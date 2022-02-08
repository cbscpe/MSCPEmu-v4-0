;-----------------------------------------------------------------------------
;
;	New Mount Volume Routine
;
;=============================================================================
;
;	When an SD-Card is inserted and initialise Mount Volume will
;	scan the SD-Card for a valid data media
;
;	- We expect a valid MBR formatted drive
;	- We will go through all partitions and create a partition control block
;	  for all partitions meaningfull to the Disk Emulator
;		o FAT-32 Partitions as candidates to store files and disk images
;		o FAT-16b Partitions as candidates to store files and disk images
;		o FAT-12 Partitions as candidates for uninitialized disk images
;		o Linux Partitions as candidates for disk images
;
;	- We will also process extendend partitions
;
;	- FAT-12 partitions are assumed to hold no valid data and are used just
;	  as a place holder partition, mostly for small disks like RL01, RL02, RK05
;	  etc. in theory FAT-12 partitions can be up to 256Mbyte (64kb Clusters)
;	  The disk emulator is provding "initialize" commands for these partitions
;	  that are writing default bad sector tables at the position expected by
;	  the DEC Operating Systems. 
;	- FAT-12 paritions can  be "activated" that is we will change the 
;	  partition type FAT-12 to Linux
;	- Linux partitions are copys of disk images. We use parittions so you can
;	  just DD disk images (e.g. created using SIMH) to the individual partitions
;	- FAT-32/16 partitions are standard FAT Volumes
;
;	- After the first step all partition control blocks are queued into the
;	  partition block queue and in a next step we will analyze the volumes
;	  and either mount them as data volumes (FAT-32/16) or disk partitions
;	  (FAT-12/Linux), data partitions must be of a predefined size that
;	  matches any of the known disk drives. Known disk drives are defined in
;	  the Drive Tab.
;	- In a third step we will try to read the file "DISKEMU.INI" in the root
;	  directory of the first FAT-32/16 volume and execute the commands found
;	  in the file
;	- If we cannot find this file we will attach the disk partitions to disk units
;	  and bring the units online
;
MountVolume:;uint8_t MountVolume(void)
	push	yl
	push	yh
	ldi	yl, low(sdio)
	ldi	yh, high(sdio)
	ldi	zl, low(sdbuffer)
	ldi	zh, high(sdbuffer)
	std	Y+P_Address+0, zl
	std	Y+P_Address+1, zh
	std	Y+P_Sector+0, zero	; Set sector to MBR
	std	Y+P_Sector+1, zero
	std	Y+P_Sector+2, zero
	std	Y+P_Sector+3, zero
	std	Y+P_Flag, zero		; Processing Flags
;
;	P_Sector has been set to the sector number of MBR or EBR
;
;	Note:	EBR are supposed to have just to have only the first two
;		partition entries been used
;
MountAnalyzeTable:
;
;	Read the MBR / EBR and analyze the partition table
;
	movw	r25:r24, yh:yl
	call	SD_CARD_READ			
	tst	r24
	brne	MountAnalyzeErr1
	ldd	xl, Y+P_Address+0
	ldd	xh, Y+P_Address+1
	subi	xl, low(-M_PartSignature)
	sbci	xh, high(-M_PartSignature)
	ld	r18, X+
	ld	r19, X+
	cpi	r18, 0x55		; Test the signature Magic Word
	brne	MountAnalyzeErr2
	cpi	r19, 0xAA		; 
	breq	MountAnalyzePart
;
MountAnalyzeErr2:
	ldi	r24, ERR_MBR		; Invalid MBR
MountAnalyzeErr1:			; IO Error
	pop	yh
	pop	yl
	ret				;
;
;	Type
;	0x01	FAT12		this partition type is used as candidate for RL01
;				RL02 images. There is an option to write back
;				the paritition table with partition code 0x83.
;
;	0x05	Extended	Note that start sectors in the partition table of
;				an extended partition are relative to the start
;				of the extended partition
;	0x06	FAT16B		<-- Data Volume
;	0x07	exFAT		<-- Ignored
;	0x0B	FAT32		<-- Data Volume not supported
;	0x83	Linux		<-- potential Unit
;
;	There are always 4 partition entries in one partition table. There should
;	be only one extended partition per table. Normally it is but it has not to
;	be the last entry.
;
MountAnalyzePart:
	ldd	zl, Y+P_Address+0
	ldd	zh, Y+P_Address+1	; Buffer Address
	subi	zl, low(-M_PartTable)	
	sbci	zh, high(-M_PartTable)	; Partition Table
	ldi	r18, 4			; 
	std	Y+P_NumSect, r18	; Has exactly 4 entries
MountAnalyzeEntry:
	ldd	r18, Z+M_PartType
	cpi	r18, 0x01		; FAT-12
	brne	MountAnalyze010
;
;	FAT-12
;	- eligable for disk image
;	- no eligable as file volume
;	- inactive
;
	rcall	MountQueuePart
	rjmp	MountAnalyze100		; done

MountAnalyze010:
	cpi	r18, 0x05		; Extended
	brne	MountAnalyze020
;
;	Extended Partition
;
	rcall	MountExtended
	rjmp	MountAnalyze100		; done

MountAnalyze020:
	cpi	r18, 0x06		; FAT-16b
	brne	MountAnalyze030
;
;	FAT-16b
;
	rcall	MountQueuePart
	rjmp	MountAnalyze100		; done

MountAnalyze030:
	cpi	r18, 0x0B		; FAT-32
	brne	MountAnalyze040
;
;	FAT-32
;
	rcall	MountQueuePart
	rjmp	MountAnalyze100		; done

MountAnalyze040:
	cpi	r18, 0x83		; Linux
	brne	MountAnalyze050
;
;	Linux
;
	rcall	MountQueuePart
	rjmp	MountAnalyze100		; done

;
;	Check for "new" partition types goes here
;
MountAnalyze050:
;
;	Partition done
;
MountAnalyze100:

	adiw	zh:zl, M_PartEntry
	ldd	r18, Y+P_NumSect
	dec	r18			; Another to go?
	std	Y+P_NumSect, r18
	brne	MountAnalyzeEntry
	ldd	r18, Y+P_Flag
	sbrs	r18, Part__Next		; Did we have a next extended partition?
	rjmp	MountAnalyzeDone	; no, then we are done ----> Part 2
	cbr	r18, (1<<Part__Next)	; Reset Extended Partition Flag
	std	Y+P_Flag, r18		; else we would loop forever!
;
;	If there was an extended partition the start sector is now stored in P_Cluster
;	and we need to analyze the partition entries in the first sector of the extended
;	partition, which typically just holds one normal partition and a next extended 
;	partition entry.
;
	ldd	r20, Y+P_Cluster+0
	ldd	r21, Y+P_Cluster+1
	ldd	r22, Y+P_Cluster+2
	ldd	r23, Y+P_Cluster+3
	std	Y+P_Sector+0, r20
	std	Y+P_Sector+1, r21
	std	Y+P_Sector+2, r22
	std	Y+P_Sector+3, r23
	rjmp	MountAnalyzeTable
;--------------------------------------------------------------------------
;
;	The partition tables have now all been analyzed and if a partition
;	has been found that matches a drive then a partition control block
;	has been queued to the pcbqueue.
;
MountAnalyzeDone:
	ldi	r18, 1			; Set First Partition ID
	sts	partitionid, r18
	ldi	r18, 'C'		; Set First Volume ID
	sts	volumeid, r18
;
;	Now we scan all partitions and will mount the FAT-16 and FAT-32 
;	partitions we find as a volume and try to match a valid drive
;	entry for all FAT-12 and Linux partitions
;
	ldi	yl, low(pcbqueue)
	ldi	yh, high(pcbqueue)
MountScanPartition:
	movw	zh:zl, yh:yl		; copy queue head pointer
	ldd	yl, Z+pcb_queue+0	; get address of next pcb
	ldd	yh, Z+pcb_queue+1
	sbiw	yh:yl, 0
	breq	MountScanDone		; end of pcb list reached
	ldd	r18, Y+pcb_type		; Get Partition
	cpi	r18, 0x01		; FAT-12
	brne	MountScanPartition010
	rcall	MountScanInactive
	rjmp	MountScanPartition
MountScanPartition010:
	cpi	r18, 0x06		; FAT-16b
	brne	MountScanPartition020
	rcall	MountScanFat16
	rjmp	MountScanPartition
MountScanPartition020:
	cpi	r18, 0x0b		; FAT-32
	brne	MountScanPartition030
	rcall	MountScanFat32
	rjmp	MountScanPartition
MountScanPartition030:
	cpi	r18, 0x83		; Linux
	brne	MountScanPartition040
	rcall	MountScanActive
	rjmp	MountScanPartition
MountScanPartition040:
	rjmp	MountScanPartition
MountScanDone:
;
;	If we have a FAT-32/16 partition we will try to read "DISKEMU.INI" from the
;	root directory of the first FAT-32/16 partition and execute it's command
;
	lds	yl, volqueue+0
	lds	yh, volqueue+1
	sbiw	yh:yl, 0
	breq	MountAttach
	ldi	r24, 0			; or 1 to really execute commands
	call	readinit
	cpi	r24, FAT_FNF		; File not found
	brne	MountAttachDone		;
;
;	No "DISKEMU.INI" found so we proceed with attaching valid paritions to
;	the disk units. Note we accept only the error file not found to proceed
;	with automatically attaching partitions to units
;
MountAttach:
	lds	yl, pcbqueue+0
	lds	yh, pcbqueue+1
	clr	r23			; for (Unit=0;Unit<units;Unit++)
MountAttachLoop:
	sbiw	yh:yl, 0		; 
	breq	MountAttachDone		; no more partitions available
	ldd	r22, Y+pcb_status
	tst	r22			; Check for idle, attach, fat bit
	brne	MountAttachNextPart	; Partition is not usable or already attached
	mov	zl, r23			; Convert unit
	swap	zl
	clr	zh
	subi	zl, low(-unittable)
	sbci	zh, high(-unittable)
	ldd	r22, Z+ucb_status	; Get current unit status
	andi	r22, (1<<ucb__file) | (1<<ucb__part)
	brne	MountAttachNextPart	; Skip this unit if already attached
	ldi	r22, (1<<ucb__drdy) | (1<<ucb__part)
	std	Z+ucb_status, r22	; Set attached to a partition
	std	Z+ucb_imgptr+0, yl
	std	Z+ucb_imgptr+1, yh
	ldi	r22, (1<<pcb__attach)
	std	Y+pcb_status, r22

	movw	r17:r16, zh:zl		; Save ucb pointer
	ldd	zl, Y+pcb_drvtab+0	; Get Pointer to Drive Tab Entry
	ldd	zh, Y+pcb_drvtab+1
	ldd	r18, Z+Drv_Flags	; Get Drive Flags
	ldd	r19, Z+Drv_Type		; Get Drive Type
	movw	zh:zl, r17:r16		; Restore ucb pointer
	std	Z+ucb_flags, r18	; Set UCB Flags
	std	Z+ucb_type, r19		; Set UCB Type

	inc	r23			
	cpi	r23, units
	brsh	MountAttachDone		; 

MountAttachNextPart:
	ldd	r24, Y+0
	ldd	r25, Y+1
	movw	yh:yl, r25:r24
	rjmp	MountAttachLoop

MountAttachDone:
	pop	yh
	pop	yl
	ret				; Exit
;-----------------------------------------------------------------------------
;_____________________________________________________________________________
;
;	Local Sub-Routines
;--------------------------------------------------------------------------
;
;	This routine is called to match the partition against a list of valid
;	drive types. In the case a valid drive type could be mapped to the
;	partition a partition control block is added to the partition queue.
;
;	Input
;		Y		Parameterblock
;		Z		Partition Table Entry
;
;	Output
;		New PCB is queued to end of PCB queue
;--------------------------------------------------------------------------
;
MountQueuePart:
	push	yl
	push	yh
	push	zl
	push	zh
;
;	Allocate a partition control block
;
	ldi	r24, low(pcb_size)
	ldi	r25, high(pcb_size)
	push	zl
	push	zh
	call	malloc
	pop	zh
	pop	zl
	sbiw	r25:r24, 0
	brne	MountQueuePart010
	rjmp	MountQueueExit
MountQueuePart010:
;
;	Save MBR/EBR Sector to PCB
;
	ldd	r16, Y+P_Sector+0	; Sector of MBR/EBR
	ldd	r17, Y+P_Sector+1
	ldd	r18, Y+P_Sector+2
	ldd	r19, Y+P_Sector+3
;
;	Initialize PCB
;
	movw	Y, r25:r24		; Y = Partition Control Block
;	
;	The Sector of the MBR
;
	std	Y+pcb_mbrsector+0, r16	; Sector of MBR/EBR
	std	Y+pcb_mbrsector+1, r17	
	std	Y+pcb_mbrsector+2, r18	
	std	Y+pcb_mbrsector+3, r19	
;
;	Queue Header
;
	std	Y+pcb_queue+0, zero
	std	Y+pcb_queue+1, zero
;
;	Partition Type, Status, MBR Offset and Parition ID
;
	ldd	r20, Z+M_PartType	; Partition Type
	std	Y+pcb_type, r20
	std	Y+pcb_status, zero
	std	Y+pcb_offset, zl	; Remember offset of entry in MBR/EBR
	std	Y+pcb_id, zero		; Remember the partition type
;
;	VCB and DRVTAB
;
	std	Y+pcb_vcb+0, zero
	std	Y+pcb_vcb+1, zero
	std	Y+pcb_drvtab+0, zero
	std	Y+pcb_drvtab+1, zero
;
;	Partition Size
;
	ldd	r20, Z+M_PartSize+0	; Partition Start Sector
	ldd	r21, Z+M_PartSize+1
	ldd	r22, Z+M_PartSize+2
	ldd	r23, Z+M_PartSize+3
	std	Y+pcb_sectors+0, r20	; Number of Sectors in Partition
	std	Y+pcb_sectors+1, r21	
	std	Y+pcb_sectors+2, r22	
	std	Y+pcb_sectors+3, r23	
;
;	Partition Start
;
	ldd	r20, Z+M_PartStart+0	; Partition Start Sector
	ldd	r21, Z+M_PartStart+1
	ldd	r22, Z+M_PartStart+2
	ldd	r23, Z+M_PartStart+3
;
;	is relative to MBR/EBR
;
	add	r16, r20
	adc	r17, r21
	adc	r18, r22
	adc	r19, r23
	
	std	Y+pcb_start+0, r16	; Save partition start sector
	std	Y+pcb_start+1, r17
	std	Y+pcb_start+2, r18
	std	Y+pcb_start+3, r19
	
	ldi	zl, low(pcbqueue)	; Insert at end of pcbqueu
	ldi	zh, high(pcbqueue)
MountQueueInsert010:
	ldd	r24, Z+pcb_queue+0	; Get next partition
	ldd	r25, Z+pcb_queue+1
	sbiw	r25:r24, 0		; Test if this is the end of queue
	breq	MountQueueInsert020	; yes, insert PCB here
	movw	Z, r25:r24		; Copy pointer to next partition
	rjmp	MountQueueInsert010	; check

MountQueueInsert020:
	std	Z+pcb_queue+0, yl	; Add this partition to last partition
	std	Z+pcb_queue+1, yh
MountQueueExit:
	pop	zh
	pop	zl
	pop	yh
	pop	yl
	ret
;--------------------------------------------------------------------------
;
;	Handle extended partitions, set flag when the first extended
;	partition has been found and copy the start sector of the first
;	extended partition to the field P_Extendend. Set the field
;	P_Cluster to the beginning of the extended partition
;
MountExtended:
	ldd	r18, Y+P_Flag
	sbrc	r18, Part__Ext		; Did we have a primary extended partition?
	rjmp	MountExtended010	; Yes
;
;	This is the first extended partition. Note that the starting sector
;	number of the first primary extension needs to be added to all partitions
;	described in any extended partition, inlcuding the extended partitions.
;	Therefore we need to remember it for later use and at the same time
;	this is the offset to the first extended partition. The offset is stored
;	in the control block at P_Cluster for later use.
;	Extended partitions can be linked, i.e. it is possible to have another
;	extended partition in a partition table of an extend partition. So if we
;	have found an extended partition we save the starting sector number
;
	ori	r18, (1<<Part__Ext) | (1<<Part__Next)
	std	Y+P_Flag, r18		; We have seen the master extended partition
	ldd	r20, Z+M_PartStart+0
	ldd	r21, Z+M_PartStart+1
	ldd	r22, Z+M_PartStart+2
	ldd	r23, Z+M_PartStart+3
	std	Y+P_Cluster+0, r20	; 
	std	Y+P_Cluster+1, r21	; 
	std	Y+P_Cluster+2, r22	; 
	std	Y+P_Cluster+3, r23	; 
	std	Y+P_Extended+0, r20	; Remember the extended parititon offset
	std	Y+P_Extended+1, r21	; 
	std	Y+P_Extended+2, r22	; 
	std	Y+P_Extended+3, r23	; 
	ret
MountExtended010:
	ori	r18, (1<<Part__Next)	; We have a next extended partition to analyze
	std	Y+P_Flag, r18
	ldd	r16, Z+M_PartStart+0
	ldd	r17, Z+M_PartStart+1
	ldd	r18, Z+M_PartStart+2
	ldd	r19, Z+M_PartStart+3
	ldd	r20, Y+P_Extended+0
	ldd	r21, Y+P_Extended+1
	ldd	r22, Y+P_Extended+2
	ldd	r23, Y+P_Extended+3
	add	r16, r20
	adc	r17, r21
	adc	r18, r22
	adc	r19, r23
	std	Y+P_Cluster+0, r16
	std	Y+P_Cluster+1, r17
	std	Y+P_Cluster+2, r18
	std	Y+P_Cluster+3, r19
	ret
;-----------------------------------------------------------------------------
;
;
;	yh:yl	Partition control block
;
MountScanInactive:
	ldi	r18, (1<<pcb__idle)
	cpse	r18, r18
MountScanActive:
	clr	r18
	std	Y+pcb_status, r18
	lds	r18, partitionid
	std	Y+pcb_id, r18
	inc	r18
	sts	partitionid, r18
	ldd	r22, Y+pcb_sectors+0
	ldd	r23, Y+pcb_sectors+1
	ldd	r24, Y+pcb_sectors+2
	ldd	r25, Y+pcb_sectors+3
	rcall	FindDriveEntry
	std	Y+pcb_drvtab+0, r24
	std	Y+pcb_drvtab+1, r25
	ret
;--------------------------------------------------------------------------
;
;	yh:yl	Partition control block
;
MountScanFAT16:
	ldi	r18, (1<<pcb__fat)
	cpse	r18, r18
MountScanFAT32:
	ldi	r18, (1<<pcb__fat | 1<<pcb__fat32)
	std	Y+pcb_status, r18
	lds	r18, volumeid
	std	Y+pcb_id, r18
	inc	r18
	sts	volumeid, r18
	push	yl
	push	yh
;
	ldd	r16, Y+pcb_start+0	; We only need the start sector
	ldd	r17, Y+pcb_start+1
	ldd	r18, Y+pcb_start+2
	ldd	r19, Y+pcb_start+3
	ldi	yl, low(sdio)		; Use the general IO parameter block
	ldi	yh, high(sdio)
	std	Y+P_Sector+0, r16	; Set the Sector
	std	Y+P_Sector+1, r17
	std	Y+P_Sector+2, r18
	std	Y+P_Sector+3, r19
	movw	r25:r24, yh:yl		;
	call	SD_CARD_READ		; Read Volume Boot Record
	tst	r24
	breq	MountScanSetup010
	rjmp	MountScanFail
MountScanSetup010:
	ldd	xl, Y+P_Address+0
	ldd	xh, Y+P_Address+1	; check magix number 0x55AA
	subi	xl, low(-M_PartSignature)
	sbci	xh, high(-M_PartSignature)
	ld	r18, X+
	cpi	r18, 0x55
	breq	MountScanSetup020
	ldi	r24, FAT_MAG
	rjmp	MountScanFail
MountScanSetup020:
	ld	r18, X+
	cpi	r18, 0xAA
	breq	MountScanSetup030
	ldi	r24, FAT_MAG
	rjmp	MountScanFail
MountScanSetup030:			; Successfully read and checkd VBR
;
;	We need
;	- volume control block
;	- parameter block for FAT IO
;	- buffer for FAT IO
;	- parameter block for DIR IO
;	- buffer for DIR IO
;
	ldi	r24, low(Vol_size)
	ldi	r25, high(Vol_size)
	call	malloc
	sbiw	r25:r24, 0
	breq	MountScanFail1
	movw	yh:yl, r25:r24		; Y = Volume Control Block
	ldi	r18, (1<<Vol__MBR) | (1<<Vol__VBR)
	std	Y+Vol_Status, r18

	ldi	r24, low(P_size)
	ldi	r25, high(P_size)
	call	malloc
	sbiw	r25:r24, 0
	breq	MountScanFail2

	std	Y+Vol_diriob+0, r24	; Parameter Block for DIR IO
	std	Y+Vol_diriob+1, r25
	
	ldi	r24, low(512)
	ldi	r25, high(512)
	call	malloc
	sbiw	r25:r24, 0
	breq	MountScanFail3

	ldd	zl, Y+Vol_diriob+0
	ldd	zh, Y+Vol_diriob+1
	rcall	MountInitIOB
		
	ldi	r24, low(P_size)
	ldi	r25, high(P_size)
	call	malloc
	sbiw	r25:r24, 0
	breq	MountScanFail4
	std	Y+Vol_fatiob+0, r24	; Parameter Block for FAT IO
	std	Y+Vol_fatiob+1, r25
	
	ldi	r24, low(512)
	ldi	r25, high(512)
	call	malloc
	sbiw	r25:r24, 0
	brne	MountScanSetup		; We got all our buffers
;
;	Unwind Buffer allocation
;
	ldd	r24, Y+Vol_fatiob+0
	ldd	r25, Y+Vol_fatiob+1
	call	free			; Free Parameter Block for FAT IO
MountScanFail4:
	ldd	zl, Y+Vol_diriob+0
	ldd	zh, Y+Vol_diriob+1
	ldd	r24, Z+P_Address+0
	ldd	r25, Z+P_Address+1
	call	free			; Free Buffer for DIR IO
MountScanFail3:
	ldd	r24, Y+Vol_diriob+0
	ldd	r25, Y+Vol_diriob+1
	call	free			; Free Parameter Block for DIR IO
MountScanFail2:
	movw	r25:r24, yh:yl
	call	free			; Free Volume Control Block
MountScanFail1:
	ldi	r24, FAT_INS		; Insufficient Memory to mount FAT volume
MountScanFail:
	call	print
	.db	"MountScanFAT failed", CR, LF, 0
	pop	yh
	pop	yl
	ret
;
;	Save last retrieved buffer and release lock
;
MountScanSetup:
	ldd	zl, Y+Vol_fatiob+0
	ldd	zh, Y+Vol_fatiob+1
	rcall	MountInitIOB
	sts	pprint+0, yl
	sts	pprint+1, yh
	call	print
	.db	"Create VCB 0x", 0x81, 0x80, CR, LF, 0
	pop	zh
	pop	zl
	push	zl
	push	zh			; Get PCB Pointer
	std	Z+pcb_vcb+0, yl
	std	Z+pcb_vcb+1, yh		; Store VCB Address
;
;	Y	Volume Control Block
;
	ldi	zl, low(sdio)
	ldi	zh, high(sdio)
	ldd	xl, Z+P_Address+0
	ldd	xh, Z+P_Address+1
	movw	zh:zl, xh:xl		; Z = Buffer Address of VBR
	ldd	r18, Z+V_BytesPSect+0	; Bytes per sector
	ldd	r19, Z+V_BytesPSect+1
	std	Y+Vol_bytespsect+0, r18
	std	Y+Vol_bytespsect+1, r19
	ldd	r18, Z+V_ReservedSect+0	; Number of reserved sectors
	ldd	r19, Z+V_ReservedSect+1
	std	Y+Vol_reservedsect+0, r18
	std	Y+Vol_reservedsect+1, r19
	ldd	r18, Z+V_SecPClust	; Sectors per cluster
	std	Y+Vol_sectperclst, r18
;
;	 FATStart = PartitionStart + ReservedSectors
;	
	movw	r25:r24, yh:yl		; Save VCB
	ldi	yl, low(sdio)		; Get IO Parameter Block
	ldi	yh, high(sdio)
	ldd	r16, Y+P_Sector+0	; Get Sector retrieved
	ldd	r17, Y+P_Sector+1
	ldd	r18, Y+P_Sector+2
	ldd	r19, Y+P_Sector+3
	movw	yh:yl, r25:r24		; Restore VCB
	std	Y+Vol_part1start+0, r16
	std	Y+Vol_part1start+1, r17
	std	Y+Vol_part1start+2, r18
	std	Y+Vol_part1start+3, r19
	ldd	r20, Z+V_ReservedSect+0
	ldd	r21, Z+V_ReservedSect+1
	add	r16, r20
	adc	r17, r21
	adc	r18, zero
	adc	r19, zero
	std	Y+Vol_fat1start+0, r16
	std	Y+Vol_fat1start+1, r17
	std	Y+Vol_fat1start+2, r18
	std	Y+Vol_fat1start+3, r19	;
;
;	DataStart = PartitionStart + ReservedSectors + (NumFAT * SectorsPerFAT)
;
	ldd	r20, Z+V_SecPFAT+0	; Sectors per FAT
	ldd	r21, Z+V_SecPFAT+1
	clr	r22
	clr	r23
	subi	r20, 0
	sbci	r21, 0
	brne	MountScanSetup100	; if it's not zero then we have FAT16
	ldd	r20, Y+Vol_Status	; Don't use R16..19
	ori	r20, 1<<Vol__FAT32
	std	Y+Vol_Status, r20	; else we have a FAT32 volume
	ldd	r20, Z+V_SecPFAT32+0
	ldd	r21, Z+V_SecPFAT32+1
	ldd	r22, Z+V_SecPFAT32+2
	ldd	r23, Z+V_SecPFAT32+3
MountScanSetup100:
	std	Y+Vol_sectperfat+0, r20
	std	Y+Vol_sectperfat+1, r21
	std	Y+Vol_sectperfat+2, r22
	std	Y+Vol_sectperfat+3, r23
;
;	Add NumFAT times SectorsPerFAT) to current DataStart
;
	ldd	r25, Z+V_NumFATs	; + NumFAT * SectorsPerFAT
	std	Y+Vol_NumFATs, r25
MountScanSetup110:
	add	r16, r20
	adc	r17, r21
	adc	r18, r22
	adc	r19, r23
	dec	r25			; Another FAT
	brne	MountScanSetup110	; Yes
;
	std	Y+Vol_datastart+0, r16	
	std	Y+Vol_datastart+1, r17	
	std	Y+Vol_datastart+2, r18	
	std	Y+Vol_datastart+3, r19
	ldd	r20, Y+Vol_Status	; Don't use R16..19
	sbrc	r20, Vol__FAT32
	rjmp	MountScanSetup130	; For FAT32 we are done
;
;	FAT-16
;	Current position points now to the start sector of the root
;	directory. Save this sector number in Vol_rootdir
;
	std	Y+Vol_rootdir+0, r16	; this is where the Root Directory Starts
	std	Y+Vol_rootdir+1, r17
	std	Y+Vol_rootdir+2, r18
	std	Y+Vol_rootdir+3, r19
;
;	Now we need to calculate the number of sectors uses for the root
;	directory and add this to the start sector of the root directory
;	to find the start of the data sectors. As each directory entry
;	requires 32 bytes we need to multiply the number of root directory
;	entries by 32, that is shift it left by 5 bits to calculate the
;	number of bytes the root directory occuppies
;
	ldd	r20, Z+V_EntriesRootD+0
	ldd	r21, Z+V_EntriesRootD+1	; Get number of entries in root DIR
	ldi	r22, 5			; Multiply by 32 = 2^5
MountScanSetup120:
	add	r20, r20
	adc	r21, r21
	dec	r22
	brne	MountScanSetup120
;
;	Now we need to round it up to the next sector, this is done by
;	adding number of bytes per sector minus one. We could either use
;	V_BytesPSect or just assume that the sector size is 512bytes which
;	in any case is the only sector size supported, so we just add
;	511 to the calculated size of the root directory
;
	subi	r20, low(-511)
	sbci	r21, high(-511)
;
;	As we assume 512 bytes per sector the high byte of the above
;	calculated number just needs to be divided by 2 to get the
;	number of sectors used for the root directory
;
	lsr	r21			; Devide by 512 gives number of
	std	Y+Vol_dirsectors, r21	; Sectors in Root Directory
	add	r16, r21		; Add number of sectors used for the
	adc	r17, zero		; root directory to the start of the
	adc	r18, zero		; root directory
	adc	r19, zero
	std	Y+Vol_datastart+0, r16	; which is then the start of the
	std	Y+Vol_datastart+1, r17	; data sectors
	std	Y+Vol_datastart+2, r18	
	std	Y+Vol_datastart+3, r19
	rjmp	MountScanSetup140
;
;	FAT-32
;	Here the root directory is just, like any directory or file, a
;	linked list of clusters. The start cluster is stored in the VBR
;	and copied to the volumecontrol block instead of the start sector
;	of the root directory of FAT-16 volumes
;
MountScanSetup130:
	std	Y+Vol_dirsectors, zero	; Invalidate for FAT32 and instead
	ldd	r16, Z+V_FAT32RootClus+0
	ldd	r17, Z+V_FAT32RootClus+1
	ldd	r18, Z+V_FAT32RootClus+2
	ldd	r19, Z+V_FAT32RootClus+3
	std	Y+Vol_rootdir+0, r16	; save the first cluster of the root
	std	Y+Vol_rootdir+1, r17	; directory as value for rootdir
	std	Y+Vol_rootdir+2, r18
	std	Y+Vol_rootdir+3, r19
;
;	Continue with FAT-32/16 volume processing
;
MountScanSetup140:
	rcall	MountScanCopyLabel
;
;	Set working directory to the ROOT directory
;
	std	Y+Vol_DirCluster+0, zero
	std	Y+Vol_DirCluster+1, zero
	std	Y+Vol_DirCluster+2, zero
	std	Y+Vol_DirCluster+3, zero	
;
;	With matching path (not multivolume for now)
;
	sts	Path, zero
;
;	Initialize the remaining fields
;
	std	Y+Vol_DirPointer+0, zero; Pointer to Current Directory Entry
	std	Y+Vol_DirPointer+1, zero
	std	Y+Vol_DirNxtPtr+0, zero	; Pointer to Next Directory Entry
	std	Y+Vol_DirNxtPtr+1, zero
	std	Y+Vol_UpdatePtr+0, zero	; Path Name Update Pointer
	std	Y+Vol_UpdatePtr+1, zero
	std	Y+Vol_DirCount, zero	; Directory Processing Counter
	std	Y+Vol_FileCnt, zero	; Active File Counter (not yet implemented)
	std	Y+Vol_link+0, zero	; Init Link Header
	std	Y+Vol_link+1, zero
;
;	Insert VCB at the end of volume queue
;
	ldi	zl, low(volqueue)	; Get start of volume queue
	ldi	zh, high(volqueue)
MountScanSetup150:
	ldd	r24, Z+Vol_link+0
	ldd	r25, Z+Vol_Link+1
	sbiw	r25:r24, 0
	breq	MountScanSetup160
	movw	zh:zl, r25:r24
	rjmp	MountScanSetup150
MountScanSetup160:
	std	Z+Vol_link+0, yl	; Queue to last VCB (or VCB queue)
	std	Z+Vol_link+1, yh
	pop	yh
	pop	yl
	clr	r24
	ret
;--------------------------------------------------------------------------
;
;	Initialise IO Parameter Block
;
;	Z	IO Parameter Block
;	r25:r24	Buffer Address
;
MountInitIOB:
	std	Z+P_Address+0, r24	; Buffer for DIR IO
	std	Z+P_Address+1, r25
	std	Z+P_Sector+0, zero
	std	Z+P_Sector+1, zero
	std	Z+P_Sector+2, zero
	std	Z+P_Sector+3, zero
	std	Z+P_Cluster+0, zero
	std	Z+P_Cluster+1, zero
	std	Z+P_Cluster+2, zero
	std	Z+P_Cluster+3, zero
	std	Z+P_Flag, zero
	std	Z+P_NumSect, zero
	ret
;--------------------------------------------------------------------------
;
;	Copy the volume label from the MBR to the VCB. A volume label
;	has up to 11 character filled with blank if necessary. It is
;	copy as a zero terminated string to the field Vol_Label which
;	is 12 bytes long.
;
MountScanCopyLabel:
	movw	r17:r16, yh:yl
	movw	r19:r18, zh:zl
	ldd	r20, Y+Vol_Status
	adiw	zh:zl, V_FAT16Label	; assume FAT16
	sbrc	r20, Vol__Fat32
	;	it is FAT32 we now add the diff as V_FAT32Lable >63
	adiw	zh:zl, V_FAT32Label-V_FAT16Label
	adiw	yh:yl, Vol_Label
	ldi	r20, 11
MountScanCopyLabel010:
	ld	r24, Z+
	st	Y+, r24
	dec	r20
	brne	MountScanCopyLabel010
	st	Y+, zero
	movw	zh:zl, r19:r18
	movw	yh:yl, r17:r16
	ret
;--------------------------------------------------------------------------
;
;	Find Matching Drive
;
;	Input
;		r25:r24:r23:r22	Drive Size
;
;	Output
;		r25:r24		Drive Table Entry
;
;
FindDriveEntry:
	ldi	zl, low(DriveTab)		; Drive Table, note we use mapped
	ldi	zh, high(DriveTab)		; FLASH, see DriveTab.inc
	sts	pprint+12, r22
	sts	pprint+13, r23
	sts	pprint+14, r24
	sts	pprint+15, r25
	call	print
	.db	CR, LF
	.db	"Finddrive with size 0x", 0x8f, 0x8e, 0x8d, 0x8c, CR, LF, 0, 0
FindDriveLoop:
	ldd	r16, Z+Drv_Name+0		; Valid table entry
	tst	r16				; 
	breq	FindDriveTabNo			; no
;	rcall	debugFindDriveLoop
	ldd	r16, Z+Drv_Capacity+0		; 
	ldd	r17, Z+Drv_Capacity+1
	ldd	r18, Z+Drv_Capacity+2
	ldd	r19, Z+Drv_Capacity+3		; Get Drive Capacity
	cp	r22, r16			; 
	cpc	r23, r17
	cpc	r24, r18
	cpc	r25, r19			; Compare to Partition Size
	breq	FindDriveFound
	brlo	FindDriveNotFound		; no to large
;
;	In many cases partitions cannot be made exact the size of a known
;	drive, therefore a second upper value is 
;
	ldd	r16, Z+Drv_MaxCapacity+0	; 
	ldd	r17, Z+Drv_MaxCapacity+1
	ldd	r18, Z+Drv_MaxCapacity+2
	ldd	r19, Z+Drv_MaxCapacity+3	; Get Max Drive Capacity
	cp	r22, r16			; 
	cpc	r23, r17
	cpc	r24, r18
	cpc	r25, r19			; Compare to Partition Size
	brlo	FindDriveFound			; yes
FindDriveNotFound:
	adiw	zh:zl, Drv_Size			; Point to next entry
	rjmp	FindDriveLoop			; continue
FindDriveFound:
	movw	r25:r24, zh:zl			; Save Drive Tabele Entry Pointer
	rjmp	FindDriveExit
	ret

FindDriveTabNo:
	clr	r24
	clr	r25
FindDriveExit:
	ret


debugFindDriveLoop:
	ldd	r16, Z+Drv_Name+0
	sts	pprint+0, r16
	ldd	r16, Z+Drv_Name+1
	sts	pprint+1, r16
	ldd	r16, Z+Drv_Name+2
	sts	pprint+2, r16
	ldd	r16, Z+Drv_Name+3
	sts	pprint+3, r16

	ldd	r16, Z+Drv_Capacity+0
	sts	pprint+4, r16
	ldd	r16, Z+Drv_Capacity+1
	sts	pprint+5, r16
	ldd	r16, Z+Drv_Capacity+2
	sts	pprint+6, r16
	ldd	r16, Z+Drv_Capacity+3
	sts	pprint+7, r16

	ldd	r16, Z+Drv_MaxCapacity+0
	sts	pprint+8, r16
	ldd	r16, Z+Drv_MaxCapacity+1
	sts	pprint+9, r16
	ldd	r16, Z+Drv_MaxCapacity+2
	sts	pprint+10, r16
	ldd	r16, Z+Drv_MaxCapacity+3
	sts	pprint+11, r16
	
	call	print
	.db	CR, LF
	.db	"Finddrive check '", 0x90, 0x91, 0x92, 0x93, "'"
	.db	", Min 0x", 0x87, 0x86, 0x85, 0x84
	.db	", Max 0x", 0x8b, 0x8a, 0x89, 0x88
	.db	CR, LF, 0, 0
	ret
