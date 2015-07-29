`timescale 1ns/1ns

//Testbench for the pulse_gen module

module pulse_gen_tb();

    parameter OUTPUT_WIDTH = 16;    

    reg clk, reset, trig;
    reg [31:0] low_period, high_period;
    reg [OUTPUT_WIDTH-1:0] value;
    wire [OUTPUT_WIDTH-1:0] out;

    //generate reset and clock
    initial begin
        clk = 1'b1;
        reset = 1'b1;
        #10 clk = 1'b0;
        #10 clk = 1'b1;
        reset = 1'b0;
        forever begin
            #10 clk = ~clk;
        end
    end

    //stimuli
    initial begin
        #100;
        low_period = 300;
        high_period = 500;
        value = 3865;
        trig = 1'b1;
        #20 trig = 1'b0;
        @ (negedge out);
        #1000;
        $stop;
    end

    pulse_gen #(.OUTPUT_WIDTH(OUTPUT_WIDTH)) dut (
        .clk(clk),
        .reset(reset),
        .trig(trig),
        .low_period(low_period),
        .high_period(high_period),
        .value(value),
        .out(out)
    );

endmodule