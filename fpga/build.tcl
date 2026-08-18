# ============================================================================
#  build.tcl — MSXnano port · Tang Console 60K (GW5AT-60)
#  Derivado del build.tcl del TN20K (108 add_file) con los cambios del port:
#   - device GW5AT-LV60PG484AC1/I0
#   - IPs de reloj GW2A (clk_108p, clkdiv, clkdiv2, clk_135) SUSTITUIDAS por
#     un unico Gowin_PLL (PLLA, 4 salidas: 108/54/27/135 exactos) + PLL_INIT
#   - constraints nuevos (msx_console60k.cst/.sdc)
#  Uso: cd fpga && gw_sh.exe build.tcl
# ============================================================================
set_device -name GW5AT-60B GW5AT-LV60PG484AC1/I0

# ----- Verilog -----
# F2 (_82): MoonSound FM — core OPL3 de gtaylormb (fork antxiko/mangOPL4 con
# fixes de Gowin, LGPL-3.0). El PAQUETE va PRIMERO (SystemVerilog).
add_file opl3/opl3_pkg.sv
add_file opl3/afifo.v
add_file opl3/calc_envelope_shift.sv
add_file opl3/calc_phase_inc.sv
add_file opl3/calc_rhythm_phase.sv
add_file opl3/channels.sv
add_file opl3/clk_div.sv
add_file opl3/control_operators.sv
add_file opl3/dac_prep.sv
add_file opl3/edge_detector.sv
add_file opl3/envelope_generator.sv
add_file opl3/host_if.sv
add_file opl3/ksl_add_rom.sv
add_file opl3/leds.sv
add_file opl3/mem_multi_bank.sv
add_file opl3/mem_multi_bank_reset.sv
add_file opl3/mem_simple_dual_port.sv
add_file opl3/mem_simple_dual_port_async_read.sv
add_file opl3/mem_simple_dual_port_bram.sv
add_file opl3/operator.sv
add_file opl3/opl3.sv
add_file opl3/opl3_exp_lut.sv
add_file opl3/opl3_log_sine_lut.sv
add_file opl3/phase_generator.sv
add_file opl3/pipeline_sr.sv
add_file opl3/reset_sync.sv
add_file opl3/synchronizer.sv
add_file opl3/timer.sv
add_file opl3/timers.sv
add_file opl3/tremolo.sv
add_file opl3/trick_sw_detection.sv
add_file opl3/vibrato.sv
add_file src/opl4fm.v
# _104: la wave vive en la SDRAM del dock (DDR3 del SOM fuera del build —
# analogicamente marginal en esta placa, saga _94-_103)
add_file src/wave_sdram.v
# F2 (_89): motor PCM 24 slots del OPL4 (srg320, BSD-3/MAME, con permiso).
# ymf278b_gowin.v es GENERADO por sv2v desde opl4wave/*.sv (ver convert.sh)
add_file opl4wave/ymf278b_gowin.v
add_file src/opl4_pcm.v
add_file jtopl/jt2413.v
add_file jtopl/jtopl.v
add_file jtopl/jtopl2.v
add_file jtopl/jtopl_acc.v
add_file jtopl/jtopl_csr.v
add_file jtopl/jtopl_div.v
add_file jtopl/jtopl_eg.v
add_file jtopl/jtopl_eg_cnt.v
add_file jtopl/jtopl_eg_comb.v
add_file jtopl/jtopl_eg_ctrl.v
add_file jtopl/jtopl_eg_final.v
add_file jtopl/jtopl_eg_pure.v
add_file jtopl/jtopl_eg_step.v
add_file jtopl/jtopl_exprom.v
add_file jtopl/jtopl_lfo.v
add_file jtopl/jtopl_logsin.v
add_file jtopl/jtopl_mmr.v
add_file jtopl/jtopl_noise.v
add_file jtopl/jtopl_op.v
add_file jtopl/jtopl_pg.v
add_file jtopl/jtopl_pg_comb.v
add_file jtopl/jtopl_pg_inc.v
add_file jtopl/jtopl_pg_rhy.v
add_file jtopl/jtopl_pg_sum.v
add_file jtopl/jtopl_pm.v
add_file jtopl/jtopl_reg.v
add_file jtopl/jtopl_reg_ch.v
add_file jtopl/jtopl_sh.v
add_file jtopl/jtopl_sh_rst.v
add_file jtopl/jtopl_single_acc.v
add_file jtopl/jtopl_slot_cnt.v
add_file jtopl/jtopl_timers.v
add_file jtopl/jtopll_mmr.v
add_file jtopl/jtopll_reg.v
add_file jtopl/jtopll_reg_ch.v
add_file jt10/jt10_adpcmb.v
add_file jt10/jt10_adpcmb_interpol.v
add_file jt10/jt10_adpcm_div.v
add_file src/y8950_adpcm.v
# _159: RAM de muestras del ADPCM-B (256KB) en la SDRAM via puerto wv2
add_file src/adpcm_sdram.v
add_file src/flash_rw.v
add_file src/megaram.v
add_file src/scc_wave2_ghdl.v
add_file src/scc_glue.v
add_file src/scc_wave2v.v
add_file src/memory.v
add_file src/fan_ctrl.v
add_file src/dbg_uart.v
add_file src/ro_osc.v
add_file src/ocm/kanji.v
add_file src/ocm/rtc.v
add_file src/psg_filter.v
add_file src/msx_mouse.v
add_file src/ws2812.v
add_file src/wondertang/crc16.v
add_file src/wondertang/dpram.v
add_file src/wondertang/pinfilter.v
add_file src/wondertang/sd_reader.sv
add_file src/wondertang/sdcmd_ctrl.sv
# ----- F1 V9968: variable del build (0 = VDP clasico tn_vdp, 1 = V9968).
# DEBE ir en sintonia con el `define ENABLE_V9968_VDP de top.v (el clon del
# build _117+ pone ambos a 1 via sed). Los hdmi/*.sv van SIEMPRE (ambos
# puentes los usan); el arbol tn_vdp solo entra en el build clasico
# (colision de nombre vdp/VDP con el core V9968 + ahorro de CLS).
set USE_V9968 0
set USE_VRAM_DDR3 0
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
if {!$USE_V9968} {
    add_file tn_vdp_v3_v9958/src/clockdiv.v
    add_file tn_vdp_v3_v9958/src/v9958_top.v
}
if {$USE_V9968} {
    # core V9968 de HRA! (rev 5978d18, parche tag+eco — ver v9968/ORIGEN.txt)
    add_file v9968/vdp.v
    add_file v9968/vdp_color_palette.v
    add_file v9968/vdp_color_palette_ram.v
    add_file v9968/vdp_command.v
    add_file v9968/vdp_command_cache.v
    add_file v9968/vdp_cpu_interface.v
    add_file v9968/vdp_sprite_divide_table.v
    add_file v9968/vdp_sprite_info_collect.v
    add_file v9968/vdp_sprite_makeup_pixel.v
    add_file v9968/vdp_sprite_select_visible_planes.v
    add_file v9968/vdp_timing_control.v
    add_file v9968/vdp_timing_control_screen_mode.v
    add_file v9968/vdp_timing_control_sprite.v
    add_file v9968/vdp_timing_control_ssg.v
    add_file v9968/vdp_upscan.v
    add_file v9968/vdp_upscan_line_buffer.v
    add_file v9968/vdp_video_double_buffer.v
    add_file v9968/vdp_video_out.v
    add_file v9968/vdp_video_out_bilinear.v
    add_file v9968/vdp_video_ram_line_buffer.v
    add_file v9968/vdp_vram_interface.v
    # pila MSXimus: shim VRAM + bridge CDC + glue CPU + PLL 85.909 + puente 800px
    add_file src/v9968_vram_shim.v
    add_file src/v9968_sdram_bridge.v
    add_file src/v9968_cpu_glue.v
    add_file src/pll_86.v
    add_file video720/msx2hdmi_v9968.sv
    # _128X (USE_VRAM_DDR3): VRAM del V9968 en la DDR3 del SOM — IP + PLL 297
    # + danza mDRP (los mismos ficheros de la era wave _86) + backend nuevo.
    # El define ENABLE_VRAM_DDR3 de top.v gobierna el RTL; esto solo compila.
    if {$USE_VRAM_DDR3} {
        add_file ddr3/ddr3_memory_interface.v
        add_file ddr3/pll_ddr3.v
        add_file ddr3/pll_mDRP_intf.v
        add_file src/v9968_ddr3_backend.v
    }
}
add_file top.v

# ----- Reloj GW5A: un solo PLLA (108/54/27/135) + secuencia de init mDRP -----
add_file msx_console60k/src/gowin_pll/gowin_pll.v
add_file msx_console60k/src/gowin_pll/gowin_pll_mod.v
add_file msx_console60k/src/pll_init.v

# ----- USB subsystem (BL616 FPGA Companion, onboard — sin dock M0S) -----
# NOTE: add mcu_spi_new.v ONLY (mcu_spi.v has a colliding "module mcu_spi").
add_file src/usb/fpga_companion.v
add_file src/usb/hid.v
add_file src/usb/mcu_spi_new.v
add_file src/usb/sys_ctrl.v
add_file src/usb/usb_keyboard_msx.vhd

# ----- VHDL -----
add_file G80A/T80s.vhd
add_file G80A/g80a.vhd
add_file G80A/t80.vhd
add_file G80A/t80_alu.vhd
add_file G80A/t80_mcode.vhd
add_file G80A/t80_pack.vhd
add_file G80A/t80_reg.vhd
add_file PSG_YM2149/YM2149.vhdl
add_file denoise/denoise.vhd
add_file monostable/monostable.vhd
add_file src/ocm/fifo.vhd
add_file src/ocm/lpf.vhd
# v3.6 (_47): scc_wave2 ahora entra como VERILOG generado por GHDL (abajo);
# el .vhd queda en el arbol como fuente de verdad (regenerar con GHDL al tocarlo)
# add_file src/ocm/scc_wave2.vhd
add_file src/ocm/swioports.vhd
add_file src/ocm/uart_lite.vhd
add_file src/ocm/wifi_lite.vhd
# ram.vhd = modulo GENERICO 'ram' usado tambien por el RTC (src/ocm/rtc.v):
# va SIEMPRE, aunque viva en el arbol tn_vdp (el V9968 no define ningun 'ram')
add_file tn_vdp_v3_v9958/src/ram.vhd
if {!$USE_V9968} {
    add_file tn_vdp_v3_v9958/src/vdp/vdp.vhd
    add_file tn_vdp_v3_v9958/src/vdp/vdp_colordec.vhd
    add_file tn_vdp_v3_v9958/src/vdp/vdp_command.vhd
    add_file tn_vdp_v3_v9958/src/vdp/vdp_doublebuf.vhd
    add_file tn_vdp_v3_v9958/src/vdp/vdp_graphic123m.vhd
    add_file tn_vdp_v3_v9958/src/vdp/vdp_graphic4567.vhd
    add_file tn_vdp_v3_v9958/src/vdp/vdp_hvcounter.vhd
    add_file tn_vdp_v3_v9958/src/vdp/vdp_interrupt.vhd
    add_file tn_vdp_v3_v9958/src/vdp/vdp_linebuf.vhd
    add_file tn_vdp_v3_v9958/src/vdp/vdp_ntsc_pal.vhd
    add_file tn_vdp_v3_v9958/src/vdp/vdp_package.vhd
    add_file tn_vdp_v3_v9958/src/vdp/vdp_register.vhd
    add_file tn_vdp_v3_v9958/src/vdp/vdp_spinforam.vhd
    add_file tn_vdp_v3_v9958/src/vdp/vdp_sprite.vhd
    add_file tn_vdp_v3_v9958/src/vdp/vdp_ssg.vhd
    add_file tn_vdp_v3_v9958/src/vdp/vdp_text12.vhd
    add_file tn_vdp_v3_v9958/src/vdp/vdp_vga.vhd
    add_file tn_vdp_v3_v9958/src/vdp/vdp_wait_control.vhd
    add_file tn_vdp_v3_v9958/src/vdp/vencode.vhd
}

# ----- v3.0 FASE 1-REDUX: video 720p (cadena monitorcore + puente ring-BRAM) -----
add_file video720/plla/pll_27.v
add_file video720/plla/pll_74.v
add_file video720/msx2hdmi.sv

# ----- F3 (_39): teclado USB-A directo (usb_hid_host de nand2mario + decoder) -----
add_file src/usb_direct/usb_hid_host.v
add_file src/usb_direct/pll_12.v
add_file src/usb_direct/usb_kbd_decode.v

# ----- Constraints (nuevos del 60K — verificar matches>0 tras el 1er PnR) -----
add_file constraints/msx_console60k.cst
if {$USE_V9968} {
    # Gowin procesa cada .sdc AISLADO (los relojes del principal no se ven
    # desde otro fichero -> TA2004): se genera un SDC COMBINADO principal +
    # fragmento V9968 (constraints/msx_v9968.sdc) y se añade SOLO ese.
    # Ajustes al principal (TA2003 = ERROR con matches vacios, leccion vieja):
    #  1. fuera toda linea que referencie vdp4/ (el arbol tn_vdp no esta);
    #  2. fuera los generated clocks de dh/dl Y sus referencias en los
    #     grupos: en este build dh/dl son DATOS 108M-nativos (divisor libre);
    #     Gowin valida la derivacion y el assign se renombra en sintesis;
    #  3. fuera la referencia a clock_audio en los grupos (su create_clock
    #     cae con el filtro vdp4).
    set fp_a [open constraints/msx_console60k.sdc r]
    set sdc_a [read $fp_a]
    close $fp_a
    # ORDEN: primero el filtro de LINEAS (create_generated intactas para
    # casar), despues los regsub de TOKENS sueltos en las lineas de grupos
    set sdc_f {}
    foreach ln [split $sdc_a "\n"] {
        if {[string match {*vdp4/*} $ln] ||
            [string match {create_generated_clock -name clock_VideoD*} $ln] ||
            [string match {*mem1/vram_dout_*} $ln]} {
            append sdc_f "# (V9968: filtrada) $ln\n"
        } else {
            append sdc_f "$ln\n"
        }
    }
    regsub -all -- { clock_VideoDHClk} $sdc_f {} sdc_f
    regsub -all -- { clock_VideoDLClk} $sdc_f {} sdc_f
    regsub -all -- {-group \[get_clocks \{clock_audio\}\] } $sdc_f {} sdc_f
    set fp_b [open constraints/msx_v9968.sdc r]
    set sdc_b [read $fp_b]
    close $fp_b
    set fp_o [open constraints/msx_v9968_combined.sdc w]
    puts $fp_o $sdc_f
    puts $fp_o $sdc_b
    if {$USE_VRAM_DDR3} {
        # _128X: relojes de la DDR3 (nombres/pines de la era wave _86 con la
        # instancia u_vddr3). Solo cuando la IP esta en el build: con matches
        # vacios el create_clock seria TA2003/TA2004.
        puts $fp_o "create_clock -name ddr_clk4x -period 3.367 -waveform {0 1.684} \[get_pins {u_vddr3/pll_ddr3_inst/PLLA_inst/CLKOUT2}\]"
        puts $fp_o "create_clock -name ddr_clk1x -period 13.47 -waveform {0 6.734} \[get_pins {u_vddr3/u_ddr3/gw3_top/u_ddr_phy_top/fclkdiv/CLKOUT}\]"
        puts $fp_o "set_clock_groups -asynchronous -group \[get_clocks {ddr_clk4x ddr_clk1x}\] -group \[get_clocks {clk_86}\] -group \[get_clocks {clk_in clk_108m clk_54m clk_27m clk_135m eng_clk375}\] -group \[get_clocks {clk27_video clk_hdmi clk_hdmi5}\]"
    }
    close $fp_o
    add_file constraints/msx_v9968_combined.sdc
} else {
    add_file constraints/msx_console60k.sdc
}

# Pines dedicados liberados como GPIO (60K): JTAG=SPI del BL616 onboard;
# MSPI+CPU=flash compartida; DONE/READY=los 2 LEDs onboard (como C64Nano).
set_option -use_sspi_as_gpio 1 -use_mspi_as_gpio 1 -use_jtag_as_gpio 1 -use_cpu_as_gpio 1 -use_done_as_gpio 1 -use_ready_as_gpio 1 -top_module top -verilog_std sysv2017 -include_path src
# era v3 (medido en v3b010 vs v3b007/8, mismo RTL): place_option 1 deja
# 92-842 nets sin rutar donde el 2 dejaba 1.5-2.2K — con el netlist
# denso en FF/mux post-SSRAM, el placer 1 congestiona menos. Default.
set_option -place_option 1
# maxfan 50: probado en v3b013/15 — mejora nets-sin-rutar en solitario
# (72-570 vs 677-2219) pero su coste en area anulo el yield combinado
# (v3b015 0/6 vs v3b012 2/6 sin el). FUERA del default; palanca en
# reserva para netlists futuros mas ligeros.
set_option -route_option 2
# era v3: route_option 1->2 tras el PR0004 de v3b005 (12-15K nets sin
# rutar con la full ya colocada): maximo esfuerzo del router 1.9.12.

run syn
run pnr
