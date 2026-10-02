#!/usr/bin/env python3
"""
gen_iosys_bram.py - genera fpga/src/iosys/gowin_dpb_menu.v: la BSRAM del overlay YA INICIALIZADA.

V3.8 (01/10/2026): OSD CON COLOR. La BSRAM pasa de 2048 x 8 (DPB) a 2048 x 9 (DPX9B): es la MISMA BSRAM de 18 Kbit,
que en modo x8 tiraba un bit de cada nueve. Ese bit, mas el 7 del caracter (que la fuente de 128 no usa), dan a cada
celda uno de 4 atributos, y cada fila de la pantalla tiene su tabla de 4 {fondo, tinta} de una paleta de 16. Mapa y
glifos en tools/osd_fuente.py. Sin el logo de nand2mario: su hueco ($380-$3FF) es ahora la tabla de atributos.

Salidas:
  fpga/src/iosys/gowin_dpb_menu.v   la BSRAM (DPX9B) con la fuente, los glifos y la tabla de atributos por defecto
  fpga/src/iosys/osd_paleta.v       la paleta (BGR555)
  fpga/src/iosys/osd_glifos.h       G_xxx, C_xxx y la tabla UTF-8 -> codigo, para el firmware del BL616
                                    (firmware-bl616/ui/osd_glifos.h es una copia: --firmware <ruta> la escribe)

Formato de INIT_RAM en x9 (simlib/gw5a/prim_sim.v, DPX9B): la memoria es un vector de 18432 bits, la palabra k ocupa
los bits [9k+8 : 9k] e INIT_RAM_00 son los 288 bits mas bajos; o sea 32 palabras por INIT_RAM, la 0 a la derecha.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import osd_fuente as F  # noqa: E402

BASE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
IOSYS = os.path.join(BASE, "fpga", "src", "iosys")


def memoria():
    mem = [0] * 2048
    for c, filas in enumerate(F.fuente()):
        for r, v in enumerate(filas):
            mem[0x400 + c * 8 + r] = v
    for fila in range(28):
        for a in range(4):
            mem[0x380 + fila * 4 + a] = F.ATRIB_DEFECTO[a]
    # $000-$37F: celdas vacias (codigo 0 = blanco con el atributo 0). El firmware borra y pinta al encender el OSD.
    return mem


def verilog_bsram(mem):
    lin = []
    for k in range(64):
        v = 0
        for j in range(32):
            v |= (mem[k * 32 + j] & 0x1FF) << (9 * j)
        lin.append("defparam dpx9b_inst_0.INIT_RAM_%02X = 288'h%072X;" % (k, v))
    return """// GENERADO por tools/gen_iosys_bram.py -- NO EDITAR A MANO.
// BSRAM del overlay, 2048 x 9 (DPX9B): celdas {atributo[1:0], caracter[6:0]}, tabla de atributos por fila en $380 y
// fuente en $400 (tools/osd_fuente.py). Misma interfaz que el DPB de 8 bits de nand2mario, con un bit mas.

module gowin_dpb_menu (douta, doutb, clka, ocea, cea, reseta, wrea, clkb, oceb, ceb, resetb, wreb, ada, dina, adb, dinb);

output [8:0] douta;
output [8:0] doutb;
input clka;
input ocea;
input cea;
input reseta;
input wrea;
input clkb;
input oceb;
input ceb;
input resetb;
input wreb;
input [10:0] ada;
input [8:0] dina;
input [10:0] adb;
input [8:0] dinb;

wire [8:0] dpx9b_inst_0_douta_w;
wire [8:0] dpx9b_inst_0_doutb_w;
wire gw_gnd;

assign gw_gnd = 1'b0;

DPX9B dpx9b_inst_0 (
    .DOA({dpx9b_inst_0_douta_w[8:0],douta[8:0]}),
    .DOB({dpx9b_inst_0_doutb_w[8:0],doutb[8:0]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,gw_gnd,gw_gnd}),
    .BLKSELB({gw_gnd,gw_gnd,gw_gnd}),
    .ADA({ada[10:0],gw_gnd,gw_gnd,gw_gnd}),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[8:0]}),
    .ADB({adb[10:0],gw_gnd,gw_gnd,gw_gnd}),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[8:0]})
);

defparam dpx9b_inst_0.READ_MODE0 = 1'b0;
defparam dpx9b_inst_0.READ_MODE1 = 1'b0;
defparam dpx9b_inst_0.WRITE_MODE0 = 2'b00;
defparam dpx9b_inst_0.WRITE_MODE1 = 2'b00;
defparam dpx9b_inst_0.BIT_WIDTH_0 = 9;
defparam dpx9b_inst_0.BIT_WIDTH_1 = 9;
defparam dpx9b_inst_0.BLK_SEL_0 = 3'b000;
defparam dpx9b_inst_0.BLK_SEL_1 = 3'b000;
defparam dpx9b_inst_0.RESET_MODE = "SYNC";
""" + "\n".join(lin) + "\n\nendmodule //gowin_dpb_menu\n"


def verilog_paleta():
    t = []
    for campo, cual in (("tinta", 1), ("fondo", 2)):
        t.append("        case (%s)" % ("ti" if campo == "tinta" else "fo"))
        for i, p in enumerate(F.PALETA):
            t.append("            4'd%-2d: %s = 15'h%04X;   // %s" % (i, campo, F.bgr555(p[cual]), p[0]))
        t.append("        endcase")
    return ("// GENERADO por tools/gen_iosys_bram.py (tools/osd_fuente.py) -- NO EDITAR A MANO. Paleta del OSD, BGR555.\n"
            "// Atributo = {fondo[3:0], tinta[3:0]}; el 0 es el aspecto de siempre (tinta amarilla sobre negro).\n"
            "module osd_paleta (input [3:0] ti, input [3:0] fo, output reg [14:0] tinta, output reg [14:0] fondo);\n"
            "    always @* begin\n" + "\n".join(t) + "\n    end\nendmodule\n")


def cabecera_c():
    o = ["/* osd_glifos.h -- GENERADO por MSX_up_v3/tools/gen_iosys_bram.py (tools/osd_fuente.py). NO EDITAR A MANO.",
         " * OSD con color de la V3.8: 32 glifos en 0x01-0x1F y 0x7F, paleta de 16 colores, 4 atributos por fila. */",
         "#pragma once", ""]
    for i, (n, _, _) in enumerate(F.PALETA):
        o.append("#define C_%-10s %2d" % (n, i))
    o.append("#define OSD_A(fondo, tinta) ((uint8_t)(((fondo) << 4) | (tinta)))")
    o.append("")
    for cod, n, _, u in F.GLIFOS:
        o.append("#define G_%-14s 0x%02X   /* %s */" % (n, cod, u))
    o.append("")
    o.append("#ifdef OSD_UTF8_TABLA")
    o.append("static const struct { uint32_t cp; uint8_t g; } osd_utf8[] = {")
    for cod, n, _, u in F.GLIFOS:
        o.append("    { 0x%04X, G_%s }," % (ord(u), n))
    o.append("};")
    o.append("#endif")
    return "\n".join(o) + "\n"


def main():
    mem = memoria()
    open(os.path.join(IOSYS, "gowin_dpb_menu.v"), "w", encoding="utf-8", newline="\n").write(verilog_bsram(mem))
    open(os.path.join(IOSYS, "osd_paleta.v"), "w", encoding="utf-8", newline="\n").write(verilog_paleta())
    h = cabecera_c()
    open(os.path.join(IOSYS, "osd_glifos.h"), "w", encoding="utf-8", newline="\n").write(h)
    if "--firmware" in sys.argv:
        dst = sys.argv[sys.argv.index("--firmware") + 1]
        open(dst, "w", encoding="utf-8", newline="\n").write(h)
        print("OK:", dst)
    print("OK: gowin_dpb_menu.v (2048 x 9), osd_paleta.v, osd_glifos.h; %d palabras no nulas" % sum(1 for v in mem if v))


if __name__ == "__main__":
    main()
