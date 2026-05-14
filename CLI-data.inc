;--------------------------------------------------------------------------
;
;	Variables
;
	.dseg
	align	4
cdstring:	.byte	4
currentdir:	.byte	4
nbr:		.byte	8
attunit:	.byte	1
attpart:	.byte	1
tpflags:	.byte	1
.equ		tp__no	= 0
dumpswitch:	.byte	1
.equ		dumpswitch_r	= 0
.equ		dumpswitch_c	= 1
.equ		dumpswitch_b	= 2

dirswitch:	.byte	1
.equ		dirswitch_a	= 0

dumpunit:	.byte	1
dumpblock:	.byte	4
dmapdp11:	.byte	3
dmaflag:	.byte	2

portaddr:	.byte	1
portaction:	.byte	1
portbit:	.byte	1
portname:	.byte	1

logdataentry:	.byte	4
logdataentryc:	.byte	1

sdcardlbn:	.byte	4
sdcardaddr:	.byte	4
sdcardflag:	.byte	1

