;--------------------------------------------------------------------------
;
;	Return Invalid Opcode
;	
do_new:					; New Op_code for format
do_fmt:					; For now format is an illegal command
do_default:
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ori	r18, op_end
	std	Y+rsp_opcd, r18
	std	Y+rsp_flgs, zero
	ldi	r16, low(st_cmd + i_opcd)
	ldi	r17, high(st_cmd + i_opcd)
	std	Y+rsp_sts+0, r16
	std	Y+rsp_sts+1, r17
	rjmp	do_putpacket	

;
;	Return Success for Dummy Functions
;
do_dap:
do_ccd:
do_flu:
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldd	r18, Y+cmd_opcd
	ori	r18, op_end
	std	Y+rsp_opcd, r18
	std	Y+rsp_flgs, zero
	ldi	r16, low(st_suc)
	ldi	r17, high(st_suc)
	std	Y+rsp_sts+0, r16
	std	Y+rsp_sts+1, r17

do_putpacket:
	ldi	r16, low(rs_min)
	ldi	r17, high(rs_min)
	std	Y+pkt_size+0, r16
	std	Y+pkt_size+1, r17
	movw	r25:r24, yh:yl
	call	put_packet
	pop	yh
	pop	yl
	ret
