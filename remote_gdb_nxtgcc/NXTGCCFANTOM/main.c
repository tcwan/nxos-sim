#include <stdio.h>
#include <windows.h>
#include <winsock2.h>

#include "nxtgccfantom.h"

#define NXTGCCSTATUS(s) s
//((ViInt32)s+(ViInt32)142000)

#define NXTGCCBUFMAX 2048

static ViByte inFromNxt[NXTGCCBUFMAX];
nFANTOM100_iNXTIterator nxtI;
nFANTOM100_iNXT aNxt;

//IP
WSADATA wsadata;
int socket_fd;
int listen_fd;

void normal();
void debugging();

int main() {
	setvbuf(stdout, NULL, _IONBF, 0);

	debugging();
	//normal();

	return 0;
}

void printArray(ViByte* pArr, ViUInt32 Lng) {
	ViUInt32 cntarr;
	printf("Char: ");
	for (cntarr = 0; cntarr < Lng; cntarr++) {
		printf("%c ", pArr[cntarr]);
	}
	printf("\n");
	printf("Char: ");
	for (cntarr = 0; cntarr < Lng; cntarr++) {
		printf("[%d]=%c ", cntarr, pArr[cntarr]);
	}
	printf("\n");
	printf("Hex: ");
	for (cntarr = 0; cntarr < Lng; cntarr++) {
		printf("[%d]=0x%02x ", cntarr, pArr[cntarr]);
	}
}

void sendIP(ViByte* pArr, ViUInt32 Lng) {
	printf("<--GDB IP: %d bytes\n", Lng);
	printArray(pArr, Lng);
	printf("\n");
	int sendLng = send(socket_fd, pArr, Lng, 0);
	printf("<--GDB IP: Send done: %d\n", sendLng);
}

int getIP(ViByte* pArr, ViUInt32 Lng) {
	printf("==>GDB IP: Waiting to receive max. %d bytes...\n", Lng);
	int len = recv(socket_fd, pArr, Lng, 0);
	printf("==>GDB IP: Received %d bytes\n", len);
	return len;
}

int initIP() {

	if (WSAStartup(MAKEWORD(1,1), &wsadata) == SOCKET_ERROR) {
		printf("Error creating socket.");
		return -1;
	}

	if ((listen_fd = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
		puts("Error opening socket.");
		return -1;
	}

	struct sockaddr_in server_addr;
	server_addr.sin_family = AF_INET;
	server_addr.sin_addr.s_addr = htonl(INADDR_ANY);
	server_addr.sin_port = htons(1234);

	struct sockaddr_in client_addr;
	unsigned int client_addr_length = sizeof(client_addr);

	int on = 1;
	printf("Started...\n");
	setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, (char*) &on, sizeof(on));
	if ((bind(listen_fd, (struct sockaddr*) &server_addr, sizeof(server_addr)))
			< 0) {
		puts("Error binding socket.");
		return -1;
	}

	printf("Listening on socket for a connection from gdb...\n");
	printf("(Start GDB with:\"arm-elf-gdb nxtgcc.elf\" and then \"target remote :1234\" in the gdb commend window.\n");
	printf("(Try to write \"info registers\" to test it.\n");
	if ((listen(listen_fd, 64)) < 0) {
		puts("Error listening on socket.");
		return -1;
	}

	socket_fd = accept(listen_fd, (struct sockaddr *) &client_addr,
			&client_addr_length);
	printf("Accepted a connection from gdb\n");
}

void closeIP() {
	closesocket(listen_fd);
	WSACleanup();
}

void receiveQ() {
	while (1) {
		char request[32768] = { 0 };
		//recv(socket_fd, request, 32768, 0);MSG_PEEK
		printf("Waiting to receive qSupported...\n");
		printf("(You have to put in the debuggdb() method into the NXT code where you want it to transfer control to GDB)\n");
		int len = recv(socket_fd, request, 32768, 0);
		if (len == 0)
			printf("No data!\n");

		printf("-->%s\n", request);

		char content[1024] = { 0 };

		// ACK
		if (request[0] == '$') {
			content[0] = '+';
			sendIP(content, 1);
			printf("<--%s\n", content);
			content[0] = 0;
		}
		Sleep(10);
		if (request[0] == '$') {
			if (request[1] == 'q') {
				if (request[2] == 'S') {
					content[0] = '$';
					content[1] = '#';
					content[2] = '0';
					content[3] = '0';
					content[4] = '\0';
					sendIP(content, strlen(content));
					printf("<--%s\n", content);

					char request2[32768] = { 0 };
					printf("Waiting to receive qSupported confirm...");
					int len = recv(socket_fd, request2, 1, 0);
					if (len == 0)
						printf("No data!\n");

					printf("confirm-->%s\n", request2);

					//send confirm again in response to $?#3f
					//					printf("About to send confirm to ?\n");
					//					content[0] = '+';
					//					sendIP(content, 1);
					//					printf("<--%s\n", content);

					break;
				}
			}
		} else {
			//content[0] = '+';
		}
	}
}

void debugging() {
	ViStatus status = 0;
	ViConstString resourceName = "NXT";
	ViBoolean searhnxt = 0;

	ViChar myName[256];
	ViChar resourceString[256] = { 0 }; // for finding it in download mode

	ViBoolean checkfirmware = 0;

	//nxtI = nFANTOM100_createNXTIterator(0, 0, &status);
	//printf("Hej0: %d\n", NXTGCCSTATUS(status));
	//fflush(stdout);

	nFANTOM100_iNXT_findDeviceInFirmwareDownloadMode(resourceString, &status);
	printf("Find Device in Firmware Download Mode: %d, %s\n", NXTGCCSTATUS(status), resourceString);
	//fflush(stdout);

	if(NXTGCCSTATUS(status) < 0){
		printf("ERROR: No NXT in firmware download mode found. Exiting...\n");
		exit(1);
	}

	aNxt = nFANTOM100_createNXT(resourceString, &status, checkfirmware);

	printf("CreateNXT: %d\n", NXTGCCSTATUS(status));
	//fflush(stdout);

	FILE *fp;
	fp = fopen("nxtgcc.rfw", "rb");
	if (fp == NULL) {
		printf("Can't open nxtgcc.rfw\n");
		//fflush(stdout);
		return;
	}

	printf("Open nxtgcc.rfw ok\n");
	//fflush(stdout);

	ViByte firmwareBufferPtr[256 * 1024] = { 0 };
	ViByte *fwp = firmwareBufferPtr;
	ViUInt32 firmwareBufferSize = 256 * 1024;
	int ch;
	while ((ch = getc(fp)) != EOF) {
		*fwp = (ViByte) ch;
		fwp++;
	}
	fclose(fp);

	printf("Copy firmware to arrray ok\n");
	//fflush(stdout);

	nFANTOM100_iNXT_downloadFirmware(aNxt, firmwareBufferPtr,
			firmwareBufferSize, &status);

	printf("Download firmware: status=%d\n", NXTGCCSTATUS(status));
	nFANTOM100_destroyNXT(aNxt, &status);
	printf("Destroyed nxt pointer status=%d\n", NXTGCCSTATUS(status));
	//fflush(stdout);

	int secs = 0;
	long bar = 0;
	do {
		Sleep(3000);
		nxtI = nFANTOM100_createNXTIterator(0, 0, &status);
		printf("Create NXT Iterator: %d\n", NXTGCCSTATUS(status));
		//fflush(stdout);
		bar = status;
	} while (0 > bar);

	//printf("About to getNXT. Waiting for you... %d\n",
	//		NXTGCCSTATUS(status));
	//int i;
	//scanf("%d", &i);
	printf("Moving on..\n", NXTGCCSTATUS(status));
	//fflush(stdout);
	//Sleep(5000);

	aNxt = nFANTOM100_iNXTIterator_getNXT(nxtI, &status);
	printf("Get NXT  %d\n", NXTGCCSTATUS(status));
	printf("Help: If it stops here, remember you have to put in the debuggdb() method into the NXT code where you want it to transfer control to GDB\n");
	//fflush(stdout);

	ViChar name[100];
	ViByte bluetoothAddress[50];
	ViUInt8 signalStrength[100];
	ViUInt32 availableFlash;

	//		nFANTOM100_iNXT_getDeviceInfo(aNxt, name, bluetoothAddress,
	//				signalStrength, &availableFlash, &status);
	//		printf("Hej2b(time=%d): status=%d, name=%s, flash=%d\n", secs++,
	//				NXTGCCSTATUS(status), name, availableFlash);
	//		fflush(stdout);

	//	return 0;
	//nFANTOM100_unpairBluetooth(resourceName, &status);
	//	nFANTOM100_iNXTIterator_getName(nxtI, myName, &status);
	//	printf("Hej1a: %d:%s\n", NXTGCCSTATUS(status), myName);
	//	fflush(stdout);

	//	nFANTOM100_iNXT aNXT = nFANTOM100_iNXTIterator_getNXT(nxtI, &status);
	//	printf("Hej1b: %d\n", NXTGCCSTATUS(status));
	//	fflush(stdout);

	//	nFANTOM100_iNXT_setName(aNxt, "nctgcc", &status);
	//	printf("Hej1c: %d\n", NXTGCCSTATUS(status));
	//	fflush(stdout);

	//	ViByte bufferPtr[2] = { 0x01, 0x88 };
	//	ViUInt32 numberOfBytes = sizeof(bufferPtr);
	//	ViUInt32 numBytes;
	//numBytes = nFANTOM100_iNXT_write(aNxt, bufferPtr, numberOfBytes, &status);
	//printf("Hej4: %d:wrote bytes=%d\n", NXTGCCSTATUS(status), numBytes);

	//fflush(stdout);
	//ViUInt32 pollCnt;
	int cnt = 0;
	ViByte bufferRead[64] = { 0 };
	ViUInt32 readLng = 1;
	ViUInt32 numBytes;
	ViUInt32 gdbPacketCnt = 0;
	do {
		Sleep(100);
		//pollCnt = nFANTOM100_iNXT_pollAvailableLength(aNxt, 0, &status);
		numBytes = nFANTOM100_iNXT_read(aNxt, bufferRead, readLng, &status);//7, &status);
		if (bufferRead[0] == '$') {
			// Start of GDB packet
			printf(
					"Start packet from NXT (cnt=%d): numBytes=%d, rbchar=%c, rb[0]=0x%02x, status=%d\n",
					cnt++, numBytes, bufferRead[0], bufferRead[0],
					NXTGCCSTATUS(status));
			inFromNxt[gdbPacketCnt++] = bufferRead[0];

			// Body of GDB packet
			do {
				numBytes = nFANTOM100_iNXT_read(aNxt, bufferRead, readLng,
						&status);//7, &status);
				printf(
						"Inside packet from NXT (cnt=%d): numBytes=%d, rbchar=%c, rb[0]=0x%02x, status=%d\n",
						cnt++, numBytes, bufferRead[0], bufferRead[0],
						NXTGCCSTATUS(status));
				inFromNxt[gdbPacketCnt++] = bufferRead[0];
			} while (bufferRead[0] != '#');

			// Checksum of GDB packet
			numBytes = nFANTOM100_iNXT_read(aNxt, bufferRead, readLng, &status);//7, &status);
			printf(
					"Checksum 1 byte from NXT (cnt=%d): numBytes=%d, rbchar=%c, rb[0]=0x%02x, status=%d\n",
					cnt++, numBytes, bufferRead[0], bufferRead[0],
					NXTGCCSTATUS(status));
			inFromNxt[gdbPacketCnt++] = bufferRead[0];

			numBytes = nFANTOM100_iNXT_read(aNxt, bufferRead, readLng, &status);//7, &status);
			printf(
					"Checksum 2 byte from NXT (cnt=%d): numBytes=%d, rbchar=%c, rb[0]=0x%02x, status=%d\n",
					cnt++, numBytes, bufferRead[0], bufferRead[0],
					NXTGCCSTATUS(status));
			inFromNxt[gdbPacketCnt++] = bufferRead[0];

			break;
		}

		printf("Read: (cnt=%d): numBytes=%d, status=%d\n", cnt++, numBytes,
				NXTGCCSTATUS(status));
		//printArray(bufferRead, readLng);
		printf("\n");
	} while (1);//numBytes == 0);

	//	ViChar dbgmsg[11] = { 0 };
	//	strncpy(dbgmsg, bufferRead, 11);
	printf("After: status=%d:b[0]=%d:numBytes=%d\n", NXTGCCSTATUS(status),
			bufferRead[0], numBytes);

	initIP();

	receiveQ();

	sendIP(inFromNxt, gdbPacketCnt);

	while (1) {
		Sleep(10);
		printf("*****************************************\n");
		printf("**************START******************\n");
		char mymsg[2048] = { 0 };
		// get messages from GDB, our commander!
		printf("Waiting for a GDB message\n");
		int rcv = getIP(mymsg, sizeof(mymsg));
		printf("Got a message from GDB with %d bytes:%s\n", rcv, mymsg);
		int i;
		int wait = 0;

		//
		for (i = 0; i < rcv; i++) {
			ViUInt32 numBytes;
			Sleep(10);
			numBytes = nFANTOM100_iNXT_write(aNxt, &mymsg[i], 1, &status);
			printf(
					"Wrote char:%c, wrote byte:0x%02x to NXT status=%d, numBytes=%d\n",
					i, mymsg[i], mymsg[i], NXTGCCSTATUS(status), numBytes);
			// sending a packet, then expect reply
			if (mymsg[i] == '#') {
				wait = 1;
				rcv = i + 2 + 1; //modify it to avoid dirty +
			}
		}

		if (wait == 1) {
			Sleep(10);
			int nxtReads = 1;
			int foundDash = 0;
			char msgchar;
			for (i = 0; i < nxtReads; i++) {
				Sleep(10);
				// read the acknowledgement and the packet with two bytes after the #
				printf("<--NXT: About to read 1 bytes from NXT\n");
				numBytes = nFANTOM100_iNXT_read(aNxt, &msgchar, 1, &status);
				mymsg[i] = msgchar;
				printf(
						"<--NXT: Read char=%c, hex=0x%02x, from nxt, status=%d\n",
						msgchar, msgchar, NXTGCCSTATUS(status));
				sendIP(&msgchar, 1);

				if (msgchar == '#') {
					printf("Found #\n");
					foundDash = 1;
				}

				if (foundDash == 1) {
					nxtReads = i + 2 + 1; // read two more
					foundDash = 2;
				} else if (foundDash == 2) {
				} else {
					nxtReads++; // or just one more (at a time)
				}
				printf("----------\n");
			}
            printf("<--NXT(Packet):");
            printArray(mymsg, nxtReads);
            printf("\n");
			printf("Done with that packet\n");
			printf("================================\n\n");

		}

	}

	closeIP();
}

void normal() {
	ViStatus status = 0;
	ViConstString resourceName = "NXT";
	ViBoolean searhnxt = 0;

	ViChar myName[256];
	ViChar resourceString[256] = { 0 }; // for finding it in download mode
	nFANTOM100_iNXTIterator nxtI;
	nFANTOM100_iNXT aNxt;
	ViBoolean checkfirmware = 0;

	nxtI = nFANTOM100_createNXTIterator(0, 0, &status);
	printf("Create NXT iterator: %d\n", NXTGCCSTATUS(status));
	//fflush(stdout);
}
