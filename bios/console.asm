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

d_con:	dw	d_aux, BIOSSEG
	dw	0x8013
	dw	strategy
	dw	con_io
d_conn:	db	"CON     "

con_io:
	push	si
	mov	si, con_switch
	jmp	d_switch

con_init:
	mov	word [es:bx +  3], 0x0100
	mov	word [es:bx + 14], endresid
	mov	word [es:bx + 16], cs
	call	stk_init
	ret

con_clear:
	push	bx
	push	cx
	push	dx
	push	si
	mov	ah, 0x0f
	int	0x10
	mov	bx, 0x0700
	cmp	al, 0x14
	jae	.doclr
	cmp	al, 0x59
	jne	.nsvga
	xor	bh, bh
	jmp	.doclr
.nsvga:	mov	si, .attr
	xor	ah, ah
	add	si, ax
	mov	bh, [cs:si]
.doclr:	mov	ax, 0x0600
	xor	cx, cx
	mov	dx, 0x184f
	int	0x10
	mov	ah, 0x02
	xor	bx, bx
	xor	dx, dx
	int	0x10
	pop	si
	pop	dx
	pop	cx
	pop	bx
	ret
.attr:	db	7 ; 00: 40x25 Text, grayscale
	db	7 ; 01: 40x25 Text
	db	7 ; 02: 80x25 Text, grayscale
	db	7 ; 03: 80x25 Text
	db	0 ; 04: CGA 320x200
	db	0 ; 05: CGA 320x200, grayscale
	db	0 ; 06: CGA 640x200
	db	7 ; 07: 80x25 Mono text
	db	7 ; 08: Various modes, assume text
	db	0 ; 09: PCjr 320x200
	db	0 ; 0a: PCjr 640x200
	db	0 ; 0b: Tandy 1000 SL/TL
	db	7 ; 0c: Reserved
	db	0 ; 0d: EGA/VGA 320x200, 16 colors
	db	0 ; 0e: EGA/VGA 640x200, 16 colors
	db	0 ; 0f: EGA/VGA 640x350, mono
	db	0 ; 10: EGA/VGA 640x350, 4 or 16 colors
	db	0 ; 11: VGA 640x480, mono
	db	0 ; 12: VGA 640x480, 16 colors
	db	0 ; 13: VGA 320x200, 256 colors

con_fastout:
	call	stk_enter
	push	ax
	mov	ah, [cs:.state]
	cmp	ax, 27
	je	.incr
	cmp	ax, 0x0100 + "["
	je	.incr
	cmp	ax, 0x0200 + "2"
	je	.incr
	cmp	ax, 0x0300 + "J"
	je	.clear
	mov	byte [cs:.state], 0
	call	chrout
.fini:	pop	ax
	call	stk_leave
	iret
.clear:	mov	byte [cs:.state], 0
	call	con_clear
	jmp	.fini
.incr:	inc	byte [cs:.state]
	jmp	.fini
.state:	db	0

con_read:
	call	stk_enter
	push	ax
	push	cx
	push	di
.loop:	xor	ax, ax
	int	0x16
	test	al, al
	jz	.loop
	push	es
	les	di, [es:bx + 14]	; Transfer address
	stosb
	pop	es
	mov	[es:bx + 18], byte 1	; Byte count
	mov	[es:bx + 3 ], word 0x0100
	pop	di
	pop	cx
	pop	ax
	call	stk_leave
	ret

con_write:
	call	stk_enter
	push	cx
	push	si
	lds	si, [es:bx + 14] ; Transfer address
	mov	cx, [es:bx + 18] ; Byte count
.loop:	lodsb
	call	chrout
	loop	.loop
	mov	word [es:bx + 3], 0x0100
	pop	si
	pop	cx
	call	stk_leave
	ret

con_read_no_wait:
	call	stk_enter
	push	ax
.loop:	mov	ax, 0x0100
	int	0x16
	jz	.nokey
	test	al, al
	jz	.skip
	mov	byte [es:bx + 13], al
	mov	word [es:bx + 3 ], 0x0100
	pop	ax
	call	stk_leave
	ret
.nokey:	mov	word [es:bx + 3 ], 0x0300
	pop	ax
	call	stk_leave
	ret
.skip:	xor	ah, ah
	int	0x16
	jmp	.loop

con_status:
	mov	word [es:bx + 3], 0x0100
	ret

con_flush:
	call	stk_enter
	push	ax
.loop:	mov	ah, 0x01
	int	0x16
	jz	.nokey
	xor	ah, ah
	int	0x16
	jmp	.loop
.nokey:	mov	word [es:bx + 3], 0x0100
	pop	ax
	call	stk_leave
	ret

con_switch:
	dw	con_init	; Init
	dw	d_nofunc	; Media check (block only)
	dw	d_nofunc	; Build BPB (block only)
	dw	d_nofunc	; IOCTL input
	dw	con_read	; Input
	dw	con_read_no_wait ; Non-destructive input (no wait, char devs only)
	dw	d_nofunc	; Input status
	dw	con_flush	; Input flush
	dw	con_write	; Output
	dw	con_write	; Output with verify
	dw	con_status	; Output flush
