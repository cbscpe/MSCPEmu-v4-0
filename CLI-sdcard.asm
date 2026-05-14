cmdsdread:

	lds	r16, sdcardflag
	sbrc	r16, 0
	rjmp	cmdsdread010
	call	print
	.db	CR, LF, "SD-Card - No LBN!", CR, LF, 0
	clc
	ret

cmdsdread010:
	sbrc	r16, 1
	rjmp	cmdsdread020
	call	print
	.db	CR, LF, "SD-Card - No Address!", CR, LF, 0
	clc
	ret

cmdsdread020:
	ldi	yl, low(sdio)		; Setup parameter block for general IO
	ldi	yh, high(sdio)		; 
	lds	r16, sdcardlbn+0
	lds	r17, sdcardlbn+1
	lds	r18, sdcardlbn+2
	lds	r19, sdcardlbn+3
	std	Y+P_Sector+0, r16
	std	Y+P_Sector+1, r17
	std	Y+P_Sector+2, r18
	std	Y+P_Sector+3, r19
	
	sts	pprint+0, r16
	sts	pprint+1, r17
	sts	pprint+2, r18
	sts	pprint+3, r19
	call	print
	.db	CR, LF, "Sector ", 0xd0, 0, 0
	
	ldi	r16, low(0174000)	; 2 blocks
	ldi	r17, high(0174000)
	std	Y+P_Wordcount+0, r16
	std	Y+P_Wordcount+1, r17
	ldi	r16, (1<<P__Nocheck)	; don't check CRC, no partial blocks
	std	Y+P_Flag, r16		; 
	
	lds	r16, sdcardaddr+0
	lds	r17, sdcardaddr+1
	lds	r18, sdcardaddr+2
	
	sts	pprint+0, r16
	sts	pprint+1, r17
	sts	pprint+2, r18
	call	print
	.db	CR, LF, "Set DMA Address 0", 0xb0, 0, 0
	
	
	dmaaddr	r16, r17, r18
	movw	r25:r24, yh:yl
	call	SD_CARD_MULTIPLE
	sts	pprint+8, r24
	ldd	r16, Y+P_Error+0
	ldd	r17, Y+P_Error+1
	sts	pprint+0, r16
	sts	pprint+1, r17
	ldd	r16, Y+P_Duration+0
	ldd	r17, Y+P_Duration+1
	sts	pprint+4, r16
	sts	pprint+5, r17

	call	print
	.db	CR, LF, "SD_CARD_MULTIPLE RC: 0x", 0x88
	.db	CR, LF, "SD-Read Multiple Error: 0x", 0x81, 0x80
	.db	CR, LF, "Duration: 0x", 0x85, 0x84, CR, LF
	.db	0, 0
	clc
	ret
	
	
a_sdinit:
	sts	sdcardflag, zero
	clc
	ret

a_sdlbn:
	lds	r16, sdcardflag
	ori	r16, 0x01
	sts	sdcardflag, r16
	lds	r16, scanresult+0
	lds	r17, scanresult+1
	lds	r18, scanresult+2
	lds	r19, scanresult+3
	sts	sdcardlbn+0, r16
	sts	sdcardlbn+1, r17
	sts	sdcardlbn+2, r18
	sts	sdcardlbn+3, r19
	
	clc
	ret

a_sdaddr:

	lds	r16, sdcardflag
	ori	r16, 0x02
	sts	sdcardflag, r16
	lds	r16, scanresult+0
	lds	r17, scanresult+1
	lds	r18, scanresult+2
	lds	r19, scanresult+3
	sts	sdcardaddr+0, r16
	sts	sdcardaddr+1, r17
	sts	sdcardaddr+2, r18
	sts	sdcardaddr+3, r19
	clc
	ret

