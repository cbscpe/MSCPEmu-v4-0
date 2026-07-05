;--------------------------------------------------------------------------
;
;	Read INIT file
;
;	A quick and dirty hack to implement the read and execute the
;	startup configuration file RLV12.INI, of course for a MSCP
;	emulation it will be MSCP.INI. This is work in progress
;
readinit:;(uint_t8 action)
	push	r4
	push	r5			; Record Buffer
	push	r6			; Parameter
	push	r7			; Counter
	push	xl
	push	xh
	push	yl
	push	yh
	mov	r6, r24			; Save Parameter 
	ldi	r24, low(256)
	ldi	r25, high(256)
	call	malloc			; Fetch a command line buffer
	sbiw	r25:r24, 0
	brne	readinit005
	call	mprint
	.dw	msgreadinitall
	ldi	r24, ERR_MALLOC
	rjmp	readinitexit2

readinit005:
	movw	r5:r4, r25:r24
	ldi	r22, low(ReadInitName)
	ldi	r23, high(ReadInitName)
	call	print
	.db	CR, LF
	.db	"Read Init File: '", 0
	movw	xh:xl, r23:r22
readinitx10:
	ld	r24, X+
	tst	r24
	breq	readinitx20
	call	serout
	rjmp	readinitx10
readinitx20:
	call	print
	.db	"'", CR, LF, 0
	lds	r24, volqueue+0
	lds	r25, volqueue+1
	sbiw	r25:r24, 0
	brne	readinit010
	call	mprint
	.dw	msgnovolume
	ldi	r24, ERR_NOVOL
	rjmp	readinitexit1

readinit010:	
	movw	yh:yl, r25:r24		; Save Volume control block
;	uint8_t Name2DirEntry(struct* VolumeControlBlock, char* name)
	call	Name2DirEntry
	tst	r24
	breq	readinit011
	call	mprint
	.dw	msgreadinitfnf
	ldi	r24, FAT_FNF
	rjmp	readinitexit1

readinit011:
	ldd	zl, Y+Vol_DirPointer+0
	ldd	zh, Y+Vol_DirPointer+1
	ldd	r18, Z+D_Attr
	sbrs	r18, A_Directory
	rjmp	readinit012
	call	mprint
	.dw	msgreadinitinv
	ldi	r24, FAT_NAF
	rjmp	readinitexit1

;
;	Open File
;
readinit012:
	movw	r25:r24, yh:yl		; Volume control block
	call	ReadFileOpen
	movw	yh:yl, r25:r24		; File control block
	tst	r25			; Valid?
	brne	readinit015		; Yes
	sts	pprint+0, r24
	call	mprint
	.dw	msgreadinitope
	ldi	r24, FAT_OPE
	rjmp	readinitexit1

readinit015:
	call	mprint
	.dw	msgreadinitopn
;	call	dumpfcb
;
;
;
readinit020:
	movw	xh:xl, r5:r4
	clr	r7			; No bytes in command
readinit030:
	movw	r25:r24, yh:yl
	push	xl
	push	xh
	call	ReadFileByte
	pop	xh
	pop	xl
	ldd	r25, Y+fcb_flag
	sbrc	r25, F__ERR
	rjmp	readinit090
	
	cpi	r24, LF
	breq	readinit040
	cpi	r24, CR
	breq	readinit040
	sbrc	r24, 7
	rjmp	readinit020		; MSB set, this seems a binary file
	st	X+, r24
	inc	r7			; Character count++
	brpl	readinit030
	call	mprint			; Command line longer than 127 bytes not good
	.dw	msgreadinitovr
	ldi	r24, ERR_TOOLONG	; Line Too Long
	rjmp	readinitexit1

readinit040:
	tst	r7			; Anything in command line
	breq	readinit020		; Not really
	ldi	r24, CR
	st	X, r24
	rcall	readshow
	movw	xh:xl, r5:r4
	ld	r24, X
	cpi	r24, ';'		; Skip comments
	breq	readinit020
	ldi	zl, low(2*commandlist)	; Parser table
	ldi	zh, high(2*commandlist)
	sts	tpflags, zero
	cpse	r6, zero		; If Mode = 0 then don't executed
	call	scancommand
	rjmp	readinit020
;
readinit090:
	sbrs	r25, F__EOF		; End of file?
	rjmp	readinit099		; No it's another error
	tst	r7
	breq	readinit091		; Nothing to do
	ldi	r16, CR
	st	X, r16
	rcall	readshow
	movw	xh:xl, r5:r4
	ldi	zl, low(2*commandlist)	; Parser table
	ldi	zh, high(2*commandlist)
	sts	tpflags, zero
	cpse	r6, zero		; If Mode = 0 then don't executed
	call	scancommand
	rjmp	readinit091
	
readinit099:
	sts	pprint+0, r24
	call	print
	.db	CR, LF
#ifdef rlv12emulation
	.db	"Init - Error 0x", 0x80, " reading RLV12.INI"
#endif
#ifdef mscpemulation
	.db	"Init - Error 0x", 0x80, " reading MSCP.INI "
#endif
	.db	CR, LF, 0, 0
	movw	r25:r24, yh:yl
	call	ReadFileClose
	ldi	r24, FAT_RDE
	rjmp	readinitexit1

readinit091:
	movw	r25:r24, yh:yl
	call	ReadFileClose
readinitexit:
	clr	r24
readinitexit1:
	mov	r6, r24
	movw	r25:r24, r5:r4
	call	free
	mov	r24, r6
readinitexit2:
	pop	yh
	pop	yl
	pop	xh
	pop	xl
	pop	r7
	pop	r6
	pop	r5
	pop	r4
	clc				; Can be called via CLI
	ret
;
;
;
readshow:
	call	print
	.db	"Init - Executing Command:'", 0, 0
	movw	xh:xl, r5:r4
readshow010:
	ld	r24, X+
	cpi	r24, CR
	breq	readshow020
	call	serout
	rjmp	readshow010
readshow020:
	call	print
	.db	"'", CR, LF, NULL
	ret
