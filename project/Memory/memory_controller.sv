// currently i just have a read_en signal simply because the PDF for milestone 2 has one, but i think
// it is up to us if we want to have it.

// With both a write_en and a read_en, we have to decide which one takes priority incase both are high
// We can also tie a chip_en to ena wire of sram_inst
// currently if any enable signal (even single bit) is high, chip is enabled
// and will either read or write.
// So data out will change when read_en is low but we wrote to somewhere, which is bad

// Read take just 1 rising edge, so if addr and read_en are high on falling edge
// data is available after rising edge
// as far as i can tell writes also take only 1 clock cycle. 

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
    // declaration
    typedef enum logic[1:0] {
        IDLE,
        WAIT,
        DONE
    } state_t;
    state_t currenct_state, next_state;
    
    // Address dividing
    logic [13:0] sram_addr; // clog2(65536) = 16 bits, remove 2 bits because SRAM is word-addressable
    assign sram_addr = addr[15:2];

    // Init of SRAM
    SRAM sram_inst (
        .clka(clk), // input wire clka
        // made chip enable at any enable input
        .ena(read_en), // input wire ena
        .wea(write_en), // input wire [3:0] wea
        .addra(sram_addr), // input wire [13:0] addra 
        .dina(data_in), // input wire [31:0] dina
        .douta(data_out) // output wire [31:0] douta
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            currenct_state <= IDLE;
            // DO WE RESET ALL INTERNALS IN THE SRAM?
        end else begin
            currenct_state <= next_state;
        end
    end

    always_comb begin
        next_state = IDLE;
        mem_ready = 1'b0;

        case(currenct_state)
            IDLE: begin
                // if any en signal is high we change state
                // so make the multi-bit write_en one bit logic 
                // using reductive or, then logical or between both
                if (read_en || |write_en) next_state = WAIT;
                // if all is low, then next state is IDLE, like default so doesnt have to be updated.
            end
            WAIT: begin
                next_state = DONE;
            end
            DONE: begin
                mem_ready = 1'b1;
                // and then same logic as IDLE:
                if (read_en || |write_en) next_state = WAIT;
            end
        endcase
    end
endmodule