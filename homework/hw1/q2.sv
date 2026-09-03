module CSA_8 (
    input logic [7:0] A, B,
    input logic cin,
    output logic [7:0] sum,
    output logic carry
);
    logic ci_low, ci_high0, ci_high1; //cout of low adder
    logic [3:0] sum_high0, sum_high1;
    adder_4 adder_low (A[3:0],B[3:0],cin,sum[3:0],ci_low);
    adder_4 adder_high0 (A[7:4],B[7:4],1'b0,sum_high0,ci_high0);
    adder_4 adder_high1 (A[7:4],B[7:4],1'b1,sum_high1,ci_high1);
    assign sum[7:4] = ci_low ? sum_high1 : sum_high0;
    assign carry = ci_low ? ci_high1 : ci_high0;

endmodule


module adder_4 (
    input logic [3:0] A, B,
    input logic cin,
    output logic [3:0] sum,
    output logic carry
);
    assign {carry, sum} = A + B + cin;
endmodule