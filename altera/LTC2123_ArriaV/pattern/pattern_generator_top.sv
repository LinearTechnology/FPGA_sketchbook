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


//********************************************************************************************
//   Filename       : pattern_generator_top.v
//
//   Description    : Top level JESD204B design example pattern generator for PRBS, Ramp, Alternate checkerboard 
//
//   Limitation     : Supports FRAMECLK_DIV = 1,2 & 4, M = 1, 2, 4, 8(downscale reconfiguration supported) 
//					  and S = 1, 2, 4 (downscale reconfiguration supported)
//
//   Note           : Optional 
//*********************************************************************************************
module pattern_generator_top #(
	parameter FRAMECLK_DIV = 1,
	parameter M = 1,
	parameter N = 16,
	parameter S = 1,
	parameter POLYNOMIAL_LENGTH = 7,
	parameter FEEDBACK_TAP = 6,
   parameter REVERSE_DATA = 0
)
(	
   input wire                          	  clk,
   input wire                          	  rst_n,
   input wire                          	  ready,
   input wire  [3:0]                   	  csr_tx_testmode,
   input wire  [7:0]                      csr_m,
   input wire  [4:0]                      csr_s,    
   input wire   					   	  error_inject,
   output wire                            valid,
   output wire [(FRAMECLK_DIV*M*N*S)-1:0] avst_dataout
);

//testmode data pattern output
reg [(FRAMECLK_DIV*M*N*S)-1:0] alternate_out_N_reg = {(FRAMECLK_DIV*M*N*S){1'b0}};
reg [(FRAMECLK_DIV*M*N*S)-1:0] 		prbs_out_N_reg = {(FRAMECLK_DIV*M*N*S){1'b0}};
reg [(FRAMECLK_DIV*M*N*S)-1:0] 		ramp_out_N_reg = {(FRAMECLK_DIV*M*N*S){1'b0}};
wire [(FRAMECLK_DIV*M*N*S)-1:0] 			  			 dataout;
wire [FRAMECLK_DIV*M*N*S-1:0]  	 test_alternate_gen_out;
wire [FRAMECLK_DIV*M*N*S-1:0]  			test_ramp_gen_out;
wire [FRAMECLK_DIV*M*N*S-1:0]  			test_prbs_gen_out;
wire [FRAMECLK_DIV*M*N*S-1:0]   		 test_prbs_gen_out_N;
wire [FRAMECLK_DIV*M*N*S-1:0]   test_alternate_gen_out_N;
wire [FRAMECLK_DIV*M*N*S-1:0]   		 test_ramp_gen_out_N;

//enable signals for each test pattern generator
wire alternate_genN_ena;
wire prbs_genN_ena;
wire ramp_genN_ena;

//testmode enable & valid signals
reg  		prbs_valid;
reg  		ramp_valid;
reg    alternate_valid;
wire enable_alternate_mode;
wire  	  enable_prbs_mode;
wire 	  enable_ramp_mode;
assign enable_alternate_mode = (csr_tx_testmode == 4'b1000)? 1'b1:1'b0;
assign enable_ramp_mode 	 = (csr_tx_testmode == 4'b1001)? 1'b1:1'b0;
assign enable_prbs_mode 	 = (csr_tx_testmode == 4'b1010)? 1'b1:1'b0;


genvar i;

generate 
begin:LOOP
	for (i = 0; i <FRAMECLK_DIV*M*S; i = i + 1) begin : LOOP					
		always@(*) begin
			if (i < FRAMECLK_DIV*(csr_m+1)*(csr_s+1)) begin
				alternate_out_N_reg[N*(i+1)-1:i*N] <= test_alternate_gen_out_N[N*(i+1)-1:i*N];
				prbs_out_N_reg[N*(i+1)-1:i*N] <= test_prbs_gen_out_N[N*(i+1)-1:i*N];										
				ramp_out_N_reg[N*(i+1)-1:i*N] <= test_ramp_gen_out_N[N*(i+1)-1:i*N];											
			end else begin
				alternate_out_N_reg[N*(i+1)-1:i*N] <= {N{1'b0}};
				prbs_out_N_reg[N*(i+1)-1:i*N] <= {N{1'b0}};										
				ramp_out_N_reg[N*(i+1)-1:i*N] <= {N{1'b0}};
			end
		end					  
	end		
end				
endgenerate 

assign alternate_genN_ena = enable_alternate_mode;
assign ramp_genN_ena = enable_ramp_mode;												  									  								  		
assign prbs_genN_ena = enable_prbs_mode;
	
//alternate pattern generator with data width varied by parameter N						 
 alternate_generator #(
	  .DATA_WIDTH(N),
	  .S(S),
	  .M(M),
	  .FRAMECLK_DIV(FRAMECLK_DIV)
	  ) alternate_genN_inst (
	  .rst_n (rst_n),
	  .clk (clk),
	  .enable(alternate_genN_ena),
	  .csr_s(csr_s),	
	  .csr_m(csr_m),							  
	  .dataout(test_alternate_gen_out_N),
	  .alternate_error_inject(error_inject)
	  );	
 
//ramp pattern generator with data width varied by parameter N						 
 ramp_generator #(
	  .DATA_WIDTH(N),
	  .S(S),
	  .M(M),
	  .FRAMECLK_DIV(FRAMECLK_DIV)
	  ) ramp_genN_inst (
	  .rst_n (rst_n),
	  .clk (clk),
	  .enable(ramp_genN_ena),								  
	  .dataout(test_ramp_gen_out_N),
	  .csr_s(csr_s),
	  .csr_m(csr_m),							  
	  .ramp_error_inject(error_inject)
	  );
 
//prbs pattern generator with data width varied by parameter N						 
 prbs_generator #(
  .POLYNOMIAL_LENGTH(POLYNOMIAL_LENGTH),
  .FEEDBACK_TAP(FEEDBACK_TAP),
  .DATA_WIDTH(N),
  .S(S),
  .M(M),
  .FRAMECLK_DIV(FRAMECLK_DIV)
	  ) prbs_genN_inst (
	  .rst_n (rst_n),
	  .clk (clk),
	  .enable(prbs_genN_ena),
	  .initial_seed(7'h7F),	
	  .csr_s(csr_s),
	  .csr_m(csr_m),							  
	  .dataout(test_prbs_gen_out_N),
	  .prbs_error_inject(error_inject)
	  );
							  
//===OUTPUT DATA========																						  
assign test_alternate_gen_out = alternate_out_N_reg;
															
assign test_ramp_gen_out = ramp_out_N_reg;																	

assign test_prbs_gen_out = prbs_out_N_reg;														
																				  																					  
assign dataout = (csr_tx_testmode == 4'b1000) ? test_alternate_gen_out:
					  (csr_tx_testmode == 4'b1001) ? test_ramp_gen_out:  
					  (csr_tx_testmode == 4'b1010) ? test_prbs_gen_out: 
										  {(FRAMECLK_DIV*M*N*S){1'b0}};

//data reversal, e.g: initial data = {s3, s2, s1, s0}, after enable parameter REVERSE_DATA then the data = {s0, s1, s2, s3}
//only applicable for PRBS test pattern mode											   
genvar j;
generate for (j=0; j<FRAMECLK_DIV*M*S; j=j+1) begin: REVERSE
	assign avst_dataout[N*(j+1)-1:j*N] = (REVERSE_DATA == 1 && enable_prbs_mode) ? dataout[N*(FRAMECLK_DIV*M*S-j)-1:N*(FRAMECLK_DIV*M*S-j-1)] : dataout[N*(j+1)-1:j*N];
end
endgenerate

always @(posedge clk or negedge rst_n)
   begin
   if (~rst_n)
       alternate_valid <= 1'b0;    
   else if (enable_alternate_mode)
		alternate_valid <= 1'b1; 
	else
		alternate_valid <=1'b0;
 end
 
always @(posedge clk or negedge rst_n)
   begin
   if (~rst_n) begin 
       ramp_valid <= 1'b0;  
   end else if (enable_ramp_mode) begin 
		ramp_valid <= 1'b1; 
   end else begin 
		ramp_valid <=1'b0;
   end
 end
	
always @(posedge clk or negedge rst_n)
   begin
   if (~rst_n)
       prbs_valid <= 1'b0;    
   else if (enable_prbs_mode)
		prbs_valid <= 1'b1; 
	else
		prbs_valid <=1'b0;
 end
									  
assign valid = (csr_tx_testmode == 4'b1000) ? alternate_valid: 
					(csr_tx_testmode == 4'b1001) ? ramp_valid: 
					(csr_tx_testmode == 4'b1010) ? prbs_valid: 
														 1'b0;	

endmodule 