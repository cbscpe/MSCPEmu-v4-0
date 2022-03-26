;=============================================================================
;
;	General CLI command routines	
;
;--------------------------------------------------------------------------
;
;	Print out the number entred via the number command as 32-bit 
;	integer. This is to check that the scanning for a number element
;	is done correctly.
;
prtnbr:
	lds	r18, nbr+0
	sts	pprint+0, r18
	lds	r18, nbr+1
	sts	pprint+1, r18
	lds	r18, nbr+2
	sts	pprint+2, r18
	lds	r18, nbr+3
	sts	pprint+3, r18

	call	print
	.db	CR, LF, "Number is:", 0xd0, " As PDP-11 Address ", 0xb0, 0

	clc
	ret

;--------------------------------------------------------------------------
;
;	load	- load binary to PDP-11 Memory (currently only bootROM)
;
loadboot:
	ldi	r24, low(dmalock)
	ldi	r25, high(dmalock)
	call	acquire
	lds	r22, nbr+0
	lds	r23, nbr+1
	lds	r24, nbr+2
	clr	r25			; Now using ABI
	andi	r22, 0xFE		;
	andi	r24, 0x3F		; We need an even 22-bit address for DMA Read
	sts	pprint+0, r22
	sts	pprint+1, r23
	sts	pprint+2, r24
	call	print
	.db	CR, LF
	.db	"LOAD Address: ", 0xb0, CR, LF, 0
	setupdmaaddress	r22, r23, r24	
	ldi	zl, low(rom173000)
	ldi	zh, high(rom173000)
	clr	r17
loadboot010:
	ld	r24, Z+
	ld	r25, Z+
;	sts	pprint+0, r24
;	sts	pprint+1, r25
;	call	print
;	.db	0xa0, CR, LF, 0
	dmawrite r24, r25
	brcs	loadbooterror
	dec	r17
	brne	loadboot010
	ldi	r24, low(dmalock)
	ldi	r25, high(dmalock)
	call	release
	clc
	ret

loadbooterror:
	rjmp	loaderror


loadtest:
	ldi	r24, low(dmalock)
	ldi	r25, high(dmalock)
	call	acquire
	lds	r22, nbr+0
	lds	r23, nbr+1
	lds	r24, nbr+2
	clr	r25			; Now using ABI
	andi	r22, 0xFE		;
	andi	r24, 0x3F		; We need an even 22-bit address for DMA Read
	sts	pprint+0, r22
	sts	pprint+1, r23
	sts	pprint+2, r24
	call	print
	.db	CR, LF
	.db	"LOAD Address Test: ", 0xb0, CR, LF, 0, 0
	setupdmaaddress	r22, r23, r24	
	ldi	zl, low(romtest)
	ldi	zh, high(romtest)
	ldi	r17, romtestsize
loadtest010:
	ld	r24, Z+
	ld	r25, Z+
;	sts	pprint+0, r24
;	sts	pprint+1, r25
;	call	print
;	.db	0xa0, CR, LF, 0
	dmawrite r24, r25
	brcs	loadtesterror
	dec	r17
	brne	loadtest010
	ldi	r24, low(dmalock)
	ldi	r25, high(dmalock)
	call	release
	clc
	ret

loadtesterror:
	rjmp	loaderror

loaderror:
	ldi	r24, low(dmalock)
	ldi	r25, high(dmalock)
	call	release
	sbi	b_ABO
	cbi	b_ABO
	cbi	b_DMR
	call	mprint
	.dw	msgloaderr
	sec
	ret

;--------------------------------------------------------------------------
;
;	self reset processor
;
cmdreset:
	ldi	r16, 0xa5
	ldi	r17, 0x5a
	ldi	r18, GPR_GPR0
	ldi	r19, GPR_GPR1
	sts	RE_STATUS, r16
	sts	RE_SD_STATUS, r17
	sts	RE_GPR0, r18
	sts	RE_GPR1, r19

	ldi	r18, CPU_CCP_IOREG_gc
	sts	CPU_CCP, r18
	ldi	r18, RSTCTRL_SWRST_bm
	sts	RSTCTRL_SWRR, r18
	clc
	ret

;--------------------------------------------------------------------------
;
;	set DMA address
;
cmddmaaddr:
	sts	dmaflag+0, zero
	clc	
	ret
;
;	read a word via DMA from PDP-11
;	
cmddmaread:
	lds	r16, dmaflag+0
	cpi	r16, 0
	brne	cmddmaread010
	inc	r16
	sts	dmaflag+0, r16
	lds	r22, dmaaddr+0
	lds	r23, dmaaddr+1
	lds	r24, dmaaddr+2
	andi	r22, 0xFE
	andi	r24, 0x3F
	sts	pprint+0, r22
	sts	pprint+1, r23
	sts	pprint+2, r24
	ori	r22, 0x01		; Read
	call	print
	.db	CR, LF
	.db	"DMA - Set Address   ", 0xb0, 0
	setupdmaaddress r22, r23, r24
cmddmaread010:
	dmaread	r24, r25
	sts	pprint+0, r24
	sts	pprint+1, r25
	call	print
	.db	CR, LF
	.db	"DMA - Read Data     ", 0xa0, CR, LF, 0
	clc
	ret
;
;	write a word via DMA to PDP-11
;
cmddmawrite:
	lds	r16, dmaflag+0
	cpi	r16, 0
	brne	cmddmawrite010
	inc	r16
	sts	dmaflag+0, r16
	lds	r22, dmaaddr+0
	lds	r23, dmaaddr+1
	lds	r24, dmaaddr+2
	andi	r22, 0xFE
	andi	r24, 0x3F
	sts	pprint+0, r22
	sts	pprint+1, r23
	sts	pprint+2, r24
	call	print
	.db	CR, LF
	.db	"DMA - Set Address ", 0xb0, 0
	setupdmaaddress r22, r23, r24
cmddmawrite010:
	lds	r24, nbr+0
	lds	r25, nbr+1
	sts	pprint+0, r24
	sts	pprint+1, r25
	dmawrite r24, r25
	call	print
	.db	CR, LF
	.db	"DMA - write Data    ", 0xa0, CR, LF, 0
	clc
	ret
;
;	Write a block from MCU address to DMA address and read it
;	back after the block of 512bytes in the MCU memory
;	
cmddmatest:
	lds	r22, dmaaddr+0
	lds	r23, dmaaddr+1
	lds	r24, dmaaddr+2
	andi	r22, 0xFE
	andi	r24, 0x3F
	sts	pprint+0, r22
	sts	pprint+1, r23
	sts	pprint+2, r24
	call	print
	.db	CR, LF
	.db	"DMA - Set Address ", 0xb0, 0
	setupdmaaddress r22, r23, r24


	lds	xl, nbr+0
	lds	xh, nbr+1	
	clr	r17
cmddmatest010:
	ld	r24, X+
	ld	r25, X+
	dmawrite r24, r25
	adiw	r25:r24, 2
	dec	r17
	brne	cmddmatest010
	
	
	lds	r22, dmaaddr+0
	lds	r23, dmaaddr+1
	lds	r24, dmaaddr+2
	andi	r22, 0xFE
	ori	r22, 0x01
	andi	r24, 0x3F
	sts	pprint+0, r22
	sts	pprint+1, r23
	sts	pprint+2, r24
	setupdmaaddress r22, r23, r24

cmddmatest020:
	dmaread	r24, r25
	st	X+, r24
	st	X+, r25
	dec	r17
	brne	cmddmatest020
	clc
	ret
;--------------------------------------------------------------------------
;
;	
;	
cmdmemtest:
	lds	r22, nbr+0
	lds	r23, nbr+1
	lds	r24, nbr+2
	andi	r22, 0xFE
	andi	r24, 0x3F
	sts	pprint+0, r22
	sts	pprint+1, r23
	sts	pprint+2, r24
	call	print
	.db	CR, LF
	.db	"Memory Test - Set Address ", 0xb0, 0
	setupdmaaddress r22, r23, r24	; DMA Macro's destry r18
;
;	Write 512 words to PDP-11 Memory
;
	ldi	r24, low(512)
	ldi	r25, high(512)
	ldi	xl, low(531)
	ldi	xh, high(531)	; just a number
cmdmemtest010:
	dmawrite xl, xh
	adiw	xh:xl, 1
	sbiw	r25:r24, 1
	brne	cmdmemtest010

	lds	r22, nbr+0
	lds	r23, nbr+1
	lds	r24, nbr+2
	ori	r22, 0x01
	andi	r24, 0x3F
	setupdmaaddress r22, r23, r24	; DMA Macro's destry r18

	ldi	r24, low(512)
	ldi	r25, high(512)
	ldi	zl, low(0x5000)		; Test Memory
	ldi	zh, high(0x5000)	; Test Memory
cmdmemtest020:
	dmaread	r16, r17
	st	Z+, r16
	st	Z+, r17
	sbiw	r25:r24, 1
	brne	cmdmemtest020
	

	ldi	r24, low(512)
	ldi	r25, high(512)
	ldi	xl, low(531)
	ldi	xh, high(531)		; just a number
	ldi	zl, low(0x5000)		; Test Memory
	ldi	zh, high(0x5000)	; Test Memory
	ldi	r23, 32			; error counter

cmdmemtest030:
	movw	r19:r18, zh:zl		; Save Address
	ld	r16, Z+
	ld	r17, Z+
	cp	r16, xl
	cpc	r17, xh
	breq	cmdmemtest040
	dec	r23
	breq	cmdmemtest090		; Error overflow

	rcall	cmdmemtesterror
cmdmemtest040:
	adiw	xh:xl, 1
	sbiw	r25:r24, 1
	brne	cmdmemtest030
cmdmemtest090:
	subi	r23, 32
	neg	r23
	sts	pprint+0, r23
	call	print
	.db	CR, LF
	.db	"Memory Test found 0x", 0x80, " Errors.", CR, LF, 0
	clc
	ret

cmdmemtesterror:
	sts	pprint+0, r16		; Read value
	sts	pprint+1, r17
	sts	pprint+2, xl		; Expected value
	sts	pprint+3, xh
	sts	pprint+4, r18		; MCU memory address
	sts	pprint+5, r19

	lds	r20, nbr+0
	lds	r21, nbr+1
	lds	r22, nbr+2
	andi	r20, 0xFE
	andi	r21, 0x3F
	andi	r19, 0x0F
	add	r20, r18
	adc	r21, r19
	adc	r22, zero
	sts	pprint+6, r20
	sts	pprint+7, r21
	sts	pprint+8, r22
	call	print
	.db	CR, LF
	.db	"Memory Test Error at PDP-11 Address 0", 0xb6, " Read 0x"
	.db	0x81, 0x80, "- MCU Address 0x", 0x85, 0x84, " Expected 0x"
	.db	0x83, 0x82, CR, LF, 0, 0
	ret


;--------------------------------------------------------------------------
;
;
;	
cmdcontbsy:
	cbi	b_CRDY
	clc
	ret
	
cmdcontrdy:
	sbi	b_CRDY
	clc
	ret
;--------------------------------------------------------------------------
;
;
;	
cmdpointer:
	ldi	r24, low(1536)
	ldi	r25, high(1536)
	ldi	zl, low(log_buffer)
	ldi	zh, high(log_buffer)
cmdpointer010:
	sts	pprint+0, zl
	sts	pprint+1, zh
	call	print
	.db	CR, LF, "Pointer 0x", 0x81, 0x80, 0, 0

	adiw	zh:zl, 4
;	sbrc	zh,7
;	ori	zh, 0x08
	andi	zh, high(log_size) 	; 1
	ori	zh, high(log_buffer)	; 1
	
	sbiw	r25:r24, 1
	brne	cmdpointer010
	clc
	ret
