module PWM(clk_in, duty, out);
	//t = 100 us p= t/2E-8  sd = p/2E12 = 1
//   parameter period = 5_000;
	
	input clk_in;
	input [11:0] duty;
	output out;

	reg out;
	reg[11:0] duty_reg;	// registered duty cycle, to ensure update only occurs at counter rollover
	reg [11:0] counter = 12'd0;
	
	always @(posedge clk_in)
	begin
		counter <= counter + 1;
		
		if(counter <= duty_reg)//*period)
			out = 1; 
		else
			out = 0;
			
   if (counter == 12'd0)
 		duty_reg <= duty;
	end
endmodule
