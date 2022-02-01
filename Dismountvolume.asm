;=============================================================================
;
;	Dismount Volume Routine
;
DismountVolume:
	push	yl
	push	yh
;
;	First we need to disable the units
;
	clr	r24
DismountVolume110:
	mov	yl, r24
	swap	yl
	clr	yh
	subi	yl, low(-unittable)
	sbci	yh, high(-unittable)
	ldd	r25, Y+ucb_status
	cbr	r25, (1<<ucb__drdy)
	std	Y+ucb_status, r25
	inc	r24
	cpi	r24, units
	brlo	DismountVolume110
;
;	Next we need to check if a unit is attached
;
	clr	r20
DismountVolume210:
	mov	yl, r20
	swap	yl
	clr	yh
	subi	yl, low(-unittable)
	sbci	yh, high(-unittable)
	ldd	r25, Y+ucb_status
	sbrs	r25, ucb__file
	rjmp	DismountVolume220
;
;	Unit is attached to a file, we need to dispose the following buffers
;
;	File Control Block
;	IO Paramter Block
;	File Name Buffer (if exists)
;	(no sector buffer for the moment)
;	Fragment List
;
;	ldd	zl, Y+ucb_imgptr+0	; Z	File Control Block
;	ldd	zh, Y+ucb_imgptr+1
;	ldd	xl, Z+fcb_iob+0		; X	IO Parameter block
;	ldd	xh, Z+fcb_iob+1
;	adiw	xh:xl, P_Address	; X	Pointer to buffer address
;	ld	r24, X+			; retrieve buffer address
;	ld	r25, X+
;	call	free

	ldd	zl, Y+ucb_imgptr+0	; Z	File Control Block
	ldd	zh, Y+ucb_imgptr+1
	ldd	r24, Z+fcb_iob+0
	ldd	r25, Z+fcb_iob+1
	call	free
	ldd	r24, Z+fcb_filename+0
	ldd	r25, Z+fcb_filename+1
	sbiw	r25:r24, 0
	breq	DismountVolume215	; this is optional
	call	free
DismountVolume215:
	movw	r25:r24, zh:zl
	adiw	r25:r24, fcb_fraglist
	call	FreeList
	ldd	r24, Y+ucb_imgptr+0	; r25:r24 File Control Block
	ldd	r25, Y+ucb_imgptr+1
	call	free
	std	Y+ucb_status, zero
	rjmp	DismountVolume230
;
;	Unit is attached to a partition we just deattach it
; 
DismountVolume220:
	sbrs	r25, ucb__part
	rjmp	DismountVolume230
	ldd	zl, Y+ucb_imgptr+0
	ldd	zh, Y+ucb_imgptr+1
	ldd	r16, Z+pcb_status
	cbr	r16, (1<<pcb__attach)
	std	Z+pcb_status, r16
	std	Y+ucb_status, zero
	rjmp	DismountVolume210
DismountVolume230:
	inc	r20
	cpi	r20, units
	brne	DismountVolume210

;
;	Now we go through the volume control blocks and dispose the 
;	following buffers
;
;	FAT IO Parameter Block
;	FAT Sector Buffer
;	DIR IO Parameter Block
;	DIR Sector Buffer
;	Volume Control Block
;
;
DismountVolume240:
	lds	yl, volqueue+0
	lds	yh, volqueue+1
	sbiw	yh:yl, 0
	breq	DismountVolume250
	ldd	zl, Y+0
	ldd	zh, Y+1
	sts	volqueue+0, zl
	sts	volqueue+1, zh		; remove Volume from queue
	ldd	zl, Y+Vol_fatiob+0	; IO Parameter Block for FAT
	ldd	zh, Y+Vol_fatiob+1
	ldd	r24, Z+P_address+0	; FAT Buffer
	ldd	r25, Z+P_address+1
	call	free
	movw	r25:r24, zh:zl
	call	free
	ldd	zl, Y+Vol_diriob+0	; IO Parameter Block for Directory
	ldd	zh, Y+Vol_diriob+1
	ldd	r24, Z+P_address+0	; Directory Buffer
	ldd	r25, Z+P_address+1
	call	free
	movw	r25:r24, zh:zl
	call	free
	movw	r25:r24, yh:yl		; Volume Control Block
	call	free
	rjmp	DismountVolume240

;
;	Now we go through the partition control blocks
;
DismountVolume250:
	lds	yl, pcbqueue+0
	lds	yh, pcbqueue+1
	sbiw	yh:yl, 0
	breq	DismountVolume290
	ldd	zl, Y+0
	ldd	zh, Y+1
	sts	pcbqueue+0, zl
	sts	pcbqueue+1, zh		; remove PCB from queue
	movw	r25:r24, yh:yl
	call	free
	rjmp	DismountVolume250	; Just a partition
;
;
;
DismountVolume290:
	pop	yh
	pop	yl
	ret