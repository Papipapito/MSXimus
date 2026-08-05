// tb_intswallow — _188: ¿se traga el RTL una INT cuando el evento coincide
// con el ciclo de una lectura de status? Lógica VIEJA (cadena if/else de
// vdp_cpu_interface) y NUEVA (_188 paralelo set-dominante) lado a lado.
`timescale 1ns/1ps
module tb_intswallow;

logic clk = 0; always #5.82 clk = ~clk;
logic reset_n = 0;
logic w_read = 0, w_write = 0, ff_port1 = 0, ff_port4 = 0;
logic [3:0] ptr = 0;
logic [7:0] wdata = 0;
logic intr_frame = 0, intr_line = 0, intr_command_end = 0;
logic clear_line_interrupt = 0, ff_register_write = 0;
logic [5:0] ff_register_num = 0;

// ==== VIEJA (verbatim en estructura) ====
reg oF=0, oL=0, oC=0;
always @(posedge clk) begin
    if (!reset_n) begin oF<=0; oL<=0; oC<=0; end
    else if (w_read && ff_port1) begin
        if (ptr == 4'd0)      oF <= 1'b0;
        else if (ptr == 4'd1) oL <= 1'b0;
    end
    else if (w_write && ff_port4) begin
        if (wdata[0]) oF <= 1'b0;
        if (wdata[1]) oL <= 1'b0;
        if (wdata[2]) oC <= 1'b0;
    end
    else begin
        if (intr_frame) oF <= 1'b1;
        if (clear_line_interrupt || intr_frame) oL <= 1'b0;
        else if (ff_register_write && (ff_register_num==6'd0 || ff_register_num==6'd19)) oL <= 1'b0;
        else if (intr_line) oL <= 1'b1;
        if (intr_command_end) oC <= 1'b1;
    end
end

// ==== NUEVA (_188) ====
reg nF=0, nL=0, nC=0;
always @(posedge clk) begin
    if (!reset_n) begin nF<=0; nL<=0; nC<=0; end
    else begin
        if (intr_frame) nF <= 1'b1;
        else if ((w_read && ff_port1 && ptr==4'd0) || (w_write && ff_port4 && wdata[0])) nF <= 1'b0;

        if (clear_line_interrupt || intr_frame) nL <= 1'b0;
        else if (intr_line) nL <= 1'b1;
        else if ((w_read && ff_port1 && ptr==4'd1) || (w_write && ff_port4 && wdata[1])
              || (ff_register_write && (ff_register_num==6'd0 || ff_register_num==6'd19))) nL <= 1'b0;

        if (intr_command_end) nC <= 1'b1;
        else if (w_write && ff_port4 && wdata[2]) nC <= 1'b0;
    end
end

integer fallos = 0;
task chk(input string nom, input exp_oF_igual, input vF_esp);
begin
    #1;
    $display("  %-46s VIEJA F=%b  NUEVA F=%b  (silicio=%b)%s", nom, oF, nF, vF_esp,
             (nF !== vF_esp) ? "  *** NUEVA MAL ***" : (oF !== vF_esp) ? "  <- la vieja PIERDE el evento" : "");
    if (nF !== vF_esp) fallos = fallos + 1;
end
endtask

task limpiar;   // deja F=0 en las dos, sin colision
begin
    @(negedge clk); w_read=1; ff_port1=1; ptr=0;
    @(negedge clk); w_read=0; ff_port1=0;
    @(negedge clk);
end
endtask

initial begin
    repeat(4) @(negedge clk); reset_n = 1; repeat(2) @(negedge clk);

    // 1) set normal sin colision
    intr_frame=1; @(negedge clk); intr_frame=0;
    chk("1. set normal (sin lectura)", 1, 1'b1);
    limpiar();
    chk("   ... y clear normal", 1, 1'b0);

    // 2) LA COLISION: intr_frame en el MISMO ciclo que la lectura de S#0
    intr_frame=1; w_read=1; ff_port1=1; ptr=0;
    @(negedge clk); intr_frame=0; w_read=0; ff_port1=0;
    chk("2. evento vs lectura-S#0 (mismo ciclo)", 0, 1'b1);
    limpiar();

    // 3) EL APAGON: intr_frame durante una lectura de S#2 (el poll de Fleet)
    intr_frame=1; w_read=1; ff_port1=1; ptr=2;
    @(negedge clk); intr_frame=0; w_read=0; ff_port1=0;
    chk("3. evento vs lectura-S#2 (apagon del poll)", 0, 1'b1);
    limpiar();

    // 4) apagon via puerto 4 (escritura sin bits de clear)
    intr_frame=1; w_write=1; ff_port4=1; wdata=8'h00;
    @(negedge clk); intr_frame=0; w_write=0; ff_port4=0;
    chk("4. evento vs escritura-puerto4 (bits=0)", 0, 1'b1);
    limpiar();

    // 5) clear legitimo del puerto 4 SIN evento
    intr_frame=1; @(negedge clk); intr_frame=0;
    w_write=1; ff_port4=1; wdata=8'h01;
    @(negedge clk); w_write=0; ff_port4=0; wdata=0;
    chk("5. clear puerto4 bit0 (sin evento)", 1, 1'b0);

    // 6) linea: intr_line vs lectura-S#1 (misma familia)
    intr_line=1; w_read=1; ff_port1=1; ptr=1;
    @(negedge clk); intr_line=0; w_read=0; ff_port1=0;
    #1; $display("  6. line vs lectura-S#1: VIEJA FH=%b NUEVA FH=%b (silicio=1)%s", oL, nL,
                 (nL!==1'b1)?"  *** NUEVA MAL ***":(oL!==1'b1)?"  <- la vieja PIERDE el evento":"");
    if (nL !== 1'b1) fallos = fallos + 1;

    // 7) orden hardware conservado: clear_line_interrupt gana a intr_line
    clear_line_interrupt=1; intr_line=1;
    @(negedge clk); clear_line_interrupt=0; intr_line=0;
    #1; $display("  7. clear_line_hw vs intr_line: VIEJA FH=%b NUEVA FH=%b (upstream=0)%s", oL, nL,
                 (nL!==1'b0)?"  *** NUEVA MAL ***":"");
    if (nL !== 1'b0) fallos = fallos + 1;

    if (fallos == 0) $display("##### _188 VERDE: la nueva iguala al silicio en los 7 casos #####");
    else             $display("##### _188: %0d FALLOS #####", fallos);
    $finish;
end
endmodule
