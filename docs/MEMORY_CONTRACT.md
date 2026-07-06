# MEMORY_CONTRACT.md — Contrato de la interfaz de memoria a preservar en el port SDRAM → DDR3

**Proyecto**: MSXnano — port Tang Nano 20K (Gowin GW2AR-18C, SDRAM integrada) → Tang Console 60K (SOM Tang Mega 60K = Gowin GW5AT-60, DDR3 512MB).
**Fuente**: copia limpia de `dev` en `C:/Users/alber/proyectosAI/msx/_MSXnano_dev_ref`.
**Regla**: todo anclado a `file:line` real. Lo no confirmado va marcado **INCIERTO**.
**Base de la auditoría**: `fpga/AUDIT_PRE_PORT_60K.md` §5.A1 (findings A1, requisito MG2, requisito waits adaptativos).

Ficheros leídos íntegros o en las secciones citadas:
- `fpga/src/memory.v` (módulo `memory_ctrl`, completo, 1–464)
- `fpga/top.v` (magic ports 69–79; instancia `memory_ctrl` 1463–1493; mapa de bancos 1389–1418; FSM de waits 680–756; aviso 886–887; instancia VDP y wires VRAM 1244–1303)
- `fpga/src/megaram.v` (`megaram_scc`, interfaz + `ff_scc_mode`/`ff_sram_mode` 41–48/92–97, completo)
- `fpga/tn_vdp_v3_v9958/src/v9958_top.v` (puertos VRAM 47–53; instancia VDP 297–322)

---

## 0. Corrección de nomenclatura (dato duro, no inventar dominios)

El módulo `memory_ctrl` declara un puerto llamado `clk_27m` (`memory.v:3`), **pero top.v lo alimenta con `clk_54m`**:

```
memory.v:3     input wire clk_27m,
top.v:1464     .clk_27m(clk_54m),
```

Por tanto **el secuenciador de acceso CPU/VDP (`sdram_seq`, `memory.v:62`) corre a 54 MHz**, no a 27. El nombre del puerto es engañoso (herencia del diseño previo). El segundo dominio, el motor de comandos SDR crudo (`ff_sdr_seq`, `memory.v:153–462`), corre a **108 MHz** (`clk_108m`). El enunciado de la tarea dice "@27MHz" para el handshake; **eso es INCORRECTO según el código**: el handshake `ram_req`/`ram_busy`/`ram_dout` vive en el dominio **`clk_54m`**. Se documenta así en la tabla. (El "27" real del sistema es otro reloj usado en el resto del top; no toca esta interfaz.)

Los strobes `video_dhclk`/`video_dlclk` (`memory.v:6–7`) los produce el core VDP (`v9958_top.v:52–53` → `PVIDEODHCLK`/`PVIDEODLCLK` de la instancia `VDP` en `v9958_top.v:321–322`), en el dominio del reloj de píxel del VDP (`clk_w`, `v9958_top.v:115/298`, ~21.48 MHz). El secuenciador de 54 MHz los muestrea como entradas asíncronas de fase para alinear cada acceso a la ventana de vídeo.

---

## (a) Tabla signal-level: interfaz a preservar como frontera estable

Frontera = los puertos del módulo `memory_ctrl` **que NO son magic-ports SDRAM**. Los magic-ports SDRAM (`O_sdram_*`, `IO_sdram_dq`) **desaparecen** en el port (no existen en GW5AT-60) y se sustituyen por la IP DDR3; todo lo demás debe sobrevivir byte-a-byte para que `top.v` no cambie.

| # | Señal | Ancho | Dir (vista del ctrl) | Dominio de reloj | Semántica / timing (anclaje) |
|---|-------|-------|----------------------|------------------|------------------------------|
| 1 | `clk_27m` (mal llamado) | 1 | in | — (es el reloj) | **Realmente clk_54m** (top.v:1464). Reloj del secuenciador de acceso `sdram_seq` (memory.v:62). PRESERVAR nombre de puerto para no tocar top.v. |
| 2 | `clk_108m` | 1 | in | — (es el reloj) | Reloj del motor de comandos SDR (memory.v:153). En SDRAM = `O_sdram_clk` (memory.v:37). En DDR3 será el reloj del user-side de la IP (probablemente distinto; INCIERTO hasta la IP). |
| 3 | `bus_reset_n` | 1 | in | async / clk_54m | Reset activo-bajo del secuenciador (memory.v:63) y del contador de init (memory.v:159,179). |
| 4 | `video_dhclk` | 1 | in | clk_w (VDP ~21.48MHz) | Strobe de fase de vídeo alto. Gate de arranque de acceso (memory.v:75) y avance del pipeline SDR (memory.v:449,454). |
| 5 | `video_dlclk` | 1 | in | clk_w (VDP ~21.48MHz) | Strobe de fase de vídeo bajo. Selecciona **CPU vs VDP** en el slot (memory.v:220–221: `video_dlclk==0`→CPU, `==1`→VDP) y arma el fin de fase (memory.v:88). |
| 6 | `ram_din` | 8 | in | clk_54m | Dato de escritura CPU. top.v lo duplica: `{cpu_dout,cpu_dout}` o `{rom_dout,rom_dout}` (top.v:1461). Se replica ×4 al bus SDR de 32 bits (memory.v:377). |
| 7 | **`ram_req`** | 1 | in | clk_54m | **Petición de acceso CPU/ROM/mapper/megaram**. Nivel: se muestrea en `sdram_seq==0` junto a las dos fases de vídeo altas (memory.v:75). Se libera el estado con `ram_req==0` (memory.v:101). Mux de origen en top.v:1445–1459. |
| 8 | `ram_write` | 1 | in | clk_54m | 1 = la petición es escritura; 0 = lectura (memory.v:83, muestreado en seq 1 → `sdram_write`). Origen top.v:1438–1443. |
| 9 | `ram_addr` | 23 | in | clk_54m | Dirección CPU en el espacio de 8 MB (`[22:0]`). Bancos por prefijo de bits (memory.v:337 usa `[22:21]` como banco; mapa en top.v:1389–1418). Latcheada en seq 1 (memory.v:82). |
| 10 | `vram_din` | 8 | in | clk_w (VDP) | Dato de escritura VDP = `VrmDbo` (top.v:1474). Replicado ×4 al bus SDR (memory.v:380). |
| 11 | `vram_write` | 1 | in | clk_w (VDP) | 1 = ciclo VDP es escritura = `~WeVdp_n` (top.v:1475). **Clave del fix MG2** (memory.v:204,225). |
| 12 | `vram_addr` | **17** | in | clk_w (VDP) | Dirección VRAM = `VdpAdr` (`[16:0]`, top.v:1476). `[16]` = byte alto/bajo (memory.v:304–305); `[15:11]`→fila (memory.v:340); `[10:0]`+`[15:11]`→columna (memory.v:340,359). **NO son 16 bits: son 17.** |
| 13 | `bus_rfsh_n` | 1 | in | clk_54m (Z80) | Refresh Z80 activo-bajo. Habilita robar el slot para refresh SDRAM **solo si el VDP va a leer** (memory.v:204). |
| 14 | `ram_dout` | 8 | out | clk_54m | Dato leído CPU. Latcheado en seq 3 (memory.v:96 ← `RamDbi`). Consumido por el mux de bus de top.v:573–601. |
| 15 | `vram_dout` | **16** | out | clk_54m (cruza a clk_w) | Palabra leída VDP → `VrmDbi2` (top.v:1480), realimentada al core como `VrmDbi` (top.v:1299). 16 bits porque el VDP lee palabra (memory.v:440). |
| 16 | **`ram_busy`** | 1 | out | clk_54m | **Handshake de ocupación**. Sube al aceptar la petición (memory.v:77), baja al tener el dato (memory.v:98). **Hoy top.v lo IGNORA en el camino normal** (ver §c). |

**Magic-ports SDRAM (NO frontera — se eliminan en el port):** `O_sdram_clk/cke/cs_n/ras_n/cas_n/wen_n` (1 c/u), `IO_sdram_dq` [31:0], `O_sdram_addr` [10:0], `O_sdram_ba` [1:0], `O_sdram_dqm` [3:0]. Declarados en memory.v:22–32 y top.v:69–79. Se sustituyen por la interfaz user-side de la IP DDR3. **INCIERTO**: qué ancho de datos/dirección expone la IP DDR3 de Gowin (lo define el otro agente).

---

## (b) Comportamiento del secuenciador — dos FSMs acopladas

### FSM-A: secuenciador de acceso `sdram_seq` (dominio clk_54m, memory.v:62–110)
Máquina de 5 estados que serializa **una** transacción CPU y publica el handshake:

- **seq 0** (idle): si `ram_req==1` **y** ambas fases de vídeo altas (`video_dlclk==1 && video_dhclk==1`, memory.v:75) → sube `ram_busy` y pasa a seq 1. Espera a la ventana de vídeo para no pisar al VDP.
- **seq 1**: latchea `sdram_addr<=ram_addr`, `sdram_write<=ram_write`, arma `enable_sdram` (memory.v:81–84).
- **seq 2**: mantiene `enable_sdram`; espera a que **ambas fases caigan** (`video_dlclk==0 && video_dhclk==0`, memory.v:88) → limpia write y pasa a seq 3.
- **seq 3**: latchea `ram_dout<=RamDbi` y **baja `ram_busy`** (memory.v:96–98).
- **seq 4**: espera `ram_req==0` para volver a seq 0 (memory.v:101) — evita re-disparar la misma petición.

### FSM-B: motor de comandos SDR de 8 fases `ff_sdr_seq` (dominio clk_108m, memory.v:446–462)
`ff_sdr_seq` es un contador de 3 bits (0→7) sincronizado a la ventana de vídeo: arranca (0→1) cuando `video_dhclk==1` (memory.v:449) y vuelve a 0 cuando `video_dhclk==0` (memory.v:454); en medio incrementa libre. En cada fase emite el comando SDRAM crudo y las direcciones/máscaras:

- El **estado de acceso** `SdrSta` (3 bits, memory.v:187–228) se decide en `ff_sdr_seq==7`: init (idle/precharge/refresh/mode-set según `RstSeq`), **refresh oportunista** si `bus_rfsh_n==0 && video_dlclk==1 && vram_write==0` (memory.v:204), o acceso normal (`SdrSta[2]=1`). Bit 1 = CPU(0)/VDP(1) según `video_dlclk`; bit 0 = write, tomado de `sdram_write` (CPU) o `vram_write` (VDP) (memory.v:220–226).
- **Comandos** (memory.v:230–264): fase 0 → ACTIVATE (o NOP/PRE/REF/MRS en init); fase 2 → READ/WRITE con **auto-precharge** (`SdrAdr[10]=1`, memory.v:346).
- **Dirección de fila/columna** (memory.v:322–364): CPU usa `sdram_addr` con banco `[22:21]`; VDP usa `vram_addr` con banco fijo `2'b11` (bank D, memory.v:341). Mapa de bancos en top.v:1389–1400: mapper 4MB (A+B), megaram 2MB (C), VRAM/BIOS/kanji/disk (D).
- **Máscaras de byte** `SdrDqm` (memory.v:266–320): seleccionan el byte dentro de la palabra de 32 bits según `sdram_addr[1:0]` (CPU) o `vram_addr[16]` (VDP).
- **Latch de lectura** (memory.v:392–443): tras el pipeline, `RamDbi` toma el byte correcto de `SdrDat` según `sdram_addr[1:0]` (CPU, memory.v:420–433) y `vram_dout` toma la palabra completa (VDP, memory.v:437–443).

**Propiedad emergente (el contrato real)**: latencia **determinista** — exactamente **1 acceso CPU + 1 acceso VDP por slot de vídeo**, sin colas ni reordenamiento. El init SDRAM (precharge/refresh/mode-set) está codificado en `RstSeq` (memory.v:178–185, ~3 ms) y se ejecuta una sola vez; en DDR3 lo hace la IP y **este bloque de init se descarta**.

---

## (c) Los DOS requisitos duros del port

### Requisito 1 — "toda escritura VDP aceptada se COMPLETA" (fix MG2)
Anclaje: `memory.v:204–213` (comentario) + `memory.v:225`.

El refresh oportunista **solo** roba el slot del VDP cuando este va a **leer** (`bus_rfsh_n==0 && video_dlclk==1 && vram_write==0`, memory.v:204). Si el VDP va a **escribir** (`vram_write==1`), el refresh NUNCA se cuela: el VDP da ACK incondicional y la escritura **debe** materializarse. Si el arbiter DDR3 pudiera descartar/posponer una escritura VDP ya aceptada (por refresh, por cola llena, por prioridad), **reaparece el bug "agujeros en VRAM"** (glitch MG2 al cambiar de pantalla; ver MEMORY.md #22). 

**Traslado**: NO es código a traducir, es una **invariante de diseño**: en el wrapper DDR3, cualquier escritura VDP presentada (`vram_write=1`) tiene que quedar comprometida antes de liberar el slot; el refresh/arbitraje solo puede robar ciclos de **lectura** VDP (recuperables al frame siguiente).

### Requisito 2 — `ENABLE_WAIT_ADAPTIVE` obligatorio con DDR3 (no es optimización)
Anclaje: `top.v:9` (`` `define `` comentado = rama dormida), `top.v:680` (`` `ifndef ENABLE_WAIT_ADAPTIVE ``, rama activa hoy), `top.v:717–755` (rama adaptativa dormida), `top.v:886–887` (el propio código lo avisa).

Hoy, con SDRAM de **latencia fija y conocida**, los wait-states son de **duración FIJA sin handshake**: la FSM activa (memory.v/top.v:680–715) libera con los pulsos `clk_enable_3m6_54`/`clk_falling_3m6_54` y **nunca mira `ram_busy`**. El aviso está en el código: *"NO ram_busy handshake yet, so if HW shows corruption during active display, add the handshake (dormant ENABLE_WAIT_ADAPTIVE)"* (top.v:886–887).

La rama dormida `ENABLE_WAIT_ADAPTIVE` (top.v:717–755) **sí** consulta `ram_busy`: en `WAIT_STATE2` espera `ram_busy==0 && clk_enable_3m6_54==1` (top.v:738) antes de soltar el wait. Con DDR3 la latencia es **variable** (refresh, apertura de fila, colas): sin este handshake, la CPU leería antes de que el dato esté → **corrupción garantizada**.

**Traslado**: activar/portar la rama `ENABLE_WAIT_ADAPTIVE` como **requisito del port** (definir `ENABLE_WAIT_ADAPTIVE` en top.v:9), NO tocar/borrar esa rama en la limpieza, y **exponer `ram_busy` fiel desde el wrapper DDR3** (subir al aceptar, bajar solo cuando el dato de lectura esté válido). Nota de diseño: la rama adaptativa usa un contador fijo de 6 (`wait_cycles<=7'd6`, top.v:727) **antes** del gate por `ram_busy`; con DDR3 conviene revisar ese 6 o dejar que domine el `ram_busy` (INCIERTO hasta conocer la latencia peor-caso de la IP).

---

## (d) Recomendación de partición DDR3 — **PRELIMINAR** (pendiente de la IP DDR3)

> **PRELIMINAR**: la elección definitiva depende de datos que aporta el otro agente (ancho del bus user-side de la IP DDR3 de Gowin, latencia de lectura peor-caso, si la IP admite múltiples puertos/AXI o un solo puerto, granularidad de burst, y si hay puerto de baja latencia). Sin eso, lo de abajo es una recomendación razonada, no una decisión cerrada.

### Recuento de lo que hoy vive en SDRAM (memoria de vídeo + código)
De top.v:1389–1400 (mapa SDRAM de 8 MB):
- **VRAM**: 256 KB, bank D (`11111xx…`, top.v:1391). Accedida por el VDP a cadencia de píxel, con el requisito duro de "escritura nunca descartada".
- **mapper**: 4 MB, banks A+B (top.v:1400).
- **megaram**: 2 MB, bank C (top.v:1399).
- **BIOS/subrom/kanji/disk/esp/logo**: ~resto de bank D.

### Opción 1 — VRAM en BRAM del GW5A, resto (mapper+megaram+ROMs) en DDR3  ← **recomendada (preliminar)**
- **Pros**:
  - La VRAM son **256 KB** (top.v:1391). El GW5AT-60 tiene BRAM de sobra (**INCIERTO el total exacto**; la auditoría afirma "sobra", AUDIT §5.A1 L84). 256 KB de BRAM dedicada da a la VRAM **latencia fija de 1 ciclo** y ancho de banda dedicado.
  - **Disuelve el Requisito 1** casi por completo: si la VRAM es BRAM de doble puerto, la escritura VDP no compite jamás con refresh ni con la CPU → el fix MG2 deja de depender del arbiter. Es la forma más robusta de honrar "escritura VDP nunca se descarta".
  - Quita del bus DDR3 el tráfico más sensible a latencia (el VDP no tolera stalls durante display activo), dejando DDR3 para accesos que **sí** toleran el handshake `ram_busy` (CPU/mapper/megaram).
  - El `vram_dout` de 16 bits y `vram_addr` de 17 bits mapean natural a un dpram 64K×16 (o 128K×8) en BRAM.
- **Contras**:
  - Hay que instanciar un dpram y **replicar el mapeo byte/palabra** que hoy hace memory.v (memory.v:304–305, 340, 359, 437–443). Trabajo RTL nuevo, pero acotado.
  - Consume BRAM que podría querer otro subsistema (**INCIERTO** hasta el presupuesto de BRAM del diseño completo en GW5A).
  - Dos controladores de memoria (BRAM-VRAM + DDR3-CPU) en vez de uno → la lógica de arbitraje del slot vídeo (memory.v:75,88) se simplifica pero se duplica la frontera.

### Opción 2 — Todo (VRAM + mapper + megaram + ROMs) en DDR3, un solo controlador
- **Pros**:
  - Un único wrapper detrás de la interfaz `ram_*`/`vram_*` → top.v cambia menos.
  - Aprovecha los 512 MB: sobra espacio para todo con margen enorme.
- **Contras**:
  - **Ancho de banda / latencia**: DDR3 tiene latencia **variable** (apertura de fila, refresh interno del propio DDR3, colas). El acceso VDP durante display activo es el más intolerante; meterlo en DDR3 obliga a **garantizar** por diseño que cada acceso VDP cabe en su slot pese al refresh DDR3 — justo el punto donde el bug MG2 puede reaparecer "con otra cara" (AUDIT §5.A1 L85).
  - El refresh del DDR3 es **autónomo de la IP** y puede caer en cualquier ciclo → hay que asegurar que no colisiona con la ventana VDP, cosa que hoy el código controla explícitamente (memory.v:204) y que con DDR3 dejas en manos de la IP.
  - Depende críticamente de que la IP ofrezca latencia/ancho de banda suficientes para 2 accesos (CPU+VDP) por slot de vídeo a ~21.48 MHz de cadencia de píxel; **INCIERTO** sin el datasheet de la IP.

### Razonamiento de ancho de banda (preliminar)
El slot de vídeo hoy garantiza **1 acceso CPU + 1 acceso VDP** por ventana (§b). A cadencia de píxel del VDP (~21.48 MHz), eso es del orden de decenas de MB/s por flujo — trivial para DDR3 en pico, **pero** el problema no es el caudal medio sino la **latencia peor-caso acotada** del acceso VDP: un DDR3 con refresh puede introducir stalls de decenas de ciclos justo cuando el VDP necesita el dato. Sacar la VRAM a BRAM elimina esa variable del flujo crítico. Por eso la **Opción 1** es la recomendación preliminar: minimiza el riesgo del Requisito 1 y concentra la latencia variable de DDR3 donde el handshake `ram_busy`/`ENABLE_WAIT_ADAPTIVE` (Requisito 2) ya la absorbe (CPU).

### Qué necesita confirmar el agente de la IP DDR3 para cerrar la decisión
1. Total de BRAM del GW5AT-60 y presupuesto libre tras el diseño completo (¿caben 256 KB de VRAM?). **INCIERTO**.
2. Latencia de lectura peor-caso de la IP (con refresh) y si hay modo/puerto de baja latencia.
3. Si la IP expone múltiples puertos (p.ej. AXI multi-master) que permitan dar prioridad dura al flujo VDP dentro de DDR3 (habilitaría una Opción 1.5: VRAM en DDR3 pero en puerto prioritario).
4. Ancho del bus user-side y granularidad de burst (afecta a cómo se replica el mapeo byte/palabra de memory.v).

---

## Resumen de anclajes clave
- Handshake CPU: `ram_req` (memory.v:75), `ram_busy` (memory.v:77,98), `ram_dout` (memory.v:96), dominio **clk_54m** (top.v:1464).
- VRAM: `vram_addr` **17b** (top.v:1476, v9958_top.v:48), `vram_din` **8b** (top.v:1474), `vram_dout` **16b** (top.v:1480, memory.v:440), `vram_write` (top.v:1475).
- Fix MG2 (Requisito 1): memory.v:204–213, 225.
- Waits fijos sin handshake (Requisito 2): top.v:680–715 (activo), 717–755 (dormido), aviso 886–887, define 9.
- Magic-ports a eliminar: memory.v:22–32, top.v:69–79.
- Mapa de bancos: top.v:1389–1418.
