// output_fir.v
//
// Project: Medium Wave (500 kHz - 1700 kHz) Receiver, SDR Demonstration
// Copyright 2012, Zephyr Engineering, Inc., All Rights Reserved
//
// Description: Implements a generic dual-channel FIR filter with the data and
// coefficient sizes specified by input parameters. Coefficients specified in a
// separate HEX file determine the bandwidth. The number of taps may be specified
// by an internal parameter. Sample rate is determined by the periodicity of the
// strobe_in input. This implementation calculates and accumulates the
// data/coefficient products serially. There are 5 pipeline stages involved in
// the calculations so each output sample takes N+5 clock cycles to complete,
// where N is the number of filter taps.
//
// Written by: Steve Kalandros
//
// Revision 0.1 - July 23, 2012 S.K. Initial release
// -----------------------------------------------------------------------------------------------------

// ---- Module I/O -------------------------------------------------------------------------------------
module output_fir
#(
    parameter DATA_SIZE = 16,                          // Input/output data width
    parameter COEF_SIZE = 16                           // Coefficient data width
) (
    input    wire  clk,                                // System clock
    input    wire  reset_n,                            // System reset
    input    wire  strobe_in,                          // Input sample valid strobe
    input    wire  signed [DATA_SIZE-1:0] ch1_in,      // Channel 1 input sample
    input    wire  signed [DATA_SIZE-1:0] ch2_in,      // Channel 2 input sample
    output   wire  strobe_out,                         // Output sample valid strobe
    output   reg   signed [DATA_SIZE-1:0] ch1_out,     // Channel 1 output sample
    output   reg   signed [DATA_SIZE-1:0] ch2_out      // Channel 2 output sample
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
// Specify FIR coefficient parameters. This FIR was designed to have a 5 kHz
// cut-off frequency. The maximum number of taps is 5 fewer than the number of
// clock cycles between input samples.
// -----------------------------------------------------------------------------------------------------
localparam N_TAPS    = 128;                    // Number of FIR taps/coefficients
localparam N_TRUNC   = 17;                     // Number of bits to truncate from accumulator
localparam CNTR_SIZE = clog_b2(N_TAPS);        // Size of control counters = ceiling(log2(N_TAPS))
localparam RAM_SIZE  = 2**CNTR_SIZE;           // Depth of data RAM and coefficient ROM
localparam PROD_SIZE = 2*DATA_SIZE;            // Width of FIR products
localparam ACC_SIZE  = PROD_SIZE + CNTR_SIZE;  // Width of FIR accumulator
localparam SAT_SIZE  = ACC_SIZE - N_TRUNC;     // Number of bits remaining after truncation
// -----------------------------------------------------------------------------------------------------


// ---- Module Control ---------------------------------------------------------------------------------
// The FIR calculations are triggered by a pulse on the strobe_in input and
// take N+5 clock cycles where N is the number of FIR coefficients.
// -----------------------------------------------------------------------------------------------------
wire d_wen;                                    // Data RAM write enable
wire signed [DATA_SIZE-1:0] ch1_wdata;         // Data RAM write data
wire signed [DATA_SIZE-1:0] ch2_wdata;         // Data RAM write data
reg  [CNTR_SIZE-1:0] d_waddr;                  // Data RAM write address
reg  [CNTR_SIZE-1:0] d_raddr;                  // Data RAM read address
reg  [CNTR_SIZE-1:0] c_raddr;                  // Coefficent ROM read address
reg  ren;                                      // Data/coefficient read enable
reg  [1:0] ren_sr;                             // Pipelined read-enable
reg  done;                                     // Read-out done flag

// RAM write enable is the input strobe; concatenate I and Q for write data.
assign d_wen = strobe_in;
assign ch1_wdata = ch1_in;
assign ch2_wdata = ch2_in;

// Increment RAM write address on strobe_in (circular address buffer).
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        d_waddr <= {(CNTR_SIZE){1'b0}};
    end
    else if (strobe_in) begin
        d_waddr <= d_waddr + 1'b1;
    end
end

// Save last RAM write address as starting read address on strobe_in;
// count down on read enable to go backwards in delay line.
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        d_raddr <= {(CNTR_SIZE){1'b0}};
    end
    else if (strobe_in) begin
        d_raddr <= d_waddr;
    end
    else if (ren) begin
        d_raddr <= d_raddr - 1'b1;
    end
end

// Clear ROM read address on strobe_in or done and increment on read enable.
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        c_raddr <= {(CNTR_SIZE){1'b0}};
    end
    else if (strobe_in || done) begin
        c_raddr <= {(CNTR_SIZE){1'b0}};
    end
    else if (ren) begin
        c_raddr <= c_raddr + 1'b1;
    end
end

// Set read enable on strobe_in and reset when done.
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        ren <= 1'b0;
    end
    else if (done) begin
        ren <= 1'b0;
    end
    else if (strobe_in) begin
        ren <=1'b1;
    end
end

// Pipeline read enable signal to use for accumulator enable.
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        ren_sr <= 2'b00;
    end
    else begin
        ren_sr <= {ren_sr[0], ren};
    end
end

// Assert done flag when the ROM read address reaches the final coefficient.
always @(c_raddr) begin
    if (c_raddr == N_TAPS-1) begin
        done = 1'b1;
    end
    else begin
        done = 1'b0;
    end
end
// -----------------------------------------------------------------------------------------------------


// ---- Data RAMs --------------------------------------------------------------------------------------
wire signed [DATA_SIZE-1:0] ch1_rdata;         // Data RAM read data
wire signed [DATA_SIZE-1:0] ch2_rdata;         // Data RAM read data

// Instantiate channel 1 RAM.
ram_2_port_rden #(
    .ADDR_SIZE (CNTR_SIZE),
    .DATA_SIZE (DATA_SIZE)
) ram_2_port_rden_ch1_inst (
    .clk (clk),
    .wren (d_wen),
    .waddr (d_waddr),
    .d (ch1_wdata),
    .rden (ren),
    .raddr (d_raddr),
    .q (ch1_rdata)
);

// Instantiate channel 2 RAM.
ram_2_port_rden #(
    .ADDR_SIZE (CNTR_SIZE),
    .DATA_SIZE (DATA_SIZE)
) ram_2_port_rden_ch2_inst (
    .clk (clk),
    .wren (d_wen),
    .waddr (d_waddr),
    .d (ch2_wdata),
    .rden (ren),
    .raddr (d_raddr),
    .q (ch2_rdata)
);
// -----------------------------------------------------------------------------------------------------


// ---- Coefficient ROM --------------------------------------------------------------------------------
wire signed [COEF_SIZE-1:0] c_rdata;           // Coefficent ROM read data

// Instantiate ROM.
output_fir_rom #(
    .ADDR_SIZE (CNTR_SIZE),
    .COEF_SIZE (COEF_SIZE)
) output_fir_rom_inst (
    .clk (clk),
    .rden (ren),
    .addr (c_raddr),
    .q (c_rdata)
);
// -----------------------------------------------------------------------------------------------------


// ---- MAC --------------------------------------------------------------------------------------------
reg signed [PROD_SIZE-1:0] ch1_product;        // Channel 1 product of data and coefficients
reg signed [PROD_SIZE-1:0] ch2_product;        // Channel 2 product of data and coefficients
reg signed [ACC_SIZE-1:0]  ch1_acc;            // Channel 1 Accumulator
reg signed [ACC_SIZE-1:0]  ch2_acc;            // Channel 2 Accumulator

// Multiply sample data by FIR coefficients.
always @(posedge clk or negedge reset_n) begin
    if (!reset_n)    begin
        ch1_product <= {(PROD_SIZE){1'b0}};
        ch2_product <= {(PROD_SIZE){1'b0}};
    end
    else begin
        ch1_product <= ch1_rdata * c_rdata;
        ch2_product <= ch2_rdata * c_rdata;
    end
end

// Accumulate products of data and coefficients.
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        ch1_acc <= {(ACC_SIZE){1'b0}};
        ch2_acc <= {(ACC_SIZE){1'b0}};
    end
    else if (strobe_in) begin
        ch1_acc <= {(ACC_SIZE){1'b0}};
        ch2_acc <= {(ACC_SIZE){1'b0}};
    end
    else if (ren_sr[1]) begin
        ch1_acc <= ch1_acc + ch1_product;
        ch2_acc <= ch2_acc + ch2_product;
    end
end
// -----------------------------------------------------------------------------------------------------


// ---- Saturate/Round Final Output --------------------------------------------------------------------
reg [3:0] done_sr;                             // Pipelined done signal
reg signed [SAT_SIZE-1:0] ch1_sat_rnd;         // Final Channel 1 output sample
reg signed [SAT_SIZE-1:0] ch2_sat_rnd;         // Final Channel 2 output sample

// Pipeline done flag to account for calculation latency. Four stages:
// RAM/ROM, product, accumulator, sat/round.
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        done_sr <= 4'h0;
    end
    else begin
        done_sr <= {done_sr[2:0], done};
    end
end

// Saturate and round the final accumulator value.
always @(*) begin
    ch1_sat_rnd = ch1_acc[ACC_SIZE-1:N_TRUNC] + ch1_acc[N_TRUNC-1];
    ch2_sat_rnd = ch2_acc[ACC_SIZE-1:N_TRUNC] + ch2_acc[N_TRUNC-1];

    // Check for saturation, e.g. MSBs are not either all 0's or all 1's. If
    // that is the case, set the MSBs equal to the sign bit and the LSBs equal
    // to the logical inverse of the sign bit.
    if ((ch1_sat_rnd[SAT_SIZE-1:DATA_SIZE-1] != {(SAT_SIZE-DATA_SIZE+1){1'b0}}) &&
	(ch1_sat_rnd[SAT_SIZE-1:DATA_SIZE-1] != {(SAT_SIZE-DATA_SIZE+1){1'b1}})) begin
                ch1_sat_rnd[SAT_SIZE-1:DATA_SIZE-1] = {(SAT_SIZE-DATA_SIZE+1){ch1_sat_rnd[SAT_SIZE-1]}};
		ch1_sat_rnd[14:0]                   = {(DATA_SIZE-1){~ch1_sat_rnd[SAT_SIZE-1]}};
    end

    if ((ch2_sat_rnd[SAT_SIZE-1:DATA_SIZE-1] != {(SAT_SIZE-DATA_SIZE+1){1'b0}}) &&
	(ch2_sat_rnd[SAT_SIZE-1:DATA_SIZE-1] != {(SAT_SIZE-DATA_SIZE+1){1'b1}})) begin
                ch2_sat_rnd[SAT_SIZE-1:DATA_SIZE-1] = {(SAT_SIZE-DATA_SIZE+1){ch2_sat_rnd[SAT_SIZE-1]}};
		ch2_sat_rnd[14:0]                   = {(DATA_SIZE-1){~ch2_sat_rnd[SAT_SIZE-1]}};
    end
end

// Store the saturated/rounded value as the final output sample.
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        ch1_out <= {(DATA_SIZE){1'b0}};
        ch2_out <= {(DATA_SIZE){1'b0}};
    end
    else if (done_sr[2]) begin
        ch1_out <= ch1_sat_rnd[DATA_SIZE-1:0];
        ch2_out <= ch2_sat_rnd[DATA_SIZE-1:0];
    end
end

// The output strobe is the final done pipeline stage.
assign strobe_out = done_sr[3];
// -----------------------------------------------------------------------------------------------------

endmodule

