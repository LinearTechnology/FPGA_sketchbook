`timescale 1ns/1ns

//testbench for adc_controller

// Uncomment to use HW model for ADC
// `define USE_HW_MODEL

module LTC2500_controller_tb();

    //initialize modules

    reg clk, reset, go;
    wire done, done_filt, mclk, busy, sclk, sclk_filt, rdl, chain, sdo, sdi_filt;
    wire [19:0] output_data;
	wire [31:0] output_data_filt;
	wire [15:0] n;
	assign n = 16'd3;
	wire [11:0] cfg_word;
	assign cfg_word = 16'b10_00_0101_0111;



LTC2500_controller LTC2500_controller_inst(
    .clk(clk),
    . reset(reset),
    // client <-> controller
    . go(go), //initiate conversion (single clock pulse)
	. sync_request(1'b0), // Used to force a hard sync, for multiple devices.
	.cfg_word(cfg_word), // Filter configuration
    .n(n), // Number of samples to average minus 1 **** Variable SINC mode only
	.pre_in(1'b0), // 
    .done(done), //signal end of conversion and valid output data (single clock pulse)
    .data(output_data), //converted data
	.done_filt(done_filt),
	.data_filt(output_data_filt),
	.error(),
    // controller <-> adc
	.pre(),
    .mclk(mclk),
	.sync(),
    .busy(busy),
	.drdyl(),
	.rdl(),
    .sclk(sclk), // For the time being, let's grab data on both inputs
	.sdo(sdo_filt),   // (need to update model with both ports)
	.rdl_filt(),
	.sclk_filt(sclk_filt),
	.sdo_filt(sdo_filt),
	.sdi_filt(sdi_filt)
    );
	
	
    reg [31:0] analog_data;

    // `ifdef USE_HW_MODEL
        // adc_model_hw adc (
            // .clk(clk),
            // .reset(reset),
            // .analog_data_in(analog_data),
            // .convert(convert),
            // .ser_clk(sclk_filt),
            // .busy(busy),
            // .ser_data_out(sdo_filt)
        // );
    // `else
        LTC2500_model LTC2500_model_inst(
            .analog_data_in(analog_data),
            .convert(mclk),
            .ser_clk(sclk_filt | sclk),  // Wicked kluge for using a single stream to emulate both.
            .busy(busy),
            .ser_data_out(sdo_filt)
        );
//    `endif



    //reset and clk
    initial begin
        clk = 1'b0;
        reset = 1'b0;
        go = 1'b0;
        #10 reset = 1'b1;
        #10 clk = 1'b1;
        reset = 1'b0;
        forever begin
            #10 clk = ~clk;
        end
    end

    //analog data
    initial begin
        //analog_data = 20'h80000;
        analog_data = 32'hABCD_1234;
        forever begin
            #100 analog_data = analog_data + 32'h00010001;
        end
    end

    //run simulation
    initial begin
        #101; //wait for global reset
        repeat (32) begin
            #(80 * 20) // 100 clock cycles
            go = 1'b1;
            #20
            go = 1'b0;
        end
        #100;
        $stop;
    end

endmodule


    // LTC2500_controller adc_cont (
        // .clk(clk),
        // .reset(reset),
        // //client <-> controller
        // .go(go), //initiate conversion (single clock pulse)
        // .n(16'd7),
        // .done(done), //signal end of conversion and valid output data (single clock pulse)
        // .data(output_data), //converted data
        // //controller <-> adc
        // .convert(convert),
        // .busy(busy),
        // .sclk(sclk),
        // .rdl(rdl),
        // .chain(chain),
        // .sdo(sdo)
    // );