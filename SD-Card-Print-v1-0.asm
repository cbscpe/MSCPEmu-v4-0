;=============================================================================
;
; 	Print Responses
;
;	R1
;
;	+-+-+-+-+-+-+-+-+
;	|0| | | | | | | |
;	+-+-+-+-+-+-+-+-+
;	   | | | | | | +- in idle state
;	   | | | | | +--- erase reset
;	   | | | | +----- illegal command
;	   | | | +------- com crc error
;	   | | +--------- erase sequence error
;	   | +----------- address error
;	   +------------- parameter error
;

#define PARAM_ERROR		6
#define ADDR_ERROR		5
#define ERASE_SEQ_ERROR		4
#define CRC_ERROR		3
#define ILLEGAL_CMD		2
#define ERASE_RESET		1
#define IN_IDLE			0

SD_PRINT_R1:
;void SD_printR1(uint8_t res)
	sbrs	r24, 7
	rjmp	SD_PRINT_R1_010
	call	print
	.db	0x09, "Error: MSB = 1", CR, LF, 0
	ret
	
SD_PRINT_R1_010:
	tst	r24
	brne	SD_PRINT_R1_020
	call	print
	.db	0x09, "Card Ready", CR, LF, 0
	ret

SD_PRINT_R1_020:
	sbrs	r24, PARAM_ERROR
	rjmp	SD_PRINT_R1_030
	call	print
	.db	0x09, "Parameter Error", CR, LF, 0, 0

SD_PRINT_R1_030:
	sbrs	r24, ADDR_ERROR
	rjmp	SD_PRINT_R1_040
	call	print
	.db	0x09, "Address Error", CR, LF, 0, 0

SD_PRINT_R1_040:
	sbrs	r24, ERASE_SEQ_ERROR
	rjmp	SD_PRINT_R1_050
	call	print
	.db	0x09, "Erase Sequence Error", CR, LF, 0

SD_PRINT_R1_050:
	sbrs	r24, CRC_ERROR
	rjmp	SD_PRINT_R1_060
	call	print
	.db	0x09, "CRC Error", CR, LF, 0, 0

SD_PRINT_R1_060:
	sbrs	r24, ILLEGAL_CMD
	rjmp	SD_PRINT_R1_070
	call	print
	.db	0x09, "Illegal Command", CR, LF, 0, 0

SD_PRINT_R1_070:
	sbrs	r24, ERASE_RESET
	rjmp	SD_PRINT_R1_080
	call	print
	.db	0x09, "Erase Reset Error", CR, LF, 0, 0

SD_PRINT_R1_080:
	sbrs	r24, IN_IDLE
	rjmp	SD_PRINT_R1_090
	call	print
	.db	0x09, "In Idle State", CR, LF, 0, 0

SD_PRINT_R1_090:
	ret
;
;
;
;
#define OUT_OF_RANGE		7
#define ERASE_PARAM		6
#define WP_VIOLATION		5
#define CARD_ECC_FAILED		4
#define CC_ERROR		3
#define ERROR			2
#define WP_ERASE_SKIP		1
#define CARD_LOCKED		0

SD_PRINT_R2:
;void SD_printR2(uint8_t *res)
	movw	zh:zl, r25:r24
	ldd	r24, Z+0
	rcall	SD_Print_R1
	ldd	r24, Z+0
	cpi	r24, 0xFF
	brne	SD_PRINT_R2_010
	ret

SD_PRINT_R2_010:
	ldd	r24, Z+1
	cpi	r24, 0x00
	brne	SD_PRINT_R2_020
	call	print
	.db	0x09, "No R2 Error", CR, LF, 0, 0
	
SD_PRINT_R2_020:
	sbrs	r24, OUT_OF_RANGE
	rjmp	SD_PRINT_R2_030
	call	print
	.db	0x09, "No R2 Error", CR, LF, 0, 0
	
SD_PRINT_R2_030:
	sbrs	r24, ERASE_PARAM
	rjmp	SD_PRINT_R2_040
	call	print
	.db	0x09, "Erase Parameter", CR, LF, 0, 0
	
SD_PRINT_R2_040:
	sbrs	r24, WP_VIOLATION
	rjmp	SD_PRINT_R2_050
	call	print
	.db	0x09, "WP Violation", CR, LF, 0
	
SD_PRINT_R2_050:
	sbrs	r24, CARD_ECC_FAILED
	rjmp	SD_PRINT_R2_060
	call	print
	.db	0x09, "ECC Failed", CR, LF, 0
	
SD_PRINT_R2_060:
	sbrs	r24, CC_ERROR
	rjmp	SD_PRINT_R2_070
	call	print
	.db	0x09, "CC Error", CR, LF, 0
	
SD_PRINT_R2_070:
	sbrs	r24, ERROR
	rjmp	SD_PRINT_R2_080
	call	print
	.db	0x09, "Error", CR, LF, 0, 0
	
SD_PRINT_R2_080:
	sbrs	r24, WP_ERASE_SKIP
	rjmp	SD_PRINT_R2_090
	call	print
	.db	0x09, "WP Erase Skip", CR, LF, 0, 0
	
SD_PRINT_R2_090:
	sbrs	r24, CARD_LOCKED
	rjmp	SD_PRINT_R2_100
	call	print
	.db	0x09, "Card Locked", CR, LF, 0, 0
	
SD_PRINT_R2_100:
	ret

;-----------------------------------------------------------------------------
;
; 	R3
;
;	39            32 31              23              15            0
;	+-+-+-+-+-+-+-+-+---------------+---------------+---------------+
;	|0| | | | | | | |                                               |
;	+-+-+-+-+-+-+-+-+---------------+---------------+---------------+
;       \______  _______/
;	       \/
;              R1
;
;	Bit	Description
;	0-6	reserved
;	7	reserved for low-voltage
;	8-14	reserved
;	15	2.7-2.8 Volts
;	16	2.8-2.9 Volts
;	17	2.9-3.0 Volts
;	18	3.0-3.1 Volts
;	19	3.1-3.2 Volts
;	20	3.2-3.3 Volts
;	21	3.3-3.4 Volts
;	22	3.4-3.5 Volts
;	23	3.5-3.6 Volts
;	24	Switching to 1.8V accepted
;	25-28	reserved
;	29	UHS-II Card Status
;	30	Card Capacity Status
;	31	Card power up status bit (busy)
;	
#define POWER_UP_STATUS		7
#define CCS_VAL			6
#define VDD_2728		7
#define VDD_2829		0
#define VDD_2930		1
#define VDD_3031		2
#define VDD_3132		3
#define VDD_3233		4
#define VDD_3334		5
#define VDD_3435		6
#define VDD_3536		7


SD_PRINT_R3:
;void SD_printR3(uint8_t *res)
	movw	zh:zl, r25:r24
	ldd	r24, Z+0
	rcall	SD_PRINT_R1
	ldd	r24, Z+0
	cpi	r24, 2
	brlo	SD_PRINT_R3_010
	ret

SD_PRINT_R3_010:
	call	print
	.db	0x09, "Card Power Up Status: ", 0
	ldd	r24, Z+1
	sbrs	r24, POWER_UP_STATUS
	rjmp	SD_PRINT_R3_020
	call	print
	.db	"READY", CR, LF, 0
	ldi	r18, '0'
	sbrc	r24, CCS_VAL
	ldi	r18, '1'
	sts	pprint+0, r18
	call	print
	.db	0x09, "CCS Status: ", 0xC90, CR, LF, 0, 0
	rjmp	SD_PRINT_R3_030

SD_PRINT_R3_020:
	call	print
	.db	"BUSY", CR, LF, 0, 0
SD_PRINT_R3_030:
	call	print
	.db	0x09, "VDD Window: ", 0

	ldd	r24, Z+3
	sbrs	r24, VDD_2728
	rjmp	SD_PRINT_R3_040
	call	print
	.db	"2.7-2.8, ", 0
	
SD_PRINT_R3_040:
	ldd	r24, Z+2
	sbrs	r24, VDD_2829
	rjmp	SD_PRINT_R3_050
	call	print
	.db	"2.8-2.9, ", 0
	
SD_PRINT_R3_050:
	sbrs	r24, VDD_2930
	rjmp	SD_PRINT_R3_060
	call	print
	.db	"2.9-3.0, ", 0
	
SD_PRINT_R3_060:
	sbrs	r24, VDD_3031
	rjmp	SD_PRINT_R3_070
	call	print
	.db	"3.0-3.1, ", 0
	
SD_PRINT_R3_070:
	sbrs	r24, VDD_3132
	rjmp	SD_PRINT_R3_080
	call	print 
	.db	"3.1-3.2, ", 0
	
SD_PRINT_R3_080:
	sbrs	r24, VDD_3233
	rjmp	SD_PRINT_R3_090
	call	print
	.db	"3.2-3.3, ", 0
	
SD_PRINT_R3_090:
	sbrs	r24, VDD_3334
	rjmp	SD_PRINT_R3_100
	call	print
	.db	"3.3-3.4, ", 0
	
SD_PRINT_R3_100:
	sbrs	r24, VDD_3435
	rjmp	SD_PRINT_R3_110
	call	print
	.db	"3.4-3.5, ", 0
	
SD_PRINT_R3_110:
	sbrs	r24, VDD_3536
	rjmp	SD_PRINT_R3_120
	call	print
	.db	"3.5-3.6", 0
	
SD_PRINT_R3_120:
	call	print
	.db	CR, LF, 0, 0
	ret
;-----------------------------------------------------------------------------
;
; 	R7
;
;	39            32 31   28 27           12 11    8 7             0
;	+-+-+-+-+-+-+-+-+-------+---------------+-------+---------------+
;	|0| | | | | | | |cmd-ver|   reserved    | volt. | pattern echo  |
;	+-+-+-+-+-+-+-+-+-------+---------------+-------+---------------+
;       \______  _______/
;	       \/
;              R1

#define CMD_VER			0xF0
#define VOL_ACC			0x1F
#define VOLTAGE_ACC_27_33	0b00000001
#define VOLTAGE_ACC_LOW		0b00000010
#define VOLTAGE_ACC_RES1	0b00000100
#define VOLTAGE_ACC_RES2	0b00001000

SD_PRINT_R7:
;void SD_printR7(uint8_t *res)
	movw	zh:zl, r25:r24
	ldd	r24, Z+0
	rcall	SD_PRINT_R1
	ldd	r24, Z+0
	cpi	r24, 2
	brlo	SD_PRINT_R7_010
	ret
SD_PRINT_R7_010:
	ldd	r24, Z+1
	andi	r24, CMD_VER
	swap	r24
	sts	pprint+0, r24
	call	print
	.db	0x09, "Command Version: ", 0x80, CR, LF, 0
	call	print
	.db	0x09, "Voltage Accepted: ", 0
	ldd	r24, Z+3
	andi	r24, VOL_ACC
	cpi	r24, VOLTAGE_ACC_27_33
	brne	SD_PRINT_R7_020
	call	print
	.db	"2.7-3.6V", CR, LF, 0, 0
	rjmp	SD_PRINT_R7_060

SD_PRINT_R7_020:
	cpi	r24, VOLTAGE_ACC_LOW
	brne	SD_PRINT_R7_030
	call	print
	.db	0x09, "LOW VOLTAGE", CR, LF, 0, 0
	rjmp	SD_PRINT_R7_060

SD_PRINT_R7_030:
	cpi	r24, VOLTAGE_ACC_RES1
	brne	SD_PRINT_R7_050
	call	print
	.db	0x09, "RESERVED", CR, LF, 0
	rjmp	SD_PRINT_R7_060

SD_PRINT_R7_040:
	cpi	r24, VOLTAGE_ACC_RES2
	brne	SD_PRINT_R7_050
	call	print
	.db	0x09, "RESERVED", CR, LF, 0
	rjmp	SD_PRINT_R7_060

SD_PRINT_R7_050:
	call	print
	.db	0x09, "NOT DEFINED", CR, LF, 0, 0

SD_PRINT_R7_060:
	ldd	r24, Z+4
	sts	pprint+0, r24
	call	print
	.db	0x09, "Echo: 0x", 0x80, CR, LF, 0, 0
	ret

;-----------------------------------------------------------------------------
;
;	CSD Version 1.0
;	
;	Name		Position	Byte Offset	Size in Bits
;	
;	CSD_STRUCTURE	127:126		0		2
;	-		125:120		0		6
;	TAAC		119:112		1		8
;	NSAC		111:104		2		8
;	TRAN_SPPED	103:96		3		8
;	CCC		95:84		4, 5		12
;	READ_BL_LEN     83:80		5		4
;	READ_BL_PART	79		6		1
;	WRITE_BLK_MIS	78		6		1
;	READ_BLK_MIS	77		6		1
;	DSR_IMP		76		6		1
;	-		75:74		6		6
;	C_SIZE		73:62		6,7,8		12
;	VDD_R_CURR_MIN	61:59		8		3
;	VDD_R_CURR_MAX	58:56		8		3
;	VDD_W_CURR_MIN	55:53		9		3
;	VDD_W_CURR_MAX	52:50		9		3
;	C_SIZE_MULT	49:47		9,10		3
;	ERASE_BLK_EN	46		10		1
;	SECTOR_SIZE	45:39		10,11		7
;	WP_GRP_SIZE	38:32		11		7
;	WP_GRP_ENABLE	31		12		1
;	-		30:29		12		2
;	R2W_FACTOR	28:26		12		3
;	WRITE_BL_LEN	25:22		12,13		4
;	WRITE_BL_PART	21		13		1
;	-		20:16		13		5
;	FILE_FORMAT_GRP 15		14		1
;	COPY		14		14		1
;	PERM_WRITE_PROT	13		14		1
;	TMP_WRITE_PROT	12		14		1
;	FILE_FORMAT	11:10		14		2
;	-		9:8		14		2
;	CRC7		7:1		15		7
;	STOP_BIT	0		15		1
;
;
;	CSD Version 2.0
;	
;	Name		Position	Byte Offset	Size in Bits
;	
;	CSD_STRUCTURE	127:126		0		2
;	-		125:120		0		6
;	TAAC		119:112		1		8
;	NSAC		111:104		2		8
;	TRAN_SPPED	103:96		3		8
;	CCC		95:84		4, 5		12
;	READ_BL_LEN     83:80		5		4
;	READ_BL_PART	79		6		1
;	WRITE_BLK_MIS	78		6		1
;	READ_BLK_MIS	77		6		1
;	DSR_IMP		76		6		1
;	-		75:70		6,7		6
;	C_SIZE		69:48		7,8,9		22
;	-		47		10		1
;	ERASE_BLK_EN	46		10		1
;	SECTOR_SIZE	45:39		10,11		7
;	WP_GRP_SIZE	38:32		11		7
;	WP_GRP_ENABLE	31		12		1
;	-		30:29		12		2
;	R2W_FACTOR	28:26		12		3
;	WRITE_BL_LEN	25:22		12,13		4
;	WRITE_BL_PART	21		13		1
;	-		20:16		13		5
;	FILE_FORMAT_GRP 15		14		1
;	COPY		14		14		1
;	PERM_WRITE_PROT	13		14		1
;	TMP_WRITE_PROT	12		14		1
;	FILE_FORMAT	11:10		14		2
;	-		9:8		14		2
;	CRC7		7:1		15		7
;	STOP_BIT	0		15		1
;
SD_PRINT_CSD:
;void SD_printCSD(uint8_t *buf)

	movw	xh:xl, r25:r24		; Copy Buffer Address
	ldi	r16, 15			; 15 Bytes of data
	clr	r18
SD_PRINT_CSD_CRC:
	ld	r17, X+			; Get Next Command byte
	eor	r18, r17		; xor
	mov	zl, r18			; make index
	ldi	zh, high(2*crc7table)	; translate
	lpm	r18, Z			; new CRC
	dec	r16
	brne	SD_PRINT_CSD_CRC

	ori	r18, 0x01		; Stop Bit
	ld	r17, X+
	cpse	r17, r18
	rcall	SD_PRINT_CSD_CRC_ERR 

	movw	zh:zl, r25:r24
	ldd	r18, Z+0
	andi	r18, 0xE0
	swap	r18
	lsr	r18
	lsr	r18
	inc	r18
	ori	r18, '0'
	sts	pprint+0, r18

	ldd	r18, Z+1		; 7, 6-3, 2-0
	andi	r18, 0x07
	sts	pprint+1, r18
	ldd	r18, Z+1
	lsr	r18
	lsr	r18
	lsr	R18
	andi	r18, 0x0F
	sts	pprint+2, r18

	ldd	r18, Z+2
	sts	pprint+3, r18

	ldd	r18, Z+3		; 7, 6-3, 2-0
	andi	r18, 0x07
	sts	pprint+4, r18
	ldd	r18, Z+3
	lsr	r18
	lsr	r18
	lsr	R18
	andi	r18, 0x0F
	sts	pprint+5, r18

	call	print
	.db	"CSD:", CR, LF
	.db	0x09, "CSD Version.. ", 0x90, ".0", CR, LF
	.db	0x09, "TAAC:........ 0x", 0x81, " 0x", 0x82, CR, LF
	.db	0x09, "NSAC:........ 0x", 0x83, CR, LF
	.db	0x09, "TRAN_SPEED:.. 0x", 0x84, " 0x", 0x85, CR, LF, 0, 0
	lds	r18, pprint+0
	cpi	r18, '1'
	breq	SD_PRINT_CSD110
	rjmp	SD_PRINT_CSD200
SD_PRINT_CSD110:
;
;	MULT = 2**(C_SIZE_MULT+2)
;	BLOCKNR = (C_SIZE+1) * MULT
;	BLOCKLEN = 2**READ_BL_LEN
;	Capacity = BLOCKNR * BLOCKLEN = (C_SIZE+1) * 2**(C_SIZE_MULT+2+READ_BL_LEN)
;
	ldd	r18, Z+6			; Isolate bits 73:62
	ldd	r17, Z+7
	ldd	r16, Z+8
	andi	r18, 0x03
	andi	r16, 0xC0
	add	r16, r16
	adc	r17, r17
	adc	r18, r18
	add	r16, r16
	adc	r17, r17
	adc	r18, r18			; R18, R17 = C_SIZE
	subi	r17, low(-1)
	sbci	r18, high(-1)			; C_SIZE+1

	ldd	r16, Z+9
	ldd	r19, Z+10
	andi	r16, 0x03
	andi	r19, 0x80
	add	r19, r19
	adc	r16, r16			; r16 = C_SIZE_MULT 0..7
	subi	r16, -2				; r16 = C_SIZE_MULT+2 2**2..2**9

	ldd	r19, Z+5
	andi	r19, 0x0F			; READ_BL_LEN valid values are 9,10,11
	add	r16, r19			; Total bits to shift (2**)
	subi	r16, 8				; the value is already "shifted" 8 bits
	clr	r19				; initialize high byte
sd_print_size010:				; 
	add	r17, r17			; Multiply by
	adc	r18, r18
	adc	r19, r19
	dec	r16				; until we reached the total bits
	brne	sd_print_size010
	sts	pprint+11, r19			; Save to print area
	sts	pprint+10, r18
	sts	pprint+9, r17
	sts	pprint+8, zero
	call	print
	.db	0x09, "Capacity ", 0xD8, "bytes.", CR, LF, 0
	rjmp	SD_PRINT_CSD900
	
SD_PRINT_CSD200:
	cpi	r18, '1'
	brne	SD_PRINT_CSD210
	rjmp	SD_PRINT_CSD900
SD_PRINT_CSD210:
;
;	Capacity = C_SIZE+1 * 512k
;	512k = 19 bits
;	1M = 20 bits
;	Capacity in Mbyte is (C_SIZE+1)/2
;
	ldd	r18, Z+7			; Isolate bits 69:48
	andi	r18, 0x3F
	ldd	r17, Z+8
	ldd	r16, Z+9
	subi	r16, byte1(-1)
	sbci	r17, byte2(-1)
	sbci	r18, byte3(-1)			; C_SIZE+1 in 512k units
	lsr	r18
	ror	r17
	ror	r16				; device by two gives Mbytes
	sts	pprint+8, r16
	sts	pprint+9, r17
	sts	pprint+10, r18			; max size would be 16Tbyte
	sts	pprint+11, zero
	call	print
	.db	0x09, "Capacity ", 0xD8, "Mbytes", CR, LF, 0
SD_PRINT_CSD900:
	ret

SD_PRINT_CSD_CRC_ERR:
	sts	pprint+14, r17
	sts	pprint+15, r18
	call	print
	.db	"CSD CRC Error. CRC is 0x", 0x8f, ", CRC calc 0x", 0x8e, CR, LF, 0
	ret

;-----------------------------------------------------------------------------
;
;
;
#define SD_TOKEN_OOR		3
#define SD_TOKEN_CECC		2
#define SD_TOKEN_CC		1
#define SD_TOKEN_ERROR		0

SD_printDataErrToken:
	call	print
	.db	"Error Token:", CR, LF, 0, 0

SD_PRINT_DataErrToken:
	push	r24
	andi	r24, 0xF0
	pop	r24
	breq	SD_PRINT_DataErrToken_010
	call	print
	.db	0x09, "Not an Error Token", CR, LF, 0
	rjmp	SD_PRINT_DataErrToken_050

SD_PRINT_DataErrToken_010:
	sbrs	r24, SD_TOKEN_OOR
	rjmp	SD_PRINT_DataErrToken_020
	call	print
	.db	0x09, "Data out of range", CR, LF, 0, 0

SD_PRINT_DataErrToken_020:
	sbrs	r24, SD_TOKEN_CECC
	rjmp	SD_PRINT_DataErrToken_030
	call	print
	.db	0x09, "Card ECC failed", CR, LF, 0, 0

SD_PRINT_DataErrToken_030:
	sbrs	r24, SD_TOKEN_CC
	rjmp	SD_PRINT_DataErrToken_040
	call	print
	.db	0x09, "CC Error", CR, LF, 0

SD_PRINT_DataErrToken_040:
	sbrs	r24, SD_TOKEN_ERROR
	rjmp	SD_PRINT_DataErrToken_050
	call	print
	.db	0x09, "Error", CR, LF, 0, 0

SD_PRINT_DataErrToken_050:
	ret
