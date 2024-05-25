;----------------------------------------------------------------------------
;
;	To improve the performance first SD_CARD_TURBO has been written that  
;	interleaves reading the bytes from the SD-Card with the DMA. This     
;	already decreases the average time to transfer a block from 5ms to    
;	4ms. To further decrease the time we need to use the read multiple    
;	block command. However we will have to limit it to partitions or      
;	contiguous files.                                                     
;
;	Read Multiple Block (CMD18) reads consecutive blocks from the SD-Card 
;	until the transfer is stopped with CMD12. As with read block you first
;	send the command with the starting block number and then you have to  
;	wait for the data token. After the date token follow 512bytes of data 
;	and the 16-bit CRC. Then you have to wait again for a data token and  
;	so on. To stop the sequence you can send a command CMD12 at any time  
;	(even in the middle of a block) once the command has been sent one    
;	byte must be retrieved from the SD-Card which must be discarded. Then 
;	the SD-Card must be polled für a completion of CMD12 which should     
;	require 16 or less polls. In this routine we use the SPI buffered     
;	mode. In this mode we can always retrieve 2bytes in a row as we have a
;	transmit and a receive buffer register. This allows to interleave the 
;	receiption of two data bytes from the SD-Card via SPI with the DMA    
;	write of the previous two bytes (aka word). This is achieved by       
;       immediately writing two dummy bytes (0xFF) to the SPI data register   
;	after we have read the previous requested two bytes. The SPI interface
;	will start sending the two dummy bytes and thus retrieve the next two 
;	bytes, in the meantime the program starts a DMA write with the        
;	previous word. 
;
;----------------------------------------------------------------------------
;
;	Wrap writing dummy bytes into a macro as it seems we need to make 
;	sure we check DRE
;
.macro	stspi
l1:
	lds	r18, SPI1_INTFLAGS
	sbrs	r18, SPI_DREIF_bp
	rjmp	l1
	ldi	r18, 0xff
	sts	SPI1_DATA, r18
.endmacro
;
;	Wrap reading data as well into a macro. The two marcro's are used
;	during the transfer where we use 16-bit transfers form the SD-Card
;	to the MCU
;
.macro	ldspi
l1:
	lds	r18, SPI1_INTFLAGS	; Wait until we have a byte to read
	sbrs	r18, SPI_RXCIF_bp
	rjmp	l1			; Wait for first byte received
	lds	@0, SPI1_DATA
.endmacro
;
;
;
SD_CARD_MULTIPLE:
	push	r4			; Save Registers
	push	r5
	push	yl
	push	yh
	movw	yh:yl, r25:r24		; Copy Parameter Block Address
	rcall	SPI_transfer_dummy	;
	cbi	b_SS			;
	rcall	SD_setupTimer		; Reset Timer to zero
	rcall	SPI_transfer_dummy	;
	push	r0;6			; Create 6 byte Buffer for SD-Card Command
	push	r0;5
	push	r0;4
	push	r0;3
	push	r0;2
	in	zl, CPU_SPL
	in	zh, CPU_SPH		; this points to where the command will go
	ldi	r18, CMD18		; Read Multiple Block Command
	push	r18;1
	rcall	SD_setBlock		; Set Block Number
	movw	r25:r24, zh:zl		;
	rcall	SD_command		; Send Command
	pop	r18;1			; Unwind buffer
	pop	r18;2
	pop	r18;3
	pop	r18;4
	pop	r18;5
	pop	r18;6
	clr	zl
	clr	zh
	rcall	SD_readRes1		; Get R1 result
	cpi	r24, SD_READY		; Was it ok
	breq	SD_CARD_MULTIPLE010	; yes -> continue
	std	Y+P_Error, r24
	ldi	r24, SD_ERR_CMD_REJ	; Command rejected
	rjmp	SD_CARD_MULTIPLE999	; Error exit
SD_CARD_MULTIPLE010:			; Read Timeout 100ms
	ldi	xl, low(SD_MAX_READ_ATTEMPTS)
	ldi	xh, high(SD_MAX_READ_ATTEMPTS)
SD_CARD_MULTIPLE020:
	rcall	SPI_transfer_dummy	;
	cpi	r24, SD_START_TOKEN	; Data Token?
	breq	SD_CARD_MULTIPLE040	; We got one proceed with reading data
	cpi	r24, 0xFF		; Still Busy
	breq	SD_CARD_MULTIPLE030	; Yes try another one
	std	Y+P_Error, r24		; Save Error
	ldi	r24, SD_ERR_INV_TOKEN	; Report invalid Token
	rjmp	SD_CARD_MULTIPLE999	; Error exit
SD_CARD_MULTIPLE030:
	ldi	r24, low(0)		; Delay for 1ms, setting delay to zero means
	ldi	r25, high(0)		; a delay between 0 and 1ms. Depending when
	call	delay			; the tick timer intercepts the delay so
	sbiw	xh:xl, 1		; in a loop most of the times this is 1ms
	brne	SD_CARD_MULTIPLE020	; still another delay allowed
	ldi	r24, SD_ERR_NO_TOKEN	; Report no Token received within time-out
	rjmp	SD_CARD_MULTIPLE999
SD_CARD_MULTIPLE040:
	ldd	xl, Y+P_Wordcount+0	; Get Word Count
	ldd	xh, Y+P_Wordcount+1	;
	lds	r17, SPI1_CTRLA
	sts	SPI1_CTRLA, zero
	lds	r18, SPI1_CTRLB
	sbr	r18, SPI_BUFEN_bm	; Set SPI buffered mode so we can do the
	sts	SPI1_CTRLB, r18		; transfer in 16-bit chunks
	sts	SPI1_CTRLA, r17
	ldd	r16, Y+P_Flag		; Possibly skip the first RL01/02
	sbrs	r16, P__Skip		; sector in first block
	rjmp	SD_CARD_MULTIPLE080	; no read starts at a even RL01/02 sector
	clr	r4			; prepare CRC and block word count
	clr	r5			; in this case just to skip first half of it
	clr	r19
SD_CARD_MULTIPLE050:
	stspi
	stspi
	ldspi	r16
	ldspi	r17
	crc	r16, r4, r5		;
	crc	r17, r4, r5		;
	inc	r19			;
	brpl	SD_CARD_MULTIPLE050	; And skip 128 words
	rjmp	SD_CARD_MULTIPLE090	; Continue to transfer 2nd half of block
;
;	Entry point to read one full block, so first initialise CRC and block
;	word count, this is also the start when reading the next block so we
;	have to do it always
;
SD_CARD_MULTIPLE080:			; Start transferring a full block
	clr	r4
	clr	r5
	clr	r19
SD_CARD_MULTIPLE090:			; Continue 
	stspi
	stspi
SD_CARD_MULTIPLE100:
	ldspi	r16
	ldspi	r17
	stspi
	stspi
	#if cpldif==40	
	cli				;
	cbi	b_RS0			; Write DMA Data Register
	sbi	b_RS1			;
	cbi	b_RS2			;
	out	dataportout, r16	;
	sbi	b_WR			;
	cbi	b_WR			;
	sbi	b_RS0			;
	out	dataportout, r17	;
	sbi	b_WR			;
	cbi	b_WR			;
	sei				;
	#endif
	#if cpldif==22
	cli				;
	ldi	r18, 2			; Write DMA Data Register
	out	dataportout, r18	;
	sbi	b_ALEW			;
	cbi	b_ALEW			;
	out	dataportout, r16	;
	sbi	b_WR			;
	cbi	b_WR			;
	out	dataportout, r17	;
	sbi	b_WR			;
	cbi	b_WR			;
	sei				;
	#endif
	sbi	b_DMR			; In the meantime we start the DMA
	ldi	r18, dmatmo		;
	crc	r16, r4, r5		; During DMA we first calculate the CRC
	crc	r17, r4, r5		; each byte requires 11 cycles
SD_CARD_MULTIPLE120:			;
	dec	r18			; Then we wait for the DMA to finish or
	sbis	i_DMG			; time-out
	brne	SD_CARD_MULTIPLE120	; executed as long DMA is active
	brne	SD_CARD_MULTIPLE130	; branch is only taken if no time-out occured
	cbi	b_DMR			; de-assert DMA request
	nop
	sbi	b_ABO			; abort DMA
	cbi	b_ABO
	ldi	r24, SD_ERR_NXM		; Non-existant memory error
	rjmp	SD_CARD_MULTIPLE170	;
SD_CARD_MULTIPLE130:
	cbi	b_DMR			; Acknowledge state machine
	adiw	xh:xl, 1		; Wordcount
	brne	SD_CARD_MULTIPLE135
	ldi	r24, SD_SUCCESS	
	rjmp	SD_CARD_MULTIPLE170	;
SD_CARD_MULTIPLE135:
	inc	r19			; do another word
	breq	SD_CARD_MULTIPLE140
	rjmp	SD_CARD_MULTIPLE100
SD_CARD_MULTIPLE140:
	ldspi	r17			; Retrieve CRC-16, high-byte first
	ldspi	r16
	cp	r4, r16			; Match?
	cpc	r5, r17			; 
	breq	SD_CARD_MULTIPLE160	; CRC matches
	ldd	r16, Y+P_Flag
	sbrc	r16, P__Nocheck		; 
	rjmp	SD_CARD_MULTIPLE160	; We don't care about CRC
	logtr	0x77, r4, r5
	logtr	0x78, r16, r17
	ldi	r24, SD_ERR_CRC		; oh no CRC error
	rjmp	SD_CARD_MULTIPLE180	; 
;
;	Wait for next data token
;
SD_CARD_MULTIPLE160:
	ldi	r18, 0xFF
	sts	SPI1_DATA, r18
SD_CARD_MULTIPLE165:
	lds	r18, SPI1_INTFLAGS
	sbrs	r18, SPI_RXCIF_bp
	rjmp	SD_CARD_MULTIPLE165
	lds	r16, SPI1_DATA
	cpi	r16, 0xFF		; Still Busy
	breq	SD_CARD_MULTIPLE160	; Yes try another one
	ldi	r24, SD_ERR_INV_TOKEN	; Assume invalid Token
	cpi	r16, SD_START_TOKEN	; Data Token?
	brne	SD_CARD_MULTIPLE180	; not good
	rjmp	SD_CARD_MULTIPLE080	; Got a token get next block
;
;	Retrieve the two pending bytes before we proceed
;
SD_CARD_MULTIPLE170:			; remove 2 bytes
	ldspi	r16
	ldspi	r16
SD_CARD_MULTIPLE180:
	mov	r4, r24			; Save Return Code
	std	Y+P_Wordcount+0, xl	; Return Remaining Word Count
	std	Y+P_Wordcount+1, xh
	logtr	0x79, xl, xh
	lds	r17, SPI1_CTRLA		; Reset Buffered Mode
	sts	SPI1_CTRLA, zero
	lds	r18, SPI1_CTRLB
	cbr	r18, SPI_BUFEN_bm
	sts	SPI1_CTRLB, r18
	sts	SPI1_CTRLA, r17
	clr	r18
	push	r18;6
	push	r18;5
	push	r18;4
	push	r18;3
	push	r18;2
	in	zl, CPU_SPL
	in	zh, CPU_SPH		; this points to where next r18 will go
	push	r18;1
	ldi	r18, CMD12		; Stop Commands
	std	Z+0, r18
	movw	r25:r24, zh:zl
	rcall	SD_command		; Send Command
	pop	r18;1
	pop	r18;2
	pop	r18;3
	pop	r18;4
	pop	r18;5
	pop	r18;6
	ldi	r18, 0x0ff
	sts	SPI1_DATA, r18		; Send dummy byte
SD_CARD_MULTIPLE200:
	lds	r18, SPI1_INTFLAGS	; Just ommit next byte
	sbrs	r18, SPI_RXCIF_bp
	rjmp	SD_CARD_MULTIPLE200
	lds	r16, SPI1_DATA
	ldi	r19, 16			; We expect a status within 16 bytes
SD_CARD_MULTIPLE210:
	rcall	SD_readRes1		; Get R1 result
	tst	r24			; Yes command finished successfully
	brpl	SD_CARD_MULTIPLE220	; there was some error
	dec	r19
	brne	SD_CARD_MULTIPLE210	; Still busy try another one
SD_CARD_MULTIPLE220:
	tst	r24			; 
	breq	SD_CARD_MULTIPLE999	; Do not overwrite status in r4
	ldi	r24, SD_ERROR		; Assume yes
	mov	r4, r24			; General Error
SD_CARD_MULTIPLE999:
	rcall	SPI_transfer_dummy
	sbi	b_SS
	rcall	SD_readTimer		; And insert timer to IOStatus
	rcall	SPI_transfer_dummy
	mov	r24, r4
	pop	yh
	pop	yl
	pop	r5
	pop	r4
	ret
