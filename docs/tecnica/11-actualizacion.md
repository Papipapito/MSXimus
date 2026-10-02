# 11. La actualización desde el MSX

Cómo graba el MSX su propia flash (V3.8, octubre de 2026). El manual de usuario está en [manual/11-actualizar.md](../manual/11-actualizar.md); aquí va lo que hay debajo.

Las piezas:

| Pieza | Dónde | Qué hace |
|---|---|---|
| Puente de la flash | `fpga/src/flash_bridge.v` + `flash_rw.v` | Deja leer, borrar y programar la flash SPI de la FPGA por E/S |
| Formato `.UPD` | `tools/mxupd.py` | Fichero con los segmentos a grabar y sus CRC |
| `MXUPDATE.COM` | `tools/mxupdate/` | El programa de MSX-DOS: fichero o internet |
| «Instalar actualización» | `bios-msxnano-msximus/src/actualizar.asm` | Lo mismo desde Ajustes, sin DOS, con el `MSXIMUS.UPD` de la SD |
| La web | `https://msx.barcelona/wp-content/ota/tang60k/` | Los `.UPD` y el `manifiesto.txt` |

## 1. El puente de la flash

Es un dispositivo de **E/S conmutada** más, como el de Panasonic y los demás de [02-puertos-es.md](02-puertos-es.md): se selecciona escribiendo su ID, **4Dh** ('M'), en el puerto 40h, y entonces 41h-4Fh son suyos. Con él seleccionado, `IN 40h` devuelve **B2h** (el ID invertido, como el resto).

| Puerto | Dirección | Qué |
|---|---|---|
| 41h | OUT | A[23:16] |
| 42h | OUT | A[15:8] (la dirección va en páginas de 256 bytes) |
| 43h | OUT | Orden: **1** borrar el sector de 4 KB de A[23:12]; **2** programar la página A[23:8] (después, 256 `OUT 44h`); **3** leer desde A[23:8]:00 (después, `IN 44h` byte a byte, seguidos); **0** acabar la lectura |
| 44h | OUT / IN | Dato a programar / dato leído (cada lectura pide el siguiente) |
| 41h | IN | Estado: bit 0 orden en curso o lectura sin dato todavía; bit 1 la programación espera un dato; bit 2 hay dato leído; bit 3 la flash la usa otro (el arranque o el cargador de ondas): esperar; bits 7-4 = **1010** (firma: hay puente) |
| 4Eh | OUT / IN | Información del menú para el OSD del BL616: bit 0 menú en inglés, bit 1 Nextor 3. Se guarda hasta apagar (el reset del MSX no la borra) |

Usa el módulo `flash` de `flash_rw.v`, el mismo que guarda los ajustes. Su escritura de siempre borra el sector y programa los bytes que le dan; para el puente se le añadió **programar sin borrar** (`write_noerase`) y **esperar a cada byte** (`write_din_ok`). Un borrado es su escritura de siempre con un solo byte FF (programar FF no cambia nada). Todo va en `clk_54m`, el reloj del módulo; las peticiones del bus se registran una vez, como las de la configuración.

La FPGA sigue funcionando con el bitstream que cargó al encender, así que grabar uno nuevo no la afecta hasta el siguiente encendido: si algo falla, se repite.

Banco: `tools/flash_tb` (el puente contra un modelo de la flash).

## 2. El formato `.UPD`

Little endian:

| Desplazamiento | Tamaño | Qué |
|---|---|---|
| 0 | 8 | `"MXUPD1"`, 1Ah, 0 |
| 8 | 16 | Placa: `console60k`, `console138k`, `msxnano` (con ceros) |
| 24 | 16 | Versión (`3.8.0b3`) |
| 40 | 16 | Variante: `nextor214`, `nextor3`, `nextor214-en`, `nextor3-en`, o `core` sin pack |
| 56 | 1 | Número de segmentos (1 a 4) |
| 57 | 7 | Ceros |
| 64 | 16·n | Por segmento: dirección en la flash, tamaño, CRC-32, desplazamiento en el fichero (u32 cada uno) |
| … | 4 | CRC-32 de todo lo anterior |

Los datos de cada segmento van en su desplazamiento, alineado a 256. El CRC-32 es el de siempre (zlib, polinomio EDB88320).

Direcciones por placa:

| Placa | IDCODE | Core | Pack | Ajustes | Ondas del OPL4 |
|---|---|---|---|---|---|
| 60K | 0001481Bh | 0x000000 | 0x400000 | 0x480000 | 0x500000 |
| 138K | 0001081Bh | 0x000000 | 0x800000 | 0x880000 | 0x900000 |
| MSXnano 2.1.1 | 0000081Bh | 0x000000 | 0x200000 | 0x280000 | — |

El bloque de ajustes **nunca** va en un `.UPD`. De los packs del MSXnano se quita la cola de 6 bytes de configuración. `MXUPDATE /R` borra el sector de los ajustes a propósito: sin la firma «AB» el core arranca con los de fábrica, los mismos que el rescate con S2.

`tools/mxupd.py`:

```
python tools/mxupd.py crear -o MSXIMUS.UPD --placa console60k --version 3.8.0b3 --variante nextor214 \
    --bitstream msximus.fs --pack pack_bios_msximus.bin [--onda yrw801.rom]
python tools/mxupd.py info MSXIMUS.UPD
python tools/mxupd.py publicar --dir <carpeta del servidor> --placa console60k --version 3.8.0b3 \
    --bitstream msximus.fs --packs <bios-msxnano-msximus>/packs/msximus [--onda yrw801.rom] [--notas "..."]
```

`publicar` deja en `<dir>/tang60k/` (`tang138k/`, `msxnano/`) los cuatro `.UPD` normales, los cuatro completos (con `--onda`) y el `manifiesto.txt`.

## 3. El manifiesto

Texto, final de línea LF:

```
MSXIMUS-UPD 1
placa=console60k
version=3.8.0b3
notas=Instalar actualizacion en Ajustes y mapper por firma ROM
imagen=nextor214 380b3_n214_es.upd 3114752
imagen=nextor3 380b3_n3_es.upd 3114752
imagen=nextor214-en 380b3_n214_en.upd 3114752
imagen=nextor3-en 380b3_n3_en.upd 3114752
completa=nextor214 380b3_n214_es_full.upd 5211904
...
```

Las notas son solo para el usuario (las enseña `MXUPDATE /N`), de 60 caracteres como mucho. `/R` usa las líneas `completa=`.

## 4. `MXUPDATE.COM`

MSXgl + la librería UNAPI de red, compilado en el WSL (`tools/mxupdate/build.sh`, entorno de `sdk-tools/msx-unapi-env`). El código tiene que quedar por debajo de 4000h, porque la página 1 es la del UNAPI; por eso `unapi_tcp_mxu.asm` es el `unapi_tcp.asm` de MSXgl sin UDP, IP en crudo, eco ni configuración (unos 500 bytes menos).

Orden de trabajo:

1. Que el core tenga el puente (ID 4Dh, firma 1010 en el estado) y que la placa del fichero sea la de la flash: el IDCODE del bitstream grabado.
2. La cabecera y el CRC-32 de cada segmento **del fichero**, antes de borrar nada.
3. Borrar y programar sector a sector (4 KB). Las páginas que son todo FF no se programan.
4. Releer la flash entera y comprobar los CRC otra vez.

El CRC-32 en ensamblador cuesta unos 135 estados por byte. Tiempos a 3,58 MHz: el pack 75 s, core y pack 447 s, la completa 749 s, más la SD.

### Por internet (`/N`)

- A `msx.barcelona`, puerto 443, **TLS validando el certificado**. Si el ESP no puede validarlo (firmware sin autoridades de certificación), el mismo `TCP_OPEN` sin el bit de verificar, y avisa una vez: `Aviso: certificado sin validar.`. **En claro, nunca**: una versión anterior caía a HTTP:80 sin decir nada.
- HTTP/1.0 sin User-Agent: el IONOS de msx.barcelona sirve los estáticos con `Content-Length` y sin *chunked*.
- `Sin actualizaciones para esta placa (HTTP 404)` se distingue de `Sin conexion con el servidor`.
- `/S:ip[:puerto]` va a un servidor propio, en claro, con la misma estructura de carpetas: el de desarrollo es `fpga/zynq/ota/ota_servidor.py` del repo MSXimus_zynq.

El ESP32-C6 de la v3.8 lleva 16 autoridades de certificación de Mozilla de serie (`CaRaices.h` del repo ESP32-for-FPGA), entre ellas la Sectigo R46 de msx.barcelona, válida hasta 2046. El mbedTLS del core de Arduino 3.3.10 no mira las fechas, así que no depende del reloj.

## 5. «Instalar actualización» (Ajustes)

`actualizar.asm`, en la página 1 del menú (solo MSXimus). Hace lo mismo que `MXUPDATE.COM` sin MSX-DOS: busca `MSXIMUS.UPD` en la raíz de la SD con las rutinas del propio menú (`sd_read_sector`, `fatnext`, `clus2lba`), comprueba la cabecera y los CRC (`crc_mktab`, `crc_block`), y graba y relee igual. Usa como RAM la zona de la lista de ficheros (`ENT_ARRAY`); al salir pone `SD_READY = 0` para que el navegador la recargue. Sin puente, o en la MSXimus Z, lo dice y no hace nada.

Banco: `bios-msxnano-msximus/tools/actualizar_tb` (Z80 emulado con la ROM y la página 2 reales, una SD FAT16 con el fichero troceado en la FAT, el puente con 16 MB de flash y fallos inyectados): 11 casos más el inglés.

## 6. Publicar

La web es `https://msx.barcelona/wp-content/ota/<placa>/`, con `tang60k`, `tang138k` y `msxnano`; el SFTP de IONOS solo llega a `wp-content`. Se sube con `fpga/zynq/ota/ota_subir.py` del repo MSXimus_zynq, que:

- comprueba en local los CRC de los `.UPD` y el manifiesto;
- sube cada fichero como `.subiendo` y lo renombra al acabar, y el manifiesto el último;
- lo vuelve a bajar por https, como haría una placa, para comprobarlo;
- deja la versión anterior en la web para volver atrás (`manifiesto.anterior.txt`).

## 7. Bancos

| Banco | Qué prueba | Resultado |
|---|---|---|
| `tools/flash_tb` | El puente contra un modelo de la flash | — |
| `tools/mxupdate/banco` (`run.sh`) | `MXUPDATE.COM` de verdad en un Z80 emulado con MSX-DOS, el puente, un ESP32 UNAPI y una web de imitación: flash del 60K, 138K y MSXnano, fichero dañado, otra placa, no, sin puente, `/C`, `/R`, y por red validado, sin validar, 404, sin TLS, descarga cortada y completa | 18/18 |
| `bios-msxnano-msximus/tools/actualizar_tb` | «Instalar actualización» | 11/11 + inglés |
| `bios-msxnano-msximus/tools/firma_tb` | La firma de tipo de ROM del menú ([manual/05](../manual/05-roms-mappers.md)) | 15/15 |
