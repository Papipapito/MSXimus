# Reconciliación de la pasada de análisis + decisiones abiertas

Síntesis de los 5 docs code-grounded ([CLOCK_CONSTANTS](CLOCK_CONSTANTS.md), [MEMORY_CONTRACT](MEMORY_CONTRACT.md), [FILE_MANIFEST](FILE_MANIFEST.md), [BOARD_60K](BOARD_60K.md), [GW5A_IP](GW5A_IP.md)) con las contradicciones resueltas y las decisiones que quedan.

## 1. Correcciones duras al brief / a la auditoría (con fuente)

| # | Hallazgo | Impacto | Anclaje |
|---|---|---|---|
| A | **El reloj de entrada del Console 60K es 50 MHz (pin V22), NO 27 MHz.** | ⚠️ **Invalida el "mantener 108 exacto = gratis".** 50→108 exacto NO es trivial (ver §2). El árbol de reloj se rehace de verdad. | `.sdc` de C64Nano: `create_clock -name clk -period 20` (=50 MHz). BOARD_60K §2.4 |
| B | El puerto `memory_ctrl.clk_27m` **se alimenta con `clk_54m`** — el handshake CPU (`ram_req/ram_busy/ram_dout`) vive a **54 MHz, no 27**. | El wrapper DDR3/SDRAM y los sincronizadores se diseñan sobre 54 MHz. Mi prompt decía "@27" — era erróneo. | `memory.v:3` vs `top.v:1464`. MEMORY_CONTRACT §0 |
| C | `vram_addr` = **17 bits**; `vram_dout` = **16 bits**; `vram_din` = 8 bits. | El dpram de VRAM (si va a BRAM) es 128K×8 / 64K×16, no "16-bit vram" genérico. | `top.v:1476/1480`, `v9958_top.v:48`. MEMORY_CONTRACT (a) |
| D | `CLK_135` tiene VCO **540 MHz** (ODIV=4), no 864; y **540 < mínimo VCO del GW5A (~800)** → hay que **subir ODIV** al regenerar. | La PLL de HDMI no se copia: se recalcula el VCO o se pasa a SERDES nativo. | `clk_135.v:42-50`. GW5A_IP §3 (corrige AUDIT §5.A2) |
| E | **PLLA del GW5A NO está soportada por yosys/apicula** → el port **obliga al flujo propietario Gowin** (gw_sh/IDE), no al open-source. | Afecta a toda la estrategia de build del 60K. | apicula wiki. GW5A_IP §1 |
| F | El Console 60K **puede llevar un módulo Tang-SDRAM por PMOD**; el `.cst` de C64Nano **incluye el bloque SDRAM completo con pines**. | Existe una **vía alternativa al DDR3** (ver Decisión 1). | C64Nano console60k.cst. BOARD_60K §3 |
| G | `build.tcl` ya está podado (F1 aplicada); único muerto-en-disco real relevante = `G80A/T80_RegX.vhd`. | Menos limpieza de la que decía la auditoría §2.1. | FILE_MANIFEST §11/§15 |
| H | Botones e IRQ: el "IRQ=IO27" del brief es GPIO del BL616 (no pin FPGA) y de otra variante; en el 60K `spi_irqn`=**U15**. Botones s1/s2 → **AA13/AB13 en banco 1.5V** (cambia IOSTANDARD). | No propagar "IO27"; cuidado con el nivel 1.5V de los botones. | FPGA-Companion SPI.md, C64Nano .cst. BOARD_60K §1/§2.4 |

**27 pines confirmados con ALTA confianza** (del `.cst` real del Console 60K); **INCIERTOS sin inventar**: `ws2812` (1), UART ESP-01S (2), `led[2..5]` (4). Ver BOARD_60K §5.

## 2. Análisis del reloj base (hallazgo A) — el problema y las salidas

El core entero cuelga de **108 MHz** (y 54/27 por división entera). Con entrada de **50 MHz**, generar **108.000 MHz exactos** con PLL entera exige `FBDIV/IDIV = 108/50 = 54/25` → `IDIV` múltiplo de 25 → **PFD = 50/25 = 2 MHz**, por **debajo del mínimo PFD (~3 MHz)** que reportan las fuentes del GW5A. **Conclusión (condicionada a que el PFD mínimo sea 3 MHz): 108.000 exacto desde 50 MHz NO es alcanzable con PLL entera simple.** Salidas, por preferencia:

1. **Fuente de 27 MHz en la placa** (si existe un XO de 27, o se saca del BL616/HDMI/externo) → se conserva TODO idéntico (cero recálculo). *Pendiente de confirmar en el schematic — el C64Nano usa 50 MHz, pero puede haber otro reloj.*
2. **PLLA fraccional-N** (si el GW5A lo soporta) → 108 exacto desde 50. *INCIERTO si PLLA tiene modo fraccional.*
3. **Base cercana a 108 + re-derivar las constantes críticas** (turbo WSX 5.369318 exacto vía par ÷/swallow nuevo, y validar timing VDP/HDMI). Doloroso pero mecánico; la fórmula está en CLOCK_CONSTANTS §4.
4. **Dos PLL en cascada** desde 50.

→ **Es el open-item técnico nº1.** No bloquea el scaffolding de lo que no depende del reloj, pero define la IP de reloj. Lo resuelvo investigando el schematic + capacidades de PLLA; si sabes ya si el 60K expone un 27 MHz, es la respuesta más limpia.

## 3. Decisión de partición de memoria (la más importante del port)

Ver Decisión 1 abajo. Resumen técnico:
- **DDR3 onboard (512 MB, hard-IP)**: es el port "de verdad" y el que **desbloquea el roadmap** (SRAM-persist, sample-RAM de MSX-Audio/OPL4, framebuffer del frontend gráfico). Pero es **el bloque más caro**: reescribir `memory.v` + wrapper que preserve `ram_*`/`vram_*`, resolver latencia variable (rama `ENABLE_WAIT_ADAPTIVE` **obligatoria**), `init_calib_complete` que gatea el arranque, y el **requisito MG2** ("escritura VDP nunca se descarta") en el arbiter nuevo. Recomendación transversal: **VRAM en BRAM** del GW5A (256 KB caben) → disuelve el requisito MG2 y deja DDR3 solo para CPU/mapper/megaram.
- **SDRAM por PMOD (SDR, módulo externo)**: `memory.v` **porta casi tal cual** (misma interfaz SDR, mismos 108 MHz) → **camino rápido a un core arrancando** en el 60K. Pero **no usa la DDR3 onboard**, requiere comprar/enchufar el módulo, y el roadmap seguiría necesitando DDR3 después.

## 4. Decisiones abiertas

- **Decisión 1 — Memoria**: DDR3 onboard vs SDRAM-PMOD (bring-up rápido) vs mantener el scaffolding agnóstico. → *pregunta al usuario.*
- **Decisión 2 — Companion**: BL616 onboard (recomendado; el 60K lo soporta, sin secure-boot; borra `spi_ext`/mux → quita el TA1132) vs conservar el dock M0S externo. → *pregunta al usuario.*
- **Open técnico — Reloj base** (§2): resolver con schematic/PLLA. No es preferencia de usuario salvo que sepas si hay 27 MHz.
- **Open técnico — VRAM en BRAM** vs en DDR3: recomendado BRAM; se cierra al conocer el presupuesto BRAM y la latencia DDR3.
- **Pines INCIERTOS**: `ws2812`, UART ESP-01S (×2), `led[2..5]` (×4) — pendientes del schematic oficial; NO inventar.

## 5. Lo que SÍ es P0 y no depende de nada de lo anterior (arrancable ya)

1. **`clock_config.vh`** — cabecera con los localparams derivados de `CLK_108_HZ` (CLOCK_CONSTANTS §4). Centraliza las 15 constantes; el día que se fije la base, un solo cambio.
2. **Skeleton CST** — todos los pines ALTA (companion onboard, HDMI, SD, clk, botones, flash, 2 LEDs) con el checklist "verificar match>0 tras el 1er PnR". Los pines de memoria e INCIERTOS quedan marcados.
3. **Migrar IP PORTA-TAL-CUAL** sin fix pendiente (FILE_MANIFEST): jtopl (43), core VDP (20 vhd), G80A (7, sin `T80_RegX`), HDMI TMDS agnóstico, `crc16.v`, `lpf.vhd` OCM, `ws2812.v`, `fifo.vhd`, `ram.vhd`.
4. **Borrar** `G80A/T80_RegX.vhd` (muerto en disco) al copiar.
