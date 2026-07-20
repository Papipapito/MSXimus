#!/usr/bin/env python3
# dbg_shim_reader.py — lector de la telemetria del shim V9968 (_121diag).
# La FPGA emite por el USB-UART (COM11, 115200):
#   "D <miss> <bka> <bkb> <fan>\r\n"  cada 250ms (hex32; <fan> desde _123).
# Este lector muestra los contadores y sus TASAS:
#   miss/s  = misses de bg (ventana+cache) por segundo
#   bkA/s   = completaciones del canal A (wv2) por segundo
#   bkB/s   = completaciones del canal B (wv3) por segundo
#   fan     = _123: bit31 = FAN_EN, bits[19:0] = cuenta del termometro RO
#             (dbg_cnt de fan_ctrl; para CALIBRAR: apuntar cuenta en frio al
#              arrancar y cuenta con el disipador caliente, la caida % fija
#              el K_ON real. En _119/_122 los umbrales estimados no dispararon.)
# Diagnostico: SC8 limpio ~ miss/s≈0, bkA/s≈bkB/s≈1.4M (fills parejos).
#   inanicion del arbitro -> miss/s alto y bkA+bkB muy por debajo de 2.8M
#   canal B muerto        -> bkB/s ≈ 0
#   CDC corrupto          -> tasas sanas pero pantalla mal (=> siguiente ronda)
import sys, time
import serial

port = sys.argv[1] if len(sys.argv) > 1 else "COM11"
ser = serial.Serial(port, 115200, timeout=2)
print(f"escuchando {port} @115200 (Ctrl+C para salir)")
prev = None
prev_t = None
while True:
    ln = ser.readline().decode("ascii", "replace").strip()
    if not ln.startswith("D "):
        if ln:
            print(f"(otra linea: {ln[:60]})")
        continue
    try:
        parts = [int(x, 16) for x in ln.split()[1:6]]
        miss, bka, bkb = parts[0], parts[1], parts[2]
        fanw = parts[3] if len(parts) > 3 else None
        park = parts[4] if len(parts) > 4 else None
    except Exception:
        print(f"(malformada: {ln[:60]})")
        continue
    now = time.time()
    fan = "" if fanw is None else f"  fan={'ON ' if fanw >> 31 else 'off'} ro={fanw & 0xFFFFF}"
    if park is not None:
        # _124: palabra 5 = {pisadas_park[15:0], drenajes_park[15:0]}
        fan += f"  pkov={park >> 16} pkok={park & 0xFFFF}"
    if prev is not None:
        dt = now - prev_t
        dm = (miss - prev[0]) & 0xFFFFFFFF
        da = (bka - prev[1]) & 0xFFFFFFFF
        db = (bkb - prev[2]) & 0xFFFFFFFF
        print(f"miss={miss:10d} (+{dm/dt:9.0f}/s)  "
              f"bkA={bka:10d} (+{da/dt:9.0f}/s)  "
              f"bkB={bkb:10d} (+{db/dt:9.0f}/s){fan}")
    else:
        print(f"miss={miss} bkA={bka} bkB={bkb}{fan} (primera muestra)")
    prev = (miss, bka, bkb)
    prev_t = now
