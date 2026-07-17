// tb_timer.cpp — _108/_109: semantica canon de los timers del OPL4.
// Test 1: la secuencia EXACTA del OPL3_DetectPort de VGMPlay (Grauw) —
//   el cleanup enmascara (reg4=0x78) SIN 0x80 final: en el chip real la
//   mascara LIMPIA los flags (canon ymfm) y la IRQ baja. Sin eso, la IRQ
//   queda clavada -> tormenta al EI -> el cuelgue "al detectar" de la _108.
// Test 2: el patron del ISR de VGMPlay: T1=-11 (1130Hz), ack con 0x80 y
//   el timer debe SEGUIR corriendo (el bug _84 lo paraba).
#include "Vopl3.h"
#include "verilated.h"
#include <cstdio>
#include <cstdint>

static Vopl3 *dut = nullptr;
static uint64_t cycle = 0;

static void tick() {
    dut->clk = 0; dut->clk_host = 0; dut->eval();
    dut->clk = 1; dut->clk_host = 1; dut->eval();
    cycle++;
}
static void ticks(int n) { for (int i = 0; i < n; ++i) tick(); }

static void wr_addr(uint8_t reg, bool bank) {
    dut->address = bank ? 2 : 0; dut->din = reg;
    dut->cs_n = 0; dut->wr_n = 0; tick();
    dut->cs_n = 1; dut->wr_n = 1; dut->din = 0; ticks(6);
}
static void wr_data(uint8_t v) {
    dut->address = 1; dut->din = v;
    dut->cs_n = 0; dut->wr_n = 0; tick();
    dut->cs_n = 1; dut->wr_n = 1; dut->din = 0; ticks(36);
}
static void wr(uint16_t reg, uint8_t v) { wr_addr(reg & 0xff, (reg & 0x100) != 0); wr_data(v); }

static uint64_t wait_irq(uint64_t maxc) {
    uint64_t start = cycle;
    while (cycle - start < maxc) {
        tick();
        if (!dut->irq_n) return cycle;
    }
    return 0;
}

// === test 3: nota FM sostenida +/- acks del ISR a 1130Hz (VGMPlay toca FM
// mientras ackea su timer: si cada ack perturba la sintesis, la nota vibra)
static void run_note_isr(bool isr, int16_t *buf, int nsamp) {
    wr(0x105, 0x01);            // NEW
    wr(0x20, 0x01); wr(0x40, 0x1C); wr(0x60, 0xF4); wr(0x80, 0x01);
    wr(0x23, 0x01); wr(0x43, 0x00); wr(0x63, 0xF2); wr(0x83, 0x01);
    wr(0xC0, 0x3C);
    wr(0xA0, 0x41); wr(0xB0, 0x32);  // keyon blk4
    if (isr) { wr(0x02, 0xF5); wr(0x04, 0x80); wr(0x04, 0x39); }
    int n = 0;
    uint64_t last_ack = cycle;
    int sv_d = dut->sample_valid;
    while (n < nsamp) {
        tick();
        if (dut->sample_valid && !sv_d) buf[n++] = (int16_t)dut->sample_l;
        sv_d = dut->sample_valid;
        if (isr && !dut->irq_n && cycle - last_ack > 2000) {
            wr(0x04, 0x80); last_ack = cycle;
        }
    }
    wr(0xB0, 0x12);
    wr(0x04, 0x78); wr(0x04, 0x80);
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    dut = new Vopl3;
    dut->cs_n = 1; dut->wr_n = 1; dut->ic_n = 0;
    ticks(64);
    dut->ic_n = 1;
    ticks(4096);

    // === test 1: OPL3_DetectPort de VGMPlay (Grauw), secuencia exacta ===
    wr(0x04, 0x80);          // reset flags
    wr(0x02, 0xFF);          // T1 = -1 -> 80us
    wr(0x04, 0x39);          // 00111001: arranca T1 (T1 sin mascara)
    ticks(27000 * 2);        // >160us: T1 debe haber desbordado
    if (dut->irq_n) { printf("*** FALLO detect: flag/irq no subio ***\n"); return 1; }
    wr(0x04, 0x78);          // cleanup de Grauw: MASCARAS, sin 0x80
    if (!dut->irq_n) { printf("*** FALLO detect: la mascara NO limpio el flag (irq clavada => tormenta) ***\n"); return 1; }
    printf("detect AdLib: la mascara limpia flag e irq -> OK\n");

    // === test 2: patron del ISR de VGMPlay (el ack no para el timer) ===
    wr(0x02, 0xF5);          // T1 = -11 -> 11 x 80us = 880us (23760 c @27M)
    wr(0x04, 0x80);          // reset flags (VGMPlay lo hace primero)
    wr(0x04, 0x39);          // mt2 + st1 (patron VGMPlay)

    uint64_t t[4] = {0,0,0,0};
    for (int i = 0; i < 4; ++i) {
        t[i] = wait_irq(60000);
        if (!t[i]) { printf("*** FALLO: IRQ %d no llego (timeout) ***\n", i+1); return 1; }
        printf("IRQ %d en ciclo %llu\n", i+1, (unsigned long long)t[i]);
        wr(0x04, 0x80);      // ack del ISR
        if (!dut->irq_n) { printf("*** FALLO: irq_n no subio tras el ack ***\n"); return 1; }
    }
    long long p1 = (long long)(t[1]-t[0]), p2 = (long long)(t[2]-t[1]), p3 = (long long)(t[3]-t[2]);
    printf("periodos: %lld %lld %lld ciclos (nominal ~23760 mas el coste del ack)\n", p1, p2, p3);
    bool ok = p1 > 20000 && p1 < 28000 && (p2-p1) < 200 && (p2-p1) > -200 && (p3-p2) < 200 && (p3-p2) > -200;
    printf(ok ? "*** TIMER CANON: PASA ***\n" : "*** PERIODOS MAL ***\n");
    if (!ok) return 1;

    // === test 3: nota sostenida — control (A vs A2, ambas sin ISR) y
    //     experimento (A vs B, con acks a 1130Hz) ===
    static int16_t bufA[24000], bufA2[24000], bufB[24000];
    run_note_isr(false, bufA, 24000);
    ticks(200000);
    run_note_isr(false, bufA2, 24000);
    ticks(200000);
    run_note_isr(true,  bufB, 24000);
    // rugosidad AUTOCONTENIDA: variacion bloque-a-bloque de la envolvente
    // dentro de CADA pasada (detrend local: cociente entre bloques vecinos).
    // Inmune a la fase/desalineacion entre pasadas.
    auto rough = [](int16_t *buf) {
        double prev = -1, worst = 0;
        for (int b = 8; b < 24000/256; ++b) {
            double r = 0;
            for (int k = 0; k < 256; ++k) r += (double)buf[b*256+k]*buf[b*256+k];
            r /= 256;
            if (prev > 1000 && r > 100) {
                double q = r/prev; if (q>1) q=1/q;
                if (1-q > worst) worst = 1-q;
            }
            prev = r;
        }
        return worst;
    };
    double rA = rough(bufA), rA2 = rough(bufA2), rB = rough(bufB);
    printf("rugosidad envolvente: A=%.2f%% A2=%.2f%% B(con ISR)=%.2f%%\n", rA*100, rA2*100, rB*100);
    double base = (rA > rA2 ? rA : rA2);
    printf(rB > base*2 && rB > 0.05 ? "*** FM + ISR: MODULADO (senal real) ***\n"
                                    : "*** FM + ISR: LIMPIO (rugosidad comparable al control) ***\n");

    // === test 4: VIBRATO del FM (canon YMF262: 6.07Hz; DVB=1 -> +/-14c) ===
    // Los parches de toda la saga llevaban VIB=0: vibrato.sv JAMAS se ha
    // validado. Las canciones reales (MoonDriver/MBWave) lo encienden en
    // casi todo: si la tasa/profundidad esta mal, "los instrumentos vibran".
    ticks(200000);
    wr(0x105, 0x01);
    wr(0x20, 0x61); wr(0x40, 0x10); wr(0x60, 0xF0); wr(0x80, 0x0F);  // op1 VIB+EGT (sostiene)
    wr(0x23, 0x41); wr(0x43, 0x00); wr(0x63, 0xF0); wr(0x83, 0x0F);  // op2 VIB
    wr(0xC0, 0x31);                    // salida L+R, alg aditivo
    wr(0xBD, 0x40);                    // DVB=1 (vibrato profundo)
    wr(0xA0, 0x41); wr(0xB0, 0x32);    // keyon blk4 (~440Hz)
    static int16_t vbuf[132000];
    { int n=0, sv=dut->sample_valid;
      while (n < 132000) { tick();
        if (dut->sample_valid && !sv) vbuf[n++] = (int16_t)dut->sample_l;
        sv = dut->sample_valid; } }
    wr(0xB0, 0x12);
    { FILE *fv = fopen("vib_on.raw", "wb");
      fwrite(vbuf, 2, 132000, fv); fclose(fv); }
    // control: misma nota con VIB=0
    ticks(200000);
    wr(0x20, 0x21); wr(0x23, 0x21);    // VIB off, EGT on
    wr(0xA0, 0x41); wr(0xB0, 0x32);
    { int n=0, sv=dut->sample_valid;
      while (n < 132000) { tick();
        if (dut->sample_valid && !sv) vbuf[n++] = (int16_t)dut->sample_l;
        sv = dut->sample_valid; } }
    wr(0xB0, 0x12);
    { FILE *fv = fopen("vib_off.raw", "wb");
      fwrite(vbuf, 2, 132000, fv); fclose(fv); }
    // tremolo: AM=1 en ambos ops + DAM=1 (canon: 4.8dB a 3.7Hz)
    ticks(200000);
    wr(0x20, 0xA1); wr(0x23, 0xA1);    // AM+EGT, VIB off
    wr(0xBD, 0x80);                    // DAM=1 (tremolo profundo)
    wr(0xA0, 0x41); wr(0xB0, 0x32);
    { int n=0, sv=dut->sample_valid;
      while (n < 132000) { tick();
        if (dut->sample_valid && !sv) vbuf[n++] = (int16_t)dut->sample_l;
        sv = dut->sample_valid; } }
    wr(0xB0, 0x12);
    { FILE *fv = fopen("trem_on.raw", "wb");
      fwrite(vbuf, 2, 132000, fv); fclose(fv); }
    printf("dumps vib_on/vib_off/trem_on escritos\n");
    {
        double t_prev = -1; int k = 0;
        static double ft[8000]; static double tt[8000];
        for (int i = 44100; i < 131999 && k < 8000; ++i) {
            if (vbuf[i] < 0 && vbuf[i+1] >= 0) {
                double frac = (double)(-vbuf[i]) / ((double)vbuf[i+1] - vbuf[i]);
                double tc = (i + frac) / 44100.0;
                if (t_prev > 0 && tc > t_prev) { ft[k] = 1.0/(tc - t_prev); tt[k] = tc; k++; }
                t_prev = tc;
            }
        }
        if (k < 100) { printf("*** VIB: sin senal utilizable ***\n"); return 1; }
        double fmin=1e9, fmax=0, fsum=0;
        for (int j = 0; j < k; ++j) { if (ft[j]<fmin) fmin=ft[j]; if (ft[j]>fmax) fmax=ft[j]; fsum+=ft[j]; }
        double favg = fsum/k;
        double depth_c = 1200.0 * log2(fmax/fmin) / 2.0;
        int mc = 0; double tfirst=-1, tlast=0;
        for (int j = 1; j < k; ++j)
            if ((ft[j-1] < favg) != (ft[j] < favg)) { if (tfirst<0) tfirst=tt[j]; tlast=tt[j]; mc++; }
        double rate = (mc > 2 && tlast > tfirst) ? (mc/2.0) / (tlast - tfirst) : 0;
        printf("VIBRATO FM: f=%.1fHz, profundidad ~+/-%.1f cents, tasa ~%.2f Hz\n", favg, depth_c, rate);
        printf("canon YMF262 con DVB=1: +/-14 cents a 6.07 Hz\n");
        bool okv = depth_c > 5 && depth_c < 25 && rate > 4.5 && rate < 8.0;
        printf(okv ? "*** VIBRATO: DENTRO DEL CANON ***\n" : "*** VIBRATO: FUERA DE CANON ***\n");
    }
    return 0;

}
