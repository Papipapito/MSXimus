#!/usr/bin/env python3
# dbg_wifi_reader.py — CAZA DE LAS DESCARGAS CORRUPTAS (V3.1, 21/08).
#
# Cableado: el de siempre — PMOD1 pin E22 (dbg_pmod1[4]) al RX del CH340,
# GND comun.
#
# Uso:  python tools\dbg_wifi_reader.py [COMx]      (por defecto COM11)
#
# Mira la palabra 7 (cnt_g) de la telemetria, que ahora lleva los DOS UNICOS
# mecanismos por los que se puede perder informacion en el camino
# ESP -> UART -> FIFO -> Z80 -> SD. Cada uno apunta a un culpable distinto,
# y por eso hay que medirlos por separado ANTES de decidir nada:
#
#   OVERFLOW  el ESP escribio con la FIFO (2080 bytes) LLENA -> byte TIRADO.
#             Hasta ahora era INVISIBLE: fifo.vhd lo descartaba sin dejar
#             rastro. Si esto sube, es falta de CONTROL DE FLUJO en el
#             enlace, y migrar al ESP32-S3 SE LO LLEVA PUESTO.
#
#   UNDERRUN  el Z80 leyo y no habia datos. Si esto sube, y el fichero sale
#             con bloques a CERO pero ALINEADO -- que es la firma medida
#             (Fleet: 21 sectores de 512 perdidos, uno cada 25; Aleste: uno
#             cada 49) -- entonces el driver UNAPI esta entregando ceros sin
#             avisar y el bug es del LADO MSX, no del ESP.
#
# SANO = los dos a 0 durante una descarga entera.
# Si NO sube ninguno de los dos, ambos mecanismos quedan descartados de golpe
# y hay que mirar mas arriba (el propio ESP, o la escritura a la SD).
#
# COMO USARLO: arranca esto, lanza una descarga del File-Hunter desde el menu
# del MSX, y mira los DELTAS mientras baja.
import sys, time

try:
    import serial
except ImportError:
    sys.exit("pip install pyserial")

port = sys.argv[1] if len(sys.argv) > 1 else "COM11"
ser = serial.Serial(port, 115200, timeout=2)
print(f"escuchando {port} @115200 — caza de las descargas corruptas")
print("Lanza ahora una descarga del File-Hunter y mira los deltas.\n")
print("hora      OVERFLOW  d     UNDERRUN  d     veredicto")
print("-" * 66)

prev_o = prev_u = None
while True:
    try:
        ln = ser.readline().decode("ascii", "replace").strip()
    except KeyboardInterrupt:
        break
    if not ln.startswith("D "):
        continue
    try:
        w = [int(x, 16) for x in ln.split()[1:8]]
    except ValueError:
        continue
    if len(w) < 7:
        continue
    g = w[6]
    ovf = (g >> 16) & 0xFFFF
    unr = g & 0xFFFF

    do = 0 if prev_o is None else ((ovf - prev_o) & 0xFFFF)
    du = 0 if prev_u is None else ((unr - prev_u) & 0xFFFF)
    prev_o, prev_u = ovf, unr

    if do and du:
        v = "<<< LOS DOS (mirar cual domina)"
    elif do:
        v = "<<< ENLACE: falta control de flujo"
    elif du:
        v = "<<< LADO MSX: el driver entrega ceros"
    else:
        v = ""
    print("%s  %8d %+4d     %8d %+4d     %s" % (
        time.strftime("%H:%M:%S"), ovf, do, unr, du, v))
