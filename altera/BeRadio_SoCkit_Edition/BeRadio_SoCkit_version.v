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
//    output          adc_clk_out,            // Raw ADC out
    output          adc_clk_nshift_out,     // PLL clock out 0 deg shift
    output          adc_clk_shift_out,      // PLL clock out -90 deg shift
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

    ////// DACs ////////////
    output  [15:0]  DAC_A,
    output  [15:0]  DAC_B,
	 
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

    parameter       FPGA_TYPE = 16'h0003; // FPGA project type identification. Accessible from register map.
    parameter       FPGA_REV = 16'h0101;  // FPGA revision (also accessible from register.)
	 // Revision History
	 // 0101: Initial release
	 // 0102: Add CIC filter, edge control via a signal from blob rather than a different MUX input

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
//	 reg     [31:0]  adc_data_reg_posedge; // Data captured on positive clock edge
//	 reg     [31:0]  adc_data_reg_negedge; // Data captured on negative clock edge
//	 reg     [31:0]  adc_data_filtered;    // Filtered data from CIC filter
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
//    wire            reset_n;
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

// ----------- Reset -----------------------------------------------------------------------------------
// This circuit holds reset active for approximately 419 ms after power-on or after pushing the
// SoCkit (BeMicro) reset push-button (KEY[0]).
// -----------------------------------------------------------------------------------------------------

assign rst_n = KEY[0];

reg [22:0] rstcount;                   // Reset counter
wire reset_n;                          // internal reset
always @(posedge adc_clk_out or negedge rst_n) begin
    if (!rst_n) begin
        rstcount       <= 23'h0;
    end
    else if (!rstcount[22]) begin
        rstcount <= rstcount + 23'h1;
    end
end

// Internal reset is the MSB of the counter. CHANGED to coming straight from KEY[0]
assign reset_n = KEY[0]; //rstcount[22];
assign reset = reset_n;
//    assign reset_n = ~reset;
//    assign overflow = wrfull | wrfull_nyq;

// -----------------------------------------------------------------------------------------------------


// ---- User Parameters --------------------------------------------------------------------------------
// Specify tuning frequency parameters in kHz.
// -----------------------------------------------------------------------------------------------------
parameter  START_FREQ_KHZ =  550;      // Default frequency at reset or power-up
parameter  FREQ_STEP_KHZ  =   10;      // Frequency increment or decrement step
parameter  LOW_FREQ_KHZ   =  500;      // Lowest allowed frequency (rolls over to top below this)
parameter  HIGH_FREQ_KHZ  = 1700;      // Highest allowed frequency (rolls over to bottom above this)
parameter  BAND3_LIMIT    =  700;      // Upper bound on BeRadio frequency band 3
parameter  BAND2_LIMIT    =  850;      // Upper bound on BeRadio frequency band 2
parameter  BAND1_LIMIT    = 1160;      // Upper bound on BeRadio frequency band 1
parameter  DEBOUNCE_SIZE  =   20;      // Bits in User push-button debounce counter; debounce delay is
                                       // 2^(DEBOUNCE_SIZE-1) / 10 MHz (~52 ms delay for 20 bits)
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

// Function to calculate ceiling of Log base 10 of a value.
function integer clog_b10;
    input integer value;
    integer tmp;
    begin
        tmp = 10;
        for (clog_b10 = 1; value > tmp; clog_b10 = clog_b10 + 1) tmp = 10*tmp;
    end
endfunction

// Function to select capacitors on the BeRadio based on frequency band.
function [1:0] band_sel;
    input [FREQ_SIZE-1:0] freq;
    begin
             if (freq < BAND3_LIMIT) band_sel = 2'b11;
        else if (freq < BAND2_LIMIT) band_sel = 2'b10;
        else if (freq < BAND1_LIMIT) band_sel = 2'b01;
        else                         band_sel = 2'b00;
    end
endfunction
// -----------------------------------------------------------------------------------------------------


// ---- I/O Connector Signal Renaming ------------------------------------------------------------------
// Rename expansion connector pins. The convention here is to use BeMicro schematic names in the pin
// list and logical names within the design. The logical names may also match BeRadio schematic names.
// -----------------------------------------------------------------------------------------------------

// ADC status inputs
wire adc_of;                           // ADC overflow indicator
assign adc_of = adc_data[18];//P4; // Note mapping on DC2512, OF signal to D18

// ADC data inputs
wire signed [11:0] adc_d;              // ADC input data
assign adc_d = adc_data [13:2]; //{P5,P6,P7,P8,P9,P10,P11,P12,P13,P14,P15,P16}; // Remapped to DC782 + DC2512

// Clock input
wire adc_clk_out;                      // ADC clock source from BeRadio
assign adc_clk_out = ~adc_clk_in;


// DAC outputs
//assign P24 = dac_clr_l;//P24 = dac_clr_l;
assign linduino_mosi = dac_din;//P25 = dac_din;
assign linduino_sck = dac_sclk;//P26 = dac_sclk;
assign linduino_cs = dac_cs_l;//P27 = dac_cs_l;




//---- Static control signal assignments ---------------------------------------------------------------
// --None--
// -----------------------------------------------------------------------------------------------------


// ---- Clocks -----------------------------------------------------------------------------------------
//wire adc_clk_in;                       // 10 MHz clock input on BeRadio



// ------- Heartbeat LED -------------------------------------------------------------------------------
// Heartbeat at 0.596 Hz (10 MHz clock divided by 2^24 for a 24 bit counter)
// -----------------------------------------------------------------------------------------------------
reg [23:0] hbcount;                    // Heartbeat counter
wire hb_led;                           // Heartbeat LED output

always @(posedge adc_clk_out or negedge reset_n) begin
    if (!reset_n) begin
        hbcount <= 24'h0;
    end
    else begin
        hbcount <= hbcount + 24'h1;
    end
end

assign hb_led = hbcount[23];
// -----------------------------------------------------------------------------------------------------


// ---- ADC input data ---------------------------------------------------------------------------------
reg signed [11:0] rx_data;             // Registered data from ADC
reg [19:0] of_count;                   // Overflow delay counter
wire of_led;                           // ADC overflow LED output

// Register the ADC data at the pins.
always @(posedge adc_clk_out or negedge reset_n) begin
    if (!reset_n) begin
        rx_data     <= 12'h0;
    end
    else begin
        rx_data     <= adc_d;
    end
end

// When an ADC overflow is detected, set an LED for about 105 ms.
always @(posedge adc_clk_out or negedge reset_n) begin
    if (!reset_n) begin
        of_count     <= 20'h0;
    end
    else if (adc_of) begin
        of_count     <= 20'hF_FFFF;
    end
    else if (of_count[19]) begin
        of_count     <= of_count - 20'b1;
    end
end

assign of_led = of_count[19];
// -----------------------------------------------------------------------------------------------------


// ---- Complex Mixer ----------------------------------------------------------------------------------
// Mix the received signal with the output of a local oscillator. 
// The oscillator is tunable using the user push-button on the
// BeMicro.
// -----------------------------------------------------------------------------------------------------
localparam FREQ_SIZE = clog_b2(HIGH_FREQ_KHZ+1);   // Bits to encode highest frequency
wire pb_strb;                                      // Push-button strobe
wire freq_strb;                                    // Frequency valid strobe
wire [FREQ_SIZE-1:0] freq;                         // Current frequency
wire [31:0] phi_inc;                               // Phase increment for local oscillator
reg [1:0] band;                                    // BeRadio frequency band select
wire signed [15:0] fcos;                           // In-phase component of local oscillator
wire signed [15:0] fsin;                           // Quadrature component of local oscillator
reg signed [27:0] i_data;                          // In-phase component of baseband data
reg signed [27:0] q_data;                          // Quadrature component of baseband data


wire [31:0] nco_phi_inc;				// Frequency from the blob.

// Instantiate Numerically Controlled Oscillator (NCO) to implement local oscillator.
z_nco z_nco_inst (
    .phase_inc (nco_phi_inc),
    .clk       (adc_clk_out),
    .reset_n   (reset_n),
    .fsin      (fsin),
    .fcos      (fcos)
);

//NCOMega z_nco_inst (
//		.phi_inc_i(nco_phi_inc),
//		.clk(adc_clk_out),
//		.reset_n(reset_n),
//		.clken(reset_n),
//		.fsin_o(fsin),
//		.fcos_o(fcos),
//		.out_valid()
//);

// Shift received signal to zero by multiplying (mixing) with the local oscillator.
always @(posedge adc_clk_out or negedge reset_n) begin
    if (!reset_n) begin
        i_data <= 28'h0;
        q_data <= 28'h0;
    end
    else begin
        i_data <= fcos * rx_data;
        q_data <= fsin * rx_data;
    end
end
// -----------------------------------------------------------------------------------------------------


// ---- Decimation and Filtering -----------------------------------------------------------------------
// Reduce sample rate from 10 Msps to 50 ksps using CIC filters. Use two CIC
// filters: one with fewer stages but a higher decimation rate to get the
// sample rate down and one with a lower decimation rate but more stages to
// improve performance. This arrangement yields better performance with fewer
// resources for the same decimation rate because the resource usage scales
// with the square of the number of stages.
//
// WARNING: The FIR filter used below requires 133 clock cycles between input
// samples to generate each output sample; thus, the overall decimation rate
// from the CIC filters must be at least 133 for proper operation. To reduce
// the decimation rate below 133, the FIR filter will need to be modified.
// -----------------------------------------------------------------------------------------------------
wire signed [21:0] cic_in_i;           // Saturated/rounded in-phase input data to CICs
wire signed [21:0] cic_in_q;           // Saturated/rounded quadrature input data to CICs
wire cic1_strb;                        // Output data valid strobe from first CIC
wire signed [22:0] cic1_i;             // In-phase component of first CIC output (decimate by 25)
wire signed [22:0] cic1_q;             // Quadrature component of first CIC output (decimate by 25)
wire cic2_strb;                        // Output data valid strobe from second CIC
wire signed [23:0] cic2_i;             // In-phase component of second CIC output (decimate by 8)
wire signed [23:0] cic2_q;             // Quadrature component of second CIC output (decimate by 8)

// Saturate and round the CIC inputs to get from 28 bits down to 22.
sat_rnd #(
    .IN_SIZE       (28),
    .TRUNC_SIZE    (5),
    .OUT_SIZE      (22)
) sat_rnd_cic_inst (
    .d1            (i_data),
    .d2            (q_data),
    .q1            (cic_in_i),
    .q2            (cic_in_q)
);

// First CIC filter (5 stages) decimates by 25.
z_cic #(
    .IN_SIZE   (22),
    .OUT_SIZE  (23),
    .N_STAGES  (5),
    .DEC_RATE  (25)
) z_cic1_inst (
    .clk       (adc_clk_out),
    .reset_n   (reset_n),
    .instrobe  (1'b1),
    .in1_data  (cic_in_i),
    .in2_data  (cic_in_q),
    .outstrobe (cic1_strb),
    .out1_data (cic1_i),
    .out2_data (cic1_q)
);

// Second CIC filter (14 stages) decimates by 8.
z_cic #(
    .IN_SIZE   (23),
    .OUT_SIZE  (24),
    .N_STAGES  (14),
    .DEC_RATE  (8)
) z_cic2_inst (
    .clk       (adc_clk_out),
    .reset_n   (reset_n),
    .instrobe  (cic1_strb),
    .in1_data  (cic1_i),
    .in2_data  (cic1_q),
    .outstrobe (cic2_strb),
    .out1_data (cic2_i),
    .out2_data (cic2_q)
);
// -----------------------------------------------------------------------------------------------------

wire [15:0] fir_in_i;
wire [15:0] fir_in_q;

// Saturate and round the FIR inputs to get from 24 bits down to 16.
sat_rnd #(
    .IN_SIZE       (24),
    .TRUNC_SIZE    (4),
    .OUT_SIZE      (16)
) sat_rnd_fir_inst (
    .d1            (cic2_i),
    .d2            (cic2_q),
    .q1            (fir_in_i),
    .q2            (fir_in_q)
);

// Use a low-pass, 128-tap FIR filter with a 5 kHz bandwidth to eliminate
// out-of-band noise. The sample rate here is 50 ksps after the CIC filters.
// The FIR filter is a dual-channel filter but only one channel is used
// because the data are real valued, not complex, after the AM demodulation.
//
// The FIR filter requires N+5 clock cycles to calculate each output sample
// for every input sample. Since there are 128 taps in this implementation, it
// takes 133 cycles. There are 200 clock cycles between input samples at the
// current decimation rate; if the CIC filter decimation rate is reduced below
// 133, then the number of FIR filter taps will need to be reduced or the
// filter will need to be redesigned in order to complete the calculations in
// the given time.
//
// Optimization opportunity: Adjust the FIR coefficients to a.) compensate for
// the CIC filter response roll-off within the pass band and b.) filter out
// the DC component introduced by the amplitude calculation in order to make
// better use of the dynamic range of the DAC.
output_fir #(
    .DATA_SIZE     (16),
    .COEF_SIZE     (16)
) output_fir_inst (
    .clk           (adc_clk_out),
    .reset_n       (reset_n),
    .strobe_in     (cic2_strb), //(am_strb),
    .ch1_in        (fir_in_i),//(am_data),
    .ch2_in        (fir_in_q),//(16'h0000),
    .strobe_out    (am_strb), // Doesn't need to change - 
    .ch1_out       (am_in_i),//(audio_data),
    .ch2_out       (am_in_q)
);
// -----------------------------------------------------------------------------------------------------

// ------- AM demodulator ------------------------------------------------------------------------------
// Demodulate the AM audio signal.
// -----------------------------------------------------------------------------------------------------
wire signed [15:0] am_in_i;            // Saturated/rounded in-phase component of decimated output
wire signed [15:0] am_in_q;            // Saturated/rounded quadrature component of decimated output
wire am_strb;                          // Demodulated AM data valid strobe
wire signed [15:0] am_data;            // Demodulated AM data
wire signed [15:0] audio_data;         // Filtered audio data
wire audio_strb;                       // Filtered audio data valid strobe

// Saturate and round the CIC outputs to get from 24 bits down to 16.
sat_rnd #(
    .IN_SIZE       (24),
    .TRUNC_SIZE    (4),
    .OUT_SIZE      (16)
) sat_rnd_am_inst (
    .d1            (am_in_i), //Try getting rid of FIR, just for fun...
    .d2            (am_in_q),
    .q1            (am_in_sr_i),//)(am_in_i),
    .q2            (am_in_sr_q)
);

// Instantiate the AM demodulator, which calculates the amplitude of the
// received samples (i.e. data_out = sqrt(i_in^2 + q_in^2) ).
am_demod #(
    .DATA_SIZE     (16)
) am_demod_inst (
    .clk           (adc_clk_out),
    .reset_n       (reset_n),
    .strobe_in     (am_strb),
    .i_in          (fir_in_i), //(am_in_sr_i),
    .q_in          (fir_in_q), //(am_in_sr_q),
    .strobe_out    (audio_strb),
    .data_out      (audio_data)
);



// ---- DAC SPI Interface ------------------------------------------------------------------------------
// Load the audio data into the shift register and shift out the SPI bus to
// the DAC.
// -----------------------------------------------------------------------------------------------------
wire [15:0] unipolar_data;             // Audio data in unipolar instead of signed format
wire dac_clr_l;                        // DAC clear (active-low)
wire dac_cs_l;                         // DAC SPI interface chip select (active-low)
wire dac_sclk;                         // DAC SPI clock
wire dac_din;                          // DAC SPI data

// Invert the MSB of the audio data to convert from 2's complement data to unipolar.
// Note that this is equivalent to adding 0x8000 to shift the data values from a range
// of signed values from a minimum of 0x8000 to a maximum of 0x7FFF to an unsigned range
// of minimum of 0x0000 to a maximum of 0xFFFF.  
assign unipolar_data = {~audio_data[15],audio_data[14:0]};

// When connected, NIOS will control audio level
wire signed [23:0] scaled_audio;			// Audio data after scaling by audio_gain from NIOS
reg unsigned [15:0] audio_out;			// Audio data out to the BeRadio SPI audio DAC

assign scaled_audio = audio_data * (audio_gain + 8'b1);

// If nios_phi_inc is zero, select unscaled audio (unipolar_data), else select scaled audio (scaled_audio).
// The nios_phi_inc value is non-zero whenever NIOS takes control of the receiver.
always @(posedge adc_clk_out or negedge reset_n) begin
//	if (!reset_n) begin
//		audio_out <= unipolar_data;
//   end
//   else begin
//		if(1 == 1) begin // if(nios_phi_inc == 0) begin
//			audio_out <= unipolar_data;
//		end
//		else begin
			// bits selected empiricaly to trade off output audio volume versus distortion
			audio_out <= unipolar_data; // Try with No scaling
			//audio_out <= {~scaled_audio[23],scaled_audio[20:6]};
//		end
//   end
end

// Instantiate the SPI interface component.
spi_if #(
    .DATA_SIZE (16)
) spi_if_inst (
    .clk       (adc_clk_out),
    .reset_n   (reset_n),
    .strobe_in (audio_strb),
    .data_in   (audio_out),
    .spi_clr_l (dac_clr_l),
    .spi_cs_l  (dac_cs_l),
    .spi_sclk  (dac_sclk),
    .spi_data  (dac_din)
);
// -----------------------------------------------------------------------------------------------------


// ---- Frequency LEDs ---------------------------------------------------------------------------------
// Convert the frequency into Binary-Coded Decimal (BCD) when it changes.
// Display the current frequency, one BCD digit at a time, on 4 of the LEDs.
// A sub-component waits for the next heartbeat LED flash after the frequency
// has been converted to BCD; it then shifts the BCD digits out to the LEDs,
// one digit per heartbeat. Start and termination characters (0xF) are flashed
// before and after the frequency for half the heartbeat period.
// -----------------------------------------------------------------------------------------------------
localparam BCD_DIGITS  = clog_b10(HIGH_FREQ_KHZ+1); 	// BCD digits to encode highest frequency
localparam BCD_SIZE    = 4*BCD_DIGITS;                // BCD bits to encode highest frequency
localparam LED_SR_SIZE = BCD_SIZE + 4;                // Bits in LED shift register
wire bcd_strb;                         					// BCD frequency value valid strobe
wire [BCD_SIZE-1:0] freq_bcd;          					// Current frequency in BCD
wire [3:0] leds_out;                   					// BCD LED outputs

// Instantiate the BCD conversion component.
binary_to_bcd #(
    .IN_BITS       (FREQ_SIZE),
    .OUT_DIGITS    (BCD_DIGITS)
) binary_to_bcd_inst (
    .clk           (adc_clk_out),
    .reset_n       (reset_n),
    .strobe_in     (freq_strb),
    .data_in       (freq),
    .strobe_out    (bcd_strb),
    .data_out      (freq_bcd)
);

// Instantiate the LED digit display component.
digit_display #(
    .NUM_DIGITS    (BCD_DIGITS)
) digit_display_inst (
    .clk           (adc_clk_out),
    .reset_n       (reset_n),
    .sync          (hb_led),
    .abort         (pb_strb),
    .strobe_in     (bcd_strb),
    .data_in       (freq_bcd),
    .leds_out      (leds_out)
);
// ---- NIOS -------------------------------------------------------------------------------------------
// The NIOS processor controls the audio gain and frequency via commands from the 
// BeMicroSDK USB port. The antenna capacitor selection is also made by NIOS, based
// on the frequency requested.
// 
// -----------------------------------------------------------------------------------------------------
// NIOS control ports
wire signed [7:0] audio_gain;							// audio volume control
//wire [31:0] nios_phi_inc;								// phase increment to control tuning frequency
wire [7:0] nios_filter_sel;							    // filter selection 
wire [1:0]	nios_band;									// only 2 bits of nios pio port used here
assign nios_band = nios_filter_sel[1:0];










///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////


	overflow_det overflow_detector_1
	(
		.q(overflow),      // status - asserted means overflow occurred after
		.qbar(),           // the most recent trigger
		.r(trig_pulse),    // Trigger rising edge resets
		.s(adc_fifo_full), // Any assertion of fifo full signal asserts
		.clk(adc_clk)
	);

//    assign adc_clk_out = adc_clk_in;
    assign adc_clk_nshift_out = adc_clk;
//    assign adc_clk_shift_out = adc_clk_shift;

    assign LEDwire[3] = hb_led;
    assign LEDwire[2] = overflow;
	assign LEDwire[1] = cic_valid;

// Register ADC data... both posedge and negedge versions...

    always @ (posedge adc_clk)
        begin
            adc_data_reg <= adc_data;
        end
	
		  
	 
    assign DAC_A = 16'b0; // Tie off.
    assign DAC_B = 16'b0;

	 assign adc_clk = adc_clk_in; // Assign clock to the one and only ADC clock

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
        .data0x ({20'b0, rx_data, 1'b1 & delayed_trig}),               // RX data that is sent to the demodulator
        .data1x ({32'd1111, 1'b1 & delayed_trig}),   // filtered ADC data
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
        .output_0x60_export                ({24'b0, audio_gain}),                //              output_0x60.export
        .output_0x70_export                (),                //              output_0x70.export
        .output_0x80_export                (),                //              output_0x80.export
        .output_0x90_export                (),                //              output_0x90.export
        .output_0xa0_export                (),                //              output_0xa0.export
        .output_0xb0_export                (),                //              output_0xb0.export
        .output_0xc0_export                ({16'b0,system_clocks_per_sample}),                //              output_0xc0.export
        .output_0xd0_export                ({28'b0,  1'b0, fifo_data_select[2:0]}), // Multiplexer input selection
        .output_0xe0_export                (),
        .output_0xf0_export                (nco_phi_inc),  // NCO tuning word
        .input_0x100_export                ({2'b0, stop_address[29:0]}), // After capture, this is where to start reading
        // SPI port for configuring various things
        .spi_0_external_MISO               (), //(spi_miso),               //           spi_0_external.MISO // DISCONNECT for BeRadio
        .spi_0_external_MOSI               (), //(spi_mosi),               //                         .MOSI
        .spi_0_external_SCLK               (), //(spi_sck),               //                         .SCLK
        .spi_0_external_SS_n               (), //({6'bz, linduino_cs, ltc6954_cs}),                //                         .SS_n
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


/*
//Instantiate NIOS SOPC
hf0 hf0_sopc (
        .clk_clk                                  (clk50),     
        .reset_reset_n                            (reset_n),                           
        .volume_pio_external_connection_export    (audio_gain),    
        .freq_pio_external_connection_export      (nios_phi_inc),     
        .model_rev_pio_external_connection_export (32'h0), 			//future use
        .epcs_flash_controller_0_external_dclk    (dclk_from_the_epcs_flash_controller),    
        .epcs_flash_controller_0_external_sce     (sce_from_the_epcs_flash_controller),    
        .epcs_flash_controller_0_external_sdo     (sdo_from_the_epcs_flash_controller),    
        .epcs_flash_controller_0_external_data0   (data0_to_the_epcs_flash_controller),
		  .filter_pio_external_connection_export    (nios_filter_sel) 
		  
);

    // *********************************************************
    // SPI logic
    assign spi_miso = (linduino_miso & (~linduino_cs));
    assign linduino_mosi = spi_mosi;
    assign linduino_sck = spi_sck;


// Frequency band select outputs
assign P28 = band[0];
assign P29 = band[1];
// -----------------------------------------------------------------------------------------------------



// ---- BeMicro Signal Renaming ------------------------------------------------------------------------
// Rename signals to/from BeMicro on-board resources.
// -----------------------------------------------------------------------------------------------------
// BeMicro clocks and resets
wire clk50;                            // 50 MHz oscillator
wire rst_n;                            // Active-low reset push-button
assign clk50 = CLK_FPGA_50M;
assign rst_n = CPU_RST_N;

// BeMicro switch inputs
wire freq_step;                        // Frequency-up/down (User) push-button
wire freq_dir;                         // Frequency-up/down select
assign freq_step = ~PBSW_N;            // Input is active-low so invert here
assign freq_dir  = RECONFIG_SW1;




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

// Instantiate frequency and phase increment counters. Note: this component
// assumes a 10 MHz clock and uses a 32-bit phase accumulator.
freq_phase_cntrs 
#(
    .START_FREQ_KHZ    (START_FREQ_KHZ),
    .FREQ_STEP_KHZ     (FREQ_STEP_KHZ),
    .LOW_FREQ_KHZ      (LOW_FREQ_KHZ),
    .HIGH_FREQ_KHZ     (HIGH_FREQ_KHZ),
    .FREQ_SIZE         (FREQ_SIZE),
    .DEBOUNCE_SIZE     (DEBOUNCE_SIZE)
) freq_phase_cntrs_inst (
    .clk               (adc_clk_out),
    .reset_n           (reset_n),
    .freq_step         (freq_step),
    .freq_dir          (freq_dir),
    .pb_strb           (pb_strb),
    .freq_strb         (freq_strb),
    .freq              (freq),
    .phi_inc           (phi_inc)
);

// Select capacitors on the BeRadio based on frequency band.
// If nios_phi_inc is zero, use band_sel (set by buttons) to select, else use nios_band
// (set by NIOS).
always @(posedge adc_clk_out or negedge reset_n) begin
	if (!reset_n) begin
		band <= band_sel(START_FREQ_KHZ[FREQ_SIZE-1:0]);
   end
   else begin
		if(nios_phi_inc == 0) begin
			band <= band_sel(freq);
		end
		else begin
			band <= nios_band;
		end
   end
end


// BeMicro LED outputs -> 1'b0 == on, 1'b1 == off (active-low to turn on)
assign F_LED0 = fsin[15];               // frequency counter!!
//assign F_LED1 = ~of_led;               // ADC overflow
assign F_LED2 = ~RECONFIG_SW1;         // Configuration switch 1
assign F_LED3 = ~RECONFIG_SW2;         // Configuration switch 2
assign F_LED4 = ~leds_out[3];          // Frequency display digit
assign F_LED5 = ~leds_out[2];          // Frequency display digit
assign F_LED6 = ~leds_out[1];          // Frequency display digit
assign F_LED7 = ~leds_out[0];          // Frequency display digit

*/