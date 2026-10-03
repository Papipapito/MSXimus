# 03. La tarjeta SD

Cómo preparar la microSD y qué poner en ella. Todo lo que dice este capítulo sale del código del menú y del driver de disco.

## 1. Qué tarjeta

**De marca y clase 10**: Samsung, SanDisk, Kingston. Las tarjetas sin marca leen bien, pero rechazan o pierden escrituras en ráfagas largas, que es justo lo que hacen las descargas y los guardados. Está medido en el banco con el mismo código y la misma geometría: una sin marca fallaba escrituras aunque se le diera tiempo; una Samsung EVO+ no falló ninguna. Si las descargas o los guardados hacen cosas raras, la primera sospechosa es la tarjeta.

El tamaño da igual: el controlador admite SD v1, SD v2 y SDHC, y el menú de pruebas dice cuál ha detectado.

## 2. Formato

**FAT16**, en la primera partición. Con FAT32 el navegador y el lanzador de discos funcionan, pero no las dos funciones que escriben en la tarjeta:

| Función | FAT16 | FAT32 |
|---|---|---|
| Navegar y lanzar ROMs | sí | sí |
| Lanzar discos `.dsk` | sí | sí |
| Descargar con File-Hunter | sí | no: "FH: la SD es FAT32 (v1 solo FAT16)" |
| Guardar la SRAM de cartucho y el Game Master 2 | sí | no |
| Nextor desde MSX-DOS | sí | no: Nextor no monta FAT32 (ni la 2.1.4 ni la 3.0 beta 2) |

La forma más fácil de dejarla lista es **[MSX SD Maker](../../MSXsdmaker/LEEME.md)**, un programa para Windows que está en este repositorio: parte la tarjeta en particiones FAT16 de 2 o 4 GB como lo hace el FDISK de Nextor (o en una sola FAT32), copia Nextor o MSX-DOS, SofaRun, Multi Mente y el resto de programas, y escribe el `AUTOEXEC.BAT` que monta las demás particiones como C:, D:… Sin él: una tarjeta de 2 GB o menos se formatea en FAT16 desde cualquier sistema, y con tarjetas mayores hay que crear una partición de hasta 2 GB en FAT16 con una herramienta de particiones o con `CALL FDISK` desde el propio MSX. El menú admite **varias particiones** y la tecla **TAB** cambia de una a otra, así que una tarjeta grande puede llevar una FAT16 para el menú y otras para MSX-DOS.

Nombres largos: el navegador los **muestra**, pero todo lo que el menú **escribe** va en formato 8.3. Un fichero que crea el menú, como una descarga o un guardado, se verá con nombre corto en el PC. Y al revés: si desde MSX-DOS renombras o borras un fichero que tenía nombre largo, Nextor solo toca el nombre corto y deja atrás las entradas del largo; el menú (desde el pack del 21 de septiembre) las descarta, como hace Windows, y muestra el nombre corto nuevo.

## 3. Qué poner y dónde

El navegador solo lista carpetas, ficheros `.ROM` y ficheros `.DSK`. Lo demás no se ve, aunque esté. Pueden ir en cualquier carpeta, hasta ocho niveles de profundidad, y el orden es el del directorio.

| Carpeta | Para qué |
|---|---|
| Cualquiera | ROMs y discos, organizados como se quiera |
| **`FHUNT`** en la raíz | La crea el usuario desde MSX-DOS con `MKDIR FHUNT`. Ahí van las descargas de File-Hunter, los guardados `.SRM` y la ROM del Game Master 2. Sin ella, no hay descargas ni guardados |
| Raíz | Nextor busca aquí `NEXTOR.EMU` para montar discos en tarjetas FAT16; lo crea el menú solo, oculto |
| Raíz | Los ficheros de arranque de MSX-DOS o Nextor si se quiere arrancar en DOS: `MSXDOS2.SYS`, `NEXTOR.SYS`, `COMMAND2.COM`, `AUTOEXEC.BAT` |

### Ficheros con nombre especial

| Fichero | Qué es |
|---|---|
| `FHUNT\GM2.ROM` | La ROM del cartucho Game Master 2 de Konami, 128 KB. La pone el usuario. Necesaria para el guardado de partidas de los juegos Konami |
| `FHUNT\GM2.SRM` | Los 8 KB de SRAM del Game Master 2. Lo crea el menú la primera vez |
| `FHUNT\<nombre>.SRM` | Los 32 KB de SRAM de cada cartucho ASCII8 o ASCII16 con SRAM, con el mismo nombre que la ROM. Lo crea el menú la primera vez |
| `NEXTOR.EMU` | Descriptor de emulación de disco, oculto, en la raíz. Solo en FAT16 |

## 4. Etiquetas en el nombre de las ROMs

El menú decide el mapper de una ROM mirando su contenido, pero si el nombre lleva una etiqueta, la etiqueta manda. File-Hunter las pone al descargar, y uno mismo puede ponerlas al renombrar:

| Etiqueta en el nombre | Mapper |
|---|---|
| `[ASCII16]` | ASCII16 |
| `[ASCII8]` | ASCII8 |
| `[SCC]` | Konami-SCC |
| `[KONAMI]` | Konami |
| `NEO16` o `NEO-16` | NEO-16 |
| `NEO8` o `NEO-8` | NEO-8 |
| `KOEI` o `SRAM` | Además del mapper, activa la SRAM de cartucho por defecto |

Las mayúsculas no importan. Una ROM sin etiqueta y cuyo análisis no dé resultado sale como mapper desconocido, y se elige a mano con la tecla **M** en la pantalla de lanzar. El [capítulo 05](05-roms-mappers.md) va al detalle.

## 5. Discos `.dsk`

Un `.dsk` tiene que estar **en clusters consecutivos** de la tarjeta, porque Nextor lo monta como un rango lineal de sectores. Los ficheros recién copiados a una tarjeta poco usada lo están; en una tarjeta con muchas borradas y escrituras puede que no, y entonces el menú avisa con *"DSK fragmentado: recopialo"*. Basta con copiarlo de nuevo desde el PC.

## 6. Editar ficheros de la tarjeta desde el PC

Los ficheros de texto del MSX, como `AUTOEXEC.BAT`, llevan fin de línea CR+LF y barras invertidas en las rutas. Un editor que los convierta a fin de línea Unix o toque las barras los deja inservibles para MSX-DOS. Si se editan desde el PC, con un editor que respete el formato.

## 7. Preparar una tarjeta desde cero, resumido

1. Formatear en FAT16.
2. Copiar `MSXDOS2.SYS` o `NEXTOR.SYS` y `COMMAND2.COM` a la raíz si se quiere arrancar en DOS.
3. Crear la carpeta `FHUNT` en la raíz, mejor desde MSX-DOS con `MKDIR FHUNT`. Desde el PC también vale si el nombre queda en mayúsculas, que es como la busca el menú.
4. Copiar `GM2.ROM` dentro de `FHUNT` si se van a usar los guardados del Game Master 2.
5. Copiar las ROMs y los discos, en las carpetas que se quiera.
6. Meter la tarjeta y encender.
