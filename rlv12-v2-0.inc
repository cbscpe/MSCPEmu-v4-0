;
;	Controller specific bit definitions
;
.equ	DL_DRSEEK	= 3		; Drive performs a seek
;
;	Controller specific defintions of ucb_type
;
.equ	DL_RL02		= 0		; Drive is RL02

;
;	RLV12 Register bit definitions
;
.equ	CSR_ERR		= 7
.equ	CSR_DE		= 6
.equ	CSR_DS1		= 1
.equ	CSR_DS0		= 0

.equ	CSR_CRDY	= 7
.equ	CSR_IE		= 6
.equ	CSR_BA17	= 5
.equ	CSR_BA16	= 4
.equ	CSR_FC2		= 3
.equ	CSR_FC1		= 2
.equ	CSR_FC0		= 1
.equ	CSR_DRVRDY	= 0

.equ	BAE_BA17	= 1
.equ	BAE_BA16	= 0

.equ	DAR_SEEK_DIR	= 2		; Direction bit in DAR for seek
.equ	DAR_SEEK_HS	= 4		; Head select bit in DAR for seek
.equ	DAR_RW_HS	= 6		; Head select bin in DAR for read/write
.equ	MPR_GETS_HS	= 6		; Head select bin in MPR for get status
.equ	MPR_GETS_DT	= 7		; Drive Type bit in MPR for get status
;
;
;
#define driveselect	(1<<CSR_DS1) | (1<<CSR_DS0)
#define function	(1<<CSR_FC2) | (1<<CSR_FC0) | (1<<CSR_FC0)

		align	4
CSRL:		.byte	1
CSRH:		.byte	1
BARL:		.byte	1
BARH:		.byte	1
DARL:		.byte	1
DARH:		.byte	1
MPRL:		.byte	1
MPRH:		.byte	1
BAEL:		.byte	1
BAEH:		.byte	1
CSR12:		.byte	2		; not implemented but addressable
CSR14:		.byte	2		; auto-boot
CSR16:		.byte	2		; auto-boot
;
;	MPR Fifo for Read Header
;
MPR_Fifo:	.byte	8		; MPR Fifo buffer

rlv12_error:	.byte	1
HNF_Count:	.byte	1
