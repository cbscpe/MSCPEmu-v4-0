;--------------------------------------------------------------------------
;
;	Pin Change Interrupt for POLL and SA write
;
;	2022-02-18 Peter Schranz
;
;	2026-04-21 Peter Schranz
;		We will not implement a packet queue and we will only have 
;		one job that does all the MSCP handling. That is we only
;		have the POLL job.
;		
;		We are now using multiple IOs on Port B for interrupts. The
;		GO flag from the RLV12 emulator has been renamed to IP for
;		the MSCP emulation and the SA flag is used for writes
;		to the SA register mainly used during initialisation
;
;	2026-05-06 Peter Schranz
;
;		0x71	get_descriptor DMA address as the ring area is fixed
;			we only show the lower 16-bit of the address
;		0x72	get_descriptor the descriptor itself
;		0x73	put_descriptor, address of descriptor high word and value
;		0x74	put_descriptor, address of previous descriptor high word
;			and value
;		0x75	put_descriptor, address of interrupt flag
;		0x76	put_descriptor, new index
;		0x77	poll: init block
;		0x78	poll: ipr block
;		0x79	poll: status check with packet
;
;		0x7A	put_packet return end-code, flags, status 
;		0x7B	put_packet message size, Packet-type, Credits, Connection ID
;		0x7C	put_packet response status
;		0x7D	get_packet start address
;
;		0x7F	follows any trace in case more then 16-bits need to be
;			logged.
;
;		0x1E	poll: unit, opcode, packet type and connection ID of received
;			packet, we use the ID code of the INIT module to avoid
;			confusion with 0x7x codes from the POLL module
;	2026-06-06 Peter Schranz
;
;	New traces and added DMAPOLL option to enable and disable logging of
;	of DMA addresses used in poll job
;
;		0x71	Info about command packet
;		0x72	MSCP STATUS violations
;		0x7E	Response Status
;--------------------------------------------------------------------------
;
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
	cli
	lds	zl, log_pointer+0	; 3 Logging is done only if log__reg is set
	lds	zh, log_pointer+1	; 3
	ldi	yl, log_trace
	st	Z+, yl
	ldi	yl, 0x1E
	st	Z+, yl
	ldi	yl, (1<<IP)
	st	Z+, yl
	in	yl, VPORTB_OUT
	st	Z+, yl
	sbrc	zh, log_overflow	; 2/1
	ldi	zh, high(log_buffer+log_begin)
	sts	log_pointer+0, zl	; 2
	sts	log_pointer+1, zh	; 2
	sei	
	ldi	zl, low(mscpipr)
	ldi	zh, high(mscpipr)
	jmp	unblocki

poll_010:
	sbis	f_SA
	rjmp	poll_020
;
;	In the RQDX3 code a SA write increments the saw.flag and the INIT process
;	waits for this flag in a loop in the "init" sub-routine. Here we have a
;	INIT job and use block and unblocki.
;
	sbi	b_SA
	push	r8			; save minimal context
	in	r8, CPU_SREG
	push	zh			; acknowledging the interrupt we need to
	push	zl			; have at least one additional cpu cycle!
	push	yh
	push	yl
	sbi	f_SA			; Acknowledge interrupt

	cli
	lds	zl, log_pointer+0	; 3 Logging is done only if log__reg is set
	lds	zh, log_pointer+1	; 3
	ldi	yl, log_trace
	st	Z+, yl
	ldi	yl, 0x1E
	st	Z+, yl
	ldi	yl, (1<<SA)
	st	Z+, yl
	in	yl, VPORTB_OUT
	st	Z+, yl
	sbrc	zh, log_overflow	; 2/1
	ldi	zh, high(log_buffer+log_begin)
	sts	log_pointer+0, zl	; 2
	sts	log_pointer+1, zh	; 2
	sei	

	ldi	zl, low(mscpsaw)
	ldi	zh, high(mscpsaw)
	jmp	unblocki
;
;	Fatal Error Interrupt without set interrupt bit
;
poll_020:

	push	r8			; save minimal context
	in	r8, CPU_SREG
	push	zh			; acknowledging the interrupt we need to
	push	zl			; have at least one additional cpu cycle!
	push	yh
	push	yl

	cli
	lds	zl, log_pointer+0	; 3 Logging is done only if log__reg is set
	lds	zh, log_pointer+1	; 3
	ldi	yl, log_trace
	st	Z+, yl
	ldi	yl, 0x1E
	st	Z+, yl
	ldi	yl, 0xFF		; Fatal
	st	Z+, yl
	in	yl, VPORTB_OUT
	st	Z+, yl
	sbrc	zh, log_overflow	; 2/1
	ldi	zh, high(log_buffer+log_begin)
	sts	log_pointer+0, zl	; 2
	sts	log_pointer+1, zh	; 2
	sei	

	pop	yl
	pop	yh
	pop	zl
	pop	zh
	out	CPU_SREG, r8
	pop	r8
	reti

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
	ldi	r24, low(mscpinit)	; make sure initialisation is done
	ldi	r25, high(mscpinit)	;
	call	block			;
	lds	r16, mscpstatus
	cpi	r16, mscp_go		; We expect that mscpinit is unblocked whenever
	breq	poll100
	logtr	0x72, r16, zero		;
	rjmp	polljob			; the state goes to mscp_go
;
;	Main Loop
;
poll100:
	rcall	get_packet		; Get Packet
	sbiw	r25:r24, 0		; We really got a packet
	brne	poll120			; yes

poll110:				; wait for block
	cli
	lds	r16, mscpipr+0
	lds	r17, mscpipr+1
	sei
	logtr	0x73, r16, r17
	ldi	r24, low(mscpipr)
	ldi	r25, high(mscpipr)
	call	block
	lds	r16, mscpstatus		; 
	cpi	r16, mscp_go		; Make sure we are in GO state
	breq	poll100			; and only then we call get packet
	ldi	r17, 1			; Log state mismatch
	;logtr	0x72, r16, r17		;
	rjmp	poll110			; -> wait

poll120:
	movw	yh:yl, r25:r24
	ldd	r16, Y+pkt_size+0
	ldd	r17, Y+pkt_size+1
	ldd	r18, Y+pkt_type
	ldd	r19, Y+pkt_connid
	ldd	r20, Y+cmd_unit+0
	ldd	r21, Y+cmd_unit+1
	ldd	r22, Y+cmd_opcd

	mov	xl, r22
	andi	xl, 0x3F
	clr	xh
	subi	xl, low(-op_stats)
	sbci	xh, high(-op_stats)
	ld	r23, X
	inc	r23
	cpse	r23, zero		; Don't save overflow
	st	X, r23
	ldd	r23, Y+cmd_mod+0	;
	logtr	0x71, r22, r23		; Opcode / Modifiers
	logtr	0x7F, r20, r21		; Unit
	logtr	0x7F, r18, r19		; Packet Type / Connection ID
	andi	r18, 0xF0		; Mask credit fields to get message type
	brne	poll140			; This is not a sequential message -> fatal
	tst	r19
	brne	poll130
	tst	r22
	breq	poll125
	mov	zl, r22			; Get Opcode
	andi	zl, 0x3F		; 
	clr	zh
	subi	zl, low(-do_mscp_table)	; Index to jump table
	sbci	zh, high(-do_mscp_table)
	icall				; Execute function
poll125:
	rjmp	poll100			; loop

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
;	Jump Table
;	
do_mscp_table:
	rjmp	do_default		;
	rjmp	do_abo			; Abort
	rjmp	do_gcs			; Get Command Status
	rjmp	do_gus			; Get Unit Status
	rjmp	do_scc			; Set Controller Characteristics
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_avl			; Available
	rjmp	do_onl			; Online
	rjmp	do_suc			; Set Unit Characteristics
	rjmp	do_dap			; No-Op
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_acc			; Access
	rjmp	do_ccd			; No-Op
	rjmp	do_ers			; Erase
	rjmp	do_flu			; No-Op
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_new			; Format (24)
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_cmp			; Compare	
	rjmp	do_rd			; Read
	rjmp	do_wr			; Write
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_fmt			; Format (47)
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default		; AVA?? Now Available



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
	clr	r10
	clr	r11
	rjmp	get_packet110

get_packet100:
	lds	r16, descriptor+0
	lds	r17, descriptor+1
	lds	r18, descriptor+2
	lds	r19, descriptor+3
	subi	r16, byte1(4)
	sbci	r17, byte2(4)
	sbci	r18, byte3(4)
	sbci	r19, byte4(4)
	
	ori	r16, 1
	logdmapoll	0x01, r16, r17, r18	; Packet DMA Address
	dmaaddr r16, r17, r18

	ldi	xl, low(cmd_link)
	ldi	xh, high(cmd_link)
	movw	r11:r10, xh:xl
	adiw	xh:xl, 2	

	dmaread r16, r17		; Get Packet Size
	brcc	get_packet101
	rjmp	get_packet120
get_packet101:
	st	X+, r16			; Save Packet Size in cmd_buffer
	st	X+, r17
	dmaread r16, r17		; Get Connection ID and Packet Type
	brcc	get_packet102
	rjmp	get_packet120
get_packet102:
	st	X+, r16			; Save in cmd_buffer
	st	X+, r17
	ldi	r24, low(040)		; RQDX3 always reads 040 (octal) words
	ldi	r25, high(040)
get_packet105:
	dmaread r16, r17
	brcs	get_packet120
	st	X+, r16
	st	X+, r17
	sbiw	r25:r24, 1		; one word done
	brne	get_packet105
	ldi	r24, low(cmd)
	ldi	r25, high(cmd)
	rcall	put_descriptor		;
get_packet110:
	ldi	r24, low(dmalock)
	ldi	r25, high(dmalock)
	call	release
	movw	r25:r24, r11:r10
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
	
	ldd	r16, Y+rsp_opcd+0
	ldd	r17, Y+rsp_flgs+0
	ldd	r18, Y+rsp_sts+0
	ldd	r19, Y+rsp_sts+1
	logtr	0x7E, r18, r19		; 
	ldi	r16, 10
put_packet090:
	sts	put_packet_wait, r16
put_packet100:
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
	ldi	r24, low(20)		; Sleep for a bit
	ldi	r25, high(20)
	call	delay
	lds	r16, put_packet_wait
	dec	r16
	brne	put_packet090
	ldi	r24, low(pe_tmo)
	ldi	r25, high(pe_tmo)
	rcall	fatal_error

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
	lds	r19, descriptor+3
	subi	r16, byte1(4)
	sbci	r17, byte2(4)
	sbci	r18, byte3(4)
	sbci	r19, byte4(4)

	logdmapoll	0x01, r16, r17, r18	; Response Packet DMA Address
	dmaaddr r16, r17, r18

	ldd	r24, Y+rsp_sts+0
	ldd	r25, Y+rsp_sts+1
	movw	xh:xl, yh:yl		; Get Packet Address
	adiw	xh:xl, 2		; Skip Link Header

	ld	r24, X+			; Get Message Size
	ld	r25, X+
	dmawrt	r24, r25		; Put Message Size
	ld	r16, X+			; Get Packet-type, Credits, Connection ID
	ld	r17, X+
	dmawrt	r16, r17		; Put Packet-type, Credits, Connection ID
put_packet145:
	ld	r16, X+
	ld	r17, X+
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
	ldi	r24, low(dmalock)
	ldi	r25, high(dmalock)
	call	release
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
	ldd	r19, Y+ring_base+3	; The Q-Bus has only 22 address bits
	ldd	r20, Y+ring_index+0
	ldd	r21, Y+ring_index+1

	add	r16, r20
	adc	r17, r21
	adc	r18, zero
	adc	r19, zero

	sts	descr_addr+0, r16	; save descriptor address in case we need
	sts	descr_addr+1, r17	; it later
	sts	descr_addr+2, r18
	sts	descr_addr+3, r19

	ori	r16, 1			; DMA Read
	logdmapoll	0x00, r16, r17, r18	; Read Descriptor DMA Address
	dmaaddr r16, r17, r18

	clr	r12
	dmaread	r20, r21		; Read full descriptor
	brcs	get_descriptor040
	inc	r12
	dmaread	r22, r23		; 
	brcc	get_descriptor050
get_descriptor040:
	rjmp	get_descriptor110	; Something went wrong
get_descriptor050:
	sts	descriptor+0, r20	; Save the descriptor
	sts	descriptor+1, r21
	sts	descriptor+2, r22
	sts	descriptor+3, r23
get_descriptor100:
	pop	yh
	pop	yl
	pop	r17
	pop	r16
	tst	r23			; O-Flag -> N
	ret

get_descriptor110:
	ldi	r24, low(dmalock)
	ldi	r25, high(dmalock)
	call	release
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
	lds	r19, descr_addr+3
	subi	r16, byte1(-2)
	sbci	r17, byte2(-2)
	sbci	r18, byte3(-2)
	sbci	r19, byte4(-2)		; We only need to update the second word

	lds	r22, descriptor+2
	lds	r23, descriptor+3
	ori	r23, 0x40		; set F flag
	andi	r23, 0x7F		; clear O flag (ownership)
	logdmapoll	0x00, r16, r17, r18	; Write Descriptor DMA Address
	dmaaddr r16, r17, r18
	dmawrt	r22, r23	
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
	ldd	r20, Y+ring_base+0	; get address of ring
	ldd	r21, Y+ring_base+1
	ldd	r22, Y+ring_base+2
	ldd	r23, Y+ring_base+3
	ldd	r24, Y+ring_index+0	; create index of previous 
	ldd	r25, Y+ring_index+1	; descriptor to poll
	sbiw	r25:r24, 4		;
	ldd	r16, Y+ring_mask+0	; make sure the index is within the ring
	ldd	r17, y+ring_mask+1	; buffer size
	and	r24, r16
	and	r25, r17
	adiw	r25:r24, 2		; get the second word of the descriptors

	add	r20, r24		; calculate the host memory address of
	adc	r21, r25		; the descriptor
	adc	r22, zero
	adc	r23, zero
	ori	r20, 1			; DMA read
	logdmapoll	0x02, r20, r21, r22	; Read Previous Descriptor DMA Address
	dmaaddr r20, r21, r22		; set DMA address
	dmaread	r24, r25		; read the 2nd word of the descrption
	brcc	put_descriptor070
	rjmp	put_descriptor120
put_descriptor070:
	tst	r25			; do we own the previous entry
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


	ldd	r16, Y+ring_flag+0	; The ring transition requires to interrupt
	ldd	r17, Y+ring_flag+1	; the host, each ring keeps the memory 
	ldd	r18, Y+ring_flag+2	; address of the flag word which must be set
	ldd	r19, Y+ring_flag+3	; to a non-zero value before we activate the
	ldi	r24, low(1)		; interrupt
	ldi	r25, high(1)
	logdmapoll	0x02, r16, r17, r18	; Write Flag DMA Address
	dmaaddr	r16, r17, r18
	dmawrt	r24, r25
	brcs	put_descriptor120
	lds	r24, vector+0
	lds	r25, vector+1
	sbiw	r25:r24, 0		; is a vector defined
	breq	put_descriptor110	; no
	sbi	b_IRQ			; set interrupt
put_descriptor110:
	ldd	r24, Y+ring_index+0	; point to the next slot
	ldd	r25, Y+ring_index+1
	ldd	r18, Y+ring_mask+0
	ldd	r19, Y+ring_mask+1
	adiw	r25:r24, 4
	and	r24, r18
	and	r25, r19
	std	Y+ring_index+0, r24
	std	Y+ring_index+1, r25
	pop	yh
	pop	yl
	ret

put_descriptor120:
	ldi	r24, low(dmalock)
	ldi	r25, high(dmalock)
	call	release
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
	cli
	lds	zl, log_pointer+0	; 3 Logging is done only if log__reg is set
	lds	zh, log_pointer+1	; 3
	ldi	r16, log_trace
	st	Z+, r16
	ldi	r16, 0xFF
	st	Z+, r16
	st	Z+, r24
	st	Z+, r25
	sbrc	zh, log_overflow	; 2/1
	ldi	zh, high(log_buffer+log_begin)
	sts	log_pointer+0, zl	; 2
	sts	log_pointer+1, zh	; 2
	sei	

	sts	sa_go+0, r24
	sts	sa_go+1, r25
	ldi	r24, low(2)
	ldi	r25, high(2)
	call	delay
	sbi	b_CRDY
	cbi	FLAGS_LOG, log__reg	; Stop logging of registers
	movw	r9:r8, r25:r24
fatal_error010:
	ldi	r24, low(10240)		;;; 10 seconds
	ldi	r25, high(10240)
	call	delay
	rjmp	fatal_error010
	rjmp	PC			;;; wait forever
