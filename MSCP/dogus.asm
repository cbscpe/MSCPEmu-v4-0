/*
 *  process a GET UNIT STATUS command
 *
 *  This is a sequential command, but since it changes no state, and no non-
 *  sequential commands change state either, we can treat it as if it were
 *  not.  If the "next unit" modifier is set, then what is being inquired
 *  about is either this unit number or the next higher unit number which
 *  exists (and if no more unit numbers exist, wrap the unit number around to
 *  zero).  The command status returned can be either "offline" (for units
 *  which don't exist) "offline, no volume mounted" (for units which have the
 *  run/stop button set to stop or which have no media present), "available"
 *  (for units which could be online but aren't), or "success" (for units
 *  which are currently online to a host).
 */


recordcont	pkt, data			;	command / response
record		gus, crf, 4			; 6.	command reference number
record		gus, unit, 2			; 10.	unit number
record		gus, r1, 2			; 12.	reserved
record		gus, opcd, 1			; 14.	opcode (9)
record		gus, flgs, 1			; 15.	reserved / flags
record		gus, sts, 2			; 16.	modifiers / status
record		gus, mlun, 2			; 18.	reserved / multi unit code
record		gus, unfl, 2			; 20.	unit flags
record		gus, r2, 4			; 22.	reserved
record		gus, unti, 8			; 26.	reserved / unit identifier
record		gus, medi, 4			; 34.	device dependent parameters / media type identifier
record		gus, shun, 2			; 38.	reserved
record		gus, shst, 2			; 40.	reserved
record		gus, trk, 2			; 42.		/ unit size
record		gus, grp, 2			; 44.		/ volume serial number
record		gus, cyl, 2			; 46.
record		gus, usvr, 1			; 48.
record		gus, uhvr, 1			; 49.
record		gus, rcts, 2			; 50.
record		gus, rbns, 1			; 52.
record		gus, rctc, 1			; 53.
recordend	gus, next			; 54.

.equ	rs_gus	= gus_next - pkt_data


.def	unitl	= r12			; Unit
.def	unith	= r13
.def	ucbl	= r14			; UCB Address
.def	ucbh	= r15


do_gus:					; Get Unit Status
	push	yl
	push	yh
	movw	yh:yl, r25:r24
;
;	Get Unit Number and Command Modifiers
;	
	ldd	unitl, Y+cmd_unit+0	; unit = CMD.p_unit;
	ldd	unith, Y+cmd_unit+1
	std	Y+gus_flgs, zero	; RSP.p_flgs = 0.;
	ldd	r18, Y+cmd_mod+0	; need low-byte
	sbrs	r18, md_nxu_bp		; request next unit
	rjmp	do_gus020
;
;	Next Unit Modifier
;	Return the next known unit >= cmd_unit unless cmd_unit is 
;	greater than the number of drives we support
;
	logtr	0x43, unitl, unith
	lds	r18, unitbase+0		; if( unit < unit_base )
	lds	r19, unitbase+1		;     unit = unit_base;
	cp	unitl, r18
	cpc	unith, r19
	brsh	do_gus005
	movw	unith:unitl, r19:r18
do_gus005:
	logtr	0x4F, unitl, unith
	subi	r18, low(-units)	; if ( (unit > unit_base+3)
	sbci	r19, high(-units)
	cp	unitl, r18
	cpc	unith, r19
	brsh	do_gus010
	movw	r25:r24, unith:unitl
	call	getucb
	sbiw	r25:r24, 0		;  || (get_ucb( unit ) == null) )
	brne	do_gus015
do_gus010:
	clr	unitl			;  unit = 0;
	clr	unith
do_gus015:
	logtr	0x4F, unitl, unith
	std	Y+gus_unit+0, unitl	;  RSP.p_unit = unit;
	std	Y+gus_unit+1, unith
;
;
;
do_gus020:
	logtr	0x44, unitl, unith
	movw	r25:r24, unith:unitl
	call	getucb
	logtr	0x4F, r24, r25
	sbiw	r25:r24, 0		; if( ( ucb = get_ucb( unit ) ) == null) 
	brne	do_gus030
;
;	Unit does not exist
;
	ldi	r16, low(st_ofl)	;   RSP:P_sts = st_ofl;
	ldi	r17, high(st_ofl)
	std	Y+gus_sts+0, r16
	std	Y+gus_sts+1, r17
	clr	unitl
	clr	unith
	std	Y+gus_unit+0, unitl	;  RSP.p_unit = unit;
	std	Y+gus_unit+1, unith
	rjmp	do_gus060
;
;	Unit exists, check the status and always return
;
do_gus030:				; else
	movw	zh:zl, r25:r24		; 
	ldd	r18, Z+ucb_status	; if( UCB.state & us_ofl) /* not attached */ 
	sbrc	r18, ucb__part		
	rjmp	do_gus040
	sbrc	r18, ucb__file
	rjmp	do_gus040
	ldi	r16, low(st_ofl + (st_sub * sb_ofl_nv))	; RSP.p_sts = st_ofl+ st_sub * sb_ofl_nv
	ldi	r17, high(st_ofl + (st_sub * sb_ofl_nv))
	std	Y+gus_sts+0, r16	; RSP.p_sts = st_ofl || st_sub;
	std	Y+gus_sts+1, r17
	rjmp	do_gus060
do_gus040:
	sbrc	r18, ucb__onl		; else if ( !(UCB.state & us_onl) )
	rjmp	do_gus050
;
;	Unit is attached but not online -> unit is available
;
	ldi	r16, low(st_avl)	;   RSP.p_sts = st_avl;
	ldi	r17, high(st_avl)	;
	std	Y+gus_sts+0, r16
	std	Y+gus_sts+1, r17
	rjmp	do_gus055	
;
;	Unit, Next Unit or Unit 0 is valid and attached and online -> report
;
do_gus050:				; else
	ldi	r16, low(st_suc)	;   RSP.p_sts = st_suc;
	ldi	r17, high(st_suc)
	std	Y+gus_sts+0, r16
	std	Y+gus_sts+1, r17
do_gus055:
	ldd	xl, Z+ucb_imgptr+0
	ldd	xh, Z+ucb_imgptr+1
	movw	zh:zl, xh:xl
	ldd	xl, Z+pcb_drvtab+0
	ldd	xh, Z+pcb_drvtab+1
	movw	zh:zl, xh:xl	
;
;
;
	ldi	r24, low(uf_rpl | uf_rmv)
	ldi	r25, high(uf_rpl | uf_rmv)
	std	Y+gus_unfl+0, r24
	std	Y+gus_unfl+1, r25
	std	Y+gus_unti+2, zero
	std	Y+gus_unti+3, zero
	std	Y+gus_unti+4, zero
	std	Y+gus_unti+5, zero

;	std	Y+gus_unti+6, zero	; UCB.type
;	std	Y+gus_unti+7, zero

	ldi	r16, low(0x020D)
	ldi	r17, high(0x020D)
	std	Y+gus_unti+6, r16	; UCB.type
	std	Y+gus_unti+7, r17

	ldd	r16, Z+Drv_MediaID+0
	ldd	r17, Z+Drv_MediaID+1
	ldd	r18, Z+Drv_MediaID+2
	ldd	r19, Z+Drv_MediaID+3
	std	Y+gus_medi+0, r16	; Media Identifier
	std	Y+gus_medi+1, r17
	std	Y+gus_medi+2, r18
	std	Y+gus_medi+3, r19
;
;	Virtual Disk Geometry, does not make any sense for SD-Cards
;
	ldd	r16, Z+Drv_Sectors
	std	Y+gus_trk+0, r16
	std	Y+gus_trk+1, zero
	ldd	r16, Z+Drv_Tracks
	std	Y+gus_grp+0, r16
	std	Y+gus_grp+1, zero
	ldd	r16, Z+Drv_Cylinders+0
	ldd	r17, Z+Drv_Cylinders+1
	std	Y+gus_cyl+0, r16
	std	Y+gus_cyl+1, r17
	ldi	r16, mscp_softv
	std	Y+gus_usvr, r16		; Software Version
	ldi	r16, mscp_hardv
	std	Y+gus_uhvr, r16		; Hardware Version
	ldd	r16, Z+Drv_RCTSize+0	; RCT Size
	ldd	r17, Z+Drv_RCTSize+1
	std	Y+gus_rcts+0, r16	; RCT Size
	std	Y+gus_rcts+1, r17
	ldi	r16, 1
	std	Y+gus_rbns, r16		; Number of RBN
	std	Y+gus_rctc, r16		; Number of RCT
;
;	
;
do_gus060:
	std	Y+gus_unti+0, unitl	; unit
	std	Y+gus_unti+1, unith
	std	Y+gus_mlun+0, unitl
	std	Y+gus_mlun+1, unith
;
;
do_gus070:	
	std	Y+gus_shun+0, unitl	; shadow unit
	std	Y+gus_shun+1, unith
	std	Y+gus_shst+0, zero
	std	Y+gus_shst+1, zero
	ldd	r18, Y+cmd_opcd
	ori	r18, op_end
	std	Y+gus_opcd, r18
	ldi	r24, low(rs_gus)
	ldi	r25, high(rs_gus)
	std	Y+pkt_size+0, r24
	std	Y+pkt_size+1, r25
	ldi	r16, mt_seq
	std	Y+pkt_type, r16
;
;
;
	movw	xh:xl, yh:yl
	adiw	xh:xl, 2		; no need to logg the link word
	ld	r16, X+
	ld	r17, X+
	logtr	0x40, r16, r17
	ld	r16, X+
	ld	r17, X+
	logtr	0x4F, r16, r17
do_gus910:
	ld	r16, X+
	ld	r17, X+
	logtr	0x4F, r16, r17
	sbiw	r25:r24, 2
	brne	do_gus910
	movw	r25:r24, yh:yl
	call	put_packet
	pop	yh
	pop	yl
	ret

.undef	unitl
.undef	unith
.undef	ucbl
.undef	ucbh

/*
	.db	"RD54"
	.dd	0x25644036		; Media ID
	.dd	311200
	.dd	312377
	.dw	7			; RCT Size
	.db	17, 15
	.dw	1224
	.db	DT__IMGSZ_bm, 0

0x7D58 DATI    (88) IP (GO)  Value    000000
0x7D5C Trace ID 0x1E, Bytes 0x01 0x13 Word 011401
0x7D60 Trace ID 0x7D, Bytes 0x98 0xC4 Word 142230
0x7D64 Trace ID 0x7F, Bytes 0x00 0x00 Word 000000
0x7D68 Trace ID 0x7E, Bytes 0x03 0x03 Word 001403

0x7D6C Trace ID 0x40, Bytes 0x36 0x00 Word 000066	GUS response	2
0x7D70 Trace ID 0x4F, Bytes 0x00 0x00 Word 000000			4
0x7D74 Trace ID 0x4F, Bytes 0x00 0x00 Word 000000			6
0x7D78 Trace ID 0x4F, Bytes 0x00 0x00 Word 000000			8.
0x7D7C Trace ID 0x4F, Bytes 0x03 0x00 Word 000003			10.
0x7D80 Trace ID 0x4F, Bytes 0x00 0x00 Word 000000			12.
0x7D84 Trace ID 0x4F, Bytes 0x83 0x00 Word 000203	End Code	14.
0x7D88 Trace ID 0x4F, Bytes 0x23 0x00 Word 000043	status
0x7D8C Trace ID 0x4F, Bytes 0x23 0x00 Word 000043	multi unit code
0x7D90 Trace ID 0x4F, Bytes 0x00 0x00 Word 000000	unit flags
0x7D94 Trace ID 0x4F, Bytes 0x00 0x00 Word 000000	reserved
0x7D98 Trace ID 0x4F, Bytes 0x00 0x00 Word 000000	    *
0x7D9C Trace ID 0x4F, Bytes 0x23 0x00 Word 000043	unit identifers
0x7DA0 Trace ID 0x4F, Bytes 0x00 0x00 Word 000000	    *
0x7DA4 Trace ID 0x4F, Bytes 0x00 0x00 Word 000000	    *
0x7DA8 Trace ID 0x4F, Bytes 0x00 0x00 Word 000000	    *
0x7DAC Trace ID 0x4F, Bytes 0x00 0x00 Word 000000	media type
0x7DB0 Trace ID 0x4F, Bytes 0x83 0xB0 Word 130203	reserved
0x7DB4 Trace ID 0x4F, Bytes 0x23 0x00 Word 000043	reserved
0x7DB8 Trace ID 0x4F, Bytes 0x00 0x00 Word 000000
0x7DBC Trace ID 0x4F, Bytes 0x00 0x00 Word 000000
0x7DC0 Trace ID 0x4F, Bytes 0x00 0x00 Word 000000
0x7DC4 Trace ID 0x4F, Bytes 0x00 0x00 Word 000000
0x7DC8 Trace ID 0x4F, Bytes 0x02 0x01 Word 000402
0x7DCC Trace ID 0x4F, Bytes 0x00 0x00 Word 000000
0x7DD0 Trace ID 0x4F, Bytes 0x01 0x01 Word 000401
0x7DD4 Trace ID 0x4F, Bytes 0x00 0x00 Word 000000
0x7DD8 Trace ID 0x4F, Bytes 0x00 0x00 Word 000000
0x7DDC Trace ID 0x4F, Bytes 0x00 0x00 Word 000000
 */
