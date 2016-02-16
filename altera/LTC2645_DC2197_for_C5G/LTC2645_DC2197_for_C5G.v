module LTC2645_DC2197_for_C5G(
input wire clk,
output wire out0,
output wire out1,
output wire out2,
output wire out3
);

//parameter duty0 = 12'd1023;
//parameter duty1 = 12'd2043;
//parameter duty2 = 12'd3071;
//parameter duty3 = 12'd818;

reg [12:0] divider;
reg nco_clk;

wire [11:0]duty0;
wire [11:0]duty1;
wire [11:0]duty2;
wire [11:0]duty3;


PWM pwm_A (clk, {~duty0[11],duty0[10:0]}, out2);
PWM pwm_B (clk, {~duty1[11],duty1[10:0]}, out3);
PWM pwm_C (clk, {~duty2[11],duty2[10:0]}, out0);
PWM pwm_D (clk, {~duty3[11],duty3[10:0]}, out1);


NCO14_1 i_nco1 (
    .out_valid(),
    .fsin_o(duty0),
    .fcos_o(duty1),
    .phi_inc_i(24'd167772), //100Hz @10ksps
    .reset_n(1'b1),
    .clken(nco_clk),
    .clk(clk)
    );
	 
NCO14_1 i_nco2 (
    .out_valid(),
    .fsin_o(duty2),
    .fcos_o(duty3),
    .phi_inc_i(24'd838861), //500Hz @10ksps
    .reset_n(1'b1),
    .clken(nco_clk),
    .clk(clk)
    );

always @(posedge clk)
	begin
		if(divider == 13'd81919)//*period)
			begin
			divider <= 13'd0;
			nco_clk <= 1;
			end
		else
			begin
			divider <= divider + 1;
			nco_clk <= 0;
			end

	end


endmodule
