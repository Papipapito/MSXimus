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
//   fpga/src/ocm/scc_wave2.vhd            (md5 c6a34f8b7927e63f0ad1269f4c54a3e3)
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
//   scc_wave2   -- top, MISMO nombre y port map que la entity VHDL
//                  (incl. los 3 puertos de debug _46dbg: dbg_vol_nz,
//                   dbg_sel_nz, dbg_freq_nz; y el _49dbg dbg_ptr_lsb =
//                   LSB de ff_ptr_ch_a, togglea en CADA avance del puntero
//                   de onda del canal A -> LED duty ~50% si el tono corre)
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
//     verbatim de top.v:240-328) y chip a clk_27m: 21 checks + check de
//     avance del puntero (cambios de valor de scc_wav + toggles dbg_ptr_lsb).
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
  reg [7:0] n588;
  wire [7:0] n589; // mem_rd
  assign dbi = n589; //(module output)
  /*# ram.vhd:50:10 */
  assign iadr = n588; // (signal)
  /*# ram.vhd:56:5 */
  always @(posedge clk)
    n588 <= adr;
  reg [7:0] blkram[255:0] ; // memory
  assign n589 = blkram[iadr];
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
   output dbg_ptr_lsb);
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
  wire n10;
  wire n11;
  wire n12;
  wire n13;
  wire [2:0] n14;
  wire n16;
  wire n17;
  wire [2:0] n18;
  wire n20;
  wire n21;
  wire n22;
  wire n23;
  wire [3:0] n24;
  wire n25;
  wire n27;
  wire [3:0] n28;
  wire n29;
  wire n31;
  wire n32;
  wire n34;
  wire [3:0] n35;
  wire n36;
  wire n38;
  wire n39;
  wire n41;
  wire [3:0] n42;
  wire n43;
  wire n45;
  wire n46;
  wire n48;
  wire [3:0] n49;
  wire n50;
  wire n52;
  wire n53;
  wire n55;
  wire [3:0] n56;
  wire n57;
  wire n59;
  wire [3:0] n60;
  wire n62;
  wire [3:0] n63;
  wire n65;
  wire [3:0] n66;
  wire n68;
  wire [3:0] n69;
  wire n71;
  wire [3:0] n72;
  wire n74;
  wire [4:0] n75;
  wire [14:0] n76;
  wire [7:0] n77;
  reg [7:0] n78;
  wire [3:0] n79;
  reg [3:0] n80;
  wire [7:0] n81;
  reg [7:0] n82;
  wire [3:0] n83;
  reg [3:0] n84;
  wire [7:0] n85;
  reg [7:0] n86;
  wire [3:0] n87;
  reg [3:0] n88;
  wire [7:0] n89;
  reg [7:0] n90;
  wire [3:0] n91;
  reg [3:0] n92;
  wire [7:0] n93;
  reg [7:0] n94;
  wire [3:0] n95;
  reg [3:0] n96;
  reg [3:0] n97;
  reg [3:0] n98;
  reg [3:0] n99;
  reg [3:0] n100;
  reg [3:0] n101;
  reg [4:0] n102;
  reg n103;
  reg n104;
  reg n105;
  reg n106;
  reg n107;
  wire n109;
  wire n111;
  wire n113;
  wire n115;
  wire n117;
  wire [11:0] n118;
  wire [11:0] n120;
  wire [11:0] n122;
  wire [11:0] n124;
  wire [11:0] n126;
  wire n134;
  wire n135;
  wire n136;
  wire n137;
  wire n138;
  wire n139;
  wire [2:0] n140;
  wire n142;
  wire n143;
  wire n201;
  wire n202;
  wire n203;
  wire n205;
  wire n206;
  wire n207;
  wire n211;
  wire n212;
  wire n216;
  wire n217;
  wire n221;
  wire n222;
  wire n224;
  reg [11:0] n225_ff_cnt_ch_a;
  reg [11:0] n225_ff_cnt_ch_b;
  reg [11:0] n225_ff_cnt_ch_c;
  reg [11:0] n225_ff_cnt_ch_d;
  reg [11:0] n225_ff_cnt_ch_e;
  wire [8:0] n233;
  wire n235;
  wire n236;
  wire n238;
  wire [4:0] n240;
  wire [11:0] n242;
  wire [4:0] n243;
  wire [11:0] n244;
  wire [4:0] n246;
  wire [11:0] n247;
  wire [8:0] n248;
  wire n250;
  wire n251;
  wire n253;
  wire [4:0] n255;
  wire [11:0] n257;
  wire [4:0] n258;
  wire [11:0] n259;
  wire [4:0] n261;
  wire [11:0] n262;
  wire [8:0] n263;
  wire n265;
  wire n266;
  wire n268;
  wire [4:0] n270;
  wire [11:0] n272;
  wire [4:0] n273;
  wire [11:0] n274;
  wire [4:0] n276;
  wire [11:0] n277;
  wire [8:0] n278;
  wire n280;
  wire n281;
  wire n283;
  wire [4:0] n285;
  wire [11:0] n287;
  wire [4:0] n288;
  wire [11:0] n289;
  wire [4:0] n291;
  wire [11:0] n292;
  wire [8:0] n293;
  wire n295;
  wire n296;
  wire n298;
  wire [4:0] n300;
  wire [11:0] n302;
  wire [4:0] n303;
  wire [11:0] n304;
  wire [4:0] n306;
  wire [11:0] n307;
  wire [7:0] n349;
  wire [7:0] n351;
  wire n353;
  wire [7:0] n354;
  wire [7:0] n356;
  wire n358;
  wire [7:0] n359;
  wire [7:0] n361;
  wire n363;
  wire [7:0] n364;
  wire [7:0] n366;
  wire n368;
  wire [7:0] n369;
  wire [7:0] n371;
  wire [7:0] n372;
  wire [7:0] n374;
  wire [7:0] wavemem_n375;
  wire n404;
  wire n407;
  wire n410;
  wire n413;
  wire n416;
  wire [4:0] n418;
  reg [4:0] n419;
  wire n420;
  wire n421;
  wire n422;
  wire n423;
  wire n424;
  wire n425;
  wire n426;
  wire n427;
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
  wire [7:0] n439;
  wire n441;
  wire n443;
  wire n445;
  wire n447;
  wire n449;
  wire [4:0] n451;
  reg [3:0] n452;
  wire [7:0] n453;
  wire [4:0] n455;
  wire [12:0] n456;
  wire [12:0] n457;
  wire [12:0] n458;
  wire [11:0] n459;
  wire n463;
  wire n465;
  wire [2:0] n467;
  wire [2:0] n469;
  wire n478;
  wire n480;
  wire n481;
  wire n482;
  wire [1:0] n483;
  wire n484;
  wire [2:0] n485;
  wire [14:0] n486;
  wire [14:0] n487;
  wire [14:0] n489;
  wire n498;
  wire n500;
  wire n502;
  wire [7:0] n510;
  reg [7:0] n511;
  wire [11:0] n512;
  reg [11:0] n513;
  wire [11:0] n514;
  reg [11:0] n515;
  wire [11:0] n516;
  reg [11:0] n517;
  wire [11:0] n518;
  reg [11:0] n519;
  wire [11:0] n520;
  reg [11:0] n521;
  wire [3:0] n522;
  reg [3:0] n523;
  wire [3:0] n524;
  reg [3:0] n525;
  wire [3:0] n526;
  reg [3:0] n527;
  wire [3:0] n528;
  reg [3:0] n529;
  wire [3:0] n530;
  reg [3:0] n531;
  wire [4:0] n532;
  reg [4:0] n533;
  wire [7:0] n534;
  reg [7:0] n535;
  reg n536;
  reg n537;
  reg n538;
  reg n539;
  reg n540;
  wire [4:0] n541;
  reg [4:0] n542;
  wire [4:0] n543;
  reg [4:0] n544;
  wire [4:0] n545;
  reg [4:0] n546;
  wire [4:0] n547;
  reg [4:0] n548;
  wire [4:0] n549;
  reg [4:0] n550;
  wire [2:0] n551;
  reg [2:0] n552;
  reg [2:0] n553;
  wire [14:0] n554;
  reg [14:0] n555;
  reg n556;
  reg n557;
  reg n558;
  reg [7:0] n559;
  wire [14:0] n560;
  reg [14:0] n561;
  wire [11:0] n562;
  reg [11:0] n563;
  wire [11:0] n564;
  reg [11:0] n565;
  wire [11:0] n566;
  reg [11:0] n567;
  wire [11:0] n568;
  reg [11:0] n569;
  wire [11:0] n570;
  reg [11:0] n571;
  assign ack = ff_req_dl; //(module output)
  assign dbi = n511; //(module output)
  assign wave = ff_wave; //(module output)
  assign dbg_vol_nz = n212; //(module output)
  assign dbg_sel_nz = n217; //(module output)
  assign dbg_freq_nz = n222; //(module output)
  assign dbg_ptr_lsb = n224; //(module output)
  /*# scc_wave2.vhd:124:12 */
  assign w_wave_ce = n203; // (signal)
  /*# scc_wave2.vhd:125:12 */
  assign w_wave_we = n207; // (signal)
  /*# scc_wave2.vhd:126:12 */
  assign w_wave_adr = n349; // (signal)
  /*# scc_wave2.vhd:127:12 */
  assign w_ch_dec = n419; // (signal)
  /*# scc_wave2.vhd:128:12 */
  assign w_ch_bit = n438; // (signal)
  /*# scc_wave2.vhd:129:12 */
  assign w_ch_mask = n439; // (signal)
  /*# scc_wave2.vhd:130:12 */
  assign w_ch_vol = n452; // (signal)
  /*# scc_wave2.vhd:131:12 */
  assign w_wave = n453; // (signal)
  /*# scc_wave2.vhd:132:12 */
  assign w_mul = n459; // (signal)
  /*# scc_wave2.vhd:133:12 */
  assign w_mul_s = n458; // (signal)
  /*# scc_wave2.vhd:134:12 */
  assign ram_dbi = wavemem_n375; // (signal)
  /*# scc_wave2.vhd:140:12 */
  assign reg_freq_ch_a = n513; // (signal)
  /*# scc_wave2.vhd:141:12 */
  assign reg_freq_ch_b = n515; // (signal)
  /*# scc_wave2.vhd:142:12 */
  assign reg_freq_ch_c = n517; // (signal)
  /*# scc_wave2.vhd:143:12 */
  assign reg_freq_ch_d = n519; // (signal)
  /*# scc_wave2.vhd:144:12 */
  assign reg_freq_ch_e = n521; // (signal)
  /*# scc_wave2.vhd:145:12 */
  assign reg_vol_ch_a = n523; // (signal)
  /*# scc_wave2.vhd:146:12 */
  assign reg_vol_ch_b = n525; // (signal)
  /*# scc_wave2.vhd:147:12 */
  assign reg_vol_ch_c = n527; // (signal)
  /*# scc_wave2.vhd:148:12 */
  assign reg_vol_ch_d = n529; // (signal)
  /*# scc_wave2.vhd:149:12 */
  assign reg_vol_ch_e = n531; // (signal)
  /*# scc_wave2.vhd:150:12 */
  assign reg_ch_sel = n533; // (signal)
  /*# scc_wave2.vhd:151:12 */
  assign reg_mode_sel = n535; // (signal)
  /*# scc_wave2.vhd:154:12 */
  assign ff_rst_ch_a = n536; // (signal)
  /*# scc_wave2.vhd:155:12 */
  assign ff_rst_ch_b = n537; // (signal)
  /*# scc_wave2.vhd:156:12 */
  assign ff_rst_ch_c = n538; // (signal)
  /*# scc_wave2.vhd:157:12 */
  assign ff_rst_ch_d = n539; // (signal)
  /*# scc_wave2.vhd:158:12 */
  assign ff_rst_ch_e = n540; // (signal)
  /*# scc_wave2.vhd:159:12 */
  assign ff_ptr_ch_a = n542; // (signal)
  /*# scc_wave2.vhd:160:12 */
  assign ff_ptr_ch_b = n544; // (signal)
  /*# scc_wave2.vhd:161:12 */
  assign ff_ptr_ch_c = n546; // (signal)
  /*# scc_wave2.vhd:162:12 */
  assign ff_ptr_ch_d = n548; // (signal)
  /*# scc_wave2.vhd:163:12 */
  assign ff_ptr_ch_e = n550; // (signal)
  /*# scc_wave2.vhd:164:12 */
  assign ff_ch_num = n552; // (signal)
  /*# scc_wave2.vhd:165:12 */
  assign ff_ch_num_dl = n553; // (signal)
  /*# scc_wave2.vhd:166:12 */
  assign ff_mix = n555; // (signal)
  /*# scc_wave2.vhd:167:12 */
  assign ff_wave_ce = n556; // (signal)
  /*# scc_wave2.vhd:168:12 */
  assign ff_wave_ce_dl = n557; // (signal)
  /*# scc_wave2.vhd:169:12 */
  assign ff_req_dl = n558; // (signal)
  /*# scc_wave2.vhd:170:12 */
  assign ff_wave_dat = n559; // (signal)
  /*# scc_wave2.vhd:171:12 */
  assign ff_wave = n561; // (signal)
  /*# scc_wave2.vhd:205:41 */
  assign n10 = ~ff_req_dl;
  /*# scc_wave2.vhd:205:27 */
  assign n11 = n10 & req;
  /*# scc_wave2.vhd:205:47 */
  assign n12 = wrt & n11;
  /*# scc_wave2.vhd:206:27 */
  assign n13 = ~sccplus;
  /*# scc_wave2.vhd:206:40 */
  assign n14 = adr[7:5]; // extract
  /*# scc_wave2.vhd:206:53 */
  assign n16 = n14 == 3'b100;
  /*# scc_wave2.vhd:206:33 */
  assign n17 = n16 & n13;
  /*# scc_wave2.vhd:207:40 */
  assign n18 = adr[7:5]; // extract
  /*# scc_wave2.vhd:207:53 */
  assign n20 = n18 == 3'b101;
  /*# scc_wave2.vhd:207:33 */
  assign n21 = n20 & sccplus;
  /*# scc_wave2.vhd:206:62 */
  assign n22 = n17 | n21;
  /*# scc_wave2.vhd:205:61 */
  assign n23 = n22 & n12;
  /*# scc_wave2.vhd:208:25 */
  assign n24 = adr[3:0]; // extract
  /*# scc_wave2.vhd:209:114 */
  assign n25 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:209:21 */
  assign n27 = n24 == 4'b0000;
  /*# scc_wave2.vhd:210:71 */
  assign n28 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:210:114 */
  assign n29 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:210:21 */
  assign n31 = n24 == 4'b0001;
  /*# scc_wave2.vhd:211:114 */
  assign n32 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:211:21 */
  assign n34 = n24 == 4'b0010;
  /*# scc_wave2.vhd:212:71 */
  assign n35 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:212:114 */
  assign n36 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:212:21 */
  assign n38 = n24 == 4'b0011;
  /*# scc_wave2.vhd:213:114 */
  assign n39 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:213:21 */
  assign n41 = n24 == 4'b0100;
  /*# scc_wave2.vhd:214:71 */
  assign n42 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:214:114 */
  assign n43 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:214:21 */
  assign n45 = n24 == 4'b0101;
  /*# scc_wave2.vhd:215:114 */
  assign n46 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:215:21 */
  assign n48 = n24 == 4'b0110;
  /*# scc_wave2.vhd:216:71 */
  assign n49 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:216:114 */
  assign n50 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:216:21 */
  assign n52 = n24 == 4'b0111;
  /*# scc_wave2.vhd:217:114 */
  assign n53 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:217:21 */
  assign n55 = n24 == 4'b1000;
  /*# scc_wave2.vhd:218:71 */
  assign n56 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:218:114 */
  assign n57 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:218:21 */
  assign n59 = n24 == 4'b1001;
  /*# scc_wave2.vhd:219:71 */
  assign n60 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:219:21 */
  assign n62 = n24 == 4'b1010;
  /*# scc_wave2.vhd:220:71 */
  assign n63 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:220:21 */
  assign n65 = n24 == 4'b1011;
  /*# scc_wave2.vhd:221:71 */
  assign n66 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:221:21 */
  assign n68 = n24 == 4'b1100;
  /*# scc_wave2.vhd:222:71 */
  assign n69 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:222:21 */
  assign n71 = n24 == 4'b1101;
  /*# scc_wave2.vhd:223:71 */
  assign n72 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:223:21 */
  assign n74 = n24 == 4'b1110;
  /*# scc_wave2.vhd:224:71 */
  assign n75 = dbo[4:0]; // extract
  /*# scc_wave2.vhd:208:17 */
  assign n76 = {n74, n71, n68, n65, n62, n59, n55, n52, n48, n45, n41, n38, n34, n31, n27};
  /*# scc_wave2.vhd:140:12 */
  assign n77 = reg_freq_ch_a[7:0]; // extract
  /*# scc_wave2.vhd:208:17 */
  always @*
    case (n76)
      15'b100000000000000: n78 = n77;
      15'b010000000000000: n78 = n77;
      15'b001000000000000: n78 = n77;
      15'b000100000000000: n78 = n77;
      15'b000010000000000: n78 = n77;
      15'b000001000000000: n78 = n77;
      15'b000000100000000: n78 = n77;
      15'b000000010000000: n78 = n77;
      15'b000000001000000: n78 = n77;
      15'b000000000100000: n78 = n77;
      15'b000000000010000: n78 = n77;
      15'b000000000001000: n78 = n77;
      15'b000000000000100: n78 = n77;
      15'b000000000000010: n78 = n77;
      15'b000000000000001: n78 = dbo;
      default: n78 = n77;
    endcase
  /*# scc_wave2.vhd:140:12 */
  assign n79 = reg_freq_ch_a[11:8]; // extract
  /*# scc_wave2.vhd:208:17 */
  always @*
    case (n76)
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
      15'b000000000000010: n80 = n28;
      15'b000000000000001: n80 = n79;
      default: n80 = n79;
    endcase
  /*# scc_wave2.vhd:141:12 */
  assign n81 = reg_freq_ch_b[7:0]; // extract
  /*# scc_wave2.vhd:208:17 */
  always @*
    case (n76)
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
      15'b000000000000100: n82 = dbo;
      15'b000000000000010: n82 = n81;
      15'b000000000000001: n82 = n81;
      default: n82 = n81;
    endcase
  /*# scc_wave2.vhd:141:12 */
  assign n83 = reg_freq_ch_b[11:8]; // extract
  /*# scc_wave2.vhd:208:17 */
  always @*
    case (n76)
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
      15'b000000000001000: n84 = n35;
      15'b000000000000100: n84 = n83;
      15'b000000000000010: n84 = n83;
      15'b000000000000001: n84 = n83;
      default: n84 = n83;
    endcase
  /*# scc_wave2.vhd:142:12 */
  assign n85 = reg_freq_ch_c[7:0]; // extract
  /*# scc_wave2.vhd:208:17 */
  always @*
    case (n76)
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
      15'b000000000010000: n86 = dbo;
      15'b000000000001000: n86 = n85;
      15'b000000000000100: n86 = n85;
      15'b000000000000010: n86 = n85;
      15'b000000000000001: n86 = n85;
      default: n86 = n85;
    endcase
  /*# scc_wave2.vhd:142:12 */
  assign n87 = reg_freq_ch_c[11:8]; // extract
  /*# scc_wave2.vhd:208:17 */
  always @*
    case (n76)
      15'b100000000000000: n88 = n87;
      15'b010000000000000: n88 = n87;
      15'b001000000000000: n88 = n87;
      15'b000100000000000: n88 = n87;
      15'b000010000000000: n88 = n87;
      15'b000001000000000: n88 = n87;
      15'b000000100000000: n88 = n87;
      15'b000000010000000: n88 = n87;
      15'b000000001000000: n88 = n87;
      15'b000000000100000: n88 = n42;
      15'b000000000010000: n88 = n87;
      15'b000000000001000: n88 = n87;
      15'b000000000000100: n88 = n87;
      15'b000000000000010: n88 = n87;
      15'b000000000000001: n88 = n87;
      default: n88 = n87;
    endcase
  /*# scc_wave2.vhd:143:12 */
  assign n89 = reg_freq_ch_d[7:0]; // extract
  /*# scc_wave2.vhd:208:17 */
  always @*
    case (n76)
      15'b100000000000000: n90 = n89;
      15'b010000000000000: n90 = n89;
      15'b001000000000000: n90 = n89;
      15'b000100000000000: n90 = n89;
      15'b000010000000000: n90 = n89;
      15'b000001000000000: n90 = n89;
      15'b000000100000000: n90 = n89;
      15'b000000010000000: n90 = n89;
      15'b000000001000000: n90 = dbo;
      15'b000000000100000: n90 = n89;
      15'b000000000010000: n90 = n89;
      15'b000000000001000: n90 = n89;
      15'b000000000000100: n90 = n89;
      15'b000000000000010: n90 = n89;
      15'b000000000000001: n90 = n89;
      default: n90 = n89;
    endcase
  /*# scc_wave2.vhd:143:12 */
  assign n91 = reg_freq_ch_d[11:8]; // extract
  /*# scc_wave2.vhd:208:17 */
  always @*
    case (n76)
      15'b100000000000000: n92 = n91;
      15'b010000000000000: n92 = n91;
      15'b001000000000000: n92 = n91;
      15'b000100000000000: n92 = n91;
      15'b000010000000000: n92 = n91;
      15'b000001000000000: n92 = n91;
      15'b000000100000000: n92 = n91;
      15'b000000010000000: n92 = n49;
      15'b000000001000000: n92 = n91;
      15'b000000000100000: n92 = n91;
      15'b000000000010000: n92 = n91;
      15'b000000000001000: n92 = n91;
      15'b000000000000100: n92 = n91;
      15'b000000000000010: n92 = n91;
      15'b000000000000001: n92 = n91;
      default: n92 = n91;
    endcase
  /*# scc_wave2.vhd:144:12 */
  assign n93 = reg_freq_ch_e[7:0]; // extract
  /*# scc_wave2.vhd:208:17 */
  always @*
    case (n76)
      15'b100000000000000: n94 = n93;
      15'b010000000000000: n94 = n93;
      15'b001000000000000: n94 = n93;
      15'b000100000000000: n94 = n93;
      15'b000010000000000: n94 = n93;
      15'b000001000000000: n94 = n93;
      15'b000000100000000: n94 = dbo;
      15'b000000010000000: n94 = n93;
      15'b000000001000000: n94 = n93;
      15'b000000000100000: n94 = n93;
      15'b000000000010000: n94 = n93;
      15'b000000000001000: n94 = n93;
      15'b000000000000100: n94 = n93;
      15'b000000000000010: n94 = n93;
      15'b000000000000001: n94 = n93;
      default: n94 = n93;
    endcase
  /*# scc_wave2.vhd:144:12 */
  assign n95 = reg_freq_ch_e[11:8]; // extract
  /*# scc_wave2.vhd:208:17 */
  always @*
    case (n76)
      15'b100000000000000: n96 = n95;
      15'b010000000000000: n96 = n95;
      15'b001000000000000: n96 = n95;
      15'b000100000000000: n96 = n95;
      15'b000010000000000: n96 = n95;
      15'b000001000000000: n96 = n56;
      15'b000000100000000: n96 = n95;
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
  /*# scc_wave2.vhd:208:17 */
  always @*
    case (n76)
      15'b100000000000000: n97 = reg_vol_ch_a;
      15'b010000000000000: n97 = reg_vol_ch_a;
      15'b001000000000000: n97 = reg_vol_ch_a;
      15'b000100000000000: n97 = reg_vol_ch_a;
      15'b000010000000000: n97 = n60;
      15'b000001000000000: n97 = reg_vol_ch_a;
      15'b000000100000000: n97 = reg_vol_ch_a;
      15'b000000010000000: n97 = reg_vol_ch_a;
      15'b000000001000000: n97 = reg_vol_ch_a;
      15'b000000000100000: n97 = reg_vol_ch_a;
      15'b000000000010000: n97 = reg_vol_ch_a;
      15'b000000000001000: n97 = reg_vol_ch_a;
      15'b000000000000100: n97 = reg_vol_ch_a;
      15'b000000000000010: n97 = reg_vol_ch_a;
      15'b000000000000001: n97 = reg_vol_ch_a;
      default: n97 = reg_vol_ch_a;
    endcase
  /*# scc_wave2.vhd:208:17 */
  always @*
    case (n76)
      15'b100000000000000: n98 = reg_vol_ch_b;
      15'b010000000000000: n98 = reg_vol_ch_b;
      15'b001000000000000: n98 = reg_vol_ch_b;
      15'b000100000000000: n98 = n63;
      15'b000010000000000: n98 = reg_vol_ch_b;
      15'b000001000000000: n98 = reg_vol_ch_b;
      15'b000000100000000: n98 = reg_vol_ch_b;
      15'b000000010000000: n98 = reg_vol_ch_b;
      15'b000000001000000: n98 = reg_vol_ch_b;
      15'b000000000100000: n98 = reg_vol_ch_b;
      15'b000000000010000: n98 = reg_vol_ch_b;
      15'b000000000001000: n98 = reg_vol_ch_b;
      15'b000000000000100: n98 = reg_vol_ch_b;
      15'b000000000000010: n98 = reg_vol_ch_b;
      15'b000000000000001: n98 = reg_vol_ch_b;
      default: n98 = reg_vol_ch_b;
    endcase
  /*# scc_wave2.vhd:208:17 */
  always @*
    case (n76)
      15'b100000000000000: n99 = reg_vol_ch_c;
      15'b010000000000000: n99 = reg_vol_ch_c;
      15'b001000000000000: n99 = n66;
      15'b000100000000000: n99 = reg_vol_ch_c;
      15'b000010000000000: n99 = reg_vol_ch_c;
      15'b000001000000000: n99 = reg_vol_ch_c;
      15'b000000100000000: n99 = reg_vol_ch_c;
      15'b000000010000000: n99 = reg_vol_ch_c;
      15'b000000001000000: n99 = reg_vol_ch_c;
      15'b000000000100000: n99 = reg_vol_ch_c;
      15'b000000000010000: n99 = reg_vol_ch_c;
      15'b000000000001000: n99 = reg_vol_ch_c;
      15'b000000000000100: n99 = reg_vol_ch_c;
      15'b000000000000010: n99 = reg_vol_ch_c;
      15'b000000000000001: n99 = reg_vol_ch_c;
      default: n99 = reg_vol_ch_c;
    endcase
  /*# scc_wave2.vhd:208:17 */
  always @*
    case (n76)
      15'b100000000000000: n100 = reg_vol_ch_d;
      15'b010000000000000: n100 = n69;
      15'b001000000000000: n100 = reg_vol_ch_d;
      15'b000100000000000: n100 = reg_vol_ch_d;
      15'b000010000000000: n100 = reg_vol_ch_d;
      15'b000001000000000: n100 = reg_vol_ch_d;
      15'b000000100000000: n100 = reg_vol_ch_d;
      15'b000000010000000: n100 = reg_vol_ch_d;
      15'b000000001000000: n100 = reg_vol_ch_d;
      15'b000000000100000: n100 = reg_vol_ch_d;
      15'b000000000010000: n100 = reg_vol_ch_d;
      15'b000000000001000: n100 = reg_vol_ch_d;
      15'b000000000000100: n100 = reg_vol_ch_d;
      15'b000000000000010: n100 = reg_vol_ch_d;
      15'b000000000000001: n100 = reg_vol_ch_d;
      default: n100 = reg_vol_ch_d;
    endcase
  /*# scc_wave2.vhd:208:17 */
  always @*
    case (n76)
      15'b100000000000000: n101 = n72;
      15'b010000000000000: n101 = reg_vol_ch_e;
      15'b001000000000000: n101 = reg_vol_ch_e;
      15'b000100000000000: n101 = reg_vol_ch_e;
      15'b000010000000000: n101 = reg_vol_ch_e;
      15'b000001000000000: n101 = reg_vol_ch_e;
      15'b000000100000000: n101 = reg_vol_ch_e;
      15'b000000010000000: n101 = reg_vol_ch_e;
      15'b000000001000000: n101 = reg_vol_ch_e;
      15'b000000000100000: n101 = reg_vol_ch_e;
      15'b000000000010000: n101 = reg_vol_ch_e;
      15'b000000000001000: n101 = reg_vol_ch_e;
      15'b000000000000100: n101 = reg_vol_ch_e;
      15'b000000000000010: n101 = reg_vol_ch_e;
      15'b000000000000001: n101 = reg_vol_ch_e;
      default: n101 = reg_vol_ch_e;
    endcase
  /*# scc_wave2.vhd:208:17 */
  always @*
    case (n76)
      15'b100000000000000: n102 = reg_ch_sel;
      15'b010000000000000: n102 = reg_ch_sel;
      15'b001000000000000: n102 = reg_ch_sel;
      15'b000100000000000: n102 = reg_ch_sel;
      15'b000010000000000: n102 = reg_ch_sel;
      15'b000001000000000: n102 = reg_ch_sel;
      15'b000000100000000: n102 = reg_ch_sel;
      15'b000000010000000: n102 = reg_ch_sel;
      15'b000000001000000: n102 = reg_ch_sel;
      15'b000000000100000: n102 = reg_ch_sel;
      15'b000000000010000: n102 = reg_ch_sel;
      15'b000000000001000: n102 = reg_ch_sel;
      15'b000000000000100: n102 = reg_ch_sel;
      15'b000000000000010: n102 = reg_ch_sel;
      15'b000000000000001: n102 = reg_ch_sel;
      default: n102 = n75;
    endcase
  /*# scc_wave2.vhd:208:17 */
  always @*
    case (n76)
      15'b100000000000000: n103 = ff_rst_ch_a;
      15'b010000000000000: n103 = ff_rst_ch_a;
      15'b001000000000000: n103 = ff_rst_ch_a;
      15'b000100000000000: n103 = ff_rst_ch_a;
      15'b000010000000000: n103 = ff_rst_ch_a;
      15'b000001000000000: n103 = ff_rst_ch_a;
      15'b000000100000000: n103 = ff_rst_ch_a;
      15'b000000010000000: n103 = ff_rst_ch_a;
      15'b000000001000000: n103 = ff_rst_ch_a;
      15'b000000000100000: n103 = ff_rst_ch_a;
      15'b000000000010000: n103 = ff_rst_ch_a;
      15'b000000000001000: n103 = ff_rst_ch_a;
      15'b000000000000100: n103 = ff_rst_ch_a;
      15'b000000000000010: n103 = n29;
      15'b000000000000001: n103 = n25;
      default: n103 = ff_rst_ch_a;
    endcase
  /*# scc_wave2.vhd:208:17 */
  always @*
    case (n76)
      15'b100000000000000: n104 = ff_rst_ch_b;
      15'b010000000000000: n104 = ff_rst_ch_b;
      15'b001000000000000: n104 = ff_rst_ch_b;
      15'b000100000000000: n104 = ff_rst_ch_b;
      15'b000010000000000: n104 = ff_rst_ch_b;
      15'b000001000000000: n104 = ff_rst_ch_b;
      15'b000000100000000: n104 = ff_rst_ch_b;
      15'b000000010000000: n104 = ff_rst_ch_b;
      15'b000000001000000: n104 = ff_rst_ch_b;
      15'b000000000100000: n104 = ff_rst_ch_b;
      15'b000000000010000: n104 = ff_rst_ch_b;
      15'b000000000001000: n104 = n36;
      15'b000000000000100: n104 = n32;
      15'b000000000000010: n104 = ff_rst_ch_b;
      15'b000000000000001: n104 = ff_rst_ch_b;
      default: n104 = ff_rst_ch_b;
    endcase
  /*# scc_wave2.vhd:208:17 */
  always @*
    case (n76)
      15'b100000000000000: n105 = ff_rst_ch_c;
      15'b010000000000000: n105 = ff_rst_ch_c;
      15'b001000000000000: n105 = ff_rst_ch_c;
      15'b000100000000000: n105 = ff_rst_ch_c;
      15'b000010000000000: n105 = ff_rst_ch_c;
      15'b000001000000000: n105 = ff_rst_ch_c;
      15'b000000100000000: n105 = ff_rst_ch_c;
      15'b000000010000000: n105 = ff_rst_ch_c;
      15'b000000001000000: n105 = ff_rst_ch_c;
      15'b000000000100000: n105 = n43;
      15'b000000000010000: n105 = n39;
      15'b000000000001000: n105 = ff_rst_ch_c;
      15'b000000000000100: n105 = ff_rst_ch_c;
      15'b000000000000010: n105 = ff_rst_ch_c;
      15'b000000000000001: n105 = ff_rst_ch_c;
      default: n105 = ff_rst_ch_c;
    endcase
  /*# scc_wave2.vhd:208:17 */
  always @*
    case (n76)
      15'b100000000000000: n106 = ff_rst_ch_d;
      15'b010000000000000: n106 = ff_rst_ch_d;
      15'b001000000000000: n106 = ff_rst_ch_d;
      15'b000100000000000: n106 = ff_rst_ch_d;
      15'b000010000000000: n106 = ff_rst_ch_d;
      15'b000001000000000: n106 = ff_rst_ch_d;
      15'b000000100000000: n106 = ff_rst_ch_d;
      15'b000000010000000: n106 = n50;
      15'b000000001000000: n106 = n46;
      15'b000000000100000: n106 = ff_rst_ch_d;
      15'b000000000010000: n106 = ff_rst_ch_d;
      15'b000000000001000: n106 = ff_rst_ch_d;
      15'b000000000000100: n106 = ff_rst_ch_d;
      15'b000000000000010: n106 = ff_rst_ch_d;
      15'b000000000000001: n106 = ff_rst_ch_d;
      default: n106 = ff_rst_ch_d;
    endcase
  /*# scc_wave2.vhd:208:17 */
  always @*
    case (n76)
      15'b100000000000000: n107 = ff_rst_ch_e;
      15'b010000000000000: n107 = ff_rst_ch_e;
      15'b001000000000000: n107 = ff_rst_ch_e;
      15'b000100000000000: n107 = ff_rst_ch_e;
      15'b000010000000000: n107 = ff_rst_ch_e;
      15'b000001000000000: n107 = n57;
      15'b000000100000000: n107 = n53;
      15'b000000010000000: n107 = ff_rst_ch_e;
      15'b000000001000000: n107 = ff_rst_ch_e;
      15'b000000000100000: n107 = ff_rst_ch_e;
      15'b000000000010000: n107 = ff_rst_ch_e;
      15'b000000000001000: n107 = ff_rst_ch_e;
      15'b000000000000100: n107 = ff_rst_ch_e;
      15'b000000000000010: n107 = ff_rst_ch_e;
      15'b000000000000001: n107 = ff_rst_ch_e;
      default: n107 = ff_rst_ch_e;
    endcase
  /*# scc_wave2.vhd:226:13 */
  assign n109 = clkena ? 1'b0 : ff_rst_ch_a;
  /*# scc_wave2.vhd:226:13 */
  assign n111 = clkena ? 1'b0 : ff_rst_ch_b;
  /*# scc_wave2.vhd:226:13 */
  assign n113 = clkena ? 1'b0 : ff_rst_ch_c;
  /*# scc_wave2.vhd:226:13 */
  assign n115 = clkena ? 1'b0 : ff_rst_ch_d;
  /*# scc_wave2.vhd:226:13 */
  assign n117 = clkena ? 1'b0 : ff_rst_ch_e;
  /*# scc_wave2.vhd:205:13 */
  assign n118 = {n80, n78};
  /*# scc_wave2.vhd:205:13 */
  assign n120 = {n84, n82};
  /*# scc_wave2.vhd:205:13 */
  assign n122 = {n88, n86};
  /*# scc_wave2.vhd:205:13 */
  assign n124 = {n92, n90};
  /*# scc_wave2.vhd:205:13 */
  assign n126 = {n96, n94};
  /*# scc_wave2.vhd:205:13 */
  assign n134 = n23 ? n103 : n109;
  /*# scc_wave2.vhd:205:13 */
  assign n135 = n23 ? n104 : n111;
  /*# scc_wave2.vhd:205:13 */
  assign n136 = n23 ? n105 : n113;
  /*# scc_wave2.vhd:205:13 */
  assign n137 = n23 ? n106 : n115;
  /*# scc_wave2.vhd:205:13 */
  assign n138 = n23 ? n107 : n117;
  /*# scc_wave2.vhd:235:27 */
  assign n139 = wrt & req;
  /*# scc_wave2.vhd:235:48 */
  assign n140 = adr[7:5]; // extract
  /*# scc_wave2.vhd:235:61 */
  assign n142 = n140 == 3'b110;
  /*# scc_wave2.vhd:235:41 */
  assign n143 = n142 & n139;
  /*# scc_wave2.vhd:244:55 */
  assign n201 = ~ff_req_dl;
  /*# scc_wave2.vhd:244:41 */
  assign n202 = n201 & req;
  /*# scc_wave2.vhd:244:25 */
  assign n203 = n202 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:245:55 */
  assign n205 = ~ff_req_dl;
  /*# scc_wave2.vhd:245:41 */
  assign n206 = n205 & req;
  /*# scc_wave2.vhd:245:25 */
  assign n207 = n206 ? wrt : 1'b0;
  /*# scc_wave2.vhd:249:44 */
  assign n211 = reg_vol_ch_a != 4'b0000;
  /*# scc_wave2.vhd:249:24 */
  assign n212 = n211 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:250:42 */
  assign n216 = reg_ch_sel != 5'b00000;
  /*# scc_wave2.vhd:250:24 */
  assign n217 = n216 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:251:45 */
  assign n221 = reg_freq_ch_a != 12'b000000000000;
  /*# scc_wave2.vhd:251:24 */
  assign n222 = n221 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:257:31 */
  assign n224 = ff_ptr_ch_a[0]; // extract
  /*# scc_wave2.vhd:263:18 */
  always @*
    n225_ff_cnt_ch_a = n563; // (isignal)
  initial
    n225_ff_cnt_ch_a = 12'bX;
  /*# scc_wave2.vhd:264:18 */
  always @*
    n225_ff_cnt_ch_b = n565; // (isignal)
  initial
    n225_ff_cnt_ch_b = 12'bX;
  /*# scc_wave2.vhd:265:18 */
  always @*
    n225_ff_cnt_ch_c = n567; // (isignal)
  initial
    n225_ff_cnt_ch_c = 12'bX;
  /*# scc_wave2.vhd:266:18 */
  always @*
    n225_ff_cnt_ch_d = n569; // (isignal)
  initial
    n225_ff_cnt_ch_d = 12'bX;
  /*# scc_wave2.vhd:267:18 */
  always @*
    n225_ff_cnt_ch_e = n571; // (isignal)
  initial
    n225_ff_cnt_ch_e = 12'bX;
  /*# scc_wave2.vhd:284:34 */
  assign n233 = reg_freq_ch_a[11:3]; // extract
  /*# scc_wave2.vhd:284:48 */
  assign n235 = n233 == 9'b000000000;
  /*# scc_wave2.vhd:284:62 */
  assign n236 = n235 | ff_rst_ch_a;
  /*# scc_wave2.vhd:287:36 */
  assign n238 = n225_ff_cnt_ch_a == 12'b000000000000;
  /*# scc_wave2.vhd:288:48 */
  assign n240 = ff_ptr_ch_a + 5'b00001;
  /*# scc_wave2.vhd:291:48 */
  assign n242 = n225_ff_cnt_ch_a - 12'b000000000001;
  /*# scc_wave2.vhd:287:17 */
  assign n243 = n238 ? n240 : ff_ptr_ch_a;
  /*# scc_wave2.vhd:287:17 */
  assign n244 = n238 ? reg_freq_ch_a : n242;
  /*# scc_wave2.vhd:284:17 */
  assign n246 = n236 ? 5'b00000 : n243;
  /*# scc_wave2.vhd:284:17 */
  assign n247 = n236 ? reg_freq_ch_a : n244;
  /*# scc_wave2.vhd:294:34 */
  assign n248 = reg_freq_ch_b[11:3]; // extract
  /*# scc_wave2.vhd:294:48 */
  assign n250 = n248 == 9'b000000000;
  /*# scc_wave2.vhd:294:62 */
  assign n251 = n250 | ff_rst_ch_b;
  /*# scc_wave2.vhd:297:36 */
  assign n253 = n225_ff_cnt_ch_b == 12'b000000000000;
  /*# scc_wave2.vhd:298:48 */
  assign n255 = ff_ptr_ch_b + 5'b00001;
  /*# scc_wave2.vhd:301:48 */
  assign n257 = n225_ff_cnt_ch_b - 12'b000000000001;
  /*# scc_wave2.vhd:297:17 */
  assign n258 = n253 ? n255 : ff_ptr_ch_b;
  /*# scc_wave2.vhd:297:17 */
  assign n259 = n253 ? reg_freq_ch_b : n257;
  /*# scc_wave2.vhd:294:17 */
  assign n261 = n251 ? 5'b00000 : n258;
  /*# scc_wave2.vhd:294:17 */
  assign n262 = n251 ? reg_freq_ch_b : n259;
  /*# scc_wave2.vhd:304:34 */
  assign n263 = reg_freq_ch_c[11:3]; // extract
  /*# scc_wave2.vhd:304:48 */
  assign n265 = n263 == 9'b000000000;
  /*# scc_wave2.vhd:304:62 */
  assign n266 = n265 | ff_rst_ch_c;
  /*# scc_wave2.vhd:307:36 */
  assign n268 = n225_ff_cnt_ch_c == 12'b000000000000;
  /*# scc_wave2.vhd:308:48 */
  assign n270 = ff_ptr_ch_c + 5'b00001;
  /*# scc_wave2.vhd:311:48 */
  assign n272 = n225_ff_cnt_ch_c - 12'b000000000001;
  /*# scc_wave2.vhd:307:17 */
  assign n273 = n268 ? n270 : ff_ptr_ch_c;
  /*# scc_wave2.vhd:307:17 */
  assign n274 = n268 ? reg_freq_ch_c : n272;
  /*# scc_wave2.vhd:304:17 */
  assign n276 = n266 ? 5'b00000 : n273;
  /*# scc_wave2.vhd:304:17 */
  assign n277 = n266 ? reg_freq_ch_c : n274;
  /*# scc_wave2.vhd:314:34 */
  assign n278 = reg_freq_ch_d[11:3]; // extract
  /*# scc_wave2.vhd:314:48 */
  assign n280 = n278 == 9'b000000000;
  /*# scc_wave2.vhd:314:62 */
  assign n281 = n280 | ff_rst_ch_d;
  /*# scc_wave2.vhd:317:36 */
  assign n283 = n225_ff_cnt_ch_d == 12'b000000000000;
  /*# scc_wave2.vhd:318:48 */
  assign n285 = ff_ptr_ch_d + 5'b00001;
  /*# scc_wave2.vhd:321:48 */
  assign n287 = n225_ff_cnt_ch_d - 12'b000000000001;
  /*# scc_wave2.vhd:317:17 */
  assign n288 = n283 ? n285 : ff_ptr_ch_d;
  /*# scc_wave2.vhd:317:17 */
  assign n289 = n283 ? reg_freq_ch_d : n287;
  /*# scc_wave2.vhd:314:17 */
  assign n291 = n281 ? 5'b00000 : n288;
  /*# scc_wave2.vhd:314:17 */
  assign n292 = n281 ? reg_freq_ch_d : n289;
  /*# scc_wave2.vhd:324:34 */
  assign n293 = reg_freq_ch_e[11:3]; // extract
  /*# scc_wave2.vhd:324:48 */
  assign n295 = n293 == 9'b000000000;
  /*# scc_wave2.vhd:324:62 */
  assign n296 = n295 | ff_rst_ch_e;
  /*# scc_wave2.vhd:327:36 */
  assign n298 = n225_ff_cnt_ch_e == 12'b000000000000;
  /*# scc_wave2.vhd:328:48 */
  assign n300 = ff_ptr_ch_e + 5'b00001;
  /*# scc_wave2.vhd:331:48 */
  assign n302 = n225_ff_cnt_ch_e - 12'b000000000001;
  /*# scc_wave2.vhd:327:17 */
  assign n303 = n298 ? n300 : ff_ptr_ch_e;
  /*# scc_wave2.vhd:327:17 */
  assign n304 = n298 ? reg_freq_ch_e : n302;
  /*# scc_wave2.vhd:324:17 */
  assign n306 = n296 ? 5'b00000 : n303;
  /*# scc_wave2.vhd:324:17 */
  assign n307 = n296 ? reg_freq_ch_e : n304;
  /*# scc_wave2.vhd:341:41 */
  assign n349 = w_wave_ce ? adr : n354;
  /*# scc_wave2.vhd:342:24 */
  assign n351 = {3'b000, ff_ptr_ch_a};
  /*# scc_wave2.vhd:342:57 */
  assign n353 = ff_ch_num == 3'b000;
  /*# scc_wave2.vhd:341:66 */
  assign n354 = n353 ? n351 : n359;
  /*# scc_wave2.vhd:343:24 */
  assign n356 = {3'b001, ff_ptr_ch_b};
  /*# scc_wave2.vhd:343:57 */
  assign n358 = ff_ch_num == 3'b001;
  /*# scc_wave2.vhd:342:66 */
  assign n359 = n358 ? n356 : n364;
  /*# scc_wave2.vhd:344:24 */
  assign n361 = {3'b010, ff_ptr_ch_c};
  /*# scc_wave2.vhd:344:57 */
  assign n363 = ff_ch_num == 3'b010;
  /*# scc_wave2.vhd:343:66 */
  assign n364 = n363 ? n361 : n369;
  /*# scc_wave2.vhd:345:24 */
  assign n366 = {3'b011, ff_ptr_ch_d};
  /*# scc_wave2.vhd:345:57 */
  assign n368 = ff_ch_num == 3'b011;
  /*# scc_wave2.vhd:344:66 */
  assign n369 = n368 ? n366 : n372;
  /*# scc_wave2.vhd:346:24 */
  assign n371 = {3'b100, ff_ptr_ch_e};
  /*# scc_wave2.vhd:345:66 */
  assign n372 = sccplus ? n371 : n374;
  /*# scc_wave2.vhd:347:24 */
  assign n374 = {3'b011, ff_ptr_ch_e};
  /*# scc_wave2.vhd:349:5 */
  ram_Brtl wavemem (
    .adr(w_wave_adr),
    .clk(clk21m),
    .we(w_wave_we),
    .dbo(dbo),
    .dbi(wavemem_n375));
  /*# scc_wave2.vhd:393:17 */
  assign n404 = ff_ch_num_dl == 3'b001;
  /*# scc_wave2.vhd:394:17 */
  assign n407 = ff_ch_num_dl == 3'b010;
  /*# scc_wave2.vhd:395:17 */
  assign n410 = ff_ch_num_dl == 3'b011;
  /*# scc_wave2.vhd:396:17 */
  assign n413 = ff_ch_num_dl == 3'b100;
  /*# scc_wave2.vhd:397:17 */
  assign n416 = ff_ch_num_dl == 3'b101;
  /*# scc_wave2.vhd:392:5 */
  assign n418 = {n416, n413, n410, n407, n404};
  /*# scc_wave2.vhd:392:5 */
  always @*
    case (n418)
      5'b10000: n419 = 5'b10000;
      5'b01000: n419 = 5'b01000;
      5'b00100: n419 = 5'b00100;
      5'b00010: n419 = 5'b00010;
      5'b00001: n419 = 5'b00001;
      default: n419 = 5'b00000;
    endcase
  /*# scc_wave2.vhd:400:30 */
  assign n420 = w_ch_dec[0]; // extract
  /*# scc_wave2.vhd:400:48 */
  assign n421 = reg_ch_sel[0]; // extract
  /*# scc_wave2.vhd:400:34 */
  assign n422 = n420 & n421;
  /*# scc_wave2.vhd:401:30 */
  assign n423 = w_ch_dec[1]; // extract
  /*# scc_wave2.vhd:401:48 */
  assign n424 = reg_ch_sel[1]; // extract
  /*# scc_wave2.vhd:401:34 */
  assign n425 = n423 & n424;
  /*# scc_wave2.vhd:400:53 */
  assign n426 = n422 | n425;
  /*# scc_wave2.vhd:402:30 */
  assign n427 = w_ch_dec[2]; // extract
  /*# scc_wave2.vhd:402:48 */
  assign n428 = reg_ch_sel[2]; // extract
  /*# scc_wave2.vhd:402:34 */
  assign n429 = n427 & n428;
  /*# scc_wave2.vhd:401:53 */
  assign n430 = n426 | n429;
  /*# scc_wave2.vhd:403:30 */
  assign n431 = w_ch_dec[3]; // extract
  /*# scc_wave2.vhd:403:48 */
  assign n432 = reg_ch_sel[3]; // extract
  /*# scc_wave2.vhd:403:34 */
  assign n433 = n431 & n432;
  /*# scc_wave2.vhd:402:53 */
  assign n434 = n430 | n433;
  /*# scc_wave2.vhd:404:30 */
  assign n435 = w_ch_dec[4]; // extract
  /*# scc_wave2.vhd:404:48 */
  assign n436 = reg_ch_sel[4]; // extract
  /*# scc_wave2.vhd:404:34 */
  assign n437 = n435 & n436;
  /*# scc_wave2.vhd:403:53 */
  assign n438 = n434 | n437;
  /*# scc_wave2.vhd:406:21 */
  assign n439 = {w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit};
  /*# scc_wave2.vhd:409:29 */
  assign n441 = ff_ch_num_dl == 3'b001;
  /*# scc_wave2.vhd:410:29 */
  assign n443 = ff_ch_num_dl == 3'b010;
  /*# scc_wave2.vhd:411:29 */
  assign n445 = ff_ch_num_dl == 3'b011;
  /*# scc_wave2.vhd:412:29 */
  assign n447 = ff_ch_num_dl == 3'b100;
  /*# scc_wave2.vhd:413:29 */
  assign n449 = ff_ch_num_dl == 3'b101;
  /*# scc_wave2.vhd:408:5 */
  assign n451 = {n449, n447, n445, n443, n441};
  /*# scc_wave2.vhd:408:5 */
  always @*
    case (n451)
      5'b10000: n452 = reg_vol_ch_e;
      5'b01000: n452 = reg_vol_ch_d;
      5'b00100: n452 = reg_vol_ch_c;
      5'b00010: n452 = reg_vol_ch_b;
      5'b00001: n452 = reg_vol_ch_a;
      default: n452 = 4'b0000;
    endcase
  /*# scc_wave2.vhd:416:28 */
  assign n453 = w_ch_mask & ff_wave_dat;
  /*# scc_wave2.vhd:426:48 */
  assign n455 = {1'b0, w_ch_vol};
  /*# scc_wave2.vhd:426:35 */
  assign n456 = {{5{w_wave[7]}}, w_wave}; // sext
  /*# scc_wave2.vhd:426:35 */
  assign n457 = {{8{n455[4]}}, n455}; // sext
  /*# scc_wave2.vhd:426:35 */
  assign n458 = $signed(n456) * $signed(n457); // smul
  /*# scc_wave2.vhd:427:44 */
  assign n459 = w_mul_s[11:0]; // extract
  /*# scc_wave2.vhd:470:28 */
  assign n463 = ~ff_wave_ce;
  /*# scc_wave2.vhd:471:31 */
  assign n465 = ff_ch_num == 3'b101;
  /*# scc_wave2.vhd:474:44 */
  assign n467 = ff_ch_num + 3'b001;
  /*# scc_wave2.vhd:471:17 */
  assign n469 = n465 ? 3'b000 : n467;
  /*# scc_wave2.vhd:486:31 */
  assign n478 = ~ff_wave_ce_dl;
  /*# scc_wave2.vhd:487:34 */
  assign n480 = ff_ch_num_dl == 3'b000;
  /*# scc_wave2.vhd:490:39 */
  assign n481 = w_mul[11]; // extract
  /*# scc_wave2.vhd:490:51 */
  assign n482 = w_mul[11]; // extract
  /*# scc_wave2.vhd:490:44 */
  assign n483 = {n481, n482};
  /*# scc_wave2.vhd:490:63 */
  assign n484 = w_mul[11]; // extract
  /*# scc_wave2.vhd:490:56 */
  assign n485 = {n483, n484};
  /*# scc_wave2.vhd:490:68 */
  assign n486 = {n485, w_mul};
  /*# scc_wave2.vhd:490:77 */
  assign n487 = n486 + ff_mix;
  /*# scc_wave2.vhd:487:17 */
  assign n489 = n480 ? 15'b000000000000000 : n487;
  /*# scc_wave2.vhd:502:31 */
  assign n498 = ~ff_wave_ce_dl;
  /*# scc_wave2.vhd:503:34 */
  assign n500 = ff_ch_num_dl == 3'b000;
  /*# scc_wave2.vhd:502:13 */
  assign n502 = n500 & n498;
  /*# scc_wave2.vhd:363:9 */
  assign n510 = ff_wave_ce ? ram_dbi : n511;
  /*# scc_wave2.vhd:363:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n511 <= 8'b11111111;
    else
      n511 <= n510;
  /*# scc_wave2.vhd:203:9 */
  assign n512 = n23 ? n118 : reg_freq_ch_a;
  /*# scc_wave2.vhd:203:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n513 <= 12'b000000000000;
    else
      n513 <= n512;
  /*# scc_wave2.vhd:203:9 */
  assign n514 = n23 ? n120 : reg_freq_ch_b;
  /*# scc_wave2.vhd:203:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n515 <= 12'b000000000000;
    else
      n515 <= n514;
  /*# scc_wave2.vhd:203:9 */
  assign n516 = n23 ? n122 : reg_freq_ch_c;
  /*# scc_wave2.vhd:203:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n517 <= 12'b000000000000;
    else
      n517 <= n516;
  /*# scc_wave2.vhd:203:9 */
  assign n518 = n23 ? n124 : reg_freq_ch_d;
  /*# scc_wave2.vhd:203:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n519 <= 12'b000000000000;
    else
      n519 <= n518;
  /*# scc_wave2.vhd:203:9 */
  assign n520 = n23 ? n126 : reg_freq_ch_e;
  /*# scc_wave2.vhd:203:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n521 <= 12'b000000000000;
    else
      n521 <= n520;
  /*# scc_wave2.vhd:203:9 */
  assign n522 = n23 ? n97 : reg_vol_ch_a;
  /*# scc_wave2.vhd:203:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n523 <= 4'b0000;
    else
      n523 <= n522;
  /*# scc_wave2.vhd:203:9 */
  assign n524 = n23 ? n98 : reg_vol_ch_b;
  /*# scc_wave2.vhd:203:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n525 <= 4'b0000;
    else
      n525 <= n524;
  /*# scc_wave2.vhd:203:9 */
  assign n526 = n23 ? n99 : reg_vol_ch_c;
  /*# scc_wave2.vhd:203:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n527 <= 4'b0000;
    else
      n527 <= n526;
  /*# scc_wave2.vhd:203:9 */
  assign n528 = n23 ? n100 : reg_vol_ch_d;
  /*# scc_wave2.vhd:203:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n529 <= 4'b0000;
    else
      n529 <= n528;
  /*# scc_wave2.vhd:203:9 */
  assign n530 = n23 ? n101 : reg_vol_ch_e;
  /*# scc_wave2.vhd:203:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n531 <= 4'b0000;
    else
      n531 <= n530;
  /*# scc_wave2.vhd:203:9 */
  assign n532 = n23 ? n102 : reg_ch_sel;
  /*# scc_wave2.vhd:203:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n533 <= 5'b00000;
    else
      n533 <= n532;
  /*# scc_wave2.vhd:203:9 */
  assign n534 = n143 ? dbo : reg_mode_sel;
  /*# scc_wave2.vhd:203:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n535 <= 8'b00000000;
    else
      n535 <= n534;
  /*# scc_wave2.vhd:203:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n536 <= 1'b0;
    else
      n536 <= n134;
  /*# scc_wave2.vhd:203:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n537 <= 1'b0;
    else
      n537 <= n135;
  /*# scc_wave2.vhd:203:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n538 <= 1'b0;
    else
      n538 <= n136;
  /*# scc_wave2.vhd:203:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n539 <= 1'b0;
    else
      n539 <= n137;
  /*# scc_wave2.vhd:203:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n540 <= 1'b0;
    else
      n540 <= n138;
  /*# scc_wave2.vhd:281:9 */
  assign n541 = clkena ? n246 : ff_ptr_ch_a;
  /*# scc_wave2.vhd:281:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n542 <= 5'b00000;
    else
      n542 <= n541;
  /*# scc_wave2.vhd:281:9 */
  assign n543 = clkena ? n261 : ff_ptr_ch_b;
  /*# scc_wave2.vhd:281:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n544 <= 5'b00000;
    else
      n544 <= n543;
  /*# scc_wave2.vhd:281:9 */
  assign n545 = clkena ? n276 : ff_ptr_ch_c;
  /*# scc_wave2.vhd:281:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n546 <= 5'b00000;
    else
      n546 <= n545;
  /*# scc_wave2.vhd:281:9 */
  assign n547 = clkena ? n291 : ff_ptr_ch_d;
  /*# scc_wave2.vhd:281:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n548 <= 5'b00000;
    else
      n548 <= n547;
  /*# scc_wave2.vhd:281:9 */
  assign n549 = clkena ? n306 : ff_ptr_ch_e;
  /*# scc_wave2.vhd:281:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n550 <= 5'b00000;
    else
      n550 <= n549;
  /*# scc_wave2.vhd:469:9 */
  assign n551 = n463 ? n469 : ff_ch_num;
  /*# scc_wave2.vhd:469:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n552 <= 3'b000;
    else
      n552 <= n551;
  /*# scc_wave2.vhd:381:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n553 <= 3'b000;
    else
      n553 <= ff_ch_num;
  /*# scc_wave2.vhd:485:9 */
  assign n554 = n478 ? n489 : ff_mix;
  /*# scc_wave2.vhd:485:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n555 <= 15'b000000000000000;
    else
      n555 <= n554;
  /*# scc_wave2.vhd:381:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n556 <= 1'b0;
    else
      n556 <= w_wave_ce;
  /*# scc_wave2.vhd:381:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n557 <= 1'b0;
    else
      n557 <= ff_wave_ce;
  /*# scc_wave2.vhd:203:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n558 <= 1'b0;
    else
      n558 <= req;
  /*# scc_wave2.vhd:381:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n559 <= 8'b00000000;
    else
      n559 <= ram_dbi;
  /*# scc_wave2.vhd:501:9 */
  assign n560 = n502 ? ff_mix : ff_wave;
  /*# scc_wave2.vhd:501:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n561 <= 15'b000000000000000;
    else
      n561 <= n560;
  /*# scc_wave2.vhd:281:9 */
  assign n562 = clkena ? n247 : n225_ff_cnt_ch_a;
  /*# scc_wave2.vhd:281:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n563 <= 12'b000000000000;
    else
      n563 <= n562;
  /*# scc_wave2.vhd:281:9 */
  assign n564 = clkena ? n262 : n225_ff_cnt_ch_b;
  /*# scc_wave2.vhd:281:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n565 <= 12'b000000000000;
    else
      n565 <= n564;
  /*# scc_wave2.vhd:281:9 */
  assign n566 = clkena ? n277 : n225_ff_cnt_ch_c;
  /*# scc_wave2.vhd:281:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n567 <= 12'b000000000000;
    else
      n567 <= n566;
  /*# scc_wave2.vhd:281:9 */
  assign n568 = clkena ? n292 : n225_ff_cnt_ch_d;
  /*# scc_wave2.vhd:281:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n569 <= 12'b000000000000;
    else
      n569 <= n568;
  /*# scc_wave2.vhd:281:9 */
  assign n570 = clkena ? n307 : n225_ff_cnt_ch_e;
  /*# scc_wave2.vhd:281:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n571 <= 12'b000000000000;
    else
      n571 <= n570;
endmodule

