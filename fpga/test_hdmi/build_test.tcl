# build_test.tcl — bitstream de TEST HDMI (barras) para la Console 60K
# Uso: cd fpga && gw_sh.exe test_hdmi/build_test.tcl   (se lanza desde fpga/)
set_device -name GW5AT-60B GW5AT-LV60PG484AC1/I0

add_file test_hdmi/hdmi_test_top.v
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

# constraints propios del test (el CST del core FALLA con nets ausentes: CT1135)
add_file test_hdmi/test.cst
add_file test_hdmi/test.sdc

set_option -use_jtag_as_gpio 1 -use_done_as_gpio 1 -use_ready_as_gpio 1 -top_module top -verilog_std sysv2017
set_option -place_option 2
set_option -route_option 2

run syn
run pnr
