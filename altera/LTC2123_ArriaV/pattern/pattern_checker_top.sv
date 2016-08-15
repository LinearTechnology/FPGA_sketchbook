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
//   Filename       : pattern_checker_top.v
//
//   Description    : Top level JESD204B design example pattern checker for PRBS, Ramp, Alternate checkerboard 
//
//   Limitation     : Supports FRAMECLK_DIV = 1,2 & 4, M = 1, 2, 4, 8(downscale reconfiguration supported) 
//					  and S = 1, 2, 4 (downscale reconfiguration supported)
//
//   Note           : Optional 
//*********************************************************************************************
module pattern_checker_top #(
   parameter FRAMECLK_DIV = 1,
   parameter M = 1,
   parameter N = 16,
   parameter S = 1,
   parameter POLYNOMIAL_LENGTH = 7,
   parameter FEEDBACK_TAP = 6,
   parameter ERR_THRESHOLD = 3,
   parameter REVERSE_DATA = 0
)
(
   input wire                           clk,
   input wire                           rst_n,
   input wire                           valid,
   input wire  [3:0]                    csr_rx_testmode,
   input wire  [7:0]                    csr_m,
   input wire  [4:0]                    csr_s,
   input wire  [FRAMECLK_DIV*M*N*S-1:0] avst_datain,
   output wire 							err_out,
   output reg 							ready
);

reg [FRAMECLK_DIV*M*N*S-1:0] datain_reg;
   
//enable signal
wire enable_prbs_mode, enable_alternate_mode, enable_ramp_mode;

//datain for different test pattern modes
reg [FRAMECLK_DIV*M*N*S-1:0] prbs_in_Nbit;
reg [FRAMECLK_DIV*M*N*S-1:0] alternate_in_Nbit;
reg [FRAMECLK_DIV*M*N*S-1:0] ramp_in_Nbit;


//test pattern error signals
wire prbs_error_N;
wire alternate_error_N;
wire ramp_error_N;

//enable signals
reg prbs_chkN_ena;
reg alternate_chkN_ena;
reg ramp_chkN_ena;

wire [FRAMECLK_DIV*M*N*S-1:0] reversed_datain;
   
//data reversal, e.g: initial data = {s3, s2, s1, s0}, after enable parameter REVERSE_DATA then the data = {s0, s1, s2, s3}
//only applicable for PRBS test pattern mode
genvar i;
generate for (i=0; i<FRAMECLK_DIV*M*S; i=i+1) begin: REVERSE
	assign reversed_datain[N*(i+1)-1:i*N] = (REVERSE_DATA == 1 && enable_prbs_mode) ? avst_datain[N*(FRAMECLK_DIV*M*S-i)-1:N*(FRAMECLK_DIV*M*S-i-1)] : avst_datain[N*(i+1)-1:i*N];
end
endgenerate

always @(posedge clk or negedge rst_n)
begin
	if (~rst_n) begin
	  alternate_in_Nbit <= {FRAMECLK_DIV*M*N*S{1'b0}};
	  ramp_in_Nbit <= {FRAMECLK_DIV*M*N*S{1'b0}};
	  prbs_in_Nbit <= {FRAMECLK_DIV*M*N*S{1'b0}};
	end 
	else begin
	  if (csr_rx_testmode == 4'b1000) begin
	     alternate_in_Nbit <= reversed_datain;
		  ramp_in_Nbit <= {FRAMECLK_DIV*M*N*S{1'b0}};
	     prbs_in_Nbit <= {FRAMECLK_DIV*M*N*S{1'b0}};
	  end 
	  else if (csr_rx_testmode == 4'b1001) begin
		  ramp_in_Nbit <= reversed_datain;
		  alternate_in_Nbit <= {FRAMECLK_DIV*M*N*S{1'b0}};
		  prbs_in_Nbit <= {FRAMECLK_DIV*M*N*S{1'b0}};
	  end 
	  else if (csr_rx_testmode == 4'b1010) begin
		  prbs_in_Nbit <= reversed_datain;
		  alternate_in_Nbit <= {FRAMECLK_DIV*M*N*S{1'b0}};
		  ramp_in_Nbit <= {FRAMECLK_DIV*M*N*S{1'b0}};
	  end 
	  else begin
		  alternate_in_Nbit <= {FRAMECLK_DIV*M*N*S{1'b0}};
		  ramp_in_Nbit <= {FRAMECLK_DIV*M*N*S{1'b0}};
		  prbs_in_Nbit <= {FRAMECLK_DIV*M*N*S{1'b0}};	
	  end
   end
end	


assign err_out = (csr_rx_testmode == 4'b1000)? alternate_error_N:
					  (csr_rx_testmode == 4'b1001)? ramp_error_N:
					  (csr_rx_testmode == 4'b1010)? prbs_error_N: 					
															 'h0;
															
always @(posedge clk or negedge rst_n) begin
	if (~rst_n) begin
	  ready <= 1'b0;
	  end else begin	
		ready <= 1'b1;
	  end
   end	
   
//testmode
assign enable_alternate_mode = (csr_rx_testmode == 4'b1000)? 1'b1:1'b0;
assign enable_ramp_mode = (csr_rx_testmode == 4'b1001)? 1'b1:1'b0;
assign enable_prbs_mode = (csr_rx_testmode == 4'b1010)? 1'b1:1'b0;

always @(posedge clk or negedge rst_n)
begin
   if (~rst_n) begin
       prbs_chkN_ena <= 1'b0; 
	   alternate_chkN_ena <= 1'b0; 
	   ramp_chkN_ena <= 1'b0; 
   end else if (enable_alternate_mode & valid) begin
	   prbs_chkN_ena <= 1'b0; 
	   alternate_chkN_ena <= 1'b1; 
	   ramp_chkN_ena <= 1'b0;  
  end else if (enable_ramp_mode & valid) begin
	   prbs_chkN_ena <= 1'b0; 
	   alternate_chkN_ena <= 1'b0; 
	   ramp_chkN_ena <= 1'b1;  
   end else if (enable_prbs_mode & valid) begin
	   prbs_chkN_ena <= 1'b1; 
	   alternate_chkN_ena <= 1'b0; 
	   ramp_chkN_ena <= 1'b0; 
   end else begin
	   prbs_chkN_ena <= 1'b0; 
	   alternate_chkN_ena <= 1'b0; 
	   ramp_chkN_ena <= 1'b0; 
   end
 end
 
//prbs pattern checker with data width varied by parameter N 
 prbs_checker #(
	  .POLYNOMIAL_LENGTH(POLYNOMIAL_LENGTH),
	  .FEEDBACK_TAP(FEEDBACK_TAP),
	  .DATA_WIDTH(N),
	  .S(S),
	  .M(M),
	  .FRAMECLK_DIV(FRAMECLK_DIV),
	  .ERR_THRESHOLD(ERR_THRESHOLD)
	  ) prbs_chkN_inst (
	  .rst_n (rst_n),	
	  .clk (clk),
	  .initial_seed(7'h7F),
	  .enable(prbs_chkN_ena),
	  .csr_s(csr_s),
	  .csr_m(csr_m),							  
	  .datain(prbs_in_Nbit),
	  .prbs_err_out(prbs_error_N)
	  );

//alternate pattern checker with data width varied by parameter N 								  
 alternate_checker #(
	  .DATA_WIDTH(N),
	  .S(S),
	  .M(M),
	  .FRAMECLK_DIV(FRAMECLK_DIV),
	  .ERR_THRESHOLD(ERR_THRESHOLD)
	  ) alternate_chkN_inst (
	  .rst_n (rst_n),
	  .clk (clk),
	  .enable(alternate_chkN_ena),
	  .csr_s(csr_s),
	  .csr_m(csr_m),
	  .datain(alternate_in_Nbit),
	  .alternate_err_out(alternate_error_N)
	  );

//ramp pattern checker with data width varied by parameter N								
 ramp_checker #(
  .DATA_WIDTH(N),
  .S(S),
  .M(M),
  .FRAMECLK_DIV(FRAMECLK_DIV),
  .ERR_THRESHOLD(ERR_THRESHOLD)
	) ramp_chkN_inst (   
	 .clk(clk),
	 .rst_n(rst_n),
	 .datain(ramp_in_Nbit),
	 .enable(ramp_chkN_ena),
	 .csr_s(csr_s),
	 .csr_m(csr_m),
	 .ramp_err_out(ramp_error_N)
	 );
			
endmodule 