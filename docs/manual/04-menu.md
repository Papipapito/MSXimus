# 04. El menú de arranque

El MSXimus lleva un menú dentro de la BIOS. No es un programa que se cargue de la tarjeta: va en el pack de BIOS, en la ROM del cartucho interno, y arranca antes que MSX-DOS. Desde él se navega por la tarjeta SD, se lanzan ROMs y discos, se cambian los ajustes de la máquina, se configura la WiFi y se descargan ficheros.

Todo lo que hay en este capítulo está sacado del código del menú (`menu_main.asm`, `gm2.asm`, `srm_saves.asm` y `test_menu.asm` del repositorio `bios-msxnano-msximus`), no de memoria.

## 1. Qué pasa al encender

1. Sale el logo del MSXimus. Dura unos tres segundos.
2. Durante el logo, el menú mira el teclado. Tres teclas hacen algo:

| Tecla | Adónde va |
|---|---|
| **S** | Ajustes |
| **W** | Configuración WiFi del ESP32 |
| **T** | Menú de pruebas |

3. Si no se pulsa nada, manda el ajuste **Menú al arrancar**:
   - **On**: aparece el navegador de la SD (la pantalla principal de este capítulo).
   - **Off**: la máquina arranca directamente MSX-DOS o Nextor desde la tarjeta, como un MSX normal. El navegador no aparece.

Con el menú desactivado, la única forma de volver a activarlo es pulsar **S** durante el logo, poner **Menú al arrancar** en On y hacer **Save & Restart**.

Si no hay tarjeta o no se puede leer, sale una pantalla con el aviso *"No se detecta la tarjeta SD."* y la línea *"RETURN=Boot MSX S=Settings W=WiFi"*. RETURN o ESC arrancan el sistema igualmente, S abre Ajustes, W la WiFi y T las pruebas.

## 2. El navegador de la SD

Es la pantalla principal. Texto de 80 columnas, con este reparto:

- **Fila 1**: el título, *MSXimus*.
- **Fila 2**: las tres pestañas de filtro, `[R]OM  [D]SK  [A]LL`. La activa se ve en vídeo inverso. Al entrar está en ALL.
- **Filas 4 a 21**: la lista, 18 entradas por página, **ordenada**: primero las carpetas y después las ROM y los discos juntos, por orden alfabético sin distinguir mayúsculas (desde la v3.7.4). A la derecha de cada entrada, `[DIR]` si es una carpeta o el tamaño en KB si es un fichero. Se ven los nombres largos; si el seleccionado no cabe en la ventana de 59 columnas, se desplaza solo como una marquesina.
- **Fila 23**: el pie con las teclas, `R/D/A=Filtro  ESC=Boot  S=Set  W=WiFi  TAB=Part  H=Ayuda`, y en el centro el contador `seleccionado/total`, que termina en `+` si la carpeta tiene más entradas de las que caben.

Solo se listan carpetas, ficheros `.ROM` y ficheros `.DSK`. El resto de la tarjeta no aparece, y tampoco lo oculto o de sistema: la `System Volume Information` de Windows, las `.Trashes` y `.fseventsd` y los `._nombre.rom` que deja un Mac al copiar. Se puede bajar hasta ocho niveles de carpetas.

Caben **112 entradas por carpeta**. Si hay más, las que sobran (las últimas que se copiaron a la tarjeta) no salen y el contador acaba en `+` (`112/112+`): conviene repartirlas en subcarpetas. Las listas del File-Hunter no se ordenan: van en el orden del servidor.

### Teclas del navegador

| Tecla | Qué hace |
|---|---|
| **Arriba / Abajo** | Mover la selección |
| **Izquierda / Derecha** | Saltar una página entera (18 entradas) atrás o adelante |
| **RETURN** | Entrar en la carpeta, o abrir la pantalla de lanzar si es una ROM o un disco |
| **BACKSPACE** | Volver a la carpeta anterior |
| **/** | Buscar por nombre. Abre un campo en la fila 0: se escribe un trozo del nombre (hasta 12 caracteres, sin distinguir mayúsculas), RETURN salta a la siguiente coincidencia desde la selección actual y da la vuelta al final, ESC cancela |
| **TAB** | Cambiar de partición, si la tarjeta tiene más de una |
| **R**, **D**, **A** | Filtrar: solo ROMs, solo discos, o todo |
| **S** | Ajustes |
| **W** | Configuración WiFi |
| **T** | Menú de pruebas |
| **F** | File-Hunter: buscar y descargar de internet |
| **H** | Ayuda: una pantalla con esta misma lista de teclas |
| **ESC** | Arrancar el sistema (MSX-DOS o Nextor de la tarjeta) |

El mando en el puerto 1 también sirve: las cuatro direcciones mueven igual que los cursores, el botón A es RETURN y el botón B es BACKSPACE. Arriba y abajo se repiten solos al mantenerlos; izquierda y derecha (saltar página) cuentan **una vez por pulsación** desde la v3.7.5: un mando con la izquierda atascada devolvía 18 entradas atrás toda selección a partir de la 18, y parecía que la lista no hacía scroll.

## 3. Lanzar una ROM

Al pulsar RETURN sobre una `[ROM]` se abre la pantalla **Lanzar ROM**. Tiene un formato fijo:

- **Fichero**: el nombre completo.
- **Tamaño**: en KB.
- **Mapper**: el tipo de cartucho con el que se va a emular.
- **SRAM: On/Off**: solo aparece con mappers ASCII8 y ASCII16, que son los que llevan SRAM de cartucho.
- **GM2: On/Off**: solo aparece con mappers Konami y Konami-SCC, que son los que usan el Game Master 2.
- Una **barra de progreso** de 64 celdas para la carga.
- Una **línea de estado** con lo que está pasando.
- El **pie** con las teclas disponibles.

Nada más entrar, la línea de estado dice *"Analizando ROM..."* con un indicador girando mientras el menú decide el mapper.

### Cómo se decide el mapper

1. Si la ROM ocupa 32 KB o menos, es **Plain** (lineal, sin mapper), salvo que el nombre diga otra cosa.
2. Si es mayor, manda la **etiqueta del nombre** si la hay: `[ASCII16]`, `[ASCII8]`, `[SCC]`, `[KONAMI]`, `NEO16` o `NEO-16`, `NEO8` o `NEO-8`. Son las etiquetas que pone File-Hunter al descargar, y las que puede poner uno mismo al renombrar un fichero.
3. Sin etiqueta, se **analiza el contenido** de la ROM buscando las instrucciones con que cada mapper cambia de banco, al estilo de openMSX. En los cores con DMA el análisis lo hace el propio hardware mientras carga y es instantáneo.
4. Una ROM que el análisis da como Konami pero mide 320 KB o más se promociona a **Konami-SCC**: el Konami original nunca pasa de 256 KB.
5. Ya cargada, se mira la **firma del autor** (v3.8): ocho letras en el offset 10h del fichero, o en 4010h, según la convención de MSXgl. `ROM_ASC8`, `ROM_AS16`, `ROM_KON4`, `ROM_KON5`, `ROM_NEO8`, `ROM_NE16` y `ASCII16X` fijan el mapper por encima de la etiqueta y del análisis. Así arrancan solas las ROM de geo3d y lo hecho con MSXgl. Detalle en el [capítulo 05](05-roms-mappers.md).
6. Y dos casos especiales. Una ROM de más de 4 MB sin firma es **ASCII16-X** (así arranca tal cual la V9968 TECH DEMO 0.7.5 de renatus, de 8 MB). Y una de 16 a 48 KB que no lleva `AB` al principio pero sí en +4000h es **Plain 0000h**: una imagen lineal desde la dirección 0000h, como las demos V9990 de Edd Biddulph.

Si el análisis no ve nada, el mapper queda como *"? (desconocido)"* y hay que elegirlo a mano con la tecla M.

Los mappers disponibles son: Plain, Konami, Konami-SCC, ASCII8, ASCII16, NEO-8, NEO-16, Plain 0000h y ASCII16-X. Las ROMs de hasta 8 MB caben en la megaram.

### Teclas de la pantalla de lanzar ROM

| Tecla | Qué hace |
|---|---|
| **RETURN** | Cargar la ROM en la megaram y lanzarla. La barra avanza durante la carga, el estado dice *"Cargando ROM en megaram..."* y luego *"ROM cargada."*; después la máquina se reinicia con la ROM como si fuera un cartucho |
| **M** | Cambiar el mapper. Cicla Plain, Konami, Konami-SCC, ASCII8, ASCII16, NEO-8, NEO-16, Plain 0000h, ASCII16-X y vuelta a Plain. Al cambiar, la SRAM y el GM2 vuelven a su valor por defecto |
| **S** | Conmutar la SRAM de cartucho para este lanzamiento. Solo actúa en ASCII8 y ASCII16. Por defecto está Off, salvo que el nombre lleve `KOEI` o `SRAM`, en cuyo caso arranca On |
| **G** | Conmutar el Game Master 2 para este lanzamiento. Solo actúa en Konami y Konami-SCC. Por defecto toma el valor del ajuste **Slot 1** |
| **ESC** | Volver al navegador sin lanzar |

Hay un caso en que RETURN no hace nada: cuando el estado dice *"INIT pag.0/BASIC: no lanzable"*. Es una ROM plana cuyo punto de entrada cae fuera de la ventana del cartucho, normalmente un programa BASIC empaquetado como ROM. Lanzarla reiniciaría la máquina, así que el menú lo impide. Cambiar el mapper con M vuelve a evaluar ese veto.

### La SRAM y el guardado de partidas

Al lanzar un ASCII8 o ASCII16 con **SRAM On**, el menú busca en la carpeta `FHUNT` de la raíz de la tarjeta un fichero con el mismo nombre que la ROM y extensión `.SRM` (32 KB). Si existe, lo carga como SRAM del cartucho; si no, lo crea vacío. La partida se guarda en la SRAM emulada mientras se juega, y se escribe de vuelta a ese `.SRM` **en el siguiente arranque del navegador**, que es cuando el menú vuelve a tener la tarjeta montada. Por eso, para conservar la partida hay que hacer **RESET, no apagar**: la memoria aguanta un reset, pero no un apagado.

Los mensajes que se ven: *"SRAM: cargando ..."*, *"SRAM: nueva (FF) -> FHUNT"*, *"SRAM cambiada: guardando FHUNT/..."* con *"OK"*. Si no existe la carpeta FHUNT, *"SRAM: sin FHUNT, no se guarda"*: la SRAM funciona pero se pierde. Las ROMs de 4 MB no dejan sitio para la SRAM y tampoco se guardan.

### El Game Master 2

El Game Master 2 es el cartucho de Konami que añadía guardado de partidas a sus juegos. El MSXimus lo emula en el slot 1 cuando se lanza un juego Konami con **GM2 On**. Necesita dos ficheros en `FHUNT`: `GM2.ROM` (la ROM original del cartucho, 128 KB, la pone el usuario) y `GM2.SRM` (8 KB, se crea solo la primera vez). El guardado a la tarjeta funciona igual que el de la SRAM: en el siguiente arranque, y tras un RESET.

Si falta algo, el juego se lanza sin GM2 y la línea de estado dice por qué: *"GM2: falta FHUNT/GM2.ROM"*, *"GM2: GM2.ROM no mide 128 KB"*, *"GM2: sin FHUNT"*, o *"GM2: este core no lo trae"* si el core es anterior a la 3.5f. Los juegos de 4 MB no dejan sitio y con ellos no se arma.

## 4. Lanzar un disco

Al pulsar RETURN sobre un `[DSK]` se abre **Lanzar disco**, con el nombre del fichero, *"Tipo: Disco (Nextor)"* y el estado *"DSK listo para montar."*.

| Tecla | Qué hace |
|---|---|
| **RETURN** | Montar y lanzar |
| **ESC** | Volver |

El disco se monta con la emulación de disco de Nextor: al seguir el arranque, Nextor lo ve como la unidad A: en modo MSX-DOS 1 y ejecuta su sector de arranque. Dura hasta el siguiente reinicio. Para que funcione, el fichero `.dsk` tiene que estar **en clusters consecutivos** de la tarjeta; si no, el menú avisa con *"DSK fragmentado: recopialo"* y basta con copiarlo de nuevo a la tarjeta desde el PC.

En tarjetas FAT16 el menú necesita un fichero oculto `NEXTOR.EMU` en la raíz, que crea él solo la primera vez. Si no puede crearlo dice *"Falta NEXTOR.EMU en la raiz"*. En FAT32 no hace falta: usa un sector reservado de la partición.

## 5. Ajustes (tecla S)

La pantalla **MSXimus - Ajustes** tiene estas opciones:

| Opción | Valores | Qué es |
|---|---|---|
| **Slot 1** | Nada / 2o SCC / Game Master 2 | Qué hay en el slot 1 del MSX. *2o SCC* pone un segundo chip SCC para los juegos que lo buscan como cartucho aparte. *Game Master 2* deja el GM2 activado por defecto para los juegos Konami |
| **Enable Scanlines** | On / Off | Líneas de barrido en la salida HDMI |
| **Stereo Sound** | On / Off | Sonido en estéreo |
| **Boot Turbo** | On / Off | Arrancar siempre con la CPU a 5,37 MHz. Solo entra en un arranque en frío: hay que apagar y encender, no basta el reset |
| **Menú al arrancar** | On / Off | Si aparece el navegador de la SD al encender o se arranca MSX-DOS directamente |
| **Mezclador de audio** | | Abre la página del mezclador (v3.7): la ganancia maestra y el nivel de cada chip, con nota de prueba. Ver el [capítulo 08](08-audio.md) |
| **Instalar actualización** | | Graba el `MSXIMUS.UPD` de la raíz de la SD: el core, el pack o los dos (v3.8). Lo comprueba entero antes de borrar nada y pregunta. Ver el [capítulo 11](11-actualizar.md) |
| **Save & Restart** | | Guardar en la flash y reiniciar |

Debajo se muestra *"Version FPGA (.fs): x.y.z"*, la versión del core que hay flasheado (`3.7.6`; el tercer dígito sale del puerto 29h desde la 3.7.1, y con un core anterior solo se ve `3.7`), o *"desconocida"* si el core no la publica.

| Tecla | Qué hace |
|---|---|
| **Arriba / Abajo** | Mover entre opciones |
| **ESPACIO** | Cambiar el valor de la opción seleccionada. En *Slot 1* va ciclando los tres estados. Sobre *Save & Restart* guarda y reinicia |
| **ESC** | Volver al navegador **sin guardar** |

Los cambios solo se escriben en la flash con *Save & Restart*. ESC, o reiniciar la máquina por otro camino, los descarta. La fila 22 recuerda las teclas.

## 6. Configuración WiFi (tecla W)

La tecla W no abre una pantalla del menú, sino el menú de configuración que trae el propio firmware del ESP32-C6, el **Wi-Fi Setup** del driver TCP/IP UNAPI de ducasp. Sus opciones son *Set Nagle*, *Wi-Fi On Period*, *Scan/Join Access Points* y *Wi-Fi and Clock Settings*; con ESC se vuelve al navegador. Es ahí donde se elige la red y se pone la contraseña. La opción de reloj pone en hora el MSX por internet.

Necesita el ESP32-C6 cableado y con su firmware, como se explica en el capítulo de instalación. Sin él, esa pantalla muestra caracteres sin sentido, porque lee de una línea serie a la que no responde nadie.

## 7. File-Hunter (tecla F)

Busca ROMs y discos en la base de datos de File-Hunter y los descarga a la tarjeta. Hace falta la WiFi configurada y una carpeta `FHUNT` en la raíz de la tarjeta, creada desde MSX-DOS con `MKDIR FHUNT`.

1. **F** abre el campo *"File-Hunter Buscar:"* en la fila 0. Se escribe el texto (hasta 20 caracteres), RETURN busca y ESC cancela.
2. Se ven los pasos: *"Conectando..."*, *"DNS..."*, *"Abriendo..."*, *"Enviando GET..."*. Se hacen dos consultas seguidas, una de ROMs y otra de discos, y los resultados salen juntos en la lista del navegador.
3. En la lista de resultados: **RETURN** descarga el seleccionado, **F** hace otra búsqueda, **ESC** o **BACKSPACE** salen de File-Hunter. Los filtros y el resto de teclas del navegador no actúan aquí.
4. La descarga va a `FHUNT` con el nombre original en formato 8.3 y la etiqueta de mapper que dé la API, por ejemplo `[SCC].rom`. Se ve *"FH: bajando ..."* y al acabar se comprueba el CRC (*"CRC OK"*). Si ya existe un fichero con ese nombre y el mismo tamaño no se vuelve a bajar: la carpeta hace de caché. Si existe con otro tamaño pregunta *"Ya existe. Sobreescribir? (S/N)"*.
5. Al terminar, el fichero se **lanza solo** por el mismo camino que cualquier ROM o disco de la tarjeta.

Límites: la tarjeta tiene que ser **FAT16** (con FAT32 dice *"FH: la SD es FAT32 (v1 solo FAT16)"*), la carpeta FHUNT tiene que existir (*"Falta FHUNT (MKDIR en DOS)"*) y los nombres se escriben en 8.3.

Mensajes de error: *"FH: sin UNAPI"* (no se ve el driver del ESP), *"FH: sin red (tecla W)"*, *"FH: fallo DNS"*, *"FH: sin conexion"*, *"FH: sin resultados"*, *"FH: timeout de descarga"*, *"FH: respuesta API rara"*, *"FH: error SD"*, *"FH: SD llena"*, *"FH: CRC MAL"*.

## 8. Menú de pruebas (tecla T)

La pantalla **MSXimus - Pruebas** sirve para comprobar que la máquina va bien y para medir. Arriba muestra la versión del core, si el core trae cronómetro propio, el tipo de tarjeta (SD v1, SD v2 o SDHC) y los bytes de configuración del core (`#41`, `#42` y `#46`, con el estado del menú al arrancar).

| Tecla | Prueba |
|---|---|
| **1** | Velocidad de lectura de la SD. Lee los mismos 128 KB por cada uno de los cuatro caminos posibles (ventana, puertos sector a sector, puertos en multibloque y DMA a RAM) y da los KB/s de cada uno. No escribe nada en la tarjeta. Con un core sin DMA la cuarta fila dice *"(este core no trae la DMA)"* |
| **2** | Sonido: una nota por el PSG y otra por el OPLL (MSX-MUSIC) |
| **3** | Game Master 2 en el slot 1: vuelca lo que ve en el slot 1 con la ROM y la SRAM del último lanzamiento, para comprobar que el mapeo es correcto |
| **4** | VDP: cuenta cuántas veces se ven los bits HR y VR del registro de estado S#2 en 20000 lecturas, y da la referencia de un V9938 real |
| **ESC** | Seguir arrancando |

## 9. Ayuda (tecla H)

Una pantalla con la lista de teclas del navegador. Cualquier tecla vuelve.

## 10. Resumen de todas las teclas

| Dónde | Teclas |
|---|---|
| Logo | S, W, T |
| Sin tarjeta | RETURN, ESC, S, W, T |
| Navegador | cursores, RETURN, BACKSPACE, /, TAB, R, D, A, S, W, T, F, H, ESC, mando (direcciones, A, B) |
| Búsqueda por nombre | texto, RETURN, BACKSPACE, ESC |
| Lanzar ROM | RETURN, M, S, G, ESC |
| Lanzar disco | RETURN, ESC |
| Ajustes | Arriba, Abajo, ESPACIO |
| File-Hunter | texto, RETURN, BACKSPACE, F, ESC |
| Pruebas | 1, 2, 3, 4, ESC |
| Ayuda | cualquiera |
