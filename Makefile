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
	  main-v2-1.asm
	  
.PHONY : install, readflash, verify


install :
	avrdude -c avrispmkII -p m1284p -P usb -U flash:w:main-v2-1.hex
	
verify :
	avrdude -c avrispmkII -p m1284p -P usb -U flash:v:main-v2-1.hex
	
readflash :
	avrdude -c avrispmkII -p m1284p -P usb -U flash:r:main-v2-1-flash.hex:i
