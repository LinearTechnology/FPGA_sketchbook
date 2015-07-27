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
      The ADC controller module is intended to interface with 
      the LTC2351. The input serial data is pararallized for
      formatting.
*/

module LTC2351_controller
(
    clk,
    reset_n,
    go,
    data_in,
    conv,
    valid,
    data_out
);
    parameter RETIMEING_FF = 0;

    // Signal definitions
    input               clk;
    input               reset_n;
    input               go;
    input               data_in;
    output              conv;
    output reg          valid;
    output reg  [95:0]  data_out;

    // Internal Signals
    reg         [2:0]   state; 
    wire                enable_counter;
    wire                shift_right;
    wire                counter_reset;
    reg         [6:0]   data_count;

    // One Hot FSM
    localparam WAIT_STATE       = 3'b001;
    localparam CONV_STATE       = 3'b010;
    localparam READ_DATA_STATE  = 3'b100;

    always @(posedge clk)
        begin
            if(!reset_n)
                // Initializations
                state <= WAIT_STATE;
            else
                begin
                    case(state)
                        WAIT_STATE:
                            // Wait state
                            if(go == 1)
                                state <= CONV_STATE;
                        CONV_STATE:
                            // Conversion state
                                state <= READ_DATA_STATE;
                        READ_DATA_STATE: 
                            // Read data state 
                            if(data_count == 0)
                                state <= WAIT_STATE;
                        default:
                            state <= WAIT_STATE;
                    endcase
                end 
        end

    // Main shift register
    always @(posedge clk)
        begin
            if(!reset_n)
                data_out <= 96'b0;
            else if (shift_right)
                data_out <= {data_out[94:0], data_in};
        end
 
    // 7-bit data counter
    always @(posedge clk)
        begin
            if (counter_reset)
                data_count <= 7'd95 + RETIMEING_FF;
            else
                if(enable_counter)
                    data_count <= data_count - 7'b01;
        end

    assign conv = (state == CONV_STATE) ? 1'b1 : 1'b0;
    
    // Set valid signal 
    always @ (posedge clk)
        begin
            if((state == READ_DATA_STATE) && (data_count == 0))
                valid <= 1'b1;
            else
                valid <= 1'b0;
        end
    
    assign counter_reset = (state != READ_DATA_STATE) ? 1'b1: 1'b0;
    assign shift_right = ((data_count != 0) && (state == READ_DATA_STATE)) ? 1'b1: 1'b0;
    assign enable_counter = (state == READ_DATA_STATE) ? 1'b1: 1'b0;
endmodule
