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

	jmp	0x07c0:start

start:	cli ; Don't rely on the interrupt shadow (some CPUs are buggy)
	xor	ax, ax
	mov	ss, ax
	mov	sp, STKTOP
	sti
	push	cs
	pop	ds
	cld
	
	mov	ax, 0x50
	mov	es, ax
	xor	si, si
	xor	di, di
	mov	cx, 0x100
	rep movsw
	mov	ds, ax
	jmp	0x50:.moved

.moved:	mov	si, 0x1be
.loop:	test	byte [si], 0x80
	jnz	.found
	add	si, 0x10
	cmp	si, 0x1fe
	jne	.loop
	mov	si, mnoact
	call	puts
	jmp	$

.found:	mov	bx, 0x07c0
	mov	es, bx
	xor	bx, bx
	mov	ax, 0x0201
	mov	dx, [si    ]
	mov	cx, [si + 2]
	int	0x13
	jc	fail
	
	jmp	0x0000:0x7c00

puts:	mov	dx, 0x0007
	mov	ah, 0x0e
.loop:	lodsb
	test	al, al
	jz	.fini
	int	0x10
	jmp	.loop
.fini:	ret

fail:	mov	si, mrfail
	call	puts
	int	0x18

mrfail:	db	"Error loading operating system", 13, 10, 0
mnoact:	db	"Missing operating system", 13, 10, 0
