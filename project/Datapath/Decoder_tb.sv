`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.10.2026 09:11:10
// Design Name: 
// Module Name: Decoder_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Comprehensive Verbose Testbench for RISC-V Decoder
// 
//////////////////////////////////////////////////////////////////////////////////

module Decoder_tb;
    
    // Inputs to the DUT (Decoder)
    logic [31:0] Instruction;
    
    // Outputs from the Decoder
    logic [6:0] opcode;
    logic [4:0] rd;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [2:0] func3;
    logic [6:0] func7;
    logic [31:0] imm;
    
    // Instantiate the Decoder DUT
    Decoder #() DUT_Decoder (
        .data_in(Instruction),
        .opcode(opcode),
        .rd(rd),
        .rs1(rs1),
        .rs2(rs2),
        .func3(func3),
        .func7(func7),
        .imm(imm)
    );
        
    // Define the 9 target opcodes based on the RISC-V base ISA specification
    localparam logic [6:0] OP_R      = 7'b0110011; // 1: Register-to-register
    localparam logic [6:0] OP_I      = 7'b0010011; // 2: Immediate ALU
    localparam logic [6:0] OP_LOAD   = 7'b0000011; // 3: Memory Load
    localparam logic [6:0] OP_STORE  = 7'b0100011; // 4: Memory Store
    localparam logic [6:0] OP_BRANCH = 7'b1100011; // 5: Conditional Branch (SB-type)
    localparam logic [6:0] OP_LUI    = 7'b0110111; // 6: Load Upper Immediate (U-type)
    localparam logic [6:0] OP_AUIPC  = 7'b0010111; // 7: Add Upper Immediate to PC (U-type)
    localparam logic [6:0] OP_JAL    = 7'b1101111; // 8: Jump and Link (UJ-type)
    localparam logic [6:0] OP_JALR   = 7'b1100111; // 9: Jump and Link Register (I-type)
    
    int opcode_number;
    int pass_count = 0;
    int fail_count = 0;
    
    // Temporary expected value buffers
    logic [4:0] tmp_rd;
    logic [4:0] tmp_rs1;
    logic [4:0] tmp_rs2;
    logic [2:0] tmp_func3;
    logic [6:0] tmp_func7;
    logic [31:0] tmp_imm;
    
    // Raw bits for immediate construction
    logic [11:0] imm12_val;
    logic [19:0] imm20_val;
    logic [12:0] imm13_val;
    logic [21:0] imm21_val;
    
    // Variables used for ensuring match or not
    logic match = 1;
        
    initial begin
        $display("--- Beginning Verbose Decoder Verification ---");
        
        for (int i_test_run = 0; i_test_run < 50; i_test_run++) begin
            
            // Select a random opcode category from 1 to 9
            opcode_number = $urandom_range(1, 9);
            Instruction = '0; // Clear instruction bus
            match = 1;
            
            case (opcode_number)
                
                // ----------------------------------------------------
                // 1. R-TYPE INSTRUCTIONS (OP_R)
                // ----------------------------------------------------
                1: begin
                    Instruction[6:0]   = OP_R;
                    tmp_rd             = $urandom_range(31, 0);
                    Instruction[11:7]  = tmp_rd;
                    tmp_func3          = $urandom_range(7, 0);
                    Instruction[14:12] = tmp_func3;
                    tmp_rs1            = $urandom_range(31, 0);
                    Instruction[19:15] = tmp_rs1;
                    tmp_rs2            = $urandom_range(31, 0);
                    Instruction[24:20] = tmp_rs2;
                    tmp_func7          = $urandom_range(127, 0);
                    Instruction[31:25] = tmp_func7;
                    
                    tmp_imm            = 32'sd0; 
                    
                    #1; // Wait for combinational propagation
                    
                    $write("Run %02d [R-type]: ", i_test_run);
                    if (rd !== tmp_rd) begin $write("RD mismatch (Exp: %05b, Got: %05b) | ", tmp_rd, rd); match = 0; end
                    if (func3 !== tmp_func3) begin $write("FUNC3 mismatch (Exp: %03b, Got: %03b) | ", tmp_func3, func3); match = 0; end
                    if (rs1 !== tmp_rs1) begin $write("RS1 mismatch (Exp: %05b, Got: %05b) | ", tmp_rs1, rs1); match = 0; end
                    if (rs2 !== tmp_rs2) begin $write("RS2 mismatch (Exp: %05b, Got: %05b) | ", tmp_rs2, rs2); match = 0; end
                    if (func7 !== tmp_func7) begin $write("FUNC7 mismatch (Exp: %07b, Got: %07b) | ", tmp_func7, func7); match = 0; end
                    if (imm !== 32'sd0) begin $write("IMM mismatch (Exp: %032b, Got: %032b) | ", 32'sd0, imm); match = 0; end
                end
                
                // ----------------------------------------------------
                // 2. I-TYPE ALU INSTRUCTIONS (OP_I)
                // ----------------------------------------------------
                2: begin
                    Instruction[6:0]   = OP_I;
                    tmp_rd             = $urandom_range(31, 0);
                    Instruction[11:7]  = tmp_rd;
                    tmp_func3          = $urandom_range(7, 0);
                    Instruction[14:12] = tmp_func3;
                    tmp_rs1            = $urandom_range(31, 0);
                    Instruction[19:15] = tmp_rs1;
                    
                    imm12_val          = $urandom;
                    Instruction[31:20] = imm12_val;
                    tmp_imm            = {{20{imm12_val[11]}}, imm12_val};
                    
                    #1;
                    
                    $write("Run %02d [I-type ALU]: ", i_test_run);
                    if (rd !== tmp_rd) begin $write("RD mismatch (Exp: %05b, Got: %05b) | ", tmp_rd, rd); match = 0; end
                    if (func3 !== tmp_func3) begin $write("FUNC3 mismatch (Exp: %03b, Got: %03b) | ", tmp_func3, func3); match = 0; end
                    if (rs1 !== tmp_rs1) begin $write("RS1 mismatch (Exp: %05b, Got: %05b) | ", tmp_rs1, rs1); match = 0; end
                    if (imm !== tmp_imm) begin $write("IMM mismatch (Exp: %032b, Got: %032b) | ", tmp_imm, imm); match = 0; end
                end
                
                // ----------------------------------------------------
                // 3. I-TYPE LOAD INSTRUCTIONS (OP_LOAD)
                // ----------------------------------------------------
                3: begin
                    Instruction[6:0]   = OP_LOAD;
                    tmp_rd             = $urandom_range(31, 0);
                    Instruction[11:7]  = tmp_rd;
                    tmp_func3          = $urandom_range(7, 0); 
                    Instruction[14:12] = tmp_func3;
                    tmp_rs1            = $urandom_range(31, 0);
                    Instruction[19:15] = tmp_rs1;
                   
                    imm12_val          = $urandom;
                    Instruction[31:20] = imm12_val;
                    tmp_imm            = {{20{imm12_val[11]}}, imm12_val};
                    
                    #1;
                    
                    $write("Run %02d [Load]: ", i_test_run);
                    if (rd !== tmp_rd) begin $write("RD mismatch (Exp: %05b, Got: %05b) | ", tmp_rd, rd); match = 0; end
                    if (func3 !== tmp_func3) begin $write("FUNC3 mismatch (Exp: %03b, Got: %03b) | ", tmp_func3, func3); match = 0; end
                    if (rs1 !== tmp_rs1) begin $write("RS1 mismatch (Exp: %05b, Got: %05b) | ", tmp_rs1, rs1); match = 0; end
                    if (imm !== tmp_imm) begin $write("IMM mismatch (Exp: %032b, Got: %032b) | ", tmp_imm, imm); match = 0; end
                end
                
                // ----------------------------------------------------
                // 4. S-TYPE STORE INSTRUCTIONS (OP_STORE)
                // ----------------------------------------------------
                4: begin
                    Instruction[6:0]   = OP_STORE;
                    tmp_func3          = $urandom_range(7, 0); 
                    Instruction[14:12] = tmp_func3;
                    tmp_rs1            = $urandom_range(31, 0);
                    Instruction[19:15] = tmp_rs1;
                    tmp_rs2            = $urandom_range(31, 0);
                    Instruction[24:20] = tmp_rs2;
                    
                    imm12_val          = $urandom;
                    Instruction[31:25] = imm12_val[11:5];
                    Instruction[11:7]  = imm12_val[4:0];
                    tmp_imm            = {{20{imm12_val[11]}}, imm12_val};
                    
                    #1;
                    
                    $write("Run %02d [Store]: ", i_test_run);
                    if (func3 !== tmp_func3) begin $write("FUNC3 mismatch (Exp: %03b, Got: %03b) | ", tmp_func3, func3); match = 0; end
                    if (rs1 !== tmp_rs1) begin $write("RS1 mismatch (Exp: %05b, Got: %05b) | ", tmp_rs1, rs1); match = 0; end
                    if (rs2 !== tmp_rs2) begin $write("RS2 mismatch (Exp: %05b, Got: %05b) | ", tmp_rs2, rs2); match = 0; end
                    if (imm !== tmp_imm) begin $write("IMM mismatch (Exp: %032b, Got: %032b) | ", tmp_imm, imm); match = 0; end
                end
                
                // ----------------------------------------------------
                // 5. SB-TYPE CONDITIONAL BRANCH INSTRUCTIONS (OP_BRANCH)
                // ----------------------------------------------------
                5: begin
                    Instruction[6:0]   = OP_BRANCH;
                    tmp_func3          = $urandom_range(7, 0); 
                    Instruction[14:12] = tmp_func3;
                    tmp_rs1            = $urandom_range(31, 0);
                    Instruction[19:15] = tmp_rs1;
                    tmp_rs2            = $urandom_range(31, 0);
                    Instruction[24:20] = tmp_rs2;
                    
                    imm13_val          = $urandom;
                    Instruction[31]    = imm13_val[12];
                    Instruction[30:25] = imm13_val[10:5];
                    Instruction[11:8]  = imm13_val[4:1];
                    Instruction[7]     = imm13_val[11];
                    
                    tmp_imm            = {{19{imm13_val[12]}}, imm13_val[12:0]};
                    tmp_imm[0]         = 0;     // Assumed due to addresses in RISC_V are always even
                    
                    #1;
                    
                    $write("Run %02d [Branch]: ", i_test_run);
                    if (func3 !== tmp_func3) begin $write("FUNC3 mismatch (Exp: %03b, Got: %03b) | ", tmp_func3, func3); match = 0; end
                    if (rs1 !== tmp_rs1) begin $write("RS1 mismatch (Exp: %05b, Got: %05b) | ", tmp_rs1, rs1); match = 0; end
                    if (rs2 !== tmp_rs2) begin $write("RS2 mismatch (Exp: %05b, Got: %05b) | ", tmp_rs2, rs2); match = 0; end
                    if (imm !== tmp_imm) begin $write("IMM mismatch (Exp: %032b, Got: %032b) | ", tmp_imm, imm); match = 0; end
                end
                
                // ----------------------------------------------------
                // 6. U-TYPE LUI INSTRUCTION (OP_LUI)
                // ----------------------------------------------------
                6: begin
                    Instruction[6:0]   = OP_LUI;
                    tmp_rd             = $urandom_range(31, 0);
                    Instruction[11:7]  = tmp_rd;
                   
                    imm20_val          = $urandom;
                    Instruction[31:12] = imm20_val;
                    tmp_imm            = {imm20_val, 12'b0}; 
                    
                    #1;
                    
                    $write("Run %02d [LUI]: ", i_test_run);
                    if (rd !== tmp_rd) begin $write("RD mismatch (Exp: %05b, Got: %05b) | ", tmp_rd, rd); match = 0; end
                    if (imm !== tmp_imm) begin $write("IMM mismatch (Exp: %032b, Got: %032b) | ", tmp_imm, imm); match = 0; end
                end
                
                // ----------------------------------------------------
                // 7. U-TYPE AUIPC INSTRUCTION (OP_AUIPC)
                // ----------------------------------------------------
                7: begin
                    Instruction[6:0]   = OP_AUIPC;
                    tmp_rd             = $urandom_range(31, 0);
                    Instruction[11:7]  = tmp_rd;
                    
                    imm20_val          = $urandom;
                    Instruction[31:12] = imm20_val;
                    tmp_imm            = {imm20_val, 12'b0};
                    
                    #1;
                    
                    $write("Run %02d [AUIPC]: ", i_test_run);
                    if (rd !== tmp_rd) begin $write("RD mismatch (Exp: %05b, Got: %05b) | ", tmp_rd, rd); match = 0; end
                    if (imm !== tmp_imm) begin $write("IMM mismatch (Exp: %032b, Got: %032b) | ", tmp_imm, imm); match = 0; end
                end
                
                // ----------------------------------------------------
                // 8. UJ-TYPE JAL INSTRUCTION (OP_JAL)
                // ----------------------------------------------------
                8: begin
                    Instruction[6:0]   = OP_JAL;
                    tmp_rd             = $urandom_range(31, 0);
                    Instruction[11:7]  = tmp_rd;
                    
                    imm21_val          = $urandom;
                    Instruction[31]    = imm21_val[20];
                    Instruction[30:21] = imm21_val[10:1];
                    Instruction[20]    = imm21_val[11];
                    Instruction[19:12] = imm21_val[19:12];
                    
                    tmp_imm            = {{11{imm21_val[20]}}, imm21_val[20:0]};
                    tmp_imm[0]         = 0;     // Assumed due to addresses in RISC_V are always even
                    
                    #1;
                    
                    $write("Run %02d [JAL]: ", i_test_run);
                    if (rd !== tmp_rd) begin $write("RD mismatch (Exp: %05b, Got: %05b) | ", tmp_rd, rd); match = 0; end
                    if (imm !== tmp_imm) begin $write("IMM mismatch (Exp: %032b, Got: %032b) | ", tmp_imm, imm); match = 0; end
                end
                
                // ----------------------------------------------------
                // 9. I-TYPE JALR INSTRUCTION (OP_JALR)
                // ----------------------------------------------------
                9: begin
                    Instruction[6:0]   = OP_JALR;
                    tmp_rd             = $urandom_range(31, 0);
                    Instruction[11:7]  = tmp_rd;
                    Instruction[14:12] = 3'b000;
                    tmp_rs1            = $urandom_range(31, 0);
                    Instruction[19:15] = tmp_rs1;
                    
                    imm12_val          = $urandom;
                    Instruction[31:20] = imm12_val;
                    tmp_imm            = {{20{imm12_val[11]}}, imm12_val};
                    
                    #1;
                    
                    $write("Run %02d [JALR]: ", i_test_run);
                    if (rd !== tmp_rd) begin $write("RD mismatch (Exp: %05b, Got: %05b) | ", tmp_rd, rd); match = 0; end
                    if (func3 !== 3'b000) begin $write("FUNC3 mismatch (Exp: 000, Got: %03b) | ", func3); match = 0; end
                    if (rs1 !== tmp_rs1) begin $write("RS1 mismatch (Exp: %05b, Got: %05b) | ", tmp_rs1, rs1); match = 0; end
                    if (imm !== tmp_imm) begin $write("IMM mismatch (Exp: %032b, Got: %032b) | ", tmp_imm, imm); match = 0; end
                end
                
                default: begin
                    $display("[ERROR] Unknown opcode category selected.");
                    match = 0;
                end
                
            endcase
            
            // Tally results
            if (match) begin
                $display("[PASS]");
                pass_count++;
            end else begin
                $display("[FAIL]");
                fail_count++;
            end
        end
        
        $display("----------------------------------------");
        $display("TEST SUMMARY: PASSED = %0d / 50, FAILED = %0d / 50", pass_count, fail_count);
        $display("----------------------------------------");
        $finish;
    end
    
endmodule