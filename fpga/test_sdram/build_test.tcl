# build_test.tcl — AUTO-TEST de SDRAM (lanzar desde fpga/)
set_device -name GW5AT-60B GW5AT-LV60PG484AC1/I0

add_file test_sdram/test_sdram_top.v
add_file test_sdram/sdram_tester.v
add_file src/memory.v
add_file msx_console60k/src/gowin_pll/gowin_pll.v
add_file msx_console60k/src/gowin_pll/gowin_pll_mod.v
add_file msx_console60k/src/pll_init.v
add_file tn_vdp_v3_v9958/src/clockdiv.v
add_file tn_vdp_v3_v9958/src/hdmi/audio_clock_regeneration_packet.sv
add_file tn_vdp_v3_v9958/src/hdmi/audio_info_frame.sv
add_file tn_vdp_v3_v9958/src/hdmi/audio_sample_packet.sv
add_file tn_vdp_v3_v9958/src/hdmi/auxiliary_video_information_info_frame.sv
add_file tn_vdp_v3_v9958/src/hdmi/hdmi.sv
add_file tn_vdp_v3_v9958/src/hdmi/packet_assembler.sv
add_file tn_vdp_v3_v9958/src/hdmi/packet_picker.sv
add_file tn_vdp_v3_v9958/src/hdmi/serializer.sv
add_file tn_vdp_v3_v9958/src/hdmi/source_product_description_info_frame.sv
add_file tn_vdp_v3_v9958/src/hdmi/tmds_channel.sv

add_file test_sdram/test.cst
add_file test_sdram/test.sdc

set_option -use_jtag_as_gpio 1 -use_done_as_gpio 1 -use_ready_as_gpio 1 -top_module top -verilog_std sysv2017
set_option -place_option 2
set_option -route_option 2

run syn
run pnr
