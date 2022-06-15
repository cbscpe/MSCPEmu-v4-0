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
;	reliable. For the moment we will leave it at 28MHz which is
;	still fast enough.
;
.equ	F_CLK	=	CLKCTRL_FREQSEL_32M_gc
.equ	F_CPU	=	32000000
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
;	Q-Bridge CPLD Version
;
#define cpldif 40
;#define cpldif 22
;
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
#define spibuffered 0
;--------------------------------------------------------------------------
;
;	SD-Card status byte bit definitions
;
.equ		sd__v1		= 0	; If card is a version 2 card
.equ		sd__v2		= 1	; If card is a version 2 card
.equ		sd__init	= 2	; Card could be initialised
.equ		sd__ccs		= 3	; Card Capacity Support
.equ		sd__reset	= 7	; Card could be reset successfully
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
.equ	dmatmo		= 100		; DMA Timeout
;
;	Timestamp uses TCB2
;
#define	timestamp	TCB2_CNTL
;
;--------------------------------------------------------------------------
;
;	GPR_GPR0 definitions for signalling states of the emulator
;
.equ	serin__drv	= 0		; Interrupt Driven Serial Input 
.equ	serout__drv	= 1		; Interrupt Driven Serial Output
.equ	sdcard__insert	= 2		; SD Card was inserted
.equ	sdcard__remove	= 3		; SD Card was removed
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
;	Logging - Buffers, Definitions, Macro's
;
;	For debugging purposes a logging buffer is implemented. Each
;	log entry occupies 4-bytes. 
;
#define	log_iack	0x10
#define	log_init	0x11
#define	log_dato	0x30
#define	log_dati	0x40
;
;	DATI/DATO modifiers
;
#define	log_csr		0x00
#define	log_bar		0x02
#define	log_dar		0x04
#define	log_mpr		0x06
#define	log_bae		0x08
#define	log_boot2	0x0a
#define log_boot4	0x0c
#define log_boot6	0x0e
#define log_rom		0x01
;
#define	log_fnc0	0x80
#define	log_address	0x90
#define	log_fnc2	0xa0
#define	log_seek	0xb0
#define	log_pbn		0xc0
#define	log_diskaddr	0xd0
;
; General Purpose Trace
;
#define log_trace	0xe0	; general trace
#define log_traceh	0xe1	; hex word
#define log_traceo	0xe2	; octal word
#define log_tracebh	0xe3	; hex bytes
#define log_tracebo	0xe4	; octal bytes
;
#define	log_mscp	0x50
#define	log_bcnt	0x51
#define	log_buff	0x52
#define	log_lbn		0x53
#define log_pkt		0x54
#define	log_ring	0x55
#define	log_dup		0x60
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
.equ	log_begin	= 0x0000
.equ	log_size	= log_buffersize - log_begin
.equ	log_overflow	= 7		; the 7th bit of the high byte address
;
;	GPR_GPR1 definitions for logging
;
.equ	log__rl0	= 0		; Log IO to unit 0
.equ	log__rl1	= 1
.equ	log__rl2	= 2
.equ	log__rl3	= 3
.equ	log__units	= 0x0f		; All Units
.equ	log__trace	= 4		; Log Debug Traces
.equ	log__iack	= 5		; Log Interrupt Ack and bus INIT
.equ	log__pbn	= 6		; Log physical block number
.equ	log__reg	= 7		; Log Device Register IO
;
;#define logging (1<<log__pbn) | (0<<log__trace) | (1<<log__reg) | (1<<log__iack) | log__units
;#define logging (0<<log__pbn) | (0<<log__trace) | (0<<log__reg) | (1<<log__iack) | log__units
#define logging (1<<log__pbn) | (1<<log__trace) | (1<<log__reg) | (1<<log__iack) | log__units

.if (log_begin & 0xFF >0)
	.error " Invalid non-circular buffer size"
.endif
.if (log_buffersize & 0xFF >0)
	.error " Invalid total logging buffer size"
.endif
.if ((log_buffer & (log_buffersize - 1)) != 0)
	.error " Invalid logging buffer definitions"
.endif
;
;	Get the current log pointer to the Z register and update
;	the log pointer with the next entry in the circular or
;	lollipop shaped logging buffer
;
	.macro	logptr			; Destroys r25:r24, zh:zl
	cli				;;;
	lds	zl, log_pointer+0	;;;  3 Logging
	lds	zh, log_pointer+1	;;;  3 Logging
	movw	r25:r24, zh:zl		;;;  1
	adiw	r25:r24, 4		;;;  2
	sbrc	r25, log_overflow	;;;  2/1
	subi	r25, high(log_size)     ;;;  0/1
	sts	log_pointer+0, r24	;;;  2
	sts	log_pointer+1, r25	;;;  2
	sei				;;;  1	-> 16 cycles ~0.6usec
	.endmacro
;
;	Trace function which creates a log entry with an ID and a 16-bit      
;	value, typically used to display the current value of register or a   
; 	register pair mostly used during debugging                            
;
	.macro	logtr; trace-id, reg tracevaluelow, regtracevaluehigh
	sbis	GPR_GPR1, log__trace
	rjmp	notrace
	push	r16			; Save registers
	push	r17
	push	zl
	push	zh
	LDI	R16, log_trace
	ldi	r17, @0
	cli				;;;
	lds	zl, log_pointer+0	;;;  3 Logging
	lds	zh, log_pointer+1	;;;  3 Logging
	st	Z+, r16			;;;  2
	st	Z+, r17			;;;  2
	st	Z+, @1			;;;  2
	st	Z+, @2			;;;  2
	sbrc	zh, log_overflow	;;;  2/1
	subi	zh, high(log_size)	;;;  0/1
	sts	log_pointer+0, zl	;;;  2
	sts	log_pointer+1, zh	;;;  2
	sei				;;;  1	-> 21 cycles ~0.75usec
	pop	zh			; Restore registers
	pop	zl
	pop	r17
	pop	r16
notrace:
	.endmacro


