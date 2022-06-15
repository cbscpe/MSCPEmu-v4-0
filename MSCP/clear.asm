/*
 *  this routine is called to initialize most internal data structures (since
 *  RAM is already clear, we only need to initialize non-zero stuff)
 */
 
clear:
	ldi	r18, 60
	sts	ccb_timeout, r18
	sts	pcb_timeout, r18
	ldi	r18, cf_rpl
	sts	ccb_flags, r18
	ldi	r16, mscp_model
	ldi	r17, mscp_class
	sts	ccb_type+0, r16
	sts	ccb_type+0, r17
	ldi	r18, max_commads - 1
	sts	credits, r18
	ldi	r18, 60 + 1
	sts	ha_time, r18
	sts	pkts+0, zero
	sts	pkts+1, zero
	sts	unitbase+0, zero
	sts	unitbase+1, zero

	push	r15
	ldi	r16, max_packets - 1
	r15
clear010:	
	ldi	r24, low(pkt_length)
	ldi	r25, high(pkt_length)
	call	malloc
	sbiw	r25:r24, 0
	breq	clear090
	movw	r23:r22, r25:r24
	ldi	r24, low(pkts)
	ldi	r25, high(pkts)
	call	enqhead
	dec	r15
	brpl	clear010
	pop	r15
	ret

clear090:
	ldi	r24, low(pe_nsr)
	ldi	r25, high(pe_nsr)
	call	fatalerror
