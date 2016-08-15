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
//   Filename       : altera_jesd204_assembler.sv
//
//   Description    : This module takes the samples form the converter and maps them into different lanes.
//
//   Limitation     : This module supports only LMF ={112, 222, 442, 114, 224, 444}, N={12, 13, 14, 15, 16}, N' = 16, S = {1, 2}.
//
//   Note           : Optional 
//***************************************

// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on

module altera_jesd204_assembler 
#(
    parameter L                 = 4,  // Supported range: 1-8
    parameter F                 = 4,  // Supported value: 1, 2, 4 and 8
    parameter N                 = 12, // Supported value: 12, 13, 14, 15 and 16
    parameter N_PRIME           = 16,      
    parameter CS                = 0,
    parameter F1_FRAMECLK_DIV   = 4,  //Supported value: 1 and 4
    parameter F2_FRAMECLK_DIV   = 2,  //Supported value: 1 and 2
    parameter RECONFIG_EN       = 1, 
   
    parameter DATA_BUS_WIDTH    = (F==8)? (8*8*L*N/N_PRIME) : (F==4)? (8*4*L*N/N_PRIME) : (F==2) ? (F2_FRAMECLK_DIV*8*2*L*N/N_PRIME) : (F==1) ? (F1_FRAMECLK_DIV*8*1*L*N/N_PRIME)  : 1,
    parameter CONTROL_BUS_WIDTH = ( (CS==0) ? 1 : (DATA_BUS_WIDTH/N*CS) )
) 
(
    input    wire   txlink_clk,
    input    wire   txframe_clk,
    input    wire   txframe_rst_n,
    input    wire   txlink_rst_n,
    input    wire   jesd_tx_data_valid,
    input    wire   link_tprt_early_txdata_ready,
    input    wire   [4:0]  csr_l,
    input    wire   [4:0]  csr_n,
    input    wire   [7:0]  csr_f,
    input    wire   [(DATA_BUS_WIDTH-1):0] jesd_tx_datain,
    input    wire   [CONTROL_BUS_WIDTH-1:0] tprt_avalon_tx_control,
    
    output   wire   jesd_tx_data_ready,
    output   reg    tprt_link_txdata_error,
    output   reg    tprt_link_txdata_valid,
    output   reg    [(L * 32)-1:0]  tprt_link_txdata
);

   localparam MAX_M_MUL_S                      = DATA_BUS_WIDTH/N;
   localparam MAX_ASSEMBLED_WIDTH              = MAX_M_MUL_S*N_PRIME;
   localparam PAD_WIDTH                        = (16-N-CS);
   localparam N12_PAD_WIDTH                    = (16-12-CS);
   localparam N13_PAD_WIDTH                    = (16-13-CS);
   localparam N14_PAD_WIDTH                    = (16-14-CS);
   localparam TX_DATA_PAD_BUS_WIDTH            = (F==1) ? (L%2) ? (F1_FRAMECLK_DIV*8*1*(L+1)*N/N_PRIME) : DATA_BUS_WIDTH : DATA_BUS_WIDTH; 
   localparam F1_LANE_FRAMECLK_DIV_WIDTH       = (F1_FRAMECLK_DIV*8*L);
   localparam F1_FIFO_DEPTH                    = (L/2);

genvar i, j;

reg csr_f1, csr_f2, csr_f4, csr_f8;
reg csr_n12, csr_n13, csr_n14, csr_n15, csr_n16;
reg jesd_tx_data_valid_d1;
reg csr_f1_odd;
reg [7:0] csr_pdlane;
reg [1:0] f1_cnt;
reg link_tprt_early_txdata_ready_d1;
      
reg [F1_FIFO_DEPTH-1:0][15:0] f1_txfifo_entry0;
reg [F1_FIFO_DEPTH-1:0][15:0] f1_txfifo_entry1;
reg [F1_FIFO_DEPTH-1:0][15:0] f1_txfifo_entry2;
reg [F1_FIFO_DEPTH-1:0][15:0] f1_txfifo_entry3;
reg [F1_FIFO_DEPTH-1:0][15:0] f1_txfifo_entry4;
reg [F1_FIFO_DEPTH-1:0][15:0] f1_txfifo_entry5;
reg [F1_FIFO_DEPTH-1:0][15:0] f1_txfifo_entry6;
reg [F1_FIFO_DEPTH-1:0][15:0] f1_txfifo_entry7;

reg [L-1:0][15:0] f2_txfifo_entry0;
reg [L-1:0][15:0] f2_txfifo_entry1;
reg [L-1:0][15:0] f2_txfifo_entry2;
reg [L-1:0][15:0] f2_txfifo_entry3;
   
reg [1:0] f1_read_ready;
reg [2:0] f1_txfifo_wptr;
reg [2:0] f1_txfifo_rptr;
reg [(L/2)-1:0][63:0] f1_tx_reg_d;

reg [1:0] f2_txfifo_wptr;
reg [1:0] f2_txfifo_rptr;
reg [1:0] f2_read_ready;
wire [L-1:0][31:0] f2_tx_reg;
   
reg [MAX_ASSEMBLED_WIDTH-1:0] txdata_tp;
reg [(L*32)-1:0]txdata_final;

reg f1_f2_txerror_flop;
reg int_txdata_error_1st_flop;
reg txerror_2nd_flop;
reg txerror_3rd_flop;

wire               f1_tx_ready;
wire [(L*32)-1:0]  f1_tsp_txlink_datain;
wire [(L*32)-1:0]  f1_tx_data;
wire [(L/2)-1:0][63:0] f1_tx_reg;

wire               f2_tx_ready;
wire [(L*32)-1:0]  f2_tsp_txlink_datain;
wire [(L*32)-1:0]  f2_tx_data;

wire [(L*32)-1:0]  f4_tsp_txlink_datain;
wire [(L*32)-1:0]  f4_tx_data;

wire [(L*32)-1:0]  f8_tsp_txlink_datain_L0;
wire [(L*32)-1:0]  f8_tsp_txlink_datain_L1;
wire [(L*32)-1:0]  f8_tx_data_reg;
wire [(L*64)-1:0]  f8_tx_data_in;
reg  [(L*64)-1:0]  f8_tx_data_pre;
reg  [(L*32)-1:0]  f8_tx_data;
reg                f8_early_txdata_ready_d1, f8_early_txdata_ready_d2;

wire [(MAX_ASSEMBLED_WIDTH-1):0] tx_data_tp_15;
wire [(MAX_ASSEMBLED_WIDTH-1):0] tx_data_tp_14;
wire [(MAX_ASSEMBLED_WIDTH-1):0] tx_data_tp_13;
wire [(MAX_ASSEMBLED_WIDTH-1):0] tx_data_tp_12;

wire f1_fclkdiv1_txerror;
wire f1_f2_txerror_input;
wire f1_f2_f4_txdata_error;
wire f8_txdata_error;
wire txdata_error_pre;
wire n_txdata_error;
wire f2_fclkdiv1_txerror;

   always @ (posedge txframe_clk)
   begin
      if (!txframe_rst_n)
      begin
         csr_f1     <= 1'b0;
         csr_f2     <= 1'b0;
         csr_f4     <= 1'b0;
         csr_f8     <= 1'b0;
         
         csr_n12    <= 1'b0;
         csr_n13    <= 1'b0;
         csr_n14    <= 1'b0;
         csr_n15    <= 1'b0;
         csr_n16    <= 1'b0;
         
         csr_pdlane <= 8'b000;
         csr_f1_odd <= 1'b0;
      end
      else
      begin
         csr_f1     <= (csr_f == 8'h00) ? 1'b1 : 1'b0;
         csr_f2     <= (csr_f == 8'h01) ? 1'b1 : 1'b0;
         csr_f4     <= (csr_f == 8'h03) ? 1'b1 : 1'b0;
         csr_f8     <= (csr_f == 8'h07) ? 1'b1 : 1'b0;
         
         csr_n12    <= (csr_n == 5'd11) ? 1'b1 : 1'b0;
         csr_n13    <= (csr_n == 5'd12) ? 1'b1 : 1'b0;
         csr_n14    <= (csr_n == 5'd13) ? 1'b1 : 1'b0;
         csr_n15    <= (csr_n == 5'd14) ? 1'b1 : 1'b0;
         csr_n16    <= (csr_n == 5'd15) ? 1'b1 : 1'b0;
         csr_pdlane <= (csr_l==5'd0)? 8'b11111110 : 
                       (csr_l==5'd1)? 8'b11111100 : 
                       (csr_l==5'd2)? 8'b11111000 : 
                       (csr_l==5'd3)? 8'b11110000 : 
                       (csr_l==5'd4)? 8'b11100000 : 
                       (csr_l==5'd5)? 8'b11000000 : 
                       (csr_l==5'd6)? 8'b10000000 : 8'b00000000;
         csr_f1_odd <= (csr_f1 && ((csr_l== 5'd0) || (csr_l==5'd2) || (csr_l==5'd4) || (csr_l==5'd6))) ? 1'b1 : 1'b0;
	   end
   end

   ///////////////////////////////////////////////////////////////////////////////////////
   //      F=1
   ///////////////////////////////////////////////////////////////////////////////////////
   generate
   if ( (!RECONFIG_EN && (F==1)) || (RECONFIG_EN && !(L%2)))
   begin
      for (i=0; i<F1_FIFO_DEPTH; i=i+1)
      begin : F1
         always @ (posedge txframe_clk)
         begin
            if (!txframe_rst_n)
            begin
               f1_txfifo_entry0[i] <= 16'b0;
               f1_txfifo_entry1[i] <= 16'b0;
               f1_txfifo_entry2[i] <= 16'b0;
               f1_txfifo_entry3[i] <= 16'b0;
               f1_txfifo_entry4[i] <= 16'b0;
               f1_txfifo_entry5[i] <= 16'b0;
               f1_txfifo_entry6[i] <= 16'b0;
               f1_txfifo_entry7[i] <= 16'b0;
               f1_tx_reg_d[i]      <= 64'b0;
            end
            else
            begin
               f1_txfifo_entry0[i][7:0]  <= (!csr_pdlane[i]) ? ((f1_txfifo_wptr==3'b000) ? txdata_tp[(i*2+1)*8 +: 8] : f1_txfifo_entry0[i][7:0]) : 8'b0; 
               f1_txfifo_entry1[i][7:0]  <= (!csr_pdlane[i]) ? ((f1_txfifo_wptr==3'b001) ? txdata_tp[(i*2+1)*8 +: 8] : f1_txfifo_entry1[i][7:0]) : 8'b0;
               f1_txfifo_entry2[i][7:0]  <= (!csr_pdlane[i]) ? ((f1_txfifo_wptr==3'b010) ? txdata_tp[(i*2+1)*8 +: 8] : f1_txfifo_entry2[i][7:0]) : 8'b0;
               f1_txfifo_entry3[i][7:0]  <= (!csr_pdlane[i]) ? ((f1_txfifo_wptr==3'b011) ? txdata_tp[(i*2+1)*8 +: 8] : f1_txfifo_entry3[i][7:0]) : 8'b0;
               f1_txfifo_entry4[i][7:0]  <= (!csr_pdlane[i]) ? ((f1_txfifo_wptr==3'b100) ? txdata_tp[(i*2+1)*8 +: 8] : f1_txfifo_entry4[i][7:0]) : 8'b0;
               f1_txfifo_entry5[i][7:0]  <= (!csr_pdlane[i]) ? ((f1_txfifo_wptr==3'b101) ? txdata_tp[(i*2+1)*8 +: 8] : f1_txfifo_entry5[i][7:0]) : 8'b0;
               f1_txfifo_entry6[i][7:0]  <= (!csr_pdlane[i]) ? ((f1_txfifo_wptr==3'b110) ? txdata_tp[(i*2+1)*8 +: 8] : f1_txfifo_entry6[i][7:0]) : 8'b0;
               f1_txfifo_entry7[i][7:0]  <= (!csr_pdlane[i]) ? ((f1_txfifo_wptr==3'b111) ? txdata_tp[(i*2+1)*8 +: 8] : f1_txfifo_entry7[i][7:0]) : 8'b0; 
   	           
               f1_txfifo_entry0[i][15:8] <= (!csr_pdlane[i]) ? ((f1_txfifo_wptr==3'b000) ? txdata_tp[(i*16) +: 8] : f1_txfifo_entry0[i][15:8]) : 8'b0; 
               f1_txfifo_entry1[i][15:8] <= (!csr_pdlane[i]) ? ((f1_txfifo_wptr==3'b001) ? txdata_tp[(i*16) +: 8] : f1_txfifo_entry1[i][15:8]) : 8'b0;
               f1_txfifo_entry2[i][15:8] <= (!csr_pdlane[i]) ? ((f1_txfifo_wptr==3'b010) ? txdata_tp[(i*16) +: 8] : f1_txfifo_entry2[i][15:8]) : 8'b0;
               f1_txfifo_entry3[i][15:8] <= (!csr_pdlane[i]) ? ((f1_txfifo_wptr==3'b011) ? txdata_tp[(i*16) +: 8] : f1_txfifo_entry3[i][15:8]) : 8'b0;
               f1_txfifo_entry4[i][15:8] <= (!csr_pdlane[i]) ? ((f1_txfifo_wptr==3'b100) ? txdata_tp[(i*16) +: 8] : f1_txfifo_entry4[i][15:8]) : 8'b0;
               f1_txfifo_entry5[i][15:8] <= (!csr_pdlane[i]) ? ((f1_txfifo_wptr==3'b101) ? txdata_tp[(i*16) +: 8] : f1_txfifo_entry5[i][15:8]) : 8'b0;
               f1_txfifo_entry6[i][15:8] <= (!csr_pdlane[i]) ? ((f1_txfifo_wptr==3'b110) ? txdata_tp[(i*16) +: 8] : f1_txfifo_entry6[i][15:8]) : 8'b0;
               f1_txfifo_entry7[i][15:8] <= (!csr_pdlane[i]) ? ((f1_txfifo_wptr==3'b111) ? txdata_tp[(i*16) +: 8] : f1_txfifo_entry7[i][15:8]) : 8'b0; 
               f1_tx_reg_d[i]            <=  (f1_cnt == 2'b11) ? f1_tx_reg[i] : f1_tx_reg_d[i];   
            end
         end                                                                         
         assign f1_tx_reg[i][31:0] = (f1_txfifo_rptr[2]==1'b0) ? {f1_txfifo_entry0[i][7:0], f1_txfifo_entry1[i][7:0], f1_txfifo_entry2[i][7:0], f1_txfifo_entry3[i][7:0]} :  
                                                                        {f1_txfifo_entry4[i][7:0], f1_txfifo_entry5[i][7:0], f1_txfifo_entry6[i][7:0], f1_txfifo_entry7[i][7:0]}; 
         assign f1_tx_reg[i][63:32] = (f1_txfifo_rptr[2]==1'b0) ? {f1_txfifo_entry0[i][15:8], f1_txfifo_entry1[i][15:8], f1_txfifo_entry2[i][15:8], f1_txfifo_entry3[i][15:8]} :  
                                                                        {f1_txfifo_entry4[i][15:8], f1_txfifo_entry5[i][15:8], f1_txfifo_entry6[i][15:8], f1_txfifo_entry7[i][15:8]}; 
                                   
      
         assign f1_tsp_txlink_datain[i*64 +: 64] = (F1_FRAMECLK_DIV==1) ? f1_tx_reg_d[i] : 
                                                   (F1_FRAMECLK_DIV==4) ? {txdata_tp[(i*16) +: 8], txdata_tp[(i*16)+(L*8) +: 8], txdata_tp[(i*16)+(L*16) +: 8], txdata_tp[(i*16)+(L*24) +: 8], txdata_tp[(i*16)+8 +: 8], txdata_tp[(i*16)+8+(L*8) +: 8], txdata_tp[(i*16)+8+(L*16) +: 8], txdata_tp[(i*16)+8+(L*24) +: 8]} : {64{1'b0}};
      end
      
      assign f1_tx_ready = f1_read_ready[1];
      assign f1_tx_data  = (!link_tprt_early_txdata_ready_d1) ? {32*L*{1'b0}} : f1_tsp_txlink_datain[(L*32)-1:0];
      
      always @ (posedge txframe_clk)
   	   if (!txframe_rst_n)
   	   begin
            f1_txfifo_wptr   <= 3'b0;
            f1_txfifo_rptr   <= 3'b0;
            f1_read_ready    <= 2'b0;
            f1_cnt           <= 2'b0;
   	   end
   	   else
   	   begin
            f1_txfifo_wptr   <= (!link_tprt_early_txdata_ready_d1) ? 3'b000 : ( (f1_txfifo_wptr==3'b111) ? 3'b000: f1_txfifo_wptr+3'b001 ); 
            f1_txfifo_rptr   <= (!f1_read_ready[0]) ? 3'b000 : ( (f1_txfifo_rptr==3'b111) ? 3'b000: f1_txfifo_rptr+3'b001 ); 
            f1_read_ready    <= {(f1_read_ready[0]&&link_tprt_early_txdata_ready_d1), link_tprt_early_txdata_ready_d1};
            f1_cnt           <= (!f1_read_ready[0]) ? 2'b00 : (f1_cnt == 2'b11) ? 2'b00 : (f1_cnt + 2'b01);
   	   end  
   end
   else
      assign f1_tx_ready = 1'b0;
   endgenerate
   
   ///////////////////////////////////////////////////////////////////////////////////////
   //      F=2
   ///////////////////////////////////////////////////////////////////////////////////////
   generate
   if ( (!RECONFIG_EN && (F==2)) || (RECONFIG_EN && (F!=1)) )
   begin
      for (i=0; i<L ; i=i+1)
      begin: F2
         always @ (posedge txframe_clk)
         begin
            if (!txframe_rst_n)
            begin
               f2_txfifo_entry0[i] <= 16'b0;
               f2_txfifo_entry1[i] <= 16'b0;
               f2_txfifo_entry2[i] <= 16'b0;
               f2_txfifo_entry3[i] <= 16'b0;
            end
            else
            begin
               f2_txfifo_entry0[i] <= (!csr_pdlane[i]) ? ((f2_txfifo_wptr==2'b00) ? txdata_tp[(i*16) +: 16] : f2_txfifo_entry0[i]) : 16'b0; 
               f2_txfifo_entry1[i] <= (!csr_pdlane[i]) ? ((f2_txfifo_wptr==2'b01) ? txdata_tp[(i*16) +: 16] : f2_txfifo_entry1[i]) : 16'b0;
               f2_txfifo_entry2[i] <= (!csr_pdlane[i]) ? ((f2_txfifo_wptr==2'b10) ? txdata_tp[(i*16) +: 16] : f2_txfifo_entry2[i]) : 16'b0;
               f2_txfifo_entry3[i] <= (!csr_pdlane[i]) ? ((f2_txfifo_wptr==2'b11) ? txdata_tp[(i*16) +: 16] : f2_txfifo_entry3[i]) : 16'b0;
            end
         end                          
                 
         assign f2_tx_reg[i][15:0]  = (f2_txfifo_rptr[1]== 1'b1) ? f2_txfifo_entry1[i] : f2_txfifo_entry3[i];
         assign f2_tx_reg[i][31:16] = (f2_txfifo_rptr[1]== 1'b1) ? f2_txfifo_entry0[i] : f2_txfifo_entry2[i];                 
         assign f2_tsp_txlink_datain[i*32 +: 32] = (F2_FRAMECLK_DIV==1) ? f2_tx_reg[i][31:0] : 
                                                   (F2_FRAMECLK_DIV==2) ? {txdata_tp[(i*16) +: 16], txdata_tp[((i*16)+(L*16)) +: 16]} : {32{1'b0}}; 
                                                  
         assign f2_tx_ready = f2_read_ready[1];
      end
      
      always @ (posedge txframe_clk)
      begin
         if (!txframe_rst_n)
         begin
            f2_txfifo_wptr   <= 2'b0;
            f2_txfifo_rptr   <= 2'b0;
            f2_read_ready    <= 2'b0;
         end
         else
         begin
            f2_txfifo_wptr   <= (!link_tprt_early_txdata_ready_d1) ? 2'b00 : ( (f2_txfifo_wptr==2'b11) ? 2'b00: f2_txfifo_wptr+2'b01 ); 
            f2_txfifo_rptr   <= (!f2_read_ready[0]) ? 2'b00 : ( (f2_txfifo_rptr==2'b11) ? 2'b00: f2_txfifo_rptr+2'b01 ); 
            f2_read_ready    <= {(f2_read_ready[0]&&link_tprt_early_txdata_ready_d1), link_tprt_early_txdata_ready_d1};
         end
      end
      
   	  assign f2_tx_data = (!link_tprt_early_txdata_ready_d1) ? {32*L*{1'b0}} : f2_tsp_txlink_datain;
   end
   else
      assign f2_tx_ready = 1'b0;
   endgenerate

   
   ///////////////////////////////////////////////////////////////////////////////////////
   //      F=4
   ///////////////////////////////////////////////////////////////////////////////////////
   generate
   if ( (!RECONFIG_EN && (F==4)) || (RECONFIG_EN && (F!=1 && F!=2)) )
   begin
      for (i=0;i<L;i=i+1)
      begin : F4
         assign f4_tsp_txlink_datain[i*32 +: 32] = (!csr_pdlane[i]) ? {txdata_tp[(i*2)*16 +:16], txdata_tp[(i*2+1)*16 +:16]} : 32'b0;
      end
      
      assign f4_tx_data = (!link_tprt_early_txdata_ready_d1) ? {32*L*{1'b0}} : f4_tsp_txlink_datain;
   end
   
   endgenerate
   
   
   ///////////////////////////////////////////////////////////////////////////////////////
   //      F=8
   ///////////////////////////////////////////////////////////////////////////////////////
   generate
   if (F==8)
   begin
      for (i=0;i<L;i=i+1)
      begin : F8
         assign f8_tsp_txlink_datain_L0[i*32 +: 32] = (!csr_pdlane[i]) ? {f8_tx_data_in[(i*4)*16 +:16], f8_tx_data_in[(i*4+1)*16 +:16]} : 32'b0;
         assign f8_tsp_txlink_datain_L1[i*32 +: 32] = (!csr_pdlane[i]) ? {f8_tx_data_in[(i*4+2)*16 +:16], f8_tx_data_in[(i*4+3)*16 +:16]} : 32'b0;
      end  
      
      reg f8_cnt;
      
      always @ (posedge txlink_clk)
      begin
         if (!txlink_rst_n)
         begin
            f8_early_txdata_ready_d1        <= 1'b0;
            f8_early_txdata_ready_d2        <= 1'b0;
            f8_cnt                          <= 1'b0;
            f8_tx_data_pre                  <= {64*L*{1'b0}};   
            f8_tx_data                      <= {32*L*{1'b0}};
         end
         else
            f8_early_txdata_ready_d1        <= link_tprt_early_txdata_ready; 
            f8_early_txdata_ready_d2        <= f8_early_txdata_ready_d1;
            f8_cnt                          <= (!f8_early_txdata_ready_d1) ? 1'b0 : !f8_cnt;
            f8_tx_data_pre                  <= f8_tx_data_in;
            f8_tx_data                      <= f8_tx_data_reg;
      end
      
      assign f8_tx_data_in = (f8_cnt) ? txdata_tp : f8_tx_data_pre;
      assign f8_tx_data_reg = (!f8_early_txdata_ready_d2) ? {32*L*{1'b0}} : f8_cnt ? f8_tsp_txlink_datain_L0 : f8_tsp_txlink_datain_L1;

   end  
   endgenerate
   
	generate 
   if (F==8 && RECONFIG_EN)
   begin
      always @ (*)
      begin
         if (csr_f1 && !csr_f1_odd)
            txdata_final = f1_tx_data;
         else if (csr_f2)
            txdata_final = f2_tx_data;
         else if (csr_f4)
            txdata_final = f4_tx_data;
         else if (csr_f8)
            txdata_final = f8_tx_data;
         else
            txdata_final = {DATA_BUS_WIDTH{1'b0}};
      end
   end
   endgenerate
	
	generate 
   if (F==4 && RECONFIG_EN)
   begin
      always @ (*)
      begin
         if (csr_f1 && !csr_f1_odd)
            txdata_final = f1_tx_data;
         else if (csr_f2)
            txdata_final = f2_tx_data;
         else if (csr_f4)
            txdata_final = f4_tx_data;
         else
            txdata_final = {DATA_BUS_WIDTH{1'b0}};
      end
   end
   endgenerate
	
	generate 
   if (F==2 && RECONFIG_EN)
   begin
      always @ (*)
      begin
         if (csr_f1 && !csr_f1_odd)
            txdata_final = f1_tx_data;
         else if (csr_f2)
            txdata_final = f2_tx_data;
         else
            txdata_final = {DATA_BUS_WIDTH{1'b0}};
      end
   end
   endgenerate
	
	generate 
   if (F==1 && RECONFIG_EN)
   begin
      always @ (*)
      begin
         if (csr_f1)
            txdata_final = f1_tx_data;
         else
            txdata_final = {DATA_BUS_WIDTH{1'b0}};
      end
   end
   endgenerate
	
   generate 
   if (!RECONFIG_EN)
   begin
      always @ (*)
      begin 
         txdata_final = (F==1) ? f1_tx_data : (F==2) ? f2_tx_data : (F==4) ? f4_tx_data : (F==8) ? f8_tx_data : {DATA_BUS_WIDTH{1'b0}};
      end
   end
	endgenerate
	
   ///////////////////////////////////////////////////////////////////////////////////////
   //      Tailbits padding for different N
   ///////////////////////////////////////////////////////////////////////////////////////
  
   // N=15
   generate 
   if (N==15 || N==16)
   begin
      for (j=1;j<=MAX_M_MUL_S;j=j+1)
      begin : N15
         assign tx_data_tp_15[j*16-1 -: 15] = jesd_tx_datain[j*15-1 -: 15];
         
         if (CS!=0)
            assign tx_data_tp_15[j*16-1-15 -: CS]  = tprt_avalon_tx_control[j*CS-1 -: CS];
         else
            assign tx_data_tp_15[j*16-1-15 -: 1]  = 1'b0;
            
      end
   end
   else if (!RECONFIG_EN)
      assign tx_data_tp_15  = {MAX_ASSEMBLED_WIDTH{1'b0}};
   endgenerate

     
   // N=14 
   generate 
   if (N==14 || N==15 || N==16)
   begin
      for (j=1;j<=MAX_M_MUL_S;j=j+1)
      begin : N14
         assign tx_data_tp_14[j*16-1 -: 14] = jesd_tx_datain[j*14-1 -: 14];
         
         if (CS!=0)
         begin
            assign tx_data_tp_14[j*16-1-14 -: CS]  = tprt_avalon_tx_control[j*CS-1 -: CS];
            assign tx_data_tp_14[j*16-1-14-CS -: N14_PAD_WIDTH] =  {N14_PAD_WIDTH{1'b0}};
         end
         else
            assign tx_data_tp_14[j*16-1-14 -: 2]  = 2'b0;
            
      end
   end
   else if (!RECONFIG_EN)
      assign tx_data_tp_14  = {MAX_ASSEMBLED_WIDTH{1'b0}};
   endgenerate

 
   // N= 13
   generate 
   if (N==13 || N==14 || N==15 || N==16)
   begin
      for (j=1;j<=MAX_M_MUL_S;j=j+1)
      begin : N13
         assign tx_data_tp_13[j*16-1 -: 13] = jesd_tx_datain[j*13-1 -: 13];
         
         if (CS!=0)
         begin
            assign tx_data_tp_13[j*16-1-13 -: CS]  = tprt_avalon_tx_control[j*CS-1 -: CS];
            assign tx_data_tp_13[j*16-1-13-CS -: N13_PAD_WIDTH] =  {N13_PAD_WIDTH{1'b0}};
         end
         else
            assign tx_data_tp_13[j*16-1-13 -: N13_PAD_WIDTH]  = {N13_PAD_WIDTH{1'b0}};
            
      end
   end
   else if (!RECONFIG_EN)
      assign tx_data_tp_13  = {MAX_ASSEMBLED_WIDTH{1'b0}};
   endgenerate

   // N=12
   generate 
   if (N==12 || N==13 || N==14 || N==15 || N==16)
   begin
      for (j=1;j<=MAX_M_MUL_S;j=j+1)
      begin : N12
         assign tx_data_tp_12[j*16-1 -: 12] = jesd_tx_datain[j*12-1 -: 12];
         
         if (CS!=0)
         begin
            assign tx_data_tp_12[j*16-1-12 -: CS]  = tprt_avalon_tx_control[j*CS-1 -: CS];
            assign tx_data_tp_12[j*16-1-12-CS -: N12_PAD_WIDTH] =  {N12_PAD_WIDTH{1'b0}};
         end
         else
            assign tx_data_tp_12[j*16-1-12 -: N12_PAD_WIDTH]  = {N12_PAD_WIDTH{1'b0}};
            
      end
   end
   else if (!RECONFIG_EN)
      assign tx_data_tp_12  = {MAX_ASSEMBLED_WIDTH{1'b0}};
   endgenerate

   
   // N=16
   generate 
   if (N==16 && RECONFIG_EN)
   begin
      always @ (*)
      begin
         if (csr_n12)
            txdata_tp = tx_data_tp_12;
         else if (csr_n13)
            txdata_tp = tx_data_tp_13;
         else if (csr_n14)
            txdata_tp = tx_data_tp_14;
         else if (csr_n15)
            txdata_tp = tx_data_tp_15;
         else if (csr_n16)
            txdata_tp = jesd_tx_datain;
         else
            txdata_tp = {MAX_ASSEMBLED_WIDTH{1'b0}};
      end
   end
   endgenerate

   
   // N=15
   generate 
   if (N==15 && RECONFIG_EN)
   begin
      always @ (*)
      begin
         if (csr_n12)
            txdata_tp = tx_data_tp_12;
         else if (csr_n13)
            txdata_tp = tx_data_tp_13;
         else if (csr_n14)
            txdata_tp = tx_data_tp_14;
         else if (csr_n15)
            txdata_tp = tx_data_tp_15;
         else
            txdata_tp = {MAX_ASSEMBLED_WIDTH{1'b0}};
      end
   end
   endgenerate
   
   // N=14
   generate 
   if (N==14 && RECONFIG_EN)
   begin
      always @ (*)
      begin
         if (csr_n12)
            txdata_tp = tx_data_tp_12;
         else if (csr_n13)
            txdata_tp = tx_data_tp_13;
         else if (csr_n14)
            txdata_tp = tx_data_tp_14;
         else
            txdata_tp = {MAX_ASSEMBLED_WIDTH{1'b0}};
      end
   end
   endgenerate
   
   // N=13
   generate 
   if (N==13 && RECONFIG_EN)
   begin
      always @ (*)
      begin
         if (csr_n12)
            txdata_tp = tx_data_tp_12;
         else if (csr_n13)
            txdata_tp = tx_data_tp_13;
         else
            txdata_tp = {MAX_ASSEMBLED_WIDTH{1'b0}};
      end
   end
   endgenerate

   // N=12
   generate 
   if (N==12 && RECONFIG_EN)
   begin
      always @ (*)
      begin
         if (csr_n12)
            txdata_tp = tx_data_tp_12;
         else
            txdata_tp = {MAX_ASSEMBLED_WIDTH{1'b0}};
      end
   end
   endgenerate

   generate 
   if (!RECONFIG_EN)
   begin
      always @ (*)
      begin 
         txdata_tp = (N==12) ? tx_data_tp_12 : 
                     (N==13) ? tx_data_tp_13 : 
                     (N==14) ? tx_data_tp_14 : 
                     (N==15) ? tx_data_tp_15 : 
                     (N==16) ? jesd_tx_datain[TX_DATA_PAD_BUS_WIDTH-1:0] :  {TX_DATA_PAD_BUS_WIDTH{1'b0}};
      end
   end
   endgenerate
   

   // **************************************************************************************
   //   tprt_link_txdata_error implementation. 
   // ***************************************************************************************
   assign n_txdata_error = jesd_tx_data_ready && (!jesd_tx_data_valid);
   assign f2_fclkdiv1_txerror = n_txdata_error || int_txdata_error_1st_flop;

   always @ (posedge txframe_clk)
   begin
      if (!txframe_rst_n)
      begin
         int_txdata_error_1st_flop <= 1'b0;                   
      end
      else
      begin
         int_txdata_error_1st_flop <= n_txdata_error;          
      end
   end

   always @ (posedge txframe_clk)
   begin
      if (!txframe_rst_n)
      begin
         txerror_2nd_flop <= 1'b0;                   
      end
      else
      begin
         txerror_2nd_flop <= int_txdata_error_1st_flop;          
      end
   end

   always @ (posedge txframe_clk)
   begin
      if (!txframe_rst_n)
      begin
         txerror_3rd_flop <= 1'b0;                   
      end
      else
      begin
         txerror_3rd_flop <= txerror_2nd_flop;          
      end
   end
		
   always @ (posedge txlink_clk)
   begin
      if (!txlink_rst_n)
      begin
         f1_f2_txerror_flop <= 1'b0;
      end
      else
      begin
         f1_f2_txerror_flop <= f1_f2_txerror_input;
      end
   end
   
   assign f1_fclkdiv1_txerror = f2_fclkdiv1_txerror || txerror_2nd_flop || txerror_3rd_flop; 
   assign f1_f2_txerror_input = (csr_f1 && (F1_FRAMECLK_DIV==1)) ? f1_fclkdiv1_txerror : f2_fclkdiv1_txerror; 
   assign f1_f2_f4_txdata_error = ((csr_f1 && F1_FRAMECLK_DIV == 1) || (csr_f2 && F2_FRAMECLK_DIV == 1)) ? f1_f2_txerror_flop : n_txdata_error; 
   assign f8_txdata_error = int_txdata_error_1st_flop; 
   assign txdata_error_pre = csr_f8 ? f8_txdata_error : f1_f2_f4_txdata_error; 
   assign jesd_tx_data_ready = link_tprt_early_txdata_ready_d1;
	
   reg f1_tx_ready_d;

   always @ (posedge txframe_clk)
   begin
      if (!txframe_rst_n)
         link_tprt_early_txdata_ready_d1 <= 1'b0;
      else
         link_tprt_early_txdata_ready_d1 <= link_tprt_early_txdata_ready;
   end
   always @ (posedge txlink_clk )
   begin
      if (!txlink_rst_n)
      begin
         tprt_link_txdata       <= {L*32{1'b0}};
         jesd_tx_data_valid_d1  <= 1'b0;
         tprt_link_txdata_valid <= 1'b0;
         tprt_link_txdata_error <= 1'b0;
         f1_tx_ready_d          <= 1'b0;
      end
      else
      begin
         tprt_link_txdata       <= txdata_final;
         jesd_tx_data_valid_d1  <= jesd_tx_data_valid;
	 f1_tx_ready_d          <= f1_tx_ready;
         tprt_link_txdata_valid <= (RECONFIG_EN) ? (csr_f1 && (F1_FRAMECLK_DIV==1)) ? f1_tx_ready_d : 
                                                   (csr_f2 && (F2_FRAMECLK_DIV==1)) ? f2_tx_ready : jesd_tx_data_valid_d1 : jesd_tx_data_valid_d1;
         tprt_link_txdata_error <= txdata_error_pre;
      end
   end
	
endmodule





