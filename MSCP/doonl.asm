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
	;logtr	0x60, r24, r25
	call	getucb			;
	;logtr	0x61, r24, r25
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

	;logtr	0x62, r24, r25

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
	ldi	r24, 4
	ldi	r25, 2				; see comparison with simh
	std	Y+onl_unti+6, r24
	std	Y+onl_unti+7, r25
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
;	Unit is attached to a file, so we copy the file size to unit size
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

;	
;#define my_media	0x22a4103c	; RA60
;#define my_media	0x25641050	; RD54
;
;	ldi	r20, byte1(my_media)
;	ldi	r21, byte2(my_media)
;	ldi	r22, byte3(my_media)
;	ldi	r23, byte4(my_media)

	ldd	xl, Z+pcb_drvtab+0
	ldd	xh, Z+pcb_drvtab+1
	adiw	xh:xl, Drv_MediaID
	ld	r20, X+
	ld	r21, X+
	ld	r22, X+
	ld	r23, X+

	std	Y+onl_medi+0, r20
	std	Y+onl_medi+1, r21
	std	Y+onl_medi+2, r22
	std	Y+onl_medi+3, r23

#define my_serial 0x029c
	ldi	r24, low(my_serial)
	ldi	r25, high(my_serial)
	std	Y+onl_vser+0, r24
	std	Y+onl_vser+1, r25
	std	Y+onl_vser+3, zero
	std	Y+onl_vser+2, zero
;
;	Comparison of response sent by simh to our solution * marks differences
;

/*
0x726C Trace ID 0x60, Bytes 0x00 0x00 Word 000000
0x7270 Trace ID 0x61, Bytes 0x90 0x4D Word 046620
0x7274 Trace ID 0x62, Bytes 0x00 0x00 Word 000000

                                           Emulator	simh		offset	description
0x7278 Trace ID 0x80, Bytes 0x2C 0x00 Word 000054	0x002c		 2.	Message Length
0x727C Trace ID 0x8F, Bytes 0x00 0x00 Word 000000	0x0000		 4.	Credits / Message Type / Connection ID
0x7280 Trace ID 0x8F, Bytes 0x02 0x00 Word 000002	0x0002		 6.	CRF Low
0x7284 Trace ID 0x8F, Bytes 0xD0 0x26 Word 023320	0x26d0		 8.	CRF High
0x7288 Trace ID 0x8F, Bytes 0x00 0x00 Word 000000	0x0000		10.	unit number
0x728C Trace ID 0x8F, Bytes 0x00 0x00 Word 000000	0x0000		12.	reserved
0x7290 Trace ID 0x8F, Bytes 0x89 0x00 Word 000211	0x0089		14.	opcode
0x7294 Trace ID 0x8F, Bytes 0x00 0x00 Word 000000	0x0000		16.	status
0x7298 Trace ID 0x8F, Bytes 0x00 0x00 Word 000000	0x0000		18.	multi unit code
0x729C Trace ID 0x8F, Bytes 0x00 0x00 Word 000000	0x8080*!	20.	unit flags
0x72A0 Trace ID 0x8F, Bytes 0x00 0x00 Word 000000	0x0000		22.	reserved
0x72A4 Trace ID 0x8F, Bytes 0x00 0x00 Word 000000	0x0000
0x72A8 Trace ID 0x8F, Bytes 0x00 0x00 Word 000000	0x0000		26.	unit identifier
0x72AC Trace ID 0x8F, Bytes 0x00 0x00 Word 000000	0x0000
0x72B0 Trace ID 0x8F, Bytes 0x00 0x00 Word 000000	0x0000
0x72B4 Trace ID 0x8F, Bytes 0x02 0x01 Word 000402	0x0204*!	
0x72B8 Trace ID 0x8F, Bytes 0x50 0x10 Word 010120	0x103c*!	34.	media type identifier
0x72BC Trace ID 0x8F, Bytes 0x64 0x25 Word 022544	0x22a4*!
0x72C0 Trace ID 0x8F, Bytes 0x00 0x00 Word 000000	0x0000		38.	reserved
0x72C4 Trace ID 0x8F, Bytes 0x00 0x00 Word 000000	0x0000!		40.	reserved
0x72C8 Trace ID 0x8F, Bytes 0xEC 0xC3 Word 141754	0x1b30*!	42.	unit size
0x72CC Trace ID 0x8F, Bytes 0x04 0x00 Word 000004	0x0006*
0x72D0 Trace ID 0x8F, Bytes 0x00 0x00 Word 000000	0x029c		46.	volume serial number
0x72D4 Trace ID 0x8F, Bytes 0x02 0x6F Word 067402	0x0000
0x72D8 IACK    (C1) Vector  000154


4.	-------------------------------------------------------------------

DBG(9546200)> RQ REQ: cmd=0009(ONL), mod=0000, unit=0, bc=00000000, ma=00000000, lbn=00000000
DBG(9546200)> RQ TRACE: rq_mscp - Queue
DBG(9546200)> RQ TRACE: rq_onl
DBG(9546200)> RQ TRACE: rq_putr_unit
DBG(9546200)> RQ REQ: rsp=0089, sts=0000
DBG(9546200)> RQ TRACE: txt=002C, 0000, 0002, 26D0, 0000, 0000, 0089, 0000
DBG(9546200)> RQ TRACE: txt=0000, 8080, 0000, 0000, 0000, 0000, 0000, 0204
DBG(9546200)> RQ TRACE: txt=103C, 22A4, 0000, 0000, 1B30, 0006, 029C, 0000
DBG(9546200)> RQ TRACE: rq_setint
DBG(9546200)> RQ TRACE: rq_clrint
DBG(9546400)> RQ TRACE: rq_quesvc
DBG(9546617)> RQ REQ: poll started, PC=C6A6
DBG(9546817)> RQ TRACE: rq_quesvc

*/
;
;	Following we make sure things are according to simh
;
	ldi	r24, low(uf_rpl | uf_rmv)
	ldi	r25, high(uf_rpl | uf_rmv)
	std	Y+onl_unfl+0, r24
	std	Y+onl_unfl+1, r25
;
;	hard code 
;
	
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
	movw	xh:xl, yh:yl
	adiw	xh:xl, 2		; no need to logg the link word
	ld	r16, X+
	ld	r17, X+
	;logtr	0x63, r16, r17
	ld	r16, X+
	ld	r17, X+
	;logtr	0x6F, r16, r17
do_onl910:
	ld	r16, X+
	ld	r17, X+
	;logtr	0x6F, r16, r17
	sbiw	r25:r24, 2
	brne	do_onl910
	movw	r25:r24, yh:yl
	call	put_packet
	pop	yh
	pop	yl
	ret
