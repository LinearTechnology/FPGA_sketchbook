`timescale 1ns / 10ps   // Each unit time is 1ns and the time precision is 10ps

/*
    Created by: Noe Quintero
    E-mail: nquintero@linear.com

    Copyright (c) 2016, Linear Technology Corp.(LTC)
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
        The purpose of this module is to provide a simple interface to the LTC2358.
*/

module LTC2358_controller
(
    // Control Signals
    clk,            // Module main clock 
    shft_clk_in,    // Clock to be gated. This should lead the system clock when 
                    // running at higher clock speeds.
    reset_n,        // Reset active low
    cnfg,           // Configure word
    go,             // Start an ADC read

    // LTC2358 Signals
    LTC2358_sck,    // The gated clock
    LTC2358_busy,   // The ADC is busy with a conversion
    LTC2358_cnv,    // The conversion signals
    LTC2358_sdi,    // LTC2358 configuration signal
    LTC2358_sdo,    // LTC2358 data
    
    // Streaming Output
    data,       // Parallel data out
    valid,      // The data is valid
    error       // An error has occord with the module
);

    ///////////////////////////////////////////////////////////////////////////
    // Module parameters
    ///////////////////////////////////////////////////////////////////////////

    parameter DFF_CYCLE_COMP        = 1;    // If using flip flop a delay in cycle is needed
    parameter NUM_OF_CLK_PER_BSY    = 219;  // Number of system clk cycles to make 4400ns
                                            // 4400ns / (1/50 Mhz) ~ 220 cycles (rounded up) then -1
    parameter NUM_OF_CLK_PERCNV_H   = 2;    // Number of system clk cycles to have conver high
                                            // 60ns / (1/50 Mhz) ~ 3 cycles then -1
    parameter NUM_OF_LANES          = 8;    // Valid parameters are 1, 2, 4, 8

    // Enforce the valid parameter options with the genreate statement
    generate
        if(NUM_OF_LANES != 1 && NUM_OF_LANES != 2 && NUM_OF_LANES != 4 && NUM_OF_LANES != 8)
            illegal_parameter_condition_will_instantiate_this non_existing_module();
    endgenerate
    
    ///////////////////////////////////////////////////////////////////////////
    // Port declaration
    ///////////////////////////////////////////////////////////////////////////

    // Control Signals
    input                   clk;
    input                   shft_clk_in;
    input                   reset_n;
    input       [23:0]      cnfg;
    input                   go;

    // LTC2358 Signals
    output                          LTC2358_sck;
    input                           LTC2358_busy;
    output                          LTC2358_cnv;
    output                          LTC2358_sdi;
    input       [NUM_OF_LANES-1:0]  LTC2358_sdo;
    
    // Streaming Output
    output  reg [8*24-1:0]  data;
    output  reg             valid;
    output  reg             error;

    ///////////////////////////////////////////////////////////////////////////
    // Internal signals
    ///////////////////////////////////////////////////////////////////////////

    reg         [1:0]   state;
    reg         [15:0]  busy_count;
    reg         [7:0]   data_count;
    reg         [7:0]   cnv_count;
    wire                q_n;
    wire                s;
    wire                r;
    reg                 en_sck;
    wire                en_busy_count;
    wire                en_count;
    reg         [(192/NUM_OF_LANES)-1:0] data_shift_reg [0:NUM_OF_LANES-1];

    //*************************************************************************

    // One Hot FSM
    localparam IDLE                 = 3'b001;
    localparam WAIT_4_BUSY          = 3'b010;
    localparam GET_DATA             = 3'b100;

    always @ (posedge clk or negedge reset_n)
        begin
            if(!reset_n)
                state <= IDLE;
            else
                begin
                    case(state)
                        IDLE:
                            if(go)
                                state <= WAIT_4_BUSY;
                        WAIT_4_BUSY:
                            begin
                                if ((busy_count == 16'b0) && LTC2358_busy)  // Busy should be low by now
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

    // Conversion high time counter
    always @ (posedge clk or negedge reset_n)
        begin
            if(!reset_n)
                cnv_count <= NUM_OF_CLK_PERCNV_H;
            else if(state == IDLE)
                cnv_count <= NUM_OF_CLK_PERCNV_H;
            else if(state == WAIT_4_BUSY)
                cnv_count <= cnv_count - 1'b1;
        end

    //*************************************************************************

    // Generate the conversion signal with an SR latch
    assign LTC2358_cnv = ~(r | q_n);
    assign q_n  = ~(s | LTC2358_cnv);
    assign s = go & (state == IDLE);
    assign r = (cnv_count == 0) || (!reset_n);

    //*************************************************************************

    // Counter for busy signal timing
    always @ (posedge clk or negedge reset_n)
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

    // Data in coounter set to 24 counts
    always @ (posedge clk or negedge reset_n)
        begin
            if (!reset_n)
                data_count <= (192 / NUM_OF_LANES)-1;
            else if (state == IDLE)
                data_count <= (192 / NUM_OF_LANES)-1;
            else if (en_count && (data_count > 0))
                data_count <= data_count - 1'b1;
        end

    // Generate the enable count
    assign en_count = state == GET_DATA;

    //*************************************************************************

    // Generated the gated clock
    always @ (negedge shft_clk_in or negedge reset_n)
        begin
            if (!reset_n)
                en_sck <= 1'b0;
            else if (en_count || state == GET_DATA)
                en_sck <= 1'b1;
            else
                en_sck <= 1'b0;
         end

    assign LTC2358_sck = en_sck & shft_clk_in;

    //*************************************************************************

    // Data shift in registers
    // Generates the shift in registers.
    // data_shift_reg[x][y] - x is the shift reg number, y is the elements of the 
    // shift register.
    genvar i;
    generate
        for(i = 0; i <= NUM_OF_LANES-1; i = i + 1)
            begin: shift_in_array
                always @ (posedge clk or negedge reset_n)
                    begin
                        if(!reset_n)
                            data_shift_reg[i] <= 0;
                        else if(en_count)
                            data_shift_reg[i] <= {data_shift_reg[i][(192 / NUM_OF_LANES)-2:0], LTC2358_sdo[i]};
                    end
            end
    endgenerate

    //*************************************************************************

    // Update data out after the data has been shifted in
    // MSB -> LSB
    // CH0, CH1, CH2, CH3, CH4, CH5, CH6, CH7 
    genvar j;
    generate
        for(j = NUM_OF_LANES; j >= 1; j = j - 1)
            begin: data_out_array
                always @ (posedge clk or negedge reset_n)
                    begin
                        if (!reset_n)
                            data[j*(192/NUM_OF_LANES)-1 : 192/NUM_OF_LANES*(j-1)] <= 0;
                        else if ((data_count == 0) && (state == IDLE))
                            data[j*(192/NUM_OF_LANES)-1 : 192/NUM_OF_LANES*(j-1)] <= data_shift_reg[(NUM_OF_LANES)-j];
                    end
            end
    endgenerate

    //*************************************************************************

    // Generate the valid data signal after all data has been read
    always @ (posedge clk or negedge reset_n)
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
    always @ (posedge clk or negedge reset_n)
        begin
            if(!reset_n)
                error <= 1'b0;
            else if (state == IDLE)
                error <= 1'b0;
            else if ((state == GET_DATA) & LTC2358_busy)
                error <= 1'b1;
        end
endmodule