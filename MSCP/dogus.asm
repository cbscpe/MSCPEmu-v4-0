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
record		gus, grp, 2			; 46.		/ volume serial number
record		gus, cyl, 2			; 50.
record		gus, usvr, 1			; 52.
record		gus, uhvr, 1			; 53.
record		gus, rcts, 2			; 54.
record		gus, rbns, 1			; 56.
record		gus, rctc, 1			; 57.
recordend	rs, gus

do_gus:					; Get Unit Status
	push	yl
	push	yh
	movw	yh:yl, r25:r24
;
;	Get Unit Number and Command Modifiers
;	
	std	Y+rsp_flgs, zero
	ldd	r24, Y+cmd_unit+0
	ldd	r25, Y+cmd_unit+1
	ldd	r18, Y+cmd_mod+0	; need low-byte
	sbrs	r18, md_nxu		; request next unit
	rjmp	do_gus020
;
;	Next Unit Modifier
;	Return the next known unit >= cmd_unit unless cmd_unit is 
;	greater than the number of drives we support
;
	lds	r18, unitbase+0
	lds	r19, unitbase+1
	cp	r24, r18
	cpc	r25, r19
	brsh	do_gus005
	movw	r25:r24, r19:r18
do_gus005:
	subi	r18, low(-units)
	sbci	r19, high(-units)
	cp	r24, r18
	cpc	r25, r19
	brsh	do_gus010
	call	getucb
	sbiw	r25:r24, 0
	brne	do_gus015
do_gus010:
	clr	r24
	clr	r25

do_gus015:
	std	Y+cmd_unit+0, r24
	std	Y+cmd_unit+1, r25
do_gus020:

	call	getucb
	sbiw	r25:r24, 0
	brne	do_gus030
	ldi	r16, low(st_ofl)
	ldi	r17, high(st_ofl)
	std	Y+gus_sts+0, r16
	std	Y+gus_sts+1, r17
	rjmp	do_gus070
do_gus030:
	ldd	r18, Z+ucb_status	; Get Unit status	
	andi	r18, (1<<ucb__part) | (1<<ucb__file)
	brne	do_gus040
	ldi	r16, low(st_ofl + st_sub)
	ldi	r17, high(st_ofl + st_sub)
	std	Y+gus_sts+0, r16
	std	Y+gus_sts+1, r17
	rjmp	do_gus050
do_gus040:
	ldi	r16, low(st_suc)
	ldi	r17, high(st_suc)
	std	Y+gus_sts+0, r16
	std	Y+gus_sts+1, r17
	
do_gus050:
;
;	As always the unit number is directly linked to an offset into
;	the unittable. For each unit we have reserved 16-bytes of basic
;	information.
;
	
	ldd	xl, Z+ucb_imgptr+0
	ldd	xh, Z+ucb_imgptr+1
	movw	zh:zl, xh:xl
	ldd	xl, Z+pcb_drvtab+0
	ldd	xh, Z+pcb_drvtab+1
	
	movw	zh:zl, xh:xl
	
;
;	Set units first as long as r17:r16 is valid
;
	std	Y+gus_unti+0, r16	; unit
	std	Y+gus_unti+1, r17
	std	Y+gus_shun+0, r16	; shadow unit
	std	Y+gus_shun+1, r17
	std	Y+gus_mlun+0, r16
	std	Y+gus_mlun+1, r17
;
;
;
	std	Y+gus_unfl+0, zero
	std	Y+gus_unfl+1, zero
	std	Y+gus_unti+2, zero
	std	Y+gus_unti+3, zero
	std	Y+gus_unti+4, zero
	std	Y+gus_unti+5, zero
	std	Y+gus_unti+6, zero	; UCB.type
	std	Y+gus_unti+7, zero

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
	ldd	r16, Z+Drv_RCTSize+1
	std	Y+gus_rcts+0, r16	; RCT Size
	std	Y+gus_rcts+1, r17
	ldi	r16, 1
	std	Y+gus_rbns, r16		; Number of RBN
	std	Y+gus_rctc, r16		; Number of RCT
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

do_gus070:	
	
	movw	r25:r24, yh:yl
	call	put_packet
	pop	yh
	pop	yl
	ret

