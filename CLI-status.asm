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

	clc
	ret


