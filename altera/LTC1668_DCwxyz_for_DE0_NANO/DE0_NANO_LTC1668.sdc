#************************************************************
# THIS IS A WIZARD-GENERATED FILE.                           
#
# Version 12.1 Build 243 01/31/2013 Service Pack 1 SJ Web Edition
#
#************************************************************

# Copyright (C) 1991-2012 Altera Corporation
# Your use of Altera Corporation's design tools, logic functions 
# and other software and tools, and its AMPP partner logic 
# functions, and any output files from any of the foregoing 
# (including device programming or simulation files), and any 
# associated documentation or information are expressly subject 
# to the terms and conditions of the Altera Program License 
# Subscription Agreement, Altera MegaCore Function License 
# Agreement, or other applicable license agreement, including, 
# without limitation, that your use is for the sole purpose of 
# programming logic devices manufactured by Altera and sold by 
# Altera or its authorized distributors.  Please refer to the 
# applicable agreement for further details.



# Clock constraints

create_clock -name "CLK_50" -period 20.000ns [get_ports {CLK_50}]


# Automatically constrain PLL and other generated clocks
derive_pll_clocks -create_base_clocks

# Automatically calculate clock uncertainty to jitter and other effects.
derive_clock_uncertainty

# tsu/th constraints

set_input_delay -clock "CLK_50" -max 10ns [get_ports {CLK_50}] 
set_input_delay -clock "CLK_50" -min 10.000ns [get_ports {CLK_50}] 


# tco constraints

set_output_delay -clock "CLK_50" -max 10ns [get_ports {CLKOUT}] 
set_output_delay -clock "CLK_50" -min -10.000ns [get_ports {CLKOUT}] 


# tpd constraints

set_max_delay 10.000ns -from [get_ports {CLK_50}] -to [get_ports {CLKOUT}]


