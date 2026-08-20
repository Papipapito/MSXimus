#!/usr/bin/env python3
# dbg_mouse_reader.py — lector COM11 para la CAZA DEL RATON (18/08).
#
# Cableado: el de siempre — PMOD1 pin E22 (dbg_pmod1[4]) al RX del CH340,
# GND comun. Es el mismo adaptador de toda la telemetria del MSXimus.
#
# Uso:  python tools\dbg_mouse_reader.py [COMx]     (por defecto COM11)
#
# La FPGA emite "D <w0> ... <w6>" cada 250 ms. Aqui solo interesa w6 (cnt_g),
# donde vive el estado completo del raton:
#   [31:30] typ USB2   [29:28] typ USB1   (0 nada, 1 teclado, 2 RATON, 3 gpad)
#   [27] conerr USB2   [26] conerr USB1
#   [25] raton visto (pegajoso)     [24] el MSX sondea el puerto 2
#   [23:21] fase de la maquina      [20] pin 8 del puerto 2 (strobe)
#   [19:12] informes de RATON       [11:8] informes de cualquier tipo
#   [7:0]  diag del ADPCM
#
# COMO LEERLO:
#   USB2 debe poner RATON y quedarse ahi. Si baila entre NADA/TECL/RATON, la
#   enumeracion no se estabiliza.
#   INF.RATON tiene que SUBIR al mover el raton. Si no sube, no llegan datos.
#   VISTO se engancha en cuanto llega el primer informe y ya no se suelta.
#   PIN8 y FASE solo se mueven con un programa de raton corriendo en el MSX;
#   desde BASIC es normal que esten quietos.
import sys, time

try:
    import serial
except ImportError:
    sys.exit("pip install pyserial")

TYP = {0: "NADA ", 1: "TECL ", 2: "RATON", 3: "GPAD "}

port = sys.argv[1] if len(sys.argv) > 1 else "COM11"
ser = serial.Serial(port, 115200, timeout=2)
print(f"escuchando {port} @115200 — caza del raton (Ctrl+C para salir)")
print()
print("hora      USB1  USB2  cerr  VISTO P2 PIN8 FASE  INF.RATON  d  INF.TODO  d")
print("-" * 78)

prev_m = prev_a = None
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

    t2   = (g >> 30) & 3
    t1   = (g >> 28) & 3
    ce2  = (g >> 27) & 1
    ce1  = (g >> 26) & 1
    seen = (g >> 25) & 1
    p2   = (g >> 24) & 1
    fase = (g >> 21) & 7
    pin8 = (g >> 20) & 1
    mcnt = (g >> 12) & 0xFF
    acnt = (g >> 8) & 0xF

    dm = "" if prev_m is None else "%+3d" % (((mcnt - prev_m) + 256) % 256)
    da = "" if prev_a is None else "%+3d" % (((acnt - prev_a) + 16) % 16)
    prev_m, prev_a = mcnt, acnt

    marca = ""
    if t2 == 2 and mcnt != 0:
        marca = "  <<< RATON VIVO"
    elif t2 == 2:
        marca = "  (enumerado, sin datos)"
    elif t2 != 0:
        marca = "  <<< USB2 mal clasificado"

    print("%s  %s %s  %s%s   %s   %d   %d    %d     %3d     %s   %2d    %s%s" % (
        time.strftime("%H:%M:%S"),
        TYP[t1], TYP[t2],
        "1" if ce1 else "0", "1" if ce2 else "0",
        "SI " if seen else "no ",
        p2, pin8, fase, mcnt, dm, acnt, da, marca))
