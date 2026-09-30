# 02. Mapa de puertos de E/S

Todos los puertos a los que responde el core, sacados del decodificador de `fpga/top.v` y de los módulos que cuelgan de él. Los puertos que no aparecen devuelven FFh en lectura y se ignoran en escritura: no hay bus externo.

## 1. Resumen

| Puertos | Dispositivo | Estándar MSX |
|---|---|---|
| 06-07 | UART del ESP32 (WiFi UNAPI) | no |
| 10-12 | Segundo PSG | no |
| 20-27 | Último informe del mando por los USB-A (diagnóstico) | no |
| 29, 2A-2F | Tercer dígito de la versión, arranque de la DDR3, diagnóstico USB y del ratón, versión del core | no |
| 34-37 | Diagnóstico de la DDR3 y del cargador de ondas | no |
| 40-4F | E/S conmutada: configuración del core, SD por puertos, OCM, turbo Panasonic | OCM |
| 7C-7D | OPLL (MSX-MUSIC) | sí |
| 7E-7F | OPL4, parte de ondas (MoonSound) | sí |
| 88-8B | V9968 como cartucho externo (alias del interno) | HRA! |
| 98-9B | V9968 (el VDP de la máquina) | sí |
| A0-A2 | PSG | sí |
| A8-AB | PPI: slots, teclado, casete, click | sí |
| B4-B5 | Reloj de tiempo real | sí |
| C0-C1 | Y8950 (MSX-Audio) | sí |
| C4-C7 | OPL4, parte FM (MoonSound) | sí |
| D8-DB | Fuente kanji JIS1 y JIS2 | sí |
| E4-E7 | S1990 (identificación turbo R) | sí |
| F2 | Registro libre de 8 bits | no |
| FC-FF | Registros del mapper de RAM | sí |

## 2. La E/S conmutada: 40h a 4Fh

Es el mecanismo del OCM. Se escribe en el puerto **40h** el identificador de un dispositivo y a partir de ahí los puertos 41h a 4Fh son de ese dispositivo. Leer 40h devuelve el identificador invertido, que es como el software comprueba que el dispositivo existe. El MSXimus responde a tres identificadores:

| OUT 40h | Lee 40h | Dispositivo |
|---|---|---|
| 48h | B7h | La configuración del core, la del menú de Ajustes. Es el dispositivo "goauld" heredado del MSXnano |
| 08h | F7h | Turbo del T9769 de Panasonic, para el software que lo maneja así |
| D4h | 2Bh | E/S conmutada del OCM: órdenes inteligentes en 41h y DIP virtuales en 42h |

Sin dispositivo seleccionado, o con otro identificador, 41h-4Fh caen en el módulo OCM.

### Dispositivo 48h: la configuración del core

| Puerto | Acceso | Contenido |
|---|---|---|
| 41h | R/W | Config 1. bit 0 mapper activo, bit 1 megaram activa, bit 2 segundo SCC en el slot 1, bit 3 scanlines, bits 5-4 slot del mapper (11 = expandido 3-0), bits 7-6 slot de la megaram (11 = expandido 3-3 al arrancar; el dispositivo OCM la pasa a 10 = slot 2 al lanzar una ROM) |
| 42h | R/W | Config 2. bit 0 SD activa, bits 2-1 slot de la SD (3-2), bit 3 menú al arrancar, bit 4 Game Master 2 en el slot 1, bit 5 estéreo. En escritura, el bit 6 ordena guardar la configuración en la flash y el bit 7 ordena un reset; solo se almacenan los bits 5-0 |
| 43h | W | Configuración de la SRAM de la megaram, volátil. En ASCII8 el bit de habilitación; en ASCII16 distinto de cero activa el modo "valor 10h"; 0 la apaga |
| 44h | R/W | Mezclador de audio (v3.7). Escritura: `{solo_sel[7], canal[6:4], nivel[3:0]}`. Canal 0 = la ganancia maestra de siempre (nivel 0-7 = x1..x8, así que `OUT 44h,0..7` sigue significando lo mismo); canales 1-6 = PSG, SCC, OPLL, MSX-Audio, OPL4 FM, OPL4 wave, nivel 0-8 = k/8 (8 = tal cual, 0 = mudo); el 7 (WaveGame) solo existe en la línea Zynq. Con el bit 7 a 1 no escribe: solo selecciona el canal. Lectura: `{0, canal seleccionado, su nivel}`; el canal 7 lee Fh en el Tang. Sonda del menú: `OUT 44h,F0h` + `IN 44h` = 7nh si hay mezclador. Todo se guarda en la flash con la orden de 42h |
| 45h | R/W | bit 0 = arrancar en turbo. Se guarda en la flash como el byte 'T' |
| 46h | R/W | Extensión del mapper de la megaram, volátil pero sobrevive al reset del MSX: bit 0 NEO (convierte ASCII8 en NEO-8 y ASCII16 en NEO-16), bit 1 Plain 0000h (la megaram responde también en la página 0, con la dirección del Z80 tal cual), bit 2 ASCII16-X (con el SWIO de ASCII16: bancos de 12 bits, hasta 8 MB), bit 4 mitad alta de los 4 MB para el cargador, bit 6 Game Master 2 armado. En lectura, el bit 7 a 1 dice que el core trae el Game Master 2 |
| 47h-4Fh | | El controlador de la SD por puertos, en el apartado siguiente |

Una escritura en 41h o en 42h pasa por una copia temporal y se confirma en el registro **de ese mismo puerto** en el ciclo siguiente. Desde el 24 de septiembre de 2026 cada puerto confirma solo el suyo: antes cualquiera de los dos confirmaba los dos, con la copia del otro a cero, y un `OUT 42h` suelto desde un programa (TURBO.COM `/P`, el estéreo desde BASIC) dejaba config1 a cero y, con el bit de guardar, lo grababa en la flash. Guardar en la flash es el bit 6 de 42h, y el bit 7 reinicia.

El reset del MSX borra del 46h los bits 3-7 a propósito (si el Game Master 2 quedara armado, el escaneo de slots de la BIOS se toparía con su firma en el slot 1) y, desde el 24 de septiembre, **conserva los bits 0-2**: tras un reset la BIOS relanza la ROM cargada y sin ellos la lanzaba con el mapper básico.

Desde la v3.7.5, las escrituras a 40h-43h, 45h y 46h, como la del 44h desde la v3.7, pasan por una etapa de registro en 27 MHz: petición, dirección y dato se capturan juntos y se aplican un ciclo después. Es invisible para el software (un OUT dura unos 20 ciclos de 27 MHz) y quitó el cruce de 54 a 27 MHz que tumbaba casi todos los dados ([capítulo 07](07-sintesis-campanas.md)).

### Dispositivo 48h, puertos 47h a 4Fh: la SD por puertos

Es el interfaz que usan el menú y el driver de Nextor. La ventana de memoria clásica sigue existiendo (capítulo 03) y ambos caminos gobiernan el mismo controlador.

| Puerto | Acceso | Contenido |
|---|---|---|
| 47h | W | Orden: bit 0 leer, bit 1 escribir, bit 2 DMA (con el bit 0), bit 3 contar patrones de mapper durante la DMA, bit 4 poner a cero los contadores, bit 7 inicializar la tarjeta. Además rebobina el puntero del búfer |
| 47h | R | Estado: bit 7 ocupado, bit 3 bloque listo, bit 2 error de CRC en lectura, bit 1 timeout, bit 0 error de CRC en escritura. Los bits 6-5 fijos a 0 y el bit 4 fijo a 1 sirven de sonda: un core sin puertos devuelve FFh |
| 48h-4Bh | W | Los cuatro bytes del número de sector, del bajo al alto |
| 48h | R | Tipo de tarjeta: 0 desconocida, 1 SD v1, 2 SD v2, 3 SDHC |
| 4Ch | R/W | Un byte del búfer de sector; el puntero avanza solo, pensado para INIR y OTIR |
| 4Dh | R/W | Número de bloques de la siguiente orden: 0 o 1 un solo sector, N mayor que 1 lectura o escritura multibloque |
| 4Eh | W | Índice del byte de información que devolverá la lectura de 4Eh |
| 4Eh | R | El byte de información elegido, según la tabla de abajo |
| 4Fh | W | 80h arma el registro de destino de la DMA y los tres OUT siguientes son la dirección; cualquier otro valor rebobina el puntero del búfer |
| 4Fh | R | Puntero del búfer, byte bajo, para depurar |

Índices de 4Eh:

| Índice | Devuelve |
|---|---|
| 2 | El mismo estado que 47h |
| 7, 8, 9 | Tamaño de la tarjeta (C_SIZE), tres bytes |
| 10 | C_SIZE_MULT |
| 11 | READ_BL_LEN |
| 12 | Tipo de tarjeta |
| 25, 26, 27 | Cronómetro de milisegundos, tres bytes. Al pedir el 25 se congela la foto de los 24 bits, y 26 y 27 devuelven esa misma foto |
| 28 | 54h ('T'): este core tiene cronómetro |
| 29 | 44h ('D'): este core tiene DMA de lectura |
| 31 | 4Dh ('M'): la DMA tiene modo lógico y contadores de mapper |
| 32-33, 34-35, 36-37, 38-39 | Los cuatro contadores de patrones de la DMA, 16 bits cada uno: Konami-SCC, Konami, ASCII8, ASCII16 |

El cronómetro va con el reloj de 27 MHz y no depende de las interrupciones del MSX; existe porque el menú medía la carga con el contador de la BIOS, que se para con las interrupciones inhibidas. Todo el detalle de la DMA está en el capítulo 06.

### Dispositivo 08h: el turbo de Panasonic

| Puerto | Acceso | Contenido |
|---|---|---|
| 41h | W | Solo el bit 0, activo a nivel bajo: 0 pone 5,37 MHz, 1 pone 3,58 MHz |
| 41h | R | bit 0 estado del turbo (0 = activo), bit 2 a 0 (turbo disponible), bit 7 a 1; es decir FAh en turbo y FBh en normal |

Es el protocolo que openMSX describe para el MSXMatsushita, y el que usan los juegos y utilidades que conocen el turbo de la serie FS-A1.

### Dispositivo D4h: la E/S conmutada del OCM

Llega del módulo `swioports` del OCM-PLD. El menú la usa para una sola cosa: la orden inteligente 0Fh en 41h, que pone el slot 2 en modo SCC-I interno, que es como el cargador escribe la megaram. Los DIP virtuales del puerto 42h fijan el modo de ese slot 2.

## 3. El resto de puertos, uno a uno

### 06h-07h: UART del ESP32

Es el puente `wifi_lite` de ducasp, agnóstico al módulo. Un byte por acceso, sin búfer de transmisión, FIFO de recepción de 2080 bytes.

| Puerto | Acceso | Contenido |
|---|---|---|
| 06h | W | Orden de velocidad. La versión "lite" solo reconoce la 20, que vacía el FIFO; la velocidad es fija |
| 06h | R | Saca un byte del FIFO de recepción. Si está vacío, el hardware retiene la lectura hasta 25 ms esperando un byte; si no llega, devuelve FFh y marca underrun |
| 07h | W | Byte a transmitir |
| 07h | R | Estado: bit 0 hay datos, bit 1 transmisión en curso, bit 2 FIFO lleno, bit 3 soporta recepción rápida, bit 4 underrun |

El módulo pone al Z80 en espera durante sus ciclos de E/S.

### 10h-12h: segundo PSG

Un segundo YM2149 completo, con la misma decodificación que el principal desplazada: 10h dirección, 11h escritura, 12h lectura. Para el software que espera un PSG ahí. (Con la opción `DIETA_V36H` desaparece y 12h lee FFh; en producción va.)

### 20h-27h: el último informe del mando

Los ocho bytes del último informe HID del mando conectado a un USB-A, tal cual los recibe el host: `FOR I=0 TO 7:PRINT HEX$(INP(&H20+I));" ";:NEXT`. Es para diagnosticar mandos genéricos (entraron el 28 de septiembre para la caza del 0810:0001). Son casi estáticos entre dominios de reloj: valen para mirar, no para jugar.

### 29h-2Fh: diagnóstico y versión

| Puerto | Devuelve |
|---|---|
| 29h | Tercer dígito de la versión (FPGA_PATCH): 6 en la 3.7.6. El menú lo imprime tras «3.7» si vale 1-15; un core anterior devuelve FFh y el menú imprime «3.7» a secas. Comparte término del mux de lectura con el 2Fh: `bus_addr[2]` elige cuál |
| 2Ah | Arranque de la DDR3 (v3.7b): décimas de segundo desde el encendido hasta que la VRAM calibró (255 = 25 s o más, o no ha calibrado) |
| 2Bh | Arranque de la DDR3: duración en centésimas del intento de calibración que lo consiguió (255 = 2,55 s o más); sin calibrar, el intento en curso |
| 2Ch | Arranque de la DDR3: bit 7 = calibrada; bits 6-0 = intentos de calibración fallidos antes (0 = a la primera, 127 = saturado) |
| 2Dh | Estado del USB: bit 7 error de conexión en el USB 2, bit 6 en el USB 1, bits 5-4 tipo del USB 2 y bits 3-2 tipo del USB 1 (0 nada, 1 teclado, 2 ratón, 3 mando), bits 1-0 cuenta de informes recibidos, que cambia si el dispositivo habla |
| 2Eh | Estado interno del ratón |
| 2Fh | Versión del core, en BCD: 37h es la 3.7 (con el 29h, la 3.7.6) |

El menú de Ajustes muestra la versión leyendo 2Fh. Un core anterior a que existiera devuelve FFh, y el menú dice "desconocida".

Los tres de la DDR3 son la respuesta al arranque en negro desde un cargador (capítulo 10 del manual): desde BASIC, `PRINT INP(&H2C) AND 127, INP(&H2B)*10, INP(&H2A)/10` dice cuántos intentos fallaron, cuántos milisegundos duró el bueno y a los cuántos segundos arrancó el vídeo.

### 34h-37h: DDR3 y cargador de ondas

Cuatro puertos de solo lectura que dejó el bring-up de la DDR3 para el OPL4, cuando las ondas vivían en ella (desde la _104 van por la SDRAM del dock, `wave_sdram`, y los puertos conservan el nombre y la interfaz): 34h diagnóstico de la DDR3, 35h diagnóstico del motor, 36h estado del cargador (bit 2 = copiando la YRW801), 37h un byte de la DDR3 leído por anticipado.

### 7Ch-7Dh: OPLL

El YM2413 de MSX-MUSIC, solo escritura: 7Ch registro, 7Dh dato.

### 7Eh-7Fh: OPL4, ondas

La parte PCM del MoonSound: 7Eh registro y 7Fh dato del motor de 24 slots. La ROM de ondas es la YRW801 de 2 MB, copiada de la flash (0x500000) a la región de ondas de la SDRAM del dock al arrancar (capítulo 03).

### 88h-8Bh y 98h-9Bh: el V9968

Los cuatro puertos clásicos del VDP: 98h datos de VRAM, 99h registros y estado, 9Ah paleta, 9Bh registros indirectos. El rango 88h-8Bh es un alias del mismo chip: el software escrito para el cartucho V9968 de HRA! lo busca ahí como VDP externo, y en el MSXimus el V9968 ya es el interno.

El 99h recibe los registros en pares de bytes (dato y luego número con el bit 7 a 1). Desde la 3.7.6, un par a medias se cancela con cualquier lectura del VDP y con una escritura al 98h, como en el V9938/V9958 y en openMSX; antes solo lo cancelaba la lectura del estado. El primer byte de la paleta (9Ah) comparte ese latch.

Los puertos 9Ch y 8Ch, el "puerto 4" que el V9968 define para los flags de interrupción, **no están decodificados**. El capítulo 05 explica qué implica.

### A0h-A2h: PSG

El YM2149 principal. En A2h con el registro 14 seleccionado se lee el joystick, que viene del mando o del ratón USB; el bit 6 del registro 15 elige el puerto. Los botones 3 y 4 del mando hacen autodisparo sobre los botones 1 y 2. El registro 15 se relee (lo último escrito): la BIOS lo lee, modifica y escribe en cada interrupción, y devolver FFh conmutaba el pin 8 del puerto 2 a 60 Hz y vaciaba el ratón (arreglado en la v3.6e). Los demás registros siguen devolviendo FFh al leerlos: el `O_DA` del YM2149 está sin conectar, aunque el modelo los sirve.

### A8h-ABh: PPI

| Puerto | Contenido |
|---|---|
| A8h | Registro de slots primarios |
| A9h | Lectura de la fila del teclado seleccionada |
| AAh | bits 3-0 fila del teclado, bit 4 motor del casete, bit 5 salida de casete, bit 6 LED de kana, bit 7 click del teclado. Se puede releer |
| ABh | Registro de control: el modo de poner y quitar bits sueltos del puerto C, que usa la BIOS para CAPS, el click y el motor |

### B4h-B5h: reloj de tiempo real

El RP5C01 de un MSX2: B4h selecciona el registro, B5h lo lee o escribe. Su reset está fijo a cero, así que hora y RAM sobreviven a los resets del MSX; no hay pila, al apagar se pierden. Con el ESP32 conectado, el driver de red puede ponerlo en hora por internet.

### C0h-C1h: Y8950

MSX-Audio: C0h registro, C1h dato. En lectura, C0h devuelve el estado con los flags de los temporizadores, el fin de muestra y el búfer del ADPCM. La IRQ va al Z80 en AND cableado, y arranca enmascarada.

### C4h-C7h: OPL4, FM

La parte OPL3 del MoonSound: C4h/C5h primer banco de registros, C6h/C7h segundo banco. En lectura, el estado.

### D8h-DBh: fuente kanji

El interfaz estándar: D8h y D9h fijan la dirección en JIS1, DAh y DBh en JIS2, y la lectura devuelve los bytes del glifo. Los 256 KB de fuente viven en la SDRAM.

### E4h-E7h: S1990

El controlador del turbo R, solo para identificarse como tal. La BIOS y el software leen aquí el modo de CPU y CHGCPU conmuta el turbo del core. No hay R800 detrás.

### F2h: registro libre

Un byte de lectura y escritura sin función en el hardware. Se lee tal como se escribió.

### FCh-FFh: mapper de RAM

Los cuatro registros de segmento del mapper, uno por página de 16 KB. Son de **solo escritura** en el core: leerlos devuelve FFh. El mapper es de 2 MB, así que se usan siete bits y el octavo se ignora, que es como se comporta un mapper real de 8 bits con menos memoria. Que sean de solo escritura es lo que obligó a dar a la DMA de la SD un modo lógico que traduce direcciones con estos registros dentro del core (capítulo 06).

## 4. Puertos que existen en un MSX y aquí no

- **Impresora** (90h-91h): no hay.
- **Joystick por PSG**: sí, pero solo desde USB; no hay conectores DE-9.
- **Puerto 4 del V9968** (9Ch): no decodificado, ver arriba.
- **Cinta**: el motor y la salida existen en el PPI, pero no hay conector; la cinta virtual que se preparó para el ESP32 se retiró.
