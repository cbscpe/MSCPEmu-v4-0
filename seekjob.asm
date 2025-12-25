;--------------------------------------------------------------------------
;
;	DUMMY JOB
;
;	This job executed at a very low priority just makes sure the
;	registers R0... are set to values 0... so we can verify the
;	show job command output, this will be removed when we release
;	the software of course.
;
dummyjob:
	clr	r0
	mov	r1, r0
	inc	r1
	mov	r2, r1
	inc	r2
	mov	r3, r2
	inc	r3
	mov	r4, r3
	inc	r4
	mov	r5, r4
	inc	r5
	mov	r6, r5
	inc	r6
	mov	r7, r6
	inc	r7
	mov	r8, r7
	inc	r8
	mov	r9, r8
	inc	r9
	mov	r10, r9
	inc	r10
	mov	r11, r10
	inc	r11
	mov	r12, r11
	inc	r12
	mov	r13, r12
	inc	r13
	mov	r14, r13
	inc	r14
	mov	r15, r14
	inc	r15
	mov	r16, r15
	inc	r16
	mov	r17, r16
	inc	r17
	mov	r18, r17
	inc	r18
	mov	r19, r18
	inc	r19
	mov	r20, r19
	inc	r20
	mov	r21, r20
	inc	r21
	mov	r22, r21
	inc	r22
	mov	r23, r22
	inc	r23
	mov	r24, r23
	inc	r24
	mov	r25, r24
	inc	r25
	mov	r26, r25
	inc	r26
	mov	r27, r26
	inc	r27
	mov	r28, r27
	inc	r28
	mov	r29, r28
	inc	r29
	mov	r30, r29
	inc	r30
	mov	r31, r30
	inc	r31
	rjmp	dummyjob