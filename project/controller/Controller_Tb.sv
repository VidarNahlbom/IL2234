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
task test_u_instruction(
    input [6:0] test_opcode,
    input [3:0] expected_alu,
    input [1:0] expected_write_src,
    input [80*8-1:0] instruction_name
);
begin
    // Return to Fetch from the previous instruction
    @(negedge clk);
    @(posedge clk);
    #1;
    // Supply the new instruction
    @(negedge clk);
    opcode = test_opcode;
    func3 = 3'b000;
    func7 = 7'b0000000;
    mem_ready = 1;
    // Move to Execute1
    @(posedge clk);
    #1;
    // Check ALU operation
    if (alu_opcode === expected_alu)
        $display("PASS: %0s - ALU operation", instruction_name);
    else
        $display("FAIL: %0s - ALU expected %b, got %b",
                 instruction_name, expected_alu, alu_opcode);
    // Check immediate selection only for LUI
    //Unlike LUI, AUIPC doesn't set alu_b_src = 1'b1.
    //Since AUIPC uses a dedicated adder and the rf_write_src = 2'b11 mux selection to obtain PC + immediate
    if (test_opcode == 7'b0110111) begin
        if (alu_b_src === 1'b1)
            $display("PASS: %0s - immediate selected", instruction_name);
        else
            $display("FAIL: %0s - immediate not selected", instruction_name);
    end
    // Check register write-back source
    if (rf_write_src === expected_write_src)
        $display("PASS: %0s - write-back source", instruction_name);
    else
        $display("FAIL: %0s - expected write source %b, got %b",
                 instruction_name, expected_write_src, rf_write_src);
    // Check that register writing is enabled
    if (rf_write_en_n === 1'b0)
        $display("PASS: %0s - register write enabled", instruction_name);
    else
        $display("FAIL: %0s - register write not enabled", instruction_name);
end
endtask



task test_load_instruction(
    input [2:0] test_func3,
    input [80*8-1:0] instruction_name
);
begin
    // Make sure the previous instruction has completed
    wait (dut.current_state == dut.Fetch);
    @(negedge clk);

    // Set up the next load instruction
    opcode = 7'b0000011;
    func3 = test_func3;
    func7 = 7'b0000000;
    mem_ready = 1;

    // Fetch -> Execute1
    // Wait for the rising edge that changes the state
    @(posedge clk);
    #1;

//    // Debug: confirm the state before checking Execute1
//    $display("DEBUG %0s: state=%0d, alu=%b, rf_write_en_n=%b, pc_write_en=%b",
//             instruction_name, dut.current_state,
//             alu_opcode, rf_write_en_n, pc_write_en);

    // Check Execute1 control signals
    if (dut.current_state == dut.Execute1 && alu_opcode === 4'b0000)
        $display("PASS: %0s - ALU ADD", instruction_name);
    else
        $display("FAIL: %0s - ALU ADD or state incorrect", instruction_name);

    if (alu_b_src === 1'b1)
        $display("PASS: %0s - immediate selected", instruction_name);
    else
        $display("FAIL: %0s - immediate not selected", instruction_name);

    if (rf_write_src === 2'b01)
        $display("PASS: %0s - memory data selected", instruction_name);
    else
        $display("FAIL: %0s - write-back source incorrect", instruction_name);

    if (rf_write_en_n === 1'b1)
        $display("PASS: %0s - register write waits", instruction_name);
    else
        $display("FAIL: %0s - register write enabled too early", instruction_name);

    if (dut.current_state == dut.Execute1 && pc_write_en === 1'b0)
        $display("PASS: %0s - PC waits in Execute1", instruction_name);
    else
        $display("FAIL: %0s - PC should wait in Execute1", instruction_name);

    // Execute1 -> Execute2
    wait (dut.current_state == dut.Execute2);

    // Simulate memory not ready
    @(negedge clk);
    mem_ready = 0;
    #1;

    if (mem_read_en === 1'b1 &&
        mem_addr_src === 1'b1 &&
        rf_write_en_n === 1'b1 &&
        pc_write_en === 1'b0)
        $display("PASS: %0s - waits for memory", instruction_name);
    else
        $display("FAIL: %0s - incorrect memory-wait controls", instruction_name);

    // Simulate memory becoming ready
    
@(negedge clk);
mem_ready = 1;
#1;

if (mem_read_en === 1 && rf_write_en_n === 0 && pc_write_en === 1)
    $display("PASS: %0s - completes load", instruction_name);
else
    $display("FAIL: %0s - completes load", instruction_name);

// Allow the FSM to return to Fetch.
@(posedge clk);
#1;

// Stop Fetch from advancing before the next instruction is set.
@(negedge clk);
mem_ready = 0;

end
endtask

task test_store_instruction(
    input [2:0] test_func3,
    input [80*8-1:0] instruction_name
);
begin
    // Make sure the previous instruction has completed
    wait (dut.current_state == dut.Fetch);
    @(negedge clk);

    // Set up the next store instruction
    opcode = 7'b0100011;
    func3 = test_func3;
    func7 = 7'b0000000;
    mem_ready = 1;

    // Fetch -> Execute1
    @(posedge clk);
    #1;

//    $display("DEBUG %0s: state=%0d, alu=%b, rf_write_en_n=%b, pc_write_en=%b",
//             instruction_name, dut.current_state,
//             alu_opcode, rf_write_en_n, pc_write_en);

    // Check Execute1 control signals
    if (dut.current_state == dut.Execute1 && alu_opcode === 4'b0000)
        $display("PASS: %0s - ALU ADD", instruction_name);
    else
        $display("FAIL: %0s - ALU ADD or state incorrect", instruction_name);

    if (alu_b_src === 1'b1)
        $display("PASS: %0s - immediate selected", instruction_name);
    else
        $display("FAIL: %0s - immediate not selected", instruction_name);

    if (rf_write_en_n === 1'b1)
        $display("PASS: %0s - register write disabled", instruction_name);
    else
        $display("FAIL: %0s - unexpected register write", instruction_name);

    if (dut.current_state == dut.Execute1 && pc_write_en === 1'b0)
        $display("PASS: %0s - PC waits in Execute1", instruction_name);
    else
        $display("FAIL: %0s - PC should wait in Execute1", instruction_name);

    // Execute1 -> Execute2
    wait (dut.current_state == dut.Execute2);

    // Simulate memory not ready
    
    @(negedge clk);
    mem_ready = 1;
    #1;

    if (mem_write_unit_en === 1 && mem_read_en === 0 && pc_write_en === 1 && rf_write_en_n === 1)
        $display("PASS: %0s - store completes without register write", instruction_name);
    else
        $display("FAIL: %0s - store completes without register write", instruction_name);

    // Allow the FSM to return to Fetch.
    @(posedge clk);
    #1;

    // Prevent Fetch from advancing before the next instruction is set.
    @(negedge clk);
    mem_ready = 0;

end
endtask

task test_branch_instruction(
    input [2:0] test_func3,
    input [6:0] test_func7,
    input [3:0] expected_alu,
    input expected_zero,
    input expected_taken,
    input [80*8-1:0] instruction_name
);
begin
    // Wait until the controller is ready for a new instruction.
    wait (dut.current_state == dut.Fetch);

    @(negedge clk);
    opcode = 7'b1100011;  // Branch opcode
    func3 = test_func3;
    func7 = test_func7;
    alu_zero = expected_zero;
    mem_ready = 1;

    // Fetch -> Execute1
    @(posedge clk);
    #1;

    if (dut.current_state == dut.Execute1 &&
        alu_opcode === expected_alu)
        $display("PASS: %0s - ALU operation", instruction_name);
    else
        $display("FAIL: %0s - ALU operation or state incorrect",
                 instruction_name);

    if (pc_src === (expected_taken ? 2'b01 : 2'b00))
        $display("PASS: %0s - branch decision", instruction_name);
    else
        $display("FAIL: %0s - expected pc_src=%b, got %b",
                 instruction_name,
                 (expected_taken ? 2'b01 : 2'b00), pc_src);

    if (rf_write_en_n === 1'b1)
        $display("PASS: %0s - register write disabled", instruction_name);
    else
        $display("FAIL: %0s - register write should be disabled",
                 instruction_name);

    if (pc_write_en === 1'b1)
        $display("PASS: %0s - PC write enabled", instruction_name);
    else
        $display("FAIL: %0s - PC write should be enabled",
                 instruction_name);

    // Execute1 -> Fetch for a branch instruction.
    @(posedge clk);
    #1;

    // Hold Fetch until the next test supplies its instruction.
    @(negedge clk);
    mem_ready = 0;
end
endtask

task test_jump_instruction(
    input [6:0] test_opcode,
    input [1:0] expected_pc_src,
    input [3:0] expected_alu,
    input expected_alu_b_src,
    input [80*8-1:0] instruction_name
);
begin
    // Wait for Fetch and prevent premature state transitions.
    wait (dut.current_state == dut.Fetch);
    @(negedge clk);

    mem_ready = 0;
    opcode = test_opcode;
    func3 = 3'b000;
    func7 = 7'b0000000;

    // Start fetching this instruction.
    mem_ready = 1;
    @(posedge clk);
    #1;

    // Check the jump control signals in Execute1.
    if (dut.current_state == dut.Execute1)
        $display("PASS: %0s - Execute1 state", instruction_name);
    else
        $display("FAIL: %0s - expected Execute1, got state %0d",
                 instruction_name, dut.current_state);

    if (pc_src === expected_pc_src)
        $display("PASS: %0s - PC source", instruction_name);
    else
        $display("FAIL: %0s - expected pc_src=%b, got %b",
                 instruction_name, expected_pc_src, pc_src);

    if (rf_write_src === 2'b10)
        $display("PASS: %0s - PC+4 selected for writeback",
                 instruction_name);
    else
        $display("FAIL: %0s - incorrect register write source",
                 instruction_name);

    if (rf_write_en_n === 1'b0)
        $display("PASS: %0s - register write enabled", instruction_name);
    else
        $display("FAIL: %0s - register write should be enabled",
                 instruction_name);

    if (pc_write_en === 1'b1)
        $display("PASS: %0s - PC write enabled", instruction_name);
    else
        $display("FAIL: %0s - PC write should be enabled",
                 instruction_name);

    if (alu_opcode === expected_alu)
        $display("PASS: %0s - ALU operation", instruction_name);
    else
        $display("FAIL: %0s - expected ALU=%b, got %b",
                 instruction_name, expected_alu, alu_opcode);

    if (alu_b_src === expected_alu_b_src)
        $display("PASS: %0s - ALU B source", instruction_name);
    else
        $display("FAIL: %0s - incorrect ALU B source",
                 instruction_name);

    // Jump instructions return to Fetch after Execute1.
    @(posedge clk);
    #1;

    // Hold Fetch so the next instruction can be applied safely.
    @(negedge clk);
    mem_ready = 0;
end
endtask

task test_fsm_wait_behavior;
begin
    $display("--------------------------------");
    $display("TEST 8: FSM wait behavior");
    $display("--------------------------------");

    // Start from a known state.
    @(negedge clk);
    rst_n = 0;
    mem_ready = 0;
    opcode = 0;
    func3 = 0;
    func7 = 0;
    #1;

    if (dut.current_state == dut.Fetch)
        $display("PASS: Reset enters Fetch");
    else
        $display("FAIL: Reset did not enter Fetch");

    @(negedge clk);
    rst_n = 1;
    mem_ready = 0;

    // Check Fetch waits while memory is not ready.
    repeat (2) @(posedge clk);
    #1;

    if (dut.current_state == dut.Fetch)
        $display("PASS: Fetch waits when memory is not ready");
    else
        $display("FAIL: Fetch left before memory was ready");

    // Memory becomes ready: Fetch -> Execute1.
    @(negedge clk);
    mem_ready = 1;
    @(posedge clk);
    #1;

    if (dut.current_state == dut.Execute1)
        $display("PASS: Fetch transitions to Execute1");
    else
        $display("FAIL: Fetch did not transition to Execute1");

    // Set up a load and enter Execute2.
    @(negedge clk);
    opcode = 7'b0000011;
    func3 = 3'b010;
    mem_ready = 1;

    @(posedge clk);
    #1;

    if (dut.current_state == dut.Execute2)
        $display("PASS: Load transitions to Execute2");
    else
        $display("FAIL: Load did not transition to Execute2");

    // Load waits in Execute2 while memory is not ready.
    @(negedge clk);
    mem_ready = 0;

    repeat (2) @(posedge clk);
    #1;

    if (dut.current_state == dut.Execute2)
        $display("PASS: Load waits in Execute2");
    else
        $display("FAIL: Load left Execute2 too early");

    // Memory becomes ready: Execute2 -> Fetch.
    @(negedge clk);
    mem_ready = 1;
    @(posedge clk);
    #1;

    if (dut.current_state == dut.Fetch)
        $display("PASS: Load returns to Fetch when ready");
    else
        $display("FAIL: Load did not return to Fetch");

    // Hold Fetch to prepare the store test.
    @(negedge clk);
    mem_ready = 0;
    opcode = 7'b0100011;
    func3 = 3'b010;

    // Fetch -> Execute1 -> Execute2.
    mem_ready = 1;
    @(posedge clk);
    #1;
    @(posedge clk);
    #1;

    if (dut.current_state == dut.Execute2)
        $display("PASS: Store transitions to Execute2");
    else
        $display("FAIL: Store did not transition to Execute2");

    // Store waits in Execute2 while memory is not ready.
    @(negedge clk);
    mem_ready = 0;

    repeat (2) @(posedge clk);
    #1;

    if (dut.current_state == dut.Execute2)
        $display("PASS: Store waits in Execute2");
    else
        $display("FAIL: Store left Execute2 too early");

    // Memory becomes ready: Execute2 -> Fetch.
    @(negedge clk);
    mem_ready = 1;
    @(posedge clk);
    #1;

    if (dut.current_state == dut.Fetch)
        $display("PASS: Store returns to Fetch when ready");
    else
        $display("FAIL: Store did not return to Fetch");

    @(negedge clk);
    mem_ready = 0;

    $display("================================");
    $display(" TEST 8 COMPLETED");
    $display("================================");
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
        // Test 3: LUI and AUIPC
        $display("------------------------------");
        $display("TEST 3: LUI and AUIPC");
        $display("------------------------------");
        // LUI: pass the immediate through the ALU
        test_u_instruction(
            7'b0110111,  // LUI opcode
            4'b1111,     // ALU_PASS_B
            2'b00,       // Register write-back source
            "LUI"
        );
        // AUIPC: add the immediate to the PC
        test_u_instruction(
            7'b0010111,  // AUIPC opcode
            4'b0000,     // ALU_ADD
            2'b11,       // PC + immediate write-back source
            "AUIPC"
        );
        $display("================================");
        $display(" TEST 3 COMPLETED");
        $display("================================");
        // Test 4: Load instructions
        $display("------------------------------");
        $display("TEST 4: Load instructions");
        $display("------------------------------");
        test_load_instruction(3'b000, "LB");
        test_load_instruction(3'b001, "LH");
        test_load_instruction(3'b010, "LW");
        test_load_instruction(3'b100, "LBU");
        test_load_instruction(3'b101, "LHU");
        $display("================================");
        $display(" TEST 4 COMPLETED");
        $display("================================");   
        // Test 5: Store instructions
        $display("------------------------------");
        $display("TEST 5: Store instructions");
        $display("------------------------------");
        test_store_instruction(3'b000, "SB");
        test_store_instruction(3'b001, "SH");
        test_store_instruction(3'b010, "SW");
        $display("================================");
        $display(" TEST 5 COMPLETED");
        $display("================================");
        $display("--------------------------------");
        $display("TEST 6: Branch instructions");
        $display("--------------------------------");
        // BEQ: taken when alu_zero = 1
        test_branch_instruction(3'b000, 7'b0000000, 4'b0001, 1'b1, 1'b1, "BEQ taken");
        // BEQ: not taken when alu_zero = 0
        test_branch_instruction(3'b000, 7'b0000000, 4'b0001, 1'b0, 1'b0, "BEQ not taken");
        // BNE: taken when alu_zero = 0
        test_branch_instruction(3'b001, 7'b0000000, 4'b0001, 1'b0, 1'b1, "BNE taken");
        // BNE: not taken when alu_zero = 1
        test_branch_instruction(3'b001, 7'b0000000, 4'b0001, 1'b1, 1'b0, "BNE not taken");
        // BLT: taken when alu_zero = 0
        test_branch_instruction(3'b100, 7'b0000000, 4'b0100, 1'b0, 1'b1, "BLT taken");
        // BLT: not taken when alu_zero = 1
        test_branch_instruction(3'b100, 7'b0000000, 4'b0100, 1'b1, 1'b0, "BLT not taken");
        // BGE: taken when alu_zero = 1
        test_branch_instruction(3'b101, 7'b0000000, 4'b0100, 1'b1, 1'b1, "BGE taken");
        // BGE: not taken when alu_zero = 0
        test_branch_instruction(3'b101, 7'b0000000, 4'b0100, 1'b0, 1'b0, "BGE not taken");
        // BLTU: taken when alu_zero = 0
        test_branch_instruction(3'b110, 7'b0000000, 4'b0110, 1'b0, 1'b1, "BLTU taken");
        // BLTU: not taken when alu_zero = 1
        test_branch_instruction(3'b110, 7'b0000000, 4'b0110, 1'b1, 1'b0, "BLTU not taken");
        // BGEU: taken when alu_zero = 1
        test_branch_instruction(3'b111, 7'b0000000, 4'b0110, 1'b1, 1'b1, "BGEU taken");
        // BGEU: not taken when alu_zero = 0
        test_branch_instruction(3'b111, 7'b0000000, 4'b0110, 1'b0, 1'b0, "BGEU not taken");
        $display("================================");
        $display(" TEST 6 COMPLETED");
        $display("================================");
        $display("--------------------------------");
        $display("TEST 7: Jump instructions");
        $display("--------------------------------");
        // JAL: PC-relative jump, return address is PC+4.
        test_jump_instruction(7'b1101111, 2'b01, 4'b0000, 1'b0, "JAL");
        // JALR: register + immediate jump, return address is PC+4.
        test_jump_instruction(7'b1100111, 2'b10, 4'b0000, 1'b1, "JALR");
        $display("================================");
        $display(" TEST 7 COMPLETED");
        $display("================================");
        test_fsm_wait_behavior();
        $finish;
    end

endmodule
