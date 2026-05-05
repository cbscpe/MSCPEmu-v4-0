;
;	For the disk emulator this translates into the following
;	--------------------------------------------------------
;
;	process an ONLINE command
;
;	Before a host can access a unit it must execute an ONLINE command.
;	The unit must actually exist and it must not be offline. 
;
;	For a unit to exist it must not be lower than "unitbase" and it must not
;	be higher than "unitbase+units".
;
;	For an RQDX3 controller not offline means for a RD device the run/stop
;	butten must not be pressend and for a RX device a media must be
;	inserted and the door must be closed. 
;
;	For the Disk Emulator not offline means that it is either attached to
;	a partition or a disk image.
;
;	RQDX3 has two flags, us$onl and us$ofl. During setup() the RQDX3 will
;	probe all drive select signals (DS0...3)
; 
;	Offset definitions for error packet (used in doonl)
;
recordcont	pkt, data		;	command / response
record		onl, crf, 4		; 6.	command reference number
record		onl, unit, 2		; 10.	unit number
record		onl, r1, 2		; 12.	reserved
record		onl, opcd, 1		; 14.	opcode (9)
record		onl, flgs, 1		; 15.	reserved / flags
record		onl, sts, 2		; 16.	modifiers / status
record		onl, mlun, 2		; 18.	reserved / multi unit code
record		onl, unfl, 2		; 20.	unit flags
record		onl, r2, 4		; 22.	reserved
record		onl, unti, 8		; 26.	reserved / unit identifier
record		onl, medi, 4		; 34.	device dependent parameters / media type identifier
record		onl, shun, 2		; 38.	reserved
record		onl, shst, 2		; 40.	reserved
record		onl, unsz, 4		; 42.		/ unit size
record		onl, vser, 4		; 46.		/ volume serial number
recordend	onl, next		; 50.

.equ	rs_onl	= onl_next - pkt_data

do_onl:					; Online

	push	yl
	push	yh
	movw	yh:yl, r25:r24
;
;	Hier den entsprechenden code einfügen
;	
	std	Y+onl_flgs, zero
	ldd	r24, Y+onl_unit+0
	ldd	r25, Y+onl_unit+1
	std	Y+onl_shun+0, r24
	std	Y+onl_shun+1, r25
	logtr	0x60, r24, r25
	call	getucb			;
	logtr	0x61, r24, r25
	adiw	r25:r24, 0
	breq	do_onl010		; Set Offline
;
;	Get UCB status and check if the unit is attached to a disk image
;
	movw	zh:zl, r25:r24
	ldd	r16, Z+ucb_status	;
	sbrc	r16, ucb__part		; Attached to Partition?
	rjmp	do_onl020		; yes
	sbrc	r16, ucb__file		; Attached to File?
	rjmp	do_onl020		; yes
;
;	Either we did not find a UCB or the unit is not attached to a disk image
;
do_onl010:
	ldi	r24, low(st_ofl)
	ldi	r25, high(st_ofl)
	std	Y+onl_sts+0, r24
	std	Y+onl_sts+1, r25
	rjmp	do_onl900
;
;	The unit exists and is attached to a disk
;
do_onl020:
	bst	r16, ucb__onl		; Save current online status
	ori	r16, (1<<ucb__onl)
	std	Z+ucb_status, r16	; Set Online bit
	ldi	r24, low(st_suc)
	ldi	r25, high(st_suc)
	brtc	do_onl030
	ori	r24, low(st_sub * 8)
	ori	r25, high(st_sub * 8)
do_onl030:
	std	Y+onl_sts+0, r24
	std	Y+onl_sts+1, r25	; 

	logtr	0x62, r24, r25

	ldd	r24, Y+onl_unit+0
	ldd	r25, Y+onl_unit+1

	std	Y+onl_mlun+0, r24
	std	Y+onl_mlun+1, r25
	std	Y+onl_unti+0, r24
	std	Y+onl_unti+1, r25
	std	Y+onl_unti+2, zero
	std	Y+onl_unti+3, zero
	std	Y+onl_unti+4, zero
	std	Y+onl_unti+5, zero
	ldi	r24, low(rd_type)
	ldi	r25, high(rd_type)
	std	Y+onl_unti+6, r24
	std	Y+onl_unti+7, r25
	
	ldi	r20, byte1(rd_media)
	ldi	r21, byte2(rd_media)
	ldi	r22, byte3(rd_media)
	ldi	r23, byte4(rd_media)
	std	Y+onl_medi+0, r20
	std	Y+onl_medi+1, r21
	std	Y+onl_medi+2, r22
	std	Y+onl_medi+3, r23
	
	ldd	r18, Z+ucb_imgptr+0
	ldd	r19, Z+ucb_imgptr+1

	movw	zh:zl, r19:r18
	sbrs	r16, ucb__part
	rjmp	do_onl040
;
;	Unit is attached to a paritition, so we copy partition size to unit size
;
	ldd	r20, Z+pcb_sectors+0
	ldd	r21, Z+pcb_sectors+1
	ldd	r22, Z+pcb_sectors+2
	ldd	r23, Z+pcb_sectors+3
	rjmp	do_onl050
;
;
;
do_onl040:
	ldd	r20, Z+fcb_filesize+0
	ldd	r21, Z+fcb_filesize+1
	ldd	r22, Z+fcb_filesize+2
	ldd	r23, Z+fcb_filesize+3

do_onl050:
	std	Y+onl_unsz+0, r20
	std	Y+onl_unsz+1, r21
	std	Y+onl_unsz+2, r22
	std	Y+onl_unsz+3, r23

	std	Y+onl_vser+0, zero
	std	Y+onl_vser+1, zero
	std	Y+onl_vser+2, zl
	std	Y+onl_vser+3, zh
	
do_onl900:
	ldd	r16, Y+onl_opcd
	ori	r16, op_end
	std	Y+onl_opcd, r16
	ldi	r24, low(rs_onl)
	ldi	r25, high(rs_onl)
	std	Y+pkt_size+0, r24
	std	Y+pkt_size+1, r25
	ldi	r16, mt_seq
	std	Y+pkt_type, r16
	movw	r25:r24, yh:yl
	call	put_packet
	pop	yh
	pop	yl
	ret
