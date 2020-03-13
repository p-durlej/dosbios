; Copyright (c) Piotr Durlej
; All rights reserved.
;
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met:
;
; 1. Redistributions of source code must retain the above copyright notice,
; this list of conditions and the following disclaimer.
;
; 2. Redistributions in binary form must reproduce the above copyright
; notice, this list of conditions and the following disclaimer in the
; documentation and/or other materials provided with the distribution.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
; POSSIBILITY OF SUCH DAMAGE.
;

	%include "bios/config.asm"

	jmp	init

	%include "bios/rawcon.asm"
	%include "bios/stack.asm"
	%include "bios/devsw.asm"

	%include "bios/console.asm"
	%include "bios/aux.asm"
	%include "bios/prn.asm"
	%include "bios/clock.asm"
	%include "bios/floppy.asm"
	%include "bios/fxdisk.asm"

; ---- DOS Patch -------------------------------------------------------------

newsc:	cmp	ah, 0x47
	je	getcwd
	cmp	ah, 0xff
	je	oemfunc
	jmp far [cs:oldvec]

getcwd:	pushf
	call far [cs:oldvec]
	jc	.fini
	push	ax
	push	si
	xor	al, al
	cld
.loop:	mov	ah, al
	lodsb
	cmp	al, 'a'
	jb	.skip
	cmp	al, 'z'
	ja	.skip
	sub	byte [si - 1], 32
.skip:	test	al, al
	jnz	.loop
.nodot:	pop	si
	pop	ax
.fini:	iret

oemfunc:mov	al, 0x20
	iret

oldvec:	dw	0, 0

reinit:	push	ax
	push	dx
	push	ds
	push	cs
	pop	ds
	mov	ax, 0x3521
	int	0x21
	mov	[cs:oldvec    ], bx
	mov	[cs:oldvec + 2], es
	mov	ax, 0x2521
	mov	dx, newsc
	int	0x21
	pop	ds
	pop	dx
	pop	ax
	retf

; ---- Initialization --------------------------------------------------------

endresid:

init:	xor	ax, ax
	mov	ss, ax
	mov	sp, BIOSSEG << 4
	mov	ax, INITSEG
	mov	es, ax
	push	cs
	pop	ds
	mov	si, endinit - 2
	mov	di, endinit - dosinit - 2
	mov	cx, (endinit - dosinit) / 2
	std
	rep movsw
	test	dl, 0x80
	jz	.floppy
	mov	word [drive], 0x3
.floppy:xor	ax, ax
	mov	ss, ax
	mov	sp, STKTOP
	mov	si, banner
	call	strout
	xor	ax, ax
	mov	ds, ax
	mov	word [0x29 * 4    ], con_fastout
	mov	word [0x29 * 4 + 2], cs
	mov	ax, INITSEG
	mov	ds, ax
	mov	byte [0x03], 0xea
	mov	word [0x04], reinit
	mov	word [0x06], cs
	push	word [cs:drive]
	push	cs
	mov	ax, d_con
	push	ax
	int	0x12
	cmp	ax, MINMEM
	jb	nomem
	mov	cl, 6
	shl	ax, cl
	push	ax
	mov	ax, 0x181 ;DOSSEG ; XXX TODO: move to INITSEG
	push	ax
	mov	ax, DOSSEG
	push	ax
	jmp	INITSEG:0

nomem:	mov	si, lowmem
	call	strout
.loop:	hlt
	jmp	.loop

drive:	dw	0

; ---- Strings ---------------------------------------------------------------

banner	db	13, 10, "DOSBIOS Copyright (C) Piotr Durlej", 13, 10
	db		"SYSINIT Copyright (C) Microsoft Corp.", 13, 10, "$"

lowmem	db	13, 10, "48K of RAM or more is required", 13, 10, "$"

; ---- DOS Init --------------------------------------------------------------

dosinit	incbin	"newinit/NEWINIT.BIN"
endinit:
