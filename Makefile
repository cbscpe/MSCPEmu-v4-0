#
#       Makefile built after reading the excellent introduction at
#
#	       https://web.mit.edu/gnu/doc/html/make_2.html
#
main : 
	avrasm2 -fI -o main-v2-1.hex  -m main-v2-1.map  -l main-v2-1.lss  -S main-v2-1.tmp  -W+ie \
	 -I ~/AVR-Projects/include  \
	 -I ~/AVR-Projects/avrasminclude \
	 -i AVR128DB48def.inc \
	 -d main-v2-1.obj  \
	 -e main-v2-1.eep \
	 -D mscpemulation \
	  main-v2-1.asm
	  
.PHONY : install, readflash, verify, mscp, rlv

#
#	QBUS64 Hardware Version 4.0
#
#
mscp :
	avrasm2 -fI -o main-v2-1.hex  -m main-v2-1.map  -l main-v2-1.lss  -S main-v2-1.tmp  -W+ie \
	 -I ~/AVR-Projects/include  \
	 -I ~/AVR-Projects/avrasminclude \
	 -i AVR128DB48def.inc \
	 -d main-v2-1.obj  \
	 -e main-v2-1.eep \
	 -D mscpemulation \
	  main-v2-1.asm
#
#	QBUS Hardware Version 5.1
#
qbus :
	avrasm2 -fI -o main-v2-1.hex  -m main-v2-1.map  -l main-v2-1.lss  -S main-v2-1.tmp  -W+ie \
	 -I ~/AVR-Projects/include  \
	 -I ~/AVR-Projects/avrasminclude \
	 -i AVR128DB48def.inc \
	 -d main-v2-1.obj  \
	 -e main-v2-1.eep \
	 -D mscpemulation \
	 -D qbus51 \
	  main-v2-1.asm
#
#	QBUS64 Hardware Version 5.1
#
qbus64 :
	avrasm2 -fI -o main-v2-1.hex  -m main-v2-1.map  -l main-v2-1.lss  -S main-v2-1.tmp  -W+ie \
	 -I ~/AVR-Projects/include  \
	 -I ~/AVR-Projects/avrasminclude \
	 -i AVR128DB48def.inc \
	 -d main-v2-1.obj  \
	 -e main-v2-1.eep \
	 -D mscpemulation \
	 -D qbus64 \
	  main-v2-1.asm

qbus50 :
	avrasm2 -fI -o main-v2-1.hex  -m main-v2-1.map  -l main-v2-1.lss  -S main-v2-1.tmp  -W+ie \
	 -I ~/AVR-Projects/include  \
	 -I ~/AVR-Projects/avrasminclude \
	 -i AVR128DB48def.inc \
	 -d main-v2-1.obj  \
	 -e main-v2-1.eep \
	 -D mscpemulation \
	 -D qbus50 \
	  main-v2-1.asm

rlv :
	avrasm2 -fI -o main-v2-1.hex  -m main-v2-1.map  -l main-v2-1.lss  -S main-v2-1.tmp  -W+ie \
	 -I ~/AVR-Projects/include  \
	 -I ~/AVR-Projects/avrasminclude \
	 -i AVR128DB48def.inc \
	 -d main-v2-1.obj  \
	 -e main-v2-1.eep \
	 -D rlv12emulation \
	  main-v2-1.asm

install :
	avrdude -p AVR128DB48 -c atmelice_updi -U flash:w:main-v2-1.hex
	
verify :
	avrdude -p AVR128DB48 -c atmelice_updi -U flash:v:main-v2-1.hex
	
readflash :
	avrdude -p AVR128DB48 -c atmelice_updi -U flash:r:main-v2-1.hex:i


duboot :
	macro11 -l DUBOOT.LST -o DUBOOT.OBJ DUBOOT.MAC
	perl obj2bin.pl --raw --rt11 --outfile=DUBOOT.BIN DUBOOT.OBJ

sram :
	avrdude -p AVR128DB48 -c atmelice_updi -U sram:r:sram.bin:r
