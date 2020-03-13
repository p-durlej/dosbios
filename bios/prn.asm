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

d_prn:	dw	d_clk, BIOSSEG
	dw	0x8000
	dw	strategy
	dw	prn_io
d_prnn:	db	"PRN     "

prn_io:	push	si
	mov	si, prn_switch
	jmp	d_switch

prn_init:
	mov	word [es:bx +  3], 0x0100
	mov	word [es:bx + 14], endresid
	mov	word [es:bx + 16], cs
	ret

prn_write:
	call	stk_enter
	push	ds
	push	cx
	push	dx
	push	si
	lds	si, [es:bx + 14] ; Transfer address
	mov	cx, [es:bx + 18] ; Byte count
.loop:	xor	dx, dx
	xor	ah, ah
	lodsb
	int	0x17
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

prn_read_no_wait:
prn_read:
	mov	word [es:bx + 18], 0x0000 ; Byte count
	mov	word [es:bx + 3 ], 0x0100
	ret

prn_status:
	mov	word [es:bx + 3], 0x0100
	ret

prn_flush:
	mov	word [es:bx + 3], 0x0100
	ret

prn_switch:
	dw	prn_init	; Init
	dw	d_nofunc	; Media check (block only)
	dw	d_nofunc	; Build BPB (block only)
	dw	d_nofunc	; IOCTL input
	dw	prn_read	; Input
	dw	prn_read_no_wait ; Non-destructive input (no wait, char devs only)
	dw	d_nofunc	; Input status
	dw	prn_flush	; Input flush
	dw	prn_write	; Output
	dw	prn_write	; Output with verify
	dw	prn_status	; Output flush
