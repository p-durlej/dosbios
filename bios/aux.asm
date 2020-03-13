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

d_aux:	dw	d_prn, BIOSSEG
	dw	0x8000
	dw	strategy
	dw	aux_io
d_auxn:	db	"AUX     "

aux_io:	push	si
	mov	si, aux_switch
	jmp	d_switch

aux_init:
	mov	word [es:bx +  3], 0x0100
	mov	word [es:bx + 14], endresid
	mov	word [es:bx + 16], cs
	ret

aux_havechr:
	db	0
aux_cbuf:
	db	0

aux_read:
	call	stk_enter
	push	ax
	push	cx
	push	dx
	push	di
	push	es
	mov	cx, [es:bx + 18] ; Byte count
	les	di, [es:bx + 14] ; Transfer address
	test	byte [cs:aux_havechr], -1
	jnz	.havechr
.loop:	xor	dx, dx
	mov	ax, 0x0200
	int	0x14
	test	ah, 0x80
	jnz	.stop
	stosb
	loop	.loop
.stop:	pop	es
	sub	[es:bx + 18], cx
	mov	[es:bx + 3 ], word 0x0100
	pop	di
	pop	dx
	pop	cx
	pop	ax
	call	stk_leave
	ret
.havechr:
	mov	byte [cs:aux_havechr], 0
	mov	al, [cs:aux_cbuf]
	stosb
	dec	cx
	jmp	.stop

aux_read_no_wait:
	call	stk_enter
	push	ax
.loop:	mov	ax, 0x0300
	xor	dx, dx
	int	0x14
	test	ah, 0x01
	jz	.nochr
	sub	[es:bx + 18], cx
	mov	[es:bx + 3 ], word 0x0100
	pop	ax
	call	stk_leave
	ret
.nochr:	mov	word [es:bx + 3 ], 0x0300
	pop	ax
	call	stk_leave
	ret

aux_write:
	call	stk_enter
	push	ds
	push	cx
	push	dx
	push	si
	lds	si, [es:bx + 14] ; Transfer address
	mov	cx, [es:bx + 18] ; Byte count
.loop:	xor	dx, dx
	mov	ah, 0x01
	lodsb
	int	0x14
	jc	.fail
	loop	.loop
	mov	word [es:bx + 3], 0x0100
.fini:	pop	si
	pop	dx
	pop	cx
	pop	ds
	call	stk_leave
	ret
.fail:	mov	word [es:bx + 3], 0x800c
	jmp	.fini

aux_status:
	mov	word [es:bx + 3], 0x0100
	ret

aux_flush:
	call	stk_enter
	push	ax
	push	dx
	mov	ax, 0x0300
	xor	dx, dx
	int	0x14
	test	ah, 0x01
	jz	.nochr
	mov	ax, 0x0200
	xor	dx, dx
	int	0x14
.nochr:	mov	word [es:bx + 3], 0x0100
	pop	dx
	pop	ax
	call	stk_leave
	ret

aux_switch:
	dw	aux_init	; Init
	dw	d_nofunc	; Media check (block only)
	dw	d_nofunc	; Build BPB (block only)
	dw	d_nofunc	; IOCTL input
	dw	aux_read	; Input
	dw	aux_read_no_wait ; Non-destructive input (no wait, char devs only)
	dw	d_nofunc	; Input status
	dw	aux_flush	; Input flush
	dw	aux_write	; Output
	dw	aux_write	; Output with verify
	dw	aux_status	; Output flush
