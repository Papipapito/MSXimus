# 04. El pack de BIOS

Qué es el fichero de 512 KB que se graba en 0x400000, qué ROMs lleva y en qué orden, cómo se construye y por qué es el mismo para todos los cores desde la 3.5c. Sale del repositorio `bios-msxnano-msximus`: sus scripts `build.sh`, `tools/hacer_packs.py` y `tools/desmontar_pack.py`, y el fuente del menú.

## 1. Qué es

Una **concatenación pura** de diez ROMs, sin cabecera ni índice. El core sabe qué hay en cada desplazamiento porque está cableado en el RTL: copia los 512 KB a la SDRAM al arrancar, en 700000h, y cada región del banco D es exactamente el pack más esa base ([capítulo 03](03-mapas-memoria.md)).

| Desplazamiento | Tamaño | Contenido | Slot donde aparece |
|---|---|---|---|
| 00000 | 128 KB | Fuente kanji JIS1 | Por puertos D8-DB |
| 20000 | 128 KB | Fuente kanji JIS2 | Por puertos D8-DB |
| 40000 | 128 KB | **Nextor**: kernel en los bancos 0 a 6, driver de la SD en el banco 7 | 3-2 |
| 60000 | 32 KB | BIOS principal MSX2+ | 0-0 |
| 68000 | 16 KB | SubROM MSX2+ | 3-1, página 0 |
| 6C000 | 16 KB | BIOS MSX-MUSIC y, desde 4760h, **el menú** | 3-1, página 1 |
| 70000 | 16 KB | **Segunda página del menú** (antes, el driver kanji) | 3-1, página 2 |
| 74000 | 16 KB | A FF (antes, el resto del driver kanji) | |
| 78000 | 16 KB | ROM UNAPI del driver de red | 0-2, página 1 |
| 7C000 | 16 KB | Logo de arranque | 0-3, página 1 |

El pack del MSXimus mide **512 KB justos**. Detrás, en 0x480000 de la flash, van seis bytes de configuración que escribe el menú con Save & Restart y que el pack no incluye desde el 9 de septiembre de 2026, para que grabar un pack no pise los ajustes. El pack del MSXnano sí lleva esa cola.

## 2. Las ROMs y su procedencia

| ROM | Fichero | De dónde |
|---|---|---|
| Kanji JIS1 y JIS2 | `a1xxjis1.rom`, `a1xxjis2.rom` | Las de un Panasonic FS-A1FX. Propietarias |
| Nextor 2.1.4 | `Nextor-2.1.4.MSXimus.ROM` | Kernel de Nestor Soto (Konamiman) más el driver de la SD, hecho aquí sobre el del WonderTANG de Luis Antoniosi (BSD-2). Se compila en `nextor214/` |
| Nextor 3.0 beta 1 | `Nextor-3*.ROM` | El mismo driver, portado al kernel 3. Se compila en `nextor3/` |
| BIOS principal, internacional | `32k_msx2p_int_fix.bin` | La BIOS japonesa de Panasonic con 49 bytes cambiados: juego de caracteres, teclado y BASIC internacionales, el glifo del yen convertido en barra, el color del borde. Propietaria |
| BIOS principal y SubROM, japonesas | `a1wsxyen.rom`, `2pextrtc.rom` | Las del Panasonic FS-A1WSX. Propietarias |
| SubROM internacional | `16k_msx2p_subrom.bin` | Propietaria |
| FM-BIOS | Dentro de `16k_msx2p_fm_logo_menu.bin` | La BIOS de MSX-MUSIC, propietaria, con el menú detrás |
| Driver de red | `esp8266e.rom` | El driver TCP/IP UNAPI de ducasp, binario |
| Logo | `logo16k.bin` | Propio, generado con `make_logo16k.py` |

Como lleva ROMs propietarias, el pack **no se publica en el repositorio**: la carpeta `packs/` está en el `.gitignore` y el usuario lo descarga de la release. Quien tenga sus propias ROMs puede montarlo con el Pack Builder del MSXnano.

`tools/desmontar_pack.py` corta un pack por esos desplazamientos y comprueba, reconcatenando, que reproduce el original byte a byte. Así se recuperaron las ROMs que faltaban en disco y así se verifica cualquier pack que llegue.

## 3. El menú: 32 KB en ROM

El menú de la BIOS ([capítulo 04 del manual](../manual/04-menu.md)) es un programa en ensamblador que se ejecuta como cartucho desde el slot 3-1. Hasta la versión 3.5 se descomprimía en RAM; ahora corre desde la ROM, con 32 KB repartidos así:

| Dirección Z80 | Qué |
|---|---|
| 4000-475F | La FM-BIOS de siempre, intacta |
| 4760-7050 | **Página 1 del menú**: rutinas que no pueden conmutar la página 1 (guardados, Game Master 2, DMA, pruebas) y la entrada del cartucho |
| 7051-7FFF | Tablas de la FM-BIOS, intactas. El ensamblado comprueba que no se pisan |
| 8000-9FFF | **Banco de código** del menú, en la página 2 |
| A010-BFFF | **Banco de datos**, con las rutinas que necesitan conmutar la página 1 |
| C000-E7FF | Variables y búferes en RAM; E800 en adelante se conserva entre pases |

Los dos bancos de la página 2 llevan guardas (`ds #A000-$` y `ds #C000-$`) que hacen fallar el ensamblado si el código crece más de la cuenta. Una regla de esa estructura que costó una regresión: **nada de lo que se llame durante una sesión de red de File-Hunter puede vivir en la página 1**, porque durante la sesión la página 1 es la ROM del ESP.

Un solo fuente sirve para las dos máquinas: `MSXIMUS=1` o `0` en `menu_main.asm`, y el resto son bloques `IF MSXIMUS`. El MSXnano se queda con el menú de 16 KB descomprimido en RAM; el MSXimus, con el de 32 KB.

Desde el 24 de septiembre de 2026 cada máquina tiene **cuatro packs**: el menú en castellano o en inglés (`ENGLISH=1`, sufijo `_en`) por Nextor 2.1.4 o 3 (sufijo `_nextor3`). `tools/hacer_packs.py` los hace todos de una vez.

El navegador ordena la carpeta desde la v3.7.4 (29 de septiembre): la tabla de entradas se llena en el orden de la FAT y se ordena un **índice de un byte por entrada**, `SORT_IDX` en E600h, alineado a página, por inserción binaria (carpetas primero, luego nombre sin mayúsculas). `ent_addr`, el único acceso del navegador a una entrada, lee a través del índice. Por eso la capacidad bajó de 115 a 112 entradas; el byte siguiente, `LIST_FULL`, vale `+` si no cabían todas. El filtro del escaneo descarta volumen, ocultos y sistema (máscara 0Eh del atributo). Los bancos de prueba, en un Z80 de openMSX, están en `tools/test_navegador/` del repo de la BIOS: `gen_test.py` (la ordenación), `scan_test.py` (un directorio FAT16 de punta a punta) y `browse_test.py` (el navegador con teclas reales y, con `--joy-left`, un joystick con la izquierda atascada).

## 4. Construir

Todo desde WSL:

```bash
./build.sh msximus          # ensambla el menu con asmsx y lo inyecta en la FM-BIOS
python tools/hacer_packs.py # monta los cuatro packs: 2 maquinas x 2 Nextor
```

`build.sh` ensambla `menu_main.asm` con `asmsx`, comprueba que la parte de la página 1 no pisa las tablas de la FM-BIOS, y deja `out/bios_msximus.bin` (los 16 KB de 6C000) y `out/bios_msximus_p2.bin` (los de 70000).

`hacer_packs.py` parte del pack anterior de cada máquina, reescribe las ventanas que cambian (menú, segunda página, logo, Nextor) y guarda el anterior en `packs/historico/`. Para la línea de Nextor 3 toma la ROM más nueva que haya en `nextor3/`: para actualizar la beta basta con dejar ahí su ROM de 128 KB. Imprime el md5 de cada pack, que es lo que se anota en cada entrega.

El driver de la SD se compila aparte, con `make` en `nextor214/` y en `nextor3/`, usando los ensambladores de cada kernel; el fichero `sd_rw_ports.inc` es común a los dos.

## 5. Un pack para todos los cores

El menú y el driver sondean el core en cada arranque y usan lo que encuentran, con las firmas del [capítulo 06](06-sd-dma.md): puertos de la SD, cronómetro, DMA, modo lógico. Un core de la 3.5c va con la ventana de memoria y el escaneo por software; uno de la 3.6c con DMA y contadores. Por eso una entrega nueva del core no obliga a regrabar el pack, y una entrega nueva del pack no obliga a regrabar el core, salvo que el LEEME de la entrega diga lo contrario.

Lo que un core tiene que tener para arrancar un pack actual: el menú de 32 KB en ROM exige la ventana de la segunda página en el slot 3-1, que existe desde la 3.5. Con un core anterior el menú no arranca.

## 6. El pack de pruebas de escritura

En `packs/herramientas/` hay packs que en vez del menú llevan la prueba de escritura en crudo de la SD (la tecla C de las versiones antiguas). Sirven para calificar tarjetas: escriben y verifican en un cluster libre sin tocar el sistema de ficheros. No son para uso normal.
