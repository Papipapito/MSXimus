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
    (* syn_ramstyle = "block_ram" *)
    logic [DATA_WIDTH-1:0] ram [DEPTH-1:0] = '{default: DEFAULT_VALUE};

    logic [DATA_WIDTH-1:0] dob_p1 = DEFAULT_VALUE;

    always_ff @(posedge clka)
        if (wea)
            ram[addra] <= dia;

    always_ff @(posedge clkb)
        if (reb)
            dob_p1 <= ram[addrb];

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
