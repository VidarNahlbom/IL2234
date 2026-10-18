`timescale 1ns/1ps

// Hierarchical paths into cpu_top (dut)
`define PC     dut.datapath_inst.pc_inst.pc_out
`define RF     dut.datapath_inst.rf_inst.outputs
`define STATE  dut.controller_inst.current_state
`define FETCH  dut.controller_inst.Fetch
`define EXEC1  dut.controller_inst.Execute1

module cpu_top_tb;
    // Inputs to the CPU
    logic clk;
    logic rst_n;
    logic [31:0] data_in;
    logic mem_ready;

    // Outputs from the CPU
    logic [31:0] addr;
    logic [31:0] data_out;
    logic [3:0] write_en;
    logic read_en;

    // Instantiate the CPU (memory is emulated below)
    cpu_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .mem_ready(mem_ready),
        .addr(addr),
        .data_out(data_out),
        .write_en(write_en),
        .read_en(read_en)
    );

    // Generate clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Watchdog, in case the CPU ever hangs waiting for something
    initial begin
        #5_000_000;
        $display("FAIL: testbench timeout, CPU got stuck");
        $finish;
    end

    // Pass/fail counters
    int pass_count = 0;
    int fail_count = 0;

    // Memory emulation
    // Same behaviour as memory_controller: write = 1 cycle then mem_ready,
    // read = 2 cycles then mem_ready, data valid while mem_ready is high.
    // mem_stall holds the memory idle, so the CPU waits in Fetch between
    // instructions until the testbench has placed the next one.
    logic [31:0] mem [0:1023]; // 4 KiB, word indexed by addr[11:2]
    logic mem_stall;

    typedef enum logic [1:0] {M_IDLE, M_WAIT, M_DONE} mem_state_t;
    mem_state_t mem_state, mem_next;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) mem_state <= M_IDLE;
        else mem_state <= mem_next;
    end

    always_comb begin
        mem_next = M_IDLE;
        mem_ready = 1'b0;
        case (mem_state)
            M_IDLE: begin
                if (!mem_stall) begin
                    if (|write_en)    mem_next = M_DONE;
                    else if (read_en) mem_next = M_WAIT;
                end
            end
            M_WAIT: mem_next = M_DONE;
            M_DONE: mem_ready = 1'b1;
            default: ;
        endcase
    end

    // Synchronous read, byte-wise write (like the SRAM)
    always @(posedge clk) begin
        data_in <= mem[addr[11:2]]; // cpus data in
        for (int b = 0; b < 4; b++) begin
            if (write_en[b]) mem[addr[11:2]][8*b +: 8] = data_out[8*b +: 8];
        end
    end

    // Remember the last write on the bus, to check address and byte enables
    logic [31:0] last_waddr;
    logic [3:0] last_we;
    always @(posedge clk) begin
        if (|write_en) begin
            last_waddr <= addr;
            last_we <= write_en;
        end
    end

    // Opcodes
    localparam logic [6:0] OP_R      = 7'b0110011;
    localparam logic [6:0] OP_I      = 7'b0010011;
    localparam logic [6:0] OP_LOAD   = 7'b0000011;
    localparam logic [6:0] OP_STORE  = 7'b0100011;
    localparam logic [6:0] OP_BRANCH = 7'b1100011;
    localparam logic [6:0] OP_LUI    = 7'b0110111;
    localparam logic [6:0] OP_AUIPC  = 7'b0010111;
    localparam logic [6:0] OP_JAL    = 7'b1101111;
    localparam logic [6:0] OP_JALR   = 7'b1100111;

    // Instruction encoders (field layout from the ISA formats)
    // So that instead of us having to write hexcodes to store in memory for each instruction
    // we can just use these to generate the correct instruction
    function logic [31:0] enc_r(input logic [6:0] f7, input logic [4:0] rs2,
                                input logic [4:0] rs1, input logic [2:0] f3,
                                input logic [4:0] rd);
        enc_r = {f7, rs2, rs1, f3, rd, OP_R};
    endfunction

    function logic [31:0] enc_i(input logic [11:0] imm, input logic [4:0] rs1,
                                input logic [2:0] f3, input logic [4:0] rd,
                                input logic [6:0] op);
        enc_i = {imm, rs1, f3, rd, op};
    endfunction

    function logic [31:0] enc_s(input logic [11:0] imm, input logic [4:0] rs2,
                                input logic [4:0] rs1, input logic [2:0] f3);
        enc_s = {imm[11:5], rs2, rs1, f3, imm[4:0], OP_STORE};
    endfunction

    function logic [31:0] enc_b(input logic [12:0] imm, input logic [4:0] rs2,
                                input logic [4:0] rs1, input logic [2:0] f3);
        enc_b = {imm[12], imm[10:5], rs2, rs1, f3, imm[4:1], imm[11], OP_BRANCH};
    endfunction

    function logic [31:0] enc_u(input logic [19:0] imm, input logic [4:0] rd,
                                input logic [6:0] op);
        enc_u = {imm, rd, op};
    endfunction

    function logic [31:0] enc_j(input logic [20:0] imm, input logic [4:0] rd);
        enc_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd, OP_JAL};
    endfunction

    // Helper tasks
    // Compare a value and print PASS/FAIL
    task check_value(
        input [31:0] actual,
        input [31:0] expected,
        input [80*8-1:0] instruction_name,
        input [40*8-1:0] what
    );
    begin
        if (actual === expected) begin
            $display("PASS: %0s - %0s", instruction_name, what);
            pass_count++;
        end else begin
            $display("FAIL: %0s - %0s", instruction_name, what);
            $display("      Expected = %h, Actual = %h", expected, actual);
            fail_count++;
        end
    end
    endtask

    // Reset the CPU and clear the memory. All registers and the PC become 0.
    task reset_cpu;
    begin
        mem_stall = 1'b1;
        @(negedge clk);
        rst_n = 1'b0;
        for (int i = 0; i < 1024; i++) mem[i] = 32'd0;
        last_we    = 4'b0000;
        last_waddr = 32'd0;
        @(negedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
    end
    endtask

    // Put one instruction in memory at the current PC, let the CPU
    // fetch and execute it, and stop it again once it is back in Fetch.
    task run_instruction(input [31:0] instr);
    begin
        mem[`PC >> 2] = instr; // the shift is divide by 4, which is needed for byte based instead of word based memory so it reads correctly
        @(negedge clk);
        mem_stall = 1'b0; // releases memory to read the instruction
        wait (`STATE == `EXEC1);
        wait (`STATE == `FETCH);
        #1;
        mem_stall = 1'b1; // waits until cpu has completed instruction and then stalls it again
    end
    endtask

    // Load a 32-bit value into a register using LUI + ADDI
    // (LUI and ADDI are verified on their own in TEST 3 and TEST 4)
    // Since we cant write directly to register file, we only emulate memory
    // We put in instructions into memory that loads values into RF
    // So we can put known values into RF x1 and x2
    // So first we load a LUI instruction into mem
    // which loads the upper 20 bits of Value into rd, so x1 or x2
    // lower 12 bits are 0 
    // then we do an ADDI instruction where we add the lower 12 bits

    task set_reg(input [4:0] rd, input [31:0] value);
        logic [19:0] upper;
    begin
        upper = value[31:12] + value[11]; // compensate for ADDI sign extension
        // if bit 12 is 1, then ADDI will think its negative and sign extend it, basically adding -4096
        // but that will ruin the earlier LUI stored values, so we counter this by adding 4096 if we know
        // bit 12 is 1, because then we know that the later ADDI step will just remove that added 4096.
        run_instruction(enc_u(upper, rd, OP_LUI));
        run_instruction(enc_i(value[11:0], rd, 3'b000, rd, OP_I));
    end
    endtask

    // R-type: x3 = x1 (op) x2
    task test_r_instruction(
        input [2:0] test_func3,
        input [6:0] test_func7,
        input [31:0] a,
        input [31:0] b,
        input [31:0] expected,
        input [80*8-1:0] instruction_name
    );
        logic [31:0] pc_before;
    begin
        reset_cpu;
        set_reg(5'd1, a);
        set_reg(5'd2, b);
        pc_before = `PC;

        run_instruction(enc_r(test_func7, 5'd2, 5'd1, test_func3, 5'd3));

        check_value(`RF[3], expected,       instruction_name, "x3 (rd) result");
        check_value(`RF[1], a,              instruction_name, "x1 (rs1) unchanged");
        check_value(`RF[2], b,              instruction_name, "x2 (rs2) unchanged");
        check_value(`PC,    pc_before + 4,  instruction_name, "PC = PC + 4");
    end
    endtask

    // I-type ALU: x3 = x1 (op) imm. For shifts imm = {func7, shamt}
    task test_i_instruction(
        input [2:0] test_func3,
        input [11:0] imm,
        input [31:0] a,
        input [31:0] expected,
        input [80*8-1:0] instruction_name
    );
        logic [31:0] pc_before;
    begin
        reset_cpu;
        set_reg(5'd1, a);
        pc_before = `PC;

        run_instruction(enc_i(imm, 5'd1, test_func3, 5'd3, OP_I));

        check_value(`RF[3], expected,       instruction_name, "x3 (rd) result");
        check_value(`RF[1], a,              instruction_name, "x1 (rs1) unchanged");
        check_value(`PC,    pc_before + 4,  instruction_name, "PC = PC + 4");
    end
    endtask

    // LUI: x3 = imm20 << 12
    task test_lui(
        input [19:0] imm20,
        input [80*8-1:0] instruction_name
    );
        logic [31:0] pc_before;
    begin
        reset_cpu;
        pc_before = `PC;

        run_instruction(enc_u(imm20, 5'd3, OP_LUI));

        check_value(`RF[3], {imm20, 12'b0}, instruction_name, "x3 (rd) result");
        check_value(`PC,    pc_before + 4,  instruction_name, "PC = PC + 4");
    end
    endtask

    // AUIPC: x3 = PC + (imm20 << 12)
    task test_auipc(
        input [19:0] imm20,
        input [80*8-1:0] instruction_name
    );
        logic [31:0] pc_before;
    begin
        reset_cpu;
        set_reg(5'd1, 32'h1); // only here to move the PC away from 0
        pc_before = `PC;

        run_instruction(enc_u(imm20, 5'd3, OP_AUIPC));

        check_value(`RF[3], pc_before + {imm20, 12'b0}, instruction_name, "x3 (rd) = PC + imm");
        check_value(`PC,    pc_before + 4,              instruction_name, "PC = PC + 4");
    end
    endtask

    // Loads: x3 = MEM[x1 + offset]
    task test_load_instruction(
        input [2:0] test_func3,
        input [31:0] base,
        input [11:0] offset,
        input [31:0] mem_word,
        input [31:0] expected,
        input [80*8-1:0] instruction_name
    );
        logic [31:0] pc_before;
        logic [31:0] expected_addr;
    begin
        expected_addr = base + {{20{offset[11]}}, offset};
        reset_cpu;
        mem[expected_addr[11:2]] = mem_word;
        set_reg(5'd1, base);
        pc_before = `PC;

        run_instruction(enc_i(offset, 5'd1, test_func3, 5'd3, OP_LOAD));

        check_value(`RF[3], expected,        instruction_name, "x3 (rd) loaded value");
        check_value(`RF[1], base,            instruction_name, "x1 (rs1) unchanged");
        check_value(`PC,    pc_before + 4,   instruction_name, "PC = PC + 4");
        check_value({28'b0, last_we}, 32'd0, instruction_name, "no memory write issued");
    end
    endtask

    // Stores: MEM[x1 + offset] = x2
    task test_store_instruction(
        input [2:0] test_func3,
        input [31:0] base,
        input [11:0] offset,
        input [31:0] rs2_value,
        input [31:0] init_word,
        input [31:0] expected_word,
        input [3:0] expected_we,
        input [80*8-1:0] instruction_name
    );
        logic [31:0] pc_before;
        logic [31:0] expected_addr;
    begin
        expected_addr = base + {{20{offset[11]}}, offset};
        reset_cpu;
        mem[expected_addr[11:2]] = init_word;
        set_reg(5'd1, base);
        set_reg(5'd2, rs2_value);
        pc_before = `PC;

        run_instruction(enc_s(offset, 5'd2, 5'd1, test_func3));

        check_value(mem[expected_addr[11:2]],   expected_word, instruction_name, "memory word after store");
        check_value({28'b0, last_we}, {28'b0, expected_we}, instruction_name, "write_en byte mask");
        check_value(last_waddr,      expected_addr,            instruction_name, "write address");
        check_value(`RF[1],          base,          instruction_name, "x1 (rs1) unchanged");
        check_value(`RF[2],          rs2_value,     instruction_name, "x2 (rs2) unchanged");
        check_value(`PC,             pc_before + 4, instruction_name, "PC = PC + 4");
    end
    endtask

    // Branches: if (x1 cmp x2) PC += imm else PC += 4
    task test_branch_instruction(
        input [2:0] test_func3,
        input [31:0] a,
        input [31:0] b,
        input [12:0] imm,
        input taken,
        input [80*8-1:0] instruction_name
    );
        logic [31:0] pc_before;
    begin
        reset_cpu;
        set_reg(5'd1, a);
        set_reg(5'd2, b);
        pc_before = `PC;

        run_instruction(enc_b(imm, 5'd2, 5'd1, test_func3));

        if (taken) check_value(`PC, pc_before + {{19{imm[12]}}, imm}, instruction_name, "PC = PC + imm (taken)");
        else       check_value(`PC, pc_before + 4,                    instruction_name, "PC = PC + 4 (not taken)");
        check_value(`RF[1], a, instruction_name, "x1 (rs1) unchanged");
        check_value(`RF[2], b, instruction_name, "x2 (rs2) unchanged");
    end
    endtask

    // JAL: x[rd] = PC + 4, PC += imm
    task test_jal(
        input [20:0] imm,
        input [4:0] rd,
        input [80*8-1:0] instruction_name
    );
        logic [31:0] pc_before;
    begin
        reset_cpu;
        set_reg(5'd2, 32'h1234); // moves the PC away from 0 so negative offsets make sense
        pc_before = `PC;

        run_instruction(enc_j(imm, rd));

        check_value(`PC, pc_before + {{11{imm[20]}}, imm}, instruction_name, "PC = PC + imm");
        if (rd != 5'd0) check_value(`RF[rd], pc_before + 4, instruction_name, "x[rd] = PC + 4 (link)");
        check_value(`RF[2], 32'h1234, instruction_name, "x2 unchanged");
    end
    endtask

    // JALR: x[rd] = PC + 4, PC = (x1 + imm) & ~3
    task test_jalr(
        input [4:0] rd,
        input [31:0] base,
        input [11:0] imm,
        input [31:0] expected_target,
        input [80*8-1:0] instruction_name
    );
        logic [31:0] pc_before;
    begin
        reset_cpu;
        set_reg(5'd1, base);
        pc_before = `PC;

        run_instruction(enc_i(imm, 5'd1, 3'b000, rd, OP_JALR));

        check_value(`PC, expected_target, instruction_name, "PC = (x1 + imm) & ~3");
        if (rd != 5'd0) check_value(`RF[rd], pc_before + 4, instruction_name, "x[rd] = PC + 4 (link)");
    end
    endtask

    function logic is_valid_opcode(input logic [6:0] op);
    case (op)
        OP_R, OP_I, OP_LOAD, OP_STORE, OP_BRANCH,
        OP_LUI, OP_AUIPC, OP_JAL, OP_JALR: is_valid_opcode = 1'b1;
        default:                           is_valid_opcode = 1'b0;
    endcase
    endfunction
    task test_random_instruction(input [31:0] instr);
        logic [31:0] pc_before;
        logic rf_ok;
    begin
        reset_cpu;
        set_reg(5'd1, 32'h1234);
        set_reg(5'd2, 32'h5678);
        pc_before = `PC;

        run_instruction(instr);

        if (is_valid_opcode(instr[6:0])) begin
            $display("INFO: %h has a VALID opcode (%b), executed, result not checked", instr, instr[6:0]);
        end else begin
            $display("INFO: %h has an INVALID opcode (%b), must be ignored", instr, instr[6:0]);
            check_value(`PC, pc_before + 4, "RANDOM invalid opcode", "PC = PC + 4");
            check_value(`RF[1], 32'h1234,    "RANDOM invalid opcode", "x1 unchanged");
            check_value(`RF[2], 32'h5678,    "RANDOM invalid opcode", "x2 unchanged");
            check_value(`RF[3], 32'd0,       "RANDOM invalid opcode", "x3 not written");
            // reset made every register 0, so the rest should still be 0
            rf_ok = 1'b1;
            for (int r = 4; r < 32; r++) begin
                if (`RF[r] !== 32'd0) rf_ok = 1'b0;
            end
            check_value({31'b0, rf_ok}, 32'd1, "RANDOM invalid opcode", "no register written");
        end
    end
    endtask


    // Main test sequence
    initial begin
        rst_n     = 1'b1;
        mem_stall = 1'b1;
        data_in   = 32'd0;
        #2;

        // TEST 1: Reset state
        $display("\n=== TEST 1: Reset state ===");
        reset_cpu;
        check_value(`PC,    32'd0,  "RESET", "PC = 0");
        check_value(`STATE, `FETCH, "RESET", "controller in Fetch");
        check_value(read_en, 32'd1, "RESET", "read_en high in Fetch");
        check_value(`RF[1], 32'd0,  "RESET", "x1 = 0");

        // TEST 2: R-type instructions
        $display("\n=== TEST 2: R-type instructions ===");
        //                 func3   func7       a              b           expected      name
        test_r_instruction(3'b000, 7'b0000000, 32'd5,         32'd7,      32'd12,       "ADD");
        test_r_instruction(3'b000, 7'b0000000, 32'hFFFFFFFF,  32'd1,      32'd0,        "ADD wrap-around"); // Overflow flag should go high, but its never used in this CPU
        test_r_instruction(3'b000, 7'b0100000, 32'd10,        32'd3,      32'd7,        "SUB");
        test_r_instruction(3'b000, 7'b0100000, 32'd3,         32'd10,     32'hFFFFFFF9, "SUB negative result");
        test_r_instruction(3'b001, 7'b0000000, 32'd1,         32'd4,      32'h10,       "SLL"); // 0000 0001 to 0001 0000 (1 to 10 in hexadecimal)
        test_r_instruction(3'b010, 7'b0000000, 32'hFFFFFFFF,  32'd1,      32'd1,        "SLT -1 < 1"); // signed, so should handle negatives
        test_r_instruction(3'b010, 7'b0000000, 32'd1,         32'hFFFFFFFF, 32'd0,      "SLT 1 < -1");
        test_r_instruction(3'b011, 7'b0000000, 32'd1,         32'hFFFFFFFF, 32'd1,      "SLTU 1 < 0xFFFFFFFF"); // unsigned, should not handle negatives so FFFFFFF is larger
        test_r_instruction(3'b011, 7'b0000000, 32'hFFFFFFFF,  32'd1,      32'd0,        "SLTU 0xFFFFFFFF < 1");
        test_r_instruction(3'b100, 7'b0000000, 32'hF0F0F0F0,  32'hFF00FF00, 32'h0FF00FF0, "XOR");
        test_r_instruction(3'b101, 7'b0000000, 32'h80000000,  32'd4,      32'h08000000, "SRL"); 
        test_r_instruction(3'b101, 7'b0100000, 32'h80000000,  32'd4,      32'hF8000000, "SRA");
        test_r_instruction(3'b110, 7'b0000000, 32'hF0F0F0F0,  32'h0F0F0000, 32'hFFFFF0F0, "OR");
        test_r_instruction(3'b111, 7'b0000000, 32'hF0F0F0F0,  32'hFF00FF00, 32'hF000F000, "AND");

        // TEST 3: I-type ALU instructions
        $display("\n=== TEST 3: I-type ALU instructions ===");
        //                 func3   imm12               a             expected      name
        test_i_instruction(3'b000, 12'd5,              32'd10,       32'd15,       "ADDI");
        test_i_instruction(3'b000, 12'hFFD,            32'd10,       32'd7,        "ADDI negative imm (-3)");
        test_i_instruction(3'b010, 12'd3,              32'hFFFFFFFB, 32'd1,        "SLTI -5 < 3");
        test_i_instruction(3'b010, 12'hFFD,            32'd5,        32'd0,        "SLTI 5 < -3");
        test_i_instruction(3'b011, 12'hFFF,            32'd5,        32'd1,        "SLTIU 5 < 0xFFFFFFFF");
        test_i_instruction(3'b011, 12'd1,              32'hFFFFFFFF, 32'd0,        "SLTIU 0xFFFFFFFF < 1");
        test_i_instruction(3'b100, 12'hFFF,            32'h0000FF0F, 32'hFFFF00F0, "XORI"); // imm gets sign extended
        test_i_instruction(3'b110, 12'h00F,            32'h000000F0, 32'h000000FF, "ORI");
        test_i_instruction(3'b111, 12'h0F0,            32'h0FF000FF, 32'h000000F0, "ANDI");
        test_i_instruction(3'b001, {7'b0000000, 5'd4}, 32'd1,        32'h10,       "SLLI");
        test_i_instruction(3'b101, {7'b0000000, 5'd4}, 32'h80000000, 32'h08000000, "SRLI");
        test_i_instruction(3'b101, {7'b0100000, 5'd4}, 32'h80000000, 32'hF8000000, "SRAI");

        // TEST 4: LUI and AUIPC
        $display("\n=== TEST 4: LUI and AUIPC ===");
        test_lui(20'h12345, "LUI");
        test_lui(20'hFFFFF, "LUI all ones");
        test_auipc(20'h00001, "AUIPC");
        test_auipc(20'h12345, "AUIPC large imm");

        // TEST 5: Loads
        // Memory word 0xF27F8001 -> byte0=01, byte1=80, byte2=7F, byte3=F2
        $display("\n=== TEST 5: Load instructions ===");
        //                    func3   base     offset   mem_word      expected      name
        test_load_instruction(3'b000, 32'h200, 12'd0,   32'hF27F8001, 32'h00000001, "LB byte 0");
        test_load_instruction(3'b000, 32'h200, 12'd1,   32'hF27F8001, 32'hFFFFFF80, "LB byte 1 sign-extended");
        test_load_instruction(3'b000, 32'h200, 12'd2,   32'hF27F8001, 32'h0000007F, "LB byte 2");
        test_load_instruction(3'b000, 32'h200, 12'd3,   32'hF27F8001, 32'hFFFFFFF2, "LB byte 3 sign-extended");
        test_load_instruction(3'b001, 32'h200, 12'd0,   32'hF27F8001, 32'hFFFF8001, "LH lower half sign-extended");
        test_load_instruction(3'b001, 32'h200, 12'd2,   32'hF27F8001, 32'hFFFFF27F, "LH upper half sign-extended");
        test_load_instruction(3'b010, 32'h200, 12'd0,   32'hF27F8001, 32'hF27F8001, "LW");
        test_load_instruction(3'b010, 32'h204, 12'hFFC, 32'hF27F8001, 32'hF27F8001, "LW negative offset");
        test_load_instruction(3'b100, 32'h200, 12'd1,   32'hF27F8001, 32'h00000080, "LBU byte 1 zero-extended");
        test_load_instruction(3'b100, 32'h200, 12'd3,   32'hF27F8001, 32'h000000F2, "LBU byte 3 zero-extended");
        test_load_instruction(3'b101, 32'h200, 12'd0,   32'hF27F8001, 32'h00008001, "LHU lower half zero-extended");
        test_load_instruction(3'b101, 32'h200, 12'd2,   32'hF27F8001, 32'h0000F27F, "LHU upper half zero-extended");

        // TEST 6: Stores
        // Memory word starts as 0xAABBCCDD, x2 = 0x11223344
        $display("\n=== TEST 6: Store instructions ===");
        //                     func3   base     offset   rs2           init          expected      we       name
        test_store_instruction(3'b000, 32'h200, 12'd0,   32'h11223344, 32'hAABBCCDD, 32'hAABBCC44, 4'b0001, "SB byte 0");
        test_store_instruction(3'b000, 32'h200, 12'd1,   32'h11223344, 32'hAABBCCDD, 32'hAABB44DD, 4'b0010, "SB byte 1");
        test_store_instruction(3'b000, 32'h200, 12'd2,   32'h11223344, 32'hAABBCCDD, 32'hAA44CCDD, 4'b0100, "SB byte 2");
        test_store_instruction(3'b000, 32'h200, 12'd3,   32'h11223344, 32'hAABBCCDD, 32'h44BBCCDD, 4'b1000, "SB byte 3");
        test_store_instruction(3'b001, 32'h200, 12'd0,   32'h11223344, 32'hAABBCCDD, 32'hAABB3344, 4'b0011, "SH lower half");
        test_store_instruction(3'b001, 32'h200, 12'd2,   32'h11223344, 32'hAABBCCDD, 32'h3344CCDD, 4'b1100, "SH upper half");
        test_store_instruction(3'b010, 32'h200, 12'd0,   32'h11223344, 32'hAABBCCDD, 32'h11223344, 4'b1111, "SW");
        test_store_instruction(3'b010, 32'h204, 12'hFFC, 32'h11223344, 32'hAABBCCDD, 32'h11223344, 4'b1111, "SW negative offset");

        // TEST 7: Branches (imm = +16 unless noted)
        $display("\n=== TEST 7: Branch instructions ===");
        //                      func3   a             b             imm       taken name
        test_branch_instruction(3'b000, 32'd5,        32'd5,        13'd16,   1, "BEQ equal"); 
        test_branch_instruction(3'b000, 32'd5,        32'd6,        13'd16,   0, "BEQ not equal");
        test_branch_instruction(3'b000, 32'd5,        32'd5,        13'h1FF8, 1, "BEQ backwards (-8)");
        test_branch_instruction(3'b001, 32'd5,        32'd6,        13'd16,   1, "BNE not equal");
        test_branch_instruction(3'b001, 32'd5,        32'd5,        13'd16,   0, "BNE equal");
        test_branch_instruction(3'b100, 32'hFFFFFFFF, 32'd1,        13'd16,   1, "BLT -1 < 1");
        test_branch_instruction(3'b100, 32'd1,        32'hFFFFFFFF, 13'd16,   0, "BLT 1 < -1");
        test_branch_instruction(3'b100, 32'd3,        32'd3,        13'd16,   0, "BLT equal");
        test_branch_instruction(3'b101, 32'd1,        32'hFFFFFFFF, 13'd16,   1, "BGE 1 >= -1");
        test_branch_instruction(3'b101, 32'd3,        32'd3,        13'd16,   1, "BGE equal");
        test_branch_instruction(3'b101, 32'hFFFFFFFF, 32'd1,        13'd16,   0, "BGE -1 >= 1");
        test_branch_instruction(3'b110, 32'd1,        32'hFFFFFFFF, 13'd16,   1, "BLTU 1 < 0xFFFFFFFF");
        test_branch_instruction(3'b110, 32'hFFFFFFFF, 32'd1,        13'd16,   0, "BLTU 0xFFFFFFFF < 1");
        test_branch_instruction(3'b110, 32'd3,        32'd3,        13'd16,   0, "BLTU equal");
        test_branch_instruction(3'b111, 32'hFFFFFFFF, 32'd1,        13'd16,   1, "BGEU 0xFFFFFFFF >= 1");
        test_branch_instruction(3'b111, 32'd3,        32'd3,        13'd16,   1, "BGEU equal");
        test_branch_instruction(3'b111, 32'd1,        32'hFFFFFFFF, 13'd16,   0, "BGEU 1 >= 0xFFFFFFFF");

        // TEST 8: JAL and JALR
        $display("\n=== TEST 8: JAL and JALR ===");
        //       imm21       rd     name
        test_jal(21'd64,     5'd1,  "JAL forward");
        test_jal(21'h1FFFF8, 5'd1,  "JAL backwards (-8)");
        test_jal(21'h0ABCDE, 5'd1,  "JAL large imm");
        test_jal(21'd64,     5'd0,  "JAL rd = x0 (plain jump)");

        //        rd    base     imm       expected_target  name
        test_jalr(5'd3, 32'h100, 12'd8,    32'h108, "JALR positive imm");
        test_jalr(5'd3, 32'h200, 12'hFF0,  32'h1F0, "JALR negative imm (-16)");
        test_jalr(5'd3, 32'h103, 12'd0,    32'h100, "JALR clears low 2 bits");
        test_jalr(5'd1, 32'h100, 12'd0,    32'h100, "JALR rd = rs1");
        test_jalr(5'd0, 32'h100, 12'd4,    32'h104, "JALR rd = x0 (return)");

        // TEST 9: random instructions and x0
        $display("\n=== TEST 9: random instructions and x0 ===");
        for (int i = 1; i < 100; i++) begin
            test_random_instruction($urandom);
        end
        
        // Writing to x0 must have no effect
        reset_cpu;
        run_instruction(enc_i(12'd5, 5'd0, 3'b000, 5'd0, OP_I)); // ADDI x0, x0, 5
        run_instruction(enc_i(12'd0, 5'd0, 3'b000, 5'd3, OP_I)); // ADDI x3, x0, 0
        check_value(`RF[3], 32'd0, "x0 hardwired", "x0 still reads 0 after write");

        // ---------------------------------------------------------
        // Summary
        // ---------------------------------------------------------
        $display("\n=== SUMMARY: %0d passed, %0d failed ===", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else                 $display("SOME TESTS FAILED");
        $finish;
    end
endmodule