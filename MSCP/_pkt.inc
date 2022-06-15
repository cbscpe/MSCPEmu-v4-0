;--------------------------------------------------------------------------
;
;	MSCP command dispatcher, this routine is entered with the 
;	address of a command packet. The command packet has the
;	following structure	
;										offset
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;	|                          link header                          |	0.
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;	|                   message length (in bytes)                   |	2.
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;	|     connection id             | message type  |    credits    |	4.
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;	|                                                               |	6.
;	+-                 command reference number                    -+
;	|                                                               |	8.
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;	|                         unit number                           |	10.
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;	|                           reserved                            |	12.
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;	|           reserved            |           opcode              |	14.
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;	|                           reserved                            |	16.
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;	|                                                               |	18.
;	+-                    command / response message               -+
;	|                                                               |
;	....
;	|                                                               |
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;
;	The real RQDX3 controller has a separate job for each unit 
;	because the transfer for each unit is asynchronuous. As those
;	are real disks it is very bad to wait for every IO to complete
;	however in our case this does not matter, we only have one
;	SD-Card. So it does not make sense to have one unit do a seek
;	and the other do a transfer. Also I suppose in most environments
;	we will use this MSCP emulator we will have to deal with just one
;	unit.
;
;	In the RQDX3 source code the message offsets are always defined in 
;	each module. First there is the packet which is defined ins pkt.h
;
;	struct $pkt
;	    {
;	    struct $pkt		*link;
;	    word		size;
;	    byte		type;
;	    byte		connid;
;	    byte		data[60];
;	    };
;
;	The message is preceeded by the message length, connection id,
;	message type and credits field as defined in page 4-6 of the
;	MSCPDocument3df. the internal packets themselves are preceeded
;	by the link header. 
;
;	The message itself can then be found in the PKT.data part.
;
;	#define PKT (*pkt)
;	#define CMD (*(struct $aboc *)&(PKT.data))
;	#define RSP (*(struct $abor *)&(PKT.data))
;
;	At entry the packet is a copy of the command packet received
;	by the port driver. Each action routine will then update the
;	fields and "convert" the packet into a response packet that
;	later is sent to the host via the port driver as response
;	packet. Hence we always see a 'c' and a 'r' form of the
;	data structure
;
;	In the disk emulator the offsets are defined in the same way,
;	and always relative to the start of the packet (pkt.link) and
;	we always assume the pointer register to point to the start
;	of the packet. ldd and std however can always address only
;	the first 64 bytes but messages can be up to 60 bytes. In
;	other words the last two bytes of the message cannot be
;	accessed using the ldd or std instructions. If this is required
;	then we will need to find a solution how to access these bytes.

recordstart	pkt
record		pkt, link, 2		; 0.
record		pkt, size, 2		; 2.
record		pkt, type, 1		; 4.
record		pkt, connid, 1		; 5.
record		pkt, data, 60		; 6.
recordend	pkt, length

;	/*
;	 *  the ABORT command packet
;	 */
;	struct $aboc
;	    {
;	    long	p_crf;
;	    word	p_unit;
;	    word	p_r1;
;	    byte	p_opcd;
;	    byte	p_r2;
;	    word	p_mod;
;	    long	p_otrf;
;	    };
;
recordcont	pkt, data
record		cmd, crf, 4		; 6.
record		cmd, unit, 2		; 10.
record		cmd, r1, 2		; 12.
record		cmd, opcd, 1		; 14.
record		cmd, r2, 1		; 15.
record		cmd, mod, 2		; 16.
record		cmd, otfr, 0		; 18.
record		cmd, bcnt, 4		; 18.
record		cmd, buff, 12		; 22.
record		cmd, lbn, 4		; 34.
recordend	cmd, next	

;	/*
;	 *  the ABORT response packet
;	 */
;	struct $abor
;	    {
;	    long	p_crf;
;	    word	p_unit;
;	    word	p_r1;
;	    byte	p_opcd;
;	    byte	p_flgs;
;	    word	p_sts;
;	    long	p_otrf;
;	    };
;
recordcont	pkt, data
record		rsp, crf, 4		; 6.
record		rsp, unit, 2		; 10.
record		rsp, r1, 2		; 12.
record		rsp, opcd, 1		; 14.
record		rsp, flgs, 1		; 15.
record		rsp, sts, 2		; 16.
recordend	rsp, min		; 18.

.equ	rs_min	= rsp_min - pkt_data	; End of Minimal Response Packet

recordcont	rsp, min
record		rsp, otfr, 0		; 18.
record		rsp, bcnt, 4		; 18.
record		rsp, cmst, 4		; 22.	command status
recordend	rsp, gcs		; 26.

.equ	rs_gcs	= rsp_gcs - pkt_data	; End of Get Controller Status Response Packet

recordcont	rsp, gcs
record		rsp, r2, 8		; 26.
record		rsp, fbbk, 4		; 34.
recordend	rsp, next

.equ	rs_rw	= rsp_next - pkt_data	; End of Read/Write Response Packet
;
;
;	Ring Descriptor
;
recordstart	ring
record		ring, base, 4		; 000
record		ring, flag, 4		; 004
record		ring, size, 2		; 010
record		ring, mask, 2		; 012
record		ring, index, 2		; 014
recordend	ring, sz
