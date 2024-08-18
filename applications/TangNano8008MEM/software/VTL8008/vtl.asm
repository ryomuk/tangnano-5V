;;;---------------------------------------------------------------------------
;;; Very Tiny Language Interpreter (VTL-8008) for Intel 8008
;;; ported (and rewrited) from VTL-4004
;;;
;;; This program is for TangNano8008MEM system.
;;; It will be easily ported by simply writing PUTCH and GETCH and
;;; modifing the memory map.
;;;
;;; by Ryo Mukai
;;; https://github.com/ryomuk
;;; 2024/08/18
;;;---------------------------------------------------------------------------

;;;---------------------------------------------------------------------------
;;; This source can be assembled with the Macroassembler AS
;;; (http://john.ccac.rwth-aachen.de:8000/as/)
;;;---------------------------------------------------------------------------

 	cpu 8008new	       ; AS's command to specify CPU
;;; 	cpu 8080
	if MOMCPUNAME=="8008NEW"
CODE_JMP equ 44H
	elseif MOMCPUNAME=="8080"
CODE_JMP equ 0C3H
	else
	error "unknown CPU"
	error MOMCPUNAME
	endif
;;;---------------------------------------------------------------------------
;;; some macros
;;;---------------------------------------------------------------------------
lo     	function x, ((x)&255)
up     	function x, (((x)>>8)&255)

LXI_HL 	macro x
	MVI H,up(x)
	MVI L,lo(x)
	endm

LXI_BC 	macro x
	MVI B,up(x)
	MVI C,lo(x)
	endm

MVI_REG16 macro x,y
	LXI_HL x
	MVI M,lo(y)
	INR L
	MVI M,up(y)
	DCR L
	endm

DEBUG   equ 1
	if DEBUG
;;;---------------------------------------------------------------------------
;;; for debug
;;; SAFEPUTCHAR
;;; PUTCHAR keeping A and B
;;; for debug
;;; destroy HL
;;;---------------------------------------------------------------------------
SAFEPUTCHAR macro x
	CALL PUSH_A
	MVI A,x
	OUT REG_TX
	CALL POP_A
	endm

	endif

;;;---------------------------------------------------------------------------
;;; some constants
;;;---------------------------------------------------------------------------
LF	equ 0AH			; '\n'
CR	equ 0DH			; '\r'
	
;;;---------------------------------------------------------------------------
;;; Register usage
;;; A: ACC
;;; B: tmp
;;; C: tmp
;;; D: memory register index0
;;; E: memroy register index1
;;; HL: tmp for memory operation
;;;---------------------------------------------------------------------------

;;;---------------------------------------------------------------------------
;;; Memory Map
;;;---------------------------------------------------------------------------
PROGRAM_START	equ 1000H
PROGRAM_END	equ 37FFH
REGTOP		equ 3800H ; lo(REGTOP) must be 00H;
ARRAYTOP	equ 3900H
RETURNSTACK	equ 3D00H ; used downwards used by VTL !,]
LINEBUF		equ 3D00H ; used upperwards
PCSTACK       	equ 3E00H ; stack for Subroutine call (3E00-3EFF)
STACK         	equ 3F00H ; stack for registers       (3F00-3FFF)

REGPAGE		equ up(REGTOP)	; 

;;;---------------------------------------------------------------------------
;;; for pseudo random generator
;;;---------------------------------------------------------------------------
RANDOM_SEED equ 1234
	
;;;---------------------------------------------------------------------------
;;; Data registers
;;; must be in one page
;;;---------------------------------------------------------------------------

	org REGTOP


REG16_INDEX:		DW ?	; 00H or @, `
REG16_A_TO_Z:		DW 26 DUP ?	; 02H-34H
REG16_LINENUM:		DW ?	; current line number
REG16_THISLINE_PTR:	DW ?	; pointer to the top of the current line
REG16_NEXTLINE_PTR:	DW ?	; pointer to the next program line
REG16_PEND:		DW ?	; pointer to the end of program
REG16_LVALUE:		DW ?
REG16_RVALUE:		DW ?
REG16_FACTOR:		DW ?
REG16_EVAL:		DW ?	; result of evaluation
REG16_RMND:		DW ?	; Remainder (result of last DIV)
REG16_RETURNSTACK:	DW ?	; stack for != and ]
REG16_RANDOM0:		DW ?	; for pseudo random number
REG16_RANDOM1:		DW ?	; for pseudo random number
REG16_ARRAYINDEX:	DW ?	; for array assignment
REG16_TMP_ARRAY:	DW ?	; for array read
REG16_TMP:		DW ?
REG16_TMP2:		DW ?
REG16_TMP_MUL:		DW ?
REG16_TMP2_MUL:		DW ?
REG16_TMP_GETNUM:	DW ?
REG16_TMP_REG		DW ?	; tmp for PUSH/POP_REG16x
REG16_TMP_PRINT		DW ?	; tmp for PRINT_REG16
REG16_TEST		DW ?
REG16_TEST2		DW ?
REG16_DIVRESULT:	DW ?
REG16_DIVIDEND      	DW ?	
REG16_DIVISOR       	DW ?	
REG16_MON_TMP:		DW ?
REG16_MON_TMP2:		DW ?
REG16_ERROR:		DW ?
REG8_ERROR2:		DB ?
REG8_SIGNDIVIDEND:	DB ?	; sign of the dividend
REG8_SIGNDIVISOR:	DB ?	; sign of the divisor
REG8_ZEROSUP:		DB ?
REG16_CONST_10000:      DW ?	; Here is RAM area
REG16_CONST_1000:	DW ?	; so these constants are
REG16_CONST_100:	DW ?	; initialized in the program
REG16_CONST_10:	        DW ?
;;;---------------------------------------------------------------------------
;;; RETURN_BY_JMP
;;; This routine is the end of the RETURN_BY_PCSTACK
;;; the target address is variable, so this is located on the data area
;;; (not a ROM area)
;;;---------------------------------------------------------------------------
RETURN_BY_JMP:		DB ?    ; write 'CODE_JMP'(=44H or 0C3H) in the program
RETURN_ADDRESS:		DW ?	; operand is written by RETURN_BY_PCSTACK

REG16_LAST:
	if up(REG16_LAST-2) != REGPAGE
	error "Register area exceeded one page!"
	endif
	
MAXINT			equ 7FFFH
MININT			equ 8001H
	
;;;---------------------------------------------------------------------------
;;; Program Start
;;;---------------------------------------------------------------------------
	org 0000H

MAIN:
RST0:	NOP
	JMP START
	org 8H
RST1:	JMP START
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
RST7:	JMP START

	org 40H

;;;----------------------------------------------------------------------------
;;; user dependent console I/O routine
;;;----------------------------------------------------------------------------
	include "user.asm"

;;;----------------------------------------------------------------------------
;;; some basic I/O routines
;;;----------------------------------------------------------------------------
;;;---------------------------------------------------------------------------
;;; PUTCHAR
;;; defined by macro
;;; destroy A,B
;;;---------------------------------------------------------------------------
PUTCHAR macro x
	MVI  A,x
	CALL PUTCH
	endm
	
;;;---------------------------------------------------------------------------
;;; PUTS
;;; print string *(HL)
;;; destroy: A, B, HL
;;;---------------------------------------------------------------------------
PUTS:	MOV A,M
	ANA A
	RZ
	CALL PUTCH
	INR L
	JNZ PUTS
	INR H
	JMP PUTS

;;;---------------------------------------------------------------------------
;;; PRINT_CRLF
;;;---------------------------------------------------------------------------
PRINT_CRLF:	
	PUTCHAR CR
	PUTCHAR LF
	RET

;;;---------------------------------------------------------------------------
;;; init system
;;;---------------------------------------------------------------------------
	org 100H
START:
	if MOMCPUNAME=="8080"
	LXI SP,0000H
	endif
	
	LXI_HL STR_VFD_INIT ; init VFD
        CALL PUTS
	JMP VTL_START

;;;----------------------------------------------------------------------------
;;; String data
;;;----------------------------------------------------------------------------

STR_VFD_INIT:		;reset VFD and set scroll mode
	DB 1bH, 40H, 1fH, 02H, 0
STR_VTL_MESSAGE:
	DB "\r\n"
	DB "VTL-8008 Interpreter Ver 2.0\r\n"
	DB "(C) 2024 Ryo Mukai\r\n", 0
STR_VTL_OK:
	DB "\r\nOK\r\n", 0
STR_VTL_ERROR_SYNTAX:
	DB "SYERR", 0
STR_VTL_ERROR_PRINT:
	DB "PRERR", 0
STR_VTL_ERROR_OPERATOR:
	DB "OPERR", 0
STR_VTL_ERROR_EOL:
	DB "EOLERR", 0
STR_VTL_ERROR_FACTOR:
	DB "FTERR", 0
STR_VTL_BUF:
	DB "BUF=", 0
STR_VTL_SP:
	DB "SP=", 0
STR_VTL_PCSP:
	DB "PCSP=", 0
STR_VTL_ERRORLINENUM:
	DB "IN #", 0

;;;---------------------------------------------------------------------------
;;; CALL/RETRUN on memory stack
;;; usage:
;;;  set return address to register pair BC and jmp to subroutine
;;;  the subroutine pushes the BC to PCSTACK
;;;  and returns by RETURN_BY_PCSTACK
;;; 
;;;	LXI_BC RET_X
;;; 	JMP SUB_Y
;;; RET_X: ; return here
;;;	...
;;;       
;;; SUB_Y:
;;; 	CALL PUSH_BC_PCSTACK
;;; 	...
;;; 	JMP RETURN_BY_PCSTACK
;;; 	
;;;---------------------------------------------------------------------------
PUSH_BC_PCSTACK:
	MVI H,up(PCSTACK)
	MVI L,0
	MOV L,M
	DCR L
	MOV M,B
	DCR L
	MOV M,C
	MOV C,L
	MVI L,0
	MOV M,C
	MOV L,C
	MOV C,M
	RET

RETURN_BY_PCSTACK:
	CALL PUSH_BC
	MVI H,up(PCSTACK)	; set H to Stack Page
	MVI L,0			; set HL to &SP
	MOV L,M			; L=SP
	MOV C,M			; C=*(SP)
	INR L			; SP++
	INR L			; SP++
	MOV B,L			; B=new SP
	MVI L,0			; set HL to &SP
	MOV M,B			; SP = B (=new SP = original SP +2)
	MOV L,B			;
	DCR L			; HL=original SP+1 
	MOV B,M			; B=*(original SP+1)
	MVI H,up(RETURN_BY_JMP)
	MVI L,lo(RETURN_BY_JMP)
 	MVI M,CODE_JMP
	INR L
	MOV M,C			; lower byte of the return address
	INR L
	MOV M,B			; upper byte of the return address
	CALL POP_BC
	JMP RETURN_BY_JMP

;;;---------------------------------------------------------------------------
;;; Stack operations
;;; stack area consists of one page (256 byte)
;;; stack pointer is xx00 (1byte)
;;; stack area is xx02-xxFF (254byte)
;;; Push/Pop register pair on stack
;;; destroy: HL
;;;
;;;---------------------------------------------------------------------------
PUSH_A:
	MVI H,up(STACK)		; set H to Stack Page
	MVI L,0			; set HL to &SP
	MOV L,M			; L=SP
	DCR L			;
	MOV M,A			; (--SP)=A
	MOV A,L
	MVI L,0			; HL = &SP
	MOV M,A			; write new SP
	MOV L,M			; 
	MOV A,M			; restore A
	RET

PUSH_AB:
	MVI H,up(STACK)		; set H to Stack Page
	MVI L,0			; set HL to &SP
	MOV L,M			; L=SP
	DCR L			;
	MOV M,A			; (--SP)=A
	DCR L			;
	MOV M,B			; (--SP)=B
	MOV B,L			; B=new SP (restored afterward)
	MVI L,0			; HL = &SP
	MOV M,B			; SP=B
	MOV L,B			; 
	MOV B,M			; restore B
	RET

PUSH_BC:
	MVI H,up(STACK)		; set H to Stack Page
	MVI L,0			; set HL to &SP
	MOV L,M			; L=SP
	DCR L			;
	MOV M,B			; (--SP)=B
	DCR L			;
	MOV M,C			; (--SP)=C
	MOV C,L			; C=new SP (restored afterward)
	MVI L,0			; HL = &SP
	MOV M,C			; SP=C
	MOV L,C			; 
	MOV C,M			; restore C
	RET

PUSH_DE:
	MVI H,up(STACK)
	MVI L,0
	MOV L,M
	DCR L
	MOV M,D
	DCR L
	MOV M,E
	MOV E,L
	MVI L,0
	MOV M,E
	MOV L,E
	MOV E,M
	RET

POP_A:
	MVI H,up(STACK)		; set H to Stack Page
	MVI L,0			; set HL to &SP
	MOV L,M			; L=SP
	INR L			; 
	MOV A,L			; A=orig SP+1
	MVI L,0			;
	MOV M,A			; SP++
	MOV L,A			; 
	DCR L			; HL= &(orig SP)
	MOV A,M			; A=(orig SP)
	RET

POP_AB:
	MVI H,up(STACK)		; set H to Stack Page
	MVI L,0			; set HL to &SP
	MOV L,M			; L=SP
	MOV B,M			; B=(SP)
	INR L			; SP++
	INR L			; SP++
	MOV A,L			; A=new SP
	MVI L,0			; set HL to &SP
	MOV M,A			; SP = A (=new SP = original SP +2)
	MOV L,A			;
	DCR L			; HL=original SP+1 
	MOV A,M			; A=(original SP+1)
	RET

POP_BC:
	MVI H,up(STACK)		; set H to Stack Page
	MVI L,0			; set HL to &SP
	MOV L,M			; L=SP
	MOV C,M			; C=(SP)
	INR L			; SP++
	INR L			; SP++
	MOV B,L			; B=new SP
	MVI L,0			; set HL to &SP
	MOV M,B			; SP = B (=new SP = original SP +2)
	MOV L,B			;
	DCR L			; HL=original SP+1 
	MOV B,M			; B=(original SP+1)
	RET

POP_DE:
	MVI H,up(STACK)
	MVI L,0
	MOV L,M
	MOV E,M
	INR L
	INR L
	MOV D,L
	MVI L,0
	MOV M,D
	MOV L,D
	DCR L
	MOV D,M
	RET

;;;---------------------------------------------------------------------------
;;; Push/Pop REG16A
;;; destroy: HL
;;;---------------------------------------------------------------------------
PUSH_REG16A:
	MVI H,REGPAGE
	MVI L,lo(REG16_TMP_REG)
	MOV M,C
	INR L
	MOV M,B			; store BC to TMP_REG

	MOV L,A
	MOV C,M
	INR L
	MOV B,M			; load REG(A) to BC
	CALL PUSH_BC		; push REG(A)

	MVI H,REGPAGE
	MVI L,lo(REG16_TMP_REG)
	MOV C,M
	INR L
	MOV B,M			; restore BC from TMP_REG
	RET
	
POP_REG16A:
	MVI H,REGPAGE
	MVI L,lo(REG16_TMP_REG)
	MOV M,C
	INR L
	MOV M,B			; store BC to TMP_REG

	CALL POP_BC		; pop REG(A) from stack
	MVI H,REGPAGE
	MOV L,A
	MOV M,C
	INR L
	MOV M,B			; load REG(A) from BC

	MVI L,lo(REG16_TMP_REG)
	MOV C,M
	INR L
	MOV B,M			; restore BC from TMP_REG
	RET

;;;---------------------------------------------------------------------------
;;; MOV_REG16D_REG16E
;;; REG16(D)=REG16(E)
;;; destroy: A, HL (H=REGPAGE)
;;;---------------------------------------------------------------------------
MOV_REG16D_REG16E:
	MVI H,REGPAGE
	MOV L,E
	MOV A,M
	MOV L,D
	MOV M,A
	MOV L,E
	INR L
	MOV A,M
	MOV L,D
	INR L
	MOV M,A
	RET

;;;---------------------------------------------------------------------------
;;; MOV_REG16E_REG16D
;;; REG16(E)=REG16(D)
;;; destroy: A, HL
;;;---------------------------------------------------------------------------
MOV_REG16E_REG16D:
	MVI H,REGPAGE
	MOV L,D
	MOV A,M
	MOV L,E
	MOV M,A
	MOV L,D
	INR L
	MOV A,M
	MOV L,E
	INR L
	MOV M,A
	RET

;;;---------------------------------------------------------------------------
;;; MOV_REG16B_REG16D
;;; REG16(B)=REG16(D)
;;; destroy: A, HL
;;;---------------------------------------------------------------------------
MOV_REG16B_REG16D:
	MVI H,REGPAGE
	MOV L,D
	MOV A,M
	MOV L,B
	MOV M,A
	MOV L,D
	INR L
	MOV A,M
	MOV L,B
	INR L
	MOV M,A
	RET

;;;---------------------------------------------------------------------------
;;; MOV_REG16D_REG16B
;;; REG16(D)=REG16(B)
;;; destroy: A, HL
;;;---------------------------------------------------------------------------
MOV_REG16D_REG16B:
	MVI H,REGPAGE
	MOV L,B
	MOV A,M
	MOV L,D
	MOV M,A
	MOV L,B
	INR L
	MOV A,M
	MOV L,D
	INR L
	MOV M,A
	RET

;;;---------------------------------------------------------------------------
;;; MOV_REG16B_REG16E
;;; REG16(B)=REG16(E)
;;; destroy: A, HL
;;;---------------------------------------------------------------------------
MOV_REG16B_REG16E:
	MVI H,REGPAGE
	MOV L,E
	MOV A,M
	MOV L,B
	MOV M,A
	MOV L,E
	INR L
	MOV A,M
	MOV L,B
	INR L
	MOV M,A
	RET

;;;---------------------------------------------------------------------------
;;; INC_REG16D
;;; REG16(D)++
;;; destroy: B, HL (H = REGPAGE)
;;;---------------------------------------------------------------------------
INC_REG16D:
	MVI H,REGPAGE
	MOV L,D			;set pointer to lower byte
	MOV B,M
	INR B			;increment lower byte
	MOV M,B
	RNZ			;not zero then return
	INR L			;set pointer to upper byte
	MOV B,M
	INR B			;increment upper byte
	MOV M,B
	RET

;;;---------------------------------------------------------------------------
;;; DEC_REG16D
;;; REG16(D)--
;;; destroy: B, HL
;;;---------------------------------------------------------------------------
DEC_REG16D:
	MVI H,REGPAGE
	MOV L,D			; set pointer to lower byte
	MOV B,M
	INR B
	DCR B			; check if lower byte is zero
	JZ .LZERO
	DCR B			; lower byte is not zero
	MOV M,B			; then decriment and write
	RET
.LZERO				; lower byte is zero
	DCR B
	MOV M,B			; decriment lower byte and write
	INR L			; set pointer to upper byte
	MOV B,M
	DCR B			; decriment upper byte
	MOV M,B			; and write
	RET
	
;;;---------------------------------------------------------------------------
;;; PRINTHEX_A
;;; print ACC in HEX format
;;; print contents of ACC('0'...'F') as a character
;;; destroy: HL
;;;---------------------------------------------------------------------------
PRINTHEX_A:
	CALL PUSH_AB
	MOV L,A			; save A to L
	RRC
	RRC
	RRC
	RRC
	ANI 0FH
	CPI 10
	JC .L1			; A<10
	ADI 07H			; A>=10
.L1:	ADI 30H			;'0'
	CALL PUTCH
	MOV A,L			; restore A from L
	ANI 0FH
	CPI 10
	JC .L2			;A<10
	ADI 07H			;A>=10
.L2:	ADI 30H			;'0'
	CALL PUTCH
	JMP  POP_AB

;;;---------------------------------------------------------------------------
;;; ISNUM_A
;;; check P1 '0' to '9' as a ascii character
;;; return: C=0 if P1 is not a number
;;;         C=1 if P1 is a number
;;;---------------------------------------------------------------------------
ISNUM_A:
	CPI '0'
	JC  .FALSE		; A <'0'
	CPI '9'+1
	RET                     ; '0'<=A<'9'+1 then C=1
.FALSE:
	ANA A			; clear Carry
	RET			; A is not a number (C=0)

;;;----------------------------------------------------------------------------
;;; ISHEX_A
;;; check A is a hex digit letter ('0' to '9') or ('A' to 'F') or ('a' to 'f') 
;;; return: C=0 if A is not a hex digit letter
;;;         C=1 if A is a hex digit letter
;;; destroy: 
;;;----------------------------------------------------------------------------
ISHEX_A:
	CPI '0'
	JC  .FALSE		; A <'0'
	CPI '9'+1
	RC                      ; '0'<=A<'9'+1 then C=1
				; if C=0, test next chance
	CPI 'A'
	JC  .FALSE		; A <'A'
	CPI 'F'+1
	RC                      ; 'A'<=A<'F'+1 then C=1
				; if C=0, test next chance
	CPI 'a'
	JC  .FALSE		; A <'a'
	CPI 'f'+1
	RC
.FALSE:
	ANA A
	RET                      ; 'a'<=A<'f'+1 then C=1
	
;;;----------------------------------------------------------------------------
;;; ISALPHA_A
;;; check A is an alphabet as a ascii character
;;; return: C=0 if A is not an alphabet
;;;         C=1 if A is an alphabet
;;;----------------------------------------------------------------------------
ISALPHA_A:
	CPI 'A'
	JC  .FALSE		; A <'A'
	CPI 'Z'+1
	RC                      ; 'A'<=A<'Z'+1 then C=1
				; if C=0, test next chance
	CPI 'a'
	JC  .FALSE		; A <'a'
	CPI 'z'+1
	RC
.FALSE:
	ANA A
	RET                      ; 'a'<=A<'z'+1 then C=1

	
;;;---------------------------------------------------------------------------
;;; CTOI_A
;;; convert character ('0-9','a-f','A-F') to value 0000 ... 1111
;;; no error check
;;; input: A
;;; output: A
;;;---------------------------------------------------------------------------
CTOI_A:
	SUI 30H			; A=A-30H
	CPI 10
	RC			; return if A-30H <10
	ANI 1FH
	SUI 07H
	RET

;;;----------------------------------------------------------------------------
;;; Subroutines for memory operation
;;;----------------------------------------------------------------------------
;;;---------------------------------------------------------------------------
;;; MOV_A_MEMREG16D
;;; A = *REG(D)
;;; destroy: HL
;;;---------------------------------------------------------------------------
MOV_A_MEMREG16D:
	CALL PUSH_BC
	MVI H,REGPAGE
	MOV L,D
	MOV C,M
	INR L
	MOV B,M
	MOV H,B
	MOV L,C
	MOV A,M
	JMP POP_BC

;;;---------------------------------------------------------------------------
;;; MOV_MEMREG16D_A
;;; *REG(D) = A
;;; destroy: HL
;;;---------------------------------------------------------------------------
MOV_MEMREG16D_A:
	CALL PUSH_BC
	MVI H,REGPAGE
	MOV L,D
	MOV C,M
	INR L
	MOV B,M
	MOV H,B
	MOV L,C
	MOV M,A
	JMP POP_BC
	
;;;----------------------------------------------------------------------------
;;; MOV_BC_MEMREG16D
;;; BC = *REG(D)
;;; destroy: HL
;;;----------------------------------------------------------------------------
MOV_BC_MEMREG16D:
	CALL PUSH_DE
	MVI H,REGPAGE
	MOV L,D
	MOV E,M			;E=REG(D) lower byte
	INR L
	MOV D,M			;D=REG(D) upper byte
	MOV H,D			;HL=REG(D)
	MOV L,E
	MOV C,M			;C=*REG(D) lower byte
	INR L			;HL++
	JNZ .L1
	INR H
.L1:
	MOV B,M			;B=*REG(D) upper byte
	JMP POP_DE

;;;----------------------------------------------------------------------------
;;; MOV_MEMREG16D_BC
;;;*REG(D) = BC
;;; destroy: HL
;;;----------------------------------------------------------------------------
MOV_MEMREG16D_BC:
	CALL PUSH_DE
	MVI H,REGPAGE
	MOV L,D			; HL=&REG(D)
	MOV E,M			; E=REG(D) lower byte
	INR L			;
	MOV D,M			; D=REG(D) upper byte
	MOV H,D			; HL=REG(D)
	MOV L,E			; 
	MOV M,C			; *REG(D) = C lower byte
	INR L			;
	JNZ .L1
	INR H
.L1:
	MOV M,B			; *REG(D) = B upper byte
	JMP POP_DE

;;;----------------------------------------------------------------------------
;;; MOV_REG16E_MEMREG16D
;;; REG(E) = *REG(D)
;;; 
;;; destroy: HL
;;;----------------------------------------------------------------------------
MOV_REG16E_MEMREG16D:
	CALL PUSH_BC
	CALL PUSH_DE
	MVI H,REGPAGE
	MOV L,D
	MOV E,M
	INR L
	MOV D,M			; DE=REG(D)
	MOV H,D
	MOV L,E			; HL=REG(D)
	MOV C,M			; C=*REG(D) lower byte
	INR L
	JNZ .L1
	INR H			; HL++
.L1:
	MOV B,M			; B=*REG(D) upper byte
	CALL POP_DE		; restore DE
	MVI H,REGPAGE
	MOV L,E			; L=REG(E)
	MOV M,C			; REG(E) lower byte =C
	INR L
	MOV M,B			; REG(E) upper byte =B

	JMP POP_BC

;;;----------------------------------------------------------------------------
;;; MOV_MEMREG16D_REG16E
;;; *REG(D) = REG(E) 
;;; 
;;; destroy: HL
;;;----------------------------------------------------------------------------
MOV_MEMREG16D_REG16E:	
	CALL PUSH_BC
	CALL PUSH_DE
	MVI H,REGPAGE
	MOV L,E
	MOV C,M
	INR L
	MOV B,M			;BC=REG(E)

	MOV L,D
	MOV E,M
	INR L
	MOV D,M			;DE=REG(D)

	MOV H,D
	MOV L,E			;HL=DE(=REG(D))

	MOV M,C			; *REG(D)=C (lower byte)
	INR L
	JNZ .L1
	INR H
.L1:
	MOV M,B			; *REG(D)=B (upper byte)

	CALL POP_DE
	JMP POP_BC

;;;----------------------------------------------------------------------------
;;; GETLINE_MEMREG16D
;;; Get line from serial input and store to M(REG(D))
;;; The value of REG(D) does not change
;;;----------------------------------------------------------------------------
GETLINE_MEMREG16D:	
	CALL PUSH_BC
	CALL PUSH_DE

	MVI E,lo(REG16_TMP)
	CALL MOV_REG16E_REG16D	; REG(TMP)=REG(INDEX)

.LOOP:
	CALL GETCH
	CPI CR
	JNZ .L1
;;; 	CPI LF
;;; 	JNZ .L1
	CALL PRINT_CRLF
	JMP .EXIT
.L1:
	CPI 08H			; backspace
	JNZ .INSERTCHAR

	MVI E,lo(REG16_TMP)
	CALL CMP_UNSIGNED_REG16D_REG16E
	JNZ .BS			; do BS if REG(D)!=REG(TMP)
	JMP .LOOP		; ignore BS
.BS:				; delete a character on the cursor
	CALL DEC_REG16D		; REG(D)--
.L1_NEXT:			; delete a character on the cursor
	PUTCHAR 08H		; put backspace
	PUTCHAR ' '
	PUTCHAR 08H		; put backspace
	JMP .LOOP
.INSERTCHAR:
	CALL PUTCH
	CALL MOV_MEMREG16D_A
	CALL INC_REG16D		; *REG(D)++ = A

	JMP .LOOP
.EXIT:
	XRA A
	CALL MOV_MEMREG16D_A
	CALL INC_REG16D
	CALL MOV_MEMREG16D_A

	CALL MOV_REG16D_REG16E	; restore REG(INDEX)
	CALL POP_DE
	JMP  POP_BC

;;;----------------------------------------------------------------------------
;;; GETHEXNUMBER_MEMREG16D_REG16E
;;;----------------------------------------------------------------------------
GETHEXNUMBER_MEMREG16D_REG16E:
	CALL PUSH_AB
	CALL CLEAR_REG16E
.LOOP:
	CALL MOV_A_MEMREG16D
	CALL ISHEX_A
	JNC .EXIT
	CALL INC_REG16D
	CALL CTOI_A
	MOV  B,A
	MOV  A,E
	CALL MUL2_REG16A
	CALL MUL2_REG16A
	CALL MUL2_REG16A
	CALL MUL2_REG16A
	CALL ADD_REG16A_B
	JMP .LOOP
.EXIT:
	JMP POP_AB
	
;;;----------------------------------------------------------------------------
;;; GETNUMBER_MEMREG16D_REG16E
;;; Read a decimal or hexadecimal number in the string and store to register
;;; Read string from *REG16(D) and set a number to REG16(E)
;;; REG16(D) is incremented to the character which is not a number.
;;; Hexadecimal number begins with 0 (ex. 0A123).
;;; destroy: HL
;;; TMP: working for multiply by 10
;;;----------------------------------------------------------------------------
GETNUMBER_MEMREG16D_REG16E:
	CALL MOV_A_MEMREG16D	; A = *REG16(D)
	CPI '0'
	JZ GETHEXNUMBER_MEMREG16D_REG16E  ;; if start with '0' then get HEX

	CALL PUSH_A
	CALL PUSH_BC
	CALL CLEAR_REG16E
	MOV  C,D		; save D to C
.LOOP:
	MOV  D,C		; restore D from C
	MOV  A,C
	CALL MOV_A_MEMREG16D
	CALL ISNUM_A
	JNC .EXIT
	CALL INC_REG16D
	CALL CTOI_A
	MOV  B,A
	MOV  A,E
	CALL MUL2_REG16A
	MVI  D,lo(REG16_TMP_GETNUM)
	CALL MOV_REG16D_REG16E 	; TMP=REG(E)*2
	MOV  A,E
	CALL MUL2_REG16A
	CALL MUL2_REG16A	; REG(E)=REG(E)*8
	
	MVI  D,lo(REG16_TMP_GETNUM)
	CALL ADD_REG16D_REG16E	; TMP=REG(E)*10
	MOV  A,D
	CALL ADD_REG16A_B	; TMP=REG(E)*10+B
	CALL MOV_REG16E_REG16D
	JMP .LOOP
.EXIT:
	CALL POP_BC
	JMP  POP_A

;;;----------------------------------------------------------------------------
;;; Monitor Command
;;; .c         :    Clear memory
;;; .dxxxx,yyyy:    Dump memory
;;;----------------------------------------------------------------------------
VTL_MONITORCMD:
	CALL INC_REG16D
	CALL MOV_A_MEMREG16D

	CPI 'c'		; clear program area
	JZ  MEM_CLEAR
	CPI 'd'		; dump MEMORY
	JZ  MEM_DUMP
	JMP VTL_MAIN

MEM_CLEAR:	
	CALL PUSH_BC
	LXI_HL PROGRAM_START
	LXI_BC PROGRAM_END
.LOOP:
	MVI M,0
	INR L
	JNZ .L1
	INR H
.L1:	MOV A,H
	CMP B
	JNZ .LOOP
	MOV A,L
	CMP C
	JNZ  .LOOP
	CALL POP_BC
	JMP  VTL_MAIN

MEM_DUMP:	
	CALL INC_REG16D
	
	MVI E,lo(REG16_MON_TMP)
	CALL GETHEXNUMBER_MEMREG16D_REG16E
	CALL MOV_A_MEMREG16D
	ANA A
	JZ  .L1
	CALL INC_REG16D
	MVI E,lo(REG16_MON_TMP2)
	CALL GETHEXNUMBER_MEMREG16D_REG16E
	JMP .L2
.L1:
	MVI E,lo(REG16_MON_TMP2)
	MVI D,lo(REG16_MON_TMP)
	CALL MOV_REG16E_REG16D
	MOV L,E
	MOV A,M
	ADI 0FFH
	MOV M,A
	INR L
	MOV A,M
	ACI 00H
	MOV M,A			; REG(MOMTMP2)=REG(MONTMP)+0FFH
	
.L2:
	MVI D,lo(REG16_MON_TMP)
	MVI E,lo(REG16_MON_TMP2)
.LOOP1:
	CALL PRINTHEX_REG16D
	PUTCHAR ':'
.LOOP2:
	PUTCHAR ' '
	CALL MOV_A_MEMREG16D
	CALL PRINTHEX_A
	CALL CMP_UNSIGNED_REG16D_REG16E
	JZ   VTL_MAIN	          ;  exit if REG16(TMP)==REG16(TMP2)
	CALL INC_REG16D
	MVI  H,REGPAGE
	MOV  L,D
	MOV  A,M
	ANI  0FH
	JNZ .LOOP2
	CALL PRINT_CRLF
	JMP .LOOP1

;;;----------------------------------------------------------------------------
;;; Subroutines for REG16 (16bit registars)
;;;----------------------------------------------------------------------------
;;;----------------------------------------------------------------------------
;;; CLEAR_REG16D
;;; REG16(D) = 0
;;; destroy: HL (H=REGPAGE)
;;;----------------------------------------------------------------------------
CLEAR_REG16D:
	MVI H,REGPAGE
	MOV L,D
	MVI M,0
	INR L
	MVI M,0
	RET

CLEAR_REG16E:
	MVI H,REGPAGE
	MOV L,E
	MVI M,0
	INR L
	MVI M,0
	RET

CLEAR_REG16L:
	MVI H,REGPAGE
	MVI M,0
	INR L
	MVI M,0
	RET

;;;----------------------------------------------------------------------------
;;; CTOREG16NUM_A
;;; return lower byte of the address of REG16_x, (x=A to Z)
;;; no error check
;;;----------------------------------------------------------------------------
CTOREG16NUM_A:
	ANI 5FH			; toupper
	SUI 'A'
	RLC
	ADI lo(REG16_A_TO_Z)
	RET

;;;----------------------------------------------------------------------------
;;; MOV_REG16D_8BIT_A
;;; REG16(D) = A
;;; destroy: HL
;;;----------------------------------------------------------------------------
MOV_REG16D_8BIT_A:
	MVI H,REGPAGE
	MOV L,D
	MOV M,A
	INR L
	MVI M,0
	RET

;;;----------------------------------------------------------------------------
;;; MOV_REG16D_BC
;;; REG16(D) = BC
;;; destroy: HL
;;;----------------------------------------------------------------------------
MOV_REG16D_BC:
	MVI H,REGPAGE
	MOV L,D
	MOV M,C
	INR L
	MOV M,B
	RET

;;;----------------------------------------------------------------------------
;;; MOV_BC_REG16D
;;; BC = REG16(D)
;;; destroy: HL
;;;----------------------------------------------------------------------------
MOV_BC_REG16D:
	MOV L,D
MOV_BC_REG16L:
	MVI H,REGPAGE
	MOV C,M
	INR L
	MOV B,M
	RET
	
;;;----------------------------------------------------------------------------
;;; GETSIGN_REG16D
;;; Get a sign of REG(D) and set Carry flag
;;; destroy: HL,A (H=REGPAGE)
;;;----------------------------------------------------------------------------
GETSIGN_REG16D:
	MVI H,REGPAGE
	MOV L,D
	INR L
	MOV A,M
	RAL
	RET
	
;;;----------------------------------------------------------------------------
;;; COMPLEMENT2_REG16D
;;; make 2's complement
;;; REG16(D) = (not REG16(D)) + 1
;;; destroy: HL,A,B
;;;----------------------------------------------------------------------------
COMPLEMENT2_REG16D:
	MVI H,REGPAGE
	MOV L,D
	MOV A,M
	XRI 0FFH
	MOV M,A			; (HL)=not(HL) lower byte
	INR L
	MOV A,M
	XRI 0FFH
	MOV M,A			; (HL)=not(HL) upper byte
	JMP INC_REG16D		; (HL)=(HL)+1

;;;----------------------------------------------------------------------------
;;; ISZERO_REG16D
;;; return:
;;; 	Z = 1, REG16(D) == 0
;;;     Z = 0, otherwise
;;; destroy: A, HL
;;;----------------------------------------------------------------------------
ISZERO_REG16D:
	MOV L,D
ISZERO_REG16L:
	MVI H,REGPAGE
	MOV A,M
	ANA A
	RNZ			; Z = 0 (A!=0)
	INR L
	MOV A,M
	ANA A			; Z = (A==0) ? 1:0
	RET
	
;;;----------------------------------------------------------------------------
;;; ADD_REG16A_B
;;; REG16(A) = REG16(A) + B
;;; Carry set if overflow
;;; destroy: A, HL
;;;----------------------------------------------------------------------------
ADD_REG16A_B:
	MVI H,REGPAGE
	MOV L,A
	MOV A,B
	ADD M
	MOV M,A
	INR L
	MVI A,00H
	ADC M
	MOV M,A
	RET

;;;----------------------------------------------------------------------------
;;; ADD_REG16D_REG16E
;;; REG16(D) = REG16(D) + REG16(E)
;;; Carry set if overflow
;;; destroy: A, HL
;;;----------------------------------------------------------------------------
ADD_REG16D_REG16E:
	CALL PUSH_BC	
	MVI H,REGPAGE
	MOV L,E
	MOV C,M
	INR L
	MOV B,M			; BC=REG16(E)

	MOV L,D
	MOV A,C
	ADD M
	MOV M,A
	INR L
	MOV A,B
	ADC M
	MOV M,A
	JMP POP_BC		; POP does not affect to Carry

;;;----------------------------------------------------------------------------
;;; SUB_REG16D_REG16E
;;; REG16(D) = REG16(D) - REG16(E)
;;; destroy: A, HL
;;;----------------------------------------------------------------------------
SUB_REG16D_REG16E:
	CALL PUSH_BC	
	MVI H,REGPAGE
	MOV L,D
	MOV C,M
	INR L
	MOV B,M			; BC=REG(D)

	MOV L,E
	MOV A,C
	SUB M
	MOV C,A			; C=REG(D)-REG(E) (lower byte)

	INR L
	MOV A,B
	SBB M
	MOV B,A			; B=REG(D)-REG(E)-carry (upper byte)
	
	MOV L,D			; write back result to REG(D)
	MOV M,C
	INR L
	MOV M,B
	
	JMP POP_BC		; POP does not affect to Carry

;;;----------------------------------------------------------------------------
;;; MUL2_REG16A
;;; REG16(A) = REG16(A)*2
;;; C=1 if overflow
;;; destroy: HL
;;;----------------------------------------------------------------------------
MUL2_REG16A:
	MVI H,REGPAGE
	MOV L,A
	ANA A			; clear Carry
	MOV A,M
	RAL			; {C,A[7:0]}<={A[7:0],C}
	MOV M,A

	INR L
	MOV A,M
	RAL			; {C,A[7:0]}<={A[7:0],C}
	MOV M,A
	DCR L			; DCR does not affect Carry
	MOV A,L			; restore A
	RET

;;;----------------------------------------------------------------------------
;;; DIV2_REG16A
;;; REG16(A) = REG16(A)/2
;;; C=1 if LSB is 1;
;;; destroy: HL
;;;----------------------------------------------------------------------------
DIV2_REG16A:
	MVI H,REGPAGE
	MOV L,A
	INR L
	MOV A,M
	ANA A			; clear Carry

	RAR			; {A[7:0],C}<={C,A[7:0]}
	MOV M,A
	DCR L
	MOV A,M
	RAR			; {A[7:0],C}<={C,A[7:0]}
	MOV M,A
	MOV A,L			; restore A
	RET
	
;;;----------------------------------------------------------------------------
;;; MUL_REG16D_REG16E
;;; REG16(D) =  REG16(D) * REG16(E)
;;; destroy A,HL
;;;----------------------------------------------------------------------------
MUL_REG16D_REG16E:
	CALL PUSH_BC
	CALL PUSH_DE

	MVI B,lo(REG16_TMP_MUL)
	CALL MOV_REG16B_REG16D	; REG(TMP)= REG(D)
	
	MVI B,lo(REG16_TMP2_MUL)
	CALL MOV_REG16B_REG16E	; REG(TMP2)= REG(E)
	
	MVI H,REGPAGE
	MOV L,D
	MVI M,0
	INR L			; clear resister for result
	MVI M,0	                ; REG(D) = 0

	MVI E,lo(REG16_TMP_MUL)	 ; D (<<=1 for each loop)
	MVI B,lo(REG16_TMP2_MUL) ; E (>>=1 for each loop)

	MVI C,16
.LOOP:
	MOV A,B			; B=TMP2 (=E>>x)
	CALL DIV2_REG16A	; E>>=1
	JNC .NEXT
	CALL ADD_REG16D_REG16E	; ADD D to result if LSB(E) was 1
.NEXT:	
	MOV A,E			; E=TMP (=D<<x)
	CALL MUL2_REG16A	; D<<=1
	DCR C
	JNZ .LOOP
	CALL POP_DE
	JMP POP_BC
	
;;;----------------------------------------------------------------------------
;;; DIV_UNSIGNED_REG16D_REG16E (for unsigned 16bit int REG(D) and REG(E))
;;; REG16(D) =  ((unsigned int)REG16(D)) / (unsigned int)REG16(E))
;;; REG(RMND) = remainder
;;; destroy: HL, A
;;;----------------------------------------------------------------------------
DIV_UNSIGNED_REG16D_REG16E:
	CALL PUSH_BC
	CALL PUSH_DE

	MVI B,lo(REG16_DIVIDEND)
	CALL MOV_REG16B_REG16D		; copy REG(D) to DIVIDEND
	MOV D,B
	MVI B,lo(REG16_DIVISOR)		; copy REG(E) to DIVISOR
	CALL MOV_REG16B_REG16E
	MOV E,B
	
	LXI_BC 0001H		;BC=0001H
	MVI B,00
	MVI C,01H
DIV_NORMALIZE_LOOP:
	MVI H,REGPAGE
	MVI L,lo(REG16_DIVISOR)+1 ; upper byte of DIVISOR
	MOV A,M
	ANI 80H
	JNZ DIV_START           ; if MSB(bit15)==1 then start division
	MVI A,lo(REG16_DIVISOR)
	CALL MUL2_REG16A	; DIVISOR=DIVISOR<<1
	XRA A			; clear carry
	MOV A,C
	RAL
	MOV C,A
	MOV A,B
	RAL
	MOV B,A			; BC=BC<<1
	JNC DIV_NORMALIZE_LOOP	; loop while BC not overflow
	JMP DIV_DIV0		; BC overflow
DIV_START:
	MVI  L,lo(REG16_DIVRESULT)
	CALL CLEAR_REG16L
	
DIV_LOOP:
	MVI  D,lo(REG16_DIVIDEND)
	MVI  E,lo(REG16_DIVISOR)
	CALL CMP_UNSIGNED_REG16D_REG16E
	JC   DIV_NEXT
	CALL SUB_REG16D_REG16E

	MVI H,REGPAGE
	MVI L,lo(REG16_DIVRESULT)
	MOV A,C
	ADD M
	MOV M,A
	INR L
	MOV A,B
	ADC M
	MOV M,A			; RESULT=RESULT+BC
	
DIV_NEXT:
	MVI  A,lo(REG16_DIVISOR)
	CALL DIV2_REG16A
	XRA A			; clear carry
	MOV A,B
	RAR
	MOV B,A
	MOV A,C
	RAR
	MOV C,A			; BC=BC>>1
	JNC DIV_LOOP		; loop until Carry=(01H>>1)

	MVI D,lo(REG16_RMND)	; copy the last DIVIDENT to RMND
	MVI E,lo(REG16_DIVIDEND)
	CALL MOV_REG16D_REG16E

DIV_EXIT:
	CALL POP_DE
	MVI  B,lo(REG16_DIVRESULT)
	CALL MOV_REG16D_REG16B
	JMP  POP_BC

;;; 	 Error: divide by zero 
DIV_DIV0:
	MVI H,REGPAGE
	MVI L,lo(REG16_RMND)	; RMND = 0
	MVI M,0
	INR L
	MVI M,0

	MVI L,lo(REG16_DIVRESULT) ;DIVRESULT=MAXINT
	MVI M,lo(MAXINT)
	INR L
	MVI M,up(MAXINT)
	JMP DIV_EXIT
	
;;;----------------------------------------------------------------------------
;;; DIV_REG16D_REG16E
;;; REG16(D) =  REG16(D) / REG16(E)
;;; REG16(D) : dividend
;;; REG16(E) : divisor
;;; REG(RMND) = remainder
;;; destroy: HL,A
;;;----------------------------------------------------------------------------
DIV_REG16D_REG16E:
	MOV A,E
	CALL PUSH_REG16A		; push REG(E)
	CALL PUSH_BC
	MOV C,D			        ; save D to C

	LXI_HL REG8_SIGNDIVIDEND	; clear sign of the dividend
	MVI M,0
	LXI_HL REG8_SIGNDIVISOR		; clear sign of the divisor
	MVI M,0
	
	CALL GETSIGN_REG16D
	JNC  .L1
	;;; for NEGATIVE_DIVIDEND
	CALL COMPLEMENT2_REG16D		; REG(D)=abs(REG(D))
	LXI_HL REG8_SIGNDIVIDEND	; set sign of the result
	MVI M,01H
.L1:
	MOV  D,E
	CALL GETSIGN_REG16D
	JNC  .L2
	;;; for NEGATIVE_DIVISOR
	CALL COMPLEMENT2_REG16D		; REG(E)=abs(REG(E))
	LXI_HL REG8_SIGNDIVISOR		; toggle sign of the divisor
	MVI M,01H
.L2:
	;; exec DIV_UNSIGNED
	MOV  D,C		        ; restore D from C
	CALL DIV_UNSIGNED_REG16D_REG16E

	LXI_HL REG8_SIGNDIVIDEND        ; DIVIDEND<0 then RMND=-RMND
	MOV  A,M
	ANA  A
	JZ  .L3
	MVI D,lo(REG16_RMND)
	CALL COMPLEMENT2_REG16D
.L3:
	LXI_HL REG8_SIGNDIVIDEND	; sign(DIVIDEND) != sign(DIVISOR)
	MOV  A,M			; then REG(D)=-REG(D)
	LXI_HL REG8_SIGNDIVISOR
	CMP M
	JZ .L4
	MOV D,C
	CALL COMPLEMENT2_REG16D		; REG(D)=-REG(D)
.L4:
	CALL POP_BC
	MOV A,E
	JMP POP_REG16A		        ; POP REG(E) and return

	
;;;----------------------------------------------------------------------------
;;; XOR_REG16D_REG16E
;;; REG16(D) = REG16(D) ^ REG16(E)
;;; destroy: A,HL
;;;----------------------------------------------------------------------------
XOR_REG16D_REG16E:
	MVI H,REGPAGE
	MOV L,E
	MOV A,M
	MOV L,D
	XRA M
	MOV M,A
	MOV L,E
	INR L
	MOV A,M
	MOV L,D
	INR L
	XRA M
	MOV M,A
	RET

;;;----------------------------------------------------------------------------
;;; AND_REG16D_REG16E
;;; REG16(D) = REG16(D) & REG16(E)
;;; destroy: A,HL
;;;----------------------------------------------------------------------------
AND_REG16D_REG16E:
	MVI H,REGPAGE
	MOV L,E
	MOV A,M
	MOV L,D
	ANA M
	MOV M,A
	MOV L,E
	INR L
	MOV A,M
	MOV L,D
	INR L
	ANA M
	MOV M,A
	RET

;;;----------------------------------------------------------------------------
;;; OR_REG16D_REG16E
;;; REG16(D) = REG16(D) | REG16(E)
;;; destroy: A,HL
;;;----------------------------------------------------------------------------
OR_REG16D_REG16E:
	MVI H,REGPAGE
	MOV L,E
	MOV A,M
	MOV L,D
	ORA M
	MOV M,A
	MOV L,E
	INR L
	MOV A,M
	MOV L,D
	INR L
	ORA M
	MOV M,A
	RET

;;;----------------------------------------------------------------------------
;;; CMP_UNSIGNED_REG16D_REG16E
;;; Compare by REG16(D) - REG16(E)
;;; Z=1, C=0: REG16(D) == REG16(E)
;;; Z=0, C=1: REG16(D) <  REG16(E)
;;; Z=0, C=0: REG16(D) >= REG16(E)
;;; destroy: A,HL
;;;----------------------------------------------------------------------------
CMP_UNSIGNED_REG16D_REG16E:
	MVI H,REGPAGE
	MOV L,D
	INR L
	MOV A,M			; A = upper byte of REG(D)
	MOV L,E
	INR L
	CMP M			;upper byte REG(D)-REG(E)
	RNZ			; return if upper byte REG(D)!=REG(E)
	MOV L,D
	MOV A,M			; A = lower byte of REG(D)
	MOV L,E
	CMP M			;lower byte REG(D)-REG(E)
	RET
	
;;;----------------------------------------------------------------------------
;;; CMP_REG16D_REG16E (compare signed 16 bit integer)
;;; -32767=8001H<=X<=7FFFH=32767
;;; zero is 0000H
;;; positive number is  0001H to  7FFFH (1 to 32767)
;;; negative number is  8001H to 0FFFFH (-32767 to -1)
;;; 8000H is undefined number
;;; Z=1, C=0: REG16(D) == REG16(E)
;;; Z=0, C=1: REG16(D) <  REG16(E)
;;; Z=0, C=0: REG16(D) >= REG16(E)
;;; destroy: A,HL
;;;----------------------------------------------------------------------------
CMP_REG16D_REG16E:
	MVI H,REGPAGE
	MOV L,D
	INR L
	MOV A,M
	RAL
	JC .NEGD
	MOV L,E
	INR L
	MOV A,M
	RAL
	JC .POSD_NEGE
	JMP CMP_UNSIGNED_REG16D_REG16E	;; POSD_POSE
.NEGD:
	MOV L,E
	INR L
	MOV A,M
	RAL
	JNC .NEGD_POSE
	CALL CMP_UNSIGNED_REG16D_REG16E	;; NEGD_NEGE
	RZ				; return if equal
	;; make complement C
	MVI A,01H			; to reset Z flag by RAL&XRI 01H
	RAL
	XRI 01H
	RAR
	RET			; Z=0, C=(not C)
.POSD_NEGE:
	XRA A
	ADI 01H			; Z=0, C=0
	RET
.NEGD_POSE:
	XRA A
	SUI 01H			; Z=0, C=1
	RET

;;;----------------------------------------------------------------------------
;;; MAKE_RANDOMNUMBER:
;;; Pseudo random number generator
;;; destroys REG16_TMP, REG16_TMP2, HL,A
;;; 
;;; REG16_RANDOM0: hidden state  (x)
;;; REG16_RANDOM1: RANDOM NUMBER (y)
;;; 
;;; 16bit xorshift algorithm
;;; https://b2d-f9r.blogspot.com/2010/08/16-bit-xorshift-rng-now-with-more.html
;;; unsigned REG16 x, y, t
;;; initial state: x=y=RANDOM_SEED
;;; t = x ^ (x<<5)
;;; x = y
;;; t = t ^ (t>>3)
;;; y = y ^ (y>>1)
;;; y = y ^ t
;;;----------------------------------------------------------------------------
MAKE_RANDOMNUMBER:
	CALL PUSH_BC
	CALL PUSH_DE

	MVI D,lo(REG16_TMP)		; t
	MVI E,lo(REG16_RANDOM0)		; x

	CALL MOV_REG16D_REG16E		; t=x
	MOV  A,D
	CALL MUL2_REG16A		;
	CALL MUL2_REG16A		;
	CALL MUL2_REG16A		;
	CALL MUL2_REG16A		;
	CALL MUL2_REG16A		; t=x<<5
 	CALL XOR_REG16D_REG16E  	; t= (x<<5) ^ x

	MVI  D,lo(REG16_RANDOM1)	; y
	CALL MOV_REG16E_REG16D		; x = y
	
	MVI  D,lo(REG16_TMP2)
	MVI  E,lo(REG16_TMP)		; t
	CALL MOV_REG16D_REG16E		; tmp2=t
	MOV  A,D
	CALL DIV2_REG16A
	CALL DIV2_REG16A
	CALL DIV2_REG16A   		; tmp2 = t>>3
	CALL XOR_REG16D_REG16E		; tmp2 = (t>>3)^t

	MVI  D,lo(REG16_RANDOM1)	; y
	MVI  E,lo(REG16_TMP)
	CALL MOV_REG16E_REG16D    	; t = y
	MOV  A,E
	CALL DIV2_REG16A		; t = y>>1
	CALL XOR_REG16D_REG16E 		; y = y^(y>>1)
	
	MVI  E,lo(REG16_TMP2)
	CALL XOR_REG16D_REG16E		; y = y^tmp2

	CALL POP_DE
	JMP  POP_BC
	
;;;---------------------------------------------------------------------------
;;; Program for Very Tiny Language Interpreter
;;;---------------------------------------------------------------------------
	
;;;---------------------------------------------------------------------------
VTL_START:
;;;---------------------------------------------------------------------------
;;; some initialization
;;;---------------------------------------------------------------------------
	; initialize stack pointers
	LXI_HL STACK
	MVI M,0
	LXI_HL PCSTACK
	MVI M,0

	; initialize constants
	LXI_HL REG16_CONST_10000
	MVI M,lo(10000)
	INR L
	MVI M,up(10000)
	INR L
	MVI M,lo(1000)
	INR L
	MVI M,up(1000)
	INR L
	MVI M,lo(100)
	INR L
	MVI M,up(100)
	INR L
	MVI M,lo(10)
	INR L
	MVI M,up(10)

.LOOP:
	LXI_HL STR_VTL_MESSAGE
	CALL PUTS
	MVI_REG16 REG16_PEND,PROGRAM_START	; REG(PEND) = PROGRAM_START
	MVI_REG16 REG16_RANDOM0, RANDOM_SEED 	; REG(RANDOM0) = RANDOM_SEED
	MVI_REG16 REG16_RANDOM1, RANDOM_SEED	; REG(RANDOM1) = RANDOM_SEED

	JMP VTL_NOERROR
;;;---------------------------------------------------------------------------
;;; Main Loop
;;;---------------------------------------------------------------------------
VTL_MAIN:
;;;---------------------------------------------------------------------------
;;; Error check
;;;---------------------------------------------------------------------------
	;; print REG(ERROR) if not zero
	LXI_HL REG16_ERROR
	CALL ISZERO_REG16L
	JZ  VTL_NOERROR
	;; print error message
	MVI D,lo(REG16_ERROR)
	CALL PRINTSTR_MEMREG16D
	PUTCHAR ' '
	LXI_HL REG8_ERROR2
	MOV A,M
	CALL PRINTHEX_A		; print error code
	PUTCHAR ' '
	
	;; print remainig buffer 
	LXI_HL STR_VTL_BUF
	CALL PUTS

	MVI D,lo(REG16_INDEX)
	CALL DEC_REG16D
	CALL PRINTSTR_MEMREG16D ; print (REG(INDEX)-1) (for debug)
	CALL PRINT_CRLF

	;; print error line number
	MVI D,lo(REG16_LINENUM)
	CALL ISZERO_REG16D
	JZ  VTL_ERROR_NOLINENUM
	LXI_HL STR_VTL_ERRORLINENUM
	CALL PUTS
	MVI D,lo(REG16_LINENUM)
	CALL PRINT_REG16D
	CALL PRINT_CRLF
	
VTL_ERROR_NOLINENUM:
VTL_NOERROR:
	;; Check stack pointer
	;; 
	;; if SP !=0 print it and reset (for debug)
	LXI_HL STACK
	MOV A,M
	MOV C,A
	ANA A
	JZ  VTL_SPOK
	LXI_HL STR_VTL_SP
	CALL PUTS
	MOV  A,C
	CALL PRINTHEX_A
	CALL PRINT_CRLF
VTL_SPOK:
	LXI_HL PCSTACK
	MOV A,M
	MOV C,A
	ANA A
	JZ  VTL_OK
	LXI_HL STR_VTL_PCSP
	CALL PUTS
	MOV  A,C
	CALL PRINTHEX_A
	CALL PRINT_CRLF

VTL_OK:	
	;; Reset stack pointers and error registers
	;; and print a prompt 'OK'

	;; RESET SP
	XRA A
	LXI_HL STACK
	MOV M,A
	LXI_HL PCSTACK
	MOV M,A

	;; RESET RETURN STACK
	MVI_REG16 REG16_RETURNSTACK,RETURNSTACK
	
	;; clear error registers
	XRA A
	MVI H,REGPAGE
	MVI L,lo(REG16_ERROR)
	MOV M,A
	INR L
	MOV M,A
	MVI L,lo(REG8_ERROR2)
	MOV M,A
	
	LXI_HL STR_VTL_OK
	CALL PUTS

;;; LOOP entry for program input
VTL_LOOP:
	;; 	PUTCHAR '%'	; put a prompt (for debug)

	MVI L,lo(REG16_LINENUM)	; clear linenumber counter
	CALL CLEAR_REG16L
	
	MVI_REG16 REG16_INDEX,LINEBUF 	; REG(INDEX) = LINEBUF

;;; function test (for debug)
;;;   	include "test.asm"
;;; TEST_EXIT:
	
	MVI  D,lo(REG16_INDEX)
	CALL GETLINE_MEMREG16D
	CALL MOV_A_MEMREG16D	; ACC=(REG(INDEX))
	
	CPI '.'			; monitor command
	JZ  VTL_MONITORCMD

	CALL ISNUM_A
	JC  VTL_INSERT_PROGRAMLINE ; Top character is a number

	MVI_REG16 REG16_LINENUM,0 ; REG(LINENUM)=0
	MVI_REG16 REG16_NEXTLINE_PTR, PROGRAM_END
				; REG(NEXTLINE_PTR)=MEMEND to exit after exec

	MVI D,lo(REG16_INDEX)
	JMP VTL_RUN_SINGLE_LINE

;;;----------------------------------------------------------------------------
;;; FIND_LINE_AND_EXEC
;;; Search for the linenumber REG(LINENUM) and find the pointer of the line
;;; to be executed (minimum linenumber >= REG(LINENUM))
;;; in the PM(PROGRAM) and set REG(LINENUM) to the found linenumber
;;; and execute it
;;;----------------------------------------------------------------------------
FIND_LINE_AND_EXEC:
	MVI_REG16 REG16_INDEX,PROGRAM_START ; REG(INDEX) = PROGRAM_START
	MOV D,L				    ; D=INDEX

.LOOP:
	MVI  E,lo(REG16_THISLINE_PTR)
	CALL MOV_REG16E_REG16D			; REG(THISLINE_PTR)=REG(INDEX)

	MVI  E,lo(REG16_TMP)
	CALL MOV_REG16E_MEMREG16D		; REG(TMP) =current line numbe
	CALL INC_REG16D
	CALL INC_REG16D				; REG(D)++ (+2byte)

	
	MVI  D,lo(REG16_TMP)
	MVI  E,lo(REG16_LINENUM)
	CALL CMP_UNSIGNED_REG16D_REG16E
 	JNC   .GO		; REG(TMP) >= REG(LINENUM) then GO (exec)
	
	MVI  D,lo(REG16_INDEX)
	MVI  E,lo(REG16_INDEX)
	CALL MOV_REG16E_MEMREG16D		; REG(INDEX)= next line pointer

	MVI  E,lo(REG16_PEND)
	CALL CMP_UNSIGNED_REG16D_REG16E
	JC  .LOOP			; loop while REG(INDEX)<REG(PEND)
	JMP VTL_MAIN				; reach the end of the program

.GO:
	CALL MOV_REG16E_REG16D	; REG(LINENUM) = real linenum
	JMP  VTL_RUN_PROGRAM_MINDEX_FROM_GOTO ; 
	
;;;----------------------------------------------------------------------------
;;; VTL_RUN_PROGRAM_MINDEX:
;;; Run the program buffer "MINDEX" (= MEM(REG(INDEX)) = *REG(INDEX))
;;; one line is:
;;; 	2 byte: linenumber
;;; 	2 byte: PTR to next line
;;; 	   x  : program code
;;; 	1 byte: 00H (EOL)
;;; if REG(NEXTLINE_PTR)==0 or REG(NEXTLINE_PTR)>=REG(PEND) then back to prompt
;;;----------------------------------------------------------------------------
VTL_RUN_PROGRAM_MINDEX:
	MVI D,lo(REG16_INDEX)
	MVI E,lo(REG16_THISLINE_PTR)
	CALL MOV_REG16E_REG16D    ; REG(THIS_LINE_PTR)=REG(INDEX)

	MVI  E,lo(REG16_LINENUM)        ; REG(LINENUM)=current line number
	CALL MOV_REG16E_MEMREG16D	;             (=*REG(INDEX))
	CALL INC_REG16D			; REG(INDEX)++ (+=2)
	CALL INC_REG16D

VTL_RUN_PROGRAM_MINDEX_FROM_GOTO:
	MVI D,lo(REG16_INDEX)
	MVI E,lo(REG16_NEXTLINE_PTR)
	CALL MOV_REG16E_MEMREG16D	; REG(NEXT_LINE_PTR)=*REG(INDEX)
	CALL INC_REG16D                 ; REG(INDEX)++ (+=2)
	CALL INC_REG16D

	JMP VTL_RUN_SINGLE_LINE

VTL_RUN_PROGRAM_MINDEX_FROM_RETURN:
	;; recover context (INDEX, THISLINE_PTR, NEXTLINE_PTR)
	MVI D,lo(REG16_RETURNSTACK)

	MVI  E,lo(REG16_NEXTLINE_PTR)
	CALL MOV_REG16E_MEMREG16D
	CALL INC_REG16D
	CALL INC_REG16D

	MVI  E,lo(REG16_THISLINE_PTR)
	CALL MOV_REG16E_MEMREG16D
	CALL INC_REG16D
	CALL INC_REG16D

	MVI  E,lo(REG16_INDEX)
	CALL MOV_REG16E_MEMREG16D
	CALL INC_REG16D
	CALL INC_REG16D

VTL_RUN_NEXTLINE:
	MVI  D,lo(REG16_NEXTLINE_PTR)
	MVI  E,lo(REG16_PEND)
	CALL CMP_UNSIGNED_REG16D_REG16E
	JNC  VTL_MAIN		; exit if REG(NEXTLINE_PTR) >= REG(PEND)
	MVI  D,lo(REG16_INDEX)
	MVI  E,lo(REG16_NEXTLINE_PTR)
	CALL MOV_REG16D_REG16E		; REG(INDEX) = REG(NEXTLINE_PTR)
	JMP  VTL_RUN_PROGRAM_MINDEX	; continue running program

;;;----------------------------------------------------------------------------
;;; VTL_EXECUTE_MINDEX
;;; Execute a string *REG(INDEX)
;;; destroy: HL,A,BC,DE
;;;----------------------------------------------------------------------------
VTL_RUN_SINGLE_LINE:
;;; 	JMP VTL_EXECUTE_MINDEX
VTL_EXECUTE_MINDEX:
	;; if some initialization is needed, write here
VTL_EXECUTE_MINDEX_CONTINUE:
	MVI D,lo(REG16_INDEX)

SKIPSPACE:
	CALL MOV_A_MEMREG16D
	CPI  ' '
	JNZ .NEXT
	CALL INC_REG16D		  ; REG(INDEX)++ while ' '
	JMP  SKIPSPACE
.NEXT:
	; check the left term
	ANA  A
	JZ   VTL_RUN_NEXTLINE ; EOF then return to the run loop

	CALL INC_REG16D		; REG(INDEX)++ index incremented in advance

	CPI '?' 		; '?=', '??=' or '?$='
	JZ  DISPATCH_PRINT
	CPI ']'			; RETURN
	JZ  VTL_RUN_PROGRAM_MINDEX_FROM_RETURN
	CPI '@'			; Array
	JNZ  VTL_EXEC_LEFTTERM

GET_ARRAY_INDEX:		; evaluate index and save to REG16_ARRAYINDEX
	LXI_BC .RETURN
	MVI E,lo(REG16_ARRAYINDEX)
	JMP GETFACTOR_MINDEX_REG16E
.RETURN:
	MVI D,lo(REG16_INDEX)
	MVI A,'@'

VTL_EXEC_LEFTTERM:
	;; "left term = right expression" type procedures
	CALL PUSH_A		; push the left term
	;; check '='
	CALL MOV_A_MEMREG16D
	CPI '='
	JZ  VTL_EXEC_EQUAL_OK
 	CALL POP_A		; pop the left term before go to error
	JMP VTL_EXEC_SYNTAX_ERROR
VTL_EXEC_EQUAL_OK:
 	CALL INC_REG16D
	;; Evaluate the right expression
	LXI_BC .RETURN
	MVI E,lo(REG16_EVAL)
	JMP EVAL_EXPRESSION_MINDEX_REG16E
.RETURN:
	CALL POP_A		; pop the left term
	;; Dispatch according to the left term
	CALL ISALPHA_A
	JC VTL_EXEC_ASSIGN_VARIABLE
	CPI '@'
	JZ VTL_EXEC_ARRAY
	CPI ';'
	JZ VTL_EXEC_IF
	CPI '#'
	JZ VTL_EXEC_GOTO
	CPI '!'
	JZ VTL_EXEC_GOSUB_PUSHCONTEXT_AND_GO
	CPI '&'
	JZ VTL_EXEC_ASSIGN_PEND
	CPI '$'
	JZ VTL_EXEC_PUTCHAR
	CPI '\''
  	JZ VTL_EXEC_ASSIGN_SEED
	CPI '>'
 	JZ VTL_EXEC_FAST_GOTO

VTL_EXEC_SYNTAX_ERROR:
	LXI_HL REG8_ERROR2
	MOV M,A		; ERROR2 = A
	MVI_REG16 REG16_ERROR, STR_VTL_ERROR_SYNTAX
	JMP VTL_MAIN

DISPATCH_PRINT:	
	;; check the next char to '?' and set print format
	CALL MOV_A_MEMREG16D  ; check printformat "?=" or "?$=" or "??="
	CPI '$'
	JZ  VTL_EXEC_PRINT_HEX2
	CPI '?'
	JZ VTL_EXEC_PRINT_HEX4
	;; assume that it's "?=" but not check "=" here
	JMP VTL_EXEC_PRINT

VTL_EXEC_ASSIGN_VARIABLE: ;; Assignment to the normal variable
	CALL CTOREG16NUM_A	; convert the name to the register address
	MOV  E,A
	MVI  D,lo(REG16_EVAL)
	CALL MOV_REG16E_REG16D
	JMP VTL_EXECUTE_MINDEX_CONTINUE ; execute remaining string

VTL_EXEC_ARRAY: 	;; Assignment to Array
	MVI D,lo(REG16_ARRAYINDEX)
	MOV A,D
	CALL MUL2_REG16A
	MVI E,lo(REG16_TMP)
	MVI H,REGPAGE
	MOV L,E
	MVI M,lo(ARRAYTOP)
	INR L
	MVI M,up(ARRAYTOP)
	CALL ADD_REG16D_REG16E	; now, REG(ARRAYINDEX) is address of
				; the array item (ARRAYTOP+ARRAYINDEX*2)
	MVI  D,lo(REG16_ARRAYINDEX)
	MVI  E,lo(REG16_EVAL)
	CALL MOV_MEMREG16D_REG16E       ; *REG(ARRAYINDEX)=REG(EVAL)
	JMP  VTL_EXECUTE_MINDEX_CONTINUE ; execute remaining string
	
VTL_EXEC_IF:
	MVI  D,lo(REG16_EVAL)
	CALL ISZERO_REG16D
	JZ   VTL_RUN_NEXTLINE ; go to next line
	JMP  VTL_EXECUTE_MINDEX_CONTINUE ; execute remaining string

VTL_EXEC_GOTO:
	MVI  D,lo(REG16_EVAL)
	CALL ISZERO_REG16D
	JZ   VTL_EXECUTE_MINDEX_CONTINUE ; execute remaining string
	MVI  D,lo(REG16_LINENUM)
	MVI  E,lo(REG16_EVAL)
	CALL MOV_REG16D_REG16E
	JMP  FIND_LINE_AND_EXEC	         ; execute GOTO

VTL_EXEC_ASSIGN_PEND:
	MVI  D,lo(REG16_PEND)
	MVI  E,lo(REG16_EVAL)
	CALL MOV_REG16D_REG16E
	JMP  VTL_EXECUTE_MINDEX_CONTINUE ; execute remaining string

VTL_EXEC_PUTCHAR:
	MVI H,REGPAGE
	MVI L,lo(REG16_EVAL)
	MOV A,M
	CALL PUTCH
	JMP VTL_EXECUTE_MINDEX_CONTINUE ; execute remaining string

VTL_EXEC_ASSIGN_SEED: 	;;  seed of random number
	;; REG(RANDOM0)=REG(RANDOM1)=seed
	MVI  E,lo(REG16_EVAL)
	MVI  D,lo(REG16_RANDOM0)
	CALL MOV_REG16D_REG16E
	MVI  D,lo(REG16_RANDOM1)
	CALL MOV_REG16D_REG16E
	JMP  VTL_EXECUTE_MINDEX_CONTINUE ; execute remaining string

VTL_EXEC_FAST_GOTO: ;; Jump by loading INDEX
	MVI  E,lo(REG16_EVAL)
	MVI  D,lo(REG16_INDEX)
	CALL MOV_REG16D_REG16E
	JMP  VTL_RUN_PROGRAM_MINDEX

;;;----------------------------------------------------------------------------
;;; Push context (INDEX, THISLINE_PTR, NEXTLINE_PTR) to RETURNSTACK
;;; and jump to new linenumber in REG(EVAL)
;;;----------------------------------------------------------------------------
VTL_EXEC_GOSUB_PUSHCONTEXT_AND_GO:
	MVI  D,lo(REG16_RETURNSTACK)

	MVI  E,lo(REG16_INDEX)
	CALL DEC_REG16D
	CALL DEC_REG16D
	CALL MOV_MEMREG16D_REG16E

	MVI  E,lo(REG16_THISLINE_PTR)
	CALL DEC_REG16D
	CALL DEC_REG16D
	CALL MOV_MEMREG16D_REG16E

	MVI  E,lo(REG16_NEXTLINE_PTR)
	CALL DEC_REG16D
	CALL DEC_REG16D
	CALL MOV_MEMREG16D_REG16E

	JMP VTL_EXEC_GOTO

;;;----------------------------------------------------------------------------
;;; EVAL_EXPRESSION_MINDEX_REG16E
;;; Evaluate expression *REG(INDEX) and set result to REG(E)
;;; destory: HL,A
;;; return: REG(E)=result, D=INDEX
;;; REG16(INDEX) is incremented to the end of expression +1, (EOL if EOL)
;;; 
;;; This routine returns by RETURN_BY_PCSTACK.
;;; Subroutine call for this routine is set return address to BC and JMP.
;;;----------------------------------------------------------------------------
EVAL_EXPRESSION_MINDEX_REG16E:
	CALL PUSH_BC_PCSTACK ; PUSH a return address
	CALL PUSH_DE
	
	MVI D,lo(REG16_INDEX)
	CALL MOV_A_MEMREG16D
	ANA A       ; check EOL
	JNZ EVAL_START
	;; EOL and EXIT
	;; Do nothing, and REG(EVAL) does not change.
	MVI H,REGPAGE
	MVI_REG16 REG16_ERROR, STR_VTL_ERROR_EOL
	JMP VTL_MAIN		; error and jump to VTL_MAIN

EVAL_START:	
	;; get a factor and push it
	MVI E,lo(REG16_LVALUE)
	LXI_BC .RETURN
	JMP GETFACTOR_MINDEX_REG16E
.RETURN:	
EVAL_CONTINUE:
	MVI  A,lo(REG16_LVALUE)
	CALL PUSH_REG16A		; push the LVALUE
	MVI  D,lo(REG16_INDEX)
	CALL MOV_A_MEMREG16D		; get an operator
	ANA  A				; no operator and EOL, then exit
	JZ   EVAL_EXIT
	CALL INC_REG16D			; increment INDEX if not EOL

	CPI ')'
	JZ  EVAL_EXIT			; if ')', then exit
	CPI ' '
	JZ  EVAL_EXIT			; if ' ', then exit

	CALL PUSH_A			; push the operator

	LXI_BC .RETURN
	MVI E,lo(REG16_RVALUE)
	JMP GETFACTOR_MINDEX_REG16E   ; get RVALUE
.RETURN:	
	CALL POP_A
	MOV B,A			        ; pop the operator and store to B

	MVI D,lo(REG16_LVALUE)		; set D = REG_LVALUE
	MVI E,lo(REG16_RVALUE)		; set E = REG_RVALUE
	MOV A,D
	CALL POP_REG16A		        ; pop the LVALUE
;;; 
;;;  execute operator calculation
;;; 
	MOV  A,B			; restore the operator from B
	;; dispatch by the operator
	CPI '+'
	JZ EVAL_ADD
	CPI '-'
	JZ EVAL_SUB
	CPI '*'
	JZ EVAL_MUL
	CPI '/'
	JZ EVAL_DIV
	CPI '='
	JZ EVAL_EQU
	CPI '<'
	JZ EVAL_LE
	CPI '>'		; > or =
	JZ EVAL_GEQ
	CPI '#'		; not equal
	JZ EVAL_NEQ
	CPI '%'		; reminder
	JZ EVAL_REM
	CPI '^'		; exclusive-or
	JZ EVAL_XOR
	CPI '&'		; and
	JZ EVAL_AND
	CPI '|'		; or
	JZ EVAL_OR

	;; ERROR (unknown operator)
	LXI_HL REG8_ERROR2
	MOV M,A			; ERROR2 = A
	MVI_REG16 REG16_ERROR, STR_VTL_ERROR_OPERATOR
	JMP VTL_MAIN		; error and jump to VTL_MAIN

EVAL_EXIT:
	MVI A,lo(REG16_TMP)
	CALL POP_REG16A		; return with stacked value

	CALL POP_DE
	MVI  D,lo(REG16_TMP)
	CALL MOV_REG16E_REG16D	; load result to REG(E)

	MVI D,lo(REG16_INDEX)	; restore D to INDEX
	JMP RETURN_BY_PCSTACK

EVAL_ADD:
	CALL ADD_REG16D_REG16E
	JMP EVAL_CONTINUE

EVAL_SUB:
	CALL SUB_REG16D_REG16E
	JMP  EVAL_CONTINUE

EVAL_MUL:
	CALL MUL_REG16D_REG16E
	JMP  EVAL_CONTINUE

EVAL_DIV:
	CALL DIV_REG16D_REG16E
	JMP  EVAL_CONTINUE

EVAL_EQU:
	CALL CMP_UNSIGNED_REG16D_REG16E
	JZ  EVAL_LVALUE_TRUE ; jump if REG(D)==REG(E)
EVAL_LVALUE_FALSE:	
	CALL CLEAR_REG16D	; set LVALUE=0
	JMP EVAL_CONTINUE
EVAL_LVALUE_TRUE:	
	MVI H,REGPAGE
	MOV L,D
	MVI M,01H
	INR L
	MVI M,00H		; set LVALUE=1
	JMP EVAL_CONTINUE

EVAL_LE:
 	CALL CMP_REG16D_REG16E
	JC   EVAL_LVALUE_TRUE  ; jump if REG(D) < REG(E)
	JMP  EVAL_LVALUE_FALSE

EVAL_GEQ:
;;; '>' is TEST FOR GREATER THAN OR EQUAL TO
 	CALL CMP_REG16D_REG16E
	JC   EVAL_LVALUE_FALSE	; jump if REG(D) < REG(E)
	JMP  EVAL_LVALUE_TRUE	;    REG(P0) >= REG(P1)

EVAL_NEQ:			; not equal
	CALL CMP_UNSIGNED_REG16D_REG16E
	JNZ  EVAL_LVALUE_TRUE  ; REG(D)!=REG(E)
	JMP  EVAL_LVALUE_FALSE ; REG(D)==REG(E)

EVAL_REM:
	CALL DIV_REG16D_REG16E
	MVI  E,lo(REG16_RMND)
	CALL MOV_REG16D_REG16E
	JMP EVAL_CONTINUE

EVAL_XOR:
	CALL XOR_REG16D_REG16E
	JMP  EVAL_CONTINUE

EVAL_AND:
	CALL AND_REG16D_REG16E
	JMP  EVAL_CONTINUE

EVAL_OR:
	CALL OR_REG16D_REG16E
	JMP  EVAL_CONTINUE

;;;----------------------------------------------------------------------------
;;; GETFACTOR_MINDEX_REG16E
;;; Get a value of the first factor from MINDEX and set it to REG(D)
;;; 
;;; This routine returns by RETURN_BY_PCSTACK.
;;; Subroutine call for this routine is set return address to BC and JMP.
;;;----------------------------------------------------------------------------
GETFACTOR_MINDEX_REG16E:
	CALL PUSH_BC_PCSTACK; PUSH a return address
	CALL PUSH_DE

	MVI D,lo(REG16_INDEX)
	CALL MOV_A_MEMREG16D
	;;; dispatch by the term
	CPI '('
	JZ GETFACTOR_LEFTBRACE

	MVI E,lo(REG16_FACTOR)	; REG(E) is REG16_FACTOR
	CPI '-' 		; unary operator minus '-' 
	JZ  GETFACTOR_MINUS
	CALL ISNUM_A
	JC  GETFACTOR_DECIMAL_NUMBER
	CALL ISALPHA_A
	JC  GETFACTOR_VARIABLE
	CPI '@'
	JZ  GETFACTOR_ARRAY
	CPI '%'			; remainder of the last DIV
	JZ  GETFACTOR_REMAINDER
 	CPI '#'
 	JZ  GETFACTOR_THISLINE
	CPI '\''		; random number
	JZ  GETFACTOR_RANDOM
	CPI '&'			; the last byte of program
	JZ  GETFACTOR_PEND
	CPI '$'
	JZ  GETFACTOR_GETCH	; input one charactoer from serial
	CPI '?'			; input one line from serial and evaluate it
	JZ  GETFACTOR_GETVALUE

GETFACTOR_ERROR:
	LXI_HL REG8_ERROR2
	MOV M,A
	MVI_REG16 REG16_ERROR,STR_VTL_ERROR_FACTOR
	JMP VTL_MAIN		; error and jump to VTL_MAIN

GETFACTOR_EXIT:
	MVI  D,lo(REG16_INDEX)
	CALL INC_REG16D		; increment REG(INDEX)
GETFACTOR_EXIT_NOINCREMENT:
	CALL POP_DE
	MVI  D,lo(REG16_FACTOR)
	CALL MOV_REG16E_REG16D	; load result to REG(E)
	MVI  D,lo(REG16_INDEX)	; set D to INDEX
	JMP  RETURN_BY_PCSTACK
	
GETFACTOR_LEFTBRACE:	
	CALL INC_REG16D
	LXI_BC .RETURN
	MVI E,lo(REG16_FACTOR)
	JMP EVAL_EXPRESSION_MINDEX_REG16E
.RETURN:
	JMP GETFACTOR_EXIT_NOINCREMENT

GETFACTOR_MINUS:
	CALL INC_REG16D
	LXI_BC .RETURN
	MVI E,lo(REG16_FACTOR)
	JMP GETFACTOR_MINDEX_REG16E
.RETURN:
	;; REG(FACTOR)=-REG(FACTOR) (2's complement)
	MVI D,lo(REG16_FACTOR)
	CALL COMPLEMENT2_REG16D	; REG(D)=-REG(D)
	JMP GETFACTOR_EXIT_NOINCREMENT

GETFACTOR_DECIMAL_NUMBER:	;; decimal number
	MVI  E,lo(REG16_FACTOR)
	CALL GETNUMBER_MEMREG16D_REG16E
	JMP  GETFACTOR_EXIT_NOINCREMENT

GETFACTOR_VARIABLE:	;; variable
	CALL CTOREG16NUM_A
	MOV E,A
	MVI D,lo(REG16_FACTOR)
	CALL MOV_REG16D_REG16E
	JMP GETFACTOR_EXIT

GETFACTOR_ARRAY:
	;; 16bit array
	;; @(x) = 16bit data at VTL_ARRAYTOP+x*2
	CALL INC_REG16D
	LXI_BC .RETURN
	MVI E,lo(REG16_TMP_ARRAY)
	JMP GETFACTOR_MINDEX_REG16E
.RETURN:
	MOV A,E
	CALL MUL2_REG16A
	MVI D,lo(REG16_TMP)
	MVI H,REGPAGE
	MOV L,D
	MVI M,lo(ARRAYTOP)
	INR L
	MVI M,up(ARRAYTOP)
	CALL ADD_REG16D_REG16E
	MVI E,lo(REG16_FACTOR)
	CALL MOV_REG16E_MEMREG16D
	CALL INC_REG16D
	CALL INC_REG16D
	JMP GETFACTOR_EXIT_NOINCREMENT

GETFACTOR_REMAINDER:
	MVI  D,lo(REG16_RMND)
	CALL MOV_REG16E_REG16D
	JMP GETFACTOR_EXIT

GETFACTOR_THISLINE: ; this line pointer
 	MVI D,lo(REG16_THISLINE_PTR)
 	CALL MOV_REG16E_REG16D
 	JMP GETFACTOR_EXIT

GETFACTOR_RANDOM:
	CALL MAKE_RANDOMNUMBER
	MVI D,lo(REG16_RANDOM1)
	CALL MOV_REG16E_REG16D
	;; result &= 7FFFH
	MVI H,REGPAGE
	MOV L,E
	INR L
	MOV A,M
	ANI 7FH
	MOV M,A
	JMP GETFACTOR_EXIT

GETFACTOR_PEND:
	MVI  D,lo(REG16_PEND)
	CALL MOV_REG16E_REG16D
	JMP GETFACTOR_EXIT

GETFACTOR_GETCH:
	CALL GETCH
	MVI H,REGPAGE
	MVI L,lo(REG16_FACTOR)
	MOV M,A
	INR L
	MVI M,0
	JMP GETFACTOR_EXIT

GETFACTOR_GETVALUE:  ; input one line from serial and evaluate it
	MVI  D,lo(REG16_INDEX)
	MOV  A,D
	CALL PUSH_REG16A	; push REG(INDEX)
	MVI H,REGPAGE
	MOV L,D
	MVI M,lo(LINEBUF)
	INR L
	MVI M,up(LINEBUF) ; REG(INDEX) = LNEBUF
	CALL GETLINE_MEMREG16D	; get line input

	MVI E,lo(REG16_FACTOR)
	LXI_BC .RETURN
	JMP EVAL_EXPRESSION_MINDEX_REG16E ; eval it
.RETURN:
	MVI A,lo(REG16_INDEX)
	CALL POP_REG16A		; pop REG(INDEX)
	JMP GETFACTOR_EXIT

;;;----------------------------------------------------------------------------
;;; VTL_INSERT_PROGRAMLINE
;;; Input program line to program area
;;;----------------------------------------------------------------------------
VTL_INSERT_PROGRAMLINE:
	;; 	include "stacktest.inc"
	;; 	include "numbertest.inc"
	MVI D,lo(REG16_INDEX)  ; this can be omitted?
	MVI E,lo(REG16_TMP)
	CALL GETNUMBER_MEMREG16D_REG16E ; REG(TMP)=LINENUMBER
	MOV L,E
	CALL ISZERO_REG16L
	JZ   PRINT_LIST

	CALL INC_REG16D		; skip ' ' without check for symplification

	MVI  D,lo(REG16_PEND)
	CALL MOV_MEMREG16D_REG16E ; *REG(PEND)=REG(TMP)
	CALL INC_REG16D		  ; REG(PEND)+=2
	CALL INC_REG16D

	MOV  A,D
 	CALL PUSH_REG16A	; PUSH(REG(PEND)) to write a pointer
				; to the next line afterward
	CALL INC_REG16D		; make a space to write NEXTLINE_PTR
	CALL INC_REG16D		; PEND=PEND+2
	
INSERT_PROGRAM_LOOP:
	MVI  D,lo(REG16_INDEX)
	CALL MOV_A_MEMREG16D
	ANA  A			; EOL
	JZ   INSERT_PROGRAM_EXIT
	CALL INC_REG16D		; REG(INDEX)++
	MVI  D,lo(REG16_PEND)
	CALL MOV_MEMREG16D_A	; copy *REG(INDEX) to *REG(PEND)
	CALL INC_REG16D		; REG(PEND)++
	;; the end of memory check is omitted for simplicity
	JMP INSERT_PROGRAM_LOOP	;
	
INSERT_PROGRAM_EXIT:
	MVI D,lo(REG16_PEND)
	XRA A
	CALL MOV_MEMREG16D_A	; write EOL and increment REG(PEND)
	CALL INC_REG16D

	MVI D,lo(REG16_TMP)	
	MOV A,D			; pop the place to write the next line pointer
	CALL POP_REG16A		; (the top+2 of this line) to REG(TMP)
	
	MVI E,lo(REG16_PEND)
	CALL MOV_MEMREG16D_REG16E; BC=REG(PEND)

	JMP VTL_LOOP

;;;----------------------------------------------------------------------------
;;; PRINT_LIST:
;;; Print program list
;;;----------------------------------------------------------------------------
PRINT_LIST:
	MVI_REG16 REG16_INDEX,PROGRAM_START
	MOV D,L

.LOOP:
	MVI E,lo(REG16_PEND)
	CALL CMP_UNSIGNED_REG16D_REG16E
	JNC VTL_MAIN        ;REG(D) >= REG(PEND) then exit to VTL_MAIN

	;; Get line number
	MVI  E,lo(REG16_LINENUM)
	CALL MOV_REG16E_MEMREG16D
	CALL INC_REG16D
	CALL INC_REG16D

	CALL PRINT_REG16E
	PUTCHAR ' '
	
	CALL INC_REG16D 	; skip next line pointer
	CALL INC_REG16D

	CALL PRINTSTR_MEMREG16D
	CALL PRINT_CRLF
	CALL INC_REG16D		; increment pointer to the next char of EOL
	JMP .LOOP


;;;----------------------------------------------------------------------------
;;; PRINT_REG16E
;;; PRINT REG16(E) in decimal format
;;; destroy: HL
;;;----------------------------------------------------------------------------
PRINT_REG16E:
	CALL PUSH_BC
	CALL PUSH_DE
	MOV D,E
	JMP PRINT_REG16D_START
;;;----------------------------------------------------------------------------
;;; PRINT_REG16D
;;; PRINT REG16(D) in decimal format
;;; destroy: HL
;;;----------------------------------------------------------------------------
PRINT_REG16D:
	CALL PUSH_BC
	CALL PUSH_DE

PRINT_REG16D_START:
	MVI B,lo(REG16_TMP_PRINT)
	CALL MOV_REG16B_REG16D	; copy  REG16(D) to TMP_PRINT
	MOV D,B			; and D points to TMP_PRINT
	
	MVI A,lo(REG16_RMND)	; save last RMND before this PRINT
	CALL PUSH_REG16A

	LXI_HL REG8_ZEROSUP	;
	MVI M,1			; set zero supress flag
	
	CALL GETSIGN_REG16D     ; Print '-' if REG(P0) < 0
	JNC  PRINT_POSITIVE
	CALL COMPLEMENT2_REG16D	; REG(D)=-REG(D)
	PUTCHAR '-'

PRINT_POSITIVE:	
	;; 10000'
	MVI E,lo(REG16_CONST_10000)
 	CALL DIV_UNSIGNED_REG16D_REG16E	; REG(D)=REG(D)/REG(10000)
	CALL PRINT_REG4D_ZEROSUP
	MVI E,lo(REG16_RMND)
	CALL MOV_REG16D_REG16E	; REG(D) = REG(RMND)

	;; 1000'
	MVI E,lo(REG16_CONST_1000)
	CALL DIV_UNSIGNED_REG16D_REG16E	; REG(D)=REG(D)/REG(1000)
	CALL PRINT_REG4D_ZEROSUP
	MVI E,lo(REG16_RMND)
	CALL MOV_REG16D_REG16E	; REG(D) = REG(RMND)

	;; 100'
	MVI E,lo(REG16_CONST_100)
	CALL DIV_UNSIGNED_REG16D_REG16E	; REG(D)=REG(D)/REG(100)
	CALL PRINT_REG4D_ZEROSUP
	MVI E,lo(REG16_RMND)
	CALL MOV_REG16D_REG16E	; REG(D) = REG(RMND)

	;; 10'
	MVI E,lo(REG16_CONST_10)
	CALL DIV_UNSIGNED_REG16D_REG16E	; REG(D)=REG(D)/REG(10)
	CALL PRINT_REG4D_ZEROSUP
	MVI E,lo(REG16_RMND)
	CALL MOV_REG16D_REG16E	; REG(D) = REG(RMND)

	;; 1'
	MOV L,D
	MOV A,M
	CALL PRINT_4BIT_A
	
	MVI  A,lo(REG16_RMND)
	CALL POP_REG16A	                ; restore last RMND
	
	CALL POP_DE
	JMP  POP_BC

;;;----------------------------------------------------------------------------
;;; PRINT_REG4D_ZEROSUP:
;;; PRINT REG4(D) (= lower 4bit of REG(D))
;;; if REG4(P0) !=0 then print it and clear REG(ZEROSUP) flag
;;; else if REG4(ZEROSUP) == false then print REG4(D)
;;; skip otherwise
;;;----------------------------------------------------------------------------
PRINT_REG4D_ZEROSUP:
	MVI H,REGPAGE
	MOV L,D
	MOV A,M
	ANI 0FH
	JNZ CLEAR_AND_PRINT	; print if REG4(P0) != 0
	MVI L,lo(REG8_ZEROSUP)
	MOV A,M
	ANA A
	RNZ		        ; RETURN if ZERSUP=1
				; print A(=0) if ZERSUP=0
CLEAR_AND_PRINT:	
	LXI_HL REG8_ZEROSUP
	MVI M,0		        ; clear ZEROSUP
PRINT_4BIT_A:
	ADI 30H			;'0'
	JMP PUTCH

;;;----------------------------------------------------------------------------
;;; PRINTHEX_REG16D
;;; PRINT REG16(D)
;;; destroy: HL
;;;----------------------------------------------------------------------------
PRINTHEX_REG16D:
	MVI H,REGPAGE
	MOV L,D
	INR L
	MOV A,M
	CALL PRINTHEX_A
	MVI H,REGPAGE
	MOV L,D
	MOV A,M
	JMP PRINTHEX_A

;;;----------------------------------------------------------------------------
;;; PRINTHEX_REG16E
;;; PRINT REG16(E)
;;; destroy: HL
;;;----------------------------------------------------------------------------
PRINTHEX_REG16E:
	MVI H,REGPAGE
	MOV L,E
	INR L
	MOV A,M
	CALL PRINTHEX_A
	MVI H,REGPAGE
	MOV L,E
	MOV A,M
	JMP PRINTHEX_A

;;;----------------------------------------------------------------------------
;;; VTL_EXEC_PRINT
;;;----------------------------------------------------------------------------
VTL_EXEC_PRINT:
	CALL MOV_A_MEMREG16D	  ; check '='
	CPI '='
	JNZ VTL_EXEC_SYNTAX_ERROR

 	CALL INC_REG16D
	CALL MOV_A_MEMREG16D
	ANA  A
	JZ   VTL_PRINT_ERREXIT		; EOL

	CPI 22H 			; '"'
	JZ  VTL_PRINT_QUOTEDSTRING

	MVI E,lo(REG16_EVAL)
	LXI_BC .RETURN
	JMP EVAL_EXPRESSION_MINDEX_REG16E
.RETURN:
	CALL PRINT_REG16E
	JMP  VTL_EXECUTE_MINDEX_CONTINUE ; execute remaining string

VTL_PRINT_QUOTEDSTRING:
	CALL INC_REG16D		; INDEX++
	MVI A,22H		; "
	CALL PRINTSTR_MEMREG16D_DELIM_A

	CALL MOV_A_MEMREG16D
	CPI ';'
	JZ  .SKIPCRLF	; skip CRLF and increment INDEX
	CALL PRINT_CRLF
	JMP VTL_EXECUTE_MINDEX_CONTINUE ; execute remaining string
.SKIPCRLF:	
	CALL INC_REG16D			; increment for ';'
	JMP VTL_EXECUTE_MINDEX_CONTINUE ; execute remaining string

VTL_PRINT_ERREXIT:
	MVI_REG16 REG16_ERROR,STR_VTL_ERROR_PRINT
	JMP VTL_MAIN			 ; error and jump to start
	
;;;----------------------------------------------------------------------------
;;; VTL_EXEC_PRINT_HEX2
;;; VTL_EXEC_PRINT_HEX4
;;;----------------------------------------------------------------------------
VTL_EXEC_PRINT_HEX2:
	CALL INC_REG16D
	CALL MOV_A_MEMREG16D
	CPI '='
	JNZ VTL_EXEC_SYNTAX_ERROR
	CALL INC_REG16D
	MVI E,lo(REG16_EVAL)
	LXI_BC .RETURN
	JMP EVAL_EXPRESSION_MINDEX_REG16E
.RETURN:
	LXI_HL REG16_EVAL
	MOV A,M
	CALL PRINTHEX_A
	JMP VTL_EXECUTE_MINDEX_CONTINUE ; execute remaining string

VTL_EXEC_PRINT_HEX4:
	CALL INC_REG16D
	CALL MOV_A_MEMREG16D
	CPI '='
	JNZ VTL_EXEC_SYNTAX_ERROR
	CALL INC_REG16D
	MVI E,lo(REG16_EVAL)
	LXI_BC .RETURN
	JMP EVAL_EXPRESSION_MINDEX_REG16E
.RETURN:
	CALL PRINTHEX_REG16E
	JMP VTL_EXECUTE_MINDEX_CONTINUE ; execute remaining string

;;;----------------------------------------------------------------------------
;;; PRINTSTR_MEMREG16D_DELIM_A(Delimiter is A and 00H)
;;; PRINTSTR_MEMREG16D        (Delimiter is 0x00)
;;; Print a string 
;;; put a string on REG16(D)[] to serial output until the A or 00H
;;; REG(D) is incremented to
;;; 	the end of the string    (if the delimiter == 00H)
;;; 	the end of the string +1 (if the delimiter != 00H)
;;; 
;;; maximum string length = 256 (to avoid endless loop)
;;; 
;;; destroy: A, HL
;;;----------------------------------------------------------------------------
PRINTSTR_MEMREG16D:
	MVI A, 00H
PRINTSTR_MEMREG16D_DELIM_A:
	CALL PUSH_BC
	CALL PUSH_DE

	MOV E,A		; save the delimiter A to E
	CALL MOV_BC_REG16D
	MOV H,B
	MOV L,C
	MVI C,00H       ; count 256
.LOOP:
	MOV A,M
	ANA A
	JZ .BREAK
	CMP E
	JZ .BREAK
	INR C
	JZ .EXIT		; to avoid endless loop
	CALL PUTCH
	INR L
	JNZ .LOOP
	INR H			; INC HL
	JMP .LOOP
.BREAK:
	MOV A,E			; INC HL if defimiter is not 00H
	ANA A
	JZ  .EXIT
	INR L
	JNZ .EXIT
	INR H
.EXIT:
	MOV B,H
	MOV C,L
	CALL POP_DE
	CALL MOV_REG16D_BC 	; set incremented pointer to REG(D)
	JMP  POP_BC
