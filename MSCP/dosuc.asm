/*
 *  process a SET UNIT CHARACTERISTICS command
 *
 *  This is a sequential command, so if there are any non-sequential commands
 *  outstanding, we must hold this command pending until they are complete; if
 *  not (the UCB.tcbs list is empty), and if the unit actually exists and is
 *  not offline, then new values for the unit flags are set.  Like the ONLINE
 *  command, this command returns certain media-dependent information to the
 *  host as its final step.
 */
 

recordcont	pkt, data
record		suc, crf, 4	
record		suc, unit, 2	
record		suc, r1, 2	
record		suc, opcd, 1	
record		suc, flgs, 1	
record		suc, sts, 2	
record		suc, mlun, 2	
record		suc, unfl, 2	
record		suc, r2, 4	
record		suc, unti, 8	
record		suc, medi, 4	
record		suc, shun, 2	
record		suc, shst, 2	
record		suc, unsz, 4	
record		suc, vser, 4	
recordend	rs, suc


do_suc:					; Set Unit  Characteristics

	push	yl
	push	yh
	movw	yh:yl, r25:r24
;
;	Hier den entsprechenden code einfügen
;	
	movw	r25:r24, yh:yl
	call	put_packet
	pop	yh
	pop	yl
	ret
