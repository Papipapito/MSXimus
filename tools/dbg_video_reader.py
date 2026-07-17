#!/usr/bin/env python3
# dbg_video_reader.py — _114diag: lee por COM11 el ESTADO DEL VIDEO que va
# metido en el byte 15 de la trama de telemetria (nibble alto), para
# diagnosticar el HDMI muerto sin depender de la pantalla.
#   byte15 = {vid[3:0], alive[3:0]}
#     alive[3:0]  = latido del MOTOR (avanza cada CE)  -> motor vivo
#     vid[2:0]    = frame_cnt del lado VIDEO (modo activo) -> si AVANZA entre
#                   tramas, el pipeline de video GENERA FRAMES (pipeline vivo)
#     vid[3]      = pll27_lock (PLL de video base bloqueado)
# VEREDICTO:
#   frame_cnt AVANZA + pll_lock=1 -> pipeline vivo => falla la SALIDA fisica
#                                    (gearbox OSER10 / TMDS): skew del serializador
#   frame_cnt CONGELADO + pll=1   -> PLL ok pero frames muertos => sync/reset
#   pll_lock=0                    -> ni el PLL base bloquea (entrada de reloj)
# Uso: python tools\dbg_video_reader.py [COMx]
import sys
try:
    import serial
    from serial.tools import list_ports
except ImportError:
    sys.exit("pip install pyserial")

def pick_port():
    if len(sys.argv) > 1:
        return sys.argv[1]
    ports = [p.device for p in list_ports.comports() if 'CH340' in (p.description or '')]
    ports = ports or [p.device for p in list_ports.comports()]
    if not ports:
        sys.exit("no hay puertos serie")
    print("usando", ports[0])
    return ports[0]

def main():
    ser = serial.Serial(pick_port(), 115200, timeout=1)
    print("esperando tramas... (Ctrl+C para salir)")
    buf = bytearray(); prev = None; frozen = 0; alive_frozen = 0
    while True:
        buf += ser.read(64)
        while True:
            i = buf.find(b'\xa5')
            if i < 0 or len(buf) - i < 17:
                if i > 0: del buf[:i]
                break
            fr = bytes(buf[i:i+17]); del buf[:i+17]
            if (sum(fr[:16]) & 0xFF) != fr[16]:
                continue
            vid = fr[15] >> 4
            cur = dict(seq=fr[1], alive=fr[15] & 15,
                       fcnt=vid & 7, pll=(vid >> 3) & 1)
            if prev:
                df = (cur['fcnt'] - prev['fcnt']) & 7
                da = (cur['alive'] - prev['alive']) & 15
                frozen = frozen + 1 if df == 0 else 0
                alive_frozen = alive_frozen + 1 if da == 0 else 0
                vid_state = "FRAMES-VIVO " if df else f"CONGELADO({frozen})"
                mot = "motor-vivo" if da else f"MOTOR-PARADO({alive_frozen})"
                verd = ""
                if frozen >= 3:
                    verd = "  => PLL ok, frames MUERTOS: sync/reset" if cur['pll'] \
                           else "  => PLL27 NO BLOQUEA (entrada de reloj)"
                elif df and cur['pll']:
                    verd = "  => pipeline VIVO: falla SALIDA fisica (gearbox/TMDS)"
                print(f"seq={cur['seq']:3d} alive={cur['alive']:2d}[{mot}] "
                      f"fcnt={cur['fcnt']}[d{df}] pll27={cur['pll']} "
                      f"video:{vid_state}{verd}")
            prev = cur

if __name__ == '__main__':
    try: main()
    except KeyboardInterrupt: pass
