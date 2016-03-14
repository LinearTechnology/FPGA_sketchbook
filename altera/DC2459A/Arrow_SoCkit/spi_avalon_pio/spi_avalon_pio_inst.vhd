	component spi_avalon_pio is
		port (
			clk_clk                                                    : in    std_logic                     := 'X'; -- clk
			pio_data_export                                            : out   std_logic_vector(31 downto 0);        -- export
			reset_reset_n                                              : in    std_logic                     := 'X'; -- reset_n
			spi_bridge_mosi_to_the_spislave_inst_for_spichain          : in    std_logic                     := 'X'; -- mosi_to_the_spislave_inst_for_spichain
			spi_bridge_nss_to_the_spislave_inst_for_spichain           : in    std_logic                     := 'X'; -- nss_to_the_spislave_inst_for_spichain
			spi_bridge_miso_to_and_from_the_spislave_inst_for_spichain : inout std_logic                     := 'X'; -- miso_to_and_from_the_spislave_inst_for_spichain
			spi_bridge_sclk_to_the_spislave_inst_for_spichain          : in    std_logic                     := 'X'  -- sclk_to_the_spislave_inst_for_spichain
		);
	end component spi_avalon_pio;

	u0 : component spi_avalon_pio
		port map (
			clk_clk                                                    => CONNECTED_TO_clk_clk,                                                    --        clk.clk
			pio_data_export                                            => CONNECTED_TO_pio_data_export,                                            --   pio_data.export
			reset_reset_n                                              => CONNECTED_TO_reset_reset_n,                                              --      reset.reset_n
			spi_bridge_mosi_to_the_spislave_inst_for_spichain          => CONNECTED_TO_spi_bridge_mosi_to_the_spislave_inst_for_spichain,          -- spi_bridge.mosi_to_the_spislave_inst_for_spichain
			spi_bridge_nss_to_the_spislave_inst_for_spichain           => CONNECTED_TO_spi_bridge_nss_to_the_spislave_inst_for_spichain,           --           .nss_to_the_spislave_inst_for_spichain
			spi_bridge_miso_to_and_from_the_spislave_inst_for_spichain => CONNECTED_TO_spi_bridge_miso_to_and_from_the_spislave_inst_for_spichain, --           .miso_to_and_from_the_spislave_inst_for_spichain
			spi_bridge_sclk_to_the_spislave_inst_for_spichain          => CONNECTED_TO_spi_bridge_sclk_to_the_spislave_inst_for_spichain           --           .sclk_to_the_spislave_inst_for_spichain
		);

