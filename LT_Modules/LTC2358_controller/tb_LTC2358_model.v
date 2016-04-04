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
        The purpose of this module is to  test the LTC2378 model.
*/

module tb_LTC2358_model();

    ///////////////////////////////////////////////////////////////////////////
    // Test signals
    ///////////////////////////////////////////////////////////////////////////

    reg             reset_n;
    wire    [17:0]  data;
    wire            cs_n;
    reg             cnv;
    wire            busy;
    reg             sdi;
    reg             scki;
    wire    [7:0]   sdo;
    wire    [23:0]  cnfg_data;

    ///////////////////////////////////////////////////////////////////////////
    // Test bench parameters
    ///////////////////////////////////////////////////////////////////////////
    
    parameter RST_DEASSERT_DELAY        = 10;
    parameter SCKI_HALF_PERIOD          = 5;    // 100 MHz
    parameter CNV_PERIOD                = 4400;
    parameter END_SIM_DELAY             = 10000;

    //*************************************************************************

    assign data = 18'h12345;
    assign cs_n = 1'b0;
    assign cnfg_data = 24'h923456;

    //*************************************************************************

    // Generate the reset_n
    initial
        begin
            reset_n                     = 1'b0;
            #RST_DEASSERT_DELAY reset_n = 1'b1;
        end

    //*************************************************************************

    // Generate the serial data clock
    integer i;
    initial
        begin
            scki = 1'b0;
        end
    always @ (busy or negedge reset_n)
        begin
            if(!reset_n || busy)
                scki = 1'b0;
            else
                begin
                    for(i = 1; i<=48; i=i+1)
                        begin
                            #SCKI_HALF_PERIOD scki = ~scki;
                        end
                end
        end

    //*************************************************************************

    // Generate the conversion signal
    initial
        begin
            cnv = 1'b0;
            #100; 
            #40 cnv = 1'b1;
            #420 cnv = 1'b0;
            #(CNV_PERIOD-420) cnv = 1'b0;
        end

    //*************************************************************************

    // Generate the serial data in
    integer j;
    initial
        begin
            sdi = 1'b0;
        end
    always @ (busy or negedge reset_n)
        begin
            if(!reset_n)
                sdi = 1'b0;
            else
                begin
                    if(busy)
                        sdi = cnfg_data[23];
                    else
                        begin
                            for(j=2;j<23;j=j+1)
                                begin
                                    #(SCKI_HALF_PERIOD*2) sdi = cnfg_data[24-j];
                                end
                            #(SCKI_HALF_PERIOD*2) sdi = cnfg_data[0];
                        end
                end
        end

    //*************************************************************************

    // Stop the sim
    initial
        begin
            #END_SIM_DELAY;
            $stop;
            $finish; // close the simulation
        end

    //*************************************************************************

    LTC2358_model dut
    (
        // Simulation Interface
        .reset_n    (reset_n),            // Used to reset the model
        .data       (data),               // Input for the ADC data

        // ADC Interface
        .cs_n       (cs_n),               // Chip select active low
        .cnv        (cnv),                // Convert start
        .busy       (busy),               // Busy output
        .sdi        (sdi),                // Serial data input
        .scki       (scki),               // Serial clock input
        .sdo        (sdo)                 // Serial data output
    );
endmodule