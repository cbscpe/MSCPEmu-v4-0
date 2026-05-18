;--------------------------------------------------------------------------
;
;	The 3rd quarter of the flash will be mapped to the normal address
;	space. The new AVR family AVR128 allows to map a section of the
;	flash to the data address space so we can directly read from the
;	flash without using LPM. Note that the avrasm2 uses word addresses
;	for the flash but the data space uses byte addresses. Therefore 
;	when you put RO data into the mapped section you need to "translate"
;	the addresses into a byte address. This translation of course 
;	depends on the section you map. Here we use section 2 which starts
;	at the flash word address 0x8000. Eventually we will move all
;	RO data sections into the mapped section.
;
	.org	0x8000
.equ ReadInitName = (PC - 0x8000) * 2 + 0x8000
	.db	"RLV12.INI", NULL
	
.equ ReadInitSection = (PC - 0x8000) * 2 + 0x8000
	.db	"[RLV12.INI]", NULL

.equ CommandName = (PC - 0x8000) * 2 + 0x8000
	.db	"Maint  ", 0
	.db	"WrtChk ", 0
	.db	"GetStat", 0
	.db	"Seek   ", 0
	.db	"ReadHdr", 0
	.db	"Write  ", 0
	.db	"Read   ", 0
	.db	"ReadNC ", 0

#ifdef rlv12emulation
.equ REGName = (PC - 0x8000) * 2 + 0x8000
	.db	"CSR", 0
	.db	"BAR", 0
	.db	"DAR", 0
	.db	"MPR", 0
	.db	"BAE", 0
	.db	"BO2", 0
	.db	"BO4", 0
	.db     "BO6", 0

.equ JobNames = (PC - 0x8000) * 2 + 0x8000
	.db	"RLV12",	0, 0, 0
	.db	"CLI",		0, 0, 0, 0, 0
	.db	"SD-Card",	0
	.db	"Scan",		0 , 0, 0, 0
#endif

#ifdef mscpemulation
.equ REGName = (PC - 0x8000) * 2 + 0x8000
	.db	"IP     ", 0
	.db	"IP (S1)", 0
	.db	"IP (S2)", 0
	.db	"IP (S3)", 0
	.db	"IP (S4)", 0
	.db	"IP (WR)", 0
	.db	"IP (GO)", 0
	.db	"IP (ER)", 0
	.db	"SA     ", 0
	.db	"SA (S1)", 0
	.db	"SA (S2)", 0
	.db	"SA (S3)", 0
	.db	"SA (S4)", 0
	.db	"SA (WR)", 0
	.db	"SA (GO)", 0
	.db	"SA (ER)", 0
.equ JobNames = (PC - 0x8000) * 2 + 0x8000
	.db	"Poll",		0, 0, 0, 0
	.db	"CLI",		0, 0, 0, 0, 0
	.db	"SD-Card", 	0
	.db	"INIT",		0 , 0, 0, 0
.equ ringlengthtable = (PC - 0x8000) * 2 + 0x8000
	.dw	1, 0xFFFE
	.dw	2, 0xFFFE
	.dw	4, 0xFFFE
	.dw	8, 0xFFFE
	.dw	16, 0xFFFE
	.dw	32, 0xFFFE
	.dw	64, 0xFFFE
	.dw	128, 0xFFFE
.equ mscp_status_names = (PC - 0x8000) * 2 + 0x8000
	.db	"INIT"
	.db	"S1  "
	.db	"S2  "
	.db	"S3  "
	.db	"S4  "
	.db	"WRAP"
	.db	"GO  "
	.db	"inv."

.equ mscp_names = (PC - 0x8000) * 2 + 0x8000
	.db	"    "				;/*  0 */
	.db	"ABO "				;/*  1 b: abort */
	.db	"GCS "				;/*  2 b: get command status */
	.db	"GUS "				;/*  3 b: get unit status */
	.db	"SCC "				;/*  4 b: set controller char */
	.db	"    ", "    ", "    "		;/*  5-7 */
	.db	"AVL "				;/*  8 b: available */
	.db	"ONL "				;/*  9 b: online */
	.db	"SUC "				;/* 10 b: set unit char */
	.db	"DAP "				;/* 11 b: det acc paths - nop */
	.db	"    ","    ","    ","    "	;/* 12-15 */
	.db	"ACC "				;/* 16 b: access */
	.db	"CCD "				;/* 17 d: compare - nop */
	.db	"ERS "				;/* 18 b: erase */
	.db	"FLU "				;/* 19 d: flush - nop */
	.db	"    ","    "			;/* 20-21 */
	.db	"ERG "				;/* 22 t: erase gap */
	.db	"    ","    ","    ","    "	;/* 23-26 */
	.db	"    ","    ","    ","    "	;/* 27-30 */
	.db	"    "				;/* 31 */
	.db	"CMP "				;/* 32 b: compare */
	.db	"RD  "				;/* 33 b: read */
	.db	"WR  "				;/* 34 b: write */
	.db	"    "				;/* 35 */
	.db	"WTM "				;/* 36 t: write tape mark */
	.db	"POS "				;/* 37 t: reposition */
	.db	"    ","    ","    ","    "	;/* 38-41 */
	.db	"    ","    ","    ","    "	;/* 42-45 */
	.db	"    "				;/* 46 */
	.db	"FMT "				;/* 47 d: format */
	.db	"    ","    ","    ","    "	;/* 48-51 */
	.db	"    ","    ","    ","    "	;/* 52-55 */
	.db	"    ","    ","    ","    "	;/* 56-59 */
	.db	"    ","    ","    ","    "	;/* 60-63 */
#endif

	
.include "DriveTab.inc"
.include "help.inc"
.include "Messages.inc"
