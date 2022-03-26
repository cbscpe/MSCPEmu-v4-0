;--------------------------------------------------------------------------
;
;	Action routines 
;
;	Input:
;	X	Points to the input buffer past the syntax element this
;		pointer must return a valid buffer pointer if it retunrs
;		with success, normally an action routine must not alter
;		the input buffer pointer but in some cases it can be
;		usefull to do the own scanning for syntax elements
;	scanresult 
;		a 4 byte buffer that contains information about the scanned
;		element. In case of a string it has the start address and
;		the length and in case of numbers it contains the value of
;		the converted number as a 32-bit integer
;	Output:
;	CC	Syntax Element has been accepted
;	CS	Syntax Element has been rejected
;	X	input buffer pointer for further scanning, ignored if syntax element
;		has been rejected
;
;	Note that the calling module 'tparse' is not making any assumption regarding
;	saved registers. Action Routine only need to retunr a valid X pointer if
;	the syntax element has been accepted, else any register can be altered. 
;	However we still should adhere to the ABI standard, that is the following
;	registers need to be preserved: r0..15, yl, yh (aka r28 and r29).
;
;--------------------------------------------------------------------------
a_cd:
	push	xl
	push	xh
	lds	xl, scanresult+0
	lds	xh, scanresult+1
	lds	r17, scanresult+2
	sts	cdstring+0, xl
	sts	cdstring+1, xh
	add	xl, r17
	adc	xh, zero
	sts	cdstring+2, xl
	sts	cdstring+3, xh
	pop	xh
	pop	xl
	clc
	ret

a_dev:
	lds	r18, scanresult+2
	cpi	r18, units
	brlo	a_dev010
	sec
	ret
a_dev010:
	sts	attunit, r18
	clc
	ret

a_par:
	lds	r18, scanresult+2
	sts	attpart, r18
	clc
	ret
	
a_mon:
	push	xl
	push	xh
	push	zl
	push	zh
	ld	r24, X
	lds	xl, scanresult+0
	lds	xh, scanresult+1
	movw	r25:r24, xh:xl		; Save start of monitor commands

a_mon010:
	ld	r16, X+			; Search for end-of-line
	cpi	r16, CR			; CR
	breq	a_mon020		; we are done
	tst	r16			; NULL
	brne	a_mon010		; no
	ldi	r16, CR			; replace NULL with CR
a_mon020:
	st	-X, r16			; Adjust X and write end-of-line
;
;	sts	pprint+0, r24		; debugging
;	sts	pprint+1, r25
;	sts	pprint+2, xl
;	sts	pprint+3, xh
;	call	print
;	.db	CR, LF, "Fakemon buffer 0x", 0x81, 0x80, " -> 0x", 0x83, 0x82, CR, LF, 0
;
	call	fakemon
	pop	zh
	pop	zl
	pop	xh
	pop	xl
	clc
	ret

a_nbr:
	lds	r18, scanresult+0
	sts	nbr+0, r18
	lds	r18, scanresult+1
	sts	nbr+1, r18
	lds	r18, scanresult+2
	sts	nbr+2, r18
	lds	r18, scanresult+3
	sts	nbr+3, r18
	clc
	ret
	
set_no:
	lds	r18, tpflags
	ori	r18, (1<<tp__no)
	sts	tpflags, r18
	clc
	ret
;
;	Dump First Block of Unit
;
a_dumpblknbr:
	lds	r18, scanresult+0
	sts	dumpblock+0, r18
	lds	r18, scanresult+1
	sts	dumpblock+1, r18
	lds	r18, scanresult+2
	sts	dumpblock+2, r18
	lds	r18, scanresult+3
	sts	dumpblock+3, r18
	clc
	ret

a_dirinit:
	sts	dirswitch, zero
	clc
	ret

a_dirswa:
	lds	r18, dirswitch
	ori	r18, (1<<dirswitch_a)
	sts	dirswitch, r18
	clc
	ret

a_dumpinit:
	sts	dumpswitch, zero
	sts	dumpblock+0, zero
	sts	dumpblock+1, zero
	sts	dumpblock+2, zero
	sts	dumpblock+3, zero
	clc
	ret

a_dumpswr:
	lds	r18, dumpswitch
	ori	r18, (1<<dumpswitch_r)
	sts	dumpswitch, r18
	clc
	ret	

a_dumpswc:
	lds	r18, dumpswitch
	ori	r18, (1<<dumpswitch_c)
	sts	dumpswitch, r18
	clc
	ret	

a_dumpswb:
	lds	r18, dumpswitch
	ori	r18, (1<<dumpswitch_b)
	sts	dumpswitch, r18
	clc
	ret	

a_dumpdev:
	lds	r18, scanresult+2
	cpi	r18, units
	brlo	a_dumpdev010
	sec
	ret
a_dumpdev010:
	sts	dumpunit, r18
	clc
	ret
;--------------------------------------------------------------------------
;
a_dmaaddr:
	lds	r18, scanresult+0
	sts	dmaaddr+0, r18
	lds	r18, scanresult+1
	sts	dmaaddr+1, r18
	lds	r18, scanresult+2
	sts	dmaaddr+2, r18
	clc
	ret

;--------------------------------------------------------------------------
;
	
;--------------------------------------------------------------------------
;
;	port % [set|clear|toggle|output|input] n
;
a_port:
	lds	r16, scanresult+2	; Convert the port character to uppercase
	cpi	r16, 0x60
	brlo	a_portuc
	andi	r16, 0x5f
a_portuc:
	sts	portname, r16		; Save it for later
	subi	r16, 'A'		; Valid port names are A...G
	brmi	a_portinv		; any character less than 'A' is invalid
	cpi	r16, 7			; And everthing higher than 'G' as well
	brsh	a_portinv
	swap	r16			; 
	lsl	r16			; Port ID * 0x20 gives offset to ports
	sts	portaddr, r16
	clc
	ret

a_portinv:
	call	print
	.db	CR, LF
	.db	"Invalid Port ", CR, LF, 0
	sec
	ret				; 
;
;	Set port action
;
a_porttoggle:
	lds	r16, scanresult
	cpi	r16, 8			; Pinnumber must be between 0..7
	brsh	a_portinvpin
	sts	portbit, r16
	ldi	r16, 'T'
	sts	portaction, r16
	clc
	ret	

a_portset:
	lds	r16, scanresult
	cpi	r16, 8
	brsh	a_portinvpin
	sts	portbit, r16
	ldi	r16, 'S'
	sts	portaction, r16
	clc
	ret	

a_portclr:
	lds	r16, scanresult
	cpi	r16, 8
	brsh	a_portinvpin
	sts	portbit, r16
	ldi	r16, 'C'
	sts	portaction, r16
	clc
	ret	
	
a_portoutput:
	lds	r16, scanresult
	cpi	r16, 8
	brsh	a_portinvpin
	sts	portbit, r16
	ldi	r16, 'O'
	sts	portaction, r16
	clc
	ret	
	
a_portinput:
	lds	r16, scanresult
	cpi	r16, 8
	brsh	a_portinvpin
	sts	portbit, r16
	ldi	r16, 'I'
	sts	portaction, r16
	clc
	ret	
	
	
a_portinvpin:
	lds	r16, scanresult+0
	lds	r17, scanresult+1
	lds	r18, scanresult+2
	lds	r19, scanresult+3
	sts	pprint+0, r16
	sts	pprint+1, r17
	sts	pprint+2, r18
	sts	pprint+3, r19
	call	print
	.db	CR, LF, "Invalid Pin number", 0xd0, CR, LF, 0
	sec
	ret
;
;	Execute the "port %" command to show the port status
;
cmdportshow:
	lds	zl, portaddr		; Get Port Offset
	ldi	zh, high(PORTA_DIR)	; Add Base Address
	sts	pprint+0, zl		; 
	sts	pprint+1, zh
	lds	r16, portname
	sts	pprint+2, r16
	call	print			; Print basic port info
	.db	CR, LF
	.db	"Port ", 0x92, " (Address 0x", 0x81, 0x80, ") Bits......:"," 76543210", CR, LF
	.db	TAB, TAB, TAB, "Direction.: ", 0
	ldd	r16, Z+PORT_DIR_offset
	ldi	r24, 'I'		; First show direction 
	sbrc	r16, 7
	ldi	r24, 'O'
	call	serout
	ldi	r24, 'I'
	sbrc	r16, 6
	ldi	r24, 'O'
	call	serout
	ldi	r24, 'I'
	sbrc	r16, 5
	ldi	r24, 'O'
	call	serout
	ldi	r24, 'I'
	sbrc	r16, 4
	ldi	r24, 'O'
	call	serout
	ldi	r24, 'I'
	sbrc	r16, 3
	ldi	r24, 'O'
	call	serout
	ldi	r24, 'I'
	sbrc	r16, 2
	ldi	r24, 'O'
	call	serout
	ldi	r24, 'I'
	sbrc	r16, 1
	ldi	r24, 'O'
	call	serout
	ldi	r24, 'I'
	sbrc	r16, 0
	ldi	r24, 'O'
	call	serout
	call	seroutcrlf
	call	print
	.db	TAB, TAB, TAB, "State.....: ", 0
	ldd	r16, Z+PORT_IN_offset	; Then show input state
	ldi	r24, '0'
	sbrc	r16, 7
	ldi	r24, '1'
	call	serout
	ldi	r24, '0'
	sbrc	r16, 6
	ldi	r24, '1'
	call	serout
	ldi	r24, '0'
	sbrc	r16, 5
	ldi	r24, '1'
	call	serout
	ldi	r24, '0'
	sbrc	r16, 4
	ldi	r24, '1'
	call	serout
	ldi	r24, '0'
	sbrc	r16, 3
	ldi	r24, '1'
	call	serout
	ldi	r24, '0'
	sbrc	r16, 2
	ldi	r24, '1'
	call	serout
	ldi	r24, '0'
	sbrc	r16, 1
	ldi	r24, '1'
	call	serout
	ldi	r24, '0'
	sbrc	r16, 0
	ldi	r24, '1'
	call	serout
	call	seroutcrlf
	clc
	ret
;
;	Do all other commands changing individual pins
;
cmdportdo:
	lds	zl, portaddr
	ldi	zh, high(PORTA_DIR)
	sts	pprint+0, zl
	sts	pprint+1, zh
	lds	r16, portname
	sts	pprint+2, r16
	lds	r16, portbit
	sts	pprint+3, r16
	lds	r16, portaction
	cpi	r16, 'T'
	brne	PC+2
	rjmp	cmdporttoggle
	cpi	r16, 'C'
	brne	PC+2
	rjmp	cmdportclr
	cpi	r16, 'S'
	brne	PC+2
	rjmp	cmdportset
	cpi	r16, 'O'
	brne	PC+2
	rjmp	cmdportoutput
	cpi	r16, 'I'
	brne	PC+2
	rjmp	cmdportinput
	rjmp	cmdportunknown

cmdporttoggle:
	call	print
	.db	CR, LF
	.db	"Toggle Bit ", 0x83, " of Port ", 0x92, " (Address 0x", 0x81, 0x80, ")", CR, LF, 0
	rcall	cmdportmask
	std	Z+PORT_OUTTGL_offset, r24
	clc
	ret

cmdportset:
	call	print
	.db	CR, LF
	.db	"Set Bit ", 0x83, " of Port ", 0x92, " (Address 0x", 0x81, 0x80, ")", CR, LF, 0, 0
	rcall	cmdportmask
	std	Z+PORT_OUTSET_offset, r24
	clc
	ret

cmdportclr:
	call	print
	.db	CR, LF
	.db	"Clear Bit ", 0x83, " of Port ", 0x92, " (Address 0x", 0x81, 0x80, ")", CR, LF, 0, 0
	rcall	cmdportmask
	std	Z+PORT_OUTCLR_offset, r24
	clc
	ret
	
cmdportoutput:
	call	print
	.db	CR, LF
	.db	"Output ", 0x83, " of Port ", 0x92, " (Address 0x", 0x81, 0x80, ")", CR, LF, 0
	rcall	cmdportmask
	std	Z+PORT_DIRSET_offset, r24
	clc
	ret

cmdportinput:
	call	print
	.db	CR, LF
	.db	"Input ", 0x83, " of Port ", 0x92, " (Address 0x", 0x81, 0x80, ")", CR, LF, 0, 0
	rcall	cmdportmask
	std	Z+PORT_DIRCLR_offset, r24
	clc
	ret
;
;	Should never happen as we made sure only valid options have been specified 
;	via the command parsing
;
cmdportunknown:
	lds	zl, portaddr
	clr	zh
	sts	pprint+0, zl
	sts	pprint+1, zh
	lds	r16, portname
	sts	pprint+2, r16
	lds	r16, portaction
	sts	pprint+3, r16

	call	print
	.db	CR, LF
	.db	"Unknown Port Command '", 0x93, "' (0x", 0x83, ")"
	.db	" Port ", 0x92, " (Address 0x", 0x81, 0x80, ")",  CR, LF, 0, 0
	sec
	ret
;
;	
;
cmdportmask:				; Convert Bit into Mask
	lds	r16, portbit
	ldi	r24, 1
cmdportmask010:
	tst	r16
	breq	cmdportmask020
	dec	r16
	lsl	r24
	rjmp	cmdportmask010
cmdportmask020:
	ret

;--------------------------------------------------------------------------
;
;
;

a_logentry:
	sts	logdataentryc, zero
	clc
	ret
	
a_logbyte:
	lds	r16, logdataentryc
	cpi	r16, 4
	brlo	a_logbyte010
	sec
	ret
	
a_logbyte010:
	lds	zl, scanresult+0
	lds	zh, scanresult+1
	lds	r17, scanresult+2
	sts	pprint+0, zl
	sts	pprint+1, zh
	sts	pprint+2, r17
	clr	r18
a_logbyte020:
	ld	r24, Z+
	cpi	r24, 0x60		; lower case ?
	brlo	a_logbyte025		; nope
	andi	r24, 0x5F		; Perhaps yes, make sure we have upper case only
a_logbyte025:
	ldi	r16,0x30		; 
	eor	r16,r24			; Convert 
	cpi	r16,0x0A		; was the character between '0' and '9'
	brlo	a_logbyte030		; yes so we have a digit
	subi	r16,-0x89		; Convert so 'A' to 'F' are mapped to 0xFA to 0xFF
	cpi	r16,0xFA		; i.e. the lower nibble correponds to the value
	brsh	a_logbyte030		; If higher than we have a digit
	sec				; no digit just return with Character in char
	ret				; not a hex digit
a_logbyte030:
	lsl	r18
	lsl	r18
	lsl	r18
	lsl	r18
	andi	r16, 0x0F
	or	r18, r16
	dec	r17
	brne	a_logbyte020
	lds	r16, logdataentryc
	mov	zl, r16
	inc	r16
	sts	logdataentryc, r16
	clr	zh
	subi	zl, low(-logdataentry)
	sbci	zh, high(-logdataentry)
	st	Z, r18
	clc
	ret











