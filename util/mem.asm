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

	org	0x100

	mov	dx, header
	mov	ah, 0x09
	int	0x21
	
	mov	ah, 0x52
	int	0x21
	
	mov	bx, [es:bx - 2]
	mov	ds, bx
	
next:	mov	ax, ds
	inc	ax
	call	phex
	mov	al, 32
	call	chrout
	
	mov	ax, [0x01]
	test	ax, ax
	jnz	powner
	
	mov	dx, mfree
	mov	ah, 0x09
	int	0x21
	jmp	psize
	
powner:	call	phex
	mov	al, 32
	call	chrout
	
psize:	mov	ax, [0x03]
	call	phex
	
	mov	al, 13
	call	chrout
	mov	al, 10
	call	chrout
	
	cmp	byte [0x00], 'Z'
	jz	fini
	
	add	bx, [0x03]
	inc	bx
	mov	ds, bx
	jmp	next
fini:	int	0x20

chrout:	push	ax
	push	dx
	mov	ah, 0x02
	mov	dl, al
	int	0x21
	pop	dx
	pop	ax
	ret

header:	db	13, 10
	db	"MCB chain dump", 13, 10, 10
	db	"BASE OWNR SIZE ", 13, 10
	db	"---- ---- ---- ", 13, 10, "$"

mfree:	db	"     $"

	%include "bios/prhex.asm"
