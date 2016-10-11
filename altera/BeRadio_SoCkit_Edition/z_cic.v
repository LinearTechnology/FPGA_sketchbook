// z_cic.v
//
// Project: Medium Wave (500 kHz - 1700 kHz) Receiver, SDR Demonstration
// Copyright 2012, Zephyr Engineering, Inc., All rights reserved.
//
// Description: Implements a generic dual-channel CIC filter with the number
// of stages and decimation rate specified by input parameters.
//
// Written by: Charles Mesarosh & Steve Kalandros
//
// Revision 0.1 - May 27, 2012  C.M. Initial release
// Revision 0.2 - July 26, 2012 S.K. Use FOR loops to make configurable
// Revision 0.3 - Aug. 20, 2012 S.K. Make dual-channel
// -----------------------------------------------------------------------------------------------------

// ---- Module I/O -------------------------------------------------------------------------------------
module z_cic
#(
    parameter IN_SIZE  = 16,                           // Input data width
    parameter OUT_SIZE = 16,                           // Output data width
    parameter N_STAGES = 5,                            // Number of stages
    parameter DEC_RATE = 10                            // Decimation rate
) (
    input    wire  clk,                                // System clock
    input    wire  reset_n,                            // System reset
    input    wire  instrobe,                           // Input sample valid strobe
    input    wire  signed [IN_SIZE-1:0] in1_data,      // Channel 1 input sample
    input    wire  signed [IN_SIZE-1:0] in2_data,      // Channel 2 input sample
    output   wire  outstrobe,                          // Output sample valid strobe
    output   reg   signed [OUT_SIZE-1:0] out1_data,    // Channel 1 output sample
    output   reg   signed [OUT_SIZE-1:0] out2_data     // Channel 2 output sample
);
// -----------------------------------------------------------------------------------------------------


// ---- Function Definitions ---------------------------------------------------------------------------
// Function to calculate ceiling of Log base 2 of a value.
function integer clog_b2;
    input [31:0] value;
    integer tmp;
    begin
        tmp = value - 1;        
        for (clog_b2 = 0; tmp > 0; clog_b2 = clog_b2 + 1) tmp = tmp >> 1;
    end
endfunction
// -----------------------------------------------------------------------------------------------------


// ---- User Parameters --------------------------------------------------------------------------------
// Derive internal parameters from input parameters using the Log2 function.
// -----------------------------------------------------------------------------------------------------
localparam CNTR_SIZE = clog_b2(DEC_RATE);              // Size of sample decimation counter
localparam ACC_SIZE  = IN_SIZE + (N_STAGES*CNTR_SIZE); // Width of integration accumulators
// -----------------------------------------------------------------------------------------------------


// ---- Module Control ---------------------------------------------------------------------------------
reg [CNTR_SIZE-1:0] sample_count;                      // Sample decimation counter
reg combstrobe;                                        // Strobe for activating comb stages
reg [1:0] del_strobe;                                  // Pipelined comb strobe to match latency

// Generate internal strobe for every DEC_RATE input strobes.
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        sample_count <= {(CNTR_SIZE){1'b0}};
    end
    else begin
        del_strobe <= {del_strobe[0] , combstrobe};
        if (instrobe) begin
            if (sample_count == DEC_RATE - 1) begin
                sample_count <= {(CNTR_SIZE){1'b0}};
                combstrobe <= 1'b1;
            end
            else begin
                sample_count <= sample_count + 1'b1;
                combstrobe <= 1'b0;
            end
        end
        else begin
            combstrobe <= 1'b0;
        end
    end
end
// -----------------------------------------------------------------------------------------------------


// ---- Integrator Stages ------------------------------------------------------------------------------
reg signed [ACC_SIZE-1:0] integ1 [N_STAGES-1:0];       // Array of integrators for channel 1
reg signed [ACC_SIZE-1:0] integ2 [N_STAGES-1:0];       // Array of integrators for channel 2
integer i;                                             // FOR loop variable

// For each integration stage, integrate the value of the previous stage. The
// first stage integrates the input data.
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        for (i = 0; i < N_STAGES; i = i + 1) begin
            integ1[i] <= 0;
            integ2[i] <= 0;
        end
    end
    else begin
        if (instrobe) begin
            integ1[0]       <= integ1[0] + {{(ACC_SIZE-IN_SIZE){in1_data[IN_SIZE-1]}},in1_data};
            integ2[0]       <= integ2[0] + {{(ACC_SIZE-IN_SIZE){in2_data[IN_SIZE-1]}},in2_data};
            for (i = 1; i < N_STAGES; i = i + 1) begin
                integ1[i]   <= integ1[i] + integ1[i-1];
                integ2[i]   <= integ2[i] + integ2[i-1];
            end
        end
    end
end
// -----------------------------------------------------------------------------------------------------


// ---- Comb Stages ------------------------------------------------------------------------------------
reg signed [ACC_SIZE-1:0] comb1 [N_STAGES-1:0];        // Array of comb stages for channel 1
reg signed [ACC_SIZE-1:0] comb1q [N_STAGES-1:0];       // Array of delayed comb values for channel 1
reg signed [ACC_SIZE-1:0] comb2 [N_STAGES-1:0];        // Array of comb stages for channel 2
reg signed [ACC_SIZE-1:0] comb2q [N_STAGES-1:0];       // Array of delayed comb values for channel 2
integer j;                                             // FOR loop variable

// For each comb stage, subtract the previous value of the previous stage from
// the current value of the previous stage. The first stage subtracts from the
// value of the final integration stage.
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        for (j = 0; j < N_STAGES; j = j + 1) begin
            comb1[j]  <= 0;
            comb1q[j] <= 0;
            comb2[j]  <= 0;
            comb2q[j] <= 0;
        end
    end
    else begin
        if (combstrobe) begin
            comb1[0]       <= integ1[N_STAGES-1] - comb1q[0];
            comb1q[0]      <= integ1[N_STAGES-1];
            comb2[0]       <= integ2[N_STAGES-1] - comb2q[0];
            comb2q[0]      <= integ2[N_STAGES-1];
            for (j = 1; j < N_STAGES; j = j + 1) begin
                comb1[j]   <= comb1[j-1] - comb1q[j];
                comb1q[j]  <= comb1[j-1];
                comb2[j]   <= comb2[j-1] - comb2q[j];
                comb2q[j]  <= comb2[j-1];
            end
        end
    end
end
// -----------------------------------------------------------------------------------------------------

// ---- Output -----------------------------------------------------------------------------------------
// Assign final element of delayed comb strobe as the output strobe.
assign outstrobe = del_strobe[1];

// Round off LSBs of final comb output to get filter output.
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        out1_data <= 0;
        out2_data <= 0;
    end
    else begin
        out1_data <= comb1[N_STAGES-1][ACC_SIZE-1:ACC_SIZE-OUT_SIZE] +
                     comb1[N_STAGES-1][ACC_SIZE-OUT_SIZE-1];
        out2_data <= comb2[N_STAGES-1][ACC_SIZE-1:ACC_SIZE-OUT_SIZE] +
                     comb2[N_STAGES-1][ACC_SIZE-OUT_SIZE-1];
    end
end
// -----------------------------------------------------------------------------------------------------

endmodule
