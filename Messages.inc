;--------------------------------------------------------------------------
;
;	Macro to create messages addresses for messages that can be read
;	with flash mapped to the data address space
;
;	currently assuming page 3 is mapped to address space
;
;	msgnl	starts and ends the message with a new-line
;	msg	only ends the message with a new-line

.macro msgnl
.equ @0 = (PC - 0x8000) * 2 + 0x8000
.db	CR, LF
.if (STRLEN(@1)&1)
.db	@1, CR, LF, 0x00
.else
.db	@1, CR, LF, 0x00, 0x00
.endif
.endmacro

.macro msg
.equ @0 = (PC - 0x8000) * 2 + 0x8000
.if (STRLEN(@1)&1)
.db	@1, CR, LF, 0x00
.else
.db	@1, CR, LF, 0x00, 0x00
.endif
.endmacro


msgnl	msgnovolume, "No Volume!"
msgnl	msgdirfnf, "DIR - directory not found!"
msgnl	msgdirnad, "DIR - not a directory!"
msgnl	msgattachinv, "Attach - invalid unit number %c"
msgnl	msgattachunt, "Attach - invalid unit"
msgnl	msgattachfnf, "Attach - file not found"
msgnl	msgattachnaf, "Attach - not a file"
msgnl	msgattachfcb, "Attach - not enough memory for fcb!"
msgnl	msgattachiob, "Attach - not enough memory for iob!"
msgnl	msgattachfrg, "Attach - not enough memory to hold fragment list!"
msgnl	msgattachnfn, "Attach - not enough memory for file name!"
msgnl	msgattachuaa, "Attach - unit is already attached!"
msgnl	msgattachnsd, "Attach - not a standard disk image!"
msgnl	msgattachpnf, "Attach - Partition %c not found"
msgnl	msgattachpaa, "Attach - Partition %c is already attached"
msgnl	msgattachinf, "Attach - Next step is BuildFragList"
msgnl	msgattachpin, "Attach - Partition %c is inactive"
msgnl	msgdetachinv, "Detach - invalid unit number %c"
msgnl	msgdetachuna, "Detach - Unit %c is not attached"
msgnl	msgtypenaf, "Type - Not a file!"
msgnl	msgtypefnf, "Type - File not found!"
msgnl	msgtypeerr, "Type - open error:%x"
msgnl	msgcdfnf, "CD - directory not found"
msgnl	msgcdnad, "CD - not a directory"
msgnl	msgreadinitall, "Init - Failed to allocated Buffer"
msgnl	msgreadinitinv, "Init - RLV12.INI not a valid file"
msgnl	msgreadinitfnf, "Init - RLV12.INI not found"
msgnl	msgreadinitope, "Init - Error %x opening file RLV12.INI "
msgnl	msgreadinitopn, "Init - RLV12.INI successfully opened"
msgnl	msgreadinitovr, "Init - Fatal buffer overflow!"
msgnl	msgdismountopn, "Dismount - Volume %c still has open files"
msg	msgdriveunk, "  Drive Type not defined."
msgnl	msgloaderr, "Load - DMA Error"
msgnl	msgrlv12ins, "RLV12 - Insufficient Memory"
