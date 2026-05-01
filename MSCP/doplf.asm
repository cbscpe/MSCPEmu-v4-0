/*
 *  this routine handles PORT LAST FAILURE error log packets
 *
 *  The flow is simple:  if an error occurred during a previous incarnation,
 *  then allocate an error log packet, fill in its fields (including the
 *  previous SA error code), and send it to the host.  This is the only packet
 *  sent to the host with a packet connection identifier of "diagnostic".
 */


;
;	Offset definitions for error packet (used in doplf)
;
recordcont	pkt, data
record		plf, crf, 4		; 6.
record		plf, unit, 2		; 10.
record		plf, seq, 2		; 12.
record		plf, fmt, 1		; 14.
record		plf, flgs, 1		; 15.	
record		plf, evnt, 2		; 16.
record		plf, cnti, 8		; 18.
record		plf, csvr, 1		; 26.
record		plf, chvr, 1		; 27.
record		plf, perr, 2		; 28.
recordend	plf, next		; 30.

.equ	es_plf	= plf_next - pkt_data


;
;	Port Last Failure
;
do_plf:
	push	yl
	push	yh

	push	r24
	push	r25			; Save error code

;	ldi	r24, low(pkts)
;	ldi	r25, high(pkts)
;	call	deqf_head
	movw	yh:yl, r25:r24

	std	Y+plf_crf+0, zero
	std	Y+plf_crf+1, zero
	std	Y+plf_crf+2, zero
	std	Y+plf_crf+3, zero

	std	Y+plf_unit+0, zero
	std	Y+plf_unit+1, zero

	std	Y+plf_seq+0, zero
	std	Y+plf_seq+1, zero

	ldi	r18, fm_cnt
	std	Y+plf_fmt, r18
	
	ldi	r18, lf_snr
	std	Y+plf_flgs, r18
	
	ldi	r16, low(st_cnt)
	ldi	r17, high(st_cnt)
	std	Y+plf_evnt, r16
	std	Y+plf_evnt, r17

	lds	r18, _ccb_type
	std	Y+plf_cnti+0, zero
	std	Y+plf_cnti+1, zero
	std	Y+plf_cnti+2, zero
	std	Y+plf_cnti+3, r18

	ldi	r18, mscp_softv
	std	Y+plf_csvr, r18
	ldi	r18, mscp_hardv
	std	Y+plf_chvr, r18
	
	pop	r17
	pop	r16			; Restore error code
	std	Y+plf_perr+0, r24
	std	Y+plf_perr+1, r25
	
	ldi	r16, low(es_plf)
	ldi	r17, high(es_plf)
	std	Y+pkt_size+0, r16
	std	Y+pkt_size+1, r17
	
	ldi	r18, ct_diag
	std	Y+pkt_connid, r18
	
	lds	r18, ha_flag
	inc	r18
	sts	ha_flag, r18

	movw	r25:r24, yh:yl
	call	put_packet
	
	pop	yh
	pop	yl
	ret	
	

