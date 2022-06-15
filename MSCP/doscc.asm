/*
 *  process a SET CONTROLLER CHARACTERISTICS command
 *
 *  This is a sequential command, but since it changes no state which other
 *  non-sequential commands depend on, it can be considered to be a non-
 *  sequential command (thus we don't have to synchronize with anything else).
 *  The only characteristics that the host can modify are the host timeout
 *  value and a couple of this-kind-of-error-log-desired flags (pretty simple,
 *  huh?).
 */


do_scc:					; Set Controller Characteristics
	push	yl
	push	yh
	movw	yh:yl, r25:r24
;
;	Hier den entsprechenden code einfügen
;	
	movw	r25:r24, yh:yl
	call	put_packet
	pop	yh
	pop	yl
	ret

/*
 *  file = DOSCC.C
 *  project = RQDX3
 *  author = Stephen F. Shirron
 *
 *  the SET CONTROLLER CHARACTERISTICS command
 */

#include "defs.h"
#include "pkt.h"
#include "ccb.h"
#include "mscp.h"

extern struct $ccb _ccb;

/*
 *  the SET CONTROLLER CHARACTERISTICS command packet
 */
struct $sccc
    {
    long	p_crf;
    word	p_r1[2];
    byte	p_opcd;
    byte	p_r2;
    word	p_mod;
    word	p_vrsn;
    word	p_cntf;
    word	p_htmo;
    word	p_r3;
    word	p_time[4];
    word	p_ctpm[2];
    };

/*
 *  the SET CONTROLLER CHARACTERISTICS response packet
 */
struct $sccr
    {
    long	p_crf;
    word	p_r1[2];
    byte	p_opcd;
    byte	p_flgs;
    word	p_sts;
    word	p_vrsn;
    word	p_cntf;
    word	p_ctmo;
    byte	p_csvr;
    byte	p_chvr;
    word	p_cnti[4];
    word	p_mcnt[2];
    };

#define		rs_scc		sizeof( struct $sccr )

;
;	Offset definitions for error packet (used in doplf)
;
recordcont	pkt, data
record		scc, crf, 4		; 6.
record		scc, r1, 4		; 10.
record		scc, opcd, 1		; 14.
record		scc, flgs, 1		; 15.	
record		scc, sts, 2		; 16.
record		scc, vrsn, 2		; 18.
record		scc, cntf, 2		; 20.
record		scc, ctmo, 2		; 22.
record		scc, csvr, 1		; 24.
record		scc, chvr, 1		; 25.
record		scc, cnti, 8		; 26.
record		scc, mcnt, 4		; 34.
recordend	scc, next		; 38.

.equ	rs_scc	= scc_next - pkt_data


#define PKT (*pkt)
#define CMD (*(struct $sccc *)&(PKT.data))
#define RSP (*(struct $sccr *)&(PKT.data))
#define CCB _ccb

do_scc( pkt )
register struct $pkt *pkt;
    {
#if debug>=1
    printf( "\nSET CONTROLLER CHARACTERISTICS" );
#endif
    RSP.p_flgs = 0;
    /*
     *  if the MSCP version number is not zero, barf royally
     */
    if( CMD.p_vrsn > 0 )
	{
	RSP.p_opcd = 0;
	RSP.p_sts = st_cmd + i_vrsn;
	}
    else
	{
	/*
	 *  get the timeout value and the controller flags, and return
	 *  stuff like version numbers and controller identifiers
	 */
	RSP.p_sts = st_suc;
	if( ( CCB.timeout = CMD.p_htmo ) != 0 )
	    CCB.timeout += 2;
	CCB.flags &= cf_rpl;
	CCB.flags |= CMD.p_cntf & cf_msk;
	RSP.p_cntf = CCB.flags;
	RSP.p_ctmo = 120;
	RSP.p_csvr = rqdx3_softv;
	RSP.p_chvr = rqdx3_hardv;
	RSP.p_cnti[0] = 0;
	RSP.p_cnti[1] = 0;
	RSP.p_cnti[2] = 0;
	RSP.p_cnti[3] = CCB.type;
	/*
	 *  this is the maximum allowed byte count -- will VMS ever implement?
	 */
	RSP.p_mcnt[0] = 0;
	RSP.p_mcnt[1] = 0;
	}
    RSP.p_opcd |= op_end;
    PKT.size = rs_scc;
    PKT.type = mt_seq;
    put_packet( pkt );
    }
