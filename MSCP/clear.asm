;
;
;
mscp_reset:
	clr	yh						;  1
	ldi	zl, low(cmd)					;  1
	ldi	zh, high(cmd)					;  1
	ldi	yl, ring_sz					;  1
mscp_reset010:
	st	Z+, yh						;  3
	dec	yl						;  1
	brne	mscp_reset010					;  2 -> * 8
								; 52+
;
;
;
	ldi	zl, low(rsp)
	ldi	zh, high(rsp)
	ldi	yl, ring_sz
mscp_reset020:
	st	Z+, yh
	dec	yl
	brne	mscp_reset020
								; 51+
;
;
;
	ldi	yl, mscp_init					;  1
	sts	mscpstatus, yl					;  3
	
;
; Reset drives 
;
	lds	zh, unittable+ucb_size*0+ucb_status+0		;  1
	cbr	zh, (1<<ucb__onl) | (1<<ucb__ofl)		;  1
	sts	unittable+ucb_size*0+ucb_status+0, zh		;  3

	lds	zh, unittable+ucb_size*1+ucb_status+0
	cbr	zh, (1<<ucb__onl) | (1<<ucb__ofl)
	sts	unittable+ucb_size*1+ucb_status+0, zh

	lds	zh, unittable+ucb_size*2+ucb_status+0
	cbr	zh, (1<<ucb__onl) | (1<<ucb__ofl)
	sts	unittable+ucb_size*2+ucb_status+0, zh

	lds	zh, unittable+ucb_size*3+ucb_status+0
	cbr	zh, (1<<ucb__onl) | (1<<ucb__ofl)
	sts	unittable+ucb_size*3+ucb_status+0, zh
								; 24+
	sts	unitbase+0, yh					; yh==0
	sts	unitbase+1, yh
	ldi	zl, 60
	sts	_ccb_timeout, zl
	sts	_pcb_timeout, zl
	ldi	zl, low(cf_rpl)
	ldi	zh, high(cf_rpl)
	sts	_ccb_flags+0, zl
	sts	_ccb_flags+1, zh
	ldi	zl, mscp_model
	ldi	zh, mscp_class
	sts	_ccb_type+0, zl
	sts	_ccb_type+0, zh
	ldi	zl, max_commands - 1
	sts	credits, zl
	ldi	zl, 60 + 1
	sts	ha_time, zl
								; 37+

	ret							;  4+
								;----
								;170
								;===
