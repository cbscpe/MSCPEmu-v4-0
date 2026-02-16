;--------------------------------------------------------------------------
;
;	activate <partition>
;
;	Change the partition type from MS-DOS FAT-12 to Linux so it can 
;	be attached
;

activpar092:
	lds	r18, attpart
	ori	r18, '0'
	sts	pprint+0, r18
	call	print
	.db	"Partition ", 0x90, " is not idle", 0x0d, 0x0a, 0x00
	clc
	rjmp	activparexit

;activpar091:
;	lds	r18, attpart
;	ori	r18, '0'
;	sts	pprint+0, r18
;	call	print
;	.db	"Partition ", 0x90, " is attached", 0x0d, 0x0a, 0x00
;	clc
;	rjmp	activparexit

activpar090:
	lds	r18, attpart
	ori	r18, '0'
	sts	pprint+0, r18
	call	print
	.db	"Partition ", 0x90, " not found", 0x0d, 0x0a, 0x00
	clc
	rjmp	activparexit

activpar:
	push	yl
	push	yh
	lds	r24, attpart
	rcall	findpart
	adiw	r25:r24, 0
	breq	activpar090
	movw	r15:r14, r25:r24		; Save PCB Pointer
	movw	yh:yl, r15:r14
	ldd	r18, Y+pcb_status
;	sbrc	r18, pcb__attach
;	rjmp	activpar091
	sbrs	r18, pcb__idle
	rjmp	activpar092
	
	ldi	yl, low(sdio)
	ldi	yh, high(sdio)
	ldi	r18, low(sdbuffer)
	std	Y+P_Address+0, r18
	ldi	r18, high(sdbuffer)
	std	Y+P_Address+1, r18
	
	movw	zh:zl, r15:r14		; Partition Control Block
	ldd	r18, Z+pcb_mbrsector+0
	std	Y+P_Sector+0, r18	
	ldd	r18, Z+pcb_mbrsector+1
	std	Y+P_Sector+1, r18	
	ldd	r18, Z+pcb_mbrsector+2
	std	Y+P_Sector+2, r18	
	ldd	r18, Z+pcb_mbrsector+3
	std	Y+P_Sector+3, r18	
	movw	r25:r24, yh:yl
	call	SD_CARD_READ
	brcc	activpar010

	call	print
	.db	"Error reading partition master sector", 0x0d, 0x0a, 0x00
	clc
	rjmp	activparexit
activpar010:	
	lds	r18, sdbuffer+510
	cpi	r18, 0x55
	brne	activpar093
	lds	r18, sdbuffer+511
	cpi	r18, 0xAA
	breq	activpar020

activpar093:
	call	print
	.db	"Invalid partition master sector", 0x0d, 0x0a, 0x00
	clc
	rjmp	activparexit

activpar020:
	movw	zh:zl, r15:r14
	ldd	xl, Z+pcb_offset
	ldi	xh, 0x01
	subi	xl, low(-sdbuffer-M_PartType)
	sbci	xh, high(-sdbuffer-M_PartType)
	ld	r18, X
	cpi	r18, 0x01		; FAT-12
	breq	activpar030
	cpi	r18, 0xAF		; HFS+
	breq	activpar030
	call	print
	.db	CR, LF, "Partition is not FAT-12/HFS+", 0x0d, 0x0a, 0x00, 0x00
	clc
	rjmp	activparexit
;
;	
;
activpar030:
	ldi	r18, 0x83
	st	X, r18
	movw	r25:r24, yh:yl
	call	SD_CARD_WRITE
	brcc	activpar040
	call	print
	.db	"Error writing partition master sector", 0x0d, 0x0a, 0x00
	clc
	rjmp	activparexit
activpar040:
	movw	zh:zl, r15:r14
	std	Z+pcb_status, zero
	clc
;
;
;
activparexit:
	pop	yh
	pop	yl
	ret

	
;--------------------------------------------------------------------------
;
;	initialise <partition>
;
;	The bad sector file is written on the last track on the last surface
;	of a cartridge. For a description see
;	http://bitsavers.org/pdf/dec/disc/rl01_rl02/EK-RL012-UG-005_Sep81.tif.pdf
;
;	The first half of the track has factory written bad sector info and
;	the second half has field written bad sector info.
;
;	The information of each inforomation block is duplicated 5 times. Each block
;	occupies 1024bytes, which is 2 SD-Card blocks or 4 RL01/02 sectors.
;
;	Unused bad sector entries consists of all ones.
;
;	+-------------------------------------------------------------+
;	| 5 most significant octal digits of cartridge serial number  |
;	+-------------------------------------------------------------+
;	| 5 least significant octal digits of cartridge serial number |
;	+-------------------------------------------------------------+
;	| zeroes                                                      |
;	+-------------------------------------------------------------+
;	| zeroes                                                      |
;	+-------------------------------------------------------------+
;	| 1st bad sector entry (cylinder)                             |
;	+-------------------------------------------------------------+
;	| 1st bad sector entry (head, sector)                         |
;	+-------------------------------------------------------------+
;	...
;	+-------------------------------------------------------------+
;	| 125th bad sector entry (cylinder)                           |
;	+-------------------------------------------------------------+
;	| 125th bad sector entry (head, sector)                       |
;	+-------------------------------------------------------------+
;	| all ones                                                    |
;	+-------------------------------------------------------------+
;	| all ones                                                    |
;	+-------------------------------------------------------------+
;	...
;	+-------------------------------------------------------------+
;	| all ones                                                    |
;	+-------------------------------------------------------------+
;	| all ones                                                    |
;	+-------------------------------------------------------------+
;
initpar090:
	lds	r18, attpart
	ori	r18, '0'
	sts	pprint+0, r18
	call	print
	.db	"Partition ", 0x90, " not found", 0x0d, 0x0a, 0x00
	clc
	ret

initpar:
	lds	r24, attpart
	rcall	findpart
	adiw	r25:r24, 0
	breq	initpar090
	movw	yh:yl, r25:r24
	sbrc	r18, pcb__attach
	rjmp	initpar091				; Must not be attached
	sbrc	r18, pcb__idle
	rjmp	initpar092				; Must have a valid partition type

;
;	Get Drive Type
;
	ldd	zl, Y+pcb_drvtab+0		; Get pointer to drive table
	ldd	zh, Y+pcb_drvtab+1
	subi	zl, low(-Drv_Size)
	sbci	zh, high(-Drv_Size)
	ldd	xl, Z+Drv_Capacity+0
	ldd	xh, Z+Drv_Capacity+1		; Get lower 16 bit of drive size
	subi	xl, low(20)
	sbci	xh, high(20)			; Last track is equivalent to 20 sectors

	movw	Z, Y				; Save partition control block pointer
	ldi	yl, low(sdio)		; Prepare IO control block
	ldi	yh, high(sdio)

	ldi	r18, low(sdbuffer)
	std	Y+P_Address+0, r18
	ldi	r18, high(sdbuffer)
	std	Y+P_Address+1, r18

	ldd	r18, Z+pcb_start+0		; Copy partition start sector
	add	r18, xl
	std	Y+P_Sector+0, r18	
	ldd	r18, Z+pcb_start+1
	adc	r18, xh
	std	Y+P_Sector+1, r18	
	ldd	r18, Z+pcb_start+2
	adc	r18, zero
	std	Y+P_Sector+2, r18	
	ldd	r18, Z+pcb_start+3
	adc	r18, zero
	std	Y+P_Sector+3, r18	


	clr	r17
	ldd	Xl, Y+P_Address+0
	ldd	xh, Y+P_Address+1
	ldi	r18, 0xff
	
initpar010:					; Initialize the block buffer with all ones
	st	X+, r18
	st	X+, r18
	dec	r17
	brne	initpar010

	ldi	r17, 10				; Repeat 10 times

	ldd	r18, Y+P_Sector+0		; Get sector for output messages
	sts	pprint+0, r18
	ldd	r18, Y+P_Sector+1
	sts	pprint+1, r18
	ldd	r18, Y+P_Sector+2
	sts	pprint+2, r18
	ldd	r18, Y+P_Sector+3
	sts	pprint+3, r18		

initpar020:
	rcall	initparbsfa			; Part A : Serial Number
	call	SD_CARD_WRITE
	call	print
	.db	"Init Par: Write A Sector 0x", 0x83, 0x82, 0x81, 0x80, 0x0d, 0x0a, 0x00
	call	initparinc

	rcall	initparbsfb			; Part B : All Ones
	call	SD_CARD_WRITE
	call	print
	.db	"Init Par: Write B Sector 0x", 0x83, 0x82, 0x81, 0x80, 0x0d, 0x0a, 0x00
	call	initparinc
	

	dec	r17
	brne	initpar020
	clc
	ret	

initpar091:
	lds	r18, attpart
	ori	r18, '0'
	sts	pprint+0, r18
	call	print
	.db	"Partition ", 0x90, " is attached", 0x0d, 0x0a, 0x00
	clc
	ret

initpar092:
	lds	r18, attpart
	ori	r18, '0'
	sts	pprint+0, r18
	call	print
	.db	"Partition ", 0x90, " is idle", 0x0d, 0x0a, 0x00
	clc
	ret
;
;	Write bad sector file section A  inlcuding hex encoded version and issue date
;	as the serial number as hex digits VVYYMMDD
;
initparbsfa:
	ldi	r18, 0x23			; VV	Version 2.3	
	sts	sdbuffer+0, r18
	ldi	r18, 0x19			; YY	Year 19 (for 2019)
	sts	sdbuffer+1, r18
	ldi	r18, 0x07			; MM	Month 07
	sts	sdbuffer+2, r18
	ldi	r18, 0x31			; DD	Day 31
	sts	sdbuffer+3, r18
	sts	sdbuffer+4, zero
	sts	sdbuffer+5, zero
	sts	sdbuffer+6, zero
	sts	sdbuffer+7, zero
	ret
;
;	Write bad sector file section B (all ones)
;	
	ldi	r18, 0xFF
initparbsfb:
	sts	sdbuffer+0, r18
	sts	sdbuffer+1, r18
	sts	sdbuffer+2, r18
	sts	sdbuffer+3, r18
	sts	sdbuffer+4, r18
	sts	sdbuffer+5, r18
	sts	sdbuffer+6, r18
	sts	sdbuffer+7, r18
	ret
;
;	Increment Sector
;
initparinc:
	ldd	r18, Y+P_Sector+0
	subi	r18, byte1(-1)
	sts	pprint+0, r18
	std	Y+P_Sector+0, r18
	ldd	r18, Y+P_Sector+1
	sbci	r18, byte2(-1)
	sts	pprint+1, r18
	std	Y+P_Sector+1, r18
	ldd	r18, Y+P_Sector+2
	sbci	r18, byte3(-1)
	sts	pprint+2, r18
	std	Y+P_Sector+2, r18
	ldd	r18, Y+P_Sector+3
	sbci	r18, byte4(-1)

	sts	pprint+3, r18
	std	Y+P_Sector+3, r18
	ret
