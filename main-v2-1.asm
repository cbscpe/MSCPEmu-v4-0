;
; Disk Emulator
;
; Created: 23.10.2021 16:20:20
; Author : peter
;
	.listmac

.include "macro-library-v1-1.asm"	; My standard macros
.include "FAT/FAT-defs.asm"		; FAT defintions

;=============================================================================
;
;	Definitions
;
.include "diskemu.inc"			; Global Definitions
.include "control-blocks.inc"		; Control Blocks
.include "error.inc"			; Error code definitions
#ifdef mscpemulation
.include "MSCP/_mscp.inc"
#endif
;--------------------------------------------------------------------------
;
;	Data Segment
;	
.include "main-v2-1.inc"		; Disk Emulator Data section

;=============================================================================
;
;	Flash Begin
;
;	Interrupt Vector Table
;
	.cseg
	.org	0
	jmp	start

	.org	RTC_CNT_vect		; Overflow interrupt for IO ticks
	jmp	iotick
	
	.org	RTC_PIT_vect		; PIT interrupt from RTC for tick
	jmp	tick

	.org	v_RTOS			; Software Interrupt RTOS
	jmp	rtos_

	.org	v_QBUS			; External Level 1 Q-Bus Interrupt
	jmp	qbus_			; Module qbus-v2-0.asm
	
	#ifdef	rlv12emulation
	.org	v_GO			; Software Interrupt Controller GO
	jmp	go_			; Module rlv12-v2-0.asm
	#endif
	#ifdef	mscpemulation
	.org	v_IP			; Software Interrupt Controller IP, SA
	jmp	poll_
	#endif

	.org	USART1_RXC_vect
	jmp	rxc1_isr
	
	.org	USART1_DRE_vect
	jmp	dre1_isr

	.org	INT_VECTORS_SIZE
;=============================================================================
;
;
start:
;
;	Check for Software Reset 
;
;	As we use software reset to re-initialise the MSCP controller
;	we must not re-initialise the SD-Card
;
	lds	r0, RSTCTRL_RSTFR
	sts	reset_status, r0	; Save it for later
	sts	RSTCTRL_RSTFR, r0	; Reset the flags
	sbrc	r0, RSTCTRL_WDRF_bp
	rjmp	crash
	sbrc	r0, RSTCTRL_SWRF_bp
	rjmp	start010
;
;	Not a Software Reset
;
	clr	r0
	sts	sd_status, r0		; Require a full initialisation
	cbi	FLAGS_COMMON, auto__boot
	cbi	FLAGS_COMMON, sddetect__en
	rjmp	start100
;
;	Software Reset, this is equivalent to a write to the IP 
;	register and restarts everything. However we assume that
;	an already inserted SD-Card is already initialised and
;	we just create the partion blocks again and read the
;	init file. We assume that "sd_status" has been saved
;	before doing a software reset
;
start010:
	cbi	FLAGS_COMMON, auto__boot
	cbi	FLAGS_COMMON, sddetect__en
;
;	Init
;	
start100:
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

;=============================================================================
;
;	Initialize RAM
;
;	During debugging we do the following. We assume that the RAM range
;	assigned does not exceed the first 4k pages
;
;	0x4xxx	is copied to 0x5xxx
;	RAMINIT	is zeroized
;
;	Memory above RAMINITEND to 0x4FFF is not initialized 
;
	ldi	xl, low(0x4000)
	ldi	xh, high(0x4000)
	ldi	yl, low(0x5000)
	ldi	yh, high(0x5000)
	movw	r25:r24, yh:yl
raminit100:
	ld	r16, X+
	st	Y+, r16
	cp	xl, r24
	cpc	xh, r25
	brlo	raminit100
	
	lds	r16, log_pointer+0
	lds	r17, log_pointer+1
	sts	0x5000, r16
	sts	0x5001, r17

	ldi	xl, low(RAMINITSTART)
	ldi	xh, high(RAMINITSTART)
	ldi	yl, low(RAMINITEND)
	ldi	yh, high(RAMINITEND)
raminit110:
	st	X+, zero
	cp	xl, yl
	cpc	xh, yh
	brlo	raminit110

#ifdef tesout
;--------------------------------------------------------------------------
;
;	Initialise Test Output
;
	ldi	xl, low(tesoutbuf)
	ldi	xh, high(tesoutbuf)
	sts	tesoutptr+0, xl
	sts	tesoutptr+1, xh
#endif
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
;	Initialize Logging
;
	ldi	yl, low(log_buffer)
	ldi	yh, high(log_buffer)
	sts	log_pointer+0, yl
	sts	log_pointer+1, yh
	ldi	r24, low(log_size)
	ldi	r25, high(log_size)
loginit010:
	st	Y+, zero
	sbiw	r25:r24, 1
	brne	loginit010
	ldi	r18, logging
	out	FLAGS_LOG, r18
	ldi	r18, (1<<ucb__log)
	sts	unittable+ucb_size*0+ucb_log+0, r18	;
	ldi	r18, (1<<ucb__log)
	sts	unittable+ucb_size*1+ucb_log+0, r18	;

;--------------------------------------------------------------------------
;
;	Initialize RAM values
;
	ldi	r18, 0xff
	sts	nguard, r18		; Null Job Stack Guard Byte
;=============================================================================
;
;	Port Settings
;
;	Normal GPIO Pins
;
	sbi	d_MSCP
	sbi	d_DMR			; DMA Request
	cbi	d_DMG			; DMA Granted
	sbi	d_ABO			; DMA Abort
	sbi	d_ACK			; Interrupt Acknowledge
	sbi	d_CLK			; CPU Clock Output
	
#ifdef mscpemulation
	ldi	r18, low(0154)
	ldi	r19, high(0154)
	sts	vector+0, r18
	sts	vector+1, r19
	sbi	b_MSCP
#endif
#ifdef rlv12emulation
	ldi	r18, low(0160)
	ldi	r19, high(0160)
	sts	vector+0, r18
	sts	vector+1, r19
	cbi	b_MSCP
#endif
	cbi	b_DMR			; No DMA request
	sbi	b_ABO
	cbi	b_ABO			; Abort any pending DMA
	sbi	b_ACK			; Acknowledge eventually pending interrupt
	cbi	b_ACK			; Unlock Q-Bus

#if cpldif==40
	sbi	d_RS0			; Register Select 0
	sbi	d_RS1			; Register Select 1
	sbi	d_RS2			; Register Select 2
#endif
#if cpldif==22
	sbi	d_ALER			; Read Register Address Latch
	cbi	b_ALER
	sbi	d_ALEW			; Write Register Address Latch
	cbi	b_ALEW
#endif
	sbi	d_LED			; Activity LED
	cbi	b_LED
	sbi	d_CRDY			; Controller Ready
	sbi	d_IRQ			; Q-Bus Interrupt Request
	sbi	d_RD			; Read Register in CPLD
	sbi	d_WR			; Write Register in CPLD
	
	sbi	b_CRDY
	cbi	b_IRQ
	cbi	b_RD			; Important default is cleared!!!
	cbi	b_WR
;
;	MVIO Port Settings - Port C is used for the SD-Card interface and the UART
;
;	ldi	r18, PORT_SRL_bm	; Low Slew Rate on port c
;	sts	PORTC_PORTCTRL, r18	; 
	
	sbi	b_SS			; Disable SD-Card
	sbi	d_TXD			; UART Transmit
	cbi	d_RXD			; UART Receive
	cbi	d_CD			; SD-Card Card Detect
	cbi	d_WP			; SD-Card Write Protect
	sbi	d_MOSI			; SD-Card
	sbi	b_MOSI			; SD-Card
	cbi	d_MISO			; SD-Card
	sbi	d_SCK			; SD-Card
	sbi	d_SS			; SD-Card
;
;	Activate Pull-Up for CD and WP of SD-Card slot
;
	ldi	r18, PORT_PULLUPEN_bm
	sts	c_CD, r18
	sts	c_WP, r18
;
;	Alternate PINs for SPI1
;
	ldi	r18, PORTMUX_SPI1_ALT1_gc; SPI1 on PC4..7
	sts	PORTMUX_SPIROUTEA, r18
;
;	The data port 
;
	ldi	r18, 0xFF
	out	dataportdir, r18	; default data port direction is output !!!
;=============================================================================
;
;	RTC / PIT
;
;	For tick we are using the PIT of the RTC and for iotick we use
;	the overflow interrupt of the RTC counter.
;
;	Using the RTC for the Tick and Iotick saves a timer. 
;
rtcwait:
	lds	r18, RTC_STATUS
	sbrc	r18, RTC_PERBUSY_bp	; Wait for PIT controller to be free
	rjmp	rtcwait
	ldi	r18, low(EXP2(15)-1)	; Overflow every second
	ldi	r19, high(EXP2(15)-1)
	sts	RTC_PERL, r18
	sts	RTC_PERH, r19
	ldi	r18, RTC_OVF_bm		; Enable RTC overflow interrupt
	sts	RTC_INTCTRL, r18
;
;	Periodic Interrupt every 32 RTC clocks, this gives 1024 ticks per
;	second
;
pitwait:
	lds	r18, RTC_PITSTATUS
	sbrc	r18, RTC_CTRLBUSY_bp	; Wait for PIT controller to be free
	rjmp	pitwait
	ldi	r18, RTC_PERIOD_CYC32_gc+RTC_PITEN_bm
	sts	RTC_PITCTRLA, r18
	ldi	r18, RTC_RTCEN_bm
	sts	RTC_CTRLA, R18
	ldi	r18, RTC_PI_bm		; Enable PIT interrupt
	sts	RTC_PITINTCTRL, r18
;=============================================================================
;
;	RT-OS Softinterrupt
;
	sbi	d_RTOS			; RT-OS Soft Interrupt
	sbi	b_RTOS			; Set Level = High 
	sbi	f_RTOS			; Acknowledge any pending interrupt
	ldi	r18, PORT_ISC_LEVEL_gc	; Level Sense Interrupt
	sts	c_RTOS, r18		; Pin Control
	
	ldi	r18, CPU_CCP_IOREG_gc	; Configuration Change Protection
	sts	CPU_CCP, r18
	ldi	r18, CLKCTRL_CLKOUT_bm	; Clock Out
	sts	CLKCTRL_MCLKCTRLA, r18
;
;	Q-Bus Level 1 to RT-OS Level 0 signalling to unblock the disk emulator
;	job. The Q-Bus Level 1 interrupt must not call any external routines   
;	and must especially not make any calls to the RT-OS, therefore it will
;	set a soft level 0 interrupt that will be executed after the Level 1  
;	Q-Bus Service Routine has finished and an eventually running Level 0  
;	service routine that has been interrupted by the Level 1 interrupt.   
;
#ifdef mscpemulation
	sbi	d_SA			; SA Write Soft Interrupt
	sbi	b_SA
	sbi	f_SA			; SA must be in the same port as IP
	ldi	r18, PORT_ISC_LEVEL_gc	; Level Sense Interrupt
	sts	c_SA, r18		; Pin Control

	sbi	d_IP			; IP Soft Interrupt
	sbi	b_IP			; Set Level = High 
	sbi	f_IP			; Acknowledge any pending interrupt
	ldi	r18, PORT_ISC_LEVEL_gc	; Level Sense Interrupt
	sts	c_IP, r18		; Pin Control
#endif
#ifdef rlv12emulation
	sbi	d_GO			; GO Soft Interrupt
	sbi	b_GO			; Set Level = High 
	sbi	f_GO			; Acknowledge any pending interrupt
	ldi	r18, PORT_ISC_LEVEL_gc	; Level Sense Interrupt
	sts	c_GO, r18		; Pin Control
#endif
;
;	Q-Bus Interrupts - Level 1 Interrupt
;
	cbi	d_INTI			; Q-Bus IACK Interrupt
	sbi	f_INTI			; Acknowledge any pending interrupt
	ldi	r18, PORT_ISC_LEVEL_gc	; Level Sense Interrupt
;	ldi	r18, PORT_ISC_FALLING_gc
	ori	r18, PORT_PULLUPEN_bm	; Pullup
	sts	c_INTI, r18		; Pin Control

	cbi	d_INTQ			; Q-Bus DATI/DATO Interrupt
	sbi	f_INTQ			; Acknowledge any pending interrupt
	ldi	r18, PORT_ISC_LEVEL_gc	; Level Sense Interrupt
;	ldi	r18, PORT_ISC_FALLING_gc
	ori	r18, PORT_PULLUPEN_bm	; Pullup
	sts	c_INTQ, r18		; Pin Control

	cbi	d_INIT			; Q-Bus BINIT Interrupt
	sbi	f_INIT			; Acknowledge any pending interrupt
	ldi	r18, PORT_ISC_BOTHEDGES_gc ; Level Sense Interrupt
	ori	r18, PORT_PULLUPEN_bm	; Pullup
	sts	c_INIT, r18		; Pin Control

	ldi	r18, v_QBUS/2		; Vector Number is Vector Address/2
	sts	CPUINT_LVL1VEC, r18

;=============================================================================
;
;	Map Flash section 2 to Data address space
;
	ldi	r18, CPU_CCP_IOREG_gc
	sts	CPU_CCP, r18
	ldi     r18, NVMCTRL_FLMAP_SECTION2_gc
	sts     NVMCTRL_CTRLB, r18

;=============================================================================
;
;	SPI 1
;
	ldi	r18, SPI_SSD_bm;  | SPI_BUFEN_bm
	sts	SPI1_CTRLB, r18
;
;	Various Clock rates: CPUCLK/2, CPUCLK/4, CPUCLK/8
;
;	ldi	r18, SPI_CLK2X_bm | SPI_ENABLE_bm | SPI_MASTER_bm | SPI_PRESC_DIV4_gc
;	ldi	r18,                SPI_ENABLE_bm | SPI_MASTER_bm | SPI_PRESC_DIV4_gc
;	ldi	r18, SPI_CLK2X_bm | SPI_ENABLE_bm | SPI_MASTER_bm | SPI_PRESC_DIV16_gc
	ldi	r18, spispeed
	sts	SPI1_CTRLA, r18		
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
;	Driver usage is controlled by FLAGS_COMMON
;
	cbi	FLAGS_COMMON, serin__drv	; Polled 
	cbi	FLAGS_COMMON, serout__drv

;=============================================================================
;
;	Timer 
;
;	TCA0 is run in split mode and provides the base time intervalls
;	for the other timers. It will producde two intervalls
;	1usec	this will be used by TCB1 to count the IO time
;	4usec	this will be used by TCB2 for the time stamp
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
;	TCB2 is used as the timestamp for the logging. As logging never  
;	takes place faster than the PDP-11 accesses the device register a           
;	granularity of approx 4 micro seconds is sufficient to notice an      
;	increase in the timestamp of consecutive reads or writes to device    
;	registers. On the other hand it should not be too short, so we can    
;	detect gaps as long as possible, as we only use the low-byte of TCB2  
;	in the timestamp of log messages, this will let us know if access to  
;	device registers are appart as much as 256*4 = 1024, wnich is more    
;	than 1ms, a very long time for a PDP-11.                              
;	
;	For this we operate Timer A in split mode and set the period of the   
;	lower counter to 1usec and the period of the upper counter to 4usec   
;	based on the F_CPU variable                                           
;
;	Although you cannot control Timer A in split mode via events Timer A  
;	still can create events independently for each half of the timer.     
;	                                                                      
;	The timer is clocked by the CPU frequency and hence the period of the 
;	lower half is set to 27 and the period of the upper half is set to    
;	111. Note that a period cannot exceed 255 as each half only has 8-bits
;	and that counters in split mode count downwards.
;
	ldi	r18, TCA_SPLIT_SPLITM_bm	; Set TCA0 into split mode as
	sts	TCA0_SINGLE_CTRLD, r18		; we need two 8-bit counters

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
;	counts the 4usec base ticks generated by the upper half of TCA0
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
;	Disable/Enable Boot ROM
;
	#if	cpldif==22
	ldi	r16, 7
	out	dataportout, r16
	sbi	b_ALEW
	cbi	b_ALEW
	ldi	r16, 1			; 0=disable, 1=enable
	out	dataportout, r16
	sts	romstatus, r16
	sbi	b_WR
	cbi	b_WR
	#endif
	
;=============================================================================
;
;	Print Hello Message
;
	lds	r0, reset_status
	sts	pprint+0, r0
	lds	r0, sd_status
	sts	pprint+1, r0
	call	print
	.db	CR, LF
	.db	"RSTCTRL_RSTFR  0x", 0x80
	.db	CR, LF
	.db	"SD-Card Status 0x", 0x81
	.db	CR, LF
	.db	"Starting Universal Disk Controller!", CR, LF, 0
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
	
	std	Z+jcb_stack+0, r24	; Pointer past stack area
	std	Z+jcb_stack+1, r25
	std	Z+jcb_joblist+0, xl
	std	Z+jcb_joblist+1, xh

	ldi	r18, main_id
	std	Z+jcb_jobid, r18
	ldi	r18, main_prio		; Priority
	std	Z+jcb_priority, r18
	clr	r18
	std	Z+jcb_flags, r18

	call	print
	.db	"Create Main Job", CR, LF, 0
	rcall	prtcreate

	ldi	r18, USART_RXCIE_bm	; Enable RX interrupt for RTOS
	sts	USART1_CTRLA, r18
	sbi	FLAGS_COMMON, serin__drv	; Activate Serial Driver
	sbi	FLAGS_COMMON, serout__drv
	movw	r25:r24, zh:zl
	sei
	call	create			; This call will never return
;=============================================================================
;
;	Crash
;
;crash:	rjmp	start
.include "crash.asm"
;=============================================================================
;
;	Serial In/Out Support routines
;
seroutcrlf:
	ldi	r24, CR
	rcall	serout
	ldi	r24, LF

serout:
	sbic	FLAGS_COMMON, serout__drv	; Is driver active
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
	sbic	FLAGS_COMMON, serin__drv	; Is driver active
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
;	mini RT-OS
;
.include	"rtos-v3-0.asm"
;=============================================================================
;
;	The Jobs
;
;-----------------------------------------------------------------------------
;
;	Main program in fact is the interactive command line interpreter
;
main:
	call	print
	.db	CR, LF, "Hallo RTOS on Universal Disk Emulator ", CR, LF, 0, 0
#ifdef mscpemulation
	call	mscp_reset
#endif
#ifdef rlv12emulation
	call	rlv12_reset
#endif
;
;	Card Detect Job
;
	ldi	zl, low(jcb1)
	ldi	zh, high(jcb1)
	ldi	xl, low(carddetect)	; start address requires word address
	ldi	xh, high(carddetect)
	ldi	r24, low(usersp1)	
	ldi	r25, high(usersp1)	
	std	Z+jcb_stack+0, r24	; Top of Stack
	std	Z+jcb_stack+1, r25
	std	Z+jcb_joblist+0, xl	; Job Entry Point
	std	Z+jcb_joblist+1, xh

	ldi	r18, carddetect_id
	std	Z+jcb_jobid, r18
	ldi	r18, carddetect_prio
	std	Z+jcb_priority, r18	; Job Priority
	clr	r18
	std	Z+jcb_flags, r18	; Job Flags

	call	print
	.db	"Create SD-Card Detect Job", CR, LF, 0
	rcall	prtcreate
	movw	r25:r24, zh:zl
	call	create
#ifdef rlv12emulation
;
;	RLV12 Emulator Job
;
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

	ldi	r18, rlv12job_id
	std	Z+jcb_jobid, r18
	ldi	r18, rlv12job_prio	; should be less than the priority of CLI
	std	Z+jcb_priority, r18	; rlv12 emulator job
	clr	r18
	std	Z+jcb_flags, r18

	call	print
	.db	"Create RLV12 Job", CR, LF, 0, 0
	rcall	prtcreate
	movw	r25:r24, zh:zl
	call	create
;
;	Seek Job
;
	ldi	zl, low(jcb3)
	ldi	zh, high(jcb3)
	ldi	xl, low(seekjob)	; start address requires word address
	ldi	xh, high(seekjob)
	ldi	r24, low(usersp3)	
	ldi	r25, high(usersp3)	
	std	Z+jcb_stack+0, r24
	std	Z+jcb_stack+1, r25
	std	Z+jcb_joblist+0, xl
	std	Z+jcb_joblist+1, xh

	ldi	r18, seek_id
	std	Z+jcb_jobid, r18
	ldi	r18, seek_prio		; Must be the lowest priority
	std	Z+jcb_priority, r18	; carddetect job
	clr	r18
	std	Z+jcb_flags, r18

	call	print
	.db	"Create Seek Job", CR, LF, 0
	rcall	prtcreate
	movw	r25:r24, zh:zl
	call	create
#endif
#ifdef mscpemulation
;
;	Poll
;
	ldi	zl, low(jcb2)
	ldi	zh, high(jcb2)
	ldi	xl, low(polljob)	; start address requires word address
	ldi	xh, high(polljob)
	ldi	r24, low(usersp2)	
	ldi	r25, high(usersp2)	
	std	Z+jcb_stack+0, r24
	std	Z+jcb_stack+1, r25
	std	Z+jcb_joblist+0, xl
	std	Z+jcb_joblist+1, xh

	ldi	r18, polljob_id
	std	Z+jcb_jobid, r18
	ldi	r18, polljob_prio	; should be less than the priority of CLI
	std	Z+jcb_priority, r18	; rlv12 emulator job
	clr	r18
	std	Z+jcb_flags, r18

	call	print
	.db	"Create Poll Job", CR, LF, 0
	rcall	prtcreate
	movw	r25:r24, zh:zl
	call	create
;
;	Init Job
;
	ldi	zl, low(jcb3)
	ldi	zh, high(jcb3)
	ldi	xl, low(initjob)	; start address requires word address
	ldi	xh, high(initjob)
	ldi	r24, low(usersp3)	
	ldi	r25, high(usersp3)	
	std	Z+jcb_stack+0, r24
	std	Z+jcb_stack+1, r25
	std	Z+jcb_joblist+0, xl
	std	Z+jcb_joblist+1, xh

	ldi	r18, scan_id
	std	Z+jcb_jobid, r18
	ldi	r18, scan_prio		; Must be the lowest priority
	std	Z+jcb_priority, r18	; carddetect job
	clr	r18
	std	Z+jcb_flags, r18

	call	print
	.db	"Create Init Job", CR, LF, 0
	rcall	prtcreate
	movw	r25:r24, zh:zl
	call	create
#endif

#define wdgactive 0
#if wdgactive>0
	ldi	r18, CPU_CCP_IOREG_gc
	sts	CPU_CCP, r18
	
#if wdgactive==1
;
;	WINDOW	if not zero sets the duration of the closed period
;	PERIOD	sets the duration of the open period, else
;
	ldi	r18, WDT_PERIOD_1KCLK_gc | WDT_WINDOW_512CLK_gc
#endif
#if wdgactive==2
;
;	PERIOD	sets the duration of the time-out between WDR instruction
;
	ldi	r18, WDT_PERIOD_1KCLK_gc
#endif
#if wdgactive==3
;
;	TICK	ultrashort 
;
	ldi	r18, WDT_PERIOD_8CLK_gc
#endif
	sts	WDT_CTRLA, r18
	lds	r18, WDT_CTRLA
	sts	pprint+15, r18
	call	print
	.db	CR, LF, "wdt - Starting watchdog ", 0x8f, CR, LF, 0
#endif



;--------------------------------------------------------------------------
;
;	Main Job - User Interface
;
readcmd:
	sts	InputBuffer, zero
	sbi	FLAGS_COMMON, sddetect__en		; Enable SD detect
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
;	Use legacy Calling Convention to TPARSE
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
	.db	0x09, "Job Control Block  0x"
	.db	0x81, 0x80, CR, LF
	.db	0x09, "Initial Stack      0x"
	.db	0x80+jcb_stack+1, 0x80+jcb_stack, CR, LF
	.db	0x09, "Programm Start     0x"
	.db	0x80+jcb_joblist+1, 0x80+jcb_joblist, CR, LF
	.db	0x09, "Priority/Flags     0x"
	.db	0x80+jcb_priority, "/0x", 0x80+jcb_flags, CR, LF, 00
	ret

;--------------------------------------------------------------------------
;
;	
;
.include	"seekjob.asm"		; Our seek job
;.include	"scanjob.asm"		; MSCP scan job
.include	"sdcardjob.asm"		; SD-Card Insert/Remove and LED routine
.include	"SD-Card-Print-v1-0.asm"; Print SD-Card messages
.include	"SD-Card-v1-0.asm"	; Main SD-Card routines
.include	"SD-Card-Multiple-v1-0.asm"
.include	"SD-Card-Turbo-v1-0.asm"
.include	"CRC-Tables.inc"
.include	"monitor-sub.asm"	; sub-routines used by Apple II monitor
.include	"mprint.asm"		; local formatted messages routine

;--------------------------------------------------------------------------
;
;		RLV12 and other modules
;
.include	"DMA-Macro.inc"		; CPLD DMA Macroes 
.include	"print-v2-1.asm"	; Print Inline
.include	"tparse-v2-0.asm"	; Table Drive Parser
.include	"Mountvolume.asm"	; Automount
.include	"Dismountvolume.asm"	; Autodismount
.include	"malloc-v3-0.asm"	; Malloc/Free
.include	"CLI-table.inc"		; Parser Table
.include	"CLI-action.asm"	; Parser Action Routines
.include	"CLI-attach.asm"	; Attach/Detach Command
.include	"CLI-sub.asm"		; Subroutines for CLI
.include	"CLI-directory.asm"	; dir/cd/pwd
.include	"CLI-partition.asm"	; Partition
.include	"CLI-show.asm"		; Various Show commands
.include	"CLI-dumpblock.asm"	; Dump Disk
.include	"CLI-fdisk.asm"		; fdisk
.include	"CLI-logging.asm"	; Logging
.include	"CLI-commands.asm"	; Various Other commands
.include	"CLI-sdcard.asm"	; Read Multiple Block Test
.include	"CLI-status.asm"	; Show status of variables

.include "FAT/BuildFragList.asm"
.include "FAT/Cluster2Sector.asm"
.include "FAT/CopyName.asm"
.include "FAT/CreatePath.asm"
.include "FAT/FreeList.asm"
.include "FAT/LinkedCluster.asm"
.include "FAT/Logical2Physical.asm"
.include "FAT/MatchFileName.asm"
.include "FAT/Name2DirEntry.asm"
.include "FAT/OpenDir.asm"
.include "FAT/ReadDir.asm"
.include "FAT/ReadFileByte.asm"
.include "FAT/ReadFileClose.asm"
.include "FAT/ReadFileOpen.asm"

.include	"readcmdline.asm"	; Read Command Line
.include	"readinit.asm"		; Read Init File
#ifdef rlv12emulation
.include	"rlv12-v2-0.asm"	; RLV12 Disk Emulation
.include	"qbus-v2-0.asm"		; RLV12 Q-Bus Interface
#endif
.include	"readonlydata.asm"	; Read Only Memory mapped to data space

;--------------------------------------------------------------------------
;
;	MSCP modules are just included just to verify the assembler syntax 
;	but not actually used for the moment
;
#ifdef mscpemulation
.include	"MSCP/qbus-v2-0.asm"	; RLV12 Q-Bus Interface
.include	"MSCP/clear.asm"
.include	"MSCP/poll-v2-0.asm"
.include	"MSCP/init.asm"
.include	"MSCP/doabo.asm"
.include	"MSCP/doavl.asm"
.include	"MSCP/subsm.asm"
.include	"MSCP/dogus.asm"
.include	"MSCP/dosuc.asm"
.include	"MSCP/dogcs.asm"
.include	"MSCP/doplf.asm"
.include	"MSCP/doscc.asm"	; work in progress
.include	"MSCP/doonl.asm"	; work in progress
.include	"MSCP/dorw.asm"
.include	"MSCP/douna.asm"
.include	"MSCP/mscp.asm"
.include	"MSCP/dup.asm"
#endif
