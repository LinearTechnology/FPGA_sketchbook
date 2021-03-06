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
        The purpose of this test bench is to verify the LTC2500 controller module.
*/

module tb_LTC2500_controller();

    // Signal declaration
    reg             clk;
    reg             reset_n;
    reg             go;
    reg             sync_req_recfg;
    wire    [9:0]   cfg;
    wire    [13:0]  n;
    wire            rdl_filt;
    wire            sck_filt;
    wire            sdi_filt;
    wire            sdo_filt;
    wire            rdl_nyq;
    wire            sck_nyq;
    wire            sdo_nyq;
    wire            busy;
    wire            drdy_n;
    wire            mclk;
    wire            sync;
    wire            pre;
    wire    [31:0]  data_nyq;
    wire            valid_nyq;
    wire    [53:0]  data_filt;
    wire            valid_filt;
    wire            error;
    reg             d1_mclk;
    wire    [31:0]  nyquist_data;
    wire    [31:0]  filtered_data;

    // Change the parameters to modify the test
    parameter CLK_HALF_PERIOD       = 10;   // 50Mhz
    parameter RST_DEASSERT_DELAY    = 100;
    parameter GO_SIG_IN_CYCLES      = 50;
    parameter END_SIM_DELAY         = 1000000;

    // Change the following to test for different input and configurations
    assign nyquist_data     = 32'h12345678;     // Dummy data for Nyquist port
    assign filtered_data    = 32'h12345678;     // Dummy data for filtered data
    assign cfg              = 10'b00_0100_0100; // Configuration word
    assign n                = 14'h3FFF;         // N factor for averaging mode

    // Generate the clock
    initial
        begin
            clk = 1'b0;
        end
    always
        begin
            #CLK_HALF_PERIOD clk = ~clk;
        end

    // Generate the reset_n
    initial
        begin
            reset_n                     = 1'b0;
            #RST_DEASSERT_DELAY reset_n = 1'b1;
        end

    // Generate the go
    initial
        begin
            go = 1'b0;
        end
    always
        begin
            go = 1'b1;
            #(CLK_HALF_PERIOD*2) go = 1'b0;
            #(CLK_HALF_PERIOD*2*(GO_SIG_IN_CYCLES-1));
        end

    // Generate the sync_req_recfg
    initial
        begin
            sync_req_recfg = 1'b0;
            #(CLK_HALF_PERIOD*2)
            #(CLK_HALF_PERIOD*2*(GO_SIG_IN_CYCLES-1));
            sync_req_recfg = 1'b1;
            #(CLK_HALF_PERIOD*2)
            sync_req_recfg = 1'b0;
        end

    // Used to simulate the external flip flop on mclk
    always @ (posedge clk)
        begin
            d1_mclk <= mclk;
        end

    // Stop the sim
    initial
        begin
            #END_SIM_DELAY;
            $stop;
            $finish; // close the simulation
        end

    // The device under test
    LTC2500_controller #
    (
        .NUM_OF_CLK_PER_BSY(33), // Number of sys_clk cycles to make 675ns
                                 // 675ns / (1/50 Mhz) ~ 34 cycles (rounded up) then -1
        .TRUNK_VALUE (16)        // Truncated data count value per mclk
    )
    dut
    (
        // Control 
        .sys_clk        (clk),              // The digital clock
        .reset_n        (reset_n),          // Reset active low
        .go             (go),               // Start a ADC read
        .sync_req_recfg (sync_req_recfg),   // Request a synchronisation
        .cfg            (cfg),              // The configuration word 
        .n              (n),                // The averaging ratio
        .pre_mode       (1'b0),             // The preset mode

        // LTC2500 Signals
        // Port A
        .rdl_filt       (rdl_filt),       // Read data low for the filtered data port
        .sck_filt       (sck_filt),       // Gated clock for filtered data port
        .sdi_filt       (sdi_filt),       // Serial data in for the ADC's filtered port
        .sdo_filt       (sdo_filt),       // Serial data out for the ADC's filtered port
        // Port B
        .rdl_nyq        (rdl_nyq),        // Read data low for the Nyquist data port
        .sck_nyq        (sck_nyq),        // Gated clock for Nyquist data port
        .sdo_nyq        (sdo_nyq),        // Serial data out for the ADC's Nyquist port

        .busy           (busy),           // The ADC is busy with a conversion
        .drdy_n         (drdy_n),         // The ADC is not ready for filtered data
        .mclk           (mclk),           // The conversion clock
        .sync           (sync),           // The synchronizing signal for the ADC
        .pre            (pre),            // The pre signal is used to configure the filtered data
                                          // into two settings, depending on SDI logic level.
        // Streaming output
        .data_nyq       (data_nyq),       // Parallel Nyquist data out
        .valid_nyq      (valid_nyq),      // The Nyquist data is valid

        .data_filt      (data_filt),      // Parallel filtered data out
        .valid_filt     (valid_filt),     // Parallel common mode filtered data out
        .error          (error)           // The filtered data is valid
    );

    // The LTC2500 digital model interface
    LTC2500_model ltc2500
    (
        // Simulation interface
        .reset_n        (reset_n),          // Used to reset the model
        .nyquist_data   (nyquist_data),     // Input for Nyquist data
        .filtered_data  (filtered_data),    // Input for filtered data
        .n (n),                             // Input for number of sampled averaged

        // ADC Interface
        // A SPI port
        .rdla           (rdl_filt),         // Read low input A. 
        .scka           (sck_filt),         // Serial clock input A
        .sdoa           (sdo_filt),         // Serial data output A

        // B SPI port
        .rdlb           (rdl_nyq),          // Read low input B
        .sckb           (sck_nyq),          // Serial clock input B
        .sdob           (sdo_nyq),          // Serial data input B

        .pre            (pre),              // Preset input
        .mclk           (mclk),             // Master clock input
        .sync           (sync),             // Synchronization input
        .drdy_n         (drdy_n),           // Data ready output
        .sdi            (sdi_filt),         // Serial data in
        .busy           (busy)              // Busy indicator
    );

endmodule