;
; We will in fact only use very little from the original UCB in the RQDX3
; firmware. All the information which is related to the drive can be
; ommitted. Also we do not implement any seek algorithm and we do not need
; any information regarding the format
;
;
; The standard UCB

recordstart	ucb
record		ucb, status, 1
	.equ	ucb__drdy	= 0	; Report Drive is Ready
	.equ	ucb__part	= 1	; Unit is attached to a partition
	.equ	ucb__file	= 2	; Unit is attached to a file
	.equ	ucb__seek	= 3	; Seek in Progress
	.equ	ucb__de		= 4	; Drive Error
record		ucb, flags, 1		; Unit flags
record		ucb, type, 1		; Unit specific status
record		ucb, reserved, 1	; ...
record		ucb, imgptr, 2		; Pointer to partition or file control block
record		ucb, disksize, 4	; Disk Size to report 
record		ucb, lock, 2		; Lock word to let the unit job wait
record		ucb, diskaddr, 2	; Unit disk address register
record		ucb, seektimer, 2	; 
recordend	ucb, size



/*
 *  file = UCB.H
 *  project = RQDX3
 *  author = Stephen F. Shirron
 *
 *  definition of $UCB structure
 *
 *  hostsize		-- number of available host LBNs		ucb_disksize
 *  flags		-- MSCP flags (definition in MSCP.H)		ucb_flags
 *  media		-- media identifier (creation of Ed Gardner)	ucb_imgptr**
 *  volume		-- serial number of unit
 *  state		-- unit state
 *	us_onl		--     unit is online to a host
 *	us_ofl		--     unit is offline and unusable
 *	us_rd		--     type is RD (hard disk)
 *	us_rx		--     type is RX (floppy disk)
 *	us_imf		--     ignore media format error (don't use RCT)
 *	us_unk		--     unit is of unknown type
 *	us_mfe		--     unit is not formatted (media format error)
 *	us_hs3		--     "head select 3" is important to this unit
 *	us_50		--     floppy is RX50
 *	us_33		--     floppy is RX33
 *	us_tsf		--     floppy uses DEC's ten sector format
 *	us_up		--     current elevator direction (up or down)
 *	us_fct		--     LBN being replaced is from FCT, so shortcut
 *  type		-- unit class and model value			ucb_type
 */

**)	ucb_imgptr either points to partition control block or file control block
	either will have a drive tabel entry pointer
	
;
;	MSCP UCB
;	
;	Again UCB is 16bytes long and there can be up to 16 UCBs
;	
;	Unitnumbers are continguous but my start at a value different from 0
;

	
recordstart	ucb
record		ucb, status, 1
	.equ	ucb__part	= 1	; Unit is attached to a partition
	.equ	ucb__file	= 2	; Unit is attached to a file
	.equ	us_onl		= 4
	.equ	us_ofl		= 5
	.equ	us_imf		= 6
	.equ	us_unk		= 7

record		ucb, flags, 1		; Unit flags
	.equ	uf_cmr
	.equ	uf_cmw
	.equ	uf_rpl
	.equ	uf_rmv
	.equ	uf_wpd
	.equ	uf_wph
	.equ	uf_wps
record		ucb, type, 2		; Unit specific status
record		ucb, imgptr, 2		; Pointer to partition or file control block
record		ucb, disksize, 4	; Disk Size to report 
record		ucb, lock, 2		; Lock word to let the unit job wait
record		ucb, diskaddr, 2	; Unit disk address register
record		ucb, seektimer, 2	; 
recordend	ucb, size
