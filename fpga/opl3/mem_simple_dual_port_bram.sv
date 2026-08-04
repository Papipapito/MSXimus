/*******************************************************************************
#
#   FILENAME: mem_simple_dual_port_bram.sv
#
#   DESCRIPTION (MSXimus, era v3):
#   Variante BSRAM de mem_simple_dual_port para OUTPUT_DELAY 1/2. Gowin
#   retiro el SSRAM del GW5AT-60B por un problema de silicio (soporte,
#   03/08/2026) y como flip-flops estas memorias no caben (PR0003). El
#   patron "if (reb) q <= ram[addrb]" es lectura sincrona con enable =
#   BSRAM SDPB con CE, y su semantica es IDENTICA al camino delay>=1 del
#   original (incluida la colision misma direccion/mismo flanco: ambos
#   leen el dato VIEJO — nonblocking alli, read-old aqui).
#
#   Derivado de mem_simple_dual_port.sv de OPL3 FPGA:
#   Copyright (C) 2014 Greg Taylor <gtaylor@sonic.net>, LGPL v3+.
#
#******************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module mem_simple_dual_port_bram #(
    parameter DATA_WIDTH = 0,
    parameter DEPTH = 0,
    parameter OUTPUT_DELAY = 1, // 1 o 2 (el 0 no existe en una BSRAM)
    parameter logic [DATA_WIDTH-1:0] DEFAULT_VALUE = 0
) (
    input wire clka,
    input wire clkb,
    input wire wea,
    input wire reb,
    input wire [$clog2(DEPTH)-1:0] addra,
    input wire [$clog2(DEPTH)-1:0] addrb,
    input wire [DATA_WIDTH-1:0] dia,
    output logic [DATA_WIDTH-1:0] dob
);
    // Anchura >18: se parte en 18b de BSRAM + resto en FF (mismas
    // direcciones, mismo enable). Un SDP de >18 bits consume DOS
    // primitivos (SDP32/36, que ademas el PnR convierte por la advisory
    // 202409001); partido, la parte BSRAM cabe en UN primitivo y el
    // resto son unos pocos FF. Con <=18 bits el generate colapsa al
    // caso simple de un solo array.
    localparam BW = (DATA_WIDTH > 18) ? 18 : DATA_WIDTH;

    (* syn_ramstyle = "block_ram" *)
    logic [BW-1:0] ram [DEPTH-1:0] = '{default: DEFAULT_VALUE[BW-1:0]};

    logic [BW-1:0] q_lo = DEFAULT_VALUE[BW-1:0];

    always_ff @(posedge clka)
        if (wea)
            ram[addra] <= dia[BW-1:0];

    always_ff @(posedge clkb)
        if (reb)
            q_lo <= ram[addrb];

    logic [DATA_WIDTH-1:0] dob_p1;

    generate
    if (DATA_WIDTH > 18) begin : hi_ff
        logic [DATA_WIDTH-1:BW] ram_hi [DEPTH-1:0] = '{default: DEFAULT_VALUE[DATA_WIDTH-1:BW]};
        logic [DATA_WIDTH-1:BW] q_hi = DEFAULT_VALUE[DATA_WIDTH-1:BW];

        always_ff @(posedge clka)
            if (wea)
                ram_hi[addra] <= dia[DATA_WIDTH-1:BW];

        always_ff @(posedge clkb)
            if (reb)
                q_hi <= ram_hi[addrb];

        always_comb dob_p1 = {q_hi, q_lo};
    end
    else
        always_comb dob_p1 = q_lo;
    endgenerate

    generate
    if (OUTPUT_DELAY == 2) begin
        logic [DATA_WIDTH-1:0] dob_p2 = DEFAULT_VALUE;

        always_ff @(posedge clkb)
            dob_p2 <= dob_p1;

        always_comb dob = dob_p2;
    end
    else
        always_comb dob = dob_p1;
    endgenerate
endmodule
`default_nettype wire
