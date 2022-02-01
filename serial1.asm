	.cseg
;--------------------------------------------------------------------------
;
;	Interrupt driven serial input and output routines with a transmit and
;	a receive ring buffer. The ring buffers one page of 256bytes long
;	so pointers and counters are just 8 bits long. Each ring buffer has 
;	three variables associated.
;	An insert pointer, a remove pointer and a count. If count is zero the
;	ring buffer is empty, if count is 0xFF the ring buffer is full.
;	The transmitter uses the data register empty interrupt which is more
;	suitable for this scenario. In this way the serout routine only waits
;	for the transmit ring buffer not being full, then inserts the byte
;	increments the count and insert pointer and then activates the data
;	register empty interrupt.
;
;	Interrupt routines must not make any system calls, if an interrupt
;	has to make a system call it must push the registers zh and zl onto
;	the stack (first zh then zl), restore any previously changed status
;	register to the pre interrupt state, load the address of the user interrupt 
;	service routine into zh:zl and jmp to the intdis (interrupt dispatcher)
;	The interrupt dispatcher will then call the user interrupt service
;	routine which is allowed to make system calls like unblock.
;
;	Interrupt routines may end with a jump to unblocki with the stack
;	set up as follows
; SP--->
;	.byte	1	; zl
;	.byte	1	; zh
;	.byte	1	; R8
;	.byte	1	; pch	
;	.byte	1	; pcl
;
;	R8 contains the saved SREG value and Z pointing to the lock word
;
;	2021-11-27	Activate ABI
;--------------------------------------------------------------------------

;
;	Data Register Empty Interrupt, i.e. another character may be sent to USART
;
dre1_isr:				;;;
	push	r8
	in	r8, CPU_SREG		;;; Save status  
	push	zh			;;; Save registers
	push	zl			;;; 
	push	yh
	push	yl

	lds	zl, tx1cnt		;;; Get number of characeters in ring buffer
	dec	zl			;;; 
	sts	tx1cnt, zl		;;; 
	brne	dre1_isr_next		;;; There are still more
	lds	zl, USART1_CTRLA	;;; If this is the last character in the ring
	cbr	zl, USART_DREIE_bm	;;; we clear the data register empty interrutp
	sts	USART1_CTRLA, zl	;;; 
dre1_isr_next:				;;; 

	lds	zl, tx1outptr		;;; Note that we only get DRE interrupts
	inc	zl			;;; if there is at least one characeters in the
	sts	tx1outptr, zl		;;; transmit ring buffer
	clr	zh			;;;
	subi	zl, low(-tx1ring)	;;;
	sbci	zh, high(-tx1ring)	;;; calculate address of character to send 
	ld	yl, Z			;;; get character
	sts	USART1_TXDATAL, yl	;;; send character
	ldi	zl, low(serout1)
	ldi	zh, high(serout1)
	rjmp	unblocki		;;; Unblock waiting job and sysret
;--------------------------------------------------------------------------
;
;
;
serout_1:
	push	zl
	push	zh
serout_1wait:
	cli
	lds	zl, tx1cnt		;;; 3 Get number of characters in buffer
	inc	zl			;;; 1 We want to add a character
	brne	serout_1nowait		;;; 1 Not full, so we will not wait
	
	sei				;;; 1	-> 6 cycles ~0.19usec
	push	r25			;
	push	r24			;
	ldi	r24, low(serout1)	;
	ldi	r25, high(serout1)	;
	call	block			;
	pop	r24			;
	pop	r25			;

	rjmp	serout_1wait		; Then wait until there is room

serout_1nowait:				;;; 6
	sts	tx1cnt, zl		;;; 2 There is space in ring buffer
	lds	zl, tx1inptr		;;; 3 Get input pointer
	inc	zl			;;; 1
	sts	tx1inptr, zl		;;; 2 Update input pointer
	clr	zh			;;; 1
	subi	zl, low(-tx1ring)	;;; 1
	sbci	zh, high(-tx1ring)	;;; 1
	st	Z, r24			;;; 2
	lds	zl, USART1_CTRLA	;;; 3 Activate the data register empty
	sbr	zl, USART_DREIE_bm	;;; 1 interrupt so the ISR picks up the
	sts	USART1_CTRLA, zl	;;; 2 queued character(s)
	sei				;;; 1	-> 25 cycles ~0.78usec
	pop	zh			;
	pop	zl			;
	ret
;--------------------------------------------------------------------------
;
;	Receive Complete Interrupt
;
rxc1_isr:
	push	r8			;;;
	in	r8, CPU_SREG		;;; Save status 
	push	zh			;;; Save Registers used
	push	zl			;;;
	push	yh
	push	yl

	lds	yl, USART1_RXDATAL	;;; Retrieve the character
	lds	zl, rx1cnt		;;; Check the received character count
	inc	zl			;;; Add a character
	breq	rxc1_overflow		;;; Buffer full so ignore it
	sts	rx1cnt, zl		;;; one more
	lds	zl, rx1inptr		;;; get index into ring buffer
	inc	zl			;;; update index
	sts	rx1inptr, zl		;;;
	clr	zh			;;; make it 16-bit offset
	subi	zl, low(-rx1ring)	;;; add buffer start
	sbci	zh, high(-rx1ring)	;;;
	st	Z, yl			;;; save characters
rxc1_overflow:
	ldi	zl, low(serin1)
	ldi	zh, high(serin1)
	rjmp	unblocki		;;; Unblock waiting job and sysret

;--------------------------------------------------------------------------
;
;	The task dispatcher is currently linked to the serin routine. 
;
serin_1:
	push	zl			; Save registers
	push	zh
serin_1wait:
	cli				; block interrupts
	lds	zl, rx1cnt		;;; 3 check number of characters in rx input
	tst	zl			;;; 1 ring buffer
	brne	serin_1nowait		;;; 1 we have one
	
	sei				;;; 1	-> 6 cycles ~0.19usec
	push	r25			;
	push	r24			;
	ldi	r24, low(serin1)	; else wait for input
	ldi	r25, high(serin1)	;
	call	block			;
	pop	r24			;
	pop	r25			;
	rjmp	serin_1wait		; retry

serin_1nowait:				;;; 6
	lds	zl, rx1cnt		;;; 3 get count
	dec	zl			;;; 1 and remove one character
	sts	rx1cnt, zl		;;; 2 
	lds	zl, rx1outptr		;;; 3 get rx ring read pointer
	inc	zl			;;; 1
	sts	rx1outptr, zl		;;; 2 we to a pre-increment now
	clr	zh			;;; 1 make it a 16-bit offset
	subi	zl, low(-rx1ring)	;;; 1 add receive ring buffer base
	sbci	zh, high(-rx1ring)	;;; 1
	ld	r24, Z			;;; 2 get character
	sei				;;; 1	-> 24 cycles ~0.75usec
	pop	zh			;
	pop	zl			;
	ret
;--------------------------------------------------------------------------
;
;	Force redraw of line at prompt by inserting a ^R
;
;	Input:
;		none
;	Registers:
;		r24, r25, zl, zh
;
#define CTRL_R 0x12
redraw_1:
	cli
	lds	zl, rx1cnt		;;; 3 Check the received character count
	inc	zl			;;; 1 Add a character
	breq	redraw_1v		;;; 1 Buffer full so ignore it should not happen
	sts	rx1cnt, zl		;;; 2 one more
	lds	zl, rx1inptr		;;; 3 get index into ring buffer
	inc	zl			;;; 1 update index
	sts	rx1inptr, zl		;;; 1
	clr	zh			;;; 1 make it 16-bit offset
	subi	zl, low(-rx1ring)	;;; 1 add buffer start
	sbci	zh, high(-rx1ring)	;;; 1
	ldi	r24, CTRL_R		;;; 1 Redraw character
	st	Z, r24			;;; 2 save characters
	sei				;;; 1	-> 19 cycles ~0.6usec

	ldi	r24, low(serin1)
	ldi	r25, high(serin1)
	rjmp	unblock			; Unblock waiting job and return

redraw_1v:				;;; 6
	sei				;;; 1	-> 7 cycles ~0.22usec
	ret	
	
	