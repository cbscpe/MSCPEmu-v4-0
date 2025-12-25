;--------------------------------------------------------------------------
;
;	SEEK JOB
;
;
seekjob:

seekjobloop:
#if wdgactive>0
	wdr
#endif
	ldi	r24, low(2)
	ldi	r25, high(2)
	call	delay
;
;	Seek processing, not we perform seek processing in the low piority
;	job seekjob. Therefore it is very likely that a read or write command
;	already has been issued before seek processing takes place. Such a
;	command will have priority over the seek itself as it is assumed that
;	write or read commands will wait for the disk to finish a seek and then
;	perform the data transfer. 
;	
	clr	r21			; seek execution mask
;
;	The RLV12 does not have to "wait" for a seek to finish and just starts    
;	with the transfer and terminates a pending seek (it clears ucb__seek).    
;	Therefore we only collect overlapped seeks if they are still pending.     
;	Therefore we need to make seek atomic with interrupts disabled            
;
	cli
	lds	r20, unittable+ucb_size*0+ucb_status
	sbrs	r20, ucb__seek
	rjmp	seek100
;
;	When a seek command is executed DATO processing will store DAR to
;	ucb_media in the UCB.
;
	sbr	r21, 0x01
	cbr	r20, (1<<ucb__seek)
	sts	unittable+ucb_size*0+ucb_status, r20
	lds	r16, unittable+ucb_size*0+ucb_diskaddr+0
	lds	r17, unittable+ucb_size*0+ucb_diskaddr+1
	lds	r18, unittable+ucb_size*0+ucb_media+0
	lds	r19, unittable+ucb_size*0+ucb_media+1

	bst	r18, DAR_SEEK_HS	; Get HS from DAR of seek command
	bld	r16, DAR_RW_HS		; Set head in current disk address
	sbrs	r18, DAR_SEEK_DIR	; direction of seek
	rjmp	seekout000		; towards the boarder
;
;	DIR=1 head moves to a higher cylinder address
;
	andi	r18, 0x80		; Only keep cylinder bits
	add	r16, r18
	adc	r17, r19
	rjmp	seekdone000
;
;	DIR=0 head moves to a lower cylinder address
;
seekout000:
	andi	r18, 0x80		; Only keep cylinder bits
	sub	r16, r18
	sbc	r17, r19
seekdone000:
	sts	unittable+ucb_size*0+ucb_diskaddr+0, r16
	sts	unittable+ucb_size*0+ucb_diskaddr+1, r17
seek100:
	sei
	nop
	nop
	nop
	nop

	cli
	lds	r20, unittable+ucb_size*1+ucb_status
	sbrs	r20, ucb__seek
	rjmp	seek200
;
;	When a seek command is executed DATO processing will store DAR to
;	ucb_media in the UCB.
;
	sbr	r21, 0x02
	cbr	r20, (1<<ucb__seek)
	sts	unittable+ucb_size*1+ucb_status, r20
	lds	r16, unittable+ucb_size*1+ucb_diskaddr+0
	lds	r17, unittable+ucb_size*1+ucb_diskaddr+1
	lds	r18, unittable+ucb_size*1+ucb_media+0
	lds	r19, unittable+ucb_size*1+ucb_media+1

	bst	r18, DAR_SEEK_HS	; Get HS from DAR of seek command
	bld	r16, DAR_RW_HS		; Set head in current disk address
	sbrs	r18, DAR_SEEK_DIR	; direction of seek
	rjmp	seekout100		; towards the boarder
;
;	DIR=1 head moves to a higher cylinder address
;
	andi	r18, 0x80		; Only keep cylinder bits
	add	r16, r18
	adc	r17, r19
	rjmp	seekdone100
;
;	DIR=0 head moves to a lower cylinder address
;
seekout100:
	andi	r18, 0x80		; Only keep cylinder bits
	sub	r16, r18
	sbc	r17, r19
seekdone100:
	sts	unittable+ucb_size*1+ucb_diskaddr+0, r16
	sts	unittable+ucb_size*1+ucb_diskaddr+1, r17
seek200:
	sei
	nop
	nop
	nop
	nop

	cli
	lds	r20, unittable+ucb_size*2+ucb_status
	sbrs	r20, ucb__seek
	rjmp	seek300
;
;	When a seek command is executed DATO processing will store DAR to
;	ucb_media in the UCB.
;
	sbr	r21, 0x04
	cbr	r20, (1<<ucb__seek)
	sts	unittable+ucb_size*2+ucb_status, r20
	lds	r16, unittable+ucb_size*2+ucb_diskaddr+0
	lds	r17, unittable+ucb_size*2+ucb_diskaddr+1
	lds	r18, unittable+ucb_size*2+ucb_media+0
	lds	r19, unittable+ucb_size*2+ucb_media+1

	bst	r18, DAR_SEEK_HS	; Get HS from DAR of seek command
	bld	r16, DAR_RW_HS		; Set head in current disk address
	sbrs	r18, DAR_SEEK_DIR	; direction of seek
	rjmp	seekout200		; towards the boarder
;
;	DIR=1 head moves to a higher cylinder address
;
	andi	r18, 0x80		; Only keep cylinder bits
	add	r16, r18
	adc	r17, r19
	rjmp	seekdone200
;
;	DIR=0 head moves to a lower cylinder address
;
seekout200:
	andi	r18, 0x80		; Only keep cylinder bits
	sub	r16, r18
	sbc	r17, r19
seekdone200:
	sts	unittable+ucb_size*2+ucb_diskaddr+0, r16
	sts	unittable+ucb_size*2+ucb_diskaddr+1, r17
seek300:
	sei
	nop
	nop
	nop
	nop

	cli
	lds	r20, unittable+ucb_size*3+ucb_status
	sbrs	r20, ucb__seek
	rjmp	seek400
;
;	When a seek command is executed DATO processing will store DAR to
;	ucb_media in the UCB.
;
	sbr	r21, 0x08
	cbr	r20, (1<<ucb__seek)
	sts	unittable+ucb_size*3+ucb_status, r20
	lds	r16, unittable+ucb_size*3+ucb_diskaddr+0
	lds	r17, unittable+ucb_size*3+ucb_diskaddr+1
	lds	r18, unittable+ucb_size*3+ucb_media+0
	lds	r19, unittable+ucb_size*3+ucb_media+1

	bst	r18, DAR_SEEK_HS	; Get HS from DAR of seek command
	bld	r16, DAR_RW_HS		; Set head in current disk address
	sbrs	r18, DAR_SEEK_DIR	; direction of seek
	rjmp	seekout300		; towards the boarder
;
;	DIR=1 head moves to a higher cylinder address
;
	andi	r18, 0x80		; Only keep cylinder bits
	add	r16, r18
	adc	r17, r19
	rjmp	seekdone300
;
;	DIR=0 head moves to a lower cylinder address
;
seekout300:
	andi	r18, 0x80		; Only keep cylinder bits
	sub	r16, r18
	sbc	r17, r19
seekdone300:
	sts	unittable+ucb_size*3+ucb_diskaddr+0, r16
	sts	unittable+ucb_size*3+ucb_diskaddr+1, r17
seek400:
	sei

	tst	r21
	breq	seeknoseek
	logtr	0x06, r21, zero
seeknoseek:
	rjmp	seekjobloop

