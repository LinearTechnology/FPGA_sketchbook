module gen_multi_sysref #(
   parameter F = 4,
	parameter K = 32
) (
   input wire clock,
   input wire rst_n,
//   input wire [4:0] csr_k,
	input wire rx_dev_sync_n,
 //  input wire [7:0] csr_f,
   output reg sysref
);

//localparam csr_k = 8; // Temporary

reg [8:0] n_lmfc_cnt, lmfc_cnt; 
wire n_sysref;

always @ (posedge clock or negedge rst_n) begin
   if (!rst_n) begin
      lmfc_cnt <= 9'h4;
      sysref   <= 1'b0;
   end else begin
      lmfc_cnt <= n_lmfc_cnt;
      sysref   <= n_sysref;
   end
end

//Since F is fix to 4, thus use csr_k to capture lmfc boundary
assign  n_sysref = (rx_dev_sync_n)? 1'b0 :(lmfc_cnt == 1);
//assign n_sysref = (lmfc_cnt == 1'b1);
always @(*) begin
   if (sysref) begin
//   n_lmfc_cnt = (csr_k+1'b1)*F/4 -1'b1;
   n_lmfc_cnt = K*F/4 -1'b1;
   end else begin
   n_lmfc_cnt = lmfc_cnt - 9'h1;
   end
end

endmodule
