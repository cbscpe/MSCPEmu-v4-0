# MSCP Emulator

MSCP Emulator is a dual-width Q-BUS card for PDP-11. It emulates an MSCP disk controller
and allows to store disk images on a SD-Card. 

## Content

This repository contains the main firmware. The firmware is written in AVR Assembler 
for the assembler `avrasm2`, which is included in Microchip Studio.

## Requirements

### PCB DISKEmu-v5-1

The MSCP Emulator runs on the DISKEmu-v5-1 Q-BUS card. This card fits in any Q-BUS slot
of a LSI-11 system.

### CPLD Programming

The CPLDs on the DISKEmu hardware need to be programmed with the appropriate JEDEC files.

### Microcontroller Firmware

To build the firmware for this MSCP Emulator you need also the include and FAT
repositories


## Releases

### v1.0.0

First public release. Boots RT-11 V5.3, RT-11 V5.7, RSX-11M+ V4.6 and BSD 2.11.
There is still an issue booting RSTS/E

### v1.0.1


