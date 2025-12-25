;--------------------------------------------------------------------------
;
;	Requests that access the drives are all handled in this module.
;
;	READ
;	- check parameters
;	- read data from the SD-Card
;	- write the data via DMA to the host memory
;	- put_packet()
;
;	WRITE
;	- check parameters
;	- read data via DMA from host memory
;	- write data to the SD-Card
;	- put_packet()
;
;	COMPARE
;	- check parameters
;	- read data from the SD-Card
;	- compare the data via DMA with the host memory
;	- put_packet()
;
;	ACCESS
;	- check parameters
;	- put_packet()
;
;	ERASE
;	- check parameters
;	- write 0 to the SD-Card
;	- put_packet()
;

.def	crcl	= r2
.def	crch	= r3
.def	datal	= r4			; DMA data
.def	datah	= r5
.def	bkcl	= r6
.def	bkch	= r7			; For even bigger word counts
.def	wcnt	= r8			; Word Counter
.def	count	= r9	
.def	pktl	= r10
.def	pkth	= r11
.def	addrl	= r12
.def	addrh	= r13
.def	ucbl	= r14
.def	ucbh	= r15

do_acc:
do_cmp:
do_ers:
do_rd:
do_wr:
;
;
;
	push	yl
	push	yh
	movw	zh:zl, r25:r24
	std	Z+rsp_flgs, zero

;
;	Check Parameters
;
	ldd	yl, Z+cmd_unit+0
	ldd	yh, Z+cmd_unit+1
	cpi	yl, units		; 
	cpc	yh, zero
	brlo	rwchkparam010
	;
	;	Return Status Offline
	;
	ldi	r16, low(st_ofl)	; Unit Offline
	ldi	r17, high(st_ofl)	; Unit Unknown
	std	Z+rsp_sts+0, r16
	std	Z+rsp_sts+1, r17	;
	rjmp	rwexit

rwchkparam010:
	swap	yl			; unit*16 = offset to unittable
	subi	yl, low(-unittable)
	sbci	yh, high(-unittable)	
	ldd	r18, Y+ucb_status
	sbrc	r18, ucb__drdy		; 
	rjmp	rwchkparam020
	;
	;	Return unit Available
	;
	ldi	r18, st_avl		; Unit Available
	std	Z+rsp_sts+0, r18
	std	Z+rsp_sts+1, zero	;
	rjmp	rwexit
	
	
rwchkparam020:
;
;	In mscp_server.cpp the logic is the following
;
;	- rctBlockNumber is set if LBN > disksize
;	- if LBN > disksize+RCT return i_lbn
;	- if LBN + bytecount/512. > disksize+RCT retunr i_bcnt
;	- if rctBlockNumber and bytecount != 512. retunr i_bcnt
;
;	
	ldd	r24, Y+ucb_imgptr+0
	ldd	r25, Y+ucb_imgptr+1	; 
.if ((fcb_drvtab - pcb_drvtab) != 0)
	.error " Offsets fcb_drvtab and pcb_drvtab must be equal!"
.endif
	movw	xh:xl, yh:yl		; Save ucb pointer
	movw	yh:yl, r25:r24
	ldd	r24, Y+pcb_drvtab+0
	ldd	r25, Y+pcb_drvtab+1
	movw	yh:yl, r25:r24		; 

	ldd	r20, Y+Drv_Capacity+0	; Total Diks capacity incl. RCT
	ldd	r21, Y+Drv_Capacity+1
	ldd	r22, Y+Drv_Capacity+2
	ldd	r23, Y+Drv_Capacity+3
	ldd	r24, Y+Drv_RCTSize+0
	ldd	r25, Y+Drv_RCTSize+1
	add	r20, r24
	adc	r21, r25
	adc	r22, zero
	adc	r23, zero
	ldd	r16, Z+cmd_lbn+0	; Get starting LNB
	ldd	r17, Z+cmd_lbn+1
	ldd	r18, Z+cmd_lbn+2
	ldd	r19, Z+cmd_lbn+3
	cp	r16, r20
	cpc	r17, r21
	cpc	r18, r22
	cpc	r19, r23
	brlo	rwchkparam030		; Must be lower 
	;
	;	Return Invalid Command, Subcode i_lbn
	;
	ldi	r18, st_cmd		; Invalid Command
	std	Z+rsp_sts+0, r18
	ldi	r18, i_lbn		; LBN
	std	Z+rsp_sts+1, r18	;
	rjmp	rwexit
	
rwchkparam030:				; Check for RCT
	ldd	r20, Y+Drv_Capacity+0
	ldd	r21, Y+Drv_Capacity+1
	ldd	r22, Y+Drv_Capacity+2
	ldd	r23, Y+Drv_Capacity+3
	cp	r16, r20
	cpc	r17, r21
	cpc	r18, r22
	cpc	r19, r23
	brlo	rwchkparam040		; A regular block
	
	ldd	r20, Z+cmd_bcnt+0	; We are reading a RCT block
	ldd	r21, Z+cmd_bcnt+1
	ldd	r22, Z+cmd_bcnt+2
	ldd	r23, Z+cmd_bcnt+3
	subi	r20, byte1(512)
	sbci	r21, byte2(512)
	sbci	r22, byte3(512)
	sbci	r23, byte4(512)
	breq	rwchkparam040		; In case of RCT bytecount must be 512.
	;
	;	Return Invalid Command, Subcode i_bcnt
	;
	ldi	r18, st_cmd		; Invalid Command
	std	Z+rsp_sts+0, r18
	ldi	r18, i_bcnt		; LBN
	std	Z+rsp_sts+1, r18	;
	rjmp	rwexit
	
rwchkparam040:
	
	ldd	r20, Z+cmd_bcnt+1	; Calculate the number of blocks
	ldd	r21, Z+cmd_bcnt+2	; we are reading past the first LBN
	ldd	r22, Z+cmd_bcnt+3
	lsr	r22
	ror	r21
	ror	r20
	
	add	r16, r20
	adc	r17, r21
	adc	r18, r22
	adc	r19, zero		; Last LBN we expect to read

	ldd	r20, Y+Drv_Capacity+0	; Again the whole capacity
	ldd	r21, Y+Drv_Capacity+1
	ldd	r22, Y+Drv_Capacity+2
	ldd	r23, Y+Drv_Capacity+3
	ldd	r24, Y+Drv_RCTSize+0
	ldd	r25, Y+Drv_RCTSize+1
	add	r20, r24
	adc	r21, r25
	adc	r22, zero
	adc	r23, zero
	ldd	r16, Z+cmd_lbn+0
	ldd	r17, Z+cmd_lbn+1
	ldd	r18, Z+cmd_lbn+2
	ldd	r19, Z+cmd_lbn+3
	cp	r16, r20
	cpc	r17, r21
	cpc	r18, r22
	cpc	r19, r23
	brlo	rwchkparam050		; It is within the valid range
	breq	rwchkparam050		; It is within the valid range
	;
	;	Return Invalid Command, Subcode i_bcnt
	;
	ldi	r18, st_cmd		; Invalid Command
	std	Z+rsp_sts+0, r18
	ldi	r18, i_bcnt		; LBN
	std	Z+rsp_sts+1, r18	;
	rjmp	rwexit

rwchkparam050:
;
;	Check Host Buffer
;
	ldd	r18, Z+cmd_opcd
	cpi	r18, op_ers
	breq	rwchkparam080		; not required for ERASE
	cpi	r18, op_acc
	breq	rwchkparam080		; not required for ACCESS
	ldd	r16, Z+cmd_bcnt+0
	sbrs	r16, 0			; Byte count must be even
	rjmp	rwchkparam060
	;
	;	Return Invalid Host Buffer
	;
	ldi	r16, low(st_hst+st_sub*2)
	ldi	r17, high(st_hst+st_sub*2)
	std	Z+rsp_sts+0, r16
	std	Z+rsp_sts+1, r17	;
	rjmp	rwexit
	
rwchkparam060:
	ldd	r16, Z+cmd_buff+0
	sbrs	r16, 0			; Address must be even
	rjmp	rwchkparam070
	;
	;	Return Invalid Host Buffer
	;
	ldi	r16, low(st_hst+st_sub*1)
	ldi	r17, high(st_hst+st_sub*1)
	std	Z+rsp_sts+0, r16
	std	Z+rsp_sts+1, r17	;
	rjmp	rwexit
	
rwchkparam070:
	ldd	r17, Z+cmd_buff+1
	ldd	r18, Z+cmd_buff+2
	ldd	r19, Z+cmd_buff+3

	subi	r16, byte1(020000000)
	sbci	r17, byte2(020000000)
	sbci	r18, byte3(020000000)
	sbci	r19, byte4(020000000)
	brmi	rwchkparam080
	;
	;	Return Invalid Host Buffer
	;
	ldi	r16, low(st_hst+st_sub*1)
	ldi	r17, high(st_hst+st_sub*1)
	std	Z+rsp_sts+0, r16
	std	Z+rsp_sts+1, r17	;
	rjmp	rwexit

rwchkparam080:
;--------------------------------------------------------------------------
;
;	now we have checked the parameters
;
	ldd	r18, Z+cmd_opcd		; Get Opcode
	
					; Erase
					; Compare
					; Access
					; Read
					; Write

	cpi	r18, op_rd
	brne	rwchkparam110	
	rjmp	mscp_rd

rwchkparam110:
	cpi	r18, op_wr
	brne	rwchkparam120
	rjmp	mscp_wr	

rwchkparam120:
	cpi	r18, op_cmp
	brne	rwchkparam130
	rjmp	mscp_cmp	
	
rwchkparam130:
	cpi	r18, op_ers
	brne	rwchkparam140	
;--------------------------------------------------------------------------
;
;	ERASE
;
	clr	count
	movw	xh:xl, addrh:addrl
mscp_era010:
	st	X+, zero
	st	X+, zero
	dec	count
	brne	mscp_era010
mscp_era020:
	call	SD_CARD_WRITE

	cp	bkcl, zero
	cpc	bkch, zero
	breq	mscp_era030
	ldi	r16, low(1)
	ldi	r17, high(1)
	sub	bkcl, r16
	sbc	bkch, r17
	rcall	mscp_rwnextsector
	rjmp	mscp_era020

mscp_era030:
	rjmp	rwexit

rwchkparam140:
	cpi	r18, op_acc
	brne	rwchkparam150	
;--------------------------------------------------------------------------
;
;	ACCESS
;
	rjmp	rwexit

rwchkparam150:
	ldi	r16, low(st_cmd)
	ldi	r17, high(st_cmd)
	std	Z+rsp_sts+0, r16
	std	Z+rsp_sts+1, r17	;
	rjmp	rwexit
	
;--------------------------------------------------------------------------
;
;	READ
;
mscp_rd:
	rcall	mscp_setupw		; Write Host Memory
mscp_rd010:
	clr	count
	cp	bkcl, zero
	cpc	bkch, zero
	breq	mscp_rd020
	mov	count, wcnt
mscp_rd020:
	call	SD_CARD_READ	
	movw	xh:xl, addrh:addrl
mscp_rd030:
	ld	datal, X+
	ld	datah, X+
	dmawrt datal, datah
	brcs	mscp_rd090
	dec	count
	brne	mscp_rd030	
	cp	bkcl, zero
	cpc	bkch, zero
	breq	mscp_rd040
	ldi	r16, low(1)
	ldi	r17, high(1)
	sub	bkcl, r16
	sbc	bkch, r17
	rcall	mscp_rwnextsector
	rjmp	mscp_rd010

mscp_rd040:
	rjmp	rwexit
mscp_rd090:
	rjmp	rwdmaerror
;--------------------------------------------------------------------------
;
;	WRITE
;
mscp_wr:
	rcall	mscp_setupr
mscp_wr010:
	clr	count
	cp	bkcl, zero
	cpc	bkch, zero
	breq	mscp_wr020
	mov	count, wcnt
mscp_wr020:
	movw	xh:xl, addrh:addrl
mscp_wr030:
	dmaread	datal, datah
	brcs	mscp_wr090
	st	X+, datal
	st	X+, datah
	dec	count
	brne	mscp_wr030
	cp	bkcl, zero
	cpc	bkch, zero
	breq	mscp_wr040
	call	SD_CARD_WRITE
	rcall	mscp_rwnextsector
	rjmp	mscp_wr010
mscp_wr040:
	tst	wcnt
	breq	mscp_wr050
	st	X+, zero
	st	X+, zero
	inc	wcnt
	rjmp	mscp_wr040
mscp_wr050:
	call	SD_CARD_WRITE
	rjmp	rwexit
mscp_wr090:
	rjmp	rwdmaerror
;--------------------------------------------------------------------------
;
;	COMPARE
;
mscp_cmp:
	rcall	mscp_setupr		; Write Host Memory
mscp_cmp010:
	clr	count
	cp	bkcl, zero
	cpc	bkch, zero
	breq	mscp_cmp020
	mov	count, wcnt
mscp_cmp020:
	call	SD_CARD_READ	
	movw	xh:xl, addrh:addrl
mscp_cmp030:
	ld	r16, X+
	ld	r17, X+
	dmaread datal, datah
	brcs	mscp_cmp090
	cp	r16, datal
	cpc	r17, datah
	brne	mscp_cmp091
	dec	count
	brne	mscp_cmp030	
	cp	bkcl, zero
	cpc	bkch, zero
	breq	mscp_cmp040
	ldi	r16, low(1)
	ldi	r17, high(1)
	sub	bkcl, r16
	sbc	bkch, r17
	rcall	mscp_rwnextsector
	rjmp	mscp_cmp010

mscp_cmp040:
	rjmp	rwexit
mscp_cmp090:
	rjmp	rwdmaerror
mscp_cmp091:
	rjmp	rwerror


rwdmaerror:

rwerror:

rwexit:
	movw	r25:r24, pkth:pktl
	call	put_packet
	pop	yh
	pop	yl
	ret
;--------------------------------------------------------------------------
;
;	Input:
;	Y		UCB
;	Z		PKT
;
;	Output:
;	ucbh:ucbl	UCB
;	pkth:pktl	Packet
;	wcnt		Word Count partial block
;	bkch:bkcl	Block Count
;	addrh:addrl	Buffer Address
;	CPLD		DMA direction and DMA start address are set
;
;
mscp_setupr:
	set				; Set Direction bit
	cpse	zero, zero		; Skip next instruction
mscp_setupw:	
	clt				; Clear Direction Bit
	ldd	r20, Z+cmd_buff+0
	ldd	r21, Z+cmd_buff+1
	ldd	r22, Z+cmd_buff+2
	bld	r20, 0			; Copy Direction Bit
	dmaaddr r20, r21, r22	; Start Address of DMA transfer

	ldd	r16, Z+cmd_lbn+0	
	ldd	r17, Z+cmd_lbn+1
	ldd	r18, Z+cmd_lbn+2
	ldd	r19, Z+cmd_lbn+3	; Logical Block Number
	
	ldd	wcnt, Z+cmd_bcnt+0
	ldd	bkcl, Z+cmd_bcnt+1
	ldd	bkch, Z+cmd_bcnt+2	; we support only 2^24 bytes :-)
	
	lsr	bkch			; Convert to word count, note LSR
	ror	bkcl			; Clears bit7.
	ror	wcnt

	movw	ucbh:ucbl, yh:yl	; Save UCB
	movw	pkth:pktl, zh:zl	; Save PKT
;
;	Logging
;
	movw	zh:zl, pkth:pktl	
	ldi	r16, log_buff
	ldd	r17, Z+cmd_buff+0
	ldd	r18, Z+cmd_buff+1
	ldd	r19, Z+cmd_buff+2
	logptr	zl, zh, r25, r24
	std	Z+0, r16
	std	Z+1, r17
	std	Z+2, r18
	std	Z+3, r19
	movw	zh:zl, pkth:pktl	
	ldi	r16, log_bcnt
	ldd	r17, Z+cmd_bcnt+0
	ldd	r18, Z+cmd_bcnt+1
	ldd	r19, Z+cmd_bcnt+2
	logptr	zl, zh, r25, r24
	std	Z+0, r16
	std	Z+1, r17
	std	Z+2, r18
	std	Z+3, r19
	movw	zh:zl, pkth:pktl	
	ldi	r16, log_lbn
	ldd	r17, Z+cmd_lbn+0
	ldd	r18, Z+cmd_lbn+1
	ldd	r19, Z+cmd_lbn+2
	logptr	zl, zh, r25, r24
	std	Z+0, r16
	std	Z+1, r17
	std	Z+2, r18
	std	Z+3, r19
;
;	Get Image Pointer
;	
	ldd	zl, Y+ucb_imgptr+0	; Get pointer to disk image control block
	ldd	zh, Y+ucb_imgptr+1
	ldd	r20, Y+ucb_status	; Get the status
	sbrs	r20, ucb__file		; Is unit attached to a file?
	rjmp	mscp_rwsetup020	; no its a partition
;
;	A file is attached, Z points to the fcb. We put the LBN to the
;	P_Cluster offset of the iob linked to the fcb (file control block)
;	which is then translated to a physical block number by using the
;	fragment list attached to the file control block
;
	ldd	yl, Z+fcb_iob+0
	ldd	yh, Z+fcb_iob+1
	std	Y+P_Cluster+0, r16	; Set start LBN for read or write
	std	Y+P_Cluster+1, r17
	std	Y+P_Cluster+2, r18
	std	Y+P_Cluster+3, r19
	movw	r25:r24, zh:zl		; File Control Block
	call	Logical2Physical	; Convert to PBN (pyhsical block number)
	rjmp	mscp_rwsetup030
;
;	A partition is attached, Z points to the pcb which holds the
;	start sector number of the partition, translating LBN to PBN
;	results in just adding the start sector number
;
mscp_rwsetup020:
	ldd	r20, Z+pcb_start+0	; Add start of partition
	ldd	r21, Z+pcb_start+1
	ldd	r22, Z+pcb_start+2
	ldd	r23, Z+pcb_start+3
	add	r16, r20
	adc	r17, r21
	adc	r18, r22
	adc	r19, r23
	ldi	yl, low(sdio)		; Setup parameter block for general IO
	ldi	yh, high(sdio)		; 
	std	Y+P_Sector+0, r16	; Set start sector for read or write
	std	Y+P_Sector+1, r17
	std	Y+P_Sector+2, r18
	std	Y+P_Sector+3, r19
;
;	Get the number of words requested. If more words are requested than
;	would be available on the current track from the start sector then
;	we truncate to the maximum word count possible. If this was the
;	case we need to return HNF so the device driver can continue the
;	read/write request after a seek to the next track has been made.
;	This is an undocumented feature and has been verifed with simh and
;	at least the boot loader of RT-11 makes use of this behaviour. Note
;	that we calculate MAXWC and then overwrite MPR in case it is higher
;	than the user provided value of the wordcount in MPR. This value
;	will later be used to calculate the and bus address after the
;	transferred bytes. This is not a problem as the wordcount cannot be
;	retrieved, reading MPR always returns values from the FIFO
;
mscp_rwsetup030:
	sbis	FLAGS_LOG, log__pbn
	rjmp	mscp_rwsetup035
	logptr	zl, zh, r25, r24	; Destroys r25:r24, zh:zl
	ldd	r16, Y+P_Sector+0	; Set start sector for read or write
	ldd	r17, Y+P_Sector+1
	ldd	r18, Y+P_Sector+2
	ldd	r19, Y+P_Sector+3
	std	Z+3, r16
	std	Z+2, r17
	std	Z+1, r18
	andi	r19, 0x0F
	ori	r19, log_pbn
	std	Z+0, r19
mscp_rwsetup035:	

	ldi	r16, low(sdbuffer)	; 
	ldi	r17, high(sdbuffer)	; 
	std	Y+P_Address+0, r16	; Set buffer address for SD-Card block
	std	Y+P_Address+1, r17	; 
	movw	addrh:addrl, r17:r16
	ret
;--------------------------------------------------------------------------
;
;	When reading or writing another block we need to either increment the
;	sector in case the unit is attached to a partition or we need to increment
;	the logical block number and then translate it to a physical block number.	
;
mscp_rwnextsector:
	movw	zh:zl, ucbh:ucbl	; Get UCB Pointer
	ldd	r20, Z+ucb_status
	sbrc	r20, ucb__file		; Is the unit attached to a file?
	rjmp	mscp_rwnextsector010	; Yes so increment LBN and translate

	ldd	r16, Y+P_Sector+0	; in case unit is attached to a partition
	ldd	r17, Y+P_Sector+1	; we just need to increment the sector
	ldd	r18, Y+P_Sector+2	; number by one
	ldd	r19, Y+P_Sector+3
	subi	r16, byte1(-1)
	sbci	r17, byte2(-1)
	sbci	r18, byte3(-1)
	sbci	r19, byte4(-1)
	std	Y+P_Sector+0, r16
	std	Y+P_Sector+1, r17
	std	Y+P_Sector+2, r18
	std	Y+P_Sector+3, r19
	sbis	FLAGS_LOG, log__pbn
	ret
	logptr	zl, zh, r25, r24	; Destroys r25:r24, zh:zl
	std	Z+3, r16
	std	Z+2, r17
	std	Z+1, r18
	andi	r19, 0x0F
	ori	r19, log_pbn
	std	Z+0, r19	
	ret

mscp_rwnextsector010:
	ldd	r16, Y+P_Cluster+0	; in case unit is attached to a file
	ldd	r17, Y+P_Cluster+1	; we just need to increment the LBN
	ldd	r18, Y+P_Cluster+2	; by one and then
	ldd	r19, Y+P_Cluster+3
	subi	r16, byte1(-1)
	sbci	r17, byte2(-1)
	sbci	r18, byte3(-1)
	sbci	r19, byte4(-1)
	std	Y+P_Cluster+0, r16
	std	Y+P_Cluster+1, r17
	std	Y+P_Cluster+2, r18
	std	Y+P_Cluster+3, r19
	ldd	r24, Z+ucb_imgptr+0	; This is the file control block
	ldd	r25, Z+ucb_imgptr+1
	call	Logical2Physical	; translate it to a PBN using the fragment list
	ldd	r16, Y+P_Sector+0
	ldd	r17, Y+P_Sector+1
	ldd	r18, Y+P_Sector+2
	ldd	r19, Y+P_Sector+3
	sbis	FLAGS_LOG, log__pbn
	ret
	logptr	zl, zh, r25, r24		
	std	Z+3, r16
	std	Z+2, r17
	std	Z+1, r18
	andi	r19, 0x0F
	ori	r19, log_pbn
	std	Z+0, r19	
	ret		


	












.undef	crcl
.undef	crch
.undef	datal	
.undef	datah	
.undef	bkcl	
.undef	bkch
.undef	wcnt
.undef	count
.undef	addrl
.undef	addrh
.undef	ucbl
.undef	ucbh
.undef	pktl
.undef	pkth
