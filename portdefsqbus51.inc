;=============================================================================
;
;	PDP-11/Hack
;
;	Disk Emulator Version 5-1
;
#define cpldif 40
#define qbus 51

;-----------------------------------------------------------------------------
;
;	PORT A	(Bits0..7)
;
.equ	ACK	= 0			; Acknowledge Cycle
.equ	CRDY	= 1			; Controller Ready
.equ	IRQ	= 2			; Interrupt Request
.equ	LED	= 3			; Activity LED PIN32 Yellow Kinar Wire
.equ	RTOS	= 4			; RTOS Software Interrupt	
.equ	ABO	= 5			; Abort Cycle	
.equ	DMR	= 6			; DMA Request	
.equ	CLK	= 7			; CPDL Clock output

#define d_ACK	VPORTA_DIR, ACK
#define	d_CRDY	VPORTA_DIR, CRDY
#define	d_IRQ	VPORTA_DIR, IRQ
#define	d_LED	VPORTA_DIR, LED
#define d_RTOS	VPORTA_DIR, RTOS
#define d_ABO	VPORTA_DIR, ABO
#define d_DMR	VPORTA_DIR, DMR
#define d_CLK	VPORTA_DIR, CLK

#define b_ACK	VPORTA_OUT, ACK
#define	b_CRDY	VPORTA_OUT, CRDY
#define	b_IRQ	VPORTA_OUT, IRQ
#define	b_LED	VPORTA_OUT, LED
#define b_RTOS	VPORTA_OUT, RTOS
#define b_ABO	VPORTA_OUT, ABO
#define b_DMR	VPORTA_OUT, DMR
#define b_CLK	VPORTA_OUT, CLK

#define	f_RTOS	VPORTA_INTFLAGS, RTOS
#define	c_RTOS	PORTA_PIN4CTRL
#define v_RTOS	PORTA_PORT_vect

;-----------------------------------------------------------------------------
;
;	PORT B (Bits0..5)
;
#ifdef mscpemulation
.equ	IP	= 0			; GO Level1 -> Level0 signalling RLV12
.equ	SA	= 1
#endif
#ifdef rlv12emulation
.equ	GO	= 1			; GO Level1 -> Level0 signalling RLV12
#endif
.equ	RD	= 2			; Register Read
.equ	WR	= 3			; Register Write
.equ	MSCP	= 4			; ENA in EAGLE and CPLD Design file
.equ	DMG	= 5			; DMA Granted	

#ifdef mscpemulation
#define	d_IP	VPORTB_DIR, IP	
#define	b_IP	VPORTB_OUT, IP	
#define	f_IP	VPORTB_INTFLAGS, IP
#define	c_IP	PORTB_PIN0CTRL

#define	d_SA	VPORTB_DIR, SA	
#define	b_SA	VPORTB_OUT, SA
#define	f_SA	VPORTB_INTFLAGS, SA
#define	c_SA	PORTB_PIN1CTRL

#define	v_IP	PORTB_PORT_vect
#endif

#ifdef rlv12emulation
#define	d_GO	VPORTB_DIR, GO	
#define	b_GO	VPORTB_OUT, GO	
#define	f_GO	VPORTB_INTFLAGS, GO
#define	c_GO	PORTB_PIN1CTRL
#define	v_GO	PORTB_PORT_vect
#endif

#define	d_RD	VPORTB_DIR, RD
#define	d_WR	VPORTB_DIR, WR
#define d_MSCP	VPORTB_DIR, MSCP
#define d_DMG	VPORTB_DIR, DMG

#define	b_RD	VPORTB_OUT, RD
#define	b_WR	VPORTB_OUT, WR
#define b_MSCP	VPORTB_OUT, MSCP
#define i_DMG	VPORTB_IN, DMG

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

#define c_CD	PORTC_PIN2CTRL
#define	c_WP	PORTC_PIN3CTRL

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
.equ	DBG	= 0			; PIN1 Red Kinar Wire

#define d_DBG	VPORTE_DIR, DBG
#define b_DBG	VPORTE_OUT, DBG

;-----------------------------------------------------------------------------
;
;	PORT F (Bits0..5, Bit6 is Reset and may be used as input but not here)
;
.equ	RS0	= 0			; Register Select 0
.equ	RS1	= 1			; Register Select 1
.equ	RS2	= 2			; Register Select 2
.equ	INIT	= 3			; Bus INIT interrupt
.equ	INTI	= 4			; IACK cycle interrupt
.equ	INTQ	= 5			; DATI/DATO cycle interrupt

#define	d_RS0	VPORTF_DIR, RS0
#define	d_RS1	VPORTF_DIR, RS1
#define	d_RS2	VPORTF_DIR, RS2
#define	d_INIT	VPORTF_DIR, INIT
#define	d_INTI	VPORTF_DIR, INTI
#define	d_INTQ	VPORTF_DIR, INTQ

#define	b_RS0	VPORTF_OUT, RS0
#define	b_RS1	VPORTF_OUT, RS1
#define	b_RS2	VPORTF_OUT, RS2

#define	i_INIT	VPORTF_IN, INIT
#define	f_INIT	VPORTF_INTFLAGS, INIT
#define	c_INIT	PORTF_PIN3CTRL

#define	i_INTI	VPORTF_IN, INTI
#define	f_INTI	VPORTF_INTFLAGS, INTI
#define	c_INTI	PORTF_PIN4CTRL

#define	i_INTQ	VPORTF_IN, INTQ
#define	f_INTQ	VPORTF_INTFLAGS, INTQ
#define	c_INTQ	PORTF_PIN5CTRL

#define v_QBUS	PORTF_PORT_vect

#define int_port VPORTF_IN
#define int_flags VPORTF_INTFLAGS
