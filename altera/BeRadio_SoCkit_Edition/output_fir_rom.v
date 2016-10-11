// output_fir_rom.v
//
// Project: Medium Wave (500 kHz - 1700 kHz) Receiver, SDR Demonstration
// Copyright 2012, Zephyr Engineering, Inc., All Rights Reserved
//
// Description: Implements a ROM to store coefficients for the output FIR
// filter. Instantiates an Altera altsyncram megafunction but uses input
// parameters to specify the address and data vector widths. Outputs are
// not registered so there is one cycle of read latency. ROM contents are
// specified in a separate HEX file.
//
// Written by: Steve Kalandros
//
// Revision 0.1 - July 24, 2012 S.K. Initial release
// -----------------------------------------------------------------------------------------------------

// ---- Module I/O -------------------------------------------------------------------------------------
module output_fir_rom
#(
    parameter ADDR_SIZE = 7,                   // Address width
    parameter COEF_SIZE = 16                   // Coefficient data width
) (
    input    wire  clk,                        // System clock
    input    wire  rden,                       // Read enable
    input    wire  [ADDR_SIZE-1:0] addr,       // Read address
    output   wire  [COEF_SIZE-1:0] q           // Output coefficient
);
// -----------------------------------------------------------------------------------------------------


// ---- Altera RAM Instantiation -----------------------------------------------------------------------
altsyncram altsyncram_component (
            .address_a (addr),
            .clock0 (clk),
            .rden_a (rden),
            .q_a (q),
            .aclr0 (1'b0),
            .aclr1 (1'b0),
            .address_b (1'b1),
            .addressstall_a (1'b0),
            .addressstall_b (1'b0),
            .byteena_a (1'b1),
            .byteena_b (1'b1),
            .clock1 (1'b1),
            .clocken0 (1'b1),
            .clocken1 (1'b1),
            .clocken2 (1'b1),
            .clocken3 (1'b1),
            .data_a ({(COEF_SIZE){1'b1}}),
            .data_b (1'b1),
            .eccstatus (),
            .q_b (),
            .rden_b (1'b1),
            .wren_a (1'b0),
            .wren_b (1'b0));
defparam
    altsyncram_component.address_aclr_a = "NONE",
    altsyncram_component.clock_enable_input_a = "BYPASS",
    altsyncram_component.clock_enable_output_a = "BYPASS",
    altsyncram_component.init_file = "output_fir_rom.hex",
    altsyncram_component.intended_device_family = "Cyclone IV E",
    altsyncram_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
    altsyncram_component.lpm_type = "altsyncram",
    altsyncram_component.numwords_a = 2**ADDR_SIZE,
    altsyncram_component.operation_mode = "ROM",
    altsyncram_component.outdata_aclr_a = "NONE",
    altsyncram_component.outdata_reg_a = "UNREGISTERED",
    altsyncram_component.widthad_a = ADDR_SIZE,
    altsyncram_component.width_a = COEF_SIZE,
    altsyncram_component.width_byteena_a = 1;
// -----------------------------------------------------------------------------------------------------

endmodule

