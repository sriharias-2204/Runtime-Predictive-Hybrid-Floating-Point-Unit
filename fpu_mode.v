`timescale 1ns/1ps

// SRI HARI A S

module fpu_mode (
    input clk,
    input rst_n,
    input valid_in,
    input [1:0] opcode,  // 00 add, 01 sub, 10 mul
    input [31:0] A,
    input [31:0] B,

    output reg valid_out,
    output reg [31:0] result,
    output reg overflow,
    output reg underflow,
    output reg inexact,
    output reg zero,
    output reg used_approx,
    output reg used_bf16
);

    reg [31:0] A_r, B_r;
    reg [1:0] opcode_r;
    reg valid_pipe;

    wire [7:0] eA = A[30:23];
    wire [7:0] eB = B[30:23];
    wire [8:0] exp_diff = (eA > eB) ? (eA - eB) : (eB - eA);
    wire [8:0] exp_sum  = eA + eB;

    wire [7:0] mantA = A[22:15];
    wire [7:0] mantB = B[22:15];
    wire [7:0] mant_diff = (mantA > mantB) ? (mantA - mantB) : (mantB - mantA);

    wire bf16_safe = (A[22:10] == 0 && B[22:10] == 0) || (eA < 20 && eB < 20) || (eA > 230 || eB > 230);

    // cancellation risk
    wire cancel_risk = (exp_diff <= 2) && (mant_diff < 8);

    wire approx_safe = !bf16_safe && !cancel_risk && ((opcode != 2'b10 && exp_diff > 10) || (opcode == 2'b10 && exp_sum > 10 && exp_sum < 230));

    localparam MODE_FP32 = 2'b00, MODE_APPROX = 2'b01, MODE_BF16 = 2'b10;
    reg [1:0] exec_mode;

    wire [31:0] A_fp32 = (exec_mode==MODE_FP32) ? A_r : 32'b0;
    wire [31:0] B_fp32 = (exec_mode==MODE_FP32) ? B_r : 32'b0;
    wire [31:0] A_apx = (exec_mode==MODE_APPROX) ? A_r : 32'b0;
    wire [31:0] B_apx = (exec_mode==MODE_APPROX) ? B_r : 32'b0;
    wire [15:0] A_bf16 = (exec_mode==MODE_BF16) ? {A_r[31],A_r[30:23],A_r[22:16]} : 16'b0;
    wire [15:0] B_bf16 = (exec_mode==MODE_BF16) ? {B_r[31],B_r[30:23],B_r[22:16]} : 16'b0;

    wire [31:0] exact_add, exact_mul;
    wire exact_ovf, exact_unf, exact_inx, exact_zero;

    exact_addsub u_add(A_fp32,B_fp32,opcode_r[0],exact_add,exact_zero,exact_inx,exact_ovf,exact_unf);
    exact_mul u_mul(A_fp32,B_fp32,exact_mul,exact_zero,exact_inx,exact_ovf,exact_unf);

    wire [31:0] approx_add, approx_mul;
    wire approx_ovf, approx_unf, approx_inx, approx_zero;
    approx_addsub_fp32 u_approx_add(A_apx,B_apx,opcode_r[0],approx_add,approx_zero,approx_inx,approx_ovf,approx_unf);
    approx_mul_fp32 u_approx_mul(A_apx,B_apx,approx_mul,approx_zero,approx_inx,approx_ovf,approx_unf);

    wire [15:0] bf16_add, bf16_mul;
    wire bf16_zero, bf16_inx, bf16_ovf, bf16_unf;
    bf16_add u_bfadd(A_bf16,B_bf16,bf16_add,bf16_zero,bf16_inx,bf16_ovf,bf16_unf);
    bf16_mul u_bfmul(A_bf16,B_bf16,bf16_mul,bf16_zero,bf16_inx,bf16_ovf,bf16_unf);

    wire [31:0] bf16_fp32 = (opcode_r==2'b10) ? {bf16_mul[15],bf16_mul[14:7],bf16_mul[6:0],16'b0} : {bf16_add[15],bf16_add[14:7],bf16_add[6:0],16'b0};

    reg state;
    localparam IDLE=0, EXEC=1;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=IDLE;
            valid_out<=0;
            valid_pipe<=0;
            exec_mode<=MODE_FP32;
        end else begin
            case(state)
                IDLE: begin
                    valid_out<=0;
                    if(valid_in) begin
                        A_r<=A; B_r<=B; opcode_r<=opcode;
                        valid_pipe<=1;
                        if(bf16_safe) exec_mode<=MODE_BF16;
                        else if(approx_safe) exec_mode<=MODE_APPROX;
                        else exec_mode<=MODE_FP32;
                        state<=EXEC;
                    end
                end

                EXEC: begin
                    valid_out<=valid_pipe;
                    valid_pipe<=0;
                    case(exec_mode)
                        MODE_BF16: begin
                            result<=bf16_fp32;
                            {zero,inexact,overflow,underflow} <= {bf16_zero,bf16_inx,bf16_ovf,bf16_unf};
                            used_bf16<=1; used_approx<=0;
                        end
                        MODE_APPROX: begin
                            result<= (opcode_r==2'b10)? approx_mul : approx_add;
                            {zero,inexact,overflow,underflow} <= {approx_zero,approx_inx,approx_ovf,approx_unf};
                            used_bf16<=0; used_approx<=1;
                        end
                        default: begin
                            result<= (opcode_r==2'b10)? exact_mul : exact_add;
                            {zero,inexact,overflow,underflow} <= {exact_zero,exact_inx,exact_ovf,exact_unf};
                            used_bf16<=0; used_approx<=0;
                        end
                    endcase
                    state<=IDLE;
                end
            endcase
        end
    end

endmodule

