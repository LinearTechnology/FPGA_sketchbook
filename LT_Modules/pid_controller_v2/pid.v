`timescale 1ns/1ns

//This file implements a parameterizable PID controller
//Reference for this design taken from http://brettbeauregard.com/blog/2011/04/improving-the-beginners-pid-introduction/

// Implements following algorithm:
// loop:
//      error = setpoint - measurement
//      d_error = last_error - error
//      error_sum = error_sum + error
//      u = Kp*error + Ki*error_sum + Kd*d_error

// Parameters must be scaled for sampling rate:
// Kp remains the same
// Ki -> Ki * T_s
// Kd -> Kd / T_s

module pid #(
    parameter INPUT_WIDTH = 20,
    parameter OUTPUT_WIDTH = 16,
    parameter PID_PARAM_WIDTH = 16,
    parameter PID_PARAM_FP_PRECISION = 8, //fixed point decimal places (must be <= PID_PARAM_WIDTH-1)
    parameter MAX_OVF_SUM = 4 //overflow bits for err_sum
    ) (
    input clk,
    input reset,
    //PID settings
    input signed [PID_PARAM_WIDTH-1:0] kp, //signed binary fixed point
    input signed [PID_PARAM_WIDTH-1:0] ki, //signed binary fixed point
    input signed [PID_PARAM_WIDTH-1:0] kd, //signed binary fixed point
    input signed [INPUT_WIDTH-1:0] setpoint, //signed integer
    //PID signals
    input signed [INPUT_WIDTH-1:0] feedback, //signed integer
    output signed [OUTPUT_WIDTH-1:0] sig_out, //signed integer
    input trig, //triggers new calculation (1 clock pulse)
    output reg done //signals new valid data on output (1 clock pulse)
    );

    //save maximum width (this is what we will use for calculations)
    localparam DATA_WIDTH = (INPUT_WIDTH>OUTPUT_WIDTH) ? INPUT_WIDTH : OUTPUT_WIDTH;

    reg signed [DATA_WIDTH-1:0] sig_out_norm;
    wire signed [DATA_WIDTH-1:0] setpoint_norm;
    wire signed [DATA_WIDTH-1:0] feedback_norm;
    //scale setpoint, feedback, and sig_out to max DATA_WIDTH to maximize accuracy
    generate
        if (DATA_WIDTH == INPUT_WIDTH && DATA_WIDTH == OUTPUT_WIDTH) begin
            assign setpoint_norm = setpoint;
            assign feedback_norm = feedback;
            assign sig_out = sig_out_norm;
        end else if (DATA_WIDTH == INPUT_WIDTH) begin
            assign setpoint_norm = setpoint;
            assign feedback_norm = feedback;
            assign sig_out = sig_out_norm[DATA_WIDTH-1:DATA_WIDTH-OUTPUT_WIDTH];
        end else begin //DATA_WIDTH == OUTPUT_WIDTH
            assign setpoint_norm = {setpoint, {(DATA_WIDTH-INPUT_WIDTH){1'b0}}};
            assign feedback_norm = {feedback, {(DATA_WIDTH-INPUT_WIDTH){1'b0}}};
            assign sig_out = sig_out_norm;
        end
    endgenerate

    //latched constants
    reg signed [PID_PARAM_WIDTH-1:0] kp_latch;
    reg signed [PID_PARAM_WIDTH-1:0] ki_latch;
    reg signed [PID_PARAM_WIDTH-1:0] kd_latch;

    // PID error signal
    reg signed [DATA_WIDTH-1:0] err;
    reg signed [DATA_WIDTH:0] err_tmp;

    // derivative error term
    reg signed [INPUT_WIDTH:0] d_err;

    // cumulative error term (allow up to 16x max error to be accumulated before overflow)
    reg signed [DATA_WIDTH+MAX_OVF_SUM-1:0] err_sum;
    reg signed [DATA_WIDTH+MAX_OVF_SUM:0] err_sum_tmp;
    //handle saturation
    always @(*) begin
        if (err_sum_tmp > $signed({2'b0, {(DATA_WIDTH+MAX_OVF_SUM-1){1'b1}}})) begin
            err_sum = $signed({1'b0, {(DATA_WIDTH+MAX_OVF_SUM-1){1'b1}}});
        end else if (err_sum_tmp < -$signed({2'b1, {(DATA_WIDTH+MAX_OVF_SUM-1){1'b0}}})) begin
            err_sum = $signed({1'b1, {(DATA_WIDTH+MAX_OVF_SUM-1){1'b0}}});
        end else begin
            err_sum = $signed(err_sum_tmp[MAX_OVF_SUM+DATA_WIDTH-1:0]);
        end
    end 

    //intermediate signals
    wire signed [PID_PARAM_WIDTH+DATA_WIDTH-1:0] term1;
    wire signed [PID_PARAM_WIDTH+DATA_WIDTH+MAX_OVF_SUM-1:0] term2;
    wire signed [PID_PARAM_WIDTH+INPUT_WIDTH:0] term3;

    //memories
    reg signed [INPUT_WIDTH-1:0] input_d1;

    wire signed [PID_PARAM_WIDTH+DATA_WIDTH+MAX_OVF_SUM:0] sig_out_temp;

    assign sig_out_temp = {{(MAX_OVF_SUM+1){term1[PID_PARAM_WIDTH+DATA_WIDTH-1]}}, term1}
        + {{1{term2[PID_PARAM_WIDTH+DATA_WIDTH+MAX_OVF_SUM-1]}}, term2}
        + {{MAX_OVF_SUM{term3[PID_PARAM_WIDTH+DATA_WIDTH]}}, term3};

    //assign multiplications
    assign term1 = kp_latch * err;
    assign term2 = ki_latch * err_sum;
    assign term3 = kd_latch * d_err;

    reg [2:0] state;
    localparam WAIT_STATE = 3'd0;
    localparam ERR_SAT = 3'd1;
    localparam CALC = 3'd2;
    localparam SEND_OUT = 3'd3;
    localparam SEND_OUT_SAT = 3'd4;

    always @(posedge clk) begin
        if (reset) begin
            // reset
            err <= $signed({DATA_WIDTH{1'b0}});
            input_d1 <= $signed({INPUT_WIDTH{1'b0}});
            sig_out_norm <= $signed({DATA_WIDTH{1'b0}});
            done <= 1'b0;
            state <= WAIT_STATE;
            err_tmp <= $signed({DATA_WIDTH{1'b0}});
            d_err <= $signed({(INPUT_WIDTH+1){1'b0}});
            err_sum_tmp <= $signed({(DATA_WIDTH+MAX_OVF_SUM){1'b0}});
            kp_latch <= $signed({PID_PARAM_WIDTH{1'b0}});
            ki_latch <= $signed({PID_PARAM_WIDTH{1'b0}});
            kd_latch <= $signed({PID_PARAM_WIDTH{1'b0}});
        end
        else begin
            case (state)
                WAIT_STATE: begin
                    //wait for signal to calculate next data point
                    if (trig) begin
                        err_tmp <= setpoint_norm - feedback_norm;
                        state <= ERR_SAT;
                    end else begin
                        err <= err;
                        state <= WAIT_STATE;
                    end
                    input_d1 <= input_d1;
                    done <= 1'b0;
                    sig_out_norm <= sig_out_norm;
                    d_err <= d_err;
                    err_sum_tmp <= err_sum;
                    kp_latch <= kp;
                    ki_latch <= ki;
                    kd_latch <= kd;
                end
                ERR_SAT: begin
                    //handle saturation math for error signal
                    if (err_tmp < -$signed({2'b1, {(DATA_WIDTH-1){1'b0}}})) begin
                        err <= $signed({1'b1, {(DATA_WIDTH-1){1'b0}}});
                        err_sum_tmp <= err_sum - $signed({{(MAX_OVF_SUM){1'b0}}, 1'b1, {(DATA_WIDTH-1){1'b0}}});
                    end else if (err_tmp > $signed({2'b0, {(DATA_WIDTH-1){1'b1}}})) begin
                        err <= $signed({1'b0, {(DATA_WIDTH-1){1'b1}}});
                        err_sum_tmp <= err_sum + $signed({{(MAX_OVF_SUM+1){1'b0}}, {(DATA_WIDTH-1){1'b1}}});
                    end else begin
                        err <= err_tmp[DATA_WIDTH-1:0];
                        err_sum_tmp <= err_sum + $signed(err_tmp[DATA_WIDTH-1:0]);
                    end
                    d_err <= feedback - input_d1;
                    input_d1 <= input_d1;
                    done <= 1'b0;
                    sig_out_norm <= sig_out_norm;
                    state <= CALC;
                    kp_latch <= kp_latch;
                    ki_latch <= ki_latch;
                    kd_latch <= kd_latch;
                end
                CALC: begin
                    //wait clock cycle for multiplication
                    state <= SEND_OUT;
                    err <= err;
                    err_tmp <= err_tmp;
                    input_d1 <= input_d1;
                    sig_out_norm <= sig_out_norm;
                    done <= 1'b0;
                    d_err <= d_err;
                    err_sum_tmp <= err_sum;
                    kp_latch <= kp_latch;
                    ki_latch <= ki_latch;
                    kd_latch <= kd_latch;
                end
                SEND_OUT: begin
                    //Calculate output
                    state <= SEND_OUT_SAT;
                    err <= err;
                    err_tmp <= err_tmp;
                    input_d1 <= input_d1;
                    sig_out_norm <= sig_out_norm;
                    done <= 1'b0;
                    d_err <= d_err;
                    err_sum_tmp <= err_sum;
                    kp_latch <= kp_latch;
                    ki_latch <= ki_latch;
                    kd_latch <= kd_latch;
                end
                SEND_OUT_SAT: begin
                    //handle saturation math for output
                    if ($signed(sig_out_temp[DATA_WIDTH+PID_PARAM_WIDTH+MAX_OVF_SUM:PID_PARAM_FP_PRECISION]) < 
                        $signed({{(MAX_OVF_SUM+PID_PARAM_WIDTH-PID_PARAM_FP_PRECISION){1'b1}}, {(DATA_WIDTH-1){1'b0}}})) begin
                        sig_out_norm <= $signed({1'b1, {(DATA_WIDTH-1){1'b0}}});
                    end else if ($signed(sig_out_temp[DATA_WIDTH+PID_PARAM_WIDTH+MAX_OVF_SUM:PID_PARAM_FP_PRECISION]) > 
                        $signed({{(MAX_OVF_SUM+PID_PARAM_WIDTH-PID_PARAM_FP_PRECISION){1'b0}}, {(DATA_WIDTH-1){1'b1}}})) begin
                        sig_out_norm <= $signed({1'b0, {(DATA_WIDTH-1){1'b1}}});
                    end else begin
                        sig_out_norm <= sig_out_temp[DATA_WIDTH+PID_PARAM_FP_PRECISION-1:PID_PARAM_FP_PRECISION];
                    end
                    err <= err;
                    err_tmp <= err_tmp;
                    input_d1 <= feedback;
                    done <= 1'b1;
                    state <= WAIT_STATE;
                    d_err <= d_err;
                    err_sum_tmp <= err_sum;
                    kp_latch <= kp_latch;
                    ki_latch <= ki_latch;
                    kd_latch <= kd_latch;
                end
                default: begin
                    state <= WAIT_STATE;
                    err <= err;
                    err_tmp <= err_tmp;
                    input_d1 <= input_d1;
                    sig_out_norm <= sig_out_norm;
                    done <= 1'b0;
                    d_err <= d_err;
                    err_sum_tmp <= err_sum;
                    kp_latch <= kp_latch;
                    ki_latch <= ki_latch;
                    kd_latch <= kd_latch;
                end
            endcase
        end
    end



endmodule