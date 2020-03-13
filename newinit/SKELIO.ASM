       TITLE   IO.SYS for the ALTOS ACS-86C.

; I/O system for Version 2.x of MSDOS.

;This BIOS designed to be linked with the SYSINIT module provided by
;Microsoft

BIOSIZ  EQU     4096            ;Size of BIOS in bytes.
BIOSIZS EQU     100H            ;Size of BIOS in Paragraphs.
ANSI    EQU     0               ;Ansi switch.

;Additional Information for the ALTOS machine.

QSIZE   EQU     100             ;Input queue size.
BIOSSEG EQU     0200H           ;I/O system segment.
MAX_MEM EQU     4000H           ;Memory size in paragraphs.

; Constants for commands in Altos ROM.

ROM_CONSTA      EQU     01      ;Return status AL of console selected in CX.
ROM_CONIN       EQU     02      ;Get char. from console in CX to AL
ROM_CONOUT      EQU     03      ;Write char. in DL to console in CX.
ROM_PMSG        EQU     07      ;Write string ES:DX to console in CX.
ROM_DISKIO      EQU     08      ;Perform disk I/O from IOPB in ES:CX.
ROM_INIT        EQU     10      ;Returns boot console and top memory ES:DX.

;Things needed to communicate with SYSINIT

EXTRN   SYSINIT:FAR                   ;The entry point of SYSINIT
EXTRN   CURRENT_DOS_LOCATION:WORD     ;Where the DOS is when SYSINIT called
EXTRN   FINAL_DOS_LOCATION:WORD       ;Where I want SYSINIT to put the DOS
EXTRN   DEVICE_LIST:DWORD             ;Pointer to the DEVICE list.
EXTRN   MEMORY_SIZE:WORD              ;Size in paragraphs of Physical memory.
EXTRN   DEFAULT_DRIVE:BYTE            ;Default Drive to use when system booted
EXTRN   BUFFERS:BYTE                  ;Number of default buffers.
				      ; Leave as is and SYSINIT uses only 2.

CODE    SEGMENT
ASSUME  CS:CODE,DS:CODE,ES:CODE,SS:CODE

	ORG     0               ;Starts at an offset of zero.

INIT:   JMP     HWINIT

RINITP  PROC    FAR

RE_INIT:
	RET

RINITP  ENDP

HWINIT: PUSH    CS
	POP     ES

	MOV     AX,SEG SYSINIT
	MOV     DS,AX

ASSUME  DS:SEG SYSINIT

	MOV     DS:[CURRENT_DOS_LOCATION],AX
	MOV     DS:[FINAL_DOS_LOCATION],BX
	MOV     DS:[MEMORY_SIZE],CX
	MOV     WORD PTR DS:[DEVICE_LIST+2],DX
	MOV     WORD PTR DS:[DEVICE_LIST],SI
	JMP     SYSINIT

DOSSPOT LABEL   WORD

CODE    ENDS

	END
