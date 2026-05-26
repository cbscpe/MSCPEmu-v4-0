;=============================================================================
;
;
.include "monitor-chartbl-v2-0.inc"
	.db	0, "K"		; crcro
	.db	0, "S"		; SD
	.db	0, "R"
	.db	0, "W"
	.db	0, "G"
	.db	0, 'F' & 0x1F
	.db	0, 'O'
	.db	0, 'T'
	.db	0, 'U'
;	I	1S	.dw	mon_sd_card_spi		SD_CARD_SPI
;	H	2S	.dw	mon_sd_card_ifc		SD_CARD_IFC
;	J	3S	.dw	mon_sd_card_init	SD_CARD_INIT
;	K	4S	.dw	mon_sd_card_readocr	SD_CARD_READOCR
;	L	5S	.dw	mon_sd_card_blklen	SD_CARD_BLKLEN

.include "monitor-subtbl-v2-0.inc"
	.dw	moncrc7
	.dw	SD_main
	.dw	monsdreadsector
	.dw	monsdwritesector
	.dw	monstack
	.dw	fdisk
	.dw	mountcmd
	.dw	mondrivecmd
	.dw	dismountcmd

.include "monitor-v2-0.asm"
;=============================================================================
;
;	To verify the crc7table we have here a list of sd-card commands with 
;	the precalcualted CRC-7, which can be found in the internet.
;	CRC-7 Calculation for SD-Cards includes the first byte, which consists
;	of the start bit (the MSB needs to be 0) and the data start bit (bit-6
;	which needs to be 1) and the command (bits5..0). In fact CRC is only
;	required until the card is in SPI mode because after this the CRC is
;	ignored.
;
tstcmd41:	.db	0x69, 0x40, 0x00, 0x00, 0x00, 0x77
tstcmd55:	.db	0x77, 0x00, 0x00, 0x00, 0x00, 0x65 
tstcmd58:	.db	0x7A, 0x00, 0x00, 0x00, 0x00, 0xfd
tstcmd9:	.db	0x49, 0x00, 0x00, 0x01, 0xAA, 0xeb
tstcmd8:	.db	0x48, 0x00, 0x00, 0x01, 0xAA, 0x87
tstcmd0:	.db	0x40, 0x00, 0x00, 0x00, 0x00, 0x95
moncrc7:
	call	seroutcrlf
	ldi	yl, low(2*tstcmd0)
	ldi	yh, high(2*tstcmd0)
	rcall	moncrc7sub
	
	ldi	yl, low(2*tstcmd8)
	ldi	yh, high(2*tstcmd8)
	rcall	moncrc7sub

	ldi	yl, low(2*tstcmd9)
	ldi	yh, high(2*tstcmd9)
	rcall	moncrc7sub

	ldi	yl, low(2*tstcmd41)
	ldi	yh, high(2*tstcmd41)
	rcall	moncrc7sub

	ldi	yl, low(2*tstcmd55)
	ldi	yh, high(2*tstcmd55)
	rcall	moncrc7sub

	ldi	yl, low(2*tstcmd58)
	ldi	yh, high(2*tstcmd58)
	rcall	moncrc7sub

	ret

moncrc7sub:
	clr	r4
	movw	Z, Y
	lpm	r16, Z+
	movw	Y, Z
	eor	r4, r16
	andi	r16, 0x3f
	sts	pprint+2, r16
	clr	r16
	sts	pprint+3, r16
	mov	zl, r4
	ldi	zh, high(crc7table)	
	ld	r4, Z
	
	movw	Z, Y
	lpm	r16, Z+
	movw	Y, Z
	eor	r4, r16
	mov	zl, r4
	ldi	zh, high(crc7table)	
	ld	r4, Z

	movw	Z, Y
	lpm	r16, Z+
	movw	Y, Z
	eor	r4, r16
	mov	zl, r4
	ldi	zh, high(crc7table)	
	ld	r4, Z

	movw	Z, Y
	lpm	r16, Z+
	movw	Y, Z
	eor	r4, r16
	mov	zl, r4
	ldi	zh, high(crc7table)	
	ld	r4, Z

	movw	Z, Y
	lpm	r16, Z+
	movw	Y, Z
	eor	r4, r16
	mov	zl, r4
	ldi	zh, high(crc7table)	
	ld	r4, Z

	ldi	r18, 0x01
	or	r4, r18
	sts	pprint+0, r4
	movw	Z, Y
	lpm	r16, Z
	sts	pprint+1, r16
	call	print
	.db	"CRC of CMD", 0xc2," is 0x", 0x80, " and should be 0x", 0x81, CR, LF, 0, 0
	ret

;--------------------------------------------------------------------------
;
;
;
monstack:
	sts	pprint+14, zl
	sts	pprint+15, zh
	push	zl
	push	zh
	ldi	r18, 0xaa
	push	r18
	ldi	r18, 0x55
	push	r18
	in	r18, CPU_SPL
	sts	pprint+0, r18
	in	r18, CPU_SPH
	sts	pprint+1, r18
	ldi	r18, low(monstackret)
	sts	pprint+2, r18
	ldi	r18, high(monstackret)
	sts	pprint+3, r18
	rcall	monstackcall	
monstackret:
	call	print
	.db	"Stack pointer at entry to monstack .......0x", 0x81, 0x80, CR, LF
	.db	"Address of label monstackret .............0x", 0x83, 0x82, CR, LF
	.db	"Stack address at monstackcall ............0x", 0x85, 0x84, CR, LF
	.db	"Memory Value at stack+0 ..................0x", 0x86, " ", CR, LF
	.db	"Memory Value at stack+1 ..................0x", 0x87, " ", CR, LF
	.db	"Memory Value at stack+2 ..................0x", 0x88, " ", CR, LF
	.db	"Memory Value at stack+3 ..................0x", 0x89, " ", CR, LF
;	.db	"Return Address fetched at monstackcall ...0x", 0x87, 0x86, CR, LF
;	.db	"Next two bytes on stack at monstackcall ..0x", 0x89, 0x88, CR, LF
	.db	"Value of Z register entering monstack ....0x", 0x8f, 0x8e, CR, LF
	.db	0, 0
	pop	r18
	pop	r18
	pop	zh
	pop	zl
	ret

monstackcall:
	ldi	r18, 0xff
	push	r18
	in	zl, CPU_SPL
	in	zh, CPU_SPH
	sts	pprint+4, zl
	sts	pprint+5, zh
	ldd	r18, Z+0
	sts	pprint+6, r18
	ldd	r18, Z+1
	sts	pprint+7, r18
	ldd	r18, Z+2
	sts	pprint+8, r18
	ldd	r18, Z+3
	sts	pprint+9, r18
	pop	r18
	ret
;--------------------------------------------------------------------------
;
;		"avrmem"<"pdp11memstart"."pdp11memend"R
;
;		'avrmem(a4)'<'sector(a1)'R
monsdreadsector:
	push	r0
	push	r1
	push	xl
	push	xh
	push	yl
	push	yh
	push	zl
	push	zh

	ldi	zl, low(sdio)
	ldi	zh, high(sdio)

	lds	r18, a1l
	std	Z+P_Sector+0, r18
	lds	r18, a1h
	std	Z+P_Sector+1, r18
	lds	r18, a1b
	std	Z+P_Sector+2, r18
	std	Z+P_Sector+3, zero
	
	lds	xl, a4l
	lds	xh, a4h
	std	Z+P_Address+0, xl
	std	Z+P_Address+1, xh
	movw	r25:r24, zh:zl
	call	SD_sendRead
	cpse	r24, zero
	rjmp	monsdread900
	call	print
	.db	"Success!", CR, LF, 0, 0

	lds	xl, a4l
	lds	xh, a4h
	clr	r16
	push	r4
	push	r5
	clr	r4
	clr	r5
monsdread010:
	ld	r18, X+
	crcro	r18, r4, r5
	ld	r18, X+
	crcro	r18, r4, r5
	dec	r16
	brne	monsdread010
	sts	pprint+0, r4
	sts	pprint+1, r5
	lds	r18, sdio+P_Duration+0
	sts	pprint+4, r18
	lds	r18, sdio+P_Duration+1
	sts	pprint+5, r18
	call	print
	.db	"CRC Calculated 0x", 0x81, 0x80, " ", CR, LF
	.db	"Read took ", 0xC4, "usec", CR, LF, 0
	pop	r5
	pop	r4
	rjmp	monsdread990
monsdread900:
	cpi	r24, 1
	brne	monsdread910
	call	print
	.db	"*** Error: Command Rejected ***", CR, LF, 0
	rjmp	monsdread990
monsdread910:
	cpi	r24, 2
	brne	monsdread920
	lds	r18, sdio+P_Error+0
	sts	pprint+0, r18
	call	print
	.db	"*** Error: Invalid Data Token Received 0x", 0x80, " *** ", CR, LF, 0
	rjmp	monsdread990
monsdread920:
	cpi	r24, 3
	brne	monsdread930
	call	print
	.db	"*** Error: Timeout Data Token ***", CR, LF, 0
	rjmp	monsdread990
monsdread930:
	cpi	r24, 4
	brne	monsdread940
	lds	r18, sdio+P_Error+0
	sts	pprint+0, r18
	lds	r18, sdio+P_Error+1
	sts	pprint+1, r18
	call	print
	.db	"*** Error: CRC Error 0x", 0x81, 0x80, " ***", CR, LF, 0
	rjmp	monsdread990
monsdread940:
	sts	pprint+0, r24
	call	print
	.db		"*** Error: unkonw error 0x", 0x80, CR, LF, 0

monsdread990:
	pop	zh
	pop	zl
	pop	yh
	pop	yl
	pop	xh
	pop	xl
	pop	r1
	pop	r0
	ret	

monsdwritesector:
	push	r0
	push	r1
	push	xl
	push	xh
	push	yl
	push	yh
	push	zl
	push	zh
	lds	xl, a1l
	lds	xh, a1h
	clr	r16
	push	r4
	push	r5
	clr	r4
	clr	r5
monsdwrite010:
	ld	r18, X+
	crcro	r18, r4, r5
	ld	r18, X+
	crcro	r18, r4, r5
	dec	r16
	brne	monsdwrite010
	sts	pprint+0, r4
	sts	pprint+1, r5
	pop	r5
	pop	r4
	call	print
	.db	"CRC Calculated 0x", 0x81, 0x80, CR, LF, 0
	ldi	zl, low(sdio)
	ldi	zh, high(sdio)
	lds	r18, a4l
	std	Z+P_Sector+0, r18
	lds	r18, a4h
	std	Z+P_Sector+1, r18
	lds	r18, a4b
	std	Z+P_Sector+2, r18
	std	Z+P_Sector+3, zero
	lds	xl, a1l
	lds	xh, a1h
	std	Z+P_Address+0, xl
	std	Z+P_Address+1, xh
	movw	r25:r24, zh:zl
	call	SD_sendWrite
	lds	r18, sdio+P_Duration+0
	sts	pprint+0, r18
	lds	r18, sdio+P_Duration+1
	sts	pprint+1, r18
	call	print
	.db	"Write took ", 0xC0, "usec", CR, LF, 0, 0
	cpse	r24, zero
	rjmp	monsdwrite900
	call	print
	.db	"Success!", CR, LF, 0, 0
	rjmp	monsdwrite990
monsdwrite900:
	cpi	r24, 1
	brne	monsdwrite910
	call	print
	.db	"*** Error: Command Rejected ***", CR, LF, 0
	rjmp	monsdwrite990
monsdwrite910:
	cpi	r24, 2
	brne	monsdwrite920
	call	print
	.db	"*** Error: Timeout Data Response *** ", CR, LF, 0
	rjmp	monsdwrite990
monsdwrite920:
	cpi	r24, 3
	brne	monsdwrite930
	lds	r18, sdio+P_Error+0
	sts	pprint+0, r18
	call	print
	.db	"*** Error: Data Rejected 0x", 0x80, " *** ", CR, LF, 0
	rjmp	monsdwrite990
monsdwrite930:
	cpi	r24, 4
	brne	monsdwrite940
	call	print
	.db	"*** Error: Timeout Get Ready *** ", CR, LF, 0
	rjmp	monsdwrite990
monsdwrite940:
	sts	pprint, r24
	call	print
	.db	"*** Error: unkown error 0x", 0x80, CR, LF, 0
monsdwrite990:
	pop	zh
	pop	zl
	pop	yh
	pop	yl
	pop	xh
	pop	xl
	pop	r1
	pop	r0
	ret	

;--------------------------------------------------------------------------
;
mondrivecmd:
	call	print
	.db	CR, LF
	.db	"mondrivecmd "
	.db	CR, LF, 0, 0
	lds	r16, a1l
	lds	r17, a1h
	lds	r18, a1b
	clr	r19
	sts	pprint+0, r16
	sts	pprint+1, r17
	sts	pprint+2, r18
	sts	pprint+3, r19
	call	print
	.db	CR, LF
	.db	"Looking for Drive with size 0x", 0x83, 0x82, 0x81, 0x80
	.db	CR, LF, 0, 0

	movw	r23:r22, r17:r16
	movw	r25:r24, r19:r18

	call	FindDriveEntry
	sts	pprint+0, r24
	sts	pprint+1, r25
	call	print
	.db	"Find Drive Entry returned 0x", 0x81, 0x80
	.db	CR, LF, 0, 0
	ret
	
;--------------------------------------------------------------------------
;
dismountcmd:
	call	DismountVolume
	ret

mountcmd:
	call	MountVolume
	ldi	r24, low(volqueue)
	ldi	r25, high(volqueue)
	sts	pprint+0, r24
	sts	pprint+1, r25
	ldi	r24, low(pcbqueue)
	ldi	r25, high(pcbqueue)
	sts	pprint+2, r24
	sts	pprint+3, r25
	sts	pprint+4, r24
	call	print
	.db	"Mount Volume 0x", 0x84, CR, LF
	.db	"    volqueue 0x", 0x81, 0x80, SPACE, CR, LF
	.db	"    pcbqueue 0x", 0x83, 0x82, CR, LF, 0

	lds	zl, volqueue+0
	lds	zh, volqueue+1
	sbiw	zh:zl, 0
	brne	mountcmd010
	ret
mountcmd010:
	ldd	r16, Z+Vol_Status
	sts	pprint, r16
	call	print
;		 ----+----1----+----2----+----3----+----4
	.db	"Status................................:", 0x80, CR, LF, 0, 0

	ldd	r16, Z+Vol_part1start+3
	sts	pprint+3, r16
	ldd	r16, Z+Vol_part1start+2
	sts	pprint+2, r16
	ldd	r16, Z+Vol_part1start+1
	sts	pprint+1, r16
	ldd	r16, Z+Vol_part1start+0
	sts	pprint+0, r16
	call	print
	.db	"Partition start.......................:", 0x83, 0x82, 0x81, 0x80, CR, LF, 0	

;	ldd	r16, Z+Vol_sectbefore+3
;	sts	pprint+3, r16
;	ldd	r16, Z+Vol_sectbefore+2
;	sts	pprint+2, r16
;	ldd	r16, Z+Vol_sectbefore+1
;	sts	pprint+1, r16
;	ldd	r16, Z+Vol_sectbefore+0
;	sts	pprint+0, r16
;	call	print
;	.db	"Sectors before this partition.........:", 0x83, 0x82, 0x81, 0x80, CR, LF, 0	

;	ldd	r16, Z+Vol_sectpart+3
;	sts	pprint+3, r16
;	ldd	r16, Z+Vol_sectpart+2
;	sts	pprint+2, r16
;	ldd	r16, Z+Vol_sectpart+1
;	sts	pprint+1, r16
;	ldd	r16, Z+Vol_sectpart+0
;	sts	pprint+0, r16
;	.db	"Partition size........................:", 0x83, 0x82, 0x81, 0x80, CR, LF, 0	

	ldd	r16, Z+Vol_NumFATs
	sts	pprint, r16
	call	print
	.db	"Number of FATs........................:", 0x80, CR, LF, 0, 0

	ldd	r16, Z+Vol_sectperfat+3
	sts	pprint+3, r16
	ldd	r16, Z+Vol_sectperfat+2
	sts	pprint+2, r16
	ldd	r16, Z+Vol_sectperfat+1
	sts	pprint+1, r16
	ldd	r16, Z+Vol_sectperfat+0
	sts	pprint+0, r16
	call	print
	.db	"Sectors per FAT.......................:", 0x83, 0x82, 0x81, 0x80, CR, LF, 0	

	ldd	r16, Z+Vol_sectperclst
	sts	pprint+0, r16
	call	print
	.db	"Sectors per cluster...................:", 0x80, CR, LF, 0, 0

	ldd	r16, Z+Vol_bytespsect+1
	sts	pprint+1, r16
	ldd	r16, Z+Vol_bytespsect
	sts	pprint+0, r16
	call	print
	.db	"Bytes per sector......................:", 0x81, 0x80, CR, LF, 0	

	ldd	r16, Z+Vol_reservedsect+1
	sts	pprint+1, r16
	ldd	r16, Z+Vol_reservedsect
	sts	pprint+0, r16
	call	print
	.db 	"Reserved sectors......................:", 0x81, 0x80, CR, LF, 0	

	ldd	r16, Z+Vol_fat1start+3
	sts	pprint+3, r16
	ldd	r16, Z+Vol_fat1start+2
	sts	pprint+2, r16
	ldd	r16, Z+Vol_fat1start+1
	sts	pprint+1, r16
	ldd	r16, Z+Vol_fat1start+0
	sts	pprint+0, r16
	call	print
	.db	"1st FAT starts at sector..............:", 0x83, 0x82, 0x81, 0x80, CR, LF, 0	

	ldd	r16, Z+Vol_datastart+3
	sts	pprint+3, r16
	ldd	r16, Z+Vol_datastart+2
	sts	pprint+2, r16
	ldd	r16, Z+Vol_datastart+1
	sts	pprint+1, r16
	ldd	r16, Z+Vol_datastart+0
	sts	pprint+0, r16
	call	print
	.db	"Data starts at sector.................:", 0x83, 0x82, 0x81, 0x80, CR, LF, 0	

	ldd	r16, Z+Vol_Status
	sbrc	r16, Vol__FAT32
	rjmp	mountcmd32info

	ldd	r16, Z+Vol_dirsectors
	sts	pprint+0, r16
	call	print
	.db	"FAT16 Volume with root dir sectors....:", 0x80, CR, LF, 0, 0
	
	ldd	r16, Z+Vol_rootdir+3
	sts	pprint+3, r16
	ldd	r16, Z+Vol_rootdir+2
	sts	pprint+2, r16
	ldd	r16, Z+Vol_rootdir+1
	sts	pprint+1, r16
	ldd	r16, Z+Vol_rootdir+0
	sts	pprint+0, r16
	call	print
	.db	"The root dir starts at sector.........:", 0x83, 0x82, 0x81, 0x80, CR, LF, 0
	ret

mountcmd32info:
	ldd	r16, Z+Vol_rootdir+3
	sts	pprint+3, r16
	ldd	r16, Z+Vol_rootdir+2
	sts	pprint+2, r16
	ldd	r16, Z+Vol_rootdir+1
	sts	pprint+1, r16
	ldd	r16, Z+Vol_rootdir+0
	sts	pprint+0, r16
	call	print
	.db	"FAT32 Volume root dir start cluster...:", 0x83, 0x82, 0x81, 0x80, CR, LF, 0
	ret
