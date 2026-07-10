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
//   fpga/src/ocm/scc_wave2.vhd            (md5 7965a69d1e9159e281408bb5d8373965)
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
//                   _53dbg: dbg_capnz   = '1' si la ULTIMA captura fue con
//                           ff_mix /= 0 (beeper sierra vivo ~97% = 31/32;
//                           "captura ceros" = 0% fijo)
//                           dbg_wave_nz = ff_wave (registro interno) /= 0
//                           (~97% con tono; separa "ff_wave==0" de "cono
//                           ff_wave->puerto wave roto")
//                   _54dbg: dbg_mix5_nz = ff_mix /= 0 muestreado en el slot
//                           dl=="101" (ultimo de acumulacion; ~97-100% con
//                           tono). mix5_nz ON + capnz OFF = el valor se
//                           desvanece entre dl==5 y la captura dl==0.
//
// ⚠ CAMBIOS DE RTL (no solo sondas):
//   _52: el proceso ff_wave captura SIN el guard ff_wave_ce_dl='0'.
//   _54 FIX "carga/hold" (sintoma _53dbg: el latch capturaba CEROS): ff_mix
//     ya NO se resetea en dl=="000" (HOLD); en dl=="001" CARGA el primer
//     producto (ch.A) y en dl=="010".."101" acumula. Suma IDENTICA, pero la
//     captura de ff_wave lee un valor estable >=1 ciclo — cero interaccion
//     captura/reset por construccion (mata la carrera que GW5A rompia).
//     El guard ce_dl del mixer se conserva. Ver comentarios en scc_wave2.vhd.
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
//     avance del puntero (N1), escaneo vivo (N2), acumulador activo (N3),
//     tasa de captura del latch final (N4), contenido de la captura +
//     registro de salida (N5) y suma en el ultimo slot de acumulacion (N6)
//     con las sondas dbg_ptr_lsb / dbg_scan_lsb / dbg_mix_nz / dbg_wavlatch /
//     dbg_capnz / dbg_wave_nz / dbg_mix5_nz calibradas.
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
  reg [7:0] n646;
  wire [7:0] n647; // mem_rd
  assign dbi = n647; //(module output)
  /*# ram.vhd:50:10 */
  assign iadr = n646; // (signal)
  /*# ram.vhd:56:5 */
  always @(posedge clk)
    n646 <= adr;
  reg [7:0] blkram[255:0] ; // memory
  assign n647 = blkram[iadr];
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
   output dbg_wavlatch,
   output dbg_capnz,
   output dbg_wave_nz,
   output dbg_mix5_nz);
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
  wire ff_capnz;
  wire ff_mix5_nz;
  wire n16;
  wire n17;
  wire n18;
  wire n19;
  wire [2:0] n20;
  wire n22;
  wire n23;
  wire [2:0] n24;
  wire n26;
  wire n27;
  wire n28;
  wire n29;
  wire [3:0] n30;
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
  wire n59;
  wire n61;
  wire [3:0] n62;
  wire n63;
  wire n65;
  wire [3:0] n66;
  wire n68;
  wire [3:0] n69;
  wire n71;
  wire [3:0] n72;
  wire n74;
  wire [3:0] n75;
  wire n77;
  wire [3:0] n78;
  wire n80;
  wire [4:0] n81;
  wire [14:0] n82;
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
  wire [7:0] n99;
  reg [7:0] n100;
  wire [3:0] n101;
  reg [3:0] n102;
  reg [3:0] n103;
  reg [3:0] n104;
  reg [3:0] n105;
  reg [3:0] n106;
  reg [3:0] n107;
  reg [4:0] n108;
  reg n109;
  reg n110;
  reg n111;
  reg n112;
  reg n113;
  wire n115;
  wire n117;
  wire n119;
  wire n121;
  wire n123;
  wire [11:0] n124;
  wire [11:0] n126;
  wire [11:0] n128;
  wire [11:0] n130;
  wire [11:0] n132;
  wire n140;
  wire n141;
  wire n142;
  wire n143;
  wire n144;
  wire n145;
  wire [2:0] n146;
  wire n148;
  wire n149;
  wire n207;
  wire n208;
  wire n209;
  wire n211;
  wire n212;
  wire n213;
  wire n217;
  wire n218;
  wire n222;
  wire n223;
  wire n227;
  wire n228;
  wire n230;
  wire n231;
  wire n234;
  wire n235;
  reg [11:0] n237_ff_cnt_ch_a;
  reg [11:0] n237_ff_cnt_ch_b;
  reg [11:0] n237_ff_cnt_ch_c;
  reg [11:0] n237_ff_cnt_ch_d;
  reg [11:0] n237_ff_cnt_ch_e;
  wire [8:0] n245;
  wire n247;
  wire n248;
  wire n250;
  wire [4:0] n252;
  wire [11:0] n254;
  wire [4:0] n255;
  wire [11:0] n256;
  wire [4:0] n258;
  wire [11:0] n259;
  wire [8:0] n260;
  wire n262;
  wire n263;
  wire n265;
  wire [4:0] n267;
  wire [11:0] n269;
  wire [4:0] n270;
  wire [11:0] n271;
  wire [4:0] n273;
  wire [11:0] n274;
  wire [8:0] n275;
  wire n277;
  wire n278;
  wire n280;
  wire [4:0] n282;
  wire [11:0] n284;
  wire [4:0] n285;
  wire [11:0] n286;
  wire [4:0] n288;
  wire [11:0] n289;
  wire [8:0] n290;
  wire n292;
  wire n293;
  wire n295;
  wire [4:0] n297;
  wire [11:0] n299;
  wire [4:0] n300;
  wire [11:0] n301;
  wire [4:0] n303;
  wire [11:0] n304;
  wire [8:0] n305;
  wire n307;
  wire n308;
  wire n310;
  wire [4:0] n312;
  wire [11:0] n314;
  wire [4:0] n315;
  wire [11:0] n316;
  wire [4:0] n318;
  wire [11:0] n319;
  wire [7:0] n361;
  wire [7:0] n363;
  wire n365;
  wire [7:0] n366;
  wire [7:0] n368;
  wire n370;
  wire [7:0] n371;
  wire [7:0] n373;
  wire n375;
  wire [7:0] n376;
  wire [7:0] n378;
  wire n380;
  wire [7:0] n381;
  wire [7:0] n383;
  wire [7:0] n384;
  wire [7:0] n386;
  wire [7:0] wavemem_n387;
  wire n416;
  wire n419;
  wire n422;
  wire n425;
  wire n428;
  wire [4:0] n430;
  reg [4:0] n431;
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
  wire n448;
  wire n449;
  wire n450;
  wire [7:0] n451;
  wire n453;
  wire n455;
  wire n457;
  wire n459;
  wire n461;
  wire [4:0] n463;
  reg [3:0] n464;
  wire [7:0] n465;
  wire [4:0] n467;
  wire [12:0] n468;
  wire [12:0] n469;
  wire [12:0] n470;
  wire [11:0] n471;
  wire n475;
  wire n477;
  wire [2:0] n479;
  wire [2:0] n481;
  wire n490;
  wire n492;
  wire n493;
  wire n494;
  wire [1:0] n495;
  wire n496;
  wire [2:0] n497;
  wire [14:0] n498;
  wire n500;
  wire n501;
  wire n502;
  wire [1:0] n503;
  wire n504;
  wire [2:0] n505;
  wire [14:0] n506;
  wire [14:0] n507;
  wire [14:0] n508;
  wire [14:0] n509;
  wire n519;
  wire n521;
  wire n524;
  wire n534;
  wire n535;
  wire n537;
  wire n540;
  wire n556;
  wire n557;
  wire [7:0] n562;
  reg [7:0] n563;
  wire [11:0] n564;
  reg [11:0] n565;
  wire [11:0] n566;
  reg [11:0] n567;
  wire [11:0] n568;
  reg [11:0] n569;
  wire [11:0] n570;
  reg [11:0] n571;
  wire [11:0] n572;
  reg [11:0] n573;
  wire [3:0] n574;
  reg [3:0] n575;
  wire [3:0] n576;
  reg [3:0] n577;
  wire [3:0] n578;
  reg [3:0] n579;
  wire [3:0] n580;
  reg [3:0] n581;
  wire [3:0] n582;
  reg [3:0] n583;
  wire [4:0] n584;
  reg [4:0] n585;
  wire [7:0] n586;
  reg [7:0] n587;
  reg n588;
  reg n589;
  reg n590;
  reg n591;
  reg n592;
  wire [4:0] n593;
  reg [4:0] n594;
  wire [4:0] n595;
  reg [4:0] n596;
  wire [4:0] n597;
  reg [4:0] n598;
  wire [4:0] n599;
  reg [4:0] n600;
  wire [4:0] n601;
  reg [4:0] n602;
  wire [2:0] n603;
  reg [2:0] n604;
  reg [2:0] n605;
  wire [14:0] n606;
  reg [14:0] n607;
  reg n608;
  reg n609;
  reg n610;
  reg [7:0] n611;
  wire [14:0] n612;
  reg [14:0] n613;
  wire n614;
  reg n615;
  wire n616;
  reg n617;
  wire n618;
  reg n619;
  wire [11:0] n620;
  reg [11:0] n621;
  wire [11:0] n622;
  reg [11:0] n623;
  wire [11:0] n624;
  reg [11:0] n625;
  wire [11:0] n626;
  reg [11:0] n627;
  wire [11:0] n628;
  reg [11:0] n629;
  assign ack = ff_req_dl; //(module output)
  assign dbi = n563; //(module output)
  assign wave = ff_wave; //(module output)
  assign dbg_vol_nz = n218; //(module output)
  assign dbg_sel_nz = n223; //(module output)
  assign dbg_freq_nz = n228; //(module output)
  assign dbg_ptr_lsb = n230; //(module output)
  assign dbg_scan_lsb = n231; //(module output)
  assign dbg_mix_nz = n235; //(module output)
  assign dbg_wavlatch = ff_wavlatch_tgl; //(module output)
  assign dbg_capnz = ff_capnz; //(module output)
  assign dbg_wave_nz = n557; //(module output)
  assign dbg_mix5_nz = ff_mix5_nz; //(module output)
  /*# scc_wave2.vhd:134:12 */
  assign w_wave_ce = n209; // (signal)
  /*# scc_wave2.vhd:135:12 */
  assign w_wave_we = n213; // (signal)
  /*# scc_wave2.vhd:136:12 */
  assign w_wave_adr = n361; // (signal)
  /*# scc_wave2.vhd:137:12 */
  assign w_ch_dec = n431; // (signal)
  /*# scc_wave2.vhd:138:12 */
  assign w_ch_bit = n450; // (signal)
  /*# scc_wave2.vhd:139:12 */
  assign w_ch_mask = n451; // (signal)
  /*# scc_wave2.vhd:140:12 */
  assign w_ch_vol = n464; // (signal)
  /*# scc_wave2.vhd:141:12 */
  assign w_wave = n465; // (signal)
  /*# scc_wave2.vhd:142:12 */
  assign w_mul = n471; // (signal)
  /*# scc_wave2.vhd:143:12 */
  assign w_mul_s = n470; // (signal)
  /*# scc_wave2.vhd:144:12 */
  assign ram_dbi = wavemem_n387; // (signal)
  /*# scc_wave2.vhd:150:12 */
  assign reg_freq_ch_a = n565; // (signal)
  /*# scc_wave2.vhd:151:12 */
  assign reg_freq_ch_b = n567; // (signal)
  /*# scc_wave2.vhd:152:12 */
  assign reg_freq_ch_c = n569; // (signal)
  /*# scc_wave2.vhd:153:12 */
  assign reg_freq_ch_d = n571; // (signal)
  /*# scc_wave2.vhd:154:12 */
  assign reg_freq_ch_e = n573; // (signal)
  /*# scc_wave2.vhd:155:12 */
  assign reg_vol_ch_a = n575; // (signal)
  /*# scc_wave2.vhd:156:12 */
  assign reg_vol_ch_b = n577; // (signal)
  /*# scc_wave2.vhd:157:12 */
  assign reg_vol_ch_c = n579; // (signal)
  /*# scc_wave2.vhd:158:12 */
  assign reg_vol_ch_d = n581; // (signal)
  /*# scc_wave2.vhd:159:12 */
  assign reg_vol_ch_e = n583; // (signal)
  /*# scc_wave2.vhd:160:12 */
  assign reg_ch_sel = n585; // (signal)
  /*# scc_wave2.vhd:161:12 */
  assign reg_mode_sel = n587; // (signal)
  /*# scc_wave2.vhd:164:12 */
  assign ff_rst_ch_a = n588; // (signal)
  /*# scc_wave2.vhd:165:12 */
  assign ff_rst_ch_b = n589; // (signal)
  /*# scc_wave2.vhd:166:12 */
  assign ff_rst_ch_c = n590; // (signal)
  /*# scc_wave2.vhd:167:12 */
  assign ff_rst_ch_d = n591; // (signal)
  /*# scc_wave2.vhd:168:12 */
  assign ff_rst_ch_e = n592; // (signal)
  /*# scc_wave2.vhd:169:12 */
  assign ff_ptr_ch_a = n594; // (signal)
  /*# scc_wave2.vhd:170:12 */
  assign ff_ptr_ch_b = n596; // (signal)
  /*# scc_wave2.vhd:171:12 */
  assign ff_ptr_ch_c = n598; // (signal)
  /*# scc_wave2.vhd:172:12 */
  assign ff_ptr_ch_d = n600; // (signal)
  /*# scc_wave2.vhd:173:12 */
  assign ff_ptr_ch_e = n602; // (signal)
  /*# scc_wave2.vhd:174:12 */
  assign ff_ch_num = n604; // (signal)
  /*# scc_wave2.vhd:175:12 */
  assign ff_ch_num_dl = n605; // (signal)
  /*# scc_wave2.vhd:176:12 */
  assign ff_mix = n607; // (signal)
  /*# scc_wave2.vhd:177:12 */
  assign ff_wave_ce = n608; // (signal)
  /*# scc_wave2.vhd:178:12 */
  assign ff_wave_ce_dl = n609; // (signal)
  /*# scc_wave2.vhd:179:12 */
  assign ff_req_dl = n610; // (signal)
  /*# scc_wave2.vhd:180:12 */
  assign ff_wave_dat = n611; // (signal)
  /*# scc_wave2.vhd:181:12 */
  assign ff_wave = n613; // (signal)
  /*# scc_wave2.vhd:182:12 */
  assign ff_wavlatch_tgl = n615; // (signal)
  /*# scc_wave2.vhd:183:12 */
  assign ff_capnz = n617; // (signal)
  /*# scc_wave2.vhd:184:12 */
  assign ff_mix5_nz = n619; // (signal)
  /*# scc_wave2.vhd:218:41 */
  assign n16 = ~ff_req_dl;
  /*# scc_wave2.vhd:218:27 */
  assign n17 = n16 & req;
  /*# scc_wave2.vhd:218:47 */
  assign n18 = wrt & n17;
  /*# scc_wave2.vhd:219:27 */
  assign n19 = ~sccplus;
  /*# scc_wave2.vhd:219:40 */
  assign n20 = adr[7:5]; // extract
  /*# scc_wave2.vhd:219:53 */
  assign n22 = n20 == 3'b100;
  /*# scc_wave2.vhd:219:33 */
  assign n23 = n22 & n19;
  /*# scc_wave2.vhd:220:40 */
  assign n24 = adr[7:5]; // extract
  /*# scc_wave2.vhd:220:53 */
  assign n26 = n24 == 3'b101;
  /*# scc_wave2.vhd:220:33 */
  assign n27 = n26 & sccplus;
  /*# scc_wave2.vhd:219:62 */
  assign n28 = n23 | n27;
  /*# scc_wave2.vhd:218:61 */
  assign n29 = n28 & n18;
  /*# scc_wave2.vhd:221:25 */
  assign n30 = adr[3:0]; // extract
  /*# scc_wave2.vhd:222:114 */
  assign n31 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:222:21 */
  assign n33 = n30 == 4'b0000;
  /*# scc_wave2.vhd:223:71 */
  assign n34 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:223:114 */
  assign n35 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:223:21 */
  assign n37 = n30 == 4'b0001;
  /*# scc_wave2.vhd:224:114 */
  assign n38 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:224:21 */
  assign n40 = n30 == 4'b0010;
  /*# scc_wave2.vhd:225:71 */
  assign n41 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:225:114 */
  assign n42 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:225:21 */
  assign n44 = n30 == 4'b0011;
  /*# scc_wave2.vhd:226:114 */
  assign n45 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:226:21 */
  assign n47 = n30 == 4'b0100;
  /*# scc_wave2.vhd:227:71 */
  assign n48 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:227:114 */
  assign n49 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:227:21 */
  assign n51 = n30 == 4'b0101;
  /*# scc_wave2.vhd:228:114 */
  assign n52 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:228:21 */
  assign n54 = n30 == 4'b0110;
  /*# scc_wave2.vhd:229:71 */
  assign n55 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:229:114 */
  assign n56 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:229:21 */
  assign n58 = n30 == 4'b0111;
  /*# scc_wave2.vhd:230:114 */
  assign n59 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:230:21 */
  assign n61 = n30 == 4'b1000;
  /*# scc_wave2.vhd:231:71 */
  assign n62 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:231:114 */
  assign n63 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:231:21 */
  assign n65 = n30 == 4'b1001;
  /*# scc_wave2.vhd:232:71 */
  assign n66 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:232:21 */
  assign n68 = n30 == 4'b1010;
  /*# scc_wave2.vhd:233:71 */
  assign n69 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:233:21 */
  assign n71 = n30 == 4'b1011;
  /*# scc_wave2.vhd:234:71 */
  assign n72 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:234:21 */
  assign n74 = n30 == 4'b1100;
  /*# scc_wave2.vhd:235:71 */
  assign n75 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:235:21 */
  assign n77 = n30 == 4'b1101;
  /*# scc_wave2.vhd:236:71 */
  assign n78 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:236:21 */
  assign n80 = n30 == 4'b1110;
  /*# scc_wave2.vhd:237:71 */
  assign n81 = dbo[4:0]; // extract
  /*# scc_wave2.vhd:221:17 */
  assign n82 = {n80, n77, n74, n71, n68, n65, n61, n58, n54, n51, n47, n44, n40, n37, n33};
  /*# scc_wave2.vhd:150:12 */
  assign n83 = reg_freq_ch_a[7:0]; // extract
  /*# scc_wave2.vhd:221:17 */
  always @*
    case (n82)
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
      15'b000000000000100: n84 = n83;
      15'b000000000000010: n84 = n83;
      15'b000000000000001: n84 = dbo;
      default: n84 = n83;
    endcase
  /*# scc_wave2.vhd:150:12 */
  assign n85 = reg_freq_ch_a[11:8]; // extract
  /*# scc_wave2.vhd:221:17 */
  always @*
    case (n82)
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
      15'b000000000001000: n86 = n85;
      15'b000000000000100: n86 = n85;
      15'b000000000000010: n86 = n34;
      15'b000000000000001: n86 = n85;
      default: n86 = n85;
    endcase
  /*# scc_wave2.vhd:151:12 */
  assign n87 = reg_freq_ch_b[7:0]; // extract
  /*# scc_wave2.vhd:221:17 */
  always @*
    case (n82)
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
      15'b000000000010000: n88 = n87;
      15'b000000000001000: n88 = n87;
      15'b000000000000100: n88 = dbo;
      15'b000000000000010: n88 = n87;
      15'b000000000000001: n88 = n87;
      default: n88 = n87;
    endcase
  /*# scc_wave2.vhd:151:12 */
  assign n89 = reg_freq_ch_b[11:8]; // extract
  /*# scc_wave2.vhd:221:17 */
  always @*
    case (n82)
      15'b100000000000000: n90 = n89;
      15'b010000000000000: n90 = n89;
      15'b001000000000000: n90 = n89;
      15'b000100000000000: n90 = n89;
      15'b000010000000000: n90 = n89;
      15'b000001000000000: n90 = n89;
      15'b000000100000000: n90 = n89;
      15'b000000010000000: n90 = n89;
      15'b000000001000000: n90 = n89;
      15'b000000000100000: n90 = n89;
      15'b000000000010000: n90 = n89;
      15'b000000000001000: n90 = n41;
      15'b000000000000100: n90 = n89;
      15'b000000000000010: n90 = n89;
      15'b000000000000001: n90 = n89;
      default: n90 = n89;
    endcase
  /*# scc_wave2.vhd:152:12 */
  assign n91 = reg_freq_ch_c[7:0]; // extract
  /*# scc_wave2.vhd:221:17 */
  always @*
    case (n82)
      15'b100000000000000: n92 = n91;
      15'b010000000000000: n92 = n91;
      15'b001000000000000: n92 = n91;
      15'b000100000000000: n92 = n91;
      15'b000010000000000: n92 = n91;
      15'b000001000000000: n92 = n91;
      15'b000000100000000: n92 = n91;
      15'b000000010000000: n92 = n91;
      15'b000000001000000: n92 = n91;
      15'b000000000100000: n92 = n91;
      15'b000000000010000: n92 = dbo;
      15'b000000000001000: n92 = n91;
      15'b000000000000100: n92 = n91;
      15'b000000000000010: n92 = n91;
      15'b000000000000001: n92 = n91;
      default: n92 = n91;
    endcase
  /*# scc_wave2.vhd:152:12 */
  assign n93 = reg_freq_ch_c[11:8]; // extract
  /*# scc_wave2.vhd:221:17 */
  always @*
    case (n82)
      15'b100000000000000: n94 = n93;
      15'b010000000000000: n94 = n93;
      15'b001000000000000: n94 = n93;
      15'b000100000000000: n94 = n93;
      15'b000010000000000: n94 = n93;
      15'b000001000000000: n94 = n93;
      15'b000000100000000: n94 = n93;
      15'b000000010000000: n94 = n93;
      15'b000000001000000: n94 = n93;
      15'b000000000100000: n94 = n48;
      15'b000000000010000: n94 = n93;
      15'b000000000001000: n94 = n93;
      15'b000000000000100: n94 = n93;
      15'b000000000000010: n94 = n93;
      15'b000000000000001: n94 = n93;
      default: n94 = n93;
    endcase
  /*# scc_wave2.vhd:153:12 */
  assign n95 = reg_freq_ch_d[7:0]; // extract
  /*# scc_wave2.vhd:221:17 */
  always @*
    case (n82)
      15'b100000000000000: n96 = n95;
      15'b010000000000000: n96 = n95;
      15'b001000000000000: n96 = n95;
      15'b000100000000000: n96 = n95;
      15'b000010000000000: n96 = n95;
      15'b000001000000000: n96 = n95;
      15'b000000100000000: n96 = n95;
      15'b000000010000000: n96 = n95;
      15'b000000001000000: n96 = dbo;
      15'b000000000100000: n96 = n95;
      15'b000000000010000: n96 = n95;
      15'b000000000001000: n96 = n95;
      15'b000000000000100: n96 = n95;
      15'b000000000000010: n96 = n95;
      15'b000000000000001: n96 = n95;
      default: n96 = n95;
    endcase
  /*# scc_wave2.vhd:153:12 */
  assign n97 = reg_freq_ch_d[11:8]; // extract
  /*# scc_wave2.vhd:221:17 */
  always @*
    case (n82)
      15'b100000000000000: n98 = n97;
      15'b010000000000000: n98 = n97;
      15'b001000000000000: n98 = n97;
      15'b000100000000000: n98 = n97;
      15'b000010000000000: n98 = n97;
      15'b000001000000000: n98 = n97;
      15'b000000100000000: n98 = n97;
      15'b000000010000000: n98 = n55;
      15'b000000001000000: n98 = n97;
      15'b000000000100000: n98 = n97;
      15'b000000000010000: n98 = n97;
      15'b000000000001000: n98 = n97;
      15'b000000000000100: n98 = n97;
      15'b000000000000010: n98 = n97;
      15'b000000000000001: n98 = n97;
      default: n98 = n97;
    endcase
  /*# scc_wave2.vhd:154:12 */
  assign n99 = reg_freq_ch_e[7:0]; // extract
  /*# scc_wave2.vhd:221:17 */
  always @*
    case (n82)
      15'b100000000000000: n100 = n99;
      15'b010000000000000: n100 = n99;
      15'b001000000000000: n100 = n99;
      15'b000100000000000: n100 = n99;
      15'b000010000000000: n100 = n99;
      15'b000001000000000: n100 = n99;
      15'b000000100000000: n100 = dbo;
      15'b000000010000000: n100 = n99;
      15'b000000001000000: n100 = n99;
      15'b000000000100000: n100 = n99;
      15'b000000000010000: n100 = n99;
      15'b000000000001000: n100 = n99;
      15'b000000000000100: n100 = n99;
      15'b000000000000010: n100 = n99;
      15'b000000000000001: n100 = n99;
      default: n100 = n99;
    endcase
  /*# scc_wave2.vhd:154:12 */
  assign n101 = reg_freq_ch_e[11:8]; // extract
  /*# scc_wave2.vhd:221:17 */
  always @*
    case (n82)
      15'b100000000000000: n102 = n101;
      15'b010000000000000: n102 = n101;
      15'b001000000000000: n102 = n101;
      15'b000100000000000: n102 = n101;
      15'b000010000000000: n102 = n101;
      15'b000001000000000: n102 = n62;
      15'b000000100000000: n102 = n101;
      15'b000000010000000: n102 = n101;
      15'b000000001000000: n102 = n101;
      15'b000000000100000: n102 = n101;
      15'b000000000010000: n102 = n101;
      15'b000000000001000: n102 = n101;
      15'b000000000000100: n102 = n101;
      15'b000000000000010: n102 = n101;
      15'b000000000000001: n102 = n101;
      default: n102 = n101;
    endcase
  /*# scc_wave2.vhd:221:17 */
  always @*
    case (n82)
      15'b100000000000000: n103 = reg_vol_ch_a;
      15'b010000000000000: n103 = reg_vol_ch_a;
      15'b001000000000000: n103 = reg_vol_ch_a;
      15'b000100000000000: n103 = reg_vol_ch_a;
      15'b000010000000000: n103 = n66;
      15'b000001000000000: n103 = reg_vol_ch_a;
      15'b000000100000000: n103 = reg_vol_ch_a;
      15'b000000010000000: n103 = reg_vol_ch_a;
      15'b000000001000000: n103 = reg_vol_ch_a;
      15'b000000000100000: n103 = reg_vol_ch_a;
      15'b000000000010000: n103 = reg_vol_ch_a;
      15'b000000000001000: n103 = reg_vol_ch_a;
      15'b000000000000100: n103 = reg_vol_ch_a;
      15'b000000000000010: n103 = reg_vol_ch_a;
      15'b000000000000001: n103 = reg_vol_ch_a;
      default: n103 = reg_vol_ch_a;
    endcase
  /*# scc_wave2.vhd:221:17 */
  always @*
    case (n82)
      15'b100000000000000: n104 = reg_vol_ch_b;
      15'b010000000000000: n104 = reg_vol_ch_b;
      15'b001000000000000: n104 = reg_vol_ch_b;
      15'b000100000000000: n104 = n69;
      15'b000010000000000: n104 = reg_vol_ch_b;
      15'b000001000000000: n104 = reg_vol_ch_b;
      15'b000000100000000: n104 = reg_vol_ch_b;
      15'b000000010000000: n104 = reg_vol_ch_b;
      15'b000000001000000: n104 = reg_vol_ch_b;
      15'b000000000100000: n104 = reg_vol_ch_b;
      15'b000000000010000: n104 = reg_vol_ch_b;
      15'b000000000001000: n104 = reg_vol_ch_b;
      15'b000000000000100: n104 = reg_vol_ch_b;
      15'b000000000000010: n104 = reg_vol_ch_b;
      15'b000000000000001: n104 = reg_vol_ch_b;
      default: n104 = reg_vol_ch_b;
    endcase
  /*# scc_wave2.vhd:221:17 */
  always @*
    case (n82)
      15'b100000000000000: n105 = reg_vol_ch_c;
      15'b010000000000000: n105 = reg_vol_ch_c;
      15'b001000000000000: n105 = n72;
      15'b000100000000000: n105 = reg_vol_ch_c;
      15'b000010000000000: n105 = reg_vol_ch_c;
      15'b000001000000000: n105 = reg_vol_ch_c;
      15'b000000100000000: n105 = reg_vol_ch_c;
      15'b000000010000000: n105 = reg_vol_ch_c;
      15'b000000001000000: n105 = reg_vol_ch_c;
      15'b000000000100000: n105 = reg_vol_ch_c;
      15'b000000000010000: n105 = reg_vol_ch_c;
      15'b000000000001000: n105 = reg_vol_ch_c;
      15'b000000000000100: n105 = reg_vol_ch_c;
      15'b000000000000010: n105 = reg_vol_ch_c;
      15'b000000000000001: n105 = reg_vol_ch_c;
      default: n105 = reg_vol_ch_c;
    endcase
  /*# scc_wave2.vhd:221:17 */
  always @*
    case (n82)
      15'b100000000000000: n106 = reg_vol_ch_d;
      15'b010000000000000: n106 = n75;
      15'b001000000000000: n106 = reg_vol_ch_d;
      15'b000100000000000: n106 = reg_vol_ch_d;
      15'b000010000000000: n106 = reg_vol_ch_d;
      15'b000001000000000: n106 = reg_vol_ch_d;
      15'b000000100000000: n106 = reg_vol_ch_d;
      15'b000000010000000: n106 = reg_vol_ch_d;
      15'b000000001000000: n106 = reg_vol_ch_d;
      15'b000000000100000: n106 = reg_vol_ch_d;
      15'b000000000010000: n106 = reg_vol_ch_d;
      15'b000000000001000: n106 = reg_vol_ch_d;
      15'b000000000000100: n106 = reg_vol_ch_d;
      15'b000000000000010: n106 = reg_vol_ch_d;
      15'b000000000000001: n106 = reg_vol_ch_d;
      default: n106 = reg_vol_ch_d;
    endcase
  /*# scc_wave2.vhd:221:17 */
  always @*
    case (n82)
      15'b100000000000000: n107 = n78;
      15'b010000000000000: n107 = reg_vol_ch_e;
      15'b001000000000000: n107 = reg_vol_ch_e;
      15'b000100000000000: n107 = reg_vol_ch_e;
      15'b000010000000000: n107 = reg_vol_ch_e;
      15'b000001000000000: n107 = reg_vol_ch_e;
      15'b000000100000000: n107 = reg_vol_ch_e;
      15'b000000010000000: n107 = reg_vol_ch_e;
      15'b000000001000000: n107 = reg_vol_ch_e;
      15'b000000000100000: n107 = reg_vol_ch_e;
      15'b000000000010000: n107 = reg_vol_ch_e;
      15'b000000000001000: n107 = reg_vol_ch_e;
      15'b000000000000100: n107 = reg_vol_ch_e;
      15'b000000000000010: n107 = reg_vol_ch_e;
      15'b000000000000001: n107 = reg_vol_ch_e;
      default: n107 = reg_vol_ch_e;
    endcase
  /*# scc_wave2.vhd:221:17 */
  always @*
    case (n82)
      15'b100000000000000: n108 = reg_ch_sel;
      15'b010000000000000: n108 = reg_ch_sel;
      15'b001000000000000: n108 = reg_ch_sel;
      15'b000100000000000: n108 = reg_ch_sel;
      15'b000010000000000: n108 = reg_ch_sel;
      15'b000001000000000: n108 = reg_ch_sel;
      15'b000000100000000: n108 = reg_ch_sel;
      15'b000000010000000: n108 = reg_ch_sel;
      15'b000000001000000: n108 = reg_ch_sel;
      15'b000000000100000: n108 = reg_ch_sel;
      15'b000000000010000: n108 = reg_ch_sel;
      15'b000000000001000: n108 = reg_ch_sel;
      15'b000000000000100: n108 = reg_ch_sel;
      15'b000000000000010: n108 = reg_ch_sel;
      15'b000000000000001: n108 = reg_ch_sel;
      default: n108 = n81;
    endcase
  /*# scc_wave2.vhd:221:17 */
  always @*
    case (n82)
      15'b100000000000000: n109 = ff_rst_ch_a;
      15'b010000000000000: n109 = ff_rst_ch_a;
      15'b001000000000000: n109 = ff_rst_ch_a;
      15'b000100000000000: n109 = ff_rst_ch_a;
      15'b000010000000000: n109 = ff_rst_ch_a;
      15'b000001000000000: n109 = ff_rst_ch_a;
      15'b000000100000000: n109 = ff_rst_ch_a;
      15'b000000010000000: n109 = ff_rst_ch_a;
      15'b000000001000000: n109 = ff_rst_ch_a;
      15'b000000000100000: n109 = ff_rst_ch_a;
      15'b000000000010000: n109 = ff_rst_ch_a;
      15'b000000000001000: n109 = ff_rst_ch_a;
      15'b000000000000100: n109 = ff_rst_ch_a;
      15'b000000000000010: n109 = n35;
      15'b000000000000001: n109 = n31;
      default: n109 = ff_rst_ch_a;
    endcase
  /*# scc_wave2.vhd:221:17 */
  always @*
    case (n82)
      15'b100000000000000: n110 = ff_rst_ch_b;
      15'b010000000000000: n110 = ff_rst_ch_b;
      15'b001000000000000: n110 = ff_rst_ch_b;
      15'b000100000000000: n110 = ff_rst_ch_b;
      15'b000010000000000: n110 = ff_rst_ch_b;
      15'b000001000000000: n110 = ff_rst_ch_b;
      15'b000000100000000: n110 = ff_rst_ch_b;
      15'b000000010000000: n110 = ff_rst_ch_b;
      15'b000000001000000: n110 = ff_rst_ch_b;
      15'b000000000100000: n110 = ff_rst_ch_b;
      15'b000000000010000: n110 = ff_rst_ch_b;
      15'b000000000001000: n110 = n42;
      15'b000000000000100: n110 = n38;
      15'b000000000000010: n110 = ff_rst_ch_b;
      15'b000000000000001: n110 = ff_rst_ch_b;
      default: n110 = ff_rst_ch_b;
    endcase
  /*# scc_wave2.vhd:221:17 */
  always @*
    case (n82)
      15'b100000000000000: n111 = ff_rst_ch_c;
      15'b010000000000000: n111 = ff_rst_ch_c;
      15'b001000000000000: n111 = ff_rst_ch_c;
      15'b000100000000000: n111 = ff_rst_ch_c;
      15'b000010000000000: n111 = ff_rst_ch_c;
      15'b000001000000000: n111 = ff_rst_ch_c;
      15'b000000100000000: n111 = ff_rst_ch_c;
      15'b000000010000000: n111 = ff_rst_ch_c;
      15'b000000001000000: n111 = ff_rst_ch_c;
      15'b000000000100000: n111 = n49;
      15'b000000000010000: n111 = n45;
      15'b000000000001000: n111 = ff_rst_ch_c;
      15'b000000000000100: n111 = ff_rst_ch_c;
      15'b000000000000010: n111 = ff_rst_ch_c;
      15'b000000000000001: n111 = ff_rst_ch_c;
      default: n111 = ff_rst_ch_c;
    endcase
  /*# scc_wave2.vhd:221:17 */
  always @*
    case (n82)
      15'b100000000000000: n112 = ff_rst_ch_d;
      15'b010000000000000: n112 = ff_rst_ch_d;
      15'b001000000000000: n112 = ff_rst_ch_d;
      15'b000100000000000: n112 = ff_rst_ch_d;
      15'b000010000000000: n112 = ff_rst_ch_d;
      15'b000001000000000: n112 = ff_rst_ch_d;
      15'b000000100000000: n112 = ff_rst_ch_d;
      15'b000000010000000: n112 = n56;
      15'b000000001000000: n112 = n52;
      15'b000000000100000: n112 = ff_rst_ch_d;
      15'b000000000010000: n112 = ff_rst_ch_d;
      15'b000000000001000: n112 = ff_rst_ch_d;
      15'b000000000000100: n112 = ff_rst_ch_d;
      15'b000000000000010: n112 = ff_rst_ch_d;
      15'b000000000000001: n112 = ff_rst_ch_d;
      default: n112 = ff_rst_ch_d;
    endcase
  /*# scc_wave2.vhd:221:17 */
  always @*
    case (n82)
      15'b100000000000000: n113 = ff_rst_ch_e;
      15'b010000000000000: n113 = ff_rst_ch_e;
      15'b001000000000000: n113 = ff_rst_ch_e;
      15'b000100000000000: n113 = ff_rst_ch_e;
      15'b000010000000000: n113 = ff_rst_ch_e;
      15'b000001000000000: n113 = n63;
      15'b000000100000000: n113 = n59;
      15'b000000010000000: n113 = ff_rst_ch_e;
      15'b000000001000000: n113 = ff_rst_ch_e;
      15'b000000000100000: n113 = ff_rst_ch_e;
      15'b000000000010000: n113 = ff_rst_ch_e;
      15'b000000000001000: n113 = ff_rst_ch_e;
      15'b000000000000100: n113 = ff_rst_ch_e;
      15'b000000000000010: n113 = ff_rst_ch_e;
      15'b000000000000001: n113 = ff_rst_ch_e;
      default: n113 = ff_rst_ch_e;
    endcase
  /*# scc_wave2.vhd:239:13 */
  assign n115 = clkena ? 1'b0 : ff_rst_ch_a;
  /*# scc_wave2.vhd:239:13 */
  assign n117 = clkena ? 1'b0 : ff_rst_ch_b;
  /*# scc_wave2.vhd:239:13 */
  assign n119 = clkena ? 1'b0 : ff_rst_ch_c;
  /*# scc_wave2.vhd:239:13 */
  assign n121 = clkena ? 1'b0 : ff_rst_ch_d;
  /*# scc_wave2.vhd:239:13 */
  assign n123 = clkena ? 1'b0 : ff_rst_ch_e;
  /*# scc_wave2.vhd:218:13 */
  assign n124 = {n86, n84};
  /*# scc_wave2.vhd:218:13 */
  assign n126 = {n90, n88};
  /*# scc_wave2.vhd:218:13 */
  assign n128 = {n94, n92};
  /*# scc_wave2.vhd:218:13 */
  assign n130 = {n98, n96};
  /*# scc_wave2.vhd:218:13 */
  assign n132 = {n102, n100};
  /*# scc_wave2.vhd:218:13 */
  assign n140 = n29 ? n109 : n115;
  /*# scc_wave2.vhd:218:13 */
  assign n141 = n29 ? n110 : n117;
  /*# scc_wave2.vhd:218:13 */
  assign n142 = n29 ? n111 : n119;
  /*# scc_wave2.vhd:218:13 */
  assign n143 = n29 ? n112 : n121;
  /*# scc_wave2.vhd:218:13 */
  assign n144 = n29 ? n113 : n123;
  /*# scc_wave2.vhd:248:27 */
  assign n145 = wrt & req;
  /*# scc_wave2.vhd:248:48 */
  assign n146 = adr[7:5]; // extract
  /*# scc_wave2.vhd:248:61 */
  assign n148 = n146 == 3'b110;
  /*# scc_wave2.vhd:248:41 */
  assign n149 = n148 & n145;
  /*# scc_wave2.vhd:257:55 */
  assign n207 = ~ff_req_dl;
  /*# scc_wave2.vhd:257:41 */
  assign n208 = n207 & req;
  /*# scc_wave2.vhd:257:25 */
  assign n209 = n208 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:258:55 */
  assign n211 = ~ff_req_dl;
  /*# scc_wave2.vhd:258:41 */
  assign n212 = n211 & req;
  /*# scc_wave2.vhd:258:25 */
  assign n213 = n212 ? wrt : 1'b0;
  /*# scc_wave2.vhd:262:44 */
  assign n217 = reg_vol_ch_a != 4'b0000;
  /*# scc_wave2.vhd:262:24 */
  assign n218 = n217 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:263:42 */
  assign n222 = reg_ch_sel != 5'b00000;
  /*# scc_wave2.vhd:263:24 */
  assign n223 = n222 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:264:45 */
  assign n227 = reg_freq_ch_a != 12'b000000000000;
  /*# scc_wave2.vhd:264:24 */
  assign n228 = n227 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:270:31 */
  assign n230 = ff_ptr_ch_a[0]; // extract
  /*# scc_wave2.vhd:282:30 */
  assign n231 = ff_ch_num[0]; // extract
  /*# scc_wave2.vhd:283:39 */
  assign n234 = ff_mix != 15'b000000000000000;
  /*# scc_wave2.vhd:283:25 */
  assign n235 = n234 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:289:18 */
  always @*
    n237_ff_cnt_ch_a = n621; // (isignal)
  initial
    n237_ff_cnt_ch_a = 12'bX;
  /*# scc_wave2.vhd:290:18 */
  always @*
    n237_ff_cnt_ch_b = n623; // (isignal)
  initial
    n237_ff_cnt_ch_b = 12'bX;
  /*# scc_wave2.vhd:291:18 */
  always @*
    n237_ff_cnt_ch_c = n625; // (isignal)
  initial
    n237_ff_cnt_ch_c = 12'bX;
  /*# scc_wave2.vhd:292:18 */
  always @*
    n237_ff_cnt_ch_d = n627; // (isignal)
  initial
    n237_ff_cnt_ch_d = 12'bX;
  /*# scc_wave2.vhd:293:18 */
  always @*
    n237_ff_cnt_ch_e = n629; // (isignal)
  initial
    n237_ff_cnt_ch_e = 12'bX;
  /*# scc_wave2.vhd:310:34 */
  assign n245 = reg_freq_ch_a[11:3]; // extract
  /*# scc_wave2.vhd:310:48 */
  assign n247 = n245 == 9'b000000000;
  /*# scc_wave2.vhd:310:62 */
  assign n248 = n247 | ff_rst_ch_a;
  /*# scc_wave2.vhd:313:36 */
  assign n250 = n237_ff_cnt_ch_a == 12'b000000000000;
  /*# scc_wave2.vhd:314:48 */
  assign n252 = ff_ptr_ch_a + 5'b00001;
  /*# scc_wave2.vhd:317:48 */
  assign n254 = n237_ff_cnt_ch_a - 12'b000000000001;
  /*# scc_wave2.vhd:313:17 */
  assign n255 = n250 ? n252 : ff_ptr_ch_a;
  /*# scc_wave2.vhd:313:17 */
  assign n256 = n250 ? reg_freq_ch_a : n254;
  /*# scc_wave2.vhd:310:17 */
  assign n258 = n248 ? 5'b00000 : n255;
  /*# scc_wave2.vhd:310:17 */
  assign n259 = n248 ? reg_freq_ch_a : n256;
  /*# scc_wave2.vhd:320:34 */
  assign n260 = reg_freq_ch_b[11:3]; // extract
  /*# scc_wave2.vhd:320:48 */
  assign n262 = n260 == 9'b000000000;
  /*# scc_wave2.vhd:320:62 */
  assign n263 = n262 | ff_rst_ch_b;
  /*# scc_wave2.vhd:323:36 */
  assign n265 = n237_ff_cnt_ch_b == 12'b000000000000;
  /*# scc_wave2.vhd:324:48 */
  assign n267 = ff_ptr_ch_b + 5'b00001;
  /*# scc_wave2.vhd:327:48 */
  assign n269 = n237_ff_cnt_ch_b - 12'b000000000001;
  /*# scc_wave2.vhd:323:17 */
  assign n270 = n265 ? n267 : ff_ptr_ch_b;
  /*# scc_wave2.vhd:323:17 */
  assign n271 = n265 ? reg_freq_ch_b : n269;
  /*# scc_wave2.vhd:320:17 */
  assign n273 = n263 ? 5'b00000 : n270;
  /*# scc_wave2.vhd:320:17 */
  assign n274 = n263 ? reg_freq_ch_b : n271;
  /*# scc_wave2.vhd:330:34 */
  assign n275 = reg_freq_ch_c[11:3]; // extract
  /*# scc_wave2.vhd:330:48 */
  assign n277 = n275 == 9'b000000000;
  /*# scc_wave2.vhd:330:62 */
  assign n278 = n277 | ff_rst_ch_c;
  /*# scc_wave2.vhd:333:36 */
  assign n280 = n237_ff_cnt_ch_c == 12'b000000000000;
  /*# scc_wave2.vhd:334:48 */
  assign n282 = ff_ptr_ch_c + 5'b00001;
  /*# scc_wave2.vhd:337:48 */
  assign n284 = n237_ff_cnt_ch_c - 12'b000000000001;
  /*# scc_wave2.vhd:333:17 */
  assign n285 = n280 ? n282 : ff_ptr_ch_c;
  /*# scc_wave2.vhd:333:17 */
  assign n286 = n280 ? reg_freq_ch_c : n284;
  /*# scc_wave2.vhd:330:17 */
  assign n288 = n278 ? 5'b00000 : n285;
  /*# scc_wave2.vhd:330:17 */
  assign n289 = n278 ? reg_freq_ch_c : n286;
  /*# scc_wave2.vhd:340:34 */
  assign n290 = reg_freq_ch_d[11:3]; // extract
  /*# scc_wave2.vhd:340:48 */
  assign n292 = n290 == 9'b000000000;
  /*# scc_wave2.vhd:340:62 */
  assign n293 = n292 | ff_rst_ch_d;
  /*# scc_wave2.vhd:343:36 */
  assign n295 = n237_ff_cnt_ch_d == 12'b000000000000;
  /*# scc_wave2.vhd:344:48 */
  assign n297 = ff_ptr_ch_d + 5'b00001;
  /*# scc_wave2.vhd:347:48 */
  assign n299 = n237_ff_cnt_ch_d - 12'b000000000001;
  /*# scc_wave2.vhd:343:17 */
  assign n300 = n295 ? n297 : ff_ptr_ch_d;
  /*# scc_wave2.vhd:343:17 */
  assign n301 = n295 ? reg_freq_ch_d : n299;
  /*# scc_wave2.vhd:340:17 */
  assign n303 = n293 ? 5'b00000 : n300;
  /*# scc_wave2.vhd:340:17 */
  assign n304 = n293 ? reg_freq_ch_d : n301;
  /*# scc_wave2.vhd:350:34 */
  assign n305 = reg_freq_ch_e[11:3]; // extract
  /*# scc_wave2.vhd:350:48 */
  assign n307 = n305 == 9'b000000000;
  /*# scc_wave2.vhd:350:62 */
  assign n308 = n307 | ff_rst_ch_e;
  /*# scc_wave2.vhd:353:36 */
  assign n310 = n237_ff_cnt_ch_e == 12'b000000000000;
  /*# scc_wave2.vhd:354:48 */
  assign n312 = ff_ptr_ch_e + 5'b00001;
  /*# scc_wave2.vhd:357:48 */
  assign n314 = n237_ff_cnt_ch_e - 12'b000000000001;
  /*# scc_wave2.vhd:353:17 */
  assign n315 = n310 ? n312 : ff_ptr_ch_e;
  /*# scc_wave2.vhd:353:17 */
  assign n316 = n310 ? reg_freq_ch_e : n314;
  /*# scc_wave2.vhd:350:17 */
  assign n318 = n308 ? 5'b00000 : n315;
  /*# scc_wave2.vhd:350:17 */
  assign n319 = n308 ? reg_freq_ch_e : n316;
  /*# scc_wave2.vhd:367:41 */
  assign n361 = w_wave_ce ? adr : n366;
  /*# scc_wave2.vhd:368:24 */
  assign n363 = {3'b000, ff_ptr_ch_a};
  /*# scc_wave2.vhd:368:57 */
  assign n365 = ff_ch_num == 3'b000;
  /*# scc_wave2.vhd:367:66 */
  assign n366 = n365 ? n363 : n371;
  /*# scc_wave2.vhd:369:24 */
  assign n368 = {3'b001, ff_ptr_ch_b};
  /*# scc_wave2.vhd:369:57 */
  assign n370 = ff_ch_num == 3'b001;
  /*# scc_wave2.vhd:368:66 */
  assign n371 = n370 ? n368 : n376;
  /*# scc_wave2.vhd:370:24 */
  assign n373 = {3'b010, ff_ptr_ch_c};
  /*# scc_wave2.vhd:370:57 */
  assign n375 = ff_ch_num == 3'b010;
  /*# scc_wave2.vhd:369:66 */
  assign n376 = n375 ? n373 : n381;
  /*# scc_wave2.vhd:371:24 */
  assign n378 = {3'b011, ff_ptr_ch_d};
  /*# scc_wave2.vhd:371:57 */
  assign n380 = ff_ch_num == 3'b011;
  /*# scc_wave2.vhd:370:66 */
  assign n381 = n380 ? n378 : n384;
  /*# scc_wave2.vhd:372:24 */
  assign n383 = {3'b100, ff_ptr_ch_e};
  /*# scc_wave2.vhd:371:66 */
  assign n384 = sccplus ? n383 : n386;
  /*# scc_wave2.vhd:373:24 */
  assign n386 = {3'b011, ff_ptr_ch_e};
  /*# scc_wave2.vhd:375:5 */
  ram_Brtl wavemem (
    .adr(w_wave_adr),
    .clk(clk21m),
    .we(w_wave_we),
    .dbo(dbo),
    .dbi(wavemem_n387));
  /*# scc_wave2.vhd:419:17 */
  assign n416 = ff_ch_num_dl == 3'b001;
  /*# scc_wave2.vhd:420:17 */
  assign n419 = ff_ch_num_dl == 3'b010;
  /*# scc_wave2.vhd:421:17 */
  assign n422 = ff_ch_num_dl == 3'b011;
  /*# scc_wave2.vhd:422:17 */
  assign n425 = ff_ch_num_dl == 3'b100;
  /*# scc_wave2.vhd:423:17 */
  assign n428 = ff_ch_num_dl == 3'b101;
  /*# scc_wave2.vhd:418:5 */
  assign n430 = {n428, n425, n422, n419, n416};
  /*# scc_wave2.vhd:418:5 */
  always @*
    case (n430)
      5'b10000: n431 = 5'b10000;
      5'b01000: n431 = 5'b01000;
      5'b00100: n431 = 5'b00100;
      5'b00010: n431 = 5'b00010;
      5'b00001: n431 = 5'b00001;
      default: n431 = 5'b00000;
    endcase
  /*# scc_wave2.vhd:426:30 */
  assign n432 = w_ch_dec[0]; // extract
  /*# scc_wave2.vhd:426:48 */
  assign n433 = reg_ch_sel[0]; // extract
  /*# scc_wave2.vhd:426:34 */
  assign n434 = n432 & n433;
  /*# scc_wave2.vhd:427:30 */
  assign n435 = w_ch_dec[1]; // extract
  /*# scc_wave2.vhd:427:48 */
  assign n436 = reg_ch_sel[1]; // extract
  /*# scc_wave2.vhd:427:34 */
  assign n437 = n435 & n436;
  /*# scc_wave2.vhd:426:53 */
  assign n438 = n434 | n437;
  /*# scc_wave2.vhd:428:30 */
  assign n439 = w_ch_dec[2]; // extract
  /*# scc_wave2.vhd:428:48 */
  assign n440 = reg_ch_sel[2]; // extract
  /*# scc_wave2.vhd:428:34 */
  assign n441 = n439 & n440;
  /*# scc_wave2.vhd:427:53 */
  assign n442 = n438 | n441;
  /*# scc_wave2.vhd:429:30 */
  assign n443 = w_ch_dec[3]; // extract
  /*# scc_wave2.vhd:429:48 */
  assign n444 = reg_ch_sel[3]; // extract
  /*# scc_wave2.vhd:429:34 */
  assign n445 = n443 & n444;
  /*# scc_wave2.vhd:428:53 */
  assign n446 = n442 | n445;
  /*# scc_wave2.vhd:430:30 */
  assign n447 = w_ch_dec[4]; // extract
  /*# scc_wave2.vhd:430:48 */
  assign n448 = reg_ch_sel[4]; // extract
  /*# scc_wave2.vhd:430:34 */
  assign n449 = n447 & n448;
  /*# scc_wave2.vhd:429:53 */
  assign n450 = n446 | n449;
  /*# scc_wave2.vhd:432:21 */
  assign n451 = {w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit};
  /*# scc_wave2.vhd:435:29 */
  assign n453 = ff_ch_num_dl == 3'b001;
  /*# scc_wave2.vhd:436:29 */
  assign n455 = ff_ch_num_dl == 3'b010;
  /*# scc_wave2.vhd:437:29 */
  assign n457 = ff_ch_num_dl == 3'b011;
  /*# scc_wave2.vhd:438:29 */
  assign n459 = ff_ch_num_dl == 3'b100;
  /*# scc_wave2.vhd:439:29 */
  assign n461 = ff_ch_num_dl == 3'b101;
  /*# scc_wave2.vhd:434:5 */
  assign n463 = {n461, n459, n457, n455, n453};
  /*# scc_wave2.vhd:434:5 */
  always @*
    case (n463)
      5'b10000: n464 = reg_vol_ch_e;
      5'b01000: n464 = reg_vol_ch_d;
      5'b00100: n464 = reg_vol_ch_c;
      5'b00010: n464 = reg_vol_ch_b;
      5'b00001: n464 = reg_vol_ch_a;
      default: n464 = 4'b0000;
    endcase
  /*# scc_wave2.vhd:442:28 */
  assign n465 = w_ch_mask & ff_wave_dat;
  /*# scc_wave2.vhd:452:48 */
  assign n467 = {1'b0, w_ch_vol};
  /*# scc_wave2.vhd:452:35 */
  assign n468 = {{5{w_wave[7]}}, w_wave}; // sext
  /*# scc_wave2.vhd:452:35 */
  assign n469 = {{8{n467[4]}}, n467}; // sext
  /*# scc_wave2.vhd:452:35 */
  assign n470 = $signed(n468) * $signed(n469); // smul
  /*# scc_wave2.vhd:453:44 */
  assign n471 = w_mul_s[11:0]; // extract
  /*# scc_wave2.vhd:496:28 */
  assign n475 = ~ff_wave_ce;
  /*# scc_wave2.vhd:497:31 */
  assign n477 = ff_ch_num == 3'b101;
  /*# scc_wave2.vhd:500:44 */
  assign n479 = ff_ch_num + 3'b001;
  /*# scc_wave2.vhd:497:17 */
  assign n481 = n477 ? 3'b000 : n479;
  /*# scc_wave2.vhd:525:31 */
  assign n490 = ~ff_wave_ce_dl;
  /*# scc_wave2.vhd:526:34 */
  assign n492 = ff_ch_num_dl == 3'b001;
  /*# scc_wave2.vhd:527:39 */
  assign n493 = w_mul[11]; // extract
  /*# scc_wave2.vhd:527:51 */
  assign n494 = w_mul[11]; // extract
  /*# scc_wave2.vhd:527:44 */
  assign n495 = {n493, n494};
  /*# scc_wave2.vhd:527:63 */
  assign n496 = w_mul[11]; // extract
  /*# scc_wave2.vhd:527:56 */
  assign n497 = {n495, n496};
  /*# scc_wave2.vhd:527:68 */
  assign n498 = {n497, w_mul};
  /*# scc_wave2.vhd:528:37 */
  assign n500 = ff_ch_num_dl != 3'b000;
  /*# scc_wave2.vhd:529:39 */
  assign n501 = w_mul[11]; // extract
  /*# scc_wave2.vhd:529:51 */
  assign n502 = w_mul[11]; // extract
  /*# scc_wave2.vhd:529:44 */
  assign n503 = {n501, n502};
  /*# scc_wave2.vhd:529:63 */
  assign n504 = w_mul[11]; // extract
  /*# scc_wave2.vhd:529:56 */
  assign n505 = {n503, n504};
  /*# scc_wave2.vhd:529:68 */
  assign n506 = {n505, w_mul};
  /*# scc_wave2.vhd:529:77 */
  assign n507 = n506 + ff_mix;
  /*# scc_wave2.vhd:528:17 */
  assign n508 = n500 ? n507 : ff_mix;
  /*# scc_wave2.vhd:526:17 */
  assign n509 = n492 ? n498 : n508;
  /*# scc_wave2.vhd:546:30 */
  assign n519 = ff_ch_num_dl == 3'b101;
  /*# scc_wave2.vhd:547:28 */
  assign n521 = ff_mix != 15'b000000000000000;
  /*# scc_wave2.vhd:547:17 */
  assign n524 = n521 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:578:30 */
  assign n534 = ff_ch_num_dl == 3'b000;
  /*# scc_wave2.vhd:580:36 */
  assign n535 = ~ff_wavlatch_tgl;
  /*# scc_wave2.vhd:585:28 */
  assign n537 = ff_mix != 15'b000000000000000;
  /*# scc_wave2.vhd:585:17 */
  assign n540 = n537 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:599:40 */
  assign n556 = ff_wave != 15'b000000000000000;
  /*# scc_wave2.vhd:599:25 */
  assign n557 = n556 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:389:9 */
  assign n562 = ff_wave_ce ? ram_dbi : n563;
  /*# scc_wave2.vhd:389:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n563 <= 8'b11111111;
    else
      n563 <= n562;
  /*# scc_wave2.vhd:216:9 */
  assign n564 = n29 ? n124 : reg_freq_ch_a;
  /*# scc_wave2.vhd:216:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n565 <= 12'b000000000000;
    else
      n565 <= n564;
  /*# scc_wave2.vhd:216:9 */
  assign n566 = n29 ? n126 : reg_freq_ch_b;
  /*# scc_wave2.vhd:216:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n567 <= 12'b000000000000;
    else
      n567 <= n566;
  /*# scc_wave2.vhd:216:9 */
  assign n568 = n29 ? n128 : reg_freq_ch_c;
  /*# scc_wave2.vhd:216:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n569 <= 12'b000000000000;
    else
      n569 <= n568;
  /*# scc_wave2.vhd:216:9 */
  assign n570 = n29 ? n130 : reg_freq_ch_d;
  /*# scc_wave2.vhd:216:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n571 <= 12'b000000000000;
    else
      n571 <= n570;
  /*# scc_wave2.vhd:216:9 */
  assign n572 = n29 ? n132 : reg_freq_ch_e;
  /*# scc_wave2.vhd:216:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n573 <= 12'b000000000000;
    else
      n573 <= n572;
  /*# scc_wave2.vhd:216:9 */
  assign n574 = n29 ? n103 : reg_vol_ch_a;
  /*# scc_wave2.vhd:216:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n575 <= 4'b0000;
    else
      n575 <= n574;
  /*# scc_wave2.vhd:216:9 */
  assign n576 = n29 ? n104 : reg_vol_ch_b;
  /*# scc_wave2.vhd:216:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n577 <= 4'b0000;
    else
      n577 <= n576;
  /*# scc_wave2.vhd:216:9 */
  assign n578 = n29 ? n105 : reg_vol_ch_c;
  /*# scc_wave2.vhd:216:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n579 <= 4'b0000;
    else
      n579 <= n578;
  /*# scc_wave2.vhd:216:9 */
  assign n580 = n29 ? n106 : reg_vol_ch_d;
  /*# scc_wave2.vhd:216:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n581 <= 4'b0000;
    else
      n581 <= n580;
  /*# scc_wave2.vhd:216:9 */
  assign n582 = n29 ? n107 : reg_vol_ch_e;
  /*# scc_wave2.vhd:216:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n583 <= 4'b0000;
    else
      n583 <= n582;
  /*# scc_wave2.vhd:216:9 */
  assign n584 = n29 ? n108 : reg_ch_sel;
  /*# scc_wave2.vhd:216:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n585 <= 5'b00000;
    else
      n585 <= n584;
  /*# scc_wave2.vhd:216:9 */
  assign n586 = n149 ? dbo : reg_mode_sel;
  /*# scc_wave2.vhd:216:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n587 <= 8'b00000000;
    else
      n587 <= n586;
  /*# scc_wave2.vhd:216:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n588 <= 1'b0;
    else
      n588 <= n140;
  /*# scc_wave2.vhd:216:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n589 <= 1'b0;
    else
      n589 <= n141;
  /*# scc_wave2.vhd:216:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n590 <= 1'b0;
    else
      n590 <= n142;
  /*# scc_wave2.vhd:216:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n591 <= 1'b0;
    else
      n591 <= n143;
  /*# scc_wave2.vhd:216:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n592 <= 1'b0;
    else
      n592 <= n144;
  /*# scc_wave2.vhd:307:9 */
  assign n593 = clkena ? n258 : ff_ptr_ch_a;
  /*# scc_wave2.vhd:307:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n594 <= 5'b00000;
    else
      n594 <= n593;
  /*# scc_wave2.vhd:307:9 */
  assign n595 = clkena ? n273 : ff_ptr_ch_b;
  /*# scc_wave2.vhd:307:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n596 <= 5'b00000;
    else
      n596 <= n595;
  /*# scc_wave2.vhd:307:9 */
  assign n597 = clkena ? n288 : ff_ptr_ch_c;
  /*# scc_wave2.vhd:307:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n598 <= 5'b00000;
    else
      n598 <= n597;
  /*# scc_wave2.vhd:307:9 */
  assign n599 = clkena ? n303 : ff_ptr_ch_d;
  /*# scc_wave2.vhd:307:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n600 <= 5'b00000;
    else
      n600 <= n599;
  /*# scc_wave2.vhd:307:9 */
  assign n601 = clkena ? n318 : ff_ptr_ch_e;
  /*# scc_wave2.vhd:307:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n602 <= 5'b00000;
    else
      n602 <= n601;
  /*# scc_wave2.vhd:495:9 */
  assign n603 = n475 ? n481 : ff_ch_num;
  /*# scc_wave2.vhd:495:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n604 <= 3'b000;
    else
      n604 <= n603;
  /*# scc_wave2.vhd:407:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n605 <= 3'b000;
    else
      n605 <= ff_ch_num;
  /*# scc_wave2.vhd:524:9 */
  assign n606 = n490 ? n509 : ff_mix;
  /*# scc_wave2.vhd:524:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n607 <= 15'b000000000000000;
    else
      n607 <= n606;
  /*# scc_wave2.vhd:407:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n608 <= 1'b0;
    else
      n608 <= w_wave_ce;
  /*# scc_wave2.vhd:407:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n609 <= 1'b0;
    else
      n609 <= ff_wave_ce;
  /*# scc_wave2.vhd:216:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n610 <= 1'b0;
    else
      n610 <= req;
  /*# scc_wave2.vhd:407:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n611 <= 8'b00000000;
    else
      n611 <= ram_dbi;
  /*# scc_wave2.vhd:577:9 */
  assign n612 = n534 ? ff_mix : ff_wave;
  /*# scc_wave2.vhd:577:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n613 <= 15'b000000000000000;
    else
      n613 <= n612;
  /*# scc_wave2.vhd:577:9 */
  assign n614 = n534 ? n535 : ff_wavlatch_tgl;
  /*# scc_wave2.vhd:577:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n615 <= 1'b0;
    else
      n615 <= n614;
  /*# scc_wave2.vhd:577:9 */
  assign n616 = n534 ? n540 : ff_capnz;
  /*# scc_wave2.vhd:577:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n617 <= 1'b0;
    else
      n617 <= n616;
  /*# scc_wave2.vhd:545:9 */
  assign n618 = n519 ? n524 : ff_mix5_nz;
  /*# scc_wave2.vhd:545:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n619 <= 1'b0;
    else
      n619 <= n618;
  /*# scc_wave2.vhd:307:9 */
  assign n620 = clkena ? n259 : n237_ff_cnt_ch_a;
  /*# scc_wave2.vhd:307:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n621 <= 12'b000000000000;
    else
      n621 <= n620;
  /*# scc_wave2.vhd:307:9 */
  assign n622 = clkena ? n274 : n237_ff_cnt_ch_b;
  /*# scc_wave2.vhd:307:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n623 <= 12'b000000000000;
    else
      n623 <= n622;
  /*# scc_wave2.vhd:307:9 */
  assign n624 = clkena ? n289 : n237_ff_cnt_ch_c;
  /*# scc_wave2.vhd:307:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n625 <= 12'b000000000000;
    else
      n625 <= n624;
  /*# scc_wave2.vhd:307:9 */
  assign n626 = clkena ? n304 : n237_ff_cnt_ch_d;
  /*# scc_wave2.vhd:307:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n627 <= 12'b000000000000;
    else
      n627 <= n626;
  /*# scc_wave2.vhd:307:9 */
  assign n628 = clkena ? n319 : n237_ff_cnt_ch_e;
  /*# scc_wave2.vhd:307:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n629 <= 12'b000000000000;
    else
      n629 <= n628;
endmodule

