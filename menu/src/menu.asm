.ZILOG
.BIOS

.org #4760

	; --- MSXnano M1 ---------------------------------------------------------
	; The cartridge INIT used to only enter the config menu while the 'G' key
	; was held; otherwise it 'ret'urned and the normal MSX boot continued.
	; For M1 we ALWAYS enter: decompress the menu code to #8000 and jump into
	; it. The new main menu (option "1. Arrancar sistema") restores the stack
	; and 'ret's back to the BIOS, reproducing the original "continue boot"
	; behaviour. The old G-key gate is kept commented for reference.
	; ------------------------------------------------------------------------
	;di
	;ld   a, ROW_G					; Select keyboard matrix row of "G"
	;out  (PPIC), a
	;in   a, (PPIB)
	;bit  COL_G, a
	;ei
	;ret  nz						; G not pressed -> continue normal boot

	ld   hl, compressed_code
	ld   de, menu_main
	push de

decompressor:
;	.include "../src/dzx7mini.asm"
	.include "../src/dzx0_standard.asm"


; -----------------------------------------------------------------------------
; Compressed main menu code:
; -----------------------------------------------------------------------------
compressed_code:
;	.incbin "menu_main.zx7"
	.incbin "menu_main.zx0"

menu_main equ #8000

PPIB    equ  0xA9
PPIC    equ  0xAA

ROW_G   equ  0xF3

; Columna de “G” en puerto A → bit4 (Eje: 0=A/S/D/F/G → columna 4)
COL_G   equ  4