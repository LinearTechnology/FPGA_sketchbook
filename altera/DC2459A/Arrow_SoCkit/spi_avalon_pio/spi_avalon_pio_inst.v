	spi_avalon_pio u0 (
		.clk_clk                                                    (<connected-to-clk_clk>),                                                    //        clk.clk
		.pio_data_export                                            (<connected-to-pio_data_export>),                                            //   pio_data.export
		.reset_reset_n                                              (<connected-to-reset_reset_n>),                                              //      reset.reset_n
		.spi_bridge_mosi_to_the_spislave_inst_for_spichain          (<connected-to-spi_bridge_mosi_to_the_spislave_inst_for_spichain>),          // spi_bridge.mosi_to_the_spislave_inst_for_spichain
		.spi_bridge_nss_to_the_spislave_inst_for_spichain           (<connected-to-spi_bridge_nss_to_the_spislave_inst_for_spichain>),           //           .nss_to_the_spislave_inst_for_spichain
		.spi_bridge_miso_to_and_from_the_spislave_inst_for_spichain (<connected-to-spi_bridge_miso_to_and_from_the_spislave_inst_for_spichain>), //           .miso_to_and_from_the_spislave_inst_for_spichain
		.spi_bridge_sclk_to_the_spislave_inst_for_spichain          (<connected-to-spi_bridge_sclk_to_the_spislave_inst_for_spichain>)           //           .sclk_to_the_spislave_inst_for_spichain
	);

