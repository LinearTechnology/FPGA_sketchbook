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


`timescale 1 ps / 1 ps

module control_unit #(
   parameter LINK         = 1,   // Number of links, multi 112 core has LINK=2 while single 222 core has LINK=1 
   parameter L            = 2,   // Number of lanes, multi 112 core has L=1 while single 222 core has L=2
   parameter M            = 2,   // Number of converters per converter device
   parameter F            = 2,   // Number of octets per frame
   parameter SPI_WIDTH    = 24,  // Number of bits in a SPI read/write transaction
   parameter DEVICE_FAMILY = "Arria V"
)
( 
   input               clk, // mgmt_clk freq 100MHz
   input               rst_n,
   input  [LINK*L-1:0] tx_ready,
   input  [LINK*L-1:0] rx_ready,
   input               reconfig,
   input               runtime_lmf,
   input               runtime_datarate,
   output              avs_rst_n,
   output              frame_rst_n,
   output              link_rst_n,
   output              xcvr_rst_n,
   input               	   spi_trdy,
   input                   spi_rrdy,   
   input  [SPI_WIDTH-1:0]  spi_rxdata,
   output              spi_read_n,
   output              spi_write_n,
   output              spi_select,     
   output [2:0]        spi_addr,
   output [SPI_WIDTH-1:0]   spi_txdata,
   input               pll_mgmt_waitrequest,  
   output              pll_mgmt_read,         
   output              pll_mgmt_write,     
   input  [31:0]       pll_mgmt_readdata,   
   output [5:0]        pll_mgmt_address,     
   output [31:0]       pll_mgmt_writedata,
   output [LINK-1:0]      jesd204_tx_avs_chipselect, 
   output [LINK-1:0][9:0]           jesd204_tx_avs_address,     
   output [LINK-1:0]      jesd204_tx_avs_read,        
   input  [LINK-1:0][31:0]          jesd204_tx_avs_readdata,   
   input  [LINK-1:0]      jesd204_tx_avs_waitrequest, 
   output [LINK-1:0]      jesd204_tx_avs_write,       
   output [LINK-1:0][31:0]          jesd204_tx_avs_writedata ,
   output [LINK-1:0]      jesd204_rx_avs_chipselect, 
   output [LINK-1:0][9:0]           jesd204_rx_avs_address ,     
   output [LINK-1:0]      jesd204_rx_avs_read,        
   input  [LINK-1:0][31:0]          jesd204_rx_avs_readdata ,   
   input  [LINK-1:0]      jesd204_rx_avs_waitrequest, 
   output [LINK-1:0]      jesd204_rx_avs_write,       
   output [LINK-1:0][31:0]          jesd204_rx_avs_writedata ,
   output [6:0]        reconfig_mgmt_address,     
   output              reconfig_mgmt_read,        
   input  [31:0]       reconfig_mgmt_readdata,    
   input               reconfig_mgmt_waitrequest, 
   output              reconfig_mgmt_write,       
   output [31:0]       reconfig_mgmt_writedata,
   output              cu_busy
);

   genvar i;

   //   
   // Local parameters declaration
   //
   localparam SLAVE_NUM             = 3;  // Default set to 3 - ADC, DAC and Clock
   localparam DEBUG_SPI_READ        = 0;  // Set to 1 to perform SPI read from external device for debugging purpose
   localparam ROM_CHN_DIVIDER0_ADDR = 10; // TBD
   localparam DATARATE              = 0;  // TBD - 0:4.9152Gbps (example), 1:2.4576Gbps (example)
   localparam BONDED_MODE           = "non_bonded"; // valid value "non_bonded", "bonded"
   localparam NUM_CHANNEL           = (BONDED_MODE == "bonded") ? ((L>5) ? L+2 : L+1) : LINK*L*2;
   
   //   
   // Registers and wires declaration   
   //   
   reg          frame_rst;
   reg          link_rst;
   reg          avs_rst;
   reg  [4:0]   current_state;
   reg  [4:0]   next_state;
   reg          inc_rom_addr_ptr;
   reg          clr_rom_addr_ptr;
   reg          set_rom_clken;
   reg          set_delay_cnt;  
   reg          dec_delay_cnt;
   reg          set_spi_write;
   reg          set_spi_read;  
   reg          set_poll_status; 
   reg          set_first_read;  
   reg          set_reset;
   reg          clr_avs_reset;
   reg          clr_core_reset;
   reg  [6:0]   rom_addr_ptr;
   reg  [3:0]   rom3_addr_ptr;
   reg          rom_clken;
   reg  [4:0]   delay_cnt;
   reg          first_read;
   reg          spi_write_r;
   reg          spi_read_r;   
   reg  [2:0]   spi_addr_r;
   reg          spi_select_r;
   reg  [SPI_WIDTH-1:0]  spi_txdata_r;
   reg  [SPI_WIDTH-1:0] 	slaveselect_shift;
   reg  [1:0]  	slaveselect_cnt;
   reg          set_spi_write_fake;
   reg          set_slaveselect;
   reg          inc_slaveselect;
   reg          set_init_done;
   reg          init_done;
   //reg          pll_read;
//   reg          pll_write;
//   reg  [5:0]   pll_address;
//   reg  [31:0]  pll_writedata;
//   reg          tx_avs_chipselect;
   reg          avs_read;
   reg          avs_write;
   reg  [9:0]   avs_address;
   reg  [31:0]  tx_avs_writedata;
//   reg          rx_avs_chipselect;
//   reg          rx_avs_read;
//   reg          rx_avs_write;
//   reg  [7:0]   rx_avs_address;
   reg  [31:0]  rx_avs_writedata;
//   reg          reconfig_read;
//   reg          reconfig_write;
//   reg  [6:0]   reconfig_address;
//   reg  [31:0]  reconfig_writedata;
   reg          pll_read_r;
   reg          pll_write_r;
   reg  [5:0]   pll_address_r;
   reg  [31:0]  pll_writedata_r;
   reg  [LINK-1:0] tx_avs_chipselect_r;
   reg  [LINK-1:0] tx_avs_read_r;
   reg  [LINK-1:0] tx_avs_write_r;
   reg  [LINK-1:0][9:0]      tx_avs_address_r    ;
   reg  [LINK-1:0][31:0]     tx_avs_writedata_r  ;
   reg  [LINK-1:0][LINK-1:0] rx_avs_chipselect_r ;
   reg  [LINK-1:0] rx_avs_read_r;
   reg  [LINK-1:0] rx_avs_write_r;
   reg  [LINK-1:0][9:0]      rx_avs_address_r   ;
   reg  [LINK-1:0][31:0]     rx_avs_writedata_r ;
   reg          reconfig_read_r;
   reg          reconfig_write_r;
   reg  [6:0]   reconfig_address_r;
   reg  [31:0]  reconfig_writedata_r;
   wire         wire_ready_and;   
   wire         frame_rst_sync;
   wire         link_rst_sync;
   wire [SPI_WIDTH-1:0]  rom_data_out;
   wire [SPI_WIDTH-1:0]  rom0_data_out;
   wire [SPI_WIDTH-1:0]  rom1_data_out;
   wire [SPI_WIDTH-1:0]  rom2_data_out;
   wire [15:0]  rom3_data_out;
   wire         is_read;
   wire         tmt;
   wire         last_rom_addr;
   wire         last_jesd_rom_addr;
   reg          set_slave_0;
   reg [4:0]   runtime_l;
   reg [7:0]   runtime_m;
   reg [7:0]   runtime_f;
   reg [4:0]   runtime_l_prev;
   reg [7:0]   runtime_f_prev;
   wire [7:0]   chn_divider0; // divider for ADC sampling clock
   reg          set_reconfig;
   reg          clr_reconfig;
   reg          reconfig_in_progress;
   reg          set_reconfig_csr_lmf;
   reg          set_reconfig_pll;
   reg          set_reconfig_xcvr;
   wire [5:0]   pll_address;
   wire [31:0]  pll_writedata;
   wire [6:0]   reconfig_address;
   wire [31:0]  reconfig_writedata;
   wire         wire_tx_waitrequest_and; 
   wire         wire_rx_waitrequest_and; 

   reg          set_pll_mif_base;
   reg          set_pll_write_cmd;
   reg          runtime_lmf_reg;
   reg          runtime_datarate_reg;
   reg [4:0]    reconfig_mgmt_state;
   reg [1:0]    set_reconfig_cmd;
   reg          toggle_reconfig_mgmt_state;
   reg          set_reconfig_mgmt_state;
   reg [31:0]   channel_number;
   reg [31:0]   xcvr_mif_base_addr;
   reg          set_channel_number;
   reg          toggle_channel_number;
   reg          set_xcvr_reset;
   reg          clr_xcvr_reset;
   reg          xcvr_rst;
   reg          csr_scr_en_constant;
   reg [4:0]    csr_k_constant;
   reg          set_lmf_read;
   reg          init_reset;
   reg          set_init_reset;
   reg          set_runtime_lmf_read;
   reg          power_state;
   reg [4:0]    pd_channel_num;  
   reg [4:0]    last_pd_channel;     
   integer      j;
   reg          reconfig_reg;
   reg          reconfig_reg2;
   wire         reconfig_wire;

   reg          set_ilas_data1_offset;
   reg          set_avs_address_to_pd_channel_num;
   reg          set_power_state;
   reg          clr_power_state;
   reg          inc_pd_channel_num;
   reg          set_pd_channel_num_to_runtime_l;
   reg          set_pd_channel_num_to_runtime_l_prev;
   reg          set_last_pd_channel_to_runtime_l_prev;
   reg          set_last_pd_channel_to_runtime_l;
	
   // Run time LMF reconfig
//   assign runtime_l = runtime_lmf_reg ? L/2-1 : L-1; // TBD
//   assign runtime_m = runtime_lmf_reg ? M/2-1 : M-1; // TBD
//   assign runtime_f = runtime_lmf_reg ? F-1 : F-1;   // TBD
   assign reconfig_wire = reconfig & ~reconfig_reg2;   // posedge trigger for reconfig signal

   // Run time data rate reconfig
   assign chn_divider0       = runtime_datarate_reg ? DATARATE/2 : DATARATE; // TBD
   assign pll_address        = set_pll_mif_base ? 6'b011111 : 6'b000010;  // MIF Base Address Register:Start Register
   assign pll_writedata      = set_pll_mif_base ? (runtime_datarate_reg ? 32'b00000000000000000000000000000000 : 32'b00000000000000000000000000101110) : 32'h00000001; // Set MIF base address to 46 for downscaling, 0 for compile time configuration
   assign reconfig_address   = 7'd0;  // TBD
   assign reconfig_writedata = 32'd0; // TBD

   // Transceiver initialization successful indication   
   assign wire_ready_and = &tx_ready;
   
   // Waitrequest signals from multiple JESD204B instances  
   assign wire_tx_waitrequest_and = &jesd204_tx_avs_waitrequest;
   assign wire_rx_waitrequest_and = &jesd204_rx_avs_waitrequest;
	
   //   
   // FSM states declaration   
   //   
   localparam INIT                = 0;
   localparam INIT_RESET          = 1;
   localparam SELECT_SLAVE        = 2;
   localparam READ_ROM            = 3;
   localparam WRITE_SPI           = 4;
   localparam NEXT_SLAVE          = 5; 
   localparam POLL_TMT            = 6;
   localparam WAIT_RRDY_LOW       = 7;
   localparam READ_SPI            = 8; 
   localparam SET_RESET           = 9;
   localparam CLR_XCVR_RESET      = 10;
   localparam CLR_AVS_RESET       = 11;
   localparam CLR_CORE_RESET      = 12;
   localparam IDLE                = 13;
   localparam ADC_RECONFIG        = 14; // data rate reconfig
   localparam LMF_RECONFIG        = 15; // LM reconfig
   localparam LMF_READ            = 16; // LM reconfig
   localparam READ_JESD_MIF       = 17; // LM reconfig
   localparam PREPARE_AVS_DATA    = 18; // LM reconfig
   localparam WRITE_JESD_CSR      = 19; // LM reconfig
   localparam SELECT_PD_CHANNEL   = 20; // LM reconfig
   localparam LMF_RECONFIG_DONE   = 21; // LM reconfig
   localparam PLL_RECONFIG_SETUP  = 22; // data rate reconfig
   localparam PLL_RECONFIG_WRITE  = 23; // data rate reconfig
   localparam PLL_RECONFIG_DONE   = 24; // data rate reconfig
   localparam SELECT_XCVR_CHANNEL = 25; // data rate reconfig
   localparam XCVR_RECONFIG       = 26; // data rate reconfig
   localparam XCVR_RECONFIG_POLL  = 27; // data rate reconfig
   //Insert new state ERROR to capture FSM errors
   //
   localparam ERROR               = 28; // FSM error

   
   //   
   // FSM
   //     
   always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin
         current_state <= INIT;
      end else begin
         current_state <= next_state;		
      end
   end

   //   
   // ROM last address
   // Alternative is to add one more last word which define weird/invalid data in the MIF
   // so that when FSM reads and detects that, it terminates the ROM reading
   // Question is what is the best invalid data that does not conflict with the real valid 
   // data accepted by the external cards.   
   //   
   //localparam LAST_ROM_ADDR = 6;
   assign last_rom_addr = &rom_data_out;  
   //assign last_jesd_rom_addr = &rom3_data_out;
			     
   //
   // Next state logic
   //  	
   always @ (current_state or wire_ready_and or spi_trdy or delay_cnt or
             first_read or is_read or spi_rrdy or tmt or last_rom_addr or slaveselect_cnt
             //or rom_addr_ptr
             or reconfig_wire or runtime_l or runtime_m or runtime_f or tx_avs_writedata or rx_avs_writedata
             or wire_tx_waitrequest_and or wire_rx_waitrequest_and or pll_mgmt_waitrequest
             or reconfig_mgmt_waitrequest or init_done or init_reset or reconfig_in_progress or runtime_lmf_reg or runtime_datarate_reg
             or csr_scr_en_constant or csr_k_constant or avs_address or last_jesd_rom_addr
             or pd_channel_num or last_pd_channel or runtime_l or runtime_l_prev or channel_number
             or reconfig_mgmt_state or reconfig_mgmt_readdata)
	     
   begin
      next_state           = current_state;
      inc_rom_addr_ptr     = 1'b0;
      clr_rom_addr_ptr     = 1'b0;
      set_rom_clken        = 1'b0;
      set_delay_cnt        = 1'b0;  
      dec_delay_cnt        = 1'b0;     
      set_spi_write        = 1'b0;
      set_spi_read         = 1'b0; 
      set_poll_status      = 1'b0;
      set_first_read       = 1'b0;      
      set_reset            = 1'b0;
      clr_avs_reset        = 1'b0;
      clr_core_reset       = 1'b0;
      set_spi_write_fake   = 1'b0; // to assert wr_strobe for configuring slaveselect at next clock cycle, mem_addr is kept at 0      
      set_slaveselect      = 1'b0;
      inc_slaveselect      = 1'b0;
      set_init_done        = 1'b0;
      //pll_read           = 1'b0;
      //pll_write          = 1'b0;
      //pll_address        = 6'd0;
      //pll_writedata      = 32'd0;
      //tx_avs_chipselect  = 1'b0;
      //avs_read        = 1'b0;
      //avs_write       = 1'b0;
      //avs_address     = 10'd0;
      //tx_avs_writedata   = 32'd0;
      //rx_avs_chipselect  = 1'b0;
      //rx_avs_read        = 1'b0;
      //rx_avs_write       = 1'b0;
      //rx_avs_address     = 8'd0;
      //rx_avs_writedata   = 32'd0;
      //reconfig_read      = 1'b0;
      //reconfig_write     = 1'b0;
      //reconfig_address   = 7'd0;
      //reconfig_writedata = 32'd0;
      set_slave_0          = 1'b0;
      set_reconfig         = 1'b0;
      clr_reconfig         = 1'b0;
      set_reconfig_csr_lmf = 1'b0;
      set_reconfig_pll     = 1'b0;
      set_reconfig_xcvr    = 1'b0;
      set_pll_mif_base     = 1'b0;
      set_pll_write_cmd    = 1'b0;
      set_reconfig_cmd     = 2'b00;
      toggle_reconfig_mgmt_state = 1'b0;
      set_reconfig_mgmt_state = 1'b0;
      set_channel_number   = 1'b0;
      toggle_channel_number = 1'b0;
      set_xcvr_reset       = 1'b0;
      clr_xcvr_reset       = 1'b0;
      set_lmf_read         = 1'b0;
      set_init_reset       = 1'b0;
      set_runtime_lmf_read = 1'b0;
      set_ilas_data1_offset = 1'b0;
      set_avs_address_to_pd_channel_num     = 1'b0;
      set_power_state       = 1'b0;
      clr_power_state       = 1'b0;
      inc_pd_channel_num    = 1'b0;
      set_pd_channel_num_to_runtime_l       = 1'b0;
      set_pd_channel_num_to_runtime_l_prev  = 1'b0;
      set_last_pd_channel_to_runtime_l_prev = 1'b0;
      set_last_pd_channel_to_runtime_l      = 1'b0;
		
      case (current_state)
         // Initial state upon power up
         // Clear the ROM address pointer  	
         INIT: begin
            if(~init_reset)
               next_state = INIT_RESET;
					
				if (reconfig_in_progress == 1'b1) begin
                 if (runtime_lmf_reg == 1'b1 && runtime_datarate_reg == 1'b0)
                     next_state = PLL_RECONFIG_SETUP;
                 else
                     next_state = LMF_RECONFIG;
            end
            else   
               next_state = SET_RESET;
            //else
            //begin
               //clr_rom_addr_ptr = 1'b1;
               // For multi-slave, assert write to trigger the SPI internal
               // wr_strobe for configuring slaveselect 	
               //if (SLAVE_NUM>1) begin
               //   set_spi_write_fake = 1'b1;	       
               //   next_state = SELECT_SLAVE;
               //end else begin	    
               //   next_state = READ_ROM;
               //end	
            //end
         end

         INIT_RESET: begin
            set_reset = 1'b1;
            set_init_reset = 1'b1;
            next_state = INIT;
         end

         // Write to SPI slaveselect register with corresponding value
         // configure for slave 0 followed by 1, 2 etc 	
         /*SELECT_SLAVE: begin
            set_slaveselect = 1'b1;	    
            next_state = READ_ROM;            
         end*/        
	
         // Read from the ROM 
         // Assert clock enable and wait for few (2 is enough) cycles
         // for valid ROM data out for current address pointer
         // Clear the SPI master RRDY signal by asserting a read signal	
         /*READ_ROM: begin
            set_rom_clken = 1'b1;
            dec_delay_cnt = 1'b1;
            set_spi_read = 1'b1;
            
            if (delay_cnt==5'd17) begin 
               set_delay_cnt = 1'b1; 
               next_state = WRITE_SPI;             
            end   
         end*/

         // If the SPI Master ready to transmit data,
         // trigger a write strobe and write the ROM data out to SPI Master
         // Increment the ROM address pointer and check if it has reached last 
         // address, if yes proceed to handle the reset sequence of the base core
         // else repeat the ROM reading.            
         /*WRITE_SPI: begin
            if (spi_trdy) begin
               //set_spi_write = 1'b1;
               inc_rom_addr_ptr = 1'b1;
	       
               //if (rom_addr_ptr==LAST_ROM_ADDR) begin
               if (last_rom_addr) begin	       
                  // Go to configure next slave 
                  if ((SLAVE_NUM>1 && ~init_done) || (SLAVE_NUM>1 && reconfig_in_progress)) begin
                     if (slaveselect_cnt==SLAVE_NUM-1) begin
                        if (reconfig_in_progress == 1'b1) begin
                           if (runtime_lmf_reg == 1'b1 && runtime_datarate_reg == 1'b0)
                              next_state = PLL_RECONFIG_SETUP;
                           else
                              next_state = LMF_RECONFIG;
                        end
                        else   
                           next_state = SET_RESET;
                     end else begin
                        next_state = NEXT_SLAVE;
                     end			
                  end else begin
                        if (reconfig_in_progress == 1'b1) begin
                           if (runtime_lmf_reg == 1'b1 && runtime_datarate_reg == 1'b0)
                              next_state = PLL_RECONFIG_SETUP;
                           else
                              next_state = LMF_RECONFIG;
                        end
                        else   
                           next_state = SET_RESET;
                  end		     
               end else begin
                  set_spi_write = 1'b1;
                                   
                  if (DEBUG_SPI_READ && is_read) begin
                     if (~first_read) begin
                        next_state = POLL_TMT;
                     end else begin
                        next_state = READ_SPI;
                     end			
                  end else begin		  
                     next_state = READ_ROM;
                  end               
               end  
            end
         end*/ 

         // Wait for the SPI to complete all the pending transaction
         // before proceed to configure next slave	
         /*NEXT_SLAVE: begin
            if (DEBUG_SPI_READ) begin
               if (spi_rrdy) begin
                  inc_slaveselect = 1'b1;
                  next_state = INIT;
               end		  
            end else begin
               set_poll_status = 1'b1;

               if (tmt) begin
                  inc_slaveselect = 1'b1;		  
                  next_state = INIT;
               end
            end	       
         end*/	

         // Performs first real read to get the valid intended/received data
         // Poll SPI master TMT status to determine when is the right time to
         // receive the first real data from SPI slave	
         // TMT asserts when all the data in the queue has been transmitted
         // It is full duplex transaction, at the same transaction the last 
         // 8-bit of MISO data line is the data sent by the SPI slave   
         /*POLL_TMT: begin
            set_poll_status = 1'b1;

            if (tmt) begin
               set_spi_read = 1'b1;
               set_first_read = 1'b1;
               next_state = WAIT_RRDY_LOW;
            end	    
         end*/

         // Safe mechanism to only proceed to transmit next data from ROM
         // when SPI master deasserts the RRDY
         /*WAIT_RRDY_LOW: begin
            if (~spi_rrdy) begin 
               next_state = READ_ROM;
            end  
         end*/	

         // Performs second and subsequent real reads
         // when SPI master has valid data received  	
         /*READ_SPI: begin
            if (spi_rrdy) begin
               set_spi_read = 1'b1;   
               next_state = READ_ROM;
            end
         end*/
	
         // Reset the base core + transceiver
         // when the transceiver reset controller indicates ready
         // this means the transceiver has gone through the reset sequence
         // successfully and it is ready   	
         SET_RESET: begin
            set_reset = 1'b1;
            if (reconfig_in_progress == 1'b1) begin
               set_xcvr_reset = 1'b1;
               next_state = INIT;
            end else begin
               next_state = CLR_XCVR_RESET;	
            end
         end	

         // Clear the XCVR reset
         CLR_XCVR_RESET: begin
            clr_xcvr_reset = 1'b1;
            if (wire_ready_and) begin
		         next_state = CLR_AVS_RESET;
            end
         end

         // Clear the Avalon Slave (resides in the base core) reset	
         CLR_AVS_RESET: begin
            if (~pll_mgmt_waitrequest) begin
               clr_avs_reset = 1'b1;
               dec_delay_cnt = 1'b1;
               if (delay_cnt==0) begin
                  set_delay_cnt = 1'b1;
                  next_state = CLR_CORE_RESET;					
               end
            end
         end

         // Clear the base core reset	
         CLR_CORE_RESET: begin
            clr_core_reset = 1'b1;
            next_state = IDLE;	            			
         end			
	
         // Do nothing		
         IDLE: begin
            set_init_done = 1'b1;
            clr_reconfig  = 1'b1;
            set_delay_cnt = 1'b1;

            if (reconfig_wire) begin
               next_state = ADC_RECONFIG;   
            end
         end

         ADC_RECONFIG: begin
            set_reconfig = 1'b1;
            set_slave_0 = 1'b1;
            next_state = SET_RESET;    // need to put JESD core in reset first before reconfig SPI, else JESD code will give link error towards end of SPI reconfig.
           
         end

         LMF_RECONFIG: begin
            set_reconfig_csr_lmf = 1'b1;
            clr_rom_addr_ptr = 1'b1;
            if ((csr_scr_en_constant == 1'b0) && (csr_k_constant == 5'b0)) begin
               set_ilas_data1_offset = 1'b1;
               dec_delay_cnt = 1'b1;
               if (delay_cnt==5'd19) begin 
                  set_delay_cnt = 1'b1; 
                  next_state = LMF_READ;
               end 
            end else
            begin
               next_state = READ_JESD_MIF;
           end
         end

         LMF_READ: begin
            set_reconfig_csr_lmf = 1'b1;
            avs_write = 1'b0;
            avs_read  = 1'b1;
            dec_delay_cnt = 1'b1;
            
            if (delay_cnt==5'd17) 
            begin
               avs_write = 1'b0;
               avs_read  = 1'b0;
               set_delay_cnt = 1'b1;
               if (avs_address == 10'h94) begin
                  set_lmf_read = 1'b1;                   // only overwrite csr_k_constant & csr_scr_en_constant value if the read address is 10'h94 (ilas_data1 register)
                  next_state = READ_JESD_MIF;
               end else
                  next_state = PREPARE_AVS_DATA;
            end
         end 

         READ_JESD_MIF: begin
            set_reconfig_csr_lmf = 1'b1;
            set_rom_clken = 1'b1;
            dec_delay_cnt = 1'b1;

            if (delay_cnt==5'd15) begin
               set_delay_cnt = 1'b1; 
               if (last_jesd_rom_addr) begin
                  next_state = PREPARE_AVS_DATA;
               end else begin
                  next_state = ERROR;               
               end
            end
            else if (delay_cnt==5'd16) begin  
               if (last_jesd_rom_addr) begin
                  set_ilas_data1_offset = 1'b1;
               end else begin
                  set_delay_cnt = 1'b1;                 
                  set_runtime_lmf_read = 1'b1;
               end
               inc_rom_addr_ptr = 1'b1;
            end
         end
         
         PREPARE_AVS_DATA: begin
            set_reconfig_csr_lmf = 1'b1;
            next_state = WRITE_JESD_CSR;
         end

         WRITE_JESD_CSR: begin
            set_reconfig_csr_lmf = 1'b1;
            avs_write = 1'b1;
            avs_read  = 1'b0;
            dec_delay_cnt = 1'b1;
            
            if (delay_cnt==5'd17) 
            begin
               avs_write = 1'b0;
               avs_read  = 1'b0;
               set_delay_cnt = 1'b1;
               if (avs_address == 10'h94)
                  next_state = LMF_RECONFIG_DONE;
               else
                  next_state = SELECT_PD_CHANNEL;
            end
         end

         SELECT_PD_CHANNEL: begin
            set_reconfig_csr_lmf = 1'b1;
            if (~wire_tx_waitrequest_and & ~wire_rx_waitrequest_and) begin
               if(pd_channel_num <= last_pd_channel)
               begin
                 
                  if (delay_cnt==5'd20) begin
                     dec_delay_cnt = 1'b1;
                     set_avs_address_to_pd_channel_num = 1'b1;
                     inc_pd_channel_num = 1'b0;
                  end                     
                  else if (delay_cnt==5'd19) begin
                     dec_delay_cnt = 1'b0;
                     set_delay_cnt = 1'b1;
                     set_avs_address_to_pd_channel_num = 1'b0;
                     inc_pd_channel_num = 1'b1;
                     next_state = LMF_READ; // go to read lane_ctrl_<n> register before write power down value to it
                  end
               end else
                  if ((runtime_lmf_reg == 1'b1 && runtime_datarate_reg == 1'b1) || (runtime_lmf_reg == 1'b0 && runtime_datarate_reg == 1'b0))
                     next_state = PLL_RECONFIG_SETUP;             // done with lmf reconfig, go to next reconfig
                  else
                     next_state = CLR_XCVR_RESET;                 // done with lmf reconfig, go to next reconfig
            end
         end

         LMF_RECONFIG_DONE: begin
            set_reconfig_csr_lmf = 1'b1;
            if (~wire_tx_waitrequest_and & ~wire_rx_waitrequest_and) begin
               //next_state = PLL_RECONFIG_SETUP; 
               //next_state = CLR_XCVR_RESET;   
               if (runtime_l < runtime_l_prev) begin        // not yet done, need to power down some lanes
                  set_pd_channel_num_to_runtime_l = 1'b1;
                  set_last_pd_channel_to_runtime_l_prev = 1'b1;
                  set_power_state = 1'b1;
                  //Delay by one cycle to account for delayed register setting
  	          dec_delay_cnt = 1'b1;
                  if (delay_cnt==5'd19) begin 
                     set_delay_cnt = 1'b1;                   
                     next_state = SELECT_PD_CHANNEL; // go to select power down lane channel before read the lane_ctrl_<n> register
                  end

               end
               else if (runtime_l > runtime_l_prev) begin   // not yet done, need to power up some lanes
                  set_pd_channel_num_to_runtime_l_prev = 1'b1;
                  set_last_pd_channel_to_runtime_l = 1'b1;
                  clr_power_state = 1'b1;
                  //Delay by one cycle to account for delayed register setting
                  dec_delay_cnt = 1'b1;
                  if (delay_cnt==5'd19) begin 
                     set_delay_cnt = 1'b1;                   
                     next_state = SELECT_PD_CHANNEL; // go to select power down lane channel before read the lane_ctrl_<n> register
                  end
               end else
                  if ((runtime_lmf_reg == 1'b1 && runtime_datarate_reg == 1'b1) || (runtime_lmf_reg == 1'b0 && runtime_datarate_reg == 1'b0))
                     next_state = PLL_RECONFIG_SETUP;             // done with lmf reconfig, go to next reconfig
                  else
                     next_state = CLR_XCVR_RESET;                 // done with lmf reconfig, go to next reconfig
            end
         end

         PLL_RECONFIG_SETUP: begin
            // need to wait until the initial PLL reconfig busy deasserted
            if (~pll_mgmt_waitrequest) begin
               set_reconfig_pll = 1'b1;
               set_pll_mif_base = 1'b1;
               dec_delay_cnt = 1'b1;

               if (delay_cnt==5'd19) 
               begin
                  set_pll_write_cmd = 1'b1;
               end
               else if (delay_cnt==5'd17)
               begin
                  set_delay_cnt = 1'b1;
                  set_pll_write_cmd = 1'b0;
                  next_state = PLL_RECONFIG_WRITE;
               end
            end
         end

         PLL_RECONFIG_WRITE: begin
            set_reconfig_pll = 1'b1;
            set_pll_mif_base = 1'b0;
            dec_delay_cnt = 1'b1;

            if (delay_cnt==5'd19) 
            begin
               set_pll_write_cmd = 1'b1;
            end
            else if (delay_cnt==5'd17)
            begin
               set_delay_cnt = 1'b1;
               set_pll_write_cmd = 1'b0;
               next_state = PLL_RECONFIG_DONE;
            end

            //next_state = XCVR_RECONFIG;
         end
   
         PLL_RECONFIG_DONE: begin
            if (~pll_mgmt_waitrequest) begin
               next_state = SELECT_XCVR_CHANNEL;
            end
         end
  
         SELECT_XCVR_CHANNEL: begin
            set_reconfig_xcvr = 1'b1;
               if (channel_number < NUM_CHANNEL)
                  next_state = XCVR_RECONFIG;             
               else begin
                  set_channel_number = 1'b1;
                  next_state = CLR_XCVR_RESET;  // last state of reconfiguration
               end
         end
       
         XCVR_RECONFIG: begin
            set_reconfig_xcvr = 1'b1;
            dec_delay_cnt = 1'b1;
            
            if (delay_cnt==5'd19) 
            begin
               if (reconfig_mgmt_state == 4'b1000) // final reconfig mgmt state
                  set_reconfig_cmd = 2'b10;
               else
                  set_reconfig_cmd = 2'b01;
            end
            else if (delay_cnt==5'd17)
            begin
               set_delay_cnt = 1'b1;
               set_reconfig_cmd = 2'b00;
               if (reconfig_mgmt_state < 4'b1000)  // final reconfig mgmt state
                  toggle_reconfig_mgmt_state = 1'b1;
               else
                  next_state = XCVR_RECONFIG_POLL;
            end
         end

         XCVR_RECONFIG_POLL: begin
            set_reconfig_xcvr = 1'b1;
            if (~reconfig_mgmt_waitrequest && (reconfig_mgmt_readdata[8] == 1'b0)) begin
               set_reconfig_mgmt_state = 1'b1;
               next_state = SELECT_XCVR_CHANNEL;
               toggle_channel_number = 1'b1;
            end else
               next_state = XCVR_RECONFIG;
         end

        //Insert new state ERROR to capture FSM errors
         ERROR: begin
            next_state = ERROR;			
         end
         
         default: begin
            next_state = INIT;			
         end
      endcase
   end
      
   //   
   // Output register for ROM address pointer   
   //   
   /*always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin  
         rom_addr_ptr <= 7'd0;
         rom3_addr_ptr <= 4'd0;
      end else begin
         if (clr_rom_addr_ptr) begin
            if (runtime_datarate_reg == 1'b1)
               rom_addr_ptr <= 7'd0;
            else
               rom_addr_ptr <= 7'd64;

            if (runtime_lmf_reg == 1'b1)
               rom3_addr_ptr <= 4'd0;
            else
               rom3_addr_ptr <= 4'd8;         
        
         end else if (inc_rom_addr_ptr) begin
            rom_addr_ptr <= rom_addr_ptr + 7'd1;
            rom3_addr_ptr <= rom3_addr_ptr + 4'd1;
         end    
      end       
   end*/

   //   
   // Output register for ROM clock enable      
   //   
   /*always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin  
         rom_clken <= 1'b0;
      end else begin
         if (set_rom_clken) begin
            rom_clken <= 1'b1;  
         end else begin
            rom_clken <= 1'b0;  
         end
      end       
   end*/

   //   
   // Output register for delay counter
   //   
   always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin  
         delay_cnt <= 5'd20;
      end else begin
         if (set_delay_cnt) begin
            delay_cnt <= 5'd20;  
         end else if (dec_delay_cnt) begin
            delay_cnt <= delay_cnt - 5'd1;  
         end
      end       
   end

   //
   // Output register for first read
   // Asserted when first real read is performed   
   //   
   /*always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin  
         first_read <= 1'b0;
      end else begin
         if (set_first_read) begin
            first_read <= 1'b1;  
         end
      end       
   end*/
 
   //   
   // Output register for init_done
   // Set to 1 once power up initialization is done
   //  
   always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin  
         init_done <= 1'b0;
      end else begin
         if (set_init_done) begin
            init_done <= 1'b1;  
         end
      end       
   end
  
   //   
   // Output register for init_reset
   // Set to 1 once power up reset is triggered
   //  
   always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin  
         init_reset <= 1'b0;
      end else begin
         if (set_init_reset) begin
            init_reset <= 1'b1;
         end
      end       
   end

   //   
   // Output register for runtime_lmf & runtime_datarate
   //  
   always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin  
         runtime_lmf_reg      <= 1'b1;
         runtime_datarate_reg <= 1'b1;		
      end else begin
         if (reconfig_wire && ~cu_busy) begin
            runtime_lmf_reg      <= runtime_lmf;
            runtime_datarate_reg <= runtime_datarate;		
         end
      end       
   end

   // ****** for hw testing only ********  
   // edge trigger for reconfig signal
   //  
   always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin
         reconfig_reg <= 1'b0;
         reconfig_reg2 <= 1'b0;
      end else begin
         reconfig_reg <= reconfig;
         reconfig_reg2 <= reconfig_reg;
      end
   end


   //   
   // Output register for csr_scr_en_constant & csr_k_constant
   //  
   always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin  
         csr_k_constant <= 5'b0;
         csr_scr_en_constant <= 1'b0;		
      end else begin
         if (set_lmf_read) begin
            // current use model is tx and rx running at same configuration in duplex mode, read tx value is enough.
            csr_scr_en_constant <= jesd204_tx_avs_readdata >> 7 & 1'b1;              
            csr_k_constant <= jesd204_tx_avs_readdata >> 16 & 5'b11111;
         end
      end       
   end
 
   //   
   // Output register for runtime_l, runtime_m, runtime_f, runtime_l_prev & runtime_f_prev
   //  
   always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin  
         runtime_l <= L-1;
         runtime_m <= M-1;
         runtime_f <= F-1;
         runtime_l_prev <= 5'b0;
         runtime_f_prev <= 8'b0;		
      end else begin
         if (set_runtime_lmf_read) begin
            case(rom3_addr_ptr[2:0])
               3'b000: begin
                  runtime_l_prev <= runtime_l;
                  runtime_l <= rom3_data_out & 5'b11111;
               end

               3'b001: begin
                  runtime_m <= rom3_data_out & 8'b11111111;
               end

               3'b010: begin
                  runtime_f_prev <= runtime_f;
                  runtime_f <= rom3_data_out & 8'b11111111;
               end
            endcase        
         end
      end       
   end


   //   
   // Output register for reconfig_in_progress
   // Set to 1 during run time reconfig
   // 
   always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin  
         reconfig_in_progress <= 1'b0;
      end else begin
         if (clr_reconfig) begin
            reconfig_in_progress <= 1'b0;  
         end else if (set_reconfig) begin
            reconfig_in_progress <= 1'b1;  
         end
      end       
   end

   assign cu_busy = (reconfig_in_progress | ~init_done);

   //
   // Output registers for multi-slave operation
   //    
   /*always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin  
         slaveselect_shift <= 24'd1;
         slaveselect_cnt <= 2'd0;	 
      end else begin
         if (inc_slaveselect) begin 
            slaveselect_shift <= {slaveselect_shift[22:0], 1'b0};
            slaveselect_cnt <= slaveselect_cnt + 2'd1;
         end else if (set_slave_0) begin
            slaveselect_shift <= 24'd1;
            slaveselect_cnt <= 2'd0;        
         end else begin
            slaveselect_shift <= slaveselect_shift;
            slaveselect_cnt <= slaveselect_cnt;
         end
      end       
   end*/
   
   //   
   // Output register for SPI Master control signals and data
   //   
   /*always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin  
         spi_write_r  <= 1'b0;
         spi_read_r   <= 1'b0;	 
         spi_select_r <= 1'b0;
         spi_addr_r   <= 3'd0;
         spi_txdata_r <= {SPI_WIDTH{1'b0}};
      end else begin
         // Write signal	 
         if (set_spi_write || set_spi_write_fake) begin
            spi_write_r <= 1'b1;
         end else begin
            spi_write_r <= 1'b0;
         end

         // Read signal	 
         if (set_spi_read) begin
            spi_read_r <= 1'b1;
         end else begin
            spi_read_r <= 1'b0;  
         end
	 
         // Address signal   
         if (set_spi_read) begin
            spi_addr_r <= 3'd0;
         end else if (set_spi_write) begin
            spi_addr_r <= 3'd1;
         end else if (set_poll_status) begin
            spi_addr_r <= 3'd2;
         end else if (set_slaveselect) begin
            spi_addr_r <= 3'd5;	    
         end else begin
            spi_addr_r <= 3'd0;
         end

         // SPI select signal        
         if (set_spi_write || set_spi_read || set_spi_write_fake) begin
            spi_select_r <= 1'b1;
         end else begin
            spi_select_r <= 1'b0;
         end

         // Configure the slaveselect register for multi-slave operation
         if (set_slaveselect) begin
            spi_txdata_r <= slaveselect_shift;
         // if it is read transaction, tri-state the lower 8-bit data bits	    
         end else if (is_read) begin
            spi_txdata_r <= {rom_data_out[SPI_WIDTH-1:8], 8'hzz};
         end else begin
            if (reconfig_in_progress && rom_addr_ptr==ROM_CHN_DIVIDER0_ADDR) begin
               spi_txdata_r <= {rom_data_out[SPI_WIDTH-1:8], chn_divider0[7:0]}; // update channel divider 
            end else begin
               spi_txdata_r <= rom_data_out;               
            end	    
         end
      end       
   end

   assign rom_data_out = slaveselect_cnt==2 ? rom2_data_out :
                         slaveselect_cnt==1 ? rom1_data_out :
                                              rom0_data_out;

   assign tmt         = spi_rxdata[5];
   assign is_read     = spi_txdata_r[23];   
   assign spi_txdata  = spi_txdata_r;
   assign spi_write_n = ~spi_write_r;
   assign spi_read_n  = ~spi_read_r;   
   assign spi_addr    = spi_addr_r; 
   assign spi_select  = spi_select_r;*/    

   //   
   // Output register for base core + transceiver resets   
   // 
   always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin
         frame_rst <= 1'b0;
         link_rst <= 1'b0;
         avs_rst <= 1'b0;
         xcvr_rst <= 1'b0;
      end else begin
         if (clr_core_reset) begin
            frame_rst <= 1'b0;
            link_rst <= 1'b0;
         end else if (clr_avs_reset) begin
            avs_rst <= 1'b0;
         end else if (clr_xcvr_reset) begin
            xcvr_rst <= 1'b0;         
         end else if (set_reset) begin
            frame_rst <= 1'b1;
            link_rst <= 1'b1;
            if(~reconfig_in_progress) begin
               avs_rst <= 1'b1;
            end
            if(set_xcvr_reset) begin
               xcvr_rst <= 1'b1;
            end
         end			
      end	
   end
   
   assign frame_rst_n = ~frame_rst;
   assign link_rst_n  = ~link_rst;
   assign avs_rst_n   = ~avs_rst;
   assign xcvr_rst_n  = ~xcvr_rst;

   //   
   // Output register for PLL Reconfig Avalon MM   
   //
   always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin
         pll_read_r <= 1'b0;
         pll_write_r <= 1'b0;
         pll_address_r <= 6'd0;
         pll_writedata_r <= 32'd0;
      end else begin
         pll_read_r <= 1'b0;
         pll_write_r <= 1'b0;
         pll_address_r <= 6'd0;
         pll_writedata_r <= 32'd0;
                 
         if (set_reconfig_pll) begin
            pll_read_r <= 1'b0;
            if(set_pll_write_cmd) 
               pll_write_r <= 1'b1;
            else
               pll_write_r <= 1'b0; 
            pll_address_r <= pll_address;
            pll_writedata_r <= pll_writedata;
        end
      end	
   end

   assign pll_mgmt_read = pll_read_r;
   assign pll_mgmt_write = pll_write_r;
   assign pll_mgmt_address = pll_address_r;
   assign pll_mgmt_writedata = pll_writedata_r;

   // Output register for PD Channel Number
   // 
   always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin  
         pd_channel_num <= 5'd0;
      end else if (set_pd_channel_num_to_runtime_l) begin
         pd_channel_num <= runtime_l + 5'b00001; 
      end else if (set_pd_channel_num_to_runtime_l_prev) begin
         pd_channel_num <= runtime_l_prev + 5'b00001;
      end else if (inc_pd_channel_num) begin
		     pd_channel_num <= pd_channel_num + 5'b00001;
      end
   end	

   // Output register for last pd channel
   // 
   always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin  
         last_pd_channel <= 5'd0;
      end else if (set_last_pd_channel_to_runtime_l) begin
         last_pd_channel <= runtime_l;
      end else if (set_last_pd_channel_to_runtime_l_prev) begin
         last_pd_channel <= runtime_l_prev;
      end
   end	
	
   // Output register for power state
   // 
   always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin  
         power_state <= 1'b0;
      end else if (clr_power_state) begin
            power_state <= 1'b0;  
      end else if (set_power_state) begin
            power_state <= 1'b1;  
      end
   end

   // Output register for TX AVS Write Data
   //
   always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin
         tx_avs_writedata     <= 32'd0;
         rx_avs_writedata     <= 32'd0;			
      end else begin
         if (avs_address == 10'h94) begin
            tx_avs_writedata <= {runtime_m[7:0], 3'b000, csr_k_constant, runtime_f[7:0], csr_scr_en_constant, 2'b00, runtime_l[4:0]}; 
            rx_avs_writedata <= tx_avs_writedata;
         end else begin
            tx_avs_writedata <= jesd204_tx_avs_readdata;
            rx_avs_writedata <= jesd204_rx_avs_readdata;
            tx_avs_writedata[1] <= power_state;
            rx_avs_writedata[1] <= power_state;
         end
	   end		
	end	

   // Output register for AVS Address
   //
   always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin
         avs_address <= 10'd0;	
      end else if (set_ilas_data1_offset) begin
         avs_address <= 10'h94;
      end else if (set_avs_address_to_pd_channel_num) begin       
         avs_address <= ((pd_channel_num + 5'b00001) * 4) & 10'b1111111111;
      end			
   end	
   
   generate 
   for (i=0; i<LINK; i=i+1) begin: AVMM    
   //   
   // Output register for Base Core Tx CSR Avalon MM   
   //
   always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin
         tx_avs_chipselect_r[i] <= 1'b0;
         tx_avs_read_r[i]       <= 1'b0;
         tx_avs_write_r[i]      <= 1'b0;
         tx_avs_address_r[i]    <= 8'd0;
         tx_avs_writedata_r[i]  <= 32'd0;
      end else begin
         tx_avs_chipselect_r[i] <= 1'b0;
         tx_avs_read_r[i]       <= 1'b0;
         tx_avs_write_r[i]      <= 1'b0;
         tx_avs_address_r[i]    <= 8'd0;
         tx_avs_writedata_r[i]  <= 32'd0;
         
         if (set_reconfig_csr_lmf) begin        
            tx_avs_chipselect_r[i] <= 1'b1;
            tx_avs_read_r[i] <= avs_read;
            tx_avs_write_r[i] <= avs_write;
            tx_avs_address_r[i] <= avs_address;
            tx_avs_writedata_r[i] <= tx_avs_writedata;
         end            
      end	
   end

   assign jesd204_tx_avs_chipselect[i] = tx_avs_chipselect_r[i];
   assign jesd204_tx_avs_read[i]       = tx_avs_read_r[i];
   assign jesd204_tx_avs_write[i]      = tx_avs_write_r[i];
   assign jesd204_tx_avs_address[i]    = tx_avs_address_r[i];
   assign jesd204_tx_avs_writedata[i]  = tx_avs_writedata_r[i];
   
   //   
   // Output register for Base Core Rx CSR Avalon MM   
   //
   always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin
         rx_avs_chipselect_r[i] <= 1'b0;
         rx_avs_read_r[i] <= 1'b0;
         rx_avs_write_r[i] <= 1'b0;
         rx_avs_address_r[i] <= 8'd0;
         rx_avs_writedata_r[i] <= 32'd0;
      end else begin
         rx_avs_chipselect_r[i] <= 1'b0;
         rx_avs_read_r[i] <= 1'b0;
         rx_avs_write_r[i] <= 1'b0;
         rx_avs_address_r[i] <= 8'd0;
         rx_avs_writedata_r[i] <= 32'd0;
         
         if (set_reconfig_csr_lmf) begin        
            rx_avs_chipselect_r[i] <= 1'b1;
            rx_avs_read_r[i] <= avs_read;
            rx_avs_write_r[i] <= avs_write;
            rx_avs_address_r[i] <= avs_address;
            rx_avs_writedata_r[i] <= rx_avs_writedata;
         end
      end	
   end
   
   assign jesd204_rx_avs_chipselect[i] = rx_avs_chipselect_r[i];
   assign jesd204_rx_avs_read[i]       = rx_avs_read_r[i];
   assign jesd204_rx_avs_write[i]      = rx_avs_write_r[i];
   assign jesd204_rx_avs_address[i]    = rx_avs_address_r[i];
   assign jesd204_rx_avs_writedata[i]  = rx_avs_writedata_r[i];
   
	end
	endgenerate
	
   //   
   // Output register for Transceiver Reconfig Controller Avalon MM   
   //
   always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin
         reconfig_read_r <= 1'b0;
         reconfig_write_r <= 1'b0;
         reconfig_address_r <= 7'd0;
         reconfig_writedata_r <= 32'd0;
      end else begin
         reconfig_read_r <= 1'b0;
         reconfig_write_r <= 1'b0;
         reconfig_address_r <= 7'd0;
         reconfig_writedata_r <= 32'd0;
         
         if (set_reconfig_xcvr) begin        
            case (reconfig_mgmt_state)
               4'b0000: begin
                  // Write logical channel number 
                  reconfig_address_r <= 32'h00000038;
                  reconfig_writedata_r <= channel_number;
               end
      
               4'b0001: begin
                  // Write MIF mode
                  reconfig_address_r <= 32'h0000003A;
                  reconfig_writedata_r <= 32'h00000000;
               end
   
               4'b0010: begin
                  // Write to select MIF Base Address offset
                  reconfig_address_r <= 32'h0000003B;
                  reconfig_writedata_r <= 32'h00000000;
               end

               4'b0011: begin
                  // Write MIF Base Address (0 - original TX PLL MIF, 12 - original Channel MIF, 93 - downscale TX PLL MIF, 105 - downscale Channel MIF)
                  reconfig_address_r <= 32'h0000003C;
                  reconfig_writedata_r <= xcvr_mif_base_addr;
               end

               4'b0100: begin
                  // Write all data to streamer
                  reconfig_address_r <= 32'h0000003A;
                  reconfig_writedata_r <= 32'h00000001;
               end

               4'b0101: begin
                  // Write to select Start MIF stream offset
                  reconfig_address_r <= 32'h0000003B;
                  reconfig_writedata_r <= 32'h00000001;
               end
   
               4'b0110: begin
                  // Write to set word MIF address mode and start MIF stream
                  reconfig_address_r <= 32'h0000003C;
                  reconfig_writedata_r <= 32'h00000003;
               end
   
               4'b0111: begin
                  // Write all data to streamer
                  reconfig_address_r <= 32'h0000003A;
                  reconfig_writedata_r <= 32'h00000001;
               end
   
               4'b1000: begin
                  // Issue read command
                  reconfig_address_r <= 32'h0000003A;
               end

               default: begin
                  // Issue read command
                  reconfig_address_r <= 32'h0000003A;
               end
            endcase

            if (set_reconfig_cmd == 2'b01)
            begin
               reconfig_read_r  <= 1'b0;
               reconfig_write_r <= 1'b1;
            end else if (set_reconfig_cmd == 2'b10)
            begin
               reconfig_read_r  <= 1'b1;
               reconfig_write_r <= 1'b0;
            end else
            begin
               reconfig_read_r  <= 1'b0;
               reconfig_write_r <= 1'b0;
            end
         end  // end if
      end	
   end

   assign reconfig_mgmt_read = reconfig_read_r;
   assign reconfig_mgmt_write = reconfig_write_r;
   assign reconfig_mgmt_address = reconfig_address_r;
   assign reconfig_mgmt_writedata = reconfig_writedata_r;


   //   
   // Output register for reconfig_mgmt_state
   //  
   always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin  
         reconfig_mgmt_state <= 4'b0;
      end else begin
         if (set_reconfig_mgmt_state) begin
            reconfig_mgmt_state <= 4'b0;  
         end else if (toggle_reconfig_mgmt_state) begin
            reconfig_mgmt_state <= reconfig_mgmt_state + 4'b0001;  
         end
      end       
   end


   //   
   // Output register for channel number & xcvr_mif_base_addr
   //  
   always @ (posedge clk or negedge rst_n)
   begin
      if (~rst_n) begin  
         channel_number <= 32'b0;
         xcvr_mif_base_addr <= 32'b0;
      end else begin
         if (set_channel_number) begin
            channel_number <= 32'b0; 
          end else if (toggle_channel_number) begin
            channel_number <= channel_number + 32'h00000001;  
         end

         // For bonded mode, L is the last channel number, which is TX_PLL
         if ((channel_number % (L*2)) < L)
         begin
            if (runtime_datarate_reg == 1'b1)
               xcvr_mif_base_addr <= 32'd12; 
            else if (runtime_datarate_reg == 1'b0)
               xcvr_mif_base_addr <= 32'd105; 
         end else
         begin
            if (runtime_datarate_reg == 1'b1)
               xcvr_mif_base_addr <= 32'd0; 
            else if (runtime_datarate_reg == 1'b0)
               xcvr_mif_base_addr <= 32'd93; 
         end
      end       
   end

   //   
   // ROMs that holds the MIF
   // MIF contains the required write sequence for external ADC or DAC    
   //
   // ROM 0: ADC
   //
   // rom_1port_128 #(
      // .INIT_FILE ("./adc.mif"),  
      // .WIDTH     (SPI_WIDTH),
      // .DEVICE_FAMILY(DEVICE_FAMILY)
   // ) u_rom0 (                       
      // .clock   (clk),                    
      // .clken   (rom_clken),
      // .address (rom_addr_ptr),
      // .q       (rom0_data_out)
    // );
    
   //
   // ROM 1: DAC
   //
   // rom_1port_128 #(
      // .INIT_FILE ("./dac.mif"),  
      // .WIDTH     (SPI_WIDTH),
      // .DEVICE_FAMILY(DEVICE_FAMILY)
   // ) u_rom1 (                       
      // .clock   (clk),                    
      // .clken   (rom_clken),
      // .address (rom_addr_ptr),
      // .q       (rom1_data_out)
    // );

   //
   // ROM 2: Clock
   //
   // rom_1port_128 #(
      // .INIT_FILE ("./clock.mif"),  
      // .WIDTH     (SPI_WIDTH),
      // .DEVICE_FAMILY(DEVICE_FAMILY)
   // ) u_rom2 (                       
      // .clock   (clk),                    
      // .clken   (rom_clken),
      // .address (rom_addr_ptr),
      // .q       (rom2_data_out)
    // );

   //
   // ROM 3: JESD
   //
   // rom_1port_16 #(
      // .INIT_FILE ("./jesd.mif"),
      // .DEVICE_FAMILY(DEVICE_FAMILY)  
   // ) u_rom3 (                       
      // .clock   (clk),                    
      // .clken   (rom_clken),
      // .address (rom3_addr_ptr),
      // .q       (rom3_data_out)
    // );

   //
   // FOR RUNTIME RECONFIG
   //    
   // Rx/Tx 0x94 ILAS Data 1 [4:0] csr_l
   //                        [15:8] csr_f
   //                        [31:24] csr_m
   // lane powerdown features are currently not supported by transport layer
   // Rx/Tx 0x4 Physical Lane Ctrl 0 [1]=1 Power down
   // Rx/Tx 0x8 Physical Lane Ctrl 1 [1]=1 Power down
   // Rx/Tx 0xC Physical Lane Ctrl 2 [1]=1 Power down
   // Rx/Tx 0x10 Physical Lane Ctrl 3 [1]=1 Power down
   // During LMF runtime reconfig (only support single link 442 or 222), program CSRs above and 
   // connect csr_lane_powerdown[L-1:0] to rx_digital/analog 
   // and tx_digital resets[L-1:0] and OR with the resets wire from reset controllers
   // Also connects rx_digital/analog and tx_digital resets[L-1:0] to
   // rx/tx_manual[L-1:0] of reset controllers respectively.
   
   // DIP[0] = 0:3.072Gbps, 1:6.144Gbps (runtime data rate)
   // DIP[1] = 0:112 or 222, 1: 222 or 442 (runtime L&M)
   // DIP[2] = 0:Lane 0 On, 1: Lane 0 Off
   // DIP[3] = 0:Lane 1 On, 1: Lane 1 Off
   // DIP[4] = 0:Lane 2 On, 1: Lane 2 Off (only for 442)
   // DIP[5] = 0:Lane 3 On, 1: Lane 3 Off (only for 442)
   // PUSHBUTTON[0] = push when DIP[5:0] is configured to trigger reconfig
   
   // Run-time reconfig L and M (down-scale) for internal serial loopback
   // Configure Tx/Rx CSR
   // Reset
   // LED[0] = en0 & ~error0  LED[1:3] for subsequent lanes
   // en0=1, error0=0 (valid data w/ no error) LED:ON
   // en0=1, error0=1 (valid data w/ error) LED:OFF
   // en0=0, error0=0 (no valid data) LED:OFF
   // en0=0, error0=1 (impossible) LED:OFF
   
   // Run-time data rate for Rx interop w/ FMC176 inclusive of AD9517 & AD9250
   // Configure AD9517 to change sampling clock (/2) for AD9250
   // Configure Rx XCVR CDR clock to divide by 2
   // Configure PLL outclk0 (frame_clk) and outclk1(link_clk) to divide by 2
   // Reset
   // LED[4] = valid & ~rx_int  LED[5:7] for subsequent lanes
   //    
endmodule
