;--------------------------------------------------------------------------
;
;	Show Status
;
.macro	bytestatus
	call	print
.if (STRLEN(@0)&1)
.db	@0, 0x00
.else
.db	@0, 0x00, 0x00
.endif
	lds	r24, @1
	sts	pprint+0, r24
	call	print
	.db	" 0x", 0x80, CR, LF, 0, 0
.endmacro

.macro	wordstatus
	call	print
.if (STRLEN(@0)&1)
.db	@0, 0x00
.else
.db	@0, 0x00, 0x00
.endif
	lds	r24, @1+0
	sts	pprint+0, r24
	lds	r24, @1+1
	sts	pprint+1, r24
	call	print
	.db	" 0x", 0x81, 0x80, CR, LF, 0
.endmacro


printstatus:
	call	seroutcrlf
	bytestatus	"nguard        ", nguard
	wordstatus	"log_pointer   ", log_pointer
#ifdef testout
	wordstatus	"tesoutptr     ", tesoutptr
#endif
	wordstatus	"heap          ", heap
	wordstatus	"              ", heap+2
	
	call	print
	.db	"SD-Card Turbo ..................:", 0
	in	r24, FLAGS_LOG
	bst	r24, log__turbo
	call	logstatusonoff
	cli
	lds	r16, sysuptime+0
	lds	r17, sysuptime+1
	lds	r18, sysuptime+2
	lds	r19, sysuptime+3
	sei
	sts	pprint+0, r16
	sts	pprint+1, r17
	sts	pprint+2, r18
	sts	pprint+3, r19
	call	print
	.db	"SysUpTime ......................:", 0xd0, "s", CR, LF, 0

;
;	Calculate DAYs
;
	clr	r24
	clr	r25
printstatus010:
	subi	r16, byte1(86400)
	sbci	r17, byte2(86400)
	sbci	r18, byte3(86400)
	sbci	r19, byte4(86400)
	brmi	printstatus020
	adiw	r25:r24, 1
	rjmp	printstatus010

printstatus020:
	sts	pprint+0, r24		; Store DAYs
	sts	pprint+1, r25
	subi	r16, byte1(-86400)	; Compensate surplus subtract
	sbci	r17, byte2(-86400)
	sbci	r18, byte3(-86400)
	sbci	r19, byte4(-86400)
;
;	Calculate HOURs
;
	clr	r24
printstatus030:
	subi	r16, byte1(3600)
	sbci	r17, byte2(3600)
	sbci	r18, byte3(3600)
	sbci	r19, byte4(3600)
	brmi	printstatus040
	inc	r24
	rjmp	printstatus030

printstatus040:
	rcall	printcvtbyte
	sts	pprint+2, r24		; Store HOURs
	subi	r16, byte1(-3600)	; Compensate surplus subtract
	sbci	r17, byte2(-3600)
	sbci	r18, byte3(-3600)
	sbci	r19, byte4(-3600)
;
;	Calculate MINUTEs
;
	clr	r24
printstatus050:
	subi	r16, byte1(60)
	sbci	r17, byte2(60)
	brmi	printstatus060
	inc	r24
	rjmp	printstatus050

printstatus060:
	rcall	printcvtbyte
	sts	pprint+3, r24		; Store MINUTESs
	subi	r16, byte1(-60)		; Compensate surplus subtract
	sbci	r17, byte2(-60)
	mov	r24, r16
	rcall	printcvtbyte
	sts	pprint+4, r24		; Store SECONDs

	call	print
	.db	"SysUpTime ......................:", 0xc0, " Days ", 0x82, ":", 0x83, ":", 0x84, CR, LF, 0

	clc
	ret

;
;
;
printcvtbyte:
	push	r25
	clr	r25
printcvtbyte010:
	subi	r24, 10
	brcs	printcvtbyte020
	subi	r25, -10
	rjmp	printcvtbyte010
printcvtbyte020:
	subi	r24, -10
	add	r24, r25
	pop	r25
	ret

