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
	
	org	0x7c00
base:
	jmp	start
	nop

	db	"PETYADOS"	; OEM
	dw	0x0200		; bytes per sector
clstsz:	db	0x01		; sectors per cluster
rsvds:	dw	0x01		; reserved sectors
nfats:	db	0x02		; number of FATs
ndire:	dw	0x00e0		; number of dir entries
	dw	0x0b40		; number of sectors
	db	0xf0		; media descriptor
fatsz:	dw	0x0009		; sectors per FAT
nsect:	dw	0x0012		; sectors per head
nhead:	dw	0x0002		; heads per cylinder
	dd	0x000000000	; hidden sectors
	dd	0x000000000	; large total logical sectors
	db	0x00		; physical drive number
	db	0x00		; flags
	db	0x00		; extended boot signature
	dd	0x12345678	; volume serial number
	db	"DOS        "	; volume label
	times	8 db 0		; filesystem type

start:	mov	bx, [si + 8]
	cli ; Don't rely on the interrupt shadow (some CPUs are buggy)
	xor	ax, ax
	mov	ss, ax
	mov	sp, STKTOP
	xor	ax, ax
	mov	ds, ax
	mov	es, ax
	cld
	sti
	
	mov	[drive], dl
	test	dl, 0x80
	jz	.floppy
	mov	[poff], bx
.floppy:
	
	; load IO.SYS and MSDOS.SYS
	
	mov	word [cseg], 0x70
	mov	word [cname], ionam
	call	loadfile
	
	mov	word [cseg], 0x280
	mov	word [cname], dosnam
	call	loadfile
	
	; transfer control to IO.SYS
	
	mov	dl, [drive]
	mov	ax, 0x70
	mov	ds, ax
	mov	es, ax
	jmp	0x70:0

loadfile:
	mov	ax, [fatsz]
	mov	bl, [nfats]
	xor	bh, bh
	mul	bx
	add	ax, [rsvds]
	mov	bx, [ndire]
	add	bx, 15
	mov	cl, 4
	shr	bx, cl
	mov	[resid], bx
	push	ax
	call	seek
.nextdt:push	word [cseg] ; XXX
	mov	word [cseg], DIRBUF >> 4
	call	read
	pop	word [cseg] ; XXX
	
	; find the directory entry
	
	mov	di, DIRBUF
.next:	mov	si, [cname]
	mov	cx, 11
	rep cmpsb
	je	.found
	and	di, 0xffe0
	add	di, 32
	cmp	di, DIRBUF + 512
	jne	.next
	dec	word [resid]
	cmp	word [resid], 0
	jne	.nextdt
	jmp	fail
	
	; calculate the first sector CHS address of the file
	
.found:	mov	ax, [di + 0x1a - 11] ; first cluster
	sub	ax, 2
	mov	bl, [clstsz]
	xor	bh, bh
	mul	bx
	pop	bx
	add	ax, bx
	mov	bx, [ndire]
	add	bx, 15
	mov	cl, 4
	shr	bx, cl
	add	ax, bx
	call	seek
	
	; calculate the number of sectors to load
	
	mov	cx, [di + 0x1c - 11] ; file size
	add	cx, 511
	mov	cl, ch
	shr	cl, 1
	xor	ch, ch
	mov	word [resid], cx
	
	; load the file
	
.load:	call	read
	add	word [cseg], 0x20
	dec	word [resid]
	cmp	word [resid], 0
	jne	.load

seek:	add	ax, [poff]
	xor	dx, dx
	mov	bx, word [nsect]
	div	bx
	inc	dx
	mov	byte [csect], dl
	xor	dx, dx
	mov	bx, word [nhead]
	div	bx
	mov	byte [chead], dl
	mov	[ccyl], ax
	ret

read:	push	es
	mov	ax, word [cseg]
	mov	es, ax
	mov	ax, 0x0201
	mov	ch, byte [ccyl]
	mov	cl, byte [ccyl + 1]
	ror	cl, 1
	ror	cl, 1
	or	cl, byte [csect]
	mov	dh, byte [chead]
	mov	dl, byte [drive]
	xor	bx, bx
	int	0x13
	jc	fail
	pop	es
	inc	byte [csect]
	mov	cl, [nsect]
	cmp	[csect], cl
	jbe	.fini
	mov	byte [csect], 1
	inc	byte [chead]
	mov	cl, [nhead]
	cmp	[chead], cl
	jb	.fini
	mov	byte [chead], 0
	inc	byte [ccyl]
.fini:	ret

fail:	mov	dx, 0x0007
	mov	ah, 0x0e
	mov	si, .msg
.loop:	lodsb
	jz	.halt
	int	0x10
	loop	.loop
.halt:	xor	ah, ah
	int	0x16
	int	0x19
.msg	db	13, 10, "Not a system disk or disk error", 13, 10, 0

dosnam	db	"MSDOS   SYS"
ionam	db	"IO      SYS"

ccyl	dw	0
chead	db	0
csect	db	0
cseg	dw	0xb800
cname	dw	0
drive	db	0
resid	dw	0
poff	dw	0

	times	0x01fe - ($ - $$) db 0
	dw	0xaa55
