# Diseño del wrapper DDR3 (frente B) — el corazón del port

Sustituye `fpga/src/memory.v` (secuenciador SDR crudo @108 MHz de la SDRAM del GW2AR) por un wrapper alrededor de la **Gowin DDR3 Memory Interface IP** que **preserva la interfaz `ram_*`/`vram_*`** hacia el core. Base: [MEMORY_CONTRACT.md](MEMORY_CONTRACT.md) (interfaz a preservar) + [GW5A_IP.md](GW5A_IP.md) + interfaz REAL de la IP (ver §2, de `DDR3_TOP.v` del toolchain).

## 0. Decisión de arquitectura — partición VRAM/CPU (cierra open-item nº2)

**VRAM → BRAM del GW5A (determinista). CPU/mapper/megaram/ROM → DDR3.**

```
                 ┌───────────────────────── memory_ddr3 (wrapper) ─────────────────────────┐
   VDP  ◄──────► │  vram_addr[16:0] / vram_din[7:0] / vram_dout[15:0] / vram_write          │
 (clk_w,         │        │                                                                  │
  ~21.48MHz)     │        ▼   VRAM 128KB en BRAM dual-port  (latencia fija, NUNCA se stalea) │
                 │   ┌─────────────┐                                                          │
                 │   │  dpram DP   │  ← escritura VDP siempre aceptada = requisito MG2 GRATIS │
                 │   └─────────────┘                                                          │
                 │                                                                            │
   CPU  ◄──────► │  ram_req/ram_busy/ram_dout/ram_addr[22:0]/ram_din/ram_write (@54 MHz)      │
 (clk_54m)       │        │                                                                   │
                 │        ▼   FSM CPU  +  CDC 54↔clk_out  +  pack/unpack byte↔128b            │
                 │   ┌──────────────────────── DDR3_Memory_Interface_Top ──────────────┐     │
                 │   │  cmd/cmd_en/cmd_ready · wr_data/en/end/mask/rdy · rd_data/valid   │────┼──► pines DDR3
                 │   └──────────────────────────────────────────────────────────────────┘     │  (hard-IP, sin IO_LOC)
                 └────────────────────────────────────────────────────────────────────────────┘
```

**Por qué así** (MEMORY_CONTRACT §d + AUDIT §5.A1):
- La VRAM (128 KB) cabe holgada en BRAM del GW5AT-60 → **latencia fija de 1 ciclo**, ancho de banda dedicado, y **disuelve el requisito MG2**: una escritura VDP a un BRAM dual-port NUNCA compite con refresh/CPU → jamás se descarta. Es la forma más robusta de honrar "escritura VDP se completa siempre".
- La DDR3 (latencia variable por refresh/apertura de fila/colas) queda SOLO para accesos que **toleran** el handshake `ram_busy` (CPU/mapper/megaram). Ahí es donde la rama `ENABLE_WAIT_ADAPTIVE` (requisito 2) absorbe la latencia.
- ⚠️ **Presupuesto BRAM: CONFIRMAR** que 128 KB de VRAM caben en el BRAM del GW5AT-60 dejando margen para el resto (kanji, line buffers del VDP, FIFOs…). El GW5A-60 tiene BRAM de sobra según la auditoría, pero medir tras el primer build. Si no cupiera, fallback = VRAM en DDR3 con arbiter que garantice el requisito MG2 (más complejo).

## 1. Interfaz a preservar (core-side) — de MEMORY_CONTRACT

El wrapper `memory_ddr3` presenta a `top.v` los MISMOS puertos que `memory_ctrl` **menos los magic-ports SDRAM** (que desaparecen) y **más** los de la DDR3 IP. Nombres preservados para minimizar el diff en top.v:

| Señal | Ancho | Dir | Dominio | Nota |
|---|---|---|---|---|
| `clk_27m` (mal llamado) | 1 | in | — | **es clk_54m** (top.v:1464). Dominio del handshake CPU |
| `clk_108m` | 1 | in | — | hoy reloj SDR; con DDR3 ya no hace falta para memoria (ver §3) |
| `bus_reset_n` | 1 | in | async | reset |
| `video_dhclk`/`video_dlclk` | 1 | in | clk_w | strobes de fase de vídeo (ya solo para el path VRAM/BRAM) |
| `ram_din`/`ram_dout` | 8 | in/out | clk_54m | dato CPU |
| `ram_req`/`ram_busy` | 1 | in/out | clk_54m | **handshake** (busy ahora SÍ se usa, requisito 2) |
| `ram_write` | 1 | in | clk_54m | 1=escritura |
| `ram_addr` | 23 | in | clk_54m | dir CPU (8 MB) — banco por `[22:21]` |
| `vram_din` | 8 | in | clk_w | dato VDP |
| `vram_dout` | 16 | out | clk_54m→clk_w | palabra VDP |
| `vram_write` | 1 | in | clk_w | 1=escritura VDP (a BRAM) |
| `vram_addr` | **17** | in | clk_w | dir VRAM |
| `bus_rfsh_n` | 1 | in | clk_54m | refresh Z80 (ya no arma refresh SDRAM; la IP lo hace sola) |

Magic-ports SDRAM (`O_sdram_*`, `IO_sdram_dq`) **eliminados**.

## 2. Interfaz de usuario REAL de la DDR3 IP (ground truth)

De `IDE/ipcore/DDR3/data/ddr3_1_4code_hs/DDR3_TOP.v` (modo Controller `DDR3_PHY_MC`, ratio 1:4). **Corrige los nombres INCIERTOS de GW5A_IP §4.1.**

| Grupo | Señal | Dir | Nota |
|---|---|---|---|
| Reloj | `memory_clk` | in | reloj del PHY DDR3 (alta velocidad, de un PLL) |
| Reloj | `clk` | in | reloj de usuario de referencia |
| Reloj | **`clk_out`** | out | **reloj del dominio de la app** (= memory_clk/4 en 1:4) — la lógica DDR3-side corre aquí |
| Reloj | `pll_lock` | in | lock del PLL de memory_clk |
| Reloj | `pll_stop` | out | (no GW2A) |
| Reset | `rst_n` | in · `ddr_rst` out | |
| **Init** | **`init_calib_complete`** | out | **R/W PROHIBIDOS hasta =1** (calibración del PHY) |
| Comando | `cmd[2:0]` / `cmd_en` / **`cmd_ready`** | in/in/out | handshake de comando (READ/WRITE); válido cuando `cmd_ready` |
| Comando | `addr[ADDR_WIDTH-1:0]` | in | dir → rank/bank/row/col |
| Escritura | `wr_data[APP_DATA_WIDTH-1:0]` | in | dato (128b en 1:4/DQ16) |
| Escritura | `wr_data_en` / `wr_data_end` | in | válido / última ráfaga |
| Escritura | `wr_data_mask[APP_MASK_WIDTH-1:0]` | in | **máscara por byte** (16b) → escribir solo el byte MSX |
| Escritura | **`wr_data_rdy`** | out | la IP acepta dato de escritura |
| Lectura | `rd_data[APP_DATA_WIDTH-1:0]` | out | dato (128b) |
| Lectura | **`rd_data_valid`** | out | **dato válido SOLO aquí** (latencia variable) |
| Lectura | `rd_data_end` | out | última ráfaga |
| Refresh | `ref_req`/`ref_ack`, `sr_req`/`sr_ack`, `burst` | | opcional (auto-refresh interno por defecto) |
| Memoria | `O_ddr_*`, `IO_ddr_dq/dqs/dqs_n` | | a los pines DDR3 (hard-IP, sin IO_LOC) |

Anchos (1:4 + DQ 16): **APP_DATA_WIDTH=128**, **APP_MASK_WIDTH=16** (a confirmar en los params generados). Comando `cmd`: 0=WRITE / 1=READ (confirmar contra `DDR3_define.v`).

## 3. Relojes del subsistema DDR3

- La IP necesita **`memory_clk`** (alta velocidad) desde un PLL + su `pll_lock`. Frecuencia según el grado del chip DDR3 del SOM (JEDEC; el default del IP es Memory_Clock=200 = DDR3-400, el grado más lento). **CONFIRMAR el part del chip DDR3 de la Tang Mega 60K** para fijar timings/velocidad (referencia útil: `nand2mario/ddr3_framebuffer_gowin`, que ya corre DDR3 en esta placa).
- La IP entrega **`clk_out`** = dominio de la app (memory_clk/4 en 1:4). **La lógica DDR3-side del wrapper corre en `clk_out`.**
- **Frontera CDC 54↔clk_out**: como `clk_out` y el `clk_54m` del core salen de PLLs distintos (no alineados), el wrapper cruza con **CDC explícito** (handshake req/ack de 2FF o FIFO async pequeña) entre el dominio `ram_*` (54) y el dominio DDR3 (`clk_out`). El path CPU tolera los ~pocos ciclos extra vía `ram_busy` (requisito 2). *(Optimización posible: alimentar `memory_clk` desde el mismo Gowin_PLL y elegir ratio para que `clk_out`=54 exacto → eliminaría el CDC. Evaluar cuando se conozca la velocidad mínima del chip.)*
- `clk_108m`: con la VRAM en BRAM y la CPU en DDR3, **el core ya no usa 108 para memoria**. Se mantiene 108 en el árbol (turbo WSX ÷20, bus ÷30) pero el wrapper no lo necesita salvo como referencia.

## 4. Requisitos duros — cómo se satisfacen

- **Requisito 1 (MG2, "escritura VDP nunca se descarta")**: **satisfecho por construcción** — la VRAM es BRAM dual-port; `vram_write` escribe siempre, sin arbiter. Documentar: si algún día la VRAM va a DDR3, el arbiter CPU/VDP DEBE comprometer toda escritura VDP antes de liberar el slot (MEMORY_CONTRACT §c-Req1).
- **Requisito 2 (`ENABLE_WAIT_ADAPTIVE`)**: **obligatorio**. `top.v` debe definir `ENABLE_WAIT_ADAPTIVE` (top.v:9) y usar la rama que espera `ram_busy==0` (top.v:738). El wrapper genera `ram_busy` fiel: sube al aceptar `ram_req`, baja SOLO cuando el dato de lectura ha vuelto (`rd_data_valid` cruzado el CDC) o la escritura está comprometida (`wr_data_rdy`/`wr_data_end`). Con DDR3 la latencia es variable → sin este handshake, corrupción garantizada.

## 5. Camino de datos CPU (byte ↔ 128 bits)

- **Lectura**: emitir `cmd=READ`+`addr` (con `cmd_en`/`cmd_ready`); esperar `rd_data_valid`; de los 128 bits de `rd_data`, **seleccionar el byte** según `ram_addr[3:0]` (16 bytes por palabra de app). (Análogo a memory.v:420-433 que extraía 1 de 4 bytes de `SdrDat[31:0]`; ahora 1 de 16.)
- **Escritura**: emitir `cmd=WRITE`+`addr`; poner `wr_data` = el byte replicado en la lane correcta y `wr_data_mask` con **solo** el byte objetivo habilitado (los 15 restantes enmascarados) → read-modify-write innecesario. `wr_data_end` en la (única) ráfaga.
- **Direccionamiento**: `ram_addr[22:0]` (8 MB) → `addr` de la IP. Mapa de bancos actual (top.v:1389-1418: mapper 4MB A+B, megaram 2MB C, ROM/BIOS/kanji/disk D) se re-mapea al espacio DDR3 (512 MB, sobra). La VRAM (antes bank D) sale del mapa DDR3 (va a BRAM).

## 6. Arranque (nuevo vs SDRAM)

`init_calib_complete` gatea todo: el wrapper debe **retener el core** (no aceptar `ram_req`, mantener reset del subsistema RAM) hasta `init_calib_complete==1`. La VRAM/BRAM sí está disponible desde el principio. Encadenar `init_calib_complete` + `pll_lock` (del Gowin_PLL) + `clock_locked` en la cadena de reset de top.v.

## 7. Ajustes para GENERAR la DDR3 IP en el IDE

Como el PLL (ver CLOCK_PLAN §"Cómo generar"): `Tools ▸ IP Core Generator ▸ Soft IP Core ▸ Memory Control ▸ DDR3 Memory Interface`, device GW5AT-60B. Ajustes de partida:
- **User Interface = Controller** (la interfaz de §2).
- **CLK Ratio = 1:4** · **Memory Clock** = según el chip (empezar 200; subir si el chip lo pide).
- **Dq Width = 16** · **Dram Width = 8** (confirmar con el chip del SOM).
- **Row/Bank/Column** = según densidad del chip (default 14/3/10). **Burst = 8**, CAS/CW latency y timings JEDEC por defecto para el primer bring-up.
- Guardar en `MSX_up/fpga/ip/ddr3/` (o dentro del proyecto `msx_console60k/src/`).
- ⚠️ **Confirmar el part del chip DDR3 del SOM Tang Mega 60K** antes de fijar densidad/timings (afecta ROW/COL/BANK y Memory Clock).

## 8. Entregable RTL

`fpga/src/memory_ddr3.v` — **skeleton** del wrapper con: puertos core-side (§1) + instancia `DDR3_Memory_Interface_Top` (§2) + `dpram` VRAM (§0) + FSM CPU/CDC/pack (§5) marcados como TODO (la implementación fina se itera en simulación, testbench estilo `tools/megaram_equiv`). NO buildeable aún (faltan la IP DDR3 generada, el dpram y el top.v portado).

## 9. Pendientes / open
- [ ] Confirmar part del chip DDR3 del SOM (timings/densidad) — referencia `nand2mario/ddr3_framebuffer_gowin`.
- [ ] Confirmar presupuesto BRAM para 128 KB VRAM en GW5AT-60.
- [ ] Confirmar APP_DATA_WIDTH/APP_MASK_WIDTH/codificación `cmd` en los params generados.
- [ ] Decidir CDC explícito vs alinear `clk_out`=54 (memory_clk desde el Gowin_PLL).
- [ ] Testbench del wrapper (Icarus) reutilizando el patrón de `tools/megaram_equiv`.
