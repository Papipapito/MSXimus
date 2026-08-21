# M2 — "Lanzar ROM de la SD" — Documento de diseño (FASE DE DISEÑO, no implementación)

Objetivo M2: que la opción 2 del menú boot navegue la tarjeta SD (carpetas + ficheros
`.ROM`), liste paginado (~19/pág estilo Picoverse), y al elegir una: autodetecte el
mapper (Konami/SCC, ASCII8/16, plain 16K/32K/48K), cargue la ROM en la
megaram/mapper y arranque dentro de ella (idealmente con SD/Nextor desactivados para
máxima compatibilidad, como Picoverse).

Este documento es el resultado de **investigar los building blocks reales** del repo
(rama `menu`) y proponer la arquitectura más viable. No se ha escrito firmware todavía.

---

## 1. Hallazgos por building block (con ficheros / líneas / puertos concretos)

### 1.1 Acceso a la SD — SOLO vía la disk-ROM (Nextor), NO hay puerto I/O raw

Fichero clave: `fpga/top.v`, bloque `ifdef ENABLE_SDCARD` (líneas ~1953–2229), más
`fpga/src/wondertang/sd_reader.sv` y `sdcmd_ctrl.sv`.

- El hardware SD **NO se expone por puertos I/O Z80**. Se expone como una **ventana de
  memoria mapeada DENTRO del slot de la disk-ROM**:
  - `SD_SLOT = 3` (parámetro top, línea 16), subslot expandido **2** (`exp_slotx_num[2]`).
  - Registros en página 1 del slot, direcciones `0x7C00–0x7EFF` (top.v 2044–2058):
    - `SDC_SDATA = 0x7C00` (512 bytes, área de transferencia de sector — un dpram dual-port, top.v 2101–2118).
    - `SDC_ENABLE = 0x7E00` (wo: 1=habilita registros SDC).
    - `SDC_CMD = 0x7E01` (wo: bit0=read sector, bit1=write, bit7=init).
    - `SDC_STATUS = 0x7E02` (ro: bit7=busy, crc/timeout).
    - `SDC_SADDR = 0x7E03..06` (wo: nº de sector LBA, 32 bits).
    - + tamaño de tarjeta, CID/CSD, etc.
  - **Doble compuerta de habilitación** (top.v 2097, 2161, 2168):
    `config_enable_sdcard == 1` **Y** `ff_sd_en == 1` (set escribiendo `0x7E00`)
    **Y** `pri_slot_num[SD_SLOT]==1 && exp_slotx_num[2]==1`.
    Es decir: para tocar la SD por hardware hay que **tener paginado el subslot 3-2
    en página 1** y haber escrito el enable.

- `sd_reader.sv`: host SPI que inicializa la tarjeta (SDv1/v2/SDHC) y lee/escribe **un
  sector de 512 bytes** por comando (`rstart`+`rsector`→`outen/outaddr/outbyte`).
  Es acceso **por sector raw (LBA)** — perfecto para un lector FAT propio — pero el
  único camino hacia él es la ventana de memoria del slot de la disk-ROM.

- **Importante para "antes del SO"**: el menú corre en el INIT del cartucho (slot 3-1
  pág1, INIT 0x4760) ANTES de MSX-DOS/Nextor. Para leer la SD por hardware desde el
  menú habría que **paginar manualmente el subslot 3-2 en página 1** (manipular PPI
  0xA8 + el byte de subslot expandido en 0xFFFF), escribir 0x7E00=1, y hacer
  transferencias de sector. Es factible (el HW está vivo desde el reset), pero implica
  reimplementar el "driver SD + FAT" que Nextor ya tiene.

- Alternativa vía la disk-ROM: la disk-ROM Nextor del pack expone los puntos de entrada
  estándar de disco (DSKIO/DSKCHG/GETDPB) en su cabecera. Llamar DSKIO directamente
  desde el INIT es posible en teoría pero frágil (requiere DPB/workarea inicializados);
  no es el camino recomendado (ver riesgos §4).

**Conclusión 1.1**: hay acceso por sector raw (LBA) usable, pero **solo a través de la
ventana de memoria de la disk-ROM** (no por puertos I/O independientes). No existe un
"puerto SD" que el menú pueda usar trivialmente sin paginar el slot de Nextor.

### 1.2 Megaram / mapper — bancos, puertos y cómo "cargar ROM y ejecutar como cartucho"

Ficheros: `fpga/src/megaram.v` (lógica de banking) + `fpga/top.v` (mapeo a SDRAM y
puertos de config).

- **Megaram (2 MB, SCC)** — `megaram_scc` (top.v 1496–1512, megaram.v):
  - Respaldada por **SDRAM banco C**: `ram_addr = { 2'b10, megaram_addr[20:0] }`
    (top.v 1243). Es **RAM escribible por la CPU** (`megaram_wrt`, top.v 1272).
  - Modos seleccionables por `map_sel` (=`Slot2Mode`) y `map_linear` (=`iSlt2_linear`),
    que vienen de los **switched-I/O ports OCM** (`switched_io_ports`, top.v 2255–2273;
    seleccionables por puerto 0x40..0x4F vía `io42_id212`). Modos implementados en
    megaram.v: **Konami SCC** (banks 5000/7000/9000/B000), **ASCII8** (6000/6800/7000/7800),
    **ASCII16** (6000/7000), y **lineal** (`map_linear`, mapea 0000–FFFF directo).
  - Ubicación por defecto: slot **3-3** (`config_megaram_slot=2'b11`, top.v 1710).
    Relocable a slots 1/2 desde el menú de ajustes (`config1_ff[7:6]`).

- **Mapper ASCII (4 MB)** — top.v 1143–1197:
  - Respaldado por **SDRAM bancos A+B**: `ram_addr = { 1'b0, mapper_addr[21:0] }` (top.v 1236).
  - Es el mapper de RAM estándar MSX (puertos 0xFC–0xFF, segmentos de 16K). Pensado
    como RAM mapeada del sistema, no como "cartucho ROM".

- **Cómo se ejecuta una imagen como cartucho**: la megaram ES RAM (banco C de la
  SDRAM). El patrón Picoverse/SofaRun es: **escribir la imagen .ROM en la megaram**
  (a través de su ventana de banking o del modo lineal), configurar el modo de mapper
  correcto, y **resetear el MSX** con la megaram habilitada en un slot. Al reiniciar,
  la BIOS escanea slots, encuentra la "ROM" (en realidad RAM precargada) con su
  cabecera `AB`+INIT y arranca dentro de ella.
  - **No hay un mecanismo HW dedicado de "carga ROM y resetea dentro"**: se compone de
    (a) escritura CPU→megaram + (b) el bit de reset de config (§1.3). El "pegamento"
    es software.

**Conclusión 1.2**: la megaram (2 MB, banco C) es RAM escribible por CPU con banking
Konami/ASC8/ASC16/lineal ya implementado en HW. Es exactamente el destino donde
escribir la imagen .ROM y dejar que la BIOS la arranque tras un reset. No hay
"load+run" atómico en HW; se construye con escritura + bit de reset.

### 1.3 Reset / modo compatible — puertos OCM 0x40–0x42

Fichero: `fpga/top.v`, bloque `ifdef ENABLE_CONFIG` (1585–1746); uso real en
`menu_main.asm` (`selected_saveReset`, líneas 851–861, y `config_var2byte`).

- **Desbloqueo**: escribir `0x40 = 0xB7` activa `config_ok` (top.v 1686). Sin esto,
  #41/#42 no responden. (El menú usa `out (#40), #48` para hablar con el "device
  Goauld"; el 0xB7 es el id que habilita el banco config — ver `config0_ff <= ~cpu_dout`,
  top.v 1626, y `config_ok=(config0_ff==0xB7)`.)
- **#41** (`config1_ff`): bit0=mapper enable, bit1=megaram enable, bit2=ghost SCC,
  bit3=scanlines, bits5,4=mapper slot, bits7,6=megaram slot.
- **#42** (`config2_ff`): bit0=SD enable, bits2,1=SD slot, **bit3=`config_enable_wait`
  (modo compatible / wait extra en MREQ)** (top.v 1692), **bit6=guardar config en
  flash**, **bit7=RESET** (top.v 1639–1641 → `config_reset_ff` → `config_reset` →
  fuerza `bus_reset_n=0`, top.v 214).
- El menú ya hace exactamente esto en `selected_saveReset` (menu_main.asm 851):
  `out(#40),#48` → `in a,(#42)` → `or #C0` (bit7 reset + bit6 save) → `out(#42),a`.
  **Es decir, el HW de "reconfigura + resetea" ya está probado y en uso.**
- **Para "arrancar dentro de la ROM con SD/Nextor OFF"**: antes de pulsar el reset,
  poner #42 bit0=0 (SD disable) y #41 con megaram enable=1 en el slot deseado y
  mapper=0 (o lo que la ROM requiera). Tras el reset, la BIOS arrancará y, sin la
  disk-ROM acaparando, la megaram precargada se ejecuta como cartucho.
  - Matiz: deshabilitar la SD (#42 bit0=0) quita la disk-ROM Nextor del slot 3-2. Eso
    es justo lo que se quiere para "máxima compatibilidad" (igual que Picoverse, que
    arranca el juego sin disk-ROM residente).
  - `config_enable_wait` (modo compatible, #42 bit3) puede activarse para juegos
    sensibles a velocidad.

**Conclusión 1.3**: el ciclo "reconfigurar slots + resetear" está implementado y
probado (mismo path que `selected_saveReset`). Se puede arrancar con SD/Nextor OFF y
megaram ON poniendo los bits de #41/#42 antes del reset.

### 1.4 Espacio — el menú de 16 KB (0x4760–0x8000) NO basta para M2

Estado actual (menu.asm, menu_main.asm):
- La ROM `fm_logo_menu` es de **16 KB** y vive en SDRAM `0x76c000` mapeada en slot 3-1
  página 1 (subrom+logo+menu; ver mapa SDRAM en top.v 1209–1232 y los `*_req` 988–1006).
- El INIT está en `0x4760`; el código del menú se **descomprime (zx0) a 0x8000** (página 2,
  RAM) y se ejecuta ahí (menu.asm 22–38, menu_main.asm `.org #8000`).
- Ya hay ~8 KB de código en `menu_main.asm` (config menu + main menu + lector de teclado
  por matriz). Un navegador de SD + parser FAT + detección de mapper + cargador no cabe
  sumado a lo existente dentro del presupuesto de 16 KB de la ROM de menú.

Opciones de espacio evaluadas:
- **(a) Segunda etapa cargada en RAM / megaram**: el menú actual ya descomprime a 0x8000.
  Se puede ampliar el blob comprimido (más código de M2) mientras quepa comprimido en la
  ROM de 16 KB y descomprimido en RAM. Límite: la RAM de página 2/3 disponible y el
  tamaño comprimido. Viable para un navegador modesto; ajustado para FAT completo +
  detección + carga.
- **(b) ROM de menú más grande (megarom/banking)**: el HW tiene un mecanismo de
  **megarom paginado** en el slot SD (top.v 1957–1982): `megarom_page` se selecciona
  escribiendo `0x6000`, páginas de 16 KB desde SDRAM banco D (`0x740000`, la "wondertang
  disk", 128 KB). Reutilizar esa zona como ROM de menú multi-banco daría hasta 128 KB,
  pero choca con que esa zona es la disk-ROM/Nextor y requeriría rehacer el mapa de
  SDRAM y la build del BIOS pack. Mayor esfuerzo en HW + build.
- **(c) Ejecutar bajo MSX-DOS**: dejar que el boot llegue a Nextor (como hace
  "Arrancar sistema") y lanzar un **.COM navegador propio** desde la SD. El .COM tiene
  64 KB de TPA y la FAT de Nextor disponible: espacio de sobra. Es la opción de la
  arquitectura B (§3).

**Conclusión 1.4**: dentro de la ROM de 16 KB no cabe M2 completo. (a) sirve para un
navegador pre-SO reducido con esfuerzo alto; (c) elimina el problema de espacio por
completo a costa de pasar por el SO.

### 1.5 SofaRun — la prueba de que "load ROM→run" YA funciona en este HW

`README.md` 111–112:
> "Megaram is detected automatically by sofarun using default settings. When using
> other software you may need to indicate location, Slot 3-3 by default."

- SofaRun (de NYYRIKKI) es un **lanzador MSX-DOS** que: lee ROM/DSK de la SD usando el
  sistema de ficheros del SO (Nextor/FAT), **copia la imagen a la megaram/mapper**,
  autodetecta el mapper, y **resetea el MSX dentro de la imagen** (deja un pequeño
  stub residente que sobrevive al reset y re-arranca el contenido).
- En este HW funciona con la **megaram en slot 3-3 por defecto** — exactamente la
  megaram de 2 MB descrita en §1.2, con el bit de reset de §1.3.
- **Implicación de diseño**: el camino "FAT→megaram→reset→ejecutar" es viable en este
  hardware y ya está demostrado por software de terceros. La arquitectura B (§3) es
  esencialmente "hacer lo que SofaRun hace", o incluso **invocar SofaRun** desde el menú.

---

## 2. Tabla resumen de building blocks

| Bloque | Dónde | Estado para M2 |
|---|---|---|
| SD por sector (LBA) | `sd_reader.sv`; ventana `0x7C00–0x7EFF` en slot 3-2 (top.v 2044–2229) | Usable, pero solo paginando el slot de la disk-ROM + doble enable |
| FAT / sistema de ficheros | Nextor 2.1 (en el BIOS pack) | Disponible **solo bajo MSX-DOS**; no en el INIT |
| Megaram 2 MB (destino ROM) | `megaram.v`, SDRAM banco C (top.v 1243, 1496) | RAM escribible, banking Konami/ASC8/ASC16/lineal listo |
| Mapper 4 MB | top.v 1143–1197, SDRAM banks A+B | RAM mapeada del sistema |
| Reconfig + reset | puertos #40=0xB7/#41/#42, bit7 reset (top.v 1639, 214) | **Probado** (selected_saveReset) |
| Modo compatible (wait) | #42 bit3 → `config_enable_wait` (top.v 1692) | Disponible |
| Descompresor a RAM | zx0, `menu.asm` (descomprime a 0x8000) | Listo; ampliable |
| Lector teclado fiable en INIT | matriz PPI 0xAA/0xA9 (menu_main.asm 247–371) | **Probado** (la ISR de BIOS NO es fiable en INIT) |
| Lanzador ROM→megaram→run | SofaRun (3rd party, README 111) | **Demuestra viabilidad bajo DOS** |

---

## 3. Dos arquitecturas concretas

### Arquitectura A — Navegador PRE-SO en el cartucho

**Idea**: ampliar el menú (segunda etapa en RAM) para que, sin arrancar el SO, lea la SD
por sector, parsee la FAT por su cuenta, liste carpetas/.ROM, y al elegir: cargue la
imagen en la megaram, configure el mapper, deshabilite SD/Nextor y resetee.

**Flujo**:
1. El usuario elige opción 2 → segunda etapa del menú toma control (aún en INIT, sin SO).
2. Paginar slot 3-2 en página 1 (PPI 0xA8 + subslot 0xFFFF), `out 0x7E00,1` (SD enable HW).
3. Driver SD propio: leer MBR/VBR → parsear FAT16/FAT32 → listar dir raíz y subdirs.
4. Render paginado (~19/línea) con el lector de teclado por matriz ya existente.
5. Al elegir: leer el fichero .ROM por clusters → escribir en megaram (banco C) vía su
   ventana de banking o modo lineal; detectar mapper por heurística (tamaño + firmas
   `AB` + patrones de escritura a 0x5000/0x6000/0x7000/0x9000).
6. Configurar #41 (megaram ON en slot, mapper OFF), #42 (SD OFF, modo compatible si
   procede), y disparar reset (#42 bit7). Dejar la megaram persistente (es SDRAM, no se
   borra en reset). La BIOS re-arranca dentro de la ROM.

**Viabilidad real en este HW**: ALTA en lo eléctrico (el HW SD y la megaram están vivos
desde el reset). El reto es 100% software: reimplementar driver SD + FAT16/FAT32 +
navegación + detección + carga en muy poco espacio.

**Esfuerzo**: ALTO. FAT32 + subdirectorios + cadenas de clusters + LFN es mucho código
asm. Hay que reutilizar/portar un lector FAT (p.ej. el de Picoverse RP2040 es en C para
otro core; aquí sería Z80 asm). Riesgo de no caber en RAM/ROM.

**Espacio**: requiere segunda etapa grande (driver SD ~1–2 KB, FAT ~3–5 KB, UI ~2 KB,
detección+carga ~2 KB). Probablemente exige (a) blob comprimido grande o (b) megarom
multi-banco (rehacer mapa SDRAM/BIOS build).

**Pros**:
- Experiencia "consola": SD-browser instantáneo al encender, sin pasar por DOS.
- Más fiel a Picoverse (arranque limpio, sin disk-ROM residente).
- Control total del momento del reset y de la config de slots.

**Contras / riesgos** (incluye los problemas vistos en M1):
- **Remapeo de página 2 en contexto de cartucho** (documentado en menu_main.asm 198–212):
  la segunda etapa vive en 0x8000; al paginar el slot 3-2 en página 1 y mover datos hay
  que tener cuidadísimo con qué hay en cada página y con el stack (página 3). El bug de
  M1 (variables en página 2 leídas como basura tras remapeo) es exactamente la clase de
  fallo que acecha aquí, multiplicado.
- **ISR de teclado no fiable en INIT**: ya resuelto con matriz directa (reutilizable), OK.
- Reimplementar FAT es propenso a bugs (FAT32, clusters grandes, fragmentación).
- Mantener compatibilidad con tarjetas (SDHC ya soportado por sd_reader, bien).

### Arquitectura B — Navegador bajo MSX-DOS (.COM propio, estilo SofaRun)

**Idea**: la opción 2 deja que el boot llegue a **Nextor/MSX-DOS** (igual que "Arrancar
sistema") y autoejecuta un **.COM navegador propio** (o directamente SofaRun) que usa la
FAT de Nextor para listar, y carga la ROM en la megaram + reset, como hace SofaRun.

**Flujo**:
1. Opción 2 → el menú escribe en flash/var un flag "lanzar navegador" y hace el mismo
   `ret` limpio a la BIOS que "Arrancar sistema" (menu_main.asm 213–219).
2. Nextor arranca MSX-DOS. Un `AUTOEXEC.BAT` (o un command interpreter custom) ejecuta
   `NANOROM.COM` (nuestro navegador) — o `SOFARUN.COM`.
3. `NANOROM.COM` corre en TPA (64 KB): usa llamadas FAT de Nextor (FIB/búsqueda/lectura)
   para listar carpetas y .ROM con UI paginada.
4. Al elegir: lee el .ROM con file I/O del SO, lo escribe en la megaram, detecta mapper,
   configura #41/#42 (SD OFF, megaram ON, modo compatible si procede) y resetea (#42 bit7).
5. La BIOS re-arranca dentro de la ROM (megaram persiste en SDRAM tras el reset).

**Viabilidad real en este HW**: MUY ALTA — **ya demostrada** por SofaRun (README 111).
Nextor + megaram en 3-3 + bit de reset = camino conocido y funcionando.

**Esfuerzo**: BAJO/MEDIO. Si se reutiliza SofaRun: casi nulo (solo cablear el autoarranque
desde la opción 2). Si se hace .COM propio: medio, pero con FAT y file I/O "gratis" del
SO; el grueso es UI + detección + escritura a megaram + reset (lo mismo que en A pero sin
driver SD ni parser FAT).

**Espacio**: NO es problema. 64 KB de TPA. La ROM de menú de 16 KB solo necesita el
"ret a la BIOS + flag de autoarranque".

**Pros**:
- Robusto y probado (FAT/SD de Nextor, maduro; SDHC, FAT32, LFN, subdirs ya resueltos).
- Mínimo riesgo de los bugs de paginación/stack de M1 (el .COM corre en entorno DOS
  normal, no en INIT de cartucho).
- Reutilizable: SofaRun ya hace exactamente esto; un .COM propio puede pulir la UX.
- Detección de mapper de SofaRun ya es muy buena (años de heurísticas).

**Contras / riesgos**:
- Pasa por el SO: arranque más lento (carga Nextor + DOS) — pero solo cuando se elige
  "Lanzar ROM", no en el arranque normal.
- Menos "limpio" que pre-SO; depende de Nextor estar presente y configurado.
- Autoejecutar el .COM requiere preparar la SD (AUTOEXEC / archivo de arranque) o un
  truco para encadenar tras el `ret`.
- La detección de mapper hay que mantenerla nosotros si NO usamos SofaRun.

---

## 4. RECOMENDACIÓN: **Arquitectura B** (navegador bajo MSX-DOS)

**Por qué**:
1. **Ya está probado en este HW exacto** (README: SofaRun detecta la megaram en 3-3 y
   lanza ROMs). El riesgo técnico es el más bajo posible: el camino FAT→megaram→reset
   está validado por software de terceros sobre esta misma core.
2. **Evita los dos fantasmas de M1**: el remapeo de página 2 en contexto de cartucho y
   la fragilidad del INIT. Un `.COM` corre en MSX-DOS con memoria/stack normales.
3. **Esfuerzo y espacio**: el navegador pre-SO (A) exige reimplementar driver SD + FAT16/
   FAT32 + LFN en Z80 asm dentro de un presupuesto de RAM/ROM apretadísimo. B obtiene
   FAT y file I/O "gratis" del SO y dispone de 64 KB de TPA.
4. **Reutilización**: se puede empezar invocando SofaRun (esfuerzo casi nulo) para tener
   M2 funcional ya, y después escribir `NANOROM.COM` propio para la UX Picoverse
   (paginado ~19, estética del menú) reutilizando la detección/carga.

**Camino incremental sugerido (no implementar aún)**:
- **M2.0**: opción 2 → `ret` a BIOS + autoarranque de `SOFARUN.COM` desde la SD →
  navegador y lanzamiento ya funcionales. Valida todo el flujo HW.
- **M2.1**: `NANOROM.COM` propio con UI estilo Picoverse (paginado 19/pág, mismo look),
  usando FAT de Nextor, escribiendo a megaram y reseteando con #41/#42.
- **M2.2** (opcional, futuro): si se quiere arranque pre-SO "de consola", portar el
  navegador a una segunda etapa pre-SO (Arquitectura A) reutilizando la detección de
  mapper ya escrita en M2.1.

La Arquitectura A queda como objetivo "premium" futuro, no como primer entregable.

---

## 5. Lo que haría falta (checklist) y formato de índice

### Para Arquitectura B (recomendada)
- **Mecanismo de autoarranque del .COM** tras la opción 2:
  - Opción simple: documentar que la SD debe tener `SOFARUN.COM`/`NANOROM.COM` +
    `AUTOEXEC.BAT` que lo lance; la opción 2 solo hace `ret` a la BIOS.
  - Opción mejor: que la opción 2 escriba un flag (en var RAM no volátil al reset, o en
    el byte de config) y que un pequeño residente/command lo detecte y autoejecute.
    → **Pregunta abierta**: ¿cómo encadenar el .COM sin tocar la SD del usuario?
- **API Nextor/MSX-DOS a usar**: funciones FAT estándar (FFIRST/FNEXT/OPEN/READ, fnc 0x40+),
  o la API extendida de Nextor para LFN. No hace falta FAT propio.
- **Rutina de carga a megaram**: escribir la imagen por la ventana de banking de la
  megaram (modo lineal `iSlt2_linear` para copiar directo, o banco a banco). Definir el
  slot de megaram (3-3 por defecto) y los bits #41.
- **Detección de mapper**: tamaño (16K/32K/48K plain) + firmas de escritura
  (0x6000/0x6800/0x7000/0x7800 → ASCII8; 0x6000/0x7000 → ASCII16; 0x5000/0x7000/0x9000/
  0xB000 + "SCC" → Konami SCC; 0x4000/0x8000/0xA000 → Konami sin SCC). Si se usa SofaRun,
  ya la trae.
- **Secuencia de reset**: replicar `selected_saveReset` (menu_main.asm 851): #40=0xB7
  desbloqueo (aquí `#48` device), set #41 (megaram ON/slot, mapper OFF), #42 (SD OFF,
  bit3 compat opcional, **sin** bit6 flash a menos que se quiera persistir), bit7 reset.
- **Formato de índice de ROMs**: **no hace falta índice** — se navega la FAT en vivo. Si
  se quiere acelerar, un `.idx` opcional con rutas+mappers cacheados; pero MVP navega
  directorios reales.

### Para Arquitectura A (si se aborda en el futuro)
- Driver SD propio sobre la ventana `0x7C00–0x7EFF` (paginado de slot 3-2 + 0x7E00 enable
  + comandos `SDC_CMD`/`SDC_SADDR`/`SDC_SDATA`).
- Parser **FAT16 + FAT32** (BPB, cadena de clusters, dir raíz + subdirs, 8.3 mínimo, LFN
  opcional).
- Gestión rigurosa de páginas/stack para no repetir el bug de página 2 de M1.
- Segunda etapa grande → resolver espacio (blob comprimido mayor o megarom multi-banco).

---

## 6. Preguntas abiertas para el usuario

1. **¿Reutilizar SofaRun o escribir navegador propio?** SofaRun da M2 casi gratis y
   probado; propio da la UX Picoverse exacta pero más trabajo. ¿Empezamos por SofaRun
   (M2.0) y luego propio (M2.1)?
2. **Autoarranque del .COM**: ¿es aceptable requerir que la SD del usuario tenga un
   `AUTOEXEC.BAT`/`.COM` en la raíz, o prefieres que el firmware lo gestione de forma
   transparente (flag + residente)? Esto condiciona cuánto código va en la ROM de menú.
3. **Slot de megaram**: ¿fijamos megaram en 3-3 (default, lo que SofaRun espera) o
   permitimos que M2 lo configure dinámicamente según el mapper detectado?
4. **Modo compatible (#42 bit3) al lanzar**: ¿activarlo siempre para juegos, dejarlo como
   estaba, u ofrecer un toggle por-ROM en la UI?
5. **Persistencia**: al lanzar una ROM, ¿queremos volver al menú tras resetear el MSX, o
   que el reset entre directo en la ROM (sin disk-ROM)? (Afecta a si dejamos un residente.)
6. **Alcance de mappers en M2.1**: ¿basta Konami/SCC/ASCII8/ASCII16/plain (cubre la
   mayoría) o hay que cubrir mappers exóticos (R-Type, Cross Blaim, etc.)?
7. **¿Interesa a medio plazo el navegador pre-SO (Arquitectura A)** como modo "consola", o
   con B es suficiente?
