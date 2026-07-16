// tb_timer.cpp — _108: el patron de VGMPlay/MBWave sobre el timer del OPL4.
// T1=-11 (1130Hz), start (reg4=0x39), esperar IRQ, ack (reg4=0x80) y
// comprobar que el timer SIGUE corriendo (el bug _84 lo paraba: el ack
// tambien escribia st1=0). PASA si llegan >=3 IRQs con periodo estable.
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

// espera flanco de bajada de irq_n; devuelve ciclo o 0 si timeout
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

    wr(0x02, 0xF5);          // T1 = -11 -> 11 x 80us = 880us (23760 c @27M)
    wr(0x04, 0x80);          // reset flags (VGMPlay lo hace primero)
    wr(0x04, 0x39);          // 00111001: mt2 + st1 (patron VGMPlay)

    uint64_t t[4] = {0,0,0,0};
    for (int i = 0; i < 4; ++i) {
        t[i] = wait_irq(60000);
        if (!t[i]) { printf("*** FALLO: IRQ %d no llego (timeout) ***\n", i+1); return 1; }
        printf("IRQ %d en ciclo %llu (status=%02x)\n", i+1, (unsigned long long)t[i], dut->dout);
        wr(0x04, 0x80);      // ack del ISR
        if (!dut->irq_n) { printf("*** FALLO: irq_n no subio tras el ack ***\n"); return 1; }
    }
    long long p1 = (long long)(t[1]-t[0]), p2 = (long long)(t[2]-t[1]), p3 = (long long)(t[3]-t[2]);
    printf("periodos: %lld %lld %lld ciclos (nominal ~23760 mas el coste del ack)\n", p1, p2, p3);
    bool ok = p1 > 20000 && p1 < 28000 && (p2-p1) < 200 && (p2-p1) > -200 && (p3-p2) < 200 && (p3-p2) > -200;
    printf(ok ? "*** TIMER CANON: PASA ***\n" : "*** PERIODOS MAL ***\n");
    return ok ? 0 : 1;
}
