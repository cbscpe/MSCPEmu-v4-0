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
	clc
	ret


