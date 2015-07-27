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
        This module interfaces with 3 ADC controllers. It obtains parallel data and 
        formats it to 32 bits wide to store into memory. It accepts back pressure. 
*/

module data_formatter
( 
    clk,
    reset_n,
    done, 
    word_9_data,
    word_9_valid,
    data_in,
    valid,
    ready,
    data_out
);

    // Signal definitions
    input           clk;
    input           reset_n;
    input           done;
    input   [31:0]  word_9_data;
    input           word_9_valid;
    input   [287:0] data_in;
    output          valid;
    output  [31:0]  data_out;
    input           ready;
 
    // Internal signals
    reg     [319:0] internal_buffer;
    reg     [17:0]  state;
 
    // One Hot FSM states
    localparam WAIT_STATE           = 18'b000000000000000001;
    localparam ARRANGE_DATA_STATE   = 18'b000000000000000010;
    localparam WORD_0               = 18'b000000000000000100;
    localparam WORD_1               = 18'b000000000000001000;
    localparam WORD_2               = 18'b000000000000010000;
    localparam WORD_3               = 18'b000000000000100000;
    localparam WORD_4               = 18'b000000000001000000;
    localparam WORD_5               = 18'b000000000010000000;
    localparam WORD_6               = 18'b000000000100000000;
    localparam WORD_7               = 18'b000000001000000000;
    localparam WORD_8               = 18'b000000010000000000;
    localparam WORD_9               = 18'b000000100000000000;
    localparam WORD_10              = 18'b000001000000000000;
    localparam WORD_11              = 18'b000010000000000000;
    localparam WORD_12              = 18'b000100000000000000;
    localparam WORD_13              = 18'b001000000000000000;
    localparam WORD_14              = 18'b010000000000000000;
    localparam WORD_15              = 18'b100000000000000000;
 
    // Main FSM
    always @(posedge clk)
        begin
            if(!reset_n)
                state <= WAIT_STATE;
            else
                begin
                    case(state)
                        // Wait state
                        WAIT_STATE:
                            if(done)
                                state <= ARRANGE_DATA_STATE;
                        // Arrange data
                        ARRANGE_DATA_STATE:
                            state <= WORD_0;
                        WORD_0:
                            // Ch0 and CH1
                            if(ready)
                                state <= WORD_1;
                        WORD_1:
                            // Ch2 and CH3
                            if(ready)
                                state <= WORD_2;
                        WORD_2:
                            // Ch4 and CH5
                            if(ready)
                                state <= WORD_3;
                        WORD_3:
                            // Ch6 and CH7
                            if(ready)
                                state <= WORD_4;
                        WORD_4:
                            // Ch8 and CH9
                            if(ready)
                                state <= WORD_5;
                        WORD_5:
                            // Ch10 and CH11
                            if(ready)
                                state <= WORD_6;
                        WORD_6:
                            // Ch12 and CH13
                            if(ready)
                                state <= WORD_7;
                        WORD_7:
                            // Ch14 and CH15
                            if(ready)
                                state <= WORD_8;
                        WORD_8:
                            // CH16 and CH17
                            if(ready)
                                state <= WORD_9;
                        WORD_9:
                            // Digital data
                            if(ready)
                                state <= WORD_10;
                        WORD_10:
                            // Reserved for future use. Send nothing
                            if(ready)
                                state <= WORD_11;
                        WORD_11:
                            // Reserved for future use. Send nothing
                            if(ready)
                                state <= WORD_12;
                        WORD_12:
                            // Reserved for future use. Send nothing
                            if(ready)
                                state <= WORD_13;
                        WORD_13:
                            // Reserved for future use. Send nothing
                            if(ready)
                                state <= WORD_14;
                        WORD_14:
                            // Reserved for future use. Send nothing
                            if(ready)
                                state <= WORD_15;
                        WORD_15:
                            // Reserved for future use. Send nothing
                            if(ready)
                                state <= WAIT_STATE;
                        default:
                            state <= WAIT_STATE;
                    endcase
                end
        end

    integer data_index;
    integer channel_index;
    // Arrange the data
    always @ (posedge clk)
        begin
            if(state == ARRANGE_DATA_STATE)
                begin
                    for(channel_index = 0; channel_index <= 35; channel_index = channel_index + 1)
                        begin
                            for(data_index = 0; data_index <= 7; data_index = data_index +1)
                                internal_buffer[(channel_index*8)+data_index] <= data_in[280 - (channel_index*8)  + data_index];
                        end
                    if(word_9_valid)
                        // Insert digital data into output buffer 
                        internal_buffer[319:288] <= word_9_data;
                    else
                        internal_buffer[319:288] <= 32'd0;    
                end
        end
 
    assign data_out = (!reset_n)    ? 32'b0                     :
                (state == WORD_0)   ? internal_buffer[31:0]     :
                (state == WORD_1)   ? internal_buffer[63:32]    :
                (state == WORD_2)   ? internal_buffer[95:64]    :
                (state == WORD_3)   ? internal_buffer[127:96]   :
                (state == WORD_4)   ? internal_buffer[159:128]  :
                (state == WORD_5)   ? internal_buffer[191:160]  :
                (state == WORD_6)   ? internal_buffer[223:192]  :
                (state == WORD_7)   ? internal_buffer[255:224]  :
                (state == WORD_8)   ? internal_buffer[287:256]  :
                (state == WORD_9)   ? internal_buffer[319:288]  :
                (state == WORD_10)  ? 32'h01020304              :
                (state == WORD_11)  ? 32'h05060708              :
                (state == WORD_12)  ? 32'h090A0B0C              :
                (state == WORD_13)  ? 32'h0D0E0F10              :
                (state == WORD_14)  ? 32'h11121314              :
                (state == WORD_15)  ? 32'hDEADBEEF              :
                                    32'b0;
       
    assign valid = ((!reset_n) || state == WAIT_STATE || state == ARRANGE_DATA_STATE) ? 1'b0 :1'b1; 
endmodule 