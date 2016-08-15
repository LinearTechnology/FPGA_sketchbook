//****************************************
//   Filename       : jesd204b_ed_top.v
//
//   Description    : Top level example design for JESD204B IP
//
//   Limitation     : No dynamic rate switch and dynamic LMF changes
//
//   Note           : Optional 
//***************************************

// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on

module jesd204b_ed_top (
   // Clock and Reset   
   input                  device_clk,    // Device clock	
   input                  mgmt_clk,      // Management clock - 100MHz
// input                  global_rst_n,  // Active low asynchronous global reset
   // JESD204B Specific Signals
   input                  sync_n,
   output                 rx_dev_sync_n,
   output wire            sysref_out,
   // SPI Specific Signals
   input                  miso,
   output                 mosi,
   output                 sclk,
   output [2:0]           ss_n,    
   // Serial In/Out   
   input  [LINK*L-1:0]    rx_serial_data,
   output [LINK*L-1:0]    tx_serial_data,
   // Status Signals
	output [7:0]           user2_led_g
//   output [0:0]           user2_led_r = 1'b1,     //turn LED off by default
   //serial loopback enable

);
	
   localparam LINK              = 1;  
   localparam L                 = 2; 
   localparam M                 = 2;
   localparam F                 = 2;
   localparam S                 = 1;
   localparam N                 = 14;
	localparam CS                = 0;
	localparam K         		  = 32;
	localparam F1_FRAMECLK_DIV   = 1;
	localparam F2_FRAMECLK_DIV   = 1;
	localparam POLYNOMIAL_LENGTH = 9;
	localparam FEEDBACK_TAP      = 5;
	localparam SPI_WIDTH         = 32;
 
   wire [LINK-1:0]     mdev_sync_n;   
   wire [LINK-1:0]     tx_dev_sync_n;
   wire                alldev_lane_aligned;
   wire [LINK-1:0]     dev_lane_aligned;
   wire [LINK-1:0]     tx_sync_n;
   wire [LINK-1:0]     rx_sync_n;
   wire [LINK*L-1:0]   rx_is_lockedtodata;  
   wire                data_valid;       
   wire [LINK*M*S-1:0] data_error;
   wire [LINK-1:0]     tx_link_error;
   wire [LINK-1:0]     rx_link_error;
   wire        rx_avs_chipselect;
   wire        rx_avs_read;
   wire [9:0]  rx_avs_address;
   wire [31:0] rx_avs_readdata;
   wire        rx_avs_waitrequest;
   wire        rx_avs_write;
   wire [31:0] rx_avs_writedata;
   wire [4:0]  dl_K;
   wire global_reset;
   wire rx_seriallpbken;
   wire link_clk;
	
   // JESD204B specific connection   
   assign mdev_sync_n         = tx_dev_sync_n;
   assign rx_dev_sync_n       = & rx_sync_n;
   assign alldev_lane_aligned = dev_lane_aligned;
   assign tx_sync_n = (rx_seriallpbken ? rx_sync_n : {LINK{sync_n}});

   //
   // JESD204B Example Design Module
   //     
   jesd204b_ed #(
      .LINK (LINK),
      .L    (L),
      .M    (M),
      .F    (F),
      .S    (S),
      .N    (N),
		.CS   (CS),
		.F1_FRAMECLK_DIV   (F1_FRAMECLK_DIV),
		.F2_FRAMECLK_DIV   (F2_FRAMECLK_DIV),
		.POLYNOMIAL_LENGTH (POLYNOMIAL_LENGTH),
		.FEEDBACK_TAP      (FEEDBACK_TAP),
		.SPI_WIDTH         (SPI_WIDTH)
   ) u_jesd204b_ed (
      .device_clk          (device_clk),
      .mgmt_clk            (mgmt_clk),
      .global_rst_n        (~global_reset),
      .frame_clk           (),
      .link_clk            (link_clk),
      .avst_usr_din        (),
      .avst_usr_din_valid  (),
      .avst_usr_din_ready  (),
      .avst_usr_dout       (),
      .avst_usr_dout_valid (data_valid),
      .avst_usr_dout_ready (),
      .reconfig            (1'b0),
      .runtime_lmf         (1'b0),
      .runtime_datarate    (1'b0),
      .tx_sysref           ({LINK{sysref_out}}),
      .rx_sysref           ({LINK{sysref_out}}),
      .sync_n              (tx_sync_n),
      .rx_dev_sync_n       (rx_sync_n),
      .tx_avs_chipselect_sys (1'b0),
      .tx_avs_read_sys       (1'b0),
      .tx_avs_address_sys    (32'h00000000),
      .tx_avs_readdata_sys   (),
      .tx_avs_waitrequest_sys(),
      .tx_avs_write_sys      (1'b0),
      .tx_avs_writedata_sys  (32'h00000000),
      .rx_avs_chipselect_sys (rx_avs_chipselect ),
      .rx_avs_read_sys       (rx_avs_read ),
      .rx_avs_address_sys    (rx_avs_address[9:2]),
      .rx_avs_readdata_sys   (rx_avs_readdata ),
      .rx_avs_waitrequest_sys(rx_avs_waitrequest ),
      .rx_avs_write_sys      (rx_avs_write ),
      .rx_avs_writedata_sys  (rx_avs_writedata ),
      .mdev_sync_n         (mdev_sync_n),
      .tx_dev_sync_n       (tx_dev_sync_n),
      .alldev_lane_aligned (alldev_lane_aligned),
      .dev_lane_aligned    (dev_lane_aligned),      
      .test_mode           (4'b0001),
      .rx_seriallpbken     ({(LINK*L){rx_seriallpbken}}),
      .rx_serial_data      (rx_serial_data),
      .tx_serial_data      (tx_serial_data),
      .rx_is_lockedtodata  (rx_is_lockedtodata),
      .data_error          (data_error),
      .jesd204_tx_int      (tx_link_error),
      .jesd204_rx_int      (rx_link_error),
		.avs_rst_n_done 		(avs_rst_n_o),
		.link_rst_n_done		(link_rst_n_o),
		.frame_rst_n_done 	(frame_rst_n_o)
   );

   // Generete periodic sysref according to K value
   gen_multi_sysref #(
      .F(F),
		.K(K)
   )u_sysref (
       .clock         (link_clk)
      ,.rst_n         (1'b1)
      ,.rx_dev_sync_n (rx_sync_n)
      ,.sysref        (sysref_out)
   );

   issp u0_issp (
      .source_clk  (mgmt_clk)
     ,.source      ({rx_seriallpbken, global_reset})
   );
   
   jesd204b_avmm_interface avmm_console_interface_inst( 
      .clk_clk                                (mgmt_clk), 																	
      .reset_reset_n                          (~global_reset),
      .jesd204b_console_interface_address     (rx_avs_address),     
      .jesd204b_console_interface_writedata   (rx_avs_writedata),   
      .jesd204b_console_interface_readdata    (rx_avs_readdata),   
      .jesd204b_console_interface_write       (rx_avs_write),       
      .jesd204b_console_interface_read        (rx_avs_read),        
      .jesd204b_console_interface_waitrequest (rx_avs_waitrequest),  
      .jesd204b_console_interface_chipselect  (rx_avs_chipselect),
	   .spi_0_external_MISO                    (miso),    // spi_0_external.MISO
      .spi_0_external_MOSI                    (mosi),    //               .MOSI
      .spi_0_external_SCLK                    (sclk),    //               .SCLK
      .spi_0_external_SS_n                    (ss_n[0])  //               .SS_n
   );

//LED Display
assign user2_led_g[7] = ~&data_error; 
assign user2_led_g[6] = ~tx_link_error; 
assign user2_led_g[5] = ~rx_link_error; 
assign user2_led_g[4] = ~rx_dev_sync_n; 
assign user2_led_g[3] = ~dev_lane_aligned; 	
assign user2_led_g[2] = ~avs_rst_n_o; 
assign user2_led_g[1] = ~link_rst_n_o; 
assign user2_led_g[0] = ~frame_rst_n_o; 

endmodule
