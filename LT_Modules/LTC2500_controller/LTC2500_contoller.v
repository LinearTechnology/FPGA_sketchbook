`timescale 1ns / 10ps   // Each unit time is 1ns and the time precision is 10ps

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
    reset_n,            // Reset active low
    go,                 // Start a ADC read
    sync_req_recfg,     // Request a synchronisation or reconfigure ADC
    cfg,                // The configuration word 
    n,                  // The averaging ratio
    pre_mode,           // The preset mode

    // LTC2500 Signals
    // Port A
    rdl_filt,       // Read data low for the filtered data port
    sck_filt,       // Gated clock for filtered data port
    sdi_filt,       // Serial data in for the ADC's filtered port
    sdo_filt,       // Serial data out for the ADC's filtered port
    // Port B
    rdl_nyq,        // Read data low for the Nyquist data port
    sck_nyq,        // Gated clock for Nyquist data port
    sdo_nyq,        // Serial data out for the ADC's Nyquist port

    busy,           // The ADC is busy with a conversion
    drdy_n,         // The ADC is not ready for filtered data
    mclk,           // The conversion clock
    sync,           // The synchronizing signal for the ADC
    pre,            // The pre signal is used to configure the filtered data
                    // into two settings, depending on SDI logic level.
    // Streaming output
    data_nyq,       // Parallel Nyquist data out
    valid_nyq,      // The Nyquist data is valid

    data_filt,      // Parallel filtered data out
    valid_filt,     // Parallel common mode filtered data out
    error           // The filtered data is valid
);

    parameter DFF_CYCLE_COMP        = 1;    // If using flip flop a delay in cycle is needed
    parameter NUM_OF_CLK_PER_BSY    = 67;   // Number of sys_clk cycles to make 675ns
                                            // 675ns / (1/100 Mhz) ~ 68 cycles (rounded up) then -1
    parameter TRUNK_VALUE           = 32;   // Truncated data count value per mclk

    // Port declaration
    input               sys_clk;
    input               reset_n;
    input               go;
    input               sync_req_recfg;
    input   [9:0]       cfg;
    input   [13:0]      n;
    input               pre_mode;
    output              rdl_filt;
    output              sck_filt;
    output  reg         sdi_filt;
    input               sdo_filt;
    output              rdl_nyq;
    output              sck_nyq;
    input               sdo_nyq;
    input               busy;
    input               drdy_n;
    output              mclk;
    output              sync;
    output              pre;
    output  reg [31:0]  data_nyq;
    output  reg         valid_nyq;
    output  reg [53:0]  data_filt;
    output  reg         valid_filt;
    output  reg         error;

    // Internal signals
    wire                        q_n;
    wire                        r;
    wire                        s;
    wire                        en_busy_count;
    reg     [4:0]               state;
    reg                         sync_flag;
    reg     [9:0]               config_buff;
    reg     [15:0]              n_buff;
    reg     [5:0]               nyq_data_count;
    reg     [TRUNK_VALUE-1:0]   nyq_data_shift_reg;
    reg     [15:0]              busy_count;
    wire                        en_nyq_count;
    reg                         en_nyq_sck;
    reg     [5:0]               filt_data_count;
    reg     [14:0]              dsf_avg_count;
    wire                        en_filt_count;
    reg                         rd_filt_flag;
    reg     [53:0]              filt_data_shift_reg;
    wire                        set_dsf_avg_count;
    wire                        en_dsf_avg_count;
    reg                         en_filt_sck;
//    wire    [3:0]               power_shift;
    reg     [14:0]              dsf_avg_sample_num;

    // One Hot FSM
    localparam IDLE                 = 5'b00001;
    localparam WAIT_4_BUSY          = 5'b00010;
    localparam SEND_ERROR           = 5'b00100;
    localparam GET_DATA             = 5'b01000;
    localparam GET_DATA_WITH_SYNC   = 5'b10000;

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
                                    state <= SEND_ERROR;
                                else if ((busy_count == 16'b0) && sync_flag)
                                    state <= GET_DATA_WITH_SYNC;
                                else if ((busy_count == 16'b0) && !sync_flag)
                                    state <= GET_DATA;
                            end
                        SEND_ERROR:
                            state <= IDLE;
                        GET_DATA:
                            if (nyq_data_count == TRUNK_VALUE - 2)
                                state <= IDLE;
                        GET_DATA_WITH_SYNC:
                           if (nyq_data_count == TRUNK_VALUE - 2)
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
                (state == SEND_ERROR)           ||
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
    assign en_nyq_count = ((state == GET_DATA) || (state == GET_DATA_WITH_SYNC)) && (nyq_data_count < TRUNK_VALUE);

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
            else if(en_nyq_count || (busy_count == 16'b0 && state == WAIT_4_BUSY))
                nyq_data_shift_reg <= {nyq_data_shift_reg[TRUNK_VALUE-2:0], sdo_nyq};
        end

    // Generated the gated clock for Nyquist data
    always @ (negedge sys_clk or negedge reset_n)
        begin
            if (!reset_n)
                en_nyq_sck <= 1'b0;
            else if (en_nyq_count)
                en_nyq_sck <= 1'b1;
            else
                en_nyq_sck <= 1'b0;
         end
    assign sck_nyq = (en_nyq_sck || state == GET_DATA || state == GET_DATA_WITH_SYNC) ? sys_clk : 1'b0;

    // Send the pre mode signal directly to the ADC
    assign pre = pre_mode;

    // The rdl Nyquist signal can be continuously be active low
    assign rdl_nyq = 1'b0;

    // Generate the valid Nyquist data signal after all data has been read
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if(!reset_n)
                valid_nyq <= 1'b0;
            else if((nyq_data_count == TRUNK_VALUE - 1) && (state == IDLE))
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
                if(TRUNK_VALUE - (32-i) >= 0)
                    begin
                        always @ (posedge sys_clk)
                            begin
                                if((nyq_data_count == TRUNK_VALUE - 1))
                                    data_nyq[i] <= nyq_data_shift_reg[TRUNK_VALUE - (32 - i)];
                                else
                                    data_nyq[i] <= data_nyq[i];
                            end
                    end
                else
                    begin
                        always @ (posedge sys_clk)
                            begin
                                data_nyq[i] <= 1'b0;
                            end
                    end
            end
    endgenerate

    // The sample counter input mux
    always @ *
        begin
            if(!reset_n)
                dsf_avg_sample_num = 14'd63;
            else
                begin
                    if (pre_mode)
                        begin
                            if(!sdi_filt)
                                dsf_avg_sample_num = n;
                            else
                                dsf_avg_sample_num = 14'd63;
                        end
                    else
                        begin
                            if (config_buff[3:0] == 4'b0111)
                                dsf_avg_sample_num = n;
                            else
                                // Convert the DSF code for the counter
                                dsf_avg_sample_num = (15'b1 << config_buff[7:4]);
                        end
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
            else if ((dsf_avg_count != 0) && drdy_n)
                error <= 1'b1;
            else if ((dsf_avg_count == 0) && !drdy_n && state == WAIT_4_BUSY && busy)
                error <= 1'b1;
            else
                error <= 1'b0;
        end

    // Flag for reading the filtered data over multiple reads
    always @ (negedge sys_clk or negedge reset_n)
        begin
            if (!reset_n)
                rd_filt_flag <= 1'b0;
            else if (filt_data_count > 6'd53)
                rd_filt_flag <= 1'b0;
            else if (sync_flag)
                rd_filt_flag <= 1'b1;
        end

    // The rdl filtered signal should be active low when obtaining data
    assign rdl_filt = !rd_filt_flag;

    // Generated the gated clock for filtered data
    always @ (negedge sys_clk or negedge reset_n)
        begin
            if (!reset_n)
                en_filt_sck <= 1'b0;
            else if (en_filt_count)
                en_filt_sck <= 1'b1;
            else
                en_filt_sck <= 1'b0;
         end
    assign sck_filt = en_filt_sck & rd_filt_flag & sys_clk;

    // Count for filtered data
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if (!reset_n)
                filt_data_count <= 6'b0;
            else if (!rd_filt_flag)
                filt_data_count <= 6'b0;
            else if (en_filt_count)
                filt_data_count <= filt_data_count + 1'b1;
        end
    assign en_filt_count = (state != IDLE) && (rd_filt_flag && busy_count == 0);

    // Filtered data shift in register
    always @ (posedge sck_filt or negedge reset_n)
        begin
            if(!reset_n)
                filt_data_shift_reg <= 54'b0;
            else if (filt_data_count <= 6'd54 && busy_count == 0)
                filt_data_shift_reg <= {filt_data_shift_reg[52:0], sdo_filt};
        end

    // Filtered data out gated
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if(!reset_n)
                data_filt <= 54'b0;
            else if(filt_data_count == 6'd54)
                data_filt <= filt_data_shift_reg;
            else
                data_filt <= data_filt;
        end

    // Generate the valid filtered data signal
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if(!reset_n)
                valid_filt <= 1'b0;
            else if(filt_data_count == 6'd54)
                valid_filt <= 1'b1;
            else
                valid_filt <= 1'b0;
        end

    // Generate the sdi filt signal
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if (!reset_n)
                sdi_filt = 1'b0;
            else
                begin
                    if (pre_mode)
                        sdi_filt = config_buff[9];
                    else
                        begin
                            if(state == GET_DATA_WITH_SYNC || sync_flag)
                                begin
                                    if (filt_data_count == 6'd0)
                                        sdi_filt = 1'b1;
                                    else if (filt_data_count == 6'd1)
                                        sdi_filt = 1'b0;
                                    else if (filt_data_count < 6'd11)
                                        sdi_filt = config_buff[11-filt_data_count];
                                    else
                                        sdi_filt = 1'b0;
                                end
                        end
                end
        end

endmodule