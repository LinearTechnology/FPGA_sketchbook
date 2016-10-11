// sat_rnd.v
//
// Project: Medium Wave (500 kHz - 1700 kHz) Receiver, SDR Demonstration
// Copyright 2012, Zephyr Engineering, Inc., All Rights Reserved
//
// Description: Since Verilog doesn't allow you to parameterize functions,
// we create a saturation/rounding module that does the same thing. This
// implementation is dual-channel so one instantiation can be used for 
// both components of a complex value. The process:
// 1.) Truncate the desired number of bits.
// 2.) Add the value of the most significant truncated bit (rounds 1/2 in
//     positive direction).
// 3.) Saturate to maximum signed value unless all MSBs equal the sign bit.
//
// Written by: Steve Kalandros
//
// Revision 0.1 - July 26, 2012 S.K. Initial release
// Revision 0.2 - Aug. 20, 2012 S.K. Make dual-channel
// -----------------------------------------------------------------------------------------------------

// ---- Module I/O -------------------------------------------------------------------------------------
module sat_rnd
#(
    parameter IN_SIZE    = 32,                 // Size of original value
    parameter TRUNC_SIZE = 15,                 // Number of LSBs to truncate
    parameter OUT_SIZE   = 16                  // Size of output value
) (
    input      signed [IN_SIZE-1:0]    d1,     // Channel 1 input value
    input      signed [IN_SIZE-1:0]    d2,     // Channel 2 input value
    output reg signed [OUT_SIZE-1:0]   q1,     // Channel 1 output value
    output reg signed [OUT_SIZE-1:0]   q2      // Channel 2 output value
);
// -----------------------------------------------------------------------------------------------------


// ---- User Parameters --------------------------------------------------------------------------------
localparam TEMP_SIZE = IN_SIZE - TRUNC_SIZE + 1;   // Size after truncating and sign-extending
localparam SAT_SIZE  = TEMP_SIZE - OUT_SIZE;       // Number of MSBs to saturate
// -----------------------------------------------------------------------------------------------------


// ---- Rounding ---------------------------------------------------------------------------------------
reg signed [TEMP_SIZE-1:0] temp1;
reg signed [TEMP_SIZE-1:0] temp2;

always @(*) begin
    // Skip rounding if TRUNC_SIZE is zero. Still need to sign-extend to be consistent
    // with saturation logic.
    if (TRUNC_SIZE == 0) begin
        temp1 = {d1[IN_SIZE-1], d1};
        temp2 = {d2[IN_SIZE-1], d2};
    end
    
    // Sign-extend the original value minus the LSBs to truncate and add the value
    // of the most significant truncated bit. If this bit is low, meaning the truncated
    // bits are less than 0.5, nothing is added and the bits are just dropped,
    // i.e. it rounds down. If this bit is high, meaning the truncated bits are
    // greater than or equal to 0.5, it adds 1, i.e. it rounds up. Note that +0.5
    // rounds to 1 and -0.5 rounds to zero so there is a slight positive bias
    // here.
    else begin
        temp1 = {d1[IN_SIZE-1], d1[IN_SIZE-1:TRUNC_SIZE]} + d1[TRUNC_SIZE-1];
        temp2 = {d2[IN_SIZE-1], d2[IN_SIZE-1:TRUNC_SIZE]} + d2[TRUNC_SIZE-1];
    end
end
// -----------------------------------------------------------------------------------------------------


// ---- Saturation -------------------------------------------------------------------------------------
// If the bits to be saturated do not ALL match the new sign bit, then the original
// value is too large to fit into the smaller vector and must be saturated.
// Saturation is done by preserving the sign bit and setting all the other bits in
// the output vector to the logical inverse of the sign bit. If no saturation is
// needed, just pass the rounded value after removing the MSBs.
//
// Channel 1
always @(*) begin
    if (temp1[TEMP_SIZE-2:OUT_SIZE-1] != {SAT_SIZE{temp1[TEMP_SIZE-1]}}) begin
        q1 = {temp1[TEMP_SIZE-1], {(OUT_SIZE-1){~temp1[TEMP_SIZE-1]}}};
    end
    else begin
        q1 = temp1[OUT_SIZE-1:0];
    end
end

// Channel 2
always @(*) begin
    if (temp2[TEMP_SIZE-2:OUT_SIZE-1] != {SAT_SIZE{temp2[TEMP_SIZE-1]}}) begin
        q2 = {temp2[TEMP_SIZE-1], {(OUT_SIZE-1){~temp2[TEMP_SIZE-1]}}};
    end
    else begin
        q2 = temp2[OUT_SIZE-1:0];
    end
end
// -----------------------------------------------------------------------------------------------------

endmodule

