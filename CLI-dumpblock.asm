cmddumpbl:
	lds	zl, dumpunit
	andi	zl, 0x03
	swap	zl
	clr	zh
	subi	zl, low(-unittable)
	sbci	zh, high(-unittable)	
	ldd	yl, Z+ucb_imgptr+0		; Get pointer to disk image control block
	ldd	yh, Z+ucb_imgptr+1
	ldd	r18, Z+ucb_status		; Get the status
	sbrs	r18, ucb__file			; Is unit attached to a file?
	rjmp	cmddumppart				; no its a partition
;
;	A file is attached, Y points to the fcb. We put the LBN to the P_Cluster
;	offset of the fcb (file control block) which is then translated to a physical
;	block number by using the fragment list attached to the file control block
;
	ldd	zl, Y+fcb_iob+0
	ldd	zh, Y+fcb_iob+1

	lds	r16, dumpblock+0
	lds	r17, dumpblock+1
	lds	r18, dumpblock+2
	lds	r19, dumpblock+3

	std	Z+P_Cluster+0, r16		; Set start sector for read or write
	std	Z+P_Cluster+1, r17
	std	Z+P_Cluster+2, r18
	std	Z+P_Cluster+3, r19	

	movw	r25:r24, yh:yl
	call	Logical2Physical		; Convert to PBN (pyhsical block number)
	ldd	zl, Y+fcb_iob+0
	ldd	zh, Y+fcb_iob+1
	rjmp	cmddumpblock
	
cmddumppart:
;
;	Y points to the partition control block
;
	ldi	zl, low(sdio)		; Setup parameter block for general IO
	ldi	zh, high(sdio)		; 

	ldd	r16, Y+pcb_start+0	
	ldd	r17, Y+pcb_start+1	
	ldd	r18, Y+pcb_start+2	
	ldd	r19, Y+pcb_start+3
	
	lds	r20, dumpblock+0
	lds	r21, dumpblock+1
	lds	r22, dumpblock+2
	lds	r23, dumpblock+3

	add	r16, r20
	adc	r17, r21
	adc	r18, r22
	adc	r19, r23

	std	Z+P_Sector+0, r16		; Set start sector for read or write
	std	Z+P_Sector+1, r17
	std	Z+P_Sector+2, r18
	std	Z+P_Sector+3, r19	
;	
;
;
cmddumpblock:
	movw	Y, Z
	ldi	xl, low(sdbuffer)	; 
	ldi	xh, high(sdbuffer)	; 
	std	Y+P_Address+0, xl	; Set buffer address for SD-Card block
	std	Y+P_Address+1, xh	; 
	LEDON
	movw	r25:r24, yh:yl
	call	SD_CARD_READ		; 
	clr	zl
	clr	zh
	ldd	xl, Y+P_Address+0
	ldd	xh, Y+P_Address+1

	ldd	r16, Y+P_Sector+0	
	ldd	r17, Y+P_Sector+1	
	ldd	r18, Y+P_Sector+2	
	ldd	r19, Y+P_Sector+3

	sts	pprint+0, r16
	sts	pprint+1, r17
	sts	pprint+2, r18
	sts	pprint+3, r19
	call	print
	.db	CR, LF
	.db	"Dump absolute sector 0x", 0x83, 0x82, 0x81, 0x80, CR, LF, 0

	ldi	r17, 32			; 32 x 16 bytes = 1 Block
cmddumpline:
	sts	pprint+0, zl
	sts	pprint+1, zh
	adiw	zh:zl, 16
	call	print
	.db	0xA0, ": ", 0
	ldi	yl, low(pprint)
	ldi	yh, high(pprint)
	ldi	r16, 16
cmddumpcopybyte:
	ld	r18, X+
	st	Y+, r18
	dec	r16
	brne	cmddumpcopybyte
 	call	print
 	.db	0xA0, " ", 0xA2, " ",0xA4, " ",0xA6, " " 
 	.db	0xA8, " ", 0xAA, " ",0xAC, " ",0xAE , 0

	lds	r18, dumpswitch
	sbrs	r18, dumpswitch_r
	brne	cmddumpline010
	call	print
	.db	" '", 0xE0, 0xE2, 0xE4, 0xE6, 0xE8, 0xEA, 0xEC, 0xEE, "'", 0
	
cmddumpline010:
	lds	r18, dumpswitch
	sbrs	r18, dumpswitch_c
	brne	cmddumpline020
	call	print
	.db	" '", 0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97
	.db	0x98, 0x99, 0x9A, 0x9B, 0x9C, 0x9D, 0x9E, 0x9F, "'", 0

cmddumpline020:

	call	seroutcrlf
	dec	r17
	brne	cmddumpline

	clc
	ret


