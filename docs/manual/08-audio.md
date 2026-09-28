# 08. Audio

Todo el sonido del MSXimus sale por el HDMI, mezclado dentro del core. Este capítulo dice qué chips hay, qué ve el software, cómo se reparte el estéreo y cómo se ajusta el volumen.

## 1. Los chips

| Chip | Qué es | Dónde lo ve el software |
|---|---|---|
| **PSG** | El sonido básico de todo MSX, tres voces y ruido | Puertos A0-A2, como siempre |
| **Segundo PSG** | Otro PSG completo | Puertos 10-12, para el software que lo busca ahí |
| **SCC y SCC+** | El chip de ondas de Konami, cinco voces | Dentro del cartucho emulado, en el slot 2. Cualquier juego con mapper Konami-SCC lo tiene, y los que usan el SCC+ también |
| **Segundo SCC** | Otro SCC en el slot 1 | Para trackers y reproductores que buscan un SCC como cartucho aparte. Se activa en Ajustes, **Slot 1 = 2o SCC**, y es incompatible con el Game Master 2, que va en el mismo slot |
| **OPLL** | MSX-MUSIC, el FM-PAC de nueve voces | Puertos 7C-7D, con su BIOS en el pack |
| **MSX-Audio** | El Y8950 del Music Module de Philips: FM de nueve voces más un canal ADPCM de muestras | Puertos C0-C1, con 32 KB de memoria de muestras. Las interrupciones del chip funcionan |
| **MoonSound** | El OPL4 completo: FM de 18 voces (OPL3) y 24 voces de tabla de ondas con la ROM YRW801 de 2 MB | Puertos C4-C7 el FM, 7E-7F las ondas |

La ROM de ondas del MoonSound, `yrw801.bin`, se graba en la flash a 0x500000 y el core la copia a la memoria al arrancar. Sin ella el OPL4 tiene FM pero no ondas; el software que use instrumentos de la ROM sonará incompleto.

Todo esto está a la vez y sin conflictos: un juego puede usar PSG y SCC, un reproductor puede tocar el MoonSound mientras el PSG hace los efectos.

## 2. Mono y estéreo

En Ajustes, **Stereo Sound**:

| | Izquierda | Derecha |
|---|---|---|
| **Off** | Todo mezclado | Todo mezclado |
| **On** | PSG principal, SCC del cartucho, OPLL, MSX-Audio | Segundo PSG, segundo SCC, OPLL, MSX-Audio |

El MoonSound tiene sus propios canales izquierdo y derecho y en estéreo los saca tal cual. Con un solo SCC y un solo PSG, el estéreo pone el PSG y el SCC a un lado y el FM en el centro, que es lo que hacían los MSX con salida estéreo.

## 3. El volumen

Cada chip entra al mezclador a su nivel real, medido contra openMSX, y el conjunto lleva una **ganancia maestra** para el grupo clásico (PSG, SCC, OPLL, MSX-Audio) que sirve para ponerlos a la altura del MoonSound, que suena más fuerte de origen. Va de 0 a 7, el valor de fábrica es 5, y se guarda en la flash.

Desde la v3.7 hay además un **mezclador por chip**: cada fuente (PSG, SCC, OPLL, MSX-Audio, OPL4 FM y OPL4 wave) tiene su nivel de 0 a 8 octavos antes de la suma, 8 = tal cual, 0 = muda. Se ajusta en **Ajustes → Mezclador de audio** (arriba/abajo elige el canal, izquierda/derecha mueve el nivel y suena una nota de prueba en ese chip; ESC vuelve) y se guarda con *Save & Restart*. La ganancia maestra es la primera fila de esa misma página.

Por puerto, para el que quiera hacerlo desde BASIC: el 44h del dispositivo de configuración recibe `{canal, nivel}`: canal 0 es la ganancia maestra (0-7), 1-6 los chips en ese orden (nivel 0-8). Para dejar la ganancia en 4 y el PSG a la mitad:

```basic
OUT &H40,&H48 : OUT &H44,4 : OUT &H44,&H14 : OUT &H42,INP(&H42) OR &HC0
```

Los niveles cambian en el acto; la última orden los guarda en la flash y reinicia la máquina, igual que Save & Restart. El mezclador satura suavemente en vez de recortar: con la ganancia alta y muchos chips a la vez se comprime, no distorsiona a saco.

## 4. Lo que se comprobó en placa

- PSG, SCC, OPLL y MoonSound en el propio menú de pruebas (tecla T, opción 2, para PSG y OPLL) y en juegos.
- MSX-Audio con ADPCM en VGMPlay y en juegos que lo usan.
- El MoonSound completo con MoonBlaster y con VGMs de OPL4.
- Dos SCC a la vez con trackers que usan el segundo.

Un caso conocido: **VGMPlay** con VGMs de OPL3 se cuelga bajo Nextor 3 beta, no bajo Nextor 2.1.4 ([capítulo 06](06-msxdos-nextor.md)).

## 5. Lo que no hay

- Salida analógica: todo va por el HDMI, así que hace falta un televisor o un extractor de audio HDMI.
- Chips fuera de la lista: no hay Darky ni SFG-01.
