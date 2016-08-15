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
//   FEEDBACK_TAP   	  : intermediate stage that is xor-ed with the last stage to generate to next prbs bit 
//	 ERR_THRESHOLD		  : maximum number of allowable data mismatch 
//   DATA_WIDTH           : converter resolution 
//	 M					  : number of converters
//   FRAMECLK_DIV         : number of frameclk division
//	 S					  : number of converter samples
//------------------------------------------------------------------------------
// PINS DESCRIPTION 
//------------------------------------------------------------------------------
//      rst_n        : in : syncronous reset active low
//      clk          : in : system clock
//		datain	     : in : datain
//		initial_seed : in : initial seed for prbs generator/checker
//      enable       : in : enable/pause pattern check
//      prbs_err_out : out: prbs mismatch error detect    
//      csr_s        : in : csr input for dynamic reconfiguration S 
//      csr_m        : in : csr input for dynamic reconfiguration M                   
//-------------------------------------------------------------------------------
module prbs_checker #(
   parameter POLYNOMIAL_LENGTH = 7,
   parameter FEEDBACK_TAP = 6,
   parameter DATA_WIDTH = 16,
	parameter S = 1,
	parameter M = 1,
	parameter FRAMECLK_DIV = 4,	
   parameter ERR_THRESHOLD = 1
)
(
   input wire                      clk,
   input wire                      rst_n,
   input wire 					   enable,
   input wire [4:0] 			   csr_s,
   input wire [7:0] 			   csr_m,	
   input wire [POLYNOMIAL_LENGTH - 1: 0] initial_seed,
   input wire [FRAMECLK_DIV*M*DATA_WIDTH*S - 1:0]   datain,
   output wire                     prbs_err_out
);
  
	//SM
   localparam  IDLE                     	= 2'b00;
   localparam  INVALID_DATA      			= 2'b01;
   localparam  VALID_DATA		       		= 2'b10;
   localparam  MAX_ERROR_DETECT         	= 2'b11;  

	reg [POLYNOMIAL_LENGTH - 1: 0] prbs_reg;
	reg [4:0] err_count;
	reg prbs_err_detect;
	reg [1:0] current_state;
	reg [1:0] next_state; 
	reg en_delay;
	reg [4:0] dly_cnt;
	wire [POLYNOMIAL_LENGTH - 1:0] prbs [FRAMECLK_DIV*M*DATA_WIDTH*S:0];
	wire [FRAMECLK_DIV*M*DATA_WIDTH*S - 1:0] pre_tx_prbs;
	wire [FRAMECLK_DIV*M*DATA_WIDTH*S - 1:0] post_tx_prbs;
	wire [FRAMECLK_DIV*M*DATA_WIDTH*S - 1:0] prbs_lsb;
	wire max_prbs_err_detect;
	wire prbs_err;	
	wire [6:0] reconf_rate = (csr_m+1)*(csr_s+1);
	reg [FRAMECLK_DIV*M*S - 1:0] post_tx_prbs_masked_reg;
   reg [FRAMECLK_DIV*M*DATA_WIDTH*S - 1:0] datain_masked_reg;
	assign prbs_err_out = prbs_err_detect;
	
   assign prbs[0] = prbs_reg; 
	
	integer k;
	always @(posedge clk or negedge rst_n) begin
	  for (k = 0; k < FRAMECLK_DIV*M*DATA_WIDTH*S; k = k + 1) begin 
			if(~rst_n) begin
				datain_masked_reg[k] <= 1'b0;
			end 
			else begin	
				if (k < FRAMECLK_DIV*DATA_WIDTH*reconf_rate)
					datain_masked_reg[k] <= datain[FRAMECLK_DIV*DATA_WIDTH*reconf_rate-k-1]; 
				else
					datain_masked_reg[k] <= 1'b0;
			end
	  end
	end
	
   genvar i;
   generate for (i = 0; i < FRAMECLK_DIV*M*DATA_WIDTH*S; i = i + 1) begin : GEN_PRBS
		assign pre_tx_prbs[FRAMECLK_DIV*M*DATA_WIDTH*S-i-1] = prbs[i][FEEDBACK_TAP - 1] ^ prbs[i][POLYNOMIAL_LENGTH - 1];
		assign post_tx_prbs[FRAMECLK_DIV*M*DATA_WIDTH*S-i-1] = pre_tx_prbs[FRAMECLK_DIV*M*DATA_WIDTH*S-i-1] ^ datain_masked_reg[i];			 
		assign prbs_lsb[i] = datain_masked_reg[i]; 
		assign prbs[i+1] = {prbs[i][POLYNOMIAL_LENGTH - 2:0], prbs_lsb[i]};
   end
   endgenerate
	
	
	always @(posedge clk or negedge rst_n) begin
	  if(~rst_n) begin
		 prbs_reg <= initial_seed;
	   end 
	   else begin 
		 if (enable)
		 prbs_reg <= prbs[FRAMECLK_DIV*reconf_rate*DATA_WIDTH];
		 else 
		 prbs_reg <= initial_seed;
	   end
	end
	
	integer j;
	always @(posedge clk or negedge rst_n) begin
	  for (j = 0; j < FRAMECLK_DIV*M*S; j = j + 1) begin 
			if(~rst_n) begin
				post_tx_prbs_masked_reg[j] <= 1'b0;
			end 
			else begin	
				if (j < FRAMECLK_DIV*reconf_rate)
					post_tx_prbs_masked_reg[j] <= |post_tx_prbs[(FRAMECLK_DIV*M*S-j)*DATA_WIDTH-1 -:DATA_WIDTH];
				else
					post_tx_prbs_masked_reg[j] <= 1'b0;
			end
	  end
	end
 
 
   //checking data error from 4th user data onward
   assign prbs_err = (en_delay) ? (| post_tx_prbs_masked_reg) : 1'b0; 
  
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
									 if (dly_cnt == 8) 
									  next_state <= VALID_DATA;
								  end   
								  else 
									next_state <= IDLE;
									
								  end
								  
	  VALID_DATA			  : begin

								  if (enable) begin 
									if (max_prbs_err_detect)
										next_state <= MAX_ERROR_DETECT;
								  end 
								  else
								   next_state <= IDLE;
									
								  end
								  
	  MAX_ERROR_DETECT	  : begin
	  
								  if (enable) begin 
										if (max_prbs_err_detect)
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
	  end else if (dly_cnt == 5'd8) begin
	    dly_cnt <= 5'd0;
		end else if (enable) begin
	    dly_cnt <= dly_cnt + 5'd1;
	  end else 
		dly_cnt <= 5'd0;	 
   end  
  
   always @(next_state) begin
      if (next_state == MAX_ERROR_DETECT) begin
	    prbs_err_detect <= 1'b1;
	  end else 
		prbs_err_detect <= 1'b0;		
   end  

   //enable the error checking from incoming data
   always @(next_state) begin
      if (next_state == VALID_DATA || next_state == MAX_ERROR_DETECT) begin
	     en_delay <= 1'b1;
	  end else 
		 en_delay <= 1'b0;
	  
   end  
 
   // start counting before the error threshold is reached 
   always @(posedge clk or negedge rst_n) begin
      if(~rst_n)
         err_count <= 5'd0;
	  else if (~prbs_err && err_count == ERR_THRESHOLD )
         err_count <= 5'd0;
	  else if (prbs_err && err_count == ERR_THRESHOLD )
         err_count <= 5'd1;
	  else if (en_delay && prbs_err)
	     err_count <= err_count + 5'd1;	    
   end
   assign max_prbs_err_detect = (err_count == ERR_THRESHOLD) ? 1'b1 : 1'b0;
 
endmodule
