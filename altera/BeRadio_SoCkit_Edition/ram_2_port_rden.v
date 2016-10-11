// ram_2_port_rden.v
//
// Project: Medium Wave (500 kHz - 1700 kHz) Receiver, SDR Demonstration
// Copyright 2012, Zephyr Engineering, Inc., All Rights Reserved
//
// Description: Generic dual-port RAM with a read enable input. Instantiates
// an Altera altsyncram megafunction but uses input parameters to specify
// the address and data vector widths. Outputs are not registered so there
// is one cycle of read latency.
//
// Written by: Steve Kalandros
//
// Revision 0.1 - July 24, 2012 S.K. Initial release
// -----------------------------------------------------------------------------------------------------

// ---- Module I/O -------------------------------------------------------------------------------------
module ram_2_port_rden
#(
    parameter ADDR_SIZE = 7,                   // Address width
    parameter DATA_SIZE = 16                   // Data width
) (
    input    wire  clk,                        // System clock
    input    wire  wren,                       // Write enable
    input    wire  [ADDR_SIZE-1:0] waddr,      // Write address
    input    wire  [DATA_SIZE-1:0] d,          // Write data
    input    wire  rden,                       // Read enable
    input    wire  [ADDR_SIZE-1:0] raddr,      // Read address
    output   wire  [DATA_SIZE-1:0] q           // Read data
);
// -----------------------------------------------------------------------------------------------------


// ---- Altera RAM Instantiation -----------------------------------------------------------------------
	altsyncram	altsyncram_component (
				.address_a (waddr),
				.clock0 (clk),
				.data_a (d),
				.rden_b (rden),
				.wren_a (wren),
				.address_b (raddr),
				.q_b (q),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_a (1'b1),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b ({(DATA_SIZE){1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_b = "NONE",
		altsyncram_component.address_reg_b = "CLOCK0",
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone IV E",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 2**ADDR_SIZE,
		altsyncram_component.numwords_b = 2**ADDR_SIZE,
		altsyncram_component.operation_mode = "DUAL_PORT",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.rdcontrol_reg_b = "CLOCK0",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.widthad_a = ADDR_SIZE,
		altsyncram_component.widthad_b = ADDR_SIZE,
		altsyncram_component.width_a = DATA_SIZE,
		altsyncram_component.width_b = DATA_SIZE,
		altsyncram_component.width_byteena_a = 1;
// -----------------------------------------------------------------------------------------------------

endmodule

