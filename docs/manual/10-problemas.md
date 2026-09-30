# 10. Problemas frecuentes

Por síntoma, qué mirar. Casi todo lo que hay aquí ha pasado de verdad durante el desarrollo, y la causa fue casi siempre la que se dice en primer lugar.

## Al encender

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| Pantalla azul y nada más | El pack no está en 0x400000, o falta apagar y encender tras grabar | Regrabar el pack en la dirección exacta y **apagar y encender**, no reset |
| Pantalla negra, sin señal HDMI | La DDR3 no calibró tras un reset en caliente | Apagar y encender |
| Pantalla negra (o negra y luego el menú sin logo) al encender **desde un cargador**, pero arranca bien desde el USB del PC; el LED de la SD (U12) parpadea solo y va más rápido con F11 | La DDR3 de la VRAM no ha calibrado: cada intento de calibración sale bien con una probabilidad que depende del core (del dado, capítulo 07 de la técnica) y de la alimentación. El MSX corre por debajo, sin vídeo | Esperar: desde la v3.7b el core reintenta con ventanas cada vez más largas y, si sigue sin calibrar, con el PLL reiniciado; el arranque espera hasta 10 s. Probar otro cargador o una batería USB (algunos cargadores USB-C hacen caer VBUS un instante al negociar). Si un core concreto falla siempre, es su dado: otro `.fs`. Desde BASIC `PRINT INP(&H2C) AND 127` dice los intentos que fallaron |
| Arranca pero se reinicia en bucle | Una ROM con el punto de entrada fuera del cartucho, o un core antiguo con un pack nuevo | Reset; si es al lanzar una ROM, el menú ya lo veta desde la 2.x |
| Arranca directo en DOS y no sale el menú | Menú al arrancar en Off | **S** durante el logo, marcar *Menú al arrancar*, Save & Restart |
| Los ajustes vuelven a los de fábrica | Se grabó un pack antiguo con cola de configuración, o se encendió con S2 pulsado | Volver a Ajustes y guardar. Los packs actuales no pisan la configuración |
| Sale el menú del Game Master 2 en vez del juego | El juego no es Konami pero usa el mapper Konami-SCC (Space Manbow 2) con GM2 activo | Tecla **G** en la pantalla de lanzar para ese juego |

## La tarjeta

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| "No se detecta la tarjeta SD" | Tarjeta mal insertada, formato no reconocido, o tarjeta que no inicializa | Comprobar el formato; probar otra tarjeta. Tecla T, la cabecera dice qué tipo detecta |
| Descargas o guardados que fallan de forma aleatoria | Tarjeta sin marca que pierde escrituras | Cambiar a una de marca, clase 10 |
| "FH: la SD es FAT32" o los guardados no se escriben | La partición no es FAT16 | Reparticionar con una FAT16 de hasta 2 GB para el menú |
| "DSK fragmentado: recopialo" | El `.dsk` no está en clusters consecutivos | Copiarlo de nuevo desde el PC |
| "Falta NEXTOR.EMU en la raiz" | El menú no pudo crear el fichero oculto | Tarjeta llena o protegida; con FAT32 no hace falta |
| "Falta FHUNT (MKDIR en DOS)" | No existe la carpeta | Crearla desde MSX-DOS |
| Nextor da "Disk error writing drive A" con DRVTEST | Se ha redirigido la salida a la SD | Redirigir a un disco RAM |

## ROMs

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| Mapper "? (desconocido)" | La ROM cambia de banco de una forma que el análisis no ve | Tecla **M** hasta acertar; luego poner la etiqueta en el nombre |
| El juego arranca y se cuelga a los pocos segundos | Mapper equivocado | Probar los otros con M |
| "INIT pag.0/BASIC: no lanzable" | ROM de un programa BASIC | No es lanzable como cartucho |
| La partida no se guardó | Se apagó en vez de hacer reset, o no hay carpeta FHUNT | Reset siempre; crear FHUNT |
| Metal Gear 2 en pantalla negra con el Game Master 2 | La versión [9692] de la ROM, con chequeo de MSX-DOS en el arranque | Usar otra versión, por ejemplo la [3371] o la [1489] |
| "Analizando ROM..." tarda mucho | Core anterior a la 3.6, sin análisis por hardware | Actualizar el core; con el 3.6c es instantáneo |

## Vídeo y audio

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| El televisor no muestra imagen | Receptor que no acepta 720p60 con audio embebido | Probar otro cable o entrada; es una señal estándar |
| Un juego a 50 Hz se ve con la geometría rara | El modo 50 Hz es el menos probado | Anotar cuál y reportarlo |
| Sin MoonSound, o instrumentos que faltan | `yrw801.bin` no grabado en 0x500000 | Grabarlo |
| Todo suena bajo o distorsionado | Ganancia maestra tocada | Volver a 5 ([capítulo 08](08-audio.md)) |
| VGMPlay se cuelga con OPL3 | Nextor 3 beta | Usar el pack con Nextor 2.1.4 |
| El SCC no suena en un juego | El juego busca el SCC en otro slot | Ajustes, Slot 1 = 2o SCC |

## Teclado, mando y ratón

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| El teclado no responde | Teclado con hub interno o inalámbrico con receptor compuesto | Probar otro teclado; conectar directo, sin hub |
| El ratón no se ve | Receptor inalámbrico | Solo ratones con cable |
| El mando no hace nada | Es XInput (Xbox o un receptor 2,4 GHz que se presenta como Xbox 360): el host de los USB-A es HID puro | Un mando USB genérico HID; muchos receptores tienen un modo D (DirectInput) además del X |
| Con el mando conectado, los juegos ven la izquierda pulsada y en el navegador la lista vuelve 18 entradas atrás al llegar a la entrada 18 («no hace scroll») | Un core anterior a la 3.7.5: un paquete USB vacío del mando se leía como «eje X = 00». Se comprueba con `PRINT STICK(1)`: con el mando quieto da 7 | Core 3.7.5. Con uno anterior, desenchufar y volver a enchufar el mando suelta la izquierda hasta la siguiente vez; el pack de la 3.7.5 ya no repite izquierda/derecha en el navegador |
| El mando mueve mal o no enumera (un mando genérico con cruceta y sticks) | Un core anterior a la 3.7.2/3.7.3: el host solo entendía los mandos «SNES USB» y no esperaba a los que contestan muy deprisa | Core 3.7.5. Los puertos 20h-27h enseñan el último informe del mando: `FOR I=0 TO 7:PRINT HEX$(INP(&H20+I));" ";:NEXT` |
| F12 no hace nada | El BL616 no tiene firmware | Grabarlo ([capítulo 02](02-instalacion.md)); el turbo es F11 |
| La ñ no sale con un teclado español | La distribución del MSX no la tiene en esa tecla | Pendiente |

## Red

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| Con W salen caracteres sin sentido y no aparece el menú | El módulo no está o no responde | Comprobar alimentación y cables; la pantalla del módulo tiene que encender |
| La pantalla del módulo dice "Sin WiFi" | Red no configurada | Tecla W, Scan/Join |
| "FH: sin UNAPI" | El MSX no ve el driver: RX del FPGA mal cableado | TX y RX cruzados: IO16 al pin 16, IO17 al pin 14 |
| Conectado pero nada descarga | Sin internet, o File-Hunter caído | Probar más tarde |
| El módulo se porta raro | Alimentado a la vez por J10 y por USB-C | Una sola fuente |

## Herramientas para diagnosticar

- **Tecla T en el arranque o en el navegador**: el menú de pruebas. Dice la versión del core, el tipo de tarjeta, los bytes de configuración, y mide la velocidad de la tarjeta por sus cuatro caminos, el sonido del PSG y del OPLL, el Game Master 2 y el VDP.
- **Tecla H**: la ayuda del navegador.
- **Ajustes**: muestra la versión del core que hay grabada.
- **F12**: el panel del BL616, con el estado de la CPU, la tarjeta, el ventilador, el teclado y la red.
- **La pantalla del ESP32**: red, tráfico, turbo, hora.
- **La tira de LEDs**, si se ha montado la tira de ocho WS2812 en el pin previsto: encendido, CAPS, kana, actividad de disco, turbo, red, mando y teclado.
- **Puertos de diagnóstico** desde BASIC: `INP(&H2F)` da la versión del core, `INP(&H2D)` el estado del USB, `INP(&H2E)` el del ratón ([capítulo 02 de la referencia técnica](../tecnica/02-puertos-es.md)).

## Cómo reportar un problema

Con la versión del core (Ajustes o `INP(&H2F)`), el pack (2.1.4 o Nextor 3), el nombre exacto de la ROM o disco con su tamaño, y lo que dice la línea de estado del menú o el mensaje de DOS. Una foto de la pantalla vale más que una descripción.
