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

DIVINT		equ	0x00

XITINT		equ	0x20
DOSINT		equ	0x21
XRTINT		equ	0x22
BRKINT		equ	0x23
ERRINT		equ	0x24
DKRINT		equ	0x25
DKWINT		equ	0x26
TSRINT		equ	0x27
EXTINT		equ	0x2b

CR		equ	13
LF		equ	10
BS		equ	8
ESC		equ	27
EOF		equ	26
INTR		equ	3

FCB1		equ	0x5c
FCB2		equ	0x6c

SCHRINE		equ	0x01
SCHROUT		equ	0x02
SDCHRIN		equ	0x06
SCHRINN		equ	0x08
SSTROUT		equ	0x09
SSTRIN		equ	0x0a
SDSKRST		equ	0x0d
SSDRIVE		equ	0x0e
SOPEN		equ	0x0f
SCLOSE		equ	0x10
SFINDF		equ	0x11
SFINDN		equ	0x12
SDELETE		equ	0x13
SREAD		equ	0x14
SWRITE		equ	0x15
SCREAT		equ	0x16
SRENAME		equ	0x17
SGDRIVE		equ	0x19
SSETDTA		equ	0x1a
SGETALLOC	equ	0x1b
SGETALLOC2	equ	0x1c
SGETDPB		equ	0x1f
SGDATE		equ	0x2a
SSDATE		equ	0x2b
SGTIME		equ	0x2c
SSTIME		equ	0x2d
SSINTV		equ	0x25
SNEWPSP		equ	0x26
SPARSEN		equ	0x29

DPB_OFFSET	equ	0x0b	; DPB offset within bootsector
DPB_SIZE	equ	0x11	; DPB size

DPB_BPS		equ	0x00
DPB_CLUSTER_SZ	equ	0x02
DPB_RSVD_SECTS	equ	0x03
DPB_NFATS	equ	0x05
DPB_NDIRENT	equ	0x06
DPB_TOT_SECTORS	equ	0x08
DPB_MEDIA_DESCR	equ	0x0a
DPB_FAT_SIZE	equ	0x0b
DPB_NSECT	equ	0x0d
DPB_NHEAD	equ	0x0f

SECT_SIZE	equ	0x200
