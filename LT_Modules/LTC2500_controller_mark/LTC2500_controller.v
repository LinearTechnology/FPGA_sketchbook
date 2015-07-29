`timescale 1ns/1ns

//This module provides a controller for the LTC2500 ADC
//Ned Danyliw --- 7/14/2014



module LTC2500_controller (
    input clk,
    input reset,
    // client <-> controller
    input go, //initiate conversion (single clock pulse)
	input sync_request, // Used to force a hard sync, for multiple devices.
	input [11:0] cfg_word, // Filter configuration
    input [15:0] n, // Number of samples to average minus 1 **** Variable SINC mode only
	input pre_in, // 
    output reg done, //signal end of conversion and valid output data (single clock pulse)
    output reg [19:0] data, //mclked data
	output reg done_filt,
	output reg [31:0] data_filt,
	output error,
    // controller <-> adc
	output pre,
    output reg mclk,
	output sync,
    input busy,
	input drdyl,
	output rdl,
    output sclk,
	input sdo,
	output rdl_filt,
	output sclk_filt,
	input sdo_filt,
	output sdi_filt
    );


localparam ADC_CTRL_WAIT = 2'd0;
localparam ADC_CTRL_CNV = 2'd1;
localparam ADC_CTRL_RD = 2'd2;
localparam ADC_CTRL_CNV_WAIT = 2'd3;

localparam ADC_DATA_WAIT = 2'd0;
localparam ADC_DATA_READ = 2'd1;

localparam ADC_CONVERSION_TIME = 8'd34; // Calculation: CLK frequency * conversion time (50_000_000 * 675ns = 33.75, round to 34)

parameter WIDTH = 20; // Let's make this equal to the desired number of nyquist data bits_left_to_read
parameter WIDTH_FILT = 32; // How many bits of filtered data to read. Nominally 40, some apps may need to reduce.
parameter COUNT_WIDTH = 6;

    //set rdl, rdl_filt to GND
    assign rdl = 1'b0;
	assign rdl_filt = 1'b0;
    //set pre equal to pre_in. Perhaps we should detect this and override cfg_word
	// accordingly.
    assign pre = pre_in;

    reg [1:0] conv_state;
    reg [1:0] data_state;
    reg [8:0] conversion_timer;
    reg [15:0] samples_left_to_avg; // Counter for how many more samples left to average
	reg [11:0] cfg_word_shift_reg;
    reg [COUNT_WIDTH-1:0] bits_left_to_read;
	reg [COUNT_WIDTH-1:0] bits_left_to_read_filt;
	
    reg [WIDTH-1:0] shift_register;
	reg [WIDTH_FILT-1:0] shift_register_filt;
    reg sclk_en;
	reg sclk_filt_en;

	wire [15:0] samples_left_to_avg_wire;
	wire [15:0] downsample_factor_wire;
	
// Decode downsample factor field. The cfg_word input is assumed to be static,
// May need to set false paths.
	assign downsample_factor_wire = (16'b0000_0000_0000_0001 << cfg_word[7:4]) -1;
// Detect Variable SINC mode, assign samples_left... to n port accordingly
	assign samples_left_to_avg_wire = (cfg_word[3:0] == 4'b0111) ? n : downsample_factor_wire;
	
	
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // reset
            conv_state <= ADC_CTRL_WAIT;
			data_state <= ADC_DATA_WAIT;
            done <= 1'b0;
            data <= 20'b0;
			done_filt <= 1'b0;
			data_filt <= 32'b0;
            mclk <= 1'b0;
            sclk_en <= 0; // disable shift clock
            conversion_timer <= 8'b0;
            bits_left_to_read <= 0;
            samples_left_to_avg <= samples_left_to_avg_wire;
			cfg_word_shift_reg <= cfg_word;
            shift_register <= 0;
			shift_register_filt <= 0;
        end
        else begin
			// Handle serial data input. Yes, we can shift ANY time mclk is NOT asserted
			// (Remembering that the mclk signal is a replica of the BUSY state.)
			// We re-register the shift registers at just the right point into
			// data and data_filt output registers.
			// Actually... need to fix this to avoid violating tquiet.
            if(~mclk) begin
                shift_register <= {shift_register[WIDTH-2 : 0], sdo}; // Shift in the next bit on each clock unless blanked.
				shift_register_filt <= {shift_register_filt[WIDTH_FILT-2 : 0], sdo_filt}; // Shift in the next bit on each clock unless blanked.
            end else begin
                shift_register <= shift_register; // Shift in the next bit, always, on each clock. 
				shift_register_filt <= shift_register_filt;
            end

            case (conv_state)
                ADC_CTRL_WAIT: begin
                done <= 0;
                data <= data;
                sclk_en <= sclk_en;
				bits_left_to_read <= WIDTH-1; // Load bit counter
				if (go) begin
                        conv_state <= ADC_CTRL_CNV;
                        mclk <= 1'b1;
                        conversion_timer <= ADC_CONVERSION_TIME;
                        if(samples_left_to_avg == 0) begin
                            samples_left_to_avg <= n;
                        end
                        else begin
                            samples_left_to_avg <= samples_left_to_avg - 1;
                        end
                    end else begin
                        conv_state <= ADC_CTRL_WAIT;
                        mclk <= mclk;
                        conversion_timer <= conversion_timer;
                    end

                end

                ADC_CTRL_CNV: begin
                    //if (!busy) begin
					data <= data;
					bits_left_to_read <= WIDTH-1; // Load bit counter
                    if(conversion_timer == 8'd0) begin // Conversion is done, read data next
                        conv_state <= ADC_CTRL_RD;
                        mclk <= 1'b0;
						sclk_en <= 1; // enable shift clock
                        conversion_timer <= conversion_timer; // Halt decrementing
						done <= done;
                    end else begin
                        conv_state <= ADC_CTRL_CNV;
                        mclk <= mclk;
						sclk_en <= sclk_en; // disable shift clock
                        conversion_timer <= conversion_timer - 8'd1;
						done <= done;
                    end

                end

               ADC_CTRL_RD: begin // Re-grab this state from 2378-20 controller, need to read out each time
                    //if (ser_done) begin
                    if(bits_left_to_read == 0) begin
                        conv_state <= ADC_CTRL_WAIT;
                        done <= 1'b1;
                        data <= {shift_register[WIDTH-2 : 0], sdo}; // {shift_register[18 : 0], sdo}; // {shift_register[WIDTH-2 : 0], sdo};
                        sclk_en <= 0; // disable shift clock
                        bits_left_to_read <= WIDTH-1; // Load bit counter
                    end else begin
                        conv_state <= ADC_CTRL_RD;
                        sclk_en <= sclk_en; // enable shift clock
                        //shift_register <= {shift_register[18 : 0], sdo}; // Shift in the next bit
                        bits_left_to_read <= bits_left_to_read - 1;
                        done <= done;
                        data <= data;
                    end
                    mclk <= mclk;
                    conversion_timer <= conversion_timer;
                end
				
				
				
                // default: begin
                    // conv_state <= ADC_CTRL_WAIT;
                    // mclk <= mclk;
					// done <= done;
                    // //sclk_en <= sclk_en; // disable shift clock
                    // conversion_timer <= conversion_timer;
                    // bits_left_to_read <= bits_left_to_read;
                // end
            endcase

            case(data_state)
                ADC_DATA_WAIT: begin
                    if(go && samples_left_to_avg == 0) begin // This occurs on a single clock, trigger read 
                        data_state <= ADC_DATA_READ;
						data_filt <= data_filt;
                        bits_left_to_read_filt <= WIDTH_FILT-1; // Don't really need to do this conditionally - consider moving
                        sclk_filt_en <= 1; // enable shift clock
                    end else begin
                        data_state <= ADC_DATA_WAIT;
						data_filt <= data_filt;
                        bits_left_to_read_filt <= bits_left_to_read_filt;
                        sclk_filt_en <= sclk_filt_en;
                    end
                    done_filt <= 1'b0;
                end
                ADC_DATA_READ: begin
                    if(bits_left_to_read_filt == 0) begin
                        data_state <= ADC_DATA_WAIT;
                        data_filt <= {shift_register_filt[WIDTH_FILT-2 : 0], sdo}; //shift_register; // {shift_register[18 : 0], sdo}; // {shift_register[WIDTH-2 : 0], sdo};
                        sclk_filt_en <= 0; // disable shift clock
                        done_filt <= 1'b1;
                    end else if (~mclk) begin
                        bits_left_to_read_filt <= bits_left_to_read_filt - 1;
                        data_state <= ADC_DATA_READ;
						data_filt <= data_filt;
                        sclk_filt_en <= sclk_filt_en; //
                        done_filt <= done_filt;
                    end else begin
                        bits_left_to_read_filt <= bits_left_to_read_filt;
                        data_state <= ADC_DATA_READ;
						data_filt <= data_filt;
                        sclk_filt_en <= sclk_filt_en; //
                        done_filt <= done_filt;                        
                    end
                end
                default: begin
                    data_state <= ADC_DATA_WAIT;
                    bits_left_to_read_filt <= bits_left_to_read_filt;
					data_filt <= data_filt;
                end
            endcase
        end


    end

    //generate gated sclk
reg sclk_en_out;
reg sclk_filt_en_out;

    always @ (negedge clk) begin
        sclk_en_out <= sclk_en & ~mclk; // No clocks during conversion
		sclk_filt_en_out <= sclk_filt_en & ~mclk;
    end

    assign sclk = clk & sclk_en_out;
	assign sclk_filt = clk & sclk_filt_en_out;

endmodule

                // ADC_CTRL_RD: begin
                //     //if (ser_done) begin
                //     if(bits_left_to_read == 0) begin
                //         conv_state <= ADC_CTRL_WAIT;
                //         done <= 1'b1;
                //         data <= shift_register; // {shift_register[18 : 0], sdo}; // {shift_register[WIDTH-2 : 0], sdo};
                //         sclk_en <= 0; // disable shift clock
                //         bits_left_to_read <= bits_left_to_read;
                //     end else begin
                //         conv_state <= ADC_CTRL_RD;
                //         sclk_en <= 1; // enable shift clock
                //         //shift_register <= {shift_register[18 : 0], sdo}; // Shift in the next bit
                //         bits_left_to_read <= bits_left_to_read - 1;
                //         done <= done;
                //         data <= data;
                //     end
                //     mclk <= mclk;
                //     conversion_timer <= conversion_timer;
                // end
				
							
				
		// case(cfg_word[7:4])
			// 4'b0010: downsample_factor_wire = 16'd3; // Minus one encoding
			// 4'b0011: downsample_factor_wire = 16'd7;
			// 4'b0100: downsample_factor_wire = 16'd15;
			// 4'b0101: downsample_factor_wire = 16'd31;
			// 4'b0110: downsample_factor_wire = 16'd63;
			// 4'b0111: downsample_factor_wire = 16'd127;
			// 4'b1000: downsample_factor_wire = 16'd255;
			// 4'b1001: downsample_factor_wire = 16'd511;
			// 4'b1010: downsample_factor_wire = 16'd1023;
			// 4'b1011: downsample_factor_wire = 16'd2047;
			// 4'b1100: downsample_factor_wire = 16'd4095;
			// 4'b1101: downsample_factor_wire = 16'd8191;
			// 4'b1110: downsample_factor_wire = 16'd16383;
		// endcase
	// end