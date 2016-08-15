# (C) 2001-2014 Altera Corporation. All rights reserved.
# Your use of Altera Corporation's design tools, logic functions and other 
# software and tools, and its AMPP partner logic functions, and any output 
# files any of the foregoing (including device programming or simulation 
# files), and any associated documentation or information are expressly subject 
# to the terms and conditions of the Altera Program License Subscription 
# Agreement, Altera MegaCore Function License Agreement, or other applicable 
# license agreement, including, without limitation, that your use is for the 
# sole purpose of programming logic devices manufactured by Altera and sold by 
# Altera or its authorized distributors.  Please refer to the applicable 
# agreement for further details.


#Users are recommended to modify this sdc file if these settings do not reflects the correct design's usage .
#For example, users must comment out set_clock_groups -asynch -group {jesd204_*x_link_clk} - group {jesd204_*x_avs_clk} if the jesd204_*x_link_clk is synchronous to jesd204_*x_avs_clk

   #RX_TX 
      create_clock -name "tx_pll_ref_clk" -period 8.138ns [get_ports *tx_pll_ref_clk*] 
      create_clock -name "rx_pll_ref_clk" -period 8.138ns [get_ports *rx_pll_ref_clk*] 
      derive_pll_clocks -create_base_clocks
      derive_clock_uncertainty
      create_clock -name "rxlink_clk" -period 8.138ns [get_ports *rxlink_clk*]
      create_clock -name "txlink_clk" -period 8.138ns [get_ports *txlink_clk*]
      create_clock -name "rx_avs_clk" -period 8.000ns [get_ports *rx_avs_clk*]
      create_clock -name "tx_avs_clk" -period 8.000ns [get_ports *tx_avs_clk*] 
      create_clock -name "reconfig_to_xcvr[0]" -period 8.000ns [get_ports *reconfig_to_xcvr[0]*] 
      set_clock_groups -asynchronous -group {rxlink_clk} -group {tx_pll_ref_clk} -group {rx_pll_ref_clk} -group {rx_avs_clk} -group {reconfig_to_xcvr[0]} -group {txlink_clk} -group {tx_avs_clk}
      # JESD204B IP may not meet timing for high data rate and multi lanes design due to non-ideal placement of Quartus fitter. Set Max delay for workaround. FB 161708 
      set_max_delay -from [get_keepers {*inst_av_hssi_8g_rx_pcs|wys~BURIED_SYNC_DATA*}] 8.138ns 
      set_max_delay -to [get_keepers {*inst_av_hssi_8g_tx_pcs|wys~BURIED_SYNC_DATA*}] 8.138ns 



