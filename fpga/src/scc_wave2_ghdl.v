// ============================================================================
// scc_wave2_ghdl.v -- SCC / SCC-I sound core (GENERADO, no editar a mano).
//
// Verilog producido por GHDL a partir del VHDL original, para esquivar el
// frontend VHDL de la sintesis de Gowin en GW5A (que miscompila este fichero
// en silencio: entity barrida NL0002 + al menos una miscompilacion muda mas).
// Gowin solo ve Verilog; GHDL (que interpreta el VHDL correctamente) hace la
// conversion.
//
// Fuentes:
//   fpga/src/ocm/scc_wave2.vhd            (md5 3a952ffdc27ea84e77f4d30c72fd7f95)
//   fpga/tn_vdp_v3_v9958/src/ram.vhd      (md5 4b07b17365c24cdf624b4cafad86fbeb, solo entity 'ram')
//
// Herramienta:
//   GHDL 6.0.0 (6.0.0.r0.ge589c698c) [Dunoon edition], mcode,
//   binario release ghdl-mcode-6.0.0-ubuntu24.04-x86_64.tar.gz (WSL).
//
// Comandos exactos:
//   ghdl -a       -fsynopsys -fexplicit --std=93c ram.vhd scc_wave2.vhd
//   ghdl --synth  --out=verilog -fsynopsys -fexplicit --std=93c scc_wave2 \
//        > scc_wave2_ghdl.v
//
// Modulos generados:
//   scc_wave2   -- top, MISMO nombre y port map que la entity VHDL, con los
//                  puertos de debug:
//                   _46dbg: dbg_vol_nz / dbg_sel_nz / dbg_freq_nz
//                   _49dbg: dbg_ptr_lsb  = ff_ptr_ch_a(0), togglea en CADA
//                           avance del puntero ch.A (440Hz -> cuadrada
//                           ~7 kHz, duty 50%)
//                   _51dbg: dbg_scan_lsb = ff_ch_num(0), escaneo de canales
//                           a reloj pleno (vivo = cuadrada clk/2 = 13.5 MHz
//                           a 27M, duty ~50%; congelado = nivel fijo)
//                           dbg_mix_nz   = ff_mix /= 0 (con tono ~80% duty;
//                           mixer muerto = 0%)
//   ram_Brtl    -- la wave RAM 256x8 (entity 'ram', arquitectura RTL);
//                  el sufijo _Brtl lo pone GHDL => NO colisiona con la
//                  entity VHDL 'ram' de ram.vhd si esta sigue en el proyecto
//
// INTEGRACION (build.tcl): al añadir este fichero hay que QUITAR
//   src/ocm/scc_wave2.vhd  del proyecto (si no, design unit 'scc_wave2'
//   duplicada VHDL/Verilog). ram.vhd puede quedarse (palette_rb/palette_g).
//
// Validado con Icarus Verilog 12:
//   tools/scc_tb/run_ghdl.sh  -- mismos 21 checks que el TB de scc_wave2v
//   tools/scc_tb/run_cen27.sh -- TB con el camino REAL de clk_enable_3m6_27
//     (div30@108M -> PINFILTER@54M -> cadena 8FF@27M -> edge detect, replica
//     verbatim de top.v:240-328) y chip a clk_27m: 21 checks + checks de
//     avance del puntero (N1), escaneo vivo (N2) y acumulador activo (N3)
//     con las sondas dbg_ptr_lsb / dbg_scan_lsb / dbg_mix_nz calibradas.
//
// Notas de estilo del netlist GHDL (revisadas):
//   - FF: always @(posedge clk21m or posedge reset) con if/else -> DFF con
//     reset asincrono estandar, sin latches.
//   - Combinacional: assign + always @* con case y default en todos los
//     decodificadores; los 5 always @* sin default son copias incondicionales
//     de una sola linea (espejo de las VHDL variables ff_cnt_ch_*).
//   - 5 bloques 'initial <reg> = 12'bX': inicializacion X SOLO de simulacion
//     de esos espejos; la sintesis los ignora (don't care).
//   - 1 multiplicador: assign $signed(a) * $signed(b) // smul (el producto
//     onda x volumen del FIX, ya inline, sin frontera de entity que barrer).
//
// Licencia: derivado de scc_wave.vhd (c)2006 Kazuhiro Tsujikawa (ESE Artists'
// factory), mod. 2007 t.hara. La licencia original (no comercial) aplica.
// ============================================================================

module ram_Brtl
  (input  [7:0] adr,
   input  clk,
   input  we,
   input  [7:0] dbo,
   output [7:0] dbi);
  wire [7:0] iadr;
  reg [7:0] n596;
  wire [7:0] n597; // mem_rd
  assign dbi = n597; //(module output)
  /*# ram.vhd:50:10 */
  assign iadr = n596; // (signal)
  /*# ram.vhd:56:5 */
  always @(posedge clk)
    n596 <= adr;
  reg [7:0] blkram[255:0] ; // memory
  assign n597 = blkram[iadr];
  always @(posedge clk)
    if (we)
      blkram[adr] <= dbo;
  /*# ram.vhd:64:17 */
  /*# ram.vhd:58:16 */
endmodule

module scc_wave2
  (input  clk21m,
   input  reset,
   input  clkena,
   input  req,
   output ack,
   input  wrt,
   input  [7:0] adr,
   output [7:0] dbi,
   input  [7:0] dbo,
   output [14:0] wave,
   input  sccplus,
   output dbg_vol_nz,
   output dbg_sel_nz,
   output dbg_freq_nz,
   output dbg_ptr_lsb,
   output dbg_scan_lsb,
   output dbg_mix_nz);
  wire w_wave_ce;
  wire w_wave_we;
  wire [7:0] w_wave_adr;
  wire [4:0] w_ch_dec;
  wire w_ch_bit;
  wire [7:0] w_ch_mask;
  wire [3:0] w_ch_vol;
  wire [7:0] w_wave;
  wire [11:0] w_mul;
  wire [12:0] w_mul_s;
  wire [7:0] ram_dbi;
  wire [11:0] reg_freq_ch_a;
  wire [11:0] reg_freq_ch_b;
  wire [11:0] reg_freq_ch_c;
  wire [11:0] reg_freq_ch_d;
  wire [11:0] reg_freq_ch_e;
  wire [3:0] reg_vol_ch_a;
  wire [3:0] reg_vol_ch_b;
  wire [3:0] reg_vol_ch_c;
  wire [3:0] reg_vol_ch_d;
  wire [3:0] reg_vol_ch_e;
  wire [4:0] reg_ch_sel;
  wire [7:0] reg_mode_sel;
  wire ff_rst_ch_a;
  wire ff_rst_ch_b;
  wire ff_rst_ch_c;
  wire ff_rst_ch_d;
  wire ff_rst_ch_e;
  wire [4:0] ff_ptr_ch_a;
  wire [4:0] ff_ptr_ch_b;
  wire [4:0] ff_ptr_ch_c;
  wire [4:0] ff_ptr_ch_d;
  wire [4:0] ff_ptr_ch_e;
  wire [2:0] ff_ch_num;
  wire [2:0] ff_ch_num_dl;
  wire [14:0] ff_mix;
  wire ff_wave_ce;
  wire ff_wave_ce_dl;
  wire ff_req_dl;
  wire [7:0] ff_wave_dat;
  wire [14:0] ff_wave;
  wire n12;
  wire n13;
  wire n14;
  wire n15;
  wire [2:0] n16;
  wire n18;
  wire n19;
  wire [2:0] n20;
  wire n22;
  wire n23;
  wire n24;
  wire n25;
  wire [3:0] n26;
  wire n27;
  wire n29;
  wire [3:0] n30;
  wire n31;
  wire n33;
  wire n34;
  wire n36;
  wire [3:0] n37;
  wire n38;
  wire n40;
  wire n41;
  wire n43;
  wire [3:0] n44;
  wire n45;
  wire n47;
  wire n48;
  wire n50;
  wire [3:0] n51;
  wire n52;
  wire n54;
  wire n55;
  wire n57;
  wire [3:0] n58;
  wire n59;
  wire n61;
  wire [3:0] n62;
  wire n64;
  wire [3:0] n65;
  wire n67;
  wire [3:0] n68;
  wire n70;
  wire [3:0] n71;
  wire n73;
  wire [3:0] n74;
  wire n76;
  wire [4:0] n77;
  wire [14:0] n78;
  wire [7:0] n79;
  reg [7:0] n80;
  wire [3:0] n81;
  reg [3:0] n82;
  wire [7:0] n83;
  reg [7:0] n84;
  wire [3:0] n85;
  reg [3:0] n86;
  wire [7:0] n87;
  reg [7:0] n88;
  wire [3:0] n89;
  reg [3:0] n90;
  wire [7:0] n91;
  reg [7:0] n92;
  wire [3:0] n93;
  reg [3:0] n94;
  wire [7:0] n95;
  reg [7:0] n96;
  wire [3:0] n97;
  reg [3:0] n98;
  reg [3:0] n99;
  reg [3:0] n100;
  reg [3:0] n101;
  reg [3:0] n102;
  reg [3:0] n103;
  reg [4:0] n104;
  reg n105;
  reg n106;
  reg n107;
  reg n108;
  reg n109;
  wire n111;
  wire n113;
  wire n115;
  wire n117;
  wire n119;
  wire [11:0] n120;
  wire [11:0] n122;
  wire [11:0] n124;
  wire [11:0] n126;
  wire [11:0] n128;
  wire n136;
  wire n137;
  wire n138;
  wire n139;
  wire n140;
  wire n141;
  wire [2:0] n142;
  wire n144;
  wire n145;
  wire n203;
  wire n204;
  wire n205;
  wire n207;
  wire n208;
  wire n209;
  wire n213;
  wire n214;
  wire n218;
  wire n219;
  wire n223;
  wire n224;
  wire n226;
  wire n227;
  wire n230;
  wire n231;
  reg [11:0] n233_ff_cnt_ch_a;
  reg [11:0] n233_ff_cnt_ch_b;
  reg [11:0] n233_ff_cnt_ch_c;
  reg [11:0] n233_ff_cnt_ch_d;
  reg [11:0] n233_ff_cnt_ch_e;
  wire [8:0] n241;
  wire n243;
  wire n244;
  wire n246;
  wire [4:0] n248;
  wire [11:0] n250;
  wire [4:0] n251;
  wire [11:0] n252;
  wire [4:0] n254;
  wire [11:0] n255;
  wire [8:0] n256;
  wire n258;
  wire n259;
  wire n261;
  wire [4:0] n263;
  wire [11:0] n265;
  wire [4:0] n266;
  wire [11:0] n267;
  wire [4:0] n269;
  wire [11:0] n270;
  wire [8:0] n271;
  wire n273;
  wire n274;
  wire n276;
  wire [4:0] n278;
  wire [11:0] n280;
  wire [4:0] n281;
  wire [11:0] n282;
  wire [4:0] n284;
  wire [11:0] n285;
  wire [8:0] n286;
  wire n288;
  wire n289;
  wire n291;
  wire [4:0] n293;
  wire [11:0] n295;
  wire [4:0] n296;
  wire [11:0] n297;
  wire [4:0] n299;
  wire [11:0] n300;
  wire [8:0] n301;
  wire n303;
  wire n304;
  wire n306;
  wire [4:0] n308;
  wire [11:0] n310;
  wire [4:0] n311;
  wire [11:0] n312;
  wire [4:0] n314;
  wire [11:0] n315;
  wire [7:0] n357;
  wire [7:0] n359;
  wire n361;
  wire [7:0] n362;
  wire [7:0] n364;
  wire n366;
  wire [7:0] n367;
  wire [7:0] n369;
  wire n371;
  wire [7:0] n372;
  wire [7:0] n374;
  wire n376;
  wire [7:0] n377;
  wire [7:0] n379;
  wire [7:0] n380;
  wire [7:0] n382;
  wire [7:0] wavemem_n383;
  wire n412;
  wire n415;
  wire n418;
  wire n421;
  wire n424;
  wire [4:0] n426;
  reg [4:0] n427;
  wire n428;
  wire n429;
  wire n430;
  wire n431;
  wire n432;
  wire n433;
  wire n434;
  wire n435;
  wire n436;
  wire n437;
  wire n438;
  wire n439;
  wire n440;
  wire n441;
  wire n442;
  wire n443;
  wire n444;
  wire n445;
  wire n446;
  wire [7:0] n447;
  wire n449;
  wire n451;
  wire n453;
  wire n455;
  wire n457;
  wire [4:0] n459;
  reg [3:0] n460;
  wire [7:0] n461;
  wire [4:0] n463;
  wire [12:0] n464;
  wire [12:0] n465;
  wire [12:0] n466;
  wire [11:0] n467;
  wire n471;
  wire n473;
  wire [2:0] n475;
  wire [2:0] n477;
  wire n486;
  wire n488;
  wire n489;
  wire n490;
  wire [1:0] n491;
  wire n492;
  wire [2:0] n493;
  wire [14:0] n494;
  wire [14:0] n495;
  wire [14:0] n497;
  wire n506;
  wire n508;
  wire n510;
  wire [7:0] n518;
  reg [7:0] n519;
  wire [11:0] n520;
  reg [11:0] n521;
  wire [11:0] n522;
  reg [11:0] n523;
  wire [11:0] n524;
  reg [11:0] n525;
  wire [11:0] n526;
  reg [11:0] n527;
  wire [11:0] n528;
  reg [11:0] n529;
  wire [3:0] n530;
  reg [3:0] n531;
  wire [3:0] n532;
  reg [3:0] n533;
  wire [3:0] n534;
  reg [3:0] n535;
  wire [3:0] n536;
  reg [3:0] n537;
  wire [3:0] n538;
  reg [3:0] n539;
  wire [4:0] n540;
  reg [4:0] n541;
  wire [7:0] n542;
  reg [7:0] n543;
  reg n544;
  reg n545;
  reg n546;
  reg n547;
  reg n548;
  wire [4:0] n549;
  reg [4:0] n550;
  wire [4:0] n551;
  reg [4:0] n552;
  wire [4:0] n553;
  reg [4:0] n554;
  wire [4:0] n555;
  reg [4:0] n556;
  wire [4:0] n557;
  reg [4:0] n558;
  wire [2:0] n559;
  reg [2:0] n560;
  reg [2:0] n561;
  wire [14:0] n562;
  reg [14:0] n563;
  reg n564;
  reg n565;
  reg n566;
  reg [7:0] n567;
  wire [14:0] n568;
  reg [14:0] n569;
  wire [11:0] n570;
  reg [11:0] n571;
  wire [11:0] n572;
  reg [11:0] n573;
  wire [11:0] n574;
  reg [11:0] n575;
  wire [11:0] n576;
  reg [11:0] n577;
  wire [11:0] n578;
  reg [11:0] n579;
  assign ack = ff_req_dl; //(module output)
  assign dbi = n519; //(module output)
  assign wave = ff_wave; //(module output)
  assign dbg_vol_nz = n214; //(module output)
  assign dbg_sel_nz = n219; //(module output)
  assign dbg_freq_nz = n224; //(module output)
  assign dbg_ptr_lsb = n226; //(module output)
  assign dbg_scan_lsb = n227; //(module output)
  assign dbg_mix_nz = n231; //(module output)
  /*# scc_wave2.vhd:127:12 */
  assign w_wave_ce = n205; // (signal)
  /*# scc_wave2.vhd:128:12 */
  assign w_wave_we = n209; // (signal)
  /*# scc_wave2.vhd:129:12 */
  assign w_wave_adr = n357; // (signal)
  /*# scc_wave2.vhd:130:12 */
  assign w_ch_dec = n427; // (signal)
  /*# scc_wave2.vhd:131:12 */
  assign w_ch_bit = n446; // (signal)
  /*# scc_wave2.vhd:132:12 */
  assign w_ch_mask = n447; // (signal)
  /*# scc_wave2.vhd:133:12 */
  assign w_ch_vol = n460; // (signal)
  /*# scc_wave2.vhd:134:12 */
  assign w_wave = n461; // (signal)
  /*# scc_wave2.vhd:135:12 */
  assign w_mul = n467; // (signal)
  /*# scc_wave2.vhd:136:12 */
  assign w_mul_s = n466; // (signal)
  /*# scc_wave2.vhd:137:12 */
  assign ram_dbi = wavemem_n383; // (signal)
  /*# scc_wave2.vhd:143:12 */
  assign reg_freq_ch_a = n521; // (signal)
  /*# scc_wave2.vhd:144:12 */
  assign reg_freq_ch_b = n523; // (signal)
  /*# scc_wave2.vhd:145:12 */
  assign reg_freq_ch_c = n525; // (signal)
  /*# scc_wave2.vhd:146:12 */
  assign reg_freq_ch_d = n527; // (signal)
  /*# scc_wave2.vhd:147:12 */
  assign reg_freq_ch_e = n529; // (signal)
  /*# scc_wave2.vhd:148:12 */
  assign reg_vol_ch_a = n531; // (signal)
  /*# scc_wave2.vhd:149:12 */
  assign reg_vol_ch_b = n533; // (signal)
  /*# scc_wave2.vhd:150:12 */
  assign reg_vol_ch_c = n535; // (signal)
  /*# scc_wave2.vhd:151:12 */
  assign reg_vol_ch_d = n537; // (signal)
  /*# scc_wave2.vhd:152:12 */
  assign reg_vol_ch_e = n539; // (signal)
  /*# scc_wave2.vhd:153:12 */
  assign reg_ch_sel = n541; // (signal)
  /*# scc_wave2.vhd:154:12 */
  assign reg_mode_sel = n543; // (signal)
  /*# scc_wave2.vhd:157:12 */
  assign ff_rst_ch_a = n544; // (signal)
  /*# scc_wave2.vhd:158:12 */
  assign ff_rst_ch_b = n545; // (signal)
  /*# scc_wave2.vhd:159:12 */
  assign ff_rst_ch_c = n546; // (signal)
  /*# scc_wave2.vhd:160:12 */
  assign ff_rst_ch_d = n547; // (signal)
  /*# scc_wave2.vhd:161:12 */
  assign ff_rst_ch_e = n548; // (signal)
  /*# scc_wave2.vhd:162:12 */
  assign ff_ptr_ch_a = n550; // (signal)
  /*# scc_wave2.vhd:163:12 */
  assign ff_ptr_ch_b = n552; // (signal)
  /*# scc_wave2.vhd:164:12 */
  assign ff_ptr_ch_c = n554; // (signal)
  /*# scc_wave2.vhd:165:12 */
  assign ff_ptr_ch_d = n556; // (signal)
  /*# scc_wave2.vhd:166:12 */
  assign ff_ptr_ch_e = n558; // (signal)
  /*# scc_wave2.vhd:167:12 */
  assign ff_ch_num = n560; // (signal)
  /*# scc_wave2.vhd:168:12 */
  assign ff_ch_num_dl = n561; // (signal)
  /*# scc_wave2.vhd:169:12 */
  assign ff_mix = n563; // (signal)
  /*# scc_wave2.vhd:170:12 */
  assign ff_wave_ce = n564; // (signal)
  /*# scc_wave2.vhd:171:12 */
  assign ff_wave_ce_dl = n565; // (signal)
  /*# scc_wave2.vhd:172:12 */
  assign ff_req_dl = n566; // (signal)
  /*# scc_wave2.vhd:173:12 */
  assign ff_wave_dat = n567; // (signal)
  /*# scc_wave2.vhd:174:12 */
  assign ff_wave = n569; // (signal)
  /*# scc_wave2.vhd:208:41 */
  assign n12 = ~ff_req_dl;
  /*# scc_wave2.vhd:208:27 */
  assign n13 = n12 & req;
  /*# scc_wave2.vhd:208:47 */
  assign n14 = wrt & n13;
  /*# scc_wave2.vhd:209:27 */
  assign n15 = ~sccplus;
  /*# scc_wave2.vhd:209:40 */
  assign n16 = adr[7:5]; // extract
  /*# scc_wave2.vhd:209:53 */
  assign n18 = n16 == 3'b100;
  /*# scc_wave2.vhd:209:33 */
  assign n19 = n18 & n15;
  /*# scc_wave2.vhd:210:40 */
  assign n20 = adr[7:5]; // extract
  /*# scc_wave2.vhd:210:53 */
  assign n22 = n20 == 3'b101;
  /*# scc_wave2.vhd:210:33 */
  assign n23 = n22 & sccplus;
  /*# scc_wave2.vhd:209:62 */
  assign n24 = n19 | n23;
  /*# scc_wave2.vhd:208:61 */
  assign n25 = n24 & n14;
  /*# scc_wave2.vhd:211:25 */
  assign n26 = adr[3:0]; // extract
  /*# scc_wave2.vhd:212:114 */
  assign n27 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:212:21 */
  assign n29 = n26 == 4'b0000;
  /*# scc_wave2.vhd:213:71 */
  assign n30 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:213:114 */
  assign n31 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:213:21 */
  assign n33 = n26 == 4'b0001;
  /*# scc_wave2.vhd:214:114 */
  assign n34 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:214:21 */
  assign n36 = n26 == 4'b0010;
  /*# scc_wave2.vhd:215:71 */
  assign n37 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:215:114 */
  assign n38 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:215:21 */
  assign n40 = n26 == 4'b0011;
  /*# scc_wave2.vhd:216:114 */
  assign n41 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:216:21 */
  assign n43 = n26 == 4'b0100;
  /*# scc_wave2.vhd:217:71 */
  assign n44 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:217:114 */
  assign n45 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:217:21 */
  assign n47 = n26 == 4'b0101;
  /*# scc_wave2.vhd:218:114 */
  assign n48 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:218:21 */
  assign n50 = n26 == 4'b0110;
  /*# scc_wave2.vhd:219:71 */
  assign n51 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:219:114 */
  assign n52 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:219:21 */
  assign n54 = n26 == 4'b0111;
  /*# scc_wave2.vhd:220:114 */
  assign n55 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:220:21 */
  assign n57 = n26 == 4'b1000;
  /*# scc_wave2.vhd:221:71 */
  assign n58 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:221:114 */
  assign n59 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:221:21 */
  assign n61 = n26 == 4'b1001;
  /*# scc_wave2.vhd:222:71 */
  assign n62 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:222:21 */
  assign n64 = n26 == 4'b1010;
  /*# scc_wave2.vhd:223:71 */
  assign n65 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:223:21 */
  assign n67 = n26 == 4'b1011;
  /*# scc_wave2.vhd:224:71 */
  assign n68 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:224:21 */
  assign n70 = n26 == 4'b1100;
  /*# scc_wave2.vhd:225:71 */
  assign n71 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:225:21 */
  assign n73 = n26 == 4'b1101;
  /*# scc_wave2.vhd:226:71 */
  assign n74 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:226:21 */
  assign n76 = n26 == 4'b1110;
  /*# scc_wave2.vhd:227:71 */
  assign n77 = dbo[4:0]; // extract
  /*# scc_wave2.vhd:211:17 */
  assign n78 = {n76, n73, n70, n67, n64, n61, n57, n54, n50, n47, n43, n40, n36, n33, n29};
  /*# scc_wave2.vhd:143:12 */
  assign n79 = reg_freq_ch_a[7:0]; // extract
  /*# scc_wave2.vhd:211:17 */
  always @*
    case (n78)
      15'b100000000000000: n80 = n79;
      15'b010000000000000: n80 = n79;
      15'b001000000000000: n80 = n79;
      15'b000100000000000: n80 = n79;
      15'b000010000000000: n80 = n79;
      15'b000001000000000: n80 = n79;
      15'b000000100000000: n80 = n79;
      15'b000000010000000: n80 = n79;
      15'b000000001000000: n80 = n79;
      15'b000000000100000: n80 = n79;
      15'b000000000010000: n80 = n79;
      15'b000000000001000: n80 = n79;
      15'b000000000000100: n80 = n79;
      15'b000000000000010: n80 = n79;
      15'b000000000000001: n80 = dbo;
      default: n80 = n79;
    endcase
  /*# scc_wave2.vhd:143:12 */
  assign n81 = reg_freq_ch_a[11:8]; // extract
  /*# scc_wave2.vhd:211:17 */
  always @*
    case (n78)
      15'b100000000000000: n82 = n81;
      15'b010000000000000: n82 = n81;
      15'b001000000000000: n82 = n81;
      15'b000100000000000: n82 = n81;
      15'b000010000000000: n82 = n81;
      15'b000001000000000: n82 = n81;
      15'b000000100000000: n82 = n81;
      15'b000000010000000: n82 = n81;
      15'b000000001000000: n82 = n81;
      15'b000000000100000: n82 = n81;
      15'b000000000010000: n82 = n81;
      15'b000000000001000: n82 = n81;
      15'b000000000000100: n82 = n81;
      15'b000000000000010: n82 = n30;
      15'b000000000000001: n82 = n81;
      default: n82 = n81;
    endcase
  /*# scc_wave2.vhd:144:12 */
  assign n83 = reg_freq_ch_b[7:0]; // extract
  /*# scc_wave2.vhd:211:17 */
  always @*
    case (n78)
      15'b100000000000000: n84 = n83;
      15'b010000000000000: n84 = n83;
      15'b001000000000000: n84 = n83;
      15'b000100000000000: n84 = n83;
      15'b000010000000000: n84 = n83;
      15'b000001000000000: n84 = n83;
      15'b000000100000000: n84 = n83;
      15'b000000010000000: n84 = n83;
      15'b000000001000000: n84 = n83;
      15'b000000000100000: n84 = n83;
      15'b000000000010000: n84 = n83;
      15'b000000000001000: n84 = n83;
      15'b000000000000100: n84 = dbo;
      15'b000000000000010: n84 = n83;
      15'b000000000000001: n84 = n83;
      default: n84 = n83;
    endcase
  /*# scc_wave2.vhd:144:12 */
  assign n85 = reg_freq_ch_b[11:8]; // extract
  /*# scc_wave2.vhd:211:17 */
  always @*
    case (n78)
      15'b100000000000000: n86 = n85;
      15'b010000000000000: n86 = n85;
      15'b001000000000000: n86 = n85;
      15'b000100000000000: n86 = n85;
      15'b000010000000000: n86 = n85;
      15'b000001000000000: n86 = n85;
      15'b000000100000000: n86 = n85;
      15'b000000010000000: n86 = n85;
      15'b000000001000000: n86 = n85;
      15'b000000000100000: n86 = n85;
      15'b000000000010000: n86 = n85;
      15'b000000000001000: n86 = n37;
      15'b000000000000100: n86 = n85;
      15'b000000000000010: n86 = n85;
      15'b000000000000001: n86 = n85;
      default: n86 = n85;
    endcase
  /*# scc_wave2.vhd:145:12 */
  assign n87 = reg_freq_ch_c[7:0]; // extract
  /*# scc_wave2.vhd:211:17 */
  always @*
    case (n78)
      15'b100000000000000: n88 = n87;
      15'b010000000000000: n88 = n87;
      15'b001000000000000: n88 = n87;
      15'b000100000000000: n88 = n87;
      15'b000010000000000: n88 = n87;
      15'b000001000000000: n88 = n87;
      15'b000000100000000: n88 = n87;
      15'b000000010000000: n88 = n87;
      15'b000000001000000: n88 = n87;
      15'b000000000100000: n88 = n87;
      15'b000000000010000: n88 = dbo;
      15'b000000000001000: n88 = n87;
      15'b000000000000100: n88 = n87;
      15'b000000000000010: n88 = n87;
      15'b000000000000001: n88 = n87;
      default: n88 = n87;
    endcase
  /*# scc_wave2.vhd:145:12 */
  assign n89 = reg_freq_ch_c[11:8]; // extract
  /*# scc_wave2.vhd:211:17 */
  always @*
    case (n78)
      15'b100000000000000: n90 = n89;
      15'b010000000000000: n90 = n89;
      15'b001000000000000: n90 = n89;
      15'b000100000000000: n90 = n89;
      15'b000010000000000: n90 = n89;
      15'b000001000000000: n90 = n89;
      15'b000000100000000: n90 = n89;
      15'b000000010000000: n90 = n89;
      15'b000000001000000: n90 = n89;
      15'b000000000100000: n90 = n44;
      15'b000000000010000: n90 = n89;
      15'b000000000001000: n90 = n89;
      15'b000000000000100: n90 = n89;
      15'b000000000000010: n90 = n89;
      15'b000000000000001: n90 = n89;
      default: n90 = n89;
    endcase
  /*# scc_wave2.vhd:146:12 */
  assign n91 = reg_freq_ch_d[7:0]; // extract
  /*# scc_wave2.vhd:211:17 */
  always @*
    case (n78)
      15'b100000000000000: n92 = n91;
      15'b010000000000000: n92 = n91;
      15'b001000000000000: n92 = n91;
      15'b000100000000000: n92 = n91;
      15'b000010000000000: n92 = n91;
      15'b000001000000000: n92 = n91;
      15'b000000100000000: n92 = n91;
      15'b000000010000000: n92 = n91;
      15'b000000001000000: n92 = dbo;
      15'b000000000100000: n92 = n91;
      15'b000000000010000: n92 = n91;
      15'b000000000001000: n92 = n91;
      15'b000000000000100: n92 = n91;
      15'b000000000000010: n92 = n91;
      15'b000000000000001: n92 = n91;
      default: n92 = n91;
    endcase
  /*# scc_wave2.vhd:146:12 */
  assign n93 = reg_freq_ch_d[11:8]; // extract
  /*# scc_wave2.vhd:211:17 */
  always @*
    case (n78)
      15'b100000000000000: n94 = n93;
      15'b010000000000000: n94 = n93;
      15'b001000000000000: n94 = n93;
      15'b000100000000000: n94 = n93;
      15'b000010000000000: n94 = n93;
      15'b000001000000000: n94 = n93;
      15'b000000100000000: n94 = n93;
      15'b000000010000000: n94 = n51;
      15'b000000001000000: n94 = n93;
      15'b000000000100000: n94 = n93;
      15'b000000000010000: n94 = n93;
      15'b000000000001000: n94 = n93;
      15'b000000000000100: n94 = n93;
      15'b000000000000010: n94 = n93;
      15'b000000000000001: n94 = n93;
      default: n94 = n93;
    endcase
  /*# scc_wave2.vhd:147:12 */
  assign n95 = reg_freq_ch_e[7:0]; // extract
  /*# scc_wave2.vhd:211:17 */
  always @*
    case (n78)
      15'b100000000000000: n96 = n95;
      15'b010000000000000: n96 = n95;
      15'b001000000000000: n96 = n95;
      15'b000100000000000: n96 = n95;
      15'b000010000000000: n96 = n95;
      15'b000001000000000: n96 = n95;
      15'b000000100000000: n96 = dbo;
      15'b000000010000000: n96 = n95;
      15'b000000001000000: n96 = n95;
      15'b000000000100000: n96 = n95;
      15'b000000000010000: n96 = n95;
      15'b000000000001000: n96 = n95;
      15'b000000000000100: n96 = n95;
      15'b000000000000010: n96 = n95;
      15'b000000000000001: n96 = n95;
      default: n96 = n95;
    endcase
  /*# scc_wave2.vhd:147:12 */
  assign n97 = reg_freq_ch_e[11:8]; // extract
  /*# scc_wave2.vhd:211:17 */
  always @*
    case (n78)
      15'b100000000000000: n98 = n97;
      15'b010000000000000: n98 = n97;
      15'b001000000000000: n98 = n97;
      15'b000100000000000: n98 = n97;
      15'b000010000000000: n98 = n97;
      15'b000001000000000: n98 = n58;
      15'b000000100000000: n98 = n97;
      15'b000000010000000: n98 = n97;
      15'b000000001000000: n98 = n97;
      15'b000000000100000: n98 = n97;
      15'b000000000010000: n98 = n97;
      15'b000000000001000: n98 = n97;
      15'b000000000000100: n98 = n97;
      15'b000000000000010: n98 = n97;
      15'b000000000000001: n98 = n97;
      default: n98 = n97;
    endcase
  /*# scc_wave2.vhd:211:17 */
  always @*
    case (n78)
      15'b100000000000000: n99 = reg_vol_ch_a;
      15'b010000000000000: n99 = reg_vol_ch_a;
      15'b001000000000000: n99 = reg_vol_ch_a;
      15'b000100000000000: n99 = reg_vol_ch_a;
      15'b000010000000000: n99 = n62;
      15'b000001000000000: n99 = reg_vol_ch_a;
      15'b000000100000000: n99 = reg_vol_ch_a;
      15'b000000010000000: n99 = reg_vol_ch_a;
      15'b000000001000000: n99 = reg_vol_ch_a;
      15'b000000000100000: n99 = reg_vol_ch_a;
      15'b000000000010000: n99 = reg_vol_ch_a;
      15'b000000000001000: n99 = reg_vol_ch_a;
      15'b000000000000100: n99 = reg_vol_ch_a;
      15'b000000000000010: n99 = reg_vol_ch_a;
      15'b000000000000001: n99 = reg_vol_ch_a;
      default: n99 = reg_vol_ch_a;
    endcase
  /*# scc_wave2.vhd:211:17 */
  always @*
    case (n78)
      15'b100000000000000: n100 = reg_vol_ch_b;
      15'b010000000000000: n100 = reg_vol_ch_b;
      15'b001000000000000: n100 = reg_vol_ch_b;
      15'b000100000000000: n100 = n65;
      15'b000010000000000: n100 = reg_vol_ch_b;
      15'b000001000000000: n100 = reg_vol_ch_b;
      15'b000000100000000: n100 = reg_vol_ch_b;
      15'b000000010000000: n100 = reg_vol_ch_b;
      15'b000000001000000: n100 = reg_vol_ch_b;
      15'b000000000100000: n100 = reg_vol_ch_b;
      15'b000000000010000: n100 = reg_vol_ch_b;
      15'b000000000001000: n100 = reg_vol_ch_b;
      15'b000000000000100: n100 = reg_vol_ch_b;
      15'b000000000000010: n100 = reg_vol_ch_b;
      15'b000000000000001: n100 = reg_vol_ch_b;
      default: n100 = reg_vol_ch_b;
    endcase
  /*# scc_wave2.vhd:211:17 */
  always @*
    case (n78)
      15'b100000000000000: n101 = reg_vol_ch_c;
      15'b010000000000000: n101 = reg_vol_ch_c;
      15'b001000000000000: n101 = n68;
      15'b000100000000000: n101 = reg_vol_ch_c;
      15'b000010000000000: n101 = reg_vol_ch_c;
      15'b000001000000000: n101 = reg_vol_ch_c;
      15'b000000100000000: n101 = reg_vol_ch_c;
      15'b000000010000000: n101 = reg_vol_ch_c;
      15'b000000001000000: n101 = reg_vol_ch_c;
      15'b000000000100000: n101 = reg_vol_ch_c;
      15'b000000000010000: n101 = reg_vol_ch_c;
      15'b000000000001000: n101 = reg_vol_ch_c;
      15'b000000000000100: n101 = reg_vol_ch_c;
      15'b000000000000010: n101 = reg_vol_ch_c;
      15'b000000000000001: n101 = reg_vol_ch_c;
      default: n101 = reg_vol_ch_c;
    endcase
  /*# scc_wave2.vhd:211:17 */
  always @*
    case (n78)
      15'b100000000000000: n102 = reg_vol_ch_d;
      15'b010000000000000: n102 = n71;
      15'b001000000000000: n102 = reg_vol_ch_d;
      15'b000100000000000: n102 = reg_vol_ch_d;
      15'b000010000000000: n102 = reg_vol_ch_d;
      15'b000001000000000: n102 = reg_vol_ch_d;
      15'b000000100000000: n102 = reg_vol_ch_d;
      15'b000000010000000: n102 = reg_vol_ch_d;
      15'b000000001000000: n102 = reg_vol_ch_d;
      15'b000000000100000: n102 = reg_vol_ch_d;
      15'b000000000010000: n102 = reg_vol_ch_d;
      15'b000000000001000: n102 = reg_vol_ch_d;
      15'b000000000000100: n102 = reg_vol_ch_d;
      15'b000000000000010: n102 = reg_vol_ch_d;
      15'b000000000000001: n102 = reg_vol_ch_d;
      default: n102 = reg_vol_ch_d;
    endcase
  /*# scc_wave2.vhd:211:17 */
  always @*
    case (n78)
      15'b100000000000000: n103 = n74;
      15'b010000000000000: n103 = reg_vol_ch_e;
      15'b001000000000000: n103 = reg_vol_ch_e;
      15'b000100000000000: n103 = reg_vol_ch_e;
      15'b000010000000000: n103 = reg_vol_ch_e;
      15'b000001000000000: n103 = reg_vol_ch_e;
      15'b000000100000000: n103 = reg_vol_ch_e;
      15'b000000010000000: n103 = reg_vol_ch_e;
      15'b000000001000000: n103 = reg_vol_ch_e;
      15'b000000000100000: n103 = reg_vol_ch_e;
      15'b000000000010000: n103 = reg_vol_ch_e;
      15'b000000000001000: n103 = reg_vol_ch_e;
      15'b000000000000100: n103 = reg_vol_ch_e;
      15'b000000000000010: n103 = reg_vol_ch_e;
      15'b000000000000001: n103 = reg_vol_ch_e;
      default: n103 = reg_vol_ch_e;
    endcase
  /*# scc_wave2.vhd:211:17 */
  always @*
    case (n78)
      15'b100000000000000: n104 = reg_ch_sel;
      15'b010000000000000: n104 = reg_ch_sel;
      15'b001000000000000: n104 = reg_ch_sel;
      15'b000100000000000: n104 = reg_ch_sel;
      15'b000010000000000: n104 = reg_ch_sel;
      15'b000001000000000: n104 = reg_ch_sel;
      15'b000000100000000: n104 = reg_ch_sel;
      15'b000000010000000: n104 = reg_ch_sel;
      15'b000000001000000: n104 = reg_ch_sel;
      15'b000000000100000: n104 = reg_ch_sel;
      15'b000000000010000: n104 = reg_ch_sel;
      15'b000000000001000: n104 = reg_ch_sel;
      15'b000000000000100: n104 = reg_ch_sel;
      15'b000000000000010: n104 = reg_ch_sel;
      15'b000000000000001: n104 = reg_ch_sel;
      default: n104 = n77;
    endcase
  /*# scc_wave2.vhd:211:17 */
  always @*
    case (n78)
      15'b100000000000000: n105 = ff_rst_ch_a;
      15'b010000000000000: n105 = ff_rst_ch_a;
      15'b001000000000000: n105 = ff_rst_ch_a;
      15'b000100000000000: n105 = ff_rst_ch_a;
      15'b000010000000000: n105 = ff_rst_ch_a;
      15'b000001000000000: n105 = ff_rst_ch_a;
      15'b000000100000000: n105 = ff_rst_ch_a;
      15'b000000010000000: n105 = ff_rst_ch_a;
      15'b000000001000000: n105 = ff_rst_ch_a;
      15'b000000000100000: n105 = ff_rst_ch_a;
      15'b000000000010000: n105 = ff_rst_ch_a;
      15'b000000000001000: n105 = ff_rst_ch_a;
      15'b000000000000100: n105 = ff_rst_ch_a;
      15'b000000000000010: n105 = n31;
      15'b000000000000001: n105 = n27;
      default: n105 = ff_rst_ch_a;
    endcase
  /*# scc_wave2.vhd:211:17 */
  always @*
    case (n78)
      15'b100000000000000: n106 = ff_rst_ch_b;
      15'b010000000000000: n106 = ff_rst_ch_b;
      15'b001000000000000: n106 = ff_rst_ch_b;
      15'b000100000000000: n106 = ff_rst_ch_b;
      15'b000010000000000: n106 = ff_rst_ch_b;
      15'b000001000000000: n106 = ff_rst_ch_b;
      15'b000000100000000: n106 = ff_rst_ch_b;
      15'b000000010000000: n106 = ff_rst_ch_b;
      15'b000000001000000: n106 = ff_rst_ch_b;
      15'b000000000100000: n106 = ff_rst_ch_b;
      15'b000000000010000: n106 = ff_rst_ch_b;
      15'b000000000001000: n106 = n38;
      15'b000000000000100: n106 = n34;
      15'b000000000000010: n106 = ff_rst_ch_b;
      15'b000000000000001: n106 = ff_rst_ch_b;
      default: n106 = ff_rst_ch_b;
    endcase
  /*# scc_wave2.vhd:211:17 */
  always @*
    case (n78)
      15'b100000000000000: n107 = ff_rst_ch_c;
      15'b010000000000000: n107 = ff_rst_ch_c;
      15'b001000000000000: n107 = ff_rst_ch_c;
      15'b000100000000000: n107 = ff_rst_ch_c;
      15'b000010000000000: n107 = ff_rst_ch_c;
      15'b000001000000000: n107 = ff_rst_ch_c;
      15'b000000100000000: n107 = ff_rst_ch_c;
      15'b000000010000000: n107 = ff_rst_ch_c;
      15'b000000001000000: n107 = ff_rst_ch_c;
      15'b000000000100000: n107 = n45;
      15'b000000000010000: n107 = n41;
      15'b000000000001000: n107 = ff_rst_ch_c;
      15'b000000000000100: n107 = ff_rst_ch_c;
      15'b000000000000010: n107 = ff_rst_ch_c;
      15'b000000000000001: n107 = ff_rst_ch_c;
      default: n107 = ff_rst_ch_c;
    endcase
  /*# scc_wave2.vhd:211:17 */
  always @*
    case (n78)
      15'b100000000000000: n108 = ff_rst_ch_d;
      15'b010000000000000: n108 = ff_rst_ch_d;
      15'b001000000000000: n108 = ff_rst_ch_d;
      15'b000100000000000: n108 = ff_rst_ch_d;
      15'b000010000000000: n108 = ff_rst_ch_d;
      15'b000001000000000: n108 = ff_rst_ch_d;
      15'b000000100000000: n108 = ff_rst_ch_d;
      15'b000000010000000: n108 = n52;
      15'b000000001000000: n108 = n48;
      15'b000000000100000: n108 = ff_rst_ch_d;
      15'b000000000010000: n108 = ff_rst_ch_d;
      15'b000000000001000: n108 = ff_rst_ch_d;
      15'b000000000000100: n108 = ff_rst_ch_d;
      15'b000000000000010: n108 = ff_rst_ch_d;
      15'b000000000000001: n108 = ff_rst_ch_d;
      default: n108 = ff_rst_ch_d;
    endcase
  /*# scc_wave2.vhd:211:17 */
  always @*
    case (n78)
      15'b100000000000000: n109 = ff_rst_ch_e;
      15'b010000000000000: n109 = ff_rst_ch_e;
      15'b001000000000000: n109 = ff_rst_ch_e;
      15'b000100000000000: n109 = ff_rst_ch_e;
      15'b000010000000000: n109 = ff_rst_ch_e;
      15'b000001000000000: n109 = n59;
      15'b000000100000000: n109 = n55;
      15'b000000010000000: n109 = ff_rst_ch_e;
      15'b000000001000000: n109 = ff_rst_ch_e;
      15'b000000000100000: n109 = ff_rst_ch_e;
      15'b000000000010000: n109 = ff_rst_ch_e;
      15'b000000000001000: n109 = ff_rst_ch_e;
      15'b000000000000100: n109 = ff_rst_ch_e;
      15'b000000000000010: n109 = ff_rst_ch_e;
      15'b000000000000001: n109 = ff_rst_ch_e;
      default: n109 = ff_rst_ch_e;
    endcase
  /*# scc_wave2.vhd:229:13 */
  assign n111 = clkena ? 1'b0 : ff_rst_ch_a;
  /*# scc_wave2.vhd:229:13 */
  assign n113 = clkena ? 1'b0 : ff_rst_ch_b;
  /*# scc_wave2.vhd:229:13 */
  assign n115 = clkena ? 1'b0 : ff_rst_ch_c;
  /*# scc_wave2.vhd:229:13 */
  assign n117 = clkena ? 1'b0 : ff_rst_ch_d;
  /*# scc_wave2.vhd:229:13 */
  assign n119 = clkena ? 1'b0 : ff_rst_ch_e;
  /*# scc_wave2.vhd:208:13 */
  assign n120 = {n82, n80};
  /*# scc_wave2.vhd:208:13 */
  assign n122 = {n86, n84};
  /*# scc_wave2.vhd:208:13 */
  assign n124 = {n90, n88};
  /*# scc_wave2.vhd:208:13 */
  assign n126 = {n94, n92};
  /*# scc_wave2.vhd:208:13 */
  assign n128 = {n98, n96};
  /*# scc_wave2.vhd:208:13 */
  assign n136 = n25 ? n105 : n111;
  /*# scc_wave2.vhd:208:13 */
  assign n137 = n25 ? n106 : n113;
  /*# scc_wave2.vhd:208:13 */
  assign n138 = n25 ? n107 : n115;
  /*# scc_wave2.vhd:208:13 */
  assign n139 = n25 ? n108 : n117;
  /*# scc_wave2.vhd:208:13 */
  assign n140 = n25 ? n109 : n119;
  /*# scc_wave2.vhd:238:27 */
  assign n141 = wrt & req;
  /*# scc_wave2.vhd:238:48 */
  assign n142 = adr[7:5]; // extract
  /*# scc_wave2.vhd:238:61 */
  assign n144 = n142 == 3'b110;
  /*# scc_wave2.vhd:238:41 */
  assign n145 = n144 & n141;
  /*# scc_wave2.vhd:247:55 */
  assign n203 = ~ff_req_dl;
  /*# scc_wave2.vhd:247:41 */
  assign n204 = n203 & req;
  /*# scc_wave2.vhd:247:25 */
  assign n205 = n204 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:248:55 */
  assign n207 = ~ff_req_dl;
  /*# scc_wave2.vhd:248:41 */
  assign n208 = n207 & req;
  /*# scc_wave2.vhd:248:25 */
  assign n209 = n208 ? wrt : 1'b0;
  /*# scc_wave2.vhd:252:44 */
  assign n213 = reg_vol_ch_a != 4'b0000;
  /*# scc_wave2.vhd:252:24 */
  assign n214 = n213 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:253:42 */
  assign n218 = reg_ch_sel != 5'b00000;
  /*# scc_wave2.vhd:253:24 */
  assign n219 = n218 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:254:45 */
  assign n223 = reg_freq_ch_a != 12'b000000000000;
  /*# scc_wave2.vhd:254:24 */
  assign n224 = n223 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:260:31 */
  assign n226 = ff_ptr_ch_a[0]; // extract
  /*# scc_wave2.vhd:272:30 */
  assign n227 = ff_ch_num[0]; // extract
  /*# scc_wave2.vhd:273:39 */
  assign n230 = ff_mix != 15'b000000000000000;
  /*# scc_wave2.vhd:273:25 */
  assign n231 = n230 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:279:18 */
  always @*
    n233_ff_cnt_ch_a = n571; // (isignal)
  initial
    n233_ff_cnt_ch_a = 12'bX;
  /*# scc_wave2.vhd:280:18 */
  always @*
    n233_ff_cnt_ch_b = n573; // (isignal)
  initial
    n233_ff_cnt_ch_b = 12'bX;
  /*# scc_wave2.vhd:281:18 */
  always @*
    n233_ff_cnt_ch_c = n575; // (isignal)
  initial
    n233_ff_cnt_ch_c = 12'bX;
  /*# scc_wave2.vhd:282:18 */
  always @*
    n233_ff_cnt_ch_d = n577; // (isignal)
  initial
    n233_ff_cnt_ch_d = 12'bX;
  /*# scc_wave2.vhd:283:18 */
  always @*
    n233_ff_cnt_ch_e = n579; // (isignal)
  initial
    n233_ff_cnt_ch_e = 12'bX;
  /*# scc_wave2.vhd:300:34 */
  assign n241 = reg_freq_ch_a[11:3]; // extract
  /*# scc_wave2.vhd:300:48 */
  assign n243 = n241 == 9'b000000000;
  /*# scc_wave2.vhd:300:62 */
  assign n244 = n243 | ff_rst_ch_a;
  /*# scc_wave2.vhd:303:36 */
  assign n246 = n233_ff_cnt_ch_a == 12'b000000000000;
  /*# scc_wave2.vhd:304:48 */
  assign n248 = ff_ptr_ch_a + 5'b00001;
  /*# scc_wave2.vhd:307:48 */
  assign n250 = n233_ff_cnt_ch_a - 12'b000000000001;
  /*# scc_wave2.vhd:303:17 */
  assign n251 = n246 ? n248 : ff_ptr_ch_a;
  /*# scc_wave2.vhd:303:17 */
  assign n252 = n246 ? reg_freq_ch_a : n250;
  /*# scc_wave2.vhd:300:17 */
  assign n254 = n244 ? 5'b00000 : n251;
  /*# scc_wave2.vhd:300:17 */
  assign n255 = n244 ? reg_freq_ch_a : n252;
  /*# scc_wave2.vhd:310:34 */
  assign n256 = reg_freq_ch_b[11:3]; // extract
  /*# scc_wave2.vhd:310:48 */
  assign n258 = n256 == 9'b000000000;
  /*# scc_wave2.vhd:310:62 */
  assign n259 = n258 | ff_rst_ch_b;
  /*# scc_wave2.vhd:313:36 */
  assign n261 = n233_ff_cnt_ch_b == 12'b000000000000;
  /*# scc_wave2.vhd:314:48 */
  assign n263 = ff_ptr_ch_b + 5'b00001;
  /*# scc_wave2.vhd:317:48 */
  assign n265 = n233_ff_cnt_ch_b - 12'b000000000001;
  /*# scc_wave2.vhd:313:17 */
  assign n266 = n261 ? n263 : ff_ptr_ch_b;
  /*# scc_wave2.vhd:313:17 */
  assign n267 = n261 ? reg_freq_ch_b : n265;
  /*# scc_wave2.vhd:310:17 */
  assign n269 = n259 ? 5'b00000 : n266;
  /*# scc_wave2.vhd:310:17 */
  assign n270 = n259 ? reg_freq_ch_b : n267;
  /*# scc_wave2.vhd:320:34 */
  assign n271 = reg_freq_ch_c[11:3]; // extract
  /*# scc_wave2.vhd:320:48 */
  assign n273 = n271 == 9'b000000000;
  /*# scc_wave2.vhd:320:62 */
  assign n274 = n273 | ff_rst_ch_c;
  /*# scc_wave2.vhd:323:36 */
  assign n276 = n233_ff_cnt_ch_c == 12'b000000000000;
  /*# scc_wave2.vhd:324:48 */
  assign n278 = ff_ptr_ch_c + 5'b00001;
  /*# scc_wave2.vhd:327:48 */
  assign n280 = n233_ff_cnt_ch_c - 12'b000000000001;
  /*# scc_wave2.vhd:323:17 */
  assign n281 = n276 ? n278 : ff_ptr_ch_c;
  /*# scc_wave2.vhd:323:17 */
  assign n282 = n276 ? reg_freq_ch_c : n280;
  /*# scc_wave2.vhd:320:17 */
  assign n284 = n274 ? 5'b00000 : n281;
  /*# scc_wave2.vhd:320:17 */
  assign n285 = n274 ? reg_freq_ch_c : n282;
  /*# scc_wave2.vhd:330:34 */
  assign n286 = reg_freq_ch_d[11:3]; // extract
  /*# scc_wave2.vhd:330:48 */
  assign n288 = n286 == 9'b000000000;
  /*# scc_wave2.vhd:330:62 */
  assign n289 = n288 | ff_rst_ch_d;
  /*# scc_wave2.vhd:333:36 */
  assign n291 = n233_ff_cnt_ch_d == 12'b000000000000;
  /*# scc_wave2.vhd:334:48 */
  assign n293 = ff_ptr_ch_d + 5'b00001;
  /*# scc_wave2.vhd:337:48 */
  assign n295 = n233_ff_cnt_ch_d - 12'b000000000001;
  /*# scc_wave2.vhd:333:17 */
  assign n296 = n291 ? n293 : ff_ptr_ch_d;
  /*# scc_wave2.vhd:333:17 */
  assign n297 = n291 ? reg_freq_ch_d : n295;
  /*# scc_wave2.vhd:330:17 */
  assign n299 = n289 ? 5'b00000 : n296;
  /*# scc_wave2.vhd:330:17 */
  assign n300 = n289 ? reg_freq_ch_d : n297;
  /*# scc_wave2.vhd:340:34 */
  assign n301 = reg_freq_ch_e[11:3]; // extract
  /*# scc_wave2.vhd:340:48 */
  assign n303 = n301 == 9'b000000000;
  /*# scc_wave2.vhd:340:62 */
  assign n304 = n303 | ff_rst_ch_e;
  /*# scc_wave2.vhd:343:36 */
  assign n306 = n233_ff_cnt_ch_e == 12'b000000000000;
  /*# scc_wave2.vhd:344:48 */
  assign n308 = ff_ptr_ch_e + 5'b00001;
  /*# scc_wave2.vhd:347:48 */
  assign n310 = n233_ff_cnt_ch_e - 12'b000000000001;
  /*# scc_wave2.vhd:343:17 */
  assign n311 = n306 ? n308 : ff_ptr_ch_e;
  /*# scc_wave2.vhd:343:17 */
  assign n312 = n306 ? reg_freq_ch_e : n310;
  /*# scc_wave2.vhd:340:17 */
  assign n314 = n304 ? 5'b00000 : n311;
  /*# scc_wave2.vhd:340:17 */
  assign n315 = n304 ? reg_freq_ch_e : n312;
  /*# scc_wave2.vhd:357:41 */
  assign n357 = w_wave_ce ? adr : n362;
  /*# scc_wave2.vhd:358:24 */
  assign n359 = {3'b000, ff_ptr_ch_a};
  /*# scc_wave2.vhd:358:57 */
  assign n361 = ff_ch_num == 3'b000;
  /*# scc_wave2.vhd:357:66 */
  assign n362 = n361 ? n359 : n367;
  /*# scc_wave2.vhd:359:24 */
  assign n364 = {3'b001, ff_ptr_ch_b};
  /*# scc_wave2.vhd:359:57 */
  assign n366 = ff_ch_num == 3'b001;
  /*# scc_wave2.vhd:358:66 */
  assign n367 = n366 ? n364 : n372;
  /*# scc_wave2.vhd:360:24 */
  assign n369 = {3'b010, ff_ptr_ch_c};
  /*# scc_wave2.vhd:360:57 */
  assign n371 = ff_ch_num == 3'b010;
  /*# scc_wave2.vhd:359:66 */
  assign n372 = n371 ? n369 : n377;
  /*# scc_wave2.vhd:361:24 */
  assign n374 = {3'b011, ff_ptr_ch_d};
  /*# scc_wave2.vhd:361:57 */
  assign n376 = ff_ch_num == 3'b011;
  /*# scc_wave2.vhd:360:66 */
  assign n377 = n376 ? n374 : n380;
  /*# scc_wave2.vhd:362:24 */
  assign n379 = {3'b100, ff_ptr_ch_e};
  /*# scc_wave2.vhd:361:66 */
  assign n380 = sccplus ? n379 : n382;
  /*# scc_wave2.vhd:363:24 */
  assign n382 = {3'b011, ff_ptr_ch_e};
  /*# scc_wave2.vhd:365:5 */
  ram_Brtl wavemem (
    .adr(w_wave_adr),
    .clk(clk21m),
    .we(w_wave_we),
    .dbo(dbo),
    .dbi(wavemem_n383));
  /*# scc_wave2.vhd:409:17 */
  assign n412 = ff_ch_num_dl == 3'b001;
  /*# scc_wave2.vhd:410:17 */
  assign n415 = ff_ch_num_dl == 3'b010;
  /*# scc_wave2.vhd:411:17 */
  assign n418 = ff_ch_num_dl == 3'b011;
  /*# scc_wave2.vhd:412:17 */
  assign n421 = ff_ch_num_dl == 3'b100;
  /*# scc_wave2.vhd:413:17 */
  assign n424 = ff_ch_num_dl == 3'b101;
  /*# scc_wave2.vhd:408:5 */
  assign n426 = {n424, n421, n418, n415, n412};
  /*# scc_wave2.vhd:408:5 */
  always @*
    case (n426)
      5'b10000: n427 = 5'b10000;
      5'b01000: n427 = 5'b01000;
      5'b00100: n427 = 5'b00100;
      5'b00010: n427 = 5'b00010;
      5'b00001: n427 = 5'b00001;
      default: n427 = 5'b00000;
    endcase
  /*# scc_wave2.vhd:416:30 */
  assign n428 = w_ch_dec[0]; // extract
  /*# scc_wave2.vhd:416:48 */
  assign n429 = reg_ch_sel[0]; // extract
  /*# scc_wave2.vhd:416:34 */
  assign n430 = n428 & n429;
  /*# scc_wave2.vhd:417:30 */
  assign n431 = w_ch_dec[1]; // extract
  /*# scc_wave2.vhd:417:48 */
  assign n432 = reg_ch_sel[1]; // extract
  /*# scc_wave2.vhd:417:34 */
  assign n433 = n431 & n432;
  /*# scc_wave2.vhd:416:53 */
  assign n434 = n430 | n433;
  /*# scc_wave2.vhd:418:30 */
  assign n435 = w_ch_dec[2]; // extract
  /*# scc_wave2.vhd:418:48 */
  assign n436 = reg_ch_sel[2]; // extract
  /*# scc_wave2.vhd:418:34 */
  assign n437 = n435 & n436;
  /*# scc_wave2.vhd:417:53 */
  assign n438 = n434 | n437;
  /*# scc_wave2.vhd:419:30 */
  assign n439 = w_ch_dec[3]; // extract
  /*# scc_wave2.vhd:419:48 */
  assign n440 = reg_ch_sel[3]; // extract
  /*# scc_wave2.vhd:419:34 */
  assign n441 = n439 & n440;
  /*# scc_wave2.vhd:418:53 */
  assign n442 = n438 | n441;
  /*# scc_wave2.vhd:420:30 */
  assign n443 = w_ch_dec[4]; // extract
  /*# scc_wave2.vhd:420:48 */
  assign n444 = reg_ch_sel[4]; // extract
  /*# scc_wave2.vhd:420:34 */
  assign n445 = n443 & n444;
  /*# scc_wave2.vhd:419:53 */
  assign n446 = n442 | n445;
  /*# scc_wave2.vhd:422:21 */
  assign n447 = {w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit};
  /*# scc_wave2.vhd:425:29 */
  assign n449 = ff_ch_num_dl == 3'b001;
  /*# scc_wave2.vhd:426:29 */
  assign n451 = ff_ch_num_dl == 3'b010;
  /*# scc_wave2.vhd:427:29 */
  assign n453 = ff_ch_num_dl == 3'b011;
  /*# scc_wave2.vhd:428:29 */
  assign n455 = ff_ch_num_dl == 3'b100;
  /*# scc_wave2.vhd:429:29 */
  assign n457 = ff_ch_num_dl == 3'b101;
  /*# scc_wave2.vhd:424:5 */
  assign n459 = {n457, n455, n453, n451, n449};
  /*# scc_wave2.vhd:424:5 */
  always @*
    case (n459)
      5'b10000: n460 = reg_vol_ch_e;
      5'b01000: n460 = reg_vol_ch_d;
      5'b00100: n460 = reg_vol_ch_c;
      5'b00010: n460 = reg_vol_ch_b;
      5'b00001: n460 = reg_vol_ch_a;
      default: n460 = 4'b0000;
    endcase
  /*# scc_wave2.vhd:432:28 */
  assign n461 = w_ch_mask & ff_wave_dat;
  /*# scc_wave2.vhd:442:48 */
  assign n463 = {1'b0, w_ch_vol};
  /*# scc_wave2.vhd:442:35 */
  assign n464 = {{5{w_wave[7]}}, w_wave}; // sext
  /*# scc_wave2.vhd:442:35 */
  assign n465 = {{8{n463[4]}}, n463}; // sext
  /*# scc_wave2.vhd:442:35 */
  assign n466 = $signed(n464) * $signed(n465); // smul
  /*# scc_wave2.vhd:443:44 */
  assign n467 = w_mul_s[11:0]; // extract
  /*# scc_wave2.vhd:486:28 */
  assign n471 = ~ff_wave_ce;
  /*# scc_wave2.vhd:487:31 */
  assign n473 = ff_ch_num == 3'b101;
  /*# scc_wave2.vhd:490:44 */
  assign n475 = ff_ch_num + 3'b001;
  /*# scc_wave2.vhd:487:17 */
  assign n477 = n473 ? 3'b000 : n475;
  /*# scc_wave2.vhd:502:31 */
  assign n486 = ~ff_wave_ce_dl;
  /*# scc_wave2.vhd:503:34 */
  assign n488 = ff_ch_num_dl == 3'b000;
  /*# scc_wave2.vhd:506:39 */
  assign n489 = w_mul[11]; // extract
  /*# scc_wave2.vhd:506:51 */
  assign n490 = w_mul[11]; // extract
  /*# scc_wave2.vhd:506:44 */
  assign n491 = {n489, n490};
  /*# scc_wave2.vhd:506:63 */
  assign n492 = w_mul[11]; // extract
  /*# scc_wave2.vhd:506:56 */
  assign n493 = {n491, n492};
  /*# scc_wave2.vhd:506:68 */
  assign n494 = {n493, w_mul};
  /*# scc_wave2.vhd:506:77 */
  assign n495 = n494 + ff_mix;
  /*# scc_wave2.vhd:503:17 */
  assign n497 = n488 ? 15'b000000000000000 : n495;
  /*# scc_wave2.vhd:518:31 */
  assign n506 = ~ff_wave_ce_dl;
  /*# scc_wave2.vhd:519:34 */
  assign n508 = ff_ch_num_dl == 3'b000;
  /*# scc_wave2.vhd:518:13 */
  assign n510 = n508 & n506;
  /*# scc_wave2.vhd:379:9 */
  assign n518 = ff_wave_ce ? ram_dbi : n519;
  /*# scc_wave2.vhd:379:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n519 <= 8'b11111111;
    else
      n519 <= n518;
  /*# scc_wave2.vhd:206:9 */
  assign n520 = n25 ? n120 : reg_freq_ch_a;
  /*# scc_wave2.vhd:206:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n521 <= 12'b000000000000;
    else
      n521 <= n520;
  /*# scc_wave2.vhd:206:9 */
  assign n522 = n25 ? n122 : reg_freq_ch_b;
  /*# scc_wave2.vhd:206:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n523 <= 12'b000000000000;
    else
      n523 <= n522;
  /*# scc_wave2.vhd:206:9 */
  assign n524 = n25 ? n124 : reg_freq_ch_c;
  /*# scc_wave2.vhd:206:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n525 <= 12'b000000000000;
    else
      n525 <= n524;
  /*# scc_wave2.vhd:206:9 */
  assign n526 = n25 ? n126 : reg_freq_ch_d;
  /*# scc_wave2.vhd:206:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n527 <= 12'b000000000000;
    else
      n527 <= n526;
  /*# scc_wave2.vhd:206:9 */
  assign n528 = n25 ? n128 : reg_freq_ch_e;
  /*# scc_wave2.vhd:206:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n529 <= 12'b000000000000;
    else
      n529 <= n528;
  /*# scc_wave2.vhd:206:9 */
  assign n530 = n25 ? n99 : reg_vol_ch_a;
  /*# scc_wave2.vhd:206:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n531 <= 4'b0000;
    else
      n531 <= n530;
  /*# scc_wave2.vhd:206:9 */
  assign n532 = n25 ? n100 : reg_vol_ch_b;
  /*# scc_wave2.vhd:206:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n533 <= 4'b0000;
    else
      n533 <= n532;
  /*# scc_wave2.vhd:206:9 */
  assign n534 = n25 ? n101 : reg_vol_ch_c;
  /*# scc_wave2.vhd:206:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n535 <= 4'b0000;
    else
      n535 <= n534;
  /*# scc_wave2.vhd:206:9 */
  assign n536 = n25 ? n102 : reg_vol_ch_d;
  /*# scc_wave2.vhd:206:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n537 <= 4'b0000;
    else
      n537 <= n536;
  /*# scc_wave2.vhd:206:9 */
  assign n538 = n25 ? n103 : reg_vol_ch_e;
  /*# scc_wave2.vhd:206:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n539 <= 4'b0000;
    else
      n539 <= n538;
  /*# scc_wave2.vhd:206:9 */
  assign n540 = n25 ? n104 : reg_ch_sel;
  /*# scc_wave2.vhd:206:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n541 <= 5'b00000;
    else
      n541 <= n540;
  /*# scc_wave2.vhd:206:9 */
  assign n542 = n145 ? dbo : reg_mode_sel;
  /*# scc_wave2.vhd:206:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n543 <= 8'b00000000;
    else
      n543 <= n542;
  /*# scc_wave2.vhd:206:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n544 <= 1'b0;
    else
      n544 <= n136;
  /*# scc_wave2.vhd:206:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n545 <= 1'b0;
    else
      n545 <= n137;
  /*# scc_wave2.vhd:206:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n546 <= 1'b0;
    else
      n546 <= n138;
  /*# scc_wave2.vhd:206:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n547 <= 1'b0;
    else
      n547 <= n139;
  /*# scc_wave2.vhd:206:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n548 <= 1'b0;
    else
      n548 <= n140;
  /*# scc_wave2.vhd:297:9 */
  assign n549 = clkena ? n254 : ff_ptr_ch_a;
  /*# scc_wave2.vhd:297:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n550 <= 5'b00000;
    else
      n550 <= n549;
  /*# scc_wave2.vhd:297:9 */
  assign n551 = clkena ? n269 : ff_ptr_ch_b;
  /*# scc_wave2.vhd:297:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n552 <= 5'b00000;
    else
      n552 <= n551;
  /*# scc_wave2.vhd:297:9 */
  assign n553 = clkena ? n284 : ff_ptr_ch_c;
  /*# scc_wave2.vhd:297:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n554 <= 5'b00000;
    else
      n554 <= n553;
  /*# scc_wave2.vhd:297:9 */
  assign n555 = clkena ? n299 : ff_ptr_ch_d;
  /*# scc_wave2.vhd:297:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n556 <= 5'b00000;
    else
      n556 <= n555;
  /*# scc_wave2.vhd:297:9 */
  assign n557 = clkena ? n314 : ff_ptr_ch_e;
  /*# scc_wave2.vhd:297:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n558 <= 5'b00000;
    else
      n558 <= n557;
  /*# scc_wave2.vhd:485:9 */
  assign n559 = n471 ? n477 : ff_ch_num;
  /*# scc_wave2.vhd:485:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n560 <= 3'b000;
    else
      n560 <= n559;
  /*# scc_wave2.vhd:397:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n561 <= 3'b000;
    else
      n561 <= ff_ch_num;
  /*# scc_wave2.vhd:501:9 */
  assign n562 = n486 ? n497 : ff_mix;
  /*# scc_wave2.vhd:501:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n563 <= 15'b000000000000000;
    else
      n563 <= n562;
  /*# scc_wave2.vhd:397:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n564 <= 1'b0;
    else
      n564 <= w_wave_ce;
  /*# scc_wave2.vhd:397:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n565 <= 1'b0;
    else
      n565 <= ff_wave_ce;
  /*# scc_wave2.vhd:206:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n566 <= 1'b0;
    else
      n566 <= req;
  /*# scc_wave2.vhd:397:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n567 <= 8'b00000000;
    else
      n567 <= ram_dbi;
  /*# scc_wave2.vhd:517:9 */
  assign n568 = n510 ? ff_mix : ff_wave;
  /*# scc_wave2.vhd:517:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n569 <= 15'b000000000000000;
    else
      n569 <= n568;
  /*# scc_wave2.vhd:297:9 */
  assign n570 = clkena ? n255 : n233_ff_cnt_ch_a;
  /*# scc_wave2.vhd:297:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n571 <= 12'b000000000000;
    else
      n571 <= n570;
  /*# scc_wave2.vhd:297:9 */
  assign n572 = clkena ? n270 : n233_ff_cnt_ch_b;
  /*# scc_wave2.vhd:297:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n573 <= 12'b000000000000;
    else
      n573 <= n572;
  /*# scc_wave2.vhd:297:9 */
  assign n574 = clkena ? n285 : n233_ff_cnt_ch_c;
  /*# scc_wave2.vhd:297:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n575 <= 12'b000000000000;
    else
      n575 <= n574;
  /*# scc_wave2.vhd:297:9 */
  assign n576 = clkena ? n300 : n233_ff_cnt_ch_d;
  /*# scc_wave2.vhd:297:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n577 <= 12'b000000000000;
    else
      n577 <= n576;
  /*# scc_wave2.vhd:297:9 */
  assign n578 = clkena ? n315 : n233_ff_cnt_ch_e;
  /*# scc_wave2.vhd:297:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n579 <= 12'b000000000000;
    else
      n579 <= n578;
endmodule

