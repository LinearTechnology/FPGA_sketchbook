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
        The purpose of this module is to test the LTC2351 model
*/

module tb_LTC2351_model();

    reg         clk;
    reg         reset_n;
    reg         conv;
    wire        sdo;
    wire [95:0] data_in;
    
    assign data_in = {2'bzz, 14'h3111, 2'bzz, 14'h3222, 2'bzz, 14'h3333, 2'bzz, 14'h3444, 2'bzz, 14'h3555, 2'bzz, 14'h3666};

    parameter CLK_HALF_PERIOD       = 20;   // 25Mhz
    parameter RST_DEASSERT_DELAY    = 100;
    parameter CONV_ASSERTION_DELAY_IN_CLOCK_CYCLES  = 100;  //250Ksps
    parameter END_SIM_DELAY         = 10000;

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
    
    // Generate the conv
    initial
        begin
            conv = 1'b0;
        end

    always
        begin
            repeat(CONV_ASSERTION_DELAY_IN_CLOCK_CYCLES *2)
                #CLK_HALF_PERIOD;
            conv = 1'b1;
            repeat(2)
                #CLK_HALF_PERIOD;
            conv = 1'b0;
        end

    // Stop the sim
    initial
        begin
            #END_SIM_DELAY;
            $stop;
            $finish; // close the simulation
        end

    LTC2351_model dut
    (
        .sck(clk), 
        .reset_n(reset_n),
        .conv(conv), 
        .sel(3'd5), 
        .sdo(sdo),
        .data_in(data_in)
    );
endmodule


