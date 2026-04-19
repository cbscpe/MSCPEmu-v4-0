;
;	CCB
;
;

_ccb_state:	.byte	1		; Controller Status
	.equ	cs__ini	= 0		; Currently being initialized
	.equ	cs__act	= 1		; active
	.equ	cs__dup	= 2		; running a DUP program
	.equ	cs__abo	= 3		; the DUP program is being aborted
_ccb_timeout:	.byte	1		; host timeout value (default 60.)
_ccb_type:	.byte	2		; controller class and model value
_ccb_flags:	.byte	2
