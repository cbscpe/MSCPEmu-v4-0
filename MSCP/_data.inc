;
;
;
cmd:		.byte	ring_sz		; Command Ring Data Structure
rsp:		.byte	ring_sz		; Response Ring Data Structure
purgeflag:	.byte	4		; Host Memory Address of Purge Flags

descriptor:	.byte	4		; Last Descriptor used
source:		.byte	4		; Message
packet:		.byte	2		; Packet in get_packet -> evtl. use local regs
mscpipr:	.byte	2		; Poll Job IP Read Wait Lock
dma:		.byte	2		; DMA Lock word
pkts:		.byte	2		; Free Packets link header
ha_time:	.byte	1		; Host Adapter Timeout
ha_flag:	.byte	1		; Host Adapter Flag
credits:	.byte	1		; MSCP Credits
unit0:		.byte	1		; Unit number of first unit
s1:		.byte	2		; Step 1 Host Value
s2:		.byte	2		; Step 2 Host Value
s3:		.byte	2		; Step 3 Host Value
s4:		.byte	2		; Step 4 Host Value
saw:		.byte	2		; SA Write Data
sar:		.byte	2		; SA Read Data
ipw:		.byte	2		; IP Write Data
ipr:		.byte	2		; IP Read Data
sawflag:	.byte	1		; SA Write Flag
iprflag:	.byte	1		; IP Read Flag
mscpstatus:	.byte	1		; MSCP Port Status
porterror:	.byte	1		; Last Port Error 
unitbase:	.byte	2		; Starting Unit Number
