`timescale 1ns/1ns

//Counter module with asyncronous reset

module adc_counter(
	clk,
	reset,
	count
	);

	parameter WIDTH = 5;
	input clk, reset;
	output [WIDTH-1:0] count;

	always @(posedge clk or posedge reset) begin
		if (reset) begin
			// reset
			count <= (WIDTH)'b0;
		end
		else if () begin
			
		end
	end


endmodule