// nco.v
//
// Project: Medium Wave (500 kHz - 1700 kHz) Receiver, SDR Demonstration
// Copyright 2012, Zephyr Engineering, Inc., All rights reserved.
//
// Description: Simple, brute-force implementation of NCO. Phase accumulator
// increments by input phase_inc value each clock cycle. MSBs of phase accumulator
// are address inputs to sine and cosine lookup tables. Lookup tables are 4096 
// locations deep (angular resolution) and 16 bits wide (amplitude resolution).
// No optimization of lookup table size is implemented. Full cycle of both sine
// and cosine are stored. Outputs one sample each of cosine and sine per cycle.
//
// Optimization opportunity: Use the upper two bits of the phase accumulator
// to determine the quadrant of the unit circle; then only store a quarter of
// the cosine and sine cycle and conditionally negate the lookup values
// depending on the quadrant. This would reduce memory block usage by 75%.
//
// Written by: Charles Mesarosh
//
// Revision 0.1 - May 4, 2012 C.M. Initial release
// -----------------------------------------------------------------------------------------------------

// ---- Module I/O -------------------------------------------------------------------------------------
// generates cosine and sine outputs
module z_nco (
    input  wire clk,                   // System clock
    input  wire reset_n,               // System reset
    input  wire [31:0] phase_inc,      // Phase increment
    output wire [15:0] fcos,           // Cosine output
    output wire [15:0] fsin            // Sine output
);
// -----------------------------------------------------------------------------------------------------


// ---- Phase Accumulator ------------------------------------------------------------------------------
reg [31:0] accum;                      // Phase accumulator

// Accumulate the current phase increment every clock cycle
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        accum <= 32'h0;
    end
    else begin
        accum <= accum + phase_inc;
    end
end
// -----------------------------------------------------------------------------------------------------


// ---- Lookup Tables ----------------------------------------------------------------------------------
// Cosine lookup table.
lut_cos lut_cos_inst (
    .address ( accum[31:20] ),
    .clock ( clk ),
    .q ( fcos[15:0] )
);

// Sine lookup table.
lut_sin lut_sin_inst (
    .address ( accum[31:20] ),
    .clock ( clk ),
    .q ( fsin[15:0] )
);
// -----------------------------------------------------------------------------------------------------

endmodule

