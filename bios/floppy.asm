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

d_floppy:
	dw	d_fxdisk, BIOSSEG
	dw	0x2000
	dw	strategy
	dw	floppy_io
flpcnt:	db	2
	db	0, 0, 0, 0, 0, 0, 0

; ---- Floppy ----------------------------------------------------------------

floppy_io:
	push	si
	mov	si, floppy_switch
	jmp	d_switch

floppy_init:
	mov	byte [es:bx + 13], 2		; number of units
	mov	word [es:bx + 14], endresid
	mov	word [es:bx + 16], cs
	mov	word [es:bx + 18], floppy_bpba	; BPB list offset
	mov	word [es:bx + 20], cs		; BPB list segment
	mov	word [es:bx +  3], 0x0100	; DONE
	ret

floppy_mcheck:
	mov	byte [es:bx + 14], 0		; Not sure if media changed
;	mov	byte [es:bx + 14], 1		; Media has been changed
	mov	word [es:bx +  3], 0x0100	; DONE
	ret

floppy_lgeom:
	mov	word [cs:nhead], 2
	mov	word [cs:nsect], 18
	ret

floppy_bbpb:
	mov	word [es:bx +  3], 0x0100	; DONE
	mov	word [es:bx + 18], floppy_bpb
	mov	word [es:bx + 20], cs
	ret

floppy_ppkt:
	mov	cx, [es:bx + 18]	; Sector count
	mov	ax, [es:bx + 20]	; Starting sector
	mov	dl, [es:bx +  1]	; Unit number
	mov	si, [es:bx + 14]
	mov	[cs:coff], si
	mov	si, [es:bx + 16]
	mov	[cs:cseg], si
	mov	[cs:ccnt], cx
	mov	[cs:cunit], dl
	ret

floppy_read:
	call	stk_enter
	push	ds
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	
	call	floppy_lgeom
	call	floppy_ppkt
	call	seek
.loop:	call	split
	call	spldma
	call	read3
	jc	.fail
	call	next
	sub	cx, [cs:ccnt]
	jnz	.loop
	
	mov	word [es:bx +  3], 0x0100	; DONE
.fini:	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	pop	ds
	call	stk_leave
	ret
.fail:	mov	word [es:bx +  3], 0x800c	; General Failure
	mov	word [es:bx + 18], 0
	jmp	.fini

floppy_write:
	call	stk_enter
	push	ds
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	
	call	floppy_lgeom
	call	floppy_ppkt
	call	seek
.loop:	call	split
	call	spldma
	call	write3
	jc	.fail
	call	next
	sub	cx, [cs:ccnt]
	jnz	.loop
	mov	word [es:bx +  3], 0x0100	; DONE
.fini:	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	pop	ds
	call	stk_leave
	ret
.fail:	mov	word [es:bx +  3], 0x800c	; General Failure
	mov	word [es:bx + 18], 0
	jmp	.fini

floppy_wrver:
	call	stk_enter
	push	ds
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	
	call	floppy_lgeom
	call	floppy_ppkt
	call	seek
.loop:	call	split
	call	spldma
	call	write3
	jc	.fail
	call	verify3
	jc	.fail
	call	next
	sub	cx, [cs:ccnt]
	jnz	.loop
	mov	word [es:bx +  3], 0x0100	; DONE
.fini:	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	pop	ds
	call	stk_leave
	ret
.fail:	mov	word [es:bx +  3], 0x800c	; General Failure
	mov	word [es:bx + 18], 0
	jmp	.fini

seek:	push	bx
	push	dx
	
	xor	dx, dx
	mov	bx, word [cs:nsect]
	div	bx
	mov	[cs:csect], dx
	xor	dx, dx
	mov	bx, word [cs:nhead]
	div	bx
	mov	byte [cs:chead], dl
	mov	[cs:ccyl], ax
	
	pop	dx
	pop	bx
	ret

split:	mov	ax, [cs:csect]
	add	ax, cx
	cmp	ax, [cs:nsect]
	jle	.fits
	
	mov	ax, [cs:nsect]
	sub	ax, [cs:csect]
	mov	[cs:ccnt], ax
	ret
	
.fits:	mov	[cs:ccnt], cx
	ret

spldma:
	push	cx
	
	mov	ax, [cs:cseg]
	mov	cl, 4
	shl	ax, cl
	add	ax, [cs:coff]
	neg	ax
	
	mov	cl, 9
	shr	ax, cl
	
	cmp	ax, [cs:ccnt]
	jge	.fits
	
	test	ax, ax
	jnz	.nzero
	inc	ax
.nzero:	mov	[cs:ccnt], ax
.fits:	pop	cx
	ret

bncaddr:
	dw	0, IOBUF >> 4

lparm:	les	bx, [cs:caddr]
	mov	ah, 0x02
	mov	al, byte [cs:ccnt]
	mov	ch, byte [cs:ccyl]
	mov	cl, byte [cs:ccyl + 1] ; This code is also used by the HD driver
	ror	cl, 1
	ror	cl, 1
	or	cl, byte [cs:csect]
	mov	dh, byte [cs:chead]
	mov	dl, byte [cs:cunit]
	inc	cl
	ret

read:	push	ds
	push	es
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	
	call	lparm
	int	0x13
	jc	.error
	
.fini:	clc
.fail:	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	pop	es
	pop	ds
	ret
.error:	cmp	ah, 0x09
	je	.bounce
	stc
	jmp	.fail
.bounce:mov	word [cs:ccnt], 1 ; xxx
	call	lparm
	les	bx, [cs:bncaddr]
	int	0x13
	jc	.fail
	
	lds	si, [cs:bncaddr]
	les	di, [cs:caddr]
	mov	cx, 0x100
	cld
	rep movsw
	
	jmp	.fini

verify:	mov	byte [cs:wrcmd], 0x04
	jmp	wrcom
write:	mov	byte [cs:wrcmd], 0x03
wrcom:	push	ds
	push	es
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	
	call	lparm
	mov	ah, [cs:wrcmd]
	int	0x13
	jc	.error
	
.fini:	clc
.fail:	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	pop	es
	pop	ds
	ret
.error:	cmp	ah, 0x09
	je	.bounce
	stc
	jmp	.fail
.bounce:les	di, [cs:bncaddr]
	lds	si, [cs:caddr]
	mov	cx, 0x100
	cld
	rep movsw
	
	mov	word [cs:ccnt], 1 ; xxx
	call	lparm
	mov	ah, [cs:wrcmd]
	les	bx, [cs:bncaddr]
	int	0x13
	jnc	.fini
	jmp	.fail

next:	push	cx
	
	mov	ax, [cs:ccnt]
	mov	cl, 5
	shl	ax, cl
	add	[cs:cseg], ax
	
	mov	ax, [cs:chead]
	mov	cx, [cs:ccnt]
	add	cx, [cs:csect]
	cmp	cx, [cs:nsect]
	jne	.fini
	
	xor	cx, cx
	inc	ax
	cmp	ax, [cs:nhead]
	jb	.fini
	
	xor	ax, ax
	inc	word [cs:ccyl]
.fini:	mov	[cs:csect], cx
	mov	[cs:chead], ax
	
	pop	cx
	ret

read3:	call	read
	jnc	.fini
	call	read
	jnc	.fini
	call	read
.fini:	ret

write3:	call	write
	jnc	.fini
	call	write
	jnc	.fini
	call	write
.fini:	ret

verify3:call	verify
	jnc	.fini
	call	verify
	jnc	.fini
	call	verify
.fini:	ret

wrcmd	db	0x03
nsect	dw	18
nhead	dw	2

caddr:
coff	dw	0
cseg	dw	0
ccyl	dw	0
ccnt	dw	0
chead	dw	0
csect	dw	0
cunit	db	0

floppy_bpba:
	dw	floppy_bpb
	dw	floppy_bpb

floppy_bpb:
	dw	0x0200		; bytes per sector
	db	0x01		; sectors per cluster
	dw	0x01		; reserved sectors
	db	0x02		; number of FATs
	dw	0x00e0		; number of dir entries
	dw	0x0b40		; number of sectors
	db	0xf0		; media descriptor
	dw	0x0009		; sectors per FAT

floppy_switch:
	dw	floppy_init	; Init
	dw	floppy_mcheck	; Media check (block only)
	dw	floppy_bbpb	; Build BPB (block only)
	dw	d_nofunc	; IOCTL input
	dw	floppy_read	; Input
	dw	d_nofunc	; Non-destructive input (no wait, char devs only)
	dw	d_nofunc	; Input status
	dw	d_nofunc	; Input flush
	dw	floppy_write	; Output
	dw	floppy_wrver	; Output with verify
	dw	d_nofunc	; Output flush
