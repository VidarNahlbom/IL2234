// Can be made into 3 states with no IDLE state, but then it will be continously cycling
// between READ and DONE state, limiting availability if nothing else.
// Read should take 1 cycle, read_en is read, addr is read, next state is READ
// where data is routed internally to the primitive output register, so next state is DONE
// and next rising edge that data is available on data_out, so state is DONE and mem_ready goes high
// DONE will then have to be able to move into all 3 other states. 

// With both a write_en and a read_en, we have to decide which one takes priority incase both are high
// We can also tie a chip_en to ena wire of sram_inst
// because currently it will be reading every cycle no matter what i think

module memory_controller (
    input   logic       clk,
    input   logic       rst_n,
    // Depth of 16384, but word-addressable so addr needs to access 64KiB
    // so clog2(65536) = 16, so 15:0
    input   logic[15:0] addr, 
    input   logic[31:0] data_in, 
    output  logic[31:0] data_out,
    input   logic[3:0]  write_en, // byte-wise write mask, if 0000 then read enable
    input   logic       read_en,
    output  logic       mem_ready
);
    typedef enum logic[1:0] {
        IDLE,
        READ,
        WRITE,
        DONE
    } state_t;
    state_t currenct_state, next_state;

    logic enable, load, co;
    logic [1:0] count; // Counter for when read and write output is ready, so for mem_ready
    // Unsure how long each operation takes, will have to be figured out later

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) count <= 2'b00;
        else if (enable) count <= count + 1;
        else if (load) count <= 2'b00;
    end
    
    assign co = &count; // reduction and
    
    logic [13:0] sram_addr; // clog2(65536) = 16 bits, remove 2 bits because SRAM is word-addressable
    assign sram_addr = addr[15:2];

    SRAM_sv sram_inst (
        .clka(clk), // input wire clka
        .ena(1'b1), // input wire ena
        .wea(write_en), // input wire [3:0] wea
        .addra(sram_addr), // input wire [13:0] addra 
        .dina(data_in), // input wire [31:0] dina
        .douta(data_out) // output wire [31:0] douta
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            currenct_state <= READ;
        end else begin
            currenct_state <= next_state;
        end
    end

    always_comb begin
        next_state = READ;
        mem_ready = 1'b0;
        enable = 1'b0;
        load = 1'b0;

        case(currenct_state)
            READ: begin
                // If any write_en bit is high we go to write state, so reduction or operation is used
                next_state = |write_en ? WRITE : READ;
                // READ DONE mem_ready LOGIC
            end
            WRITE: begin
                next_state = co ? DONE : WRITE; 
