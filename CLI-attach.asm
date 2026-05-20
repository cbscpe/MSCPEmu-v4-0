;--------------------------------------------------------------------------
;
;	attach <unit> <file>
;
;
attachcmd:
	push	yl
	push	yh
	lds	yl, volqueue+0
	lds	yh, volqueue+1		; get current volume
	sbiw	yh:yl, 0
	brne	attachcmd010
	call	mprint
	.dw	msgnovolume		; No Volume 
	rjmp	attachcmdexit
attachcmd010:
	rcall	checkunit		; is it a valid unit
	brcc	attachcmd020
	call	mprint
	.dw	msgattachunt		; Invalid Unit
	rjmp	attachcmdexit
attachcmd020:
	lds	zl, attunit		; get unit and convert to
	swap	zl
	clr	zh
	subi	zl, low(-unittable)
	sbci	zh, high(-unittable)	; unit control block address
	ldd	r18, Z+ucb_status
	andi	r18, (1<<ucb__file) | (1<<ucb__part)
	breq	attachcmd025
	call	mprint
	.dw	msgattachuaa		; unit already attached
	rjmp	attachcmdexit
attachcmd025:
	lds	xl, cdstring+2
	lds	xh, cdstring+3
	st	X, zero			; Zero Terminate the string
	lds	r22, cdstring+0
	lds	r23, cdstring+1		; path/file 
	movw	r25:r24, yh:yl		; volume control block
	call	Name2DirEntry		;
	tst	r24
	breq	attachcmd030		; path/file found
	call	mprint
	.dw	msgattachfnf		; File not found
	rjmp	attachcmdexit
attachcmd030:
	ldd	zl, Y+Vol_DirPointer+0
	ldd	zh, Y+Vol_DirPointer+1
	sbiw	zh:zl, 0
	breq	attachcmd040		; Just the root, this is not a file
	ldd	r18, Z+D_Attr
	sbrs	r18, A_Directory
	rjmp	attachcmd050		; path/file is a file
attachcmd040:
	call	mprint
	.dw	msgattachnaf		; path/file is not a valid file
	rjmp	attachcmdexit
attachcmd050:
	ldi	r24, low(fcb_size)	; file control block
	ldi	r25, high(fcb_size)
	call	malloc
	sbiw	r25:r24, 0
	brne	attachcmd060
	call	mprint
	.dw	msgattachfcb		; no memory to allocate fcb
	rjmp	attachcmdexit
;--------------------------------------------------------------------------
;
;	r25:r24	File Control Block	
;	Y	Volume Control Block
;
attachcmd060:
	movw	zh:zl, yh:yl		; Z	Volume Control Block
	movw	yh:yl, r25:r24		; Y	File Control Block
	ldi	r24, low(P_Size)	; IO parameter block
	ldi	r25, high(P_Size)
	call	malloc
	sbiw	r25:r24, 0
	brne	attachcmd070
	movw	r25:r24, yh:yl		; Return FCB
	call	free
	call	mprint
	.dw	msgattachiob		; no memory to allocate iob
attachcmd070:				;
	std	Y+fcb_iob+0, r24	; set IO parameter block in file control block
	std	Y+fcb_iob+1, r25
	std	Y+fcb_volume+0, zl	; store volume control block
	std	Y+fcb_volume+1, zh
	ldi	r24, low(sdbuffer)	; IO Buffer can be shared
	ldi	r25, high(sdbuffer)
	ldd	zl, Y+fcb_iob+0
	ldd	zh, Y+fcb_iob+1
	std	Z+P_address+0, r24
	std	Z+P_address+1, r25
;
;	File Size must match one of the valid images
;
	ldd	zl, Y+fcb_volume+0	
	ldd	zh, Y+fcb_volume+1
	ldd	xl, Z+Vol_DirPointer+0	; Z	Volume Control Block
	ldd	xh, Z+Vol_DirPointer+1
	movw	zh:zl, xh:xl		; Z	Directory Entry 
	ldd	r22, Z+D_Size+1		; Convert file size to number of blocks
	ldd	r23, Z+D_Size+2		; using just bits9..31 of the file size
	ldd	r24, Z+D_Size+3		; in bytes into a 32-bit integer

	clr	r25			; 
	lsr	r24			;
	ror	r23			;
	ror	r22			; 

	std	Y+fcb_filesize+0, r22	; And save to FCB as number of blocks
	std	Y+fcb_filesize+1, r23	; to report
	std	Y+fcb_filesize+2, r24
	std	Y+fcb_filesize+3, r25
	ldi	r18, (1<<F__Image)	; Assume valid image
	std	Y+fcb_flag, r18		; Initialise the flags
	call	FindDriveEntry
	std	Y+fcb_drvtab+0, r24	; Save drive tab entry returned by FindDrvEntry
	std	Y+fcb_drvtab+1, r25	; zero if no valid standard drive found
	sbiw	r25:r24, 0
	brne	attachcmd080
	std	Y+fcb_flag, zero	; not a standard image
	call	mprint
	.dw	msgattachnsd		; not a standard disk image
	rjmp	attachcmd085
attachcmd080:
;;;	movw	zh:zl, r25:r24		; We have a standard image, now we need to 
;;;
;;;	We need to come up with a logic what disk size we report. For the moment
;;;	we just use the file size
;;;
;;;	ldd	r16, Z+Drv_Type		; know what size we report
;;;	sbrs	r16, DT__DRCAP_bp	; Report Drive Capacity from Drive Tab
;;;	rjmp	attachcmd081
;;;	ldd	r16, Z+drv_Capacity+0	; if a standard file size then set 
;;;	ldd	r17, Z+drv_Capacity+1	; the number of blocks to report
;;;	ldd	r18, Z+drv_Capacity+2	; to the exact value for this drive type
;;;	ldd	r19, Z+drv_Capacity+3
;;;	cp	r22, r16
;;;	cp	r22, r16
;;;	std	Y+fcb_filesize+0, r16	; And save to FCB as number of blocks
;;;	std	Y+fcb_filesize+1, r17	; to report
;;;	std	Y+fcb_filesize+2, r18
;;;	std	Y+fcb_filesize+3, r19
;;;	rjmp	attachcmd085
;;;
;;;attachcmd081:
;;;	sbrs	r16, DT__MXCAP_bp	; Report Drive MaxCapacity from Drive Tab
;;;	rjmp	attachcmd082
;;;	ldd	r16, Z+drv_MaxCapacity+0; if a standard file size then set 
;;;	ldd	r17, Z+drv_MaxCapacity+1; the number of blocks to report
;;;	ldd	r18, Z+drv_MaxCapacity+2; to the exact value for this drive type
;;;	ldd	r19, Z+drv_MAxCapacity+3
;;;	std	Y+fcb_filesize+0, r16	; And save to FCB as number of blocks
;;;	std	Y+fcb_filesize+1, r17	; to report
;;;	std	Y+fcb_filesize+2, r18
;;;	std	Y+fcb_filesize+3, r19
;;;	rjmp	attachcmd085
;;;
;;;attachcmd082:				; DT__IMGSZ is the default and already set
;;;					;
attachcmd085:
	ldi	xl, low(Path)
	ldi	xh, high(Path)
	ldi	zl, low(LongFileN)
	ldi	zh, high(LongFileN)
attachcmd090:				; Duplicate current path
	ld	r16, X+
	st	Z+, r16
	tst	r16
	brne	attachcmd090
	
	lds	r22, cdstring+0
	lds	r23, cdstring+1		; note it already is zero-terminated
	ldi	r24, low(LongFileN)
	ldi	r25, high(LongFileN)
	call	CreatePath		; Create display path with duplicated path
	;
	; Perhaps we should CreatePath let return the length!!!!
	;
	call	print
	.db	CR, LF, "Attach - Full File Name:'", 0
	ldi	xl, low(LongFileN)
	ldi	xh, high(LongFileN)
attachcmdx10:
	ld	r24, X+
	tst	r24
	breq	attachcmdx20
	call	serout
	rjmp	attachcmdx10
attachcmdx20:
	call	print
	.db	"'", CR, LF, 0	
	;
	;----------------------------------
	;
	ldi	xl, low(LongFileN)
	ldi	xh, high(LongFileN)
	ldi	r24, low(1)
	ldi	r25, high(1)		; to compensate for even block size
attachcmd100:	
	ld	r18, X+
	adiw	r25:r24, 1		;
	tst	r18
	brne	attachcmd100

	andi	r24, 0xFE		; make it even	
	call	malloc
	std	Y+fcb_filename+0, r24
	std	Y+fcb_filename+1, r25
	sbiw	r25:r24, 0
	brne	attachcmd110
	call	mprint
	.dw	msgattachnfn		; no memory to allocate filename buffer
	rjmp	attachcmd130
attachcmd110:
	ldi	xl, low(LongFileN)
	ldi	xh, high(LongFileN)
	movw	zh:zl, r25:r24
attachcmd120:
	ld	r18, X+
	st	Z+, r18
	tst	r18
	brne	attachcmd120

attachcmd130:
	ldd	zl, Y+fcb_volume+0
	ldd	zh, Y+fcb_volume+1
	ldd	r20, Z+Vol_status	; Z	Volume Control Block
	ldd	xl, Z+Vol_DirPointer+0
	ldd	xh, Z+Vol_DirPointer+1
	movw	zh:zl, xh:xl		; Z	Directory Entry
	ldd	r16, Z+D_Cluster+0
	ldd	r17, Z+D_Cluster+1	; Copy lower 16-bit of clusternumber
	clr	r18
	clr	r19
	sbrs	r20, Vol__FAT32
	rjmp	attachcmd140
	ldd	r18, Z+D_ClusterH+0
	ldd	r19, Z+D_ClusterH+1	; 32-bit if its FAT-32
attachcmd140:
	ldd	zl, Y+fcb_iob+0
	ldd	zh, Y+fcb_iob+1		; Get io parameter block
	std	Z+P_Cluster+0, r16	; set start cluster
	std	Z+P_Cluster+1, r17
	std	Z+P_Cluster+2, r18
	std	Z+P_Cluster+3, r19
	movw	r25:r24, yh:yl		; File Control Block
	call	BuildFragList		;
	tst	r24
	breq	attachcmd200		; 
;
;	unwind allocated buffers as we could not build a fragment list
;
	call	mprint
	.dw	msgattachfrg		; not enough memory to hold fragment list

	ldd	r24, Y+fcb_filename+0
	ldd	r25, Y+fcb_filename+1
	sbiw	r25:r24, 0
	breq	attachcmd150
	call	free
attachcmd150:
	ldd	r24, Y+fcb_iob+0
	ldd	r25, Y+fcb_iob+1
	call	free
	movw	r25:r24, yh:yl
	call	free	
	rjmp	attachcmdexit
;
;	Y has a valid file descriptor block 
;
attachcmd200:
	ldd	xl, Y+fcb_filename+0	; Print full path name
	ldd	xh, Y+fcb_filename+1
	sbiw	xh:xl, 0
	breq	attachcmd230
	ldi	r24, DELIM
	call	serout
attachcmd210:
	ld	r24, X+
	tst	r24
	breq	attachcmd220
	call	serout
	rjmp	attachcmd210
attachcmd220:
	call	seroutcrlf
attachcmd230:
;	call	printfraglist		; print fragments info
	ldd	r18, Y+fcb_flag
	sbrs	r18, F__Image		; check if it was a valid image
	rjmp	detachunitfile		; no, so we need to deallocate everything
	ldd	zl, Y+fcb_drvtab+0	; get drive table entry
	ldd	zh, Y+fcb_drvtab+1
	ldd	r18, Z+drv_type
	ldd	r19, Z+drv_flags
	lds	zl, attunit		; get unit and convert to
	swap	zl
	clr	zh
	subi	zl, low(-unittable)
	sbci	zh, high(-unittable)	; unit control block address
	std	Z+ucb_type, r18		; Set drive type
	std	Z+ucb_flags, r19
	ldi	r18, (1<<ucb__drdy) | (1<<ucb__file)
	std	Z+ucb_status, r18	; Set status
	std	Z+ucb_diskaddr+0, zero	; Set current disk address
	std	Z+ucb_diskaddr+1, zero
	std	Z+ucb_imgptr+0, yl	; Link file control block
	std	Z+ucb_imgptr+1, yh
attachcmdexit:
	clc
	pop	yh
	pop	yl
	ret
;--------------------------------------------------------------------------
;
;	attach <unit> <partition>
;
attachpar:
	push	yl
	push	yh
	lds	zl, attunit		; get unit and convert to
	cpi	zl, units
	brlo	attachpar005
	ori	zl, '0'	
	sts	pprint+0, zl
	call	mprint
	.dw	msgattachinv		; invalid unit
	clc
	rjmp	detachunitexit

attachpar005:
	swap	zl
	clr	zh
	subi	zl, low(-unittable)
	sbci	zh, high(-unittable)	; unit control block address
	ldd	r18, Z+ucb_status
	andi	r18, (1<<ucb__file) | (1<<ucb__part)
	breq	attachpar010
	call	mprint
	.dw	msgattachuaa		; unit already attached
	clc
	rjmp	attachcmdexit
attachpar010:
	lds	r24, attpart
	rcall	findpart
	adiw	r25:r24, 0
	breq	attachpar090
	movw	yh:yl, r25:r24
	ldd	r18, Y+pcb_status
	sbrc	r18, pcb__attach
	rjmp	attachpar091
	sbrc	r18, pcb__idle
	rjmp	attachpar092
	sbr	r18, (1<<pcb__attach)
	std	Y+pcb_status, r18
	ldd	zl, Y+pcb_drvtab+0
	ldd	zh, Y+pcb_drvtab+1
	ldd	r18, Z+Drv_Type
	ldd	r19, Z+Drv_Flags
	push	r18
	rcall	checkunit
	pop	r18
	brcs	attachpar030
	std	Z+ucb_type, r18		; Set drive type
	std	Z+ucb_flags, r19	; Set drive flags
	ldi	r18, (1<<ucb__drdy) | (1<<ucb__part)
	std	Z+ucb_status, r18	; Set status
	std	Z+ucb_diskaddr+0, zero	; Set current disk address
	std	Z+ucb_diskaddr+1, zero
	std	Z+ucb_imgptr+0, yl	; Link partition control block
	std	Z+ucb_imgptr+1, yh
	clc
	rjmp	attachparexit

attachpar030:
	call	mprint
	.dw	msgattachunt		; invalid unit number (old version)
	clc	
	rjmp	attachparexit
attachpar090:
	lds	r18, attpart
	ori	r18, '0'
	sts	pprint+0, r18
	call	mprint
	.dw	msgattachpnf		;"Attach - Partition %c not found"
	clc
	rjmp	attachparexit

attachpar091:
	lds	r18, attpart
	ori	r18, '0'
	sts	pprint+0, r18
	call	mprint
	.dw	msgattachpaa		;"Attach - Partition %c is already attached"
	clc
	rjmp	attachparexit

attachpar092:
	lds	r18, attpart
	ori	r18, '0'
	sts	pprint+0, r18
	call	mprint
	.dw	msgattachpin		;"Attach - Partition %c is inactive"
	clc
attachparexit:
	pop	yh
	pop	yl
	ret

;--------------------------------------------------------------------------
;
;	detach <unit>
;
detachunit:
	push	yl			
	push	yh
	lds	zl, attunit		
	cpi	zl, units
	brlo	detachunit010
	ori	zl, '0'
	sts	pprint+0, zl
	call	mprint
	.dw	msgdetachinv
	rjmp	detachunitexit
detachunit010:
	swap	zl
	clr	zh
	subi	zl, low(-unittable)
	sbci	zh, high(-unittable)
	ldd	r18, Z+ucb_status
	andi	r18, (1<<ucb__part) | (1<<ucb__file)
	brne	detachunit020
	lds	r18, attunit
	ori	r18, '0'
	sts	pprint+0, r18
	call	mprint
	.dw	msgdetachuna		;"Detach - Unit %c is not attached"
	rjmp	detachunitexit

detachunit020:
	std	Z+ucb_status, zero		; 
	ldd	yl, Z+ucb_imgptr+0
	ldd	yh, Z+ucb_imgptr+1
	sbrc	r18, ucb__file
	rjmp	detachunitfile
	ldd	r18, Y+pcb_status
	cbr	r18, (1<<pcb__attach)
	std	Y+pcb_status, r18
	rjmp	detachunitexit
;--------------------------------------------------------------------------
;
;	Dispose allocated memory of a file control block
;
;	Y	pointer to file control block
;	Z	pointer to unit control block
;
detachunitfile:
	ldd	r24, Y+fcb_filename+0		; free filename buffer
	ldd	r25, Y+fcb_filename+1
	sbiw	r25:r24, 0
	breq	detachunit090
	call	free
detachunit090:
	movw	r25:r24, Y
	adiw	r25:r24, fcb_fraglist
	call	FreeList
	ldd	zl, Y+fcb_iob+0
	ldd	zh, Y+fcb_iob+1
;	ldd	r24, P_Address+0	; currently shared buffer do not release
;	ldd	r25, P_Address+1
;	call	free
	movw	r25:r24, zh:zl		; IO Parameter Block
	call	free
	movw	r25:r24, yh:yl		; File Control Block
	call	free
;
;	Exit
;
detachunitexit:
	clc				; CLC means command processed
	pop	yh			; SEC would mean try another command
	pop	yl
	ret
