`timescale 1ns / 10ps   // Each unit time is 1ns and the time precision is 10ps

/*
    Created by: Noe Quintero
    E-mail: nquintero@linear.com

    Copyright (c) 2013, Linear Technology Corp.(LTC)
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
        The purpose of this module is to controll the LTScope.
    
*/
 
module ltscope_controller
(
    clk,
    reset_n,
 
    // CSR
    ring_buff_go,
    ring_buff_addr,
    read_go,
    read_start_addr,
    read_length,
    read_done,
 
    // Avalon ST sink
    snk_data,
    snk_valid,
    snk_ready,
 
    // Avalon ST source
    src_data,
    src_valid,
    src_ready,
 
    // Avalon MM interface
    write,
    writedata,
    waitrequest,
    address,
    read,
    byteenable,
    readdatavalid,
    readdata
);
    parameter ADDRESS_DEPTH = 29; // Cyclone C5G demo board
 
    input               clk;
    input               reset_n;
 
    // CSR
    input               ring_buff_go;
    output      [31:0]  ring_buff_addr;
    input               read_go;
    input       [31:0]  read_start_addr;
    input       [31:0]  read_length;
    output              read_done;

    // Avalon ST sink
    input       [31:0]  snk_data;
    input               snk_valid;
    output              snk_ready;
 
    // Avalon ST source
    output      [31:0]  src_data;
    output              src_valid;
    input               src_ready;
 
    // Avalon MM interface
    output              write;
    output      [31:0]  writedata;
    input               waitrequest;
    output      [31:0]  address;
    output              read;
    output      [3:0]   byteenable;
    input               readdatavalid;
    input       [31:0]  readdata;
 
    // Internal signals
    wire                fifo_empty_n;
    wire                rdreq;
    wire        [31:0]  ring_address;
    wire        [31:0]  read_address;
 
    // The ring buffer module
    ring_buffer 
        #(.RAM_DEPTH(ADDRESS_DEPTH))
    main_ring_buffer
    (
        .clk(clk),
        .reset_n(reset_n),
        .start(ring_buff_go),
        .data(snk_data),
        .valid(snk_valid),
        .ready(snk_ready),
        .write(write),
        .writedata(writedata),
        .waitrequest(waitrequest),
        .address(ring_address)
    );
 
    // The reader module
    reader 
        #(.RAM_DEPTH(ADDRESS_DEPTH))
    main_reader
    (
        .clk                (clk),
        .reset_n            (reset_n),
        .start              (read_go),
        .done               (read_done),
        .start_addr         (read_start_addr),
        .rd_length          (read_length),
        .data               (src_data),
        .fifo_empty_n       (fifo_empty_n),
        .rdreq              (rdreq),
        .address            (read_address),
        .read               (read),
        .byteenable         (byteenable),
        .wait_request       (waitrequest),
        .read_data_valid    (readdatavalid),
        .read_data          (readdata)
    );

    assign address          = (ring_buff_go) ? ring_address : read_address;
    assign src_valid        = (!reset_n) ? 1'b0 : fifo_empty_n;
    assign rdreq            = (!reset_n) ? 1'b0 : fifo_empty_n && src_ready;
    assign ring_buff_addr   = ring_address;
endmodule
  