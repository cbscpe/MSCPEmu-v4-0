#
#       2026-07-01	Peter Schranz
#		From now on only the following hardware is supported
#
#		Q-BUS	DISK Emulator Version 5-1
#		QBUS64	DISK Emulator Version 5-1a
#
#		All other versions and prototypes have either been modified to
#		comply or have been discarded.
#
main : qbusw
	  
.PHONY : install, readflash, verify, mscp, rlv

#
#	QBUS Hardware Version 5.1
#
qbus :
	avrasm2 -fI -o main.hex  -m main.map  -l main.lss  -S main.tmp  -W+ie \
	 -I ../include  \
	 -I ../avrinclude \
	 -i AVR128DB48def.inc \
	 -d main.obj  \
	 -e main.eep \
	 -D mscpemulation \
	 -D qbus51 \
	 -D lasttag='"'$(shell git describe --tags --abbrev=0 )'"' \
	  main.asm
#
#	Q-BUS Hardware Version 5.1 using wine to run latest avrasm2 from Microchip Studio
#
qbusw :
	MVK_CONFIG_LOG_LEVEL=0 wine ~/windows.exe/avrasm2.exe -fI -o main.hex  -m main.map  -l main.lss  -S main.tmp  -W+ie \
	 -I ../avrasminclude \
	 -I ../include  \
	 -i AVR128DB48def.inc \
	 -d main.obj  \
	 -e main.eep \
	 -D mscpemulation \
	 -D qbus51 \
	 -D lasttag='"'$(shell git describe --tags --abbrev=0 )'"' \
	  main.asm
#
#	RLV12 Emulation
#
rlv :
	avrasm2 -fI -o main.hex  -m main.map  -l main.lss  -S main.tmp  -W+ie \
	 -I ../include  \
	 -I ../avrinclude \
	 -i AVR128DB48def.inc \
	 -d main.obj  \
	 -e main.eep \
	 -D rlv12emulation \
	 -D qbus51 \
	 -D lasttag='"'$(shell git describe --tags --abbrev=0 )'"' \
	  main.asm

#
#	RLV12 Emulation using wine to run latest avrasm2 from Microchip Studio
#
rlvw :
	MVK_CONFIG_LOG_LEVEL=0 wine ~/windows.exe/avrasm2.exe -fI -o main.hex  -m main.map  -l main.lss  -S main.tmp  -W+ie \
	 -I ../avrasminclude \
	 -I ../include  \
	 -i AVR128DB48def.inc \
	 -d main.obj  \
	 -e main.eep \
	 -D rlv12emulation \
	 -D qbus51 \
	 -D lasttag='"'$(shell git describe --tags --abbrev=0 )'"' \
	  main.asm

install :
	avrdude -p AVR128DB48 -c atmelice_updi -U flash:w:main.hex
	
verify :
	avrdude -p AVR128DB48 -c atmelice_updi -U flash:v:main.hex
	
readflash :
	avrdude -p AVR128DB48 -c atmelice_updi -U flash:r:main.hex:i

duboot :
	macro11 -l DUBOOT.LST -o DUBOOT.OBJ DUBOOT.MAC
	perl obj2bin.pl --raw --rt11 --outfile=DUBOOT.BIN DUBOOT.OBJ

sram :
	avrdude -p AVR128DB48 -c atmelice_updi -U sram:r:sram.bin:r
