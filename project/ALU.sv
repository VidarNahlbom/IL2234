module ALU #(parameter BW) (
    input logic [BW-1:0] in_a,
    input logic [BW-1:0] in_b,
    input logic [3:0] opcode,
    output logic [BW-1:0] out,
    output logic [2:0] flags // {overflow, negative, zero}
);

    // TESTING GIT

    // Could add assigns here for 
    // assign N = BW-1;
    // assign msb_a = in_a[N];
    // assign msb_b = in_b[N];
    // assign msb_out = out[N];
    // assign shamt = in_b[$clog2(BW)-1:0];

    always_comb begin : operation
        // Output Rule:
        out = '0;
        flags = 3'b0;
        case (opcode)
            4'b0000: out = in_a + in_b; // Addition
            4'b0001: out = in_a - in_b; // Subtraction
            4'b0010: out = in_a << in_b[$clog2(BW)-1:0]; // Logical left shift
            4'b0100: out = ($signed(in_a) < $signed(in_b)) ? 1:0; // Set less than (signed)
            4'b0110: out = (in_a < in_b) ? 1:0; // Set less than (unsigned)
            4'b1000: out = in_a ^ in_b; // Logic XOR
            4'b1010: out = in_a >> in_b[$clog2(BW)-1:0]; // Logical right shift
            4'b1011: out = $signed(in_a) >>> in_b[$clog2(BW)-1:0]; // Arithmetic right shift, signed is included to make sure operation does sign extension, so that it replicates the leftmost bit
            4'b1100: out = in_a | in_b; // Logic OR
            4'b1110: out = in_a & in_b; // Logic AND
            4'b1111: out = in_b; // Passthrough B
            default: out = '0; // Unnecessary?
        endcase

        // Flag order is {overflow, negative, zero}
        // OVERFLOW Flag check
        if (opcode == 4'b0000) begin // If operation is addition
            if ((in_a[BW-1] & in_b[BW-1] & ~out[BW-1] | // If MSB of A and B is high but output is not
                ~in_a[BW-1] & ~in_b[BW-1] & out[BW-1])) // Or if MSB of A and B is low but output is not
                flags[2] = 1'b1; // Overflow flag set to high
        end 
        else if (opcode == 4'b0001) begin // If operation is subtraction
            if ((~in_a[BW-1] & in_b[BW-1] & out[BW-1] | // If A is pos, B is neg, then (-B) is positive and answer should be positive, since twos compliment is used that means MSB should be 0
                in_a[BW-1] & ~in_b[BW-1] & ~out[BW-1])) // A neg (1), B pos (0) -> out pos (0) means overflow
                flags[2] = 1'b1; // Overflow flag set to high
        end 

        // NEGATIVE Flag check
        flags[1] = out[BW-1];
       
        // ZERO Flag check
        flags[0] = ~|out; // Uses bitwise NOR
        // flags[0] = (out == '0) // Achieves the same purpose
    end
endmodule