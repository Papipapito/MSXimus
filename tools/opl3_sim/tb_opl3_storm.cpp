// ============================================================================
//  tb_opl3_storm — guardian de la DIETA del OPL3 (era v3)
//
//  El tb_opl3 normal escribe los registros ANTES de sonar y luego solo hace un
//  key-off. Eso NO prueba lo delicado de la dieta: los cuatro ficheros de
//  registro del operador (0x20-0x35, 0x40-0x55, 0x60-0x75, 0x80-0x95) ahora
//  viven en un BSRAM que se lee SINCRONO con la direccion adelantada, y una
//  escritura que cae justo en el flanco de captura la veria la version
//  asincrona original pero no el BSRAM. Ese hueco lo tapa el camino de
//  adelanto (bypass), y este banco es lo unico que lo ejercita.
//
//  Metodo: sonar y, a la vez, martillear escrituras en esos cuatro rangos con
//  separaciones VARIABLES (paso primo) para barrer todas las fases posibles
//  respecto al barrido de 37 estados x 2 ciclos del motor. Si el bypass
//  fallara en una sola fase, el WAV dejaria de ser bit-identico.
//
//  Uso: igual que tb_opl3 -> ./Vopl3 salida.wav [n_muestras]
// ============================================================================
#include "Vopl3.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>

static Vopl3 *dut = nullptr;
static uint64_t cycle = 0;

struct WavSink {
    FILE *f;
    uint32_t n_samples = 0;
    uint32_t sample_rate;
    WavSink(const char *path, uint32_t sr) : sample_rate(sr) {
        f = fopen(path, "wb");
        if (!f) { fprintf(stderr, "no puedo abrir %s\n", path); exit(1); }
        for (int i = 0; i < 44; ++i) fputc(0, f);
    }
    void push(int16_t l, int16_t r) {
        fwrite(&l, 2, 1, f); fwrite(&r, 2, 1, f);
        n_samples++;
    }
    void close() {
        uint32_t data_bytes = n_samples * 4;
        uint32_t riff = 36 + data_bytes;
        uint32_t fmt_len = 16, byte_rate = sample_rate * 4;
        uint16_t fmt = 1, ch = 2, align = 4, bits = 16;
        fseek(f, 0, SEEK_SET);
        fwrite("RIFF", 1, 4, f); fwrite(&riff, 4, 1, f);
        fwrite("WAVE", 1, 4, f); fwrite("fmt ", 1, 4, f);
        fwrite(&fmt_len, 4, 1, f); fwrite(&fmt, 2, 1, f); fwrite(&ch, 2, 1, f);
        fwrite(&sample_rate, 4, 1, f); fwrite(&byte_rate, 4, 1, f);
        fwrite(&align, 2, 1, f); fwrite(&bits, 2, 1, f);
        fwrite("data", 1, 4, f); fwrite(&data_bytes, 4, 1, f);
        fclose(f);
    }
};

static WavSink *g_wav = nullptr;
static int g_prev_valid = 0;

// tick que SIEMPRE captura: si no, las muestras generadas durante los 44
// ciclos que dura una escritura se perderian y el banco dejaria de mirar
// justo donde mas falta hace.
static void tick() {
    dut->clk = 0; dut->clk_host = 0; dut->eval();
    dut->clk = 1; dut->clk_host = 1; dut->eval();
    cycle++;
    if (g_wav) {
        if (dut->sample_valid && !g_prev_valid) {
            int32_t l = (int32_t)(dut->sample_l & 0xFFFFFF);
            int32_t r = (int32_t)(dut->sample_r & 0xFFFFFF);
            if (l & 0x800000) l |= 0xFF000000;
            if (r & 0x800000) r |= 0xFF000000;
            l >>= 8; r >>= 8;
            if (l > 32767) l = 32767; if (l < -32768) l = -32768;
            if (r > 32767) r = 32767; if (r < -32768) r = -32768;
            g_wav->push((int16_t)l, (int16_t)r);
        }
        g_prev_valid = dut->sample_valid;
    }
}

static void ticks(int n) { for (int i = 0; i < n; ++i) tick(); }

static void opl3_write_addr(uint8_t reg, bool bank) {
    dut->address = bank ? 0b10 : 0b00;
    dut->din = reg; dut->cs_n = 0; dut->wr_n = 0;
    tick();
    dut->cs_n = 1; dut->wr_n = 1; dut->din = 0;
    ticks(6);
}

static void opl3_write_data(uint8_t value) {
    dut->address = 0b01;
    dut->din = value; dut->cs_n = 0; dut->wr_n = 0;
    tick();
    dut->cs_n = 1; dut->wr_n = 1; dut->din = 0;
    ticks(36);
}

static void opl3_write(uint16_t reg, uint8_t value) {
    opl3_write_addr(reg & 0xff, (reg & 0x100) != 0);
    opl3_write_data(value);
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    dut = new Vopl3;

    const char *out_path = "out.wav";
    uint32_t target_samples = 24000;
    if (argc > 1) out_path = argv[1];
    if (argc > 2) target_samples = atoi(argv[2]);

    dut->ic_n = 0; dut->cs_n = 1; dut->rd_n = 1; dut->wr_n = 1;
    dut->address = 0; dut->din = 0; dut->clk_dac = 0;
    ticks(100);
    dut->ic_n = 1;
    ticks(2000);

    // Mismos parches que tb_opl3: piano ch0 + bajo ch1.
    opl3_write(0x105, 0x01);
    opl3_write(0x01, 0x00);
    opl3_write(0x20, 0x01); opl3_write(0x40, 0x1c);
    opl3_write(0x60, 0xf4); opl3_write(0x80, 0x27);
    opl3_write(0x23, 0x01); opl3_write(0x43, 0x00);
    opl3_write(0x63, 0xf2); opl3_write(0x83, 0x45);
    opl3_write(0xc0, 0x3c);
    opl3_write(0x21, 0x01); opl3_write(0x41, 0x10);
    opl3_write(0x61, 0xf6); opl3_write(0x81, 0x26);
    opl3_write(0x24, 0x01); opl3_write(0x44, 0x08);
    opl3_write(0x64, 0xf4); opl3_write(0x84, 0x36);
    opl3_write(0xc1, 0x38);
    opl3_write(0xa0, 0x59); opl3_write(0xb0, 0x35);
    opl3_write(0xa1, 0x59); opl3_write(0xb1, 0x2d);

    WavSink wav(out_path, 49716);
    g_wav = &wav;

    // Operadores que SUENAN de verdad (ch0: 0 y 3, ch1: 1 y 4). Escribir en
    // operadores mudos no probaria nada porque su valor no llega al WAV.
    const uint8_t opidx[4] = {0x00, 0x01, 0x03, 0x04};
    // Bases de los cuatro rangos que la dieta movio al BSRAM.
    const uint8_t base[4]  = {0x20, 0x40, 0x60, 0x80};
    // Valores plausibles: no dejan el canal mudo, asi que cualquier
    // divergencia se oye.
    const uint8_t val[4][4] = {
        {0x01, 0x02, 0x11, 0x21},   // am/vib/egt/ksr/mult
        {0x00, 0x08, 0x1c, 0x10},   // ksl/tl
        {0xf4, 0xf2, 0xf6, 0xe8},   // ar/dr
        {0x27, 0x45, 0x26, 0x36},   // sl/rr
    };

    uint32_t i = 0;
    uint64_t deadline = (uint64_t)target_samples * 900;
    uint64_t start = cycle;

    while (wav.n_samples < target_samples && (cycle - start) < deadline) {
        // Separacion variable con paso primo (17) modulo 74 = la longitud del
        // barrido: asi la escritura cae en TODAS las fases del motor.
        ticks(1 + (int)((i * 17) % 74));

        uint32_t r = i & 3, o = (i >> 2) & 3, v = (i >> 4) & 3;
        opl3_write(base[r] + opidx[o], val[r][v]);

        // Re-disparo periodico para que la nota no se apague del todo y el
        // banco siga siendo sensible durante toda la captura.
        if ((i % 64) == 63) {
            opl3_write(0xb0, 0x35);
            opl3_write(0xb1, 0x2d);
        }
        ++i;
    }

    wav.close();
    fprintf(stderr, "storm: %u muestras, %u escrituras, %llu ciclos -> %s\n",
            wav.n_samples, i, (unsigned long long)(cycle - start), out_path);
    delete dut;
    return 0;
}
