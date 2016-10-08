# Onboard 50MHz clock, used for Qsys blob. Always present.
create_clock -period 20.000 [get_ports clk]
# 50MHz from LTC6954 divider.
create_clock -period 20.000 [get_ports adc_clk_in]
# Virtual clock for LTC1668 DACs. Delayed by 5ns (same as advanced by 15ns)
# such that data has an extra 5ns to meet 4ns minimum hold time.
create_clock -name ext_dac_clk -period 20.000# -waveform {5 15}

#create_clock -period 20000 [get_ports {KEY[0]}]

#derive_pll_clocks -create_base_clocks
derive_pll_clocks -create_base_clocks -use_net_name
derive_clock_uncertainty

# Constrain to meet 8ns setup time
set_output_delay -clock [get_clocks ext_dac_clk] -max 8 [get_ports {DAC_*}]
# Constrain to meet 4ns hold time
set_output_delay -clock [get_clocks ext_dac_clk] -min 4 [get_ports {DAC_*}] -add_delay

#set_output_delay -clock clk -min 0 [get_ports {ADC_sclk_A ADC_sclk_B}]
#set_output_delay -clock clk -max 1 [get_ports {ADC_sclk_A ADC_sclk_B}]

create_generated_clock -name sclk_u1 -source [get_ports adc_clk]
# -edges {1 2 3} -edge_shift {0.5 0.5 0.5}
create_generated_clock -name sclk_u2 -source [get_ports adc_clk]
# -edges {1 2 3} -edge_shift {0.5 0.5 0.5}
create_generated_clock -name sclk_filt_u1 -source [get_ports adc_clk]
# -edges {1 2 3} -edge_shift {0.5 0.5 0.5}
create_generated_clock -name sclk_filt_u2 -source [get_ports adc_clk]
# -edges {1 2 3} -edge_shift {0.5 0.5 0.5}


set_false_path -to [get_ports sclk_u1]
set_false_path -to [get_ports sclk_u2]
set_false_path -to [get_ports sclk_filt_u1]
set_false_path -to [get_ports sclk_filt_u2]

# max delay of the LTC2380-24 is 8ns, experimenting
# around with various delays to see if stuff can break...

set_input_delay -clock sclk_u1 -max 5 [get_ports {sdo_u1}]
set_input_delay -clock sclk_u1 -min 2 [get_ports {sdo_u1}] -add_delay
set_input_delay -clock sclk_filt_u1 -max 5 [get_ports {sdo_filt_u1}]
set_input_delay -clock sclk_filt_u1 -min 2 [get_ports {sdo_filt_u1}] -add_delay

set_input_delay -clock sclk_u2 -max 5 [get_ports {sdo_u2}]
set_input_delay -clock sclk_u2 -min 2 [get_ports {sdo_u2}] -add_delay
set_input_delay -clock sclk_filt_u2 -max 5 [get_ports {sdo_filt_u2}]
set_input_delay -clock sclk_filt_u2 -min 2 [get_ports {sdo_filt_u2}] -add_delay


#set_output_delay -clock [get_clocks sclk_filt_u1] -max 2 [get_ports sdi_filt_u1]
#set_output_delay -clock [get_clocks sclk_filt_u1] -min -10 [get_ports sdi_filt_u1] -add_delay
#set_output_delay -clock [get_clocks sclk_filt_u2] -max 2 [get_ports sdi_filt_u2]
#set_output_delay -clock [get_clocks sclk_filt_u2] -min -10 [get_ports sdi_filt_u2] -add_delay

# Cut paths to slow SPI port, GPOs.
set_false_path -to [get_ports ltc6954_sync]
set_false_path -to [get_ports ltc6954_cs]
set_false_path -to [get_ports ltc6954_sck]
set_false_path -to [get_ports ltc6954_sdi]
set_false_path -to [get_ports ltc6954_sdo]
    
set_false_path -to [get_ports gpo0]
set_false_path -to [get_ports gpo1]


# Asynchronous I/O
set_false_path -from [get_ports {KEY*}]    -to [get_pins -hierarchical {*}]

set_false_path -from [get_ports              {*}] -to [get_ports {LED*}]
set_false_path -from [get_pins -hierarchical {*}] -to [get_ports {LED*}]
#set_false_path -to [get_ports {KEY*}]
#set_false_path -to [get_ports {LED*}]