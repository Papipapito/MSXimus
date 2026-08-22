.ZILOG
.BIOS
.BIOSVARS

ENABLE_SDCARD=1
MSXIMUS=1				; 1 = build MSXimus/Console 60K: sprites 8/linea en bit3 y 16:9 en bit4
ENABLE_MEGARAM=1

; (aliases de structs Enable* eliminados: mapper/megaram/SD van siempre ON)

.org #8000

; #############################################################################
; ##  MSXnano MAIN MENU (Picoverse-style boot menu) - added for M1
; #############################################################################
; This is now the entry point reached after the FM logo (menu.asm decompresses
; this code to #8000 and jumps here). It shows a main menu with 4 options and,
; when "Arrancar sistema" is chosen, returns to the BIOS so the normal MSX boot
; continues (chain to Nextor/MSX-DOS exactly as it would without a cartridge
; INIT taking over).
;
; STACK NOTE: when execution arrives at #8000 the top of the stack is the
; return address into the BIOS boot routine (the original caller of the
; cartridge INIT at #4760). We save SP here so "Arrancar sistema" can restore
; it and 'ret' cleanly back into the BIOS boot flow.

main_menu_entry:
	; Save the BIOS cartridge-INIT return context. At this point SP points at the
	; BIOS return address (the decompressor's final 'ret' consumed the pushed
	; #8000, leaving the BIOS return on top). We store SP in PAGE-3 RAM (#E000),
	; which does NOT remap like page 2, so "Arrancar sistema" can restore the exact
	; SP and 'ret' reliably even if the menu's stack ends up unbalanced for any
	; reason (this is more robust than relying on perfectly balanced calls).
	ld   (BOOT_SP), sp
	pop  hl							; top of stack = BIOS boot return address
	push hl
	ld   (BOOT_RET), hl				; save it: the WiFi ESP ROM may clobber the stack
	; The goauld BIOS boot calls this cartridge INIT a SECOND time before it
	; finally boots the disk. "Arrancar sistema" sets BOOT_FLAG and rets; on the
	; re-run we see the flag and ret again WITHOUT showing the browser, so a
	; single ESC boots (otherwise it took two: logo + browser reappear, then boot).
	ld   a, (BOOT_FLAG)
	ld   b, a
	xor  a
	ld   (BOOT_FLAG), a				; the flag is only valid transiently
	ld   a, b
	cp   #99
	jp   z, second_pass_boot		; pending boot -> continue the boot, skip the menu
	; (el registro Nextor de #A000 lo cubre el padding del .org #A010: el depack
	; del menu escribe esa zona en cada arranque y borra cualquier firma rancia)
	ld   a, #C9						; limpiar un hook H.STKE residual de un juego
	ld   hl, #FEDA					; lanzado antes (si no, "Arrancar sistema" tras un
	ld   b, 5						; reset manual relanzaria el juego en vez del DOS)
.wipe_stke:
	ld   (hl), a
	inc  hl
	djnz .wipe_stke
	xor  a
	ld   (DSK_PEND), a				; sin .dsk pendiente: el 2o pase NO debe reescribir
	ld   (FH_MODE), a				; File-Hunter off (en frio la RAM es basura)
									; el registro NEXTOR (en frio #C0DD es basura y
									; emulaba un disco inexistente -> caia a BASIC)
	; pantalla de logo (slot 0-3): si el pack la trae (magic 'L'), mostrarla
	ld   a, #8C						; slot 0-3 (expandido, pri 0, sec 3)
	ld   hl, #4000
	call RDSLT
	cp   'L'
	jr   nz, .no_logo
	rst  #30						; CALLF a la rutina del logo (SCREEN5, ~0.5s)
	.db  #8C
	.dw  #4002
.no_logo:
	; premontar la SD BAJO el logo (montaje silencioso): si va bien, el
	; navegador se salta el "Leyendo SD..." y aparece ya con contenido
	ld   a, 2						; FILTER = ALL ANTES de escanear: select_partition
	ld   (FILTER), a				; -> scan_root aplica FILTER; en frio era basura y
									; filtraba los ficheros (solo se veian carpetas
									; en el primer listado hasta cambiar de pestana)
	xor  a
	ld   (SD_READY), a
	ld   (SD_LBA+0), a
	ld   (SD_LBA+1), a
	ld   (SD_LBA+2), a
	ld   (SD_LBA+3), a
	call sd_read_sector				; MBR
	ld   a, (SD_STATUS)
	or   a
	jr   nz, .pm_done
	ld   a, (SD_BUF+510)
	cp   #55
	jr   nz, .pm_done
	ld   a, (SD_BUF+511)
	cp   #AA
	jr   nz, .pm_done
	call enum_partitions
	ld   a, (PART_CNT)
	or   a
	jr   z, .pm_done
	xor  a
	call select_partition
	jr   c, .pm_done
	ld   a, 1
	ld   (SD_READY), a
	ld   de, 2						; ~1s extra de logo con la SD ya lista
.pm_w1:
	ld   bc, 0
.pm_w2:
	dec  bc
	ld   a, b
	or   c
	jr   nz, .pm_w2
	dec  de
	ld   a, d
	or   e
	jr   nz, .pm_w1
.pm_done:
	call restore_palette			; restaurar la paleta de fabrica AL SALIR del
									; logo (no mientras sigue en pantalla)
	ld   a, 2
	ld   (FILTER), a				; default tab = ALL

	; --- v1.9: warn if the bitstream (.fs) and BIOS pack (.bin) versions differ ---
	; e.g. someone flashed a v1.8 .fs with a v1.7 .bin. Port 0x2F returns the FPGA
	; version (0x1X); 0xFF = a pre-v1.9 bitstream with no version port. First boot only.
	in   a, (#2F)
	cp   #30						; this pack's version (v3.0)
	call nz, version_warning

; Re-entry point used by the placeholders (M2/M3): re-init the screen and
; redraw WITHOUT re-capturing the BIOS context (which is only valid on the
; very first entry from the cartridge INIT).
main_menu_restart:
	xor  a
	ld   (BROWSING), a				; leaving the browser: stop marquee animation
	call init_screen				; Reuse screen/blink init (shared routine)
	; UNIFIED UI (Picoverse-style): the SD browser IS the home screen. Boot and
	; every "return to menu" land here. ESC in the browser = boot the system,
	; 'A' = settings. The old 4-option menu below is kept but no longer reached.
	jp   main_action_sdrom

; --- v1.9 version-mismatch warning (bitstream .fs vs BIOS pack .bin) ---------
; A = FPGA version read from port 0x2F (mismatched). Shows a warning on SCREEN 1
; and holds ~3s with a busy loop (no keyboard/IRQ needed, so it works even if the
; USB keyboard is dead), then returns and the menu continues.
version_warning:
	ld   c, a						; C = FPGA/bitstream version
	ld   a, 1
	call #005F						; CHGMOD -> SCREEN 1 (clears)
	ld   hl, ver_msg1
	call ver_puts
	ld   a, c
	call ver_pnib					; print bitstream version "M.m"
	ld   hl, ver_msg2
	call ver_puts
	ld   a, #30						; this pack's version
	call ver_pnib
	ld   hl, ver_msg3
	call ver_puts
	ld   de, 6						; hold ~3s
.vw1:
	ld   bc, 0
.vw2:
	dec  bc
	ld   a, b
	or   c
	jr   nz, .vw2
	dec  de
	ld   a, d
	or   e
	jr   nz, .vw1
	ret
ver_puts:							; HL -> zero-terminated string, print via CHPUT
	ld   a, (hl)
	or   a
	ret  z
	call #00A2
	inc  hl
	jr   ver_puts
ver_pnib:							; A = version byte -> "M.m" (hex nibbles)
	push af
	rrca
	rrca
	rrca
	rrca
	call ver_hex1
	ld   a, '.'
	call #00A2
	pop  af
	call ver_hex1
	ret
ver_hex1:
	and  #0F
	cp   10
	jr   c, .vh
	add  a, 7
.vh:
	add  a, '0'
	call #00A2
	ret
IF MSXIMUS
ver_msg1:	.db 13,10,10,"  MSXimus: VERSION MISMATCH",13,10,10,"  Bitstream (.fs): ",0
ELSE
ver_msg1:	.db 13,10,10,"  MSXnano: VERSION MISMATCH",13,10,10,"  Bitstream (.fs): ",0
ENDIF
ver_msg2:	.db 13,10,"  BIOS pack (.bin): ",0
IF MSXIMUS
ver_msg3:	.db 13,10,10,"  Flash the .fs and .bin from",13,10,"  the SAME MSXimus version.",0
ELSE
ver_msg3:	.db 13,10,10,"  Flash the .fs and .bin from",13,10,"  the SAME MSXnano version.",0
ENDIF

; --- Option 1: continue the normal MSX boot ---------------------------------
; Behaves EXACTLY like the proven "Save & Exit" of the config menu (known to
; continue the boot on real Goa'uld hardware): clean up the screen and 'ret'
; through the NATURAL, LIVE stack back to the BIOS cartridge-INIT caller, which
; chains to Nextor / MSX-DOS.
;
; ROOT CAUSE of the previous reset (found by debugger): a previous version
; saved SP + the BIOS return address into page-2 RAM variables at entry and
; restored them here. But on the Goa'uld the page-2 (0x8000-0xBFFF) slot/segment
; mapping is NOT guaranteed to be the same when the menu first runs and when an
; option is later selected, so those variables read back as GARBAGE -> "ld sp,
; garbage" + "ret" jumped to a random address -> CPU reset/loop. The fix is to
; never rely on page-2 stored state: the LIVE stack (page-3 RAM) still holds the
; BIOS return address on top here (the menu's calls are balanced), so a plain
; 'ret' returns correctly regardless of any page-2 remapping.
; boot_system: user chose "arrancar sistema". Mark a pending-boot flag (so the
; BIOS's second INIT pass auto-continues instead of showing the browser again)
; and continue the boot.
; second_pass_boot: 2o pase del INIT con boot pendiente. Si hay un .dsk
; seleccionado, REESCRIBIR el registro NEXTOR_EMU_DATA (#A000-#A015): el
; re-depack de este mismo pase acaba de machacarlo (los datos del menu viven
; en #A010+ desde el reorg y el padding cubre #A000-#A00F a proposito).
second_pass_boot:
	ld   a, (DSK_PEND)
	or   a
	jp   z, main_action_boot
	xor  a
	ld   (DSK_PEND), a
	ld   hl, emuSig
	ld   de, #A000
	ld   bc, 16
	ldir
	ld   a, 1
	ld   (#A010), a					; device index (WonderTANG SD)
	ld   a, 1
	ld   (#A011), a					; LUN
	ld   hl, (EMU_LBA+0)
	ld   (#A012), hl
	ld   hl, (EMU_LBA+2)
	ld   (#A014), hl
	jp   main_action_boot

boot_system:
	ld   a, #99
	ld   (BOOT_FLAG), a
	; fall through to main_action_boot

main_action_boot:
	di
	call INITXT						; clear screen (SCREEN 0) before handing back
	ld   bc, #000d					; turn blink mode off (restore normal text)
	call WRTVDP
	ld   sp, (BOOT_SP)				; restore the exact BIOS-INIT SP saved at entry
	ld   hl, (BOOT_RET)				; re-supply the BIOS return address in case the
	ex   (sp), hl					; WiFi ESP ROM clobbered that stack slot
	ei
	ret								; return into BIOS boot -> normal boot continues

; --- Option 2: Lanzar ROM de la SD -------------------------------------------
; M2.1 derisk: prove the boot menu itself can read a raw SD sector through the
; WonderTANG window BEFORE the OS boots. Menu code runs at #8000 (page 2); the
; SD register window is at #7C00-#7EFF in PAGE 1, slot 3-2. We switch page 1 to
; slot 3-2 only around the access, read sector 0, restore page 1 to slot 3-1.
; The sector buffer + scratch live at FIXED PAGE-3 RAM addresses (NOT reserved
; inside the menu image with 'ds', which would inflate the decompressed image).
SD_LBA		equ	#C000			; 4 bytes: LBA to read (page-3 RAM scratch)
SD_CTYPE	equ	#C004			; 1 byte: card type read back
SD_STATUS	equ	#C005			; 1 byte: 0=OK, 1=init timeout, 2=read timeout
part_type	equ	#C006			; 1 byte: MBR partition 1 type
PART_LBA	equ	#C008			; 4 bytes: partition start LBA (FAT16 volume)
ROOT_LBA	equ	#C00C			; 4 bytes: root directory start LBA
disp_row	equ	#C010			; 1 byte: current display row
sec_left	equ	#C011			; 1 byte: root-dir sectors remaining
ent_in_sec	equ	#C01F			; 1 byte: dir entries left in current sector
name83		equ	#C012			; 13 bytes: formatted 8.3 name (ASCIIZ)
ENT_COUNT	equ	#C020			; 1 byte: number of entries scanned
BR_SEL		equ	#C021			; 1 byte: selected entry index
BR_TOP		equ	#C022			; 1 byte: first visible entry index
BR_TMP		equ	#C023			; 1 byte: scratch (draw_entry)
BR_TMP2		equ	#C024			; 1 byte: scratch (draw_browser loop index)
BR_REC		equ	#C025			; 2 bytes: scratch record pointer
ARR_PTR		equ	#C027			; 2 bytes: array write pointer (scan)
BR_OLD		equ	#C029			; 1 byte: previously-selected index (partial repaint)
BR_OLDTOP	equ	#C02A			; 1 byte: BR_TOP before ensure_visible (scroll detect)
ENT_ARRAY	equ	#C300			; entry array: ENT_SIZE bytes each (type,cluster,name)
ENT_SIZE	equ	80				; record: type(1)+cluster(2)+size(4)+name(73 ASCIIZ)
NAME_OFF	equ	9				; name offset inside a record (type1+cluster4+size4)
SIZE_OFF	equ	5				; file-size dword offset inside a record
NAME_MAX	equ	70				; max name chars stored (+ NUL) -> longer than the
								; 59-col window so long names overflow and marquee-scroll
NAME_WIN	equ	59				; name display window width (cols 9..67, size at 69)
VISIBLE		equ	18				; entries per page (list rows 4..21; hdr 1, tabs 2, line 3, sep 22, footer 23)
MAX_ENT		equ	115				; array capacity (115*80 = 9200 bytes -> C300..E6F0)
HAVE_LFN	equ	#C02B			; 1 byte: a long-file-name is being accumulated
LFN_BUF		equ	#C02C			; 80 bytes: assembled long file name (C02C..C07B)
DIR_SP		equ	#C07E			; 1 byte: folder back-stack depth
DATA_LBA	equ	#C090			; 4 bytes: FAT data region start LBA
SEC_PER_CLUS equ #C094			; 1 byte: sectors per cluster
ROOT_SECS	equ	#C095			; 1 byte: root-directory sector count
JOY_PREV	equ	#C096			; 1 byte: previous joystick code (edge detect)
FAT_LBA		equ	#C097			; 4 bytes: FAT table start LBA
CHAIN_CNT	equ	#C09D			; 2 bytes: file cluster-chain length
BOOT_SP		equ	#C0B0			; 2 bytes: saved BIOS cartridge-INIT SP (page-3, stable)
MQ_OFF		equ	#C0B2			; 1 byte: marquee scroll offset of the selected name
MQ_SEL		equ	#C0B3			; 1 byte: entry index currently being marquee-scrolled
MQ_TICK		equ	#C0B4			; 1 byte: marquee frame counter
BROWSING	equ	#C0B5			; 1 byte: 1 while inside the SD browser (gate marquee)
MAP_SCC		equ	#C0B6			; 2 bytes: Konami-SCC bank-write count
MAP_KON		equ	#C0B8			; 2 bytes: Konami bank-write count
MAP_A8		equ	#C0BA			; 2 bytes: ASCII8 bank-write count
MAP_A16		equ	#C0BC			; 2 bytes: ASCII16 bank-write count
SSEC_LEFT	equ	#C0C0			; 1 byte: sectors left in current cluster (scan)
SCAN_N		equ	#C0C1			; 2 bytes: sectors scanned so far
MAPPER_ID	equ	#C0C3			; 1 byte: detected mapper id
MEG_T0		equ	#C0C4			; 1 byte: megaram write-test readback byte 0
MEG_T1		equ	#C0C5			; 1 byte: megaram write-test readback byte 1
MEG_P42		equ	#C0C6			; 1 byte: SWIO port 0x42 readback (Slot2Mode in bits 4,5)
MEG_B0		equ	#C0C7			; 1 byte: megaram byte 0 BEFORE the write
LOAD_SEG	equ	#C0C8			; 1 byte: current 8K megaram segment being loaded
LOAD_OFF	equ	#C0C9			; 2 bytes: byte offset within the current 8K segment
MEG_RB		equ	#C0CD			; 8 bytes: megaram readback scratch (load verify)
SRCH_BUF	equ	#E880			; 13 bytes: consulta de busqueda del navegador (ASCIIZ)
SRAM_FLAG	equ	#C0D9			; 1 byte: SRAM de cartucho para este lanzamiento (0/1)
P2_SLOT		equ	#C0DA			; 1 byte: slot de la pag.2 al llamar al INIT (v2.0.1
									; caso Aleste2: la BIOS real deja RAM en 0x8000;
									; #02=megaram solo para ROMs lineales MAP_PLAIN)
SD_READY	equ	#C0DB			; 1 byte: SD ya montada+escaneada (bajo el logo)
MAP_SWIO	equ	#C0DC			; 1 byte: smart command del mapper (lo aplica el stub)
DSK_PEND	equ	#C0DD			; 1 byte: registro .dsk pendiente de reescribir (2o pase)
TW_LOAD		equ	#C0DE			; 1 byte: loadcmd de la cinta web (0=RUN 1=BLOAD 2=?)
NEEDLE		equ	#C0D5			; 2 bytes: substring search needle pointer (tag scan)
TAGPTR		equ	#C0D7			; 2 bytes: haystack (filename) pointer (tag scan)
PE_PTR		equ	#C0D9			; 2 bytes: MBR partition-entry pointer (dump diag)
PE_ROW		equ	#C0DB			; 1 byte: partition dump display row
PE_DW		equ	#C0DC			; 4 bytes: 32-bit value scratch for hex print
DSK_LBA		equ	#C0E0			; 4 bytes: abs LBA of the selected .dsk first sector
DSK_SECS	equ	#C0E4			; 2 bytes: .dsk size in 512-byte sectors
EMU_LBA		equ	#C0E6			; 4 bytes: abs LBA of the NEXTOR.EMU data file sector
FAT_SZ		equ	#C0EA			; 2 bytes: sectors per FAT (FATSz16 o FATSz32 low16)
NUM_FATS	equ	#C0EC			; 1 byte: number of FAT copies
NEW_CLUS	equ	#C0ED			; 2 bytes: cluster allocated for a new NEXTOR.EMU (FAT16 path)
; --- FAT32: clusters anchos (4 bytes LE) en pagina-3 alta, zona libre #E840+ ---
CUR_CLUS	equ	#E840			; 4 bytes: current directory cluster (FAT16: 0 = root)
SCAN_CLUS	equ	#E844			; 4 bytes: cluster being scanned (dir chain walk)
FILE_CLUS	equ	#E848			; 4 bytes: selected file's first cluster
LOAD_CLUS	equ	#E84C			; 4 bytes: cluster being loaded (ROM chain walk)
W_TMP		equ	#E850			; 4 bytes: wide-cluster scratch (fatnext/clus2lba)
W_SAVE		equ	#E854			; 4 bytes: CUR_CLUS save/restore (scan_rom/load_rom)
FS32		equ	#E858			; 1 byte: 0 = FAT16, 1 = FAT32 (per selected partition)
SPC_SHIFT	equ	#E859			; 1 byte: log2(SEC_PER_CLUS)
ROOT_CLUS	equ	#E85C			; 4 bytes: FAT32 root directory first cluster
DIR_STACK	equ	#E860			; 8 x 4 bytes: parent-cluster back stack (#E860..#E87F)
FFC_BASE	equ	#C0EF			; 2 bytes: base cluster of the FAT sector being scanned
FFC_LEFT	equ	#C0F1			; 2 bytes: FAT sectors left to scan
MCE_OFF		equ	#C0F3			; 2 bytes: byte offset of the FAT entry within its sector
WDE_LEFT	equ	#C0F5			; 1 byte: root-dir sectors left to scan
MCE_SEC		equ	#C0F6			; 1 byte: FAT sector offset of the cluster entry
BR_BLINK	equ	#C0F7			; 1 byte: per-row blink-attr fill byte (dir colour)
FILTER		equ	#C0F8			; 1 byte: active tab filter (0=ROM, 1=DSK, 2=ALL)
FH_DFERR	equ	#C0F9			; 1 byte: fh2_dfind no pudo LEER (su CF=1 no es fiable)
; --- multi-partition support (placed at #E800, above ENT_ARRAY C300..E700) ---
MAX_PARTS	equ	8
PART_TBL	equ	#E800			; up to 8 entries x 4 bytes = start LBA of each FAT16 partition
PART_CNT	equ	#E820			; 1 byte: number of partitions found
EXT_BASE	equ	#E821			; 4 bytes: extended-partition base LBA (0 = none)
CUR_PART	equ	#E825			; 1 byte: currently-selected partition index
EBR_CUR		equ	#E826			; 4 bytes: current EBR LBA while walking the chain
ADD_TMP		equ	#E82A			; 4 bytes: 32-bit add scratch
BOOT_RET	equ	#E82E			; 2 bytes: saved BIOS boot return address (survives WiFi ROM)
BOOT_FLAG	equ	#E830			; 1 byte: 0x99 = boot pending (skip menu on BIOS 2nd INIT pass)
CLK_STR		equ	#E831			; 9 bytes: "HH:MM:SS" + 0 (header clock)
CLK_LAST	equ	#E83A			; 1 byte: last seconds-units digit (clock change detect)
JOY_RPT		equ	#E83B			; 1 byte: joystick auto-repeat frame counter
BAR_FRAC	equ	#E83C			; 2 bytes: acumulador Bresenham de la barra de carga
BAR_TOT		equ	#E83E			; 2 bytes: total de segmentos 8K de la ROM (escala barra)
BAR_CNT		equ	#E85A			; 1 byte: celdas pintadas de la barra (tope fisico 64)
JOY_RPT_DELAY equ 14			; frames before a held stick starts repeating
JOY_RPT_RATE  equ 2				; frames between repeats (lower = faster)
RAM_SLOT_30	equ	#83				; ENASLT id: expandido, primario 3, secundario 0 (RAM mapeada)
MEG_SLOT	equ	#02				; primary slot 2 (the OCM relocates the megaram here
								; when Slot2Mode is set via the SWIO smart command)
; mapper ids
MAP_PLAIN	equ	0
MAP_KON_ID	equ	2
MAP_SCC_ID	equ	3
MAP_A8_ID	equ	4
MAP_A16_ID	equ	5
MAP_UNK		equ	6
MAP_THRESH	equ	2				; min bank-writes to accept a mapper signature
SD_BUF		equ	#C100			; 512 bytes: sector transfer buffer
SD_SLOT_32	equ	#8B			; ENASLT slot id: expanded, primary 3, secondary 2 (SD)
SD_SLOT_31	equ	#87			; ENASLT slot id: expanded, primary 3, secondary 1 (menu)
SDC_SDATA	equ	#7C00			; 512-byte sector transfer window
SDC_ENABLE	equ	#7E00			; wo: bit0 = enable SDC register block
SDC_CMD		equ	#7E01			; wo: bit0=read
SDC_STATUS	equ	#7E02			; ro: bit7=busy bit1=timeout bit0=bloque RECHAZADO
SDC_SADDR	equ	#7E03			; wo: 4 bytes = LBA
SDC_CTYPE	equ	#7E0C			; ro: card type

main_action_sdrom:
	ld   a, (SD_READY)
	or   a
	jp   nz, browse					; montada bajo el logo -> navegador directo
	call cls_browser				; show feedback (the SD init can pause a moment)
	ld   hl, #0103
	call POSIT
	ld   hl, readingStr				; "Leyendo SD..."
	call print_string
	; --- read sector 0 (MBR with partition table) ---
	xor  a
	ld   (SD_LBA+0), a
	ld   (SD_LBA+1), a
	ld   (SD_LBA+2), a
	ld   (SD_LBA+3), a
	call sd_read_sector
	; --- SD-present check: if the init/read timed out (no card, or not the SD
	;     window) bail out cleanly instead of parsing garbage and hanging ---
	ld   a, (SD_STATUS)
	or   a
	jp   nz, sd_not_present
	ld   a, (SD_BUF+510)			; MBR boot signature must be 0x55 0xAA
	cp   #55
	jp   nz, sd_not_present
	ld   a, (SD_BUF+511)
	cp   #AA
	jp   nz, sd_not_present
	; --- enumerate ALL FAT16 partitions (4 primaries + extended-chain logicals) ---
	call enum_partitions
	ld   a, (PART_CNT)
	or   a
	jp   z, sd_not_present			; no readable FAT16 partition
	xor  a
	call select_partition			; open partition 0 (reads BPB, computes root, scans;
	jp   c, sd_not_present			; sets BR_SEL/BR_TOP/MQ_SEL/BROWSING)
	ld   a, 1
	ld   (SD_READY), a				; las vueltas desde ajustes ya no re-montan
	jp   browse						; scrolling browser (returns to menu on ESC)

; sd_not_present: no usable SD card (init/read timeout or bad MBR signature).
; In the unified UI the browser is the home screen, so DON'T loop back to it
; (that would re-read the SD and bounce here forever). Offer the global actions.
sd_not_present:
	call cls_browser
	ld   hl, #0103
	call POSIT
	ld   hl, noSdStr
	call print_string
	ld   hl, #0105
	call POSIT
	ld   hl, noSdStr2
	call print_string
.snp_key:
	call browse_getkey
	cp   #0D						; RETURN -> arrancar sistema
	jp   z, boot_system
	cp   #1B						; ESC -> arrancar sistema
	jp   z, boot_system
	cp   #53						; 'S' -> Settings (Ajustes)
	jp   z, config_menu_entry
	cp   #73						; 's'
	jp   z, config_menu_entry
	cp   #57						; 'W' -> WiFi config
	jp   z, main_action_wifi
	cp   #77						; 'w'
	jp   z, main_action_wifi
	cp   #54						; 'T' -> Cinta web (TSX streaming)
	jp   z, main_action_tsxweb
	cp   #74						; 't'
	jp   z, main_action_tsxweb
	cp   #46						; 'F' -> File-Hunter (buscar y listar online)
	jp   z, fh_browse
	cp   #66						; 'f'
	jp   z, fh_browse
	jr   .snp_key

; =====================================================================
; Multi-partition support
; =====================================================================
; is_fat16: A = MBR/EBR partition type byte. CF=1 if it is a FAT12/16/32 type
; we can browse (0x01/0x04/0x06/0x0E FAT16, 0x0B/0x0C FAT32). CF=0 otherwise.
is_fat16:
	cp   #01
	jr   z, .if_yes
	cp   #04
	jr   z, .if_yes
	cp   #06
	jr   z, .if_yes
	cp   #0E
	jr   z, .if_yes
	cp   #0B						; FAT32 CHS
	jr   z, .if_yes
	cp   #0C						; FAT32 LBA
	jr   z, .if_yes
	or   a							; CF = 0
	ret
.if_yes:
	scf
	ret

; add_partition_at: HL = ptr to a 4-byte start LBA. Append it to PART_TBL if room.
add_partition_at:
	ld   a, (PART_CNT)
	cp   MAX_PARTS
	ret  nc							; table full -> ignore
	push hl							; src
	ld   l, a						; dest = PART_TBL + cnt*4
	ld   h, 0
	add  hl, hl						; *2
	add  hl, hl						; *4
	ld   de, PART_TBL
	add  hl, de
	ex   de, hl						; DE = dest
	pop  hl							; HL = src
	ld   bc, 4
	ldir
	ld   a, (PART_CNT)
	inc  a
	ld   (PART_CNT), a
	ret

; set_add_tmp: HL = ptr to 4-byte value -> ADD_TMP = value.
set_add_tmp:
	ld   de, ADD_TMP
	ld   bc, 4
	ldir
	ret

; add_to_tmp: HL = ptr to 4-byte addend -> ADD_TMP += (HL), 32-bit.
add_to_tmp:
	or   a							; clear carry
	ld   de, ADD_TMP
	ld   b, 4
.att_loop:
	ld   a, (de)
	adc  a, (hl)
	ld   (de), a
	inc  de
	inc  hl
	djnz .att_loop
	ret

; enum_partitions: SD_BUF holds the MBR. Fill PART_TBL / PART_CNT with every
; FAT16 partition: the 4 primary entries, plus the logical drives inside an
; extended partition (type 0x05/0x0F) by walking its EBR chain.
enum_partitions:
	xor  a
	ld   (PART_CNT), a
	ld   (EXT_BASE+0), a
	ld   (EXT_BASE+1), a
	ld   (EXT_BASE+2), a
	ld   (EXT_BASE+3), a
	ld   hl, SD_BUF + 446			; first primary entry
	ld   b, 4
.ep_pri:
	push bc
	push hl
	ld   de, 4
	add  hl, de						; HL -> type byte
	ld   a, (hl)
	cp   #05
	jr   z, .ep_ext
	cp   #0F
	jr   z, .ep_ext
	call is_fat16
	jr   nc, .ep_pnext
	pop  hl							; HL = entry base
	push hl
	ld   de, 8
	add  hl, de						; HL -> start LBA
	call add_partition_at
	jr   .ep_pnext
.ep_ext:
	pop  hl							; HL = entry base
	push hl
	ld   de, 8
	add  hl, de						; HL -> extended start LBA
	ld   de, EXT_BASE
	ld   bc, 4
	ldir							; EXT_BASE = this entry's start LBA
.ep_pnext:
	pop  hl							; HL = entry base
	ld   de, 16
	add  hl, de						; next primary entry
	pop  bc
	djnz .ep_pri
	; --- walk the extended chain, if any ---
	ld   a, (EXT_BASE+0)
	ld   hl, EXT_BASE+1
	or   (hl)
	inc  hl
	or   (hl)
	inc  hl
	or   (hl)
	ret  z							; EXT_BASE == 0 -> no extended partition
	ld   hl, EXT_BASE				; EBR_CUR = EXT_BASE
	ld   de, EBR_CUR
	ld   bc, 4
	ldir
	ld   b, MAX_PARTS				; bound the chain length
.ep_walk:
	push bc
	ld   hl, EBR_CUR				; SD_LBA = EBR_CUR
	ld   de, SD_LBA
	ld   bc, 4
	ldir
	call sd_read_sector
	ld   a, (SD_STATUS)
	or   a
	jr   nz, .ep_wend				; read error -> stop
	ld   a, (SD_BUF + 450)			; EBR entry0 type
	call is_fat16
	jr   nc, .ep_link				; not FAT16 -> skip recording
	ld   hl, EBR_CUR				; logical LBA = EBR_CUR + entry0.rel_start
	call set_add_tmp
	ld   hl, SD_BUF + 454
	call add_to_tmp
	ld   hl, ADD_TMP
	call add_partition_at
.ep_link:
	ld   a, (SD_BUF + 466)			; EBR entry1 type (link to next EBR)
	or   a
	jr   z, .ep_wend				; empty -> end of chain
	ld   hl, EXT_BASE				; next EBR = EXT_BASE + entry1.rel_start
	call set_add_tmp
	ld   hl, SD_BUF + 470
	call add_to_tmp
	ld   hl, ADD_TMP
	ld   de, EBR_CUR
	ld   bc, 4
	ldir
	pop  bc
	djnz .ep_walk
	ret
.ep_wend:
	pop  bc
	ret

; select_partition: A = partition index. Set PART_LBA from PART_TBL, read its
; boot sector (BPB), compute the root dir and scan it. Also (re)inits the browser
; selection/marquee. Returns CF=1 on SD error, CF=0 on success.
select_partition:
	ld   (CUR_PART), a
	ld   l, a						; src = PART_TBL + idx*4
	ld   h, 0
	add  hl, hl
	add  hl, hl
	ld   de, PART_TBL
	add  hl, de
	ld   de, PART_LBA				; PART_LBA = table[idx]
	ld   bc, 4
	ldir
	ld   hl, PART_LBA				; SD_LBA = PART_LBA
	ld   de, SD_LBA
	ld   bc, 4
	ldir
	call sd_read_sector
	ld   a, (SD_STATUS)
	or   a
	scf
	ret  nz							; SD error -> CF=1
	call fat_compute_root
	call scan_root
	xor  a
	ld   (BR_SEL), a
	ld   (BR_TOP), a
	xor  a
	ld   (DIR_SP), a				; reset folder back-stack (root of this partition)
	ld   a, #FF
	ld   (MQ_SEL), a
	ld   a, 1
	ld   (BROWSING), a
	or   a							; CF = 0 (success)
	ret

; -----------------------------------------------------------------------------
; fat_compute_root: parse the BPB (SD_BUF) of the selected partition and derive
; FAT_LBA / DATA_LBA / root geometry. FAT32 is detected by FATSz16 == 0.
; FAT16: ROOT_LBA = fixed region, ROOT_SECS sectors, FS32=0.
; FAT32: root = cluster chain at ROOT_CLUS, FS32=1 (no fixed root region).
; -----------------------------------------------------------------------------
fat_compute_root:
	ld   a, (SD_BUF+13)				; sectors per cluster (power of 2)
	ld   (SEC_PER_CLUS), a
	ld   b, 0						; SPC_SHIFT = log2(SPC)
.fcr_sh:
	rrca
	jr   c, .fcr_shdone
	inc  b
	jr   .fcr_sh
.fcr_shdone:
	ld   a, b
	ld   (SPC_SHIFT), a
	ld   a, (SD_BUF+16)				; NumFATs
	ld   (NUM_FATS), a
	; FAT_LBA = PART_LBA + RsvdSecCnt (first FAT table sector)
	ld   hl, (SD_BUF+14)
	ld   de, (PART_LBA+0)
	add  hl, de
	ld   (FAT_LBA+0), hl
	ld   hl, (PART_LBA+2)
	ld   de, 0
	adc  hl, de
	ld   (FAT_LBA+2), hl
	; FATSz16 == 0 -> FAT32
	ld   hl, (SD_BUF+22)
	ld   a, h
	or   l
	jr   z, .fcr32
	; ---------- FAT16 ----------
	xor  a
	ld   (FS32), a
	ld   (FAT_SZ), hl
	call .fcr_fatmul				; DE = NumFATs * FAT_SZ
	ld   hl, (FAT_LBA+0)			; ROOT_LBA = FAT_LBA + NumFATs*FATSz16
	add  hl, de
	ld   (ROOT_LBA+0), hl
	ld   hl, (FAT_LBA+2)
	ld   de, 0
	adc  hl, de
	ld   (ROOT_LBA+2), hl
	ld   hl, (SD_BUF+17)			; RootEntCnt
	srl  h
	rr   l
	srl  h
	rr   l
	srl  h
	rr   l
	srl  h
	rr   l							; HL = RootEntCnt/16 = root-dir sectors
	ld   a, l
	ld   (ROOT_SECS), a
	ld   d, 0						; DATA_LBA = ROOT_LBA + ROOT_SECS
	ld   e, a
	ld   hl, (ROOT_LBA+0)
	add  hl, de
	ld   (DATA_LBA+0), hl
	ld   hl, (ROOT_LBA+2)
	ld   de, 0
	adc  hl, de
	ld   (DATA_LBA+2), hl
	ret
.fcr32:
	; ---------- FAT32 ----------
	ld   a, 1
	ld   (FS32), a
	ld   hl, (SD_BUF+36)			; FATSz32 (tomamos los 16 bits bajos; cubre <=512GB)
	ld   (FAT_SZ), hl
	call .fcr_fatmul				; DE = NumFATs * FAT_SZ
	ld   hl, (FAT_LBA+0)			; DATA_LBA = FAT_LBA + NumFATs*FATSz32 (sin root fijo)
	add  hl, de
	ld   (DATA_LBA+0), hl
	ld   hl, (FAT_LBA+2)
	ld   de, 0
	adc  hl, de
	ld   (DATA_LBA+2), hl
	ld   hl, SD_BUF+44				; RootClus (dword)
	ld   de, ROOT_CLUS
	ld   bc, 4
	ldir
	xor  a
	ld   (ROOT_SECS), a
	ret
.fcr_fatmul:						; DE = NumFATs * FAT_SZ (16-bit)
	ld   a, (NUM_FATS)
	ld   b, a
	ld   hl, 0
	ld   de, (FAT_SZ)
.fcr_mul:
	add  hl, de
	djnz .fcr_mul
	ex   de, hl
	ret

; -----------------------------------------------------------------------------
; set_scan_start: set SD_LBA (first sector) and sec_left (sector limit) for the
; directory whose cluster is CUR_CLUS (FAT16: 0 = the fixed root-dir region).
; -----------------------------------------------------------------------------
set_scan_start:
	ld   a, (FS32)
	or   a
	jr   nz, .sss_data				; FAT32: la raiz tambien es una cadena de clusters
	ld   hl, (CUR_CLUS+0)
	ld   a, h
	or   l
	jr   nz, .sss_data
	ld   hl, (ROOT_LBA+0)			; FAT16 root: fixed region after the FATs
	ld   (SD_LBA+0), hl
	ld   hl, (ROOT_LBA+2)
	ld   (SD_LBA+2), hl
	ld   a, (ROOT_SECS)
	ld   (sec_left), a
	ret
.sss_data:
	ld   hl, CUR_CLUS				; SD_LBA + sec_left desde el cluster (ancho)
	ld   de, W_TMP
	call w_copy
	jp   clus2lba

; -----------------------------------------------------------------------------
; Wide-cluster (FAT32) helpers. Clusters viven en RAM como dwords LE.
; -----------------------------------------------------------------------------
; w_copy: copia 4 bytes (HL) -> (DE).
w_copy:
	ld   bc, 4
	ldir
	ret

; w_zero: pone a 0 los 4 bytes en (HL).
w_zero:
	xor  a
	ld   (hl), a
	inc  hl
	ld   (hl), a
	inc  hl
	ld   (hl), a
	inc  hl
	ld   (hl), a
	ret

; cur_root: CUR_CLUS = raiz (FAT16: 0 / FAT32: ROOT_CLUS).
cur_root:
	ld   a, (FS32)
	or   a
	jr   z, .cr16
	ld   hl, ROOT_CLUS
	ld   de, CUR_CLUS
	jp   w_copy
.cr16:
	ld   hl, CUR_CLUS
	jp   w_zero

; clus2lba: SD_LBA = DATA_LBA + ((W_TMP-2) << SPC_SHIFT); sec_left = SPC.
; Destruye W_TMP.
clus2lba:
	ld   hl, (W_TMP+0)				; W_TMP -= 2 (32-bit)
	ld   de, 2
	or   a
	sbc  hl, de
	ld   (W_TMP+0), hl
	ld   hl, (W_TMP+2)
	ld   de, 0
	sbc  hl, de
	ld   (W_TMP+2), hl
	ld   a, (SPC_SHIFT)				; << SPC_SHIFT (32-bit)
	or   a
	jr   z, .c2l_add
.c2l_sh:
	ld   hl, (W_TMP+0)
	add  hl, hl
	ld   (W_TMP+0), hl
	ld   hl, (W_TMP+2)
	adc  hl, hl
	ld   (W_TMP+2), hl
	dec  a
	jr   nz, .c2l_sh
.c2l_add:
	ld   hl, (DATA_LBA+0)			; SD_LBA = DATA_LBA + W_TMP
	ld   de, (W_TMP+0)
	add  hl, de
	ld   (SD_LBA+0), hl
	ld   hl, (DATA_LBA+2)
	ld   de, (W_TMP+2)
	adc  hl, de
	ld   (SD_LBA+2), hl
	ld   a, (SEC_PER_CLUS)
	ld   (sec_left), a
	ret

; fat_seek_read: SD_LBA = FAT_LBA + DE (16-bit), lee el sector. CF=1 si error SD.
fat_seek_read:
	ld   hl, (FAT_LBA+0)
	add  hl, de
	ld   (SD_LBA+0), hl
	ld   hl, (FAT_LBA+2)
	ld   de, 0
	adc  hl, de
	ld   (SD_LBA+2), hl
	call sd_read_sector
	ld   a, (SD_STATUS)
	or   a
	ret  z							; CF=0 ok
	scf
	ret

; fatnext: W_TMP = FAT[W_TMP]. FAT16 normaliza su EOC a 0x0FFFFFF8 para que
; w_is_eoc valga para ambos. CF=1 si error SD. Destruye SD_BUF.
fatnext:
	ld   a, (FS32)
	or   a
	jr   nz, .fn32
	; FAT16: sector = clus>>8, entrada = (clus&255)*2
	ld   a, (W_TMP+1)
	ld   e, a
	ld   d, 0
	call fat_seek_read
	ret  c
	ld   a, (W_TMP+0)
	ld   l, a
	ld   h, 0
	add  hl, hl
	ld   de, SD_BUF
	add  hl, de
	ld   e, (hl)
	inc  hl
	ld   d, (hl)
	ld   (W_TMP+0), de
	ld   hl, 0
	ld   (W_TMP+2), hl
	ld   a, d						; normalizar EOC/bad (>= 0xFFF7)
	cp   #FF
	jr   nz, .fn_ok
	ld   a, e
	cp   #F7
	jr   c, .fn_ok
	ld   hl, #FFF8					; -> 0x0FFFFFF8 canonico
	ld   (W_TMP+0), hl
	ld   hl, #0FFF
	ld   (W_TMP+2), hl
.fn_ok:
	or   a							; CF=0
	ret
.fn32:
	; FAT32: sector = clus>>7, entrada = (clus&127)*4 (mascara 28 bits)
	ld   hl, (W_TMP+0)
	ld   a, (W_TMP+2)
	add  hl, hl						; (A:HL) << 1; DE = bytes [2:1] == clus>>7
	rla
	ld   e, h
	ld   d, a
	call fat_seek_read
	ret  c
	ld   a, (W_TMP+0)
	and  #7F
	ld   l, a
	ld   h, 0
	add  hl, hl
	add  hl, hl						; *4
	ld   de, SD_BUF
	add  hl, de
	ld   e, (hl)
	inc  hl
	ld   d, (hl)
	ld   (W_TMP+0), de
	inc  hl
	ld   e, (hl)
	inc  hl
	ld   a, (hl)
	and  #0F						; entradas FAT32 son de 28 bits
	ld   d, a
	ld   (W_TMP+2), de
	or   a							; CF=0
	ret

; w_is_eoc: CF=1 si W_TMP es fin de cadena/bad (>= 0x0FFFFFF7) o invalido (< 2).
w_is_eoc:
	ld   a, (W_TMP+3)
	cp   #0F
	jr   nz, .we_low
	ld   a, (W_TMP+2)
	cp   #FF
	jr   nz, .we_low
	ld   a, (W_TMP+1)
	cp   #FF
	jr   nz, .we_low
	ld   a, (W_TMP+0)
	cp   #F7
	jr   nc, .we_yes				; >= 0x0FFFFFF7 -> fin
.we_low:
	ld   a, (W_TMP+1)
	ld   hl, W_TMP+2
	or   (hl)
	inc  hl
	or   (hl)
	jr   nz, .we_no					; >= 0x100 -> valido
	ld   a, (W_TMP+0)
	cp   2
	jr   c, .we_yes					; 0/1 -> invalido
.we_no:
	or   a
	ret
.we_yes:
	scf
	ret

; -----------------------------------------------------------------------------
; scan_root / scan_current: read the current directory and store each [DIR]/.ROM
; entry into ENT_ARRAY as {type(1: 0=dir 1=rom), cluster(2), name(ASCIIZ)}.
; scan_root resets to the root; scan_current rescans whatever CUR_CLUS points to.
; -----------------------------------------------------------------------------
scan_root:
	call cur_root					; CUR_CLUS = raiz (0 en FAT16, ROOT_CLUS en FAT32)
	xor  a
	ld   (DIR_SP), a
scan_current:
	xor  a
	ld   (ENT_COUNT), a
	ld   (HAVE_LFN), a
	ld   hl, ENT_ARRAY
	ld   (ARR_PTR), hl
	call set_scan_start
	ld   hl, CUR_CLUS				; working cluster for FAT-chain walk
	ld   de, SCAN_CLUS
	call w_copy
.scr_sec:
	call sd_read_sector
	ld   a, (SD_STATUS)
	or   a
	jp   nz, .scr_done				; SD read failed -> stop, keep entries gathered so far
	ld   ix, SD_BUF
	ld   a, 16
	ld   (ent_in_sec), a
.scr_ent:
	ld   a, (ix+0)
	or   a
	jp   z, .scr_done				; 0x00 = end of directory
	cp   #E5
	jp   z, .scr_drop				; deleted -> skip, drop pending LFN
	ld   a, (ix+11)
	and  #0F
	cp   #0F
	jp   z, .scr_lfn				; LFN entry -> accumulate the long name
	ld   a, (ix+11)
	and  #08
	jp   nz, .scr_drop				; volume label -> skip
	ld   a, (ix+0)
	cp   '.'
	jp   z, .scr_drop				; "." and ".." entries -> skip
	ld   a, (ENT_COUNT)
	cp   MAX_ENT
	jp   nc, .scr_done				; array full
	ld   a, (ix+11)
	and  #10
	jr   z, .scr_file
	ld   c, 0						; type 0 = directory
	jr   .scr_store
.scr_file:
	call ix_is_rom
	jr   z, .scr_isrom
	call ix_is_dsk
	jp   nz, .scr_drop				; ni ROM/DSK -> fuera
.scr_isdsk:
	ld   c, 2						; type 2 = dsk (Nextor disk image)
	jr   .scr_store
.scr_isrom:
	ld   c, 1						; type 1 = rom
.scr_store:
	; active-tab filter: dirs (c=0) always kept; files filtered by type.
	ld   a, c
	or   a
	jr   z, .scr_fltok				; directory -> keep
	ld   a, (FILTER)
	cp   2
	jr   z, .scr_fltok				; ALL -> keep
	or   a
	jr   nz, .scr_fdsk
	ld   a, c						; tab ROM: solo roms (1)
	cp   2
	jp   z, .scr_drop
	jr   .scr_fltok
.scr_fdsk:
	ld   a, c						; tab DSK: solo imagenes de disco
	cp   2
	jp   nz, .scr_drop
.scr_fltok:
	; name source: assembled LFN if any, else the 8.3 short name
	ld   a, (HAVE_LFN)
	or   a
	jr   z, .scr_short
	ld   hl, LFN_BUF
	jr   .scr_named
.scr_short:
	push bc							; preserve type across fmt_name83
	call fmt_name83					; -> name83 (uses ix)
	pop  bc
	ld   hl, name83
.scr_named:
	push hl							; name source ptr
	ld   hl, (ARR_PTR)
	ld   (hl), c					; +0 type
	inc  hl
	ld   a, (ix+26)					; +1 cluster byte 0
	ld   (hl), a
	inc  hl
	ld   a, (ix+27)					; +2 cluster byte 1
	ld   (hl), a
	inc  hl
	ld   a, (FS32)
	or   a
	jr   nz, .scr_hi32
	xor  a							; FAT16: bytes altos = 0
	ld   (hl), a
	inc  hl
	jr   .scr_hi_done
.scr_hi32:
	ld   a, (ix+20)					; +3 cluster byte 2 (FAT32: word alto en +20)
	ld   (hl), a
	inc  hl
	ld   a, (ix+21)					; +4 cluster byte 3
	and  #0F
.scr_hi_done:
	ld   (hl), a
	inc  hl
	ld   a, (ix+28)					; +5 file size byte 0 (LE dword)
	ld   (hl), a
	inc  hl
	ld   a, (ix+29)					; +6 file size byte 1
	ld   (hl), a
	inc  hl
	ld   a, (ix+30)					; +7 file size byte 2
	ld   (hl), a
	inc  hl
	ld   a, (ix+31)					; +8 file size byte 3
	ld   (hl), a
	inc  hl							; hl = record+9 (name destination)
	ex   de, hl						; de = dest
	pop  hl							; hl = name source
	call copy_name					; copy up to NAME_MAX, NUL-terminated
	ld   hl, (ARR_PTR)				; advance ARR_PTR by one full record
	ld   de, ENT_SIZE
	add  hl, de
	ld   (ARR_PTR), hl
	ld   a, (ENT_COUNT)
	inc  a
	ld   (ENT_COUNT), a
.scr_drop:
	xor  a
	ld   (HAVE_LFN), a				; clear any pending LFN accumulation
	jr   .scr_next
.scr_lfn:
	call lfn_accumulate				; place this entry's 13 chars into LFN_BUF
	jr   .scr_next
.scr_next:
	ld   de, 32
	add  ix, de
	ld   a, (ent_in_sec)
	dec  a
	ld   (ent_in_sec), a
	jp   nz, .scr_ent
	call inc_sd_lba
	ld   a, (sec_left)
	dec  a
	ld   (sec_left), a
	jp   nz, .scr_sec
	call scan_next_cluster			; subdir spanning >1 cluster: follow FAT chain
	jp   c, .scr_sec				; CF=1 -> a new cluster is ready, keep scanning
.scr_done:
	ret

; scan_next_cluster: advance the directory scan to the next cluster of the current
; subdirectory by following the FAT chain. Returns CF=1 if a new valid cluster was
; set up (SD_LBA + sec_left ready), CF=0 if there is no next cluster (root dir, end
; of chain, bad cluster, or SD error). Destroys SD_BUF.
scan_next_cluster:
	ld   a, (FS32)
	or   a
	jr   nz, .snc_walk				; FAT32: la raiz tambien encadena
	ld   hl, (CUR_CLUS+0)
	ld   a, h
	or   l
	jr   z, .snc_none				; FAT16 root: region fija, sin cadena
.snc_walk:
	ld   hl, SCAN_CLUS
	ld   de, W_TMP
	call w_copy
	call fatnext					; W_TMP = FAT[W_TMP] (lee un sector FAT a SD_BUF)
	jr   c, .snc_none				; SD error -> stop
	call w_is_eoc
	jr   c, .snc_none				; fin de cadena / cluster invalido
	ld   hl, W_TMP
	ld   de, SCAN_CLUS
	call w_copy
	call clus2lba					; SD_LBA + sec_left (destruye W_TMP)
	scf
	ret
.snc_none:
	or   a							; CF=0
	ret

; lfn_accumulate: place the 13 chars of this LFN entry (IX) into LFN_BUF at
; (seq-1)*13, where seq = (IX+0) & 0x3F. Clears LFN_BUF on the first entry.
lfn_accumulate:
	ld   a, (HAVE_LFN)
	or   a
	jr   nz, .lac_seq
	ld   hl, LFN_BUF				; first of group: clear 80-byte buffer
	ld   (hl), 0
	ld   de, LFN_BUF+1
	ld   bc, 79
	ldir
	ld   a, 1
	ld   (HAVE_LFN), a
.lac_seq:
	ld   a, (ix+0)
	and  #3F						; sequence number (1-based)
	dec  a							; 0-based
	cp   6
	ret  nc							; seq too high -> ignore (name truncated)
	ld   hl, 0
	or   a
	jr   z, .lac_dst
	ld   b, a
	ld   de, 13
.lac_mul:
	add  hl, de
	djnz .lac_mul					; hl = (seq-1)*13
.lac_dst:
	ld   de, LFN_BUF
	add  hl, de
	ex   de, hl						; de = LFN_BUF + (seq-1)*13
	jp   lfn_copy13					; copy 13 chars (ends with ret)

; lfn_copy13: copy the 13 name chars (UTF-16 low bytes) of the LFN entry at IX
; into (DE). Char byte offsets: 1,3,5,7,9, 14,16,18,20,22,24, 28,30.
lfn_copy13:
	ld   a, (ix+1)
	ld   (de), a
	inc  de
	ld   a, (ix+3)
	ld   (de), a
	inc  de
	ld   a, (ix+5)
	ld   (de), a
	inc  de
	ld   a, (ix+7)
	ld   (de), a
	inc  de
	ld   a, (ix+9)
	ld   (de), a
	inc  de
	ld   a, (ix+14)
	ld   (de), a
	inc  de
	ld   a, (ix+16)
	ld   (de), a
	inc  de
	ld   a, (ix+18)
	ld   (de), a
	inc  de
	ld   a, (ix+20)
	ld   (de), a
	inc  de
	ld   a, (ix+22)
	ld   (de), a
	inc  de
	ld   a, (ix+24)
	ld   (de), a
	inc  de
	ld   a, (ix+28)
	ld   (de), a
	inc  de
	ld   a, (ix+30)
	ld   (de), a
	inc  de
	ret

; fh2_lfn_acc: como lfn_accumulate pero acumula en FH_LNBUF (208B) hasta 15
; entradas (195 chars = FH_MAXNAME), para que el precheck compare el nombre
; largo COMPLETO (no los 78 de LFN_BUF). Reusa HAVE_LFN como flag de grupo.
fh2_lfn_acc:
	ld   a, (HAVE_LFN)
	or   a
	jr   nz, .fla_seq
	ld   hl, FH_LNBUF				; primera del grupo: limpiar el buffer entero
	ld   (hl), 0
	ld   de, FH_LNBUF+1
	ld   bc, FH_LNBUFLEN-1
	ldir
	ld   a, 1
	ld   (HAVE_LFN), a
.fla_seq:
	ld   a, (ix+0)
	and  #3F						; numero de secuencia (1-based)
	dec  a							; 0-based
	cp   15							; seq >=16 -> nombre >195, ignorar el resto
	ret  nc
	ld   hl, 0
	or   a
	jr   z, .fla_dst
	ld   b, a
	ld   de, 13
.fla_mul:
	add  hl, de
	djnz .fla_mul					; hl = (seq-1)*13
.fla_dst:
	ld   de, FH_LNBUF
	add  hl, de
	ex   de, hl						; de = FH_LNBUF + (seq-1)*13
	jp   lfn_copy13					; copia 13 chars (termina en ret)

; copy_name: copy name from HL to DE, up to NAME_MAX chars, stopping at NUL or
; 0xFF (LFN padding); then NUL-terminate the destination.
copy_name:
	ld   b, NAME_MAX
.cn_loop:
	ld   a, (hl)
	or   a
	jr   z, .cn_end
	cp   #FF
	jr   z, .cn_end
	ld   (de), a
	inc  hl
	inc  de
	djnz .cn_loop
.cn_end:
	xor  a
	ld   (de), a
	ret

; inc16: HL = address of a 16-bit counter -> increment it.
inc16:
	inc  (hl)
	ret  nz
	inc  hl
	inc  (hl)
	ret

; classify_addr: DE = a "LD (nn),A" target address; bump exactly ONE mapper
; counter, counting only the DISTINGUISHING bank registers of each mapper.
; (Low byte of every bank register is 0; classify by the high byte.)
;   0x50/0x90/0xB0 -> SCC-only    0x80/0xA0 -> Konami-only
;   0x68/0x78      -> ASCII8-only 0x60/0x70 -> ASCII16/generic
classify_addr:
	; tabla de creditos de openMSX guessRomType: 4000/8000/A000=Konami;
	; 5000/9000/B000=SCC; 6800/7800=ASCII8; 77FF=ASCII16;
	; 6000=Konami+A8+A16; 7000=SCC+A8+A16
	ld   a, e
	or   a
	jr   nz, .ca_77ff				; byte bajo != 0: solo interesa 77FF
	ld   a, d
	cp   #50
	jr   z, .ca_scc
	cp   #90
	jr   z, .ca_scc
	cp   #B0
	jr   z, .ca_scc
	cp   #40
	jr   z, .ca_kon
	cp   #80
	jr   z, .ca_kon
	cp   #A0
	jr   z, .ca_kon
	cp   #68
	jr   z, .ca_a8
	cp   #78
	jr   z, .ca_a8
	cp   #60
	jr   z, .ca_kaa
	cp   #70
	jr   z, .ca_saa
	ret
.ca_77ff:
	inc  a							; e == #FF ?
	ret  nz
	ld   a, d
	cp   #77
	ret  nz
	jr   .ca_a16
.ca_kaa:							; 6000: Konami + ASCII8 + ASCII16
	ld   hl, MAP_KON
	call inc16
	jr   .ca_aa
.ca_saa:							; 7000: SCC + ASCII8 + ASCII16
	ld   hl, MAP_SCC
	call inc16
.ca_aa:
	ld   hl, MAP_A8
	call inc16
	jr   .ca_a16
.ca_scc:
	ld   hl, MAP_SCC
	jp   inc16
.ca_kon:
	ld   hl, MAP_KON
	jp   inc16
.ca_a8:
	ld   hl, MAP_A8
	jp   inc16
.ca_a16:
	ld   hl, MAP_A16
	jp   inc16

; scan_sector_mapper: scan SD_BUF (512 bytes) for "32 lo hi" (LD (nn),A).
scan_sector_mapper:
	ld   hl, SD_BUF
	ld   bc, 510
.ssm:
	ld   a, (hl)
	cp   #32
	jr   nz, .ssm_n
	push hl
	push bc
	inc  hl
	ld   e, (hl)
	inc  hl
	ld   d, (hl)
	call classify_addr
	pop  bc
	pop  hl
.ssm_n:
	inc  hl
	dec  bc
	ld   a, b
	or   c
	jr   nz, .ssm
	ret

; scan_rom: read the ROM (FILE_CLUS chain), up to 256 sectors, scanning for
; mapper bank-writes into MAP_* counters. Restores CUR_CLUS.
scan_rom:
	ld   hl, 0
	ld   (MAP_SCC), hl
	ld   (MAP_KON), hl
	ld   (MAP_A8), hl
	ld   (MAP_A16), hl
	ld   (SCAN_N), hl
	ld   hl, FILE_CLUS
	ld   de, SCAN_CLUS
	call w_copy
.sr_clus:
	ld   hl, SCAN_CLUS				; SD_LBA + sec_left para el cluster actual
	ld   de, W_TMP
	call w_copy
	call clus2lba
	ld   a, (SEC_PER_CLUS)
	ld   (SSEC_LEFT), a
.sr_sec:
	call sd_read_sector
	call scan_sector_mapper
	ld   hl, (SCAN_N)
	inc  hl
	ld   (SCAN_N), hl
	ld   a, h						; cap at 512 sectors (256 KB scanned)
	cp   2
	jr   nc, .sr_done
	; spinner: el analisis del mapper lee ~170 sectores/s; girar un caracter (cambia
	; de frame cada 16 sectores) para que se vea que el menu trabaja en esos 2-3s
	push af
	push bc
	push de
	push hl
	ld   a, (SCAN_N)				; low byte del contador de sectores
	and  #30						; bits 5:4 -> frame 0..3
	rrca
	rrca
	rrca
	rrca
	ld   e, a
	ld   d, 0
	ld   hl, spin_chars
	add  hl, de
	ld   c, (hl)					; caracter del frame
	ld   hl, #2C11					; col 44, fila 17 (junto a "Analizando ROM...")
	call POSIT
	ld   a, c
	call CHPUT
	pop  hl
	pop  de
	pop  bc
	pop  af
	call inc_sd_lba
	ld   a, (SSEC_LEFT)
	dec  a
	ld   (SSEC_LEFT), a
	jr   nz, .sr_sec
	ld   hl, SCAN_CLUS				; siguiente cluster de la cadena
	ld   de, W_TMP
	call w_copy
	call fatnext
	jr   c, .sr_done
	call w_is_eoc
	jr   c, .sr_done
	ld   hl, W_TMP
	ld   de, SCAN_CLUS
	call w_copy
	jr   .sr_clus
.sr_done:
	ret
spin_chars:
	.db #2D,#5C,#7C,#2F				; frames del spinner: - \ | /

; decide_mapper: eleccion al estilo openMSX guessRomType: quirk ascii8-- y
; despues el maximo con >= iterando SCC,Konami,ASCII8,ASCII16 (en empate gana
; el iterado mas tarde, p.ej. ASCII16 sobre ASCII8). Todo a cero -> plain.
decide_mapper:
	ld   hl, (MAP_A8)
	ld   a, h
	or   l
	jr   z, .dm_go
	dec  hl							; quirk openMSX: ascii8-- si no es cero
	ld   (MAP_A8), hl
.dm_go:
	ld   b, MAP_PLAIN				; mejor tipo
	ld   de, 0						; mejor puntuacion
	ld   hl, (MAP_SCC)
	ld   c, MAP_SCC_ID
	call .dm_cand
	ld   hl, (MAP_KON)
	ld   c, MAP_KON_ID
	call .dm_cand
	ld   hl, (MAP_A8)
	ld   c, MAP_A8_ID
	call .dm_cand
	ld   hl, (MAP_A16)
	ld   c, MAP_A16_ID
	call .dm_cand
	ld   a, b
	ld   (MAPPER_ID), a
	ret
.dm_cand:							; HL=puntos, C=tipo: si HL!=0 y HL>=mejor, gana
	ld   a, h
	or   l
	ret  z
	push hl
	or   a
	sbc  hl, de						; CF=1 si HL < mejor
	pop  hl
	ret  c
	ex   de, hl						; nueva mejor puntuacion
	ld   b, c
	ret

; detect_mapper: decide MAPPER_ID for the selected file. <=32 KB -> plain; else
; scan the content. Uses the file size in the record (BR_REC+3 dword) for the rule.
detect_mapper:
	ld   hl, (BR_REC)
	ld   de, SIZE_OFF+2
	add  hl, de
	ld   a, (hl)					; size byte 2
	inc  hl
	or   (hl)						; | size byte 3
	jr   nz, .det_scan				; > 64 KB -> scan
	ld   hl, (BR_REC)
	ld   de, SIZE_OFF+1
	add  hl, de
	ld   a, (hl)					; size byte 1 (x256)
	cp   #80						; < 0x8000 (32 KB)?
	jr   nc, .det_scan				; 32..64 KB -> scan to be sure
	ld   a, MAP_PLAIN
	ld   (MAPPER_ID), a
	ret
.det_scan:
	; _182b (Albert, 04/08): la ETIQUETA del nombre MANDA sobre el contenido.
	; La pone la API en las descargas (fh2_typetag) y el usuario al renombrar;
	; el escaneo de opcodes queda de RESPALDO para nombres sin etiqueta (con
	; su promocion Konami>=320K intacta). Antes era al reves (la etiqueta solo
	; como ultima red) y el probe de Compile ganaba a un [ASCII16] explicito.
	xor  a
	ld   (MAPPER_ID), a				; base: sin decision (MAP_PLAIN)
	call override_mapper_by_name	; pone MAPPER_ID si el nombre lleva tag
	ld   a, (MAPPER_ID)
	or   a
	ret  nz							; habia etiqueta -> manda el nombre
	call scan_rom
	call decide_mapper				; MAPPER_ID por CONTENIDO (estilo openMSX)
	; v2.0.1: promocion Konami4 -> Konami-SCC en ROMs grandes. Konami4 real
	; nunca pasa de 256KB; los megaroms "Konami" grandes son conversiones
	; MFR SCC+ (Aleste2 v8 2MB: su probe dual enganyaba al scan por 1 punto
	; de ruido). +24 bytes medidos; el guard ds #A000-$ vigila el banco.
	ld   a, (MAPPER_ID)
	cp   MAP_KON_ID					; ?el scan dijo Konami4?
	jr   nz, .det_kok
	ld   hl, (BR_REC)
	ld   de, SIZE_OFF+2
	add  hl, de
	ld   a, (hl)					; size[23:16]
	cp   5							; >= 320 KB -> promocionar a SCC
	jr   c, .det_kok
	ld   a, MAP_SCC_ID
	ld   (MAPPER_ID), a
.det_kok:
	ret								; _182b: la etiqueta ya se miro ANTES del scan

; megaram_test: set the megaram to Konami-SCC mode (OCM SWIO), write-enable it,
; write A5/5A to bank 0, read them back into MEG_T0/MEG_T1. No reset (safe).
; If the readback is A5 5A the megaram load mechanism works.
megaram_test:
	di
	; --- OCM SWIO smart command: set Slot2 = Internal SCC-I (Konami-SCC mode) ---
	; (Slot2Mode is driven by the virtual DIP-SW, changed via a smart command on
	;  port 0x41, NOT by writing port 0x42 directly. 0x0F = Ext Slot1 + Int SCC-I
	;  Slot2 -> io42[5:3]="010" -> Slot2Mode=10 -> megaram map_sel[0]=0 = SCC mode.)
	ld   a, #D4
	out  (#40), a					; select smart device ID212
	ld   a, #0F
	out  (#41), a					; smart command: Internal SCC-I in Slot2
	in   a, (#42)					; diagnostic readback (expect bit4 set, bit5 clear)
	ld   (MEG_P42), a
	; --- map page 1 to the megaram slot ---
	ld   a, MEG_SLOT
	ld   hl, #4000
	call ENASLT
	ld   a, (#4000)					; diagnostic: megaram content BEFORE writing
	ld   (MEG_B0), a
	; bank 0 -> reg0 (write-enable must be OFF to set the bank register)
	xor  a
	ld   (#7FFE), a					; mode_a = 0
	xor  a
	ld   (#5000), a					; megaram_reg0 = 0 (segment 0 at 0x4000-0x5FFF)
	; enable writing
	ld   a, #10
	ld   (#7FFE), a					; mode_a bit4 = 1 (write enable)
	ld   a, #A5
	ld   (#4000), a
	ld   a, #5A
	ld   (#4001), a
	xor  a
	ld   (#7FFE), a					; write disable
	ld   a, (#4000)					; read back
	ld   (MEG_T0), a
	ld   a, (#4001)
	ld   (MEG_T1), a
	; restore page 1 -> slot 3-1 (this menu)
	ld   a, #87
	ld   hl, #4000
	call ENASLT
	ei
	ret

; write_sector_to_megaram: copy SD_BUF (512 B) into the megaram at LOAD_SEG/LOAD_OFF
; (8K-segment linear). Sets the bank + write-enable at each segment start.
write_sector_to_megaram:
	ld   a, MEG_SLOT				; page 1 -> megaram (slot 2)
	ld   hl, #4000
	call ENASLT
	ld   hl, (LOAD_OFF)
	ld   a, h
	or   l
	jr   nz, .wsm_copy				; mid-segment -> just copy
	xor  a							; new 8K segment: disable write, set bank, enable write
	ld   (#7FFE), a
	ld   a, (LOAD_SEG)
	ld   (#5000), a					; megaram_reg0 = segment
	ld   a, #10
	ld   (#7FFE), a
.wsm_copy:
	ld   hl, (LOAD_OFF)
	ld   de, #4000
	add  hl, de
	ex   de, hl						; de = 0x4000 + offset
	ld   hl, SD_BUF
	ld   bc, 512
	ldir
	ld   a, #87						; page 1 -> slot 3-1
	ld   hl, #4000
	call ENASLT
wsm_advance:
	ld   hl, (LOAD_OFF)				; advance offset, wrap to next segment at 8 KB
	ld   de, 512
	add  hl, de
	ld   (LOAD_OFF), hl
	ld   a, h
	cp   #20						; 0x2000 = 8192
	ret  c
	ld   hl, 0
	ld   (LOAD_OFF), hl
	ld   a, (LOAD_SEG)
	inc  a
	ld   (LOAD_SEG), a
	ret

; load_rom: load the whole ROM (FILE_CLUS chain) into the megaram, 8K linear.
load_rom:
	xor  a							; carga normal: desde el segmento 0
	push af
	ld   a, #D4						; SWIO: Slot2 = Int SCC-I (megaram -> slot 2, SCC mode)
	out  (#40), a
	ld   a, #0F
	out  (#41), a
	; --- barra ESCALADA (Bresenham): BAR_TOT = ceil(KB/8) = segmentos 8K de la
	;     ROM; por cada segmento FRAC += 64 y cada TOT acumulados pinta 1 celda
	;     -> la barra acaba SIEMPRE llena (64 celdas), sea 16K o 2MB ---
	call rom_kb						; HL = tamano de la ROM en KB
	ld   de, 7
	add  hl, de						; ceil(KB/8)
	srl  h
	rr   l
	srl  h
	rr   l
	srl  h
	rr   l
	ld   a, h
	or   l
	jr   nz, .lro_t1
	inc  hl							; minimo 1 (ROM vacia: evita bucle infinito)
.lro_t1:
	ld   (BAR_TOT), hl
	ld   hl, 0
	ld   (BAR_FRAC), hl
	xor  a
	ld   (BAR_CNT), a
	ld   hl, #090F					; celdas de la barra (fila 15, cols 9..72)
	call POSIT
	pop  af
	ld   (LOAD_SEG), a
	ld   hl, 0
	ld   (LOAD_OFF), hl
	ld   hl, FILE_CLUS
	ld   de, LOAD_CLUS
	call w_copy
.lro_clus:
	ld   hl, LOAD_CLUS				; SD_LBA + sec_left para el cluster actual
	ld   de, W_TMP
	call w_copy
	call clus2lba
	ld   a, (SEC_PER_CLUS)
	ld   (SSEC_LEFT), a
.lro_sec:
	call sd_read_sector
	call write_sector_to_megaram
	ld   hl, (LOAD_OFF)				; LOAD_OFF wrapped to 0 -> one 8K segment done
	ld   a, h
	or   l
	jr   nz, .lro_nobar
	; Bresenham: FRAC += 64; por cada TOT completos pinta una celda solida
	ld   hl, (BAR_FRAC)
	ld   de, 64
	add  hl, de
.lro_bloop:
	ld   de, (BAR_TOT)
	or   a
	sbc  hl, de
	jr   c, .lro_brest				; FRAC < TOT -> restaurar resto y seguir
	ld   a, (BAR_CNT)
	cp   64							; tope fisico: no pisar el ']' del marco
	jr   c, .lro_btick
	add  hl, de						; barra ya llena: restaurar y salir
	jr   .lro_bsave
.lro_btick:
	inc  a
	ld   (BAR_CNT), a
	ld   a, #DB						; celda solida de la barra
	call CHPUT
	jr   .lro_bloop
.lro_brest:
	add  hl, de						; deshacer la resta que se paso
.lro_bsave:
	ld   (BAR_FRAC), hl
.lro_nobar:
	call inc_sd_lba
	ld   a, (SSEC_LEFT)
	dec  a
	ld   (SSEC_LEFT), a
	jr   nz, .lro_sec
	ld   hl, LOAD_CLUS				; siguiente cluster de la cadena
	ld   de, W_TMP
	call w_copy
	call fatnext
	jr   c, .lro_done
	call w_is_eoc
	jr   c, .lro_done
	ld   hl, W_TMP
	ld   de, LOAD_CLUS
	call w_copy
	jr   .lro_clus
.lro_done:
	; completar la barra hasta 64 (si el size del dir no cuadra con la cadena
	; de clusters, o la ROM es mas corta): al acabar SIEMPRE se ve llena
	ld   a, (BAR_CNT)
.lro_fill:
	cp   64
	jr   nc, .lro_fin
	push af
	ld   a, #DB
	call CHPUT
	pop  af
	inc  a
	jr   .lro_fill
.lro_fin:
	ret

; override_mapper_by_name: if the selected file's name contains a GoodMSX mapper
; tag ([ASCII16]/[ASCII8]/[KonamiSCC]/[SCC]/[Konami]) set MAPPER_ID from it. The
; name tag is far more reliable than scanning code for bank-write opcodes (many
; games bank-switch via LD (HL),A which the opcode scan misses, e.g. Ikari).
; BR_REC must point at the selected record (name ASCIIZ at +NAME_OFF).
override_mapper_by_name:
	ld   hl, (BR_REC)
	ld   de, NAME_OFF
	add  hl, de
	ld   (TAGPTR), hl				; haystack = filename
	ld   hl, tag_a16
	call name_contains
	jr   nc, .omn_a8
	ld   a, MAP_A16_ID
	jr   .omn_set
.omn_a8:
	ld   hl, tag_a8
	call name_contains
	jr   nc, .omn_scc
	ld   a, MAP_A8_ID
	jr   .omn_set
.omn_scc:
	ld   hl, tag_scc
	call name_contains
	jr   nc, .omn_kon
	ld   a, MAP_SCC_ID
	jr   .omn_set
.omn_kon:
	ld   hl, tag_kon
	call name_contains
	ret  nc							; no tag -> keep the code-scan result
	ld   a, MAP_KON_ID
.omn_set:
	ld   (MAPPER_ID), a
	ret

; name_contains: case-sensitive substring search. HL = needle (ASCIIZ);
; (TAGPTR) = haystack (ASCIIZ). Returns CF=1 if needle occurs in haystack.
name_contains:
	ld   (NEEDLE), hl
	ld   hl, (TAGPTR)
.ncs_try:
	ld   a, (hl)
	or   a
	jr   z, .ncs_nf					; end of haystack -> not found
	push hl							; remember this start position
	ld   de, (NEEDLE)
.ncs_cmp:
	ld   a, (de)
	or   a
	jr   z, .ncs_found				; end of needle -> matched
	ld   c, a						; needle char (tags are stored UPPER-case)
	ld   a, (hl)					; haystack char -> upper-case for case-insensitive cmp
	cp   'a'
	jr   c, .ncs_noup
	cp   'z' + 1
	jr   nc, .ncs_noup
	sub  #20						; 'a'..'z' -> 'A'..'Z'
.ncs_noup:
	cp   c
	jr   nz, .ncs_next
	inc  hl
	inc  de
	jr   .ncs_cmp
.ncs_next:
	pop  hl
	inc  hl
	jr   .ncs_try
.ncs_found:
	pop  hl
	scf
	ret
.ncs_nf:
	or   a							; CF = 0
	ret

; tags de mapper GoodMSX/openMSX: SIEMPRE entre corchetes. Antes "KONAMI"
; (sin corchetes) se tragaba el nombre del FABRICANTE -- casi toda ROM MSX
; lleva "Konami" en el nombre -> forzaba Konami4 a juegos KonamiSCC (MG2 se
; cargaba como Konami4 y reiniciaba). Con el corchete solo matchea el TAG.
tag_a16:
	.db "[ASCII16",0
tag_a8:
	.db "[ASCII8",0
tag_scc:
	.db "SCC]",0					; pilla [SCC] y [KonamiSCC]
tag_kon:
	.db "[Konami",0					; [Konami] o [Konami5]; NO el fabricante suelto
tag_koei:
	.db "KOEI",0
tag_sram:
	.db "SRAM",0

; launch_rom: ROM already loaded into the megaram (SCC mode). DIRECT boot, no
; hardware reset: a reset re-runs the 512KB flash->SDRAM BIOS reload with the
; refresh stopped for >64ms, so the megaram DRAM content DECAYS (verified on HW:
; slot 2 reads FF after any reset; that is also why SofaRun never resets).
; We instead do what the BIOS would: set the mapper mode via SWIO, clean the
; VDP, switch pages 1+2 to slot 2 and CALL the cartridge INIT. If the INIT
; RETURNS (two-stage Konami: Metal Gear 2, SD Snatcher hook H.STKE and expect
; the BIOS to call it later) we call the H.STKE hook ourselves.
launch_rom:
	di
	; --- SRAM de cartucho (#43): bit de habilitacion + limpieza del area ---
	ld   a, #48						; dispositivo config goauld
	out  (#40), a
	ld   a, (SRAM_FLAG)
	or   a
	jr   z, .lr_sroff
	ld   a, (MAPPER_ID)
	cp   MAP_A16_ID
	ld   b, #10						; ASCII16: modo "valor==0x10" (Hydlide2/A-Train)
	jr   z, .lr_srclr
	cp   MAP_A8_ID
	jr   nz, .lr_sroff				; SRAM solo aplica a ASCII8/16
	ld   hl, (BR_REC)				; ASCII8: bit = pow2 >= bancos de 8K (openMSX)
	ld   de, SIZE_OFF+1
	add  hl, de
	ld   e, (hl)					; size>>8
	inc  hl
	ld   d, (hl)					; size>>16
	srl  d
	rr   e
	srl  d
	rr   e
	srl  d
	rr   e
	srl  d
	rr   e
	srl  d
	rr   e							; e = bancos de 8K (size>>13)
	ld   b, 1
.lr_srb:
	ld   a, e
	dec  a
	cp   b							; b >= bancos -> listo
	jr   c, .lr_srclr
	sla  b
	jr   nz, .lr_srb
	ld   b, #80						; tope 2MB
.lr_srclr:
	ld   a, b
	out  (#43), a
	ld   a, MEG_SLOT				; limpiar SRAM (segs 252-255) a FF = cartucho virgen
	ld   hl, #4000
	call ENASLT
	ld   a, 252
.lr_srcs:
	push af
	xor  a
	ld   (#7FFE), a					; banco solo se fija con write-protect activo
	pop  af
	push af
	ld   (#5000), a					; reg0 = segmento
	ld   a, #10
	ld   (#7FFE), a					; write enable
	ld   hl, #4000
	ld   de, #4001
	ld   bc, #1FFF
	ld   (hl), #FF
	ldir
	pop  af
	inc  a
	jr   nz, .lr_srcs				; 252..255, tras 255 A pasa a 0
	xor  a
	ld   (#7FFE), a
	ld   a, #87
	ld   hl, #4000
	call ENASLT
	jr   .lr_srdone
.lr_sroff:
	xor  a
	out  (#43), a					; SRAM apagada (defecto en cada lanzamiento)
.lr_srdone:
	; megaram a estado de cartucho (banco 0, write-protect) -- en modo SCC
	; 0x7FFE/0x5000 son regs de control (en ASCII serian regs de banco)
	ld   a, MEG_SLOT				; page 1 -> megaram (slot 2)
	ld   hl, #4000
	call ENASLT
	ld   a, #80
	ld   (#7FFE), a					; mode_a = 0x80: write-protect + CERROJO (bit7):
									; bloquea 7FFE y BFFE hasta el proximo reset para
									; que los pokes anticopia (MG2) no abran escritura
	xor  a
	ld   (#5000), a					; bank reg0 = 0 (first 8 KB at 0x4000)
									; (regs 1-3 los inicializa el stub: aqui la
									; pagina 2 es la del menu, no la megaram)
	ld   a, #87						; page 1 -> slot 3-1 (menu)
	ld   hl, #4000
	call ENASLT
	; mapper real del juego via OCM SWIO
	ld   a, (MAPPER_ID)
	cp   MAP_A8_ID
	jr   z, .lr_a8
	cp   MAP_A16_ID
	jr   z, .lr_a16
	cp   MAP_KON_ID
	ld   a, #0D						; Konami4: Slot2Mode=00 (cmd Ext1+Ext2) ->
	jr   z, .lr_setmap				; megaram map_sel=00 = regs 6000/8000/A000
	ld   a, #0F						; SCC / plain (map_sel=10)
	jr   .lr_setmap
.lr_a8:
	ld   a, #11						; Int ASCII8K
	jr   .lr_setmap
.lr_a16:
	ld   a, #13						; Int ASCII16K
.lr_setmap:
	ld   (MAP_SWIO), a				; el stub lo aplica TRAS inicializar los bancos
									; (el modo se queda en SCC, el del load, para que
									; las escrituras de bancos del stub funcionen)
	; v2.0.1 (caso Aleste2 2MB, probado en openMSX): la BIOS real llama al INIT
	; con RAM en la pagina 2; nosotros dejabamos la megaram y las conversiones
	; de disco (usan 0x8000 de buffer) escribian al vacio o sobre reg2/reg3.
	; Solo las ROMs lineales 32/48K necesitan el cartucho en la pagina 2.
	ld   a, (MAPPER_ID)
	or   a							; MAP_PLAIN = 0 -> lineal: pag.2 = megaram
	ld   a, MEG_SLOT
	jr   z, .lr_p2sl
	ld   a, RAM_SLOT_30				; megarom: pag.2 = RAM (fiel a la BIOS)
.lr_p2sl:
	ld   (P2_SLOT), a
	; VDP a estado limpio: INIT32 (R0-R7 + espejo) y R8-R23/R25-R27 a cero
	call #006F						; INIT32 (SCREEN 1)
	di								; INIT32 puede reactivar IRQs
	ld   hl, vdp_clean_tbl
	ld   b, 19						; R8-R23 (16 regs) + R25-R27 (3 regs)
.lr_vdp:
	ld   a, (hl)
	inc  hl
	out  (#99), a					; data byte
	ld   a, (hl)
	inc  hl
	out  (#99), a					; register select (0x80 | reg)
	djnz .lr_vdp
	call restore_palette			; el logo dejo su paleta de marca puesta
	ld   a, #C9						; hook H.STKE virgen antes de llamar al INIT
	ld   (#FEDA), a
	ld   hl, boot_stub				; stub a RAM de pagina 3 y saltar
	ld   de, #E000
	ld   bc, boot_stub_end - boot_stub
	ldir
	jp   #E000

; restore_palette: paleta V9938 de fabrica (el logo de arranque la cambia y los
; juegos MSX1 no la reprograman: sin esto salen colores invertidos/raros)
restore_palette:
	xor  a
	out  (#99), a
	ld   a, #90						; R#16 = 0 (indice de paleta)
	out  (#99), a
	ld   hl, def_palette
	ld   b, 32
.rp_l:
	ld   a, (hl)
	inc  hl
	out  (#9A), a
	djnz .rp_l
	ret
def_palette:						; formato: (R<<4)|B, G
	.db #00,0, #00,0, #11,6, #33,7, #17,1, #27,3, #51,1, #27,6
	.db #71,1, #73,3, #61,6, #64,6, #11,4, #65,2, #55,5, #77,7

; clean MSX2/V9958 VDP register values: (data, 0x80|reg) pairs for R8-R23,R25-27
vdp_clean_tbl:
	.db #08,#88						; R8  = 0x08 (VR=64K, color0 opaque)
	.db #00,#89						; R9  = 192 lines, no interlace
	.db #00,#8A, #00,#8B, #00,#8C, #00,#8D, #00,#8E, #00,#8F
	.db #00,#90, #00,#91
	.db #00,#92						; R18 = display adjust 0 (centered)
	.db #00,#93						; R19 = line-interrupt line 0
	.db #00,#94, #00,#95, #00,#96
	.db #00,#97						; R23 = vertical scroll 0
	.db #00,#99						; R25 = 0 (V9958 modes/scroll)
	.db #00,#9A						; R26 = 0 (V9958 horiz scroll H)
	.db #00,#9B						; R27 = 0 (V9958 horiz scroll L)

; boot_stub: runs from #E000 (page-3 RAM). Switches page 1 to slot 2 (and
; page 2 to RAM for megaroms / slot 2 for plain ROMs, like the real BIOS)
; and CALLS the cartridge INIT at (0x4002) the way
; the BIOS boots a cartridge. Single-stage games never return. If the INIT
; returns (two-stage Konami that hooked H.STKE expecting the BIOS to chain),
; invoke the hook ourselves -- without any hardware reset (megaram decays).
boot_stub:
	ld   sp, #F380					; standard MSX boot stack (page-3 RAM)
	ld   a, #02						; page 1 (0x4000) -> slot 2
	ld   hl, #4000
	call ENASLT
	ld   a, #02						; page 2 (0x8000) -> slot 2
	ld   hl, #8000
	call ENASLT
	xor  a							; bancos a su valor canonico 0,1,2,3: el sondeo
	ld   (#5000), a					; de RAM de la BIOS escribe en 0x8000 de todos los
	ld   a, 1						; slots al arrancar y (en modo Konami4, el de
	ld   (#7000), a					; encendido) corrompe reg2; los juegos de dos fases
	ld   a, 2						; (MG2) confian en el mapeo por defecto al entrar
	ld   (#9000), a					; en la pagina 2. Aqui el modo aun es SCC (load).
	ld   a, 3
	ld   (#B000), a
	ld   a, (P2_SLOT)				; v2.0.1: pag.2 -> RAM en megaroms (la BIOS real
	ld   hl, #8000					; arranca asi; los bancos canonicos de arriba se
	call ENASLT						; fijaron con la megaram aun mapeada) / megaram
									; solo en ROMs lineales (MAP_PLAIN)
	ld   a, #D4						; ahora si: mapper real del juego via SWIO
	out  (#40), a
	ld   a, (MAP_SWIO)
	out  (#41), a
	; #22 FIX (page-flip MG2): el menu deja R#13=0x10 (blink "steady" de la barra
	; de seleccion). En el VDP eso fija FF_BLINK_STATE=1 -> el bit de pagina (R#2
	; bit5) se fuerza a 0 SIEMPRE (vdp_graphic4567.vhd:249 y 505-507). MG2 hace el
	; page-flip carga->escenario via R#2 pero NO reescribe R#13 (asume el 0 que
	; deja la BIOS), asi que la imagen se queda clavada en pagina 0 y la carga no
	; se borra. DOS deja R#13=0, por eso SofaRun si funciona. Limpiamos R#13/R#12
	; (estado de blink como tras un SCREEN de la BIOS) antes de llamar al INIT.
	ld   bc, #000D					; B=0 dato, C=13 reg -> R#13 = 0 (blink OFF)
	call #0047						; WRTVDP (actualiza HW + espejo BIOS)
	ld   bc, #000C					; R#12 = 0 (colores de blink), por limpieza
	call #0047						; WRTVDP
	; el logo de arranque (MSX Barcelona) pinta su bitmap con comandos VDP y puede
	; dejar el motor del V9938/58 a medias (CE asserted). MG2, al entrar, hace un
	; HMMV de borrado (el "fundido"); si el motor sigue ocupado no cuaja. R#46=0 =
	; comando STOP: aborta y limpia CE. Directo por puerto (WRTVDP no cubre R#46).
	xor  a
	out  (#99), a					; dato = 0
	ld   a, #AE						; #80|46 -> seleccionar R#46 (registro de comando)
	out  (#99), a					; R#46 = 0 = STOP -> aborta comando pendiente, limpia CE
	ld   hl, (#4002)				; cartridge INIT vector
	ld   bc, boot_ret - boot_stub + #E000
	push bc							; "direccion de retorno" = boot_ret (en el stub)
	ei
	jp   (hl)						; call INIT (1 fase: no vuelve)
boot_ret:
	di								; INIT retorno = juego de 2 fases (H.STKE)
	ld   a, (#FEDA)
	cp   #C9
	jr   z, boot_dead				; sin hook y sin tomar control: nada que hacer
	ld   sp, #F380
	ei
	call #FEDA						; arrancar fase 2 (CALLF inter-slot, no vuelve)
boot_dead:
	jr   boot_dead
boot_stub_end:
; -----------------------------------------------------------------------------
; browse: scrolling browser over ENT_ARRAY. Cursor up/down move the selection,
; RETURN shows the selected entry, ESC returns to the main menu. Input goes via
; the BIOS (ei/halt/CHSNS/CHGET) so the cursor keys are delivered (same method as
; the config menu; the direct PPI matrix scan missed row 8).
; -----------------------------------------------------------------------------
browse:
	; entering/re-entering the browser: assert the marquee gate. The SD_READY
	; premount fast-path (main_action_sdrom: jp nz, browse) and the File-Hunter
	; results path (.f1_fin) jump straight here WITHOUT calling select_partition,
	; which is the only place that sets BROWSING=1. Since main_menu_restart clears
	; BROWSING on every "return to menu", the flag stayed 0 and marquee_tick bailed
	; out immediately -> the long-name scroll was silently frozen (regression
	; f5e064d, the "mount SD under the logo" premount). Set it here so every entry
	; and every redraw re-entry re-asserts it in one spot.
	ld   a, 1
	ld   (BROWSING), a
browse_redraw:						; global: asMSX no ve locales desde browse_enter/
	call draw_browser				; browse_back -> etiquetas globales propias
browse_key:							; global: bucle de teclado SIN redibujar (re-entrada
									; con el navegador YA pintado: refresh_list ya pinto el
									; listado; jp browse repintaba encima = doble listado)
.br_key:
	call browse_getkey				; A = key code
	ld   c, a						; modo File-Hunter: fh_key_filter (CALL) se come
	ld   a, (FH_MODE)				; las teclas SD/lanzado (devuelve A=0 -> cae al
	or   a							; final del dispatch = repetir bucle) o salta a
	ld   a, c						; la accion FH descartando el retorno; el resto
	call nz, fh_key_filter			; (cursores, '/', H) sigue el dispatch normal
	cp   #1E						; cursor up
	jp   z, .br_up
	cp   #1F						; cursor down
	jp   z, .br_down
	cp   #1C						; cursor right (next column)
	jp   z, .br_right
	cp   #1D						; cursor left (prev column)
	jp   z, .br_left
	cp   #0D						; RETURN
	jp   z, browse_enter
	cp   #08						; BACKSPACE -> parent folder
	jp   z, browse_back
	cp   '/'						; busqueda por nombre
	jp   z, .br_search
	cp   #09						; TAB -> next partition (multi-partition cards)
	jp   z, .br_nextpart
	cp   #53						; 'S' -> Settings (Ajustes)
	jp   z, config_menu_entry
	cp   #73						; 's'
	jp   z, config_menu_entry
	cp   #57						; 'W' -> WiFi config (ESP ROM menu)
	jp   z, main_action_wifi
	cp   #77						; 'w'
	jp   z, main_action_wifi
	cp   #54						; 'T' -> Cinta web (TSX streaming)
	jp   z, main_action_tsxweb
	cp   #74						; 't'
	jp   z, main_action_tsxweb
	cp   #46						; 'F' -> File-Hunter (buscar y listar online)
	jp   z, fh_browse
	cp   #66						; 'f'
	jp   z, fh_browse
	cp   #48						; 'H' -> help overlay
	jp   z, .br_help
	cp   #68						; 'h'
	jp   z, .br_help
	cp   #52						; 'R' -> filter: ROMs only
	jp   z, .br_from
	cp   #72						; 'r'
	jp   z, .br_from
	cp   #44						; 'D' -> filter: disks only
	jp   z, .br_fdsk
	cp   #64						; 'd'
	jp   z, .br_fdsk
	cp   #41						; 'A' -> filter: all
	jp   z, .br_fall
	cp   #61						; 'a'
	jp   z, .br_fall
	cp   #1B						; ESC -> arrancar sistema (boot the OS)
	jp   z, boot_system
	jp   .br_key					; (jp: el hook FH dejo .br_key fuera de rango jr)
.br_help:
	call help_screen
	jp   browse_redraw
.br_from:
	xor  a							; FILTER = 0 (ROM)
	jr   .br_setfilter
.br_fdsk:
	ld   a, 1						; FILTER = 1 (DSK)
	jr   .br_setfilter
.br_fall:
	ld   a, 2						; FILTER = 2 (ALL)
.br_setfilter:
	ld   (FILTER), a
	call scan_current				; re-scan current dir applying the new filter
	xor  a
	ld   (BR_SEL), a
	ld   (BR_TOP), a
	call draw_tabs					; update active-tab highlight
	call refresh_list				; soft repaint (no full-screen flicker)
	jp   .br_key
.br_nextpart:
	ld   a, (PART_CNT)
	cp   2
	jp   c, .br_key					; only one partition -> ignore TAB
	ld   a, (CUR_PART)
	inc  a							; next index, wrap to 0 at PART_CNT
	ld   hl, PART_CNT
	cp   (hl)
	jr   c, .bnp_go
	xor  a
.bnp_go:
	call select_partition			; switch partition (re-scans its root)
	jp   c, .br_key					; SD error -> stay
	call refresh_list				; repaint only the list+footer (bars don't flash)
	jp   .br_key
.br_up:
	ld   a, (BR_SEL)
	ld   (BR_OLD), a				; remember old selection
	or   a
	jr   nz, .bu_dec
	; at the top -> wrap to the LAST entry (fast jump to the end)
	ld   a, (ENT_COUNT)
	or   a
	jp   z, .br_key					; empty list
	dec  a
	ld   (BR_SEL), a
	jp   .br_move
.bu_dec:
	dec  a
	ld   (BR_SEL), a
	jp   .br_move
.br_down:
	ld   a, (ENT_COUNT)
	ld   b, a
	ld   a, (BR_SEL)
	ld   (BR_OLD), a				; remember old selection
	inc  a
	cp   b
	jr   c, .bd_set					; sel+1 < count -> normal move down
	; at the bottom -> wrap to the FIRST entry
	xor  a
	ld   (BR_SEL), a
	jp   .br_move
.bd_set:
	ld   (BR_SEL), a
	jp   .br_move
.br_right:
	ld   a, (BR_SEL)
	add  a, VISIBLE				; sel + 22 (jump to next column / down a page-half)
	ld   c, a
	ld   a, (ENT_COUNT)
	cp   c
	jp   c, .br_key					; candidate beyond list
	jp   z, .br_key
	ld   a, (BR_SEL)
	ld   (BR_OLD), a
	ld   a, c
	ld   (BR_SEL), a
	jp   .br_move
.br_left:
	ld   a, (BR_SEL)
	cp   VISIBLE
	jp   c, .br_key					; already in first column
	ld   (BR_OLD), a
	sub  VISIBLE
	ld   (BR_SEL), a
	jp   .br_move
.br_search:
	; Busqueda por nombre (subcadena, insensible a mayusculas). '/' abre el
	; prompt en la fila 0; ENTER busca la SIGUIENTE coincidencia desde la
	; seleccion actual (con vuelta), ESC cancela. Reusa name_contains.
	ld   a, (ENT_COUNT)
	or   a
	jp   z, .br_key					; lista vacia
	ld   hl, #0100
	call POSIT
	ld   hl, srchStr				; "Buscar: "
	call print_string
	ld   hl, SRCH_BUF
	ld   b, 0						; longitud actual
.bs_key:
	push hl							; browse_getkey (marquee_tick/poll_joy) machaca
	push bc							; HL y BC: preservar puntero y longitud
	call browse_getkey
	pop  bc
	pop  hl
	cp   #0D
	jr   z, .bs_go
	cp   #1B
	jp   z, browse_redraw			; cancelar (redibuja y limpia el prompt)
	cp   #08
	jr   z, .bs_del
	cp   ' '
	jr   c, .bs_key					; controles fuera
	cp   #7F
	jr   nc, .bs_key
	ld   c, a
	ld   a, b
	cp   12
	jr   nc, .bs_key				; buffer lleno
	ld   a, c
	cp   'a'
	jr   c, .bs_st
	cp   'z'+1
	jr   nc, .bs_st
	sub  #20						; needle en MAYUSCULAS (name_contains)
.bs_st:
	ld   (hl), a
	inc  hl
	inc  b
	call CHPUT						; eco
	jr   .bs_key
.bs_del:
	ld   a, b
	or   a
	jr   z, .bs_key
	dec  hl
	dec  b
	ld   a, #08
	call CHPUT
	ld   a, ' '
	call CHPUT
	ld   a, #08
	call CHPUT
	jr   .bs_key
.bs_go:
	ld   (hl), 0					; terminar la consulta
	ld   a, b
	or   a
	jp   z, browse_redraw			; consulta vacia
	ld   a, (BR_SEL)
	ld   d, a						; d = indice de partida
	ld   a, (ENT_COUNT)
	ld   e, a						; e = entradas por probar
.bs_loop:
	ld   a, d
	inc  a
	ld   hl, ENT_COUNT
	cp   (hl)
	jr   c, .bs_idx
	xor  a							; vuelta al principio
.bs_idx:
	ld   d, a
	push de
	call ent_addr					; A -> HL = registro de la entrada
	ld   bc, NAME_OFF
	add  hl, bc
	ld   (TAGPTR), hl				; haystack = nombre del fichero
	ld   hl, SRCH_BUF
	call name_contains
	pop  de
	jr   c, .bs_found
	dec  e
	jr   nz, .bs_loop
	jp   browse_redraw				; sin coincidencias
.bs_found:
	ld   a, d
	ld   (BR_SEL), a
	call ensure_visible				; recolocar la ventana si hace falta
	jp   browse_redraw				; redibuja todo (borra el prompt)

.br_move:
	; Repaint only the old and new rows so the '>' marker moves without a
	; full-screen redraw (no flicker). Full redraw only when the page scrolls.
	ld   a, (BR_TOP)
	ld   (BR_OLDTOP), a
	call ensure_visible
	ld   a, (BR_TOP)
	ld   hl, BR_OLDTOP
	cp   (hl)
	jp   nz, .br_scroll				; page scrolled -> repaint rows in place (no clear)
	ld   a, (BR_OLD)
	call draw_entry					; repaint old row (clears its '>')
	ld   a, (BR_SEL)
	call draw_entry					; repaint new row (draws '>')
	jp   .br_key
.br_scroll:
	call draw_rows					; redraw the visible rows WITHOUT clearing screen
	jp   .br_key
browse_enter:						; global: el auto-lanzado de File-Hunter entra aqui
.br_enter:
	ld   a, (ENT_COUNT)
	or   a
	jp   z, browse_key				; empty list (pantalla intacta: no redibujar)
	ld   a, (BR_SEL)
	call ent_addr					; hl = record
	ld   a, (hl)					; type (0=dir, 1=rom, 2=dsk)
	or   a
	jr   z, .br_isdir				; 0 = directory
	dec  a
	jp   z, .br_selrom				; 1 = rom -> load to megaram + launch
	dec  a
	jp   z, .br_seldsk				; 2 = dsk -> Nextor disk emulation + boot
	jp   browse					; (tipo inesperado -> ignorar)
.br_isdir:
	; --- directory: push current cluster, descend ---
	ld   a, (DIR_SP)
	cp   8
	jp   nc, browse_key				; stack full -> ignore (no redibujar)
	add  a, a						; DIR_STACK[DIR_SP] = CUR_CLUS (4 bytes/nivel)
	add  a, a
	ld   e, a
	ld   d, 0
	ld   hl, DIR_STACK
	add  hl, de
	ex   de, hl
	ld   hl, CUR_CLUS
	call w_copy
	ld   a, (DIR_SP)
	inc  a
	ld   (DIR_SP), a
	ld   a, (BR_SEL)				; CUR_CLUS = selected dir's first cluster
	call ent_addr
	inc  hl							; record+1 = cluster (dword)
	ld   de, CUR_CLUS
	call w_copy
	call scan_current
	xor  a
	ld   (BR_SEL), a
	ld   (BR_TOP), a
	call refresh_list				; soft repaint of the new directory (no flicker)
	jp   browse_key					; NO jp browse: draw_browser repintaba encima (doble listado)
.br_selrom:
	; --- selected file: load it straight into the megaram, then offer to launch.
	;     No debug dump, no separate "load" step -> fastest path to launch. ---
	ld   a, (BR_SEL)
	call ent_addr
	ld   (BR_REC), hl				; record (size at +SIZE_OFF, name at +NAME_OFF)
	inc  hl							; record+1 = cluster (dword)
	ld   de, FILE_CLUS
	call w_copy
	; ---- pantalla de lanzamiento: LAYOUT FIJO 80x24 (rediseno v1.9c) ----
	; fila 2: titulo | 3+21: linea fina | 6/8: fichero | 11: Tamano/Mapper/SRAM
	; en columnas fijas | 15: barra [64 celdas] | 17: estado | 22: teclas.
	; Cada campo dinamico se LIMPIA a ancho fijo antes de reimprimir -> nada
	; se mezcla ni deja residuos (tamano de 1-4 digitos, mappers de 6-15 chars).
	; Se pinta YA (detect_mapper tarda 2-3s en ROMs grandes; el spinner gira en
	; la fila de estado para que el Enter no parezca un cuelgue).
	call .bls_skel					; esqueleto COMUN ROM/DSK (limpia, marquee off,
									; lineas, Fichero+nombre, marco de la barra)
	ld   hl, #2402					; titulo centrado (fila 2)
	call POSIT
	ld   hl, titleRomStr
	call print_string
	ld   hl, analyzStr				; estado (fila 17): "Analizando ROM..." + spinner
	call .bsr_status
	call detect_mapper				; mapper por CONTENIDO (estilo Picoverse/openMSX);
									; el nombre solo decide si el scan no ve nada.
									; Evita falsos positivos del nombre (p.ej. "Konami"
									; del fabricante forzaba Konami4 a juegos SCC).
	; SRAM de cartucho: por defecto OFF; tags KOEI/SRAM en el nombre la activan
	ld   hl, (BR_REC)				; asegurar TAGPTR -> nombre para los tags SRAM
	ld   de, NAME_OFF
	add  hl, de
	ld   (TAGPTR), hl
	xor  a
	ld   (SRAM_FLAG), a
	call .bsr_isascii				; la SRAM emulada SOLO existe en ASCII8/16; en
	jr   nc, .bsr_srdone			; Konami/SCC ni se activa (evita liar con juegos
									; parcheados que fingen Game Master y cuelgan)
	ld   hl, tag_koei
	call name_contains
	jr   c, .bsr_sron
	ld   hl, tag_sram
	call name_contains
	jr   nc, .bsr_srdone
.bsr_sron:
	ld   a, 1
	ld   (SRAM_FLAG), a
.bsr_srdone:
	ld   a, (MAPPER_ID)
	cp   #FF
	jr   nz, .bsr_have
	call detect_mapper
.bsr_have:
	; fila de datos (fila 11): Tamano / Mapper / SRAM en COLUMNAS FIJAS (la
	; pantalla ya esta pintada; el repintado del campo de estado tapa el spinner)
	ld   hl, #050B
	call POSIT
	ld   hl, romClusStr				; "Tamano:" (col 5)
	call print_string
	ld   hl, #0D0B					; valor (col 13, campo fijo 6: "2048K")
	ld   b, 6
	call clear_at
	call print_rom_kb
	ld   a, 'K'
	call CHPUT
	ld   hl, #1B0B
	call POSIT
	ld   hl, romSpcStr				; "Mapper:" (col 27)
	call print_string
	call .bsr_mprint				; valor (col 35, campo fijo 15)
	call .bsr_sprint				; "SRAM: On/Off" (col 57, solo ASCII8/16)
	ld   hl, loadingStr				; estado: "Cargando ROM en megaram..."
	call .bsr_status
	call load_rom					; carga (barra de progreso escalada, fila 15)
	ld   hl, doneStr				; estado: "ROM cargada."
	call .bsr_status
	call .bsr_footer				; teclas (fila 22): ya se puede lanzar
.bsr_lk:
	call browse_getkey
	cp   #0D
	jp   z, launch_rom
	cp   #1B
	jp   z, meg_disarm_esc			; _182c: desarmar la megaram antes de volver (banco A010)
	cp   'M'
	jp   z, .bsr_map
	cp   'm'
	jp   z, .bsr_map
	cp   'S'
	jp   z, .bsr_srtg
	cp   's'
	jp   z, .bsr_srtg
	jr   .bsr_lk
.bsr_srtg:
	call .bsr_isascii				; la tecla S solo actua en ASCII8/16 (en Konami/
	jr   nc, .bsr_lk				; SCC no hay SRAM: ignorar para no confundir)
	ld   a, (SRAM_FLAG)				; conmutar SRAM de cartucho para este lanzamiento
	xor  1
	ld   (SRAM_FLAG), a
	call .bsr_sprint
	jr   .bsr_lk
.bsr_sprint:
	call .bsr_isascii				; SRAM solo en ASCII8/16: en otros mappers NO se
	jr   nc, .bsr_sprcl				; muestra el grupo (columna limpia)
	ld   hl, #390B
	call POSIT
	ld   hl, sramStr				; "SRAM:" (col 57, fila 11)
	call print_string
	ld   hl, #3F0B					; valor On/Off (col 63)
	ld   a, (SRAM_FLAG)
	jp   print_on_off				; imprime On/Off y retorna al llamador
.bsr_sprcl:
	ld   hl, #390B					; no-ASCII: borrar el grupo "SRAM: Off" entero
	ld   b, 9						; (por si se venia de ASCII via tecla M)
	jp   clear_at
.bsr_name:							; nombre (fila 8, col 5): max 72; si es mas largo,
	ld   hl, (BR_REC)				; corta a 69 + "..." para que NUNCA haga wrap
	ld   de, NAME_OFF
	add  hl, de
	ex   de, hl						; DE = nombre
	ld   h, d						; strlen acotado (73 = "mas de 72")
	ld   l, e
	ld   b, 73
	ld   c, 0
.bsr_nl:
	ld   a, (hl)
	or   a
	jr   z, .bsr_nd
	inc  hl
	inc  c
	djnz .bsr_nl
.bsr_nd:
	ld   hl, #0508
	call POSIT
	ex   de, hl						; HL = nombre
	ld   a, c
	cp   73
	jr   c, .bsr_nfit
	ld   b, 69						; no cabe: 69 chars + "..."
	call print_string_max
	ld   b, 3
.bsr_ndots:
	ld   a, '.'
	call CHPUT
	djnz .bsr_ndots
	ret
.bsr_nfit:
	jp   print_string
.bsr_status:						; HL = texto -> campo de estado (fila 17, col 26,
	push hl							; ancho fijo 30: cada mensaje tapa el anterior
	ld   hl, #1A11					; y el spinner del analisis)
	ld   b, 30
	call clear_at
	pop  hl
	jp   print_string
.bsr_mprint:						; valor del mapper en campo fijo de 15 (fila 11)
	ld   hl, #230B
	ld   b, 15
	call clear_at
	jp   print_mapper_name
.bls_skel:							; ===== esqueleto COMUN de las pantallas de lanzar
	call cls_browser				; ROM y DSK (identicas): limpia pantalla, apaga el
	xor  a							; marquee del browser (BROWSING=0; si no, nombres
	ld   (BROWSING), a				; >59 chars se pintan en scroll ENCIMA; browse lo
									; re-asserta al volver con ESC, como la ayuda),
	ld   a, 3						; lineas finas (filas 3 y 21),
	call draw_hline
	ld   a, 21
	call draw_hline
	ld   hl, #0306
	call POSIT
	ld   hl, romInfoStr				; "Fichero:" (fila 6)
	call print_string
	call .bsr_name					; nombre (fila 8): max 72, con "..." si es mas largo
	; marco de la barra (fila 15): '[' col8 + 64 celdas de linea fina + ']' col73.
	; Las celdas (char #10) van por FILVRM directo a la name table: CHPUT IGNORA
	; los codigos de control 0x00-0x1F (mismo motivo por el que draw_hline usa
	; FILVRM). Name table en 0x0000, 80 cols: fila fisica 14 * 80 + col fisica 8.
	ld   hl, #0468					; 14*80+8 = 1128
	ld   bc, 64
	ld   a, #10
	call FILVRM
	ld   hl, #080F					; '[' (col 8)
	call POSIT
	ld   a, '['
	call CHPUT
	ld   hl, #490F					; ']' (col 73)
	call POSIT
	ld   a, ']'
	jp   CHPUT
.bsd_fillbar:						; barra al 100% de golpe (montaje DSK: sin carga
	ld   hl, #090F					; larga; misma estetica que la ROM al terminar)
	call POSIT
	ld   b, 64
.bsd_fb:
	ld   a, #DB
	call CHPUT
	djnz .bsd_fb
	ret
.bsd_err:							; HL = mensaje de error DSK -> estado + pie "pulsa
	call .bsr_status				; una tecla" + esperar y volver al navegador
	ld   hl, #0116
	ld   b, 79
	call clear_at
	ld   hl, #1A16					; "Pulsa una tecla..." (30 chars) centrado, col 26
	call POSIT
	ld   hl, helpEndStr
	call print_string
	call browse_getkey
	jp   browse
.bsr_isascii:						; CF=1 si MAPPER_ID es ASCII8/16 (unica con SRAM)
	ld   a, (MAPPER_ID)
	cp   MAP_A8_ID
	jr   z, .bsr_isa1
	cp   MAP_A16_ID
	jr   z, .bsr_isa1
	or   a							; CF=0
	ret
.bsr_isa1:
	scf
	ret
.bsr_footer:						; pie de teclas (fila 22), centrado; variante con
	ld   hl, #0116					; S=SRAM solo en ASCII8/16. Se limpia la fila
	ld   b, 79						; entera antes -> sin residuos entre variantes
	call clear_at
	call .bsr_isascii
	jr   c, .bsr_ftA
	ld   hl, #1316					; variante corta centrada (43 chars, col 19)
	call POSIT
	ld   hl, launch2bStr
	jp   print_string
.bsr_ftA:
	ld   hl, #0E16					; variante con SRAM centrada (54 chars, col 14)
	call POSIT
	ld   hl, launch2Str
	jp   print_string
.bsr_map:
	ld   a, (MAPPER_ID)				; ciclar plain->Konami->SCC->ASCII8->ASCII16
	cp   MAP_PLAIN
	ld   b, MAP_KON_ID
	jr   z, .bsr_ms
	cp   MAP_KON_ID
	ld   b, MAP_SCC_ID
	jr   z, .bsr_ms
	cp   MAP_SCC_ID
	ld   b, MAP_A8_ID
	jr   z, .bsr_ms
	cp   MAP_A8_ID
	ld   b, MAP_A16_ID
	jr   z, .bsr_ms
	ld   b, MAP_PLAIN
.bsr_ms:
	ld   a, b
	ld   (MAPPER_ID), a
	call .bsr_mprint				; solo el campo del mapper (limpia 15 y pinta:
									; columnas fijas -> el tamano NO se toca)
	call .bsr_isascii				; si al ciclar deja de ser ASCII, forzar SRAM OFF
	jr   c, .bsr_mkeep
	xor  a
	ld   (SRAM_FLAG), a
.bsr_mkeep:
	call .bsr_sprint				; refrescar/limpiar el grupo SRAM y el pie
	call .bsr_footer
	jp   .bsr_lk

.br_seldsk:
	; --- selected .dsk: set up Nextor disk-emulation mode and boot it ---
	; Nextor checks RAM #A000 for the "NEXTOR_EMU_DATA" record on every boot
	; (one-time mode). We run in the cartridge INIT (slot 3-1) DURING the cold-boot
	; slot scan, BEFORE Nextor (slot 3-2) initialises -> we just write the record
	; and let the boot continue; Nextor reads it and mounts the image as drive A:
	; in MSX-DOS 1 mode, then runs its boot sector. No reset needed.
	ld   a, (BR_SEL)
	call ent_addr
	ld   (BR_REC), hl
	inc  hl							; record+1 = first cluster of the .dsk (dword)
	ld   de, FILE_CLUS
	call w_copy
	; ---- MISMA pantalla que lanzar ROM (esqueleto comun .bls_skel): titulo,
	;      Fichero+nombre, fila de datos en columnas fijas, barra, estado, pie ----
	call .bls_skel
	ld   hl, #2302					; titulo centrado (fila 2): "Lanzar disco" (12)
	call POSIT
	ld   hl, dskTitleStr
	call print_string
	ld   hl, #050B					; fila de datos (fila 11), columnas fijas
	call POSIT
	ld   hl, romClusStr				; "Tamano:" (col 5)
	call print_string
	ld   hl, #0D0B					; valor (col 13, campo 6)
	ld   b, 6
	call clear_at
	call print_rom_kb
	ld   a, 'K'
	call CHPUT
	ld   hl, #1B0B
	call POSIT
	ld   hl, dskTipoStr				; "Tipo:" (col 27, donde la ROM pone Mapper:)
	call print_string
	ld   hl, #230B					; valor (col 35, campo 15)
	ld   b, 15
	call clear_at
	ld   hl, dskTipoValStr			; "Disco (Nextor)"
	call print_string
	ld   hl, dskReadyStr			; estado: "DSK listo para montar."
	call .bsr_status
	ld   hl, #0116					; pie DSK centrado (39 chars, col 21)
	ld   b, 79
	call clear_at
	ld   hl, #1516
	call POSIT
	ld   hl, dskAskStr				; "RETURN = Montar y lanzar   ESC = Volver"
	call print_string
.bsd_ask:
	call browse_getkey
	cp   #0D
	jr   z, .bsd_go					; RETURN -> mount + launch
	cp   #1B
	jp   z, browse				; (hook FH global)				; ESC -> back to the browser
	jr   .bsd_ask
.bsd_go:
	ld   hl, dskMountStr			; estado: "Montando disco Nextor..."
	call .bsr_status
	; 1) the image must be unfragmented (Nextor maps a linear sector range)
	call dsk_check_contig
	jr   nc, .bsd_contig
	ld   hl, dskFragStr				; error al campo de estado + "pulsa una tecla"
	jp   .bsd_err
.bsd_contig:
	; 2) absolute start LBA of the .dsk -> DSK_LBA
	ld   hl, FILE_CLUS
	ld   de, W_TMP
	call w_copy
	call clus2lba					; SD_LBA = abs LBA of the .dsk first cluster
	ld   hl, (SD_LBA+0)
	ld   (DSK_LBA+0), hl
	ld   hl, (SD_LBA+2)
	ld   (DSK_LBA+2), hl
	; 3) image size in 512-byte sectors = ceil(size/512) = (size+511)>>9  (16-bit)
	ld   hl, (BR_REC)
	ld   de, SIZE_OFF
	add  hl, de						; hl -> size dword (LE) at record+SIZE_OFF
	ld   e, (hl)
	inc  hl
	ld   d, (hl)
	inc  hl
	ld   c, (hl)
	inc  hl
	ld   b, (hl)					; bcde = 32-bit size (b=MSB, e=LSB)
	ld   hl, #01FF					; + 511
	add  hl, de
	ex   de, hl
	ld   hl, 0
	adc  hl, bc						; hl:de = size+511 (hl = high word)
	ld   b, h
	ld   c, l						; bc = high word -> c = byte2, b = byte3
	ld   l, d						; (size+511) >> 8  -> l=byte1, h=byte2 (floppy: byte3=0)
	ld   h, c
	srl  h							; >> 1  => >> 9 total
	rr   l
	ld   (DSK_SECS), hl				; sectors in the image
	; 4) sector del data-file de emulacion:
	;    FAT32 -> sector reservado de la particion (FAT_LBA-2): los reservados
	;    (>=32 en FAT32) solo usan 0/1/6/7, asi que rsvd-2 esta libre, es
	;    invisible para el PC y no requiere crear ningun fichero.
	;    FAT16 -> fichero NEXTOR.EMU en la raiz (rsvd=1, no hay hueco), oculto.
	ld   a, (FS32)
	or   a
	jr   z, .bsd_emu16
	ld   hl, (FAT_LBA+0)			; EMU_LBA = FAT_LBA - 2 (32-bit)
	ld   de, 2
	or   a
	sbc  hl, de
	ld   (EMU_LBA+0), hl
	ld   hl, (FAT_LBA+2)
	ld   de, 0
	sbc  hl, de
	ld   (EMU_LBA+2), hl
	jp   .bsd_build
.bsd_emu16:
	call find_emufile
	jr   nc, .bsd_haveemu
	call create_emufile				; not found -> create it (CF=1 on failure)
	jr   nc, .bsd_haveemu
.bsd_noemu:
	ld   hl, dskNoEmuStr			; error al campo de estado + "pulsa una tecla"
	jp   .bsd_err
.bsd_haveemu:
	; FILE_CLUS now = NEXTOR.EMU first cluster -> its abs LBA = the data-file sector.
	; Safety net: never write with cluster < 2 (would target the root dir /
	; reserved area and corrupt the filesystem).
	ld   hl, FILE_CLUS
	ld   de, W_TMP
	call w_copy
	call w_is_eoc					; CF=1 si cluster < 2 o reservado
	jp   c, .bsd_noemu				; invalid cluster -> abort, do NOT write
	call clus2lba					; (W_TMP intacto tras w_is_eoc)
	ld   hl, (SD_LBA+0)
	ld   (EMU_LBA+0), hl
	ld   hl, (SD_LBA+2)
	ld   (EMU_LBA+2), hl
.bsd_build:
	; 5) build the emulation data file in SD_BUF and write it to the EMU_LBA sector
	call build_emu_datafile
	ld   hl, (EMU_LBA+0)			; destino EXPLICITO (no confiar en SD_LBA residual:
	ld   (SD_LBA+0), hl				; en el camino FAT32 SD_LBA traia el sector del .dsk
	ld   hl, (EMU_LBA+2)			; y la escritura corrompia la imagen)
	ld   (SD_LBA+2), hl
	call sd_write_sector
	ld   a, (SD_STATUS)
	or   a
	jr   z, .bsd_wrok
	ld   hl, dskWrErrStr			; error al campo de estado + "pulsa una tecla"
	jp   .bsd_err
.bsd_wrok:
	call .bsd_fillbar				; barra al 100%: montaje OK, arrancamos
	; 6) one-time pointer at #A000 -> the data file (device 1, LUN 1, EMU_LBA)
	ld   hl, emuSig
	ld   de, #A000
	ld   bc, 16
	ldir
	ld   a, 1
	ld   (#A010), a					; device index (WonderTANG SD) [verify if needed]
	ld   a, 1
	ld   (#A011), a					; LUN
	ld   hl, (EMU_LBA+0)
	ld   (#A012), hl
	ld   hl, (EMU_LBA+2)
	ld   (#A014), hl
	ld   a, 1
	ld   (DSK_PEND), a				; el 2o pase del INIT reescribira el registro
	jp   boot_system				; continue boot with Nextor ON -> Nextor emulates A:
browse_back:						; global (pareja del anterior)
.br_back:
	ld   a, (DIR_SP)
	or   a
	jp   z, browse_key				; already at root (no redibujar)
	dec  a
	ld   (DIR_SP), a
	add  a, a						; CUR_CLUS = DIR_STACK[DIR_SP] (4 bytes/nivel)
	add  a, a
	ld   e, a
	ld   d, 0
	ld   hl, DIR_STACK
	add  hl, de
	ld   de, CUR_CLUS
	call w_copy
	call scan_current
	xor  a
	ld   (BR_SEL), a
	ld   (BR_TOP), a
	call refresh_list				; soft repaint of the parent directory (no flicker)
	jp   browse_key					; NO jp browse: evitar doble listado (ver .br_isdir)

; rom_kb: HL = tamano de la ROM seleccionada en KB (desde BR_REC). Lo usan
; print_rom_kb (mostrar) y load_rom (escalar la barra de progreso).
rom_kb:
	ld   hl, (BR_REC)
	ld   de, SIZE_OFF+1
	add  hl, de
	ld   a, (hl)					; size byte 1
	srl  a
	srl  a
	ld   c, a
	ld   hl, (BR_REC)
	ld   de, SIZE_OFF+2
	add  hl, de
	ld   e, (hl)
	inc  hl
	ld   d, (hl)
	ex   de, hl						; hl = size >> 16
	add  hl, hl
	add  hl, hl
	add  hl, hl
	add  hl, hl
	add  hl, hl
	add  hl, hl						; * 64
	ld   e, c
	ld   d, 0
	add  hl, de						; hl = KB
	ret

; print_rom_kb: print the selected ROM's size in KB (decimal) from BR_REC.
print_rom_kb:
	call rom_kb
	jp   print_dec16

; print_mapper_name: print the detected mapper's name (MAPPER_ID).
print_mapper_name:
	ld   a, (MAPPER_ID)
	cp   MAP_KON_ID
	jr   z, .pmn_kon
	cp   MAP_SCC_ID
	jr   z, .pmn_scc
	cp   MAP_A8_ID
	jr   z, .pmn_a8
	cp   MAP_A16_ID
	jr   z, .pmn_a16
	cp   MAP_PLAIN
	jr   z, .pmn_plain
	ld   hl, mapUnkStr
	jp   print_string
.pmn_plain:
	ld   hl, mapPlainStr
	jp   print_string
.pmn_kon:
	ld   hl, mapKonStr
	jp   print_string
.pmn_scc:
	ld   hl, mapSccStr
	jp   print_string
.pmn_a8:
	ld   hl, mapA8Str
	jp   print_string
.pmn_a16:
	ld   hl, mapA16Str
	jp   print_string

; ensure_visible: adjust BR_TOP so BR_SEL is within the visible window.
ensure_visible:
	ld   a, (BR_SEL)
	ld   hl, BR_TOP
	cp   (hl)
	jr   nc, .ev1
	ld   (BR_TOP), a				; sel < top -> top = sel
	ret
.ev1:
	ld   a, (BR_TOP)
	add  a, VISIBLE
	ld   b, a						; top + VISIBLE
	ld   a, (BR_SEL)
	cp   b
	ret  c							; sel < top+VISIBLE -> already visible
	sub  VISIBLE - 1
	ld   (BR_TOP), a				; top = sel - (VISIBLE-1)
	ret

; prompt_getkey: como browse_getkey pero SOLO teclado y SIN marquee_tick. Un
; prompt de texto en la fila 0 (busqueda File-Hunter) no debe ser perturbado por
; el marquee, que al hacer scroll de un nombre largo reposiciona el cursor a la
; fila de la lista -> lo tecleado caia sobre la lista, no sobre el prompt.
prompt_getkey:
	ei
.pgk_loop:
	halt
	call CHSNS						; tecla pendiente?
	jr   z, .pgk_loop
	call CHGET
	or   a
	jr   z, .pgk_loop
	ret

; browse_getkey: wait for input from the keyboard (cursors via CHGET) OR the
; joystick (GTSTCK/GTTRIG, edge-detected) and return it as a key code.
browse_getkey:
	ei
.bgk_loop:
	halt
	call marquee_tick				; scroll the selected long name while idle (browser only)
	call CHSNS						; keyboard pending?
	jr   z, .bgk_joy
	call CHGET
	or   a
	jr   z, .bgk_loop
	ret
.bgk_joy:
	call poll_joy					; A = joystick code (0 = nothing new)
	or   a
	jr   z, .bgk_loop
	ret

; poll_joy: read joystick 1, edge-detect against JOY_PREV. Returns a key code on
; a fresh press (0 otherwise) so holding the stick yields one event per push.
poll_joy:
	call read_joy_code				; A = code for the current joystick state
	ld   hl, JOY_PREV
	cp   (hl)
	jr   z, .pj_held				; unchanged -> held (maybe auto-repeat)
	ld   (hl), a					; state changed -> store
	ld   b, a
	ld   a, JOY_RPT_DELAY			; (re)arm the auto-repeat initial delay
	ld   (JOY_RPT), a
	ld   a, b
	or   a
	ret  nz							; fresh non-neutral press -> emit now
	xor  a
	ret
.pj_held:
	or   a
	jr   z, .pj_zero				; neutral held -> nothing
	cp   #1C						; only auto-repeat the 4 directions (1C..1F),
	jr   c, .pj_zero				; not the A/B buttons (RETURN 0D / BS 08)
	ld   b, a						; save the direction code
	ld   a, (JOY_RPT)
	dec  a
	ld   (JOY_RPT), a
	jr   nz, .pj_zero				; delay not elapsed -> nothing this frame
	ld   a, JOY_RPT_RATE			; reload interval for the next repeat
	ld   (JOY_RPT), a
	ld   a, b						; emit the held direction (fast repeat)
	ret
.pj_zero:
	xor  a
	ret

; read_joy_code: map joystick 1 direction/buttons to menu key codes.
;   up=VT_UP down=VT_DOWN left=VT_LEFT right=VT_RIGHT  A=RETURN  B=BACKSPACE
read_joy_code:
	ld   a, 1
	call GTSTCK						; A = direction 0..8 (joystick 1)
	cp   1
	jr   z, .rjc_up
	cp   5
	jr   z, .rjc_down
	cp   3
	jr   z, .rjc_right
	cp   7
	jr   z, .rjc_left
	ld   a, 1						; trigger A (joystick 1) -> select
	call GTTRIG
	or   a
	jr   nz, .rjc_a
	ld   a, 3						; trigger B (joystick 1) -> back
	call GTTRIG
	or   a
	jr   nz, .rjc_b
	xor  a
	ret
.rjc_up:
	ld   a, #1E
	ret
.rjc_down:
	ld   a, #1F
	ret
.rjc_right:
	ld   a, #1C
	ret
.rjc_left:
	ld   a, #1D
	ret
.rjc_a:
	ld   a, #0D
	ret
.rjc_b:
	ld   a, #08
	ret

; draw_hline: A = row (1-based). Draw a thin horizontal line using the custom glyph
; (char 0x10) written straight into the name table — CHPUT would interpret control
; codes, so we FILVRM the code into VRAM (name table at 0x0000, 80 cols/row).
draw_hline:
	dec  a							; physical row (0-based)
	ld   l, a
	ld   h, 0
	add  hl, hl						; *2
	add  hl, hl						; *4
	add  hl, hl						; *8
	add  hl, hl						; *16
	ld   d, h
	ld   e, l						; DE = row*16
	add  hl, hl						; *32
	add  hl, hl						; *64
	add  hl, de						; HL = row*80 (name-table offset)
	ld   a, #10						; thin-line glyph
	ld   bc, 78
	call FILVRM
	ret

; load_font: (re)load our custom glyphs into the TEXT2 pattern table (VRAM 0x1000).
; Must run after every INITXT (which reloads the BIOS font). Char 0x10 = thin line.
load_font:
	di
	ld   a, #80						; VRAM write addr = 0x1080 (0x1000 + 0x10*8)
	out  (#99), a
	ld   a, #50						; high 0x10 | write bit 0x40 -> char 0x10
	out  (#99), a
	ld   hl, font_pat
	ld   b, 8
.lf_loop:
	ld   a, (hl)
	out  (#98), a
	inc  hl
	djnz .lf_loop
	; char 0xDB = bloque solido (lo usa la barra de carga de ROMs). El glifo de
	; #DB en el charset de la BIOS 2+ no es macizo (se ve "feo"); lo redefinimos a
	; 8x0xFF para que la barra sea solida con CUALQUIER BIOS. Addr en la tabla de
	; patrones (SCREEN 0/80col, base 0x1000) = 0x1000 + 0xDB*8 = 0x16D8.
	ld   a, #D8						; low byte de 0x16D8
	out  (#99), a
	ld   a, #56						; high 0x16 | write bit 0x40
	out  (#99), a
	ld   b, 8
.lf_solid:
	ld   a, #FF
	out  (#98), a
	djnz .lf_solid
	ei
	ret
font_pat:
	.db #00,#00,#00,#00,#FF,#00,#00,#00	; 0x10 thin horizontal line (row 4)

; draw_tabs: row 2 filter tabs "[R]OM [D]SK [A]LL"; active one inverse via blink.
draw_tabs:
	ld   hl, #0102					; X=1, Y=2
	call POSIT
	ld   hl, tabRStr
	call print_string
	ld   hl, #0902					; X=9, Y=2
	call POSIT
	ld   hl, tabDStr
	call print_string
	ld   hl, #1102					; X=17, Y=2
	call POSIT
	ld   hl, tabAStr
	call print_string
	; blink table: row 2 is physical row 1 -> base 0x0800 + 1*10 = 0x080A.
	; Tab cells live in bytes 0,1,2 of that row (cols 0-7, 8-15, 16-23).
	xor  a
	ld   bc, 3
	ld   hl, #080A
	call FILVRM						; clear the 3 tab attr bytes
	ld   a, (FILTER)				; active tab byte = FILTER (0=ROM,1=DSK,2=ALL)
	ld   e, a
	ld   d, 0
	ld   hl, #080A
	add  hl, de
	ld   a, #FF
	ld   bc, 1
	call FILVRM						; inverse-highlight the active tab
	; thin baseline under the tabs (row 3), with a gap under the active tab so it
	; "connects" into the list below (folder-tab look)
	ld   a, 3
	call draw_hline					; full thin line under the tabs (no gap; the active
	ret								; tab is already shown highlighted in inverse)

; draw_footer: bottom shortcut bar (row 23) with the partition indicator.
draw_footer:
	ld   hl, #0117					; X=1, Y=23
	call POSIT
	ld   a, (PART_CNT)
	cp   2
	jr   c, .df_keys
	ld   a, 'P'
	call CHPUT
	ld   a, (CUR_PART)
	inc  a
	add  a, '0'
	call CHPUT
	ld   a, '/'
	call CHPUT
	ld   a, (PART_CNT)
	add  a, '0'
	call CHPUT
	ld   a, ' '
	call CHPUT
	call CHPUT
.df_keys:
	ld   hl, footerStr
	call print_string
	ret

; help_screen: overlay listing the keys and how to move around. Any key returns.
help_screen:
	xor  a
	ld   (BROWSING), a				; freeze marquee/clock while help is shown
	call cls_browser
	ld   hl, #0101
	call POSIT
	ld   hl, helpTitleStr
	call print_string
	ld   a, 2
	call draw_hline
	ld   hl, #0204
	call POSIT
	ld   hl, help1Str
	call print_string
	ld   hl, #0206
	call POSIT
	ld   hl, help2Str
	call print_string
	ld   hl, #0207
	call POSIT
	ld   hl, help3Str
	call print_string
	ld   hl, #0208
	call POSIT
	ld   hl, help4Str
	call print_string
	ld   hl, #020A
	call POSIT
	ld   hl, help5Str
	call print_string
	ld   hl, #020B
	call POSIT
	ld   hl, help6Str
	call print_string
	ld   hl, #020C
	call POSIT
	ld   hl, help7Str
	call print_string
	ld   hl, #020D
	call POSIT
	ld   hl, help8Str
	call print_string
	ld   hl, #0217
	call POSIT
	ld   hl, helpEndStr
	call print_string
	call browse_getkey
	ld   a, 1
	ld   (BROWSING), a
	ret

; refresh_list: repaint ONLY the list area (rows 3..21) + the footer partition
; indicator, leaving the header/clock and separator lines untouched (no flash).
refresh_list:
	xor  a							; clear the list rows' blink attrs first, so rows
	ld   bc, 180					; that become empty don't keep a stale inverse bar
	ld   hl, #081E					; 0x0800 + physical row 3 * 10 (18 rows * 10 bytes)
	call FILVRM
	ld   a, 4
.rl_clear:
	push af
	ld   h, 1
	ld   l, a
	call POSIT
	ld   a, #1B
	call CHPUT
	ld   a, 'K'						; ESC K = clear to end of line
	call CHPUT
	pop  af
	inc  a
	cp   22
	jr   c, .rl_clear
	call draw_rows
	call draw_footer
	call draw_counter
	ret

; draw_browser: full repaint (clear + header), then fall into draw_rows.
draw_browser:
	call cls_browser
	; --- header row 1: title + build (left), live clock (right) ---
	ld   hl, #0101					; X=1, Y=1
	call POSIT
	ld   hl, hdrTitleStr			; "MSX Nano  v1.9"
	call print_string
	call draw_tabs					; row 2: filter tabs (active inverse)
	ld   a, 22
	call draw_hline					; thin separator above the footer
	call draw_footer
	call draw_counter				; "sel/total" centred on the bottom line
	; --- file list (rows 3..21) ---
	call draw_rows
	ret
; draw_rows: repaint the visible page in place (no clear, no header) so a scroll
; does not flash. Each row self-clears to end of line (draw_entry emits ESC K).
draw_rows:
	ld   a, (BR_TOP)
	ld   (BR_TMP2), a
	ld   b, VISIBLE
.dbw_loop:
	ld   a, (ENT_COUNT)
	ld   c, a
	ld   a, (BR_TMP2)
	cp   c
	jr   nc, .dbw_done				; idx >= count -> done
	push bc
	ld   a, (BR_TMP2)
	call draw_entry
	pop  bc
	ld   a, (BR_TMP2)
	inc  a
	ld   (BR_TMP2), a
	djnz .dbw_loop
.dbw_done:
	ret

; draw_entry: A = entry index. Print marker + [DIR]/file tag + name at its row.
draw_entry:
	ld   (BR_TMP), a
	; --- full-width inverse highlight on the SELECTED row (File-Hunter "hover") ---
	; A = idx on entry; set this row's 10 TEXT2 blink-attr bytes (VRAM 0x0800+Y*10)
	; to 0xFF when selected (-> R12 inverse colour), 0x00 otherwise.
	ld   hl, BR_SEL
	cp   (hl)
	ld   a, #FF
	jr   z, .de_blsel
	xor  a
.de_blsel:
	ld   (BR_BLINK), a
	ld   a, (BR_TMP)				; physical row (0-based) = 2 + (idx - BR_TOP)
	ld   c, a						; (POSIT row is 1-based Y=3; blink table is 0-based)
	ld   a, (BR_TOP)
	neg
	add  a, c
	add  a, 3
	ld   l, a
	ld   h, 0
	ld   c, l
	ld   b, h
	add  hl, hl
	add  hl, hl
	add  hl, bc
	add  hl, hl						; HL = row*10 (10 attr bytes per 80-col line)
	ld   bc, #0800
	add  hl, bc						; HL = 0x0800 + row*10
	ld   a, (BR_BLINK)
	ld   bc, 10
	call FILVRM						; paint the row's blink attribute
	ld   a, (BR_TMP)
	ld   c, a						; idx
	ld   a, (BR_TOP)
	neg
	add  a, c						; rel = idx - BR_TOP (0..21)
	add  a, 4						; Y = 4 + rel (list rows 4..21)
	ld   l, a
	ld   h, 1						; X = 1
	call POSIT
	ld   a, (BR_TMP)				; selection marker
	ld   hl, BR_SEL
	cp   (hl)
	ld   a, ' '
	jr   nz, .de0
	ld   a, '>'
.de0:
	call CHPUT
	ld   a, ' '
	call CHPUT
	ld   a, (BR_TMP)
	call ent_addr
	ld   (BR_REC), hl
	; --- name (no type tag; HL already = record) ---
	ld   de, NAME_OFF
	add  hl, de
	ld   b, NAME_WIN
	call print_name_win				; the name (record+7), padded to NAME_WIN
	ld   a, #1B						; ESC
	call CHPUT
	ld   a, 'K'						; VT-52 "erase to end of line"
	call CHPUT
	; --- right column (X=69): "[DIR]" for directories, size in KB for files ---
	ld   a, (BR_TMP)
	ld   c, a
	ld   a, (BR_TOP)
	neg
	add  a, c
	add  a, 4
	ld   l, a
	ld   h, 69						; X = 69 (right column)
	call POSIT
	ld   hl, (BR_REC)
	ld   a, (hl)					; type
	or   a
	jr   nz, .de_size				; file -> show KB size
	ld   hl, tagDirStr				; directory -> "[DIR]" in the right column
	call print_string
	ret
.de_size:
	; KB = (size>>16)*64 + (size_byte1 >> 2)
	ld   hl, (BR_REC)
	ld   de, SIZE_OFF+1
	add  hl, de
	ld   a, (hl)					; size byte 1
	srl  a
	srl  a
	ld   c, a
	ld   hl, (BR_REC)
	ld   de, SIZE_OFF+2
	add  hl, de
	ld   e, (hl)					; size byte 2
	inc  hl
	ld   d, (hl)					; size byte 3
	ex   de, hl						; hl = size >> 16
	add  hl, hl
	add  hl, hl
	add  hl, hl
	add  hl, hl
	add  hl, hl
	add  hl, hl						; * 64
	ld   e, c
	ld   d, 0
	add  hl, de						; hl = size in KB
	call print_dec16
	ld   a, 'K'
	call CHPUT
	ret

; print_dec16: print HL as unsigned decimal (no leading zeros).
print_dec16:
	ld   b, 0						; b = "a non-zero digit was printed" flag
	ld   de, 10000
	call .pd_dig
	ld   de, 1000
	call .pd_dig
	ld   de, 100
	call .pd_dig
	ld   de, 10
	call .pd_dig
	ld   a, l						; units digit (always shown)
	add  a, '0'
	jp   CHPUT
.pd_dig:
	xor  a
.pd_loop:
	or   a							; clear carry
	sbc  hl, de
	jr   c, .pd_done
	inc  a
	jr   .pd_loop
.pd_done:
	add  hl, de						; restore remainder
	or   a							; digit == 0 ?
	jr   nz, .pd_show
	ld   a, b
	or   a
	ret  z							; leading zero -> suppress
	xor  a							; print a '0'
.pd_show:
	ld   b, 1
	add  a, '0'
	jp   CHPUT

; print_name_win: print exactly B chars from (HL) — the name, then spaces to pad.
; Stops copying at NUL and pads the rest with blanks so the window is fully drawn.
print_name_win:
	ld   a, (hl)
	or   a
	jr   z, .pnw_pad
	push hl
	push bc
	call CHPUT
	pop  bc
	pop  hl
	inc  hl
	djnz print_name_win
	ret
.pnw_pad:
	ld   a, ' '
	push bc
	call CHPUT
	pop  bc
	djnz .pnw_pad
	ret

; strlen_name: HL = string -> A = length (B clobbered, HL advanced).
strlen_name:
	ld   b, 0
.snl:
	ld   a, (hl)
	or   a
	jr   z, .snd
	inc  hl
	inc  b
	jr   .snl
.snd:
	ld   a, b
	ret

; marquee_tick: while in the browser, if the selected entry's name is longer than
; the window, scroll it horizontally (one step every few frames).
marquee_tick:
	ld   a, (BROWSING)
	or   a
	ret  z
	ld   a, (ENT_COUNT)
	or   a
	ret  z
	ld   a, (BR_SEL)
	call ent_addr
	ld   de, NAME_OFF
	add  hl, de						; hl -> name
	call strlen_name				; a = len
	cp   NAME_WIN + 1
	ret  c							; len <= window -> fits, no scroll
	ld   c, a						; c = name length
	ld   a, (BR_SEL)				; selection changed since last tick?
	ld   b, a
	ld   a, (MQ_SEL)
	cp   b
	jr   z, .mt_same
	ld   a, b
	ld   (MQ_SEL), a
	xor  a
	ld   (MQ_OFF), a
	ld   (MQ_TICK), a
.mt_same:
	ld   a, (MQ_TICK)
	inc  a
	cp   5							; advance one column every 5 frames
	jr   c, .mt_savetick
	xor  a
	ld   (MQ_TICK), a
	ld   a, (MQ_OFF)
	inc  a
	ld   b, a						; b = candidate offset
	ld   a, c						; len
	sub  NAME_WIN					; a = max offset (len - window)
	cp   b
	jr   nc, .mt_okoff				; max >= candidate -> keep
	ld   b, 0						; wrap back to the start
.mt_okoff:
	ld   a, b
	ld   (MQ_OFF), a
	jp   draw_sel_name_window		; redraw the selected name window
.mt_savetick:
	ld   (MQ_TICK), a
	ret

; draw_sel_name_window: redraw the selected row's name window at offset MQ_OFF
; (leaves the marker, tag and size columns intact).
draw_sel_name_window:
	ld   a, (BR_SEL)				; screen row = 4 + (BR_SEL - BR_TOP)
	ld   c, a
	ld   a, (BR_TOP)
	neg
	add  a, c
	add  a, 4
	ld   l, a
	ld   h, 3						; X = name column (no type tag now)
	call POSIT
	ld   a, (BR_SEL)
	call ent_addr
	ld   de, NAME_OFF
	add  hl, de
	ld   a, (MQ_OFF)				; hl = name + MQ_OFF
	ld   e, a
	ld   d, 0
	add  hl, de
	ld   b, NAME_WIN
	jp   print_name_win				; padded -> size column survives

; ent_addr: A = index -> HL = ENT_ARRAY + index*ENT_SIZE (44, not a power of 2).
ent_addr:
	ld   hl, ENT_ARRAY
	or   a
	ret  z
	ld   b, a
	ld   de, ENT_SIZE
.ea_mul:
	add  hl, de
	djnz .ea_mul
	ret

; cls_browser: SCREEN 0 + clear the TEXT2 blink colour table (removes the white bar).
cls_browser:
	call INITXT
	call load_font					; INITXT reloads the BIOS font -> restore our glyphs
	ld   a, 0
	ld   bc, 240
	ld   hl, #0800
	call FILVRM
	ret

; draw_counter: show "sel/total" centred over the bottom separator line (row 22).
draw_counter:
	ld   hl, #2316					; X=35, Y=22 (roughly centred on 80 cols)
	call POSIT
	ld   a, ' '
	call CHPUT
	ld   a, (BR_SEL)
	inc  a
	ld   l, a
	ld   h, 0
	call print_dec16
	ld   a, '/'
	call CHPUT
	ld   a, (ENT_COUNT)
	ld   l, a
	ld   h, 0
	call print_dec16
	ld   a, ' '
	call CHPUT
	ret

; ix_is_rom: Z set if the entry's extension (ix+8..10) is "ROM" (upper-case).
ix_is_rom:
	ld   a, (ix+8)
	cp   'R'
	ret  nz
	ld   a, (ix+9)
	cp   'O'
	ret  nz
	ld   a, (ix+10)
	cp   'M'
	ret

; ix_is_dsk: Z set if the entry's extension (ix+8..10) is "DSK" (upper-case).
ix_is_dsk:
	ld   a, (ix+8)
	cp   'D'
	ret  nz
	ld   a, (ix+9)
	cp   'S'
	ret  nz
	ld   a, (ix+10)
	cp   'K'
	ret

; dsk_check_contig: verify the file whose first cluster is FILE_CLUS occupies
; CONSECUTIVE clusters (Nextor disk emulation maps a linear sector range, so the
; image must be unfragmented). Returns CF=0 if contiguous, CF=1 if fragmented.
dsk_check_contig:
	ld   hl, FILE_CLUS
	ld   de, SCAN_CLUS				; SCAN_CLUS = cluster actual de la cadena
	call w_copy
.dcc_loop:
	ld   hl, SCAN_CLUS
	ld   de, W_TMP
	call w_copy
	call w_is_eoc
	jr   c, .dcc_bad				; cluster < 2 / reservado -> cadena invalida
	call fatnext					; W_TMP = siguiente cluster
	jr   c, .dcc_bad				; error SD
	call w_is_eoc
	jr   c, .dcc_ok					; fin de cadena -> contiguo hasta aqui
	ld   hl, (SCAN_CLUS+0)			; siguiente debe ser actual+1 (32-bit)
	inc  hl
	ld   (SCAN_CLUS+0), hl
	ld   a, h
	or   l
	jr   nz, .dcc_nc
	ld   hl, (SCAN_CLUS+2)
	inc  hl
	ld   (SCAN_CLUS+2), hl
.dcc_nc:
	ld   hl, (SCAN_CLUS+0)
	ld   de, (W_TMP+0)
	or   a
	sbc  hl, de
	jr   nz, .dcc_bad
	ld   hl, (SCAN_CLUS+2)
	ld   de, (W_TMP+2)
	or   a
	sbc  hl, de
	jr   nz, .dcc_bad
	jr   .dcc_loop					; SCAN_CLUS ya = siguiente, continuar
.dcc_ok:
	or   a							; CF = 0 (contiguous)
	ret
.dcc_bad:
	scf								; CF = 1 (fragmented / invalid)
	ret

; fmt_name83: format the 11-byte 8.3 name at IX into name83 as "NAME.EXT",0
fmt_name83:
	ld   de, name83
	push ix
	pop  hl							; hl -> name field
	ld   b, 8
.fn_base:
	ld   a, (hl)
	cp   ' '
	jr   z, .fn_ext
	ld   (de), a
	inc  de
	inc  hl
	djnz .fn_base
.fn_ext:
	ld   a, (ix+8)
	cp   ' '
	jr   z, .fn_term				; no extension
	ld   a, '.'
	ld   (de), a
	inc  de
	ld   a, (ix+8)
	ld   (de), a
	inc  de
	ld   a, (ix+9)
	cp   ' '
	jr   z, .fn_term
	ld   (de), a
	inc  de
	ld   a, (ix+10)
	cp   ' '
	jr   z, .fn_term
	ld   (de), a
	inc  de
.fn_term:
	xor  a
	ld   (de), a
	ret

; inc_sd_lba: 32-bit increment of SD_LBA.
inc_sd_lba:
	ld   hl, SD_LBA
	inc  (hl)
	ret  nz
	inc  hl
	inc  (hl)
	ret  nz
	inc  hl
	inc  (hl)
	ret  nz
	inc  hl
	inc  (hl)
	ret

; sd_read_sector: read the 512-byte sector at SD_LBA into SD_BUF.
; The WonderTANG card is NOT auto-initialized: after reset the FPGA state machine
; sits in STANDBY with busy=1 FOREVER until we kick CMD0 via the init bit. The
; menu runs at cartridge INIT, BEFORE Nextor inits the card, so we must init it
; ourselves. Every busy-wait has a timeout so the CPU can NEVER hang (which would
; freeze the whole menu with interrupts off). SD_STATUS: 0=OK 1=init-TO 2=read-TO.
; Maps page 1 to slot 3-2 only for the transfer; menu code in page 2 is untouched.
sd_read_sector:
	di
	xor  a
	ld   (SD_STATUS), a				; assume OK
	ld   a, SD_SLOT_32				; page 1 -> slot 3-2 (SD window)
	ld   hl, #4000
	call ENASLT
	ld   a, #1
	ld   (SDC_ENABLE), a			; enable SDC register block

	ld   a, #80						; SDC_CMD bit7 = init (STANDBY -> CMD0 -> ... -> IDLING)
	ld   (SDC_CMD), a
	call sd_wait_idle				; wait busy->0, CARRY=timeout
	jr   nc, .init_ok
	ld   a, #1
	ld   (SD_STATUS), a				; init timed out
	jr   .sd_done
.init_ok:
	ld   a, (SD_LBA+0)
	ld   (SDC_SADDR+0), a
	ld   a, (SD_LBA+1)
	ld   (SDC_SADDR+1), a
	ld   a, (SD_LBA+2)
	ld   (SDC_SADDR+2), a
	ld   a, (SD_LBA+3)
	ld   (SDC_SADDR+3), a
	ld   a, #1						; SDC_CMD bit0 = read
	ld   (SDC_CMD), a
	ld   b, 0						; settle: let the FSM leave IDLING before polling
.sd_settle:
	djnz .sd_settle
	call sd_wait_idle
	jr   nc, .read_ok
	ld   a, #2
	ld   (SD_STATUS), a				; read timed out
	jr   .sd_done
.read_ok:
	ld   a, (SDC_CTYPE)
	ld   (SD_CTYPE), a
	ld   hl, SDC_SDATA				; copy 512 bytes window -> page-3 RAM
	ld   de, SD_BUF
	ld   bc, 512
	ldir
.sd_done:
	ld   a, SD_SLOT_31				; restore page 1 -> slot 3-1 (menu)
	ld   hl, #4000
	call ENASLT
	ei
	ret

; sd_wait_idle: poll SDC busy (status bit7) until 0. Returns CARRY clear on
; success, CARRY set on timeout (~a few seconds backstop so we never hang).
sd_wait_idle:
	ld   d, 6						; outer count (~2-3 s backstop; card responds in ms)
.swo:
	ld   bc, 0						; 65536 inner iterations
.swi:
	ld   a, (SDC_STATUS)
	and  #80
	ret  z							; busy=0 -> AND cleared carry -> OK
	dec  bc
	ld   a, b
	or   c
	jr   nz, .swi
	dec  d
	jr   nz, .swo
	scf								; timeout
	ret

; sd_write_sector: write the 512-byte SD_BUF to the sector at SD_LBA.
; Mirrors sd_read_sector but fills the SDC_SDATA window first and triggers
; SDC_CMD bit1 = write. SD_STATUS: 0=OK, 1=init timeout, 3=write timeout.
sd_write_sector:
	di
	xor  a
	ld   (SD_STATUS), a
	ld   a, SD_SLOT_32				; page 1 -> slot 3-2 (SD window)
	ld   hl, #4000
	call ENASLT
	ld   a, #1
	ld   (SDC_ENABLE), a
	ld   a, #80						; init the card (same as read path)
	ld   (SDC_CMD), a
	call sd_wait_idle
	jr   nc, .sw_init_ok
	ld   a, #1
	ld   (SD_STATUS), a
	jr   .sw_done
.sw_init_ok:
	ld   hl, SD_BUF					; fill the 512-byte transfer window
	ld   de, SDC_SDATA
	ld   bc, 512
	ldir
	ld   a, (SD_LBA+0)
	ld   (SDC_SADDR+0), a
	ld   a, (SD_LBA+1)
	ld   (SDC_SADDR+1), a
	ld   a, (SD_LBA+2)
	ld   (SDC_SADDR+2), a
	ld   a, (SD_LBA+3)
	ld   (SDC_SADDR+3), a
	; --- V3.1 (21/08): la tarjeta puede RECHAZAR el bloque, y nadie lo miraba.
	; sd_wait_idle solo hace "and #80" (bit de busy), asi que el token de
	; respuesta del bloque -- que el hardware SI captura y expone en
	; SDC_STATUS bit0 -- se tiraba a la basura: la escritura se daba por buena
	; y el sector se quedaba con lo que hubiera ANTES en la tarjeta.
	; Medido comparando 4 descargas del File-Hunter contra el CRC32 de su API:
	; el stream llega INTACTO (cero bytes perdidos, cero desplazamiento) pero
	; ~1 sector de cada 1120 conserva contenido ajeno (FF, E5, restos de otro
	; fichero). Firma imposible de explicar por perdida de datos.
	; Reintentar es GRATIS: escribir solo LEE la ventana SDC_SDATA, no la
	; destruye, asi que basta con volver a disparar SDC_CMD bit1 con el mismo
	; SD_LBA. E sobrevive a sd_wait_idle (usa A, D, BC), por eso es el contador.
	ld   e, 3						; hasta 3 intentos
.sw_try:
	ld   a, #2						; SDC_CMD bit1 = write
	ld   (SDC_CMD), a
	ld   b, 0
.sw_settle:
	djnz .sw_settle
	call sd_wait_idle
	jr   c, .sw_tmo					; ni solto el busy -> fallo duro
	ld   a, (SDC_STATUS)
	and  #03						; bit1 = timeout, bit0 = bloque RECHAZADO
	jr   z, .sw_done				; aceptado por la tarjeta
	dec  e
	jr   nz, .sw_try				; rechazado: repetir el MISMO sector
.sw_tmo:
	ld   a, #3
	ld   (SD_STATUS), a				; timeout, o rechazado 3 veces
.sw_done:
	ld   a, SD_SLOT_31				; restore page 1 -> slot 3-1 (menu)
	ld   hl, #4000
	call ENASLT
	ei
	ret

; find_emufile: search the SD ROOT directory for "NEXTOR  EMU" (8.3). On success
; CF=0 and (FILE_CLUS) = its first cluster; on not-found / SD error CF=1.
find_emufile:
	call cur_root					; CUR_CLUS = raiz (FAT16: region fija / FAT32: cadena)
	call set_scan_start
	ld   hl, CUR_CLUS
	ld   de, SCAN_CLUS
	call w_copy						; para seguir la cadena de la raiz FAT32
.fe_sec:
	call sd_read_sector
	ld   a, (SD_STATUS)
	or   a
	jp   nz, .fe_bad
	ld   ix, SD_BUF
	ld   a, 16
	ld   (ent_in_sec), a
.fe_ent:
	ld   a, (ix+0)
	or   a
	jp   z, .fe_bad					; 0x00 = end of directory -> not found
	cp   #E5
	jr   z, .fe_next				; deleted entry
	ld   a, (ix+11)
	and  #0F
	cp   #0F
	jr   z, .fe_next				; LFN sub-entry
	push ix
	pop  hl							; hl -> 11-byte 8.3 name
	ld   de, emuFileName
	ld   b, 11
.fe_cmp:
	ld   a, (de)
	cp   (hl)
	jr   nz, .fe_next
	inc  hl
	inc  de
	djnz .fe_cmp
	; name matches -> require first cluster >= 2. A 0-byte file has cluster 0,
	; and writing the data file there would CORRUPT the filesystem. Skip such an
	; entry and keep searching.
	ld   a, (ix+27)
	or   a
	jr   nz, .fe_take
	ld   a, (FS32)					; FAT32: el word alto (+20/21) tambien cuenta
	or   a
	jr   z, .fe_lo
	ld   a, (ix+20)
	or   a
	jr   nz, .fe_take
	ld   a, (ix+21)
	and  #0F
	jr   nz, .fe_take
.fe_lo:
	ld   a, (ix+26)
	cp   2
	jr   c, .fe_next				; cluster 0 or 1 -> unusable
.fe_take:
	ld   a, (ix+26)					; match -> first cluster (dword)
	ld   (FILE_CLUS+0), a
	ld   a, (ix+27)
	ld   (FILE_CLUS+1), a
	xor  a
	ld   (FILE_CLUS+2), a
	ld   (FILE_CLUS+3), a
	ld   a, (FS32)
	or   a
	jr   z, .fe_done
	ld   a, (ix+20)
	ld   (FILE_CLUS+2), a
	ld   a, (ix+21)
	and  #0F
	ld   (FILE_CLUS+3), a
.fe_done:
	or   a							; CF=0
	ret
.fe_next:
	ld   de, 32
	add  ix, de
	ld   a, (ent_in_sec)
	dec  a
	ld   (ent_in_sec), a
	jp   nz, .fe_ent
	call inc_sd_lba
	ld   a, (sec_left)
	dec  a
	ld   (sec_left), a
	jp   nz, .fe_sec
	call scan_next_cluster			; raiz FAT32 multi-cluster: seguir la cadena
	jp   c, .fe_sec
.fe_bad:
	scf
	ret

; build_emu_datafile: fill SD_BUF with a Nextor disk-emulation data file describing
; ONE image: header (signature, 1 entry, boot entry #1) + one 8-byte entry pointing
; at the .dsk (DSK_LBA, DSK_SECS). Uses device 0 (= same device as the data file).
build_emu_datafile:
	ld   hl, SD_BUF					; zero the whole 512-byte sector
	ld   de, SD_BUF+1
	ld   bc, 511
	ld   (hl), 0
	ldir
	ld   hl, emuSig					; +0  signature (16 bytes)
	ld   de, SD_BUF
	ld   bc, 16
	ldir
	ld   a, 1
	ld   (SD_BUF+16), a				; +16 entry count = 1
	ld   a, 1
	ld   (SD_BUF+17), a				; +17 1-based index of image to mount at boot
	; +18 work area (2) = 0, +20 reserved (4) = 0  -> already zeroed
	; entry #0 starts at +24
	xor  a
	ld   (SD_BUF+24), a				; entry device = 0 (same device as data file)
	ld   a, 1
	ld   (SD_BUF+25), a				; entry LUN = 1
	ld   hl, (DSK_LBA+0)			; +26 absolute start sector of the .dsk (4 bytes)
	ld   (SD_BUF+26), hl
	ld   hl, (DSK_LBA+2)
	ld   (SD_BUF+28), hl
	ld   hl, (DSK_SECS)				; +30 size in sectors (2 bytes)
	ld   (SD_BUF+30), hl
	ret

; create_emufile: create a 1-cluster file "NEXTOR.EMU" in the current partition's
; root dir to hold the emulation data file. On success CF=0 and (FILE_CLUS) = its
; first cluster. CF=1 on failure (no free cluster / no dir slot / SD error).
; Only ever writes to: one FAT sector (x NUM_FATS) + one root-dir sector. It does
; NOT touch any other file's data.
create_emufile:
	ld   a, (FS32)					; la creacion escribe estructuras FAT16; en FAT32
	or   a							; el usuario copia un NEXTOR.EMU (>=512B) desde DOS
	jr   z, .ce_fat16
	scf
	ret
.ce_fat16:
	call find_free_cluster			; DE = free cluster, CF=1 if none
	ret  c
	ld   (NEW_CLUS), de
	call mark_cluster_eof			; FAT entry -> 0xFFFF (both copies)
	ret  c
	call write_dir_entry			; root dir entry for NEXTOR.EMU
	ret  c
	ld   hl, (NEW_CLUS)
	ld   (FILE_CLUS+0), hl
	ld   hl, 0
	ld   (FILE_CLUS+2), hl
	or   a							; CF=0 success
	ret

; find_free_cluster: scan FAT copy 1 for a free entry (0x0000). Returns DE = cluster,
; CF=0; or CF=1 if none / SD error. Clusters 0 and 1 are reserved (skipped).
find_free_cluster:
	ld   hl, (FAT_LBA+0)
	ld   (SD_LBA+0), hl
	ld   hl, (FAT_LBA+2)
	ld   (SD_LBA+2), hl
	ld   hl, 0
	ld   (FFC_BASE), hl
	ld   hl, (FAT_SZ)
	ld   (FFC_LEFT), hl
.ffc_sec:
	ld   hl, (FFC_LEFT)
	ld   a, h
	or   l
	jr   z, .ffc_none
	call sd_read_sector
	ld   a, (SD_STATUS)
	or   a
	jr   nz, .ffc_none
	ld   ix, SD_BUF
	ld   c, 0
	ld   hl, (FFC_BASE)				; first FAT sector (base 0) holds clusters 0,1 -> skip
	ld   a, h
	or   l
	jr   nz, .ffc_ent
	ld   ix, SD_BUF+4
	ld   c, 2
.ffc_ent:
	ld   a, (ix+0)
	or   (ix+1)
	jr   z, .ffc_found
	inc  ix
	inc  ix
	inc  c
	jr   nz, .ffc_ent				; 256 entries/sector (c wraps to 0)
	ld   hl, (FFC_BASE)				; next sector: base += 256
	ld   de, 256
	add  hl, de
	ld   (FFC_BASE), hl
	ld   hl, (FFC_LEFT)
	dec  hl
	ld   (FFC_LEFT), hl
	call inc_sd_lba
	jr   .ffc_sec
.ffc_found:
	ld   hl, (FFC_BASE)
	ld   e, c
	ld   d, 0
	add  hl, de
	ex   de, hl						; DE = cluster
	or   a							; CF=0
	ret
.ffc_none:
	scf
	ret

; mark_cluster_eof: set the FAT entry for NEW_CLUS to 0xFFFF in FAT copy 1 and, if
; NUM_FATS>=2, copy 2. CF=1 on SD error.
mark_cluster_eof:
	ld   hl, (NEW_CLUS)
	ld   a, h
	ld   (MCE_SEC), a				; FAT sector offset = cluster >> 8
	ld   h, 0						; (entry byte offset = (cluster&255)*2)
	ld   a, (NEW_CLUS+0)
	ld   l, a
	add  hl, hl						; *2
	ld   (MCE_OFF), hl
	ld   hl, (FAT_LBA+0)			; SD_LBA = FAT_LBA + sector offset
	ld   a, (MCE_SEC)
	ld   e, a
	ld   d, 0
	add  hl, de
	ld   (SD_LBA+0), hl
	ld   hl, (FAT_LBA+2)
	ld   de, 0
	adc  hl, de
	ld   (SD_LBA+2), hl
	call sd_read_sector
	ld   a, (SD_STATUS)
	or   a
	jr   nz, .mce_err
	ld   hl, SD_BUF
	ld   de, (MCE_OFF)
	add  hl, de
	ld   (hl), #FF
	inc  hl
	ld   (hl), #FF
	call sd_write_sector			; FAT copy 1
	ld   a, (SD_STATUS)
	or   a
	jr   nz, .mce_err
	ld   a, (NUM_FATS)
	cp   2
	jr   c, .mce_ok					; only one FAT -> done
	ld   hl, (SD_LBA+0)				; FAT copy 2 sector = same + FAT_SZ
	ld   de, (FAT_SZ)
	add  hl, de
	ld   (SD_LBA+0), hl
	ld   hl, (SD_LBA+2)
	ld   de, 0
	adc  hl, de
	ld   (SD_LBA+2), hl
	call sd_write_sector			; same buffer (FAT copies are identical)
	ld   a, (SD_STATUS)
	or   a
	jr   nz, .mce_err
.mce_ok:
	or   a
	ret
.mce_err:
	scf
	ret

; write_dir_entry: find a free slot in the current partition's root dir and write a
; 32-byte entry for NEXTOR.EMU (first cluster = NEW_CLUS, size = 512). CF=1 on error.
write_dir_entry:
	ld   hl, (ROOT_LBA+0)
	ld   (SD_LBA+0), hl
	ld   hl, (ROOT_LBA+2)
	ld   (SD_LBA+2), hl
	ld   a, (ROOT_SECS)
	ld   (WDE_LEFT), a
.wde_sec:
	ld   a, (WDE_LEFT)
	or   a
	jr   z, .wde_err
	call sd_read_sector
	ld   a, (SD_STATUS)
	or   a
	jr   nz, .wde_err
	ld   ix, SD_BUF
	ld   b, 16
.wde_ent:
	ld   a, (ix+0)
	or   a
	jr   z, .wde_found				; 0x00 = free (end of dir)
	cp   #E5
	jr   z, .wde_found				; deleted -> reuse
	ld   de, 32
	add  ix, de
	djnz .wde_ent
	call inc_sd_lba
	ld   a, (WDE_LEFT)
	dec  a
	ld   (WDE_LEFT), a
	jr   .wde_sec
.wde_found:
	push ix							; zero the 32-byte slot
	pop  hl
	ld   d, h
	ld   e, l
	inc  de
	ld   (hl), 0
	ld   bc, 31
	ldir
	push ix							; name "NEXTOR  EMU"
	pop  hl
	ld   de, emuFileName
	ld   b, 11
.wde_name:
	ld   a, (de)
	ld   (hl), a
	inc  hl
	inc  de
	djnz .wde_name
	ld   (ix+11), #26				; attr = archive+hidden+system (invisible en el PC)
	ld   hl, (NEW_CLUS)
	ld   (ix+26), l					; first cluster low
	ld   (ix+27), h					; first cluster high
	ld   (ix+28), #00				; size = 512 bytes (0x00000200)
	ld   (ix+29), #02
	ld   (ix+30), #00
	ld   (ix+31), #00
	call sd_write_sector
	ld   a, (SD_STATUS)
	or   a
	jr   nz, .wde_err
	or   a							; CF=0
	ret
.wde_err:
	scf
	ret

; print A as two upper-case hex digits via CHPUT
print_hex_a:
	push af
	rrca
	rrca
	rrca
	rrca
	call .ph_nib
	pop  af
.ph_nib:
	and  #0f
	add  a, #90
	daa
	adc  a, #40
	daa
	jp   CHPUT

; print HL as four upper-case hex digits (high byte first)
print_hex_hl:
	ld   a, h
	call print_hex_a
	ld   a, l
	jp   print_hex_a

; --- Option 3: Configuracion WiFi (PLACEHOLDER, M3) -------------------------
; main_action_wifi: open the ESP8266 WiFi config menu that already lives in the
; ESP ROM (slot 0-2, esp8266e.rom). Its INIT (which ran at boot, before our menu,
; since slot 0 < slot 3) shows that menu when F1 is held: 'jp z,#4202'. We reach
; the same entry on demand: map page 1 to slot 0-2 and CALL #4202; the WiFi menu
; runs there (page 0 BIOS + page 3 RAM + UART I/O all stay valid) and returns on
; exit, then we restore page 1 and go back to the SD browser.
ESP_SLOT	equ	#88				; slot 0-2 (expanded: pri 0, sec 2)
main_action_wifi:
	di
	ld   a, ESP_SLOT				; page 1 -> ESP8266 WiFi ROM
	ld   hl, #4000
	call ENASLT
	ei
	call #006F						; INIT32: SCREEN 1 (32 col, GRAPHIC1). El setup del ESP
									; NO fija modo y carga patrones de caracter propios
									; (OUTI a #98) que asumen la tabla de patrones de
									; GRAPHIC1; en SCREEN 0 caian en VRAM equivocada -> los
									; "caracteres raros". Al volver, main_menu_restart ->
									; init_screen restaura el SCREEN 0 80col del navegador.
	call #4202						; ESP WiFi config menu (returns on exit)
	di
	ld   a, #87						; page 1 -> our menu ROM (slot 3-1)
	ld   hl, #4000
	call ENASLT
	ei
	jp   main_menu_restart			; back to the SD browser (home)

; Shows a centered message line, waits for ANY key, returns.
; Input: HL - message string
main_show_message:
	push hl
	ld   hl, #1212					; bottom area
	call POSIT
	pop  hl
	call print_string
.msg_wait:
	call read_any_key				; direct matrix scan, A!=0 when a key was pressed
	or   a
	jr   z, .msg_wait
	ret

; -----------------------------------------------------------------------------
; Direct keyboard-matrix reader (bypasses BIOS CHGET, which is unreliable at
; cartridge-INIT time on the Goa'uld). Reads via PPI: write row to port 0xAA
; (low nibble = row, high nibble kept high), read columns from port 0xA9
; (a 0 bit = key pressed). Matrix positions verified empirically:
;   '1'..'4' = row 0 bits 1..4 | UP = row8 bit5 | DOWN = row8 bit6
;   SPACE    = row8 bit0       | RETURN = row7 bit7
; Each routine implements press+release debouncing so one physical press yields
; exactly one event.
; -----------------------------------------------------------------------------
KB_PPIB	equ	0xA9				; PPI port B: keyboard column read
KB_PPIC	equ	0xAA				; PPI port C: keyboard row select (low nibble)

; read_menu_key: returns A = mapped key code (VT_UP/VT_DOWN/VT_RETURN/VT_SPACE/
;                '1'..'4') or 0 if nothing relevant is pressed. Waits for the
;                key to be released before returning (one event per press).
read_menu_key:
	; --- Row 0: digits 1..4 ---
	ld   a, 0xF0
	out  (KB_PPIC), a				; select row 0
	in   a, (KB_PPIB)
	cpl								; now 1 bit = pressed
	ld   b, a						; B = row0 pressed mask
	bit  1, b
	jr   nz, .k1
	bit  2, b
	jr   nz, .k2
	bit  3, b
	jr   nz, .k3
	bit  4, b
	jr   nz, .k4
	; --- Row 8: space / cursor up / cursor down ---
	ld   a, 0xF8
	out  (KB_PPIC), a				; select row 8
	in   a, (KB_PPIB)
	cpl
	ld   b, a						; B = row8 pressed mask
	bit  5, b
	jr   nz, .kup
	bit  6, b
	jr   nz, .kdown
	bit  0, b
	jr   nz, .kspace
	; --- Row 7: RETURN ---
	ld   a, 0xF7
	out  (KB_PPIC), a				; select row 7
	in   a, (KB_PPIB)
	cpl
	bit  7, a
	jr   nz, .kret
	xor  a							; nothing relevant pressed
	ret

.k1:	ld   c, '1'
	jr   .got
.k2:	ld   c, '2'
	jr   .got
.k3:	ld   c, '3'
	jr   .got
.k4:	ld   c, '4'
	jr   .got
.kup:	ld   c, VT_UP
	jr   .got
.kdown:	ld   c, VT_DOWN
	jr   .got
.kspace:ld   c, VT_SPACE
	jr   .got
.kret:	ld   c, VT_RETURN
.got:
	call wait_all_released			; debounce: wait until ALL keys are up
	ld   a, c
	ret

; read_any_key: returns A!=0 once ANY key is pressed (then released), else 0.
read_any_key:
	ld   a, 0xF0
	ld   b, 9						; scan rows 0..8
.ra_loop:
	out  (KB_PPIC), a
	push af
	in   a, (KB_PPIB)
	cp   0xFF						; 0xFF = no key in this row
	jr   nz, .ra_pressed
	pop  af
	inc  a							; next row
	djnz .ra_loop
	xor  a							; no key
	ret
.ra_pressed:
	pop  af
	call wait_all_released
	ld   a, 1						; signal "a key was pressed"
	ret

; wait_all_released: blocks until no key is pressed on rows 0,7,8 (the ones we
; use), with a short settle, so a single press is not read repeatedly.
wait_all_released:
	push bc
.war_loop:
	ld   a, 0xF0					; row 0
	out  (KB_PPIC), a
	in   a, (KB_PPIB)
	inc  a							; 0xFF -> 0 if all released
	jr   nz, .war_busy
	ld   a, 0xF7					; row 7
	out  (KB_PPIC), a
	in   a, (KB_PPIB)
	inc  a
	jr   nz, .war_busy
	ld   a, 0xF8					; row 8
	out  (KB_PPIC), a
	in   a, (KB_PPIB)
	inc  a
	jr   nz, .war_busy
	; all released -> small settle delay then return
	ld   bc, 0x0800
.war_settle:
	dec  bc
	ld   a, b
	or   c
	jr   nz, .war_settle
	pop  bc
	ret
.war_busy:
	jr   .war_loop

; Shared screen initialization: SCREEN 0 / 80 columns + blink mode ON, with a
; DETERMINISTIC palette so the menu looks EXACTLY the same on cold boot and on
; every redraw (placeholder return, etc.). On cold boot the menu used to inherit
; whatever text colours / palette the FM logo left behind; on a redraw those had
; changed -> "different blue". We now force the colours ourselves every time:
;   - FORCLR/BAKCLR/BDRCLR BIOS vars -> INITXT programs VDP r7 from them
;   - palette entry 4  = blue  (background / normal text bg, blink fg)
;   - palette entry 15 = white (normal text fg, blink bg / header box)
; so the result is byte-for-byte identical regardless of prior screen state.
init_screen:
	; Fixed text colours: foreground 15 (white), background/border 4 (blue)
	ld   a, 15
	ld   (FORCLR), a				; foreground = white (palette index 15)
	ld   a, 4
	ld   (BAKCLR), a				; background = blue  (palette index 4)
	ld   (BDRCLR), a				; border     = blue
	ld   a, 80
	ld   (LINL40), a
	call INITXT						; SCREEN 0 / 80 col; programs VDP r7 from FORCLR/BAKCLR
	; Blink mode ON: r12 = blink colours (fg 4 / bg 15) -> blue-on-white inverse
	ld   bc, #4f0c
	call WRTVDP
	ld   bc, #100d					; r13 = blink rate (steady)
	call WRTVDP
	; Force palette entries 4 and 15 to fixed RGB so the blue/white never drift.
	call set_menu_palette
	ret

; Reprograms VDP palette entries 4 (blue) and 15 (white) deterministically.
; V9938/V9958 palette write: select entry in r16, then write 2 bytes to port
; 0x9A: byte1 = (R<<4)|B, byte2 = G  (each component 0..7).
set_menu_palette:
	di
	; --- entry 4 = blue (R=1, G=1, B=7) ---
	ld   a, 4
	out  (#99), a					; low byte = palette index 4
	ld   a, 16 | #80				; select VDP register 16 (palette pointer)
	out  (#99), a
	ld   a, #17						; byte1 = (R<<4)|B = (1<<4)|7 = 0x17
	out  (#9A), a
	ld   a, #01						; byte2 = G = 1
	out  (#9A), a
	; --- entry 15 = white (R=7, G=7, B=7) ---
	ld   a, 15
	out  (#99), a
	ld   a, 16 | #80
	out  (#99), a
	ld   a, #77						; byte1 = (7<<4)|7 = 0x77
	out  (#9A), a
	ld   a, #07						; byte2 = G = 7
	out  (#9A), a
	ei
	ret

; #############################################################################
; ##  EXISTING GOA'ULD CONFIG MENU  (reached from main menu option "Ajustes")
; #############################################################################

; ############## Initialization
config_menu_entry:
	call init_screen				; SCREEN 0 80-col + blink (shared routine)

	; Print menu title
	ld   hl,#1a02
	call POSIT						; BIOS setCursor
	ld   hl,menuTitleStr
	call print_string
	; clear area
	ld   a, #00
	ld   bc, 240
	ld   hl, #0800
	call FILVRM	
	; Top header line
	ld   a, #ff
	ld   bc, 30
	ld   hl, #0800
	call FILVRM						; BIOS fill VRAM

	; Print menu options
	ld   ix, structs_start
	ld   (var_currentStruct), ix
.printmenu_loop:
	ld   a, (ix)
	or   a
	jr   z, .printmenu_loop_end
	call print_struct
	ld   bc, STRUCT_SIZE
	add  ix, bc
	jr   .printmenu_loop
.printmenu_loop_end:

	; Read Goauld settings
	di								; Set initial variables values

	ld   a, #48						; Set I/O device to Goauld (#48)
	out  (#40), a
	in   a, (#41)
	
	ld   b, a
	and  #01						; Bit 0: mapper enable
	ld   (var_mapper), a
	ld   a, b
IFDEF ENABLE_MEGARAM
	and  #02						; Bit 1: megaram enable
	rrca
	ld   (var_megram), a
	ld   a, b
ENDIF ;ENABLE_MEGARAM
	and  #04						; Bit 2: ghost scc enable
	rrca
	rrca
	ld   (var_ghtscc), a
	ld   a, b
	and  #08						; Bit 3: scanlines enable
	rrca
	rrca
	rrca
	ld   (var_scanln), a
	ld   a, b
	and  #30						; Bits5,4: mapper slot
	rrca
	rrca
	rrca
	rrca
	ld   (var_mapslt), a
	ld   a, b
IFDEF ENABLE_MEGARAM
	and  #c0						; Bits7,6: megaram slot
	rlca
	rlca
	ld   (var_megslt), a
ENDIF ;ENABLE_MEGARAM

IFDEF ENABLE_SDCARD
	in   a, (#42)
	ld   b, a
	and  #01						; Bit 0: SD card enable
	ld   (var_sdcard), a
	ld   a, b
	and  #06						; Bits1,2: SD card slot
	rrca
	ld   (var_sdcslt), a
ENDIF ;ENABLE_SDCARD

	in   a, (#42)
	ld   b, a
	ld   a, b
	and  #20						; Bit 5: stereo sound
	rlca
	rlca
	rlca							; bit5 -> bit0
	ld   (var_stereo), a
IF !MSXIMUS					; 60K: sprites 8/linea (bit3) y 16:9 (bit4) ELIMINADOS
	ld   a, b						; (V9968 hace 16/linea; core _143 = pantalla unica)
	and  #10						; Bit 4: sprites 8/linea (anti-parpadeo screen2)
	rrca
	rrca
	rrca
	rrca							; bit4 -> bit0
	ld   (var_sprlim), a
ENDIF

	in   a, (#45)					; #45 Bit 0: boot turbo (flash byte[4]='T')
	and  #01
	ld   (var_btturb), a

	ei

; ############## Main loop

bucle_repaint_selection:
	ld   a, #ff						; Print selection
	call print_selection

ONOFF_Y = 5
bucle:
	ld   hl,#2b00 + ONOFF_Y			; Print Second SCC
	ld   a,(var_ghtscc)
	call print_on_off
ONOFF_Y = ONOFF_Y + 2

	ld   hl,#2b00 + ONOFF_Y			; Print Enable Scanlines
	ld   a,(var_scanln)
	call print_on_off
ONOFF_Y = ONOFF_Y + 2

	ld   hl,#2b00 + ONOFF_Y			; Print Stereo Sound
	ld   a,(var_stereo)
	call print_on_off
ONOFF_Y = ONOFF_Y + 2

IF !MSXIMUS
	ld   hl,#2b00 + ONOFF_Y			; Print Sprites 8/linea (solo nano)
	ld   a,(var_sprlim)
	call print_on_off
ONOFF_Y = ONOFF_Y + 2
ENDIF

	ld   hl,#2b00 + ONOFF_Y			; Print Boot Turbo
	ld   a,(var_btturb)
	call print_on_off
	ld   hl,#2f00 + ONOFF_Y			; nota en la misma fila (col 47): el Boot Turbo solo
	call POSIT						; entra al ARRANCAR EN FRIO; Save&Reset con turbo no
	ld   hl, turboNoteStr			; reinicia (se queda en negro) -> reiniciar fisicamente
	call print_string
ONOFF_Y = ONOFF_Y + 2

	; Wait for a key
wait_for_a_key:
	ei
	halt
	call CHSNS						; BIOS keyStatus
	jr   z, wait_for_a_key
	call CHGET						; BIOS readChar
	or   a
	jr   z, wait_for_a_key

; ############## Keys handling

.key_lateral:
	sub  VT_RIGHT
	jr   z, .key_lateral_ok
	dec  a
	jr   nz, .key_up
.key_lateral_ok:
	ld   e, (ix+STRUCT_KEY_LATERAL)
	ld   d, (ix+STRUCT_KEY_LATERAL+1)
.new_selection:
	ld   a, 0						; Remove selection print
	call print_selection
	ld   ixl, e
	ld   ixh, d
	ld   (var_currentStruct), ix
	jp   bucle_repaint_selection

.key_up:
	dec  a
	jr   nz, .key_down
	ld   e, (ix+STRUCT_KEY_UP)
	ld   d, (ix+STRUCT_KEY_UP+1)
	jR   .new_selection

.key_down:
	dec  a
	jr   nz, .key_space
	ld   e, (ix+STRUCT_KEY_DOWN)
	ld   d, (ix+STRUCT_KEY_DOWN+1)
	jr   .new_selection

.key_space:
	ld   hl, bucle
	push hl
	dec  a
	ret  nz

	ld   l, (ix+STRUCT_SEL_ACTION)
	ld   h, (ix+STRUCT_SEL_ACTION+1)
	jp   (hl)

; ############## Actions

selected_stereo:
	ld   hl, var_stereo
	jp   .selected_on_off

IF !MSXIMUS
selected_spritelimit:
	ld   hl, var_sprlim
	jp   .selected_on_off
ENDIF

selected_bootturbo:
	ld   hl, var_btturb
	jp   .selected_on_off

selected_slot1Ghost:
	ld   hl, var_ghtscc
	jp   .selected_on_off

selected_scanlines:
	ld   hl, var_scanln

.selected_on_off:
	ld   a, (hl)
	xor  1
	ld   (hl), a
	ret

selected_saveReset:
	pop  hl							; Remove ret to bucle
	call config_var2byte
	di
	ld   a, #48						; Set I/O device to Goauld (#48)
	out  (#40),a
	in   a, (#42)
	or   #C0						; Bit 7: reset, Bit 6: save config in flash
	out  (#42), a
	ei
	ret

selected_saveExit:
	pop  hl							; Remove ret to bucle (the config-menu loop)
	call config_var2byte			; Save settings to flash + clear screen
	; Continue the boot using the SAME robust mechanism as the main-menu
	; "Arrancar sistema" option, instead of ret'ing into a possibly-drifted
	; stack. This guarantees we hand control back to the BIOS cleanly.
	jp   main_action_boot

config_var2byte:
	ld   b, #03						; #41 Bits 0,1: mapper + megaram SIEMPRE on
	ld   a, (var_ghtscc)			; #41 Bit 2: ghost scc enable
	rlca
	rlca
	or   b
	ld   b, a
	ld   a, (var_scanln)			; #41 Bit 3: scanlines enable
	rlca
	rlca
	rlca
	or   b
	ld   b, a
	ld   a, (var_mapslt)			; #41 Bits5,4: mapper slot
	rlca
	rlca
	rlca
	rlca
	or   b
	ld   b, a
IFDEF ENABLE_MEGARAM
	ld   a, (var_megslt)			; #41 Bits7,6: megaram slot
	rlca
	rlca
	rlca
	rlca
	rlca
	rlca
	or   b
	ld   b, a
ENDIF ;ENABLE_MEGARAM

	ld   c, #41
	call set_settings

	ld   a, (var_btturb)			; #45 Bit 0: arrancar en turbo (persistido)
	ld   b, a						; ANTES del #42: la escritura de #42 (bit6)
	ld   c, #45						; dispara la grabacion en flash y byte[4]
	call set_settings				; se muestrea en ese momento

	ld   b, #0
IFDEF ENABLE_SDCARD
	ld   b, #01						; #42 Bit 0: SD Card SIEMPRE on
	ld   a, (var_sdcslt)			; #42 Bit 1,2: SD Card slot
	rlca
	or   b
	ld   b, a
ENDIF

	ld   a, (var_stereo)			; #42 Bit 5: stereo sound
	rrca
	rrca
	rrca							; bit0 -> bit5
	or   b
	ld   b, a
IF !MSXIMUS
	ld   a, (var_sprlim)			; #42 Bit 4: sprites 8/linea (solo nano; 60K sin sprite-limit)
	rlca
	rlca
	rlca
	rlca							; bit0 -> bit4
	or   b
ENDIF
	or   #40						; Bit 6: save config in flash
	ld   b, a

	ld   c, #42
	call set_settings

	call INITXT						; BIOS clearScreen
	ld   bc, #000d					; Blink mode off
	jp   WRTVDP

set_settings:
	di
	ld   a, #48						; Set I/O device to Goauld (#48)
	out  (#40),a
	ld   a, b
	out  (c),a
	reti

; Prints characters from memory until a 0 is found.
; Input    : HL - The text address 
print_string:
	ld   a,(hl)
	or   a
	ret  z
	inc  hl
	call CHPUT						; BIOS printChar
	jr   print_string

; print_string_max: imprime (HL) hasta B caracteres o NUL (lo que llegue antes)
print_string_max:
	ld   a, (hl)
	or   a
	ret  z
	inc  hl
	call CHPUT
	djnz print_string_max
	ret

; clear_at: limpia un campo de B espacios en HL (POSIT #ColFila) y deja el
; cursor REPOSICIONADO al inicio del campo -> el llamador imprime encima.
; Es la base del layout fijo de la pantalla de lanzar ROM (sin residuos).
clear_at:
	push hl
	call POSIT
.ca_sp:
	ld   a, ' '
	call CHPUT
	djnz .ca_sp
	pop  hl
	jp   POSIT

; Set the cursor to L,H position and prints 'Off'/'On ' if A is 0 or not.
; Input    : H  - Y coordinate of cursor
;            L  - X coordinate of cursor
;            A  - Value to print (0:Off 1:On)
print_on_off:
	ld   b, a
	call POSIT						; BIOS setCursor
	ld   a, b
	ld   hl,offStr
	or   a
	jr   z,print_on_off_end
	ld   hl,onStr
print_on_off_end:
	jr   print_string

; Print the text of a struct
; Input    : IX - Struct address
print_struct:
	ld   l, (ix+STRUCT_POSXY+1)
	ld   h, (ix+STRUCT_POSXY)
	call POSIT						; BIOS setCursor
	ld   l, (ix+STRUCT_TEXT)
	ld   h, (ix+STRUCT_TEXT+1)
	jr   print_string

; Print the selection highlight on/off
; Input    : A  - 0:off #ff:on
print_selection:
	ld   ix, (var_currentStruct)
	ld   b, 0
	ld   c, (ix+STRUCT_SEL_LEN)
	ld   l, (ix+STRUCT_SEL_START)
	ld   h, (ix+STRUCT_SEL_START+1)
	jp   FILVRM


; ############## Constants

tagDirStr:
	.db "[DIR] ",0
tagRomStr:
	.db "[ROM] ",0
tagDskStr:
	.db "[DSK] ",0
hdrTitleStr:
IF MSXIMUS
	.db "MSXimus   v2.1",0
ELSE
	.db "MSX Nano  v1.9",0
ENDIF
tabRStr:
	.db "[R]OM",0
tabDStr:
	.db "[D]SK",0
tabAStr:
	.db "[A]LL",0
footerStr:
	.db "R/D/A=Filtro  ESC=Boot  S=Set  W=WiFi  TAB=Part  H=Ayuda",0
helpTitleStr:
IF MSXIMUS
	.db "MSXimus - AYUDA",0
ELSE
	.db "MSXnano - AYUDA",0
ENDIF
; ============================== DATOS (>= A010) ==============================
; El codigo debe quedar por debajo de #A000; cadenas y tablas viven a partir de
; #A010, dejando #A000-#A00F como hueco para el registro NEXTOR_EMU_DATA que
; escribe el lanzador de .dsk (y que el depack machaca en cada arranque).
; GUARD anti-desborde: si el codigo previo pasa de #A000, el ds sale NEGATIVO
; y el ensamblado FALLA (sin esto, el .org solapaba secciones EN SILENCIO y
; corrompia el binario - descubierto al anadir la fase 0 de File-Hunter, cuyo
; bloque vive ahora al FINAL de la seccion de datos, tras los structs).
	ds   #A000-$
	.org #A010
help1Str:
	.db "Arriba/Abajo          : mover (Izq/Der = pagina)",0
help2Str:
	.db "RETURN / Boton A      : abrir carpeta o lanzar ROM",0
help3Str:
	.db "BACKSPACE / Boton B   : carpeta anterior",0
help4Str:
	.db "TAB                   : cambiar de particion",0
help5Str:
	.db "ESC                   : arrancar el sistema (MSX-DOS)",0
help6Str:
	.db "S                     : Ajustes (configuracion goauld)",0
help7Str:
	.db "W                     : configuracion WiFi (ESP)",0
help8Str:
	.db "H                     : esta ayuda",0
helpEndStr:
	.db "Pulsa una tecla para volver...",0
romInfoStr:
	.db "Fichero:",0
titleRomStr:
	.db "Lanzar ROM",0
analyzStr:
	.db "Analizando ROM...",0
doneStr:
	.db "ROM cargada.",0
romClusStr:
	.db "Tamano:",0
romSpcStr:
	.db "Mapper:",0
mapPlainStr:
	.db "Plain (lineal)",0
mapKonStr:
	.db "Konami",0
mapSccStr:
	.db "Konami-SCC",0
mapA8Str:
	.db "ASCII8",0
mapA16Str:
	.db "ASCII16",0
mapUnkStr:
	.db "? (desconocido)",0
loadingStr:
	.db "Cargando ROM en megaram...",0
launch2Str:							; pie (fila 22); .bsr_footer limpia la fila antes,
	.db "RETURN = Lanzar   M = Mapper   S = SRAM   ESC = Volver",0
launch2bStr:						; variante sin SRAM (no-ASCII)
	.db "RETURN = Lanzar   M = Mapper   ESC = Volver",0
sramStr:
	.db "SRAM:",0
srchStr:
	.db "Buscar: ",0
tw_title:
IF MSXIMUS
	.db "MSXimus - Cinta web (tsx.eslamejor.com)",13,10,0
ELSE
	.db "MSXnano - Cinta web (tsx.eslamejor.com)",13,10,0
ENDIF
tw_search:
	.db "Buscando y descargando (hasta 40s)...",0
tw_notfound:
	.db "No encontrada. Pulsa una tecla.",0
tw_error:
	.db "Error del ESP/WiFi. Pulsa una tecla.",0
tw_timeout:
	.db "Sin respuesta del ESP. Pulsa una tecla.",0
tw_ready1:
	.db "CINTA EN MARCHA. Al arrancar BASIC teclea:",0
tw_cmd_run:
	.db "RUN",34,"CAS:",34,0
tw_cmd_bload:
	.db "BLOAD",34,"CAS:",34,",R",0
tw_cmd_unk:
	.db "RUN",34,"CAS:",34," (o BLOAD",34,"CAS:",34,",R)",0
tw_ready2:
	.db "RETURN = arrancar BASIC   ESC = cancelar",0
; strings de la pantalla de lanzar DSK (mismo layout que la de ROM; los textos
; de estado/error caben en el campo fijo de 30; el "pulsa una tecla" va al pie)
dskTitleStr:
	.db "Lanzar disco",0
dskTipoStr:
	.db "Tipo:",0
dskTipoValStr:
	.db "Disco (Nextor)",0
dskReadyStr:
	.db "DSK listo para montar.",0
dskMountStr:
	.db "Montando disco Nextor...",0
dskFragStr:
	.db "DSK fragmentado: recopialo",0
dskAskStr:
	.db "RETURN = Montar y lanzar   ESC = Volver",0
dskNoEmuStr:
	.db "Falta NEXTOR.EMU en la raiz",0
dskWrErrStr:
	.db "Error escribiendo en la SD",0
; Nextor disk-emulation "one-time" signature (16-byte field: 15 chars + NUL)
emuSig:
	.db "NEXTOR_EMU_DATA",0
; 8.3 name of the helper file that holds the emulation data file (root dir)
emuFileName:
	.db "NEXTOR  EMU"
readingStr:
	.db "Leyendo SD...",0
noSdStr:
	.db "No se detecta la tarjeta SD.",0
noSdStr2:
	.db "RETURN=Boot MSX   S=Settings   W=WiFi",0

menuTitleStr:
IF MSXIMUS
	.db "MSXimus - Ajustes",0
ELSE
	.db "MSXnano - Ajustes",0
ENDIF
slot1GhostStr:
	.db "Second SCC",0			; config1 bit2 (former ghost SCC): SCC+ nr.2 in the free slot
enableScanlinesStr:
	.db "Enable Scanlines",0
stereoStr:
	.db "Stereo Sound",0
IF !MSXIMUS
spriteStr:
	.db "Sprites 8/linea",0
ENDIF
bootTurboStr:
	.db "Boot Turbo",0			; arrancar siempre a 5.37 MHz (flash byte[4]='T')
turboNoteStr:
	.db "(reiniciar fisicamente)",0	; el Boot Turbo solo entra en arranque en frio
saveExitStr:
	.db "Save & Exit",0
saveResetStr:
	.db "Save & Reset",0

onStr:
	.db "On ",0
offStr:
	.db "Off",0


; ############## Structs

STRUCT_POSXY		equ		0
STRUCT_TEXT			equ		STRUCT_POSXY + 2
STRUCT_KEY_UP		equ		STRUCT_TEXT + 2
STRUCT_KEY_DOWN		equ		STRUCT_KEY_UP + 2
STRUCT_KEY_LATERAL	equ		STRUCT_KEY_DOWN + 2
STRUCT_SEL_START	equ		STRUCT_KEY_LATERAL + 2
STRUCT_SEL_LEN		equ		STRUCT_SEL_START + 2
STRUCT_SEL_ACTION	equ		STRUCT_SEL_LEN + 1

STRUCT_SIZE			equ		STRUCT_SEL_ACTION + 2	; Struct size

POS_Y = 4

structs_start:
struct_Slot1GhostSCC:
	.db 21, POS_Y+1
	.dw slot1GhostStr
	.dw struct_SaveReset, struct_EnableScanlines, struct_Slot1GhostSCC
	.dw #0800 + POS_Y*10 + 2
	.db 4
	.dw selected_slot1Ghost
POS_Y = POS_Y + 2

struct_EnableScanlines:
	.db 21, POS_Y+1
	.dw enableScanlinesStr
	.dw struct_Slot1GhostSCC, struct_Stereo, struct_EnableScanlines
	.dw #0800 + POS_Y*10 + 2
	.db 4
	.dw selected_scanlines
POS_Y = POS_Y + 2

struct_Stereo:
	.db 21, POS_Y+1
	.dw stereoStr
IF MSXIMUS
	.dw struct_EnableScanlines, struct_BootTurbo, struct_Stereo
ELSE
	.dw struct_EnableScanlines, struct_SpriteLimit, struct_Stereo
ENDIF
	.dw #0800 + POS_Y*10 + 2
	.db 4
	.dw selected_stereo
POS_Y = POS_Y + 2

IF !MSXIMUS					; Sprites 8/linea = solo nano (60K: V9968 hace 16/linea)
struct_SpriteLimit:
	.db 21, POS_Y+1
	.dw spriteStr
	.dw struct_Stereo, struct_BootTurbo, struct_SpriteLimit
	.dw #0800 + POS_Y*10 + 2
	.db 4
	.dw selected_spritelimit
POS_Y = POS_Y + 2
ENDIF

; struct_Aspect (Pantalla 16:9) ELIMINADO del 60K: core _143 = pantalla unica full-screen

struct_BootTurbo:
	.db 21, POS_Y+1
	.dw bootTurboStr
IF MSXIMUS
	.dw struct_Stereo, struct_SaveExit, struct_BootTurbo
ELSE
	.dw struct_SpriteLimit, struct_SaveExit, struct_BootTurbo
ENDIF
	.dw #0800 + POS_Y*10 + 2
	.db 4
	.dw selected_bootturbo
POS_Y = POS_Y + 2

struct_SaveExit:
	.db 21, POS_Y+1
	.dw saveExitStr
	.dw struct_BootTurbo, struct_SaveReset, struct_SaveExit
	.dw #0800 + POS_Y*10 + 2
	.db 4
	.dw selected_saveExit
POS_Y = POS_Y + 2

struct_SaveReset:
	.db 21, POS_Y+1
	.dw saveResetStr
	.dw struct_SaveExit, struct_Slot1GhostSCC, struct_SaveReset
	.dw #0800 + POS_Y*10 + 2
	.db 4
	.dw selected_saveReset
POS_Y = POS_Y + 2

structs_end:
	.db 0


; --- FASE 0 FILE-HUNTER: test UNAPI desde el menu (tecla U) ------------------
; Verifica en HW la cadena completa PRE-DOS: hook EXTBIO (instalado por el INIT
; del ROM ESP, que corre antes que el menu por orden de slots) -> discovery
; "TCP/IP" -> UNAPI_GET_INFO (nombre+version del driver) -> TCPIP_NET_STATE ->
; DNS de api.file-hunter.com. Al terminar DESINSTALA la parte volatil que el
; driver asigna en su PRIMERA llamada (30 bytes bajo HIMEM = #F363-#F380 + hook
; H.TIMI): sin esa limpieza, el stack de boot (SP #F380) pisaria el area y el
; backup de H.TIMI se ejecutaria corrupto -> crash. El hook EXTBIO se queda
; (vive en ROM+SLTWRK): bajo DOS el driver re-asigna limpio bajo el HIMEM de
; Nextor. Refs: spec MSX-UNAPI/TCP-IP UNAPI (Konamiman) + ESPUNAPI.asm (ducasp).
FH_EXTBIO	equ	#FFCA			; hook ext-BIOS (RST30+slot+DO_EXTBIO del ESP)
FH_HOKVLD	equ	#FB20			; bit0 = hook EXTBIO valido
FH_ARG		equ	#F847			; buffer identificador para EXTBIO
FH_HTIMI	equ	#FD9F			; hook H.TIMI (el driver lo engancha al asignar)
FH_HIMEM	equ	#FC4A			; tope de RAM libre (el driver le resta 30)
FH_SLTWRK_P	equ	#FD1E			; SLTWRK del slot 0-2: puntero al area del driver

; ============================================================================
; CINTA WEB (tecla T): busca un TSX en tsx.eslamejor.com via el ESP32-C6 y lo
; reproduce en la CINTA VIRTUAL por stream (cas_stream, pines 26/32). Habla con
; el firmware TapeWeb por la UART del wifi_lite en I/O 0x06/0x07 DIRECTO (sin
; driver UNAPI): OUT(7)=TX ; IN(7) bit0 = hay dato ; IN(6) = RX ; OUT(6),20 =
; vaciar FIFO RX. Comando 'J' TSX_FIND {texto}: el C6 busca en el catalogo,
; descarga el .tsx, lo convierte y lo STREAMEA al FPGA.
;   respuesta OK:    'J', 0, sizeH, sizeL, loadcmd, nombreZ (ASCII)
;   respuesta error: 'J', err   (3 = no encontrada)
; Al RETURN se arranca BASIC y el usuario teclea el comando mostrado (la cinta
; ya esta sonando; la BIOS la lee por el bit7 del PSG como una cinta real).
; ============================================================================
main_action_tsxweb:
	call init_screen				; SCREEN 0 (como Ajustes)
	ld   hl, tw_title
	call ver_puts
	ld   hl, #0305					; prompt de busqueda
	call POSIT
	ld   hl, srchStr				; "Buscar: " (reusada del browser)
	call print_string
	ld   hl, SRCH_BUF
	ld   b, 0						; longitud actual
.tw_key:
	push hl
	push bc
	call prompt_getkey				; solo teclado, sin marquee
	pop  bc
	pop  hl
	cp   #0D
	jr   z, .tw_go
	cp   #1B
	jp   z, main_menu_restart		; ESC = volver al menu
	cp   #08
	jr   z, .tw_del
	cp   ' '
	jr   c, .tw_key					; controles fuera
	cp   #7F
	jr   nc, .tw_key
	ld   c, a
	ld   a, b
	cp   40							; hasta 40 caracteres
	jr   nc, .tw_key
	ld   a, c
	ld   (hl), a
	inc  hl
	inc  b
	call CHPUT						; eco
	jr   .tw_key
.tw_del:
	ld   a, b
	or   a
	jr   z, .tw_key
	dec  hl
	dec  b
	ld   a, #08
	call CHPUT
	ld   a, ' '
	call CHPUT
	ld   a, #08
	call CHPUT
	jr   .tw_key
.tw_go:
	ld   a, b
	or   a
	jp   z, main_menu_restart		; consulta vacia = volver
	push bc							; B = longitud del texto
	ld   hl, #0308
	call POSIT
	ld   hl, tw_search				; "Buscando y descargando..."
	call print_string
	ld   a, 20						; vaciar el FIFO RX de la UART del ESP
	out  (6), a
	ld   a, 'J'						; TSX_FIND
	out  (7), a
	xor  a
	out  (7), a						; size alto = 0
	pop  bc
	ld   a, b
	out  (7), a						; size bajo = longitud
	ld   hl, SRCH_BUF
.tw_tx:
	ld   a, (hl)
	inc  hl
	out  (7), a
	djnz .tw_tx
	call tw_rx_long					; cmd de eco ('J'); CF=1 timeout (~40s)
	jp   c, .tw_terr
	call tw_rx						; err
	jp   c, .tw_terr
	or   a
	jr   nz, .tw_err
	call tw_rx						; size alto (la resp cabe en <256: ignorar)
	jp   c, .tw_terr
	call tw_rx						; size bajo
	jp   c, .tw_terr
	ld   b, a						; = 1 (loadcmd) + nombre + NUL
	call tw_rx
	jp   c, .tw_terr
	ld   (TW_LOAD), a				; 0=RUN"CAS: 1=BLOAD"CAS:",R 2=otro
	dec  b
	ld   hl, #030A					; nombre encontrado (fila 10)
	call POSIT
.tw_nm:
	call tw_rx
	jp   c, .tw_terr
	or   a
	jr   z, .tw_ready				; NUL = fin del nombre
	call CHPUT
	djnz .tw_nm
.tw_ready:
	ld   hl, #030D
	call POSIT
	ld   hl, tw_ready1				; "CINTA EN MARCHA..."
	call print_string
	ld   hl, #050F					; el comando a teclear en BASIC
	call POSIT
	ld   a, (TW_LOAD)
	ld   hl, tw_cmd_run
	or   a
	jr   z, .tw_pc
	ld   hl, tw_cmd_bload
	dec  a
	jr   z, .tw_pc
	ld   hl, tw_cmd_unk
.tw_pc:
	call print_string
	ld   hl, #0312
	call POSIT
	ld   hl, tw_ready2				; "RETURN = arrancar BASIC   ESC = cancelar"
	call print_string
.tw_wait:
	call prompt_getkey
	cp   #0D
	jp   z, boot_system				; a BASIC: la cinta sigue streameando
	cp   #1B
	jr   nz, .tw_wait
	ld   a, 'K'						; ESC: STOP al C6 (PLAY con size 0)
	out  (7), a
	xor  a
	out  (7), a
	out  (7), a
	jp   main_menu_restart
.tw_err:
	cp   3							; UNAPI_ERR_NO_DATA = sin coincidencias
	ld   hl, tw_notfound
	jr   z, .tw_pe
	ld   hl, tw_error
	jr   .tw_pe
.tw_terr:
	ld   hl, tw_timeout
.tw_pe:
	push hl
	ld   hl, #030A
	call POSIT
	pop  hl
	call print_string
	call prompt_getkey
	jp   main_menu_restart

; tw_rx: espera un byte de la UART del ESP (I/O 6/7). A=dato; CF=1 timeout ~2s.
tw_rx:
	push bc
	ld   b, 100						; ~100 x 17ms
.twr_f:
	push bc
	ld   bc, 2000					; poll rapido (~17ms)
.twr_i:
	in   a, (7)
	rrca							; bit0 (hay dato) -> CF
	jr   c, .twr_g
	dec  bc
	ld   a, b
	or   c
	jr   nz, .twr_i
	pop  bc
	djnz .twr_f
	pop  bc
	scf
	ret
.twr_g:
	in   a, (6)
	pop  bc
	pop  bc
	or   a							; CF=0
	ret

; tw_rx_long: como tw_rx pero ~40s (la descarga del TSX puede tardar).
tw_rx_long:
	push bc
	ld   b, 20						; 20 x 2s
.twl_f:
	push bc
	call tw_rx
	pop  bc
	jr   nc, .twl_ok
	djnz .twl_f
	pop  bc
	scf
	ret
.twl_ok:
	pop  bc
	or   a
	ret

; llama a la funcion UNAPI A (ROM del driver YA mapeado en pagina 1);
; conserva todos los registros de entrada, incluida HL
fh_unapi:
	push hl
	ld   hl, (FH_UNAPI_ADR)
	ex   (sp), hl
	ret								; = jp (entry)

; imprime A en hexadecimal (2 digitos)
fh_hex8:
	push af
	rrca
	rrca
	rrca
	rrca
	call ver_hex1
	pop  af
	jp   ver_hex1

; imprime A en decimal (1-3 digitos, sin ceros a la izquierda); usa B,C,D,E
fh_dec8:
	ld   c, 0						; c=1 cuando ya hay un digito impreso
	ld   b, 100
	call .fd_dig
	ld   b, 10
	call .fd_dig
	add  a, '0'						; unidades: siempre
	jp   #00A2
.fd_dig:
	ld   d, '0'-1
.fd_sub:
	inc  d
	sub  b
	jr   nc, .fd_sub
	add  a, b						; A = resto
	ld   e, a
	ld   a, d
	cp   '0'
	jr   nz, .fd_out				; digito != 0 -> imprimir
	bit  0, c
	jr   z, .fd_done				; cero a la izquierda -> omitir
.fd_out:
	call #00A2
	ld   c, 1
.fd_done:
	ld   a, e
	ret

fh_id:		.db "TCP/IP",0
fh_host:	.db "api.file-hunter.com",0
fh_m_rein:	.db 13,10,"Re-iniciando driver ESP...",13,10,0
fh_m_dq:	.db 13,10,"D:",0
fh_m_p1:	.db 13,10,"P:",0
fh_m_rst:	.db 13,10,"R:",0
fh_m_p2:	.db 13,10,"P2:",0

; --- FASE 1 FILE-HUNTER: buscar y listar online (tecla F) --------------------
; Pide una busqueda (>=2 chars), consulta la API index4 de file-hunter.com por
; HTTP sobre UNAPI y vuelca los resultados en ENT_ARRAY con el MISMO formato
; que el scan de la SD (type+cluster+size+nombre) para reutilizar el navegador
; completo (scroll, marquee, busqueda '/'). En cluster se guarda el INDICE del
; item dentro de esta query (la fase 2 descargara con download=N). FH_MODE=1
; hace que browse_key_loop desvie a fh_key_filter las teclas que tocan la SD o
; lanzan; ESC/BS salen re-escaneando la SD (el fetch machaca ENT_ARRAY).
; Red: MISMAS salvaguardas validadas en HW que la fase 0 (SP<#F363, backups
; HIMEM/H.TIMI, desinstalacion SIEMPRE), aqui como subrutinas fh_net_begin/end
; (guardan su direccion de retorno en FH_RETTMP porque cambian de stack).
; Request y RX reutilizan SD_BUF (512B): durante FH no hay actividad SD.
; API: registros de 7B (u32 ptr, u16 KB, u8 load) + terminador u32 0 + ASCIIZs
; en orden (los punteros relocados por base no hacen falta). Nombres <=73 en
; origen; se truncan a NAME_MAX (70) + NUL, como hace copy_name en el scan.

FH_MAXENT	equ	115				; cap = capacidad de ENT_ARRAY (115 registros)

fh_browse:
	; ---- prompt de busqueda (fila 0, como .br_search) ----
	xor  a
	ld   (FH_MODE), a				; durante el prompt aun no hay lista FH
	ld   hl, #0100
	call POSIT
	ld   hl, fh1_prompt
	call ver_puts
	ld   hl, FH_QUERY
	ld   b, 0
.f1_key:
	push hl
	push bc
	call prompt_getkey				; teclado sin marquee (no descoloca el prompt)
	pop  bc
	pop  hl
	cp   #0D
	jr   z, .f1_go
	cp   #1B
	jp   z, main_menu_restart		; cancelar
	cp   #08
	jr   z, .f1_del
	cp   ' '
	jr   c, .f1_key
	cp   #7F
	jr   nc, .f1_key
	ld   c, a
	ld   a, b
	cp   20
	jr   nc, .f1_key				; buffer lleno
	ld   a, c
	ld   (hl), a
	inc  hl
	inc  b
	call CHPUT						; eco
	jr   .f1_key
.f1_del:
	ld   a, b
	or   a
	jr   z, .f1_key
	dec  hl
	dec  b
	ld   a, #08
	call CHPUT
	ld   a, ' '
	call CHPUT
	ld   a, #08
	call CHPUT
	jr   .f1_key
.f1_go:
	ld   a, b
	cp   2
	jr   c, .f1_key					; minimo 2 chars (evita listas gigantes)
	ld   (hl), 0
; fh_refetch: relanza la busqueda (rom + dsk) con FH_QUERY ya fijada. Entrada
; tambien desde overwrite-N (fh2_abort_old) para volver a la pantalla de lista.
fh_refetch:
	ld   hl, fh1_m_net				; "  Conectando..."
	call ver_puts
	xor  a
	ld   (FH_BASEIDX), a			; ENT_ARRAY vacio
	ld   a, 1
	ld   (FH_CURTYPE), a			; 1a consulta: ROM
	call fh_one_query				; CF=1 error (HL=msg, SESION YA CERRADA)
	jp   c, fh_neterr
	ld   a, 2
	ld   (FH_CURTYPE), a			; 2a consulta: DSK (anexa a la lista ROM)
	call fh_one_query
	jp   c, fh_neterr
	ld   a, (FH_BASEIDX)			; total (rom + dsk)
	or   a
	jr   z, .fr_none
	ld   (ENT_COUNT), a
	xor  a
	ld   (BR_SEL), a
	ld   (BR_TOP), a
	ld   a, 1
	ld   (FH_MODE), a
	jp   browse						; navegador sobre los resultados FH (rom+dsk)
.fr_none:
	ld   hl, fh1_m_none
	jp   fh_neterr					; sin resultados: mensaje + tecla + volver

; ---- fh_one_query: UNA sesion de red completa para la consulta FH_CURTYPE ----
; (1=rom, 2=dsk). net_begin + dns + TCP_OPEN + GET + SEND + RX (el parser anexa
; en ENT_ARRAY desde FH_BASEIDX con tag +0=FH_CURTYPE) + TCP_ABORT + net_end, y
; FH_BASEIDX += FH_NREC. Sesion AUTONOMA = el patron probado del par 10 corrido
; DOS veces (rom, dsk) para juntar todo -> evita 2 TCP_OPEN en una sola sesion.
; CF=1 error (HL=msg, sesion YA cerrada -> el llamador usa fh_neterr).
fh_one_query:
	call fh_net_begin				; CF=1 -> HL=msg (nada abierto que cerrar)
	ret  c
	call fh_dns_wake
	jr   nc, .oq_open
	ld   hl, fh1_e_dns
	jp   .oq_err
.oq_open:
	ld   hl, FH_TCPP+4				; bloque TCP_OPEN (13 bytes)
	ld   (hl), 80
	inc  hl
	ld   (hl), 0
	inc  hl
	ld   (hl), #FF
	inc  hl
	ld   (hl), #FF
	inc  hl
	ld   (hl), 0
	inc  hl
	ld   (hl), 0
	inc  hl
	ld   (hl), 0
	inc  hl
	ld   (hl), 0
	inc  hl
	ld   (hl), 0
	ld   hl, FH_TCPP
	ld   a, 13						; TCPIP_TCP_OPEN
	call fh_unapi
	or   a
	jr   z, .oq_conn
	ld   hl, fh1_e_con
	jp   .oq_err
.oq_conn:
	ld   a, b
	ld   (FH_CONN), a
	call fh_build_gethead			; SD_BUF = "...&type=<rom|dsk>&msx=&char="
	ld   hl, FH_QUERY
.oq_q:
	ld   a, (hl)
	inc  hl
	or   a
	jr   z, .oq_q2
	cp   ' '
	jr   nz, .oq_q1
	ld   a, '+'						; espacios -> '+' (URL)
.oq_q1:
	ld   (de), a
	inc  de
	jr   .oq_q
.oq_q2:
	ld   hl, fh1_req2
	call fh_strcpy
	ex   de, hl						; HL = fin del request
	ld   bc, SD_BUF
	or   a
	sbc  hl, bc
	ld   (FH_REQLEN), hl
	ld   a, 100						; tope de reintentos de envio
	ld   (FH_TRIES), a
.oq_send:
	ld   a, (FH_CONN)
	ld   b, a
	ld   de, SD_BUF
	ld   hl, (FH_REQLEN)
	ld   c, 1						; PUSH
	ld   a, 17						; TCPIP_TCP_SEND
	call fh_unapi
	or   a
	jr   z, .oq_rx0
	cp   13							; ERR_BUFFER -> reintentar (acotado)
	jp   nz, .oq_serr
	ld   a, (FH_TRIES)
	dec  a
	ld   (FH_TRIES), a
	jp   z, .oq_serr				; reintentos agotados
	halt
	jr   .oq_send
.oq_rx0:
	xor  a
	ld   (FH_STATE), a				; 0 = cabeceras HTTP
	ld   (FH_NREC), a
	ld   (FH_SIDX), a
	ld   (FH_ACCN), a
	ld   (FH_CRLF), a
	ld   (FH_HPOS), a
	ld   (FH_FULL), a
	ld   (FH_DOTC), a
	ld   a, 120
	ld   (FH_TRIES), a				; timeout de inactividad ~10 s
.oq_rx:
	ld   a, (FH_CONN)
	ld   b, a
	ld   de, SD_BUF
	ld   hl, 512
	ld   a, 18						; TCPIP_TCP_RCV -> BC = bytes
	call fh_unapi
	cp   11							; ERR_NO_CONN: servidor cerro y drenado
	jr   z, .oq_fin
	or   a
	jr   nz, .oq_fin				; otros errores: terminar con lo recibido
	ld   a, b
	or   c
	jr   nz, .oq_data
	ld   b, 5						; sin datos: espera corta + timeout
.oq_rw:
	halt
	djnz .oq_rw
	ld   a, (FH_TRIES)
	dec  a
	ld   (FH_TRIES), a
	jr   nz, .oq_rx
	jr   .oq_fin
.oq_data:
	ld   a, 120
	ld   (FH_TRIES), a
	ld   a, (FH_DOTC)				; un punto cada ~4KB
	inc  a
	ld   (FH_DOTC), a
	and  #07
	jr   nz, .oq_nd
	ld   a, '.'
	call #00A2
.oq_nd:
	ld   hl, SD_BUF
.oq_dl:
	ld   a, (hl)
	inc  hl
	push hl
	push bc
	call fh_rx_byte
	pop  bc
	pop  hl
	ld   a, (FH_STATE)
	cp   9							; DONE: todas las strings copiadas
	jr   z, .oq_fin
	dec  bc
	ld   a, b
	or   c
	jr   nz, .oq_dl
	jr   .oq_rx
.oq_fin:
	ld   a, (FH_CONN)				; cerrar la conexion
	ld   b, a
	ld   a, 15						; TCPIP_TCP_ABORT
	call fh_unapi
	call fh_net_end					; cerrar la sesion (desinstalar SIEMPRE)
	ld   a, (FH_BASEIDX)			; FH_BASEIDX += FH_NREC (entradas anexadas)
	ld   c, a
	ld   a, (FH_NREC)
	add  a, c
	ld   (FH_BASEIDX), a
	or   a							; CF=0 OK
	ret
.oq_serr:
	ld   a, (FH_CONN)				; error de SEND: cerrar el socket abierto
	ld   b, a
	ld   a, 15
	call fh_unapi
	ld   hl, fh1_e_con
.oq_err:
	push hl							; error tras net_begin: net_end + CF=1
	call fh_net_end
	pop  hl
	scf
	ret

; error de red DESPUES de abrir sesion: cerrar/desinstalar y avisar (HL=msg)
fh_neterr_end:
	push hl
	call fh_net_end
	pop  hl
; error con sesion ya cerrada (HL=msg): fila 0 + tecla + volver al menu
fh_neterr:
	xor  a							; salir de File-Hunter: FH_MODE off y forzar
	ld   (FH_MODE), a				; re-scan de la SD (los buffers RX/meta pisan
	ld   (SD_READY), a				; ENT_ARRAY -> si no, la lista sale corrupta)
	push hl
	ld   hl, #0100
	call POSIT
	pop  hl
	call ver_puts
	call CHGET
	jp   main_menu_restart

; ---- procesa 1 byte recibido (A); estado en FH_STATE ----
; 0=cabeceras (status 2xx + CRLFCRLF)  1=registros 7B  2=strings  8=absorber  9=DONE
fh_rx_byte:
	ld   c, a
	ld   a, (FH_STATE)
	or   a
	jr   z, .fb_hdr
	cp   1
	jr   z, .fb_rec
	cp   2
	jp   z, .fb_str
	ret								; 8/9: absorber
.fb_hdr:
	ld   a, (FH_HPOS)
	inc  a
	jr   z, .fb_h2					; saturado: no envolver el contador
	ld   (FH_HPOS), a
	cp   10
	jr   nz, .fb_h2
	ld   a, c						; byte 10 de "HTTP/1.1 2xx" = '2'
	cp   '2'
	jr   z, .fb_h2
	ld   a, 8
	ld   (FH_STATE), a				; status no-2xx: absorber (0 resultados)
	ret
.fb_h2:
	ld   a, c						; deteccion CR LF CR LF
	cp   13
	jr   z, .fb_cr
	cp   10
	jr   z, .fb_lf
	xor  a
	ld   (FH_CRLF), a
	ret
.fb_cr:
	ld   a, (FH_CRLF)
	cp   2
	jr   z, .fb_c3
	ld   a, 1
	ld   (FH_CRLF), a
	ret
.fb_c3:
	ld   a, 3
	ld   (FH_CRLF), a
	ret
.fb_lf:
	ld   a, (FH_CRLF)
	cp   1
	jr   z, .fb_l2
	cp   3
	jr   z, .fb_body
	xor  a
	ld   (FH_CRLF), a
	ret
.fb_l2:
	ld   a, 2
	ld   (FH_CRLF), a
	ret
.fb_body:
	ld   a, 1						; empieza el cuerpo: registros de 7B
	ld   (FH_STATE), a
	xor  a
	ld   (FH_ACCN), a
	ld   a, (FH_BASEIDX)			; append: tras las entradas ya presentes (rom+dsk)
	call ent_addr					; HL = ENT_ARRAY + baseidx*ENT_SIZE
	ld   (FH_RPTR), hl
	ret
.fb_rec:
	ld   a, (FH_ACCN)				; acumular en FH_ACC
	ld   e, a
	ld   d, 0
	ld   hl, FH_ACC
	add  hl, de
	ld   (hl), c
	inc  a
	ld   (FH_ACCN), a
	cp   4
	jr   z, .fb_r4
	cp   7
	ret  nz
	xor  a							; registro completo
	ld   (FH_ACCN), a
	ld   a, (FH_BASEIDX)			; total = base + nrec (append rom+dsk)
	ld   c, a
	ld   a, (FH_NREC)
	add  a, c
	cp   FH_MAXENT
	jr   c, .fb_r7
	ld   a, 1						; cap alcanzado: ignorar el resto de
	ld   (FH_FULL), a				; registros (sus strings se cortan al
	ret								; llegar FH_SIDX a FH_NREC)
.fb_r7:
	ld   hl, (FH_RPTR)				; ENT_ARRAY[n] (layout real de .scr_store):
	ld   a, (FH_CURTYPE)			;   +0 type = rom(1)/dsk(2) de la consulta actual
	ld   (hl), a
	inc  hl
	ld   a, (FH_NREC)
	ld   (hl), a					;   +1..+4 indice del item DENTRO de esta consulta
	inc  hl
	ld   (hl), 0
	inc  hl
	ld   (hl), 0
	inc  hl
	ld   (hl), 0
	inc  hl
	ld   a, (FH_ACC+4)				;   +5..+8 size en BYTES = KB << 10
	ld   e, a						;   e = KB lo, d = KB hi
	ld   a, (FH_ACC+5)
	ld   d, a
	ld   (hl), 0					;   byte0 = 0
	inc  hl
	ld   a, e						;   byte1 = (lo<<2) & #FC
	rlca
	rlca
	and  #FC
	ld   (hl), a
	inc  hl
	ld   a, e						;   byte2 = (lo>>6) | ((hi<<2) & #FC)
	rlca
	rlca
	and  #03
	ld   c, a
	ld   a, d
	rlca
	rlca
	and  #FC
	or   c
	ld   (hl), a
	inc  hl
	ld   a, d						;   byte3 = hi >> 6
	rlca
	rlca
	and  #03
	ld   (hl), a
	ld   hl, (FH_RPTR)
	ld   de, ENT_SIZE
	add  hl, de
	ld   (FH_RPTR), hl
	ld   a, (FH_NREC)
	inc  a
	ld   (FH_NREC), a
	ret
.fb_r4:
	ld   hl, FH_ACC					; con 4 bytes: terminador u32 0?
	ld   a, (hl)
	inc  hl
	or   (hl)
	inc  hl
	or   (hl)
	inc  hl
	or   (hl)
	ret  nz							; no: seguir hasta 7
	ld   a, (FH_NREC)
	or   a
	jr   nz, .fb_s0
	ld   a, 9						; 0 registros -> DONE (sin resultados)
	ld   (FH_STATE), a
	ret
.fb_s0:
	ld   a, 2						; empiezan las strings (en orden)
	ld   (FH_STATE), a
	xor  a
	ld   (FH_SIDX), a
	ld   (FH_NPOS), a
	ld   a, (FH_BASEIDX)			; append: strings tras las entradas presentes
	call ent_addr					; HL = ENT_ARRAY + baseidx*ENT_SIZE
	ld   de, 9
	add  hl, de
	ld   (FH_WPTR), hl
	ret
.fb_str:
	ld   a, c
	or   a
	jr   z, .fb_se					; NUL: string cerrada
	ld   a, (FH_NPOS)
	cp   NAME_MAX
	ret  nc							; truncar a NAME_MAX + NUL (como copy_name)
	inc  a
	ld   (FH_NPOS), a
	ld   hl, (FH_WPTR)
	ld   (hl), c
	inc  hl
	ld   (FH_WPTR), hl
	ret
.fb_se:
	ld   hl, (FH_WPTR)
	ld   (hl), 0
	ld   a, (FH_SIDX)
	inc  a
	ld   (FH_SIDX), a
	ld   c, a
	ld   a, (FH_NREC)
	cp   c
	jr   z, .fb_done
	ld   a, (FH_BASEIDX)			; destino: ENT_ARRAY + (base + sidx)*ENT_SIZE + 9
	add  a, c
	call ent_addr
	ld   de, 9
	add  hl, de
	ld   (FH_WPTR), hl
	xor  a
	ld   (FH_NPOS), a
	ret
.fb_done:
	ld   a, 9
	ld   (FH_STATE), a
	ret

; ---- filtro de teclas en modo File-Hunter (llamado con CALL, A = tecla) ----
; Acciones FH: descartan la direccion de retorno (pop) y saltan. Teclas que
; tocan la SD o lanzan: devuelven A=0 (no casa con nada en el dispatch del
; navegador -> cae al 'jr .br_key' final = bucle). Resto: A intacta.
fh_key_filter:
	cp   #0D						; RETURN -> item (fase 2: descarga)
	jr   z, .kf_enter
	cp   #1B						; ESC / BACKSPACE -> salir de FH
	jr   z, .kf_exit
	cp   #08
	jr   z, .kf_exit
	cp   #46						; F -> nueva busqueda
	jr   z, .kf_new
	cp   #66
	jr   z, .kf_new
	cp   #09						; TAB, filtros R/D/A y S/W/U: inertes
	jr   z, .kf_eat
	cp   #52
	jr   z, .kf_eat
	cp   #72
	jr   z, .kf_eat
	cp   #44
	jr   z, .kf_eat
	cp   #64
	jr   z, .kf_eat
	cp   #41
	jr   z, .kf_eat
	cp   #61
	jr   z, .kf_eat
	cp   #53
	jr   z, .kf_eat
	cp   #73
	jr   z, .kf_eat
	cp   #57
	jr   z, .kf_eat
	cp   #77
	jr   z, .kf_eat
	cp   #55
	jr   z, .kf_eat
	cp   #75
	jr   z, .kf_eat
	ret								; cursores, '/', H: dispatch normal
.kf_eat:
	xor  a							; A=0: no casa con nada -> repite el bucle
	ret
.kf_enter:
	pop  af							; descartar retorno del CALL
	jp   fh_enter_item
.kf_exit:
	pop  af
	jp   fh_exit
.kf_new:
	pop  af
	jp   fh_browse

fh_exit:
	xor  a
	ld   (FH_MODE), a
	ld   (SD_READY), a				; ENT_ARRAY machacado: forzar re-scan SD
	jp   main_menu_restart

; ---- copia ASCIIZ HL->DE (el NUL no se copia; DE queda al final) ----
fh_strcpy:
	ld   a, (hl)
	or   a
	ret  z
	ld   (de), a
	inc  hl
	inc  de
	jr   fh_strcpy

; fh_build_gethead: monta "GET /MSXnano.php?base=1BA0&type=<rom|dsk>&msx=&char="
; en SD_BUF segun FH_CURTYPE (1=rom, 2=dsk). Devuelve DE = fin (tras "char="),
; listo para anexar la query. Comun a la lista (fh_one_query) y la descarga.
fh_build_gethead:
	ld   hl, fh1_req1
	ld   de, SD_BUF
	call fh_strcpy					; "...&type="
	ld   a, (FH_CURTYPE)
	cp   2
	ld   hl, fh1_t_rom
	jr   nz, .gh_t
	ld   hl, fh1_t_dsk
.gh_t:
	call fh_strcpy					; "rom" / "dsk"
	ld   hl, fh1_reqchr
	jp   fh_strcpy					; "&msx=&char=" -> DE al final

; ---- instalacion manual del hook EXTBIO del driver ESP ----
; En frio el INIT del ESP aborta sin instalar (H:1 puede ser HOKVLD residual
; con el hook en RETs) -> el discovery da 0 implementaciones. El menu instala
; el hook EL MISMO: convencion MSX de hook inter-slot (RST #30 + slot + addr
; + RET) apuntando a DO_EXTBIO (#4C73) del esp8266e.rom EXACTO del pack
; (build pineado, slot 0-2 = #88) + HOKVLD bit0. El driver funciona sin mas
; estado previo (su area de trabajo se asigna perezosamente via GETWRK).
fh_hook_install:
	di
	ld   a, #F7						; RST #30 (CALLF inter-slot)
	ld   (#FFCA), a
	ld   a, ESP_SLOT				; slot 0-2 expandido (#88)
	ld   (#FFCB), a
	ld   hl, #4C73					; DO_EXTBIO de ESTE build de esp8266e.rom
	ld   (#FFCC), hl
	ld   a, #C9						; RET de cierre del hook
	ld   (#FFCE), a
	ld   hl, #FB20					; HOKVLD bit0 = ext-BIOS valido
	set  0, (hl)
	ei
	ret

; ---- re-init del driver ESP (NO USADO: colgaba llamado desde el menu; el
;      fix real es el retraso de power-on en la FPGA. Se conserva de referencia) ----
; En frio, el INIT de boot del cartucho ESP corre ANTES de que el ESP-01 haya
; terminado de arrancar: el driver queda instalado "sin ESP" y su DO_EXTBIO
; responde 0 implementaciones PARA SIEMPRE (y el 2o pase del goauld se corta
; por el flag #EF/#F0 del puerto F2). Pasar por el setup W lo arregla porque
; su salida re-ejecuta INIT_UNAPI. Hacemos lo equivalente sin UI: F2:=0
; (semantica power-on -> el INIT hace el camino completo con re-deteccion) y
; CALL al INIT del cartucho (#4010, build pineado del pack). Imprime su
; welcome en pantalla (inofensivo) y puede tardar ~2-10s (con Auto Clock
; ademas conecta la WiFi y pone la hora). Usa (TXTTAB) como scratch igual
; que el setup W (probado en HW a diario). Deja pagina 1 = ROM del menu.
fh_reinit_driver:
	ld   hl, fh_m_rein
	call ver_puts
	di
	ld   a, ESP_SLOT
	ld   hl, #4000
	call ENASLT
	ei
	xor  a
	out  (#F2), a					; F2=0: fuerza el camino power-on del INIT
	call #4010						; INIT del cartucho ESP (ret al acabar)
	di
	ld   a, #87
	ld   hl, #4000
	call ENASLT
	ei
	ret

; ---- DNS con "despertador" de radio (v3: warm-reset del ESP) ----
; Tras el WIFIRELEASE que manda el INIT del ESP en el boot, la radio queda
; dormida y NADA de la UNAPI la despierta (probado en HW: ni DNS_Q ni el
; WIFIHOLD 'H', que solo RETIENE una conexion ya viva). Lo que hace el
; setup W (y por eso "arregla" la red) es un WARM RESET del ESP nada mas
; entrar (ESPUNAPI.asm RESET_ESP: CLEAR_UART + SET_SPEED + 'W'): al rebotar,
; el firmware del ESP se conecta SOLO a la red guardada. Replicamos eso como
; fase 2 del despertador; la fase 1 es un intento directo rapido para no
; pagar el reset (~5s) cuando la radio ya esta despierta. El driver siempre
; trabaja a la velocidad UART por defecto (SET_SPEED solo se usa en el reset),
; asi que el reset no desincroniza nada. NOTA: con "Auto Clock" activado en el
; setup W, el propio INIT del boot ya conecta la WiFi (pide la hora por NTP)
; y ademas pone en hora el reloj del MSX: recomendado.
; CF=0: IP resuelta y copiada a FH_TCPP+0..3. CF=1: agotado.
fh_dns_wake:
	; fase 1: intento directo (~4s) por si la radio ya esta despierta
	ld   a, 20						; 20 sondeos x ~200ms = ~4s
	ld   (FH_TRIES), a
	call .dw_q
	call .dw_poll
	ret  nc							; resuelto sin reset
	; fase 2: despertador real = warm-reset del ESP (protocolo del setup W)
	ld   a, 20
	out  (#06), a					; CLEAR_UART
	xor  a
	out  (#06), a					; SET_SPEED (velocidad por defecto)
	halt
	halt
	ld   a, 'W'						; CMD_WRESET_ESP: al rebotar reconecta solo
	out  (#07), a
	ld   b, 180						; ~3s: reboot del ESP + asociacion en marcha
.dw_boot:
	halt
	djnz .dw_boot
	ld   c, 64						; drenar la respuesta "Ready" del FIFO (acotado)
.dw_drain:
	in   a, (#07)
	bit  0, a						; bit0 = hay dato
	jr   z, .dw_drained
	in   a, (#06)
	dec  c
	jr   nz, .dw_drain
.dw_drained:
	ld   a, 20
	out  (#06), a					; UART limpia para el driver
	ld   a, 160						; 160 sondeos x ~200ms = ~32s
	ld   (FH_TRIES), a
	call .dw_q
	jp   .dw_poll					; CF final = veredicto

; sondea DNS_S re-lanzando DNS_Q en error; punto de progreso cada ~3s
; CF=0 resuelto (IP en FH_TCPP) / CF=1 agotado. Usa FH_TRIES como contador.
.dw_poll:
	ld   b, 12
.dw_w:
	halt
	djnz .dw_w
	ld   a, (FH_TRIES)
	dec  a
	ld   (FH_TRIES), a
	jr   z, .dw_fail
	and  #0F						; un punto cada ~3s
	jr   nz, .dw_np
	ld   a, '.'
	call #00A2
.dw_np:
	ld   b, 1						; limpiar resultado al leerlo
	ld   a, 7						; TCPIP_DNS_S
	call fh_unapi
	or   a
	jr   nz, .dw_req				; error (radio dormida/asociando): re-lanzar
	ld   a, b
	cp   2
	jr   nz, .dw_poll				; 1 = en curso
	ld   a, l						; resuelto: IP (L.H.E.D) -> FH_TCPP
	ld   (FH_TCPP+0), a
	ld   a, h
	ld   (FH_TCPP+1), a
	ld   a, e
	ld   (FH_TCPP+2), a
	ld   a, d
	ld   (FH_TCPP+3), a
	or   a							; CF=0
	ret
.dw_req:
	ld   a, (FH_TRIES)
	and  #1F						; re-DNS_Q como mucho cada ~6s
	jr   nz, .dw_poll
	call .dw_q
	jr   .dw_poll
.dw_fail:
	scf
	ret
.dw_q:
	ld   hl, fh_host
	ld   b, 0
	ld   a, 6						; TCPIP_DNS_Q
	call fh_unapi
	ret

; ---- abre la sesion de red (salvaguardas fase 0, en subrutina) ----
; Cambia de stack: guarda su retorno en FH_RETTMP. CF=0 ok (driver mapeado en
; pag.1); CF=1 fallo con TODO restaurado y HL=mensaje.
fh_net_begin:
	pop  hl
	ld   (FH_RETTMP), hl
	di
	ld   (FH_SAVE_SP), sp
	ld   sp, #F300					; bajo el area que asigna el driver (#F363)
	ld   hl, (FH_HIMEM)
	ld   (FH_SAVE_HIMEM), hl
	ld   hl, FH_HTIMI
	ld   de, FH_SAVE_HTIMI
	ld   bc, 5
	ldir
	ei
	xor  a
	ld   (FH_RETRIED), a
.nb_disc:
	ld   hl, fh_id
	ld   de, FH_ARG
	ld   bc, 7
	ldir
	ld   a, (FH_HOKVLD)
	bit  0, a
	jr   z, .nb_inst
	xor  a
	ld   b, a
	ld   de, #2222
	call FH_EXTBIO					; contar implementaciones
	ld   a, b
	or   a
	jr   nz, .nb_disc_ok
.nb_inst:
	ld   a, (FH_RETRIED)			; en frio el INIT del ESP no instala:
	or   a							; instalar el hook a mano y reintentar
	jr   nz, .nb_no
	ld   a, 1
	ld   (FH_RETRIED), a
	call fh_hook_install
	jr   .nb_disc
.nb_disc_ok:
	ld   a, 1
	ld   de, #2222
	call FH_EXTBIO					; datos: A=slot, HL=entry (asigna area!)
	ld   (FH_UNAPI_SLT), a
	ld   (FH_UNAPI_ADR), hl
	di
	ld   hl, #4000
	call ENASLT						; pag.1 -> ROM del driver (A=slot)
	ei
	or   a							; CF=0
	ld   hl, (FH_RETTMP)
	jp   (hl)
.nb_no:
	di								; fallo: restaurar (inocuo si no llego a
	ld   hl, FH_SAVE_HTIMI			; asignarse nada) y volver con CF=1
	ld   de, FH_HTIMI
	ld   bc, 5
	ldir
	ld   hl, (FH_SAVE_HIMEM)
	ld   (FH_HIMEM), hl
	xor  a
	ld   (FH_SLTWRK_P), a
	ld   (FH_SLTWRK_P+1), a
	ld   sp, (FH_SAVE_SP)
	ei
	ld   hl, fh1_e_unapi
	push hl
	ld   hl, (FH_RETTMP)
	ex   (sp), hl					; stack=retorno; HL=mensaje
	scf
	ret

; ---- cierra la sesion: desinstala el area volatil del driver y restaura ----
fh_net_end:
	pop  hl
	ld   (FH_RETTMP), hl
	ld   a, 20						; CLEAR_UART + WIFIRELEASE ('h'): soltar la
	out  (#06), a					; retencion de radio (simetrico del WIFIHOLD
	ld   a, 'h'						; de fh_dns_wake; el ESP vuelve a su politica
	out  (#07), a					; de Wi-Fi On Period)
	di
	ld   a, #87						; pag.1 -> ROM del menu
	ld   hl, #4000
	call ENASLT
	ld   hl, FH_SAVE_HTIMI			; H.TIMI original
	ld   de, FH_HTIMI
	ld   bc, 5
	ldir
	ld   hl, (FH_SAVE_HIMEM)		; HIMEM original
	ld   (FH_HIMEM), hl
	xor  a
	ld   (FH_SLTWRK_P), a			; puntero del area en SLTWRK a 0
	ld   (FH_SLTWRK_P+1), a
	ld   sp, (FH_SAVE_SP)
	ei
	ld   hl, (FH_RETTMP)
	jp   (hl)

fh1_prompt:	.db "File-Hunter (ROM+DSK) Buscar: ",0
fh1_m_net:	.db "  Conectando...",0
fh1_m_none:	.db "FH: sin resultados. Pulsa una tecla",0
fh1_m_f2:	.db "FH: la descarga llega en la fase 2. Pulsa una tecla",0
fh1_e_unapi:	.db "FH: UNAPI no disponible. Pulsa una tecla",0
fh1_e_red:	.db "FH: sin red (configurala con W). Pulsa una tecla",0
fh1_e_dns:	.db "FH: fallo de DNS. Pulsa una tecla",0
fh1_e_con:	.db "FH: fallo de conexion. Pulsa una tecla",0
fh1_req1:	.db "GET /MSXnano.php?base=1BA0&type=",0
fh1_reqchr:	.db "&msx=&char=",0
fh1_t_rom:	.db "rom",0
fh1_t_dsk:	.db "dsk",0
fh1_req2:	.db " HTTP/1.1",13,10,"Host: api.file-hunter.com",13,10,"User-Agent: MSXnano/1.9",13,10,"Connection: close",13,10,13,10,0

; --- FASE 2+3 FILE-HUNTER: descargar a FHUNT y lanzar (RETURN en la lista) ---
; RETURN sobre un item FH: re-consulta la API con download=N (N = indice del
; item guardado en el campo cluster por la fase 1), parsea la linea meta
; (size: y name:), y ESCRIBE el payload en la SD en la carpeta FHUNT de la
; raiz (creandola si no existe) con el nombre original en 8.3, en streaming
; sector a sector con encadenado FAT16 multi-cluster. Al terminar, lista la
; carpeta con el scan normal del navegador y AUTO-LANZA el fichero via
; browse_enter (el camino probado de carga+mapper+launch de la SD).
; El fichero QUEDA SIEMPRE en FHUNT (cache: si ya existe con el mismo tamano,
; se salta la descarga y se lanza directo).
; Limitaciones v1: FAT16 (como el flujo NEXTOR.EMU; error limpio en FAT32),
; nombres 8.3 (el menu no escribe LFN), carpeta FHUNT de 1 cluster, y si se
; re-descarga un nombre existente con distinto tamano la cadena vieja queda
; huerfana (recuperable con chkdsk; v1).
; Durante el streaming: TCP_RCV llena FH_RXB (el ESP esta en pag.1); el
; sector se monta en SD_BUF; cada operacion SD re-mapea pag.1 a 3-2 y vuelve
; a #87, asi que tras cada flush se re-mapea el ESP (#88) antes del siguiente
; RCV. El TCP hace flow-control, no se pierde nada.

; Buffers grandes en el espacio de ENT_ARRAY (#C300-#E6F0): durante la
; descarga el listado esta muerto (se reconstruye despues con scan_current)
FH_RXB		equ	#C400			; 512B: buffer RX de TCP (el request va en SD_BUF)
FH_SAVED	equ	#C600			; 512B: salva SD_BUF mientras fh2_alloc usa la FAT
FH_METALEN	equ	300				; meta real hasta 205B (nombre completo sin truncar)
; FH_METAB en page-3 libre (#EA00..#EB2C): NO en #C800 porque fh2_check_exists re-escanea
; ENT_ARRAY (#C300..#E6F0) que SOLAPABA #C800 (entrada 16) y pisaba la meta viva; y no cabe
; en page-2 (imagen del menu llena hasta ~#BEA1). #EA00 esta sobre los vars #E8xx y bajo #F000.
FH_METAB	equ	#EA00

; FH_LNBUF: nombre largo COMPLETO reconstruido por el precheck (fh2_check_exists).
; El lector antiguo (lfn_accumulate -> LFN_BUF) capa en 78 chars (6 entradas, buffer
; de 80B), pero el ESCRITOR graba hasta FH_MAXNAME=195. Comparar contra 78 daba
; falsos negativos (nombres >78 nunca casaban -> duplicados) y falsos positivos por
; prefijo. FH_LNBUF captura los 195 -> comparacion EXACTA. Va tras la meta (#EB2C),
; ambos vivos a la vez durante el precheck; #EB2C..#EBFB, bajo los vars #F000.
FH_LNBUFLEN	equ	208				; 16*13 (cubre FH_MAXNAME=195 + NUL)
FH_LNBUF	equ	FH_METAB+FH_METALEN	; #EB2C

FH_ADIR		equ	#10				; attr directorio
FH_AARC		equ	#20				; attr archivo

fh_enter_item:
	; ---- item seleccionado ----
	ld   a, (BR_SEL)
	call ent_addr					; HL -> ENT_ARRAY[sel]
	ld   a, (hl)					; +0 = tipo (1=rom, 2=dsk) -> type= de la descarga
	ld   (FH_CURTYPE), a
	inc  hl
	ld   a, (hl)					; +1 = indice del item DENTRO de su consulta
	ld   (FH_ITEM), a

	; ---- FAT16 solamente (el escritor, como el flujo NEXTOR.EMU) ----
	ld   a, (FS32)
	or   a
	ld   hl, fh2_e_fat32
	jp   nz, fh_neterr				; mensaje + tecla + volver

	ld   hl, #0100
	call POSIT
	ld   hl, fh2_m_prep				; "FH: preparando..."
	call ver_puts

	; ---- asegurar la carpeta FHUNT en la raiz (SD, sin red aun) ----
	call fh2_fhunt_ensure			; -> FH_DIRCLUS / CF=1 error (HL=msg)
	jp   c, fh_neterr

	; ---- sesion de red + DNS + TCP open (como la fase 1) ----
	call fh_net_begin
	jp   c, fh_neterr
	call fh_dns_wake
	jr   nc, .f2_open
	ld   hl, fh1_e_dns
	jp   fh_neterr_end
.f2_open:

	ld   hl, FH_TCPP+4
	ld   (hl), 80
	inc  hl
	ld   (hl), 0
	inc  hl
	ld   (hl), #FF
	inc  hl
	ld   (hl), #FF
	inc  hl
	ld   (hl), 0
	inc  hl
	ld   (hl), 0
	inc  hl
	ld   (hl), 0
	inc  hl
	ld   (hl), 0
	inc  hl
	ld   (hl), 0
	ld   hl, FH_TCPP
	ld   a, 13						; TCPIP_TCP_OPEN
	call fh_unapi
	or   a
	ld   hl, fh1_e_con
	jp   nz, fh_neterr_end
	ld   a, b
	ld   (FH_CONN), a

	; ---- GET con download=N (tipo del item en FH_CURTYPE + query en FH_QUERY) ----
	call fh_build_gethead			; SD_BUF = "...&type=<rom|dsk>&msx=&char="; DE al final
	ld   hl, FH_QUERY
.f2_q:
	ld   a, (hl)
	inc  hl
	or   a
	jr   z, .f2_q2
	cp   ' '
	jr   nz, .f2_q1
	ld   a, '+'
.f2_q1:
	ld   (de), a
	inc  de
	jr   .f2_q
.f2_q2:
	ld   hl, fh2_req_dl				; "&download="
	call fh_strcpy
	ld   a, (FH_ITEM)
	call fh2_wdec8					; escribe A en decimal en (DE)
	ld   hl, fh1_req2				; " HTTP/1.1..." + Host + close
	call fh_strcpy
	ex   de, hl
	ld   bc, SD_BUF
	or   a
	sbc  hl, bc
	ld   (FH_REQLEN), hl
	ld   a, 100
	ld   (FH_TRIES), a
.f2_send:
	ld   a, (FH_CONN)
	ld   b, a
	ld   de, SD_BUF
	ld   hl, (FH_REQLEN)
	ld   c, 1
	ld   a, 17						; TCPIP_TCP_SEND
	call fh_unapi
	or   a
	jr   z, .f2_rx0
	cp   13
	ld   hl, fh1_e_con
	jp   nz, fh_neterr_end
	ld   a, (FH_TRIES)
	dec  a
	ld   (FH_TRIES), a
	jp   z, fh_neterr_end
	halt
	jr   .f2_send

	; ---- recepcion: cabeceras + linea meta, luego payload en streaming ----
.f2_rx0:
	xor  a
	ld   (FH_STATE), a				; 0=cabeceras 1=meta 2=payload 8=error
	ld   (FH_DOOVR), a				; sin sobreescritura pedida aun
	ld   (FH_CRLF), a
	ld   (FH_HPOS), a
	ld   (FH_SECN), a
	ld   hl, 0
	ld   (FH_FILL), hl
	ld   (FH_PREV), hl
	ld   (FH_CLUS0), hl
	ld   (FH_DOTK), hl
	ld   hl, FH_METAB
	ld   (FH_METAP), hl
	ld   a, 120
	ld   (FH_TRIES), a
.f2_rx:
	ld   a, (FH_CONN)
	ld   b, a
	ld   de, FH_RXB
	ld   hl, 512
	ld   a, 18						; TCPIP_TCP_RCV -> BC bytes
	call fh_unapi
	cp   11							; conexion cerrada y drenada
	jp   z, .f2_eof
	or   a
	jp   nz, .f2_eof
	ld   a, b
	or   c
	jr   nz, .f2_data
	ld   b, 5
.f2_rw:
	halt
	djnz .f2_rw
	ld   a, (FH_TRIES)
	dec  a
	ld   (FH_TRIES), a
	jp   nz, .f2_rx
	ld   hl, fh2_e_dl				; timeout de inactividad
	jp   fh_neterr_end
.f2_data:
	ld   a, 120
	ld   (FH_TRIES), a
	ld   (FH_RXN), bc				; bytes en FH_RXB
	ld   hl, FH_RXB
	ld   (FH_RXP), hl
.f2_consume:
	; fase por bytes hasta que el estado llegue a 2 (payload)
	ld   a, (FH_STATE)
	cp   2
	jr   z, .f2_bulk
	cp   8
	jr   z, .f2_apierr
	ld   bc, (FH_RXN)
	ld   a, b
	or   c
	jp   z, .f2_rx					; buffer agotado: mas red
	ld   hl, (FH_RXP)
	ld   a, (hl)
	inc  hl
	ld   (FH_RXP), hl
	dec  bc
	ld   (FH_RXN), bc
	call fh2_rx_byte				; consume 1 byte (cabeceras/meta)
	jr   .f2_consume
.f2_apierr:
	ld   hl, fh2_e_api
	jp   fh_neterr_end
.f2_bulk:
	; payload en bloque: copiar min(FH_RXN, 512-FH_FILL, FH_WLEFT.bajo) a SD_BUF
	ld   bc, (FH_RXN)
	ld   a, b
	or   c
	jp   z, .f2_rx					; buffer agotado
	; limite por hueco del sector
	ld   hl, 512
	ld   de, (FH_FILL)
	or   a
	sbc  hl, de						; HL = hueco en SD_BUF
	; BC = min(BC, HL)
	ld   a, h
	cp   b
	jr   c, .f2_bhl
	jr   nz, .f2_bbc
	ld   a, l
	cp   c
	jr   nc, .f2_bbc
.f2_bhl:
	ld   b, h
	ld   c, l
.f2_bbc:
	; limite por lo que queda del fichero (si WLEFT alto=0 y bajo<BC)
	ld   a, (FH_WLEFT+2)
	or   a
	jr   nz, .f2_bcp
	ld   hl, (FH_WLEFT+0)
	ld   a, h
	cp   b
	jr   c, .f2_bwl
	jr   nz, .f2_bcp
	ld   a, l
	cp   c
	jr   nc, .f2_bcp
.f2_bwl:
	ld   b, h
	ld   c, l
.f2_bcp:
	; copiar BC bytes RXP -> SD_BUF+FILL
	ld   a, b
	or   c
	jp   z, .f2_fin					; WLEFT=0: descarga completa
	push bc
	ld   hl, (FH_RXP)
	ld   de, (FH_FILL)
	push hl
	ld   hl, SD_BUF
	add  hl, de
	ex   de, hl						; DE = destino
	pop  hl							; HL = origen
	ldir
	ld   (FH_RXP), hl
	pop  bc
	; actualizar contadores
	ld   hl, (FH_RXN)
	or   a
	sbc  hl, bc
	ld   (FH_RXN), hl
	ld   hl, (FH_FILL)
	add  hl, bc
	ld   (FH_FILL), hl
	ld   hl, (FH_WLEFT+0)			; WLEFT -= BC (32 bits)
	or   a
	sbc  hl, bc
	ld   (FH_WLEFT+0), hl
	jr   nc, .f2_nbw
	ld   hl, (FH_WLEFT+2)
	dec  hl
	ld   (FH_WLEFT+2), hl
.f2_nbw:
	; sector completo?
	ld   hl, (FH_FILL)
	ld   de, 512
	or   a
	sbc  hl, de
	jr   nz, .f2_wend
	call fh2_flush					; escribe el sector (CF=1 error+HL=msg)
	jp   c, fh_neterr_end
	ld   hl, 0
	ld   (FH_FILL), hl
.f2_wend:
	; fin del fichero? (bytes 0-2; el tamano esta capado a 1MB)
	ld   a, (FH_WLEFT+0)
	ld   hl, (FH_WLEFT+1)
	or   h
	or   l
	jp   nz, .f2_bulk
	jr   .f2_fin
.f2_eof:
	; conexion cerrada: valido solo si ya no queda nada por recibir
	ld   a, (FH_WLEFT+0)
	ld   hl, (FH_WLEFT+1)
	or   h
	or   l
	ld   hl, fh2_e_dl
	jp   nz, fh_neterr_end
.f2_fin:
	; ultimo sector parcial pendiente?
	ld   hl, (FH_FILL)
	ld   a, h
	or   l
	jr   z, .f2_nofl
	; zero-pad la cola (FH_FILL..511) para no escribir basura de SD_BUF
	ld   de, (FH_FILL)
	ld   hl, SD_BUF
	add  hl, de
	ld   (hl), 0
	ld   d, h
	ld   e, l
	inc  de
	push hl
	ld   hl, 511
	ld   bc, (FH_FILL)
	or   a
	sbc  hl, bc
	ld   b, h
	ld   c, l
	pop  hl
	ld   a, b
	or   c
	jr   z, .f2_padded
	ldir
.f2_padded:
	call fh2_flush
	jp   c, fh_neterr_end
.f2_nofl:
	; cerrar conexion y sesion
	ld   a, (FH_CONN)
	ld   b, a
	ld   a, 15						; TCPIP_TCP_ABORT
	call fh_unapi
	call fh_net_end
	call fh2_dirent					; escribir el nuevo (LFN+SFN)
	jp   c, .f2_derr
	ld   a, (FH_DOOVR)				; sobreescritura pedida en la meta?
	or   a
	jr   z, .f2_nofl_new
	call fh2_del_dirents			; CF=1 si no se borro -> no liberar (cross-link)
	jr   c, .f2_nofl_new
	ld   hl, (FH_OLDCLUS)
	call fh2_free_chain
.f2_nofl_new:
	ld   hl, (FH_CLUS0)
	ld   (FH_LAUNCHC), hl
fh2_launch:							; alias global (fh2_abort_old salta aqui)
.f2_launch:
	; listar FHUNT con el scan normal y auto-lanzar el fichero
	xor  a
	ld   (FH_MODE), a
	ld   (DIR_SP), a
	ld   (BR_TOP), a
	ld   a, 2
	ld   (FILTER), a				; ALL
	ld   a, 1
	ld   (SD_READY), a				; listado valido (no re-montar)
	ld   hl, (FH_DIRCLUS)
	ld   (CUR_CLUS+0), hl
	ld   hl, 0
	ld   (CUR_CLUS+2), hl
	call scan_current				; ENT_ARRAY = contenido de FHUNT
	call fh2_findsel				; BR_SEL por cluster (FH_LAUNCHC)
	jp   c, browse					; no encontrado: ensena la carpeta
	jp   browse_enter				; LANZAR (no vuelve)
.f2_derr:
	ld   hl, fh2_e_dir
	jp   fh_neterr

; ---- consume 1 byte (A) en fases cabeceras/meta ----
; estados: 0 = cabeceras HTTP (status 2xx + CRLFCRLF), 1 = linea meta hasta LF,
; al parsearla pasa a 2 (payload) o 8 (error API)
fh2_rx_byte:
	ld   c, a
	ld   a, (FH_STATE)
	or   a
	jr   z, .g_hdr
	; estado 1: acumular meta hasta LF
	ld   a, c
	cp   10
	jr   z, .g_meta
	cp   13
	ret  z							; CR: ignorar
	ld   hl, (FH_METAP)
	ld   de, FH_METAB+FH_METALEN-2	; guard atado al tamano (1B para el NUL)
	or   a
	sbc  hl, de
	jr   nc, .g_over				; meta demasiado larga: error
	ld   hl, (FH_METAP)
	ld   (hl), c
	inc  hl
	ld   (FH_METAP), hl
	ret
.g_over:
	ld   a, 8
	ld   (FH_STATE), a
	ret
.g_meta:
	ld   hl, (FH_METAP)
	ld   (hl), 0					; cerrar ASCIIZ
	jp   fh2_meta					; parsea y fija FH_STATE (2 u 8)
.g_hdr:
	ld   a, (FH_HPOS)
	inc  a
	jr   z, .g_h2
	ld   (FH_HPOS), a
	cp   10
	jr   nz, .g_h2
	ld   a, c
	cp   '2'
	jr   z, .g_h2
	ld   a, 8
	ld   (FH_STATE), a
	ret
.g_h2:
	ld   a, c
	cp   13
	jr   z, .g_cr
	cp   10
	jr   z, .g_lf
	xor  a
	ld   (FH_CRLF), a
	ret
.g_cr:
	ld   a, (FH_CRLF)
	cp   2
	jr   z, .g_c3
	ld   a, 1
	ld   (FH_CRLF), a
	ret
.g_c3:
	ld   a, 3
	ld   (FH_CRLF), a
	ret
.g_lf:
	ld   a, (FH_CRLF)
	cp   1
	jr   z, .g_l2
	cp   3
	jr   z, .g_body
	xor  a
	ld   (FH_CRLF), a
	ret
.g_l2:
	ld   a, 2
	ld   (FH_CRLF), a
	ret
.g_body:
	ld   a, 1						; empieza la linea meta
	ld   (FH_STATE), a
	ret

; ---- parsea FH_METAB: "type:...,size:NNN,name:XXXX.rom" ----
fh2_meta:
	; size:
	ld   hl, FH_METAB
	ld   de, fh2_k_size
	call fh2_find					; HL -> tras "size:" / CF=1
	jp   c, .m_bad
	call fh2_pdec					; FH_FSIZE (32b) desde (HL)
	; sanity: 0 < size <= 2MB (v2.0.1: era 1MB y rechazaba ROMs grandes
	; — Aleste 2 de 1216KB/2048KB — con "respuesta inesperada de la API";
	; 2MB = el limite fisico real de la megaram en ambas placas)
	ld   a, (FH_FSIZE+3)
	or   a
	jp   nz, .m_bad
	ld   a, (FH_FSIZE+2)
	cp   #21
	jp   nc, .m_bad
	ld   hl, (FH_FSIZE+0)
	ld   a, h
	or   l
	ld   a, (FH_FSIZE+2)
	or   h
	or   l
	jp   z, .m_bad
	ld   hl, (FH_FSIZE+0)
	ld   (FH_WLEFT+0), hl
	ld   hl, (FH_FSIZE+2)
	ld   (FH_WLEFT+2), hl
	; name:
	ld   hl, FH_METAB
	ld   de, fh2_k_name
	call fh2_find
	jp   c, .m_bad
	call fh2_typetag				; _182: el type: de la API -> etiqueta [mapper]
	call fh2_make83					; FH_NAME83 + FH_NAMEDOT
	; mostrar "-> NOMBRE tamKB"
	push hl
	ld   hl, #0100
	call POSIT
	ld   hl, fh2_m_down
	call ver_puts
	ld   hl, FH_NAMEDOT
	call ver_puts
	ld   a, ' '
	call #00A2
	pop  hl
	; precheck: ya existe? (nombre+tamano) ANTES de bajar el payload
	call fh2_check_exists			; CF=0 existe (FH_OLDCLUS)
	push af
	di								; sd_* dejaron pag.1 en el menu; volver al ESP
	ld   a, ESP_SLOT
	ld   hl, #4000
	call ENASLT
	ei
	pop  af
	jr   c, .m_go					; no existe -> descargar
	call fh2_ask_overwrite			; A = tecla
	cp   'S'
	jr   z, .m_ovr
	cp   's'
	jr   z, .m_ovr
	jp   fh2_abort_old				; N -> abortar SIN bajar el payload
.m_ovr:
	ld   a, 1
	ld   (FH_DOOVR), a				; borrar el viejo al terminar
.m_go:
	ld   a, 2
	ld   (FH_STATE), a				; payload
	ret
.m_bad:
	ld   a, 8
	ld   (FH_STATE), a
	ret

; ---- busca la subcadena (DE, ASCIIZ) en (HL, ASCIIZ); HL -> tras ella ----
fh2_find:
	push de
.ff_try:
	pop  de
	push de
	ld   a, (hl)
	or   a
	jr   z, .ff_no
	push hl
.ff_cmp:
	ld   a, (de)
	or   a
	jr   z, .ff_hit
	ld   c, a
	ld   a, (hl)
	cp   c
	jr   nz, .ff_miss
	inc  hl
	inc  de
	jr   .ff_cmp
.ff_miss:
	pop  hl
	inc  hl
	jr   .ff_try
.ff_hit:
	pop  af							; descartar el HL guardado
	pop  de
	or   a							; CF=0, HL tras la clave
	ret
.ff_no:
	pop  de
	scf
	ret

; ---- parsea decimal ASCII en (HL) -> FH_FSIZE (32 bits) ----
fh2_pdec:
	xor  a
	ld   (FH_FSIZE+0), a
	ld   (FH_FSIZE+1), a
	ld   (FH_FSIZE+2), a
	ld   (FH_FSIZE+3), a
.pd_l:
	ld   a, (hl)
	sub  '0'
	ret  c
	cp   10
	ret  nc
	inc  hl
	push hl
	push af
	; FSIZE = FSIZE*10 = (FSIZE*2) + (FSIZE*8)
	call .pd_x2						; *2
	ld   hl, (FH_FSIZE+0)
	ld   (FH_T10+0), hl
	ld   hl, (FH_FSIZE+2)
	ld   (FH_T10+2), hl				; T10 = x*2
	call .pd_x2
	call .pd_x2						; FSIZE = x*8
	ld   hl, (FH_T10+0)				; FSIZE += T10 -> x*10
	ld   de, (FH_FSIZE+0)
	add  hl, de
	ld   (FH_FSIZE+0), hl
	ld   hl, (FH_T10+2)
	ld   de, (FH_FSIZE+2)
	adc  hl, de
	ld   (FH_FSIZE+2), hl
	pop  af							; + digito
	ld   e, a
	ld   d, 0
	ld   hl, (FH_FSIZE+0)
	add  hl, de
	ld   (FH_FSIZE+0), hl
	jr   nc, .pd_nc
	ld   hl, (FH_FSIZE+2)
	inc  hl
	ld   (FH_FSIZE+2), hl
.pd_nc:
	pop  hl
	jr   .pd_l
.pd_x2:
	ld   hl, (FH_FSIZE+0)
	add  hl, hl
	ld   (FH_FSIZE+0), hl
	ld   hl, (FH_FSIZE+2)
	adc  hl, hl
	ld   (FH_FSIZE+2), hl
	ret

; ---- nombre de la API (HL, hasta NUL) -> FH_NAME83 (11B) + FH_NAMEDOT ----
; _182c: vive en el banco A010 (RAM) porque el banco de codigo iba tan justo
; que la variante NANO desbordaba el guard ds #A000-$ con el bloque dentro.
meg_disarm_esc:
	; _182c (patron cazado por Albert: cargar ROM -> ESC -> boot = cuelgue o
	; reset intermitente tras el logo, y a veces basura en screen1): la carga
	; deja la megaram ARMADA en el slot 2 (Slot2Mode del SWIO) con el "AB" del
	; juego a medias dentro y escribible; la BIOS del siguiente arranque la
	; escanea y EJECUTA el cartucho fantasma. Al salir sin lanzar: envenenar
	; la cabecera (AB -> 00 00, banco 0 en modo SCC, que es como carga SIEMPRE
	; load_rom) y dejarla write-protect. El Slot2Mode se queda como esta -- un
	; slot SCC vacio sin AB es invisible para la BIOS (mismo estado que deja
	; un lanzamiento normal tras su reset).
	di
	ld   a, MEG_SLOT				; pag.1 = megaram (slot 2)
	ld   hl, #4000
	call ENASLT
	xor  a
	ld   (#7FFE), a					; write-protect (el banco se fija asi)
	ld   (#5000), a					; reg0 = banco 0 (donde vive el "AB")
	ld   a, #10
	ld   (#7FFE), a					; write-enable
	xor  a
	ld   (#4000), a					; 'A' -> 0
	ld   (#4001), a					; 'B' -> 0
	ld   (#7FFE), a					; write-protect de nuevo
	ld   a, SD_SLOT_31				; pag.1 de vuelta al menu (slot 3-1)
	ld   hl, #4000
	call ENASLT
	ei
	jp   browse

; ---- _182: mete el mapper que YA manda la API como etiqueta en el nombre ----
; La cabecera empieza "type:<valor>,": ascii16 / ascii8 / konami / konamiscc
; (dsk y desconocidos: sin etiqueta). Se sobrescribe el nombre EN FH_METAB
; desde su ultimo punto: "NOMBRE.rom" -> "NOMBRE [ASCII16].rom". Todo lo de
; aguas abajo (8.3, display, precheck de existencia y escritura LFN) lee de
; ahi, asi que heredan la etiqueta sin tocarlos; y el lanzador ya prioriza
; la etiqueta del nombre sobre el escaneo (override_mapper_by_name), que es
; exactamente el reparto pedido: nombre primero, escaneo despues.
; Re-descargas: mismo type => mismo nombre etiquetado => el precheck de
; sobreescritura sigue casando. Entra/sale con HL = nombre en FH_METAB.
fh2_typetag:
	push hl
	ld   a, (FH_METAB)				; sanidad: la meta empieza por "type:"
	cp   't'
	jr   nz, .tt_r
	ld   a, (FH_METAB+5)			; valor[0]
	ld   de, fh2_tag_a16
	cp   'a'
	jr   z, .tt_a
	cp   'k'
	jr   nz, .tt_r					; plain/dsk/desconocido: sin etiqueta
	ld   a, (FH_METAB+11)			; "konami"+valor[6]: ',' fin o 's' de scc
	ld   de, fh2_tag_kon
	cp   's'
	jr   nz, .tt_i
	ld   de, fh2_tag_scc
	jr   .tt_i
.tt_a:
	ld   a, (FH_METAB+10)			; "ascii"+valor[5]: '1'=16, '8'=8
	cp   '8'
	jr   nz, .tt_i
	ld   de, fh2_tag_a8
.tt_i:
	ld   b, 0						; BC = ptr al ultimo '.' (0 = ninguno)
	ld   c, b
.tt_d:
	ld   a, (hl)
	or   a
	jr   z, .tt_de
	cp   '.'
	jr   nz, .tt_dn
	ld   b, h
	ld   c, l
.tt_dn:
	inc  hl
	jr   .tt_d
.tt_de:
	ld   a, b
	or   c
	jr   z, .tt_r					; sin punto: no tocar
	ld   h, d						; HL = etiqueta " [TAG].rom",0
	ld   l, e
	ld   d, b						; DE = ultimo punto del nombre
	ld   e, c
.tt_c:
	ld   a, (hl)
	ld   (de), a
	inc  hl
	inc  de
	or   a
	jr   nz, .tt_c
.tt_r:
	pop  hl
	ret

fh2_make83:
	push hl
	ld   hl, FH_NAME83				; rellenar con espacios
	ld   b, 11
.m8_sp:
	ld   (hl), ' '
	inc  hl
	djnz .m8_sp
	pop  hl
	; localizar el ULTIMO punto (extension)
	push hl
	ld   de, 0						; DE = ptr ultimo punto (0 = ninguno)
.m8_dot:
	ld   a, (hl)
	or   a
	jr   z, .m8_dend
	cp   '.'
	jr   nz, .m8_dn
	ld   d, h
	ld   e, l
.m8_dn:
	inc  hl
	jr   .m8_dot
.m8_dend:
	ld   (FH_EXTP), de
	pop  hl
	; base: hasta 8 chars validos (para antes del ultimo punto)
	ld   ix, FH_NAME83
	ld   b, 8
.m8_b:
	ld   a, (hl)
	or   a
	jr   z, .m8_ext
	ld   de, (FH_EXTP)
	ld   c, a
	ld   a, d
	or   e
	jr   z, .m8_b1
	push hl
	or   a
	sbc  hl, de
	pop  hl
	jr   nc, .m8_ext				; llegamos al punto de la extension
.m8_b1:
	ld   a, c
	inc  hl
	call fh2_valid					; CF=1 invalido (saltar)
	jr   c, .m8_b
	ld   (ix+0), a
	inc  ix
	djnz .m8_b
.m8_ext:
	; extension: 3 validos tras el ultimo punto
	ld   hl, (FH_EXTP)
	ld   a, h
	or   l
	jr   z, .m8_dotname
	inc  hl							; saltar el punto
	ld   ix, FH_NAME83+8
	ld   b, 3
.m8_e:
	ld   a, (hl)
	or   a
	jr   z, .m8_dotname
	inc  hl
	call fh2_valid
	jr   c, .m8_e
	ld   (ix+0), a
	inc  ix
	djnz .m8_e
.m8_dotname:
	; construir "BASE.EXT",0 en FH_NAMEDOT (para el matching del listado)
	ld   hl, FH_NAME83
	ld   de, FH_NAMEDOT
	ld   b, 8
.m8_c1:
	ld   a, (hl)
	cp   ' '
	jr   z, .m8_c1n
	ld   (de), a
	inc  de
.m8_c1n:
	inc  hl
	djnz .m8_c1
	ld   a, (FH_NAME83+8)
	cp   ' '
	jr   z, .m8_c3
	ld   a, '.'
	ld   (de), a
	inc  de
	ld   hl, FH_NAME83+8
	ld   b, 3
.m8_c2:
	ld   a, (hl)
	cp   ' '
	jr   z, .m8_c2n
	ld   (de), a
	inc  de
.m8_c2n:
	inc  hl
	djnz .m8_c2
.m8_c3:
	xor  a
	ld   (de), a
	ret

; char valido 8.3: A-Z 0-9 (a-z se sube); resto invalido (CF=1)
fh2_valid:
	cp   'a'
	jr   c, .v_1
	cp   'z'+1
	jr   nc, .v_1
	sub  #20						; a mayusculas
.v_1:
	cp   '0'
	jr   c, .v_no
	cp   '9'+1
	jr   c, .v_ok
	cp   'A'
	jr   c, .v_no
	cp   'Z'+1
	jr   nc, .v_no
.v_ok:
	or   a
	ret
.v_no:
	scf
	ret

; ---- escribe A en decimal ASCII en (DE) (1-3 digitos) ----
fh2_wdec8:
	ld   c, 0
	ld   b, 100
	call .w_dig
	ld   b, 10
	call .w_dig
	add  a, '0'
	ld   (de), a
	inc  de
	ret
.w_dig:
	ld   l, '0'-1
.w_sub:
	inc  l
	sub  b
	jr   nc, .w_sub
	add  a, b
	ld   h, a
	ld   a, l
	cp   '0'
	jr   nz, .w_out
	bit  0, c
	jr   z, .w_skip
.w_out:
	ld   (de), a
	inc  de
	ld   c, 1
.w_skip:
	ld   a, h
	ret

; ---- HL = cluster FAT16 -> SD_LBA = DATA_LBA + (HL-2) << SPC_SHIFT ----
fh2_clus2lba:
	dec  hl
	dec  hl
	ld   e, 0						; E = bits 16-23 del offset
	ld   a, (SPC_SHIFT)
	or   a
	jr   z, .cl_add
	ld   b, a
.cl_sh:
	add  hl, hl
	rl   e
	djnz .cl_sh
.cl_add:
	ld   a, e
	ld   de, (DATA_LBA+0)
	add  hl, de
	ld   (SD_LBA+0), hl
	ld   l, a
	ld   h, 0
	ld   de, (DATA_LBA+2)
	adc  hl, de
	ld   (SD_LBA+2), hl
	ret

; ---- FAT16[NEW_CLUS] = FH_FATVAL en ambas copias (patron mark_cluster_eof) --
fh2_fat_set:
	ld   hl, (NEW_CLUS)
	ld   a, h
	ld   (FH2_SEC), a
	ld   h, 0
	ld   a, (NEW_CLUS+0)
	ld   l, a
	add  hl, hl
	ld   (FH2_OFF), hl
	ld   hl, (FAT_LBA+0)
	ld   a, (FH2_SEC)
	ld   e, a
	ld   d, 0
	add  hl, de
	ld   (SD_LBA+0), hl
	ld   hl, (FAT_LBA+2)
	ld   de, 0
	adc  hl, de
	ld   (SD_LBA+2), hl
	call sd_read_sector
	ld   a, (SD_STATUS)
	or   a
	jr   nz, .fs_err
	ld   hl, SD_BUF
	ld   de, (FH2_OFF)
	add  hl, de
	ld   a, (FH_FATVAL+0)
	ld   (hl), a
	inc  hl
	ld   a, (FH_FATVAL+1)
	ld   (hl), a
	call sd_write_sector
	ld   a, (SD_STATUS)
	or   a
	jr   nz, .fs_err
	ld   a, (NUM_FATS)
	cp   2
	jr   c, .fs_ok
	ld   hl, (SD_LBA+0)
	ld   de, (FAT_SZ)
	add  hl, de
	ld   (SD_LBA+0), hl
	ld   hl, (SD_LBA+2)
	ld   de, 0
	adc  hl, de
	ld   (SD_LBA+2), hl
	call sd_write_sector
	ld   a, (SD_STATUS)
	or   a
	jr   nz, .fs_err
.fs_ok:
	or   a
	ret
.fs_err:
	scf
	ret

; ---- asigna el siguiente cluster de la cadena (EOF + enlace desde FH_PREV) --
fh2_alloc:
	call find_free_cluster			; DE = libre / CF=1
	ret  c
	ld   (FH_CURC), de
	ld   (NEW_CLUS), de
	call mark_cluster_eof			; EOF en el nuevo (lo saca del pool)
	ret  c
	ld   hl, (FH_PREV)
	ld   a, h
	or   l
	jr   z, .al_first
	ld   (NEW_CLUS), hl				; enlazar FH_PREV -> FH_CURC
	ld   hl, (FH_CURC)
	ld   (FH_FATVAL), hl
	call fh2_fat_set
	ret  c
	jr   .al_done
.al_first:
	ld   hl, (FH_CURC)
	ld   (FH_CLUS0), hl
.al_done:
	ld   hl, (FH_CURC)
	ld   (FH_PREV), hl
	ld   (NEW_CLUS), hl
	or   a
	ret

; ---- vuelca SD_BUF al sector actual del fichero (asigna cluster si toca) ----
; CF=1 error con HL = mensaje. Deja el ESP re-mapeado en pag.1 al salir.
fh2_flush:
	ld   a, (FH_SECN)
	or   a
	jr   nz, .fl_have
	; sector 0 del cluster: asignar el siguiente de la cadena.
	; OJO: fh2_alloc/find_free usan SD_BUF -> preservar el sector montado
	ld   hl, SD_BUF
	ld   de, FH_SAVED
	ld   bc, 512
	ldir
	call fh2_alloc
	jp   c, .fl_nsp
	ld   hl, FH_SAVED
	ld   de, SD_BUF
	ld   bc, 512
	ldir
.fl_have:
	ld   hl, (FH_CURC)
	call fh2_clus2lba				; SD_LBA = base del cluster
	ld   a, (FH_SECN)
	ld   e, a
	ld   d, 0
	ld   hl, (SD_LBA+0)
	add  hl, de
	ld   (SD_LBA+0), hl
	jr   nc, .fl_w
	ld   hl, (SD_LBA+2)
	inc  hl
	ld   (SD_LBA+2), hl
.fl_w:
	call sd_write_sector
	ld   a, (SD_STATUS)
	or   a
	jp   nz, .fl_err
	ld   a, (FH_SECN)
	inc  a
	ld   c, a
	ld   a, (SEC_PER_CLUS)
	cp   c
	jr   nz, .fl_ns
	ld   c, 0
.fl_ns:
	ld   a, c
	ld   (FH_SECN), a
	; progreso: un punto cada 32KB (64 sectores)
	ld   hl, (FH_DOTK)
	inc  hl
	ld   (FH_DOTK), hl
	ld   a, l
	and  #3F
	jr   nz, .fl_map
	ld   a, '.'
	call #00A2
.fl_map:
	di								; el ESP de vuelta a pag.1 para el RCV
	ld   a, ESP_SLOT
	ld   hl, #4000
	call ENASLT
	ei
	or   a
	ret
.fl_nsp:
	ld   hl, fh2_e_full
	jr   .fl_e2
.fl_err:
	ld   hl, fh2_e_e0
.fl_e2:
	push hl
	di
	ld   a, ESP_SLOT
	ld   hl, #4000
	call ENASLT
	ei
	pop  hl
	scf
	ret

; ---- asegura la carpeta FHUNT en la raiz -> FH_DIRCLUS / CF=1 (HL=msg) ----
fh2_fhunt_ensure:
	ld   hl, (ROOT_LBA+0)
	ld   (FH_DLBA+0), hl
	ld   hl, (ROOT_LBA+2)
	ld   (FH_DLBA+2), hl
	ld   a, (ROOT_SECS)
	ld   (FH_DSECS), a
	ld   hl, fh2_n_fhunt
	call fh2_dfind					; busca en la raiz / CF=1 no esta
	jr   nc, .fe_ok
	; CF=1 puede ser "no esta" o "no se pudo leer", y confundirlos DESTRUYE LA
	; TARJETA: se crea una FHUNT nueva, se pide un cluster y se escribe encima
	; de lo que hubiera. Cazado en placa el 21/08 con la traza de LBA: escribio
	; los 64 sectores del CLUSTER 2 (LBA 2584-2647), se llevo por delante
	; \System Volume Information y dejo el cluster 60 con vinculo cruzado.
	ld   a, (FH_DFERR)
	or   a
	jr   z, .fe_mk					; de verdad no esta -> crearla
	ld   hl, fh2_e_e1				; no se pudo leer -> ABORTAR, no crear
	scf
	ret
.fe_ok:
	; existe: cluster en DE (comprobar que es carpeta: attr bit4)
	bit  4, b
	ld   hl, fh2_e_dir
	jr   z, .fe_bad
	ld   (FH_DIRCLUS), de
	or   a
	ret
.fe_bad:
	scf
	ret
.fe_mk:
	; crear FHUNT: cluster + EOF + limpiar + "." / ".." + dirent en la raiz
	call find_free_cluster
	ld   hl, fh2_e_full
	ret  c
	ld   (FH_DIRCLUS), de
	ld   (NEW_CLUS), de
	call mark_cluster_eof
	ld   hl, fh2_e_e2
	ret  c
	; limpiar los sectores del cluster
	ld   hl, SD_BUF					; SD_BUF = 512 ceros
	ld   d, h
	ld   e, l
	inc  de
	ld   (hl), 0
	ld   bc, 511
	ldir
	ld   a, (SEC_PER_CLUS)
	ld   (FH2_LEFT), a
	ld   hl, (FH_DIRCLUS)
	call fh2_clus2lba
.fe_z:
	call sd_write_sector
	ld   a, (SD_STATUS)
	or   a
	ld   hl, fh2_e_e3
	jp   nz, .fe_sderr
	call inc_sd_lba
	ld   a, (FH2_LEFT)
	dec  a
	ld   (FH2_LEFT), a
	jr   nz, .fe_z
	; "." y ".." en el primer sector del cluster
	ld   hl, SD_BUF
	ld   d, h
	ld   e, l
	inc  de
	ld   (hl), 0
	ld   bc, 511
	ldir
	ld   ix, SD_BUF
	ld   b, 11
	ld   hl, fh2_n_dot
.fe_d1:
	ld   a, (hl)
	ld   (ix+0), a
	inc  hl
	inc  ix
	djnz .fe_d1
	ld   ix, SD_BUF
	ld   (ix+11), FH_ADIR
	ld   hl, (FH_DIRCLUS)
	ld   (ix+26), l
	ld   (ix+27), h
	ld   ix, SD_BUF+32
	ld   b, 11
	ld   hl, fh2_n_ddot
.fe_d2:
	ld   a, (hl)
	ld   (ix+0), a
	inc  hl
	inc  ix
	djnz .fe_d2
	ld   ix, SD_BUF+32
	ld   (ix+11), FH_ADIR			; ".." cluster 0 = raiz (FAT16)
	ld   hl, (FH_DIRCLUS)
	call fh2_clus2lba
	call sd_write_sector
	ld   a, (SD_STATUS)
	or   a
	ld   hl, fh2_e_e4
	jp   nz, .fe_sderr
	; dirent "FHUNT" en la raiz
	ld   hl, (FH_DIRCLUS)
	ld   (FH_DE_CLUS), hl
	xor  a
	ld   (FH_DE_ATTR), a			; se fija abajo
	ld   a, FH_ADIR
	ld   (FH_DE_ATTR), a
	ld   hl, 0
	ld   (FH_DE_SIZ+0), hl
	ld   (FH_DE_SIZ+2), hl
	ld   hl, (ROOT_LBA+0)
	ld   (FH_DLBA+0), hl
	ld   hl, (ROOT_LBA+2)
	ld   (FH_DLBA+2), hl
	ld   a, (ROOT_SECS)
	ld   (FH_DSECS), a
	ld   hl, fh2_n_fhunt
	call fh2_dwrite
	ld   hl, fh2_e_dir
	ret  c
	or   a
	ret
.fe_sderr:
	scf
	ret

; ---- busca nombre (HL, 11B) en la region de directorio FH_DLBA/FH_DSECS ----
; CF=0: DE = cluster de la entrada, B = attr, FH_FSIZ2 = size (4B)
fh2_dfind:
	ld   (FH_NPTR), hl
	xor  a
	ld   (FH_DFERR), a				; 0 = el veredicto es fiable
	ld   hl, (FH_DLBA+0)
	ld   (SD_LBA+0), hl
	ld   hl, (FH_DLBA+2)
	ld   (SD_LBA+2), hl
	ld   a, (FH_DSECS)
	ld   (FH2_LEFT), a
.df_sec:
	ld   a, (FH2_LEFT)
	or   a
	jp   z, .df_no
	call sd_read_sector
	ld   a, (SD_STATUS)
	or   a
	jp   nz, .df_sderr				; NO es "no esta": es "no he podido mirar"
	ld   ix, SD_BUF
	ld   b, 16
.df_ent:
	ld   a, (ix+0)
	or   a
	jp   z, .df_no					; fin de directorio
	cp   #E5
	jr   z, .df_next
	ld   a, (ix+11)					; saltar volume-label (#08) y LFN (#0F)
	and  #08
	jr   nz, .df_next
	push bc
	ld   hl, (FH_NPTR)
	push ix
	pop  de
	ld   b, 11
.df_cmp:
	ld   a, (de)
	cp   (hl)
	jr   nz, .df_nm
	inc  hl
	inc  de
	djnz .df_cmp
	pop  bc
	; match!
	ld   e, (ix+26)
	ld   d, (ix+27)
	ld   b, (ix+11)
	ld   l, (ix+28)
	ld   h, (ix+29)
	ld   (FH_FSIZ2+0), hl
	ld   l, (ix+30)
	ld   h, (ix+31)
	ld   (FH_FSIZ2+2), hl
	or   a
	ret
.df_nm:
	pop  bc
.df_next:
	ld   de, 32
	add  ix, de
	djnz .df_ent
	call inc_sd_lba
	ld   a, (FH2_LEFT)
	dec  a
	ld   (FH2_LEFT), a
	jr   .df_sec
.df_sderr:
	ld   a, 1
	ld   (FH_DFERR), a				; CF=1 pero NO significa "libre"
.df_no:
	scf
	ret

; ---- crea/sobrescribe la entrada (HL=nombre 11B) en FH_DLBA/FH_DSECS ----
; campos: FH_DE_ATTR, FH_DE_CLUS, FH_DE_SIZ. CF=1 sin hueco / error SD.
fh2_dwrite:
	ld   (FH_NPTR), hl
	ld   hl, (FH_DLBA+0)
	ld   (SD_LBA+0), hl
	ld   hl, (FH_DLBA+2)
	ld   (SD_LBA+2), hl
	ld   a, (FH_DSECS)
	ld   (FH2_LEFT), a
.dw_sec:
	ld   a, (FH2_LEFT)
	or   a
	jp   z, .dw_err
	call sd_read_sector
	ld   a, (SD_STATUS)
	or   a
	jp   nz, .dw_err
	ld   ix, SD_BUF
	ld   b, 16
.dw_ent:
	ld   a, (ix+0)
	or   a
	jp   z, .dw_put					; libre (fin de dir)
	cp   #E5
	jp   z, .dw_put					; borrado: reutilizar
	ld   a, (ix+11)					; no confundir volume-label/LFN con el nombre
	and  #08
	jr   nz, .dw_nm
	push bc
	ld   hl, (FH_NPTR)				; mismo nombre: sobrescribir
	push ix
	pop  de
	ld   b, 11
.dw_cmp:
	ld   a, (de)
	cp   (hl)
	jr   nz, .dw_nm
	inc  hl
	inc  de
	djnz .dw_cmp
	pop  bc
	jr   .dw_put
.dw_nm:
	pop  bc
	ld   de, 32
	add  ix, de
	djnz .dw_ent
	call inc_sd_lba
	ld   a, (FH2_LEFT)
	dec  a
	ld   (FH2_LEFT), a
	jr   .dw_sec
.dw_put:
	push ix							; limpiar los 32 bytes
	pop  hl
	ld   d, h
	ld   e, l
	inc  de
	ld   (hl), 0
	ld   bc, 31
	ldir
	push ix							; nombre 11B
	pop  de
	ld   hl, (FH_NPTR)
	ld   b, 11
.dw_nc:
	ld   a, (hl)
	ld   (de), a
	inc  hl
	inc  de
	djnz .dw_nc
	ld   a, (FH_DE_ATTR)
	ld   (ix+11), a
	ld   hl, (FH_DE_CLUS)
	ld   (ix+26), l
	ld   (ix+27), h
	ld   a, (FH_DE_SIZ+0)
	ld   (ix+28), a
	ld   a, (FH_DE_SIZ+1)
	ld   (ix+29), a
	ld   a, (FH_DE_SIZ+2)
	ld   (ix+30), a
	ld   a, (FH_DE_SIZ+3)
	ld   (ix+31), a
	call sd_write_sector
	ld   a, (SD_STATUS)
	or   a
	jp   nz, .dw_err
	or   a
	ret
.dw_err:
	scf
	ret

; ---- entrada final del fichero descargado en FHUNT ----
; ---- entrada final del fichero en FHUNT: LFN (nombre completo) + SFN 8.3 ----
; Escribe el nombre ORIGINAL de File-Hunter como entradas VFAT largas (LFN) +
; una entrada corta 8.3 unica "BASE~N". El nombre largo vive aun en FH_METAB
; (no se toca durante el streaming); se re-localiza con fh2_find "name:".
; Formato LFN validado contra referencia Python (checksum verbatim del spec
; FAT, 13 chars/entrada en offsets 1,3,5,7,9,14,16,18,20,22,24,28,30, orden
; fisico inverso: seq mas alta con #40 primero, luego SFN). Limitacion v1:
; FHUNT es 1 cluster; si no cabe (nlfn+1 entradas) -> error limpio.
FH_MAXNAME	equ	195				; cap del nombre largo (15 entradas LFN)

fh2_dirent:
	; region de directorio = cluster de FHUNT
	ld   hl, (FH_DIRCLUS)
	call fh2_clus2lba
	ld   hl, (SD_LBA+0)
	ld   (FH_DLBA+0), hl
	ld   hl, (SD_LBA+2)
	ld   (FH_DLBA+2), hl
	ld   a, (SEC_PER_CLUS)
	ld   (FH_DSECS), a

	; 1) SFN unico "BASE~N" en FH_NAME83 (busca N libre en FHUNT)
	call fh2_mk_sfn
	jp   c, fh2_de_err				; sin nombre fiable no se escribe nada
	; 2) checksum del SFN (enlaza las LFN con el 8.3)
	call fh2_lfn_cksum
	; 3) puntero + longitud del nombre completo (en FH_METAB)
	ld   hl, FH_METAB
	ld   de, fh2_k_name
	call fh2_find					; HL -> tras "name:" / CF=1
	jp   c, fh2_de_sfn				; sin name: (raro) -> solo SFN
	ld   (FH_FNPTR), hl
	call fh2_strlen					; FH_FNLEN = min(len, FH_MAXNAME)
	; nlfn = ceil(FH_FNLEN/13) por resta repetida (<=15 vueltas)
	ld   hl, (FH_FNLEN)
	ld   c, 0
	ld   de, 13
.de_nl:
	ld   a, h
	or   l
	jr   z, .de_nld
	inc  c
	or   a
	sbc  hl, de
	jr   nc, .de_nl
.de_nld:
	ld   a, c
	ld   (FH_NLFN), a
	or   a
	jp   z, fh2_de_sfn				; nombre vacio -> solo SFN (djnz b=0 daria 256!)
	; 4) end-of-dir index en FHUNT + sitio para nlfn+1 entradas
	call fh2_dir_eod				; FH_DIDX = 1a entrada libre / CF=1 lleno
	jp   c, fh2_de_err
	; total entradas del cluster = FH_DSECS*16 ; necesita FH_DIDX+nlfn+1 <=
	ld   a, (FH_DSECS)
	ld   l, a
	ld   h, 0
	add  hl, hl						; *2
	add  hl, hl						; *4
	add  hl, hl						; *8
	add  hl, hl						; *16
	ex   de, hl						; DE = total entradas
	ld   hl, (FH_DIDX)
	ld   a, (FH_NLFN)
	ld   c, a
	ld   b, 0
	add  hl, bc						; + nlfn
	inc  hl							; + SFN
	; HL <= DE ?
	ex   de, hl
	or   a
	sbc  hl, de						; total - (didx+nlfn+1)
	jp   c, fh2_de_err				; no cabe
	; 5) escribir: LFN k=nlfn..1 (rev), luego SFN
	ld   hl, (FH_DIDX)
	ld   (FH_PUTIDX), hl
	ld   a, (FH_NLFN)
	ld   b, a						; b = k actual (empieza en nlfn)
	ld   a, #40						; primera fisica lleva #40
	ld   (FH_MASK40), a
.de_lfn:
	ld   a, b
	push bc
	call fh2_build_lfn				; construye FH_ENT32 para seq A=k
	call fh2_dir_put				; escribe en FH_PUTIDX, incrementa
	pop  bc
	jp   c, fh2_de_err
	xor  a
	ld   (FH_MASK40), a				; solo la 1a lleva #40
	djnz .de_lfn
	; SFN entry
	call fh2_build_sfn				; FH_ENT32 = entrada corta
	call fh2_dir_put
	ret								; CF de fh2_dir_put

; solo SFN (sin nombre largo disponible)
fh2_de_sfn:
	call fh2_dir_eod
	jr   c, fh2_de_err
	ld   hl, (FH_DIDX)
	ld   (FH_PUTIDX), hl
	call fh2_build_sfn
	jp   fh2_dir_put
fh2_de_err:
	scf
	ret

; ---- muta FH_NAME83 a "BASE~N" 8.3 unico dentro de FHUNT (usa FH_DLBA/DSECS) --
fh2_mk_sfn:
	ld   hl, FH_NAME83				; base = chars no-espacio (hasta 6)
	ld   de, FH_SFNBASE
	ld   c, 0
	ld   b, 6
.ms_b:
	ld   a, (hl)
	cp   ' '
	jr   z, .ms_bd
	ld   (de), a
	inc  hl
	inc  de
	inc  c
	djnz .ms_b
.ms_bd:
	ld   a, c
	ld   (FH_SFNBLEN), a
	ld   a, 1
	ld   (FH_SFNN), a
.ms_try:
	ld   hl, FH_SFNBASE				; FH_NAME83[0..7] = base + '~' + N + pad
	ld   de, FH_NAME83
	ld   a, (FH_SFNBLEN)
	or   a
	jr   z, .ms_tl
	ld   b, a
.ms_cp:
	ld   a, (hl)
	ld   (de), a
	inc  hl
	inc  de
	djnz .ms_cp
.ms_tl:
	ld   a, '~'
	ld   (de), a
	inc  de
	ld   a, (FH_SFNN)
	add  a, '0'
	ld   (de), a
	inc  de
	ld   a, 6						; pad = 6 - blen espacios (base+2 escritos)
	ld   hl, FH_SFNBLEN
	sub  (hl)
	jr   z, .ms_chk
	ld   b, a
.ms_pad:
	ld   a, ' '
	ld   (de), a
	inc  de
	djnz .ms_pad
.ms_chk:
	ld   hl, FH_NAME83
	call fh2_dfind					; CF=1 = no existe... o no se pudo leer
	jr   nc, .ms_next				; existe -> probar el siguiente N
	ld   a, (FH_DFERR)
	or   a
	ret  z							; libre de verdad -> usarlo (CF=0)
	scf								; error de SD: no inventarse un nombre
	ret
.ms_next:
	ld   a, (FH_SFNN)
	inc  a
	ld   (FH_SFNN), a
	cp   10
	jr   c, .ms_try					; 1..9
	scf								; agotados: FALLAR. Antes salia con el ~9,
	ret								; que YA sabia ocupado -> entrada duplicada

; ---- checksum LFN del SFN (FH_NAME83, 11B) -> FH_CKSUM ----
fh2_lfn_cksum:
	ld   hl, FH_NAME83
	ld   b, 11
	ld   c, 0						; sum
.lc:
	ld   a, c
	rrca							; ((sum&1)<<7) | (sum>>1)
	add  a, (hl)
	ld   c, a
	inc  hl
	djnz .lc
	ld   a, c
	ld   (FH_CKSUM), a
	ret

; ---- strlen(FH_FNPTR) capado a FH_MAXNAME -> FH_FNLEN ----
fh2_strlen:
	ld   hl, (FH_FNPTR)
	ld   bc, 0
.sl:
	ld   a, (hl)
	or   a
	jr   z, .sl_e
	inc  hl
	inc  bc
	ld   a, c
	cp   FH_MAXNAME
	jr   c, .sl
.sl_e:
	ld   (FH_FNLEN), bc
	ret

; ---- FH_DIDX = indice de la 1a entrada 0x00 en FHUNT ; CF=1 si lleno ----
fh2_dir_eod:
	ld   hl, (FH_DLBA+0)
	ld   (SD_LBA+0), hl
	ld   hl, (FH_DLBA+2)
	ld   (SD_LBA+2), hl
	ld   a, (FH_DSECS)
	ld   (FH2_LEFT), a
	ld   hl, 0
	ld   (FH_DIDX), hl
.eo_sec:
	ld   a, (FH2_LEFT)
	or   a
	jr   z, .eo_full
	call sd_read_sector
	ld   a, (SD_STATUS)
	or   a
	jr   nz, .eo_full
	ld   ix, SD_BUF
	ld   b, 16
.eo_ent:
	ld   a, (ix+0)
	or   a
	jr   z, .eo_found				; 0x00 = fin de dir (todo libre despues)
	ld   de, 32
	add  ix, de
	ld   hl, (FH_DIDX)
	inc  hl
	ld   (FH_DIDX), hl
	djnz .eo_ent
	call inc_sd_lba
	ld   a, (FH2_LEFT)
	dec  a
	ld   (FH2_LEFT), a
	jr   .eo_sec
.eo_found:
	or   a
	ret
.eo_full:
	scf
	ret

; ---- escribe FH_ENT32 en la entrada FH_PUTIDX de FHUNT, luego FH_PUTIDX++ ----
; CF=1 error de SD.
fh2_dir_put:
	ld   hl, (FH_PUTIDX)
	ld   a, l
	and  #0F
	ld   (FH_PUTSLOT), a			; slot 0..15
	ld   b, 4						; sec offset = idx>>4
.dp_sh:
	srl  h
	rr   l
	djnz .dp_sh
	ld   de, (FH_DLBA+0)
	add  hl, de
	ld   (SD_LBA+0), hl
	ld   hl, (FH_DLBA+2)
	ld   de, 0
	adc  hl, de
	ld   (SD_LBA+2), hl
	call sd_read_sector
	ld   a, (SD_STATUS)
	or   a
	jr   nz, .dp_err
	ld   a, (FH_PUTSLOT)			; dest = SD_BUF + slot*32
	ld   l, a
	ld   h, 0
	add  hl, hl						; *2
	add  hl, hl						; *4
	add  hl, hl						; *8
	add  hl, hl						; *16
	add  hl, hl						; *32
	ld   de, SD_BUF
	add  hl, de
	ex   de, hl						; DE = destino
	ld   hl, FH_ENT32
	ld   bc, 32
	ldir
	call sd_write_sector
	ld   a, (SD_STATUS)
	or   a
	jr   nz, .dp_err
	ld   hl, (FH_PUTIDX)
	inc  hl
	ld   (FH_PUTIDX), hl
	or   a
	ret
.dp_err:
	scf
	ret

; ---- construye la entrada LFN seq A (1-based) en FH_ENT32 ----
fh2_build_lfn:
	push af
	ld   hl, FH_ENT32				; limpiar 32 bytes
	ld   de, FH_ENT32+1
	ld   (hl), 0
	ld   bc, 31
	ldir
	ld   a, #0F
	ld   (FH_ENT32+11), a
	ld   a, (FH_CKSUM)
	ld   (FH_ENT32+13), a
	pop  af
	ld   c, a						; seq | mask
	ld   a, (FH_MASK40)
	or   c
	ld   (FH_ENT32), a
	; char base = (seq-1)*13
	ld   a, c						; c = seq (sin mask)
	dec  a
	ld   l, a
	ld   h, 0
	push hl							; *13 = *8 + *4 + *1
	add  hl, hl						; *2
	add  hl, hl						; *4
	push hl							; guarda *4
	add  hl, hl						; *8
	pop  de							; de = *4
	add  hl, de						; *12
	pop  de							; de = *1
	add  hl, de						; *13
	ld   (FH_CGI), hl				; gi corriente
	; recorrer 13 slots
	ld   ix, fh2_lfn_slots
	ld   b, 13
.bl_c:
	push bc
	; cp: comparar CGI con FNLEN
	ld   hl, (FH_CGI)
	ld   de, (FH_FNLEN)
	or   a
	sbc  hl, de						; CGI - FNLEN
	jr   c, .bl_char				; CGI < len -> char real
	jr   z, .bl_term				; CGI == len -> 0x0000
	; CGI > len -> 0xFFFF (byte alto en B: DE se reusa para el puntero)
	ld   c, #FF
	ld   b, #FF
	jr   .bl_put
.bl_term:
	ld   c, 0
	ld   b, 0
	jr   .bl_put
.bl_char:
	ld   hl, (FH_FNPTR)
	ld   de, (FH_CGI)
	add  hl, de
	ld   c, (hl)					; low = char (latin-1)
	ld   b, 0						; high = 0 (B es scratch: push/pop bc lo salva)
.bl_put:
	ld   a, (ix+0)					; slot offset dentro de la entrada
	ld   l, a
	ld   h, 0
	ld   de, FH_ENT32
	add  hl, de						; HL = FH_ENT32 + slot
	ld   (hl), c					; byte bajo
	inc  hl
	ld   a, b						; byte alto (0 o #FF), NO E (la pisa ld de arriba)
	ld   (hl), a
	inc  ix
	ld   hl, (FH_CGI)
	inc  hl
	ld   (FH_CGI), hl
	pop  bc
	djnz .bl_c
	ret

; ---- construye la entrada SFN 8.3 en FH_ENT32 ----
fh2_build_sfn:
	ld   hl, FH_ENT32
	ld   de, FH_ENT32+1
	ld   (hl), 0
	ld   bc, 31
	ldir
	ld   hl, FH_NAME83				; nombre 8.3 (11B)
	ld   de, FH_ENT32
	ld   bc, 11
	ldir
	ld   a, FH_AARC					; attr archivo
	ld   (FH_ENT32+11), a
	ld   hl, (FH_CLUS0)
	ld   a, l
	ld   (FH_ENT32+26), a
	ld   a, h
	ld   (FH_ENT32+27), a
	ld   a, (FH_FSIZE+0)
	ld   (FH_ENT32+28), a
	ld   a, (FH_FSIZE+1)
	ld   (FH_ENT32+29), a
	ld   a, (FH_FSIZE+2)
	ld   (FH_ENT32+30), a
	ld   a, (FH_FSIZE+3)
	ld   (FH_ENT32+31), a
	ret

fh2_lfn_slots:	.db 1,3,5,7,9,14,16,18,20,22,24,28,30

; ---- localiza FH_NAMEDOT en ENT_ARRAY -> BR_SEL (CF=1 no encontrado) ----
fh2_findsel:
	; match por CLUSTER (FH_CLUS0) en vez de por nombre: con LFN el listado
	; guarda el nombre LARGO, no el 8.3, asi que el cluster es el ancla fiable
	ld   a, (ENT_COUNT)
	or   a
	jr   z, .fs_no
	ld   c, a
	ld   b, 0
.fs_i:
	ld   a, b
	push bc
	call ent_addr					; HL -> entrada
	inc  hl							; +1 = cluster lo
	ld   de, (FH_LAUNCHC)
	ld   a, (hl)
	cp   e
	jr   nz, .fs_n
	inc  hl
	ld   a, (hl)					; +2 = cluster hi
	cp   d
	jr   nz, .fs_n
	pop  bc
	ld   a, b
	ld   (BR_SEL), a
	or   a
	ret
.fs_n:
	pop  bc
	inc  b
	dec  c
	jr   nz, .fs_i
.fs_no:
	scf
	ret

; ---- existe en FHUNT? (scan DIRECTO: SD_BUF + LFN_BUF, NO ENT_ARRAY/FH_RXB) ----
; Se llama TRAS parsear la meta y ANTES de bajar el payload, para poder abortar
; sin descargar el juego. Reconstruye el nombre largo COMPLETO de cada fichero con
; fh2_lfn_acc (a FH_LNBUF, #EB2C, hasta 195) y compara nombre+tamano EXACTOS con
; FH_METAB + FH_FSIZE. Usa SD_BUF/FH_LNBUF, que NO solapan FH_RXB(#C400) ni
; FH_METAB(#EA00), asi el resto del payload en FH_RXB sobrevive. CF=0 existe
; (FH_OLDCLUS) / CF=1 no.
fh2_check_exists:
	ld   hl, FH_METAB
	ld   de, fh2_k_name
	call fh2_find
	ret  c							; sin name -> no existe
	ld   (FH_FNPTR), hl
	ld   hl, (FH_DIRCLUS)
	call fh2_clus2lba				; SD_LBA = 1er sector del cluster FHUNT
	ld   a, (SEC_PER_CLUS)
	ld   (FH2_LEFT), a
	xor  a
	ld   (HAVE_LFN), a
.cx_sec:
	ld   a, (FH2_LEFT)
	or   a
	jr   z, .cx_no
	call sd_read_sector
	ld   a, (SD_STATUS)
	or   a
	jr   nz, .cx_no
	ld   ix, SD_BUF
	ld   b, 16
.cx_ent:
	ld   a, (ix+0)
	or   a
	jr   z, .cx_no					; fin de dir
	cp   #E5
	jr   z, .cx_reset				; borrado
	ld   a, (ix+11)
	cp   #0F
	jr   z, .cx_lfn					; entrada LFN -> acumular (NO reset)
	and  #18						; dir (#10) o volume-label (#08)?
	jr   nz, .cx_reset
	ld   a, (HAVE_LFN)				; fichero: tiene nombre largo acumulado?
	or   a
	jr   z, .cx_reset				; no -> ignorar
	push bc							; B = contador de 16 entradas; fh2_cmp_entry lo pisa
	call fh2_cmp_entry				; CF=0 match (nombre+tamano)
	pop  bc							; restaurar B en match Y en mismatch
	jr   nc, .cx_hit
.cx_reset:
	xor  a
	ld   (HAVE_LFN), a
	ld   de, 32
	add  ix, de
	djnz .cx_ent
	jr   .cx_nextsec
.cx_lfn:
	push bc
	call fh2_lfn_acc				; IX = entrada LFN -> FH_LNBUF (nombre completo)
	pop  bc
	ld   de, 32
	add  ix, de
	djnz .cx_ent
.cx_nextsec:
	call inc_sd_lba
	ld   a, (FH2_LEFT)
	dec  a
	ld   (FH2_LEFT), a
	jr   .cx_sec
.cx_hit:
	ld   l, (ix+26)
	ld   h, (ix+27)
	ld   (FH_OLDCLUS), hl
	or   a							; CF=0 existe
	ret
.cx_no:
	scf
	ret

; ---- compara LFN_BUF (nombre) + (ix+28..31 tamano) con FH_FNPTR + FH_FSIZE ----
; CF=0 si ambos coinciden.
fh2_cmp_entry:
	push ix							; tamano: ix+28..31 vs FH_FSIZE (4B)
	pop  hl
	ld   de, 28
	add  hl, de
	ld   de, FH_FSIZE
	ld   b, 4
.cme_sz:
	ld   a, (de)
	cp   (hl)
	jr   nz, .cme_no
	inc  hl
	inc  de
	djnz .cme_sz
	ld   hl, FH_LNBUF				; nombre COMPLETO reconstruido (<=195)
	ld   de, (FH_FNPTR)
	ld   b, FH_MAXNAME				; el escritor capa a 195; comparar como mucho 195
.cme_nm:
	ld   a, (de)
	ld   c, a
	ld   a, (hl)
	cp   c
	jr   nz, .cme_no
	or   a
	jr   z, .cme_yes				; ambos NUL a la vez -> mismo largo y contenido exactos
	inc  hl
	inc  de
	djnz .cme_nm
	; 195 chars iguales sin NUL comun: ambos nombres son >=195; el escritor los
	; trunca a 195, asi que en disco quedarian identicos -> match (tamano ya OK)
.cme_yes:
	or   a							; CF=0
	ret
.cme_no:
	scf
	ret

; ---- N (no sobreescribir): abortar TCP sin bajar el payload, lanzar el viejo ----
fh2_abort_old:
	ld   a, (FH_CONN)
	ld   b, a
	ld   a, 15						; TCPIP_TCP_ABORT (descarta el payload pendiente)
	call fh_unapi
	call fh_net_end
	jp   fh_refetch					; N = no sobreescribir: volver a la lista (re-buscar)

; ---- pregunta "sobreescribir?" -> A = tecla ----
fh2_ask_overwrite:
	ld   hl, #0100
	call POSIT
	ld   hl, fh2_m_exists
	call ver_puts
	call CHGET
	ret

; ---- libera la cadena de clusters FAT16 desde HL ----
fh2_free_chain:
	ld   (FH_FREECUR), hl
.fc_l:
	ld   hl, (FH_FREECUR)
	ld   a, h
	cp   #FF
	jr   z, .fc_hi					; hi=FF -> mirar lo (EOC/bad/reserved)
	or   l
	jr   z, .fc_done				; cluster 0 = libre -> fin
	jr   .fc_free
.fc_hi:
	ld   a, l
	cp   #F0						; >= 0xFFF0 -> EOC/reservado/bad -> fin
	jr   nc, .fc_done
.fc_free:
	ld   hl, (FH_FREECUR)			; next = fatnext(cur)
	ld   (W_TMP+0), hl
	ld   hl, 0
	ld   (W_TMP+2), hl
	call fatnext
	ret  c							; error leyendo FAT -> abortar (leak benigno, NO cross-link)
	ld   hl, 0						; liberar cur en la FAT (ambas copias)
	ld   (FH_FATVAL), hl
	ld   hl, (FH_FREECUR)
	ld   (NEW_CLUS), hl
	call fh2_fat_set
	ret  c							; error escribiendo FAT -> abortar
	ld   hl, (W_TMP+0)				; cur = next (16b; EOC normalizado a 0xFFF8)
	ld   (FH_FREECUR), hl
	jr   .fc_l
.fc_done:
	ret

; ---- borra (0xE5) el SFN cuyo cluster==FH_OLDCLUS + sus LFN previas ----
; usa FH_DLBA/FH_DSECS (ya seteados a FHUNT por fh2_dirent en la ruta S)
fh2_del_dirents:
	ld   hl, (FH_DLBA+0)
	ld   (SD_LBA+0), hl
	ld   hl, (FH_DLBA+2)
	ld   (SD_LBA+2), hl
	ld   a, (FH_DSECS)
	ld   (FH2_LEFT), a
	ld   hl, 0
	ld   (FH_DIDX), hl
	ld   (FH_LFNRUN), hl
.dd_sec:
	ld   a, (FH2_LEFT)
	or   a
	jr   z, .dd_fail				; escaneado todo, no encontrado
	call sd_read_sector
	ld   a, (SD_STATUS)
	or   a
	jr   nz, .dd_fail
	ld   ix, SD_BUF
	ld   b, 16
.dd_ent:
	ld   a, (ix+0)
	or   a
	jr   z, .dd_fail				; fin de dir -> no encontrado
	cp   #E5
	jr   z, .dd_reset
	ld   a, (ix+11)
	cp   #0F
	jr   z, .dd_adv					; LFN -> el grupo continua (no reset)
	ld   a, (ix+26)					; SFN: cluster == FH_OLDCLUS?
	ld   hl, (FH_OLDCLUS)
	cp   l
	jr   nz, .dd_reset
	ld   a, (ix+27)
	cp   h
	jr   nz, .dd_reset
	jp   fh2_do_del					; MATCH -> borrar [FH_LFNRUN..FH_DIDX]
.dd_reset:
	ld   de, 32
	add  ix, de
	ld   hl, (FH_DIDX)
	inc  hl
	ld   (FH_DIDX), hl
	ld   (FH_LFNRUN), hl			; el proximo grupo empieza aqui
	djnz .dd_ent
	call inc_sd_lba
	ld   a, (FH2_LEFT)
	dec  a
	ld   (FH2_LEFT), a
	jr   .dd_sec
.dd_adv:
	ld   de, 32
	add  ix, de
	ld   hl, (FH_DIDX)
	inc  hl
	ld   (FH_DIDX), hl
	djnz .dd_ent
	call inc_sd_lba
	ld   a, (FH2_LEFT)
	dec  a
	ld   (FH2_LEFT), a
	jr   .dd_sec

.dd_fail:
	scf								; CF=1: no se borro (error SD o no encontrado)
	ret

; marca 0xE5 desde FH_LFNRUN hasta FH_DIDX (inclusive); CF=0 ok / CF=1 error SD
fh2_do_del:
.dod_l:
	call fh2_mark_e5				; marca la entrada FH_LFNRUN
	ret  c							; error de SD marcando -> propagar (no liberar cadena)
	ld   hl, (FH_LFNRUN)
	ld   de, (FH_DIDX)
	or   a
	sbc  hl, de
	ret  z							; LFNRUN == DIDX (CF=0) -> borrado completo OK
	ld   hl, (FH_LFNRUN)
	inc  hl
	ld   (FH_LFNRUN), hl
	jr   .dod_l

; marca la entrada FH_LFNRUN como borrada (byte0 = 0xE5)
fh2_mark_e5:
	ld   hl, (FH_LFNRUN)
	ld   a, l
	and  #0F
	ld   (FH_PUTSLOT), a
	ld   b, 4
.me_sh:
	srl  h
	rr   l
	djnz .me_sh
	ld   de, (FH_DLBA+0)
	add  hl, de
	ld   (SD_LBA+0), hl
	ld   hl, (FH_DLBA+2)
	ld   de, 0
	adc  hl, de
	ld   (SD_LBA+2), hl
	call sd_read_sector
	ld   a, (SD_STATUS)
	or   a
	scf
	ret  nz							; error de lectura -> CF=1
	ld   a, (FH_PUTSLOT)
	ld   l, a
	ld   h, 0
	add  hl, hl
	add  hl, hl
	add  hl, hl
	add  hl, hl
	add  hl, hl						; *32
	ld   de, SD_BUF
	add  hl, de
	ld   (hl), #E5					; byte0 = entrada borrada
	call sd_write_sector
	ld   a, (SD_STATUS)
	or   a
	scf
	ret  nz							; error de escritura -> CF=1
	or   a							; CF=0 ok
	ret

fh2_m_exists:	.db "Ya existe. Sobreescribir? (S/N)",0

fh2_k_size:	.db "size:",0
fh2_k_name:	.db "name:",0
; _182: etiquetas de mapper (el lanzador reconoce ASCII16/ASCII8/SCC/Konami
; en el nombre; SCC se comprueba ANTES que Konami, por eso basta [SCC])
fh2_tag_a16:	.db " [ASCII16].rom",0
fh2_tag_a8:	.db " [ASCII8].rom",0
fh2_tag_scc:	.db " [SCC].rom",0
fh2_tag_kon:	.db " [Konami].rom",0
fh2_n_fhunt:	.db "FHUNT      "
fh2_n_dot:	.db ".          "
fh2_n_ddot:	.db "..         "
fh2_req_dl:	.db "&download=",0
fh2_m_prep:	.db "FH: preparando descarga...",0
fh2_m_down:	.db "FH: bajando ",0
fh2_e_fat32:	.db "FH: la SD es FAT32 (v1 solo FAT16). Tecla",0
fh2_e_dl:	.db "FH: error/timeout de descarga. Tecla",0
fh2_e_api:	.db "FH: respuesta inesperada de la API. Tecla",0
fh2_e_sd:	.db "FH: error escribiendo en la SD. Tecla",0
; Cada aborto con su codigo: un "error en la SD" generico no dice DONDE, y
; ese texto salia en 5 sitios distintos. Con el pack v3.0 la descarga fallaba
; siempre y no habia forma de saber cual era.
fh2_e_e0:	.db "FH: E0 fallo escribiendo (flush). Tecla",0
fh2_e_e1:	.db "FH: E1 no puedo LEER la raiz. Tecla",0
fh2_e_e2:	.db "FH: E2 fallo marcando la FAT. Tecla",0
fh2_e_e3:	.db "FH: E3 fallo limpiando FHUNT. Tecla",0
fh2_e_e4:	.db "FH: E4 fallo en . y .. de FHUNT. Tecla",0
fh2_e_full:	.db "FH: sin espacio libre en la SD. Tecla",0
fh2_e_dir:	.db "FH: error con la carpeta FHUNT. Tecla",0


; ############## Variables

	var_mapper: ds 1
IFDEF ENABLE_MEGARAM
	var_megram: ds 1
ENDIF
IFDEF ENABLE_SDCARD
	var_sdcard: ds 1
ENDIF
	var_ghtscc: ds 1
	var_scanln: ds 1
	var_mapslt: ds 1
	var_stereo: ds 1
	var_sprlim: ds 1
	var_btturb: ds 1
; var_aspct ELIMINADO (Pantalla 16:9 muerta en el 60K)

	; File-Hunter fase 0 (test UNAPI)
	FH_SAVE_SP:    ds 2
	FH_SAVE_HIMEM: ds 2
	FH_SAVE_HTIMI: ds 5
	FH_UNAPI_SLT:  ds 1
	FH_UNAPI_ADR:  ds 2
	FH_TRIES:      ds 1

	; File-Hunter fase 1 (buscar/listar)
	FH_MODE:    ds 1				; 1 = navegador mostrando resultados FH
	FH_STATE:   ds 1				; FSM RX: 0 hdr / 1 rec / 2 str / 8 abs / 9 done
	FH_CRLF:    ds 1
	FH_HPOS:    ds 1
	FH_ACC:     ds 7
	FH_ACCN:    ds 1
	FH_NREC:    ds 1
	FH_SIDX:    ds 1
	FH_NPOS:    ds 1
	FH_FULL:    ds 1
	FH_CONN:    ds 1
	FH_QUERY:   ds 21
	FH_TCPP:    ds 13
	FH_REQLEN:  ds 2
	FH_WPTR:    ds 2
	FH_RPTR:    ds 2
	FH_RETTMP:  ds 2
	FH_DOTC:    ds 1
	FH_RETRIED: ds 1
	FH_CURTYPE: ds 1				; tipo de la consulta actual: 1=rom 2=dsk (tag +0)
	FH_BASEIDX: ds 1				; entradas ya en ENT_ARRAY (append rom+dsk)

	; File-Hunter fase 2 (descarga a FHUNT + lanzar)
	; REUBICADA a #E900 (RAM libre entre los vars #E8xx y FH_METAB #EA00): el
	; bloque ds crecia tras el codigo (#BF85) y CRUZABA #C000, solapando los equ
	; fijos SD_LBA/SD_STATUS/PART_LBA/ROOT_LBA/LFN_BUF (FH_SECN caia sobre SD_LBA)
	; -> corrupcion del nombre/datos en descargas grandes (DSK). ⚠️ #EC00 NO vale:
	; es la zona ALTA (~#EC00..#F362) que usa el driver ESP durante la red (por eso
	; FH_METAB #EA00 y FH_LNBUF #EB2C SI funcionan: estan por DEBAJO). #E900 esta
	; bajo FH_METAB (zona probada-segura) y sobre ENT_ARRAY (#E6F0) y los #E8xx.
	; NOTA: no meter mas vars ds arriba sin re-verificar; tope duro < #EA00.
	org  #E900
	FH_ITEM:    ds 1
	FH_METAP:   ds 2
	FH_NAME83:  ds 11
	FH_NAMEDOT: ds 13
	FH_EXTP:    ds 2
	FH_DIRCLUS: ds 2
	FH_CURC:    ds 2
	FH_PREV:    ds 2
	FH_CLUS0:   ds 2
	FH_SECN:    ds 1
	FH_FILL:    ds 2
	FH_FATVAL:  ds 2
	FH2_SEC:    ds 1
	FH2_OFF:    ds 2
	FH2_LEFT:   ds 1
	FH_WLEFT:   ds 4
	FH_FSIZE:   ds 4
	FH_FSIZ2:   ds 4
	FH_T10:     ds 4
	FH_DOTK:    ds 2
	FH_DLBA:    ds 4
	FH_DSECS:   ds 1
	FH_NPTR:    ds 2
	FH_DE_ATTR: ds 1
	FH_DE_CLUS: ds 2
	FH_DE_SIZ:  ds 4
	FH_RXN:     ds 2
	FH_RXP:     ds 2

	; File-Hunter fase 2 - LFN (nombre largo)
	FH_ENT32:   ds 32
	FH_CKSUM:   ds 1
	FH_FNPTR:   ds 2
	FH_FNLEN:   ds 2
	FH_NLFN:    ds 1
	FH_DIDX:    ds 2
	FH_PUTIDX:  ds 2
	FH_PUTSLOT: ds 1
	FH_SFNBASE: ds 6
	FH_SFNBLEN: ds 1
	FH_SFNN:    ds 1
	FH_MASK40:  ds 1
	FH_CGI:     ds 2
	FH_OLDCLUS: ds 2
	FH_FREECUR: ds 2
	FH_LFNRUN:  ds 2
	FH_LAUNCHC: ds 2
	FH_DOOVR:   ds 1
IFDEF ENABLE_MEGARAM
	var_megslt: ds 1
ENDIF
IFDEF ENABLE_SDCARD
	var_sdcslt: ds 1
ENDIF

	var_currentStruct: ds 2

	; Main menu (MSXnano) state
	var_mainSel:  ds 1				; currently selected main-menu option (0..3)
	var_selColor: ds 1				; scratch: fill color for highlight bar


; ############## MSX VT-52 Character Codes

VT_BEEP    equ	#07		; A beep sound
VT_RETURN  equ	#0d		; 13,"M"	; Carriage return
VT_RIGHT   equ	#1c		; 27,"C"	; Cursor right
VT_LEFT    equ	#1d		; 27,"D"	; Cursor left
VT_UP      equ	#1e		; 27,"A"	; Cursor up
VT_DOWN    equ	#1f		; 27,"B"	; Cursor down
VT_SPACE   equ	#20		; Space
VT_CLRSCR  equ	#0c		; 27,"E"	; Clear screen:	Clears the screen and moves the cursor to home
VT_HOME    equ	#0b		; 27,"H"	; Cursor home:	Move cursor to the upper left corner.

