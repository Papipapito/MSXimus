//
// scc_glue.v -- glue de bus del SCC de la megaram (ventana 9800/B800, registro
// de banco 2, strobes req/wrt) EXTRAIDO VERBATIM de top.v v2.6 (rango que iba
// en ~1848-1898). Cero cambios de semantica: solo se parametrizan como
// entradas los terminos de configuracion/slot que viven en top.v
// (config_enable_megaram3/12, pri_slot, exp_slotx_num...), que son
// quasi-estaticos durante el juego.
//
// El motivo de extraerlo a modulo: tools/scc_tb instancia EXACTAMENTE este
// codigo (el mismo .v), asi la simulacion de Icarus y el bitstream comparten
// el glue al byte. El chip (scc_wave2v) se instancia en top.v bajo
// `ifdef ENABLE_SCC, fuera de este modulo, para conservar sin cambios el
// comportamiento actual de la base minima (glue siempre activo, chip fuera).
//
// Dominio: TODO a clk (clk_54m, mismo dominio que el bus del T80, v2.6).
//
module scc_glue (
    input  wire        clk,               // clk_54m (dominio del bus)
    input  wire        reset_n,           // bus_reset_n

    // bus Z80 (dominio clk, cadencia 3.58MHz por clock-enable)
    input  wire [15:0] bus_addr,
    input  wire [7:0]  cpu_dout,
    input  wire        bus_mreq_n,
    input  wire        bus_wr_n,
    input  wire        bus_rd_n,

    // gating de configuracion/slot, identico a los terminos de top.v:
    input  wire        gate_bank2_wr3,    // pri_slot_num[SD_SLOT]==1 && exp_slotx_num[3]==1
    input  wire        gate_bank2_wr12,   // config_enable_megaram12==1 && pri_slot==config_megaram_slot
    input  wire        gate_req3,         // config_enable_megaram3==1 && pri_slot==config_megaram_slot && exp_slotx_num[3]==1
    input  wire        gate_req12,        // config_enable_megaram12==1 && pri_slot==config_megaram_slot

    // modo SCC-I procedente de megaram_scc
    input  wire        scc_mode_plus,     // BFFE bit5: 1 = layout SCC+ activo
    input  wire        sccplus_win_en,    // ventana SCC+ habilitada (bit5 + bank3 bit7)
    input  wire        scc_sound_disable,

    // hacia el chip scc_wave2v y los muxes de top.v
    output wire        scc_req,
    output wire        scc_wrt,
    output wire        scc_req3_r,
    output wire        scc_rd_r,
    output reg         x98h,              // decode registrado (lo comparte el 2o SCC-I)
    output reg         xb8h,
    output wire        dbg_scc_enable     // diagnostico _42dbg: bank2==0x3F (ventana abierta)
);

    always @ (posedge clk) begin   // v2.6: glue SCC a 54M (bus mismo dominio)
        x98h <= ( bus_addr[15:8] == 8'h98 ) ? 1 : 0;
        xb8h <= ( bus_addr[15:8] == 8'hB8 ) ? 1 : 0;
    end

    reg [7:0] scc_bank2;
    reg scc_enable_req3;
    reg scc_enable_req12;
    wire scc_enable_req;
    always @ (posedge clk) begin   // v2.6: glue SCC a 54M (bus mismo dominio)
        scc_enable_req3  <= ( bus_addr[15:11] == 5'b10010 && bus_mreq_n == 0 && bus_wr_n == 0 && gate_bank2_wr3  == 1 ) ? 1 : 0;
        scc_enable_req12 <= ( bus_addr[15:11] == 5'b10010 && bus_mreq_n == 0 && bus_wr_n == 0 && gate_bank2_wr12 == 1 ) ? 1 : 0;
    end
    assign scc_enable_req = scc_enable_req3 | scc_enable_req12;

    always @ (posedge clk or negedge reset_n) begin   // v2.6: glue SCC a 54M (bus mismo dominio)
        if ( reset_n == 0)
            scc_bank2 <= 8'h00;
        else begin
            if (scc_enable_req == 1 ) begin
                scc_bank2 <= cpu_dout;
            end
        end
    end

    wire scc_enable;
    assign scc_enable = ( scc_bank2 == 8'h3f ) ? 1 : 0;
    assign dbg_scc_enable = scc_enable;

    // Sound window: compat = 9800-98FF (bank2==3F, mode bit5=0);
    // SCC+ = B800-B8FF (mode bit5=1 + bank3 bit7, sound not disabled)
    wire scc_win;
    assign scc_win = ( scc_mode_plus == 0 ) ? ( scc_enable & x98h )
                                            : ( sccplus_win_en & xb8h & ~scc_sound_disable );

    reg scc_req3;
    reg scc_req12;
    always @ (posedge clk) begin   // v2.6: glue SCC a 54M (bus mismo dominio)
        scc_req3  <= ( gate_req3  == 1 && scc_win == 1 && bus_mreq_n == 0 && (bus_wr_n == 0 || bus_rd_n == 0 ) ) ? 1 : 0;
        scc_req12 <= ( gate_req12 == 1 && (scc_sound_disable == 0 || scc_mode_plus == 1) && scc_win == 1 && bus_mreq_n == 0 && (bus_wr_n == 0 || bus_rd_n == 0 ) ) ? 1 : 0;
    end
    assign scc_req = scc_req3 | scc_req12;
    assign scc_req3_r = ( scc_req3 == 1 && bus_rd_n == 0 ) ? 1 : 0;
    assign scc_wrt = ( scc_req == 1 && bus_wr_n == 0 ) ? 1 : 0;

    // Wave-RAM read-back (SCC detection by trackers/SCC+ software). Any-window read strobe.
    assign scc_rd_r = ( scc_req == 1 && bus_rd_n == 0 ) ? 1 : 0;

endmodule
