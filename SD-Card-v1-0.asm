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
;=============================================================================
;
;	SPI 1 primitives
;
SPI_init:
	ldi	r18, SPI_SSD_bm
	sts	SPI1_CTRLB, r18
;
;	Various Clock rates: CPUCLK/2, CPUCLK/4, CPUCLK/8
;
;	ldi	r18, SPI_CLK2X_bm | SPI_ENABLE_bm | SPI_MASTER_bm | SPI_PRESC_DIV4_gc
	ldi	r18,                SPI_ENABLE_bm | SPI_MASTER_bm | SPI_PRESC_DIV4_gc
;	ldi	r18, SPI_CLK2X_bm | SPI_ENABLE_bm | SPI_MASTER_bm | SPI_PRESC_DIV16_gc
	sts	SPI1_CTRLA, r18		
	sts	sd_status, zero
	ret
;
;
;
SPI_transfer_dummy:
	ldi	r24, 0xff
SPI_transfer:
	sts	SPI1_DATA, r24
SPI_transfer010:
	lds	r18, SPI1_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	SPI_transfer010
	lds	r24, SPI1_DATA
	ret								; Done
;=============================================================================
;
;	Command DEFs
;
#define CMD0 0
#define CMD0_ARG 0x00000000
#define CMD0_CRC 0x94
#define CMD8 8
#define CMD8_ARG 0x0000001AA
#define CMD8_CRC 0x86
#define CMD9 9
#define CMD9_ARG 0x000000000
#define CMD9_CRC 0xEA
#define CMD58 58
#define CMD58_ARG 0x00000000
#define CMD58_CRC 0xFC
#define CMD55 55
#define CMD55_ARG 0x00000000
#define CMD55_CRC 0x64
#define ACMD41 41
#define ACMD41_ARG 0x40000000
#define ACMD41_CRC 0x76
;=============================================================================
;
;	SD-Card primitive
;
;-----------------------------------------------------------------------------
;
;	Read R1 response
;
;	The R1 response is expected within the next 8 SPI cycles, that is
;	we will try 9 times to get an answer from the SD-Card. When the
;	card responds with something else than 0xFF we return or after the
;	9th try we return whatever the SD-Card returns.
;
SD_readRes1:
; uint8_t SD_readRes1();
	rcall	SPI_transfer_dummy
	cpi	r24, 0xff
	brne	SD_readRes090
	rcall	SPI_transfer_dummy
	cpi	r24, 0xff
	brne	SD_readRes090
	rcall	SPI_transfer_dummy
	cpi	r24, 0xff
	brne	SD_readRes090
	rcall	SPI_transfer_dummy
	cpi	r24, 0xff
	brne	SD_readRes090
	rcall	SPI_transfer_dummy
	cpi	r24, 0xff
	brne	SD_readRes090
	rcall	SPI_transfer_dummy
	cpi	r24, 0xff
	brne	SD_readRes090
	rcall	SPI_transfer_dummy
	cpi	r24, 0xff
	brne	SD_readRes090
	cpi	r24, 0xff
	brne	SD_readRes090
	rcall	SPI_transfer_dummy
SD_readRes090:
	ret
;-----------------------------------------------------------------------------
;
;	Read R3/R7 response
;	
;	First we will read a R1 response and only if the response is either
;	0 or 1 we will continue to read the remaining 5bytes from the R3/R7
;	response
;
SD_readRes3_7:
; void SD_readRes3_7(unit8_t *res)
SD_readRes7:
; void SD_readRes7(uint8_t *res);
	movw	zh:zl, r25:r24
	rcall	SD_readRes1
	std	Z+0, r24
	cpi	r24, 2
	brsh	SD_readRes7090
	rcall	SPI_transfer_dummy
	std	Z+1, r24
	rcall	SPI_transfer_dummy
	std	Z+2, r24
	rcall	SPI_transfer_dummy
	std	Z+3, r24
	rcall	SPI_transfer_dummy
	std	Z+4, r24
	rcall	SPI_transfer_dummy
	std	Z+5, r24
SD_readRes7090:
	ret
;-----------------------------------------------------------------------------
;
;	SD Power UP Sequence
;
;	1.	Deselect SD-Card
;	2.	Wait for 1 msec
;	3.	create at least 80 dummy SPI clock cycles
;	4.	Deselect SD-Card
;	5.	Send dummy data
;
SD_powerUpSeq:
	sbi	b_SS
	ldi	r24, low(1)
	ldi	r25, high(1)
	call	delay
	rcall	SPI_transfer_dummy
	rcall	SPI_transfer_dummy
	rcall	SPI_transfer_dummy
	rcall	SPI_transfer_dummy
	rcall	SPI_transfer_dummy
	rcall	SPI_transfer_dummy
	rcall	SPI_transfer_dummy
	rcall	SPI_transfer_dummy
	rcall	SPI_transfer_dummy
	rcall	SPI_transfer_dummy
	sbi	b_SS
	rcall	SPI_transfer_dummy
	ret
;-----------------------------------------------------------------------------
;
;	Send a Command to the SD-Card
;
;	- now with built-in crc-7 calculation	
;
SD_command:
; void SD_command(uint8_t *cmd); !! rjh (uint8_t cmd, uint32_t arg, uint8_t crc);
	push	r25
	push	r24
	rcall	SD_commandCRC		; Calculate CRC-7
	pop	zl
	pop	zh
	std	Z+5, r24		; Save CRC
	ldd	r24, Z+0
	ori	r24, 0x40		; Bit7=0, Bit6=1, Bit5..0 6-bit command
	rcall	SPI_transfer
	ldd	r24, Z+1
	rcall	SPI_transfer
	ldd	r24, Z+2
	rcall	SPI_transfer
	ldd	r24, Z+3
	rcall	SPI_transfer
	ldd	r24, Z+4
	rcall	SPI_transfer
	ldd	r24, Z+5
	ori	r24, 0x01		; Stop bit
	rcall	SPI_transfer
	ret
;
;	Calculate CRC-7 left adjusted as required by SD-Card
;
SD_commandCRC:
; uint8_t SD_commandCRC(uint8_t *cmd)
	movw	xh:xl, r25:r24
	ldi	r24, 0x40		; Initiate CRC with start of Bit7=0, Bit6=1
	ldi	r16, 5			; 5 bytes
SD_commandCRC010:
	ld	r17, X+			; Get Next Command byte
	eor	r24, r17		; xor
	mov	zl, r24			; make index
	ldi	zh, high(2*crc7table)	; translate
	lpm	r24, Z			; new CRC
	dec	r16
	brne	SD_commandCRC010
	ret				; r24 contains CRC7 left-adjusted
;-----------------------------------------------------------------------------
;
;	Send Various commands
;
#define CMD17 17
#define SD_MAX_READ_ATTEMPTS 100

#define CMD24 24
#define SD_MAX_WRITE_ATTEMPTS 250

#define SD_READY	0x00
#define SD_START_TOKEN	0xFE
;
;-----------------------------------------------------------------------------
;
;	Send a Commands to the SD-Card and print results
;
SD_goIdleState:; uint8_t SD_goIdleState();
	rcall	SPI_transfer_dummy
	cbi	b_SS
	rcall	SPI_transfer_dummy
	;+parameter on stack
	ldi	r18, CMD0_CRC
	push	r18
	ldi	r18, byte1(CMD0_ARG)
	push	r18
	ldi	r18, byte2(CMD0_ARG)
	push	r18
	ldi	r18, byte3(CMD0_ARG)
	push	r18
	ldi	r18, byte4(CMD0_ARG)
	push	r18
	in	r24, CPU_SPL
	in	r25, CPU_SPH
	ldi	r18, CMD0
	push	r18
	rcall	SD_command
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	;-parameter on stack
	rcall	SD_readRes1
	push	r24
	rcall	SPI_transfer_dummy
	sbi	b_SS
	rcall	SPI_transfer_dummy
	pop	r24
	ret

SD_sendIfCond:;void SD_sendIfCond(uint8_t *res)
	push	r24
	push	r25
	rcall	SPI_transfer_dummy
	cbi	b_SS
	rcall	SPI_transfer_dummy
	;+parameter on stack
	ldi	r18, CMD8_CRC
	push	r18
	ldi	r18, byte1(CMD8_ARG)
	push	r18
	ldi	r18, byte2(CMD8_ARG)
	push	r18
	ldi	r18, byte3(CMD8_ARG)
	push	r18
	ldi	r18, byte4(CMD8_ARG)
	push	r18
	in	r24, CPU_SPL
	in	r25, CPU_SPH
	ldi	r18, CMD8
	push	r18
	rcall	SD_command
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	;-parameter on stack
	pop	r25
	pop	r24
	rcall	SD_readRes7
	rcall	SPI_transfer_dummy
	sbi	b_SS
	rcall	SPI_transfer_dummy
	ret	
	
SD_readOCR:; void SD_readOCR(uint8_t *res)
	push	r24
	push	r25
	rcall	SPI_transfer_dummy
	cbi	b_SS
	rcall	SPI_transfer_dummy
	;+parameter on stack
	ldi	r18, CMD58_CRC
	push	r18
	ldi	r18, byte1(CMD58_ARG)
	push	r18
	ldi	r18, byte2(CMD58_ARG)
	push	r18
	ldi	r18, byte3(CMD58_ARG)
	push	r18
	ldi	r18, byte4(CMD58_ARG)
	push	r18
	in	r24, CPU_SPL
	in	r25, CPU_SPH
	ldi	r18, CMD58
	push	r18
	rcall	SD_command
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	;-parameter on stack
	pop	r25
	pop	r24
	rcall	SD_readRes3_7
	rcall	SPI_transfer_dummy
	sbi	b_SS
	rcall	SPI_transfer_dummy
	ret
	
SD_sendApp:; uint8_t SD_sendApp()
	rcall	SPI_transfer_dummy
	cbi	b_SS
	rcall	SPI_transfer_dummy
	;+parameter on stack
	ldi	r18, CMD55_CRC
	push	r18
	ldi	r18, byte1(CMD55_ARG)
	push	r18
	ldi	r18, byte2(CMD55_ARG)
	push	r18
	ldi	r18, byte3(CMD55_ARG)
	push	r18
	ldi	r18, byte4(CMD55_ARG)
	push	r18
	in	r24, CPU_SPL
	in	r25, CPU_SPH
	ldi	r18, CMD55
	push	r18
	rcall	SD_command
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	;-parameter on stack
	rcall	SD_readRes1
	push	r24
	rcall	SPI_transfer_dummy
	sbi	b_SS
	rcall	SPI_transfer_dummy
	pop	r24
	ret
	
SD_sendOpCond:; uint8_t SD_sendOpCond()
	rcall	SPI_transfer_dummy
	cbi	b_SS
	rcall	SPI_transfer_dummy
	;+parameter on stack
	ldi	r18, ACMD41_CRC
	push	r18
	ldi	r18, byte1(ACMD41_ARG)
	push	r18
	ldi	r18, byte2(ACMD41_ARG)
	push	r18
	ldi	r18, byte3(ACMD41_ARG)
	push	r18
	ldi	r18, byte4(ACMD41_ARG)
	push	r18
	in	r24, CPU_SPL
	in	r25, CPU_SPH
	ldi	r18, ACMD41
	push	r18
	rcall	SD_command
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	;-parameter on stack
	rcall	SD_readRes1
	push	r24
	rcall	SPI_transfer_dummy
	sbi	b_SS
	rcall	SPI_transfer_dummy
	pop	r24
	ret
;=============================================================================
;
;	Monitor Test Routines
;
SD_main:
	push	r5
	push	r4			; Call saved register
	rcall	SPI_init
	rcall	SD_powerUpSeq
	call	print
	.db	"Sending CMD0...", CR, LF, "Response:", CR, LF, 0, 0
	rcall	SD_goIdleState
	rcall	SD_print_R1
	call	print
	.db	"Sending CMD8...", CR, LF, "Response:", CR, LF, 0, 0
;
;	To prepare a response buffer on stack we need to know that
;	pop	stack pointer is pre-incremented
;	push	stack pointer is post-decremented
;
	push	r0;6
	push	r0;5
	push	r0;4
	push	r0;3
	push	r0;2
	lds	r4, CPU_SPL
	lds	r5, CPU_SPH		; this points to where r0 will go
	push	r0;1
	movw	r25:r24, r5:r4		; Buffer Address
	rcall	SD_sendIfCond
	movw	r25:r24, r5:r4		; Buffer Address
	rcall	SD_print_R7
	movw	zh:zl, r5:r4
	ldd	r18, Z+0		;
	ldi	r24, (1<<sd__v2)	; Assume Version 2 or later
	sbrc	r18, ILLEGAL_CMD
	ldi	r24, (1<<sd__v1)	; Version 1 Card
	sts	sd_status, r24
	call	print
	.db	"Sending CMD58...", CR, LF, "Response:", CR, LF, 0
	movw	r25:r24, r5:r4		; Buffer Address
	rcall	SD_readOCR
	movw	r25:r24, r5:r4		; Buffer Address
	rcall	SD_print_R3

	call	print
	.db	"Sending CMD55...", CR, LF, "Response:", CR, LF, 0
	rcall	SD_sendApp
	rcall	SD_print_R1
	call	print
	.db	"Sending ACMD41...", CR, LF, "Response:", CR, LF, 0, 0
	rcall	SD_sendOpCond
	rcall	SD_print_R1

	ldi	r16, 20
SD_main_loop:
	ldi	r24, low(100)
	ldi	r25, high(100)	
	call	delay
	
	call	print
	.db	"Sending CMD55...", CR, LF, "Response:", CR, LF, 0
	rcall	SD_sendApp
	rcall	SD_print_R1
	call	print
	.db	"Sending ACMD41...", CR, LF, "Response:", CR, LF, 0, 0
	rcall	SD_sendOpCond
	rcall	SD_print_R1

	sbrs	r24, IN_IDLE
	rjmp	SD_main_done
	dec	r16
	brne	SD_main_loop
	call	print
	.db	"Card did not become ready after 2 seconds", CR, LF, 0
	rjmp	SD_main_exit
SD_main_done:
	lds	r18, sd_status
	sbr	r18, (1<<sd__init)
	sts	sd_status, r18
	call	print
	.db	"Sending CMD58...", CR, LF, "Response:", CR, LF, 0
	movw	r25:r24, r5:r4		; Buffer Address
	rcall	SD_readOCR
	movw	r25:r24, r5:r4		; Buffer Address
	rcall	SD_print_R3
	movw	zh:zl, r5:r4		; Buffer Address
	ldd	r18, Z+1
	bst	r18, CCS_VAL
	lds	r18, sd_status
	bld	r18, sd__ccs
	sts	sd_status, r18
	
	call	print
	.db	"Sending CMD9...", CR, LF, "Response:", CR, LF, 0, 0
	ldi	r24, low(sdbuffer)
	ldi	r25, high(sdbuffer)
	rcall	SD_readCSD
	cpse	r24, zero
	rjmp	SD_main_exit
	ldi	r24, low(sdbuffer)
	ldi	r25, high(sdbuffer)
	rcall	SD_PRINT_CSD	
	rjmp	SD_main_exit
SD_main_exit:
	pop	r18;1
	pop	r18;2
	pop	r18;3
	pop	r18;4
	pop	r18;5
	pop	r18;6
	pop	r4
	pop	r5			; restore call saved register
	ret
	
SD_readCSD:
; void SD_readOCR(uint8_t *res)
	push	r4
	push	r5
	movw	r5:r4, r25:r24
	rcall	SPI_transfer_dummy
	cbi	b_SS
	rcall	SPI_transfer_dummy
	;+parameter on stack
	ldi	r18, CMD9_CRC
	push	r18
	ldi	r18, byte1(CMD9_ARG)
	push	r18
	ldi	r18, byte2(CMD9_ARG)
	push	r18
	ldi	r18, byte3(CMD9_ARG)
	push	r18
	ldi	r18, byte4(CMD9_ARG)
	push	r18
	in	r24, CPU_SPL
	in	r25, CPU_SPH
	ldi	r18, CMD9
	push	r18
	rcall	SD_command
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	pop	r18
	;-parameter on stack
	rcall	SD_readRes1
	cpse	r24, zero
	rjmp	SD_readCSD090

SD_readCSD010:
	ldi	xl, low(SD_MAX_READ_ATTEMPTS)	; Read Timeout 100ms
	ldi	xh, high(SD_MAX_READ_ATTEMPTS)
SD_readCSD020:
	rcall	SPI_transfer_dummy
	cpi	r24, SD_START_TOKEN		; Data Token
	breq	SD_readCSD040
	cpi	r24, 0xFF			; Busy
	breq	SD_readCSD030
	call	print
	.db	"Read CSD Invalid Data Token 0x", 0x80, CR, LF, 0
	rcall	SD_printDataErrToken		; Error
	ldi	r24, SD_ERR_INV_TOKEN
	rjmp	SD_readCSD099

SD_readCSD030:
	ldi	r24, low(0)
	ldi	r25, high(0)
	call	delay
	sbiw	xh:xl, 1
	brne	SD_readCSD020
	call	print
	.db	"Read CSD no Comand Token after max retries...", CR, LF, 0
	ldi	r24, SD_ERR_NO_TOKEN
	rjmp	SD_readCSD099

SD_readCSD040:
	ldi	xl, low(18)			; CSD=128bits=16bytes+2CRC
	ldi	xh, high(18)
	movw	zh:zl, r5:r4
SD_readCSD050:
	rcall	SPI_transfer_dummy
	st	Z+, r24
	sbiw	xh:xl, 1
	brne	SD_readCSD050
	ldi	r24, SD_SUCCESS
	rjmp	SD_readCSD099
	
SD_readCSD090:
	call	print
	.db	"Read CSD command response error... ", CR, LF, 0
	rcall	SD_print_R1
	ldi	r24, SD_ERROR
SD_readCSD099:
	push	r24
	rcall	SPI_transfer_dummy
	sbi	b_SS
	rcall	SPI_transfer_dummy
	pop	r24
	pop	r5
	pop	r4
	ret	

;-----------------------------------------------------------------------------
;
;	Read one block
;
;	r25:r24	IO-controll block
;
SD_sendRead:				; With Messages
	set
	cpse	zero, zero
SD_CARD_READ:				; w/o Messages
	clt
	push	yl
	push	yh
	movw	yh:yl, r25:r24			; Copy Parameter Block Address
	rcall	SPI_transfer_dummy
	cbi	b_SS
	rcall	SD_setupTimer
	rcall	SPI_transfer_dummy
;
;	To prepare the command parameter on stack we need to know that
;	pop	stack pointer is pre-incremented
;	push	stack pointer is post-decremented
;
	push	r0;6
	push	r0;5
	push	r0;4
	push	r0;3
	push	r0;2
	in	zl, CPU_SPL
	in	zh, CPU_SPH		; this points to where r0 will go
	push	r0;1
	ldi	r18, CMD17
	std	Z+0, r18
	rcall	SD_setBlock
	brtc	SD_sendNoMsg
	call	print
	.db	"Sending CMD17 (read)...", CR, LF, 0
SD_sendNoMsg:
	movw	r25:r24, zh:zl
	rcall	SD_command

	pop	r18;1
	pop	r18;2
	pop	r18;3
	pop	r18;4
	pop	r18;5
	pop	r18;6

	rcall	SD_readRes1
	cpi	r24, SD_READY
	breq	SD_sendRead030
;--	call	print
;--	.db	"Read Comand rejected...", CR, LF, 0
;--	rcall	SD_print_R1
	std	Y+P_Error, r24
	ldi	r24, SD_ERR_CMD_REJ
	rjmp	SD_sendRead999

SD_sendRead030:
	ldi	xl, low(SD_MAX_READ_ATTEMPTS)	; Read Timeout 100ms
	ldi	xh, high(SD_MAX_READ_ATTEMPTS)
SD_sendRead040:
	rcall	SPI_transfer_dummy
	cpi	r24, SD_START_TOKEN	; Data Token
	breq	SD_sendRead060
	cpi	r24, 0xFF		; Busy
;--	breq	SD_sendRead040
	breq	SD_sendRead050
;--	rcall	SD_printDataErrToken	; Error
	std	Y+P_Error, r24
	ldi	r24, SD_ERR_INV_TOKEN
	rjmp	SD_sendRead999

SD_sendRead050:
;
;	Delay is at least nnn milli-seconds. But when in a short loop
;	as here this turns to be almost nnn+1 milli-seconds. Therefore
;	we use 0 as the delay that in all but the first time will be
;	one milli-second
;
	ldi	r24, low(0)
	ldi	r25, high(0)
	call	delay
	sbiw	xh:xl, 1
	brne	SD_sendRead040
;--	call	print
;--	.db	"Read no Comand Token after max retries...", CR, LF, 0
	ldi	r24, SD_ERR_NO_TOKEN
	rjmp	SD_sendRead999

SD_sendRead060:
	push	r4
	push	r5
	clr	r4
	clr	r5
	ldd	xl, Y+P_Address+0
	ldd	xh, Y+P_Address+1
	ldi	r24, low(512)
	ldi	r25, high(512)
	
	ldi	r16, 0xFF
	sts	SPI1_DATA, r16
SD_sendRead080:
	lds	r18, SPI1_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	SD_sendRead080
	lds	r18, SPI1_DATA
	sts	SPI1_DATA, r16		; Next dummy byte
	st	X+, r18
	crc	r18, r4, r5
	sbiw	r25:r24, 1
	brne	SD_sendRead080
	
SD_sendRead081:
	lds	r18, SPI1_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	SD_sendRead081
	lds	r25, SPI1_DATA
	sts	SPI1_DATA, r16		; Next dummy byte
	
SD_sendRead082:
	lds	r18, SPI1_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	SD_sendRead082
	lds	r24, SPI1_DATA
	
;
;	SPI Buffered Mode
;
;		lds	r18, SPI1_CTRLB
;		ori	r18, SPI_BUFEN_bm | SPI_BUFWR_bm
;		sts	SPI1_CTRLB, r18
;
;		ldi	r18, 0xFF			
;		sts	SPI1_DATA, r18		; First write a dummy byte
;	SD_sendRead080:
;		lds	r18, SPI1_INTFLAGS
;		sbrs	r18, SPI_DREIF_bp	; Wait for Data Register Empty
;		rjmp	SD_sendRead080
;
;	SD_sendRead081:
;		ldi	r18, 0xFF		; Send next dummy byte
;		sts	SPI1_DATA, r18
;	SD_sendRead082:
;		lds	r18, SPI1_INTFLAGS
;		sbrs	r18, SPI_RXCIF_bp
;		rjmp	SD_sendRead082		; and wait for byte to be received
;		lds	r18, SPI1_DATA		; Fetch byte
;		st	X+, r18			; Save Byte
;		crc	r18, r4, r5
;		sbiw	r25:r24, 1		; Until done but now when we received
;		brne	SD_sendRead081		; a byte we assume that DREIF is set
;
;		ldi	r18, 0xFF		; Send next dummy byte
;		sts	SPI1_DATA, r18
;	SD_sendRead083:
;		lds	r18, SPI1_INTFLAGS	; We sent one byte more than we 
;		sbrs	r18, SPI_RXCIF_bp	; sent in the loop therefore
;		rjmp	SD_sendRead083		; we can now get the high byte
;		lds	r25, SPI1_DATA		; of the CRC-16
;		std	Y+P_Error+1, r24
;
;		ldi	r18, 0xFF		; Send next dummy byte
;		sts	SPI1_DATA, r18
;	SD_sendRead084:
;		lds	r18, SPI1_INTFLAGS	; Next byte we retrieve is the low
;		sbrs	r18, SPI_RXCIF_bp	; byte of the CRC-16
;		rjmp	SD_sendRead084		; 
;		lds	r24, SPI1_DATA		; 
;		std	Y+P_Error+0, r24
;
;	SD_sendRead085:
;		lds	r18, SPI1_INTFLAGS	; We sent one byte more than we 
;		sbrs	r18, SPI_RXCIF_bp	; sent in the loop so wait for
;		rjmp	SD_sendRead085		; the "dummy" answer
;		lds	r18, SPI1_DATA		; get and discard
;	SD_sendRead086:
;
;		lds	r18, SPI1_CTRLB			; Restore non-buffered mode
;		andi	r18, ~(SPI_BUFEN_bm | SPI_BUFWR_bm)
;		sts	SPI1_CTRLB, r18

	cp	r4, r24		;
	cpc	r5, r25
	pop	r5
	pop	r4
	ldi	r24, SD_SUCCESS
	breq	SD_sendRead999
	
	ldi	r24, SD_ERR_CRC
SD_sendRead999:
	push	r24
	rcall	SPI_transfer_dummy
	sbi	b_SS
	rcall	SD_readTimer
	rcall	SPI_transfer_dummy
	pop	r24
	pop	yh
	pop	yl
	ret
;-----------------------------------------------------------------------------
;
;	Write Block
;
;	r25:r24	IO-controll block
;
SD_sendWrite:				; With messages
	set
	cpse	zero, zero
SD_CARD_WRITE:				; w/o messages
	clt
	push	yl
	push	yh
	movw	yh:yl, r25:r24		; Copy Parameter Block Address
	rcall	SPI_transfer_dummy
	cbi	b_SS
	rcall	SD_setupTimer
	rcall	SPI_transfer_dummy
;
;	To prepare the command parameter on stack we need to know that
;	pop	stack pointer is pre-incremented
;	push	stack pointer is post-decremented
;
	push	r0;6
	push	r0;5
	push	r0;4
	push	r0;3
	push	r0;2
	in	zl, CPU_SPL
	in	zh, CPU_SPH		; this points to where r0 will go
	push	r0;1
	ldi	r18, CMD24
	std	Z+0, r18
	rcall	SD_setBlock		; Set Parameter (Blocknumber/Address)
	movw	r25:r24, zh:zl
	rcall	SD_command		; Send Command

	pop	r18;1
	pop	r18;2
	pop	r18;3
	pop	r18;4
	pop	r18;5
	pop	r18;6

	rcall	SD_readRes1		; Send Command Response
	cpi	r24, SD_READY		; Must be 0x00
	breq	SD_sendWrite010
	ldi	r24, SD_ERR_CMD_REJ
	rjmp	SD_sendWrite999
	
SD_sendWrite010:
	ldi	r24, SD_START_TOKEN	; Start Data Token
	rcall	SPI_transfer		; Send it
	ldd	xl, Y+P_Address+0	; Buffer Address
	ldd	xh, Y+P_Address+1	
	ldi	r24, low(512)
	ldi	r25, high(512)

	push	r4
	push	r5
	clr	r4
	clr	r5


;
;	Non buffered mode
;
SD_sendWrite020:
	ld	r18, X+
	sts	SPI1_DATA, r18		; We assume all data has already been sent
SD_sendWrite021:
	lds	r18, SPI1_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	SD_sendWrite021
	sbiw	r25:r24, 1
	brne	SD_sendWrite020

	sts	SPI1_DATA, r5
SD_sendWrite022:
	lds	r18, SPI1_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	SD_sendWrite022

	sts	SPI1_DATA, r4
SD_sendWrite023:
	lds	r18, SPI1_INTFLAGS
	sbrs	r18, SPI_IF_bp
	rjmp	SD_sendWrite023
	
;
;	SPI Buffered Mode
;
;		lds	r18, SPI1_CTRLB
;		ori	r18, SPI_BUFEN_bm | SPI_BUFWR_bm
;		sts	SPI1_CTRLB, r18
;
;		ld	r18, X+
;		sts	SPI1_DATA, r18		; Start filling buffer with 1st byte
;		crc	r18, r4, r5
;		sbiw	r25:r24, 1		; one byte done
;		rjmp	SD_sendWrite021
;
;	SD_sendWrite020:
;		lds	r18, SPI1_INTFLAGS	; First make sure we read the
;		sbrs	r18, SPI_RXCIF_bp	; byte received from the slave
;		rjmp	SD_sendWrite020		; off the receive buffer
;		lds	r18, SPI1_DATA
;
;	SD_sendWrite021:
;		ld	r18, X+
;		sts	SPI1_DATA, r18		; Send byte
;		crc	r18, r4, r5
;		sbiw	r25:r24, 1
;		brne	SD_sendWrite020		; until all bytes done
;
;	SD_sendWrite022:
;		lds	r18, SPI1_INTFLAGS	; First make sure we read the
;		sbrs	r18, SPI_RXCIF_bp	; byte received from the slave
;		rjmp	SD_sendWrite022		; off the receive buffer
;		lds	r18, SPI1_DATA
;		sts	SPI1_DATA, r5	
;
;	SD_sendWrite023:
;		lds	r18, SPI1_INTFLAGS	; First make sure we read the
;		sbrs	r18, SPI_RXCIF_bp	; byte received from the slave
;		rjmp	SD_sendWrite023		; off the receive buffer
;		lds	r18, SPI1_DATA
;		sts	SPI1_DATA, r4	
;
;	SD_sendWrite024:
;		lds	r18, SPI1_INTFLAGS	; First make sure we read the
;		sbrs	r18, SPI_RXCIF_bp	; byte received from the slave
;		rjmp	SD_sendWrite024		; off the receive buffer
;		lds	r18, SPI1_DATA
;
;	SPI Unbuffered Mode
;
;		lds	r18, SPI1_CTRLB		; Restore non-buffered mode
;		andi	r18, ~(SPI_BUFEN_bm | SPI_BUFWR_bm)
;		sts	SPI1_CTRLB, r18

	pop	r5
	pop	r4
	ldi	xl, low(SD_MAX_WRITE_ATTEMPTS)	
	ldi	xh, high(SD_MAX_WRITE_ATTEMPTS)
SD_sendWrite030:
	rcall	SPI_transfer_dummy	;
	cpi	r24, 0xFF		; Wait for data response which 
	brne	SD_sendWrite040		; has bit 4 cleared -> cannot be 0xFF
	ldi	r24, low(0)
	ldi	r25, high(0)
	call	delay
	sbiw	xh:xl, 1
	brne	SD_sendWrite030
	ldi	r24, SD_ERR_DATA_RSP_TMO
	rjmp	SD_sendWrite999

SD_sendWrite040:			;
	andi	r24, 0x1F		; Mask relevant bits
	cpi	r24, 0x05		; 'Data Accepted' ?
	breq	SD_sendWrite050		; Ok
	std	Y+P_Error, r24
	ldi	r24, SD_ERR_DATA_REJ
	rjmp	SD_sendWrite999

SD_sendWrite050:

	ldi	xl, low(SD_MAX_WRITE_ATTEMPTS)	
	ldi	xh, high(SD_MAX_WRITE_ATTEMPTS)
SD_sendWrite060:
	rcall	SPI_transfer_dummy	;
	cpi	r24, 0x00		; Get status
	brne	SD_sendWrite070		; still BUSY
	ldi	r24, low(0)		; 
	ldi	r25, high(0)
	call	delay
	sbiw	xh:xl, 1
	brne	SD_sendWrite060
	ldi	r24, SD_ERR_RDY_TMO
	rjmp	SD_sendWrite999

SD_sendWrite070:			; Done
	ldi	r24, SD_SUCCESS

SD_sendWrite999:
	push	r24
	rcall	SPI_transfer_dummy
	sbi	b_SS
	rcall	SD_readTimer
	rcall	SPI_transfer_dummy
	pop	r24
	pop	yh
	pop	yl
	ret
;
;	Translate PBN to SD-Card Address according to CCS
;
SD_setBlock:
	lds	r18, sd_status
	sbrs	r18, sd__ccs
	rjmp	SD_setBlock010
;
	ldd	r18, Y+P_Sector+0	; High Capacity Card
	std	Z+4, r18
	ldd	r18, Y+P_Sector+1
	std	Z+3, r18
	ldd	r18, Y+P_Sector+2
	std	Z+2, r18
	ldd	r18, Y+P_Sector+3
	std	Z+1, r18
	std	Z+5, zero
	ret
;
SD_setBlock010:
	std	Z+4, zero		; Standard Capacity Card
	ldd	r18, Y+P_Sector+0
	add	r18, r18
	std	Z+3, r18
	ldd	r18, Y+P_Sector+1
	adc	r18, r18
	std	Z+2, r18
	ldd	r18, Y+P_Sector+2
	adc	r18, r18
	std	Z+1, r18
	std	Z+5, zero
	ret
;=============================================================================
;
;	IO Time Measurement using Timer TCB1 
;
SD_setupTimer:
	sts	TCB1_CNTL, zero		; Just reset the count and let
	sts	TCB1_CNTH, zero		; the timer start with zero
	ret
;
;	Read Timer
;
;	P_Duration	int16
;
SD_readTimer:
	lds	r18, TCB1_CNTL		; Read the current count
	std	Y+P_Duration+0, r18	; value which is the duration
	lds	r18, TCB1_CNTH		; the IO operation took measured
	std	Y+P_Duration+1, r18	; in micro-seconds
	ret
;=============================================================================
;
;	Page aligned CRC tables
;
;	CRC-7 left adjusted https://github.com/spotify/linux/blob/master/lib/crc7.c
;
	align	8
crc7table:
 .db 0x00,0x12,0x24,0x36,0x48,0x5a,0x6c,0x7e,0x90,0x82,0xb4,0xa6,0xd8,0xca,0xfc,0xee
 .db 0x32,0x20,0x16,0x04,0x7a,0x68,0x5e,0x4c,0xa2,0xb0,0x86,0x94,0xea,0xf8,0xce,0xdc
 .db 0x64,0x76,0x40,0x52,0x2c,0x3e,0x08,0x1a,0xf4,0xe6,0xd0,0xc2,0xbc,0xae,0x98,0x8a
 .db 0x56,0x44,0x72,0x60,0x1e,0x0c,0x3a,0x28,0xc6,0xd4,0xe2,0xf0,0x8e,0x9c,0xaa,0xb8
 .db 0xc8,0xda,0xec,0xfe,0x80,0x92,0xa4,0xb6,0x58,0x4a,0x7c,0x6e,0x10,0x02,0x34,0x26
 .db 0xfa,0xe8,0xde,0xcc,0xb2,0xa0,0x96,0x84,0x6a,0x78,0x4e,0x5c,0x22,0x30,0x06,0x14
 .db 0xac,0xbe,0x88,0x9a,0xe4,0xf6,0xc0,0xd2,0x3c,0x2e,0x18,0x0a,0x74,0x66,0x50,0x42
 .db 0x9e,0x8c,0xba,0xa8,0xd6,0xc4,0xf2,0xe0,0x0e,0x1c,0x2a,0x38,0x46,0x54,0x62,0x70
 .db 0x82,0x90,0xa6,0xb4,0xca,0xd8,0xee,0xfc,0x12,0x00,0x36,0x24,0x5a,0x48,0x7e,0x6c
 .db 0xb0,0xa2,0x94,0x86,0xf8,0xea,0xdc,0xce,0x20,0x32,0x04,0x16,0x68,0x7a,0x4c,0x5e
 .db 0xe6,0xf4,0xc2,0xd0,0xae,0xbc,0x8a,0x98,0x76,0x64,0x52,0x40,0x3e,0x2c,0x1a,0x08
 .db 0xd4,0xc6,0xf0,0xe2,0x9c,0x8e,0xb8,0xaa,0x44,0x56,0x60,0x72,0x0c,0x1e,0x28,0x3a
 .db 0x4a,0x58,0x6e,0x7c,0x02,0x10,0x26,0x34,0xda,0xc8,0xfe,0xec,0x92,0x80,0xb6,0xa4
 .db 0x78,0x6a,0x5c,0x4e,0x30,0x22,0x14,0x06,0xe8,0xfa,0xcc,0xde,0xa0,0xb2,0x84,0x96
 .db 0x2e,0x3c,0x0a,0x18,0x66,0x74,0x42,0x50,0xbe,0xac,0x9a,0x88,0xf6,0xe4,0xd2,0xc0
 .db 0x1c,0x0e,0x38,0x2a,0x54,0x46,0x70,0x62,0x8c,0x9e,0xa8,0xba,0xc4,0xd6,0xe0,0xf2
;	
;	CRC-16
;
;	low byte CRC lookup table
; 
crclo:
 .db 0x00,0x21,0x42,0x63,0x84,0xA5,0xC6,0xE7,0x08,0x29,0x4A,0x6B,0x8C,0xAD,0xCE,0xEF
 .db 0x31,0x10,0x73,0x52,0xB5,0x94,0xF7,0xD6,0x39,0x18,0x7B,0x5A,0xBD,0x9C,0xFF,0xDE
 .db 0x62,0x43,0x20,0x01,0xE6,0xC7,0xA4,0x85,0x6A,0x4B,0x28,0x09,0xEE,0xCF,0xAC,0x8D
 .db 0x53,0x72,0x11,0x30,0xD7,0xF6,0x95,0xB4,0x5B,0x7A,0x19,0x38,0xDF,0xFE,0x9D,0xBC
 .db 0xC4,0xE5,0x86,0xA7,0x40,0x61,0x02,0x23,0xCC,0xED,0x8E,0xAF,0x48,0x69,0x0A,0x2B
 .db 0xF5,0xD4,0xB7,0x96,0x71,0x50,0x33,0x12,0xFD,0xDC,0xBF,0x9E,0x79,0x58,0x3B,0x1A
 .db 0xA6,0x87,0xE4,0xC5,0x22,0x03,0x60,0x41,0xAE,0x8F,0xEC,0xCD,0x2A,0x0B,0x68,0x49
 .db 0x97,0xB6,0xD5,0xF4,0x13,0x32,0x51,0x70,0x9F,0xBE,0xDD,0xFC,0x1B,0x3A,0x59,0x78
 .db 0x88,0xA9,0xCA,0xEB,0x0C,0x2D,0x4E,0x6F,0x80,0xA1,0xC2,0xE3,0x04,0x25,0x46,0x67
 .db 0xB9,0x98,0xFB,0xDA,0x3D,0x1C,0x7F,0x5E,0xB1,0x90,0xF3,0xD2,0x35,0x14,0x77,0x56
 .db 0xEA,0xCB,0xA8,0x89,0x6E,0x4F,0x2C,0x0D,0xE2,0xC3,0xA0,0x81,0x66,0x47,0x24,0x05
 .db 0xDB,0xFA,0x99,0xB8,0x5F,0x7E,0x1D,0x3C,0xD3,0xF2,0x91,0xB0,0x57,0x76,0x15,0x34
 .db 0x4C,0x6D,0x0E,0x2F,0xC8,0xE9,0x8A,0xAB,0x44,0x65,0x06,0x27,0xC0,0xE1,0x82,0xA3
 .db 0x7D,0x5C,0x3F,0x1E,0xF9,0xD8,0xBB,0x9A,0x75,0x54,0x37,0x16,0xF1,0xD0,0xB3,0x92
 .db 0x2E,0x0F,0x6C,0x4D,0xAA,0x8B,0xE8,0xC9,0x26,0x07,0x64,0x45,0xA2,0x83,0xE0,0xC1
 .db 0x1F,0x3E,0x5D,0x7C,0x9B,0xBA,0xD9,0xF8,0x17,0x36,0x55,0x74,0x93,0xB2,0xD1,0xF0 
;
;	hi byte CRC lookup table
;
crchi:
 .db 0x00,0x10,0x20,0x30,0x40,0x50,0x60,0x70,0x81,0x91,0xA1,0xB1,0xC1,0xD1,0xE1,0xF1
 .db 0x12,0x02,0x32,0x22,0x52,0x42,0x72,0x62,0x93,0x83,0xB3,0xA3,0xD3,0xC3,0xF3,0xE3
 .db 0x24,0x34,0x04,0x14,0x64,0x74,0x44,0x54,0xA5,0xB5,0x85,0x95,0xE5,0xF5,0xC5,0xD5
 .db 0x36,0x26,0x16,0x06,0x76,0x66,0x56,0x46,0xB7,0xA7,0x97,0x87,0xF7,0xE7,0xD7,0xC7
 .db 0x48,0x58,0x68,0x78,0x08,0x18,0x28,0x38,0xC9,0xD9,0xE9,0xF9,0x89,0x99,0xA9,0xB9
 .db 0x5A,0x4A,0x7A,0x6A,0x1A,0x0A,0x3A,0x2A,0xDB,0xCB,0xFB,0xEB,0x9B,0x8B,0xBB,0xAB
 .db 0x6C,0x7C,0x4C,0x5C,0x2C,0x3C,0x0C,0x1C,0xED,0xFD,0xCD,0xDD,0xAD,0xBD,0x8D,0x9D
 .db 0x7E,0x6E,0x5E,0x4E,0x3E,0x2E,0x1E,0x0E,0xFF,0xEF,0xDF,0xCF,0xBF,0xAF,0x9F,0x8F
 .db 0x91,0x81,0xB1,0xA1,0xD1,0xC1,0xF1,0xE1,0x10,0x00,0x30,0x20,0x50,0x40,0x70,0x60
 .db 0x83,0x93,0xA3,0xB3,0xC3,0xD3,0xE3,0xF3,0x02,0x12,0x22,0x32,0x42,0x52,0x62,0x72
 .db 0xB5,0xA5,0x95,0x85,0xF5,0xE5,0xD5,0xC5,0x34,0x24,0x14,0x04,0x74,0x64,0x54,0x44
 .db 0xA7,0xB7,0x87,0x97,0xE7,0xF7,0xC7,0xD7,0x26,0x36,0x06,0x16,0x66,0x76,0x46,0x56
 .db 0xD9,0xC9,0xF9,0xE9,0x99,0x89,0xB9,0xA9,0x58,0x48,0x78,0x68,0x18,0x08,0x38,0x28
 .db 0xCB,0xDB,0xEB,0xFB,0x8B,0x9B,0xAB,0xBB,0x4A,0x5A,0x6A,0x7A,0x0A,0x1A,0x2A,0x3A
 .db 0xFD,0xED,0xDD,0xCD,0xBD,0xAD,0x9D,0x8D,0x7C,0x6C,0x5C,0x4C,0x3C,0x2C,0x1C,0x0C
 .db 0xEF,0xFF,0xCF,0xDF,0xAF,0xBF,0x8F,0x9F,0x6E,0x7E,0x4E,0x5E,0x2E,0x3E,0x0E,0x1E 
