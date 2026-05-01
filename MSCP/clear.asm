/*
 *  this routine is called to initialize most internal data structures (since
 *  RAM is already clear, we only need to initialize non-zero stuff)
 */
 
clear:
	ldi	r18, 60
	sts	_ccb_timeout, r18
	sts	_pcb_timeout, r18
	ldi	r17, low(cf_rpl)
	ldi	r18, high(cf_rpl)
	sts	_ccb_flags+0, r17
	sts	_ccb_flags+1, r18
	ldi	r16, mscp_model
	ldi	r17, mscp_class
	sts	_ccb_type+0, r16
	sts	_ccb_type+0, r17
	ldi	r18, max_commands - 1
	sts	credits, r18
	ldi	r18, 60 + 1
	sts	ha_time, r18
	sts	pkts+0, zero
	sts	pkts+1, zero
	sts	unitbase+0, zero
	sts	unitbase+1, zero

	push	r15
	ldi	r16, max_packets - 1
	mov	r15, r16
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
	;call	fatalerror

;
;
;
mscp_reset:
	ldi	zl, low(cmd)
	ldi	zh, high(cmd)
	ldi	yl, ring_sz
	clr	yh
mscp_reset010:
	st	Z+, yh
	dec	yl
	brne	mscp_reset010
;
;
;
	ldi	zl, low(rsp)
	ldi	zh, high(rsp)
	ldi	yl, ring_sz
	clr	yh
mscp_reset020:
	st	Z+, yh
	dec	yl
	brne	mscp_reset020
;
;
;
	ldi	yh, mscp_init
	sts	mscpstatus, yh
	
;
; Reset drives 
;
	lds	zh, unittable+ucb_size*0+ucb_status+0
	cbr	zh, (1<<ucb__onl) | (1<<ucb__ofl)
	sts	unittable+ucb_size*0+ucb_status+0, zh

	lds	zh, unittable+ucb_size*1+ucb_status+0
	cbr	zh, (1<<ucb__onl) | (1<<ucb__ofl)
	sts	unittable+ucb_size*1+ucb_status+0, zh

	lds	zh, unittable+ucb_size*2+ucb_status+0
	cbr	zh, (1<<ucb__onl) | (1<<ucb__ofl)
	sts	unittable+ucb_size*2+ucb_status+0, zh

	lds	zh, unittable+ucb_size*3+ucb_status+0
	cbr	zh, (1<<ucb__onl) | (1<<ucb__ofl)
	sts	unittable+ucb_size*3+ucb_status+0, zh
	ret
