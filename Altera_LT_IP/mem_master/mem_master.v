`timescale 1ns/1ns

//this file implements an Avalon Master which is used to write data into an
//external RAM using a provided RAM controller.

module mem_master (
    input clk,
    input resetn,
    input [31:0] data,
    input [31:0] addr,
    input go,
    output reg ready,
    output reg write,
    output reg [31:0] writedata,
    input waitrequest,
    output reg [31:0] address
    );

    localparam WAIT_STATE = 1'b0;
    localparam WRITE_STATE = 1'b1;
    reg state;
    always @ (posedge clk) begin
        if (!resetn) begin
            state <= WAIT_STATE;
            writedata <= 32'b0;
            write <= 1'b0;
            address <= 32'b0;
            ready <= 1'b0;
        end else begin
            case (state)
                WAIT_STATE: begin
                    if (go) begin
                        write <= 1'b1;
                        writedata <= data;
                        state <= WRITE_STATE;
                        address <= addr;
                        ready <= 1'b0;
                    end else begin
                        write <= 1'b0;
                        //writedata <= 32'b0;
                        //state <= WAIT_STATE;
                        //address <= 32'b0;
                        ready <= 1'b1;
                    end
                end
                WRITE_STATE: begin
                    if (waitrequest) begin
                        write <= 1'b1;
                        writedata <= writedata;
                        state <= WRITE_STATE;
                        address <= address;
                        ready <= 1'b0;
                    end else begin
                        write <= 1'b0;
                        //writedata <= 32'b0;
                        state <= WAIT_STATE;
                        //address <= 32'b0;
                        ready <= 1'b1;
                    end
                end
            endcase
        end
    end

endmodule