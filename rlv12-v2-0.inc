;
;	RLV12 Register bit definitions
;
.equ	CSR_ERR		= 7
.equ	CSR_DE		= 6
.equ	CSR_DS1		= 1
.equ	CSR_DS0		= 0
.equ	CSR_DS_gm	= 0x03

.equ	CSR_CRDY	= 7		; Controller Ready
.equ	CSR_IE		= 6		; Interrupt Enable
.equ	CSR_BA17	= 5		; Bus Address 17
.equ	CSR_BA16	= 4		; Bus Address 18
.equ	CSR_FC2		= 3		; Function Code Bit 2
.equ	CSR_FC1		= 2		; Function Code Bit 1
.equ	CSR_FC0		= 1		; Function Code Bit 0
.equ	CSR_FC_gm		= 0x0E	; Function Code Mask
.equ	CSR_FC_MAINT_gm		= 0x00	; Maintenance
.equ	CSR_FC_WRTCHK_gm	= 0x02	; Write Check
.equ	CSR_FC_GETSTAT_gm	= 0x04	; Get Status
.equ	CSR_FC_SEEK_gm		= 0x06	; Seek
.equ	CSR_FC_RDHDR_gm		= 0x08	; Read Header
.equ	CSR_FC_WRITE_gm		= 0x0A	; Write
.equ	CSR_FC_READ_gm		= 0x0C	; Read
.equ	CSR_FC_RDNOHDR_gm	= 0x0E	; Read no header check

.equ	CSR_DRVRDY	= 0		; Drive Ready

.equ	BAE_BA17	= 1		; Bus Address Extension Bus Address 17
.equ	BAE_BA16	= 0		; Bus Address Extension Bus Address 16

.equ	DAR_SEEK_DIR	= 2		; Direction bit in DAR for seek
.equ	DAR_SEEK_HS	= 4		; Head select bit in DAR for seek
.equ	DAR_RW_HS	= 6		; Head select bin in DAR for read/write
.equ	DAR_GETS_RST	= 3		; Get status with reset drive error
.equ	MPR_GETS_HS	= 6		; Head select bin in MPR for get status
.equ	MPR_GETS_DT	= 7		; Drive Type bit in MPR for get status
;
;
;
		align	4
CSRL:		.byte	1		; Control and Status Register
CSRH:		.byte	1
BARL:		.byte	1		; Bus Address Register
BARH:		.byte	1
DARL:		.byte	1		; Disk Address Register
DARH:		.byte	1
MPRL:		.byte	1		; Multi Purpose Register
MPRH:		.byte	1
BAEL:		.byte	1		; Bus Address Extension Register
BAEH:		.byte	1
CSR12:		.byte	2		; not used
CSR14:		.byte	2		; auto-boot 
CSR16:		.byte	2		; auto-boot
;
;	MPR Fifo for Read Header
;
MPR_Fifo:	.byte	8		; MPR Fifo buffer

rlv12_error:	.byte	1
HNF_Count:	.byte	1
