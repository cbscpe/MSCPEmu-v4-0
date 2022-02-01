;--------------------------------------------------------------------------
;
;	File IO Primitives
;	
;--------------------------------------------------------------------------
;
;	Open File for Read access
;
;	Create a file control block with IO Parameter and IO buffer
;	initialise the file control block and read first sector
;
;	In order to open a file you must first use Name2DirEntry to
;	find the corresponding file by name.
;
;	Version 2.0
;
;	Input:
;
;	r25:r24		Volume Control Block
;
;	Output:
;
;	r25:r24		return code for uint16_t < 256.
;	r25:r24		File Control Block for uint16_t >= 256.
;
;-----------------------------------------------------------------------------
;
;	ReadFileOpen
;
;	It is assumed that the file has already been located and found
;	using Name2DirEntry and Vol_DirPointer points to the directory
;	entry of the file to open.
;

ReadFileOpen:;fcb* ReadFileOpen(struct* VolumeControlBlock)
	push	r8
	push	r9
	push	r10
	push	r11
	push	r12
	push	r13
	push	yl
	push	yh
	movw	r9:r8, r25:r24		; Save Volume Control Block
	ldi	r24, low(fcb_size)	; Allocate memory for a file control block
	ldi	r25, high(fcb_size)
	call	malloc
	sbiw	r25:r24, 0
	brne	ReadFileOpen005
	ldi	r24, FAT_INS
	clr	r25			; if r25 = 0 then it is an error
	rjmp	ReadFileOpenExit
ReadFileOpen005:
	movw	yh:yl, r25:r24		; Y = file control block
	std	Y+fcb_volume+0, r8
	std	Y+fcb_volume+1, r9	; Link it to the volume control block
	ldi	r24, low(P_size)
	ldi	r25, high(P_size)
	call	malloc
	sbiw	r25:r24, 0
	brne	ReadFileOpen010
	movw	r25:r24, yh:yl
	call	free
	ldi	r24, FAT_INS
	clr	r25			; if r25 = 0 then it is an error
	rjmp	ReadFileOpenExit
ReadFileOpen010:
	push	r24
	push	r25
	ldi	r24, low(512)		; Allocate memory for read/write buffer
	ldi	r25, high(512)
	call	malloc
	sbiw	r25:r24, 0
	brne	ReadFileOpen015
	pop	r25
	pop	r24
	call	free
	movw	r25:r24, yh:yl
	call	free
	ldi	r24, FAT_INS
	clr	r25			; if r25 = 0 then it is an error
	rjmp	ReadFileOpenExit
ReadFileOpen015:
	pop	zh
	pop	zl			; restore to parameter block
	std	Z+P_address+0, r24	; Save buffer address to io parameter block
	std	Z+P_address+1, r25
	std	Y+fcb_iob+0, zl
	std	Y+fcb_iob+1, zh		; Save io parameter block address to fcb
	std	Y+fcb_position+0, zero	; Reset file position
	std	Y+fcb_position+1, zero
	std	Y+fcb_position+2, zero
	std	Y+fcb_position+3, zero
	
	std	Y+fcb_byteinsec+0, zero	; Reset sector position
	std	Y+fcb_byteinsec+1, zero

	ldi	r18, 1
	std	Y+fcb_sectperclst+0, r18; First sector in cluster read
	movw	r11:r10, yh:yl		; Save File Control Block

	movw	yh:yl, r9:r8		; get VCB
	ldd	zl, Y+Vol_DirPointer+0
	ldd	zh, Y+Vol_DirPointer+1	; Get directory entry pointer

	ldd	r16, Z+D_Size+0		; Get total file size 
	ldd	r17, Z+D_Size+1
	ldd	r18, Z+D_Size+2
	ldd	r19, Z+D_Size+3


	ldd	r20, Z+D_Cluster+0
	ldd	r21, Z+D_Cluster+1
	clr	r22
	clr	r23
	ldd	xl, Y+Vol_Status
	sbrs	xl, Vol__FAT32					; 
	rjmp	ReadFileOpen030			

	ldd	r22, Z+D_ClusterH+0
	ldd	r23, Z+D_ClusterH+1

ReadFileOpen030:
	movw	yh:yl, r11:r10		; Restore File Control Block
	std	Y+fcb_filesize+0, r16
	std	Y+fcb_filesize+1, r17
	std	Y+fcb_filesize+2, r18
	std	Y+fcb_filesize+3, r19	; Set File Size
	ldd	zl, Y+fcb_iob+0
	ldd	zh, Y+fcb_iob+1
	std	Z+P_Cluster+0, r20
	std	Z+P_Cluster+1, r21
	std	Z+P_Cluster+2, r22
	std	Z+P_Cluster+3, r23
	movw	r23:r22, r9:r8		; Volume control block
	movw	r25:r24, zh:zl
	call	Cluster2Sector		; Convert cluster to sector of first 
	ldd	r24, Y+fcb_iob+0
	ldd	r25, Y+fcb_iob+1
	call	SD_CARD_READ		; read the sector
	ldi	r18, (1<<F__Readonly) | (1<<F__Sequential)
	std	Y+fcb_flag, r18
	movw	r25:r24, yh:yl		; as Memory starts at 0x4000 r25 is not zero!
	ldd	zl, Y+fcb_volume+0
	ldd	zh, Y+fcb_volume+1
	ldd	r18, Z+Vol_FileCnt
	inc	r18
	std	Z+Vol_FileCnt, r18
ReadFileOpenExit:
	pop	yh
	pop	yl
	pop	r13
	pop	r12
	pop	r11
	pop	r10
	pop	r8
	pop	r9
	ret
	
;--------------------------------------------------------------------------
;
;	Close File
;
;	Input
;	
;	Y	file control block
;
;	Verions 2.0
;
;	r25:r24	file control block
WriteFileClose:
	;
	;	If there are bytes not written to the disk do so
	;
ReadFileClose:
	push	yl
	push	yh
	movw	zh:zl, r25:r24
	ldd	yl, Z+fcb_volume+0
	ldd	yh, Z+fcb_volume+1
	ldd	r18, Y+Vol_FileCnt
	dec	r18
	std	Y+Vol_FileCnt, r18
	ldd	yl, Z+fcb_iob+0
	ldd	yh, Z+fcb_iob+1
	ldd	r24, Y+P_address+0
	ldd	r25, Y+P_address+1
	push	zl
	push	zh
	call	free			; IO Buffer
	movw	r25:r24, Y
	call	free			; Parameter block
	pop	r25
	pop	r24
	call	free			; File Control block
	clr	r24			; this is always successfull
	pop	yh
	pop	yl
	ret
;--------------------------------------------------------------------------
;
;	Read One Byte from open file
;
;	Get next byte from file. 
;
;	-	Return 0x1a (^Z for end-of-file) if already all bytes read
;	-	Update file pointer
;	-	read next sector in cluster if last byte of sector already read
;	-	link to next cluster if all bytes in cluster already read
;
;	Input
;	
;	Y	file control block
;
;	Output
;
;	CS	Error
;	r16	Error Code, most important 0x1a for end-of-file
;
;	CC	Error
;	r16	Byte
;
;	Registers
;	
;	r18, r4, r5, r6, r7
;
;	Version 2.0
;	Input:
;	r25:r24	struct* filecontrolblock
;	
ReadFileByte:
;
;	First check if we already reached end-of-file
;
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldd	r20, Y+fcb_position+0	; get current posistion
	ldd	r21, Y+fcb_position+1
	ldd	r22, Y+fcb_position+2
	ldd	r23, Y+fcb_position+3	
	ldd	r16, Y+fcb_filesize+0	; compare to file size
	ldd	r17, Y+fcb_filesize+1
	ldd	r18, Y+fcb_filesize+2
	ldd	r19, Y+fcb_filesize+3
	cp	r20, r16
	cpc	r21, r17
	cpc	r22, r18
	cpc	r23, r19
	brlo	ReadFileByte010		; we still have some bytes left
	ldd	r16, Y+fcb_flag
	sbr	r16, (1<<F__EOF) | (1<<F__ERR)
	std	Y+fcb_flag, r16
	clr	r24
	rjmp	ReadFileByteExit
	
ReadFileByte010:
;
;	Next check if there is a byte left in the sector buffer
;
	subi	r20, byte1(-1)
	sbci	r21, byte2(-1)
	sbci	r22, byte3(-1)
	sbci	r23, byte4(-1)
	std	Y+fcb_position+0, r20
	std	Y+fcb_position+1, r21
	std	Y+fcb_position+2, r22
	std	Y+fcb_position+3, r23
	
	ldd	r16, Y+fcb_byteinsec+0	; get offset in sector
	ldd	r17, Y+fcb_byteinsec+1
	ldi	r18, low(512)		; reached end of sector
	ldi	r19, high(512)
	cp	r16, r18
	cpc	r17, r19
	brlo	ReadFileByte030		; no still bytes in sector
;
;	Need a new sector, as ReadFileOpen already has read the first sector
;	we need to increment the sector number first
;
	ldd	zl, Y+fcb_iob+0
	ldd	zh, Y+fcb_iob+1
	ldd	r16, Z+P_sector+0	; increment sector for next in cluster
	ldd	r17, Z+P_sector+1
	ldd	r18, Z+P_sector+2
	ldd	r19, Z+P_sector+3
	subi	r16, byte1(-1)
	sbci	r17, byte2(-1)
	sbci	r18, byte3(-1)
	sbci	r19, byte4(-1)
	std	Z+P_sector+0, r16
	std	Z+P_sector+1, r17
	std	Z+P_sector+2, r18
	std	Z+P_sector+3, r19
	ldd	r16, Y+fcb_sectperclst	; how many sectors did we already read
	ldd	zl, Y+fcb_volume+0
	ldd	zh, Y+fcb_volume+1	; Volume control block
	ldd	r17, Z+Vol_sectperclst	; compare to number of sectors in cluster
	cp	r16, r17
	brlo	ReadFileByte020		; still within current cluster
;
;	Need next cluster
;
	ldd	r22, Y+fcb_volume+0
	ldd	r23, Y+fcb_volume+1	; Volume control block
	ldd	r24, Y+fcb_iob+0
	ldd	r25, Y+fcb_iob+1	; Parameter block
	call	LinkedCluster		; get linked cluster
	ldd	r22, Y+fcb_volume+0
	ldd	r23, Y+fcb_volume+1	; Volume control block
	ldd	r24, Y+fcb_iob+0
	ldd	r25, Y+fcb_iob+1	; Parameter block
	call	Cluster2Sector		; convert cluster to sector
	clr	r16
ReadFileByte020:
	inc	r16
	std	Y+fcb_sectperclst, r16	; initialise number of sectors read
	ldd	r24, Y+fcb_iob+0
	ldd	r25, Y+fcb_iob+1
	call	SD_CARD_READ
	tst	r24
	breq	ReadFileByte025
	ldd	r16, Y+fcb_flag
	sbr	r16, (1<<F__IOE) | (1<<F__ERR)
	std	Y+fcb_flag, r16
	rjmp	ReadFileByteExit
ReadFileByte025:
	std	Y+fcb_byteinsec+0, zero
	std	Y+fcb_byteinsec+1, zero
ReadFileByte030:
	ldd	r24, Y+fcb_byteinsec+0	; get offset in sector
	ldd	r25, Y+fcb_byteinsec+1
	ldd	zl, Y+fcb_iob+0		; get io parameter block
	ldd	zh, Y+fcb_iob+1
	ldd	xl, Z+P_address+0	; get IO buffer address
	ldd	xh, Z+P_address+1
	add	xl, r24			; point to byte in question
	adc	xh, r25
	adiw	r25:r24, 1		; increment offset in sector
	std	Y+fcb_byteinsec+0, r24	; update offset in sector
	std	Y+fcb_byteinsec+1, r25
	ld	r24, X			; get byte
ReadFileByteExit:
	pop 	yh
	pop	yl
	ret	
	