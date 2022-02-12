;==========================================================================
;
;	General Project definitions
;
;
;--------------------------------------------------------------------------
;
;	CPU Clock - We are using the built-on high frequency oscillator
;
.equ CLKCTRL_FREQSEL_28M_gc = (0x0a<<2)  ; 28 MHz system clock	-> ok
.equ CLKCTRL_FREQSEL_32M_gc = (0x0b<<2)  ; 32 MHz system clock	-> ok

.equ	F_CLK	=	CLKCTRL_FREQSEL_32M_gc
.equ	F_CPU	=	32000000
;
;	Baud Rate Generator with fractional baud-rate generator
;
.equ	BAUD1	= (64 * F_CPU) / (16 * 115200)

;--------------------------------------------------------------------------
;
;	Q-Bridge CPLD Version
;
#define cpldif 40
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
;	For a simple subroutine with a 8 or 16 parameter and a 8 or 16 bit return value
;	the register pair r25:r24 is used
;
.def	zero	=	r1		; See 
;
;	Each time we start an SD-Card IO we set the activity LED and set the
;	led_time, then in the sd-card detect job we will switch the LED off
;	again after soem time
;
.equ	led_time	= 10		; LED oneshot
;
;	For DMA we need to implement a bus timeout, this is just a loop counter
;	and must be set approriately. 
;
.equ	dmatmo		= 100		; DMA Timeout


;--------------------------------------------------------------------------
;
;	GPR_GPR0 definitions for signalling
;
.equ	serin__drv	= 0
.equ	serout__drv	= 1
.equ	sdcard__insert	= 2
.equ	sdcard__remove	= 3
.equ	soft__crdy	= 4		; 
.equ	auto__boot	= 6
.equ	sddetect__en	= 7
;--------------------------------------------------------------------------
;
;	Logging
;
;	For debugging purposes a logging buffer is implemented. Each
;	log entry occupies 4-bytes. 
;
#define	log_iack	0x10
#define	log_init	0x20
#define	log_dato	0x30
#define	log_dati	0x40
#define	log_csr		0x00
#define	log_bar		0x02
#define	log_dar		0x04
#define	log_mpr		0x06
#define	log_bae		0x08
#define	log_boot2	0x0a
#define log_boot4	0x0c
#define log_boot6	0x0e
#define log_rom		0x01
#define	log_fnc0	0x80
#define	log_address	0x90
#define	log_fnc2	0xa0
#define	log_seek	0xb0
#define	log_pbn		0xc0
#define	log_diskaddr	0xd0
#define log_trace	0xe0	; general trace
#define log_traceh	0xe1	; hex word
#define log_traceo	0xe2	; octal word
#define log_tracebh	0xe3	; hex bytes
#define log_tracebo	0xe4	; octal bytes
;
;	Logging Buffer Definitions
;
;	There are two options, a circular logging buffer or a so called lollipop
;	shaped logging buffer. With a circular buffer only the last entries are
;	kept and new entries may overwrite old entries. With a lollipop shaped
;	buffer the first half is written only once and the second half is then
;	used as a circular buffer. The buffer needs to be 2^N bytes where N
;	can be selected from 8 to 12. 
;
;	For lollipop buffer, each time the logpointer is incremented by 4 the
;	overflow bit is checked in the high byte of the address, if it set
;	then the upper bit in the high byte is set before the buffer address
;	is set to the beginning. With the upper bit set it will then not at
;	the beginning but in the middle. The overflow bit must be selected
;	according to the buffer address. In case of 0x7000 the overflow bit
;	is simple the MSB of the 16-bit address. However in case of 0x6000
;	the overflow bit would be bit 5.
;
;
#define	log_type	circular
;#define	log_type	lollipop
.equ	log_buffer	= 0x7000
.equ	log_overflow	= 7		; the 7th bit of the high byte address
.equ	log_upper	= 3		; sticky address bit for lollipop buffer
.equ	log_size	= 0x0fff	; 4096 bytes of logging
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

.if ((log_buffer & log_size)> 0)
	.error " Invalid logging buffer definitions"
.endif