/* Driver for the NXT's LEGO Color sensors.
 *
 * SoftMAC Color Sensor driver.
 */

#include "base/at91sam7s256.h"

#define COLOR_LOG FALSE

#include "base/types.h"
#include "base/nxt.h"
#include "base/interrupts.h"
#include "base/assert.h"
#include "base/util.h"
#include "base/display.h"
#include "base/drivers/aic.h"
#include "base/drivers/systick.h"
#include "base/drivers/_avr.h"
#include "base/drivers/_sensors.h"
#include "base/drivers/_color.h"

/** The frequency of the Color Sensor SoftMAC processing loop in Hz. */
#define COLOR_SOFTMAC_FREQUENCY 1000				/* 1 ms per SoftMAC loop */

#define TIME_400MS	400								/* Using systick to measure 400 ms */
#define TIME_100MS	100								/* Using systick to measure 100 ms */
#define TIME_10MS	 10								/* Using systick to measure 10 ms */
#define TIME_30US	 30								/* Using PIT Timer to measure 30 us */
#define TIME_20US	 20								/* Using PIT Timer to measure 20 us */
#define TIME_2US	  2								/* Using PIT Timer to measure 2 us */

/** Maximum transmitable data size. */
#define COLOR_CAL_DATA_SIZE 52						/* sizeof color_cal_data */
#define COLOR_CAL_CRC_SIZE   2						/* sizeof caldata_crc */

/* Color Sensor Input Voltage Calibration. */
#define ADC_COLOR_MINVOLTAGE  214L					/* Min color sensor voltage (mV). */
#define ADC_MAXVOLTAGE  	 3300L					/* Max ADC voltage (mV) */
#define ADC_SCALED_RATIO	 ADC_MAXVOLTAGE/(ADC_MAXVOLTAGE - ADC_COLOR_MINVOLTAGE)
#define ADC_MAXLEVEL		 1023L					/* 10 bit resolution */

typedef struct {
    U8 colorval[NO_OF_COLORS];								/* 4 8-bit thresholds */
} color_threshvals;

/* Internal Color Detector Data Structure */
static color_threshvals min_rawcolor_lowthresh = {
		{ 0, 65, 40, 48 }
};
static color_threshvals min_rawcolor_highthresh = {
		{ 0, 110, 70, 85 }
};
static color_threshvals min_rawambience_highthresh = {
		{ 0, 40, 30, 25 }
};

static color_threshvals max_rawcolor_lowthresh = {
		{ 0, 70, 70, 60 }
};
static color_threshvals max_rawcolor_highthresh = {
		{ 0, 140, 140, 120 }
};
static color_threshvals max_rawambience_highthresh = {
		{ 0, 140, 140, 110 }
};

/* Internal Color Bus Data Structure.
 * This should be updated only by the ISR */
static volatile struct color_port {
  enum {
    COLORBUS_OFF = 0, /* Port not initialized in I2C mode. */
    COLORBUS_IDLE,    /* No transaction in progress. */
    COLORBUS_CALSTART0,
    COLORBUS_CALSTART1,
    COLORBUS_CALSTART2,
    COLORBUS_CALSTART3,
    COLORBUS_PAUSE,
    COLORBUS_WRITEBYTE,
    COLORBUS_READBYTE,
    COLORBUS_WAITREADY,
    COLORBUS_WAITRECAL,
    COLORBUS_WAITSAMPLE0,
    COLORBUS_WAITSAMPLE1,
    COLORBUS_SAMPLEINPUTS,
  } bus_state;

  /* Actual Status of the Color Sensor Bus */
  color_status colorbus_status;

  /* Target Status of the Color Sensor Bus */
  color_status colorbus_target_status;

  /* Pointer to Calibration Data Buffer (pre-allocated) */
  color_cal_data *caldataptr;

  U16 caldata_crc;	/* 16-bit CRC value */

  /* A/D Values
   * indexed based on color_mode enum
   */
  color_values advals;

  /* Data flow tracking values : currently processed bytes, the
   * currently transmitted byte, and the position of the bit currently
   * transmitted in this byte.
   */
  U8 processed;
  U8 current_byte;
  S8 current_pos;

} color_bus_state[NXT_N_SENSORS];

/* Forward declarations. */
static void color_isr(void);

/* Configuration parameter for initializing Color Sensor device */
static const U8 color_mode_setup[COLOR_NUM_MODES] = {
		17, /* COLOR_MODE_NONE */
		13, /* COLOR_FULL */
		14, /* COLOR_RED */
		15, /* COLOR_GREEN */
		16, /* COLOR_BLUE */
};

/* Color Sensor Default to None (LEDs off) */
static color_config sensors_colorconfig[NXT_N_SENSORS] = {
		{COLOR_MODE_NONE, COLOR_NOTFOUND },
		{COLOR_MODE_NONE, COLOR_NOTFOUND },
		{COLOR_MODE_NONE, COLOR_NOTFOUND },
		{COLOR_MODE_NONE, COLOR_NOTFOUND },
};

#if (COLOR_LOG == TRUE)
static void colorbus_log(const char *s);
static void colorbus_log_uint(U32 val);
#endif

/** [Internal Routine]
 * Initializes the Color Sensor SoftMAC driver, configures the TC (Timer Counter)
 * and set the interrupt handler.
 */
void nx__color_init(void) {

	NX_ASSERT(sizeof(color_cal_data) == COLOR_CAL_DATA_SIZE);	/* Sanity Check */

	memset((void*)color_bus_state, 0, sizeof(color_bus_state));
	nx_interrupts_disable();

  /* We need power for both the PIO controller and the second TC (Timer
   * Channel) controller.
   */
  *AT91C_PMC_PCER = (1 << AT91C_ID_PIOA) | (1 << AT91C_ID_TC1);

  /* Configure a timer to trigger interrupts for managing the Color Sensor
   * ports.
   *
   * Disable the counter before reconfiguring it, and mask all
   * interrupt sources. Then wait for the clock to acknowledge the
   * shutdown in its status register. Reading the SR has the
   * side-effect of clearing any pending state in there.
   */
  *AT91C_TC1_CCR = AT91C_TC_CLKDIS;
  *AT91C_TC1_IDR = ~0;
  while (*AT91C_TC1_SR & AT91C_TC_CLKSTA);

  /* Configure the timer to count at a rate of MCLK/2 (24MHz), and to
   * reset on RC compare. This means the clock will be repeatedly
   * counting at 24MHz from 0 to the value in the RC register.
   */
  *AT91C_TC1_CMR = AT91C_TC_CPCTRG;
  *AT91C_TC1_RC = (NXT_CLOCK_FREQ/2)/(4*COLOR_SOFTMAC_FREQUENCY);

  /* Enable the timer. */
  *AT91C_TC1_CCR = AT91C_TC_CLKEN;

  /* Allow the timer to trigger interrupts and register our interrupt
   * handler.
   */
  nx_aic_install_isr(AT91C_ID_TC1, AIC_PRIO_SOFTMAC, AIC_TRIG_EDGE, color_isr);

  /* Softare trigger, to get the counter going. */
  *AT91C_TC1_CCR = AT91C_TC_SWTRG;

  nx_interrupts_enable();
}

#if (COLOR_LOG == TRUE)
static void colorbus_log(const char *s)
{
  nx_display_string(s);
}

static void colorbus_log_uint(U32 val)
{
  nx_display_uint(val);
}
#endif

/** [Internal Routine]
 *
 * Get the actual configuration status of the LEGO Color Sensor on the given port
 */
static color_status nx__color_get_status(U32 sensor) {

	return color_bus_state[sensor].colorbus_status;
}

void nx__color_check_disable_isr(void) {
  U32 sensor;

  for (sensor=0; sensor<NXT_N_SENSORS; sensor++) {
	if (color_bus_state[sensor].colorbus_status != COLOR_NOTFOUND)
		return;
  }
  *AT91C_TC1_IDR = AT91C_TC_CPCS;		/* Disable color_isr if no active sensors */

}


/** Initialize a color sensor for the given mode on the given sensor port. */
void nx_color_init(U32 sensor, color_mode mode, color_cal_data *caldata) {

  volatile struct color_port *p;

  if ((sensor >= NXT_N_SENSORS) || (mode >= COLOR_NUM_MODES))
    return;

  nx__sensors_color_enable(sensor);
  sensors_colorconfig[sensor].mode = mode;
  sensors_colorconfig[sensor].status = COLOR_CALIBRATE;

  p = &color_bus_state[sensor];

  /* Configure Color Bus for the
   * Lego Color Sensor on the given port
   */
  p->caldataptr = caldata;
  memset((U8 *)&(p->advals), 0, sizeof(color_values));

  p->bus_state = COLORBUS_IDLE;			/* Initial state, will be updated once ISR kicks in. Note: This violates the
   	   	   	   	   	   	   	   	   	   	 * critical section separation where only the ISR updates color_bus_state[sensor],
   	   	   	   	   	   	   	   	   	   	 * but since we're initializing the sensor, it is safe to do so.
   	   	   	   	   	   	   	   	   	   	 */
  /* Enable the color_isr interrupt unconditionally. */
  *AT91C_TC1_IER = AT91C_TC_CPCS;

}

/** Close the link to the color sensor and disable the color sensor on the given sensor port. */
void nx_color_close(U32 sensor) {

  if (sensor >= NXT_N_SENSORS)
    return;

  sensors_colorconfig[sensor].mode = COLOR_MODE_NONE;
  sensors_colorconfig[sensor].status = COLOR_EXIT;	/* Trigger Color Sensor Cleanup */
}

/** Check the presence and status of a lego color sensor on the given sensor port. */
color_status nx_color_detect(U32 sensor) {

  NX_ASSERT(sensor < NXT_N_SENSORS);

  /* If AVR Co-processor A/D Value is above threshold, it means that some other sensor is attached */
  if (nx__avr_get_sensor_value(sensor) > 50) {
	  nx__sensors_disable(sensor);
	  sensors_colorconfig[sensor].mode = COLOR_MODE_NONE;
	  sensors_colorconfig[sensor].status = COLOR_NOTFOUND;
  } else	/* TODO: Can we handle sensor reconnection? */
	  sensors_colorconfig[sensor].status = nx__color_get_status(sensor);

  return sensors_colorconfig[sensor].status;
}

/** Recalibrate the lego color sensor on the given sensor port. */
void nx_color_reset(U32 sensor, color_mode mode) {
  if (sensor >= NXT_N_SENSORS)
    return;

  NX_ASSERT(sensors_colorconfig[sensor].status != COLOR_NOTFOUND);

  sensors_colorconfig[sensor].mode = mode;
  sensors_colorconfig[sensor].status = COLOR_CALIBRATE;	/* Trigger Color Sensor Recalibration */

}

/** Display the color sensor's information. */
void nx_color_info(U32 sensor) {
	/* FIXME */
}


/** Get the current LED mode of the given LEGO Color Sensor */
color_mode nx_color_get_mode(U32 sensor) {
  return sensors_colorconfig[sensor].mode;
}

/** Read all color sensor raw values */
bool nx_color_read_all_raw(U32 sensor, color_values* rawvalues) {
  volatile struct color_port *p;

  if ((sensor >= NXT_N_SENSORS) || (nx_color_detect(sensor) != COLOR_READY))
	return FALSE;

  p = &color_bus_state[sensor];

  memcpy(rawvalues, (void *)&(p->advals), sizeof(color_values));
  return TRUE;

}

/** Read color sensor raw value for given mode */
U32 nx_color_read_mode_raw(U32 sensor) {
  volatile struct color_port *p;
  U32 sensorval = 0;

  if ((sensor < NXT_N_SENSORS) && (nx_color_detect(sensor) == COLOR_READY)) {
	p = &color_bus_state[sensor];

	switch (sensors_colorconfig[sensor].mode) {
	case COLOR_MODE_NONE:
	case COLOR_MODE_FULL:
	  sensorval = p->advals.colorval[COLOR_NONE];
	  break;
	case COLOR_MODE_RED:
	  sensorval = p->advals.colorval[COLOR_RED];
	  break;
	case COLOR_MODE_GREEN:
	  sensorval = p->advals.colorval[COLOR_GREEN];
	  break;
	case COLOR_MODE_BLUE:
	  sensorval = p->advals.colorval[COLOR_BLUE];
	  break;
	default:
	  sensorval = 0;
	  break;
	};
  }
  return sensorval;
}

/** Scale Raw Color Inputs to full ADC range. */
U32 nx_color_scale_input(U32 rawvalue) {
	U32 scaled;

	/* Clamp to zero or positive value */
	scaled = (rawvalue > ADC_COLOR_MINVOLTAGE) ? (rawvalue - ADC_COLOR_MINVOLTAGE) : 0;

	scaled = scaled * ADC_SCALED_RATIO;		/* Expand value to full ADC Range */

	/* Clamp to ADC_MAXLEVEL */
	scaled = (scaled < ADC_MAXLEVEL) ? scaled : ADC_MAXLEVEL;

	return scaled;
}


/** Detect Colors given raw input values
 * Algorithm reverse engineered from
 * NXT Firmware code in c_input.c
 *
 * Pass a valid Calibration Data structure pointer
 * if calibration should be done (default case).
 *
 * The available LEGO brick colors are:
 *   BLACK, BLUE, GREEN, YELLOW, RED, WHITE
 *
 * RED, GREEN, BLUE are primary colors.
 * YELLOW is a combination of RED and GREEN.
 *
 * The color sensor activates each R, G, B LED
 * in turn to read the response from the surface,
 * as well as an ambience level reading (unlighted)
 * This means that the reflected color response depends
 * on the LED light color, as well as the specific color
 * reflectance of the surface. The roughness of the surface
 * will also play a part.
 *
 * e.g., BLUE surfaces would tend to reflect BLUE light
 * more than other colors.
 *
 * The algorithm assumes two modes for color detection.
 * First is for rough surfaces with lower reflectance,
 * and second for smooth surfaces with high reflectance.
 *
 * The detection process is divided into 5 thresholds
 * where low reflectance values would result in either BLACK
 * or one of the primary color, as well as YELLOW if
 * the LED light is RED or GREEN.
 * High reflectance values would either result in BLACK
 * if the various colors do not exceed the given thresholds
 * (emphasis on the ambience level readings), or else
 * it is detected as WHITE, except for the case of the BLUE
 * LED light where BLUE surfaces could give high reflectance
 * readings.
 *
 * It appears that the thresholds chosen in the NXT Firmware
 * code are empirical based on experimental data.
 */

color_detected nx_color_detector(color_values *rawvalues, color_cal_data *caldata) {

	color_detected theColor = COLOR_DETECT_UNKNOWN;
	color_struct_colors dominantColor = COLOR_NONE;
	color_struct_colors secondaryColor1 = COLOR_NONE, secondaryColor2 = COLOR_NONE;

	if (caldata)
		nx__color_calibrate_inputs(rawvalues, caldata);

	/* Determine Dominant Color */
	if ((rawvalues->colorval[COLOR_RED] > rawvalues->colorval[COLOR_BLUE]) &&
			(rawvalues->colorval[COLOR_RED] > rawvalues->colorval[COLOR_GREEN])) {
		/* Red is Dominant */
		dominantColor = COLOR_RED;		/* Possible detected colors are: Red, Yellow, White, Black */
		secondaryColor1 = COLOR_GREEN;
		secondaryColor2 = COLOR_BLUE;

	} else if (rawvalues->colorval[COLOR_GREEN] > rawvalues->colorval[COLOR_BLUE]) {
		/* Green is Dominant */
		dominantColor = COLOR_GREEN;	/* Possible detected colors are: Green, Yellow, White, Black */
		secondaryColor1 = COLOR_RED;
		secondaryColor2 = COLOR_BLUE;

	} else {
		/* Blue is Dominant */
		dominantColor = COLOR_BLUE;		/* Possible detected colors are: Blue, White, Black */
		secondaryColor1 = COLOR_RED;
		secondaryColor2 = COLOR_GREEN;
	}


	/* Detect Black
	 * < min dominant color threshold for low reflectance objects
	 * else < mid ambience threhold(s) for high reflectance objects
	 */
	if ((rawvalues->colorval[dominantColor] < min_rawcolor_lowthresh.colorval[dominantColor]) ||
		((rawvalues->colorval[dominantColor] < min_rawcolor_highthresh.colorval[dominantColor]) &&
		(rawvalues->colorval[COLOR_NONE] < min_rawambience_highthresh.colorval[dominantColor])))
			theColor = COLOR_DETECT_BLACK;
	/* mid intensity (color differential exceeds thresholds) */
	else {
		switch (dominantColor) {
		case COLOR_RED:
			if ((((rawvalues->colorval[COLOR_BLUE] * 11) / 8) < rawvalues->colorval[COLOR_GREEN]) &&
				  ((rawvalues->colorval[COLOR_GREEN] * 2) > rawvalues->colorval[COLOR_RED]))
				theColor = COLOR_DETECT_YELLOW;
			else if (((rawvalues->colorval[COLOR_GREEN] * 7) / 4) < rawvalues->colorval[COLOR_RED])
				theColor = COLOR_DETECT_RED;
			break;

		case COLOR_GREEN:
			if ((rawvalues->colorval[COLOR_BLUE] * 2) < rawvalues->colorval[COLOR_RED])
				theColor = COLOR_DETECT_YELLOW;
			else if ((((rawvalues->colorval[COLOR_RED] * 5) / 4) < rawvalues->colorval[COLOR_GREEN]) ||
					 (((rawvalues->colorval[COLOR_BLUE] * 5) / 4) < rawvalues->colorval[COLOR_GREEN]))
				theColor = COLOR_DETECT_GREEN;
			break;

		case COLOR_BLUE:
					/* Low Reflectance */
			if (((((rawvalues->colorval[COLOR_RED] * 48) / 32) < rawvalues->colorval[COLOR_BLUE]) &&
				  (((rawvalues->colorval[COLOR_GREEN] * 48) / 32) < rawvalues->colorval[COLOR_BLUE])) ||
					/* High Reflectance */
				((((rawvalues->colorval[COLOR_RED] * 58) / 32) < rawvalues->colorval[COLOR_BLUE]) &&
				  (((rawvalues->colorval[COLOR_GREEN] * 58) / 32) < rawvalues->colorval[COLOR_BLUE])))
				theColor = COLOR_DETECT_BLUE;
			break;

		default:
			break;
		}
	}

	/* High Reflectance, insufficient color differentials */
	if (theColor == COLOR_DETECT_UNKNOWN) {
		if ((rawvalues->colorval[secondaryColor1] < max_rawcolor_lowthresh.colorval[dominantColor]) ||
			(rawvalues->colorval[secondaryColor2] < max_rawcolor_lowthresh.colorval[dominantColor]) ||
			((rawvalues->colorval[dominantColor] < max_rawcolor_highthresh.colorval[dominantColor]) &&
			(rawvalues->colorval[COLOR_NONE] < max_rawambience_highthresh.colorval[dominantColor])))

				theColor = COLOR_DETECT_BLACK;

		else if ((dominantColor == COLOR_BLUE) &&
				 ((((rawvalues->colorval[secondaryColor1] * 9) / 8) < rawvalues->colorval[dominantColor]) ||
				  (((rawvalues->colorval[secondaryColor2] * 9) / 8) < rawvalues->colorval[dominantColor])))

				theColor = COLOR_DETECT_BLUE;
		else
			/* High intensity for all LED color channels */
				theColor = COLOR_DETECT_WHITE;

		}

	return theColor;
}


/* [Internal Routine]
 * Initiate A/D conversion for all active Color Sensors
 */
void nx__color_adc_get(U32 aden, color_struct_colors index) {

  int	sensor;

  const nx__sensors_adcmap *adchan;
  volatile struct color_port *p;

  /* First sample */
  *AT91C_ADC_CR = AT91C_ADC_START;

  for (sensor=0; sensor<NXT_N_SENSORS; sensor++) {
	  p = &color_bus_state[sensor];
	  adchan = nx__sensors_get_adcmap(sensor);
	  if (adchan->chn & aden) {
		  while (!((*AT91C_ADC_SR) & adchan->chn));
		  p->advals.colorval[index] = *(adchan->ptr);
	  }
  }

  /* Second sample, average */
  *AT91C_ADC_CR = AT91C_ADC_START;

  for (sensor=0; sensor<NXT_N_SENSORS; sensor++) {
	  p = &color_bus_state[sensor];
	  adchan = nx__sensors_get_adcmap(sensor);
	  if (adchan->chn & aden) {
		  while (!((*AT91C_ADC_SR) & adchan->chn));
		  p->advals.colorval[index] += *(adchan->ptr);
		  p->advals.colorval[index] = (p->advals.colorval[index] >> 1);		/* averaged reading */
	  }
  }
}

/* [Internal Routine]
 * Retrieve A/D samples for all active Color Sensors
 */
void nx__color_adc_get_samples(U32 aden, U32 adclk) {
  int colorindex;

  if ((aden == 0) || (adclk == 0))
	return;

  *AT91C_ADC_CHER = aden;							/* Enable ADC Channels */

  for (colorindex = 0; colorindex < NO_OF_COLORS; colorindex++) {

	  nx__color_adc_get(aden, colorindex);

	  if ((colorindex & 0x01) == 0)
	    *AT91C_PIOA_SODR = adclk;					/* Even ADC Clock Edge */
	  else
	    *AT91C_PIOA_CODR = adclk;					/* Odd ADC Clock Edge */
	  nx_systick_wait_us(TIME_20US);				/* ADC Settling Time */
  }

  *AT91C_ADC_CHDR = aden;							/* Disable ADC Channels */

}

/* [Internal Routine]
 * Setup transmission parameters for Color Bus
 */
void nx__colorbus_setup_txbyte(U32 sensor, U8 val) {

  volatile struct color_port *p;
  p = &color_bus_state[sensor];

  p->processed = 0;
  p->current_pos = 0;
  p->current_byte = val;

}

/* [Internal Routine]
 * Setup reception parameters for Color Bus
 */
void nx__colorbus_setup_rxbyte(U32 sensor) {

  volatile struct color_port *p;
  p = &color_bus_state[sensor];

  p->current_pos = 0;
  p->current_byte = 0;

}

/** [Internal Routine]
 * Verify CRC for Calibration Data
 * Code taken from LEGO NXT Firmware
 * If caldataptr is NULL (i.e., no calibration data buffer), return TRUE
 */
bool nx__color_calibration_crc(color_cal_data *caldataptr, U16 crcval) {

	U8 *dataptr = (U8 *) caldataptr;
	U16 crc_checkval = 0x5AA5;
	int counter;

	if (caldataptr == NULL)
		return TRUE;

	for (counter = 0; counter < (COLOR_CAL_DATA_SIZE+COLOR_CAL_CRC_SIZE); counter++) {

		int i, j;
		U8 c;

		c = dataptr[counter];
		for (i=0; i != 8; c >>= 1, i++) {
			j = (c ^ crc_checkval) & 1;
			crc_checkval >>= 1;
			if (j)
				crc_checkval ^= 0xA001;

		}
	}
	return (crc_checkval == crcval);
}

/** [Internal Routine]
 * Adjust Raw Inputs using Color Calibration Data
 * Code adapted from LEGO NXT Firmware
 */
void nx__color_calibrate_inputs(color_values *rawvalues, color_cal_data *caldata) {
	int calrange;
	color_struct_colors color_iter;
	U32 colorval_none = rawvalues->colorval[COLOR_NONE];

	calrange = (colorval_none < caldata->calibration_limits[1]) ? 2 :
			   ((colorval_none < caldata->calibration_limits[0]) ? 1 : 0);

	for (color_iter = COLOR_RED; color_iter < NO_OF_COLORS; color_iter++) {
		if (rawvalues->colorval[color_iter] > colorval_none)
			rawvalues->colorval[color_iter] = ((rawvalues->colorval[color_iter] - colorval_none)
												* caldata->calibration[calrange][color_iter]) / 65536;
	}

	/* Convert COLOR_NONE raw reading to full scale */
	// FIXME
	rawvalues->colorval[COLOR_NONE] = (rawvalues->colorval[COLOR_NONE]
	                                   * caldata->calibration[calrange][COLOR_NONE]) / 65536;

}


/** Interrupt handler. */
static void color_isr(void) {

  volatile struct color_port *p;
  volatile U32 dummy __attribute__ ((unused));
  U32 codr = 0;
  U32 sodr = 0;
  U32 aden = 0;
  U32 adclk = 0;
  U32 sensor;

  /* Read the TC1 status register to ack the TC1 timer and allow this
   * interrupt handler to be called again.
   */
  dummy = *AT91C_TC1_SR;

  for (sensor=0; sensor<NXT_N_SENSORS; sensor++) {
    const nx__sensors_pins *pins = nx__sensors_get_pins(sensor);
    const nx__sensors_adcmap *adchan = nx__sensors_get_adcmap(sensor);

    p = &color_bus_state[sensor];

    switch (p->bus_state)
       {
       default:
       case COLORBUS_OFF:
         /* Port is OFF, do nothing. */
         break;
       case COLORBUS_IDLE:
    	   if (p->colorbus_target_status != sensors_colorconfig[sensor].status) {
    		   /* State Changed */
    		   p->colorbus_target_status = sensors_colorconfig[sensor].status;
    		   /* Configure new state */
    		   switch (p->colorbus_target_status) {
    		     default:
    		     case COLOR_NOTFOUND:
    		    	 /* Disable Color Sensor */
    		    	 p->colorbus_status = p->colorbus_target_status;
    		    	 break;
    		     case COLOR_CALIBRATE:
    		    	 if ((p->colorbus_status != COLOR_NOTFOUND) && (p->colorbus_status != COLOR_READY)) {
    		    		 /* Perform Calibration for given mode */
    		    		 nx__colorbus_setup_txbyte(sensor, sensors_colorconfig[sensor].mode);
    		    		 p->colorbus_status = p->colorbus_target_status;
    		    	 }
    		    	 break;
    		     case COLOR_EXIT:
    		    	 if (p->colorbus_status != COLOR_NOTFOUND) {
    		    		 /* Perform Calibration for mode == COLOR_MODE_NONE */
    		    		 nx__colorbus_setup_txbyte(sensor, COLOR_MODE_NONE);
    		    		 p->colorbus_status = p->colorbus_target_status;
    		    	 }
    		    	 break;
    		     case COLOR_READY:
    		    	 /* Remain in current state */
    		    	  NX_ASSERT(p->colorbus_status == p->colorbus_target_status);
    		    	  /* We should be in this state only after colorbus_status has been updated to COLOR_READY */

    		    	 break;
    		   }
    	   }

    	   /* Continue processing current state */
		   switch (p->colorbus_status) {
			 case COLOR_CALIBRATE:
				 /* Continue Calibration */
		    	 p->bus_state = COLORBUS_CALSTART0;
				 break;
			 case COLOR_READY:
				 /* Prepare A/D for read */
		    	 p->bus_state = COLORBUS_WAITSAMPLE0;
				 break;
			 case COLOR_EXIT:
				 /* Continue Exiting */
		    	 p->bus_state = COLORBUS_CALSTART0;
				 break;
			 case COLOR_NOTFOUND:
			 default:
				 /* Turn off Color Bus */
		    	 p->bus_state = COLORBUS_OFF;
		    	 p->caldataptr = NULL;
		    	 nx__sensors_disable(sensor);			/* Disable sensor */
		    	 nx__color_check_disable_isr();
				 break;

		   }
    	 break;
	   case COLORBUS_CALSTART0:
		 /* The Color Sensor Initialization/Calibration sequence is done as follows:
		  * Data line (output) HIGH
		  * Serial Clock (output) toggling HIGH (1 ms)->LOW (1 ms)->HIGH (1 ms)->LOW (wait 100 ms)
		  */
         sodr |= pins->sda;
		 sodr |= pins->scl;
		 p->bus_state = COLORBUS_CALSTART1;
		 break;
	   case COLORBUS_CALSTART1:
		 codr |= pins->scl;
		 p->bus_state = COLORBUS_CALSTART2;
		 break;
	   case COLORBUS_CALSTART2:
		 sodr |= pins->scl;
		 p->bus_state = COLORBUS_CALSTART3;
		 break;
	   case COLORBUS_CALSTART3:
		 codr |= pins->scl;
		 p->bus_state = COLORBUS_PAUSE;
		 p->advals.colorval[COLOR_NONE] = nx_systick_get_ms() + TIME_100MS;	/* Use advals to store timestamp temporarily */
		 break;
       case COLORBUS_PAUSE:
    	 /* Wait for 100 ms */
	     /* Dealing with systick_time rollover:
		  * http://www.arduino.cc/playground/Code/TimingRollover
		  * Exit only if (long)( systick_time - timestamp ) >= 0
		  *    Note: This used signed compare to come up with the correct decision
		  */
    	 if ((long) (nx_systick_get_ms() - p->advals.colorval[COLOR_NONE]) >= 0)
    		p->bus_state = COLORBUS_WRITEBYTE;
    	 break;
       case COLORBUS_WRITEBYTE:
    	 /* We write out the byte directly here, due to the timing required */
   		 *AT91C_PIOA_OER = pins->sda;					/* Switch to data output on color bus */
    	 while (p->current_pos < 8) {
    		 *AT91C_PIOA_SODR = pins->scl;				/* Start with Clk HIGH */
    		 nx_systick_wait_us(TIME_2US);				/* Clock Settling Time */
    		 /* Set Data output bit */
    		 if ((p->current_byte & (1 << p->current_pos))) {
				 *AT91C_PIOA_SODR = pins->sda;
#if (COLOR_LOG == TRUE)
				 color_log_uint(1);
#endif
			 } else {
				 *AT91C_PIOA_CODR = pins->sda;
#if (COLOR_LOG == TRUE)
				 color_log_uint(0);
#endif
			 }
			 ++p->current_pos;
			 nx_systick_wait_us(TIME_30US);				/* Data Settling Time */
    		 *AT91C_PIOA_CODR = pins->scl;				/* Clock HIGH->LOW Transition (latch data bit) */
    		 nx_systick_wait_us(TIME_2US+TIME_30US);	/* Clock Settling Time + Next Bit Wait Time */
    	   }
  		 codr |= pins->scl;								/* Make sure that Clock is LOW when done */
  		 p->processed = 0;								/* Setup for Calibration Data input */
  		 *AT91C_PIOA_ODR = pins->sda;					/* Switch to data input on color bus */
  		 p->bus_state = COLORBUS_READBYTE;
      	 break;
       case COLORBUS_READBYTE:
    	 *AT91C_PIOA_ODR = pins->sda;					/* Switch to data input on color bus */
  		 nx__colorbus_setup_rxbyte(sensor);				/* Setup for byte input */
    	 while (p->current_pos < 8) {
    		 *AT91C_PIOA_SODR = pins->scl;				/* Start with Clk HIGH */
    		 nx_systick_wait_us(TIME_2US+TIME_2US+TIME_2US); /* Clock Settling Time */

    		 *AT91C_PIOA_CODR = pins->scl;				/* Clock HIGH->LOW Transition (latch data bit) */
    		 nx_systick_wait_us(TIME_2US);				/* Clock Settling Time */

    		 U8 value = (*AT91C_PIOA_PDSR & pins->sda) ? 1 : 0;	/* Read Bit value and store it */
    		 nx_systick_wait_us(TIME_2US);				/* Data Settling Time */

    		 p->current_byte |= (value << p->current_pos);	/* Accumulate byte value */
#if (COLOR_LOG == TRUE)
             color_log_uint(value);
#endif
			 ++p->current_pos;
    	   }
  		 codr |= pins->scl;								/* Make sure that Clock is LOW when done */

  		 if (p->caldataptr && (p->processed < COLOR_CAL_DATA_SIZE)) {
  			 /* Store calibration data if pointer is valid (non-NULL) */
  	  		 U8 *dataptr = (U8 *) p->caldataptr;
  	         dataptr[p->processed] = p->current_byte;
  		 } else if (p->processed == COLOR_CAL_DATA_SIZE) {
  			 p->caldata_crc = p->current_byte << 8;		/* MSByte of CRC */
  		 } else if (p->processed == COLOR_CAL_DATA_SIZE+1) {
  			 p->caldata_crc |= p->current_byte;			/* LSByte of CRC */
  		 }
  		 ++p->processed;								/* Get ready for next byte */

  		 /* Check for End of Calibration Phase */
    	 if (p->processed >= COLOR_CAL_DATA_SIZE+COLOR_CAL_CRC_SIZE) {
      		p->bus_state = COLORBUS_IDLE;			/* Default bus next state */

    		if (p->colorbus_status == COLOR_EXIT) {
    			/* Nothing to so, complete exit */
    		    p->colorbus_status = COLOR_NOTFOUND;
    		 } else {
    	   		if (nx__color_calibration_crc(p->caldataptr, p->caldata_crc)) {
    	   		  /* CRC Valid */
    	          if (p->colorbus_status == COLOR_CALIBRATE) {
    	        	p->bus_state = COLORBUS_WAITREADY;
    	            p->advals.colorval[COLOR_NONE] = nx_systick_get_ms() + TIME_10MS;	/* Use advals to store timestamp temporarily */
    	          }
    	   		} else {
    	   			/* CRC Error */
    	        	p->bus_state = COLORBUS_WAITRECAL;
    	            p->advals.colorval[COLOR_NONE] = nx_systick_get_ms() + TIME_400MS;	/* Use advals to store timestamp temporarily */
    	   		}
    		 }
    	 }
    	 break;
       case COLORBUS_WAITREADY:
      	 if ((long) (nx_systick_get_ms() - p->advals.colorval[COLOR_NONE]) >= 0) {
      		p->bus_state = COLORBUS_IDLE;
      		p->colorbus_status = COLOR_READY;
      	 }
      	 break;
       case COLORBUS_WAITRECAL:
      	 if ((long) (nx_systick_get_ms() - p->advals.colorval[COLOR_NONE]) >= 0) {
      		p->bus_state = COLORBUS_IDLE;
      		p->colorbus_status = COLOR_CALIBRATE;
      	 }
      	 break;
       case COLORBUS_WAITSAMPLE0:
     	 p->bus_state = COLORBUS_WAITSAMPLE1;
    	 codr |= pins->scl;							/* Make sure that Clock is LOW */
         break;
       case COLORBUS_WAITSAMPLE1:
     	 p->bus_state = COLORBUS_SAMPLEINPUTS;
         break;
       case COLORBUS_SAMPLEINPUTS:
    	 aden |= adchan->chn;						/* Enable A/D Conversion for given port */
    	 adclk |= pins->scl;
    	 codr |= pins->scl;							/* Make sure that Clock is LOW when done */
     	 p->bus_state = COLORBUS_WAITSAMPLE0;
         break;

       };
  };
  /** Perform AD Sampling for all active Color Sensors */
  if (aden)
	nx__color_adc_get_samples(aden, adclk);

  /** Update CODR and SODR to reflect changes for all active sensors' pins. */
  if (codr)
    *AT91C_PIOA_CODR = codr;
  if (sodr)
    *AT91C_PIOA_SODR = sodr;
}


