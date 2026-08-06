<p align="center"><img src="docs/logo/msximus.svg" alt="MSXimus" width="480"/></p>

<h1 align="center">MSXimus</h1>
<p align="center"><b>Un MSX2+ completo, en una Tang Console 60K — ahora con el VDP V9968</b></p>
<p align="center">
  <img alt="version" src="https://img.shields.io/badge/versi%C3%B3n-v2.1-blue">
  <img alt="fpga" src="https://img.shields.io/badge/FPGA-Gowin%20GW5AT--60-green">
  <img alt="licencia" src="https://img.shields.io/badge/licencia-GPLv3-orange">
</p>

<p align="center">🇬🇧 <a href="README.md">English version</a></p>

<p align="center"><img src="docs/img/v9968_devcon.jpg" alt="La demo DEVCON del V9968 corriendo en el MSXimus" width="820"/></p>
<p align="center"><i>La demo oficial del V9968 de HRA!, corriendo en el MSXimus.</i></p>

---

**MSXimus** es el hermano mayor del [**MSXnano**](https://github.com/Papipapito/MSXnano): el mismo linaje de core MSX2+ (goauld → MSXnano), portado y ampliado sobre la **Tang Console 60K**. *Nano* era el pequeño; *Maximus* es el grande.

No necesita un MSX. Es un MSX.

## Qué lleva dentro

**Vídeo** · Salida HDMI 720p a pantalla completa · **V9968** o V9958 · bordes estilo CRT · scanlines conmutables desde el menú

**Audio** · PSG · doble SCC con estéreo · OPLL (MSX-Music) · **MSX-Audio Y8950** con FM y ADPCM-B · **MoonSound / OPL4** completo, FM (OPL3) y wavetable de 24 voces

**Almacenamiento** · Nextor sobre microSD · megaram con Konami4, Konami-SCC, ASCII8 y ASCII16

**Entrada** · Teclado USB directo sin hub, con F1–F10 físicas · gamepads USB mapeados a joystick MSX

**WiFi** · UNAPI mediante un **ESP32-C6** externo, con **pantalla opcional** para información adicional

**Extras** · Turbo Panasonic 5,37 MHz · menú de arranque propio con explorador de ficheros · logo de arranque · control de ventilador por temperatura · telemetría por puerto serie para diagnóstico

## Hardware necesario

| | Qué | Notas |
|---|---|---|
| **Obligatorio** | [Sipeed **Tang Console 60K**](https://wiki.sipeed.com/hardware/en/tang/tang-console/mega-console.html) | SOM Tang Mega 60K (Gowin GW5AT-60), HDMI, 2× USB-A, microSD, DDR3 |
| **Obligatorio** | Módulo de **SDRAM** de la Console | Es la RAM del MSX; sin él el core no arranca |
| Opcional | **Disipador de 20×20 mm** sobre el SOM | Recomendado: el core va bastante cargado. [Como estos](https://s.click.aliexpress.com/e/_c4WMlpD9) |
| Opcional | **Ventilador de 20×20 mm** de 5 V | Conector **JST de 1,25 mm, 2 pines** — [como este](https://s.click.aliexpress.com/e/_c328rXwB). Se gobierna solo por temperatura |
| Opcional | Teclado y gamepad **USB** | Directos a los USB-A de la placa, sin hub |
| Opcional | **ESP32-C6** (Waveshare C6-LCD-1.3) | Para el **WiFi**, con pantalla opcional de información |

El ventilador no hace falta para funcionar. Si lo pones, el core lo controla solo: mide la temperatura del chip con un termómetro interno y solo sopla cuando toca.

## Instalación

Todo va a la **flash SPI** de la placa, en tres direcciones distintas:

| # | Fichero | Dirección | ¿Obligatorio? |
|---|---|---|---|
| 1 | `MSXimus_v*.fs` | **`0x000000`** | Sí — es el core |
| 2 | Pack de BIOS (`pack_bios_*.bin`) | **`0x400000`** | Sí — sin él no arranca el MSX |
| 3 | `yrw801.rom` | **`0x500000`** | No — solo para MoonSound/OPL4 |

### Cómo grabarlo

1. Conecta la placa por el **USB-C** y abre el **Gowin Programmer** (va bien el de la versión 1.9.12).
2. Deja que detecte el dispositivo: debe salir el **GW5AT-60**.
3. Para **cada** uno de los tres ficheros, configura una operación de escritura en la **flash SPI externa** (las opciones que empiezan por *exFlash*, no las de SRAM), pon el fichero en *Programming File* y **la dirección de la tabla en el campo de dirección de inicio**.
4. Graba primero el `.fs` y luego los otros dos. El orden entre ellos da igual, pero **las direcciones no**: si el pack no cae exactamente en `0x400000`, el core arranca y se queda en negro.
5. **Apaga y enciende la placa.** Un reset **no** basta: la DDR3 necesita recalibrar desde frío y con un reset caliente puede quedarse colgada.

> Si al arrancar ves la pantalla azul y nada más, casi siempre es (a) el pack en la dirección equivocada, o (b) que no has hecho el ciclo de apagado.

### Sobre el pack de BIOS

La release **solo trae el bitstream**. El pack contiene las BIOS del MSX, que son propiedad de sus dueños y no se pueden redistribuir aquí — igual que `yrw801.rom`, que es la wavetable de Yamaha del OPL4. Tienes que aportarlos tú, de un MSX que poseas o de donde tengas licencia para hacerlo.

Para montar el pack está el [**MSXnano Pack Builder**](https://github.com/Papipapito/MSXnano), que arma el fichero con tus propias ROMs, Nextor incluido.

Sin OPL4 el core funciona igual; simplemente no tendrás MoonSound.

Después, mete una microSD con tus ROMs y discos y listo — el menú de arranque sale solo.

## Conexión del ESP32-C6 (WiFi)

Opcional — el core funciona igual sin él; simplemente no tendrás WiFi. Son tres o cuatro cables entre el conector **J10** de la placa y el módulo:

<p align="center"><img src="docs/img/esp32_c6_j10.svg" alt="Diagrama de conexión del ESP32-C6 al J10" width="820"/></p>

| Pin J10 | Señal | Bola FPGA | ESP32-C6 |
|---|---|---|---|
| **11** | +5 V (alimentación) | — | **5V** (tira derecha, el último) |
| **12** | GND | — | **GND** (tira derecha) |
| **14** | TX (FPGA → C6) | W21 | **IO17** (tira izquierda, el RX del C6) |
| **16** | RX (FPGA ← C6) | N17 | **IO16** (tira izquierda, el TX del C6) |
| **18** | TURBO (FPGA → C6) | N13 | **GPIO3** (tira derecha, el primero) — opcional, solo alimenta el indicador de turbo de la pantalla |

Y así queda del lado del módulo:

<p align="center"><img src="docs/img/esp32_c6_pinout.jpg" alt="Pines del ESP32-C6 usados por el MSXimus" width="820"/></p>

- **J10 es el conector 2×20 libre**, el que el esquemático de Sipeed llama *SDRAM1 CONN.* — **no** el que lleva el módulo de SDRAM que el core necesita.
- **Identificar los pines sin serigrafía**: con la placa apagada y el polímetro en continuidad, **el pin 12 es el único de todo el conector con paso a masa**. Su compañero de fila es el 11 (+5 V), y desde el 12, hacia el lado largo (el que deja 14 filas, no 5), van el 14, el 16 y el 18.
- **La alimentación sale del propio J10** (pin 11 → `5V` del módulo): el USB-C del C6 solo hace falta para grabarle el firmware.
- TX y RX van **cruzados**, como siempre. La UART va a 859 372 baudios.
- ⚠️ Si algún día pinchas un segundo módulo de SDRAM en J10, hay que mudar el ESP a otro sitio.

El firmware del módulo y su inventario técnico completo están en [`esp32_c6/`](esp32_c6/); graba el `firmware_esp32c6_unapi_merged.bin` de la release en el C6 por su propio USB-C:

```
esptool --chip esp32c6 --port COMx write_flash 0x0 firmware_esp32c6_unapi_merged.bin
```

## Estado

Esta versión se ha validado en hardware con la batería de tests del V9968 de HRA!, las demos DEVCON, Metal Gear 2, Aleste 2 y el catálogo MSX2+ habitual. El V9968 está alineado con la **última revisión publicada** por HRA!; su procedencia y cada parche local están documentados en [`fpga/v9968/ORIGEN.txt`](fpga/v9968/ORIGEN.txt).

## Estructura del repositorio

```
docs/            Planes, auditorías, logo, capturas
fpga/            top.v, build.tcl
  v9968/         El VDP V9968 (+ ORIGEN.txt: procedencia y parches locales)
  video720/      Puente HDMI y escalador
  src/           RTL propio (shim de VRAM, backend DDR3, audio, USB…)
  constraints/   Pinout y constraints de la Console 60K
tools/           Testbenches y utilidades de validación
```

## Lo nuevo de la v2.1

La v2.1 pone el V9968 al día y remata el audio y la imagen:

- **El V9968, a la última** — el core lleva ahora la revisión más reciente publicada por HRA!: el nuevo mapa de registros R#20/R#21 (compatible V9958 al arrancar), juegos de paleta por sprite en modo 2 (EPAL) y la interrupción de fin de comando.
- **Audio remasterizado** — nueva estructura de ganancia calibrada contra hardware real y openMSX: bloqueo de continua en los PSG, balance entre chips revisado, limitador de rodilla suave, y **volumen maestro que se ajusta desde el propio MSX** (`OUT &H44,n`, 0–7) y se guarda en flash. El MoonSound/OPL4 suena a su nivel de referencia.
- **MSX-Audio con 256 KB** — la RAM de samples del Y8950 pasa de 32 a 256 KB, el máximo que direcciona el chip real.
- **Imagen más de CRT** — el borde se ve por los cuatro lados, cada píxel sale uniforme (escalado entero exacto) y el centrado está afinado.
- **MegaROMs ASCII16 de 2 MB completas** — Aleste 2 y compañía, enteros.
- **Memoria a prueba de bombas** — la SDRAM se refresca de forma autónoma y el puerto de CPU del V9968 respeta el /WAIT: comportamiento sólido bajo cualquier carga, del arranque en frío a la demo más exigente.
- **Firmware del ESP32-C6 en el repo** — el firmware del módulo WiFi vive ahora en `esp32_c6/`, con el pinout del J10 documentado.

## El V9968

El corazón del MSXimus es el **[V9968](https://github.com/hra1129/V9968_Cartridge) de Takayuki Hara (HRA!)**, un VDP imaginario que extiende el V9958 con lo que Yamaha nunca llegó a sacar:

- **Sprites multicolor**: 15 colores más transparencia **por sprite**, definidos píxel a píxel
- **16 sprites por línea** en vez de 8 — se acabó el parpadeo
- **Sprites escalables**, con magnificación libre, rotación y espejado
- **Paleta extendida**: 256 colores en 16 juegos de 16
- **256 KB de VRAM**, comandos extendidos (rotación LRMM, LFMM, LFMC) y modo de comandos rápido

<p align="center"><img src="docs/img/v9968_sprites.jpg" alt="Sprites multicolor del V9968" width="760"/></p>
<p align="center"><i>Sprites de 15 colores definidos píxel a píxel: imposible en un MSX2+ real.</i></p>

La VRAM del V9968 vive en la **DDR3** de la placa, lo que deja la SDRAM entera para la RAM del MSX y para lo que venga después.

Y sigue siendo un MSX2+ normal: el software de siempre funciona igual.

## Licencia

**GPLv3**, por derivación de [`Papipapito/MSXnano`](https://github.com/Papipapito/MSXnano). Ver [LICENSE](LICENSE) y [UPSTREAM.md](UPSTREAM.md) para la atribución completa y la IP de terceros.

El **V9968** es de Takayuki Hara y viene con su licencia propia, tipo BSD pero **no comercial**: se puede redistribuir conservando los avisos y publicar gratis, **pero no vender**. Esa condición se hereda, así que **este proyecto no se vende**.

El logo del MSXimus es del proyecto.

---

# Gracias

Esto no lo he hecho yo solo, ni de lejos. Todo lo que hay aquí se apoya en el trabajo de gente que publicó lo suyo para que otros pudiéramos seguir.

### El core y su linaje

- **[jabadiagm](https://github.com/jabadiagm)** — MSXgoauldSD, el Goa'uld, origen de todo este linaje (goauld → MSXnano → MSXimus), y MSX_LCD_tn20k.
- **Linaje OCM-PLD / ESE Artists' Factory** — Kunihiko Ohnaka, KdL y todos los que han mantenido vivo el MSX2+ en FPGA durante dos décadas. De ahí viene el VDP V9958.

### El V9968

- **[Takayuki Hara — HRA!](https://github.com/hra1129)** — autor del **V9968**, el VDP que hace especial a esta versión, y de la demo DEVCON y de toda la batería de tests con la que se ha validado. Gracias por publicarlo y por documentarlo tan bien.
- **[Albert Herranz — herraa1](https://github.com/herraa1)** — port de la demo a MSXgl (`ru66-v9968-demo`), el cartucho V9968 y el material de referencia que ha permitido depurar el core.

### Audio

- **[Jose Tejada — jotego](https://github.com/jotego)** — jt2413 (OPLL), jtopl2 (FM del Y8950) y jt10_adpcmb. GPLv3.
- **[Greg Taylor — gtaylormb](https://github.com/gtaylormb)** — opl3_fpga (LGPLv3), que incluye `afifo.v` de **Dan Gisselquist (ZipCPU)**.
- **Jokin Miragaia (antxiko)** — mangOPL4, los arreglos para Gowin y las lecciones de integración.
- **srg320** — YMF278B.sv, el motor PCM del OPL4, cedido con permiso expreso.
- **Equipo MAME** — R. Belmont, Olivier Galibert y hap (ymf278b.cpp), y **Aaron Giles** (ymfm).
- **Tatsuyuki Satoh** — el algoritmo ADPCM-B de referencia.

### La placa y la cadena de vídeo

- **[nand2mario](https://github.com/nand2mario)** — `ddr3_framebuffer_gowin` (la receta de la IP DDR3 que hace posible meter ahí la VRAM), `usb_hid_host`, la plantilla de vídeo 720p y, en general, por abrir camino en el ecosistema Tang.
- **hdl-util (Sameer Puri)** — el empaquetador HDMI (MIT).
- **[ducasp](https://github.com/ducasp)** — firmware y protocolo UNAPI del ESP.

### Validación y herramientas

- **Equipo de [openMSX](https://openmsx.org)** — la referencia contra la que se comprueba si algo está bien o mal.
- **Laurens Holst (grauw)** — VGMPlay MSX y la MSX Assembly Page.
- **aoineko (Guillaume Blanchard)** — MSXgl.
- **[Sipeed](https://sipeed.com)** y **Gowin** — la placa y el toolchain.
- **Yamaha** — por los chips originales (V9958, YM2149, YM2413, Y8950, YMF262, YMF278B) que esto emula con cariño.

### Y

- **Claude (Anthropic)** — **coautora del código**: RTL nuevo, el shim de VRAM sobre DDR3, las integraciones de audio, la suite de validación, y una cantidad indecente de horas de depuración a base de simulación, telemetría y equivocarse mucho antes de acertar.

---

<p align="center"><i>Para la comunidad MSX. Que dure otros cuarenta años.</i></p>
