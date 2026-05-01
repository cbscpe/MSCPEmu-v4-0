;
; given a unit number, return the address of the associated UCB (or NULL)
;
; note that this routine always updates the "offline" and "write protect"
; states; further, if a unit has just left the "offline" state, a UNIT NOW
; AVAILABLE attention message is generated
;
; In RQDX3 source code we have the array 
;
;	globaldef byte		*ucbs[4];
;
; with an arry of pointers to UCBs. getucb will convert a unit number to a UCB
; address. It will do so by subtracting unitbase from the unitnumber and then
; check if there is an entry at the index. 
;
; The unitnumber must be higher or equal to unitbase and the resulting unitnumber
; must be a valid index, i.e. unitnumber < unitbase + max_units.
;
; If the unit exists it will do some checks and eventually read the disk. 
;
; Instead of *ucbs[4] we have unittable and as always this is a table of UCBs 
; like in the RLV12 emulator and each UCB is exactly 16 bytes.
;
;
getucb:

;	r25:r24		unitnumber
	clr	zl
	clr	zh
	tst	r25
	brne	getucb000
	cpi	r24, units
	brsh	getucb000		; not a valid unit number
	movw	zh:zl, r25:r24
	swap	zl
	subi	zl, low(-unittable)	; then add base address of 
	sbci	zh, high(-unittable)
getucb000:
	movw	r25:r24, zh:zl
	ret

;	lds	r16, unitbase+0
;	lds	r17, unitbase+1
;	sub	r24, r16
;	sbc	r25, r17
;	brlt	getucb090		; not a valid unit number
;	cpi	r24, units+1
;	cpc	r25, zero
	brsh	getucb090		; not a valid unit number
	movw	zh:zl, r25:r24		; each ucb is exactly 16 bytes so translate
	swap	zl			; unitnumber to offset and
	subi	zl, low(-unittable)	; then add base address of 
	sbci	zh, high(-unittable)
	ldd	r18, Z+ucb_status	;
	andi	r18, (1<<ucb__part) | (1<<ucb__file)
	breq	getucb090		; there is no disk attached to the unit
	ldd	r18, Z+ucb_status	;
	sbrs	r18, ucb__ofl		; Is it offline
	rjmp	getucb100		; Has already been reported online
	cbr	r18, (1<<ucb__ofl)
	std	Z+ucb_status, r18
	movw	r25:r24, zh:zl
	push	r25
	push	r24
	call	do_una			; report unit available
	pop	r24
	pop	r25
	ret
getucb090:
	clr	r24
	clr	r25
getucb100:
	ret
;
; given the address of a list and a list element, add the list element to the
; head of the list
;
;	Input:
;	r25:r24		head (list)
;	r23:r22		packet (list element)
;
enqhead:
	push	yl
	push	yh
	movw	yh:yl, r25:r24		; Head
	cli
	ldd	r16, Y+0		;;;  2 Get Current Head
	ldd	r17, Y+1		;;;  2
	std	Y+0, r22		;;;  1 Put Packet Address to Head
	std	Y+1, r23		;;;  1
	movw	yh:yl, r23:r22		;;;  1 Copy Packet Address
	std	Y+0, r16		;;;  1 Put previous Head to Packet
	std	Y+1, r17		;;;  1
	sei
	pop	yh
	pop	yl
	ret
;
; given the address of a list, remove a list element and return it or
;
; second entry point -> if null that's a fatal error
;
;	Input:
;	r25:r24		head
;
;	Output:
;	r25:r24		packet
;
deqhead:
	clt				; Don't die if no list element
	cpse	r0,r0			; skip next instruction
deqfhead:
	set				; Die if no list element
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	cli
	ldd	r24, Y+0		;;;  2 Get Packet from Head
	ldd	r25, Y+1		;;;  2
	sbiw	r25:r24, 0		;;;  2
	breq	deqfhead090		;;;  1
	movw	zh:zl, r25:r24		;;;  1 Copy Packet Address
	ldd	r16, Z+0		;;;  2 Copy packet.link
	ldd	r17, Z+1		;;;  2
	std	Y+0, r16		;;;  1 to Head
	std	Y+1, r17		;;;  1
deqfhead080:
	sei
	pop	yh
	pop	yl
	ret

deqfhead090:
	brtc	deqfhead080		; No list element and don't die
	sei
	ldi	r24, low(pe_nsr)	; No Such Resource
	ldi	r25, high(pe_nsr)
	call	fatal_error		; and die
