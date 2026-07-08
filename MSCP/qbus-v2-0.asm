;--------------------------------------------------------------------------
;
;	High Priority Interrupt to interface with QBUS
;
;	MSCP Emulation
;
;--------------------------------------------------------------------------
;
;
;
	.macro	INTEXIT			; 23/44 cycles
	sbis	FLAGS_LOG, log__reg	; 1/2 
	rjmp	nolog			; 2/0
	lds	zl, log_pointer+0	; 3 Logging is done only if log__reg is set
	lds	zh, log_pointer+1	; 3
	std	Z+2, yl			; 1
	sts	log_previous+2, yl
	std	Z+3, yh			; 1
	sts	log_previous+3, yh
	ldi	yl, @0			; 1
	std	Z+0, yl			; 1
	sts	log_previous+0, yl
	lds	yl, timestamp		; 3
	std	Z+1, yl			; 1
	adiw	zh:zl, 4		; 2
	sbrc	zh, log_overflow	; 2/1
	ldi	zh, high(log_buffer+log_begin)
	sts	log_pointer+0, zl	; 2
	sts	log_pointer+1, zh	; 2
nolog:
	sbi	b_ACK			; 1
	cbi	b_ACK			; 1
	pop	yl			; 2 restore
	pop	yh			; 2 restore
	pop	zl			; 2 restore
	pop	zh			; 2 restore
	out	CPU_SREG, r8		; 2 restore
	pop	r8			; 2 restore
	sbi	f_INTQ			; 1
	reti				; 4
	.endm
;--------------------------------------------------------------------------
;
	.macro	DATI
	lds	zl, daticount
	inc	zl
	sts	daticount, zl
	#if cpldif==40
	cbi	b_RD			; 1
	ldi	zl, 0xFF		; 1
	out	dataportdir, zl		; 1 Set Data Port Direction to output
	cbi	b_RS2			; 1 Switch from CSR Address to Q-Bus Data Low
	out	dataportout, yl		; 1
	sbi	b_WR			; 1
	cbi	b_WR			; 1
	sbi	b_RS0			; 1 Switch to Q-Bus Data High
	out	dataportout, yh		; 1
	sbi	b_WR			; 1
	cbi	b_WR			; 1 -> 11 cycles
	#endif
	#if cpldif==22
	cbi	b_RD			; 1 Finish pending read
	ldi	zl, 0xFF		; 1
	out	dataportdir, zl		; 1 set port direction to output
	ldi	zl, 0x00		; 1
	out	dataportout, zl		; 1 Q-Bus Data Registers
	sbi	b_ALEW			; 1
	cbi	b_ALEW			; 1
	out	dataportout, yl		; 1 write low byte
	sbi	b_WR			; 1
	cbi	b_WR			; 1
	out	dataportout, yh		; 1 write high byte
	sbi	b_WR			; 1
	cbi	b_WR			; 1 -> 13 cycles
	#endif
	.endmacro
;--------------------------------------------------------------------------
;
	.macro	DATO
	lds	yl, datocount
	inc	yl
	sts	datocount, yl
	#if cpldif==40
	cbi	b_RS2			; 1 Switch from CSR Address to Q-Bus Data Low
	waitin				; 3-5
	in	yl, dataportin		; 1 Read Q-Bus Data Low
	sbi	b_RS0			; 1 Switch to Q-Bus Data High
	waitin				; 3-5
	in	yh, dataportin		; 1
	cbi	b_RD			; 1 
	ldi	zl, 0xFF		; 1 Set Data Port Direction to output
	out	dataportdir, zl		; 1 -> 15 cycles
	#endif
	#if cpldif==22
	sbi	b_ALER			; 1
	cbi	b_ALER			; 1
	waitin				; 3-5
	in	yl, dataportin		; 1
	sbi	b_ALER			; 1
	cbi	b_ALER			; 1
	waitin				; 3-5
	in	yh, dataportin		; 1
	cbi	b_RD			; 1
	ldi	zl, 0xFF		; 1
	out	dataportdir, zl		; 1 -> 17 cycles
	#endif
	.endmacro
;=============================================================================
;
;	QBUS Interrupts: DATI, DATO, IACK, INIT
;
;--------------------------------------------------------------------------
;
;	Register Convention
;	Y	Register Value
;	Z	Pointer, Temporary Register
;
qbus_:					; 4-5
	push	r8			; 1
	in	r8, CPU_SREG		; 1
	push	zh			; 1
	push	zl			; 1
	push	yh			; 1
	push	yl			; 1
	sbic	f_INTQ			; 2/1	Device Registers
	rjmp	qbus_intq		; 0/2
	sbic	f_INTI			; 2/1	Interrupt Acknowledge
	rjmp	qbus_iack		; 0/2
	sbic	f_INIT			; 2/1	Bus Reset
	rjmp	qbus_init		; 0/2
	pop	yl			; 2 restore
	pop	yh			; 2 restore
	pop	zl			; 2 restore
	pop	zh			; 2 restore
	out	CPU_SREG, r8		; 1 restore
	pop	r8			; 2 restore
	reti
;--------------------------------------------------------------------------
;
;	DATI/O
;
qbus_intq:
;
;	After every usage of the data port the direction must be set to
;	output and b_RD must be cleared. As the DATI/O interrupt is used
;	for both, device CSR and boot ROM, we first need to read the
;	address register and check for boot ROM access.
;
#if cpldif==40
	ldi	zl, 0x00		; 1 Data Bus Direction -> Input
	out	dataportdir, zl		; 1
	sbi	b_RD			; 1
	cbi	b_RS0			; 1
	cbi	b_RS1			; 1
	sbi	b_RS2			; 1 Read Register 4 = Device Register Address
#endif
#if cpldif==22
	ldi	zl, 0x00		; 1
	out	dataportout, zl		; 1 0->1->2->3 cycle
	sbi	b_ALER			; 1
	cbi	b_ALER			; 1
	out	dataportdir, zl		; 1 Data Bus Direction -> Input
	sbi	b_RD			; 1
#endif
;
;
;
	waitin				; 3-5 cycles
	in	zl, dataportin		; 1
;
;	+---+---+---+---+---+---+---+---+
;	|ROM|BA6|BA5|BA4|BA3|BA2|BA1| WT|
;	+---+---+---+---+---+---+---+---+
;
.equ	ROM	= 7			; Boot ROM
.equ	WTBT	= 0			; Write i.e. DATO
;
;	Check if this as access to the boot ROM
;
	sbrc	zl, ROM			; 2/1
	rjmp	qbus_rom		; 0/2
qbus_mscp:
	andi	zl, 0x03		; 1 Get BDAL1 and BWTBT
	lds	zh, mscpstatus
	or	zl, zh
	clr	zh
	subi	zl, low(-qbus_mscp_jmptbl)
	sbci	zh, high(-qbus_mscp_jmptbl)
	ijmp
qbus_mscp_jmptbl:
;
;	Status INIT
;
	rjmp	qbus_dati_ip
	rjmp	qbus_dato_ip_init
	rjmp	qbus_dati_sa_init
	rjmp	qbus_dato_sa_init
;
;	Status S1
;
	rjmp	qbus_dati_ip_s1
	rjmp	qbus_dato_ip_s1
	rjmp	qbus_dati_sa_s1
	rjmp	qbus_dato_sa_s1
;
;	Status S2
;
	rjmp	qbus_dati_ip_s2
	rjmp	qbus_dato_ip_s2
	rjmp	qbus_dati_sa_s2
	rjmp	qbus_dato_sa_s2
;
;	Status	S3
;
	rjmp	qbus_dati_ip_s3
	rjmp	qbus_dato_ip_s3
	rjmp	qbus_dati_sa_s3
	rjmp	qbus_dato_sa_s3
;
;	Status S4
;
	rjmp	qbus_dati_ip_s4
	rjmp	qbus_dato_ip_s4
	rjmp	qbus_dati_sa_s4
	rjmp	qbus_dato_sa_s4
;
;	Status Wrap Around
;
	rjmp	qbus_dati_ip_wr
	rjmp	qbus_dato_ip_wr
	rjmp	qbus_dati_sa_wr
	rjmp	qbus_dato_sa_wr
;
;	Status GO
;
	rjmp	qbus_dati_ip_go
	rjmp	qbus_dato_ip_go
	rjmp	qbus_dati_sa_go
	rjmp	qbus_dato_sa_go
;
;	Unused
;	
	rjmp	qbus_dati_ip
	rjmp	qbus_dato_ip
	rjmp	qbus_dati_sa
	rjmp	qbus_dato_sa

;=============================================================================
;
;	MSCP Register IO
;
;-----------------------------------------------------------------------------
;
;	Read IP
;
;	Reading the IP register causes the controller to start polling. The
;	register is typically read by the host if the command ring transitions
;	from empty to non-empty.
;
qbus_dati_ip:
	lds	yl, ipr+0
	lds	yh, ipr+1
	DATI
	INTEXIT	log_dati|log_ip

qbus_dati_ip_s1:
	lds	yl, ipr+0
	lds	yh, ipr+1
	DATI
	INTEXIT	log_dati|log_ips1

qbus_dati_ip_s2:
	lds	yl, ipr+0
	lds	yh, ipr+1
	DATI
	INTEXIT	log_dati|log_ips2

qbus_dati_ip_s3:
	lds	yl, ipr+0
	lds	yh, ipr+1
	DATI
	INTEXIT	log_dati|log_ips3

qbus_dati_ip_s4:
	lds	yl, ipr+0
	lds	yh, ipr+1
	cbi	b_IP
	DATI
	INTEXIT	log_dati|log_ips4

qbus_dati_ip_wr:
	lds	yl, ipr+0
	lds	yh, ipr+1
	DATI
	INTEXIT	log_dati|log_ipwr

qbus_dati_ip_go:
#if debugmode==debuggpio
	sbi	VPORTE_OUT, 1		;<<< debug
#endif
	lds	yl, ipr+0
	lds	yh, ipr+1
	cbi	b_IP
	DATI
#if debugmode==debuggpio
	cbi	VPORTE_OUT, 1		;<<< debug
#endif
	INTEXIT	log_dati|log_ipgo

;-----------------------------------------------------------------------------
;
;	Write IP
;
;	Writing the IP register causes the controller to initialise. 
;
;	2026-05-03 PS	In our case there is not much to do during initialisation
;			we just wipe all the configuration data and the mscpstatus.
;			Probably we should also clear some controller status 
;			information, but on the other hand we also have the INIT
;			Job that has much more time to initialise data structures
;			and status bits. In the Level1 interrupt we should keep
;			things to a minimum. To be save all processes should check
;			the mscpstatus before doing any actions. For the moment
;			POLL is not protected by spurious activations, but so far
;			I don't see any issue with that as b_IP is only cleared
;			in GO state.
;
qbus_dato_ip:
qbus_dato_ip_init:
qbus_dato_ip_wr:
qbus_dato_ip_s1:
qbus_dato_ip_s2:
qbus_dato_ip_s3:
qbus_dato_ip_s4:
qbus_dato_ip_go:
#if debugmode==debuggpio
	sbi	VPORTE_OUT, 0		;<<< debug
#endif
	DATO
	sts	ipr+0, yl
	sts	ipr+1, yh
	cbi	b_IRQ			; De-assert IRQ
	clr	zl			; clear important states
	sts	sa_s1+0, zl
	sts	sa_s1+1, zl
	sts	mscpstatus, zl		; Only do the minimum
#if debugmode==debuggpio
	cbi	VPORTE_OUT, 0		;<<< debug
#endif
	sbi	b_CRDY			; Enable SA Read Interrupt
	INTEXIT	log_dato|log_ip

;-----------------------------------------------------------------------------
;
;	State: INIT
;
;	After a hard reset the controller is in INIT state the first read
;	must return a ZERO before we switch to state 1. Switching to state
;	1 is exepcted to happen within 100usec, in our case it is after one
;	read to the SA, i.e. almost immediately. 
;
;	In case we will restart the system when IP is written we could make
;	use of CRDY to acknowledge further reads or writes during restart.
;	If CRDY is set the controller will just return a ZERO value and
;	once the firmware is initialized the next read of IP will proceed
;	to S1 state.
;
qbus_dati_sa_init:
	clr	yl			;
	clr	yh			; First Read after INIT must be zero
	ldi	zl, mscp_s1		;
	sts	mscpstatus, zl		;
	DATI
	INTEXIT	log_dati|log_sa

qbus_dato_sa_init:
	DATO				; Writing to SA in INIT state has no effect
	sts	sar+0, yl		
	sts	sar+1, yh
	INTEXIT	log_dato|log_sa
	
;-----------------------------------------------------------------------------
;
;	State: S1
;
qbus_dati_sa_s1:
	ldi	yl, low(step1)		; During state 1 we just report 
	ldi	yh, high(step1)		; the state and capabilities
;
;	Signal Step 1
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	|ERR| 0 | 0 | 0 | 1 |NV |QB |DI ||           reserved            |
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
	DATI
	INTEXIT	log_dati|log_sas1
;
;	During state 1 we expect the host to write the following information
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	| 1 |WR |cmdringleng|resringleng||IE |   (int vector address)/4  |
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
;
qbus_dato_sa_s1:
	DATO
	sts	sa_s1+0, yl		;
	sts	sa_s1+1, yh		;
	sbrs	yh, 7			; Check for MSB which must be set
	rjmp	qbus_dato_sa_s1_090	; Invalid Value

	sbrc	yh, 6			; check for Wrap Around
	rjmp	qbus_dato_sa_s1_080

	cbi	b_SA			; Soft Interrupt SA Write
	rjmp	qbus_dato_sa_s1_090
	
qbus_dato_sa_s1_080:			; Wrap Around will be handled in the QBUS 
	ldi	zl, mscp_wr		; interrupt routines
	sts	mscpstatus, zl		; Set New State in QBUS to WRAP

qbus_dato_sa_s1_090:
	INTEXIT	log_dato|log_sas1

;-----------------------------------------------------------------------------
;
;	State: S2
;
qbus_dati_sa_s2:
;					<<<<<<<<<<<<<<<<<<<<<<<<<
;	Signal Step 2
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	|ERR| 0 | 0 | 1 | 0 | port type || 1 |WR |cmdringleng|resringleng|
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
	lds	yl, sa_s1+1		; Low byte is just what was previously written
	ldi	yh, high(step2)
	DATI
	INTEXIT	log_dati|log_sas2

;
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	| ring based address low                                     |PI |
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;

qbus_dato_sa_s2:
	DATO
	sts	sa_s2+0, yl
	sts	sa_s2+1, yh
	cbi	b_SA
	INTEXIT	log_dato|log_sas2
	

;-----------------------------------------------------------------------------
;
;	State: S3
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	|ERR| 0 | 1 | 0 | 0 | reserved  ||IE |   (int vector address)/4  |
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
qbus_dati_sa_s3:
	lds	yl, sa_s1+0
	ldi	yh, high(step3)
	DATI
	INTEXIT	log_dati|log_sas3

;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	|PP | ring based address high                                    |
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;

qbus_dato_sa_s3:
	DATO
	sts	sa_s3+0, yl
	sts	sa_s3+1, yh
	cbi	b_SA
	INTEXIT	log_dato|log_sas3

;-----------------------------------------------------------------------------
;
;	State: S4
;
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	|ERR| 1 | 0 | 0 | 0 | reserved  ||  controller firmware version  |
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
qbus_dati_sa_s4:

	lds	yl, sa_s1+0		;
	ldi	yl, low(step4)		; 040327
	ldi	yh, high(step4)
	DATI
	INTEXIT	log_dati|log_sas4
;
;	NOTE: When the controller transitions to S4, the host can immediately
;	set the GO bit. Initially the idea was to handle the GO bit in the INIT
;	job, but this might be much too late, so the state machine could still
;	be in S4 state and the INIT job did not yet process the GO bit written.
;	Therefore we need to check the GO bit in the interrupt service routine
;	and immediately switch to the GO state. The INIT job will eventually 
;	catch up and process the data written by the host. I.e. the LF and
;	DMA burst size.
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	|           reserved            ||   dma burst size      |LF |GO |
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
qbus_dato_sa_s4:
	DATO
	sts	sa_s4+0, yl
	sts	sa_s4+1, yh
	sbrs	zl, s4go_bp
	rjmp	qbus_dato_sa_s4_010
	cbi	b_SA			; If GO is set transition to the GO
	ldi	zl, mscp_go		; state
	sts	mscpstatus, zl
qbus_dato_sa_s4_010:
	INTEXIT	log_dato|log_sas4

;--------------------------------------------------------------------------
;
;	Status WRAP
;
qbus_dati_sa_wr:
	lds	yl, sa_wr+0
	lds	yh, sa_wr+1
	DATI
	INTEXIT	log_dati|log_sawr

qbus_dato_sa_wr:
	DATO
	sts	sa_wr+0, yl
	sts	sa_wr+1, yh
	INTEXIT	log_dato|log_sawr
	
;--------------------------------------------------------------------------
;
;	Status GO
;
qbus_dati_sa_go:
	lds	yl, sa_go+0		; Normally read to the SA in GO state
	lds	yh, sa_go+1		; Just returns zero, only in case of
	DATI				; errors an error code will be placed here
	INTEXIT	log_dati|log_sago

qbus_dato_sa_go:			; Writing to the SA in GO state only
	DATO				; is required for purge requests
	sts	sa_pu+0, yl
	sts	sa_pu+1, yh
	cbi	b_SA
	INTEXIT	log_dato|log_sago

;--------------------------------------------------------------------------
;
;	Status invalid
;
qbus_dati_sa:
	lds	yl, sa_na+0
	lds	yh, sa_na+1
	DATI
	INTEXIT	log_dati|log_saer

qbus_dato_sa:
	DATO
	sts	sa_na+0, yl
	sts	sa_na+1, yh
	INTEXIT	log_dato|log_saer
	

;--------------------------------------------------------------------------
;
;	IACK
;
qbus_iack:
	cbi	b_IRQ			; 1 De-assert IRQ
	lds	yl, vector+0		; 1
	lds	yh, vector+1		; 1
	lds	zl, iackcount
	inc	zl
	sts	iackcount, zl
	#if cpldif==40
	ldi	zl, 0xFF
	out	dataportdir, zl
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
	ldi	zl, 0x00
	out	dataportout, zl
	sbi	b_ALEW
	cbi	b_ALEW
	out	dataportout, yl		; 1
	sbi	b_WR			; 1 Latch Q-Bus Data Low
	cbi	b_WR			; 1
	out	dataportout, yh		; 1
	sbi	b_WR			; 1 Latch Q-Bus Data High
	cbi	b_WR			; 1
	#endif
	sbis	FLAGS_LOG, log__iack	; 1
	rjmp	qbus_iack_nolog		; 2
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
	ldi	zh, high(log_buffer+log_begin)
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
	sbi	f_INTI			; 1 Assert MCU Interrupt
	reti				; 4	
;--------------------------------------------------------------------------
;
;	Bus INIT
;
qbus_init:
	sbi	f_INIT			; 1 Acknowledge BINIT Interrupt 
	sbis	FLAGS_LOG, log__iack
	rjmp	qbus_init_nolog
	lds	zl, log_pointer+0	; Update logging buffer pointer
	lds	zh, log_pointer+1	; 
	in	yl, int_port
	in	yh, int_flags
	std	Z+2, yl
	std	Z+3, yh
	ldi	yl, log_init
	std	Z+0, yl
	lds	yl, timestamp
	std	Z+1, yl
	adiw	zh:zl, 4		; 
	sbrc	zh, log_overflow
	ldi	zh, high(log_buffer+log_begin)
	sts	log_pointer+0, zl	; 
	sts	log_pointer+1, zh	; 
qbus_init_nolog:
;
;	On the falling edge of BINIT (note INIT is inverted BINIT) we need to
;	initialise the registers and reset the controller. When INIT is high
;	(set) the rjmp instruction is skipped and we do the initialisation
;
;	The DCJ11 pauses for 69 cycles between asserting and de-asserting BINIT.
;	A microcycle is 4 clock cycles hence. Our CPU runs at 22Mhz, therefore
;	BINIT is asserted for approx. 12usec. There is enough time to call
;	and execute the reset subroutine
;
	sbic	i_INIT			; Skip if BINIT=High i.e. rising edge
	call	mscp_reset
qbus_init_done:
	pop	yl			; restore
	pop	yh			; restore
	pop	zl			; restore
	pop	zh			; restore
	out	CPU_SREG, r8		; restore
	pop	r8			; restore
	reti				; 4	

;--------------------------------------------------------------------------
;
;	Boot ROM
;
;	For the PDP-11/Hack we don't have a real boot ROM address register
;	as there are not enough resources for that. However the boot ROM
;	emulation on the MSCP emulator does not really emulate a boot ROM
;	but rather only initiates AUTO-BOOT. Which uses only two words and
;	effectively just loads the boot sector to the host address zero and
;	then let's the PDP-11 execute the boot sector just loaded.
;
;	173000	Returns 0777 (branch to itself) and initiates a DMA. The
;		DMA will write 0777 (branch to itself) at address zero.
;		When the DMA has finished it will return 05001 (CLR R1)
;		which sets R1 to the unit number we are going to boot from.
;		In addition we will set the auto__boot flag to signal
;		that AUTOBOOT has been started.
;	173002	Returns 05007 (CLR PC), which is equivalent to a jump to the
;		address zero, where DMA has put a branch to itself instruction.
;		The PDP-11 wil now execute this instruction until auto-boot has
;		first loaded the boot block words 1..255 to address 02..0776
;		and then writes word 0 of the boot block to address 0 which 
;		then starts execution of the boot block
;
qbus_rom:
;
;	Quick fix to add DUBOOT to Emulator
;
	sbrc	zl, WTBT
	rjmp	qbus_rom_dato
	
	
	cbr	zl, (1<<ROM) | (1<<WTBT); Isolate Address Bits 1..6
	clr	zh
	subi	zl, low(-duboot)
	sbci	zh, high(-duboot)
	ld	yl, Z+
	ld	yh, Z+			; 
	DATI
	INTEXIT	log_romrd
	
qbus_rom_dato:
	INTEXIT	log_romwr

;
;	Future DU boot with autobboot trick
;

qbus_rom0_dati:
	ldi	yl, low(0777)		; 1 Assume DMA still pending
	ldi	yh, high(0777)		; 1
	sbis	b_DMR			; 2/1 did we already request DMA?
	rjmp	qbus_rom0_dati_dma	; 2 no do it now
	sbis	i_DMG			; 2/1 did it finish?
	rjmp	qbus_rom0_dati_cont	; 2 no continue to send BR .
	cbi	b_DMR			; 1 remove DMA request
	ldi	yl, low(05001)		; 1 DMA finished return a CLR R1
	ldi	yh, high(05001)		; 1
        sbi	FLAGS_COMMON, auto__boot    ; 1 Auto Boot Requested
qbus_rom0_dati_cont:
	DATI				; 13|15
	INTEXIT	log_dati|log_boot4	; 23|44
;
;	The first time we read BOOT4 we start a DMA to transfer BR .
;	instruction to adddress zero and as well return a BR. instruction.
;	
qbus_rom0_dati_dma:
	#if cpldif==40
	cbi	b_RD
	ldi	zl, 0xFF
	out	dataportdir, zl
	clr	zl
	out	dataportout, zl
	sbi	b_WR			; Register selected is 4
	cbi	b_WR
	sbi	b_RS0
	sbi	b_WR			; Register selected is 5
	cbi	b_WR
	sbi	b_RS1
	sbi	b_WR			; Register selected is 7
	cbi	b_WR
	cbi	b_RS2
	out	dataportout, yh
	sbi	b_WR			; Register selected is 3
	cbi	b_WR
	out	dataportout, yl
	cbi	b_RS0
	sbi	b_WR			; Register selected is 2
	cbi	b_WR
	sbi	b_DMR			; Request DMA
	cbi	b_RS1			; 
	out	dataportout, yl		; 
	sbi	b_WR			; Register selected is 0
	cbi	b_WR			; 
	sbi	b_RS0			; 
	out	dataportout, yh		; 
	sbi	b_WR			; Register selected is 1
	cbi	b_WR			; 30 cycles
	#endif
	#if cpldif==22
	cbi	b_RD
	ldi	zl, 0xFF
	out	dataportdir, zl
	ldi	zl, 0x04		; DMA Address Registers
	out	dataportout, zl
	sbi	b_ALEW
	cbi	b_ALEW			; Latch Write Register Address
	ldi	zl, 0x00
	out	dataportout, zl		; Set output to zero
	sbi	b_WR
	cbi	b_WR			; Latch Address Low
	sbi	b_WR
	cbi	b_WR			; Latch Address High
	sbi	b_WR
	cbi	b_WR			; Latch Address Extended
	sbi	b_DMR			; Already Request DMA so it starts asap
	sbi	dataportout, 1		; DMA Data Registers (set bit1 gives value 0x02)
	sbi	b_ALEW
	cbi	b_ALEW			; Latch Write Register Address
	out	dataportout, yl		; Low-byte of 0777
	sbi	b_WR
	cbi	b_WR
	out	dataportout, yh		; High-byte of 0777
	sbi	b_WR
	cbi	b_WR
	ldi	zl, 0x00
	out	dataportout, zl		; Q-Bus Data Register
	sbi	b_ALEW
	cbi	b_ALEW			; Latch Write Register Address
	out	dataportout, yl		; Low-byte of 0777
	sbi	b_WR
	cbi	b_WR
	out	dataportout, yh		; High-byte of 0777
	sbi	b_WR
	cbi	b_WR			; 35 cycles
	#endif
	INTEXIT	log_dati|log_boot4	; 23|44
;

qbus_rom2_dati:
        ldi     yl, low(05007)		; 1
        ldi     yh, high(05007)         ; 1 "CLR  PC" instruction
	DATI				; 13|15
;	sbic	FLAGS_COMMON, auto__boot    ; 2/1 Auto Boot Requested
;	cbi     b_SA                    ; 0/1 Trigger Main RLV12 Programm
        INTEXIT log_dati|log_boot6	; 23|44
