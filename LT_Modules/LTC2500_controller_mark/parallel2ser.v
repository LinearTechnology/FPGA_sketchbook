`timescale 1ns/1ns

//Converts parallel data to serial

module parallel2ser (
	clk,
	load,
    en,
	data_in,
	ser
	);
	
	parameter DATA_WIDTH = 32;
	input clk;
	input load;
    input en;
	input [DATA_WIDTH-1:0] data_in;

	output reg ser;

	reg [DATA_WIDTH-1:0] data_reg;

    wire ser_tmp = data_reg[DATA_WIDTH-1];
	always @ (posedge clk or posedge load) begin
		if (load) begin
			data_reg <= data_in;
		end	else begin
            #8; //wait for data to become valid
			data_reg = {data_reg[DATA_WIDTH-2:0], 1'b0};
		end
	end

    always @ (*) begin
        if (en) begin
            ser = ser_tmp;
        end else begin
            ser = 1'b0;
        end
    end

endmodule