# menu/ — el menú de arranque del MSXimus

Traído aquí el 21/08/2026, como pedía `docs/ROADMAP.md:39` ("el fuente vive aún
en el árbol del nano con el flag `MSXIMUS`. Traerlo al repo MSXimus cuando toque
tocarlo"). Origen: `MSXnano`, rama `pico-companion`, commit `c4283a8` (04/08).

**Es el MISMO fichero que el del MSXnano**, con `MSXIMUS=1` en la línea 6 de
`src/menu_main.asm`. Esta copia ya lo trae puesto; la del nano lo tiene a 0.
Cualquier arreglo que valga para las dos máquinas hay que portarlo a mano al
árbol del nano hasta que se unifique de verdad.

## Compilar

```bash
make rom          # -> fm_logo_menu.bin (16 KB, variante MSXimus)
```

`bin/` trae los ejecutables de Windows (asmsx, zx0, pletter). Funciona tal cual
desde Git Bash. La build es DETERMINISTA: dos compilaciones del mismo fuente dan
binarios idénticos (verificado).

## Margen del banco de código

El guard `ds #A000-$` (línea ~4905) vigila que el código no invada la sección de
datos, que empieza en `#A010`. Si se desborda, asmsx muere con *memory overflow*
— es una red de seguridad real, no un adorno. Estado al 21/08 con el arreglo de
la escritura SD ya dentro: **el código acaba en #9FC9, quedan 55 bytes**.

## ⚠️ El pack NO se regenera desde aquí (todavía)

`pack_bios_v2.1b.bin` lleva el menú en el offset **0x6C000** y es idéntico en
todas las entregas desde el 04/08. Ese menú **no lo reproduce este fuente**:
difieren ya en el arranque de `menu_main` (una variable en RAM desplazada 180
bytes), y el `fm_logo_menu_60k.bin` que queda en el árbol del nano es de julio,
anterior a los commits `_182` del 04/08.

O sea que la genealogía del menú que corre en placa está sin cerrar. Antes de
meter un menú nuevo en el pack hay que resolver eso, o se cuela un delta que
nadie ha validado. Mientras tanto, el arreglo de la escritura SD va por la FPGA
(ver `fpga/top.v`, reintento del bloque rechazado), que cubre el problema entero
sin tocar el pack.
