create_clock -period 20.000 [get_ports clk]
create_clock -period 20.000 [get_ports adc_clk_in]
create_clock -name altera_reserved_tck -period 100 [get_ports altera_reserved_tck]

derive_pll_clocks -create_base_clocks
derive_clock_uncertainty

set_input_delay -clock adc_clk_in -max 5 [get_ports {adc_data*}]
set_input_delay -clock adc_clk_in -min 1 [get_ports {adc_data*}] -add_delay

#set_output_delay -clock [get_clocks adc_clk] -max 2 [get_ports DAC_*]
#set_output_delay -clock [get_clocks adc_clk] -min -1 [get_ports DAC_*] -add_delay

#set_output_delay -clock clk -min 0 [get_ports {ADC_sclk_A ADC_sclk_B}]
#set_output_delay -clock clk -max 1 [get_ports {ADC_sclk_A ADC_sclk_B}]

set_false_path -from [get_pins -hierarchical {*}] -to [get_ports linduino_cs]
set_false_path -from [get_pins -hierarchical {*}] -to [get_ports linduino_mosi]
set_false_path -from [get_pins -hierarchical {*}] -to [get_ports linduino_sck]
set_false_path -from [get_ports linduino_miso]    -to [get_pins -hierarchical {*}]

set_false_path -to [get_ports gpo0]
set_false_path -to [get_ports gpo1]


# Asynchronous I/O.
set_false_path -from [get_ports {KEY*}]    -to [get_pins -hierarchical {*}]
set_false_path -from [get_ports {KEY*}]    -to [get_ports              {*}]

set_false_path -from [get_ports              {*}] -to [get_ports {LED*}]
set_false_path -from [get_pins -hierarchical {*}] -to [get_ports {LED*}]

set_false_path -from [get_ports sda]    -to [get_pins -hierarchical {*}]
set_false_path -from [get_ports scl]    -to [get_pins -hierarchical {*}]
set_false_path -from [get_pins -hierarchical {*}] -to [get_ports sda]
set_false_path -from [get_pins -hierarchical {*}] -to [get_ports scl]



 
 
## *********************************************************************************
## JTAG
## *********************************************************************************
# Constrain the NTRST port
#set_input_delay -clock altera_reserved_tck 20 [get_ports altera_reserved_ntrst]
# Constrain the TDI port
set_input_delay -clock altera_reserved_tck 20 [get_ports altera_reserved_tdi]
# Constrain the TMS port
set_input_delay -clock altera_reserved_tck 20 [get_ports altera_reserved_tms]
# Constrain the TDO port
set_output_delay -clock altera_reserved_tck 20 [get_ports altera_reserved_tdo]