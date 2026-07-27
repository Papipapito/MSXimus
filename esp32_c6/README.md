# Firmware del ESP32-C6 del MSXimus

Este directorio es la **copia de trabajo del MSXimus** del firmware que corre en el
módulo **Waveshare ESP32-C6-LCD-1.3** (WiFi UNAPI + pantalla de estado + cinta TSX).

## Por qué está aquí (bifurcación, 2026-07-27)

Hasta hoy el MSXimus y el [MSXnano](https://github.com/Papipapito/MSXnano) compartían
firmware. El MSXnano **cambia de pantalla**, así que los caminos se separan: el
**ESP32-C6 pasa a ser el módulo definitivo del MSXimus** y su firmware vive aquí.

Estado del código: rama `msximus` del clon de trabajo
(`proyectosAI/msx/ESP32-UNAPI-Firmware`), bifurcada de la rama `msxnano` en el commit
`a9416ad`. El título del LCD es **neutro** (`DEVICE_NAME "MSX"` en `Display.ino`)
porque el firmware sigue sirviendo a las dos máquinas mientras convivan.

## Procedencia y licencia

Fork de **[ducasp/ESP32-UNAPI-Firmware](https://github.com/ducasp/ESP32-UNAPI-Firmware)**
— © 2019-2026 Oduvaldo Pavan Junior (ducasp), © 2026 Leo Manes, HTTP © 2025 Jeroen
Taverne. **LGPL-2.1** (ver [LICENSE](LICENSE)); los avisos de copyright de cada fichero
se conservan intactos. Añadidos locales del ecosistema MSXnano/MSXimus: `Display.ino`
(pantalla de estado del LCD) y el bloque de cinta (`Tape.ino`, `TapeWeb.ino`,
`tsx2cvs.h`, `tsxcatalog.h`).

## Compilación

```
arduino-cli compile --fqbn esp32:esp32:esp32c6:PartitionScheme=huge_app .
```

Flasheo por el **USB-C del propio módulo** (no toca la placa Tang):

```
esptool --chip esp32c6 --port COMx write_flash 0x0 <fichero>.merged.bin
```

El binario de cada release se publica como asset junto al bitstream.

## Conexión con la FPGA (Tang Console 60K)

Conector **J10**, columna par, cuatro pines consecutivos — cable plano de 4 hilos:

| Pin J10 | Señal | Bola FPGA | Lado C6 |
|---|---|---|---|
| 12 | GND | — | GND |
| 14 | TX (FPGA → C6) | W21 | IO17 |
| 16 | RX (FPGA ← C6) | N17 | IO16 |
| 18 | TURBO (FPGA → C6) | N13 | GPIO3 |

El módulo se alimenta por su propio USB-C. UART UNAPI a 859372 bps (prescaler 27M/31
en `wifi_lite.vhd`). El pin de turbo es opcional: sin él, `Display.ino` muestra
"Normal" (entrada con pull-down).
