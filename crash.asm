;=============================================================================
;
;	crash dump
;
crash:
	cli
	sts	pprint+0, r8		; SREG
	pop	r0			; 2 restore
	pop	r1			; 2 restore
	pop	r2			; 2 restore
	pop	r3			; 2 restore
	pop	r4			; 2 restore
	pop	r5
	pop	r6
	sts	pprint+1, r0		; yl
	sts	pprint+2, r1		; yh
	sts	pprint+3, r2		; zl
	sts	pprint+4, r3		; zh
	sts	pprint+5, r4		; r8
	sts	pprint+6, r5		; pch
	sts	pprint+7, r6		; pcl
	in	r0, CPU_SPL
	in	r1, CPU_SPH
	sts	pprint+8, r0		; spl
	sts	pprint+9, r1		; sph
	in	r0, VPORTA_OUT
	sts	pprint+01, r0
	ldi	r18, low(initialsp)
	out	CPU_SPL, r18
	ldi	r18, high(initialsp)
	out	CPU_SPH, r18
;
;	Set CPU Clock Frequency
;
	ldi	r18, CPU_CCP_IOREG_gc
	sts	CPU_CCP, r18
	ldi	r18, F_CLK
	sts	CLKCTRL_OSCHFCTRLA, r18
;
;	Constants
;
	clr	zero
	out	FLAGS_COMMON, zero
	
	ldi	r18, low(BAUD1)
	sts	USART1_BAUDL, r18
	ldi	r18, high(BAUD1)
	sts	USART1_BAUDH, r18

	ldi	r18, USART_NORMAL_CHSIZE_8BIT_gc
	sts	USART1_CTRLC, r18
	sbi	VPORTB_OUT, TXD		; TXD1
	sbi	VPORTB_DIR, TXD		; TXD1

	ldi	r18, USART_RXEN_bm | USART_TXEN_bm | USART_SFDEN_bm
	sts	USART1_CTRLB, r18

	ldi	r18, 0x00
	sts	USART1_CTRLA, r18

	call	print
	.db	CR, LF
	.db	"PC 0x", 0x86, 0x87, CR, LF, "SP 0x", 0x89, 0x88, CR, LF, "PA 0x", 0x8a, 0, 0

	ldi	xl, low(RAMINITSTART)
	ldi	xh, high(RAMINITSTART)
crash010:
	sts	pprint+0, xl
	sts	pprint+1, xh
	call	print
	.db	CR, LF
	.db	0x81, 0x80, "   - ", 0
	ldi	yl, low(pprint)
	ldi	yh, high(pprint)
	ldi	r18, 16
crash020:
	ld	r0, X+
	st	Y+, r0
	dec	r18
	brne	crash020
	call	print
	.db	0x80, " ", 0x81, " ", 0x82, " ", 0x83, " ", 0x84, " ", 0x85, " ", 0x86, " ", 0x87, " "  
	.db	" ", 0x88, " ", 0x89, " ", 0x8A, " ", 0x8B, " ", 0x8C, " ", 0x8D, " ", 0x8E, " ", 0x8F
	.db	0, 0
	cpi	xh, high(RAMINITSTART+0x1000)
	brlo	crash010
	call	seroutcrlf
	call	seroutcrlf
crashloop:
;	rjmp	crashloop

	ldi	r18, CPU_CCP_IOREG_gc
	sts	CPU_CCP, r18
	ldi	r18, RSTCTRL_SWRST_bm
	sts	RSTCTRL_SWRR, r18
	clc

	ret	



	cbi	FLAGS_COMMON, serin__drv
	cbi	FLAGS_COMMON, serout__drv


	lds	r16, tx1inptr
	lds	r17, tx1outptr
	lds	r18, tx1cnt
	lds	r19, rx1inptr
	lds	r20, rx1outptr
	lds	r21, rx1cnt
	sts	pprint+0, r16
	sts	pprint+1, r17
	sts	pprint+2, r18
	sts	pprint+3, r19
	sts	pprint+4, r20
	sts	pprint+5, r21

	lds	r16, serout1+0
	lds	r17, serout1+1
	lds	r18, serin1+0
	lds	r19, serin1+1

	sts	pprint+6, r16
	sts	pprint+7, r17
	sts	pprint+8, r18
	sts	pprint+9, r19

	call	print
	.db	CR, LF
	.db	"tx inptr 0x", 0x80, " outptr 0x", 0x81, " cnt 0x", 0x82, " lock 0x", 0x87, 0x86, SPACE
	.db	"rx inptr 0x", 0x83, " outptr 0x", 0x84, " cnt 0x", 0x85, " lock 0x", 0x89, 0x88, SPACE
	.db	0, 0
	


	lds	r16, runjob+0
	lds	r17, runjob+1
	lds	r18, curjob+0
	lds	r19, curjob+1
	lds	r20, hibjob+0
	lds	r21, hibjob+1
	sts	pprint+0, r16
	sts	pprint+1, r17
	sts	pprint+2, r18
	sts	pprint+3, r19
	sts	pprint+4, r20
	sts	pprint+5, r21
	
	lds	r16, nguard
	sts	pprint+6, r16
	call	print
	.db	CR, LF
	.db	"runjob: 0x", 0x81, 0x80, CR, LF
	.db	"curjob: 0x", 0x83, 0x82, CR, LF
	.db	"higjob: 0x", 0x85, 0x84, CR, LF
	.db	"nguard: 0x", 0x86, 0
	
	lds	r16, dmalock+0
	lds	r17, dmalock+1
	lds	r18, rlvlock+0
	lds	r19, rlvlock+1
	sts	pprint+0, r16
	sts	pprint+1, r17
	sts	pprint+2, r18
	sts	pprint+3, r19


	lds	r16, pcbqueue+0
	lds	r17, pcbqueue+1
	lds	r18, filequeue+0
	lds	r19, filequeue+1
	lds	r20, volqueue+0
	lds	r21, volqueue+1
	lds	r22, log_pointer+0
	lds	r23, log_pointer+1
	sts	pprint+0, r16
	sts	pprint+1, r17
	sts	pprint+2, r18
	sts	pprint+3, r19
	sts	pprint+4, r20
	sts	pprint+5, r21
	sts	pprint+6, r22
	sts	pprint+7, r23

	
	lds	r16, CSRL
	lds	r17, CSRH
	sts	pprint+0, r16
	sts	pprint+1, r17
	lds	r16, BARL
	lds	r17, BArH
	sts	pprint+2, r16
	sts	pprint+3, r17
	lds	r16, DARL
	lds	r17, DARH
	sts	pprint+4, r16
	sts	pprint+5, r17
	lds	r16, MPRL
	lds	r17, MPRH
	sts	pprint+6, r16
	sts	pprint+7, r17
	lds	r16, BAEL
	lds	r17, BAEH
	sts	pprint+8, r16
	sts	pprint+9, r17
	lds	r16, CSR12+0
	lds	r17, CSR12+1
	sts	pprint+10, r16
	sts	pprint+11, r17
	lds	r16, CSR14+0
	lds	r17, CSR14+1
	sts	pprint+12, r16
	sts	pprint+13, r17
	lds	r16, CSR16+0
	lds	r17, CSR16+1
	sts	pprint+14, r16
	sts	pprint+15, r17
	
	
	lds	r16, heap+0
	lds	r17, heap+1
	lds	r18, heap+2
	lds	r19, heap+3
	sts	pprint+0, r16
	sts	pprint+1, r17
	sts	pprint+2, r18
	sts	pprint+3, r19
	
	
	
	rjmp	PC
	
;--------------------------------------------------------------------------
;
;	hexdump	
;



;
;	JCB
;


;
;	
;
	



















	
	
