# Port MSXnano → Tang Console 60K (GW5AT-60): regeneración de IPs de reloj y memoria (GW5A)

**Objetivo del documento.** Plan para regenerar, para la familia **Gowin GW5A / GW5AT-60 (Arora V)**, las
cuatro IPs de reloj actuales del core MSXnano (rPLL 108 MHz, dos CLKDIV, rPLL 135 MHz TMDS) y el
controlador de memoria (SDRAM → **DDR3 512 MB**), preservando el contrato de la interfaz `ram_*` / `vram_*`.

**Regla de anclaje.** Todo lo que sigue está anclado a `file:line` del árbol limpio
`C:\Users\alber\proyectosAI\msx\_MSXnano_dev_ref`. Los datos externos citan fuente. Lo que no he podido
confirmar contra fuente primaria va marcado **INCIERTO** con el motivo.

> Nota de método: los PDFs de Gowin (DS981/DS1103 datasheet, UG306 Arora V Clock, IPUG281 DDR3) no se
> dejan extraer como texto por la herramienta de fetch (streams comprimidos → 403/binario). Los valores
> numéricos de abajo provienen de fuentes HTML secundarias fiables (apicula wiki, la PLL calculator de juj,
> páginas de producto Gowin, resúmenes de manuals.plus). Los números que dependen exclusivamente del PDF
> primario quedan **INCIERTOS** y con la acción "confirmar en el PDF/IDE".

---

## 0. Estado actual anclado (lo que hay que regenerar)

### 0.1 Árbol de relojes real (`fpga/top.v`)
El reloj de entrada es **`ex_clk_27m` = 27 MHz** (`top.v:128`). De ahí cuelga todo:

| IP / señal | Instancia | Fichero fuente | Frecuencia | Uso |
|---|---|---|---|---|
| `CLK_108P clk_main` | `top.v:123-129` | `fpga/src/gowin/clk_108p.v` | 27→**108 MHz** (`clk_108m`) + `clk_108m_n` (fase) + `clock_locked` | reloj maestro SDRAM + secuenciador de memoria |
| `Gowin_CLKDIV div4` | `top.v:141-145` | `fpga/src/gowin_clkdiv/gowin_clkdiv.v` | 108÷4 = **27 MHz** (`clk_27m`) | dominio "lento" (I/O ports, RTC, kanji…) |
| `Gowin_CLKDIV2 div2` | `top.v:185-189` | `fpga/src/gowin_clkdiv2/gowin_clkdiv2.vhd` | 108÷2 = **54 MHz** (`clk_54m`) | CPU Z80 (T80), bus, wait FSM, mem accept |
| `CLK_135` (VDP) | dentro de `tn_vdp_v3_v9958` | `fpga/tn_vdp_v3_v9958/src/gowin/clk_135.v` | 27→**135 MHz** | reloj serial TMDS (×5 de 27) para HDMI |

Además hay un reloj de vídeo generado por conteo, **no por IP**: `VideoDHClk` (÷2 de 27) y `VideoDLClk`
(÷4 de 27), declarados como generated clocks en la SDC (`Z80_goauld.sdc:15-16`). Estos **fasan** el
secuenciador SDRAM (`memory.v` los usa como ventana de arbitraje CPU/VDP). No son una IP, pero su relación
de fase con 108/54/27 es parte del contrato (ver §4.4).

### 0.2 Parámetros exactos de cada rPLL/CLKDIV actual (GW2AR-18 / GW1NR-9)

**`CLK_108P` — `clk_108p.v`** (primitiva `rPLL`, `DEVICE="GW2AR-18C"`):
- `FCLKIN="27"`, `IDIV_SEL=0` (÷1), `FBDIV_SEL=3` (×4), `ODIV_SEL=8`.
- rPLL (GW2A): `CLKOUT = FCLKIN·(FBDIV_SEL+1)/(IDIV_SEL+1) = 27·4/1 =` **108 MHz**;
  `VCO = CLKOUT·ODIV_SEL = 108·8 =` **864 MHz**.
- `PSDA_SEL="1000"` → salida de fase `CLKOUTP` (`clk_108m_n`, `clk_108p.v:39/51`). `DYN_DA_EN="false"`.

**`CLK_135` — `clk_135.v`** (primitiva `rPLL`, `DEVICE="GW2AR-18C"`):
- `FCLKIN="27"`, `IDIV_SEL=0`, `FBDIV_SEL=4` (×5), `ODIV_SEL=4`.
- `CLKOUT = 27·5/1 =` **135 MHz**; `VCO = 135·4 =` **540 MHz**.
  *(Corrijo un dato de la auditoría: `AUDIT_PRE_PORT_60K.md:89` implica VCO 864 para el x5; el cálculo real
  con ODIV_SEL=4 da **540 MHz**, no 864. VCO 864 correspondería a ODIV_SEL=8; aquí es 4.)*
- **`DYN_DA_EN="true"`** (`clk_135.v:50`) — el "fantasma" citado por la auditoría: habilita ajuste dinámico
  de fase/duty que **este diseño no usa** (PSDA/DUTYDA cableados a `gnd`, `clk_135.v:37-38`). Al regenerar
  para GW5A hay que pedir **fase estática** y dejar este flag en false, o el generador arrastra puertos de
  reconfiguración dinámica muertos.

**`Gowin_CLKDIV` (÷4) — `gowin_clkdiv.v`**: primitiva `CLKDIV`, `DIV_MODE="4"`, `DEVICE=GW2AR-18`. OK.

**`Gowin_CLKDIV2` (÷2) — `gowin_clkdiv2.vhd`**: primitiva `CLKDIV`, `DIV_MODE="2"`, pero
**`Part Number: GW1NR-LV9QN88PC6/I5` / `Device: GW1NR-9`** (`gowin_clkdiv2.vhd:5-6`). Está **generado para el
chip equivocado** (GW1NR-9, no el GW2AR-18 del resto). Funciona hoy porque `CLKDIV` es una primitiva común,
pero es exactamente el tipo de IP que hay que **regenerar limpia** para el device correcto en el port.

### 0.3 Contrato de memoria (`fpga/src/memory.v`, módulo `memory_ctrl`)
No existe un fichero `MEMORY_CONTRACT.md`; el "contrato" **es la interfaz del módulo `memory_ctrl`**
(`memory.v:2-33`) más el requisito MG2. Interfaz que el port DEBE preservar byte a byte hacia el core:

```
入力 (del core):  clk_27m, clk_108m, bus_reset_n, video_dhclk, video_dlclk,
                  ram_din[7:0], ram_req, ram_write, ram_addr[22:0],
                  vram_din[7:0], vram_write, vram_addr[16:0], bus_rfsh_n
出力 (al core):   ram_dout[7:0], vram_dout[15:0], ram_busy
```
Instanciado en `top.v:1463-1493` como `mem1`. **Detalle no obvio**: el puerto `.clk_27m` recibe en realidad
**`clk_54m`** (`top.v:1464`) — el secuenciador de aceptación (`memory.v:62-110`) corre a **54 MHz**, no 27.
El resto del controlador SDRAM corre a `clk_108m`.

Semántica del contrato (de `memory.v`):
- Handshake CPU: subir `ram_req` → el secuenciador espera la ventana `video_dhclk==1 && video_dlclk==1`
  (`memory.v:75`), pone `ram_busy=1`, hace el acceso, deja `ram_dout` y baja `ram_busy` (`memory.v:96-98`);
  el llamador baja `ram_req` y vuelve a seq 0 (`memory.v:100-104`). **Latencia determinista**: 1 acceso CPU
  y 1 VDP por ventana de línea de vídeo.
- **Requisito MG2 (crítico, `memory.v:204-213`)**: *toda escritura VDP aceptada se COMPLETA*; el refresh solo
  roba el slot VDP si el VDP va a **leer** (recuperable), nunca si va a **escribir** (o reaparecen los
  "agujeros en VRAM" del glitch de MG2). Esto **no es código a traducir, es una propiedad del arbitraje** que
  el arbiter DDR3 nuevo tiene que honrar (ver §4.3).
- Las "magic ports" SDR (`memory.v:22-32`, `top.v:69-79`, `O_sdram_*`) **desaparecen** en el GW5AT-60: son la
  interfaz de la SDRAM inferida del GW2AR-18. Se sustituyen por la interfaz de usuario de la DDR3 IP.

### 0.4 Reutilización SRAM-persistente (enlace con el plan del 60K)
`SRAM_PERSIST_CONSOLE60K_DESIGN.md` reutiliza `flash_rw.v` para el auto-commit y **recomienda alojar la SRAM
de cartucho en BRAM dedicada de 32 KB** (§3.1a de ese doc), no en DDR3, precisamente para desacoplarla del
arbitraje del controlador nuevo. Este documento de IP asume esa decisión: el wrapper DDR3 sirve
mapper/megaram/RAM/VRAM; la SRAM persistente vive aparte en BRAM (el GW5AT-60 tiene BRAM de sobra).

---

## 1. IP de reloj — CLK_108P (reloj maestro 108 MHz + fase)

**Objetivo:** de `ex_clk_27m` (27 MHz) generar **108 MHz exactos** (`clk_108m`, base de todo el timing del
core y del turbo WSX 5.369318 MHz) más una salida desfasada equivalente al `CLKOUTP` actual
(`clk_108m_n`), y `LOCK` (`clock_locked`, que entra en el reset, `top.v:102`).

**Primitiva GW5A: `PLLA`** (no `rPLL`). Confirmado: en Arora V/GW5A la PLL es `PLLA`, con hasta **7 salidas
de reloj** y **fase estática independiente por salida** vía `CLKOUT0_PE_COARSE/CLKOUT0_PE_FINE`
(apicula wiki `PLL`). La `rPLL` del código actual **no existe** en GW5A. Puertos PLLA relevantes:
`CLKIN, CLKOUT0..CLKOUT6, LOCK, RESET`, parámetros `IDIV_SEL, FBDIV_SEL, ODIV0_SEL..ODIV6_SEL,
CLKOUTn_PE_COARSE/FINE`. Reconfiguración dinámica por `MDCLK/MDOPC/MDWDI/MDRDO` (no la usamos).

**Fórmula PLLA/PLLVR** (distinta de rPLL): `fCLKOUT = fCLKIN·FBDIV/IDIV`, `fVCO = fCLKOUT·ODIV`
(apicula wiki `PLL`; misma familia de fórmula que PLLVR). Para 108 MHz desde 27:
- `IDIV=1`, `FBDIV=4` → `fCLKOUT = 27·4/1 = 108 MHz`. Con `ODIV` tal que `fVCO = 108·ODIV` caiga dentro del
  rango VCO del GW5A. Con `ODIV=8` → VCO 864 MHz (mismo punto que hoy). Con VCO GW5A ≥ 800 MHz, **864 MHz es
  válido**; si el generador prefiere otro ODIV, elegir el que deje VCO en rango.

**Cómo se regenera (flujo propietario obligatorio):**
1. Gowin IDE → IP Core Generator → **PLLA** (Arora V) para device `GW5AT-LV60...` (SOM Tang Mega 60K).
2. Fijar `CLKIN=27 MHz`, salida 0 = 108 MHz. Pedir una segunda salida (CLKOUT1) con el **mismo desfase** que
   el `PSDA_SEL="1000"` del `CLKOUTP` actual — traducir ese código de fase a `CLKOUT1_PE_COARSE/FINE`
   (el "1000" del PSDA de 16 pasos ≈ 8/16 = **180°**; confirmar el equivalente exacto en el generador PLLA).
3. Salida **fija**, sin SSC, sin reconfig dinámica (`DYN_DA_EN` equivalente en OFF).
4. Sustituir en `top.v:123-129` la instancia `CLK_108P` por la nueva (mismos nombres de puerto de wrapper:
   `clkout`, `clkoutp`, `lock`) para minimizar el diff.

**Riesgos:**
- **`clk_108m_n` (la fase) es carga real**: aunque no la he rastreado como consumidor crítico aquí, si
  algún camino la usa hay que reproducir el desfase con PE_COARSE/PE_FINE, no dejarla en 0°. **INCIERTO** el
  desfase exacto en grados que representa `PSDA_SEL="1000"`: la doc de rPLL lo define en 16 pasos del periodo;
  confirmar la conversión a los parámetros de PLLA en el generador.
- **apicula (yosys) NO soporta PLLA/PLL/PLLO** todavía (apicula wiki: "not yet supported"). El árbol de
  relojes del port **obliga al flujo propietario Gowin** (gw_sh/IDE), no al open-source. Esto afecta a la
  estrategia de build completa del 60K, no solo a esta IP.
- **VCO máximo del GW5A INCIERTO**: fuente confirma **límite inferior 800 MHz** y PFD 3–400 MHz (resúmenes de
  UG306/producto). El límite superior exacto (¿1600 MHz? ¿1800 MHz?) no lo pude leer del PDF primario. 864 MHz
  está claramente dentro; no bloquea, pero **confirmar el rango completo en UG306/DS981** antes de fijar ODIV.

---

## 2. IP de reloj — Gowin_CLKDIV (÷4 → 27 MHz) y Gowin_CLKDIV2 (÷2 → 54 MHz)

**Objetivo:** de `clk_108m` derivar `clk_27m` (÷4) y `clk_54m` (÷2), **manteniendo la alineación de fase**
con 108 (requisito de los cruces sin sincronizador, §4.4).

**Primitiva GW5A: `CLKDIV`** (existe en Arora V). `DIV_MODE` admite `2/3.5/4/5/8`; puertos
`CLKOUT, HCLKIN, RESETN, CALIB` (apicula wiki `CLKDIV`; Arora V Clock UG306). Es la **misma primitiva** que
hoy → el port es casi mecánico:

**Cómo se regenera:**
1. Regenerar `Gowin_CLKDIV` (÷4) para el device GW5AT-60. Cambia solo el header/DEVICE; `DIV_MODE="4"`.
2. **Regenerar `Gowin_CLKDIV2` limpio** (÷2) para el device correcto: hoy está generado para **GW1NR-9**
   (`gowin_clkdiv2.vhd:5-6`) — no reutilizar ese fichero, regenerarlo con `DIV_MODE="2"`.
3. La entrada `HCLKIN` debe venir de la **red HCLK** (reloj de alta velocidad). En el GW5A, `clk_108m` de la
   PLLA debe enrutar a HCLK para alimentar los CLKDIV; verificar en el fitter que no cae a routing genérico
   (si no, la relación de fase 108/54/27 se degrada → §4.4).

**Riesgos:**
- **`Gowin_CLKDIV2` device equivocado** (ya citado): regenerar, no copiar. Un CLKDIV de otra familia puede
  mapear a un recurso distinto en GW5A y romper en silencio la alineación de fase.
- **CALIB / fase**: el CALIB del CLKDIV ajusta fase en flanco de bajada según el modo. Dejarlo a `gnd` como
  hoy (`gowin_clkdiv.v:24`, `gowin_clkdiv2.vhd:50`) salvo que el análisis de fase del §4.4 exija ajuste.
- **Alternativa a considerar**: como la PLLA da 7 salidas, se puede generar 108 **y** 54 **y** 27 como tres
  salidas de la MISMA PLLA (con ODIV distintos), garantizando alineación de fase por construcción y
  eliminando los dos CLKDIV. Es la opción más limpia para el 60K (menos incógnitas de fase); a valorar contra
  el coste de tocar más el diff. **Recomendada** si el análisis §4.4 confirma que la alineación por CLKDIV es
  frágil en GW5A.

---

## 3. IP de reloj — CLK_135 (TMDS ×5) / HDMI en GW5A

**Objetivo hoy:** `CLK_135` genera 135 MHz = 5×27 para serializar TMDS a 10×27 = 270 Mbps por canal
(1080p/DVI a pixel-clock 27 MHz → **INCIERTO** la resolución exacta de salida; el core es MSX, típicamente
pixel-clock 27 MHz, TMDS bit-clock 135 MHz, línea serial 270 Mb/s por par).

**Dos caminos para HDMI en GW5A:**

**(A) Portar el esquema actual (rPLL 135 + serializador ×5 por CLKDIV/lógica).**
- Regenerar `CLK_135` como **PLLA**: `IDIV=1, FBDIV=5` → 135 MHz; `ODIV` para VCO en rango (con ODIV=4 →
  VCO 540 MHz, válido; **NO** heredar ODIV=8 sin recalcular). **Poner `DYN_DA_EN`/reconfig en OFF** (hoy está
  en `true` sin usarse, `clk_135.v:50` — el fantasma). Fase estática.
- Mínimo diff, reutiliza el pipeline TMDS existente del `tn_vdp_v3_v9958`.

**(B) Usar el serializador nativo del GW5A (OSER10/SERDES) — recomendada a medio plazo.**
- El GW5A tiene salida serial rápida por GPIO: **LVDS hasta ~2.0 Gbps** (VCCX 3.3V) por par, y SERDES
  analógico hasta 12.5 Gbps (páginas de producto Arora V / GW5AT). El bit-clock de HDMI 1080p (1.485 Gbps)
  **cabe** en la vía LVDS/OSER nativa → no hace falta el truco de PLL a 135 + serialización manual.
- Ventaja: elimina una PLL entera y el pipeline TMDS manual; usa el patrón `OSER10`+`ELVDS`/`TLVDS` que ya
  usan los ports HDMI de GW5A (p.ej. proyectos Tang Primer 25K).
- Coste: reescribir la capa de salida del VDP (no el core VDP, solo el "PHY" HDMI). Encaja bien con que el
  60K ya obliga a rehacer constraints de I/O.

**Riesgos:**
- **`DYN_DA_EN="true"` fantasma** (`clk_135.v:50`): si se porta el camino (A) tal cual con el generador,
  puede reintroducir puertos de fase dinámica muertos. Pedir explícitamente salida estática.
- **VCO recalculado**: el ODIV del 135 actual (4) da VCO 540 MHz; el del 108 (8) da 864. **No copiar ODIV
  entre PLLs**; recalcular cada uno para que VCO caiga en el rango GW5A (≥800 confirmado; techo INCIERTO).
  *(Ojo: VCO 540 MHz podría quedar por debajo del mínimo 800 del GW5A → en camino (A) habría que subir ODIV,
  p.ej. ODIV=8 → VCO 1080 MHz, y ajustar. Esto NO ocurría en GW2A. **Confirmar rango y reajustar ODIV**.)*
- **INCIERTO** el número fino de data-rate del OSER10 por pin en GW5A (12.5 Gbps es el SERDES analógico,
  no el GPIO OSER). El margen de HDMI 1080p es holgado, pero confirmar en DS981/UG de I/O antes de comprometer
  la vía (B).

---

## 4. IP de memoria — SDRAM (GW2AR-18) → DDR3 Memory Interface IP (GW5AT-60)

Es **el bloque más caro del port**. Se sustituye `memory.v` entero (secuenciador SDR crudo @108 MHz) por un
wrapper alrededor de la **Gowin DDR3 Memory Interface IP** que **preserva la interfaz `ram_*`/`vram_*`** de
§0.3 hacia el core.

### 4.1 Interfaz de usuario de la DDR3 IP de Gowin (IPUG281)
Señales del "local/user interface" (nombres del IP; fuente: resúmenes IPUG281 + página de producto Gowin.
Los nombres exactos deben confirmarse contra el PDF IPUG281 en el IDE — ver INCIERTO al final):

| Grupo | Señales (nombres de la IP) | Semántica |
|---|---|---|
| Reloj/reset | `clk` (user clock), `memory_clk`, `pll_lock`/`pll_stop`, `rst_n`, `resetn` | `clk` = dominio de usuario; `memory_clk` alimenta el PHY DDR3 |
| Calibración | **`init_calib_complete`** | **R/W prohibidos hasta que sube a 1** tras power-on/calibración |
| Comando | `cmd[2:0]`, `cmd_en`, (`cmd_ready`/handshake), `addr`/`app_addr` | `cmd` codifica READ/WRITE; `addr` mapea a Rank/Bank/Row/Column; válido con `cmd_en` |
| Escritura | `wr_data`, `wr_data_en`, `wr_data_mask`, `wr_data_end` | datos de escritura, con máscara por byte y marca de fin de ráfaga |
| Lectura | `rd_data`, `rd_data_valid`, `rd_data_end` | **datos válidos SOLO cuando `rd_data_valid`=1** (latencia variable) |
| Control | `sr_req` (self-refresh), `ref_req` (refresh manual), `burst` | opcionales |

**Puntos clave del contrato de la IP (confirmados):**
- **`init_calib_complete` gatea todo**: hasta que la IP calibra el PHY contra la DDR3, cualquier acceso está
  prohibido. El wrapper debe **bloquear el core** (retener reset del subsistema de RAM / no aceptar `ram_req`)
  hasta `init_calib_complete==1`. Es un cambio de arranque que la SDRAM inferida no tenía.
- **Ratio de reloj usuario:memoria = 1:4** disponible (`clk = memory_clk/4`; confirmado que la IP soporta 1:4).
  Es decir, el usuario opera a **1/4 de la tasa DDR** con el bus local ensanchado (típico 8× el ancho de DQ).
- **Latencia de lectura NO determinista**: no hay un número fijo de ciclos; **hay que esperar
  `rd_data_valid`**. Esto **rompe** el modelo de latencia fija de `memory.v` (§0.3) → §4.2.
- **Ancho de datos**: el bus local es varias veces el ancho físico DQ (para compensar el ratio 1:4). El core
  MSXnano trabaja con `ram_din/ram_dout` de **8 bits** y `vram_*` de **8/16 bits** → el wrapper hace el
  desempaquetado (elegir un byte del burst), igual que hoy `memory.v:420-443` extrae el byte de `SdrDat[31:0]`.
- **`init_calib_complete`, `cmd/cmd_en`, `wr_data*`, `rd_data_valid`** son los pilares; el resto
  (`sr_req/ref_req`) puede quedar inactivo al principio.

### 4.2 El problema central: latencia fija → handshake real
`memory.v` asume latencia determinista y el core **no usa `ram_busy` para los wait states de memoria** en la
rama por defecto: `top.v:686-755` mete un número **fijo** de wait cycles (`wait_cycles <= 7'd6`, `top.v:727`)
y el propio código lo advierte (`top.v:886-887`). Con DDR3 (latencia variable) esto es **corrupción
garantizada**.

→ **Requisito del port (no opcional):** activar/portar la rama **`ENABLE_WAIT_ADAPTIVE`** (`top.v:686-714`),
que libera el wait con el handshake real (`clk_enable_3m6`/estado), y encadenar el `ram_busy` de la IP DDR3
(derivado de `cmd_ready` + espera a `rd_data_valid`) al `ram_busy` que ya existe en el contrato
(`memory.v:20`, consumido en `top.v:738`). En resumen: el wrapper convierte `init_calib_complete` +
`rd_data_valid` + aceptación de comando en el `ram_busy` que el core ya sabe esperar — pero **hay que usarlo**
(rama adaptativa), no la de waits fijos.

### 4.3 Preservar el requisito MG2 en el arbiter nuevo
El arbiter del wrapper DDR3 tiene que codificar la propiedad de `memory.v:204-213`: **una escritura VDP
aceptada nunca se descarta por refresh/arbitraje**. Con la DDR3 IP el refresh lo gestiona la IP
(`ref_req`/auto-refresh), así que el riesgo se traslada al **arbiter usuario CPU/VDP** del wrapper: si el
wrapper da ACK a una escritura VDP, debe garantizar que llega a `wr_data`/`wr_data_end` antes de atender otra
cosa. Si no, reaparece el glitch "agujeros en VRAM" de MG2 con otra cara. **Trasladar por escrito como
requisito de diseño del arbiter**, no como código a traducir.

### 4.4 Alineación de fase 27/54/108 y cruces sin sincronizador
El core tiene cruces registro-a-registro 27↔54 **sin sincronizadores** que hoy son seguros SOLO por la
alineación de fase del árbol CLKDIV (misma PLL): `ppi_port_a` (`top.v:1032-1040`), `exp_slot*`
(`top.v:1071-1090`), keyboard/joystick (`top.v:486-501`, `:860`). Con la DDR3 IP aparece **un dominio de
reloj nuevo** (`clk` de usuario de la IP, potencialmente distinto de `clk_54m`). Dos opciones:
- (a) Hacer que el `clk` de usuario de la DDR3 **sea** uno de los relojes del árbol (54 o 27), derivando
  `memory_clk` de la misma PLLA → mantiene la alineación. Preferible.
- (b) Si el `clk` de la IP es independiente, **añadir sincronizadores 2FF** en todos los cruces al/desde el
  dominio DDR3 (el wrapper `ram_*`/`vram_*` pasa a ser una frontera CDC explícita).

→ **Recomendación**: generar 108/54/27 como salidas de la **misma PLLA** (§2, opción de 7 salidas) y anclar
el `clk` de usuario de la DDR3 a ese árbol, para no multiplicar dominios asíncronos.

### 4.5 Encaje con SRAM-persistente
Coherente con `SRAM_PERSIST_CONSOLE60K_DESIGN.md`: la **megaram/mapper/RAM/VRAM** van sobre el wrapper DDR3;
la **SRAM de cartucho (segs 252-255)** va en **BRAM dedicada de 32 KB** (no DDR3), para no acoplarla al
arbitraje ni al decay. El wrapper DDR3 expone `ram_*`/`vram_*`; el enrutado `sram_hit` (`megaram.v:88-109`)
apunta a la BRAM. El auto-commit reutiliza `flash_rw.v` (con los fixes #1 write_terminate y WIP post-program
de la auditoría **obligatorios antes**). Ver §4.3 de ese doc.

### 4.6 Estrategia de VRAM (opción de diseño)
La auditoría (`AUDIT_PRE_PORT_60K.md:84`) sugiere valorar **VRAM en BRAM del GW5A** (que sobra) y dejar DDR3
solo para mapper/megaram. Esto **simplifica el arbiter** (elimina el cliente VDP de la DDR3, que es el de
timing más estricto y el del requisito MG2) y da latencia VRAM determinista. **Recomendado evaluarlo**: si
la VRAM (128 KB del V9958) cabe holgada en BRAM del GW5AT-60, el wrapper DDR3 solo sirve CPU/mapper y el
requisito MG2 (§4.3) se satisface trivialmente porque la VRAM ya no compite por DDR3.

---

## 5. Resumen por IP: objetivo · regeneración · riesgos

| IP actual | Objetivo (freq/fase) | Regeneración GW5A | Riesgos principales |
|---|---|---|---|
| `CLK_108P` (rPLL, `clk_108p.v`) | 27→108 MHz + `CLKOUTP` fase (~180°) + LOCK | **PLLA** IDIV=1/FBDIV=4; ODIV para VCO≥800; fase por `CLKOUTn_PE_COARSE/FINE`; estática | conversión de `PSDA="1000"` a PE_* (INCIERTO grados); **apicula no soporta PLLA → flujo propietario**; VCO máx INCIERTO |
| `Gowin_CLKDIV` ÷4 (`gowin_clkdiv.v`) | 108→27 MHz | **CLKDIV** DIV_MODE="4", device 60K | HCLKIN debe ir por red HCLK; si no, se degrada la fase |
| `Gowin_CLKDIV2` ÷2 (`gowin_clkdiv2.vhd`) | 108→54 MHz | **CLKDIV** DIV_MODE="2", **regenerar (hoy es GW1NR-9)** | **device equivocado** → regenerar, no copiar; alineación de fase |
| `CLK_135` (rPLL, `clk_135.v`) | 27→135 MHz TMDS ×5 | **(A)** PLLA IDIV=1/FBDIV=5, recalcular ODIV (VCO 540 < 800 → subir); o **(B)** OSER10/LVDS nativo | **`DYN_DA_EN="true"` fantasma** → pedir estática; VCO 540 puede caer bajo el mínimo → recalcular ODIV; OSER10 data-rate por pin INCIERTO |
| `memory.v` SDRAM (`O_sdram_*`) | mapper/RAM/VRAM sobre 512 MB | **DDR3 Memory Interface IP** + wrapper que preserva `ram_*`/`vram_*` | latencia variable → **rama `ENABLE_WAIT_ADAPTIVE` obligatoria**; `init_calib_complete` gatea arranque; requisito MG2 en arbiter; ratio 1:4 y dominio de reloj nuevo (§4.4) |

**Recomendaciones transversales:**
1. Generar 108/54/27 desde **una sola PLLA** (7 salidas) para garantizar alineación de fase y anclar ahí el
   `clk` de usuario de la DDR3 → evita CDC asíncrono en los cruces sin sincronizador.
2. Todas las constantes derivadas del reloj (turbo WSX 5.369318 MHz `top.v:899-935`, ÷30→3.6 MHz `top.v:225`,
   ESP 859372 bps `wifi_lite.vhd:205`, RTC, autofire…) deben recalcularse **solo si cambia la base de 27/108**;
   el SOM Tang Mega 60K entrega su propio oscilador — **confirmar que la base sigue siendo 27 MHz** o
   recalcular todo (auditoría §5.A2).
3. El port del reloj **obliga al flujo propietario Gowin** (PLLA no está en yosys/apicula); planificar el
   build del 60K en consecuencia.

---

## 6. Lista de INCIERTOS (confirmar en fuente primaria / IDE)

1. **VCO máximo del GW5A/PLLA**: confirmado mínimo **800 MHz** y PFD **3–400 MHz** (resúmenes UG306/producto);
   **techo exacto no leído** del PDF primario (DS981/UG306 no extraíbles por la herramienta). Acción: leer
   §"PLL Switching Characteristics" de DS981 o generar en el IDE y ver el rango que valida.
2. **VCO del CLK_135 recalculado**: con ODIV=4 el VCO sería 540 MHz, probablemente **por debajo del mínimo 800
   del GW5A**. Hay que subir ODIV (p.ej. 8 → 1080 MHz) al regenerar. Depende del punto 1.
3. **Conversión de fase `PSDA_SEL="1000"` (rPLL) a `CLKOUTn_PE_COARSE/FINE` (PLLA)**: estimado ~180°; el
   número exacto de pasos/grados hay que verlo en el generador PLLA.
4. **Nombres exactos de las señales del local interface de la DDR3 IP** (`cmd` vs `app_cmd`, `addr` vs
   `app_addr`, `wr_data_end` vs `wr_data_last`, presencia de `cmd_ready`): tomados de resúmenes de IPUG281;
   **confirmar contra el PDF IPUG281-2.6E o el wrapper que genere el IP Core Generator** en el IDE. El
   comportamiento (init_calib_complete gatea, esperar rd_data_valid, ratio 1:4) sí está confirmado.
5. **Ancho exacto del bus local DDR3** y del DQ físico del SOM Tang Mega 60K (para dimensionar el
   desempaquetado a bytes MSX): depende del generador y del chip DDR3 del SOM. Confirmar en el IDE.
6. **Data-rate por pin del OSER10/LVDS en GW5A** para la vía HDMI nativa (vía B, §3): 12.5 Gbps es el SERDES
   analógico; el OSER GPIO es menor. HDMI 1080p (1.485 Gb/s) cabe con margen, pero el número fino queda
   INCIERTO; confirmar en DS981 (sección I/O).
7. **Base de reloj del SOM Tang Mega 60K**: asumo 27 MHz de entrada como hoy; si el SOM entrega otra frecuencia,
   todas las constantes derivadas (§5.2) cambian.

---

## 7. Fuentes

- Gowin GW5A Data Sheet DS1103 — https://cdn.gowinsemi.com.cn/DS1103E.pdf
- Gowin GW5AT Data Sheet DS981 — https://cdn.gowinsemi.com.cn/DS981E.pdf
- Arora V Clock User Guide UG306 — https://cdn.gowinsemi.com.cn/UG306E.pdf
- Gowin DDR3 Memory Interface IP User Guide IPUG281 — https://cdn.gowinsemi.com.cn/IPUG281E.pdf
- Gowin DDR3 Memory Interface IP (product/IP page) — https://www.gowinsemi.com/en/support/ip_detail/14/
- Gowin DDR3 Memory Interface IP User Guide (resumen HTML) — https://manuals.plus/m/4d99b5f1bbb45675c0497cb81db115baa4d5aad9f1a7acc22e3731bea405d22d
- apicula wiki — PLL (PLLA/PLLVR/rPLL, puertos, fórmula, soporte) — https://github.com/YosysHQ/apicula/wiki/PLL
- apicula wiki — CLKDIV (DIV_MODE, puertos) — https://github.com/YosysHQ/apicula/wiki/CLKDIV
- apicula wiki — Supported primitives — https://github.com/YosysHQ/apicula/wiki/Supported-primitives
- Gowin FPGA PLL Calculator (fórmulas VCO/PFD/CLKOUT) — https://juj.github.io/gowin_fpga_code_generators/pll_calculator.html
- Arora V / GW5A / GW5AT páginas de producto (SERDES 12.5 Gbps, LVDS 2.0 Gbps) — https://www.gowinsemi.com/en/product/detail/60/ , https://www.gowinsemi.com/en/product/detail/74/ , https://www.gowinsemi.com/en/product/detail/72/

**Anclas de código internas** (árbol `_MSXnano_dev_ref`): `fpga/src/gowin/clk_108p.v`,
`fpga/src/gowin_clkdiv/gowin_clkdiv.v`, `fpga/src/gowin_clkdiv2/gowin_clkdiv2.vhd`,
`fpga/tn_vdp_v3_v9958/src/gowin/clk_135.v`, `fpga/src/memory.v`, `fpga/top.v`, `fpga/Z80_goauld.sdc`,
`fpga/src/msxnano_menu/SRAM_PERSIST_CONSOLE60K_DESIGN.md`, `fpga/AUDIT_PRE_PORT_60K.md`.
