;-----------------------------------------------------------------------------
;
;	PORT A	(Bits0..7)
;
.equ	DMR	= 1			; DMA Request	
.equ	DMG	= 2			; DMA Granted	
.equ	ABO	= 3			; Abort Cycle	
.equ	ACK	= 4			; Acknowledge Cycle
.equ	RTOS	= 6			; RTOS Software Interrupt	
.equ	CLK	= 7			; CPDL Clock output

#define b_DMR	VPORTA_OUT, DMR
#define i_DMG	VPORTA_IN, DMG
#define b_ABO	VPORTA_OUT, ABO
#define b_ACK	VPORTA_OUT, ACK

#define b_RTOS	VPORTA_OUT, RTOS
#define	f_RTOS	VPORTA_INTFLAGS, RTOS
#define	c_RTOS	PORTA_PIN6CTRL

#define b_CLK	VPORTA_OUT, CLK

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


;-----------------------------------------------------------------------------
;
;	PORT F (Bits0..5, Bit6 is Reset and may be used as input but not here)
;
.equ	MEM	= 0			; Malloc Interrupt
.equ	SIG	= 1			; Signal
.equ	CRDY	= 2			; Controller Ready
.equ	IRQ	= 3			; Interrupt Request
.equ	RD	= 4			; Register Read
.equ	WR	= 5			; Register Write

#define	b_MEM	VPORTF_OUT, MEM
#define	b_SIG	VPORTF_OUT, SIG
#define	b_CRDY	VPORTF_OUT, CRDY
#define	b_IRQ	VPORTF_OUT, IRQ
#define	b_RD	VPORTF_OUT, RD
#define	b_WR	VPORTF_OUT, WR

#define b_MEM	VPORTF_OUT, MEM
#define	f_MEM	VPORTF_INTFLAGS, MEM
#define	c_MEM	PORTF_PIN0CTRL
