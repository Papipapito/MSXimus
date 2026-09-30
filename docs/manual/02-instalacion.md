# 02. Instalación

Qué hay que grabar en la placa y con qué herramienta. Todo lo obligatorio va a la flash de la propia placa por el USB-C; las dos piezas opcionales, el ESP32-C6 y el BL616, tienen su propio procedimiento.

## 1. Lo que va a la flash de la placa

Tres ficheros, cada uno a una dirección distinta de la misma flash:

| Fichero | Dirección | Obligatorio |
|---|---|---|
| El core: `MSXimus_v3.7.5.fs` en la release (en las entregas de `files/<fecha>/` se llama `msximus_v3.x_dadoNNNN.fs`) | **0x000000** | Sí |
| El pack de BIOS, `pack_bios_msximus*.bin` | **0x400000** | Sí, sin él la máquina no arranca |
| `yrw801.bin`, la ROM de ondas del MoonSound (va como `.bin` porque el Programmer de Gowin no coge `.rom`; si tienes un `yrw801.rom`, renómbralo) | **0x500000** | No, solo para tener el OPL4 completo |

La release trae los tres, más los firmwares del C6 y del BL616. Con `yrw801.bin` sin grabar todo funciona igual, salvo la tabla de ondas del MoonSound.

**Herramienta**: el [Gowin Programmer](https://www.gowinsemi.com/en/support/download_eda/), gratuito. El que viene con el IDE 1.9.12 va bien.

### Cómo grabar

1. Conecta la placa por USB-C y abre el Gowin Programmer.
2. Deja que detecte el dispositivo: debe decir **GW5AT-60**.
3. Para cada uno de los tres ficheros, configura una operación de escritura en la **flash SPI externa** (las opciones que empiezan por *exFlash*, no las de SRAM), elige el fichero como *Programming File* y escribe **la dirección de la tabla** en el campo de dirección de inicio.
4. Graba primero el core y luego los otros dos. El orden no importa; **las direcciones sí**: si el pack no cae exactamente en 0x400000, la máquina arranca a pantalla negra.
5. **Apaga y enciende la placa.** Un reset no basta: la DDR3 necesita calibrar en frío y puede quedarse colgada tras un reset en caliente.

Si al encender solo hay una pantalla azul, es casi siempre el pack en una dirección equivocada o que falta el apagado y encendido.

Cada entrega del core viene con dos ficheros del mismo bitstream: el `.fs` y un `_jtag.bin`. Para el Gowin Programmer vale el `.fs`. El `_jtag.bin` es el mismo contenido en el formato que usa el flasheador del BL616.

### El pack de BIOS

Hay cuatro packs iguales en todo salvo el idioma del menú y el kernel de disco que llevan dentro:

| Pack | Menú | Nextor |
|---|---|---|
| `pack_bios_msximus.bin` | castellano | **2.1.4**, el estable, el que quieres |
| `pack_bios_msximus_en.bin` | inglés | **2.1.4** |
| `pack_bios_msximus_nextor3.bin` | castellano | **3.0 beta 1**, para probar la beta |
| `pack_bios_msximus_en_nextor3.bin` | inglés | **3.0 beta 1** |

Y de cada uno, una variante internacional y una japonesa, que cambian la BIOS y la SubROM. Quien prefiera montar el pack con sus propias ROMs tiene el [Pack Builder del MSXnano](https://github.com/Papipapito/MSXnano), que las ensambla con Nextor incluido. El [capítulo 04 de la referencia técnica](../tecnica/04-pack-bios.md) describe qué lleva y en qué orden.

Un mismo pack sirve para cualquier core desde la versión 3.5c: el menú y el driver de disco sondean el core y usan lo que tenga.

### Después de grabar

En una placa recién grabada la máquina arranca en el navegador de la tarjeta. Quien prefiera que arranque directamente en el MSX, como un ordenador de siempre: **S** durante el logo, desmarcar **Menú al arrancar** y **Save & Restart**. Es un ajuste guardado en la flash, sobrevive a los apagados, y se vuelve a activar marcándolo. El [capítulo 04](04-menu.md) cuenta el menú entero.

Con eso, una microSD con ROMs y discos, y ya está. El [capítulo 03](03-tarjeta-sd.md) explica cómo prepararla.

## 2. El panel F12: el BL616 (opcional)

La Console 60K lleva un microcontrolador **BL616** cableado a la FPGA de fábrica. Con un firmware, dibuja un panel de estado sobre la imagen del MSX cuando se pulsa **F12**: versión del core, CPU y turbo, tarjeta, ventilador, teclado, red y dos filas de diagnóstico del USB del propio BL616 (*USB* y *Mando*: qué ha enumerado su host en el USB-C OTG; con nada conectado ahí dicen `USB: nada`, y es lo normal). Con F12 otra vez, el juego sigue donde estaba. Es de solo lectura: no hay menú ni cursor.

No cuesta nada en hardware: la línea serie entre los dos chips ya está en la placa. Sin el firmware, el MSX funciona igual; solo falta el panel. Como el BL616 se queda la tecla F12, el turbo va en **F11**.

Dos imágenes que conviven, la de Sipeed se queda donde está:

| Fichero | Dirección |
|---|---|
| `bl616_fpga_partner_60kConsole.bin`, el de Sipeed, incluido en la release | 0x0 |
| `bl616_v3.x.bin` | 0x40000 |

1. **Mantén pulsado el botón BOOT mientras conectas el USB.** Eso pone el chip en modo ISP.
2. Aparece un **puerto COM nuevo**: ese es el BL616. Listar los puertos antes y después de conectar es la forma fácil de saber cuál.
3. Abre **BLDevCube** (el [Bouffalo Lab Dev Cube](https://github.com/bouffalolab/bouffalo_sdk)) y carga el `flash_prog_cfg.ini` de la release: ya lleva las dos imágenes con sus direcciones. Tiene que estar en la misma carpeta que los dos `.bin`.
4. Desconecta, vuelve a conectar, y apaga y enciende la placa.

El modo ISP vive en la ROM del chip, no en su flash, así que funciona escriba lo que se escriba: no se puede dejar la placa inservible por aquí.

## 3. La WiFi: el ESP32-C6 (opcional)

Sin él el core funciona igual; solo falta la red. El módulo es la Waveshare **ESP32-C6-LCD-1.3**, que además de la WiFi trae una pantalla de 240×240 donde se ve el estado.

### Cableado

Cuatro cables, o cinco con el indicador de turbo, entre el conector **J10** de la placa y el módulo:

| Pin J10 | Señal | Lado del C6 |
|---|---|---|
| **11** | +5 V | **5V**, tira derecha, el último |
| **12** | GND | **GND**, tira derecha |
| **14** | TX, FPGA → C6 | **IO17**, tira izquierda |
| **16** | RX, FPGA ← C6 | **IO16**, tira izquierda |
| **18** | Turbo, FPGA → C6 | **GPIO3**, tira derecha, el primero. Opcional: solo alimenta el indicador de la pantalla |

- **J10 es el conector 2×20 libre**, el que Sipeed llama *SDRAM1 CONN.* en el esquema. No es el que lleva el módulo SDRAM del core.
- **Sin serigrafía**: con la placa apagada y un polímetro en continuidad, **el pin 12 es el único de todo el conector con camino a masa**. Su compañero de fila es el 11, y desde el 12 hacia el lado largo del conector, el que deja catorce filas y no cinco, vienen el 14, el 16 y el 18. Un cable plano de una hilera en esa columna resuelve todo.
- La alimentación sale del propio J10. El USB-C del módulo solo hace falta para grabar su firmware.
- **Mejor no tener las dos alimentaciones a la vez.** El módulo tiene protección, pero al grabar por USB-C conviene soltar el cable de 5 V o apagar la placa.
- TX y RX van cruzados. La línea va a 859372 baudios.
- Si algún día se pincha un segundo módulo SDRAM en J10, el ESP tiene que mudarse.

### El firmware del C6

Vive en su propio repositorio, [ESP32-for-FPGA](https://github.com/Papipapito/ESP32-for-FPGA); el mismo binario sirve para el MSXimus y para el MSXnano. La release trae el binario fusionado, `firmware_esp32c6_*_merged.bin`, que se graba por el **USB-C del módulo**, sin Arduino y sin compilar nada:

- **Desde el navegador**, sin instalar nada: [esptool-js](https://espressif.github.io/esptool-js/), el flasheador web de Espressif, en Chrome o Edge. Conectar, elegir el fichero, dirección 0x0, Program.
- **Por línea de órdenes**, si ya se tiene esptool:

```bash
esptool --chip esp32c6 --port COMx write_flash 0x0 firmware_esp32c6_merged.bin
```

No hay ruta de arrastrar y soltar como en una Raspberry Pi Pico: el ESP32 no tiene cargador de almacenamiento masivo en ROM. El flasheador web es lo más parecido.

Con el módulo cableado y con firmware, la pantalla enseña el logo MSX al encender y luego el estado: red, turbo, reloj. La red se configura desde el MSX con la tecla **W** del menú ([capítulo 07](07-wifi-file-hunter.md)).

Así queda montado dentro de la carcasa impresa: el módulo en su bahía con el USB-C accesible, y los cables al J10 de la placa, fijados con silicona para que no se muevan:

<p align="center"><img src="../img/carcasa/c6_bahia_cableado.jpg" alt="El ESP32-C6 en su bahía, cableado al J10 de la Console 60K y fijado con silicona" width="820"/></p>

## 4. La carcasa (opcional)

Hay una carcasa para imprimir en 3D con la forma de un Spectravideo SVI-728: la placa atornillada al suelo, el ESP32-C6 con su pantalla en una bahía con tapa, el ventilador en la trasera, HDMI y USB sacados atrás y dos USB-A al frontal. El proyecto de Bambu Studio, los STL, los ajustes de impresión y las notas de montaje están en [`carcasa/`](../../carcasa/README.md).

<p align="center"><img src="../img/carcasa/carcasa_trasera.jpg" alt="La trasera de la carcasa: ventilador, HDMI y USB" width="820"/></p>

## 5. Actualizar

Un core nuevo se graba igual que la primera vez, solo el `.fs` en 0x000000, y apagar y encender. Un pack nuevo, solo el pack en 0x400000. Los ajustes guardados se conservan: el pack mide 512 KB justos y los seis bytes de configuración que van detrás, en 0x480000, no los toca el programador. En una placa recién grabada esos bytes están vacíos y el core arranca con los valores de fábrica, con el menú al arrancar activado; el primer Save & Restart los escribe. El `yrw801.bin` no cambia entre versiones.
