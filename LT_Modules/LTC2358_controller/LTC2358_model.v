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
        The purpose of this module is to model the digital interface for the LTC2358.
*/

module LTC2358_model
(
    // Simulation Interface
    reset_n,            // Used to reset the model
    data,               // Input for the ADC data

    // ADC Interface
    cs_n,               // Chip select active low
    cnv,                // Convert start
    busy,               // Busy output
    sdi,                // Serial data input
    scki,               // Serial clock input
    sdo                 // Serial data output
);

    ///////////////////////////////////////////////////////////////////////////
    // Port declaration
    ///////////////////////////////////////////////////////////////////////////

    // Simulation Interface
    input               reset_n;
    input       [17:0]  data;

    // ADC Interface
    input               cs_n;
    input               cnv;
    output  reg         busy;
    input               sdi;
    input               scki;
    output  reg [7:0]   sdo;

    ///////////////////////////////////////////////////////////////////////////
    // Internal signals
    ///////////////////////////////////////////////////////////////////////////

    reg     [4:0]   data_count;
    reg     [23:0]  sdi_buf;
    reg     [23:0]  cfig_word_buf;
    reg             sample_bad;
    

    //*************************************************************************

    // Data count
    always @ (posedge scki or posedge busy or negedge reset_n)
        begin
            if(!reset_n)
                data_count = 5'b0;
            else if(busy)
                data_count = 5'b1;
            else if(data_count <= 5'd24)
                data_count = data_count + 1'b1;
        end

    //*************************************************************************

    // Input shift register
    always @ (posedge scki or negedge reset_n)
        begin
            if(!reset_n)
                sdi_buf <= 24'b0;
            else if(!cs_n && (data_count < 5'd23))
                sdi_buf <= {sdi_buf[22:0],sdi};
        end

    //*************************************************************************

    // Load SDI config data after a complete data transfer
    always @ (posedge scki or negedge reset_n)
        begin
            if (!reset_n)
                cfig_word_buf <= 24'b0;
            if(data_count > 5'd23)
                cfig_word_buf <= sdi_buf;
        end

    //*************************************************************************

    // Generate the busy signal
    always @ (posedge cnv or negedge reset_n)
        begin
            if(!reset_n)
                busy = 1'b0;
            else
                begin
                    #30 busy = 1'b1;
                    #4400 busy = 1'b0;
                end
        end

    //*************************************************************************

    // Mimics a corruption if data is tried to be read when the LTC2500
    // is busy
    always @ (posedge scki or negedge reset_n)
        begin
            if(scki && busy)
                sample_bad <= 1;
            else if(!reset_n)
                sample_bad <= 0;
        end

    //*************************************************************************
    wire [2:0] ch_id [0:7];
    genvar k;
    generate
        for(k = 0; k <= 7; k = k +1)
            begin: gen_ch_id
                assign ch_id[k] = k;
            end
    endgenerate
    
    genvar i;
    generate
        for(i = 0; i <= 7; i = i + 1)
            begin: gen_output_data
                always @ *
                    begin
                        if(!reset_n)
                            sdo[i] = 1'bz;
                        if(sample_bad)
                            sdo[i] = 1'bx;
                        else if((!reset_n) || (data_count== 5'b0))
                            #8 sdo[i] = 1'bz;
                        else if(data_count <= 18)
                            #8 sdo[i] = data[18-data_count];
                        else if (data_count <= 21)
                            #8 sdo[i] = ch_id[i][21-data_count];
                        else if(data_count <= 24)
                            #8 sdo[i] = sdi_buf[(24-data_count) + (4*1)];
                        else
                            #8 sdo[i] = 1'b0;
                    end
            end
    endgenerate
endmodule