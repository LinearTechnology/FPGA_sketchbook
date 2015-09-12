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
        The purpose of this module is to model the digital interface for the LTC2500.
*/

module LTC2500_model 
(
    // Simulation interface
    reset_n,            // Used to reset the model
    nyquist_data,       // Input for Nyquist data
    filtered_data,      // Input for filtered data
    n,

    // ADC Interface
    // A SPI port
    rdla,               // Read low input A. 
    scka,               // Serial clock input A
    sdoa,               // Serial data output A

    // B SPI port
    rdlb,               // Read low input B
    sckb,               // Serial clock input B
    sdob,               // Serial data input B

    pre,                // Preset input
    mclk,               // Master clock input
    sync,               // Synchronization input
    drdy_n,             // Data ready output
    sdi,                // Serial data in
    busy                // Busy indicator
);

    // Port declaration
    input           reset_n;
    input   [31:0]  nyquist_data;
    input   [31:0]  filtered_data;
    input   [13:0]  n;
    input           rdla;
    input           scka;
    output  reg     sdoa;
    input           rdlb;
    input           sckb;
    output  reg     sdob;
    input           pre;
    input           mclk;
    input           sync;
    output  reg     drdy_n;
    input           sdi;
    output  reg     busy;

    // Internal signals
    wire    [3:0]   df_buf;
    wire    [3:0]   ft_buf;
    reg     [14:0]  dsf;
    reg     [11:0]  sdi_buf;
    reg     [9:0]   cfig_word_buf;
    reg     [5:0]   count_flt;
    reg     [14:0]  count_dsf;
    reg     [31:0]  nyq_buff;
    reg             sample_bad;
    reg     [5:0]   count_nyq;


    // Port A logic

    assign df_buf = cfig_word_buf[7:4];
    assign ft_buf = cfig_word_buf[3:0];

    
    // SDOA count
    always @ (posedge scka or negedge reset_n or rdla)
        begin
            if(!reset_n || rdla)
                count_flt <= 6'b0;
            else if(!rdla && busy)
                count_flt <= 6'b1;
            else if((!busy && count_flt == 6'b0) || !busy & scka)
                count_flt <= count_flt + 1'b1;
        end

    // Input shift register
    always @ (posedge scka or negedge reset_n)
        begin
            if(!reset_n)
                sdi_buf <= 12'b0;
            else if(!rdla && count_flt <= 4'd12)
                sdi_buf <= {sdi_buf[10:0],sdi};
        end

    // Load SDI config data if valid
    always @ (posedge scka or negedge reset_n)
        begin
            if (!reset_n)
                cfig_word_buf <= 10'b0001100001;
            if((count_flt > 12) && !rdla && (sdi_buf[11:10] == 2'b10))
                cfig_word_buf <= sdi_buf[9:0];
        end

    // Determine the DSF by the ADC mode
    always @ *
        begin
            if (!reset_n)
                dsf = 63;
            else
                begin
                    if (pre)
                        begin
                            if (sdi)
                                dsf = 63;
                            else
                                dsf = 0;
                        end
                    else if (df_buf == 4'b0000 || df_buf == 4'b0001 || df_buf == 4'b1111)
                        dsf = dsf;
                    else if (df_buf == 4'b0111)
                        dsf = 0;
                    else
                        dsf = 2**df_buf - 1;
                end
        end

    // Counter used to keep track of conversions to mimic the downsample factor
    always @ (posedge mclk or negedge reset_n or posedge sync)
        begin
            if((!reset_n) || count_dsf >= dsf || sync )
                count_dsf <= 15'b0;
            else if (count_dsf < dsf)
                count_dsf <= count_dsf + 1'b1;
        end

    // Generate the drdy_n signal
    always @ (busy or negedge reset_n)
        begin
            if(!reset_n)
                drdy_n = 1'b0;
            else if(count_dsf == 15'd0)
                drdy_n = busy;
        end

    // Generate the sdoa signal
    always @ *
        begin
            if(rdla)
                begin
                    #8 sdoa <= 1'bz;
                end
            else 
                begin
                    if (count_flt <= 32)
                        begin
                            #8 sdoa <= filtered_data[32 - count_flt];
                        end
                    else if (count_flt <= 40)
                        begin
                            #8 sdoa <= cfig_word_buf[40 - count_flt];
                        end
                    else if (count_flt <= 54)
                        begin
                            #8 sdoa <= n[54-count_flt];
                        end
                    // else if (count_flt == 55)
                        // begin
                            // #8 sdoa <= 1'b0;
                        // end
                end
        end

    // Port B logic

    // Capture data to internal buffer
    always @ (posedge mclk or negedge reset_n)
        begin
            if(!reset_n)
                nyq_buff <= 32'b0;
            else
                nyq_buff <= nyquist_data;
        end

    // Counter for keeping track of Nyquist data out
    always @ (posedge sckb or negedge reset_n or rdlb)
        begin
            if((!reset_n) || rdlb)
                count_nyq = 6'b0;
            else
                count_nyq = count_nyq + 1'b1;
        end

    // Generate the busy signal
    always @ (posedge mclk or negedge reset_n)
        begin
            if(!reset_n)
                busy = 1'b0;
            else
                begin
                    #13 busy = 1'b1;
                    #675 busy = 1'b0;
                end
        end

    // Mimics a corruption if data is tried to be read when the LTC2500
    // is busy
    always @ (posedge scka or posedge sckb or negedge reset_n or posedge mclk)
        begin
            if(sckb && busy)
                sample_bad <= 1;
            else if(!reset_n || mclk)
                sample_bad <= 0;
        end

    // Generate the sdob
    always @ *
        begin
            if(sample_bad)
                #8 sdob = 1'bx;
            else if((!reset_n) || (count_nyq == 6'd0))
                #8 sdob = 1'bz;
            else if(count_nyq < 6'd33)
                #8 sdob = nyq_buff [32 - count_nyq];
            else
                #8 sdob = 1'b0;
        end
endmodule
