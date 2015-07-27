`timescale 1ns / 1ps

module tb_ring_buff_addr();

	
	reg clk = 0;
	reg rstn = 0;
	reg en = 0;
	reg [28:0] depth = 16400;
	
	wire [28:0]addr;
	
	integer i;
	integer j;
	initial
	begin
		#1 clk = ~clk;
		#1 clk = ~clk;
		
		#1 clk = ~clk;
			rstn = 1;
		#1 clk = ~clk;
		
		#1 clk = ~clk;
			en = 1;
		
		for(j = 0; j<= 33; j = j+1)
			for(i = 0; i<= 4000; i = i + 1)
				#1 clk = ~clk;
		
	end
	
	ring_buffer_addr u1
	(
		.clk(clk),
		.rstn(rstn),
		
		.en(en),
		.depth(depth),
		.addr(addr)
	);
	
endmodule
