;--------------------------------------------------------------------------
;
;	show version
;
;
;
cmd_showvers:
	ldi	zl, low(hello)
	ldi	zh, high(hello)
cmd_showvers010:
	ld	r24, Z+
	tst	r24
	breq	cmd_showvers020
	call	serout
	rjmp	cmd_showvers010
cmd_showvers020:
	call	print
	.db	"CPLD Interface is: ", '0'+cpldif/10, '0'+cpldif%10, CR, LF, 0
	clc
	ret
;--------------------------------------------------------------------------
;
;	show internal
;
;	This will be a command that will print all dynamic data structures
;	currently it just displays information about the first vcb
;
cmd_showint:
	push	yl
	push	yh
	lds	yl, volqueue+0
	lds	yh, volqueue+1
	sbiw	yh:yl, 0
	brne	cmd_showint010
	call	print
	.db	CR, LF
	.db	"No Volume! ", CR, LF, 0
	rjmp	cmd_showint020
cmd_showint010:
	rcall	cmd_showintprint
cmd_showint020:
	rcall	cmd_showintirqs

cmd_showintexit:
	pop	yh
	pop	yl
	clc
	ret


cmd_showintirqs:
	lds	r16, daticount
	sts	pprint+0, r16
	lds	r16, datocount
	sts	pprint+1, r16
	lds	r16, iackcount
	sts	pprint+2, r16
	lds	r16, initcount
	sts	pprint+3, r16
	lds	r16, log_pointer+0
	lds	r17, log_pointer+1
	sts	pprint+4, r16
	sts	pprint+5, r17
	call	print
	.db	TAB, "Log Ptr  0x", 0x85, 0x84, CR, LF
	.db	TAB, "DATI     0x", 0x80, CR, CR, LF
	.db	TAB, "DATO     0x", 0x81, CR, CR, LF
	.db	TAB, "IACK     0x", 0x82, CR, CR, LF
	.db	TAB, "INIT     0x", 0x83, CR, CR, LF
	sts	daticount, zero
	sts	datocount, zero
	sts	iackcount, zero
	sts	initcount, zero
	lds	r16, CSRL
	lds	r17, CSRH
	sts	pprint+0, r16
	sts	pprint+1, r17
	call	print
	.db	TAB, "CSR(octal) ", 0xa0, CR, LF, 0
	ret

cmd_showintprint:
	sts	pprint+0, yl
	sts	pprint+1, yh
	call	print
	.db	CR, LF
	.db	"Volume Control Block", CR, LF
	.db	TAB, "VCB Addr.... 0x", 0x81, 0x80, CR, LF, 0, 0	
	ldd	zl, Y+Vol_diriob+0
	ldd	zh, Y+Vol_diriob+1
	ldd	r18, Y+Vol_fatiob+0
	ldd	r19, Y+Vol_fatiob+1
	sts	pprint+0, zl
	sts	pprint+1, zh
	sts	pprint+2, r18
	sts	pprint+3, r19
	ldd	r16, Z+P_Cluster+0
	ldd	r17, Z+P_Cluster+1
	ldd	r18, Z+P_Cluster+2
	ldd	r19, Z+P_Cluster+3
	sts	pprint+4, r16
	sts	pprint+5, r17
	sts	pprint+6, r18
	sts	pprint+7, r19
	ldd	r16, Y+Vol_DirCluster+0
	ldd	r17, Y+Vol_DirCluster+1
	ldd	r18, Y+Vol_DirCluster+2
	ldd	r19, Y+Vol_DirCluster+3
	sts	pprint+8, r16
	sts	pprint+9, r17
	sts	pprint+10, r18
	sts	pprint+11, r19
	ldd	r16, Y+Vol_DirPointer+0
	ldd	r17, Y+Vol_DirPointer+1
	ldd	r18, Z+P_NumSect
	ldd	r19, Y+Vol_DirCount
	sts	pprint+12, r16
	sts	pprint+13, r17
	sts	pprint+14, r18
	sts	pprint+15, r19
	call	print
	.db	TAB, "DIR IOB..... 0x", 0x81, 0x80, CR, LF	
	.db	TAB, "FAT IOB..... 0x", 0x83, 0x82, CR, LF	
	.db	TAB, "IO Cluster.. 0x", 0x87, 0x86, 0x85, 0x84, CR, LF
	.db	TAB, "DirCluster.. 0x", 0x8b, 0x8a, 0x89, 0x88, CR, LF
	.db	TAB, "DirPointer.. 0x", 0x8d, 0x8c, CR, LF
	.db	TAB, "Num Sector.. 0x", 0x8e, SPACE, CR, LF
	.db	TAB, "Dir Count... 0x", 0x8f, CR, LF, 0
	ret
;--------------------------------------------------------------------------
;
;	show units
;
cmd_showunits:
	push	xl
 	push	xh
	push	yl
	push	yh
	ldi	yl, low(unittable)
	ldi	yh, high(unittable)
	clr	r17
;
;
;
cmd_showunit:
	sts	pprint+0, yl		; unit control block address
	sts	pprint+1, yh		;
	mov	r18, r17
	ori	r18, '0'
	sts	pprint+6, r18
	ldd	r18, Y+ucb_status
	sbrc	r18, ucb__part
	rjmp	cmd_showunitpart
	sbrc	r18, ucb__file
	rjmp	cmd_showunitfile
	call	print
	.db	CR, LF
	.db	"Unit ", 0x96, " (0x", 0x81, 0x80, ") is not attached "
	.db	CR, LF, 0, 0
	rjmp	cmd_showunitnext
;
;	Unit is attached to partition
;
cmd_showunitpart:
	ldd	zl, Y+ucb_imgptr+0
	ldd	zh, Y+ucb_imgptr+1
	sts	pprint+2, zl		; partition control block address
	sts	pprint+3, zh
	ldd	xl, Z+pcb_drvtab+0
	ldd	xh, Z+pcb_drvtab+1
	sts	pprint+4, xl		; drive table entry address
	sts	pprint+5, xh
	ldd	r18, Y+ucb_status
	sts	pprint+7, r18
	ldd	r18, Z+pcb_id
	sts	pprint+8, r18
	ldd	r18, Z+pcb_start+0
	sts	pprint+9, r18
	ldd	r18, Z+pcb_start+1
	sts	pprint+10, r18
	ldd	r18, Z+pcb_start+2
	sts	pprint+11, r18
	ldd	r18, Z+pcb_start+3
	sts	pprint+12, r18
	call	print
	.db	CR, LF, "Unit ", 0x96, " (0x", 0x81, 0x80
	.db	") is attached to partition ", 0x88
	.db	" (0x", 0x83, 0x82, ") starting at sector 0x", 0x8c
	.db	0x8b, 0x8a, 0x89, CR, LF, 0
	movw	Z, X
	push	r17
	rcall	cmd_showdriveinfo
	pop	r17
	rjmp	cmd_showunitnext
;
;
;
cmd_showunitfile:
	ldd	zl, Y+ucb_imgptr+0
	ldd	zh, Y+ucb_imgptr+1
	sts	pprint+2, zl		; partition control block address
	sts	pprint+3, zh
	call	print
	.db	CR, LF, "Unit ", 0x96, " (0x", 0x81, 0x80
	.db	") is attached to file (0x", 0x83, 0x82, ") /", NULL, NULL
	ldd	xl, Z+fcb_filename+0
	ldd	xh, Z+fcb_filename+1
cmd_showunitfile010:
	ld	r24, X+
	tst	r24
	breq	cmd_showunitfile020
	call	serout
	rjmp	cmd_showunitfile010
cmd_showunitfile020:
	call	seroutcrlf
	ldd	r16, Z+fcb_Flag
	sbrs	r16, F__Contig
	rjmp	cmd_showunitfile030
	call	print
	.db	"  File is continguous.", CR, LF, 0, 0
cmd_showunitfile030:
	push	yl
	push	yh
	movw	yh:yl, zh:zl
	rcall	printfraglist
	pop	yh
	pop	yl
	ldd	xl, Z+fcb_drvtab+0
	ldd	xh, Z+fcb_drvtab+1
	sts	pprint+4, xl		; drive table entry address
	sts	pprint+5, xh
	movw	zh:zl, xh:xl
	push	r17
	rcall	cmd_showdriveinfo
	pop	r17
;
;
;
cmd_showunitnext:
	adiw	yh:yl, ucb_size
	inc	r17
	cpi	r17, units
	brsh	cmd_showunitnext010
	rjmp	cmd_showunit
cmd_showunitnext010:
	pop	yh
	pop	yl
	pop	xh
	pop	xl
	clc
	ret
;-----------------------------------------------------------------------------
;
;	show partitions
;
cmd_showpart:
	push	xl
 	push	xh
	push	yl
	push	yh
	call	seroutcrlf
	ldi	yl, low(pcbqueue)
	ldi	yh, high(pcbqueue)


cmd_showpartnext:
	ldd	xl, Y+0
	ldd	xh, Y+1
	sbiw	xh:xl, 0
	brne	cmd_showpart010
	rjmp	cmd_showpartexit

cmd_showpart010:
	movw	Y, X
	ldd	r18, Y+0		; Next partition control block
	sts	pprint+0, r18
	ldd	r18, Y+1
	sts	pprint+1, r18
	ldd	r18, Y+pcb_status	; Flags
	sts	pprint+2, r18
	ldd	r18, Y+pcb_id		; Unit
	sts	pprint+3, r18
	ldd	r18, Y+pcb_start	; Start
	sts	pprint+4, r18
	ldd	r18, Y+pcb_start+1
	sts	pprint+5, r18
	ldd	r18, Y+pcb_start+2
	sts	pprint+6, r18
	ldd	r18, Y+pcb_start+3
	sts	pprint+7, r18
	sts	pprint+8, yl
	sts	pprint+9, yh
	ldd	r18, Y+pcb_mbrsector+0
	sts	pprint+10, r18
	ldd	r18, Y+pcb_mbrsector+1
	sts	pprint+11, r18
	ldd	r18, Y+pcb_mbrsector+2
	sts	pprint+12, r18
	ldd	r18, Y+pcb_mbrsector+3
	sts	pprint+13, r18
	call	print
	.db	"Partition ", 0x83, " (pcb:0x", 0x89, 0x88, ")"
	.db	" starting at sector 0x", 0x87, 0x086, 0x85, 0x84
	.db	" MBR at 0x", 0x8d, 0x8c, 0x8b, 0x8a, NULL, NULL
	ldd	r16, Y+pcb_status
;	sts	pprint+0, r16
;	call	print
;	.db	" status 0x", 0x80, 0
	sbrs	r16, pcb__idle
	rjmp	cmd_showpart020
	ldd	r16, Y+pcb_offset
	sts	pprint+0, r16
	call	print
	.db	" is idle offset 0x01", 0x80, CR, LF, NULL
	ldd	zl, Y+pcb_drvtab+0
	ldd	zh, Y+pcb_drvtab+1
	rcall	cmd_showdriveinfo
	rjmp	cmd_showpartnext

cmd_showpart020:
	sbrs	r16, pcb__fat
	rjmp	cmd_showpart030
	ldd	r16, Y+pcb_id
	sts	pprint+0, r16
	call	print
	.db	" is volume ", 0x90, ":", CR, LF, " Label:", 0x22, 0x00
	ldd	xl, Y+pcb_vcb+0
	ldd	xh, Y+pcb_vcb+1
	adiw	xh:xl, Vol_Label
	ldi	r16, 11
cmd_showpart025:
	ld	r24, X+
	call	serout
	dec	r16
	brne	cmd_showpart025
	ldd	r16, Y+pcb_sectors+0
	sts	pprint+0, r16
	ldd	r16, Y+pcb_sectors+1
	sts	pprint+1, r16
	ldd	r16, Y+pcb_sectors+2
	sts	pprint+2, r16
	ldd	r16, Y+pcb_sectors+3
	sts	pprint+3, r16
	call	print
	.db	0x22, " Volume Size:", 0xD0, " Sectors", CR, LF, 0
	rjmp	cmd_showpartnext

cmd_showpart030:
	sbrs	r16, pcb__attach
	rjmp	cmd_showpart040
	call	print
	.db	" is attached", CR, LF, NULL, NULL
	ldd	zl, Y+pcb_drvtab+0
	ldd	zh, Y+pcb_drvtab+1
	rcall	cmd_showdriveinfo
	rjmp	cmd_showpartnext

cmd_showpart040:
	call	print
	.db	" is not attached", CR, LF, NULL, NULL
	ldd	zl, Y+pcb_drvtab+0
	ldd	zh, Y+pcb_drvtab+1
	rcall	cmd_showdriveinfo
	rjmp	cmd_showpartnext

cmd_showpartexit:
	pop	yh
	pop	yl
	pop	xh
	pop	xl
	clc
	ret

;
;

;--------------------------------------------------------------------------
;
;
;
;
cmd_showdriveinfo:
	push	r16
	sbiw	zh:zl, 0
	brne	cmd_showdriveinfo010
	call	mprint
	.dw	msgdriveunk
	call	seroutcrlf
	rjmp	cmd_showdriveinfo090
	
cmd_showdriveinfo010:
	ldd	r16, Z+drv_capacity+0
	sts	pprint+0, r16
	ldd	r16, Z+drv_capacity+1
	sts	pprint+1, r16
	ldd	r16, Z+drv_capacity+2
	sts	pprint+2, r16
	ldd	r16, Z+drv_capacity+3
	sts	pprint+3, r16
	ldd	r16, Z+drv_sectors
	sts	pprint+4, r16
	ldd	r16, Z+drv_tracks
	sts	pprint+5, r16
	ldd	r16, Z+drv_cylinders+0
	sts	pprint+6, r16
	ldd	r16, Z+drv_cylinders+1
	sts	pprint+7, r16
	ldd	r16, Z+drv_type
	sts	pprint+8, r16
	ldd	r16, Z+drv_flags
	sts	pprint+9, r16
	ldd	r16, Z+drv_name+0
	sts	pprint+10, r16
	ldd	r16, Z+drv_name+1
	sts	pprint+11, r16
	ldd	r16, Z+drv_name+2
	sts	pprint+12, r16
	ldd	r16, Z+drv_name+3
	sts	pprint+13, r16
	call	print
	.db	"  Drive has 0x", 0x83, 0x82, 0x81, 0x80, " blocks, 0x", 0x84
	.db	" sectors/track, 0x", 0x85, " tracks/cylinder and 0x", 0x87, 0x86
	.db	" cylinders  ", CR, LF
	.db	"  Drive type/flags and name 0x", 0x88, "/0x", 0x89, "  ", 0x9a
	.db	0x9b, 0x9c, 0x9d, CR, LF, CR, LF, NULL

cmd_showdriveinfo090:
	pop	r16
	ret
;--------------------------------------------------------------------------
;
;	Logging uses GPR_GPR1
;
;	
cmd_showlog:
	push	yl
	push	yh
	call	logprint
	pop	yh
	pop	yl
	clc
	ret

;--------------------------------------------------------------------------
;
;
;
showlinked:
	lds	yl, volqueue+0
	lds	yh, volqueue+1		; get current volume
	sbiw	yh:yl, 0
	brne	showlinked010
	call	mprint
	.dw	msgnovolume
	clc
	clc
	ret
showlinked010:
	movw	r23:r22, yh:yl		; Volume Control Block
	ldi	yl, low(sdio)
	ldi	yh, high(sdio)
	lds	r16, nbr+0
	lds	r17, nbr+1
	lds	r18, nbr+2
	lds	r19, nbr+3
	std	Y+P_Cluster+0, r16
	std	Y+P_Cluster+1, r17
	std	Y+P_Cluster+2, r18
	std	Y+P_Cluster+3, r19
	sts	pprint+0, r16
	sts	pprint+1, r17
	sts	pprint+2, r18
	sts	pprint+3, r19
	movw	r25:r24, yh:yl
	call	LinkedCluster
	sts	pprint+8, r24
	ldd	r16, Y+P_Cluster+0
	ldd	r17, Y+P_Cluster+1
	ldd	r18, Y+P_Cluster+2
	ldd	r19, Y+P_Cluster+3
	sts	pprint+4, r16
	sts	pprint+5, r17
	sts	pprint+6, r18
	sts	pprint+7, r19
	call	print
	.db	CR, LF, "Linked Cluster Returned 0x", 0x88, " Cluster 0x"
	.db	0x83, 0x82, 0x81, 0x80, "-->0x", 0x87, 0x86, 0x85, 0x84, CR, LF, 0
	clc
	ret
;--------------------------------------------------------------------------
;
;	New "type <filename>" command that makes use of the new file IO
;	primitives.
;
typecmd_naf:
	call	mprint
	.dw	msgtypenaf
	clc
	ret
typecmd_fnf:
	call	mprint
	.dw	msgtypefnf
	clc
	ret
typecmd_open:
	sts	pprint+0, r24
	call	mprint
	.dw	msgtypeerr
	clc
	ret
;
typecmd:
	lds	yl, volqueue+0
	lds	yh, volqueue+1		; get current volume
	sbiw	yh:yl, 0
	brne	typecmd010
	call	mprint
	.dw	msgnovolume
	clc
	clc
	ret
typecmd010:
	lds	xl, cdstring+2
	lds	xh, cdstring+3
	st	X, zero			; Zero Terminate the string
	lds	r22, cdstring+0
	lds	r23, cdstring+1
	movw	r25:r24, yh:yl
	call	Name2DirEntry
	tst	r24
	brne	typecmd_fnf
	ldd	zl, Y+Vol_DirPointer+0
	ldd	zh, Y+Vol_DirPointer+1
	sbiw	zh:zl, 0
	breq	typecmd_naf
	ldd	r18, Z+D_Attr
	sbrc	r18, A_Directory
	rjmp	typecmd_naf
	movw	r25:r24, yh:yl
	call	ReadFileOpen
	movw	yh:yl, r25:r24
	tst	r25
	breq	typecmd_open
	call	seroutcrlf
typecmd020:
	movw	r25:r24, yh:yl
	call	ReadFileByte
	ldd	r25, Y+fcb_flag
	sbrc	r25, F__ERR
	rjmp	typecmd060
	cpi	r24, LF
	breq	typecmd040
	cpi	r24, CR
	breq	typecmd050
typecmd030:
	sbrc	r24, 7
	ldi	r24, '.'
	call	serout
	rjmp	typecmd020
typecmd040:
	call	seroutcrlf
	movw	r25:r24, yh:yl
	call	ReadFileByte
	ldd	r25, Y+fcb_flag
	sbrc	r25, F__ERR
	rjmp	typecmd060
	cpi	r24, CR
	breq	typecmd020
	rjmp	typecmd030
typecmd050:
	call	seroutcrlf
	movw	r25:r24, yh:yl
	call	ReadFileByte
	ldd	r25, Y+fcb_flag
	sbrc	r25, F__ERR
	rjmp	typecmd060
	cpi	r24, LF
	breq	typecmd020
	rjmp	typecmd030
typecmd060:
	movw	r25:r24, yh:yl
	call	ReadFileClose
	clc
	ret

;--------------------------------------------------------------------------
;
;
;
cmdreadinit:
	push	xl
	push	xh
	ldi	r24, 0
	call	readinit
	sts	pprint+0, r24
	call	print
	.db	CR, LF
	.db	"Readinit -- Exit-Code 0x", 0x80, CR, LF, 0
	pop	xh
	pop	xl
	clc
	ret
;--------------------------------------------------------------------------
;
;
;
cmdhelp:
	ldi	zl, low(help5)
	ldi	zh, high(help5)

cmdhelp010:
	ld	r24, Z+
	tst	r24
	breq	cmdhelp020
	call	serout
	rjmp	cmdhelp010
cmdhelp020:
	clc
	ret

;--------------------------------------------------------------------------
;
;


cmd_showjobs:
	push	r24
	push	r25
	push	xl
	push	xh
	push	yl
	push	yh
	push	zl
	push	zh

	call	seroutcrlf
	ldi	yl, low(jcb0)
	ldi	yh, high(jcb0)
	call	jcbprintalt
	ldi	yl, low(jcb1)
	ldi	yh, high(jcb1)
	call	jcbprintalt
	ldi	yl, low(jcb2)
	ldi	yh, high(jcb2)
	call	jcbprintalt
	ldi	yl, low(jcb3)
	ldi	yh, high(jcb3)
	call	jcbprintalt
	
	clc
	pop	zh
	pop	zl
	pop	yh
	pop	yl
	pop	xh
	pop	xl
	pop	r25
	pop	r24
	ret

jcbprintalt:
	sts	pprint+8, yl
	sts	pprint+9, yh
	ldd	zl, Y+jcb_stack+0
	ldd	zh, Y+jcb_stack+1
	sts	pprint+0, zl
	sts	pprint+1, zh

	ldd	r18, Y+jcb_joblist+0
	ldd	r19, Y+jcb_joblist+1
	sts	pprint+2, r18
	sts	pprint+3, r19
	ldd	r18, Y+jcb_priority
	sts	pprint+4, r18
	adiw	zh:zl, 1		; Stack is post decrement, make offset=register
	ldd	r18, Z+8		; SREG
	sts	pprint+5, r18
	ldd	r18, Z+34
	ldd	r19, Z+33
	sts	pprint+6, r18		; PC
	sts	pprint+7, r19
	ldd	r18, Y+jcb_flags
	sbrc	r18, 0
	rjmp	jcbprint010	
	call	print
	.db	"Job Control Block 0x", 0x89, 0x88, CR, LF
	.db	"Job Program Counter 0x", 0x87, 0x86, " Status 0x", 0x85, " "
	.db	"Priority 0x", 0x84, " Stack pointer 0x", 0x81, 0x80, " "
	.db	"Queue 0x", 0x83, 0x82, CR, LF, 0, 0
	rjmp	jcbprint020
jcbprint010:
	call	print
	.db	"Job Control Block 0x", 0x89, 0x88, CR, LF
	.db	"Job Program Counter 0x", 0x87, 0x86, " Status 0x", 0x85, " "
	.db	"Priority 0x", 0x84, " Stack pointer 0x", 0x81, 0x80, " "
	.db	"Waiting 0x", 0x83, 0x82, " Ticks", CR, LF, 0, 0
jcbprint020:	
	ldi	xl, low(pprint)
	ldi	xh, high(pprint)
	ldi	r17, 16
jcbprint030:
	ld	r18, Z+			; R0..R15
	st	X+, r18
	dec	r17
	brne	jcbprint030	
	ldd	r18, Z+16		; R8 is at bottom of stack
	sts	pprint+8, r18
	call	print
	.db	"R0-7  : 0x", 0x80, ", 0x", 0x81, ", 0x", 0x82, ", 0x", 0x83
	.db	", 0x", 0x84, ", 0x", 0x85, ", 0x", 0x86, ", 0x", 0x87, CR, LF
	.db	"R8-15 : 0x", 0x88, ", 0x", 0x89, ", 0x", 0x8a, ", 0x", 0x8b
	.db	", 0x", 0x8c, ", 0x", 0x8d, ", 0x", 0x8e, ", 0x", 0x8f, CR, LF
	.db	0,0
	ldi	xl, low(pprint)
	ldi	xh, high(pprint)
	ldi	r17, 16
jcbprint040:
	ld	r18, Z+			; R16..31
	st	X+, r18
	dec	r17
	brne	jcbprint040	
	call	print
	.db	"R16-23: 0x", 0x80, ", 0x", 0x81, ", 0x", 0x82, ", 0x", 0x83 
	.db	", 0x", 0x84, ", 0x", 0x85, ", 0x", 0x86, ", 0x", 0x87, CR, LF
	.db	"R24-31: 0x", 0x88, ", 0x", 0x89, ", 0x", 0x8a, ", 0x", 0x8b 
	.db	", 0x", 0x8c, ", 0x", 0x8d, ", 0x", 0x8e, ", 0x", 0x8f, CR, LF
	.db	0,0
	ret

	

;--------------------------------------------------------------------------
;
;	Make show free callable without changing registers to debug
;	MountVolume
;
showfree:
	push	r24
	push	r25
	push	xl
	push	xh
	push	yl
	push	yh
	push	zl
	push	zh
	call	print
	.db	CR, LF
	.db	"List of free memory blocks:", CR, LF, 0
	
	
	ldi	yl, low(heap)
	ldi	yh, high(heap)
showfree010:
	movw	Z, Y
	ldd	yl, Z+2
	ldd	yh, Z+3			; Address of next
	sbiw	yh:yl, 0
	breq	showfree090
	
	ldd	r24, Y+0
	ldd	r25, Y+1		; Get Size
	movw	xh:xl, yh:yl
	sbiw	r25:r24, 2		; Adjust to "user"
	adiw	xh:xl, 2
	
	sts	pprint+0, xh
	sts	pprint+1, xl
	sts	pprint+2, r25
	sts	pprint+3, r24
	call	print
	.db	TAB, "Start 0x", 0x80, 0x81, " Size 0x", 0x82, 0x83, CR, LF, 0
	rjmp	showfree010
	
	
	
showfree090:
	clc
	pop	zh
	pop	zl
	pop	yh
	pop	yl
	pop	xh
	pop	xl
	pop	r25
	pop	r24
	ret
	


