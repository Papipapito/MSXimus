#include "Vopl3.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

static Vopl3 *dut = nullptr;
static uint64_t cycle = 0;

static void tick() {
    dut->clk = 0;
    dut->clk_host = 0;
    dut->eval();
    dut->clk = 1;
    dut->clk_host = 1;
    dut->eval();
    cycle++;
}

static void ticks(int n) { for (int i = 0; i < n; ++i) tick(); }

static void opl3_write_addr(uint8_t reg, bool bank) {
    dut->address = bank ? 0b10 : 0b00;
    dut->din = reg;
    dut->cs_n = 0;
    dut->wr_n = 0;
    tick();
    dut->cs_n = 1;
    dut->wr_n = 1;
    dut->din = 0;
    ticks(6);
}

static void opl3_write_data(uint8_t value) {
    dut->address = 0b01;
    dut->din = value;
    dut->cs_n = 0;
    dut->wr_n = 0;
    tick();
    dut->cs_n = 1;
    dut->wr_n = 1;
    dut->din = 0;
    ticks(36);
}

static void opl3_write(uint16_t reg, uint8_t value) {
    bool bank = (reg & 0x100) != 0;
    opl3_write_addr(reg & 0xff, bank);
    opl3_write_data(value);
}

struct WavSink {
    FILE *f;
    uint32_t n_samples = 0;
    uint32_t sample_rate;
    WavSink(const char *path, uint32_t sr) : sample_rate(sr) {
        f = fopen(path, "wb");
        if (!f) { fprintf(stderr, "fopen %s failed\n", path); exit(1); }
        for (int i = 0; i < 44; ++i) fputc(0, f);
    }
    void push(int16_t l, int16_t r) {
        fwrite(&l, 2, 1, f);
        fwrite(&r, 2, 1, f);
        n_samples++;
    }
    void close() {
        uint32_t data_bytes = n_samples * 4;
        uint32_t riff_size = 36 + data_bytes;
        uint32_t byte_rate = sample_rate * 4;
        fseek(f, 0, SEEK_SET);
        fwrite("RIFF", 4, 1, f);
        fwrite(&riff_size, 4, 1, f);
        fwrite("WAVEfmt ", 8, 1, f);
        uint32_t fmt_size = 16; uint16_t pcm = 1, ch = 2, ba = 4, bps = 16;
        fwrite(&fmt_size, 4, 1, f);
        fwrite(&pcm, 2, 1, f);
        fwrite(&ch, 2, 1, f);
        fwrite(&sample_rate, 4, 1, f);
        fwrite(&byte_rate, 4, 1, f);
        fwrite(&ba, 2, 1, f);
        fwrite(&bps, 2, 1, f);
        fwrite("data", 4, 1, f);
        fwrite(&data_bytes, 4, 1, f);
        fclose(f);
    }
};

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    dut = new Vopl3;

    const char *out_path = "out.wav";
    uint32_t target_samples = 24000;
    if (argc > 1) out_path = argv[1];
    if (argc > 2) target_samples = atoi(argv[2]);

    dut->ic_n = 0;
    dut->cs_n = 1;
    dut->rd_n = 1;
    dut->wr_n = 1;
    dut->address = 0;
    dut->din = 0;
    dut->clk_dac = 0;
    ticks(100);
    dut->ic_n = 1;
    ticks(2000);

    opl3_write(0x105, 0x01);
    opl3_write(0x01, 0x20);
    opl3_write(0x20, 0x01);
    opl3_write(0x40, 0x10);
    opl3_write(0x60, 0xf0);
    opl3_write(0x80, 0x77);
    opl3_write(0xe0, 0x00);
    opl3_write(0x23, 0x01);
    opl3_write(0x43, 0x00);
    opl3_write(0x63, 0xf0);
    opl3_write(0x83, 0x77);
    opl3_write(0xe3, 0x00);
    opl3_write(0xc0, 0xcb);
    opl3_write(0xa0, 0x44);
    opl3_write(0xb0, 0x32);

    WavSink wav(out_path, 49716);
    int prev_valid = 0;
    bool keyoff_done = false;
    uint64_t deadline_cycles = (uint64_t)target_samples * 800;
    uint64_t start = cycle;
    while (wav.n_samples < target_samples && (cycle - start) < deadline_cycles) {
        if (!keyoff_done && wav.n_samples >= target_samples/2) {
            opl3_write(0xb0, 0x12);   // KEY OFF (mismo block/fnum-hi)
            keyoff_done = true;
            fprintf(stderr, "keyoff en sample %u [nl]", wav.n_samples);
        }
        tick();
        if (dut->sample_valid && !prev_valid) {
            auto sx24_to_s16 = [](uint32_t u) -> int16_t {
                int32_t s = (int32_t)(u & 0xFFFFFF);
                if (s & 0x800000) s |= 0xFF000000;
                s >>= 8;
                if (s > 32767) s = 32767;
                if (s < -32768) s = -32768;
                return (int16_t)s;
            };
            wav.push(sx24_to_s16(dut->sample_l), sx24_to_s16(dut->sample_r));
        }
        prev_valid = dut->sample_valid;
    }

    wav.close();
    fprintf(stderr, "captured %u samples in %llu cycles -> %s\n",
            wav.n_samples, (unsigned long long)(cycle - start), out_path);

    delete dut;
    return 0;
}
