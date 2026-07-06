# Port SDR de `memory.v`: 32-bit (SDRAM embebida GW2AR) → 16-bit (W9825G6KH externo)

Spec de la cirugía. Base: `fpga/src/memory.v` (copiado de `dev`, aún en 32 bits). Objetivo: mismo controlador SDR, bus de 16 bits, para el módulo Tang SDRAM (1× W9825G6KH, 16b, 32 MB) por GPIO del slot SDRAM1 del Console 60K. **La FSM y el contrato `ram_*`/`vram_*` NO cambian.** Solo el frente físico + el mapeo byte/palabra + la geometría.

> ⚠️ **Verificar en simulación (Icarus) antes de confiar** — patrón `tools/megaram_equiv` + un modelo conductual del W9825. Los bit-slices de abajo son la propuesta; el testbench los valida.

## Geometría

| | 32-bit (actual, embebida) | 16-bit (W9825G6KH) |
|---|---|---|
| Bus datos | `IO_sdram_dq[31:0]` (4 bytes) | `[15:0]` (2 bytes) |
| DQM | `[3:0]` (HU/HL/U/L) | `[1:0]` (U/L) |
| Byte-en-palabra | `sdram_addr[1:0]` (1 de 4) | **`sdram_addr[0]`** (1 de 2) |
| Bus dir | `SdrAdr[10:0]` (11) | **`SdrAdr[12:0]`** (13) |
| Filas / Cols | 11 / 8 | **13 / 9** (8192×512×4banks) |
| Palabra dir | `sdram_addr[22:2]` | `sdram_addr[22:1]` |

**Mapeo CPU** (preservando el banco = `sdram_addr[22:21]`, que fija el mapa mapper/megaram/VRAM de top.v:1389-1418):
- Byte: `sdram_addr[0]` (0=`SdrDat[7:0]`, 1=`SdrDat[15:8]`)
- Bank: `sdram_addr[22:21]`
- Row (13b): `{2'b00, sdram_addr[20:10]}` (11 usados → 2 MB/banco × 4 = 8 MB)
- Col (9b): `sdram_addr[9:1]`

**VDP**: ya trabaja en 16 bits (`vram_dout <= {SdrDat[15:8],SdrDat[7:0]}`, byte por `vram_addr[16]`) → **casi sin cambios**; solo la geometría de fila/col del banco D (`vram_addr`).

## Cambios por bloque (memory.v)

1. **Puertos (29-32)**: `IO_sdram_dq[15:0]`, `O_sdram_addr[12:0]`, `O_sdram_dqm[1:0]`.
2. **Assigns DQM (44-49)**: quitar `[3]`/`[2]`; `O_sdram_dqm[1]=SdrUdq`, `[0]=SdrLdq`. Borrar `SdrHUdq`/`SdrHLdq`.
3. **Regs (120-123)**: borrar `SdrHUdq`/`SdrHLdq`; `SdrAdr[12:0]`; `SdrDat[15:0]`.
4. **DQM logic (266-320)**:
   - seq 000 / 011: `SdrUdq<=1; SdrLdq<=1;` (quitar HU/HL).
   - seq 010 CPU (`video_dlclk==0`): quitar el `if(sdram_addr[1])` (medio de 32b); dejar `SdrUdq<=~sdram_addr[0]; SdrLdq<=sdram_addr[0];`.
   - seq 010 VDP: `SdrUdq<=~vram_addr[16]; SdrLdq<=vram_addr[16];` (igual).
5. **Address (322-364)**:
   - Mode register (327): pad a 13b → `SdrAdr <= {2'b00, 3'b010,1'b0,3'b010,1'b0,3'b000};` (CL=2, BL=1 — mismo valor, 2 bits altos = reservado 0). ⚠️ confirmar mode-register del W9825 (A9 write-burst).
   - Row CPU (336): `SdrAdr <= {2'b00, sdram_addr[20:10]};` (13b). Bank (337): `sdram_addr[22:21]` (igual).
   - Row VDP (340): `SdrAdr <= {2'b00, vram_addr[...]}` — re-cuadrar la fila del banco D a 13b desde `vram_addr` (VRAM 128KB → 16-bit word addr `vram_addr[16:1]`). Bank D `2'b11` (igual).
   - Col (346-360): `SdrAdr[8:0] <= col[8:0]` (9b); `SdrAdr[10]<=1` (auto-precharge A10); CPU col = `sdram_addr[9:1]`, VDP col según `vram_addr`.
6. **Data write (366-388)**: `SdrDat` a 16b; replicación ×4→**×2**: CPU `{ram_din, ram_din}` (377), VDP `{vram_din, vram_din}` (380); tristate `16'hzzzz` (370,386).
7. **Read latch CPU (420-433)**: mux 4→**2**: `RamDbi <= sdram_addr[0] ? SdrDat[15:8] : SdrDat[7:0];`.
8. **Read latch VDP (437-443)**: `vram_dout <= SdrDat[15:0];` (igual).

## Físico (CST/SDC, no RTL)
- Magic-ports embebidos → **GPIO general**: IOBUF/OEN para `IO_sdram_dq` (el RTL ya pone Hi-Z), `IO_TYPE=LVCMOS33 DRIVE=8` en el CST (pines de C64Nano; los 5 de control ya puestos, faltan addr/dq/ba/dqm — copiar del `.cst` de C64Nano).
- **`O_sdram_clk` por pin GPIO con skew controlado** = el punto delicado a 108 MHz por header. Si hay problemas de integridad: bajar la frecuencia SDR o forwarding con fase. Constraint SDC del reloj SDRAM nueva.
- **CL a la frecuencia elegida**: el -5 admite CL2 hasta ~133 MHz; a 108 MHz OK. Revisar `ff_sdr_seq_5/6` (latencias de latch) si se cambia CL/frecuencia.

## Verificación (gate antes de HW)
1. Testbench Icarus: modelo conductual del W9825G6KH + `memory_ctrl` reworked; comprobar CPU read/write (los 2 bytes), VDP read/write (palabra), refresh, y el requisito MG2 (escritura VDP no descartada). Correr en WSL (`msx_msxnano_simulacion`).
2. Diff de comportamiento contra el 32-bit (mismos accesos lógicos → mismos datos).
3. Build Gowin GW5AT-60 (resource + timing) tras integrar CST/SDC.
