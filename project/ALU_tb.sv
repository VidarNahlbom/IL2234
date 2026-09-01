`timescale 1ns/1ps
module ALU_tb;

parameter int BW = 4;

logic [BW-1:0] a;
logic [BW-1:0] b;

logic [3:0] opcode;
logic [BW-1:0] out;
logic [2:0] flags;

ALU #(.BW(BW)) DUT (
    .a(a),
    .b(b),
    .opcode(opcode),
    .out(out),
    .flags(flags)
);

// Making a manual TB would be dumb, sadly we have yet to be taught anything else.
// We will try to create a reference function for the ALU
// How do we make sure the reference is correct?
// Right now it is simply copied, so they should be the exact same
// And this TB therefore has no value???
// I do not know ;(
// Then give the DUT and the reference the same inputs for evaluation
function automatic void compute_expected(
        input logic [BW-1:0] a,
        input logic [BW-1:0] b,
        input logic [3:0]    op,
        output logic [BW-1:0] exp_out,
        output logic         exp_v,
        output logic         exp_n,
        output logic         exp_z
    );
    // Copied code from ALU actual, changed names
    case (op)
        4'b0000: exp_out = a + b; // Addition
        4'b0001: exp_out = a - b; // Subtraction
        4'b0010: exp_out = a << b[$clog2(BW)-1:0]; // Logical left shift
        4'b0100: exp_out = ($signed(a) < $signed(b)) ? 1:0; // Set less than (signed)
        4'b0110: exp_out = (a < b) ? 1:0; // Set less than (unsigned)
        4'b1000: exp_out = a ^ b; // Logic XOR
        4'b1010: exp_out = a >> b[$clog2(BW)-1:0]; // Logical right shift
        4'b1011: exp_out = $signed(a) >>> b[$clog2(BW)-1:0]; // Arithmetic right shift, signed is included to make sure operation does sign extension, so that it replicates the leftmost bit
        4'b1100: exp_out = a | b; // Logic OR
        4'b1110: exp_out = a & b; // Logic AND
        4'b1111: exp_out = b; // Passthrough B
        default: exp_out = '0; // Unnecessary?
    endcase

    // Flag order is {overflow, negative, zero}
    // OVERFLOW Flag check
    if (op == 4'b0000) begin // If operation is addition
        if ((a[BW-1] & b[BW-1] & ~exp_out[BW-1] | // If MSB of A and B is high but output is not
            ~a[BW-1] & ~b[BW-1] & exp_out[BW-1])) // Or if MSB of A and B is low but output is not
            exp_v = 1'b1; // Overflow flag set to high
    end 
    else if (op == 4'b0001) begin // If operation is subtraction
        if ((~a[BW-1] & b[BW-1] & exp_out[BW-1] | // If A is pos, B is neg, then (-B) is positive and answer should be positive, since twos compliment is used that means MSB should be 0
            a[BW-1] & ~b[BW-1] & ~exp_out[BW-1])) // A neg (1), B pos (0) -> out pos (0) means overflow
            exp_v = 1'b1; // Overflow flag set to high
    end 

    // NEGATIVE Flag check
    exp_n = exp_out[BW-1];
    
    // ZERO Flag check
    exp_z = ~|out; // Uses bitwise NOR
    // flags[0] = (out == '0) // Achieves the same purpose
endfunction


// TB inputs and checks
initial begin

    // First edge case targeting should be done
    // Then randomized checking

    // We test 10 operands on each opcode

    opcode = 4'b0000; // Addition
    #10ns

    opcode = 4'b0001; // Subtraction
    #10ns
    
    opcode = 4'b0010; // Logical left shift
    #10ns
    
    opcode = 4'b0100; // Set less than (signed)
    #10ns
    
    opcode = 4'b0110; // Set less than (unsigned)
    #10ns
    
    opcode = 4'b1000; // Logic XOR
    #10ns
    
    opcode = 4'b1010; // Logical right shift
    #10ns
    
    opcode = 4'b1011; // Arithmetic right shift, signed is included to make sure operation does sign extension, so that it replicates the leftmost bit
    #10ns
    
    opcode = 4'b1100; // Logic OR
    #10ns
    
    opcode = 4'b1110; // Logic AND
    #10ns
    
    opcode = 4'b1111; // Passthrough B

end

