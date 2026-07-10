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
//   fpga/src/ocm/scc_wave2.vhd            (md5 f5d39e65173285134c60b181dcd46e3c)
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
//                   _52dbg: dbg_wavlatch = togglea en cada CAPTURA real del
//                           latch final ff_wave (vivo = ~4.5M capturas/s a
//                           27M, CON o SIN tono => cuadrada 2.25 MHz duty
//                           50%; muerto = fijo; ligado-a-accesos = kHz
//                           esporadicos solo bajo martilleo CPU)
//
// ⚠ _52 EXPERIMENTO DE RTL (no solo sondas): el proceso ff_wave captura
//   SIN el guard ff_wave_ce_dl='0' (candidato a fix del latch final que la
//   sintesis GW5A parece miscompilar: plano en beeper/test, oscila en juego).
//   ff_mix conserva su guard. Ver comentario _52 en scc_wave2.vhd.
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
//     avance del puntero (N1), escaneo vivo (N2), acumulador activo (N3) y
//     tasa de captura del latch final (N4) con las sondas dbg_ptr_lsb /
//     dbg_scan_lsb / dbg_mix_nz / dbg_wavlatch calibradas.
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
  reg [7:0] n602;
  wire [7:0] n603; // mem_rd
  assign dbi = n603; //(module output)
  /*# ram.vhd:50:10 */
  assign iadr = n602; // (signal)
  /*# ram.vhd:56:5 */
  always @(posedge clk)
    n602 <= adr;
  reg [7:0] blkram[255:0] ; // memory
  assign n603 = blkram[iadr];
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
   output dbg_mix_nz,
   output dbg_wavlatch);
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
  wire ff_wavlatch_tgl;
  wire n13;
  wire n14;
  wire n15;
  wire n16;
  wire [2:0] n17;
  wire n19;
  wire n20;
  wire [2:0] n21;
  wire n23;
  wire n24;
  wire n25;
  wire n26;
  wire [3:0] n27;
  wire n28;
  wire n30;
  wire [3:0] n31;
  wire n32;
  wire n34;
  wire n35;
  wire n37;
  wire [3:0] n38;
  wire n39;
  wire n41;
  wire n42;
  wire n44;
  wire [3:0] n45;
  wire n46;
  wire n48;
  wire n49;
  wire n51;
  wire [3:0] n52;
  wire n53;
  wire n55;
  wire n56;
  wire n58;
  wire [3:0] n59;
  wire n60;
  wire n62;
  wire [3:0] n63;
  wire n65;
  wire [3:0] n66;
  wire n68;
  wire [3:0] n69;
  wire n71;
  wire [3:0] n72;
  wire n74;
  wire [3:0] n75;
  wire n77;
  wire [4:0] n78;
  wire [14:0] n79;
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
  wire [7:0] n96;
  reg [7:0] n97;
  wire [3:0] n98;
  reg [3:0] n99;
  reg [3:0] n100;
  reg [3:0] n101;
  reg [3:0] n102;
  reg [3:0] n103;
  reg [3:0] n104;
  reg [4:0] n105;
  reg n106;
  reg n107;
  reg n108;
  reg n109;
  reg n110;
  wire n112;
  wire n114;
  wire n116;
  wire n118;
  wire n120;
  wire [11:0] n121;
  wire [11:0] n123;
  wire [11:0] n125;
  wire [11:0] n127;
  wire [11:0] n129;
  wire n137;
  wire n138;
  wire n139;
  wire n140;
  wire n141;
  wire n142;
  wire [2:0] n143;
  wire n145;
  wire n146;
  wire n204;
  wire n205;
  wire n206;
  wire n208;
  wire n209;
  wire n210;
  wire n214;
  wire n215;
  wire n219;
  wire n220;
  wire n224;
  wire n225;
  wire n227;
  wire n228;
  wire n231;
  wire n232;
  reg [11:0] n234_ff_cnt_ch_a;
  reg [11:0] n234_ff_cnt_ch_b;
  reg [11:0] n234_ff_cnt_ch_c;
  reg [11:0] n234_ff_cnt_ch_d;
  reg [11:0] n234_ff_cnt_ch_e;
  wire [8:0] n242;
  wire n244;
  wire n245;
  wire n247;
  wire [4:0] n249;
  wire [11:0] n251;
  wire [4:0] n252;
  wire [11:0] n253;
  wire [4:0] n255;
  wire [11:0] n256;
  wire [8:0] n257;
  wire n259;
  wire n260;
  wire n262;
  wire [4:0] n264;
  wire [11:0] n266;
  wire [4:0] n267;
  wire [11:0] n268;
  wire [4:0] n270;
  wire [11:0] n271;
  wire [8:0] n272;
  wire n274;
  wire n275;
  wire n277;
  wire [4:0] n279;
  wire [11:0] n281;
  wire [4:0] n282;
  wire [11:0] n283;
  wire [4:0] n285;
  wire [11:0] n286;
  wire [8:0] n287;
  wire n289;
  wire n290;
  wire n292;
  wire [4:0] n294;
  wire [11:0] n296;
  wire [4:0] n297;
  wire [11:0] n298;
  wire [4:0] n300;
  wire [11:0] n301;
  wire [8:0] n302;
  wire n304;
  wire n305;
  wire n307;
  wire [4:0] n309;
  wire [11:0] n311;
  wire [4:0] n312;
  wire [11:0] n313;
  wire [4:0] n315;
  wire [11:0] n316;
  wire [7:0] n358;
  wire [7:0] n360;
  wire n362;
  wire [7:0] n363;
  wire [7:0] n365;
  wire n367;
  wire [7:0] n368;
  wire [7:0] n370;
  wire n372;
  wire [7:0] n373;
  wire [7:0] n375;
  wire n377;
  wire [7:0] n378;
  wire [7:0] n380;
  wire [7:0] n381;
  wire [7:0] n383;
  wire [7:0] wavemem_n384;
  wire n413;
  wire n416;
  wire n419;
  wire n422;
  wire n425;
  wire [4:0] n427;
  reg [4:0] n428;
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
  wire n447;
  wire [7:0] n448;
  wire n450;
  wire n452;
  wire n454;
  wire n456;
  wire n458;
  wire [4:0] n460;
  reg [3:0] n461;
  wire [7:0] n462;
  wire [4:0] n464;
  wire [12:0] n465;
  wire [12:0] n466;
  wire [12:0] n467;
  wire [11:0] n468;
  wire n472;
  wire n474;
  wire [2:0] n476;
  wire [2:0] n478;
  wire n487;
  wire n489;
  wire n490;
  wire n491;
  wire [1:0] n492;
  wire n493;
  wire [2:0] n494;
  wire [14:0] n495;
  wire [14:0] n496;
  wire [14:0] n498;
  wire n508;
  wire n509;
  wire [7:0] n522;
  reg [7:0] n523;
  wire [11:0] n524;
  reg [11:0] n525;
  wire [11:0] n526;
  reg [11:0] n527;
  wire [11:0] n528;
  reg [11:0] n529;
  wire [11:0] n530;
  reg [11:0] n531;
  wire [11:0] n532;
  reg [11:0] n533;
  wire [3:0] n534;
  reg [3:0] n535;
  wire [3:0] n536;
  reg [3:0] n537;
  wire [3:0] n538;
  reg [3:0] n539;
  wire [3:0] n540;
  reg [3:0] n541;
  wire [3:0] n542;
  reg [3:0] n543;
  wire [4:0] n544;
  reg [4:0] n545;
  wire [7:0] n546;
  reg [7:0] n547;
  reg n548;
  reg n549;
  reg n550;
  reg n551;
  reg n552;
  wire [4:0] n553;
  reg [4:0] n554;
  wire [4:0] n555;
  reg [4:0] n556;
  wire [4:0] n557;
  reg [4:0] n558;
  wire [4:0] n559;
  reg [4:0] n560;
  wire [4:0] n561;
  reg [4:0] n562;
  wire [2:0] n563;
  reg [2:0] n564;
  reg [2:0] n565;
  wire [14:0] n566;
  reg [14:0] n567;
  reg n568;
  reg n569;
  reg n570;
  reg [7:0] n571;
  wire [14:0] n572;
  reg [14:0] n573;
  wire n574;
  reg n575;
  wire [11:0] n576;
  reg [11:0] n577;
  wire [11:0] n578;
  reg [11:0] n579;
  wire [11:0] n580;
  reg [11:0] n581;
  wire [11:0] n582;
  reg [11:0] n583;
  wire [11:0] n584;
  reg [11:0] n585;
  assign ack = ff_req_dl; //(module output)
  assign dbi = n523; //(module output)
  assign wave = ff_wave; //(module output)
  assign dbg_vol_nz = n215; //(module output)
  assign dbg_sel_nz = n220; //(module output)
  assign dbg_freq_nz = n225; //(module output)
  assign dbg_ptr_lsb = n227; //(module output)
  assign dbg_scan_lsb = n228; //(module output)
  assign dbg_mix_nz = n232; //(module output)
  assign dbg_wavlatch = ff_wavlatch_tgl; //(module output)
  /*# scc_wave2.vhd:129:12 */
  assign w_wave_ce = n206; // (signal)
  /*# scc_wave2.vhd:130:12 */
  assign w_wave_we = n210; // (signal)
  /*# scc_wave2.vhd:131:12 */
  assign w_wave_adr = n358; // (signal)
  /*# scc_wave2.vhd:132:12 */
  assign w_ch_dec = n428; // (signal)
  /*# scc_wave2.vhd:133:12 */
  assign w_ch_bit = n447; // (signal)
  /*# scc_wave2.vhd:134:12 */
  assign w_ch_mask = n448; // (signal)
  /*# scc_wave2.vhd:135:12 */
  assign w_ch_vol = n461; // (signal)
  /*# scc_wave2.vhd:136:12 */
  assign w_wave = n462; // (signal)
  /*# scc_wave2.vhd:137:12 */
  assign w_mul = n468; // (signal)
  /*# scc_wave2.vhd:138:12 */
  assign w_mul_s = n467; // (signal)
  /*# scc_wave2.vhd:139:12 */
  assign ram_dbi = wavemem_n384; // (signal)
  /*# scc_wave2.vhd:145:12 */
  assign reg_freq_ch_a = n525; // (signal)
  /*# scc_wave2.vhd:146:12 */
  assign reg_freq_ch_b = n527; // (signal)
  /*# scc_wave2.vhd:147:12 */
  assign reg_freq_ch_c = n529; // (signal)
  /*# scc_wave2.vhd:148:12 */
  assign reg_freq_ch_d = n531; // (signal)
  /*# scc_wave2.vhd:149:12 */
  assign reg_freq_ch_e = n533; // (signal)
  /*# scc_wave2.vhd:150:12 */
  assign reg_vol_ch_a = n535; // (signal)
  /*# scc_wave2.vhd:151:12 */
  assign reg_vol_ch_b = n537; // (signal)
  /*# scc_wave2.vhd:152:12 */
  assign reg_vol_ch_c = n539; // (signal)
  /*# scc_wave2.vhd:153:12 */
  assign reg_vol_ch_d = n541; // (signal)
  /*# scc_wave2.vhd:154:12 */
  assign reg_vol_ch_e = n543; // (signal)
  /*# scc_wave2.vhd:155:12 */
  assign reg_ch_sel = n545; // (signal)
  /*# scc_wave2.vhd:156:12 */
  assign reg_mode_sel = n547; // (signal)
  /*# scc_wave2.vhd:159:12 */
  assign ff_rst_ch_a = n548; // (signal)
  /*# scc_wave2.vhd:160:12 */
  assign ff_rst_ch_b = n549; // (signal)
  /*# scc_wave2.vhd:161:12 */
  assign ff_rst_ch_c = n550; // (signal)
  /*# scc_wave2.vhd:162:12 */
  assign ff_rst_ch_d = n551; // (signal)
  /*# scc_wave2.vhd:163:12 */
  assign ff_rst_ch_e = n552; // (signal)
  /*# scc_wave2.vhd:164:12 */
  assign ff_ptr_ch_a = n554; // (signal)
  /*# scc_wave2.vhd:165:12 */
  assign ff_ptr_ch_b = n556; // (signal)
  /*# scc_wave2.vhd:166:12 */
  assign ff_ptr_ch_c = n558; // (signal)
  /*# scc_wave2.vhd:167:12 */
  assign ff_ptr_ch_d = n560; // (signal)
  /*# scc_wave2.vhd:168:12 */
  assign ff_ptr_ch_e = n562; // (signal)
  /*# scc_wave2.vhd:169:12 */
  assign ff_ch_num = n564; // (signal)
  /*# scc_wave2.vhd:170:12 */
  assign ff_ch_num_dl = n565; // (signal)
  /*# scc_wave2.vhd:171:12 */
  assign ff_mix = n567; // (signal)
  /*# scc_wave2.vhd:172:12 */
  assign ff_wave_ce = n568; // (signal)
  /*# scc_wave2.vhd:173:12 */
  assign ff_wave_ce_dl = n569; // (signal)
  /*# scc_wave2.vhd:174:12 */
  assign ff_req_dl = n570; // (signal)
  /*# scc_wave2.vhd:175:12 */
  assign ff_wave_dat = n571; // (signal)
  /*# scc_wave2.vhd:176:12 */
  assign ff_wave = n573; // (signal)
  /*# scc_wave2.vhd:177:12 */
  assign ff_wavlatch_tgl = n575; // (signal)
  /*# scc_wave2.vhd:211:41 */
  assign n13 = ~ff_req_dl;
  /*# scc_wave2.vhd:211:27 */
  assign n14 = n13 & req;
  /*# scc_wave2.vhd:211:47 */
  assign n15 = wrt & n14;
  /*# scc_wave2.vhd:212:27 */
  assign n16 = ~sccplus;
  /*# scc_wave2.vhd:212:40 */
  assign n17 = adr[7:5]; // extract
  /*# scc_wave2.vhd:212:53 */
  assign n19 = n17 == 3'b100;
  /*# scc_wave2.vhd:212:33 */
  assign n20 = n19 & n16;
  /*# scc_wave2.vhd:213:40 */
  assign n21 = adr[7:5]; // extract
  /*# scc_wave2.vhd:213:53 */
  assign n23 = n21 == 3'b101;
  /*# scc_wave2.vhd:213:33 */
  assign n24 = n23 & sccplus;
  /*# scc_wave2.vhd:212:62 */
  assign n25 = n20 | n24;
  /*# scc_wave2.vhd:211:61 */
  assign n26 = n25 & n15;
  /*# scc_wave2.vhd:214:25 */
  assign n27 = adr[3:0]; // extract
  /*# scc_wave2.vhd:215:114 */
  assign n28 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:215:21 */
  assign n30 = n27 == 4'b0000;
  /*# scc_wave2.vhd:216:71 */
  assign n31 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:216:114 */
  assign n32 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:216:21 */
  assign n34 = n27 == 4'b0001;
  /*# scc_wave2.vhd:217:114 */
  assign n35 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:217:21 */
  assign n37 = n27 == 4'b0010;
  /*# scc_wave2.vhd:218:71 */
  assign n38 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:218:114 */
  assign n39 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:218:21 */
  assign n41 = n27 == 4'b0011;
  /*# scc_wave2.vhd:219:114 */
  assign n42 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:219:21 */
  assign n44 = n27 == 4'b0100;
  /*# scc_wave2.vhd:220:71 */
  assign n45 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:220:114 */
  assign n46 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:220:21 */
  assign n48 = n27 == 4'b0101;
  /*# scc_wave2.vhd:221:114 */
  assign n49 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:221:21 */
  assign n51 = n27 == 4'b0110;
  /*# scc_wave2.vhd:222:71 */
  assign n52 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:222:114 */
  assign n53 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:222:21 */
  assign n55 = n27 == 4'b0111;
  /*# scc_wave2.vhd:223:114 */
  assign n56 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:223:21 */
  assign n58 = n27 == 4'b1000;
  /*# scc_wave2.vhd:224:71 */
  assign n59 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:224:114 */
  assign n60 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:224:21 */
  assign n62 = n27 == 4'b1001;
  /*# scc_wave2.vhd:225:71 */
  assign n63 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:225:21 */
  assign n65 = n27 == 4'b1010;
  /*# scc_wave2.vhd:226:71 */
  assign n66 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:226:21 */
  assign n68 = n27 == 4'b1011;
  /*# scc_wave2.vhd:227:71 */
  assign n69 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:227:21 */
  assign n71 = n27 == 4'b1100;
  /*# scc_wave2.vhd:228:71 */
  assign n72 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:228:21 */
  assign n74 = n27 == 4'b1101;
  /*# scc_wave2.vhd:229:71 */
  assign n75 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:229:21 */
  assign n77 = n27 == 4'b1110;
  /*# scc_wave2.vhd:230:71 */
  assign n78 = dbo[4:0]; // extract
  /*# scc_wave2.vhd:214:17 */
  assign n79 = {n77, n74, n71, n68, n65, n62, n58, n55, n51, n48, n44, n41, n37, n34, n30};
  /*# scc_wave2.vhd:145:12 */
  assign n80 = reg_freq_ch_a[7:0]; // extract
  /*# scc_wave2.vhd:214:17 */
  always @*
    case (n79)
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
      15'b000000000000100: n81 = n80;
      15'b000000000000010: n81 = n80;
      15'b000000000000001: n81 = dbo;
      default: n81 = n80;
    endcase
  /*# scc_wave2.vhd:145:12 */
  assign n82 = reg_freq_ch_a[11:8]; // extract
  /*# scc_wave2.vhd:214:17 */
  always @*
    case (n79)
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
      15'b000000000001000: n83 = n82;
      15'b000000000000100: n83 = n82;
      15'b000000000000010: n83 = n31;
      15'b000000000000001: n83 = n82;
      default: n83 = n82;
    endcase
  /*# scc_wave2.vhd:146:12 */
  assign n84 = reg_freq_ch_b[7:0]; // extract
  /*# scc_wave2.vhd:214:17 */
  always @*
    case (n79)
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
      15'b000000000010000: n85 = n84;
      15'b000000000001000: n85 = n84;
      15'b000000000000100: n85 = dbo;
      15'b000000000000010: n85 = n84;
      15'b000000000000001: n85 = n84;
      default: n85 = n84;
    endcase
  /*# scc_wave2.vhd:146:12 */
  assign n86 = reg_freq_ch_b[11:8]; // extract
  /*# scc_wave2.vhd:214:17 */
  always @*
    case (n79)
      15'b100000000000000: n87 = n86;
      15'b010000000000000: n87 = n86;
      15'b001000000000000: n87 = n86;
      15'b000100000000000: n87 = n86;
      15'b000010000000000: n87 = n86;
      15'b000001000000000: n87 = n86;
      15'b000000100000000: n87 = n86;
      15'b000000010000000: n87 = n86;
      15'b000000001000000: n87 = n86;
      15'b000000000100000: n87 = n86;
      15'b000000000010000: n87 = n86;
      15'b000000000001000: n87 = n38;
      15'b000000000000100: n87 = n86;
      15'b000000000000010: n87 = n86;
      15'b000000000000001: n87 = n86;
      default: n87 = n86;
    endcase
  /*# scc_wave2.vhd:147:12 */
  assign n88 = reg_freq_ch_c[7:0]; // extract
  /*# scc_wave2.vhd:214:17 */
  always @*
    case (n79)
      15'b100000000000000: n89 = n88;
      15'b010000000000000: n89 = n88;
      15'b001000000000000: n89 = n88;
      15'b000100000000000: n89 = n88;
      15'b000010000000000: n89 = n88;
      15'b000001000000000: n89 = n88;
      15'b000000100000000: n89 = n88;
      15'b000000010000000: n89 = n88;
      15'b000000001000000: n89 = n88;
      15'b000000000100000: n89 = n88;
      15'b000000000010000: n89 = dbo;
      15'b000000000001000: n89 = n88;
      15'b000000000000100: n89 = n88;
      15'b000000000000010: n89 = n88;
      15'b000000000000001: n89 = n88;
      default: n89 = n88;
    endcase
  /*# scc_wave2.vhd:147:12 */
  assign n90 = reg_freq_ch_c[11:8]; // extract
  /*# scc_wave2.vhd:214:17 */
  always @*
    case (n79)
      15'b100000000000000: n91 = n90;
      15'b010000000000000: n91 = n90;
      15'b001000000000000: n91 = n90;
      15'b000100000000000: n91 = n90;
      15'b000010000000000: n91 = n90;
      15'b000001000000000: n91 = n90;
      15'b000000100000000: n91 = n90;
      15'b000000010000000: n91 = n90;
      15'b000000001000000: n91 = n90;
      15'b000000000100000: n91 = n45;
      15'b000000000010000: n91 = n90;
      15'b000000000001000: n91 = n90;
      15'b000000000000100: n91 = n90;
      15'b000000000000010: n91 = n90;
      15'b000000000000001: n91 = n90;
      default: n91 = n90;
    endcase
  /*# scc_wave2.vhd:148:12 */
  assign n92 = reg_freq_ch_d[7:0]; // extract
  /*# scc_wave2.vhd:214:17 */
  always @*
    case (n79)
      15'b100000000000000: n93 = n92;
      15'b010000000000000: n93 = n92;
      15'b001000000000000: n93 = n92;
      15'b000100000000000: n93 = n92;
      15'b000010000000000: n93 = n92;
      15'b000001000000000: n93 = n92;
      15'b000000100000000: n93 = n92;
      15'b000000010000000: n93 = n92;
      15'b000000001000000: n93 = dbo;
      15'b000000000100000: n93 = n92;
      15'b000000000010000: n93 = n92;
      15'b000000000001000: n93 = n92;
      15'b000000000000100: n93 = n92;
      15'b000000000000010: n93 = n92;
      15'b000000000000001: n93 = n92;
      default: n93 = n92;
    endcase
  /*# scc_wave2.vhd:148:12 */
  assign n94 = reg_freq_ch_d[11:8]; // extract
  /*# scc_wave2.vhd:214:17 */
  always @*
    case (n79)
      15'b100000000000000: n95 = n94;
      15'b010000000000000: n95 = n94;
      15'b001000000000000: n95 = n94;
      15'b000100000000000: n95 = n94;
      15'b000010000000000: n95 = n94;
      15'b000001000000000: n95 = n94;
      15'b000000100000000: n95 = n94;
      15'b000000010000000: n95 = n52;
      15'b000000001000000: n95 = n94;
      15'b000000000100000: n95 = n94;
      15'b000000000010000: n95 = n94;
      15'b000000000001000: n95 = n94;
      15'b000000000000100: n95 = n94;
      15'b000000000000010: n95 = n94;
      15'b000000000000001: n95 = n94;
      default: n95 = n94;
    endcase
  /*# scc_wave2.vhd:149:12 */
  assign n96 = reg_freq_ch_e[7:0]; // extract
  /*# scc_wave2.vhd:214:17 */
  always @*
    case (n79)
      15'b100000000000000: n97 = n96;
      15'b010000000000000: n97 = n96;
      15'b001000000000000: n97 = n96;
      15'b000100000000000: n97 = n96;
      15'b000010000000000: n97 = n96;
      15'b000001000000000: n97 = n96;
      15'b000000100000000: n97 = dbo;
      15'b000000010000000: n97 = n96;
      15'b000000001000000: n97 = n96;
      15'b000000000100000: n97 = n96;
      15'b000000000010000: n97 = n96;
      15'b000000000001000: n97 = n96;
      15'b000000000000100: n97 = n96;
      15'b000000000000010: n97 = n96;
      15'b000000000000001: n97 = n96;
      default: n97 = n96;
    endcase
  /*# scc_wave2.vhd:149:12 */
  assign n98 = reg_freq_ch_e[11:8]; // extract
  /*# scc_wave2.vhd:214:17 */
  always @*
    case (n79)
      15'b100000000000000: n99 = n98;
      15'b010000000000000: n99 = n98;
      15'b001000000000000: n99 = n98;
      15'b000100000000000: n99 = n98;
      15'b000010000000000: n99 = n98;
      15'b000001000000000: n99 = n59;
      15'b000000100000000: n99 = n98;
      15'b000000010000000: n99 = n98;
      15'b000000001000000: n99 = n98;
      15'b000000000100000: n99 = n98;
      15'b000000000010000: n99 = n98;
      15'b000000000001000: n99 = n98;
      15'b000000000000100: n99 = n98;
      15'b000000000000010: n99 = n98;
      15'b000000000000001: n99 = n98;
      default: n99 = n98;
    endcase
  /*# scc_wave2.vhd:214:17 */
  always @*
    case (n79)
      15'b100000000000000: n100 = reg_vol_ch_a;
      15'b010000000000000: n100 = reg_vol_ch_a;
      15'b001000000000000: n100 = reg_vol_ch_a;
      15'b000100000000000: n100 = reg_vol_ch_a;
      15'b000010000000000: n100 = n63;
      15'b000001000000000: n100 = reg_vol_ch_a;
      15'b000000100000000: n100 = reg_vol_ch_a;
      15'b000000010000000: n100 = reg_vol_ch_a;
      15'b000000001000000: n100 = reg_vol_ch_a;
      15'b000000000100000: n100 = reg_vol_ch_a;
      15'b000000000010000: n100 = reg_vol_ch_a;
      15'b000000000001000: n100 = reg_vol_ch_a;
      15'b000000000000100: n100 = reg_vol_ch_a;
      15'b000000000000010: n100 = reg_vol_ch_a;
      15'b000000000000001: n100 = reg_vol_ch_a;
      default: n100 = reg_vol_ch_a;
    endcase
  /*# scc_wave2.vhd:214:17 */
  always @*
    case (n79)
      15'b100000000000000: n101 = reg_vol_ch_b;
      15'b010000000000000: n101 = reg_vol_ch_b;
      15'b001000000000000: n101 = reg_vol_ch_b;
      15'b000100000000000: n101 = n66;
      15'b000010000000000: n101 = reg_vol_ch_b;
      15'b000001000000000: n101 = reg_vol_ch_b;
      15'b000000100000000: n101 = reg_vol_ch_b;
      15'b000000010000000: n101 = reg_vol_ch_b;
      15'b000000001000000: n101 = reg_vol_ch_b;
      15'b000000000100000: n101 = reg_vol_ch_b;
      15'b000000000010000: n101 = reg_vol_ch_b;
      15'b000000000001000: n101 = reg_vol_ch_b;
      15'b000000000000100: n101 = reg_vol_ch_b;
      15'b000000000000010: n101 = reg_vol_ch_b;
      15'b000000000000001: n101 = reg_vol_ch_b;
      default: n101 = reg_vol_ch_b;
    endcase
  /*# scc_wave2.vhd:214:17 */
  always @*
    case (n79)
      15'b100000000000000: n102 = reg_vol_ch_c;
      15'b010000000000000: n102 = reg_vol_ch_c;
      15'b001000000000000: n102 = n69;
      15'b000100000000000: n102 = reg_vol_ch_c;
      15'b000010000000000: n102 = reg_vol_ch_c;
      15'b000001000000000: n102 = reg_vol_ch_c;
      15'b000000100000000: n102 = reg_vol_ch_c;
      15'b000000010000000: n102 = reg_vol_ch_c;
      15'b000000001000000: n102 = reg_vol_ch_c;
      15'b000000000100000: n102 = reg_vol_ch_c;
      15'b000000000010000: n102 = reg_vol_ch_c;
      15'b000000000001000: n102 = reg_vol_ch_c;
      15'b000000000000100: n102 = reg_vol_ch_c;
      15'b000000000000010: n102 = reg_vol_ch_c;
      15'b000000000000001: n102 = reg_vol_ch_c;
      default: n102 = reg_vol_ch_c;
    endcase
  /*# scc_wave2.vhd:214:17 */
  always @*
    case (n79)
      15'b100000000000000: n103 = reg_vol_ch_d;
      15'b010000000000000: n103 = n72;
      15'b001000000000000: n103 = reg_vol_ch_d;
      15'b000100000000000: n103 = reg_vol_ch_d;
      15'b000010000000000: n103 = reg_vol_ch_d;
      15'b000001000000000: n103 = reg_vol_ch_d;
      15'b000000100000000: n103 = reg_vol_ch_d;
      15'b000000010000000: n103 = reg_vol_ch_d;
      15'b000000001000000: n103 = reg_vol_ch_d;
      15'b000000000100000: n103 = reg_vol_ch_d;
      15'b000000000010000: n103 = reg_vol_ch_d;
      15'b000000000001000: n103 = reg_vol_ch_d;
      15'b000000000000100: n103 = reg_vol_ch_d;
      15'b000000000000010: n103 = reg_vol_ch_d;
      15'b000000000000001: n103 = reg_vol_ch_d;
      default: n103 = reg_vol_ch_d;
    endcase
  /*# scc_wave2.vhd:214:17 */
  always @*
    case (n79)
      15'b100000000000000: n104 = n75;
      15'b010000000000000: n104 = reg_vol_ch_e;
      15'b001000000000000: n104 = reg_vol_ch_e;
      15'b000100000000000: n104 = reg_vol_ch_e;
      15'b000010000000000: n104 = reg_vol_ch_e;
      15'b000001000000000: n104 = reg_vol_ch_e;
      15'b000000100000000: n104 = reg_vol_ch_e;
      15'b000000010000000: n104 = reg_vol_ch_e;
      15'b000000001000000: n104 = reg_vol_ch_e;
      15'b000000000100000: n104 = reg_vol_ch_e;
      15'b000000000010000: n104 = reg_vol_ch_e;
      15'b000000000001000: n104 = reg_vol_ch_e;
      15'b000000000000100: n104 = reg_vol_ch_e;
      15'b000000000000010: n104 = reg_vol_ch_e;
      15'b000000000000001: n104 = reg_vol_ch_e;
      default: n104 = reg_vol_ch_e;
    endcase
  /*# scc_wave2.vhd:214:17 */
  always @*
    case (n79)
      15'b100000000000000: n105 = reg_ch_sel;
      15'b010000000000000: n105 = reg_ch_sel;
      15'b001000000000000: n105 = reg_ch_sel;
      15'b000100000000000: n105 = reg_ch_sel;
      15'b000010000000000: n105 = reg_ch_sel;
      15'b000001000000000: n105 = reg_ch_sel;
      15'b000000100000000: n105 = reg_ch_sel;
      15'b000000010000000: n105 = reg_ch_sel;
      15'b000000001000000: n105 = reg_ch_sel;
      15'b000000000100000: n105 = reg_ch_sel;
      15'b000000000010000: n105 = reg_ch_sel;
      15'b000000000001000: n105 = reg_ch_sel;
      15'b000000000000100: n105 = reg_ch_sel;
      15'b000000000000010: n105 = reg_ch_sel;
      15'b000000000000001: n105 = reg_ch_sel;
      default: n105 = n78;
    endcase
  /*# scc_wave2.vhd:214:17 */
  always @*
    case (n79)
      15'b100000000000000: n106 = ff_rst_ch_a;
      15'b010000000000000: n106 = ff_rst_ch_a;
      15'b001000000000000: n106 = ff_rst_ch_a;
      15'b000100000000000: n106 = ff_rst_ch_a;
      15'b000010000000000: n106 = ff_rst_ch_a;
      15'b000001000000000: n106 = ff_rst_ch_a;
      15'b000000100000000: n106 = ff_rst_ch_a;
      15'b000000010000000: n106 = ff_rst_ch_a;
      15'b000000001000000: n106 = ff_rst_ch_a;
      15'b000000000100000: n106 = ff_rst_ch_a;
      15'b000000000010000: n106 = ff_rst_ch_a;
      15'b000000000001000: n106 = ff_rst_ch_a;
      15'b000000000000100: n106 = ff_rst_ch_a;
      15'b000000000000010: n106 = n32;
      15'b000000000000001: n106 = n28;
      default: n106 = ff_rst_ch_a;
    endcase
  /*# scc_wave2.vhd:214:17 */
  always @*
    case (n79)
      15'b100000000000000: n107 = ff_rst_ch_b;
      15'b010000000000000: n107 = ff_rst_ch_b;
      15'b001000000000000: n107 = ff_rst_ch_b;
      15'b000100000000000: n107 = ff_rst_ch_b;
      15'b000010000000000: n107 = ff_rst_ch_b;
      15'b000001000000000: n107 = ff_rst_ch_b;
      15'b000000100000000: n107 = ff_rst_ch_b;
      15'b000000010000000: n107 = ff_rst_ch_b;
      15'b000000001000000: n107 = ff_rst_ch_b;
      15'b000000000100000: n107 = ff_rst_ch_b;
      15'b000000000010000: n107 = ff_rst_ch_b;
      15'b000000000001000: n107 = n39;
      15'b000000000000100: n107 = n35;
      15'b000000000000010: n107 = ff_rst_ch_b;
      15'b000000000000001: n107 = ff_rst_ch_b;
      default: n107 = ff_rst_ch_b;
    endcase
  /*# scc_wave2.vhd:214:17 */
  always @*
    case (n79)
      15'b100000000000000: n108 = ff_rst_ch_c;
      15'b010000000000000: n108 = ff_rst_ch_c;
      15'b001000000000000: n108 = ff_rst_ch_c;
      15'b000100000000000: n108 = ff_rst_ch_c;
      15'b000010000000000: n108 = ff_rst_ch_c;
      15'b000001000000000: n108 = ff_rst_ch_c;
      15'b000000100000000: n108 = ff_rst_ch_c;
      15'b000000010000000: n108 = ff_rst_ch_c;
      15'b000000001000000: n108 = ff_rst_ch_c;
      15'b000000000100000: n108 = n46;
      15'b000000000010000: n108 = n42;
      15'b000000000001000: n108 = ff_rst_ch_c;
      15'b000000000000100: n108 = ff_rst_ch_c;
      15'b000000000000010: n108 = ff_rst_ch_c;
      15'b000000000000001: n108 = ff_rst_ch_c;
      default: n108 = ff_rst_ch_c;
    endcase
  /*# scc_wave2.vhd:214:17 */
  always @*
    case (n79)
      15'b100000000000000: n109 = ff_rst_ch_d;
      15'b010000000000000: n109 = ff_rst_ch_d;
      15'b001000000000000: n109 = ff_rst_ch_d;
      15'b000100000000000: n109 = ff_rst_ch_d;
      15'b000010000000000: n109 = ff_rst_ch_d;
      15'b000001000000000: n109 = ff_rst_ch_d;
      15'b000000100000000: n109 = ff_rst_ch_d;
      15'b000000010000000: n109 = n53;
      15'b000000001000000: n109 = n49;
      15'b000000000100000: n109 = ff_rst_ch_d;
      15'b000000000010000: n109 = ff_rst_ch_d;
      15'b000000000001000: n109 = ff_rst_ch_d;
      15'b000000000000100: n109 = ff_rst_ch_d;
      15'b000000000000010: n109 = ff_rst_ch_d;
      15'b000000000000001: n109 = ff_rst_ch_d;
      default: n109 = ff_rst_ch_d;
    endcase
  /*# scc_wave2.vhd:214:17 */
  always @*
    case (n79)
      15'b100000000000000: n110 = ff_rst_ch_e;
      15'b010000000000000: n110 = ff_rst_ch_e;
      15'b001000000000000: n110 = ff_rst_ch_e;
      15'b000100000000000: n110 = ff_rst_ch_e;
      15'b000010000000000: n110 = ff_rst_ch_e;
      15'b000001000000000: n110 = n60;
      15'b000000100000000: n110 = n56;
      15'b000000010000000: n110 = ff_rst_ch_e;
      15'b000000001000000: n110 = ff_rst_ch_e;
      15'b000000000100000: n110 = ff_rst_ch_e;
      15'b000000000010000: n110 = ff_rst_ch_e;
      15'b000000000001000: n110 = ff_rst_ch_e;
      15'b000000000000100: n110 = ff_rst_ch_e;
      15'b000000000000010: n110 = ff_rst_ch_e;
      15'b000000000000001: n110 = ff_rst_ch_e;
      default: n110 = ff_rst_ch_e;
    endcase
  /*# scc_wave2.vhd:232:13 */
  assign n112 = clkena ? 1'b0 : ff_rst_ch_a;
  /*# scc_wave2.vhd:232:13 */
  assign n114 = clkena ? 1'b0 : ff_rst_ch_b;
  /*# scc_wave2.vhd:232:13 */
  assign n116 = clkena ? 1'b0 : ff_rst_ch_c;
  /*# scc_wave2.vhd:232:13 */
  assign n118 = clkena ? 1'b0 : ff_rst_ch_d;
  /*# scc_wave2.vhd:232:13 */
  assign n120 = clkena ? 1'b0 : ff_rst_ch_e;
  /*# scc_wave2.vhd:211:13 */
  assign n121 = {n83, n81};
  /*# scc_wave2.vhd:211:13 */
  assign n123 = {n87, n85};
  /*# scc_wave2.vhd:211:13 */
  assign n125 = {n91, n89};
  /*# scc_wave2.vhd:211:13 */
  assign n127 = {n95, n93};
  /*# scc_wave2.vhd:211:13 */
  assign n129 = {n99, n97};
  /*# scc_wave2.vhd:211:13 */
  assign n137 = n26 ? n106 : n112;
  /*# scc_wave2.vhd:211:13 */
  assign n138 = n26 ? n107 : n114;
  /*# scc_wave2.vhd:211:13 */
  assign n139 = n26 ? n108 : n116;
  /*# scc_wave2.vhd:211:13 */
  assign n140 = n26 ? n109 : n118;
  /*# scc_wave2.vhd:211:13 */
  assign n141 = n26 ? n110 : n120;
  /*# scc_wave2.vhd:241:27 */
  assign n142 = wrt & req;
  /*# scc_wave2.vhd:241:48 */
  assign n143 = adr[7:5]; // extract
  /*# scc_wave2.vhd:241:61 */
  assign n145 = n143 == 3'b110;
  /*# scc_wave2.vhd:241:41 */
  assign n146 = n145 & n142;
  /*# scc_wave2.vhd:250:55 */
  assign n204 = ~ff_req_dl;
  /*# scc_wave2.vhd:250:41 */
  assign n205 = n204 & req;
  /*# scc_wave2.vhd:250:25 */
  assign n206 = n205 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:251:55 */
  assign n208 = ~ff_req_dl;
  /*# scc_wave2.vhd:251:41 */
  assign n209 = n208 & req;
  /*# scc_wave2.vhd:251:25 */
  assign n210 = n209 ? wrt : 1'b0;
  /*# scc_wave2.vhd:255:44 */
  assign n214 = reg_vol_ch_a != 4'b0000;
  /*# scc_wave2.vhd:255:24 */
  assign n215 = n214 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:256:42 */
  assign n219 = reg_ch_sel != 5'b00000;
  /*# scc_wave2.vhd:256:24 */
  assign n220 = n219 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:257:45 */
  assign n224 = reg_freq_ch_a != 12'b000000000000;
  /*# scc_wave2.vhd:257:24 */
  assign n225 = n224 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:263:31 */
  assign n227 = ff_ptr_ch_a[0]; // extract
  /*# scc_wave2.vhd:275:30 */
  assign n228 = ff_ch_num[0]; // extract
  /*# scc_wave2.vhd:276:39 */
  assign n231 = ff_mix != 15'b000000000000000;
  /*# scc_wave2.vhd:276:25 */
  assign n232 = n231 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:282:18 */
  always @*
    n234_ff_cnt_ch_a = n577; // (isignal)
  initial
    n234_ff_cnt_ch_a = 12'bX;
  /*# scc_wave2.vhd:283:18 */
  always @*
    n234_ff_cnt_ch_b = n579; // (isignal)
  initial
    n234_ff_cnt_ch_b = 12'bX;
  /*# scc_wave2.vhd:284:18 */
  always @*
    n234_ff_cnt_ch_c = n581; // (isignal)
  initial
    n234_ff_cnt_ch_c = 12'bX;
  /*# scc_wave2.vhd:285:18 */
  always @*
    n234_ff_cnt_ch_d = n583; // (isignal)
  initial
    n234_ff_cnt_ch_d = 12'bX;
  /*# scc_wave2.vhd:286:18 */
  always @*
    n234_ff_cnt_ch_e = n585; // (isignal)
  initial
    n234_ff_cnt_ch_e = 12'bX;
  /*# scc_wave2.vhd:303:34 */
  assign n242 = reg_freq_ch_a[11:3]; // extract
  /*# scc_wave2.vhd:303:48 */
  assign n244 = n242 == 9'b000000000;
  /*# scc_wave2.vhd:303:62 */
  assign n245 = n244 | ff_rst_ch_a;
  /*# scc_wave2.vhd:306:36 */
  assign n247 = n234_ff_cnt_ch_a == 12'b000000000000;
  /*# scc_wave2.vhd:307:48 */
  assign n249 = ff_ptr_ch_a + 5'b00001;
  /*# scc_wave2.vhd:310:48 */
  assign n251 = n234_ff_cnt_ch_a - 12'b000000000001;
  /*# scc_wave2.vhd:306:17 */
  assign n252 = n247 ? n249 : ff_ptr_ch_a;
  /*# scc_wave2.vhd:306:17 */
  assign n253 = n247 ? reg_freq_ch_a : n251;
  /*# scc_wave2.vhd:303:17 */
  assign n255 = n245 ? 5'b00000 : n252;
  /*# scc_wave2.vhd:303:17 */
  assign n256 = n245 ? reg_freq_ch_a : n253;
  /*# scc_wave2.vhd:313:34 */
  assign n257 = reg_freq_ch_b[11:3]; // extract
  /*# scc_wave2.vhd:313:48 */
  assign n259 = n257 == 9'b000000000;
  /*# scc_wave2.vhd:313:62 */
  assign n260 = n259 | ff_rst_ch_b;
  /*# scc_wave2.vhd:316:36 */
  assign n262 = n234_ff_cnt_ch_b == 12'b000000000000;
  /*# scc_wave2.vhd:317:48 */
  assign n264 = ff_ptr_ch_b + 5'b00001;
  /*# scc_wave2.vhd:320:48 */
  assign n266 = n234_ff_cnt_ch_b - 12'b000000000001;
  /*# scc_wave2.vhd:316:17 */
  assign n267 = n262 ? n264 : ff_ptr_ch_b;
  /*# scc_wave2.vhd:316:17 */
  assign n268 = n262 ? reg_freq_ch_b : n266;
  /*# scc_wave2.vhd:313:17 */
  assign n270 = n260 ? 5'b00000 : n267;
  /*# scc_wave2.vhd:313:17 */
  assign n271 = n260 ? reg_freq_ch_b : n268;
  /*# scc_wave2.vhd:323:34 */
  assign n272 = reg_freq_ch_c[11:3]; // extract
  /*# scc_wave2.vhd:323:48 */
  assign n274 = n272 == 9'b000000000;
  /*# scc_wave2.vhd:323:62 */
  assign n275 = n274 | ff_rst_ch_c;
  /*# scc_wave2.vhd:326:36 */
  assign n277 = n234_ff_cnt_ch_c == 12'b000000000000;
  /*# scc_wave2.vhd:327:48 */
  assign n279 = ff_ptr_ch_c + 5'b00001;
  /*# scc_wave2.vhd:330:48 */
  assign n281 = n234_ff_cnt_ch_c - 12'b000000000001;
  /*# scc_wave2.vhd:326:17 */
  assign n282 = n277 ? n279 : ff_ptr_ch_c;
  /*# scc_wave2.vhd:326:17 */
  assign n283 = n277 ? reg_freq_ch_c : n281;
  /*# scc_wave2.vhd:323:17 */
  assign n285 = n275 ? 5'b00000 : n282;
  /*# scc_wave2.vhd:323:17 */
  assign n286 = n275 ? reg_freq_ch_c : n283;
  /*# scc_wave2.vhd:333:34 */
  assign n287 = reg_freq_ch_d[11:3]; // extract
  /*# scc_wave2.vhd:333:48 */
  assign n289 = n287 == 9'b000000000;
  /*# scc_wave2.vhd:333:62 */
  assign n290 = n289 | ff_rst_ch_d;
  /*# scc_wave2.vhd:336:36 */
  assign n292 = n234_ff_cnt_ch_d == 12'b000000000000;
  /*# scc_wave2.vhd:337:48 */
  assign n294 = ff_ptr_ch_d + 5'b00001;
  /*# scc_wave2.vhd:340:48 */
  assign n296 = n234_ff_cnt_ch_d - 12'b000000000001;
  /*# scc_wave2.vhd:336:17 */
  assign n297 = n292 ? n294 : ff_ptr_ch_d;
  /*# scc_wave2.vhd:336:17 */
  assign n298 = n292 ? reg_freq_ch_d : n296;
  /*# scc_wave2.vhd:333:17 */
  assign n300 = n290 ? 5'b00000 : n297;
  /*# scc_wave2.vhd:333:17 */
  assign n301 = n290 ? reg_freq_ch_d : n298;
  /*# scc_wave2.vhd:343:34 */
  assign n302 = reg_freq_ch_e[11:3]; // extract
  /*# scc_wave2.vhd:343:48 */
  assign n304 = n302 == 9'b000000000;
  /*# scc_wave2.vhd:343:62 */
  assign n305 = n304 | ff_rst_ch_e;
  /*# scc_wave2.vhd:346:36 */
  assign n307 = n234_ff_cnt_ch_e == 12'b000000000000;
  /*# scc_wave2.vhd:347:48 */
  assign n309 = ff_ptr_ch_e + 5'b00001;
  /*# scc_wave2.vhd:350:48 */
  assign n311 = n234_ff_cnt_ch_e - 12'b000000000001;
  /*# scc_wave2.vhd:346:17 */
  assign n312 = n307 ? n309 : ff_ptr_ch_e;
  /*# scc_wave2.vhd:346:17 */
  assign n313 = n307 ? reg_freq_ch_e : n311;
  /*# scc_wave2.vhd:343:17 */
  assign n315 = n305 ? 5'b00000 : n312;
  /*# scc_wave2.vhd:343:17 */
  assign n316 = n305 ? reg_freq_ch_e : n313;
  /*# scc_wave2.vhd:360:41 */
  assign n358 = w_wave_ce ? adr : n363;
  /*# scc_wave2.vhd:361:24 */
  assign n360 = {3'b000, ff_ptr_ch_a};
  /*# scc_wave2.vhd:361:57 */
  assign n362 = ff_ch_num == 3'b000;
  /*# scc_wave2.vhd:360:66 */
  assign n363 = n362 ? n360 : n368;
  /*# scc_wave2.vhd:362:24 */
  assign n365 = {3'b001, ff_ptr_ch_b};
  /*# scc_wave2.vhd:362:57 */
  assign n367 = ff_ch_num == 3'b001;
  /*# scc_wave2.vhd:361:66 */
  assign n368 = n367 ? n365 : n373;
  /*# scc_wave2.vhd:363:24 */
  assign n370 = {3'b010, ff_ptr_ch_c};
  /*# scc_wave2.vhd:363:57 */
  assign n372 = ff_ch_num == 3'b010;
  /*# scc_wave2.vhd:362:66 */
  assign n373 = n372 ? n370 : n378;
  /*# scc_wave2.vhd:364:24 */
  assign n375 = {3'b011, ff_ptr_ch_d};
  /*# scc_wave2.vhd:364:57 */
  assign n377 = ff_ch_num == 3'b011;
  /*# scc_wave2.vhd:363:66 */
  assign n378 = n377 ? n375 : n381;
  /*# scc_wave2.vhd:365:24 */
  assign n380 = {3'b100, ff_ptr_ch_e};
  /*# scc_wave2.vhd:364:66 */
  assign n381 = sccplus ? n380 : n383;
  /*# scc_wave2.vhd:366:24 */
  assign n383 = {3'b011, ff_ptr_ch_e};
  /*# scc_wave2.vhd:368:5 */
  ram_Brtl wavemem (
    .adr(w_wave_adr),
    .clk(clk21m),
    .we(w_wave_we),
    .dbo(dbo),
    .dbi(wavemem_n384));
  /*# scc_wave2.vhd:412:17 */
  assign n413 = ff_ch_num_dl == 3'b001;
  /*# scc_wave2.vhd:413:17 */
  assign n416 = ff_ch_num_dl == 3'b010;
  /*# scc_wave2.vhd:414:17 */
  assign n419 = ff_ch_num_dl == 3'b011;
  /*# scc_wave2.vhd:415:17 */
  assign n422 = ff_ch_num_dl == 3'b100;
  /*# scc_wave2.vhd:416:17 */
  assign n425 = ff_ch_num_dl == 3'b101;
  /*# scc_wave2.vhd:411:5 */
  assign n427 = {n425, n422, n419, n416, n413};
  /*# scc_wave2.vhd:411:5 */
  always @*
    case (n427)
      5'b10000: n428 = 5'b10000;
      5'b01000: n428 = 5'b01000;
      5'b00100: n428 = 5'b00100;
      5'b00010: n428 = 5'b00010;
      5'b00001: n428 = 5'b00001;
      default: n428 = 5'b00000;
    endcase
  /*# scc_wave2.vhd:419:30 */
  assign n429 = w_ch_dec[0]; // extract
  /*# scc_wave2.vhd:419:48 */
  assign n430 = reg_ch_sel[0]; // extract
  /*# scc_wave2.vhd:419:34 */
  assign n431 = n429 & n430;
  /*# scc_wave2.vhd:420:30 */
  assign n432 = w_ch_dec[1]; // extract
  /*# scc_wave2.vhd:420:48 */
  assign n433 = reg_ch_sel[1]; // extract
  /*# scc_wave2.vhd:420:34 */
  assign n434 = n432 & n433;
  /*# scc_wave2.vhd:419:53 */
  assign n435 = n431 | n434;
  /*# scc_wave2.vhd:421:30 */
  assign n436 = w_ch_dec[2]; // extract
  /*# scc_wave2.vhd:421:48 */
  assign n437 = reg_ch_sel[2]; // extract
  /*# scc_wave2.vhd:421:34 */
  assign n438 = n436 & n437;
  /*# scc_wave2.vhd:420:53 */
  assign n439 = n435 | n438;
  /*# scc_wave2.vhd:422:30 */
  assign n440 = w_ch_dec[3]; // extract
  /*# scc_wave2.vhd:422:48 */
  assign n441 = reg_ch_sel[3]; // extract
  /*# scc_wave2.vhd:422:34 */
  assign n442 = n440 & n441;
  /*# scc_wave2.vhd:421:53 */
  assign n443 = n439 | n442;
  /*# scc_wave2.vhd:423:30 */
  assign n444 = w_ch_dec[4]; // extract
  /*# scc_wave2.vhd:423:48 */
  assign n445 = reg_ch_sel[4]; // extract
  /*# scc_wave2.vhd:423:34 */
  assign n446 = n444 & n445;
  /*# scc_wave2.vhd:422:53 */
  assign n447 = n443 | n446;
  /*# scc_wave2.vhd:425:21 */
  assign n448 = {w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit};
  /*# scc_wave2.vhd:428:29 */
  assign n450 = ff_ch_num_dl == 3'b001;
  /*# scc_wave2.vhd:429:29 */
  assign n452 = ff_ch_num_dl == 3'b010;
  /*# scc_wave2.vhd:430:29 */
  assign n454 = ff_ch_num_dl == 3'b011;
  /*# scc_wave2.vhd:431:29 */
  assign n456 = ff_ch_num_dl == 3'b100;
  /*# scc_wave2.vhd:432:29 */
  assign n458 = ff_ch_num_dl == 3'b101;
  /*# scc_wave2.vhd:427:5 */
  assign n460 = {n458, n456, n454, n452, n450};
  /*# scc_wave2.vhd:427:5 */
  always @*
    case (n460)
      5'b10000: n461 = reg_vol_ch_e;
      5'b01000: n461 = reg_vol_ch_d;
      5'b00100: n461 = reg_vol_ch_c;
      5'b00010: n461 = reg_vol_ch_b;
      5'b00001: n461 = reg_vol_ch_a;
      default: n461 = 4'b0000;
    endcase
  /*# scc_wave2.vhd:435:28 */
  assign n462 = w_ch_mask & ff_wave_dat;
  /*# scc_wave2.vhd:445:48 */
  assign n464 = {1'b0, w_ch_vol};
  /*# scc_wave2.vhd:445:35 */
  assign n465 = {{5{w_wave[7]}}, w_wave}; // sext
  /*# scc_wave2.vhd:445:35 */
  assign n466 = {{8{n464[4]}}, n464}; // sext
  /*# scc_wave2.vhd:445:35 */
  assign n467 = $signed(n465) * $signed(n466); // smul
  /*# scc_wave2.vhd:446:44 */
  assign n468 = w_mul_s[11:0]; // extract
  /*# scc_wave2.vhd:489:28 */
  assign n472 = ~ff_wave_ce;
  /*# scc_wave2.vhd:490:31 */
  assign n474 = ff_ch_num == 3'b101;
  /*# scc_wave2.vhd:493:44 */
  assign n476 = ff_ch_num + 3'b001;
  /*# scc_wave2.vhd:490:17 */
  assign n478 = n474 ? 3'b000 : n476;
  /*# scc_wave2.vhd:505:31 */
  assign n487 = ~ff_wave_ce_dl;
  /*# scc_wave2.vhd:506:34 */
  assign n489 = ff_ch_num_dl == 3'b000;
  /*# scc_wave2.vhd:509:39 */
  assign n490 = w_mul[11]; // extract
  /*# scc_wave2.vhd:509:51 */
  assign n491 = w_mul[11]; // extract
  /*# scc_wave2.vhd:509:44 */
  assign n492 = {n490, n491};
  /*# scc_wave2.vhd:509:63 */
  assign n493 = w_mul[11]; // extract
  /*# scc_wave2.vhd:509:56 */
  assign n494 = {n492, n493};
  /*# scc_wave2.vhd:509:68 */
  assign n495 = {n494, w_mul};
  /*# scc_wave2.vhd:509:77 */
  assign n496 = n495 + ff_mix;
  /*# scc_wave2.vhd:506:17 */
  assign n498 = n489 ? 15'b000000000000000 : n496;
  /*# scc_wave2.vhd:534:30 */
  assign n508 = ff_ch_num_dl == 3'b000;
  /*# scc_wave2.vhd:536:36 */
  assign n509 = ~ff_wavlatch_tgl;
  /*# scc_wave2.vhd:382:9 */
  assign n522 = ff_wave_ce ? ram_dbi : n523;
  /*# scc_wave2.vhd:382:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n523 <= 8'b11111111;
    else
      n523 <= n522;
  /*# scc_wave2.vhd:209:9 */
  assign n524 = n26 ? n121 : reg_freq_ch_a;
  /*# scc_wave2.vhd:209:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n525 <= 12'b000000000000;
    else
      n525 <= n524;
  /*# scc_wave2.vhd:209:9 */
  assign n526 = n26 ? n123 : reg_freq_ch_b;
  /*# scc_wave2.vhd:209:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n527 <= 12'b000000000000;
    else
      n527 <= n526;
  /*# scc_wave2.vhd:209:9 */
  assign n528 = n26 ? n125 : reg_freq_ch_c;
  /*# scc_wave2.vhd:209:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n529 <= 12'b000000000000;
    else
      n529 <= n528;
  /*# scc_wave2.vhd:209:9 */
  assign n530 = n26 ? n127 : reg_freq_ch_d;
  /*# scc_wave2.vhd:209:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n531 <= 12'b000000000000;
    else
      n531 <= n530;
  /*# scc_wave2.vhd:209:9 */
  assign n532 = n26 ? n129 : reg_freq_ch_e;
  /*# scc_wave2.vhd:209:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n533 <= 12'b000000000000;
    else
      n533 <= n532;
  /*# scc_wave2.vhd:209:9 */
  assign n534 = n26 ? n100 : reg_vol_ch_a;
  /*# scc_wave2.vhd:209:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n535 <= 4'b0000;
    else
      n535 <= n534;
  /*# scc_wave2.vhd:209:9 */
  assign n536 = n26 ? n101 : reg_vol_ch_b;
  /*# scc_wave2.vhd:209:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n537 <= 4'b0000;
    else
      n537 <= n536;
  /*# scc_wave2.vhd:209:9 */
  assign n538 = n26 ? n102 : reg_vol_ch_c;
  /*# scc_wave2.vhd:209:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n539 <= 4'b0000;
    else
      n539 <= n538;
  /*# scc_wave2.vhd:209:9 */
  assign n540 = n26 ? n103 : reg_vol_ch_d;
  /*# scc_wave2.vhd:209:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n541 <= 4'b0000;
    else
      n541 <= n540;
  /*# scc_wave2.vhd:209:9 */
  assign n542 = n26 ? n104 : reg_vol_ch_e;
  /*# scc_wave2.vhd:209:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n543 <= 4'b0000;
    else
      n543 <= n542;
  /*# scc_wave2.vhd:209:9 */
  assign n544 = n26 ? n105 : reg_ch_sel;
  /*# scc_wave2.vhd:209:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n545 <= 5'b00000;
    else
      n545 <= n544;
  /*# scc_wave2.vhd:209:9 */
  assign n546 = n146 ? dbo : reg_mode_sel;
  /*# scc_wave2.vhd:209:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n547 <= 8'b00000000;
    else
      n547 <= n546;
  /*# scc_wave2.vhd:209:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n548 <= 1'b0;
    else
      n548 <= n137;
  /*# scc_wave2.vhd:209:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n549 <= 1'b0;
    else
      n549 <= n138;
  /*# scc_wave2.vhd:209:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n550 <= 1'b0;
    else
      n550 <= n139;
  /*# scc_wave2.vhd:209:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n551 <= 1'b0;
    else
      n551 <= n140;
  /*# scc_wave2.vhd:209:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n552 <= 1'b0;
    else
      n552 <= n141;
  /*# scc_wave2.vhd:300:9 */
  assign n553 = clkena ? n255 : ff_ptr_ch_a;
  /*# scc_wave2.vhd:300:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n554 <= 5'b00000;
    else
      n554 <= n553;
  /*# scc_wave2.vhd:300:9 */
  assign n555 = clkena ? n270 : ff_ptr_ch_b;
  /*# scc_wave2.vhd:300:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n556 <= 5'b00000;
    else
      n556 <= n555;
  /*# scc_wave2.vhd:300:9 */
  assign n557 = clkena ? n285 : ff_ptr_ch_c;
  /*# scc_wave2.vhd:300:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n558 <= 5'b00000;
    else
      n558 <= n557;
  /*# scc_wave2.vhd:300:9 */
  assign n559 = clkena ? n300 : ff_ptr_ch_d;
  /*# scc_wave2.vhd:300:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n560 <= 5'b00000;
    else
      n560 <= n559;
  /*# scc_wave2.vhd:300:9 */
  assign n561 = clkena ? n315 : ff_ptr_ch_e;
  /*# scc_wave2.vhd:300:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n562 <= 5'b00000;
    else
      n562 <= n561;
  /*# scc_wave2.vhd:488:9 */
  assign n563 = n472 ? n478 : ff_ch_num;
  /*# scc_wave2.vhd:488:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n564 <= 3'b000;
    else
      n564 <= n563;
  /*# scc_wave2.vhd:400:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n565 <= 3'b000;
    else
      n565 <= ff_ch_num;
  /*# scc_wave2.vhd:504:9 */
  assign n566 = n487 ? n498 : ff_mix;
  /*# scc_wave2.vhd:504:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n567 <= 15'b000000000000000;
    else
      n567 <= n566;
  /*# scc_wave2.vhd:400:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n568 <= 1'b0;
    else
      n568 <= w_wave_ce;
  /*# scc_wave2.vhd:400:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n569 <= 1'b0;
    else
      n569 <= ff_wave_ce;
  /*# scc_wave2.vhd:209:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n570 <= 1'b0;
    else
      n570 <= req;
  /*# scc_wave2.vhd:400:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n571 <= 8'b00000000;
    else
      n571 <= ram_dbi;
  /*# scc_wave2.vhd:533:9 */
  assign n572 = n508 ? ff_mix : ff_wave;
  /*# scc_wave2.vhd:533:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n573 <= 15'b000000000000000;
    else
      n573 <= n572;
  /*# scc_wave2.vhd:533:9 */
  assign n574 = n508 ? n509 : ff_wavlatch_tgl;
  /*# scc_wave2.vhd:533:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n575 <= 1'b0;
    else
      n575 <= n574;
  /*# scc_wave2.vhd:300:9 */
  assign n576 = clkena ? n256 : n234_ff_cnt_ch_a;
  /*# scc_wave2.vhd:300:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n577 <= 12'b000000000000;
    else
      n577 <= n576;
  /*# scc_wave2.vhd:300:9 */
  assign n578 = clkena ? n271 : n234_ff_cnt_ch_b;
  /*# scc_wave2.vhd:300:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n579 <= 12'b000000000000;
    else
      n579 <= n578;
  /*# scc_wave2.vhd:300:9 */
  assign n580 = clkena ? n286 : n234_ff_cnt_ch_c;
  /*# scc_wave2.vhd:300:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n581 <= 12'b000000000000;
    else
      n581 <= n580;
  /*# scc_wave2.vhd:300:9 */
  assign n582 = clkena ? n301 : n234_ff_cnt_ch_d;
  /*# scc_wave2.vhd:300:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n583 <= 12'b000000000000;
    else
      n583 <= n582;
  /*# scc_wave2.vhd:300:9 */
  assign n584 = clkena ? n316 : n234_ff_cnt_ch_e;
  /*# scc_wave2.vhd:300:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n585 <= 12'b000000000000;
    else
      n585 <= n584;
endmodule

