// udpsdr_hf0.v
//
// Project: Medium Wave (500 kHz - 1700 kHz) Receiver, SDR Demonstration
// Copyright 2012, Zephyr Engineering, Inc., All Rights Reserved
//
// Description: Top-level BeRadio (UDPSDR HF0) design file. This design
// implements a simple AM radio. Data from an ADC sampling at 10 Msps are
// mixed with a tunable local oscillator signal to remove the carrier. The
// resulting samples are decimated to 50 ksps using CIC filters. These
// samples are then demodulated using an amplitude calculation and filtered
// using an FIR filter. The final results are sent to a DAC over a SPI bus.
//
// Written by: Charles Mesarosh & Steve Kalandros
//
// Revision 1.0 - Dec 26, 2012	S.C. Final release
//
// -----------------------------------------------------------------------------------------------------

// ---- Module I/O -------------------------------------------------------------------------------------
module udpsdr_hf0 (
    // Clock
    input    wire  CLK_FPGA_50M,       // 50 MHz BeMicro on-board oscillator

    // GPIO
    input    wire  RECONFIG_SW1,       // BeMicro Configuration switch one
    input    wire  RECONFIG_SW2,       // BeMicro Configuration switch two
    input    wire  CPU_RST_N,          // BeMicro push-button reset (active-low)
    input    wire  PBSW_N,             // BeMicro User push-button (active-low)
    output   wire  F_LED0,             // BeMicro LED 0
    output   wire  F_LED1,             // BeMicro LED 1
    output   wire  F_LED2,             // BeMicro LED 2
    output   wire  F_LED3,             // BeMicro LED 3
    output   wire  F_LED4,             // BeMicro LED 4
    output   wire  F_LED5,             // BeMicro LED 5
    output   wire  F_LED6,             // BeMicro LED 6
    output   wire  F_LED7,             // BeMicro LED 7

    // Expansion Connector
    output   wire  P22,                // IOBANK1, DPCLK0
    output   wire  P23,                // IOBANK1
    output   wire  P25,                // IOBANK1
    output   wire  P27,                // IOBANK1
    input    wire  P44,                // IOBANK1
    input    wire  P45,                // IOBANK1

    input    wire  P5,                 // IOBANK2
    input    wire  P7,                 // IOBANK2
    input    wire  P9,                 // IOBANK2, CDPCLK1
    input    wire  P11,                // IOBANK2
    input    wire  P12,                // IOBANK2
    input    wire  P14,                // IOBANK2, DPCLK1
    input    wire  P17,                // IOBANK2
    input    wire  P18,                // IOBANK2
    input    wire  P19,                // IOBANK2
    input    wire  P20,                // IOBANK2
    input    wire  P47,                // IOBANK2
    input    wire  P50,                // IOBANK2
    input    wire  P51,                // IOBANK2

    output   wire  RESET_EXP_N,        // IOBANK3
    output   wire  P3,                 // IOBANK3
    input    wire  P4,                 // IOBANK3
    input    wire  P6,                 // IOBANK3
    input    wire  P8,                 // IOBANK3
    input    wire  P10,                // IOBANK3
    input    wire  P16,                // IOBANK3
    input    wire  P37,                // IOBANK3
    input    wire  P38,                // IOBANK3
    input    wire  P39,                // IOBANK3, DPCLK2
    input    wire  P40,                // IOBANK3
    input    wire  P41,                // IOBANK3
    input    wire  P42,                // IOBANK3
    input    wire  P43,                // IOBANK3, CDPCLK2
    input    wire  P49,                // IOBANK3
    input    wire  P60,                // IOBANK3, DPCLK3

    input    wire  EXP_PRESENT,        // IOBANK4
    input    wire  P13,                // IOBANK4
    input    wire  P21,                // IOBANK4, DPCLK4
    output   wire  P29,                // IOBANK4
    input    wire  P52,                // IOBANK4
    input    wire  P53,                // IOBANK4
    input    wire  P54,                // IOBANK4, CLKOUT
    input    wire  P55,                // IOBANK4

    input    wire  P15,                // IOBANK5, CDPCLK4
    output   wire  P24,                // IOBANK5
    output   wire  P26,                // IOBANK5
    output   wire  P28,                // IOBANK5
    input    wire  P46,                // IOBANK5
    input    wire  P48,                // IOBANK5
    input    wire  P56,                // IOBANK5
    input    wire  P57,                // IOBANK5
    input    wire  P58,                // IOBANK5, DPCLK6
    input    wire  P59,                // IOBANK5

    input    wire  P1,                 // CLK12, DiffCLK_7n input
    input    wire  P2,                 // CLK13, DiffCLK_7p input
    input    wire  P35,                // CLK15, DiffCLK_6n input
    input    wire  P36,                // CLK15, DiffCLK_6p input

    // 10/100 Ethernet PHY (not used in this project)
    input    wire  ETH_COL,            // Collision detect
    input    wire  ETH_CRS,            // Carrier sense
    output   wire  ETH_RESET_N,        // Reset (active-low)
    output   wire  MDC,                // Management Data Clock
    inout    wire  MDIO,               // Management Data I/O
    input    wire  RX_CLK,             // Receive clock
    input    wire  RX_DV,              // Receive data valid
    input    wire  RX_ER,              // Receive error
    input    wire  RXD_0,              // Receive data
    input    wire  RXD_1,              // Receive data
    input    wire  RXD_2,              // Receive data
    input    wire  RXD_3,              // Receive data
    input    wire  TX_CLK,             // Transmit clock
    output   wire  TX_EN,              // Transmit enable
    output   wire  TXD_0,              // Transmit data
    output   wire  TXD_1,              // Transmit data
    output   wire  TXD_2,              // Transmit data
    output   wire  TXD_3,              // Transmit data

    // 512 Mb Mobile DDR SDRAM (not used in this project)
    output   wire  RAM_A0,             // Address
    output   wire  RAM_A1,             // Address
    output   wire  RAM_A2,             // Address
    output   wire  RAM_A3,             // Address
    output   wire  RAM_A4,             // Address
    output   wire  RAM_A5,             // Address
    output   wire  RAM_A6,             // Address
    output   wire  RAM_A7,             // Address
    output   wire  RAM_A8,             // Address
    output   wire  RAM_A9,             // Address
    output   wire  RAM_A10,            // Address
    output   wire  RAM_A11,            // Address
    output   wire  RAM_A12,            // Address
    output   wire  RAM_A13,            // Address
    output   wire  RAM_BA0,            // Bank address
    output   wire  RAM_BA1,            // Bank address
    output   wire  RAM_CAS_N,          // Column Access Strobe (active-low)
    output   wire  RAM_CK_N,           // Differential clock (-)
    output   wire  RAM_CK_P,           // Differential clock (+)
    output   wire  RAM_CKE,            // Clock enable
    output   wire  RAM_CS_N,           // Chip select (active-low)
    inout    wire  RAM_D0,             // Bidirectional data
    inout    wire  RAM_D1,             // Bidirectional data
    inout    wire  RAM_D2,             // Bidirectional data
    inout    wire  RAM_D3,             // Bidirectional data
    inout    wire  RAM_D4,             // Bidirectional data
    inout    wire  RAM_D5,             // Bidirectional data
    inout    wire  RAM_D6,             // Bidirectional data
    inout    wire  RAM_D7,             // Bidirectional data
    inout    wire  RAM_D8,             // Bidirectional data
    inout    wire  RAM_D9,             // Bidirectional data
    inout    wire  RAM_D10,            // Bidirectional data
    inout    wire  RAM_D11,            // Bidirectional data
    inout    wire  RAM_D12,            // Bidirectional data
    inout    wire  RAM_D13,            // Bidirectional data
    inout    wire  RAM_D14,            // Bidirectional data
    inout    wire  RAM_D15,            // Bidirectional data
    output   wire  RAM_LDM,            // Lower data byte mask
    inout    wire  RAM_LDQS,           // Lower data byte valid strobe
    output   wire  RAM_RAS_N,          // Row Access Strobe (active-low)
    output   wire  RAM_UDM,            // Upper data byte mask,
    inout    wire  RAM_UDQS,           // Upper data byte valid strobe
    output   wire  RAM_WS_N,           // Write Strobe (active_low)

    // Micro-SD Card Socket (not used in this project)
    output   wire  SD_CLK,             // Clock
    inout    wire  SD_CMD,             // Bidirectional command
    inout    wire  SD_DAT0,            // Bidirectional data
    inout    wire  SD_DAT1,            // Bidirectional data
    inout    wire  SD_DAT2,            // Bidirectional data
    inout    wire  SD_DAT3,            // Bidirectional data

    // Temperature Sensor (not used in this project)
    output   wire  TEMP_CS_N,          // Chip Select (active-low)
    input    wire  TEMP_MISO,          // Master In, Slave Out
    output   wire  TEMP_MOSI,          // Master Out, Slave In
    output   wire  TEMP_SC,             // Clock
	 
 	// EPCS Controller
	input		wire	data0_to_the_epcs_flash_controller,
	output	wire	dclk_from_the_epcs_flash_controller,
	output	wire	sce_from_the_epcs_flash_controller,
	output	wire	sdo_from_the_epcs_flash_controller

);
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


// ---- BeMicro Unused Outputs -------------------------------------------------------------------------
// Force unused BeMicro outputs low or high.
// -----------------------------------------------------------------------------------------------------
assign ETH_RESET_N = 1'b0;
assign MDC         = 1'b0;
assign MDIO        = 1'bz;
assign RAM_BA1     = 1'b0;
assign RAM_BA0     = 1'b0;
assign RAM_A13     = 1'b0;
assign RAM_A12     = 1'b0;
assign RAM_A11     = 1'b0;
assign RAM_A10     = 1'b0;
assign RAM_A9      = 1'b0;
assign RAM_A8      = 1'b0;
assign RAM_A7      = 1'b0;
assign RAM_A6      = 1'b0;
assign RAM_A5      = 1'b0;
assign RAM_A4      = 1'b0;
assign RAM_A3      = 1'b0;
assign RAM_A2      = 1'b0;
assign RAM_A1      = 1'b0;
assign RAM_A0      = 1'b0;
assign RAM_CAS_N   = 1'b1;
assign RAM_CK_N    = 1'b0;
assign RAM_CK_P    = 1'b0;
assign RAM_CKE     = 1'b0;
assign RAM_CS_N    = 1'b1;
assign RAM_D0      = 1'bz;
assign RAM_D1      = 1'bz;
assign RAM_D2      = 1'bz;
assign RAM_D3      = 1'bz;
assign RAM_D4      = 1'bz;
assign RAM_D5      = 1'bz;
assign RAM_D6      = 1'bz;
assign RAM_D7      = 1'bz;
assign RAM_D8      = 1'bz;
assign RAM_D9      = 1'bz;
assign RAM_D10     = 1'bz;
assign RAM_D11     = 1'bz;
assign RAM_D12     = 1'bz;
assign RAM_D13     = 1'bz;
assign RAM_D14     = 1'bz;
assign RAM_D15     = 1'bz;
assign RAM_LDM     = 1'b0;
assign RAM_LDQS    = 1'bz;
assign RAM_RAS_N   = 1'b1;
assign RAM_UDM     = 1'b0;
assign RAM_UDQS    = 1'bz;
assign RAM_WS_N    = 1'b1;
assign RESET_EXP_N = 1'b1;
assign SD_CLK      = 1'b0;
assign SD_CMD      = 1'bz;
assign SD_DAT0     = 1'bz;
assign SD_DAT1     = 1'bz;
assign SD_DAT2     = 1'bz;
assign SD_DAT3     = 1'bz;
assign TEMP_CS_N   = 1'b1;
assign TEMP_MOSI   = 1'b1;
assign TEMP_SC     = 1'b0;
assign TX_EN       = 1'b0;
assign TXD_0       = 1'b0;
assign TXD_1       = 1'b0;
assign TXD_2       = 1'b0;
assign TXD_3       = 1'b0;
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

// BeMicro LED outputs -> 1'b0 == on, 1'b1 == off (active-low to turn on)
assign F_LED0 = fsin[15];               // frequency counter!!
//assign F_LED1 = ~of_led;               // ADC overflow
assign F_LED2 = ~RECONFIG_SW1;         // Configuration switch 1
assign F_LED3 = ~RECONFIG_SW2;         // Configuration switch 2
assign F_LED4 = ~leds_out[3];          // Frequency display digit
assign F_LED5 = ~leds_out[2];          // Frequency display digit
assign F_LED6 = ~leds_out[1];          // Frequency display digit
assign F_LED7 = ~leds_out[0];          // Frequency display digit
// -----------------------------------------------------------------------------------------------------


// ---- I/O Connector Signal Renaming ------------------------------------------------------------------
// Rename expansion connector pins. The convention here is to use BeMicro schematic names in the pin
// list and logical names within the design. The logical names may also match BeRadio schematic names.
// -----------------------------------------------------------------------------------------------------
// ADC control outputs
assign P3  = adc_stabil_en_l;

// ADC status inputs
wire adc_of;                           // ADC overflow indicator
assign adc_of = P4;

// ADC data inputs
wire signed [11:0] adc_d;              // ADC input data
assign adc_d = {P5,P6,P7,P8,P9,P10,P11,P12,P13,P14,P15,P16};

// Clock input
wire adc_clk_out;                      // ADC clock source from BeRadio
assign adc_clk_out = ~P19;

// ADC clock outputs
// no need for adc_clk_in to go out
//assign P22 = adc_clk_in;
assign P22 = 1'b0;
assign P23 = adc_osc_en;

// DAC outputs
assign P24 = dac_clr_l;
assign P25 = dac_din;
assign P26 = dac_sclk;
assign P27 = dac_cs_l;

// Frequency band select outputs
assign P28 = band[0];
assign P29 = band[1];
// -----------------------------------------------------------------------------------------------------


//---- Static control signal assignments ---------------------------------------------------------------
wire adc_stabil_en_l;                  // ADC clock duty cycle stabilizer enable pin (active-low)
wire adc_osc_en;                       // ADC oscillator enable pin

assign adc_stabil_en_l = 1'b1;         // ADC clock duty cycle stabilizer disabled
assign adc_osc_en      = 1'b1;         // ADC clock source: high for BeRadio crystal oscillator,
                                       //                    low for FPGA PLL
// -----------------------------------------------------------------------------------------------------


// ---- Clocks -----------------------------------------------------------------------------------------
wire adc_clk_in;                       // 10 MHz clock input on BeRadio

// c.m. - 12/18/2012, no longer required
// PLL to generate 10 MHz clock for ADC from 50 MHz input clock.
//sysclk_pll sysclk_pll_inst (
//   .inclk0    (clk50),
//    .c0        (adc_clk_in)
//);
// -----------------------------------------------------------------------------------------------------


// ----------- Reset -----------------------------------------------------------------------------------
// This circuit holds reset active for approximately 419 ms after power-on or after pushing the
// BeMicro reset push-button.
// -----------------------------------------------------------------------------------------------------
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

// Internal reset is the MSB of the counter.
assign reset_n = rstcount[22];
// -----------------------------------------------------------------------------------------------------


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



// Frequency may be controlled by either on board push buttons for stand alone operation or by
// NIOS when controlled by a PC. 
// Note that nios_phi_inc is initialized to zero by NIOS, and remains at that value until
// a command is received on the USB port. As long as nios_phi_inc is zero, the frequency will be
// determined by the phi_inc value that is under control of the push-button.
reg [31:0] nco_phi_inc;				// Frequency from the NIOS subsystem.

always @(posedge adc_clk_out or negedge reset_n) begin
	if (!reset_n) begin
		nco_phi_inc <= phi_inc;
	end
	else begin
		if(nios_phi_inc == 0) begin
			nco_phi_inc <= phi_inc;
		end
		else begin
			nco_phi_inc <= nios_phi_inc;
		end
	end
end
		

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


// Instantiate Numerically Controlled Oscillator (NCO) to implement local oscillator.
//z_nco z_nco_inst (
//    .phase_inc (nco_phi_inc),
//    .clk       (adc_clk_out),
//    .reset_n   (reset_n),
//    .fsin      (fsin),
//    .fcos      (fcos)
//);

NCOMega z_nco_inst (
		.phi_inc_i(nco_phi_inc),
		.clk(adc_clk_out),
		.reset_n(reset_n),
		.clken(reset_n),
		.fsin_o(fsin),
		.fcos_o(fcos),
		.out_valid()
);

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
    .d1            (cic2_i),
    .d2            (cic2_q),
    .q1            (am_in_i),
    .q2            (am_in_q)
);

// Instantiate the AM demodulator, which calculates the amplitude of the
// received samples (i.e. data_out = sqrt(i_in^2 + q_in^2) ).
am_demod #(
    .DATA_SIZE     (16)
) am_demod_inst (
    .clk           (adc_clk_out),
    .reset_n       (reset_n),
    .strobe_in     (cic2_strb),
    .i_in          (am_in_i),
    .q_in          (am_in_q),
    .strobe_out    (am_strb),
    .data_out      (am_data)
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
    .strobe_in     (am_strb),
    .ch1_in        (am_data),
    .ch2_in        (16'h0000),
    .strobe_out    (audio_strb),
    .ch1_out       (audio_data),
    .ch2_out       ()
);
// -----------------------------------------------------------------------------------------------------


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

assign scaled_audio = audio_data * audio_gain;

// If nios_phi_inc is zero, select unscaled audio (unipolar_data), else select scaled audio (scaled_audio).
// The nios_phi_inc value is non-zero whenever NIOS takes control of the receiver.
always @(posedge adc_clk_out or negedge reset_n) begin
	if (!reset_n) begin
		audio_out <= unipolar_data;
   end
   else begin
		if(nios_phi_inc == 0) begin
			audio_out <= unipolar_data;
		end
		else begin
			// bits selected empiricaly to trade off output audio volume versus distortion
			audio_out <= {~scaled_audio[23],scaled_audio[20:6]};
		end
   end
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
wire [31:0] nios_phi_inc;								// phase increment to control tuning frequency
wire [7:0] nios_filter_sel;							// filter selection 
wire [1:0]	nios_band;									// only 2 bits of nios pio port used here
assign nios_band = nios_filter_sel[1:0];

// Instantiate NIOS SOPC
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
// -----------------------------------------------------------------------------------------------------

	 
endmodule

