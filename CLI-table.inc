;
commandlist:
;
;		Element		Action		Next
;
	.dw	kw_rlv12init,	0,		cmd_rlv12init
	.dw	kw_insert,	0,		cmd_insert		; Selection of possible keywords
	.dw	kw_cd,		0,		cmd_cd
	.dw	kw_hallo,	0,		cmd_halloworld
	.dw	kw_show,	0,		cmd_show
	.dw	kw_dir,		a_dirinit,	cmd_dir
	.dw	kw_type,	0,		cmd_type
	.dw	kw_pwd,		0,		cmd_pwd
	.dw	kw_fdisk,	0,		cmd_fdisk
	.dw	kw_attach, 	0, 		cmd_attach
	.dw	kw_detach,	0,		cmd_detach
	.dw	kw_mon, 	a_mon,		cmd_done
	.dw	kw_help,	0, 		cmd_help
	.dw	kw_activate,	0,		cmd_activate
	.dw	kw_initialise,	0,		cmd_initialise
	.dw	kw_showlog,	0,		cmd_logging
	.dw	kw_no,		0, 		cmd_no
	.dw	kw_nbr, 	0, 		cmd_nbr
	.dw	kw_load,	0,		cmd_load
	.dw	kw_readinit,	0,		cmd_readinit
	.dw	kw_dumpblock,	a_dumpinit,	cmd_dumpblock
	.dw	kw_dmaread,	0,		cmd_dmaread
	.dw	kw_dmawrite,	0,		cmd_dmawrite
	.dw	kw_dmaaddr,	0,		cmd_dmaaddr
	.dw	kw_dmatest,	0,		cmd_dmatest
	.dw	kw_linked,	0,		cmd_linked
	.dw	kw_free,	0,		cmd_free
	.dw	kw_reset,	0,		cmd_reset
	.dw	kw_port,	0,		cmd_port
	.dw	kw_pointer,	0,		cmd_pointer
	.dw	kw_memtest,	0,		cmd_memtest
	.dw	kw_controller,	0,		cmd_controller
	.dw	kw_sdinit,	0,		cmd_sdinit
	.dw	kw_mount,	0, 		cmd_mount
	.dw	kw_dismount,	0,		cmd_dismount
	.dw	kw_sdread,	a_sdinit,	cmd_sdread
	.dw	kw_set,		0,		cmd_set
	.dw	kw_turbo,	0,		cmd_turbo
	.dw	kw_poll,	0,		cmd_poll
	.dw	kw_eol,		0,		cmd_done
	.dw	0

cmd_poll:
	.dw	kw_eol,		cmdpoll,	cmd_done
	.dw	0

cmd_rlv12init:
	.dw	kw_eol,		0,		cmd_done
	.dw	0

cmd_sdinit:
	.dw	kw_eol,		cmdsdinit,	cmd_done
	.dw	0

cmd_mount:
	.dw	kw_eol,		cmdmount,	cmd_done
	.dw	0

cmd_dismount:
	.dw	kw_eol,		cmddismount,	cmd_done
	.dw	0

cmd_controller:
	.dw	kw_ready,	0,		cmd_contrdy
	.dw	kw_busy,	0,		cmd_contbsy
	.dw	0

cmd_contrdy:
	.dw	kw_eol,		cmdcontrdy,	cmd_done
	.dw	0
	
cmd_contbsy:
	.dw	kw_eol,		cmdcontbsy,	cmd_done
	.dw	0

cmd_nbr:
	.dw	kw_number, 	a_nbr,		cmd_nbr1
	.dw	0
cmd_nbr1:
	.dw	kw_eol,		prtnbr,		cmd_done
	.dw	0

cmd_memtest:
	.dw	kw_number, 	a_nbr,		cmd_memtest1
	.dw	0
	
cmd_memtest1:
	.dw	kw_eol,		cmdmemtest,	cmd_done
	.dw	0

cmd_pointer:
	.dw	kw_eol,		cmdpointer,	cmd_done
	.dw	0

cmd_port:
	.dw	ch_a,		a_port,		cmd_port1
	.dw	ch_b,		a_port,		cmd_port1
	.dw	ch_c,		a_port,		cmd_port1
	.dw	ch_d,		a_port,		cmd_port1
	.dw	ch_e,		a_port,		cmd_port1
	.dw	ch_f,		a_port,		cmd_port1
	.dw	ch_g,		a_port,		cmd_port1
	.dw	0

cmd_port1:
	.dw	kw_show,	0,		cmd_portshow
	.dw	kw_porttoggle,	0,		cmd_porttoggle
	.dw	kw_portset,	0,		cmd_portset
	.dw	kw_portclr,	0,		cmd_portclr
	.dw	kw_portoutput, 	0,		cmd_portoutput
	.dw	kw_portinput, 	0,		cmd_portinput
	.dw	kw_eol,		cmdportshow,	cmd_done
	.dw	0
	
cmd_portshow:
	.dw	kw_eol,		cmdportshow,	cmd_done
	.dw	0

cmd_porttoggle:
	.dw	kw_eol,		a_porttoggle,	cmd_portdo
	.dw	kw_number,	a_porttoggle,	cmd_portdo
	.dw	0
	
cmd_portset:
	.dw	kw_number,	a_portset,	cmd_portdo
	.dw	0
	
cmd_portclr:
	.dw	kw_number,	a_portclr,	cmd_portdo
	.dw	0
	
cmd_portoutput:
	.dw	kw_number,	a_portoutput,	cmd_portdo
	.dw	0
	
cmd_portinput:
	.dw	kw_number,	a_portinput,	cmd_portdo
	.dw	0
	
cmd_portdo:
	.dw	kw_eol,		cmdportdo,	cmd_done
	.dw	0

cmd_reset:
	.dw	kw_eol,		cmdreset,	cmd_done
	.dw	0	

cmd_free:
	.dw	kw_eol,		showfree,	cmd_done
	.dw	0
	
cmd_linked:
	.dw	kw_number, 	a_nbr, 		cmd_linked1
	.dw	0
cmd_linked1:
	.dw	kw_eol,		showlinked,	cmd_done
	.dw	0

cmd_dmatest:
	.dw	kw_number,	a_nbr,		cmd_dmatest1
	.dw	0
cmd_dmatest1:
	.dw	kw_eol,		cmddmatest,	cmd_done
	.dw	0
	
cmd_dmawrite:
	.dw	kw_number,	a_nbr,		cmd_dmawrite1
	.dw	0
	
cmd_dmawrite1:
	.dw	kw_eol,		cmddmawrite,	cmd_done
	.dw	0

cmd_dmaaddr:
	.dw	kw_number,	a_dmaaddr,	cmd_dmaaddr1
	.dw	0
cmd_dmaaddr1:
	.dw	kw_eol,		cmddmaaddr,	cmd_done
	.dw	0

cmd_dmaread:
	.dw	kw_eol,		cmddmaread,	cmd_done
	.dw	0


cmd_readinit:
	.dw	kw_eol,		cmdreadinit, 	cmd_done
	.dw	0

cmd_load:
	.dw	kw_number, 	a_nbr,		cmd_load1
	.dw	0

cmd_load1:
	.dw	kw_eol,		loadboot,	cmd_done
	.dw	kw_iotest,	0,		cmd_loadiotest
	.dw	kw_loadtest,	0,		cmd_loadtest
	.dw	kw_duboot,	0,		cmd_loadduboot
	.dw	0

cmd_loadduboot:
	.dw	kw_eol,		loadduboot,	cmd_done
	.dw	0

cmd_loadiotest:
	.dw	kw_eol,		loadiotest,	cmd_done
	.dw	0

cmd_loadtest:
	.dw	kw_eol,		loadtest,	cmd_done
	.dw	0

cmd_fdisk:
	.dw	kw_eol,		fdisk,		cmd_done
	.dw	0

cmd_no:
	.dw	kw_showlog, 	set_no,		cmd_logging
	.dw	kw_turbo,	set_no,		cmd_turbo
	.dw	0

cmd_turbo:
	.dw	kw_eol,		setturbo,	cmd_done
	.dw	0

cmd_set:
	.dw	kw_eol,		0,		cmd_done
	.dw	0

cmd_logging:
	.dw	kw_register,	0,		cmd_logregister
	.dw	kw_interrupt,	0,		cmd_loginterrupt
	.dw	kw_units,	0,		cmd_logunits
	.dw	kw_attdev, 	a_dev,		cmd_logunit
	.dw	kw_attunit, 	a_dev,		cmd_logunit
	.dw	kw_pbn,		0,		cmd_logpbn
	.dw	kw_trace,	0,		cmd_logtrace
	.dw	kw_entry,	a_logentry,	cmd_logentry
	.dw	kw_eol,		logstatus,	cmd_done
	.dw	0

cmd_logentry:
	.dw	kw_string, 	a_logbyte,	cmd_logentry
	.dw	kw_eol,		logentry, 	cmd_done
	.dw	0

cmd_logregister:
	.dw	kw_eol,		logreg, 	cmd_done
	.dw	0

cmd_loginterrupt:
	.dw	kw_eol,		logiack, 	cmd_done
	.dw	0

cmd_logunits:
	.dw	kw_eol,		logunits,	cmd_done
	.dw	0
	
cmd_logunit:
	.dw	kw_eol,		logunit,	cmd_done
	.dw	0

cmd_logtrace:
	.dw	kw_eol,		logtrace,		cmd_done
	.dw	0	

cmd_logpbn:
	.dw	kw_eol,		logpbn,		cmd_done
	.dw	0	

cmd_activate:
	.dw	kw_attpar, 	a_par,		cmd_activate1
	.dw	0

cmd_activate1:
	.dw	kw_eol,		activpar,	cmd_done
	.dw	0
	
cmd_initialise:
	.dw	kw_attpar,	a_par,		cmd_initialise1
	.dw	0

cmd_initialise1:
	.dw	kw_eol,		initpar,	cmd_done
	.dw	0

cmd_attach:
	.dw	kw_attdev,	a_dev,		cmd_attach0
	.dw	kw_attunit, 	a_dev,		cmd_attach0
	.dw	0

cmd_attach0:
	.dw	kw_attpar,	a_par, 		cmd_attach2
	.dw	kw_qstring,	a_cd,		cmd_attach1
	.dw	kw_string,	a_cd,		cmd_attach1
	.dw	0
	
cmd_attach1:
	.dw	kw_eol,		attachcmd,	cmd_done
	.dw	0

cmd_attach2:
	.dw	kw_eol,		attachpar,	cmd_done
	.dw	0

cmd_detach:
	.dw	kw_attdev,	a_dev,		cmd_detach1
	.dw	kw_attunit, 	a_dev,		cmd_detach1
	.dw	0

cmd_detach1:
	.dw	kw_eol,		detachunit,	cmd_done
	.dw	0

cmd_pwd:
	.dw	kw_eol,		pwdcmd,		cmd_done
	.dw	0
	
cmd_type:
	.dw	kw_qstring,	a_cd,		cmd_type1
	.dw	kw_string,	a_cd,		cmd_type1
	.dw	0

cmd_type1:
	.dw	kw_eol,		typecmd,	cmd_done
	.dw	0

cmd_dir:
	.dw	kw_eol,		dircmd,		cmd_done
	.dw	sw_dira, 	a_dirswa, 	cmd_dir
	.dw	kw_qstring,	a_cd,		cmd_dir1
	.dw	kw_string,	a_cd,		cmd_dir1
	.dw	0
	
cmd_dir1:
	.dw	kw_eol,		dircmd1,	cmd_done
	.dw	0
	
cmd_insert:
	.dw	kw_disk,	0,		cmd_insert1				;  
	.dw	0

cmd_insert1:
	.dw	kw_into,	0,		cmd_insert2
	.dw	0

cmd_insert2:
	.dw	kw_volume,	0,		cmd_insert3
	.dw	kw_drive,	0,		cmd_insert3
	.dw	0

cmd_insert3:
	.dw	kw_eol,		0,		cmd_done
	.dw	0

cmd_pack:
	.dw	kw_cartridge, 	0,		cmd_done	; Subcommand allowing two keywords
	.dw	kw_diskpack,	0,		cmd_done
	.dw	0

cmd_cd:	
	.dw	kw_qstring,	a_cd,		cmd_cd1
	.dw	kw_string,	a_cd,		cmd_cd1
	.dw	kw_eol,		cdcmdroot,	cmd_done
	.dw	0
	
cmd_cd1:
	.dw	kw_eol,		cdcmd,		cmd_done
	.dw	0

cmd_halloworld:
	.dw	kw_qstring,	0,		cmd_halloworld1
	.dw	kw_string,	0,		cmd_halloworld1
	.dw	0
	
cmd_halloworld1:
	.dw	kw_eol,		0,		cmd_done
	.dw	0
	
cmd_show:
	.dw	kw_showint, 	cmd_showint,	cmd_done
	.dw	kw_showunits,	cmd_showunits,	cmd_done
	.dw	kw_showpart,	cmd_showpart,	cmd_done
	.dw	kw_showlog,	cmd_showlog,	cmd_done
	.dw	kw_showvers,	cmd_showvers,	cmd_done
	.dw	kw_jobs,	cmd_showjobs,	cmd_done
	.dw	kw_rings,	cmd_showrings,	cmd_done
	.dw	kw_message, 	cmd_showmessage,cmd_done
	.dw	kw_opcodes,	cmd_showfncstats,cmd_done
	.dw	kw_status,	0,		cmd_status
	.dw	0

cmd_status:
	.dw	kw_eol,		printstatus,	cmd_done
	.dw	0

cmd_help:
	.dw	kw_eol,		cmdhelp,	cmd_done
	.dw	0

cmd_dumpblock:
	.dw	sw_dumpr,	a_dumpswr,	cmd_dumpblock		; optional switch
	.dw	sw_dumpc,	a_dumpswc, 	cmd_dumpblock
	.dw	sw_dumpb,	a_dumpswb,	cmd_dumpnbr
	.dw	kw_dumpdev,	a_dumpdev,	cmd_dumpblock1
	.dw	0
	
cmd_dumpnbr:
	.dw	kw_number,	a_dumpblknbr,	cmd_dumpblock
	.dw	kw_lambda,	0,		cmd_dumpblock
	.dw	0

cmd_dumpblock1:
	.dw	kw_eol,		cmddumpbl,	cmd_done
	.dw	0

kw_rlv12init:	P_KEYWORD	"[RLV12]"
kw_no:		P_KEYWORD	"NO"
kw_register:	P_KEYWORD	"REGister"
kw_interrupt:	P_KEYWORD	"INTerrupt"
kw_string:	P_STRING			; string, anything except white spaces
kw_eol:		P_EOL
kw_qstring:	P_QSTRING
kw_name:	P_NAME				; Name must start with a-z, $, @ and may contain 0-9, ., -, _
kw_number:	P_NUMBER			; Number
kw_lambda:	P_LAMBDA
;
kw_type:	P_KEYWORD	"TYpe"
kw_linked:	P_KEYWORD	"LINKed"
kw_insert:	P_KEYWORD	"INSert"	; Keyword
kw_cartridge:	P_KEYSUFF	"CARtridge"	; Keyword followed by a number
kw_diskpack:	P_KEYWORD	"PACk"
kw_into:	P_KEYWORD	"INto"		; 
kw_volume:	P_KEYDEVICE	"VOLume"	; Keyword followed by a number and a colon
kw_drive:	P_KEYDEVICE	"DL"
kw_cd:		P_KEYWORD	"CD"		; Keyword
kw_units:	P_KEYWORD	"UNIts"
kw_pbn:		P_KEYWORD	"PBN"
kw_hallo:	P_KEYWORD	"HALLO"
kw_show:	P_KEYWORD	"Show"
kw_disk:	P_SUBCMD	cmd_pack	; Element Type Sub-command
kw_dir:		P_KEYWORD	"DIR"
kw_pwd:		P_KEYWORD	"PWD"
kw_attach:	P_KEYWORD	"ATTach"
kw_attdev:	P_KEYSUFF	"RL"
kw_attunit:	P_KEYSUFF	"UNit"
kw_attpar:	P_KEYSUFF	"Partition"
kw_detach:	P_KEYWORD	"DEtach"
kw_mount:	P_KEYWORD	"MOUnt"
kw_showunits:	P_KEYWORD	"Units"
kw_showpart:	P_KEYWORD	"Partitions"
kw_showvers:	P_KEYWORD	"Version"
kw_showint:	P_KEYWORD	"INTernal"
kw_activate:	P_KEYWORD	"ACTivate"
kw_initialise:	P_KEYWORD	"INITialise"
kw_showlog:	P_KEYWORD	"LOGging"
kw_mon:		P_CHAR		'$'
kw_help:	P_KEYWORD	"HElp"
kw_fdisk:	P_KEYWORD	"FDISK"
kw_nbr:		P_KEYWORD	"Number"
kw_load:	P_KEYWORD	"Load"
kw_loadtest:	P_KEYWORD	"Test"
kw_readinit:	P_KEYWORD	"READINIT"
kw_dumpdev:	P_KEYSUFF	"RL"
kw_dumpblock:	P_KEYWORD	"DUMP"
kw_dmaread:	P_KEYWORD	"DMARead"
kw_dmawrite:	P_KEYWORD	"DMAWrite"
kw_dmaaddr:	P_KEYWORD	"DMAAddress"
kw_dmatest:	P_KEYWORD	"DMATest"
kw_free:	P_KEYWORD	"FREE"
kw_set:		P_KEYWORD	"SET"
kw_reset:	P_KEYWORD	"RESET"
kw_pointer:	P_KEYWORD	"POINTer"
kw_memtest:	P_KEYWORD	"MEMorytest"
sw_dumpr:	P_SWITCH	"r"
sw_dumpc:	P_SWITCH	"c"
sw_dumpb:	P_SWITCH	"b"
sw_dira:	P_SWITCH	"a"
ch_a:		P_CHAR		"a"
ch_b:		P_CHAR		"b"
ch_c:		P_CHAR		"c"
ch_d:		P_CHAR		"d"
ch_e:		P_CHAR		"e"
ch_f:		P_CHAR		"f"
ch_g:		P_CHAR		"g"
kw_port:	P_KEYWORD	"POrt"
kw_porttoggle:	P_KEYWORD	"Toggle"
kw_portset:	P_KEYWORD	"SEt"
kw_portoutput:	P_KEYWORD	"OUTput"
kw_portinput:	P_KEYWORD	"INput"
kw_portshow:	P_KEYWORD       "SHow"
kw_portclr:	P_KEYWORD	"Clr"
kw_jobs:	P_KEYWORD	"Jobs"
kw_controller:	P_KEYWORD	"CONtroller"
kw_ready:	P_KEYWORD	"Ready"
kw_busy:	P_KEYWORD	"Busy"	
kw_entry:	P_KEYWORD	"Entry"
kw_sdinit:	P_KEYWORD	"SDInit"
kw_dismount:	P_KEYWORD	"DISMOunt"
kw_sdread:	P_KEYWORD	"SDRead"
kw_trace:	P_KEYWORD       "TRace"
kw_iotest:	P_KEYWORD	"IOTest"
kw_duboot:	P_KEYWORD	"DUBoot"
kw_status:	P_KEYWORD	"STATus"
kw_turbo:	P_KEYWORD	"TURBO"
kw_rings:	P_KEYWORD	"RINgs"
kw_message:	P_KEYWORD	"MESSage"
kw_opcodes:	P_KEYWORD	"OPCodes"
kw_poll:	P_KEYWORD	"POLL"

kw_sdclbn:	P_KEYWORD	"Lbn"
kw_sdcaddr:	P_KEYWORD	"Address"

cmd_sdread:
	.dw	kw_sdclbn,	0,		cmd_sdread010
	.dw	kw_sdcaddr,	0,		cmd_sdread020
	.dw	0
	
cmd_sdread010:
	.dw	kw_number,	a_sdlbn,	cmd_sdread011
	.dw	0

cmd_sdread011:
	.dw	kw_sdcaddr,	0,		cmd_sdread012
	.dw	0
	
cmd_sdread012:
	.dw	kw_number,	a_sdaddr,	cmd_sdread013
	.dw	0

cmd_sdread013:
	.dw	kw_eol,		cmdsdread,	cmd_done
	.dw	0
	

cmd_sdread020:	
	.dw	kw_number,	a_sdaddr,	cmd_sdread021
	.dw	0
	
cmd_sdread021:
	.dw	kw_sdclbn,	0,		cmd_sdread022
	.dw	0

cmd_sdread022:
	.dw	kw_number,	a_sdlbn,	cmd_sdread023
	.dw	0
	
cmd_sdread023:
	.dw	kw_eol,		cmdsdread,	cmd_done
	.dw	0
