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
        The purpose of this module is to model the LTC2351 digital interface
*/

module LTC2351_model
(
    sck,
    reset_n,
    conv, 
    sel, 
    sdo,
    data_in
);
    
    input               sck;
    input               conv;
    input       [2:0]   sel;
    input               reset_n; 
    output reg          sdo;
    input       [95:0]  data_in;   

    // Signal declaration
    reg         [95:0]  buffer;
    reg         [6:0]   counter;
    wire        [6:0]   reset_count;
    reg                 conv_flag;
    reg                 conv_delayed;
    wire                conv_rise_edge;
    wire                count_reset;

    // Keep track of conversion signal
    always @ (posedge sck)
        begin
            if(!reset_n || count_reset)
                conv_flag <= 1'b0;
            else if(conv_rise_edge)
                conv_flag <= 1'b1;
        end

    // Loads buffer with new data at conversion
    always @ (posedge sck)
        begin
            if(!reset_n)
                buffer <= 96'bz;
            else if(conv_rise_edge)
                begin
                    buffer <= data_in;
                    $display("buffer: %h",buffer);
                end
        end

    // Edge detector for conv
    always @ (posedge sck)
        begin
            if(!reset_n)
                conv_delayed <= 1'b0;
            else
                conv_delayed <= conv;
        end
    assign conv_rise_edge = conv & !conv_delayed;

    // Used to select the channel data out
    assign reset_count = (sel == 3'd0) ? 7'd15 :
                         (sel == 3'd1) ? 7'd31 :
                         (sel == 3'd2) ? 7'd47 :
                         (sel == 3'd3) ? 7'd63 :
                         (sel == 3'd4) ? 7'd79 :
                                         7'd95 ;

    // Data out counter
    always @ (posedge sck)
        begin
            if(!reset_n || conv_rise_edge || count_reset)
                counter <= 7'd0;
            else if(conv_flag)
                counter <= counter + 7'd1;
        end

    // Counter reset signal
    assign count_reset = (counter == reset_count) ? 1'b1 : 1'b0;

    // Set SDO with appropiate value
    always @(posedge sck) 
        begin
            sdo <= #8 buffer[96'd95-counter];
        end

endmodule
