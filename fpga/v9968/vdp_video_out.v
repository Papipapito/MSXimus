//
//	vdp_video_out.v
//	 LCD 800x480 horizontal magnifier.
//
//	Copyright (C) 2025 Takayuki Hara.
//	All rights reserved.
//									   https://github.com/hra1129
//
//	本ソフトウェアおよび本ソフトウェアに基づいて作成された派生物は、以下の条件を
//	満たす場合に限り、再頒布および使用が許可されます。
//
//	1.ソースコード形式で再頒布する場合、上記の著作権表示、本条件一覧、および下記
//	  免責条項をそのままの形で保持すること。
//	2.バイナリ形式で再頒布する場合、頒布物に付属のドキュメント等の資料に、上記の
//	  著作権表示、本条件一覧、および下記免責条項を含めること。
//	3.書面による事前の許可なしに、本ソフトウェアを販売、および商業的な製品や活動
//	  に使用しないこと。
//
//	本ソフトウェアは、著作権者によって「現状のまま」提供されています。著作権者は、
//	特定目的への適合性の保証、商品性の保証、またそれに限定されない、いかなる明示
//	的もしくは暗黙な保証責任も負いません。著作権者は、事由のいかんを問わず、損害
//	発生の原因いかんを問わず、かつ責任の根拠が契約であるか厳格責任であるか（過失
//	その他の）不法行為であるかを問わず、仮にそのような損害が発生する可能性を知ら
//	されていたとしても、本ソフトウェアの使用によって発生した（代替品または代用サ
//	ービスの調達、使用の喪失、データの喪失、利益の喪失、業務の中断も含め、またそ
//	れに限定されない）直接損害、間接損害、偶発的な損害、特別損害、懲罰的損害、ま
//	たは結果損害について、一切責任を負わないものとします。
//
//	Note that above Japanese version license is the formal document.
//	The following translation is only for reference.
//
//	Redistribution and use of this software or any derivative works,
//	are permitted provided that the following conditions are met:
//
//	1. Redistributions of source code must retain the above copyright
//	   notice, this list of conditions and the following disclaimer.
//	2. Redistributions in binary form must reproduce the above
//	   copyright notice, this list of conditions and the following
//	   disclaimer in the documentation and/or other materials
//	   provided with the distribution.
//	3. Redistributions may not be sold, nor may they be used in a
//	   commercial product or activity without specific prior written
//	   permission.
//
//	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//	"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//	LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//	FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//	COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//	INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//	CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
//	LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
//	ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//	POSSIBILITY OF SUCH DAMAGE.
//
// -----------------------------------------------------------------------------

module vdp_video_out #(
	// MSXimus _143 CENTRADO: base de la muestra fuente donde arranca el
	// puntero de lectura del magnificador. El upscan escribe el contenido
	// (256 px MSX x2 = 512 muestras) en las direcciones content_start..+511,
	// donde content_start = c_left_pos - 2*(reg_display_adjust ^ 8) = 32 -
	// 2*(adj^8). Al adjust NEUTRO (reset del registro = adj=0) content_start
	// = 32-16 = 16. Arrancar la lectura en 0 leia borde + recortaba px por la
	// derecha. Arrancar en 16 lee las 512 muestras de CONTENIDO puro al adjust
	// neutro => 256 px completos, centrados, sin recorte; SET ADJUST desplaza
	// +-1px/paso (rango -7..+8). Solo cambia la DIRECCION base de lectura: no
	// toca h_en/hs/vs ni el span (sincronismo HDMI intacto).
	// Verificado en tb_center (adj=0) => histograma {3:256}, 0 borde.
	// [v2.0.1, bug del borde derecho en SCREEN1 — Albert 27/07] 16 -> 30: la
	// sonda del line buffer (_147, ORIGEN.txt) midio content_start = 30 muestras
	// en los modos de 256px (46 TEXT1 / 45 TEXT2); leer desde 16 regalaba 14
	// muestras (~7 px MSX) al borde IZQUIERDO y se comia el DERECHO. Con 30,
	// TEXT1 queda centrado exacto (16 muestras de borde por lado). SET ADJUST
	// (+-8) sigue montado encima sin cambios.
	// [v2.0.2 BORDES] 30 -> 28: con c_left_pos = 94 (vdp_upscan.v) el
	// contenido arranca en la muestra 92; leer desde 28 deja 64 muestras
	// (= 32 puntos MSX) de borde a la IZQUIERDA y, como la ventana ahora
	// mide 640 muestras, otras 64 a la DERECHA (28+639 = 667 = 92+511+64).
	parameter [9:0]	c_read_start = 10'd28,
	// MSXimus _143 PRIME: adelanta el arranque de la ventana ACTIVA (arranque
	// del puntero de lectura + reset del Bresenham) respecto a h_en_start (748)
	// para CEBAR la tuberia del magnificador (lat ~8 columnas) antes de que se
	// abra la ventana visible. Solo mueve el INICIO de la lectura; el final
	// (active_area_end) queda fijo en 2283 y hs/vs/display_en no se tocan.
	// 747-16 = 731 (ADV16, 8 columnas de prime) era el valor _143; _147 lo pasa
	// a 729 (ADV18, 9 columnas de prime) — ver abajo.
	//
	// MSXimus _147 FIX DE LA REGRESION DE TEXT2/SCREEN6/7 (menu "con otra
	// fuente" tras la _144).  Cadena de escalado: el magnificador reparte 512
	// muestras en 768 columnas nativas (2/3 => patron 2,1,2,1) y el escalador
	// HDMI (msx2hdmi_v9968) reparte esas 768 columnas en los 1280 px de la
	// pantalla (xx = floor(3*cx/5) => patron 2,2,1).  En los modos de DOS
	// muestras por pixel MSX (todos los de 256 px y TEXT1) el pixel ocupa
	// SIEMPRE 3 columnas nativas y 3 columnas nativas consecutivas suman
	// SIEMPRE 5 px de pantalla, sea cual sea su alineamiento => inmunes.
	// En los modos de UNA muestra por pixel (TEXT2 = SCREEN0 W80, SCREEN6,
	// SCREEN7) el pixel ocupa 1 o 2 columnas nativas y el reparto final
	// depende del residuo mod 3 de la columna nativa en la que empieza:
	//     residuo 0 -> 4,1 px  (CATASTROFICO: pixeles alternos x4)
	//     residuo 1 -> 3,2 px  (optimo: media 2,5)
	//     residuo 2 -> 3,2 px  (optimo)
	// Ese residuo lo fija que columna del core cae en el indice 0 del ring, y
	// eso depende de `ce86` (top.v), un TOGGLE LIBRE SIN RESET que muestrea el
	// core (1 pixel cada 2 ciclos): su fase respecto a h_count es arbitraria
	// (cambia con el arranque/PLL/placement) => con c_active_start=731 una de
	// las dos fases posibles cae en residuo 0 = la fuente rota.  Con 729 (una
	// columna mas de prime) las dos fases posibles caen en residuos 1 y 2 =>
	// TEXT2/SCREEN6/7 salen 3,2 SIEMPRE, sin depender de la fase del ce.
	// Coste: la ventana visible se desplaza UNA columna nativa (1,67 px de
	// pantalla, sub-pixel) y los modos de 256 px siguen dando {5:*} exactos.
	// Verificado en tools/v9968_sim/tb_geomfast.sv (barrido de
	// c_active_start x c_start_numerator x fase de captura) y en
	// tools/v9968_sim/tb_textgeom.sv (pila completa, ambas fases).
	parameter [11:0] c_active_start = 12'd729,
	// Fase inicial del acumulador Bresenham. NO es el lever del fix (con 64 se
	// invierte que fase del ce es la mala, no se arregla); se deja parametrizado
	// porque el barrido de _147 lo uso como segunda dimension. Dejar en 0.
	parameter [7:0]	c_start_numerator = 8'd0
)(
	input				clk,						//	42.95454MHz
	input				reset_n,
	input		[11:0]	h_count,
	input		[ 9:0]	v_count,
	input				has_scanline,
	input				field,
	// input pixel
	input		[7:0]	vdp_r,
	input		[7:0]	vdp_g,
	input		[7:0]	vdp_b,
	// output pixel
	output				display_hs,
	output				display_vs,
	output				display_en,
	output		[7:0]	display_r,
	output		[7:0]	display_g,
	output		[7:0]	display_b,
	// parameters
	input				reg_interlace_mode,
	input				reg_flat_interlace_mode,
	input		[7:0]	reg_denominator,			//	800 / 4
	input		[7:0]	reg_normalize,				//	8192 / reg_denominator
	input				reg_50hz_mode
);
	localparam		c_v_count_max_60	= 10'd523;
	localparam		c_v_count_max_50	= 10'd625;
	localparam		active_area_start	= c_active_start;
	// [v2.0.2 BORDES] ventana ACTIVA de 1280 clk = 640 columnas nativas
	// (antes 1536 clk = 768). Con el magnificador a 1 muestra/columna eso
	// son 640 muestras = 256 px de contenido + 32 puntos de borde por lado.
	localparam		c_h_active			= 12'd1280;
	localparam		active_area_end		= 12'd747 + c_h_active;	//	2027 (antes 2283)
	localparam		clocks_per_line		= 12'd2736;
	localparam		h_en_start			= 12'd748;
	localparam		h_en_end			= h_en_start + c_h_active;	//	2028 (antes 2284)
	localparam		hs_start			= clocks_per_line - 1;
	localparam		hs_end				= 12'd567;
	localparam		v_en_start			= 10'd14;
	localparam		v_en_end			= v_en_start + 10'd480;
	localparam		vs_start_60hz		= c_v_count_max_60 - 10'd13;
	localparam		vs_end_60hz			= c_v_count_max_60 - 10'd6;
	localparam		vs_start_50hz		= c_v_count_max_50 - 10'd13;
	localparam		vs_end_50hz			= c_v_count_max_50 - 10'd6;
	// [v2.0.2 BORDES] 128 -> 192 == reg_denominator: el magnificador pasa a
	// 1 muestra por columna (relacion 1:1, sin hold). Consecuencias:
	//   * ff_numerator queda clavado en 0 => ff_coeff = 0 => tap1 puro
	//     (nearest-neighbor trivial; los multiplicadores del bilineal se
	//     podan en sintesis).
	//   * un px MSX de 2 muestras = 2 columnas = 4 px de pantalla EXACTOS y
	//     un px de 1 muestra (TEXT2/SCREEN6/7) = 1 columna = 2 px EXACTOS,
	//     en LAS DOS fases de ce86 => desaparece la loteria que motivo el
	//     fix _147 (c_active_start 731->729 deja de ser critico).
	// OJO: debe seguir siendo igual a reg_denominator (vdp.v pasa 8'd192).
	localparam		c_numerator			= 192;

	wire			w_enable;
	wire	[9:0]	w_x_position_w;
	reg		[9:0]	ff_x_position_r;
	reg				ff_active;
	reg		[7:0]	ff_numerator;
	wire	[10:0]	w_next_numerator;
	wire	[11:0]	w_sub_numerator;
	wire			w_is_write_odd;
	wire	[7:0]	w_pixel_r;
	wire	[7:0]	w_pixel_g;
	wire	[7:0]	w_pixel_b;
	wire			w_hold;
	wire	[15:0]	w_normalized_numerator;
	reg		[7:0]	ff_coeff;
	reg		[7:0]	ff_coeff1;
	reg		[7:0]	ff_coeff2;
	reg		[7:0]	ff_tap0_r;
	reg		[7:0]	ff_tap0_g;
	reg		[7:0]	ff_tap0_b;
	reg		[7:0]	ff_tap1_r;
	reg		[7:0]	ff_tap1_g;
	reg		[7:0]	ff_tap1_b;
	wire	[7:0]	w_bilinear_r;
	wire	[7:0]	w_bilinear_g;
	wire	[7:0]	w_bilinear_b;
	wire	[9:0]	w_scanline_gain;
	wire	[7:0]	w_gain;
	reg		[7:0]	ff_bilinear_r;
	reg		[7:0]	ff_bilinear_g;
	reg		[7:0]	ff_bilinear_b;
	reg		[7:0]	ff_gain;
	wire	[15:0]	w_display_r;
	wire	[15:0]	w_display_g;
	wire	[15:0]	w_display_b;
	reg		[7:0]	ff_display_r;
	reg		[7:0]	ff_display_g;
	reg		[7:0]	ff_display_b;
	reg				ff_h_en;
	reg				ff_v_en;
	reg				ff_hs;
	reg				ff_vs;
	wire			w_interlace;

	assign w_interlace	= reg_interlace_mode | reg_flat_interlace_mode;

	// --------------------------------------------------------------------
	//	Active period
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_active <= 1'b0;
		end
		else if( h_count == active_area_end ) begin
			ff_active <= 1'b0;
		end
		else if( h_count == active_area_start ) begin
			ff_active <= 1'b1;
		end
		else begin
			//	hold
		end
	end

	// --------------------------------------------------------------------
	//	Synchronous signals
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_h_en <= 1'b0;
		end
		else if( h_count == h_en_end ) begin
			ff_h_en <= 1'b0;
		end
		else if( h_count == h_en_start ) begin
			ff_h_en <= 1'b1;
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_v_en <= 1'b0;
		end
		else if( h_count == (clocks_per_line - 1) ) begin
			if( v_count == v_en_end ) begin
				ff_v_en <= 1'b0;
			end
			else if( v_count == v_en_start ) begin
				ff_v_en <= 1'b1;
			end
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_hs <= 1'b1;
		end
		else if( h_count == hs_end ) begin
			ff_hs <= 1'b1;
		end
		else if( h_count == hs_start ) begin
			ff_hs <= 1'b0;
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_vs <= 1'b1;
		end
		else if( h_count == (clocks_per_line - 1) ) begin
			if( reg_50hz_mode == 1'b0 ) begin
				if( v_count == vs_end_60hz ) begin
					ff_vs <= 1'b1;
				end
				else if( v_count == vs_start_60hz ) begin
					ff_vs <= 1'b0;
				end
			end
			else begin
				if( v_count == vs_end_50hz ) begin
					ff_vs <= 1'b1;
				end
				else if( v_count == vs_start_50hz ) begin
					ff_vs <= 1'b0;
				end
			end
		end
	end

	assign display_hs	= ff_hs;
	assign display_vs	= ff_vs;

	// --------------------------------------------------------------------
	//	Buffer address
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_x_position_r <= c_read_start;
		end
		else if( h_count == active_area_start ) begin
			ff_x_position_r <= c_read_start;
		end
		else if( !w_enable ) begin
			//	hold
		end
		else if( ff_active ) begin
			if( w_hold ) begin
				//	hold
			end
			else begin
				ff_x_position_r <= ff_x_position_r + 10'd1;
			end
		end
		else begin
			//	hold
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_numerator <= c_start_numerator;
		end
		else if( h_count == active_area_start ) begin
			ff_numerator <= c_start_numerator;
		end
		else if( !w_enable ) begin
			//	hold
		end
		else if( ff_active ) begin
			if( w_hold ) begin
				ff_numerator <= w_next_numerator[7:0];
			end
			else begin
				ff_numerator <= w_sub_numerator[7:0];
			end
		end
	end

	assign w_next_numerator		= { 1'b0, ff_numerator } + c_numerator;
	assign w_sub_numerator		= w_next_numerator - { 1'b0, reg_denominator };
	assign w_enable				= h_count[0];
	assign w_hold				= w_sub_numerator[8];

	// --------------------------------------------------------------------
	//	Delay line memory
	// --------------------------------------------------------------------
	vdp_video_double_buffer u_double_buffer (
		.clk			( clk				),
		.x_position_w	( w_x_position_w	),
		.x_position_r	( ff_x_position_r	),
		.is_write_odd	( w_is_write_odd	),
		.re				( ff_active			),
		.wdata_r		( vdp_r				),
		.wdata_g		( vdp_g				),
		.wdata_b		( vdp_b				),
		.rdata_r		( w_pixel_r			),
		.rdata_g		( w_pixel_g			),
		.rdata_b		( w_pixel_b			)
	);

	assign w_x_position_w	= h_count[11:2];
	assign w_is_write_odd	= v_count[0];

	// --------------------------------------------------------------------
	//	Filter coefficient
	// --------------------------------------------------------------------
	assign w_normalized_numerator	= ff_numerator * reg_normalize;		//	8bit * 10bit = 16bit

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_coeff	<= 8'd0;
		end
		else if( w_enable ) begin
			// MSXimus _142 NEAREST-NEIGHBOR (fuentes nitidas, como el MSXnano
			// V9958): el magnificador "LCD" de HRA mezclaba (bilineal) los
			// pixeles MSX al estirarlos a 800 -> bordes difuminados, la "H"
			// con un palo mas fino. Redondeando el coeficiente fraccional al
			// pixel MAS CERCANO (0 = tap1 izq, 63 = tap0 dcha) se elige un
			// solo pixel sin mezcla => bordes nitidos. Original preservado
			// en el comentario para revertir facil.
			//	ff_coeff <= w_normalized_numerator[14:7];					//	0 ... 63 (bilineal HRA)
			//
			// MSXimus [BUG #19 del INFORME_NIQUELADO 2026-07-26] — VERIFICADO
			// INERTE DESDE LA v2.0.2. NO LO "ARREGLES" A CIEGAS.
			// El informe tiene razon en la ARITMETICA: este snap a 8'd63 NO
			// selecciona "un solo pixel", porque el datapath del bilineal pesa
			// coeff/256 (vdp_video_out_bilinear.v: ff_mul <= w_mul[17:7] y luego
			// ff_out <= w_add[8:1]), o sea 63/256 = 24,6% de mezcla; el snap "de
			// verdad" seria 8'd255 (99,6%, error <= 1 LSB). PERO desde el cambio
			// de bordes (commit 6d15c0b) esta linea NO HACE NADA, y ponerle
			// 8'd255 TAMPOCO haria nada:
			//   c_numerator == reg_denominator == 192 (magnificador 1:1) y
			//   c_start_numerator = 0  =>  w_sub_numerator = ff_numerator + 192
			//   - 192 = ff_numerator, con acarreo SIEMPRE 0 (w_hold = 0, no hay
			//   columnas repetidas)  =>  ff_numerator es un PUNTO FIJO, y se
			//   carga con 0 en el reset y en CADA linea (active_area_start)
			//   =>  w_normalized_numerator = 0  =>  ff_coeff == 0 SIEMPRE, con
			//   snap o sin el: el bilineal degenera en tap1 puro (pass-through).
			// MEDIDO, no razonado: banco tb_coeff19.sv (entregado con el informe
			// del bug #19, fuera del arbol), vdp_upscan + vdp_video_out REALES,
			// 4 familias de modo (256px / TEXT1 / TEXT2 / 512px) x 8 combos de
			// interlace/flat_interlace/50Hz/scanline x 80 lineas x las dos
			// paridades de h_count (las dos fases del ring ce86), con contenido
			// de frontera BINARIA 0x00/0xFF:
			//   ff_numerator {0:103840}, ff_coeff {0:103840} — UN SOLO valor —,
			//   ff_coeff2 (el que entra de verdad al bilineal) != 0 en CERO
			//   ciclos, y 102400 muestras de salida bilineal 100% binarias,
			//   0 mezcladas. En la pila COMPLETA (tb_textgeom del repo, vdp.v +
			//   shim) la imagen sale con DOS colores exactos — borde 000000ff /
			//   contenido 00ffffff — en los tres modos y en las dos fases del
			//   ring: SCREEN1 241 runs {2:239}, TEXT1 229 runs {2:227}, TEXT2
			//   469 runs {1:467} columnas nativas por pixel MSX. Ni un pixel
			//   intermedio en ninguno.
			// Control positivo del MISMO banco (para que no sea uno de esos
			// bancos verdes que no ejercitan nada): con c_start_numerator = 128
			// este mismo RTL da ff_coeff {63:103840} y 40960..81920 muestras
			// MEZCLADAS (la frontera 0x00/0xFF sale 63 = el 24,6% que denuncia
			// el informe) => el banco SI ve la mezcla cuando la hay.
			// EL BUG REVIVE si alguien: (a) vuelve a un magnificador fraccionario
			// (c_numerator != reg_denominator, p.ej. el 128 de antes de la
			// v2.0.2), (b) pone c_start_numerator >= 128 (con 0 y 64 el snap
			// sigue dando 0), o (c) cambia el 8'd192 que vdp.v cablea en
			// reg_denominator. SOLO ENTONCES tiene sentido tocar el 8'd63, y el
			// valor correcto entonces es 8'd255.
			// DATO EXTRA, y por que el arreglo tampoco habria hecho falta ANTES:
			// el mismo banco con el RTL de 6d15c0b^ (c_numerator = 128, cuando el
			// snap SI se ejecutaba) da coeff 63 en 41280 ciclos... y en NINGUNO
			// de ellos tap0 != tap1 (contador n_c2mix = 0 en las 4 familias de
			// modo) => mezcla real CERO. El motivo: con el snap, el 63 cae
			// siempre en la columna de HOLD del Bresenham, que es justo la que
			// repite muestra (tap0 == tap1). El control de al lado — el mismo
			// RTL con el coeficiente bilineal ORIGINAL de HRA — si pilla taps
			// distintos (36160/37440 ciclos en TEXT2 y SCREEN6/7) y ensucia
			// 36000..37280 muestras (ejemplo 234 sobre frontera 0xFF/0x00). O
			// sea: el _142 hacia lo que prometia y el artefacto que el informe
			// deducia ("1 de cada 3 fronteras con columna fantasma al 25%") no
			// llego a existir nunca. Se deja la linea TAL CUAL a proposito.
			ff_coeff	<= (w_normalized_numerator[14:7] >= 8'd32) ? 8'd63 : 8'd0;
		end
	end

	// --------------------------------------------------------------------
	//	Bilinear interpolation
	// --------------------------------------------------------------------
	vdp_video_out_bilinear u_bilinear_r (
		.clk			( clk					),
		.enable			( w_enable				),
		.coeff			( ff_coeff2				),
		.tap0			( ff_tap0_r				),
		.tap1			( ff_tap1_r				),
		.pixel_out		( w_bilinear_r			)
	);

	vdp_video_out_bilinear u_bilinear_g (
		.clk			( clk					),
		.enable			( w_enable				),
		.coeff			( ff_coeff2				),
		.tap0			( ff_tap0_g				),
		.tap1			( ff_tap1_g				),
		.pixel_out		( w_bilinear_g			)
	);

	vdp_video_out_bilinear u_bilinear_b (
		.clk			( clk					),
		.enable			( w_enable				),
		.coeff			( ff_coeff2				),
		.tap0			( ff_tap0_b				),
		.tap1			( ff_tap1_b				),
		.pixel_out		( w_bilinear_b			)
	);

	// --------------------------------------------------------------------
	//	Scanline
	// --------------------------------------------------------------------
	assign w_scanline_gain	= { 2'd0, w_bilinear_r } + { 2'd0, w_bilinear_g } + { 2'd0, w_bilinear_b } + { 10'd128 };
	assign w_gain			= (has_scanline == 1'b0  ) ? 8'd128:
							  (w_interlace           ) ? ( (v_count[0] == ~field) ? 8'd128: 8'd0 ):
							  (v_count[0]   == 1'b1  ) ? 8'd128: { 1'b0, w_scanline_gain[9:3] };

	assign w_display_r	= ff_bilinear_r * ff_gain;
	assign w_display_g	= ff_bilinear_g * ff_gain;
	assign w_display_b	= ff_bilinear_b * ff_gain;

	always @( posedge clk ) begin
		if( w_enable ) begin
			ff_coeff1		<= ff_coeff;
			ff_coeff2		<= ff_coeff1;
			ff_tap0_r		<= w_pixel_r;
			ff_tap0_g		<= w_pixel_g;
			ff_tap0_b		<= w_pixel_b;
			ff_tap1_r		<= ff_tap0_r;
			ff_tap1_g		<= ff_tap0_g;
			ff_tap1_b		<= ff_tap0_b;
			ff_bilinear_r	<= w_bilinear_r;
			ff_bilinear_g	<= w_bilinear_g;
			ff_bilinear_b	<= w_bilinear_b;
			ff_gain			<= w_gain;
			ff_display_r	<= w_display_r[14:7];
			ff_display_g	<= w_display_g[14:7];
			ff_display_b	<= w_display_b[14:7];
		end
	end

	assign w_display_en	= ff_h_en & ff_v_en;
	assign display_r	= w_display_en ? ff_display_r : 8'd0;
	assign display_g	= w_display_en ? ff_display_g : 8'd0;
	assign display_b	= w_display_en ? ff_display_b : 8'd0;
	assign display_en	= w_display_en;
endmodule
