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

initjob:
	cli
	lds	r18, _ccb_state
	cbr	r18, (1<<cs__act)
	sbr	r18, (1<<cs__ini)
	sts	_ccb_state, r18
	sei
	sts	sawcount+0, zero
	sts	sawcount+1, zero
init010:
	ldi	r24, low(mscpsaw)
	ldi	r25, high(mscpsaw)
	call	block

	lds	r24, sawcount+0
	lds	r25, sawcount+1
	adiw	r25:r24, 1
	sts	sawcount+0, r24
	sts	sawcount+1, r25
	
	lds	zl, mscpstatus
	andi	zl, 0x1F
	clr	zh
	subi	zl, low(-inittable)
	sbci	zh, high(-inittable)
	ijmp

inittable:
	rjmp	init_init	;
	rjmp	init_init
	rjmp	init_init
	rjmp	init_init
	rjmp	init_s1
	rjmp	init_s1
	rjmp	init_s1
	rjmp	init_s1
	rjmp	init_s2
	rjmp	init_s2
	rjmp	init_s2
	rjmp	init_s2
	rjmp	init_s3
	rjmp	init_s3
	rjmp	init_s3
	rjmp	init_s3
	rjmp	init_s4
	rjmp	init_s4
	rjmp	init_s4
	rjmp	init_s4
	rjmp	init_wrap
	rjmp	init_wrap
	rjmp	init_wrap
	rjmp	init_wrap
	rjmp	init_go
	rjmp	init_go
	rjmp	init_go
	rjmp	init_go
	rjmp	init_invalid
	rjmp	init_invalid
	rjmp	init_invalid
	rjmp	init_invalid
;
;	The following states are not handled by the INIT job
;
;

init_go:
init_init:
init_wrap:
init_invalid:
	rjmp	init010

;--------------------------------------------------------------------------
;
;	When the MSCP controller switches to INIT state the Host must write
;	the first configuration word. Note that switching from INIT to S1 is
;	done in the QBUS interrupt service routine.
;
init_s1:
	cli
	lds	r20, sa_s1+0		;;; Get SA value written by host
	lds	r21, sa_s1+1		;;;
	sei				;;;
;
;	Step 1 response
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	| 1 |WR |cmdringleng|resringleng||IE |   (int vector address)/4  |
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
	tst	r21
	brpl	init010			; Invalid Value must have MSB set, although
					; we expect that the QBUS ISR does not trigger
					; a software interrupt we still check
;
;	Process S1 responses
;
init110:
;
;	Calculate vector address
;
	mov	r16, r20		; Get low-byte of S1 response
	andi	r16, s1iv_gm		; Mask Vector/4 
	clr	r17			; Convert to 16-bit Vector value
	lsl	r16			; 
	rol	r17
	lsl	r16
	rol	r17
	sts	vector+0, r16		; Save it
	sts	vector+1, r17
;
;	Calculate command ring size and mask
;
	mov	r17, r21		; Get ring lengths
	lsl	r17			; 
	swap	r17
	andi	r17, 7			; isolate command ring length
	ldi	r16, 1			; Prepare to make it a power of 2
	rjmp	init130			;
init120:
	lsl	r16			; r16 = r16*2
init130:
	dec	r17			; already reached the end
	brpl	init120			; possible values are 1,2,4,8,16,32,64,128
	clr	r17			; Make it a 16-bit word value
	sts	cmd+ring_size+0, r16	; save it
	sts	cmd+ring_size+1, r17	; save it

	logtr	0x10, r16, r17
	
	subi	r16, low(1)		; convert size to overflow mask
	sbci	r17, high(1)		; possible values are 0,1,3,7,15,31,63,127
	lsl	r16			; multiply by four 
	rol	r17			;
	lsl	r16			;
	rol	r17			;
	sts	cmd+ring_mask+0, r16
	sts	cmd+ring_mask+1, r17

	logtr	0x11, r16, r17

;
;	Calculate the response ring size and mask
;
	mov	r17, r21		; isolate response ring length 
	andi	r17, 7
	ldi	r16, 1
	rjmp	init150
init140:
	lsl	r16
init150:
	dec	r17
	brpl	init140
	clr	r17
	sts	rsp+ring_size+0, r16	
	sts	rsp+ring_size+1, r17	
	
	logtr	0x12, r16, r17

	subi	r16, low(1)
	sbci	r17, high(1)
	lsl	r16
	rol	r17
	lsl	r16
	rol	r17
	sts	rsp+ring_mask+0, r16
	sts	rsp+ring_mask+1, r17

	logtr	0x13, r16, r17

;
;	After we receive the step 1 response and processed the content we
;	now need to initialise the MSCP controller. The basic initialisation
;	of the MCU inkluding all IO has already done by the startup section
;	here we need to setup all packet queues, initialise the controller
;	status und mount the SD-Card. Up to here there are no dynamic data
;	structures
;
;
;	ldi	r16, max_packets
;	mov	r15, r16
init160:
;	ldi	r24, low(pkt_length)
;	ldi	r25, high(pkt_length)
;	call	malloc
;	sbiw	r25:r24, 0
;	brne	init170
;	ldi	r24, low(pe_nsr)	; no such resource
;	ldi	r25, high(pe_nsr)	; no such resource
;	jmp	fatal_error
init170:
;	ldi	r22, low(pkts)
;	ldi	r23, high(pkts)
;	call	enqhead
;	dec	r15
;	brne	init160
	ldi	r16, mscp_s2		; Switch to S2 which will activate the
					; appropriate routine in the QBUS IRS
	sts	mscpstatus, r16		;
	rcall	pokehost		; Possibly create a Host interrrupt 
	rjmp	init010			; And here we go
;--------------------------------------------------------------------------
;
;	When in S2 and the Host writes a configuration word we arrive
;	here. There is not much we can do now, as for further processing
;	we need the upper ring base adde
;
init_s2:
;
;	Step 2 response
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	| ring base address low                                      |PI |
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
	ldi	r16, mscp_s3
	sts	mscpstatus, r16		; Set new state
	rcall	pokehost
	rjmp	init010
;--------------------------------------------------------------------------
;
;
;
init_s3:
;
;	Step 3 response
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	|PP | ring base address high                                     |
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
	lds	r21, sa_s3+1
	sbrs	r21, s3pp_bp		; purge/poll test requested
	rjmp	init320			; no
	sts	iprflag, zero
	cli				;;;
	sts	sar+0, zero		;;;
	sts	sar+1, zero		;;;
	sei				;;;

	ldi	r24, low(mscpsaw)
	ldi	r25, high(mscpsaw)
	call	block
	cli				;;;
	lds	r24, saw+0		;;;
	lds	r25, saw+1		;;;
	sei				;;;

	sbiw	r25:r24, 0
	breq	init310
	ldi	r24, pe_ppf
	call	fatal_error

init310:
	ldi	zl, low(mscpipr)
	ldi	zh, high(mscpipr)
	call	block			; Wait for the IP Read to happen
;
;	Now calculate various memory addresses. Note that in RQDX3 source code
;	long (32-bit) values are stored high 16-bit value at offset zero and 
;	low 16-bit value at offset two. We keep the byte order in memory
;	for 32-bit values
;
init320:	
	lds	r16, sa_s2+0
	lds	r17, sa_s2+1
	lds	r18, sa_s3+0
	lds	r19, sa_s3+1		; 32-bit base address
	andi	r16, 0xFE
	andi	r19, 0x7F
	movw	r21:r20, r17:r16
	movw	r23:r22, r19:r18	; save it for later
	
	sts	rsp+ring_base+0, r16	; ring base address is also the response
	sts	rsp+ring_base+1, r17	; ring start address
	sts	rsp+ring_base+2, r18
	sts	rsp+ring_base+3, r19
	
	lds	r14, rsp+ring_size+0	; number of double-words in ring buffer
	lds	r15, rsp+ring_size+1	;
	lsl	r14
	rol	r15
	lsl	r14
	rol	r15			; make it a byte offset
	add	r16, r14		; add to response ring address to get
	adc	r17, r15		; the command ring start address
	adc	r18, zero
	adc	r19, zero
	
	sts	cmd+ring_base+0, r16	; set command ring start address
	sts	cmd+ring_base+1, r17
	sts	cmd+ring_base+2, r18
	sts	cmd+ring_base+3, r19
;
;	r24 will count for the number of double words we need to zap with zero.
;	The response and command ring interrupt flags count for one double word.
;	The purge interrupt flag and reserved area count for another double word.
;	And then the response and command rings itself need to be considered.
;
	clr	r19			; Assume no purge interrupts
;
;	Note: from here on r23:r22:r21:r20 hold the start address of the host
;	memory that we need to zap.
;
;	r23:r22:r21:r20 hold the base address of the communication memory area. 
;	There are up to four 16-bit words ahead of this area that hold the 
;	communication flags used for interrupts.
;
	subi	r20, byte1(2)
	sbci	r21, byte2(2)
	sbci	r22, byte3(2)
	sbci	r23, byte4(2)

	sts	rsp+ring_flag+0, r20	; Response Ring Interrupt Flag
	sts	rsp+ring_flag+1, r21	; 
	sts	rsp+ring_flag+2, r22
	sts	rsp+ring_flag+3, r23

	subi	r20, byte1(2)
	sbci	r21, byte2(2)
	sbci	r22, byte3(2)
	sbci	r23, byte4(2)

	sts	cmd+ring_flag+0, r20	; Command Ring Interrupt Flag
	sts	cmd+ring_flag+1, r21
	sts	cmd+ring_flag+2, r22
	sts	cmd+ring_flag+3, r23

	sts	purgeflag+0, zero	; Assume no purge interrupts
	sts	purgeflag+1, zero
	sts	purgeflag+2, zero
	sts	purgeflag+3, zero

	lds	r16, sa_s2+0
	sbrs	r16, s2pi_bp
	rjmp	init330

	ldi	r19, 1			; We have purge interrupts

	subi	r20, byte1(2)		; Purge interupts are requested
	sbci	r21, byte2(2)
	sbci	r22, byte3(2)
	sbci	r23, byte4(2)

	sts	purgeflag+0, r20	; Address of purge interrupt flags
	sts	purgeflag+1, r21
	sts	purgeflag+2, r22
	sts	purgeflag+3, r23

	subi	r20, byte1(2)		; Address of reserved word with purge interrupts
	sbci	r21, byte2(2)		; which preceeds the purge interrupt flag in
	sbci	r22, byte3(2)		; host memory
	sbci	r23, byte4(2)
;
;	r23:r22:r21:r20 now hold the start address of the area we need to zap
;
init330:
	ldi	r24, low(dmalock)
	ldi	r25, high(dmalock)
	call	acquire

	dmaaddr	r20, r21, r22		; Setup DMA address

	logtr	0x14, r20, r21	
	logtr	0x15, r22, r19
	clr	r16			; We will write r16, r16, r16, r17
	clr	r17			;
	tst	r19			; Zap purge interrupt field
	breq	init340			; no
	rcall	initzapdw		; Zap reserved and purge interrupt flags
	
init340:
	rcall	initzapdw		; Zap response and command ring transition flags
	ldi	r17, 0x80		; RSP ring needs O-flag set
	lds	r19, rsp+ring_size+0	; we only need the low byte
	logtr	0x16, r19, zero
init350:
	rcall	initzapdw
	dec	r19
	brne	init350

	clr	r17
	lds	r19, cmd+ring_size+0	; we only need the low byte
	logtr	0x17, r19, zero
init360:
	rcall	initzapdw
	dec	r19
	brne	init360

	ldi	r24, low(dmalock)
	ldi	r25, high(dmalock)
	call	release

	sts	cmd+ring_index+0, zero
	sts	cmd+ring_index+1, zero
	sts	rsp+ring_index+0, zero
	sts	rsp+ring_index+1, zero

	ldi	r16, mscp_s4
	sts	mscpstatus, r16	
	rcall	pokehost
	rjmp	init010


initzapdw:

	logtr	0x18, r16, r17

	dmawrt	r16, r16
	dmawrt	r16, r17
	ret
;--------------------------------------------------------------------------
;
;
;
init_s4:
;
;	Step 4 response
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	|           reserved            ||   dma burst size      |LF |GO |
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
	cli				;;;
	lds	r20, sa_s4+0		;;;
	lds	r21, sa_s4+1		;;;
	sei				;;;
	sbrs	r20, s4go_bp
	rjmp	init010
	sbrs	r20, s4lf_bp
	rjmp	init410
	lds	r24, porterror
	tst	r24
	breq	init410
	call	do_plf
	sts	porterror, zero
init410:
	lds	r18, _ccb_state
	sbr	r18, (1<<cs__act)
	cbr	r18, (1<<cs__ini)
	sts	_ccb_state, r18
	ldi	r16, mscp_go
	sts	mscpstatus, r16
	rjmp	init010
;--------------------------------------------------------------------------
;
;
;
pokehost:
	lds	r16, sa_s1+0		;
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
	ret
