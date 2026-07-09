module PINFILTER(
    input clk,
    input reset_n,
    input din,
    output dout
);
    // v3.7 (_50): REESCRITO SIN TRI-STATE. La version original asignaba 1'bz
    // a un reg en cada transicion (d_com ... : 1'bz) y hasta en el reset
    // (d <= 1'bz) — un "keeper" conductual que la sintesis de GW2AR resolvia
    // como HOLD benigno pero la de GW5A puede resolver como constante/dont-
    // care => cadencia 3m6 degradada => enables muertos (el TB con el filtro
    // real reprodujo EXACTO el sintoma del SCC congelado). Mismo contrato de
    // debounce (cambia solo tras 2 muestras coherentes), hold EXPLICITO,
    // reset definido, no-bloqueantes.
    reg [1:0] dpipe;
    reg d;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            d     <= 1'b0;
            dpipe <= 2'b00;
        end else begin
            dpipe <= { dpipe[0], din };
            if (dpipe == 2'b00)
                d <= 1'b0;
            else if (dpipe == 2'b11)
                d <= 1'b1;
            // else: HOLD explicito (transicion en curso)
        end
    end

    assign dout = d;

endmodule
