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

ORG 0x600

boot:	cli ; Don't rely on the interrupt shadow (some CPUs are buggy)
	xor	ax, ax
	mov	ss, ax
	mov	sp, 0x7C00	; Move top of stack below boot area in case of 1kb sectors
	sti
	cld
	mov	ds, ax		; Move MBR to 0x600 region reserved for it.
	mov	es, ax
	mov	si, sp		; Move SI = load address (currently in SP already)
	mov	di, 0x600
	mov	cx, 0x100
	rep movsw
	jmp	0x0000:start

start:	mov	si, 0x7be
.loop:	test	byte [si], 0x80
	jnz	.found
	add	si, 0x10
	cmp	si, 0x1fe
	jne	.loop
	int	0x18		; Try next boot choice, if any
	mov	si, mnoact
	call	puts
.halt:	hlt
	jmp	short .halt

.found:	test	dl, 0x80	; If we were booted from HD 2-4, dl will tell us
	jz	.nodar
	cmp	dl, 0x90	; Range cutoff in case of buggy BIOS
	ja	.nodar
	mov	[si], dl	; Boot protocol: ds:si points to the correct
				; MBR slot from which to load the OS
				; DOS doesnt care but other stuff does.
.nodar:	mov	bx, 0x7c00
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
	jmp	start.halt		; In case 0x180 returns

mrfail:	db	"Error loading operating system", 13, 10, 0
mnoact:	db	"Missing operating system", 13, 10, 0
