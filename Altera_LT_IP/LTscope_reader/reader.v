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
        The purpose of this module is to read the RAM from a triggered location
        to the end of memory, then read from the start of memory to the triggered
        location. This flatens the ring buffer.
    Signals Information:
        start:      Starts the reader
        trig_addr:  The triggered event address location
        done:       Indicates that the reader has completed reading
        depth:      The memory depth. This should be a multiple of the 
                    packet size(64 bytes -1) ex. 255 is valid, 256 is not valid
    FIFO Interface: 
        data:           data read
        fifo_empty_n:   FIFO not empty
        rdreq:          request a read
    
    Avalon Memory Master Interface
        address:            address location
        read:               read request
        byteenable:         byteenable 
        wait_request:       wait request
        read_data_valid:    data valid
        read_data:          data
*/

module reader
(
    clk,
    reset_n,
    start,
    done,
    start_addr,
    rd_length,
    data,
    fifo_empty_n,
    rdreq,
    address,
    read,
    byteenable,
    wait_request,
    read_data_valid,
    read_data
);
    parameter RAM_DEPTH = 32;
 
    input           clk;
    input           reset_n;
    input           start;
    output          done;

    input   [31:0]  start_addr;
    input   [31:0]  rd_length;

    output  [31:0]  data;
    output          fifo_empty_n;
    input wire      rdreq;
   
    // Mem interface signals
    output  [31:0]  address;
    output          read;
    output  [3:0]   byteenable;
    input           wait_request;
    input           read_data_valid;
    input   [31:0]  read_data;

    // Internal signals
    wire            reader_done;
    wire            reader_done_early;
    wire            user_data_available;
    wire            start_rise_edge;
    reg             start_d1;

    always @ (posedge clk)
        begin
            if(!reset_n)
                start_d1 <= 1'b1;
            else
                start_d1 <= start;
        end
    assign start_rise_edge = start & !start_d1;
    
    latency_aware_read_master
        #(.ADDRESSWIDTH(RAM_DEPTH))
    reader
    (
        .clk    (clk),
        .reset  (!reset_n),

        // Control inputs and outputs
        .control_fixed_location (1'b0),
        .control_read_base      (start_addr),
        .control_read_length    (rd_length),
        .control_go             (start_rise_edge),
        .control_done           (reader_done),
        .control_early_done     (reader_done_early),
  
        // User logic inputs and outputs
        .user_read_buffer       (rdreq),
        .user_buffer_data       (data),
        .user_data_available    (user_data_available),
  
        // Master inputs and outputs
        .master_address         (address),
        .master_read            (read),
        .master_byteenable      (byteenable),
        .master_readdata        (read_data),
        .master_readdatavalid   (read_data_valid),
        .master_waitrequest     (wait_request)
    );
 

    assign fifo_empty_n = user_data_available;
    assign done = reader_done | reader_done_early;
endmodule
