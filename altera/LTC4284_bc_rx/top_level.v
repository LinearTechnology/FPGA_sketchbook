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
        The purpose of this module is to interface with the DC2459A demo board as 
        a digital signal generator.
*/

module top_level
(
    // System signals
    sys_clk,
    reset_btn,
    trig,

    // SPI interface
    spi_ss,
    spi_sck,
    spi_miso,
    spi_mosi,

    // LTC1668 interface
    ltc1668_data
);

    ///////////////////////////////////////////////////////////////////////////
    // Port declaration
    ///////////////////////////////////////////////////////////////////////////

    // System signals
    input               sys_clk;
    input               reset_btn;
    output              trig;

    // SPI interface
    input               spi_ss;
    input               spi_sck;
    output              spi_miso;
    input               spi_mosi;

    // LTC1668 interface
    output  [15:0]  ltc1668_data;

    ///////////////////////////////////////////////////////////////////////////
    // Module parameters
    ///////////////////////////////////////////////////////////////////////////


    ///////////////////////////////////////////////////////////////////////////
    // Internal signals
    ///////////////////////////////////////////////////////////////////////////

    reg         [31:0]  shift_reg;
    wire                reset_n;
    wire        [17:0]  nco_sin;
    reg         [31:0]  dff;
	 wire        rx_clk;

    //*************************************************************************

    // Connect the reset to the reset button
    assign reset_n = reset_btn;

    //*************************************************************************

    assign ltc1668_data = 16'b0;
    assign trig =  1'b0;

	 LTC4284_bc_rx LTC4284_bc_rx_inst(
	 
	 

           .clk_24m (rx_clk),       // Clock
           .enb(1'b1),           // High to enable packet detect, low to abort
                                   // (enb low doesn't alter the SPI read buffer)
           .sdao(reset_btn),          // Serial output from 4284
           .cs_n(spi_ss),          // SPI chip select#
           .sck(spi_sck),           // SPI clock, in mode 0 or 3.
                                   // The falling edge of cs_n will cause the first
                                   // bit to be output.  Subsequent changes happend on
                                   // sck falling edges.  However, a rising edge must
                                   // happen first, before a falling edge is used
          .miso(spi_miso)           // Data output

	 );

	 pll_1	pll_1_inst (
	.inclk0 ( sys_clk ),
	.c0 ( rx_clk ),
	.locked ( locked_sig )
	);

endmodule
