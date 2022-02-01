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
;	NOTE: Macro's may destry r18 !!!

	.macro	setupdmaaddress
	ldi	r18, 0xFF		;
	cli				;;; 1
	cbi	b_RD			;;; 1
	cbi	b_RS0			;;; 1
	cbi	b_RS1			;;; 1
	sbi	b_RS2			;;; 1
	out	dataportdir, r18 	;;; 1
	out	dataportout, @0		;;; 1
	sbi	b_WR			;;; 1
	sbi	b_RS0			;;; 1 RS4->RS5
	out	dataportout, @1		;;; 1
	sbi	b_RS1			;;; 1 RS5->RS7
	out	dataportout, @2		;;; 1
	cbi	b_WR			;;; 1
	sei				;;; 1	-> 14 cycles ~0.45usec
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
	sei				;;; 1	-> 17 cycles ~0.53usec
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
	ldi	r18, 0xFF		;
	cli				;;; 1
	cbi	b_RD			;;; 1
	cbi	b_RS0			;;; 1
	sbi	b_RS1			;;; 1
	cbi	b_RS2			;;; 1
	out	dataportdir, r18	;;; 1
	out	dataportout, @0		;;; 1
	sbi	b_WR			;;; 1
	cbi	b_WR			;;; 1
	sbi	b_RS0			;;; 1
	out	dataportout, @1		;;; 1
	sbi	b_WR			;;; 1
	cbi	b_WR			;;; 1
	sei				;;; 1	-> 14 cycles ~0.45usec
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
	.ENDMACRO