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

/*
DBG(136791432)> RQ TRACE: txt=0020, 0000, 0000, 0000, 0000, 0000, 0084, 0000
DBG(136791432)> RQ TRACE: txt=0000, 8000, 0078, 0103, 0000, 0000, 0000, 0113
DBG(136791432)> RQ TRACE: txt=0000, 0000, 0000, 0000, 0000, 0000, 0000, 0000

0x74B4 Trace ID 0x90, Bytes 0x20 0x00 Word 000040	0020
0x74B8 Trace ID 0x9F, Bytes 0x00 0x00 Word 000000	0000

0x74BC Trace ID 0x9F, Bytes 0x00 0x00 Word 000000	0000	command reference number
0x74C0 Trace ID 0x9F, Bytes 0x00 0x00 Word 000000	0000
0x74C4 Trace ID 0x9F, Bytes 0x00 0x00 Word 000000	0000	reserved
0x74C8 Trace ID 0x9F, Bytes 0x00 0x00 Word 000000	0000
0x74CC Trace ID 0x9F, Bytes 0x84 0x00 Word 000204	0084	opcode / flags
0x74D0 Trace ID 0x9F, Bytes 0x00 0x00 Word 000000	0000	status
0x74D4 Trace ID 0x9F, Bytes 0x00 0x00 Word 000000	0000	version
0x74D8 Trace ID 0x9F, Bytes 0xD0 0x80 Word 100320	8000	controller flags
0x74DC Trace ID 0x9F, Bytes 0x78 0x00 Word 000170	0078	controller timeout
0x74E0 Trace ID 0x9F, Bytes 0x03 0x01 Word 000403	0103	software / hardware version
0x74E4 Trace ID 0x9F, Bytes 0x00 0x00 Word 000000	0000	controller id
0x74E8 Trace ID 0x9F, Bytes 0x00 0x00 Word 000000	0000
0x74EC Trace ID 0x9F, Bytes 0x00 0x00 Word 000000	0000
0x74F0 Trace ID 0x9F, Bytes 0x13 0x01 Word 000423	0113
0x74F4 Trace ID 0x9F, Bytes 0x00 0x00 Word 000000	0000	maximum byte count
0x74F8 Trace ID 0x9F, Bytes 0x00 0x00 Word 000000	0000

 */

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
	andi	r22, low(cf_msk)	; Only flags that can be set by the host
	andi	r23, high(cf_msk)
	or	r24, r22
	or	r25, r23
	sts	_ccb_flags+0, r24
	sts	_ccb_flags+1, r25	;  Set Controller Flags
	ldi	r24, low(120)
	ldi	r25, high(120)
	std	Y+scc_ctmo+0, r24
	std	Y+scc_ctmo+1, r25	; 
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
;	ldi	r24, low(cf_rpl | cf_atn | cf_msc | cf_ths)
;	ldi	r25, high(cf_rpl | cf_atn | cf_msc | cf_ths)
	ldi	r24, low(cf_rpl)
	ldi	r25, high(cf_rpl)
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

