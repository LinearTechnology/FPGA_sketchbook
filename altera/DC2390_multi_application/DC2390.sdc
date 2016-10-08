# Onboard 50MHz clock, used for Qsys blob. Always present.
create_clock -period 20.000 [get_ports clk]
# 50MHz from LTC6954 divider. This comes from the DC2390 and is asynchronous
# to the onboard clock. I'm sure setting them as separate groups will generate some new
# and exciting errors. Note that there is really only a single signal that needs to be retimed
# and that is the trigger signal from the blob to the capture logic. There is a synchronizer to
# that does this. All other signals are static control, so a little glitchy when they switch
# is not a problem.
create_clock -period 20.000 [get_ports adc_clk_in]

# Virtual clock for LTC1668 DACs. Delayed by 5ns (same as advanced by 15ns)
# such that data has an extra 5ns to meet 4ns minimum hold time.
# STILL EXPERIMENTING WITH THIS!! The clock is currently configured for a delay
# of 15ns, which I believe is a waveform of {15 25}, but that breaks timing.
# what SHOULD happen is that the DAC sees a clock latch edge from the LTC6954 5ns BEFORE the FPGA sees the edge that
# will effectively be the launch edge (adc_clk_in, through PLL, to non-shifted output.)
# This may need a multicycle delay??

# (non-shifted for now...)
create_clock -name ext_dac_clk -period 20.000 -waveform {0 10}

# I believe this is all that needs to be done to properly define:
# adc_clk and adc_clk_shift??
derive_pll_clocks -create_base_clocks -use_net_name
derive_clock_uncertainty

# DAC constraints, straight from the LTC1668 datasheet.
#(For the record, I go around saying "Make the hold time requirement
# ZERO!!!" a lot. That's slowly gaining traction, but the LTC1668 is a 15+ year old part
# And still an awesome one.

# Constrain to meet 8ns setup time
set_output_delay -clock [get_clocks ext_dac_clk] -max 8 [get_ports {DAC_*}]
# Constrain to meet 4ns hold time
set_output_delay -clock [get_clocks ext_dac_clk] -min 4 [get_ports {DAC_*}] -add_delay


# Now for some more fun!! Create gated clocks from LTC2500 control modules. I followed the BeRadio
# constraint file as a guideline, since it uses a similar scheme.

# Question 1: Do I really need to poke all the way into the heirarchy to the output of the
# combinatorial block (which happens to be an AND gate?) Why can't you just point at the
# signal name at the top level?

# Question 2: Do you need to define any waveforms or anything here? I THINK the tool has
# enough information to do this - the phase shift of adc_clk_shift, and the propagation delay
# of the AND gate...

create_generated_clock -name sclk_u1 -source [get_pins {LTC2500_u1|sck_nyq~0|combout}]
create_generated_clock -name sclk_u2 -source [get_pins {LTC2500_u2|sck_nyq~0|combout}]
create_generated_clock -name sclk_filt_u1 -source [get_pins {LTC2500_u1|sck_filt~0|combout}]
create_generated_clock -name sclk_filt_u2 -source [get_pins {LTC2500_u2|sck_filt~0|combout}]

# Cut paths to generated clocks...
set_false_path -to [get_ports sclk_u1]
set_false_path -to [get_ports sclk_u2]
set_false_path -to [get_ports sclk_filt_u1]
set_false_path -to [get_ports sclk_filt_u2]

# LTC2500 timing summary, data on SDOx FROM LTC2500 TO FPGA:
# Current data stays valid for a minimum of 1ns after a rising clock edge
# Next data is valid a maximum of 8.5ns after a rising clock edge (timing identical for 2.5V, 5V OVdd, we're using 3.3V.)

# LTC2500 timing summary, data on SDI FROM FPGA TO LTC2500:
# SDI setup time is 4ns minimum
# SDI hold time is 1ns minimum. THIS IS WHAT CAUSED US SO MANY HEADACHES THAT WE ADDED THE PHASE-SHIFTED CLOCK!!
# Note that the SDI data launch edge is adc_clock, but the clock to the LTC2500 has to travel through combinatorial
# logic so we were ever so slightly violating hold time...

# Okay, here's what made timing work for the INCOMING data from the LTC2500 (SDO pins)... note that the idea is to give the LTC2500 a "head start" by advancing its
# clock by 5ns. HOWEVER... the next adc_clk edge edge that Quartus sees happens 5ns later. This is NOT the latch edge, it's the following edge.

# Once again, do we really have to poke all the way back to the output node of the PLL?
set_multicycle_path -from sclk_u1 -to DC2390_pll:DC2390_pll_inst|DC2390_pll_0002:dc2390_pll_inst|altera_pll:altera_pll_i|outclk_wire[0] -setup  2
set_multicycle_path -from sclk_u2 -to DC2390_pll:DC2390_pll_inst|DC2390_pll_0002:dc2390_pll_inst|altera_pll:altera_pll_i|outclk_wire[0] -setup  2
set_multicycle_path -from sclk_filt_u1 -to DC2390_pll:DC2390_pll_inst|DC2390_pll_0002:dc2390_pll_inst|altera_pll:altera_pll_i|outclk_wire[0] -setup  2
set_multicycle_path -from sclk_filt_u2 -to DC2390_pll:DC2390_pll_inst|DC2390_pll_0002:dc2390_pll_inst|altera_pll:altera_pll_i|outclk_wire[0] -setup  2

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


set_output_delay -clock [get_clocks sclk_filt_u1] -max 5 [get_ports sdi_filt_u1]
set_output_delay -clock [get_clocks sclk_filt_u1] -min 2 [get_ports sdi_filt_u1] -add_delay
set_output_delay -clock [get_clocks sclk_filt_u2] -max 5 [get_ports sdi_filt_u2]
set_output_delay -clock [get_clocks sclk_filt_u2] -min 2 [get_ports sdi_filt_u2] -add_delay


# Cut paths to slow SPI port, GPOs.
set_false_path -from [get_pins -hierarchical {*}] -to [get_ports ltc6954_sync]
set_false_path -from [get_pins -hierarchical {*}] -to [get_ports ltc6954_cs]
set_false_path -from [get_pins -hierarchical {*}] -to [get_ports ltc6954_sck]
set_false_path -from [get_pins -hierarchical {*}] -to [get_ports ltc6954_sdi]
set_false_path -from [get_pins -hierarchical {*}] -to [get_ports ltc6954_sdo]
    
set_false_path -from [get_pins -hierarchical {*}] -to [get_ports gpo0]
set_false_path -from [get_pins -hierarchical {*}] -to [get_ports gpo1]


# Asynchronous I/O.
set_false_path -from [get_ports {KEY*}]    -to [get_pins -hierarchical {*}]
set_false_path -from [get_ports {KEY*}]    -to [get_ports              {*}]

set_false_path -from [get_ports              {*}] -to [get_ports {LED*}]
set_false_path -from [get_pins -hierarchical {*}] -to [get_ports {LED*}]

set_false_path -from [get_ports sda]    -to [get_pins -hierarchical {*}]
set_false_path -from [get_ports scl]    -to [get_pins -hierarchical {*}]
set_false_path -from [get_pins -hierarchical {*}] -to [get_ports sda]
set_false_path -from [get_pins -hierarchical {*}] -to [get_ports scl]

