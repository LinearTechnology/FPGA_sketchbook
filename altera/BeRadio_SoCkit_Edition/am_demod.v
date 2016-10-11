// am_demod.v
//
// Project: Medium Wave (500 kHz - 1700 kHz) Receiver, SDR Demonstration
// Copyright 2012, Zephyr Engineering, Inc., All Rights Reserved
//
// Description: Calculate the amplitude of a received audio signal:
// data_out = sqrt(i_in^2 + q_in^2)
//
// Written by: Steve Kalandros
//
// Revision 0.1 - Aug. 24, 2012  S.K. Initial release.
// -----------------------------------------------------------------------------------------------------

// ---- Module I/O -------------------------------------------------------------------------------------
module am_demod
#(
    parameter DATA_SIZE = 16                           // Bits in data path
) (
    input   wire  clk,                                 // System clock
    input   wire  reset_n,                             // Asynchronous system reset
    input   wire  strobe_in,                           // Input data valid strobe
    input   wire  signed  [DATA_SIZE-1:0] i_in,        // In-phase input data
    input   wire  signed  [DATA_SIZE-1:0] q_in,        // Quadrature input data
    output  wire  strobe_out,                          // Output data valid strobe
    output  wire  signed  [DATA_SIZE-1:0] data_out     // Output data
);
// -----------------------------------------------------------------------------------------------------


// ---- AM Demodulator ---------------------------------------------------------------------------------
reg  [2:0] strb_sr;                            // Shift register to pipeline input strobe
reg  signed [2*DATA_SIZE-1:0] i_sqrq;          // Squared in-phase data
reg  signed [2*DATA_SIZE-1:0] q_sqrq;          // Squared quadrature data
wire [2*DATA_SIZE:0] sqrsum;                   // Sum of squares of in-phase and quadrature data
reg  [2*DATA_SIZE-1:0] sqrsumq;                // Registered sum of squares
wire [DATA_SIZE-1:0] sqrt_data;                // Amplitude of received data
reg  signed [DATA_SIZE-1:0] sqrtq;             // Registered amplitude of received data

// Square the in-phase and quadrature components of the input.
// Pipeline the input strobe to match latency.
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        strb_sr    <= 3'h0;
        i_sqrq     <= {(2*DATA_SIZE){1'b0}};
        q_sqrq     <= {(2*DATA_SIZE){1'b0}};
    end
    else begin
        strb_sr    <= {strb_sr[1:0], strobe_in};
        i_sqrq     <= i_in * i_in;
        q_sqrq     <= q_in * q_in;
    end
end

// Sum of the squares plus one to implement rounding. If bit 0 is set, this
// rounds up (more positive).
assign sqrsum = i_sqrq + q_sqrq + {{(2*DATA_SIZE-1){1'b0}},1'b1};

// Register the sum of the squares after rounding off the LSB.
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        sqrsumq    <= {(2*DATA_SIZE){1'b0}};
    end
    else begin
        sqrsumq    <= sqrsum[2*DATA_SIZE:1];
    end
end

// Calculate the amplitude of the received signal as the square root of the
// sum of the squares.
sqrt sqrt_inst (
    .radical (sqrsumq),
    .q (sqrt_data),
    .remainder ()
);

// Register the square root output.
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        sqrtq <= {DATA_SIZE{1'b0}};
    end
    else if (strb_sr[1]) begin
        sqrtq <= sqrt_data;
    end
end

// Assign output strobe and data.
assign strobe_out = strb_sr[2];
assign data_out   = sqrtq;
// -----------------------------------------------------------------------------------------------------

endmodule

