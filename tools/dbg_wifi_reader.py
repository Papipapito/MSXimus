#!/usr/bin/env python3
# dbg_wifi_reader.py -- lector COM11 de la caza de las descargas corruptas.
#
# Cableado: el de siempre -- PMOD1 pin E22 (dbg_pmod1[4]) al RX del CH340,
# GND comun.
#
# Uso:  python tools\dbg_wifi_reader.py [COMx]      (por defecto COM11)
#
# QUE MIRA AHORA (V3.1, 21/08). La palabra 7 (cnt_g) lleva dos contadores:
#
#   OK        escrituras de sector TERMINADAS.  <-- TESTIGO DE VIDA
#             Tiene que subir ~1 por sector mientras baja el fichero. Si no
#             sube, la medida no vale: no estamos midiendo lo que creemos.
#             Esto es justo lo que falto en la ronda anterior, donde los dos
#             contadores dieron 0 y no habia forma de distinguir "cero
#             fallos" de "instrumento muerto".
#
#   RECHAZ.   de esas escrituras, las que la tarjeta RECHAZO: el token de
#             respuesta del bloque llego distinto de 010 (aceptado) y
#             sd_reader levanto crc_error. Hasta hoy nadie lo miraba: el
#             sd_wait_idle del menu hace "and #80" y solo ve el bit de busy,
#             asi que la escritura se daba por buena y el sector se quedaba
#             con lo que ya hubiera en la tarjeta.
#
# Este bitstream ADEMAS reintenta el bloque rechazado hasta 4 veces, asi que
# lo esperable es ver RECHAZ. subir unas pocas veces Y el fichero salir bien.
#
# COMO LEER EL RESULTADO (verifica el fichero con verificar_descarga.py):
#   OK sube, RECHAZ. 0, CRC cuadra    -> descarga limpia; repetir a por una mala
#   OK sube, RECHAZ. sube, CRC cuadra -> DIAGNOSTICO CONFIRMADO Y CURADO
#   OK sube, RECHAZ. sube, CRC MAL    -> mecanismo bueno, faltan reintentos
#   OK sube, RECHAZ. 0, CRC MAL       -> el diagnostico es INCORRECTO
#   OK no sube                        -> no se esta midiendo; avisar
import sys, time

try:
    import serial
except ImportError:
    sys.exit("pip install pyserial")

port = sys.argv[1] if len(sys.argv) > 1 else "COM11"
ser = serial.Serial(port, 115200, timeout=2)
print("escuchando %s @115200 -- escrituras a la SD y bloques rechazados" % port)
print("Lanza ahora una descarga del File-Hunter.\n")
print("hora        OK(escrituras)   d      RECHAZADAS   d     veredicto")
print("-" * 72)

prev_w = prev_r = None
vivo = False
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
    wr  = (g >> 16) & 0xFFFF     # escrituras terminadas
    rej = g & 0xFFFF             # de ellas, rechazadas

    dw = 0 if prev_w is None else ((wr  - prev_w) & 0xFFFF)
    dr = 0 if prev_r is None else ((rej - prev_r) & 0xFFFF)
    prev_w, prev_r = wr, rej
    if dw: vivo = True

    if dr:
        v = "<<< LA TARJETA RECHAZO %d BLOQUE(S) -- reintentados" % dr
    elif dw:
        v = "escribiendo"
    elif vivo:
        v = ""
    else:
        v = "(sin actividad de escritura todavia)"
    print("%s   %10d %+5d   %10d %+4d    %s" % (
        time.strftime("%H:%M:%S"), wr, dw, rej, dr, v))
