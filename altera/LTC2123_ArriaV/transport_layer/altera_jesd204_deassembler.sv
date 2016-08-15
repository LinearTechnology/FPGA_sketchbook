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
//   Filename       : altera_jesd204_deassembler.sv
//
//   Description    : This module receives Rx data from lanes, and maps it to AV-ST Rx data bus. 
//
//   Limitation     : This module supports only F={1,2,4,8}, N={12,13,14,15,16}, N'=16, L={1,2,4,8}, CS={0,1,2,3}.
//
//   Note           : Optional 
//***************************************

// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on

module altera_jesd204_deassembler 
#(
   parameter L=4,               //user to provide largest L
   parameter F=4,               //user to provide largest F 
   parameter N=12,              //user to provide largest N
   parameter CS=0,              //No reconfiguration supported
   parameter N_PRIME=16,        //No reconfiguration supported
   parameter F1_FRAMECLK_DIV=4, //Valid value: 1 and 4. No reconfiguration supported
   parameter F2_FRAMECLK_DIV=2, //Valid value: 1 and 2. No reconfiguration supported
   parameter RECONFIG_EN=1, 
   
   //parameter for internal usage only
   parameter OUTPUT_BUS_WIDTH  = (F==8)? (8*8*L*N/N_PRIME) : (F==4)? (8*4*L*N/N_PRIME) : (F==2) ? (F2_FRAMECLK_DIV*8*2*L*N/N_PRIME) : (F==1) ? (F1_FRAMECLK_DIV*8*1*L*N/N_PRIME) : 1,
   parameter CONTROL_BUS_WIDTH = ( (CS==0) ? 1 : (OUTPUT_BUS_WIDTH/N*CS) )
) 
(
   input    wire   rxlink_clk,
   input    wire   rxframe_clk,
   input    wire   rxframe_rst_n,
   input    wire   rxlink_rst_n,
   input    wire   [4:0]  csr_l,
   input    wire   [7:0]  csr_f,
   input    wire   [4:0]  csr_n,
   input    wire   link_tprt_rxdata_valid,
   input    wire   [(L * 32)-1:0]  link_tprt_rx_datain,
   input    wire   avalon_tprt_rx_ready,
   output   reg    [OUTPUT_BUS_WIDTH-1:0] tprt_avalon_rx_data,
   output   reg    [CONTROL_BUS_WIDTH-1:0] tprt_avalon_rx_control,
   output   reg    tprt_avalon_rx_data_valid,
   output   reg    tprt_link_rx_error,
   output   reg    tprt_link_rxdata_ready //done
);

   localparam MAX_M_MUL_S                      = OUTPUT_BUS_WIDTH/N;  //output bus width=M*S*N
   localparam MAX_REASSEMBLED_WIDTH            = MAX_M_MUL_S*N_PRIME;
   localparam F1_PAD_TO_MAX_REASSEMBLED_WIDTH  = (MAX_REASSEMBLED_WIDTH > (8*L*F1_FRAMECLK_DIV)) ? (MAX_REASSEMBLED_WIDTH - 8*L*F1_FRAMECLK_DIV) : 0;
   localparam F2_PAD_TO_MAX_REASSEMBLED_WIDTH  = (MAX_REASSEMBLED_WIDTH > (16*L*F2_FRAMECLK_DIV)) ? (MAX_REASSEMBLED_WIDTH - 16*L*F2_FRAMECLK_DIV) : 0;
   localparam F4_PAD_TO_MAX_REASSEMBLED_WIDTH  = (MAX_REASSEMBLED_WIDTH > (32*L)) ? (MAX_REASSEMBLED_WIDTH - 32*L) : 0;
   localparam N12_PAD_TO_OUTPUT_WIDTH          = OUTPUT_BUS_WIDTH - 12*MAX_M_MUL_S;
   localparam N13_PAD_TO_OUTPUT_WIDTH          = OUTPUT_BUS_WIDTH - 13*MAX_M_MUL_S;
   localparam N14_PAD_TO_OUTPUT_WIDTH          = OUTPUT_BUS_WIDTH - 14*MAX_M_MUL_S;
   localparam N15_PAD_TO_OUTPUT_WIDTH          = OUTPUT_BUS_WIDTH - 15*MAX_M_MUL_S;
   localparam F1F2F4_BUS_WIDTH                 = (F==1)? (F1_FRAMECLK_DIV*8*1*L*N/N_PRIME) : (F==2) ? (F2_FRAMECLK_DIV*8*2*L*N/N_PRIME) : (8*4*L*N/N_PRIME);
   localparam F1F2F4_MAX_M_MUL_S               = F1F2F4_BUS_WIDTH/N;
   localparam F1F2F4_REASSEMBLED_WIDTH         = F1F2F4_MAX_M_MUL_S*N_PRIME;
   localparam F1F2F4_PAD_TO_MAX_DATA_WIDTH     = MAX_REASSEMBLED_WIDTH - F1F2F4_REASSEMBLED_WIDTH;
   localparam F2_PAD_TO_F1F2F4_DATA_WIDTH      = F1F2F4_REASSEMBLED_WIDTH - 16*L*F2_FRAMECLK_DIV;
   localparam F1_PAD_TO_F1F2F4_DATA_WIDTH      = F1F2F4_REASSEMBLED_WIDTH - 8*L*F1_FRAMECLK_DIV;

   //common variables
   reg csr_f0;
   reg csr_f1;
   reg csr_f3;
   reg csr_f7;
   reg csr_n12;
   reg csr_n13;
   reg csr_n14;
   reg csr_n15;
   reg csr_n16;
   reg [7:0] csr_pdlane;
   
   //variables for F=1
   wire [(L+1)/2-1:0][N_PRIME-1:0] f1_b0_rx_datain_2L;
   wire [(L+1)/2-1:0][N_PRIME-1:0] f1_b1_rx_datain_2L;
   wire [(L+1)/2-1:0][N_PRIME-1:0] f1_b2_rx_datain_2L;
   wire [(L+1)/2-1:0][N_PRIME-1:0] f1_b3_rx_datain_2L;
   //M*S*N_PRIME=8*F*L, when F=1, M*S*N_PRIME=8*L
   wire                [(8*L)-1:0] f1_b0_rx_datain; 
   wire                [(8*L)-1:0] f1_b1_rx_datain;
   wire                [(8*L)-1:0] f1_b2_rx_datain;
   wire                [(8*L)-1:0] f1_b3_rx_datain;
   reg                       [1:0] f1_div1_cnt;
   wire [(F1_FRAMECLK_DIV*8*L)-1:0] f1_rx_data;

   //variables for F=2
   wire [L-1:0][N_PRIME-1:0] f2_b0b1_rx_datain_1L;
   wire [L-1:0][N_PRIME-1:0] f2_b2b3_rx_datain_1L;
   //M*S*N_PRIME=8*F*L, when F=2, M*S*N_PRIME=16*L
   wire         [(16*L)-1:0] f2_b0b1_rx_datain;
   wire         [(16*L)-1:0] f2_b2b3_rx_datain;
   reg                       f2_div1_cnt;
   wire [(F2_FRAMECLK_DIV*16*L)-1:0] f2_rx_data;
   
   //variables for F=4
   wire  [L-1:0][31:0] f4_rx_datain_1L;
   //M*S*N_PRIME=8*F*L, when F=4, M*S*N_PRIME=32*L
   wire   [(32*L)-1:0] f4_rx_datain;
   wire   [(32*L)-1:0] f4_rx_data;

   //variables for F=8
   wire  [L-1:0][31:0] f8_rx_datain_1L;
   reg   [L-1:0][31:0] f8_rxfifo_entry0;
   reg   [L-1:0][31:0] f8_rxfifo_entry1;
   reg   [L-1:0][31:0] f8_rxfifo_entry2;
   reg   [L-1:0][31:0] f8_rxfifo_entry3;
   reg   [L-1:0][31:0] f8_rxfifo_entry4;
   reg   [L-1:0][31:0] f8_rxfifo_entry5;
   reg           [2:0] f8_rxfifo_wptr;
   reg           [2:0] f8_rxfifo_rptr;
   //M*S*N_PRIME=8*F*L, when F=8, M*S*N_PRIME=64*L
   wire  [L-1:0][63:0] f8_rx_reg;
   reg           [1:0] f8_read_ready;
   wire   [(64*L)-1:0] f8_rx_data;
   wire                f8_rx_ready;

   //Tail dropping
   reg [F1F2F4_REASSEMBLED_WIDTH-1:0] rxdata_mux_out={F1F2F4_REASSEMBLED_WIDTH{1'b0}} ;
   reg [MAX_REASSEMBLED_WIDTH-1:0] rxdata_b4_td;
   reg      [OUTPUT_BUS_WIDTH-1:0] rxdata_td={OUTPUT_BUS_WIDTH{1'b0}}; 
   wire     [OUTPUT_BUS_WIDTH-1:0] rxdata_td_12; 
   wire     [OUTPUT_BUS_WIDTH-1:0] rxdata_td_13; 
   wire     [OUTPUT_BUS_WIDTH-1:0] rxdata_td_14; 
   wire     [OUTPUT_BUS_WIDTH-1:0] rxdata_td_15; 
   reg     [CONTROL_BUS_WIDTH-1:0] rxctl_td={CONTROL_BUS_WIDTH{1'b0}}; 
   wire    [CONTROL_BUS_WIDTH-1:0] rxctl_td_12; 
   wire    [CONTROL_BUS_WIDTH-1:0] rxctl_td_13; 
   wire    [CONTROL_BUS_WIDTH-1:0] rxctl_td_14; 
   wire    [CONTROL_BUS_WIDTH-1:0] rxctl_td_15; 
   
   //tprt_link_rx_error
   wire   rxerror;
   wire   rxerror_1_ext;
   wire   rxerror_3_ext;
   wire   rxerror_1st_muxed;
   wire   rxerror_2nd_muxed;
   reg    rxerror_1st_flop;
   reg    rxerror_2nd_flop;
   reg    rxerror_3rd_flop;
   reg    rxerror_4th_flop;
   
   //output
   reg link_tprt_rxdata_valid_d1;
   
   genvar i;
   genvar j;
   
   always @ (posedge rxframe_clk)
   begin
   	 if (!rxframe_rst_n)
   	 begin
	 	    csr_f0     <= 1'b0;
	 	    csr_f1     <= 1'b0;
	 	    csr_f3     <= 1'b0;
	 	    csr_f7     <= 1'b0;
	 	    csr_n12    <= 1'b0;
	 	    csr_n13    <= 1'b0;
	 	    csr_n14    <= 1'b0;
	 	    csr_n15    <= 1'b0;
	 	    csr_n16    <= 1'b0;
	 	    csr_pdlane <= 8'b000;
   	 end
	    else
	    begin
	 	    csr_f0     <= (csr_f == 8'h00);
	 	    csr_f1     <= (csr_f == 8'h01);
	 	    csr_f3     <= (csr_f == 8'h03);
	 	    csr_f7     <= (csr_f == 8'h07);
	 	    csr_n12    <= (csr_n == 5'd11);
	 	    csr_n13    <= (csr_n == 5'd12);
	 	    csr_n14    <= (csr_n == 5'd13);
	 	    csr_n15    <= (csr_n == 5'd14);
	 	    csr_n16    <= (csr_n == 5'd15);
	 	    csr_pdlane <= (csr_l==5'd0)? 8'b11111110 : (csr_l==5'd1)? 8'b11111100 : (csr_l==5'd2)? 8'b11111000 : (csr_l==5'd3)? 8'b11110000 : 
	 	                  (csr_l==5'd4)? 8'b11100000 : (csr_l==5'd5)? 8'b11000000 : (csr_l==5'd6)? 8'b10000000 : 8'b00000000;
	    end
   end

   ///////////////////////////////////////////////////////////////////////////////////////
   //      F=1
   ///////////////////////////////////////////////////////////////////////////////////////
   generate
   if ( ((!RECONFIG_EN && (F==1)) || RECONFIG_EN) && !(L%2) ) //generate only when it is even L
   begin
      for (i=0;i<L/2;i=i+1)
      begin : F1
         //lower byte from Odd lane:1, 3, 5, 7. For Odd L, the next lane
      	 //for ODD number of total L, added another dummy lanes with data tied to zeros
         assign f1_b0_rx_datain_2L[i][0 +: 8]  = (!csr_pdlane[i*2+1]) ? link_tprt_rx_datain[(((i*2+1)<L)?((i*8+7)*8):(i*8+3)*8) +: 8] : 8'b0;
         assign f1_b1_rx_datain_2L[i][0 +: 8]  = (!csr_pdlane[i*2+1]) ? link_tprt_rx_datain[(((i*2+1)<L)?((i*8+6)*8):(i*8+2)*8) +: 8] : 8'b0;
         assign f1_b2_rx_datain_2L[i][0 +: 8]  = (!csr_pdlane[i*2+1]) ? link_tprt_rx_datain[(((i*2+1)<L)?((i*8+5)*8):(i*8+1)*8) +: 8] : 8'b0;
         assign f1_b3_rx_datain_2L[i][0 +: 8]  = (!csr_pdlane[i*2+1]) ? link_tprt_rx_datain[(((i*2+1)<L)?((i*8+4)*8):(i*8+0)*8) +: 8] : 8'b0;

         //upper byte from Even lane:0, 2, 4, 6 
         assign f1_b0_rx_datain_2L[i][8 +: 8]  = (!csr_pdlane[i*2]) ? link_tprt_rx_datain[(i*8+3)*8 +: 8] : 8'b0;
         assign f1_b1_rx_datain_2L[i][8 +: 8]  = (!csr_pdlane[i*2]) ? link_tprt_rx_datain[(i*8+2)*8 +: 8] : 8'b0;
         assign f1_b2_rx_datain_2L[i][8 +: 8]  = (!csr_pdlane[i*2]) ? link_tprt_rx_datain[(i*8+1)*8 +: 8] : 8'b0;
         assign f1_b3_rx_datain_2L[i][8 +: 8]  = (!csr_pdlane[i*2]) ? link_tprt_rx_datain[(i*8+0)*8 +: 8] : 8'b0;

         assign f1_b0_rx_datain[i*16 +: 16]  = f1_b0_rx_datain_2L[i];
         assign f1_b1_rx_datain[i*16 +: 16]  = f1_b1_rx_datain_2L[i];
         assign f1_b2_rx_datain[i*16 +: 16]  = f1_b2_rx_datain_2L[i];
         assign f1_b3_rx_datain[i*16 +: 16]  = f1_b3_rx_datain_2L[i];
      end    

      if (F1_FRAMECLK_DIV==1)
      begin
         always @ (posedge rxframe_clk)
         begin
         	 if (!rxframe_rst_n)
      	    	  f1_div1_cnt   <= 2'b0;
         	 else
         	 	  f1_div1_cnt   <= (!link_tprt_rxdata_valid) ? 2'b00 : f1_div1_cnt+2'b01;
         end
      
         assign f1_rx_data   = (!link_tprt_rxdata_valid) ? {8*L{1'b0}} : ( (f1_div1_cnt==2'b01) ? f1_b1_rx_datain : 
      	    	                                                             (f1_div1_cnt==2'b10) ? f1_b2_rx_datain :
      	 	                                                                 (f1_div1_cnt==2'b11) ? f1_b3_rx_datain : f1_b0_rx_datain );
      end
      else if (F1_FRAMECLK_DIV==4)
         assign f1_rx_data   = (!link_tprt_rxdata_valid) ? {(F1_FRAMECLK_DIV*8*L){1'b0}} : {f1_b3_rx_datain, f1_b2_rx_datain, f1_b1_rx_datain, f1_b0_rx_datain};
      else
         assign f1_rx_data   = {(F1_FRAMECLK_DIV*8*L){1'bX}}; //assign X to data as it is a not supported setting
   end
   endgenerate

   ///////////////////////////////////////////////////////////////////////////////////////
   //      F=2
   ///////////////////////////////////////////////////////////////////////////////////////
   generate
   if ( (!RECONFIG_EN && (F==2)) || (RECONFIG_EN && (F!=1)) )
   begin
      for (i=0;i<L;i=i+1)
      begin : F2
         assign f2_b0b1_rx_datain_1L[i] = {link_tprt_rx_datain[(i*2+1)*16 +: 16]}; //[31:16]
         assign f2_b2b3_rx_datain_1L[i] =   {link_tprt_rx_datain[(i*2)*16 +: 16]}; //[15:0]
      
         assign f2_b0b1_rx_datain[i*16 +: 16]   = (!csr_pdlane[i]) ? f2_b0b1_rx_datain_1L[i] : 16'b0;
         assign f2_b2b3_rx_datain[i*16 +: 16]   = (!csr_pdlane[i]) ? f2_b2b3_rx_datain_1L[i] : 16'b0;
      end  
   
      if (F2_FRAMECLK_DIV==1)
      begin
         always @ (posedge rxframe_clk)
         begin
      	    if (!rxframe_rst_n)
      	 	     f2_div1_cnt   <= 1'b0;
      	    else
      	 	     f2_div1_cnt   <= (!link_tprt_rxdata_valid) ? 1'b0 : !f2_div1_cnt;
         end
      
         assign f2_rx_data   = (!link_tprt_rxdata_valid) ? {16*L{1'b0}} : (f2_div1_cnt) ? f2_b2b3_rx_datain : f2_b0b1_rx_datain;
      end
      else if (F2_FRAMECLK_DIV==2)
         assign f2_rx_data   = (!link_tprt_rxdata_valid) ? {16*L*F2_FRAMECLK_DIV{1'b0}} : {f2_b2b3_rx_datain, f2_b0b1_rx_datain};
      else
         assign f2_rx_data   = {(16*L*F2_FRAMECLK_DIV){1'bX}}; //assign X to data as it is a not supported setting
   end  
   endgenerate

   ///////////////////////////////////////////////////////////////////////////////////////
   //      F=4
   ///////////////////////////////////////////////////////////////////////////////////////
   generate
   if ( (!RECONFIG_EN && (F==4)) || (RECONFIG_EN && (F!=1 && F!=2)) )
   begin
      for (i=0;i<L;i=i+1)
      begin : F4
         assign f4_rx_datain_1L[i] = {link_tprt_rx_datain[(i*2)*16 +: 16], link_tprt_rx_datain[(i*2+1)*16 +: 16]}; //[15:0],[31:16]

         assign f4_rx_datain[i*32 +: 32] = (!csr_pdlane[i]) ? f4_rx_datain_1L[i] : 32'b0;
      end

      assign f4_rx_data = (!link_tprt_rxdata_valid) ? {32*L*{1'b0}} : f4_rx_datain;
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
         assign f8_rx_datain_1L[i] = {link_tprt_rx_datain[(i*2)*16 +: 16], link_tprt_rx_datain[(i*2+1)*16 +: 16]}; //[15:0],[31:16]

         // instatiate 1 FIFO 32b width for each L
      	 always @ (posedge rxlink_clk)
      	 begin
         	  if (!rxlink_rst_n)
      	    begin
               f8_rxfifo_entry0[i] <= 32'b0;
               f8_rxfifo_entry1[i] <= 32'b0;
               f8_rxfifo_entry2[i] <= 32'b0;
               f8_rxfifo_entry3[i] <= 32'b0;
               f8_rxfifo_entry4[i] <= 32'b0;
               f8_rxfifo_entry5[i] <= 32'b0;
   	        end
   	        else
   	        begin
               f8_rxfifo_entry0[i] <= (!csr_pdlane[i]) ? ((f8_rxfifo_wptr==3'b000) ? f8_rx_datain_1L[i] : f8_rxfifo_entry0[i]) : 32'b0;
               f8_rxfifo_entry1[i] <= (!csr_pdlane[i]) ? ((f8_rxfifo_wptr==3'b001) ? f8_rx_datain_1L[i] : f8_rxfifo_entry1[i]) : 32'b0;
               f8_rxfifo_entry2[i] <= (!csr_pdlane[i]) ? ((f8_rxfifo_wptr==3'b010) ? f8_rx_datain_1L[i] : f8_rxfifo_entry2[i]) : 32'b0;
               f8_rxfifo_entry3[i] <= (!csr_pdlane[i]) ? ((f8_rxfifo_wptr==3'b011) ? f8_rx_datain_1L[i] : f8_rxfifo_entry3[i]) : 32'b0;
               f8_rxfifo_entry4[i] <= (!csr_pdlane[i]) ? ((f8_rxfifo_wptr==3'b100) ? f8_rx_datain_1L[i] : f8_rxfifo_entry4[i]) : 32'b0;
               f8_rxfifo_entry5[i] <= (!csr_pdlane[i]) ? ((f8_rxfifo_wptr==3'b101) ? f8_rx_datain_1L[i] : f8_rxfifo_entry5[i]) : 32'b0;
   	        end
   	     end

         assign f8_rx_reg[i][31:0]  = (f8_rxfifo_rptr[2:1]==2'b00) ? f8_rxfifo_entry0[i] : 
                                      (f8_rxfifo_rptr[2:1]==2'b01) ? f8_rxfifo_entry2[i] : 
                                      (f8_rxfifo_rptr[2:1]==2'b10) ? f8_rxfifo_entry4[i] : 32'b0;

         assign f8_rx_reg[i][63:32] = (f8_rxfifo_rptr[2:1]==2'b00) ? f8_rxfifo_entry1[i] : 
                                      (f8_rxfifo_rptr[2:1]==2'b01) ? f8_rxfifo_entry3[i] : 
                                      (f8_rxfifo_rptr[2:1]==2'b10) ? f8_rxfifo_entry5[i] : 32'b0;
                                      
         assign f8_rx_data[i*64 +: 64] = f8_rx_reg[i];
      end    

      always @ (posedge rxlink_clk)
   	     if (!rxlink_rst_n)
   	     begin
            f8_rxfifo_wptr   <= 3'b0;
            f8_rxfifo_rptr   <= 3'b0;
            f8_read_ready    <= 2'b0;
   	     end
   	     else
   	     begin
            f8_rxfifo_wptr   <= (!link_tprt_rxdata_valid) ? 3'b000 : ( (f8_rxfifo_wptr==3'b101) ? 3'b000: f8_rxfifo_wptr+3'b001 ); 
            f8_rxfifo_rptr   <= (!f8_read_ready[0]) ? 3'b111 : ( (f8_rxfifo_rptr==3'b101) ? 3'b000: f8_rxfifo_rptr+3'b001 ); 
            f8_read_ready    <= {(f8_read_ready[0]&&link_tprt_rxdata_valid), link_tprt_rxdata_valid};
   	     end

      assign f8_rx_ready = f8_read_ready[1];
   end
   else
      assign f8_rx_ready = 1'b0;
   endgenerate
   
   ///////////////////////////////////////////////////////////////////////////////////////
   //      Mux the input from different F
   // The mux that taking input of F==? within the if generate(F==?) 
   // is to avoid the warning on f?_rx_data
   // e.g. if(F==4), the assign rxdata_b4_td = (F==8) ? is to avoid the warning on f8_rx_data
   ///////////////////////////////////////////////////////////////////////////////////////
   generate
   if (!RECONFIG_EN && F==8)
   begin
      assign rxdata_b4_td = f8_rx_data;
   end 
   else if (!RECONFIG_EN && F==4)
   begin
      always @ (posedge rxframe_clk)
      begin
   	    if (!rxframe_rst_n)
   	    begin
   	 	     rxdata_mux_out        <= {F1F2F4_REASSEMBLED_WIDTH{1'b0}};
   	    end
   	    else
	       begin
   	 	     rxdata_mux_out        <= f4_rx_data;
	       end
      end
      
      assign rxdata_b4_td = rxdata_mux_out;
   end 
   else if (!RECONFIG_EN && F==2)
   begin
      always @ (posedge rxframe_clk)
      begin
   	    if (!rxframe_rst_n)
   	    begin
   	 	     rxdata_mux_out        <= {F1F2F4_REASSEMBLED_WIDTH{1'b0}};
   	    end
   	    else
	       begin
   	 	     rxdata_mux_out        <= f2_rx_data;
	       end
      end
      
      assign rxdata_b4_td = rxdata_mux_out;
   end 
   else if (!RECONFIG_EN && F==1)
   begin
      always @ (posedge rxframe_clk)
      begin
   	    if (!rxframe_rst_n)
   	    begin
   	 	     rxdata_mux_out        <= {F1F2F4_REASSEMBLED_WIDTH{1'b0}};
   	    end
   	    else
	       begin
   	 	     rxdata_mux_out        <= f1_rx_data;
	       end
      end

      assign rxdata_b4_td = rxdata_mux_out;
   end 
   else if (RECONFIG_EN && F==8 && !(L%2))
   begin
      always @ (posedge rxframe_clk)
      begin
   	    if (!rxframe_rst_n)
   	    begin
   	 	     rxdata_mux_out        <= {F1F2F4_REASSEMBLED_WIDTH{1'b0}};
   	    end
   	    else
	       begin
   	 	     rxdata_mux_out        <= (csr_f0) ? {{(F1_PAD_TO_F1F2F4_DATA_WIDTH){1'b0}}, f1_rx_data} : 
   	 	                              (csr_f1) ? {{(F2_PAD_TO_F1F2F4_DATA_WIDTH){1'b0}}, f2_rx_data} :
   	 	                              (csr_f3) ? f4_rx_data : {F1F2F4_REASSEMBLED_WIDTH{1'b0}};
	       end
      end

      assign rxdata_b4_td = (csr_f7) ? f8_rx_data : {{F1F2F4_PAD_TO_MAX_DATA_WIDTH{1'b0}}, rxdata_mux_out};
   end
   else if (RECONFIG_EN && F==8 && (L%2)) //odd L does not support F=1
   begin
      always @ (posedge rxframe_clk)
      begin
   	    if (!rxframe_rst_n)
   	    begin
   	 	     rxdata_mux_out        <= {F1F2F4_REASSEMBLED_WIDTH{1'b0}};
   	    end
   	    else
	       begin
   	 	     rxdata_mux_out        <= (csr_f1) ? {{(F2_PAD_TO_F1F2F4_DATA_WIDTH){1'b0}}, f2_rx_data} :
   	 	                              (csr_f3) ? f4_rx_data : {F1F2F4_REASSEMBLED_WIDTH{1'b0}};
	       end
      end

      assign rxdata_b4_td = (csr_f7) ? f8_rx_data : {{F1F2F4_PAD_TO_MAX_DATA_WIDTH{1'b0}}, rxdata_mux_out};
   end
   else if (RECONFIG_EN && F==4 && !(L%2))
   begin
      always @ (posedge rxframe_clk)
      begin
   	    if (!rxframe_rst_n)
   	    begin
   	 	     rxdata_mux_out        <= {F1F2F4_REASSEMBLED_WIDTH{1'b0}};
   	    end
   	    else
	       begin
   	 	     rxdata_mux_out        <= (csr_f0) ? {{(F1_PAD_TO_F1F2F4_DATA_WIDTH){1'b0}}, f1_rx_data} : 
   	 	                              (csr_f1) ? {{(F2_PAD_TO_F1F2F4_DATA_WIDTH){1'b0}}, f2_rx_data} :
   	 	                              (csr_f3) ? f4_rx_data : {F1F2F4_REASSEMBLED_WIDTH{1'b0}};
	       end
      end
      	
      assign rxdata_b4_td = rxdata_mux_out;
   end
   else if (RECONFIG_EN && F==4 && (L%2)) //odd L does not support F=1
   begin
      always @ (posedge rxframe_clk)
      begin
   	    if (!rxframe_rst_n)
   	    begin
   	 	     rxdata_mux_out        <= {F1F2F4_REASSEMBLED_WIDTH{1'b0}};
   	    end
   	    else
	       begin
   	 	     rxdata_mux_out        <= (csr_f1) ? {{(F2_PAD_TO_F1F2F4_DATA_WIDTH){1'b0}}, f2_rx_data} :
   	 	                              (csr_f3) ? f4_rx_data : {F1F2F4_REASSEMBLED_WIDTH{1'b0}};
	       end
      end
      	
      assign rxdata_b4_td = rxdata_mux_out;
   end
   else if (RECONFIG_EN && F==2 && !(L%2))
   begin
      always @ (posedge rxframe_clk)
      begin
   	    if (!rxframe_rst_n)
   	    begin
   	 	     rxdata_mux_out        <= {F1F2F4_REASSEMBLED_WIDTH{1'b0}};
   	    end
   	    else
	       begin
   	 	     rxdata_mux_out        <= (csr_f0) ? {{(F1_PAD_TO_F1F2F4_DATA_WIDTH){1'b0}}, f1_rx_data} : 
   	 	                              (csr_f1) ? f2_rx_data : {F1F2F4_REASSEMBLED_WIDTH{1'b0}};
	       end
      end
      	
      assign rxdata_b4_td = rxdata_mux_out;
   end
   else if (RECONFIG_EN && F==2 && (L%2)) //odd L does not support F=1
   begin
      always @ (posedge rxframe_clk)
      begin
   	    if (!rxframe_rst_n)
   	    begin
   	 	     rxdata_mux_out        <= {F1F2F4_REASSEMBLED_WIDTH{1'b0}};
   	    end
   	    else
	       begin
   	 	     rxdata_mux_out        <= (csr_f1) ? f2_rx_data : {F1F2F4_REASSEMBLED_WIDTH{1'b0}};
	       end
      end
      	
      assign rxdata_b4_td = rxdata_mux_out;
   end
   else if (RECONFIG_EN && F==1 && !(L%2))
   begin
      always @ (posedge rxframe_clk)
      begin
   	    if (!rxframe_rst_n)
   	    begin
   	 	     rxdata_mux_out        <= {F1F2F4_REASSEMBLED_WIDTH{1'b0}};
   	    end
   	    else
	       begin
   	 	     rxdata_mux_out        <= (csr_f0) ? f1_rx_data : {F1F2F4_REASSEMBLED_WIDTH{1'b0}};
	       end
      end
      	
      assign rxdata_b4_td = rxdata_mux_out; 
   end   
   endgenerate
   	 	                   
   ///////////////////////////////////////////////////////////////////////////////////////
   //      Tail Dropping for different N
   ///////////////////////////////////////////////////////////////////////////////////////
   generate 
   if (N==15 || N==16)
   begin
      for (j=1;j<=MAX_M_MUL_S;j=j+1)
      begin : N15
         assign rxdata_td_15[j*15-1 -: 15] = rxdata_b4_td[j*16-1 -: 15];
      end
   end
   else if (!RECONFIG_EN)
      assign rxdata_td_15  = {OUTPUT_BUS_WIDTH{1'b0}};
   endgenerate

   generate 
   if (N==15 && (CS!=0)) 
   begin
      for (j=1;j<=MAX_M_MUL_S;j=j+1)
      begin : N15_CTL
         assign rxctl_td_15[j*CS-1 -: CS]  = rxdata_b4_td[j*16-1-15 -: CS];
      end
   end
   else if (!RECONFIG_EN)
      assign rxctl_td_15  = {CONTROL_BUS_WIDTH{1'b0}};
   endgenerate
      
   generate 
   if (N==14 || N==15 || N==16)
   begin
      for (j=1;j<=MAX_M_MUL_S;j=j+1)
      begin : N14
         assign rxdata_td_14[j*14-1 -: 14] = rxdata_b4_td[j*16-1 -: 14];
      end
   end
   else if (!RECONFIG_EN)
      assign rxdata_td_14  = {OUTPUT_BUS_WIDTH{1'b0}};
   endgenerate

   generate 
   if ( (N==14 || N==15) && (CS!=0) )
   begin
      for (j=1;j<=MAX_M_MUL_S;j=j+1)
      begin : N14_CTL
         assign rxctl_td_14[j*CS-1 -: CS]  = rxdata_b4_td[j*16-1-14 -: CS];
      end
   end
   else if (!RECONFIG_EN)
      assign rxctl_td_14  = {CONTROL_BUS_WIDTH{1'b0}};
   endgenerate

   generate 
   if (N==13 || N==14 || N==15 || N==16)
   begin
      for (j=1;j<=MAX_M_MUL_S;j=j+1)
      begin : N13
         assign rxdata_td_13[j*13-1 -: 13] = rxdata_b4_td[j*16-1 -: 13];
      end
   end
   else if (!RECONFIG_EN)
      assign rxdata_td_13  = {OUTPUT_BUS_WIDTH{1'b0}};
   endgenerate

   generate 
   if ((N==13 || N==14 || N==15)  && (CS!=0))
   begin
      for (j=1;j<=MAX_M_MUL_S;j=j+1)
      begin : N13_CTL
         assign rxctl_td_13[j*CS-1 -: CS]  = rxdata_b4_td[j*16-1-13 -: CS];
      end
   end
   else if (!RECONFIG_EN)
      assign rxctl_td_13  = {CONTROL_BUS_WIDTH{1'b0}};
   endgenerate

   generate 
   if (N==12 || N==13 || N==14 || N==15 || N==16)
   begin
      for (j=1;j<=MAX_M_MUL_S;j=j+1)
      begin : N12
         assign rxdata_td_12[j*12-1 -: 12] = rxdata_b4_td[j*16-1 -: 12];
      end
   end
   else if (!RECONFIG_EN)
      assign rxdata_td_12  = {OUTPUT_BUS_WIDTH{1'b0}};
   endgenerate

   generate 
   if ( (N==12 || N==13 || N==14 || N==15) && (CS!=0) )
   begin
      for (j=1;j<=MAX_M_MUL_S;j=j+1)
      begin : N12_CTL
         assign rxctl_td_12[j*CS-1 -: CS]  = rxdata_b4_td[j*16-1-12 -: CS];
      end
   end
   else if (!RECONFIG_EN)
      assign rxctl_td_12  = {CONTROL_BUS_WIDTH{1'b0}};
   endgenerate

   generate 
   if (N==16 && RECONFIG_EN)
   begin
      always @ (*)
      begin
         if (csr_n12)
            rxdata_td = {{N12_PAD_TO_OUTPUT_WIDTH{1'b0}}, rxdata_td_12[12*MAX_M_MUL_S-1:0]};
         else if (csr_n13)
            rxdata_td = {{N13_PAD_TO_OUTPUT_WIDTH{1'b0}}, rxdata_td_13[13*MAX_M_MUL_S-1:0]};
         else if (csr_n14)
            rxdata_td = {{N14_PAD_TO_OUTPUT_WIDTH{1'b0}}, rxdata_td_14[14*MAX_M_MUL_S-1:0]};
         else if (csr_n15)
            rxdata_td = {{N15_PAD_TO_OUTPUT_WIDTH{1'b0}}, rxdata_td_15[15*MAX_M_MUL_S-1:0]};
         else if (csr_n16)
            rxdata_td = rxdata_b4_td[OUTPUT_BUS_WIDTH-1:0];
         else
            rxdata_td = {OUTPUT_BUS_WIDTH{1'b0}};
            
         rxctl_td = {CONTROL_BUS_WIDTH{1'b0}};
      end
   end
   endgenerate

   generate 
   if (N==15 && RECONFIG_EN)
   begin
      always @ (*)
      begin
         if (csr_n12)
            rxdata_td = {{N12_PAD_TO_OUTPUT_WIDTH{1'b0}}, rxdata_td_12[12*MAX_M_MUL_S-1:0]};
         else if (csr_n13)
            rxdata_td = {{N13_PAD_TO_OUTPUT_WIDTH{1'b0}}, rxdata_td_13[13*MAX_M_MUL_S-1:0]};
         else if (csr_n14)
            rxdata_td = {{N14_PAD_TO_OUTPUT_WIDTH{1'b0}}, rxdata_td_14[14*MAX_M_MUL_S-1:0]};
         else if (csr_n15)
            rxdata_td = rxdata_td_15[15*MAX_M_MUL_S-1:0];
         else
            rxdata_td = {OUTPUT_BUS_WIDTH{1'b0}};
      end
   end
   endgenerate

   generate 
   if (N==15 && RECONFIG_EN && (CS!=0))
   begin
      always @ (*)
      begin
         if (csr_n12)
            rxctl_td = rxctl_td_12;
         else if (csr_n13)
            rxctl_td = rxctl_td_13;
         else if (csr_n14)
            rxctl_td = rxctl_td_14;
         else if (csr_n15)
            rxctl_td = rxctl_td_15;
         else
            rxctl_td = {CONTROL_BUS_WIDTH{1'b0}};
      end
   end
   endgenerate
   
   generate 
   if (N==14 && RECONFIG_EN)
   begin
      always @ (*)
      begin
         if (csr_n12)
            rxdata_td = {{N12_PAD_TO_OUTPUT_WIDTH{1'b0}}, rxdata_td_12[12*MAX_M_MUL_S-1:0]};
         else if (csr_n13)
            rxdata_td = {{N13_PAD_TO_OUTPUT_WIDTH{1'b0}}, rxdata_td_13[13*MAX_M_MUL_S-1:0]};
         else if (csr_n14)
            rxdata_td = rxdata_td_14[14*MAX_M_MUL_S-1:0];
         else
            rxdata_td = {OUTPUT_BUS_WIDTH{1'b0}};
      end
   end
   endgenerate

   generate 
   if (N==14 && RECONFIG_EN && (CS!=0))
   begin
      always @ (*)
      begin
         if (csr_n12)
            rxctl_td = rxctl_td_12;
         else if (csr_n13)
            rxctl_td = rxctl_td_13;
         else if (csr_n14)
            rxctl_td = rxctl_td_14;
         else
            rxctl_td = {CONTROL_BUS_WIDTH{1'b0}};
      end
   end
   endgenerate

   generate 
   if (N==13 && RECONFIG_EN)
   begin
      always @ (*)
      begin
         if (csr_n12)
            rxdata_td = {{N12_PAD_TO_OUTPUT_WIDTH{1'b0}}, rxdata_td_12[12*MAX_M_MUL_S-1:0]};
         else if (csr_n13)
            rxdata_td = rxdata_td_13[13*MAX_M_MUL_S-1:0];
         else
            rxdata_td = {OUTPUT_BUS_WIDTH{1'b0}};
      end
   end
   endgenerate

   generate 
   if (N==13 && RECONFIG_EN && (CS!=0))
   begin
      always @ (*)
      begin
         if (csr_n12)
            rxctl_td = rxctl_td_12;
         else if (csr_n13)
            rxctl_td = rxctl_td_13;
         else
            rxctl_td = {CONTROL_BUS_WIDTH{1'b0}};
      end
   end
   endgenerate

   generate 
   if (N==12 && RECONFIG_EN)
   begin
      always @ (*)
      begin
         if (csr_n12)
            rxdata_td = rxdata_td_12[12*MAX_M_MUL_S-1:0];
         else
            rxdata_td = {OUTPUT_BUS_WIDTH{1'b0}};
      end
   end
   endgenerate

   generate 
   if (N==12 && RECONFIG_EN && (CS!=0))
   begin
      always @ (*)
      begin
         if (csr_n12)
            rxctl_td = rxctl_td_12;
         else
            rxctl_td = {CONTROL_BUS_WIDTH{1'b0}};
      end
   end
   endgenerate


   generate 
   if (!RECONFIG_EN)
   begin
      always @ (*)
      begin 
         rxdata_td = (N==12) ? rxdata_td_12 : (N==13) ? rxdata_td_13 : (N==14) ? rxdata_td_14 : (N==15) ? rxdata_td_15 : (N==16) ? rxdata_b4_td[OUTPUT_BUS_WIDTH-1:0] :  {OUTPUT_BUS_WIDTH{1'b0}};
         rxctl_td  = (CS==0) ? 1'b0 : (N==12) ? rxctl_td_12 : (N==13) ? rxctl_td_13 : (N==14) ? rxctl_td_14 : (N==15) ? rxctl_td_15 : (N==16) ? 1'b0 :  {CONTROL_BUS_WIDTH{1'b0}};
      end
   end
   endgenerate

   //**************************************************************************************/
   // tprt_link_rx_error
   //**************************************************************************************/
   
   assign  rxerror = tprt_avalon_rx_data_valid && (~avalon_tprt_rx_ready);

   assign  rxerror_1_ext = rxerror_1st_flop || rxerror_2nd_flop;
   assign  rxerror_3_ext = rxerror_1_ext || rxerror_3rd_flop || rxerror_4th_flop;

   always @ (posedge rxframe_clk)
   begin
      if (!rxframe_rst_n)
      begin
            rxerror_1st_flop <= 1'b0;
            rxerror_2nd_flop <= 1'b0;
            rxerror_3rd_flop <= 1'b0;
            rxerror_4th_flop <= 1'b0;
      end
      else
      begin
            rxerror_1st_flop <= rxerror;
            rxerror_2nd_flop <= rxerror_1st_flop;
            rxerror_3rd_flop <= rxerror_2nd_flop;
            rxerror_4th_flop <= rxerror_3rd_flop;
      end
   end

   assign rxerror_1st_muxed = (csr_f0 && (F1_FRAMECLK_DIV ==1)) ? rxerror_3_ext : rxerror_1_ext;
   assign rxerror_2nd_muxed = ( ( csr_f1 || csr_f0 ) && (F1_FRAMECLK_DIV==1 || F2_FRAMECLK_DIV==1) ) ? rxerror_1st_muxed : rxerror;

   always @ (posedge rxlink_clk)
   begin
      if (!rxlink_rst_n)
      begin
            tprt_link_rx_error <= 1'b0;
      end
      else
         begin
            tprt_link_rx_error <= rxerror_2nd_muxed;
      end
   end
   
   ///////////////////////////////////////////////////////////////////////////////////////
   //      Outputs on frame_clk domain
   ///////////////////////////////////////////////////////////////////////////////////////

   always @ (posedge rxframe_clk)
   begin
   	 if (!rxframe_rst_n)
   	 begin
	 	    tprt_avalon_rx_data        <= {OUTPUT_BUS_WIDTH{1'b0}};
   	 	  tprt_avalon_rx_control     <= {CONTROL_BUS_WIDTH{1'b0}};
        tprt_link_rxdata_ready     <= 1'b0;
        link_tprt_rxdata_valid_d1  <= 1'b0;
        tprt_avalon_rx_data_valid  <= 1'b0;
   	 end
	    else
	    begin
   	 	  tprt_avalon_rx_data        <= rxdata_td;
   	 	  tprt_avalon_rx_control     <= (CS==0) ? 1'b0 : rxctl_td[CONTROL_BUS_WIDTH-1:0];
        tprt_link_rxdata_ready     <= 1'b1;
        link_tprt_rxdata_valid_d1  <= link_tprt_rxdata_valid;
        tprt_avalon_rx_data_valid  <= (csr_f7) ? f8_rx_ready : link_tprt_rxdata_valid_d1;
	    end
   end
   
endmodule