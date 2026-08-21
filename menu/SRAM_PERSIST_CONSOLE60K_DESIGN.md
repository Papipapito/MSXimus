# SRAM persistente (Console 60K) — Documento de diseño

**Estado: FASE DE DISEÑO, no implementación.** Target: **Tang Console 60K (GW5AT-60)**, no
el TN20K actual. Escrito a partir del RTL real del core MSXnano (`megaram.v`,
`flash_rw.v`, `top.v`) y de la investigación de persistencia previa. Ligado a
[[msx_msxnano_save_persistencia]], [[msx_tang_nano_60k]], [[msx_opl4_viabilidad]].

---

## 0. Resumen ejecutivo

Hoy la "SRAM de cartucho" del MSXnano (Koei / Hydlide 2 / A-Train, mappers ASCII8/16)
vive en la **SDRAM volátil** y **se pierde en cualquier reset o apagado**. No hay save
persistente escribible desde el cartucho.

Objetivo: en la Console 60K, que la SRAM sea **persistente de verdad** y que el usuario
tenga **un fichero por juego en la SD** (`<juego>.SRM`), portable y visible en el PC.

Por qué en la Console 60K y no en el TN20K: el TN20K está al **~89% CLS** y añadir la
FSM de commit + el arbitraje del backing store es riesgo de timing alto (el camino del
SCC ya dio regresión por timing en v1.7). La Console 60K (GW5AT-60, **DDR3 512 MB**, SD
y BL616 onboard, mucha más lógica) elimina esa presión y da holgura para hacerlo bien.

---

## 1. Estado actual (lo que ya existe en el core)

### 1.1 La SRAM emulada — `megaram.v`
- Solo en modos **ASCII8** (bancos 6000/6800/7000/7800) y **ASCII16** (6000/7000). En
  Konami4/SCC **no hay ninguna ruta de SRAM** (`megaram.v:230-288`).
- Vive en los **32 KB altos de la megaram**: segmentos **252-255**
  (`megaram_addr` 0x1F8000-0x1FFFFF), respaldados por **SDRAM banco C** (`top.v:1736`,
  `ram_addr = { 2'b10, megaram_addr[20:0] }`).
- Se habilita por el puerto **#43** → `config3_ff` → `sram_cfg` (`top.v:2012`, `:1747`):
  - ASCII8: `sram_en[n]` se activa si `(dato_banco & sram_cfg) != 0`; `sram_page` =
    `dato[1:0]` (Koei 32 KB = 4 páginas de 8 KB).
  - ASCII16: SRAM de 2 KB espejada, activa con el valor exacto `0x10`.
- El menú, al lanzar, **borra segs 252-255 a 0xFF** (cartucho virgen) — `menu_main.asm`
  bloque `.lr_sr*` (`launch_rom`). **Aquí es donde se insertará la carga desde SD.**
- **UI (par 19, ya hecho):** la opción SRAM del menú solo aparece/actúa en ASCII8/16
  (helper `.bsr_isascii`). Base para no ofrecer SRAM donde no la hay.

### 1.2 El motor de flash — `flash_rw.v`
- SPI NOR: `WREN 0x06`, **`SECTOR_ERASE 0x20` (4 KB)**, **`PAGE_PROGRAM 0x02` (≤256 B)**,
  `READ 0x03`, status `0x05`. Una invocación (`write_enable`) = WREN + borra el sector de
  `write_addr` + programa hasta 256 B, con el llamador cambiando `write_din` por
  `write_counter` y cerrando con `write_terminate`.
- En `top.v:2248-2270` está **cableado fijo** a `write_addr = 24'h280000` y solo vuelca
  los **6 bytes** del bloque de config (puerto #42 bit6, desbloqueo #40=0xB7). El reset
  (#42 bit7) **espera a `flash_write_busy==0`** (`top.v:2103`) — precedente exacto de
  "commit a flash y luego resetear".

### 1.3 La restricción de fondo (verificada en HW)
- **Todo lo que el Z80 escribe es volátil** (SDRAM) y **el reset la degrada** (re-stream
  de flash con refresh parado >64 ms → slot 2 lee 0xFF). El pack en flash @0x200000 es
  **solo-lectura** desde el Z80.
- Consecuencia: el menú **no puede** leer la SRAM "después" de jugar (ya decayó), y **no
  corre** mientras el juego corre. → **La flash es el puente obligatorio** entre el juego
  y la SD.

---

## 2. Qué cambia en la Console 60K

| Recurso | TN20K (hoy) | Console 60K (target) |
|---|---|---|
| FPGA | GW2AR-18 (~89% CLS) | **GW5AT-60** (mucha más lógica/BRAM) |
| RAM externa | SDRAM (volátil, decae en reset) | **DDR3 512 MB** (controlador propio) |
| Flash | SPI NOR (pack + config) | SPI NOR (idem, con hueco para saves) |
| SD | por dock / WonderTANG | **onboard** |
| Companion | BL616 (a veces externo) | **BL616 onboard** |

Implicaciones de diseño:
- **Holgura de lógica**: la FSM de commit + dirty-tracking + arbitraje caben sin apretar
  el fitter (el riesgo de timing que descarta hacerlo en TN20K desaparece).
- **DDR3**: la "megaram" y su SRAM pasan a DDR3. El controlador DDR3 (otra IP, distinta a
  la SDRAM del TN20K) es el gran bloque nuevo del port; el backing de la SRAM se define
  **sobre él** (o en BRAM dedicada, ver §3.1).
- **Puerto serio**: recordar que el port a la Console 60K ya implica cambiar familia FPGA
  y controlador de RAM; la SRAM persistente se diseña **como parte de ese port**, no como
  parche encima del TN20K.

---

## 3. Arquitectura de la persistencia

El bucle completo:

```
   juego  ──escribe SRAM──▶  backing store SRAM (32 KB)         [rápido, por-juego cargado]
                                     │
                                     │  (A) commit con debounce / on-demand
                                     ▼
                              FLASH: sector de save             [sobrevive al reset/apagado]
                                     │
                                     │  (B) el menú, en el siguiente arranque, lo lee
                                     ▼
                              <juego>.SRM en la SD              [persistente, portable, por-juego]
```
Y al lanzar: `<juego>.SRM ──(menú)──▶ backing store SRAM ──▶ el juego lo ve`.

### 3.1 Dónde vive la SRAM (backing store) — DECISIÓN
Dos opciones en la Console 60K:
- **(a) BRAM dedicada de 32 KB** para segs 252-255 (en vez de DDR3). **Recomendada.**
  - Pros: no compite con el arbitraje DDR3 (VDP/CPU/megaram); lectura para el commit es
    trivial (puerto B del BRAM dual-port); latencia determinista; **no decae** (BRAM se
    puede preservar a través del reset del Z80 sin depender del refresh).
  - Contra: 32 KB de BRAM (barato en el GW5AT-60).
- **(b) Seguir en DDR3** (banco equivalente al C actual). Pros: cambio mínimo respecto al
  mapeo actual. Contra: el commit debe **leer DDR3** arbitrando con el resto → más
  complejo y con el mismo problema conceptual de decay si el reset reinicializa DDR3.

→ **Recomendación: (a) BRAM dedicada.** Aísla la SRAM del decay y del arbitraje, que son
las dos causas raíz del problema en TN20K. `megaram.v` seguiría generando `sram_addr`
igual, pero el `sram_hit` enruta a la BRAM en vez de a `megaram_addr` de DDR3.

### 3.2 Mecanismo de commit (SRAM → flash) — DECISIÓN
El commit debe ocurrir **mientras el juego corre** (después no se puede). Opciones:
- **(a) Auto-commit con debounce (recomendada):** el core marca `dirty` en cada escritura
  a la ventana SRAM; tras **~1-2 s sin escrituras** (juego quiescente tras guardar),
  vuelca los 32 KB → flash. Debounce = clave para la **vida de la flash** (borra 8 sectores
  de 4 KB + 128 páginas de 256 B por commit; a lo sumo una vez por evento de guardado).
- **(b) On-demand por trigger:** combo de tecla (detectado por el BL616 companion) →
  "guardar ahora". Perfil de wear mínimo y explícito, pero requiere que el usuario sepa
  el combo y actúe.
- **(c) Ambos:** auto-commit debounced + trigger manual de respaldo.

→ **Recomendación: (a) + (c) opcional.** Auto-commit debounced como base; el trigger
manual como red de seguridad.

FSM de commit (reusa `flash_rw.v`, ahora con `write_addr` dinámico):
1. Detectar quiescencia (contador que se resetea con cada `megaram_wrt` en `sram_hit`).
2. Para cada uno de los 8 sectores de 4 KB del área de save: `SECTOR_ERASE` + 16×
   `PAGE_PROGRAM` de 256 B leyendo del backing store (BRAM puerto B).
3. Bloquear el reset mientras `flash_write_busy` (ya existe el gate en `top.v:2103`).
4. Marcar `clean`.

### 3.3 Destino en flash — layout
- El pack vive @0x200000; el config @0x280000. **Reservar un área de save** por encima
  (p.ej. **0x290000**, N sectores de 4 KB). 32 KB = 8 sectores. (Confirmar tamaño real de
  la flash de la Console 60K y el mapa libre en el port.)
- **Una sola ranura en flash** = la SRAM "actual". El **multi-juego** se resuelve en la
  SD (§3.5): la flash es solo el puente que cruza el reset; el menú mueve flash ↔ el
  `.SRM` del juego concreto.

### 3.4 Recarga en arranque (flash → SRAM)
- El streamer de arranque (el que copia el pack de flash a la RAM externa) copia también
  el **área de save → BRAM SRAM** (segs 252-255). Así, con solo esto, la SRAM ya es
  persistente entre apagados **aunque no toquemos la SD**.
- Añadir un **magic/checksum** en el área de save para distinguir "vacía" (0xFF → cargar
  0x00 o 0xFF virgen) de "válida".

### 3.5 Interfaz con el menú — el fichero `.SRM` en la SD (lo que pidió el usuario)
- El core expone el área de save **también en una ventana legible** para el Z80 (p.ej. el
  streamer la deja en una zona de la megaram/DDR3 que el menú puede leer), y acepta que
  el menú **escriba** esa ventana + dispare un commit (import).
- **Menú, flujo de save (export):** en el arranque, si el área de save está "dirty desde
  la última sincronización" (flag), el menú lee los 32 KB y escribe/actualiza
  `<juego>.SRM` en la SD (nombre derivado del último juego lanzado — guardar el nombre en
  el bloque de config o junto al save).
- **Menú, flujo de load (import):** al lanzar un juego ASCII8/16, si existe `<juego>.SRM`
  en la SD, el menú lo lee → escribe la ventana SRAM → (commit a flash) → lanza. En vez
  del actual "borrar segs 252-255 a 0xFF".
- **Multi-juego:** un `.SRM` por juego en la SD; la flash solo tiene el del juego en curso.
- Reusa el escritor FAT del menú (ya al ~80% por File-Hunter) y el lector de sector SD.

---

## 4. Alcance de mappers y el modo Game Master 2

### 4.1 Fase primero: ASCII8/16
La SRAM emulada actual es ASCII8/16. La persistencia se construye sobre ese mecanismo
existente. **Primera entrega = persistir la SRAM ASCII8/16** (Koei, Hydlide 2, A-Train).

### 4.2 Modo Game Master 2 (Konami) — fase 2, ligada a esto
Verificado: **el core NO emula el Konami Game Master 2** (mapper distinto: bancos
6000/8000/A000 + **bit 4 = select SRAM**, bit 5 = página; SRAM de 8 KB). MG2 corre en modo
**SCC**, donde no hay ninguna ruta de SRAM → un MG2 parcheado para fingir GM2 **cuelga**
(pokes ignorados + cerrojo de escritura → bucle de verificación).

Para soportarlo:
- **Añadir un modo GM2 a `megaram.v`**: como los 4 valores de `map_sel` ya están usados
  (00 Konami4, 10 SCC, 01/11 ASCII8/16), hace falta un **bit de config nuevo** (otro
  puerto SWIO, análogo a #43/#44) que active "SRAM estilo GM2" sobre la ruta Konami/SCC:
  interpretar bit 4 del registro de banco como select-SRAM y bit 5 como página, mapeando a
  los mismos segs 252-255 (8 KB usados). En la Console 60K el riesgo de timing (que lo
  desaconseja en TN20K, camino crítico del SCC) es asumible.
- La SRAM del GM2 **entra en el mismo sistema de persistencia** (§3): mismo backing store,
  mismo commit, mismo `.SRM`.
- **Alternativa sin core** (documentada, no recomendada como general): parche MG2→SRAM
  ASCII8 lanzando MG2 en modo ASCII8 — pero pierde el SCC del juego (sonido) → inaceptable.

→ **GM2 = fase 2**, después de que ASCII8/16 persistente esté validado, reusando toda la
infraestructura.

---

## 5. Plan por fases (con validación HW)

- **F0 — Port base a Console 60K** (prerrequisito, fuera de este doc): core corriendo en
  GW5AT-60 con controlador DDR3, SD onboard, BL616. Sin esto no hay nada.
- **F1 — SRAM en BRAM dedicada:** mover segs 252-255 de la RAM externa a una BRAM de
  32 KB. Validar: los juegos ASCII8/16 (Koei/Hydlide2/A-Train) guardan y **la SRAM
  sobrevive a un reset suave** (ya no decae). Criterio: A-Train guarda, reset, la partida
  sigue.
- **F2 — Auto-commit a flash + recarga en frío:** FSM de commit debounced + el streamer
  recarga el área de save al arrancar. Validar: guardar, **apagar del todo**, encender →
  la partida persiste (sin SD todavía). Vigilar wear/tiempo de commit.
- **F3 — Fichero `.SRM` en la SD (menú):** export/import flash ↔ `<juego>.SRM`. Validar:
  el `.SRM` aparece en el PC; copiar/borrar/compartir funciona; multi-juego.
- **F4 — Trigger manual de save (opcional):** combo por el BL616 companion.
- **F5 — Modo Game Master 2 (Konami):** nuevo bit de config + ruta SRAM GM2 en
  `megaram.v`; MG2 parcheado guarda de verdad. Validar: MG2 guarda y recarga; sin
  regresión en MG2/SCC normales.

---

## 6. Riesgos y preguntas abiertas

1. **Controlador DDR3** de la Console 60K: bloque nuevo y grande; toda esta feature asume
   F0 resuelto. La SRAM en BRAM (§3.1a) reduce el acoplamiento con DDR3.
2. **Vida de la flash**: el debounce y el commit-por-evento son obligatorios; cuantificar
   ciclos de borrado por sesión de juego. ¿Wear-leveling en el área de save o basta con
   asumir N sectores rotando?
3. **Nombre del `.SRM`**: ¿derivar del nombre del ROM lanzado? ¿Dónde se guarda ese nombre
   para el export en el siguiente arranque (bloque de config en flash)?
4. **Tamaño y mapa de la flash** en la Console 60K: confirmar hueco libre por encima de
   config para el área de save.
5. **GM2 en `megaram.v`**: el nuevo bit de config y la interacción con el SCC (que MG2
   usa a la vez) hay que diseñarlos con cuidado aunque el timing ya no apriete.
6. **Momento del export SD**: hacerlo en el arranque del menú (tras un reset) implica que
   el usuario debe volver al menú para materializar el `.SRM`. ¿Aceptable, o se quiere un
   export "en caliente" vía companion? (F4).

---

## 7. Referencias de código

- `fpga/src/megaram.v` — SRAM ASCII8/16 (`:230-288`), `sram_hit`/`sram_addr` (`:88-109`),
  segs 252-255.
- `fpga/src/flash_rw.v` — motor SPI (erase 0x20 `:336`, program 0x02 `:427`).
- `fpga/top.v` — megaram (`:1736`), `sram_cfg=config3_ff` (`:1747`, `:2012`), flash
  cableada a 0x280000 (`:2248-2270`), reset gated por flash (`:2103`), commit config
  (#42 bit6 `:2048`).
- `fpga/src/msxnano_menu/src/menu_main.asm` — `launch_rom` bloque `.lr_sr*` (borra segs
  252-255; aquí va la carga desde SD), UI SRAM gated a ASCII (`.bsr_isascii`, par 19).
- `fpga/src/msxnano_menu/M2_DESIGN.md` — acceso SD por sector, reconfig+reset (#40/#41/#42).
