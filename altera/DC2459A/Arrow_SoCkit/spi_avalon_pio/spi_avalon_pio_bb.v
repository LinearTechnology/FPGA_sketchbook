
module spi_avalon_pio (
	clk_clk,
	pio_data_export,
	reset_reset_n,
	spi_bridge_mosi_to_the_spislave_inst_for_spichain,
	spi_bridge_nss_to_the_spislave_inst_for_spichain,
	spi_bridge_miso_to_and_from_the_spislave_inst_for_spichain,
	spi_bridge_sclk_to_the_spislave_inst_for_spichain);	

	input		clk_clk;
	output	[31:0]	pio_data_export;
	input		reset_reset_n;
	input		spi_bridge_mosi_to_the_spislave_inst_for_spichain;
	input		spi_bridge_nss_to_the_spislave_inst_for_spichain;
	inout		spi_bridge_miso_to_and_from_the_spislave_inst_for_spichain;
	input		spi_bridge_sclk_to_the_spislave_inst_for_spichain;
endmodule
