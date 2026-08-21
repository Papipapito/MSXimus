#!/usr/bin/env python3
# dbg_lba_reader.py -- traza de LBA: UNA LINEA POR ESCRITURA de sector.
#
# Cableado: el de siempre -- PMOD1 pin E22 (dbg_pmod1[4]) al RX del CH340, GND.
#
#   python tools\dbg_lba_reader.py [COMx] [-o traza.txt]
#
# POR QUE ESTO. Los bytes de un sector corrupto (F1 Spirit, 29-30) resultaron
# ser una imagen SCREEN 5 que YA estaba en la tarjeta antes de formatearla: ese
# sector NUNCA SE ESCRIBIO. Con el sistema de ficheros intacto, sin
# desplazamiento en el fichero, todas las escrituras completandose y ninguna
# rechazada, lo unico que queda es que algunas vayan a un LBA equivocado.
# Eso no sale deduciendo: hay que ver la lista de LBA en orden.
#
# Cada linea trae:  [29] rechazada  [28] carga de 512 ceros  [27:0] LBA
#
# Lo que se marca al vuelo, que es lo que hay que cazar:
#   REPE   el mismo LBA escrito dos veces -> algo se sobreescribe
#   SALTO  el LBA no es el anterior+1 ni un salto de cluster razonable
#   CERO   se escribieron 512 ceros (normal en ROMs con relleno, sospechoso si
#          coincide con un sector que sale mal)
#   RECHA  la tarjeta la rechazo (hasta hoy siempre 0)
#
# Guarda SIEMPRE la traza completa a fichero: el analisis de verdad se hace
# despues, cruzandola con el fichero descargado.
import sys, time

try:
    import serial
except ImportError:
    sys.exit("pip install pyserial")

args = sys.argv[1:]
salida = "traza_lba.txt"
if "-o" in args:
    i = args.index("-o"); salida = args[i+1]; del args[i:i+2]
port = args[0] if args else "COM11"

ser = serial.Serial(port, 115200, timeout=2)
f = open(salida, "w")
print("escuchando %s @115200 -- una linea por escritura de sector" % port)
print("guardando la traza en %s   (Ctrl+C para parar)" % salida)
print()
print("   #      LBA        marcas")
print("-" * 52)

prev = None
prev_raw = None
hay_seq = False
n = 0
repes = saltos = ceros = recha = 0
vistos = {}
try:
    while True:
        ln = ser.readline().decode("ascii", "replace").strip()
        if not ln.startswith("D "):
            continue
        p = ln.split()
        if len(p) < 8:
            continue
        try:
            g = int(p[7], 16)
        except ValueError:
            continue
        # El LATIDO del temporizador repite la linea anterior. Se distingue por
        # el contador de 2 bits [31:30], que rueda con cada escritura. Pero ese
        # contador solo existe desde la v31e: en la v31d esos bits son SIEMPRE
        # 0, y descartar "lineas repetidas" alli se come ESCRITURAS DE VERDAD
        # (las 7 seguidas al mismo sector de directorio de cada fichero).
        # Por eso el descarte se activa solo si se ve el contador moverse.
        if ((g >> 30) & 3) != ((prev_raw >> 30) & 3 if prev_raw is not None else 0):
            hay_seq = True
        if hay_seq and g == prev_raw:
            continue             # latido, no escritura
        prev_raw = g
        lba = g & 0x0FFFFFFF
        cero = (g >> 28) & 1
        rej  = (g >> 29) & 1
        n += 1
        f.write("%d %d %d %d\n" % (n, lba, cero, rej)); f.flush()

        marcas = []
        if lba in vistos:
            marcas.append("REPE(ya en #%d)" % vistos[lba]); repes += 1
        if prev is not None and lba != prev + 1:
            marcas.append("SALTO %+d" % (lba - prev)); saltos += 1
        if cero: marcas.append("CERO"); ceros += 1
        if rej:  marcas.append("RECHA"); recha += 1
        vistos[lba] = n
        prev = lba

        # solo se imprime lo interesante: la traza entera va al fichero
        if marcas or n <= 5 or n % 200 == 0:
            print("%6d  %9d  %s" % (n, lba, " ".join(marcas)))
except KeyboardInterrupt:
    pass
finally:
    f.close()
    print()
    print("escrituras: %d   repetidas: %d   saltos: %d   a cero: %d   rechazadas: %d"
          % (n, repes, saltos, ceros, recha))
    print("traza completa en %s" % salida)
