`timescale 1ns/1ns

//Implements a parameterized pulse generator

module pulse_gen #(parameter OUTPUT_WIDTH = 16) (
    input clk,
    input reset,
    input trig,
    input [31:0] low_period,
    input [31:0] high_period,
    input [OUTPUT_WIDTH-1:0] value,
    output reg [OUTPUT_WIDTH-1:0] out
    );

    reg running;
    reg level;
    reg [31:0] count;
    always @ (posedge clk) begin
        if (reset) begin
            out <= {OUTPUT_WIDTH{1'b0}};
            level <= 1'b0;
            running <= 1'b0;
            count <= 32'b0;
        end else begin
            if (trig) begin
                level <= 1'b0;
                running <= 1'b1;
                count <= 32'b0;
            end else if (running) begin
                if (!level) begin //low period
                    if (count >= low_period) begin
                        level <= 1'b1;
                        count <= 32'b0;
                        out <= value;
                    end else begin
                        level <= 1'b0;
                        count <= count + 32'b1;
                        out <= {OUTPUT_WIDTH{1'b0}};
                    end
                    running <= 1'b1;
                end else begin
                    if (count >= high_period) begin
                        level <= 1'b0;
                        count <= 32'b0;
                        out <= {OUTPUT_WIDTH{1'b0}};
                        running <= 1'b0;
                    end else begin
                        level <= 1'b1;
                        count <= count + 32'b1;
                        out <= value;
                        running <= 1'b1;
                    end
                end
            end else begin
                level <= 1'b0;
                out <= {OUTPUT_WIDTH{1'b0}};
                count <= 32'b0;
                running <= 1'b0;
            end
        end
    end

endmodule