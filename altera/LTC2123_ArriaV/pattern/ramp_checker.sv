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
//	ERR_THRESHOLD	   : maximum number of allowable data mismatch 
//  DATA_WIDTH         : converter resolution 
//	 M				   : number of converters
//  FRAMECLK_DIV       : number of frameclk division
//	 S				   : number of converter samples
//------------------------------------------------------------------------------
// PINS DESCRIPTION 
//------------------------------------------------------------------------------
//      rst_n        : in : syncronous reset active low
//      clk          : in : system clock
//		datain	     : in : datain
//      enable       : in : enable/pause pattern check
//      ramp_err_out : out: ramp mismatch error detect  
//      csr_s        : in : csr input for dynamic reconfiguration S 
//      csr_m        : in : csr input for dynamic reconfiguration M                     
//-------------------------------------------------------------------------------
module ramp_checker #(
	parameter DATA_WIDTH = 16,
	parameter S = 1,
	parameter M = 1,
	parameter FRAMECLK_DIV = 4,		
	parameter ERR_THRESHOLD = 1
) 
(   
   input wire                  clk,
   input wire                  rst_n,
   input wire [(FRAMECLK_DIV*M*DATA_WIDTH*S)-1:0] datain,
   input wire 		 	  enable,
   input wire [4:0] 		csr_s,
   input wire [7:0] 		csr_m,	
   output wire 	ramp_err_out
);
  
	//SM
   localparam  IDLE                     	= 2'b00;
   localparam  INVALID_DATA      			= 2'b01;
   localparam  VALID_DATA		       		= 2'b10;
   localparam  MAX_ERROR_DETECT         	= 2'b11;  
	
	reg			  ramp_err_detect;
	reg [DATA_WIDTH-1:0]	ramp_reg;
	reg [1:0] 		 current_state;
	reg [1:0] 			 next_state; 
	reg 					   en_delay; 
	reg [4:0] 			 	 dly_cnt;
	reg [4:0] 			  err_count;
	reg [(FRAMECLK_DIV*M*S)-1:0] post_upcounter_or;
	wire [(FRAMECLK_DIV*M*S)-1:0] post_upcounter_or_masked;
	wire [(FRAMECLK_DIV*M*S)-1:0][DATA_WIDTH-1:0] datain_masked_reg;
	reg [(FRAMECLK_DIV*M*DATA_WIDTH*S)-1:0] datain_reg;
	reg [(FRAMECLK_DIV*M*S)-1:0][DATA_WIDTH-1:0] pre_upcounter;
	reg [(FRAMECLK_DIV*M*S)-1:0][DATA_WIDTH-1:0] post_upcounter;
	wire [6:0] reconf_rate = (csr_m+1)*(csr_s+1);
	wire						    max_ramp_err_detect;
	wire ramp_err;

	assign ramp_err_out = ramp_err_detect;

genvar i;

generate 
begin:GEN_RAMP_LOOP
	for (i=0; i<FRAMECLK_DIV*M*S; i=i+1) begin : GEN_RAMP
	  assign datain_masked_reg[i] = datain[DATA_WIDTH*(i+1)-1:i*DATA_WIDTH]; 
	  assign post_upcounter_or_masked[i] = (i < FRAMECLK_DIV*reconf_rate) ? post_upcounter_or[i] : 1'b0; 

	  always @ (posedge clk or negedge rst_n) begin
		 if (~rst_n) begin
				pre_upcounter[i] <= {DATA_WIDTH{1'b0}};
				post_upcounter[i] = {DATA_WIDTH{1'b0}};
			   datain_reg[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH] <= {DATA_WIDTH{1'b0}};
			end
			else begin	
				datain_reg[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH] <= datain[DATA_WIDTH*(i+1)-1:i*DATA_WIDTH];
				pre_upcounter[i] <= ramp_reg + i;
				post_upcounter[i] = pre_upcounter[i] ^ datain_reg[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH];
			end
	  end
	  
	end

end
endgenerate 

always @ (posedge clk or negedge rst_n) begin

		if(~rst_n)
			ramp_reg <= {DATA_WIDTH{1'b0}};
		else if (enable) begin
			if (FRAMECLK_DIV*M*S == FRAMECLK_DIV*reconf_rate) 
				ramp_reg <= datain_masked_reg[FRAMECLK_DIV*M*S-1] + 1;
			else if (FRAMECLK_DIV*M*S > FRAMECLK_DIV*reconf_rate) 
				ramp_reg <= datain_masked_reg[FRAMECLK_DIV*reconf_rate-1] + 1;
			else
				ramp_reg <= {DATA_WIDTH{1'b0}};
		end else 
			ramp_reg <= {DATA_WIDTH{1'b0}};
	end
	
	integer k;
	always @(posedge clk or negedge rst_n) begin
	  for (k = 0; k < FRAMECLK_DIV*M*S; k = k + 1) begin 
			if(~rst_n)
				post_upcounter_or[k] <= 1'b0;
			else
				post_upcounter_or[k] <= |post_upcounter[k];
	  end
	end
	
	//checking data error from 4th user data onward
    assign ramp_err = (en_delay) ? (| post_upcounter_or_masked) : 1'b0;  
   
   //================================================== 
   // FSM: Synchronization
   //==================================================   
   always @ (posedge clk or negedge rst_n) begin
	  if (~rst_n)
		 current_state <= IDLE;
	  else
		 current_state <= next_state;
   end

   //================================================== 
   // FSM: Evolution & Action (Outputs)
   //================================================== 
   always @ (*)
   begin
      next_state <= current_state;
      case (current_state)
	  IDLE						: begin

								  if (enable) 
									next_state <= INVALID_DATA;
								  else 
								  	next_state <= IDLE;
								  end
								  
	  INVALID_DATA				: begin

								  if (enable) begin 
									 if (dly_cnt == 3) 
									  next_state <= VALID_DATA;
								  end   
								  else 
									next_state <= IDLE;
								  
								  end
								  
	  VALID_DATA				: begin
	  
								  if (enable) begin 
									if (max_ramp_err_detect)
										next_state <= MAX_ERROR_DETECT;
								  end 
								  else
								   next_state <= IDLE;

								  end

								  
	 MAX_ERROR_DETECT	  : begin
	  
								  if (enable) begin 
										if (max_ramp_err_detect)
											next_state <= MAX_ERROR_DETECT;
										else 
											next_state <= VALID_DATA;
								  end else
										next_state <= IDLE;
										
								  end
	 
	  default : next_state <= IDLE;
      endcase
   end 
 
   // delay for 3 cycle before start checking   
   always @(posedge clk or negedge rst_n) begin
      if (~rst_n) begin
		dly_cnt <= 5'd0;
	  end else if (dly_cnt == 5'd3) begin
	    dly_cnt <= 5'd0;
		end else if (enable) begin
	    dly_cnt <= dly_cnt + 5'd1;
	  end else 
		dly_cnt <= 5'd0;	 
   end  

   //enable the error checking from incoming data
   always @(next_state) begin
      if (next_state == VALID_DATA || next_state == MAX_ERROR_DETECT)
	  en_delay <= 1'b1;
	  else
	  en_delay <= 1'b0;
   end  
	
   always @(next_state) begin
      if (next_state == MAX_ERROR_DETECT) begin
	    ramp_err_detect <= 1'b1;
	  end else 
		ramp_err_detect <= 1'b0;		
   end  
 
// start counting before the error threshold is reached 
   always @(posedge clk or negedge rst_n) begin
      if(~rst_n)
         err_count <= 5'd0;
	  else if (~ramp_err && err_count == ERR_THRESHOLD )
         err_count <= 5'd0;
	  else if (ramp_err && err_count == ERR_THRESHOLD )
         err_count <= 5'd1;
	  else if (en_delay && ramp_err)
	     err_count <= err_count + 5'd1;	    
   end
   assign max_ramp_err_detect = (err_count == ERR_THRESHOLD) ? 1'b1 : 1'b0;
 
endmodule
