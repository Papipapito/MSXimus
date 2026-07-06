# BOARD_60K — Pinout GW5AT-60 (Tang Console 60K) y skeleton .cst para el port MSXnano

**Objetivo**: mapear el pinout del **GW5AT-60** en la **Tang Console 60K** (SOM Tang Mega 60K)
para portar el core MSXnano desde el Tang Nano 20K (GW2AR-18C). Este documento cubre la parte
**A3 (Constraints)** y parte de **A4 (Companion BL616)** de la guía de port
`fpga/AUDIT_PRE_PORT_60K.md` (secciones 5.A3 y 5.A4).

**REGLA de este documento**: todo pin va anclado a una fuente real (URL + fichero). Lo no
confirmado va marcado **INCIERTO** y no lleva número inventado. Los pines FPGA de la columna
"pin GW5AT-60" NO son suposiciones: salen del `.cst` oficial de un core que corre HOY en la
Tang Console 60K.

---

## 0. Contexto y hallazgo principal

El MSXnano vive en el **mismo ecosistema** que el core de referencia elegido: FPGA-Companion /
BL616 de Harbaum + MiSTle-Dev (el firmware del companion del MSXnano es "the same version as for
the Tang Nano 20K", ver `AUDIT_PRE_PORT_60K.md:99-101` y el propio README de C64Nano). Por eso la
fuente-de-verdad más fiable para el pinout es el `.cst` del **C64Nano** para el Tang Console 60K,
no un schematic PDF suelto: es un `.cst` que sintetiza y arranca en la placa real con la misma
topología BL616-onboard que necesitamos.

- **Fuente primaria (ALTA confianza)** — pinout FPGA verbatim de un core funcionando:
  `MiSTle-Dev/C64Nano` → `src/tang/console60k/c64nano.cst` y `.../c64nano.sdc`
  https://github.com/MiSTle-Dev/C64Nano/blob/main/src/tang/console60k/c64nano.cst
  https://github.com/MiSTle-Dev/C64Nano/blob/main/src/tang/console60k/c64nano.sdc
- **Fuente del mapeo BL616↔FPGA (ALTA)** — tabla JTAG-repurposed:
  `MiSTle-Dev/FPGA-Companion` → `SPI.md`
  https://github.com/MiSTle-Dev/FPGA-Companion/blob/main/SPI.md
- **Fuente de placa / device part (MEDIA)** — Sipeed Wiki + CNX:
  https://wiki.sipeed.com/hardware/en/tang/tang-console/mega-console.html
  https://www.cnx-software.com/2025/05/27/sipeed-tang-console-a-gowin-gw5ast-gw5at-board-with-60k-or-138k-lut-for-fpga-development-and-retro-gaming/
- **Referencia cruzada de pinout (MEDIA)** — `nand2mario/snestang` `src/boards/mega60k.cst`
  y `console.cst` (mismos pines HDMI G15/G16, J14/H14, J15/H15, K17/J17 → doble-confirmación).
  https://github.com/nand2mario/snestang/tree/main/src/boards

**Device part**: `GW5AT-LV60PG484AC1/I0` (paquete PBGA484). Confirmado por Sipeed Wiki
(GW5AT-LV60PG484AC1/I0) y por el `.gprj` del port (`tang_console_60k_c64.gprj`). Confianza ALTA.

---

## 1. La trampa del "IRQ = IO27" — aclaración obligatoria

El dato de partida "BL616 por SPI sobre pines JTAG repurposed con **IRQ = IO27**" **NO es un pin
del FPGA**: es la numeración **GPIO del propio BL616** (lado micro), y además corresponde al build
del **TN20K onboard**, no al Console 60K. Verificado en `FPGA-Companion/SPI.md`:

| Señal | GPIO del **M0S Dock** → pin FPGA (TN20K) | GPIO **onboard TN20K** → pin FPGA (TN20K) |
|-------|------------------------------------------|-------------------------------------------|
| CSN   | GPIO12 → 56  | GPIO0 → 86  |
| SCK   | GPIO13 → 54  | GPIO1 → 13  |
| MOSI  | GPIO11 → 41  | GPIO3 → 76  |
| MISO  | GPIO10 ← 42  | GPIO2 ← 75  |
| IRQN  | GPIO14 ← 51  | **GPIO13 ← 69** |

O sea: en TN20K-onboard el IRQ sale del **GPIO13 del BL616 al pin 69 del FPGA**. El "27" que
circulaba es la etiqueta del GPIO del micro en OTRA variante, no un pin del GW5AT-60. **En el Tang
Console 60K el mapeo es DISTINTO** y hay que tomarlo del `.cst` del Console 60K (sección 2), donde
la conexión onboard usa los pines **JTAG re-propósito** (TMS/TCK/TDI/TDO) + la antigua UART TX.
→ Regla: **no copiar el "IO27" a ningún sitio del port**. Confianza ALTA (contradice el dato de
entrada, con fuente).

---

## 2. Tabla de pinout — Tang Console 60K (GW5AT-60)

Todos los pines de la columna "pin GW5AT-60" provienen VERBATIM de
`C64Nano/src/tang/console60k/c64nano.cst` salvo donde se indique. Los bancos de tensión
(`BANK_VCCIO`) son los declarados en ese mismo `.cst`.

### 2.1 Companion BL616 onboard (JTAG-repurposed) — el equivalente al `spi_*` del MSXnano

| Señal (net C64Nano) | pin GW5AT-60 | IOSTANDARD / banco | función (etiqueta en .cst) | procedencia | confianza |
|---|---|---|---|---|---|
| `spi_csn`   | **T13** | LVCMOS33 / VCCIO 3.3, PULL_UP | TMS · GPIO0 · _SS | C64Nano console60k.cst | ALTA |
| `spi_sclk`  | **V12** | LVCMOS33 / 3.3, PULL_NONE DRIVE=OFF | TCK · GPIO1 · SCLK (4K7 PD en SOM) | idem | ALTA |
| `spi_dat`   | **R13** | LVCMOS33 / 3.3, PULL_NONE DRIVE=OFF | TDI · GPIO3 · MOSI | idem | ALTA |
| `spi_dir`   | **U13** | LVCMOS33 / 3.3, PULL_NONE DRIVE=8 | TDO · GPIO2 · MISO (3K3 PD en board) | idem | ALTA |
| `spi_irqn`  | **U15** | LVCMOS33 / 3.3, PULL_NONE DRIVE=8 | antigua UART TX del BL616 | idem | ALTA |
| `bl616_jtagsel` | **V14** | LVCMOS33 / 3.3, PULL_UP | ex-UART-out del BL616, ahora entrada FPGA | idem | ALTA |
| `bl616_mon_tx`  | **R14** | LVCMOS33 / 3.3, DRIVE=8 | monitor/consola serie del BL616 | idem | MEDIA (opcional) |

Notas de diseño (de `AUDIT_PRE_PORT_60K.md:98-102`):
- El MSXnano de TN20K expone `spi_sclk/spi_csn/spi_dat/spi_dir/spi_irqn` (tang9k.cst:13-22). El
  **renombrado 1:1 a estos 5 pines onboard del Console 60K** es directo. Los nombres de net del
  MSXnano se conservan; solo cambian los `IO_LOC`.
- **`jtagseln` / `bl616_jtagsel`**: el Console 60K reconfigura los pines JTAG de programación en un
  interfaz SPI, y con ello **bloquea reprogramaciones posteriores por JTAG** (documentado por
  FPGA-Companion y nand2mario). Requiere el net-attribute especial `NET_LOC "jtagseln"
  V_JTAGSELN;` + `CLOCK_LOC "spi_io_clk" LOCAL_CLOCK;` que aparecen en la cabecera del `.cst`. Esto
  **NO existía en TN20K** → es nuevo en el port. Confianza ALTA.
- **Decisión pendiente (A4 del audit)**: en el Console 60K el M0S Dock externo deja de tener
  sentido como mitigación secure-boot (aquí el BL616 onboard SÍ arranca el partner). Si se decide
  quitar el dock, se borra `spi_ext`/mux (fpga_companion.v:47-59) y desaparece el TA1132 del SDC.
  El companion externo alternativo, si se quiere, va por **PMOD0** (sección 2.7), no por m0s[].

### 2.2 HDMI TMDS (onboard)

| Señal | pin GW5AT-60 (P,N) | IOSTANDARD | procedencia | confianza |
|---|---|---|---|---|
| `tmds_clk_p`  | **G15, G16** | LVCMOS33D DRIVE=8 PULL_NONE | C64Nano + snestang (doble) | ALTA |
| `tmds_d_p[0]` | **J14, H14** | LVCMOS33D DRIVE=8 | idem | ALTA |
| `tmds_d_p[1]` | **J15, H15** | LVCMOS33D DRIVE=8 | idem | ALTA |
| `tmds_d_p[2]` | **K17, J17** | LVCMOS33D DRIVE=8 | idem | ALTA |

Nota: doble-confirmados contra `snestang/src/boards/mega60k.cst` y `console.cst` (mismos pares).
El MSXnano hoy declara TMDS como `data_p[0..2]`/`clk_p` (tang9k.cst:53-61). Renombrado directo, PERO
el core TMDS del MSXnano (CLK_135 ×5 con `DYN_DA_EN`) hay que regenerarlo para GW5A o pasar al
serdes nativo (ver `AUDIT_PRE_PORT_60K.md:89` A2). Los PINES son ALTA; el IP TMDS no es cosa del .cst.

### 2.3 microSD (onboard, SDIO 4-bit)

| Señal | pin GW5AT-60 | IOSTANDARD | procedencia | confianza |
|---|---|---|---|---|
| `sd_clk`    | **V15** | LVCMOS33 PULL_UP DRIVE=8 | C64Nano console60k.cst | ALTA |
| `sd_cmd`    | **Y16** | LVCMOS33 PULL_UP DRIVE=8 | idem | ALTA |
| `sd_dat[0]` | **AA15** | LVCMOS33 PULL_UP DRIVE=8 | idem | ALTA |
| `sd_dat[1]` | **AB15** | LVCMOS33 PULL_UP DRIVE=8 | idem | ALTA |
| `sd_dat[2]` | **W14** | LVCMOS33 PULL_UP DRIVE=8 | idem | ALTA |
| `sd_dat[3]` | **W15** | LVCMOS33 PULL_UP DRIVE=8 | idem | ALTA |
| SD card-detect | **V13** (VCC 1.5V) | — | comentario en .cst ("TF_SDIO_DET V13") | MEDIA/INCIERTO |

El MSXnano usa 6 pines SD: `sd_sclk/sd_cmd/sd_dat0..3` (tang9k.cst:78-89) → mapeo 1:1
(ojo al renombrado `sd_dat[N]` vector vs `sd_datN` escalar; el RTL WonderTANG del MSXnano usa
escalares, decidir si se adaptan los nombres o el bus). El card-detect en TN20K no se usa; en el
60K está en V13 pero **es banco 1.5V** → si se cablea, requiere buffer/atención de nivel. INCIERTO
si el RTL actual lo necesita: hoy no.

### 2.4 Reloj de sistema y botones

| Señal | pin GW5AT-60 | IOSTANDARD / banco | nota | procedencia | confianza |
|---|---|---|---|---|---|
| `clk` (XO) | **V22** | LVCMOS33 PULL_NONE | **50 MHz** en Console 60K (no 27 MHz) | C64Nano .cst + .sdc (period 20ns) | ALTA |
| `key_reset_n` (s2) | **AA13** | LVCMOS15 PULL_UP / **1.5V** | botón reset activo-bajo | C64Nano .cst | ALTA |
| `key_user_n` (s1)  | **AB13** | LVCMOS15 PULL_UP / **1.5V** | botón user activo-bajo | idem | ALTA |
| (3er botón Y12 = NC) | Y12 | — | no conectado | comentario .cst | MEDIA |

**Impacto crítico de reloj (A2 del audit)**: el TN20K entra a **27 MHz** (`ex_clk_27m` pin 4,
tang9k.cst:1). El Console 60K entra a **50 MHz** en V22 (confirmado por el `.sdc`:
`create_clock -name clk -period 20`). → **Todo el árbol de PLL/CLKDIV se recalcula** (rPLL→PLLA,
VCO nuevo) y **todas las constantes absolutas** (÷30→3.6MHz, ÷20+swallow→5.369318MHz turbo WSX,
esp_boot 3s, autofire, prescaler 859372 bps del ESP, LFSR del RTC) parten ahora de 50 MHz, no 27.
Ver `AUDIT_PRE_PORT_60K.md:88-91`. El `.cst` solo fija el pin de entrada; el resto es RTL/IP.
Los botones s1/s2 del MSXnano (tang9k.cst:4-7, hoy en pines 88/87 a 3.3V) pasan a **AA13/AB13 en
banco 1.5V** → cambia el IOSTANDARD, cuidado con el `IO_TYPE`.

### 2.5 LEDs de estado

| Señal | pin GW5AT-60 | IOSTANDARD | nota | confianza |
|---|---|---|---|---|
| `leds_n[0]` | **G11** | LVCMOS33 DRIVE=4 | "fpga done" (activo bajo) | ALTA |
| `leds_n[1]` | **U12** | LVCMOS33 DRIVE=4 | "fpga ready" (activo bajo) | ALTA |
| `leds_n[2]` | **V13** | LVCMOS33 DRIVE=4 | "sys_act" (comentado en ref) | MEDIA |

El MSXnano declara **6 LEDs discretos** `led[0..5]` (tang9k.cst:37-48). El Console 60K de
referencia solo expone **2 LEDs onboard fiables** (G11/U12). → Decisión de port: reducir a 2 LEDs,
o llevar los otros 4 a pines de header/PMOD (INCIERTO cuáles; no hay pin confirmado → no invento).
Marcar 4 de los 6 LEDs como **INCIERTO / pendiente de asignar**.

### 2.6 WS2812B (tira de estado en carcasa) — INCIERTO

El MSXnano usa `ws2812_led` en un GPIO de header (pin 25 en TN20K, tang9k.cst:50). El `.cst` de
C64Nano para Console 60K **no expone ningún ws2812**. Un pin de header/PMOD libre serviría, pero
**no hay pin confirmado por una fuente** → **INCIERTO, sin número**. Candidato natural: una línea
libre de PMOD1 (`io[0..5]`, sección 2.7) o de los 2×20 headers. A confirmar con el schematic
oficial de Sipeed (aún no publicado con pinout FPGA a fecha de este doc). NO inventar el pin.

### 2.7 Companion externo alternativo (PMOD0) y GPIO PMOD1

Presente en el `.cst` de referencia por si el companion va **externo** en PMOD0 (mismo rol que el
M0S Dock del TN20K). Útil si se conserva la ruta dock:

| Señal | pin GW5AT-60 | rol | confianza |
|---|---|---|---|
| `pmod_companion_dout` | **V19** | MISO (IO10) | ALTA |
| `pmod_companion_din`  | **V18** | MOSI (IO11) | ALTA |
| `pmod_companion_ss`   | **G22** | CSn (IO12) | ALTA |
| `pmod_companion_clk`  | **G21** | SCK (IO13) | ALTA |
| `pmod_companion_intn` | **E18** | IRQn (IO14) | ALTA |
| `io[0..5]` (PMOD1, p.ej. joystick DB9) | W19,W20,F19,F20,E22,D22 | GPIO genérico open-drain | ALTA |

Estos 5 `pmod_companion_*` son el sitio natural para un ws2812 o LEDs extra si se sacrifica el
companion externo. Anclado a C64Nano console60k.cst.

### 2.8 Flash NOR (MSPI) — re-mapear direcciones

| Señal | pin GW5AT-60 | nota | confianza |
|---|---|---|---|
| `mspi_cs`  | **T19** | W25Q64 (128 Mbit) | ALTA |
| `mspi_clk` | **L12** | | ALTA |
| `mspi_di`  | **P22** | | ALTA |
| `mspi_do`  | **R22** | | ALTA |
| `mspi_wp`  | **P21** | | ALTA |
| `mspi_hold`| **R21** | | ALTA |

El MSXnano usa 4 pines flash `mspi_cs/sclk/miso/mosi` (tang9k.cst:68-75). El Console 60K expone
además wp/hold (QSPI). **Impacto (sección 5.B del audit)**: la flash del Console 60K es **W25Q64 =
64 Mbit / 8 MB** y la **comparte el BL616**. El bitstream GW5AT-60 es MAYOR que el del GW2AR-18 →
hay que **re-mapear el pack (0x200000) y la config (0x280000)** del MSXnano y aplicar antes los
fixes de `flash_rw.v` (#1 write_terminate + plausibles). Confianza de PINES ALTA; el layout de
direcciones es decisión de port, no del .cst.

### 2.9 UART / WiFi ESP-01S

| Señal | pin GW5AT-60 | nota | confianza |
|---|---|---|---|
| `uart_rx` (ejemplo C64Nano) | **M13** (TWI SCL) | UART por USB-C; C64Nano lo mueve | MEDIA |
| `bl616_mon_tx` | **R14** | monitor serie BL616 | MEDIA |
| WiFi ESP-01S UART (rx/tx del MSXnano) | **INCIERTO** | ver abajo | INCIERTO |

El MSXnano lleva su propio UART al **ESP-01S** para WiFi UNAPI (`uart_rx` pin 28 / `uart_tx` pin 27
en TN20K, tang9k.cst:93-96) a **859372 bps FIJOS** (firmware ducasp). El Console 60K **no tiene un
conector ESP-01S dedicado**: habría que sacar 2 pines libres consecutivos por header/PMOD para el
ESP-01S. **No hay par de pines confirmado por fuente** → **INCIERTO, sin número**. Candidatos:
2 líneas de PMOD1 (`io[4]`=E22, `io[5]`=D22) o `uart_ext_rx/tx` (B22/C22 en el ref). A DECIDIR con
el schematic y con dónde se enchufa físicamente el ESP-01S en el dock; NO inventar.

---

## 3. Skeleton candidato de .cst (NO usar tal cual — verificar cada match)

> **Este bloque es un SKELETON, no un fichero listo.** Los bloques ALTA salen del `.cst` real del
> Console 60K y son fiables. Los bloques **INCIERTO** llevan `<<<INCIERTO>>>` y **NO tienen pin**:
> hay que rellenarlos con el schematic oficial o midiendo en la placa. Además, el audit avisa
> (`AUDIT_PRE_PORT_60K.md:93-94`, A3) que en Gowin un `IO_LOC` sobre un net inexistente **falla en
> silencio**: tras el primer PnR, **verificar en el log que cada constraint casa >0 objetos**.
> Nombres de net = los del top del MSXnano (spi_sclk, sd_dat0…, led[…]); ajustar al RTL real.

```tcl
// ============================================================================
//  msxnano_console60k.cst  — SKELETON port TN20K(GW2AR-18) -> Console 60K(GW5AT-60)
//  Device: GW5AT-LV60PG484AC1/I0  (PBGA484)
//  Fuente de pines ALTA: MiSTle-Dev/C64Nano src/tang/console60k/c64nano.cst
//  ⚠ VERIFICAR tras el 1er PnR que NINGUNA constraint quede sin match (fallo silencioso Gowin)
// ============================================================================

// ---- JTAG-repurposed / SPI-IO clock (NUEVO en el 60K, no existía en TN20K) ----
CLOCK_LOC "spi_io_clk" LOCAL_CLOCK;
NET_LOC   "jtagseln" V_JTAGSELN;
IO_PORT   "jtagseln" PULL_MODE=DOWN IO_TYPE=LVCMOS33 BANK_VCCIO=3.3;
IO_LOC    "bl616_jtagsel" V14;
IO_PORT   "bl616_jtagsel" PULL_MODE=UP IO_TYPE=LVCMOS33 BANK_VCCIO=3.3;

// ---- Companion BL616 onboard (equivale a spi_* del MSXnano) ----
IO_LOC  "spi_csn"  T13;  IO_PORT "spi_csn"  PULL_MODE=UP   IO_TYPE=LVCMOS33 BANK_VCCIO=3.3;
IO_LOC  "spi_sclk" V12;  IO_PORT "spi_sclk" PULL_MODE=NONE DRIVE=OFF IO_TYPE=LVCMOS33 BANK_VCCIO=3.3;
IO_LOC  "spi_dat"  R13;  IO_PORT "spi_dat"  PULL_MODE=NONE DRIVE=OFF IO_TYPE=LVCMOS33 BANK_VCCIO=3.3;
IO_LOC  "spi_dir"  U13;  IO_PORT "spi_dir"  PULL_MODE=NONE DRIVE=8   IO_TYPE=LVCMOS33 BANK_VCCIO=3.3;
IO_LOC  "spi_irqn" U15;  IO_PORT "spi_irqn" PULL_MODE=NONE DRIVE=8   IO_TYPE=LVCMOS33 BANK_VCCIO=3.3;

// ---- Reloj de sistema: 50 MHz (¡NO 27!) -> recalcular TODO el árbol PLL/CLKDIV ----
IO_LOC  "clk" V22;
IO_PORT "clk" IO_TYPE=LVCMOS33 PULL_MODE=NONE DRIVE=OFF;

// ---- Botones (banco 1.5V, activo bajo) ----
IO_LOC  "key_reset_n" AA13; IO_PORT "key_reset_n" IO_TYPE=LVCMOS15 PULL_MODE=UP DRIVE=OFF BANK_VCCIO=1.5;
IO_LOC  "key_user_n"  AB13; IO_PORT "key_user_n"  IO_TYPE=LVCMOS15 PULL_MODE=UP DRIVE=OFF BANK_VCCIO=1.5;

// ---- LEDs onboard (solo 2 fiables; los 4 extra del MSXnano => INCIERTO) ----
IO_LOC  "led[0]" G11; IO_PORT "led[0]" IO_TYPE=LVCMOS33 DRIVE=4 PULL_MODE=NONE BANK_VCCIO=3.3;
IO_LOC  "led[1]" U12; IO_PORT "led[1]" IO_TYPE=LVCMOS33 DRIVE=4 PULL_MODE=NONE BANK_VCCIO=3.3;
// <<<INCIERTO>>> led[2..5]: no hay pin confirmado en el 60K. Asignar por header/PMOD con schematic.

// ---- HDMI TMDS (pares) ----
IO_LOC  "tmds_clk_p"  G15,G16; IO_PORT "tmds_clk_p"  PULL_MODE=NONE DRIVE=8 IO_TYPE=LVCMOS33D;
IO_LOC  "tmds_d_p[0]" J14,H14; IO_PORT "tmds_d_p[0]" PULL_MODE=NONE DRIVE=8 IO_TYPE=LVCMOS33D;
IO_LOC  "tmds_d_p[1]" J15,H15; IO_PORT "tmds_d_p[1]" PULL_MODE=NONE DRIVE=8 IO_TYPE=LVCMOS33D;
IO_LOC  "tmds_d_p[2]" K17,J17; IO_PORT "tmds_d_p[2]" PULL_MODE=NONE DRIVE=8 IO_TYPE=LVCMOS33D;

// ---- microSD (SDIO 4-bit) ----
IO_LOC  "sd_clk"    V15;  IO_PORT "sd_clk"    IO_TYPE=LVCMOS33 PULL_MODE=UP DRIVE=8 BANK_VCCIO=3.3;
IO_LOC  "sd_cmd"    Y16;  IO_PORT "sd_cmd"    IO_TYPE=LVCMOS33 PULL_MODE=UP DRIVE=8 BANK_VCCIO=3.3;
IO_LOC  "sd_dat0"   AA15; IO_PORT "sd_dat0"   IO_TYPE=LVCMOS33 PULL_MODE=UP DRIVE=8 BANK_VCCIO=3.3;
IO_LOC  "sd_dat1"   AB15; IO_PORT "sd_dat1"   IO_TYPE=LVCMOS33 PULL_MODE=UP DRIVE=8 BANK_VCCIO=3.3;
IO_LOC  "sd_dat2"   W14;  IO_PORT "sd_dat2"   IO_TYPE=LVCMOS33 PULL_MODE=UP DRIVE=8 BANK_VCCIO=3.3;
IO_LOC  "sd_dat3"   W15;  IO_PORT "sd_dat3"   IO_TYPE=LVCMOS33 PULL_MODE=UP DRIVE=8 BANK_VCCIO=3.3;
// (nota: renombrar sd_sclk->sd_clk y vector/escalar sd_dat según el RTL WonderTANG)

// ---- Flash NOR MSPI (W25Q64 8MB, compartida con BL616 -> re-mapear direcciones del pack) ----
IO_LOC  "mspi_cs"  T19; IO_PORT "mspi_cs"  PULL_MODE=NONE IO_TYPE=LVCMOS33;
IO_LOC  "mspi_clk" L12; IO_PORT "mspi_clk" PULL_MODE=NONE IO_TYPE=LVCMOS33;
IO_LOC  "mspi_di"  P22; IO_PORT "mspi_di"  PULL_MODE=NONE IO_TYPE=LVCMOS33; // MOSI
IO_LOC  "mspi_do"  R22; IO_PORT "mspi_do"  PULL_MODE=NONE IO_TYPE=LVCMOS33; // MISO
IO_LOC  "mspi_wp"  P21; IO_PORT "mspi_wp"  PULL_MODE=NONE IO_TYPE=LVCMOS33;
IO_LOC  "mspi_hold" R21; IO_PORT "mspi_hold" PULL_MODE=NONE IO_TYPE=LVCMOS33;

// ---- WS2812B tira de estado ----
// <<<INCIERTO>>> ws2812_led: sin pin confirmado en el 60K. Candidato: PMOD1 io[5]=D22 o header 2x20.

// ---- WiFi ESP-01S UART (859372 bps fijos, firmware ducasp) ----
// <<<INCIERTO>>> uart_rx / uart_tx del ESP-01S: sin par de pines confirmado.
//   Candidatos: PMOD1 io[4]=E22 / io[5]=D22, o uart_ext_rx=B22 / uart_ext_tx=C22. Decidir con HW.

// ---- Memoria principal: NO son pines de usuario en el path DDR3 ----
//   El Console 60K lleva DDR3 512MB como HARD-IP (sin pines de usuario en el .cst).
//   Alternativa SDR: la placa acepta Tang-SDRAM en PMOD; el .cst de C64Nano SÍ trae un bloque
//   SDRAM completo (IO_sdram_dq/addr/ba/dqm/clk/wen/ras/cas/cs) EN EL PMOD.
//   -> Decisión de A1 del audit (DDR3 hard-IP vs SDR-en-PMOD). NO se resuelve en este skeleton.
```

**Sobre la memoria (aclaración importante)**: el dato de entrada dice "DDR3 es hard-IP (SIN pines
de usuario)" — **correcto para el DDR3 onboard**: el controlador DDR3 del GW5AT es IP dura y no
aparece como `IO_LOC` en el `.cst`. PERO el `.cst` de C64Nano para Console 60K **sí incluye un
bloque SDRAM completo con pines** (`IO_sdram_dq[0..15]` E14/E13/…, `O_sdram_addr[0..12]`,
`O_sdram_ba`, `O_sdram_dqm`, `O_sdram_clk` B17, etc.): esos pines son para el **módulo Tang-SDRAM en
el PMOD** (misma vía SDR que el TN20K, ver `TANG_CONSOLE_60K.md`). Es la ruta que permitiría
**reutilizar `memory.v` casi tal cual** en vez de reescribir a DDR3. Los pines SDRAM completos
están en la fuente si se elige esa vía; se han omitido del skeleton por brevedad y porque la
decisión A1 (DDR3 vs SDR-PMOD) está abierta en el audit.

---

## 4. Contexto de relojes (SDC) para el port

Del `Z80_goauld.sdc` actual (TN20K): reloj base `clock_27m` sobre el net `clk_27m`, generados
`clock_54m` (×2), `clock_108m` (×4, sobre `O_sdram_clk`), `clock_108i`, y `clock_VideoDHClk`/`DLClk`
(÷2/÷4). Todo anclado a nombres GW2A (`clk_main/rpll_inst/CLKOUT`) y a la RED, no al puerto — origen
de fallos silenciosos al portar (`AUDIT_PRE_PORT_60K.md:94`, A3). En el Console 60K:

- El reloj de ENTRADA es **50 MHz en `clk` (V22)**, no 27 MHz (`.sdc` de C64Nano:
  `create_clock -name clk -period 20`). El `create_clock` base del SDC nuevo va sobre `[get_ports {clk}]`.
- El SDC de referencia declara `spi_clk` (period 50, sobre `[get_ports {spi_sclk}]`) y
  `spi_io_clk` (LOCAL_CLOCK) → el dominio SPI del BL616 **sí se puede constrainear** en el 60K.
  Esto resuelve el hueco TA1132 que el audit señala en `mcu_spi_new.v:43/117` (A3): con el pin SPI
  limpio, `create_clock` directo sobre `spi_sclk`.
- Todos los `create_generated_clock` y `set_false_path` anclados a nombres GW2A
  (`rpll_inst/CLKOUT`, `O_sdram_clk`) hay que **regenerarlos con los nombres de instancia del PLLA
  del GW5A**. El SDC entero es nuevo, no se copia.

---

## 5. Recuento y estado

**Pines CONFIRMADOS (ALTA, del `.cst` real del Console 60K)** — 27 nets con pin fiable:
- Companion BL616: spi_csn T13, spi_sclk V12, spi_dat R13, spi_dir U13, spi_irqn U15,
  bl616_jtagsel V14 (6)
- HDMI TMDS: clk + d[0..2] = 4 pares (4)
- microSD: clk, cmd, dat0..3 (6)
- clk V22 + reset AA13 + user AB13 (3)
- LEDs onboard led[0] G11, led[1] U12 (2)
- Flash MSPI: cs, clk, di, do, wp, hold (6)

**INCIERTOS (sin pin, marcados en el doc, NO inventados)** — 3 grupos:
- `ws2812_led` (1 pin) — no expuesto en el ref
- ESP-01S UART rx/tx (2 pines) — sin conector dedicado en el 60K
- `led[2..5]` (4 pines) — el MSXnano lleva 6, el ref solo confirma 2 onboard

**MEDIA / opcional**: bl616_mon_tx R14, SD card-detect V13 (banco 1.5V), 3er botón Y12 NC,
uart por USB-C M13, LED sys_act V13.

**Contradicción resuelta con fuente**: el "IRQ = IO27" del brief es GPIO del BL616 (no pin FPGA) y
de la variante TN20K; en el Console 60K el `spi_irqn` va al pin FPGA **U15**. No propagar "IO27".

---

## 6. Fuentes

- C64Nano (pinout Console 60K, ALTA): https://github.com/MiSTle-Dev/C64Nano/blob/main/src/tang/console60k/c64nano.cst · https://github.com/MiSTle-Dev/C64Nano/blob/main/src/tang/console60k/c64nano.sdc · https://github.com/MiSTle-Dev/C64Nano/blob/main/TANG_CONSOLE_60K.md
- FPGA-Companion SPI.md (mapeo BL616↔FPGA, aclaración IRQ): https://github.com/MiSTle-Dev/FPGA-Companion/blob/main/SPI.md
- snestang (doble-confirmación HDMI/SDRAM): https://github.com/nand2mario/snestang/tree/main/src/boards
- Sipeed Wiki Tang Console / Mega 60K (device part, interfaces): https://wiki.sipeed.com/hardware/en/tang/tang-console/mega-console.html · https://wiki.sipeed.com/hardware/en/tang/tang-mega-60k/mega-60k.html
- CNX-Software (GW5AT-LV60P484A, specs): https://www.cnx-software.com/2025/05/27/sipeed-tang-console-a-gowin-gw5ast-gw5at-board-with-60k-or-138k-lut-for-fpga-development-and-retro-gaming/
- nand2mario BL616 dual-mode / TangCore (contexto companion): https://nand2mario.github.io/posts/2025/mcu_for_better_fpga_gaming/

_Referencias internas: `fpga/AUDIT_PRE_PORT_60K.md` (secciones 5.A2 relojes, 5.A3 constraints,
5.A4 companion, 5.B flash), `fpga/tang9k.cst`, `fpga/Z80_goauld.sdc`._
