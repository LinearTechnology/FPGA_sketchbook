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
        The purpose of this module is to delay the trigger signal.
*/

module trigger_block
(
    clk,
    reset_n,

    data_valid,
    trig_in,
    force_trig,
 
    pre_trig_counter,
    pre_trig_counter_value,
    post_trig_counter,
 
    en_trig,
    delayed_trig
);

    input               clk;                    // Clock
    input               reset_n;                // Reset active low
    input               data_valid;             // Signal from upstream controller.
    input               trig_in;                // Input trigger
    input               force_trig;             // Force trigger
    input       [31:0]  pre_trig_counter;       // Minimum number of samples to capture prior to trigger
    output reg  [31:0]  pre_trig_counter_value; // The pre-triggered counter value at triggered event
    input       [31:0]  post_trig_counter;      // The number of samples to capture after trigger
    input               en_trig;                // Drive high to operate
    output              delayed_trig;           // The delayed trigger signal based on the pre and post counters
                                                // AND with downstream data valid signal
    // Signal declaration
    reg             trig_go;
    reg     [1:0]   state;
    reg     [31:0]  pre_trig_count;
    reg     [31:0]  post_trig_count;
    wire            en_pre_trig_count;
    wire            en_post_trig_count;
    wire            pre_trig_done_flag;
    reg             trig_delay;
    wire            trig_rise_edge;
    wire            trig;

    assign trig = trig_in | force_trig;

    // One Hot FSM
    localparam WAIT_STATE = 2'b01;
    localparam TRIGGER_STATE = 2'b10;

    always @(posedge clk)
        begin
            if(!reset_n)
                state <= WAIT_STATE;
            else
                begin
                    case(state)
                        WAIT_STATE:
                            if(en_trig)
                                state <= TRIGGER_STATE;
                        TRIGGER_STATE:
                            if(!en_trig)
                                state <= WAIT_STATE;
                        default:
                            state <= WAIT_STATE;
                    endcase
                end
        end
    
    // Set the go signal 
    always @(posedge clk)
        begin
            if(!reset_n)
                trig_go <= 1'b0;
            else if((state == WAIT_STATE) && en_trig)
                trig_go <= 1'b1;
            else
                trig_go <= 1'b0;
        end
    
    // Controls the pre-trigger counter
    always @(posedge clk)
        begin
            if(!reset_n)
                pre_trig_count  <= 32'd0;
            else if(trig_go)
                pre_trig_count  <= pre_trig_counter;
            else if(en_pre_trig_count)
                    pre_trig_count  <= pre_trig_count - 1;
        end

    assign en_pre_trig_count    = (pre_trig_count != 32'd0) & data_valid;

    // Controls the post-trigger counter
    always @(posedge clk)
        begin
            if(!reset_n)
                post_trig_count  <= 32'd0;
            else if(trig_go)
                post_trig_count  <= post_trig_counter;
            else if(en_post_trig_count)
                    post_trig_count  <= post_trig_count - 1;
        end

    assign en_post_trig_count   = (post_trig_count != 32'd0) & data_valid
                                    & (pre_trig_count == 32'd0) & trig; 

    // Rise edge detctor for trig
    always @ (posedge clk)
        begin
            if(!reset_n)
                trig_delay <= 1'd0;
            else
                trig_delay <= trig;
        end
    assign trig_rise_edge   = trig & !trig_delay;
    
    // Used to show the pre_trig_count when a triggered is asserted
    always @(posedge clk)
        begin
            if(!reset_n)
                pre_trig_counter_value <= 32'd0;
            else if (trig_go && trig)
                   pre_trig_counter_value <= pre_trig_counter;
            else if(trig_rise_edge)
                pre_trig_counter_value <= pre_trig_count;
        end
    
    assign delayed_trig =~((post_trig_count == 32'd0)& (!trig_go) | (!reset_n) | (!en_trig));
endmodule