`timescale 1ns/1ns

//Testbench for adc_model

module adc_model_tb();

    reg [19:0] analog_data_in;
    reg convert, ser_clk;
    wire busy;
    wire ser_data_out;

    adc_model uut (
        .analog_data_in(analog_data_in),
        .convert(convert), //initiates a conversion with a rising edge 
        .ser_clk(ser_clk), //clock for serial data
        .busy(busy), //goes high when still converting
        .ser_data_out(ser_data_out) //serial data line
    );

    //generate dummy analog data
    initial begin
        analog_data_in = 20'b0;
        #100;
        forever begin
            #5 analog_data_in = analog_data_in + 20'b1;
        end
    end

    //handle interface with adc
    initial begin
        repeat(5) begin
            convert = 1'b0;
            ser_clk = 1'b0;

            #100;
            convert = 1'b1;
            #30;
            convert = 1'b0;

            @ (negedge busy);
            repeat(20) begin
                #5 ser_clk = 1'b1;
                #5 ser_clk = 1'b0;
            end
            #10;
        end
        $stop;
    end

endmodule