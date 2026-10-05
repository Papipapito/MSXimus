# 09. Changelog de la era v3

Versión a versión, qué cambió, qué dado se entregó y con qué hashes. Sale de los LEEME de cada entrega en `files/<fecha>/`, que quedan fuera de git, y de las notas de `mi_release/`. Las versiones publicadas en GitHub llevan tag; las intermedias son entregas internas probadas en placa.

Los hashes son md5, los ocho primeros dígitos salvo donde se indica. El "dado" es el número primo con que se sembró el place and route ([capítulo 07](07-sintesis-campanas.md)); el margen es el peor setup del informe de temporización.

## v3.1 (26 de agosto de 2026, publicada, tag `v3.1.0`)

La versión que da nombre a la era: **el core reconstruido sin el SSRAM de la GW5AT-60B**, que Gowin retiró por un problema de silicio. Todas las memorias que vivían ahí pasaron a BSRAM o a registros, lo que obligó a rehacer por dentro el motor de ondas del OPL4, los registros del OPL3 y la caché PCM.

- Panel de estado en **F12** por el BL616 de la placa, con el MSX congelado debajo.
- Identificación como **turbo R**: registros del S1990 en E4-E7 y CHGCPU mueve el turbo. Sin R800.
- **Ratón MSX** desde un ratón USB con cable.
- Dos BIOS a elegir: la plana y la del navegador de la SD.
- El turbo pasa a **F11**.

| | |
|---|---|
| Core | `MSXimus_v3.1.fs` 2cbf1690, margen 0,607 ns. Respaldo 4655e7bf (0,473 ns), no publicado |
| Packs | bios-MSX 0d82f357, bios-Menu 28cb2a7b |
| BL616 | `bl616_v3.1.bin` af5a4f79 en 0x40000, con el de Sipeed 4dbe9bb1 en 0x0 |
| C6 | `firmware_esp32c6_unapi_merged.bin` 8acd1918, el mismo de la v2.1.2 |

## v3.2 (4 de septiembre de 2026, publicada, tag `v3.2`)

**El core no cambia**: es el mismo `.fs` de la v3.1. Cambia todo lo de encima.

- **Una sola BIOS**: el navegador es un ajuste, *Menú al arrancar*, guardado en la flash.
- **Descargas desde el menú**: tecla F, File-Hunter, ROMs y discos directos a la tarjeta.
- Logo MSX animado en la pantalla del C6.
- El firmware del C6 pasa a su propio repositorio, `ESP32-for-FPGA`, el mismo binario para el MSXimus y el MSXnano.

## v3.5a (5 de septiembre, interna)

Primera build del **plan 3.5**: la SD y los mappers.

- El controlador de la SD, arreglado de raíz: el token de estado de la escritura nunca se evaluaba y el host daba por escrito un sector que la tarjeta aún estaba programando. Ahora se lee el token y se espera el busy. Reloj de la tarjeta a 6,75 MHz (era 2,25). CRC16 de lectura comprobado, con reintento. CMD12 acotado.
- **Megaram de 4 MB** (era 2): el mapper de RAM se recorta a 2 MB y la megaram se queda con su hueco. ASCII16 recupera el bit 7 del registro; **NEO-8 y NEO-16** nuevos. Puerto 46h.
- Banco de 33.047 operaciones aleatorias contra la megaram de la v3.1 como oráculo.

Core: dado 3001, c3e350b0, margen 1,084 ns. Respaldo 3019. BSRAM al 118/118: desde aquí no queda ninguna.

## v3.5b (6 de septiembre, interna)

- **El menú pasa a ROM de 32 KB**: la segunda página va donde estaba el driver kanji, que desaparece del MSXimus. Ya no se descomprime en RAM.
- **SRAM de cartucho persistente** en la tarjeta: ficheros `.SRM` en `FHUNT`, guardado al siguiente arranque tras reset (bloque 5 del plan).

Core: dado 3041, 508f8330, margen 1,084 ns; respaldo 3083 (0,904 ns). Ocho dados en una noche para sacar dos buenos. Core y pack van en pareja: un core anterior con este pack no arranca el menú.

## v3.5c (6 de septiembre, interna)

- **La SD por puertos de E/S**: los registros del controlador en 47h-4Fh del dispositivo 48h, además de la ventana de memoria, que sigue igual. INIR en vez de LDIR.
- **Multibloque** CMD18 y CMD25 con un solo búfer: el core para el reloj de la tarjeta entre bloques.
- Driver de Nextor nuevo, común a 2.1.4 y 3, que sondea el core y usa lo que hay. Ninguna combinación de core y pack deja de arrancar desde aquí.

Core: dado 3169, eece0162, margen 0,481 ns; respaldo 3109 (0,419 ns). Velocidades en placa: 90, 104 y 112 KB/s por ventana, puertos y multibloque.

## v3.5d (6 y 7 de septiembre, interna)

- **Cronómetro de milisegundos** en el core, por el índice 25-27 de 4Eh: el menú medía la carga con el contador de la BIOS, que se para con las interrupciones inhibidas, y daba cifras imposibles.
- **Menú de pruebas** con la tecla T: velocidad de la SD por sus caminos, sonido, configuración.
- Todas las salidas del módulo de puertos de la SD pasan a registradas: la lógica combinacional colgada de IORQ_n y WR_n se llevó por delante tres campañas (0,171 ns, -1,55 ns, -0,791 ns).
- Una carrera metida al registrar la orden por ventana rompió la carga de ROMs en el dado 3257, que se retiró; el 3319 la lleva arreglada.

Core: dado 3319, de39e213, margen 1,309 ns, el mejor de la serie. Seis campañas y dieciocho dados en una noche: el mismo RTL dio desde 1,19 ns hasta -0,18 según el dado.

## v3.5e (8 de septiembre, pack de diagnóstico)

Solo el pack: la tecla T también desde el navegador, no solo en el logo. El core sigue el 3319.

## v3.5f (9 de septiembre, interna)

- **Game Master 2 emulado en el slot 1** (bloque 6): la ROM del cartucho y sus 8 KB de SRAM en la megaram, armado por el menú para los juegos Konami, guardado en `FHUNT\GM2.SRM` como la SRAM de cartucho. Ajustes: *Slot 1* con tres estados.
- Los packs del MSXimus pasan a **512 KB justos, sin la cola de configuración**: grabar un pack ya no pisa los ajustes.
- Se cierra la "pantalla negra" de Metal Gear 2: era la ROM [9692], cuyo arranque comprueba si hay MSX-DOS, no el core.

Core: dado 3461, e140f8da, margen 1,299 ns; respaldo 3457 (0,627 ns).

## v3.5g y v3.5h (9 de septiembre, packs)

- Corregido el "Enviando GET..." colgado de File-Hunter: una rutina de CRC había ido a parar a la página 1, que durante la sesión de red es la ROM del ESP (regresión de la 3.5b).
- **Tecla G** en la pantalla de lanzar: Game Master 2 On/Off por lanzamiento, para los juegos que usan el mapper Konami-SCC sin ser de Konami. Fuera la línea de velocidad de carga.

## v3.6 (9 de septiembre, interna)

- **DMA de lectura de la SD a la RAM**: el core vacía el búfer de sector sin pasar por el Z80, congelando la CPU con el bus en reposo y escribiendo por el camino del streamer de la flash. De 112 a **640 KB/s**. Guarda del refresco de la SDRAM: el refresco autónomo solo en las ventanas de espera de la tarjeta.
- El menú carga las ROMs por DMA, cluster a cluster.
- El puerto 2Fh dice 3.6.

Core: dado 3529, 29ffd767, margen 0,726 ns; respaldo 3527 (0,148 ns, solo respaldo). Commits ec9893d y bc0e3d0 en MSX_up_v3, e446e65 en la BIOS.

## v3.6b (9 de septiembre, pack)

El análisis del mapper de una ROM sin etiqueta pasa de leer sector a sector por la ventana a una DMA de 256 KB a la megaram y un escaneo con CPIR desde ahí: de siete segundos a dos. Commit 152693e en la BIOS.

## v3.6c (9 de septiembre, interna, validada en placa)

- **DMA en modo lógico**: el destino puede ser una dirección del Z80 que el core traduce con los registros del mapper, que para el Z80 son de solo escritura. Es lo que necesitaba el driver de Nextor.
- **Contadores de patrones de mapper** en la propia DMA: el análisis de una ROM sin etiqueta pasa a coste cero.
- **El driver de Nextor lee por DMA** cuando el búfer está en RAM del mapper: el arranque de DOS y la carga de programas se notan.
- Firma 'M' en el índice 31 de 4Eh.

Core: dado 3533, 1d3ab9ee, margen 0,913 ns; respaldo 3541 (0,039 ns, en el término del refresco, solo respaldo). Commits e5f1a54 en MSX_up_v3, 9aff42a en la BIOS. Validado en placa el 9 de septiembre: DMA a 640 KB/s, DOS arranca mucho más rápido, los discos cargan bien con Nextor 2.1.4 y con Nextor 3, Manbow 2 y Metal Gear 2 con Game Master 2 funcionan.

## v3.6d (9 de septiembre; retirada el 14)

`cpu_run`, el término de seis señales que gobierna el refresco de la SDRAM, pasó a registrado antes de entrar al controlador de memoria: era el peor camino de temporización en los tres dados de la v3.6c (commit 74f95de). **Retirada**: el primer dado que la llevó, el 3557, pasa el gate con 1,17 ns y se queda en negro al arrancar; el 3593, mismo RTL sin este registro, arranca. Un dado de cada, así que no es una prueba cerrada, pero el registro no tenía más función que ganar margen y el margen sin él (0,9 ns) ya cumple. El porqué queda abierto: sobre el papel el registro solo retrasa un ciclo de 54 MHz la puerta del refresco autónomo, y ninguno de los seis términos (reset, streamer de la flash, ESP, F12, DMA) explica que la SDRAM no arranque. Ya pasó algo parecido en la v3.5d al registrar la orden por ventana (dado 3257). Revertida en el commit de cierre de la v3.6e.

## v3.6e (14 de septiembre, interna)

Dos errores del core que salieron a la luz portándolo a la Zynq (`fpga/zynq/`, repo privado `MSXimus_zynq`), donde el buzón de depuración permite inyectar mandos y ratón y leer la telemetría sin hardware. Los dos están en `top.v` y afectan igual a la Console 60K; entran en la siguiente campaña.

- **La cruceta de los mandos, mal cableada desde la v3.1**: `assign joystick0/1` tenía dos errores a la vez. El eje vertical estaba al revés de como lo consume `joy0_msx` (el byte que ve el PSG): ponía arriba en el bit 0 y abajo en el 1, y el consumidor lee arriba en el 3 y abajo en el 2. Y el eje horizontal se tomaba de los bits 10 y 11 de la palabra del BL616, que son los **hombros L y R**, no la cruceta: en el formato del firmware (`usb_gamepad.cpp:337` con `hidparser.cpp`: right/left/down/up en los bits 0-3 del byte HID, subidos a 7/6/5/4) izquierda y derecha son los bits **6 y 7**. En la Console 60K el resultado era: arriba daba derecha, abajo daba izquierda, izquierda y derecha no hacían nada y los hombros movían arriba y abajo. El primer error salió en la Zynq; el segundo, al revisar ese arreglo contra el firmware: el companion de la Zynq (`hid_pad.c`) había copiado del comentario de `top.v` la misma idea equivocada de que la cruceta iba en 10/11, así que allí el arreglo a medias parecía completo. Ahora `top.v` lee 4/5/6/7 y `hid_pad.c` emite ese mismo formato, con los hombros en 10/11. Los botones A/B y el autodisparo no cambian.
- **El ratón perdía el movimiento**: la relectura del registro 15 del PSG devolvía FFh (solo el 14 estaba implementado en la multiplexación de `cpu_din`; el `O_DA` del YM2149 sigue sin conectar). La interrupción de la BIOS lee, modifica y escribe ese registro dos veces por frame para los gatillos de `ON STRIG` (puerto 1 `AND AFh OR 03h`, puerto 2 `AND DFh OR 4Ch`): con FFh de partida escribía AFh y luego DFh, es decir, el pin 8 del puerto 2 subía y bajaba a 60 Hz, y cada pulso hacía que `msx_mouse` capturase y vaciase su acumulador en un ciclo fantasma que nadie leía. `PAD(17)`/`PAD(18)` devolvían 0 salvo con programas que leen cada frame (INDEV lo disimulaba). Ahora el registro 15 se relee (`psgPB`) y las escrituras quedan en CFh/8Fh, con el pin 8 quieto.
- `msx_mouse` gana dos salidas de diagnóstico (`dbg_cur_x`, `dbg_rel_x`) que en la 60K quedan sin conectar.

Commits 39289a2 y 816937c en MSX_up_v3 (rama V3.5). El ratón y la cruceta se validaron en la Zynq desde BASIC: `STICK(1)` 1/5/7/3 para arriba/abajo/izquierda/derecha, `STRIG(1)`/`STRIG(3)` con A/B, `PAD(17)` = 20 para un delta de 80 (sensibilidad ÷4). Queda confirmar el sentido del ratón (`NEGAR_DELTA`) con un programa real.

Core: **dado 3593**, b823b1d3, margen 1,129 ns; holds solo la DDR3 y el anillo del ventilador. Es el RTL de la v3.6c más los dos arreglos de arriba, **sin la v3.6d**. Es el primer core de la 60K con el que se puede probar un mando.

La noche de campañas que lo produjo, para que conste lo que cuesta un dado al 98 % de CLS: siete dados en tres campañas (v36e 3547/3557/3559, v36f 3571/3581, v36g 3583/3593). Cuatro no rutaron (PR0004, entre 84 y 425 redes), uno falló el gate (3571, -0,34 ns en el T80), y de los dos que pasaron, el 3557 (con la v3.6d) se queda en negro y el 3593 (sin ella) arranca. Sin respaldo.

Un apunte que sale de la misma revisión, sin arreglar: los registros 0 a 13 del PSG tampoco se releen (devuelven FFh; `O_DA` del YM2149 está sin conectar, aunque el modelo sí los sirve). Ningún juego probado lo ha echado en falta, pero un reproductor que haga `RDPSG 7` para tocar el mezclador se encontraría todo silenciado.

**Un error del V9968, encontrado la misma noche y sin arreglar: el marcador de Xevious Fardraut Saga sale en blanco.** El juego (Namco 1989, 256 KB, `[GoodMSX] [2489]`) arranca, y el logo, la intro, la demostración y las escenas se dibujan bien; pero en partida la banda del marcador, arriba, sale blanca con puntos de colores en vez del `TOP / HI SCORE / AREA / LEFT` que muestra openMSX. El campo de juego, los sprites y el scroll van bien. Pasa igual en la Console 60K y en la Zynq, luego es del VDP compartido y no de ninguno de los dos portes. En la Zynq se volcó la VRAM durante la partida: la línea 0 de la página 0 tiene gráficos reales, y la zona de las líneas 212 a 255 (`6A00h`-`7FFFh`, fuera de la ventana visible) está entera a `FFh`, que en SCREEN 5 es blanco. Es decir, el VDP está mostrando arriba una zona de VRAM que nadie ha escrito. El juego usa el truco clásico de mover el desplazamiento vertical (R#23) a media pantalla con la interrupción de línea (R#19) para que el marcador quede quieto mientras el campo hace scroll, y los dos registros existen en `vdp_cpu_interface.v`, así que es un detalle de comportamiento y no una función que falte. Quedan dos mecanismos por separar: o el marcador vive en otra zona y a media pantalla se aplica el desplazamiento equivocado, o el juego sí lo dibuja en las líneas 212-255 y el V9968 pierde las escrituras por encima de la línea 211. Lo primero que hay que hacer es mirar en openMSX dónde escribe el juego el marcador y qué valor toma R#23 al principio del cuadro. Herramientas de la Zynq para seguirlo: `tools/vram.tcl` vuelca la VRAM cruda desde la DDR y `tools/vramfill.tcl` la rellena. Sin probar en el MSXnano, que lleva el VDP clásico.

## v3.6f (16 de septiembre, interna)

**Mandos por los USB-A.** Hasta aquí los dos USB-A solo servían teclado y ratón ("gamepads USB-A = pieza futura", decía `top.v`) y el único camino para un mando era el host USB del BL616, que vive en el USB-C OTG y necesita un hub o adaptador OTG con alimentación en el puerto donde va el cargador. Se descubrió el 16 de septiembre con el panel de F12 diciendo `USB: nada` y el mando en un USB-A. `usb_hid_host` ya sacaba `game_snes`, y en el mismo formato SNES de doce bits que la palabra del BL616: se OR-ea con el mando 1 del MCU, gateado por "hay mando en ese puerto" y sincronizado a 54 MHz. Cualquier mando en un USB-A cae en el puerto 1 del MSX. Commit 9a80f4d.

Límite: el host del fabric es HID puro con el informe de los mandos genéricos (ejes a 00/7F/FF). Un mando XInput (Xbox y los receptores 2,4 GHz que se presentan como Xbox 360, como el del Lenovo C01) no se ve por USB-A; con el firmware del BL616 y un hub en el OTG sí se enumeraba, pero la lectura de interrupción fallaba (`XBOX client #0: submit failed`), y Albert decidió no seguir por ahí: el BL616 se queda sin mandos, con su firmware congelado en el commit 3e67939 (el del panel con las filas de diagnóstico), y los mandos del MSXimus son HID por USB-A.

Del firmware del BL616, ya que se tocó: el `bl616_v3.1.bin` publicado el 26 de agosto se compiló sin `usbh_initialize()`, la pila USB host, que se fue por delante al quitar los montajes de FatFs; ningún mando pudo funcionar nunca con esa release. Repuesta en 0219b25, y de paso la cruceta como hat switch y el recorte de ejes de más de 8 bits, portados de FPGA-Companion (7146b7c). Repositorio privado de respaldo `MSXimus-firmware-bl616`.

Core: dado 3623, 2667d28b, margen 0,756 ns (clk_86, dentro del shim del V9968); holds solo la DDR3. Campaña v36h, cuatro dados: 3613 y 3607 fuera de gate (-0,05 y -1,87 ns en el motor del OPL4), 3617 con una red sin rutar. Sin respaldo. En la semana, once dados para tres útiles: al 98 % de CLS la campaña de tres ya no basta, y la de cuatro tampoco sobra.

## v3.8.1 (5 de octubre, solo en msx.barcelona): la relectura de los registros de slot del OPL4

Arreglo de un defecto que se vio en simulación y nunca en placa, traído de la Zynq el mismo día. Al leer por 7Fh un registro de slot del wavetable, la primera lectura devolvía a menudo el valor del registro leído justo antes, también respetando /WAIT; leído dos veces seguidas, la segunda salía bien. El chip real devuelve lo escrito. Las escrituras, el estado, el identificador (02h) y el dato de memoria (06h) no estaban afectados: la música no cambia, solo le importa al software que relea registros de slot.

- **Causa**, en el motor (`fpga/opl4wave/YMF278B.sv`), desde que esos registros pasaron a BSRAM en la v3.1: `REG_Q` se cargaba dos CE después del flanco de RD, cuando `rt_cpu_q` aún guardaba la lectura anterior, y el remuestreo que debía corregirlo (`REG_RD_DELAY == 2'b10`) llegaba entre 3 y 10 CE después del flanco, con `opl4_pcm.v` capturando al sexto. Fallaban siempre las lecturas en que la CYCLE1 del motor caía al cuarto CE o más tarde sin un hueco de CE por medio: 5 de cada 8 fases en los grupos de la BSRAM (08h-1Fh, 50h-7Fh, 98h-F7h). En FNUM y LFO (20h-4Fh, 80h-97h), otra carrera más rara: un 1 % de las lecturas devolvía el dato de otro slot.
- **Arreglo**, solo en el motor y sin añadir latencia: `REG_Q` se carga en el mismo CE de siempre, pero con el dato de esa lectura (`rt_cpu_d`, y `fl_cpu_d` para FNUM/LFO: 9 registros nuevos). `opl4_pcm.v` no cambia y /WAIT dura lo mismo (343 ns de mínimo y 370 de media desde que el Z80 baja RD).
- **Banco nuevo** `tools/opl4wave_sim/tb_slotrd.v` (`run_slotrd.sh`): con el motor de antes, unas 1.200 de 4.200 lecturas únicas distintas de lo escrito por semilla; con el arreglo, 0 en las tres semillas. `run_sim.sh` y `tb_regrd.sv` siguen en verde y los volcados de PCM de `run_pitch.sh` y `run_pan.sh` salen bit a bit iguales (el motor, `opl4_pcm.v` y los bancos son los mismos ficheros que en la Zynq, donde se midió). De paso, `run_pan.sh` deja de apuntar a la carpeta `MSX_up`.
- **Área**: en síntesis sola (`medir_area.ps1`) la BSRAM no se mueve (105 antes y después) y el bloque `uopl4pcm` gana 27 LUT y 10 registros.
- **Core v3.8.1** (`FPGA_PATCH = 1`): campaña `v381`, dados 5303, 5309, 5323, 5333 y 5347. **Dado 5309**: gate bien, peor setup +1,386 ns (`cpu1/RD` → `dpram1`, clk_54m → clk_27m), CLS 29260/29952 (98 %), sin holds fuera de la DDR3. 5323 fuera (-0,135 ns en el `IStatus` del T80) y 5347 fuera (-1,4 ns en el shim del V9968); 5303 y 5333 se pararon rutando, ya no hacían falta. `files/20261005/MSXimus_v3.8.1.fs` (431cc7ecf6f0) y `_jtag.bin` (8dd8d67d4af2). Packs y ondas, los de la 3.8.0b4.
- **Publicada solo en msx.barcelona** (`MXUPDATE /N`, las cuatro variantes y sus completas), sin release en GitHub: desde el 5 de octubre GitHub lleva solo las versiones grandes y los arreglos (tercer dígito) llegan por la actualización desde el MSX. Sin probar en placa.

## MXUPDATE 1.2 (4 de octubre): la ayuda con /H y /?

- `MXUPDATE /H` o `/?`: las órdenes en 40 columnas, en el idioma del menú; no toca la flash ni necesita el puente. md5 `de975760`, publicada en msx.barcelona (las 1.1 se la bajan solas). Banco: 29 casos bien.

## MXUPDATE 1.1 (4 de octubre): el fichero de cada placa, ofrecer bajarlo y autoactualizarse

- Sin fichero, busca el de la placa (`MSXIMUS.UPD`, `MSX138K.UPD`, `MSXNANO.UPD`) o el `MSXIMUS.UPD` del menú si es de esa placa; si no hay, pregunta si bajar la última versión. Antes, siempre `MSXIMUS.UPD` (en el MSXnano, el del 60K daba «Este fichero es para otra placa»).
- Se actualiza solo: msx.barcelona/wp-content/ota/mxupdate/ (manifiesto + `MXUPDATE.COM`); lo baja, lo comprueba, se sustituye y se relanza.
- Los stubs UNAPI se enlazan los primeros y msx.barcelona va en RAM: el código ya puede pasar de 4000h.
- Banco: 27 casos bien (nombres por placa, la pregunta, los tres de la autoactualización). md5 `76b89636`.

## v3.8.0b4 publicada (3 de octubre, tag `v3.8.0b4`, pre-release): Nextor 3.0 beta 2

El core de la v3.8.0b3 (dado 5233) con los packs de Nextor 3 rehechos con la **beta 2 de Konamiman** (1 de octubre): `Nextor-3.0.0-beta2.MSXnano.ROM` (617c914304e5) es el mismo driver de la beta 1, byte a byte, sobre el kernel nuevo (almacenamiento persistente `_NEXTOR.PSF`, `CALL SETSCREEN`, `BUFINSERT`, arreglos de `partit`; COMMAND3.COM con `DIRB`, `YENSLASH` y `AUTOEXEC.BTM`). Packs `pack_bios_msximus_nextor3.bin` b2e678a72172 y `_en_nextor3` 352a92d912ad; los de Nextor 2.1.4 no cambian. En msx.barcelona como 3.8.0b4 (las cuatro variantes). Con la release va una **imagen de SD** con Nextor 3 beta 2 (1800 MB) y **MSX SD Maker 1.1** (opciones de Nextor 3: `YENSLASH ON`, que desde la beta 2 es una orden de COMMAND3.COM, `BUFINSERT`, `DIRK`, `AUTOEXEC.BTM`; una sola partición en las tarjetas de 2 GB). Sin probar en placa.

## v3.8.0b3 publicada (2 de octubre, tag `v3.8.0b3`, pre-release): actualizar desde el MSX y el OSD con color

Versión nueva, pedida por Albert el 1 de octubre. Core: dado **5233**, afefaf128da8 (`_jtag.bin` 99d2e5362994), +1,095 ns. FPGA_VERSION 38h, PATCH 0 (Ajustes y MXUPDATE dicen `3.8.0`). Validada en placa el 2 de octubre: el puente lee y graba la flash real, `MXUPDATE /N` baja e instala de msx.barcelona con el certificado validado (C6 de la v3.8), y `/R` deja los ajustes de fábrica. Falta probar en placa la fila *Instalar actualización* de Ajustes y la firma de tipo de ROM.

- **Actualizar desde el MSX**: el puente de la flash (`fpga/src/flash_bridge.v`, dispositivo de E/S conmutada 4Dh), `MXUPDATE.COM` (fichero `.UPD` de la SD o `/N` de internet, `/R` completa con las ondas y ajustes de fábrica, `/C` solo comprobar) y la fila **Instalar actualización** de Ajustes, que graba el `MSXIMUS.UPD` de la raíz de la SD sin DOS. Formato `.UPD`, manifiesto y web en el [capítulo 11](11-actualizacion.md).
- **El OSD del BL616 con color** (F12): la BSRAM del overlay pasa de 2048×8 a 2048×9 (la misma: el modo ×8 tiraba un bit de cada nueve); cada fila tiene cuatro combinaciones de fondo y tinta de una paleta de 16 y hay 32 glifos nuevos. Página nueva: versión, Z80 y turbo, vídeo, SD, ajustes, USB, ventilador, mayúsculas y `MXUPDATE /N`, en el idioma del menú (el menú se lo dice al core por el puerto 4Eh). ESC también lo cierra. Un firmware viejo del BL616 se sigue viendo como antes.
- **La versión con tres dígitos** en MXUPDATE (`3.8.0`) y la etiqueta del `.UPD` con la del pack (`3.8.0b3`).
- **El ESP32-C6 con autoridades de certificación de serie** (16 de Mozilla, entre ellas la Sectigo R46 de msx.barcelona, hasta 2046): `MXUPDATE /N` valida el certificado sin depender de lo que haya en la FFat del módulo.
- **El mapper por la firma de tipo de ROM de MSXgl** (pack 3.8.0b3): `ROM_ASC8`, `ROM_AS16`, `ROM_KON4`, `ROM_KON5`, `ROM_NEO8`, `ROM_NE16` y `ASCII16X` en el offset 10h o 4010h mandan sobre la etiqueta del nombre y el análisis. Las ROM de geo3d ya no necesitan `[ASCII16]`. Banco `bios-msxnano-msximus/tools/firma_tb`, 15/15.
- Bancos: `tools/flash_tb`, `tools/osd_tb`, `tools/mxupdate/banco` (18/18), `bios-msxnano-msximus/tools/actualizar_tb` (11/11) y `firma_tb` (15/15).
- La 3.8.0b2 (pack con *Instalar actualización*, sin la firma) se publicó en msx.barcelona el mismo día y queda en la web para volver atrás.

## v3.7.6 publicada (30 de septiembre, tag `v3.7.6`): tres arreglos del V9968 de HRA y MSX SD Maker

Validada en placa por Albert el 30 de septiembre. Core: dado **5197**, 0fb615fd (`_jtag.bin` 2deacdb3), peor setup 0,965 ns (clk_86, dentro del shim); campaña pf60l, uno de cinco: 5167 −1,9 ns en el T80, 5171 −2,2 ns en el ADPCM y el shim, 5179 y 5189 sin rutar. El pack no cambia: el de la 3.7.5. FPGA_PATCH = 6 (af89f71).

HRA subió el 29 de septiembre tres arreglos a su V9968 (`44e93ec` → `4410365`). Revisados contra este árbol y portados igual que en la Zynq, donde van en la Z1.2.1:

- **El latch del puerto 99h** (`05f9806`). Un par de bytes a medias se cancela con cualquier lectura del VDP (98h-9Bh) y con una escritura al 98h, como en el V9938/V9958 y en openMSX (`registerDataStored`). Aquí solo lo cancelaba la lectura del estado, el `_185` de agosto que salió de la caza de Fleet Commander y DQ2. *Fleet Commander II* escribe un número impar de bytes en el 99h y cuenta con que las escrituras al 98h del `CLRSPR` lo resincronicen. El primer byte de la paleta V9938 comparte el latch con los puertos 1 y 3.
- **DIY con el origen arriba** (`ef12ee3`). LMMM, HMMM y YMMM copiando hacia arriba acaban también cuando el origen llega a Y = 0; solo miraban el destino. Su demo `ds4.rom` se paraba.
- **El paso de píxel registrado** (`4410365`). Es el arreglo de HRA de nuestra issue #10 (HMMM en SCREEN 2 con CMD=1) y sustituye a nuestro `ff_byte_mode` de la 3.7.1: el mismo resultado, más FG4 tratado como SCREEN 5, y la decisión de modo fuera del camino `w_next` → `ff_xsel`.

Bancos: `run_port1_latch.sh` (el banco de HRA, 12 pruebas; con el RTL anterior falla la 2), `g2cmd_check.py` con 24 casos DIY y los 60 de SCREEN 5-8 idénticos al RTL anterior, `run_cpuif_dbl.sh` en cinco modos y `run_spcol_vl.sh` (Fleet y DQ2). Los ficheros son idénticos a los de la Zynq, donde además se probó en placa: una rutina en BASIC que deja un byte huérfano en el 99h da `0 0 169` con el core anterior y `167 168 169` con este.

**MSX SD Maker** (`MSXsdmaker/`, fuente en `bios-msxnano-msximus/tools/sdmaker`): programa para Windows que prepara la tarjeta. Particiones FAT16 de 2 o 4 GB con la disposición y la geometría del FDISK de Nextor (hasta ocho) o una FAT32; Nextor 2.1.4, Nextor 3 o MSX-DOS; SofaRun, Multi Mente y el resto del contenido de `packs/sd`; el `AUTOEXEC.BAT` con un `MAPDRV` por partición. Relee la tabla y cada fichero por CRC al acabar. Probado con imágenes (sfdisk, fsck.fat, mtools) y en la Zynq: Nextor arranca de una tarjeta suya, ejecuta el `AUTOEXEC` y monta C: y D: en las particiones 2 y 3. De paso: Nextor no monta FAT32 (lo descarta en `partit.mac`: sin entradas de raíz), así que el capítulo 03 del manual se corrige.

## v3.7.5 publicada (30 de septiembre, tag `v3.7.5`): dado 5099

Validada en placa por Albert el 30 de septiembre: imagen desde el primer encendido (la DDR3 calibra), el navegador ordenado y un mando USB genérico sin la izquierda fantasma. Release en GitHub con `MSXimus_v3.7.5.fs` (ad3fcf18, `_jtag.bin` bc025ebb; campaña pf60k, peor setup 0,955 ns en el clk_108m, holds a cero), los cuatro packs del 29 de septiembre (2.1.4 7e00b72b, inglés 4e96626a, Nextor 3 9e0f4f15, inglés con Nextor 3 c7269785), la `yrw801.bin` y los firmwares del C6 y del BL616 de la v3.7, que no cambian. La rama pública `V3.7` avanza a este commit. Respaldo sin probar: 5107 (5b0b9631, 0,985 ns) y 5101 (6bb6954c, 0,526 ns). La línea 138K lleva los mismos cambios en su rama, pero ninguna campaña ha dado margen (pf138g, h, i: el V9968 a 88,5 MHz y el cruce CPU → SDRAM, sus familias de siempre) y no se publica.

## v3.7.5 (29 de septiembre): la izquierda fantasma del mando y las escrituras de configuración

- **La izquierda fantasma** (f935536). Albert, con la 3.7.4 y un vídeo: en el navegador, al bajar a la última entrada visible, la lista volvía arriba en vez de hacer scroll. No era el scroll: con el mando conectado, `PRINT STICK(1)` daba 7 con el mando quieto. El menú autorrepetía esa izquierda cada dos cuadros, y la izquierda del navegador salta 18 entradas atrás solo con la selección en la 18 o más: toda selección a partir de la 18 volvía 18 atrás (18 → 0, 20 → 2). La causa, en `usb_hid_host`: el decodificador de los mandos SNES decidía el eje X con el byte 0 nada más llegar, y un paquete vacío (ZLP) por EP1 se estroba como un solo byte 00, el primero del CRC: «eje X = 00», izquierda. Con un mando con Report ID (0810) ningún informe la soltaba, porque nunca trae 7Fh en el byte 0; la 3.7.3 solo limpiaba al acabar la enumeración. Ahora el byte 0 se evalúa al llegar el segundo byte (un ZLP no pasa de ahí) y con Report ID se sueltan las cuatro direcciones de ese decodificador. `tb_usb_hid_host` con un caso ZLP: con el RTL anterior falla (palabra 040h), con el arreglo pasa; FPGA_PATCH = 5.
- **Menú** (bios 72a8b47): el joystick solo autorrepite arriba y abajo; izquierda y derecha cuentan una vez por pulsación. Con este pack el navegador ya iba bien sobre la 3.7.4. `tools/test_navegador/browse_test.py --joy-left` reproduce el vídeo con el menú anterior.
- **Timing: las escrituras de configuración registradas** (9ff2c3a). Tres campañas con el arreglo del mando (pf60h 4951-4973, pf60i 5003-5023, pf60j 5039-5081): quince dados, cuatro por el gate, uno con margen, el **5003** (feaf6968, 0,534 ns), entregado como 3.7.5 y **retirado**: pantalla negra con la máquina funcionando (F11 cambia el turbo), la DDR3 de la VRAM no calibra. Casi todos los rechazos caían en el mismo camino, `IORQ_n`/`WR_n` del T80 → `config*_ff` y `mapper_reg*` en 27 MHz (cruce de 9,26 ns). Las escrituras a 40h-43h, 45h, 46h y a FCh-FFh pasan ahora por una etapa de registro en 27 MHz, como el 44h desde la v3.7; `tools/cfgreg_sim` (20.000 OUT) da los mismos registros y los mismos pulsos de guardar y reiniciar (su número puede variar en uno, como ya pasaba). La campaña siguiente, pf60k (5087-5113), dio **tres de cinco con margen**: 5107 (0,985 ns), 5099 (0,955) y 5101 (0,526); 5087 −0,022 en otro camino, 5113 sin rutar.

## v3.7.4 (29 de septiembre): el mux de lectura en árbol y el navegador ordenado

Core: dado 4919, 6dae4491 (`_jtag.bin` 51d15fa7), 0,51 ns; campaña pf60g, uno de cinco (los rechazos, `IORQ_n`/`WR_n` → `config*` y `mapper_reg1`: el camino que arregló la 3.7.5). Probada por Albert: el menú, y ahí salió la izquierda fantasma.

- **`cpu_din` por grupos** (8e29cbc, idea de MSXHeroTN): la cadena de ~49 ternarios del mux de lectura de la CPU va en siete grupos contiguos de la lista original, cada uno con su acierto (el OR exacto de sus condiciones) y su valor, resueltos en paralelo y luego en orden; profundidad ~15. Misma prioridad, demostrado con `tools/cpudin_equiv/verify.py` (2d26ae8: yosys con miter y SAT con los `define` de la build, con `DISABLE_BOOT_MENU` y otras cinco combinaciones, y 200.000 vectores en Icarus). El bloque va al final del módulo: la cadena leía señales declaradas miles de líneas más abajo. FPGA_PATCH = 4.
- **Navegador** (bios ee18b2c): ordenado (carpetas primero, alfabético sin mayúsculas, por un índice de un byte por entrada en E600h), sin ficheros ocultos ni de sistema, 112 entradas por carpeta (antes 115) con un `+` en el contador si no caben. Probado en un Z80 de openMSX en las seis variantes de la BIOS.

## v3.7.3 (28 y 29 de septiembre): host USB robusto

Core: dado 4831, f03f2338 (`_jtag.bin` 34caf0d1), 0,87 ns; campaña pf60f, uno de cinco. Banco nuevo `tools/usb_sim/tb_usb_hid_host.sv` con un dispositivo low-speed modelado: el host de nand2mario no enumeraba dispositivos que contestan en 2,75 bits o menos (`start` llegaba tarde al SYNC y el `timing` se congelaba), y el ZLP de la enumeración dejaba la izquierda pegada. Arreglo en `usb_hid_host.v` (8cc6c32): alineación al fin del SYNC, `timing` resincronizado en cada `start`, y limpieza de las direcciones al acabar la enumeración. 22 casos (latencias de 16 a 52 ciclos, fases, ±1,5 % de bit, SNES y teclado). FPGA_PATCH = 3.

## v3.7.2 (28 de septiembre): mandos HID genéricos por los USB-A

Core: dado 4759, 7651149b (`_jtag.bin` 9cde1018), 1,11 ns; campañas pf60c (dos de cinco, sin margen) y pf60d (4759). Un mando genérico como el «USB Gamepad» 0810:0001 enumeraba y no se movía: `usb_hid_host` solo entiende los mandos «SNES USB». `usb_pad_rid.v` (a493cfd) va en paralelo y solo opina cuando el byte 0 del informe es 01h (Report ID): cruceta por el hat o el stick izquierdo con umbrales, botones 1-4 = A/B/X/Y, 5-6 = L/R, 9-10 = SELECT/START; `tb_usb_pad_rid.sv` con 29 informes medidos. Los puertos 20h-27h enseñan el último informe (f774209; build de diagnóstico 4793, da6e0843). Menú (bios 39e201d): ESC sale de Ajustes sin guardar. FPGA_PATCH = 2.

## v3.7.1 (27 y 28 de septiembre): solo arreglos, y el tercer dígito

Albert, el 27 de septiembre: el 60K y el 138K solo reciben arreglos, y cada lote sube el tercer dígito. Core: dado 4679, 3acd3068 (`_jtag.bin` a1ce9ada), 1,24 ns; campañas pf60a (uno de cinco, con 0,13 ns, y los peores caminos en lo tocado: el 29h añadía un escalón al mux de `cpu_din` y un OR de tres modos en el motor de comandos) y pf60b tras corregirlo sin cambiar la función (0d75e64).

- Tres arreglos del V9968 de HRA! y el de HMMM/HMMV/YMMM/HMMC en SCREEN 2 con CMD=1 (f8040e5), portados de la Zynq ([capítulo 05](05-v9968.md)).
- **Puerto 29h = FPGA_PATCH**: el menú imprime «3.7.1» en Ajustes.
- Menú (bios d8d64dd): la cinta ya no se atasca en «Found:» tras buscar con F o configurar la WiFi con W (el EXTBIO del ESP quedaba encadenado a sí mismo en el segundo pase del INIT), y una ROM de más de 4 MB sin firma se lanza como ASCII16-X. Packs del 28 de septiembre: 2.1.4 192eedcb, inglés dcac4bae, Nextor 3 5e76e705, inglés con Nextor 3 ff823b68.

## Porte de la Zynq (24 y 25 de septiembre, interna)

- **ASCII16-X y megaram de 8 MB, Plain 0000h, #46 y ajustes** (ad37e24): los ficheros de la megaram, la DMA y los puertos de la SD de la Zynq; los 4 MB altos van a las filas con el bit 11 del W9825 (`tools/sdr16_tb` T11); el reset conserva los bits 0-2 del 46h; cada escritura en 41h o 42h confirma solo su registro. Menú con los mappers nuevos y **packs en inglés** (bios 36ef763, 9641d1e). Campaña pz60a, cinco de cinco por el gate: 4423, 4421 y 4447 en `files/20260924/`; Albert arrancó el 4421 el 24 de septiembre.
- **Las rayas de arranque del V9968** (37cb6db), del shim de la VRAM, portado de la Zynq. Campaña pz60r: 4519 (0,92 ns) y 4547 en `files/20260925/`; Albert, con el 4519: «va perfecto, sin rayas».

## Pack v3.7c (21 de septiembre): nombres largos huérfanos

Solo el pack; el core no cambia. Albert: un fichero con nombre largo renombrado desde MSX-DOS a `GM2.ROM` seguía saliendo en el menú con el nombre largo viejo (no confundir con los nombres cortos automáticos, que se ven así siempre). Nextor no conoce las entradas LFN (atributo 0Fh): al renombrar o borrar solo toca el 8.3 y deja delante las entradas del nombre largo, y el menú las montaba sin mirar el byte 13 de cada una, que es el checksum del 8.3 al que pertenecen (Windows y Linux las descartan por eso). Ahora el grupo lo abre la entrada con el bit 40h, todas han de llevar el mismo checksum y ese checksum ha de cuadrar con el 8.3 de la entrada corta; si no, se muestra el nombre corto, como en el PC. Lo mismo en el precheck de descargas del File-Hunter: un fichero renombrado ya no cuenta como "ya existe".

Bios 99c8e54: `lfn_group_chk`, `lfn_cks_ok`, variable `LFN_CKS` (#C07C); `lfn_copy13` pasa a un bucle para hacer sitio (el banco #8000 del menú queda con 26 bytes libres, el #A000 con 20). Prueba de ejecución real en openMSX (`tools/test_lfn_openmsx.py`, C-BIOS sin ventana): 12 imágenes de directorio, 26 registros por las dos rutas, y 10 fallan con la lógica vieja. De paso, `build.sh` comprueba en el MSXnano que el blob comprimido no pise las tablas del FM-BIOS en #7051 (quedan 149 bytes; la rama del MSXimus ya lo hacía). Packs: 2.1.4 6bc053db, Nextor 3 b970f75b; los del MSXnano también cambian (38b51673 y 3b40bbe8), sin probar en el nano. Pendiente de placa el caso de Albert y de decidir si se reemplazan los packs de la release v3.7.

## v3.7 publicada (18 de septiembre, tag `v3.7`): dado 4211

Release en GitHub con el core del dado 4211 (`MSXimus_v3.7.fs`, f588b2ef; campaña v37e, 1,010 ns en el clk_86, holds solo la IP DDR3; RTL b5c15ee = v3.7b), los dos packs (Nextor 2.1.4 fb9b6c38 y Nextor 3 10321483), el firmware del C6 (`firmware_esp32c6_v3.7_merged.bin`) y el del BL616 con el host USB apagado (`bl616_v3.7.bin` = eb5d66f, con el partner de Sipeed y el `.ini` de BLDevCube). El 4211 arranca desde un cargador USB-C sin PC. La rama pública pasa a `V3.7` (rama por defecto). El mismo día, la línea 138K publica su v3.7 (dado 4391) en `Papipapito/MSXimus_138`.

## v3.7b (17 de septiembre, noche): la calibración de la DDR3 desde el cargador

En placa, con el 4139: el arranque desde el cargador falla 3 de 5 veces (negro más de 10 s y después el menú sin el logo); el 4153 de respaldo, negro siempre, también desde el PC. En los dos, el LED U12 parpadea solo y más rápido con F11: es el chivato de la v3.6g (cuenta con el reloj de bus), es decir, **la DDR3 de la VRAM no calibra y el MSX corre por debajo**. Igual que el 3557 y el 3623; el 3593 y el 4001 calibran siempre. No es el BL616 (mismo firmware en todos) ni la colocación de la IP (idéntica en nueve dados, buenos y malos, según los informes): es la probabilidad de éxito de cada intento de calibración, que depende del dado y de la alimentación, la "lotería del ojo" de la saga de julio. Un dado que la tenía en ~1/7 (la _128Z) calibraba en 2 s; el 4153 la tiene en ~0.

- **Motor de reintentos escalonado** (b5c15ee, `v9968_ddr3_backend`): 8 intentos de 335 ms como hasta ahora, 4 de 671 ms, 4 de 1,34 s y después de 2,68 s; a partir del 17º (~11 s fallando) el pulso de reset incluye el PLL de 297 MHz, que es lo que hace un apagado y encendido (el remedio de nand2mario para un fallo), y la IP no sale de reset hasta que el PLL reengancha. Nunca se toca nada *durante* un intento (lección de las _129). Un dado que calibra a la primera no nota nada.
- **La espera del arranque pasa de 5 a 10 s**: sin vídeo no hay nada que hacer antes, y así un dado lento calibra sin que el MSX haya arrancado a ciegas y perdido el logo.
- **Puertos 2Ah-2Ch**: intentos fallidos, duración del intento bueno y tiempo total, para que "falla 3 de 5" pase a ser un número por dado (y para saber si un intento normal tarda 30 ms o 300 ms).
- Banco de pruebas del backend con la IP fallando 18 intentos seguidos: ventanas, resets del PLL y contadores como se espera; la suite T1-T9 sigue en verde.
- Campañas de la noche (b5c15ee, cuatro de cinco dados, 23:02-01:31): v37e 4 de 5 pasan el gate (4159 0,081 ns, 4177 0,020, 4201 0,039, **4211 1,010**), v37f 1 de 5 (4231 0,068; 4229 con seis caminos de la propia IP DDR3 sin cerrar), v37g 1 de 5 (**4273 0,465**), v37h 2 de 5 (4289 0,328, **4297 1,616**). Veinte dados, nueve por el gate, tres con margen de entrega: 4297, 4211 y 4273, en `files/20260918/` con un LEEME de cómo medirlos desde el cargador. Los tres llevan el motor nuevo y los puertos; cuál calibra es la lotería del dado.

## v3.7 (17 de septiembre): mezclador de audio por fuente

Pedido de Albert la misma tarde en que la v3.6h arrancó desde el cargador ("ya que estamos"). Es el mezclador que la línea Zynq estrenó ese día (5d3b409), traído tal cual.

Core: dado 4139, 6175b7c5, margen **2,012 ns** (uadpcm, clk_54m), el mejor de la era v3; holds solo la IP DDR3 (0,040). RTL = 82b1b9c (el HEAD 4c163f7 solo añade una etapa de registro en la escritura del 44h, sin cambio funcional). Campaña v37c, cinco dados: 4129 sin rutar, 4133 −0,154 ns en el decodificador del 44h (por eso el registro del HEAD), **4139, 4153 (1,243 ns) y 4157 (1,130 ns) pasan el gate**: 3 de 5, contra el 1 de 5 habitual, por el cierre del cruce de `cpu_run` (abajo). Respaldo: 4153. Packs nuevos obligatorios para ver la página (bios 6db0cf8: 2.1.4 fb9b6c38, Nextor 3 10321483).

- **Puerto 44h extendido**: `{solo_sel, canal, nivel}`. Canal 0 = la ganancia maestra de siempre (compatible con `OUT 44h,0..7`), 1-6 = PSG, SCC, OPLL, MSX-Audio, OPL4 FM, OPL4 wave con nivel 0-8 = k/8 aplicado a cada fuente **antes** de la suma; el 7 (WaveGame) no existe en el Tang (lee Fh, la escritura se ignora, el menú esconde la fila porque el 2Fh es < A0h). Lectura `{0, canal, nivel}` y sonda `OUT 44h,F0h`. Los diez multiplicadores 19×4 caen en DSP (MULTALU27X18: 8 → 18 de 118): LUT +94, ALU −47, es decir, área neutra.
- **Persistencia en la cola del pack**: el bloque de configuración de la flash (0x480000) pasa de 6 a 11 bytes: los 6 de siempre, los 28 bits de niveles en little-endian y un byte de suma (xor ^ A5h). Un bloque viejo de 6 bytes (flash borrada detrás) siembra lo de siempre y deja el mezclador a 8/8; un bloque con la suma mal o un nivel > 8, igual. Testbench en Icarus de la captura y la siembra (cinco escenarios).
- **Error latente arreglado**: `config_init` era la ventana *entre* la captura del penúltimo byte y la del último, así que los consumidores a 27 MHz leían el último byte viejo. Con 6 bytes ese último era la ganancia maestra: probablemente nunca se sembró de la flash en el Tang (nadie lo notó porque el defecto x5 es el valor que se usa). Ahora es un pulso de 4 ciclos tras el último byte, con todo estable; el testbench reproduce el fallo con la ventana vieja.
- El menú (bios 5568de4 + d991daa): fila *Mezclador de audio* en Ajustes con la página de ocho filas, barra de octavos y nota de prueba por chip; en el Tang sin mezclador (3.6h) ofrece solo la ganancia maestra. Los packs nuevos llevan además el arreglo de los SSID en kana del setup WiFi (724ba64).
- Versión del core en el 2Fh: 37h.
- **El peor camino de todos los dados, cerrado** (82b1b9c): el término del refresco autónomo (`cpu_run` = reset & flash_idle & esp_boot_ok & ~iosys_frz & ~dma_rfsh_ok) entraba combinacional desde clk_54m al RESET de los contadores de refresco de la SDRAM en clk_108m, un cruce de 9,26 ns. Fue el peor camino del 4001 (0,771 ns), de los dos marginales de la v36q y tumbó tres de los cuatro dados rutados de la v37a (−1,1, −3,1, −1,2 ns). Vuelve el registro a 54 MHz de la v3.6d (retirada por un negro que resultó ser la DDR3) y `memory.v` lo resincroniza con dos FF a 108 MHz: el cruce es FF → FF sin lógica. El retraso de ~37 ns es inocuo (el T80 tarda ≥ 280 ns en su primer ciclo de bus; la DMA espera 40 ciclos antes de escribir); `tools/sdr16_tb` pasa entero (TZ: 0 refrescos autónomos con el Z80 vivo).
- Campaña v37a (4049-4079, RTL sin ese registro): 4 de 5 rutaron (el mezclador no estorba al rutado), 3 tumbados por ese camino y 4057 por −0,3 ns en `cpu1 → ff_sd_sector`. v37b abortada; v37c con el registro dio los tres dados de arriba.

## v3.6h (17 de septiembre): generación C del V9968 y espera a la DDR3

La última build de la era v3 por decisión de Albert: después de esta, solo errores graves.

Core: dado 4001, c70eae6d, margen 0,771 ns (clk_54m→clk_108m, `u_sddma` → `mem1/rfsh_gap`); holds solo la IP DDR3 (0,040). RTL = 679b8f0 (idéntico en síntesis al HEAD 17/09 con `DIETA_V36H` apagado). PnR 14 min. Campaña v36q, cinco dados: 3947 y 4003 sin rutar (166 y 188 redes), 3989 fuera de gate por -0,006 ns en `ff_flash_state`, 3967 gate OK pero 0,005 ns (respaldo solo para pruebas). Packs: los de la V3.6c sin cambios.

- **V9968 generación C** (679b8f0, traído de la Zynq): R#20 y R#21 se ignoran mientras el bit 7 del puerto #4 (9Ch, y su espejo 8Ch, que ahora se decodifican) esté a 1, que es el estado tras el reset; el puerto #4 devuelve ese bit. Y la máscara del A17 en las bases de tabla en modo V9958. Es lo que saca el marcador de Xevious Fardraut Saga: la BIOS escribe R#20..R#23 = 0 en cada init del VDP y en la generación B eso encendía el modo nativo sin que nadie lo pidiera. Consecuencia: el software de la generación B (DEVCON con 0x9F, V9968DM, la TECH DEMO 0.7.0) no ve el V9968 hasta que haga `OUT (9Ch),0` antes de tocar R#20/R#21.
- **El MSX espera a la DDR3** (856d9c6): el paso a `reset3_n` (streamer del pack y Z80) espera a `ready` del backend DDR3 de la VRAM, con tope de ~5 s para arrancar a ciegas si nunca calibra. Y **el LED de la SD (U12) parpadea solo** mientras la DDR3 no ha calibrado (42c7d1d): el único chivato sin PC. Motivo: los dados 3557 (v36e) y 3623 (v36h) se quedaban en negro desde el cargador y arrancaban desde el USB del PC, con el 3593 arrancando siempre; S1 no lo curaba, lo que apunta a la calibración de la DDR3 y no al core MSX (y exculpa, probablemente, a la v3.6d).
- **La dieta, probada y retirada** (7d0f761, retirada el 17/09): fuera de la build la telemetría serie, la tira WS2812, el ventilador por temperatura y el segundo PSG, y un solo decodificador de teclado; LUT 38.100 → 36.173 (-5,1 %). Con un 5 % menos de lógica el placer 1 rutó **peor**: 0 de 13 colocaciones distintas (v36l/m/n/p), contra 9 de 16 con el netlist completo en la semana anterior; la campaña de control sobre el netlist sin dieta (v36q) rutó 3 de 5 y dio el 4001 al primer intento. Es la lección del 08/08 otra vez: al 96-98 % de CLS manda la congestión local, no el área. La dieta queda como opción (`DIETA_V36H` en `top.v`, apagada) por si sirve en una caza; la producción lleva todo lo de la v3.6g.
- Campaña v36k: los cinco dados murieron en el SDC (una excepción sobre `psg2`, que la dieta había quitado; Gowin aborta ante un objeto inexistente). La línea vuelve con el PSG2; si se compila con `DIETA_V36H` hay que comentarla.
- Campañas v36l, v36m (con `maxfan 50`) y v36n: 0 de 15, todos sin rutar, y con un segundo problema encima de la dieta (3e87b28): el latido mínimo del `dbg_uart` comparaba con `==` y el placer daba la misma colocación para dados distintos (3761 y 3847 idénticos, 3797/3803/3877 idénticos): quince dados que eran unos ocho. Vuelve el `>=` de la telemetría completa. La v36p, ya con dados reales, confirmó el 0 de 5 de la dieta. La v36o (dieta con `place_option 2`) rutó 4 de 5 pero ninguno cerró setup (-0,12 a -0,72 ns): el placer 2 congestiona menos y coloca peor, como se midió el 08/08. `tools/encadenar_campanas.ps1` tira campañas una tras otra (variantes, árboles de control) hasta un gate OK.

## Pendiente

- ~~Xevious Fardraut Saga: el marcador en blanco~~: arreglado con la generación C del V9968 (v3.7); Albert confirma el 30 de septiembre, con la 3.7.6, que va perfecto. El guardado de Manbow 2 (flash AMD en el cartucho) se descarta. Y la fase 3 de la SD (reloj de la tarjeta a 13,5 MHz) también: solo aceleraría la DMA, de 640 a ~1.000 KB/s teóricos, y en el 60K sería una función nueva con campaña al 98 % de CLS. Si algún día hiciera falta velocidad, la palanca es el bus de 4 bits: DAT1-DAT3 están cableados a la FPGA y hoy van fijos a 1.
- ~~Validar un mando USB HID genérico en un USB-A~~: validado con la v3.7.5 el 30 de septiembre. El ratón sin INDEV quedó validado el 16 de septiembre con el 3593.
- La línea 138K: ninguna campaña desde la v3.7 da margen (el V9968 a 88,5 MHz y el cruce CPU → SDRAM); necesita trabajo de timing propio, no más dados, y no hay placa para probarla.
- Entender por qué el `cpu_run` registrado (v3.6d) deja la SDRAM sin arrancar, si es que es él: un segundo dado con y sin el registro lo cerraría.
- Publicar la v3.6: carpeta de release, notas y créditos.
