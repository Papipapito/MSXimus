# MSX SD Maker 1.0 — preparar la tarjeta SD

*[English version](README.md)*

**MSX SD Maker** deja una tarjeta SD lista para usar en un **MSXimus** (Tang Console 60K, Tang Mega 138K o la versión Zynq), un **MSXnano** o una **MSX Pico**. En unos segundos hace todo esto:

1. Borra la tarjeta y la parte en particiones que MSX-DOS entiende.
2. Formatea cada partición.
3. Copia el sistema operativo (Nextor o MSX-DOS) en la primera partición.
4. Copia una colección de programas: SofaRun, Multi Mente, utilidades, red, música…
5. Escribe un `AUTOEXEC.BAT` que lo deja todo a mano al arrancar.
6. Relee lo escrito para comprobar que la tarjeta ha quedado bien.

No hay nada que instalar: es un solo fichero, `MSXsdmaker.exe`.

---

## Índice

1. [Qué necesitas](#1-qué-necesitas)
2. [Abrir el programa](#2-abrir-el-programa)
3. [Paso a paso](#3-paso-a-paso)
4. [Qué queda en la tarjeta](#4-qué-queda-en-la-tarjeta)
5. [El primer arranque en el MSX](#5-el-primer-arranque-en-el-msx)
6. [Poner juegos y programas](#6-poner-juegos-y-programas)
7. [Guardar como imagen en vez de tarjeta](#7-guardar-como-imagen-en-vez-de-tarjeta)
8. [Problemas frecuentes](#8-problemas-frecuentes)
9. [Para curiosos: cómo lo hace](#9-para-curiosos-cómo-lo-hace)
10. [Licencias y créditos](#10-licencias-y-créditos)

---

## 1. Qué necesitas

- **Un PC con Windows 10 u 11.**
- **Un lector de tarjetas**: el del portátil o uno USB.
- **Una tarjeta SD o microSD de 4 GB o más.** Lo más práctico es de 8 a 32 GB. Una de más de 32 GB también vale, pero con FAT16 solo se usan 8 particiones.
- **Saber qué versión de Nextor lleva tu máquina.** Depende del pack de BIOS o del `BOOT` que grabaste. Lo verás en el [paso 3.3](#33-el-sistema).

> ⚠️ **El programa borra la tarjeta entera.** Si tiene algo que quieras conservar, cópialo antes al PC.

---

## 2. Abrir el programa

1. Descarga **`MSXsdmaker.exe`** de esta carpeta. En GitHub: pulsa el fichero y luego el botón de descarga (*Download raw file*).
2. Mete la tarjeta en el lector.
3. Haz doble clic en `MSXsdmaker.exe`.
4. Windows pregunta si permites que haga cambios en el equipo: responde **Sí**. Hace falta porque el programa escribe la tarjeta entera, tabla de particiones incluida.

**Si Windows muestra «Windows protegió su PC»** (SmartScreen): pulsa **Más información** y después **Ejecutar de todas formas**. Sale porque el programa no está firmado digitalmente.

**Si el antivirus se queja**: los programas hechos en Python y empaquetados en un solo `.exe` dan a veces falsos positivos. El código fuente está en la carpeta `fuente/`.

---

## 3. Paso a paso

![La ventana de MSX SD Maker](capturas/1_ventana.png)

La ventana tiene cuatro bloques, de arriba abajo. Rellénalos en orden y pulsa **Preparar la tarjeta**.

### 3.1 La tarjeta

La lista de arriba muestra las tarjetas conectadas: letra de unidad, nombre del lector, tamaño y tipo. Si acabas de meter la tarjeta y no sale, pulsa **Actualizar**.

Debajo se ve el tamaño exacto y cómo está la tarjeta ahora; por ejemplo «Ahora: FAT32 de 29,81 GB».

> 🛡️ **Solo aparecen lectores de tarjetas SD y memorias USB extraíbles.** El disco donde está Windows no aparece nunca, y los discos duros externos tampoco. Aun así, fíjate bien en el tamaño antes de seguir.

### 3.2 Las particiones

Una **partición** es un trozo de la tarjeta que el MSX ve como una unidad de disco independiente (A:, C:, D:…). MSX-DOS no puede usar discos enormes, por eso la tarjeta se reparte en trozos que sí entiende.

| Opción | Tamaño de cada partición | Para qué sirve |
|---|---|---|
| **FAT16 de 2 GB** | 2 GB | **La opción recomendada.** Cada fichero ocupa como mínimo 32 KB, así que se desperdicia poco con ROM y DSK pequeños. |
| **FAT16 de 4 GB** | 4 GB, el máximo de Nextor | Menos particiones y más grandes. Cada fichero ocupa como mínimo 64 KB. |
| **Una FAT32** | Toda la tarjeta | Solo para el menú del MSXimus (ROM y DSK) y la MSX Pico. **MSX-DOS no la ve** (ver el aviso de abajo). |

**Cantidad.** El programa te dice cuántas particiones caben en tu tarjeta y no te deja pasar de ahí. El máximo es 8, que son las que recorre el menú del MSXimus.

**«Usar lo que sobre en una última partición FAT16».** Márcalo para no desperdiciar el trozo final de la tarjeta: se crea una partición más, más pequeña, con lo que quede (hasta 4 GB). Si no lo marcas, ese espacio queda libre y ni Windows ni el MSX lo ven.

Debajo verás cómo quedará la tarjeta. Por ejemplo:

```
  1: FAT16 de 2,00 GB    arranque (A:)
  2: FAT16 de 2,00 GB    C: (MAPDRV en el AUTOEXEC)
  3: FAT16 de 2,00 GB    D: (MAPDRV en el AUTOEXEC)
  sin usar: 23,81 GB
```

Cuántas caben en las tarjetas más habituales (su capacidad real es algo menor que la de la etiqueta):

| Tarjeta | FAT16 de 2 GB | + lo que sobra | FAT16 de 4 GB | + lo que sobra |
|---|---|---|---|---|
| 4 GB | 1 | + 1 de 1,7 GB | — | — |
| 8 GB | 3 | + 1 de 1,4 GB | 1 | + 1 de 3,4 GB |
| 16 GB | 7 | + 1 de 0,8 GB | 3 | + 1 de 2,8 GB |
| 32 GB | 8 | — | 7 | + 1 de 1,7 GB |
| 64 GB o más | 8 | — | 8 | — |

![FAT16 de 4 GB con el sobrante aprovechado](capturas/2_fat16_4gb.png)

> ⚠️ **FAT32 y MSX-DOS.** Ni Nextor 2.1.4 ni Nextor 3.0 leen particiones FAT32. Con una tarjeta FAT32 el MSX **no arrancará MSX-DOS** desde ella; saldrá el menú del MSXimus o BASIC. En el MSXimus, además, el menú no descarga del File-Hunter ni guarda la SRAM de los cartuchos en FAT32: solo lanza ROM y DSK. Elígela solo para eso o para la MSX Pico.
>
> ![Aviso de FAT32](capturas/3_fat32.png)

### 3.3 El sistema

Es el sistema operativo que se copia en la primera partición, la de arranque. **Tiene que coincidir con el Nextor que lleva tu máquina**: si no, el MSX no llega a MSX-DOS.

| Tu máquina | Si grabaste… | Elige |
|---|---|---|
| MSXimus 60K o 138K | `pack_bios_msximus.bin` o `pack_bios_msximus_en.bin` | **Nextor 2.1.4** |
| MSXimus 60K o 138K | `pack_bios_msximus_nextor3.bin` o `…_en_nextor3.bin` | **Nextor 3.0 beta 1** |
| MSXimus Z (Zynq) | un `BOOT_…_nextor214.bin` | **Nextor 2.1.4** |
| MSXimus Z (Zynq) | un `BOOT_…_nextor3.bin` | **Nextor 3.0 beta 1** |
| MSXnano | `pack_bios_msxnano.bin` o `pack_bios_msxnano_en.bin` | **Nextor 2.1.4** |
| MSXnano | `pack_bios_msxnano_nextor3.bin` o `…_en_nextor3.bin` | **Nextor 3.0 beta 1** |
| MSX Pico u otro MSX con Nextor 2.1 | — | **Nextor 2.1.4** |

Las otras dos opciones:

- **MSX-DOS básico**: solo `MSXDOS2.SYS` y `COMMAND2.COM`, más `MSXDOS.SYS` y `COMMAND.COM` de MSX-DOS 1, sin las herramientas de Nextor. Sin ellas el `AUTOEXEC` no puede montar C:, D:…; se hace a mano con `CALL MAPDRV` desde BASIC.
- **Ninguno (solo formatear)**: particiona y formatea, sin sistema ni programas. Útil para una tarjeta solo de juegos.

> ℹ️ MSX-DOS 1 solo arranca desde particiones FAT12 de 16 MB o menos, que no son las que crea este programa. Por eso con cualquiera de estas opciones arranca MSX-DOS 2, y los ficheros de MSX-DOS 1 van solo por si los necesitas.

### 3.4 Los programas

Se copian en la primera partición, cada uno en su carpeta. Marca los que quieras; los botones **Todos** y **Ninguno** ayudan.

| Casilla | Carpeta | Qué es | Cómo se abre |
|---|---|---|---|
| SofaRun | `SOFARUN` | Lanzador de ROM, DSK y cintas CAS con menú, de Louthrax | `SR` |
| Multi Mente | `MM` | Gestor de ficheros de dos paneles | `MM` |
| Utilidades | `UTIL` | Unas 120 herramientas: `DI` (DIR con nombres largos), `LOGIN`, reproductores, copias… | por su nombre |
| Red WiFi / UNAPI | `WIFI` | Programas de red TCP/IP: `HGET`, `FTP`, `TELNET`, `SNTP`, `FH` (File-Hunter)… | por su nombre |
| Fuentes de pantalla | `FONTS` | Tipos de letra para Multi Mente (ISO Latin-1, japonés, ruso…) | los usa MM |
| Música | `musica` | Reproductores de MoonBlaster Wave, VGM y más | por su nombre |
| HUB | `hub` | Cliente de MSX Hub, para instalar programas desde internet | `HUBG` o `HUB` |
| IA | `IA` | Cliente de chat con IA; tus claves van en `IA\ia.cfg` | `IA` |
| mapper e indev | `mapper`, `indev.com` | `MAPPER` desactiva el mapeador de MSX-DOS 2 para programas antiguos | por su nombre |

Siempre que haya sistema se crean también estas carpetas vacías. **No las borres**:

- `FHUNT`: donde el menú del MSXimus guarda lo que descarga del File-Hunter. El menú no puede crear carpetas, así que tiene que existir.
- `TMP`: carpeta temporal de MSX-DOS y de SofaRun.
- `SAVES` y `SETTINGS`, si marcaste SofaRun: sus partidas guardadas y su configuración.

**Nombre de la tarjeta**: es el nombre de la partición 1 que verás en Windows y con `VOL` en MSX-DOS. Las demás se llaman igual con su número detrás: «MSX 2», «MSX 3»…

### 3.5 Preparar

1. Pulsa **Preparar la tarjeta**.
2. El programa te enseña **qué va a borrar** (nombre, tamaño y unidades de la tarjeta) y **qué va a crear**. Léelo con calma. Solo sigue si respondes **Sí**; el botón por defecto es No.
3. La barra avanza mientras trabaja. Tarda unos segundos; con FAT32 en tarjetas grandes, algo más.
4. Al final, **verifica**: vuelve a leer la tabla de particiones y cada fichero copiado, y los compara con lo que quería escribir. Si todo cuadra, dice **«La tarjeta está lista y verificada»**.
5. Windows vuelve a montar la tarjeta solo. Cada partición aparece con su propia letra de unidad.

![Tarjeta terminada](capturas/4_terminado.png)

Ya puedes sacar la tarjeta. Usa «Expulsar» en Windows antes de quitarla, como con cualquier memoria.

---

## 4. Qué queda en la tarjeta

La **partición 1** (A: en el MSX), con Nextor 2.1.4 y todos los programas:

```
A:\
├── NEXTOR.SYS, COMMAND2.COM       el sistema (con Nextor 3: COMMAND3.COM)
├── MSXDOS2.SYS, MSXDOS.SYS…       sistema de respaldo
├── AUTOEXEC.BAT                   se ejecuta al arrancar (ver abajo)
├── bin\                           herramientas de Nextor: MAPDRV, DRIVERS, DEVINFO…
├── SOFARUN\  SAVES\  SETTINGS\    SofaRun y lo suyo
├── MM\  FONTS\                    Multi Mente y sus fuentes
├── UTIL\  WIFI\  musica\          utilidades, red y música
├── hub\  IA\  mapper\  indev.com
├── FHUNT\                         descargas del File-Hunter (no borrar)
└── TMP\                           temporal (no borrar)
```

Las **particiones 2, 3…** quedan vacías para tus juegos y programas.

### El AUTOEXEC.BAT

Se genera según lo que hayas elegido. Con todo marcado y tres particiones queda así:

```
PATH A:\;%1\BIN;%1\SOFARUN;%1\MM;%1\UTIL;%1\WIFI;%1\musica;%1\hub;%1\IA;%1\mapper
SET TIMEZONE=+02:00
mode 80
ALIAS .BAS = "BASIC "
ALIAS .ASC = "BASIC "
sntp pool.ntp.org /v
set temp %1\TMP
set MM=%1\MM
alias .ROM srom
alias .DSK sri
yenslash
SET FONT0808=%1\FONTS\ISO-LAT1.FNT
echo Type LOGIN to show system info (not for MSX1!)
echo Type DI for DIR with long filenames
echo Type SR to start Sofarun
echo Type MM to start Multi Mente
echo Type HUBG to start HUB Gui or HUB to CLI
echo Type FH to FileHunter Download
echo
echo Maped Units C,D
mapdrv c: 2 1 0
mapdrv d: 3 1 0
```

Qué hace cada parte:

- **`PATH`**: puedes escribir el nombre de cualquier programa desde cualquier carpeta, sin la ruta. `%1` es la unidad de arranque.
- **`SET TIMEZONE`**: la zona horaria (+02:00, horario de verano peninsular). Cámbiala si hace falta.
- **`mode 80`**: pantalla de 80 columnas.
- **`ALIAS`**: escribiendo el nombre de un `.BAS` se abre en BASIC; el de un `.ROM` o un `.DSK`, se lanza con SofaRun.
- **`sntp`**: pone el reloj en hora por internet, si hay red. Sin red da un error y sigue: es normal.
- **`mapdrv c: 2 1 0`**: monta la partición 2 como unidad C:, la 3 como D:, y así sucesivamente.

Puedes editar el `AUTOEXEC.BAT` desde Windows con el Bloc de notas. Guárdalo sin cambiarle el nombre.

---

## 5. El primer arranque en el MSX

1. Mete la tarjeta en la máquina y enciéndela.
2. **MSXimus y MSXnano**: si tienes activado «Menú al arrancar» en Ajustes, sale el navegador de la tarjeta.
   - La línea de abajo dice en qué partición estás, por ejemplo `P1/3`. **TAB** pasa a la siguiente.
   - **R**, **D** y **A** filtran por ROM, DSK o todo.
   - **ESC** sale del menú y arranca MSX-DOS desde la tarjeta.
3. MSX-DOS arranca, ejecuta el `AUTOEXEC.BAT` y queda en `A:\>`. Algo así (probado en un MSXimus Z con una tarjeta de tres particiones):

```
SNTP time setter for the TCP/IP UNAPI 1.1
*** ERROR: Unknown error when opening UDP connection (code 15)      <- sin red: normal
Type LOGIN to show system info (not for MSX1!)
Type DI for DIR with long filenames
Type SR to start Sofarun
Type MM to start Multi Mente
Type HUBG to start HUB Gui or HUB to CLI
Type FH to FileHunter Download

Maped Units C,D
A:\>vol c:
 Volume in drive C: is MSX 2
A:\>vol d:
 Volume in drive D: is MSX 3
```

Órdenes útiles para empezar:

| Escribe | Para |
|---|---|
| `SR` | SofaRun: elegir y lanzar ROM, DSK y cintas |
| `MM` | Multi Mente: copiar, mover y borrar ficheros |
| `DI` | Listar la carpeta con los nombres largos |
| `DIR C:` | Ver lo que hay en la partición 2 |
| `LOGIN` | Información del sistema |
| `BASIC` | Ir a MSX-BASIC |

---

## 6. Poner juegos y programas

Con la tarjeta en el PC, cada partición es una unidad de Windows. Copia los ficheros arrastrándolos como a cualquier memoria USB.

Una forma cómoda de organizarse:

| Partición | En el MSX | Para |
|---|---|---|
| 1 | A: | Sistema y programas (déjala como está) |
| 2 | C: | ROM de cartucho |
| 3 | D: | Discos DSK |
| 4 | E: | Música, imágenes, lo que quieras |

Hay que saber:

- **Nombres largos.** El menú del MSXimus y Windows los ven completos, como «Aleste 2 (1988).rom». MSX-DOS y SofaRun ven el nombre corto de 8+3 letras que Windows genera, como `ALESTE~1.ROM`.
- **El menú del MSXimus** recorre todas las particiones con TAB y lanza ROM y DSK sin pasar por MSX-DOS.
- **No formatees las particiones desde Windows.** Windows les cambiaría el formato o el tamaño de cluster. Para empezar de cero, vuelve a pasar la tarjeta por MSX SD Maker.
- **No borres `FHUNT` ni `TMP`** de la partición 1.

---

## 7. Guardar como imagen en vez de tarjeta

**Guardar como imagen…** crea un fichero `.img` con la tarjeta entera, en lugar de escribirla. Sirve para:

- Preparar varias tarjetas iguales: se graba la imagen con Rufus, balenaEtcher o Win32 Disk Imager.
- Probar en un emulador.
- Guardar una copia de una configuración.

Si hay una tarjeta elegida, la imagen tiene su mismo tamaño. Si no, el programa pregunta el tamaño (por ejemplo `8G`). La imagen solo ocupa en el disco del PC lo que se ha escrito de verdad, no el tamaño entero de la tarjeta.

---

## 8. Problemas frecuentes

**La tarjeta no aparece en la lista.**
Comprueba que está bien metida y pulsa **Actualizar**. Solo salen lectores SD y memorias USB extraíbles. Algunos adaptadores USB-SATA o USB-NVMe se presentan como disco fijo y no salen, a propósito.

**«La unidad E: está en uso: cierra lo que la tenga abierta».**
Cierra las ventanas del Explorador que muestren la tarjeta y los programas que tengan ficheros suyos abiertos. Vuelve a intentarlo.

**El programa dice que hacen falta permisos de administrador.**
Ábrelo con doble clic y responde **Sí** en la ventana de Windows.

**El MSX no llega a MSX-DOS.**
- ¿El sistema que elegiste coincide con el pack de BIOS o el `BOOT` de tu máquina? Mira la tabla del [paso 3.3](#33-el-sistema).
- ¿Elegiste FAT32? MSX-DOS no la lee.
- ¿Está «Menú al arrancar» activado? Entonces sale el menú primero: pulsa **ESC**.

**En MSX-DOS no aparecen C: ni D:.**
Con «MSX-DOS básico» no se copian las herramientas de Nextor, así que el `AUTOEXEC` no puede montarlas. Hazlo desde BASIC con `CALL MAPDRV`, o vuelve a preparar la tarjeta con Nextor.

**Sale «ERROR … opening UDP connection» al arrancar.**
Es `SNTP`, que intenta poner la hora por internet y no hay red. No afecta a nada. Si te molesta, borra esa línea del `AUTOEXEC.BAT`.

**La verificación ha encontrado errores.**
La tarjeta o el lector pueden estar fallando. Prueba otra vez y, si se repite, con otro lector u otra tarjeta.

**¿Puedo tener más de 8 particiones?**
No. El menú del MSXimus ve 8, y Nextor solo busca en las 9 primeras al arrancar.

**Windows dice que la tarjeta es más pequeña de lo que pone en la etiqueta.**
Es normal: los fabricantes cuentan 1 GB como 1.000 millones de bytes y Windows como 1.073 millones.

**¿Toca algo de mi PC?**
No. Solo escribe en la tarjeta que elijas, y el disco de Windows nunca aparece en la lista.

---

## 9. Para curiosos: cómo lo hace

- **Reparte la tarjeta igual que el `FDISK` de Nextor**, la herramienta que se abre con `CALL FDISK`. La partición 1 es primaria, activa y empieza en el sector 1. Las demás son lógicas dentro de una partición extendida. Así Nextor las numera 1, 2, 3… y `MAPDRV` las encuentra.
- **La FAT16 usa la geometría del `FDISK` de Nextor**: clusters de 2 a 64 KB según el tamaño, como mucho 65.524 clusters y 512 entradas en la raíz.
- **La FAT32** empieza en el sector 8192, con los datos alineados a 4 MB, como hace el formateador de la SD Association.
- **Nombres**: guarda el nombre corto de 8+3 que lee MSX-DOS y, si hace falta, también el nombre largo que ven Windows y el menú.
- **La tabla de particiones se escribe al final**, cuando todo lo demás ya está en su sitio. Luego se relee y se compara cada fichero con su CRC32.

El código fuente está en la carpeta [`fuente/`](fuente/) (Python 3 con tkinter; `construir_exe.bat` hace el `.exe` con PyInstaller). Para usarlo sin el `.exe` hace falta el contenido de la tarjeta en una carpeta `sd/` junto a `MSXsdmaker.py`, con `base/`, `nextor-2.1.4/`, `nextor-3.0.0-beta1/` y `extras/`. El `.exe` ya lo lleva dentro. Desde la línea de órdenes también se pueden hacer imágenes:

```
python MSXsdmaker.py imagen prueba.img --tamano 8G --esquema fat16-2g --n 3 --sistema nextor214 --programas todos
```

---

## 10. Licencias y créditos

MSX SD Maker es parte del proyecto MSXimus / MSXnano, de Albert (Papipapito), bajo GPL v3 como el resto del proyecto.

Los programas que copia en la tarjeta son de sus autores: Nextor y MSX-DOS, SofaRun, Multi Mente, las herramientas UNAPI, HUB y más. Mira [LICENCIAS.md](LICENCIAS.md): lleva la lista y el aviso de licencia de Nextor, que exige acompañar a sus ficheros.
