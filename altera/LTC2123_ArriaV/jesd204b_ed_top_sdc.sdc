#**************************************************************
# Time Information
#**************************************************************


#**************************************************************
# Create Clock
#**************************************************************
# On-board USB Blaster II
create_clock -name altera_reserved_tck [get_ports {altera_reserved_tck}] -period 24MHz   

create_clock -name mgmt_clk -period 10 [get_ports mgmt_clk]

create_clock -name device_clk -period 8.0 [get_ports device_clk]

#**************************************************************
# Create Generated Clock
#**************************************************************
# Create the PLL Output clocks automatically
derive_pll_clocks

#**************************************************************
# Set Clock Groups
#**************************************************************
set_clock_groups -asynchronous \
-group {altera_reserved_tck} \
-group {device_clk \
u_jesd204b_ed|u_pll|core_pll_inst|altera_pll_i|arriav_pll|counter[0].output_counter|divclk \
u_jesd204b_ed|u_pll|core_pll_inst|altera_pll_i|arriav_pll|counter[1].output_counter|divclk \
} \
-group {mgmt_clk}

#**************************************************************
# Set Clock Uncertainty
#**************************************************************
derive_clock_uncertainty

#**************************************************************
# Set Input Delay
#**************************************************************
set_input_delay -clock altera_reserved_tck 5 [get_ports altera_reserved_tdi]
set_input_delay -clock altera_reserved_tck 5 [get_ports altera_reserved_tms]

#**************************************************************
# Set Output Delay
#**************************************************************
set_output_delay -clock altera_reserved_tck  5 [get_ports altera_reserved_tdo]

#**************************************************************
# Set False Path
#**************************************************************
set_false_path -from [get_clocks {mgmt_clk}] -to [get_clocks {device_clk}]
set_false_path -from [get_clocks {mgmt_clk}] -to [get_clocks {u_jesd204b_ed|u_pll|core_pll_inst|altera_pll_i|arriav_pll|counter[1].output_counter|divclk}]
