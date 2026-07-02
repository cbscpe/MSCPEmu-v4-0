;
;	Note that here we carefully place variables at a 256. byte boundary
;	to have nice addresses during debugging
;
		align	8		; Make nice boundaries
mscpipr:	.byte	2		; Poll Job IP Read Wait Lock
mscpsaw:	.byte	2		; Init Job SA Write Wait Lock
mscpinit:	.byte	2
;
;	This is the packet buffer, at the moment we do not implement a queue
;	with multiple commands and just process the commands sequentially. We
;	have no real media and no disk controller with asynchronous operation
;	and only poll the SD-Card where all disk images are located. But to
;	keep the offset definitions we add 2 bytes link header.
;
cmd_link:	.byte	2		; Link Header in case of linked buffers
cmd_buffer:	.byte	4		; Message Header 4 bytes
cmd_message:	.byte	64		; Message Text up to 64. bytes


;		
cmd:		.byte	ring_sz		; Command Ring Data Structure
rsp:		.byte	ring_sz		; Response Ring Data Structure
purgeflag:	.byte	4		; Host Memory Address of Purge Flags
descriptor:	.byte	4		; Last Descriptor used
descr_addr:	.byte	4		; 
ha_time:	.byte	1		; Host Adapter Timeout
ha_flag:	.byte	1		; Host Adapter Flag
credits:	.byte	1		; MSCP Credits
unit0:		.byte	1		; Unit number of first unit
iprflag:	.byte	1		; IP Read Flag
porterror:	.byte	1		; Last Port Error 
unitbase:	.byte	2		; Starting Unit Number
;
;	Q-Bus Register Storage and MSCP Status
;
sar:		.byte	2		; SA Read Data
saw:		.byte	2		; SA Write Data
ipw:		.byte	2		; IP Write Data
ipr:		.byte	2		; IP Read Data
sa_s1:		.byte	2		; Step 1 Host Value
sa_s2:		.byte	2		; Step 2 Host Value
sa_s3:		.byte	2		; Step 3 Host Value
sa_s4:		.byte	2		; Step 4 Host Value
sa_wr:		.byte	2		; Wrap Around 
sa_go:		.byte	2
sa_pu:		.byte	2
sa_na:		.byte	2		; Not Applicable
sawcount:	.byte	2
mscpstatus:	.byte	1		; MSCP Port Status
