;--------------------------------------------------------------------------
;
;	CPU Clock
;
.equ CLKCTRL_FREQSEL_28M_gc = (0x0a<<2)  ; 28 MHz system clock	-> ok
.equ CLKCTRL_FREQSEL_32M_gc = (0x0b<<2)  ; 32 MHz system clock	-> ok

.equ	F_CLK	=	CLKCTRL_FREQSEL_32M_gc
.equ	F_CPU	=	32000000
.equ	BAUD1	= (64 * F_CPU) / (16 * 115200)

;--------------------------------------------------------------------------
;
;	Q-Bridge CPLD Version
;
.equ	cpldif	= 40
;--------------------------------------------------------------------------
;
;	Special characters
;
.equ	NULL	= 0
.equ    CR      = 015
.equ    LF      = 012
.equ    BELL    = 07
.equ    BKSP    = 010
.equ    TAB     = 011
.equ    EOF     = 032
.equ    ESC     = 033
.equ	SPACE	= 040
.equ    DEL     = 0177
.equ	DELIM	= 0x2f			; Directory Delimiter 0x2f = / and 0x5c = \

;
; ABI excerpt, for more information see ABI Register Convention Text File
;
;	R1 is always zero
;	R18-R27, R30, R31 are used by subroutines (inlcudes X and Z register)
;	R2-R17, R28, R29 are saved by subroutines (inlcudes Y register)
;
;	For a simple subroutine with a 8 or 16 parameter and a 8 or 16 bit return value
;	the register pair r25:r24 is used
;
.def	zero	=	r1		; See 
.def	crcl	=	r2		; must be saved
.def	crch	=	r3		; must be saved

.equ	led_time	= 10		; LED oneshot
.equ	dmatmo		= 100		; DMA Timeout



;#define	SPL CPU_SPL
;#define	SPH CPU_SPH
;#define	SREG CPU_SREG

#define	dbg_port	VPORTD_OUT	; Use the Data Port

;#define dbg_sysret	0
;#define dbg_sysrun	1
;#define dbg_block	2
;#define dbg_unblock	3
;#define dbg_acquire	4
;#define dbg_release	5
;#define dbg_tick	6
;#define dbg_sysnul	7

#define timer_intflags TCB0_INTFLAGS

;--------------------------------------------------------------------------
;
;	IO parameter block
;
;	This parameter block is related to block based IO to and from 
;	the massstorage device. In our case primarely an SD-Card connected
;	via SPI to the uController. 
;
recordstart	P
record		P, Address, 2		; Address of the IO Buffer
record		P, Sector, 4
record		P, Error, 2
record		P, Duration, 2

record		P, Cluster, 4		; Current Cluster
record		P, Extended, 4		; During Mount Volume
					;
record		P, Flag, 1
	.equ	Part__Next	= 5	; Analyze next extended partition table
	.equ	Part__Ext	= 7	; Current MBR has Extended Partition
record		P, NumSect, 1		; Housekeeping Counter
record		P, Volume, 2		; Pointer to volume control block
recordend	P, Size
;--------------------------------------------------------------------------
;
;	Volume control block
;

recordstart	Vol
record		Vol, link, 2		; Link List Header
record		Vol, fatiob, 2		; Address of io control block for FAT
record		Vol, diriob, 2		; Address of io control block for Directory
record		Vol, part1start, 4	; Startsector of FAT partition: VBR
record		Vol, fat1start, 4	; Startsector of 1st FAT in partition
record		Vol, bytespsect, 2	; Bytes per sector, always 512bytes per sector
record		Vol, reservedsect, 2	; Reserved sectors normally FAT16: 1, FAT32: 32
;record		Vol, sectbefore, 4	; sectors before this partition (part1start)
;record		Vol, sectpart, 4	; Sectors in this partition
;
; FAT16: First Sector[=part1start+reservdsect+numfat*sectperfat], FAT32: First Cluster
;
record		Vol, rootdir, 4		; 
record		Vol, sectperfat, 4	; Sectors per FAT as 32-bit integer
;
; part1start+reservdsect+numfat*sectperfat+int((rootentries*32+bytespsect-1)/bytespsect)
;
record		Vol, datastart, 4	; First Sector of Data Section 
record		Vol, DirPointer, 2	; Pointer to current directory entry
record		Vol, DirNxtPtr, 2	; Pointer to next directory entry
record		Vol, DirCluster, 4	; Start Cluster of Working Directory
record		Vol, UpdatePtr, 2	; Pointer to use for updating name
record		Vol, dirsectors, 1	; FAT16: Sectors in Root directory, FAT32: 0
record		Vol, sectperclst, 1	; Sectors per Cluster, 1,2,4,16,32,64
record		Vol, DirCount, 1	; Director Entry Counter
record		Vol, NumFATs, 1		; Number of Fats
record		Vol, FileCnt, 1		; Count of open files
record		Vol, Status, 1		; Status
.equ	Vol__MBR	=	0
.equ	Vol__VBR	=	1
.equ	Vol__FAT32	=	2
.equ	Vol__Long	=	3	; ??
.equ	Vol__Linked	=	4	; Directory is Linked Cluster
record		Vol, Label, 12		; Disk Label
recordend	Vol, size
;--------------------------------------------------------------------------
;
;	Parameter Block for FILE IO	(File Control Block)
;

recordstart	fcb
record		fcb, dummy, 4
record		fcb, iob, 2		; IO Parameter Block
record		fcb, Flag, 1
	.equ	F__Readonly	= 0	; File is open read-only
	.equ	F__Direct	= 1	; File is open for direct block IO
	.equ	F__Sequential	= 2	; File is open for sequential access
	.equ	F__Image	= 3	; File is a valid diskimage
	.equ	F__IOE		= 5	; File IO Error
	.equ	F__EOF		= 6	; File Read Past End Of File
	.equ	F__ERR		= 7	; File IO Error summary
record		fcb, sectperclst, 1
record		fcb, drvtab, 2
record		fcb, filename, 2
record		fcb, fraglist, 2
record		fcb, position, 4
record		fcb, filesize, 4
record		fcb, byteinsec, 2
record		fcb, volume, 2		; Pointer to Volume Control Block
recordend	fcb, size

recordstart	Fr
record		Fr, List, 2		; Linked List Head
record		Fr, Length, 4		; Length of Fragment
record		Fr, Start, 4		; Start sector of fragment on device
recordend	Fr, Size		; Size of fragment list entry
;--------------------------------------------------------------------------
;
;	Job Control Block
;

recordstart	jcb
record		jcb, link, 2		; Queue Head
record		jcb, stack, 2		; Stack Pointer
record		jcb, joblist, 2		; Job Queue
record		jcb, priority, 1	; Priority
record		jcb, flags, 1		; Flags, not used
;record		jcb, alljob, 2		; 
recordend	jcb, size


;--------------------------------------------------------------------------
;
;	Partition control block
;
recordstart	pcb
record		pcb, queue, 2		; Queue Head
record		pcb, status, 1		; Partition Status
	.equ	pcb__fat	= 0	; is FAT
	.equ	pcb__attach	= 1	; is attached to unit
	.equ	pcb__fat32	= 2	; is FAT32
	.equ	pcb__mount	= 3	; is mounted
	.equ	pcb__locked	= 4	; is locked
	.equ	pcb__idle	= 7	; is inactive
record		pcb, type, 1		; Partition Type
record		pcb, offset, 1		; MBR Offset
record		pcb, id, 1		; Partition ID
record		pcb, start, 4		; Partition start
record		pcb, sectors, 4		; Number of sectors
record		pcb, mbrsector, 4	; MBR Sector
record		pcb, vcb, 2		; Volume Control Block
record		pcb, drvtab, 2		; Drive Tabel Entry
record		pcb, reserved, 8
recordend	pcb, size

;--------------------------------------------------------------------------
;
;	Drive Table Entry
;
recordstart	Drv
record		Drv, Name, 4
record		Drv, Capacity, 4
record		Drv, MaxCapacity, 4
record		Drv, Sectors, 1
record		Drv, Tracks, 1
record		Drv, Cylinders, 2
record		Drv, Flags, 1
record		Drv, Type, 1
recordend	Drv, Size
;--------------------------------------------------------------------------
;
;	Unit control block
;
;	Unit control blocks are exactly 16 bytes. The header of UCB's are
;	standardized and inlcudes the status, the image pointer and the type.
;
;	status has 4 standard status bits defined
;	image pointer either points to a partition control block or a file control block
;	type is used to exchange information between main programm and Q-Bus access
;
;	one 16-bit word is dedicated as the disk address and is initialized to zero
;
;	there is a flags and a type flag copied from the drive table, which is only
;	available for disk image sizes within valid limits
;	

.equ	units	=	4

recordstart	ucb
record		ucb, status, 1
	.equ	ucb__drdy	= 0	; Report Drive is Ready
	.equ	ucb__part	= 1	; Unit is attached to a partition
	.equ	ucb__file	= 2	; Unit is attached to a file
	.equ	ucb__seek	= 3	; Seek in Progress
	.equ	ucb__de		= 4	; Drive Error
record		ucb, flags, 1		; Unit flags
record		ucb, type, 1		; Unit specific status
record		ucb, reserved, 1	; ...
record		ucb, imgptr, 2		; Pointer to partition or file control block
record		ucb, disksize, 4	; Disk Size to report 
record		ucb, lock, 2		; Lock word to let the unit job wait
record		ucb, diskaddr, 2	; Unit disk address register
record		ucb, seektimer, 2	; 
recordend	ucb, size

;
;	RL01/02 specific definitions
;
;	Flag bits
;
	.equ	DL__RL02	= 0	; 
;
;	MSCP specific definitions
;


	.dseg
;
;	Global Memory Locations and Global Buffers
;
	align	8
;
;	Job Stacks
;
		.byte	256			;;; User Job Stack
usersp0:
		.byte	256
usersp1:
		.byte	256
usersp2:
		.byte	256
usersp3:
;
;	CLI Command Buffers
;
InputBuffer:	.byte	256
HistoryBuffer:	.byte	256
;
;	General SD-Card IO Buffers
;
sdbuffer:	.byte	512		; Buffer to initialise SD-Card

.include "FAT-library-v2-0.inc"

RAMINITSTART:
.include "serial1.inc"
.include "CLI-data.inc"
.include "rtos-v2-2.inc"
;
;	Unit Control Blocks
;
;	ucb's are assumbed to be 16 bytes to speed the conversion of unit
;	number to ucb address. We will support up to 16 units so the 
;	unittable will always be 256 or less bytes. ucb's are either
;	linked to partitions or files and are also used to carry implementation
;	specific parameters (e.g. the RL02 bit to distinguish between RL01/02)
;	
;
	align 4
unittable:	.byte	units*ucb_size	;
;
;	Job Control Blocks
;
jcb0:		.byte	jcb_size	; Main Task and Command Line Interface
jcb1:		.byte	jcb_size	; SD-Card detect, automount, timed actions
jcb2:		.byte	jcb_size	; Disk Emulation Job aka RLV12
jcb3:		.byte	jcb_size	; *** spare ***
sdprint:	.byte	16
dmalock:	.byte	2		; dma state machine lock
rlvlock:	.byte	2
pcbqueue:	.byte	2
filequeue:	.byte	2
volqueue:	.byte	2
sdio:		.byte	P_Size		; Parameter Block to initialise SD-Card
sd_status:	.byte	1
.equ		sd__v1		= 0	; If card is a version 2 card
.equ		sd__v2		= 1	; If card is a version 2 card
.equ		sd__init	= 2	; Card could be initialised
.equ		sd__ccs		= 3	; Card Capacity Support
.equ		sd__reset	= 7	; Card could be reset successfully

partitionid:	.byte	1
volumeid:	.byte	1
InitCommand:	.byte	2
led_oneshot:	.byte	1
RAMINITEND:

;--------------------------------------------------------------------------
;
;	Queue Header for malloc() and free()
;
heap:		.byte	4
.equ	heapstart	= 0x6000
.equ	heapsize	= 0x1000

;--------------------------------------------------------------------------
;
;	GPR_GPR0 definitions for signalling
;
.equ	serin__drv	= 0
.equ	serout__drv	= 1
.equ	sdcard__insert	= 2
.equ	sdcard__remove	= 3
.equ	soft__crdy	= 4		; 
.equ	auto__boot	= 6
.equ	sddetect__en	= 7
;--------------------------------------------------------------------------
;
;	Logging Buffer
;
;	For debugging purposes a circular logging buffer is implemented. Each
;	log entry occupies 4-bytes. 
;
#define	log_iack	0x10
#define	log_init	0x20
#define	log_dato	0x30
#define	log_dati	0x40
#define	log_csr		0x00
#define	log_bar		0x02
#define	log_dar		0x04
#define	log_mpr		0x06
#define	log_bae		0x08
#define	log_boot2	0x0a
#define log_boot4	0x0c
#define log_boot6	0x0e
#define	log_fnc0	0x80
#define	log_address	0x90
#define	log_fnc2	0xa0
#define	log_seek	0xb0
#define	log_pbn		0xc0
#define	log_diskaddr	0xd0
#define log_trace	0xe0	; general trace
#define log_traceh	0xe1	; hex word
#define log_traceo	0xe2	; octal word
#define log_tracebh	0xe3	; hex bytes
#define log_tracebo	0xe4	; octal bytes


	align	4
log_pointer:	.byte	2		; current pointer into circular logging buffer
daticount:	.byte	1
datocount:	.byte	1
iackcount:	.byte	1
initcount:	.byte	1
		.byte	4

.equ	log_buffer	= 0x7000
.equ	log_size	= 0x0fff	; 4096 bytes of logging
;
;	GPR_GPR1 definitions for logging
;
.equ	log__rl0	= 0		; Log IO to unit 0
.equ	log__rl1	= 1
.equ	log__rl2	= 2
.equ	log__rl3	= 3
.equ	log__units	= 0x0f		; All Units
.equ	log__trace	= 4		; Log Debug Traces
.equ	log__iack	= 5		; Log Interrupt Ack and bus INIT
.equ	log__pbn	= 6		; Log physical block number
.equ	log__reg	= 7		; Log Device Register IO


.if ((log_buffer & log_size)> 0)
	.error " Invalid logging buffer definitions"
.endif
	.cseg
