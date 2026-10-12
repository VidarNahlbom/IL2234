
`timescale 1ns/1ps

module controller_tb;

    // Inputs to the controller
    logic clk;
    logic rst_n;
    logic mem_ready;
    logic [6:0] opcode;
    logic [2:0] func3;
    logic [6:0] func7;
    logic alu_zero;

    // Outputs from the controller
    logic rf_chip_en;
    logic rf_write_en_n;
    logic mem_addr_src;
    logic mem_write_unit_en;
    logic mem_read_en;
    logic ir_write_en;
    logic pc_write_en;
    logic [1:0] rf_write_src;
    logic alu_b_src;
    logic [3:0] alu_opcode;
    logic [1:0] pc_src;

    // Instantiate the controller
    controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .mem_ready(mem_ready),
        .opcode(opcode),
        .func3(func3),
        .func7(func7),
        .alu_zero(alu_zero),
        .rf_chip_en(rf_chip_en),
        .rf_write_en_n(rf_write_en_n),
        .mem_addr_src(mem_addr_src),
        .mem_write_unit_en(mem_write_unit_en),
        .mem_read_en(mem_read_en),
        .ir_write_en(ir_write_en),
        .pc_write_en(pc_write_en),
        .rf_write_src(rf_write_src),
        .alu_b_src(alu_b_src),
        .alu_opcode(alu_opcode),
        .pc_src(pc_src)
    );

    // Generate clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;
    
    
task test_alu_instruction(
    input [2:0] test_func3,
    input [6:0] test_func7,
    input [3:0] expected_alu,
    input [80*8-1:0] instruction_name
);
begin
    // Move from Execute1 back to Fetch
    @(negedge clk);
    @(posedge clk);
    #1;

    // Give the controller the next instruction
    @(negedge clk);
    opcode = 7'b0110011;  // R-type instruction
    func3 = test_func3;
    func7 = test_func7;
    mem_ready = 1;

    // Move from Fetch to Execute1
    @(posedge clk);
    #1;

    // Check the ALU operation
    if (alu_opcode === expected_alu) begin
        $display("PASS: %0s", instruction_name);
    end
    else begin
        $display("FAIL: %0s", instruction_name);
        $display("Expected ALU = %b, Actual ALU = %b",
                 expected_alu, alu_opcode);
    end
end
endtask


    initial begin

        $display("================================");
        $display(" TEST 1: RESET AND INSTRUCTION FETCH");
        $display("================================");

        // Initialise inputs
        rst_n     = 1'b1;
        mem_ready = 1'b0;
        opcode    = 7'b0;
        func3     = 3'b0;
        func7     = 7'b0;
        alu_zero  = 1'b0;

        // ------------------------------------
        // TEST 1: Reset the controller
        // ------------------------------------

        #2;
        rst_n = 1'b0;
        #2;

        if (dut.current_state === dut.Fetch)
            $display("PASS: Controller reset to Fetch");
        else
            $error("FAIL: Controller did not reset to Fetch");

        // Release reset on the falling clock edge
        @(negedge clk);
        rst_n = 1'b1;
        #1;

        // ------------------------------------
        // TEST 2: Fetch while memory is not ready
        // ------------------------------------

        mem_ready = 1'b0;
        #1;

        if (mem_read_en === 1'b1)
            $display("PASS: Fetch requests memory read");
        else
            $error("FAIL: Fetch should request memory read");

        if (mem_addr_src === 1'b0)
            $display("PASS: Fetch selects PC as memory address");
        else
            $error("FAIL: Fetch should select PC as memory address");

        if (ir_write_en === 1'b0)
            $display("PASS: Instruction register waits for memory");
        else
            $error("FAIL: IR write should be disabled while waiting");

        // Check that the controller remains in Fetch
        repeat (2) @(posedge clk);
        #1;

        if (dut.current_state === dut.Fetch)
            $display("PASS: Controller remains in Fetch while waiting");
        else
            $error("FAIL: Controller left Fetch before memory was ready");

        // ------------------------------------
        // TEST 3: Memory becomes ready
        // ------------------------------------

        @(negedge clk);
        mem_ready = 1'b1;
        #1;

        if (ir_write_en === 1'b1)
            $display("PASS: Instruction register enabled when ready");
        else
            $error("FAIL: IR write should be enabled when ready");

        // Next rising edge should move the FSM to Execute1
        @(posedge clk);
        #1;

        if (dut.current_state === dut.Execute1)
            $display("PASS: Controller transitions to Execute1");
        else
            $error("FAIL: Controller did not transition to Execute1");

        // ------------------------------------
        // END OF TASK 1
        // ------------------------------------

        $display("================================");
        $display(" TEST 1 COMPLETED");
        $display("================================");
        
        
        // Test 2: Arithmetic and logical instructions
        $display("================================");
        $display(" TEST 2: ARITHMETIC AND LOGICAL INSTRUCTIONS");
        $display("================================");
        test_alu_instruction(3'b000, 7'b0000000, 4'b0000, "ADD");
        test_alu_instruction(3'b000, 7'b0100000, 4'b0001, "SUB");
        test_alu_instruction(3'b001, 7'b0000000, 4'b0010, "SLL");
        test_alu_instruction(3'b010, 7'b0000000, 4'b0100, "SLT");
        test_alu_instruction(3'b011, 7'b0000000, 4'b0110, "SLTU");
        test_alu_instruction(3'b100, 7'b0000000, 4'b1000, "XOR");
        test_alu_instruction(3'b101, 7'b0000000, 4'b1010, "SRL");
        test_alu_instruction(3'b101, 7'b0100000, 4'b1011, "SRA");
        test_alu_instruction(3'b110, 7'b0000000, 4'b1100, "OR");
        test_alu_instruction(3'b111, 7'b0000000, 4'b1110, "AND");
        $display("================================");
        $display(" TEST 2 COMPLETED");
        $display("================================");


        $finish;
    end

endmodule
