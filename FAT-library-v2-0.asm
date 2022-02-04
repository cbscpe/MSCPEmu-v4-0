;==========================================================================
;
;	Cluster / Sector Routines
;
;--------------------------------------------------------------------------
;
;	Translate Cluster to first sector number in cluster using the formula
;
;		Sector = (Cluster - 2) * SectorsPerCluster + FirstDataSector
;
;	Input:
;		r25:r24	Pointer to datastructure with P_Cluster set
;		r23:r22	Pointer to Volume Control Block
;	Output:
;		P_Sector set to first sector in cluster
;
;
Cluster2Sector:;(struct* IOParameterBlock, struct* VolumeControlBlock)
	push	r0
	push	r1			; mul
	push	yl
	push	yh
	movw	yh:yl, r25:r24		; Parameter Block
	movw	zh:zl, r23:r22		; Volume Control Block
	
	ldd	r16, Y+P_Cluster+0
	ldd	r17, Y+P_Cluster+1
	ldd	r18, Y+P_Cluster+2
	ldd	r19, Y+P_Cluster+3

	subi	r16, byte1(2)		; The first cluster is 2!
	sbci	r17, byte2(2)
	sbci	r18, byte3(2)
	sbci	r19, byte4(2)
	
	ldd	r20, Z+Vol_datastart+0	; Data Start Sector
	ldd	r21, Z+Vol_datastart+1
	ldd	r22, Z+Vol_datastart+2
	ldd	r23, Z+Vol_datastart+3
	ldd	r24, Z+Vol_sectperclst
	clr	r25			; in case r1 is the zero constant
	
	
	mul	r16, r24		; Cluster-2 bits0:7
	add	r20, r0
	adc	r21, r1
	adc	r22, r25 ; zero
	adc	r23, r25 ; zero
	mul	r17, r24		; Cluster-2 bits8:15
	add	r21, r0
	adc	r22, r1
	adc	r23, r25 ; zero
	mul	r18, r24		; Cluster-2 bits16:23
	add	r22, r0
	adc	r23, r1
	mul	r19, r24		; Cluster-2 bits24:31
	add	r23, r0
	
	std	Y+P_Sector+0, r20
	std	Y+P_Sector+1, r21
	std	Y+P_Sector+2, r22
	std	Y+P_Sector+3, r23
	pop	yh
	pop	yl
	pop	r1
	pop	r0
	ret
;--------------------------------------------------------------------------
;
;	This routine finds the next cluster of the linked clusters of a 
;	file. 
;
;	Input:
;		r25:r24		datastructure of file
;
;	Output:
;		P_Cluster updated with linked cluster
;
;	Completioncode: r24
;		FAT_EOF		end of file reached no more clusters
;		FAT_OK		new cluster stored int P_Cluster
;
;	This routine uses the IO Parameter block at Vol_fatiob of the volume
;	control block to perform the necessary IO to read a sector of the FAT.
;
;	The cluster is used as index into the FAT. We assume a sector has
;	512bytes, we do not support different sector sizes for the moment.
;
;	For FAT-16 the FAT is an array of uint16_t clusters for FAT-32 the
;	FAT is an array of uint32_t. First we need to translate the cluster
;	into a sector index into the FAT and a byte offset into the sector.
;
;	In case of FAT-16 this is simple the high byte is the sector offset
;	and the low byte of the cluster is the array index into the sector.
;	In case of FAT-32 we need to first multiply the cluster by 2 to
;	have the same logic.
;
;
LinkedCluster:;(struct* IOParameterBlock, struct* VolumeControlBlock)
	push	yl
	push	yh			; save
	movw	yh:yl, r25:r24
	movw	zh:zl, r23:r22
	ldd	r16, Y+P_Cluster+0	; Retrieve the Cluster
	ldd	r17, Y+P_Cluster+1	; 
	clr	r18			; Assume FAT16
	clr	r19
;
;	Calculate Sector in FAT of current cluster
;	FAT16: 256 entries per sector, just shift one byte right
;	Sector = Vol_Fat1Start + P_Cluster/256
;

	ldd	r20, Z+Vol_Status
	sbrs	r20, Vol__FAT32
	rjmp	LinkedCluster16
;
;	FAT32: 128 entries per sector, first shift the cluster one bit 
;	to the left so we can use the same formula
;	
;	Sector = Vol_Fat1Start + (P_Cluster*2)/256

	ldd	r18, Y+P_Cluster+2	; For FAT32 it is 4 bytes
	ldd	r19, Y+P_Cluster+3	;

	add	r16, r16		; In case of FAT32 we need to
	adc	r17, r17		; shift the Cluster by 2 in order
	adc	r18, r18		; to convert cluster in Sector as
	adc	r19, r19		; a FAT entry has 4 bytes

LinkedCluster16:
	push	r20			; Need Vol Status later again
	push	yl
	push	yh			; Save current data structure pointer
	ldd	yl, Z+Vol_fatiob+0	; All FAT operations use a dedicated
	ldd	yh, Z+Vol_fatiob+1	; control block
;
;	Now bits 8..31 of the cluster number are the sector offset
;	into the FAT, just add Vol_fat1start to get the required
;	sector to have in memory.
;
	ldd	r20, Z+Vol_fat1start+0
	add	r17, r20		; Add bit0..7 of fat1start to bit8..15
	ldd	r20, Z+Vol_fat1start+1
	adc	r18, r20		; Add bit8..15 of fat1start to bit16..23
	ldd	r20, Z+Vol_fat1start+2
	adc	r19, r20		; Add bit16..23 of fat1start to bit24..31
	ldd	r20, Z+Vol_fat1start+3
	adc	r20, zero		; Add carry to bit24..31 of fat1start
	
	ldd	r21, Y+P_Sector+0	; Check if we already have the required
	cp	r21, r17		; sector in the memory buffer
	ldd	r21, Y+P_Sector+1
	cpc	r21, r18
	ldd	r21, Y+P_Sector+2
	cpc	r21, r19
	ldd	r21, Y+P_Sector+3
	cpc	r21, r20
	breq	LinkedSameSect		; We already have it

LinkedReadSect:
	std	Y+P_Sector+0, r17	; Save Sector to read
	std	Y+P_Sector+1, r18
	std	Y+P_Sector+2, r19
	std	Y+P_Sector+3, r20	; 

	movw	r25:r24, yh:yl
	push	r16			; Save sector offset (r16 is a volatile reg)
	call	SD_CARD_READ
	pop	r16			; Restore sector offset
LinkedDead:
	cpi	r24, SD_SUCCESS
	brne	LinkedDead		; Loop of Death

LinkedSameSect:
;
;	For FAT-16 bits0..7 of r16 are an index into an array of 256 uint16_t
;	values and for FAT-32 bits1..7 of r16 are an index into an array of
;	128 uint32_t values. Therefore we need to add twice the value of r16
;	to the buffer address of the FAT sector we have read.
;
	ldi	r24, FAT_OK		; We assume that there is another cluster
	ldd	xl, Y+P_Address+0
	ldd	xh, Y+P_Address+1
	add	xl, r16			; Add low 8 bits of index twice to
	adc	xh, zero		; the buffer address to get the pointer
	add	xl, r16			; to linked cluster, note that we need
	adc	xh, zero		; to respect a potential carry 
	pop	yh
	pop	yl			; Restore calling data structure pointer
	pop	r20			; Restore Volume Status
	sbrc	r20, Vol__FAT32
	rjmp	LinkedCluster32
;
;	At the same time we copy the new cluster we also check the end of cluster
;	chain. A FAT16 entry of 0xFFF8..0xFFFF defines end of chain.
;
	ld	r16, X+			; Get the next FAT-16 cluster
	ld	r17, X+
	std	Y+P_Cluster+0, r16
	std	Y+P_Cluster+1, r17
	std	Y+P_Cluster+2, zero	; Cluster is only a 16-bit value so for
	std	Y+P_Cluster+3, zero	; FAT-16 set upper word to zero
	andi	r16, 0xF8		; Mask bits in lower byte of next cluster
	cpi	r16, 0xF8		; And compare to the value for end of
	brne	Linked16		; linked cluster
	cpi	r17, 0xFF
	brne	Linked16
	ldi	r24, FAT_EOF		; We reached the end
Linked16:
	pop	yh
	pop	yl
	ret
;
;
;
LinkedCluster32:
;
;	At the same time we copy the new cluster we also check the end of cluster
;	chain. A FAT32 entry of 0x0FFFFFF8..0x0FFFFFFF defines end of chain.
;
	ld	r16, X+			; Get the next FAT-32 cluster
	ld	r17, X+
	ld	r18, X+
	ld	r19, X+
	std	Y+P_Cluster+0, r16	; Save it to the IO Parameter
	std	Y+P_Cluster+1, r17
	std	Y+P_Cluster+2, r18
	std	Y+P_Cluster+3, r19

	andi	r16, 0xF8		; Mask the lower bits
	cpi	r16, 0xF8		; Compare
	brne	LinkedMore
	cpi	r17, 0xFF
	brne	LinkedMore
	cpi	r18, 0xFF
	brne	LinkedMore
	andi	r19, 0x0F		; Mask the higher bits
	cpi	r19, 0x0F		; Compare
	brne	LinkedMore
	ldi	r24, FAT_EOF		; We reached the end
LinkedMore:
	pop	yh
	pop	yl
	ret

;--------------------------------------------------------------------------
;
;	Create a fragment list of a file. The fragmentlist consists of
;	tuples of fragmentsize and fragmentstart.  Each tuple is a 32-bit
;	integer. This is to support direct block IO to disk images without
;	the need to read additional sectors from the device.
;
;	size	the size of this fragments in sectors
;	start	the number of the first sector covered by this fragment
;
;	When we now need to read or write a specific sector of a file we need
;	to find the corresponding entry. For this we compare the sector we 
;	want with the size of the fragment. If it is lower then we found the
;	fragment. Else we subtract the size from the sector which can be looked
;	at as the offset into the next fragment. If the calculated value is
;	less then the size of the next fragment we are done. Else we continue
;	until the number of sector is negative (if a file is 4 sectors long
;	the sectors we can read are numbered 0,1,2,3. When we subtract the
;	legnths of all fragements from the sector to read the result is -1)
;
;	When we found a fragment we just need to add the (remaining) sector
;	offset to the start sector number of this fragment. The results is
;	then the absolute sector on the device.
;
;	Input:
;		r25:r24	Pointer to file control block
;
;	Output:
;		Fragmentlist created
;
;
;	Completioncode:
;		-1	The file has more fragments than we can store in memory
;		0	Created complete fragment list
;
;
; uint8_t BuildFagList(struct* FileControlBlock)
;
BuildFragList:
	push	r11
	push	r12
	push	r13
	push	r14
	push	r15
	push	yl
	push	yh

	sts	pprint+0, r24		; File Control Block
	sts	pprint+1, r25
	movw	zh:zl, r25:r24		; Copy File Control Block

	ldd	yl, Z+fcb_Volume+0	; 
	ldd	yh, Z+fcb_Volume+1
	sts	pprint+2, yl		; Volume Control Block
	sts	pprint+3, yh
	ldd	r11, Y+Vol_sectperclst	;

	movw	r13:r12, yh:yl		; Save Volume Control Block
	ldd	yl, Z+fcb_iob+0
	ldd	yh, Z+fcb_iob+1
	sts	pprint+4, yl		; IO Parameter Block
	sts	pprint+5, yh
	adiw	Z, fcb_fraglist		; Queue Head Address
	movw	r15:r14, zh:zl		; In case of failure we need this
	sts	pprint+6, zl
	sts	pprint+7, zh

;	call	print
;	.db	CR, LF, "debugBuildFragList  FCB 0x", 0x81, 0x80
;	.db	", VCB 0x", 0x83, 0x82, ", IOB 0x", 0x85, 0x84
;	.db	", FRL 0x", 0x87, 0x86
;	.db	CR, LF, 0, 0
;	ldi	r24, low(500)
;	ldi	r25, high(500)
;	call	delay
	
;
BuildFragListNext:
	ldi	r24, low(Fr_Size)	; Get a memory block for one fragment entry
	ldi	r25, high(Fr_Size)
	call	malloc
	sbiw	r25:r24, 0
	brne	BuildFragList010
	movw	r25:r24, r15:r14
	rcall	FreeList	
	ldi	r24, -1
	rjmp	BuildFragListExit
	
BuildFragList010:
;	sts	pprint+0, r24
;	sts	pprint+1, r25
;	sts	pprint+2, zl
;	sts	pprint+3, zh
;	call	print
;	.db	"debugBuildFragList store 0x", 0x81, 0x80, " to 0x", 0x83, 0x82, CR, LF, 0
	std	Z+Fr_List+0, r24	; Copy address to the previous queue head
	std	Z+Fr_List+1, r25
	movw	zh:zl, r25:r24		; New queue head
	std	Z+Fr_List+0, zero	; Current end of chain
	std	Z+Fr_List+1, zero
	std	Z+Fr_Length+0, r11	; initialise packet with a fragment of at
	std	Z+Fr_Length+1, zero	; least one cluster
	std	Z+Fr_Length+2, zero
	std	Z+Fr_Length+3, zero	; initial size of fragment = sectors per cluster

	movw	r23:r22, r13:r12	; Volume Control Block
	movw	r25:r24, yh:yl		; Parameter Block
	push	zl
	push	zh
	rcall	Cluster2Sector		; convert cluster to sector
	pop	zh
	pop	zl
	ldd	r16, Y+P_Sector+0	; And make this the 
	ldd	r17, Y+P_Sector+1
	ldd	r18, Y+P_Sector+2
	ldd	r19, Y+P_Sector+3

	std	Z+Fr_Start+0, r16	; start sector of this fragment.
	std	Z+Fr_Start+1, r17
	std	Z+Fr_Start+2, r18
	std	Z+Fr_Start+3, r19
;-	rcall	debugBuildFragList1

BuildFragListLoop:
	ldd	r16, Y+P_Cluster+0
	ldd	r17, Y+P_Cluster+1
	ldd	r18, Y+P_Cluster+2	
	ldd	r19, Y+P_Cluster+3	; Save current cluster in the P_Sector

	std	Y+P_Sector+0, r16	;
	std	Y+P_Sector+1, r17	;
	std	Y+P_Sector+2, r18	;
	std	Y+P_Sector+3, r19	; which is currently not used

	movw	r23:r22, r13:r12	; Volume Control Block
	movw	r25:r24, yh:yl		; Parameter Block
	push	zl
	push	zh
	rcall	LinkedCluster		; Get linked cluster
	pop	zh
	pop	zl
	cpi	r24, FAT_EOF
	breq	BuildFragListDone	; No more clusters
;-	rcall	debugBuildFragList2
	ldd	r16, Y+P_Sector+0	; Get previous cluster
	ldd	r17, Y+P_Sector+1	; 
	ldd	r18, Y+P_Sector+2	; 
	ldd	r19, Y+P_Sector+3	; 

	subi	r16, byte1(-1)
	sbci	r17, byte2(-1)
	sbci	r18, byte3(-1)
	sbci	r19, byte4(-1)		; Increment by one

	ldd	r20, Y+P_Cluster+0
	cp	r20, r16
	ldd	r20, Y+P_Cluster+1
	cpc	r20, r17
	ldd	r20, Y+P_Cluster+2
	cpc	r20, r18
	ldd	r20, Y+P_Cluster+3
	cpc	r20, r19
	breq	BuildFragList020
	rjmp	BuildFragListNext	; need new fragement entry
;
BuildFragList020:
	ldd	r16, Z+Fr_Length+0	; next cluster is adjacent, i.e. it belongs
	ldd	r17, Z+Fr_Length+1	; to this fragment, so we just
	ldd	r18, Z+Fr_Length+2	; 
	ldd	r19, Z+Fr_Length+3	; 
	add	r16, r11		; add sectors per cluster
	adc	r17, zero		; to this fragmentsize
	adc	r18, zero
	adc	r19, zero
	std	Z+Fr_Length+0, r16
	std	Z+Fr_Length+1, r17
	std	Z+Fr_Length+2, r18
	std	Z+Fr_Length+3, r19	; save
	rjmp	BuildFragListLoop	; check next clusters
;
BuildFragListDone:
	clr	r24
BuildFragListExit:
	pop	yh
	pop	yl
	pop	r15
	pop	r14
	pop	r13
	pop	r12
	pop	r11
	ret
	
debugBuildFragList1:
	ldd	r16, Z+Fr_Length+0	; Length of current fragment
	ldd	r17, Z+Fr_Length+1
	ldd	r18, Z+Fr_Length+2	
	ldd	r19, Z+Fr_Length+3

	sts	pprint+0, r16
	sts	pprint+1, r17
	sts	pprint+2, r18
	sts	pprint+3, r19

	ldd	r16, Z+Fr_Start+0
	ldd	r17, Z+Fr_Start+1
	ldd	r18, Z+Fr_Start+2	
	ldd	r19, Z+Fr_Start+3	; Save current cluster in the P_Sector

	sts	pprint+4, r16
	sts	pprint+5, r17
	sts	pprint+6, r18
	sts	pprint+7, r19
	
	sts	pprint+8, zl
	sts	pprint+9, zh

	call	print
	.db	"debugBuildFragList1 0x", 0x89, 0x88
	.db	" Start 0x", 0x87, 0x86, 0x85, 0x84, "," 
	.db	" Length 0x", 0x83, 0x82, 0x81, 0x80, CR, LF, 0, 0
	ret
	
debugBuildFragList2:
	ldd	r16, Y+P_Sector+0
	ldd	r17, Y+P_Sector+1
	ldd	r18, Y+P_Sector+2
	ldd	r19, Y+P_Sector+3
	
	sts	pprint+0, r16
	sts	pprint+1, r17
	sts	pprint+2, r18
	sts	pprint+3, r19
	
	ldd	r16, Y+P_Cluster+0
	ldd	r17, Y+P_Cluster+1
	ldd	r18, Y+P_Cluster+2
	ldd	r19, Y+P_Cluster+3
	
	sts	pprint+4, r16
	sts	pprint+5, r17
	sts	pprint+6, r18
	sts	pprint+7, r19
	
	call	print
	.db	"debugBuildFragList2 0x",0x83, 0x82, 0x81, 0x80
	.db	" -> 0x", 0x87, 0x86, 0x85, 0x84, CR, LF, 0, 0
	ret
;--------------------------------------------------------------------------
;
;	This routine disposes a list of packets from a given point. This can
;	be either the queue list head or any packet address, provided the 
;	pointer to the next packet is stored in the first two bytes.
;
;	Input:
;		r25:r24		Listheader
;
;	Output:
;		Listhead is zeroized queued packets are freed
;
;	Registers:
;		none
;	
FreeList:
	push	yl
	push	yh
	movw	zh:zl, r25:r24
	push	zl
	push	zh
;	
FreeListNext:
	ldd	yl, Z+0				; Get next packet address
	ldd	yh, Z+1
	movw	r25:r24, Y			; 
	ldd	zl, Y+0				; Get linked packet address
	ldd	zh, Y+1
	call	free				; Free this packet
	cp	zl, zero			; Check next packet address
	cpc	zh, zero
	brne	FreeListNext			; there is still another one
;
	pop	zh
	pop	zl
	std	Z+0, zero			; Clear the list head
	std	Z+1, zero
	pop	yh
	pop	yl
	ret
;--------------------------------------------------------------------------
;
;	Translate logical block to physical sector using the fragment list
;	of the file entry
;
;	2019-07-26	Input changed from P_Sector to P_Cluster so we can keep the
;			logical block number in P_Cluster. As this is only used for
;			block IO files P_Cluster is not used as we have a fragment
;			list to access the sectors of the file.
;
;	Input:
;	Y		Pointer to data structure for file IO
;	Y+P_Cluster	Logical Block Number
;
;	Output
;
;	Y+P_Sector	Physical Sector Number
;	r24		return code
;
;	Ver2.0
;
;	Input:
;	r25:r24		File Control Block
;	P_Cluster of IOB set to Logical Block Number
;
;	Output:
;	P_Sector of IOB set to physical Block Number
;	r24		return code
;
;
Logical2Physical:
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldd	zl, Y+fcb_iob+0
	ldd	zh, Y+fcb_iob+1		; Get parameter block
	ldd	r16, Z+P_Cluster+0	; Get logical block number
	ldd	r17, Z+P_Cluster+1
	ldd	r18, Z+P_Cluster+2
	ldd	r19, Z+P_Cluster+3
	ldd	zl, Y+fcb_fraglist+0
	ldd	zh, Y+fcb_fraglist+1	; Get first fragment descriptor

Logical2Loop:
	ldd	r20, Z+Fr_Length+0	; get size of current fragment list
	ldd	r21, Z+Fr_Length+1	
	ldd	r22, Z+Fr_Length+2	
	ldd	r23, Z+Fr_Length+3	
	cp	r16, r20
	cpc	r17, r21
	cpc	r18, r22
	cpc	r19, r23
	brlo	Logical2Found		; logical block < size -> found

	sub	r16, r20
	sbc	r17, r21
	sbc	r18, r22
	sbc	r19, r23	

	ldd	r24, Z+Fr_List+0	; Get next fragment descriptor
	ldd	r25, Z+Fr_List+1
	sbiw	r25:r24, 0
	brne	Logical2Loop
	ldi	r24, -1
	rjmp	Logical2Exit
;
Logical2Found:
	ldd	r20, Z+Fr_Start+0	; Add physical sector number of first
	ldd	r21, Z+Fr_Start+1
	ldd	r22, Z+Fr_Start+2
	ldd	r23, Z+Fr_Start+3
	
	add	r16, r20
	adc	r17, r21
	adc	r18, r22
	adc	r19, r23

	ldd	zl, Y+fcb_iob+0
	ldd	zh, Y+fcb_iob+1		; Get parameter block
	std	Z+P_Sector+0, r16	; return physical block number
	std	Z+P_Sector+1, r17
	std	Z+P_Sector+2, r18
	std	Z+P_Sector+3, r19
	clr	r24
Logical2Exit:
	pop	yh
	pop	yl
	ret

;==========================================================================
;
;	Name Routines
;
;--------------------------------------------------------------------------
;
;	File Name Primitives
;
;	To deal with names we actually have some global buffers.
;
;	Long File Name Buffer
;		This buffer is used when dealing with long file names, during the
;		read of directory the long file name is constructed into this buffer
;		if the directory entries are used for long filenames
;
;	Name Buffer
;		When parsing a file name each individual name of the hierarchy of
;		the input name is copied onto the namebuffer
;
;	Filenames on FAT16 and FAT32 volumes can be up to 255 characters, so 
;	in theory all three name buffers must be long enough to hold the worst
;	possible scenario. However this wastes space. Therefore the buffersize
;	reserverd for these three buffers will be made configurable. At the
;	Moment 256 bytes are allocated for each.
;--------------------------------------------------------------------------
;
;	CopyName (local Routine)
;
;	Copy file/directory name from buffer at X to NameBuffer. The buffer at
;	X is assumed to contain a combined path to a file or a directory with
;	file/directory name separators. CopyName will copy up to the next 
;	separator, null or carriage return, whichever occurs first. This
;	function is supposed to be called successively to scan and process
;	a path.
;
;	Input:
;		X		Pointer to string
;		Z		Output Buffer for null terminated name element
;
;	Output:
;		X		Pointer after terminating character
;		r24		Terminating Character
;
;	Conditions:
;		T-bit cleared	Result has length 0
;		T-bit set	Result has length >0
;
;	Registers
;		none
;
;
CopyName:

	push	zl
	push	zh
	ldi	zl, low(NameBuffer)
	ldi	zh, high(NameBuffer)
;++++
;	sts	pprint+0, xl
;	sts	pprint+1, xh
;	sts	pprint+2, zl
;	sts	pprint+3, zh
;	call	print
;	.db	CR, LF
;	;	"----+----1----+----2----+"
;	.db	"Copy Name Entry     X->0x", 0x81, 0x80, " Z->0x", 0x83, 0x82, CR, LF, 0
;----
	clt
CopyNameLoop:
	ld	r24, X+
	st	Z+, r24
	cpi	r24, DELIM
	breq	CopyNameDone
	cpi	r24, 0x0d
	breq	CopyNameDone
	cpi	r24, 0x00
	breq	CopyNameDone
	set
	rjmp	CopyNameLoop	
;
;	Note that a compare clears the carry if the result is eq
;	hence we arrive here with carry cleared
;
CopyNameDone:
	st	-Z, zero
;++++
;	in	r16, CPU_SREG		; preserve T-Bit
;	sts	pprint+0, xl
;	sts	pprint+1, xh
;	sts	pprint+2, zl
;	sts	pprint+3, zh
;	sts	pprint+4, r24
;	ldi	r17, '0'
;	bld	r17, 0
;	sts	pprint+5, r17
;	call	print
;	;	"----+----1----+----2----+"
;	.db	"Copy Name Delimiter 0x", 0x84, SPACE, CR, LF
;	.db	"T-Bit              '", 0x95, "'", CR, LF
;	.db	"Copy Name Exit      X->0x", 0x81, 0x80, " Z->0x", 0x83, 0x82, CR, LF, 0
;	out	CPU_SREG, r16
;----
	pop	zh
	pop	zl
	ret

;--------------------------------------------------------------------------
;
;	2019-01-06	Added CreatePath
;
;	Combine the current working path with a new path/file name to form
;	a fully qualified path. It is assumed that both string are valid and
;	existing paths or files respectively. E.g. have been checked using
;	Name2DirEntry, i.e. both, the working path and the new path/file
;	name must exist.
;	The function will scan the new path/file for the delimiter. If the
;	substring corresponds to ".." then it will remove the top element
;	from the working path. If it is a filename it will be added to the
;	working path. 
;	2019-07-18	Paths preceeded with DELIM are now handled as absolute paths
;			Use pointer and not location Path
;
;	Input:
;		X	Pointer to the new path/file zero terminated string
;		Z	Pointer to the current working path
;
;	Output:
;			Working path updated with 
;
;	Version 2.0
;
;	Combine input path with a new path/file name to form a fully qualified
;	path/file name. It is assumed that both string are valid and existing
;	paths or files respectively, e.g. have been checked using
;	Name2DirEntry, i.e. both, the working path and the new path/file name
;	must exist.
;
;	The function will scan the new path/file for the delimiter. If the
;	substring corresponds to ".." then it will remove the top element from
;	the input path. If it is a filename it will be added to the working
;	path. 
;
;	Input:
;	r25:r24		Pointer to base path
;	r23:r22		Pointer to file including sub-directories to add to the path
;
;	Output:
;	The input path is updated
;	
CreatePath:;(char* path, char* dir)
	push	yl
	push	yh

	movw	zh:zl, r25:r24
	movw	xh:xl, r23:r22
	
	movw	r23:r22, zh:zl		; Save pointer to current path, can't reuse
					; r25:r24 as CopyName destroys r24
	ld	r18, X			; 
	cpi	r18, DELIM		; Absolute Path?
	brne	CreatePath010		; 
	st	Z, zero			; then ignore current path 
	adiw	X, 1			; skip over leading DELIM of absolute path
	ld	r18, X			; 
	tst	r18			; Check for root
	brne	CreatePath010		; 
	rjmp	CreatePathExit		; It's the root, so we are done

CreatePath010:
;
;
;
	rcall	CopyName
	brtc	CreatePathExit		; No more
;
;	check if the element just copied is '..' 
;
	lds	r18, NameBuffer+0
	cpi	r18, '.'
	brne	CreatePath040
	lds	r18, NameBuffer+1
	cpi	r18, '.'
	brne	CreatePath040
	lds	r18, NameBuffer+2
	tst	r18
	brne	CreatePath040
;
;	Move to parent directory check if we are not at the root level.
;	If we are not at the root level and must remove the top directory
;
;	To remove the top directory we scan the current path until we reach
;	the terminating 0. When scanning the path we look for a DELIM and 
;	remember the last occurance
;
	movw	zh:zl, r23:r22
	movw	yh:yl, r23:r22		; Initialise empty path
CreatePath020:	
	ld	r18, Z+			; Scan Path
	tst	r18
	breq	CreatePath030		; Reached end of path
	cpi	r18, DELIM		; delimiter?
	brne	CreatePath020
	movw	Y, Z			; Remember delimiter
	sbiw	Y, 1
	rjmp	CreatePath020
;
;	Y points either to the last delimiter or to the empty Path
;
CreatePath030:
	st	Y, zero			; Terminate path
	cpi	r24, DELIM		; Another Path Element
	brne	CreatePathExit		; no so we are done
	rjmp	CreatePath010
;
;	need to add NameBuffer to Path
;
CreatePath040:
	movw	zh:zl, r23:r22
	ld	r18, Z
	tst	r18
	breq	CreatePath055		; Empty Path just add NameBuffer

CreatePath050:
	ld	r18, Z+
	tst	r18
	brne	CreatePath050
	ldi	r18, DELIM
	st	-Z, r18			; New delimiter
	adiw	Z, 1			; readjust
CreatePath055:
	ldi	yl, low(NameBuffer)
	ldi	yh, high(NameBuffer)
CreatePath060:
	ld	r18, Y+
	st	Z+, r18
	tst	r18
	brne	CreatePath060		; Copy until the end of the element
	cpi	r24, DELIM		; Another command element?
	breq	CreatePath010		; Yes process it
;
CreatePathExit:
	pop	yh
	pop	yl
	ret

;--------------------------------------------------------------------------
;
;	Match filename
;		Y		Pointer to datastructure setup to read a directory
;				entry (e.g. after calling ReadDir)
;		NameBuffer	null terminate filename
;
;	Completioncode:
;		CC		entry matches filename
;		CS		entry does not match
;
;	Registers:
;		r18
;
;
;	Alternate entry:
;
;	This entry will copy back the found real filename to the buffer which
;	pointer is stored at P_DirName of the datastructure. The name is not
;	zero terminated, so in case you need a zero terminated string you must
;	clear the buffer in advance. This feature is normally used by the 
;	Name2DirEntry function to update inline the given path with the real
;	filenames. This is because filenames are case insensitive but sometimes
;	we want to give feedback to the user with the as it is stored in the
;	directory with the correct case. One example is the "pwd" print working
;	directory command.
;
;	Version 2.0
;
;	r25:r24	Volume Control Block
;	Uses global Buffer LongFileN
;	Completion Code in r24
;	no alternative entry, always updates the input with the real name on disk
;
;
MatchFileName:;uint8_t (struct* VolumeControlBlock);
	push	yl
	push	yh
	movw	yh:yl, r25:r24
;++++
;	ldi	xl, low(NameBuffer)
;	ldi	xh, high(NameBuffer)	; Get pointer to the name to match
;	call	print
;	.db	CR, LF, "MatchFileName '", 0
;debugMatchFileName010:
;	ld	r24, X+
;	cpi	r24, NULL
;	breq	debugMatchFileName020
;	call	serout
;	rjmp	debugMatchFileName010
;debugMatchFileName020:
;	call	print
;	.db	"'", CR, LF, 0
;	
;debugMatchFileName030:
;	ldd	r16, Y+Vol_UpdatePtr+0
;	ldd	r17, Y+Vol_UpdatePtr+1
;	sts	pprint+0, r16
;	sts	pprint+1, r17
;	ldd	zl, Y+Vol_diriob+0
;	ldd	zh, Y+Vol_diriob+1
;	ldd	r16, Z+P_Cluster+0
;	ldd	r17, Z+P_Cluster+1
;	ldd	r18, Z+P_Cluster+2
;	ldd	r19, Z+P_Cluster+3
;	sts	pprint+2, r16
;	sts	pprint+3, r17
;	sts	pprint+4, r18
;	sts	pprint+5, r19
;	call	print
;	.db	TAB, "DirName Pointer. 0x", 0x81, 0x80, CR, LF
;	.db	TAB, "Cluster......... 0x", 0x85, 0x84, 0x83, 0x882, CR, LF
;	.dw	NULL
;debugMatchFileName040:
;debugMatchFileName050:
;----
;
;
	ldi	xl, low(NameBuffer)
	ldi	xh, high(NameBuffer)	; Get pointer to the name to match
	ldd	r18, Y+Vol_Status
	sbrs	r18, Vol__Long
	rjmp	MatchSFN		; Match Short File Name
	
	ldi	zl, low(LongFileN)
	ldi	zh, high(LongFileN)	; Get pointer to long file name

MatchFilelLoop:
	ld	r18, X+			; Get character from name buffer
	ld	r19, Z+			; Get character from long file name
	ucase	r18
	ucase	r19			; Convert to upper case
	cp	r18, r19		; Compare the two characters
	brne	MatchFileFNF		; ->file not found
	tst	r18			; did we reach the end of the name
	brne	MatchFilelLoop		; no, do next character
	clr	r24			; SUCCESS
	ldi	zl, low(LongFileN)
	ldi	zh, high(LongFileN)
	ldd	xl, Y+Vol_UpdatePtr+0
	ldd	xh, Y+Vol_UpdatePtr+1
MatchFileUpdateL:
	ld	r18, Z+
	cpi	r18, 0			; if .eq. clears carry
	breq	MatchFileFin
	st	X+, r18
	rjmp	MatchFileUpdateL

MatchFileFNF:				; Match File-not-found
	ldi	r24, FAT_FNF
MatchFileFin:
	pop	yh
	pop	yl
	ret
;
;	Match short filename 
;
MatchSFN:
	ldd	zl, Y+Vol_DirPointer+0
	ldd	zh, Y+Vol_DirPointer+1
	ldi	r24, FAT_FNF		; Asssume File not found
	ldi	r17, 8			; 8 character name
MatchSFNName:
	ld	r18, X+			; Get next input filename character
	ldd	r16, Z+D_Name		; Get next directory filename character
	adiw	Z, 1			; Adjust pointer
	cpi	r16, 0x20		; blank
	breq	MatchSFNDot		; Then next might be a dot
	ucase	r18			; Convert input character
	cp	r16, r18		; EQ?
	brne	MatchSFNFin		; file not found
	dec	r17			; Next name character
	brne	MatchSFNName		;
	ld	r18, X+
MatchSFNDot:
	ldd	zl, Y+Vol_DirPointer+0
	ldd	zh, Y+Vol_DirPointer+1
;	
;	The Name part matches the input filename. Now we have various
;	possibilities
;
;	First byte of extension is a space and we have reached end of file -> match
;	First byte of extension is not a space and we have a .	-> possible match
;
	ldd	r16, Z+D_Ext		;
	cpi	r16, 0x20		; no extension?
	breq	MatchSFNNull		; then we must have reached end of input file
	cpi	r18, '.'		; we have an extension so we need a dot
	brne	MatchSFNFin		; no match
	ldi	r17, 3			; Compare extension
MatchSFNExt:
	ld	r18, X+
	ldd	r16, Z+D_Ext
	adiw	Z, 1
	cpi	r16, 0x20		; blank
	breq	MatchSFNNull		; Then must be end of input filename
	ucase	r18
	cp	r16, r18
	brne	MatchSFNFin	
	dec	r17
	brne	MatchSFNExt
	ld	r18, X+
MatchSFNNull:
	tst	r18
	brne	MatchSFNFin
MatchSFNFound:
	clr	r24			; SUCCESS
	ldd	zl, Y+Vol_DirPointer+0
	ldd	zh, Y+Vol_DirPointer+1
	ldd	xl, Y+Vol_UpdatePtr+0
	ldd	xh, Y+Vol_UpdatePtr+1

	ldi	r17, 8
MatchSFNFound010:
	ld	r16, Z+
	cpi	r16, ' '
	breq	MatchSFNFound020
	st	X+, r16
	dec	r17
	brne	MatchSFNFound010

MatchSFNFound020:
	ld	r16, Z+
	cpi	r16, ' '
	breq	MatchSFNFin
	ldi	r18, '.'
	st	X+, r18
	st	X+, r16

	ld	r16, Z+
	cpi	r16, ' '
	breq	MatchSFNFin
	st	X+, r16

	ld	r16, Z+
	cpi	r16, ' '
	breq	MatchSFNFin
	st	X+, r16
MatchSFNFin:
	pop	yh
	pop	yl
	ret
;--------------------------------------------------------------------------
;
;	Name2DirEntry
;
;	This function takes a pointer to a path name. It walks through the 
;	path and checks if the name exists in the current directory. For this
;	the path is split into individual file names by scanning the path for
;	a delimiter (DELIM).
;	-	If the name is not found it will return a file not found error. 
;	-	If the name found is a normal filename and the name is not the
;		last name in the path it will return a not a directory error
;	-	If the name found is a directory and is not the last name it will 
;		take the next name and search for it in the new directory
;	-	If the end of the path has been reached it will return success, in
;		this case P_Cluster in the Vol_diriob parameter block will be set
;		to the start cluster of the last file found and Vol_DirPointer will
;		be set to the directory entry in the buffer used for directory IO.
;		Note that when the root directory has been requested P_Cluster and
;		Vol_DirPointer will be set to zero
;
;	The search will start with the current directory. The current directory
;	is defined as the start cluster of the directory stored in Vol_DirCluster.
;	To do this it will first copy Vol_DirClsuter to P_Cluster in the Vol_diriob 
;	Parameter block. However if the path is an absolute path the search will
;	start using the root directory
;
;	-	Vol_UpdatePtr	Pointer to the current name
;	-	Vol_DirPointer	Pointer to the directory entry
;
;
;	Input:
;		r25:r24	Pointer to Volume Control Block
;		r23:r22	Pointer to Path
;
Name2DirEntry:; uint8_t Name2DirEntry(struct* VolumeControlBlock, char* name)
	push	r6
	push	r7			; Intermediate storage for CopyName pointer
	push	yl
	push	yh
	
	movw	r7:r6, r23:r22
	movw	yh:yl, r25:r24
;++++
;	movw	xh:xl, r7:r6
;	call	print
;	.db	CR, LF, "Name2DirEntry '", 0
;debugName2DirEntry010:
;	ld	r24, X+
;	cpi	r24, NULL
;	breq	debugName2DirEntry020
;	call	serout
;	rjmp	debugName2DirEntry010
;debugName2DirEntry020:
;	call	print
;	.db	"'", CR, LF, 0
;----
;
;	Prepare the starting point
;
	ldd	r16, Y+Vol_DirCluster+0	; Assume relative path 
	ldd	r17, Y+Vol_DirCluster+1
	ldd	r18, Y+Vol_DirCluster+2
	ldd	r19, Y+Vol_DirCluster+3

	movw	xh:xl, r7:r6		; Get Name Pointer
	ld	r24, X			; Check for absolute path
	cpi	r24, DELIM		
	brne	Name2DirRel		; it is a realtive path
	adiw	xh:xl, 1		; Adjust pointer to rest of the name
	movw	r7:r6, xh:xl		; Save Pointer
	clr	r16			; so we need to start at the root directory
	clr	r17
	clr	r18
	clr	r19
	ld	r24, X
	cpi	r24, NULL
	brne	Name2DirRel
	std	Y+Vol_DirPointer+0, zero
	std	Y+Vol_DirPointer+1, zero
	
Name2DirRel:

	ldd	zl, Y+Vol_diriob+0	; io parameter block for directory IO
	ldd	zh, Y+Vol_diriob+1
	std	Z+P_Cluster+0, r16	; start cluster for name lookup
	std	Z+P_Cluster+1, r17
	std	Z+P_Cluster+2, r18
	std	Z+P_Cluster+3, r19

Name2DirEntry000:
	movw	xh:xl, r7:r6		; Get Name Pointer
	std	Y+Vol_UpdatePtr+0, xl	; Save current position as update pointer for
	std	Y+Vol_UpdatePtr+1, xh	; MatchFileName
	rcall	CopyName		; Copy a file/directory name
	movw	r7:r6, xh:xl		; Save Pointer
	brtc	Name2DirEntryDone	; Rest of name is empty -> done
;++
	push	r24			; Save end character
	rcall	Name2ChkRoot		; Skip .. in path when we are
	brcs	Name2DirEntry030	; at root
	movw	r25:r24, yh:yl
	rcall	OpenDir			; Open the directory
;	tst	r24
;	breq	Name2DirEntryfnf
Name2DirEntry010:
	movw	r25:r24, yh:yl
	rcall	ReadDir			; Read Directory Entry
	tst	r24
	brne	Name2DirEntryfnf	; End of Directory reached
	movw	r25:r24, yh:yl
	rcall	MatchFileName		; Compare Entry with Name
	tst	r24
	brne	Name2DirEntry010	; Not this one
	ldd	zl, Y+Vol_DirPointer+0	; Directory found
	ldd	zh, Y+Vol_DirPointer+1
	ldd	r18, Z+D_Attr
	sbrs	r18, A_Directory
	rjmp	Name2DirEntrynad	; this is not a directory, check if ok

	ldd	r16, Z+D_Cluster+0	; Get start cluster of directory 
	ldd	r17, Z+D_Cluster+1	;
	clr	r18
	clr	r19			; Assume FAT16
	ldd	r21, Y+Vol_Status
	sbrs	r21, Vol__FAT32
	rjmp	Name2DirEntry020
	ldd	r18, Z+D_ClusterH+0	; Upper 16-bits in case of FAT32
	ldd	r19, Z+D_ClusterH+1
Name2DirEntry020:
	ldd	zl, Y+Vol_diriob+0
	ldd	zh, Y+Vol_diriob+1
	std	Z+P_Cluster+0, r16	; start cluster
	std	Z+P_Cluster+1, r17
	std	Z+P_Cluster+2, r18
	std	Z+P_Cluster+3, r19
Name2DirEntry030:
	pop	r24
;--
	cpi	r24, DELIM		; Is there potentially another name?
	breq	Name2DirEntry000	; then proceed with next name
Name2DirEntryDone:
	clr	r24
Name2DirEntryExit:
	pop	yh
	pop	yl
	pop	r7
	pop	r6
	ret
;
;	Current name is not a directory, so we cannot proceed, therefore check
;	if this is the last name element
;
Name2DirEntrynad:
	pop	r24			; restore delimiter
	cpi	r24, CR			; 
	breq	Name2DirEntryDone
	cpi	r24, NULL
	breq	Name2DirEntryDone
	ldi	r24, FAT_NAD
;
Name2DirEntryfnf:
	pop	r24
	ldi	r24, FAT_FNF
	rjmp	Name2DirEntryExit
;
;	We cannot do a step to '..' if we are at the root
;
;	CS	if we have a step to '..' but we are already at root
;	CS	otherwise
;
Name2ChkRoot:
	ldd	r16, Y+Vol_DirCluster+0
	ldd	r17, Y+Vol_DirCluster+1
	ldd	r18, Y+Vol_DirCluster+2
	ldd	r19, Y+Vol_DirCluster+3

	subi	r16, 0
	sbci	r17, 0
	sbci	r18, 0
	sbci	r19, 0
	brne	Name2ChkRoot010		; not at root directory
	
	ldi	xl, low(NameBuffer)
	ldi	xh, high(NameBuffer)

	ld	r18, X+
	cpi	r18, '.'
	brne	Name2ChkRoot010		; not a '..' step
	ld	r18, X+
	cpi	r18, '.'
	brne	Name2ChkRoot010		; not a '..' step
	ld	r18, X+
	cpi	r18, NULL
	brne	Name2ChkRoot010		; not a '..' step even if it starts with ..
	std	Y+Vol_DirPointer+0, zero
	std	Y+Vol_DirPointer+1, zero
	sec				; at root and step is '..'
	ret

Name2ChkRoot010:
	clc
	ret

;==========================================================================
;
;	Directory Routines
;
;
; 43 74 00 78 00 74 00 00  00 FF FF 0F 00 11 FF FF  |Ct.x.t..........|
; FF FF FF FF FF FF FF FF  FF FF 00 00 FF FF FF FF  |................|
; 02 73 00 6F 00 72 00 2D  00 32 00 0F 00 11 30 00  |.s.o.r.-.2....0.|
; 32 00 30 00 31 00 31 00  32 00 00 00 35 00 2E 00  |2.0.1.1.2...5...|
; 01 5A 00 79 00 78 00 65  00 6C 00 0F 00 11 2D 00  |.Z.y.x.e.l....-.|
; 73 00 75 00 70 00 65 00  72 00 00 00 76 00 69 00  |s.u.p.e.r...v.i.|
; 5A 59 58 45 4C 2D 7E 31  54 58 54 20 00 B4 90 71  |ZYXEL-~1TXT ...q|
; 79 51 7A 51 00 00 90 71  79 51 C4 72 5F 40 02 00  |yQzQ...qyQ.r_@..|
;
;--------------------------------------------------------------------------
;
;	Open Directory
;
;	Opens the current directory, it will prepare all pointers and 
;	counters to start reading directory entries. 
;	P_Cluster of Vol_diriob must be set to the first cluster of the
;	directory. In case you want to open the ROOT directory P_Cluster must
;	be set to zero. 
;
; uint8_t OpenDir
;
OpenDir:;(struct* VolumeControlBlock);
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldi	r24, FAT_OFL
	ldd	r20, Y+Vol_Status
	sbrs	r20, Vol__MBR
	rjmp	OpenDirExit		; MBR not ok -> error
	sbrs	r20, Vol__VBR                                       
	rjmp	OpenDirExit		; VBR not ok -> error	
	
	ldd	zl, Y+Vol_diriob+0
	ldd	zh, Y+Vol_diriob+1
	
	ldd	r16, Z+P_Cluster+0	; Test if ROOT directory requested
	ldd	r17, Z+P_Cluster+1
	ldd	r18, Z+P_Cluster+2
	ldd	r19, Z+P_Cluster+3
	
	subi	r16, 0
	sbci	r17, 0
	sbci	r18, 0
	sbci	r19, 0
	brne	OpenDirCluster		; Directory is a linked list of clusters

	ldd	r16, Y+Vol_rootdir+0	; Get the start of the root directory
	ldd	r17, Y+Vol_rootdir+1
	ldd	r18, Y+Vol_rootdir+2
	ldd	r19, Y+Vol_rootdir+3

	sbrs	r20, Vol__FAT32
	rjmp	OpenRootDir		; Special Case FAT16
	
	std	Z+P_Cluster+0, r16	; In case of FAT32 this is also just a linked
	std	Z+P_Cluster+1, r17	; list of clusters
	std	Z+P_Cluster+2, r18
	std	Z+P_Cluster+3, r19
OpenDirCluster:
	movw	r23:r22, yh:yl		; Volume Control Block
	movw	r25:r24, zh:zl		; Parameter Block
	rcall	Cluster2Sector		; Convert Cluster to Sector
	ldd	zl, Y+Vol_diriob+0	; Restore Parameter Block Address
	ldd	zh, Y+Vol_diriob+1
	ldd	r18, Y+Vol_Status
	sbr	r18, 1<<Vol__Linked
	std	Y+Vol_Status, r18	; Directory is a linked list of clusters
	ldd	r18, Y+Vol_sectperclst	; Number of Sectors in Cluster
	rjmp	OpenDirAll

OpenRootDir:
	std	Z+P_Sector+0, r16	; In case of FAT16 the root directory is just
	std	Z+P_Sector+1, r17	; a contiguous block of sectors
	std	Z+P_Sector+2, r18
	std	Z+P_Sector+3, r19
	ldd	r18, Y+Vol_Status
	cbr	r18, 1<<Vol__Linked
	std	Y+Vol_Status, r18	; Directory is just a block of sectors
	ldd	r18, Y+Vol_dirsectors	; Number of Sectors in Root Directory	
OpenDirAll:	
	std	Z+P_NumSect, r18	; Number of sectors
	ldi	r18, -1
	std	Y+Vol_DirCount, r18	; Directory entries processed -1 
	ldd	r18, Z+P_Address+0
	ldd	r19, Z+P_Address+1
	std	Y+Vol_DirNxtPtr+0, r18	; Set address of next directory entry to check
	std	Y+Vol_DirNxtPtr+1, r19
	movw	r25:r24, zh:zl
;-	rcall	debugOpenDirAll;++++
	call	SD_CARD_READ		; Get first sector of directory
OpenDirExit:
	pop	yh
	pop	yl
	ret
;--------------------------------------------------------------------------
;
;	Read Directory Entry and returns a pointer either to the next active
;	or free directory entry if one exists. If no free directory entry
;	exists the pointer is set to zero. To read a directory first call
;	OpenDir with the P_Cluster set to the first cluster of the directory
;	file (or 0 in case you want to read the root directory). OpenDir and
;	ReadDir automatically handle the special case of FAT16 root directory.
;
;	For vfat long file names ReadDir will compose the long file name
;	into the global LongFileN buffer.
;
;	ReadDir will return the pointer to the 32-byte directory that has
;	the file information (Date, Time, Short File Name, Start Cluster, etc.)
;	in Vol_DirPointer 
;
;	Input:
;	r25:r24		Volume Control Block
;
; uint8_t ReadDir
;
ReadDir:;(struct* VolumeControlBlock);
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldd	zl, Y+Vol_diriob+0
	ldd	zh, Y+Vol_diriob+1
;-	rcall	debugReadDir;+++
	ldd	r18, Y+Vol_Status
	cbr	r18, 1<<Vol__Long
	std	Y+Vol_Status, r18	; No Long File Name so far
ReadDirEntry:
;-	rcall	debugReadDirEntry;++++
	ldd	r18, Y+Vol_DirCount	; Get number of entries already processed
	inc	r18			; Another entry processed
	std	Y+Vol_DirCount, r18
	cpi	r18, (512/32)		; 
	brne	ReadDirThis
;ReadNxtDir:				; We require the next sector of the direcotry
;-	rcall	debugReadNxtDir;++++
	ldd	r18, Z+P_NumSect	; Decrement sectors to read
	dec	r18			; done in directory
	std	Z+P_NumSect, r18	; 
	brne	ReadNxtDirSect		; Just read the next sector (P_Sector++)
	ldd	r18, Y+Vol_Status	; Check directory type
	sbrs	r18, Vol__Linked	; Linked list of clusters (normal file)
	rjmp	ReadNxtDirEnd		; In case of FAT16 root directory no more sectors
;
;	Either a normal directory or the FAT32 root directory is being processed which
;	are built like any file as a list of linked clusters. We reach here when we have
;	processed all sectors in the current cluster so we need to find the next cluster.
;
	movw	r25:r24, zh:zl
	movw	r23:r22, yh:yl
	rcall	LinkedCluster		; Follow Cluster List
	tst	r24
	brne	ReadNxtDirEnd
	ldd	r24, Y+Vol_diriob+0
	ldd	r25, Y+Vol_diriob+1	; Restore IO Parameter Block Pointer
	movw	r23:r22, yh:yl
	rcall	Cluster2Sector
	ldd	zl, Y+Vol_diriob+0
	ldd	zh, Y+Vol_diriob+1	; Restore IO Parameter Block Pointer
	ldd	r18, Y+Vol_sectperclst	; Re-initialise number of 
	std	Z+P_NumSect, r18	; sectors in cluster.
;-	rcall	debugReadNXtDir2;++++
	rjmp	ReadNxtReadSect
;
;	Read next directory sector of the current cluster or FAT16 root directory
;
ReadNxtDirSect:
	ldd	r16, Z+P_Sector+0
	ldd	r17, Z+P_Sector+1
	ldd	r18, Z+P_Sector+2
	ldd	r19, Z+P_Sector+3

	subi	r16, byte1(-1)
	sbci	r17, byte2(-1)
	sbci	r18, byte3(-1)
	sbci	r19, byte4(-1)

	std	Z+P_Sector+0, r16
	std	Z+P_Sector+1, r17
	std	Z+P_Sector+2, r18
	std	Z+P_Sector+3, r19
ReadNxtReadSect:
;-	rcall	debugReadNxtDirSect;++++
	ldi	r18, -1
	std	Y+Vol_DirCount, r18	; No directory entries in sector processed
	ldd	r16, Z+P_Address+0
	ldd	r17, Z+P_Address+1
	std	Y+Vol_DirNxtPtr+0, r16
	std	Y+Vol_DirNxtPtr+1, r17
	movw	r25:r24, zh:zl
	call	SD_CARD_READ
	ldd	zl, Y+Vol_diriob+0
	ldd	zh, Y+Vol_diriob+1
	tst	r24
	breq	ReadDirEntry		; Re-enter
ReadNxtDirEnd:
	std	Y+Vol_DirPointer+0, zero	
	std	Y+Vol_DirPointer+1, zero
	rjmp	ReadNxtDirExit	

ReadDirThis:
	ldd	zl, Y+Vol_DirNxtPtr+0
	ldd	zh, Y+Vol_DirNxtPtr+1	; Get pointer to next entry
	std	Y+Vol_DirPointer+0, zl	; save current pointer as directory entry
	std	Y+Vol_DirPointer+1, zh	; 
	ldi	r24, FAT_FDE		; Assume Free Directory Entry
	ldd	r18, Z+D_Name		; Get first character of Name
	tst	r18			; Check if this is the end of the directory
	breq	ReadNxtDirExit		; if yes return the pointer to the free entry
	cpi	r18, 0xe5
	breq	ReadDirNext		; This is a deleted entry, skip it
	ldd	r18, Z+D_Attr		; is it part of a long filename
	cpi	r18, A_Long		; Attribute for Long File Name
	breq	ReadDirLong
	adiw	zh:zl, 32		; Next Entry Address
	std	Y+Vol_DirNxtPtr+0, zl	; New place for this pointer
	std	Y+Vol_DirNxtPtr+1, zh
	clr	r24			; Success

ReadNxtDirExit:
	pop	yh
	pop	yl
	ret

ReadDirNext:
	adiw	zh:zl, 32		; Next Entry Address
	std	Y+Vol_DirNxtPtr+0, zl	; Save for next entry to this routine
	std	Y+Vol_DirNxtPtr+1, zh
	ldd	zl, Y+Vol_diriob+0
	ldd	zh, Y+Vol_diriob+1
	rjmp	ReadDirEntry
;
;	We found an entry with the attributes indicating a long file name
;
;	Long file names are stored in blocks of 13 characters. The last part of the
;	filename is stored first. Each block takes one directory entry. For long file
;	name entries the attribute is set to 0x0F and the first byte of the name
;	consists of the sequence number (bits 0..4) and allocation status (bit 6).
;	Bit 6 of the last block is set and as the blocks store the filename from then
;	end to the beginning bit 6 indicates the last block of a file name and at the
;	same time the highest sequence number
;
ReadDirLong:				; Process a long filename entry
	ldd	r18, Y+Vol_Status
	sbrc	r18, Vol__Long		; Are we already processing long file names
	rjmp	ReadDirLongCont		; If set then continue with long filename
	sbr	r18, 1<<Vol__Long	; We start processing of long filenames
	std	Y+Vol_Status, r18
	ldd	r18, Z+D_Name		; Get the sequence number and allocation status
	sbrs	r18, 6			; We expect this to be the last entry
	rjmp	ReadDirNext		; Something is wrong with directory, skip it
	clr	r18
	ldi	xl, low(LongFileN)
	ldi	xh, high(LongFileN)
ReadDirLongClr:
	st	X+, zero
	inc	r18
	brne	ReadDirLongClr		; Initialise long filename buffer with 0x00
	rjmp	ReadDirCopy
ReadDirLongCont:
	ldd	r18, Z+D_Name		; We are already processing long file names
	sbrc	r18, 6			; and therefore the allocation status must be 0
	rjmp	ReadDirNext		; If "Last" flag set this is an error, skip it
ReadDirCopy:
;
;	Copy the characters from a long filename directory entry to the long
;	filename buffer. Long filenames are split into directory entires each
;	with up to 13 double-byte characters. The first byte if the filename
;	has the index of the part. So we just need to multiply the index minus
;	one with 13 and copy the 13 characters. Note we assume it is all
;	ASCII, that is the highbyte of each double-byte character is 0. We do
;	not even check as this would also require that we are able to support
;	this but we are not for the moment. 
;
	ldd	r18, Z+D_Name		; get first byte of filename which 
	andi	r18, 0x1F		; contains the index, isolate the index
	dec	r18			; Sequence - 1
	clr	r19
ReadDirCopy010:
	dec	r18
	brmi	ReadDirCopy020
	subi	r19, -13
	rjmp	ReadDirCopy010
ReadDirCopy020:	
	ldi	xl, low(LongFileN)
	ldi	xh, high(LongFileN)
	add	xl, r19
	adc	xh, zero
;-	rcall	debugReadDirCopy;++++
	ldd	r18, Z+D_Name+1		; copy the 13 locations, note that the
	st	X+, r18			; string in the extension is 0x0000 terminated
	ldd	r18, Z+D_Name+3		; we assume only ASCII double characeters
	st	X+, r18
	ldd	r18, Z+D_Name+5
	st	X+, r18
	ldd	r18, Z+D_Name+7
	st	X+, r18
	ldd	r18, Z+D_Name+9
	st	X+, r18
	ldd	r18, Z+D_Name+14
	st	X+, r18
	ldd	r18, Z+D_Name+16
	st	X+, r18
	ldd	r18, Z+D_Name+18
	st	X+, r18
	ldd	r18, Z+D_Name+20
	st	X+, r18
	ldd	r18, Z+D_Name+22
	st	X+, r18
	ldd	r18, Z+D_Name+24
	st	X+, r18
	ldd	r18, Z+D_Name+28
	st	X+, r18
	ldd	r18, Z+D_Name+30
	st	X+, r18
	rjmp	ReadDirNext

debugReadDir:
	ldd	r21, Z+P_NumSect
	sts	pprint+0, r21
	call	print
	.db	CR, LF
		;----+----1----+----2----+----3
	.db	"ReadDir P_NumSect.......... 0x", 0x80, CR, LF, 0
	ret
	
debugReadDirEntry:
	ldd	r21, Y+Vol_DirCount
	sts	pprint+0, r21
	call	print
		;----+----1----+----2----+----3
	.db	"ReadDirEntry Vol_DirCount.. 0x", 0x80, CR, LF, 0
	ret

debugReadNxtDir:
	ldd	r21, Z+P_NumSect
	sts	pprint+0, r21
	sts	pprint+2, zl
	sts	pprint+3, zh
	call	print
		;----+----1----+----2----+----3
	.db	"ReadNxtDir IOB............. 0x", 0x83, 0x82, CR, LF
	.db	"ReadNxtDir P_NumSect......  0x", 0x80, CR, LF, 0
	ret

debugOpenDirAll:
	ldd	r21, Z+P_Sector+0
	sts	pprint+0, r21
	ldd	r21, Z+P_Sector+1
	sts	pprint+1, r21
	ldd	r21, Z+P_Sector+2
	sts	pprint+2, r21
	ldd	r21, Z+P_Sector+3
	sts	pprint+3, r21
	ldd	r21, Z+P_NumSect
	sts	pprint+4, r21
	call	print
		;----+----1----+----2----+----3
	.db	"OpenDirAll P_Sector........ 0x", 0x83, 0x82, 0x81, 0x80, CR, LF
	.db	"OpenDirAll P_NumSect......  0x", 0x84, CR, LF, 0
	ret
	
debugReadNxtDirSect:
	ldd	r21, Z+P_Sector+0
	sts	pprint+0, r21
	ldd	r21, Z+P_Sector+1
	sts	pprint+1, r21
	ldd	r21, Z+P_Sector+2
	sts	pprint+2, r21
	ldd	r21, Z+P_Sector+3
	sts	pprint+3, r21
	call	print
		;----+----1----+----2----+----3
	.db	"ReadNxtDirSect P_Sector.... 0x", 0x83, 0x82, 0x81, 0x80, CR, LF, 0, 0
	ret

debugReadNXtDir2:
	ldd	r21, Z+P_Sector+0
	sts	pprint+0, r21
	ldd	r21, Z+P_Sector+1
	sts	pprint+1, r21
	ldd	r21, Z+P_Sector+2
	sts	pprint+2, r21
	ldd	r21, Z+P_Sector+3
	sts	pprint+3, r21
	call	print
		;----+----1----+----2----+----3
	.db	"Cluster2Sector P_Sector.... 0x", 0x83, 0x82, 0x81, 0x80, CR, LF, 0, 0
	ret

debugReadDirCopy:
	sts	pprint+0, r19
	call	print
		;----+----1----+----2----+----3
	.db	"ReadDirCopy Name Offset...  0x", 0x80, CR, LF, 0
	ret

;--------------------------------------------------------------------------
;
;	Extension to allow creation and extension of files
;
;	uint32_t FindFreeCluster(uint32_t numclusters, uint32_t minfragment)
;
;		Find a given number of consecutive clusters, chain them 
;		and return the first cluster
;
;	uint8_t LinkCluster(uint32_t cluster, uint32_t nextcluster)
;
;		Link a cluster to another cluster
;
;	AddDirEntry
;
;		Add a directory entry
;
;
;
;
;