// freq_phase_cntrs.v
//
// Project: Medium Wave (500 kHz - 1700 kHz) Receiver, SDR Demonstration
// Copyright 2012, Zephyr Engineering, Inc., All Rights Reserved
//
// Description: Keep track of the current frequency and phase increment, which
// increment or decrement when the user push-button is pressed.
//
// Written by: Steve Kalandros
//
// Revision 0.1 - Aug. 24, 2012  S.K. Initial release.
// -----------------------------------------------------------------------------------------------------

// ---- Module I/O -------------------------------------------------------------------------------------
module freq_phase_cntrs
#(
    parameter START_FREQ_KHZ =  500,                   // Default frequency at reset or power-up
    parameter FREQ_STEP_KHZ  =   10,                   // Frequency increment or decrement step
    parameter LOW_FREQ_KHZ   =  500,                   // Lowest allowed frequency
    parameter HIGH_FREQ_KHZ  = 1700,                   // Highest allowed frequency
    parameter FREQ_SIZE      =   12,                   // Bits in frequency
    parameter DEBOUNCE_SIZE  =   20                    // Bits in debounce counter (determines delay)
) (
    input   wire  clk,                                 // System clock
    input   wire  reset_n,                             // Asynchronous system reset
    input   wire  freq_step,                           // Frequency step push-button
    input   wire  freq_dir,                            // Frequency step direction DIP switch
    output  wire  pb_strb,                             // Push-button pressed strobe
    output  wire  freq_strb,                           // Push-button released strobe
    output  wire  signed  [FREQ_SIZE-1:0] freq,        // Current frequency in kHz
    output  wire  [31:0]  phi_inc                      // Local oscillator phase increment
);
// -----------------------------------------------------------------------------------------------------


// ---- Function Definitions ---------------------------------------------------------------------------
// Function to convert frequency in kHz to a phase increment for a 32-bit phase accumulator running at
// the 10 MHz ADC clock rate:
// 1.) Multiply the frequency in kHz by a constant integer representing the reciprocal of 10 MHz
//     (10,000 kHz). Since the reciprocal is less than one and we want to do integer math, we multiply
//     the constant by 2^43. This provides sufficient precision for our integer phase increments.
// 2.) The phase accumulator is only 32 bits, so we need to truncate 11 bits. First truncate 10 bits,
//     then add one for rounding and truncate the final bit.
//              PHASE_INC = ((FREQUENCY_IN_KHZ * ((2**43) / 10,000) >> 10) + 1) >> 1
//
localparam RECIP_CLK_FREQ_KHZ = 43'd879609302;  // Define (2**43) / 10,000
function integer khz_to_phase;
    input integer khz;
    reg [74:0] product;
    begin
        product = ((khz * RECIP_CLK_FREQ_KHZ) >> 10) + 1;
        khz_to_phase = product[32:1];
    end
endfunction
// -----------------------------------------------------------------------------------------------------


// ---- Derived Parameters -----------------------------------------------------------------------------
// Use a function to convert frequencies in kHz to phase increments for a 32-bit accumulator running at
// the 10 MHz ADC clock rate.
// -----------------------------------------------------------------------------------------------------
localparam START_FREQ_PH  = khz_to_phase(START_FREQ_KHZ);  // Default phase increment
localparam FREQ_STEP_PH   = khz_to_phase(FREQ_STEP_KHZ);   // Phase increment step
localparam LOW_FREQ_PH    = khz_to_phase(LOW_FREQ_KHZ);    // Lowest phase increment
localparam HIGH_FREQ_PH   = khz_to_phase(HIGH_FREQ_KHZ);   // Highest phase increment
// -----------------------------------------------------------------------------------------------------


// ---- Push-Button Debouncing -------------------------------------------------------------------------
// Debounce the User push-button by synchronizing to the sample clock and
// setting a counter which delays long enough to get past the mechanical noise
// of the switch.
// -----------------------------------------------------------------------------------------------------
reg [1:0] step_sync;                   // Shift register to synchronize User push-button input
reg [DEBOUNCE_SIZE-1:0] usrcount;      // User push-button debounce counter
wire freq_step_deb;                    // Debounced push-button input

// Synchronize the User push-button input to the ADC clock using a shift register.
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        step_sync <= 2'b0;
    end
    else begin
        step_sync <= {step_sync[0], freq_step};
    end
end

// Debounce User push-button. The circuit sets all bits of a counter when the
// button is pushed and then counts down to zero before clearing it in order to
// ignore any mechanical noise on the switch. The delay for detecting noise is
// (2^(DEBOUNCE_SIZE-1) / 10 MHz) which is about 52 ms for the default value
// of DEBOUNCE_SIZE (20).
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        usrcount <= {DEBOUNCE_SIZE{1'b0}};
    end
    else if (step_sync[1]) begin
        usrcount <= {DEBOUNCE_SIZE{1'b1}};
    end
    else if (usrcount[DEBOUNCE_SIZE-1]) begin
        usrcount <= usrcount - {{(DEBOUNCE_SIZE-1){1'b0}},1'b1};
    end
end

// The MSB of the counter is the debounced push-button input.
assign freq_step_deb = usrcount[DEBOUNCE_SIZE-1];
// -----------------------------------------------------------------------------------------------------


// ---- Frequency and Phase Increment Counters ---------------------------------------------------------
// Increment or decrement the frequency and phase increment on a falling edge
// of the debounced push-button signal. Roll over to the low frequency and
// phase increment when incremented past the maximum frequency mark; roll over
// to the high frequency and phase increment when decremented past the low
// frequency mark. 
// -----------------------------------------------------------------------------------------------------
reg freq_step_debq;                    // Registered debounced push-button input for edge detection
reg pb_strbq;                          // Registered rising edge of debounced push-button
reg freq_strbq;                        // Registered rising edge of debounced push-button
reg [FREQ_SIZE-1:0] frequency;         // Current frequency
reg [31:0] phase_inc;                  // Phase increment for local oscillator

// The receiver powers up and resets to the default local oscillator frequency.
// Pressing the User push-button on the BeMicro causes the frequency to increment
// or decrement. The button push is detected by looking for a falling edge on the
// debounced button-push flag (which actually occurs about 105 ms after the switch
// is released). Switch 1 indicates direction: 0 is increment, 1 is decrement.
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        freq_step_debq <= 1'b0;
        pb_strbq       <= 1'b0;
        freq_strbq     <= 1'b0;
        frequency      <= START_FREQ_KHZ[FREQ_SIZE-1:0];
        phase_inc      <= START_FREQ_PH;
    end
    else begin
        freq_step_debq <= freq_step_deb;
        pb_strbq       <= freq_step_deb & ~freq_step_debq;
        freq_strbq     <= ~freq_step_deb & freq_step_debq;

        // If Switch 1 is low, increment the frequency when the push-button is
        // pressed. If already at or past the high frequency, jump to the
        // low frequency.
        if (!freq_step_deb && freq_step_debq && !freq_dir) begin
            if (frequency >= HIGH_FREQ_KHZ) begin
                frequency <= LOW_FREQ_KHZ[FREQ_SIZE-1:0];
                phase_inc <= LOW_FREQ_PH;
            end
            else begin
                frequency <= frequency + FREQ_STEP_KHZ[FREQ_SIZE-1:0];
                phase_inc <= phase_inc + FREQ_STEP_PH;
            end
        end

        // If Switch 1 is high, decrement the frequency when the push-button is
        // pressed. If already at or past the low frequency, jump to the
        // high frequency.
        else if (!freq_step_deb && freq_step_debq && freq_dir) begin
            if (frequency <= LOW_FREQ_KHZ) begin
                frequency <= HIGH_FREQ_KHZ[FREQ_SIZE-1:0];
                phase_inc <= HIGH_FREQ_PH;
            end
            else begin
                frequency <= frequency - FREQ_STEP_KHZ[FREQ_SIZE-1:0];
                phase_inc <= phase_inc - FREQ_STEP_PH;
            end
        end
    end
end

// Assign outputs
assign pb_strb   = pb_strbq;
assign freq_strb = freq_strbq;
assign freq      = frequency;
assign phi_inc   = phase_inc;
// -----------------------------------------------------------------------------------------------------

endmodule

