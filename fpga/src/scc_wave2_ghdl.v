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
//   fpga/src/ocm/scc_wave2.vhd            (md5 620258d45e65b41944a28cf8c6a7e503)
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
//                   dbg_sel_nz, dbg_freq_nz)
//   ram_Brtl    -- la wave RAM 256x8 (entity 'ram', arquitectura RTL);
//                  el sufijo _Brtl lo pone GHDL => NO colisiona con la
//                  entity VHDL 'ram' de ram.vhd si esta sigue en el proyecto
//
// INTEGRACION (build.tcl): al añadir este fichero hay que QUITAR
//   src/ocm/scc_wave2.vhd  del proyecto (si no, design unit 'scc_wave2'
//   duplicada VHDL/Verilog). ram.vhd puede quedarse (palette_rb/palette_g).
//
// Validado con Icarus Verilog 12: tools/scc_tb/run_ghdl.sh (mismos checks
// que el TB del chip scc_wave2v: 21/21 PASS).
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
  reg [7:0] n586;
  wire [7:0] n587; // mem_rd
  assign dbi = n587; //(module output)
  /*# ram.vhd:50:10 */
  assign iadr = n586; // (signal)
  /*# ram.vhd:56:5 */
  always @(posedge clk)
    n586 <= adr;
  reg [7:0] blkram[255:0] ; // memory
  assign n587 = blkram[iadr];
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
   output dbg_freq_nz);
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
  wire n9;
  wire n10;
  wire n11;
  wire n12;
  wire [2:0] n13;
  wire n15;
  wire n16;
  wire [2:0] n17;
  wire n19;
  wire n20;
  wire n21;
  wire n22;
  wire [3:0] n23;
  wire n24;
  wire n26;
  wire [3:0] n27;
  wire n28;
  wire n30;
  wire n31;
  wire n33;
  wire [3:0] n34;
  wire n35;
  wire n37;
  wire n38;
  wire n40;
  wire [3:0] n41;
  wire n42;
  wire n44;
  wire n45;
  wire n47;
  wire [3:0] n48;
  wire n49;
  wire n51;
  wire n52;
  wire n54;
  wire [3:0] n55;
  wire n56;
  wire n58;
  wire [3:0] n59;
  wire n61;
  wire [3:0] n62;
  wire n64;
  wire [3:0] n65;
  wire n67;
  wire [3:0] n68;
  wire n70;
  wire [3:0] n71;
  wire n73;
  wire [4:0] n74;
  wire [14:0] n75;
  wire [7:0] n76;
  reg [7:0] n77;
  wire [3:0] n78;
  reg [3:0] n79;
  wire [7:0] n80;
  reg [7:0] n81;
  wire [3:0] n82;
  reg [3:0] n83;
  wire [7:0] n84;
  reg [7:0] n85;
  wire [3:0] n86;
  reg [3:0] n87;
  wire [7:0] n88;
  reg [7:0] n89;
  wire [3:0] n90;
  reg [3:0] n91;
  wire [7:0] n92;
  reg [7:0] n93;
  wire [3:0] n94;
  reg [3:0] n95;
  reg [3:0] n96;
  reg [3:0] n97;
  reg [3:0] n98;
  reg [3:0] n99;
  reg [3:0] n100;
  reg [4:0] n101;
  reg n102;
  reg n103;
  reg n104;
  reg n105;
  reg n106;
  wire n108;
  wire n110;
  wire n112;
  wire n114;
  wire n116;
  wire [11:0] n117;
  wire [11:0] n119;
  wire [11:0] n121;
  wire [11:0] n123;
  wire [11:0] n125;
  wire n133;
  wire n134;
  wire n135;
  wire n136;
  wire n137;
  wire n138;
  wire [2:0] n139;
  wire n141;
  wire n142;
  wire n200;
  wire n201;
  wire n202;
  wire n204;
  wire n205;
  wire n206;
  wire n210;
  wire n211;
  wire n215;
  wire n216;
  wire n220;
  wire n221;
  reg [11:0] n223_ff_cnt_ch_a;
  reg [11:0] n223_ff_cnt_ch_b;
  reg [11:0] n223_ff_cnt_ch_c;
  reg [11:0] n223_ff_cnt_ch_d;
  reg [11:0] n223_ff_cnt_ch_e;
  wire [8:0] n231;
  wire n233;
  wire n234;
  wire n236;
  wire [4:0] n238;
  wire [11:0] n240;
  wire [4:0] n241;
  wire [11:0] n242;
  wire [4:0] n244;
  wire [11:0] n245;
  wire [8:0] n246;
  wire n248;
  wire n249;
  wire n251;
  wire [4:0] n253;
  wire [11:0] n255;
  wire [4:0] n256;
  wire [11:0] n257;
  wire [4:0] n259;
  wire [11:0] n260;
  wire [8:0] n261;
  wire n263;
  wire n264;
  wire n266;
  wire [4:0] n268;
  wire [11:0] n270;
  wire [4:0] n271;
  wire [11:0] n272;
  wire [4:0] n274;
  wire [11:0] n275;
  wire [8:0] n276;
  wire n278;
  wire n279;
  wire n281;
  wire [4:0] n283;
  wire [11:0] n285;
  wire [4:0] n286;
  wire [11:0] n287;
  wire [4:0] n289;
  wire [11:0] n290;
  wire [8:0] n291;
  wire n293;
  wire n294;
  wire n296;
  wire [4:0] n298;
  wire [11:0] n300;
  wire [4:0] n301;
  wire [11:0] n302;
  wire [4:0] n304;
  wire [11:0] n305;
  wire [7:0] n347;
  wire [7:0] n349;
  wire n351;
  wire [7:0] n352;
  wire [7:0] n354;
  wire n356;
  wire [7:0] n357;
  wire [7:0] n359;
  wire n361;
  wire [7:0] n362;
  wire [7:0] n364;
  wire n366;
  wire [7:0] n367;
  wire [7:0] n369;
  wire [7:0] n370;
  wire [7:0] n372;
  wire [7:0] wavemem_n373;
  wire n402;
  wire n405;
  wire n408;
  wire n411;
  wire n414;
  wire [4:0] n416;
  reg [4:0] n417;
  wire n418;
  wire n419;
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
  wire [7:0] n437;
  wire n439;
  wire n441;
  wire n443;
  wire n445;
  wire n447;
  wire [4:0] n449;
  reg [3:0] n450;
  wire [7:0] n451;
  wire [4:0] n453;
  wire [12:0] n454;
  wire [12:0] n455;
  wire [12:0] n456;
  wire [11:0] n457;
  wire n461;
  wire n463;
  wire [2:0] n465;
  wire [2:0] n467;
  wire n476;
  wire n478;
  wire n479;
  wire n480;
  wire [1:0] n481;
  wire n482;
  wire [2:0] n483;
  wire [14:0] n484;
  wire [14:0] n485;
  wire [14:0] n487;
  wire n496;
  wire n498;
  wire n500;
  wire [7:0] n508;
  reg [7:0] n509;
  wire [11:0] n510;
  reg [11:0] n511;
  wire [11:0] n512;
  reg [11:0] n513;
  wire [11:0] n514;
  reg [11:0] n515;
  wire [11:0] n516;
  reg [11:0] n517;
  wire [11:0] n518;
  reg [11:0] n519;
  wire [3:0] n520;
  reg [3:0] n521;
  wire [3:0] n522;
  reg [3:0] n523;
  wire [3:0] n524;
  reg [3:0] n525;
  wire [3:0] n526;
  reg [3:0] n527;
  wire [3:0] n528;
  reg [3:0] n529;
  wire [4:0] n530;
  reg [4:0] n531;
  wire [7:0] n532;
  reg [7:0] n533;
  reg n534;
  reg n535;
  reg n536;
  reg n537;
  reg n538;
  wire [4:0] n539;
  reg [4:0] n540;
  wire [4:0] n541;
  reg [4:0] n542;
  wire [4:0] n543;
  reg [4:0] n544;
  wire [4:0] n545;
  reg [4:0] n546;
  wire [4:0] n547;
  reg [4:0] n548;
  wire [2:0] n549;
  reg [2:0] n550;
  reg [2:0] n551;
  wire [14:0] n552;
  reg [14:0] n553;
  reg n554;
  reg n555;
  reg n556;
  reg [7:0] n557;
  wire [14:0] n558;
  reg [14:0] n559;
  wire [11:0] n560;
  reg [11:0] n561;
  wire [11:0] n562;
  reg [11:0] n563;
  wire [11:0] n564;
  reg [11:0] n565;
  wire [11:0] n566;
  reg [11:0] n567;
  wire [11:0] n568;
  reg [11:0] n569;
  assign ack = ff_req_dl; //(module output)
  assign dbi = n509; //(module output)
  assign wave = ff_wave; //(module output)
  assign dbg_vol_nz = n211; //(module output)
  assign dbg_sel_nz = n216; //(module output)
  assign dbg_freq_nz = n221; //(module output)
  /*# scc_wave2.vhd:122:12 */
  assign w_wave_ce = n202; // (signal)
  /*# scc_wave2.vhd:123:12 */
  assign w_wave_we = n206; // (signal)
  /*# scc_wave2.vhd:124:12 */
  assign w_wave_adr = n347; // (signal)
  /*# scc_wave2.vhd:125:12 */
  assign w_ch_dec = n417; // (signal)
  /*# scc_wave2.vhd:126:12 */
  assign w_ch_bit = n436; // (signal)
  /*# scc_wave2.vhd:127:12 */
  assign w_ch_mask = n437; // (signal)
  /*# scc_wave2.vhd:128:12 */
  assign w_ch_vol = n450; // (signal)
  /*# scc_wave2.vhd:129:12 */
  assign w_wave = n451; // (signal)
  /*# scc_wave2.vhd:130:12 */
  assign w_mul = n457; // (signal)
  /*# scc_wave2.vhd:131:12 */
  assign w_mul_s = n456; // (signal)
  /*# scc_wave2.vhd:132:12 */
  assign ram_dbi = wavemem_n373; // (signal)
  /*# scc_wave2.vhd:138:12 */
  assign reg_freq_ch_a = n511; // (signal)
  /*# scc_wave2.vhd:139:12 */
  assign reg_freq_ch_b = n513; // (signal)
  /*# scc_wave2.vhd:140:12 */
  assign reg_freq_ch_c = n515; // (signal)
  /*# scc_wave2.vhd:141:12 */
  assign reg_freq_ch_d = n517; // (signal)
  /*# scc_wave2.vhd:142:12 */
  assign reg_freq_ch_e = n519; // (signal)
  /*# scc_wave2.vhd:143:12 */
  assign reg_vol_ch_a = n521; // (signal)
  /*# scc_wave2.vhd:144:12 */
  assign reg_vol_ch_b = n523; // (signal)
  /*# scc_wave2.vhd:145:12 */
  assign reg_vol_ch_c = n525; // (signal)
  /*# scc_wave2.vhd:146:12 */
  assign reg_vol_ch_d = n527; // (signal)
  /*# scc_wave2.vhd:147:12 */
  assign reg_vol_ch_e = n529; // (signal)
  /*# scc_wave2.vhd:148:12 */
  assign reg_ch_sel = n531; // (signal)
  /*# scc_wave2.vhd:149:12 */
  assign reg_mode_sel = n533; // (signal)
  /*# scc_wave2.vhd:152:12 */
  assign ff_rst_ch_a = n534; // (signal)
  /*# scc_wave2.vhd:153:12 */
  assign ff_rst_ch_b = n535; // (signal)
  /*# scc_wave2.vhd:154:12 */
  assign ff_rst_ch_c = n536; // (signal)
  /*# scc_wave2.vhd:155:12 */
  assign ff_rst_ch_d = n537; // (signal)
  /*# scc_wave2.vhd:156:12 */
  assign ff_rst_ch_e = n538; // (signal)
  /*# scc_wave2.vhd:157:12 */
  assign ff_ptr_ch_a = n540; // (signal)
  /*# scc_wave2.vhd:158:12 */
  assign ff_ptr_ch_b = n542; // (signal)
  /*# scc_wave2.vhd:159:12 */
  assign ff_ptr_ch_c = n544; // (signal)
  /*# scc_wave2.vhd:160:12 */
  assign ff_ptr_ch_d = n546; // (signal)
  /*# scc_wave2.vhd:161:12 */
  assign ff_ptr_ch_e = n548; // (signal)
  /*# scc_wave2.vhd:162:12 */
  assign ff_ch_num = n550; // (signal)
  /*# scc_wave2.vhd:163:12 */
  assign ff_ch_num_dl = n551; // (signal)
  /*# scc_wave2.vhd:164:12 */
  assign ff_mix = n553; // (signal)
  /*# scc_wave2.vhd:165:12 */
  assign ff_wave_ce = n554; // (signal)
  /*# scc_wave2.vhd:166:12 */
  assign ff_wave_ce_dl = n555; // (signal)
  /*# scc_wave2.vhd:167:12 */
  assign ff_req_dl = n556; // (signal)
  /*# scc_wave2.vhd:168:12 */
  assign ff_wave_dat = n557; // (signal)
  /*# scc_wave2.vhd:169:12 */
  assign ff_wave = n559; // (signal)
  /*# scc_wave2.vhd:203:41 */
  assign n9 = ~ff_req_dl;
  /*# scc_wave2.vhd:203:27 */
  assign n10 = n9 & req;
  /*# scc_wave2.vhd:203:47 */
  assign n11 = wrt & n10;
  /*# scc_wave2.vhd:204:27 */
  assign n12 = ~sccplus;
  /*# scc_wave2.vhd:204:40 */
  assign n13 = adr[7:5]; // extract
  /*# scc_wave2.vhd:204:53 */
  assign n15 = n13 == 3'b100;
  /*# scc_wave2.vhd:204:33 */
  assign n16 = n15 & n12;
  /*# scc_wave2.vhd:205:40 */
  assign n17 = adr[7:5]; // extract
  /*# scc_wave2.vhd:205:53 */
  assign n19 = n17 == 3'b101;
  /*# scc_wave2.vhd:205:33 */
  assign n20 = n19 & sccplus;
  /*# scc_wave2.vhd:204:62 */
  assign n21 = n16 | n20;
  /*# scc_wave2.vhd:203:61 */
  assign n22 = n21 & n11;
  /*# scc_wave2.vhd:206:25 */
  assign n23 = adr[3:0]; // extract
  /*# scc_wave2.vhd:207:114 */
  assign n24 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:207:21 */
  assign n26 = n23 == 4'b0000;
  /*# scc_wave2.vhd:208:71 */
  assign n27 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:208:114 */
  assign n28 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:208:21 */
  assign n30 = n23 == 4'b0001;
  /*# scc_wave2.vhd:209:114 */
  assign n31 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:209:21 */
  assign n33 = n23 == 4'b0010;
  /*# scc_wave2.vhd:210:71 */
  assign n34 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:210:114 */
  assign n35 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:210:21 */
  assign n37 = n23 == 4'b0011;
  /*# scc_wave2.vhd:211:114 */
  assign n38 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:211:21 */
  assign n40 = n23 == 4'b0100;
  /*# scc_wave2.vhd:212:71 */
  assign n41 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:212:114 */
  assign n42 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:212:21 */
  assign n44 = n23 == 4'b0101;
  /*# scc_wave2.vhd:213:114 */
  assign n45 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:213:21 */
  assign n47 = n23 == 4'b0110;
  /*# scc_wave2.vhd:214:71 */
  assign n48 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:214:114 */
  assign n49 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:214:21 */
  assign n51 = n23 == 4'b0111;
  /*# scc_wave2.vhd:215:114 */
  assign n52 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:215:21 */
  assign n54 = n23 == 4'b1000;
  /*# scc_wave2.vhd:216:71 */
  assign n55 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:216:114 */
  assign n56 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:216:21 */
  assign n58 = n23 == 4'b1001;
  /*# scc_wave2.vhd:217:71 */
  assign n59 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:217:21 */
  assign n61 = n23 == 4'b1010;
  /*# scc_wave2.vhd:218:71 */
  assign n62 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:218:21 */
  assign n64 = n23 == 4'b1011;
  /*# scc_wave2.vhd:219:71 */
  assign n65 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:219:21 */
  assign n67 = n23 == 4'b1100;
  /*# scc_wave2.vhd:220:71 */
  assign n68 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:220:21 */
  assign n70 = n23 == 4'b1101;
  /*# scc_wave2.vhd:221:71 */
  assign n71 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:221:21 */
  assign n73 = n23 == 4'b1110;
  /*# scc_wave2.vhd:222:71 */
  assign n74 = dbo[4:0]; // extract
  /*# scc_wave2.vhd:206:17 */
  assign n75 = {n73, n70, n67, n64, n61, n58, n54, n51, n47, n44, n40, n37, n33, n30, n26};
  /*# scc_wave2.vhd:138:12 */
  assign n76 = reg_freq_ch_a[7:0]; // extract
  /*# scc_wave2.vhd:206:17 */
  always @*
    case (n75)
      15'b100000000000000: n77 = n76;
      15'b010000000000000: n77 = n76;
      15'b001000000000000: n77 = n76;
      15'b000100000000000: n77 = n76;
      15'b000010000000000: n77 = n76;
      15'b000001000000000: n77 = n76;
      15'b000000100000000: n77 = n76;
      15'b000000010000000: n77 = n76;
      15'b000000001000000: n77 = n76;
      15'b000000000100000: n77 = n76;
      15'b000000000010000: n77 = n76;
      15'b000000000001000: n77 = n76;
      15'b000000000000100: n77 = n76;
      15'b000000000000010: n77 = n76;
      15'b000000000000001: n77 = dbo;
      default: n77 = n76;
    endcase
  /*# scc_wave2.vhd:138:12 */
  assign n78 = reg_freq_ch_a[11:8]; // extract
  /*# scc_wave2.vhd:206:17 */
  always @*
    case (n75)
      15'b100000000000000: n79 = n78;
      15'b010000000000000: n79 = n78;
      15'b001000000000000: n79 = n78;
      15'b000100000000000: n79 = n78;
      15'b000010000000000: n79 = n78;
      15'b000001000000000: n79 = n78;
      15'b000000100000000: n79 = n78;
      15'b000000010000000: n79 = n78;
      15'b000000001000000: n79 = n78;
      15'b000000000100000: n79 = n78;
      15'b000000000010000: n79 = n78;
      15'b000000000001000: n79 = n78;
      15'b000000000000100: n79 = n78;
      15'b000000000000010: n79 = n27;
      15'b000000000000001: n79 = n78;
      default: n79 = n78;
    endcase
  /*# scc_wave2.vhd:139:12 */
  assign n80 = reg_freq_ch_b[7:0]; // extract
  /*# scc_wave2.vhd:206:17 */
  always @*
    case (n75)
      15'b100000000000000: n81 = n80;
      15'b010000000000000: n81 = n80;
      15'b001000000000000: n81 = n80;
      15'b000100000000000: n81 = n80;
      15'b000010000000000: n81 = n80;
      15'b000001000000000: n81 = n80;
      15'b000000100000000: n81 = n80;
      15'b000000010000000: n81 = n80;
      15'b000000001000000: n81 = n80;
      15'b000000000100000: n81 = n80;
      15'b000000000010000: n81 = n80;
      15'b000000000001000: n81 = n80;
      15'b000000000000100: n81 = dbo;
      15'b000000000000010: n81 = n80;
      15'b000000000000001: n81 = n80;
      default: n81 = n80;
    endcase
  /*# scc_wave2.vhd:139:12 */
  assign n82 = reg_freq_ch_b[11:8]; // extract
  /*# scc_wave2.vhd:206:17 */
  always @*
    case (n75)
      15'b100000000000000: n83 = n82;
      15'b010000000000000: n83 = n82;
      15'b001000000000000: n83 = n82;
      15'b000100000000000: n83 = n82;
      15'b000010000000000: n83 = n82;
      15'b000001000000000: n83 = n82;
      15'b000000100000000: n83 = n82;
      15'b000000010000000: n83 = n82;
      15'b000000001000000: n83 = n82;
      15'b000000000100000: n83 = n82;
      15'b000000000010000: n83 = n82;
      15'b000000000001000: n83 = n34;
      15'b000000000000100: n83 = n82;
      15'b000000000000010: n83 = n82;
      15'b000000000000001: n83 = n82;
      default: n83 = n82;
    endcase
  /*# scc_wave2.vhd:140:12 */
  assign n84 = reg_freq_ch_c[7:0]; // extract
  /*# scc_wave2.vhd:206:17 */
  always @*
    case (n75)
      15'b100000000000000: n85 = n84;
      15'b010000000000000: n85 = n84;
      15'b001000000000000: n85 = n84;
      15'b000100000000000: n85 = n84;
      15'b000010000000000: n85 = n84;
      15'b000001000000000: n85 = n84;
      15'b000000100000000: n85 = n84;
      15'b000000010000000: n85 = n84;
      15'b000000001000000: n85 = n84;
      15'b000000000100000: n85 = n84;
      15'b000000000010000: n85 = dbo;
      15'b000000000001000: n85 = n84;
      15'b000000000000100: n85 = n84;
      15'b000000000000010: n85 = n84;
      15'b000000000000001: n85 = n84;
      default: n85 = n84;
    endcase
  /*# scc_wave2.vhd:140:12 */
  assign n86 = reg_freq_ch_c[11:8]; // extract
  /*# scc_wave2.vhd:206:17 */
  always @*
    case (n75)
      15'b100000000000000: n87 = n86;
      15'b010000000000000: n87 = n86;
      15'b001000000000000: n87 = n86;
      15'b000100000000000: n87 = n86;
      15'b000010000000000: n87 = n86;
      15'b000001000000000: n87 = n86;
      15'b000000100000000: n87 = n86;
      15'b000000010000000: n87 = n86;
      15'b000000001000000: n87 = n86;
      15'b000000000100000: n87 = n41;
      15'b000000000010000: n87 = n86;
      15'b000000000001000: n87 = n86;
      15'b000000000000100: n87 = n86;
      15'b000000000000010: n87 = n86;
      15'b000000000000001: n87 = n86;
      default: n87 = n86;
    endcase
  /*# scc_wave2.vhd:141:12 */
  assign n88 = reg_freq_ch_d[7:0]; // extract
  /*# scc_wave2.vhd:206:17 */
  always @*
    case (n75)
      15'b100000000000000: n89 = n88;
      15'b010000000000000: n89 = n88;
      15'b001000000000000: n89 = n88;
      15'b000100000000000: n89 = n88;
      15'b000010000000000: n89 = n88;
      15'b000001000000000: n89 = n88;
      15'b000000100000000: n89 = n88;
      15'b000000010000000: n89 = n88;
      15'b000000001000000: n89 = dbo;
      15'b000000000100000: n89 = n88;
      15'b000000000010000: n89 = n88;
      15'b000000000001000: n89 = n88;
      15'b000000000000100: n89 = n88;
      15'b000000000000010: n89 = n88;
      15'b000000000000001: n89 = n88;
      default: n89 = n88;
    endcase
  /*# scc_wave2.vhd:141:12 */
  assign n90 = reg_freq_ch_d[11:8]; // extract
  /*# scc_wave2.vhd:206:17 */
  always @*
    case (n75)
      15'b100000000000000: n91 = n90;
      15'b010000000000000: n91 = n90;
      15'b001000000000000: n91 = n90;
      15'b000100000000000: n91 = n90;
      15'b000010000000000: n91 = n90;
      15'b000001000000000: n91 = n90;
      15'b000000100000000: n91 = n90;
      15'b000000010000000: n91 = n48;
      15'b000000001000000: n91 = n90;
      15'b000000000100000: n91 = n90;
      15'b000000000010000: n91 = n90;
      15'b000000000001000: n91 = n90;
      15'b000000000000100: n91 = n90;
      15'b000000000000010: n91 = n90;
      15'b000000000000001: n91 = n90;
      default: n91 = n90;
    endcase
  /*# scc_wave2.vhd:142:12 */
  assign n92 = reg_freq_ch_e[7:0]; // extract
  /*# scc_wave2.vhd:206:17 */
  always @*
    case (n75)
      15'b100000000000000: n93 = n92;
      15'b010000000000000: n93 = n92;
      15'b001000000000000: n93 = n92;
      15'b000100000000000: n93 = n92;
      15'b000010000000000: n93 = n92;
      15'b000001000000000: n93 = n92;
      15'b000000100000000: n93 = dbo;
      15'b000000010000000: n93 = n92;
      15'b000000001000000: n93 = n92;
      15'b000000000100000: n93 = n92;
      15'b000000000010000: n93 = n92;
      15'b000000000001000: n93 = n92;
      15'b000000000000100: n93 = n92;
      15'b000000000000010: n93 = n92;
      15'b000000000000001: n93 = n92;
      default: n93 = n92;
    endcase
  /*# scc_wave2.vhd:142:12 */
  assign n94 = reg_freq_ch_e[11:8]; // extract
  /*# scc_wave2.vhd:206:17 */
  always @*
    case (n75)
      15'b100000000000000: n95 = n94;
      15'b010000000000000: n95 = n94;
      15'b001000000000000: n95 = n94;
      15'b000100000000000: n95 = n94;
      15'b000010000000000: n95 = n94;
      15'b000001000000000: n95 = n55;
      15'b000000100000000: n95 = n94;
      15'b000000010000000: n95 = n94;
      15'b000000001000000: n95 = n94;
      15'b000000000100000: n95 = n94;
      15'b000000000010000: n95 = n94;
      15'b000000000001000: n95 = n94;
      15'b000000000000100: n95 = n94;
      15'b000000000000010: n95 = n94;
      15'b000000000000001: n95 = n94;
      default: n95 = n94;
    endcase
  /*# scc_wave2.vhd:206:17 */
  always @*
    case (n75)
      15'b100000000000000: n96 = reg_vol_ch_a;
      15'b010000000000000: n96 = reg_vol_ch_a;
      15'b001000000000000: n96 = reg_vol_ch_a;
      15'b000100000000000: n96 = reg_vol_ch_a;
      15'b000010000000000: n96 = n59;
      15'b000001000000000: n96 = reg_vol_ch_a;
      15'b000000100000000: n96 = reg_vol_ch_a;
      15'b000000010000000: n96 = reg_vol_ch_a;
      15'b000000001000000: n96 = reg_vol_ch_a;
      15'b000000000100000: n96 = reg_vol_ch_a;
      15'b000000000010000: n96 = reg_vol_ch_a;
      15'b000000000001000: n96 = reg_vol_ch_a;
      15'b000000000000100: n96 = reg_vol_ch_a;
      15'b000000000000010: n96 = reg_vol_ch_a;
      15'b000000000000001: n96 = reg_vol_ch_a;
      default: n96 = reg_vol_ch_a;
    endcase
  /*# scc_wave2.vhd:206:17 */
  always @*
    case (n75)
      15'b100000000000000: n97 = reg_vol_ch_b;
      15'b010000000000000: n97 = reg_vol_ch_b;
      15'b001000000000000: n97 = reg_vol_ch_b;
      15'b000100000000000: n97 = n62;
      15'b000010000000000: n97 = reg_vol_ch_b;
      15'b000001000000000: n97 = reg_vol_ch_b;
      15'b000000100000000: n97 = reg_vol_ch_b;
      15'b000000010000000: n97 = reg_vol_ch_b;
      15'b000000001000000: n97 = reg_vol_ch_b;
      15'b000000000100000: n97 = reg_vol_ch_b;
      15'b000000000010000: n97 = reg_vol_ch_b;
      15'b000000000001000: n97 = reg_vol_ch_b;
      15'b000000000000100: n97 = reg_vol_ch_b;
      15'b000000000000010: n97 = reg_vol_ch_b;
      15'b000000000000001: n97 = reg_vol_ch_b;
      default: n97 = reg_vol_ch_b;
    endcase
  /*# scc_wave2.vhd:206:17 */
  always @*
    case (n75)
      15'b100000000000000: n98 = reg_vol_ch_c;
      15'b010000000000000: n98 = reg_vol_ch_c;
      15'b001000000000000: n98 = n65;
      15'b000100000000000: n98 = reg_vol_ch_c;
      15'b000010000000000: n98 = reg_vol_ch_c;
      15'b000001000000000: n98 = reg_vol_ch_c;
      15'b000000100000000: n98 = reg_vol_ch_c;
      15'b000000010000000: n98 = reg_vol_ch_c;
      15'b000000001000000: n98 = reg_vol_ch_c;
      15'b000000000100000: n98 = reg_vol_ch_c;
      15'b000000000010000: n98 = reg_vol_ch_c;
      15'b000000000001000: n98 = reg_vol_ch_c;
      15'b000000000000100: n98 = reg_vol_ch_c;
      15'b000000000000010: n98 = reg_vol_ch_c;
      15'b000000000000001: n98 = reg_vol_ch_c;
      default: n98 = reg_vol_ch_c;
    endcase
  /*# scc_wave2.vhd:206:17 */
  always @*
    case (n75)
      15'b100000000000000: n99 = reg_vol_ch_d;
      15'b010000000000000: n99 = n68;
      15'b001000000000000: n99 = reg_vol_ch_d;
      15'b000100000000000: n99 = reg_vol_ch_d;
      15'b000010000000000: n99 = reg_vol_ch_d;
      15'b000001000000000: n99 = reg_vol_ch_d;
      15'b000000100000000: n99 = reg_vol_ch_d;
      15'b000000010000000: n99 = reg_vol_ch_d;
      15'b000000001000000: n99 = reg_vol_ch_d;
      15'b000000000100000: n99 = reg_vol_ch_d;
      15'b000000000010000: n99 = reg_vol_ch_d;
      15'b000000000001000: n99 = reg_vol_ch_d;
      15'b000000000000100: n99 = reg_vol_ch_d;
      15'b000000000000010: n99 = reg_vol_ch_d;
      15'b000000000000001: n99 = reg_vol_ch_d;
      default: n99 = reg_vol_ch_d;
    endcase
  /*# scc_wave2.vhd:206:17 */
  always @*
    case (n75)
      15'b100000000000000: n100 = n71;
      15'b010000000000000: n100 = reg_vol_ch_e;
      15'b001000000000000: n100 = reg_vol_ch_e;
      15'b000100000000000: n100 = reg_vol_ch_e;
      15'b000010000000000: n100 = reg_vol_ch_e;
      15'b000001000000000: n100 = reg_vol_ch_e;
      15'b000000100000000: n100 = reg_vol_ch_e;
      15'b000000010000000: n100 = reg_vol_ch_e;
      15'b000000001000000: n100 = reg_vol_ch_e;
      15'b000000000100000: n100 = reg_vol_ch_e;
      15'b000000000010000: n100 = reg_vol_ch_e;
      15'b000000000001000: n100 = reg_vol_ch_e;
      15'b000000000000100: n100 = reg_vol_ch_e;
      15'b000000000000010: n100 = reg_vol_ch_e;
      15'b000000000000001: n100 = reg_vol_ch_e;
      default: n100 = reg_vol_ch_e;
    endcase
  /*# scc_wave2.vhd:206:17 */
  always @*
    case (n75)
      15'b100000000000000: n101 = reg_ch_sel;
      15'b010000000000000: n101 = reg_ch_sel;
      15'b001000000000000: n101 = reg_ch_sel;
      15'b000100000000000: n101 = reg_ch_sel;
      15'b000010000000000: n101 = reg_ch_sel;
      15'b000001000000000: n101 = reg_ch_sel;
      15'b000000100000000: n101 = reg_ch_sel;
      15'b000000010000000: n101 = reg_ch_sel;
      15'b000000001000000: n101 = reg_ch_sel;
      15'b000000000100000: n101 = reg_ch_sel;
      15'b000000000010000: n101 = reg_ch_sel;
      15'b000000000001000: n101 = reg_ch_sel;
      15'b000000000000100: n101 = reg_ch_sel;
      15'b000000000000010: n101 = reg_ch_sel;
      15'b000000000000001: n101 = reg_ch_sel;
      default: n101 = n74;
    endcase
  /*# scc_wave2.vhd:206:17 */
  always @*
    case (n75)
      15'b100000000000000: n102 = ff_rst_ch_a;
      15'b010000000000000: n102 = ff_rst_ch_a;
      15'b001000000000000: n102 = ff_rst_ch_a;
      15'b000100000000000: n102 = ff_rst_ch_a;
      15'b000010000000000: n102 = ff_rst_ch_a;
      15'b000001000000000: n102 = ff_rst_ch_a;
      15'b000000100000000: n102 = ff_rst_ch_a;
      15'b000000010000000: n102 = ff_rst_ch_a;
      15'b000000001000000: n102 = ff_rst_ch_a;
      15'b000000000100000: n102 = ff_rst_ch_a;
      15'b000000000010000: n102 = ff_rst_ch_a;
      15'b000000000001000: n102 = ff_rst_ch_a;
      15'b000000000000100: n102 = ff_rst_ch_a;
      15'b000000000000010: n102 = n28;
      15'b000000000000001: n102 = n24;
      default: n102 = ff_rst_ch_a;
    endcase
  /*# scc_wave2.vhd:206:17 */
  always @*
    case (n75)
      15'b100000000000000: n103 = ff_rst_ch_b;
      15'b010000000000000: n103 = ff_rst_ch_b;
      15'b001000000000000: n103 = ff_rst_ch_b;
      15'b000100000000000: n103 = ff_rst_ch_b;
      15'b000010000000000: n103 = ff_rst_ch_b;
      15'b000001000000000: n103 = ff_rst_ch_b;
      15'b000000100000000: n103 = ff_rst_ch_b;
      15'b000000010000000: n103 = ff_rst_ch_b;
      15'b000000001000000: n103 = ff_rst_ch_b;
      15'b000000000100000: n103 = ff_rst_ch_b;
      15'b000000000010000: n103 = ff_rst_ch_b;
      15'b000000000001000: n103 = n35;
      15'b000000000000100: n103 = n31;
      15'b000000000000010: n103 = ff_rst_ch_b;
      15'b000000000000001: n103 = ff_rst_ch_b;
      default: n103 = ff_rst_ch_b;
    endcase
  /*# scc_wave2.vhd:206:17 */
  always @*
    case (n75)
      15'b100000000000000: n104 = ff_rst_ch_c;
      15'b010000000000000: n104 = ff_rst_ch_c;
      15'b001000000000000: n104 = ff_rst_ch_c;
      15'b000100000000000: n104 = ff_rst_ch_c;
      15'b000010000000000: n104 = ff_rst_ch_c;
      15'b000001000000000: n104 = ff_rst_ch_c;
      15'b000000100000000: n104 = ff_rst_ch_c;
      15'b000000010000000: n104 = ff_rst_ch_c;
      15'b000000001000000: n104 = ff_rst_ch_c;
      15'b000000000100000: n104 = n42;
      15'b000000000010000: n104 = n38;
      15'b000000000001000: n104 = ff_rst_ch_c;
      15'b000000000000100: n104 = ff_rst_ch_c;
      15'b000000000000010: n104 = ff_rst_ch_c;
      15'b000000000000001: n104 = ff_rst_ch_c;
      default: n104 = ff_rst_ch_c;
    endcase
  /*# scc_wave2.vhd:206:17 */
  always @*
    case (n75)
      15'b100000000000000: n105 = ff_rst_ch_d;
      15'b010000000000000: n105 = ff_rst_ch_d;
      15'b001000000000000: n105 = ff_rst_ch_d;
      15'b000100000000000: n105 = ff_rst_ch_d;
      15'b000010000000000: n105 = ff_rst_ch_d;
      15'b000001000000000: n105 = ff_rst_ch_d;
      15'b000000100000000: n105 = ff_rst_ch_d;
      15'b000000010000000: n105 = n49;
      15'b000000001000000: n105 = n45;
      15'b000000000100000: n105 = ff_rst_ch_d;
      15'b000000000010000: n105 = ff_rst_ch_d;
      15'b000000000001000: n105 = ff_rst_ch_d;
      15'b000000000000100: n105 = ff_rst_ch_d;
      15'b000000000000010: n105 = ff_rst_ch_d;
      15'b000000000000001: n105 = ff_rst_ch_d;
      default: n105 = ff_rst_ch_d;
    endcase
  /*# scc_wave2.vhd:206:17 */
  always @*
    case (n75)
      15'b100000000000000: n106 = ff_rst_ch_e;
      15'b010000000000000: n106 = ff_rst_ch_e;
      15'b001000000000000: n106 = ff_rst_ch_e;
      15'b000100000000000: n106 = ff_rst_ch_e;
      15'b000010000000000: n106 = ff_rst_ch_e;
      15'b000001000000000: n106 = n56;
      15'b000000100000000: n106 = n52;
      15'b000000010000000: n106 = ff_rst_ch_e;
      15'b000000001000000: n106 = ff_rst_ch_e;
      15'b000000000100000: n106 = ff_rst_ch_e;
      15'b000000000010000: n106 = ff_rst_ch_e;
      15'b000000000001000: n106 = ff_rst_ch_e;
      15'b000000000000100: n106 = ff_rst_ch_e;
      15'b000000000000010: n106 = ff_rst_ch_e;
      15'b000000000000001: n106 = ff_rst_ch_e;
      default: n106 = ff_rst_ch_e;
    endcase
  /*# scc_wave2.vhd:224:13 */
  assign n108 = clkena ? 1'b0 : ff_rst_ch_a;
  /*# scc_wave2.vhd:224:13 */
  assign n110 = clkena ? 1'b0 : ff_rst_ch_b;
  /*# scc_wave2.vhd:224:13 */
  assign n112 = clkena ? 1'b0 : ff_rst_ch_c;
  /*# scc_wave2.vhd:224:13 */
  assign n114 = clkena ? 1'b0 : ff_rst_ch_d;
  /*# scc_wave2.vhd:224:13 */
  assign n116 = clkena ? 1'b0 : ff_rst_ch_e;
  /*# scc_wave2.vhd:203:13 */
  assign n117 = {n79, n77};
  /*# scc_wave2.vhd:203:13 */
  assign n119 = {n83, n81};
  /*# scc_wave2.vhd:203:13 */
  assign n121 = {n87, n85};
  /*# scc_wave2.vhd:203:13 */
  assign n123 = {n91, n89};
  /*# scc_wave2.vhd:203:13 */
  assign n125 = {n95, n93};
  /*# scc_wave2.vhd:203:13 */
  assign n133 = n22 ? n102 : n108;
  /*# scc_wave2.vhd:203:13 */
  assign n134 = n22 ? n103 : n110;
  /*# scc_wave2.vhd:203:13 */
  assign n135 = n22 ? n104 : n112;
  /*# scc_wave2.vhd:203:13 */
  assign n136 = n22 ? n105 : n114;
  /*# scc_wave2.vhd:203:13 */
  assign n137 = n22 ? n106 : n116;
  /*# scc_wave2.vhd:233:27 */
  assign n138 = wrt & req;
  /*# scc_wave2.vhd:233:48 */
  assign n139 = adr[7:5]; // extract
  /*# scc_wave2.vhd:233:61 */
  assign n141 = n139 == 3'b110;
  /*# scc_wave2.vhd:233:41 */
  assign n142 = n141 & n138;
  /*# scc_wave2.vhd:242:55 */
  assign n200 = ~ff_req_dl;
  /*# scc_wave2.vhd:242:41 */
  assign n201 = n200 & req;
  /*# scc_wave2.vhd:242:25 */
  assign n202 = n201 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:243:55 */
  assign n204 = ~ff_req_dl;
  /*# scc_wave2.vhd:243:41 */
  assign n205 = n204 & req;
  /*# scc_wave2.vhd:243:25 */
  assign n206 = n205 ? wrt : 1'b0;
  /*# scc_wave2.vhd:247:44 */
  assign n210 = reg_vol_ch_a != 4'b0000;
  /*# scc_wave2.vhd:247:24 */
  assign n211 = n210 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:248:42 */
  assign n215 = reg_ch_sel != 5'b00000;
  /*# scc_wave2.vhd:248:24 */
  assign n216 = n215 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:249:45 */
  assign n220 = reg_freq_ch_a != 12'b000000000000;
  /*# scc_wave2.vhd:249:24 */
  assign n221 = n220 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:255:18 */
  always @*
    n223_ff_cnt_ch_a = n561; // (isignal)
  initial
    n223_ff_cnt_ch_a = 12'bX;
  /*# scc_wave2.vhd:256:18 */
  always @*
    n223_ff_cnt_ch_b = n563; // (isignal)
  initial
    n223_ff_cnt_ch_b = 12'bX;
  /*# scc_wave2.vhd:257:18 */
  always @*
    n223_ff_cnt_ch_c = n565; // (isignal)
  initial
    n223_ff_cnt_ch_c = 12'bX;
  /*# scc_wave2.vhd:258:18 */
  always @*
    n223_ff_cnt_ch_d = n567; // (isignal)
  initial
    n223_ff_cnt_ch_d = 12'bX;
  /*# scc_wave2.vhd:259:18 */
  always @*
    n223_ff_cnt_ch_e = n569; // (isignal)
  initial
    n223_ff_cnt_ch_e = 12'bX;
  /*# scc_wave2.vhd:276:34 */
  assign n231 = reg_freq_ch_a[11:3]; // extract
  /*# scc_wave2.vhd:276:48 */
  assign n233 = n231 == 9'b000000000;
  /*# scc_wave2.vhd:276:62 */
  assign n234 = n233 | ff_rst_ch_a;
  /*# scc_wave2.vhd:279:36 */
  assign n236 = n223_ff_cnt_ch_a == 12'b000000000000;
  /*# scc_wave2.vhd:280:48 */
  assign n238 = ff_ptr_ch_a + 5'b00001;
  /*# scc_wave2.vhd:283:48 */
  assign n240 = n223_ff_cnt_ch_a - 12'b000000000001;
  /*# scc_wave2.vhd:279:17 */
  assign n241 = n236 ? n238 : ff_ptr_ch_a;
  /*# scc_wave2.vhd:279:17 */
  assign n242 = n236 ? reg_freq_ch_a : n240;
  /*# scc_wave2.vhd:276:17 */
  assign n244 = n234 ? 5'b00000 : n241;
  /*# scc_wave2.vhd:276:17 */
  assign n245 = n234 ? reg_freq_ch_a : n242;
  /*# scc_wave2.vhd:286:34 */
  assign n246 = reg_freq_ch_b[11:3]; // extract
  /*# scc_wave2.vhd:286:48 */
  assign n248 = n246 == 9'b000000000;
  /*# scc_wave2.vhd:286:62 */
  assign n249 = n248 | ff_rst_ch_b;
  /*# scc_wave2.vhd:289:36 */
  assign n251 = n223_ff_cnt_ch_b == 12'b000000000000;
  /*# scc_wave2.vhd:290:48 */
  assign n253 = ff_ptr_ch_b + 5'b00001;
  /*# scc_wave2.vhd:293:48 */
  assign n255 = n223_ff_cnt_ch_b - 12'b000000000001;
  /*# scc_wave2.vhd:289:17 */
  assign n256 = n251 ? n253 : ff_ptr_ch_b;
  /*# scc_wave2.vhd:289:17 */
  assign n257 = n251 ? reg_freq_ch_b : n255;
  /*# scc_wave2.vhd:286:17 */
  assign n259 = n249 ? 5'b00000 : n256;
  /*# scc_wave2.vhd:286:17 */
  assign n260 = n249 ? reg_freq_ch_b : n257;
  /*# scc_wave2.vhd:296:34 */
  assign n261 = reg_freq_ch_c[11:3]; // extract
  /*# scc_wave2.vhd:296:48 */
  assign n263 = n261 == 9'b000000000;
  /*# scc_wave2.vhd:296:62 */
  assign n264 = n263 | ff_rst_ch_c;
  /*# scc_wave2.vhd:299:36 */
  assign n266 = n223_ff_cnt_ch_c == 12'b000000000000;
  /*# scc_wave2.vhd:300:48 */
  assign n268 = ff_ptr_ch_c + 5'b00001;
  /*# scc_wave2.vhd:303:48 */
  assign n270 = n223_ff_cnt_ch_c - 12'b000000000001;
  /*# scc_wave2.vhd:299:17 */
  assign n271 = n266 ? n268 : ff_ptr_ch_c;
  /*# scc_wave2.vhd:299:17 */
  assign n272 = n266 ? reg_freq_ch_c : n270;
  /*# scc_wave2.vhd:296:17 */
  assign n274 = n264 ? 5'b00000 : n271;
  /*# scc_wave2.vhd:296:17 */
  assign n275 = n264 ? reg_freq_ch_c : n272;
  /*# scc_wave2.vhd:306:34 */
  assign n276 = reg_freq_ch_d[11:3]; // extract
  /*# scc_wave2.vhd:306:48 */
  assign n278 = n276 == 9'b000000000;
  /*# scc_wave2.vhd:306:62 */
  assign n279 = n278 | ff_rst_ch_d;
  /*# scc_wave2.vhd:309:36 */
  assign n281 = n223_ff_cnt_ch_d == 12'b000000000000;
  /*# scc_wave2.vhd:310:48 */
  assign n283 = ff_ptr_ch_d + 5'b00001;
  /*# scc_wave2.vhd:313:48 */
  assign n285 = n223_ff_cnt_ch_d - 12'b000000000001;
  /*# scc_wave2.vhd:309:17 */
  assign n286 = n281 ? n283 : ff_ptr_ch_d;
  /*# scc_wave2.vhd:309:17 */
  assign n287 = n281 ? reg_freq_ch_d : n285;
  /*# scc_wave2.vhd:306:17 */
  assign n289 = n279 ? 5'b00000 : n286;
  /*# scc_wave2.vhd:306:17 */
  assign n290 = n279 ? reg_freq_ch_d : n287;
  /*# scc_wave2.vhd:316:34 */
  assign n291 = reg_freq_ch_e[11:3]; // extract
  /*# scc_wave2.vhd:316:48 */
  assign n293 = n291 == 9'b000000000;
  /*# scc_wave2.vhd:316:62 */
  assign n294 = n293 | ff_rst_ch_e;
  /*# scc_wave2.vhd:319:36 */
  assign n296 = n223_ff_cnt_ch_e == 12'b000000000000;
  /*# scc_wave2.vhd:320:48 */
  assign n298 = ff_ptr_ch_e + 5'b00001;
  /*# scc_wave2.vhd:323:48 */
  assign n300 = n223_ff_cnt_ch_e - 12'b000000000001;
  /*# scc_wave2.vhd:319:17 */
  assign n301 = n296 ? n298 : ff_ptr_ch_e;
  /*# scc_wave2.vhd:319:17 */
  assign n302 = n296 ? reg_freq_ch_e : n300;
  /*# scc_wave2.vhd:316:17 */
  assign n304 = n294 ? 5'b00000 : n301;
  /*# scc_wave2.vhd:316:17 */
  assign n305 = n294 ? reg_freq_ch_e : n302;
  /*# scc_wave2.vhd:333:41 */
  assign n347 = w_wave_ce ? adr : n352;
  /*# scc_wave2.vhd:334:24 */
  assign n349 = {3'b000, ff_ptr_ch_a};
  /*# scc_wave2.vhd:334:57 */
  assign n351 = ff_ch_num == 3'b000;
  /*# scc_wave2.vhd:333:66 */
  assign n352 = n351 ? n349 : n357;
  /*# scc_wave2.vhd:335:24 */
  assign n354 = {3'b001, ff_ptr_ch_b};
  /*# scc_wave2.vhd:335:57 */
  assign n356 = ff_ch_num == 3'b001;
  /*# scc_wave2.vhd:334:66 */
  assign n357 = n356 ? n354 : n362;
  /*# scc_wave2.vhd:336:24 */
  assign n359 = {3'b010, ff_ptr_ch_c};
  /*# scc_wave2.vhd:336:57 */
  assign n361 = ff_ch_num == 3'b010;
  /*# scc_wave2.vhd:335:66 */
  assign n362 = n361 ? n359 : n367;
  /*# scc_wave2.vhd:337:24 */
  assign n364 = {3'b011, ff_ptr_ch_d};
  /*# scc_wave2.vhd:337:57 */
  assign n366 = ff_ch_num == 3'b011;
  /*# scc_wave2.vhd:336:66 */
  assign n367 = n366 ? n364 : n370;
  /*# scc_wave2.vhd:338:24 */
  assign n369 = {3'b100, ff_ptr_ch_e};
  /*# scc_wave2.vhd:337:66 */
  assign n370 = sccplus ? n369 : n372;
  /*# scc_wave2.vhd:339:24 */
  assign n372 = {3'b011, ff_ptr_ch_e};
  /*# scc_wave2.vhd:341:5 */
  ram_Brtl wavemem (
    .adr(w_wave_adr),
    .clk(clk21m),
    .we(w_wave_we),
    .dbo(dbo),
    .dbi(wavemem_n373));
  /*# scc_wave2.vhd:385:17 */
  assign n402 = ff_ch_num_dl == 3'b001;
  /*# scc_wave2.vhd:386:17 */
  assign n405 = ff_ch_num_dl == 3'b010;
  /*# scc_wave2.vhd:387:17 */
  assign n408 = ff_ch_num_dl == 3'b011;
  /*# scc_wave2.vhd:388:17 */
  assign n411 = ff_ch_num_dl == 3'b100;
  /*# scc_wave2.vhd:389:17 */
  assign n414 = ff_ch_num_dl == 3'b101;
  /*# scc_wave2.vhd:384:5 */
  assign n416 = {n414, n411, n408, n405, n402};
  /*# scc_wave2.vhd:384:5 */
  always @*
    case (n416)
      5'b10000: n417 = 5'b10000;
      5'b01000: n417 = 5'b01000;
      5'b00100: n417 = 5'b00100;
      5'b00010: n417 = 5'b00010;
      5'b00001: n417 = 5'b00001;
      default: n417 = 5'b00000;
    endcase
  /*# scc_wave2.vhd:392:30 */
  assign n418 = w_ch_dec[0]; // extract
  /*# scc_wave2.vhd:392:48 */
  assign n419 = reg_ch_sel[0]; // extract
  /*# scc_wave2.vhd:392:34 */
  assign n420 = n418 & n419;
  /*# scc_wave2.vhd:393:30 */
  assign n421 = w_ch_dec[1]; // extract
  /*# scc_wave2.vhd:393:48 */
  assign n422 = reg_ch_sel[1]; // extract
  /*# scc_wave2.vhd:393:34 */
  assign n423 = n421 & n422;
  /*# scc_wave2.vhd:392:53 */
  assign n424 = n420 | n423;
  /*# scc_wave2.vhd:394:30 */
  assign n425 = w_ch_dec[2]; // extract
  /*# scc_wave2.vhd:394:48 */
  assign n426 = reg_ch_sel[2]; // extract
  /*# scc_wave2.vhd:394:34 */
  assign n427 = n425 & n426;
  /*# scc_wave2.vhd:393:53 */
  assign n428 = n424 | n427;
  /*# scc_wave2.vhd:395:30 */
  assign n429 = w_ch_dec[3]; // extract
  /*# scc_wave2.vhd:395:48 */
  assign n430 = reg_ch_sel[3]; // extract
  /*# scc_wave2.vhd:395:34 */
  assign n431 = n429 & n430;
  /*# scc_wave2.vhd:394:53 */
  assign n432 = n428 | n431;
  /*# scc_wave2.vhd:396:30 */
  assign n433 = w_ch_dec[4]; // extract
  /*# scc_wave2.vhd:396:48 */
  assign n434 = reg_ch_sel[4]; // extract
  /*# scc_wave2.vhd:396:34 */
  assign n435 = n433 & n434;
  /*# scc_wave2.vhd:395:53 */
  assign n436 = n432 | n435;
  /*# scc_wave2.vhd:398:21 */
  assign n437 = {w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit};
  /*# scc_wave2.vhd:401:29 */
  assign n439 = ff_ch_num_dl == 3'b001;
  /*# scc_wave2.vhd:402:29 */
  assign n441 = ff_ch_num_dl == 3'b010;
  /*# scc_wave2.vhd:403:29 */
  assign n443 = ff_ch_num_dl == 3'b011;
  /*# scc_wave2.vhd:404:29 */
  assign n445 = ff_ch_num_dl == 3'b100;
  /*# scc_wave2.vhd:405:29 */
  assign n447 = ff_ch_num_dl == 3'b101;
  /*# scc_wave2.vhd:400:5 */
  assign n449 = {n447, n445, n443, n441, n439};
  /*# scc_wave2.vhd:400:5 */
  always @*
    case (n449)
      5'b10000: n450 = reg_vol_ch_e;
      5'b01000: n450 = reg_vol_ch_d;
      5'b00100: n450 = reg_vol_ch_c;
      5'b00010: n450 = reg_vol_ch_b;
      5'b00001: n450 = reg_vol_ch_a;
      default: n450 = 4'b0000;
    endcase
  /*# scc_wave2.vhd:408:28 */
  assign n451 = w_ch_mask & ff_wave_dat;
  /*# scc_wave2.vhd:418:48 */
  assign n453 = {1'b0, w_ch_vol};
  /*# scc_wave2.vhd:418:35 */
  assign n454 = {{5{w_wave[7]}}, w_wave}; // sext
  /*# scc_wave2.vhd:418:35 */
  assign n455 = {{8{n453[4]}}, n453}; // sext
  /*# scc_wave2.vhd:418:35 */
  assign n456 = $signed(n454) * $signed(n455); // smul
  /*# scc_wave2.vhd:419:44 */
  assign n457 = w_mul_s[11:0]; // extract
  /*# scc_wave2.vhd:462:28 */
  assign n461 = ~ff_wave_ce;
  /*# scc_wave2.vhd:463:31 */
  assign n463 = ff_ch_num == 3'b101;
  /*# scc_wave2.vhd:466:44 */
  assign n465 = ff_ch_num + 3'b001;
  /*# scc_wave2.vhd:463:17 */
  assign n467 = n463 ? 3'b000 : n465;
  /*# scc_wave2.vhd:478:31 */
  assign n476 = ~ff_wave_ce_dl;
  /*# scc_wave2.vhd:479:34 */
  assign n478 = ff_ch_num_dl == 3'b000;
  /*# scc_wave2.vhd:482:39 */
  assign n479 = w_mul[11]; // extract
  /*# scc_wave2.vhd:482:51 */
  assign n480 = w_mul[11]; // extract
  /*# scc_wave2.vhd:482:44 */
  assign n481 = {n479, n480};
  /*# scc_wave2.vhd:482:63 */
  assign n482 = w_mul[11]; // extract
  /*# scc_wave2.vhd:482:56 */
  assign n483 = {n481, n482};
  /*# scc_wave2.vhd:482:68 */
  assign n484 = {n483, w_mul};
  /*# scc_wave2.vhd:482:77 */
  assign n485 = n484 + ff_mix;
  /*# scc_wave2.vhd:479:17 */
  assign n487 = n478 ? 15'b000000000000000 : n485;
  /*# scc_wave2.vhd:494:31 */
  assign n496 = ~ff_wave_ce_dl;
  /*# scc_wave2.vhd:495:34 */
  assign n498 = ff_ch_num_dl == 3'b000;
  /*# scc_wave2.vhd:494:13 */
  assign n500 = n498 & n496;
  /*# scc_wave2.vhd:355:9 */
  assign n508 = ff_wave_ce ? ram_dbi : n509;
  /*# scc_wave2.vhd:355:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n509 <= 8'b11111111;
    else
      n509 <= n508;
  /*# scc_wave2.vhd:201:9 */
  assign n510 = n22 ? n117 : reg_freq_ch_a;
  /*# scc_wave2.vhd:201:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n511 <= 12'b000000000000;
    else
      n511 <= n510;
  /*# scc_wave2.vhd:201:9 */
  assign n512 = n22 ? n119 : reg_freq_ch_b;
  /*# scc_wave2.vhd:201:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n513 <= 12'b000000000000;
    else
      n513 <= n512;
  /*# scc_wave2.vhd:201:9 */
  assign n514 = n22 ? n121 : reg_freq_ch_c;
  /*# scc_wave2.vhd:201:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n515 <= 12'b000000000000;
    else
      n515 <= n514;
  /*# scc_wave2.vhd:201:9 */
  assign n516 = n22 ? n123 : reg_freq_ch_d;
  /*# scc_wave2.vhd:201:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n517 <= 12'b000000000000;
    else
      n517 <= n516;
  /*# scc_wave2.vhd:201:9 */
  assign n518 = n22 ? n125 : reg_freq_ch_e;
  /*# scc_wave2.vhd:201:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n519 <= 12'b000000000000;
    else
      n519 <= n518;
  /*# scc_wave2.vhd:201:9 */
  assign n520 = n22 ? n96 : reg_vol_ch_a;
  /*# scc_wave2.vhd:201:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n521 <= 4'b0000;
    else
      n521 <= n520;
  /*# scc_wave2.vhd:201:9 */
  assign n522 = n22 ? n97 : reg_vol_ch_b;
  /*# scc_wave2.vhd:201:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n523 <= 4'b0000;
    else
      n523 <= n522;
  /*# scc_wave2.vhd:201:9 */
  assign n524 = n22 ? n98 : reg_vol_ch_c;
  /*# scc_wave2.vhd:201:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n525 <= 4'b0000;
    else
      n525 <= n524;
  /*# scc_wave2.vhd:201:9 */
  assign n526 = n22 ? n99 : reg_vol_ch_d;
  /*# scc_wave2.vhd:201:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n527 <= 4'b0000;
    else
      n527 <= n526;
  /*# scc_wave2.vhd:201:9 */
  assign n528 = n22 ? n100 : reg_vol_ch_e;
  /*# scc_wave2.vhd:201:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n529 <= 4'b0000;
    else
      n529 <= n528;
  /*# scc_wave2.vhd:201:9 */
  assign n530 = n22 ? n101 : reg_ch_sel;
  /*# scc_wave2.vhd:201:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n531 <= 5'b00000;
    else
      n531 <= n530;
  /*# scc_wave2.vhd:201:9 */
  assign n532 = n142 ? dbo : reg_mode_sel;
  /*# scc_wave2.vhd:201:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n533 <= 8'b00000000;
    else
      n533 <= n532;
  /*# scc_wave2.vhd:201:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n534 <= 1'b0;
    else
      n534 <= n133;
  /*# scc_wave2.vhd:201:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n535 <= 1'b0;
    else
      n535 <= n134;
  /*# scc_wave2.vhd:201:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n536 <= 1'b0;
    else
      n536 <= n135;
  /*# scc_wave2.vhd:201:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n537 <= 1'b0;
    else
      n537 <= n136;
  /*# scc_wave2.vhd:201:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n538 <= 1'b0;
    else
      n538 <= n137;
  /*# scc_wave2.vhd:273:9 */
  assign n539 = clkena ? n244 : ff_ptr_ch_a;
  /*# scc_wave2.vhd:273:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n540 <= 5'b00000;
    else
      n540 <= n539;
  /*# scc_wave2.vhd:273:9 */
  assign n541 = clkena ? n259 : ff_ptr_ch_b;
  /*# scc_wave2.vhd:273:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n542 <= 5'b00000;
    else
      n542 <= n541;
  /*# scc_wave2.vhd:273:9 */
  assign n543 = clkena ? n274 : ff_ptr_ch_c;
  /*# scc_wave2.vhd:273:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n544 <= 5'b00000;
    else
      n544 <= n543;
  /*# scc_wave2.vhd:273:9 */
  assign n545 = clkena ? n289 : ff_ptr_ch_d;
  /*# scc_wave2.vhd:273:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n546 <= 5'b00000;
    else
      n546 <= n545;
  /*# scc_wave2.vhd:273:9 */
  assign n547 = clkena ? n304 : ff_ptr_ch_e;
  /*# scc_wave2.vhd:273:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n548 <= 5'b00000;
    else
      n548 <= n547;
  /*# scc_wave2.vhd:461:9 */
  assign n549 = n461 ? n467 : ff_ch_num;
  /*# scc_wave2.vhd:461:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n550 <= 3'b000;
    else
      n550 <= n549;
  /*# scc_wave2.vhd:373:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n551 <= 3'b000;
    else
      n551 <= ff_ch_num;
  /*# scc_wave2.vhd:477:9 */
  assign n552 = n476 ? n487 : ff_mix;
  /*# scc_wave2.vhd:477:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n553 <= 15'b000000000000000;
    else
      n553 <= n552;
  /*# scc_wave2.vhd:373:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n554 <= 1'b0;
    else
      n554 <= w_wave_ce;
  /*# scc_wave2.vhd:373:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n555 <= 1'b0;
    else
      n555 <= ff_wave_ce;
  /*# scc_wave2.vhd:201:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n556 <= 1'b0;
    else
      n556 <= req;
  /*# scc_wave2.vhd:373:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n557 <= 8'b00000000;
    else
      n557 <= ram_dbi;
  /*# scc_wave2.vhd:493:9 */
  assign n558 = n500 ? ff_mix : ff_wave;
  /*# scc_wave2.vhd:493:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n559 <= 15'b000000000000000;
    else
      n559 <= n558;
  /*# scc_wave2.vhd:273:9 */
  assign n560 = clkena ? n245 : n223_ff_cnt_ch_a;
  /*# scc_wave2.vhd:273:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n561 <= 12'b000000000000;
    else
      n561 <= n560;
  /*# scc_wave2.vhd:273:9 */
  assign n562 = clkena ? n260 : n223_ff_cnt_ch_b;
  /*# scc_wave2.vhd:273:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n563 <= 12'b000000000000;
    else
      n563 <= n562;
  /*# scc_wave2.vhd:273:9 */
  assign n564 = clkena ? n275 : n223_ff_cnt_ch_c;
  /*# scc_wave2.vhd:273:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n565 <= 12'b000000000000;
    else
      n565 <= n564;
  /*# scc_wave2.vhd:273:9 */
  assign n566 = clkena ? n290 : n223_ff_cnt_ch_d;
  /*# scc_wave2.vhd:273:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n567 <= 12'b000000000000;
    else
      n567 <= n566;
  /*# scc_wave2.vhd:273:9 */
  assign n568 = clkena ? n305 : n223_ff_cnt_ch_e;
  /*# scc_wave2.vhd:273:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n569 <= 12'b000000000000;
    else
      n569 <= n568;
endmodule

