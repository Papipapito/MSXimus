//
//	vdp_timing_control_ssg.v
//	Synchronous Signal Generator for Timing Control
//
//	Copyright (C) 2025 Takayuki Hara
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
//-----------------------------------------------------------------------------

module vdp_timing_control_ssg (
	input				reset_n,
	input				clk,					//	85.90908MHz

	output		[11:0]	h_count,
	output		[ 9:0]	v_count,

	output		[13:0]	screen_pos_x,			//	signed   (Coordinates not affected by scroll register)
	output		[13:0]	screen_pos_x_clone,		//	MSXimus: sin scroll (para timing_control)
	output		[13:0]	screen_pos_x_sprite,	//	MSXimus _120: con la resta del scroll YA hecha (para u_sprite)
	output		[ 9:0]	screen_pos_y,			//	signed   (Coordinates not affected by scroll register)
	output		[ 8:0]	pixel_pos_x,			//	unsigned (Coordinates affected by scroll register)
	output		[ 7:0]	pixel_pos_y,			//	unsigned (Coordinates affected by scroll register)
	output				screen_v_active,

	output				intr_line,				//	pulse
	output				intr_frame,				//	pulse
	output				clear_line_interrupt,	//	pulse
	output				pre_vram_refresh,

	input				reg_display_on,
	input				reg_50hz_mode,
	input				reg_212lines_mode,
	input				reg_interlace_mode,
	input		[7:0]	reg_display_adjust,
	input		[7:0]	reg_interrupt_line,
	input		[7:0]	reg_vertical_offset,
	input		[2:0]	reg_horizontal_offset_l,
	input		[8:3]	reg_horizontal_offset_h,
	input				reg_interleaving_mode,
	input				reg_flat_interlace_mode,
	input		[7:0]	reg_blink_period,
	input				reg_interrupt_line_nonR23_mode,
	output		[2:0]	horizontal_offset_l,
	output		[8:3]	horizontal_offset_h,
	output				interleaving_page,
	output				blink,
	output				status_field,
	output				status_hsync,
	output				status_vsync
);
	localparam			c_left_pos				= 13'd640;		//	16の倍数
	localparam			c_hsync_start			= 13'd4864;
	localparam			c_hsync_end				= 13'd540;
						//						  Sync  top erase NTSC/PAL 192/212
	localparam			c_top_60hz_pos192		= 10'd3 + 10'd13 + 10'd9  + 10'd10;	//	画面上の垂直位置(192 lines mode)。小さくすると上へ、大きくすると下へ寄る。
	localparam			c_top_60hz_pos212		= 10'd3 + 10'd13 + 10'd9  + 10'd0;	//	画面上の垂直位置(212 lines mode)。小さくすると上へ、大きくすると下へ寄る。
	localparam			c_top_50hz_pos192		= 10'd3 + 10'd13 + 10'd36 + 10'd10;	//	画面上の垂直位置(192 lines mode)。小さくすると上へ、大きくすると下へ寄る。
	localparam			c_top_50hz_pos212		= 10'd3 + 10'd13 + 10'd36 + 10'd0;	//	画面上の垂直位置(212 lines mode)。小さくすると上へ、大きくすると下へ寄る。
	localparam			c_h_count_max			= 12'd2735;
	localparam			c_v_count_max_60		= 10'd523;
	localparam			c_v_count_max_50		= 10'd625;
	localparam			c_intr_line_timing		= 13'd4864;
	localparam			c_intr_frame_timing192	= 10'd191;
	localparam			c_intr_frame_timing212	= 10'd211;
	reg			[11:0]	ff_h_count;
	reg			[12:0]	ff_half_count;
	reg			[ 9:0]	ff_v_count;					/* synthesis syn_preserve = 1 */
	reg			[ 9:0]	ff_v_count_clone;			/* synthesis syn_preserve = 1 */
	reg					ff_line_interrupt_mask;
	wire				w_h_count_end;
	wire				w_v_count_end;
	wire		[9:0]	w_v_count_end_line;
	wire		[13:0]	w_screen_pos_x;
	wire		[ 9:0]	w_screen_pos_y;
	wire		[ 9:0]	w_pixel_pos_x;
	wire		[ 7:0]	w_pixel_pos_y;
	reg			[13:0]	ff_screen_pos_x;			/* synthesis syn_preserve = 1 */
	reg			[13:0]	ff_screen_pos_x_clone;		/* synthesis syn_preserve = 1 */
	reg			[13:0]	ff_screen_pos_x_sprite;		/* synthesis syn_preserve = 1 syn_maxfan = 8 */	// _127B: familia reincidente (3/5 dados)
	reg			[ 9:0]	ff_screen_pos_y;
	reg			[ 8:0]	ff_pixel_pos_x;
	reg			[ 7:0]	ff_pixel_pos_y;
	wire		[ 7:0]	w_intr_line_y;
	reg					ff_v_active;
	wire				w_intr_line_timing;
	wire				w_intr_frame_timing;
	reg			[2:0]	ff_horizontal_offset_l;
	reg			[8:3]	ff_horizontal_offset_h;
	reg					ff_vram_refresh;
	reg			[3:0]	ff_blink_counter;
	reg			[3:0]	ff_blink_base;				//	10 frame counter
	wire				w_10frame;
	reg					ff_interleaving_page;
	reg					ff_field;
	wire		[3:0]	w_next_blink_counter;
	reg			[9:0]	ff_top_line;
	wire				w_half_line_shift;
	reg					ff_hsync;
	reg					ff_vsync;
	reg					ff_clear_line_interrupt;
	wire		[2:0]	w_horizontal_offset_l_next;		//	MSXimus _162: proximo valor del latch de R#27[2:0]

	assign w_half_line_shift	= ff_field & (reg_interlace_mode | reg_flat_interlace_mode);

	// --------------------------------------------------------------------
	//	Latch horizontal scroll register
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_horizontal_offset_l <= 3'd0;
			ff_horizontal_offset_h <= 6'd0;
		end
		else if( ff_v_count[0] && w_h_count_end ) begin
			ff_horizontal_offset_l <= reg_horizontal_offset_l;
			ff_horizontal_offset_h <= reg_horizontal_offset_h;
		end
	end

	assign horizontal_offset_l	= ff_horizontal_offset_l;
	assign horizontal_offset_h	= ff_horizontal_offset_h;

	//	MSXimus _162 (CORRECCION del _120): funcion de proximo estado del latch
	//	de arriba, replicada TERMINO A TERMINO (misma condicion de captura, misma
	//	rama de reset). Es lo que hay que restarle a la coordenada de sprites en
	//	el _120: como esa resta esta ANTES de un registro, el valor correcto no es
	//	el R#27 VIVO (reg_horizontal_offset_l) sino el que ff_horizontal_offset_l
	//	tendra EN EL MISMO FLANCO en el que se registra la resta. PORQUE: R#27 se
	//	latchea una sola vez por PAR de lineas (ff_v_count[0] && w_h_count_end);
	//	usando el valor vivo, un split de R#27 por interrupcion de linea llegaba
	//	a los SPRITES hasta ~2 lineas antes que al FONDO (desalineacion de 1..7 px
	//	y posible desencuadre de la coleccion de sprites de una linea).
	//	_162 (forma exacta que el verificador probo en verde, 0 desajustes):
	//	con `reset_n &&` el mux devuelve el valor VIEJO del latch mientras el
	//	reset esta aserto (1 ciclo de divergencia frente al upstream); con la
	//	rama explicita a 0 la equivalencia es bit-exacta TAMBIEN en el reset,
	//	que es justo lo que este parche viene a poder afirmar sin mentir.
	assign w_horizontal_offset_l_next	= ( !reset_n ) ? 3'd0 :
	                                      ( ff_v_count[0] && w_h_count_end ) ? reg_horizontal_offset_l: ff_horizontal_offset_l;

	// --------------------------------------------------------------------
	//	Horizontal Counter
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_h_count <= 12'd0;
		end
		else if( w_h_count_end ) begin
			ff_h_count <= 12'd0;
		end
		else begin
			ff_h_count <= ff_h_count + 12'd1;
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_half_count <= 13'd0;
		end
		else if( (ff_v_count[0] == 1'b1) && w_h_count_end ) begin
			ff_half_count <= 13'd0;
		end
		else begin
			ff_half_count <= ff_half_count + 13'd1;
		end
	end

	assign w_h_count_end	= ( ff_h_count == c_h_count_max );

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_hsync <= 1'b1;
		end
		else if( ff_half_count == (c_hsync_end - 13'd1) ) begin
			ff_hsync <= 1'b0;
		end
		else if( ff_half_count == (c_hsync_start - 13'd1) ) begin
			ff_hsync <= 1'b1;
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_vram_refresh <= 1'b0;
		end
		else if( ff_half_count == { 10'd48, 3'd0 } ) begin
			ff_vram_refresh <= 1'b1;
		end
		else begin
			ff_vram_refresh <= 1'b0;
		end
	end

	assign pre_vram_refresh		= ff_vram_refresh;

	// --------------------------------------------------------------------
	//	Vertical Counter
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_v_count			<= 10'd0;
			ff_v_count_clone	<= 10'd0;
		end
		else if( w_h_count_end ) begin
			if( w_v_count_end ) begin
				ff_v_count			<= 10'd0;
				ff_v_count_clone	<= 10'd0;
			end
			else begin
				ff_v_count			<= ff_v_count + 10'd1;
				ff_v_count_clone	<= ff_v_count_clone + 10'd1;
			end
		end
	end

	assign w_v_count_end	= ( !reg_50hz_mode && ff_v_count == c_v_count_max_60 ) ||
							  (  reg_50hz_mode && ff_v_count == c_v_count_max_50 );

	always @( posedge clk ) begin
		ff_clear_line_interrupt <= w_intr_frame_timing;
	end

	assign clear_line_interrupt	= ff_clear_line_interrupt;

	// --------------------------------------------------------------------
	//	Field selector
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_field <= 1'b0;
		end
		else if( w_h_count_end && w_v_count_end ) begin
			ff_field <= ~ff_field;
		end
	end

	// --------------------------------------------------------------------
	//	Active area
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_v_active <= 1'b0;
		end
		else if( w_h_count_end ) begin
			if( ff_v_count[0] == 1'b1 && w_screen_pos_y == 10'h3FF ) begin
				ff_v_active <= 1'b1;
			end
			else if( ff_v_count[0] == 1'b1 && (w_screen_pos_y == w_v_count_end_line) ) begin
				ff_v_active <= 1'b0;
			end
		end
	end

	assign w_v_count_end_line	= reg_212lines_mode ? 10'd211: 10'd191;

	//	upstream eebc87f ("Bugfix VR bit on S#2"): el VR subia al FINAL de la
	//	linea 211/191 (~56 us DESPUES del intr_frame) y la MSX Diagnostics
	//	Cartridge detectaba un TMS9918. Ahora sube en el MISMO evento
	//	w_intr_frame_timing; el clear pasa de 3FE a 3FF (fin de la linea -1).
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_vsync <= 1'b1;
		end
		else if( w_intr_frame_timing ) begin
			ff_vsync <= 1'b1;
		end
		else if( w_h_count_end ) begin
			if( ff_v_count[0] == 1'b1 && w_screen_pos_y == 10'h3FF ) begin
				ff_vsync <= 1'b0;
			end
			else if( w_v_count_end ) begin
				ff_vsync <= 1'b1;
			end
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_top_line <= c_top_60hz_pos192;
		end
		else if( reg_212lines_mode ) begin
			if( reg_50hz_mode ) begin
				ff_top_line <= c_top_50hz_pos212;
			end
			else begin
				ff_top_line <= c_top_60hz_pos212;
			end
		end
		else begin
			if( reg_50hz_mode ) begin
				ff_top_line <= c_top_50hz_pos192;
			end
			else begin
				ff_top_line <= c_top_60hz_pos192;
			end
		end
	end

	assign w_screen_pos_x		= { 1'b0, ff_half_count   } - c_left_pos;
	assign w_screen_pos_y		= { 1'b0, ff_v_count_clone[9:1] } - ff_top_line + { 6'd0, ~reg_display_adjust[7], reg_display_adjust[6:4] };

	assign w_pixel_pos_x		= w_screen_pos_x[12:4] + { ff_horizontal_offset_h, 3'd0 };
	assign w_pixel_pos_y		= w_screen_pos_y[ 7:0] + reg_vertical_offset;

	// --------------------------------------------------------------------
	//	line interrupt
	// --------------------------------------------------------------------
	assign w_intr_line_y		= reg_interrupt_line_nonR23_mode ? w_screen_pos_y[7:0]: w_pixel_pos_y;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_line_interrupt_mask <= 1'b0;
		end
		else if( ff_v_count[0] && w_h_count_end ) begin
			if( w_screen_pos_y == 10'h3FF ) begin
				ff_line_interrupt_mask <= 1'b1;
			end
			else if( w_screen_pos_y == 10'd234 ) begin
				ff_line_interrupt_mask <= 1'b0;
			end
		end
	end

	// --------------------------------------------------------------------
	//	blink counter
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_blink_base <= 4'd0;
		end
		else if( w_h_count_end && w_v_count_end ) begin
			if( w_10frame ) begin
				ff_blink_base <= 4'd0;
			end
			else begin
				ff_blink_base <= ff_blink_base + 4'd1;
			end
		end
	end

	//	upstream 4148742: tick del blink cada 5 frames (no 10). Interactua con
	//	el off-by-one de la recarga de ff_blink_counter (la recarga se come un
	//	tic): cada fase dura (N+1) tics. Con 4'd4, R#13=0x11 da fases de 10
	//	frames EXACTOS (= datasheet 166,9 ms/unidad y openMSX); con el 4'd9
	//	anterior daban 20 (mitad de velocidad). Medido en tb_ssgblink.
	assign w_10frame			= (ff_blink_base == 4'd4);
	assign w_next_blink_counter	= ff_interleaving_page ? reg_blink_period[7:4]: reg_blink_period[3:0];

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_blink_counter <= 4'd0;
		end
		else if( reg_blink_period == 8'd0 ) begin
			ff_blink_counter <= 4'd0;
		end
		else if( w_10frame && w_h_count_end && w_v_count_end ) begin
			if( ff_blink_counter == 4'd0 ) begin
				ff_blink_counter <= w_next_blink_counter;
			end
			else begin
				ff_blink_counter <= ff_blink_counter - 4'd1;
			end
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_interleaving_page <= 1'b1;
		end
		else if( reg_blink_period == 8'd0 ) begin
			ff_interleaving_page <= 1'b1;
		end
		else if( w_10frame && w_h_count_end && w_v_count_end ) begin
			if( ff_blink_counter == 4'd0 ) begin
				if( w_next_blink_counter != 4'd0 ) begin
					ff_interleaving_page <= ~ff_interleaving_page;
				end
				else begin
					//	hold
				end
			end
		end
	end

	// --------------------------------------------------------------------
	//	Interrupt
	// --------------------------------------------------------------------
	assign w_intr_line_timing	= (ff_half_count  == c_intr_line_timing ) ? 1'b1: 1'b0;
	assign w_intr_frame_timing	= ((ff_half_count  == c_left_pos) && 
			((reg_212lines_mode && w_screen_pos_y == c_intr_frame_timing212) || (!reg_212lines_mode && w_screen_pos_y == c_intr_frame_timing192))) ? 1'b1: 1'b0;

	// --------------------------------------------------------------------
	//	Output assignment
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		ff_screen_pos_x			<= w_screen_pos_x;
		ff_screen_pos_x_clone	<= w_screen_pos_x;
		//	MSXimus _120 (timing): la resta del scroll para los SPRITES se
		//	hace AQUI, al otro lado del registro. Era el peor camino de TODA
		//	la matriz de rutados con CLS al 84% (registro -> resta 10b ->
		//	decode de fases del selector de planos, hasta -1,9 ns).
		//	_162: se resta w_horizontal_offset_l_next (el proximo valor del
		//	LATCH), NO reg_horizontal_offset_l (el R#27 vivo, que era el error
		//	del _120). Asi ff_screen_pos_x_sprite(t+1) vale exactamente
		//	ff_screen_pos_x(t+1) - ff_horizontal_offset_l(t+1) = la expresion
		//	combinacional original de vdp_timing_control_sprite.v: BIT-EXACTO
		//	ciclo a ciclo, tambien durante un split de R#27.
		ff_screen_pos_x_sprite	<= { w_screen_pos_x[13:4] - { 7'd0, w_horizontal_offset_l_next }, w_screen_pos_x[3:0] };
		ff_screen_pos_y			<= w_screen_pos_y;
		ff_pixel_pos_x	<= w_pixel_pos_x[8:0];
		ff_pixel_pos_y	<= w_pixel_pos_y;
	end

	assign h_count				= ff_h_count;
	assign v_count				= ff_v_count_clone;
	assign screen_pos_x			= ff_screen_pos_x;
	assign screen_pos_x_clone	= ff_screen_pos_x_clone;
	assign screen_pos_x_sprite	= ff_screen_pos_x_sprite;
	assign screen_pos_y			= ff_screen_pos_y;
	assign pixel_pos_x			= ff_pixel_pos_x[8:0];
	assign pixel_pos_y			= ff_pixel_pos_y;
	assign intr_line			= ( (w_intr_line_y == { 2'd0, reg_interrupt_line }) && ff_line_interrupt_mask ) ? w_intr_line_timing: 1'b0;
	assign intr_frame			= w_intr_frame_timing;
	assign screen_v_active		= ff_v_active;
	assign dot_phase			= ff_half_count[0];
	assign interleaving_page	= reg_interleaving_mode ? (ff_interleaving_page & ff_field): 1'b1;
	assign blink				= ~ff_interleaving_page;
	assign status_field			= ff_field;
	assign status_hsync			= ff_hsync;
	assign status_vsync			= ff_vsync;
endmodule
