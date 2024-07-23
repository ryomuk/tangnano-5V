;;;---------------------------------------------------------------------------
;;; CP/M 2.2 boot-loader for TangNanoZ80MEM-CPM
;;; by Ryo Mukai
;;; 2024/07/23
;;;---------------------------------------------------------------------------

;;;---------------------------------------------------------------------------
;;; This source can be assembled with the Macroassembler AS
;;; (http://john.ccac.rwth-aachen.de:8000/as/)
;;;---------------------------------------------------------------------------
	
	CPU Z80

DRIVE 	equ	0AH	; FDCD
TRACK 	equ	0BH	; FDCT
SECTOR	equ	0CH	; FDCS
FDCOP	equ	0DH	; FDCOP
DMAL	equ	0FH	; DMAL
DMAH	equ	10H	; DMAH

	org 0
BOOT:
	JP START
	
	org 080H
;;; read (dive 0, track 0, sector 1) to 0000H-007FH, and jump to 0000H
START:
	IM 0
	DI
	LD BC,1
	LD HL,0
	XOR A
	OUT DRIVE,A
	LD A,B
	OUT TRACK,A
	LD A,C
	OUT SECTOR,A
	LD A,L
	OUT DMAL,A
	LD A,H
	OUT DMAH,A
	XOR A
	OUT FDCOP,A
	JP BOOT
	
