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
;	2025-12-21	Remove logging, we need to redesign logging
;--------------------------------------------------------------------------
.def	crcl	= r2
.def	crch	= r3
.def	datal	= r4			; DMA data
.def	datah	= r5
.def	logptrl	= r6			; Logging Buffer
.def	logptrh	= r7
.def	wdcl	= r8			; Word Counter
.def	wdch	= r9	
.def	count	= r10
.def	flags	= r11
.def	addrl	= r12
.def	addrh	= r13
.def	ucbl	= r14
.def	ucbh	= r15
;--------------------------------------------------------------------------
;
;	Software Triggered Pin Change Interrupt 
;
;	2022-01-08	One single job to handle all requests
;
go_:
	sbic	b_GO			; is it a GO from the controller?
	jmp	crash
	nop
	nop
	nop
	nop
	sbi	b_GO
	push	r8			; save minimal context
	in	r8, CPU_SREG
	push	zh			; acknowledging the interrupt we need to
	push	zl			; have at least one additional cpu cycle!
	push	yh
	push	yl
	lds	yl, CSRL
	lds	yh, CSRH
	logtr	0x1F, yl, yh
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
	sbic	FLAGS_COMMON, auto__boot; Was Autoboot requested?
	rjmp	rlv12_autoboot		; Yes so do autoboot
	lds	yl, CSRH		;
	andi	yl, CSR_DS_gm		; Isolate Drive Select
	swap	yl			; Convert drive select to RL01/02
	clr	yh			; volume entry pointer. This code
	subi	yl, low(-unittable)	; assumes that the entries are 
	sbci	yh, high(-unittable)	; exactly 16 bytes and successive!
	lds	zl, CSRL		; Get function 
	ldd	r16, Y+ucb_status	; Make sure drive ready bit is copied to CSR
	bst	r16, ucb__drdy
	bld	zl, CSR_DRVRDY
	sts	CSRL, zl
	andi	zl, CSR_FC_gm
	lsr	zl
	clr	zh			; it to jump table index
	subi	zl, low(-rlv12fnctbl)	; 
	sbci	zh, high(-rlv12fnctbl)	;
	sts	rlv12_error, zero	; Assume no errors
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
;	else using the signal PIN at this moment as the Q-Bus interface
;	is disabled
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
	sbi	b_CRDY			;;; 1	Enable Controller
	sei				;;; 1	Enable Interrupts
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

;----------------------------------------------------------------------------
;
;	Autoboot Feature
;
;	By executing a 174414g in ODT the user can activate the autoboot of   
;	the controller. This feature will load the first block of the device  
;	that is attached to Unit 0 to the start of the PDP-11 memory (address 
;	zero). For more information see the description in the qbus module.   
;	
rlv12_autoboot:
	cbi	FLAGS_COMMON, auto__boot	; ack the autoboot flag
	ldi	yl, low(unittable)	; get address of first unit
	ldi	yh, high(unittable)	
	ldd	r18, Y+ucb_status
	sbrs	r18, ucb__drdy		; is unit read?
	rjmp	rlv12_noautoboot	; no can't boot then
	sbrc	r18, ucb__part		; is a partition attached
	rjmp	rlv12_autobootpart	; then boot from partition
	sbrc	r18, ucb__file		; is a file attached
	rjmp	rlv12_autobootfile	; then boot from file
rlv12_noautoboot:			; oops autoboot not possible
	rjmp	rlv12loop		; done
;
rlv12_autobootpart:			; Boot from Partition
	ldd	zl, Y+ucb_imgptr+0	; get address of partition control block
	ldd	zh, Y+ucb_imgptr+1
	ldi	yl, low(sdio)		; get IO Parameter block
	ldi	yh, high(sdio)
	ldd	r16, Z+pcb_start+0	; copy partition start
	ldd	r17, Z+pcb_start+1
	ldd	r18, Z+pcb_start+2
	ldd	r19, Z+pcb_start+3
	std	Y+P_Sector+0, r16	; to IO Parameter block, this is the boot
	std	Y+P_Sector+1, r17	; sector
	std	Y+P_Sector+2, r18
	std	Y+P_Sector+3, r19
	rjmp	rlv12_autoboot010	; cont
;
rlv12_autobootfile:			; Boot from File
	ldd	zl, Y+ucb_imgptr+0	; get address of partition control block
	ldd	zh, Y+ucb_imgptr+1
	ldd	yl, Z+fcb_iob+0		; get the address of the file control block
	ldd	yh, Z+fcb_iob+1
	std	Y+P_Cluster+0, zero	; start with first sector of file
	std	Y+P_Cluster+1, zero
	std	Y+P_Cluster+2, zero
	std	Y+P_Cluster+3, zero
	movw	r25:r24, zh:zl
	call	Logical2Physical	; translate using fragmentation list of FCB
;
;	IO Parameter Block is now setup with the sector to be read into memory
;
rlv12_autoboot010:
	ldi	r16, low(sdbuffer)	; get default IO buffer
	ldi	r17, high(sdbuffer)
	std	Y+P_Address+0, r16	; set IO buffer address
	std	Y+P_Address+1, r17
	sbi	b_LED			; blinken lights
	ldi	r18, led_time
	sts	led_oneshot, r18
	movw	r25:r24, yh:yl		; IO Parameter Block
	call	SD_CARD_READ		; read sector
	cpse	r24, zero		; test return code 
	rjmp	rlv12_noautoboot	; something went wrong no autoboot
;
;	we have now the boot record in our IO buffer, while the PDP-11
;	executes the BR . (0777) instruction at address 0 we copy 
;	words 1..256 of the boot sector to PDP-11 memory at address 2
;	
	ldi	r16, 2			; 
	dmaaddr r16, zero, zero	; destroys r18!!
	ldi	r20, 1			; need to transfer 255 words
	ldd	xl, Y+P_Address+0
	ldd	xh, Y+P_Address+1
	ld	r16, X+			; keep hold of the first word
	ld	r17, X+			; in the boot record
rlv12_autoboot020:
	ld	datal, X+		; now copy words 1..256. via DMA
	ld	datah, X+		; to the PDP-11 memory
	dmawrt datal, datah		; note dmawrt destroys r18!
	inc	r20			; 
	brne	rlv12_autoboot020
;
;	Last but not least we need to copy the first word of the boot
;	sector to address zero of the PDP-11 memory. This will overwrite
;	the BR . (0777) instruction the PDP-11 is continuously executing
;	with the first instruction of the boot sector and therefore start
;	the boot process
;
	dmaaddr zero, zero, zero
	dmawrt r16, r17
	rjmp	rlv12loop
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
	ldi	r24, 1			; DMA Read
	rcall	rlv12_rwsetup
	sbi	b_LED
	ldi	r18, led_time
	sts	led_oneshot, r18
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
	sbi	b_LED
	ldi	r18, led_time
	sts	led_oneshot, r18
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
	logtr	0xA0, r24, r25	
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
	cpi	r18, CSR_DS_gm		; Get Status
	breq	rlv12_get010
	;
	; Here we should return an error, but which?
	;
	cli
	lds	zl, log_pointer+0
	lds	zh, log_pointer+1
	lds	r18, CSRH
	andi	r18, CSR_DS_gm		; Unit
	ori	r18, log_command | (command_getstat<<2)
	st	Z+, r18
	lds	r18, timestamp
	st	Z+, r18
	ldi	r18, -1
	st	Z+, r18
	st	Z+, r18
	sbrc	zh, log_overflow
	subi	zh, high(log_size)
	sts	log_pointer+0, zl
	sts	log_pointer+1, zh
	sei
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
	cli
	lds	zl, log_pointer+0
	lds	zh, log_pointer+1
	lds	r18, CSRH
	andi	r18, CSR_DS_gm		; Unit
	ori	r18, log_command | (command_getstat<<2)
	st	Z+, r18
	lds	r18, timestamp
	st	Z+, r18
	lds	r18, MPR_Fifo+0
	st	Z+, r18
	st	Z+, zero
	sbrc	zh, log_overflow
	subi	zh, high(log_size)
	sts	log_pointer+0, zl
	sts	log_pointer+1, zh
	sei
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
	ldd	r16, Y+ucb_diskaddr+0	; Get current disk address
	ldd	r17, Y+ucb_diskaddr+1	;
	lds	r18, DARL
	lds	r19, DARH
	bst	r18, DAR_SEEK_HS	; Get HS from DAR of seek command
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
;	Copy over unit read to CSR
;
	ldi	r16, 0			; Assume Drive Ready
	ldd	r18, Y+ucb_status
	sbrs	r18, ucb__drdy		; is unit ready?
	ldi	r16, 0x84		; no -> composite error | operation incomplete
	sts	rlv12_error, r16	; Save Error

	lds	r16, CSRL		; Get CSR low byte
	bst	r18, ucb__drdy		; Get Drive Ready
	bld	r16, CSR_DRVRDY		; Copy Drive Ready
	sts	CSRL, r16		; Update CSR low byte
	cli
	lds	zl, log_pointer+0
	lds	zh, log_pointer+1
	lds	r18, CSRH
	andi	r18, CSR_DS_gm		; Unit
	ori	r18, log_command | (command_seek<<2)
	st	Z+, r18
	lds	r18, timestamp
	st	Z+, r18
	lds	r18, DARL
	st	Z+, r18
	lds	r18, DARH
	st	Z+, r18
	sbrc	zh, log_overflow
	subi	zh, high(log_size)
	sts	log_pointer+0, zl
	sts	log_pointer+1, zh
	sei
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
	cli
	lds	zl, log_pointer+0
	lds	zh, log_pointer+1
	lds	r18, CSRH
	andi	r18, CSR_DS_gm		; Unit
	ori	r18, log_command | (command_readhdr<<2)
	st	Z+, r18
	lds	r18, timestamp
	st	Z+, r18
	ldd	r18, Y+ucb_diskaddr+0
	st	Z+, r18
	ldd	r18, Y+ucb_diskaddr+1
	st	Z+, r18
	sbrc	zh, log_overflow
	subi	zh, high(log_size)
	sts	log_pointer+0, zl
	sts	log_pointer+1, zh
	sei
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
	ldi	r24, 1			; DMA Read
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
	sbi	b_LED
	ldi	r18, led_time
	sts	led_oneshot, r18
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
	sbi	b_LED
	ldi	r18, led_time
	sts	led_oneshot, r18
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
	sbi	b_LED			
	ldi	r18, led_time
	sts	led_oneshot, r18
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
	logtr	0xA0, r24, r25	
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
;	Read Data
;
;	The following read strategies have been implemented
;
;	1.	If the read starts at an odd RL01/02 sector then we use
;		the legacy mode with intermediate buffer
;	2.	If the read starts at an even RL01/02 sector and the 
;		media is contiguous then we use the read multiple block
;		function of SD-Card
;	3.	In all other cases we read individual sectors with using
;		the new TURBO read function which interleaves SD-Card
;		reads and DMA writes
;
rlv12_readnocheck:			; Read no check 
	ldi	r24, 0			; DMA Write
	rcall	rlv12_rwsetup
	ldd	r16, Y+P_Flag
	sbr	r16, (1<<P__Nocheck)
	std	Y+P_Flag, r16		; Do not check CRC
	rjmp	rlv12_readdata010

rlv12_readdata:				; Read for SD-Cards
	ldi	r24, 0			; DMA Write
	rcall	rlv12_rwsetup
	ldd	r16, Y+P_Flag
	cbr	r16, (1<<P__Nocheck)
	std	Y+P_Flag, r16		; Check CRC
rlv12_readdata010:
	sbis	FLAGS_LOG, log__turbo; 
	rjmp	rlv12_readdata060
;
;	Check if the sectors we need to read are contiguous. In this case
;	we can use Read Multiple Block which is way faster then reading
;	several single blocks
;
	ldd	r16, Y+P_Flag
	sbrs	r16, P__Contig		; Do we have a contiguous area to read?
	rjmp	rlv12_readdata020	; no so read individual blocks
	sbi	b_LED			; turn on the activity LED
	ldi	r18, led_time		; initiate the turn off count donw
	sts	led_oneshot, r18
	logtr	0x8C, wdcl, wdch
	movw	r25:r24, yh:yl		; IO Parameter Block
	call	SD_CARD_MULTIPLE	; Read in one go with SD-Card read and
	rjmp	rlv12_readdone		; DMA write interleaved and then finish
;
;	When we do not have a contiguous area we need to translate each 
;	logical block number to the physical block number individually
;
rlv12_readdata020:
	logtr	0x88, wdcl, wdch
rlv12_readdata030:
	sbi	b_LED
	ldi	r18, led_time
	sts	led_oneshot, r18
	movw	r25:r24, yh:yl		; IO Parameter Block
	call	SD_CARD_TURBO
	ldd	r16, Y+P_Flag		; Skipping the first 256 bytes is only
	cbr	r16, (1<<P__Skip)	; required for the first block in a
	std	Y+P_Flag, r16		; read command
	ldd	wdcl, Y+P_Wordcount+0	; Retrieve updated word count
	ldd	wdch, Y+P_Wordcount+1
	cp	wdcl, zero
	cpc	wdch, zero		; Any Words to tranfer left
	brne	rlv12_readdata040	; Yes more to go
	logtr	0x8B, wdcl, wdch
	rjmp	rlv12_readdone		; Done
rlv12_readdata040:
	rcall	rlv12_rwnextsector	; next sector might not be adjacent
	logtr	0x89, wdcl, wdch
	rjmp	rlv12_readdata030	; Check for Turbo
;
;	Read does not satisfy the conditions for direct transfer
;
rlv12_readdata060:
	sbi	b_LED
	ldi	r18, led_time
	sts	led_oneshot, r18
	movw	r25:r24, yh:yl		; IO Parameter Block
	call	SD_CARD_READ		; First read first sector
	tst	r24
	breq	rlv12_readdata070
	rjmp	rlv12_readerror		; was never implemented, needs to be done
rlv12_readdata070:
	movw	r25:r24, wdch:wdcl	; Get Word Count
	movw	xh:xl, addrh:addrl	; Get buffer address
;
;	RL01/02 sectors are only 256bytes but SD-Card blocks are 521byte
;	blocks, so if the read starts with an odd sector number we need
;	to skip the first 256 bytes of the SD-Card block.
;
	lds	r18, DARL
	sbrs	r18, 0
	rjmp	rlv12_readdmaloop
	inc	xh			; skip the first 256 bytes in buffer
	set				; we use the T-Bit to set Bit7 of count
	bld	count, 7		; only 128 words to transfer
rlv12_readdmaloop:
	ld	datal, X+		; Fetch one word from buffer
	ld	datah, X+		; Caution!!!! DMA Macros destroy r18
	dmawrt datal, datah		; Write the Word via DMA to PDP-11 Memory
	brcs	rlv12_readtmo
	adiw	r25:r24, 1		; increment complement of requested words
	breq	rlv12_readdone		; if eq we are really done (can use br here)
	inc	count			; do we have still words in our buffer
	brne	rlv12_readdmaloop	; Yes
	movw	wdch:wdcl, r25:r24	; Save Word Count
	rcall	rlv12_rwnextsector	; 
	sbi	b_LED
	ldi	r18, led_time
	sts	led_oneshot, r18
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

	cli
	lds	zl, log_pointer+0
	lds	zh, log_pointer+1
	lds	r18, CSRH
	andi	r18, CSR_DS_gm		; Unit
	ori	r18, log_command | (command_read<<2)
	st	Z+, r18
	lds	r18, timestamp
	st	Z+, r18
	lds	r18, MPRL
	st	Z+, r18
	lds	r18, MPRH
	st	Z+, r18
	sbrc	zh, log_overflow
	subi	zh, high(log_size)
	sts	log_pointer+0, zl
	sts	log_pointer+1, zh
	sei
	rjmp	rlv12_rwsuccess
;
rlv12_readerror:
	ldi	r18, 0x88		; Read Data CRC or Write Check Error
	sts	rlv12_error, r18
	rjmp	rlv12_rwfail
;
;	DMA Write Time-Out Handler
;
rlv12_readtmo:
	logtr	0xA0, r24, r25	
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
	sts	DARL, r18
	std	Z+ucb_diskaddr+0, r18
	std	Z+ucb_diskaddr+1, r19
	ret
rlv12_rwfail:
;
;	
;
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
	sbis	FLAGS_LOG, log__pbn	; PBN Logging requested
	ret				; Nope just return
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
	ret				; attached to the FCB
;----------------------------------------------------------------------------
;
;	Setup a read or write operation
;
;	Input:
;		r24		must be set to DMA direction (0=Write, 1=Read)
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
	lds	r16, BARL
	bst	r24, 0			; Copy over DMA direction
	bld	r16, 0		; 
	lds	r17, BARH
	lds	r18, BAEL
	dmaaddr	r16, r17, r18
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
	
	ldd	r16, Z+fcb_Flag		; 
	bst	r16, F__Contig		; Get the file is contiguous flag
	ldd	r16, Y+P_Flag		;
	bld	r16, P__Contig		; Mark contiguous SD-Card transfer
	std	Y+P_Flag, r16		;
	
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

	ldd	r16, Y+P_Flag		;
	sbr	r16, (1<<P__Contig)	;
	std	Y+P_Flag, r16		; Partitions are always contiguous

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
	logtr	3, wdcl, wdch
;
;	Setup the return registers
;
rlv12_rwsetup040:
	ldd	r16, Y+P_Flag
	lds	r18, DARL		; Get starting sector
	bst	r18, 0			; If we start with an odd sector
	bld	r16, P__Skip		; we need to skip the first 256bytes
	std	Y+P_Flag, r16		; of the sector 
	ldi	r16, low(sdbuffer)	; 
	ldi	r17, high(sdbuffer)	; 
	std	Y+P_Address+0, r16	; Set buffer address for SD-Card block
	std	Y+P_Address+1, r17	; 
	std	Y+P_Wordcount+0, wdcl	; Set word count in parameter block
	std	Y+P_Wordcount+1, wdch
	movw	addrh:addrl, r17:r16
	clr	count
	ret

;;;------------------------------------------------------------------------
;;;
;;;	Called by main and bus init interrupt, destroys zh and zl but
;;;	makes no assumption regarding preset registers
;;;
rlv12_reset:
	ldi	zl, (1<<CSR_CRDY)	;;; Mark Controller is ready
	clr	zh
	sts	CSRL, zl
	sts	CSRH, zh
	sbi	b_CRDY
	sts	BARL, zh
	sts	BARH, zh
	sts	DARL, zh
	sts	DARH, zh
	sts	MPR_Fifo+0, zh
	sts	MPR_Fifo+1, zh
	sts	MPR_Fifo+2, zh
	sts	MPR_Fifo+3, zh
	sts	BAEL, zh
	sts	BAEH, zh
;
; Reset drives disk address
;
	sts	unittable+ucb_size*0+ucb_diskaddr+0, zh	;
	sts	unittable+ucb_size*0+ucb_diskaddr+1, zh	; 
	sts	unittable+ucb_size*1+ucb_diskaddr+0, zh	; 
	sts	unittable+ucb_size*1+ucb_diskaddr+1, zh	; 
	sts	unittable+ucb_size*2+ucb_diskaddr+0, zh	; 
	sts	unittable+ucb_size*2+ucb_diskaddr+1, zh	; 
	sts	unittable+ucb_size*3+ucb_diskaddr+0, zh	; 
	sts	unittable+ucb_size*3+ucb_diskaddr+1, zh	; 
	ret

.undef	crcl
.undef	crch
.undef	datal	
.undef	datah	
.undef	logptrl	
.undef	logptrh	
.undef	wdcl	
.undef	wdch
.undef	count
.undef	flags
.undef	addrl
.undef	addrh
.undef	ucbl
.undef	ucbh
