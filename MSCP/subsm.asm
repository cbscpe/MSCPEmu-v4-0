;
; given a unit number, return the address of the associated UCB (or NULL)
;
; note that this routine always updates the "offline" and "write protect"
; states; further, if a unit has just left the "offline" state, a UNIT NOW
; AVAILABLE attention message is generated
;
; In RQDX3 source code we have the array 
;
;	globaldef byte		*ucbs[4];
;
; with an array of pointers to UCBs. getucb will convert a unit number to a UCB
; address. It will do so by subtracting unitbase from the unitnumber and then
; check if there is an entry at the index. 
;
; The unitnumber must be higher or equal to unitbase and the resulting unitnumber
; must be a valid index, i.e. unitnumber < unitbase + max_units.
;
; If the unit exists it will do some checks and eventually read the disk. 
;
; Instead of *ucbs[4] we have unittable and as always this is a table of UCBs 
; like in the RLV12 emulator and each UCB is exactly 16 bytes.
;
;
getucb:;(int16 unitnumber:r25:r24)
	lds	zl, unitbase+0
	lds	zh, unitbase+1
	sub	r24, zl
	sbc	r25, zh
	clr	zl
	clr	zh
	tst	r25
	brne	getucb000
	cpi	r24, units
	brsh	getucb000		; not a valid unit number
	mov	zl, r24
	swap	zl
	subi	zl, low(-unittable)	; then add base address of 
	sbci	zh, high(-unittable)
getucb000:
	movw	r25:r24, zh:zl
	ret

