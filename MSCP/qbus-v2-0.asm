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
	std	Z+3, yh			; 1
	ldi	yl, @0			; 1
	std	Z+0, yl			; 1
	lds	yl, timestamp		; 3
	std	Z+1, yl			; 1
	adiw	zh:zl, 4		; 2
	sbrc	zh, log_overflow	; 2/1
	subi	zh, high(log_size)	; 0/1
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
	sbic	f_INIT			; 2/1	Bus Reset
	rjmp	qbus_init		; 0/2
	sbic	f_INTI			; 2/1	Interrupt Acknowledge
	rjmp	qbus_iack		; 0/2
	sbic	f_INTQ			; 2/1	Device Registers
	rjmp	qbus_intq		; 0/2
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
;	| UB| LB|ROM|BA4|BA3|BA2|BA1| WT|
;	+---+---+---+---+---+---+---+---+
;
.equ	UB	= 7			; Don't Write Upper Byte
.equ	LB	= 6			; Don't Write Lower Byte
.equ	ROM	= 5			; Boot ROM
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
	rjmp	qbus_dato_ip
	rjmp	qbus_dati_sa_init
	rjmp	qbus_dato_sa_init
;
;	Status S1
;
	rjmp	qbus_dati_ip
	rjmp	qbus_dato_ip
	rjmp	qbus_dati_sa_s1
	rjmp	qbus_dato_sa_s1
;
;	Status S2
;
	rjmp	qbus_dati_ip
	rjmp	qbus_dato_ip
	rjmp	qbus_dati_sa_s2
	rjmp	qbus_dato_sa_s2
;
;	Status	S3
;
	rjmp	qbus_dati_ip
	rjmp	qbus_dato_ip
	rjmp	qbus_dati_sa_s3
	rjmp	qbus_dato_sa_s3
;
;	Status S4
;
	rjmp	qbus_dati_ip
	rjmp	qbus_dato_ip
	rjmp	qbus_dati_sa_s4
	rjmp	qbus_dato_sa_s4
;
;	Status Wrap Around
;
	rjmp	qbus_dati_ip
	rjmp	qbus_dato_ip
	rjmp	qbus_dati_sa_wr
	rjmp	qbus_dato_sa_wr
;
;	Status GO
;
	rjmp	qbus_dati_ip_go
	rjmp	qbus_dato_ip
	rjmp	qbus_dati_sa_go
	rjmp	qbus_dato_sa_go
;
;	Unused
;	
	rjmp	qbus_dati_ip
	rjmp	qbus_dato_ip
	rjmp	qbus_dati_sa
	rjmp	qbus_dato_sa

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
;		which sets R1 to the unit number we are going to boot from
;		and sets the AUTOBOOT flag.
;	173002	Returns 05007 (CLR PC), which is equivalent to a jump to the
;		address zero, where DMA has put a branch to itself instruction.
;		The PDP-11 wil now execute this instruction until auto-boot has
;		first loaded the boot block words 1..255 to address 02..0776
;		and then writes word 0 of the boot block to address 0 which 
;		then starts execution of the boot block
;
qbus_rom:
	mov	yl, zl
	clr	yh
	andi	zl, 0x03		; 
	cpi	zl, 0x00
	brne	qbus_rom010
	rjmp	qbus_dati_ip
qbus_rom010:
	cpi	zl, 0x02
	brne	qbus_rom020
	rjmp	qbus_dati_sa
qbus_rom020:
	sbrs	zl, 0
	breq	qbus_rom030
	INTEXIT	log_dato|log_rom
qbus_rom030:
	INTEXIT	log_dati|log_rom

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

qbus_dati_ip_go:
	lds	yl, ipr+0
	lds	yh, ipr+1
	cbi	b_IP
	DATI
	INTEXIT	log_dati|log_ip

;-----------------------------------------------------------------------------
;
;	Write IP
;
;	Writing the IP register causes the controller to initialise. For the
;	moment we just wipe some data to make sure the controller is reset
;	logically. Later we might restart the whole firmware to make sure we
;	make a fresh start. However we need to be careful, as the SD-Card
;	cannot be re-initialized without power-cycle. So we need to save the
;	SD-Card status during such a restart. We will deal with this later
;
qbus_dato_ip:
	DATO
	sts	ipr+0, yl
	sts	ipr+1, yh

	clr	zl			; clear important states
	sts	sa_s1+0, zl
	sts	sa_s1+1, zl
	sts	sa_s2+0, zl
	sts	sa_s2+1, zl
	sts	sa_s3+0, zl
	sts	sa_s3+1, zl
	sts	sa_s4+0, zl
	sts	sa_s4+1, zl
	sts	mscpstatus, zl

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
	INTEXIT	log_dati|log_sa
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
	INTEXIT	log_dato|log_sa

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
	INTEXIT	log_dati|log_sa

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
	INTEXIT	log_dato|log_sa
	

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
	INTEXIT	log_dati|log_sa

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
	INTEXIT	log_dato|log_sa

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
	lds	yl, 0x01
	ldi	yh, high(step4)
	DATI
	INTEXIT	log_dati|log_sa
;
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	|           reserved            ||   dma burst size      |LF |GO |
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;

qbus_dato_sa_s4:
	DATO
	sts	sa_s4+0, yl
	sts	sa_s4+1, yh
	sbrc	yl, 0
	cbi	b_SA
	INTEXIT	log_dato|log_sa

;--------------------------------------------------------------------------
;
;	Status WRAP
;
qbus_dati_sa_wr:
	lds	yl, sa_wr+0
	lds	yh, sa_wr+1
	DATI
	INTEXIT	log_dati|log_sa

qbus_dato_sa_wr:
	DATO
	sts	sa_wr+0, yl
	sts	sa_wr+1, yh
	INTEXIT	log_dato|log_sa
	
;--------------------------------------------------------------------------
;
;	Status GO
;
qbus_dati_sa_go:
	lds	yl, sa_go+0
	lds	yh, sa_go+1
	cbi	b_SA
	DATI
	INTEXIT	log_dati|log_sa

qbus_dato_sa_go:
	DATO
	sts	sa_pu+0, yl
	sts	sa_pu+1, yh
	INTEXIT	log_dato|log_sa

;--------------------------------------------------------------------------
;
;	Status invalid
;
qbus_dati_sa:
	lds	yl, sa_na+0
	lds	yh, sa_na+1
	DATI
	INTEXIT	log_dati|log_sa

qbus_dato_sa:
	DATO
	sts	sa_na+0, yl
	sts	sa_na+1, yh
	INTEXIT	log_dato|log_sa
	

;--------------------------------------------------------------------------
;
;	IACK
;
qbus_iack:
	cbi	b_IRQ			; 1 De-assert IRQ
	lds	yl, vector+0		; 1
	lds	yh, vector+1		; 1
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
	subi	zh, high(log_size)
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
