#!/usr/bin/env python3
# dbg_audio_reader.py — lector COM11 para _127H/_127I (debug del bug #14).
# Formato de la FPGA: "D <miss> <AUDIO> <APKT> <fan> <park>\r\n" cada 250ms.
# Palabra 2 (AUDIO) = {rst_cnt[31:16], lock_cnt[15:0]} (_127H):
#   rst_cnt  = eventos de reset del bloque HDMI del puente (¡anomalias!)
#   lock_cnt = toggles del frame-lock (~30/s en regimen NTSC normal)
# Palabra 3 (APKT, _127I; en la _127H es la bkb del shim — ignorar) =
#   {ovr[31:24], 0, paquetes_audio[15:0]} del packet_picker HDMI:
#   pkt/s DEBE ser 11025.0 CLAVADO (44100/4) y ovr fijo.
# Interpretacion:
#   - pkt/s clavado y ovr quieto DURANTE un corte audible -> el transmisor
#     entrega perfecto: culpable receptor/cable (SI del TMDS o DSP monitor).
#   - pkt/s baja o ovr sube en los cortes -> culpable el lado FPGA.
# El script marca con "<<<<" cualquier anomalia para verla de un vistazo.
import sys, time
import serial

port = sys.argv[1] if len(sys.argv) > 1 else "COM11"
ser = serial.Serial(port, 115200, timeout=2)
print(f"escuchando {port} @115200 — _127I audio debug (Ctrl+C para salir)")
print("hora      RST  d  lock/s   pkt/s   miss/s  fan  dfr/s  ops|vumetro  estado")
prev = None
prev_t = None
t0 = time.time()
while True:
    ln = ser.readline().decode("ascii", "replace").strip()
    if not ln.startswith("D "):
        continue
    try:
        p = [int(x, 16) for x in ln.split()[1:6]]
        miss, aud, apkt, fanw, park = (p + [0] * 5)[:5]
    except Exception:
        continue
    rst  = (aud >> 16) & 0xFFFF
    lock = aud & 0xFFFF
    pkt  = apkt & 0xFFFF
    ovr  = (apkt >> 24) & 0xFF
    # _128Y: bits [23:16] = diag DDR3
    #   {x1_alive, pll_lock, por_done, calib_ever, wd_fires[2:0], calib_drop}
    dd   = (apkt >> 16) & 0xFF
    dd_x1    = (dd >> 7) & 1
    dd_pll   = (dd >> 6) & 1
    dd_por   = (dd >> 5) & 1
    dd_calib = (dd >> 4) & 1
    dd_fires = (dd >> 1) & 7
    dd_drop  = dd & 1
    now = time.time()
    if prev is not None:
        dt = now - prev_t
        d_rst  = (rst  - prev[0]) & 0xFFFF
        d_lock = (lock - prev[1]) & 0xFFFF
        d_miss = (miss - prev[2]) & 0xFFFFFFFF
        d_pkt  = (pkt  - prev[3]) & 0xFFFF
        d_ovr  = (ovr  - prev[4]) & 0xFF
        lock_s = d_lock / dt if dt > 0 else 0
        miss_s = d_miss / dt if dt > 0 else 0
        pkt_s  = d_pkt / dt if dt > 0 else 0
        # _134: cnt_d = {fan_en, tear[4:0], defer[5:0], fan_dbg[19:0]}
        # defer/s ~60 = el yank del reset caia en la ventana de islands y se
        # esta difiriendo (fix activo); tear>0 = QUEDAN resets rompiendo
        # paquetes (assert violado). En builds pre-134 ambos leen 0.
        tear  = (fanw >> 26) & 0x1F
        defer = (fanw >> 20) & 0x3F
        d_tear  = (tear  - ((prev[6] >> 26) & 0x1F)) & 0x1F
        d_defer = (defer - ((prev[6] >> 20) & 0x3F)) & 0x3F
        anom = ""
        if d_rst:
            anom = "  <<<< RESET HDMI"
        elif d_tear:
            anom = f"  <<<< TEAR +{d_tear} (¡reset dentro de la isla!)"
        elif d_ovr:
            anom = f"  <<<< OVERRUN +{d_ovr}"
        elif dt < 2 and not (10800 <= pkt_s <= 11250):
            anom = "  <<<< TASA PAQUETES RARA"
        elif dt < 2 and not (24 <= lock_s <= 36):
            anom = "  <<<< LOCK RARO"
        fan = f"{'ON' if fanw >> 31 else 'of'}"
        # _133: discriminador de build — en las builds SDRAM el byte [23:16]
        # de cnt_c es 0 (no hay diag DDR3) y la palabra 5 lleva el VUMETRO
        # {amp_fuente[31:16], amp_hdmi[15:0]} (picos por ventana ~0.3s).
        # En las DDR3 el diag tiene el bit 5 fijo a 1 (nunca es 0).
        if dd == 0:
            a_src  = (park >> 16) & 0xFFFF
            a_hdmi = park & 0xFFFF
            ops = f"ampSRC={a_src:5d} ampHDMI={a_hdmi:5d}"
            ddtxt = "SDRAM+vumetro"
            if a_src > 200 and a_hdmi < (a_src >> 3):
                ddtxt = "SDRAM+vumetro <<<< CDC CONGELADO (hdmi mudo, fuente viva)"
        else:
            # _128Y: veredicto DDR3 — localiza el bloqueo exacto
            if not dd_pll:
                ddtxt = "DDR3:PLL-297-NO-ENGANCHA"
            elif not dd_por:
                ddtxt = "DDR3:POR-no-completa(27MHz?)"
            elif not dd_x1:
                ddtxt = "DDR3:IP-SIN-RELOJ(clk_x1 muerto)"
            elif not dd_calib:
                ddtxt = f"DDR3:PHY-NO-CALIBRA (reintentos={dd_fires})"
            elif dd_drop:
                ddtxt = f"DDR3:calibro-y-SE-CAYO (reint={dd_fires})"
            else:
                ddtxt = f"DDR3:OK (reintentos={dd_fires})"
            # _129b: con ENABLE_VRAM_DDR3 la palabra 5 = {lecturas, escrituras}
            d_rd = (((park >> 16) & 0xFFFF) - ((prev[5] >> 16) & 0xFFFF)) & 0xFFFF
            d_wr = ((park & 0xFFFF) - (prev[5] & 0xFFFF)) & 0xFFFF
            ops = f"rd/s={d_rd/dt:7.0f} wr/s={d_wr/dt:6.0f}"
        dfr = f"dfr/s={d_defer/dt:4.1f}" if dt > 0 else "dfr/s= ?"
        print(f"+{now - t0:6.1f}s {rst:4d} {'+' + str(d_rst) if d_rst else ' .'} "
              f"{lock_s:6.1f}  {pkt_s:8.1f}  {miss_s:6.0f}  {fan}  {dfr}  "
              f"{ops}  {ddtxt}{anom}")
    prev = (rst, lock, miss, pkt, ovr, park, fanw)
    prev_t = now
