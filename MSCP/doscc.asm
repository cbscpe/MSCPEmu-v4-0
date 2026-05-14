/*
 *  process a SET CONTROLLER CHARACTERISTICS command
 *
 *  This is a sequential command, but since it changes no state which other
 *  non-sequential commands depend on, it can be considered to be a non-
 *  sequential command (thus we don't have to synchronize with anything else).
 *  The only characteristics that the host can modify are the host timeout
 *  value and a couple of this-kind-of-error-log-desired flags (pretty simple,
 *  huh?).
 */
;
;	Offset definitions for error packet (used in doplf)
;
recordcont	pkt, data		;	command / response
record		scc, crf, 4		; 6.	command reference number
record		scc, r1, 4		; 10.	reserved 
record		scc, opcd, 1		; 14.	opcode (4)
record		scc, flgs, 1		; 15.	reserved / flags
record		scc, sts, 2		; 16.	modifiers / status
record		scc, vrsn, 2		; 18.	MSCP Version
record		scc, cntf, 2		; 20.	Controller Flags
record		scc, htmo, 0		; 22.
record		scc, ctmo, 2		; 22.	Host Timeout / Controller Timeout
record		scc, csvr, 1		; 24.	reserved
record		scc, chvr, 1		; 25.	reserved
record		scc, cnti, 8		; 26.	controller id
record		scc, mcnt, 4		; 34.
recordend	scc, next		; 38.

.equ	rs_scc	= scc_next - pkt_data


do_scc:					; Set Controller Characteristics
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldd	r24, Y+scc_vrsn+0
	ldd	r25, Y+scc_vrsn+1
	sbiw	r25:r24, 0
	breq	do_scc010
	std	Y+scc_opcd, zero
	ldi	r24, st_cmd
	ldi	r25, i_vrsn
	std	Y+scc_sts+0, r24
	std	Y+scc_sts+1, r25
	rjmp	do_scc900
;
;	get the timeout value and the controller flags, and return
;	stuff like version numbers and controller identifiers
;
do_scc010:
	ldi	r24, low(st_suc)	; Return Success
	ldi	r25, high(st_suc)
	std	Y+suc_sts+0, r24
	std	Y+suc_sts+1, r25
	
	ldd	r24, Y+scc_htmo+0	; Get Host Timeout Value
	ldd	r25, Y+scc_htmo+1
	sbiw	r25:r24, 0		; If not 0 
	breq	do_scc020		
	adiw	r25:r24, 2		; Set  Controller Timeout = Host Timeout +2
do_scc020:
	sts	_ccb_timeout+0, r24	; Set controller timeout
	sts	_ccb_timeout+1, r25
	lds	r24, _ccb_flags+0	; Get Controller Flags
	lds	r25, _ccb_flags+1
	andi	r24, low(cf_rpl)	;
	andi	r25, high(cf_rpl)
	ldd	r22, Y+scc_cntf+0
	ldd	r23, Y+scc_cntf+1
	andi	r22, low(cf_msk)
	andi	r23, high(cf_msk)
	or	r24, r22
	or	r25, r23
	sts	_ccb_flags+0, r24
	sts	_ccb_flags+1, r25	
	ldi	r24, low(120)
	ldi	r25, high(120)
	std	Y+scc_ctmo+0, r24
	std	Y+scc_ctmo+1, r25
	ldi	r24, 0x03;low(mscp_softv)
	ldi	r25, 0x01;high(mscp_hardv)
	std	Y+scc_csvr, r24
	std	Y+scc_chvr, r25
	std	Y+scc_cnti+0, zero
	std	Y+scc_cnti+1, zero
	std	Y+scc_cnti+2, zero
	std	Y+scc_cnti+3, zero
	std	Y+scc_cnti+4, zero
	std	Y+scc_cnti+5, zero
	lds	r24, _ccb_type
	lds	r25, _ccb_type
	ldi	r24, 0x13		; model
	ldi	r25, 0x01		; class
	std	Y+scc_cnti+6, r24
	std	Y+scc_cnti+7, r25
	std	Y+scc_mcnt+0, zero
	std	Y+scc_mcnt+1, zero
;
;	Comparison of response sent by simh to our solution * marks differences
;
/*

                                           Emulator	simh		offset	description
0x721C Trace ID 0x90, Bytes 0x20 0x00 Word 000040	0x0020		 2.	Message Length
0x7220 Trace ID 0x9F, Bytes 0x00 0x00 Word 000000	0x0000		 4.	Credits / Message Type / Connection ID
0x7224 Trace ID 0x9F, Bytes 0x01 0x00 Word 000001	0x0001		 6.	CRF Low
0x7228 Trace ID 0x9F, Bytes 0xD0 0x26 Word 023320	0x26d0		 8.	CRF High
0x722C Trace ID 0x9F, Bytes 0x03 0x00 Word 000003	0x0003		10.	reserved
0x7230 Trace ID 0x9F, Bytes 0x00 0x00 Word 000000	0x0000		12.	reserved
0x7234 Trace ID 0x9F, Bytes 0x84 0x00 Word 000204	0x0084		14.	opcode
0x7238 Trace ID 0x9F, Bytes 0x00 0x00 Word 000000	0x0000		16.	status
0x723C Trace ID 0x9F, Bytes 0x00 0x00 Word 000000	0x0000		18.	mscp version
0x7240 Trace ID 0x9F, Bytes 0xD0 0x00 Word 000320	0x80d0*!	20.	controller flags
0x7244 Trace ID 0x9F, Bytes 0x78 0x00 Word 000170	0x0078		22.	host time-out / controller time-out
0x7248 Trace ID 0x9F, Bytes 0x02 0x00 Word 000002	0x0103*!	24.	Controller Software Version
0x724C Trace ID 0x9F, Bytes 0x00 0x00 Word 000000	0x0000		26.	controller ID A
0x7250 Trace ID 0x9F, Bytes 0x00 0x00 Word 000000	0x0000		28.	controller ID B
0x7254 Trace ID 0x9F, Bytes 0x00 0x00 Word 000000	0x0000		30.	controller ID C
0x7258 Trace ID 0x9F, Bytes 0x02 0x01 Word 000402	0x0113*!	32.	controller ID D
0x725C Trace ID 0x9F, Bytes 0x00 0x00 Word 000000	0x0000		34.	max byte count
0x7260 Trace ID 0x9F, Bytes 0x00 0x00 Word 000000	0x0000


*/
	ldi	r24, low(cf_rpl | cf_atn | cf_msc | cf_ths)
	ldi	r25, high(cf_rpl | cf_atn | cf_msc | cf_ths)
	std	Y+scc_cntf+0, r24
	std	Y+scc_cntf+1, r25

;
;
;
do_scc900:
	ldd	r24, Y+scc_opcd
	ori	r24, op_end
	std	Y+scc_opcd, r24
	ldi	r24, low(rs_scc)
	ldi	r25, high(rs_scc)
	std	Y+pkt_size+0, r24
	std	Y+pkt_size+1, r25
	ldi	r16, mt_seq
	std	Y+pkt_type, r16

	movw	xh:xl, yh:yl
	adiw	xh:xl, 2		; no need to logg the link word
	ld	r16, X+
	ld	r17, X+
	logtr	0x90, r16, r17
	ld	r16, X+
	ld	r17, X+
	logtr	0x9F, r16, r17
do_scc910:
	ld	r16, X+
	ld	r17, X+
	logtr	0x9F, r16, r17
	sbiw	r25:r24, 2
	brne	do_scc910

	movw	r25:r24, yh:yl
	call	put_packet
	pop	yh
	pop	yl
	ret

