;--------------------------------------------------------------------------
;
;	Logging uses FLAGS_LOG
;
;	New Logging with small 4 byte log entries. 
;
;	log_record
;	log_id		.byte	1
;	log_ext		.byte	1
;	log_val		.byte	2
;
;	log_id		name		extension	value
;	bit4..7	bit0..3
;	0		filler
;	1	0000	iack		timestamp	vector
;	1	0001	init		timestamp	int_port, int_flags
;	2	0000	romwr		address??	value
;	2	0001	romrd		address??	value
;	3	addr	dato		timestamp	data
;	4	addr	dati		timestamp	data
;	5		unused
;	6		unused
;	7		unused
;	8	RLV12 unit & command	timestamp	data	
;	9	RLV12 unit & command	timestamp	data	
;	A	code	DMA address	BARL		BARH, BAEL
;	B	unit	seek		timestamp	DAR
;	C		diskaddress
;	D	unit	disk		ucb_status	ucb_diskaddr	
;	E		trace		id		value
;	F		unused
;
;--------------------------------------------------------------------------
;
;	Lollipop shaped logging buffer
;
;	The buffer is split in one half reserved for initial logging
;	and the second half is used for circular buffer
;

logprint:
	ldi	r24, low(log_begin/4)	; Number of initial/permanent entries
	ldi	r25, high(log_begin/4)
	sbiw	r25:r24, 0
	breq	logprint100
	ldi	yl, low(log_buffer)	; They always start here
	ldi	yh, high(log_buffer)
	sts	pprint+8, r24
	sts	pprint+9, r25
	sts	pprint+10, yl
	sts	pprint+11, yh
	call	print
	.db	CR, LF
	.db	"Logging ", 0xc8, " start entries starting at 0x", 0x8b, 0x8a, CR, LF, 0, 0
logprint010:
	ldd	r16, Y+0
	tst	r16
	breq 	logprint020
	sts	pprint+0, yl
	sts	pprint+1, yh
	call	print
	.db	"0x", 0x81, 0x80, " ", 0
logprint020:
	rcall	logprintentry
	sbiw	r25:r24, 1
	brne	logprint010

logprint100:
	ldi	r24, low((log_size)/4)
	ldi	r25, high((log_size)/4)
	lds	yl, log_pointer+0
	lds	yh, log_pointer+1
	sts	pprint+8, r24
	sts	pprint+9, r25
	sts	pprint+10, yl
	sts	pprint+11, yh
	call	print
	.db	CR, LF
	.db	"Logging ", 0xc8, " circular entries. Logging Pointer 0x", 0x8b, 0x8a, CR, LF, 0, 0
logprint110:
	ldd	r16, Y+0
	tst	r16
	breq 	logprint120
	sts	pprint+0, yl
	sts	pprint+1, yh
	call	print
	.db	"0x", 0x81, 0x80, " ", 0
logprint120:
	rcall	logprintentry
	sbrc	yh, log_overflow
	subi	yh, high(log_size)
	sbiw	r25:r24, 1
	brne	logprint110

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
;	Prints log entry and then zeroize it
;
logprintentry:
	push	r25
	push	r24
	ldd	r16, Y+0
	ldd	r17, Y+1
	ldd	r18, Y+2
	ldd	r19, Y+3
	sts	pprint+0, r16		; Logging ID
	sts	pprint+1, r17		; Time stamp is now TCB1_CNTL
	sts	pprint+2, r18		; Data Low Byte
	sts	pprint+3, r19		; Data High Byte
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
	pop	r25
	ret
	
logprinttbl:
	rjmp	logprintnone		; 0
	rjmp	logprintint		; 1
	rjmp	logprintrom		; 2
	rjmp	logprintdato		; 3
	rjmp	logprintdati		; 4
	rjmp	logprintnoop		; 5
	rjmp	logprintnoop		; 6
	rjmp	logprintnoop		; 7
	rjmp	logprintcommand		; 8
	rjmp	logprintcommand		; 9
	rjmp	logprintaddress		; A
	rjmp	logprintseek		; B
	rjmp	logprintpbn		; C
	rjmp	logprintdiskaddr	; D
	rjmp	logprinttrace		; E
	rjmp	logprintnoop		; F


logprintnone:
	ret

logprintnoop:
	call	print
		;----+----1----+----2----+----3
	.db	"Undefined log entry 0x", 0x80, " 0x", 0x81, " 0x", 0x82, " 0x", 0x83, CR, LF, 0
	ret
	
logprintrom:
	cpi	r16, log_romrd
	breq	logprintromrd
	cpi	r16, log_romwr
	breq	logprintromwr
	ret
logprintromrd:
	call	print
		;----+----1----+----2----+----3
	.db	"ROM RD  (", 0x81, ") Value   ", 0xa2, CR, LF, 0
	ret

logprintromwr:
	call	print
		;----+----1----+----2----+----3
	.db	"ROM WR  (", 0x81, ") Value   ", 0xa2, CR, LF, 0
	ret

logprintint:
	cpi	r16, log_iack
	breq	logprintiack
	cpi	r16, log_init
	breq	logprintinit
	ret

logprintiack:
	call	print
		;----+----1----+----2----+----3
	.db	"IACK    (", 0x81, ") Vector  ", 0xa2, CR, LF, 0
	ret
logprintinit:
	call	print
		;----+----1----+----2----+----3
	.db	"INIT    (", 0x81, ") Input 0x", 0x82, ", INTFLAGS 0x", 0x83, CR, LF, 0
	ret
logprintdato:
	lds	r16, pprint+0
;	sbrc	r16, 0		; log_rom
;	rjmp	logprintromo
	bst	r16, 3		; Make it "Octal"
	bld	r16, 4
	andi	r16, 0x16
	sts	pprint+0, r16
	call	print
		;----+----1----+----2----+----3
	.db	"DATO    (", 0x81, ") ", 0, 0
	rcall	logaddr2name
	call	print
	.db	"  Value    ", 0xa2, CR, LF, 0, 0
	ret

logprintdati:
	lds	r16, pprint+0
;	sbrc	r16, 0		; log_rom
;	rjmp	logprintromi
	bst	r16, 3		; Make it "Octal"
	bld	r16, 4
	andi	r16, 0x16
	sts	pprint+0, r16
	call	print
		;----+----1----+----2----+----3
	.db	"DATI    (", 0x81, ") ", 0, 0
	rcall	logaddr2name
	call	print
	.db	"  Value    ", 0xa2, CR, LF, 0, 0
	ret

logprintromo:
	call	print
	.db	"DATO ROM(", 0x81, ") Value   ", 0xa2, CR, LF, 0
	ret
logprintromi:
	call	print
	.db	"DATI ROM(", 0x81, ") Value   ", 0xa2, CR, LF, 0
	ret

logprintaddress:
	call	print
		;----+----1----+----2----+----3
	.db	TAB, "     DMA  Address  ", 0xb1, CR, LF, 0
	ret

logprintseek:
	ldd	r16, Y+0
	andi	r16, CSR_DS_gm
	ori	r16, '0'
	sts	pprint+4, r16
	call	print
		;----+----1----+----2----+----3
	.db	"SEEK:", 0x94, "  (", 0x81, ") DAR        ", 0xa2, CR, LF, 0, 0
	ret
logprintpbn:
	bst	r16, 3
	andi	r16, 0x07
	brts	logprintlbn	
	sts	pprint+0, r16
	call	print
	.db	TAB, "     PBN  0x", 0x80, 0x81, 0x82, 0x83, CR, LF, 0
	ret
logprintlbn:
	call	print
	.db	TAB, "     LBN  0x", 0x80, 0x81, 0x82, 0x83, CR, LF, 0
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
	andi	zl, 0x0F
	lsl	zl
	lsl	zl
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
logprintcommand:
	ldd	zl, Y+0		; Unit & Command
	andi	zl, 0x03	; Isolate Unit
	ori	zl, '0'		; ->ASCII
	sts	pprint+0, zl	;
	ldd	zl, Y+0
	lsr	zl		; 
	lsr	zl		;
	andi	zl, 0x07	; Command Bits 
	clr	zh
	subi	zl, low(-logprintcommandtbl)
	sbci	zh, high(-logprintcommandtbl)
	ijmp

logprintcommandtbl:
	
	rjmp	logprintcmdmaint
	rjmp	logprintcmdwrtchk
	rjmp	logprintcmdgetstatus
	rjmp	logprintcmdseek
	rjmp	logprintcmdreadhdr
	rjmp	logprintcmdwrite
	rjmp	logprintcmdread
	rjmp	logprintcmdreadnc
	
logprintcmdmaint:
logprintcmdwrtchk:
logprintcmdgetstatus:
logprintcmdreadhdr:
logprintcmdwrite:
logprintcmdread:
logprintcmdreadnc:
	ldd	zl, Y+0
	andi	zl, 0x1c	; Isolate Command
	lsl	zl
	clr	zh
	subi	zl, low(-CommandName)
	sbci	zh, high(-CommandName)
logprintcommand010:
	ld	r24, Z+
	tst	r24
	breq	logprintcommand020
	call	serout
	rjmp	logprintcommand010
logprintcommand020:
	call	print
	.db	" (", 0x81, ") V:", 0x90, "  Value    ", 0xa2,   CR, LF, 0, 0
	ret

;
;	DAR during seek
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	|DF8|DF7|DF6|DF5|DF4|DF3|DF2|DF1||DF0| 0 | 0 |HS | 0 |DIR| 0 | 1 |
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
logprintcmdseek:
	ldd	r24, Y+2
	ldi	r25, '0'
	sbrc	r24, DAR_SEEK_HS
	inc	r25
	sts	pprint+4, r25

	ldi	r25, '+'
	sbrs	r24, DAR_SEEK_DIR
	ldi	r25, '-'
	sts	pprint+5, r25
	ldd	r25, Y+3
	rcall	logprintcyl
	call	print
	.db	"Seek    (", 0x81, ") V:", 0x90, "  Cyl:", 0x95, 0x9a, 0x9b, 0x9c, ", Head:", 0x94,   CR, LF, 0
	ret
;
;	Input	r25:r24		DAR
;	Output	pprint+10	9-bit cylinder value converted to decimal ASCII with leading spaces	
;
logprintcyl:
	push	r16

	add	r24, r24
	adc	r25, r25
	clr	r24
	adc	r24, r24	; DF is now saved as 16-bit value with low-byte in R25

	clt
	ldi	r16, '0'
logprintcyl010:
	subi	r25, low(100)
	sbci	r24, high(100)
	brcs	logprintcyl020
	set
	inc	r16
	rjmp	logprintcyl010
logprintcyl020:
	brts	logprintcyl030
	ldi	r16, ' '
logprintcyl030:
	subi	r25, low(-100)
	sbci	r24, high(-100)
	sts	pprint+10, r16
	ldi	r16, '0'
logprintcyl040:
	subi	r25, low(10)
	sbci	r24, high(10)
	brcs	logprintcyl050
	set
	inc	r16
	rjmp	logprintcyl040
logprintcyl050:
	brts	logprintcyl060
	ldi	r16, ' '
logprintcyl060:
	subi	r25, low(-10)
	sbci	r24, high(-10)
	sts	pprint+11, r16
	ori	r25, '0'
	sts	pprint+12, r25
	pop	r16
	ret

;--------------------------------------------------------------------------
;
;
;
logreg:
	lds	r18, tpflags
	sbrc	r18, tp__no
	rjmp	logregno
	sbi	FLAGS_LOG, log__reg
	clc
	ret
logregno:
	cbi	FLAGS_LOG, log__reg
	clc
	ret

logiack:
	lds	r18, tpflags
	sbrc	r18, tp__no
	rjmp	logiackno
	sbi	FLAGS_LOG, log__iack
	clc
	ret
logiackno:
	cbi	FLAGS_LOG, log__iack
	clc
	ret

logunits:
	lds	r18, tpflags
	sbrc	r18, tp__no
	rjmp	logunitsno
	lds	r18, unittable+ucb_size*0+ucb_log
	sbr	r18, (1<<ucb__log)	
	sts	unittable+ucb_size*0+ucb_log, r18
	lds	r18, unittable+ucb_size*1+ucb_log
	sbr	r18, (1<<ucb__log)	
	sts	unittable+ucb_size*1+ucb_log, r18
	lds	r18, unittable+ucb_size*2+ucb_log
	sbr	r18, (1<<ucb__log)	
	sts	unittable+ucb_size*2+ucb_log, r18
	lds	r18, unittable+ucb_size*3+ucb_log
	sbr	r18, (1<<ucb__log)	
	sts	unittable+ucb_size*3+ucb_log, r18
	clc
	ret
logunitsno:
	lds	r18, unittable+ucb_size*0+ucb_log
	cbr	r18, (1<<ucb__log)	
	sts	unittable+ucb_size*0+ucb_log, r18
	lds	r18, unittable+ucb_size*1+ucb_log
	cbr	r18, (1<<ucb__log)	
	sts	unittable+ucb_size*1+ucb_log, r18
	lds	r18, unittable+ucb_size*2+ucb_log
	cbr	r18, (1<<ucb__log)	
	sts	unittable+ucb_size*2+ucb_log, r18
	lds	r18, unittable+ucb_size*3+ucb_log
	cbr	r18, (1<<ucb__log)	
	sts	unittable+ucb_size*3+ucb_log, r18
	clc
	ret
;
;	Move Logging Flag of units to UCB
;
logunit:
	push	r17
	push	yl
	push	yh
	lds	yl, attunit
	swap	yl
	clr	yh
	subi	yl, low(-unittable)	; 
	sbci	yh, high(-unittable)	; 
	lds	r17, tpflags
	sbrc	r17, tp__no
	rjmp	logunitno
	ldd	r17, Y+ucb_log
	sbr	r17, (1<<ucb__log)
	std	Y+ucb_log, r17
	pop	yh
	pop	yl
	pop	r17
	clc
	ret
logunitno:
	ldd	r17, Y+ucb_log
	cbr	r17, (1<<ucb__log)
	std	Y+ucb_log, r17
	pop	yh
	pop	yl
	pop	r17
	clc
	ret

logtrace:
	lds	r18, tpflags
	sbrc	r18, tp__no
	rjmp	logtraceno
	sbi	FLAGS_LOG, log__trace
	clc
	ret
logtraceno:
	cbi	FLAGS_LOG, log__trace
	clc
	ret


logblocknbrs:
	lds	r18, tpflags
	sbrc	r18, tp__no
	rjmp	logpbnno
	sbi	FLAGS_LOG, log__pbn
	clc
	ret
logpbnno:
	cbi	FLAGS_LOG, log__pbn
	clc
	ret

logstatus:
	lds	r18, tpflags
	sbrc	r18, tp__no
	rjmp	logallno
	in	r18, FLAGS_LOG
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
	.db	"Logging PBN ....................:", NULL
	bst	r18, log__pbn
	rcall	logstatusonoff
;
	call	print
	.db	"Logging Trace ..................:", NULL
	bst	r18, log__trace
	rcall	logstatusonoff
;
	call	print
	.db	"Logging unit 0 .................:", NULL
	lds	r18, unittable+ucb_size*0+ucb_log
	bst	r18, ucb__log
	rcall	logstatusonoff
;
	call	print
	.db	"Logging unit 1 .................:", NULL
	lds	r18, unittable+ucb_size*1+ucb_log
	bst	r18, ucb__log
	rcall	logstatusonoff
;
	call	print
	.db	"Logging unit 2 .................:", NULL
	lds	r18, unittable+ucb_size*2+ucb_log
	bst	r18, ucb__log
	rcall	logstatusonoff
;
	call	print
	.db	"Logging unit 3 .................:", NULL
	lds	r18, unittable+ucb_size*3+ucb_log
	bst	r18, ucb__log
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
	out	FLAGS_LOG, zero
	clc
	ret


/*

Random output to show what is wrong with logging

]show logg
Logging   768 start entries starting at 0x7000
0x7000 INIT    (E3) Input 0x30, INTFLAGS 0x00
0x7400 0x7404 0x7408 0x740C 0x7410 0x7414 0x7418             PBN  0x02B28399
0x741C WrtChk  (56) V:2  Value    001315
0x7420  Diskaddr     141313, Diskstatus 0x2A
0x7424 SEEK:0  (58) DAR        012404
0x7428 0x742C 0x7430 0x7434 SEEK:3  (66) DAR        124540
0x7438 0x743C 0x7440    Diskaddr     024570, Diskstatus 0x3F
0x7444 0x7448 0x744C 0x7450 0x7454 DATI    (AA) IP (WR)  Value    034500
0x7458 0x745C 0x7460    Diskaddr     012533, Diskstatus 0x69
0x7464 0x7468 0x746C 0x7470 DATI    (7B) IP (S3)  Value    121273
0x7474 GetStat (FE) V:1  Value    073757
0x7478 SEEK:1  (84) DAR        154352
0x747C DATO    (FF) SA       Value    151002
0x7480       LBN  0xCA7FBF11
0x7484 DATI    (4E) IP (S1)  Value    010560
0x7488       LBN  0xCDE03505
0x748C       LBN  0xCE5B63E1
0x7490 SEEK:1  (98) DAR        120577
0x7494 0x7498 GetStat (86) V:2  Value    160411
0x749C 0x74A0        DMA  Address  02467517
0x74A4 0x74A8        DMA  Address  11160750
0x74AC 0x74B0 Maint   (6C) V:1  Value    111576
0x74B4 0x74B8 0x74BC 0x74C0     Diskaddr     101471, Diskstatus 0xEB
0x74C4 0x74C8 Trace ID 0xDD, Bytes 0x28 0x76 Word 073050
0x74CC ReadNC  (F2) V:2  Value    174072
0x74D0 0x74D4 Trace ID 0x18, Bytes 0xC9 0xA3 Word 121711
0x74D8 GetStat (31) V:0  Value    032241
0x74DC 0x74E0 0x74E4 0x74E8 0x74EC 0x74F0            DMA  Address  02322236
0x74F4 0x74F8 0x74FC ReadHdr (67) V:2  Value    013225
0x7500       DMA  Address  10104454
0x7504 0x7508 0x750C    Diskaddr     072460, Diskstatus 0x30
0x7510 0x7514 0x7518         LBN  0xCA7FE952
0x751C       LBN  0xCA7524FE
0x7520 0x7524 0x7528         PBN  0x00981628
0x752C 0x7530 Trace ID 0x4F, Bytes 0xB2 0x21 Word 020662
0x7534 0x7538 0x753C ReadHdr (E2) V:0  Value    155217
0x7540 DATI    (1C) SA (S4)  Value    045123
0x7544 DATO    (D4) IP (GO)  Value    075621
0x7548 0x754C DATI    (0B) IP (GO)  Value    026361
0x7550 ReadHdr (E8) V:1  Value    124531
0x7554 0x7558   Diskaddr     053103, Diskstatus 0x28
0x755C       LBN  0xC9371454
0x7560 0x7564   Diskaddr     157154, Diskstatus 0xE8
0x7568 0x756C Maint   (F1) V:3  Value    163373
0x7570 0x7574 0x7578    Diskaddr     035246, Diskstatus 0xA6
0x757C 0x7580 Trace ID 0x7D, Bytes 0x65 0xE3 Word 161545
0x7584 GetStat (BC) V:1  Value    160115
0x7588 0x758C DATI    (E4) SA (WR)  Value    174470
0x7590 ReadHdr (42) V:1  Value    001350
0x7594 Write   (88) V:3  Value    110310
0x7598 Write   (8B) V:2  Value    140052
0x759C       DMA  Address  04557240
0x75A0 0x75A4        DMA  Address  04424037
0x75A8 DATO    (66) SA (GO)  Value    105054
0x75AC Trace ID 0xA8, Bytes 0xEE 0x5D Word 056756
0x75B0 0x75B4        DMA  Address  15042675
0x75B8  Diskaddr     114034, Diskstatus 0xE4
0x75BC 0x75C0 Trace ID 0x5B, Bytes 0xF6 0x38 Word 034366
0x75C4  Diskaddr     140055, Diskstatus 0x93
0x75C8  Diskaddr     122000, Diskstatus 0x62
0x75CC Read    (B2) V:2  Value    174736
0x75D0 0x75D4 0x75D8 Seek    (3C) V:1  Cyl:+169, Head:0
0x75DC DATO    (11) IP       Value    144134
0x75E0  Diskaddr     035400, Diskstatus 0xF6
0x75E4 0x75E8 ReadHdr (F0) V:0  Value    020255
0x75EC SEEK:3  (35) DAR        005577
0x75F0 SEEK:0  (E1) DAR        053622
0x75F4 0x75F8 0x75FC Maint   (05) V:3  Value    010123
0x7600 DATO    (16) SA (GO)  Value    171405
0x7604 DATO    (B9) IP (GO)  Value    166013
0x7608 Trace ID 0xC8, Bytes 0xA7 0x9C Word 116247
0x760C ReadHdr (40) V:1  Value    060343
0x7610 0x7614 0x7618    Diskaddr     000214, Diskstatus 0x09
0x761C       DMA  Address  06677222
0x7620 ReadHdr (89) V:0  Value    122313
0x7624  Diskaddr     016411, Diskstatus 0x11
0x7628 0x762C        LBN  0xCAA52FA4
0x7630 ReadHdr (89) V:1  Value    102217
0x7634 Trace ID 0xC4, Bytes 0x1A 0x64 Word 062032
0x7638       DMA  Address  05620771
0x763C DATI    (18) IP (S4)  Value    141050
0x7640 SEEK:1  (5A) DAR        064004
0x7644 0x7648 DATI    (84) SA (S3)  Value    001651
0x764C       DMA  Address  17126463
0x7650 0x7654 0x7658    Diskaddr     014344, Diskstatus 0x85
0x765C 0x7660 SEEK:1  (22) DAR        137473
0x7664 0x7668        LBN  0xC8AACED9
0x766C Seek    (32) V:0  Cyl:+466, Head:0
0x7670 DATI    (03) SA (S2)  Value    162230
0x7674 DATO    (9B) SA (ER)  Value    153531
0x7678 SEEK:2  (F2) DAR        144612
0x767C Seek    (4E) V:0  Cyl:-481, Head:0
0x7680 DATO    (75) SA (S2)  Value    177307
0x7684  Diskaddr     162424, Diskstatus 0x6E
0x7688       PBN  0x06F66235
0x768C 0x7690 0x7694 DATI    (F9) SA (S1)  Value    065551
0x7698 INIT    (8E) Input 0x29, INTFLAGS 0x42
0x769C Seek    (4A) V:2  Cyl:-351, Head:0
0x76A0  Diskaddr     133751, Diskstatus 0x09
0x76A4       LBN  0xCE0F45E2
0x76A8  Diskaddr     146615, Diskstatus 0x4C
0x76AC Maint   (FA) V:0  Value    165545
0x76B0 0x76B4 0x76B8    Diskaddr     166227, Diskstatus 0x58
0x76BC Trace ID 0x71, Bytes 0x6A 0xEC Word 166152
0x76C0 0x76C4 Trace ID 0x34, Bytes 0x8C 0xE5 Word 162614
0x76C8       DMA  Address  12546210
0x76CC Read    (E3) V:1  Value    172451
0x76D0 Trace ID 0xF5, Bytes 0x30 0xB8 Word 134060
0x76D4 Trace ID 0xD5, Bytes 0x31 0x6E Word 067061
0x76D8 DATI    (76) SA       Value    053362
0x76DC 0x76E0        DMA  Address  06644434
0x76E4 SEEK:0  (67) DAR        073216
0x76E8       DMA  Address  04354647
0x76EC       LBN  0xCA95280F
0x76F0 0x76F4 DATO    (70) SA (S3)  Value    163724
0x76F8 0x76FC        DMA  Address  16552343
0x7700 DATO    (DB) SA (GO)  Value    133656
0x7704 Seek    (89) V:1  Cyl:+340, Head:0
0x7708 0x770C 0x7710 DATO    (73) SA       Value    045243
0x7714 0x7718 0x771C Trace ID 0xBA, Bytes 0x95 0xAE Word 127225
0x7720 Trace ID 0x15, Bytes 0xE5 0xF4 Word 172345
0x7724 SEEK:3  (2E) DAR        066422
0x7728 0x772C        DMA  Address  06634341
0x7730 0x7734 Trace ID 0x87, Bytes 0x42 0x63 Word 061502
0x7738 DATI    (24) IP       Value    015231
0x773C 0x7740 Trace ID 0x95, Bytes 0x4D 0x27 Word 023515
0x7744       DMA  Address  07047705
0x7748 0x774C 0x7750 0x7754 0x7758 0x775C Trace ID 0x32, Bytes 0x24 0xDD Word 156444
0x7760 SEEK:1  (AC) DAR        007375
0x7764 Trace ID 0x70, Bytes 0x29 0x96 Word 113051
0x7768 0x776C 0x7770 0x7774 Write   (71) V:3  Value    033304
0x7778       DMA  Address  10054702
0x777C Seek    (FF) V:3  Cyl:-320, Head:1
0x7780       DMA  Address  00561514
0x7784       DMA  Address  17177712
0x7788 DATI    (AA) SA       Value    027520
0x778C DATI    (D8) SA (ER)  Value    146260
0x7790       LBN  0xCFA7C5FF
0x7794       DMA  Address  16624274
0x7798 SEEK:2  (9C) DAR        074206
0x779C       DMA  Address  16530201
0x77A0 0x77A4 0x77A8 SEEK:2  (3A) DAR        055507
0x77AC       PBN  0x05EA79BD
0x77B0 0x77B4 0x77B8 DATO    (C9) IP (S1)  Value    064405
0x77BC SEEK:0  (C3) DAR        177216
0x77C0 0x77C4 DATO    (B0) IP       Value    050635
0x77C8 0x77CC 0x77D0         LBN  0xC866F3B7
0x77D4  Diskaddr     024032, Diskstatus 0xF9
0x77D8 0x77DC 0x77E0    Diskaddr     112662, Diskstatus 0x53
0x77E4 SEEK:1  (F0) DAR        017127
0x77E8 0x77EC DATO    (60) SA (S1)  Value    162051
0x77F0 DATI    (6A) SA (S2)  Value    061543
0x77F4 0x77F8 Trace ID 0x02, Bytes 0x76 0xE9 Word 164566
0x77FC Read    (B2) V:2  Value    163245
0x7800 0x7804 Seek    (70) V:3  Cyl:-416, Head:1
0x7808 0x780C ReadNC  (28) V:1  Value    165557
0x7810       DMA  Address  06576045
0x7814 Trace ID 0x1A, Bytes 0xB8 0x4B Word 045670
0x7818 SEEK:0  (59) DAR        045301
0x781C 0x7820   Diskaddr     157072, Diskstatus 0x00
0x7824       DMA  Address  03032551
0x7828 0x782C Trace ID 0x6B, Bytes 0xB1 0xE8 Word 164261
0x7830  Diskaddr     144244, Diskstatus 0x3C
0x7834 0x7838 0x783C SEEK:2  (BB) DAR        072255
0x7840 0x7844 Seek    (A4) V:0  Cyl:+ 33, Head:0
0x7848 DATO    (EE) SA       Value    174436
0x784C  Diskaddr     023607, Diskstatus 0x2E
0x7850 Trace ID 0xD5, Bytes 0x41 0x7A Word 075101
0x7854 0x7858 SEEK:3  (82) DAR        150316
0x785C 0x7860 DATO    (16) SA (S3)  Value    110653
0x7864 SEEK:1  (E2) DAR        022520
0x7868 Write   (0F) V:1  Value    076452
0x786C GetStat (41) V:3  Value    171072
0x7870 DATO    (3A) IP (S3)  Value    161571
0x7874 Trace ID 0xD0, Bytes 0x22 0x72 Word 071042
0x7878       DMA  Address  02274277
0x787C Trace ID 0xBA, Bytes 0xB8 0xFD Word 176670
0x7880  Diskaddr     145155, Diskstatus 0x1D
0x7884 0x7888 0x788C 0x7890 SEEK:3  (1E) DAR        043166
0x7894 DATI    (07) SA       Value    101422
0x7898       LBN  0xCEA1B727
0x789C       DMA  Address  15657234
0x78A0 0x78A4   Diskaddr     032224, Diskstatus 0xDE
0x78A8 0x78AC 0x78B0 SEEK:2  (CA) DAR        075617
0x78B4  Diskaddr     127372, Diskstatus 0xEE
0x78B8 0x78BC 0x78C0 0x78C4 0x78C8 0x78CC 0x78D0 SEEK:1  (DA) DAR        137267
0x78D4 Trace ID 0x3F, Bytes 0x21 0xA5 Word 122441
0x78D8 0x78DC SEEK:0  (F8) DAR        144516
0x78E0 0x78E4   Diskaddr     015630, Diskstatus 0xE9
0x78E8 Read    (6E) V:2  Value    065764
0x78EC Trace ID 0x80, Bytes 0x39 0xE9 Word 164471
0x78F0 Trace ID 0x7E, Bytes 0x35 0xB7 Word 133465
0x78F4 SEEK:1  (EE) DAR        122577
0x78F8 0x78FC 0x7900 0x7904 DATI    (34) IP (ER)  Value    074741
0x7908 0x790C 0x7910 ReadHdr (EC) V:0  Value    024456
0x7914 0x7918 0x791C SEEK:3  (BB) DAR        166734
0x7920 0x7924        LBN  0xCACD24C9
0x7928 Trace ID 0xBA, Bytes 0x58 0x1A Word 015130
0x792C 0x7930 SEEK:2  (99) DAR        026115
0x7934       DMA  Address  16453313
0x7938 DATI    (89) IP (WR)  Value    062623
0x793C 0x7940 Write   (52) V:1  Value    136764
0x7944 DATO    (CB) SA (S2)  Value    115633
0x7948       DMA  Address  00775424
0x794C DATO    (A3) SA (S3)  Value    131451
0x7950 Read    (DF) V:2  Value    010723
0x7954 0x7958 0x795C ReadHdr (E9) V:3  Value    043571
0x7960       DMA  Address  02757775
0x7964 Trace ID 0x61, Bytes 0xA4 0x0B Word 005644
0x7968 DATI    (18) SA (ER)  Value    047330
0x796C 0x7970 0x7974 Trace ID 0xEA, Bytes 0x8E 0x7B Word 075616
0x7978 ReadNC  (66) V:1  Value    176450
0x797C SEEK:0  (16) DAR        033133
0x7980  Diskaddr     074727, Diskstatus 0x86
0x7984 ROM WR  (4C) Value   047214
0x7988       LBN  0xCBB23F5A
0x798C       DMA  Address  17775443
0x7990 0x7994 0x7998 0x799C 0x79A0 0x79A4       Diskaddr     136572, Diskstatus 0xA0
0x79A8 Trace ID 0x71, Bytes 0xD1 0x49 Word 044721
0x79AC SEEK:0  (E7) DAR        014273
0x79B0 DATI    (EC) SA (GO)  Value    065530
0x79B4 0x79B8 0x79BC SEEK:2  (7A) DAR        042261
0x79C0 ReadHdr (69) V:3  Value    050563
0x79C4 0x79C8   Diskaddr     135475, Diskstatus 0xF4
0x79CC 0x79D0        DMA  Address  05232761
0x79D4 0x79D8 0x79DC 0x79E0     Diskaddr     172373, Diskstatus 0x35
0x79E4 0x79E8   Diskaddr     032563, Diskstatus 0x40
0x79EC 0x79F0 0x79F4 0x79F8          PBN  0x06805A58
0x79FC Seek    (00) V:1  Cyl:+466, Head:1
0x7A00 Trace ID 0xB7, Bytes 0x09 0x66 Word 063011
0x7A04 SEEK:3  (BE) DAR        047040
0x7A08 WrtChk  (84) V:1  Value    130040
0x7A0C       DMA  Address  16627020
0x7A10       LBN  0xCF122955
0x7A14 Trace ID 0x1A, Bytes 0x9C 0x9E Word 117234
0x7A18 DATO    (08) SA (S2)  Value    123746
0x7A1C 0x7A20 0x7A24    Diskaddr     043176, Diskstatus 0xD2
0x7A28 DATI    (0D) IP (ER)  Value    051626
0x7A2C 0x7A30 0x7A34 Seek    (73) V:3  Cyl:-116, Head:1
0x7A38 0x7A3C 0x7A40 GetStat (34) V:3  Value    013107
0x7A44 0x7A48 ReadHdr (F8) V:3  Value    104163
0x7A4C Read    (E0) V:2  Value    064444
0x7A50 0x7A54 0x7A58 0x7A5C 0x7A60 0x7A64       Diskaddr     044066, Diskstatus 0xEC
0x7A68 DATI    (42) SA (S3)  Value    124547
0x7A6C 0x7A70 0x7A74 0x7A78 0x7A7C      Diskaddr     160334, Diskstatus 0xA4
0x7A80  Diskaddr     053236, Diskstatus 0xB6
0x7A84 0x7A88 Write   (1E) V:1  Value    044765
0x7A8C 0x7A90   Diskaddr     124215, Diskstatus 0x5D
0x7A94 0x7A98 0x7A9C 0x7AA0 0x7AA4 Trace ID 0x0D, Bytes 0xB8 0x48 Word 044270
0x7AA8 0x7AAC Trace ID 0xBB, Bytes 0xFB 0xF3 Word 171773
0x7AB0 0x7AB4 0x7AB8         DMA  Address  12346704
0x7ABC DATI    (69) SA (S2)  Value    075263
0x7AC0 Seek    (7B) V:3  Cyl:+270, Head:1
0x7AC4  Diskaddr     031511, Diskstatus 0x25
0x7AC8 0x7ACC Trace ID 0xD9, Bytes 0x39 0xEC Word 166071
0x7AD0 0x7AD4 0x7AD8         DMA  Address  15523216
0x7ADC       PBN  0x03044474
0x7AE0  Diskaddr     110602, Diskstatus 0x99
0x7AE4 DATO    (B4) SA (S2)  Value    022516
0x7AE8  Diskaddr     111042, Diskstatus 0xED
0x7AEC SEEK:1  (A3) DAR        121401
0x7AF0 Trace ID 0xAF, Bytes 0xD9 0xE9 Word 164731
0x7AF4       DMA  Address  16536002
0x7AF8       PBN  0x060D0014
0x7AFC 0x7B00        DMA  Address  01073562
0x7B04 0x7B08        PBN  0x01A0E3C3
0x7B0C       DMA  Address  17611670
0x7B10  Diskaddr     140562, Diskstatus 0xDE
0x7B14 0x7B18 ReadHdr (19) V:1  Value    021043
0x7B1C DATI    (6E) IP (S4)  Value    106376
0x7B20       LBN  0xCC1B2665
0x7B24 0x7B28 DATO    (60) IP (S2)  Value    056020
0x7B2C       DMA  Address  07353553
0x7B30 ReadHdr (3B) V:2  Value    126272
0x7B34 Trace ID 0x69, Bytes 0x23 0x5D Word 056443
0x7B38       LBN  0xCBCD3E50
0x7B3C Trace ID 0x43, Bytes 0xA5 0xAE Word 127245
0x7B40  Diskaddr     007051, Diskstatus 0x93
0x7B44 0x7B48 0x7B4C 0x7B50          DMA  Address  00451305
0x7B54 Write   (D5) V:0  Value    057277
0x7B58 0x7B5C   Diskaddr     141753, Diskstatus 0x38
0x7B60 0x7B64 Trace ID 0x39, Bytes 0x8E 0xCB Word 145616
0x7B68 0x7B6C        LBN  0xCAAF2CD8
0x7B70 DATI    (52) SA (WR)  Value    037013
0x7B74 GetStat (7D) V:0  Value    002462
0x7B78 0x7B7C 0x7B80 0x7B84 0x7B88 0x7B8C 0x7B90        Diskaddr     053037, Diskstatus 0xE1
0x7B94 DATI    (47) SA (S4)  Value    020514
0x7B98 0x7B9C 0x7BA0 0x7BA4 SEEK:2  (59) DAR        171365
0x7BA8 Trace ID 0x83, Bytes 0xD2 0x68 Word 064322
0x7BAC 0x7BB0        PBN  0x027CD723
0x7BB4       DMA  Address  00406424
0x7BB8 0x7BBC 0x7BC0 0x7BC4 DATI    (5D) IP (S2)  Value    102122
0x7BC8 ReadNC  (47) V:2  Value    130345
0x7BCC 0x7BD0 0x7BD4    Diskaddr     104027, Diskstatus 0x1B
0x7BD8 0x7BDC 0x7BE0 0x7BE4 DATI    (4C) IP (GO)  Value    002026
0x7BE8 0x7BEC 0x7BF0 0x7BF4 Trace ID 0x8C, Bytes 0x51 0x4D Word 046521
0x7BF8 0x7BFC DATI    (80) SA (ER)  Value    132451
*/
