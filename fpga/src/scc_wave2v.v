//
// scc_wave2v.v -- SCC / SCC-I sound core.
// Traduccion 1:1 a Verilog de src/ocm/scc_wave2.vhd (rev 1.00,
// (c)2006 Kazuhiro Tsujikawa / ESE Artists' factory, mod. 2007 t.hara).
// La licencia original (no comercial, ver scc_wave2.vhd) aplica igualmente.
//
// POR QUE EXISTE ESTE FICHERO (port Console 60K / GW5A):
//   La sintesis de Gowin para GW5A BARRE la entity VHDL `scc_wave_mul`
//   (instancia u_mul, scc_wave2.vhd:399) al optimizar:
//       WARN (NL0002): The module "scc_wave_mul" instantiated to "u_mul"
//                      is swept in optimizing (scc_wave2.vhd:399)
//   El aviso aparece x2 (ambas instancias SCC) en TODOS los builds con SCC
//   (_20.._34), con el chip a 27M o a 54M -- por eso los cambios de reloj
//   v2.5/v2.6 no curaron nada. u_mul es el multiplicador onda x volumen que
//   alimenta el mezclador: sin el, ff_mix/ff_wave quedan a 0 y `wave` sale
//   plano (mudo), mientras la wave RAM (camino independiente del producto)
//   sigue leyendo/escribiendo bien -- exactamente el sintoma de placa
//   (readback 9800-987F OK, cero sonido). En el TN20K (GW2AR) el mismo VHDL
//   no se barria y el SCC suena.
//
//   Esta version elimina la frontera de entity: el producto se calcula
//   INLINE con aritmetica signed de Verilog (no queda instancia que barrer)
//   y la wave RAM es un array interno (inferencia estandar). Ademas permite
//   simular el chip con Icarus (tools/scc_tb, ALL TESTS PASS).
//
// Semantica identica al VHDL, incluidas sus particularidades:
//   - `req` puede ser NIVEL (dura todo el ciclo de bus): el acceso se
//     auto-limita a 1 tick con el detector de flanco req & ~ff_req_dl.
//   - El registro de modo (adr xC0-xDF) se escribe por NIVEL de req
//     (re-escrituras del mismo dato: inofensivo), igual que el original.
//   - Cualquier acceso de la ventana escribe/lee la wave RAM (tambien los
//     de registros x80-xBF); las celdas x80-x9F no se reproducen en compat.
//
module scc_wave2v (
    input  wire        clk21m,     // reloj del chip (54M en el port; 21.5/27M en OCM/TN20K)
    input  wire        reset,      // asincrono, activo alto
    input  wire        clkena,     // enable 3.58MHz: 1 tick de clk21m por periodo
    input  wire        req,        // request de la ventana (nivel o pulso)
    output wire        ack,
    input  wire        wrt,        // 1=escritura, 0=lectura (valido con req)
    input  wire [7:0]  adr,
    output reg  [7:0]  dbi,
    input  wire [7:0]  dbo,
    output wire [14:0] wave,
    input  wire        sccplus     // 0 = SCC compat (regs x80-x9F, ch.E espejo de ch.D)
                                   // 1 = SCC+ (ch.E onda propia en x80-x9F, regs xA0-xBF)
);

    // ---- registros SCC ----
    reg  [11:0] reg_freq_ch_a, reg_freq_ch_b, reg_freq_ch_c, reg_freq_ch_d, reg_freq_ch_e;
    reg  [3:0]  reg_vol_ch_a,  reg_vol_ch_b,  reg_vol_ch_c,  reg_vol_ch_d,  reg_vol_ch_e;
    reg  [4:0]  reg_ch_sel;
    reg  [7:0]  reg_mode_sel;

    // ---- registros internos ----
    reg         ff_rst_ch_a, ff_rst_ch_b, ff_rst_ch_c, ff_rst_ch_d, ff_rst_ch_e;
    reg  [4:0]  ff_ptr_ch_a, ff_ptr_ch_b, ff_ptr_ch_c, ff_ptr_ch_d, ff_ptr_ch_e;
    reg  [11:0] ff_cnt_ch_a, ff_cnt_ch_b, ff_cnt_ch_c, ff_cnt_ch_d, ff_cnt_ch_e; // (variables en el VHDL)
    reg  [2:0]  ff_ch_num, ff_ch_num_dl;
    reg  [14:0] ff_mix;
    reg         ff_wave_ce, ff_wave_ce_dl;
    reg         ff_req_dl;
    reg  [7:0]  ff_wave_dat;
    reg  [14:0] ff_wave;

    // ----------------------------------------------------------------
    // acceso a registros SCC (flanco de req, como el VHDL)
    // ----------------------------------------------------------------
    wire reg_wr_hit = ( req == 1'b1 && ff_req_dl == 1'b0 && wrt == 1'b1 &&
                        ( (sccplus == 1'b0 && adr[7:5] == 3'b100) ||     // compat: 9880-989F
                          (sccplus == 1'b1 && adr[7:5] == 3'b101) ) );   // SCC+:   B8A0-B8BF

    always @(posedge clk21m or posedge reset) begin
        if (reset) begin
            ff_req_dl     <= 1'b0;
            reg_freq_ch_a <= 12'd0;  reg_freq_ch_b <= 12'd0;  reg_freq_ch_c <= 12'd0;
            reg_freq_ch_d <= 12'd0;  reg_freq_ch_e <= 12'd0;
            reg_vol_ch_a  <= 4'd0;   reg_vol_ch_b  <= 4'd0;   reg_vol_ch_c  <= 4'd0;
            reg_vol_ch_d  <= 4'd0;   reg_vol_ch_e  <= 4'd0;
            reg_ch_sel    <= 5'd0;
            reg_mode_sel  <= 8'd0;
            ff_rst_ch_a   <= 1'b0;   ff_rst_ch_b   <= 1'b0;   ff_rst_ch_c   <= 1'b0;
            ff_rst_ch_d   <= 1'b0;   ff_rst_ch_e   <= 1'b0;
        end
        else begin
            if (reg_wr_hit) begin
                case (adr[3:0])
                    4'b0000: begin reg_freq_ch_a[ 7:0] <= dbo[7:0]; ff_rst_ch_a <= reg_mode_sel[5]; end
                    4'b0001: begin reg_freq_ch_a[11:8] <= dbo[3:0]; ff_rst_ch_a <= reg_mode_sel[5]; end
                    4'b0010: begin reg_freq_ch_b[ 7:0] <= dbo[7:0]; ff_rst_ch_b <= reg_mode_sel[5]; end
                    4'b0011: begin reg_freq_ch_b[11:8] <= dbo[3:0]; ff_rst_ch_b <= reg_mode_sel[5]; end
                    4'b0100: begin reg_freq_ch_c[ 7:0] <= dbo[7:0]; ff_rst_ch_c <= reg_mode_sel[5]; end
                    4'b0101: begin reg_freq_ch_c[11:8] <= dbo[3:0]; ff_rst_ch_c <= reg_mode_sel[5]; end
                    4'b0110: begin reg_freq_ch_d[ 7:0] <= dbo[7:0]; ff_rst_ch_d <= reg_mode_sel[5]; end
                    4'b0111: begin reg_freq_ch_d[11:8] <= dbo[3:0]; ff_rst_ch_d <= reg_mode_sel[5]; end
                    4'b1000: begin reg_freq_ch_e[ 7:0] <= dbo[7:0]; ff_rst_ch_e <= reg_mode_sel[5]; end
                    4'b1001: begin reg_freq_ch_e[11:8] <= dbo[3:0]; ff_rst_ch_e <= reg_mode_sel[5]; end
                    4'b1010: reg_vol_ch_a <= dbo[3:0];
                    4'b1011: reg_vol_ch_b <= dbo[3:0];
                    4'b1100: reg_vol_ch_c <= dbo[3:0];
                    4'b1101: reg_vol_ch_d <= dbo[3:0];
                    4'b1110: reg_vol_ch_e <= dbo[3:0];
                    default: reg_ch_sel   <= dbo[4:0];      // xxxx=1111: canal on/off
                endcase
            end
            else if (clkena) begin
                ff_rst_ch_a <= 1'b0;
                ff_rst_ch_b <= 1'b0;
                ff_rst_ch_c <= 1'b0;
                ff_rst_ch_d <= 1'b0;
                ff_rst_ch_e <= 1'b0;
            end

            // registro de modo/deformacion en adr xC0-xDF (nivel de req, como el VHDL)
            if (req == 1'b1 && wrt == 1'b1 && adr[7:5] == 3'b110)
                reg_mode_sel <= dbo;

            ff_req_dl <= req;
        end
    end

    // acceso CPU a la wave RAM: 1 solo tick por ciclo de bus (flanco de req)
    wire w_wave_ce = ( req == 1'b1 && ff_req_dl == 1'b0 );
    wire w_wave_we = ( w_wave_ce ) ? wrt : 1'b0;
    assign ack = ff_req_dl;

    // ----------------------------------------------------------------
    // generador de tono (avanza bajo clkena = 3.58MHz)
    // ----------------------------------------------------------------
    always @(posedge clk21m or posedge reset) begin
        if (reset) begin
            ff_cnt_ch_a <= 12'd0; ff_cnt_ch_b <= 12'd0; ff_cnt_ch_c <= 12'd0;
            ff_cnt_ch_d <= 12'd0; ff_cnt_ch_e <= 12'd0;
            ff_ptr_ch_a <= 5'd0;  ff_ptr_ch_b <= 5'd0;  ff_ptr_ch_c <= 5'd0;
            ff_ptr_ch_d <= 5'd0;  ff_ptr_ch_e <= 5'd0;
        end
        else if (clkena) begin
            if (reg_freq_ch_a[11:3] == 9'd0 || ff_rst_ch_a) begin
                ff_ptr_ch_a <= 5'd0;
                ff_cnt_ch_a <= reg_freq_ch_a;
            end else if (ff_cnt_ch_a == 12'h000) begin
                ff_ptr_ch_a <= ff_ptr_ch_a + 5'd1;
                ff_cnt_ch_a <= reg_freq_ch_a;
            end else
                ff_cnt_ch_a <= ff_cnt_ch_a - 12'd1;

            if (reg_freq_ch_b[11:3] == 9'd0 || ff_rst_ch_b) begin
                ff_ptr_ch_b <= 5'd0;
                ff_cnt_ch_b <= reg_freq_ch_b;
            end else if (ff_cnt_ch_b == 12'h000) begin
                ff_ptr_ch_b <= ff_ptr_ch_b + 5'd1;
                ff_cnt_ch_b <= reg_freq_ch_b;
            end else
                ff_cnt_ch_b <= ff_cnt_ch_b - 12'd1;

            if (reg_freq_ch_c[11:3] == 9'd0 || ff_rst_ch_c) begin
                ff_ptr_ch_c <= 5'd0;
                ff_cnt_ch_c <= reg_freq_ch_c;
            end else if (ff_cnt_ch_c == 12'h000) begin
                ff_ptr_ch_c <= ff_ptr_ch_c + 5'd1;
                ff_cnt_ch_c <= reg_freq_ch_c;
            end else
                ff_cnt_ch_c <= ff_cnt_ch_c - 12'd1;

            if (reg_freq_ch_d[11:3] == 9'd0 || ff_rst_ch_d) begin
                ff_ptr_ch_d <= 5'd0;
                ff_cnt_ch_d <= reg_freq_ch_d;
            end else if (ff_cnt_ch_d == 12'h000) begin
                ff_ptr_ch_d <= ff_ptr_ch_d + 5'd1;
                ff_cnt_ch_d <= reg_freq_ch_d;
            end else
                ff_cnt_ch_d <= ff_cnt_ch_d - 12'd1;

            if (reg_freq_ch_e[11:3] == 9'd0 || ff_rst_ch_e) begin
                ff_ptr_ch_e <= 5'd0;
                ff_cnt_ch_e <= reg_freq_ch_e;
            end else if (ff_cnt_ch_e == 12'h000) begin
                ff_ptr_ch_e <= ff_ptr_ch_e + 5'd1;
                ff_cnt_ch_e <= reg_freq_ch_e;
            end else
                ff_cnt_ch_e <= ff_cnt_ch_e - 12'd1;
        end
    end

    // ----------------------------------------------------------------
    // control de la wave RAM
    // ----------------------------------------------------------------
    wire [7:0] w_wave_adr =
        ( w_wave_ce )            ? adr                   :
        ( ff_ch_num == 3'b000 )  ? {3'b000, ff_ptr_ch_a} :
        ( ff_ch_num == 3'b001 )  ? {3'b001, ff_ptr_ch_b} :
        ( ff_ch_num == 3'b010 )  ? {3'b010, ff_ptr_ch_c} :
        ( ff_ch_num == 3'b011 )  ? {3'b011, ff_ptr_ch_d} :
        ( sccplus )              ? {3'b100, ff_ptr_ch_e} :   // SCC+: ch.E onda propia
                                   {3'b011, ff_ptr_ch_e};    // compat: ch.E espejo de ch.D

    // 256x8: escritura sincrona, direccion de lectura registrada + lectura
    // combinacional (misma semantica que la entity `ram` de ram.vhd que usaba
    // el VHDL). Interna al modulo: no hay instancia separada.
    reg [7:0] wave_ram [0:255];
    reg [7:0] ram_iadr;
    always @(posedge clk21m) begin
        if (w_wave_we)
            wave_ram[w_wave_adr] <= dbo;
        ram_iadr <= w_wave_adr;
    end
    wire [7:0] ram_dbi = wave_ram[ram_iadr];

    //  lectura de la wave RAM hacia el bus
    always @(posedge clk21m or posedge reset) begin
        if (reset)
            dbi <= 8'hFF;
        else if (ff_wave_ce)
            dbi <= ram_dbi;
    end

    // ----------------------------------------------------------------
    // señales retardadas (pipeline del mezclador, ver cronograma del VHDL)
    // ----------------------------------------------------------------
    always @(posedge clk21m or posedge reset) begin
        if (reset) begin
            ff_wave_ce    <= 1'b0;
            ff_wave_ce_dl <= 1'b0;
            ff_wave_dat   <= 8'd0;
            ff_ch_num_dl  <= 3'd0;
        end else begin
            ff_wave_ce    <= w_wave_ce;
            ff_wave_ce_dl <= ff_wave_ce;
            ff_wave_dat   <= ram_dbi;
            ff_ch_num_dl  <= ff_ch_num;
        end
    end

    // ----------------------------------------------------------------
    // control del mezclador
    // ----------------------------------------------------------------
    reg [4:0] w_ch_dec;
    always @* begin
        case (ff_ch_num_dl)
            3'b001:  w_ch_dec = 5'b00001;
            3'b010:  w_ch_dec = 5'b00010;
            3'b011:  w_ch_dec = 5'b00100;
            3'b100:  w_ch_dec = 5'b01000;
            3'b101:  w_ch_dec = 5'b10000;
            default: w_ch_dec = 5'b00000;
        endcase
    end

    wire       w_ch_bit  = |(w_ch_dec & reg_ch_sel);
    wire [7:0] w_ch_mask = {8{w_ch_bit}};

    reg [3:0] w_ch_vol;
    always @* begin
        case (ff_ch_num_dl)
            3'b001:  w_ch_vol = reg_vol_ch_a;
            3'b010:  w_ch_vol = reg_vol_ch_b;
            3'b011:  w_ch_vol = reg_vol_ch_c;
            3'b100:  w_ch_vol = reg_vol_ch_d;
            3'b101:  w_ch_vol = reg_vol_ch_e;
            default: w_ch_vol = 4'd0;
        endcase
    end

    wire [7:0] w_wave = w_ch_mask & ff_wave_dat;     // muestra 8bit compl. a 2

    // ==== EL FIX: producto onda x volumen INLINE ====
    // (antes: entity scc_wave_mul / instancia u_mul, que la sintesis GW5A
    //  barria dejando el SCC mudo). 8bit signed x 4bit unsigned:
    //  |max| = 128*15 = 1920 < 2048 -> cabe exacto en 12 bits signed;
    //  el recorte [11:0] es identico al c <= w_mul(11 downto 0) del VHDL.
    wire signed [12:0] w_mul_full = $signed(w_wave) * $signed({1'b0, w_ch_vol});
    wire [11:0]        w_mul      = w_mul_full[11:0];

    // contador de canal (se congela 1 tick tras un acceso de CPU)
    always @(posedge clk21m or posedge reset) begin
        if (reset)
            ff_ch_num <= 3'b000;
        else if (ff_wave_ce == 1'b0) begin
            if (ff_ch_num == 3'b101)
                ff_ch_num <= 3'b000;
            else
                ff_ch_num <= ff_ch_num + 3'd1;
        end
    end

    //  mezclador: acumula A..E (15bit compl. a 2; 5*1920 = 9600 < 16384)
    always @(posedge clk21m or posedge reset) begin
        if (reset)
            ff_mix <= 15'd0;
        else if (ff_wave_ce_dl == 1'b0) begin
            if (ff_ch_num_dl == 3'b000)
                ff_mix <= 15'd0;
            else
                ff_mix <= { {3{w_mul[11]}}, w_mul } + ff_mix;
        end
    end

    //  salida
    always @(posedge clk21m or posedge reset) begin
        if (reset)
            ff_wave <= 15'd0;
        else if (ff_wave_ce_dl == 1'b0 && ff_ch_num_dl == 3'b000)
            ff_wave <= ff_mix;
    end

    assign wave = ff_wave;

endmodule
