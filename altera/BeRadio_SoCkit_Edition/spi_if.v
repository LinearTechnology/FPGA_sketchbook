// spi_if.v
//
// Project: Medium Wave (500 kHz - 1700 kHz) Receiver, SDR Demonstration
// Copyright 2012, Zephyr Engineering, Inc., All Rights Reserved
//
// Description: Serially transmits an input value over a SPI interface.
//
// Written by: Steve Kalandros
//
// Revision 0.1 - Aug. 24, 2012  S.K. Initial release.
// -----------------------------------------------------------------------------------------------------

// ---- Module I/O -------------------------------------------------------------------------------------
module spi_if
#(
    parameter DATA_SIZE = 16                   // Number of bits to transmit
) (
    input    wire  clk,                        // System clock
    input    wire  reset_n,                    // Asynchronous system reset
    input    wire  strobe_in,                  // Input data valid strobe
    input    wire  [DATA_SIZE-1:0] data_in,    // Binary input vector
    output   wire  spi_clr_l,                  // Active-low SPI bus clear
    output   wire  spi_cs_l,                   // Active-low chip select
    output   wire  spi_sclk,                   // SPI bus clock
    output   wire  spi_data                    // SPI bus data
);
// -----------------------------------------------------------------------------------------------------


// ---- Function Definitions ---------------------------------------------------------------------------
// Function to calculate ceiling of Log base 2 of a value.
function integer clog_b2;
    input integer value;
    integer tmp;
    begin
        tmp = value - 1;        
        for (clog_b2 = 0; tmp > 0; clog_b2 = clog_b2 + 1) tmp = tmp >> 1;
    end
endfunction
// -----------------------------------------------------------------------------------------------------


// ---- Derived Parameters -----------------------------------------------------------------------------
localparam CNTR_SIZE  = clog_b2(DATA_SIZE);    // Bits in control counter
localparam CNTR_INIT  = DATA_SIZE - 1;         // Initial value for control counter
// -----------------------------------------------------------------------------------------------------


// ---- SPI Interface ----------------------------------------------------------------------------------
reg [DATA_SIZE-1:0] shifter;                   // SPI shift register
reg [CNTR_SIZE-1:0] cntr;                      // Control counter
reg clr_l;                                     // SPI clear (active-low)
reg cs_l;                                      // SPI chip select (active-low)
reg sclk;                                      // SPI clock

// Load the shift register and shift data onto the SPI bus.
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        shifter    <= {DATA_SIZE{1'b0}};
        cntr       <= {CNTR_SIZE{1'b0}};
        clr_l      <= 1'b0;
        cs_l       <= 1'b1;
        sclk       <= 1'b0;
    end
    else begin
        clr_l      <= 1'b1;

        // When the input strobe indicates new valid input data, initiate the
        // SPI bus transaction by asserting the SPI chip select, forcing the
        // SPI clock low, and loading the shift register and counter.
        if (strobe_in) begin
            shifter <= data_in;
            cntr    <= CNTR_INIT[CNTR_SIZE-1:0];
            cs_l    <= 1'b0;
            sclk    <= 1'b0;
        end

        // Shift data and decrement counter until finished.
        else if (!cs_l) begin
            // Invert the SPI clock every clock (effective rate is half the
            // clock rate).
            sclk    <= ~sclk;

            // Deassert chip select when terminal count has been reached.
            if ((cntr == {CNTR_SIZE{1'b0}}) && sclk) begin
                 cs_l <= 1'b1;
            end

            // Shift data and decrement counter on the falling edge of the SPI
            // clock.
            if (sclk) begin
                 shifter   <= {shifter[DATA_SIZE-2:0],1'b0};
                 cntr      <= cntr - {{(CNTR_SIZE-1){1'b0}},1'b1};
            end
        end
    end
end

// Assign SPI outputs.
assign spi_cs_l  = cs_l;
assign spi_clr_l = clr_l;
assign spi_sclk  = sclk;
assign spi_data  = shifter[DATA_SIZE-1];
// -----------------------------------------------------------------------------------------------------

endmodule

