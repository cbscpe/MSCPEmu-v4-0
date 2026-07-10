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
;	5	0000	Poll Job Encoded DMA Address 	
;	5	other	unused
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
;	The buffer is split in one part reserved for initial logging
;	and the second part is used for circular buffer
;
logprint:
	ldi	r24, low(log_begin/4)	; Number of initial/permanent entries
	ldi	r25, high(log_begin/4)
	sbiw	r25:r24, 0		; No permanent entries configured
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
;=============================================================================
;
;	Print logging entries to make efficient use of a jump table we
;	place the dispatcher in the middle of the effective printing 
;	routines, therefore we have first a set of printing routines
;	then we have the logprintentry dispatcher and then another
;	set of printing routines
;	
;--------------------------------------------------------------------------
;
;	0x50	Poll DMA Address
;
logprintdma:
	cpi	r16, 0x50		; for the moment just a hack
	breq	logprintdma010
	ret				; nothing to print
;
;	the log entry is a 32-bit value with the following fields
;	- bit0		DMA Direction 1=read, 0=write
;	- bit1..21	DMA Address
;	- bit22..23	ID
;
;	First we collect the direction and ID to form an index
;
logprintdma010:
	clr	zl			; prepare index to text
	clr	zh
	bst	r17, 0			; Save direction bit
	bld	zl, 5			; Copy to index
	andi	r17, 0xfe		; Remove direction bit from address
	sts	pprint+1, r17		; write it back

	bst	r19, 6			; Save LSB of ID
	bld	zl, 6			; Copy to index

	bst	r19, 7			; Save MSB of ID
	bld	zl, 7			; Copy to index

	andi	r19, 0x3f		; Remove ID bit from address
	sts	pprint+3, r19		; write it back

	subi	zl, low(-dma_text)
	sbci	zh, high(-dma_text)
	
	ldi	r16, 32
logprintdma020:
	ld	r24, Z+
	call	serout
	dec	r16
	brne	logprintdma020
	call	print
	.db	0xb1, CR, LF, 0
	ret
	
logprintmscp:
#ifdef mscpemulation
;
;	r17	opcode
;	r19:r18	unit
;
	mov	xl, r17
	lsl	xl
	lsl	xl
	clr	xh
	subi	xl, low(-mscp_names)
	sbci	xh, high(-mscp_names)
	ld	r20, X+
	sts	pprint+4, r20
	ld	r20, X+
	sts	pprint+5, r20
	ld	r20, X+
	sts	pprint+6, r20
	call	print
	.db	"MSCP Command (", 0x94, 0x95, 0x96, ") Unit:", 0xa2, CR, LF, 0
#endif
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
	rjmp	logprintdma		; 5
	rjmp	logprintmscp		; 6
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
	mov	zl, r16
	andi	zl, 0x0F
	clr	zh
	subi	zl, low(-logprintinttbl)
	sbci	zh, high(-logprintinttbl)
	ijmp
	
logprintinttbl:
	rjmp	logprintiack
	rjmp	logprintinit
	rjmp	logprintsoftgo
	rjmp	logprintsoftip
	rjmp	logprintsoftsa
	rjmp	logprintsas1
	ret
	ret
	ret
	ret
	ret
	ret
	ret
	ret
	ret
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

logprintsoftgo:
	call	print
		;----+----1----+----2----+----3
	.db	"GO      (", 0x81, ") CSR     ", 0xa2, CR, LF, 0
	ret

logprintsoftip:
	call	print
		;----+----1----+----2----+----3
	.db	"IP      (", 0x81, ") MSCP    ", 0x82, ", Port B 0x", 0x83, CR, LF, 0
	ret

logprintsoftsa:
	call	print
		;----+----1----+----2----+----3
	.db	"SA      (", 0x81, ") MSCP    ", 0x82, ", Port B 0x", 0x83, CR, LF, 0
	ret

logprintsas1:
#ifdef mscpemulation
	ldi	r16, '0'
	sbrc	r18, s1ie_bp
	inc	r16
	sts	pprint+4, r16	; IE Flag
	ldi	r16, '0'
	sbrc	r19, s1wr_bp
	inc	r16
	sts	pprint+5, r16	; WR Flag
	mov	r16, r18
	andi	r16, s1iv_gm		; Mask Vector/4 
	clr	r17			; Convert to 16-bit Vector value
	lsl	r16			; 
	rol	r17
	lsl	r16
	rol	r17
	sts	pprint+6, r16		; Vector
	sts	pprint+7, r17
	mov	r16, r19
	andi	r16, 0x07
	ori	r16, '0'
	sts	pprint+8, r16		; Response Ring Size
	mov	r16, r19
	lsr	r16
	lsr	r16
	lsr	r16
	andi	r16, 0x07
	ori	r16, '0'
	sts	pprint+9, r16		; Command Ring Size
	call	print
		;----+----1----+----2----+----3
	.db	"State 1 (",0x81, "), 0x", 0x83, 0x82, " WR:", 0x95, " IE:", 0x94, " Vector:", 0xa6, " RSize:", 0x98, " CSize: ", 0x99, CR, LF, 0
#endif
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
	sts	pprint+4, r16
	brts	logprintlbn	
	call	print
	.db	"PBN: ", 0xD1, "./ 0x", 0x84, 0x83, 0x82, 0x81, CR, LF, 0
	ret
logprintlbn:
	call	print
	.db	"LBN: ", 0xD1, "./ 0x", 0x84, 0x83, 0x82, 0x81, CR, LF, 0
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
logsoftlog:
	lds	r18, tpflags
	sbrc	r18, tp__no
	rjmp	logsoftlogno
	sbi	FLAGS_LOG, log__softint
	clc
	ret
logsoftlogno:
	cbi	FLAGS_LOG, log__softint
	clc
	ret

logverblog:
	lds	r18, tpflags
	sbrc	r18, tp__no
	rjmp	logverblogno
	sbi	FLAGS_LOG, log__verbose
	clc
	ret
logverblogno:
	cbi	FLAGS_LOG, log__verbose
	clc
	ret

logdmalog:
	lds	r18, tpflags
	sbrc	r18, tp__no
	rjmp	logdmalogno
	sbi	FLAGS_LOG, log__dma
	clc
	ret
logdmalogno:
	cbi	FLAGS_LOG, log__dma
	clc
	ret

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
	sbi	FLAGS_LOG, log__blocknbr
	clc
	ret
logpbnno:
	cbi	FLAGS_LOG, log__blocknbr
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
	.db	"Logging LBN/PBN ................:", NULL
	bst	r18, log__blocknbr
	rcall	logstatusonoff
;
	call	print
	.db	"Logging Trace ..................:", NULL
	bst	r18, log__trace
	rcall	logstatusonoff
;
	call	print
	.db	"Logging Verbose ................:", NULL
	bst	r18, log__verbose
	rcall	logstatusonoff
;
	call	print
	.db	"Logging DMA Addresses  .........:", NULL
	bst	r18, log__dma
	rcall	logstatusonoff
;
	call	print
	.db	"Logging Software Interrupts ....:", NULL
	bst	r18, log__softint
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
