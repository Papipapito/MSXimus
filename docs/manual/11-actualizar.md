# 11. Actualizar desde el MSX

Desde la V3.8 el MSXimus se actualiza **sin PC**: el core y el pack de BIOS se graban en la flash de la placa desde el propio MSX. Hay tres caminos:

| Camino | Qué hace | Hace falta |
|---|---|---|
| `MXUPDATE /N` | Baja la última versión de internet ([msx.barcelona](https://msx.barcelona)) y la graba | MSX-DOS 2 o Nextor, el ESP32-C6 con WiFi |
| `MXUPDATE fichero.UPD` | Graba un fichero `.UPD` que tienes en la SD | MSX-DOS 2 o Nextor |
| Ajustes → **Instalar actualización** | Graba el `MSXIMUS.UPD` de la raíz de la SD | Nada más: no hace falta arrancar MSX-DOS |

Los tres hacen las mismas comprobaciones y graban igual. La única condición es que en la placa ya haya un **core V3.8 o posterior**, el primero que lleva el *puente de la flash* (el dispositivo que deja escribir en ella desde el MSX). La primera V3.8 se graba una vez con el PC, como siempre ([capítulo 02](02-instalacion.md)); desde ahí, ya no hace falta.

> La MSXimus Z (la versión para la ZYNQ MINI) se actualiza de otra forma: **F12 y U**, desde el panel del propio OSD. Lo de este capítulo es para la Tang Console 60K.

## 1. Qué es un `.UPD`

Un fichero `.UPD` lleva lo que hay que grabar en la flash, por trozos: el core (en 0x000000), el pack de BIOS (en 0x400000) y, en las actualizaciones completas, las ondas del OPL4 (en 0x500000). Cada trozo lleva su CRC-32. Se pueden hacer de tres tipos:

- **Normal**: core y pack. Es lo que baja `MXUPDATE /N`.
- **Solo el pack**: para cambiar de idioma del menú o de versión de Nextor en un minuto y medio, sin tocar el core.
- **Completa**: core, pack y ondas del OPL4. Es lo que baja `MXUPDATE /N /R`: todo desde cero.

Los **ajustes** que guardas con *Save & Restart* (en 0x480000) **nunca** van en un `.UPD`: una actualización los conserva. Solo `/R` los borra a propósito.

## 2. `MXUPDATE.COM`

Se copia a la SD y se lanza desde MSX-DOS. Reconoce la placa sola (60K, 138K o MSXnano 2.1.1) por el chip del core que hay grabado, y habla en el idioma del menú.

```
MXUPDATE                  graba MSXIMUS.UPD del directorio actual
MXUPDATE fichero.UPD      graba ese fichero
MXUPDATE /C fichero.UPD   solo lo comprueba (cabecera y CRC); no toca la flash
MXUPDATE /N               baja la ultima version de internet y la graba
MXUPDATE /N /R            la completa (core, pack y ondas) y vuelve a los ajustes de fabrica
MXUPDATE /EN   /ES        en ingles / en castellano
MXUPDATE /N /S:192.168.1.10:8000    desde un servidor propio en vez de msx.barcelona
```

### 2.1. Por internet: `MXUPDATE /N`

1. Configura antes la WiFi con la tecla **W** del menú ([capítulo 07](07-wifi-file-hunter.md)).
2. Arranca en MSX-DOS, ve a la raíz de la SD y escribe `MXUPDATE /N`.
3. Dice qué core tienes (`Core instalado: 3.8.0 (60K)`) y pregunta al servidor: `Version en el servidor: 3.8.0b3`, con una nota de qué trae.
4. Elige la variante, del 1 al 4: Nextor 2.1.4 o 3, menú en castellano o en inglés. Si cambias de Nextor, avisa: la SD tiene que llevar el `NEXTOR.SYS` de ese Nextor ([MSX SD Maker](../../MSXsdmaker/README.md) la prepara) o MSX-DOS no arrancará.
5. La baja a la SD como `MSXIMUS.UPD`, la comprueba entera y pregunta `Fichero correcto. Grabar en la flash? (S/N)`.
6. **S**: `Grabando. NO APAGUES EL MSX.` Al acabar relee la flash y comprueba los CRC otra vez.
7. `Listo. Apaga y vuelve a encender el MSXimus.` El core nuevo entra al encender.

La conexión con msx.barcelona es **cifrada (TLS) y con el certificado validado**. Para validarlo, el ESP32-C6 tiene que llevar el firmware de la v3.8, que trae las autoridades de certificación de serie. Con un firmware anterior funciona igual, pero sin validar el certificado, y lo dice: `Aviso: certificado sin validar.`. En claro, sin cifrar, no va nunca. El certificado de la web se renueva cada año y no hace falta volver a grabar el C6: lo que lleva el firmware son las autoridades, que duran hasta 2046.

Además, lo que se graba se comprueba con los CRC del propio fichero antes de borrar nada.

### 2.2. Desde un fichero

Copia el `.UPD` a la SD (desde el PC, o lo deja ahí `MXUPDATE /N` si contestas **N** a la pregunta de grabar) y escribe `MXUPDATE fichero.UPD`. El resto es igual: comprueba, pregunta, graba y relee.

`MXUPDATE /C fichero.UPD` solo comprueba el fichero. Funciona en cualquier MSX con MSX-DOS 2, también sin el puente.

### 2.3. Todo desde cero: `/R`

`MXUPDATE /N /R` baja la variante **completa** (unos 5 MB: core, pack y las ondas del OPL4) y, al acabar de grabar, **borra los ajustes**: la máquina arranca con los de fábrica, como recién grabada. Sirve para dejarla como nueva o si unos ajustes guardados dan guerra.

## 3. Desde Ajustes: «Instalar actualización»

Sin MSX-DOS, desde el propio menú:

1. Deja el fichero en la **raíz** de la SD con el nombre `MSXIMUS.UPD`.
2. Pulsa **S** al arrancar para entrar en Ajustes.
3. Baja hasta **Instalar actualización** (está entre *Mezclador de audio* y *Save & Restart*) y pulsa espacio.
4. Dice qué core tienes y qué trae el fichero, lo comprueba entero y pregunta `Fichero correcto. Grabar? (S/N)`.
5. **S**, y al acabar: `Listo. Apaga y enciende el MSXimus.`

Hace las mismas comprobaciones que `MXUPDATE.COM`. Si el core no tiene puente (anterior a la V3.8) lo dice y no hace nada.

## 4. Cuánto tarda

El Z80 hace todo el trabajo, a 3,58 MHz:

| Qué | Grabar | Por internet, además |
|---|---|---|
| Solo el pack | 1,5 minutos | lo que tarde en bajar 0,5 MB |
| Core y pack | 9 minutos | 3 MB |
| Completa (con las ondas) | 15 minutos | 5 MB |

**No apagues la placa mientras graba.**

## 5. Si algo sale mal

| Mensaje | Qué ha pasado | Qué hacer |
|---|---|---|
| `Hace falta MSXimus 3.8 o MSXnano 2.1.1 (o posterior)` | El core grabado no tiene el puente | Grabar la V3.8 una vez con el PC |
| `Este fichero es para otra placa` | Es un `.UPD` del 138K o del MSXnano | El de tu placa |
| `El fichero no es valido o esta danado. No se ha tocado nada.` | Cabecera o CRC mal | Bajarlo o copiarlo otra vez |
| `La descarga se ha cortado. No se ha tocado nada.` | Se fue la red a medias | Repetir `MXUPDATE /N` |
| `Sin conexion con el servidor de actualizaciones.` | No hay red, o el ESP no llega | Mirar la WiFi con la W del menú |
| `Sin actualizaciones para esta placa (HTTP 404).` | El servidor no tiene nada para tu placa | — |
| `No hay red (UNAPI)` | No hay ESP32 o no está configurado | La W del menú |
| `La flash no ha quedado bien.` | Al releer, algo no coincide | **No apagues**: el core de antes sigue en marcha hasta apagar. Repite `MXUPDATE`, o graba con el PC |

Si se va la luz a mitad de grabar el core, la placa puede no arrancar. **No hay forma de estropearla**: por el USB-C, con el Gowin Programmer, siempre se puede grabar de nuevo ([capítulo 02](02-instalacion.md)).

## 6. El panel F12

Con el firmware del BL616 de la v3.8, el panel de F12 recuerda abajo la orden para actualizar: `Actualizar: MXUPDATE /N`.
