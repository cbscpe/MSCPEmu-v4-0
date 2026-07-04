.equ ReadInitName = (PC - 0x8000) * 2 + 0x8000
#ifdef rlv12emulation
	.db	"RLV12.INI", NULL
#endif
#ifdef mscpemulation
	.db	"MSCP.INI", NULL, NULL
#endif	
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
	.db	"  0 "				;/*  0 */
	.db	"ABO "				;/*  1 b: abort */
	.db	"GCS "				;/*  2 b: get command status */
	.db	"GUS "				;/*  3 b: get unit status */
	.db	"SCC "				;/*  4 b: set controller char */
	.db	"  5 ", "  6 ", "  7 "		;/*  5-7 */
	.db	"AVL "				;/*  8 b: available */
	.db	"ONL "				;/*  9 b: online */
	.db	"SUC "				;/* 10 b: set unit char */
	.db	"DAP "				;/* 11 b: det acc paths - nop */
	.db	" 12 "," 13 "," 14 "," 15 "	;/* 12-15 */
	.db	"ACC "				;/* 16 b: access */
	.db	"CCD "				;/* 17 d: compare - nop */
	.db	"ERS "				;/* 18 b: erase */
	.db	"FLU "				;/* 19 d: flush - nop */
	.db	" 20 "," 21 "			;/* 20-21 */
	.db	"ERG "				;/* 22 t: erase gap */
	.db	" 23 "," 24 "," 25 "," 26 "	;/* 23-26 */
	.db	" 27 "," 28 "," 29 "," 30 "	;/* 27-30 */
	.db	" 31 "				;/* 31 */
	.db	"CMP "				;/* 32 b: compare */
	.db	"RD  "				;/* 33 b: read */
	.db	"WR  "				;/* 34 b: write */
	.db	" 35 "				;/* 35 */
	.db	"WTM "				;/* 36 t: write tape mark */
	.db	"POS "				;/* 37 t: reposition */
	.db	" 38 "," 39 "," 40 "," 41 "	;/* 38-41 */
	.db	" 42 "," 43 "," 44 "," 45 "	;/* 42-45 */
	.db	" 46 "				;/* 46 */
	.db	"FMT "				;/* 47 d: format */
	.db	" 48 "," 49 "," 50 "," 51 "	;/* 48-51 */
	.db	" 52 "," 53 "," 54 "," 55 "	;/* 52-55 */
	.db	" 56 "," 57 "," 58 "," 59 "	;/* 56-59 */
	.db	" 60 "," 61 "," 62 "," 63 "	;/* 60-63 */

.equ poll_dma_text = (PC - 0x8000) * 2 + 0x8000
		;----+----1----+----2----+----3--
	.db	"Poll DMA Put Descriptor ......: "
	.db	"Poll DMA Get Descriptor ......: "
	.db	"Poll DMA Put Packet ..........: "
	.db	"Poll DMA Get Packet ..........: "
	.db	"Poll DMA Write Flag ..........: "
	.db	"Poll DMA Read Prev. Descr. ...: "
	.db	"Poll DMA undefined ...........: "
	.db	"Poll DMA undefined ...........: "
#endif

