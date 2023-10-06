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

	mov	ax, 0x0201
	mov	cx, 0x0001
	mov	dx, 0x0080
	mov	bx, buf
	int	0x13
	jc	fail

main:	call	banner
	mov	dx, moptions
	mov	ah, SSTROUT
	int	DOSINT
	call	getkey
	cmp	al, 'Q'
	je	exit
	cmp	al, 'q'
	je	exit
	cmp	al, 27
	je	exit
	cmp	al, '1'
	je	create
	cmp	al, '2'
	je	change
	cmp	al, '3'
	je	delete
	cmp	al, '4'
	je	show
	call	beep
	jmp	main

exit:
	mov	ax, 0x0301
	mov	cx, 0x0001
	mov	dx, 0x0080
	mov	bx, buf
	int	0x13
	mov	dx, mexit
	mov	ah, SSTROUT
	int	DOSINT
	test	[reboot], byte 0xff
	jnz	.reboot
	int	XITINT
.reboot:mov	dx, mreboot
	mov	ah, SSTROUT
	int	DOSINT
	call	anykey
	int	0x19

banner:
	mov	dx, mbanner
	mov	ah, SSTROUT
	int	DOSINT
	ret

gettype:
	cmp	[si + 4], byte 1
	je	.dos
	cmp	[si + 4], byte 192
	je	.xenus
	mov	dx, mtother
	ret
.dos:	mov	dx, mtdos
	ret
.xenus:	mov	dx, mtxenus
	ret

prnum:	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	
	mov	di, .buf + 3
	mov	cx, 4
	std
	
.loop:	xor	dx, dx
	mov	bx, 10
	div	bx
	push	ax
	mov	ax, '0'
	add	ax, dx
	stosb
	pop	ax
	loop	.loop
	cld
	
	mov	si, .buf
	mov	cx, 3
.nzero:	cmp	[si], byte '0'
	jne	.print
	mov	[si], byte ' '
	inc	si
	loop	.nzero
	
.print:	mov	dx, .buf
	mov	ah, SSTROUT
	int	DOSINT
	
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
.buf:	db	"xxxx$"

prpart1:push	bx
	
	test	[si + 4], byte 0xff
	jz	.fini
	
	mov	cx, 4
	call	space
	mov	dl, bl
	mov	ah, SCHROUT
	int	DOSINT
	mov	cx, 9
	call	space
	
	test	[si], byte 0x80
	jz	.notact
	mov	dl, 'A'
	jmp	.pstat
.notact:mov	dl, ' '
.pstat:	mov	ah, SCHROUT
	int	DOSINT
	
	mov	cx, 3
	call	space
	
	call	gettype
	mov	ah, SSTROUT
	int	DOSINT
	
	mov	cx, 2
	call	space
	
	mov	al, [si + 3]
	mov	ah, [si + 2]
	rol	ah, 1
	rol	ah, 1
	and	ah, 3
	push	ax
	call	prnum
	
	mov	cx, 1
	call	space
	
	mov	ax, [si + 7]
	mov	ah, [si + 6]
	rol	ah, 1
	rol	ah, 1
	and	ah, 3
	push	ax
	call	prnum
	
	mov	cx, 1
	call	space
	
	pop	ax
	pop	bx
	sub	ax, bx
	inc	ax
	call	prnum
	
	call	crlf
	
.fini:	pop	bx
	ret

prpart:	mov	dx, mheader
	mov	ah, SSTROUT
	int	DOSINT
	mov	si, buf + 0x1be
	mov	bl, '1'
	call	prpart1
	mov	si, buf + 0x1ce
	inc	bl
	call	prpart1
	mov	si, buf + 0x1de
	inc	bl
	call	prpart1
	mov	si, buf + 0x1ee
	inc	bl
	call	prpart1
	call	crlf
	ret

getdp:	mov	ah, 0x08
	mov	dl, 0x80
	int	0x13
	jc	fail
	ret

create:	call	banner
	call	prpart
	mov	si, buf + 0x1be
	mov	cx, 4
.loop:	mov	al, [si + 4]
	test	al, al
	jz	.skip
	jmp	fndpart
.skip:	add	si, 0x10
	loop	.loop

	mov	si, mboot
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
	
	call	banner
	call	prpart
	mov	[reboot], byte 1
	mov	dx, mdone
	mov	ah, SSTROUT
	int	DOSINT
	call	anykey
	jmp	main
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

fndpart:mov	dx, mexist
	mov	ah, 0x09
	int	0x21
	call	waitkey
	jmp	main

fail:	mov	dx, .msg
	mov	ah, 0x09
	int	0x21
	int	0x20
.msg:	db	"I/O Error", 13, 10, "$"

getkey:
	mov	ah, SCHRINN
	int	DOSINT
	cmp	al, 27
	je	.fini
	cmp	al, 32
	jb	.bad
	cmp	al, 127
	ja	.bad
.fini:	ret
.bad:	call	beep
	jmp	getkey

waitkey:
	mov	ah, SCHRINN
	int	DOSINT
	ret

anykey:
	mov	dx, manykey
	mov	ah, SSTROUT
	int	DOSINT
	jmp	waitkey

space:
	mov	ah, SCHROUT
	mov	dl, ' '
.loop:	int	DOSINT
	loop	.loop
	ret

crlf:
	mov	dx, mcrlf
	mov	ah, 0x09
	int	0x21
	ret

beep:
	mov	dl, 7
	mov	ah, SCHROUT
	int	DOSINT
	ret

getpartn:
	call	getkey
	cmp	al, 'Q'
	je	.cancel
	cmp	al, 'q'
	je	.cancel
	cmp	al, 27
	je	.cancel
	cmp	al, '1'
	jb	.bad
	cmp	al, '4'
	ja	.bad
	sub	al, '1'
	xor	ah, ah
	mov	bx, ax
	shl	bx, 1
	shl	bx, 1
	shl	bx, 1
	shl	bx, 1
	test	[bx + part + 4], byte 0xff
	jz	.bad
	clc
	ret
.cancel:stc
	ret
.bad:	mov	dx, mbadpar
	mov	ah, SSTROUT
	int	DOSINT
	call	anykey
	stc
	ret

wantpart:
	mov	si, part
	mov	cx, 4
.loop:	test	[si + 4], byte 0xff
	jnz	.found
	add	si, 16
	loop	.loop
	mov	dx, mnopart
	mov	ah, SSTROUT
	int	DOSINT
	call	anykey
	stc
	ret
.found:	clc
	ret

change:	call	banner
	call	prpart
	call	wantpart
	jc	main
	mov	dx, mactpar
	mov	ah, SSTROUT
	int	DOSINT
	call	getpartn
	jc	main
	
	mov	di, part
	mov	cx, 4
.clear:	mov	[di], byte 0
	add	di, 16
	loop	.clear
	
	mov	bx, ax
	shl	bx, 1
	shl	bx, 1
	shl	bx, 1
	shl	bx, 1
	mov	[bx + part], byte 0x80
	
	call	banner
	call	prpart
	call	anykey
	jmp	main

delete:	call	banner
	call	prpart
	call	wantpart
	jc	main
	mov	dx, mdelpar
	mov	ah, SSTROUT
	int	DOSINT
	call	getpartn
	jc	main
	
	mov	di, ax
	shl	di, 1
	shl	di, 1
	shl	di, 1
	shl	di, 1
	add	di, part
	mov	cx, 8
	xor	ax, ax
	rep stosw
	
	mov	[reboot], byte 1
	call	banner
	call	prpart
	call	anykey
	jmp	main

show:
	call	banner
	call	prpart
	call	anykey
	jmp	main

mbanner:db	27, "[2J"
	db	"Fixed Disk Setup Program Version 1.01", 13, 10
	db	"(C) Piotr Durlej", 13, 10, 10, "$"
moptions:
	db	"Options:", 13, 10, 10
	db	" 1. Create DOS partition", 13, 10
	db	" 2. Change active partition", 13, 10
	db	" 3. Delete partition", 13, 10
	db	" 4. Display partition information", 13, 10, 10
	db	"Enter choice: $"
mexist:	db	"Partitions already exist", 13, 10, "$"
mheader:db	"Partition  Status Type  Start  End Size", 13, 10, "$"
mdone:	db	"MBR initialization successful", 13, 10, "$"
mnopart:db	"No partitions defined", 13, 10, "$"
manykey:db	"Press any key to continue", 13, 10, "$"
mactpar:db	"New active partition: $"
mdelpar:db	"Delete partition: $"
mbadpar:db	13, 10, 10, "Invalid partition specification", 13, 10, "$"
mreboot:db	"The system will now reboot", 13, 10, "$"
mexit:	db	27, "[2J$"
mtdos:	db	"DOS  $"
mtxenus:db	"XENUS$"
mtother:db	"Other$"
mcrlf:	db	13, 10, "$"

reboot:	db	0

ncyl:	dw	0
head:	dw	0
sect:	dw	0

mboot	incbin	"boot/mboot.bin"
mbootend:

	section	.bss
sbss:
buf:	resb	512
ebss:
