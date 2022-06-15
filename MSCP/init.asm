;--------------------------------------------------------------------------
;
;	Initialise MSCP Controller
;
;
;	S1 is supposed to appear 100usec after hard init
;	S2 is supposed to appear 10sec after host has written S1 response
;	S3 is supposed to appear 10sec after host has written S2 response
;	S4 is supposed to appear 10sec after host has written S3 response
;
;	In other words we have a lot of time between each step to initialize
;	the whole controller.

initmscp:
	cli
	lds	r18, _ccb_state
	cbr	r18, (1<<cs__act)
	sbr	r18, (1<<cs__ini)
	sts	_ccb_state, r18
	sei
init100:
	lds	r18, sawflag		; Did the host write SA
	tst	r18
	brne	init110			; Yes
;
;	Signal Step 1
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	|ERR| 0 | 0 | 0 | 1 |NV |QB |DI ||           reserved            |
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
	ldi	r16, low(step1)		; Set STEP1 indicator
	ldi	r17, high(step1)
	cli				;;;
	sts	sar+0, r16		;;; to SA read
	sts	sar+1, r17		;;; 
	sei				;;;
	rjmp	init100			; loop

init110:
	cli				;;; Decrement saw flag
	lds	r18, sawflag		;;;
	dec	r18			;;;
	sts	sawflag, r18		;;;
	lds	r20, saw+0		;;; Get SA value written by host
	lds	r21, saw+1		;;;
	sei				;;;
;
;	Step 1 response
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	| 1 |WR |cmdringleng|resringleng||IE |   (int vector address)/4  |
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
	sts	s1+0, r20
	sts	s1+1, r21
	tst	r21
	brpl	init100			; Invalid Value must have MSB set
	sbrs	r21, s1wr_bp		; is wrap_around specified?
	rjmp	init130			; no
init120:
	cli				;;;
	sts	sar+0, r20		;;; echo what was written into the SA
	sts	sar+1, r21		;;;
	sei				;;;
init125:
	lds	r18, sawflag		; Wait for the host to write something
	tst	r18			;
	breq	init125			;
	cli				;;; Decrement saw flag (this is most likely
	lds	r18, sawflag		;;; missing in original RQDX3 code)
	dec	r18			;;; and fetch value
	sts	sawflag, r18		;;;
	lds	r20, saw+0		;;;
	lds	r21, saw+1		;;;
	sei				;;;
	rjmp	init120			; loop forever
;
;	Process S1 responses
;
init130:
	mov	r16, r20		; Get low-byte of S1 response
	andi	r16, s1iv_gm		; Mask Vector/4 
	clr	r17			; Convert to 16-bit Vector value
	lsl	r16			; 
	rol	r17
	lsl	r16
	rol	r17
	sts	vector+0, r16		; Save it
	sts	vector+1, r17

	mov	r17, r21		; Get ring lengths
	lsr	r17
	lsr	r17
	lsr	r17
	andi	r17, 7			; isolate command ring length
	ldi	r16, 1			; Prepare to make it a power of 2
	rjmp	init150
init140:
	lsl	r16			; r16 = r16*2
init150:
	dec	r17			; already reached the end
	brpl	init140			; possible values are 1,2,4,8,16,32,64,128
	clr	r17			; Make it a 16-bit word value
	sts	cmd+ring_size+0, r16	; save it
	sts	cmd+ring_size+1, r17	; save it

	subi	r16, low(1)		; convert size to overflow mask
	sbci	r17, high(1)		; possible values are 0,1,3,7,15,31,63,127
	lsl	r16			; 
	rol	r17			;
	lsl	r16			;
	rol	r17			;
	com	r16			; 
	com	r17			; 
	sts	cmd+ring_mask+0, r16
	sts	cmd+ring_mask+1, r17
	
	mov	r17, r21		; isolate response ring length 
	andi	r17, 7
	ldi	r16, 1
	rjmp	init170
init160:
	lsl	r16
init170:
	dec	r17
	brpl	init160
	clr	r17
	sts	rsp+ring_size+0, r16	
	sts	rsp+ring_size+1, r16	
	
	subi	r16, low(1)
	sbci	r17, high(1)
	lsl	r16
	rol	r17
	lsl	r16
	rol	r17
	com	r17
	com	r16
	sts	rsp+ring_mask+0, r16
	sts	rsp+ring_mask+1, r17
;
;	>>>>>>>>>>>>>>>>>>>>>>>>>> Initialisation
;
;	After we receive the step 1 response and processed the content we
;	now need to initialise the MSCP controller. The basic initialisation
;	of the MCU inkluding all IO has already done by the startup section
;	here we need to setup all packet queues, initialise the controller
;	status und mount the SD-Card. Up to here there are no dynamic data
;	structures
;
;
	ldi	r16, max_packets
	mov	r15, r16
init180:
	ldi	r24, low(pkt_length)
	ldi	r25, high(pkt_length)
	call	malloc
	sbiw	r25:r24, 0
	brne	init181
	ldi	r24, low(pe_nsr)	; no such resource
	ldi	r25, high(pe_nsr)	; no such resource
	jmp	fatal_error
init181:
	ldi	r22, low(pkts)
	ldi	r23, high(pkts)
	call	enqhead
	dec	r15
	brne	init180
;					<<<<<<<<<<<<<<<<<<<<<<<<<
;	Signal Step 2
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	|ERR| 0 | 0 | 1 | 0 | port type || 1 |WR |cmdringleng|resringleng|
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
	ldi	r17, high(step2)
	cli				;;;
	sts	sar+0, r21		;;; Step2: Low Byte = high byte from Step1
	sts	sar+1, r17		;;; Step2: Transition S1->S2
	sei				;;;
	rcall	pokehost		; Possibly create an interrrupt
;
;	Step 2 response
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	| ring based address low                                     |PI |
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
	cli				;;;
	lds	r20, saw+0		;;;
	lds	r21, saw+1		;;;
	sei				;;;
	sts	s2+0, r20		; Ring Base Low
	sts	s2+1, r21
;
;	Signal Step 3
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	|ERR| 0 | 1 | 0 | 0 | reserved  ||IE |   (int vector address)/4  |
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
	lds	r16, s1+0
	ldi	r17, high(step3)
	cli				;;;
	sts	sar+0, r16		;;;
	sts	sar+1, r17		;;;
	sei				;;;
	rcall	pokehost
;
;	Step 3 response
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	|PP | ring based address high                                    |
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
	cli				;;;
	lds	r20, saw+0		;;;
	lds	r21, saw+1		;;;
	sei				;;;
	sts	s3+0, r20		; Ring Base High
	sts	s3+0, r21

	sbrs	r20, s3pp_bp		; purge/poll test requested
	rjmp	init210			; no
	sts	iprflag, zero
	cli				;;;
	sts	sar+0, zero		;;;
	sts	sar+1, zero		;;;
	sei				;;;
init190:
	lds	r18, sawflag
	tst	r18
	breq	init190
	cli				;;;
	lds	r18, sawflag		;;;
	dec	r18			;;;
	sts	sawflag, r18		;;;
	lds	r24, saw+0		;;;
	lds	r25, saw+1		;;;
	sei				;;;

	sbiw	r25:r24, 0
	breq	init200
	ldi	r24, pe_ppf
	call	fatal_error

init200:

	ldi	zl, low(mscpipr)
	ldi	zh, high(mscpipr)
	call	block			; INIT is part of POLL Job

	lds	r18, iprflag		; wait for the IP read to happen
	tst	r18
	breq	init200
	cbi	b_GO
	nop
	nop
	nop
	sbi	f_GO    		; 
;
;	Now calculate various memory addresses. Note that in RQDX3 source code
;	long (32-bit) values are stored high 16-bit value at offset zero and 
;	low 16-bit value at offset two. We keep the byte order in memory
;	for 32-bit values
;
init210:	
	lds	r16, s2+0
	lds	r17, s2+1
	lds	r18, s3+0
	lds	r19, s3+1
	andi	r16, 0xFE
	andi	r19, 0x7F
	movw	r21:r20, r17:r16
	movw	r23:r22, r19:r18	; save it for later
	
	sts	rsp+ring_base+0, r16	; ring base address is also the response
	sts	rsp+ring_base+1, r17	; ring start address
	sts	rsp+ring_base+2, r18
	sts	rsp+ring_base+3, r19
	
	lds	r20, rsp+ring_size+0	; number of double-words in ring buffer
	lds	r20, rsp+ring_size+1	;
	lsl	r20
	rol	r21
	lsl	r20
	rol	r21			; make it a byte offset
	add	r16, r20		; add to response ring address to get
	adc	r17, r21		; the command ring start address
	adc	r18, zero
	adc	r19, zero
	
	sts	cmd+ring_base+0, r16	; set command ring start address
	sts	cmd+ring_base+1, r17
	sts	cmd+ring_base+2, r18
	sts	cmd+ring_base+3, r19

	ldi	r24, 1			; # of double words to ZAP w/o purge interrupts
;
;	Note: from here on r23:r22:r21:r20 hold the start address of the host
;	memory that we need to zap.
;
	subi	r20, byte1(2)
	subi	r21, byte2(2)
	subi	r22, byte3(2)
	subi	r23, byte4(2)

	sts	rsp+ring_flag+0, r20
	sts	rsp+ring_flag+1, r21
	sts	rsp+ring_flag+2, r22
	sts	rsp+ring_flag+3, r23

	subi	r20, byte1(2)
	subi	r21, byte2(2)
	subi	r22, byte3(2)
	subi	r23, byte4(2)

	sts	cmd+ring_flag+0, r20
	sts	cmd+ring_flag+1, r21
	sts	cmd+ring_flag+2, r22
	sts	cmd+ring_flag+3, r23

	sts	purgeflag+0, zero	; Assume no purge interrupts
	sts	purgeflag+1, zero
	sts	purgeflag+2, zero
	sts	purgeflag+3, zero

	lds	r16, s2+0
	sbrs	r16, s2pi_bp
	rjmp	init230

	ldi	r24, 2			; # of double words to ZAP with purge interrupts

	subi	r20, byte1(2)		; Purge interupts are requested
	subi	r21, byte2(2)
	subi	r22, byte3(2)
	subi	r23, byte4(2)

	sts	purgeflag+0, r20	; Address of purge interrupt flags
	sts	purgeflag+1, r21
	sts	purgeflag+2, r22
	sts	purgeflag+3, r23

	subi	r20, byte1(2)		; Address of reserved word with purge interrupts
	subi	r21, byte2(2)		; which preceeds the purge interrupt flag in
	subi	r22, byte3(2)		; host memory
	subi	r23, byte4(2)

;
;	Now calculate the total number of double words that need to be zapped
;	in host memory, we already have the number of double words in r24
;	which is one or two in case we have purge interrupts, now wee need
;	to add the size of the response and command ring that can be found
;	at offset ring_size
;
init230:
	clr	r25			; Make 16 bit value
	lds	r16, rsp+ring_size+0
	lds	r17, rsp+ring_size+0
	add	r24, r16
	add	r25, r17
	lds	r16, cmd+ring_size+0
	lds	r17, cmd+ring_size+0
	add	r24, r16
	add	r25, r17
	add	r24, r24
	adc	r25, r25		; Make it a word count
	
	dmaaddr r20, r21, r22	; Setup DMA address
	
init235:
	dmawrt zero, zero		; zap memory
	sbiw	r25:r24, 1
	brne	init235	

	sts	cmd+ring_index+0, zero
	sts	cmd+ring_index+1, zero
	sts	rsp+ring_index+0, zero
	sts	rsp+ring_index+1, zero
	
;
;	Signal step 4
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	|ERR| 1 | 0 | 0 | 0 | reserved  ||  controller firmware version  |
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
	ldi	r16, low(step4)
	ldi	r17, high(step4)
	cli				;;;
	sts	sar+0, r16		;;;
	sts	sar+1, r17		;;;
	sei				;;;
	rcall	pokehost
init240:
;
;	Step 4 response
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	|           reserved            ||   dma burst size      |LF |GO |
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
	lds	r20, saw+0
	lds	r21, saw+1
	sbrs	r20, s4go_bp
	rjmp	init240
	sbrs	r20, s4lf_bp
	rjmp	init250
	lds	r24, porterror
	tst	r24
	breq	init250
	call	do_plf
	sts	porterror, zero
init250:
	lds	r18, _ccb_state
	sbr	r18, (1<<cs__act)
	cbr	r18, (1<<cs__ini)
	sts	_ccb_state, r18
	ret
;--------------------------------------------------------------------------
;
;
;
pokehost:
	lds	r16, s1+0		;
	sbrs	r16, s1ie_bp		; does the host request interrupts during init?
	rjmp	poke100			; no
	lds	r24, vector+0
	lds	r25, vector+1		; get vector
	sbiw	r25:r24, 0		; 
	breq	poke100			; no vector given
	sbi	b_IRQ			; request interrupt
;
;
;
poke100:
	lds	r18, sawflag		; Get sawflag
	tst	r18
	breq	poke100			; loop
	cli				;;; The PDP-11 can decrement a memory location
	lds	r18, sawflag		;;; in one instruction so there is no conflict
	dec	r18			;;; with the interrupt that increments the
	sts	sawflag, r18		;;; flag, but on a AVR we need to block interrupts
	sei				;;; to decrement or increment a flag
	ret
