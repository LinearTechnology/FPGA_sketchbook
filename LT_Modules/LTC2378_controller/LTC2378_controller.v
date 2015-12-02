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
        The purpose of this module is to interface to the LTC2378.
*/

module LTC2378_controller
(
    // Control 
    sys_clk,    // The digital clock
    sck_in,     // The serial clock from PLL to be gated for the sck of the LTC2378
    reset_n,    // Reset active low
    go,         // Start a ADC read

    // LTC2378 Signals
    LTC2378_rdl,        // Read data low
    LTC2378_sck,        // Gated clock for Nyquist data port
    LTC2378_sdo,        // Serial data out for the ADC's Nyquist port
    LTC2378_busy,       // The ADC is busy with a conversion
    LTC2378_cnv,        // The conversion clock

    // Streaming output
    data,       // Parallel Nyquist data out
    valid,      // The Nyquist data is valid
    error       // The filtered data is valid
);

    ///////////////////////////////////////////////////////////////////////////
    // Module parameters
    ///////////////////////////////////////////////////////////////////////////

    parameter DFF_CYCLE_COMP        = 1;    // If using flip flop a delay in cycle is needed
    parameter NUM_OF_CLK_PER_BSY    = 63;   // Number of sys_clk cycles to make 675ns
                                            // 675ns / (1/100 Mhz) ~ 64 cycles (rounded up) then -1

    ///////////////////////////////////////////////////////////////////////////
    // Port declaration
    ///////////////////////////////////////////////////////////////////////////

    // Control 
    input               sys_clk;
    input               sck_in;
    input               reset_n;
    input               go;

    // LTC2378 Signals
    output              LTC2378_rdl;
    output              LTC2378_sck;
    input               LTC2378_sdo;
    input               LTC2378_busy;
    output              LTC2378_cnv;

    // Streaming output
    output reg  [19:0]  data;
    output reg          valid;
    output reg          error;

    ///////////////////////////////////////////////////////////////////////////
    // Internal signals
    ///////////////////////////////////////////////////////////////////////////

    reg     [2:0]   state;
    reg     [15:0]  busy_count;
    wire            en_busy_count;
    reg     [4:0]   data_count;
    wire            en_count;
    reg             en_sck;
    reg     [19:0]  data_shift_reg;
    wire            q_n;
    wire            s;
    wire            r;
    
    //*************************************************************************

    // One Hot FSM
    localparam IDLE                 = 3'b001;
    localparam WAIT_4_BUSY          = 3'b010;
    localparam GET_DATA             = 3'b100;

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
                                if ((busy_count == 16'b0) && LTC2378_busy)  // Busy should be low by now
                                    state <= IDLE;
                                else if (busy_count == 16'b0)
                                    state <= GET_DATA;
                            end
                        GET_DATA:
                            if (data_count == 5'b0)
                                state <= IDLE;
                        default:
                            state <= IDLE;
                    endcase
                end
        end

    //*************************************************************************

    // Counter for busy signal timing
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if(!reset_n)
                busy_count <= NUM_OF_CLK_PER_BSY + DFF_CYCLE_COMP - 1;
            else if(state == IDLE)
                busy_count <= NUM_OF_CLK_PER_BSY + DFF_CYCLE_COMP - 1;
            else if (en_busy_count)
                busy_count <= busy_count - 1'b1;
        end

    // Generate the enable busy count
    assign en_busy_count = ((state == WAIT_4_BUSY) && (busy_count > 16'b0));

    //*************************************************************************

    // Data in count
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if (!reset_n)
                data_count <= 5'd19;
            else if (state == IDLE)
                data_count <= 5'd19;
            else if (en_count && (data_count > 5'b0))
                data_count <= data_count - 1'b1;
        end

    // Generate the enable count
    assign en_count = state == GET_DATA;

    //*************************************************************************

    // The rdl signal can be continuously be active low
    assign LTC2378_rdl = 1'b0;

    //*************************************************************************
    
    // Generated the gated clock
    always @ (negedge sck_in or negedge reset_n)
        begin
            if (!reset_n)
                en_sck <= 1'b0;
            else if (en_count || state == GET_DATA)
                en_sck <= 1'b1;
            else
                en_sck <= 1'b0;
         end

    assign LTC2378_sck = (en_sck) ? sck_in : 1'b0;

    //*************************************************************************

    // Data shift in register
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if(!reset_n)
                data_shift_reg <= 0;
            else if(en_count)
                data_shift_reg <= {data_shift_reg[18:0], LTC2378_sdo};
        end

    //*************************************************************************

    // Generate the conversion signal with an SR latch
    assign LTC2378_cnv = ~(r | q_n);
    assign q_n  = ~(s | LTC2378_cnv);
    assign s = go & (state == IDLE);
    assign r = (state == GET_DATA) || (!reset_n);

    //*************************************************************************

    // Update data out after the data has been shifted in
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if (!reset_n)
                data <= 20'b0;
            else if ((data_count == 5'b0) && (state == IDLE))
                data <= data_shift_reg;
        end

    //*************************************************************************

    // Generate the valid data signal after all data has been read
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if(!reset_n)
                valid <= 1'b0;
            else if((data_count == 5'b0) && (state == IDLE))
                valid <= 1'b1;
            else
                valid <= 1'b0;
        end

    //*************************************************************************

        // Send error if DSF is not correct
    always @ (posedge sys_clk or negedge reset_n)
        begin
            if(!reset_n)
                error <= 1'b0;
            else if (state == IDLE)
                error <= 1'b0;
            else if ((state != WAIT_4_BUSY) & LTC2378_busy)
                error <= 1'b1;
        end
endmodule