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
        The purpose of this module is to generate the go signal based on the sample rate
*/

module sample_rate_controller
(
    clk,
    reset_n,
    en,
    sample_rate,
    go
);

    input           clk;
    input           reset_n;
    input           en;
    input   [15:0]  sample_rate;
    output          go;

    reg     [15:0]  count;
    reg     [1:0]   state;
    
    // One Hot FSM
    localparam WAIT_STATE       = 2'b01;
    localparam ENABLE_SAMPLE    = 2'b10;

    always @ (posedge clk)
        begin
            if(!reset_n)
                state <= WAIT_STATE;
            else
                begin
                    case(state)
                        WAIT_STATE:
                            if(en)
                                state <= ENABLE_SAMPLE;
                        ENABLE_SAMPLE:
                            if(!en)
                                state <= WAIT_STATE;
                    endcase
                end
        end

    // Down counter
    always @ (posedge clk)
        begin
            if(!reset_n || state == WAIT_STATE)
                count <= 16'b0;
            else if((state == ENABLE_SAMPLE) && go)
                count <= sample_rate;
            else if(state == ENABLE_SAMPLE && !go)
                count <= count - 1'b1;
        end

    // Go is one clock cycle wide
    assign go = (count == 16'b0) & (state == ENABLE_SAMPLE);

 endmodule
    