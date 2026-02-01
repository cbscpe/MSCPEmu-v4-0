scanjob:
	ldi	r24, low(1024)
	ldi	r25, high(1024)
	call	delay
	rjmp	scanjob
