;
;	help - initially only for help files and then being abused for additional
;	information. Urgently needs clean up as well as more help screens for the
;	command line
;


.equ hello = (PC - 0x8000) * 2 + 0x8000
;	"----+----1----+----2----+----3----+----4----+----5----+----6----+----7----+----8"
.db	CR, LF, CR, LF
#ifdef cpldif
.db	"Universal Disk Emulator V2 Vers 1.0.0   ",__DATE__ ,"  CPLD Interface active    ", CR, LF
#else
.db	"Universal Disk Emulator V2 Vers 1.0.0   ",__DATE__ ,"  CPLD Interface disabled  ", CR, LF
#endif
.dw	0

.equ help = (PC - 0x8000) * 2 + 0x8000
.db	CR, LF, CR, LF
;	"----+----1----+----2----+----3----+----4----+----5----+----6----+----7----+----8"
.db	"                                                                                ", CR, LF
.db	"      You are now in command line mode. To entere Apple II like commands        ", CR, LF
.db	"      preceed the command with a $ sign. E.g. $? for help on monitor.           ", CR, LF
.db	"                                                                                ", CR, LF
.db	"      Type 'help' for an overview fo commands                                   ", CR, LF
.db	"      Type '$n?' for additional help on monitor commands, n=0..4                ", CR, LF
.db	"                                                                                ", CR, LF
.db	"                                                                                ", CR, LF
.db	"                                                                                ", CR, LF
.dw	0

.equ help0 = (PC - 0x8000) * 2 + 0x8000
.db	CR, LF, CR, LF
;	"----+----1----+----2----+----3----+----4----+----5----+----6----+----7----+----8"
.db	"Qbridge RLV12 Emulator V2 Vers 0.9.6   ",__DATE__ ,"                            ", CR, LF
.db	"                                                                                ", CR, LF
.db	"     For general syntax see Apple II monitor. The following commands of the     ", CR, LF
.db	"     Apple II Monitor are implemented: blank, dot, colon, -, +, <, move, verify ", CR, LF
.db	"                                                                                ", CR, LF
.db	"     M        Move memory                                                       ", CR, LF
.db	"     V        Verify memory                                                     ", CR, LF
.db	"     P        Fill memory with pattern                                          ", CR, LF
.db	"     X        hexdump -C a 16-byte block                                        ", CR, LF
.db	"                                                                                ", CR, LF
.db	"     ?        Show Helpscreen                                                   ", CR, LF
.db	"     1?       SD Card Initialisation and Read/Write Block                       ", CR, LF
.db	"     2?       Volume Commands                                                   ", CR, LF
.db	"     3?       File Commands                                                     ", CR, LF
.db	"     4?       DMA Commands                                                      ", CR, LF
.db	"                                                                                ", CR, LF
.db	"                                                                                ", CR, LF
.dw	0
;
.equ help1 = (PC - 0x8000) * 2 + 0x8000
.db	CR, LF, CR, LF
;	"----+----1----+----2----+----3----+----4----+----5----+----6----+----7----+----8"
.db	"Qbridge RLV12 Emulator V2 Vers 0.9.6   ",__DATE__ ," Help Screen 1              ", CR, LF
.db	"                                                                                ", CR, LF
.db	"     The normal sequence to initialise normal SD card is                        ", CR, LF
.db	"     I        Set SPI Mode (CMD0)                                               ", CR, LF
.db	"     H        Set Interface Condition (CMD8)                                    ", CR, LF
.db	"              Version 1 Card do not understand this command and return an error ", CR, LF
.db	"              IFC:05FFFFFFFF                                                    ", CR, LF
.db	"              Version 2 Card do understand this command and return success      ", CR, LF
.db	"              IFC:01000001AA                                                    ", CR, LF
.db	"     J        Then initialises the card (ACMD41)                                ", CR, LF
.db	"     K        SD Card Operation Code Registers (CMD58)                          ", CR, LF
.db	"              The operation code register will detect SD or SDHC cards          ", CR, LF
.db	"              R58:0080FF8000FF,HCXC:00  Normal SD Cards                         ", CR, LF
.db	"              R58:00C0FF8000FF,HCXC:40  SDHC Cards                              ", CR, LF
.db	"     L        SD Card Set Block Length to 512bytes (CMD16)                      ", CR, LF
.db	"              Only non-HC/XC SD Cards require to set the block size             ", CR, LF
.db	"              HC/XC Cards have the block size already set to 512bytes           ", CR, LF
.db	"                                                                                ", CR, LF
.db	"     ^R       xxxx<yyyy^R Read Sector yyyy to Address xxxx                      ", CR, LF
.db	"     ^W       xxxx<yyyy^W Write Address yyyy to Sector xxxx                     ", CR, LF
.db	"                                                                                ", CR, LF
.dw	0
;
.equ help2 = (PC - 0x8000) * 2 + 0x8000
.db	CR, LF, CR, LF
;	"----+----1----+----2----+----3----+----4----+----5----+----6----+----7----+----8"
.db	"Qbridge RLV12 Emulator V2 Vers 0.9.6   ",__DATE__ ," Help Screen 2              ", CR, LF
.db	"                                                                                ", CR, LF
.db	"     Q        Mount volume and show info                                        ", CR, LF
.db	"     T        Show subdirectory starting at cluster (0 for root dir)            ", CR, LF
.db	"     G        Show fragment list of file with start cluster nnnn                ", CR, LF
.db	"     N        Enter Command Line Mode                                           ", CR, LF
;.db	"     U        Find Name in Directory                                            ", CR, LF
.db	"     Y        aaaa<bbbbR Read Virtual Sector bbbb to address aaaa               ", CR, LF
;.db	"     Z        Find Full File Name                                               ", CR, LF
.db	"                                                                                ", CR, LF
.dw	0
;
.equ help3 = (PC - 0x8000) * 2 + 0x8000
.db	CR, LF, CR, LF
;	"----+----1----+----2----+----3----+----4----+----5----+----6----+----7----+----8"
.db	"Qbridge RLV12 Emulator V2 Vers 0.9.6   ",__DATE__ ," Help Screen 3              ", CR, LF
.db	"                                                                                ", CR, LF
.db	"     CD <directorypath>                                                         ", CR, LF
.db	"              Change working directory to the given path, an empty string       ", CR, LF
.db	"              sets the working directory to the root (empty)                    ", CR, LF
.db	"                                                                                ", CR, LF
.db	"     DIR <directorypath>                                                        ", CR, LF
.db	"              Display the contents of the directory, when no path is            ", CR, LF
.db	"              specified the current directory is listed                         ", CR, LF
.db	"                                                                                ", CR, LF
.db	"     PWD                                                                        ", CR, LF
.db	"              Print Working Directory, that is the current base path            ", CR, LF
.db	"                                                                                ", CR, LF
.db	"     TYPE <filename>                                                            ", CR, LF
.db	"              Prints the content of the first 64kbyte of the file to the        ", CR, LF
.db	"              terminal. File lookup starts from the current directory.  The     ", CR, LF
.db	"              Filename may inlcude sub-directories                              ", CR, LF
.db	"                                                                                ", CR, LF
.db	"     ATTACH <filename> TO DLn: (work in progress)                               ", CR, LF
.db	"              Attach a file as diskimage to the DL volume n:                    ", CR, LF
.db	"                                                                                ", CR, LF
.db	"                                                                                ", CR, LF
.dw	0
;
.equ help4 = (PC - 0x8000) * 2 + 0x8000
.db	CR, LF, CR, LF
;	"----+----1----+----2----+----3----+----4----+----5----+----6----+----7----+----8"
.db	"Qbridge RLV12 Emulator V2 Vers 0.9.6   ",__DATE__ ," Help Screen 4              ", CR, LF
.db	"                                                                                ", CR, LF
.db	"     R        aaaa<bbbb.ccccR DMA read from PDP-11 Memory bbbb to AVR aaaa      ", CR, LF
.db	"     W        aaaa<bbbb.ccccW DMA write from AVR Memory bbbb to PDP-11 aaaa     ", CR, LF
.db	"     O        Increment DMA address                                             ", CR, LF	
.db	"     n$       CRDY: n=0 clear CRDY, n=1 set CRDY, else show CRDY                ", CR, LF	
.db	"     ^I       Generate vectored interrupt to PDP-11                             ", CR, LF
.db	"     ^W       Write 0..65535 to PDP-11 memory on 64kbyte boundary and check     ", CR, LF
.db	"     ^L       Initialise Log Buffer and Reset CSRs                              ", CR, LF
.db	"     ^Z       Show current status, port, counters, flags                        ", CR, LF
.dw	0






.equ help5 = (PC - 0x8000) * 2 + 0x8000
;	"----+----1----+----2----+----3----+----4----+----5----+----6----+----7----+----8"
.db	"This is the preliminary help. The following commands are available", CR, LF
.db	"  Note numbers can be entered in octal with a preceeding 0 and hex", CR, LF
.db	"  with preceeding it with 0x", CR, LF
.db	"", CR, LF
.db	"   Directory commands ", CR, LF
.db	"     dir", CR, LF
.db	"     cd ", CR, LF
.db	"     pwd", CR, LF
.db	"", CR, LF
.db	"   show commands", CR, LF
.db	"     show units ", CR, LF
.db	"     show partition ", CR, LF
.db	"     show logging ", CR, LF
.db	"", CR, LF
.db	"   units commands ", CR, LF
.db	"     detach <unit>", CR, LF
.db	"     attach <unit> partition<n> ", CR, LF
.db	"     attach <unit> <file> ", CR, LF
.db	"", CR, LF
.db	"   partition commands ", CR, LF
.db	"     activate partition<n>", CR, LF
.db	"        Changes the partition type from FAT-12 to Linux ", CR, LF
.db	"     initialize partition<n>", CR, LF
.db	"     initialize <file>", CR, LF
.db	"        Writes a default RL01/02 bad block file to the partition", CR, LF
.db	"        or file so it can later be used by the OS ", CR, LF
.db	"", CR, LF
.db	"   logging control", CR, LF
.db	"     logging - display active logging options ", CR, LF
.db	"     no logging - disable all logging optoins ", CR, LF
.db	"     [no] logging <unit>", CR, LF
.db	"     [no] logging units ", CR, LF
.db	"     [no] logging registers ", CR, LF
.db	"     [no] logging interrupt ", CR, LF
.db	"", CR, LF
.db	"     <unit>     RL0, RL1, RL2, RL3", CR, LF
.db	"", CR, LF
.db	"   load bootrom ", CR, LF
.db	"     load <address> ", CR, LF
.dw	0


;
;	The following is a copy of the Plessey MVF11 Multi-Function board.
;	It allows to enter the device mnemonic, unit and CSR address to
;	boot from. Note that all r16acters must be input in capital letters.
;
;	e.g.
;
;	DD<CR>	Boots from TU-58 Unit0
;	DL<CR>	Boots from the first RL01/02 
;
;	Note that the MSCP (DU) code is missing in the MVF11 ROM and should
;	be added there is enough free space.
;
	align	8
.equ rom165000 = (PC - 0x8000) * 2 + 0x8000
	.dw	0052115,0172522,0000010,0172060,0060003,0046504,0177440,0004000
	.dw	0172126,0000021,0041104,0176700,0004000,0172212,0000071,0042104
	.dw	0176500,0002000,0172264,0000000,0052102,0177500,0000000,0171664
	.dw	0177340,0000000,0000005,0012706,0000500,0010700,0062700,0000024
	.dw	0010037,0000004,0012737,0000340,0000006,0105711,0100376,0000410
	.dw	0010700,0062700,0000130,0010037,0000004,0010401,0105711,0100376
	.dw	0012711,0000004,0012761,0001000,0000002,0012711,0140000,0105711
	.dw	0100376,0012711,0020400,0105711,0100376,0032711,0000001,0001332
	.dw	0010705,0000403,0010705,0000401,0005007,0012711,0000002,0012761
	.dw	0177400,0000002,0012711,0000004,0005061,0000002,0012711,0100000
	.dw	0105711,0100376,0032711,0000001,0001401,0000000,0000165,0000002
	.dw	0000005,0010211,0052711,0060017,0005711,0100772,0006261,0177776
	.dw	0103373,0005161,0000002,0010211,0052711,0060011,0105711,0100376
	.dw	0010705,0000445,0000755,0000005,0010261,0000010,0012711,0000003
	.dw	0105711,0100376,0005711,0100012,0032761,0000040,0000014,0001763
	.dw	0000005,0010261,0000010,0012711,0002003,0000762,0032711,0002000
	.dw	0001402,0052704,0002000,0000413,0000746,0000005,0010213,0012711
	.dw	0000021,0012761,0014000,0000032,0010705,0000402,0000766,0010213
	.dw	0012761,0177000,0000002,0010411,0105711,0100376,0005711,0100035
	.dw	0000165,0000002,0000005,0010605,0012706,0004000,0005213,0005002
	.dw	0004767,0000050,0005013,0005761,0000002,0012702,0004004,0004767
	.dw	0000036,0010002,0004767,0000032,0005002,0105711,0100376,0116122
	.dw	0000002,0022702,0001000,0101371,0010506,0005007,0004717,0004717
	.dw	0004717,0105713,0100376,0110263,0000002,0000302,0000207,0000000
	.dw	0000000,0000000,0000000,0000000,0000000,0000000,0000000,0000000
	.dw	0000000,0000000,0000000,0000000,0000000,0000000,0000000,0000000
	.dw	0000000,0000000,0000000,0000000,0000000,0000000,0000000,0000000
	.dw	0000000,0000000,0000000,0000000,0000000,0000000,0000000,0000000
	.dw	0000000,0000000,0000000,0000000,0000000,0000000,0000000,0000000
	.dw	0000000,0000000,0000000,0000000,0000000,0000000,0000000,0000000
	.dw	0000000,0000000,0000000,0000000,0000000,0000000,0000000,0000000
	.dw	0000000,0000000,0000000,0000000,0000000,0000000,0000000,0000000
.equ rom173000 = (PC - 0x8000) * 2 + 0x8000
	.dw	0000005,0010700,0062700,0000660,0105737,0177564,0100375,0112037
	.dw	0177566,0105710,0001371,0005002,0010705,0000463,0005703,0001361
	.dw	0060002,0000302,0105702,0001770,0010704,0062704,0000606,0062704
	.dw	0000010,0005714,0001746,0100004,0010704,0062704,0171676,0000767
	.dw	0020224,0001365,0012401,0010705,0000434,0010302,0042702,0177770
	.dw	0020027,0000015,0001406,0010705,0000424,0020027,0000015,0001321
	.dw	0010301,0010200,0112405,0001403,0006302,0005305,0001375,0010103
	.dw	0112405,0060503,0012405,0012404,0020103,0001001,0050204,0060705
	.dw	0000115,0005003,0105737,0177560,0100375,0113700,0177562,0110037
	.dw	0177566,0042700,0177600,0020027,0000060,0103412,0020027,0000067
	.dw	0101007,0162700,0000060,0006303,0006303,0006303,0060003,0000752
	.dw	0000165,0000002,0000005,0010705,0000447,0000774,0000005,0052702
	.dw	0000004,0012761,0000013,0000004,0010211,0105711,0100376,0112702
	.dw	0000010,0010211,0105711,0100376,0016100,0000006,0042700,0000177
	.dw	0005200,0010061,0000004,0112702,0000006,0010211,0105711,0100376
	.dw	0011103,0042703,0177776,0001774,0005061,0000004,0012761,0177000
	.dw	0000006,0010705,0000405,0000732,0010213,0012761,0177000,0000002
	.dw	0010411,0105711,0100376,0005711,0100063,0000165,0000002,0000005
	.dw	0010705,0000467,0060704,0005006,0012703,0000001,0010705,0000451
	.dw	0010300,0010705,0000454,0010705,0000450,0010705,0000442,0105714
	.dw	0001014,0005003,0005711,0001776,0100003,0062704,0177775,0000753
	.dw	0105711,0100021,0116123,0000002,0000765,0010705,0000426,0010661
	.dw	0000002,0010705,0000426,0060006,0060006,0122323,0020627,0001000
	.dw	0103002,0024444,0000733,0110200,0006200,0006200,0006200,0006200
	.dw	0005007,0112400,0050200,0010011,0000404,0005000,0152400,0010061
	.dw	0000002,0032711,0100240,0100403,0001774,0000165,0000002,0012704
	.dw	0000212,0052702,0000400,0000673,0000407,0000003,0000407,0040003
	.dw	0000407,0100003,0005015,0000044,0045504,0177404,0003015,0000064
	.dw	0000005,0050104,0176714,0000010,0000064,0000005,0043104,0177460
	.dw	0004002,0000064,0000005,0054104,0177170,0001004,0000236,0000202
	.dw	0054504,0177170,0001004,0000236,0000206,0046104,0174400,0000010
	.dw	0000074,0000014,0000000,0000000,0000000,0000000,0000000,0000000	
; No 165000 ROM
;						^^
;	.dw	0000074,0000014,0177777,0000000,0000000,0000000,0000000,0000000

;
;	DU Boot https://www.classiccmp.org/pipermail/cctalk/2015-April/006244.html
;
;	See DUBOOT.MAC
;
.equ duboot = (PC - 0x8000) * 2 + 0x8000
	.dw	 0042125, 0000176, 0000261, 0012700, 0000000, 0012701, 0172150, 0010704
	.dw	 0103003, 0000404, 0173000, 0000340, 0000137, 0165564, 0010021, 0012705
	.dw	 0004000, 0010703, 0100000, 0002404, 0000000, 0000001, 0000011, 0001041
	.dw	 0005711, 0100753, 0031105, 0001774, 0012311, 0006305, 0100371, 0005002
	.dw	 0005022, 0020227, 0002404, 0001374, 0010237, 0001064, 0112337, 0001100
	.dw	 0111337, 0001105, 0010037, 0001074, 0012722, 0001004, 0010522, 0012722
	.dw	 0001070, 0010522, 0016102, 0177776, 0005737, 0002406, 0100775, 0105737
	.dw	 0001016, 0001313, 0105723, 0001743, 0005041, 0005007, 0000000, 0032074
.equ dubootsize = (((PC - 0x8000) * 2 + 0x8000) - duboot)/2
;
;	Load 4 blocks from RL02
;
.equ romtest = (PC - 0x8000) * 2 + 0x8000
	.dw	012737		; mov	#0, @#bar
	.dw	00
	.dw	0174402
	.dw	012737		; mov	#0, @#dar
	.dw	00
	.dw	0174404
	.dw	012737		; mov	#176000, @#mpr
	.dw	0176000
	.dw	0174406
	.dw	012737		; mov	#0, @#bae
	.dw	00
	.dw	0174410
	.dw	012737		; mov	#14, @#csr	; read
	.dw	014
	.dw	0174400
;			loop:
	.dw	013700		; mov	@#csr, r0
	.dw	0174400
	.dw	032700		; bit	#200, r0
	.dw	0200
	.dw	01773		; beq	loop
	.dw	00		; halt
.equ romtestsize = (((PC - 0x8000) * 2 + 0x8000) - romtest)/2
;
;	Find Vector Test
;
.equ iotest = (PC - 0x8000) * 2 + 0x8000
	.dw	0012700, 0000200		;	mov	#200, r0
	.dw	0012701, 0001000		;	mov	#1000, r1
	.dw	0010161, 0177000		;10$:	mov	r1, -1000(r1)
	.dw	0005021				;	clr	(r1)+
	.dw	0012761, 0000340, 0177000	;	mov	#340, -1000(r1)
	.dw	0005021				;	clr	(r1)+
	.dw	0077010				;	sob	r0, 10$
	.dw	0000240				;	nop
	.dw	0012706, 0010000		;	mov	#10000, sp
	.dw	0105737, 0174400		;20$:	tstb	@#174400
	.dw	0100375				;	bpl	20$
	.dw	0012737, 0100000, 0174402	;	mov	#100000, @#174402
	.dw	0012737, 0000000, 0174404	;	mov	#0, @#174404
	.dw	0012737, 0177200, 0174406	;	mov	#177200, @#174406
	.dw	0012737, 0000000, 0174410	;	mov	#0, @#174410
	.dw	0000240				;	nop
	.dw	0012737, 0000114, 0174400	;	mov	#114, @#174400
	.dw	0000001				;	wait
	.dw	0000000				;	halt
.equ	iotestsize = (((PC - 0x8000) * 2 + 0x8000) - iotest)/2

