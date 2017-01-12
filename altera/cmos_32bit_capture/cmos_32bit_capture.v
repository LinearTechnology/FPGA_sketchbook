`timescale 1ns / 10ps   // Each unit time is 1ns and the time precision is 10ps

/*
    Created by: Mark Thoren
                Noe Quintero
    E-mail:     mthoren@linear.com
                nquintero@linear.com

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
        The purpose of this module is to capture 32-bit, CMOS level data from the
		  This can be used as a starting point for other designs that involve a
		  specific ADC controller.
*/

module cmos_32bit_capture
(
    input           clk,                    // Input OSC_50_B3B, // Original name...
    input           adc_clk_in,
    input   [3:0]   KEY ,                   // Keys are normally high, low when pressed
    output  [3:0]   LED,                    // HIGH to turn ON

	 inout sda,  //PIN_AE29
	 inout scl,  //PIN_AA28

    // ///////// DDR3 /////////
    output  [14:0]  fpga_memory_mem_a,          // fpga_memory.mem_a
    output  [2:0]   fpga_memory_mem_ba,         //            .mem_ba
    output          fpga_memory_mem_ck,         //            .mem_ck
    output          fpga_memory_mem_ck_n,       //            .mem_ck_n
    output          fpga_memory_mem_cke,        //            .mem_cke
    output          fpga_memory_mem_cs_n,       //            .mem_cs_n
    output  [3:0]   fpga_memory_mem_dm,         //            .mem_dm
    output          fpga_memory_mem_ras_n,      //            .mem_ras_n
    output          fpga_memory_mem_cas_n,      //            .mem_cas_n
    output          fpga_memory_mem_we_n,       //            .mem_we_n
    output          fpga_memory_mem_reset_n,    //            .mem_reset_n
    inout   [31:0]  fpga_memory_mem_dq,         //            .mem_dq
    inout   [3:0]   fpga_memory_mem_dqs,        //            .mem_dqs
    inout   [3:0]   fpga_memory_mem_dqs_n,      //            .mem_dqs_n
    output          fpga_memory_mem_odt,        //            .mem_odt
    input           oct_rzqin,                  //         oct.rzqin

    // ///////// HPS /////////
    output  [14:0]  hps_memory_mem_a,
    output  [2:0]   hps_memory_mem_ba,
    output          hps_memory_mem_ck,
    output          hps_memory_mem_ck_n,
    output          hps_memory_mem_cke,
    output          hps_memory_mem_cs_n,
    output          hps_memory_mem_ras_n,
    output          hps_memory_mem_cas_n,
    output          hps_memory_mem_we_n,
    output          hps_memory_mem_reset_n,
    inout   [31:0]  hps_memory_mem_dq,
    inout   [4:0]   hps_memory_mem_dqs,
    inout   [4:0]   hps_memory_mem_dqs_n,
    output          hps_memory_mem_odt,
    output  [4:0]   hps_memory_mem_dm,
    input           hps_memory_oct_rzqin,

	 
	 input [31:0]     adc_data, // 32-bit CMOS data bus

    output          linduino_cs,
    output          linduino_sck,
    output          linduino_mosi,
    input           linduino_miso,

    output          gpo0, // HSMC LVDS RX_p15 (FPGA pin F13)
    output          gpo1  // HSMC LVDS RX_p14 (FPGA pin H14)
);

    // *********************************************************
    // Parameters

    parameter       FPGA_TYPE = 16'h0001; // FPGA project type identification. Accessible from register map.
    parameter       FPGA_REV = 16'h0104;  // FPGA revision (also accessible from register.)
	 // Revision History
	 // 0101: Initial release
	 // 0102: Add CIC filter, edge control via a signal from blob rather than a different MUX input
    // 0103: Add I2C port
	 // 0104: Port cleanup, constraint cleanup

    // *********************************************************
    // Internal Signal Declaration

    wire            reset;
    wire    [31:0]  mem_ctrl_addr;
    wire            mem_ctrl_go;
    wire    [31:0]  mem_ctrl_data;
    wire            mem_ctrl_ready;

    // Wires to/from Qsys blob
    wire    [31:0]  std_ctrl_wire;
    wire    [15:0]  system_clocks_per_sample;
    wire    [29:0]  num_samples;
    wire    [31:0]  tuning_word;
    wire    [31:0]  stop_address;
    wire    [31:0]  datapath_control;

    wire            start;
    wire            data_ready;
	 reg     [31:0]  adc_data_reg_posedge; // Data captured on positive clock edge
	 reg     [31:0]  adc_data_reg_negedge; // Data captured on negative clock edge
	 reg     [31:0]  adc_data_filtered;    // Filtered data from CIC filter
	 reg     [31:0]  adc_data_reg;         // Selected from posedge, negedge registered data
    wire    [3:0]   LEDwire;
    wire    [13:0]  n;  // For LTC2378-24, number of samples to average
    wire    [19:0]  control_sys_output;
    wire            adcA_done;
    wire            adc_go; // Trigger to ADC controller
    wire    [1:0]   dac_a_select;
    wire    [1:0]   dac_b_select;
    wire    [1:0]   lut_addr_select;
    wire            en_trig;
    wire            delayed_trig;
    reg             old_trig;
    wire            trig_pulse;
    wire    [19:0]  setpoint;
    wire    [15:0]  pid_output;
    wire            pid_done;
    wire            adc_done;
    wire            reset_n;
    wire    [53:0]  filt_data_u1;
    wire    [53:0]  filt_data_u2;
//    wire            valid_filt_u1;
//    wire            valid_filt_u2;
    wire            overflow;
    wire            wrfull;
    wire            wrreq;
    wire            rdempty;
    wire            rdreq;
    wire    [31:0]  formatter_output;
    wire    [511:0] formatter_input;
    wire            formatter_valid;
    wire    [63:0]  nyquist_data;
    wire            wrfull_nyq;
    wire            wrreq_nyq;
    wire    [31:0]  formatter_nyq_output;
    wire            formatter_nyq_valid;
    reg     [29:0]  num_calculated;
    wire    [31:0]  counter_pattern;
    wire    [2:0]   fifo_data_select; // Multiplexer control signal
    wire            mem_ctrl_go_muxout;
    wire            adc_fifo_valid;
    wire            adc_fifo_rdreq;
    wire            adc_fifo_wrreq;
    wire            adc_fifo_ready;
    wire            adc_fifo_empty;
    wire            adc_fifo_full;
    wire    [31:0]  adc_fifo_data;
    wire            data_valid;
    wire    [9:0]   cfg;
    reg     [23:0]  counter;
    wire            force_trig_nosync;
    reg             force_trig, ft1, ft2;
    wire            lut_count_carry;
    wire            adcB_done;
    wire            rdreq_nyq;
    wire            rdempty_nyq;
    wire            adc_error_u1;
    wire            adc_error_u2;
    wire            adc_clk;
    wire            adc_clk_shift;
    wire            pll_lock;
    wire            lut_addr_div_cout;
    wire            spi_miso;
    wire            spi_mosi;
    wire            spi_sck;
    wire    [15:0]  lut_addr_div;
	 wire	           pos_edge_capture;

    // *********************************************************
    assign LED[3:0] = LEDwire[3:0];
    assign reset = !KEY[0];
    assign reset_n = ~reset;
//    assign overflow = wrfull | wrfull_nyq;
	 assign adc_clk = adc_clk_in; // Assign clock to the one and only ADC clock

	overflow_det overflow_detector_1
	(
		.q(overflow),      // status - asserted means overflow occurred after
		.qbar(),           // the most recent trigger
		.r(trig_pulse),    // Trigger rising edge resets
		.s(adc_fifo_full), // Any assertion of fifo full signal asserts
		.clk(adc_clk)
	);

    assign adc_clk_out = adc_clk_in;
    assign adc_clk_nshift_out = adc_clk;
//    assign adc_clk_shift_out = adc_clk_shift;

    reg [23:0] heartbeat; // Heartbeat blinky
    assign LEDwire[3] = heartbeat[18];
    assign LEDwire[2] = overflow;
	 assign LEDwire[1] = cic_valid;

    always @ (posedge adc_clk)
        begin
            heartbeat <= heartbeat + 24'b1;
        end

// Register ADC data... both posedge and negedge versions...
    always @ (negedge adc_clk)
        begin
            adc_data_reg_negedge <= adc_data;
        end
    always @ (posedge adc_clk)
        begin
            adc_data_reg_posedge <= adc_data;
        end
		
    always @ (posedge adc_clk)
        begin
		      if (pos_edge_capture == 1'b1)
				adc_data_reg <= adc_data_reg_posedge;
				else
            adc_data_reg <= adc_data_reg_negedge;
        end		
		  

    // *********************************************************
    // Create single trigger pulse from force_trig's posedge
    // Essentially an edge detector
    assign trig_pulse = force_trig & ~old_trig;
    always @ (posedge adc_clk)
        begin
            old_trig <= force_trig;
        end




    // *********************************************************
    // Sample rate generator
    sample_rate_controller sample_rate_controller_inst
    (
        .clk            (adc_clk),
        .reset_n        (reset_n),
        .en             (1'b1),
        .sample_rate    (system_clocks_per_sample),
        .go             ()
    );

assign adc_go = 1'b1; // For CMOS capture, assume we're always a GO!	 
	 
	 
// Variable CIC filter capturing the UPPER 18-bits of the input data.
wire [7:0] rate;
wire cic_valid;
	cic_variable_filter cic_variable_filter_inst (
		.clk       (adc_clk),       //     clock.clk
		.reset_n   (1'b1),   //     reset.reset_n // Tie high. Data will need to be flushed after change of rate parameter
		.in_error  (1'b0),  //  av_st_in.error
		.in_valid  (1'b1),  //          .valid
		.in_ready  (),  //          .ready
		.in_data   (adc_data_reg[17:0]),   //          .in_data
		.out_data  (adc_data_filtered),  // av_st_out.out_data
		.out_error (), //          .error
		.out_valid (cic_valid), //          .valid
		.out_ready (1'b1), //          .ready // Assume sink always ready for data
		.rate      (rate)       //      rate.conduit
	);

	upcount_32	upcount_32_inst
	(
			.clock ( adc_clk ),
			.cnt_en ( adc_go ),
			.data ( 32'b0 ),
			.sclr ( 1'b0 ),
			.sload ( 1'b0 ),
			.cout (  ),
			.q (counter_pattern)
		);
	 
    // *********************************************************
    // This multiplexer is right in front of the clock-crossing FIFO.
    // Data inputs consist of the 32 bit data concatenated with the Valid
    // signal. KEEP VALID AT THE LSB SIDE SO IT IS CONSIDERED FIRST!!!
    mux_8to1_32stream mux_8to1_32stream_inst
    (
        .clock  (adc_clk),
        .data0x ({adc_data_reg, 1'b1 & delayed_trig}),               // raw ADC data
        .data1x ({adc_data_filtered[24:0], 7'b0, cic_valid & delayed_trig}),   // filtered ADC data
        .data2x ({32'd2222, 1'b1 & delayed_trig}),
        .data3x ({32'd3333, 1'b1 & delayed_trig}),
        .data4x ({counter_pattern, adc_go & delayed_trig}), // Counter test pattern
        .data5x ({32'd5555, 1'b1 & delayed_trig}),
        .data6x ({32'd6666, 1'b1 & delayed_trig}),
        .data7x ({32'hDEAD_BEEF, adc_go}),              // Super simple test pattern
        .sel    (fifo_data_select),
        .result ({mem_ctrl_data, mem_ctrl_go_muxout})
    );

    assign adc_fifo_rdreq = (!adc_fifo_empty & adc_fifo_ready) ? 1'b1 : 1'b0;
    assign adc_fifo_wrreq =  mem_ctrl_go_muxout & (!adc_fifo_full);
    assign adc_fifo_valid = adc_fifo_rdreq;

    // *********************************************************
    // DC FIFO for going from ADC clock domain to systems 50MHz clock domain
    // Note: show ahead mode
    ADC_fifo adc_fifo
    (
        .aclr       (reset),
        .data       (mem_ctrl_data),
        .rdclk      (clk),
        .rdreq      (adc_fifo_rdreq),
        .wrclk      (adc_clk),
        .wrreq      (adc_fifo_wrreq),
        .q          (adc_fifo_data),
        .rdempty    (adc_fifo_empty),
        .wrfull     (adc_fifo_full)     // If this ever asserts, something went wrong!
    );

    // *********************************************************
    // Synchronizer for trigger pulse
    always @ (posedge adc_clk)
        begin
            ft1<= force_trig_nosync;
            ft2<= ft1;
            force_trig <= ft2;
        end

    // *********************************************************
    // Used to switch data_valid_signals
    mux_8_to_1  data_valid_mux
    (
        .data0  (1'b1), // Always valid in CMOS parallel capture mode...
        .data1  (cic_valid), // When capturing filtered data
        .data2  (1'b1),
        .data3  (1'b1),
        .data4  (1'b1),
        .data5  (1'b1),
        .data6  (1'b1),
        .data7  (1'b1),
        .sel    (fifo_data_select),
        .result (data_valid)
    );

    // *********************************************************
    // The trigger block ensures a complete read
    trigger_block trigger_block_inst
    (
        .clk                    (adc_clk),
        .reset_n                (reset_n),

        .data_valid             (data_valid),
        .trig_in                (~KEY[1]),
        .force_trig             (force_trig), // Pushbutton trigger

        .pre_trig_counter       (32'd128),
        .pre_trig_counter_value (),
        .post_trig_counter      (num_samples),

        .en_trig                (start),
        .delayed_trig           (delayed_trig)
    );

    // *********************************************************
    // SPI logic
    assign spi_miso = (linduino_miso & (~linduino_cs));
    assign linduino_mosi = spi_mosi;
    assign linduino_sck = spi_sck;

    // *********************************************************
    // Initialize qsys generated system
    LTQsys_blob2 LTQsys_blob2_inst
    (
        .clk_clk                (clk),                               //         clk.clk
        .reset_reset_n          (!reset),                            //       reset.reset_n
        .hps_memory_mem_a       (hps_memory_mem_a),                  //  hps_memory.mem_a
        .hps_memory_mem_ba      (hps_memory_mem_ba),                 //            .mem_ba
        .hps_memory_mem_ck      (hps_memory_mem_ck),                 //            .mem_ck
        .hps_memory_mem_ck_n    (hps_memory_mem_ck_n),               //            .mem_ck_n
        .hps_memory_mem_cke     (hps_memory_mem_cke),                //            .mem_cke
        .hps_memory_mem_cs_n    (hps_memory_mem_cs_n),               //            .mem_cs_n
        .hps_memory_mem_ras_n   (hps_memory_mem_ras_n),              //            .mem_ras_n
        .hps_memory_mem_cas_n   (hps_memory_mem_cas_n),              //            .mem_cas_n
        .hps_memory_mem_we_n    (hps_memory_mem_we_n),               //            .mem_we_n
        .hps_memory_mem_reset_n (hps_memory_mem_reset_n),            //            .mem_reset_n
        .hps_memory_mem_dq      (hps_memory_mem_dq),                 //            .mem_dq
        .hps_memory_mem_dqs     (hps_memory_mem_dqs),                //            .mem_dqs
        .hps_memory_mem_dqs_n   (hps_memory_mem_dqs_n),              //            .mem_dqs_n
        .hps_memory_mem_odt     (hps_memory_mem_odt),                //            .mem_odt
        .hps_memory_mem_dm      (hps_memory_mem_dm),                 //            .mem_dm
        .hps_memory_oct_rzqin   (hps_memory_oct_rzqin),              //            .oct_rzqin
        .fpga_memory_mem_a      (fpga_memory_mem_a),                 // fpga_memory.mem_a
        .fpga_memory_mem_ba     (fpga_memory_mem_ba),                //            .mem_ba
        .fpga_memory_mem_ck     (fpga_memory_mem_ck),                //            .mem_ck
        .fpga_memory_mem_ck_n   (fpga_memory_mem_ck_n),              //            .mem_ck_n
        .fpga_memory_mem_cke    (fpga_memory_mem_cke),               //            .mem_cke
        .fpga_memory_mem_cs_n   (fpga_memory_mem_cs_n),              //            .mem_cs_n
        .fpga_memory_mem_dm     (fpga_memory_mem_dm),                //            .mem_dm
        .fpga_memory_mem_ras_n  (fpga_memory_mem_ras_n),             //            .mem_ras_n
        .fpga_memory_mem_cas_n  (fpga_memory_mem_cas_n),             //            .mem_cas_n
        .fpga_memory_mem_we_n   (fpga_memory_mem_we_n),              //            .mem_we_n
        .fpga_memory_mem_reset_n(fpga_memory_mem_reset_n),           //            .mem_reset_n
        .fpga_memory_mem_dq     (fpga_memory_mem_dq),                //            .mem_dq
        .fpga_memory_mem_dqs    (fpga_memory_mem_dqs),               //            .mem_dqs
        .fpga_memory_mem_dqs_n  (fpga_memory_mem_dqs_n),             //            .mem_dqs_n
        .fpga_memory_mem_odt    (fpga_memory_mem_odt),               //            .mem_odt
        .oct_rzqin              (oct_rzqin),                         //         oct.rzqin
        .mem_pll_pll_locked     (),                                  //            .pll_locked
        // User registers  .output_std_ctrl_export
        .rev_type_id_export     ({FPGA_REV, FPGA_TYPE}),             // rev_type_id.export
        .output_std_ctrl_export            ({26'b0, lut_write_enable, pos_edge_capture , gpo1, gpo0, force_trig_nosync, start }),            //          output_std_ctrl.export
        .input_std_stat_export             ({29'b0, overflow,1'b0, delayed_trig}),             // input_std_stat.export, Extra zero is a placeholder for PLL lock signal
        .output_0x40_export                ({2'b0, n, cfg, 5'b0, LEDwire[0]}),                //              output_0x40.export
        .output_0x50_export                (num_samples),                //              output_0x50.export
        .output_0x60_export                ({24'b0, rate}),                //              output_0x60.export
        .output_0x70_export                (),                //              output_0x70.export
        .output_0x80_export                (),                //              output_0x80.export
        .output_0x90_export                (),                //              output_0x90.export
        .output_0xa0_export                (),                //              output_0xa0.export
        .output_0xb0_export                (),                //              output_0xb0.export
        .output_0xc0_export                ({16'b0,system_clocks_per_sample}),                //              output_0xc0.export
        .output_0xd0_export                ({28'b0,  1'b0, fifo_data_select[2:0]}), // Multiplexer input selection
        .output_0xe0_export                (),
        .output_0xf0_export                (),  // DAC sinewave tuning word
        .input_0x100_export                ({2'b0, stop_address[29:0]}), // After capture, this is where to start reading
        // SPI port for configuring various things
        .spi_0_external_MISO               (spi_miso),               //           spi_0_external.MISO
        .spi_0_external_MOSI               (spi_mosi),               //                         .MOSI
        .spi_0_external_SCLK               (spi_sck),               //                         .SCLK
        .spi_0_external_SS_n               ({6'bz, linduino_cs, ltc6954_cs}),                //                         .SS_n
        .tie_me_off_data                    (8'bz),                    //                   tie_me_off.data
        .tie_me_off_valid                   (1'bz),                   //                             .valid
        .tie_me_off_ready                   (1'b0),                   //                             .ready
        .ltscope_data_input_data            (adc_fifo_data),            //           ltscope_data_input.data
        .ltscope_data_input_valid           (adc_fifo_valid),           //                             .valid
        .ltscope_data_input_ready           (adc_fifo_ready),           //                             .ready
        .ltscope_controller_ring_buff_go    (start),    //           ltscope_controller.ring_buff_go
        .ltscope_controller_ring_buff_addr  (stop_address),  //                             .ring_buff_addr
        .ltscope_controller_read_go         (1'b0),         //                             .read_go
        .ltscope_controller_read_start_addr (32'b0), //                             .read_start_addr
        .ltscope_controller_read_length     (32'b0),     //                             .read_length
        .ltscope_controller_read_done       (1'bz),        //                             .read_done
		.i2c_outputs_export                 ({30'bz, scl_out, sda_out}),                 //        i2c_outputs.export
        .i2c_inputs_export                  ({30'b0, scl_in,  sda_in}) 
          );

wire sda_in, sda_out, scl_in, scl_out;
			 
tristate_iobuf	tristate_iobuf_sda (
	.datain ( 1'b0 ), // Data INTO the IO primitive... zero to emulate open-drain
	.oe ( ~sda_out ), // LOW to enable!!
	.dataio ( sda ), // The actual SDA pin
	.dataout ( sda_in ) // The state of the SDA signal
	);
tristate_iobuf	tristate_iobuf_scl (
	.datain ( 1'b0 ), // Data INTO the IO primitive... zero to emulate open-drain
	.oe ( ~scl_out ), // LOW to enable!!
	.dataio ( scl ),// The actual SCL pin
	.dataout ( scl_in ) // The actual state of the SCL signal
	);	


endmodule


//    wire            mem_adcA_nadcB;
//    wire            lut_run_once;
//    wire            lut_write_enable;
//    wire    [15:0]  lut_output;         // Output of DAC lookup table
//    wire    [15:0]  lut_addr_counter;   // Coutnter for sequencing through LUT memory
//    wire    [15:0]  lut_addr;           // Input to lookup table address
//    wire    [15:0]  lut_wraddress;
//    wire    [15:0]  lut_wrdata;
//    wire    [15:0]  nco_sin_out;
//    wire    [15:0]  nco_cos_out;
//    wire    [15:0]  dac_a_data_signed;
//    wire    [15:0]  dac_b_data_signed;
//    reg     [15:0]  dac_a_data_straight;
//    reg     [15:0]  dac_b_data_straight;



//    // *********************************************************
//    // Formatted Data formatter
//
//    // Converts the streaming control signals to the FIFO control signals
//    LT_st_dcfifo_cntr steam_to_fifo_adapter
//    (
//        // Streaming interface
//        .valid  (valid_filt_u1 & delayed_trig),    // Nominally, all valid signals should be the same
//                                                    // Picked the first one for conviniance 
//        // DC FIFO interface
//        .wrfull (wrfull),
//        .wrreq  (wrreq)
//    );

//    // A DC FIFO is used as a width adapter
//    // 512 bits to 32 bits
//    assign  formatter_input =  {32'b0, 32'b0, 32'b0, 32'hDEAD_BEEF, 32'h8BAD_F00D, 32'hB105_F00D, 32'hDEAD_C0DE, 32'hD006_F00D,
//                                32'b0, 32'b0, 32'b0, 32'hDEAD_BEEF, 32'h8BAD_F00D, 32'hB105_F00D, 32'hDEAD_C0DE, 32'hD006_F00D};
//    formatter adc_formatter
//    (
//        .aclr       (reset),
//        .data       (formatter_input),
//        .rdclk      (adc_clk),
//        .rdreq      (rdreq),
//        .wrclk      (adc_clk),
//        .wrreq      (wrreq),
//        .q          (formatter_output),
//        .rdempty    (rdempty),
//        .wrfull     (wrfull)
//    );
//
//    // Converts the FIFO control signals to streaming control signals
//    LT_dcfifo_st_cntr  fifo_to_stream
//    (
//        // DC FIFO interface
//        .rdempty    (rdempty),
//        .rdreq      (rdreq),
//        // Streaming interface
//        .valid      (formatter_valid),
//        .ready      (1'b1)
//    );

//    // *********************************************************
//    // Nyquist data formatter
//
//    // Converts the streaming control signals to the FIFO control signals
//    LT_st_dcfifo_cntr steam_to_fifo_adapter_nyq
//    (
//        // Streaming interface
//        .valid  (adcA_done & delayed_trig), // Nominally, all valid signals should be the same
//                                            // Picked the first one for conviniance 
//        // DC FIFO interface
//        .wrfull (wrfull_nyq),
//        .wrreq  (wrreq_nyq)
//    );

//    // A DC FIFO is used as a width adapter
//    // 64 bits to 32 bits
//    assign nyquist_data = {32'b0, 32'b0};
//    nyq_formatter nyquist_formatter
//    (
//        .aclr       (reset),
//        .data       (nyquist_data),
//        .rdclk      (adc_clk),
//        .rdreq      (rdreq_nyq),
//        .wrclk      (adc_clk),
//        .wrreq      (wrreq_nyq),
//        .q          (formatter_nyq_output),
//        .rdempty    (rdempty_nyq),
//        .wrfull     (wrfull_nyq)
//    );
//
//    // Converts the FIFO control signals to streaming control signals
//    LT_dcfifo_st_cntr fifo_to_stream_nyq
//    (
//        // DC FIFO interface
//        .rdempty    (rdempty_nyq),
//        .rdreq      (rdreq_nyq),
//        // Streaming interface
//        .valid      (formatter_nyq_valid),
//        .ready      (1'b1)
//    );