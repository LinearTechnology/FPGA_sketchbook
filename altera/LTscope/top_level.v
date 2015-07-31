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
        LTscope top level
*/

module top_level
(
    CLOCK_125_p,    // System clock
    reset_n,
    
    // DDR RAM signals
    DDR2LP_CA,
    DDR2LP_CKE,
    DDR2LP_CK_n,
    DDR2LP_CK_p,
    DDR2LP_CS_n,
    DDR2LP_DM,
    DDR2LP_DQ,
    DDR2LP_DQS_n,
    DDR2LP_DQS_p,
    DDR2LP_OCT_RZQ,

    // SPI signals
    miso_spi_ext,
    mosi_spi_ext,
    cs_spi_ext,
    sck_spi_ext,

    SW,
    led_rst,    // Reset indicator led
    ledr,
    btn_trig,
    
    // FT2232 signals
    usb_clock,
    usb_rxf_n,
    usb_txe_n,
    usb_data,
    usb_rd_n,
    usb_wr_n,
    usb_oe_n,
    usb_reset_n,
    usb_suspend_n,
    usb_power_en_n,

    // LTC2351 signals
    adc_clk,
    adc_data,
    adc_conv,
    dir_conv,
    bip,
    adc_ch_sel,
    adc_clock
);

    input           CLOCK_125_p;
    input           reset_n;

    input           SW;
    output          led_rst;
    output  [7:0]   ledr;
    input           btn_trig;
    
    assign ledr[6] = adc_fifo_full;

    // DDR RAM Signals
    output  [9:0]   DDR2LP_CA;
    output  [1:0]   DDR2LP_CKE;
    output          DDR2LP_CK_n;
    output          DDR2LP_CK_p;
    output  [1:0]   DDR2LP_CS_n;
    output  [3:0]   DDR2LP_DM;
    inout   [31:0]  DDR2LP_DQ;
    inout   [3:0]   DDR2LP_DQS_n;
    inout   [3:0]   DDR2LP_DQS_p;
    input           DDR2LP_OCT_RZQ;
 
    // SPI Signals
    output          miso_spi_ext;
    input           mosi_spi_ext;
    input           sck_spi_ext;
    input           cs_spi_ext;
 
    // ADC signals
    input           adc_clk;
    input   [2:0]   adc_data;
    output  [2:0]   adc_conv;
    inout   [2:0]   dir_conv;
    output  [2:0]   bip;
    output  [8:0]   adc_ch_sel;
    output  [2:0]   adc_clock;
 
    assign adc_clock = {adc_clk,adc_clk,adc_clk};
    assign adc_ch_sel = 9'b111111111;
    assign bip = 3'b000; 
    assign dir_conv = 3'bZZZ;
 
    // FT2232 Signals
    input           usb_clock;  // 60 MHz provided by the FT2232
    input           usb_rxf_n;  // When RXF_N is high, the FT2232 does not have valid data to read
    input           usb_txe_n;  // When TXE_N is high, the FT2232 is not ready for data
    inout   [7:0]   usb_data;   // FT2232 data bus
    output          usb_rd_n;   // Enables the FT2232 to drive data on the bus
    output          usb_wr_n;   // Enables the FT2232 to read data on the bus
    output          usb_oe_n;   // Output enable allows the FT2232 to drive data on the bus
    input           usb_suspend_n;  // Active low when USB is in suspend mode
    input           usb_power_en_n; // 0: Normal operation, 1: USB SUSPEND mode or device has not been configured
    output          usb_reset_n;    // ft2232 reset

    // Internal signals
    wire    [31:0]  depth;
    wire            delay_rd;
    wire            src_valid;
    wire            src_ready;
    wire    [31:0]  src_data;
    wire            reset;
    wire            fifo_empty;
    wire            fifo_full;
    wire    [31:0]  adc_formatted_data;
    wire    [287:0] adc_parrallel_data;
    wire            adc_formatter_valid;
    wire            adc_formatter_ready;
    wire    [15:0]  sample_rate;
    wire            sys_reset_n;
    wire            sample_rate_go;
    wire    [2:0]   adc_ctrl_valid;
    wire            trig_signal;
    wire            error_signal;
    wire    [31:0]  word_9_data;
    wire            word_9_valid;
    wire            adc_fifo_empty;
    wire            adc_fifo_full;
    wire    [31:0]  adc_fifo_data;
    wire            adc_fifo_valid;
    wire            adc_fifo_ready;
    wire            adc_fifo_rdreq;
    wire            adc_fifo_wrreq;
    wire    [3:0]   en_pio_export;
    wire    [15:0]  sample_rate_pio_export;
    wire            force_trig_pio_export;
    wire    [31:0]  pre_trig_count_value_pio_export;
    wire    [31:0]  post_trig_count_pio_export;
    wire    [31:0]  ltscope_controller_ring_buff_addr;
    wire    [31:0]  ltscope_controller_read_start_addr;
    wire    [31:0]  ltscope_controller_read_length;
    wire            ltscope_controller_read_done;
    wire    [31:0]  pre_trig_count_pio_export;

    // Sample rate controller
    // used to create the go signal for the ADC controllers
    sample_rate_controller sample_rate_c1
    (
        .clk            (adc_clk),
        .reset_n        (sys_reset_n),
        .en             (en_pio_export[0]),
        .sample_rate    (sample_rate_pio_export),
        .go             (sample_rate_go)
    );

    // ADC controllers with flip flop retiming
    LTC2351_controller
        #( .RETIMEING_FF(1) )
    adc_cntr_0
    (
        .clk            (adc_clk),
        .reset_n        (sys_reset_n),
        .go             (sample_rate_go),
        .data_in        (adc_data[0]),
        .conv           (adc_conv[0]),
        .valid          (adc_ctrl_valid[0]),
        .data_out       (adc_parrallel_data[287:192])
    );

    // ADC controllers with flip flop retiming
    LTC2351_controller
        #( .RETIMEING_FF(1) )
    adc_cntr_1
    (
        .clk            (adc_clk),
        .reset_n        (sys_reset_n),
        .go             (sample_rate_go),
        .data_in        (adc_data[1]),
        .conv           (adc_conv[1]),
        .valid          (adc_ctrl_valid[1]),
        .data_out       (adc_parrallel_data[191:96])
    );

    // ADC controllers with flip flop retiming
    LTC2351_controller
        #( .RETIMEING_FF(1) )
    adc_cntr_2
    (
        .clk            (adc_clk),
        .reset_n        (sys_reset_n),
        .go             (sample_rate_go),
        .data_in        (adc_data[2]),
        .conv           (adc_conv[2]),
        .valid          (adc_ctrl_valid[2]),
        .data_out       (adc_parrallel_data[95:0])
    );

    // The trigger bolck is used to stop data
    // to the formatter when a trigger 
    trigger_block ltscope_trigger_block
    (
        .clk(adc_clk),
        .reset_n(sys_reset_n),
        .data_valid(adc_ctrl_valid[0]),
        .trig_in(force_trig_pio_export),
        .force_trig(~btn_trig),
        .pre_trig_counter(pre_trig_count_pio_export),
        .pre_trig_counter_value(pre_trig_count_value_pio_export),
        .post_trig_counter(post_trig_count_pio_export),
        .en_trig(en_pio_export[1]),
        .delayed_trig(trig_signal)
    );
    
    // The data formatter accepts wide data
    // and creates packets to store to RAM
    data_formatter adc_formatter
    ( 
        .clk(adc_clk),
        .reset_n(sys_reset_n),
        // The trig_signal is used to shut off 
        // data to the formatter.
        .done(adc_ctrl_valid[0]&trig_signal), 
        .word_9_data(word_9_data),
        .word_9_valid(word_9_valid),
        .data_in(adc_parrallel_data),
        .valid(adc_formatter_valid),
        .ready(adc_formatter_ready),
        .data_out(adc_formatted_data)
    );

    assign word_9_valid = 1'b0;
    assign word_9_data  = 32'b0;

    // Generate an error_signal if the ADC valid signal are not the same
    assign error_signal = ~((~adc_ctrl_valid[0])&(~adc_ctrl_valid[1])&(~adc_ctrl_valid[2])) |
                          ~((adc_ctrl_valid[0])&(adc_ctrl_valid[1])&(adc_ctrl_valid[2]));
 
    assign adc_formatter_ready = (!adc_fifo_full) ? 1'b1 : 1'b0;

    assign adc_fifo_rdreq = (!adc_fifo_empty & adc_fifo_ready) ? 1'b1 : 1'b0;
    
    assign adc_fifo_wrreq = adc_formatter_valid & (!adc_fifo_full);

    assign adc_fifo_valid = adc_fifo_rdreq;
//    always @(posedge CLOCK_125_p)
//        begin
//            if(adc_fifo_rdreq)
//                adc_fifo_valid <= 1'b1;
//            else
//                adc_fifo_valid <= 1'b0;
//        end

    // Note: show ahead mode
    ADC_fifo adc_fifo
    (
        .aclr(!sys_reset_n),
        .data(adc_formatted_data),
        .rdclk(CLOCK_125_p),
        .rdreq(adc_fifo_rdreq),
        .wrclk(adc_clk),
        .wrreq(adc_fifo_wrreq),
        .q(adc_fifo_data),
        .rdempty(adc_fifo_empty),
        .wrfull(adc_fifo_full)
    );

    ram_mem_contr u0
    (
        .clk_clk                                                                                         (CLOCK_125_p),                                                                                     //                                             clk.clk
        .en_pio_export                                                                                   (en_pio_export),                                                                                   //                                          en_pio.export
        .sample_rate_pio_export                                                                          (sample_rate_pio_export),                                                                          //                                 sample_rate_pio.export
        .force_trig_pio_export                                                                           (force_trig_pio_export),                                                                           //                                  force_trig_pio.export
        .pre_trig_count_value_pio_export                                                                 (pre_trig_count_value_pio_export),                                                                 //                        pre_trig_count_value_pio.export
        .post_trig_count_pio_export                                                                      (post_trig_count_pio_export),                                                                      //                             post_trig_count_pio.export
        .led_external_connection_export                                                                  (ledr[5:0]),                                                                                       //                         led_external_connection.export
        .memory_mem_ca                                                                                   (DDR2LP_CA),                                                                                       //                                          memory.mem_ca
        .memory_mem_ck                                                                                   (DDR2LP_CK_p),        //                                                     .mem_ck
        .memory_mem_ck_n                                                                                 (DDR2LP_CK_n),        //                                                     .mem_ck_n
        .memory_mem_cke                                                                                  (DDR2LP_CKE),         //                                                     .mem_cke
        .memory_mem_cs_n                                                                                 (DDR2LP_CS_n),        //                                                     .mem_cs_n
        .memory_mem_dm                                                                                   (DDR2LP_DM),          //                                                     .mem_dm
        .memory_mem_dq                                                                                   (DDR2LP_DQ),          //                                                     .mem_dq
        .memory_mem_dqs                                                                                  (DDR2LP_DQS_p),       //                                                     .mem_dqs
        .memory_mem_dqs_n                                                                                (DDR2LP_DQS_n),       //                                                     .mem_dqs_n
        .oct_rzqin                                                                                       (DDR2LP_OCT_RZQ),     //                                                  oct.rzqin
        .reset_reset_n                                                                                   (reset_n),                                                                                   //                                           reset.reset_n
        .reset_for_ltscope_reset_n                                                                       (sys_reset_n),                                                                       //                               reset_for_ltscope.reset_n
        .spi_slave_to_avalon_mm_master_bridge_0_export_0_mosi_to_the_spislave_inst_for_spichain          (mosi_spi_ext),          // spi_slave_to_avalon_mm_master_bridge_0_export_0.mosi_to_the_spislave_inst_for_spichain
        .spi_slave_to_avalon_mm_master_bridge_0_export_0_nss_to_the_spislave_inst_for_spichain           (cs_spi_ext),           //                                                .nss_to_the_spislave_inst_for_spichain
        .spi_slave_to_avalon_mm_master_bridge_0_export_0_miso_to_and_from_the_spislave_inst_for_spichain (miso_spi_ext), //                                                .miso_to_and_from_the_spislave_inst_for_spichain
        .spi_slave_to_avalon_mm_master_bridge_0_export_0_sclk_to_the_spislave_inst_for_spichain          (sck_spi_ext),          //                                                .sclk_to_the_spislave_inst_for_spichain
        .ltscope_controller_ring_buff_go                                                                 (en_pio_export[2]),                                                                 //                              ltscope_controller.ring_buff_go
        .ltscope_controller_ring_buff_addr                                                               (ltscope_controller_ring_buff_addr),                                                               //                                                .ring_buff_addr
        .ltscope_controller_read_go                                                                      (en_pio_export[3]),                                                                      //                                                .read_go
        .ltscope_controller_read_start_addr                                                              (ltscope_controller_read_start_addr),                                                              //                                                .read_start_addr
        .ltscope_controller_read_length                                                                  (ltscope_controller_read_length),                                                                  //                                                .read_length
        .ltscope_controller_read_done                                                                    (ltscope_controller_read_done),                                                                    //                                                .read_done
        .ltscope_controller_snk_data                                                                     (adc_fifo_data),                                                                     //                          ltscope_controller_snk.data
        .ltscope_controller_snk_valid                                                                    (adc_fifo_valid),                                                                    //                                                .valid
        .ltscope_controller_snk_ready                                                                    (adc_fifo_ready),                                                                    //                                                .ready
        .ltscope_controller_src_data                                                                     (src_data),                                                                     //                          ltscope_controller_src.data
        .ltscope_controller_src_valid                                                                    (src_valid),                                                                    //                                                .valid
        .ltscope_controller_src_ready                                                                    (src_ready),                                                                    //                                                .ready
        .pre_trig_count_pio_export                                                                       (pre_trig_count_pio_export),                                                                       //                              pre_trig_count_pio.export
        .reader_start_addr_pio_export                                                                    (ltscope_controller_read_start_addr),                                                                    //                           reader_start_addr_pio.export
        .reader_rd_length_pio_export                                                                     (ltscope_controller_read_length),                                                                     //                            reader_rd_length_pio.export
        .reader_done_pio_export                                                                          (ltscope_controller_read_done),                                                                           //                                 reader_done_pio.export
        .scope_reset_n_export                                                                            (sys_reset_n),                                                                             //                                   scope_reset_n.export
        .ring_buff_addr_pio_export                                                                       (ltscope_controller_ring_buff_addr),                                                                       //                              ring_buff_addr_pio.export
        .trig_state_pio_export                                                                           (trig_signal)                                                                            //                                  trig_state_pio.export
        
    );

    // 32-bits of data is written into the FIFO
    // from the reader. 8-bits of data is sent to the ft2232. 
    // Note: This module was created with Altera's MegaWizard manager.
    ft2232_fifo main_ft2232_fifo
    (
        .aclr  (reset),             // Resets the FIFO
        .data  (src_data),          // FIFO data in
        .rdclk (usb_clock),         // ft2232 clock (60MHz) 
        .rdreq ((!usb_txe_n)&(!fifo_empty)&(!delay_rd)),    // Read enable when the FIFO is not empty and the ft2232 is ready for data
        .wrclk (CLOCK_125_p),       // Systems clock
        .wrreq (src_valid & (!fifo_full)& sys_reset_n),     // Write enable when the fifo is not full and the demux data is valid.
                // Also, wrreq should not be driven when the FIFO is in asychronus clear.
                // This avoids a race condition. 
        .q   (usb_data),            // 8-bits is sent to the ft2232
        .rdempty (fifo_empty),      // Determens when the fifo is empty
        .wrfull (fifo_full)         // Used to exhert backpressure to the demux
    );
 
    // Negative edge detector
    reg tx_d1;
    always @(posedge usb_clock)
        begin
            tx_d1 <= usb_txe_n;
    end
 
    // This signal is used to delay the DCFIFO
    // rdreq signal when the FT2232 starts 
    // accepting data after a break.
    // This allows the data to be held for
    // an extra clock
    assign delay_rd = tx_d1 & !usb_txe_n;
 
    // Disable data going from the FT2232 to the bus
    assign usb_rd_n = 1'b1;
    assign usb_oe_n = 1'b1;
 
    assign usb_reset_n = reset_n;
 
    // Assert Ft2232 write_n when the fifo has data 
    // and the Ft2232 is ready for data
    assign usb_wr_n = fifo_empty | usb_txe_n;
 
    assign led_rst = sys_reset_n;
 
    assign src_ready = ~fifo_full; // Applies backpressure to reader
 
endmodule
