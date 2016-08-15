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


//--------------------------------------------------------------------------
// PARAMETERS 
//--------------------------------------------------------------------------
//   POLYNOMIAL_LENGTH    : length of the polynomial (= number of shift register stages)
//   FEEDBACK_TAP         : intermediate stage that is xor-ed with the last stage to generate to next prbs bit 
//   DATA_WIDTH           : converter resolution 
//	  M					  : number of converters
//   FRAMECLK_DIV         : number of frameclk division
//	  S					  : number of converter samples
//------------------------------------------------------------------------------
// PINS DESCRIPTION 
//------------------------------------------------------------------------------
//      rst_n        		: in : syncronous reset active low
//      clk          		: in : system clock
//      enable       		: in : enable/pause pattern generation
//		initial_seed 		: in : initial seed for prbs generator/checker
//		prbs_error_inject	: in : inject error bit 
//      dataout      		: out: generated prbs pattern   
//      csr_s       		: in : csr input for dynamic reconfiguration S 
//      csr_m       		: in : csr input for dynamic reconfiguration M                    
//-------------------------------------------------------------------------------
module prbs_generator #(
   parameter POLYNOMIAL_LENGTH  = 7,
   parameter FEEDBACK_TAP = 6,
   parameter DATA_WIDTH   = 16,
	parameter S = 1,
	parameter M = 1,
	parameter FRAMECLK_DIV = 4		
) (
   input wire rst_n, 
   input wire clk, 
   input wire [4:0] csr_s,
   input wire [7:0] csr_m,
   input wire prbs_error_inject,
   input wire [POLYNOMIAL_LENGTH - 1: 0] initial_seed,
   input wire enable,
   output reg [(FRAMECLK_DIV*M*DATA_WIDTH*S)-1:0] dataout
);
   reg  [6:0] reconf_rate;
   reg  [POLYNOMIAL_LENGTH - 1: 0] prbs_reg;
   wire [POLYNOMIAL_LENGTH - 1:0] prbs [FRAMECLK_DIV*M*DATA_WIDTH*S:0];
   wire [(FRAMECLK_DIV*M*DATA_WIDTH*S)-1:0] pre_tx_prbs;
   wire [(FRAMECLK_DIV*M*DATA_WIDTH*S)-1:0] post_tx_prbs;
   wire [(FRAMECLK_DIV*M*DATA_WIDTH*S)-1:0] prbs_lsb;
   
   wire err_inject;
  
   assign err_inject = (prbs_error_inject) ? 1'b1 : 1'b0;
   	
   assign prbs[0] = prbs_reg; 
	
   genvar i;
   generate for (i = 0; i < FRAMECLK_DIV*M*DATA_WIDTH*S; i = i + 1) begin : GEN_PRBS
      assign pre_tx_prbs[(FRAMECLK_DIV*M*DATA_WIDTH*S)-i-1] = prbs[i][FEEDBACK_TAP - 1] ^ prbs[i][POLYNOMIAL_LENGTH - 1];
	  assign post_tx_prbs[(FRAMECLK_DIV*M*DATA_WIDTH*S)-i-1] = pre_tx_prbs[(FRAMECLK_DIV*M*DATA_WIDTH*S)-i-1] ^ err_inject;
      assign prbs_lsb[i] = pre_tx_prbs[(FRAMECLK_DIV*M*DATA_WIDTH*S)-i-1]; 		
      assign prbs[i+1] = {prbs[i][POLYNOMIAL_LENGTH - 2:0], prbs_lsb[i]};
   end
   endgenerate

	always @(*) begin
	  if(~rst_n)
		reconf_rate <= 7'd0;
	   else
		reconf_rate <= (csr_m+1)*(csr_s+1);
	end 

	always @(posedge clk or negedge rst_n) begin
	  if(~rst_n) begin
		prbs_reg <= initial_seed;
		dataout <= {FRAMECLK_DIV*M*DATA_WIDTH*S{1'b0}};
	   end 
	  else begin
		   if (enable) begin 
			prbs_reg <= prbs[FRAMECLK_DIV*DATA_WIDTH*reconf_rate]; 
			dataout <= post_tx_prbs;
			end
		   else begin
			prbs_reg <= initial_seed;
			dataout <= {FRAMECLK_DIV*M*DATA_WIDTH*S{1'b0}};
		   end
	  end
	 
	end
 
endmodule
