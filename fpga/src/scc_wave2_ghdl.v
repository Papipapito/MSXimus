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
//   fpga/src/ocm/scc_wave2.vhd            (md5 87cab76f17ea650e12e23f9048da0e1a)
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
//     avance del puntero (N1), escaneo vivo (N2), acumulador activo (N3),
//     tasa de captura del latch final (N4) y contenido de la captura +
//     registro de salida (N5) con las sondas dbg_ptr_lsb / dbg_scan_lsb /
//     dbg_mix_nz / dbg_wavlatch / dbg_capnz / dbg_wave_nz calibradas.
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
  reg [7:0] n620;
  wire [7:0] n621; // mem_rd
  assign dbi = n621; //(module output)
  /*# ram.vhd:50:10 */
  assign iadr = n620; // (signal)
  /*# ram.vhd:56:5 */
  always @(posedge clk)
    n620 <= adr;
  reg [7:0] blkram[255:0] ; // memory
  assign n621 = blkram[iadr];
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
   output dbg_wave_nz);
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
  wire n15;
  wire n16;
  wire n17;
  wire n18;
  wire [2:0] n19;
  wire n21;
  wire n22;
  wire [2:0] n23;
  wire n25;
  wire n26;
  wire n27;
  wire n28;
  wire [3:0] n29;
  wire n30;
  wire n32;
  wire [3:0] n33;
  wire n34;
  wire n36;
  wire n37;
  wire n39;
  wire [3:0] n40;
  wire n41;
  wire n43;
  wire n44;
  wire n46;
  wire [3:0] n47;
  wire n48;
  wire n50;
  wire n51;
  wire n53;
  wire [3:0] n54;
  wire n55;
  wire n57;
  wire n58;
  wire n60;
  wire [3:0] n61;
  wire n62;
  wire n64;
  wire [3:0] n65;
  wire n67;
  wire [3:0] n68;
  wire n70;
  wire [3:0] n71;
  wire n73;
  wire [3:0] n74;
  wire n76;
  wire [3:0] n77;
  wire n79;
  wire [4:0] n80;
  wire [14:0] n81;
  wire [7:0] n82;
  reg [7:0] n83;
  wire [3:0] n84;
  reg [3:0] n85;
  wire [7:0] n86;
  reg [7:0] n87;
  wire [3:0] n88;
  reg [3:0] n89;
  wire [7:0] n90;
  reg [7:0] n91;
  wire [3:0] n92;
  reg [3:0] n93;
  wire [7:0] n94;
  reg [7:0] n95;
  wire [3:0] n96;
  reg [3:0] n97;
  wire [7:0] n98;
  reg [7:0] n99;
  wire [3:0] n100;
  reg [3:0] n101;
  reg [3:0] n102;
  reg [3:0] n103;
  reg [3:0] n104;
  reg [3:0] n105;
  reg [3:0] n106;
  reg [4:0] n107;
  reg n108;
  reg n109;
  reg n110;
  reg n111;
  reg n112;
  wire n114;
  wire n116;
  wire n118;
  wire n120;
  wire n122;
  wire [11:0] n123;
  wire [11:0] n125;
  wire [11:0] n127;
  wire [11:0] n129;
  wire [11:0] n131;
  wire n139;
  wire n140;
  wire n141;
  wire n142;
  wire n143;
  wire n144;
  wire [2:0] n145;
  wire n147;
  wire n148;
  wire n206;
  wire n207;
  wire n208;
  wire n210;
  wire n211;
  wire n212;
  wire n216;
  wire n217;
  wire n221;
  wire n222;
  wire n226;
  wire n227;
  wire n229;
  wire n230;
  wire n233;
  wire n234;
  reg [11:0] n236_ff_cnt_ch_a;
  reg [11:0] n236_ff_cnt_ch_b;
  reg [11:0] n236_ff_cnt_ch_c;
  reg [11:0] n236_ff_cnt_ch_d;
  reg [11:0] n236_ff_cnt_ch_e;
  wire [8:0] n244;
  wire n246;
  wire n247;
  wire n249;
  wire [4:0] n251;
  wire [11:0] n253;
  wire [4:0] n254;
  wire [11:0] n255;
  wire [4:0] n257;
  wire [11:0] n258;
  wire [8:0] n259;
  wire n261;
  wire n262;
  wire n264;
  wire [4:0] n266;
  wire [11:0] n268;
  wire [4:0] n269;
  wire [11:0] n270;
  wire [4:0] n272;
  wire [11:0] n273;
  wire [8:0] n274;
  wire n276;
  wire n277;
  wire n279;
  wire [4:0] n281;
  wire [11:0] n283;
  wire [4:0] n284;
  wire [11:0] n285;
  wire [4:0] n287;
  wire [11:0] n288;
  wire [8:0] n289;
  wire n291;
  wire n292;
  wire n294;
  wire [4:0] n296;
  wire [11:0] n298;
  wire [4:0] n299;
  wire [11:0] n300;
  wire [4:0] n302;
  wire [11:0] n303;
  wire [8:0] n304;
  wire n306;
  wire n307;
  wire n309;
  wire [4:0] n311;
  wire [11:0] n313;
  wire [4:0] n314;
  wire [11:0] n315;
  wire [4:0] n317;
  wire [11:0] n318;
  wire [7:0] n360;
  wire [7:0] n362;
  wire n364;
  wire [7:0] n365;
  wire [7:0] n367;
  wire n369;
  wire [7:0] n370;
  wire [7:0] n372;
  wire n374;
  wire [7:0] n375;
  wire [7:0] n377;
  wire n379;
  wire [7:0] n380;
  wire [7:0] n382;
  wire [7:0] n383;
  wire [7:0] n385;
  wire [7:0] wavemem_n386;
  wire n415;
  wire n418;
  wire n421;
  wire n424;
  wire n427;
  wire [4:0] n429;
  reg [4:0] n430;
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
  wire n448;
  wire n449;
  wire [7:0] n450;
  wire n452;
  wire n454;
  wire n456;
  wire n458;
  wire n460;
  wire [4:0] n462;
  reg [3:0] n463;
  wire [7:0] n464;
  wire [4:0] n466;
  wire [12:0] n467;
  wire [12:0] n468;
  wire [12:0] n469;
  wire [11:0] n470;
  wire n474;
  wire n476;
  wire [2:0] n478;
  wire [2:0] n480;
  wire n489;
  wire n491;
  wire n492;
  wire n493;
  wire [1:0] n494;
  wire n495;
  wire [2:0] n496;
  wire [14:0] n497;
  wire [14:0] n498;
  wire [14:0] n500;
  wire n510;
  wire n511;
  wire n513;
  wire n516;
  wire n532;
  wire n533;
  wire [7:0] n538;
  reg [7:0] n539;
  wire [11:0] n540;
  reg [11:0] n541;
  wire [11:0] n542;
  reg [11:0] n543;
  wire [11:0] n544;
  reg [11:0] n545;
  wire [11:0] n546;
  reg [11:0] n547;
  wire [11:0] n548;
  reg [11:0] n549;
  wire [3:0] n550;
  reg [3:0] n551;
  wire [3:0] n552;
  reg [3:0] n553;
  wire [3:0] n554;
  reg [3:0] n555;
  wire [3:0] n556;
  reg [3:0] n557;
  wire [3:0] n558;
  reg [3:0] n559;
  wire [4:0] n560;
  reg [4:0] n561;
  wire [7:0] n562;
  reg [7:0] n563;
  reg n564;
  reg n565;
  reg n566;
  reg n567;
  reg n568;
  wire [4:0] n569;
  reg [4:0] n570;
  wire [4:0] n571;
  reg [4:0] n572;
  wire [4:0] n573;
  reg [4:0] n574;
  wire [4:0] n575;
  reg [4:0] n576;
  wire [4:0] n577;
  reg [4:0] n578;
  wire [2:0] n579;
  reg [2:0] n580;
  reg [2:0] n581;
  wire [14:0] n582;
  reg [14:0] n583;
  reg n584;
  reg n585;
  reg n586;
  reg [7:0] n587;
  wire [14:0] n588;
  reg [14:0] n589;
  wire n590;
  reg n591;
  wire n592;
  reg n593;
  wire [11:0] n594;
  reg [11:0] n595;
  wire [11:0] n596;
  reg [11:0] n597;
  wire [11:0] n598;
  reg [11:0] n599;
  wire [11:0] n600;
  reg [11:0] n601;
  wire [11:0] n602;
  reg [11:0] n603;
  assign ack = ff_req_dl; //(module output)
  assign dbi = n539; //(module output)
  assign wave = ff_wave; //(module output)
  assign dbg_vol_nz = n217; //(module output)
  assign dbg_sel_nz = n222; //(module output)
  assign dbg_freq_nz = n227; //(module output)
  assign dbg_ptr_lsb = n229; //(module output)
  assign dbg_scan_lsb = n230; //(module output)
  assign dbg_mix_nz = n234; //(module output)
  assign dbg_wavlatch = ff_wavlatch_tgl; //(module output)
  assign dbg_capnz = ff_capnz; //(module output)
  assign dbg_wave_nz = n533; //(module output)
  /*# scc_wave2.vhd:132:12 */
  assign w_wave_ce = n208; // (signal)
  /*# scc_wave2.vhd:133:12 */
  assign w_wave_we = n212; // (signal)
  /*# scc_wave2.vhd:134:12 */
  assign w_wave_adr = n360; // (signal)
  /*# scc_wave2.vhd:135:12 */
  assign w_ch_dec = n430; // (signal)
  /*# scc_wave2.vhd:136:12 */
  assign w_ch_bit = n449; // (signal)
  /*# scc_wave2.vhd:137:12 */
  assign w_ch_mask = n450; // (signal)
  /*# scc_wave2.vhd:138:12 */
  assign w_ch_vol = n463; // (signal)
  /*# scc_wave2.vhd:139:12 */
  assign w_wave = n464; // (signal)
  /*# scc_wave2.vhd:140:12 */
  assign w_mul = n470; // (signal)
  /*# scc_wave2.vhd:141:12 */
  assign w_mul_s = n469; // (signal)
  /*# scc_wave2.vhd:142:12 */
  assign ram_dbi = wavemem_n386; // (signal)
  /*# scc_wave2.vhd:148:12 */
  assign reg_freq_ch_a = n541; // (signal)
  /*# scc_wave2.vhd:149:12 */
  assign reg_freq_ch_b = n543; // (signal)
  /*# scc_wave2.vhd:150:12 */
  assign reg_freq_ch_c = n545; // (signal)
  /*# scc_wave2.vhd:151:12 */
  assign reg_freq_ch_d = n547; // (signal)
  /*# scc_wave2.vhd:152:12 */
  assign reg_freq_ch_e = n549; // (signal)
  /*# scc_wave2.vhd:153:12 */
  assign reg_vol_ch_a = n551; // (signal)
  /*# scc_wave2.vhd:154:12 */
  assign reg_vol_ch_b = n553; // (signal)
  /*# scc_wave2.vhd:155:12 */
  assign reg_vol_ch_c = n555; // (signal)
  /*# scc_wave2.vhd:156:12 */
  assign reg_vol_ch_d = n557; // (signal)
  /*# scc_wave2.vhd:157:12 */
  assign reg_vol_ch_e = n559; // (signal)
  /*# scc_wave2.vhd:158:12 */
  assign reg_ch_sel = n561; // (signal)
  /*# scc_wave2.vhd:159:12 */
  assign reg_mode_sel = n563; // (signal)
  /*# scc_wave2.vhd:162:12 */
  assign ff_rst_ch_a = n564; // (signal)
  /*# scc_wave2.vhd:163:12 */
  assign ff_rst_ch_b = n565; // (signal)
  /*# scc_wave2.vhd:164:12 */
  assign ff_rst_ch_c = n566; // (signal)
  /*# scc_wave2.vhd:165:12 */
  assign ff_rst_ch_d = n567; // (signal)
  /*# scc_wave2.vhd:166:12 */
  assign ff_rst_ch_e = n568; // (signal)
  /*# scc_wave2.vhd:167:12 */
  assign ff_ptr_ch_a = n570; // (signal)
  /*# scc_wave2.vhd:168:12 */
  assign ff_ptr_ch_b = n572; // (signal)
  /*# scc_wave2.vhd:169:12 */
  assign ff_ptr_ch_c = n574; // (signal)
  /*# scc_wave2.vhd:170:12 */
  assign ff_ptr_ch_d = n576; // (signal)
  /*# scc_wave2.vhd:171:12 */
  assign ff_ptr_ch_e = n578; // (signal)
  /*# scc_wave2.vhd:172:12 */
  assign ff_ch_num = n580; // (signal)
  /*# scc_wave2.vhd:173:12 */
  assign ff_ch_num_dl = n581; // (signal)
  /*# scc_wave2.vhd:174:12 */
  assign ff_mix = n583; // (signal)
  /*# scc_wave2.vhd:175:12 */
  assign ff_wave_ce = n584; // (signal)
  /*# scc_wave2.vhd:176:12 */
  assign ff_wave_ce_dl = n585; // (signal)
  /*# scc_wave2.vhd:177:12 */
  assign ff_req_dl = n586; // (signal)
  /*# scc_wave2.vhd:178:12 */
  assign ff_wave_dat = n587; // (signal)
  /*# scc_wave2.vhd:179:12 */
  assign ff_wave = n589; // (signal)
  /*# scc_wave2.vhd:180:12 */
  assign ff_wavlatch_tgl = n591; // (signal)
  /*# scc_wave2.vhd:181:12 */
  assign ff_capnz = n593; // (signal)
  /*# scc_wave2.vhd:215:41 */
  assign n15 = ~ff_req_dl;
  /*# scc_wave2.vhd:215:27 */
  assign n16 = n15 & req;
  /*# scc_wave2.vhd:215:47 */
  assign n17 = wrt & n16;
  /*# scc_wave2.vhd:216:27 */
  assign n18 = ~sccplus;
  /*# scc_wave2.vhd:216:40 */
  assign n19 = adr[7:5]; // extract
  /*# scc_wave2.vhd:216:53 */
  assign n21 = n19 == 3'b100;
  /*# scc_wave2.vhd:216:33 */
  assign n22 = n21 & n18;
  /*# scc_wave2.vhd:217:40 */
  assign n23 = adr[7:5]; // extract
  /*# scc_wave2.vhd:217:53 */
  assign n25 = n23 == 3'b101;
  /*# scc_wave2.vhd:217:33 */
  assign n26 = n25 & sccplus;
  /*# scc_wave2.vhd:216:62 */
  assign n27 = n22 | n26;
  /*# scc_wave2.vhd:215:61 */
  assign n28 = n27 & n17;
  /*# scc_wave2.vhd:218:25 */
  assign n29 = adr[3:0]; // extract
  /*# scc_wave2.vhd:219:114 */
  assign n30 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:219:21 */
  assign n32 = n29 == 4'b0000;
  /*# scc_wave2.vhd:220:71 */
  assign n33 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:220:114 */
  assign n34 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:220:21 */
  assign n36 = n29 == 4'b0001;
  /*# scc_wave2.vhd:221:114 */
  assign n37 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:221:21 */
  assign n39 = n29 == 4'b0010;
  /*# scc_wave2.vhd:222:71 */
  assign n40 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:222:114 */
  assign n41 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:222:21 */
  assign n43 = n29 == 4'b0011;
  /*# scc_wave2.vhd:223:114 */
  assign n44 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:223:21 */
  assign n46 = n29 == 4'b0100;
  /*# scc_wave2.vhd:224:71 */
  assign n47 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:224:114 */
  assign n48 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:224:21 */
  assign n50 = n29 == 4'b0101;
  /*# scc_wave2.vhd:225:114 */
  assign n51 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:225:21 */
  assign n53 = n29 == 4'b0110;
  /*# scc_wave2.vhd:226:71 */
  assign n54 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:226:114 */
  assign n55 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:226:21 */
  assign n57 = n29 == 4'b0111;
  /*# scc_wave2.vhd:227:114 */
  assign n58 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:227:21 */
  assign n60 = n29 == 4'b1000;
  /*# scc_wave2.vhd:228:71 */
  assign n61 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:228:114 */
  assign n62 = reg_mode_sel[5]; // extract
  /*# scc_wave2.vhd:228:21 */
  assign n64 = n29 == 4'b1001;
  /*# scc_wave2.vhd:229:71 */
  assign n65 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:229:21 */
  assign n67 = n29 == 4'b1010;
  /*# scc_wave2.vhd:230:71 */
  assign n68 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:230:21 */
  assign n70 = n29 == 4'b1011;
  /*# scc_wave2.vhd:231:71 */
  assign n71 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:231:21 */
  assign n73 = n29 == 4'b1100;
  /*# scc_wave2.vhd:232:71 */
  assign n74 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:232:21 */
  assign n76 = n29 == 4'b1101;
  /*# scc_wave2.vhd:233:71 */
  assign n77 = dbo[3:0]; // extract
  /*# scc_wave2.vhd:233:21 */
  assign n79 = n29 == 4'b1110;
  /*# scc_wave2.vhd:234:71 */
  assign n80 = dbo[4:0]; // extract
  /*# scc_wave2.vhd:218:17 */
  assign n81 = {n79, n76, n73, n70, n67, n64, n60, n57, n53, n50, n46, n43, n39, n36, n32};
  /*# scc_wave2.vhd:148:12 */
  assign n82 = reg_freq_ch_a[7:0]; // extract
  /*# scc_wave2.vhd:218:17 */
  always @*
    case (n81)
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
      15'b000000000000010: n83 = n82;
      15'b000000000000001: n83 = dbo;
      default: n83 = n82;
    endcase
  /*# scc_wave2.vhd:148:12 */
  assign n84 = reg_freq_ch_a[11:8]; // extract
  /*# scc_wave2.vhd:218:17 */
  always @*
    case (n81)
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
      15'b000000000000100: n85 = n84;
      15'b000000000000010: n85 = n33;
      15'b000000000000001: n85 = n84;
      default: n85 = n84;
    endcase
  /*# scc_wave2.vhd:149:12 */
  assign n86 = reg_freq_ch_b[7:0]; // extract
  /*# scc_wave2.vhd:218:17 */
  always @*
    case (n81)
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
      15'b000000000001000: n87 = n86;
      15'b000000000000100: n87 = dbo;
      15'b000000000000010: n87 = n86;
      15'b000000000000001: n87 = n86;
      default: n87 = n86;
    endcase
  /*# scc_wave2.vhd:149:12 */
  assign n88 = reg_freq_ch_b[11:8]; // extract
  /*# scc_wave2.vhd:218:17 */
  always @*
    case (n81)
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
      15'b000000000010000: n89 = n88;
      15'b000000000001000: n89 = n40;
      15'b000000000000100: n89 = n88;
      15'b000000000000010: n89 = n88;
      15'b000000000000001: n89 = n88;
      default: n89 = n88;
    endcase
  /*# scc_wave2.vhd:150:12 */
  assign n90 = reg_freq_ch_c[7:0]; // extract
  /*# scc_wave2.vhd:218:17 */
  always @*
    case (n81)
      15'b100000000000000: n91 = n90;
      15'b010000000000000: n91 = n90;
      15'b001000000000000: n91 = n90;
      15'b000100000000000: n91 = n90;
      15'b000010000000000: n91 = n90;
      15'b000001000000000: n91 = n90;
      15'b000000100000000: n91 = n90;
      15'b000000010000000: n91 = n90;
      15'b000000001000000: n91 = n90;
      15'b000000000100000: n91 = n90;
      15'b000000000010000: n91 = dbo;
      15'b000000000001000: n91 = n90;
      15'b000000000000100: n91 = n90;
      15'b000000000000010: n91 = n90;
      15'b000000000000001: n91 = n90;
      default: n91 = n90;
    endcase
  /*# scc_wave2.vhd:150:12 */
  assign n92 = reg_freq_ch_c[11:8]; // extract
  /*# scc_wave2.vhd:218:17 */
  always @*
    case (n81)
      15'b100000000000000: n93 = n92;
      15'b010000000000000: n93 = n92;
      15'b001000000000000: n93 = n92;
      15'b000100000000000: n93 = n92;
      15'b000010000000000: n93 = n92;
      15'b000001000000000: n93 = n92;
      15'b000000100000000: n93 = n92;
      15'b000000010000000: n93 = n92;
      15'b000000001000000: n93 = n92;
      15'b000000000100000: n93 = n47;
      15'b000000000010000: n93 = n92;
      15'b000000000001000: n93 = n92;
      15'b000000000000100: n93 = n92;
      15'b000000000000010: n93 = n92;
      15'b000000000000001: n93 = n92;
      default: n93 = n92;
    endcase
  /*# scc_wave2.vhd:151:12 */
  assign n94 = reg_freq_ch_d[7:0]; // extract
  /*# scc_wave2.vhd:218:17 */
  always @*
    case (n81)
      15'b100000000000000: n95 = n94;
      15'b010000000000000: n95 = n94;
      15'b001000000000000: n95 = n94;
      15'b000100000000000: n95 = n94;
      15'b000010000000000: n95 = n94;
      15'b000001000000000: n95 = n94;
      15'b000000100000000: n95 = n94;
      15'b000000010000000: n95 = n94;
      15'b000000001000000: n95 = dbo;
      15'b000000000100000: n95 = n94;
      15'b000000000010000: n95 = n94;
      15'b000000000001000: n95 = n94;
      15'b000000000000100: n95 = n94;
      15'b000000000000010: n95 = n94;
      15'b000000000000001: n95 = n94;
      default: n95 = n94;
    endcase
  /*# scc_wave2.vhd:151:12 */
  assign n96 = reg_freq_ch_d[11:8]; // extract
  /*# scc_wave2.vhd:218:17 */
  always @*
    case (n81)
      15'b100000000000000: n97 = n96;
      15'b010000000000000: n97 = n96;
      15'b001000000000000: n97 = n96;
      15'b000100000000000: n97 = n96;
      15'b000010000000000: n97 = n96;
      15'b000001000000000: n97 = n96;
      15'b000000100000000: n97 = n96;
      15'b000000010000000: n97 = n54;
      15'b000000001000000: n97 = n96;
      15'b000000000100000: n97 = n96;
      15'b000000000010000: n97 = n96;
      15'b000000000001000: n97 = n96;
      15'b000000000000100: n97 = n96;
      15'b000000000000010: n97 = n96;
      15'b000000000000001: n97 = n96;
      default: n97 = n96;
    endcase
  /*# scc_wave2.vhd:152:12 */
  assign n98 = reg_freq_ch_e[7:0]; // extract
  /*# scc_wave2.vhd:218:17 */
  always @*
    case (n81)
      15'b100000000000000: n99 = n98;
      15'b010000000000000: n99 = n98;
      15'b001000000000000: n99 = n98;
      15'b000100000000000: n99 = n98;
      15'b000010000000000: n99 = n98;
      15'b000001000000000: n99 = n98;
      15'b000000100000000: n99 = dbo;
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
  /*# scc_wave2.vhd:152:12 */
  assign n100 = reg_freq_ch_e[11:8]; // extract
  /*# scc_wave2.vhd:218:17 */
  always @*
    case (n81)
      15'b100000000000000: n101 = n100;
      15'b010000000000000: n101 = n100;
      15'b001000000000000: n101 = n100;
      15'b000100000000000: n101 = n100;
      15'b000010000000000: n101 = n100;
      15'b000001000000000: n101 = n61;
      15'b000000100000000: n101 = n100;
      15'b000000010000000: n101 = n100;
      15'b000000001000000: n101 = n100;
      15'b000000000100000: n101 = n100;
      15'b000000000010000: n101 = n100;
      15'b000000000001000: n101 = n100;
      15'b000000000000100: n101 = n100;
      15'b000000000000010: n101 = n100;
      15'b000000000000001: n101 = n100;
      default: n101 = n100;
    endcase
  /*# scc_wave2.vhd:218:17 */
  always @*
    case (n81)
      15'b100000000000000: n102 = reg_vol_ch_a;
      15'b010000000000000: n102 = reg_vol_ch_a;
      15'b001000000000000: n102 = reg_vol_ch_a;
      15'b000100000000000: n102 = reg_vol_ch_a;
      15'b000010000000000: n102 = n65;
      15'b000001000000000: n102 = reg_vol_ch_a;
      15'b000000100000000: n102 = reg_vol_ch_a;
      15'b000000010000000: n102 = reg_vol_ch_a;
      15'b000000001000000: n102 = reg_vol_ch_a;
      15'b000000000100000: n102 = reg_vol_ch_a;
      15'b000000000010000: n102 = reg_vol_ch_a;
      15'b000000000001000: n102 = reg_vol_ch_a;
      15'b000000000000100: n102 = reg_vol_ch_a;
      15'b000000000000010: n102 = reg_vol_ch_a;
      15'b000000000000001: n102 = reg_vol_ch_a;
      default: n102 = reg_vol_ch_a;
    endcase
  /*# scc_wave2.vhd:218:17 */
  always @*
    case (n81)
      15'b100000000000000: n103 = reg_vol_ch_b;
      15'b010000000000000: n103 = reg_vol_ch_b;
      15'b001000000000000: n103 = reg_vol_ch_b;
      15'b000100000000000: n103 = n68;
      15'b000010000000000: n103 = reg_vol_ch_b;
      15'b000001000000000: n103 = reg_vol_ch_b;
      15'b000000100000000: n103 = reg_vol_ch_b;
      15'b000000010000000: n103 = reg_vol_ch_b;
      15'b000000001000000: n103 = reg_vol_ch_b;
      15'b000000000100000: n103 = reg_vol_ch_b;
      15'b000000000010000: n103 = reg_vol_ch_b;
      15'b000000000001000: n103 = reg_vol_ch_b;
      15'b000000000000100: n103 = reg_vol_ch_b;
      15'b000000000000010: n103 = reg_vol_ch_b;
      15'b000000000000001: n103 = reg_vol_ch_b;
      default: n103 = reg_vol_ch_b;
    endcase
  /*# scc_wave2.vhd:218:17 */
  always @*
    case (n81)
      15'b100000000000000: n104 = reg_vol_ch_c;
      15'b010000000000000: n104 = reg_vol_ch_c;
      15'b001000000000000: n104 = n71;
      15'b000100000000000: n104 = reg_vol_ch_c;
      15'b000010000000000: n104 = reg_vol_ch_c;
      15'b000001000000000: n104 = reg_vol_ch_c;
      15'b000000100000000: n104 = reg_vol_ch_c;
      15'b000000010000000: n104 = reg_vol_ch_c;
      15'b000000001000000: n104 = reg_vol_ch_c;
      15'b000000000100000: n104 = reg_vol_ch_c;
      15'b000000000010000: n104 = reg_vol_ch_c;
      15'b000000000001000: n104 = reg_vol_ch_c;
      15'b000000000000100: n104 = reg_vol_ch_c;
      15'b000000000000010: n104 = reg_vol_ch_c;
      15'b000000000000001: n104 = reg_vol_ch_c;
      default: n104 = reg_vol_ch_c;
    endcase
  /*# scc_wave2.vhd:218:17 */
  always @*
    case (n81)
      15'b100000000000000: n105 = reg_vol_ch_d;
      15'b010000000000000: n105 = n74;
      15'b001000000000000: n105 = reg_vol_ch_d;
      15'b000100000000000: n105 = reg_vol_ch_d;
      15'b000010000000000: n105 = reg_vol_ch_d;
      15'b000001000000000: n105 = reg_vol_ch_d;
      15'b000000100000000: n105 = reg_vol_ch_d;
      15'b000000010000000: n105 = reg_vol_ch_d;
      15'b000000001000000: n105 = reg_vol_ch_d;
      15'b000000000100000: n105 = reg_vol_ch_d;
      15'b000000000010000: n105 = reg_vol_ch_d;
      15'b000000000001000: n105 = reg_vol_ch_d;
      15'b000000000000100: n105 = reg_vol_ch_d;
      15'b000000000000010: n105 = reg_vol_ch_d;
      15'b000000000000001: n105 = reg_vol_ch_d;
      default: n105 = reg_vol_ch_d;
    endcase
  /*# scc_wave2.vhd:218:17 */
  always @*
    case (n81)
      15'b100000000000000: n106 = n77;
      15'b010000000000000: n106 = reg_vol_ch_e;
      15'b001000000000000: n106 = reg_vol_ch_e;
      15'b000100000000000: n106 = reg_vol_ch_e;
      15'b000010000000000: n106 = reg_vol_ch_e;
      15'b000001000000000: n106 = reg_vol_ch_e;
      15'b000000100000000: n106 = reg_vol_ch_e;
      15'b000000010000000: n106 = reg_vol_ch_e;
      15'b000000001000000: n106 = reg_vol_ch_e;
      15'b000000000100000: n106 = reg_vol_ch_e;
      15'b000000000010000: n106 = reg_vol_ch_e;
      15'b000000000001000: n106 = reg_vol_ch_e;
      15'b000000000000100: n106 = reg_vol_ch_e;
      15'b000000000000010: n106 = reg_vol_ch_e;
      15'b000000000000001: n106 = reg_vol_ch_e;
      default: n106 = reg_vol_ch_e;
    endcase
  /*# scc_wave2.vhd:218:17 */
  always @*
    case (n81)
      15'b100000000000000: n107 = reg_ch_sel;
      15'b010000000000000: n107 = reg_ch_sel;
      15'b001000000000000: n107 = reg_ch_sel;
      15'b000100000000000: n107 = reg_ch_sel;
      15'b000010000000000: n107 = reg_ch_sel;
      15'b000001000000000: n107 = reg_ch_sel;
      15'b000000100000000: n107 = reg_ch_sel;
      15'b000000010000000: n107 = reg_ch_sel;
      15'b000000001000000: n107 = reg_ch_sel;
      15'b000000000100000: n107 = reg_ch_sel;
      15'b000000000010000: n107 = reg_ch_sel;
      15'b000000000001000: n107 = reg_ch_sel;
      15'b000000000000100: n107 = reg_ch_sel;
      15'b000000000000010: n107 = reg_ch_sel;
      15'b000000000000001: n107 = reg_ch_sel;
      default: n107 = n80;
    endcase
  /*# scc_wave2.vhd:218:17 */
  always @*
    case (n81)
      15'b100000000000000: n108 = ff_rst_ch_a;
      15'b010000000000000: n108 = ff_rst_ch_a;
      15'b001000000000000: n108 = ff_rst_ch_a;
      15'b000100000000000: n108 = ff_rst_ch_a;
      15'b000010000000000: n108 = ff_rst_ch_a;
      15'b000001000000000: n108 = ff_rst_ch_a;
      15'b000000100000000: n108 = ff_rst_ch_a;
      15'b000000010000000: n108 = ff_rst_ch_a;
      15'b000000001000000: n108 = ff_rst_ch_a;
      15'b000000000100000: n108 = ff_rst_ch_a;
      15'b000000000010000: n108 = ff_rst_ch_a;
      15'b000000000001000: n108 = ff_rst_ch_a;
      15'b000000000000100: n108 = ff_rst_ch_a;
      15'b000000000000010: n108 = n34;
      15'b000000000000001: n108 = n30;
      default: n108 = ff_rst_ch_a;
    endcase
  /*# scc_wave2.vhd:218:17 */
  always @*
    case (n81)
      15'b100000000000000: n109 = ff_rst_ch_b;
      15'b010000000000000: n109 = ff_rst_ch_b;
      15'b001000000000000: n109 = ff_rst_ch_b;
      15'b000100000000000: n109 = ff_rst_ch_b;
      15'b000010000000000: n109 = ff_rst_ch_b;
      15'b000001000000000: n109 = ff_rst_ch_b;
      15'b000000100000000: n109 = ff_rst_ch_b;
      15'b000000010000000: n109 = ff_rst_ch_b;
      15'b000000001000000: n109 = ff_rst_ch_b;
      15'b000000000100000: n109 = ff_rst_ch_b;
      15'b000000000010000: n109 = ff_rst_ch_b;
      15'b000000000001000: n109 = n41;
      15'b000000000000100: n109 = n37;
      15'b000000000000010: n109 = ff_rst_ch_b;
      15'b000000000000001: n109 = ff_rst_ch_b;
      default: n109 = ff_rst_ch_b;
    endcase
  /*# scc_wave2.vhd:218:17 */
  always @*
    case (n81)
      15'b100000000000000: n110 = ff_rst_ch_c;
      15'b010000000000000: n110 = ff_rst_ch_c;
      15'b001000000000000: n110 = ff_rst_ch_c;
      15'b000100000000000: n110 = ff_rst_ch_c;
      15'b000010000000000: n110 = ff_rst_ch_c;
      15'b000001000000000: n110 = ff_rst_ch_c;
      15'b000000100000000: n110 = ff_rst_ch_c;
      15'b000000010000000: n110 = ff_rst_ch_c;
      15'b000000001000000: n110 = ff_rst_ch_c;
      15'b000000000100000: n110 = n48;
      15'b000000000010000: n110 = n44;
      15'b000000000001000: n110 = ff_rst_ch_c;
      15'b000000000000100: n110 = ff_rst_ch_c;
      15'b000000000000010: n110 = ff_rst_ch_c;
      15'b000000000000001: n110 = ff_rst_ch_c;
      default: n110 = ff_rst_ch_c;
    endcase
  /*# scc_wave2.vhd:218:17 */
  always @*
    case (n81)
      15'b100000000000000: n111 = ff_rst_ch_d;
      15'b010000000000000: n111 = ff_rst_ch_d;
      15'b001000000000000: n111 = ff_rst_ch_d;
      15'b000100000000000: n111 = ff_rst_ch_d;
      15'b000010000000000: n111 = ff_rst_ch_d;
      15'b000001000000000: n111 = ff_rst_ch_d;
      15'b000000100000000: n111 = ff_rst_ch_d;
      15'b000000010000000: n111 = n55;
      15'b000000001000000: n111 = n51;
      15'b000000000100000: n111 = ff_rst_ch_d;
      15'b000000000010000: n111 = ff_rst_ch_d;
      15'b000000000001000: n111 = ff_rst_ch_d;
      15'b000000000000100: n111 = ff_rst_ch_d;
      15'b000000000000010: n111 = ff_rst_ch_d;
      15'b000000000000001: n111 = ff_rst_ch_d;
      default: n111 = ff_rst_ch_d;
    endcase
  /*# scc_wave2.vhd:218:17 */
  always @*
    case (n81)
      15'b100000000000000: n112 = ff_rst_ch_e;
      15'b010000000000000: n112 = ff_rst_ch_e;
      15'b001000000000000: n112 = ff_rst_ch_e;
      15'b000100000000000: n112 = ff_rst_ch_e;
      15'b000010000000000: n112 = ff_rst_ch_e;
      15'b000001000000000: n112 = n62;
      15'b000000100000000: n112 = n58;
      15'b000000010000000: n112 = ff_rst_ch_e;
      15'b000000001000000: n112 = ff_rst_ch_e;
      15'b000000000100000: n112 = ff_rst_ch_e;
      15'b000000000010000: n112 = ff_rst_ch_e;
      15'b000000000001000: n112 = ff_rst_ch_e;
      15'b000000000000100: n112 = ff_rst_ch_e;
      15'b000000000000010: n112 = ff_rst_ch_e;
      15'b000000000000001: n112 = ff_rst_ch_e;
      default: n112 = ff_rst_ch_e;
    endcase
  /*# scc_wave2.vhd:236:13 */
  assign n114 = clkena ? 1'b0 : ff_rst_ch_a;
  /*# scc_wave2.vhd:236:13 */
  assign n116 = clkena ? 1'b0 : ff_rst_ch_b;
  /*# scc_wave2.vhd:236:13 */
  assign n118 = clkena ? 1'b0 : ff_rst_ch_c;
  /*# scc_wave2.vhd:236:13 */
  assign n120 = clkena ? 1'b0 : ff_rst_ch_d;
  /*# scc_wave2.vhd:236:13 */
  assign n122 = clkena ? 1'b0 : ff_rst_ch_e;
  /*# scc_wave2.vhd:215:13 */
  assign n123 = {n85, n83};
  /*# scc_wave2.vhd:215:13 */
  assign n125 = {n89, n87};
  /*# scc_wave2.vhd:215:13 */
  assign n127 = {n93, n91};
  /*# scc_wave2.vhd:215:13 */
  assign n129 = {n97, n95};
  /*# scc_wave2.vhd:215:13 */
  assign n131 = {n101, n99};
  /*# scc_wave2.vhd:215:13 */
  assign n139 = n28 ? n108 : n114;
  /*# scc_wave2.vhd:215:13 */
  assign n140 = n28 ? n109 : n116;
  /*# scc_wave2.vhd:215:13 */
  assign n141 = n28 ? n110 : n118;
  /*# scc_wave2.vhd:215:13 */
  assign n142 = n28 ? n111 : n120;
  /*# scc_wave2.vhd:215:13 */
  assign n143 = n28 ? n112 : n122;
  /*# scc_wave2.vhd:245:27 */
  assign n144 = wrt & req;
  /*# scc_wave2.vhd:245:48 */
  assign n145 = adr[7:5]; // extract
  /*# scc_wave2.vhd:245:61 */
  assign n147 = n145 == 3'b110;
  /*# scc_wave2.vhd:245:41 */
  assign n148 = n147 & n144;
  /*# scc_wave2.vhd:254:55 */
  assign n206 = ~ff_req_dl;
  /*# scc_wave2.vhd:254:41 */
  assign n207 = n206 & req;
  /*# scc_wave2.vhd:254:25 */
  assign n208 = n207 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:255:55 */
  assign n210 = ~ff_req_dl;
  /*# scc_wave2.vhd:255:41 */
  assign n211 = n210 & req;
  /*# scc_wave2.vhd:255:25 */
  assign n212 = n211 ? wrt : 1'b0;
  /*# scc_wave2.vhd:259:44 */
  assign n216 = reg_vol_ch_a != 4'b0000;
  /*# scc_wave2.vhd:259:24 */
  assign n217 = n216 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:260:42 */
  assign n221 = reg_ch_sel != 5'b00000;
  /*# scc_wave2.vhd:260:24 */
  assign n222 = n221 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:261:45 */
  assign n226 = reg_freq_ch_a != 12'b000000000000;
  /*# scc_wave2.vhd:261:24 */
  assign n227 = n226 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:267:31 */
  assign n229 = ff_ptr_ch_a[0]; // extract
  /*# scc_wave2.vhd:279:30 */
  assign n230 = ff_ch_num[0]; // extract
  /*# scc_wave2.vhd:280:39 */
  assign n233 = ff_mix != 15'b000000000000000;
  /*# scc_wave2.vhd:280:25 */
  assign n234 = n233 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:286:18 */
  always @*
    n236_ff_cnt_ch_a = n595; // (isignal)
  initial
    n236_ff_cnt_ch_a = 12'bX;
  /*# scc_wave2.vhd:287:18 */
  always @*
    n236_ff_cnt_ch_b = n597; // (isignal)
  initial
    n236_ff_cnt_ch_b = 12'bX;
  /*# scc_wave2.vhd:288:18 */
  always @*
    n236_ff_cnt_ch_c = n599; // (isignal)
  initial
    n236_ff_cnt_ch_c = 12'bX;
  /*# scc_wave2.vhd:289:18 */
  always @*
    n236_ff_cnt_ch_d = n601; // (isignal)
  initial
    n236_ff_cnt_ch_d = 12'bX;
  /*# scc_wave2.vhd:290:18 */
  always @*
    n236_ff_cnt_ch_e = n603; // (isignal)
  initial
    n236_ff_cnt_ch_e = 12'bX;
  /*# scc_wave2.vhd:307:34 */
  assign n244 = reg_freq_ch_a[11:3]; // extract
  /*# scc_wave2.vhd:307:48 */
  assign n246 = n244 == 9'b000000000;
  /*# scc_wave2.vhd:307:62 */
  assign n247 = n246 | ff_rst_ch_a;
  /*# scc_wave2.vhd:310:36 */
  assign n249 = n236_ff_cnt_ch_a == 12'b000000000000;
  /*# scc_wave2.vhd:311:48 */
  assign n251 = ff_ptr_ch_a + 5'b00001;
  /*# scc_wave2.vhd:314:48 */
  assign n253 = n236_ff_cnt_ch_a - 12'b000000000001;
  /*# scc_wave2.vhd:310:17 */
  assign n254 = n249 ? n251 : ff_ptr_ch_a;
  /*# scc_wave2.vhd:310:17 */
  assign n255 = n249 ? reg_freq_ch_a : n253;
  /*# scc_wave2.vhd:307:17 */
  assign n257 = n247 ? 5'b00000 : n254;
  /*# scc_wave2.vhd:307:17 */
  assign n258 = n247 ? reg_freq_ch_a : n255;
  /*# scc_wave2.vhd:317:34 */
  assign n259 = reg_freq_ch_b[11:3]; // extract
  /*# scc_wave2.vhd:317:48 */
  assign n261 = n259 == 9'b000000000;
  /*# scc_wave2.vhd:317:62 */
  assign n262 = n261 | ff_rst_ch_b;
  /*# scc_wave2.vhd:320:36 */
  assign n264 = n236_ff_cnt_ch_b == 12'b000000000000;
  /*# scc_wave2.vhd:321:48 */
  assign n266 = ff_ptr_ch_b + 5'b00001;
  /*# scc_wave2.vhd:324:48 */
  assign n268 = n236_ff_cnt_ch_b - 12'b000000000001;
  /*# scc_wave2.vhd:320:17 */
  assign n269 = n264 ? n266 : ff_ptr_ch_b;
  /*# scc_wave2.vhd:320:17 */
  assign n270 = n264 ? reg_freq_ch_b : n268;
  /*# scc_wave2.vhd:317:17 */
  assign n272 = n262 ? 5'b00000 : n269;
  /*# scc_wave2.vhd:317:17 */
  assign n273 = n262 ? reg_freq_ch_b : n270;
  /*# scc_wave2.vhd:327:34 */
  assign n274 = reg_freq_ch_c[11:3]; // extract
  /*# scc_wave2.vhd:327:48 */
  assign n276 = n274 == 9'b000000000;
  /*# scc_wave2.vhd:327:62 */
  assign n277 = n276 | ff_rst_ch_c;
  /*# scc_wave2.vhd:330:36 */
  assign n279 = n236_ff_cnt_ch_c == 12'b000000000000;
  /*# scc_wave2.vhd:331:48 */
  assign n281 = ff_ptr_ch_c + 5'b00001;
  /*# scc_wave2.vhd:334:48 */
  assign n283 = n236_ff_cnt_ch_c - 12'b000000000001;
  /*# scc_wave2.vhd:330:17 */
  assign n284 = n279 ? n281 : ff_ptr_ch_c;
  /*# scc_wave2.vhd:330:17 */
  assign n285 = n279 ? reg_freq_ch_c : n283;
  /*# scc_wave2.vhd:327:17 */
  assign n287 = n277 ? 5'b00000 : n284;
  /*# scc_wave2.vhd:327:17 */
  assign n288 = n277 ? reg_freq_ch_c : n285;
  /*# scc_wave2.vhd:337:34 */
  assign n289 = reg_freq_ch_d[11:3]; // extract
  /*# scc_wave2.vhd:337:48 */
  assign n291 = n289 == 9'b000000000;
  /*# scc_wave2.vhd:337:62 */
  assign n292 = n291 | ff_rst_ch_d;
  /*# scc_wave2.vhd:340:36 */
  assign n294 = n236_ff_cnt_ch_d == 12'b000000000000;
  /*# scc_wave2.vhd:341:48 */
  assign n296 = ff_ptr_ch_d + 5'b00001;
  /*# scc_wave2.vhd:344:48 */
  assign n298 = n236_ff_cnt_ch_d - 12'b000000000001;
  /*# scc_wave2.vhd:340:17 */
  assign n299 = n294 ? n296 : ff_ptr_ch_d;
  /*# scc_wave2.vhd:340:17 */
  assign n300 = n294 ? reg_freq_ch_d : n298;
  /*# scc_wave2.vhd:337:17 */
  assign n302 = n292 ? 5'b00000 : n299;
  /*# scc_wave2.vhd:337:17 */
  assign n303 = n292 ? reg_freq_ch_d : n300;
  /*# scc_wave2.vhd:347:34 */
  assign n304 = reg_freq_ch_e[11:3]; // extract
  /*# scc_wave2.vhd:347:48 */
  assign n306 = n304 == 9'b000000000;
  /*# scc_wave2.vhd:347:62 */
  assign n307 = n306 | ff_rst_ch_e;
  /*# scc_wave2.vhd:350:36 */
  assign n309 = n236_ff_cnt_ch_e == 12'b000000000000;
  /*# scc_wave2.vhd:351:48 */
  assign n311 = ff_ptr_ch_e + 5'b00001;
  /*# scc_wave2.vhd:354:48 */
  assign n313 = n236_ff_cnt_ch_e - 12'b000000000001;
  /*# scc_wave2.vhd:350:17 */
  assign n314 = n309 ? n311 : ff_ptr_ch_e;
  /*# scc_wave2.vhd:350:17 */
  assign n315 = n309 ? reg_freq_ch_e : n313;
  /*# scc_wave2.vhd:347:17 */
  assign n317 = n307 ? 5'b00000 : n314;
  /*# scc_wave2.vhd:347:17 */
  assign n318 = n307 ? reg_freq_ch_e : n315;
  /*# scc_wave2.vhd:364:41 */
  assign n360 = w_wave_ce ? adr : n365;
  /*# scc_wave2.vhd:365:24 */
  assign n362 = {3'b000, ff_ptr_ch_a};
  /*# scc_wave2.vhd:365:57 */
  assign n364 = ff_ch_num == 3'b000;
  /*# scc_wave2.vhd:364:66 */
  assign n365 = n364 ? n362 : n370;
  /*# scc_wave2.vhd:366:24 */
  assign n367 = {3'b001, ff_ptr_ch_b};
  /*# scc_wave2.vhd:366:57 */
  assign n369 = ff_ch_num == 3'b001;
  /*# scc_wave2.vhd:365:66 */
  assign n370 = n369 ? n367 : n375;
  /*# scc_wave2.vhd:367:24 */
  assign n372 = {3'b010, ff_ptr_ch_c};
  /*# scc_wave2.vhd:367:57 */
  assign n374 = ff_ch_num == 3'b010;
  /*# scc_wave2.vhd:366:66 */
  assign n375 = n374 ? n372 : n380;
  /*# scc_wave2.vhd:368:24 */
  assign n377 = {3'b011, ff_ptr_ch_d};
  /*# scc_wave2.vhd:368:57 */
  assign n379 = ff_ch_num == 3'b011;
  /*# scc_wave2.vhd:367:66 */
  assign n380 = n379 ? n377 : n383;
  /*# scc_wave2.vhd:369:24 */
  assign n382 = {3'b100, ff_ptr_ch_e};
  /*# scc_wave2.vhd:368:66 */
  assign n383 = sccplus ? n382 : n385;
  /*# scc_wave2.vhd:370:24 */
  assign n385 = {3'b011, ff_ptr_ch_e};
  /*# scc_wave2.vhd:372:5 */
  ram_Brtl wavemem (
    .adr(w_wave_adr),
    .clk(clk21m),
    .we(w_wave_we),
    .dbo(dbo),
    .dbi(wavemem_n386));
  /*# scc_wave2.vhd:416:17 */
  assign n415 = ff_ch_num_dl == 3'b001;
  /*# scc_wave2.vhd:417:17 */
  assign n418 = ff_ch_num_dl == 3'b010;
  /*# scc_wave2.vhd:418:17 */
  assign n421 = ff_ch_num_dl == 3'b011;
  /*# scc_wave2.vhd:419:17 */
  assign n424 = ff_ch_num_dl == 3'b100;
  /*# scc_wave2.vhd:420:17 */
  assign n427 = ff_ch_num_dl == 3'b101;
  /*# scc_wave2.vhd:415:5 */
  assign n429 = {n427, n424, n421, n418, n415};
  /*# scc_wave2.vhd:415:5 */
  always @*
    case (n429)
      5'b10000: n430 = 5'b10000;
      5'b01000: n430 = 5'b01000;
      5'b00100: n430 = 5'b00100;
      5'b00010: n430 = 5'b00010;
      5'b00001: n430 = 5'b00001;
      default: n430 = 5'b00000;
    endcase
  /*# scc_wave2.vhd:423:30 */
  assign n431 = w_ch_dec[0]; // extract
  /*# scc_wave2.vhd:423:48 */
  assign n432 = reg_ch_sel[0]; // extract
  /*# scc_wave2.vhd:423:34 */
  assign n433 = n431 & n432;
  /*# scc_wave2.vhd:424:30 */
  assign n434 = w_ch_dec[1]; // extract
  /*# scc_wave2.vhd:424:48 */
  assign n435 = reg_ch_sel[1]; // extract
  /*# scc_wave2.vhd:424:34 */
  assign n436 = n434 & n435;
  /*# scc_wave2.vhd:423:53 */
  assign n437 = n433 | n436;
  /*# scc_wave2.vhd:425:30 */
  assign n438 = w_ch_dec[2]; // extract
  /*# scc_wave2.vhd:425:48 */
  assign n439 = reg_ch_sel[2]; // extract
  /*# scc_wave2.vhd:425:34 */
  assign n440 = n438 & n439;
  /*# scc_wave2.vhd:424:53 */
  assign n441 = n437 | n440;
  /*# scc_wave2.vhd:426:30 */
  assign n442 = w_ch_dec[3]; // extract
  /*# scc_wave2.vhd:426:48 */
  assign n443 = reg_ch_sel[3]; // extract
  /*# scc_wave2.vhd:426:34 */
  assign n444 = n442 & n443;
  /*# scc_wave2.vhd:425:53 */
  assign n445 = n441 | n444;
  /*# scc_wave2.vhd:427:30 */
  assign n446 = w_ch_dec[4]; // extract
  /*# scc_wave2.vhd:427:48 */
  assign n447 = reg_ch_sel[4]; // extract
  /*# scc_wave2.vhd:427:34 */
  assign n448 = n446 & n447;
  /*# scc_wave2.vhd:426:53 */
  assign n449 = n445 | n448;
  /*# scc_wave2.vhd:429:21 */
  assign n450 = {w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit, w_ch_bit};
  /*# scc_wave2.vhd:432:29 */
  assign n452 = ff_ch_num_dl == 3'b001;
  /*# scc_wave2.vhd:433:29 */
  assign n454 = ff_ch_num_dl == 3'b010;
  /*# scc_wave2.vhd:434:29 */
  assign n456 = ff_ch_num_dl == 3'b011;
  /*# scc_wave2.vhd:435:29 */
  assign n458 = ff_ch_num_dl == 3'b100;
  /*# scc_wave2.vhd:436:29 */
  assign n460 = ff_ch_num_dl == 3'b101;
  /*# scc_wave2.vhd:431:5 */
  assign n462 = {n460, n458, n456, n454, n452};
  /*# scc_wave2.vhd:431:5 */
  always @*
    case (n462)
      5'b10000: n463 = reg_vol_ch_e;
      5'b01000: n463 = reg_vol_ch_d;
      5'b00100: n463 = reg_vol_ch_c;
      5'b00010: n463 = reg_vol_ch_b;
      5'b00001: n463 = reg_vol_ch_a;
      default: n463 = 4'b0000;
    endcase
  /*# scc_wave2.vhd:439:28 */
  assign n464 = w_ch_mask & ff_wave_dat;
  /*# scc_wave2.vhd:449:48 */
  assign n466 = {1'b0, w_ch_vol};
  /*# scc_wave2.vhd:449:35 */
  assign n467 = {{5{w_wave[7]}}, w_wave}; // sext
  /*# scc_wave2.vhd:449:35 */
  assign n468 = {{8{n466[4]}}, n466}; // sext
  /*# scc_wave2.vhd:449:35 */
  assign n469 = $signed(n467) * $signed(n468); // smul
  /*# scc_wave2.vhd:450:44 */
  assign n470 = w_mul_s[11:0]; // extract
  /*# scc_wave2.vhd:493:28 */
  assign n474 = ~ff_wave_ce;
  /*# scc_wave2.vhd:494:31 */
  assign n476 = ff_ch_num == 3'b101;
  /*# scc_wave2.vhd:497:44 */
  assign n478 = ff_ch_num + 3'b001;
  /*# scc_wave2.vhd:494:17 */
  assign n480 = n476 ? 3'b000 : n478;
  /*# scc_wave2.vhd:509:31 */
  assign n489 = ~ff_wave_ce_dl;
  /*# scc_wave2.vhd:510:34 */
  assign n491 = ff_ch_num_dl == 3'b000;
  /*# scc_wave2.vhd:513:39 */
  assign n492 = w_mul[11]; // extract
  /*# scc_wave2.vhd:513:51 */
  assign n493 = w_mul[11]; // extract
  /*# scc_wave2.vhd:513:44 */
  assign n494 = {n492, n493};
  /*# scc_wave2.vhd:513:63 */
  assign n495 = w_mul[11]; // extract
  /*# scc_wave2.vhd:513:56 */
  assign n496 = {n494, n495};
  /*# scc_wave2.vhd:513:68 */
  assign n497 = {n496, w_mul};
  /*# scc_wave2.vhd:513:77 */
  assign n498 = n497 + ff_mix;
  /*# scc_wave2.vhd:510:17 */
  assign n500 = n491 ? 15'b000000000000000 : n498;
  /*# scc_wave2.vhd:539:30 */
  assign n510 = ff_ch_num_dl == 3'b000;
  /*# scc_wave2.vhd:541:36 */
  assign n511 = ~ff_wavlatch_tgl;
  /*# scc_wave2.vhd:546:28 */
  assign n513 = ff_mix != 15'b000000000000000;
  /*# scc_wave2.vhd:546:17 */
  assign n516 = n513 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:560:40 */
  assign n532 = ff_wave != 15'b000000000000000;
  /*# scc_wave2.vhd:560:25 */
  assign n533 = n532 ? 1'b1 : 1'b0;
  /*# scc_wave2.vhd:386:9 */
  assign n538 = ff_wave_ce ? ram_dbi : n539;
  /*# scc_wave2.vhd:386:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n539 <= 8'b11111111;
    else
      n539 <= n538;
  /*# scc_wave2.vhd:213:9 */
  assign n540 = n28 ? n123 : reg_freq_ch_a;
  /*# scc_wave2.vhd:213:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n541 <= 12'b000000000000;
    else
      n541 <= n540;
  /*# scc_wave2.vhd:213:9 */
  assign n542 = n28 ? n125 : reg_freq_ch_b;
  /*# scc_wave2.vhd:213:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n543 <= 12'b000000000000;
    else
      n543 <= n542;
  /*# scc_wave2.vhd:213:9 */
  assign n544 = n28 ? n127 : reg_freq_ch_c;
  /*# scc_wave2.vhd:213:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n545 <= 12'b000000000000;
    else
      n545 <= n544;
  /*# scc_wave2.vhd:213:9 */
  assign n546 = n28 ? n129 : reg_freq_ch_d;
  /*# scc_wave2.vhd:213:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n547 <= 12'b000000000000;
    else
      n547 <= n546;
  /*# scc_wave2.vhd:213:9 */
  assign n548 = n28 ? n131 : reg_freq_ch_e;
  /*# scc_wave2.vhd:213:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n549 <= 12'b000000000000;
    else
      n549 <= n548;
  /*# scc_wave2.vhd:213:9 */
  assign n550 = n28 ? n102 : reg_vol_ch_a;
  /*# scc_wave2.vhd:213:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n551 <= 4'b0000;
    else
      n551 <= n550;
  /*# scc_wave2.vhd:213:9 */
  assign n552 = n28 ? n103 : reg_vol_ch_b;
  /*# scc_wave2.vhd:213:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n553 <= 4'b0000;
    else
      n553 <= n552;
  /*# scc_wave2.vhd:213:9 */
  assign n554 = n28 ? n104 : reg_vol_ch_c;
  /*# scc_wave2.vhd:213:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n555 <= 4'b0000;
    else
      n555 <= n554;
  /*# scc_wave2.vhd:213:9 */
  assign n556 = n28 ? n105 : reg_vol_ch_d;
  /*# scc_wave2.vhd:213:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n557 <= 4'b0000;
    else
      n557 <= n556;
  /*# scc_wave2.vhd:213:9 */
  assign n558 = n28 ? n106 : reg_vol_ch_e;
  /*# scc_wave2.vhd:213:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n559 <= 4'b0000;
    else
      n559 <= n558;
  /*# scc_wave2.vhd:213:9 */
  assign n560 = n28 ? n107 : reg_ch_sel;
  /*# scc_wave2.vhd:213:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n561 <= 5'b00000;
    else
      n561 <= n560;
  /*# scc_wave2.vhd:213:9 */
  assign n562 = n148 ? dbo : reg_mode_sel;
  /*# scc_wave2.vhd:213:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n563 <= 8'b00000000;
    else
      n563 <= n562;
  /*# scc_wave2.vhd:213:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n564 <= 1'b0;
    else
      n564 <= n139;
  /*# scc_wave2.vhd:213:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n565 <= 1'b0;
    else
      n565 <= n140;
  /*# scc_wave2.vhd:213:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n566 <= 1'b0;
    else
      n566 <= n141;
  /*# scc_wave2.vhd:213:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n567 <= 1'b0;
    else
      n567 <= n142;
  /*# scc_wave2.vhd:213:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n568 <= 1'b0;
    else
      n568 <= n143;
  /*# scc_wave2.vhd:304:9 */
  assign n569 = clkena ? n257 : ff_ptr_ch_a;
  /*# scc_wave2.vhd:304:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n570 <= 5'b00000;
    else
      n570 <= n569;
  /*# scc_wave2.vhd:304:9 */
  assign n571 = clkena ? n272 : ff_ptr_ch_b;
  /*# scc_wave2.vhd:304:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n572 <= 5'b00000;
    else
      n572 <= n571;
  /*# scc_wave2.vhd:304:9 */
  assign n573 = clkena ? n287 : ff_ptr_ch_c;
  /*# scc_wave2.vhd:304:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n574 <= 5'b00000;
    else
      n574 <= n573;
  /*# scc_wave2.vhd:304:9 */
  assign n575 = clkena ? n302 : ff_ptr_ch_d;
  /*# scc_wave2.vhd:304:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n576 <= 5'b00000;
    else
      n576 <= n575;
  /*# scc_wave2.vhd:304:9 */
  assign n577 = clkena ? n317 : ff_ptr_ch_e;
  /*# scc_wave2.vhd:304:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n578 <= 5'b00000;
    else
      n578 <= n577;
  /*# scc_wave2.vhd:492:9 */
  assign n579 = n474 ? n480 : ff_ch_num;
  /*# scc_wave2.vhd:492:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n580 <= 3'b000;
    else
      n580 <= n579;
  /*# scc_wave2.vhd:404:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n581 <= 3'b000;
    else
      n581 <= ff_ch_num;
  /*# scc_wave2.vhd:508:9 */
  assign n582 = n489 ? n500 : ff_mix;
  /*# scc_wave2.vhd:508:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n583 <= 15'b000000000000000;
    else
      n583 <= n582;
  /*# scc_wave2.vhd:404:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n584 <= 1'b0;
    else
      n584 <= w_wave_ce;
  /*# scc_wave2.vhd:404:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n585 <= 1'b0;
    else
      n585 <= ff_wave_ce;
  /*# scc_wave2.vhd:213:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n586 <= 1'b0;
    else
      n586 <= req;
  /*# scc_wave2.vhd:404:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n587 <= 8'b00000000;
    else
      n587 <= ram_dbi;
  /*# scc_wave2.vhd:538:9 */
  assign n588 = n510 ? ff_mix : ff_wave;
  /*# scc_wave2.vhd:538:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n589 <= 15'b000000000000000;
    else
      n589 <= n588;
  /*# scc_wave2.vhd:538:9 */
  assign n590 = n510 ? n511 : ff_wavlatch_tgl;
  /*# scc_wave2.vhd:538:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n591 <= 1'b0;
    else
      n591 <= n590;
  /*# scc_wave2.vhd:538:9 */
  assign n592 = n510 ? n516 : ff_capnz;
  /*# scc_wave2.vhd:538:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n593 <= 1'b0;
    else
      n593 <= n592;
  /*# scc_wave2.vhd:304:9 */
  assign n594 = clkena ? n258 : n236_ff_cnt_ch_a;
  /*# scc_wave2.vhd:304:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n595 <= 12'b000000000000;
    else
      n595 <= n594;
  /*# scc_wave2.vhd:304:9 */
  assign n596 = clkena ? n273 : n236_ff_cnt_ch_b;
  /*# scc_wave2.vhd:304:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n597 <= 12'b000000000000;
    else
      n597 <= n596;
  /*# scc_wave2.vhd:304:9 */
  assign n598 = clkena ? n288 : n236_ff_cnt_ch_c;
  /*# scc_wave2.vhd:304:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n599 <= 12'b000000000000;
    else
      n599 <= n598;
  /*# scc_wave2.vhd:304:9 */
  assign n600 = clkena ? n303 : n236_ff_cnt_ch_d;
  /*# scc_wave2.vhd:304:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n601 <= 12'b000000000000;
    else
      n601 <= n600;
  /*# scc_wave2.vhd:304:9 */
  assign n602 = clkena ? n318 : n236_ff_cnt_ch_e;
  /*# scc_wave2.vhd:304:9 */
  always @(posedge clk21m or posedge reset)
    if (reset)
      n603 <= 12'b000000000000;
    else
      n603 <= n602;
endmodule

