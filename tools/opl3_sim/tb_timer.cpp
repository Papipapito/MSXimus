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
    return ok ? 0 : 1;
}
