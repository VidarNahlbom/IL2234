`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.09.2026 17:14:25
// Design Name: 
// Module Name: ALU_TestBench_source
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns/1ps

module ALU_TestBench_source;

    // --------------------------------------------------
    // Parameter
    // --------------------------------------------------
    parameter BW = 4;

    // --------------------------------------------------
    // Testbench signals
    // --------------------------------------------------
    logic [BW-1:0] in_a;
    logic [BW-1:0] in_b;
    logic [3:0]    opcode;

    logic [BW-1:0] out;
    logic [2:0]    flags;

    // Expected values
    logic [BW-1:0] expected_out;
    logic [2:0]    expected_flags;

    // --------------------------------------------------
    // Instantiate DUT
    // --------------------------------------------------
    ALU #(.BW(BW)) DUT (
        .in_a(in_a),
        .in_b(in_b),
        .opcode(opcode),
        .out(out),
        .flags(flags)
    );

    // --------------------------------------------------
    // Task to check one test case
    // --------------------------------------------------
    task automatic check_operation(
        input logic [BW-1:0] a,
        input logic [BW-1:0] b,
        input logic [3:0] op
    );

        logic overflow_expected;

        begin

            // Apply inputs
            in_a   = a;
            in_b   = b;
            opcode = op;

            // Wait for combinational logic to settle
            #1;

            // Default values
            expected_out      = '0;
            overflow_expected = 1'b0;

            // Calculate expected output
            case (op)

                4'b0000: begin
                    // ADD
                    expected_out = a + b;

                    overflow_expected =
                        (~a[BW-1] & ~b[BW-1] & expected_out[BW-1]) |
                        ( a[BW-1] &  b[BW-1] & ~expected_out[BW-1]);
                end

                4'b0001: begin
                    // SUB
                    expected_out = a - b;

                    overflow_expected =
                        (~a[BW-1] &  b[BW-1] &  expected_out[BW-1]) |
                        ( a[BW-1] & ~b[BW-1] & ~expected_out[BW-1]);
                end

                4'b0010: begin
                    // SLL
                    expected_out = a << b[$clog2(BW)-1:0];
                end

                4'b0100: begin
                    // SLT - signed
                    expected_out = ($signed(a) < $signed(b)) ? 1 : 0;
                end

                4'b0110: begin
                    // SLTU - unsigned
                    expected_out = (a < b) ? 1 : 0;
                end

                4'b1000: begin
                    // XOR
                    expected_out = a ^ b;
                end

                4'b1010: begin
                    // SRL - logical right shift
                    expected_out = a >> b[$clog2(BW)-1:0];
                end

                4'b1011: begin
                    // SRA - arithmetic right shift
                    expected_out = $signed(a) >>> b[$clog2(BW)-1:0];
                end

                4'b1100: begin
                    // OR
                    expected_out = a | b;
                end

                4'b1110: begin
                    // AND
                    expected_out = a & b;
                end

                4'b1111: begin
                    // PASS_B
                    expected_out = b;
                end

                default: begin
                    expected_out = '0;
                end

            endcase

            // --------------------------------------------------
            // Calculate expected flags
            // --------------------------------------------------

            expected_flags[2] = overflow_expected;
            expected_flags[1] = expected_out[BW-1];
            expected_flags[0] = (expected_out == '0);

            // --------------------------------------------------
            // Compare actual and expected values
            // --------------------------------------------------

            if ((out !== expected_out) ||
                (flags !== expected_flags)) begin

                $display("----------------------------------------");
                $display("FAIL");
                $display("Opcode  = %04b", op);
                $display("in_a    = %b (%0d)", a, a);
                $display("in_b    = %b (%0d)", b, b);
                $display("Expected out   = %b", expected_out);
                $display("Actual out     = %b", out);
                $display("Expected flags = %b", expected_flags);
                $display("Actual flags   = %b", flags);
                $display("----------------------------------------");

            end
            else begin

                $display("PASS: opcode=%04b, A=%0d, B=%0d, OUT=%b, FLAGS=%b",
                         op, a, b, out, flags);

            end

        end

    endtask


    // --------------------------------------------------
    // Test sequence
    // --------------------------------------------------
    initial begin

        $display("========================================");
        $display("Starting ALU Testbench");
        $display("BW = %0d", BW);
        $display("========================================");

        // --------------------------------------------------
        // ADD
        // --------------------------------------------------
        check_operation(4'b0000, 4'b0000, 4'b0000);
        check_operation(4'b0010, 4'b0011, 4'b0000);
        check_operation(4'b0111, 4'b0001, 4'b0000);
        check_operation(4'b1111, 4'b0001, 4'b0000);

        // --------------------------------------------------
        // SUB
        // --------------------------------------------------
        check_operation(4'b0101, 4'b0011, 4'b0001);
        check_operation(4'b0011, 4'b0101, 4'b0001);
        check_operation(4'b0000, 4'b0001, 4'b0001);
        check_operation(4'b1000, 4'b0001, 4'b0001);

        // --------------------------------------------------
        // SLL
        // --------------------------------------------------
        check_operation(4'b0001, 4'b0001, 4'b0010);
        check_operation(4'b0001, 4'b0010, 4'b0010);
        check_operation(4'b0001, 4'b0011, 4'b0010);

        // --------------------------------------------------
        // SLT - signed
        // --------------------------------------------------
        check_operation(4'b0101, 4'b0111, 4'b0100);
        check_operation(4'b0111, 4'b0101, 4'b0100);
        check_operation(4'b1111, 4'b0001, 4'b0100);
        check_operation(4'b0001, 4'b1111, 4'b0100);

        // --------------------------------------------------
        // SLTU - unsigned
        // --------------------------------------------------
        check_operation(4'b0101, 4'b0111, 4'b0110);
        check_operation(4'b0111, 4'b0101, 4'b0110);
        check_operation(4'b1111, 4'b0001, 4'b0110);

        // --------------------------------------------------
        // XOR
        // --------------------------------------------------
        check_operation(4'b1010, 4'b0101, 4'b1000);
        check_operation(4'b1111, 4'b1111, 4'b1000);
        check_operation(4'b0000, 4'b0000, 4'b1000);

        // --------------------------------------------------
        // SRL
        // --------------------------------------------------
        check_operation(4'b1000, 4'b0001, 4'b1010);
        check_operation(4'b1000, 4'b0010, 4'b1010);
        check_operation(4'b1111, 4'b0010, 4'b1010);

        // --------------------------------------------------
        // SRA
        // --------------------------------------------------
        check_operation(4'b1000, 4'b0001, 4'b1011);
        check_operation(4'b1000, 4'b0010, 4'b1011);
        check_operation(4'b1111, 4'b0010, 4'b1011);
        check_operation(4'b0111, 4'b0010, 4'b1011);

        // --------------------------------------------------
        // OR
        // --------------------------------------------------
        check_operation(4'b1010, 4'b0101, 4'b1100);
        check_operation(4'b0000, 4'b0101, 4'b1100);

        // --------------------------------------------------
        // AND
        // --------------------------------------------------
        check_operation(4'b1010, 4'b0101, 4'b1110);
        check_operation(4'b1111, 4'b0101, 4'b1110);

        // --------------------------------------------------
        // PASS_B
        // --------------------------------------------------
        check_operation(4'b1010, 4'b0101, 4'b1111);
        check_operation(4'b0000, 4'b1111, 4'b1111);

        // --------------------------------------------------
        // Invalid opcodes
        // --------------------------------------------------
        check_operation(4'b1010, 4'b0101, 4'b0011);
        check_operation(4'b1010, 4'b0101, 4'b0101);
        check_operation(4'b1010, 4'b0101, 4'b0111);
        check_operation(4'b1010, 4'b0101, 4'b1001);
        check_operation(4'b1010, 4'b0101, 4'b1101);

        $display("========================================");
        $display("ALU Testbench Finished");
        $display("========================================");

        $finish;

    end

endmodule
