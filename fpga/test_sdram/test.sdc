# test.sdc — relojes del TEST HDMI (mismos nombres de instancia que el core)
create_clock -name clk_in -period 20.000 [get_ports {ex_clk_27m}]
create_clock -name clk_108m -period 9.260  [get_pins {pll_main/u_pll/PLLA_inst/CLKOUT0}]
create_clock -name clk_54m  -period 18.520 [get_pins {pll_main/u_pll/PLLA_inst/CLKOUT1}]
create_clock -name clk_135m -period 7.408  [get_pins {pll_main/u_pll/PLLA_inst/CLKOUT3}]
create_generated_clock -name clk_27m -source [get_pins {pll_main/u_pll/PLLA_inst/CLKOUT3}] -master_clock clk_135m -divide_by 5 [get_pins {div5_video/CLKOUT}]

# --- Recovery del RESET de los OSER10 (54->135, mismo PLLA) ---
# rst_n=&por_cnt se suelta UNA vez al arrancar; los OSER10 se alinean solos
# con el par PCLK/FCLK del CLKDIV (estructura nestang validada en placa).
# OJO: estas violaciones NO aparecen en el resumen por-reloj del informe tr,
# solo en la Path Slacks Table (seccion recovery).
set_false_path -from [get_pins {por_cnt_*_s0/Q}] -to [get_pins {serializer/gwSer*/RESET}]
