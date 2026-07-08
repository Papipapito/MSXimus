module fpga_companion (
    input        clk,
    input        reset,

    // internal SPI to on-board BL616
    // (Console 60K: puertos m0s del dock M0S externo eliminados)
    input	spi_sclk,
    input	spi_csn,
    output	spi_dir,
    input	spi_dat,
    output	spi_irqn,

    //USB keyboard data
    output [127:0] keyboard,
    output [7:0] joystick0,
    output [7:0] joystick0_console,
    output [7:0] joystick1,
    output [23:0] ws2812_color,
    output dbg_hid_strobe     // sonda bring-up: bytes HID llegando del MCU
);

assign dbg_hid_strobe = mcu_hid_strobe;

wire mcu_hid_strobe;
wire mcu_sys_strobe;
wire mcu_osd_strobe;
wire mcu_sdc_strobe;

wire mcu_start;
wire spi_intn;
wire [7:0] mcu_data_out;
wire [7:0] sys_data_out;
wire [7:0] hid_data_out;

// -------------------------- MCU interface -----------------------
// intn and dout are outputs driven by the FPGA to the MCU
// din, ss and clk are inputs coming from the MCU
// onboard connection to on-board BL616

assign spi_dir = spi_io_dout;
assign spi_irqn = spi_intn;

// Console 60K: solo el BL616 onboard (sin mux spi_ext ni dock M0S externo);
// el SPI interno se conecta directo a los puertos spi_* onboard
wire spi_io_din = spi_dat;
wire spi_io_ss = spi_csn;
wire spi_io_clk = spi_sclk;

mcu_spi mcu (
        .clk(clk),
        .reset(reset),

        .spi_io_ss(spi_io_ss),
        .spi_io_clk(spi_io_clk),
        .spi_io_din(spi_io_din),
        .spi_io_dout(spi_io_dout),

        .mcu_sys_strobe(mcu_sys_strobe),
        .mcu_hid_strobe(mcu_hid_strobe),
        .mcu_osd_strobe(mcu_osd_strobe),
        .mcu_sdc_strobe(mcu_sdc_strobe),
        .mcu_start(mcu_start),
        .mcu_dout(mcu_data_out),
        .mcu_sys_din(sys_data_out),
        .mcu_hid_din(hid_data_out),
        .mcu_osd_din(8'b00000000),
        .mcu_sdc_din(8'b00000000)
        );

wire [7:0] int_ack;
wire hid_int;
wire hid_iack = int_ack[1];

hid hid_inst (
        .clk(clk),
        .reset(reset),

         // interface to receive user data from MCU (mouse, kbd, ...)
        .data_in_strobe(mcu_hid_strobe),
        .data_in_start(mcu_start),
        .data_in(mcu_data_out),
        .data_out(hid_data_out),

        // input local db9 port events to be sent to MCU. Changes also trigger
        // an interrupt, so the MCU doesn't have to poll for joystick events
        //.db9_port( db9_joy ),
        .irq( hid_int ),
        .iack( hid_iack ),

        //.mouse(hid_mouse),
        .keyboard(keyboard),
        .joystick0(joystick0),
        .joystick0_console(joystick0_console),
        .joystick1(joystick1)
         );   


sysctrl sysctrl (
        .clk(clk),
        .reset(reset),

         // interface to send and receive generic system control
        .data_in_strobe(mcu_sys_strobe),
        .data_in_start(mcu_start),
        .data_in(mcu_data_out),
        .data_out(sys_data_out),

        
        .int_out_n(spi_intn),
        .int_in( { 4'b0000, 1'b0, 1'b0, hid_int, 1'b0 }),
        .int_ack( int_ack ),

        .buttons( {1'b0, 1'b0} ),
        .leds(system_leds),
        .color(ws2812_color)
         );   

endmodule