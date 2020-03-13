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

	%include "bios/config.asm"
	%include "util/yldos.inc"
	%include "util/ylbss.inc"

MAXSECT	equ	0xa000

mbootsz	equ	(mbootend - mboot)
part	equ	buf + 0x1be

	mov	dx, mintro
	mov	ah, 0x09
	int	0x21
	mov	ah, 0x01
	int	0x21
	mov	bl, al
	mov	dx, crlf
	mov	ah, 0x09
	int	0x21
	cmp	bl, 'y'
	je	start
	cmp	bl, 'Y'
	je	start
	int	0x20

start:	mov	ax, 0x0201
	mov	cx, 0x0001
	mov	dx, 0x0080
	mov	bx, buf
	int	0x13
	jc	.fail

	mov	si, buf + 0x1be
	mov	cx, 4
.loop:	mov	al, [si + 4]
	test	al, al
	jz	.skip
	jmp	fndpart
.skip:	add	si, 0x10
	loop	.loop
	jmp	fxinit
.fail:	jmp	fail

getdp:	mov	ah, 0x08
	mov	dl, 0x80
	int	0x13
	jc	.fail
	ret
.fail:	jmp	fail

fxinit:	mov	si, mboot
	mov	di, buf
	mov	cx, mbootsz
	cld
	rep movsb
	
	mov	cx, 510 - mbootsz
	xor	al, al
	rep stosb
	mov	ax, 0xaa55
	stosw
	
	call	getdp
	
	mov	word [part    ], 0x0180
	mov	word [part + 2], 0x0001
	mov	word [part + 4], 1
	mov	byte [part + 5], dh
	mov	word [part + 6], cx
	
	inc	dh
	
	mov	al, cl
	xor	ah, ah
	shl	ax, 1
	shl	ax, 1
	mov	al, ch
	inc	ax
	
	and	cx, 0x3f
	
	mov	dl, dh
	xor	dh, dh
	
	mov	[ncyl], ax
	mov	[head], dx
	mov	[sect], cx
	
	mul	dx
	jc	.oflow
	mul	cx
	jc	.oflow
	sub	ax, cx
	cmp	ax, 0xa000
	jae	.oflow
	
.gotsz:	mov	word [part + 0x08], cx
	mov	word [part + 0x0c], ax
	
	mov	ax, 0x0301
	mov	cx, 0x0001
	mov	dx, 0x0080
	mov	bx, buf
	int	0x13
	jc	.fail
	
	mov	dx, mdone
	mov	ah, 0x09
	int	0x21
	mov	ah, 0x07
	int	0x21
	mov	dx, crlf
	mov	ah, 0x09
	int	0x21
	int	0x19
.oflow:	push	cx
	mov	ax, MAXSECT - 1
	xor	dx, dx
	div	word [sect]
	xor	dx, dx
	div	word [head]
	mov	cl, 6
	shl	ah, cl
	mov	[part + 7], al
	and	[part + 6], byte 0x3f
	or	[part + 6], ah
	mov	ax, MAXSECT
	pop	cx
	jmp	.gotsz
.fail:	jmp	fail

fndpart:mov	dx, mconf
	mov	ah, 0x09
	int	0x21
	mov	ah, 0x01
	int	0x21
	mov	bl, al
	mov	dx, crlf
	mov	ah, 0x09
	int	0x21
	cmp	bl, 'y'
	je	.init
	cmp	bl, 'Y'
	je	.init
	int	0x20
.init:	jmp	fxinit

fail:	mov	dx, .msg
	mov	ah, 0x09
	int	0x21
	int	0x20
.msg:	db	"I/O Error", 13, 10, "$"

mintro:	db	13, 10
	db	"This is a MBR initialization program!", 13, 10
	db	"Continue (Y/N)? $"
mconf:	db	13, 10
	db	"All partitions will be removed!", 13, 10
	db	"Continue (Y/N)? $"
mdone:	db	13, 10
	db	"MBR initialization successful", 13, 10
	db	"Press any key to reboot", 13, 10, "$"
crlf:	db	13, 10, "$"

ncyl:	dw	0
head:	dw	0
sect:	dw	0

mboot	incbin	"boot/mboot.bin"
mbootend:

	section	.bss
sbss:
buf:	resb	512
ebss:
