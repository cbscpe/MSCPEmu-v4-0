cmdsdread:
	ldi	yl, low(sdio)		; Setup parameter block for general IO
	ldi	yh, high(sdio)		; 
	lds	r16, nbr+4
	lds	r17, nbr+5
	lds	r18, nbr+6
	lds	r19, nbr+7
	std	Y+P_Sector+0, r16
	std	Y+P_Sector+1, r17
	std	Y+P_Sector+2, r18
	std	Y+P_Sector+3, r19
	ldi	r16, low(-(8*256+100))
	ldi	r17, high(-(8*256+100))
	ldi	r16, low(0177000)
	ldi	r17, high(0177000)
	std	Y+P_Wordcount+0, r16
	std	Y+P_Wordcount+1, r17
	
	lds	r16, nbr+0
	lds	r17, nbr+1
	lds	r18, nbr+2
	
	dmaaddr	r16, r17, r18
	movw	r25:r24, yh:yl
	call	SD_CARD_MULTIPLE
	sts	pprint+8, r24
	ldd	r16, Y+P_Error+0
	ldd	r17, Y+P_Error+1
	sts	pprint+0, r16
	sts	pprint+1, r17
;	ldd	r18, Y+P_Error+2
;	ldd	r19, Y+P_Error+3
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