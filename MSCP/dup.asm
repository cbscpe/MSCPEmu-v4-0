/*
 *  this routine will process active packets
 *
 *  This routine is called in two places:  from the POLL routine whenever a
 *  packet is received which has a connection identifier of "DUP", and from
 *  the SEND DATA and RECEIVE DATA routines when running down a list of PKTs
 *  (from the PCB.pkts field) which needs to be reparsed after having been
 *  initially deferred.  If a matching opcode is found, then the associated
 *  action routine is invoked, else an "invalid command" status is returned.
 */

do_dup:
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldd	zl, Y+cmd_opcd		; 016 (octal see rqdx3.das)
	cpi	zl, 0x07		;
	brsh	do_ill
	clr	zh
	subi	zl, low(-dup_tbl)
	sbci	zh, high(-dup_tbl)
	ijmp


dup_tbl:
	rjmp	do_ill			;
	rjmp	do_gds
	rjmp	do_esp
	rjmp	do_elp
	rjmp	do_snd
	rjmp	do_rcv
	rjmp	do_ap
	rjmp	do_ill


do_ill:
	ldi	r16, low(st_cmd + i_opcd)
	ldi	r17, high(st_cmd + i_opcd)
	std	Y+rsp_sts+0, r16
	std	Y+rsp_sts+1, r17
/*
 *	There are no user programs available for the moment perhaps a 
 *
 *
 */
do_gds:
do_esp:
do_elp:
do_snd:
do_rcv:
do_ap:
dup_exit:
	ldi	r18, op_end
	std	Y+rsp_opcd, r18
	ldi	r16, low(rs_min)
	ldi	r17, high(rs_min)
	std	Y+pkt_size+0, r16
	std	Y+pkt_size+1, r17
	ldi	r18, mt_seq
	std	Y+pkt_type, r18
	movw	r25:r24, yh:yl
	call	put_packet	
	pop	yh
	pop	yl
	ret

	
	
