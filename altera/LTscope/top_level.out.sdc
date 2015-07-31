## Generated SDC file "top_level.out.sdc"

## Copyright (C) 1991-2014 Altera Corporation. All rights reserved.
## Your use of Altera Corporation's design tools, logic functions 
## and other software and tools, and its AMPP partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Altera Program License 
## Subscription Agreement, the Altera Quartus II License Agreement,
## the Altera MegaCore Function License Agreement, or other 
## applicable license agreement, including, without limitation, 
## that your use is for the sole purpose of programming logic 
## devices manufactured by Altera and sold by Altera or its 
## authorized distributors.  Please refer to the applicable 
## agreement for further details.


## VENDOR  "Altera"
## PROGRAM "Quartus II"
## VERSION "Version 14.1.0 Build 186 12/03/2014 SJ Full Version"

## DATE    "Wed Jun 03 15:29:45 2015"

##
## DEVICE  "5CGXFC5C6F27C7"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {adc_clk} -period 40.000 -waveform { 0.000 20.000 } [get_ports {adc_clk}]
create_clock -name {CLOCK_125_p} -period 8.000 -waveform { 0.000 4.000 } [get_ports {CLOCK_125_p}]
create_clock -name {usb_clock} -period 16.666 -waveform { 0.000 8.333 } [get_ports {usb_clock}]


#**************************************************************
# Create Generated Clock
#**************************************************************



#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

set_clock_uncertainty -rise_from [get_clocks {usb_clock}] -rise_to [get_clocks {usb_clock}] -setup 0.100  
set_clock_uncertainty -rise_from [get_clocks {usb_clock}] -rise_to [get_clocks {usb_clock}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {usb_clock}] -fall_to [get_clocks {usb_clock}] -setup 0.100  
set_clock_uncertainty -rise_from [get_clocks {usb_clock}] -fall_to [get_clocks {usb_clock}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {usb_clock}] -rise_to [get_clocks {CLOCK_125_p}]  0.120  
set_clock_uncertainty -rise_from [get_clocks {usb_clock}] -fall_to [get_clocks {CLOCK_125_p}]  0.120  
set_clock_uncertainty -fall_from [get_clocks {usb_clock}] -rise_to [get_clocks {usb_clock}] -setup 0.100  
set_clock_uncertainty -fall_from [get_clocks {usb_clock}] -rise_to [get_clocks {usb_clock}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {usb_clock}] -fall_to [get_clocks {usb_clock}] -setup 0.100  
set_clock_uncertainty -fall_from [get_clocks {usb_clock}] -fall_to [get_clocks {usb_clock}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {usb_clock}] -rise_to [get_clocks {CLOCK_125_p}]  0.120  
set_clock_uncertainty -fall_from [get_clocks {usb_clock}] -fall_to [get_clocks {CLOCK_125_p}]  0.120  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_125_p}] -rise_to [get_clocks {usb_clock}]  0.120  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_125_p}] -fall_to [get_clocks {usb_clock}]  0.120  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_125_p}] -rise_to [get_clocks {CLOCK_125_p}]  0.120  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_125_p}] -fall_to [get_clocks {CLOCK_125_p}]  0.120  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_125_p}] -rise_to [get_clocks {adc_clk}]  0.120  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_125_p}] -fall_to [get_clocks {adc_clk}]  0.120  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_125_p}] -rise_to [get_clocks {usb_clock}]  0.120  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_125_p}] -fall_to [get_clocks {usb_clock}]  0.120  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_125_p}] -rise_to [get_clocks {CLOCK_125_p}]  0.120  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_125_p}] -fall_to [get_clocks {CLOCK_125_p}]  0.120  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_125_p}] -rise_to [get_clocks {adc_clk}]  0.120  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_125_p}] -fall_to [get_clocks {adc_clk}]  0.120  
set_clock_uncertainty -rise_from [get_clocks {adc_clk}] -rise_to [get_clocks {CLOCK_125_p}]  0.120  
set_clock_uncertainty -rise_from [get_clocks {adc_clk}] -fall_to [get_clocks {CLOCK_125_p}]  0.120  
set_clock_uncertainty -rise_from [get_clocks {adc_clk}] -rise_to [get_clocks {adc_clk}] -setup 0.100  
set_clock_uncertainty -rise_from [get_clocks {adc_clk}] -rise_to [get_clocks {adc_clk}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {adc_clk}] -fall_to [get_clocks {adc_clk}] -setup 0.100  
set_clock_uncertainty -rise_from [get_clocks {adc_clk}] -fall_to [get_clocks {adc_clk}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {adc_clk}] -rise_to [get_clocks {CLOCK_125_p}]  0.120  
set_clock_uncertainty -fall_from [get_clocks {adc_clk}] -fall_to [get_clocks {CLOCK_125_p}]  0.120  
set_clock_uncertainty -fall_from [get_clocks {adc_clk}] -rise_to [get_clocks {adc_clk}] -setup 0.100  
set_clock_uncertainty -fall_from [get_clocks {adc_clk}] -rise_to [get_clocks {adc_clk}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {adc_clk}] -fall_to [get_clocks {adc_clk}] -setup 0.100  
set_clock_uncertainty -fall_from [get_clocks {adc_clk}] -fall_to [get_clocks {adc_clk}] -hold 0.060  


#**************************************************************
# Set Input Delay
#**************************************************************



#**************************************************************
# Set Output Delay
#**************************************************************



#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************



#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

