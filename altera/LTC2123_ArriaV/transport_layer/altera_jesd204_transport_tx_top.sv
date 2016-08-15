// (C) 2001-2014 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License Subscription 
// Agreement, Altera MegaCore Function License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


//****************************************
//   Filename       : altera_jesd204_transport_tx_top.sv
//
//   Description    : Top level TX transport layer with test mode selection
//
//   Limitation     : 
//
//   Note           : Optional 
//***************************************

// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on


module altera_jesd204_transport_tx_top #(
   parameter L                 = 2,
   parameter F                 = 2,
   parameter N                 = 12, 
   parameter N_PRIME           = 16,
   parameter CS                = 0,
   parameter F1_FRAMECLK_DIV   = 4,
   parameter F2_FRAMECLK_DIV   = 2,
   parameter RECONFIG_EN       = 1,
				 
   parameter DATA_BUS_WIDTH    = (F==8)? (8*8*L*N/N_PRIME) : (F==4)? (8*4*L*N/N_PRIME) : (F==2) ? (F2_FRAMECLK_DIV*8*2*L*N/N_PRIME) : (F==1) ? (F1_FRAMECLK_DIV*8*1*L*N/N_PRIME)  : 1,
   parameter CONTROL_BUS_WIDTH = ( (CS==0) ? 1 : (DATA_BUS_WIDTH/N*CS) )
)(            
   input    wire   txlink_rst_n,
   input    wire   txframe_rst_n,
   input    wire   txframe_clk,
   input    wire   txlink_clk,
   input    wire   [DATA_BUS_WIDTH-1:0] jesd204_tx_datain,
   input    wire   [CONTROL_BUS_WIDTH-1:0] jesd204_tx_controlin,
   input    wire   jesd204_tx_data_valid,
   input    wire   jesd204_tx_link_early_ready,
   input    wire   [4:0]  csr_l,
   input    wire   [7:0]  csr_f,
   input    wire   [4:0]  csr_n,
	
   output   wire   jesd204_tx_data_ready, 
   output   reg    jesd204_tx_link_error,
   output   reg    [(L*32)-1:0]  jesd204_tx_link_datain, 
   output   reg    jesd204_tx_link_data_valid
);

	
altera_jesd204_assembler #(
   .L              (L),
   .F              (F),
   .N              (N),
   .CS             (CS),
   .F1_FRAMECLK_DIV(F1_FRAMECLK_DIV),
   .F2_FRAMECLK_DIV(F2_FRAMECLK_DIV),
   .RECONFIG_EN    (RECONFIG_EN),
   .N_PRIME        (N_PRIME)
) assembler1(
   .txlink_clk(txlink_clk),
   .txframe_clk(txframe_clk),
   .txframe_rst_n(txframe_rst_n),
   .txlink_rst_n(txlink_rst_n),
   .jesd_tx_datain (jesd204_tx_datain),
	.tprt_avalon_tx_control(jesd204_tx_controlin),
   .jesd_tx_data_valid(jesd204_tx_data_valid),
   .link_tprt_early_txdata_ready(jesd204_tx_link_early_ready),
   .csr_l(csr_l),
   .csr_f(csr_f),
   .csr_n(csr_n),
   .jesd_tx_data_ready(jesd204_tx_data_ready),
   .tprt_link_txdata_error(jesd204_tx_link_error),
   .tprt_link_txdata(jesd204_tx_link_datain),
   .tprt_link_txdata_valid(jesd204_tx_link_data_valid) 
);

	
endmodule
