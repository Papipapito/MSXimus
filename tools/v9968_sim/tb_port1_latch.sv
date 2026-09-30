`timescale 1ns/1ps
// ============================================================================
// tb_port1_latch.sv — banco tb_port1_latch_reset de HRA! (hra1129/V9968_Cartridge, src/v9968/test_vdp_cpu_interface/tb.sv,
// commit 05f9806, 29/09/2026; su core es MIT), TAL CUAL salvo dos conexiones de salida que nuestro
// vdp_cpu_interface.v no tiene (clear_sprite_overmap, sprite_overmap_enable: su overmap, aqui va la _187).
// 12 pruebas: el par de bytes del puerto 1 se cancela con una escritura a 98h, con una lectura de 98h y con la
// lectura de status; 9Ah/9Bh lo mantienen y sustituyen el dato; la paleta V9938 saca R/B del latch compartido;
// R#16 reinicia el contador de la paleta; la paleta extendida va aparte. Uso: bash run_port1_latch.sh
// ============================================================================
module tb_port1_latch_reset ();
	reg clk;
	reg reset_n;
	reg [2:0] bus_address;
	reg bus_ioreq;
	reg bus_write;
	reg bus_valid;
	reg [7:0] bus_wdata;
	wire bus_ready;
	wire [7:0] bus_rdata;
	wire bus_rdata_en;
	wire vram_write;
	wire vram_valid;
	reg vram_ready;
	reg vram_rdata_en;
	wire register_write;
	wire [5:0] register_num;
	wire [7:0] register_data;
	wire [7:0] reg_backdrop_color;
	wire [17:11] reg_sprite_pattern_generator_table_base;
	reg [5:0] last_register_num;
	reg [7:0] last_register_data;
	integer register_write_count;
	wire palette_valid;
	wire [7:0] palette_num;
	wire [4:0] palette_r;
	wire [4:0] palette_g;
	wire [4:0] palette_b;
	wire reg_ext_palette_mode;
	reg [7:0] last_palette_num;
	reg [4:0] last_palette_r;
	reg [4:0] last_palette_g;
	reg [4:0] last_palette_b;
	integer palette_write_count;

	vdp_cpu_interface u_dut (
		.reset_n(reset_n),
		.clk(clk),
		.bus_address(bus_address),
		.bus_ioreq(bus_ioreq),
		.bus_write(bus_write),
		.bus_valid(bus_valid),
		.bus_ready(bus_ready),
		.bus_wdata(bus_wdata),
		.bus_rdata(bus_rdata),
		.bus_rdata_en(bus_rdata_en),
		.vram_address(),
		.vram_write(vram_write),
		.vram_valid(vram_valid),
		.vram_ready(vram_ready),
		.vram_wdata(),
		.vram_rdata(8'h5A),
		.vram_rdata_en(vram_rdata_en),
		.palette_valid(palette_valid),
		.palette_num(palette_num),
		.palette_r(palette_r),
		.palette_g(palette_g),
		.palette_b(palette_b),
		.int_n(),
		.intr_line(1'b0),
		.intr_frame(1'b0),
		.intr_command_end(1'b0),
		.clear_line_interrupt(1'b0),
		.clear_sprite_collision(),
		.sprite_collision(1'b0),
		.clear_sprite_collision_xy(),
		.sprite_collision_x(9'd0),
		.sprite_collision_y(10'd0),
		.sprite_overmap(1'b0),
		.sprite_overmap_id(5'd31),
		.clear_border_detect(),
		.read_color(),
		.register_write(register_write),
		.register_num(register_num),
		.register_data(register_data),
		.status_command_execute(1'b0),
		.status_field(1'b0),
		.status_border_detect(1'b0),
		.status_hsync(1'b0),
		.status_vsync(1'b0),
		.status_transfer_ready(1'b0),
		.status_color(8'd0),
		.status_border_position(9'd0),
		.vram_access_mask(1'b0),
		.force_highspeed(1'b0),
		.button(2'd0),
		.reg_screen_mode(),
		.reg_sprite_magify(),
		.reg_sprite_16x16(),
		.reg_display_on(),
		.reg_pattern_name_table_base(),
		.reg_color_table_base(),
		.reg_pattern_generator_table_base(),
		.reg_sprite_attribute_table_base(),
		.reg_sprite_pattern_generator_table_base(reg_sprite_pattern_generator_table_base),
		.reg_backdrop_color(reg_backdrop_color),
		.reg_sprite_disable(),
		.reg_color0_opaque(),
		.reg_50hz_mode(),
		.reg_interleaving_mode(),
		.reg_interlace_mode(),
		.reg_212lines_mode(),
		.reg_text_back_color(),
		.reg_blink_period(),
		.reg_display_adjust(),
		.reg_interrupt_line(),
		.reg_vertical_offset(),
		.reg_scroll_planes(),
		.reg_left_mask(),
		.reg_yjk_mode(),
		.reg_yae_mode(),
		.reg_command_enable(),
		.reg_sprite_priority_shuffle(),
		.reg_horizontal_offset_l(),
		.reg_horizontal_offset_h(),
		.reg_command_high_speed_mode(),
		.reg_sprite_nonR23_mode(),
		.reg_interrupt_line_nonR23_mode(),
		.reg_sprite_mode3(),
		.reg_ext_palette_mode(reg_ext_palette_mode),
		.reg_ext_command_mode(),
		.reg_vram256k_mode(),
		.reg_sprite16_mode(),
		.reg_flat_interlace_mode(),
		.pulse0(),
		.pulse1(),
		.pulse2(),
		.pulse3(),
		.pulse4(),
		.pulse5(),
		.pulse6(),
		.pulse7()
	);

	always #5 clk = ~clk;

	always @(posedge clk) begin
		if (palette_valid) begin
			last_palette_num    <= palette_num;
			last_palette_r      <= palette_r;
			last_palette_g      <= palette_g;
			last_palette_b      <= palette_b;
			palette_write_count <= palette_write_count + 1;
		 end
	end

	//	Minimal VRAM model: accept one cycle after request, return read data one cycle later.
	always @(posedge clk) begin
		vram_ready    <= vram_valid & ~vram_ready;
		vram_rdata_en <= vram_valid & vram_ready & ~vram_write;
	end

	always @(posedge clk) begin
		if (register_write) begin
			last_register_num    <= register_num;
			last_register_data   <= register_data;
			register_write_count <= register_write_count + 1;
		end
	end

	task automatic access_io;
		input [2:0] address;
		input       write;
		input [7:0] wdata;
		integer time_out;
		begin
			bus_ioreq   = 1'b1;
			bus_address = address;
			bus_write   = write;
			bus_wdata   = wdata;
			bus_valid   = 1'b1;
			time_out    = 0;
			while (bus_ready !== 1'b1) begin
				@(posedge clk);
				#1;
				time_out = time_out + 1;
				if (time_out > 100) $fatal(1, "bus_ready timeout (accept)");
			end
			@(posedge clk);
			#1;
			bus_valid = 1'b0;
			time_out  = 0;
			while (bus_ready !== 1'b1) begin
				@(posedge clk);
				#1;
				time_out = time_out + 1;
				if (time_out > 100) $fatal(1, "bus_ready timeout (complete)");
			end
			bus_ioreq = 1'b0;
			repeat (4) @(posedge clk);
			#1;
		end
	endtask

	task automatic write_register;
		input [5:0] num;
		input [7:0] value;
		begin
			access_io(3'd1, 1'b1, value);
			access_io(3'd1, 1'b1, { 2'b10, num });
		end
	endtask

	task automatic expect_backdrop;
		input [7:0] expected;
		input [8*48-1:0] name;
		begin
			if (reg_backdrop_color !== expected) begin
				$fatal(1, "%0s: R#7 expected %02X, got %02X", name, expected, reg_backdrop_color);
			end
			$display("-- %0s: OK", name);
		end
	endtask

	//	Expected palette entry for the V9938 format (3bit each, expanded to 5bit)
	task automatic expect_palette9938;
		input [3:0] num;
		input [7:0] rb;
		input [7:0] g;
		input [8*48-1:0] name;
		begin
			expect_palette({ 4'd0, num }, { rb[6:4], rb[6:5] }, { g[2:0], g[2:1] }, { rb[2:0], rb[2:1] }, name);
		end
	endtask

	task automatic expect_palette;
		input [7:0] num;
		input [4:0] r;
		input [4:0] g;
		input [4:0] b;
		input [8*48-1:0] name;
		begin
			if (palette_write_count !== 1) begin
				$fatal(1, "%0s: palette write count expected 1, got %0d", name, palette_write_count);
			end
			if (last_palette_num !== num || last_palette_r !== r || last_palette_g !== g || last_palette_b !== b) begin
				$fatal(1, "%0s: palette expected #%02X R%02X G%02X B%02X, got #%02X R%02X G%02X B%02X",
					name, num, r, g, b, last_palette_num, last_palette_r, last_palette_g, last_palette_b);
			end
			$display("-- %0s: OK", name);
			palette_write_count = 0;
		end
	endtask

	initial begin
		clk = 1'b0;
		reset_n = 1'b0;
		bus_address = 3'd0;
		bus_ioreq = 1'b0;
		bus_write = 1'b0;
		bus_valid = 1'b0;
		bus_wdata = 8'd0;
		vram_ready = 1'b0;
		vram_rdata_en = 1'b0;
		last_register_num = 6'd0;
		last_register_data = 8'd0;
		register_write_count = 0;
		last_palette_num = 8'd0;
		last_palette_r = 5'd0;
		last_palette_g = 5'd0;
		last_palette_b = 5'd0;
		palette_write_count = 0;
		repeat (3) @(posedge clk);
		#1;
		reset_n = 1'b1;
		repeat (3) @(posedge clk);
		#1;

		$display("[test001] Normal port#1 register write");
		write_register(6'd7, 8'h12);
		expect_backdrop(8'h12, "R#7 write");

		//	Fleet Commander II writes an odd byte count to port#1 and relies on this.
		$display("[test002] Port#0 write cancels pending port#1 1st byte");
		access_io(3'd1, 1'b1, 8'h34);
		access_io(3'd0, 1'b1, 8'hA5);
		write_register(6'd7, 8'h23);
		expect_backdrop(8'h23, "port#0 write");

		$display("[test003] Port#0 read cancels pending port#1 1st byte");
		access_io(3'd1, 1'b1, 8'h00);
		access_io(3'd1, 1'b1, 8'h00);
		access_io(3'd1, 1'b1, 8'h45);
		access_io(3'd0, 1'b0, 8'h00);
		write_register(6'd7, 8'h56);
		expect_backdrop(8'h56, "port#0 read");

		$display("[test004] Port#1 status read cancels pending port#1 1st byte");
		access_io(3'd1, 1'b1, 8'h67);
		access_io(3'd1, 1'b0, 8'h00);
		write_register(6'd7, 8'h78);
		expect_backdrop(8'h78, "port#1 read");

		$display("[test005] Port#2 1st byte keeps pending port#1 and replaces its data");
		write_register(6'd16, 8'h01);
		palette_write_count = 0;
		access_io(3'd1, 1'b1, 8'h89);
		access_io(3'd2, 1'b1, 8'h77);
		register_write_count = 0;
		access_io(3'd1, 1'b1, 8'h87);
		if (register_write_count !== 1 || last_register_num !== 6'd7) begin
			$fatal(1, "port#2 write: port#1 2nd byte was not a register write (count=%0d num=%0d)", register_write_count, last_register_num);
		end
		expect_backdrop(8'h77, "port#2 write");
		access_io(3'd2, 1'b1, 8'h07);
		expect_palette9938(4'd1, 8'h77, 8'h07, "palette after port#1 register write");

		$display("[test006] Port#3 write keeps pending port#1 and replaces its data");
		write_register(6'd17, 8'h87);
		access_io(3'd1, 1'b1, 8'h9A);
		access_io(3'd3, 1'b1, 8'h0B);
		expect_backdrop(8'h0B, "port#3 indirect R#7");
		access_io(3'd1, 1'b1, 8'h86);
		if (reg_sprite_pattern_generator_table_base !== 7'h0B) begin
			$fatal(1, "port#3 write: R#6 expected 0B, got %02X", reg_sprite_pattern_generator_table_base);
		end
		$display("-- port#3 write: OK");

		$display("[test007] Port#1 1st byte replaces pending palette R/B");
		write_register(6'd16, 8'h03);
		palette_write_count = 0;
		access_io(3'd2, 1'b1, 8'h12);
		access_io(3'd1, 1'b1, 8'h34);
		access_io(3'd1, 1'b1, 8'h87);
		expect_backdrop(8'h34, "R#7 between palette bytes");
		if (palette_write_count !== 0) $fatal(1, "R#7 write completed a palette entry");
		access_io(3'd2, 1'b1, 8'h05);
		expect_palette9938(4'd3, 8'h34, 8'h05, "palette R/B from port#1 1st byte");

		$display("[test008] Port#3 write replaces pending palette R/B");
		access_io(3'd2, 1'b1, 8'h11);
		access_io(3'd3, 1'b1, 8'h62);
		expect_backdrop(8'h62, "port#3 R#7 between palette bytes");
		access_io(3'd2, 1'b1, 8'h03);
		expect_palette9938(4'd4, 8'h62, 8'h03, "palette R/B from port#3");

		$display("[test009] R#16 write restarts palette byte counter");
		access_io(3'd2, 1'b1, 8'h70);
		write_register(6'd16, 8'h05);
		access_io(3'd2, 1'b1, 8'h21);
		if (palette_write_count !== 0) $fatal(1, "palette completed right after R#16 write");
		access_io(3'd2, 1'b1, 8'h04);
		expect_palette9938(4'd5, 8'h21, 8'h04, "palette after R#16 write");

		$display("[test010] Status read does not reset palette byte counter");
		access_io(3'd2, 1'b1, 8'h56);
		access_io(3'd1, 1'b0, 8'h00);
		access_io(3'd2, 1'b1, 8'h01);
		expect_palette9938(4'd6, 8'h56, 8'h01, "palette across status read");

		$display("[test011] Extended palette keeps its own byte counter");
		access_io(3'd4, 1'b1, 8'h00);
		write_register(6'd20, 8'h10);
		if (reg_ext_palette_mode !== 1'b1) $fatal(1, "extended palette mode was not enabled");
		write_register(6'd16, 8'h40);
		access_io(3'd2, 1'b1, 8'h1F);
		access_io(3'd1, 1'b1, 8'h55);
		access_io(3'd2, 1'b1, 8'h0A);
		access_io(3'd3, 1'b1, 8'h66);
		access_io(3'd2, 1'b1, 8'h03);
		expect_palette(8'h40, 5'h1F, 5'h0A, 5'h03, "extended palette unaffected by data latch");
		access_io(3'd1, 1'b1, 8'h87);
		expect_backdrop(8'h66, "port#1 pair across extended palette");

		$display("[test012] R#16 write restarts extended palette byte counter");
		access_io(3'd2, 1'b1, 8'h01);
		access_io(3'd2, 1'b1, 8'h02);
		write_register(6'd16, 8'h41);
		access_io(3'd2, 1'b1, 8'h02);
		access_io(3'd2, 1'b1, 8'h03);
		if (palette_write_count !== 0) $fatal(1, "extended palette completed right after R#16 write");
		access_io(3'd2, 1'b1, 8'h04);
		expect_palette(8'h41, 5'h02, 5'h03, 5'h04, "extended palette after R#16 write");

		$display("Port#1 latch reset test PASSED");
		$finish;
	end
endmodule
