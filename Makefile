#
#       Makefile built after reading the excellent introduction at
#
#	       https://web.mit.edu/gnu/doc/html/make_2.html
#
main : 
	avrasm2 -fI -o main.hex  -m main.map  -l main.lss  -S main.tmp  -W+ie \
	 -I ../include  \
	 -I ../avrasminclude \
	 -i AVR128DB48def.inc \
	 -d main.obj  \
	 -e main.eep \
	 -D mscpemulation \
	  main.asm
	  
.PHONY : install, readflash, verify, mscp, rlv

#
#	QBUS64 Hardware Version 4.0
#
#
mscp :
	avrasm2 -fI -o main.hex  -m main.map  -l main.lss  -S main.tmp  -W+ie \
	 -I ../include  \
	 -I ../avrasminclude \
	 -i AVR128DB48def.inc \
	 -d main.obj  \
	 -e main.eep \
	 -D mscpemulation \
	  main.asm
#
#	QBUS Hardware Version 5.1
#
qbus :
	avrasm2 -fI -o main.hex  -m main.map  -l main.lss  -S main.tmp  -W+ie \
	 -I ../include  \
	 -I ../avrasminclude \
	 -i AVR128DB48def.inc \
	 -d main.obj  \
	 -e main.eep \
	 -D mscpemulation \
	 -D qbus51 \
	  main.asm
#
#	QBUS64 Hardware Version 5.1
#
qbus64 :
	avrasm2 -fI -o main.hex  -m main.map  -l main.lss  -S main.tmp  -W+ie \
	 -I ../include  \
	 -I ../avrasminclude \
	 -i AVR128DB48def.inc \
	 -d main.obj  \
	 -e main.eep \
	 -D mscpemulation \
	 -D qbus64 \
	  main.asm


rlv :
	avrasm2 -fI -o main.hex  -m main.map  -l main.lss  -S main.tmp  -W+ie \
	 -I ../include  \
	 -I ../avrasminclude \
	 -i AVR128DB48def.inc \
	 -d main.obj  \
	 -e main.eep \
	 -D rlv12emulation \
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
