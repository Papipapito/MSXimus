#!/usr/bin/env python3
# dbg_audio_reader.py — lector COM11 para la _127H (debug del bug #14 audio).
# Formato de la FPGA: "D <miss> <AUDIO> <bkb> <fan> <park>\r\n" cada 250ms.
# La 2a palabra (antes bkA) es ahora AUDIO = {rst_cnt[31:16], lock_cnt[15:0]}:
#   rst_cnt  = eventos de reset del bloque HDMI del puente (¡anomalias!)
#   lock_cnt = toggles del frame-lock (~30/s en regimen NTSC normal)
# Interpretacion:
#   - REGIMEN SANO: RST estable (0 saltos), LOCK/s clavado en ~29-31.
#   - Si cada corte de audio (~3s) coincide con RST+1 o con un bache del
#     LOCK/s -> el stream HDMI se esta re-arrancando: culpable el puente.
#   - Si RST/LOCK impasibles durante los cortes -> el problema NO es el
#     re-arranque del stream: mirar mezclador/packetizer.
# El script marca con "<<<<" cualquier anomalia para verla de un vistazo.
import sys, time
import serial

port = sys.argv[1] if len(sys.argv) > 1 else "COM11"
ser = serial.Serial(port, 115200, timeout=2)
print(f"escuchando {port} @115200 — _127H audio debug (Ctrl+C para salir)")
print("hora      RST  d  LOCK   lock/s   miss/s   fan    park")
prev = None
prev_t = None
t0 = time.time()
while True:
    ln = ser.readline().decode("ascii", "replace").strip()
    if not ln.startswith("D "):
        continue
    try:
        p = [int(x, 16) for x in ln.split()[1:6]]
        miss, aud, bkb, fanw, park = (p + [0] * 5)[:5]
    except Exception:
        continue
    rst  = (aud >> 16) & 0xFFFF
    lock = aud & 0xFFFF
    now = time.time()
    if prev is not None:
        dt = now - prev_t
        d_rst  = (rst  - prev[0]) & 0xFFFF
        d_lock = (lock - prev[1]) & 0xFFFF
        d_miss = (miss - prev[2]) & 0xFFFFFFFF
        lock_s = d_lock / dt if dt > 0 else 0
        miss_s = d_miss / dt if dt > 0 else 0
        anom = ""
        if d_rst:
            anom = "  <<<< RESET HDMI"
        elif not (24 <= lock_s <= 36) and dt < 2:
            anom = "  <<<< LOCK RARO"
        fan = f"{'ON' if fanw >> 31 else 'of'}"
        print(f"+{now - t0:6.1f}s {rst:4d} {'+' + str(d_rst) if d_rst else ' .'} "
              f"{lock:5d}  {lock_s:6.1f}  {miss_s:8.0f}  {fan}  "
              f"{park & 0xFFFF}/{park >> 16}{anom}")
    prev = (rst, lock, miss)
    prev_t = now
