;--------------------------------------------------------------------------
;
;	Pin Change Interrupt for POLL
;
;	
;
;	2022-02-18
;
poll_:
	sbis	f_GO
	reti


unblockpoll:
	sbi	b_GO
	push	r8			; save minimal context
	in	r8, CPU_SREG
	push	zh			; acknowledging the interrupt we need to
	push	zl			; have at least one additional cpu cycle!
	push	yh
	push	yl
	sbi	f_GO			; Acknowledge interrupt
	ldi	zl, low(mscpipr)
	ldi	zh, high(mscpipr)
	jmp	unblocki


;--------------------------------------------------------------------------
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
;	!!!! only temporary defined here !!!!
;
deqf_head:
enq_head:
;
;	Main Entry Point
;
polljob:
;
;	All the initialisation must be done in a job therefore the whole
;	initialisation will take place here
;




poll100:
	rcall	get_packet
	sbiw	r25:r24, 0
	breq	poll120
	movw	yh:yl, r25:r24		; 
	ldd	r18, Y+pkt_type
	andi	r18, 0360
	brne	poll140
	ldd	r18, Y+pkt_type
	cpi	r18, ct_mscp
	brne	poll110
	call	do_mscp			; Destroys all registers!!!!
	rjmp	poll100
poll110:
	cpi	r18, ct_dup
	brne	poll130
	call	do_dup			; Destroys all registers!!!!
	rjmp	poll100

poll120:
	ldi	r24, low(mscpipr)
	ldi	r25, high(mscpipr)
	call	block
	rjmp	poll100

poll130:
	ldi	r24, low(pe_ici)
	ldi	r25, high(pe_ici)
	call	fatal_error

poll140:
	ldi	r24, low(pe_pie)
	ldi	r25, high(pe_pie)
	call	fatal_error
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
	ldi	r24, low(dma)
	ldi	r25, high(dma)
	call	acquire
	ldi	r24, low(cmd)
	ldi	r25, high(cmd)
	rcall	get_descriptor		;
	brmi	get_packet100
	sts	packet+0, zero
	sts	packet+1, zero
	rjmp	get_packet110

get_packet100:
	ldi	r24, low(pkts)		; get a packet from the free packet queue
	ldi	r25, high(pkts)
	call	deqf_head		; fail if there is none
	sts	packet+0, r24		; save packet
	sts	packet+1, r25
	movw	xh:xl, r25:r24		; create data pointer
	adiw	xh:xl, 2		; skip link header
	lds	r16, descriptor+0
	lds	r17, descriptor+1
	lds	r18, descriptor+2
	lds	r19, descriptor+3

	ori	r16, 1
	dmaaddr r16, r17, r18
	
	ldi	r18, 32			; max. message length is 64. bytes / 32. words
get_packet105:
	dmaread r16, r17
	brcs	get_packet120
	st	X+, r16
	st	X+, r17
	dec	r18
	brpl	get_packet105
	ldi	r24, low(cmd)
	ldi	r25, high(cmd)
	rcall	put_descriptor		;
get_packet110:
	ldi	r24, low(dma)
	ldi	r25, high(dma)
	call	release
	lds	r24, packet+0
	lds	r25, packet+1
	ret

get_packet120:
	ldi	r24, low(pe_pre)
	ldi	r25, high(pe_pre)
	rcall	fatal_error

;
; this routine will put a packet to the host if a slot is available (one is
; available if a valid descriptor is returned)
;
put_packet:
	push	yl
	push	yh			; save packet
	movw	yh:yl, r25:r24

put_packet100:
	ldi	r24, low(dma)
	ldi	r25, high(dma)
	call	acquire
	rcall	get_descriptor
	brmi	put_packet110
	ldi	r24, low(dma)
	ldi	r25, high(dma)
	call	release
	ldi	r24, low(5)
	ldi	r25, high(5)
	call	delay
	rjmp	put_packet100

put_packet110:
	ldd	r16, Y+4
	andi	r16, 0360
	brne	put_packet140
	ldd	r16, Y+16
	tst	r16
	brpl	put_packet140
	lds	r18, credits
	tst	r18
	breq	put_packet130
	cpi	r18, 16
	brlo	put_packet120
	ldi	r18, 16
	
put_packet120:
	lds	r16, credits
	sub	r16, r18
	sts	credits, r16
put_packet130:
	inc	r18
	ldd	r16, Y+4
	or	r18, r16
	std	Y+4, r18

put_packet140:
	ldd	r24, Y+pkt_size+0
	ldd	r25, Y+pkt_size+1
	adiw	r25:r24, pkt_data-pkt_size; Account for Header
	lsr	r25
	ror	r24			; Word count
	movw	xh:xl, yh:yl
	adiw	xh:xl, 2

	lds	r16, descriptor+0
	lds	r17, descriptor+1
	lds	r18, descriptor+2
	lds	r19, descriptor+3
	dmaaddr r16, r17, r18
	
put_packet145:
	ld	r16, X+
	ld	r17, X+
	dmawrt r16, r17
	brcs	put_packet160
	sbiw	r25:r24, 1
	brne	put_packet145
	rcall	put_descriptor
	ldi	r24, low(dma)
	ldi	r25, high(dma)
	call	release
	movw	r25:r24, yh:yl
	call	enq_head
	lds	r16, ha_flag		; one packet less
	dec	r16
	sts	ha_flag, r16		;
	brne	put_packet150
	lds	r16, _ccb_timeout	; enable host timeouts
	sts	ha_time, r16
put_packet150:
	pop	yh
	pop	yl
	ret

put_packet160:
	ldi	r24, low(pe_pwe)
	ldi	r25, high(pe_pwe)
	rcall	fatal_error

;
; get a descriptor (two words) from the host; the second word is copied only
; if the first word indicates that this is a valid descriptor
;
get_descriptor:
	movw	zh:zl, r25:r24		; The Ring Descriptor
	
	ldd	r16, Z+ring_base+0
	ldd	r17, Z+ring_base+1
	ldd	r18, Z+ring_base+2
	ldd	r19, Z+ring_base+3
	ldd	r24, Z+ring_index+0
	ldd	r25, Z+ring_index+1
	adiw	r25:r24, 2

	add	r16, r20
	adc	r17, r21
	adc	r18, zero
	adc	r19, zero
	
	ori	r16, 1			; DMA Read
	dmaaddr r16, r17, r18
	dmaread	r20, r21
	brcc	get_descriptor050
	rjmp	get_descriptor110
get_descriptor050:
	sts	descriptor+2, r20
	sts	descriptor+3, r21
	tst	r21
	brmi	get_descriptor100
	ret
get_descriptor100:
	sts	source+0, r16
	sts	source+1, r17
	sts	source+2, r18
	sts	source+3, r19
	subi	r16, byte1(2)
	subi	r17, byte2(2)
	subi	r18, byte3(2)
	subi	r19, byte4(2)

	ori	r16, 1			; DMA Read
	dmaaddr r16, r17, r18
	dmaread	r20, r21
	brcs	get_descriptor110

	sts	descriptor+0, r20
	sts	descriptor+1, r21
	sen
	ret

get_descriptor110:
	ldi	r24, low(pe_qre)
	ldi	r25, high(pe_qre)
	rcall	fatal_error	


;
; put a descriptor (two words) to the host, clearing the owner bit and
; interrupting the host if the ring has transitioned from either "empty" to
; "non-empty" or from "full" to "non-full" (both conditions are detected
; by noticing whether the owner bit is set for the previous descriptor)
;
put_descriptor:
	movw	yh:yl, r25:r24
	lds	r16, source+0
	lds	r17, source+1
	lds	r18, source+2
	lds	r19, source+3

	dmaaddr r16, r17, r18
	
	lds	r22, descriptor+2
	lds	r23, descriptor+3

	ori	r23, 0x40		; set F flag
	andi	r23, 0x7F		; clear O flag (ownership)
	
	dmawrt r22, r23	
	brcc	put_descriptor050
	rjmp	put_descriptor120
put_descriptor050:	
	lds	r23, descriptor+3
	sbrs	r23, 6			; was the F flag set
	rjmp	put_descriptor110	; no - don't interrupt the host

	ldd	r24, Y+ring_size+0
	ldd	r25, Y+ring_size+1
	sbiw	r25:r24, 1		; is it a ring size of 1
	brne	put_descriptor060
	rjmp	put_descriptor100	; yes - always interrupt the host
put_descriptor060:
	ldd	r16, Y+ring_base+0	; get address to poll
	ldd	r17, Y+ring_base+1
	ldd	r18, Y+ring_base+2
	ldd	r19, Y+ring_base+3

	ldd	r24, Y+ring_index+0	; create index of previous 
	ldd	r25, Y+ring_index+1	; descriptor
	sbiw	r25:r24, 4		;
	
	ldd	r22, Y+ring_mask+0	; make sure the index is within the ring
	ldd	r23, y+ring_mask+1	; buffer
	and	r24, r22
	and	r25, r23
	adiw	r25:r24, 2		; get the second word of the descriptors

	add	r16, r24		; calculate the host memory address of
	adc	r17, r25		; the descriptor
	adc	r18, zero
	adc	r19, zero

	ori	r16, 1			; DMA read
	dmaaddr r16, r17, r18	; set DMA address
	dmaread	r16, r17		; read the 2nd word of the descrption
	brcc	put_descriptor070
	rjmp	put_descriptor120
put_descriptor070:
	tst	r17			; do we own the previous entry
	brpl	put_descriptor110	; no
put_descriptor100:
;
;	If the message was a command with F=1 and the port fetching it
;	caused the command ring to transition from full to non-full.
;	(note it was full in case the previous descriptor was owned by us)
;	This interrupt means that the host may place another command in
;	the command ring
;
;	If the message was a response with F=1 and the port's depositing
;	it caused the resonse ring to transition from empty to non-empty
;	(not it was empty in case the previous descriptor was owned by us)
;	This interrupt means that there is a response for the host to
;	be processed.
;
;	Each ring has it's own flag in host memory to let the host know
;	which ring transition was the cause of the interrupt. To raise
;	the flag we just need to write a value one to the flag location.


	ldd	r16, Y+ring_flag+0	; the ring just transitions from full
	ldd	r17, Y+ring_flag+1	; to no-full (it was full if this and the
	ldd	r18, Y+ring_flag+2	; the previous descriptor in the ring was
	ldd	r19, Y+ring_flag+3	; owned by us
	ldi	r20, low(1)		; Flag value
	ldi	r21, high(1)

	dmaaddr r16, r17, r18
	dmawrt r20, r21
	brcs	put_descriptor120

	lds	r24, vector+0
	lds	r25, vector+1
	sbiw	r25:r24, 0		; is a vector defined
	breq	put_descriptor110	; no
	sbi	b_IRQ			; set interrupt
put_descriptor110:
	ldd	r16, Y+ring_index+0
	ldd	r17, Y+ring_index+1
	ldd	r18, Y+ring_mask+0
	ldd	r19, Y+ring_mask+1
	and	r16, r18
	and	r17, r19
	std	Y+ring_index+0, r16
	std	Y+ring_index+1, r17
	ret

put_descriptor120:
	ldi	r24, low(pe_qwe)
	ldi	r25, high(pe_qwe)
	rcall	fatal_error


;
; get a buffer from the host
;
get_buffer:;( qbusaddress:r18:r19:r20:r21, memoryaddress:r22:r23, bytecount:r24:r25)
	ori	r18, 1
	dmaaddr r18, r19, r20
;	tst	r21
;	bmi	map_buffer		; <<<<<<<<<< micro VAX I
	
	movw	xh:xl, r23:r22
	lsr	r25
	ror	r24			; Word Count
get_buffer100:
	dmaread	r16, r17
	brcs	get_buffer120
	st	X+, r16
	st	X+, r17
	sbiw	r25:r24, 1
	brne	get_buffer100
	clr	r24
	clr	r25
	ret

get_buffer120:
	ldi	r24, low(er_nem)
	ldi	r25, high(er_nem)
	ret

put_buffer:
	andi	r18, 0xFE
	dmaaddr r18, r19, r20
;	tst	r21
;	brmi	map_buffer
	
	movw	xh:xl, r23:r22
	lsr	r25
	ror	r24			; Word Count
put_buffer100:
	ld	r16, X+
	ld	r17, X+
	dmawrt r16, r17
	brcs	put_buffer120
	sbiw	r25:r24, 1
	brne	put_buffer100
	clr	r24
	clr	r25
	ret

put_buffer120:
	ldi	r24, low(er_nem)
	ldi	r25, high(er_nem)
	ret



;
; this is the "croak and die" routine
;
; This routine is called when a fatal controller error has occurred, at a low
; enough level that the link to the host is effectively broken.  The only
; thing left to do is to stuff an error code into the SA and loop forever.
; Of course, we save the SA error code for the next initialization attempt.
;
fatal_error:
	rjmp	PC			;;; wait forever
