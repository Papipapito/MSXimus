# 05. ROMs y mappers

Cómo lanza el MSXimus un cartucho desde un fichero: qué mappers emula, cómo elige uno, qué pasa con la SRAM de los cartuchos que guardan partida y cómo funciona el Game Master 2. Las teclas concretas de la pantalla de lanzar están en el [capítulo 04](04-menu.md).

## 1. La megaram: el cartucho emulado

Al lanzar una ROM, el menú la copia de la tarjeta a una memoria de **8 MB** dentro de la máquina (4 MB hasta la v3.7), la megaram, y le dice al core con qué mapper tiene que comportarse. A partir de ahí la máquina se reinicia y encuentra la ROM en el **slot 2**, como si hubiera un cartucho pinchado. Un juego no puede distinguirlo de un cartucho real.

La carga va por DMA: unos 640 KB por segundo, así que un megarom de 512 KB tarda menos de un segundo, uno de 4 MB unos seis y uno de 8 MB unos trece. La barra de la pantalla de lanzar la muestra.

## 2. Los mappers

| Mapper | ROMs típicas | Tamaño máximo |
|---|---|---|
| **Plain** | Cartuchos de 8, 16 y 32 KB sin mapper | 32 KB |
| **Konami** | Konami sin SCC: Nemesis, Penguin Adventure, Metal Gear 1 | 256 KB, ninguno real es mayor |
| **Konami-SCC** | Konami con SCC: Salamander, Metal Gear 2, Space Manbow, y las conversiones grandes | 2 MB |
| **ASCII8** | La mayoría de los megaroms japoneses de 8 KB por banco: Aleste, Xak, Ys | 2 MB |
| **ASCII16** | Megaroms de 16 KB por banco: R-Type, Fire Hawk, Ys II | 4 MB |
| **NEO-8** | El mapper NEO de 8 KB por banco, para homebrew reciente | 4 MB |
| **NEO-16** | El mapper NEO de 16 KB por banco | 4 MB |
| **Plain 0000h** | Imágenes lineales desde la dirección 0000h, con su propia página 0: las demos V9990 de Edd Biddulph (Wireframes, Flying Logos, Wolfenstein) | 48 KB |
| **ASCII16-X** | La ampliación de ASCII16 de [grauw.nl](https://www.grauw.nl/projects/ascii-x/ascii16-x/) con bancos de 12 bits: la V9968 TECH DEMO 0.7.5 de renatus | 8 MB |

Los cartuchos ASCII8 y ASCII16 con **SRAM** (Koei, Hydlide 3, Royal Blood) están cubiertos: la SRAM se emula y se guarda, apartado 4.

Lo que no hay: mappers exóticos como R-Type original con su disposición propia, Cross Blaim, Harry Fox, o los cartuchos con hardware extra como el FM-PAC o el Sunrise. Y las ROMs que hacen de cartucho de disco.

## 3. Cómo se decide el mapper

En este orden:

1. **Tamaño.** Hasta 32 KB, Plain.
2. **Etiqueta en el nombre.** `[ASCII16]`, `[ASCII8]`, `[SCC]`, `[KONAMI]`, `NEO8`, `NEO16`. Si la hay, manda, sin mirar el contenido. Las pone File-Hunter al descargar, y uno mismo al renombrar. Es la forma de fijar un mapper de una vez para siempre.
3. **Análisis del contenido.** Sin etiqueta, el core cuenta, mientras carga, las instrucciones con que cada familia de mapper cambia de banco, y gana la familia con más. Es el mismo criterio que usa openMSX y acierta con casi todo. Una ROM detectada como Konami de 320 KB o más se promociona a Konami-SCC, porque ningún Konami sin SCC pasa de 256 KB.
4. **La firma del autor, ya cargada** (desde la v3.8). Muchas ROM nuevas llevan su mapper escrito dentro: ocho letras justo después de la cabecera, en el offset 10h del fichero (o en 4010h, si la cabecera va en el segundo segmento), según la [convención de MSXgl](https://aoineko.org/msxgl/index.php?title=ROM_type_signature). Si el menú encuentra `ROM_ASC8`, `ROM_AS16`, `ROM_KON4`, `ROM_KON5`, `ROM_NEO8`, `ROM_NE16` o `ASCII16X`, ese es el mapper, por encima de la etiqueta y del análisis: lo ha puesto quien hizo la ROM. Así se lanzan solas, sin `[ASCII16]` en el nombre, las ROM de geo3d y lo hecho con MSXgl. Si la firma cambia el mapper, la fila se repinta y la SRAM queda apagada (en ASCII8 y ASCII16, la tecla **S** la enciende).
5. **Casos especiales, ya cargada.** Más de 4 MB sin firma: ASCII16-X. De 16 a 48 KB, sin `AB` al principio y con `AB` en +4000h: Plain 0000h.
6. **A mano.** Si el análisis no ve nada, el mapper sale como desconocido y se elige con **M**, que va ciclando los nueve. Una vez encontrado, lo cómodo es poner la etiqueta en el nombre.

Un mapper equivocado no rompe nada: el juego no arranca o se cuelga, y se vuelve al menú con reset.

Hay ROMs que engañan al análisis: las que cambian de banco con instrucciones distintas de la habitual, como las demos compiladas con z88dk, o las que llevan dentro código de dos mappers. Para esas, la etiqueta.

## 4. La SRAM de cartucho y el guardado

Los cartuchos ASCII8 y ASCII16 con SRAM guardaban la partida en 8 o 32 KB de memoria con pila. En el MSXimus:

- La SRAM se emula en la propia megaram, en sus últimos 32 KB.
- Se activa por defecto si el nombre lleva `KOEI` o `SRAM`, y se puede encender o apagar para cada lanzamiento con la tecla **S**. Solo existe en ASCII8 y ASCII16; en Konami no aparece.
- Al lanzar, el menú busca en `FHUNT` un fichero con el mismo nombre que la ROM y extensión `.SRM`. Si existe, lo carga como contenido de la SRAM; si no, crea uno nuevo, vacío.
- Al **siguiente arranque del navegador**, el menú comprueba si la SRAM cambió y, si cambió, reescribe el `.SRM`.

La consecuencia práctica: **para conservar la partida hay que hacer RESET, no apagar.** La memoria aguanta un reset y el menú guarda al arrancar; un apagado pierde lo que no se haya guardado aún. La línea de estado lo dice al arrancar: *"SRAM cambiada: guardando FHUNT/..."* y *"OK"*.

Sin carpeta `FHUNT`, la SRAM funciona pero no se guarda: *"SRAM: sin FHUNT, no se guarda"*. Las ROMs de 4 MB o más no dejan sitio; con ellas tampoco.

El guardado solo escribe si el `.SRM` sigue en la misma tarjeta y en el mismo sitio. Cambiar de tarjeta entre el juego y el arranque siguiente no corrompe nada: el menú lo detecta y descarta el guardado.

## 5. El Game Master 2

El **Game Master 2** de Konami (RC-755) era un cartucho que, pinchado junto a un juego Konami, le daba guardado de partida, trucos y un mapa. Es la forma de guardar en Metal Gear 2, SD Snatcher, Snatcher, Salamander y los demás Konami con SCC que lo reconocen.

El MSXimus lo emula en el **slot 1**. Hace falta:

- `FHUNT\GM2.ROM`: la ROM del cartucho, 128 KB. La pone el usuario, por lo mismo que las ROMs de los juegos.
- `FHUNT\GM2.SRM`: sus 8 KB de SRAM. Los crea el menú la primera vez.

Y activarlo, de dos maneras:

- **Para todos los lanzamientos**: en Ajustes, **Slot 1 = Game Master 2**.
- **Para uno**: en la pantalla de lanzar, tecla **G**. Solo aparece con mappers Konami y Konami-SCC, que son los que lo usan. Por defecto toma el valor de Ajustes, y es útil en las dos direcciones: para quitarlo en un juego que no es Konami pero usa el mapper Konami-SCC, como Space Manbow 2, que con el Game Master 2 activo no arranca; o para ponerlo una vez sin cambiar el ajuste.

El guardado funciona igual que el de la SRAM: se escribe en `GM2.SRM` al siguiente arranque del navegador, tras un RESET. El propio Game Master 2 tiene su utilidad para formatear la SRAM la primera vez.

Al arrancar el juego con el Game Master 2 armado, sale primero la pantalla del cartucho, como en un MSX real: desde ahí se arranca el juego, o se entra en su menú de trucos y guardado.

Si falta algo, el juego arranca igual, sin Game Master 2, y la línea de estado dice por qué: *"GM2: falta FHUNT/GM2.ROM"*, *"GM2: GM2.ROM no mide 128 KB"*, *"GM2: sin FHUNT"*. Las ROMs de 4 MB tampoco dejan sitio para él. Y con la opción **Slot 1 = 2o SCC** el slot está ocupado por el segundo SCC y el Game Master 2 no se ofrece.

Una advertencia con Metal Gear 2: hay una versión española de la ROM, la que circula con el número [9692], cuya rutina de arranque comprueba si hay MSX-DOS y no es compatible con el arranque a través del Game Master 2: pantalla negra. No es del core. Otras versiones, como la [3371] española o la [1489] japonesa, arrancan y guardan sin problema.

## 6. ROMs que no lanzan

- **"INIT pag.0/BASIC: no lanzable"**: una ROM plana cuyo punto de entrada cae fuera de la ventana del cartucho. Suelen ser programas BASIC empaquetados como ROM. Lanzarla reiniciaría la máquina, así que el menú lo impide.
- Una ROM de disco (las que emulan una unidad) no tiene sentido aquí: el disco ya lo pone Nextor.
- Una ROM mayor de 8 MB no cabe.
