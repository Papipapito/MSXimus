# Port SDR de `memory.v`: 32-bit (SDRAM embebida GW2AR) → 16-bit (W9825G6KH externo)

**✅ CIRUGÍA APLICADA Y VERIFICADA EN SIMULACIÓN** (`tools/sdr16_tb/`, Icarus 12 en WSL: **ALL TESTS PASS** — init real precharge/refresh/MRS, lanes, DQM, 600 accesos aleatorios, words VDP, aliasing de geometría, MG2/refresh). La FSM y el contrato `ram_*`/`vram_*` NO cambiaron; solo el frente físico + mapeo byte/palabra + geometría.

## Geometría (implementada)

| | 32-bit (original, embebida) | 16-bit (W9825G6KH) |
|---|---|---|
| Bus datos | `IO_sdram_dq[31:0]` (4 bytes) | `[15:0]` (2 bytes) |
| DQM | `[3:0]` (HU/HL/U/L) | `[1:0]` (U/L) |
| Byte-en-palabra | `sdram_addr[1:0]` (1 de 4) | **`sdram_addr[0]`** (1 de 2) |
| Bus dir | `SdrAdr[10:0]` (11) | **`SdrAdr[12:0]`** (13) |

**Mapeo GEOMETRÍA-PRESERVANTE (el implementado — sustituye a la propuesta inicial de este doc):** el bit `sdram_addr[1]`, que antes elegía la mitad alta/baja del word de 32 bits (lanes HU/HL vs U/L), pasa a ser el **LSB de COLUMNA**. Cada word de 32b original = 2 columnas de 16b adyacentes → **la biyección dirección→celda física y la geometría de colisión CPU↔VRAM del banco D quedan IDÉNTICAS al diseño original** (VRAM en columnas pares de la región `3'b111`; lo que vivía en HU/HL vive ahora en las columnas impares). Cualquier patrón de direcciones que no colisionaba antes sigue sin colisionar.

- **CPU**: bank=`addr[22:21]` · row=`{2'b00, addr[12:2]}` (mismos bits que el original) · col=`{addr[20:13], addr[1]}` · byte=`addr[0]`
- **VDP**: bank=`2'b11` · row=`{2'b00, vram[10:0]}` · col=`{3'b111, vram[15:11], 1'b0}` · byte=`vram[16]`

> La propuesta inicial de este doc (row=`addr[20:10]`, col=`addr[9:1]`) era funcionalmente correcta pero **cambiaba la geometría de colisión del banco D** (donde conviven VRAM y BIOS/kanji/disk). Descartada por eso; el test T6 del testbench verifica la geometría implementada.

## Hallazgos de implementación (importantes para el resto del port)

1. **Idioma de lectura del bus era Gowin-mágico**: el original hacía `assign IO_sdram_dq = SdrDat` (con `SdrDat<=z` en lecturas) y luego **leía el reg `SdrDat`** para capturar el dato — solo funciona porque Gowin lo mapea al pad de la SDRAM *embebida*. Con chip externo por GPIO (GW5A) y en cualquier simulador eso lee `z`. **Fix aplicado**: tristate explícito `dq_oe` + `wire dq_in = IO_sdram_dq`, y los latches leen `dq_in`. Portable a cualquier toolchain.
2. **Doble latch fases 5+6 = tolerancia CL2/CL2+pad-register**: el latch de lectura dispara en las fases 5 **y** 6. En fase 6 el chip ya no conduce (BL=1 + DQM read-latency) → el bus retiene el valor por capacidad (igual que en el TN20K). Si el IOB del GW5A añade un registro de entrada, la fase 6 lo cubre. El modelo del testbench emula la retención (conduce 1 ciclo extra).
3. **Initializers de registros** (`ff_mem_seq`, `ff_sdr_seq`, `SdrSta`, `SdrCmd`, DQM, latches): sin ellos la simulación se bloquea en X (el contador Johnson nunca sale de XX). Añadidos = power-up real de Gowin (0). Misma higiene que la auditoría pide para `kanji.v` — **aplicar el patrón al resto de módulos cuando se porten**.
4. **CKE sin pin**: el módulo Tang SDRAM ata CKE alto en placa (el .cst de C64Nano no lo tiene). `O_sdram_cke` queda sin constraint.

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
