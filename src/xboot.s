.include "io.inc"


.segment "VECTORS"
.word nmi
.word reset
.word irq


.zeropage
ptr1: .res 2


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


loop:
	bra loop
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

.proc acia_getc
:	lda ACIA_STATUS
    and #$08
    beq :-
    lda ACIA_DATA
    rts
.endproc

.proc acia_puts
	pha
:	lda (ptr1)
	beq :+
	jsr acia_putc
	inc16 ptr1
	bra :-
:	pla
	rts
.endproc


.rodata
msg: .byte "Hello, World!", 10, 0