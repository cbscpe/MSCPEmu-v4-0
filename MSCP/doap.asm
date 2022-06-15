;
;	Abort Program
;
;	As we do not support DUP we also can never abort a program
;	therefore this is an illegal command
;


do$ap::
	jsr	r5,csv$	
	mov	4(r5),r4
	bit	102650,#4	; if( CCB.state & cs_dup );
	beq	45570	
	bis	#2,102670	; PCB.state |= ps_abo;
	clr	20(r4)		; RSP.p_sts = st_suc;
	br	45576	

	mov	#1,20(r4)	; RSP.p_sts = st_cmd;
	bisb	#200,16(r4)	; RSP.p_opcd |= op_end;
	mov	#14,2(r4)	; PKT.size = rs_ap;
	clrb	4(r4)		; PKT.type = mt_seq;
	mov	r4,-(sp)
	call	put.packet	; put_packet( pkt);
	tst	(sp)+	
	jmp	cret$	


do_ap( pkt )
register struct $pkt *pkt;
    {
#if debug>=1
    printf( "\nABORT PROGRAM" );
#endif
    /*
     *  if we are running a program, set the "abort" state (if no program is
     *  running, this is an invalid command!)
     */
    if( CCB.state & cs_dup )
	{
	PCB.state |= ps_abo;
	RSP.p_sts = st_suc;
	}
    else
	RSP.p_sts = st_cmd;
    RSP.p_opcd |= op_end;
    PKT.size = rs_ap;
    PKT.type = mt_seq;
    put_packet( pkt );
    }
    
do_ap:
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	lds	r18, _ccb_state
	sbrs	r18, cs_dup_bp
	rjmp	do_ap010
	lds	r18, _pcb_state
	ori	r18, ps_abo_bm
	sts	_pcb_state, r18
	ldi	r18, st_suc
	std	Y+rsp_sts, r18
	rjmp	do_ap020

do_ap010:
	ldi	r18, st_cmd
	std	Y+rsp_sts, r18

do_ap020:
	ldd	r18, Y+rsp_opcd
	ori	r18, op_end_bm
	std	Y+rsp_opcd, r18
	ldi	r16, low(rs_ap)
	ldi	r17, high(rs_ap)
	std	Y+pkt_size+0, r16
	std	Y+pkt_size+1, r17
	ldi	r18, mt_seq
	std	Y+pkt_type, r18
	movw	r25:r24, yh:yl
	call	put_packet
	pop	yh
	pop	yl
	ret
