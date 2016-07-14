//--------------------------------------------------------------------
// Broadcast checker for FPGA implementation
// Double-buffers the input.  Results will be read out via SPI.
//--------------------------------------------------------------------

`timescale 1ns / 10ps

module LTC4284_bc_rx (
     input  wire    clk_24m,       // Clock
     input  wire    enb,           // High to enable packet detect, low to abort
                                   // (enb low doesn't alter the SPI read buffer)
     input  wire    sdao,          // Serial output from 4284
     input  wire    cs_n,          // SPI chip select#
     input  wire    sck,           // SPI clock, in mode 0 or 3.
                                   // The falling edge of cs_n will cause the first
                                   // bit to be output.  Subsequent changes happend on
                                   // sck falling edges.  However, a rising edge must
                                   // happen first, before a falling edge is used
     output wire    miso           // Data output
     );

// Internal variables
reg enb_sync;            // Synchronizers
reg sdao_del, sdao_sync;
reg [2:0] bc_st, bc_st_d;     // State bits
reg first_half, first_half_d; // Saved SDAO during first half-bit time
reg clr_clk_ctr;              // Clears clk_ctr
reg bc_start, bc_end;         // Start and end of packet reception
reg first_bit;                // First "0" bit received, store speed information
reg set_frame_err;            // If bad Manchester coding
reg set_pec_err;              // PEC is wrong
reg set_too_long;             // Extra bits
reg set_too_short;            // Missing bits
reg store_nrz;                // Save an incoming data bit (NRZ comes from first-half bit value

reg [1:0] speed_code;         // 00 = 32K, 01 = 128K, 10 = 512K, 11 = 2M
wire [1:0] speed_code_q;      // Speed code from stored status
reg speed_good;               // If a valid speed present

// Quarter and half-bit time decodes (against clk_ctr value)
wire half_bit_m1;             // half-bit time minus 1
wire [10:0] quarter_bit;      // quarter-bit time
wire quarter_bit_m1;          // 
wire two_bits_slow;           // clk_ctr == TWO_BITS_SLOW
wire ctr_max;                 // clk_ctr at maximum value

// Clock counter
reg [10:0] clk_ctr;           // Maximum required is 1536 for two-bit time at 32Khz
// Data and status storage
reg [7:0] bc_bit_ctr;         // Counts up to 160 NRZ bits
reg [159:0] bc_data;          // Stored bits
reg [7:0] bc_status;          // Status byte for SPI.  Bit order reversed since bit 0
                              // is sent to SPI first (although SPI thinks bit 7 of a byte
                              // is coming first)

reg [7:0] pec;                // PEC accumulator

// Handshake with SPI
reg pkt_pend, pkt_pend_d;     // Set when packet is ready to go out but can't be used yet
reg ld_spi;                   // High to copy status and data to SPI side

// SPI input and tracking

reg cs_del_1, cs_del_2;       // CS delayed, also for edge detect
wire cs_tedge;                // CS# trailing edge (CS# goes from low to high)
reg sck_del_1, sck_del_2;     // SCK
reg spi_run, spi_run_d;       // 

reg spi_stb;                  // Active to shift spi_data
reg [167:0] spi_data;         // 21 bytes of data including status byte first

// Input detect state machine
parameter BC_DIS = 0;              // Park here if enb low
parameter BC_IDLE = 1;             // Wait for SDAO to be high for at least 2 bit times of 32K
parameter BC_EDGE1 = 2;            // First SDAO falling edge detected
parameter BC_EDGE2 = 3;            // Second SDAO falling edge, measure apparent bitrate here
parameter BC_1ST_HALF = 4;         // First half-bit time
parameter BC_2ND_HALF = 5;         // Second half-bit time, evaluate received bit
parameter BC_TERM = 6;             // Wrap up and copy to SPI side

parameter TWO_BITS_SLOW = 64 * 12 * 2;  // Two 32Khz bit times in 24Mhz clock cycles

always @ (posedge clk_24m)
begin
     enb_sync <= enb;
     sdao_sync <= sdao;
     sdao_del <= sdao_sync;
end

// State machine
always @ (bc_bit_ctr or bc_st or ctr_max or enb_sync or first_half or
     pec or quarter_bit_m1 or sdao_del or sdao_sync or speed_good or
     two_bits_slow)
begin
     bc_st_d = bc_st;
     first_half_d = first_half;
     clr_clk_ctr = 0;
     bc_start = 0;
     bc_end = 0;
     first_bit = 0;
     set_too_short = 0;
     set_too_long = 0;
     set_frame_err = 0;
     set_pec_err = 0;
     store_nrz = 0;

     // Wait for enb high
     if (bc_st == BC_DIS)
     begin
          if (enb_sync)
          begin
               // Set up counter to wait for SDAO high
               clr_clk_ctr = 1;
               bc_st_d = BC_IDLE;
          end
     end
     // Wait for SDAO high for two bit times of 32Khz
     if (bc_st == BC_IDLE)
     begin
          // If SDAO low, keep waiting
          if (!sdao_sync) clr_clk_ctr = 1;
          // If counter expired
          else if (two_bits_slow) bc_st_d = BC_EDGE1;
          // Else keep incrementing (happens automatically
     end
     // Look for first trailing edge of SDAO
     if (bc_st == BC_EDGE1)
     begin
          if (!sdao_sync & sdao_del)
          begin
               bc_start = 1;
               clr_clk_ctr = 1;    // Count clocks between edges
               bc_st_d = BC_EDGE2;
          end
     end
     // Look for second trailing edge
     if (bc_st == BC_EDGE2)
     begin
          // Check for falling edge.  Also, if counter going to
          // overflow, stop counting and deal with the speed error
          if (!sdao_sync & sdao_del | ctr_max)
          begin
               first_bit = 1;      // Store speed status
               // Is speed good?
               if (speed_good)
               begin
                    clr_clk_ctr = 1;
                    bc_st_d = BC_1ST_HALF;
               end
               // If not, exit now
               else bc_st_d = BC_TERM;
          end
          // Otherwise, keep incrementing
     end
     // Sample first half-bit
     if (bc_st == BC_1ST_HALF)
     begin
          // If a quarter bit time has passed
          if (quarter_bit_m1)
          begin
               first_half_d = sdao_sync; // Save sdao for next half-bit time
               bc_st_d = BC_2ND_HALF;
          end
     end
     // Sample second half-bit
     if (bc_st == BC_2ND_HALF)
     begin
          // If a quarter bit time has passed
          if (quarter_bit_m1)
          begin
               // Special code for bit past end
               if (bc_bit_ctr == 160)
               begin
                    bc_st_d = BC_TERM;
                    // Should be idle
                    if (sdao_sync & first_half)
                    begin
                         // Indicate if PEC error
                         set_pec_err = (pec != 0);
                    end
                    // Check for invalid Manchester
                    else if (!sdao_sync & !first_half) set_frame_err = 1;
                    // Otherwise, it's one too many bits
                    else set_too_long = 1;
               end
               // If in the middle
               else
               begin
                    // If idle, packet was too short
                    if (sdao_sync & first_half)
                    begin
                         set_too_short = 1;
                         bc_st_d = BC_TERM;
                    end
                    // If invalid Manchester
                    else if (!sdao_sync & !first_half)
                    begin
                         set_frame_err = 1;
                         bc_st_d = BC_TERM;
                    end
                    // If valid Manchester
                    else
                    begin
                         // First half-bit has correct value per GE Thomas
                         store_nrz = 1;           // Save it and shift through PEC,
                                                  // also increment bc_bit_ctr
                         bc_st_d = BC_1ST_HALF;
                    end
               end
          end
     end
     // End of packet reception
     if (bc_st == BC_TERM)
     begin
          bc_end = 1;
          bc_st_d = BC_IDLE;
     end
end

// Speed decode based on clk_ctr for the distance between two sequential trailing edges
// The basic rule:  match the ideal speed within 10%, with another one-clock margin
// Datarate   Min   Max
//   2M        10    14
//  512K       42    53
//  128K      172   212
//   32K      690   846
//
// Match one less than desired value due to counter delay

always @ (clk_ctr)
begin
     speed_good = 0;
     speed_code = 0;
     // 2M check
     if (clk_ctr > 8 && clk_ctr < 14)
     begin
          speed_good = 1;
          speed_code = 3;
     end
     // 512K
     if (clk_ctr > 40 && clk_ctr < 53)
     begin
          speed_good = 1;
          speed_code = 2;
     end
     // 128K
     if (clk_ctr > 170 && clk_ctr < 212)
     begin
          speed_good = 1;
          speed_code = 1;
     end
     // 32K
     if (clk_ctr > 688 && clk_ctr < 846)
     begin
          speed_good = 1;
          speed_code = 0;
     end
end

// Decode limits for half and quarter bit times.  These are both
// "minus 1" since counting starts at 0

assign quarter_bit = 3 << ((3 - speed_code_q) << 1);   // Divide by 4 for each speed increment
assign quarter_bit_m1 = (clk_ctr == quarter_bit - 1);
assign half_bit_m1 = (clk_ctr == ({ quarter_bit, 1'b0 } - 1));

// Two bit times at slowest rate
assign two_bits_slow = (clk_ctr == TWO_BITS_SLOW);
// Maximum clk_ctr value
assign ctr_max = (clk_ctr == 2047);

// Flip-flop updates
initial
begin
     bc_st <= BC_DIS;
     first_half <= 0;
end

always @ (posedge clk_24m)
begin
     bc_st <= bc_st_d;
     first_half <= first_half_d;
end

// Clock counter updates
always @ (posedge clk_24m)
begin
     if (clr_clk_ctr) clk_ctr <= 0;
     else
     begin
          // Increment may be overwritten below
          clk_ctr <= clk_ctr + 1;
          // Rollover at half bit time when in bit processing,
          // also check for SDAO edge
          if (bc_st == BC_1ST_HALF || bc_st == BC_2ND_HALF)
          begin
               if (half_bit_m1 | (sdao_sync != sdao_del))
                    clk_ctr <= 0;
          end
     end
end

// Store NRZ data and update bit counter
always @ (posedge clk_24m)
begin
     if (bc_start)
     begin
          bc_data <= 0;
          bc_bit_ctr <= 1;     // At start, first bit assumed "0"
     end
     else if (store_nrz)
     begin
          bc_data <= { first_half, bc_data[159:1] };
          bc_bit_ctr <= bc_bit_ctr + 1;
     end
end

// Manage status bits
always @ (posedge clk_24m)
begin
     if (!enb_sync) bc_status <= 0;
     else if (bc_start) bc_status <= 0;
     else
     begin
          // If completing packet now
          if (bc_st_d == BC_TERM && bc_st != BC_TERM) bc_status[0] <= 1;   // "present" bit
          // Save speed code in reverse order plus speed error status
          if (first_bit)
          begin
               bc_status[3] <= !speed_good;
               if (speed_good)
               begin
                    bc_status[1] <= speed_code[1];
                    bc_status[2] <= speed_code[0];
               end
          end
          if (set_frame_err) bc_status[4] <= 1;
          if (set_too_short) bc_status[5] <= 1;
          if (set_too_long) bc_status[6] <= 1;
          if (set_pec_err) bc_status[7] <= 1;
     end
end

// Bring back latched speed code in normal order
assign speed_code_q = { bc_status[1], bc_status[2] };

// PEC accumulator
always @ (posedge clk_24m)
begin
     // Initialize to 0
     if (bc_start) pec <= 0;
     // At second half-bit time, calculate based on incoming
     // NRZ bit.  Disregard stop bit
     else if (store_nrz == 1 && bc_bit_ctr != 160)
     begin
          if (first_half == pec[7]) pec <= pec << 1;
          else pec <= (pec << 1) ^ 7;
     end
end

// Arbitration between broadcast decode and SPI interface
always @ (pkt_pend or cs_del_1 or bc_end or bc_start)
begin
     pkt_pend_d = pkt_pend;   // Remembers that a packet is pending for SPI to take
     ld_spi = 0;
     // If SPI is idle, bypass the pending latch
     if (!cs_del_1)
     begin
          pkt_pend_d = 0;
          ld_spi = pkt_pend | bc_end;
     end
     // If SPI is busy, manage pending latch
     else
     begin
          if (bc_end) pkt_pend_d = 1;
          // Abort present pend bit if another broadcast packet has begun
          else if (bc_start) pkt_pend_d = 0;
     end
end

initial pkt_pend <= 0;
always @ (posedge clk_24m) pkt_pend <= pkt_pend_d;


// SPI interface

initial
begin
     cs_del_1 <= 0;
     cs_del_2 <= 0;
     sck_del_1 <= 0;
     sck_del_2 <= 0;
     spi_run <= 0;
end

always @ (posedge clk_24m)
begin
     cs_del_1 <= !cs_n;
     cs_del_2 <= cs_del_1;
     sck_del_1 <= sck;
     sck_del_2 <= sck_del_1;
     spi_run <= spi_run_d;
end

always @ (spi_run or cs_del_1 or sck_del_1 or sck_del_2)
begin
     spi_run_d = spi_run;
     spi_stb = 0;
     // If already running
     if (spi_run)
     begin
          // Stop if CS# goes high
          if (!cs_del_1) spi_run_d = 0;
          // Otherwise, clock the shift register on SCK falling edges
          else if (!sck_del_1 & sck_del_2) spi_stb = 1;
     end
     // If waiting to start up.  Insist on CS# and SCK both low.  This allows
     // use of either mode 0 or 3.
     else if (cs_del_1 & !sck_del_1) spi_run_d = 1;
end

assign cs_tedge = !cs_del_1 & cs_del_2;

// Manage shift register
always @ (posedge clk_24m)
begin
     // Prepend data with status byte
     // Note:  Internal bc_status[7:0] is reverse the order which
     // SPI reads it.  bc_status[0] internally is the "data present" bit,
     // But it appears as the first bit on SPI, which is logical bit 7
     if (ld_spi) spi_data <= { bc_data, bc_status };
     // Shift as bits are read
     else if (spi_stb) spi_data <= { 1'b0, spi_data[167:1] };
     // At end of SPI access, clear whole register to force status 
     else if (cs_tedge) spi_data <= 0;
end

// Always output bit 0 of shift register
assign miso = cs_n ? 1'bZ : spi_data[0];

endmodule

