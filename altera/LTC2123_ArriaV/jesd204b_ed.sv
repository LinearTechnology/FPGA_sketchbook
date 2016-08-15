// (C) 2001-2014 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License Subscription 
// Agreement, Altera MegaCore Function License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the applicable 
// agreement for further details.



`timescale 1ps / 1ps

module jesd204b_ed #(
   parameter LINK              = 2,  // Number of links, a link composed of multiple lanes
             L                 = 2,  // Number of lanes per converter device
             M                 = 2,  // Number of converters per converter device
             F                 = 2,  // Number of octets per frame
             S                 = 1,  // Number of transmitter samples per converter per frame
             N                 = 14, // Number of converter bits per converter
             N_PRIME           = 16, // Number of transmitted bits per sample 
             CS                = 0,  // Number of control bits per conversion sample				 
             F1_FRAMECLK_DIV   = 4,  // Frame clk divider for transport layer when F=1. Valid value = 1 or 4. Default parameter used in all F value scenarios.
				 F2_FRAMECLK_DIV   = 2,  // Frame clk divider for transport layer when F=2. Valid value = 1 or 2. For F=4 & 8, this parameter is not used.
             POLYNOMIAL_LENGTH = 7,  // Length of the polynomial for PRBS Gen/Checker = number of shift register stages
             FEEDBACK_TAP      = 6,  // Intermediate stage that is xor-ed with the last stage to generate to next prbs bit
				 SPI_WIDTH         = 32  // Number of bits in a SPI read/write transaction. Valid value is 24 and 32.
) (
   // Clock and Reset   
   input                                device_clk,    // Device clock
   input                                mgmt_clk,      // Management clock - 100MHz
   input                                global_rst_n,  // Active low asynchronous global reset
   output                               frame_clk,
	output										 link_clk,
   // Av-ST User Data
   input  [F1_FRAMECLK_DIV*LINK*M*S*N-1:0] avst_usr_din,
   input  [LINK-1:0]                       avst_usr_din_valid,
   output [LINK-1:0]                       avst_usr_din_ready,
   output [F1_FRAMECLK_DIV*LINK*M*S*N-1:0] avst_usr_dout,
   output [LINK-1:0]                       avst_usr_dout_valid,
   input  [LINK-1:0]                       avst_usr_dout_ready,            
   input  [3:0]                            test_mode,                        
   // JESD204B Specific Signals   
   input  [LINK-1:0]                    tx_sysref,
   input  [LINK-1:0]                    sync_n,
   input  [LINK-1:0]                    mdev_sync_n,
   input  [LINK-1:0]                    alldev_lane_aligned, 
   input  [LINK-1:0]                    rx_sysref,
   output [LINK-1:0]                    tx_dev_sync_n,
   output [LINK-1:0]                    dev_lane_aligned,
   output [LINK-1:0]                    rx_dev_sync_n,

   // Avalon- MM System console 
   input  wire        tx_avs_chipselect_sys,
   input  wire        tx_avs_read_sys,
   input  wire [7:0]  tx_avs_address_sys,
   output wire [31:0] tx_avs_readdata_sys,
   output wire        tx_avs_waitrequest_sys,
   input  wire        tx_avs_write_sys,
   input  wire [31:0] tx_avs_writedata_sys,
   input  wire        rx_avs_chipselect_sys,
   input  wire        rx_avs_read_sys,
   input  wire [7:0]  rx_avs_address_sys,
   output wire [31:0] rx_avs_readdata_sys,
   output wire        rx_avs_waitrequest_sys,
   input  wire        rx_avs_write_sys,
   input  wire [31:0] rx_avs_writedata_sys,
   // SPI Specific Signals 
   input                                miso,
   output                               mosi,
   output                               sclk,
   output [2:0]                         ss_n,    
   // Serial In/Out & Control
   input  [LINK*L-1:0]                  rx_seriallpbken,     
   input  [LINK*L-1:0]                  rx_serial_data,
   output [LINK*L-1:0]                  tx_serial_data,
   // User Request Control (Run Time Reconfig)
   input                                reconfig,
   input                                runtime_lmf,
   input                                runtime_datarate,
   // Status Signals
   output [LINK*L-1:0]                   rx_is_lockedtodata,
   output [LINK*M-1:0]                     data_error,
   output [LINK-1:0]                     jesd204_tx_int,
   output [LINK-1:0]                     jesd204_rx_int,
   output                                cu_busy,
	output              						 avs_rst_n_done,
   output             						 link_rst_n_done,
   output              						 frame_rst_n_done	
);

   genvar i;

   // Determine number of reconfig interfaces required =
   // (Number of link * number of lanes = number of channels) + (number of link = number of Tx PLL)   //bonded
   // (Number of link * number of lanes = number of channels) + (Number of link * number of lanes = number of Tx PLL)   //unbonded
   localparam NUMBER_OF_RECONFIG_INTERFACES = L+1;  //reconfig only supported unbonded
   localparam RECONFIG_TO_WIDTH             = LINK * NUMBER_OF_RECONFIG_INTERFACES * 70;
   localparam RECONFIG_FROM_WIDTH           = LINK * NUMBER_OF_RECONFIG_INTERFACES * 46;
   localparam RECONFIG_LOGIC                = 0; 
   localparam PLL_SEL_WIDTH                 = altera_xcvr_functions::clogb2(LINK-1);
 
   // Wire declarations for JESD204 IP core   
   wire [LINK-1:0]   jesd204_rx_avs_chipselect;   
   wire [LINK-1:0][9:0]        jesd204_rx_avs_address;
   wire [LINK-1:0]   jesd204_rx_avs_read;
   wire [LINK-1:0][31:0]       jesd204_rx_avs_readdata;
   wire [LINK-1:0]   jesd204_rx_avs_waitrequest;
   wire [LINK-1:0]   jesd204_rx_avs_write;
   wire [LINK-1:0][31:0]       jesd204_rx_avs_writedata;
   wire [LINK-1:0]   jesd204_tx_avs_chipselect;   
   wire [LINK-1:0][9:0]        jesd204_tx_avs_address;
   wire [LINK-1:0]   jesd204_tx_avs_read;
   wire [LINK-1:0][31:0]       jesd204_tx_avs_readdata;
   wire [LINK-1:0]   jesd204_tx_avs_waitrequest;
   wire [LINK-1:0]   jesd204_tx_avs_write;
   wire [LINK-1:0][31:0]       jesd204_tx_avs_writedata;
 
   // Wire declarations for Pattern Generator(s)   
   wire [F1_FRAMECLK_DIV*LINK*M*S*N-1:0] tx_sample_bus;
   wire [LINK*M-1:0]                       tx_sample_valid_bus;
	wire [LINK*M-1:0]                       wire_tx_sample_valid_bus;
   
   // Wire declarations for Pattern Checker(s)
   wire [F1_FRAMECLK_DIV*LINK*M*S*N-1:0] rx_sample_bus;
   wire [LINK-1:0]                       rx_sample_valid_bus;
   wire [LINK*M-1:0]                       checker_ready;
   
   // Wire declarations for Tx Transport Layer
   wire [F1_FRAMECLK_DIV*LINK*M*S*N-1:0] assembler_din;
   wire [LINK-1:0]                       assembler_din_valid;
   wire [LINK*M-1:0]                       assembler_din_ready;   
   wire [LINK*5-1:0]                     tx_csr_l;              // [4:0] for 1x222, [9:0] for 2x112
   wire [LINK*8-1:0]                     tx_csr_f;              // [7:0] for 1x222, [15:0] for 2x112
   wire [LINK*8-1:0]                     tx_csr_m;              // [7:0] for 1x222, [15:0] for 2x112            
   wire [LINK*5-1:0]                     tx_csr_n;              // [4:0] for 1x222, [9:0] for 2x112            
   wire [LINK*5-1:0]                     tx_csr_s;              // [4:0] for 1x222, [9:0] for 2x112            
   wire [LINK*4-1:0]                     tx_csr_testmode;       // [3:0] for 1x222, [7:0] for 2x112   
   wire [LINK-1:0]                       jesd204_tx_link_valid; // [0] for 1x222, [1:0] for 2x112
   wire [LINK-1:0]                       jesd204_tx_frame_ready;// [0] for 1x222, [1:0] for 2x112
   wire [LINK-1:0]                       jesd204_tx_frame_error;// [0] for 1x222, [1:0] for 2x112
   wire [LINK*L-1:0]                     tx_csr_lane_powerdown; // [1:0] for both 1x222 and 2x112	
   wire [LINK*L*32-1:0]                  jesd204_tx_link_data;  // [63:0] for both 1x222 and 2x112
                                                                // [127:0] for both 1x442 and 2x222   
   
   // Wire declarations for Rx Transport Layer
   wire [F1_FRAMECLK_DIV*LINK*M*S*N-1:0] deassembler_dout;
   wire [LINK-1:0]                       deassembler_dout_valid_bus;
   wire [LINK-1:0]                       deassembler_dout_ready;
   wire [LINK*L*32-1:0]                  jesd204_rx_link_data;
   wire [LINK-1:0]                       jesd204_rx_link_valid;
   wire [LINK-1:0]                       jesd204_rx_link_ready;
   wire [LINK-1:0]                       jesd204_rx_frame_error;
   wire [LINK*5-1:0]                     rx_csr_l;
   wire [LINK*8-1:0]                     rx_csr_f;
   wire [LINK*8-1:0]                     rx_csr_m;             
   wire [LINK*5-1:0]                     rx_csr_n;             
   wire [LINK*5-1:0]                     rx_csr_s;             
   wire [LINK*L-1:0]                     rx_csr_lane_powerdown;
   wire [LINK*4-1:0]                     rx_csr_testmode;
   
   // Wire declarations for Control Unit, SPI, Transceiver Reset Controller
   wire [LINK-1:0] pll_powerdown;
	wire [LINK*L-1:0] pll_locked;
   wire [LINK*L-1:0] tx_cal_busy;
   wire [LINK*L-1:0] rx_cal_busy;
   wire [LINK*L-1:0] wire_rx_ready;
   wire [LINK*L-1:0] wire_rx_analogreset;
   wire [LINK*L-1:0] wire_rx_digitalreset;  
   wire [LINK*L-1:0] wire_tx_ready;
   wire [LINK*L-1:0] wire_tx_analogreset;
   wire [LINK*L-1:0] wire_tx_digitalreset;
   wire              wire_frame_rst_n;
   wire              wire_link_rst_n;
   wire [SPI_WIDTH-1:0] spi_txdata;           
   wire [SPI_WIDTH-1:0] spi_rxdata;            
   wire              spi_trdy;
   wire              spi_rrdy;
   wire              spi_write_n; 
   wire              spi_read_n;   
   wire [2:0]        spi_addr;
   wire              spi_select;
   wire              avs_rst_n;
   wire              frame_rst_n;
   wire              link_rst_n;
   wire              tx_link_rst_n_sync;
   wire              tx_frame_rst_n_sync;
   wire              rx_link_rst_n_sync;
   wire              rx_frame_rst_n_sync;
   wire              global_rst_n_sync;
	
   // Wire declarations for run time reconfig
   wire [63:0]       reconfig_to_pll;
   wire [63:0]       reconfig_from_pll;
   wire              pll_mgmt_waitrequest;
   wire              pll_mgmt_read;
   wire              pll_mgmt_write;
   wire [31:0]       pll_mgmt_readdata;
   wire [5:0]        pll_mgmt_address;
   wire [31:0]       pll_mgmt_writedata;

	wire [31:0]       reconfig_mif_address;   
   wire [15:0]       reconfig_mif_readdata;
   wire 	            reconfig_mif_read;
   reg 		         reconfig_mif_waitrequest;
	 
   // Wire declarations for Transceiver Reconfig Controller
   wire [RECONFIG_TO_WIDTH-1:0]   reconfig_to_xcvr;   
   wire [RECONFIG_FROM_WIDTH-1:0] reconfig_from_xcvr; 
   wire [6:0]        reconfig_mgmt_address;
   wire              reconfig_mgmt_read;
   wire [31:0]       reconfig_mgmt_readdata;
   wire              reconfig_mgmt_waitrequest;
   wire              reconfig_mgmt_write;
   wire [31:0]       reconfig_mgmt_writedata;
   
   // Wire declarations for resets
   wire tx_avs_rst_n;
   wire rx_avs_rst_n;
   wire tx_frame_rst_n;
   wire rx_frame_rst_n;
   wire tx_link_rst_n;
   wire rx_link_rst_n;
   wire wire_xcvr_rst_n;
   wire core_pll_locked;
   wire xcvr_rst_ctrl_rst_n;
   	
   // Hold core in reset mode until transceiver is ready
   assign tx_avs_rst_n   = avs_rst_n;
   assign rx_avs_rst_n   = avs_rst_n;
   assign tx_frame_rst_n = ~tx_frame_rst_n_sync;
   assign rx_frame_rst_n = ~rx_frame_rst_n_sync;
   assign tx_link_rst_n  = ~tx_link_rst_n_sync;
   assign rx_link_rst_n  = ~rx_link_rst_n_sync;
	assign avs_rst_n_done =  avs_rst_n;
   assign link_rst_n_done = tx_link_rst_n & rx_link_rst_n;
   assign frame_rst_n_done = tx_frame_rst_n & rx_frame_rst_n;
	
   // Hold transceiver in reset mode until core PLL is locked     
   assign xcvr_rst_ctrl_rst_n = wire_xcvr_rst_n & global_rst_n_sync & core_pll_locked;
   assign xcvr_reconfig_rst_n = global_rst_n_sync & core_pll_locked; 
		
   assign jesd204_tx_avs_chipselect = cu_tx_avs_chipselect | tx_avs_chipselect_sys;
   assign jesd204_tx_avs_read       = cu_tx_avs_read       | tx_avs_read_sys ;
   assign jesd204_tx_avs_address    = cu_tx_avs_address    | tx_avs_address_sys ;
   assign jesd204_tx_avs_write      = cu_tx_avs_write      | tx_avs_write_sys ;
   assign jesd204_tx_avs_writedata  = cu_tx_avs_writedata  | tx_avs_writedata_sys ;
   assign jesd204_rx_avs_chipselect = cu_rx_avs_chipselect | rx_avs_chipselect_sys ;
   assign jesd204_rx_avs_read       = cu_rx_avs_read       | rx_avs_read_sys  ;
   assign jesd204_rx_avs_address    = cu_rx_avs_address    | rx_avs_address_sys ;
   assign jesd204_rx_avs_write      = cu_rx_avs_write      | rx_avs_write_sys ;
   assign jesd204_rx_avs_writedata  = cu_rx_avs_writedata  | rx_avs_writedata_sys ;
   assign cu_tx_avs_readdata        = jesd204_tx_avs_readdata;
   assign cu_rx_avs_readdata        = jesd204_rx_avs_readdata;
   assign cu_tx_avs_waitrequest     = jesd204_tx_avs_waitrequest;
   assign cu_rx_avs_waitrequest     = jesd204_rx_avs_waitrequest;
   assign tx_avs_readdata_hw        = jesd204_tx_avs_readdata;
   assign rx_avs_readdata_hw        = jesd204_rx_avs_readdata;
   assign tx_avs_waitrequest_hw     = jesd204_tx_avs_waitrequest;
   assign rx_avs_waitrequest_hw     = jesd204_rx_avs_waitrequest;
   assign tx_avs_readdata_sys        = jesd204_tx_avs_readdata;
   assign rx_avs_readdata_sys        = jesd204_rx_avs_readdata;
   assign tx_avs_waitrequest_sys     = jesd204_tx_avs_waitrequest;
   assign rx_avs_waitrequest_sys     = jesd204_rx_avs_waitrequest;
   
   //
   // Core PLL
   //
   core_pll u_pll (
      .refclk            (device_clk),
      .rst               (~global_rst_n),
      .outclk_0          (frame_clk),            
      .outclk_1          (link_clk),             
      .locked            (core_pll_locked),
      .reconfig_to_pll   (reconfig_to_pll),
      .reconfig_from_pll (reconfig_from_pll)		   
   );

   // 
   // Core PLL Reconfig (for runtime data rate reconfig)
   //
   core_pll_reconfig u_pll_reconfig (
      .mgmt_clk          (mgmt_clk),          
      .mgmt_reset        (~global_rst_n_sync),        
      .mgmt_waitrequest  (pll_mgmt_waitrequest), 
      .mgmt_read         (pll_mgmt_read),         
      .mgmt_write        (pll_mgmt_write),        
      .mgmt_readdata     (pll_mgmt_readdata),     
      .mgmt_address      (pll_mgmt_address),     
      .mgmt_writedata    (pll_mgmt_writedata),    
      .reconfig_to_pll   (reconfig_to_pll),   
      .reconfig_from_pll (reconfig_from_pll) 
   );

   //
   // Pattern Generator(s)
   //
   generate 
      for (i=0; i<LINK*M; i=i+1) begin: GENERATOR    
         pattern_generator_top #(
				.FRAMECLK_DIV      (F1_FRAMECLK_DIV),
//				.M                 (M),
            .N                 (N),
            .S                 (S),				     
    			.POLYNOMIAL_LENGTH (POLYNOMIAL_LENGTH),
            .FEEDBACK_TAP      (FEEDBACK_TAP),
				.REVERSE_DATA      (0)
         ) u_gen (
            .clk               (frame_clk),
            .rst_n             (tx_frame_rst_n),
//				.csr_tx_testmode   (rx_csr_testmode[i*4+3:i*4]),
				.csr_tx_testmode   (4'b1010),    //hard code for data rate reconfig testing
				.csr_m             (8'd0),
            .csr_s             (5'd0),
            .error_inject      (1'b0),
				.ready             (assembler_din_ready[i]),				
            .valid             (wire_tx_sample_valid_bus[i]),
            .avst_dataout      (tx_sample_bus[F1_FRAMECLK_DIV*S*N*(i+1)-1:F1_FRAMECLK_DIV*S*N*i])		   
         );

			// assign tx_sample_valid_bus[i] = (tx_csr_testmode[3])? wire_tx_sample_valid_bus[i] : 1'b1;
            assign tx_sample_valid_bus[i] = wire_tx_sample_valid_bus[i];			//hard coded for now
      end		
   endgenerate      	

   // 
   // Pattern Checker(s)
   //
	
   generate 
      for (i=0; i<LINK*M; i=i+1) begin: CHECKER    
         pattern_checker_top #(
				.FRAMECLK_DIV      (F1_FRAMECLK_DIV),
//				.M                 (M),
            .N                 (N),
            .S                 (S),				     
            .POLYNOMIAL_LENGTH (POLYNOMIAL_LENGTH),
            .FEEDBACK_TAP      (FEEDBACK_TAP),
				.ERR_THRESHOLD     (1),
				.REVERSE_DATA      (0)			     
         ) u_chk (
            .clk              (frame_clk),
            .rst_n            (rx_frame_rst_n),
//				.csr_rx_testmode  (rx_csr_testmode[i*4+3:i*4]),
				.csr_rx_testmode  (4'b1010),          //hard code for data rate reconfig testing
				.csr_m            (8'd0),
            .csr_s            (5'd0),
			   .ready            (checker_ready[i]),	
				.valid            (rx_sample_valid_bus),			
            .avst_datain      (rx_sample_bus[F1_FRAMECLK_DIV*S*N*(i+1)-1:F1_FRAMECLK_DIV*S*N*i]),
            .err_out          (data_error[i])
         );
      end
   endgenerate
	
   assign rx_sample_bus       = deassembler_dout;
   assign rx_sample_valid_bus = deassembler_dout_valid_bus;
   assign avst_usr_dout       = deassembler_dout;
   assign avst_usr_dout_valid = deassembler_dout_valid_bus;
   assign deassembler_dout_ready = test_mode == 4'b0000 ? avst_usr_dout_ready : &checker_ready;

   
   assign assembler_din       = test_mode == 4'b0000 ? avst_usr_din        : tx_sample_bus;   
   assign assembler_din_valid = test_mode == 4'b0000 ? avst_usr_din_valid  : &tx_sample_valid_bus;
   assign avst_usr_din_ready  = test_mode == 4'b0000 ? &assembler_din_ready : {LINK{1'b0}}; 
	
   //
   // Tx Transport Layer 
   //
   generate 
         for (i=0; i<LINK; i=i+1) begin: ASSEMBLER       
            altera_jesd204_transport_tx_top #(
               .L               (L), 
               .F               (F),
               .N               (N),
					.N_PRIME         (N_PRIME),
					.CS              (CS),
               .F1_FRAMECLK_DIV (F1_FRAMECLK_DIV),
               .F2_FRAMECLK_DIV (F2_FRAMECLK_DIV),					
               .RECONFIG_EN     (1)   
            ) u_tx_transport (
               .txlink_rst_n                (tx_link_rst_n),
               .txframe_rst_n               (tx_frame_rst_n),
               .txframe_clk                 (frame_clk),
               .txlink_clk                  (link_clk),
               .jesd204_tx_datain           (assembler_din[F1_FRAMECLK_DIV*M*S*N*(i+1)-1:F1_FRAMECLK_DIV*M*S*N*i]),
					.jesd204_tx_controlin        ({F1_FRAMECLK_DIV*M*S*N{1'b0}}),     //for CS=0, connection to this port is not needed
               .jesd204_tx_data_valid       (assembler_din_valid[i]),
               .jesd204_tx_link_early_ready (jesd204_tx_frame_ready[i]),
               .csr_l                       (tx_csr_l[i*5+4:i*5]),
               .csr_f                       (tx_csr_f[i*8+7:i*8]),
               .csr_n                       (tx_csr_n[i*5+4:i*5]),
               .jesd204_tx_data_ready       (assembler_din_ready[i]),
               .jesd204_tx_link_error       (jesd204_tx_frame_error[i]),
               .jesd204_tx_link_datain      (jesd204_tx_link_data[i*32*L+(32*L-1):i*32*L]),			      
               .jesd204_tx_link_data_valid  (jesd204_tx_link_valid[i])		      
            );
         end 
   endgenerate	 

   //
   // Rx Transort Layer 
   //
   generate 
         for (i=0; i<LINK; i=i+1) begin: DEASSEMBLER  
            altera_jesd204_transport_rx_top #(
               .L               (L),
               .F               (F),
               .N               (N),
					.CS              (CS),
					.N_PRIME         (N_PRIME),      
               .F1_FRAMECLK_DIV (F1_FRAMECLK_DIV),
		         .F2_FRAMECLK_DIV (F2_FRAMECLK_DIV),
				   .RECONFIG_EN     (1)	
            ) u_rx_transport (
               .rxlink_rst_n               (rx_link_rst_n),
               .rxframe_rst_n              (rx_frame_rst_n),
               .rxframe_clk                (frame_clk),
               .rxlink_clk                 (link_clk),
               .jesd204_rx_link_datain     (jesd204_rx_link_data[i*32*L+(32*L-1):i*32*L]),			      
               .jesd204_rx_link_data_valid (jesd204_rx_link_valid[i]),
               .jesd204_rx_data_ready      (deassembler_dout_ready[i]),
               .csr_l                      (rx_csr_l[i*5+4:i*5]),
               .csr_f                      (rx_csr_f[i*8+7:i*8]),
               .csr_n                      (rx_csr_n[i*5+4:i*5]),
               .jesd204_rx_dataout         (deassembler_dout[F1_FRAMECLK_DIV*M*S*N*(i+1)-1:F1_FRAMECLK_DIV*M*S*N*i]),
					.jesd204_rx_controlout      (),                           //for CS=0, connection to this port is not needed
               .jesd204_rx_link_error      (jesd204_rx_frame_error[i]),
               .jesd204_rx_data_valid      (deassembler_dout_valid_bus[i]),
               .jesd204_rx_link_data_ready (jesd204_rx_link_ready[i])		      
            );
         end				     
   endgenerate
   
	 // 
   // JESD204B Duplex Core
   //
   generate 
         for (i=0; i<LINK; i=i+1) begin: JESD204B_DUPLEX_CORE    
            altera_jesd204 u_jesd204 (
               .tx_pll_ref_clk             (device_clk),
               .txlink_clk                 (link_clk),
               .txlink_rst_n_reset_n       (tx_link_rst_n),
               .jesd204_tx_avs_clk         (mgmt_clk),
               .jesd204_tx_avs_rst_n       (tx_avs_rst_n),
               .jesd204_tx_avs_chipselect  (jesd204_tx_avs_chipselect[i]),
               .jesd204_tx_avs_address     (jesd204_tx_avs_address[i][9:2]),
               .jesd204_tx_avs_read        (jesd204_tx_avs_read[i]),
               .jesd204_tx_avs_readdata    (jesd204_tx_avs_readdata[i]),
               .jesd204_tx_avs_waitrequest (jesd204_tx_avs_waitrequest[i]),
               .jesd204_tx_avs_write       (jesd204_tx_avs_write[i]),
               .jesd204_tx_avs_writedata   (jesd204_tx_avs_writedata[i]),
               .jesd204_tx_link_data       (jesd204_tx_link_data[i*32*L+(32*L-1):i*32*L]),
               .jesd204_tx_link_valid      (jesd204_tx_link_valid[i]),
               .jesd204_tx_link_ready      (),
               .jesd204_tx_int             (jesd204_tx_int[i]),
               .tx_sysref                  (tx_sysref[i]),                 
               .sync_n                     (sync_n[i]),                    
               .tx_dev_sync_n              (tx_dev_sync_n[i]),             
               .mdev_sync_n                (mdev_sync_n[i]),               
               .jesd204_tx_frame_ready     (jesd204_tx_frame_ready[i]),    
               .tx_csr_l                   (tx_csr_l[i*5+4:i*5]),                  
               .tx_csr_f                   (tx_csr_f[i*8+7:i*8]),                  
               .tx_csr_k                   (),                  
               .tx_csr_m                   (tx_csr_m[i*8+7:i*8]),                  
               .tx_csr_cs                  (),                 
               .tx_csr_n                   (tx_csr_n[i*5+4:i*5]),                  
               .tx_csr_np                  (),                 
               .tx_csr_s                   (tx_csr_s[i*5+4:i*5]),                  
               .tx_csr_hd                  (),                 
               .tx_csr_cf                  (),                 
               .tx_csr_lane_powerdown      (tx_csr_lane_powerdown[i*L+L-1:i*L]),      
               .csr_tx_testmode            (tx_csr_testmode[i*4+3:i*4]),            
               .csr_tx_testpattern_a       (),       
               .csr_tx_testpattern_b       (),       
               .csr_tx_testpattern_c       (),       
               .csr_tx_testpattern_d       (),       
               .jesd204_tx_frame_error     (jesd204_tx_frame_error[i]),     
               .jesd204_tx_dlb_data        (),        
               .jesd204_tx_dlb_kchar_data  (),  
               .txphy_clk                  (),                  
               .tx_serial_data             (tx_serial_data[i*L+L-1:i*L]),             
               .pll_powerdown              (pll_powerdown[i]),              
               .tx_analogreset             (wire_tx_analogreset[i*L+L-1:i*L]),             
               .tx_digitalreset            (wire_tx_digitalreset[i*L+L-1:i*L]),            
               .pll_locked                 (pll_locked[i*L+L-1:i*L]),                 
               .tx_cal_busy                (tx_cal_busy[i*L+L-1:i*L]),                
               .rx_pll_ref_clk             (device_clk),             
               .rxlink_clk                 (link_clk),                 
               .rxlink_rst_n_reset_n       (rx_link_rst_n),       
               .jesd204_rx_avs_clk         (mgmt_clk),         
               .jesd204_rx_avs_rst_n       (rx_avs_rst_n),       
               .jesd204_rx_avs_chipselect  (jesd204_rx_avs_chipselect[i]),  
               .jesd204_rx_avs_address     (jesd204_rx_avs_address[i][7:0]),     
               .jesd204_rx_avs_read        (jesd204_rx_avs_read[i]),        
               .jesd204_rx_avs_readdata    (jesd204_rx_avs_readdata[i]),    
               .jesd204_rx_avs_waitrequest (jesd204_rx_avs_waitrequest[i]), 
               .jesd204_rx_avs_write       (jesd204_rx_avs_write[i]),       
               .jesd204_rx_avs_writedata   (jesd204_rx_avs_writedata[i]),   
               .jesd204_rx_link_data       (jesd204_rx_link_data[i*32*L+(32*L-1):i*32*L]),      
               .jesd204_rx_link_valid      (jesd204_rx_link_valid[i]),      
               .jesd204_rx_link_ready      (jesd204_rx_link_ready[i]),      
               .jesd204_rx_dlb_data        (),        
               .jesd204_rx_dlb_data_valid  (),  
               .jesd204_rx_dlb_kchar_data  (),  
               .jesd204_rx_dlb_errdetect   (),   
               .jesd204_rx_dlb_disperr     (),     
               .alldev_lane_aligned        (alldev_lane_aligned[i]),        
               .rx_sysref                  (rx_sysref[i]),                  
               .jesd204_rx_frame_error     (jesd204_rx_frame_error[i]),     
               .jesd204_rx_int             (jesd204_rx_int[i]),             
               .csr_rx_testmode            (rx_csr_testmode[i*4+3:i*4]),           
               .dev_lane_aligned           (dev_lane_aligned[i]),          
               .rx_dev_sync_n              (rx_dev_sync_n[i]),             
               .rx_sof                     (),                    
               .rx_somf                    (),                   
               .rx_csr_f                   (rx_csr_f[i*8+7:i*8]),                  
               .rx_csr_k                   (),                  
               .rx_csr_l                   (rx_csr_l[i*5+4:i*5]),                  
               .rx_csr_m                   (rx_csr_m[i*8+7:i*8]),                  
               .rx_csr_n                   (rx_csr_n[i*5+4:i*5]),                  
               .rx_csr_s                   (rx_csr_s[i*5+4:i*5]),                  
               .rx_csr_cf                  (),                 
               .rx_csr_cs                  (),                 
               .rx_csr_hd                  (),                 
               .rx_csr_np                  (),                 
               .rx_csr_lane_powerdown      (rx_csr_lane_powerdown[i*L+L-1:i*L]),     
               .rxphy_clk                  (),                 
               .rx_serial_data             (rx_serial_data[i*L+L-1:i*L]),            
               .rx_analogreset             (wire_rx_analogreset[i*L+L-1:i*L]),            
               .rx_digitalreset            (wire_rx_digitalreset[i*L+L-1:i*L]),           
               .reconfig_to_xcvr           (reconfig_to_xcvr[i*NUMBER_OF_RECONFIG_INTERFACES*70+(NUMBER_OF_RECONFIG_INTERFACES*70-1):i*NUMBER_OF_RECONFIG_INTERFACES*70]),    // NUMBER_OF_RECONFIG_INTERFACES*70
               .reconfig_from_xcvr         (reconfig_from_xcvr[i*NUMBER_OF_RECONFIG_INTERFACES*46+(NUMBER_OF_RECONFIG_INTERFACES*46-1):i*NUMBER_OF_RECONFIG_INTERFACES*46]),  // NUMBER_OF_RECONFIG_INTERFACES*46   
               .rx_islockedtodata          (rx_is_lockedtodata[i*L+L-1:i*L]),         
               .rx_cal_busy                (rx_cal_busy[i*L+L-1:i*L]),                
               .rx_seriallpbken            (rx_seriallpbken[i*L+L-1:i*L])                
            );
         end
   endgenerate	 
	 
   //
   // Transceiver Reconfig Controller
   // Instantiates the lower level entity (alt_xcvr_reconfig) directly 
   // so that parameters can be accessed
   //
   //reconfig_controller
   alt_xcvr_reconfig #(
      .device_family                 ("Arria V"),
      .number_of_reconfig_interfaces (LINK*NUMBER_OF_RECONFIG_INTERFACES),
      .enable_offset                 (1),
      .enable_lc                     (0),
      .enable_dcd                    (0),
      .enable_dcd_power_up           (1),
      .enable_analog                 (0),
      .enable_eyemon                 (0),
      .enable_ber                    (0),
      .enable_dfe                    (0),
      .enable_adce                   (0),
      .enable_mif                    (1),
      .enable_pll                    (1)
   ) u_reconfig (   
      .reconfig_busy             (),
      .cal_busy_in               (1'b0),		
      .mgmt_clk_clk              (mgmt_clk),
      .mgmt_rst_reset            (~xcvr_reconfig_rst_n),	            
      .reconfig_mgmt_address     (reconfig_mgmt_address),    
      .reconfig_mgmt_read        (reconfig_mgmt_read),        
      .reconfig_mgmt_readdata    (reconfig_mgmt_readdata),  
      .reconfig_mgmt_waitrequest (reconfig_mgmt_waitrequest), 
      .reconfig_mgmt_write       (reconfig_mgmt_write),       
      .reconfig_mgmt_writedata   (reconfig_mgmt_writedata),
      .reconfig_mif_address      (reconfig_mif_address),      
      .reconfig_mif_read         (reconfig_mif_read),          
      .reconfig_mif_readdata     (reconfig_mif_readdata),   
      .reconfig_mif_waitrequest  (reconfig_mif_waitrequest), 
      .reconfig_to_xcvr          (reconfig_to_xcvr),    
      .reconfig_from_xcvr        (reconfig_from_xcvr) 
   );


   always @ (posedge mgmt_clk) 
   begin
      reconfig_mif_waitrequest <= ~(reconfig_mif_read);
   end
	
   //
   // Control Unit
   //     
   control_unit #(
      .LINK       (LINK),      
      .L          (L),
      .M          (M),
      .F          (F),
      .SPI_WIDTH  (SPI_WIDTH),
      .DEVICE_FAMILY ("Arria V")	
   ) u_cu (
      .clk                        (mgmt_clk),
      .rst_n                      (global_rst_n_sync),
      .tx_ready                   (wire_tx_ready),
      .rx_ready                   (wire_rx_ready),
      .reconfig                   (reconfig),
      .runtime_lmf                (runtime_lmf),
      .runtime_datarate           (runtime_datarate),	   
      .avs_rst_n                  (avs_rst_n),
      .frame_rst_n                (wire_frame_rst_n),
      .link_rst_n                 (wire_link_rst_n),
      .xcvr_rst_n                 (wire_xcvr_rst_n),
      .spi_trdy                   (spi_trdy),
      .spi_rrdy                   (spi_rrdy),   
      .spi_rxdata                 (spi_rxdata),
      .spi_read_n                 (spi_read_n),
      .spi_write_n                (spi_write_n),
      .spi_select                 (spi_select),     
      .spi_addr                   (spi_addr),
      .spi_txdata                 (spi_txdata),
      .pll_mgmt_waitrequest       (pll_mgmt_waitrequest), 
      .pll_mgmt_read              (pll_mgmt_read),         
      .pll_mgmt_write             (pll_mgmt_write),        
      .pll_mgmt_readdata          (pll_mgmt_readdata),     
      .pll_mgmt_address           (pll_mgmt_address),     
      .pll_mgmt_writedata         (pll_mgmt_writedata),
      .jesd204_tx_avs_chipselect  (cu_tx_avs_chipselect),
      .jesd204_tx_avs_address     (cu_tx_avs_address),
      .jesd204_tx_avs_read        (cu_tx_avs_read),
      .jesd204_tx_avs_readdata    (cu_tx_avs_readdata),
      .jesd204_tx_avs_waitrequest (cu_tx_avs_waitrequest),
      .jesd204_tx_avs_write       (cu_tx_avs_write),
      .jesd204_tx_avs_writedata   (cu_tx_avs_writedata),
      .jesd204_rx_avs_chipselect  (cu_rx_avs_chipselect),
      .jesd204_rx_avs_address     (cu_rx_avs_address),
      .jesd204_rx_avs_read        (cu_rx_avs_read),
      .jesd204_rx_avs_readdata    (cu_rx_avs_readdata),
      .jesd204_rx_avs_waitrequest (cu_rx_avs_waitrequest),
      .jesd204_rx_avs_write       (cu_rx_avs_write),
      .jesd204_rx_avs_writedata   (cu_rx_avs_writedata),
      .reconfig_mgmt_address      (reconfig_mgmt_address),    
      .reconfig_mgmt_read         (reconfig_mgmt_read),        
      .reconfig_mgmt_readdata     (reconfig_mgmt_readdata),  
      .reconfig_mgmt_waitrequest  (reconfig_mgmt_waitrequest), 
      .reconfig_mgmt_write        (reconfig_mgmt_write),       
      .reconfig_mgmt_writedata    (reconfig_mgmt_writedata),
	   .cu_busy                    (cu_busy)
   );
   
   //   
   // Transceiver Reset Controller   
   //   
   altera_xcvr_reset_control #(
      .CHANNELS              (LINK*L),
      .PLLS                  (LINK),   // Tx PLLs  
      .SYS_CLK_IN_MHZ        (100),
      .SYNCHRONIZE_RESET     (0),
      .REDUCED_SIM_TIME      (0),
      .TX_PLL_ENABLE         (0),
      .T_PLL_POWERDOWN       (1000),
      .SYNCHRONIZE_PLL_RESET (0),
      .TX_ENABLE             (1),
      .TX_PER_CHANNEL        (1),
      .T_TX_DIGITALRESET     (20),
      .T_PLL_LOCK_HYST       (0),   
      .RX_ENABLE             (1),
      .RX_PER_CHANNEL        (1),
      .T_RX_ANALOGRESET      (80),
      .T_RX_DIGITALRESET     (4000)
   ) u_xcvr_rst_ctl (
      .clock              (mgmt_clk),                 
      .reset              (~xcvr_rst_ctrl_rst_n),                    
      .rx_analogreset     (wire_rx_analogreset),   
      .rx_digitalreset    (wire_rx_digitalreset), 
      .rx_ready           (wire_rx_ready),              
      .rx_is_lockedtodata (rx_is_lockedtodata),       
      .rx_cal_busy        (rx_cal_busy),                    
      .pll_powerdown      (pll_powerdown),                                                 
      .tx_analogreset     (wire_tx_analogreset),                                                
      .tx_digitalreset    (wire_tx_digitalreset),                                                 
      .tx_ready           (wire_tx_ready),                                                
      .pll_locked         (pll_locked),                                            
      .pll_select         ({{LINK*L*PLL_SEL_WIDTH}{1'b0}}),                                            
      .tx_cal_busy        (tx_cal_busy),                                            
      .tx_manual          ({{LINK*L}{1'b0}}),                                             
      .rx_manual          ({{LINK*L}{1'b0}}), // auto ltr-ltd mode                                            
      .tx_digitalreset_or ({{LINK*L}{1'b0}}),                                              
      .rx_digitalreset_or ({{LINK*L}{1'b0}})                                              
   );

   //    
   // Reset synchronizers for global reset (mgmt clock domain)  
   //  
   altera_reset_controller_0 #(
      .NUM_RESET_INPUTS        (1),
      .OUTPUT_RESET_SYNC_EDGES ("deassert"),
      .SYNC_DEPTH              (2)
   ) u_avs_rst_sync (
      .reset_in0  (global_rst_n), 
      .clk        (mgmt_clk),                                
      .reset_out  (global_rst_n_sync)
   );
   
   //   
   // Reset synchronizers for transport layer reset (frame clock domain)
   //   
   altera_reset_controller_0 #(
      .NUM_RESET_INPUTS        (1),
      .OUTPUT_RESET_SYNC_EDGES ("deassert"),
      .SYNC_DEPTH              (2)
   ) u_tx_frame_rst_sync (
      .reset_in0  (~(wire_frame_rst_n & wire_tx_ready)), 
      .clk        (frame_clk),                                
      .reset_out  (tx_frame_rst_n_sync)
   );

   altera_reset_controller_0 #(
      .NUM_RESET_INPUTS        (1),
      .OUTPUT_RESET_SYNC_EDGES ("deassert"),
      .SYNC_DEPTH              (2)
   ) u_rx_frame_rst_sync (
      .reset_in0  (~(wire_frame_rst_n & wire_rx_ready)), 
      .clk        (frame_clk),                                
      .reset_out  (rx_frame_rst_n_sync)
   );

   //    
   // Reset synchronizers for base core reset (link clock domain)
   //  
   altera_reset_controller_0 #(
      .NUM_RESET_INPUTS        (1),
      .OUTPUT_RESET_SYNC_EDGES ("deassert"),
      .SYNC_DEPTH              (2)
   ) u_tx_link_rst_sync (
      .reset_in0  (~(wire_link_rst_n & wire_tx_ready)), 
      .clk        (link_clk),                                
      .reset_out  (tx_link_rst_n_sync)
   );
   
   altera_reset_controller_0 #(
      .NUM_RESET_INPUTS        (1),
      .OUTPUT_RESET_SYNC_EDGES ("deassert"),
      .SYNC_DEPTH              (2)
   ) u_rx_link_rst_sync (
      .reset_in0  (~(wire_link_rst_n & wire_rx_ready)), 
      .clk        (link_clk),                                
      .reset_out  (rx_link_rst_n_sync)
   );

   //
   // SPI Master core (full duplex)
   //

   /*generate 
      if (SPI_WIDTH == 24) begin: SPI  
	      spi_master_24 u_spi_master (
            .MISO          (miso),
            .MOSI          (mosi),
            .SCLK          (sclk),
            .SS_n          (ss_n),
            .clk           (mgmt_clk),
            .data_from_cpu (spi_txdata),
            .data_to_cpu   (spi_rxdata), // received data is not being used but for signaltap debugging only
            .dataavailable (spi_rrdy),
            .endofpacket   (),
            .irq           (),
            .mem_addr      (spi_addr),
            .read_n        (spi_read_n),
            .readyfordata  (spi_trdy),
            .reset_n       (global_rst_n_sync),
            .spi_select    (spi_select),
            .write_n       (spi_write_n)
         );
      end else begin
	      spi_master_32 u_spi_master (
            .MISO          (miso),
            .MOSI          (mosi),
            .SCLK          (sclk),
            .SS_n          (ss_n),
            .clk           (mgmt_clk),
            .data_from_cpu (spi_txdata),
            .data_to_cpu   (spi_rxdata), // received data is not being used but for signaltap debugging only
            .dataavailable (spi_rrdy),
            .endofpacket   (),
            .irq           (),
            .mem_addr      (spi_addr),
            .read_n        (spi_read_n),
            .readyfordata  (spi_trdy),
            .reset_n       (global_rst_n_sync),
            .spi_select    (spi_select),
            .write_n       (spi_write_n)
         );	
      end	
   endgenerate*/
	
endmodule

