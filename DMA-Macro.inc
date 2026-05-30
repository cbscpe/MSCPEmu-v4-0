;
;	Macros and definition regarding CPDL interface
;
;	2022-05-23	CPLD Interface 22 uses now the new RLV12Emu-V21 setup
;			developped for the new RLV12 Emulator 2.0 firmware using
;			the ATmega1284P. The same interface can now be used
;			either Adapter-B with some pins on CPLD A swapped or
;			with the same pinout using Adapter-C with 3V3 LDO for
;			MVIO Port C. This replaces the previous definition of
;			the CPLD Interface 22
;
;
;	QBRIDGE CPLD V4.0 (PDP-11/Hack)
;
;	Q-Bus Data Register (RW)	0, 1
;	DMA Data Register (RW)		2, 3
;	DMA Address Register (WO)	4, 5, 7
;	Device Register Address (RO)	4
;	
;	RLV12 Emulator V2.0 2022 CPLD V2.2
;
;	CPLD-B	Read Registers using b_ALER and b_RD
;	0	Device Register Address
;	1	Q-Bus Low Byte
;	2	Q-Bus High Byte
;	3	ROM Address
;	4	DMA Low Byte
;	5	DMA High Byte
;
;	CPLD-A	Write Registers using b_ALEW and b_WR
;	0	Q-Bus Low Byte
;	1	Q-Bus High Byte
;	2	DMA Low Byte
;	3	DMA High Byte
;	4	DMA Low Byte + Direction
;	5	DMA High Byte
;	6	DMA Extended Address
;	7	ROM Configuration
;	
	.macro	dmaaddr
	sbi	b_ABO
	cbi	b_ABO			; Abort any pending DMA
	#if cpldif==40
	cli				;
	dec	zero
	out	dataportdir, zero
	clr	zero
	cbi	b_RS0			;;; 1
	cbi	b_RS1			;;; 1
	sbi	b_RS2			;;; 1
	out	dataportout, @0		;;; 1
	sbi	b_WR			;;; 1
	sbi	b_RS0			;;; 1 RS4->RS5
	out	dataportout, @1		;;; 1
	sbi	b_RS1			;;; 1 RS5->RS7
	out	dataportout, @2		;;; 1
	cbi	b_WR			;;; 1
	sei				;;; 1	-> 11 cycles ~0.35usec
	#endif
	#if cpldif==22
	cli
	out	dataportout, zero
	sbi	dataportout, 2		;;; Sets Address to 0x04
	sbi	b_ALEW
	cbi	b_ALEW
	out	dataportout, @0
	sbi	b_WR
	cbi	b_WR
	out	dataportout, @1
	sbi	b_WR
	cbi	b_WR
	out	dataportout, @2
	sbi	b_WR
	cbi	b_WR
	sei
	#endif
	.endmacro	
;
;	NOTE: dmaread destroys r18 !!!
;
	.macro	dmaread
	sbi	b_DMR			; Request DMA
	ldi	r18, dmatmo
dmareadloop1:
	dec	r18
	sbis	i_DMG			; Wait for DMA data transfer phase
	brne	dmareadloop1		; Skip branch to loop if DMG is set
	breq	dmareadtmo		; In case we reach here when r18==0.
	cbi	b_DMR			;
	#if cpldif==40	
	cli				;;; 1 Need to disable interrupt as we use the IO Port
	out	dataportdir, zero	;;; 1
	sbi	b_RD			;;; 1
	cbi	b_RS0			;;; 1
	sbi	b_RS1			;;; 1
	cbi	b_RS2			;;; 1
	waitin				;;; 3-5
	in	@0, dataportin		;;; 1
	sbi	b_RS0			;;; 1
	waitin				;;; 3-5
	in	@1, dataportin		;;; 1
	cbi	b_RD			;;; 1
	ldi	r18, 0xFF		;;; 1
	out	dataportdir, r18	;;; 1
	sei				;;; 1	-> 19 cycles ~0.6usec
	#endif
	#if cpldif==22
	cli				;;; Need to disable interrupt as we use the IO Port
	ldi	r18, 4			;;;
	out	dataportout, r18	;;; Read Sequence 1 = DMA Data Register
	sbi	b_ALER			;;;
	cbi	b_ALER			;;;
	out	dataportdir, zero	;;;
	sbi	b_RD			;;;
	waitin				;;; 3-5
	in	@0, dataportin		;;;
	sbi	b_ALER			;;;
	cbi	b_ALER			;;;
	waitin				;;; 3-5
	in	@1, dataportin		;;;
	cbi	b_RD			;;;
	ldi	r18, 0xFF		;;;
	out	dataportdir, r18	;;;
	sei				; Enable Interrupts
	#endif
	clc
	rjmp	dmareadfin

dmareadtmo:
	cbi	b_DMR
	sbi	b_ABO
	cbi	b_ABO
	sec
dmareadfin:
	.endmacro
;
;	NOTE: dmawrt destroys r18 !!!
;
	.macro	dmawrt
	#if cpldif==40	
	cli				;
	cbi	b_RS0			;;; 1
	sbi	b_RS1			;;; 1
	cbi	b_RS2			;;; 1
	out	dataportout, @0		;;; 1
	sbi	b_WR			;;; 1
	cbi	b_WR			;;; 1
	sbi	b_RS0			;;; 1
	out	dataportout, @1		;;; 1
	sbi	b_WR			;;; 1
	cbi	b_WR			;;; 1
	sei				;;; 1	-> 11 cycles ~0.35usec
	#endif
	#if cpldif==22
	cli
	ldi	r18, 2
	out	dataportout, r18
	sbi	b_ALEW
	cbi	b_ALEW
	out	dataportout, @0		;;;
	sbi	b_WR			;;;
	cbi	b_WR			;;;
	out	dataportout, @1		;;;
	sbi	b_WR			;;;
	cbi	b_WR			;;;
	sei
	#endif
	sbi	b_DMR			;
	ldi	r18, dmatmo		;
dmawriteloop2:				;
	dec	r18			;
	sbis	i_DMG			;
	brne	dmawriteloop2		;
	breq	dmawritetmo		;
	cbi	b_DMR
	clc
	rjmp	dmawritefin
dmawritetmo:
	cbi	b_DMR
	nop
	nop
	nop
	sbi	b_ABO
	cbi	b_ABO
	sec
dmawritefin:
	.endmacro
