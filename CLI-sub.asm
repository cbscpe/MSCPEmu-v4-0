;--------------------------------------------------------------------------
;
;	Subroutine that checks unitnumber and if unit is free
;
;	Input
;
;	attunit		The unit number
;
;	Output
;
;	CC		Unit valid and not attached
;	CS		Unit is invalid or already attached
;	Z		Pointer to the Unit Control Block
;
;	Registers
;
;	r18
;
checkunit:
	lds	zl, attunit
	cpi	zl, units
	brlo	checkunit010
	ori	zl, '0'
	sts	pprint+0, zl
	call	print
	.db	CR, LF
	.db	"Unit ", 0x90, " does not exist", CR, LF, 0
	sec
	ret

checkunit010:
	swap	zl
	clr	zh
	subi	zl, low(-unittable)
	sbci	zh, high(-unittable)

	ldd	r18, Z+ucb_status
	andi	r18, (1<<ucb__part) | (1<<ucb__file)
	breq	checkunit020
	lds	r18, attunit
	ori	r18, '0'
	sts	pprint+0, r18
	call	print
	.db	CR, LF
	.db	"Unit ", 0x90, " is busy ", CR, LF, 0
	sec
	ret
checkunit020:
	clc
	ret
;--------------------------------------------------------------------------
;
;	int16 findpart(int8 partitionid) - find partition
;
findpart:
	push	yl
	push	yh
	ldi	zl, low(pcbqueue)	; get partition queue head
	ldi	zh, high(pcbqueue)

	lds	yl, pcbqueue+0
	lds	yh, pcbqueue+1
findpart010:
	sbiw	yh:yl, 0
	breq	findpart020		; yes then done
	ldd	r25, Y+pcb_id		; get id
	cp	r24, r25
	breq	findpart020

	ldd	zl, Y+0			; get partition
	ldd	zh, Y+1
	movw	Y, Z
	rjmp	findpart010
;
findpart020:
	movw	r25:r24, yh:yl
	pop	yh
	pop	yl
	ret


;--------------------------------------------------------------------------
;
;	Y		pointer to file control block
;
printfraglist:
	push	zl
	push	zh
	call	print
	.db	"  Fragments of file", 0x0d, 0x0a, 0x00
	movw	zl:zh, yl:yh
	adiw	Z, fcb_fraglist
	
printfraglist010:
	ldd	r24, Z+0
	ldd	r25, Z+1
	sbiw	r25:r24, 0
	breq	printfraglist020
	movw	zh:zl, r25:r24

	ldd	r18, Z+Fr_Length+0
	sts	pprint+0, r18
	ldd	r18, Z+Fr_Length+1
	sts	pprint+1, r18
	ldd	r18, Z+Fr_Length+2
	sts	pprint+2, r18
	ldd	r18, Z+Fr_Length+3
	sts	pprint+3, r18

	ldd	r18, Z+Fr_Start+0
	sts	pprint+4, r18
	ldd	r18, Z+Fr_Start+1
	sts	pprint+5, r18
	ldd	r18, Z+Fr_Start+2
	sts	pprint+6, r18
	ldd	r18, Z+Fr_Start+3
	sts	pprint+7, r18

	call	print
	.db	"  Start:", 0x87, 0x86, 0x85, 0x84, "  Length:", 0x83, 0x82, 0x81, 0x80, CR, LF, 0
	rjmp	printfraglist010

printfraglist020:
	pop	zh
	pop	zl
	ret
	
;--------------------------------------------------------------------------
;
;
;
;	record		fcb, iob, 2		; IO Parameter Block
;	record		fcb, Flag, 1
;		.equ	F__Readonly	= 0	; File is open read-only
;		.equ	F__Direct	= 1	; File is open for direct block IO
;		.equ	F__Sequential	= 2	; File is open for sequential access
;		.equ	F__Image	= 3	; File is a valid diskimage
;		.equ	F__IOE		= 5	; File IO Error
;		.equ	F__EOF		= 6	; File Read Past End Of File
;		.equ	F__ERR		= 7	; File IO Error summary
;	record		fcb, sectperclst, 1
;	record		fcb, drvtab, 2
;	record		fcb, filename, 2
;	record		fcb, fraglist, 2
;	record		fcb, position, 4
;	record		fcb, filesize, 4
;	record		fcb, byteinsec, 2
;	record		fcb, volume, 2		; Pointer to Volume Control Block

dumpfcb:
	push	r16
	sts	pprint+0, yl
	sts	pprint+1, yh

	ldd	r16, Y+fcb_iob+0
	sts	pprint+2, r16
	ldd	r16, Y+fcb_iob+1
	sts	pprint+3, r16
	call	print
	.db	CR, LF, "Dump FCB -------> 0x", 0x81, 0x80, CR, LF
	.db	TAB, "IOB ......0x", 0x83, 0x82, CR, LF, 0

	ldd	r16, Y+fcb_Flag
	sts	pprint+2, r16
	call	print
	.db	TAB, "Flags ....0x", 0x82, CR, LF, 0, 0

	ldd	r16, Y+fcb_sectperclst
	sts	pprint+2, r16
	call	print
	.db	TAB, "sectpclst 0x", 0x82, CR, LF, 0, 0

	ldd	r16, Y+fcb_drvtab+0
	sts	pprint+2, r16
	ldd	r16, Y+fcb_drvtab+1
	sts	pprint+3, r16
	call	print
	.db	TAB, "drvtab ...0x", 0x83, 0x82, CR, LF, 0

	ldd	r16, Y+fcb_filename+0
	sts	pprint+2, r16
	ldd	r16, Y+fcb_filename+1
	sts	pprint+3, r16
	call	print
	.db	TAB, "filename .0x", 0x83, 0x82, CR, LF, 0

	ldd	r16, Y+fcb_fraglist+0
	sts	pprint+2, r16
	ldd	r16, Y+fcb_fraglist+1
	sts	pprint+3, r16
	call	print
	.db	TAB, "fraglist .0x", 0x83, 0x82, CR, LF, 0

	ldd	r16, Y+fcb_filesize+0
	sts	pprint+2, r16
	ldd	r16, Y+fcb_filesize+1
	sts	pprint+3, r16
	ldd	r16, Y+fcb_filesize+2
	sts	pprint+4, r16
	ldd	r16, Y+fcb_filesize+3
	sts	pprint+5, r16
	call	print
	.db	TAB, "filesize .0x", 0x85, 0x84, 0x83, 0x82, CR, LF, 0

	ldd	r16, Y+fcb_volume+0
	sts	pprint+2, r16
	ldd	r16, Y+fcb_volume+1
	sts	pprint+3, r16
	call	print
	.db	TAB, "volume ...0x", 0x83, 0x82, CR, LF, 0
	pop	r16
	ret
	
	
dumpreg:
	sts	pprint+0, r22
	sts	pprint+1, r23
	sts	pprint+2, r24
	sts	pprint+3, r25
	sts	pprint+4, xl
	sts	pprint+5, xh
	sts	pprint+6, yl
	sts	pprint+7, yh
	sts	pprint+8, zl
	sts	pprint+9, zh
	call	print
	.db	CR, LF
	.db	"Registers r22..r31"
	.db	" 0x", 0x80
	.db	" 0x", 0x81
	.db	" 0x", 0x82
	.db	" 0x", 0x83
	.db	" 0x", 0x84
	.db	" 0x", 0x85
	.db	" 0x", 0x86
	.db	" 0x", 0x87
	.db	" 0x", 0x88
	.db	" 0x", 0x89
	.db	CR, LF
	.dw	0
	ret	
	
	
