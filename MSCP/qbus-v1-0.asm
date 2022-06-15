;=============================================================================
;
;	Q-Bus Interface for a MSCP port / controller
;

;	An MSCP controller has only two registers the IP and the SA
;	registers. 
;
;	IP	Initializing and Polling
;
;		When written it causes a hard reset of the port and
;		the controller
;
;		When read while the port is operting, it causes the
;		controller to initiate polling, this will set b_POLL
;
;	The values read and written are not important
;
;	SA	Status Address and Purge
;
;		When read it just reads the current value of SAR
;		When written we just increment the sawflag
;
;--------------------------------------------------------------------------
;
;	Register Convention
;	Y	Register Value
;	Z	Pointer, Temporary Register
;
qbus_:					; 4-5
	push	r8			; 1 save
	in	r8, CPU_SREG		; 1  save
	push	zh			; 1 save
	push	zl			; 1 save
	push	yh			; 1  save
	push	yl			; 1 save
	sbi	b_SIG			; 1
	sbic	f_INTI			; 2/1
	rjmp	qbus_iack		; 0/2
	sbic	f_INTQ			; 2/1
	rjmp	qbus_intq		; 0/2
	sbic	f_INIT			; 2/1
	rjmp	qbus_init		; 0/2


;	Pulse Legend
;	1	INTQ
;	2	INTI
;	3	INIT
;	4	Busy
;	5	Spurious Interrupt
;	6	Card Detect Job
;	7	RLV12 Processing finished
;
	pulse				; Signal spuriuous interrupt
	pulse
	pulse
	pulse
	pulse

	pop	yl			; 2 restore
	pop	yh			; 2 restore
	pop	zl			; 2 restore
	pop	zh			; 2 restore
	out	CPU_SREG, r8		; 1 restore
	pop	r8			; 2 restore
	cbi	b_SIG			; 1 fin
	reti


;
;	Dispatch Q-Bus DATI/DATO
;
qbus_intq:
	
	pulse				; 6 always signal a Q-Bus interrupt

	ldi	zl, 0x00		; 1 Data Bus Direction -> Input
	out	dataportdir, zl		; 1
	sbi	b_RD			; 1
	cbi	b_RS0			; 1
	cbi	b_RS1			; 1
	sbi	b_RS2			; 1 Read Register 4 = Device Register Address
	nop				; 1
	nop				; 1
	nop				; 1
	in	zl, dataportin		; 1
	andi	zl, 0x03		; 1 Get BDAL1 and BWTBT 
	clr	zh			; 1
	subi	zl, low(-qbus_jmptbl)	; 1
	sbci	zh, high(-qbus_jmptbl)	; 1
	ijmp				; 2


qbus_jmptbl:
	rjmp	qbus_dati_ip		; 2 -> ~27 cycles
	rjmp	qbus_dato_ip

	rjmp	qbus_dati_sa
	rjmp	qbus_dato_sa


;------------------------------------------------------------------------------
;
;	IP	1772150
;
qbus_dati_ip:
	lds	zl, iprflag
	inc	zl
	sts	iprflag, zl
	sbi	b_GO			; 1 Start Poll
	clr	yl
	clr	yh
	DATI
	INTEXIT	log_dati|log_ip
	
;
;	Writing the IP register should re-initialize the controller
;	not sure how we want to do it. Just resetting the controller
;	will not work as there are some routines that must be ommitted
;	e.g. you cannot initialise a SD-Card without power-cycle.
;
;	Therefore the startup now must first read the reset flags
;	and then clear them and then check if the reset was due to
;	Power-On, Software-Reset, UPDI, etc. and in case of software
;	reset make a soft restart.
;
;	Perhaps the soft reset needs to be connected to a software
;	interrupt as we must not interrupt Level0 actions.
;
qbus_dato_ip:
	DATO
	sts	ipw+0, yl		; 2
	sts	ipw+1, yh		;
	sbi	b_ACK
	nop
	cbi	b_ACK

;	sbi	b_IPW
;	INTEXIT	log_dato|log_ip
	
	ldi	yl, CPU_CCP_IOREG_gc
	sts	CPU_CCP, yl
	ldi	yl, RSTCTRL_SWRST_bm
	sts	RSTCTRL_SWRR, yl	; Restart the whole system
	rjmp	PC			; We should never end here :-)
;------------------------------------------------------------------------------
;
;	SA	1772152
;
qbus_dati_sa:
	lds	yl, sar+0		; 1
	lds	yh, sar+1		; 1
	DATI
	INTEXIT	log_dati|log_sa
	
	
qbus_dato_sa:
	DATO
	sts	saw+0, yl		; 2
	sts	saw+1, yh		;
	lds	zl, sawflag		;
	inc	zl			;
	sts	sawflag, zl		;
	INTEXIT	log_dato|log_sa

;--------------------------------------------------------------------------
;
;	IACK
;
;
qbus_iack:
	cbi	b_IRQ			; 1 De-assert IRQ
	lds	yl, vector+0		; 3
	lds	yh, vector+1		; 3
	#if cpldif==40
	cbi	b_RS0			; 1	Q-Bus Register
	cbi	b_RS1			; 1	Q-Bus Register
	cbi	b_RS2			; 1	Q-Bus Register
	out	dataportout, yl		; 1
	sbi	b_WR			; 1
	cbi	b_WR			; 1
	sbi	b_RS0			; 1
	out	dataportout, yh		; 1
	sbi	b_WR			; 1
	cbi	b_WR			; 1
	#endif
	#if cpldif==22
	cbi	b_RA0			; 1 Clear Write Sequence	RA='b'00
	cbi	b_RA1			; 1
	sbi	b_RA1			; 1 Select Q-Bus Data Regiser	RA='b'01
	out	dataportout, yl		; 1
	sbi	b_WR			; 1 Latch Q-Bus Data Low
	cbi	b_WR			; 1
	out	dataportout, yh		; 1
	sbi	b_WR			; 1 Latch Q-Bus Data High
	cbi	b_WR			; 1
	#endif
	sbis	GPR_GPR1, log__iack	; 1
	rjmp	qbus_iack_nolog		; 2

	pulse
	pulse

	lds	zl, log_pointer+0	; 3
	lds	zh, log_pointer+1	; 3
	std	Z+2, yl			; 2
	std	Z+3, yh			; 2
	ldi	yl, log_iack		; 1
	std	Z+0, yl			; 2
	lds	yl, timestamp		; 3
	std	Z+1, yl			; 2
	adiw	zh:zl, 4		; 2 
	sbrc	zh, log_overflow
	subi	zh, high(log_size)
	sts	log_pointer+0, zl	; 2 
	sts	log_pointer+1, zh	; 2 
qbus_iack_nolog:
	pop	yl			; 2 restore
	pop	yh			; 2 restore
	pop	zl			; 2 restore
	pop	zh			; 2 restore
	out	CPU_SREG, r8		; 2 restore
	pop	r8			; 2 restore

	sbi	b_ACK			; 1
	cbi	b_ACK			; 1
	cbi	b_SIG			; 1
	sbi	f_INTI			; 1 Assert MCU Interrupt
	reti				; 4	
;--------------------------------------------------------------------------
;
;	Bus INIT
;
;	MSCP Controllers normally do not initialise during a bus reset
;	mostly because they are initialized by the host when it writes
;	the IP register.
;
qbus_init:
	sbi	b_ABO			; BINIT does no longer clear DMA 
	cbi	b_ABO			; so we need to do it in software
	sbi	f_INIT			; 1 Acknowledge BINIT Interrupt 
	sbis	GPR_GPR1, log__iack
	rjmp	qbus_init_nolog

	pulse
	pulse
	pulse

	lds	zl, log_pointer+0	;;; Update logging buffer pointer
	lds	zh, log_pointer+1	;;; 
	in	yl, VPORTE_IN
	in	yh, VPORTE_INTFLAGS
	std	Z+2, yl
	std	Z+3, yh
	ldi	yl, log_init
	std	Z+0, yl
	lds	yl, timestamp
	std	Z+1, yl
	adiw	zh:zl, 4		;;; 
	sbrc	zh, log_overflow
	subi	zh, high(log_size)
	sts	log_pointer+0, zl	;;; 
	sts	log_pointer+1, zh	;;; 
qbus_init_nolog:
;
;	On the falling edge of BINIT (note INIT is inverted BINIT) we need to
;	initialise the registers and reset the controller. When INIT is high
;	(set) the rjmp instruction is skipped and we do the initialisation
;
;	The DCJ11 pauses for 69 cycles between asserting and de-asserting BINIT.
;	A microcycle is 4 clock cycles hence. Our CPU runs at 22Mhz, therefore
;	BINIT is asserted for approx. 12usec. There is enough time to call
;	and execute rlv12_reset
;
	sbic	i_INIT			;;; Skip if BINIT=High i.e. rising edge
	call	mscp_reset		;;; reset MSCP controller
qbus_init_done:
	pop	yl			;; restore
	pop	yh			;; restore
	pop	zl			;; restore
	pop	zh			;; restore
	out	CPU_SREG, r8		;; restore
	pop	r8			;; restore

	sbi	b_ACK			; 1 Acknowledge any pending interrupt
	nop
	cbi	b_ACK			; 1
	nop
	nop
	cbi	b_SIG			; 1
	reti				; 4	
















