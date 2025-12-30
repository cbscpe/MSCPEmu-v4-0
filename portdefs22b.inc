;=============================================================================
;
;	Q-Bus RLV12 Emulator Version 2.0 Adapter B
;

#define cpldif 22

;-----------------------------------------------------------------------------
;
;	PORT A	(Bits0..7)
;
.equ	RTOS	= 0			; RT-OS 
.equ	RD	= 1			; Read
.equ	DMG	= 2			; DMA Granted
.equ	ALER	= 3			; Read Register Address Latch Enable
.equ	ABO	= 4			; Abort DMA
.equ	LED	= 5			; LED on
.equ	ACK	= 6			; Acknowledge
.equ	CLK	= 7			; CLKOUT

#define d_RTOS	VPORTA_DIR, RTOS
#define b_RTOS	VPORTA_OUT, RTOS
#define	f_RTOS	VPORTA_INTFLAGS, RTOS
#define	c_RTOS	PORTA_PIN0CTRL
#define v_RTOS	PORTA_PORT_vect

#define d_RD	VPORTA_DIR, RD
#define b_RD	VPORTA_OUT, RD

#define d_DMG	VPORTA_DIR, DMG
#define i_DMG	VPORTA_IN, DMG

#define d_ALER	VPORTA_DIR, ALER
#define b_ALER	VPORTA_OUT, ALER

#define d_ABO	VPORTA_DIR, ABO
#define b_ABO	VPORTA_OUT, ABO

#define d_LED	VPORTA_DIR, LED
#define b_LED	VPORTA_OUT, LED

#define d_ACK	VPORTA_DIR, ACK
#define b_ACK	VPORTA_OUT, ACK

#define d_CLK	VPORTA_DIR, CLK
#define b_CLK	VPORTA_OUT, CLK

;-----------------------------------------------------------------------------
;
;	PORT B (Bits0..5)
;
;	PB0	unused
;	PB1	unused
.equ	IRQ	= 2			; Interrupt Request
;	PB3	unused
;	PB4	unused
.equ	GO	= 5			; Level1->Level0 signal

#define	d_IRQ	VPORTB_DIR, IRQ
#define	b_IRQ	VPORTB_OUT, IRQ

#define	d_GO	VPORTB_DIR, GO	
#define	b_GO	VPORTB_OUT, GO	
#define	f_GO	VPORTB_INTFLAGS, GO
#define	c_GO	PORTB_PIN5CTRL
#define	v_GO	PORTB_PORT_vect

#define d_T3	VPORTB_DIR, 3
#define b_T3	VPORTB_OUT, 3
#define d_T4	VPORTB_DIR, 4
#define b_T4	VPORTB_OUT, 4

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

#define d_TXD	VPORTC_DIR, TXD
#define d_RXD	VPORTC_DIR, RXD
#define d_CD	VPORTC_DIR, CD
#define d_WP	VPORTC_DIR, WP
#define d_MOSI	VPORTC_DIR, MOSI
#define d_MISO	VPORTC_DIR, MISO
#define b_MOSI	VPORTC_OUT, MOSI
#define d_SCK	VPORTC_DIR, SCK
#define d_SS	VPORTC_DIR, SS

#define	i_CD	VPORTC_IN, CD
#define	i_WP	VPORTC_IN, WP
#define	b_SS	VPORTC_OUT, SS

#define	c_CD	PORTC_PIN2CTRL
#define c_WP	PORTC_PIN3CTRL

;-----------------------------------------------------------------------------
;
;	PORT D (Bits0..7)
;
;	Data Port used as debug port, initialised as output
;
#define	dataportout	VPORTD_OUT
#define dataportin	VPORTD_IN
#define dataportdir	VPORTD_DIR

;-----------------------------------------------------------------------------
;
;	PORT E (Bits0..3)
;
;	PE0	unused
.equ	CRDY	= 1			; Controller Ready
.equ	ALEW	= 2			; Write Register Address Latch Enable
.equ	WR	= 3			; Write

#define	d_CRDY	VPORTE_DIR, CRDY
#define	b_CRDY	VPORTE_OUT, CRDY

#define	d_ALEW	VPORTE_DIR, ALEW
#define	b_ALEW	VPORTE_OUT, ALEW

#define	d_WR	VPORTE_DIR, WR
#define	b_WR	VPORTE_OUT, WR

;-----------------------------------------------------------------------------
;
;	PORT F (Bits0..5, Bit6 is Reset and may be used as input but not here)
;
;	PF0	unused
.equ	DMR	= 1			; DMA Request
	PF2	unused
.equ	INTQ	= 3			; IACK
.equ	INTI	= 4			; DATI/DATO
.equ	INIT	= 5			; INIT

#define	d_DMR	VPORTF_DIR, DMR
#define	b_DMR	VPORTF_OUT, DMR

#define	d_INTI	VPORTF_DIR, INTI
#define	i_INTI	VPORTF_IN, INTI
#define	f_INTI	VPORTF_INTFLAGS, INTI
#define	c_INTI	PORTF_PIN3CTRL

#define	d_INTQ	VPORTF_DIR, INTQ
#define	i_INTQ	VPORTF_IN, INTQ
#define	f_INTQ	VPORTF_INTFLAGS, INTQ
#define	c_INTQ	PORTF_PIN4CTRL

#define	d_INIT	VPORTF_DIR, INIT
#define	i_INIT	VPORTF_IN, INIT
#define	f_INIT	VPORTF_INTFLAGS, INIT
#define	c_INIT	PORTF_PIN5CTRL

#define v_QBUS	PORTF_PORT_vect

#define int_port VPORTF_IN
#define int_flags VPORTF_INTFLAGS
