# MSX SD Maker

Prepara tarjetas SD para **MSXimus** (60K, 138K, Zynq), **MSXnano** y **MSX Pico**: las particiona, las formatea, copia el sistema y deja una estructura de programas con su `AUTOEXEC.BAT`.

## Uso

Abrir `dist\MSXsdmaker.exe`: pide permisos de administrador (hacen falta para escribir la tarjeta entera).

1. **Tarjeta**: solo aparecen lectores SD/MMC y memorias USB extraíbles, nunca el disco de Windows. Se ve el tamaño y las particiones que tiene ahora.
2. **Particiones**:
   - FAT16 de 2 GB o de 4 GB, tantas como quepan (hasta 8, las que ve el menú del MSXimus). Opcionalmente, una última con lo que sobre.
   - O una FAT32 con toda la tarjeta. Nextor 2.1.4 y 3.0 no leen FAT32: sirve para el menú del MSXimus (ROM y DSK) y la MSX Pico, no para arrancar MSX-DOS.
3. **Sistema** en la partición 1: Nextor 2.1.4, Nextor 3.0 beta 1, MSX-DOS básico (`MSXDOS2.SYS` + `COMMAND2.COM`, y los de MSX-DOS 1) o ninguno.
4. **Programas**: SofaRun, Multi Mente, UTIL, WiFi/UNAPI, fuentes, música, HUB, IA, mapper e indev. Se crean también `FHUNT` y `TMP` (el menú no puede crear carpetas) y `SAVES` y `SETTINGS` de SofaRun.

El `AUTOEXEC.BAT` se genera con lo elegido: `PATH`, alias de SofaRun y una línea `mapdrv c: 2 1 0` por cada partición de más (C:, D:, E:...).

Al acabar se relee todo lo escrito: la tabla de particiones y cada fichero por CRC.

🚨 La primera vez, pruébalo con una tarjeta que no tenga nada que importe: borra la tarjeta entera.

## Cómo reparte la tarjeta

Igual que el `FDISK` de Nextor (`kernel/bank5/fdisk2.c`): partición 1 primaria, activa y en el sector 1; las demás lógicas dentro de una extendida, cada una con su EBR. Geometría FAT16 idéntica a la suya (cluster de 2 a 64 KB, como mucho 65.524 clusters, 512 entradas de raíz). La FAT32 empieza en el sector 8192 con los datos alineados a 4 MB.

## Contenido

Sale de `packs/sd/` de este repo y va dentro del `.exe`: `base/`, `nextor-2.1.4/`, `nextor-3.0.0-beta1/` y `extras/` (SOFARUN, hub, mapper, IA e indev de la SD de la MSX Pico). Para cambiar lo que se copia, se cambian esas carpetas y se vuelve a construir.

## Construir y probar

```bat
construir_exe.bat
```

Hace `dist\MSXsdmaker.exe` con PyInstaller.

Línea de órdenes (con Python), útil para probar con imágenes:

```bash
python MSXsdmaker.py imagen prueba.img --tamano 8G --esquema fat16-2g --n 3 --sistema nextor214 --programas todos
```

Pruebas en WSL con herramientas ajenas al programa (`sfdisk`, `fsck.fat`, `mtools`):

```bash
bash pruebas/probar_imagenes.sh
```

Siete casos: 3×200 MB, 2×2 GB con sobrante y Nextor 3, 2×4 GB con sobrante, FAT32 de 16 GB, MSX-DOS, vacía y 8 particiones. En cada uno, la partición 1 se extrae y se compara con un árbol hecho con `cp`.
