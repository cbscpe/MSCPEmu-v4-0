;--------------------------------------------------------------------------
;
;	Pin Change Interrupt for POLL
;
;	
;
;	2022-02-18 Peter Schranz
;
;	2026-04-21 Peter Schranz
;		We will not implement a packet queue and we will only have 
;		one job that does all the MSCP handling. That is we only
;		have the POLL job.
;		
;		We are now using multiple IOs on Port B for interrupts. The
;		GO flag is now exclusively used for IP writes, it will most
;		likely be renamed to IP, and the SA flag is used for writes
;		to the SA register during writes and for reads to the SA
;		register when the initialisation state has reached the GO 
;		state
;		
;
poll_:
	sbis	f_IP
	rjmp	poll_010
;
;	IP Read Interrupt. The RQDX3 code checks the controller state before
;	unblocking the poll job. However in our case the Q-Bus interface
;	only clears b_IP if in GO state. So we don't have to do it here
;
	sbi	b_IP
	push	r8			; save minimal context
	in	r8, CPU_SREG
	push	zh			; acknowledging the interrupt we need to
	push	zl			; have at least one additional cpu cycle!
	push	yh
	push	yl
	sbi	f_IP			; Acknowledge interrupt
	ldi	zl, low(mscpipr)
	ldi	zh, high(mscpipr)
	jmp	unblocki

poll_010:
	sbis	f_SA
	reti
;
;	In the RQDX3 code a SA write increments the saw.flag and the INIT process
;	waits for this flag in a loop in the "init" sub-routine. Here we have a
;	INIT job.
;
	sbi	b_SA
	push	r8			; save minimal context
	in	r8, CPU_SREG
	push	zh			; acknowledging the interrupt we need to
	push	zl			; have at least one additional cpu cycle!
	push	yh
	push	yl
	sbi	f_SA			; Acknowledge interrupt
	ldi	zl, low(mscpsaw)
	ldi	zh, high(mscpsaw)
	jmp	unblocki

;----------------------------------------------------------------------------
;
;	Main Routine 
;
;	This is the starting point for all commands received via the port
;	from the host.
;
;	Normally POLL is blocked and waits for some action. A host that
;	queues a command to the command ring is supposed to read the IP
;	register. Reading the IP register will set the software interrupt
;	b_POLL which will cause the pin change ISR to unblock POLL.
;
;	Poll then tries to get a packet. If there is a packet then it
;	will dispatch the packet to the action routine
;
;	The action routine will then process the command and return the
;	response to the host
;



;
;	Main Entry Point
;
polljob:
	clr	r8			; will be set to fatal_error in delay loop
	clr	r9			; and can be displayed with "show jobs".
	ldi	r24, low(mscpipr)	; In the source code of the RQDX3 controller
	ldi	r25, high(mscpipr)	; POLL first performs a get_packet, which in
	call	block			; my opinion is not correct.
;
;	Main Loop
;
poll100:
	rcall	get_packet		; Get Packet
	logtr	0x70, r24, r25
	sbiw	r25:r24, 0
	brne	poll120			; No Packet

	ldi	r24, low(mscpipr)
	ldi	r25, high(mscpipr)
	call	block
	rjmp	poll100

poll120:
	movw	yh:yl, r25:r24

	ldd	r16, Y+pkt_type
	ldd	r17, Y+pkt_connid
;	logtr	0x79, r16, r17

	andi	r16, 0xF0		; Mask credit fields to get message type
	brne	poll140			; This is not a sequential message -> fatal

	tst	r17
	brne	poll130

	ldd	r16, Y+cmd_opcd	; Get Opcode

	logtr	0x79, r16, r17
	
	cpi	r16, op_onl
	brne	poll121
	call	do_onl
	rjmp	poll100
poll121:
	cpi	r16, op_scc
	brne	poll122
	call	do_scc
	rjmp	poll100
poll122:
	cpi	r16, op_rd
	brne	poll123
	call	do_rd
	rjmp	poll100
poll123:
	cpi	r16, op_wr
	brne	poll124
	call	do_wr
	rjmp	poll100
poll124:
	ori	r16, op_end
	std	Y+rsp_opcd, r16	; Set End Flag
	rcall	put_packet
	rjmp	poll100
	
;>>>>>>>>
	

;	lds	r16, cmd_link+cmd_opcd	; Get Opcode
;	ori	r16, op_end
;	sts	cmd_link+rsp_opcd, r16	; Set End Flag
;
;	ldi	r24, low(rsp_link)
;	ldi	r25, high(rsp_link)
;	call	do_mscp			; do_mscp
;
;	ldi	r24, low(cmd_link)
;	ldi	r25, high(cmd_link)
;	call	put_packet
;	rjmp	poll100
;
poll110:
;	cpi	r16, 2
;	brne	poll130
;
;	lds	r16, cmd_link+cmd_opcd	; Get Opcode
;	ori	r16, op_end
;	sts	cmd_link+rsp_opcd, r16	; Set End Flag
;
;	ldi	r24, low(cmd_link)
;	ldi	r25, high(cmd_link)
;	call	put_packet
;	rjmp	poll100


poll130:
	ldi	r24, low(pe_ici)	; illegal connection identifier
	ldi	r25, high(pe_ici)
	call	fatal_error

poll140:
	ldi	r24, low(pe_pie)	; protocol incompatibility error
	ldi	r25, high(pe_pie)
	call	fatal_error
;----------------------------------------------------------------------------
;
;	Communication to the host is done via two rings. Each ring 
;	contains a number of descriptors. The number is define during
;	initialisation by the host. The descriptors are 32-bit values
;	
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;	| L | L | L | L | L | L | L | L | L | L | L | L | L | L | L | 0 |
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;	| O | F |            reserved           | Q | Q | Q | Q | U | U |
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;
;	The L,U,Q bits define the host memory address of a buffer where
;	for command descriptors the host has put a command message and
;	for response descriptor the host expects the response message.
;
;	O	is the owner flag O=0 means host and O=1 means controller
;	F	is a flag
;
;	After initialisation the command descriptors are owned by the
;	host and the response descriptors are owned by the controller
;
;	A message can be up to 64bytes. Therefore all buffers are at 
;	laest 64 bytes in length. 
;
; this routine will get a packet from the host if one is available (one is
; available if a valid descriptor is returned)
;
get_packet:
	ldi	r24, low(dmalock)
	ldi	r25, high(dmalock)
	call	acquire
	ldi	r24, low(cmd)
	ldi	r25, high(cmd)
	rcall	get_descriptor		;
	brmi	get_packet100
	clr	r20
	clr	r21
	rjmp	get_packet110

get_packet100:
	lds	r16, descriptor+0
	lds	r17, descriptor+1
	lds	r18, descriptor+2
;-22	lds	r19, descriptor+3
	subi	r16, byte1(4)
	sbci	r17, byte2(4)
	sbci	r18, byte3(4)
;-22	sbci	r19, byte4(4)
	ori	r16, 1
	logtr	0x76, r16, r17		;-----> logging
	dmaaddr r16, r17, r18

	ldi	xl, low(cmd_link)
	ldi	xh, high(cmd_link)	
	movw	r21:r20, xh:xl
	adiw	xh:xl, 2		; skip link header

	dmaread r24, r25		; Get Packet Size
	brcc	get_packet101
	rjmp	get_packet120
get_packet101:
	st	X+, r24			; Save Packet Size in cmd_buffer
	st	X+, r25
	logtr	0x77, r24, r25		;-----> logging
	dmaread r16, r17		; Get Connection ID and Packet Type
	brcc	get_packet102
	rjmp	get_packet120
get_packet102:
	st	X+, r16			; Save in cmd_buffer
	st	X+, r17
	logtr	0x77, r16, r17		;-----> logging
get_packet105:
	dmaread r16, r17
	brcs	get_packet120

	logtr	0x77, r16, r17		;-----> logging
	st	X+, r16
	st	X+, r17
	sbiw	r25:r24, 2		; two bytes done
	brne	get_packet105
	ldi	r24, low(cmd)
	ldi	r25, high(cmd)
	rcall	put_descriptor		;
get_packet110:
	ldi	r24, low(dmalock)
	ldi	r25, high(dmalock)
	call	release
	movw	r25:r24, r21:r20
	ret

get_packet120:
	ldi	r24, low(dmalock)
	ldi	r25, high(dmalock)
	call	release
	ldi	r24, low(pe_pre)
	ldi	r25, high(pe_pre)
	rcall	fatal_error
;----------------------------------------------------------------------------
;
; this routine will put a packet to the host if a slot is available (one is
; available if a valid descriptor is returned)
;
put_packet:
	push	yl
	push	yh
	movw	yh:yl, r25:r24
put_packet100:

	ldi	r16, 10
	mov	r10, r16
	ldi	r24, low(dmalock)	; Acquire the DMA engine
	ldi	r25, high(dmalock)
	call	acquire
	ldi	r24, low(rsp)		; Get descriptor from response ring
	ldi	r25, high(rsp)
	rcall	get_descriptor
	brmi	put_packet110
	ldi	r24, low(dmalock)	; Release the DMA engine
	ldi	r25, high(dmalock)
	call	release
	logtr	0x71, r12, r13
	pop	yh
	pop	yl
	ret;------->
	
	ldi	r24, low(20)		; Sleep for a bit
	ldi	r25, high(20)
	call	delay
	dec	r10
	breq	put_packet090
	rjmp	put_packet100
put_packet090:
	ret

put_packet110:

	ldd	r20, Y+pkt_type 	; credits/message type
	andi	r20, 0xF0		; is this a sequential message?
	brne	put_packet140		; no
	ldd	r20, Y+rsp_opcd	; is this a response packet?
	tst	r20
	brpl	put_packet140		; no
	lds	r21, credits		; send number of credits if needed
	tst	r21
	breq	put_packet130		; not needed
	cpi	r21, 14			; too many for one message?
	brlo	put_packet120		; no
	ldi	r21, 14			; just do this many for now
put_packet120:
	lds	r20, credits
	sub	r20, r21
	sts	credits, r20		; update credits
put_packet130:
	inc	r21			; credits is actually one more
	ldd	r20, Y+pkt_type
	andi	r20, 0xF0
	or	r21, r20
	std	Y+pkt_type, r21
put_packet140:
	lds	r16, descriptor+0
	lds	r17, descriptor+1
	lds	r18, descriptor+2
;-22	lds	r19, descriptor+3
	subi	r16, byte1(4)
	sbci	r17, byte2(4)
	sbci	r18, byte3(4)
;-22	sbci	r19, byte4(4)

	logtr	0x7A, r16, r17

	dmaaddr r16, r17, r18

	movw	xh:xl, yh:yl		; Get Packet Address
	adiw	xh:xl, 2		; Skip Link Header

	ld	r24, X+			; Get Packet Size
	ld	r25, X+
	logtr	0x7B, r24, r25
	dmawrt	r24, r25
	adiw	r25:r24, 2		; Account for Conn ID, Type, Credits

put_packet145:
	ld	r16, X+
	ld	r17, X+
	logtr	0x7C, r16, r17

	dmawrt	r16, r17
	brcs	put_packet160
	sbiw	r25:r24, 2		; two bytes done
	brne	put_packet145
	
	ldi	r24, low(rsp)
	ldi	r25, high(rsp)
	rcall	put_descriptor
	ldi	r24, low(dmalock)
	ldi	r25, high(dmalock)
	call	release
;
;	Code from RQDX3 which makes sure the host is polled regularly
;
;	lds	r16, ha_flag		; one packet less
;	dec	r16
;	sts	ha_flag, r16		;
;	brne	put_packet150
;	lds	r16, _ccb_timeout	; enable host timeouts
;	sts	ha_time, r16
put_packet150:
	pop	yh
	pop	yl
	ret

put_packet160:
	ldi	r24, low(pe_pwe)
	ldi	r25, high(pe_pwe)
	rcall	fatal_error

;--------------------------------------------------------------------------
;
;	Get a descriptor from the host. Note we will in any case read the
;	whole descriptor, else we would need to read the second word first
;	and then set the DMA address again to read the first word in case
;	this is a valid descriptor (O-Flag set).
;
;	Input:
;	r25:r24 must be set to either the command or response ring data structure
;
;	Output:
;	descriptor
;	descr_addr
;
;	O-Flag will be copied to the processor status N
;
get_descriptor:
	push	r16
	push	r17
	push	yl
	push	yh
	movw	yh:yl, r25:r24		; The Ring Descriptor
	
	ldd	r16, Y+ring_base+0	; get address to poll using the ring
	ldd	r17, Y+ring_base+1	; base address and the current index
	ldd	r18, Y+ring_base+2
;-22	ldd	r19, Y+ring_base+3	; The Q-Bus has only 22 address bits
	ldd	r20, Y+ring_index+0
	ldd	r21, Y+ring_index+1

	add	r16, r20
	adc	r17, r21
	adc	r18, zero
;-22	adc	r19, zero

	sts	descr_addr+0, r16	; save descriptor address in case we need
	sts	descr_addr+1, r17	; it later
	sts	descr_addr+2, r18
;-22	sts	descr_addr+3, r19

	ori	r16, 1			; DMA Read
	logtr	0x72, r16, r17
	dmaaddr r16, r17, r18

	dmaread	r20, r21		; Read full descriptor
	brcs	get_descriptor040
	dmaread	r22, r23		; 
	brcc	get_descriptor050
get_descriptor040:
	rjmp	get_descriptor110	; Something went wrong
get_descriptor050:
	sts	descriptor+0, r20	; Save the descriptor
	sts	descriptor+1, r21
	sts	descriptor+2, r22
	sts	descriptor+3, r23
	
	logtr	0x73, r20, r21		; Low
	logtr	0x73, r22, r23		; High word of descriptor

get_descriptor100:
	pop	yh
	pop	yl
	pop	r17
	pop	r16
	tst	r23			; O-Flag -> N
	ret

get_descriptor110:
	ldi	r24, low(pe_qre)	; Queue read error
	ldi	r25, high(pe_qre)
	rcall	fatal_error	
;
; put a descriptor (two words) to the host, clearing the owner bit and
; interrupting the host if the ring has transitioned from either "empty" to
; "non-empty" or from "full" to "non-full" (both conditions are detected
; by noticing whether the owner bit is set for the previous descriptor)
;
put_descriptor:
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	lds	r16, descr_addr+0
	lds	r17, descr_addr+1
	lds	r18, descr_addr+2
;-22	lds	r19, descr_addr+3
	subi	r16, byte1(-2)
	sbci	r17, byte2(-2)
	sbci	r18, byte3(-2)
;-22	sbci	r19, byte4(-2)		; We only need to update the second word

	lds	r22, descriptor+2
	lds	r23, descriptor+3
	ori	r23, 0x40		; set F flag
	andi	r23, 0x7F		; clear O flag (ownership)

	dmaaddr r16, r17, r18

	dmawrt r22, r23	
	brcc	put_descriptor050
put_descriptor040:	
	rjmp	put_descriptor120

put_descriptor050:	
	lds	r23, descriptor+3	
	sbrs	r23, 6			; was the F flag set
	rjmp	put_descriptor110	; no - don't interrupt the host

	ldd	r24, Y+ring_size+0	; is it a ring of size one?
	ldd	r25, Y+ring_size+1	; 
	sbiw	r25:r24, 1		; 
	brne	put_descriptor060	;
	rjmp	put_descriptor100	; yes - always interrupt the host
put_descriptor060:
	ldd	r16, Y+ring_base+0	; get address of ring
	ldd	r17, Y+ring_base+1
	ldd	r18, Y+ring_base+2
;-22	ldd	r19, Y+ring_base+3

	ldd	r24, Y+ring_index+0	; create index of previous 
	ldd	r25, Y+ring_index+1	; descriptor to poll
	sbiw	r25:r24, 4		;
	ldd	r22, Y+ring_mask+0	; make sure the index is within the ring
	ldd	r23, y+ring_mask+1	; buffer size
	and	r24, r22
	and	r25, r23
	adiw	r25:r24, 2		; get the second word of the descriptors

	add	r16, r24		; calculate the host memory address of
	adc	r17, r25		; the descriptor
	adc	r18, zero
;-22	adc	r19, zero

	ori	r16, 1			; DMA read

	logtr	0x74, r16, r17		;-----> address of high word of previous descriptor

	dmaaddr r16, r17, r18	; set DMA address
	dmaread	r16, r17		; read the 2nd word of the descrption
	brcc	put_descriptor070
	rjmp	put_descriptor120

	logtr	0x78, r16, r17		;-----> high word of previous descriptor

put_descriptor070:
	tst	r17			; do we own the previous entry
	brmi	put_descriptor100
	rjmp	put_descriptor110	; no
put_descriptor100:
;
;	If the message was a command with F=1 and the port fetching it
;	caused the command ring to transition from full to non-full.
;	(note it was full in case the previous descriptor was owned by us)
;	This interrupt means that the host may place another command in
;	the command ring
;
;	If the message was a response with F=1 and the port's depositing
;	it caused the response ring to transition from empty to non-empty
;	(note it was empty in case the previous descriptor was owned by us)
;	This interrupt means that there is a response for the host to
;	be processed.
;
;	Each ring has it's own flag in host memory to let the host know
;	which ring transition was the cause of the interrupt. To raise
;	the flag we just need to write a value one to the flag location.


	ldd	r16, Y+ring_flag+0	; The ring transition requries to interrupt
	ldd	r17, Y+ring_flag+1	; the host, each ring keeps the memory 
	ldd	r18, Y+ring_flag+2	; address of the flag word which must be set
;-22	ldd	r19, Y+ring_flag+3	; to a non-zero value before we activate the
	ldi	r20, low(1)		; interrupt
	ldi	r21, high(1)

	logtr	0x7E, r16, r17		

	dmaaddr	r16, r17, r18
	dmawrt	r20, r21
	brcs	put_descriptor120

	lds	r24, vector+0
	lds	r25, vector+1
	sbiw	r25:r24, 0		; is a vector defined
	breq	put_descriptor110	; no
	sbi	b_IRQ			; set interrupt
put_descriptor110:
	ldd	r24, Y+ring_index+0	; point to the nect slot
	ldd	r25, Y+ring_index+1
	ldd	r18, Y+ring_mask+0
	ldd	r19, Y+ring_mask+1
	adiw	r25:r24, 4
	and	r24, r18
	and	r25, r19
	std	Y+ring_index+0, r24
	std	Y+ring_index+1, r25
	logtr	0x75, r24, r25		;----> New descriptor index
	pop	yh
	pop	yl
	ret

put_descriptor120:
	ldi	r24, low(pe_qwe)	; Queue write error
	ldi	r25, high(pe_qwe)
	rcall	fatal_error
;
; this is the "croak and die" routine
;
; This routine is called when a fatal controller error has occurred, at a low
; enough level that the link to the host is effectively broken.  The only
; thing left to do is to stuff an error code into the SA and loop forever.
; Of course, we save the SA error code for the next initialization attempt.
;
fatal_error:
	sts	sa_go+0, r24
	sts	sa_go+1, r25
	movw	r9:r8, r25:r24
fatal_error010:
	ldi	r24, low(10240)		;;; 10 seconds
	ldi	r25, high(10240)
	call	delay
	rjmp	fatal_error010
	rjmp	PC			;;; wait forever
