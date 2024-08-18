;;;----------------------------------------------------------------------------
;;; User dependent console I/O routines
;;;----------------------------------------------------------------------------
REG_CSR equ 00H
REG_RX  equ 01H	
REG_TX  equ 10H	

PUTCH:	MOV B,A
.WAIT:	IN REG_CSR
	ANI 04H
	JZ .WAIT
	MOV A,B
	OUT REG_TX
	RET	

GETCH:	IN REG_CSR
	ANI 01H
	JZ GETCH
	IN REG_RX
	RET
