;--------------------------------------------------------------------------
;
;	A minimal set of routines that allow parallel jobs on a AVR
;	microcontroller. You need to provide at least the following
;	data section
;
	.dseg
	align	4
runjob:	.byte	2		; Initialise with 0
curjob:	.byte	2		; Initialise with 0
hibjob:	.byte	2		; Initialise with 0
nguard:	.byte	1		; Null Job Stack Guard Byte
;
;	2022-01-26	The stack of the null job must be as large as all nested
;			interrupts may require. In case of two interrupt levels
;			the previous default of 19bytes was not sufficient!
;			Therefore null stack has been increased to 39bytes
;
	.byte	39		; Stack of the Null Job
nstack:
;
;	and of course data sections for the job control blocks (see create:)
;	and the individual stacks of each process and other resources you
;	need in your application (see other routines)
