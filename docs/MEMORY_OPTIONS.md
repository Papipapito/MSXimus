# Memoria del port: SDR SDRAM vs DDR3 — comparativa y decisión

El usuario tiene **las dos** memorias disponibles en la Tang Console 60K:
- **Módulo Tang SDRAM v1.3**: 2× Winbond **W9825G6KH-5** (SDR, 256 Mbit=32 MB, 16M×16, 3.3 V) → 64 MB físicos, pero el ecosistema (C64Nano) cablea **1 chip = 16 bits = 32 MB**.
- **DDR3 onboard** del SOM Tang Mega 60K: **SK Hynix H5TQ4G63EFR** (4 Gbit=**512 MB**, 256M×16, 1.5 V; el bus corre a ~1100 MT/s según Sipeed).

## Tabla comparativa

| Criterio | **SDR SDRAM** (W9825 módulo) | **DDR3** (Hynix onboard) |
|---|---|---|
| Capacidad | 32 MB (16b) / 64 MB (32b, 2 chips a mano) | **512 MB** |
| Ancho de banda | ~0.4 GB/s (200MHz×16) | ~1.2 GB/s (a 594) / hasta 3.2 (no explotado) |
| **Reuso de `memory.v`** | **~85-90%** (FSM 8-fases, comandos SDR, arbiter, MG2, byte-latch intactos) | **0%** (reescritura desde cero) |
| **Latencia** | **Fija/determinista** (encaja con el contrato actual) | Variable (refresh, colas) → CDC + waits adaptativos |
| **Riesgo del requisito MG2** | Ninguno (la FSM ya lo cumple, memory.v:204-213) | Alto (arbiter nuevo debe garantizarlo por escrito) |
| **Probado en ESTA placa** | ✅ Sí (C64Nano/VIC20Nano usan este módulo por el slot SDRAM1) | ⚠️ Solo **framebuffer** (nand2mario, 594 MT/s, **refresh OFF**). Como **RAM general de baja latencia = NO validado** aquí (nand2mario reportó dificultades; general solo validado en Primer 20K) |
| **Esfuerzo** | **~25-35% del DDR3** | 100% (el bloque más caro del port) |
| **Pines** | ocupa el slot SDRAM1 (40-pin), GPIO general | onboard (hard-IP, sin pines de usuario) |
| Voltaje | 3.3 V | 1.5 V (hard-IP se encarga) |

## Qué cuesta exactamente la vía SDR (reuso de `memory.v`)

Del análisis de `memory.v` (reuse agent):
1. **La FSM porta casi tal cual** (~85-90%): secuenciador de 8 fases `ff_sdr_seq`, comandos SDR crudos, arbitraje CPU/VDP por `video_dhclk/dlclk`, fix MG2 (memory.v:204-213), latch de lectura por byte (420-443). El contrato `ram_req/ram_busy/ram_dout` no cambia.
2. **Cambio real = bus 32→16 bits**: `memory.v` asume 4 bytes/palabra (`IO_sdram_dq[31:0]`, `dqm[3:0]`); el W9825 es x16 (2 bytes, 2 DQM). Toca 4 bloques `always`: replicación ×4→×2 (memory.v:377/380), selección de byte (`sdram_addr[1]` deja de aplicar), extracción de lectura (423-430), DQM. **Mecánico pero invasivo.**
   - *Alternativa x32*: cablear los **2 chips en paralelo** (=32 bits, 64 MB) → reusa la lógica de 32 bits **casi sin tocar**, a costa de doblar GPIO. **INCIERTO**: hay que abrir el schematic del módulo v1.3 + Console 60K para ver si el 2º bus de 16 bits sale al 40-pin (ningún `.cst` de referencia lo hace).
3. **Geometría**: ampliar fila 11→**13 bits** (W9825 = 8192 rows×512 cols×4 banks); CL2 encaja a ≤133 MHz (el core va a 108). Ajuste acotado.
4. **Magic-ports embebidos → GPIO general** (trabajo de físico, no RTL): IOB reales, tri-state del DQ (memory.v ya pone Hi-Z), y sobre todo **CST+SDC nuevos** con el *clock forwarding* de `O_sdram_clk` por un pin de header con skew controlado (el punto delicado a 108 MHz — posible bajar frecuencia). Es justo el "fallo silencioso de constraints" de la auditoría §5.A3. Proven por C64Nano/NEStang que corren SDR externo por PMOD.

## Recomendación

**Core (mapper/megaram/VRAM/ROM) → SDR SDRAM (W9825), 16 bits/32 MB.** Y **reservar la DDR3 para el framebuffer del frontend gráfico** más adelante — que es precisamente su uso PROBADO en esta placa (streaming, refresh-off), no RAM general.

Razones:
- **Menor esfuerzo y menor riesgo**: ~30% del trabajo, y evita los dos puntos más caros/arriesgados del port (arbiter MG2 + waits adaptativos) porque conserva la latencia determinista.
- **La DDR3 como RAM general del MSX no está validada en el 60K** (solo framebuffer). Meter la CPU/mapper ahí es apostar por el camino que nand2mario no logró estabilizar.
- **32 MB sobran** para el core (~8 MB) y para SRAM-persistente. La DDR3 (512 MB) aporta cuando llegue el framebuffer/sample-RAM grandes — y ahí se usa como lo que funciona: framebuffer.
- El módulo ya está comprado y puesto.

**Sub-decisión 16 vs 32 bits**: empezar en **16 bits (32 MB)** = pinout C64Nano probado, arranque seguro. Subir a x32/64 MB después si interesa (requiere confirmar el schematic del módulo).

## Reparto final propuesto
- **SDR SDRAM (32 MB)**: RAM del core (mapper 4MB + megaram 2MB + VRAM + ROM/BIOS/kanji/disk). `memory.v` reusado (frente 32→16b + CST/SDC GPIO).
- **DDR3 (512 MB)**: fase 2, framebuffer del [frontend gráfico](GRAPHICAL... roadmap) — IP DDR3 estilo `nand2mario/ddr3_framebuffer_gowin` (297 MHz, refresh off). El diseño [DDR3_WRAPPER.md](DDR3_WRAPPER.md) queda como referencia para ese día.
- **VRAM**: sigue pudiendo ir en **BRAM** (265 KB disponibles) si interesa la latencia fija — opcional con SDR (la FSM ya sirve la VRAM), decidir en implementación.

Fuentes: Sipeed Wiki (Mega 60K, PMOD), nand2mario ddr3_framebuffer_gowin (README + pll_ddr3.mod), gbatang console60k.v, C64Nano console60k.cst/TANG_MEGA_60K.md, Winbond W9825G6KH datasheet, memory-distributor/LCSC (H5TQ4G63EFR).
