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

;
;	Logging
;
;	0x50	ucb
;	0x51	lbn
;	0x52	byte count
;	0x53	count of 64k blocks
;	0x54	2's complement of word count in last 64k block
;	0x55	DMA Address, word-count in block, block count
;	0x5F	multi-word output


.def	count	= r3			; Local Counter 
.def	datal	= r4			; DMA data
.def	datah	= r5
.def	bkcl	= r6			; Block Counter for even bigger word counts
.def	bkch	= r7			; 
.def	wcntl	= r8			; Word Counter
.def	wcnth	= r9			; Word Counter
.def	pktl	= r10			; MSCP Packet address
.def	pkth	= r11
.def	addrl	= r12			; I/O Buffer Address
.def	addrh	= r13
.def	ucbl	= r14			; UCB Address
.def	ucbh	= r15


; 
;	Offset definitions for READ, WRITE, COMPARE, ACCESS or ERASE command packet
;
recordcont	pkt, data		;	
record		rwc, crf, 4		; 6.	Command Reference Number
record		rwc, unit, 2		; 8.	Unit
record		rwc, r1, 2		; 10.	reserved 1
record		rwc, opcd, 1		; 12.	Op Code
record		rwc, r2, 1		; 13.	reserved 2
record		rwc, mod, 2		; 14.	Command Modifiers
record		rwc, bcnt, 4		; 16.	Byte Count
record		rwc, buff, 12		; 20.	Buffer Descriptor
record		rwc, lbn, 4		; 32.	Logical Block Number
recordend	rwc, next		; 50.

recordcont	pkt, data		;	
record		rwr, crf, 4		; 6.	Command Reference Number
record		rwr, unit, 2		; 8.	Unit
record		rwr, r1, 2		; 10.	reserved 1
record		rwr, opcd, 1		; 12.	Op Code
record		rwr, flgs, 1		; 13.	Flags
record		rwr, sts, 2		; 14.	Status
record		rwr, bcnt, 4		; 16.	Byte Count
record		rwr, r2, 12		; 20.	reserved 2
record		rwr, fbbk, 4		; 32.	First Bad Block
recordend	rwr, next		; 50.

.equ	rs_rw	= rwc_next - pkt_data

;
;	Register Conventions
;
;	yh:yl	Always points to the MSCP packet, may be used in special cases but
;		only within local code that does not call any other sub-routine and
;		must be restored when done
;
;	ucbh:ucbl	Unit Control Block is stored there after calling getucb
;		
;	
;
;
;
;
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
	movw	pkth:pktl, r25:r24	; Save PKT address locally
	movw	yh:yl, pkth:pktl	; Get PKT address
	std	Y+rwr_flgs, zero
;
;	Check Drive Status
;
	ldd	r24, Y+rwc_unit+0
	ldd	r25, Y+rwc_unit+1
	call	getucb
	;logtr	0x50, r24, r25
	sbiw	r25:r24, 0
	breq	rwchkparam010

	movw	ucbh:ucbl, r25:r24	; Save UCB address locally
	movw	zh:zl, ucbh:ucbl	; Get UCB address
	ldd	r18, Z+ucb_status
	sbrc	r18, ucb__onl		; 
	rjmp	rwchkparam020
	andi	r18, (1<<ucb__part) | (1<<ucb__file)
	breq	rwchkparam010
	;
	;	Return unit Available
	;
	ldi	r18, low(st_avl)	; Unit Offline
	ldi	r19, high(st_avl)	; Unit Unknown
	std	Y+rwr_sts+0, r18
	std	Y+rwr_sts+1, r19	;
	rjmp	rwexit

rwchkparam010:
	;
	;	Return Status Offline
	;
	ldi	r18, low(st_ofl)	; Unit Offline
	ldi	r19, high(st_ofl)	; Unit Unknown
	std	Y+rwr_sts+0, r18
	std	Y+rwr_sts+1, r19	;
	rjmp	rwexit
;
;	Check Parameters	
;
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
	ldd	r24, Z+ucb_imgptr+0	; get disk image control block
	ldd	r25, Z+ucb_imgptr+1	; 
.if ((fcb_drvtab - pcb_drvtab) != 0)
	.error " Offsets fcb_drvtab and pcb_drvtab must be equal!"
.endif
	movw	zh:zl, r25:r24		; 
	ldd	r24, Z+pcb_drvtab+0	;
	ldd	r25, Z+pcb_drvtab+1	;
	movw	zh:zl, r25:r24		; 

	ldd	r20, Z+Drv_Capacity+0	; Total Diks capacity incl. RCT
	ldd	r21, Z+Drv_Capacity+1
	ldd	r22, Z+Drv_Capacity+2
	ldd	r23, Z+Drv_Capacity+3
	ldd	r24, Z+Drv_RCTSize+0
	ldd	r25, Z+Drv_RCTSize+1
	add	r20, r24
	adc	r21, r25
	adc	r22, zero
	adc	r23, zero
	ldd	r16, Y+rwc_lbn+0	; Get starting LNB
	ldd	r17, Y+rwc_lbn+1
	ldd	r18, Y+rwc_lbn+2
	ldd	r19, Y+rwc_lbn+3
	;logtr	0x51, r16, r17		; 
	;logtr	0x5F, r18, r19
	cp	r16, r20
	cpc	r17, r21
	cpc	r18, r22
	cpc	r19, r23
	brlo	rwchkparam030		; Must be lower 
	;
	;	Return Invalid Command, Subcode i_lbn
	;
	ldi	r18, st_cmd		; Invalid Command
	ldi	r19, i_lbn		; LBN
	std	Y+rwr_sts+0, r18
	std	Y+rwr_sts+1, r19	;
	rjmp	rwexit
	
rwchkparam030:				; Check for RCT
	ldd	r20, Z+Drv_Capacity+0
	ldd	r21, Z+Drv_Capacity+1
	ldd	r22, Z+Drv_Capacity+2
	ldd	r23, Z+Drv_Capacity+3
	cp	r16, r20
	cpc	r17, r21
	cpc	r18, r22
	cpc	r19, r23
	brlo	rwchkparam040		; A regular block
	
	ldd	r20, Y+rwc_bcnt+0	; We are reading a RCT block
	ldd	r21, Y+rwc_bcnt+1
	ldd	r22, Y+rwc_bcnt+2
	ldd	r23, Y+rwc_bcnt+3
	subi	r20, byte1(512)
	sbci	r21, byte2(512)
	sbci	r22, byte3(512)
	sbci	r23, byte4(512)
	breq	rwchkparam040		; In case of RCT bytecount must be 512.
	;
	;	Return Invalid Command, Subcode i_bcnt
	;
	ldi	r18, st_cmd		; Invalid Command
	ldi	r19, i_bcnt		; LBN
	std	Y+rwr_sts+0, r18
	std	Y+rwr_sts+1, r19	;
	rjmp	rwexit
	
rwchkparam040:
	ldd	r20, Y+rwc_bcnt+0	; Get Byte count and calculate the
	ldd	r21, Y+rwc_bcnt+1	; number of blocks to verify the
	ldd	r22, Y+rwc_bcnt+2	; request does not go beyond the
	ldd	r23, Y+rwc_bcnt+3	; disk size

	;logtr	0x52, r20, r21		; Byte Count Low
	;logtr	0x5F, r22, r23
	
	lsr	r23
	ror	r22
	ror	r21
	
	add	r16, r21
	adc	r17, r22
	adc	r18, r23
	adc	r19, zero		; Last LBN we expect to read

	ldd	r20, Z+Drv_Capacity+0	; Again the whole capacity
	ldd	r21, Z+Drv_Capacity+1
	ldd	r22, Z+Drv_Capacity+2
	ldd	r23, Z+Drv_Capacity+3
	ldd	r24, Z+Drv_RCTSize+0
	ldd	r25, Z+Drv_RCTSize+1
	add	r20, r24
	adc	r21, r25
	adc	r22, zero
	adc	r23, zero
	ldd	r16, Y+rwc_lbn+0
	ldd	r17, Y+rwc_lbn+1
	ldd	r18, Y+rwc_lbn+2
	ldd	r19, Y+rwc_lbn+3
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
	ldi	r19, i_bcnt		; LBN
	std	Y+rwr_sts+0, r18
	std	Y+rwr_sts+1, r19	;
	rjmp	rwexit

rwchkparam050:
;
;	Check Host Buffer
;
	ldd	r18, Y+rwc_opcd
	cpi	r18, op_ers
	breq	rwchkparam055		; not required for ERASE
	cpi	r18, op_acc
	breq	rwchkparam055		; not required for ACCESS
	ldd	r16, Y+rwc_bcnt+0
	sbrs	r16, 0			; Byte count must be even
	rjmp	rwchkparam060
	;
	;	Return Invalid Host Buffer
	;
	ldi	r18, low(st_hst+st_sub*2)
	ldi	r19, high(st_hst+st_sub*2)
	std	Y+rwr_sts+0, r18
	std	Y+rwr_sts+1, r19	;
	rjmp	rwexit

rwchkparam055:
	rjmp	rwchkparam080
	
rwchkparam060:
	ldd	r16, Y+rwc_buff+0
	sbrs	r16, 0			; Address must be even
	rjmp	rwchkparam070
	;
	;	Return Invalid Host Buffer
	;
	ldi	r18, low(st_hst+st_sub*1)
	ldi	r19, high(st_hst+st_sub*1)
	std	Y+rwr_sts+0, r18
	std	Y+rwr_sts+1, r19	;
	rjmp	rwexit
	
rwchkparam070:				; Calculate End Address
	ldd	r17, Y+rwc_buff+1
	ldd	r18, Y+rwc_buff+2
	ldd	r19, Y+rwc_buff+3

	subi	r16, byte1(020000000)
	sbci	r17, byte2(020000000)
	sbci	r18, byte3(020000000)
	sbci	r19, byte4(020000000)
	brmi	rwchkparam080
	;
	;	Return Invalid Host Buffer
	;
	ldi	r18, low(st_hst+st_sub*1)
	ldi	r19, high(st_hst+st_sub*1)
	std	Y+rwr_sts+0, r18
	std	Y+rwr_sts+1, r19	;
	rjmp	rwexit

rwchkparam080:
;--------------------------------------------------------------------------
;
;	now we have checked the parameters
;
	ldd	r18, Y+rwc_opcd		; Get Opcode
	cpi	r18, op_rd		; Read
	brne	rwchkparam110	
	rjmp	mscp_rd

rwchkparam110:

	cpi	r18, op_wr		; Write
	brne	rwchkparam120
	rjmp	mscp_write	

rwchkparam120:
	cpi	r18, op_cmp		; Compare
	brne	rwchkparam130
	rjmp	mscp_cmp	
	
rwchkparam130:
	cpi	r18, op_ers		; Erase
	brne	rwchkparam140	
;--------------------------------------------------------------------------
;
;	ERASE
;
	rcall	mscp_setupe
	clr	count
	movw	xh:xl, addrh:addrl
mscp_era010:
	st	X+, zero
	st	X+, zero
	dec	count
	brne	mscp_era010
mscp_era020:
	call	SD_CARD_WRITE
	
	movw	xh:xl, bkch:bkcl
	sbiw	xh:xl, 0
	breq	mscp_era030
	sbiw	xh:xl, 1
	movw	bkch:bkcl, xh:xl
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
	rjmp	rwexit			; Access

rwchkparam150:				; Invalid Command
	ldi	r18, low(st_cmd)
	ldi	r19, high(st_cmd)
	std	Y+rwr_sts+0, r18
	std	Y+rwr_sts+1, r19	;
	rjmp	rwexit
	
;--------------------------------------------------------------------------
;
;	READ
;
mscp_rd:
	rcall	mscp_setupw		; Write Host Memory
;
;	DMA Address has been set and the IO control block has been
;	filled with all the necessary information to read a block
;	from the SD-Card. The IO control block address is in yh:yl
;	the number of blocks we need to read is in bkch:bkcl including
;	a potential partail last block and the number of words to 
;	transfer in the last block is in wcntl.
;
	movw	zh:zl, ucbh:ucbl
	ldd	r16, Z+ucb_status
	sbrc	r16, ucb__part
	rjmp	mscp_rd100

mscp_rd010:
	movw	r25:r24, yh:yl		; get IO control block
	call	SD_CARD_READ
	movw	xh:xl, addrh:addrl	; Get Buffer Address
	clr	count			; Assume we need to transfer the whole block
	movw	r25:r24, bkch:bkcl	; Get Blocks to Read
	sbiw	r25:r24, 1		; Is this the last block
	brne	mscp_rd020		; no
	tst	wcntl			; is the last block a partial block
	breq	mscp_rd020		; no	
	mov	count, wcntl		; partial block size

mscp_rd020:
	ld	datal, X+
	ld	datah, X+
	dmawrt	datal, datah
	brcs	mscp_rd090
	dec	count
	brne	mscp_rd020		; Transfer to host memory
	movw	r25:r24, bkch:bkcl	; Get Blocks to read
	sbiw	r25:r24, 1		; More blocks to read
	breq	mscp_rd030		; No - All done
	movw	bkch:bkcl, r25:r24	; 
	rcall	mscp_rwnextsector	; Calculate the next sector
	rjmp	mscp_rd010

mscp_rd030:
	rjmp	rwexit
mscp_rd090:
	rjmp	rwdmaerror
	
;
;	Experimental code for SD_CARD_MULTIPE
;
mscp_rd100:
	movw	zh:zl, pkth:pktl	; Get Packet
	ldd	r22, Z+rwc_bcnt+0	; Get Byte Count, which is at this moment
	ldd	r23, Z+rwc_bcnt+1	; verified to be valid
	ldd	r24, Z+rwc_bcnt+2
	ldd	r25, Z+rwc_bcnt+3
	lsr	r25			; Make word count
	ror	r24
	ror	r23
	ror	r22
	com	r23
	neg	r22
	sbci	r23, -1			; Make 2's complement and save word count
	movw	wcnth:wcntl, r23:r22	; of last block of 65536 words

	;logtr	0x53, r24, r25	; Show how many blocks we are going to do

	rjmp	mscp_rd120
;------------------------------
;
;
;
mscp_rd110:
	movw	bkch:bkcl, r25:r24	; Save remaining block count
	movw	r25:r24, yh:yl		; Get IO control block
	call	SD_CARD_MULTIPLE
	movw	r25:r24, bkch:bkcl
;
;
;
mscp_rd120:
	std	Y+P_Wordcount+0, zero	; Assume 65536 words
	std	Y+P_Wordcount+1, zero
	sbiw	r25:r24, 1		; 
	brpl	mscp_rd110		; do full block
	std	Y+P_Wordcount+0, wcntl	; Remaining Words
	std	Y+P_Wordcount+1, wcnth
	;logtr	0x54, wcntl, wcnth	; We are doing the rest of the block
	movw	r25:r24, yh:yl		; Get IO control block
	call	SD_CARD_MULTIPLE
	rjmp	rwexit	
;
;
;
;--------------------------------------------------------------------------
;
;	WRITE
;
mscp_write:
	rcall	mscp_setupr		; Read Host Memory
mscp_write010:
	clr	count			; Assume Entire Block
	movw	r25:r24, bkch:bkcl	; Get Blocks to Write
	sbiw	r25:r24, 1		; Is this the last block
	brne	mscp_write020		; no
	tst	wcntl			; Is the last block a partial block
	breq	mscp_write020		; no
	movw	xh:xl, addrh:addrl	; For partial blocks make sure that we
mscp_write015:				; fill the rest with zero
	st	X+, zero
	st	X+, zero
	inc	count
	brne	mscp_write015
	mov	count, wcntl		; Only Partial Block
mscp_write020:
	movw	xh:xl, addrh:addrl
mscp_write030:
	dmaread	datal, datah		; Read Host Data
	brcs	mscp_write090
	st	X+, datal		; Save to Block
	st	X+, datah
	dec	count			; More to go?
	brne	mscp_write030
	movw	r25:r24, yh:yl		; get IO control block
	call	SD_CARD_WRITE		; Write the block
	movw	r25:r24, bkch:bkcl	; Get Blocks to Write
	sbiw	r25:r24, 1		; More Blocks to Write
	breq	mscp_write040		; No - All done
	movw	bkch:bkcl, r25:r24
	rcall	mscp_rwnextsector	; Calcualte the next sector
	rjmp	mscp_write010
mscp_write040:
	rjmp	rwexit
mscp_write090:
	rjmp	rwdmaerror
;--------------------------------------------------------------------------
;
;	COMPARE
;
mscp_cmp:
	rcall	mscp_setupr		; Read Host Memory
mscp_cmp010:
	clr	count
	cp	bkcl, zero
	cpc	bkch, zero
	breq	mscp_cmp020
	mov	count, wcntl
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
	movw	yh:yl, pkth:pktl
	ldd	r18, Y+rwr_opcd
	ori	r18, op_end
	std	Y+rwr_opcd, r18	; Set End Flag
	ldi	r24, low(rs_rw)
	ldi	r25, high(rs_rw)
	std	Y+pkt_size+0, r24
	std	Y+pkt_size+1, r25

	movw	r25:r24, pkth:pktl
	call	put_packet
	pop	yh
	pop	yl
	ret
;--------------------------------------------------------------------------
;
;	Input:
;	Y		PKT
;	ucbh:ucbl	UCB
;
;	Output:
;	wcntl		Word Count partial block
;	bkch:bkcl	Block Count
;	addrh:addrl	Buffer Address
;	CPLD		DMA direction and DMA start address are set
;	Y		IO Control Block
;
;
mscp_setupr:				; READ
	set				; Set Direction bit
	cpse	zero, zero		; Skip next instruction
mscp_setupw:				; WRITE
	clt				; Clear Direction Bit
	ldd	r20, Y+rwc_buff+0
	ldd	r21, Y+rwc_buff+1
	ldd	r22, Y+rwc_buff+2
	bld	r20, 0			; Copy Direction Bit
	dmaaddr r20, r21, r22		; Start Address of DMA transfer

mscp_setupe:				; ERASE
;
;	Now we need to convert the byte count into a word count and
;	a block count. The good thing is a block is exactly 256. words
;	in other words we just need to shift the byte count one bit
;	to the right and then we can use the lower 8 bits as word count
;	and the rest as block count
;
	ldd	wcntl, Y+rwc_bcnt+0
	ldd	r24, Y+rwc_bcnt+1
	ldd	r25, Y+rwc_bcnt+2	; we support only 2^24 bytes :-)
	
	lsr	r25
	ror	r24
	ror	wcntl
	cpse	wcntl, zero		; Is the last block a partial block
	adiw	r25:r24, 1		; Account for partial block
	movw	bkch:bkcl, r25:r24	

	ldd	r16, Y+rwc_lbn+0	
	ldd	r17, Y+rwc_lbn+1
	ldd	r18, Y+rwc_lbn+2
	ldd	r19, Y+rwc_lbn+3	; Logical Block Number
	
	;logtr	0x55, r20, r21		; DMA Start Address and word
	;logtr	0x5F, r22, wcntl		; count in last block (0=entire block)
	;logtr	0x5F, bkcl, bkch	; block count
;
;	Get Image Pointer
;	
	movw	yh:yl, ucbh:ucbl 	; Get UCB
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
	ldd	yl, Z+fcb_iob+0		; Get pointer to IO control block
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
	ldi	yl, low(sdio)		; Address of common IO control block
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
	ldi	r16, (1<<P__Nocheck)	; don't check CRC, no partial start block
	std	Y+P_Flag, r16		; 
	ldi	r16, low(sdbuffer)	; 
	ldi	r17, high(sdbuffer)	; 
	std	Y+P_Address+0, r16	; Set buffer address for SD-Card block
	std	Y+P_Address+1, r17	; 
	movw	addrh:addrl, r17:r16	; Keep Buffer Address
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
;??	ldd	r16, Y+P_Sector+0
;??	ldd	r17, Y+P_Sector+1
;??	ldd	r18, Y+P_Sector+2
;??	ldd	r19, Y+P_Sector+3
	ret


	












.undef	datal	
.undef	datah	
.undef	bkcl	
.undef	bkch
.undef	wcntl
.undef	count
.undef	addrl
.undef	addrh
.undef	ucbl
.undef	ucbh
.undef	pktl
.undef	pkth
