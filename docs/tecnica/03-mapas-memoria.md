# 03. Mapas de memoria

Cuatro mapas distintos y cómo se relacionan: lo que ve el Z80 (slots y páginas), lo que hay en la SDRAM física, lo que hay en la flash y lo que va a la DDR3. Sale del mux de direcciones de `fpga/top.v`, de `fpga/src/megaram.v`, de `fpga/src/gm2_slot1.v` y del script que monta el pack en el repositorio de la BIOS.

## 1. Lo que ve el Z80: slots

| Slot | Página 0 (0000-3FFF) | Página 1 (4000-7FFF) | Página 2 (8000-BFFF) | Página 3 (C000-FFFF) |
|---|---|---|---|---|
| **0-0** | BIOS principal | BIOS principal | | |
| 0-1 | | | | |
| **0-2** | | ROM UNAPI del ESP (16 KB) | | |
| **0-3** | | Logo de arranque (16 KB) | | |
| **1** | | Segundo SCC o Game Master 2 | Segundo SCC o Game Master 2 | |
| **2** | | Megaram, cuando el menú la mueve aquí al lanzar una ROM | Megaram | |
| **3-0** | Mapper | Mapper | Mapper | Mapper |
| **3-1** | SubROM (16 KB) | Menú + FM-BIOS (16 KB) | Segunda página del menú (16 KB) | |
| **3-2** | | Nextor: kernel paginado y ventana de la SD | Nextor | |
| **3-3** | | Megaram en su posición de arranque | Megaram | |

Los slots 0 y 3 son expandidos; el 1 y el 2 no. Es el reparto de un MSX2+ de Panasonic con el disco en el slot 3-2, más el cartucho emulado en el 2.

Detalles que importan:

- **El mapper** son 2 MB en 128 segmentos de 16 KB. Los registros FCh-FFh son de solo escritura y el bit 7 se ignora: los segmentos 128 a 255 son alias de los 0 a 127.
- **El menú corre desde ROM**, como un cartucho de 32 KB, en las páginas 1 y 2 del slot 3-1. Antes se descomprimía en RAM; ahora la página 2 ocupa la ventana que tenía el driver kanji del MSXnano, que en el MSXimus no existe. La fuente kanji sí, por puertos.
- **Nextor** ocupa el slot 3-2 con su kernel de 128 KB paginado en 6000h, y en la página 1 lleva además la **ventana de la SD**: 7C00h-7DFFh es el búfer de sector y 7E00h-7EFFh son los registros del controlador, activos solo cuando se ha escrito un 1 en 7E00h. Es el interfaz WonderTANG original; el capítulo 06 lo detalla.
- **La megaram** arranca en el slot 3-3 (config 1 = F3h). Al lanzar una ROM, el menú manda la orden 0Fh al dispositivo OCM, que la pasa a modo SCC-I y la mueve al slot 2; ahí es donde el juego la encuentra como cartucho. El segundo SCC, si está activo, ocupa el slot que no tiene la megaram: normalmente el 1.
- **El slot 1** es del segundo SCC si Ajustes lo pide, o del Game Master 2 cuando el menú lo arma para un juego Konami. Si no, no responde.
- La **BIOS principal** del pack está parcheada con la corrección de interrupciones del MSXnano; hay dos variantes de pack, internacional y japonesa, que cambian BIOS y SubROM.

## 2. La SDRAM física: 8 MB

El controlador direcciona 8 MB con 23 bits para la CPU (filas 0-2047 del W9825) y, desde el 24 de septiembre de 2026, un bit 23 más que va a la **fila 11**: las filas 2048-4095, que estaban libres, guardan los 4 MB altos de la megaram de 8 MB (apartado 3); por encima, en las filas 4096 y siguientes, fuera del alcance de cualquier mapeo de la CPU, viven los 4 MB de la familia de ondas del OPL4 (la YRW801 de 2 MB copiada de la flash al arrancar, por el puerto `wv` de `memory_ctrl`) y, en las filas 5120+, los 256 KB de muestras del ADPCM del Y8950 (`adpcm_sdram`, puerto `wv2`). Roban turnos vacíos de la CPU y no compiten con ella.

El controlador direcciona 8 MB con 23 bits. Los cuatro bancos de 2 MB se reparten así:

| Rango | Banco | Contenido | Bits altos de la dirección |
|---|---|---|---|
| 000000-1FFFFF | A | Mapper de RAM, 2 MB | 00 |
| 200000-3FFFFF | B | Megaram, mitad alta (A21 = 1), y el Game Master 2 | 01 |
| 400000-5FFFFF | C | Megaram, mitad baja (A21 = 0), 2 MB | 10 |
| 600000-7FFFFF | D | El pack de BIOS, la fuente kanji y la VRAM de respaldo | 11 |

La megaram está partida en dos bancos a propósito. Hasta la versión 3.5 era de 2 MB y vivía en el banco C; el mapper ocupaba A y B. Al recortar el mapper a 2 MB, la megaram creció a 4 MB quedándose con el B, y la traducción es un simple cruce de bits, sin sumador: la dirección física es `{~A21, A21, A[20:0]}`. Todo lo que cabía en 2 MB sigue en las mismas direcciones que antes.

El banco D, en detalle:

| Dirección física | Tamaño | Contenido | Origen en el pack |
|---|---|---|---|
| 700000-73FFFF | 256 KB | Fuente kanji JIS1 y JIS2 | 00000 |
| 740000-75FFFF | 128 KB | Nextor (kernel y driver) | 40000 |
| 760000-767FFF | 32 KB | BIOS principal | 60000 |
| 768000-76BFFF | 16 KB | SubROM | 68000 |
| 76C000-76FFFF | 16 KB | FM-BIOS + menú, primera página | 6C000 |
| 770000-773FFF | 16 KB | Menú, segunda página | 70000 |
| 774000-777FFF | 16 KB | Reserva, a FF | 74000 |
| 778000-77BFFF | 16 KB | ROM UNAPI del ESP | 78000 |
| 77C000-77FFFF | 16 KB | Logo de arranque | 7C000 |
| 7C0000-7FFFFF | 256 KB | VRAM, solo en la línea de respaldo con la VRAM en SDRAM | |

El pack se copia entero, 512 KB, desde 700000. Cada región del banco D es exactamente el pack más 700000, lo que hace trivial comprobar en placa que el streaming ha ido bien.

## 3. La megaram: 8 MB y sus rincones reservados

La megaram es el cartucho emulado del slot 2. El menú carga ahí la ROM y configura el mapper con el que se va a comportar: Konami, Konami-SCC, ASCII8, ASCII16, NEO-8, NEO-16, Plain 0000h o ASCII16-X.

Desde el 24 de septiembre de 2026 (porte de la Zynq) mide **8 MB**: los 4 MB de siempre y otros 4 MB altos que solo alcanza el ASCII16-X, con bancos de 12 bits. La dirección física es `{A22, ~A22 & ~A21, A21, A[20:0]}` y el bit 23 de la dirección de la SDRAM va a la fila 11, así que con A22 = 0 todo sigue exactamente donde estaba; la DMA los llena armada con 81h (bit 23). Todo lo que sigue habla de los 4 MB bajos, que es donde viven los rincones reservados. Los registros de banco son de 9 bits; en los mappers de 8 bits el noveno es siempre 0, y en ASCII16 y los NEO llega desde el propio registro. Para llenar la mitad alta durante la carga, que se hace en modo SCC con registros de 8 bits, el menú usa el bit 4 del puerto 46h.

Los 512 segmentos de 8 KB tienen dueño:

| Segmentos | Uso |
|---|---|
| 0-255 | Mitad baja. Toda ROM de hasta 2 MB cabe aquí |
| 256-479 | Mitad alta, libre para ROMs de más de 2 MB |
| 480-495 | ROM del Game Master 2 (128 KB), cuando está armado |
| 496 | SRAM del Game Master 2 (8 KB) |
| 497 | Descriptor "GM2S" del guardado del Game Master 2 |
| 498-510 | Libres |
| 511 | Descriptor "SRM1" del guardado de SRAM de cartucho |

La **SRAM de cartucho** de los ASCII8 y ASCII16 se emula en los segmentos 252 a 255, los últimos 32 KB de la mitad baja. Los descriptores de guardado viven en la mitad alta porque un juego normal no llega ahí; una ROM de 4 MB sí la pisa, y por eso con ellas no hay guardado ni Game Master 2.

El mecanismo de guardado depende de que la SDRAM sobreviva al reset del MSX, que lo hace: el menú, al arrancar de nuevo, comprueba el descriptor y el checksum y reescribe el fichero en la tarjeta si la SRAM ha cambiado.

## 4. La flash: 8 MB compartidos con el BL616

| Dirección | Tamaño | Contenido |
|---|---|---|
| 000000-3FFFFF | 4 MB | Bitstream de la GW5AT-60 (unos 2,3 MB) y margen |
| 400000-47FFFF | 512 KB | Pack de BIOS |
| 480000-480005 | 6 bytes | Configuración: 'A', 'B', config 1, config 2, turbo al arrancar ('T'), ganancia (C0h + valor) |
| 480006-4FFFFF | | Libre |
| 500000-6FFFFF | 2 MB | ROM de ondas YRW801 del OPL4 |
| 700000-7FFFFF | 1 MB | Libre |

El pack se flashea en 400000 y el core lo copia a la SDRAM en cada encendido. El mismo streaming que copia los 512 KB lee los once bytes siguientes: los seis primeros van a los registros 41h, 42h, 45h y 44h y los cuatro de niveles del mezclador, con su byte de suma, a los atenuadores del 44h (desde la v3.7). El menú, al hacer Save & Restart, reescribe solo esos once bytes. Desde el 9 de septiembre de 2026 el pack del MSXimus mide 512 KB justos, sin esa cola: así grabar un pack nuevo no pisa los ajustes guardados (se perdió dos veces en un día el "Slot 1 = Game Master 2" por eso). El pack del MSXnano sí la lleva.

Si la cola no empieza por 'AB' el core no la carga y se queda con los valores de fábrica: config 1 = F3h (mapper en 3-0 y megaram en 3-3 activos, segundo SCC y scanlines apagados), config 2 = 0Fh (SD activa en el slot 3-2 y menú al arrancar), sin turbo y ganancia 5. Con el botón S2 pulsado en el encendido pasa lo mismo aunque la cola sea válida: es el rescate.

## 5. La DDR3 del SOM: un solo cliente

La DDR3 tiene un único cliente: el backend de vídeo, con los 256 KB de VRAM del V9968, escritos todo el tiempo por el shim. Las ondas del OPL4 no van aquí desde la _104: el **cargador de ondas** copia los 2 MB de la YRW801 desde la flash a la región de ondas de la SDRAM (apartado 2), una vez, en segundo plano, tras copiar el pack; el bit 2 del puerto 36h dice que sigue copiando.

El controlador sigue la receta de nand2mario para esta placa: PLL a 297 MHz, órdenes de ráfaga de 128 bits y refresco automático activado. Si no calibra al encender, el core reintenta con ventanas cada vez más largas (capítulo 05 y el 10 del manual).

## 6. Qué comparte el camino de streaming

Cuando la CPU está parada, la SDRAM la escriben dos fuentes por el mismo camino: el streamer de la flash al arrancar y la DMA de la SD. Ninguna de las dos pasa por el decodificador de slots; escriben direcciones físicas de 23 bits directamente:

- El streamer escribe siempre en el banco D, desde 700000.
- La DMA escribe donde le diga el menú o el driver: en la megaram, con dirección física, o en el mapper, con una dirección lógica del Z80 que el core traduce con los registros FCh-FFh (capítulo 06).

## 7. Referencias cruzadas

- Cómo se decide en el core cada región del mux: `fpga/top.v`, el comentario "sdram map" y el `assign ram_addr`.
- El pack, ROM a ROM: `tools/desmontar_pack.py` y `tools/hacer_packs.py` en el repositorio de la BIOS.
- El guardado de SRAM y el Game Master 2 desde el lado del menú: capítulo 04 del manual.
