;=============================================================================
;
;	This is the data segment
;
;
	.dseg
	align	8
;
;	Job Stacks
;
;	Note: the stacks could be made much smaller. 
;
;	PC	2
;	Reg	32
;	SREG	1
;	Level0	9	(tick)
;	Level1	7
;	RT-OS	9	-> 60bytes
;	Job	?	call/rcall nesting and push in each sub-routine
;
RAMINITSTART:
		.byte	256		; Main Job (User Interface)
usersp0:
		.byte	256		; SD-Card Detect and Activity LED Job
usersp1:
		.byte	256		; Main Disk Emulator JOB 
usersp2:
		.byte	256		; Dummy JOB (only during testing)
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

partitionid:	.byte	1
volumeid:	.byte	1
InitCommand:	.byte	2
led_oneshot:	.byte	1

;--------------------------------------------------------------------------
;
;	Queue Header for malloc() and free()
;
heap:		.byte	4
.equ	heapstart	= 0x6000
.equ	heapsize	= 0x1000



	align	4
log_pointer:	.byte	2		; current pointer into circular logging buffer
daticount:	.byte	1
datocount:	.byte	1
iackcount:	.byte	1
initcount:	.byte	1
		.byte	4

;--------------------------------------------------------------------------
;
;	Data Segments of external modules
;	
.include "monitor-v2-0.inc"		; Interactive monitor
.include "print-v2-0.inc"		; Print routine
.include "tparse-v2-0.inc"		; Table Driven Parser
.include "rlv12-v2-0.inc"		; Disk Emulator

RAMINITEND:
;--------------------------------------------------------------------------
;
;	Re-Init Data Area
;
;	The Re-Init Data Area is not initialised when a software reset
;	has been issued. Else it will be zeroized
;	
	align	4
sd_status:	.byte	1
.equ		sd__v1		= 0	; If card is a version 2 card
.equ		sd__v2		= 1	; If card is a version 2 card
.equ		sd__init	= 2	; Card could be initialised
.equ		sd__ccs		= 3	; Card Capacity Support
.equ		sd__reset	= 7	; Card could be reset successfully
reset_status:	.byte	1