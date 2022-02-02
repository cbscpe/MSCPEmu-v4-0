;--------------------------------------------------------------------------
;
;	Core RLV12 Emulator routines
;
;
;	2018-03-25	For logging move the drive select bits to CSRL bits 4 and 5, 
;			these bits are just a copy of bits 0 and 1 of BAE.
;	2018-12-08	Version 2.0 based on new Bridge Design. See CPLD.
;	2018-12-23	Include seek into general rlv12 file
;	2019-01-05	In case the drive is not ready do not just return drive
;			error but call a special error handling routine, especially
;			read header and get status need to be more sophisticated
;	2019-01-05	Also handle ucb__drdy in seek
;	2019-01-12	Include all RL01/02 specific
;	2019-07-26	New Logical2Physical (moved input paramter to P_Cluster)
;			We need to translate each block via Logical2Physical when
;			the disk image is a file as we never know if we advance to
;			the next fragment if we need to read more than one block
;			rlv12_rwsetup now makes sure that Z points to the ucb for
;			the rest of processing and added rlv12_rwnextsector (which
;			requires ucb_file flag on ucb_status therefore we now keep
;			the ucb in Z)
;	2019-11-21	Add new CPLD interface as option
;	2019-11-28	Centralized DMA routines
;	2020-12-25	New RLV12 Emulator for PDP-11/Hack
;	2022-01-05	Disk Emulator
;--------------------------------------------------------------------------

.def	datal	= r4			; DMA data
.def	datah	= r5
.def	logptrl	= r6			; Logging Buffer
.def	logptrh	= r7
.def	wdcl	= r8			; Word Counter
.def	wdch	= r9	
.def	count	= r10
.def	bar_l	= r11
.def	addrl	= r12
.def	addrh	= r13
.def	ucbl	= r14
.def	ucbh	= r15
;
;
;
	.macro	logptr			; Destroys r25:r24, zh:zl
	cli				;;;
	lds	zl, log_pointer+0	;;;  3 Logging
	lds	zh, log_pointer+1	;;;  3 Logging
	movw	r25:r24, zh:zl		;;;  2
	adiw	r25:r24, 4		;;;  2
;	sbrc	r25,7			;;;  2 Lollipop shaped logging buffer, once
;	ori	r25, 0x08		;;;    it overflows it stays at upper half
	andi	r25, high(log_size)	;;;  1
	ori	r25, high(log_buffer)	;;;  1
	sts	log_pointer+0, r24	;;;  2
	sts	log_pointer+1, r25	;;;  2
	sei				;;;  1	-> 19 cycles ~0.6usec
	.endm
;--------------------------------------------------------------------------
;
;	Pin Change Interrupt
;
;	2022-01-08	One single job to handle all requests
;
go_:
	sbis	f_GO			; is it a GO from the controller?
	reti
	sbi	b_GO
	push	r8			; save minimal context
	in	r8, CPU_SREG
	push	zh			; acknowledging the interrupt we need to
	push	zl			; have at least one additional cpu cycle!
	push	yh
	push	yl
	sbi	f_GO			; Acknowledge interrupt
	ldi	zl, low(rlvlock)
	ldi	zh, high(rlvlock)
	jmp	unblocki
;--------------------------------------------------------------------------
;
;	RLV12 Emulator Job
;
;	The RLV12 Emulator V3.0 will take a different approach to emulate
;	the controller with up to 4 disk drives attached to it.
;
;	- In a first stage we are now using a small realtime kernel that
;	allows us to run jobs independently, the realtime kernel executes
;	at Level0 interrupt level.
;	- The Q-BUS interface is now executing at Level1 Interrupt level
;	and as such can interrupt the realtime kernel or any other interrupt.
;	- To execute a command the host first needs to setup the device registers
;	and then clear the controller ready bit (CRDY). When this bit is cleared
;	the Q-BUS interface will clear the b_GO bit that will trigger the Level0
;	interrupt assouciated with the PC interrupt of the b_GO bit. This bit
;	will then unblock the "RL01/02" emulator job. For a description of the
;	status bits see the qbus-v2-0.asm module.
;
;	- The "RL01/02" emulator job will then check the device registers and
;	execute the selected function as set in the function code bits. When
;	it has finished execution of the command it will set the CRDY bit and
;	if requested request a Q-BUS interrupt.
;	
rlv12job:
;
;	First we will have only one job to handle all requests. Even so we
;	have several units as we do not time the io operations we can just
;	do everything in one single job. Note that the controller is busy
;	during the execution of the job until we make the controller ready
;	again, so there are no conflicts when accessing the device registers
;
;	local variables kept in registers, note that registers r4..15 are
;	supposed to be saved be external routines (see ABI), so we can keep
;	some important variables in registers. r0..15 are like memory
;	locations as they do not allow immediate values as operands
;
rlv12loop:
	ldi	r24, low(rlvlock)
	ldi	r25, high(rlvlock)
	call	block			; Wait for GO
	logptr				; Destroys r25:r24, zh:zl
	movw	logptrh:logptrl, zh:zl	; keep it in case we want to overwrite
	lds	r16, CSRL		; the default logging
	std	Z+2, r16
	andi	r16, 0x0F		; Log Function Code
	ori	r16, log_fnc0
	std	Z+0, r16
	lds	r16, TCB2_CNTL
	std	Z+1, r16
	sts	rlv12_error, zero	; Assume no errors
	lds	yl, CSRH		;
	std	Z+3, yl			; Log error bits and driveselect
	andi	yl, driveselect		; Isolate Drive Select
	swap	yl			; Convert drive select to RL01/02
	clr	yh			; volume entry pointer. This code
	subi	yl, low(-unittable)	; assumes that the entries are 
	sbci	yh, high(-unittable)	; exactly 16 bytes and successive!
	lds	zl, CSRL		; Get function
	ldd	r16, Y+ucb_status	; Make sure drive ready bit is copied to CSR
	bst	r16, ucb__drdy
	bld	zl, CSR_DRVRDY
	sts	CSRL, zl
	lsr	zl
	andi	zl, 0x07		; Isolate function code 
	clr	zh			; it to jump table index
	subi	zl, low(-rlv12fnctbl)	; 
	sbci	zh, high(-rlv12fnctbl)	;

	icall				; Call Function subroutine
;
;	Set Interrupt request in case the IE bit of the CSR is set.
;
	lds	r18, CSRH
	lds	r16, rlv12_error
	or	r18, r16
	sts	CSRH, r18		; Update error bits
	lds	r18, CSRL
	sbr	r18, (1<<CSR_CRDY)
	sts	CSRL, r18
;
;	Show 7 pulses on signal PIN normally there should be nothing
;	else using the signal PIN at this moment even we have interrupts
;	enabled, but with b_ENA cleared the interrupts that also use
;	this pin have been disabled within the CPLD
;
	ldi	r16, 7			;
rlv12toggle:				;
	sbi	b_SIG			; 1
	nop				; 1
	dec	r16			; 1	shifting dec r16 here
	cbi	b_SIG			; 1	makes the pulses symmetric
	brne	rlv12toggle		; 2
	cli				;	Disable Interrupts
	sbrc	r18, CSR_IE		;;; 1/2 Interrupt Enabled?
	sbi	b_IRQ			;;; 0/1 yes then set interrupt
	sbi	b_CRDY			;;; 1	Enable controller
	sbi	b_QDE			;;; 1	Enable Q-Bus Data
	sbi	b_ENA			;;; 1	Enable CPLD Interrupts
	sei				;;; 1	Enable Interrupts
					;
	rjmp	rlv12loop		; 
;
;
;
rlv12fnctbl:
	rjmp	rlv12_maintenance
	rjmp	rlv12_writecheck
	rjmp	rlv12_getstatus
	rjmp	rlv12_seek
	rjmp	rlv12_readheader
	rjmp	rlv12_writedata
	rjmp	rlv12_readdata
	rjmp	rlv12_readnocheck

;--------------------------------------------------------------------------
;
;	Not (yet) implemented
;
rlv12_maintenance:
	ret
;--------------------------------------------------------------------------
;
;	Write Check, Compare data on the disk with the data in memory
;
rlv12_writecheck:
	set				; DMA Read
	rcall	rlv12_rwsetup
	ldi	r18, led_time
	sts	led_oneshot, r18
	sbi	b_LED
	call	SD_CARD_READ		; 
	tst	r24
	breq	rlv12_writecheck010
	rjmp	rlv12_writechk_error	; was never implemented, needs to be done
rlv12_writecheck010:
	movw	r25:r24, wdch:wdcl	; Get word count
	movw	xh:xl, addrh:addrl	; Get buffer address
;
;	Now we need to consider the following special cases
;
;	If read starts at an odd sector we need to skip half
;	of the block from the SDCARD
;
	lds	r18, DARL
	sbrs	r18, 0
	rjmp	rlv12_writechkdmaloop
	inc	xh			; Second half of block from SDCARD
	ldi	r18, 128		; has only 128 words
	mov	count, r18
rlv12_writechkdmaloop:
	dmaread	datal, datah		; Caution!!!! DMA Macros destroy r18
	brcs	rlv12_writechktmo
	ld	r16, X+
	ld	r17, X+
	cp	r16, datal
	cpc	r17, datah
	brne	rlv12_writechk_error
	adiw	r25:r24, 1		; increment complement of requested words
	breq	rvl12_writechk_success	; if eq we are really done
	dec	count			; do we have still words in our buffer
	brne	rlv12_writechkdmaloop	; Yes
	movw	wdch:wdcl, r25:r24	; Update wordcount
	rcall	rlv12_rwnextsector
	ldi	r18, led_time
	sts	led_oneshot, r18
	sbi	b_LED
	movw	r25:r24, yh:yl		; 
	call	SD_CARD_READ
	tst	r24
	brne	rlv12_writechkerror	; was never implemented, needs to be done
	movw	r25:r24, wdch:wdcl	; Restore Word Count
	movw	xh:xl, addrh:addrl	; Get buffer address
	clr	count			; Sector Word Count
	rjmp	rlv12_writechkdmaloop	;
rvl12_writechk_success:
	rjmp	rlv12_rwsuccess
rlv12_writechkerror:
	ldi	r18, 0x88		; Read Data CRC or Write Check Error
	sts	rlv12_error, r18
	rjmp	rlv12_rwfail

rlv12_writechk_error:
	rjmp	rlv12_writechk_error
;
;	DMA Read Time-Out Handler
;
rlv12_writechktmo:
	logptr
	ldi	r16, log_trace
	ldi	r17, 0xA0
	std	Z+0, r16
	std	Z+1, r17
	std	Z+2, r24
	std	Z+3, r25
	sts	pprint+0, xl
	sts	pprint+1, xh
	sts	pprint+2, r24
	sts	pprint+3, r25
	sts	pprint+4, count
	call	print
	.db	CR, LF
	.db	"WCHK NXM 0x", 0x81, 0x80, ", WDC 0x", 0x83, 0x82, CR, LF, 0
	call	redraw_1
	ldi	r18, 0xa0		; Set error bits: NXM
	sts	rlv12_error, r18
	rjmp	rlv12_rwfail
;
;	On compare error we print a message to the MCU console and set the 
;	corresponding error bits in CSR
;
rlv12_writechk_error010:
	sts	pprint+0, r16		; Value from PDP-11 Memory
	sts	pprint+1, r17
	sts	pprint+2, datal		; Value from SD-Card
	sts	pprint+3, datah
	sts	pprint+4, xl		; Address in Buffer
	sts	pprint+5, xh
	call	print
	.db	"wcheck-error at buffer address: 0x", 0x85, 0x84
	.db	"  pdp-11: 0x", 0x81, 0x80
	.db	" disk: 0x", 0x83, 0x82, CR, LF, 0
	call	redraw_1
	ldi	r18, 0x88				; Set error bits: WCE
	sts	rlv12_error, r18
	rjmp	rlv12_rwfail

;--------------------------------------------------------------------------
;
;	Get drive status
;
;	Often the DL: driver calls get status three times. First it does
;	a read status with RST cleared to get the current error bits. Then
;	it does a get status with RST set to clear the error bits and then
;	checks the drive again with RST cleared to make sure the error bits
;	are reset.
;
;	DAR during get status
;
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;	| x | x | x | x | x | x | x | x | 0 | 0 | 0 | 0 |RST| 0 | 1 | 1 |
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;
;	MPR during get status
;
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;	|WDE|CHE|WL |SKT|SPE|WGE|VC |DSE|DT |HS |CO |HO |BH |STC|STB|STA|
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;
rlv12_getstatus:
	lds	r18, DARL		; Check for valid request code
	cpi	r18, 0x0B		; Get Status with reset errors
	breq	rlv12_get010
	cpi	r18, 0x03		; Get Status
	breq	rlv12_get010
	;
	; Here we should return an error, but which?
	;
	ret
rlv12_get010:
	ldi	r18, 0x1d		; Assume RL01 and drive ready
	ldd	r16, Y+ucb_diskaddr	; Get current Disk address
	bst	r16, DAR_RW_HS		; Get current head selected
	bld	r18, MPR_GETS_HS	; Set selected head in status
	ldd	r16, Y+ucb_type		; Get Volume Type
	bst	r16, DL_RL02		; Copy RL02 bit
	bld	r18, MPR_GETS_DT	; Set drive type in status

rlv12_get020:
;
;	Note that when the PDP-11 reads the MPR the reads always go to the
;	FIFO and never to the word-count register, which is a write only
;	register.
;
	sts	MPR_Fifo+0, r18		; Return status
	sts	MPR_Fifo+1, zero
	sts	MPR_Fifo+2, zero
	sts	MPR_Fifo+3, zero
	sts	MPR_Fifo+4, zero
	sts	MPR_Fifo+5, zero
	sts	MPR_Fifo+6, zero
	sts	MPR_Fifo+7, zero
	ret	
;--------------------------------------------------------------------------
;
;	Seek RLV12 Emulator routines
;
;	Under investigation
;
;	A seek command is special as it does not block the controller
;	until the drive has executed the seek. It rather just sends
;	the seek command to the drive and the controller is immediately
;	ready again. However I don't know what IMMEDIATELY measn.
;
;	The RLV12 Emulator Version 3.0 instead of processing the seek
;	command in the Q-BUS interface routines it will now be executed
;	in this job. Note that as long as CRDY is cleared the CPLD that
;	interfaces to the Q-BUS just returns a zero word. Therefore I
;	assume that it is acceptable that CRDY must not be set in the 
;	Q-BUS interface but rather in the normal "RL01/02" emulator job.
;	
;	This behaviour allows drives to execute a seek and still perform
;	a read or write request to another drive. This makes it rather
;	simple
;
rlv12_seek:
;
;	DAR during seek
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	|DF8|DF7|DF6|DF5|DF4|DF3|DF2|DF1||DF0| 0 | 0 |HS | 0 |DIR| 0 | 1 |
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
;	Disk Address during read/write operations
;
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;	|CA8|CA7|CA6|CA5|CA4|CA3|CA2|CA1||CA0|HS |SA5|SA4|SA3|SA2|SA1|SA0|
;	+---+---+---+---+---+---+---+---++---+---+---+---+---+---+---+---+
;
	movw	zh:zl, logptrh:logptrl	; Get Log Pointer
	lds	r17, CSRH		; Overwrite Logging with log_seek
	andi	r17, driveselect
	ori	r17, log_seek
	lds	r18, DARL		; Get seek command
	lds	r19, DARH
	std	Z+0, r17		
	std	Z+2, r18
	std	Z+3, r19		; Save DAR used with Seek command
	ldd	r16, Y+ucb_diskaddr+0	; Get current disk address
	ldd	r17, Y+ucb_diskaddr+1
	bst	r18, DAR_SEEK_HS	; Get HS from seek command
	bld	r16, DAR_RW_HS		; Set head in current disk address
	sbrs	r18, DAR_SEEK_DIR	; direction of seek
	rjmp	rlv12_seekout		; towards the boarder
;
;	DIR=1 head moves to a higher cylinder address
;
	andi	r18, 0x80		; Only keep cylinder bits
	add	r16, r18
	adc	r17, r19
	rjmp	rlv12_seekdone
;
;	DIR=0 head moves to a lower cylinder address
;
rlv12_seekout:
	andi	r18, 0x80		; Only keep cylinder bits
	sub	r16, r18
	sbc	r17, r19
rlv12_seekdone:
	std	Y+ucb_diskaddr+0, r16
	std	Y+ucb_diskaddr+1, r17
;
;	Logging
;
	logptr				; Destroys r25:r24, zh:zl
	std	Z+2, r16
	std	Z+3, r17		; new disk address
	ldi	r16, log_diskaddr
	std	Z+0, r16
	ldd	r16, Y+ucb_status
	std	Z+1, r16
;
;	Real Seek Time (optional)
;
;-	ldd	r18, Y+ucb_status	; Reset Seek Request
;-	sbr	r18, (1<<DL_DRSEEK)	; seek pending	
;-	std	Y+ucb_status, r18
;-	ldi	r18, 2
;-	std	Y+ucb_seektimer, r18	; 
;
;	Copy over unit read to CSR
;
	ldi	r16, 0			; Assume Drive Ready
	ldd	r18, Y+ucb_status
	sbrs	r18, ucb__drdy		; is unit ready?
	ldi	r16, 0x84		; no -> composite error | operation incomplete
	sts	rlv12_error, r16	; Save Error

	lds	r16, CSRL		; Got CSR low byte
	bst	r18, ucb__drdy		; Get Drive Ready
	bld	r16, CSR_DRVRDY		; Copy Drive Ready
	sts	CSRL, r16		; Update CSR low byte
	ret

;--------------------------------------------------------------------------
;
;	Read Header
;
;	Fake the read header result by calculating the header from a RL02
;	from just the current DAR. After every read header we increment the
;	sector number respecting overflow from 39 to 0.
;
rlv12_readheader:
	clr	crcl
	clr	crch			; Init CRC
	ldd	r16, Y+ucb_diskaddr+0	; First MPR is last DAR
	ldd	r17, Y+ucb_diskaddr+1
	sts	MPR_Fifo+0, r16
	sts	MPR_Fifo+1, r17
	updcrc	r16			; Inline macro to update CRC using tables
	updcrc	r17
	updcrc	zero
	updcrc	zero
	sts	MPR_Fifo+2, zero
	sts	MPR_Fifo+3, zero
	sts	MPR_Fifo+4, crcl
	sts	MPR_Fifo+5, crch
	sts	MPR_Fifo+6, zero
	sts	MPR_Fifo+7, zero
;
;	After each Read Header we increment the sector to make the
;	program think the disk spins really
;
	ldd	r18, Y+ucb_diskaddr+0
	andi	r18, 0x3F
	inc	r18
	cpi	r18, 40
	brlo	rlv12_readheader010
	clr	r18			; Sectornumber goes from 0..39 only
rlv12_readheader010:
	ldd	r16, Y+ucb_diskaddr+0	; Disk address of this drive
	andi	r16, 0xC0		; Keep LSB of Cylinder and HS
	or	r18, r16
	std	Y+ucb_diskaddr+0, r18
	ret

;--------------------------------------------------------------------------
;
;	The RLV12 write command can write to any 256byte sector and it also can
;	write less then 256bytes. When writing less then 256bytes the RLV12 will
;	fill the rest with the value zero. The SD-Cards have a block size of
;	512bytes. Therefore it can happen that we need to first read the block
;	as only part of it is updated by the write request. MPR is loaded with the
;	2's complement of the word count to write, therefore we need to compare it
;	with the 2's complement of 128.
;	In case MPR is higher or same (between 177600 and 177777) we
;	only write one RL01/02 sector, which is half of a SD-Card block. This check
;	needs to be done always before we write a new SD-Card block. Note that 
;	a single write can write up to 5120 words as long as the RL01/02 sectors 
;	written belong to the same track. 
;
rlv12_writedata:
	set				; DMA Read
	rcall	rlv12_rwsetup		;
	lds	r18, DARL		; Does the write start at a SD-Card
	sbrc	r18, 0			; Block boundary
	rjmp	rlv12_write010		; -> no

rlv12_write000:
	ldi	r18, high(-128)
	cpi	r24, low(-128)		; Do we write more than 128 words?
	cpc	r25, r18		; That is MPR is lower than -128 (unsigned)
	brlo	rlv12_write025		; Just write the block
	rjmp	rlv12_write020		; Only first half of SD-Card block is written 
;
;	If the first sector to be written is an odd sector number then it starts
;	in the second half of a SD-Card block. Therefore we need to adjust the
;	start address and the number of words left to be written in a SD-Card
;	block.
;
rlv12_write010:
;	ldi	r18, 128		; Write 128 words
;	mov	count, r18
	set
	bld	count, 7		; Make only 128 words to write
	inc	addrh			; starting at the second half of the buffer
;
;	Either write starts at second half of SD-Card Block or we only write
;	128 words or less to the first half therefore we first need to read 
;	the SD-Card block to the buffer before we transfer the data
;
rlv12_write020:
	ldi	r18, led_time
	sts	led_oneshot, r18
	sbi	b_LED
	movw	r25:r24, yh:yl		; IO Parameter block in r25:r24 as per ABI
	call	SD_CARD_READ		; 
	tst	r24
	breq	rlv12_write025
	rjmp	rlv12_writeerror	; was never implemented, needs to be done
rlv12_write025:
	movw	r25:r24, wdch:wdcl	; Restore Word Count
	movw	xh:xl, addrh:addrl	; Get buffer address
;
;	Now we transfer the data from PDP-11 memory to the Block buffer.
;
rlv12_write030:
	dmaread	datal, datah		; Caution!!!! DMA Macros destroy r18
	brcs	rlv12_writetmo
	st	X+, datal
	st	X+, datah
	adiw	r25:r24, 1		; One word less
	breq	rlv12_write040		; Done with the request
	inc	count			; Another word in our SD-Card block buffer
	brne	rlv12_write030		; more left
	movw	wdch:wdcl, r25:r24	; Save Word Count after loop
;
;	We have reached the end of the SD-Card buffer, therefore we need to write
;	the data to the SD-Card and prepare for the next SD-Card block
;
	ldi	r18, led_time
	sts	led_oneshot, r18
	sbi	b_LED
	movw	r25:r24, yh:yl
	call	SD_CARD_WRITE
	tst	r24
	brne	rlv12_writeerror	; was never implemented, needs to be done
;
;	Update parameter block, i.e. increment current sector by 1.
;
	rcall	rlv12_rwnextsector
	ldd	addrl, Y+P_Address+0	; Get buffer address for SD-Card block
	ldd	addrh, Y+P_Address+1	; from IO control block
	clr	count			; Once we are here we always start at the
	rjmp	rlv12_write000		; Do check for partial write of SD-Card block
;
;	The request has finished. If not a full sector has been written the rest
;	is filled with zero bytes. First we need to make sure we only fill the 
;	part that corresonds to the RL01/02 sector. Therefore we adjust count
;	so it only accounts for one 128 word sector, regardless whether we have
;	started with the even or odd sector within the same SD-Card block
;
rlv12_write040:
	set
	bld	count, 7		; zero fill only to the next 128 word boundary
;	ldi	r18, 0x80		; zero fill only to the next 128 word boundary
;	or	count, r18
;
;	Check if we already reached the end of the SD-Card before writing zero as we
;	arrive here when word count has reached zero and before count would have been
;	incremented
;
rlv12_write050:
	inc	count			; need to increment count not done previously
	breq	rlv12_write060		; no more or no words to write
	st	X+, zero
	st	X+, zero		; Write one word with 0
	rjmp	rlv12_write050		; do for the rest of the buffer
;
;	Sector has now potentially be filled with zero value and the last SD-Card
;	block of this write request is ready to be written to the SD-Card
;
rlv12_write060:
	ldi	r18, led_time
	sts	led_oneshot, r18
	sbi	b_LED			
	movw	r25:r24, yh:yl		; no need to save word count it is zero now
	call	SD_CARD_WRITE	
	tst	r24
	brne	rlv12_writeerror	; was never implemented, needs to be done
	rjmp	rlv12_rwsuccess		; Done

rlv12_writeerror:
	ldi	r18, 0x88		; Read Data CRC or Write Check Error
	sts	rlv12_error, r18
	rjmp	rlv12_rwfail
;
;	DMA was not successfull we assume bus time-out 
;
rlv12_writetmo:
	logptr
	ldi	r16, log_trace
	ldi	r17, 0xA0
	std	Z+0, r16
	std	Z+1, r17
	std	Z+2, r24
	std	Z+3, r25
	sts	pprint+0, xl
	sts	pprint+1, xh
	sts	pprint+2, r24
	sts	pprint+3, r25
	sts	pprint+4, count
	call	print
	.db	CR, LF
	.db	"WRIT NXM 0x", 0x81, 0x80, ", WDC 0x", 0x83, 0x82, CR, LF, 0
	call	redraw_1
	ldi	r18, 0xa0		; Set error bits: NXM
	sts	rlv12_error, r18
	rjmp	rlv12_rwfail
;--------------------------------------------------------------------------
;
;	Read no check is the same as Read for SD-Cards
;
rlv12_readnocheck:
;--------------------------------------------------------------------------
;
;	Read Data
;
rlv12_readdata:
;
;	Express Log
;
;	lds	r16, CSRL
;	lds	r17, CSRH
;	sts	pprint+0, r16
;	sts	pprint+1, r17
;	lds	r16, BARL
;	lds	r17, BARH
;	sts	pprint+2, r16
;	sts	pprint+3, r17
;	lds	r16, DARL
;	lds	r17, DARH
;	sts	pprint+4, r16
;	sts	pprint+5, r17
;	lds	r16, MPRL
;	lds	r17, MPRH
;	sts	pprint+6, r16
;	sts	pprint+7, r17
;	lds	r16, BAEL
;	lds	r17, BAEH
;	sts	pprint+8, r16
;	sts	pprint+9, r17
;	call	print
;	.db	"R:", 0xa0, " ", 0xa2, " ", 0xa4, " ", 0xa6, " ", 0xa8, CR, LF, 0

	clt				; DMA Write
	rcall	rlv12_rwsetup
	ldi	r18, led_time
	sts	led_oneshot, r18
	sbi	b_LED
	movw	r25:r24, yh:yl		; IO Parameter Block
	call	SD_CARD_READ
	tst	r24
	breq	rlv12_readdata010
	rjmp	rlv12_readerror		; was never implemented, needs to be done
rlv12_readdata010:
	movw	r25:r24, wdch:wdcl	; Restore Word Count
	movw	xh:xl, addrh:addrl	; Get buffer address
;
;	We need to consider the following special cases
;
;	-	If the software requested an odd start sector 
;	-	Wordcount (MPR) is not a multiple of 256
;
;	If read starts at an odd sector we need to skip half
;	of the block from the SDCARD
;
	lds	r18, DARL
	sbrs	r18, 0
	rjmp	rlv12_readdmaloop
	inc	xh			; Second half of block from SDCARD
;	ldi	r18, 128		; has only 128 words
;	mov	count, r18
	set	
	bld	count, 7		; has only 128 words
rlv12_readdmaloop:
	ld	datal, X+		; Fetch one word from buffer
	ld	datah, X+		; Caution!!!! DMA Macros destroy r18
	dmawrite datal, datah		; Write the Word via DMA to PDP-11 Memory
	brcs	rlv12_readtmo
	adiw	r25:r24, 1		; increment complement of requested words
	breq	rlv12_readdone		; if eq we are really done (can use br here)
	inc	count			; do we have still words in our buffer
	brne	rlv12_readdmaloop	; Yes
	movw	wdch:wdcl, r25:r24

	rcall	rlv12_rwnextsector
	ldi	r18, led_time
	sts	led_oneshot, r18
	sbi	b_LED
	movw	r25:r24, yh:yl
	call	SD_CARD_READ
	tst	r24
	brne	rlv12_readerror		; was never implemented, needs to be done
	movw	r25:r24, wdch:wdcl	; Restore Word Count
	ldd	xl, Y+P_Address+0
	ldd	xh, Y+P_Address+1	; Get buffer address from IO control block
	clr	count			; Sector Word Count
	rjmp	rlv12_readdmaloop	; and go
rlv12_readdone:
	rjmp	rlv12_rwsuccess
;
;	DMA Write Time-Out Handler
;
rlv12_readtmo:
	logptr
	ldi	r16, log_trace
	ldi	r17, 0xA0
	std	Z+0, r16
	std	Z+1, r17
	std	Z+2, r24
	std	Z+3, r25
	sts	pprint+0, xl
	sts	pprint+1, xh
	sts	pprint+2, r24
	sts	pprint+3, r25
	sts	pprint+4, count
	call	print
	.db	CR, LF
	.db	"READ NXM 0x", 0x81, 0x80, ", WDC 0x", 0x83, 0x82, CR, LF, 0
	call	redraw_1
	ldi	r18, 0xa0		; Set error bits: NXM
	sts	rlv12_error, r18
	rjmp	rlv12_rwfail
	ldi	r18, 0xa0		; Set error bits: NXM
	sts	rlv12_error, r18
	rjmp	rlv12_rwfail
rlv12_readerror:
	ldi	r18, 0x88		; Read Data CRC or Write Check Error
	sts	rlv12_error, r18
	rjmp	rlv12_rwfail
;--------------------------------------------------------------------------
;
;	read or write data finished, we now need to update the DAR and BAR
;
rlv12_rwsuccess:

	lds	wdcl, MPRL
	lds	wdch, MPRH
	lsl	wdcl			; Translate word count to byte count
	rol	wdch			; wdch holds also the number of RL01/02 sectors

	lds	r16, BARL
	lds	r17, BARH
	lds	r18, BAEL

	sub	r16, wdcl		; Note word count was 2's complement
	sbc	r17, wdch
	sbci	r18, byte3(-1)

	sts	BARL, r16
	sts	BARH, r17
	sts	BAEL, r18
	lds	r16, CSRL		; When we update BAE we also need to update
	bst	r18, BAE_BA16		; BA16 and BA17 in CSRL
	bld	r16, CSR_BA16
	bst	r18, BAE_BA17
	bld	r16, CSR_BA17
	sts	CSRL, r16
;
;	in the setup routine we made sure that no more words will be transferred
;	than are left on a cylinder, if we read past the last sector, the sector
;	number obviously is now 40. which is the number the RLV12 effectively
;	returns, in this case the setup routine has set the error to HNF (header
;	not found)
;
	movw	zh:zl, ucbh:ucbl	;
	lds	r18, DARL
	lds	r19, DARH
	sub	r18, wdch
;	mov	r17, r18
;	andi	r17, 0x3F
;	cpi	r17, 40
;	brlo	rlv12_rwsuccess010	; still ok
;	andi	r18, 0xC0		; wrap around
;	logptr				; Destroys r25:r24, zh:zl
;	ldi	r16, log_trace
;	ldi	r17, 4
;	std	Z+0, r16
;	std	Z+1, r17
;	std	Z+2, r18
;	std	Z+3, r19	
;rlv12_rwsuccess010:

;	mov	r17, r18
;	andi	r18, 0xC0		; LSB of Cyl and HS
;	andi	r17, 0x3F		; Sector
;	sub	r17, wdch		; wdch is 2's complement of sectors transferred
;	cpi	r17, 40
;	brlo	rlv12_rwsuccess010	; still ok
;	clr	r17			; wrap around
;rlv12_rwsuccess010:
;	or	r18, r17		; Insert Updated sector Numbers

	sts	DARL, r18
	std	Z+ucb_diskaddr+0, r18
	std	Z+ucb_diskaddr+1, r19
	ldi	r24, low(dmalock)
	ldi	r25, high(dmalock)	; 
;	call	release
	ret
rlv12_rwfail:
	ldi	r24, low(dmalock)
	ldi	r25, high(dmalock)	; 
;	call	release
	ret
;--------------------------------------------------------------------------
;
;	When reading or writing another block we need to either increment the
;	sector in case the unit is attached to a partition or we need to increment
;	the logical block number and then translate it to a physical block number.	
;
rlv12_rwnextsector:
	movw	zh:zl, ucbh:ucbl	; Get UCB Pointer
	ldd	r20, Z+ucb_status
	sbrc	r20, ucb__file		; Is the unit attached to a file?
	rjmp	rlv12_rwnextsector010	; Yes so increment LBN and translate

	ldd	r16, Y+P_Sector+0	; in case unit is attached to a partition
	ldd	r17, Y+P_Sector+1	; we just need to increment the sector
	ldd	r18, Y+P_Sector+2	; number by one
	ldd	r19, Y+P_Sector+3
	subi	r16, byte1(-1)
	sbci	r17, byte2(-1)
	sbci	r18, byte3(-1)
	sbci	r19, byte4(-1)
	std	Y+P_Sector+0, r16
	std	Y+P_Sector+1, r17
	std	Y+P_Sector+2, r18
	std	Y+P_Sector+3, r19
	logptr				; Destroys r25:r24, zh:zl
	std	Z+3, r16
	std	Z+2, r17
	std	Z+1, r18
	andi	r19, 0x0F
	ori	r19, log_pbn
	std	Z+0, r19	
	ret

rlv12_rwnextsector010:
	ldd	r16, Y+P_Cluster+0	; in case unit is attached to a file
	ldd	r17, Y+P_Cluster+1	; we just need to increment the LBN
	ldd	r18, Y+P_Cluster+2	; by one and then
	ldd	r19, Y+P_Cluster+3
	subi	r16, byte1(-1)
	sbci	r17, byte2(-1)
	sbci	r18, byte3(-1)
	sbci	r19, byte4(-1)
	std	Y+P_Cluster+0, r16
	std	Y+P_Cluster+1, r17
	std	Y+P_Cluster+2, r18
	std	Y+P_Cluster+3, r19
	ldd	r24, Z+ucb_imgptr+0	; This is the file control block
	ldd	r25, Z+ucb_imgptr+1
	call	Logical2Physical	; translate it to a PBN using the fragment list
	ldd	r16, Y+P_Sector+0
	ldd	r17, Y+P_Sector+1
	ldd	r18, Y+P_Sector+2
	ldd	r19, Y+P_Sector+3
	logptr				; Destroys r25:r24, zh:zl
	std	Z+3, r16
	std	Z+2, r17
	std	Z+1, r18
	andi	r19, 0x0F
	ori	r19, log_pbn
	std	Z+0, r19	
	ret				; attached to the FCB

;--------------------------------------------------------------------------
;
;	Setup a read or write operation
;
;	Input:
;		T-Bit		must be set to DMA direction (0=Write, 1=Read)
;		Y		points to the current RL0x unit control block
;
;	Output:
;		Y		points to the parameter buffer with sector
;				and buffer address set for SD_CARD_READ/WRITE
;		addrh:addrl	IO buffer address
;		wdch:wdcl	2's complement of word count
;		ucbh:ucbl	unit control block
;		count		set to zero
;		CPLD		DMA direction and DMA start address are set
;	
;	Translate DAR into a sector number of the partition
;
;	Frist the 16-bit disk address in DAR
;
;		bit0..5		Sector		0..39
;		bit6		Head		0..1
;		bit7..15	Cylinder	0..511
;
;	needs to be translate into a logical block number. For this we multiply
;	the compound value of (cylinder,header) by 20 as there are 40 sectors 
;	of 256bytes per track on a RL01/02 which corresponds to 20	sectors of 
;	512bytes on a SD-Card. 
;
;	20 in binary is 0b10100, so we need to calculate
;
;	ccccccccch000000	cylinder and head in DAR
; x            10100		binary for 20 in decimal
;
;	this is the same as calculating the following value
;
;	00ccccccccch0000
; +	0000ccccccccch00
;
;	For this we take DAR, mask out the sector value and shift the result to
;	the right by two bits. Then we duplicate the result and shift the
;	copy again by two bits to the right. Finally we add them together and
;	have the desired value.
;
;	Then we need to add the sector/2 to the above result. Remember sectors
;	on a RL02 are only 256bytes. This gives the offset in sectors into the
;	partition that holds the disk image of a RL02.
;
rlv12_rwsetup:
;
;	Setup DMA Address
;
	lds	bar_l, BARL
	bld	bar_l, 0		; T bit might not be preserved later
	lds	r16, BARH
	lds	r17, BAEL
;
	logptr				; Destroys r25:r24, zh:zl
	ldi	r19, log_address
	std	Z+0, r19
	std	Z+1, bar_l
	std	Z+2, r16
	std	Z+3, r17
	setupdmaaddress	bar_l, r16, r17	; Caution!!!! DMA Macros destroy r18
;
	ldd	r18, Y+ucb_status
	cbr	r18, (1<<DL_DRSEEK)
	std	Y+ucb_status, r18	; clear pending seek
;
;	Translate disk address to a logical block number
;
	lds	r18, DARL
	lds	r19, DARH
	andi	r18, 0xc0		; need only the LSB of CYL and the HS bits
	lsr	r19
	ror	r18
	lsr	r19
	ror	r18			; Devide by four
	movw	r17:r16, r19:r18	; Make copy
	lsr	r19
	ror	r18
	lsr	r19
	ror	r18			; Divide by four again
	add	r16, r18
	adc	r17, r19
	lds	r18, DARL
	andi	r18, 0x3f		; Isolate Sector Number
	lsr	r18			; Sectors on RL02 are only 256bytes
	add	r16, r18
	adc	r17, zero
	clr	r18
	clr	r19			; r16..19 32-bit sector of partition
;
;	Translate logical block number to physical block number on SD-Card
;
	movw	ucbh:ucbl, yh:yl	; Save UCB
	ldd	zl, Y+ucb_imgptr+0	; Get pointer to disk image control block
	ldd	zh, Y+ucb_imgptr+1
	ldd	r20, Y+ucb_status	; Get the status
	sbrs	r20, ucb__file		; Is unit attached to a file?
	rjmp	rlv12_rwsetup020	; no its a partition
;
;	A file is attached, Z points to the fcb. We put the LBN to the
;	P_Cluster offset of the iob linked to the fcb (file control block)
;	which is then translated to a physical block number by using the
;	fragment list attached to the file control block
;
	ldd	yl, Z+fcb_iob+0
	ldd	yh, Z+fcb_iob+1
	std	Y+P_Cluster+0, r16	; Set start LBN for read or write
	std	Y+P_Cluster+1, r17
	std	Y+P_Cluster+2, r18
	std	Y+P_Cluster+3, r19
	movw	r25:r24, zh:zl		; File Control Block
	call	Logical2Physical	; Convert to PBN (pyhsical block number)
	rjmp	rlv12_rwsetup030
;
;	A partition is attached, Z points to the pcb which holds the
;	start sector number of the partition, translating LBN to PBN
;	results in just adding the start sector number
;
rlv12_rwsetup020:
	ldd	r20, Z+pcb_start+0	; Add start of partition
	ldd	r21, Z+pcb_start+1
	ldd	r22, Z+pcb_start+2
	ldd	r23, Z+pcb_start+3
	add	r16, r20
	adc	r17, r21
	adc	r18, r22
	adc	r19, r23
	ldi	yl, low(sdio)		; Setup parameter block for general IO
	ldi	yh, high(sdio)		; 
	std	Y+P_Sector+0, r16	; Set start sector for read or write
	std	Y+P_Sector+1, r17
	std	Y+P_Sector+2, r18
	std	Y+P_Sector+3, r19
;
;	Get the number of words requested. If more words are requested than
;	would be available on the current track from the start sector then
;	we truncate to the maximum word count possible. If this was the
;	case we need to return HNF so the device driver can continue the
;	read/write request after a seek to the next track has been made.
;	This is an undocumented feature and has been verifed with simh and
;	at least the boot loader of RT-11 makes use of this behaviour. Note
;	that we calculate MAXWC and then overwrite MPR in case it is higher
;	than the user provided value of the wordcount in MPR. This value
;	will later be used to calculate the and bus address after the
;	transferred bytes. This is not a problem as the wordcount cannot be
;	retrieved, reading MPR always returns values from the FIFO
;
rlv12_rwsetup030:
	logptr				; Destroys r25:r24, zh:zl
	ldd	r16, Y+P_Sector+0	; Set start sector for read or write
	ldd	r17, Y+P_Sector+1
	ldd	r18, Y+P_Sector+2
	ldd	r19, Y+P_Sector+3
	std	Z+3, r16
	std	Z+2, r17
	std	Z+1, r18
	andi	r19, 0x0F
	ori	r19, log_pbn
	std	Z+0, r19	
;
;	We cannot read more than there is left on a track, therefore
;	we caluclate the 2's complement of words left. First we take
;	the current sector and subtract the number of sectors per track
;	which is 40. This gives the 2's complement of RL02 sectors
;	left. As each RL02 sector is 256bytes this is also the high byte
;	of the 2's complement of bytes left on the track, thats why we 
;	combine it with a zero low byte (clr r16). Now we need to convert
;	the number of bytes left in the track to the number of 16-bit
;	words left on the track, as this is a negative number we need
;	to rotate the byte value to the right with the carry initially set.
;
	clr	r16			; as a 2's complement number. Then we
	lds	r17, DARL
	andi	r17, 0x3f		; Current Sector
	subi	r17, 40			; Number of sectors left in current track
	sec				; convert this into a maximum word count
	ror	r17			; that can be transferred before a SEEK
	ror	r16			; is required to switch tracks
;
;	Now we get the requested word count and compare it with the number
;	of words left on the track. Note that both values are teh 2's complement
;	of the words requested and left on the track therefore the logic is
;	inverted, that is when the 2's complement of the number of words is
;	higher or same than the 2's complement of the number of words left
;	on the track then we can transfer as many words as requested. Else
;	we can only transfer as many bytes as are left on the track and will
;	return this value to the caller, also we will update the MPR to the
;	number of words we are going to transfer to later calculate the BUS
;	address and set the error HNF to indicate that transfer beyond the 
;	last sector was requested (i.e. a non-existant sector header)
;
	lds	wdcl, MPRL
	lds	wdch, MPRH		; Get Word Count (2's complement) = wc
	cp	wdcl, r16		; compare "word count" with "max word count"
	cpc	wdch, r17		;
	brsh	rlv12_rwsetup040	; if less words request than possible -> ok
	mov	wdcl, r16
	mov	wdch, r17		; only maxwc can be transferred
	sts	MPRL, wdcl
	sts	MPRH, wdch		; used later to calculate the ending DMA address
	ldi	r18, 0x94		; Set error bits: Header Not Found
	sts	rlv12_error, r18
	lds	r18, HNF_count
	inc	r18
	sts	HNF_count, r18

	logptr				; Destroys r25:r24, zh:zl
	std	Z+2, wdcl
	std	Z+3, wdch	
	ldi	r18, log_trace
	std	Z+0, r18
	ldi	r18, 3
	std	Z+1, r18
;
;	Setup the return registers
;
rlv12_rwsetup040:
	ldi	r16, low(sdbuffer)	; 
	ldi	r17, high(sdbuffer)	; 
	std	Y+P_Address+0, r16	; Set buffer address for SD-Card block
	std	Y+P_Address+1, r17	; 
	movw	addrh:addrl, r17:r16
	clr	count
	ret

;;;------------------------------------------------------------------------
;;;
;;;	Called by main and bus init interrupt, destroys zh and zl but
;;;	makes no assumption regarding preset registers
;;;
rlv12_reset:
	ldi		zl, (1<<CSR_CRDY)	;;; Mark Controller is ready
	clr		zh
	sts		CSRL, zl
	sts		CSRH, zh
	sbi		b_CRDY			;;; Set Controller Read
	sbi		b_QDE
	sts		BARL, zh
	sts		BARH, zh
	sts		DARL, zh
	sts		DARH, zh
	sts		MPR_Fifo+0, zh
	sts		MPR_Fifo+1, zh
	sts		MPR_Fifo+2, zh
	sts		MPR_Fifo+3, zh
	sts		BAEL, zh
	sts		BAEH, zh
;
; Reset drives disk address
;
	sts		unittable+ucb_size*0+ucb_diskaddr+0, zh	;
	sts		unittable+ucb_size*0+ucb_diskaddr+1, zh	; 
	sts		unittable+ucb_size*1+ucb_diskaddr+0, zh	; 
	sts		unittable+ucb_size*1+ucb_diskaddr+1, zh	; 
	sts		unittable+ucb_size*2+ucb_diskaddr+0, zh	; 
	sts		unittable+ucb_size*2+ucb_diskaddr+1, zh	; 
	sts		unittable+ucb_size*3+ucb_diskaddr+0, zh	; 
	sts		unittable+ucb_size*3+ucb_diskaddr+1, zh	; 
	ret

.undef	datal	
.undef	datah	
.undef	logptrl	
.undef	logptrh	
.undef	wdcl	
.undef	wdch
.undef	count
.undef	ucbl
.undef	ucbh