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

bpb	equ	bootsec + DPB_OFFSET
clusz	equ	bpb	+ DPB_CLUSTER_SZ
nsect	equ	bpb	+ DPB_NSECT
nhead	equ	bpb	+ DPB_NHEAD
nfats	equ	bpb	+ DPB_NFATS
fatsz	equ	bpb	+ DPB_FAT_SIZE
ndire	equ	bpb	+ DPB_NDIRENT
rsvds	equ	bpb	+ DPB_RSVD_SECTS
totsec	equ	bpb	+ DPB_TOT_SECTORS

	push	ax
	mov	ah, 0xff
	int	DOSINT
	cmp	al, 0x20
	jne	baddos
	pop	ax
	
	test	al, al
	jnz	baddrv
	
	mov	cl, [0x80]
	xor	ch, ch
	mov	di, 0x81
	mov	al, '/'
	cld
.getsw:	repne scasb
	cmp	cx, 0
	je	.getdrv
	mov	bl, [di]
	cmp	bl, 's'
	je	.sflag
	cmp	bl, 'S'
	je	.sflag
	cmp	bl, 'q'
	je	.qflag
	cmp	bl, 'Q'
	je	.qflag
	cmp	bl, 'a'
	je	.aflag
	cmp	bl, 'A'
	je	.aflag
	cmp	bl, 'e'
	je	.eflag
	cmp	bl, 'E'
	je	.eflag
	jmp	.badsw
.sflag:	mov	byte [sflag], 1
	jmp	.getsw
.qflag:	mov	byte [qflag], 1
	jmp	.getsw
.aflag:	mov	byte [aflag], 1
	jmp	.getsw
.eflag:	mov	byte [ndire], 16
	jmp	.getsw
.badsw:	mov	dx, mbadsw
	mov	ah, SSTROUT
	int	DOSINT
	mov	ah, SCHROUT
	mov	dl, bl
	int	DOSINT
	call	crlf
	int	XITINT
.getdrv:mov	al, [FCB1]
	test	al, al
	jnz	.gotdrv
	mov	ah, SGDRIVE
	int	DOSINT
	inc	al
.gotdrv:dec	al
	mov	[biosdrv], al ; XXX assumes DOS drive numbers correspond directly to BIOS drive numbers
	mov	[drive], al
	add	[minsnew + 33], al
	add	[mconfm  + 16], al
	add	[label	     ], al
	inc	al
	
	cmp	al, 2
	jle	.floppy
	add	byte [biosdrv], 126
	mov	byte [qflag], 1
.floppy:
	
	call	loadsys
.again:	test	byte [aflag], 0xff
	jnz	.nwait
	
	mov	dx, minsnew
	test	byte [biosdrv], 0x80
	jz	.nhard
	mov	dx, mconfm
.nhard:
	mov	ah, SSTROUT
	int	DOSINT
	
	call	waitkey
.nwait:	mov	ah, SCHROUT
	mov	dl, LF
	int	DOSINT
	call	fmt
	jc	.asknxt
	call	savesys
	call	setlabel
.asknxt:test	byte [biosdrv], 0x80
	jnz	.fini
	test	byte [aflag], 0xff
	jnz	.fini
	call	crlf
.asknx1:mov	dx, mnext
	mov	ah, SSTROUT
	int	DOSINT
	mov	ah, SCHRINE
	int	DOSINT
	call	crlf
	cmp	al, 'Y'
	je	.again
	cmp	al, 'y'
	je	.again
	cmp	al, 'N'
	je	.fini
	cmp	al, 'n'
	jne	.asknx1
.fini:	int	XITINT

fmt:	mov	ah, SDSKRST
	int	DOSINT
	
	; get drive parameters
	
	mov	dl, [biosdrv]
	mov	ah, 0x08
	int	0x13
	mov	ax, cs
	mov	es, ax
	mov	ds, ax
	jc	.fail
	inc	ch
	inc	dh
	mov	dl, cl
	rol	dl, 1
	rol	dl, 1
	and	dl, 3
	mov	byte [ncyl + 1], dl
	mov	byte [ncyl], ch
	and	cl, 0x3f
	mov	[nsect], cl
	mov	[nhead], dh
	
	mov	ax, word [nsect]
	mov	cx, word [nhead]
	mul	cl
	mov	cx, word [ncyl]
	mul	cx
	mov	word [totsec], ax
	
	mov	cx, ax
	shl	cx, 1
	add	cx, ax
	
	add	cx, 1023
	shr	cx, 1
	shr	cx, 1
	mov	cl, ch
	xor	ch, ch
	
	mov	word [fatsz], cx
	
	; set media type
	
	mov	dl, [biosdrv]
	test	dl, 0x80
	jnz	.nsmtype
	mov	ch, byte [ncyl]
	mov	cl, [nsect]
	dec	ch
	mov	ah, 0x18
	int	0x13
.nsmtype:
	
	cmp	byte [qflag], 0
	jne	.quick
	
	mov	byte [mwork + 18], '0'
	mov	byte [mwork + 19], '0'
	mov	byte [mwork + 27], '1'
	
	mov	byte [curhead], 0
	mov	word [curcyl ], 0
	
.next:	mov	ah, SSTROUT
	mov	dx, mwork
	int	DOSINT
	
	mov	ax, cs
	mov	es, ax
	
	; fill AFB
	
	mov	dl, 1
	mov	di, buf
	mov	cl, [nsect]
	xor	ch, ch
.fafb:	mov	al, [curcyl]
	stosb
	
	mov	al, [curhead]
	stosb
	
	mov	al, dl
	inc	dl
	stosb
	
	mov	al, 2
	stosb
	loop	.fafb
	
	; format track
	
	call	fmttrk
	jc	.fail
	
	; advance to the next track
	
	mov	al, [nhead]
	add	al, '1'
	inc	byte [mwork + 27]
	cmp	byte [mwork + 27], al
	jne	.incch
	mov	byte [mwork + 27], '1'
	inc	byte [mwork + 19]
	cmp	byte [mwork + 19], 58
	jne	.incch
	mov	byte [mwork + 19], '0'
	inc	byte [mwork + 18]
	
.incch:	mov	al, [nhead]
	mov	bl, byte [ncyl]
	inc	byte [curhead]
	cmp	byte [curhead], al
	jb	.next
	mov	byte [curhead], 0
	inc	word [curcyl]
	cmp	byte [curcyl], bl ; XXX
	jb	.next
	
.quick:	call	clrlin
	mov	dx, mwork2
	mov	ah, SSTROUT
	int	DOSINT
	
	; XXX DOSBIOS uses a hardcoded BPB and ignores on-disk BPB
	; update BPB and partition offset
	
	mov	ah, 0x32
	mov	dl, [drive]
	inc	dl
	int	DOSINT
	test	al, al
	jnz	.fail
	
	mov	cl, [ds:bx + 0x04] ; Cluster size
	inc	cl
	mov	ax, [ds:bx + 0x06] ; Reserved sectors
	mov	dl, [ds:bx + 0x08] ; Number of FATs
	mov	si, [ds:bx + 0x09] ; Number of root dir entries
	mov	dh, [ds:bx + 0x0f] ; Sectors per FAT
	
	push	cs
	pop	ds
	
	mov	word [rsvds], ax
	mov	byte [nfats], dl
	mov	word [ndire], si
	mov	byte [fatsz], dh
	mov	byte [clusz], cl
	
	; write the boot sector to disk
	
	call	writeboot
	jc	.fail
	
	mov	cx, word [ndire]
	add	cx, 15
	shr	cx, 1
	shr	cx, 1
	shr	cx, 1
	shr	cx, 1
	
	mov	ax, word [fatsz]
	mov	bl, byte [nfats]
	xor	bh, bh
	mul	bx
	add	cx, ax
	
	add	cx, word [rsvds]
	
	dec	cx
	mov	[sresid], cx
	mov	byte [cursec], 1
	
	mov	cx, SECT_SIZE
	mov	di, buf
	xor	al, al
	rep stosb
	
	mov	word [buf    ], 0xfff8
	mov	byte [buf + 2], 0xff
	
.clear:	mov	al, [drive]
	mov	cx, 1
	mov	dx, [cursec]
	mov	bx, buf
	call	dkwrite
	jc	.fail
	
	mov	word [buf    ], 0
	mov	byte [buf + 2], 0
	
	inc	byte [cursec]
	dec	word [sresid]
	cmp	word [sresid], 0
	jne	.clear
	
	mov	ah, SSTROUT
	mov	dx, mdone
	int	DOSINT
	clc
	ret
.fail:	call	clrlin
	mov	ah, SSTROUT
	mov	dx, mfail
	int	DOSINT
	stc
	ret

fmttrk1:mov	al, [nsect]
	mov	ch, [curcyl]
	mov	dh, [curhead]
	mov	dl, [biosdrv]
	mov	bx, buf
	mov	ah, 0x05
	int	0x13
	ret

fmttrk:	call	fmttrk1
	jnc	.fini
	call	fmttrk1
	jnc	.fini
	call	fmttrk1
	jnc	.fini
	cmp	ah, 3
	je	.wprot
.fini:	ret
.wprot:	call	clrlin
	mov	ah, SSTROUT
	mov	dx, mwprot
	int	DOSINT
	stc
	ret

clrlin:	mov	ah, SCHROUT
	mov	dl, CR
	int	DOSINT
	mov	dl, ' '
	mov	cx, 39
.loop:	int	DOSINT
	loop	.loop
	mov	dl, CR
	int	DOSINT
	ret

dkwrite:push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	bp
	mov	[.sp], sp
	int	DKWINT
	mov	sp, [.sp]
	pop	bp
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
.sp	dw	0

writeboot:
	mov	bx, bootsec
	mov	al, [drive]
	mov	cx, 1
	xor	dx, dx
	jmp	dkwrite

loadsys:
	mov	al, [drive]
	add	[biosnam], al
	add	[dosnam], al
	add	[comnam], al
	ret

savesys:
	cmp	byte [sflag], 0
	je	.fini
	
	mov	dx, biosnam
	mov	di, bios
	mov	bl, 0x07
	mov	cx, dos - bios
	call	savefile
	
	mov	dx, dosnam
	mov	di, dos
	mov	bl, 0x07
	mov	cx, command - dos
	call	savefile
	
	mov	dx, comnam
	mov	di, command
	mov	bl, 0x20
	mov	cx, endcom - command
	call	savefile
	
.fini:	ret

savefile:
	push	cx
	mov	ah, 0x3c
	mov	cx, bx
	int	DOSINT
	jc	saverr
	mov	bx, ax
	pop	cx
	
	mov	ah, 0x40
	mov	dx, di
	int	DOSINT
	jc	saverr
	mov	cx, ax
	
	mov	ah, 0x3e
	int	DOSINT
	jc	saverr
	
	ret

saverr:	mov	dx, msave
	mov	ah, SSTROUT
	int	DOSINT
	int	XITINT ; XXX

waitkey:mov	dx, manykey
	mov	ah, SSTROUT
	int	DOSINT
	mov	ah, SCHRINN
	int	DOSINT
	call	crlf
.fini:	ret

setlabel:
	test	[aflag], byte 1
	jnz	.fini
	
	; prompt the user and input the label
	
.again:	mov	dx, mlabel
	mov	ah, SSTROUT
	int	DOSINT
	mov	ah, SSTRIN
	mov	dx, .buf
	int	DOSINT
	call	crlf
	
	mov	cl, [.len]
	xor	ch, ch
	test	cx, cx
	jz	.fini
	mov	di, label + 3
	mov	si, .buf + 2
	cmp	cx, 8
	jg	.long
	rep movsb
.nterm:	xor	al, al
	stosb
	
	; XXX probably should use the FCB API
	; create the label
	
	mov	dx, label
	mov	cx, 8
	mov	ah, 0x3c
	int	DOSINT
	jnc	.fini
	cmp	ax, 2
	jne	.badlab
.fini:	ret
.long:	mov	bx, cx
	mov	cx, 8
	rep movsb
	mov	al, '.'
	stosb
	mov	cx, bx
	sub	cx, 8
	rep movsb
	jmp	.nterm
.badlab:mov	dx, mbadlab
	mov	ah, SSTROUT
	int	DOSINT
	jmp	.again
	.buf:	db	12
.len:	db	0
	resb	12

label:	db	"A:\"
	resb	13

baddos:	mov	dx, mbaddos
	mov	ah, SSTROUT
	int	DOSINT
	int	XITINT

baddrv:	mov	dx, mbaddrv
	mov	ah, SSTROUT
	int	DOSINT
	int	XITINT

crlf:	push	ax
	push	dx
	mov	ah, SCHROUT
	mov	dl, CR
	int	DOSINT
	mov	ah, SCHROUT
	mov	dl, LF
	int	DOSINT
	pop	dx
	pop	ax
	ret

minsnew	db	CR, LF,	"Insert NEW diskette into drive A",		CR, LF, "$"
mconfm	db	CR, LF,	"Data in drive A will be lost!",		CR, LF, "$"
mwprot	db		"Disk write-protected",				CR, LF, "$"
mnext	db	CR,	"Format another disk (Y/N)? $"
mwork	db	CR,	"Formatting track XX, side X ... $"
mwork2	db	CR,	"Formatting ... $"
mdone	db	CR,	"Format complete",				CR, LF, "$"
mfail	db	CR,	"Format failed",				CR, LF, "$"
msys	db		"Transferring DOS ... $"
msdone	db	CR,	"DOS transferred     ",				CR, LF, "$"
manykey	db		"Strike any key when ready ... $"
mbaddrv	db		"Invalid drive specification",			CR, LF, "$"
mbadsw	db		"Invalid switch: /$",				CR, LF, "$"
mbadlab	db		"Invalid label",				CR, LF, "$"
mbaddos	db		"Incorrect DOS version",			CR, LF, "$"
mlabel	db		"Volume label: $"
msave	db	CR,	"Cannot transfer operating system"
mcrlf	db	CR, LF, "$"

bootsec	incbin	"boot/boot.com"
bios	incbin	"bios/dosbios.sys"
dos	incbin	"msdos/msdos.sys"
command	incbin	"msdos/command.com"
endcom:

ncyl	dw	80

biosnam:db	"A:\IO.SYS", 0
dosnam:	db	"A:\MSDOS.SYS", 0
comnam:	db	"A:\COMMAND.COM", 0

	section	.bss
sbss:

drive	resb	1
biosdrv	resb	1

curcyl	resb	1
curhead	resb	1

cursec	resw	1
sresid	resw	1

sflag	resb	1
qflag	resb	1
aflag	resb	1

buf:	resb	512

ebss:
