`timescale 1ns / 10ps   // Each unit time is 1ns and the time precision is 10ps

/*
    Created by: Noe Quintero
    E-mail: nquintero@linear.com

    Copyright (c) 2015, Linear Technology Corp.(LTC)
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    1. Redistributions of source code must retain the above copyright notice, this
       list of conditions and the following disclaimer.
    2. Redistributions in binary form must reproduce the above copyright notice,
       this list of conditions and the following disclaimer in the documentation
       and/or other materials provided with the distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
    ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
    ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
    (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
    ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
    SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

    The views and conclusions contained in the software and documentation are those
    of the authors and should not be interpreted as representing official policies,
    either expressed or implied, of Linear Technology Corp.
    
    Description:
        The purpose of this testbench is to verify the design and demonstrate the 
        interface for the ADC controller block. Modify the values in the parameters 
        to test different conditions. 
*/

module tb_LTC2351_controller();
    
    reg         clk;
    reg         reset_n;
    wire        go;
    wire [15:0] sample_rate;
    wire        sdo;
    wire [95:0] data_out;
    wire        valid;
    wire        conv;
    wire [95:0] data_in;
    reg         en;

    parameter CLK_HALF_PERIOD       = 20;   // 25Mhz
    parameter RST_DEASSERT_DELAY    = 100;
    parameter EN_DELAY              = 110;
    parameter END_SIM_DELAY         = 10000;
    assign sample_rate = 16'd100; // 250 ksps

    // Uncomment to run the LTC2351 model with a DFF on the 
    // conv signal.
    //`define TEST_WITH_FF = 1

    // Generate the clock
    initial
        begin
            clk = 1'b0;
        end
    always 
        begin
            #CLK_HALF_PERIOD clk = ~clk;
        end

    // Generate the reset_n 
    initial
        begin
            reset_n                     = 1'b0;
            #RST_DEASSERT_DELAY reset_n = 1'b1;
        end

    // Generate the go
    initial
        begin
            en = 1'b0;
            #EN_DELAY en = 1'b1;
        end

    // Stop the sim
    initial
        begin
            #END_SIM_DELAY;
            $stop;
            $finish; // close the simulation
        end

    // Sample_rate_controller
    sample_rate_controller src1
    (
        .clk(clk),
        .reset_n(reset_n),
        .en(en),
        .sample_rate(sample_rate),
        .go(go)
    );

    // Set the ADC input data 
    assign data_in = {2'bzz, 14'h3111, 2'bzz, 14'h3222, 2'bzz, 14'h3333, 2'bzz, 14'h3444, 2'bzz, 14'h3555, 2'bzz, 14'h3666};
    
    `ifndef TEST_WITH_FF
        // Device under test
        LTC2351_controller dut
        (
            .clk(clk),
            .reset_n(reset_n),
            .go(go),
            .data_in(sdo),
            .conv(conv),
            .valid(valid),
            .data_out(data_out)
        );

        // The LTC2351 digital model
        LTC2351_model m1
        (
            .sck(clk),
            .reset_n(reset_n),
            .conv(conv), 
            .sel(3'd5), 
            .sdo(sdo),
            .data_in(data_in)
        );
    `else
        // Device under test
        LTC2351_controller 
        #( .RETIMEING_FF(1) )
        dut
        (
            .clk(clk),
            .reset_n(reset_n),
            .go(go),
            .data_in(sdo),
            .conv(conv),
            .valid(valid),
            .data_out(data_out)
        );

        reg conv_d1;
        // The LTC2351 digital model
        LTC2351_model m1
        (
            .sck(clk),
            .reset_n(reset_n),
            .conv(conv_d1), 
            .sel(3'd5), 
            .sdo(sdo),
            .data_in(data_in)
        );
        always @(posedge clk)
            begin
                conv_d1 <= conv;
            end
    `endif
endmodule
