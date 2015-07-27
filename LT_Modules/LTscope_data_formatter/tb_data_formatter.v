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
        This module test the data formatter.
*/

module tb_data_formatter();
    reg             clk;
    reg             reset_n;
    reg             done;
    wire    [31:0]  word_9_data;
    wire    [287:0] data_in;
    wire            valid;
    wire    [31:0]  data_out;

    parameter CLK_HALF_PERIOD       = 5;    // 100Mhz
    parameter RST_DEASSERT_DELAY    = 100;
    parameter DONE_DELAY_IN_CLK_CYCLES = 100;
    parameter END_SIM_DELAY         = 10000;

    assign word_9_data = 32'hADC00009;
    assign data_in = 288'h00000101020203030404050506060707080809090A0A0B0B0C0C0D0D0E0E0F0F11111212;

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
    
    // Generate done signal
    initial
        begin
            done = 1'b0;
        end

    always
        begin
            repeat(DONE_DELAY_IN_CLK_CYCLES *2)
                #CLK_HALF_PERIOD;
            done = 1'b1;
            repeat(2)
                #CLK_HALF_PERIOD;
            done = 1'b0;
        end

    initial
        begin
            #END_SIM_DELAY;
            $stop;
            $finish; // close the simulation
        end
    data_formatter dut
    ( 
        .clk(clk),
        .reset_n(reset_n),
        .done(done), 
        .word_9_data(word_9_data),
        .word_9_valid(1'b1),
        .data_in(data_in),
        .valid(valid),
        .ready(1'b1),
        .data_out(data_out)
    );
endmodule
