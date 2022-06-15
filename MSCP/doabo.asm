;
;	do_abo( pkt )
;

;
;	Offset definitions for error packet (used in doplf)
;
recordcont	pkt, data
record		abo, crf, 4		; 6.
record		abo, unit, 2		; 10.
record		abo, r1, 2		; 12.
record		abo, opcd, 1		; 14.
record		abo, flgs, 1		; 15.	
record		abo, sts, 2		; 16.
record		abo, otrf, 4		; 18.
recordend	abo, next		; 38.

.equ	rs_abo	= abo_next - pkt_data

;
;	As we execute all commands sequentially this is more or less a no-op
;	and always successfull
;
do_abo:
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	std	Y+abo_flgs, zero
	ldi	r16, low(st_suc)
	ldi	r17, high(st_suc)
	std	Y+abo_sts+0, r16
	std	Y+abo_sts+1, r17
	ldd	r18, Y+abo_opcd
	ori	r18, op_end
	std	Y+abo_opcd, r18
	ldi	r16, low(rs_abo)
	ldi	r17, high(rs_abo)
	std	Y+pkt_size+0, r16
	std	Y+pkt_size+1, r17
	ldi	r18, mt_seq
	std	Y+pkt_type, r18
	movw	r25:r24, yh:yl
	call	put_packet
	pop	yh
	pop	yl
	ret

