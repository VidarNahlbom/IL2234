//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.09.2026 15:11:18
// Design Name: 
// Module Name: ALU_Exhaustive_TestBench
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

module ALU_Exhaustive_TestBench;

    parameter BW = 4;

    logic [BW-1:0] in_a;
    logic [BW-1:0] in_b;
    logic [3:0]    opcode;

    logic [BW-1:0] out;
    logic [2:0]    flags;

    logic [BW-1:0] expected_out;
    logic [2:0]    expected_flags;

    integer total_tests;
    integer passed_tests;
    integer failed_tests;

    // Instantiate the ALU
    ALU #(.BW(BW)) DUT (
        .in_a(in_a),
        .in_b(in_b),
        .opcode(opcode),
        .out(out),
        .flags(flags)
    );

    // Check one ALU operation
    task automatic check_operation(
        input logic [BW-1:0] a,
        input logic [BW-1:0] b,
        input logic [3:0]    op
    );

        logic overflow_expected;

        begin
            // Apply inputs
            in_a   = a;
            in_b   = b;
            opcode = op;

            // Wait for combinational ALU to respond
            #1;

            // Default expected values
            expected_out      = '0;
            overflow_expected = 1'b0;

            // Calculate expected result
            case (op)

                // ADD
                4'b0000: begin
                    expected_out = a + b;

                    overflow_expected =
                        (~a[BW-1] & ~b[BW-1] &  expected_out[BW-1]) |
                        ( a[BW-1] &  b[BW-1] & ~expected_out[BW-1]);
                end

                // SUB
                4'b0001: begin
                    expected_out = a - b;

                    overflow_expected =
                        (~a[BW-1] &  b[BW-1] &  expected_out[BW-1]) |
                        ( a[BW-1] & ~b[BW-1] & ~expected_out[BW-1]);
                end

                // SLL
                4'b0010:
                    expected_out = a << b[$clog2(BW)-1:0];

                // SLT signed
                4'b0100:
                    expected_out = ($signed(a) < $signed(b)) ? 1 : 0;

                // SLTU unsigned
                4'b0110:
                    expected_out = (a < b) ? 1 : 0;

                // XOR
                4'b1000:
                    expected_out = a ^ b;

                // SRL
                4'b1010:
                    expected_out = a >> b[$clog2(BW)-1:0];

                // SRA
                4'b1011:
                    expected_out = $signed(a) >>> b[$clog2(BW)-1:0];

                // OR
                4'b1100:
                    expected_out = a | b;

                // AND
                4'b1110:
                    expected_out = a & b;

                // PASS_B
                4'b1111:
                    expected_out = b;

                // Unused opcodes
                default:
                    expected_out = '0;

            endcase

            // Calculate expected flags
            expected_flags[2] = overflow_expected;
            expected_flags[1] = expected_out[BW-1];
            expected_flags[0] = (expected_out == '0);

            // Update counters
            total_tests = total_tests + 1;

            // Compare DUT with expected values
            if ((out !== expected_out) ||
                (flags !== expected_flags)) begin

                failed_tests = failed_tests + 1;

                $display("----------------------------------------");
                $display("FAIL");
                $display("Opcode          = %04b", op);
                $display("A               = %04b", a);
                $display("B               = %04b", b);
                $display("Expected output = %04b", expected_out);
                $display("Actual output   = %04b", out);
                $display("Expected flags  = %03b", expected_flags);
                $display("Actual flags    = %03b", flags);
                $display("----------------------------------------");

            end
            else begin
                passed_tests = passed_tests + 1;
            end
        end

    endtask


    // Exhaustive testing
    initial begin

        total_tests  = 0;
        passed_tests = 0;
        failed_tests = 0;

        $display("");
        $display("==============================================");
        $display("       ALU EXHAUSTIVE TESTBENCH STARTED");
        $display("==============================================");
        $display("ALU Width = %0d bits", BW);
        $display("Testing all opcodes and all operand combinations");
        $display("");

        // Test every opcode
        for (int op = 0; op < 16; op = op + 1) begin

            // Test every possible value of A
            for (int a = 0; a < 16; a = a + 1) begin

                // Test every possible value of B
                for (int b = 0; b < 16; b = b + 1) begin

                    check_operation(
                        a[BW-1:0],
                        b[BW-1:0],
                        op[3:0]
                    );

                end
            end
        end


        // Final results
        $display("");
        $display("==============================================");
        $display("           ALU EXHAUSTIVE TEST RESULTS");
        $display("==============================================");
        $display("Total tests  : %0d", total_tests);
        $display("Passed       : %0d", passed_tests);
        $display("Failed       : %0d", failed_tests);
        $display("==============================================");

        if (failed_tests == 0)
            $display("           ALL TESTS PASSED");
        else
            $display("           TESTS FAILED");

        $display("==============================================");
        $display("");

        $finish;

    end

endmodule
