;--------------------------------------------------------------------------
;
;	SD Card Job
;
;	This routine is run every 5-6 msec. It checks the CD pin and
;	debounces it to detect the insertion or removal of an SD-Card.
;	If this is the case it calls the appropriate routine to
;	initialise the SD-Card and mounts the volumes or it dismounts
;	the volumes
;
;	It also decrements the led_oneshot that is typically set by
;	SD-Card access routines and in case it is zero will switch off
;	the activity LED.
;
carddetect:
;
;	CD (Card Detect) input
;
;	The CD from the SD-Card cage is a normally opened switch that 
;	closes when a SD-Card is inserted.
;
	ldi	yl, 0xFF
	cbi	FLAGS_COMMON, sdcard__insert		; assert pending insertion
	clr	r12
	ldi	yh, 0xFF
	cbi	FLAGS_COMMON, sdcard__remove		; assert pending removal
	clr	r13	
;	
;	Start the debounce timer (5msec) and initialise SD-Card status vars.
;	
carddetect100:
	push	yl
	push	yh
	ldi	r24, low(5)
	ldi	r25, high(5)
	call	delay
	pop	yh
	pop	yl
;
;	Automount/Autodismount and Activity LED
;
	lds	r16, led_oneshot
	dec	r16
	brpl	carddetect110
	clr	r16
	cbi	b_LED
carddetect110:
	sts	led_oneshot, r16

;
;	Keep the last 7 states for sdremove and sdinsert in a FIFO
;
	ldi	r18, 7
	ldi	zl, low(sdprint+7)
	ldi	zh, high(sdprint+7)
carddetect120:
	ld	r16, -Z		; sdprint+6, 5, 4, 3, 2, 1, 0
	std	Z+1, r16	; sdprint+7, 6, 5, 4, 3, 2, 1
	ldd	r16, Z+8	; sdprint+14, 13, 12, 11, 10, 9, 8
	std	Z+9, r16	; sdprint+15, 14, 13, 12, 11, 10, 9
	dec	r18
	brne	carddetect120
;
;	From "Debouncing Tutorial" the following routine gets called
;	regularly and returns true once a leading edge of the switch
;	closure is encountered. Here we are the regularly called routine
;
;	// Service routine called by a timer interrupt
;	bool_t DebounceSwitch2()
;	{
;		static uint16_t State = 0; // Current debounce status
;		State=(State<<1) | !RawKeyPressed() | 0xe000;
;		if(State==0xf000)return TRUE;
;		return FALSE;
;	}
;
;	First simulate RawKeyPressed, this routine returns 1 if the
;	key is pressed. In our case i_CD is low if the SD-Card is inserted
;	and as we need the inverted state we just need to copy i_CD to
;	the Carry bit.
;
	clc
	sbic	i_CD			; Normal Input
	sec
;
;	Now we need to shift State one bit left and put the carry to bit 0,
;	this is in fact the same as just adding State to itself and include
;	the carry bit
;
	adc	yl, yl			; we shift the inputs every 5ms 
	sts	sdprint+0, yl		; store to state FIFO
;
;	In our case state is only a 8-bit integer, but this seems to be
;	sufficient
;
	ori	yl, 0xe0		; and look for a rising edge 
	cpi	yl, 0xf0
	brne	carddetect150
;
;	We have detected a leading key press so the SD-Card has just been
;	inserted
;
	sbi	FLAGS_COMMON, sdcard__insert; set card insertion flag
	inc	r12
carddetect150:
;
;	Now we need to do the inverted logic to detect the falling edge.
;	For this we just need the true value of RawKeyPressed and proceed
;	as above
;
;
	clc
	sbis	i_CD			; Inverted Input
	sec
	adc	yh, yh			; we shift the inputs every 5ms 
	sts	sdprint+8, yh		; store to state FIFO
	ori	yh, 0xe0		; and look for a falling edge (inverted)
	cpi	yh, 0xf0
	brne	carddetect160
	sbi	FLAGS_COMMON, sdcard__remove; set card removal flag
	inc	r13
carddetect160:
;
;	We could have dealt with the edges directly but for the moment
;	I decided to first detect the edges and then process it. I
;	might change this later.
;
	sbic	FLAGS_COMMON, sdcard__remove
	rcall	sdcardremove		; SD-Card was removed
	cbi	FLAGS_COMMON, sdcard__remove
	sbic	FLAGS_COMMON, sdcard__insert
	rcall	sdcardinsert		; SD-Card was inserted
	cbi	FLAGS_COMMON, sdcard__insert
	rjmp	carddetect100		; 
;--------------------------------------------------------------------------
;
;
;
;
sdcardinsert:
	call	print
	.db	LF, CR, "SD Card inserted", 0, 0
	ldi	xl, low(sdprint)
	ldi	xh, high(sdprint)
	rcall	sdcardprbyte
;
;	As we are now using the software reset to restart the whole thing
;	in case of a SD-Card detection we must make sure it was not 
;	previously initialised.
;
	lds	r16, sd_status		; get SD-Card status
	sbrs	r16, sd__init		; do not re-init SD-Card
	call	SD_main			; initialise SD-Card
	call	MountVolume		; 
	sbic	FLAGS_COMMON, sddetect__en	; Is CLI active
	call	redraw_1
	ret

sdcardremove:
	call	print
	.db	LF, CR, "SD Card removed ", 0, 0
	ldi	xl, low(sdprint+8)
	ldi	xh, high(sdprint+8)
	rcall	sdcardprbyte
	call	DismountVolume
	sts	sd_status, zero		; Mark sd-init required
	sbic	FLAGS_COMMON, sddetect__en	; Is CLI active
	call	redraw_1
	ret
;
;
;
sdcardprbyte:
;	jmp	seroutcrlf		; print no more, it is now clear how it works

	ldi	r18, 8
sdcardprbyte000:
	call	print
	.db	" 0x", 0
	ld	r25, X+
	mov	r24, r25
	swap	r24
	ldi	r16, '0'
	andi	r24, 0x0F
	cpi	r24, 10
	brlo	sdcardprbyte010
	ldi	r16, 'A'-10
sdcardprbyte010:
	add	r24, r16
	call	serout
	mov	r24, r25
	ldi	r16, '0'
	andi	r24, 0x0F
	cpi	r24, 10
	brlo	sdcardprbyte020
	ldi	r16, 'A'-10
sdcardprbyte020:
	add	r24, r16
	call	serout
	dec	r18
	brne	sdcardprbyte000
	jmp	seroutcrlf
