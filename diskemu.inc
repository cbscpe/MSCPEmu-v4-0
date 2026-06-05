;==========================================================================
;
;	General Project definitions
;
;--------------------------------------------------------------------------
;
;	CPU Clock - We are using the built-on high frequency oscillator
;
.equ CLKCTRL_FREQSEL_28M_gc = (0x0a<<2)  ; 28 MHz system clock	-> ok
.equ CLKCTRL_FREQSEL_32M_gc = (0x0b<<2)  ; 32 MHz system clock	-> ok
;
;	Note: Using the AVR128DB48 with Adapter-B on the Q-Bus Version
;	shows some issues when running with 32MHz, it's not clear why
;	perhaps also a programming error but with 28MHz it is much more
;	reliable. For the moment we will leave it at 24MHz which is
;	still fast enough.
;
.equ	F_CLK	=	CLKCTRL_FREQSEL_20M_gc
.equ	F_CPU	=	20000000
;
;	Baud Rate Generator with fractional baud-rate generator
;
.equ	BAUD1	= (64 * F_CPU) / (16 * 115200)
;
;	When activating the outputs of the CPLD it takes some cycles 
;	before the result can be read from the input port. The AVR MCU
;	require at least 3 cycles before the input has been latched and
;	for high clock rates, the propagation delay must be considered
;	as well. The following macro defines the number of cycles to
;	wait for input, normally for CPU clocks of 20MHz and less three
;	cycles are sufficient. For 24 and 28MHz 4 cycles are required
;	and for 32MHz we still need to find the reason why it is not
;	reliable.
;
	.macro	waitin
	rjmp	PC+1		; 2 This is a single word instruction 2 cycle nop
	rjmp	PC+1		; 2
;	nop			; 1
	.endmacro

;--------------------------------------------------------------------------
;
;
;
.equ	units	=	4


;--------------------------------------------------------------------------
;
;	Q-Bridge CPLD Version
;
#ifdef qbus50
.include	"portdefs40qbus.inc"	; CPLD Interface 4.0 QBUS 
#else
.include	"portdefs40.inc"	; CPLD Interface 4.0 PDP-11/Hack
#endif
;.include	"portdefs22b.inc"	; CPLD Interface 2.2 RLV12 Emu 2.0 Adapter B
;.include	"portdefs22c.inc"	; CPLD Interface 2.2 RLV12 Emu 2.0 Adapter C
;
;--------------------------------------------------------------------------
;	
;	SPI SD-Card Speed and other settings
;
;	Various Clock rates: CPUCLK/2, CPUCLK/4, CPUCLK/8
;
;#define spispeed SPI_CLK2X_bm | SPI_ENABLE_bm | SPI_MASTER_bm | SPI_PRESC_DIV4_gc
#define spispeed                SPI_ENABLE_bm | SPI_MASTER_bm | SPI_PRESC_DIV4_gc
;#define spispeed SPI_CLK2X_bm | SPI_ENABLE_bm | SPI_MASTER_bm | SPI_PRESC_DIV16_gc
;
;	Conditional assembly
;
#define includemscp 1
;#define mscpemulation 1
;#define rlv12emulation 1
;
;--------------------------------------------------------------------------
;
;	SD-Card status byte bit definitions
;
.equ	sd__v1		= 0	; If card is a version 2 card
.equ	sd__v2		= 1	; If card is a version 2 card
.equ	sd__init	= 2	; Card could be initialised
.equ	sd__ccs		= 3	; Card Capacity Support
.equ	sd__reset	= 7	; Card could be reset successfully
;--------------------------------------------------------------------------
;
;	Special characters
;
.equ	NULL	= 0
.equ    CR      = 015
.equ    LF      = 012
.equ    BELL    = 07
.equ    BKSP    = 010
.equ    TAB     = 011
.equ    EOF     = 032
.equ    ESC     = 033
.equ	SPACE	= 040
.equ    DEL     = 0177
.equ	DELIM	= 0x2f			; Directory Delimiter 0x2f = / and 0x5c = \

;
; ABI excerpt, for more information see ABI Register Convention Text File
;
;	R1 is always zero
;	R18-R27, R30, R31 are used by subroutines (inlcudes X and Z register)
;	R2-R15, R28, R29 are saved by subroutines (inlcudes Y register)
;
;	For a simple subroutine with a 8 or 16 bit parameter and a 8 or 16 bit 
;	return value the register pair r25:r24 is used
;
.def	zero	=	r1		; See 
;
;	Each time we start an SD-Card IO we set the activity LED and set the
;	led_time, then in the sd-card detect job we will switch the LED off
;	again after some time
;
.equ	led_time	= 10		; LED oneshot
;
;	For DMA we need to implement a bus timeout, this is just a loop counter
;	and must be set approriately. The loop is 4 cycles long and the timeout
;	must be 10usec or higher. Therefore dmatmo must be at least 70 for 28MHz
;	and 80 for 32MHz.
;
.equ	dmatmo		= 150		; DMA Timeout
;
;	Timestamp uses TCB2
;
#define	timestamp	TCB2_CNTL
;
;--------------------------------------------------------------------------
;
;	Flag Registers - GPR_GPR0..3
;
#define FLAGS_COMMON GPR_GPR2
#define FLAGS_LOG GPR_GPR3
;--------------------------------------------------------------------------
;
;	FLAGS_COMMON definitions for signalling states of the emulator
;
.equ	serin__drv	= 0		; Interrupt Driven Serial Input 
.equ	serout__drv	= 1		; Interrupt Driven Serial Output
.equ	sdcard__insert	= 2		; SD Card was inserted
.equ	sdcard__remove	= 3		; SD Card was removed
;			  4		; reserved
;			  5		; reserved
.equ	auto__boot	= 6		; Autoboot Requested
.equ	sddetect__en	= 7		; SD-Card Detect Enabled
;--------------------------------------------------------------------------
;
;	RAM Usage
;
;	0x4000..0x4FFF	Variables, Stack
;	0x5000..0x5FFF	Monitor, Test
;	0x6000..0x6FFF	Heap, Dynamic Memory
;	0x7000..0x7FFF	Logging Buffer
;
;--------------------------------------------------------------------------
;
;	Dynamically allocatable memory
;
.equ	heapstart	= 0x6000
.equ	heapsize	= 0x1000
;--------------------------------------------------------------------------
;
;	Job Definitions
;
#define rlv12job_id 0
#define rlv12job_prio 2

#define polljob_id 0
#define polljob_prio 2

#define main_id 1
#define main_prio 4

#define carddetect_id 2
#define carddetect_prio 9

#define seek_id 3
#define seek_prio 1

#define init_id 3
#define init_prio 1
;--------------------------------------------------------------------------
;
;	Logging - Buffers, Definitions, Macro's
;
;	For debugging purposes a logging buffer is implemented. Each
;	log entry occupies 4-bytes. 
;
;
;	0x1x - Interrupts
;
#define	log_iack	0x10
#define	log_init	0x11
;
;	0x2x - ROM
;
#define log_romwr	0x20
#define log_romrd	0x21
;
;	0x3x - DATO
;
#define	log_dato	0x30
;
;	0x4x - DATI
;
#define	log_dati	0x40
;
;	DATI/DATO modifiers RLV12 Emulation
;
#define	log_csr		0x00
#define	log_bar		0x02
#define	log_dar		0x04
#define	log_mpr		0x06
#define	log_bae		0x08
#define	log_boot2	0x0a
#define log_boot4	0x0c
#define log_boot6	0x0e
;
;	DATI/DATO modifiers MSCP Emulation
;
#define	log_ip		0x00
#define	log_ips1	0x01
#define	log_ips2	0x02
#define	log_ips3	0x03
#define	log_ips4	0x04
#define	log_ipwr	0x05
#define	log_ipgo	0x06
#define	log_iper	0x07
#define	log_sa		0x08
#define	log_sas1	0x09
#define	log_sas2	0x0A
#define	log_sas3	0x0B
#define	log_sas4	0x0C
#define	log_sawr	0x0D
#define	log_sago	0x0E
#define	log_saer	0x0F
;
;	0x5x - reserved
;

;
;	0x6x - reserved
;

;
;	0x7x - reserved
;

;
;	0x8x, 0x9x - RLV12 commands
;		Bits0..1 = Unit
;		Bits2..4 = Function Code
;
#define	log_command	0x80
;
;	0xax -reserved
;

;
;	0xbx -reserved
;

;
;	0xcx - 27-bit Disk Address i.e. up to 64GB
;
#define log_pbn		0xc0
#define	log_lbn		0xc8
;
;	0xdx -reserved
;

;
;	0xex - General Purpose Trace
;
#define log_trace	0xe0	; general trace
#define log_traceh	0xe1	; hex word
#define log_traceo	0xe2	; octal word
#define log_tracebh	0xe3	; hex bytes
#define log_tracebo	0xe4	; octal bytes
;
;	0xfx -reserved
;

;
;	Logging Buffer Definitions
;
;	The logging buffer starts with an optional non-circular part where we 
;	will store the first log entries. Then follows a circular buffer which
;	stores the last few entries. The size of the non-circular buffer is   
;	defined by log_begin. The total logging buffer is defined by          
;	log_buffersize. Both, log_begin and log_buffersize must be a multiple 
;	of 256. The logging buffer must end at a boundary which is a power of   
;	two so that an overflow of the log_pointer can be detected by a bit   
;	set in the log_pointer. E.g. if the buffer goes up to 0x7FF4 (each    
;	entry starts at a 4-byte boundary) and we add 4 to get the next       
;	log_pointer we just need to check bit 15 of the pointer, which is bit 
;	7 of the high byte. If this bit is set we know that we have reached   
;	the end of the circular buffer and need to reset the log_pointer to   
;	the start of the circular buffer. This is simply done by subtracting  
;	the high-byte of the circular buffer size, log_size, from log_pointer.           
;
.equ	log_buffer	= 0x7000
.equ	log_buffersize	= 0x1000
.equ	log_begin	= 0x0c00
.equ	log_size	= log_buffersize - log_begin
.equ	log_overflow	= 7		; the 7th bit of the high byte address
;
;	FLAGS_LOG definitions for logging
;
;			  0		; reserved
;			  1		; reserved
;			  2		; reserved
;			  3		; reserved
.equ	log__trace	= 4		; Log Debug Traces
.equ	log__iack	= 5		; Log Interrupt Ack and bus INIT
.equ	log__pbn	= 6		; Log physical block number
.equ	log__reg	= 7		; Log Device Register IO
;
;#define logging (1<<log__pbn) | (0<<log__trace) | (1<<log__reg) | (1<<log__iack)
;#define logging (0<<log__pbn) | (0<<log__trace) | (0<<log__reg) | (1<<log__iack)
;#define logging (1<<log__pbn) | (1<<log__trace) | (1<<log__reg) | (1<<log__iack)
#define logging (0<<log__pbn) | (1<<log__trace) | (1<<log__reg) | (1<<log__iack)
.if (log_begin & 0xFF >0)
	.error " Invalid non-circular buffer size"
.endif
.if (log_buffersize & 0xFF >0)
	.error " Invalid total logging buffer size"
.endif
.if ((log_buffer & (log_buffersize - 1)) != 0)
	.error " Invalid logging buffer definitions"
.endif
;--------------------------------------------------------------------------
;
;	Get the current log pointer and update the log pointer with the next entry
;	in the circular or lollipop shaped logging buffer this macro expects the  
;	registers that receives the current pointer and two scratchpad registers  
;	as parameters, the scratchpad registers will be set to the pointer as
;	well and log_pointer will point to the next entry                                                           
;
	.macro	logptr			; logptr ptrl, ptrh, scratchl, scratchh
	cli
	lds	@2, log_pointer+0
	lds	@3, log_pointer+1
	movw	@1:@0, @3:@2
	adiw	@1:@0, 4
	sbrc	@1, log_overflow
	subi	@1, high(log_size)
	sts	log_pointer+0, @0
	sts	log_pointer+1, @1
	sei
	movw	@1:@0, @3:@2
	.endmacro

;
;	Trace function which creates a log entry with an ID and a 16-bit      
;	value, typically used to display the current value of register or a   
; 	register pair mostly used during debugging                            
;
	.macro	logtr; trace-id, regtracevaluelow, regtracevaluehigh
	sbis	FLAGS_LOG, log__trace
	rjmp	notrace
	push	zl			; Save Z first
	push	zh
	push	r17			; Save temporary registers
	push	r16
	ldi	r16, log_trace
	ldi	r17, @0
	cli				;;;
	lds	zl, log_pointer+0	;;;  3 Logging
	lds	zh, log_pointer+1	;;;  3 Logging
	st	Z+, r16			;;;  2
	st	Z+, r17			;;;  2
	pop	r16			;;;  1 Restore r16/r17 here in case that
	pop	r17			;;;  1 they are used as the trace values
	st	Z+, @1			;;;  2
	st	Z+, @2			;;;  2
	sbrc	zh, log_overflow	;;;  2/1
	ldi	zh, high(log_buffer+log_begin)
	sts	log_pointer+0, zl	;;;  2
	sts	log_pointer+1, zh	;;;  2
	sei				;;;  1	-> 23 cycles ~1usec
	pop	zh			; Restore Z registers
	pop	zl
notrace:
	.endmacro

	.macro	logpbn; 4 registers with byte1, byte2, byte3 and byte4 of PBN
	sbis    FLAGS_LOG, log__pbn
	rjmp	notrace
	push	zl
	push	zh
	push	r16			;;; need a register
	mov	r16, @3			;;; even if @3 is r16 this does not matter
	andi	r16, 0x07		;;; isolate bits 25..27 of pbn
	ori	r16, log_pbn		;;; logging code
	cli
	lds	zl, log_pointer+0	;;; retrieve logging pointer
	lds	zh, log_pointer+1
	st	Z+, r16			;;; save code with pbn bits 25..27
	pop	r16			;;;
	st	Z+, @0			;;; save bits 0..23
	st	Z+, @1
	st	Z+, @2
	sbrc	zh, log_overflow
	ldi	zh, high(log_buffer+log_begin)
	sts	log_pointer+0, zl
	sts	log_pointer+0, zh
	sei
	pop	zh
	pop	zl
notrace:
	.endmacro
	
	.macro	loglbn; 4 registers with byte1, byte2, byte3 and byte4 of LBN
	sbis    FLAGS_LOG, log__pbn
	rjmp	notrace
	push	zl
	push	zh
	push	r16			;;; need a register
	mov	r16, @3
	andi	r16, 0x07		;;; isolate bits 25..27 of lbn
	ori	r16, log_lbn		;;; logging code
	cli
	lds	zl, log_pointer+0	;;; retrieve logging pointer
	lds	zh, log_pointer+1
	st	Z+, r16			;;; save code with lbn bits 25..27
	pop	r16			;;;
	st	Z+, @0			;;; save bits 0..23
	st	Z+, @1
	st	Z+, @2
	sbrc	zh, log_overflow
	ldi	zh, high(log_buffer+log_begin)
	sts	log_pointer+0, zl
	sts	log_pointer+0, zh
	sei
	pop	zh
	pop	zl
notrace:
	.endmacro

;=============================================================================
;
;	RT-OS Flag Definitions
;
.equ	tesout_bp	= 0
.equ	tesoutblock_bp	= 1
.equ	tesoutout_bp	= 2
