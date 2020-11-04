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

	; NUL-terminate the command line tail
	
	mov	bl, [0x80]
	xor	bh, bh
	add	bx, 0x81
	xor	al, al
	mov	[bx], al
	
	; set the DTA address
	
	mov	ah, 0x1a
	mov	dx, dta
	int	0x21
	
	; default to *.*
	
	cmp	[0x80], byte 2
	jge	.havnam
	mov	[nammask], word allfil
.havnam:
	
	; find the first file
	
	mov	ax, 0x4e00
	mov	dx, [nammask]
	mov	cx, 0x27
	int	0x21
	jc	nofile
	
	; print the file information
	
gotfile:call	prfile
	
	mov	ah, 0x4f
	int	0x21
	jnc	gotfile
	int	0x20

	; no files found
	
nofile:	mov	ah, 0x09
	mov	dx, mnofil
	int	0x21
	int	0x20

prfile:	mov	dl, [dta + 0x15]
	mov	si, mattr
	mov	cx, 8
	mov	[curattr], dl
	cld
.atrlop:lodsb
	mov	dl, [curattr]
	shr	dl, 1
	mov	[curattr], dl
	
	jnc	.clear
	mov	dl, al
	mov	ah, 0x02
	int	0x21
	loop	.atrlop
	jmp	.skip
.clear:	call	space
	loop	.atrlop
.skip:	mov	ah, 0x02
	mov	dl, ' '
	int	0x21
	mov	si, dta + 0x1e
.loop:	lodsb
	test	al, al
	jz	.end
	mov	dl, al
	mov	ah, 0x02
	int	0x21
	jmp	.loop
.end:	jmp	crlf

crlf:	mov	dx, mcrlf
	mov	ah, 0x09
	int	0x21
	ret

space:	mov	ah, 0x02
	mov	dl, ' '
	int	0x21
	ret

nammask:dw	0x82
allfil:	db	"*.*", 0

mnofil:	db	"Invalid path or file not found", 13, 10, "$"
mcrlf:	db	13, 10, "$"
mattr:	db	"RHSLDA67"

dta:	resb	128
curattr:db	0
