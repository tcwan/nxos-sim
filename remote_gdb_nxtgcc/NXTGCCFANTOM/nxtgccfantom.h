#ifndef __NXTGCC_FANTOM_H
#define __NXTGCC_FANTOM_H

#include "visatype.h"



typedef ViObject nFANTOM100_iNXTIterator;
typedef ViObject nFANTOM100_iNXT;

//#define STATUS(s) ((s-0xFFFDD550))


nFANTOM100_iNXTIterator nFANTOM100_createNXTIterator(ViBoolean searchBluetooth,
		ViUInt32 bluetoothSearchTimeoutInSeconds, ViStatus* status);

void nFANTOM100_iNXTIterator_getName(nFANTOM100_iNXTIterator iteratorPtr,
		ViChar resourceName[], ViStatus* status);

nFANTOM100_iNXT _VI_FUNCC nFANTOM100_iNXTIterator_getNXT(
		nFANTOM100_iNXTIterator iteratorPtr, ViStatus* status);

void nFANTOM100_iNXT_getDeviceInfo(nFANTOM100_iNXT nxtPtr, ViChar name[],
		ViByte bluetoothAddress[], ViUInt8 signalStrength[],
		ViUInt32* availableFlash, ViStatus* status);

void nFANTOM100_iNXT_setName(nFANTOM100_iNXT nxtPtr, ViConstString newName,
		ViStatus* status);

ViUInt32 nFANTOM100_iNXT_write(nFANTOM100_iNXT nxtPtr,
		const ViByte bufferPtr[], ViUInt32 numberOfBytes, ViStatus* status);

ViUInt32 nFANTOM100_iNXT_read(nFANTOM100_iNXT nxtPtr,
		ViPBuf bufferPtr, ViUInt32 numberOfBytes, ViStatus* status);

void nFANTOM100_iNXT_findDeviceInFirmwareDownloadMode(
      ViChar resourceString[],
      ViStatus*   status );

nFANTOM100_iNXT nFANTOM100_createNXT(
      ViConstString    resourceString,
      ViStatus*   status,
      ViBoolean   checkFirmwareVersion );

void nFANTOM100_iNXT_downloadFirmware(
      nFANTOM100_iNXT nxtPtr,
      const ViByte    firmwareBufferPtr[],
      ViUInt32    firmwareBufferSize,
      ViStatus*   status );

void nFANTOM100_destroyNXT(
       nFANTOM100_iNXT  nxtPtr,
       ViStatus*      status );

ViUInt32 nFANTOM100_iNXT_pollAvailableLength(
      nFANTOM100_iNXT  nxtPtr,
      ViUInt32        bufferIndex,
      ViStatus*      status );

#endif //__NXTGCC_FANTOM_H
