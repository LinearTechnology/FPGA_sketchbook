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
//    rst_n      		   	: in : syncronous reset active low
//    clk         			: in : system clock
//    datain	  			: in : datain
//    enable    		    : in : enable/pause pattern check
//    alternate_err_out     : out: mismatch error detect 
//    csr_s       			: in : csr input for dynamic reconfiguration S 
//    csr_m       			: in : csr input for dynamic reconfiguration M                      
//------------------------------------------------- ------------------------------
module alternate_checker #(
	parameter DATA_WIDTH = 16,
	parameter S = 1,
	parameter M = 1,
	parameter FRAMECLK_DIV = 4,		
	parameter ERR_THRESHOLD = 1
) (
	input wire  rst_n, 
	input wire  clk, 
	input wire [4:0] csr_s,
	input wire [7:0] csr_m,	
	input wire  [(FRAMECLK_DIV*M*DATA_WIDTH*S)-1:0] datain,
	input wire  enable,
	output wire alternate_err_out
);

localparam [DATA_WIDTH-1:0] ALTERNATE_ZERO_ONE_PATTERN = 'h5555;
localparam [DATA_WIDTH-1:0] ALTERNATE_ONE_ZERO_PATTERN = 'hAAAA;
//SM
localparam  IDLE                     = 2'b00;
localparam  INVALID_DATA      		 = 2'b01;
localparam  VALID_DATA		       	 = 2'b10;
localparam  MAX_ERROR_DETECT         = 2'b11; 

reg [4:0] err_count;
reg 	  alternate_err_detect;
reg max_alternate_err_detect;
reg [1:0] current_state;
reg [1:0] 	 next_state;
reg [DATA_WIDTH-1:0] flipcounter_reg;					
reg 		en_delay;
reg [4:0] dly_cnt;
reg [(FRAMECLK_DIV*M*S)-1:0] post_flipcounter_or;
reg [(FRAMECLK_DIV*M*S)-1:0] post_flipcounter_or_masked;
wire 	alternate_err;
wire [(FRAMECLK_DIV*M*S):0][DATA_WIDTH-1:0]   flipcounter;
wire [(FRAMECLK_DIV*M*S)-1:0][DATA_WIDTH-1:0] pre_flipcounter;
wire [(FRAMECLK_DIV*M*S)-1:0][DATA_WIDTH-1:0] post_flipcounter;
wire [6:0] reconf_rate = (csr_m+1)*(csr_s+1);
assign alternate_err_out = alternate_err_detect;  
	
assign flipcounter[0] = flipcounter_reg;

  genvar i;
  generate 
  begin:LOOP
	for (i = 0; i <FRAMECLK_DIV*M*S; i = i + 1) begin : GEN_ALT
		assign pre_flipcounter[i] = ~flipcounter[i];
		assign post_flipcounter[i] = pre_flipcounter[i] ^ datain[DATA_WIDTH*(i+1)-1:i*DATA_WIDTH];	
		assign flipcounter[i+1] = datain[DATA_WIDTH*(i+1)-1:i*DATA_WIDTH]; 	
	end
  end
  endgenerate

integer j;
always @(posedge clk or negedge rst_n) begin
  for (j = 0; j < FRAMECLK_DIV*M*S; j = j + 1) begin 
		if(~rst_n) begin
			post_flipcounter_or[j] <= 1'b0;
			post_flipcounter_or_masked[j] <= 1'b0;
		end 
		else begin
			post_flipcounter_or[j] <= |post_flipcounter[j];	
	
			if (j < FRAMECLK_DIV*reconf_rate)
				post_flipcounter_or_masked[j] <= post_flipcounter_or[j];
			else
				post_flipcounter_or_masked[j] <= 1'b0;
		end
  end
end	
	
//checking data error from 4th user data onward
assign alternate_err = (en_delay) ? (|post_flipcounter_or_masked) : 1'b0;  

	always @(posedge clk or negedge rst_n) begin
		if(~rst_n)
			flipcounter_reg <= ALTERNATE_ONE_ZERO_PATTERN;
			//flipcounter_reg <= ALTERNATE_ZERO_ONE_PATTERN;
		else if (enable)
			flipcounter_reg <= flipcounter[FRAMECLK_DIV*reconf_rate];
		else 
			flipcounter_reg <= ALTERNATE_ONE_ZERO_PATTERN;
	end

//================================================== 
// FSM: Synchronization
//==================================================   
always @ (posedge clk or negedge rst_n)
begin
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
								  
	  VALID_DATA			 : begin
	  
								  if (enable) begin 
									if (max_alternate_err_detect)
										next_state <= MAX_ERROR_DETECT;
								  end 
								  else
								   next_state <= IDLE;
								  
								  end
								  
	  MAX_ERROR_DETECT	  : begin
	  
								  if (enable) begin 
										if (max_alternate_err_detect)
											next_state <= MAX_ERROR_DETECT;
										else 
											next_state <= VALID_DATA;
								  end else
										next_state <= IDLE;	
										
								  end
	 
	 default : next_state <= IDLE;
     endcase
end
 
//delay for 2 cycle before start checking  
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

  
always @(next_state) begin
      if (next_state == MAX_ERROR_DETECT) begin
	    alternate_err_detect <= 1'b1;
	  end else 
		 alternate_err_detect <= 1'b0;	
	
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
	  else if (~alternate_err && err_count == ERR_THRESHOLD)
      err_count <= 5'd0;
	  else if (alternate_err && err_count == ERR_THRESHOLD)
      err_count <= 5'd1;
	  else if (en_delay && alternate_err)
	  err_count <= err_count + 5'd1;
	    
  end
  
 assign max_alternate_err_detect = (err_count == ERR_THRESHOLD) ? 1'b1 : 1'b0;  

endmodule 