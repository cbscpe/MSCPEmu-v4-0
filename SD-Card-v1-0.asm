;=============================================================================
;
;	SPI 1 primitives
;
SPI_init:
	ldi	r18, SPI_SSD_bm
	sts	SPI1_CTRLB, r18
;
;	Various Clock rates: CPUCLK/2, CPUCLK/4, CPUCLK/8
;
;	ldi	r18, SPI_CLK2X_bm | SPI_ENABLE_bm | SPI_MASTER_bm | SPI_PRESC_DIV4_gc
	ldi	r18,                SPI_ENABLE_bm | SPI_MASTER_bm | SPI_PRESC_DIV4_gc
;	ldi	r18, SPI_CLK2X_bm | SPI_ENABLE_bm | SPI_MASTER_bm | SPI_PRESC_DIV16_gc
	sts	SPI1_CTRLA, r18		
	sts	sd_status, zero
	ret
;
;
;
SPI_transfer_dummy:
	ldi	r24, 0xff
SPI_transfer:
	sts	SPI1_DATA, r24
SPI_transfer010:
	lds	r24, SPI1_INTFLAGS
	sbrs	r24, SPI_IF_bp
	rjmp	SPI_transfer010
	lds	r24, SPI1_DATA
	ret								; Done
;=============================================================================
;
;	Command DEFs
;
#define CMD0 0
#define CMD0_ARG 0x00000000
#define CMD0_CRC 0x94
#define CMD8 8
#define CMD8_ARG 0x0000001AA
#define CMD8_CRC 0x86
#define CMD9 9
#define CMD9_ARG 0x000000000
#define CMD9_CRC 0xEA
#define CMD58 58
#define CMD58_ARG 0x00000000
#define CMD58_CRC 0xFC
#define CMD55 55
#define CMD55_ARG 0x00000000
#define CMD55_CRC 0x64
#define ACMD41 41
#define ACMD41_ARG 0x40000000
#define ACMD41_CRC 0x76
;=============================================================================
;
;	SD-Card primitive
;
;-----------------------------------------------------------------------------
;
;	Read R1 response
;
;	The R1 response is expected within the next 8 SPI cycles, that is
;	we will try 9 times to get an answer from the SD-Card. When the
;	card responds with something else than 0xFF we return or after the
;	9th try we return whatever the SD-Card returns.
;
SD_readRes1:
; uint8_t SD_readRes1();
	rcall	SPI_transfer_dummy
	cpi	r24, 0xff
	brne	SD_readRes090
	rcall	SPI_transfer_dummy
	cpi	r24, 0xff
	brne	SD_readRes090
	rcall	SPI_transfer_dummy
	cpi	r24, 0xff
	brne	SD_readRes090
	rcall	SPI_transfer_dummy
	cpi	r24, 0xff
	brne	SD_readRes090
	rcall	SPI_transfer_dummy
	cpi	r24, 0xff
	brne	SD_readRes090
	rcall	SPI_transfer_dummy
	cpi	r24, 0xff
	brne	SD_readRes090
	rcall	SPI_transfer_dummy
	cpi	r24, 0xff
	brne	SD_readRes090
	cpi	r24, 0xff
	brne	SD_readRes090
	rcall	SPI_transfer_dummy
SD_readRes090:
	ret
;-----------------------------------------------------------------------------
;
;	Read R3/R7 response
;	
;	First we will read a R1 response and only if the response is either
;	0 or 1 we will continue to read the remaining 5bytes from the R3/R7
;	response
;
SD_readRes3_7:
; void SD_readRes3_7(unit8_t *res)
SD_readRes7:
; void SD_readRes7(uint8_t *res);
	movw	zh:zl, r25:r24
	rcall	SD_readRes1
	std	Z+0, r24
	cpi	r24, 2
	brsh	SD_readRes7090
	rcall	SPI_transfer_dummy
	std	Z+1, r24
	rcall	SPI_transfer_dummy
	std	Z+2, r24
	rcall	SPI_transfer_dummy
	std	Z+3, r24
	rcall	SPI_transfer_dummy
	std	Z+4, r24
	rcall	SPI_transfer_dummy
	std	Z+5, r24
SD_readRes7090:
	ret
;-----------------------------------------------------------------------------
;
;	SD Power UP Sequence
;
;	1.	Deselect SD-Card
;	2.	Wait for 1 msec
;	3.	create at least 80 dummy SPI clock cycles
;	4.	Deselect SD-Card
;	5.	Send dummy data
;
SD_powerUpSeq:
	sbi	b_SS
	ldi	r24, low(1)
	ldi	r25, high(1)
	call	delay
	rcall	SPI_transfer_dummy
	rcall	SPI_transfer_dummy
	rcall	SPI_transfer_dummy
	rcall	SPI_transfer_dummy
	rcall	SPI_transfer_dummy
	rcall	SPI_transfer_dummy
	rcall	SPI_transfer_dummy
	rcall	SPI_transfer_dummy
	rcall	SPI_transfer_dummy
	rcall	SPI_transfer_dummy
	sbi	b_SS
	rcall	SPI_transfer_dummy
	ret
;-----------------------------------------------------------------------------
;
;	Send a Command to the SD-Card
;
;	- now with built-in crc-7 calculation	
;
SD_command:
; void SD_command(uint8_t *cmd); !! rjh (uint8_t cmd, uint32_t arg, uint8_t crc);
	push	r25
	push	r24
	rcall	SD_commandCRC		; Calculate CRC-7
	pop	zl
	pop	zh
	std	Z+5, r24		; Save CRC
	ldd	r24, Z+0
	ori	r24, 0x40		; Bit7=0, Bit6=1, Bit5..0 6-bit command
	rcall	SPI_transfer
	ldd	r24, Z+1
	rcall	SPI_transfer
	ldd	r24, Z+2
	rcall	SPI_transfer
	ldd	r24, Z+3
	rcall	SPI_transfer
	ldd	r24, Z+4
	rcall	SPI_transfer
	ldd	r24, Z+5
	ori	r24, 0x01		; Stop bit
	rcall	SPI_transfer
	ret
;
;	Calculate CRC-7 left adjusted as required by SD-Card
;
SD_commandCRC:
; uint8_t SD_commandCRC(uint8_t *cmd)
	movw	xh:xl, r25:r24
	ldi	r24, 0x40		; Initiate CRC with start of Bit7=0, Bit6=1
	ldi	r16, 5			; 5 bytes
SD_commandCRC010:
	ld	r17, X+			; Get Next Command byte
	eor	r24, r17		; xor
	mov	zl, r24			; make index
	ldi	zh, high(2*crc7table)	; translate
	lpm	r24, Z			; new CRC
	dec	r16
	brne	SD_commandCRC010
	ret				; r24 contains CRC7 left-adjusted
;-----------------------------------------------------------------------------
;
;	Send Various commands
;
#define CMD12 12
#define CMD17 17
#define CMD18 18
#define SD_MAX_READ_ATTEMPTS 100

#define CMD24 24
#define SD_MAX_WRITE_ATTEMPTS 250

#define SD_READY	0x00
#define SD_START_TOKEN	0xFE
;
;-----------------------------------------------------------------------------
;
;	Send a Commands to the SD-Card and print results
;
SD_goIdleState:; uint8_t SD_goIdleState();
	rcall	SPI_transfer_dummy
	cbi	b_SS
	rcall	SPI_transfer_dummy
	;+parameter on stack
	ldi	r18, CMD0_CRC
	push	r18
	ldi	r18, byte1(CMD0_ARG)
	push	r18
	ldi	r18, byte2(CMD0_ARG)
	push	r18
	ldi	r18, byte3(CMD0_ARG)
	push	r18
	ldi	r18, byte4(CMD0_ARG)
	push	r18
	in	r24, CPU_SPL
	in	r25, CPU_SPH
	ldi	r18, CMD0
	push	r18
	rcall	SD_command
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	;-parameter on stack
	rcall	SD_readRes1
	push	r24
	rcall	SPI_transfer_dummy
	sbi	b_SS
	rcall	SPI_transfer_dummy
	pop	r24
	ret

SD_sendIfCond:;void SD_sendIfCond(uint8_t *res)
	push	r24
	push	r25
	rcall	SPI_transfer_dummy
	cbi	b_SS
	rcall	SPI_transfer_dummy
	;+parameter on stack
	ldi	r18, CMD8_CRC
	push	r18
	ldi	r18, byte1(CMD8_ARG)
	push	r18
	ldi	r18, byte2(CMD8_ARG)
	push	r18
	ldi	r18, byte3(CMD8_ARG)
	push	r18
	ldi	r18, byte4(CMD8_ARG)
	push	r18
	in	r24, CPU_SPL
	in	r25, CPU_SPH
	ldi	r18, CMD8
	push	r18
	rcall	SD_command
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	;-parameter on stack
	pop	r25
	pop	r24
	rcall	SD_readRes7
	rcall	SPI_transfer_dummy
	sbi	b_SS
	rcall	SPI_transfer_dummy
	ret	
	
SD_readOCR:; void SD_readOCR(uint8_t *res)
	push	r24
	push	r25
	rcall	SPI_transfer_dummy
	cbi	b_SS
	rcall	SPI_transfer_dummy
	;+parameter on stack
	ldi	r18, CMD58_CRC
	push	r18
	ldi	r18, byte1(CMD58_ARG)
	push	r18
	ldi	r18, byte2(CMD58_ARG)
	push	r18
	ldi	r18, byte3(CMD58_ARG)
	push	r18
	ldi	r18, byte4(CMD58_ARG)
	push	r18
	in	r24, CPU_SPL
	in	r25, CPU_SPH
	ldi	r18, CMD58
	push	r18
	rcall	SD_command
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	;-parameter on stack
	pop	r25
	pop	r24
	rcall	SD_readRes3_7
	rcall	SPI_transfer_dummy
	sbi	b_SS
	rcall	SPI_transfer_dummy
	ret
	
SD_sendApp:; uint8_t SD_sendApp()
	rcall	SPI_transfer_dummy
	cbi	b_SS
	rcall	SPI_transfer_dummy
	;+parameter on stack
	ldi	r18, CMD55_CRC
	push	r18
	ldi	r18, byte1(CMD55_ARG)
	push	r18
	ldi	r18, byte2(CMD55_ARG)
	push	r18
	ldi	r18, byte3(CMD55_ARG)
	push	r18
	ldi	r18, byte4(CMD55_ARG)
	push	r18
	in	r24, CPU_SPL
	in	r25, CPU_SPH
	ldi	r18, CMD55
	push	r18
	rcall	SD_command
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	;-parameter on stack
	rcall	SD_readRes1
	push	r24
	rcall	SPI_transfer_dummy
	sbi	b_SS
	rcall	SPI_transfer_dummy
	pop	r24
	ret
	
SD_sendOpCond:; uint8_t SD_sendOpCond()
	rcall	SPI_transfer_dummy
	cbi	b_SS
	rcall	SPI_transfer_dummy
	;+parameter on stack
	ldi	r18, ACMD41_CRC
	push	r18
	ldi	r18, byte1(ACMD41_ARG)
	push	r18
	ldi	r18, byte2(ACMD41_ARG)
	push	r18
	ldi	r18, byte3(ACMD41_ARG)
	push	r18
	ldi	r18, byte4(ACMD41_ARG)
	push	r18
	in	r24, CPU_SPL
	in	r25, CPU_SPH
	ldi	r18, ACMD41
	push	r18
	rcall	SD_command
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	;-parameter on stack
	rcall	SD_readRes1
	push	r24
	rcall	SPI_transfer_dummy
	sbi	b_SS
	rcall	SPI_transfer_dummy
	pop	r24
	ret
;=============================================================================
;
;	Monitor Test Routines
;
SD_main:
	push	r5
	push	r4			; Call saved register
	rcall	SD_powerUpSeq
	call	print
	.db	"Sending CMD0...", CR, LF, "Response:", CR, LF, 0, 0
	rcall	SD_goIdleState
	rcall	SD_print_R1
	call	print
	.db	"Sending CMD8...", CR, LF, "Response:", CR, LF, 0, 0
;
;	To prepare a response buffer on stack we need to know that
;	pop	stack pointer is pre-incremented
;	push	stack pointer is post-decremented
;
	push	r0;6
	push	r0;5
	push	r0;4
	push	r0;3
	push	r0;2
	lds	r4, CPU_SPL
	lds	r5, CPU_SPH		; this points to where r0 will go
	push	r0;1
	movw	r25:r24, r5:r4		; Buffer Address
	rcall	SD_sendIfCond
	movw	r25:r24, r5:r4		; Buffer Address
	rcall	SD_print_R7
	movw	zh:zl, r5:r4
	ldd	r18, Z+0		;
	ldi	r24, (1<<sd__v2)	; Assume Version 2 or later
	sbrc	r18, ILLEGAL_CMD
	ldi	r24, (1<<sd__v1)	; Version 1 Card
	sts	sd_status, r24
	call	print
	.db	"Sending CMD58...", CR, LF, "Response:", CR, LF, 0
	movw	r25:r24, r5:r4		; Buffer Address
	rcall	SD_readOCR
	movw	r25:r24, r5:r4		; Buffer Address
	rcall	SD_print_R3

	call	print
	.db	"Sending CMD55...", CR, LF, "Response:", CR, LF, 0
	rcall	SD_sendApp
	rcall	SD_print_R1
	call	print
	.db	"Sending ACMD41...", CR, LF, "Response:", CR, LF, 0, 0
	rcall	SD_sendOpCond
	rcall	SD_print_R1

	ldi	r16, 20
SD_main_loop:
	ldi	r24, low(100)
	ldi	r25, high(100)	
	call	delay
	
	call	print
	.db	"Sending CMD55...", CR, LF, "Response:", CR, LF, 0
	rcall	SD_sendApp
	rcall	SD_print_R1
	call	print
	.db	"Sending ACMD41...", CR, LF, "Response:", CR, LF, 0, 0
	rcall	SD_sendOpCond
	rcall	SD_print_R1

	sbrs	r24, IN_IDLE
	rjmp	SD_main_done
	dec	r16
	brne	SD_main_loop
	call	print
	.db	"Card did not become ready after 2 seconds", CR, LF, 0
	rjmp	SD_main_exit
SD_main_done:
	lds	r18, sd_status
	sbr	r18, (1<<sd__init)
	sts	sd_status, r18
	call	print
	.db	"Sending CMD58...", CR, LF, "Response:", CR, LF, 0
	movw	r25:r24, r5:r4		; Buffer Address
	rcall	SD_readOCR
	movw	r25:r24, r5:r4		; Buffer Address
	rcall	SD_print_R3
	movw	zh:zl, r5:r4		; Buffer Address
	ldd	r18, Z+1
	bst	r18, CCS_VAL
	lds	r18, sd_status
	bld	r18, sd__ccs
	sts	sd_status, r18
	
	call	print
	.db	"Sending CMD9...", CR, LF, "Response:", CR, LF, 0, 0
	ldi	r24, low(sdbuffer)
	ldi	r25, high(sdbuffer)
	rcall	SD_readCSD
	cpse	r24, zero
	rjmp	SD_main_exit
	ldi	r24, low(sdbuffer)
	ldi	r25, high(sdbuffer)
	rcall	SD_PRINT_CSD
	
	lds	r18, SPI1_INTFLAGS
	lds	r18, SPI1_DATA
	sts	SPI1_CTRLA, zero	; Disable
	ldi	r18,                SPI_ENABLE_bm | SPI_MASTER_bm | SPI_PRESC_DIV4_gc
	sts	SPI1_CTRLA, r18		; Re-enable at high speed
		
	rjmp	SD_main_exit
SD_main_exit:
	pop	r18;1
	pop	r18;2
	pop	r18;3
	pop	r18;4
	pop	r18;5
	pop	r18;6
	pop	r4
	pop	r5			; restore call saved register
	ret
	
SD_readCSD:
; void SD_readOCR(uint8_t *res)
	push	r4
	push	r5
	movw	r5:r4, r25:r24
	rcall	SPI_transfer_dummy
	cbi	b_SS
	rcall	SPI_transfer_dummy
	;+parameter on stack
	ldi	r18, CMD9_CRC
	push	r18
	ldi	r18, byte1(CMD9_ARG)
	push	r18
	ldi	r18, byte2(CMD9_ARG)
	push	r18
	ldi	r18, byte3(CMD9_ARG)
	push	r18
	ldi	r18, byte4(CMD9_ARG)
	push	r18
	in	r24, CPU_SPL
	in	r25, CPU_SPH
	ldi	r18, CMD9
	push	r18
	rcall	SD_command
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	;-parameter on stack
	rcall	SD_readRes1
	cpse	r24, zero
	rjmp	SD_readCSD090

SD_readCSD010:
	ldi	xl, low(SD_MAX_READ_ATTEMPTS)	; Read Timeout 100ms
	ldi	xh, high(SD_MAX_READ_ATTEMPTS)
SD_readCSD020:
	rcall	SPI_transfer_dummy
	cpi	r24, SD_START_TOKEN		; Data Token
	breq	SD_readCSD040
	cpi	r24, 0xFF			; Busy
	breq	SD_readCSD030
	sts	pprint+0, r24
	call	print
	.db	"Read CSD Invalid Data Token 0x", 0x80, CR, LF, 0
	rcall	SD_printDataErrToken		; Error
	ldi	r24, SD_ERR_INV_TOKEN
	rjmp	SD_readCSD099

SD_readCSD030:
	ldi	r24, low(0)
	ldi	r25, high(0)
	call	delay
	sbiw	xh:xl, 1
	brne	SD_readCSD020
	call	print
	.db	"Read CSD no Comand Token after max retries...", CR, LF, 0
	ldi	r24, SD_ERR_NO_TOKEN
	rjmp	SD_readCSD099

SD_readCSD040:
	ldi	xl, low(18)			; CSD=128bits=16bytes+2CRC
	ldi	xh, high(18)
	movw	zh:zl, r5:r4
SD_readCSD050:
	rcall	SPI_transfer_dummy
	st	Z+, r24
	sbiw	xh:xl, 1
	brne	SD_readCSD050
	ldi	r24, SD_SUCCESS
	rjmp	SD_readCSD099
	
SD_readCSD090:
	call	print
	.db	"Read CSD command response error... ", CR, LF, 0
	rcall	SD_print_R1
	ldi	r24, SD_ERROR
SD_readCSD099:
	push	r24
	rcall	SPI_transfer_dummy
	sbi	b_SS
	rcall	SPI_transfer_dummy
	pop	r24
	pop	r5
	pop	r4
	ret	

;-----------------------------------------------------------------------------
;
;	Read one block
;
;	r25:r24	IO-controll block
;
SD_sendRead:				; With Messages
	set
	cpse	zero, zero
SD_CARD_READ:				; w/o Messages
	clt
	push	yl
	push	yh
	movw	yh:yl, r25:r24		; Copy Parameter Block Address
	rcall	SPI_transfer_dummy
	cbi	b_SS
	rcall	SD_setupTimer
	rcall	SPI_transfer_dummy
;
;	To prepare the command parameter on stack we need to know that
;	pop	stack pointer is pre-incremented
;	push	stack pointer is post-decremented
;
	push	r0;6
	push	r0;5
	push	r0;4
	push	r0;3
	push	r0;2
	in	zl, CPU_SPL
	in	zh, CPU_SPH		; this points to where r0 will go
	push	r0;1
	ldi	r18, CMD17
	std	Z+0, r18
	rcall	SD_setBlock
	brtc	SD_sendNoMsg
	call	print
	.db	"Sending CMD17 (read)...", CR, LF, 0
SD_sendNoMsg:
	movw	r25:r24, zh:zl
	rcall	SD_command

	pop	r18;1
	pop	r18;2
	pop	r18;3
	pop	r18;4
	pop	r18;5
	pop	r18;6

	rcall	SD_readRes1
	cpi	r24, SD_READY
	breq	SD_sendRead030
;--	call	print
;--	.db	"Read Comand rejected...", CR, LF, 0
;--	rcall	SD_print_R1
	std	Y+P_Error, r24
	ldi	r24, SD_ERR_CMD_REJ
	rjmp	SD_sendRead999

SD_sendRead030:
	ldi	xl, low(SD_MAX_READ_ATTEMPTS)	; Read Timeout 100ms
	ldi	xh, high(SD_MAX_READ_ATTEMPTS)
SD_sendRead040:
	rcall	SPI_transfer_dummy
	cpi	r24, SD_START_TOKEN	; Data Token
	breq	SD_sendRead060
	cpi	r24, 0xFF		; Busy
;--	breq	SD_sendRead040
	breq	SD_sendRead050
;--	rcall	SD_printDataErrToken	; Error
	std	Y+P_Error, r24
	ldi	r24, SD_ERR_INV_TOKEN
	rjmp	SD_sendRead999

SD_sendRead050:
;
;	Delay is at least nnn milli-seconds. But when in a short loop
;	as here this turns to be almost nnn+1 milli-seconds. Therefore
;	we use 0 as the delay that in all but the first time will be
;	one milli-second
;
	ldi	r24, low(0)
	ldi	r25, high(0)
	call	delay
	sbiw	xh:xl, 1
	brne	SD_sendRead040
;--	call	print
;--	.db	"Read no Comand Token after max retries...", CR, LF, 0
	ldi	r24, SD_ERR_NO_TOKEN
	rjmp	SD_sendRead999

SD_sendRead060:
	push	r4
	push	r5
	clr	r4
	clr	r5
	ldd	xl, Y+P_Address+0
	ldd	xh, Y+P_Address+1
	ldi	r24, low(512)
	ldi	r25, high(512)
	ldi	r16, 0xFF
	sts	SPI1_DATA, r16
SD_sendRead080:
	lds	r18, SPI1_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	SD_sendRead080
	lds	r18, SPI1_DATA
	sts	SPI1_DATA, r16		; Next dummy byte
	st	X+, r18
	crc	r18, r4, r5
	sbiw	r25:r24, 1
	brne	SD_sendRead080
	
SD_sendRead081:
	lds	r18, SPI1_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	SD_sendRead081
	lds	r25, SPI1_DATA
	sts	SPI1_DATA, r16		; Next dummy byte
	
SD_sendRead082:
	lds	r18, SPI1_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	SD_sendRead082
	lds	r24, SPI1_DATA
	cp	r4, r24		;
	cpc	r5, r25
	pop	r5
	pop	r4
	ldi	r24, SD_SUCCESS
	breq	SD_sendRead999		; if CRC matches
	
	ldi	r24, SD_ERR_CRC		; CRC does not match
SD_sendRead999:
	push	r24
	rcall	SPI_transfer_dummy
	sbi	b_SS
	rcall	SD_readTimer
	rcall	SPI_transfer_dummy
	pop	r24
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;	Write Block
;
;	r25:r24	IO-controll block
;
SD_sendWrite:				; With messages
	set
	cpse	zero, zero
SD_CARD_WRITE:				; w/o messages
	clt
	push	yl
	push	yh
	movw	yh:yl, r25:r24		; Copy Parameter Block Address
	rcall	SPI_transfer_dummy
	cbi	b_SS
	rcall	SD_setupTimer
	rcall	SPI_transfer_dummy
;
;	To prepare the command parameter on stack we need to know that
;	pop	stack pointer is pre-incremented
;	push	stack pointer is post-decremented
;
	push	r0;6
	push	r0;5
	push	r0;4
	push	r0;3
	push	r0;2
	in	zl, CPU_SPL
	in	zh, CPU_SPH		; this points to where r0 will go
	push	r0;1
	ldi	r18, CMD24
	std	Z+0, r18
	rcall	SD_setBlock		; Set Parameter (Blocknumber/Address)
	movw	r25:r24, zh:zl
	rcall	SD_command		; Send Command

	pop	r18;1
	pop	r18;2
	pop	r18;3
	pop	r18;4
	pop	r18;5
	pop	r18;6

	rcall	SD_readRes1		; Send Command Response
	cpi	r24, SD_READY		; Must be 0x00
	breq	SD_sendWrite010
	ldi	r24, SD_ERR_CMD_REJ
	rjmp	SD_sendWrite999
	
SD_sendWrite010:
	ldi	r24, SD_START_TOKEN	; Start Data Token
	rcall	SPI_transfer		; Send it
	ldd	xl, Y+P_Address+0	; Buffer Address
	ldd	xh, Y+P_Address+1	
	ldi	r24, low(512)
	ldi	r25, high(512)

	push	r4
	push	r5
	clr	r4
	clr	r5


;
;	Non buffered mode
;
SD_sendWrite020:
	ld	r18, X+
	sts	SPI1_DATA, r18		; We assume all data has already been sent
SD_sendWrite021:
	lds	r18, SPI1_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	SD_sendWrite021
	sbiw	r25:r24, 1
	brne	SD_sendWrite020

	sts	SPI1_DATA, r5
SD_sendWrite022:
	lds	r18, SPI1_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	SD_sendWrite022

	sts	SPI1_DATA, r4
SD_sendWrite023:
	lds	r18, SPI1_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	SD_sendWrite023
	
;
;	SPI Buffered Mode
;
;		lds	r18, SPI1_CTRLB
;		ori	r18, SPI_BUFEN_bm | SPI_BUFWR_bm
;		sts	SPI1_CTRLB, r18
;
;		ld	r18, X+
;		sts	SPI1_DATA, r18		; Start filling buffer with 1st byte
;		crc	r18, r4, r5
;		sbiw	r25:r24, 1		; one byte done
;		rjmp	SD_sendWrite021
;
;	SD_sendWrite020:
;		lds	r18, SPI1_INTFLAGS	; First make sure we read the
;		sbrs	r18, SPI_RXCIF_bp	; byte received from the slave
;		rjmp	SD_sendWrite020		; off the receive buffer
;		lds	r18, SPI1_DATA
;
;	SD_sendWrite021:
;		ld	r18, X+
;		sts	SPI1_DATA, r18		; Send byte
;		crc	r18, r4, r5
;		sbiw	r25:r24, 1
;		brne	SD_sendWrite020		; until all bytes done
;
;	SD_sendWrite022:
;		lds	r18, SPI1_INTFLAGS	; First make sure we read the
;		sbrs	r18, SPI_RXCIF_bp	; byte received from the slave
;		rjmp	SD_sendWrite022		; off the receive buffer
;		lds	r18, SPI1_DATA
;		sts	SPI1_DATA, r5	
;
;	SD_sendWrite023:
;		lds	r18, SPI1_INTFLAGS	; First make sure we read the
;		sbrs	r18, SPI_RXCIF_bp	; byte received from the slave
;		rjmp	SD_sendWrite023		; off the receive buffer
;		lds	r18, SPI1_DATA
;		sts	SPI1_DATA, r4	
;
;	SD_sendWrite024:
;		lds	r18, SPI1_INTFLAGS	; First make sure we read the
;		sbrs	r18, SPI_RXCIF_bp	; byte received from the slave
;		rjmp	SD_sendWrite024		; off the receive buffer
;		lds	r18, SPI1_DATA
;
;	SPI Unbuffered Mode
;
;		lds	r18, SPI1_CTRLB		; Restore non-buffered mode
;		andi	r18, ~(SPI_BUFEN_bm | SPI_BUFWR_bm)
;		sts	SPI1_CTRLB, r18

	pop	r5
	pop	r4
	ldi	xl, low(SD_MAX_WRITE_ATTEMPTS)	
	ldi	xh, high(SD_MAX_WRITE_ATTEMPTS)
SD_sendWrite030:
	rcall	SPI_transfer_dummy	;
	cpi	r24, 0xFF		; Wait for data response which 
	brne	SD_sendWrite040		; has bit 4 cleared -> cannot be 0xFF
	ldi	r24, low(0)
	ldi	r25, high(0)
	call	delay
	sbiw	xh:xl, 1
	brne	SD_sendWrite030
	ldi	r24, SD_ERR_DATA_RSP_TMO
	rjmp	SD_sendWrite999

SD_sendWrite040:			;
	andi	r24, 0x1F		; Mask relevant bits
	cpi	r24, 0x05		; 'Data Accepted' ?
	breq	SD_sendWrite050		; Ok
	std	Y+P_Error, r24
	ldi	r24, SD_ERR_DATA_REJ
	rjmp	SD_sendWrite999

SD_sendWrite050:

	ldi	xl, low(SD_MAX_WRITE_ATTEMPTS)	
	ldi	xh, high(SD_MAX_WRITE_ATTEMPTS)
SD_sendWrite060:
	rcall	SPI_transfer_dummy	;
	cpi	r24, 0x00		; Get status
	brne	SD_sendWrite070		; still BUSY
	ldi	r24, low(0)		; 
	ldi	r25, high(0)
	call	delay
	sbiw	xh:xl, 1
	brne	SD_sendWrite060
	ldi	r24, SD_ERR_RDY_TMO
	rjmp	SD_sendWrite999

SD_sendWrite070:			; Done
	ldi	r24, SD_SUCCESS

SD_sendWrite999:
	push	r24
	rcall	SPI_transfer_dummy
	sbi	b_SS
	rcall	SD_readTimer
	rcall	SPI_transfer_dummy
	pop	r24
	pop	yh
	pop	yl
	ret
;
;	Translate PBN to SD-Card Address according to CCS
;
SD_setBlock:
	lds	r18, sd_status
	sbrs	r18, sd__ccs
	rjmp	SD_setBlock010
;
	ldd	r18, Y+P_Sector+0	; High Capacity Card
	std	Z+4, r18
	ldd	r18, Y+P_Sector+1
	std	Z+3, r18
	ldd	r18, Y+P_Sector+2
	std	Z+2, r18
	ldd	r18, Y+P_Sector+3
	std	Z+1, r18
	std	Z+5, zero
	ret
;
SD_setBlock010:
	std	Z+4, zero		; Standard Capacity Card
	ldd	r18, Y+P_Sector+0
	add	r18, r18
	std	Z+3, r18
	ldd	r18, Y+P_Sector+1
	adc	r18, r18
	std	Z+2, r18
	ldd	r18, Y+P_Sector+2
	adc	r18, r18
	std	Z+1, r18
	std	Z+5, zero
	ret
;=============================================================================
;
;	IO Time Measurement using Timer TCB1 
;
SD_setupTimer:
	sts	TCB1_CNTL, zero		; Just reset the count and let
	sts	TCB1_CNTH, zero		; the timer start with zero
	ret
;
;	Read Timer
;
;	P_Duration	int16
;
SD_readTimer:
	lds	r18, TCB1_CNTL		; Read the current count
	std	Y+P_Duration+0, r18	; value which is the duration
	lds	r18, TCB1_CNTH		; the IO operation took measured
	std	Y+P_Duration+1, r18	; in micro-seconds
	ret

