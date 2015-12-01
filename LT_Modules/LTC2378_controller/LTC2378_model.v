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
        The purpose of this module is to model the LTC2378 digital interface.
*/

module LTC2378_model
(
    // System signals
    reset_n,
    data,

    rdl,
    sck,
    sdo,
    cnv,
    busy
);

    ///////////////////////////////////////////////////////////////////////////
    // Port declaration
    ///////////////////////////////////////////////////////////////////////////

    input           reset_n;
    input   [19:0]  data;
    input           rdl;
    input           sck;
    output reg      sdo;
    input           cnv;
    output reg      busy;

    ///////////////////////////////////////////////////////////////////////////
    // Internal signals
    ///////////////////////////////////////////////////////////////////////////

    reg     [19:0]  buff;
    reg     [4:0]   count;
    reg             sample_bad;
    
    //*************************************************************************
    
    // Generate the busy signal
    always @ (posedge cnv or negedge reset_n)
        begin
            if(!reset_n)
                busy = 1'b0;
            else
                begin
                    #13 busy = 1'b1;
                    #675 busy = 1'b0;
                end
        end

    //*************************************************************************

    // Capture data to internal buffer
    always @ (posedge cnv or negedge reset_n)
        begin
            if(!reset_n)
                buff <= 20'b0;
            else
                buff <= data;
        end

    //*************************************************************************

    // Counter for keeping track of data out
    always @ (posedge sck or busy or negedge reset_n)
        begin
            if(!reset_n)
                count = 5'b0;
            else if (rdl || busy)
                count = 5'b0;
            else if(count <= 5'd21)
                count = count + 1'b1;
        end

    //*************************************************************************

    // Mimics a corruption if data is tried to be read when the LTC2378
    // is busy
    always @ (posedge sck or negedge reset_n or posedge cnv)
        begin
            if(sck && busy)
                sample_bad <= 1;
            else if(!reset_n || cnv)
                sample_bad <= 0;
        end

    //*************************************************************************

    // Generate the sdob
    always @ *
        begin
            if(sample_bad)
                #8 sdo = 1'bx;
            else if((!reset_n) || (count== 5'd0))
                #8 sdo = 1'b0;
            else if (count == 5'd1)
                #5 sdo = buff[19];
            else if(count < 5'd21)
                #8 sdo = buff[20 - count];
            else
                #8 sdo = 1'b0;
        end
endmodule