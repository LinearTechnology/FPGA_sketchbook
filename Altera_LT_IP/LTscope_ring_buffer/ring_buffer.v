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
        The purpose of this module is to use RAM as an ring buffer.
        
    Signals Information:
        Controls/Satus Signals
            start:         Starts the ring buffer
    
        Avalon Streaming Interface
      data:          Data in
      valid:         Data valid
      ready:         Ring buffer is ready for data

        Avalon Memory Master Interface
            write:         Initiate a write 
            writedata:     Data to be writen
            waitrequest:   Wait for memory
            address:       Address location
*/

module ring_buffer
(
    clk,
    reset_n,
    start,
    data,
    valid,
    ready,
    write,
    writedata,
    waitrequest,
    address
);
    parameter RAM_DEPTH = 32;
    input             clk;
    input             reset_n;
    input             start;
    input      [31:0] data;
    input             valid;
    output            ready;

    // Mem interface signals
    output          write;
    output  [31:0]  writedata;
    input           waitrequest;
    output  [31:0]  address;

    // Internal signals
    wire [31:0] addresser_addr;
    wire        writer_ready;
    wire        addr_en;
    wire        writer_go;
  
    // The ring buffer addresser
    ring_buffer_addr 
        #(.DEPTH(RAM_DEPTH))
    addresser
    (
        .clk(clk),
        .rstn(reset_n),
        .en(addr_en),
        .addr(addresser_addr)
    );

    // The RAM master signals
    mem_master writer
    (
        .clk(clk),
        .resetn(reset_n),
        .data(data),
        .addr(addresser_addr),
        .go(writer_go),
        .ready(writer_ready),
        .write(write),
        .writedata(writedata),
        .waitrequest(waitrequest),
        .address(address)
    );

    assign writer_go = start & valid;
    assign addr_en =  valid & writer_ready;
    assign ready = writer_ready;
endmodule
