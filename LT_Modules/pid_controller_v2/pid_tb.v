`timescale 1ns/1ns

//Testbench for verilog PID controller

module pid_tb();

    reg clk, reset, trig;
    reg signed [31:0] kp, ki, kd;
    reg signed [31:0] setpoint, feedback, old_fb;
    wire signed [31:0] sig_out;
    wire done;

    //clock and reset loop
    initial begin
        clk = 1'b0;
        reset = 1'b1;
        #10 clk = 1'b1;
        #10 clk = 1'b0;
        #10 clk = 1'b1;
        reset = 1'b0;

        forever begin
            #10 clk = ~clk;
        end
    end

    //main stimuli
    initial begin
        #100; //wait for reset
        kp = 32'sd5 << 16;
        ki = 32'sd1 << 14;
        kd = 32'sd1 << 13;
        setpoint = 32'sd10000;
        feedback = 32'sd0;

        repeat (1000) begin
            @ (posedge clk);
            #1 plant(sig_out);
            trig = 1'b1;
            @ (posedge clk);
            #1 trig = 1'b0;
            //wait 10 clock cycles
            repeat (10) @ (posedge clk);
        end
        #100;
        setpoint = 32'sd5000;
        repeat (1000) begin
            @ (posedge clk);
            #1 plant(sig_out);
            trig = 1'b1;
            @ (posedge clk);
            #1 trig = 1'b0;
            //wait 10 clock cycles
            repeat (10) @ (posedge clk);
        end
        #100;
        ki = 32'sd1 << 13;
        repeat (1000) begin
            @ (posedge clk);
            #1 plant(sig_out);
            trig = 1'b1;
            @ (posedge clk);
            #1 trig = 1'b0;
            //wait 10 clock cycles
            repeat (10) @ (posedge clk);
        end
        #100;
        $stop;
    end

    //define tasks
    task plant;
        input signed [31:0] data;
        begin
            old_fb = feedback;
            feedback = (data>>>2) + (old_fb >>> 1);
        end
    endtask

    //pid
    pid #(
        .INPUT_WIDTH(32),
        .OUTPUT_WIDTH(32),
        .PID_PARAM_WIDTH(32),
        .PID_PARAM_FP_PRECISION(16),
        .MAX_OVF_SUM(4)
        ) dut (
        .clk(clk),
        .reset(reset),
        //PID settings
        // K1 = Kp + Ki + Kd
        // K2 = -Kp - 2Kd
        // K3 = Kd
        .kp(kp), //32 bit signed binary fixed point (Q15.16)
        .ki(ki), //32 bit signed binary fixed point (Q15.16)
        .kd(kd), //32 bit signed binary fixed point (Q15.16)
        .setpoint(setpoint), //32 bit signed integer
        //PID signals
        .feedback(feedback), //32 bit signed integer
        .sig_out(sig_out), //32 bit signed integer
        .trig(trig), //triggers new calculation (1 clock pulse)
        .done(done) //signals new valid data on output (1 clock pulse)
    );

endmodule