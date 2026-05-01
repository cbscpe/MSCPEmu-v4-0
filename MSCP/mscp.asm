;
;
;	The real deal
;
;	Normal MSCP controllers distinguish between immediate and other
;	commands. Other commands are commands that include certain delays
;	as e.g. seek, rotational delay, resource waits. However in our case
;	we will just retrieve commands from the command ring, execute them
;	and report the result to the resonse ring.
;


;-	Requests that access the drives are all handled in this module.
;-	It will try to interleave the process as much as possible. First
;-	it will create a TCB (transfer control block). Then it will queue
;-	the transfer control block to the appropriate work job. But before
;-	the TCB will be queued to the work job some checks will be done.
;-
;-	Later the work job will pick up the TCB and start the execution
;-	of the transfer. 
;-
;-	A few remarks to the 9224 universal disk controller
;-
;-	- It can do interleaved seeks
;-	- Data is transferred to/from local memory from/to the disk
;-	- for this the 9224 has a built-in DMA controller
;-	- there is a bufferin local memory that can hold one track of
;-	  data, i.e. which is 18*512bytes
;-	- there is only one buffer and the 9224 can do only one transfer
;-	  at a time
;-	- only one work job can perform a transfer, therefore it must
;-	  lock the buffer.
;-	- the transfer from/to local memory to/from the host memory
;-	  requires a dedicated step using put_buffer/get_buffer
;-
;	We will skip all the interleave stuff. In other words do_rw will
;	be straightforward. And we will treat all commands sequentially.
;	No queueing, no buffer management, nothing. This is because our
;	hardware does not support DMA and we have only one SD-Card.

;
;	do_mscp destroys all registers!!!!
;
;	r25:r24	address of message buffer packet link header, i.e. the
;		MSCP message is preceeded by six bytes consisting of the 
;		link header(2), message buffer length(2), credits/message 
;		type(1) and connection id(1).
;
do_mscp:
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldd	zl, Y+cmd_opcd		; 016 (octal see rqdx3.das)
	cpi	zl, 0x3F
	mov	r16, zl
	logtr	0x7D, r16, zero
	brsh	do_default
	clr	zh
	subi	zl, low(-do_mscp_table)
	sbci	zh, high(-do_mscp_table)
	icall
	pop	yh
	pop	yl
	ret

;--------------------------------------------------------------------------
;
;	Return Invalid Opcode
;	
do_new:					; New Op_code for format
do_fmt:					; For now format is an illegal command
do_default:
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ori	r18, op_end
	std	Y+rsp_opcd, r18
	std	Y+rsp_flgs, zero
	ldi	r16, low(st_cmd + i_opcd)
	ldi	r17, high(st_cmd + i_opcd)
	std	Y+rsp_sts+0, r16
	std	Y+rsp_sts+1, r17
	rjmp	do_putpacket	

;
;	Return Success for Dummy Functions
;
do_dap:
do_ccd:
do_flu:
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldd	r18, Y+cmd_opcd
	ori	r18, op_end
	std	Y+rsp_opcd, r18
	std	Y+rsp_flgs, zero
	ldi	r16, low(st_suc)
	ldi	r17, high(st_suc)
	std	Y+rsp_sts+0, r16
	std	Y+rsp_sts+1, r17

do_putpacket:
	ldi	r16, low(rs_min)
	ldi	r17, high(rs_min)
	std	Y+pkt_size+0, r16
	std	Y+pkt_size+1, r17
	movw	r25:r24, yh:yl
	call	put_packet
	pop	yh
	pop	yl
	ret

;--------------------------------------------------------------------------
;
;	Jump Table
;	
do_mscp_table:
	rjmp	do_default		;
	rjmp	do_abo			; Abort
	rjmp	do_gcs			; Get Command Status
	rjmp	do_gus			; Get Unit Status
	rjmp	do_scc			; Set Controller Characteristics
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_avl			; Available
	rjmp	do_onl			; Online
	rjmp	do_suc			; Set Unit Characteristics
	rjmp	do_dap			; No-Op
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_acc			; Access
	rjmp	do_ccd			; No-Op
	rjmp	do_ers			; Erase
	rjmp	do_flu			; No-Op
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_new			; Format (24)
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_cmp			; Compare	
	rjmp	do_rd			; Read
	rjmp	do_wr			; Write
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_fmt			; Format (47)
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default
	rjmp	do_default		; AVA?? Now Available
