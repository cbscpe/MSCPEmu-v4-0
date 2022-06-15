;--------------------------------------------------------------------------
;
;	process a GET COMMAND STATUS command
;
;	As we execute all commands sequentially this will always return zero.
;

do_gcs:					; Get Controller Status
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	std	Y+rsp_flgs, zero
	ldi	r16, low(st_suc)
	ldi	r17, high(st_suc)
	std	Y+rsp_sts+0, r16
	std	Y+rsp_sts+1, r17

	std	Y+rsp_cmst+0, zero
	std	Y+rsp_cmst+1, zero
	std	Y+rsp_cmst+2, zero
	std	Y+rsp_cmst+3, zero

	ldd	r18, Y+cmd_opcd
	ori	r18, op_end
	std	Y+rsp_opcd, r18
	ldi	r16, low(rs_gcs)
	ldi	r17, high(rs_gcs)
	std	Y+pkt_size+0, r16
	std	Y+pkt_size+1, r17
	
	ldi	r18, mt_seq
	std	Y+pkt_type, r18
	movw	r25:r24, yh:yl
	call	put_packet
	pop	yh
	pop	yl
	ret
