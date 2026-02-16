;
;	This section is subject to mapping FLASH to direct addressable address range
;
;	Currently section 2 (0x8000...0xBFFF) will be mapped. All such sections
;	must be included at the end
;
;	Information retrieved from 
;		https://xhomer.isani.org/xhomer/ the Pro-350 Emulator
;		http://decvax.50megs.com/doc/rqdx/mfmdisks.html
;
;	    Filesize  Heads  Cylinders  Sectors  Disk type
;	    --------  -----  ---------  -------  ---------
;	   5,013,504      4        153       16   RD50  5M
;	   5,326,848      4        153       17   RD50  5M
;	  10,027,008      4        306       16   RD51 10M
;	  10,653,696      4        306       17   RD51 10M
;	  20,152,320      4        615       16   RD31 21M
;	  21,411,840      4        615       17   RD31 21M
;	  33,554,432      8        512       16   RD52 36M
;	  35,651,584      8        512       17   RD52 36M
;	  40,304,640      6        820       16   RD32 43M
;	  42,823,680      6        820       17   RD32 43M
;	  67,108,864      8       1024       16   RD53 71M
;	  71,303,168      8       1024       17   RD53 71M
;
;
;	Information retrieved from SIMH PDP11/pdp11_rq.c
;
;	/* The RQDX3 supports multiple disk drive types (x = not implemented):
;
;	   type sec     surf    cyl     tpg     gpc     RCT     LBNs
;	
;	   RX50 10      1       80      5       16      -       800
;	   RX33 15      2       80      2       1       -       2400
;	   RD51 18      4       306     4       1       36*4    21600
;	   RD31 17      4       615     4       1       3*8     41560
;	   RD52 17      8       512     8       1       4*8     60480
;	   RD32 17      6       820     6       1       4*8     83204
;	x  RD33 17      7       1170    ?       ?       ?       138565
;	   RD53 17      8       1024    8       1       5*8     138672
;	   RD54 17      15      1225    15      1       7*8     311200
;
;	   The simulator also supports larger drives that only existed
;	   on SDI controllers.
;
;	   RA60 42(+1)  6       1600    6       1       1008    400176
;	x  RA70 33(+1)  11      1507+   11      1       ?       547041
;	   RA80 31      14      546      ?      ?       ?       237212
;	   RA81 51(+1)  14      1258    14      1       2856    891072
;	   RA82 57(+1)  15      1435    15      1       3420    1216665
;	   RA71 51(+1)  14      1921    14      1       1428    1367310         
;	   RA72 51(+1)  20      1921    20      1       2040    1953300
;	   RA90 69(+1)  13      2656    13      1       1794    2376153
;	   RA92 73(+1)  13      3101    13      1       949     2940951
;	x  RA73 70(+1)  21      2667+   21      1       ?       3920490
;
;	   LESI attached RC25 disks (one removable, one fixed)
;	   type  sec     surf    cyl     tpg     gpc     RCT     LBNs
;	   RC25  31      2        821    ?       ?       ?       50902
;	   RCF25 31      2        821    ?       ?       ?       50902
;
;	   Each drive can be a different type.  The drive field in the
;	   unit flags specified the drive type and thus, indirectly,
;	   the drive size.
;	*/
;
;	Information retrieved from mscp_drive.hpp for UniBone
;
;   DriveInfo g_driveTable[21] {
;   //     Name     Blocks    MediaID     Model  RCTSize  Removable  ReadOnly
;       { "RX50",   800,      0x25658032, 7,     0,       true,      false }, 
;       { "RX33",   2400,     0x25658021, 10,    0,       true,      false },
;       { "RD51",   21600,    0x25644033, 6,     36,      false,     false }, 
;       { "RD31",   41560,    0x2564401f, 12,    3,       false,     false },
;       { "RC25",   50902,    0x20643019, 2,     0,       true,      false },
;       { "RC25F",  50902,    0x20643319, 3,     0,       true,      false }, 
;       { "RD52",   60480,    0x25644034, 8,     4,       false,     false }, 
;       { "RD32",   83236,    0x25641047, 15,    4,       false,     false },
;	{ "RD53",   138672,   0x25644035, 9,     5,       false,     false }, 
;       { "RA80",   237212,   0x20643019, 1,     0,       false,     false }, 
;       { "RD54",   311200,   0x25644036, 13,    7,       false,     false }, 
;       { "RA60",   400176,   0x22a4103c, 4,     1008,    true,      false },
;       { "RA70",   547041,   0x20643019, 18,    198,     false,     false }, 
;       { "RA81",   891072,   0x25641051, 5,     2856,    false,     false }, 
;       { "RA82",   1216665,  0x25641052, 11,    3420,    false,     false }, 
;       { "RA71",   1367310,  0x25641047, 40,    1428,    false,     false },
;       { "RA72",   1953300,  0x25641048, 37,    2040,    false,     false }, 
;       { "RA90",   2376153,  0x2564105a, 19,    1794,    false,     false }, 
;       { "RA92",   2940951,  0x2564105c, 29,    949,     false,     false },
;       { "RA73",   3920490,  0x25641049, 47,    198,     false,     false },
;       { "", 0, 0, 0, 0, false, false } 
;   };
;
.equ DriveTab = (PC - 0x8000) * 2 + 0x8000
;
;	RL01	40	2	256	5Mbyte
;
	.db	"RL01"			; Name
	.dd	0			; Media ID
	.dd	(40*2*256/2)		; Sector Size is only 256bytes!
	.dd	(40*2*256/2)		;
	.dw	0			; RCT only used for MSCP Emulation
	.db	40, 2			; Sector/Track, Track/Cylinder
	.dw	256			; Cylinders
	.db	0, 0			; Drive Flags, Type
;
;	RL02	40	2	512	10Mbyte
;
	.db	"RL02"
	.dd	0			; Media ID
	.dd	(40*2*512/2)		; Sector Size is only 256bytes!
	.dd	(40*2*512/2)
	.dw	0			; RCT only used for MSCP Emulation
	.db	40, 2
	.dw	512
	.db	0, (1<<DL__RL02) 	; Drive Flags, Type
;
;	RD31	17	4	615	20Mbyte		aka ST-225
;
	.db	"RD31"
	.dd	0x2564401f		; Media ID
	.dd	41560
	.dd	41560
	.dw	3			; RCT Size
	.db	17, 4
	.dw	615
	.db	0, 0
;
;	RD32	17	6	820	42Mbyte		aka ST-251-01
;
	.db	"RD32"
	.dd	0x25641047		; Media ID
	.dd	83204
	.dd	83204
	.dw	4			; RCT Size
	.db	17, 6
	.dw	820
	.db	0, 0
;
;	RD52	18	7	450	36Mbyte		aka Quantum 540 / Atasi
;
;	Note: Although this is a 36Mbyte Capacity drive the RQDX controllers
;	only defines 60480 user LBNs. Thus the small reported size.
;
	.db	"RD52"
	.dd	0x25644034		; Media ID
	.dd	60480
	.dd	60480
	.dw	4			; RCT Size
	.db	18, 8
	.dw	512
	.db	0, 0
;
;	RD53	17	8	1024	71Mbyte		aka Micropolis 1325
;
	.db	"RD53"
	.dd	0x25644035		; Media ID
	.dd	138672
	.dd	138672
	.dw	5			; RCT Size
	.db	17, 8
	.dw	1024
	.db	0, 0
;
;	RD54	17	15	1224	159Mbyte	aka Maxtor XT2190D
;
	.db	"RD54"
	.dd	0x25644036		; Media ID
	.dd	311200
	.dd	312377;/311200
	.dw	7			; RCT Size
	.db	17, 15
	.dw	1224
	.db	0, 0
;
;	RA70	34	11	1507	280Mbyte
;
	.db	"RA70"
	.dd	0x20643019		; Media ID
	.dd	547041
	.dd	547041+8
	.dw	198			; RCT Size
	.db	34, 11
	.dw	1507
	.db	0, 0
;
;	RA82	57	15	1423	622Mbyte
;
	.db	"RA82"
	.dd	0x25641052		; Media ID
	.dd	1216665
	.dd	1216665+8
	.dw	3420			; RCT Size
	.db	57, 15
	.dw	1423
	.db	0, 0
;
;	RA81	52	14	1248	456Mbyte
;
	.db	"RA81"
	.dd	0x25641051		; Media ID
	.dd	891072
	.dd	891072
	.dw	2856			; RCT Size
	.db	52, 14
	.dw	1248
	.db	0, 0
;
;	RA60	42	4	2382	205Mbyte
;
	.db	"RA60"
	.dd	0x22a4103c		; Media ID
	.dd	400176
	.dd	400176
	.dw	1008			; RCT Size
	.db	42, 4
	.dw	2382
	.db	0, 0
;
;	End of table
;
	.dw	0
