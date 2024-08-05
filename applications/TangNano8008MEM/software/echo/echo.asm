;;;---------------------------------------------------------------------------
;;; This source can be assembled with the Macroassembler AS
;;; (http://john.ccac.rwth-aachen.de:8000/as/)
;;;---------------------------------------------------------------------------

	cpu 8008	; AS's command to specify CPU

REG_CSR equ 00H
REG_RX  equ 01H	
REG_TX  equ 10H	

	org 0H
RST0:
	NOP
	JMP START

	org 8H
RST1:
RXINT:	INP REG_RX
	JMP PUTCH
	
	org 10H
RST2:	JMP START

	org 18H
RST3:	JMP START

	org 20H
RST4:	JMP START

	org 28H
RST5:	JMP START

	org 30H
RST6:	JMP START
	
	org 38H
RST7:	LAI '@'
	JMP PUTCH

	org 40H
START:
;;; uncomment this for polling
;;  	CAL GETCH
;;  	CAL PUTCH
	JMP START 		; wait for interrupt

PUTCH:
	LBA
	INP REG_CSR
	NDI 04H
	JTZ PUTCH
	LAB
	OUT REG_TX
	RET	

GETCH:
	INP REG_CSR
	NDI 01H
	JTZ GETCH
	INP REG_RX
	RET
