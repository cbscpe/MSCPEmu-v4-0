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
	lds	zh, mscpstatus
	andi	zl, 0x03		; 1 Get BDAL1 and BWTBT
	andi	yh, 0x1c		; Isolate status bits
	or	zl, zh
	clr	zh
	subi	zl, low(-qbus_mscp_jmptbl)
	sbci	zh, high(-qbus_mscp_jmptbl)
	ijmp
qbus_mscp_jmptbl:
;
;	Status INIT	0
;
	rjmp	qbus_dati_ip
	rjmp	qbus_dato_ip
	rjmp	qbus_dati_sa
	rjmp	qbus_dato_sa
;
;	Status START	1
;
	rjmp	qbus_dati_ip
	rjmp	qbus_dato_ip
	rjmp	qbus_dati_sa
	rjmp	qbus_dato_sa
;
;	Status CONFIG	2
;
	rjmp	qbus_dati_ip
	rjmp	qbus_dato_ip
	rjmp	qbus_dati_sa
	rjmp	qbus_dato_sa
;
;	Status	READY	3
;
	rjmp	qbus_dati_ip
	rjmp	qbus_dato_ip
	rjmp	qbus_dati_sa
	rjmp	qbus_dato_sa
;
;	Status GO	4
;
	rjmp	qbus_dati_ip
	rjmp	qbus_dato_ip
	rjmp	qbus_dati_sa
	rjmp	qbus_dato_sa
;
;	Status INVALID	5,6,7
;
	rjmp	qbus_dati_ip
	rjmp	qbus_dato_ip
	rjmp	qbus_dati_sa
	rjmp	qbus_dato_sa

	rjmp	qbus_dati_ip
	rjmp	qbus_dato_ip
	rjmp	qbus_dati_sa
	rjmp	qbus_dato_sa

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
;		The PDP-11 will now execute this instruction until auto-boot has
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

;--------------------------------------------------------------------------
;
;	MSCP
;
qbus_dati_ip:
	lds	yl, ipr+0
	lds	yh, ipr+1
	DATI
	INTEXIT	log_dati|log_ip
	
qbus_dati_sa:
	lds	yl, sar+0
	lds	yh, sar+1
	DATI
	INTEXIT	log_dati|log_sa

qbus_dato_ip:
	DATO
	sts	ipr+0, yl
	sts	ipr+1, yh
	INTEXIT	log_dato|log_ip

qbus_dato_sa:
	DATO
	sts	sar+0, yl
	sts	sar+1, yh
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
;	and execute rlv12_reset
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
