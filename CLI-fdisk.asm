;--------------------------------------------------------------------------
;
;	fdisk
;
;--------------------------------------------------------------------------
;
fdisk:
	ldi	yl, low(sdio)				; Prepare an IO control block
	ldi	yh, high(sdio)				; 
	ldi	zl, low(sdbuffer)			; set IO buffer address
	ldi	zh, high(sdbuffer)			; 
	std	Y+P_Address+0, zl
	std	Y+P_Address+1, zh

	std	Y+P_Sector+0, zero			; Set sector to MBR
	std	Y+P_Sector+1, zero
	std	Y+P_Sector+2, zero
	std	Y+P_Sector+3, zero

	std	Y+P_Cluster+0, zero
	std	Y+P_Cluster+1, zero
	std	Y+P_Cluster+2, zero
	std	Y+P_Cluster+3, zero
	
	std	Y+P_Extended+0, zero
	std	Y+P_Extended+1, zero
	std	Y+P_Extended+2, zero
	std	Y+P_Extended+3, zero
	
	std	Y+P_Flag, zero				; No partition seen

fdisknext:
	wdr
	ldd	r18, Y+P_Sector+0
	sts	pprint+2, r18
	ldd	r18, Y+P_Sector+1
	sts	pprint+3, r18
	ldd	r18, Y+P_Sector+2
	sts	pprint+4, r18
	ldd	r18, Y+P_Sector+3
	sts	pprint+5, r18
	movw	r25:r24, yh:yl
	call	SD_CARD_READ
	brcs	fdiskerr81

	ldd	xl, Y+P_Address+0
	ldd	xh, Y+P_Address+1
	subi	xl, low(-510)
	sbci	xh, high(-510)
	ld	r18, X+
	sts	pprint+0, r18
	cpi	r18, 0x55
	brne	fdiskerr82
	ld	r18, X+
	sts	pprint+1, r18
	cpi	r18, 0xAA
	breq	fdiskanalyze
;
;
;
fdiskerr82:
	call	print
	.db	CR, LF
	.db	"fdisk -- invalid signature 0x", 0x80, 0x81, " in sector 0x", 0x85, 0x84, 0x83, 0x82
	.db	CR, LF, 0, 0
	ldi	r18, 0x82
	rjmp	fdiskerr
fdiskerr81:
	ldi	r18, 0x81
fdiskerr:
	sts	pprint+12, r18
	sec
	ret					; Exit with CS

fdiskanalyze:

	call	print
	.db	CR, LF
	.db	"Sector: 0x", 0x85, 0x84, 0x83, 0x82, ", Signature: 0xAA55 ", CR, LF
	.db	"         Starting       Ending", CR, LF
	.db	"#: id  cyl  hd sec -  cyl  hd sec [     start -       size] ", CR, LF
	.db	"------------------------------------------------------------------------"
	.db	CR, LF, 0, 0
	ldd	zl, Y+P_Address+0
	ldd	zh, Y+P_Address+1	
	subi	zl, low(-M_PartTable)	
	sbci	zh, high(-M_PartTable)	
	ldi	r17, 4
	ldd	r18, Y+P_Flag
	cbr	r18, (1<<Part__Next)
	std	Y+P_Flag, r18
fdiskanalyzenext:
	rcall	fdiskprintentry
	rcall	fdiskcheckextended
	adiw	Z, M_PartEntry
	dec	r17
	brne	fdiskanalyzenext
	
	ldd	r18, Y+P_Flag
	sbrs	r18, Part__Next
	rjmp	fdiskanalyzedone
	cbr	r18, (1<<Part__Next)
	std	Y+P_Flag, r18

	ldd	r18, Y+P_Cluster+0
	std	Y+P_Sector+0, r18		
	ldd	r18, Y+P_Cluster+1
	std	Y+P_Sector+1, r18
	ldd	r18, Y+P_Cluster+2
	std	Y+P_Sector+2, r18
	ldd	r18, Y+P_Cluster+3
	std	Y+P_Sector+3, r18
	rjmp	fdisknext

fdiskanalyzedone:
	clc
	ret

fdiskcheckextended:
	ldd	r18, Z+M_PartType
	cpi	r18, 0x05
	breq	fdiskcheckextended010
	ret
fdiskcheckextended010:
	ldd	r18, Y+P_Flag
	sbrc	r18, Part__Ext
	rjmp	fdiskcheckextended020
	sbr	r18, (1<<Part__Ext | 1<<Part__Next)
	std	Y+P_Flag, r18

	ldd	r18, Z+M_PartStart+0
	std	Y+P_Cluster+0, r18	; Remember the extended parititon offset
	std	Y+P_Extended+0, r18	; Remember the global extended parititon offset

	ldd	r18, Z+M_PartStart+1
	std	Y+P_Cluster+1, r18
	std	Y+P_Extended+1, r18

	ldd	r18, Z+M_PartStart+2
	std	Y+P_Cluster+2, r18
	std	Y+P_Extended+2, r18
	
	ldd	r18, Z+M_PartStart+3
	std	Y+P_Cluster+3, r18
	std	Y+P_Extended+3, r18
	ret

fdiskcheckextended020:
	sbr	r18, (1<<Part__Next)
	std	Y+P_Flag, r18
	
	ldd	r16, Y+P_Extended+0
	ldd	r18, Z+M_PartStart+0
	add	r18, r16
	std	Y+P_Cluster+0, r18	

	ldd	r16, Y+P_Extended+1
	ldd	r18, Z+M_PartStart+1
	adc	r18, r16
	std	Y+P_Cluster+1, r18	

	ldd	r16, Y+P_Extended+2
	ldd	r18, Z+M_PartStart+2
	adc	r18, r16
	std	Y+P_Cluster+2, r18	

	ldd	r16, Y+P_Extended+3
	ldd	r18, Z+M_PartStart+3
	adc	r18, r16
	std	Y+P_Cluster+3, r18	

	ret

fdiskprintentry:
	ldi	r18, '5'
	sub	r18, r17
	sts	pprint+0, r18
	ldd	r18, Z+M_PartType
	sts	pprint+1, r18

	ldd	r18, Z+M_PartStart+0
	sts	pprint+2, r18
	ldd	r18, Z+M_PartStart+1
	sts	pprint+3, r18
	ldd	r18, Z+M_PartStart+2
	sts	pprint+4, r18
	ldd	r18, Z+M_PartStart+3
	sts	pprint+5, r18

	ldd	r18, Z+M_PartType
	tst	r18
	brne	fdiskprintentry110
;
;	Empty Partition Entry
;
	call	print	
	.db	0x90, ": 00    0   0   0 -    0   0   0 [         0 -          0] unused"
	.db	CR, LF, 0, 0
	ret

fdiskprintentry110:
	cpi	r18, 0x05
	breq	fdiskprintentry120
;
;	Normal Partition Start: Y+P_Sector + Z+M_PartStart
;
	lds	r18, pprint+2
	ldd	r16, Y+P_Sector+0
	add	r18, r16
	sts	pprint+2, r18
	lds	r18, pprint+3
	ldd	r16, Y+P_Sector+1
	adc	r18, r16
	sts	pprint+3, r18
	lds	r18, pprint+4
	ldd	r16, Y+P_Sector+2
	adc	r18, r16
	sts	pprint+4, r18
	lds	r18, pprint+5
	ldd	r16, Y+P_Sector+3
	adc	r18, r16
	sts	pprint+5, r18
	rjmp	fdiskprintentry130
;
;	Extended Partition Start: pextended + Z+__PartStart
;
fdiskprintentry120:
	lds	r18, pprint+2
	ldd	r16, Y+P_Extended+0
	add	r18, r16
	sts	pprint+2, r18
	lds	r18, pprint+3
	ldd	r16, Y+P_Extended+1
	adc	r18, r16
	sts	pprint+3, r18
	lds	r18, pprint+4
	ldd	r16, Y+P_Extended+2
	adc	r18, r16
	sts	pprint+4, r18
	lds	r18, pprint+5
	ldd	r16, Y+P_Extended+3
	adc	r18, r16
	sts	pprint+5, r18

fdiskprintentry130:

	ldd	r18, Z+M_PartSize+0
	sts	pprint+6, r18
	ldd	r18, Z+M_PartSize+1
	sts	pprint+7, r18
	ldd	r18, Z+M_PartSize+2
	sts	pprint+8, r18
	ldd	r18, Z+M_PartSize+3
	sts	pprint+9, r18
	
	call	print
	.db	0x90,": ", 0x81," 1023 254  63 - 1023 254  63 [0x", 0x85, 0x84, 0x83, 0x82, " - 0x", 0x89, 0x88, 0x87, 0x86, "] ", 0x00
	ldd	r18, Z+M_PartType
	cpi	r18, 0x00
	brne	fdiskprintentry010
	call	print
	.db	"unused ", CR, LF, 0
	ret
fdiskprintentry010:
	cpi	r18, 0x83
	brne	fdiskprintentry020
	call	print
	.db	"Linux files", CR, LF, 0
	ret

fdiskprintentry020:
	cpi	r18, 0x05
	brne	fdiskprintentry030
	call	print
	.db	"Extended DOS ", CR, LF, 0
	ret

fdiskprintentry030:
	cpi	r18, 0x0b
	brne	fdiskprintentry040
	call	print
	.db	"Win95 FAT-32 ", CR, LF, 0
	ret

fdiskprintentry040:
	cpi	r18, 0x06
	brne	fdiskprintentry050
	call	print
	.db	"Win95 FAT-16b", CR, LF, 0
	ret

fdiskprintentry050:
	cpi	r18, 0x07
	brne	fdiskprintentry060
	call	print
	.db	"extended FAT ", CR, LF, 0
	ret

fdiskprintentry060:
	cpi	r18, 0x01
	brne	fdiskprintentry070
	call	print
	.db	"MSDOS FAT-12 ", CR, LF, 0
	ret
fdiskprintentry070:
	call	print
	.db	"other", CR, LF, 0
	ret
	
	
	
	
	
	
	
	
	
	
	
	