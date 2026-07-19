//============================================================================
// ro_osc.v — Oscilador en anillo + contador (termometro del die, MSXimus 60K)
//
// Anillo de STAGES NANDs (impar) en fabric: con ro_en=1 oscila a una
// frecuencia que CAE con la temperatura del die (~0.1%/grado); con ro_en=0
// el anillo se congela (todas las etapas a 1) y el contador queda estatico
// para leerlo sin cruce de dominios. Las etapas son LUT2 explicitas con
// syn_keep: al ser un LAZO con enable de registro, la sintesis no puede
// plegarlas como hizo con los buffers de paso (leccion _120c).
//
// El contador vive en el dominio del anillo; SOLO debe leerse/limpiarse con
// el anillo parado (lo garantiza el FSM de fan_ctrl.v).
//============================================================================
module ro_osc #(
    parameter STAGES = 8               // latches en el lazo (paridad da igual:
                                       // la inversion la pone el LUT1)
)(
    input  wire        ro_en,          // 1 = anillo corriendo
    input  wire        cnt_rst,       // limpiar contador (con anillo parado)
    output wire [19:0] cnt_out
);

    // El anillo NO puede ser de LUTs puras: GowinSynthesis detecta el lazo
    // combinacional (AG0100) y lo ELIMINA por completo, ignorando syn_keep y
    // syn_noprune (verificado empiricamente: 0 instancias en el .vg). El lazo
    // se cierra a traves de LATCHES TRANSPARENTES (DLCE): son celulas
    // secuenciales, la sintesis no las atraviesa ni puede quitar el inversor
    // del lazo sin cambiar la funcion. Con G=ro_en los latches ademas hacen
    // de enable: ro_en=0 -> retienen -> anillo congelado y contador estable.
    wire [STAGES:0] n;

`ifdef __ICARUS__
    genvar gi;
    generate
        for (gi = 0; gi < STAGES; gi = gi + 1) begin : g_ring
            reg q;
            always @(*) if (ro_en) q = #1 n[gi];   // latch transparente
            assign n[gi+1] = q;
        end
    endgenerate
    // inversor del lazo en sim
    wire inv_out;
    assign #1 inv_out = ~n[STAGES];
`else
    genvar gi;
    generate
        for (gi = 0; gi < STAGES; gi = gi + 1) begin : g_ring
            DLCE u_lat (
                .Q     (n[gi+1]),
                .D     (n[gi]),
                .G     (ro_en),
                .GE    (1'b1),
                .CLEAR (1'b0)
            );
        end
    endgenerate
`endif

    // inversion del lazo: un LUT1 entre el ultimo latch y el primero
    // (en un lazo de celulas secuenciales no es eliminable)
`ifdef __ICARUS__
    assign n[0] = inv_out;
`else
    LUT1 #(.INIT(2'b01)) u_inv (.F(n[0]), .I0(n[STAGES]));
`endif

    wire ro_clk = n[STAGES];

    reg [19:0] c = 20'd0;
    always @(posedge ro_clk or posedge cnt_rst) begin
        if (cnt_rst) c <= 20'd0;
        else         c <= c + 20'd1;
    end
    assign cnt_out = c;

endmodule
