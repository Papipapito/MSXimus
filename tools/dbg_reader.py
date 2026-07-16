#!/usr/bin/env python3
# dbg_reader.py — lector de la telemetria del MSXimus (_111).
# Cableado: PMOD1 pin E22 (dbg_pmod1[4]) -> RX del CH340, GND comun.
#   (El mismo adaptador CH340 de la saga WiFi: E22 al pin TXD del zocalo.)
# Uso:  python tools\dbg_reader.py [COMx]   (autodetecta si se omite)
#
# Trama (17 bytes @115200 8N1, cada ~250ms):
#   A5 seq rep[2] drop[2] push[2] tick[2] miss[2] pf[2] {lvl_min,lvl} {ifw,alive} sum
# Muestra DELTAS por ventana: rep/drop deberian ser SIEMPRE 0 mientras suena;
# push==tick; miss bajo salvo ataques de nota. Si rep/drop se mueven mientras
# "vibra" -> la FIFO es la culpable; si no -> el motor produce la modulacion.
import sys, time

try:
    import serial
    from serial.tools import list_ports
except ImportError:
    sys.exit("pip install pyserial")

def pick_port():
    if len(sys.argv) > 1:
        return sys.argv[1]
    ports = [p.device for p in list_ports.comports() if 'CH340' in (p.description or '')]
    if not ports:
        ports = [p.device for p in list_ports.comports()]
    if not ports:
        sys.exit("no hay puertos serie")
    print("usando", ports[0], "(pasa el COM como argumento para forzar otro)")
    return ports[0]

def u16(b, i):
    return b[i] * 256 + b[i + 1]

def main():
    ser = serial.Serial(pick_port(), 115200, timeout=1)
    print("esperando tramas... (Ctrl+C para salir)")
    buf = bytearray()
    prev = None
    while True:
        buf += ser.read(64)
        while True:
            i = buf.find(b'\xa5')
            if i < 0 or len(buf) - i < 17:
                if i > 0: del buf[:i]
                break
            fr = bytes(buf[i:i + 17]); del buf[:i + 17]
            if (sum(fr[:16]) & 0xFF) != fr[16]:
                print("! checksum"); continue
            cur = dict(seq=fr[1], rep=u16(fr, 2), drop=u16(fr, 4), push=u16(fr, 6),
                       tick=u16(fr, 8), miss=u16(fr, 10), pf=u16(fr, 12),
                       lvl=fr[14] & 15, lvl_min=fr[14] >> 4,
                       ifw=fr[15] >> 4, alive=fr[15] & 15)
            if prev:
                d = {k: (cur[k] - prev[k]) & 0xFFFF for k in ('rep', 'drop', 'push', 'tick', 'miss', 'pf')}
                flag = "  <-- ¡FIFO!" if (d['rep'] or d['drop']) else ""
                print(f"seq={cur['seq']:3d} d_rep={d['rep']:5d} d_drop={d['drop']:5d} "
                      f"d_push={d['push']:5d} d_tick={d['tick']:5d} d_miss={d['miss']:5d} "
                      f"d_pf={d['pf']:6d} lvl={cur['lvl']:2d} min={cur['lvl_min']:2d} "
                      f"ifw={cur['ifw']}{flag}")
            prev = cur

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
