;--------------------------------------------------------------------------
;
;	SD-Card Turbo Read
;
;	Turbo Read interleaves the fetch of words from the SD-Card
;	and the DMA write of the word to the PDP-11 memory. As the
;	SPI clock is rather slow (F_CPU/4) we waste 32 cycles per
;	byte. Instead of this we use the buffered SPI mode and 
;	request two consecutive bytes (we write two dummy bytes
;	at once) and during the SPI fetches the next two bytes via
;	SPI we perform the DMA write of the previous word. This
;	saves approximatively 1ms per block, i.e. 4ms instead of
;	5ms. 
;
;	27-05-2022	New IOB Field P_Wordcount, which allows for
;			reading partial sectors and which is also
;			updated. If it is update to zero the
;			caller knows that the whole transfer has
;			been finished.
;
SD_CARD_TURBO:
	push	r4
	push	r5
	push	yl
	push	yh
	movw	yh:yl, r25:r24		; Copy Parameter Block Address
	rcall	SPI_transfer_dummy
	cbi	b_SS
	rcall	SD_setupTimer		; Reset Timer to zero
	rcall	SPI_transfer_dummy
	push	r0;6
	push	r0;5
	push	r0;4
	push	r0;3
	push	r0;2
	in	zl, CPU_SPL
	in	zh, CPU_SPH		; this points to where the command will go
	ldi	r18, CMD17		; Read Block Command
	push	r18;1
	rcall	SD_setBlock		; Set Block Number
	movw	r25:r24, zh:zl
	rcall	SD_command		; Send Command
	pop	r18;1
	pop	r18;2
	pop	r18;3
	pop	r18;4
	pop	r18;5
	pop	r18;6
	rcall	SD_readRes1		; Get R1 result
	cpi	r24, SD_READY		; Command accepted and device ready?
	breq	SD_CARD_TURBO010	; yes -> continue
	std	Y+P_Error, r24		; Save R1 response in error field
	ldi	r24, SD_ERR_CMD_REJ	; Command rejected
	rjmp	SD_CARD_TURBO999	; Error exit
SD_CARD_TURBO010:			; Set number of times we try to read data token
	ldi	xl, low(SD_MAX_READ_ATTEMPTS)
	ldi	xh, high(SD_MAX_READ_ATTEMPTS)
SD_CARD_TURBO020:
	rcall	SPI_transfer_dummy	; Poll SD-Card
	cpi	r24, SD_START_TOKEN	; Data Token?
	breq	SD_CARD_TURBO040	; We got one proceed with reading data
	cpi	r24, 0xFF		; Still Busy
	breq	SD_CARD_TURBO030	; Yes try another one
	std	Y+P_Error, r24		; Else something went wrong, save error
	ldi	r24, SD_ERR_INV_TOKEN	; Report invalid Token
	rjmp	SD_CARD_TURBO999	; Error exit
SD_CARD_TURBO030:			; Wait for 1ms, setting delay to zero means
	ldi	r24, low(0)		; a delay between 0 and 1ms. Depending when
	ldi	r25, high(0)		; the tick timer intercepts the delay in a
	call	delay			; tight loop this is mostly just 1ms
	sbiw	xh:xl, 1		; another attempt left?
	brne	SD_CARD_TURBO020	; yes -> wait for another ms
	ldi	r24, SD_ERR_NO_TOKEN	; Report no Token received within time-out
	rjmp	SD_CARD_TURBO999	; Error exit
SD_CARD_TURBO040:
	ldd	xl, Y+P_Wordcount+0
	ldd	xh, Y+P_Wordcount+1
	lds	r17, SPI1_CTRLA
	sts	SPI1_CTRLA, zero
	lds	r18, SPI1_CTRLB
	sbr	r18, SPI_BUFEN_bm	; Set SPI buffered mode so we can do the
	sts	SPI1_CTRLB, r18		; transfer in 16-bit chunks
	sts	SPI1_CTRLA, r17
	clr	r4			; Prepare for CRC Calculcation
	clr	r5
	clr	r19
	ldd	r16, Y+P_Flag		; Possibly skip the first RL01/02
	sbrs	r16, P__Skip		; sector in first block
	rjmp	SD_CARD_TURBO080	; no read starts at a even RL01/02 sector
SD_CARD_TURBO050:
	ldi	r18, 0xFF			
	sts	SPI1_DATA, r18		; Write two dummy bytes in order
	sts	SPI1_DATA, r18		; to request two bytes from the SD-Card
	rjmp	PC+1
	rjmp	PC+1
SD_CARD_TURBO060:
	lds	r18, SPI1_INTFLAGS	; Wait until we have a byte to read
	sbrs	r18, SPI_RXCIF_bp
	rjmp	SD_CARD_TURBO060	; Wait for first byte received
	lds	r16, SPI1_DATA
SD_CARD_TURBO070:
	lds	r18, SPI1_INTFLAGS	; and another one
	sbrs	r18, SPI_RXCIF_bp
	rjmp	SD_CARD_TURBO070	; Wait for second byte received
	lds	r17, SPI1_DATA
	crc	r16, r4, r5		;
	crc	r17, r4, r5		;
	inc	r19			; And skip 128 words
	brpl	SD_CARD_TURBO050	;
SD_CARD_TURBO080:			; Start transferring a full block
	ldi	r18, 0xFF
	sts	SPI1_DATA, r18		; Write two dummy bytes in order
	sts	SPI1_DATA, r18		; to request two bytes from the SD-Card
	rjmp	PC+1			; Let some cycles pass
	rjmp	PC+1			; 
SD_CARD_TURBO100:
	lds	r18, SPI1_INTFLAGS	; Wait until both bytes have been sent
	sbrs	r18, SPI_RXCIF_bp
	rjmp	SD_CARD_TURBO100	; Wait for first byte received
	lds	r16, SPI1_DATA
SD_CARD_TURBO110:
	lds	r18, SPI1_INTFLAGS	; Wait until both bytes have been sent
	sbrs	r18, SPI_RXCIF_bp
	rjmp	SD_CARD_TURBO110	; Wait for first byte received
	lds	r17, SPI1_DATA
	ldi	r18, 0xFF
	sts	SPI1_DATA, r18		; Write two dummy bytes in order
	sts	SPI1_DATA, r18		; to request two bytes from the SD-Card
	#if cpldif==40	
	cli				;
	cbi	b_RS0			;
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
	ldi	r18, 2			;
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
	crc	r17, r4, r5		;
SD_CARD_TURBO120:			;
	dec	r18			; Then we wait for the DMA to finish or
	sbis	i_DMG			; time-out
	brne	SD_CARD_TURBO120	; skipped if DMA finished, loops when active
	brne	SD_CARD_TURBO130	; no time-out
;
;	DMA Bus Timeout
;
	cbi	b_DMR			; de-assert DMA request
	nop
	sbi	b_ABO			; abort DMA
	cbi	b_ABO
	ldi	r24, SD_ERROR		; General error
	rjmp	SD_CARD_TURBO999
SD_CARD_TURBO130:
	cbi	b_DMR			; Acknowledge state machine
	adiw	xh:xl, 1
	breq	SD_CARD_TURBO140
	inc	r19			; do another word
	breq	SD_CARD_TURBO155	; Finished one block
	rjmp	SD_CARD_TURBO100
SD_CARD_TURBO140:
	inc	r19
	breq	SD_CARD_TURBO155
SD_CARD_TURBO150:
	lds	r18, SPI1_INTFLAGS	; Wait until both bytes have been sent
	sbrs	r18, SPI_RXCIF_bp
	rjmp	SD_CARD_TURBO150	; Wait for first byte received
	lds	r17, SPI1_DATA		; High Byte CRC first
SD_CARD_TURBO151:
	lds	r18, SPI1_INTFLAGS	; Wait until both bytes have been sent
	sbrs	r18, SPI_RXCIF_bp
	rjmp	SD_CARD_TURBO151	; Wait for first byte received
	lds	r16, SPI1_DATA		;
	ldi	r18, 0xFF
	sts	SPI1_DATA, r18		; Write two dummy bytes in order
	sts	SPI1_DATA, r18		; to request two bytes from the SD-Card
	rjmp	SD_CARD_TURBO140
SD_CARD_TURBO155:
	std	Y+P_Wordcount+0, xl	; save remaining wordcount
	std	Y+P_Wordcount+1, xh
SD_CARD_TURBO160:
	lds	r18, SPI1_INTFLAGS	; Wait until both bytes have been sent
	sbrs	r18, SPI_RXCIF_bp
	rjmp	SD_CARD_TURBO160	; Wait for first byte received
	lds	r17, SPI1_DATA		; High Byte CRC first
SD_CARD_TURBO161:
	lds	r18, SPI1_INTFLAGS	; Wait until both bytes have been sent
	sbrs	r18, SPI_RXCIF_bp
	rjmp	SD_CARD_TURBO161	; Wait for first byte received
	lds	r16, SPI1_DATA		;
	cp	r4, r16			; Match?
	cpc	r5, r17			; 
	ldi	r24, SD_SUCCESS		; Assume yes
	breq	SD_CARD_TURBO170	; yeah!
	ldi	r24, SD_ERR_CRC		; oh no! CRC error
SD_CARD_TURBO170:
	lds	r17, SPI1_CTRLA		; Reset Buffered Mode
	sts	SPI1_CTRLA, zero
	lds	r18, SPI1_CTRLB
	cbr	r18, SPI_BUFEN_bm
	sts	SPI1_CTRLB, r18
	sts	SPI1_CTRLA, r17
SD_CARD_TURBO999:
	mov	r4, r24			; Save Return Status
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
