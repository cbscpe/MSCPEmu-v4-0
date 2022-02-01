


	dmaread	r16, r17		; Get word
	mov	zl, r17
	swap	zl
	lsr	zl
	andi	zl, 0x07
	clr	zh
	subi	zl, low(-2*disasmtbl1)
	sbic	zh, high(-2*disasmtbl1)
	ijmp
disasmtbl1:			
	rjmp	disvar0			;	b0xxxx
	rjmp	dismov			;	b1xxxx
	rjmp	discmp			;	b2xxxx
	rjmp	disbit			;	b3xxxx	
	rjmp	disbic			;	b4xxxx
	rjmp	disbis			;	b5xxxx
	rjmp	disaddsub		;	b6xxxx
	rjmp	disvar7			;	b7xxxx
	

dismov:
	call	print
	.db	"MOV", 0
	ldi	r24, 'B'
	sbrc	r17, 7
	call	serout
	rjmp	disdouble
discmp:
	call	print
	.db	"CMP", 0
	ldi	r24, 'B'
	sbrc	r17, 7
	call	serout
	rjmp	disdouble
disaddsub:
	sbrc	r17, 7
	rjmp	dissub
	call	print
	.db	"ADD", 0
	rjmp	disdouble
dissub:
	call	print
	.db	"SUB", 0
	rjmp	disdouble
disbit:
	call	print
	.db	"BIT", 0
	ldi	r24, 'B'
	sbrc	r17, 7
	call	serout
	rjmp	disdouble
disbic
	call	print
	.db	"BIC", 0
	ldi	r24, 'B'
	sbrc	r17, 7
	call	serout
	rjmp	disdouble
disbis
	call	print
	.db	"BIS", 0
	ldi	r24, 'B'
	sbrc	r17, 7
	call	serout
	rjmp	disdouble

;--------------------------------------------------------------------------
;
;
;	b0xxxx
;
disvar0:
	sbrc	r17, 3		; b000xx...b004xx
	rjmp	dissop		; 
	mov	zl, r17
	bst	zl, 7
	andi	0x07		; 0'000'0xx'x
	bld	zl, 3		; 0'000'bxx'x
	clr	zh
	subi	zl, low(-2*disasmtbl2)
	sbci	zh, high(-2*disasmtbl2)
	ijmp
disasmtbl2:
	rjmp	dislow		; 0000
	rjmp	disbr		; 0004
	rjmp	disbne		; 0010
	rjmp	disbeq		; 0014
	rjmp	disbge		; 0020
	rjmp	disblt		; 0024
	rjmp	disbgt		; 0030
	rjmp	disble		; 0034
	rjmp	disbpl		; 1000
	rjmp	disbmi		; 1004
	rjmp	disbhi		; 1010
	rjmp	disblos		; 1014
	rjmp	disbvc		; 1020
	rjmp	disbvs		; 1024
	rjmp	disbcc		; 1030
	rjmp	disbcs		; 1034
	
disbr:
	call	print
	.db	"BR", 0, 0
	rjmp	disbranch
disbne:
	call	print
	.db	"BNE", 0
	rjmp	disbranch
disbne:
	call	print
	.db	"BEQ", 0
	rjmp	disbranch
disbne:
	call	print
	.db	"BGE", 0
	rjmp	disbranch
disbne:
	call	print
	.db	"BLT", 0
	rjmp	disbranch
disbne:
	call	print
	.db	"BGT", 0
	rjmp	disbranch
disbne:
	call	print
	.db	"BLE", 0
	rjmp	disbranch
disbne:
	call	print
	.db	"BPL", 0
	rjmp	disbranch
disbne:
	call	print
	.db	"BMI", 0
	rjmp	disbranch
disbne:
	call	print
	.db	"BHI", 0
	rjmp	disbranch
disbne:
	call	print
	.db	"BLOS", 0, 0
	rjmp	disbranch
disbne:
	call	print
	.db	"BVC", 0
	rjmp	disbranch
disbne:
	call	print
	.db	"BVS", 0
	rjmp	disbranch
disbne:
	call	print
	.db	"BCC", 0
	rjmp	disbranch
disbne:
	call	print
	.db	"BCS", 0
	rjmp	disbranch

disbranch:
	movw	r19:18, xh:xl		; Assume xh:xl == PC
	mov	r20, r16		; Offfset
	clr	r21			; 
	sbrc	r16			; Test sign of offset
	com	r21			; sign extend to r21
	add	r18, r20
	add	r19, r21
	sts	pprint+0, r20
	sts	pprint+1, r21
	call	print
	.db	TAB, 0xA0, CR, LF, 0, 0
	ret
	
;--------------------------------------------------------------------------
;
;
;	000000	000377 
;
	
dislow:

;	000000	halt
;	000001	wait
;	000002	rti
;	000003	bpt
;	000004	iot
;	000005	reset
;	000006	rtt
;	000007	mfpt	move processor type

;	000010	000077	unused	

;	0001xx	JMP
;	000200	000207	RTS
;	000210	000227	unused
;	000230	000237	SPL
;	000240	000257	Cxx
;	000260	000277	Sxx
;	000300	000377	SWAB	


;	000400	003777	Branches	; Already done
;	100000	103777	Branches	; Already done

;--------------------------------------------------------------------------
;
;
;	b04000	b07777
;

dissop:
	mov	zl, r17
	lsr	zl
	andi	zl, 0x03
	bst	r17, 7
	bld	zl, 2
	clr	zh
	subi	zl, low(-2*disasmtbl4)
	sbci	zh, high(-2*disasmtbl4)
	ijmp

disasmtbl4:
	rjmp	disjsr			;	004xxx	JSR
	rjmp	distrp			;	104xxx	EMT/TRAP
	rjmp	dissingle5		;	005xxx
	rjmp	dissingle5		;	105xxx
	rjmp	dissingle6		;	006xxx
	rjmp	dissingle6		;	106xxx
	rjmp	disspecial		;	007xxx
	rjmp	disunused		;	107xxx

;
;	004rdd	JSR
;
disjsr:
	call	print
	.db	"JSR", 0
	call	disreg
	rjmp	disdest


;	104000	104377	EMT
;	104400	104777	TRAP
;
distrp:
	sbrc	r17, 0
	rjmp	distrap
	call	print
	.db	"EMT", 0
	rjmp	disbyte
distrap:
	call	print
	.db	"TRAP", 0, 0
	rjmp	disbyte
;
;	b05000	b05077	CLR(B)
;	b05100	b05177	COM(B)
;	b05200	b05277	INC(B)
;	b05300	b05377	DEC(B)
;	b05400	b05477	NEG(B)
;	b05500	b05577	ADC(B)
;	b05600	b05677	SBC(B)
;	b05700	b05777	TST(B)
;
dissingle5:
	sbrc	r17, 0		
	rjmp	dissingle504x
	sbrc	r16, 7
	rjmp	dissingle502x
	sbrc	r16, 6
	rjmp	dissingle5010
	call	print
	.db	"CLR", 0
	rjmp	dissingle5b
dissingle5010:
	call	print
	.db	"COM", 0
	rjmp	dissingle5b

dissingle502x:
	sbrc	r16, 6
	rjmp	dissingle5030
	call	print
	.db	"INC", 0
	rjmp	dissingle5b
	
dissingle5030:
	call	print
	.db	"DEC", 0
	rjmp	dissingle5b

dissingle504x:
	sbrc	r16, 7
	rjmp	dissingle506x
	sbrc	r16, 6
	rjmp	dissingle5050
	call	print
	.db	"NEG", 0
	rjmp	dissingle5b
dissingle5050:
	call	print
	.db	"ADC", 0
	rjmp	dissingle5b
dissingle506x:
	sbrc	r16, 6
	rjmp	dissingle5070
	call	print
	.db	"SBC", 0
	rjmp	dissingle5b
dissingle5070:
	call	print
	.db	"TST", 0
	rjmp	dissingle5b
dissingle5b:
	ldi	r24, SPACE
	sbrc	r17, 7
	call	serout
	rjmp	disdest

;
;	b06000	b06077	ROR(B)
;	b06100	b06177	ROL(B)
;	b06200	b06277	ASR(B)
;	b06300	b06377	ASL(B)
;	b06400	b06477	MARK	MTPS
;	b06500	b06577	MFPI	MFPD
;	b06600	b06677	MTPI	MTPD
;	b06700	b06777	SXT	MFPS
;
dissingle6:
	sbrc	r17, 0		
	rjmp	dissingle604x
	sbrc	r16, 7
	rjmp	dissingle602x
	sbrc	r16, 6
	rjmp	dissingle6010
	call	print
	.db	"ROR", 0
	rjmp	dissingle6b
dissingle6010:
	call	print
	.db	"ROL", 0
	rjmp	dissingle6b

dissingle602x:
	sbrc	r16, 6
	rjmp	dissingle6030
	call	print
	.db	"ASR", 0
	rjmp	dissingle6b
	
dissingle6030:
	call	print
	.db	"ASL", 0
	rjmp	dissingle6b

dissingle6b:
	ldi	r24, SPACE
	sbrc	r17, 7
	call	serout
	rjmp	disdest

dissingle604x:
	sbrc	r17, 7
	rjmp	dissingle604xb
	sbrc	r16, 7
	rjmp	dissingle606x
	sbrc	r16, 6
	rjmp	dissingle6050
	call	print
	.db	"MARK", 0, 0		; Mark Stack
	rjmp	disdest
dissingle6050:
	call	print
	.db	"MFPI", 0, 0		; Move From Previous Intstruction Space
	rjmp	disdest
dissingle606x:
	sbrc	r16, 6
	rjmp	dissingle6070
	call	print
	.db	"MTPI", 0, 0		; Move To Previosu Instruction Space
	rjmp	disdest
dissingle6070:
	call	print
	.db	"SXT", 0		; Sign Extend
	rjmp	disdest
	
	
dissingle604xb:
	sbrc	r16, 7
	rjmp	dissingle606xb
	sbrc	r16, 6
	rjmp	dissingle6050b
	call	print
	.db	"MTPS", 0, 0		; Move To Processor Status
	rjmp	disdest
dissingle6050b:
	call	print
	.db	"MFPD", 0, 0		; Move From Previous Data Space
	rjmp	disdest
dissingle606xb:
	sbrc	r16, 6
	rjmp	dissingle6070b
	call	print
	.db	"MTPD", 0, 0		; Move To Previous Data Space
	rjmp	disdest
dissingle6070b:
	call	print
	.db	"MFPS", 0		; Move From Processor Status
	rjmp	disdest

;
;	007000	007077	CSM
;	007100	007177	unused
;	007200	007277	WRTLCK
;	007300	007377	TSTSET
;	007400	007477	unused
;	007500	007577	unused
;	007600	007677	unused
;	007700	007777	unused
;
disspecial:
	sbrc	r17, 0
	rjmp	disunused
	sbrc	r16, 7
	rjmp	disspecial2x
	sbrc	r16, 6
	rjmp	disunused
	.db	"CSM", 0		; Call Supervisor Mode
	rjmp	disdest

disspecial2x:
	sbrc	r16, 6
	rjmp	disspecial3
	call	print
	.db	"WRTLCK", 0, 0		; Write Lock
	rjmp	disdest
disspecial3:
	call	print
	.db     "TSTSET", 0, 0		; Test and Set
	rjmp	disdest
;
;	107000	107777	unused
;
disunused:

;--------------------------------------------------------------------------
;
;
;	x7xxxx
;

disvar7:
	sbrc	r17, 7		;
	rjmp	disfloat	; 17xxxx are floating point numberes
	mov	zl, r17
	lsr	zl
	andi	zl, 0x07
	clr	zh
	subi	zl, low(-2*disasmtbl3)
	sbci	zh, high(-2*disasmtbl3)
	ijmp
disasmtbl3:
	rjmp	dismul		; 070rss
	rjmp	disdiv		; 071rss
	rjmp	disash		; 072rss
	rjmp	disashc		; 073rss
	rjmp	disxor		; 074rdd
	rjmp	disunk		; 075xxx
	rjmp	disunk		; 076xxx
	rjmp	dissob		; 077rDD

disfloat:
	call	print
	.db	"Float", 0
	ret





