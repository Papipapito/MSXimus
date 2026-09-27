`timescale 1ns/1ps
// ============================================================================
// tb_g2cmd.sv — el motor de comandos del V9968 (vdp_command.v + vdp_command_cache.v) A SOLAS, con una VRAM de
// 256 KB en palabras de 32 bits (byte 0 en los bits 7:0, como espera la cache). Sin CPU: solo comandos por
// registros (HMMV/HMMM/YMMM/LMMV/LMMM/LINE...). Lo conduce tools/v9968_sim/g2cmd_check.py.
//
// 27/09/2026: nacido para el aviso de la sesion del F1 Spirit V9968: en SCREEN 2 con R#25 CMD=1 (modo "byte",
// direccionado como SCREEN 8) los comandos rapidos HMMM/HMMV/YMMM/HMMC avanzaban 2 bytes por paso (w_next se
// fijaba en "no es SCREEN 8" en vez de en "no es SCREEN 5/6/7") y copiaban un byte si y otro no.
//
// Plusargs: +mode=<indice del bit de screen_mode: 1 = SCREEN 2, 3 = SCREEN 5, 4 = SCREEN 6, 5 = SCREEN 7,
//           6 = SCREEN 8>  +cmden=<R#25 CMD>  +hs=<R#20 high speed>  +ecm=<R#21 V58=0: comandos extendidos>
//           +v256=<VRAM de 256 KB>  +init=<$readmemh de bytes con @direccion>  +cmds=<fichero "W reg hex" / "E">
//           +dump=<salida: 262144 lineas hex>
// ============================================================================
module tb_g2cmd;
    reg clk = 0;
    reg reset_n = 0;
    always #5.82 clk = ~clk;                  // 85.909 MHz

    wire [17:0] a;
    wire        v, w;
    wire [31:0] wd;
    wire [3:0]  wm;
    reg  [31:0] rd;
    reg         rde;
    reg         rw = 0;
    reg  [5:0]  rn = 0;
    reg  [7:0]  rdat = 0;
    wire        ce;
    integer     mode, cmden, hs, ecm, v256;
    reg  [9:0]  screen_mode;

    vdp_command dut (
        .reset_n(reset_n), .clk(clk),
        .command_vram_address(a), .command_vram_valid(v), .command_vram_ready(1'b1),
        .command_vram_write(w), .command_vram_wdata(wd), .command_vram_wdata_mask(wm),
        .command_vram_rdata(rd), .command_vram_rdata_en(rde),
        .register_write(rw), .register_num(rn), .register_data(rdat),
        .clear_border_detect(1'b0), .read_color(1'b0),
        .status_command_execute(ce), .status_border_detect(), .status_transfer_ready(),
        .status_color(), .status_border_position(),
        .screen_mode(screen_mode),
        .vram_interleave(1'b0), .reg_text_back_color(8'd0),
        .reg_command_enable(cmden[0]), .reg_command_high_speed_mode(hs[0]),
        .reg_ext_command_mode(ecm[0]), .reg_vram256k_mode(v256[0]),
        .vram_access_mask(), .intr_command_end()
    );

    reg [31:0] mem [0:65535];
    integer i;
    always @(posedge clk) begin
        rde <= 1'b0;
        if (v) begin
            if (w) begin
                if (!wm[0]) mem[a[17:2]][ 7: 0] <= wd[ 7: 0];
                if (!wm[1]) mem[a[17:2]][15: 8] <= wd[15: 8];
                if (!wm[2]) mem[a[17:2]][23:16] <= wd[23:16];
                if (!wm[3]) mem[a[17:2]][31:24] <= wd[31:24];
            end else begin
                rd  <= mem[a[17:2]];
                rde <= 1'b1;
            end
        end
    end

    reg [8*200-1:0] fcmd, fdump, finit;
    integer fi, fo, r, reg_n, val, cyc, ncmd;
    reg [8*4-1:0] op;
    reg [7:0] bytes [0:262143];

    initial begin
        if (!$value$plusargs("mode=%d",  mode))  mode  = 3;
        if (!$value$plusargs("cmden=%d", cmden)) cmden = 1;
        if (!$value$plusargs("hs=%d",    hs))    hs    = 1;
        if (!$value$plusargs("ecm=%d",   ecm))   ecm   = 1;
        if (!$value$plusargs("v256=%d",  v256))  v256  = 1;
        if (!$value$plusargs("cmds=%s",  fcmd))  fcmd  = "g2_cmds.txt";
        if (!$value$plusargs("init=%s",  finit)) finit = "g2_init.hex";
        if (!$value$plusargs("dump=%s",  fdump)) fdump = "g2_dump.hex";
        screen_mode = 10'd0;
        screen_mode[mode] = 1'b1;
        for (i = 0; i < 65536; i = i + 1) mem[i] = 32'd0;
        for (i = 0; i < 262144; i = i + 1) bytes[i] = 8'hxx;
        $readmemh(finit, bytes);
        for (i = 0; i < 262144; i = i + 1)
            if (bytes[i] !== 8'hxx) mem[i >> 2][8 * (i & 3) +: 8] = bytes[i];
        repeat (4) @(negedge clk);
        reset_n = 1;
        repeat (4) @(negedge clk);

        ncmd = 0;
        fi = $fopen(fcmd, "r");
        while (!$feof(fi)) begin
            r = $fscanf(fi, "%s", op);
            if (r == 1) begin
                if (op[7:0] == "W") begin
                    r = $fscanf(fi, "%d %h", reg_n, val);
                    @(negedge clk); rw = 1; rn = reg_n; rdat = val;
                    @(negedge clk); rw = 0;
                end else if (op[7:0] == "E") begin
                    cyc = 0;
                    @(negedge clk);
                    while (!ce && cyc < 8) begin @(negedge clk); cyc = cyc + 1; end
                    while (ce && cyc < 4000000) begin @(negedge clk); cyc = cyc + 1; end
                    if (ce) $display("TIMEOUT: CE sigue a 1 tras %0d ciclos", cyc);
                    ncmd = ncmd + 1;
                end
            end
        end
        $fclose(fi);
        fo = $fopen(fdump, "w");
        for (i = 0; i < 262144; i = i + 1)
            $fwrite(fo, "%02x\n", mem[i >> 2][8 * (i & 3) +: 8]);
        $fclose(fo);
        $display("tb_g2cmd: modo bit %0d, CMD=%0d, %0d comandos", mode, cmden[0], ncmd);
        $finish;
    end
endmodule
