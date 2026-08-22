#!/usr/bin/env python3
# dbg_spi_reader.py -- bring-up del enlace SPI con el ESP32-S3.
#
# Cableado del lector: el de siempre -- PMOD1 pin E22 (dbg_pmod1[4]) al RX del
# CH340, GND comun. Es el CH340 de la FPGA (COM11), no el del S3.
#
#   python tools\dbg_spi_reader.py [COMx]      (por defecto COM11)
#
# DOS TESTIGOS EN DOS PUNTOS DISTINTOS de la cadena. Esa es toda la gracia:
# permiten saber DONDE se rompe, no solo que no va.
#
#   HID   bytes HID que han llegado del S3 (sonda dbg_hid_strobe del companion).
#   TECLA veces que ha CAMBIADO el vector keyboard[127:0] que ve el MSX.
#
# COMO SE LEE:
#
#   HID sube, TECLA sube      -> el enlace ENTERO funciona. Si ademas sale la
#                                letra en el MSX, esta cerrado.
#   HID sube, TECLA NO sube   -> los bytes llegan pero no se interpretan. Mirar
#                                el comando (1 = teclado) y el bit 7, que va AL
#                                REVES: puesto = SOLTAR.
#   HID NO sube               -> la FPGA no recibe NADA. Es cable, o modo SPI, o
#                                el CS#. Repasar: modo 1 (CPOL=0, CPHA=1), CS
#                                bajo durante TODA la trama, y que el primer
#                                byte sea el destino (1 = HID).
#   Ni uno ni otro se mueven nunca -> antes de tocar el cable, comprobar que la
#                                telemetria en si esta viva: los otros campos de
#                                la linea "D ..." tienen que ir cambiando.
import sys, time

try:
    import serial
except ImportError:
    sys.exit("pip install pyserial")

port = sys.argv[1] if len(sys.argv) > 1 else "COM11"
ser = serial.Serial(port, 115200, timeout=2)
print("escuchando %s @115200 -- bring-up del SPI con el S3" % port)
print("Mueve una tecla en el teclado USB del S3 y mira los deltas.\n")
print("hora        HID(bytes)    d      TECLA(cambios)   d    veredicto")
print("-" * 74)

prev_h = prev_k = None
vivo = False
while True:
    try:
        ln = ser.readline().decode("ascii", "replace").strip()
    except KeyboardInterrupt:
        break
    if not ln.startswith("D "):
        continue
    p = ln.split()
    if len(p) < 8:
        continue
    try:
        g = int(p[7], 16)
    except ValueError:
        continue
    hid = (g >> 16) & 0xFFFF
    kbd = g & 0xFFFF

    dh = 0 if prev_h is None else ((hid - prev_h) & 0xFFFF)
    dk = 0 if prev_k is None else ((kbd - prev_k) & 0xFFFF)
    prev_h, prev_k = hid, kbd
    if dh or dk:
        vivo = True

    if dh and dk:
        v = "<<< ENLACE COMPLETO: llega y se interpreta"
    elif dh:
        v = "<<< llegan bytes pero NO cambian teclas (comando? bit7?)"
    elif dk:
        v = "<<< raro: cambia el teclado sin bytes nuevos"
    elif vivo:
        v = ""
    else:
        v = "(sin trafico todavia)"
    print("%s   %10d %+5d      %10d %+4d   %s" % (
        time.strftime("%H:%M:%S"), hid, dh, kbd, dk, v))
