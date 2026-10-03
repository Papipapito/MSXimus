# 06. MSX-DOS y Nextor

El disco del MSXimus es la tarjeta microSD, y quien la sirve es **Nextor**, el sistema de disco de Nestor Soto que sustituye al MSX-DOS 2 y sabe de particiones grandes y FAT16. Este capítulo cuenta qué versión hay, cómo se arranca en DOS, cómo se lanza un disco de imagen y qué esperar del rendimiento.

## 1. Las dos versiones

El pack de BIOS lleva Nextor dentro, en el slot 3-2 de la máquina, y hay dos packs que solo difieren en eso:

| Pack | Nextor | Cuándo |
|---|---|---|
| `pack_bios_msximus.bin` | **2.1.4** | El de uso diario. Estable, con años de software probado encima |
| `pack_bios_msximus_nextor3.bin` | **3.0 beta 2** | Para probar la beta. Con la beta 1 arrancaba, leía, escribía y pasaba la batería de pruebas del propio Nextor; la beta 2 (01/10/2026) lleva el mismo driver, byte a byte, y está por probar en placa. Es beta y hay software que todavía no la lleva bien |

El driver de la tarjeta es el mismo en los dos, hecho para este core: sondea qué tiene delante y usa lo más rápido que encuentre. Con el core actual, la lectura va por DMA sin que DOS se entere.

Un caso conocido con Nextor 3: **VGMPlay** se cuelga al reproducir un VGM de OPL3, mientras que con Nextor 2.1.4 en el mismo core reproduce bien, y MoonBlaster con OPL4 funciona bajo Nextor 3. Es del reproductor, no del core ni del driver; conviene reportarlo a sus autores citando "Nextor 3.0.0 beta 1".

## 2. Arrancar en DOS

Con el ajuste **Menú al arrancar** en Off, la máquina arranca directamente en Nextor desde la tarjeta, como un MSX con su interfaz de disco. Con el menú activo, **ESC** en el navegador hace lo mismo. En cualquier caso, la tarjeta necesita en la raíz de su primera partición los ficheros de sistema: `NEXTOR.SYS` y `COMMAND2.COM` para Nextor 2, o `NEXTOR.SYS` y `COMMAND3.COM` para Nextor 3, y opcionalmente un `AUTOEXEC.BAT`. Sin ellos se arranca en BASIC, con el disco accesible desde ahí.

Desde DOS todo es lo de siempre: `DIR`, `COPY`, ejecutar `.COM`, Nextor con sus utilidades. Las particiones que Nextor vea son unidades A:, B:, etc.

Dos detalles de esta máquina:

- El disco está en el **slot 3-2**, expandido. Las utilidades que piden el slot del driver, como `DRVTEST`, lo quieren así: `DRVTEST 3-2`, no `DRVTEST 3`.
- Nextor **no puede escribir en la tarjeta mientras el propio driver está en la página 1**, y `DRVTEST` lo llama directamente. Redirigir su salida a la SD da "Disk error writing drive A". No es un fallo: se redirige a un disco RAM (`RAMDISK 256`) y luego se copia.

## 3. Lanzar un disco de imagen

Desde el navegador del menú, RETURN sobre un `.dsk` y RETURN otra vez para **montar y lanzar**. El menú deja a Nextor un descriptor de emulación y sigue el arranque: Nextor ve la imagen como unidad A: en modo MSX-DOS 1 y ejecuta su sector de arranque, como si el disquete estuviera en una disquetera. Dura hasta el siguiente reinicio; después la unidad A: vuelve a ser la tarjeta.

Requisitos: el `.dsk` en clusters consecutivos (capítulo 03), y en tarjetas FAT16 el fichero oculto `NEXTOR.EMU` en la raíz, que el menú crea solo. Nada se crea ni se borra al montar: solo se reescriben sectores de ficheros que ya existen.

Los juegos de disco que usan MSX-DOS y música FM, como Aleste, funcionan así con las dos versiones de Nextor. Los que necesitan cambiar de disco no tienen forma de hacerlo: se monta una imagen por arranque.

## 4. Rendimiento

La tarjeta se lee por DMA: el core copia cada sector a la memoria del MSX sin que el Z80 mueva un byte, a unos 640 KB por segundo, seis veces lo que daba el camino anterior. El arranque de DOS y la carga de programas grandes se notan. La escritura va por el camino clásico, más lenta, pero la escritura en un MSX siempre lo fue.

El menú de pruebas (tecla T, opción 1) mide los cuatro caminos de lectura sobre 128 KB, y sirve para ver que la tarjeta y el core están bien:

| Camino | KB/s |
|---|---|
| Ventana de memoria | 90 |
| Puertos, sector a sector | 104 |
| Puertos, multibloque | 112 |
| DMA | 640 |

## 5. Otros sistemas

**SymbOS 4.0** arranca en el MSXimus: hay una imagen de tarjeta preparada, con el driver de disco del WonderTANG que es el que este controlador entiende. Está en su propio repositorio. Y todo lo que corra sobre Nextor, como MSX-DOS 2 con sus herramientas, corre igual.

## 6. Lo que no hay

- No hay MSX-DOS 2 en ROM aparte de Nextor. No hace falta: Nextor es compatible con él.
- No hay disquetera ni forma de conectar una.
- No hay cambio de disco en caliente para los juegos de varios discos en imagen.
