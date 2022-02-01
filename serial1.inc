;--------------------------------------------------------------------------
;
;	2021-11-27	.dseg in separate files
;
;
	.dseg
	align	8
tx1ring:	.byte	256
rx1ring:	.byte	256
serout1:	.byte	2		; Serial Out Lock
serin1:		.byte	2		; Serial In Lock
tx1inptr:	.byte	1		; Transmitring insert pointer
tx1outptr:	.byte	1		; Transmitring remove pointer
tx1cnt:		.byte	1		; Transmitring usage counter
rx1inptr:	.byte	1		; Receivering insert pointer
rx1outptr:	.byte	1		; Receivering remove pointer
rx1cnt:		.byte	1		; Receivering usage counter
	

