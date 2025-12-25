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
	.db	"RLV12", 0, 0, 0
	.db	"CLI", 0, 0, 0, 0, 0
	.db	"SD-Card", 0
	.db	"Seek",0 , 0, 0, 0

	
.include "DriveTab.inc"
.include "help.inc"
.include "Messages.inc"
