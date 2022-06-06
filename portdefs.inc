#if cpldif==40
;=============================================================================
;
;
;
;-----------------------------------------------------------------------------
;
;	PORT A	(Bits0..7)
;
.equ	ENA	= 0			; Signal/Debugging
.equ	DMR	= 1			; DMA Request	
.equ	DMG	= 2			; DMA Granted	
.equ	ABO	= 3			; Abort Cycle	
.equ	ACK	= 4			; Acknowledge Cycle
;	PA5	unused	
.equ	RTOS	= 6			; RTOS Software Interrupt	
.equ	CLK	= 7			; CPDL Clock output

#define d_ENA	VPORTA_DIR, ENA
#define d_DMR	VPORTA_DIR, DMR
#define d_DMG	VPORTA_DIR, DMG
#define d_ABO	VPORTA_DIR, ABO
#define d_ACK	VPORTA_DIR, ACK
#define d_RTOS	VPORTA_DIR, RTOS
#define d_CLK	VPORTA_DIR, CLK

#define b_ENA	VPORTA_OUT, ENA
#define b_DMR	VPORTA_OUT, DMR
#define i_DMG	VPORTA_IN, DMG
#define b_ABO	VPORTA_OUT, ABO
#define b_ACK	VPORTA_OUT, ACK

#define b_RTOS	VPORTA_OUT, RTOS
#define	f_RTOS	VPORTA_INTFLAGS, RTOS
#define	c_RTOS	PORTA_PIN6CTRL
#define v_RTOS	PORTA_PORT_vect

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
.equ	GO	= 5			; GO Level1 -> Level0 signalling RLV12

#define	d_RS0	VPORTB_DIR, RS0
#define	d_RS1	VPORTB_DIR, RS1
#define	d_RS2	VPORTB_DIR, RS2
#define	d_GO	VPORTB_DIR, GO	


#define	b_RS0	VPORTB_OUT, RS0
#define	b_RS1	VPORTB_OUT, RS1
#define	b_RS2	VPORTB_OUT, RS2
#define	b_GO	VPORTB_OUT, GO	
#define	f_GO	VPORTB_INTFLAGS, GO
#define	c_GO	PORTB_PIN5CTRL
#define	v_GO	PORTB_PORT_vect

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
.equ	INTI	= 0			; IACK cycle interrupt
.equ	INTQ	= 1			; DATI/DATO cycle interrupt
.equ	LED	= 2			; Activity LED
.equ	INIT	= 3			; Bus INIT interrupt

#define	d_INTI	VPORTE_DIR, INTI
#define	d_INTQ	VPORTE_DIR, INTQ
#define	d_LED	VPORTE_DIR, LED
#define	d_INIT	VPORTE_DIR, INIT

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

#define v_QBUS	PORTE_PORT_vect

#define int_port VPORTE_IN
#define int_flags VPORTE_INTFLAGS

;-----------------------------------------------------------------------------
;
;	PORT F (Bits0..5, Bit6 is Reset and may be used as input but not here)
;
.equ	MEM	= 0			; Malloc Interrupt
.equ	SIG	= 1			; Signal/Debugging
.equ	CRDY	= 2			; Controller Ready
.equ	IRQ	= 3			; Interrupt Request
.equ	RD	= 4			; Register Read
.equ	WR	= 5			; Register Write

#define	d_MEM	VPORTF_DIR, MEM
#define	d_SIG	VPORTF_DIR, SIG
#define	d_CRDY	VPORTF_DIR, CRDY
#define	d_IRQ	VPORTF_DIR, IRQ
#define	d_RD	VPORTF_DIR, RD
#define	d_WR	VPORTF_DIR, WR

#define	b_MEM	VPORTF_OUT, MEM
#define	b_SIG	VPORTF_OUT, SIG
#define	b_CRDY	VPORTF_OUT, CRDY
#define	b_IRQ	VPORTF_OUT, IRQ
#define	b_RD	VPORTF_OUT, RD
#define	b_WR	VPORTF_OUT, WR

#define b_MEM	VPORTF_OUT, MEM
#define	f_MEM	VPORTF_INTFLAGS, MEM
#define	c_MEM	PORTF_PIN0CTRL
#define v_MEM	PORTF_PORT_vect

#endif
#if cpldif==22
;=============================================================================
;
;	Adapter B
;
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
.equ	MEM	= 0			; malloc(), free()
.equ	CRDY	= 1			; Controller Ready
.equ	ALEW	= 2			; Write Register Address Latch Enable
.equ	WR	= 3			; Write

#define	d_MEM	VPORTE_DIR, MEM
#define	b_MEM	VPORTE_OUT, MEM
#define b_MEM	VPORTE_OUT, MEM
#define	f_MEM	VPORTE_INTFLAGS, MEM
#define	c_MEM	PORTE_PIN0CTRL
#define v_MEM	PORTE_PORT_vect

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
.equ	SIG	= 2			; SIGNAL
.equ	INTQ	= 3			; IACK
.equ	INTI	= 4			; DATI/DATO
.equ	INIT	= 5			; INIT

#define	d_DMR	VPORTF_DIR, DMR
#define	b_DMR	VPORTF_OUT, DMR

#define	d_SIG	VPORTF_DIR, SIG
#define	b_SIG	VPORTF_OUT, SIG

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

#endif
#if cpldif==999
;=============================================================================
;
;	Adapter C
;
;-----------------------------------------------------------------------------
;
;	PORT A	(Bits0..7)
;
.equ	DMG	= 0			; DMA Granted
.equ	ALER	= 1			; Read Address Latch Enable
.equ	ABO	= 2			; Abort DMA
.equ	CD	= 3			; Card Detect
.equ	MOSI0	= 4			; SPI 0
.equ	MISO0	= 5
.equ	SCK0	= 6
.equ	CLK	= 7			; CLKOUT


#define d_DMG	VPORTA_DIR, DMG
#define i_DMG	VPORTA_IN, DMG

#define d_ALER	VPORTA_DIR, ALER
#define b_ALER	VPORTA_OUT, ALER

#define d_ABO	VPORTA_DIR, ABO
#define b_ABO	VPORTA_OUT, ABO

#define d_CD	VPORTA_DIR, CD
#define	i_CD	VPORTA_IN, CD
#define	c_CD	PORTA_PIN3CTRL

#define	d_MOSI0	VPORTA_DIR, MOSI0
#define	b_MOSI0	VPORTA_OUT, MOSI0
#define d_MISO0	VPORTA_DIR, MISO0
#define	d_SCK0	VPORTA_DIR, SCK0

#define d_CLK	VPORTA_DIR, CLK
#define b_CLK	VPORTA_OUT, CLK

;-----------------------------------------------------------------------------
;
;	PORT B (Bits0..5)
;
.equ	LED	= 0			; LED on
.equ	ALEW	= 1			; Write Address Latch Enable
.equ	IRQ	= 2			; Interrupt Request
.equ	INTQ	= 3			; IACK
.equ	INTI	= 4			; DATI/DATO
.equ	INIT	= 5			; INIT

#define d_LED	VPORTB_DIR, LED
#define b_LED	VPORTB_OUT, LED

#define d_ALEW	VPORTB_DIR, ALEW
#define b_ALEW	VPORTB_OUT, ALEW

#define	d_IRQ	VPORTB_DIR, IRQ
#define	b_IRQ	VPORTB_OUT, IRQ

#define	d_INTI	VPORTB_DIR, INTI
#define	i_INTI	VPORTB_IN, INTI
#define	f_INTI	VPORTB_INTFLAGS, INTI
#define	c_INTI	PORTB_PIN3CTRL

#define	d_INTQ	VPORTB_DIR, INTQ
#define	i_INTQ	VPORTB_IN, INTQ
#define	f_INTQ	VPORTB_INTFLAGS, INTQ
#define	c_INTQ	PORTB_PIN4CTRL

#define	d_INIT	VPORTB_DIR, INIT
#define	i_INIT	VPORTB_IN, INIT
#define	f_INIT	VPORTB_INTFLAGS, INIT
#define	c_INIT	PORTB_PIN5CTRL

#define v_QBUS	PORTB_PORT_vect

#define int_port VPORTB_IN
#define int_flags VPORTB_INTFLAGS

;-----------------------------------------------------------------------------
;
;	PORT C	MVIO (Bits0..7)
;
.equ	TXD	= 0			; USART 1 Transmit
.equ	RXD	= 1			; USART 1 Receive
.equ	RTOS	= 2			; RT-OS
.equ	ENA	= 3
.equ	MOSI	= 4			; SPI
.equ	MISO	= 5
.equ	SCK	= 6
.equ	SS	= 7

#define d_TXD	VPORTC_DIR, TXD
#define d_RXD	VPORTC_DIR, RXD

#define d_RTOS	VPORTC_DIR, RTOS
#define b_RTOS	VPORTC_OUT, RTOS
#define	f_RTOS	VPORTC_INTFLAGS, RTOS
#define	c_RTOS	PORTC_PIN2CTRL
#define v_RTOS	PORTC_PORT_vect

#define d_ENA	VPORTC_DIR, ENA
#define b_ENA	VPORTC_OUT, ENA

#define d_MOSI	VPORTC_DIR, MOSI
#define b_MOSI	VPORTC_OUT, MOSI
#define d_MISO	VPORTC_DIR, MISO
#define d_SCK	VPORTC_DIR, SCK
#define d_SS	VPORTC_DIR, SS
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
.equ	MEM	= 0			; malloc(), free()
.equ	WP	= 1			; Write Protect
.equ	CRDY	= 2			; Controller Ready
.equ	WR	= 3			; Write

#define	d_MEM	VPORTE_DIR, MEM
#define	b_MEM	VPORTE_OUT, MEM
#define b_MEM	VPORTE_OUT, MEM
#define	f_MEM	VPORTE_INTFLAGS, MEM
#define	c_MEM	PORTE_PIN0CTRL
#define v_MEM	PORTE_PORT_vect

#define d_WP	VPORTE_DIR, WP
#define	i_WP	VPORTE_IN, WP
#define c_WP	PORTE_PIN1CTRL

#define	d_CRDY	VPORTE_DIR, CRDY
#define	b_CRDY	VPORTE_OUT, CRDY

#define	d_WR	VPORTE_DIR, WR
#define	b_WR	VPORTE_OUT, WR

;-----------------------------------------------------------------------------
;
;	PORT F (Bits0..5, Bit6 is Reset and may be used as input but not here)
;
.equ	GO	= 0			; Level1->Level0 signal
;	PF1	unused
.equ	SIG	= 2			; SIGNAL
.equ	DMR	= 3			; DMA Request
.equ	ACK	= 4			; Acknowledge
.equ	RD	= 5			; Read

#define	d_GO	VPORTF_DIR, GO	
#define	b_GO	VPORTF_OUT, GO	
#define	f_GO	VPORTF_INTFLAGS, GO
#define	c_GO	PORTF_PIN0CTRL
#define	v_GO	PORTF_PORT_vect

#define	d_SIG	VPORTF_DIR, SIG
#define	b_SIG	VPORTF_OUT, SIG

#define	d_DMR	VPORTF_DIR, DMR
#define	b_DMR	VPORTF_OUT, DMR

#define d_ACK	VPORTF_DIR, ACK
#define b_ACK	VPORTF_OUT, ACK

#define d_RD	VPORTF_DIR, RD
#define b_RD	VPORTF_OUT, RD
#endif
