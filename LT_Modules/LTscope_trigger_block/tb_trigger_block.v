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
        interface for the trigger block. Modify the values in the parameters to test 
        different conditions. 
*/

module tb_trigger_block();

    reg             clk;
    reg             reset_n;
    reg             data_valid;
    reg             trig_in;
    reg             force_trig;
    wire    [31:0]  pre_trig_counter;
    wire    [31:0]  post_trig_counter;
    wire    [31:0]  pre_trig_counter_value;
    reg             en_trig;
    wire            delayed_trig;
    
    // Uncomment to to implament the force trirgger signal
    //`define FORCE_TRIG_TEST = 1

    parameter CLK_HALF_PERIOD       = 5;    // 100Mhz
    parameter RST_DEASSERT_DELAY    = 100;
    parameter TRIG_ASSERT_DELAY     = 1000;
    parameter DATA_VALID_DELAY_IN_CLK_CYCLES = 5;
    parameter PRE_TRIG_COUNT        = 32'd5;
    parameter POST_TRIG_COUNT       = 32'd10;
    parameter GO_DELAY              = 110;
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
    
    // Generate data valid signal
    initial
        begin
            data_valid = 1'b0;
        end

    always
        begin
            repeat(DATA_VALID_DELAY_IN_CLK_CYCLES *2)
                #CLK_HALF_PERIOD;
            data_valid = 1'b1;
            repeat(2)
                #CLK_HALF_PERIOD;
            data_valid = 1'b0;
        end
    
    `ifdef FORCE_TRIG_TEST
        // Generate trigger signal
        initial 
            begin
                trig_in = 1'b0;
            end
        initial
            begin
                force_trig = 1'b0;
                #TRIG_ASSERT_DELAY force_trig = 1'b1;
            end
    `else 
        initial 
            begin
                trig_in = 1'b0;
                #TRIG_ASSERT_DELAY trig_in = 1'b1;
            end
        initial
            begin
                force_trig = 1'b0;
            end
    `endif
    
    // Generate en_trig signal
    initial
        begin
            en_trig = 1'b0;
            #GO_DELAY en_trig = 1'b1;
        end
    initial
        begin
            #END_SIM_DELAY;
            $stop;
            $finish; // close the simulation
        end

    // Display a warning message when
    initial 
        begin
            if(GO_DELAY<RST_DEASSERT_DELAY)
                begin
                    $display("***********************************************");
                    $display("*             Warning!!!                      *");
                    $display("*   Warning!!!          Warning!!!            *");
                    $display("*             Warning!!!                      *");
                    $display("*                                             *");
                    $display("*                                             *");
                    $display("* Go signal is asserted while in active reset *");
                    $display("*                                             *");
                    $display("***********************************************");
                    $stop;
                end
        end

    assign pre_trig_counter     = PRE_TRIG_COUNT;
    assign post_trig_counter    = POST_TRIG_COUNT;

    trigger_block dut
    (
        .clk                    (clk),
        .reset_n                (reset_n),
        .data_valid             (data_valid),
        .trig_in                (trig_in),
        .force_trig             (force_trig),
        .pre_trig_counter       (pre_trig_counter),
        .pre_trig_counter_value (pre_trig_counter_value),
        .post_trig_counter      (post_trig_counter),
        .en_trig                (en_trig),
        .delayed_trig           (delayed_trig)
    );

endmodule