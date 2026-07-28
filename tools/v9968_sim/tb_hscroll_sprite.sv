//
//	tb_hscroll_sprite.sv — BUG #18 (MSXimus _162)
//
//	Equivalencia CICLO A CICLO de la coordenada de sprites (screen_pos_x_sprite)
//	entre TRES instancias del SSG alimentadas con EXACTAMENTE el mismo estimulo:
//
//	  u_ref : semantica ORIGINAL de HRA (pre-_120): resta combinacional
//	          screen_pos_x[13:4] - horizontal_offset_l  (el valor LATCHEADO)
//	  u_bug : HEAD fc7f724 (parche _120: resta reg_horizontal_offset_l, el VIVO)
//	  u_fix : parche _162 (resta w_horizontal_offset_l_next = proximo del latch)
//
//	Criterio de exito:
//	  1) u_fix == u_ref en TODOS los ciclos y en TODAS las salidas   (bit-exacto)
//	  2) u_bug != u_ref en un numero SIGNIFICATIVO de ciclos          (el banco
//	     ejercita de verdad el bug; si esto sale 0 el banco no prueba nada)
//	  3) contadores de actividad > 0 (escrituras de R#27, eventos de latch,
//	     ventanas vivo!=latcheado, transiciones de la coordenada)
//
//	Plusargs:  +cycles=N   (por defecto 2900000, ~2 campos NTSC)
//	           +nosplit    (sin escrituras de R#27: el bug debe DESAPARECER)
//	           +seed=N
//
`timescale 1ns/1ps

module tb_hscroll_sprite;

	// ------------------------------------------------------------------
	//	Reloj / reset
	// ------------------------------------------------------------------
	reg				clk		= 1'b0;
	reg				reset_n	= 1'b0;
	always #5.82 clk = ~clk;			//	85.90908 MHz aprox

	// ------------------------------------------------------------------
	//	Registros del VDP (estimulo comun a las tres instancias)
	// ------------------------------------------------------------------
	reg				reg_display_on					= 1'b1;
	reg				reg_50hz_mode					= 1'b0;
	reg				reg_212lines_mode				= 1'b0;
	reg				reg_interlace_mode				= 1'b0;
	reg		[7:0]	reg_display_adjust				= 8'h77;
	reg		[7:0]	reg_interrupt_line				= 8'd100;
	reg		[7:0]	reg_vertical_offset				= 8'd0;
	reg		[2:0]	reg_horizontal_offset_l			= 3'd0;
	reg		[8:3]	reg_horizontal_offset_h			= 6'd0;
	reg				reg_interleaving_mode			= 1'b0;
	reg				reg_flat_interlace_mode			= 1'b0;
	reg		[7:0]	reg_blink_period				= 8'h00;
	reg				reg_interrupt_line_nonR23_mode	= 1'b0;

	// ------------------------------------------------------------------
	//	Salidas de las tres instancias
	// ------------------------------------------------------------------
	`define SSG_PORTS(p) \
		wire	[11:0]	p``_h_count;				\
		wire	[ 9:0]	p``_v_count;				\
		wire	[13:0]	p``_screen_pos_x;			\
		wire	[13:0]	p``_screen_pos_x_clone;		\
		wire	[13:0]	p``_screen_pos_x_sprite;	\
		wire	[ 9:0]	p``_screen_pos_y;			\
		wire	[ 8:0]	p``_pixel_pos_x;			\
		wire	[ 7:0]	p``_pixel_pos_y;			\
		wire			p``_screen_v_active;		\
		wire			p``_intr_line;				\
		wire			p``_intr_frame;				\
		wire			p``_clear_line_interrupt;	\
		wire			p``_pre_vram_refresh;		\
		wire	[ 2:0]	p``_horizontal_offset_l;	\
		wire	[ 8:3]	p``_horizontal_offset_h;	\
		wire			p``_interleaving_page;		\
		wire			p``_blink;					\
		wire			p``_status_field;			\
		wire			p``_status_hsync;			\
		wire			p``_status_vsync;

	`SSG_PORTS(ref)
	`SSG_PORTS(bug)
	`SSG_PORTS(fix)

	`define SSG_INST(mod,p) \
		mod u_``p (								\
			.reset_n						( reset_n						),	\
			.clk							( clk							),	\
			.h_count						( p``_h_count					),	\
			.v_count						( p``_v_count					),	\
			.screen_pos_x					( p``_screen_pos_x				),	\
			.screen_pos_x_clone				( p``_screen_pos_x_clone		),	\
			.screen_pos_x_sprite			( p``_screen_pos_x_sprite		),	\
			.screen_pos_y					( p``_screen_pos_y				),	\
			.pixel_pos_x					( p``_pixel_pos_x				),	\
			.pixel_pos_y					( p``_pixel_pos_y				),	\
			.screen_v_active				( p``_screen_v_active			),	\
			.intr_line						( p``_intr_line					),	\
			.intr_frame						( p``_intr_frame				),	\
			.clear_line_interrupt			( p``_clear_line_interrupt		),	\
			.pre_vram_refresh				( p``_pre_vram_refresh			),	\
			.reg_display_on					( reg_display_on				),	\
			.reg_50hz_mode					( reg_50hz_mode					),	\
			.reg_212lines_mode				( reg_212lines_mode				),	\
			.reg_interlace_mode				( reg_interlace_mode			),	\
			.reg_display_adjust				( reg_display_adjust			),	\
			.reg_interrupt_line				( reg_interrupt_line			),	\
			.reg_vertical_offset			( reg_vertical_offset			),	\
			.reg_horizontal_offset_l		( reg_horizontal_offset_l		),	\
			.reg_horizontal_offset_h		( reg_horizontal_offset_h		),	\
			.reg_interleaving_mode			( reg_interleaving_mode			),	\
			.reg_flat_interlace_mode		( reg_flat_interlace_mode		),	\
			.reg_blink_period				( reg_blink_period				),	\
			.reg_interrupt_line_nonR23_mode	( reg_interrupt_line_nonR23_mode),	\
			.horizontal_offset_l			( p``_horizontal_offset_l		),	\
			.horizontal_offset_h			( p``_horizontal_offset_h		),	\
			.interleaving_page				( p``_interleaving_page			),	\
			.blink							( p``_blink						),	\
			.status_field					( p``_status_field				),	\
			.status_hsync					( p``_status_hsync				),	\
			.status_vsync					( p``_status_vsync				)	\
		);

	`SSG_INST(vdp_timing_control_ssg_ref,ref)
	`SSG_INST(vdp_timing_control_ssg_bug,bug)
	`SSG_INST(vdp_timing_control_ssg_fix,fix)

	// ------------------------------------------------------------------
	//	Estimulo de R#27 (scroll horizontal fino)
	//	Se escribe con NO BLOQUEANTE en el flanco, igual que el registro real
	//	de vdp_cpu_interface: las tres instancias ven el mismo valor el mismo
	//	ciclo.
	// ------------------------------------------------------------------
	integer	seed		= 32'h1234_5678;
	integer	n_cycles	= 2900000;
	reg		nosplit		= 1'b0;

	integer	cnt_r27_write		= 0;	//	escrituras de R#27 que CAMBIAN el valor
	integer	cnt_split_isr		= 0;	//	splits disparados por interrupcion de linea
	integer	cnt_phase_sweep		= 0;	//	escrituras del barrido de fase
	integer	cnt_latch_event		= 0;	//	ciclos con captura del latch
	integer	cnt_latch_change	= 0;	//	capturas que CAMBIAN el valor latcheado
	integer	cnt_live_ne_latch	= 0;	//	ciclos con R#27 vivo != latcheado
	integer	cnt_sprite_toggle	= 0;	//	transiciones de screen_pos_x_sprite (ref)
	integer	cnt_cmp				= 0;	//	ciclos comparados
	integer	cnt_mm_fix			= 0;	//	desajustes fix  vs ref  (debe ser 0)
	integer	cnt_mm_bug			= 0;	//	desajustes bug  vs ref  (debe ser > 0)
	integer	cnt_mm_other		= 0;	//	desajustes de las OTRAS salidas fix vs ref
	integer	mm_bug_max_dx		= 0;	//	|delta| maximo en pixeles (bug)
	integer	mm_bug_burst_max	= 0;	//	rafaga de desajuste mas larga (ciclos)
	integer	mm_bug_burst		= 0;
	integer	dumped				= 0;

	reg		[13:0]	prev_sprite_ref;
	reg		[ 2:0]	prev_r27	= 3'd0;
	reg				isronly		= 1'b0;
	integer	isr_arm		= -1;
	integer	line_idx	= 0;
	reg		prev_intr_line;
	reg		prev_h_end;
	integer	i;
	integer	dx;
	reg		cmp_en	= 1'b0;

	//	--- barrido de fase: escribe R#27 en h_count = {2735,2734,2733,0,1,1368}
	//	    de lineas consecutivas, para cubrir el ciclo EXACTO de la captura
	//	    del latch y sus vecinos, en lineas pares e impares.
	integer	sweep_phase	= 0;
	reg		[11:0]	sweep_h;

	always @( posedge clk ) begin
		if( reset_n && !nosplit ) begin
			//	(a) split "de interrupcion": la ISR escribe R#27 unos ciclos
			//	    despues de intr_line (caso real de raster split)
			if( ref_intr_line && !prev_intr_line ) begin
				isr_arm			<= 250;
			end
			else if( isr_arm > 0 ) begin
				isr_arm			<= isr_arm - 1;
			end
			else if( isr_arm == 0 ) begin
				reg_horizontal_offset_l	<= reg_horizontal_offset_l + 3'd3;
				isr_arm			<= -1;
				cnt_split_isr	<= cnt_split_isr + 1;
			end

			//	(b) barrido de fase respecto a la captura del latch
			if( isronly ) begin
				//	solo el split de la ISR (mide la rafaga REAL del bug)
			end
			else if( ref_h_count == sweep_h ) begin
				reg_horizontal_offset_l	<= $random(seed);
				cnt_phase_sweep	<= cnt_phase_sweep + 1;
			end
			//	(c) escrituras aleatorias (1 de cada ~4096 ciclos)
			else if( ($random(seed) & 32'hFFF) == 32'd0 ) begin
				reg_horizontal_offset_l	<= $random(seed);
				reg_horizontal_offset_h	<= $random(seed);
			end
		end
		prev_intr_line <= ref_intr_line;
	end

	//	fase del barrido: cambia una vez por linea
	always @( posedge clk ) begin
		if( !reset_n ) begin
			sweep_phase	<= 0;
			sweep_h		<= 12'd2735;
			line_idx	<= 0;
		end
		else if( ref_h_count == 12'd2735 ) begin
			line_idx	<= line_idx + 1;
			sweep_phase	<= (sweep_phase == 5) ? 0: sweep_phase + 1;
			case( sweep_phase )
			0:			sweep_h <= 12'd2734;
			1:			sweep_h <= 12'd2733;
			2:			sweep_h <= 12'd0;
			3:			sweep_h <= 12'd1;
			4:			sweep_h <= 12'd1368;
			default:	sweep_h <= 12'd2735;
			endcase
		end
	end

	// ------------------------------------------------------------------
	//	Contadores de ACTIVIDAD + comparacion (en el flanco de bajada, con
	//	todas las salidas ya estables)
	// ------------------------------------------------------------------
	always @( negedge clk ) begin
		if( reset_n ) begin
			if( reg_horizontal_offset_l !== prev_r27 )	cnt_r27_write		= cnt_r27_write + 1;
			prev_r27 = reg_horizontal_offset_l;

			if( u_ref.ff_v_count[0] && u_ref.w_h_count_end ) begin
				cnt_latch_event = cnt_latch_event + 1;
				if( reg_horizontal_offset_l !== ref_horizontal_offset_l )
					cnt_latch_change = cnt_latch_change + 1;
			end
			if( reg_horizontal_offset_l !== ref_horizontal_offset_l )
				cnt_live_ne_latch = cnt_live_ne_latch + 1;
			if( ref_screen_pos_x_sprite !== prev_sprite_ref )	cnt_sprite_toggle = cnt_sprite_toggle + 1;
			prev_sprite_ref = ref_screen_pos_x_sprite;
		end

		if( cmp_en ) begin
			cnt_cmp = cnt_cmp + 1;

			//	--- 1) la coordenada de sprites -----------------------------
			if( fix_screen_pos_x_sprite !== ref_screen_pos_x_sprite ) begin
				cnt_mm_fix = cnt_mm_fix + 1;
				if( dumped < 10 ) begin
					$display("[FIX-MISMATCH] t=%0t v=%0d h=%0d ref=%h fix=%h",
						$time, ref_v_count, ref_h_count, ref_screen_pos_x_sprite, fix_screen_pos_x_sprite);
					dumped = dumped + 1;
				end
			end

			if( bug_screen_pos_x_sprite !== ref_screen_pos_x_sprite ) begin
				cnt_mm_bug	= cnt_mm_bug + 1;
				mm_bug_burst = mm_bug_burst + 1;
				if( mm_bug_burst > mm_bug_burst_max )	mm_bug_burst_max = mm_bug_burst;
				dx = $signed( {1'b0,bug_screen_pos_x_sprite[13:4]} ) - $signed( {1'b0,ref_screen_pos_x_sprite[13:4]} );
				if( dx < 0 )	dx = -dx;
				if( dx > 512 )	dx = 1024 - dx;		//	envolvente del contador de 10 bits
				if( dx > mm_bug_max_dx )				mm_bug_max_dx = dx;
			end
			else begin
				mm_bug_burst = 0;
			end

			//	--- 2) el RESTO de salidas (no debe cambiar nada mas) -------
			if( (fix_h_count				!== ref_h_count				) ||
				(fix_v_count				!== ref_v_count				) ||
				(fix_screen_pos_x			!== ref_screen_pos_x		) ||
				(fix_screen_pos_x_clone		!== ref_screen_pos_x_clone	) ||
				(fix_screen_pos_y			!== ref_screen_pos_y		) ||
				(fix_pixel_pos_x			!== ref_pixel_pos_x			) ||
				(fix_pixel_pos_y			!== ref_pixel_pos_y			) ||
				(fix_screen_v_active		!== ref_screen_v_active		) ||
				(fix_intr_line				!== ref_intr_line			) ||
				(fix_intr_frame				!== ref_intr_frame			) ||
				(fix_clear_line_interrupt	!== ref_clear_line_interrupt) ||
				(fix_pre_vram_refresh		!== ref_pre_vram_refresh	) ||
				(fix_horizontal_offset_l	!== ref_horizontal_offset_l	) ||
				(fix_horizontal_offset_h	!== ref_horizontal_offset_h	) ||
				(fix_interleaving_page		!== ref_interleaving_page	) ||
				(fix_blink					!== ref_blink				) ||
				(fix_status_field			!== ref_status_field		) ||
				(fix_status_hsync			!== ref_status_hsync		) ||
				(fix_status_vsync			!== ref_status_vsync		) ) begin
				cnt_mm_other = cnt_mm_other + 1;
				if( dumped < 10 ) begin
					$display("[FIX-OTHER-MISMATCH] t=%0t v=%0d h=%0d", $time, ref_v_count, ref_h_count);
					dumped = dumped + 1;
				end
			end
		end
	end

	// ------------------------------------------------------------------
	//	Secuencia principal
	// ------------------------------------------------------------------
	initial begin
		if( $value$plusargs("cycles=%d", n_cycles) )	;
		if( $value$plusargs("seed=%d",   seed    ) )	;
		nosplit = $test$plusargs("nosplit");
		isronly = $test$plusargs("isronly");

		$display("=== tb_hscroll_sprite : BUG #18 (scroll de sprites _120 -> _162) ===");
		$display("    ciclos=%0d  nosplit=%0d  isronly=%0d  seed=%0d", n_cycles, nosplit, isronly, seed);

		reset_n = 1'b0;
		repeat( 8 ) @( posedge clk );
		reset_n = 1'b1;
		repeat( 8 ) @( posedge clk );
		cmp_en = 1'b1;

		for( i = 0; i < n_cycles; i = i + 1 ) begin
			@( posedge clk );
		end

		cmp_en = 1'b0;
		@( negedge clk );

		$display("");
		$display("--- ACTIVIDAD (si algo de esto es 0, el banco NO prueba nada) ---");
		$display("  ciclos comparados ................ %0d", cnt_cmp);
		$display("  lineas recorridas ................ %0d", line_idx);
		$display("  escrituras de R#27 (cambio real) . %0d", cnt_r27_write);
		$display("    de ellas, splits por ISR ....... %0d", cnt_split_isr);
		$display("    barrido de fase del latch ...... %0d", cnt_phase_sweep);
		$display("  capturas del latch (2 lineas) .... %0d", cnt_latch_event);
		$display("    capturas que CAMBIAN el valor .. %0d", cnt_latch_change);
		$display("  ciclos con R#27 vivo != latcheado  %0d", cnt_live_ne_latch);
		$display("  transiciones de screen_pos_x_sprite %0d", cnt_sprite_toggle);
		$display("");
		$display("--- RESULTADO ---");
		$display("  desajustes  fix vs ref (sprite) .. %0d   <-- debe ser 0", cnt_mm_fix);
		$display("  desajustes  fix vs ref (resto) ... %0d   <-- debe ser 0", cnt_mm_other);
		$display("  desajustes  bug vs ref (sprite) .. %0d   <-- debe ser > 0 (salvo +nosplit)", cnt_mm_bug);
		$display("    |delta| maximo en pixeles ...... %0d", mm_bug_max_dx);
		$display("    rafaga mas larga (ciclos) ...... %0d  = %0d,%02d lineas de 2736 ciclos",
			mm_bug_burst_max, mm_bug_burst_max/2736, ((mm_bug_burst_max*100)/2736)%100);
		$display("");

		if( cnt_cmp != n_cycles || cnt_sprite_toggle == 0 ) begin
			$display("*** FALLO: el banco no comparo todos los ciclos o la coordenada esta muerta ***");
			$finish;
		end
		if( !nosplit && (cnt_r27_write == 0 || cnt_latch_event == 0 ||
						 cnt_latch_change == 0 || cnt_live_ne_latch == 0) ) begin
			$display("*** FALLO: el banco no ejercita el split de R#27 (contadores de actividad) ***");
			$finish;
		end

		if( cnt_mm_fix != 0 || cnt_mm_other != 0 ) begin
			$display("*** FALLO: el parche _162 NO es bit-exacto ***");
		end
		else if( !nosplit && cnt_mm_bug == 0 ) begin
			$display("*** FALLO: el banco no reproduce el bug del _120 (comparacion ciega) ***");
		end
		else if( nosplit && cnt_mm_bug != 0 ) begin
			$display("*** FALLO: sin escrituras de R#27 no deberia haber diferencias ***");
		end
		else begin
			$display("*** OK: _162 bit-exacto con el original y el bug del _120 reproducido ***");
		end
		$finish;
	end

endmodule
