;--------------------------------------------------------------------------
;
;	Logging uses GPR_GPR1


;
;	New Logging with small 4 byte log entries. 
;
;	log_record
;	log_id		.byte	1
;	log_ext		.byte	1
;	log_val		.byte	2
;
;	log_id		name	extension	value
;	bit4..7	bit0..3
;	0		noop
;	1	0000	iack	timestamp	vector
;	2	000e	init	timestamp	0000
;	3	addr	dato	timestamp	data
;	4	addr	dati	timestamp	data
;	5
;	6		dev	timestamp	
;	7	
;	8	fc	fnc0	timestamp	CSR	
;	9	0000	address	BARL		BARH, BAEL
;	A	fc	fnc2			MPR
;	B	unit	seek	timestamp	DAR
;	C	24..27	pbn	bits16..23	bits0..15
;	D	unit	disk	ucb_status	ucb_diskaddr	
;	E		trace	id		value
;	F	noop








;
;	Lollipop shaped logging buffer
;
	ldi	r24, low((log_size+1)/8)
	ldi	r25, high((log_size+1)/8)
	ldi	yl, low(log_buffer)
	ldi	yh, high(log_buffer)
	sts	pprint+8, r24
	sts	pprint+9, r25
	sts	pprint+10, yl
	sts	pprint+11, yh
	call	print
	.db	CR, LF
	.db	"Logging ", 0xc8, " start entries starting at 0x", 0x8b, 0x8a, CR, LF, 0, 0
logprint010:
	rcall	logprintentry
	sbiw	r25:r24, 1
	brne	logprint010

	ldi	r24, low((log_size+1)/8)
	ldi	r25, high((log_size+1)/8)
	lds	yl, log_pointer+0
	lds	yh, log_pointer+1
	sbrs	yh, 3
	rjmp	logprintexit

logprint:

	ldi	r24, low((log_size+1)/4)
	ldi	r25, high((log_size+1)/4)
	lds	yl, log_pointer+0
	lds	yh, log_pointer+1
	sts	pprint+8, r24
	sts	pprint+9, r25
	sts	pprint+10, yl
	sts	pprint+11, yh
	call	print
	.db	CR, LF
	.db	"Logging ", 0xc8, " circular entries starting at 0x", 0x8b, 0x8a, CR, LF, 0
logprint020:
	rcall	logprintentry

;	sbrc	yh,7			;
;	ori	yh, 0x08		;
	andi	yh, high(log_size)	;
	ori	yh, high(log_buffer)	;

	sbiw	r25:r24, 1
	brne	logprint020

logprintexit:
	ldi	yl, low(log_buffer)
	ldi	yh, high(log_buffer)
	sts	log_pointer+0, yl
	sts	log_pointer+1, yh
	ret



;--------------------------------------------------------------------------
;
;
;
logentry:
	lds	r16, logdataentryc
	cpi	r16, 4
	breq	logentry010
	sec
	ret
logentry010:
	ldi	yl, low(logdataentry)
	ldi	yh, high(logdataentry)
	call	logprintentry
	clc
	ret
	
;--------------------------------------------------------------------------
;

logprintentry:
	push	r24
	ldd	r16, Y+0
	ldd	r17, Y+1
	ldd	r18, Y+2
	ldd	r19, Y+3
	sts	pprint+0, r16
	sts	pprint+1, r17		; And a negated value for timestamps
	neg	r17			; is we use TCA0_SPLIT_LCNT as timestamp
	sts	pprint+5, r17		; 
	sts	pprint+2, r18
	sts	pprint+3, r19
	mov	zl, r16
	swap	zl
	andi	zl, 0x0F
	clr	zh
	subi	zl, low(-logprinttbl)
	sbci	zh, high(-logprinttbl)
	icall
	st	Y+, zero
	st	Y+, zero
	st	Y+, zero
	st	Y+, zero
	pop	r24
	ret
	
logprinttbl:
	rjmp	logprintnoop		; 0
	rjmp	logprintiack		; 1
	rjmp	logprintinit		; 2
	rjmp	logprintdato		; 3
	rjmp	logprintdati		; 4
	rjmp	logprintnoop		; 5
	rjmp	logprintnoop		; 6
	rjmp	logprintnoop		; 7
	rjmp	logprintfnc0		; 8
	rjmp	logprintaddress		; 9
	rjmp	logprintfnc2		; A
	rjmp	logprintseek		; B
	rjmp	logprintpbn		; C
	rjmp	logprintdiskaddr	; D
	rjmp	logprinttrace		; E
	rjmp	logprintnoop		; F



logprintnoop:
	ret
	


logprintiack:
	call	print
		;----+----1----+----2----+----3
	.db	"IACK    (", 0x85, ") Vector  ", 0xa2, CR, LF, 0
	ret
logprintinit:
	call	print
		;----+----1----+----2----+----3
	.db	"INIT    (", 0x85, ") Input 0x", 0x82, ", INTFLAGS 0x", 0x83, CR, LF, 0
	ret
logprintdato:
	lds	r16, pprint+0
	bst	r16, 3		; Make it "Octal"
	bld	r16, 4
	andi	r16, 0x16
	sts	pprint+0, r16
	call	print
		;----+----1----+----2----+----3
	.db	"DATO    (", 0x85, ") ", 0, 0
	rcall	logaddr2name
	call	print
	.db	"  Value    ", 0xa2, CR, LF, 0, 0
	ret

logprintdati:
	lds	r16, pprint+0
	bst	r16, 3		; Make it "Octal"
	bld	r16, 4
	andi	r16, 0x16
	sts	pprint+0, r16
	call	print
		;----+----1----+----2----+----3
	.db	"DATI    (", 0x85, ") ", 0, 0
	rcall	logaddr2name
	call	print
	.db	"  Value    ", 0xa2, CR, LF, 0, 0
	ret


logprintfnc0:
	lds	zl, pprint+0		; Logging Code
	andi	zl, 0x0E		; Isolate Funciton code
	lsl	zl
	lsl	zl
	clr	zh
	subi	zl, low(-FNCName)
	sbci	zh, high(-FNCName)
logprintfnc0_010:
	ld	r24, Z+
	tst	r24
	breq	logprintfnc0_020
	call	serout
	rjmp	logprintfnc0_010
logprintfnc0_020:	
	lds	r16, pprint+0
	lsr	r16
	andi	r16, 0x07
	ori	r16, '0'
	sts	pprint+0, r16
	call	print
		;----+----1----+----2----+----3
	.db	"   (", 0x85, ") CSR  Value    ", 0xa2, " (", 0x90, ")",   CR, LF, 0, 0
	ret
logprintaddress:
	call	print
		;----+----1----+----2----+----3
	.db	TAB, "     DMA  Address  ", 0xb1, CR, LF, 0
	ret
logprintfnc2:
	call	print
		;----+----1----+----2----+----3
	.db	"FNC2    (", 0x85, ") MPR    0x", 0x83, 0x82, CR, LF, 0
	ret
logprintseek:
	ldd	r16, Y+0
	andi	r16, driveselect
	ori	r16, '0'
	sts	pprint+4, r16
	call	print
		;----+----1----+----2----+----3
	.db	"SEEK:", 0x94, "  (", 0x85, ") DAR        ", 0xa2, CR, LF, 0, 0
	ret
logprintpbn:
	andi	r16, 0x0F
	sts	pprint+0, r16
	call	print
	.db	TAB, "     PBN  0x", 0x80, 0x81, 0x82, 0x83, CR, LF, 0
	ret
	
logprintdiskaddr:
	call	print
		;----+----1----+----2----+----3
	.db	TAB, "Diskaddr     ", 0xa2, ", Diskstatus 0x", 0x81, CR, LF, 0
	ret

;
;	Trace could actually be extended to support various formats
;	using bits 0..3 of type field
;
logprinttrace:
	call	print
	.db	"Trace ID 0x", 0x81, ", Bytes 0x", 0x82, " 0x", 0x83, " Word ", 0xa2, CR, LF, 0, 0
	ret


;	.db	"DATI    (66) CSR  Value    "

logaddr2name:
	ldd	zl, Y+0
	andi	zl, 0x0E
	lsl	zl
	clr	zh
	subi	zl, low(-REGName)
	sbci	zh, high(-REGName)
logaddr2name010:
	ld	r24, Z+
	tst	r24
	breq	logaddr2name020
	call	serout
	rjmp	logaddr2name010
logaddr2name020:
	ret
	
;--------------------------------------------------------------------------
;
;
;
logreg:
	lds	r18, tpflags
	sbrc	r18, tp__no
	rjmp	logregno
	sbi	GPR_GPR1, log__reg
	clc
	ret
logregno:
	cbi	GPR_GPR1, log__reg
	clc
	ret

logiack:
	lds	r18, tpflags
	sbrc	r18, tp__no
	rjmp	logiackno
	sbi	GPR_GPR1, log__iack
	clc
	ret
logiackno:
	cbi	GPR_GPR1, log__iack
	clc
	ret

logunits:
	lds	r18, tpflags
	sbrc	r18, tp__no
	rjmp	logunitsno
	in	r18, GPR_GPR1
	ori	r18, log__units
	out	GPR_GPR1, r18
	clc
	ret
logunitsno:
	in	r18, GPR_GPR1
	andi	r18, ~log__units
	out	GPR_GPR1, r18
	clc
	ret

logunit:
	push	r17
	lds	r17, attunit
	ldi	r18, (1<<log__rl0)
logunit010:
	dec	r17
	brmi	logunit020
	lsl	r18
	rjmp	logunit010
logunit020:
	lds	r17, tpflags
	sbrc	r17, tp__no
	rjmp	logunitno
	in	r17, GPR_GPR1
	or	r17, r18
	out	GPR_GPR1, r17
	pop	r17
	clc
	ret
logunitno:
	com	r18
	in	r17, GPR_GPR1
	and	r17, r18
	out	GPR_GPR1, r17
	pop	r17
	clc
	ret

logstatus:
	lds	r18, tpflags
	sbrc	r18, tp__no
	rjmp	logallno
	in	r18, GPR_GPR1
;
	call	print
	.db	CR, LF
	.db	"Logging device register access .:", NULL
	bst	r18, log__reg
	rcall	logstatusonoff
;
	call	print
	.db	"Logging Interrupts .............:", NULL
	bst	r18, log__iack
	rcall	logstatusonoff
;
	call	print
	.db	"Logging unit 0 .................:", NULL
	bst	r18, log__rl0
	rcall	logstatusonoff
;
	call	print
	.db	"Logging unit 1 .................:", NULL
	bst	r18, log__rl1
	rcall	logstatusonoff
;
	call	print
	.db	"Logging unit 2 .................:", NULL
	bst	r18, log__rl2
	rcall	logstatusonoff
;
	call	print
	.db	"Logging unit 3 .................:", NULL
	bst	r18, log__rl3
	rcall	logstatusonoff
;
	clc
	ret
logstatusonoff:
	brtc	logstatusonoff010
	call	print
	.db	" on", CR, LF, NULL
	ret
logstatusonoff010:
	call	print
	.db	" off", CR, LF, NULL, NULL
	ret
logallno:
	out	GPR_GPR1, zero
	clc
	ret