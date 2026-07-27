<p align="center"><img src="docs/logo/msximus.svg" alt="MSXimus" width="480"/></p>

<h1 align="center">MSXimus</h1>
<p align="center"><b>Un MSX2+ completo, en una Tang Console 60K — ahora con el VDP V9968</b></p>
<p align="center">
  <img alt="version" src="https://img.shields.io/badge/versi%C3%B3n-v2.0-blue">
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

**Vídeo** · Salida HDMI 720p a pantalla completa · **V9968** o V9958 · **relación de aspecto configurable** (4:3 / panorámico) y scanlines, desde el menú

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
| 1 | `msximus_60k_*.fs` | **`0x000000`** | Sí — es el core |
| 2 | Pack de BIOS (`goauld_rom_int_*.bin`) | **`0x400000`** | Sí — sin él no arranca el MSX |
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

## Estado y limitaciones conocidas

Esta versión se ha validado en hardware con la batería de tests del V9968 de HRA!, la demo DEVCON, Metal Gear 2, Aleste 2 y el software MSX2+ habitual. No es perfecta, y prefiero contarlo:

- **El logo de arranque del MSX2+** (el que sale al entrar en BASIC) muestra glitches durante medio segundo, probablemente ligados al entrelazado de su animación. Está diagnosticado; el arreglo conocido penaliza el rutado del chip y está aparcado — es puramente cosmético.
- **Quedan líneas sueltas** en las escenas más exigentes de las demos del V9968 — del orden de 4 a 10 fallos de caché por frame. No afecta a los juegos.
- El **scroll de dos páginas en SCREEN 7 y 8**, y el scroll hacia atrás, todavía no están finos.
- El core está alineado con el V9968 tal como estaba en **enero de 2026**. HRA! ha seguido trabajando desde entonces y los arreglos posteriores se van portando uno a uno; el detalle está en [`fpga/v9968/ORIGEN.txt`](fpga/v9968/ORIGEN.txt).

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

## Versiones

### v2.0 — lo nuevo: el V9968

Hasta la v1.1 el MSXimus llevaba un **V9958**, el VDP del MSX2+. La v2.0 incorpora el **[V9968](https://github.com/hra1129/V9968_Cartridge) de Takayuki Hara (HRA!)**, un VDP imaginario que extiende el V9958 con lo que Yamaha nunca llegó a sacar:

- **Sprites multicolor**: 15 colores más transparencia **por sprite**, definidos píxel a píxel
- **16 sprites por línea** en vez de 8 — se acabó el parpadeo
- **Sprites escalables**, con magnificación libre, rotación y espejado
- **Paleta extendida**: 256 colores en 16 juegos de 16
- **256 KB de VRAM**, comandos extendidos (rotación LRMM, LFMM, LFMC) y modo de comandos rápido

<p align="center"><img src="docs/img/v9968_sprites.jpg" alt="Sprites multicolor del V9968" width="760"/></p>
<p align="center"><i>Sprites de 15 colores definidos píxel a píxel: imposible en un MSX2+ real.</i></p>

La VRAM del V9968 vive en la **DDR3** de la placa, lo que deja la SDRAM entera para la RAM del MSX y para lo que venga después. La v2.0 también estrena el **WiFi por ESP32-C6**, corrige un fallo serio de refresco de la DDR3 heredado de la configuración de referencia, y porta los primeros arreglos del V9968 upstream.

Y sigue siendo un MSX2+ normal: el software de siempre funciona igual.

### v1.1 — V9958 estable

La primera versión pública del MSXimus: el MSX2+ clásico con V9958, audio completo (PSG, SCC, OPLL, Y8950, OPL4) y el menú de arranque, sobre la build `_116`.

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
