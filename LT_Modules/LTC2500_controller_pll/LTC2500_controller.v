`timescale 1ns / 100ps   // Each unit time is 1ns and the time precision is 10ps

/*
    Created by: Noe Quintero
    E-mail: nquintero@linear.com

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
        The purpose of this module is to interface to the LTC2500.
*/

module LTC2500_controller
(
    // Control 
    sys_clk,            // The digital clock
    sck_in,             // The serial clock from PLL to be gated for the sck of the LTC2500
    reset_n,            // Reset active low
    go,                 // Start a ADC read
    sync_req_recfg,     // Request a synchronisation or reconfigure ADC
    cfg,                // The configuration word 
    n,                  // The averaging ratio

    // LTC2500 Signals
    // Port A
    rdl_filt,           // Read data low for the filtered data port
    sck_filt,           // Gated clock for filtered data port
    sdi_filt,           // Serial data in for the ADC's filtered port
    sdo_filt,           // Serial data out for the ADC's filtered port
    // Port B
    rdl_nyq,            // Read data low for the Nyquist data port
    sck_nyq,            // Gated clock for Nyquist data port
    sdo_nyq,            // Serial data out for the ADC's Nyquist port

    busy,               // The ADC is busy with a conversion
    drdy_n,             // The ADC is not ready for filtered data
    mclk,               // The conversion clock
    sync,               // The synchronizing signal for the ADC
                        // into two settings, depending on SDI logic level.
    // Streaming output
    data_nyq,           // Parallel Nyquist data out
    valid_nyq,          // The Nyquist data is valid

    data_filt,          // Parallel filtered data out
    valid_filt,         // Parallel common mode filtered data out
    error           // The filtered data is valid
);

    parameter DFF_CYCLE_COMP        = 1;    // If using flip flop a delay in cycle is needed
    parameter NUM_OF_CLK_PER_BSY    = 67;   // Number of sys_clk cycles to make 675ns
                                            // 675ns / (1/100 Mhz) ~ 68 cycles (rounded up) then -1
    parameter NYQ_TRUNK_VALUE       = 32;   // Truncated data count value per mclk for nyquist data
    parameter FILT_TRUNK_VALUE      = 54;   // Truncated data count value for filtered data

    // Port declaration
    input               sys_clk;
    input               sck_in;
    input               reset_n;
    input               go;
    input               sync_req_recfg;
    input   [9:0]       cfg;
    input   [13:0]      n;
    output              rdl_filt;
    output              sck_filt;
    output              sdi_filt;
    input               sdo_filt;
    output              rdl_nyq;
    output              sck_nyq;
    input               sdo_nyq;
    input               busy;
    input               drdy_n;
    output              mclk;
    output              sync;
    output  reg [31:0]  data_nyq;
    output  reg         valid_nyq;
    output  reg [53:0]  data_filt;
    output  reg         valid_filt;
    output  reg         error;

    // Internal signals
    wire                            q_n;
    wire                            r;
    wire                            s;
    wire                            en_busy_count;
    reg     [3:0]                   state;
    reg                             sync_flag;
    reg     [9:0]                   config_buff;
    reg     [15:0]                  n_buff;
    reg     [5:0]                   nyq_data_count;
    reg     [NYQ_TRUNK_VALUE-1:0]   nyq_data_shift_reg;
    reg     [15:0]                  busy_count;
    wire                            en_nyq_count;
    reg                             en_nyq_sck;
    reg     [5:0]                   filt_data_count;
    reg     [14:0]                  dsf_avg_count;
    wire                            en_filt_count;
    reg                             rd_filt_flag;
    reg     [FILT_TRUNK_VALUE-1:0]  filt_data_shift_reg;
    wire                            set_dsf_avg_count;
    wire                            en_dsf_avg_count;
    reg                             en_filt_sck;
    reg     [14:0]                  dsf_avg_sample_num;
    reg     [11:0]                  mosi;

    // One Hot FSM
    localparam IDLE                 = 4'b0001;
    localparam WAIT_4_BUSY          = 4'b0010;
    localparam GET_DATA             = 4'b0100;
    localparam GET_DATA_WITH_SYNC   = 4'b1000;

    always @ (posedge sys_clk or negedge reset_n)
        begin
            if(!reset_n)
                state <= IDLE;
            else
                begin
                    case (state)
                        IDLE:
                            if (go)
                                state <= WAIT_4_BUSY;
                        WAIT_4_BUSY:
                            begin
                                if ((busy_count == 16'b0) && busy)  // Busy should be low by now
                                    state <= IDLE;
                                else if ((busy_count == 16'b0) && sync_flag)
                                    state <= GET_DATA_WITH_SYNC;
                                else if ((busy_count == 16'b0) && (!sync_flag))
                                    state <= GET_DATA;
                            end
                        GET_DATA:
                            if (nyq_data_count == NYQ_TRUNK_VALUE - 1)
                                state <= IDLE;
                        GET_DATA_WITH_SYNC:
                           if (nyq_data_count == NYQ_TRUNK_VALUE - 1)
                                state <= IDLE;
                        default:
                            state <= IDLE;
                    endcase
                end
        end

    // Flag a sync request when requested with a go
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if (!reset_n)
                sync_flag <= 1'b0;
            else if (sync)
                sync_flag <= 1'b0;
            else if ((state == IDLE && sync_req_recfg && go) || dsf_avg_count == 14'b0)
                sync_flag <= 1'b1;
        end

    // Store the configuration word with a go
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if (!reset_n)
                config_buff <= 10'b00010110;
            else if (state == IDLE && go)
                config_buff <= cfg;
        end

    // Store the averaging ratio with a go
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if(!reset_n)
                n_buff <= 16'b0;
            else if(state == IDLE && go)
                n_buff <= n;
        end

    // // Generate the mclk signal with an SR latch
    assign mclk = ~(r | q_n);
    assign q_n  = ~(s | mclk);
    assign s = go & (state == IDLE);
    assign r = ((state == GET_DATA)             ||
                (state == GET_DATA_WITH_SYNC)   ||
                !reset_n) ? 1'b1 : 1'b0;

    // Counter for busy signal timing
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if(!reset_n)
                busy_count <= NUM_OF_CLK_PER_BSY + DFF_CYCLE_COMP - 1;
            else if (state == IDLE)
                busy_count <= NUM_OF_CLK_PER_BSY + DFF_CYCLE_COMP - 1;
            else if (en_busy_count)
                busy_count <= busy_count - 1'b1;
        end

    // Generate the enable busy count
    assign en_busy_count = ((state == WAIT_4_BUSY) && (busy_count != 16'b0)) ? 1'b1 : 1'b0;

    // Generate the enable Nyquist count
    assign en_nyq_count = ((state == GET_DATA) || (state == GET_DATA_WITH_SYNC)) && (nyq_data_count < NYQ_TRUNK_VALUE);

    // Count Nyquist data in
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if (!reset_n)
                nyq_data_count <= 6'b0;
            else if (state == IDLE)
                nyq_data_count <= 6'b0;
            else if (en_nyq_count)
                nyq_data_count <= nyq_data_count + 1'b1;
        end

    // Nyquist data in shift in register
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if(!reset_n)
                nyq_data_shift_reg <= 0;
            else if(en_nyq_count)
                nyq_data_shift_reg <= {nyq_data_shift_reg[NYQ_TRUNK_VALUE-2:0], sdo_nyq};
        end

    // Generated the gated clock for Nyquist data
    always @ (negedge sck_in or negedge reset_n)
        begin
            if (!reset_n)
                en_nyq_sck <= 1'b0;
            else if (en_nyq_count || state == GET_DATA || state == GET_DATA_WITH_SYNC)
                en_nyq_sck <= 1'b1;
            else
                en_nyq_sck <= 1'b0;
         end
    assign sck_nyq = (en_nyq_sck) ? sck_in : 1'b0;

    // The rdl Nyquist signal can be continuously be active low
    assign rdl_nyq = 1'b0;

    // Generate the valid Nyquist data signal after all data has been read
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if(!reset_n)
                valid_nyq <= 1'b0;
            else if((nyq_data_count == NYQ_TRUNK_VALUE))
                valid_nyq <= 1'b1;
            else
                valid_nyq <= 1'b0;
        end

    // Connects the shift register to the data Nyquist out
    // This keeps the msb of data in to the msb data out with
    // different width sift registers
    genvar i;
    generate
        for ( i = 31; i >= 0 ; i = i - 1)
            begin : assign_nyq
                if(NYQ_TRUNK_VALUE - (32-i) >= 0)
                    begin
                        always @ (posedge sys_clk or negedge reset_n)
                            begin
                                if(!reset_n)
                                    data_nyq[i] <= 1'b0;
                                else
                                    begin
                                        if((nyq_data_count == NYQ_TRUNK_VALUE ))
                                            data_nyq[i] <= nyq_data_shift_reg[NYQ_TRUNK_VALUE - (32 - i)];
                                        else
                                            data_nyq[i] <= data_nyq[i];
                                    end
                            end
                    end
                else
                    begin
                        always @ (posedge sys_clk or negedge reset_n)
                            begin
                                data_nyq[i] <= 1'b0;
                            end
                    end
            end
    endgenerate

    // The sample counter input mux
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if(!reset_n)
                dsf_avg_sample_num <= 14'd63;
            else
                begin
                    if (cfg[3:0] == 4'b0111)
                        dsf_avg_sample_num <= n;
                    else
                        // Convert the DSF code for the counter
                        dsf_avg_sample_num <= (15'b1 << cfg[7:4]);
                end
        end

    // Generate a sync signal after a busy
    assign sync = state == GET_DATA_WITH_SYNC || (dsf_avg_count == 14'b0 && state == GET_DATA);

    // Keep track of samples into the controller
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if (!reset_n)
                dsf_avg_count <= 15'd63;
            else if (set_dsf_avg_count)
                dsf_avg_count <= dsf_avg_sample_num;
            else if (en_dsf_avg_count)
                dsf_avg_count <= dsf_avg_count - 1'b1;
        end
    assign en_dsf_avg_count = s && dsf_avg_count != 14'b0;
    assign set_dsf_avg_count = state == GET_DATA_WITH_SYNC;

    // Send error if DSF is not correct
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if(!reset_n)
                error <= 1'b0;
            else if(sync_flag)
                error <= 1'b0;
            else if ((dsf_avg_count != 0) && drdy_n)
                error <= 1'b1;
            else if ((dsf_avg_count == 0) && !drdy_n && state == WAIT_4_BUSY && busy)
                error <= 1'b1;
            else if(state == IDLE)
                error <= 1'b0;
        end

    // Flag for reading the filtered data over multiple reads
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if (!reset_n)
                rd_filt_flag <= 1'b0;
            else if (filt_data_count == FILT_TRUNK_VALUE-1)
                rd_filt_flag <= 1'b0;
            else if (sync_flag)
                rd_filt_flag <= 1'b1;
        end

    // The rdl filtered signal should be active low when obtaining data
    assign rdl_filt = !rd_filt_flag;

    // Generated the gated clock for filtered data
    always @ (negedge sck_in or negedge reset_n)
        begin
            if (!reset_n)
                en_filt_sck <= 1'b0;
            else if (en_filt_count || state == GET_DATA_WITH_SYNC)
                en_filt_sck <= 1'b1;
            else
                en_filt_sck <= 1'b0;
         end
    assign sck_filt  =  (en_filt_sck&(!mclk)) ? sck_in : 1'b0;

    // Count for filtered data
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if (!reset_n)
                filt_data_count <= 6'b0;
            else if (!rd_filt_flag)
                filt_data_count <= 6'b0;
            else if (rd_filt_flag && (state != WAIT_4_BUSY) & (!mclk))
                filt_data_count <= filt_data_count + 1'b1;
        end
    assign en_filt_count = rd_filt_flag && (state != WAIT_4_BUSY) && (!mclk);

    // Filtered data shift in register
    always @ (posedge sck_in or negedge reset_n)
        begin
            if(!reset_n)
                filt_data_shift_reg <= 0;
            else if (rd_filt_flag && filt_data_count < FILT_TRUNK_VALUE && (state != WAIT_4_BUSY) && !mclk)
                filt_data_shift_reg <= {filt_data_shift_reg[FILT_TRUNK_VALUE-2:0], sdo_filt};
        end

    // Connects the shift register to the data filtered out
    // This keeps the msb of data in to the msb data out with
    // different width sift registers
    genvar j;
    generate
        for ( j = 53; j >= 0 ; j = j - 1)
            begin : assign_filt
                if(FILT_TRUNK_VALUE - (54-j) >= 0)
                    begin
                        always @ (posedge sys_clk or negedge reset_n)
                            begin
                                if(!reset_n)
                                    data_filt[j] <= 1'b0;
                                else
                                    begin
                                        if((filt_data_count == FILT_TRUNK_VALUE))
                                            data_filt[j] <= filt_data_shift_reg[FILT_TRUNK_VALUE - (54 - j)];
                                        else
                                            data_filt[j] <= data_filt[j];
                                    end
                            end
                    end
                else
                    begin
                        always @ (posedge sys_clk)
                            begin
                                data_filt[j] <= 1'b0;
                            end
                    end
            end
    endgenerate

    // Generate the valid filtered data signal
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if(!reset_n)
                valid_filt <= 1'b0;
            else if(filt_data_count == FILT_TRUNK_VALUE)
                valid_filt <= 1'b1;
            else
                valid_filt <= 1'b0;
        end

    // Generate the sdi filt signal

    // Edge dedge detector for sync_flag
    reg sync_flag_d1;
    wire rise_edge_sync_flag;
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if(!reset_n)
                sync_flag_d1 <= 1'b0;
            else
                sync_flag_d1 <= sync_flag;
        end
    assign rise_edge_sync_flag = sync_flag & (!sync_flag_d1);

    // Send sdo 
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if(!reset_n)
                mosi <= 12'b0;
            else if (rise_edge_sync_flag)
                mosi <= {2'b10,cfg};
            else if (en_filt_sck)
                mosi <= {mosi[10:0],1'b0};
        end
    assign sdi_filt = mosi[11];
endmodule