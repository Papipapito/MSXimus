# 10. Auditoría externa de septiembre de 2026: verificación y plan

El 21 de septiembre de 2026 llegaron cuatro informes de auditoría estática hechos por otra IA sobre los repositorios públicos: `MSXimus_audit.md` (60K), `MSXnano_audit.md`, `INFORME_MAESTRO_AUDITORIA.md` (consolidado de los dos) y `AUDITORIA-COMPLETA.md` (repositorio de la bios y los packs). En total 137 hallazgos, contando por separado los que el informe maestro atribuye a "ambos" proyectos.

Este capítulo dice cuáles son ciertos, cuáles no y por qué, y qué se hace con cada uno. Cada hallazgo se contrastó contra el árbol local con fichero y línea; los tres marcados como críticos se sometieron además a un modelo de ciclos (`bridge_cdc_model.py`, RTL del puente literal, dos relojes de 85,909 y 74,25 MHz, 1200 combinaciones de fase y 480.000 operaciones).

## 1. Resultado en una tabla

| | Confirmado | Parcial | Ya arreglado | Estilo | No aplica | Refutado |
|---|---:|---:|---:|---:|---:|---:|
| MSXimus (60K) | 0 | 1 | 11 | 10 | 7 | 19 |
| MSXnano | 2 | 7 | 0 | 34 | 2 | 11 |
| bios y packs | 8 | 6 | 3 | 7 | 3 | 6 |

Los tres "críticos" y los diez "altos" del informe maestro quedan en **cero defectos disparables en placa**. Lo que sí acierta el informe de la bios son ocho cosas pequeñas de documentación y herramientas, ninguna de ellas de código del menú ni de los packs.

Significado de las columnas: *confirmado* = defecto real con un disparador concreto; *parcial* = algo cierto pero con la severidad o el arreglo equivocados; *ya arreglado* = corregido en el árbol antes del informe; *estilo* = cierto como descripción, sin efecto para el usuario; *no aplica* = el fichero o la ruta no entra en el bitstream de producción; *refutado* = falso.

## 2. Por qué se equivoca tanto el informe del MSXimus

No son errores sueltos: hay seis patrones que se repiten y conviene conocer para leer cualquier auditoría futura.

1. **Leyó `top.v` tal cual y creyó que la producción es el V9958.** Los `define` del V9968 y de la VRAM en DDR3 van comentados en el fuente y los activa `tools/lanzar_campana.ps1` en el clon antes de sintetizar (el propio `top.v` lo avisa en sus primeras líneas). De ahí salen los hallazgos sobre `v9958_top.v`, el "camino muerto" de `audio_sample` (que es el audio HDMI de las dos ramas) y el `casex` de FSM que la síntesis poda.
2. **Comparó ficheros del nano y dijo "persiste" sin abrir los del MSXimus.** `sd_reader.sv`, `flash_rw.v`, `YM2149.vhdl`, `dpram.v` y `pinfilter.v` divergieron hace semanas: reintentos acotados, CRC de lectura, token de escritura, espera de WIP con timeout, carga síncrona de la envolvente, `1 << n`. La tabla "solo el 22 % arreglado" del informe maestro sale de ahí.
3. **Trató relojes del mismo PLL como cruces asíncronos.** `clk_27m`, `clk_54m` y `clk_108m` son salidas del mismo `pll_main` y van en el mismo grupo del SDC: el STA cronometra esos caminos y el gate los vigila. Un sincronizador de dos etapas ahí no evita ninguna metaestabilidad y sí desalinearía cosas validadas (la cadencia del turbo, la ventana del refresco).
4. **Confundió asignaciones bloqueantes con carreras.** Dentro de un solo `always` secuencial el orden es determinista. Donde una variable se relee tras escribirse (`counter_demux` antes del `casex`, el `dw` del entrenador de stride del PCM, los temporales `lo_now`/`hi_now` del shim) el `=` es intencionado y pasarlo a `<=` **cambia el comportamiento** y rompería cosas validadas en placa. Donde no se relee, `=` y `<=` dan el mismo flop.
5. **No vio el Save & Restart.** Los bits de slot de mapper y SD de los puertos 41h/42h se aplican en el reset que el propio menú dispara; aplicarlos "en caliente", como propone, movería la RAM de la página 3 bajo los pies del menú antes del reset.
6. **El informe maestro consolidó mal.** Mezcla líneas de `opl4_pcm.v` con código de `opl4fm.v`, inventa una señal (`w_pcm_use_st`) y marca como "ambos" cosas que su propia fuente dice que el MSXimus tiene mejor (el mezclador con rodilla suave).

## 3. Los tres críticos, uno a uno

**C1, carrera `wv2_req`/`wv2_done` en `v9968_sdram_bridge.v`.** El estado "nueva petición y done anterior en el mismo flanco" es inalcanzable. El shim solo emite `bk_req` con `bsy` a 0 (`v9968_vram_shim.v:1792`) y `bsy` solo baja al ver el toggle de `bk_done_t`; entre el `wv2_done` de una operación y el `new_req` de la siguiente hay una cadena de al menos ocho registros. El modelo de ciclos da una distancia mínima de siete flancos y cero coincidencias. La guarda que propone el informe, con el backend DDR3 real, dejaría la petición nueva sin servir para siempre (`a_srv` solo se rearma al bajar `a_req`).

**C2, `bk_req` y `new_ack` en el mismo flanco.** Misma razón, lado del VDP: el shim no puede emitir hasta consumir el toggle que ese `new_ack` produce; distancia mínima tres flancos, cero coincidencias en el modelo. Separar la rama en otro `always` no cambia nada.

**C3, la escritura "rescatada" del backend DDR3.** El informe describe bien lo que hace el rescate (a los 0,9 ms con la IP sin aceptar, se da el done al shim y `en`/`wren` quedan retenidos) y mal sus consecuencias: el payload queda congelado en registros hasta que la IP lo acepta (llega tarde, no equivocado) y ninguna operación nueva entra sin `iss_free`, así que nada adelanta a la retenida. Es la decisión de diseño de la _95 para no colgar el VDP con una IP parada, y el arreglo propuesto (bloquear hasta `iss_free`) restauraría ese cuelgue. Lo único cierto es un hueco ya conocido: la rama de rescate no actualiza la caché de línea, así que un hit posterior sobre esa línea devolvería el dato anterior. Disparador: IP colgada sin perder la calibración, sin evidencia en placa. Queda en el backlog del bitstream (apartado 5).

## 4. Veredicto hallazgo a hallazgo

### 4.1 MSXimus (Tang Console 60K)

| Id | Fichero | Veredicto | Motivo |
|---|---|---|---|
| C1 | `v9968_sdram_bridge.v` | Refutado | Estado inalcanzable por protocolo (`bsy` del shim); modelo de ciclos con cero coincidencias |
| C2 | `v9968_sdram_bridge.v` | Refutado | Ídem, lado VDP; distancia mínima tres flancos |
| C3 | `v9968_ddr3_backend.v` | Parcial, baja | Rescate deliberado; payload retenido íntegro; solo falta invalidar la línea de caché en el rescate |
| H1 | `top.v` cargador de flash | Estilo | Nadie relee `ff_flash_state` tras el `=`; mismo flop; INIT1-4 son estados muertos |
| H2 | `top.v` FSM demux | No aplica | El `=` es intencionado (el `casex` ve el contador incrementado); la FSM solo alimenta `ex_msel`/`ex_bus_mp`, sin consumidor: podada |
| H3 | `top.v` estado `FINISH2` | No aplica | Cierto, pero dentro de la misma FSM podada |
| H4 | `top.v` `opl4wave_rd_w` | Estilo | Deliberado (_89): el motor PCM cubre 7Eh y 7Fh; el stub es inalcanzable y se poda |
| H5 | `v9968_vram_shim.v` temporales | Refutado | Idioma correcto de temporal en bloque con nombre; con `<=` el relleno de caché usaría datos rancios |
| H6 | `swioports.vhd` `"00X00000"` | Estilo | Heredado del OCM 3.9; el bit 5 no lo lee nadie (19 lecturas, ninguna del bit 5); sin aviso de síntesis |
| H7 | `swioports.vhd` `inout` sin `oe` | Refutado | Es el idioma VHDL-93 de KdL (releer un puerto); la l.166 lo lee y llega a `IN 41h`; "quitar inout" no compila |
| H8 | `v9958_top.v` bloque con `=` | No aplica | El fichero no entra en la build V9968 |
| H9 | `opl4_pcm.v` `dw =` | Refutado | Temporal del entrenador de stride; con `<=` el prefetch pediría palabras equivocadas |
| H10 | `top.v` `config_enable_*` | Refutado | Se recargan en el reset del Save & Restart; el informe dice "arreglado" citando el mismo código que el nano |
| M1 | bridge sin reset | Estilo | Registros de payload; el reset genera como mucho una repetición idempotente de la última op |
| M2 | `opl4_pcm.v` estéreo | Refutado | Las líneas citadas son un CDC; el código es de `opl4fm.v` (mono); `w_pcm_use_st` no existe; el PCM satura por canal |
| M3 | `wave_ddr3.v` watchdog | No aplica | No está en `build.tcl` desde la _104 (`wave_sdram.v`) |
| M4 | `adpcm_sdram.v` sin watchdog | Refutado | `memory.v` es un secuenciador de bucle abierto que siempre concede y siempre pulsa `wv2_done` |
| M4b | `v9958_top.v` `VDP_ID` | No aplica | Fichero fuera de la build |
| M5 | `memory.v` `enable_sdram` | Refutado | 54 y 108 MHz del mismo PLL, mismo grupo del SDC; documentado en `memory.v` (_122) |
| M5b | `config_init` 54→27 | Refutado | Mismo PLL; además desde el 17/09 dura cuatro ciclos (`cfg_init_sr`) |
| M6 | `memory.v` init FSM | Refutado | Lectura equivocada: `RstSeq[4:2]=111` es el régimen permanente; el arreglo literal rompe el controlador |
| M6b | `cadence_safe` | Refutado | `bus_clk_3m6` ya está registrada a 54 MHz por el PINFILTER; un 2FF desalinearía el turbo (cuelgue F11 de la v1.9a) |
| M7 | mezclador sin saturación | Refutado | Sumas de 19 bits, `gmul` a 23 y `sat16k` con rodilla; el anexo del propio informe lo reconoce |
| LOW | `mapper_dout`, `megaram_dout`, `opll_mix` | Estilo | Wires sin uso |
| LOW | `audio_sample` "solo V9958" | Refutado | Es el audio HDMI de las dos ramas; quitarlo dejaría el MSXimus sin sonido |
| LOW | `;;` | Estilo | Cierto, inocuo |
| LOW | `psg2_req_r` | Estilo | Nombre engañoso, sin efecto |
| LOW | `casex` | No aplica | FSM podadas; el idioma además es correcto |
| LOW | ternario signed | Estilo | Sin efecto |
| LOW | puertos "sin nombrar" | Refutado | Todos van con nombre (`.debug()`); es el idioma recomendado |
| LOW | `mix_lvl` canal 0 | Refutado | La guarda existe en `top.v:4755` |
| LOW | `ASYNC_REG` | Estilo | Atributo de Vivado; 11 de las 15 líneas no son cruces asíncronos |
| LOW | `dbg_uart.v` | Refutado | El orden es correcto |
| LOW | `clk27_align.v` | No aplica | No se compila desde la v3.0 |
| LOW | `ro_osc.v` desborde | Estilo, baja | Margen del 25 % con `WIN_CYC` de 2^18; el fallo caería del lado seguro; comentario de `fan_ctrl.v:22` desfasado |
| previa | `sd_reader.sv` (M1, M2, M3, #3, #4, #5, #6), `dpram.v`, `pinfilter.v`, `flash_rw.v` (3), `YM2149.vhdl` | Ya arreglado | Todo corregido en el árbol del 60K antes del informe; "persiste" es falso |

### 4.2 MSXnano (Tang Nano 20K, cerrado en v2.0)

| Id | Fichero | Veredicto | Motivo |
|---|---|---|---|
| H1 | `top.v` `config_enable_*` | Refutado | Se recargan en el reset del Save & Restart; el menú del nano ni expone el slot del mapper |
| H2 | `v9958_top.v` bloque con `=` | Estilo | Nadie relee tras escribir; mismo flop; solo riesgo de simulación |
| H3 | `swioports.vhd` `X` | Estilo | Bit 5 sin consumidor |
| H4 | `swioports.vhd` `inout` | Refutado | Idioma VHDL-93; `io42` usa la misma mecánica y alimenta `Slot2Mode` |
| M1 | `sd_reader.sv` `outaddr` | Refutado | Se reinicia en cada orden; los pulsos extra solo activan la lectura del buffer; descargas validadas byte a byte |
| M2 | `sd_reader.sv` CRC desfasado | Refutado | Tres ciclos de margen entre el último bit y la emisión |
| M3 | `sd_reader.sv` `=` | Estilo | Sin efecto en silicio |
| M4 | `v9958_top.v` `VDP_ID` | Estilo | Los smart codes OCM de offset e ID no están cableados; rutear cambiaría el offset validado (19 frente a 16) |
| M5 | `config_init` | Refutado | La ventana dura unos 20 ciclos (un byte de la SPI); nadie lee el byte 5 |
| M6 | `cadence_safe` | Refutado | Ídem MSXimus |
| M7 | mezclador sin saturación | Parcial, baja | Aritméticamente posible con picos en fase de todas las fuentes; nunca observado; el disparador del informe es del MSXimus |
| M8 | `dpram.v` `$pow` | Estilo | GowinSynthesis lo resuelve; solo afecta a yosys |
| #3 | `sd_reader.sv` `rdone` | Parcial, baja | Al revés: la colisión hace que la cancelación por timeout nunca dé `done` y se reintente hasta reset |
| #4 | `sd_reader.sv` reintentos | Confirmado, baja | Bucle infinito sin tarjeta o con tarjeta extraída; no cuelga el MSX (el firmware tiene backstop) |
| #5 | `sd_reader.sv` timeout WTAIL | Parcial, baja | El timeout es código muerto pero no hay cuelgue; el defecto real es otro: el token no se captura y WBUSY sale antes del busy (bloque "aceptado y no escrito" si el Z80 no espera 2 ms; el menú lo tapa) |
| #6 | `sd_reader.sv` CRC de lectura | Confirmado, baja | Se ignora; limitación de WonderTANG |
| #2 | `YM2149.vhdl` envolvente | Parcial, baja | Sí hay bucles lógicos: 36 avisos AG0100 en el log de síntesis; sin síntoma en años |
| #1 | `flash_rw.v` `write_terminate` | Parcial, baja | Sigue como `output`; programa 256 bytes en vez de 7, con el relleno a FF: mismo resultado |
| L71 | `flash_rw.v` WIP sin timeout | Estilo | Indisparable con la flash de la que arranca la propia FPGA |
| L72 | `flash_rw.v` sin WIP tras programar | Parcial, baja | Solo importa en ráfaga; el nano escribe una página por acción humana y el reset tarda 39 ms |
| LOW | demux y flash-loader con `=` | No aplica / estilo | Demux podada; cargador sin relectura |
| LOW | `;;`, `ff_rom_addr` 25→23, mux `ram_addr`, `cpu_din` | Estilo | Ciertos, sin efecto |
| LOW | CDC "implícitos" | Refutado | 27 y 54 MHz del mismo `CLKDIV`, mismo grupo del SDC |
| LOW | `STARTUP_WAIT` sin declarar | Refutado | Declarado en `flash_rw.v:1-3` |
| LOW | `uart_lite.vhd` sin instanciar | Refutado | Lo instancia `wifi_lite.vhd` (la UART del WiFi) |
| LOW | `wifi_lite.vhd` strobe | Estilo | Sin efecto |
| LOW | `rp2040/main.c` `buf_pool` | Estilo | Variables sin uso |
| DEAD | 24 wires y regs de `top.v` | Estilo | Todos ciertos (`clk_108m_n`, `mp_cnt`, `af_phase`, `io_active`, `psg_dout`, `usb_uart_tx`, etc.); la síntesis los poda; `ppi_swap` va bajo un `ifdef` apagado |

### 4.3 bios-msxnano-msximus (bios, menú, packs, herramientas)

| Id | Fichero | Veredicto | Motivo |
|---|---|---|---|
| B1 | `tools/insertar_en_pack.py:56` | Confirmado, media | Imprime "0x200000" para todos; el MSXimus va a 0x400000 y el bitstream ocupa 2,59 MB: flashear ahí lo corrompe (se recupera por JTAG) |
| P1 | `packs/LEEME.md:54` | Confirmado, baja | Dice que falta `COMMAND2.COM` y está en `packs/sd/`; además la l.8 dice que `packs/` no está en git (sí lo está desde el 02/09) y la l.71 apunta a `../MSXnano-nextor3/` (es `nextor3/`) |
| P2, B15 | `release/` | Confirmado, baja | Esquema de cuatro bios del 23/08, abandonado; su LEEME manda el pack del MSXimus a 0x200000 |
| B16, BP6, BP5 | 8 packs `bios-MSX`/`bios-Menu` | Confirmado, baja | Legacy trackeados (los del nano con el logo a FF; los del MSXimus del menú de 16 KB, que en un core V3.7 no arranca el menú y pisa los ajustes) y `packs/LEEME.md:35/37` los da como comando de flasheo |
| S4 | descripción del repo en GitHub | Confirmado, baja | Habla de "tres variantes" desde antes del 04/09 |
| P3 | `tools/desmontar_pack.py` | Confirmado, baja | Rechaza los packs canónicos del MSXimus (512 KB sin cola) |
| B5 | `build.sh` `dd` sin comprobar | Parcial, baja | Cierto; un fallo dejaría la ROM base sin menú, no un pack roto |
| B3 | `insertar_en_pack.py` salida = entrada | Parcial, baja | Dejaría el pack parcheado, no roto; packs en git y con backup diario |
| B8 | `hacer_packs.py` escritura no atómica | Parcial, baja | Backup previo y git; un pack truncado no pasa el `assert` del siguiente run |
| B10 | `hacer_packs.py` orden lexicográfico | Parcial, baja | Solo falla con beta10 conviviendo con beta2-9 |
| S1 | `nextor3/setup.sh` sin hashes | Parcial, baja | HTTPS a GitHub, bootstrap ya hecho; ni arranca en Git Bash |
| B7, B13 | validación Nextor 2.1.4; `fh2_dfind` | Ya arreglado | La comprobación está en la l.142; el fail-closed está documentado en el fuente |
| B2 | slice fuera de rango | Refutado | Aborta antes de escribir con y sin `-O` (probado) |
| B6, B9 | TOCTOU, medianoche | Refutado | Un solo usuario; copiar el mismo fichero dos veces da los mismos bytes |
| B14 | magic `SRM1` | Refutado | Es el descriptor en RAM, no las partidas |
| P4, P5, B4 | portabilidad a macOS | No aplica | El entorno es Windows con Git Bash (bash 5.3, coreutils GNU); el build corre |
| B11, B12, B17, S2, S3, BP1, BP3 | limpiezas y firmas | Estilo | Ciertos, sin efecto; firmar commits es decisión de Albert |
| BP2 | CI en GitHub Actions con los packs | Refutado | La "verificación" de `desmontar_pack.py` es una tautología, rechazaría los packs del MSXimus, y mandar packs con ROMs con copyright a runners ajenos va contra el criterio del repo |
| BP4 | hook pre-commit anti `.bin` | Refutado | Bloquearía `assets/*.bin` y `nextor214/*.bin`, que se trackean a propósito |

## 5. Plan por proyecto

### MSXimus (60K): ningún cambio de RTL

No hay ningún hallazgo que justifique un bitstream. Un bitstream nuevo es una campaña de place and route al 98 % de CLS y una validación en placa, y la regla desde la v3.6h es que solo entran errores graves: no hay ninguno.

Lo que queda es un backlog de higiene para **la próxima vez que se abra `top.v` o se rute la DDR3 por otro motivo**, todo netlist-neutro o de un par de líneas:

1. C3: en la rama de rescate de escritura de `v9968_ddr3_backend.v` (606-614), invalidar o actualizar la línea de caché (`clA`/`clB`) igual que hace la rama normal (588-601), y añadir al banco `tb_ddr3_backend.sv` un caso de escritura con la línea en caché durante un fallo de la IP.
2. H6: `"00X00000"` a `"00000000"` en `swioports.vhd:241` (inocuo, solo por quitar el `X`).
3. Borrar las dos FSM muertas del standalone (`top.v` 719-782 y 1197-1246) y los estados INIT1-4 del cargador de flash, en vez de reescribirlas.
4. Marcar como históricos o borrar `clk27_align.v` y `wave_ddr3.v`, que no se compilan.
5. Corregir el comentario de `fan_ctrl.v:22-23` (con `WIN_CYC` de 2^18 el techo del anillo es ~108 MHz) y anotar en `memory.v:313` que `RstSeq[4:3]==11` es la marca de init terminado.

Y una nota de método para el capítulo 07: cualquier auditoría del MSXimus tiene que leer `tools/lanzar_campana.ps1` antes que `top.v`.

### MSXnano: nada, con la deuda apuntada

El proyecto está cerrado en v2.0 (19 de septiembre) y nada de lo encontrado lo reabre: los dos confirmados y los siete parciales son de severidad baja, solo se disparan con una tarjeta extraída o averiada, o nunca se han observado. Si algún día se reabriera, el orden sería:

1. Portar `sd_reader.sv` del MSXimus entero (reintentos acotados, CRC de lectura, token y busy de escritura, `rdone` tras timeout): son los hallazgos #3, #4, #5 y #6 de una vez. Cambia el arranque sin tarjeta y la temporización de escritura: placa.
2. Portar `p_envelope_shape` de `YM2149.vhdl` (carga síncrona) y comprobar que el log de síntesis queda sin avisos AG0100.
3. Portar los estados `STATE_05c_*` de `flash_rw.v` y pasar `write_terminate` a `input`; solo importa si se lleva el guardado de SRAM a la flash.
4. Sumar el mezclador en 19 bits con clamp a 16.

No se toca el repositorio del nano por esto; este capítulo es la nota.

### bios-msxnano-msximus: fase 0 de un cuarto de hora

Todo documentación y herramientas; no cambia ni la bios ni los packs.

| Paso | Qué | Tiempo |
|---|---|---|
| 1 | B1: el `print` de `insertar_en_pack.py` con las dos direcciones ("MSXnano 0x200000, MSXimus 0x400000"), sin el `sys.exit` del informe (rompería el uso documentado con `pack.bin`) | 5 min |
| 2 | P2, B15: `git rm -r release/` (la historia lo conserva; no moverlo a `packs/historico/`, que está ignorado) | 2 min |
| 3 | B16: `git rm` de los ocho packs legacy y en `packs/LEEME.md` cambiar los comandos de las l.35/37 a `pack_bios_msximus.bin` / `pack_bios_msxnano.bin` y quitar la tabla "Las dos variantes" | 5 min |
| 4 | P1: `packs/LEEME.md` sin el "falta COMMAND2.COM", con la l.8 (packs en git desde el 02/09) y la l.71 (`nextor3/`) corregidas | 5 min |
| 5 | S4: `gh repo edit --description` con la bios única por máquina y los cuatro packs | 1 min |

Fase 1, opcional y sin prisa: cola opcional en `desmontar_pack.py` (P3, 3 líneas); `|| fallo` en los tres `dd` de `build.sh` (B5); `realpath` en `insertar_en_pack.py` (B3) y escritura a `.tmp` + `os.replace` en `hacer_packs.py` (B8); hashes SHA-256 en `setup.sh` (S1); una línea en el README con "Windows/Git Bash, o Linux/WSL con bash 4 y coreutils GNU" (P4/P5). B10 cuando exista una beta10 de Nextor 3.

Lo que no se hace: CI con los packs (BP2), hook anti `.bin` (BP4), reescribir `build.sh` para bash 3.2 (B4), y las firmas de commits (BP1, S3), que son decisión de Albert.

**Fase 0 aplicada el 21/09** (commit 3cf25d8 de `bios-msxnano-msximus`): los cinco pasos de la tabla, con el `insertar_en_pack.py` probado sobre los dos packs canónicos (cero bytes cambiados) y la descripción del repo actualizada. La fase 1 sigue pendiente.

Los ocho ficheros vacíos de la raíz del repositorio (EXTRA-1 del verificador) eran restos de redirecciones de esta misma sesión y ya están borrados.
