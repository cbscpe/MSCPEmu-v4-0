/*
 *  process an AVAILABLE command
 *
 *  First of all, the unit specified must be currently online to the host; if
 *  not, the command really makes no sense.  This is a sequential command, so
 *  if there are any non-sequential commands outstanding, we must hold this
 *  command pending until they complete; if not (the UCB.tcbs list is empty),
 *  then clear any dynamic state and flags (part of the state is the online
 *  bit!), turn off the write protect light if it was on, and return success to
 *  the host.
 */

#define rs_avl rs_min

do_avl:
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	std	Y+rsp_flgs, zero
	ldd	r24, Y+cmd_unit+0
	ldd	r25, Y+cmd_unit+1
	call	getucb
	sbiw	r25:r24, 0
	breq	do_avl010
	movw	zh:zl, r25:r24
	ldd	r18, Z+ucb_status
	andi	r18, (1<<ucb__part)|(ucb__file)
	brne	do_avl020

do_avl010:
	ldi	r16, low(st_ofl)
	ldi	r17, high(st_ofl)
	std	Y+rsp_sts+0, r16
	std	Y+rsp_sts+1, r17
	rjmp	do_avl090

do_avl020:
	ldd	r18, Z+ucb_status
	cbr	r18, (1<<ucb__onl)		; Unit is no longer online
	std	Z+ucb_status, r18
	ldi	r16, low(st_suc)
	ldi	r17, high(st_suc)
	std	Y+rsp_sts+0, r16
	std	Y+rsp_sts+1, r17

do_avl090:
	ldd	r18, Y+cmd_opcd
	ori	r18, op_end
	std	Y+cmd_opcd, r18
	ldi	r16, low(rs_avl)
	ldi	r17, high(rs_avl)
	std	Y+pkt_size+0, r16
	std	Y+pkt_size+1, r17
	ldi	r18, mt_seq
	std	Y+pkt_type, r18
	movw	r25:r24, yh:yl
	call	put_packet
	pop	yh
	pop	yl
	ret

