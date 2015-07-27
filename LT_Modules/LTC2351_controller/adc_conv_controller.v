`timescale 1ns / 1ps   // Each unit time is 1ns and the time precision is 10ps

/*
    Created by: Noe Quintero
    E-mail: nquintero@linear.com

    Copyright (c) 2013, Linear Technology Corp.(LTC)
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
        The purpose of this module is to control the conversion signal
        to the ADC for a specific sample rate. A sample rate from ~281 sps 
        to 250000 sps can be achieved with the module for a 25MHz clock.
    
*/

module adc_conv_controller
(
    clk,
    reset_n,
    go,
    sample_rate,
    adc_conv
);

    input clk;
    input reset_n;
    input go;
    input [15:0] sample_rate;
    output adc_conv;
    
    reg [15:0] count;
    
    always @(posedge clk)
    begin
        if(!reset_n)
            count <= 16'b0;
        else
        begin
            if(go)
            begin
                if(count >= sample_rate)
                    count <= 16'b0;
                else
                    count <= count + 1'b1;
            end
            else
            begin
                count <= 16'b0;
            end
        end
    end
    assign adc_conv = (count >= sample_rate) ? 1'b1 : 1'b0;
endmodule
