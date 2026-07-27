#!/bin/bash
# run_audio_ce.sh — compila y corre tb_audio_ce (validacion del fix _127I)
# Patron de run_battery.sh: Verilator --binary --timing en WSL.
set -e
M=/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958
H=$M/fpga/tn_vdp_v3_v9958/src/hdmi
cd /tmp && rm -rf audio_ce_tb && mkdir audio_ce_tb && cd audio_ce_tb
verilator --binary --timing -j 8 -Wno-fatal -Wno-BLKANDNBLK \
    --top-module tb_audio_ce \
    $M/tools/v9968_sim/tb_audio_ce.sv \
    $H/hdmi.sv \
    $H/packet_picker.sv \
    $H/packet_assembler.sv \
    $H/audio_clock_regeneration_packet.sv \
    $H/audio_info_frame.sv \
    $H/audio_sample_packet.sv \
    $H/auxiliary_video_information_info_frame.sv \
    $H/source_product_description_info_frame.sv \
    $H/tmds_channel.sv > verilate.log 2>&1 || { tail -30 verilate.log; exit 1; }
timeout 600 ./obj_dir/Vtb_audio_ce
