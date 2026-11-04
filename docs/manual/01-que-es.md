# 01. Qué es el MSXimus

Un **MSX2+ completo dentro de una FPGA**, en la placa Sipeed Tang Console 60K. No necesita un MSX: es un MSX. Se conecta a un televisor por HDMI, se le enchufa un teclado USB y arranca en un MSX-DOS o en un menú desde el que se lanzan juegos y discos guardados en una tarjeta microSD.

Es el hermano mayor del [MSXnano](https://github.com/Papipapito/MSXnano): la misma línea de core (goauld, luego MSXnano), portada a una placa con más recursos y ampliada con lo que en la pequeña no cabía. Nano era el pequeño; Maximus el grande.

## Lo que trae

| | |
|---|---|
| **CPU** | Z80 a 3,58 MHz, con turbo a 5,37 MHz al estilo Panasonic (tecla F11) y la identificación de turbo R que el software consulta |
| **Vídeo** | El **V9968** de HRA!, un V9958 ampliado con 256 KB de VRAM, comandos rápidos, paleta de 32768 colores y sprites multicolor escalables. Salida HDMI a 720p, con bordes como un monitor de tubo y scanlines opcionales |
| **Audio** | PSG, dos SCC, OPLL (MSX-MUSIC), MSX-Audio Y8950 con ADPCM, y el MoonSound completo: OPL4 con FM y tabla de ondas. Mono o estéreo por el HDMI |
| **Memoria** | 2 MB de RAM mapeada y una megaram de 4 MB para el cartucho emulado |
| **Almacenamiento** | Nextor sobre microSD. Lanza ROMs de hasta 4 MB con los mappers Konami, Konami-SCC, ASCII8, ASCII16, NEO-8 y NEO-16, y discos `.dsk` |
| **Guardado** | La SRAM de los cartuchos ASCII y el Game Master 2 de Konami se guardan en la tarjeta |
| **Entrada** | Teclado, mando y ratón USB directos a la placa, sin hub |
| **Red** | WiFi UNAPI con un ESP32-C6 externo, con pantalla de estado opcional, y descarga de ROMs y discos desde el propio menú |
| **Panel** | Un panel de estado sobre la imagen con la tecla F12, dibujado por el microcontrolador BL616 que la placa ya trae |
| **Extras** | Logo de arranque, ventilador controlado por temperatura, dos BIOS a elegir (internacional y japonesa), y un menú de pruebas para diagnosticar |

## Lo que hace falta

| | Qué | Notas |
|---|---|---|
| **Obligatorio** | [Sipeed **Tang Console 60K**](https://wiki.sipeed.com/hardware/en/tang/tang-console/mega-console.html) | Con el módulo SOM Tang Mega 60K (Gowin GW5AT-60), HDMI, dos USB-A, microSD y DDR3 |
| **Obligatorio** | El **módulo SDRAM** de la Console | Es la memoria del MSX. Sin él el core no arranca |
| **Obligatorio** | Una **microSD** de marca, clase 10, en FAT16 | Las tarjetas sin marca leen bien pero pierden escrituras en ráfagas largas. Está medido en el banco: una sin marca fallaba escrituras aunque se le diera tiempo y una Samsung EVO+ no falló ninguna con el mismo código |
| Recomendado | Disipador de 20×20 mm sobre el SOM | El core mantiene el chip ocupado |
| Opcional | Ventilador de 5 V de 20×20 mm, conector JST de 1,25 mm y dos pines | El core lo gobierna solo con el termómetro interno del chip; parado si no hace falta |
| Opcional | Teclado y mando USB | Directos a los USB-A de la placa |
| Opcional | Ratón USB **con cable** | Un receptor inalámbrico no funciona: se presenta como dispositivo compuesto |
| Opcional | **ESP32-C6** Waveshare C6-LCD-1.3 | Para la WiFi y su pantalla. Tres cables y la alimentación desde la placa |
| **Obligatorio** | Nada que comprar: el **BL616** de la placa | Hay que flashearle el firmware del MSXimus una vez y **antes que nada**: de fábrica lleva el de Sipeed y es lo que sale al encender. Además da el panel F12 |
| Opcional | Una **carcasa** impresa en 3D | Con forma de Spectravideo SVI-728, con sitio para la placa, el C6 con su pantalla y el ventilador. Los ficheros y las fotos están en [`carcasa/`](../../carcasa/README.md) |

## Lo que no es

- No es un turbo R: se identifica como tal para que el software que lo consulta funcione, pero no hay R800.
- No tiene salida de vídeo ni de audio analógicos. Todo va por el HDMI.
- No tiene conectores de joystick, ni de casete, ni de impresora. Los mandos van por USB.
- No lleva la variante de VDP V9958: el V9968 es el único, y es compatible con todo lo que espera un V9958.

## Cómo seguir

El [capítulo 02](02-instalacion.md) explica qué flashear y dónde. El [03](03-tarjeta-sd.md), cómo preparar la tarjeta. El [04](04-menu.md), el menú tecla a tecla. Los siguientes van tema por tema: ROMs, discos, red, audio, vídeo y problemas. Quien quiera saber cómo está hecho por dentro tiene la [referencia técnica](../INDICE.md#referencia-técnica-docstecnica).
