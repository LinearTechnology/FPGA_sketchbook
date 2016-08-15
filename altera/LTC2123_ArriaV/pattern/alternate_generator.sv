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
//      rst_n       	   			: in : syncronous reset active low
//      clk          				: in : system clock
//      dataout     	   	    	: out: generated alternate pattern 
//		alternate_error_inject		: in : inject error bit    
//      enable      	    		: in : enable/pause pattern check     
//      csr_s       				: in : csr input for dynamic reconfiguration S 
//      csr_m       				: in : csr input for dynamic reconfiguration M                
//-------------------------------------------------------------------------------
module alternate_generator #(
	parameter DATA_WIDTH = 16,
	parameter S = 1,
	parameter M = 1,
	parameter FRAMECLK_DIV = 4	
) 
(   
   input wire rst_n,
   input wire clk,
   input wire [4:0] csr_s,
   input wire [7:0] csr_m,	
   input wire enable,
   input wire alternate_error_inject,
   output reg [(FRAMECLK_DIV*M*DATA_WIDTH*S)-1:0] dataout 
);


  localparam [DATA_WIDTH-1:0] ALTERNATE_ZERO_ONE_PATTERN = 'h5555;
  localparam [DATA_WIDTH-1:0] ALTERNATE_ONE_ZERO_PATTERN = 'hAAAA;
  
  reg [6:0] reconf_rate;
  reg  [DATA_WIDTH-1:0] flipcounter_reg;
  wire [(FRAMECLK_DIV*M*S):0][DATA_WIDTH-1:0] flipcounter;
  wire [(FRAMECLK_DIV*M*S)-1:0][DATA_WIDTH-1:0] pre_flipcounter;
  wire [(FRAMECLK_DIV*M*S)-1:0][DATA_WIDTH-1:0] post_flipcounter;
  wire err_inject;
  
  assign err_inject = (alternate_error_inject) ? 1'b1 : 1'b0;

  assign flipcounter[0] = flipcounter_reg; 
   
  genvar i;
  generate 
  begin:LOOP
	for (i = 0; i <FRAMECLK_DIV*M*S; i = i + 1) begin : GEN_ALT
		assign pre_flipcounter[i] = ~flipcounter[i]; 
		assign post_flipcounter[i] = pre_flipcounter[i] ^ err_inject;
		assign flipcounter[i+1] = pre_flipcounter[i]; 
		
		always @(posedge clk or negedge rst_n) begin
			if(~rst_n)
				dataout[DATA_WIDTH*(i+1)-1:i*DATA_WIDTH] <= {DATA_WIDTH{1'b0}};
			else if (enable)
				dataout[DATA_WIDTH*(i+1)-1:i*DATA_WIDTH] <= post_flipcounter[i];
			else
				dataout[DATA_WIDTH*(i+1)-1:i*DATA_WIDTH] <= {DATA_WIDTH{1'b0}};
		end
		
	end
  end
  endgenerate	

	always @(*) begin
	  if(~rst_n)
		 reconf_rate <= 7'd0;
	   else
		 reconf_rate <= (csr_m+1)*(csr_s+1);
	end 

	always @(posedge clk or negedge rst_n) begin
		if(~rst_n)
			flipcounter_reg <= ALTERNATE_ONE_ZERO_PATTERN;
			//flipcounter_reg <= ALTERNATE_ZERO_ONE_PATTERN;
		else if (enable) 
			flipcounter_reg <= flipcounter[FRAMECLK_DIV*reconf_rate];
		else 
			flipcounter_reg <= ALTERNATE_ONE_ZERO_PATTERN;
	end	
  
endmodule

