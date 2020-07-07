; This is a basic XMODEM/CRC "bootloader" based on
; code by Daryl Rictor and Ross Archer:
; http://www.6502.org/source/io/xmodem/xmodem-receive.txt


.include "io.inc"


XPACKET_BUF 	= $0200
XPACKET_SIZE 	= 133

X_SOH 			= $01
X_EOT 			= $04
X_ACK 			= $06
X_NAK 			= $15


.segment "VECTORS"
.word nmi
.word reset
.word irq


.zeropage
ptr1:  		.res 2
xdlptr:		.res 2
blkno: 		.res 1
retry1: 	.res 1
retry2: 	.res 1
bflag: 		.res 1
crc:		.res 2

.code
reset: 		jmp start
nmi:		rti
irq:		rti


.macro ld16 addr, val
	lda #<val
	sta addr
	lda #>val
	sta addr+1
.endmacro

.macro inc16 addr
.local @skip
	inc addr
	bne @skip
	inc addr+1
@skip:
.endmacro


.proc start
	sei
	cld
	ldx #$FF
	txs
	cli


	lda #$0F
	sta VIA_DDRA
	stz VIA_ORA


	lda #%00001011
    sta ACIA_COMMAND
    lda #%00011111
    sta ACIA_CONTROL


    jsr xrecv
    bcs run

    lda #$0F
    sta VIA_ORA
cry:
	wai
	bra cry

run:
	jmp (xdlptr)
.endproc


.proc xrecv
    		lda #1
    		sta blkno
    		sta bflag

startcrc:	lda #'C'
			jsr acia_putc
			lda #$FF
			sta retry2
			stz crc
			stz crc+1
			jsr xget_byte
			bcs gotb
			bra startcrc

startblk:	lda #$FF
			sta retry2
			stz crc
			stz crc+1
			jsr xget_byte
			bcc startblk
gotb:	  	cmp #X_SOH
			beq begblk
			cmp #X_EOT
			bne badcrc
			jmp done
begblk:		ldx #0
getblk:		lda #$FF
			sta retry2
getblk1:	jsr xget_byte
			bcc badcrc
getblk2:  	sta XPACKET_BUF,x
			inx
			cpx #$84
			bne getblk
			ldx #0
			lda XPACKET_BUF,x
			cmp blkno
			beq goodblk1
			jsr xflush
			clc
			rts
goodblk1:	eor #$FF
			inx
			cmp XPACKET_BUF,x
			beq goodblk2
			clc
			rts
goodblk2:	ldy #2
calccrc:	lda XPACKET_BUF,y
			jsr xcrc_update
			iny
			cpy #$82
			bne calccrc
			lda XPACKET_BUF,y
			cmp crc+1
			bne badcrc
			iny
			lda XPACKET_BUF,y
			cmp crc
			beq goodcrc
badcrc:		jsr xflush
			lda #X_NAK
			jsr acia_putc
			jmp startblk

goodcrc:	ldx #2
			lda blkno
			cmp #1
			bne copyblk
			lda bflag
			beq copyblk
			lda XPACKET_BUF,x
			sta xdlptr
			sta ptr1
			inx
			lda XPACKET_BUF,x
			sta xdlptr+1
			sta ptr1+1
			inx
			dec bflag

copyblk: 	ldy #0
copyblk1:	lda XPACKET_BUF,x
			sta (ptr1),y
			inc16 ptr1
			inx
			cpx #$82
			bne copyblk1
incblk:		inc blkno
			lda #X_ACK
			jsr acia_putc
			jmp startblk

done:		lda #X_ACK
			jsr acia_putc
			jsr xflush

    		sec
			rts
.endproc

.proc xcrc_update
	eor crc+1
	tax
	lda crc
	eor CRCHI,x
	sta crc+1
	lda CRCLO,x
	sta crc
	rts
.endproc

.proc xflush
:	lda #$70
	sta retry2
	jsr xget_byte
	bcs :-
	rts
.endproc

.proc xget_byte
	lda #0
	sta retry1
:	jsr acia_getc
	bcs :+
	dec retry1
	bne :-
	dec retry2
	bne :-
	clc
:	rts
.endproc


.proc acia_getc
	clc
	lda ACIA_STATUS
	and #$08
	beq :+
	lda ACIA_DATA
	sec
:	rts
.endproc

.proc acia_putc
	phx
	ldx #$68
:	dex
	bne :-
	plx
	sta ACIA_DATA
	rts
.endproc


.rodata
CRCLO:
	.byte $00,$21,$42,$63,$84,$A5,$C6,$E7,$08,$29,$4A,$6B,$8C,$AD,$CE,$EF
	.byte $31,$10,$73,$52,$B5,$94,$F7,$D6,$39,$18,$7B,$5A,$BD,$9C,$FF,$DE
	.byte $62,$43,$20,$01,$E6,$C7,$A4,$85,$6A,$4B,$28,$09,$EE,$CF,$AC,$8D
	.byte $53,$72,$11,$30,$D7,$F6,$95,$B4,$5B,$7A,$19,$38,$DF,$FE,$9D,$BC
	.byte $C4,$E5,$86,$A7,$40,$61,$02,$23,$CC,$ED,$8E,$AF,$48,$69,$0A,$2B
	.byte $F5,$D4,$B7,$96,$71,$50,$33,$12,$FD,$DC,$BF,$9E,$79,$58,$3B,$1A
	.byte $A6,$87,$E4,$C5,$22,$03,$60,$41,$AE,$8F,$EC,$CD,$2A,$0B,$68,$49
	.byte $97,$B6,$D5,$F4,$13,$32,$51,$70,$9F,$BE,$DD,$FC,$1B,$3A,$59,$78
	.byte $88,$A9,$CA,$EB,$0C,$2D,$4E,$6F,$80,$A1,$C2,$E3,$04,$25,$46,$67
	.byte $B9,$98,$FB,$DA,$3D,$1C,$7F,$5E,$B1,$90,$F3,$D2,$35,$14,$77,$56
	.byte $EA,$CB,$A8,$89,$6E,$4F,$2C,$0D,$E2,$C3,$A0,$81,$66,$47,$24,$05
	.byte $DB,$FA,$99,$B8,$5F,$7E,$1D,$3C,$D3,$F2,$91,$B0,$57,$76,$15,$34
	.byte $4C,$6D,$0E,$2F,$C8,$E9,$8A,$AB,$44,$65,$06,$27,$C0,$E1,$82,$A3
	.byte $7D,$5C,$3F,$1E,$F9,$D8,$BB,$9A,$75,$54,$37,$16,$F1,$D0,$B3,$92
	.byte $2E,$0F,$6C,$4D,$AA,$8B,$E8,$C9,$26,$07,$64,$45,$A2,$83,$E0,$C1
	.byte $1F,$3E,$5D,$7C,$9B,$BA,$D9,$F8,$17,$36,$55,$74,$93,$B2,$D1,$F0 

CRCHI:
	.byte $00,$10,$20,$30,$40,$50,$60,$70,$81,$91,$A1,$B1,$C1,$D1,$E1,$F1
	.byte $12,$02,$32,$22,$52,$42,$72,$62,$93,$83,$B3,$A3,$D3,$C3,$F3,$E3
	.byte $24,$34,$04,$14,$64,$74,$44,$54,$A5,$B5,$85,$95,$E5,$F5,$C5,$D5
	.byte $36,$26,$16,$06,$76,$66,$56,$46,$B7,$A7,$97,$87,$F7,$E7,$D7,$C7
	.byte $48,$58,$68,$78,$08,$18,$28,$38,$C9,$D9,$E9,$F9,$89,$99,$A9,$B9
	.byte $5A,$4A,$7A,$6A,$1A,$0A,$3A,$2A,$DB,$CB,$FB,$EB,$9B,$8B,$BB,$AB
	.byte $6C,$7C,$4C,$5C,$2C,$3C,$0C,$1C,$ED,$FD,$CD,$DD,$AD,$BD,$8D,$9D
	.byte $7E,$6E,$5E,$4E,$3E,$2E,$1E,$0E,$FF,$EF,$DF,$CF,$BF,$AF,$9F,$8F
	.byte $91,$81,$B1,$A1,$D1,$C1,$F1,$E1,$10,$00,$30,$20,$50,$40,$70,$60
	.byte $83,$93,$A3,$B3,$C3,$D3,$E3,$F3,$02,$12,$22,$32,$42,$52,$62,$72
	.byte $B5,$A5,$95,$85,$F5,$E5,$D5,$C5,$34,$24,$14,$04,$74,$64,$54,$44
	.byte $A7,$B7,$87,$97,$E7,$F7,$C7,$D7,$26,$36,$06,$16,$66,$76,$46,$56
	.byte $D9,$C9,$F9,$E9,$99,$89,$B9,$A9,$58,$48,$78,$68,$18,$08,$38,$28
	.byte $CB,$DB,$EB,$FB,$8B,$9B,$AB,$BB,$4A,$5A,$6A,$7A,$0A,$1A,$2A,$3A
	.byte $FD,$ED,$DD,$CD,$BD,$AD,$9D,$8D,$7C,$6C,$5C,$4C,$3C,$2C,$1C,$0C
	.byte $EF,$FF,$CF,$DF,$AF,$BF,$8F,$9F,$6E,$7E,$4E,$5E,$2E,$3E,$0E,$1E