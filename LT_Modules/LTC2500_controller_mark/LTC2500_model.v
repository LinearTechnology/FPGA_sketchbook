`timescale 1ns/1ns

// This module simulates the LTC2500 32 bit, 1 MSPS ADC
// First cut - simulating 32 bit filtered data transfer only.

module LTC2500_model (
	input [31:0] analog_data_in,
	input convert, //initiates a conversion with a rising edge 
	input ser_clk, //clock for serial data
	output reg busy, //goes high when still converting
	output ser_data_out //serial data line
	);

	initial begin
		busy = 1'b0;
	end

    reg load; //signal to handle capturing data
    reg en; //signal to simulate invalid data until 
	always @ (posedge convert) begin
        load = 1'b1;
        en = 1'b0;
		#13 busy = 1'b1;
		#500 busy = 1'b0; //min: 615ns   max: 675ns
        load = 1'b0;
        #5 en = 1'b1;
	end

	parallel2ser ser_interface (.clk(ser_clk), .load(load), .en(en), .data_in(analog_data_in),
		.ser(ser_data_out));

endmodule