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
//  DATA_WIDTH         : converter resolution 
//	 M				   : number of converters
//  FRAMECLK_DIV       : number of frameclk division
//	 S				   : number of converter samples
//------------------------------------------------------------------------------
// PINS DESCRIPTION 
//------------------------------------------------------------------------------
//      rst_n       	    : in : syncronous reset active low
//      clk          		: in : system clock
//      dataout     	    : out: generated ramp pattern    
//		ramp_error_inject	: in : inject error bit 
//      enable       		: in : enable/pause pattern check  
//      csr_s       		: in : csr input for dynamic reconfiguration S 
//      csr_m       		: in : csr input for dynamic reconfiguration M                   
//-------------------------------------------------------------------------------
module ramp_generator #(
	parameter DATA_WIDTH = 16,
	parameter S = 1,
	parameter M = 1,
	parameter FRAMECLK_DIV = 4		
) 
( 
   input wire rst_n,
   input wire clk,
   input wire enable,
   input wire [4:0] csr_s,
   input wire [7:0] csr_m,	
   input wire ramp_error_inject,
   output reg [(FRAMECLK_DIV*M*DATA_WIDTH*S)-1:0] dataout 
);

  wire [(FRAMECLK_DIV*M*S)-1:0][DATA_WIDTH-1:0] post_ramp_reg;
  reg [(FRAMECLK_DIV*M*DATA_WIDTH*S)-1:0] ramp_reg;
  wire [6:0] reconf_rate = (csr_m+1)*(csr_s+1);
  wire 	err_inject;
  assign err_inject = (ramp_error_inject) ? 1'b1 : 1'b0;
  
genvar i;

generate 
begin:GEN_RAMP_LOOP
	for (i=0; i<FRAMECLK_DIV*M*S; i=i+1) begin : GEN_RAMP
	  always @ (posedge clk or negedge rst_n) begin
		 if (~rst_n) begin
			  ramp_reg[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH] <= {DATA_WIDTH{1'b0}};
		  end else begin	  
			 //Only for config case that FRAMECLK_DIV*M*S not equal to one 
			 if (ramp_reg == {FRAMECLK_DIV*M*DATA_WIDTH*S{1'b0}} & (FRAMECLK_DIV*M*S != 1))
				 ramp_reg[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH] <= i;
			 else
				 ramp_reg[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH] <= ramp_reg[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH] + FRAMECLK_DIV*reconf_rate;
		  end
	  end
	  
	  assign post_ramp_reg[i] = ramp_reg[DATA_WIDTH*(i+1)-1:i*DATA_WIDTH] ^ err_inject;
	  
		always @(posedge clk or negedge rst_n) begin
			if(~rst_n) begin
				dataout[DATA_WIDTH*(i+1)-1:i*DATA_WIDTH] <= {DATA_WIDTH{1'b0}};
			end else begin 	
				if (enable)
					dataout[DATA_WIDTH*(i+1)-1:i*DATA_WIDTH] <= post_ramp_reg[i];
				else
					dataout[DATA_WIDTH*(i+1)-1:i*DATA_WIDTH] <= {DATA_WIDTH{1'b0}};	
			end				
		end
	end
end
endgenerate 
  
endmodule
