/*
 *  file = DOUNA.C
 *  project = RQDX3
 *  author = Stephen F. Shirron
 *
 *  the UNIT NOW AVAILABLE attention message routine
 */


recordcont	pkt, data
record		una, crf, 4		; 6.
record		una, unit, 2		; 10.
record		una, r2, 2		; 12.
record		una, opcd, 1		; 14.
record		una, r3, 1		; 15.
record		una, r4, 2		; 16.
record		una, mlun, 2		; 18.
record		una, unfl, 2		; 20.
record		una, r5, 4		; 22.
record		una, unti, 8		; 26.
record		una, medi, 4		; 34.
recordend	una, size		; 38.

.equ	es_una	= una_size - pkt_data

/*
 *  this routine handles UNIT NOW AVAILABLE attention message packets
 *
 *  The flow is simple:  if the host cares about these attention message
 *  packets, then allocate one, fill in its fields, and send it to the host.
 *  The only difficult part is in finding the unit number of the UCB in
 *  question, since there is no back-pointer; rather, a linear search must
 *  be done of the table of all known UCBs looking for a match.
 */
 
 
do_una:
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	subi	r24, low(unittable)
	sbci	r25, high(unittable)
	swap	r24
	lds	r25, unitbase
	add	r24, r25
	push	r24			; Unit
;	ldi	r24, low(pkts)
;	ldi	r25, high(pkts)
; 	call	deqf_head
	movw	zh:zl, r25:r24
	pop	r24			; Unit
	std	Z+una_crf+0, zero
	std	Z+una_crf+1, zero
	std	Z+una_crf+2, zero
	std	Z+una_crf+3, zero
	std	Z+una_unit+0, r24
	std	Z+una_unit+1, zero
	ldi	r18, op_ava
	std	Z+una_opcd, r18
	std	Z+una_mlun+0, r24
	std	Z+una_mlun+1, zero
	ldd	r16, Y+ucb_flags+0
	ldd	r17, Y+ucb_flags+1
	std	Z+una_unfl+0, r16
	std	Z+una_unfl+1, r17
	std	Z+una_unti+0, r24
	std	Z+una_unti+1, zero
	std	Z+una_unti+2, zero
	std	Z+una_unti+3, zero
	std	Z+una_unti+4, zero
	std	Z+una_unti+5, zero
	ldd	r16, Y+ucb_type+0
	ldd	r17, Y+ucb_type+1
	std	Z+una_unti+6, r16
	std	Z+una_unti+7, r17
	ldd	xl, Y+ucb_imgptr+0
	ldd	xh, Y+ucb_imgptr+1
	adiw	xh:xl, pcb_drvtab
	ld	r16, X+
	ld	r17, X+
	movw	xh:xl, r17:r16
	adiw	xh:xl, Drv_MediaID
	ld	r16, X+
	ld	r17, X+
	ld	r18, X+
	ld	r19, X+
	std	Z+una_medi+0, r16
	std	Z+una_medi+1, r17
	std	Z+una_medi+2, r18
	std	Z+una_medi+3, r19
	ldi	r16, low(es_una)
	ldi	r17, high(es_una)
	std	Z+pkt_size+0, r16
	std	Z+pkt_size+1, r17
	ldi	r18, mt_seq
	std	Z+pkt_type, r18
	ldi	r18, ct_mscp
	std	Z+pkt_connid, r18
	cli
	lds	r18, ha_flag
	inc	r18
	sts	ha_flag, r18
	sei
	movw	r25:r24, zh:zl
	call	put_packet
	pop	yh
	pop	yl
	ret

