;;;---------------------------------------------------------------------------
;;; CP/M 2.2 boot-loader for TangNano8080MEM
;;; by Ryo Mukai
;;; 2024/08/29
;;;---------------------------------------------------------------------------

;;;---------------------------------------------------------------------------
;;; This source can be assembled with the Macroassembler AS
;;; (http://john.ccac.rwth-aachen.de:8000/as/)
;;;---------------------------------------------------------------------------
	
	CPU 8080

DRIVE 	equ	0AH	; FDCD
TRACK 	equ	0BH	; FDCT
SECTOR	equ	0CH	; FDCS
FDCOP	equ	0DH	; FDCOP
DMAL	equ	0FH	; DMAL
DMAH	equ	10H	; DMAH

	org 0
BOOT:
	JMP START
	
	org 080H
;;; read (dive 0, track 0, sector 1) to 0000H-007FH, and jump to 0000H
START:
	DI
	LXI B,1
	LXI H,0
	XRA A
	OUT DRIVE
	MOV A,B
	OUT TRACK
	MOV A,C
	OUT SECTOR
	MOV A,L
	OUT DMAL
	MOV A,H
	OUT DMAH
	XRA A
	OUT FDCOP
	JMP BOOT
