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
//   Filename       : altera_jesd204_transport_rx_top.sv
//
//   Description    : Top level RX transport layer with test mode selection
//
//   Limitation     : 
//
//   Note           : Optional 
//***************************************

// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on


module altera_jesd204_transport_rx_top #(
   parameter L=4, 
   parameter F=2, 
   parameter CS=0, 
   parameter N=12, 
   parameter N_PRIME =16,
   parameter F1_FRAMECLK_DIV=4, //valid value:1 or 4
   parameter F2_FRAMECLK_DIV=2,
   parameter RECONFIG_EN=1,

   //parameter for internal usage only
   parameter OUTPUT_BUS_WIDTH  = (F==8)? (8*8*L*N/N_PRIME) : (F==4)? (8*4*L*N/N_PRIME) : (F==2) ? (F2_FRAMECLK_DIV*8*2*L*N/N_PRIME) : (F==1) ? (F1_FRAMECLK_DIV*8*1*L*N/N_PRIME) : 1,
   parameter CONTROL_BUS_WIDTH= ( (CS==0) ? 1 : (OUTPUT_BUS_WIDTH/N*CS) )
             
) (
   input    wire   rxlink_rst_n,
   input    wire   rxframe_rst_n,
   input    wire   rxframe_clk,
   input    wire   rxlink_clk,
   input    wire   jesd204_rx_link_data_valid,
   input    wire   [(L*32)-1:0]  jesd204_rx_link_datain,
   input    wire   jesd204_rx_data_ready,
   input    wire   [4:0]  csr_l,
   input    wire   [7:0]  csr_f,
   input    wire   [4:0]  csr_n,
   output   reg    [OUTPUT_BUS_WIDTH-1:0]  jesd204_rx_dataout,
   output   reg    [CONTROL_BUS_WIDTH-1:0]  jesd204_rx_controlout,
   output   reg    jesd204_rx_data_valid,
   output   reg    jesd204_rx_link_error,
   output   reg    jesd204_rx_link_data_ready
);

   altera_jesd204_deassembler #(
      .L(L),
      .F(F),
      .N(N),
      .CS(CS),
      .N_PRIME(N_PRIME),
      .RECONFIG_EN(RECONFIG_EN),
      .F1_FRAMECLK_DIV(F1_FRAMECLK_DIV),
      .F2_FRAMECLK_DIV(F2_FRAMECLK_DIV)
   ) deassember1 (
      .rxlink_clk(rxlink_clk),
      .rxframe_clk(rxframe_clk),
      .rxframe_rst_n(rxframe_rst_n),
      .rxlink_rst_n(rxlink_rst_n),
      .csr_l(csr_l),
      .csr_f(csr_f),
      .csr_n(csr_n),
      .link_tprt_rxdata_valid(jesd204_rx_link_data_valid),
      .link_tprt_rx_datain(jesd204_rx_link_datain),
      .avalon_tprt_rx_ready(jesd204_rx_data_ready),
      .tprt_avalon_rx_data(jesd204_rx_dataout),
      .tprt_avalon_rx_control(jesd204_rx_controlout),
      .tprt_avalon_rx_data_valid(jesd204_rx_data_valid),
      .tprt_link_rx_error(jesd204_rx_link_error),
      .tprt_link_rxdata_ready(jesd204_rx_link_data_ready)
   );

	
endmodule
