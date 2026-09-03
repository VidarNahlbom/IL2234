//   Model using HDL a unsigned N-bit multiplier. The design must be parametric with 2 inputs of 
// N-bit, where N>3. Your design should use half adders and/or full adders (given below).
module multiplier #(parameter N) (
    input logic [N-1:0]a,b,
    output logic [2*N-1:0] product
);
    genvar r, c;
    generate
        for (r = 0; r < N; r++) begin : gen_pp_rows
            for (c = 0; c < N; c++) begin : gen_pp_cols
                assign pp[r][c] = a[c] & b[r];
            end
        end
    endgenerate
endmodule

module full_adder (
    input logic a,b,c_in,
    output logic c_out, s
);
    logic s1,c1,c2;
    half_adder ha1(a,b,s1,c1);
    half_adder ha2(s1,c_in,c2,s);
    assign c_out = c1|c2;
endmodule

module half_adder (
    input logic a,b,
    output logic c_out, s
);
    assign s = a^b;
    assign c_out = a&b;
endmodule