;=============================================================================
;
;	General Return Codes
;
#define IO_SUCCESS 0
#define IO_ERROR 1
;
;	SD-Card IO Errors
;
#define IO_ERR_CMD_REJ 2
#define IO_ERR_INV_TOKEN 3
#define IO_ERR_NO_TOKEN 4
#define IO_ERR_CRC 5
#define IO_ERR_DATA_RSP_TMO 6
#define IO_ERR_DATA_REJ 7
#define IO_ERR_RDY_TMO 8
;
;	Internal Errors
;
#define ERR_MALLOC 128
#define ERR_MBR 129
#define	ERR_NOVOL 130
#define ERR_TOOLONG 131


#define SD_SUCCESS 0
#define SD_ERROR 1
#define SD_ERR_CMD_REJ 1

#define SD_ERR_INV_TOKEN 2
#define SD_ERR_NO_TOKEN 3
#define SD_ERR_CRC 4
#define SD_ERR_NXM 5

#define SD_ERR_DATA_RSP_TMO 2
#define SD_ERR_DATA_REJ 3
#define SD_ERR_RDY_TMO 4



