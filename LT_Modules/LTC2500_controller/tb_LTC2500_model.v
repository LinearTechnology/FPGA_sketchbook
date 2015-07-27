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
        The purpose of this module is to  test the LTC2500 model.
*/

module tb_LTC2500_model();

    reg             mclk;
    reg             reset_n;
    wire    [31:0]  nyquist_data;
    wire    [31:0]  filtered_data;
    reg             rdla;
    reg             scka;
    wire            sdoa;
    reg             rdlb;
    reg             sckb;
    wire            sdob;
    wire            drdy_n;
    wire            busy;
    wire    [9:0]   config_word;
    reg             en_shift;
    reg     [3:0]   sdi_count;
    wire            sdi;

    `define TEST_PORTA    1
    `define TEST_PORTB    1
    `define TEST_SDI      1

    parameter CLK_HALF_PERIOD       = 500;     // 1Mhz
    parameter RST_DEASSERT_DELAY    = 1000;
    parameter RDLA_DEASSERT_DELAY   = 2000;
    parameter RDLB_DEASSERT_DELAY   = 2000;
    parameter SCKA_HALF_PERIOD      = 5;   // 100Mhz
    parameter SCKB_HALF_PERIOD      = 5;   // 100Mhz
    parameter END_SIM_DELAY         = 1000000;
    parameter SDI_DATA_DELAY        = 2000;

    assign nyquist_data = 32'h12345678;
    assign filtered_data = 32'h12345678;
    assign config_word = 10'b1000001000;
        // Generate the master clock
    initial
        begin
            mclk = 1'b0;
        end
    always 
        begin
            #CLK_HALF_PERIOD mclk = ~mclk;
        end

    // Generate the reset_n
    initial
        begin
            reset_n                     = 1'b0;
            #RST_DEASSERT_DELAY reset_n = 1'b1;
        end

    // Generate the rdla
    initial
        begin
            rdla                          = 1'b1;
            `ifdef TEST_PORTA
                #RDLA_DEASSERT_DELAY rdla = 1'b0;
            `endif
        end

    // Stop the sim
    initial
        begin
            #END_SIM_DELAY;
            $stop;
            $finish; // close the simulation
        end

    // Generate the SPI port A clock
    initial
        begin
            scka = 1'b0;
        end
    always 
        begin
            #SCKA_HALF_PERIOD scka = ~scka;
        end
        
    // Generate the rdlb
    initial
        begin
            rdlb                     = 1'b1;
            `ifdef TEST_PORTB
                #RDLB_DEASSERT_DELAY rdlb = 1'b0;
            `endif
        end

    // Generate the SPI port B clock
    initial
        begin
            sckb = 1'b0;
        end
    always
        begin
            #SCKB_HALF_PERIOD sckb = ~sckb;
        end
    
    // Generate the en_shift signal
    initial
        begin
            en_shift = 1'b0;
            `ifdef TEST_SDI
                #SDI_DATA_DELAY en_shift = 1'b1;
            `endif
        end
    
    always @ (posedge scka or negedge reset_n)
        begin
            if(!reset_n || rdla || drdy_n)
                sdi_count <= 4'b0;
            else if (en_shift && !busy && sdi_count < 4'd8)
                sdi_count <= sdi_count + 4'b1;
        end

    assign sdi = (!reset_n) ? 1'b0 : config_word[9 - sdi_count];

    // DUT
    LTC2500_model dut
    (
        // Simulation interface
        .reset_n        (reset_n),          // Used to reset the model
        .nyquist_data   (nyquist_data),     // Input for Nyquist data
        .filtered_data  (filtered_data),    // Input for filtered data

        // ADC Interface
        // A SPI port
        .rdla           (rdla),             // Read low input A. 
        .scka           (scka&!busy),       // Serial clock input A
        .sdoa           (sdoa),             // Serial data output A

        // B SPI port
        .rdlb           (rdlb),             // Read low input B
        .sckb           (sckb&!busy),       // Serial clock input B
        .sdob           (sdob),             // Serial data input B

        .pre            (1'b0),             // Preset input
        .mclk           (mclk),             // Master clock input
        .sync           (1'b0),             // Synchronization input
        .drdy_n         (drdy_n),           // Data ready output
        .sdi            (sdi),              // Serial data in
        .busy           (busy)              // Busy indicator
    );
endmodule