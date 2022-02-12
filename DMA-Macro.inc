;
;	Macros and definition regarding CPDL interface
;
;	QBRIDGE CPLD V4.0
;
;	Q-Bus Data Register (RW)	0, 1
;	DMA Data Register (RW)		2, 3
;	DMA Address Register (WO)	4, 5, 7
;	Device Register Address (RO)	4
;	
;
;	DISKEmuQ	CPLD V2.2
;
;	CPLD-B	Read Register using b_RD and b_ALE
;	0	Device Register Address
;	2	Q-Bus Low Byte
;	4	Q-Bus High Byte
;	1	DMA Low Byte
;	3	DMA High Byte
;	CPLD-A	Write Register using b_RA0, b_RA1, b_WR
;	0	Reset
;	1	Q-Bus Data 
;	2	DMA Address
;	3	DMA Data
;	
;	NOTE: Macro's may destroy r18 !!!

	.macro	setupdmaaddress
	#if cpldif==40
	cli				;
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
	cbi	b_RA0			;;; 1
	cbi	b_RA1			;;; 1 Reset Register Select
	sbi	b_RA1			;;; 1 DMA Address
	sbi	b_WR			;;; 1
	cbi	b_WR			;;; 1
	out	dataportout, @1		;;; 1
	sbi	b_WR			;;; 1
	cbi	b_WR			;;; 1
	out	dataportout, @2		;;; 1
	sbi	b_WR			;;; 1
	cbi	b_WR			;;; 1
	sei				;;; 1	-> 12 cycles ~.38usec
	#endif
	.endmacro	


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
	nop				;;; 1
	nop				;;; 1
	nop				;;; 1
	in	@0, dataportin		;;; 1
	sbi	b_RS0			;;; 1
	nop				;;; 1
	nop				;;; 1
	nop				;;; 1
	in	@1, dataportin		;;; 1
	cbi	b_RD			;;; 1
	ldi	r18, 0xFF		;;; 1
	out	dataportdir, r18	;;; 1
	sei				;;; 1	-> 19 cycles ~0.6usec
	#endif
	#if cpldif==22
	cli
	ldi	r18, 1			;;; 1 DMA Data Register Sequence
	out	dataportout, r18	;;; 1
	sbi	b_ALE			;;; 1
	cbi	b_ALE			;;; 1
	ldi	r18, 0			;;; 1
	out	dataportdir, r18	;;; 1
	sbi	b_RD			;;; 1
	nop				;;; 1
	nop				;;; 1
	nop				;;; 1
	in	@0, dataportin		;;; 1
	sbi	b_ALE			;;; 1
	cbi	b_ALE			;;; 1
	nop				;;; 1
	nop				;;; 1
	nop				;;; 1
	in	@1, dataportin		;;; 1
	cbi	b_RD			;;; 1
	ldi	r18, 0xFF		;;; 1
	out	dataportdir, r18	;;; 1
	sei				;;; 1	-> 21 cycles ~0.6usec
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
	
	.macro	dmawrite
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
	cli				;
	cbi	b_RA0			;;; 1
	cbi	b_RA1			;;; 1
	sbi	b_RA0			;;; 1
	sbi	b_RA1			;;; 1
	out	dataportout, @0		;;; 1
	sbi	b_WR			;;; 1
	cbi	b_WR			;;; 1
	out	dataportout, @1		;;; 1
	sbi	b_WR			;;; 1
	cbi	b_WR			;;; 1
	sei				;;; 1	-> 11 cycles ~0.35usec
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