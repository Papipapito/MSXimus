`timescale 1ns/1ps
//-----------------------------------------------------------------------------
//	tb_cmdcache.sv — banco UNITARIO de fpga/v9968/vdp_command_cache.v
//	(MSXimus — bug #2 del INFORME_NIQUELADO: ff_busy que no lo limpia nadie)
//
//	Monta el escenario EXACTO del informe:
//	  1) comando de SOLO LECTURA (POINT/SRCH/LMCM): deja la cache LIMPIA
//	  2) fin de comando -> cache_flush_start: el flush recorre 5..1 SIN escribir
//	     nada en VRAM (ya esta drenado desde el primer ciclo)
//	  3) escritura de R#46 (start) A MITAD de ese flush — legal, el software no
//	     tiene por que esperar a CE=0
//	  4) el comando nuevo intenta su primer acceso a la cache
//	Sin el arreglo, (3) pone ff_busy=1 y NADIE lo baja: cache_vram_ready se queda
//	a 0 para siempre y (4) no se acepta jamas -> DEADLOCK (comando fantasma).
//
//	El banco es AUTOCOMPROBANTE y ademas CUENTA ACTIVIDAD (lecturas y escrituras
//	reales contra el modelo de VRAM, bytes servidos al motor, flush_end vistos):
//	si cualquiera de esos contadores sale a 0 el banco se declara INERTE y
//	FALLA, para que no pueda "salir en verde" sin ejercitar nada.
//-----------------------------------------------------------------------------
module tb_cmdcache;

	localparam int ACC_LAT		= 2;		//	ciclos hasta que la VRAM acepta
	localparam int RD_LAT		= 6;		//	ciclos hasta la respuesta de lectura
	localparam int MAXC			= 400;		//	paciencia por espera (ciclos)

	logic			clk = 1'b0;
	always #5 clk = ~clk;

	//	interfaz del motor de comandos
	logic			reset_n;
	logic			start;
	logic [17:0]	c_addr;
	logic			c_valid;
	wire			c_ready;
	logic			c_write;
	logic [7:0]		c_wdata;
	wire  [7:0]		c_rdata;
	wire			c_rdata_en;
	logic			flush_start;
	wire			flush_end;

	//	interfaz de VRAM
	wire [17:0]		m_addr;
	wire			m_valid;
	wire			m_write;
	wire [31:0]		m_wdata;
	wire [3:0]		m_wmask;
	logic [31:0]	m_rdata;
	logic			m_rdata_en;

	//	contadores de ACTIVIDAD
	int				n_wr	= 0;	//	escrituras aceptadas por la VRAM
	int				n_rd	= 0;	//	lecturas aceptadas por la VRAM
	int				n_srv	= 0;	//	bytes servidos al motor (cache_vram_rdata_en)
	int				n_fend	= 0;	//	pulsos de cache_flush_end
	int				n_start	= 0;	//	pulsos de start (R#46)
	int				fails	= 0;
	int				deadlocks = 0;

	// -------------------------------------------------------------------------
	//	DUT
	// -------------------------------------------------------------------------
	vdp_command_cache u_cache (
		.reset_n				( reset_n		),
		.clk					( clk			),
		.start					( start			),
		.cache_vram_address		( c_addr		),
		.cache_vram_valid		( c_valid		),
		.cache_vram_ready		( c_ready		),
		.cache_vram_write		( c_write		),
		.cache_vram_wdata		( c_wdata		),
		.cache_vram_rdata		( c_rdata		),
		.cache_vram_rdata_en	( c_rdata_en	),
		.cache_flush_start		( flush_start	),
		.cache_flush_end		( flush_end		),
		.command_vram_address	( m_addr		),
		.command_vram_valid		( m_valid		),
		.command_vram_ready		( m_ready		),
		.command_vram_write		( m_write		),
		.command_vram_wdata		( m_wdata		),
		.command_vram_wdata_mask( m_wmask		),
		.command_vram_rdata		( m_rdata		),
		.command_vram_rdata_en	( m_rdata_en	)
	);

	// -------------------------------------------------------------------------
	//	Modelo de VRAM (32 bits por palabra, mascara estilo DQM: 1 = NO escribir)
	// -------------------------------------------------------------------------
	logic [31:0]	mem [0:65535];
	logic [3:0]		acc_dly;
	int				acc_lat = ACC_LAT;		//	ajustable en caliente (escenario E)
	wire			m_ready = m_valid && (acc_dly >= acc_lat);

	logic [31:0]	rd_val;
	logic			rd_pend;
	logic [7:0]		rd_cnt;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			acc_dly <= 4'd0;
		end
		else if( m_valid && !m_ready ) begin
			acc_dly <= acc_dly + 4'd1;
		end
		else begin
			acc_dly <= 4'd0;
		end
	end

	always @( posedge clk ) begin
		m_rdata_en <= 1'b0;
		if( !reset_n ) begin
			rd_pend	<= 1'b0;
			rd_cnt	<= 8'd0;
		end
		else begin
			if( m_valid && m_ready ) begin
				if( m_write ) begin
					if( !m_wmask[0] )	mem[ m_addr[17:2] ][ 7: 0] <= m_wdata[ 7: 0];
					if( !m_wmask[1] )	mem[ m_addr[17:2] ][15: 8] <= m_wdata[15: 8];
					if( !m_wmask[2] )	mem[ m_addr[17:2] ][23:16] <= m_wdata[23:16];
					if( !m_wmask[3] )	mem[ m_addr[17:2] ][31:24] <= m_wdata[31:24];
					n_wr	<= n_wr + 1;
				end
				else begin
					rd_val	<= mem[ m_addr[17:2] ];
					rd_pend	<= 1'b1;
					rd_cnt	<= RD_LAT[7:0];
					n_rd	<= n_rd + 1;
				end
			end
			if( rd_pend ) begin
				if( rd_cnt == 8'd0 ) begin
					m_rdata		<= rd_val;
					m_rdata_en	<= 1'b1;
					rd_pend		<= 1'b0;
				end
				else begin
					rd_cnt		<= rd_cnt - 8'd1;
				end
			end
		end
	end

	//	espias de actividad del lado del motor
	always @( posedge clk ) begin
		if( reset_n && c_rdata_en )	n_srv  <= n_srv + 1;
		if( reset_n && flush_end )	n_fend <= n_fend + 1;
	end

	// -------------------------------------------------------------------------
	//	Utilidades del maestro (todo se pincha en negedge, el DUT muestrea en
	//	posedge; c_ready y flush_end salen de FFs, asi que en negedge ya valen lo
	//	que el proximo posedge va a ver)
	// -------------------------------------------------------------------------
	task automatic do_reset();
		begin
			reset_n		= 1'b0;
			start		= 1'b0;
			c_valid		= 1'b0;
			c_write		= 1'b0;
			c_wdata		= 8'd0;
			c_addr		= 18'd0;
			flush_start	= 1'b0;
			repeat( 4 ) @( negedge clk );
			reset_n		= 1'b1;
			repeat( 2 ) @( negedge clk );
			//	el reset deja ff_busy=1 a proposito: el primer start (R#46) con la
			//	cache limpia es quien lo libera, igual que en el core real
			pulse_start();
			repeat( 2 ) @( negedge clk );
		end
	endtask

	task automatic pulse_start();
		begin
			@( negedge clk );
			start	= 1'b1;
			n_start	= n_start + 1;
			@( negedge clk );
			start	= 1'b0;
		end
	endtask

	task automatic pulse_flush();
		begin
			@( negedge clk );
			flush_start	= 1'b1;
			@( negedge clk );
			flush_start	= 1'b0;
		end
	endtask

	//	peticion a la cache; ok=0 si no la aceptan en `maxc` ciclos
	task automatic req( input bit wr, input [17:0] a, input [7:0] d,
						input int maxc, output bit ok );
		int i;
		begin
			@( negedge clk );
			c_addr	= a;
			c_write	= wr;
			c_wdata	= d;
			c_valid	= 1'b1;
			ok		= 1'b0;
			for( i = 0; i < maxc; i++ ) begin
				if( c_ready ) ok = 1'b1;
				@( negedge clk );			//	cruza el posedge que acepta
				if( ok ) break;
			end
			c_valid	= 1'b0;
		end
	endtask

	task automatic wait_rdata( input int maxc, output bit ok, output logic [7:0] d );
		int i;
		begin
			ok	= 1'b0;
			d	= 8'd0;
			for( i = 0; i < maxc; i++ ) begin
				@( negedge clk );
				if( c_rdata_en ) begin
					ok	= 1'b1;
					d	= c_rdata;
					break;
				end
			end
		end
	endtask

	task automatic wait_flush_end( input int maxc, output bit ok );
		int i;
		begin
			ok = 1'b0;
			for( i = 0; i < maxc; i++ ) begin
				@( negedge clk );
				if( flush_end ) begin
					ok = 1'b1;
					break;
				end
			end
		end
	endtask

	task automatic chk( input bit cond, input string msg );
		begin
			if( cond ) begin
				$display( "  OK    %s", msg );
			end
			else begin
				$display( "  FALLO %s", msg );
				fails = fails + 1;
			end
		end
	endtask

	// -------------------------------------------------------------------------
	//	Escenarios
	// -------------------------------------------------------------------------
	bit				ok, ok2;
	logic [7:0]		rb;
	int				off;
	int				n_rd_e;
	string			s;

	initial begin
		//	VRAM con un patron reconocible
		for( int k = 0; k < 65536; k++ ) mem[k] = { 8'h44, 8'h33, 8'h22, 8'h11 } ^ k;

		$display( "=== tb_cmdcache: banco unitario de vdp_command_cache ===" );

		// ---------------------------------------------------------------------
		//	A) CONTROL — camino normal: 4 escrituras + flush explicito
		// ---------------------------------------------------------------------
		$display( "[A] control: 4 escrituras en una palabra + flush" );
		do_reset();
		req( 1'b1, 18'h01000, 8'hA1, MAXC, ok );  chk( ok, "escritura 0 aceptada" );
		req( 1'b1, 18'h01001, 8'hB2, MAXC, ok );  chk( ok, "escritura 1 aceptada" );
		req( 1'b1, 18'h01002, 8'hC3, MAXC, ok );  chk( ok, "escritura 2 aceptada" );
		req( 1'b1, 18'h01003, 8'hD4, MAXC, ok );  chk( ok, "escritura 3 aceptada" );
		pulse_flush();
		wait_flush_end( MAXC, ok );               chk( ok, "flush_end del control" );
		repeat( 8 ) @( negedge clk );
		chk( mem[18'h01000>>2] == 32'hD4C3B2A1, "la palabra llego a la VRAM" );

		// ---------------------------------------------------------------------
		//	B) BUG #2 — start (R#46) a mitad de un flush YA DRENADO
		// ---------------------------------------------------------------------
		$display( "[B] bug #2: R#46 durante un flush limpio (comando de solo lectura)" );
		for( off = 1; off <= 6; off++ ) begin
			do_reset();
			//	comando de SOLO LECTURA: una lectura de VRAM deja la entrada
			//	LIMPIA (already_read=1, mask=1111) => w_dirty_any = 0
			req( 1'b0, 18'h02000, 8'h00, MAXC, ok );
			wait_rdata( MAXC, ok2, rb );
			$sformat( s, "off=%0d: lectura previa servida (0x%02X)", off, rb );
			chk( ok && ok2, s );

			//	fin del comando: el motor pide el flush...
			pulse_flush();
			//	...y el software escribe R#46 `off` ciclos despues, con el flush
			//	todavia en marcha (ff_flush_state != 0) y NADA sucio que escribir
			repeat( off - 1 ) @( negedge clk );
			pulse_start();

			//	el flush termina solo
			repeat( 12 ) @( negedge clk );

			//	primer acceso del comando NUEVO
			req( 1'b1, 18'h05000, 8'h5A, MAXC, ok );
			if( !ok ) deadlocks = deadlocks + 1;
			$sformat( s, "off=%0d: el comando nuevo es aceptado (no hay deadlock)", off );
			chk( ok, s );

			if( ok ) begin
				pulse_flush();
				wait_flush_end( MAXC, ok2 );
				repeat( 8 ) @( negedge clk );
				$sformat( s, "off=%0d: el byte del comando nuevo llego a la VRAM", off );
				chk( mem[18'h05000>>2][7:0] == 8'h5A, s );
			end
		end

		// ---------------------------------------------------------------------
		//	C) REGRESION del FIX ABORTO — start con la cache SUCIA (flush_state=0)
		// ---------------------------------------------------------------------
		$display( "[C] regresion FIX ABORTO: R#46 con la cache sucia" );
		do_reset();
		req( 1'b1, 18'h03000, 8'h7E, MAXC, ok );  chk( ok, "escritura sucia aceptada" );
		pulse_start();									//	aborta: NO debe descartar
		req( 1'b1, 18'h06000, 8'h99, MAXC, ok );  chk( ok, "el comando nuevo arranca" );
		pulse_flush();
		wait_flush_end( MAXC, ok );               chk( ok, "flush_end tras el aborto" );
		repeat( 8 ) @( negedge clk );
		chk( mem[18'h03000>>2][7:0] == 8'h7E, "el byte abortado SI llego a la VRAM" );
		chk( mem[18'h06000>>2][7:0] == 8'h99, "el byte del comando nuevo llego a la VRAM" );

		// ---------------------------------------------------------------------
		//	D) start a mitad de un flush CON suciedad pendiente
		// ---------------------------------------------------------------------
		$display( "[D] R#46 durante un flush SUCIO" );
		do_reset();
		req( 1'b1, 18'h04000, 8'h11, MAXC, ok );  chk( ok, "sucio 0 aceptado" );
		req( 1'b1, 18'h04010, 8'h22, MAXC, ok );  chk( ok, "sucio 1 aceptado" );
		pulse_flush();
		pulse_start();									//	off=1, con dirty vivo
		repeat( 24 ) @( negedge clk );
		req( 1'b1, 18'h07000, 8'h33, MAXC, ok );  chk( ok, "el comando nuevo es aceptado" );
		pulse_flush();
		wait_flush_end( MAXC, ok2 );
		repeat( 8 ) @( negedge clk );
		chk( mem[18'h04000>>2][7:0] == 8'h11, "sucio 0 llego a la VRAM" );
		chk( mem[18'h04010>>2][7:0] == 8'h22, "sucio 1 llego a la VRAM" );
		chk( mem[18'h07000>>2][7:0] == 8'h33, "el byte del comando nuevo llego a la VRAM" );

		// ---------------------------------------------------------------------
		//	E) ENDURECIMIENTO — start con un flush en marcha y una LECTURA en
		//	   vuelo todavia sin aceptar por la VRAM. La rama de aborto CANCELA
		//	   esa lectura (ff_vram_valid <= valid && write), asi que el esbozo
		//	   `ff_busy <= w_dirty_any | ff_vram_valid` del informe deja busy=1
		//	   sin nadie que lo baje: sigue habiendo deadlock. Estimulo legal a
		//	   nivel de modulo; alcanzabilidad a nivel de sistema NO demostrada.
		// ---------------------------------------------------------------------
		$display( "[E] endurecimiento: R#46 + flush con una lectura en vuelo" );
		do_reset();
		acc_lat = 12;						//	VRAM lenta: ventana ancha de lectura en vuelo
		n_rd_e = n_rd;
		req( 1'b0, 18'h08000, 8'h00, MAXC, ok );  chk( ok, "lectura aceptada por la cache" );
		//	aqui ff_vram_valid = 1 (lectura hacia VRAM, aun SIN aceptar)
		@( negedge clk );	flush_start = 1'b1;
		@( negedge clk );	flush_start = 1'b0;	start = 1'b1;	n_start = n_start + 1;
		@( negedge clk );	start = 1'b0;
		//	la lectura queda CANCELADA por el aborto (nunca la acepta la VRAM),
		//	asi que no hay respuesta huerfana que rescate ff_busy de rebote
		acc_lat = ACC_LAT;
		repeat( 24 ) @( negedge clk );
		chk( n_rd == n_rd_e, "la lectura fue CANCELADA (la VRAM no la acepto)" );
		req( 1'b1, 18'h09000, 8'hC7, MAXC, ok );
		if( !ok ) deadlocks = deadlocks + 1;
		chk( ok, "el comando nuevo es aceptado (no hay deadlock)" );
		if( ok ) begin
			pulse_flush();
			wait_flush_end( MAXC, ok2 );
			repeat( 8 ) @( negedge clk );
			chk( mem[18'h09000>>2][7:0] == 8'hC7, "el byte del comando nuevo llego a la VRAM" );
		end

		// ---------------------------------------------------------------------
		//	Informe
		// ---------------------------------------------------------------------
		$display( "--- ACTIVIDAD: vram_wr=%0d vram_rd=%0d bytes_servidos=%0d flush_end=%0d start=%0d",
					n_wr, n_rd, n_srv, n_fend, n_start );
		if( n_wr == 0 || n_rd == 0 || n_srv == 0 || n_fend == 0 ) begin
			$display( "BANCO INERTE: algun contador de actividad esta a 0" );
			fails = fails + 1;
		end
		$display( "--- DEADLOCKS observados: %0d", deadlocks );
		if( fails == 0 )
			$display( "RESULTADO: OK (0 fallos)" );
		else
			$display( "RESULTADO: FALLO (%0d fallos)", fails );
		$finish;
	end

	//	perro guardian global
	initial begin
		#4_000_000;
		$display( "TIMEOUT GLOBAL del banco" );
		$display( "RESULTADO: FALLO (timeout)" );
		$finish;
	end
endmodule
