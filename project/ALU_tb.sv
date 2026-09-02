`timescale 1ns/1ns
module ALU_tb;

parameter int BW = 4;

// DUT signals
logic [BW-1:0] a;
logic [BW-1:0] b;
logic [3:0] opcode;
logic [BW-1:0] out;
logic [2:0] flags;

// file management
int file_handle;

// Expected result signals
logic [BW-1:0] exp_out;
logic [2:0] exp_flags;

// test variables
int test_count;
int error_count;
logic [3:0] unsigned_op_list[2];
logic [3:0] signed_op_list[9];

ALU #(.BW(BW)) DUT (
    .in_a(a),
    .in_b(b),
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
        output logic [2:0]   exp_flags
    );
    exp_flags = 3'b000;
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
            exp_flags[2] = 1'b1; // Overflow flag set to high
    end 
    else if (op == 4'b0001) begin // If operation is subtraction
        if ((~a[BW-1] & b[BW-1] & exp_out[BW-1] | // If A is pos, B is neg, then (-B) is positive and answer should be positive, since twos compliment is used that means MSB should be 0
            a[BW-1] & ~b[BW-1] & ~exp_out[BW-1])) // A neg (1), B pos (0) -> out pos (0) means overflow
            exp_flags[2] = 1'b1; // Overflow flag set to high
    end 

    // NEGATIVE Flag check
    exp_flags[1] = exp_out[BW-1];
    
    // ZERO Flag check
    exp_flags[0] = ~|exp_out; // Uses bitwise NOR
    // flags[0] = (out == '0) // Achieves the same purpose
endfunction

function automatic string get_op_name(input logic [3:0] op);
        case (op)
            4'b0000: return "ADD";
            4'b0001: return "SUB";
            4'b0010: return "SLL";
            4'b0100: return "SLT";
            4'b0110: return "SLTU";
            4'b1000: return "XOR";
            4'b1010: return "SRL";
            4'b1011: return "SRA";
            4'b1100: return "OR";
            4'b1110: return "AND";
            4'b1111: return "PASS_B";
            default: return "UNKNOWN/INVALID";
        endcase
    endfunction

// Apparently difference between task and function is timing capabilities, since we want waits here we use a task
task automatic test_and_log(
    input logic [BW-1:0] a_val,
    input logic [BW-1:0] b_val,
    input logic [3:0] op_val,
    ref int test_num,
    ref int error_num
);
    string status;
    test_num++;

    // drive inputs
    a = a_val;
    b = b_val;
    opcode = op_val;

    #10ns; // waiting for combinational propogation

    // compute expected outputs
    compute_expected(a, b, opcode, exp_out, exp_flags);

    // Check against DUT
    if ((out === exp_out) && (flags === exp_flags)) begin
        status = "PASS";
    end else begin
        status = "MISMATCH!";
        error_num++;
        $error("Mismatch [Test #%0d - %s]: A=%h B=%h | DUT Out=%h Flags=%b | EXP Out=%h Flags=%b",
                test_num, get_op_name(opcode), a, b, out, flags, exp_out, exp_flags);
    end

    // Write log
    $fdisplay(file_handle, "%-5d | %-8s | %h | %h | %h | %b   | %h | %b   | %s",
                test_num, get_op_name(opcode), a, b, out, flags, exp_out, exp_flags, status);
endtask

// TB inputs and checks
initial begin

    // First edge case targeting should be done
    // Then randomized checking

    // We test 10 operands on each opcode

    test_count = 0;
    error_count = 0; 
    signed_op_list = '{4'b0000, 4'b0001, 4'b0010, 4'b0100, 
                                4'b1000, 4'b1011, 4'b1100, 4'b1110, 4'b1111};
    unsigned_op_list = '{4'b0110,  4'b1010};


    // Opening file for write
    file_handle = $fopen("alu_tb_results.txt", "w");
    if (file_handle == 0) begin
        $display("Error: could not open alu_tb_results.txt!");
        $finish;
    end

    // Writing header to file
    $fdisplay(file_handle, "=================================================================================================");
    $fdisplay(file_handle, "                                  ALU VERIFICATION LOG FILE                                      ");
    $fdisplay(file_handle, "=================================================================================================");
    $fdisplay(file_handle, "Test# | Operation| IN_A     | IN_B     | OUT      | Flags(VNZ)| EXP_OUT  | EXP_FLAGS| Status");
    $fdisplay(file_handle, "-------------------------------------------------------------------------------------------------");

    // Now we loop through the opcodes and do 10 operations each
    $display("Running 10 tests per opcode");
    
    // the operations using signed numbers first
    foreach (signed_op_list[i]) begin
        for (int j = 0; j < 10; j++) begin
            test_and_log($random, $random, signed_op_list[i], test_count, error_count);
        end
    end

    // then the unsigned operations
    foreach (unsigned_op_list[i]) begin
        for (int j = 0; j < 10; j++) begin
            test_and_log($urandom, $urandom, unsigned_op_list[i], test_count, error_count);
        end
    end

    $fdisplay(file_handle, "-------------------------------------------------------------------------------------------------");
    $fdisplay(file_handle, "TOTAL TESTS: %0d | TOTAL ERRORS: %0d", test_count, error_count);
    $display("Done. Executed %0d tests with %0d errors. Log saved to 'alu_tb_results.txt'.", test_count, error_count);

    $fclose(file_handle);
    $finish;
end

endmodule

