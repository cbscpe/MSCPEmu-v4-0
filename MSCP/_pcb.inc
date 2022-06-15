;
;	Program Control Block
;
;
;
_pcb_count:	.byte	2
_pcb_buffer:	.byte	2
_pcb_program:	.byte	2
_pcb_work:	.byte	4

#define	ps__beg	0
#define	ps__abo	1
#define	ps__snd	2
#define	ps__rcv	3

_pcb_state:	.byte	1
_pcb_timeout:	.byte	1
_pcb_pkts:	.byte	2