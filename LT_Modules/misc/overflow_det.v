module overflow_det(q,qbar,r,s,clk);
	output q,qbar;
	input r,s,clk;
	reg q,qbar;
	initial
	begin
		q=1'b0;
		qbar=1'b1;
	end
	always @(posedge clk)
	  begin
	  case({s,r})
		 {1'b0,1'b0}: begin q=q; qbar=qbar; end
		 {1'b0,1'b1}: begin q=1'b0; qbar=1'b1; end
		 {1'b1,1'b0}: begin q=1'b1; qbar=1'b0; end
		 {1'b1,1'b1}: begin q=1'b1; qbar=1'b0; end // Special case for error detection!!
	endcase
	end
endmodule