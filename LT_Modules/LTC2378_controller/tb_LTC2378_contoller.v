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
        The purpose of this test bench is to verify the LTC2378 controller module.
*/

module tb_LTC2378_controller();

    ///////////////////////////////////////////////////////////////////////////
    // Signal declaration
    ///////////////////////////////////////////////////////////////////////////

    reg             clk;
    reg             pll_clk;
    reg             reset_n;
    reg             go;
    wire            rdl;
    wire            sck;
    wire            sdo;
    wire            busy;
    wire            cnv;
    wire    [19:0]  data_in;
    wire            valid;
    wire    [19:0]  data_out;
    wire            error;
    reg             d1_cnv;

    ///////////////////////////////////////////////////////////////////////////
    // Module parameters
    ///////////////////////////////////////////////////////////////////////////
    
    // Change the parameters to modify the test
    parameter CLK_HALF_PERIOD       = 10;   // 50Mhz
    parameter RST_DEASSERT_DELAY    = 100;
    parameter GO_SIG_IN_CYCLES      = 100;
    parameter END_SIM_DELAY         = 100000;

    // Change the following to test for different inputs
    assign data_in     = 20'hC0DE1;     // Dummy data for Nyquist port
    //*************************************************************************

    // Generate the clock
    initial
        begin
            clk = 1'b0;
        end
    always
        begin
            #CLK_HALF_PERIOD clk = ~clk;
        end

    //*************************************************************************

    // Generate the pll_clock
    initial
        begin
            pll_clk = 1'b0;
        end
    always @ (clk)
        begin
            #(CLK_HALF_PERIOD*0.5) pll_clk = ~pll_clk;
        end

    //*************************************************************************

    // Generate the reset_n
    initial
        begin
            reset_n                     = 1'b0;
            #RST_DEASSERT_DELAY reset_n = 1'b1;
        end

    //*************************************************************************

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

    //*************************************************************************

    // Used to simulate the external flip flop on cnv
    always @ (posedge clk)
        begin
            d1_cnv <= cnv;
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

    // The device under test
    LTC2378_controller #
    (
        .NUM_OF_CLK_PER_BSY(33),    // Number of sys_clk cycles to make 675ns
                                    // 675ns / (1/50 Mhz) ~ 34 cycles (rounded up) then -1
        .DFF_CYCLE_COMP (1)         // Compensate on clock for the external DFF
    )
    dut
    (
        // Control 
        .sys_clk        (clk),      // The digital clock
        .sck_in         (pll_clk),  // The serial clock from PLL to be gated for the sck of the LTC2378
        .reset_n        (reset_n),  // Reset active low
        .go             (go),       // Start a ADC read

        // LTC2378 Signals
        .LTC2378_rdl    (rdl),      // Read data low
        .LTC2378_sck    (sck),      // Gated clock for Nyquist data port
        .LTC2378_sdo    (sdo),      // Serial data out for the ADC's Nyquist port
        .LTC2378_busy   (busy),     // The ADC is busy with a conversion
        .LTC2378_cnv    (cnv),      // The conversion clock

        // Streaming output
        .data           (data_out), // Parallel Nyquist data out
        .valid          (valid),    // The Nyquist data is valid
        .error          (error)     // The filtered data is valid
    );

    //*************************************************************************

    // The LTC2378 digital model interface
    LTC2378_model ltc2378
    (
        // System signals
        .reset_n    (reset_n),
        .data       (data_in),

        .rdl        (rdl),
        .sck        (sck),
        .sdo        (sdo),
        .cnv        (d1_cnv),
        .busy       (busy)
    );
endmodule