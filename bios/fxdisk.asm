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

d_fxdisk:
	dw	-1, -1
	dw	0x2000
	dw	strategy
	dw	fxdisk_io
fxcnt:	db	1
	db	0, 0, 0, 0, 0, 0, 0

; ---- fxdisk ----------------------------------------------------------------

fxdisk_io:
	push	si
	mov	si, fxdisk_switch
	jmp	d_switch

fxdisk_readpart:
	mov	ax, 0x0201
	mov	cx, 0x0001
	mov	dx, 0x0080
	mov	bx, IOBUF >> 4
	mov	ds, bx
	mov	es, bx
	xor	bx, bx
	int	0x13
	ret

fxdisk_getpart:
	call	fxdisk_readpart
	jnc	.ok
	call	fxdisk_readpart
	jnc	.ok
	call	fxdisk_readpart
	jc	.fini
	
.ok:	mov	bx, 0x1be
.loop:	mov	al, [bx + 0x4]
	cmp	al, 0x01
	je	.found
	add	bx, 0x10
	cmp	bx, 0x1fe
	jne	.loop
	stc
.fini:	push	cs
	pop	es
	push	cs
	pop	ds
	ret
.found:	mov	ax, [bx + 0x8]
	mov	cx, [bx + 0xc]
	
	mov	[cs:fxoff ], ax
	mov	[cs:fxtots], cx
	
	jmp	.fini

fxdisk_init:
	call	stk_enter
	
	mov	byte [es:bx + 13], 1		; number of units
	mov	word [es:bx + 14], endresid
	mov	word [es:bx + 16], cs
	mov	word [es:bx + 18], fxdisk_bpba	; BPB list offset
	mov	word [es:bx + 20], cs		; BPB list segment
	mov	word [es:bx +  3], 0x0100	; DONE
	
	mov	ah, 0x08
	mov	dl, 0x80
	int	0x13
	jc	.fail
	
	inc	dh
	
	mov	al, cl
	xor	ah, ah
	shl	ax, 1
	shl	ax, 1
	mov	al, ch
	inc	ax
	
	mov	[cs:fxdisk_geom    ], ax
	mov	[cs:fxdisk_geom + 2], dh
	and	cl, 0x3f
	mov	[cs:fxdisk_geom + 4], cl
	
	call	fxdisk_getpart
	call	stk_leave
	ret
.fail:	call	stk_leave
	ret

fxdisk_mcheck:
	mov	byte [es:bx + 14], 0		; Not sure if media changed
;	mov	byte [es:bx + 14], 1		; Media has been changed
	mov	word [es:bx +  3], 0x0100	; DONE
	ret

fxdisk_bbpb:
	mov	word [es:bx +  3], 0x0100	; DONE
	mov	word [es:bx + 18], fxdisk_bpb
	mov	word [es:bx + 20], cs
	ret

fxdisk_lgeom:
	push	ax
	mov	ax, [cs:fxdisk_geom + 2]
	mov	[cs:nhead], ax
	mov	ax, [cs:fxdisk_geom + 4]
	mov	[cs:nsect], ax
	pop	ax
	ret

fxdisk_ppkt:
	call	floppy_ppkt
	add	byte [cs:cunit], 0x80
	ret

fxdisk_nogeom:
	mov	word [es:bx +  3], 0x800c
	mov	word [es:bx + 18], 0
	ret

fxdisk_read:
	test	word [cs:fxtots], -1
	jz	fxdisk_nogeom
	
	call	stk_enter
	push	ds
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	
	call	fxdisk_lgeom
	call	fxdisk_ppkt
	add	ax, [cs:fxoff]
	call	seek
	
.loop:	call	split
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

fxdisk_write:
	test	word [cs:fxtots], -1
	jz	fxdisk_nogeom
	
	call	stk_enter
	push	ds
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	
	call	fxdisk_lgeom
	call	fxdisk_ppkt
	add	ax, [cs:fxoff]
	call	seek
.loop:	call	split
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

fxdisk_wrver:
	test	word [cs:fxtots], -1
	jz	fxdisk_nogeom
	
	call	stk_enter
	push	ds
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	
	call	fxdisk_lgeom
	call	fxdisk_ppkt
	add	ax, [cs:fxoff]
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

fxdisk_bpba:
	dw	fxdisk_bpb
	dw	fxdisk_bpb

fxdisk_geom:
	dw	0	; Cylinders
	dw	0	; Heads
	dw	0	; Sectors
fxoff:	dw	0	; Partition offset

fxdisk_bpb:
	dw	0x0200		; bytes per sector
	db	0x10		; sectors per cluster
	dw	0x01		; reserved sectors
	db	0x02		; number of FATs
	dw	0x0200		; number of dir entries
fxtots:	dw	0x0000		; number of sectors
	db	0xf8		; media descriptor
	dw	0x0008		; sectors per FAT

fxdisk_switch:
	dw	fxdisk_init	; Init
	dw	fxdisk_mcheck	; Media check (block only)
	dw	fxdisk_bbpb	; Build BPB (block only)
	dw	d_nofunc	; IOCTL input
	dw	fxdisk_read	; Input
	dw	d_nofunc	; Non-destructive input (no wait, char devs only)
	dw	d_nofunc	; Input status
	dw	d_nofunc	; Input flush
	dw	fxdisk_write	; Output
	dw	fxdisk_wrver	; Output with verify
	dw	d_nofunc	; Output flush
