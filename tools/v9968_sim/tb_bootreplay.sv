// ============================================================================
// tb_bootreplay.sv — replay del protocolo VDP REAL trazado en openMSX
// (V9958 de referencia, maquina FS-A1WSX) contra la pila v2.1 del MSXimus:
// vdp (85.9 MHz) + v9968_vram_shim + SDRAM con latencia variable, calcada de
// tb_cmdghost.sv.
//
// Estimulo: fichero de ops (gen_stim.py sobre fleet_vdp2.log):
//   W <p> <hex>  escritura puerto (1=0x99 2=0x9A 3=0x9B)
//   R            lectura unica de 0x99 (descarta)
//   P <ms>       poll: leer 0x99 hasta bit0(CE)==0; <ms> = duracion V9958
//                real; si se agota el margen -> *** CUELGUE REPRODUCIDO ***
//   G <us>       pausa
//   M <txt>      marcador
// Ventanas del estimulo: tormenta LINE/PSET del logo (violaciones de
// protocolo: lanzamientos con CE=1), tormenta LMMC con preload de R#44 +
// streaming a ciegas por 0x9B, y fase de juego de Fleet (LMMM/HMMM/YMMM con
// bloque de args por 0x9B AI + lanzamiento con CE=1).
// Al final: comando sonda HMMV para comprobar que el motor sigue VIVO.
// ============================================================================
`timescale 1ns/1ps

module tb_bootreplay;

localparam real CLK_HALF = 5.8207;

logic reset_n = 0;
logic clk = 0;
always #(CLK_HALF) clk = ~clk;

logic [2:0]  bus_address = 0;
logic        bus_write = 0;
logic        bus_ioreq = 0, bus_valid = 0;
logic [7:0]  bus_wdata = 0;

wire  [7:0]  bus_rdata;
wire         bus_rdata_en, bus_ready, int_n;
wire  [17:2] vaddr;
wire         vwrite, vvalid, vrefresh;
wire  [31:0] vwdata;
wire  [3:0]  vmask;
wire  [4:0]  vtag;
wire  [31:0] vrdata;
wire         vrdata_en;
wire  [4:0]  vrtag;
wire         vstall;
wire         d_hs, d_vs, d_en;
wire  [7:0]  d_r, d_g, d_b;

vdp u_vdp (
    .reset_n(reset_n), .clk(clk), .initial_busy(1'b0),
    .bus_address(bus_address), .bus_ioreq(bus_ioreq), .bus_write(bus_write),
    .bus_valid(bus_valid), .bus_ready(bus_ready),
    .bus_wdata(bus_wdata), .bus_rdata(bus_rdata), .bus_rdata_en(bus_rdata_en),
    .int_n(int_n),
    .vram_address(vaddr), .vram_write(vwrite),
    .vram_valid(vvalid), .vram_wdata(vwdata),
    .vram_wdata_mask(vmask),
    .vram_rdata(vrdata), .vram_rdata_en(vrdata_en),
    .vram_tag(vtag), .vram_rtag(vrtag),
    .vram_stall(vstall),
    .vram_refresh(vrefresh),
    .display_hs(d_hs), .display_vs(d_vs), .display_en(d_en),
    .display_r(d_r), .display_g(d_g), .display_b(d_b),
    .force_highspeed(1'b0), .button(2'b00),
    .pulse0(), .pulse1(), .pulse2(), .pulse3(),
    .pulse4(), .pulse5(), .pulse6(), .pulse7()
);

wire        bk_req, bk_we;
wire [21:0] bk_addr;
wire [31:0] bk_wdata;
wire [3:0]  bk_wmask;
logic [15:0] bk_rword = 0;
logic        bk_done_t = 0;
wire [7:0]  shim_diag;
wire        bk2_req;
wire [21:0] bk2_addr;
logic [15:0] bk2_rword = 0;
logic        bk2_done_t = 0;

v9968_vram_shim #(.VRAM_BASE(22'h280000)) u_shim (
    .clk_vdp(clk), .rst_n(reset_n),
    .vram_address(vaddr), .vram_write(vwrite),
    .vram_valid(vvalid), .vram_wdata(vwdata),
    .vram_wdata_mask(vmask), .vram_tag(vtag),
    .vram_rdata(vrdata), .vram_rdata_en(vrdata_en),
    .vram_rtag(vrtag),
    .vram_stall(vstall),
    .bk_req(bk_req), .bk_we(bk_we), .bk_addr(bk_addr), .bk_wdata(bk_wdata),
    .bk_wmask(bk_wmask),
    .bk_rword(bk_rword), .bk_done_t(bk_done_t),
    .bk2_req(bk2_req), .bk2_addr(bk2_addr),
    .bk2_rword(bk2_rword), .bk2_done_t(bk2_done_t),
    .diag(shim_diag)
);

logic [7:0] sdram [0:4194303];
logic        m_pend = 0, m_we;
logic [21:0] m_addr;
logic [31:0] m_dat;
logic [3:0]  m_msk;
integer      m_cnt, m_lat;
always @(posedge clk) begin
    if (bk_req && !m_pend) begin
        m_pend <= 1; m_we <= bk_we; m_addr <= bk_addr; m_dat <= bk_wdata;
        m_msk <= bk_wmask;
        m_cnt <= 0; m_lat <= 26 + ({$random} % 18);
    end
    else if (m_pend) begin
        m_cnt <= m_cnt + 1;
        if (m_cnt == m_lat) begin
            if (m_we) begin
                if (m_msk[0]) sdram[{m_addr[21:2],2'b00}] <= m_dat[ 7: 0];
                if (m_msk[1]) sdram[{m_addr[21:2],2'b01}] <= m_dat[15: 8];
                if (m_msk[2]) sdram[{m_addr[21:2],2'b10}] <= m_dat[23:16];
                if (m_msk[3]) sdram[{m_addr[21:2],2'b11}] <= m_dat[31:24];
            end
            else begin
                bk_rword[7:0]  <= sdram[{m_addr[21:1],1'b0}];
                bk_rword[15:8] <= sdram[{m_addr[21:1],1'b1}];
            end
            bk_done_t <= ~bk_done_t;
            m_pend <= 0;
        end
    end
end
logic        m2_pend = 0;
logic [21:0] m2_addr;
integer      m2_cnt, m2_lat;
always @(posedge clk) begin
    if (bk2_req && !m2_pend) begin
        m2_pend <= 1; m2_addr <= bk2_addr;
        m2_cnt <= 0; m2_lat <= 26 + ({$random} % 18);
    end
    else if (m2_pend) begin
        m2_cnt <= m2_cnt + 1;
        if (m2_cnt == m2_lat) begin
            bk2_rword[7:0]  <= sdram[{m2_addr[21:1],1'b0}];
            bk2_rword[15:8] <= sdram[{m2_addr[21:1],1'b1}];
            bk2_done_t <= ~bk2_done_t;
            m2_pend <= 0;
        end
    end
end

integer vi;
initial begin
    for (vi = 0; vi < 4194304; vi = vi + 1) sdram[vi] = 8'h00;
end

// ---------------- tareas de bus (disciplina negedge de tb_cpu_bulk) --------
integer op_n = 0;
task bus_wr(input [2:0] a, input [7:0] d);
begin
    op_n = op_n + 1;
    @(negedge clk);
    bus_address = a; bus_wdata = d; bus_write = 1;
    bus_ioreq = 1; bus_valid = 0;
    @(negedge clk);
    while (!bus_ready) @(negedge clk);
    bus_valid = 1;
    @(negedge clk);
    bus_valid = 0; bus_ioreq = 0; bus_write = 0;
    repeat (2) @(negedge clk);
end
endtask
task bus_rd(input [2:0] a, output [7:0] d);
begin
    op_n = op_n + 1;
    @(negedge clk);
    bus_address = a; bus_write = 0;
    bus_ioreq = 1; bus_valid = 0;
    @(negedge clk);
    while (!bus_ready) @(negedge clk);
    bus_valid = 1;
    @(negedge clk);
    bus_valid = 0; bus_ioreq = 0;
    while (!bus_rdata_en) @(negedge clk);
    d = bus_rdata;
    repeat (2) @(negedge clk);
end
endtask

// paso Z80: suelo de ~3.4 us entre OUT y OUT (12 T-states @ 3.58 MHz)
task z80_gap;
begin
    repeat (280) @(negedge clk);
end
endtask

// contadores del handshake LMMC/HMMC: bytes que la CPU escribio en R#44 vs
// bytes que el motor consumio (entradas a c_state_lmmc_make=27 / hmmc "make"
// via c_state_hmmc=13->salida). El descuadre es la firma del byte perdido.
integer n_wr44 = 0;
integer n_consumo = 0;
logic [5:0] st_d = 0;
always @(posedge clk) begin
    st_d <= u_vdp.u_command.ff_state;
    if (u_vdp.u_command.register_write && u_vdp.u_command.register_num == 6'd44)
        n_wr44 <= n_wr44 + 1;
    // lmmc_make (27) se entra una vez por byte LMMC; para HMMC cuenta la
    // salida de c_state_hmmc (13) hacia otra cosa con escritura lanzada
    if (u_vdp.u_command.ff_state == 6'd27 && st_d != 6'd27)
        n_consumo <= n_consumo + 1;
    if (st_d == 6'd13 && u_vdp.u_command.ff_state != 6'd13 &&
        u_vdp.u_command.ff_command == 4'b1111)
        n_consumo <= n_consumo + 1;
end

task volcado_estado(input [1023:0] motivo);
begin
    $display("---- RADIOGRAFIA (%0s) op=%0d ----", motivo, op_i);
    $display("  motor: state=%0d cmd=%h CE=%b start=%b TR=%b flushstart=%b",
        u_vdp.u_command.ff_state, u_vdp.u_command.ff_command,
        u_vdp.u_command.ff_command_execute, u_vdp.u_command.ff_start,
        u_vdp.u_command.ff_transfer_ready, u_vdp.u_command.ff_cache_flush_start);
    $display("  motor: nx=%0d ny=%0d dx=%0d dy=%0d vram_valid=%b vram_wr=%b",
        u_vdp.u_command.ff_nx, u_vdp.u_command.ff_ny,
        u_vdp.u_command.ff_dx, u_vdp.u_command.ff_dy,
        u_vdp.u_command.ff_cache_vram_valid, u_vdp.u_command.ff_cache_vram_write);
    $display("  cache: busy=%b flush_state=%0d vram_valid=%b ready=%b rdata_en=%b",
        u_vdp.u_command.u_cache.ff_busy,
        u_vdp.u_command.u_cache.ff_flush_state,
        u_vdp.u_command.u_cache.ff_vram_valid,
        u_vdp.u_command.w_cache_vram_ready,
        u_vdp.u_command.u_cache.ff_cache_vram_rdata_en);
    $display("  handshake: R#44 escritos=%0d consumidos=%0d (descuadre=%0d)",
        n_wr44, n_consumo, n_wr44 - n_consumo);
end
endtask

// ---------------- lector de estimulo ----------------
integer fh, code, op_i, port, hexv, gap_us, poll_ms, poll_max, pr, snap_ext;
logic [63:0] snap, snap2;
logic [7:0]  rb;
logic [8*16-1:0]  tok;
logic [8*250-1:0] mtxt;
integer cuelgues = 0;
integer marker_n = 0;

initial begin
    repeat (50) @(posedge clk);
    reset_n = 1;
    repeat (2000) @(posedge clk);

    if (!$value$plusargs("stim=%s", mtxt)) mtxt = "fleet_ops.txt";
    fh = $fopen(mtxt, "r");
    if (fh == 0) begin
        $display("*** NO PUEDO ABRIR EL ESTIMULO %0s", mtxt);
        $finish;
    end
    $display("REPLAY EMPIEZA (estimulo %0s)", mtxt);

    op_i = 0;
    while (!$feof(fh)) begin
        code = $fscanf(fh, " %s", tok);
        if (code != 1) begin
            code = $fgetc(fh);  // consume basura/EOF
        end
        else begin
            op_i = op_i + 1;
            case (tok[7:0])
            "W": begin
                code = $fscanf(fh, " %d %h", port, hexv);
                bus_wr(port[2:0], hexv[7:0]);
                // ritmo Z80 real: pares por 0x99 a ~3.5us (OUT a 12-14 T),
                // streaming por 0x9B a ~6.5us (OTIR, 23 T)
                if (port == 3) repeat (560) @(negedge clk);
                else            z80_gap;
            end
            "R": begin
                bus_rd(3'd1, rb);
                z80_gap;
            end
            "P": begin
                code = $fscanf(fh, " %d", poll_ms);
                // presupuesto por TIEMPO de sim: 5 ms + 4x la duracion V9958
                // real; lecturas paceadas a ~5us => max_iters = presupuesto/5us
                // ⚠ los P de bucles con flip de R#15 quedan aislados (dur=1ms),
                // asi que un comando largo (YMMM 60ms) agotaria el presupuesto
                // con el motor SANO. Solo es cuelgue si ADEMAS los contadores
                // del motor no se mueven durante toda una ventana: deteccion
                // de progreso con snapshot {state,nx,ny,dx,dy}, hasta 60
                // extensiones (~600 ms de sim).
                poll_max = (5 + 4 * poll_ms) * 195;
                if (poll_max < 2000) poll_max = 2000;
                pr = 0;
                snap_ext = 0;
                snap = {u_vdp.u_command.ff_state, u_vdp.u_command.ff_nx,
                        u_vdp.u_command.ff_ny, u_vdp.u_command.ff_dx,
                        u_vdp.u_command.ff_dy};
                rb = 8'hFF;
                while ((rb & 8'h01) != 0 && pr < poll_max) begin
                    bus_rd(3'd1, rb);
                    pr = pr + 1;
                    if ((rb & 8'h01) != 0) repeat (420) @(negedge clk);
                    if (pr == poll_max && (rb & 8'h01) != 0 && snap_ext < 60) begin
                        snap2 = {u_vdp.u_command.ff_state, u_vdp.u_command.ff_nx,
                                 u_vdp.u_command.ff_ny, u_vdp.u_command.ff_dx,
                                 u_vdp.u_command.ff_dy};
                        if (snap2 != snap) begin
                            // el motor PROGRESA: extender la espera
                            snap = snap2;
                            snap_ext = snap_ext + 1;
                            pr = 0;
                        end
                    end
                end
                if ((rb & 8'h01) != 0) begin
                    cuelgues = cuelgues + 1;
                    $display("*** CUELGUE REPRODUCIDO op=%0d (poll de %0d ms reales, %0d lecturas, S#2=%02x)",
                             op_i, poll_ms, pr, rb);
                    volcado_estado("CUELGUE");
                    if (cuelgues >= 3) begin
                        $display("*** 3 cuelgues: abandono el replay");
                        $finish;
                    end
                end
            end
            "G": begin
                code = $fscanf(fh, " %d", gap_us);
                repeat (gap_us * 86) @(negedge clk);
            end
            "M": begin
                code = $fscanf(fh, " %s", mtxt);
                marker_n = marker_n + 1;
                $display("== MARCA %0d: %0s (op=%0d t=%0t)", marker_n, mtxt, op_i, $time);
            end
            default: begin
                $display("?? token raro '%0s' op=%0d", tok, op_i);
            end
            endcase
            if ((op_i % 2000) == 0) begin
                $display(".. progreso op=%0d t=%0t CE=%b state=%0d", op_i, $time,
                         u_vdp.u_command.ff_command_execute, u_vdp.u_command.ff_state);
            end
        end
    end
    $fclose(fh);

    $display("REPLAY COMPLETO op=%0d cuelgues=%0d", op_i, cuelgues);

    // ---- sonda final: HMMV 16x1 en (0,200) — ¿sigue vivo el motor? ----
    bus_wr(3'd1, 8'd0);   bus_wr(3'd1, 8'hA4);   // R#36
    bus_wr(3'd1, 8'd0);   bus_wr(3'd1, 8'hA5);
    bus_wr(3'd1, 8'd200); bus_wr(3'd1, 8'hA6);   // R#38 DY=200
    bus_wr(3'd1, 8'd0);   bus_wr(3'd1, 8'hA7);
    bus_wr(3'd1, 8'd16);  bus_wr(3'd1, 8'hA8);   // NX=16
    bus_wr(3'd1, 8'd0);   bus_wr(3'd1, 8'hA9);
    bus_wr(3'd1, 8'd1);   bus_wr(3'd1, 8'hAA);   // NY=1
    bus_wr(3'd1, 8'd0);   bus_wr(3'd1, 8'hAB);
    bus_wr(3'd1, 8'hEE);  bus_wr(3'd1, 8'hAC);   // CLR
    bus_wr(3'd1, 8'h00);  bus_wr(3'd1, 8'hAD);   // ARG
    bus_wr(3'd1, 8'h02);  bus_wr(3'd1, 8'h8F);   // R#15=2
    bus_wr(3'd1, 8'hC0);  bus_wr(3'd1, 8'hAE);   // HMMV
    pr = 0;
    rb = 8'hFF;
    while ((rb & 8'h01) != 0 && pr < 60000) begin
        bus_rd(3'd1, rb);
        pr = pr + 1;
    end
    if ((rb & 8'h01) != 0) begin
        $display("*** SONDA FINAL: el motor NO responde (S#2=%02x tras %0d lecturas)", rb, pr);
        volcado_estado("SONDA_MUERTA");
        $display("*** BOOTREPLAY: CUELGUE (sonda final)");
    end
    else if (cuelgues != 0) begin
        $display("*** BOOTREPLAY: CUELGUE (%0d polls agotados)", cuelgues);
    end
    else begin
        $display("*** BOOTREPLAY: OK (motor vivo, 0 cuelgues)");
    end
    #1000;
    $finish;
end

// progreso de vida + timeout global
integer beat = 0;
always @(posedge clk) begin
    beat <= beat + 1;
    if (beat % 20000000 == 0 && beat != 0)
        $display("~~ latido ciclo=%0d op=%0d state=%0d CE=%b", beat, op_i,
                 u_vdp.u_command.ff_state, u_vdp.u_command.ff_command_execute);
end
initial begin
    repeat (4000) #1000000;   // 4 s de sim
    $display("TIMEOUT GLOBAL op=%0d", op_i);
    volcado_estado("TIMEOUT_GLOBAL");
    $display("*** BOOTREPLAY: TIMEOUT");
    $finish;
end

endmodule
