// ============================================================================
// tb_spcold.sv — DEPURADOR del 5S fantasma (_187b): FASES C y D de tb_spcol
// con CHIVATO en el instante exacto en que se arma ff_sprite_overmap.
// Imprime plano, cuentas, finish, frescura, atributo y posicion de pantalla
// en cada disparo (limitado a los primeros 40).
// Uso: vvp sim [+VMODE=2|5]
// ============================================================================
`timescale 1ns/1ps

module tb_spcold;

localparam real CLK_HALF = 5.8207;
localparam real TSTATE   = 279.33;

logic reset_n = 0;
logic clk = 0;
always #(CLK_HALF) clk = ~clk;

wire [2:0]  bus_address;
wire        bus_ioreq, bus_write, bus_valid;
wire [7:0]  bus_wdata;
wire [7:0]  bus_rdata;
wire        bus_rdata_en, bus_ready;

logic       csw_n = 1'b1, csr_n = 1'b1;
logic [1:0] z_mode = 2'd0;
logic [7:0] z_cdo  = 8'd0;
wire  [7:0] z_cdi;
wire        g_wait_n;

v9968_cpu_glue u_glue (
    .clk_86(clk), .rst_n(reset_n),
    .csw_n(csw_n), .csr_n(csr_n), .mode(z_mode), .cdo(z_cdo), .cdi_r(z_cdi),
    .wait_n(g_wait_n),
    .bus_address(bus_address), .bus_ioreq(bus_ioreq), .bus_write(bus_write),
    .bus_valid(bus_valid), .bus_ready(bus_ready), .bus_wdata(bus_wdata),
    .bus_rdata(bus_rdata), .bus_rdata_en(bus_rdata_en)
);

wire        int_n;
wire [17:2] vaddr;
wire        vwrite, vvalid, vrefresh;
wire [31:0] vwdata;
wire [3:0]  vmask;
wire [4:0]  vtag;
wire [31:0] vrdata;
wire        vrdata_en;
wire [4:0]  vrtag;
wire        vstall;
wire        d_hs, d_vs, d_en;
wire [7:0]  d_r, d_g, d_b;

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

task z80_out(input [1:0] m, input [7:0] d);
begin
    z_mode = m; z_cdo = d;
    #(TSTATE);
    csw_n = 1'b0;
    #(1.5*TSTATE);
    while (g_wait_n == 1'b0) #(TSTATE);
    #(1.5*TSTATE);
    csw_n = 1'b1;
    #(8.0*TSTATE);
end
endtask

task z80_in(input [1:0] m, output [7:0] d);
begin
    z_mode = m;
    #(TSTATE);
    csr_n = 1'b0;
    #(1.5*TSTATE);
    while (g_wait_n == 1'b0) #(TSTATE);
    #(1.0*TSTATE);
    d = z_cdi;
    #(0.5*TSTATE);
    csr_n = 1'b1;
    #(8.0*TSTATE);
end
endtask

task vdp_reg(input [5:0] r, input [7:0] d);
begin z80_out(2'd1, d); z80_out(2'd1, {2'b10, r}); end
endtask

task vram_set_wr(input [17:0] a);
begin
    vdp_reg(6'd14, {5'd0, a[16:14]});
    z80_out(2'd1, a[7:0]);
    z80_out(2'd1, {2'b01, a[13:8]});
end
endtask

task espera_frames(input integer n);
integer f;
begin
    for (f = 0; f < n; f = f + 1) begin
        @(posedge d_vs);
    end
    #100000;
end
endtask

task lee_s0(output [7:0] v);
begin
    z80_out(2'd1, 8'h00); z80_out(2'd1, 8'h8F);
    z80_in (2'd1, v);
end
endtask

// ------------------- EL CHIVATO -------------------
integer nov = 0;
wire dbg_ovm = u_vdp.u_timing_control.u_sprite.u_select_visible_planes.ff_sprite_overmap;
logic dbg_ovm_d = 0;
always @(posedge clk) begin
    dbg_ovm_d <= dbg_ovm;
    if (dbg_ovm && !dbg_ovm_d && nov < 40) begin
        nov = nov + 1;
        $display("OVM#%0d t=%0t id=%0d plane=%0d pcount=%0d scount=%0d finish=%b fresh1=%b fresh2=%b cfull=%b sfull=%b inv=%b attr=%08x w_y=%0d | posx=%04x(px=%0d ph=%0d sub=%0d) posy=%0d pixy=%0d",
            nov, $time,
            u_vdp.u_timing_control.u_sprite.u_select_visible_planes.ff_sprite_overmap_id,
            u_vdp.u_timing_control.u_sprite.u_select_visible_planes.ff_current_plane_num,
            u_vdp.u_timing_control.u_sprite.u_select_visible_planes.ff_plane_count,
            u_vdp.u_timing_control.u_sprite.u_select_visible_planes.ff_selected_count,
            u_vdp.u_timing_control.u_sprite.u_select_visible_planes.ff_select_finish,
            u_vdp.u_timing_control.u_sprite.u_select_visible_planes.ff_att1_fresh,
            u_vdp.u_timing_control.u_sprite.u_select_visible_planes.ff_att2_fresh,
            u_vdp.u_timing_control.u_sprite.u_select_visible_planes.w_count_full,
            u_vdp.u_timing_control.u_sprite.u_select_visible_planes.w_selected_full,
            u_vdp.u_timing_control.u_sprite.u_select_visible_planes.w_invisible,
            u_vdp.u_timing_control.u_sprite.u_select_visible_planes.w_attribute,
            u_vdp.u_timing_control.u_sprite.u_select_visible_planes.w_y,
            u_vdp.u_timing_control.u_sprite.u_select_visible_planes.screen_pos_x,
            u_vdp.u_timing_control.u_sprite.u_select_visible_planes.screen_pos_x[13:4],
            u_vdp.u_timing_control.u_sprite.u_select_visible_planes.screen_pos_x[6:4],
            u_vdp.u_timing_control.u_sprite.u_select_visible_planes.screen_pos_x[3:0],
            u_vdp.u_timing_control.u_sprite.u_select_visible_planes.screen_pos_y,
            u_vdp.u_timing_control.u_sprite.u_select_visible_planes.pixel_pos_y);
    end
end

// ---------------------------------------------------------------------------
integer VMODE = 2;
integer i, n5s, ncol;
logic [7:0] v;

task sat_plane(input [7:0] y, input [7:0] x, input [7:0] pat);
begin
    z80_out(2'd0, y); z80_out(2'd0, x); z80_out(2'd0, pat);
    z80_out(2'd0, (VMODE == 2) ? 8'd15 : 8'd0);
end
endtask

initial begin
    if( !$value$plusargs("VMODE=%d", VMODE) ) VMODE = 2;

    repeat (48) @(posedge clk);
    reset_n = 1;
    repeat (48) @(posedge clk);
    $display("=== tb_spcold (depurador _187b): VMODE=%0d ===", VMODE);

    if (VMODE == 2) begin
        vdp_reg(6'd0, 8'h02);
        vdp_reg(6'd2, 8'h06);
        vdp_reg(6'd3, 8'hFF);
        vdp_reg(6'd4, 8'h03);
        vdp_reg(6'd5, 8'h36);
        vdp_reg(6'd6, 8'h07);
        vdp_reg(6'd1, 8'h40);
    end
    else begin
        vdp_reg(6'd0, 8'h06);
        vdp_reg(6'd2, 8'h1F);
        vdp_reg(6'd5, 8'hEF);
        vdp_reg(6'd11, 8'h00);
        vdp_reg(6'd6, 8'h07);
        vdp_reg(6'd1, 8'h40);
    end

    vram_set_wr(18'h03800);
    for (i = 0; i < 8; i = i + 1) z80_out(2'd0, 8'hFF);

    // FASE C
    begin
        integer cupo;
        cupo = (VMODE == 2) ? 4 : 8;
        if (VMODE != 2) begin
            vram_set_wr(18'h07400);
            for (i = 0; i < 512; i = i + 1) z80_out(2'd0, 8'h0F);
        end
        vram_set_wr((VMODE == 2) ? 18'h01B00 : 18'h07600);
        for (i = 0; i < 32; i = i + 1) begin
            if (i < cupo) sat_plane(8'd59, 8'd10 + i[7:0]*8'd24, 8'd0);
            else          sat_plane(8'd220, 8'd0, 8'd0);
        end
        lee_s0(v); lee_s0(v);
        espera_frames(2);
        $display("--- FASE C armada (cupo=%0d) — muestras:", cupo);
        n5s = 0;
        for (i = 0; i < 3; i = i + 1) begin
            lee_s0(v);
            $display("  S#0=%02x", v);
            if (v[6]) n5s = n5s + 1;
            espera_frames(1);
        end
        $display("FASE C: 5S=1 en %0d/3 (esperado 0)", n5s);
    end

    // FASE D
    begin
        vram_set_wr((VMODE == 2) ? 18'h01B00 : 18'h07600);
        for (i = 0; i < 30; i = i + 1) sat_plane(8'd220, 8'd0, 8'd0);
        sat_plane(8'd99, 8'd100, 8'd0);
        sat_plane(8'd99, 8'd104, 8'd0);
        lee_s0(v); lee_s0(v);
        espera_frames(2);
        $display("--- FASE D armada — muestras:");
        n5s = 0; ncol = 0;
        for (i = 0; i < 3; i = i + 1) begin
            lee_s0(v);
            $display("  S#0=%02x", v);
            if (v[6]) n5s = n5s + 1;
            if (v[5]) ncol = ncol + 1;
            espera_frames(1);
        end
        $display("FASE D: 5S=1 en %0d/3 (esperado 0), C=1 en %0d/3 (esperado 3)", n5s, ncol);
    end

    $finish;
end

endmodule
