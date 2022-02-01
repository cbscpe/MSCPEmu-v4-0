;--------------------------------------------------------------------------
;
;	Change Directory
;
;	-	in case there is a string save the start address and size
;	-	when the command was parsed successfully check for a string
;	-	if no string we reset active directory to root directory
;	-	if there is a string terminate it with 0x00
;	-	Call CopyName save "r16"
;	-	Call OpenDir
;	-	Call ReadDir		CS -> not found
;	-	Call MatchEntry		CS -> try next directory entry
;		-	If not a directory then issue message
;		-	If saved "r16" is \ start with copy name
;		-	If saved "r16" is 0x00 we are done
;
;	Commands to implement
;
;	How to maintain the working directory name
;
;	1.	Initially the working directory is set to the root, that is the
;		start cluster is 0 and the path is empty
;	2.	When executing a CD command we need to first check if the path
;		defined is valid
;	3.	If the path is valid we do not change the working directory
;	4.	A path change to '..' will go down the path only if we are not
;		at the root, else it will be ignored
;	5.	Absolute paths
;
;	FAT Library V2-0
;
;--------------------------------------------------------------------------
;
;	cd <directory>
;
cdcmd:
	push	yl
	push	yh

	lds	yl, volqueue+0
	lds	yh, volqueue+1		; get current volume
	sbiw	yh:yl, 0
	brne	cdcmd010
	call	mprint
	.dw	msgnovolume
	clc
	rjmp	cdcmdexit

cdcmd010:
	lds	xl, cdstring+2
	lds	xh, cdstring+3
	st	X, zero			; Zero Terminate the string
	lds	r22, cdstring+0
	lds	r23, cdstring+1
	movw	r25:r24, yh:yl		;
	call	Name2DirEntry
	tst	r24
	brne	cdcmd_fnf
	ldd	zl, Y+Vol_DirPointer+0	; Directory found
	ldd	zh, Y+Vol_DirPointer+1
	sbiw	zh:zl, 0		; Root
	breq	cdcmd020
	ldd	r18, Z+D_Attr     
	sbrs	r18, A_Directory
	rjmp	cdcmd_nad		; this is not a directory
cdcmd020:
	lds	r22, cdstring+0
	lds	r23, cdstring+1
	ldi	r24, low(Path)
	ldi	r25, high(Path)
	call	CreatePath		; Combine path and directory to new path

	ldd	zl, Y+Vol_diriob+0
	ldd	zh, Y+Vol_diriob+1
	ldd	r16, Z+P_Cluster+0	; Get Start Cluster of Directory 
	ldd	r17, Z+P_Cluster+1
	ldd	r18, Z+P_Cluster+2
	ldd	r19, Z+P_Cluster+3
	std	Y+Vol_DirCluster+0, r16	; Set current working directory 
	std	Y+Vol_DirCluster+1, r17
	std	Y+Vol_DirCluster+2, r18
	std	Y+Vol_DirCluster+3, r19
	clc
	rjmp	cdcmdexit

cdcmd030:
	sts	Path, zero
	clc
	rjmp	cdcmdexit

cdcmd_fnf:
	call	mprint
	.dw	msgcdfnf
	clc
	rjmp	cdcmdexit

cdcmd_nad:
	call	mprint
	.dw	msgcdnad
	clc
	rjmp	cdcmdexit

cdcmdexit:
	pop	yh
	pop	yl
	ret
;
;	cd
;
cdcmdroot:
	push	yl
	push	yh

	lds	yl, volqueue+0
	lds	yh, volqueue+1		; get current volume
	sbiw	yh:yl, 0
	brne	cdcmdroot010
	call	mprint
	.dw	msgnovolume
	clc
	rjmp	cdcmdexit
cdcmdroot010:
	std	Y+Vol_DirCluster+0, zero
	std	Y+Vol_DirCluster+1, zero
	std	Y+Vol_DirCluster+2, zero
	std	Y+Vol_DirCluster+3, zero
	sts	Path, zero		; Smash current Path
	pop	yh
	pop	yl
	clc
	ret
	
;--------------------------------------------------------------------------
;
;
;
dirsetcluster:
	ldd	r16, Y+Vol_DirCluster+0	; Get current working directory 
	ldd	r17, Y+Vol_DirCluster+1
	ldd	r18, Y+Vol_DirCluster+2
	ldd	r19, Y+Vol_DirCluster+3
	ldd	zl, Y+Vol_diriob+0	; io parameter block for directory IO
	ldd	zh, Y+Vol_diriob+1
	std	Z+P_Cluster+0, r16	; start cluster for dir command
	std	Z+P_Cluster+1, r17
	std	Z+P_Cluster+2, r18
	std	Z+P_Cluster+3, r19
	ret
	

dircmd_nad:
	call	mprint
	.dw	msgdirnad
	clc
	rjmp	dircmdexit

dircmd_fnf:
	call	mprint
	.dw	msgdirfnf
	clc
	rjmp	dircmdexit

;
;
;
dirchkvolume:
	lds	yl, volqueue+0
	lds	yh, volqueue+1		; get current volume
	sbiw	yh:yl, 0
	brne	dirchkvolume010
	call	mprint
	.dw	msgnovolume
	sez
dirchkvolume010:
	ret
;
;	dir (current directory)
;
dircmd:
	push	yl
	push	yh
	rcall	dirchkvolume
	brne	dircmd010
	rjmp	dircmdexit
dircmd010:
	rcall	dirsetcluster
	ldi	xl, low(Path)
	ldi	xh, high(Path)
	rjmp	dircmdprint
;
;	dir <directory>
;
dircmd1:
	push	yl
	push	yh
	rcall	dirchkvolume
	brne	dircmd110
	rjmp	dircmdexit
dircmd110:
	lds	xl, cdstring+2
	lds	xh, cdstring+3
	st	X, zero			; Zero Terminate the string
	lds	r22, cdstring+0
	lds	r23, cdstring+1
	movw	r25:r24, yh:yl
	call	Name2DirEntry
	tst	r24
	breq	dircmd120
	rjmp	dircmd_fnf
dircmd120:
	ldd	zl, Y+Vol_DirPointer+0
	ldd	zh, Y+Vol_DirPointer+1
	sbiw	zh:zl, 0
	breq	dircmd125
	ldd	r18, Z+D_Attr
	sbrs	r18, A_Directory
	rjmp	dircmd_nad
dircmd125:
	ldi	xl, low(Path)
	ldi	xh, high(Path)
	ldi	zl, low(LongFileN)
	ldi	zh, high(LongFileN)
dircmd130:				; Duplicate current path
	ld	r16, X+
	st	Z+, r16
	tst	r16
	brne	dircmd130
	lds	r22, cdstring+0
	lds	r23, cdstring+1
	ldi	r24, low(LongFileN)
	ldi	r25, high(LongFileN)
	call	CreatePath		; Create display path with duplicated path

	ldi	xl, low(LongFileN)
	ldi	xh, high(LongFileN)

;
;	Print Directory with P_Cluster of Vol_diriob set to start cluster
;
dircmdprint:
	call	print
	.db	CR, LF, "Directory of /", 0, 0
dircmdprint010:
	ld	r24, X+
	tst	r24
	breq	dircmdprint020
	call	serout
	rjmp	dircmdprint010
dircmdprint020:
	call	seroutcrlf
	movw	r25:r24, yh:yl
	call	OpenDir
	tst	r24
	brne	dircmdprint040
dircmdprint030:
	movw	r25:r24, yh:yl
	call	ReadDir
	tst	r24
	brne	dircmdprint040
	call	printdirentry
	rjmp	dircmdprint030
dircmdprint040:
	call	seroutcrlf
dircmdexit:
	clc
	pop	yh
	pop	yl
	ret
;--------------------------------------------------------------------------
;
;	pwd	- print working directory
;
pwdcmd:
	push	yl
	push	yh
	lds	yl, volqueue+0
	lds	yh, volqueue+1		; get current volume
	sbiw	yh:yl, 0
	brne	pwdcmd005
	call	mprint
	.dw	msgnovolume
	clc
	rjmp	pwdcmdexit
pwdcmd005:
	ldi	xl, low(Path)
	ldi	xh, high(Path)
	call	print
	.db	CR, LF, DELIM, 0
pwdcmd010:
	ld	r24, X+
	tst	r24
	breq	pwdcmd020
pwdcmd015:
	call	serout
	rjmp	pwdcmd010
pwdcmd020:
	call	seroutcrlf
pwdcmdexit:
	pop	yh
	pop	yl
	clc
	ret

;--------------------------------------------------------------------------
;
; Print Directory Entry Information
;
printdirentry:
	ldd	zl, Y+Vol_DirPointer+0
	ldd	zh, Y+Vol_DirPointer+1
	ldd	r16, Y+Vol_Status			
	sbrc	r16, Vol__Long
	lds	r16, LongFileN		; Long file name
	sbrs	r16, Vol__Long
	ldd	r16, Z+D_Name		; Short file name
	cpi	r16, '.'		; Name starts with '.'?
	brne	printdirentry010	; no, then evtl. print it
	lds	r16, dirswitch		; get dir switches
	sbrs	r16, dirswitch_a	; do we want . files
	ret				; no
printdirentry010:
	ldd	r18, Z+D_Attr		; Attributes
	sbrs	r18, A_Hidden		; Is the file hidden
	rjmp	printdirentry020	; no, print it
	lds	r16, dirswitch		; get dir switches
	sbrs	r16, dirswitch_a	; do we want hidden files
	ret				; no
printdirentry020:
	ldi	r16, 'A'		
	sbrs	r18, A_Archive		; Archived
	ldi	r16, ' '
	sts	pprint+0, r16
	ldi	r16, 'S'
	sbrs	r18, A_System		; System
	ldi	r16, ' '
	sts	pprint+1, r16
	ldi	r16, 'H'
	sbrs	r18, A_Hidden		; Hidden
	ldi	r16, ' '
	sts	pprint+2, r16
	ldi	r16, 'R'
	sbrs	r18, A_Readonly		; Read-only
	ldi	r16, ' '
	sts	pprint+3, r16
	ldd	r18, Z+D_Cluster+0
	sts	pprint+4, r18
	ldd	r18, Z+D_Cluster+1
	sts	pprint+5, r18		; Lower 16-bit of Startcluster
	ldd	r18, Y+Vol_Status
	sbrs	r18, Vol__FAT32
	rjmp	printdirentry030	; In case of FAT32 we also have
	ldd	r18, Z+D_ClusterH+0	; Higher 16-bit of Startcluster
	sts	pprint+6, r18
	ldd	r18, Z+D_ClusterH+1
	sts	pprint+7, r18
	call	print
	.db	0x0d, 0x0a, 0x90, 0x91, 0x92, 0x93, " Cl:", 0x87, 0x86, 0x85, 0x84, " ", 0
	rjmp	printdirentry040
printdirentry030:
	call	print
	.db	0x0d, 0x0a, 0x90, 0x91, 0x92, 0x93, " Cl:", 0x85, 0x84, " ", 0
printdirentry040:
	ldd	r18, Z+D_Attr		; Attributes
	sbrc	r18, A_Volume
	rjmp	printdirentry050
	sbrs	r18, A_Directory
	rjmp	printdirentry060
	call	print
	.db	" <DIR>       ", 0x00	; It's a directory
	rjmp	printdirentry070
printdirentry050:	
	call	print
	.db	" <Volume>    ", 0x00	; It's the volume information (Name)
	rjmp	printdirentry070
printdirentry060:	
	ldd	r18, Z+D_Size+0		; Get file length in bytes
	sts	pprint+0, r18
	ldd	r18, Z+D_Size+1
	sts	pprint+1, r18
	ldd	r18, Z+D_Size+2
	sts	pprint+2, r18
	ldd	r18, Z+D_Size+3
	sts	pprint+3, r18
	call	print
	.db	0xD0, 0x00		; Print file length as 32-bit integer
printdirentry070:	
	ldi	r24, ' '				
	call	serout
	ldd	r18, Y+Vol_Status			
	sbrc	r18, Vol__Long
	rjmp	printdirentry120	; Only print short name if there is no long name
;
;	Print short file name
;
	ldi	r17, 8			; Print short file name
	clr	r18			; Number of characters printed so far
printdirentry080:
	ld	r24, Z+
	cpi	r24, ' '
	breq	printdirentry090
	call	serout
	inc	r18
	dec	r17
	brne	printdirentry080
printdirentry090:
	ldd	zl, Y+Vol_DirPointer+0
	ldd	zh, Y+Vol_DirPointer+1
	adiw	Z, 8
	ld	r24, Z
	cpi	r24, ' '		; Does file have extension?
	breq	printdirentry110	; no then dont show anything
	ldi	r24, '.'		; dot between name and exteions
	inc	r18
	call	serout
	ldi	r17, 3
printdirentry100:
	ld	r24, Z+
	cpi	r24, ' '
	breq	printdirentry110
	call	serout
	inc	r18
	dec	r17
	brne	printdirentry100
printdirentry110:
	ret
;
;	Print long file name
;
printdirentry120:
	ldi	zl, low(LongFileN)	; Get the long file name buffer pinter
	ldi	zh, high(LongFileN)
	std	Z+48, zero		; just for safety reasons max 48 characters
printdirentry130:			; Print long file name
	ld	r24, Z+
	tst	r24
	breq	printdirentry140
	call	serout
	rjmp	printdirentry130
printdirentry140:
	ret
