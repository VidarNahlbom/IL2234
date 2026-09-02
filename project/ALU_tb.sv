`timescale 1ns/1ps // 1ns for timing and 1ps for simulation resolution
module ALU_tb;

parameter int BW = 4;

// Defining plag positions here for ease of reading
int FLAG_OVERFLOW = 2;
int FLAG_NEGATIVE = 1;
int FLAG_ZERO = 0;


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
    
    $display("INFO: Starting the test of ADDITION. ");
    opcode = 4'b0000; // Addition
    for (int i = 0; i < 10; i = i +1) begin

        // Generating random values, Will be atomatically trucnated to BW .
        a = $urandom;
        b = $urandom;

        // --- General idea for preforming the test ---
        // 1. Preform addition
        // 2. Validate the raised flags
        // 3. validate output result

        // 1. Preforming addition. Waiting for 10ns for the ALU to prefom addition, lower delay if applicable
        #10ns

        // 2. Validating flags

        // Validating overflow flag

        // If overflow is raised ensure it is correct
        if (flags[FLAG_OVERFLOW] === 1'b1) begin

            // If the flag is raised yet no over flow is expected then throw a error
            
            // If both a and b is negative then their sum shall also be negative. I.E if MSB(a) == 1 & MSB(b) == 1 then MSB(out) == 1 
            // Similarly of the MSB of both a and b is 0 then the MSB of out should be 0 since positive + positive = positive
            // If this is not the case a overflow has occured
            // if all 1  or all 0 everything is good, so flag is erronius
            if (a[BW-1] & b[BW-1] & out[BW-1] | ~a[BW-1] & ~b[BW-1] & ~out[BW-1]) begin 

                $error("ERROR: Overflow flag gave a false positive when preforming %b + %b = %b with flags %b", a, b, out, flags);

            end
        
        // If overflow is not raised ensure that this is correct
        end else begin 
        
            // If MSB of a and b are 1 but out is 0 then overflow occured. Or if MSB of a and b is 0 but out is 1 then a oveflow occured
            if (a[BW-1] & b[BW-1] & ~out[BW-1] | ~a[BW-1] & ~b[BW-1] & out[BW-1]) begin

                $error("ERROR: Overflow flag gave false negative when preforming %b + %b = %b with flags %b", a, b ,out, flags);

            end

        end


        // Validatng negative flag.

        // Simple if MSB out and flag match then all good
        if (out[BW-1] !== flags[FLAG_NEGATIVE] ) begin

            $error("ERROR: Erroiusly raised negative flag, %b,  for output: %b", flags, out);

        end

        // Validating zero flag

        //If the zero flag is raised check for false negative
        if (flags[FLAG_ZERO] === 1'b1) begin
            

            if(out !== '0) begin
                
                $error("ERROR: False positive zero flag: %b , for output: %b", flags, out);

            end

        // If negative check for false negative
        end else begin
            
            if(out !== '0) begin

                $error("ERROR: False negative zero flag: %b , for output: %b", flags, out);

            end

        end
    end

    $display("INFO: Addition veriifed sucesfully");
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
