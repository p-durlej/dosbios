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

d_clk:	dw	d_floppy, BIOSSEG
	dw	0x8008
	dw	strategy
	dw	clk_io
d_clkn:	db	"CLOCK$  "

clk_io:
	push	si
	mov	si, clk_switch
	jmp	d_switch

clk_init:
	mov	word [es:bx +  3], 0x0100
	mov	word [es:bx + 14], endresid
	mov	word [es:bx + 16], cs
	ret

clk_bcd2int:
	push	bx
	push	cx
	push	dx
	mov	bx, ax
	and	ax, 0xf0f0
	mov	cl, 4
	shr	ax, cl
	mov	cx, 10
	mul	cx
	and	bx, 0x0f0f
	add	ax, bx
	pop	dx
	pop	cx
	pop	bx
	ret

; XXX this code is crude

clk_read:
	call	stk_enter
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	es
	
	les	di, [es:bx + 14]	; Transfer address
	mov	cx, [es:bx + 18]	; Byte count
	cmp	cx, 6
	jb	.fail
	
	mov	ah, 0x04
	clc
	int	0x1a
	jc	.fail
	
	push	bx
	
	mov	ax, cx
	call	clk_bcd2int
	mov	cx, ax
	
	mov	ax, dx
	call	clk_bcd2int
	mov	dx, ax
	
	xor	ah, ah
	mov	bx, ax
	
	mov	si, clk_md - 2
	test	cl, 3
	jnz	.nleap
	mov	si, clk_lmd - 2
.nleap:
	
	xor	ah, ah
	mov	al, dh
	add	si, ax
	add	si, ax
	mov	ax, [cs:si]
	add	bx, ax
	
	xor	ah, ah
	mov	al, cl
	add	al, 3
	shr	al, 1
	shr	al, 1
	add	bx, ax
	
	mov	al, cl
	mov	cx, 365
	mul	cx
	
	add	ax, bx
	add	ax, 0x1c88
	
	cld
	stosw
	
	pop	bx
	
	mov	ah, 0x02
	clc
	int	0x1a
	jc	.fail
	
	mov	ax, cx
	call	clk_bcd2int
	stosw
	xor	al, al
	mov	ax, dx
	call	clk_bcd2int
	stosw
	
	mov	word [es:bx +  3], 0x0100
	mov	word [es:bx + 18], 6	; Byte count
	
.fini:	pop	es
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	call	stk_leave
	ret
.fail:	mov	word [es:bx +  3], 0x800c
	mov	word [es:bx + 18], 0
	jmp	.fini
clk_md:	dw	0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334
clk_lmd:dw	0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335

clk_int2bcd8:
	push	cx
	push	dx
	xor	ah, ah
	mov	dl, 10
	div	dl
	mov	cl, 4
	shl	al, cl
	or	al, ah
	pop	dx
	pop	cx
	ret

clk_write:
	call	stk_enter
	push	ax
	push	cx
	push	dx
	push	si
	push	ds
	
	lds	si, [es:bx + 14]	; Transfer address
	mov	cx, [es:bx + 18]	; Byte count
	cmp	cx, 6
	jb	.fail
	
	lodsw
	
	mov	dx, ax
	mov	cl, 14
	shr	dx, cl
	shl	ax, 1
	shl	ax, 1
	mov	cx, 365 * 4 + 1
	div	cx
	cmp	ax, 20
	jb	.fail
	sub	ax, 20
	
	; convert the year to BCD and load into CX
	
	call	clk_int2bcd8
	mov	cl, al
	mov	ch, 0x20
	
	mov	bx, clk_md + 2
	test	al, 3
	jnz	.noleap
	mov	bx, clk_lmd + 2
	
.noleap:mov	ax, 1
	shr	dx, 1
	shr	dx, 1
.loop:	cmp	dx, [cs:bx]
	jl	.found
	add	bx, 2
	inc	ax
	jmp	.loop
.found:	sub	dx, [cs:bx - 2]
	inc	dx
	call	clk_int2bcd8
	mov	dh, al
	mov	al, dl
	call	clk_int2bcd8
	mov	dl, al
	
	mov	ah, 0x05
	int	0x1a
	
	lodsb
	call	clk_int2bcd8
	mov	cl, al
	
	lodsb
	call	clk_int2bcd8
	mov	ch, al
	
	lodsb
	lodsb
	call	clk_int2bcd8
	mov	dh, al
	xor	dl, dl
	
	mov	ah, 0x03
	int	0x1a
	
	mov	word [es:bx +  3], 0x0100
	mov	word [es:bx + 18], 6	; Byte count
	
.fini:	pop	ds
	pop	si
	pop	dx
	pop	cx
	pop	ax
	call	stk_leave
	ret
.fail:	mov	word [es:bx +  3], 0x800c
	mov	word [es:bx + 18], 0
	jmp	.fini

clk_switch:
	dw	clk_init	; Init
	dw	d_nofunc	; Media check (block only)
	dw	d_nofunc	; Build BPB (block only)
	dw	d_nofunc	; IOCTL input
	dw	clk_read	; Input
	dw	clk_read	; Non-destructive input (no wait, char devs only)
	dw	d_nofunc	; Input status
	dw	d_nofunc	; Input flush
	dw	clk_write	; Output
	dw	clk_write	; Output with verify
	dw	d_nofunc	; Output flush
