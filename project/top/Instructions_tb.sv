`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.10.2026 11:15:54
// Design Name: 
// Module Name: Instructions_tb
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


module Instructions_tb(

    );
    
    // Parameters used for testing
    localparam N_runs_per_inst = 20;
    
    // Proper verification of instruction execution requers insight into the internals of the processor.
    // Therefore the following block of code is just interconnects between the different procesor components.
    
    //Defining all the necessary interconnect variables here
    logic CLK;                          // The CLOCK
    logic clk_off;                   // Used to toggle the clock
    logic rst_n;                        // Resets the entire thing, CPU reset
    
    // Signals use to emulate memory
    logic mem_ready;                // To controller
    logic [31:0] raw_data_from_mem; // Data from memory
    
    // Instruction outputs
    logic [31:0] IR_to_Dec;              // Instruction register to Decoder
    
    // Decoder outputs
    // Decoder to multiple components interconnects
    logic [2:0] func3;                   // Func3 from instruction to be used in controller and mem unitts
    logic [31:0] IMM;                    // The immediate value form the intruction.          
    
    // The Decoder to Controller interconnects
    logic [6:0] opcode_dec_to_con;       // Opcode, not the ALU one
    logic [6:0] func7_dec_to_con;        // Func7 to controller
    
    // Decoder to Registers interconnections
    logic [4:0] RD_to_write_addr;        // Addres determening which register is to be written to
    logic [4:0] RS1_to_read_addr1;       // Address determening register to be availabe on data_out_1
    logic [4:0] RS2_to_read_addr2;       // Address determening register to be availabe on data_out_2
    
    
    // Controller outputs 
    logic rf_chip_en;                   // Enable signal for the Registers
    logic rf_write_en_n;                // Write enable for the Registers
    logic mem_addr_src;                 // Selects address for memeory(SRAM), either ALU or Program counter
    logic mem_write_unit_en;            // Enables the memroy write unit in order to write to the SRAM
    logic mem_read_en;                  // Enables reading from the actual SRAM memory
    logic ir_write_en;                  // Writes the input of the IR into the instruction register(IR)
    logic pc_write_en;                  // Writes one of the inputs into the PC depending on the value in PC_src
    logic alu_b_src;                    // Determines what shoudl be used as the source for the B channel of the ALU
    
    logic [1:0] rf_write_src;           // Determines what component shoud be used as a source for the Registers
    logic [3:0] ALU_opcode;             // The opcdoe fed into the ALU
    logic [1:0] PC_src;                 // Dictates which source should be written into the PC when pc_write_en goes high. 
    
    // Registers
    // Inputs
    logic [31:0] reg_data_in;
    // The outputs of the registers
    logic [31:0] reg_data_out_1_to_alu;
    logic [31:0] reg_data_out_2;
    
    // ALU
    // Imputs
    logic [31:0] ALU_in_b;
    
    // Outputs
    logic [31:0] ALU_out;
    logic [2:0] ALU_flags;
    logic [31:0] memory_addr;           // <---------------------------- One of the IOs to memroy

    
    // Program Counter
    logic [31:0] PC_plus_imm;
    logic [31:0] PC_plus_4;
    logic [31:0] PC_out;
    
    // Memory Write Unit
    // Output
    // Used outputs from Memory Write Unit
    
    // Memory Load Unit
    // Output
    logic [31:0] Data_from_mem;
    
    // Memory Write Unit
    // Output
    logic [31:0] data_to_memory;
    logic [3:0] mem_write_en;

    
    // Instanciating the different parts of the CPU
    
    // The ALU
    ALU #(.BW(32)) the_alu (
    // Inputs
    .opcode(ALU_opcode),
    .in_a(reg_data_out_1_to_alu),
    .in_b(ALU_in_b),
    // Outputs
    .out(ALU_out),
    .flags(ALU_flags)
    );
    
    //The registers
    register_file #(.BW(32), .DEPTH(32)) the_registers (
    // Inputs
    .clk(CLK),
    .rst_n(rst_n),
    .chip_en(rf_chip_en),
    .write_en_n(rf_write_en_n),
    .read_addr_1(RS1_to_read_addr1),
    .read_addr_2(RS2_to_read_addr2),
    .data_in(reg_data_in),
    .write_addr(RD_to_write_addr),
    // Outputs
    .data_out_1(reg_data_out_1_to_alu),
    .data_out_2(reg_data_out_2)
    
    );
    
    // Decoder
    Decoder #() the_decoder(
    // Inputs
    .data_in(IR_to_Dec),
    // Outputs
    .opcode(opcode_dec_to_con),
    .rd(RD_to_write_addr),
    .rs1(RS1_to_read_addr1),
    .rs2(RS2_to_read_addr2),
    .func3(func3),
    .func7(func7_dec_to_con),
    .imm(IMM)
    );
    
    // Controller
    controller #() the_controller(
    
    // Inputs
    .clk(CLK),
    .rst_n(rst_n),
    .opcode(opcode_dec_to_con),
    .func3(func3),
    .func7(func7_dec_to_con),
    .alu_zero(ALU_flags[0]),
    .mem_ready(mem_ready),
    
    // Outputs
    .rf_chip_en(rf_chip_en),
    .rf_write_en_n(rf_write_en_n),
    .mem_addr_src(mem_addr_src), 
    .mem_write_unit_en(mem_write_unit_en), 
    .mem_read_en(mem_read_en),
    .ir_write_en(ir_write_en),
    .pc_write_en(pc_write_en),
    .rf_write_src(rf_write_src), 
    .alu_b_src(alu_b_src), 
    .alu_opcode(ALU_opcode), 
    .pc_src(PC_src)
    );
    
    // Instruction regitser
    instruction_register #() the_ir_reg(
    // Inputs
    .clk(CLK),
    .rst_n(rst_n),
    .ir_write_en(ir_write_en),
    .ir_in(raw_data_from_mem),
    // Output
    .ir_out(IR_to_Dec)
    );
    
    // Program Counter
    program_counter #() the_pc(
    // Inputs
    .clk(CLK),
    .rst_n(rst_n),
    .alu_out(ALU_out),
    .imm(IMM),
    .pc_write_en(pc_write_en),
    .pc_src(PC_src),
    // Output
    .pc_plus_imm(PC_plus_imm),
    .pc_plus_4(PC_plus_4),
    .pc_out(PC_out)
    );
    
    // Memory load unit
    memory_load_unit #() the_mem_load(
    // Inputs
    .addr_lo(memory_addr[1:0]),
    .func3(func3),
    .mem_data(raw_data_from_mem),
    // Outputs
    .load_data(Data_from_mem)
    );
    
    // Memory write unit
    memory_write_unit #() the_mem_write(
    // Inputs
    .mem_write(mem_write_unit_en),
    .addr_lo(memory_addr[1:0]),
    .func3(func3),
    .rs2_data(reg_data_out_2),
    // Outputs
    .data_out(data_to_memory),
    .write_en(mem_write_en)
    );
    
    // Now the different Multiplexer interconnects need to be wiered
    
    // U11 Mux for deciding the B channel input of the ALU
    assign ALU_in_b = (alu_b_src) ? IMM : reg_data_out_2;
    
    // U6 Mux for selecting what outputs to be used as addres for the SRAM
    assign memory_addr = (mem_addr_src) ? ALU_out : PC_out;
    
    // U12 Mux for selectig the source for the registers
    always_comb begin
        
        case(rf_write_src)
            2'b00: reg_data_in = ALU_out;
            2'b01: reg_data_in = Data_from_mem;
            2'b10: reg_data_in = PC_plus_4;
            2'b11: reg_data_in = PC_plus_imm;
        
        endcase
    end
    
    // Now to begin the simualtions
    
    // Start the clock
    always begin
        #5;
        if(!clk_off) begin
            CLK = ~CLK;
        end
        
    end
    
    // Defining all the logic variables that are used in the contruction of a intruction.
    // This is done so that they may be randomised 
    
    
    task automatic validate_ADDI(); 
    begin
        $display("Testing the ADDI instruction, Will perform %0d iterations", N_runs_per_inst);
        
        for(int i = 1; i <= N_runs_per_inst; i++) begin
            
            logic [4:0]  rs1  = $urandom_range(1, 31); 
            logic [4:0]  rd   = $urandom_range(1, 31);
            logic [11:0] imm  = $urandom_range(0, 100);
            
            // 1. Reset and disable clock
            clk_off = 1;
            rst_n = 0;
           
            // 2. Load instruction into memory
            raw_data_from_mem[6:0]   = 7'b0010011; // Opcode
            raw_data_from_mem[11:7]  = rd;         // Destination reg
            raw_data_from_mem[14:12] = 3'b000;     // func3
            raw_data_from_mem[19:15] = rs1;        // Source reg
            raw_data_from_mem[31:20] = imm;        // Immediate
            
            #1;
            clk_off = 0;
            rst_n = 1;
            
            // 3. Handle memory handshake across the fetch cycles
            // (Depending on your FSM, you may need to keep mem_ready high 
            // for the duration of the fetch state)
            @(posedge CLK);
            mem_ready = 1;
            
            // WAIT FOR MULTI-CYCLE EXECUTION TO COMPLETE
            // (Adjust the number of clock cycles based on how many your FSM takes per instruction)
            @(posedge CLK); // Cycle 1 (e.g., Fetch completes)
            mem_ready = 0;
            
            @(posedge CLK); // Cycle 2 (Execute)
            @(posedge CLK); // Cycle 3 (Writeback / Finish)
            
            #1; // Small delta settle time
            
            // 4. Check ALU execution (Fixed order of print arguments)
            if ({ALU_flags[2], ALU_out} === ({1'b0, reg_data_out_1_to_alu} + {{20{imm[11]}}, imm})) begin
                $display("[PASS] %0d/%0d ALU addition correct", i, N_runs_per_inst);
            end else begin
                $display("[FAILED] %0d/%0d ALU addition failed. Expected: %0h | Observed: %0h", 
                         i, N_runs_per_inst, 
                         ({1'b0, reg_data_out_1_to_alu} + {{20{imm[11]}}, imm}), 
                         {ALU_flags[2], ALU_out});
            end
            
            // 5. Check PC increment
            if (memory_addr === 4) begin
                $display("[PASS] %0d/%0d PC incremented correctly", i, N_runs_per_inst);
            end else begin
                $display("[FAILED] %0d/%0d PC increment failed (memory_addr = %0h)", i, N_runs_per_inst, memory_addr);
            end
        end 
    end
    endtask
    
    
    task automatic validate_SLTI();
        
        $display("Testing the SLTI instruction, Will perform %0d iterations", N_runs_per_inst);
        
        for (int i = 1; i <= N_runs_per_inst; i++) begin
            
            logic [4:0]  rs1  = $urandom_range(1, 31); 
            logic [4:0]  rd   = $urandom_range(1, 31);
            logic [11:0] imm  = $urandom_range(0, 100);
            
            // 1. Reset and disable clock
            clk_off = 1;
            rst_n = 0;
            
            // 2. Load instruction into memory
            raw_data_from_mem[6:0]   = 7'b0010011; // Opcode
            raw_data_from_mem[11:7]  = rd;         // Destination reg
            raw_data_from_mem[14:12] = 3'b010;     // func3
            raw_data_from_mem[19:15] = rs1;        // Source reg
            raw_data_from_mem[31:20] = imm;        // Immediate
            
            #1;
            clk_off = 0;
            rst_n = 1;
            
            @(posedge CLK); // Starting Fetch state
            mem_ready = 1;
            
            @(posedge CLK);     // Transitioning from the Fetch to execute 1
            mem_ready = 0;
            
            @(posedge CLK);     // Transition from Execute 1 to Execute 2
            @(posedge CLK);     // Finished with execute 2. Now the CPU is waiting in the fetch state for tthe memroy to reply with the next instruction
            
            #1;     // Ensure that this the CPU is truly done and waiting in the fetch state.
            
            if (($signed(reg_data_out_1_to_alu) < $signed(imm)) & ALU_out === 1) begin
            
                $display("[PASS] %0d/%0d SLTI executed correctly", i, N_runs_per_inst);
            end else begin
                
                $display("[FAILED] %od/%0d Filed to execute SLTI intrcution. Expectd: %0b | Obderved %0b", i , N_runs_per_inst, ($signed(reg_data_out_1_to_alu) < $signed(imm)), ALU_out);
            end
            
            // 5. Check PC increment
            if (memory_addr === 4) begin
                $display("[PASS] %0d/%0d PC incremented correctly", i, N_runs_per_inst);
            end else begin
                $display("[FAILED] %0d/%0d PC increment failed (memory_addr = %0h)", i, N_runs_per_inst, memory_addr);
            end
        end
        
    endtask
    
    
    task automatic validate_SLTIU();
        
        $display("Testing the SLTIU instruction, Will perform %0d iterations", N_runs_per_inst);
        
        for (int i = 1; i <= N_runs_per_inst; i++) begin
            
            logic [4:0]  rs1  = $urandom_range(1, 31); 
            logic [4:0]  rd   = $urandom_range(1, 31);
            logic [11:0] imm  = $urandom_range(0, 100);
            
            // 1. Reset and disable clock
            clk_off = 1;
            rst_n = 0;
            
            // 2. Load instruction into memory
            raw_data_from_mem[6:0]   = 7'b0010011; // Opcode
            raw_data_from_mem[11:7]  = rd;         // Destination reg
            raw_data_from_mem[14:12] = 3'b011;     // func3
            raw_data_from_mem[19:15] = rs1;        // Source reg
            raw_data_from_mem[31:20] = imm;        // Immediate
            
            #1;
            clk_off = 0;
            rst_n = 1;
            
            @(posedge CLK); // Starting Fetch state
            mem_ready = 1;
            
            @(posedge CLK);     // Transitioning from the Fetch to execute 1
            mem_ready = 0;
            
            @(posedge CLK);     // Transition from Execute 1 to Execute 2
            @(posedge CLK);     // Finished with execute 2. Now the CPU is waiting in the fetch state for tthe memroy to reply with the next instruction
            
            #1;     // Ensure that this the CPU is truly done and waiting in the fetch state.
            
            if ((reg_data_out_1_to_alu < imm) & ALU_out === 1) begin
            
                $display("[PASS] %0d/%0d SLTIU executed correctly", i, N_runs_per_inst);
            end else begin
                
                $display("[FAILED] %od/%0d Filed to execute SLTIU intrcution. Expectd: %0b | Obderved %0b", i , N_runs_per_inst, (reg_data_out_1_to_alu < imm), ALU_out);
            end
            
            // 5. Check PC increment
            if (memory_addr === 4) begin
                $display("[PASS] %0d/%0d PC incremented correctly", i, N_runs_per_inst);
            end else begin
                $display("[FAILED] %0d/%0d PC increment failed (memory_addr = %0h)", i, N_runs_per_inst, memory_addr);
            end
        end
        
    endtask
    
    
    task automatic validate_XORI();
        
        $display("Testing the XORI instruction, Will perform %0d iterations", N_runs_per_inst);
        
        for(int i = 0; i <= N_runs_per_inst; i++) begin
            
            logic [4:0]  rs1  = $urandom_range(1, 31); 
            logic [4:0]  rd   = $urandom_range(1, 31);
            logic [11:0] imm  = $urandom_range(0, 100);
            
            // 1. Reset and disable clock
            clk_off = 1;
            rst_n = 0;
            
            // 2. Load instruction into memory
            raw_data_from_mem[6:0]   = 7'b0010011; // Opcode
            raw_data_from_mem[11:7]  = rd;         // Destination reg
            raw_data_from_mem[14:12] = 3'b100;     // func3
            raw_data_from_mem[19:15] = rs1;        // Source reg
            raw_data_from_mem[31:20] = imm;        // Immediate
            
            #1;
            clk_off = 0;
            rst_n = 1;
            
            @(posedge CLK); // CPU Should be in Fecth state. Repprt that memory is ready
            mem_ready = 1;
            
            @(posedge CLK); // CPU should have read memory. and transition into execute 1
            mem_ready = 0;
            
            @(posedge CLK);
            @(posedge CLK);     // Let the CPU tarnsition through execute 1 and execute 1 back to fetch next intruction
            
            #1;     // Delay to check stability should still be in Fetch
            
            if ((reg_data_out_1_to_alu ^ imm) === ALU_out) begin
                
                $display("[PASS] %0d/%0d XORI executed correctly", i, N_runs_per_inst);
            end else begin
            
                $display("[FAILED] %0d/%0d XORI failed to execute, Expected: %0b | Observed: %0b", i, N_runs_per_inst, (reg_data_out_1_to_alu ^ imm), ALU_out);
            end
            
            // 5. Check PC increment
            if (memory_addr === 4) begin
                $display("[PASS] %0d/%0d PC incremented correctly", i, N_runs_per_inst);
            end else begin
                $display("[FAILED] %0d/%0d PC increment failed (memory_addr = %0h)", i, N_runs_per_inst, memory_addr);
            end
        end
        
    endtask
    
    
    task automatic validate_ORI();
        
        $display("Testing the ORI instruction, Will perform %0d iterations", N_runs_per_inst);
        
        for(int i = 0; i <= N_runs_per_inst; i++) begin
            
            logic [4:0]  rs1  = $urandom_range(1, 31); 
            logic [4:0]  rd   = $urandom_range(1, 31);
            logic [11:0] imm  = $urandom_range(0, 100);
            
            // 1. Reset and disable clock
            clk_off = 1;
            rst_n = 0;
            
            // 2. Load instruction into memory
            raw_data_from_mem[6:0]   = 7'b0010011; // Opcode
            raw_data_from_mem[11:7]  = rd;         // Destination reg
            raw_data_from_mem[14:12] = 3'b110;     // func3
            raw_data_from_mem[19:15] = rs1;        // Source reg
            raw_data_from_mem[31:20] = imm;        // Immediate
            
            #1;
            clk_off = 0;
            rst_n = 1;
            
            @(posedge CLK); // CPU Should be in Fecth state. Repprt that memory is ready
            mem_ready = 1;
            
            @(posedge CLK); // CPU should have read memory. and transition into execute 1
            mem_ready = 0;
            
            @(posedge CLK);
            @(posedge CLK);     // Let the CPU tarnsition through execute 1 and execute 1 back to fetch next intruction
            
            #1;     // Delay to check stability should still be in Fetch
            
            if ((reg_data_out_1_to_alu | imm) === ALU_out) begin
                
                $display("[PASS] %0d/%0d ORI executed correctly", i, N_runs_per_inst);
            end else begin
            
                $display("[FAILED] %0d/%0d ORI failed to execute, Expected: %0b | Observed: %0b", i, N_runs_per_inst, (reg_data_out_1_to_alu | imm), ALU_out);
            end
            
            // 5. Check PC increment
            if (memory_addr === 4) begin
                $display("[PASS] %0d/%0d PC incremented correctly", i, N_runs_per_inst);
            end else begin
                $display("[FAILED] %0d/%0d PC increment failed (memory_addr = %0h)", i, N_runs_per_inst, memory_addr);
            end
        end
        
    endtask
    
    
    task automatic validate_ANDI();
        
        $display("Testing the ANDI instruction, Will perform %0d iterations", N_runs_per_inst);
        
        for(int i = 0; i <= N_runs_per_inst; i++) begin
            
            logic [4:0]  rs1  = $urandom_range(1, 31); 
            logic [4:0]  rd   = $urandom_range(1, 31);
            logic [11:0] imm  = $urandom_range(0, 100);
            
            // 1. Reset and disable clock
            clk_off = 1;
            rst_n = 0;
            
            // 2. Load instruction into memory
            raw_data_from_mem[6:0]   = 7'b0010011; // Opcode
            raw_data_from_mem[11:7]  = rd;         // Destination reg
            raw_data_from_mem[14:12] = 3'b111;     // func3
            raw_data_from_mem[19:15] = rs1;        // Source reg
            raw_data_from_mem[31:20] = imm;        // Immediate
            
            #1;
            clk_off = 0;
            rst_n = 1;
            
            @(posedge CLK); // CPU Should be in Fecth state. Repprt that memory is ready
            mem_ready = 1;
            
            @(posedge CLK); // CPU should have read memory. and transition into execute 1
            mem_ready = 0;
            
            @(posedge CLK);
            @(posedge CLK);     // Let the CPU tarnsition through execute 1 and execute 1 back to fetch next intruction
            
            #1;     // Delay to check stability should still be in Fetch
            
            if ((reg_data_out_1_to_alu & imm) === ALU_out) begin
                
                $display("[PASS] %0d/%0d ANDI executed correctly", i, N_runs_per_inst);
            end else begin
            
                $display("[FAILED] %0d/%0d ANDI failed to execute, Expected: %0b | Observed: %0b", i, N_runs_per_inst, (reg_data_out_1_to_alu & imm), ALU_out);
            end
            
            // 5. Check PC increment
            if (memory_addr === 4) begin
                $display("[PASS] %0d/%0d PC incremented correctly", i, N_runs_per_inst);
            end else begin
                $display("[FAILED] %0d/%0d PC increment failed (memory_addr = %0h)", i, N_runs_per_inst, memory_addr);
            end
        end
        
    endtask
    
    task automatic validate_SLLI();
        
        $display("Testing the SLLI instruction, Will perform %0d iterations", N_runs_per_inst);
        
        for (int i = 0; i <= N_runs_per_inst; i++) begin
            
            logic [4:0]  rs1  = $urandom_range(1, 31); 
            logic [4:0]  rd   = $urandom_range(1, 31);
            logic [4:0] imm  = $urandom_range(0, 100);
            
            // 1. Reset and disable clock
            clk_off = 1;
            rst_n = 0;
            
            // 2. Load instruction into memory
            raw_data_from_mem[6:0]   = 7'b0010011;              // Opcode
            raw_data_from_mem[11:7]  = rd;                      // Destination reg
            raw_data_from_mem[14:12] = 3'b001;                  // func3
            raw_data_from_mem[19:15] = rs1;                     // Source reg
            raw_data_from_mem[31:20] = {7'b0000000, imm};        // Immediate
            
            #1;
            clk_off = 0;
            rst_n = 1;
            
            @(posedge CLK); // CPU Should be in Fecth state. Repprt that memory is ready
            mem_ready = 1;
            
            @(posedge CLK); // CPU should have read memory. and transition into execute 1
            mem_ready = 0;
            
            @(posedge CLK);
            @(posedge CLK);     // Let the CPU tarnsition through execute 1 and execute 1 back to fetch next intruction
            
            #1;     // Delay to check stability should still be in Fetch
            
            if (ALU_out === (reg_data_out_1_to_alu << imm[4:0])) begin
                
                $display("[PASS] %0d/%0d SLLI executed correctly", i, N_runs_per_inst);
            end else begin
            
                $display("[FAILED] %0d/%0d SLLI failed to execute, Expected: %0b | Observed: %0b", i, N_runs_per_inst, (reg_data_out_1_to_alu << imm[4:0]), ALU_out);
            end
            
            // 5. Check PC increment
            if (memory_addr === 4) begin
                $display("[PASS] %0d/%0d PC incremented correctly", i, N_runs_per_inst);
            end else begin
                $display("[FAILED] %0d/%0d PC increment failed (memory_addr = %0h)", i, N_runs_per_inst, memory_addr);
            end
            
            
        end
        
    endtask
    
    
    task automatic validate_SRLI();
        
        $display("Testing the SRLI instruction, Will perform %0d iterations", N_runs_per_inst);
        
        for (int i = 0; i <= N_runs_per_inst; i++) begin
            
            logic [4:0]  rs1  = $urandom_range(1, 31); 
            logic [4:0]  rd   = $urandom_range(1, 31);
            logic [4:0] imm  = $urandom_range(0, 100);
            
            // 1. Reset and disable clock
            clk_off = 1;
            rst_n = 0;
            
            // 2. Load instruction into memory
            raw_data_from_mem[6:0]   = 7'b0010011;              // Opcode
            raw_data_from_mem[11:7]  = rd;                      // Destination reg
            raw_data_from_mem[14:12] = 3'b101;                  // func3
            raw_data_from_mem[19:15] = rs1;                     // Source reg
            raw_data_from_mem[31:20] = {7'b0000000, imm};        // Immediate
            
            #1;
            clk_off = 0;
            rst_n = 1;
            
            @(posedge CLK); // CPU Should be in Fecth state. Repprt that memory is ready
            mem_ready = 1;
            
            @(posedge CLK); // CPU should have read memory. and transition into execute 1
            mem_ready = 0;
            
            @(posedge CLK);
            @(posedge CLK);     // Let the CPU tarnsition through execute 1 and execute 1 back to fetch next intruction
            
            #1;     // Delay to check stability should still be in Fetch
            
            if (ALU_out === (reg_data_out_1_to_alu >> imm[4:0])) begin
                
                $display("[PASS] %0d/%0d SRLI executed correctly", i, N_runs_per_inst);
            end else begin
            
                $display("[FAILED] %0d/%0d SRLI failed to execute, Expected: %0b | Observed: %0b", i, N_runs_per_inst, (reg_data_out_1_to_alu >> imm[4:0]), ALU_out);
            end
            
            // 5. Check PC increment
            if (memory_addr === 4) begin
                $display("[PASS] %0d/%0d PC incremented correctly", i, N_runs_per_inst);
            end else begin
                $display("[FAILED] %0d/%0d PC increment failed (memory_addr = %0h)", i, N_runs_per_inst, memory_addr);
            end
            
            
        end
        
    endtask
     
    task automatic validate_SRAI();
        
        $display("Testing the SRAI instruction, Will perform %0d iterations", N_runs_per_inst);
        
        for (int i = 0; i <= N_runs_per_inst; i++) begin
            
            logic [4:0]  rs1  = $urandom_range(1, 31); 
            logic [4:0]  rd   = $urandom_range(1, 31);
            logic [4:0] imm  = $urandom_range(0, 100);
            
            // 1. Reset and disable clock
            clk_off = 1;
            rst_n = 0;
            
            // 2. Load instruction into memory
            raw_data_from_mem[6:0]   = 7'b0010011;              // Opcode
            raw_data_from_mem[11:7]  = rd;                      // Destination reg
            raw_data_from_mem[14:12] = 3'b101;                  // func3
            raw_data_from_mem[19:15] = rs1;                     // Source reg
            raw_data_from_mem[31:20] = {7'b0100000, imm};        // Immediate
            
            #1;
            clk_off = 0;
            rst_n = 1;
            
            @(posedge CLK); // CPU Should be in Fecth state. Repprt that memory is ready
            mem_ready = 1;
            
            @(posedge CLK); // CPU should have read memory. and transition into execute 1
            mem_ready = 0;
            
            @(posedge CLK);
            @(posedge CLK);     // Let the CPU tarnsition through execute 1 and execute 1 back to fetch next intruction
            
            #1;     // Delay to check stability should still be in Fetch
            
            if (ALU_out === ($signed(reg_data_out_1_to_alu) >>> imm[4:0] )) begin
                
                $display("[PASS] %0d/%0d SRAI executed correctly", i, N_runs_per_inst);
            end else begin
            
                $display("[FAILED] %0d/%0d SRAI failed to execute, Expected: %0b | Observed: %0b", i, N_runs_per_inst, (reg_data_out_1_to_alu >> imm[4:0]), ALU_out);
            end
            
            // 5. Check PC increment
            if (memory_addr === 4) begin
                $display("[PASS] %0d/%0d PC incremented correctly", i, N_runs_per_inst);
            end else begin
                $display("[FAILED] %0d/%0d PC increment failed (memory_addr = %0h)", i, N_runs_per_inst, memory_addr);
            end
            
            
        end
        
    endtask
    
    task automatic validate_LB();
    begin
        $display("Testing the LB instruction, Will perform %0d iterations", N_runs_per_inst);
        
        for (int i = 1; i <= N_runs_per_inst; i++) begin
            
            logic [4:0]  rs1     = $urandom_range(1, 31); 
            logic [4:0]  rd      = $urandom_range(1, 31);
            logic [11:0] imm     = $urandom_range(0, 100);
            logic [31:0] mem_val = $urandom();
            
            // 1. Reset and disable clock
            rst_n   = 0;
            
            // 2. Load instruction into memory (I-type Load Byte format)[cite: 2, 3, 5]
            raw_data_from_mem[6:0]   = 7'b0000011; // Opcode for loads[cite: 5]
            raw_data_from_mem[11:7]  = rd;         // Destination reg[cite: 2, 3]
            raw_data_from_mem[14:12] = 3'b000;     // func3 for LB[cite: 5]
            raw_data_from_mem[19:15] = rs1;        // Source reg (base address)[cite: 2, 3]
            raw_data_from_mem[31:20] = imm;        // 12-bit signed immediate offset[cite: 2, 3]
            
            #1;
            rst_n   = 1;
            
            // CPU enters into fetch state. Alternatively this handles the flase posedge caused by cpu_off going low to high
            @(posedge CLK);     
            
            // 3. Fetch state handshake. Tell the awaiting CPU that we are ready to send the intruction
            @(posedge CLK); 
            mem_ready = 1;
            
            // 4. Move to Execute 1 (Address Calculation). Instruction read into IR and ALU can carry out calculation for memory_addr. 
            @(posedge CLK); 
            mem_ready = 0;
            
   
            // Verify computed memory address
            if (memory_addr === (reg_data_out_1_to_alu + {{20{imm[11]}}, imm})) begin  
                $display("[PASS] %0d / %0d LB requested correct memory address.", i, N_runs_per_inst);
            end else begin
                $display("[FAILED] %0d / %0d LB requested wrong memory address. Expected: %0b | Observed: %0b", 
                         i, N_runs_per_inst, (reg_data_out_1_to_alu + {{20{imm[11]}}, imm}), memory_addr);
                continue;
            end
            
            // 5. Provide simulated memory data for Execute 2[cite: 8]
            raw_data_from_mem = mem_val;
            #1; // Emulate memory read latency
            
            @(posedge CLK); // Enter Execute 2 state[cite: 8]
            mem_ready = 1;
            
            @(posedge CLK);
            mem_ready = 0;
            
            #1; // Settling time
            
            // 6. Verify sign-extended data output (x[rd] = signext(MEM[x[rs1]+imm][7:0]))[cite: 5]
            if (Data_from_mem === { {24{mem_val[7]}}, mem_val[7:0] }) begin
                $display("[PASS] %0d / %0d LB sign-extension correct", i, N_runs_per_inst);
            end else begin
                $display("[FAILED] %0d / %0d LB Failed to sign extend. Expected: %0b | Observed: %0b", 
                         i, N_runs_per_inst, { {24{mem_val[7]}}, mem_val[7:0] }, Data_from_mem);
            end
        end
    end
    endtask
         
    initial begin
        
        // Reset the CPU and deisable the clock
        CLK = 0;
        rst_n = 0;
        clk_off = 1;
        
        #5;     // Await for stability    
        
        // TESTING ADDI
        validate_ADDI();
        
        // TESTING SLTI
        validate_SLTI();
        
        validate_SLTIU();
        
        validate_XORI();
        
        validate_ORI();
        
        validate_ANDI();
        
        validate_SLLI();
        
        validate_SRLI();
        
        validate_LB();
        $finish;
    end
    
endmodule
