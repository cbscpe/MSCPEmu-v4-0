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
record		fcb, iob, 2		; IO Parameter Block
record		fcb, drvtab, 2
record		fcb, Flag, 1
	.equ	F__Readonly	= 0	; File is open read-only
	.equ	F__Direct	= 1	; File is open for direct block IO
	.equ	F__Sequential	= 2	; File is open for sequential access
	.equ	F__Image	= 3	; File is a valid diskimage
	.equ	F__IOE		= 5	; File IO Error
	.equ	F__EOF		= 6	; File Read Past End Of File
	.equ	F__ERR		= 7	; File IO Error summary
record		fcb, sectperclst, 1
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
record		pcb, drvtab, 2		; Drive Tabel Entry
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
record		pcb, reserved, 8
recordend	pcb, size

;--------------------------------------------------------------------------
;
;	Drive Table Entry
;
recordstart	Drv
record		Drv, Name, 4
record		Drv, MediaID, 4
record		Drv, Capacity, 4
record		Drv, MaxCapacity, 4
record		DRv, RCTSize, 2
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
	.equ	ucb__onl	= 6	; MSCP
	.equ	ucb__ofl	= 7	; MSCP
record		ucb, flags, 1		; Unit flags
record		ucb, type, 1		; Unit specific status
record		ucb, r1, 1		; ...
record		ucb, imgptr, 2		; Pointer to partition or file control block
record		ucb, media, 4		; perhaps via drvtyp, it is a constant!
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