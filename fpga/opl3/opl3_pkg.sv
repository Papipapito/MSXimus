//
// opl3_pkg_mangopl4.sv
//
// MangOPL4 — copia local del package opl3_pkg de gtaylormb/opl3_fpga con
// CLK_FREQ y CLK_DIV_COUNT recalculados para el reloj de 33.5625 MHz que
// alimentamos al core (134.25 MHz / 4 vía CLKDIV en board_wt200b_clock.sv).
// El upstream usa 12.727 MHz porque está pensado para un Zybo con DAC SSM2603
// y oversampling fijo 256x. Nosotros usamos un reloj más alto y un divisor
// mayor para obtener una sample rate ≈49.502 kHz (-0.03% respecto los
// 49.516 kHz nominales del MoonSound real, inaudible).
//
// El upstream `opl3_pkg.sv` se EXCLUYE del .gprj — este archivo es el único
// `package opl3_pkg` que se compila.
//
// Original LGPL-3.0:
//   Copyright (C) 2014 Greg Taylor <gtaylor@sonic.net>
// Cambios MangOPL4:
//   Copyright (C) 2026 Jokin Miragaia <tech.fxmedia@gmail.com>
// LGPL-3.0
//
`timescale 1ns / 1ps
`default_nettype none

package opl3_pkg;
    // MangOPL4: 134.25 MHz / 4 = 33.5625 MHz (CLKDIV en u_div_opl3)
    localparam CLK_FREQ = 27e6; // MSXimus _84: clk_27m del PLLA principal (hermano del bus: CDC emparentado, sin 3er PLL)
    localparam DAC_OUTPUT_WIDTH = 24;
    localparam INSTANTIATE_TIMERS = 1; // MangOPL4: ON para detección OPL3 (Timer1+Timer2 + status bits)
    localparam NUM_LEDS = 4; // connected to kon bank 0 starting at 0
    localparam INSTANTIATE_SAMPLE_SYNC_TO_DAC_CLK = 0;

    // MangOPL4: 33.5625 MHz / 678 ≈ 49.502 kHz (vs 49.516 kHz MoonSound nominal)
    localparam DESIRED_SAMPLE_FREQ = 49.516e3;
    localparam CLK_DIV_COUNT = 545; // 27e6/545 = 49541 Hz (+0.05% vs 49516 nominal)
    localparam ACTUAL_SAMPLE_FREQ = CLK_FREQ/CLK_DIV_COUNT;

    localparam NUM_REG_PER_BANK = 'hF6;
    localparam REG_FILE_DATA_WIDTH = 8;
    localparam REG_TIMER_WIDTH = 8;
    localparam REG_CONNECTION_SEL_WIDTH = 6;
    localparam REG_MULT_WIDTH = 4;
    localparam REG_FNUM_WIDTH = 10;
    localparam REG_BLOCK_WIDTH = 3;
    localparam REG_WS_WIDTH = 3;
    localparam REG_ENV_WIDTH = 4;
    localparam REG_TL_WIDTH = 6;
    localparam REG_KSL_WIDTH = 2;
    localparam REG_FB_WIDTH = 3;

    localparam SAMPLE_WIDTH = 16;
    localparam DAC_LEFT_SHIFT = signed'(DAC_OUTPUT_WIDTH - SAMPLE_WIDTH - 2) < 0 ? 0 : DAC_OUTPUT_WIDTH - SAMPLE_WIDTH - 3;
    localparam FINAL_ENV_WIDTH = 11;
    localparam OP_OUT_WIDTH = 13;
    localparam PHASE_ACC_WIDTH = 20;
    localparam PHASE_FINAL_WIDTH = 10;
    localparam VIB_VAL_WIDTH = REG_FNUM_WIDTH - 7;
    localparam ENV_SHIFT_WIDTH = 2;
    localparam TREMOLO_MAX_COUNT = 13*1024;
    localparam TREMOLO_INDEX_WIDTH = $clog2(TREMOLO_MAX_COUNT);
    localparam AM_VAL_WIDTH = TREMOLO_INDEX_WIDTH - 8;
    localparam KSL_ADD_WIDTH = 8;

    localparam NUM_BANKS = 2;
    localparam NUM_OPERATORS_PER_BANK = 18;
    localparam NUM_CHANNELS_PER_BANK = 9;
    localparam BANK_NUM_WIDTH = $clog2(NUM_BANKS);
    localparam OP_NUM_WIDTH = $clog2(NUM_OPERATORS_PER_BANK);

    localparam TIMER1_TICK_INTERVAL = 80e-6;  // in seconds
    localparam TIMER2_TICK_INTERVAL = 320e-6; // in seconds

    // mangopl4: TICK_COUNT precomputado como entero. Gowin trunca mal
    // CLK_FREQ*TIMER_TICK_INTERVAL (WARN EX3791 size 64→32) dando un
    // valor erróneo, lo que ralentiza Timer1 ~30x y rompe la base de
    // tiempo de VGMPlay-MSX (música reproduce muy lenta).
    // 33.5625e6 Hz * 80e-6 s = 2685 ; * 320e-6 = 10740
    localparam int TIMER1_TICK_COUNT = 2160;  // 80us a 27MHz EXACTO
    localparam int TIMER2_TICK_COUNT = 8640;  // 320us a 27MHz EXACTO

    typedef enum logic [2:0] {
        OP_NORMAL,
        OP_BASS_DRUM,
        OP_HI_HAT,
        OP_TOM_TOM,
        OP_SNARE_DRUM,
        OP_TOP_CYMBAL
    } operator_t;

    typedef struct packed {
        logic valid;
        logic bank_num;
        logic [REG_FILE_DATA_WIDTH-1:0] address;
        logic [REG_FILE_DATA_WIDTH-1:0] data;
    } opl3_reg_wr_t;

    typedef struct packed {
        logic valid;
        logic bank_num;
        logic [$clog2(NUM_OPERATORS_PER_BANK)-1:0] op_num;
        logic signed [OP_OUT_WIDTH-1:0] op_out;
    } operator_out_t;

endpackage
`default_nettype wire
