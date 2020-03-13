; I/O system for Version 2.x of MSDOS.

;This BIOS designed to be linked with the SYSINIT module provided by
;Microsoft

;Things needed to communicate with SYSINIT

EXTRN   SYSINIT:FAR                   ;The entry point of SYSINIT
EXTRN   CURRENT_DOS_LOCATION:WORD     ;Where the DOS is when SYSINIT called
EXTRN   FINAL_DOS_LOCATION:WORD       ;Where I want SYSINIT to put the DOS
EXTRN   DEVICE_LIST:DWORD             ;Pointer to the DEVICE list.
EXTRN   MEMORY_SIZE:WORD              ;Size in paragraphs of Physical memory.
EXTRN   DEFAULT_DRIVE:BYTE            ;Default Drive to use when system booted
EXTRN   BUFFERS:BYTE                  ;Number of default buffers.
				      ; Leave as is and SYSINIT uses only 2.

PUBLIC  RE_INIT

CODE    SEGMENT
ASSUME  CS:CODE,DS:CODE,ES:CODE,SS:CODE

	ORG     0               ;Starts at an offset of zero.

INIT:   JMP     HWINIT

RINITP  PROC    FAR

RE_INIT:
	RET
	NOP
	NOP
	NOP
	NOP

RINITP  ENDP

HWINIT: PUSH    CS
	POP     ES

	MOV     DI,SEG SYSINIT
	MOV     DS,DI

ASSUME  DS:SEG SYSINIT

	POP     DS:[CURRENT_DOS_LOCATION]
	POP     DS:[FINAL_DOS_LOCATION]
	POP     DS:[MEMORY_SIZE]
	POP     WORD PTR DS:[DEVICE_LIST    ]
	POP     WORD PTR DS:[DEVICE_LIST + 2]
	POP     AX
	MOV     BYTE PTR DS:[DEFAULT_DRIVE], AL
	JMP     SYSINIT

DOSSPOT LABEL   WORD

CODE    ENDS

	END
