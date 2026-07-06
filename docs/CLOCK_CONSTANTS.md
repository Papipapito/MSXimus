# CLOCK_CONSTANTS — Constantes absolutas dependientes de la base de reloj (port MSXnano TN20K → Tang Console 60K)

Fuente: copia limpia de `dev` en `C:\Users\alber\proyectosAI\msx\_MSXnano_dev_ref`.
Guía previa: `fpga/AUDIT_PRE_PORT_60K.md` (sección 5.A2, línea 91, enumera la lista; aquí se ancla al código real con `file:line` y valores exactos).
Regla: todo anclado a código real. Lo no confirmable va marcado **INCIERTO** con motivo.

---

## 1. El árbol de relojes actual (de dónde salen 108 / 54 / 27 MHz)

Todo el core cuelga de UN oscilador externo de **27 MHz** (`ex_clk_27m`, top.v:18) y de UN PLL:

| IP | Fichero | Instancia en top.v | Parámetros (defparam) | Salida |
|---|---|---|---|---|
| `CLK_108P` | `fpga/src/gowin/clk_108p.v` | top.v:123 `clk_main` | `FCLKIN="27"`, `IDIV_SEL=0` (÷1), `FBDIV_SEL=3` (×4), `ODIV_SEL=8` | **108 MHz** = `clk_108m` (VCO = 108×8 = **864 MHz**) |
| `Gowin_CLKDIV` (÷4) | `fpga/src/gowin_clkdiv/gowin_clkdiv.v` | top.v:141 `div4` | `DIV_MODE="4"`, `hclkin=clk_108m` | **27 MHz** = `clk_27m` |
| `Gowin_CLKDIV2` (÷2) | `fpga/src/gowin_clkdiv2/gowin_clkdiv2.vhd` | top.v:185 `div2` | `DIV_MODE="2"`, `hclkin=clk_108m` (⚠️ IP generado para **GW1NR-9**, clk_108p.v:5-6 dice GW2AR-18) | **54 MHz** = `clk_54m` |
| `CLK_135` | `fpga/tn_vdp_v3_v9958/src/gowin/clk_135.v` | v9958_top.v:140, `clkin = clk` = `clk_27m` (top.v:1259) | `FCLKIN="27"`, `IDIV_SEL=0`, `FBDIV_SEL=4` (×5), `ODIV_SEL=4`, ⚠️ `DYN_DA_EN="true"` (fase dinámica fantasma) | **135 MHz** (TMDS ×5 del pixel 27 MHz para HDMI) |

Consecuencia: **108, 54 y 27 MHz están alineados en fase** (todos derivan del mismo `clk_108m` por CLKDIV enteros). Varios cruces 27↔54 sin sincronizador dependen de esa alineación (AUDIT 5.A2, línea 90). El pixel clock del VDP y el TMDS×5 salen del **mismo 27 MHz**, no de una base independiente.

**Objetivo del port**: en el GW5AT-60 hay que regenerar `CLK_108P` (rPLL→PLLA, verificar VCO 864 MHz alcanzable), `Gowin_CLKDIV`/`Gowin_CLKDIV2` y `CLK_135` para la familia GW5A. **Mientras `clk_108m` siga siendo 108.000 MHz exactos** (y por tanto 54 y 27 exactos), TODOS los divisores de fabric de abajo siguen dando la misma frecuencia y **no habría que recalcular nada**. La tabla siguiente da los valores por si se decide una base distinta (o por si el PLL del 60K no puede clavar 108.000).

> **Recomendación transversal**: mantener 108/54/27 exactos en el 60K es, con diferencia, el camino de menor riesgo (cero recálculo, cero re-derivación del LFSR RTC, cero cambio del prescaler WiFi). Solo si el 60K obliga a otra base se aplican las fórmulas de la columna "60K".

---

## 2. Tabla EXHAUSTIVA de constantes absolutas

Leyenda criticidad: **[C]** = crítica (rompe compatibilidad o exactitud si se recalcula mal), [·] = ordinaria (tolerante a error de recálculo).

| # | file:line | Símbolo / literal | Valor actual | Qué computa | Reloj del que depende | Fórmula | Valor / nota 60K |
|---|---|---|---|---|---|---|---|
| 1 | `fpga/top.v:225` | `div30_cnt == 5'd14` | 14 (medio periodo → periodo **30**) | Genera `clk_3m6_internal` = **3.6 MHz** (clock del bus MSX interno, `ex_bus_clk_3m6`) | `clk_108m` (108 MHz) | medio_periodo = CLK_108/(2·3.6M) − 1 = 108M/7.2M − 1 = **14** | Si CLK_108=108M exacto: **14** (sin cambio). Otra base: `round(CLK_108/(2·3_600_000)) − 1`. Reg `div30_cnt` es `[4:0]` (top.v, decl. cerca 220): si el medio-periodo sube de 31 hay que ensanchar el reg. |
| 2 | `fpga/top.v:899` | `div20_cnt >= 5'd9` | 9 (medio periodo → periodo **20**) | Genera `clk_5m4_internal` = **5.40 MHz** (base del turbo WSX antes del trago) | `clk_108m` (108 MHz) | medio_periodo = 108M/(2·5.4M) − 1 = **9** | Si CLK_108=108M: **9**. La cadencia 5.4 base debe ser 108/20 EXACTO para que el trago dé 5.369318. **[C]** (parte del turbo exacto) |
| 3 | `fpga/top.v:908-935` | `pana_per_cnt == 8'd175` (líneas 917, 924); ratio **175/176** | 175 | "Trago de periodo": de cada **176** periodos de 5.4 MHz enmascara 1 → 5.4M·(175/176) = **5 369 318 Hz** = turbo WSX EXACTO (= 315/88 · 1.5 MHz) | Derivado del ÷20 sobre `clk_108m` | 5_369_318 = CLK_108/20 · 175/176. La igualdad SOLO se cumple si CLK_108/20 = 5.400000 MHz exactos | **[C] CRÍTICA.** Si se conserva 108 MHz: **NO tocar** (175/176 sigue dando 5.369318 exacto). Si cambia la base, hay que rehacer el par (divisor + ratio) para clavar 5 369 318 Hz — resolver `p/q` tal que `(CLK_108/div)·(p/q) = 5369318`. Validado en HW a 5.369318 MHz (memoria WSX turbo). Reg `pana_per_cnt` es `[7:0]`: q>256 obliga a ensanchar. |
| 4 | `fpga/top.v:836` | `esp_boot_cnt == 27'd81000000` | 81 000 000 | Retención de reset ~**3.0 s** en power-on para que arranque el ESP-01S (WiFi) antes del INIT del driver | `clk_27m` (27 MHz) | ticks = 3.0 · CLK_27 = 3.0 · 27M = **81 000 000** | `round(3.0 · CLK_27)`. Con 27M: 81e6. No crítico (margen de segundos). Reg `[26:0]`: 81e6 < 2^27 (134M) OK; si CLK_27 sube mucho revisar ancho. `ifdef ENABLE_WIFI`. |
| 5 | `fpga/top.v:516` | `af_cnt >= 22'd2700000` | 2 700 000 | Semiperiodo autofire = **50 ms** (onda cuadrada ~10 Hz para botones turbo 3/4 del pad) | `clk_54m` (54 MHz) | ticks = 0.050 · CLK_54 = 0.050 · 54M = **2 700 000** | `round(0.050 · CLK_54)`. Con 54M: 2.7e6. No crítico (debe durar ≥1 scan PSG, ~1 frame; margen amplio). Reg `[21:0]`: 2.7e6 < 2^22 (4.19M) OK. |
| 6 | `fpga/top.v:290` | `counter_reset <= 21'b1<<20` (`21'b100000000000000000000` = **1 048 576** = 2^20) | 1 048 576 | Duración de CADA paso de la secuencia de reset power-on (`rst_seq` de 3 pasos, top.v:299-320). ~**38.8 ms/paso**, ~116 ms total | `clk_27m` (27 MHz) | t_paso = 2^20 / CLK_27 = 1048576/27M ≈ **38.8 ms** | Con 27M: dejar 2^20 (los reset son márgenes generosos). Si se quiere t fija en ms: `2^ceil(log2(t·CLK_27))` o cambiar a comparación decimal. No crítico. Reg `[20:0]`. |
| 7 | `fpga/src/ocm/rtc.v:66` | `c_1sec_cnt0 = 22'h2D94A3` (=2 987 171 dec, **patrón terminal LFSR**) | 0x2D94A3 | Prescaler del **1 segundo** del RTC (RP-5C01). Es un **LFSR de 22 bits** (rtc.v:75-76,132,180-186): recorre **3 579 547 estados** (= 1 s) antes de igualar `c_1sec_cnt0`. **NO es una resta / no es nº de ticks lineal.** | El LFSR avanza con `clkena` = **`clk_enable_3m6_27`** (rtc.v:180; instancia top.v:1228-1230 `clk21m=clk_27m`, `clkena=clk_enable_3m6_27`). O sea: cuenta a **3.579545 MHz** (el tick del bus), NO a 27 MHz. | 1 s ⇒ **3 579 547 ticks** del enable de 3.58 MHz. El valor hex es el estado LFSR tras esos ticks (polinomio `~(bit21 ^ bit20)`, rtc.v:132). | **[C] CRÍTICA y sutil.** Como el enable sigue siendo el tick de ~3.58 MHz derivado del **bus MSX** (no de la base FPGA), **si `clk_enable_3m6_27` sigue siendo 3.579545 MHz el valor NO cambia** — mantener `0x2D94A3`. Solo se recalcula si cambia el nº de ticks/segundo del *enable*, y entonces **NO restando**: hay que regenerar con el generador LFSR de KdL (OCM-PLD) para el nuevo recuento. Comentario in-code alterno para 50 MHz÷6 (`0x1F53BB`) confirma que se regenera, no se resta. |
| 8 | `fpga/src/ocm/wifi_lite.vhd:205` | `uart_prescaler_i => to_unsigned(31, 14)` | 31 | Prescaler UART del ESP → **baudrate FIJO** del firmware WiFi de ducasp. 27M/31 ≈ 870 968 (doc: **859 372 bps**) | `clk_i` = **`clk_27m`** (27 MHz; instancia — ver §3) | prescaler = round(CLK_27 / 859372) = 27M/859372 ≈ **31** (ticks_per_bit) | **[C] CRÍTICA.** El baudrate lo fija el firmware del ESP (no negociable). `nuevo_prescaler = round(CLK_wifi / 859372)`. Con CLK_wifi=27M: **31** (sin cambio). Con otra base: recalcular para que CLK_wifi/prescaler quede lo más cerca posible de 859 372 (el reg es `(13 downto 0)`, 14 bits → máx 16383). Ver comentarios wifi_lite.vhd:194-198 para otros baudios. |
| 9 | `fpga/src/ocm/wifi_lite.vhd:243` | `qckbase_cnt >= 675000` | 675 000 | Timeout de **25 ms** (quick-base del protocolo del cartucho WiFi) | `clk_i` = `clk_27m` (27 MHz) | ticks = 0.025 · CLK_27 = 0.025·27M = **675 000** | `round(0.025 · CLK_wifi)`. Con 27M: 675000. No crítico (timeout con margen). |
| 10 | `fpga/src/psg_filter.v:28` | `clk_2m7_counter >= 10` | 10 (÷**11**) | `clk_enable_2m7` ≈ **2.45 MHz** (clkena del 2º LPF del filtro PSG/OPLL) | `clk_27m` (27 MHz) | f = CLK_27/(10+1) = 27M/11 ≈ **2.45 MHz** | `round(CLK_27/f_deseada) − 1`. Con 27M: 10. Filtro de audio, tolerante; ajustar solo si se busca la misma f de corte. |
| 11 | `fpga/src/psg_filter.v:32` | `clk_270k_counter >= 100` | 100 (÷**101**) | `clk_enable_270k` ≈ **267 kHz** (clkena de los LPF 3º/4º del filtro PSG/OPLL) | `clk_27m` (27 MHz) | f = CLK_27/(100+1) = 27M/101 ≈ **267 kHz** | `round(CLK_27/f) − 1`. Con 27M: 100. Reg `clk_270k_counter` es `[7:0]`; si CLK_27 sube y el divisor pasa de 255, ensanchar. Tolerante. |
| 12 | `fpga/top.v:2797` | `led_stretch #(.HOLD(1350000)) st_disk` | 1 350 000 | Estirado LED actividad **disco/SD** ≈ **50 ms** | `clk_27m` (27 MHz, `.clk(clk_27m)`) | ticks = 0.050 · CLK_27 = **1 350 000** | `round(0.050 · CLK_27)`. Cosmético, no crítico. |
| 13 | `fpga/top.v:2798` | `led_stretch #(.HOLD(540000)) st_wifi` | 540 000 | Estirado LED actividad **WiFi** ≈ **20 ms** | `clk_27m` (27 MHz) | ticks = 0.020 · CLK_27 = **540 000** | `round(0.020 · CLK_27)`. Cosmético. |
| 14 | `fpga/top.v:2799` | `led_stretch #(.HOLD(1350000)) st_kbd` | 1 350 000 | Estirado LED actividad **teclado** ≈ **50 ms** | `clk_27m` (27 MHz) | ticks = 0.050 · CLK_27 = **1 350 000** | `round(0.050 · CLK_27)`. Cosmético. |
| 15 | `fpga/top.v:2811` | `ws2812 #(.NUM_LEDS(8), .CLK_FRE(27))` | 27 | Frecuencia (MHz) que el driver WS2812B usa para calcular los tiempos de bit (T0H/T1H/reset del protocolo) | `clk_27m` (27 MHz, `.clk(clk_27m)`) | `CLK_FRE` = CLK_27 en MHz = **27** | **Poner CLK_FRE = frecuencia real de `clk_27m` en MHz.** Con 27M: 27. Si el reloj del driver cambia, actualizar o los tiempos WS2812 quedan fuera de spec. AUDIT 5.C lo lista como "parámetros dependen de CLK_FRE". |

### Constantes de contexto (no son "a recalcular" pero fijan la base — para referencia del port)

| file:line | Símbolo | Valor | Nota |
|---|---|---|---|
| `clk_108p.v:44-50` | `FCLKIN/IDIV/FBDIV/ODIV` | 27 / ÷1 / ×4 / ODIV=8 | Define 108 MHz y VCO 864 MHz. Regenerar para PLLA del GW5A. |
| `gowin_clkdiv.v:27` | `DIV_MODE` | "4" | 108→27. |
| `gowin_clkdiv2.vhd:44` | `DIV_MODE` | "2" | 108→54. IP creado para GW1NR-9 (regenerar). |
| `clk_135.v:42-48` | `FCLKIN/FBDIV/ODIV` | 27 / ×5 / ÷4 | 27→135 (TMDS ×5). `DYN_DA_EN="true"` fantasma — pedir fase estática al regenerar. |
| `top.v:137-138` | `clk_enable_27m/54m` (÷ de 108) | cnt `[1:0]` | Enables 27/54 derivados de 108; AUDIT los marca como código muerto candidato a borrar (5.2.3). |

---

## 3. Puntos INCIERTOS / a verificar en el port

- **[INCIERTO] `clk_i` de `wifi_lite` = 27 MHz**: confirmado por el comentario in-code (wifi_lite.vhd:193-198 "for XTAL 27 MHz", 27000000/859372=31) y coherente con que todo el ocm cuelga de `clk_27m`. No he leído la instanciación exacta de `wifi_lite` en top.v en esta pasada (la lista de instancias `clk21m`→`clk_27m` del §1 lo hace casi seguro). **Verificar** el `clock_i =>` de la instancia de `wifi_lite` en top.v antes de tocar el prescaler.
- **[INCIERTO] Redondeo real 859 372 vs 870 968**: 27M/31 = 870 968 bps, pero el doc/comentario declara **859 372 bps**. La discrepancia (~1.35%) la absorbe la tolerancia UART del ESP; el número "859372" viene del firmware de ducasp. Al portar: lo que importa es que `CLK_wifi/prescaler` caiga dentro de ±2-3% de 859 372. **Confirmar tolerancia** si se cambia la base.
- **RTC (#7)**: confirmado que el LFSR avanza con `clkena=clk_enable_3m6_27` (rtc.v:180), es decir a la cadencia del **bus 3.58 MHz**, no a 27 MHz. Por eso el valor NO depende de la base FPGA mientras el enable siga siendo 3.579545 MHz. Es el punto más fácil de romper por un recálculo ingenuo.

---

## 4. Bloque propuesto: localparams derivados de un único `CLK_108_HZ`

Centralizar en una cabecera (p.ej. `fpga/src/clock_config.vh`) incluida por `top.v`, `rtc.v`(*), `wifi_lite`(*), `psg_filter.v`. Un único cambio de base recalcula todo. (*) VHDL: replicar como `constant` en un package o parametrizar por genéricos.

```verilog
// ===== clock_config.vh — base de reloj centralizada (port 60K) =====
// UNICO parametro a tocar si cambia la base. Con 108M exactos, todos los
// valores de abajo COINCIDEN con los literales actuales del RTL.
`ifndef CLOCK_CONFIG_VH
`define CLOCK_CONFIG_VH

localparam integer CLK_108_HZ = 108_000_000;              // salida de CLK_108P
localparam integer CLK_54_HZ  = CLK_108_HZ / 2;           // Gowin_CLKDIV2  = 54_000_000
localparam integer CLK_27_HZ  = CLK_108_HZ / 4;           // Gowin_CLKDIV   = 27_000_000

// --- Bus MSX 3.6 MHz interno (÷30 sobre 108): medio-periodo ---   [top.v:225]
localparam integer BUS_3M6_HZ      = 3_600_000;
localparam integer DIV30_HALF      = CLK_108_HZ/(2*BUS_3M6_HZ) - 1;      // = 14

// --- Turbo WSX: base 5.4 MHz (÷20 sobre 108) + trago 175/176 ---  [top.v:899,917/924]  [CRITICO]
localparam integer TURBO_BASE_HZ   = CLK_108_HZ / 20;                    // 5_400_000 (debe ser exacto)
localparam integer DIV20_HALF      = CLK_108_HZ/(2*TURBO_BASE_HZ) - 1;   // = 9
localparam integer PANA_SWALLOW_N  = 175;   // enmascara 1 de cada 176 -> 5.4M*175/176 = 5_369_318 EXACTO
localparam integer PANA_SWALLOW_D  = 176;   // (par valido SOLO si TURBO_BASE_HZ == 5.400000 MHz)

// --- Power-on WiFi/ESP: ~3 s @27 ---                              [top.v:836]
localparam integer ESP_BOOT_CNT    = 3 * CLK_27_HZ;                      // = 81_000_000

// --- Autofire: semiperiodo 50 ms @54 ---                          [top.v:516]
localparam integer AF_HALF_CNT     = CLK_54_HZ / 20;                     // 50ms = 2_700_000

// --- Secuencia reset power-on: ~38.8 ms/paso @27 ---              [top.v:290]
localparam integer RST_STEP_CNT    = 1 << 20;                           // 1_048_576 (~38.8 ms)

// --- Filtro PSG/OPLL (enables) @27 ---                            [psg_filter.v:28,32]
localparam integer PSG_2M7_DIV     = CLK_27_HZ/2_450_000 - 1;           // = 10  (÷11)
localparam integer PSG_270K_DIV    = CLK_27_HZ/  267_000 - 1;           // = 100 (÷101)

// --- LED activity stretch @27 ---                                [top.v:2797-2799]
localparam integer LED_50MS        = CLK_27_HZ / 20;                    // 1_350_000
localparam integer LED_20MS        = CLK_27_HZ / 50;                    // 540_000

// --- WS2812: frecuencia del driver en MHz ---                    [top.v:2811]
localparam integer WS2812_CLK_MHZ  = CLK_27_HZ / 1_000_000;            // 27

`endif
```

Casos aparte (no encajan en el patrón lineal):
- **RTC `c_1sec_cnt0` (#7) [CRITICO]**: es un patrón LFSR, NO un contador. `localparam` = valor generado, con comentario del recuento de ticks. Mantener `22'h2D94A3` mientras `clk_enable_3m6_27` = 3.579545 MHz. Regenerar con el LFSR de KdL solo si cambia el nº de ticks/segundo del enable — nunca restando.
- **UART WiFi prescaler (#8) [CRITICO]**: `WIFI_PRESCALER = round(CLK_WIFI_HZ / 859_372)` = 31 con 27 MHz. `WIFI_TMO_25MS = CLK_WIFI_HZ/40` = 675_000 (#9). El objetivo es el **baudrate del firmware**, no una fracción de la base.

---

## 5. Resumen de criticidad

- **[C] CRÍTICAS (romperían compatibilidad si se recalculan mal):** #2+#3 turbo WSX 5.369318 MHz exacto (par ÷20 + 175/176), #7 LFSR RTC del segundo (regenerar, no restar), #8 prescaler UART WiFi 859372 bps (lo fija el firmware ESP).
- **[·] Ordinarias (márgenes amplios, tolerantes):** #1 bus 3.6 MHz, #4/#6 resets/boot, #5 autofire, #9 timeout WiFi, #10/#11 filtros PSG, #12-#14 LED stretch, #15 WS2812.
- **Camino de mínimo riesgo:** clavar CLK_108 = 108.000000 MHz en el PLLA del GW5A → los 15 literales quedan idénticos y solo hay que regenerar los 4 IPs de PLL/CLKDIV (no las constantes). La única constante que NUNCA se recalcula linealmente es el LFSR RTC (#7).
