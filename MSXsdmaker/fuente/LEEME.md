# SD_Maker — tarjetas SD para los MSX en FPGA

*[English](README.md)*

**MSX SD Maker** prepara tarjetas SD para los MSX en FPGA, **MSXimus** (60K, 138K, Zynq), **MSXnano** y **Goa'uld**, y también para la **MSX Pico**: las particiona, las formatea, copia el sistema y deja una estructura de programas con su `AUTOEXEC.BAT`.

## Uso

Se reparte en un ZIP (`MSX_SD_Maker_<versión>.zip`, en las [releases](https://github.com/Papipapito/SD_Maker/releases/latest)): descomprimir y ejecutar `MSXsdmaker.exe`. Pide permisos de administrador (hacen falta para escribir la tarjeta entera).

1. **Tarjeta**: solo aparecen lectores SD/MMC y memorias USB extraíbles, nunca el disco de Windows. Se ve el tamaño y las particiones que tiene ahora.
2. **Particiones**:
   - FAT16 de 2 GB o de 4 GB, tantas como quepan (hasta 8, las que ve el menú del MSXimus). Opcionalmente, una última con lo que sobre.
   - O una FAT32 con toda la tarjeta. Nextor 2.1.4 y 3.0 no leen FAT32: sirve para el menú del MSXimus (ROM y DSK) y la MSX Pico, no para arrancar MSX-DOS.
3. **Sistema** en la partición 1: Nextor 2.1.4, Nextor 3.0 beta 2, MSX-DOS básico (`MSXDOS2.SYS` + `COMMAND2.COM`, y los de MSX-DOS 1) o ninguno.
4. **Programas**: SofaRun, Multi Mente, UTIL, WiFi/UNAPI, fuentes, música, HUB, IA, mapper e indev, y las herramientas FPGA (`FPGA\MXUPDATE.COM`, que actualiza el core del MSXimus 60K/138K y del MSXnano). Se crean también `FHUNT` y `TMP` (el menú no puede crear carpetas) y `SAVES` y `SETTINGS` de SofaRun.

El `AUTOEXEC.BAT` se genera con lo elegido: `PATH`, alias de SofaRun y una línea `mapdrv c: 2 1 0` por cada partición de más (C:, D:, E:...). Con Nextor 3 (1.1) lleva además las opciones del recuadro: `YENSLASH ON` (la orden interna de COMMAND3.COM desde la beta 2; el `yenslash` a secas solo diría el estado), `SET BUFINSERT=ON`, `SET DIRK=0` y, si se elige, se llama `AUTOEXEC.BTM`. Desde la 1.1, una tarjeta más pequeña que una partición entera (las de "2 GB") lleva una sola con todo, y la imagen pregunta siempre el tamaño (1800M por defecto: cabe en cualquier tarjeta de 2 GB).

Al acabar se relee todo lo escrito: la tabla de particiones y cada fichero por CRC.

🚨 La primera vez, pruébalo con una tarjeta que no tenga nada que importe: borra la tarjeta entera.

## Cómo reparte la tarjeta

Igual que el `FDISK` de Nextor (`kernel/bank5/fdisk2.c`): partición 1 primaria, activa y en el sector 1; las demás lógicas dentro de una extendida, cada una con su EBR. Geometría FAT16 idéntica a la suya (cluster de 2 a 64 KB, como mucho 65.524 clusters, 512 entradas de raíz). La FAT32 empieza en el sector 8192 con los datos alineados a 4 MB.

## Contenido

Sale de `sd/` y va dentro del `.exe`: `base/`, `nextor-2.1.4/`, `nextor-3.0.0-beta2/` y `extras/` (SOFARUN, hub, mapper, IA e indev de la SD de la MSX Pico, y FPGA con MXUPDATE.COM); [`sd/LEEME.md`](sd/LEEME.md) explica cada carpeta. Para cambiar lo que se copia, se cambian esas carpetas y se vuelve a construir.

Casi todo lo de `sd/` es de terceros (Nextor, MSX-DOS, SofaRun, Multi Mente, las herramientas UNAPI...) y va bajo la responsabilidad del autor de este proyecto: autores y licencias en [`paquete/LICENCIAS.md`](paquete/LICENCIAS.md), con la licencia de Nextor. El programa es GPL v3 ([`LICENSE`](LICENSE)).

## Construir y probar

```bat
construir_exe.bat
```

Hace `dist\MSXsdmaker.exe` con PyInstaller. `python hacer_zip.py` hace el ZIP de la release (`dist\MSX_SD_Maker_<versión>.zip`: el `.exe` con LEEME, README, LICENCIAS y las capturas).

Línea de órdenes (con Python), útil para probar con imágenes:

```bash
python MSXsdmaker.py imagen prueba.img --tamano 8G --esquema fat16-2g --n 3 --sistema nextor214 --programas todos
```

Pruebas en WSL con herramientas ajenas al programa (`sfdisk`, `fsck.fat`, `mtools`):

```bash
bash pruebas/probar_imagenes.sh
```

Nueve casos: 3×200 MB, 2×2 GB con sobrante y Nextor 3, 2×4 GB con sobrante, FAT32 de 16 GB, MSX-DOS, vacía, 8 particiones, las opciones de Nextor 3 y una imagen de 1800 MB. En cada uno, la partición 1 se extrae y se compara con un árbol hecho con `cp`.

## Paquete para los repos de las máquinas

```bash
python publicar_paquete.py ../MSXimus_zynq ../MSXimus
```

Copia a la carpeta `MSXsdmaker/` de cada repo el `.exe` (antes, `construir_exe.bat`), las instrucciones, `LICENCIAS.md` y las capturas de `paquete/`, y el código en `fuente/`. No hace commit.
