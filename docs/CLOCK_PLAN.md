# Plan de reloj del 60K — OPEN-ITEM Nº1 RESUELTO

**Fuente autoritativa: los `.ipspec` del propio toolchain instalado** (`C:\Gowin\Gowin_V1.9.11.03_Education_x64\IDE\ipcore\`), no web secundaria.

## Resolución

El reloj de entrada del Console 60K es **50 MHz** (pin V22), no 27. Generar 108 exactos desde 50 con PLL **entera** no era posible (PFD <3 MHz). **PERO el PLL del GW5A (`PLL_ADV` / `Gowin_PLL`) tiene división FRACCIONAL** — parámetros `CLKOUT0_DIV_FRAC` y `CLKFBOUT_DIV_FRAC` en `plladv.ipspec` — con modelo "Expected Frequency + Tolerance". Por tanto:

> **Se genera ~108.000 MHz desde 50 MHz con feedback fraccional (dentro de ppm). NO hace falta un 27 MHz en la placa, NI re-derivar ninguna constante.** `clock_config.vh` se queda con `CLK_108_HZ = 108_000_000` y las 15 constantes (turbo WSX 5.369318, prescaler WiFi 859372, LFSR RTC…) permanecen idénticas. La desviación en ppm es muy inferior a la tolerancia del cristal del MSX real (±50 ppm) → inaudible/irrelevante para compatibilidad.

**Open-item nº1: CERRADO.** (Con el matiz de validar en el generador que la tolerancia sale ~0; la resolución fraccional del GW5A es fina, no debería dar problema.)

## Toolchain confirmado (local, 1.9.11.03 Education)

| Pilar | Soporta GW5AT-60B | Fuente |
|---|---|---|
| Device GW5AT-60 PBGA484 | ✅ `PBGA484A.json` | `IDE/data/device/GW5AT-60B/` |
| PLL fraccional (`PLL_ADV`/`Gowin_PLL`) | ✅ `GW5AT-60B-*` | `IDE/ipcore/PLL_ADV/plladv.ipspec` |
| DDR3 Memory Interface (v5.9) | ✅ `GW5AT-60B-*` | `IDE/ipcore/DDR3/ddr3.ipspec` |

## Arquitectura de reloj propuesta (2 PLL, como hoy)

Todo se ancla a la MISMA entrada de 50 MHz → los dos PLL quedan relacionados en fase a través del reloj de entrada (igual que hoy los dos rPLL cuelgan del 27).

### PLL #1 — árbol del core (sustituye `CLK_108P` + los dos CLKDIV)
Una sola instancia `Gowin_PLL` con **3 salidas** desde el mismo VCO (elimina los `Gowin_CLKDIV`/`CLKDIV2`, uno de los cuales estaba mal generado para GW1NR-9):

| Salida | Freq | Divisor de VCO | Uso |
|---|---|---|---|
| CLKOUT0 | **108 MHz** (`clk_108m`) | 864/8 | secuenciador, base timing, turbo |
| CLKOUT1 | **54 MHz** (`clk_54m`) | 864/16 | CPU Z80, bus, wait FSM, handshake memoria |
| CLKOUT2 | **27 MHz** (`clk_27m`) | 864/32 | dominio lento (I/O, RTC, kanji), pixel VDP |

- **VCO = 864 MHz** (dentro del rango GW5A, ≥800). Feedback fraccional 864/50 = **17.28** (IDIV=1 → PFD=50 MHz, sin el problema de la PLL entera). Divisores de salida enteros 8/16/32.
- **Fase estática** (`CLKOUT*_PHASE_STATIC=true`) → adiós al `DYN_DA_EN` fantasma del diseño viejo.
- **`LOCK_EN=true`** → la señal LOCK entra en la cadena de reset (equivalente a `clock_locked`, top.v:102).
- **Ventaja clave**: 108/54/27 salen del MISMO VCO → **alineados en fase por construcción** → resuelve los cruces 27↔54 sin sincronizador (GW5A_IP §4.4) sin añadir 2FF.

### PLL #2 — HDMI TMDS (sustituye `CLK_135`)
`Gowin_PLL` 50 → **135 MHz** (TMDS ×5 del pixel 27). VCO recalculado a rango GW5A (p.ej. 135×8 = **1080 MHz**, NO heredar el ODIV viejo que daba 540 < 800). Fase estática.
- Detalle P2 (port HDMI): decidir si el pixel 27 del path HDMI se toma de PLL#1/CLKOUT2 o se regenera en PLL#2 junto al 135 para garantizar alineación pixel↔TMDS del serializer. Alternativa: SERDES/OSER10 nativo del GW5A (GW5A_IP §3, vía B).

## Ajustes del IP Core Generator (PLL #1, General Mode)

Anclado a los `tclcommand` de `plladv.ipspec`:

```
General_Mode      = true
CLKIN_FREQ        = 50            # MHz (pin V22)
CLKIN_DIV         = 1            # IDIV=1 -> PFD=50 MHz (OK)
CLKFB_INTERNAL    = true
LOCK_EN           = true
CLKOUT0_FREQ      = 108 ; CLKOUT0_TOLERANCE = 0.0 ; CLKOUT0_PHASE_STATIC = true
CLKOUT1_EN=true ; CLKOUT1_FREQ = 54  ; CLKOUT1_TOLERANCE = 0.0 ; CLKOUT1_PHASE_STATIC = true
CLKOUT2_EN=true ; CLKOUT2_FREQ = 27  ; CLKOUT2_TOLERANCE = 0.0 ; CLKOUT2_PHASE_STATIC = true
# El generador fija CLKFBOUT_DIV_FRAC / CLKOUT*_DIV_FRAC para clavar 108/54/27 desde 50.
```
Módulo generado: `Gowin_PLL` (target `gowin_pll`). Al integrarlo, conservar los nombres de puerto del wrapper actual (`clkout`, `lock`) para minimizar el diff en top.v.

## Impacto en `memory.v`/DDR3 (nota para el wrapper, frente B)

La DDR3 IP (`ddr3.ipspec`) trae su propio reloj: **`Memory_Clock`** (default 200 MHz = DDR3-400) y **`CLK_Ratio`** (1:2 o 1:4) → reloj de usuario = memory_clk / ratio. Objetivo de diseño del wrapper: **hacer que el reloj de usuario de la DDR3 = 54 MHz** (el dominio del handshake `ram_*`/`vram_*`) para NO crear un dominio nuevo y evitar CDC. Ej.: `Memory_Clock=216`, `CLK_Ratio=1:4` → user = 54 MHz (DDR3-432, holgado). A cerrar en el diseño del wrapper DDR3 (docs/MEMORY_CONTRACT.md).

## Cómo generar la IP en el IDE (paso a paso)

> El generador headless `GowinModGen.exe` **no arranca fuera del entorno de proyecto** del IDE (falla con "MG2000: Failed to read MODFILE" y no expone su sintaxis). Se genera desde el IDE. Deja `.mod`+`.ipc`+`.v` → a partir de ahí se puede scriptar la regeneración.

1. **Gowin IDE** → `File ▸ New ▸ FPGA Design Project`. Elegir el device:
   - Series **GW5AT** · Device **GW5AT-60B** · Package **PBGA484A** · Part Number **`GW5AT-LV60PG484AC1/I0`**.
   - Guardar el proyecto en `MSX_up/fpga/` (p.ej. `msx_console60k`).
2. `Tools ▸ IP Core Generator` → `Hard Module ▸ CLOCK ▸ PLL` (= PLL_ADV / `Gowin_PLL`).
3. Ajustes (General Mode):
   - **Clock Frequency (CLKIN) = 50 MHz**.
   - **CLKOUT0**: Expected Frequency **108**, Tolerance **0**, Phase = Static, valor 0.
   - Enable **CLKOUT1**: **54**, Tol 0, Static 0.
   - Enable **CLKOUT2**: **27**, Tol 0, Static 0.
   - **Enable Lock** = ON.
   - Verificar que la ventana muestre las 3 salidas a 108/54/27 con error ~0 (usa fraccional automáticamente).
4. Module Name **`Gowin_PLL`**, guardar en `MSX_up/fpga/ip/gowin_pll/`. Generar.
5. Commitear los `gowin_pll.{v,ipc,mod}` resultantes (o avísame y lo integro yo).

*(Repetir para PLL #2: CLKIN 50 → CLKOUT0 = 135, Static, para el TMDS.)*

## ✅ Resultado generado (PLL #1)

Generada en el IDE → proyecto `fpga/msx_console60k/`, IP en `src/gowin_pll/`. El IDE eligió:
- **VCO = 1350 MHz** (IDIV=1 → PFD 50 MHz; feedback ×27 = 50×27). Dentro de rango GW5A (el IDE lo validó → techo VCO ≥1350).
- Salidas por divisor de VCO: **108 = 1350/12.5** (fraccional, `Clkout0VCOFrac=4` = 0.5), **54 = 1350/25**, **27 = 1350/50** → **108/54/27 EXACTOS** (cero error), fase estática, Lock ON.

**Módulo `Gowin_PLL`** (puertos): `clkin`, `clkout0`=108, `clkout1`=54, `clkout2`=27, `lock`, **`mdclk`** (in).
- ⚠️ **Integración top.v (P2)**: el wrapper trae un `PLL_INIT` (secuencia de arranque por mDRP, propia del GW5A) → hay que **alimentar `mdclk` con el reloj de entrada de 50 MHz** (`CLK_PERIOD=20`, `MULTI_FAC=27`). El rPLL viejo no tenía esto. `lock` sale ya tras el init → va a la cadena de reset (equivale a `clock_locked`).
- Ficheros: `gowin_pll.v` (wrapper) + `gowin_pll_mod.v` (primitiva PLLA) + `pll_init.v`. Los `*_tmp.v` son basura del generador (gitignored).

## Siguiente
1. ✅ PLL #1 generada.
2. **Wrapper DDR3 (frente B)**: interfaz `ram_*`/`vram_*` a 54 MHz + user clock 54 + requisito MG2 + waits adaptativos. ← siguiente
3. Pendiente: PLL #2 (135 TMDS) cuando toque el port de HDMI.
