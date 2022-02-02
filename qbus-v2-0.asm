;--------------------------------------------------------------------------
;
;	High Priority Interrupt to interface with QBUS
;
;	Notes for the RLV12 Emulator
;
;	The RLV12 controller disables access to all device registers when CRDY 
;	has been cleared by software. When looking at the engineering drawings
;	the controller still would respond to device register access via the
;	Q-Bus with a BRPLY but it will not alter any registers and when reading
;	it will always return 0, the four DC005 in the datapath are not activated
;	and hence BDAL0..15 will stay high which as the bus is inverted corresponds
;	to the value 0.
;
;	The emulator will act equally. If CRDY is cleared it will no longer
;	interrupt the MCU and reading any register will just return the value 0
;
;	For the Q-Bus interrupt we use the Level1 High-Priority Interrupt feature
;	of the XMEGA core used as well in the AVR128Dx MCUs. Therefore we do not
;	care how long the RTOS or other Interrupt Service Routines block interrupts
;
;	When software clears CRDY we trigger a Level0 software interrupt using
;	a Port PIN. This ISR will then wake up the WORK routine that corresponds
;	to the unit.
;
;	We now can handle timers and seek in a correct way. When a seek command
;	is executed we just wake up the WORK routine. Seek will immediately 
;	create an interrupt and send the seek to the drive (which is a virtual
;	item for the emulator). DRDY will be cleared until the seek is finished.
;	Still you can issue a read or write command to any drive. A read or write
;	command will disable the controller and create an interrupt only if the
;	transfer has completed.
;
	.macro	INTEXIT			; 22/46 cycles
	sbis	GPR_GPR1, log__reg	; 1/2
	rjmp	nolog			; 2/0
	lds	zl, log_pointer+0	; 3
	lds	zh, log_pointer+1	; 3
	std	Z+2, yl			; 1
	std	Z+3, yh			; 1
	ldi	yl, @0			; 1
	std	Z+0, yl			; 1
	lds	yl, TCB2_CNTL		; 3
	std	Z+1, yl			; 1
	adiw	zh:zl, 4		; 2
;	sbrc	zh,7			; 1/2
;	ori	zh, 0x08		; 1/0
	andi	zh, high(log_size) 	; 1
	ori	zh, high(log_buffer)	; 1
	sts	log_pointer+0, zl	; 2
	sts	log_pointer+1, zh	; 2
nolog:
	sbi	b_ACK			; 1
	nop
	cbi	b_ACK			; 1

	pop	yl			;; restore
	pop	yh			;; restore
	pop	zl			;; restore
	pop	zh			;; restore
	out	CPU_SREG, r8		;; restore
	pop	r8			;; restore

	cbi	b_SIG			; 1
	sbi	f_INTQ
	reti				; 4
	.endm
	
	.macro	pulse
	cbi	b_SIG			; blinken lights in fast mode :-)
	nop
	nop
	sbi	b_SIG
	nop
	nop
	.endm
;--------------------------------------------------------------------------
;
;	Register Convention
;	Y	Register Value
;	Z	Pointer, Temporary Register
;
qbus_:					; 4-5

	push	r8			;; save
	in	r8, CPU_SREG		;; save
	push	zh			;; save
	push	zl			;; save
	push	yh			;; save
	push	yl			;; save
	sbi	b_SIG			; 1
	sbic	f_INTI			; 2
	rjmp	qbus_iack
	sbic	f_INTQ			; 2
	rjmp	qbus_intq
	sbic	f_INIT			; 2
	rjmp	qbus_init

;	Pulse Legend
;	1	INTQ
;	2	INTI
;	3	INIT
;	4	Busy
;	5	Spurious Interrupt
;	6	Card Detect Job
;	7	RLV12 Processing finished
;
;

	pulse
	pulse
	pulse
	pulse
	pulse

	pop	yl			;; restore
	pop	yh			;; restore
	pop	zl			;; restore
	pop	zh			;; restore
	out	CPU_SREG, r8		;; restore
	pop	r8			;; restore

	cbi	b_SIG			; fin
	reti

;--------------------------------------------------------------------------
;
;	DATI/O
;
qbus_intq:
;
;	Since it is a falling edge interrupt we can now immediately
;	acknowledge the interrupt in the interrupt controller
;
	sbis	b_CRDY			; 1
	rjmp	qbus_busy		; 1 Catch access before CPLD is updated
	
	pulse

	ldi	zl, 0x00		; 1 Data Bus Direction -> Input
	out	dataportdir, zl		; 1
	sbi	b_RD			; 1
	cbi	b_RS0			; 1
	cbi	b_RS1			; 1
	sbi	b_RS2			; 1
	nop				; 1
	nop				; 1
	nop				; 1
	in	zl, dataportin		; 1
	andi	zl, 0x0F		; 1
	clr	zh			; 1
	subi	zl, low(-qbus_jmptbl)	; 1
	sbci	zh, high(-qbus_jmptbl)	; 1
	ijmp				; 2
	
qbus_jmptbl:
	rjmp	qbus_dati_csr		; 2 -> ~27 cycles
	rjmp	qbus_dato_csr

	rjmp	qbus_dati_bar
	rjmp	qbus_dato_bar

	rjmp	qbus_dati_dar
	rjmp	qbus_dato_dar

	rjmp	qbus_dati_mpr
	rjmp	qbus_dato_mpr

	rjmp	qbus_dati_bae
	rjmp	qbus_dato_bae

	rjmp	qbus_dati_boot2
	rjmp	qbus_dato_boot2

	rjmp	qbus_dati_boot4
	rjmp	qbus_dato_boot4

	rjmp	qbus_dati_boot6
	rjmp	qbus_dato_boot6
;--------------------------------------------------------------------------
;
;	Controller Busy
;
;
qbus_busy:
;
;	Signal interrupt type
;
	cbi	b_RD
	cbi	b_RS0
	cbi	b_RS1
	cbi	b_RS2
	ldi	zl, 0xFF
	out	dataportdir, zl
	clr	zl
	out	dataportout, zl
	sbi	b_WR
	cbi	b_WR
	sbi	b_RS0
	sbi	b_WR
	cbi	b_WR			; We always return 0 if controller is busy

	pulse
	pulse
	pulse
	pulse
;
;	Clean up and acknowledge
;
	sbi	b_ACK			; 1
	nop
	cbi	b_ACK			; 1

	pop	yl			;; restore
	pop	yh			;; restore
	pop	zl			;; restore
	pop	zh			;; restore
	out	CPU_SREG, r8		;; restore
	pop	r8			;; restore

	cbi	b_SIG			; fin
	sbi	f_INTQ
	reti
;--------------------------------------------------------------------------
;
;	CSR		17774400
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	|ERR|DE |E3 |E2 |E1 |E0 |DS1|DS0||CRY|IE |A17|A16|F2 |F1 |F0 |RDY|
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
;	Bit(s) 	Description
;	0	Drive Ready (DRDY) - When set, this bit indicates that the 
;		selected drive is ready to receive a command. The bit is 
;		cleared when a seek or head-select operation is initiated
;		and set when the operation is completed.
;	1-3 	Function Code - These bits are set by software to indicate
;		the command to be executed.
;		F2-F0	Command
;		000	NOP (RL11) Maintenance Mode (RLV11/RLV12)
;		001	Write Check
;		010	Get Status
;		011	Seek
;		100	Read Header
;		101	Write Data
;		110	Read Data
;		111	Read Data Without Header Check
;
;	4-5	Bus Address Extension Bits (BA16, BA17) - The two most 
;		significant bus address bits when operating in 18-bit 
;		addressing modes. Read and written as data bits 4 and 5 of
;		the CSR register but considered as address bits 16 and 17 
;		of the extended bus address register (see Paragraph 3.4.2). 
;	6	Interrupt Enable (IE) - When this bit is set by software, 
;		the controller is allowed to interruptthe processor at the
;		normal command or error termination ..
;	7	Controller Ready (CRDY) - When cleared by software, this 
;		bit indicates that the commandcode in bits 1-3 is to be 
;		executed (negative GO bit). When set, this bit indicates 
;		the controller is ready to accept another command.
;	8-9	Drive Select (DS0, DS1) - These bits determine which drive 
;		will communicate with the controller via the drive bus.
;	10-13	Error Code
;		E3-E0	Error Name							
;		0001	Operation Incomplete (OPI)			
;		0010	Read Data CRC (DCRC) or Write Check Error (WCE)
;		0011	Header CRC (HCRC)					
;		0100	Data Late (DLT)						
;		0101	Header Not Found (HNF)				
;		1000	Non-Existent Memory (NXM)			
;		1001	Memory Parity Error (MPE) RLV12 only
;	14	Drive Error (DE) - This bit is tied directly to the DE 
;		interface line. When set, it indicates that the selected 
;		drive has flagged an error. (The source of the error can 
;		be determined by executing a get status command and then 
;		executing an MPR read.) DE can be cleared by executing 
;		a get status command with bit 3 of the DA register set.
;	15	Composite Error - When set, this bit indicates that one
;		or more of the error bits (bits 10-14) is set. If the IE 
;		bit (bit 6 of CS) is set and an error occurs (which sets 
;		bit 7), an interrupt will be initiated.
;
qbus_dato_csr:
	cbi	b_RS2			; 1
	nop				; 1
	nop				; 1
	nop				; 1
	in	yl, dataportin		; 1
	sbi	b_RS0			; 1
	nop				; 1
	nop				; 1
	nop				; 1
	in	yh, dataportin		; 1
	andi	yh, driveselect		; 1 remove error bits (they are RO)
	sts	CSRH, yh		; 2
	sts	CSRL, yl		; 2 update drive ready status in CSR
;
;	BA16 and BA17 can be written via CSR or BAE, we always make sure
;	we update the other register when writing either
;
	lds	zl, BAEL
	bst	yl, CSR_BA16		; Copy BA16
	bld	zl, BAE_BA16
	bst	yl, CSR_BA17		; and BA17
	bld	zl, BAE_BA17
	sts	BAEL, zl
;
;	New Logic
;
;	- Just check if a command has been initiated
;	- If a command has been initiated then trigger the Level0 interrupt
;	- Block Access to the controller Register
;
	sbrc	yl, CSR_CRDY		; 1 command requested, i.e. CRDY=0
	rjmp	qbus_dato_csr_done	; 1 no, then we are done

;
;	Queue Event to RT-OS
;
	cbi	b_CRDY			; 1	Disable QBUS Interface
	cbi	b_GO			; 1	GO
;
;	The controller is now locked and the main job can now analyze the
;	command and then perform the appropriate acction, now the DATI 
;	of the CRS must translate the DS into a ucb offset and return
;	the correct status for DRDY
;
qbus_dato_csr_done:
	INTEXIT	log_dato|log_csr
;
;
;
qbus_dati_csr:
	cbi	b_RD			; 1
	lds	yl, CSRH		; 3
	andi	yl, driveselect		; 1
	swap	yl			; 1
	clr	yh			; 1
	subi	yl, low(-unittable)	; 1
	sbci	yh, high(-unittable)	; 1
	ldd	zl, Y+ucb_status	; 1 Get status

	lds	yl, CSRL		; 3
	lds	yh, CSRH		; 3

	bst	zl, ucb__drdy		; 1 copy drive ready from ucb status
	bld	yl, CSR_DRVRDY		; 1 to drvie ready in CSR
	bst	zl, ucb__de		; 1 get general drive error
	bld	yh, CSR_DE		; 1 copy over the disks status bits

	sts	CSRL, yl
	sts	CSRH, yh

	ldi	zl, 0xFF		; 1
	out	dataportdir, zl		; 1
	cbi	b_RS2			; 1
	out	dataportout, yl		; 1
	sbi	b_WR			; 1
	cbi	b_WR			; 1
	sbi	b_RS0			; 1
	out	dataportout, yh		; 1
	sbi	b_WR			; 1
	cbi	b_WR			; 1
	INTEXIT	log_dati|log_csr
;------------------------------------------------------------------------------
;
;	BAR	17774402
;
qbus_dati_bar:
	cbi	b_RD			; 1
	lds	yl, BARL		; 1
	lds	yh, BARH		; 1
	ldi	zl, 0xFF		; 1
	out	dataportdir, zl		; 1
	cbi	b_RS2			; 1
	out	dataportout, yl		; 1
	sbi	b_WR			; 1
	cbi	b_WR			; 1
	sbi	b_RS0			; 1
	out	dataportout, yh		; 1
	sbi	b_WR			; 1
	cbi	b_WR			; 1
	INTEXIT	log_dati|log_bar
;
;
;
qbus_dato_bar:
	cbi	b_RS2			; 1
	nop				; 1
	nop				; 1
	nop				; 1
	in	yl, dataportin		; 1
	sbi	b_RS0			; 1
	sts	BARL, yl		; 2
	nop				; 1
	in	yh, dataportin		; 1
	sts	BARH, yh
	INTEXIT	log_dato|log_bar
;------------------------------------------------------------------------------
;
;	DAR	17774404
;
qbus_dati_dar:
	cbi	b_RD			; 1
	lds	yl, DARL		; 1
	lds	yh, DARH		; 1
	ldi	zl, 0xFF		; 1
	out	dataportdir, zl		; 1
	cbi	b_RS2			; 1
	out	dataportout, yl		; 1
	sbi	b_WR			; 1
	cbi	b_WR			; 1
	sbi	b_RS0			; 1
	out	dataportout, yh		; 1
	sbi	b_WR			; 1
	cbi	b_WR			; 1
	INTEXIT	log_dati|log_dar
;
;
;
qbus_dato_dar:
	cbi	b_RS2			; 1
	nop				; 1
	nop				; 1
	nop				; 1
	in	yl, dataportin		; 1
	sbi	b_RS0			; 1
	sts	DARL, yl		; 2
	nop				; 1
	in	yh, dataportin		; 1
	sts	DARH, yh
	INTEXIT	log_dato|log_dar
;------------------------------------------------------------------------------
;
;	MPR	17774406
;
;	The MPR register can have three meanings
;
;	MPR during get status
;
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;	|WDE|CHE|WL |SKT|SPE|WGE|VC |DSE|DT |HS |CO |HO |BH |STC|STB|STA|
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;
;	STA..C	Status
;	BH		Brush home
;	HO		Heads out
;	CO		Cover open
;	HS		Head select
;	DT		Drive Type
;	DSE		Drive Select Error
;	VC		Volume Check
;	WGE		Write Gate Error
;	SPE		Spin Error
;	SKTO	Seek Time-out
;	WL		Write Lock
;	CHE		Current Head Error
;	WDE		Write Data Error
;
;	MPR during read header
;
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;	|CA8|CA7|CA6|CA5|CA4|CA3|CA2|CA1|CA0|HS |SA5|SA4|SA3|SA2|SA1|SA0|
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;	| 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;	|                              CRC                              |
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;
;	MPR during write word count (write-only)
;
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;	| 1 | 1 | 1 |        2's comlement of word count                |
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;
qbus_dati_mpr:
	lds	yl, MPR_Fifo+0		; 3
	lds	yh, MPR_Fifo+1		; 3
	cbi	b_RD			; 1
	ldi	zl, 0xFF		; 1
	out	dataportdir, zl		; 1
	cbi	b_RS2			; 1
	out	dataportout, yl		; 1
	sbi	b_WR			; 1
	cbi	b_WR			; 1
	sbi	b_RS0			; 1
	out	dataportout, yh		; 1
	sbi	b_WR			; 1
	cbi	b_WR			; 1
	lds	zl, MPR_Fifo+2		; Shift Fifo, the real Fifo
	sts	MPR_Fifo+0, zl		; on the RLV12 has 512 words
	lds	zl, MPR_Fifo+3		; however we only need the
	sts	MPR_Fifo+1, zl		; Fifo when we perform a read
	lds	zl, MPR_Fifo+4		; header. 
	sts	MPR_Fifo+2, zl		;
	lds	zl, MPR_Fifo+5
	sts	MPR_Fifo+3, zl
	lds	zl, MPR_Fifo+6
	sts	MPR_Fifo+4, zl
	lds	zl, MPR_Fifo+7
	sts	MPR_Fifo+5, zl
	INTEXIT	log_dati|log_mpr
;
;
;
qbus_dato_mpr:
	cbi	b_RS2			; 1
	nop				; 1
	nop				; 1
	nop				; 1
	in	yl, dataportin		; 1
	sbi	b_RS0			; 1
	sts	MPRL, yl		; 2
	nop				; 1
	in	yh, dataportin		; 1
	sts	MPRH, yh
	INTEXIT	log_dato|log_mpr
;------------------------------------------------------------------------------
;
;	BAE	17774410
;
;	Bus Address Extension
;
;	The address bits A16 and A17 can be accessed via the CSR and the BAE
;	internally the CSR is the master. That is when writing to the BAE
;	we copy them to the CSR and when reading the BAE we return the values
;	for A16 and A17 stored in the CSR. That is only A18, A19, A20 and A21
;	are valid in the BAE
;

qbus_dati_bae:
	lds	yl, BAEL
	lds	yh, BAEH
	cbi	b_RD			; 1
	ldi	zl, 0xFF		; 1
	out	dataportdir, zl		; 1
	cbi	b_RS2			; 1
	out	dataportout, yl		; 1
	sbi	b_WR			; 1
	cbi	b_WR			; 1
	sbi	b_RS0			; 1
	out	dataportout, yh		; 1
	sbi	b_WR			; 1
	cbi	b_WR			; 1
	INTEXIT	log_dati|log_bae
;
;
;
qbus_dato_bae:
	cbi	b_RS2			; 1
	nop				; 1
	nop				; 1
	nop				; 1
	in	yl, dataportin		; 1
	sbi	b_RS0			; 1
	sts	BAEL, yl
	nop				; 1
	in	yh, dataportin		; 1
	sts	BAEH, yh
;
;	BA16 and BA17 can be written via CSR or BAE, we always make sure
;	we update the other register when writing either
;
	lds	zl, CSRL		;
	bst	yl, BAE_BA16
	bld	zl, CSR_BA16
	bst	yl, BAE_BA17
	bld	zl, CSR_BA17 
	sts	CSRL, zl
	INTEXIT	log_dato|log_bae
;------------------------------------------------------------------------------
;
;	BOOT2	17774412
;
;	
;
;
qbus_dati_boot2:
	lds	yl, CSR12+0		; 1
	lds	yh, CSR12+1		; 1
	cbi	b_RD			; 1
	ldi	zl, 0xFF		; 1
	out	dataportdir, zl		; 1
	cbi	b_RS2			; 1
	out	dataportout, yl		; 1
	sbi	b_WR			; 1
	cbi	b_WR			; 1
	sbi	b_RS0			; 1
	out	dataportout, yh		; 1
	sbi	b_WR			; 1
	cbi	b_WR			; 1
	INTEXIT	log_dati|log_boot2
;
;
;
qbus_dato_boot2:
	cbi	b_RS2			; 1
	nop				; 1
	nop				; 1
	nop				; 1
	in	yl, dataportin		; 1
	sbi	b_RS0			; 1
	sts	CSR12+0, yl		; 2
	nop				; 1
	in	yh, dataportin		; 1
	sts	CSR12+1, yh
	INTEXIT	log_dato|log_boot2
;------------------------------------------------------------------------------
;
;	BOOT4	17774414
;
;	
;
;
qbus_dati_boot4:
	lds	yl, CSR14+0		; 1
	lds	yh, CSR14+1		; 1
	cbi	b_RD			; 1
	ldi	zl, 0xFF		; 1
	out	dataportdir, zl		; 1
	cbi	b_RS2			; 1
	out	dataportout, yl		; 1
	sbi	b_WR			; 1
	cbi	b_WR			; 1
	sbi	b_RS0			; 1
	out	dataportout, yh		; 1
	sbi	b_WR			; 1
	cbi	b_WR			; 1
	INTEXIT	log_dati|log_boot4

;
;
;
qbus_dato_boot4:
	cbi	b_RS2			; 1
	nop				; 1
	nop				; 1
	nop				; 1
	in	yl, dataportin		; 1
	sbi	b_RS0			; 1
	sts	CSR14+0, yl		; 2
	nop				; 1
	in	yh, dataportin		; 1
	sts	CSR14+1, yh
	INTEXIT	log_dato|log_boot4
;------------------------------------------------------------------------------
;
;	BOOT6	17774416
;
;	During Test just a normal read/write port
;
qbus_dati_boot6:
	lds	yl, CSR16+0		; 1
	lds	yh, CSR16+1		; 1
	cbi	b_RD			; 1
	ldi	zl, 0xFF		; 1
	out	dataportdir, zl		; 1
	cbi	b_RS2			; 1
	out	dataportout, yl		; 1
	sbi	b_WR			; 1
	cbi	b_WR			; 1
	sbi	b_RS0			; 1
	out	dataportout, yh		; 1
	sbi	b_WR			; 1
	cbi	b_WR			; 1
	INTEXIT	log_dati|log_boot6

qbus_dato_boot6:
	cbi	b_RS0			; 1
	nop				; 1
	nop				; 1
	nop				; 1
	in	yl, dataportin		; 1
	sbi	b_RS0			; 1
	sts	CSR16+0, yl		; 2
	nop				; 1
	in	yh, dataportin		; 1
	sts	CSR16+1, yh
	INTEXIT	log_dato|log_boot6
;--------------------------------------------------------------------------
;
;	IACK
;
;
qbus_iack:
	cbi	b_IRQ			; 1 De-assert IRQ
	cbi	b_RD			; 1
	ldi	zl, 0xff		; 1	Data Bus Direction -> Input
	out	dataportdir, zl		; 1
	cbi	b_RS0			; 1	Q-Bus Register
	cbi	b_RS1			; 1	Q-Bus Register
	cbi	b_RS2			; 1	Q-Bus Register
	ldi	yl, low(0160)		; 1
	ldi	yh, high(0160)		; 1
	out	dataportout, yl		; 1
	nop
	sbi	b_WR			; 1
	cbi	b_WR			; 1
	sbi	b_RS0			; 1
	out	dataportout, yh		; 1
	nop				; 1
	sbi	b_WR			; 1
	cbi	b_WR			; 1

	pulse
	pulse

	sbis	GPR_GPR1, log__iack	; 1
	rjmp	qbus_iack_nolog		; 2
	lds	zl, log_pointer+0	; 3
	lds	zh, log_pointer+1	; 3
	std	Z+2, yl			; 2
	std	Z+3, yh			; 2
	ldi	yl, log_iack		; 1
	std	Z+0, yl			; 2
	lds	yl, TCB2_CNTL		; 3
	std	Z+1, yl			; 2
	adiw	zh:zl, 4		; 2 
;	sbrc	zh,7			; 1/2
;	ori	zh, 0x08		; 1/0
	andi	zh, high(log_size) 	; 1
	ori	zh, high(log_buffer)	; 1
	sts	log_pointer+0, zl	; 2 
	sts	log_pointer+1, zh	; 2 
qbus_iack_nolog:
	pop	yl			;; restore
	pop	yh			;; restore
	pop	zl			;; restore
	pop	zh			;; restore
	out	CPU_SREG, r8		;; restore
	pop	r8			;; restore

	sbi	b_ACK			; 1
	nop
	cbi	b_ACK			; 1
	nop
	nop
	cbi	b_SIG			; 1
	sbi	f_INTI			; 1 Assert MCU Interrupt
	reti				; 4	
;--------------------------------------------------------------------------
;
;
;
;	Bus INIT
;
qbus_init:
	sbi	b_ABO			; BINIT does no longer clear DMA 
	cbi	b_ABO			; so we need to do it in software
	sbi	f_INIT			; 1 Acknowledge BINIT Interrupt 

	pulse
	pulse
	pulse

	sbis	GPR_GPR1, log__iack
	rjmp	qbus_init_nolog
	lds	zl, log_pointer+0	;;; Update logging buffer pointer
	lds	zh, log_pointer+1	;;; 
	in	yl, VPORTE_IN
	in	yh, VPORTE_INTFLAGS
	std	Z+2, yl
	std	Z+3, yh
	ldi	yl, log_init
	std	Z+0, yl
	lds	yl, TCB2_CNTL
	std	Z+1, yl
	adiw	zh:zl, 4		;;; 
;	sbrc	zh,7
;	ori	zh, 0x08
	andi	zh, high(log_size) 	; 1
	ori	zh, high(log_buffer)	; 1
	sts	log_pointer+0, zl	;;; 
	sts	log_pointer+1, zh	;;; 
qbus_init_nolog:
;
;	On the falling edge of BINIT (note INIT is inverted BINIT) we need to
;	initialise the registers and reset the controller. When INIT is high
;	(set) the rjmp instruction is skipped and we do the initialisation
;
	sbic	i_INIT			;;; Skip if BINIT=High i.e. rising edge
	call	rlv12_reset		;;; reset RLV12 controller
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
