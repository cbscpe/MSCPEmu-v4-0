;
; Disk Emulator
;
; Created: 23.10.2021 16:20:20
; Author : peter
;
	.listmac
;=============================================================================
;
;	
;
.include "macro-library-v1-1.asm"	; My standard macros
.include "../include/FAT/fat-defs.asm"	; FAT defintions
.include "Error.inc"			; Error code definitions
;
;--------------------------------------------------------------------------
;
;	Data Segment
;	
.include "main-v2-1.inc"		; Disk Emulator Data section
;
;--------------------------------------------------------------------------
;
;	Data Segments of external modules
;	
.include "monitor-v2-0.inc"		; Interactive monitor
.include "print-v2-0.inc"		; Print routine
.include "tparse-v2-0.inc"		; Table Driven Parser
.include "rlv12-v2-0.inc"		; Disk Emulator

;=============================================================================
;
;	Flash Begin
;
;
;	Interrupt Vector Table
;
	.cseg
	.org	0
	jmp	start

	.org	PORTA_PORT_vect		; Software Interrupt RTOS
	jmp	rtos_

	.org	TCB0_INT_vect		; Ticker Interrupt
	jmp	tick

	.org	TCB1_INT_vect		; Ticker Interrupt
	rjmp	tcb1_isr
	.org	TCB2_INT_vect		; Ticker Interrupt
	rjmp	tcb2_isr
	.org	TCB3_INT_vect		; Ticker Interrupt
	rjmp	tcb3_isr

	
	.org	PORTB_PORT_vect		; Software Interrupt Controller GO
	jmp	go_			; Module rlv12-v2-0.asm

	.org	PORTF_PORT_vect		; Softinterrupt for malloc() and free()
	jmp	mem_

	.org	USART1_RXC_vect
	jmp	rxc1_isr
	
	.org	USART1_DRE_vect
	jmp	dre1_isr

	.org	PORTE_PORT_vect		; External Level 1 Q-Bus Interrupt
	jmp	qbus_			; Module qbus-v2-0.asm
	
	.org	INT_VECTORS_SIZE

tcb1_isr:
	push	r16
	ldi	r16, 3
	sts	TCB1_INTFLAGS, r16
	pop	r16
	reti
tcb2_isr:
	push	r16
	ldi	r16, 3
	sts	TCB2_INTFLAGS, r16
	pop	r16
	reti
tcb3_isr:
	push	r16
	ldi	r16, 3
	sts	TCB3_INTFLAGS, r16
	pop	r16
	reti


;=============================================================================
;
;
start:
;	sbic	GPR_GPR3, 0
;	jmp	crash
;
;	Init
;	
	ldi	r18, low(RAMEND)
	out	CPU_SPL, r18
	ldi	r18, high(RAMEND)		; AVR128DA does this during RESET
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
;
;	Initialise RAM except for 32 bytes at the beginning
;
;	ldi	xl, low(RAMINITSTART+0x20)
;	ldi	xh, high(RAMINITSTART+0x20)
;	ldi	yl, low(RAMINITEND)
;	ldi	yh, high(RAMINITEND)

;	ldi	xl, low(INTERNAL_SRAM_START+0x20)
;	ldi	xh, high(INTERNAL_SRAM_START+0x20)
;	ldi	yl, low(INTERNAL_SRAM_START+INTERNAL_SRAM_SIZE)
;	ldi	yh, high(INTERNAL_SRAM_START+INTERNAL_SRAM_SIZE)



;=============================================================================
;
;	During debugging we do the following. We assume that the RAM range
;	assigned does not exceed the first 4k pages
;
;	0x4xxx	is copied to 0x5xxx
;	0x7xxx	is copied to 0x5xxx
;	0x4xxx	is zeroized except for the first 32 bytes
;	0x6xxx	is zeroized
;	0x7xxx	is zeroized
;
;	we don't care about SRAM definitions
;
	ldi	xl, low(0x4000)
	ldi	xh, high(0x4000)
	ldi	xl, low(0x7000)
	ldi	xh, high(0x7000)
	ldi	yl, low(0x5000)
	ldi	yh, high(0x5000)
	movw	r25:r24, yh:yl
ramcopy010:
	ld	r16, X+
	st	Y+, r16
	cp	xl, r24
	cpc	xh, r25
	brlo	ramcopy010
	
	lds	r16, log_pointer+0
	lds	r17, log_pointer+1
	sts	0x5000, r16
	sts	0x5001, r17

	ldi	xl, low(0x4000)
	ldi	xh, high(0x4000)
	ldi	yl, low(0x5000)
	ldi	yh, high(0x5000)
raminit100:
	st	X+, zero
	cp	xl, yl
	cpc	xh, yh
	brlo	raminit100

	ldi	xl, low(0x6000)
	ldi	xh, high(0x6000)
	ldi	yl, low(0x8000)
	ldi	yh, high(0x8000)
raminit110:
	st	X+, zero
	cp	xl, yl
	cpc	xh, yh
	brlo	raminit110

	ldi	r18, 0xff
	sts	nguard, r18
;--------------------------------------------------------------------------
;
;	Initialise heap
;
	ldi	xl, low(heapsize)
	ldi	xh, high(heapsize)
	ldi	yl, low(heapstart)
	ldi	yh, high(heapstart)

initheap010:				; First init range with zero
	st	Y+, zero
	sbiw	xh:xl, 1
	brne	initheap010

	ldi	xl, low(heapsize)
	ldi	xh, high(heapsize)
	ldi	yl, low(heapstart)
	ldi	yh, high(heapstart)
	
	sts	heap+0, zero		; Dummy record that starts the
	sts	heap+1, zero		; List of free blocks with size 0
	sts	heap+2, yl		; and points to the heap
	sts	heap+3, yh
	
	std	Y+0, xl			; Size of heap
	std	Y+1, xh
	std	Y+2, zero		; Just one block for now, no more
	std	Y+3, zero
;--------------------------------------------------------------------------
;
;	Initialise pcb queue
;
	sts	pcbqueue+0, zero
	sts	pcbqueue+1, zero
	sts	partitionid, zero
	ldi	r18, 'C'
	sts	volumeid, r18
;--------------------------------------------------------------------------
;
;	Initialise command history
;
	
	sts	HistoryBuffer, zero
;--------------------------------------------------------------------------
;
;	Clear internal flags
;
	cbi	GPR_GPR0, auto__boot
	cbi	GPR_GPR0, sddetect__en
;=============================================================================
;
;	Port Settings
;
;	New CPLD Interface
;	PA0	ENA		Enables Interrupt
;	PF0	MEM
;	PF1	SIG		Alternate Function
;	PF2	QDE		Q-Bus Data Enable Output
;
;-----------------------------------------------------------------------------
;
;	PORT A	(Bits0..7)
;
.equ	ENA	= 0			; Enable CPLD (Pin 11)
.equ	DMR	= 1			; DMA Request	
.equ	DMG	= 2			; DMA Granted	
.equ	ABO	= 3			; Abort Cycle	
.equ	ACK	= 4			; Acknowledge Cycle
.equ	CRDY	= 5			; Controller Ready this an internal flag only
.equ	RTOS	= 6			; RTOS Software Interrupt	
.equ	CLK	= 7			; CPDL Clock output

#define b_ENA	VPORTA_OUT, ENA
#define b_DMR	VPORTA_OUT, DMR
#define i_DMG	VPORTA_IN, DMG
#define b_ABO	VPORTA_OUT, ABO
#define b_ACK	VPORTA_OUT, ACK
#define b_CRDY	VPORTA_OUT, CRDY

#define b_RTOS	VPORTA_OUT, RTOS
#define	f_RTOS	VPORTA_INTFLAGS, RTOS
#define	c_RTOS	PORTA_PIN6CTRL

#define b_CLK	VPORTA_OUT, CLK

	sbi	VPORTA_DIR, ENA
	sbi	VPORTA_DIR, DMR
	cbi	VPORTA_DIR, DMG
	sbi	VPORTA_DIR, ABO
	sbi	VPORTA_DIR, ACK
	sbi	VPORTA_DIR, CRDY
	sbi	VPORTA_DIR, RTOS
	sbi	VPORTA_DIR, CLK
	
	sbi	b_ENA			; Enable Q-Bus Interrupts
	cbi	b_DMR			; No DMA request
	sbi	b_ABO
	cbi	b_ABO			; Abort any pending DMA
	sbi	b_ACK
	cbi	b_ACK			; Unlock Bus
	sbi	b_CRDY
	
	sbi	b_RTOS			; Set Level = High 
	sbi	f_RTOS			; Acknowledge any pending interrupt
	ldi	r18, PORT_ISC_LEVEL_gc	; Level Sense Interrupt
	sts	c_RTOS, r18		; Pin Control
	
	ldi	r18, CPU_CCP_IOREG_gc
	sts	CPU_CCP, r18

	ldi	r18, CLKCTRL_CLKOUT_bm	; Clock Out
	sts	CLKCTRL_MCLKCTRLA, r18
;-----------------------------------------------------------------------------
;
;	PORT B (Bits0..5)
;
.equ	RS0	= 0			; Register Select 0
.equ	RS1	= 1			; Register Select 1
.equ	RS2	= 2			; Register Select 2
;	PB3	unused
;	PB4	unused
.equ	GO	= 5			; GO Level1 -> Level0 signalling

#define	b_RS0	VPORTB_OUT, RS0
#define	b_RS1	VPORTB_OUT, RS1
#define	b_RS2	VPORTB_OUT, RS2
#define	b_GO	VPORTB_OUT, GO	
#define	f_GO	VPORTB_INTFLAGS, GO
#define	c_GO	PORTB_PIN5CTRL


	sbi	VPORTB_DIR, RS0
	sbi	VPORTB_DIR, RS1
	sbi	VPORTB_DIR, RS2
	sbi	VPORTB_DIR, GO

	sbi	b_GO			; Set Level = High 
	sbi	f_GO			; Acknowledge any pending interrupt
	ldi	r18, PORT_ISC_LEVEL_gc	; Level Sense Interrupt
	ldi	r18, PORT_ISC_FALLING_gc
	sts	c_GO, r18		; Pin Control

;-----------------------------------------------------------------------------
;
;	PORT C	MVIO (Bits0..7)
;
.equ	TXD	= 0			; USART 1 Transmit
.equ	RXD	= 1			; USART 1 Receive
.equ	CD	= 2			; Card Detect
.equ	WP	= 3			; Write Protect
.equ	MOSI	= 4			; SPI
.equ	MISO	= 5
.equ	SCK	= 6
.equ	SS	= 7

#define	i_CD	VPORTC_IN, CD
#define	i_WP	VPORTC_IN, WP
#define	b_SS	VPORTC_OUT, SS

	ldi	r18, PORT_SRL_bm
	sts	PORTC_PORTCTRL, r18
	
	sbi	b_SS			; Disable SD-Card

	sbi	VPORTC_DIR, TXD		; UART Transmit
	cbi	VPORTC_DIR, RXD		; UART Receive
	cbi	VPORTC_DIR, CD		; SD-Card Card Detect
	cbi	VPORTC_DIR, WP		; SD-Card Write Protect
	sbi	VPORTC_DIR, MOSI	; SD-Card
	cbi	VPORTC_DIR, MISO	; SD-Card
	sbi	VPORTC_DIR, SCK		; SD-Card
	sbi	VPORTC_DIR, SS		; SD-Card
	
;
;	Activate Pull-Up for CD and WP of SD-Card slot
;
	ldi	r18, PORT_PULLUPEN_bm
	sts	PORTC_PIN2CTRL, r18
	sts	PORTC_PIN3CTRL, r18
;
;	Alternate PINs for SPI1
;
	ldi	r18, PORTMUX_SPI1_ALT1_gc; SPI1 on PC4..7
	sts	PORTMUX_SPIROUTEA, r18
;-----------------------------------------------------------------------------
;
;	PORT D (Bits0..7)
;
;	Data Port used as debug port, initialised as output
;
#define	dataportout	VPORTD_OUT
#define dataportin	VPORTD_IN
#define dataportdir	VPORTD_DIR
	ldi	r18, 0x00
	out	VPORTD_DIR, r18
;-----------------------------------------------------------------------------
;
;	PORT E (Bits0..3)
;
.equ	INTI	= 0			; IACK cycle interrupt
.equ	INTQ	= 1			; DATI/DATO cycle interrupt
.equ	LED	= 2			; Activity LED
.equ	INIT	= 3			; Bus INIT interrupt

#define	i_INTI	VPORTE_IN, INTI
#define	f_INTI	VPORTE_INTFLAGS, INTI
#define	c_INTI	PORTE_PIN0CTRL

#define	i_INTQ	VPORTE_IN, INTQ
#define	f_INTQ	VPORTE_INTFLAGS, INTQ
#define	c_INTQ	PORTE_PIN1CTRL

#define	b_LED	VPORTE_OUT, LED

#define	i_INIT	VPORTE_IN, INIT
#define	f_INIT	VPORTE_INTFLAGS, INIT
#define	c_INIT	PORTE_PIN3CTRL

	cbi	VPORTE_DIR, INTI
	cbi	VPORTE_DIR, INTQ
	cbi	VPORTE_DIR, INIT
	sbi	VPORTE_DIR, LED

	cbi	VPORTE_OUT, INTI
	cbi	VPORTE_OUT, INTQ
	cbi	VPORTE_OUT, INIT
	cbi	VPORTE_OUT, LED

	sbi	f_INTI			; Acknowledge any pending interrupt
	ldi	r18, PORT_ISC_LEVEL_gc	; Level Sense Interrupt
;	ldi	r18, PORT_ISC_FALLING_gc
	sts	c_INTI, r18		; Pin Control

	sbi	f_INTQ			; Acknowledge any pending interrupt
	ldi	r18, PORT_ISC_LEVEL_gc	; Level Sense Interrupt
;	ldi	r18, PORT_ISC_FALLING_gc
	sts	c_INTQ, r18		; Pin Control

	sbi	f_INIT			; Acknowledge any pending interrupt
	ldi	r18, PORT_ISC_BOTHEDGES_gc	; Level Sense Interrupt
	sts	c_INIT, r18		; Pin Control

	ldi	r18, PORTE_PORT_vect/2	; 
	sts	CPUINT_LVL1VEC, r18
;-----------------------------------------------------------------------------
;
;	PORT F (Bits0..5, Bit6 is Reset and may be used as input but not here)
;
.equ	MEM	= 0			; Malloc Interrupt
.equ	SIG	= 1			; Signal
.equ	QDE	= 2			; Controller Ready
.equ	IRQ	= 3			; Interrupt Request
.equ	RD	= 4			; Register Read
.equ	WR	= 5			; Register Write

#define	b_MEM	VPORTF_OUT, MEM
#define	b_SIG	VPORTF_OUT, SIG
#define	b_QDE	VPORTF_OUT, QDE
#define	b_IRQ	VPORTF_OUT, IRQ
#define	b_RD	VPORTF_OUT, RD
#define	b_WR	VPORTF_OUT, WR

#define b_MEM	VPORTF_OUT, MEM
#define	f_MEM	VPORTF_INTFLAGS, MEM
#define	c_MEM	PORTF_PIN0CTRL

	sbi	VPORTF_DIR, MEM
	sbi	VPORTF_DIR, SIG
	sbi	VPORTF_DIR, QDE		; True CRDY
	sbi	VPORTF_DIR, IRQ
	sbi	VPORTF_DIR, RD
	sbi	VPORTF_DIR, WR
	
	cbi	b_SIG
	sbi	b_QDE
	cbi	b_IRQ
	cbi	b_RD
	cbi	b_WR
	
	sbi	b_MEM			; Set Level = High 
	sbi	f_MEM			; Acknowledge any pending interrupt
	ldi	r18, PORT_ISC_LEVEL_gc	; Level Sense Interrupt
	sts	c_MEM, r18		; Pin Control


;=============================================================================
;
;	Map Flash section 2 to Data address space
;
	ldi	r18, CPU_CCP_IOREG_gc
	sts	CPU_CCP, r18
	ldi     r18, NVMCTRL_FLMAP_SECTION2_gc
	sts     NVMCTRL_CTRLB, r18

	call	SPI_init
;=============================================================================
;
;	USART 1
;
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
;
;	Driver usage is controlled by GPR_GPR0
;	Logging uses GPR_GPR1
;	Level1 interrupt uses GPR_GPR2 and GPR-GPR3
;
	cbi	GPR_GPR0, serin__drv		; Polled 
	cbi	GPR_GPR0, serout__drv

;=============================================================================
;
;	Tick Interrupt (every 1ms) Timer TCB0
;
;	Remark, a ticker every 1ms seems to be a lot, however the RTOS is
;	very small and we only have a limited number of active timers at
;	each moment, so the overhead is still less than 5%.  
;	Compared to the Atmega1248P used in the RLV12 emulator we have 
;	more CPU power (about 30% as we overclock to 32MHz) this more
;	than compensates the tick overhead, on the other hand 1ms tick
;	allows very small delays required by IO without hogging the CPU.
;
	ldi	r18, low(F_CPU/1000)	; 1ms
	sts	TCB0_CCMPL, r18
	ldi	r18, high(F_CPU/1000)
	sts	TCB0_CCMPH, r18

	ldi	r18, 0
	sts	TCB0_CTRLB, r18

	ldi	r18, TCB_CAPT_bm
	sts	TCB0_INTCTRL, r18

	ldi	r18, TCB_ENABLE_bm+TCB_RUNSTDBY_bm+TCB_CLKSEL_DIV1_gc
	sts	TCB0_CTRLA, r18
;=============================================================================
;
;	Timer 
;
;	TCA0 is run in split mode and provides the base time intervalls
;	for the other timers. It will producde two intervalls
;	1usec	this will be used by TCB1 to count the IO time
;	4usec	this will be used by TCB2 for the time stamp
;
;
;
;=============================================================================
;
;	Base Intervall Timer TCA0
;
;	Timer A is used to create the base ticks for TCB1 and TCB2.
;
;	We want TCB1 to directly measure the time of SD-Card IO 
;	operations in micro seconds. 
;
;	TCB2 is used as the timestamp for the logging. As logging
;	never takes place faster than the PDP-11 accesses the device
;	register a granularity of approx 4 micro seconds is fine to
;	notice an increase in the timestamp of consecutive reads or
;	writes of device registers. On the other hand it should not
;	be too short, so we can detect gaps as long as possible
;	as we only use the low-byte of TCB2 in the timestamp of
;	log messages this will let us know if access to device
;	registers are appart as much as 256*4 = 1024, wnich is
;	more than 1ms, a very long time for a PDP-11.
;
;	For this we operate Timer A in split mode and set the 
;	period of the lower counter to 1usec and the period of the
;	upper counter to 4usec based on the F_CPU variable
;
;	Although you cannot control Timer A in split mode via
;	events Timer A still can create events independently for
;	each half of the timer.
;
;	The timer is clocked by the CPU frequency and hence the
;	period of the lower half is set to 31 and the period of
;	the upper half is set to 127. Note that a period cannot
;	exceed 255 as each half only has 8-bits
;
	ldi	r18, TCA_SPLIT_SPLITM_bm	; We only need a 8-bit counter
	sts	TCA0_SINGLE_CTRLD, r18

	ldi	r18, low(F_CPU/1000000-1)	; Low Counter = 1usec
	sts	TCA0_SPLIT_LPER, r18		; Period in normal mode
	ldi	r18, low(4*F_CPU/1000000-1)	; High Counter = 4usec
	sts	TCA0_SPLIT_HPER, r18		; Period in normal mode
	ldi	r18, 0
	sts	TCA0_SINGLE_CTRLC, r18		; 
	ldi	r18, 0
	sts	TCA0_SINGLE_CTRLB, r18
	ldi	r18, TCA_SINGLE_CLKSEL_DIV1_gc | TCA_SINGLE_ENABLE_bm
	sts	TCA0_SINGLE_CTRLA, r18
;
;	Setup Event Channel 0 for the TCA0 Low byte underflow Capture flag
;
	ldi	r18, EVSYS_CHANNEL0_TCA0_OVF_LUNF_gc
	sts	EVSYS_CHANNEL0, r18
;
;	Connect the Count Input of TCB1 to Event Channel 0
;
	ldi	r18, EVSYS_USER_CHANNEL0_gc
	sts	EVSYS_USERTCB1COUNT, r18; To Obsever Channel 0
;
;	TCB1 counts the events of event channel 0 in other words it
;	counts the microseconds the SD_CARD_READ takes.
;
	ldi	r18, 0xFF
	sts	TCB1_CCMPL, r18
	sts	TCB1_CCMPH, r18
	sts	TCB1_CNTL, zero
	sts	TCB1_CNTH, zero
	ldi	r18, TCB_CNTMODE_INT_gc
	sts	TCB1_CTRLB, r18		
	ldi	r18, TCB_ENABLE_bm + TCB_CLKSEL_EVENT_gc
	sts	TCB1_CTRLA, r18
;
;	Setup Event Channel 1 for the TCA0 High byte underflow Capture flag
;
	ldi	r18, EVSYS_CHANNEL1_TCA0_HUNF_gc
	sts	EVSYS_CHANNEL1, r18
;
;	Connect the Count Input of TCB2 to Event Channel 1
;
	ldi	r18, EVSYS_USER_CHANNEL1_gc
	sts	EVSYS_USERTCB2COUNT, r18; To Obsever Channel 1
;
;	TCB1 counts the events of event channel 1 in other words it
;	counts the 4usec base ticks generated by the upper half
;
	ldi	r18, 0xFF
	sts	TCB2_CCMPL, r18
	sts	TCB2_CCMPH, r18
	sts	TCB2_CNTL, zero
	sts	TCB2_CNTH, zero
	ldi	r18, TCB_CNTMODE_INT_gc
	sts	TCB2_CTRLB, r18		
	ldi	r18, TCB_ENABLE_bm + TCB_CLKSEL_EVENT_gc
	sts	TCB2_CTRLA, r18
;=============================================================================
;
;	Print Hello Message
;
	call	print
	.db	"Starting Universal Disk Controller!", CR, LF, 0

;=============================================================================
;
;	Print low bytes
;
	sbis	GPR_GPR3, 0
	rjmp	nogpr
	ldi	xl, low(INTERNAL_SRAM_START)
	ldi	xh, high(INTERNAL_SRAM_START)
	ldi	zl, low(pprint)
	ldi	zh, high(pprint)
	ldi	r16, 16
gpr010:
	ld	r18, X+
	st	Z+, r18
	dec	r16
	brne	gpr010
	call	print
	.db	CR, LF
	.db	"Content of uninitialized RAM"
	.db	CR, LF
	.db	" ", 0x80
	.db	" ", 0x81
	.db	" ", 0x82
	.db	" ", 0x83
	.db	" ", 0x84
	.db	" ", 0x85
	.db	" ", 0x86
	.db	" ", 0x87
	.db	" ", 0x88
	.db	" ", 0x89
	.db	" ", 0x8a
	.db	" ", 0x8b
	.db	" ", 0x8c
	.db	" ", 0x8d
	.db	" ", 0x8e
	.db	" ", 0x8f
	.db	0, 0
	ldi	zl, low(pprint)
	ldi	zh, high(pprint)
	ldi	r16, 16
gpr020:
	ld	r18, X+
	st	Z+, r18
	dec	r16
	brne	gpr020
	call	print
	.db	CR, LF
	.db	" ", 0x80
	.db	" ", 0x81
	.db	" ", 0x82
	.db	" ", 0x83
	.db	" ", 0x84
	.db	" ", 0x85
	.db	" ", 0x86
	.db	" ", 0x87
	.db	" ", 0x88
	.db	" ", 0x89
	.db	" ", 0x8a
	.db	" ", 0x8b
	.db	" ", 0x8c
	.db	" ", 0x8d
	.db	" ", 0x8e
	.db	" ", 0x8f
	.db	CR, LF, 0, 0
nogpr:
	cbi	GPR_GPR3, 0
	ldi	xl, low(INTERNAL_SRAM_START)
	ldi	xh, high(INTERNAL_SRAM_START)
	ldi	r16, 32
gpr030:
	st	X+, zero
	dec	r16
	brne	gpr030
	

;=============================================================================
;
;	Start without RTOS
;
;	call	rlv12_reset
;	ldi	r24, low(usersp0)	
;	ldi	r25, high(usersp0)	
;	out	CPU_SPL, r24
;	out	CPU_SPH, r25
;	sei
;	rjmp	readcmd

;=============================================================================
;
;	Create Main Job
;
	ldi	zl, low(jcb0)
	ldi	zh, high(jcb0)
		
	ldi	xl, low(main)		; start address requries word address
	ldi	xh, high(main)
	
	ldi	r24, low(usersp0)	
	ldi	r25, high(usersp0)	
	
	ldi	r18, 3			; Priority
	std	Z+jcb_stack+0, r24	; Pointer past stack area
	std	Z+jcb_stack+1, r25
	std	Z+jcb_joblist+0, xl
	std	Z+jcb_joblist+1, xh
	std	Z+jcb_priority, r18
	std	Z+jcb_flags, zero

	call	print
	.db	"Create Main Job", CR, LF, 0
	call	prtcreate

	ldi	r18, USART_RXCIE_bm	; Enable RX interrupt for RTOS
	sts	USART1_CTRLA, r18
	sbi	GPR_GPR0, serin__drv		; Activate Serial Driver
	sbi	GPR_GPR0, serout__drv
	movw	r25:r24, zh:zl
	sei
	call	create
;=============================================================================
;
;	mini RT-OS
;
.include	"rtos-v2-2.asm"
;=============================================================================
;
;	Support routines
;
seroutcrlf:
	ldi	r24, CR
	rcall	serout
	ldi	r24, LF

serout:
	sbic	GPR_GPR0, serout__drv		; Is driver active
	rjmp	serout_1		; Then call driver
	push	r24			; Else proceed with polled IO
serout100:
	lds	r24, USART1_STATUS
	sbrs	r24, USART_DREIF_bp
	rjmp	serout100
	pop	r24
	sts	USART1_TXDATAL, r24
	ret

serin:
	sbic	GPR_GPR0, serin__drv		; Is driver active
	rjmp	serin_1			; Then call driver
serin100:				; Else proceed with polled IO
	lds	r24, USART1_STATUS
	sbrs	r24, USART_RXCIF_bp
	rjmp	serin100
	lds	r24, USART1_RXDATAL
	ret
;=============================================================================
;
;	Serial Driver using Interrupt routines
;	
.include	"serial1.asm"
;=============================================================================
;
;
.include "monitor-chartbl-v2-0.inc"
	.db	0, "K"		; crc
	.db	0, "S"		; SD
	.db	0, "R"
	.db	0, "W"
	.db	0, "G"
	.db	0, 'F' & 0x1F
;	.db	0, 'Q'
	.db	0, 'O'
	.db	0, 'T'
	.db	0, 'U'
;	I	1S	.dw	mon_sd_card_spi		SD_CARD_SPI
;	H	2S	.dw	mon_sd_card_ifc		SD_CARD_IFC
;	J	3S	.dw	mon_sd_card_init	SD_CARD_INIT
;	K	4S	.dw	mon_sd_card_readocr	SD_CARD_READOCR
;	L	5S	.dw	mon_sd_card_blklen	SD_CARD_BLKLEN

.include "monitor-subtbl-v2-0.inc"
	.dw	moncrc7
	.dw	SD_main
	.dw	monsdreadsector
	.dw	monsdwritesector
	.dw	monstack
	.dw	fdisk
;	.dw	readcmd
	.dw	mountcmd
	.dw	mondrivecmd
	.dw	dismountcmd

.include "monitor-v2-0.asm"
;=============================================================================
;
;	The Jobs
;
;-----------------------------------------------------------------------------
;
;	
main:
	call	print
	.db	CR, LF, "Hallo RTOS on Universal Disk Emulator ", CR, LF, 0, 0

	call	rlv12_reset

	ldi	r18, 9
	ldi	zl, low(jcb1)
	ldi	zh, high(jcb1)
	ldi	xl, low(carddetect)	; start address requires word address
	ldi	xh, high(carddetect)
	ldi	r24, low(usersp1)	
	ldi	r25, high(usersp1)	
	std	Z+jcb_stack+0, r24
	std	Z+jcb_stack+1, r25
	std	Z+jcb_joblist+0, xl
	std	Z+jcb_joblist+1, xh
	std	Z+jcb_priority, r18	; carddetect job
	clr	r18
	std	Z+jcb_flags, r18
	call	print
	.db	"Create carddetect Job", CR, LF, 0
	call	prtcreate
	movw	r25:r24, zh:zl
	call	create

	ldi	r18, 2
	ldi	zl, low(jcb2)
	ldi	zh, high(jcb2)
	ldi	xl, low(rlv12job)	; start address requires word address
	ldi	xh, high(rlv12job)
	ldi	r24, low(usersp2)	
	ldi	r25, high(usersp2)	
	std	Z+jcb_stack+0, r24
	std	Z+jcb_stack+1, r25
	std	Z+jcb_joblist+0, xl
	std	Z+jcb_joblist+1, xh
	std	Z+jcb_priority, r18	; carddetect job
	clr	r18
	std	Z+jcb_flags, r18
	call	print
	.db	"Create RLV12 Job", CR, LF, 0, 0
	call	prtcreate
	movw	r25:r24, zh:zl
	call	create

	ldi	r18, 1
	ldi	zl, low(jcb3)
	ldi	zh, high(jcb3)
	ldi	xl, low(dummyjob)	; start address requires word address
	ldi	xh, high(dummyjob)
	ldi	r24, low(usersp3)	
	ldi	r25, high(usersp3)	
	std	Z+jcb_stack+0, r24
	std	Z+jcb_stack+1, r25
	std	Z+jcb_joblist+0, xl
	std	Z+jcb_joblist+1, xh
	std	Z+jcb_priority, r18	; carddetect job
	clr	r18
	std	Z+jcb_flags, r18
	call	print
	.db	"Create Dummy Job", CR, LF, 0, 0
	call	prtcreate
	movw	r25:r24, zh:zl
	call	create



;
;	Directly enter readcommand
;
;--------------------------------------------------------------------------
;
;	Adjust the existing log_pointer to a valid value, that is it must
;	point to the log_buffer and must be a multiple of 8.
;
readcmd:
	lds	r16, RSTCTRL_RSTFR
	sbrc	r16, RSTCTRL_PORF_bp
	rcall	loginit

	lds	r16, log_pointer+0	; Make sure log pointer starts
	lds	r17, log_pointer+1	; at a 8 byte boundary
	andi	r16, 0xF8
	andi	r17, high(log_size)
	ori	r17, high(log_buffer)
	sts	log_pointer+0, r16
	sts	log_pointer+1, r17	
	ldi	r18, (1<<log__reg) | (1<<log__iack) | log__units
	out	GPR_GPR1, r18

	sts	InputBuffer, zero
	sbi	GPR_GPR0, sddetect__en		; Enable SD detect
readcmd010:
	ldi	r22, ']'		; Prompt
	ldi	r24, low(InputBuffer)
	ldi	r25, high(InputBuffer)
	call	readcmdline

	cpi	r24, 0;cmdok		; 
	brne	readcmd040
	lds	r18, InputBuffer
	cpi	r18, 0
	breq	readcmd010
	cpi	r18, CR
	breq	readcmd010		; do not save empty command
	ldi	xl, low(InputBuffer)	; Command
	ldi	xh, high(InputBuffer)
	ldi	zl, low(HistoryBuffer)
	ldi	zh, high(HistoryBuffer)
readcmd020:
	ld	r18, X+
	st	Z+, r18
	cpi	r18, 0
	breq	readcmd030
	cpi	r18, CR
	breq	readcmd030
	rjmp	readcmd020
readcmd030:
;
;	Old Calling Convention to TPARSE
;
	ldi	xl, low(InputBuffer)	; Command
	ldi	xh, high(InputBuffer)
	ldi	zl, low(2*commandlist)	; Parser table
	ldi	zh, high(2*commandlist)
	sts	tpflags, zero
	call	scancommand		; call TParse
	sts	InputBuffer, zero
	rjmp	readcmd010

readcmd040:
	cpi	r24, 1;cmdup		; 
	brne	readcmd060
	ldi	xl, low(HistoryBuffer)
	ldi	xh, high(HistoryBuffer)
	ldi	zl, low(InputBuffer)	; Command
	ldi	zh, high(InputBuffer)
readcmd050:
	ld	r18, X+
	st	Z+, r18
	cpi	r18, 0
	breq	readcmd010
	cpi	r18, CR
	breq	readcmd010
	rjmp	readcmd050

readcmd060:
	sts	InputBuffer, zero
	rjmp	readcmd010
;--------------------------------------------------------------------------
;
;	DUMMY JOB
;
dummyjob:
	clr	r0
	mov	r1, r0
	inc	r1
	mov	r2, r1
	inc	r2
	mov	r3, r2
	inc	r3
	mov	r4, r3
	inc	r4
	mov	r5, r4
	inc	r5
	mov	r6, r5
	inc	r6
	mov	r7, r6
	inc	r7
	mov	r8, r7
	inc	r8
	mov	r9, r8
	inc	r9
	mov	r10, r9
	inc	r10
	mov	r11, r10
	inc	r11
	mov	r12, r11
	inc	r12
	mov	r13, r12
	inc	r13
	mov	r14, r13
	inc	r14
	mov	r15, r14
	inc	r15
	mov	r16, r15
	inc	r16
	mov	r17, r16
	inc	r17
	mov	r18, r17
	inc	r18
	mov	r19, r18
	inc	r19
	mov	r20, r19
	inc	r20
	mov	r21, r20
	inc	r21
	mov	r22, r21
	inc	r22
	mov	r23, r22
	inc	r23
	mov	r24, r23
	inc	r24
	mov	r25, r24
	inc	r25
	mov	r26, r25
	inc	r26
	mov	r27, r26
	inc	r27
	mov	r28, r27
	inc	r28
	mov	r29, r28
	inc	r29
	mov	r30, r29
	inc	r30
	mov	r31, r30
	inc	r31
	rjmp	dummyjob
;--------------------------------------------------------------------------
;
loginit:

	ldi	yl, low(log_buffer)
	ldi	yh, high(log_buffer)
	sts	log_pointer+0, yl
	sts	log_pointer+1, yh
	ldi	r24, low(log_size+1)
	ldi	r25, high(log_size+1)
loginit010:
	st	Y+, zero
	sbiw	r25:r24, 1
	brne	loginit010
	ret
;--------------------------------------------------------------------------
;
;	Automount/Autodismount
;
carddetect:
	ldi	yl, 0xFF
	cbi	GPR_GPR0, sdcard__insert		; assert pending insertion
	clr	r12
	ldi	yh, 0xFF
	cbi	GPR_GPR0, sdcard__remove		; assert pending removal
	clr	r13	
;	
;	Start the debounce timer (5msec) and initialise SD-Card status vars.
;	
carddetect100:
	push	yl
	push	yh
	ldi	r24, low(5)
	ldi	r25, high(5)
	call	delay
	cli
	sbi	b_SIG
	nop
	nop
	cbi	b_SIG
	nop
	nop
	sbi	b_SIG
	nop
	nop
	cbi	b_SIG
	nop
	nop
	sbi	b_SIG
	nop
	nop
	cbi	b_SIG
	nop
	nop
	sbi	b_SIG
	nop
	nop
	cbi	b_SIG
	nop
	nop
	sbi	b_SIG
	nop
	nop
	cbi	b_SIG
	nop
	nop
	sbi	b_SIG
	nop
	nop
	cbi	b_SIG
	nop
	nop
	sei

	pop	yh
	pop	yl

	lds	r16, led_oneshot
	dec	r16
	brpl	carddetect105
	clr	r16
	cbi	b_LED
carddetect105:
	sts	led_oneshot, r16

	lds	r16, sdprint+6
	sts	sdprint+7, r16
	lds	r16, sdprint+5
	sts	sdprint+6, r16
	lds	r16, sdprint+4
	sts	sdprint+5, r16
	lds	r16, sdprint+3
	sts	sdprint+4, r16
	lds	r16, sdprint+2
	sts	sdprint+3, r16
	lds	r16, sdprint+1
	sts	sdprint+2, r16
	lds	r16, sdprint+0
	sts	sdprint+1, r16

	lds	r16, sdprint+14
	sts	sdprint+15, r16
	lds	r16, sdprint+13
	sts	sdprint+14, r16
	lds	r16, sdprint+12
	sts	sdprint+13, r16
	lds	r16, sdprint+11
	sts	sdprint+12, r16
	lds	r16, sdprint+10
	sts	sdprint+11, r16
	lds	r16, sdprint+9
	sts	sdprint+10, r16
	lds	r16, sdprint+8
	sts	sdprint+9, r16

	clc
	sbic	i_CD			; Normal Input
	sec
	adc	yl, yl			; we shift the inputs every 5ms 
	ori	yl, 0xe0		; and look for a rising edge 
	cpi	yl, 0xf0
	brne	carddetect110
	sbi	GPR_GPR0, sdcard__insert		; rise card insertion flag
	inc	r12
carddetect110:

	clc
	sbis	i_CD			; Inverted Input
	sec
	adc	yh, yh			; we shift teh inputs every 5ms 
	ori	yh, 0xe0		; and look for a falling edge (inverted)
	cpi	yh, 0xf0
	brne	carddetect120
	sbi	GPR_GPR0, sdcard__remove		; rise card removal flag
	inc	r13
carddetect120:
	sbic	GPR_GPR0, sdcard__remove
	rcall	sdcardremove		; SD-Card was removed
	cbi	GPR_GPR0, sdcard__remove
	sbic	GPR_GPR0, sdcard__insert
	rcall	sdcardinsert		; SD-Card was inserted
	cbi	GPR_GPR0, sdcard__insert
	rjmp	carddetect100		; 

sdcardinsert:
	sts	sdprint+0, yl
	call	print
	.db	LF, CR, "SD Card inserted"
	.db	" 0x", 0x80
	.db	" 0x", 0x81
	.db	" 0x", 0x82
	.db	" 0x", 0x83
	.db	" 0x", 0x84
	.db	" 0x", 0x85
	.db	" 0x", 0x86
	.db	" 0x", 0x87
	.db	LF, CR, 0, 0
	call	SD_main
	call	MountVolume
	sbic	GPR_GPR0, sddetect__en		; Is CLI active
	call	redraw_1
	ret

sdcardremove:
	sts	sdprint+8, yh
	call	print
	.db	LF, CR, "SD Card removed "
	.db	" 0x", 0x88
	.db	" 0x", 0x89
	.db	" 0x", 0x8a
	.db	" 0x", 0x8b
	.db	" 0x", 0x8c
	.db	" 0x", 0x8d
	.db	" 0x", 0x8e
	.db	" 0x", 0x8f 
	.db	LF, CR, 0, 0
	call	DismountVolume
	sbic	GPR_GPR0, sddetect__en		; Is CLI active
	call	redraw_1
	ret

;--------------------------------------------------------------------------
;
;	
;
.include	"SD-Card-v1-0.asm"

;=============================================================================
;
;	To verify the crc7table we have here a list of sd-card commands with 
;	the precalcualted CRC-7, which can be found in the internet.
;	CRC-7 Calculation for SD-Cards includes the first byte, which consists
;	of the start bit (the MSB needs to be 0) and the data start bit (bit-6
;	which needs to be 1) and the command (bits5..0). In fact CRC is only
;	required until the card is in SPI mode because after this the CRC is
;	ignored.
;
tstcmd41:	.db	0x69, 0x40, 0x00, 0x00, 0x00, 0x77
tstcmd55:	.db	0x77, 0x00, 0x00, 0x00, 0x00, 0x65 
tstcmd58:	.db	0x7A, 0x00, 0x00, 0x00, 0x00, 0xfd
tstcmd9:	.db	0x49, 0x00, 0x00, 0x01, 0xAA, 0xeb
tstcmd8:	.db	0x48, 0x00, 0x00, 0x01, 0xAA, 0x87
tstcmd0:	.db	0x40, 0x00, 0x00, 0x00, 0x00, 0x95
moncrc7:

	ldi	yl, low(2*tstcmd0)
	ldi	yh, high(2*tstcmd0)
	rcall	moncrc7sub
	
	ldi	yl, low(2*tstcmd8)
	ldi	yh, high(2*tstcmd8)
	rcall	moncrc7sub

	ldi	yl, low(2*tstcmd9)
	ldi	yh, high(2*tstcmd9)
	rcall	moncrc7sub

	ldi	yl, low(2*tstcmd41)
	ldi	yh, high(2*tstcmd41)
	rcall	moncrc7sub

	ldi	yl, low(2*tstcmd55)
	ldi	yh, high(2*tstcmd55)
	rcall	moncrc7sub

	ldi	yl, low(2*tstcmd58)
	ldi	yh, high(2*tstcmd58)
	rcall	moncrc7sub

	ret

moncrc7sub:

	clr	crcl
	movw	Z, Y
	lpm	r16, Z+
	movw	Y, Z
	eor	crcl, r16
	andi	r16, 0x3f
	sts	pprint+2, r16
	clr	r16
	sts	pprint+3, r16
	mov	zl, crcl
	ldi	zh, high(2*crc7table)	
	lpm	crcl, Z
	
	movw	Z, Y
	lpm	r16, Z+
	movw	Y, Z
	eor	crcl, r16
	mov	zl, crcl
	ldi	zh, high(2*crc7table)	
	lpm	crcl, Z

	movw	Z, Y
	lpm	r16, Z+
	movw	Y, Z
	eor	crcl, r16
	mov	zl, crcl
	ldi	zh, high(2*crc7table)	
	lpm	crcl, Z

	movw	Z, Y
	lpm	r16, Z+
	movw	Y, Z
	eor	crcl, r16
	mov	zl, crcl
	ldi	zh, high(2*crc7table)	
	lpm	crcl, Z

	movw	Z, Y
	lpm	r16, Z+
	movw	Y, Z
	eor	crcl, r16
	mov	zl, crcl
	ldi	zh, high(2*crc7table)	
	lpm	crcl, Z

	ldi	r18, 0x01
	or	crcl, r18
	sts	pprint+0, crcl
	movw	Z, Y
	lpm	r16, Z
	sts	pprint+1, r16
	call	print
	.db	"CRC of CMD", 0xc2," is 0x", 0x80, " and should be 0x", 0x81, CR, LF, 0, 0
	ret

;--------------------------------------------------------------------------
;
;
;
monstack:
	sts	pprint+14, zl
	sts	pprint+15, zh
	push	zl
	push	zh
	ldi	r18, 0xaa
	push	r18
	ldi	r18, 0x55
	push	r18
	in	r18, CPU_SPL
	sts	pprint+0, r18
	in	r18, CPU_SPH
	sts	pprint+1, r18
	ldi	r18, low(monstackret)
	sts	pprint+2, r18
	ldi	r18, high(monstackret)
	sts	pprint+3, r18
	rcall	monstackcall	
monstackret:
	call	print
	.db	"Stack pointer at entry to monstack .......0x", 0x81, 0x80, CR, LF
	.db	"Address of label monstackret .............0x", 0x83, 0x82, CR, LF
	.db	"Stack address at monstackcall ............0x", 0x85, 0x84, CR, LF
	.db	"Memory Value at stack+0 ..................0x", 0x86, " ", CR, LF
	.db	"Memory Value at stack+1 ..................0x", 0x87, " ", CR, LF
	.db	"Memory Value at stack+2 ..................0x", 0x88, " ", CR, LF
	.db	"Memory Value at stack+3 ..................0x", 0x89, " ", CR, LF
;	.db	"Return Address fetched at monstackcall ...0x", 0x87, 0x86, CR, LF
;	.db	"Next two bytes on stack at monstackcall ..0x", 0x89, 0x88, CR, LF
	.db	"Value of Z register entering monstack ....0x", 0x8f, 0x8e, CR, LF
	.db	0, 0
	pop	r18
	pop	r18
	pop	zh
	pop	zl
	ret


monstackcall:
	ldi	r18, 0xff
	push	r18
	in	zl, CPU_SPL
	in	zh, CPU_SPH
	sts	pprint+4, zl
	sts	pprint+5, zh
	ldd	r18, Z+0
	sts	pprint+6, r18
	ldd	r18, Z+1
	sts	pprint+7, r18
	ldd	r18, Z+2
	sts	pprint+8, r18
	ldd	r18, Z+3
	sts	pprint+9, r18
	pop	r18
	ret
;--------------------------------------------------------------------------
;
;		"avrmem"<"pdp11memstart"."pdp11memend"R
;
;		'avrmem(a4)'<'sector(a1)'R
monsdreadsector:
	push	r0
	push	r1
	push	xl
	push	xh
	push	yl
	push	yh
	push	zl
	push	zh

	ldi	zl, low(sdio)
	ldi	zh, high(sdio)

	lds	r18, a1l
	std	Z+P_Sector+0, r18
	lds	r18, a1h
	std	Z+P_Sector+1, r18
	lds	r18, a1b
	std	Z+P_Sector+2, r18
	std	Z+P_Sector+3, zero
	
	lds	xl, a4l
	lds	xh, a4h
	std	Z+P_Address+0, xl
	std	Z+P_Address+1, xh
	movw	r25:r24, zh:zl
	cbi	b_QDE
	call	SD_sendRead
	sbi	b_QDE
	cpse	r24, zero
	rjmp	monsdread900
	call	print
	.db	"Success!", CR, LF, 0, 0

	lds	xl, a4l
	lds	xh, a4h
	clr	r16
	push	crcl
	push	crch
	clr	crcl
	clr	crch
monsdread010:
	ld	r18, X+
	updcrc	r18
	ld	r18, X+
	updcrc	r18
	dec	r16
	brne	monsdread010
	sts	pprint+0, crcl
	sts	pprint+1, crch
	lds	r18, sdio+P_Duration+0
	sts	pprint+4, r18
	lds	r18, sdio+P_Duration+1
	sts	pprint+5, r18
	call	print
	.db	"CRC Calculated 0x", 0x81, 0x80, " ", CR, LF
	.db	"Read took ", 0xC4, "usec", CR, LF, 0
	pop	crch
	pop	crcl
	rjmp	monsdread990
monsdread900:
	cpi	r24, 1
	brne	monsdread910
	call	print
	.db	"*** Error: Command Rejected ***", CR, LF, 0
	rjmp	monsdread990
monsdread910:
	cpi	r24, 2
	brne	monsdread920
	lds	r18, sdio+P_Error+0
	sts	pprint+0, r18
	call	print
	.db	"*** Error: Invalid Data Token Received 0x", 0x80, " *** ", CR, LF, 0
	rjmp	monsdread990
monsdread920:
	cpi	r24, 3
	brne	monsdread930
	call	print
	.db	"*** Error: Timeout Data Token ***", CR, LF, 0
	rjmp	monsdread990
monsdread930:
	cpi	r24, 4
	brne	monsdread940
	lds	r18, sdio+P_Error+0
	sts	pprint+0, r18
	lds	r18, sdio+P_Error+1
	sts	pprint+1, r18
	call	print
	.db	"*** Error: CRC Error 0x", 0x81, 0x80, " ***", CR, LF, 0
	rjmp	monsdread990
monsdread940:
	sts	pprint+0, r24
	call	print
	.db		"*** Error: unkonw error 0x", 0x80, CR, LF, 0

monsdread990:
	pop	zh
	pop	zl
	pop	yh
	pop	yl
	pop	xh
	pop	xl
	pop	r1
	pop	r0
	ret	

monsdwritesector:
	push	r0
	push	r1
	push	xl
	push	xh
	push	yl
	push	yh
	push	zl
	push	zh
	lds	xl, a1l
	lds	xh, a1h
	clr	r16
	push	crcl
	push	crch
	clr	crcl
	clr	crch
monsdwrite010:
	ld	r18, X+
	updcrc	r18
	ld	r18, X+
	updcrc	r18
	dec		r16
	brne	monsdwrite010
	sts	pprint+0, crcl
	sts	pprint+1, crch
	pop	crch
	pop	crcl
	call	print
	.db	"CRC Calculated 0x", 0x81, 0x80, CR, LF, 0
	ldi	zl, low(sdio)
	ldi	zh, high(sdio)
	lds	r18, a4l
	std	Z+P_Sector+0, r18
	lds	r18, a4h
	std	Z+P_Sector+1, r18
	lds	r18, a4b
	std	Z+P_Sector+2, r18
	std	Z+P_Sector+3, zero
	lds	xl, a1l
	lds	xh, a1h
	std	Z+P_Address+0, xl
	std	Z+P_Address+1, xh
	movw	r25:r24, zh:zl
	call	SD_sendWrite
	lds	r18, sdio+P_Duration+0
	sts	pprint+0, r18
	lds	r18, sdio+P_Duration+1
	sts	pprint+1, r18
	call	print
	.db	"Write took ", 0xC0, "usec", CR, LF, 0, 0
	cpse	r24, zero
	rjmp	monsdwrite900
	call	print
	.db	"Success!", CR, LF, 0, 0
	rjmp	monsdwrite990
monsdwrite900:
	cpi	r24, 1
	brne	monsdwrite910
	call	print
	.db	"*** Error: Command Rejected ***", CR, LF, 0
	rjmp	monsdwrite990
monsdwrite910:
	cpi	r24, 2
	brne	monsdwrite920
	call	print
	.db	"*** Error: Timeout Data Response *** ", CR, LF, 0
	rjmp	monsdwrite990
monsdwrite920:
	cpi	r24, 3
	brne	monsdwrite930
	lds	r18, sdio+P_Error+0
	sts	pprint+0, r18
	call	print
	.db	"*** Error: Data Rejected 0x", 0x80, " *** ", CR, LF, 0
	rjmp	monsdwrite990
monsdwrite930:
	cpi	r24, 4
	brne	monsdwrite940
	call	print
	.db	"*** Error: Timeout Get Ready *** ", CR, LF, 0
	rjmp	monsdwrite990
monsdwrite940:
	sts	pprint, r24
	call	print
	.db	"*** Error: unkown error 0x", 0x80, CR, LF, 0
monsdwrite990:
	pop	zh
	pop	zl
	pop	yh
	pop	yl
	pop	xh
	pop	xl
	pop	r1
	pop	r0
	ret	

;--------------------------------------------------------------------------
;
mondrivecmd:
	call	print
	.db	CR, LF
	.db	"mondrivecmd "
	.db	CR, LF, 0, 0
	lds	r16, a1l
	lds	r17, a1h
	lds	r18, a1b
	clr	r19
	sts	pprint+0, r16
	sts	pprint+1, r17
	sts	pprint+2, r18
	sts	pprint+3, r19
	call	print
	.db	CR, LF
	.db	"Looking for Drive with size 0x", 0x83, 0x82, 0x81, 0x80
	.db	CR, LF, 0, 0

	movw	r23:r22, r17:r16
	movw	r25:r24, r19:r18

	call	FindDriveEntry
	sts	pprint+0, r24
	sts	pprint+1, r25
	call	print
	.db	"Find Drive Entry returned 0x", 0x81, 0x80
	.db	CR, LF, 0, 0
	ret
	
;--------------------------------------------------------------------------
;
dismountcmd:
	call	DismountVolume
	ret

mountcmd:
	call	MountVolume
	ldi	r24, low(volqueue)
	ldi	r25, high(volqueue)
	sts	pprint+0, r24
	sts	pprint+1, r25
	ldi	r24, low(pcbqueue)
	ldi	r25, high(pcbqueue)
	sts	pprint+2, r24
	sts	pprint+3, r25
	sts	pprint+4, r24
	call	print
	.db	"Mount Volume 0x", 0x84, CR, LF
	.db	"    volqueue 0x", 0x81, 0x80, SPACE, CR, LF
	.db	"    pcbqueue 0x", 0x83, 0x82, CR, LF, 0

	lds	zl, volqueue+0
	lds	zh, volqueue+1
	sbiw	zh:zl, 0
	brne	mountcmd010
	ret
mountcmd010:
	ldd	r16, Z+Vol_Status
	sts	pprint, r16
	call	print
;		 ----+----1----+----2----+----3----+----4
	.db	"Status................................:", 0x80, CR, LF, 0, 0

	ldd	r16, Z+Vol_part1start+3
	sts	pprint+3, r16
	ldd	r16, Z+Vol_part1start+2
	sts	pprint+2, r16
	ldd	r16, Z+Vol_part1start+1
	sts	pprint+1, r16
	ldd	r16, Z+Vol_part1start+0
	sts	pprint+0, r16
	call	print
	.db	"Partition start.......................:", 0x83, 0x82, 0x81, 0x80, CR, LF, 0	

;	ldd	r16, Z+Vol_sectbefore+3
;	sts	pprint+3, r16
;	ldd	r16, Z+Vol_sectbefore+2
;	sts	pprint+2, r16
;	ldd	r16, Z+Vol_sectbefore+1
;	sts	pprint+1, r16
;	ldd	r16, Z+Vol_sectbefore+0
;	sts	pprint+0, r16
;	call	print
;	.db	"Sectors before this partition.........:", 0x83, 0x82, 0x81, 0x80, CR, LF, 0	

;	ldd	r16, Z+Vol_sectpart+3
;	sts	pprint+3, r16
;	ldd	r16, Z+Vol_sectpart+2
;	sts	pprint+2, r16
;	ldd	r16, Z+Vol_sectpart+1
;	sts	pprint+1, r16
;	ldd	r16, Z+Vol_sectpart+0
;	sts	pprint+0, r16
;	.db	"Partition size........................:", 0x83, 0x82, 0x81, 0x80, CR, LF, 0	

	ldd	r16, Z+Vol_NumFATs
	sts	pprint, r16
	call	print
	.db	"Number of FATs........................:", 0x80, CR, LF, 0, 0

	ldd	r16, Z+Vol_sectperfat+3
	sts	pprint+3, r16
	ldd	r16, Z+Vol_sectperfat+2
	sts	pprint+2, r16
	ldd	r16, Z+Vol_sectperfat+1
	sts	pprint+1, r16
	ldd	r16, Z+Vol_sectperfat+0
	sts	pprint+0, r16
	call	print
	.db	"Sectors per FAT.......................:", 0x83, 0x82, 0x81, 0x80, CR, LF, 0	

	ldd	r16, Z+Vol_sectperclst
	sts	pprint+0, r16
	call	print
	.db	"Sectors per cluster...................:", 0x80, CR, LF, 0, 0

	ldd	r16, Z+Vol_bytespsect+1
	sts	pprint+1, r16
	ldd	r16, Z+Vol_bytespsect
	sts	pprint+0, r16
	call	print
	.db	"Bytes per sector......................:", 0x81, 0x80, CR, LF, 0	

	ldd	r16, Z+Vol_reservedsect+1
	sts	pprint+1, r16
	ldd	r16, Z+Vol_reservedsect
	sts	pprint+0, r16
	call	print
	.db 	"Reserved sectors......................:", 0x81, 0x80, CR, LF, 0	

	ldd	r16, Z+Vol_fat1start+3
	sts	pprint+3, r16
	ldd	r16, Z+Vol_fat1start+2
	sts	pprint+2, r16
	ldd	r16, Z+Vol_fat1start+1
	sts	pprint+1, r16
	ldd	r16, Z+Vol_fat1start+0
	sts	pprint+0, r16
	call	print
	.db	"1st FAT starts at sector..............:", 0x83, 0x82, 0x81, 0x80, CR, LF, 0	

	ldd	r16, Z+Vol_datastart+3
	sts	pprint+3, r16
	ldd	r16, Z+Vol_datastart+2
	sts	pprint+2, r16
	ldd	r16, Z+Vol_datastart+1
	sts	pprint+1, r16
	ldd	r16, Z+Vol_datastart+0
	sts	pprint+0, r16
	call	print
	.db	"Data starts at sector.................:", 0x83, 0x82, 0x81, 0x80, CR, LF, 0	

	ldd	r16, Z+Vol_Status
	sbrc	r16, Vol__FAT32
	rjmp	mountcmd32info

	ldd	r16, Z+Vol_dirsectors
	sts	pprint+0, r16
	call	print
	.db	"FAT16 Volume with root dir sectors....:", 0x80, CR, LF, 0, 0
	
	ldd	r16, Z+Vol_rootdir+3
	sts	pprint+3, r16
	ldd	r16, Z+Vol_rootdir+2
	sts	pprint+2, r16
	ldd	r16, Z+Vol_rootdir+1
	sts	pprint+1, r16
	ldd	r16, Z+Vol_rootdir+0
	sts	pprint+0, r16
	call	print
	.db	"The root dir starts at sector.........:", 0x83, 0x82, 0x81, 0x80, CR, LF, 0
	ret

mountcmd32info:
	ldd	r16, Z+Vol_rootdir+3
	sts	pprint+3, r16
	ldd	r16, Z+Vol_rootdir+2
	sts	pprint+2, r16
	ldd	r16, Z+Vol_rootdir+1
	sts	pprint+1, r16
	ldd	r16, Z+Vol_rootdir+0
	sts	pprint+0, r16
	call	print
	.db	"FAT32 Volume root dir start cluster...:", 0x83, 0x82, 0x81, 0x80, CR, LF, 0
	ret


;--------------------------------------------------------------------------
;
prtcreate:
	sts	pprint+0, zl
	sts	pprint+1, zh
	ldd	r18, Z+2
	sts	pprint+2, r18
	ldd	r18, Z+3
	sts	pprint+3, r18
	ldd	r18, Z+4
	sts	pprint+4, r18
	ldd	r18, Z+5
	sts	pprint+5, r18
	ldd	r18, Z+6
	sts	pprint+6, r18
	ldd	r18, Z+7
	sts	pprint+7, r18

	call	print
	.db	0x09, "Job Control Block  0x", 0x81, 0x80, CR, LF
	.db	0x09, "Initial Stack      0x", 0x80+jcb_stack+1, 0x80+jcb_stack, CR, LF
	.db	0x09, "Programm Start     0x", 0x80+jcb_joblist+1, 0x80+jcb_joblist, CR, LF
	.db	0x09, "Priority/Flags     0x", 0x80+jcb_priority, ",0x", 0x80+jcb_flags, CR, LF, 00
	ret
;--------------------------------------------------------------------------
;
;	mprint routine to print a message
;
;	usage
;
;	call	mprint
;	.dw	<msgptr>
;
;	It makes use of the feature of the AVR128 mcu family that can map a 32kbyte
;	range of the flash to the normal data address space. Therefore the pointer
;	must match the address in the data space and the messages must be put
;	in the mapped portion of the flash
;
mprint:
	push	yl			; Save two pointer registers
	push	yh
	push	zl
	push	zh
	in	yl, CPU_SPL		; get stack pointer
	in	yh, CPU_SPH
	ldd	zl, Y+6			; get return address
	ldd	zh, Y+5
	adiw	zh:zl, 1		; increment return address (skip msg pointer)
	std	Y+6, zl			; update return address
	std	Y+5, zh
	sbiw	zh:zl, 1		; go back to msg pointer
	lsl	zl			; Make byte index
	rol	zh
	lpm	yl, Z+			; get message pointer
	lpm	yh, Z+
	push	r24
	push	r25
	push	xl
	push	xh
	ldi	xl, low(pprint)
	ldi	xh, high(pprint)
mprint010:	
	ld	r24, Y+
	tst	r24
	breq	mprint090
	cpi	r24, '%'
	brne	mprint080
	ld	r24, Y+
	tst	r24
	breq	mprint090
	cpi	r24, '%'
	breq	mprint080
	cpi	r24, 'c'
	brne	mprint020
	ld	r24, X+			; %c
	rjmp	mprint080
mprint020:
	cpi	r24, 'x'
	brne	mprint080		; %x
	ldi	r24, '0'
	call	serout
	ldi	r24, 'x'
	call	serout
	ld	r24, X+
	mov	zl, r24
	andi	r24, 0xF0
	swap	r24
	ori	r24, '0'
	cpi	r24, '9'+1
	brlo	mprint021
	subi	r24, ('0'-'A')
mprint021:
	call	serout
	movw	r24, zl
	andi	r24, 0xF0
	swap	r24
	ori	r24, '0'
	cpi	r24, '9'+1
	brlo	mprint080
	subi	r24, ('0'-'A')

mprint080:
	call	serout
	rjmp	mprint010
mprint090:
	pop	xh
	pop	xl
	pop	r25
	pop	r24
	pop	zh
	pop	zl
	pop	yh
	pop	yl
	ret


;--------------------------------------------------------------------------
;
;	
;
.include	"CPLD-v4-0.inc"		; CPLD Macroes 
.include	"print-v2-0.asm"
.include	"tparse-v2-0.asm"
.include	"Mountvolume.asm"
.include	"Dismountvolume.asm"
.include	"malloc-v2-2.asm"
.include	"CLI-table.inc"
.include	"CLI-action.asm"
.include	"CLI-attach.asm"
.include	"CLI-sub.asm"
.include	"CLI-directory.asm"
.include	"CLI-partition.asm"
.include	"CLI-show.asm"
.include	"CLI-dumpblock.asm"
.include	"CLI-fdisk.asm"
.include	"CLI-logging.asm"
.include	"CLI-commands.asm"
.include	"FAT-library-v2-0.asm"
.include	"FAT-fileio-v2-0.asm"
.include	"readcmdline.asm"
.include	"rlv12-v2-0.asm"
.include	"qbus-v2-0.asm"


.include	"crash.asm"


;--------------------------------------------------------------------------
;
;	The 3rd quarter of the flash will be mapped to the normal address
;	space.
;
;
	.org	0x8000
.include "DriveTab.inc"
.include "help.inc"

	align	4
TestTabFlash:
.equ TestTab = (TestTabFlash - 0x8000) * 2 + 0x8000
	.db	"This is the Test Tab Location!"

.equ ReadInitName = (PC - 0x8000) * 2 + 0x8000
	.db	"RLV12.INI", NULL
	
.include "Messages.inc"

.equ FNCName = (PC - 0x8000) * 2 + 0x8000
	.db	"Maint", 0, 0, 0
	.db	"WRCHK", 0, 0, 0
	.db	"GETST", 0, 0, 0
	.db	"SEEK ", 0, 0, 0
	.db	"RDHDR", 0, 0, 0
	.db	"Write", 0, 0, 0
	.db	"Read ", 0, 0, 0
	.db	"RDNCH", 0, 0, 0

.equ REGName = (PC - 0x8000) * 2 + 0x8000
	.db	"CSR", 0
	.db	"BAR", 0
	.db	"DAR", 0
	.db	"MPR", 0
	.db	"BEA", 0
	.db	"BO2", 0
	.db	"BO4", 0
	.db     "BO6", 0
