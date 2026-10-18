# Hello
this repo is use by Project **Group 16** in order to coordinate work amongst peers for the course **IL2234** "Digital Systems Design and Verification using Hardware Description Language".
There is also a Whattsapp group used for communication.

## Organization
**Admin:** Vidar Nahlbom, vidarcn@kth.se

**Member**: Matyas Krejci, krejci@kth.se

**Member**: Krithika Suresh, ksur@kth.se

*TODO*: Add remaining members email.

## Components
The follwoing chapter contains pinouts and descriptions of each of the following components to serve as a reftrence document for each of the CPU components.

### ALU

#### Module description

The `ALU` (Arithmetic Logic Unit) module is a fully combinational component designed to perform core arithmetic, logical, and shift operations for a RISC-V processor core. The data width is parameterized via `BW` (typically set to 32 for RV32I implementations).

It evaluates a 4-bit operational selector (`opcode`) to execute operations including signed/unsigned addition, subtraction, bitwise logic (AND, OR, XOR), logical and arithmetic shifts, set-less-than comparisons (`SLT`, `SLTU`), and a passthrough mode. Shift amounts are dynamically constrained using `$clog2(BW)` bits from input `in_b`.

In addition to computing the main result (`out`), the module continuously evaluates and outputs status flags via the 3-bit `flags` vector:

* **Overflow (`flags[2]`):** Indicates signed arithmetic overflow for addition and subtraction based on MSB sign transitions.
* **Negative (`flags[1]`):** Reflects the sign bit (MSB) of the generated output.
* **Zero (`flags[0]`):** Evaluates whether the computed result is zero using a bitwise reduction NOR operator.

---

#### Interface Pinout Table

| Pin Name | Direction | Bit Width | Description |
| --- | --- | --- | --- |
| `BW` | Parameter | — | Data bit width parameter (e.g., 32 for 32-bit architecture). |
| `in_a` | Input | `BW` | Primary operand A (source data / base register value). |
| `in_b` | Input | `BW` | Secondary operand B (source data, immediate value, or shift amount). |
| `opcode` | Input | 4 bits | Operation selection code controlling the active ALU function. |
| `out` | Output | `BW` | Computed result of the selected ALU operation. |
| `flags` | Output | 3 bits | Status flags vector: `flags[2]` = Overflow, `flags[1]` = Negative, `flags[0]` = Zero. |

#### Testing
Testing is preformed using one of the three test benches
* **ALU_Exhaustive_TestBench.sv**
* **ALU_TestBench_source.sv**
* **ALU_tb.sv**

### Register

#### 1. `register_block` Module

The `register_block` module represents a single parameterizable $D$ flip-flop-based register designed to store data of width `BW`. It handles synchronous state storage with an asynchronous active-low reset (`rst_n`).

* **Sequential Behavior:** State updates occur on the rising edge of the clock (`posedge clk`).
* **Active-Low Write Enable (`write_en_n`):** New data (`data_in`) is sampled into the register only when `write_en_n` is driven LOW.
* **Asynchronous Reset (`rst_n`):** Overrides all operations to clear the output `out` to zero immediately upon falling edge detection.

---

#### 2. `register_file` Module

The `register_file` module acts as a multi-port register array simulating the register bank of a RISC-V core. It instantiates `DEPTH - 1` instances of `register_block` using a `generate` loop to form an addressable register set parameterized by data width (`BW`) and register depth (`DEPTH`).

* **Hardwired Zero Register:** Register index `0` (`outputs[0]`) is hardwired to zero (`'b0`) to comply with RISC-V architectural specifications for register `x0`.
* **Asynchronous Multi-Port Read:** Features two independent read ports (`read_addr_1`, `read_addr_2`) driving combinational outputs (`data_out_1`, `data_out_2`).
* **Synchronous Write Routing:** Decodes `write_addr` to select and route an active-low write signal (`write_enables[write_addr] = 1'b0`) to a specific register block when global write enable (`write_en_n`) is active.
* **Chip Enable & Standby (`chip_en`):** Disabling `chip_en` or asserting reset (`rst_n`) combinationally forces both output data ports to zero.

---


#### `register_block` Pinout Table

| Pin Name | Direction | Bit Width | Description |
| --- | --- | --- | --- |
| `BW` | Parameter | — | Parameter defining the register data bit width. |
| `clk` | Input | 1 bit | Master clock input signal; triggers sequential state updates on rising edge. |
| `rst_n` | Input | 1 bit | Asynchronous active-low reset signal; forces `out` to zero when LOW. |
| `write_en_n` | Input | 1 bit | Active-low write enable signal; permits `data_in` sampling when LOW. |
| `data_in` | Input | `BW` | Parallel data input bus sampled on clock edge when enabled. |
| `out` | Output | `BW` | Stored register output data bus. |

---

#### `register_file` Pinout Table

| Pin Name | Direction | Bit Width | Description |
| --- | --- | --- | --- |
| `BW` | Parameter | — | Data width parameter for stored register values (default: 4). |
| `DEPTH` | Parameter | — | Total count of addressable registers in the file (default: 15). |
| `clk` | Input | 1 bit | Master clock input signal driving internal register blocks. |
| `rst_n` | Input | 1 bit | Asynchronous active-low reset signal; resets internal registers and clears outputs. |
| `write_en_n` | Input | 1 bit | Global active-low write enable controlling write port access. |
| `chip_en` | Input | 1 bit | Active-high chip enable signal; gates outputs to zero when inactive. |
| `data_in` | Input | `BW` | Common data input bus routed to the target register during a write operation. |
| `read_addr_1` | Input | `$clog2(DEPTH)` | Target register address for output read port 1. |
| `read_addr_2` | Input | `$clog2(DEPTH)` | Target register address for output read port 2. |
| `write_addr` | Input | `$clog2(DEPTH)` | Target register address for incoming write operations. |
| `data_out_1` | Output | `BW` | Asynchronous read data output bus for Port 1. |
| `data_out_2` | Output | `BW` | Asynchronous read data output bus for Port 2. |

#### Testing
Testing is preformed using `register_file_tb.sv`

### Memory

#### `memory_controller` Module

The `memory_controller` module acts as an interface wrapper around a single-port word-addressable block RAM (`SRAM`) macro on a Xilinx FPGA. It converts a byte-level 16-bit address space into word-aligned memory accesses and provides a handshaking signal (`mem_ready`) to synchronize memory requests with the processor core.

* **Byte-to-Word Address Translation:** Translates a 16-bit byte address (`addr[15:0]`) to a 14-bit word address (`sram_addr[13:0]`) by truncating the lower 2 bits (`addr[15:2]`), addressing a total memory depth of 16,384 32-bit words (64 KiB total byte capacity).
* **Byte-Enabling Writes:** Supports byte-granularity write operations via a 4-bit write mask (`write_en`). Each bit enables writing to its corresponding byte lane of the 32-bit word (`data_in`).
* **Finite State Machine (FSM):** Manages access latencies and generates the `mem_ready` handshake signal across three states:
* **`IDLE`:** Awaits read or write requests.
* **`WAIT`:** Accommodates the 1-clock cycle read latency of the synchronous SRAM macro.
* **`DONE`:** Asserts `mem_ready = 1'b1` when valid read data is available on `data_out` or immediately after a write cycle completes. Back-to-back operations transition directly within `DONE` to maintain high throughput.

---


#### `memory_controller` Pinout Table

| Pin Name | Direction | Bit Width | Description |
| --- | --- | --- | --- |
| `clk` | Input | 1 bit | Master clock input driving FSM state transitions and synchronous SRAM access. |
| `rst_n` | Input | 1 bit | Asynchronous active-low reset signal; resets the controller FSM to `IDLE`. |
| `addr` | Input | 16 bits | Byte-address input bus (`addr[15:0]`); `addr[15:2]` is routed to SRAM as word address. |
| `data_in` | Input | 32 bits | 32-bit write data payload to be stored in memory. |
| `data_out` | Output | 32 bits | 32-bit read data output directly driven by the underlying SRAM macro (`douta`). |
| `write_en` | Input | 4 bits | Byte-wise active-high write enable mask (e.g., `4'b0001` writes byte 0; `4'b0000` for reads). |
| `read_en` | Input | 1 bit | Active-high read request enable signal. |
| `mem_ready` | Output | 1 bit | Handshake output signal; indicates requested read/write access is complete. |

### Controller (`controller`)

#### Description

The `controller` module serves as the primary multi-cycle control unit (Finite State Machine) for the RISC-V processor. It processes instructions by decoding the `opcode`, `func3`, and `func7` fields received from the `Decoder`, along with condition evaluation flags (such as `alu_zero`) from the `ALU`. It manages the execution flow across three FSM states (`Fetch`, `Execute1`, and `Execute2`) and generates datapath control signals to sequence instruction execution:

* **FSM Sequencing:** Coordinates memory wait states during instruction fetch (`Fetch`) and memory load/store operations (`Execute2`) by evaluating `mem_ready` handshakes.


* **ALU & Branch Control:** Determines ALU operations (`alu_opcode`), operand selections (`alu_b_src`), and branch outcomes (`pc_src`) based on conditions like `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, and `BGEU`.


* **Write & Multiplexer Control:** Controls Register File write enables (`rf_write_en_n`), source selection multiplexers (`rf_write_src`), Program Counter updates (`pc_write_en`), Instruction Register loading (`ir_write_en`), and memory access routing (`mem_addr_src`, `mem_read_en`, `mem_write_unit_en`).

---

#### Pinout Table

| Pin Name | Direction | Bit Width | Description |
| --- | --- | --- | --- |
| `clk` | Input | 1 bit | Clock input for FSM state transitions.|
| `rst_n` | Input | 1 bit | Active-low asynchronous reset for FSM. |
| `mem_ready` | Input | 1 bit | Memory controller ready handshake signal. |
| `opcode` | Input | 7 bits | Instruction opcode field from `Decoder`. |
| `func3` | Input | 3 bits | Instruction `func3` field from `Decoder`.
| `func7` | Input | 7 bits | Instruction `func7` field from `Decoder`.
| `alu_zero` | Input | 1 bit | Zero status flag from ALU (`flags[0]`).
| `rf_chip_en` | Output | 1 bit | Register file chip enable control signal.
| `rf_write_en_n` | Output | 1 bit | Active-low write enable signal for Register File.
| `mem_addr_src` | Output | 1 bit | Memory address mux control (0: PC, 1: ALU result).
| `mem_write_unit_en` | Output | 1 bit | Enable control signal for `memory_write_unit`.
| `mem_read_en` | Output | 1 bit | Enable signal for memory read operations.
| `ir_write_en` | Output | 1 bit | Write enable for `instruction_register`.
| `pc_write_en` | Output | 1 bit | Write enable for `program_counter` register.
| `rf_write_src` | Output | 2 bits | RF write-back data mux control (00: ALU, 01: Mem, 10: PC+4, 11: PC+imm).
| `alu_b_src` | Output | 1 bit | ALU operand B mux control (0: `rs2_data`, 1: `imm`).
| `alu_opcode` | Output | 4 bits | Operation selection code driven to ALU.
| `pc_src` | Output | 2 bits | Next PC source mux control (00: PC+4, 01: PC+imm, 10: JALR target).


---

### Decoder (`Decoder`)

#### Description

The `Decoder` module is a combinational instruction decoding unit that parses 32-bit RISC-V instruction words (`data_in`) into architectural instruction fields and immediate values.

* **Field Extraction:** Unpacks bit fields including `opcode`, destination register (`rd`), source registers (`rs1`, `rs2`), and function selectors (`func3`, `func7`).


* **Immediate Generation:** Formats and sign-extends immediate operands (`imm`) according to RISC-V instruction type specifications:


* **I-type / Loads / JALR:** 12-bit sign-extended immediate.


* **U-type (`LUI`, `AUIPC`):** 20-bit upper immediate zero-padded in the lower 12 bits.


* **S-type (Stores):** Reassembled 12-bit split sign-extended immediate.


* **SB-type (Branches):** Reassembled 13-bit sign-extended immediate with `imm[0] = 0`.


* **UJ-type (`JAL`):** Reassembled 21-bit sign-extended immediate with `imm[0] = 0`.


#### Pinout Table

| Pin Name | Direction | Bit Width | Description |
| --- | --- | --- | --- |
| `data_in` | Input | 32 bits | Raw 32-bit instruction word from `instruction_register`. |
| `opcode` | Output | 7 bits | Instruction opcode output (bits [6:0]). |
| `rd` | Output | 5 bits | Destination register index output (bits [11:7]). |
| `func3` | Output | 3 bits | Instruction sub-function code output (bits). |
| `rs1` | Output | 5 bits | Source register 1 index output (bits). |
| `rs2` | Output | 5 bits | Source register 2 index output (bits). |
| `func7` | Output | 7 bits | Instruction extended function code output (bits). |
| `imm` | Output | 32 bits | Extracted and sign-extended immediate payload. |


---

### Instruction Register (`instruction_register`)

#### Description

The `instruction_register` module is a synchronous 32-bit register holding the current instruction word fetched from memory. It updates on the rising edge of `clk` when enabled by `ir_write_en` (asserted by the `controller` when valid memory data is ready) and asynchronously resets to `0x0000_0000` via active-low `rst_n`.

#### Pinout Table

| Pin Name | Direction | Bit Width | Description |
| --- | --- | --- | --- |
| `clk` | Input | 1 bit | System clock input.
| `rst_n` | Input | 1 bit | Active-low asynchronous reset.
| `ir_write_en` | Input | 1 bit | Write enable from `controller`.
| `ir_in` | Input | 32 bits | Read instruction word from memory.
| `ir_out` | Output | 32 bits | Latched instruction word driven to `Decoder`.


---

### Memory Load Unit (`memory_load_unit`)

#### Description

The `memory_load_unit` module is a combinational alignment and sign/zero-extension circuit that formats data loaded from memory before driving the Register File input multiplexer.

* **Byte/Halfword Selection:** Evaluates the lower address bits (`addr_lo = ALU_out[1:0]`) to select the targeted byte lane (`byte_sel`) or halfword lane (`half_sel`) within a 32-bit memory word (`mem_data`).


* **Format Extension:** Uses `func3` to execute byte (`LB`), halfword (`LH`), and word (`LW`) signed extensions, as well as zero-extended unsigned loads (`LBU`, `LHU`).



#### Pinout Table

| Pin Name | Direction | Bit Width | Description |
| --- | --- | --- | --- |
| `mem_data` | Input | 32 bits | Raw 32-bit word read from memory.
| `addr_lo` | Input | 2 bits | Lower 2 bits of target address (`ALU_out[1:0]`) for byte offset.
| `func3` | Input | 3 bits | Load width/sign specification (`LB`, `LH`, `LW`, `LBU`, `LHU`).
| `load_data` | Output | 32 bits | Aligned and sign/zero-extended word output for Register File.


---

### Memory Write Unit (`memory_write_unit`)

#### Description

The `memory_write_unit` module is a combinational alignment unit that formats store data (`rs2_data`) and computes byte-level write enable masks (`write_en`) for memory store operations.

* **Write Mask Generation:** Translates `func3` (`SB`, `SH`, `SW`) and byte offset (`addr_lo = ALU_out[1:0]`) into a 4-bit active-high byte write mask (`write_en`).


* **Lane Replication:** Replicates source byte or halfword values across all byte lanes of `data_out` (e.g., 4x byte replication for `SB`, 2x halfword replication for `SH`) so that memory write controllers can commit byte-masked writes correctly regardless of word offset.



#### Pinout Table

| Pin Name | Direction | Bit Width | Description |
| --- | --- | --- | --- |
| `mem_write` | Input | 1 bit | Master write enable signal from `controller`.
| `addr_lo` | Input | 2 bits | Lower 2 bits of target address (`ALU_out[1:0]`) for byte offset.
| `func3` | Input | 3 bits | Store size specification (`SB`, `SH`, `SW`).
| `rs2_data` | Input | 32 bits | Store payload read from Register File port 2.
| `data_out` | Output | 32 bits | Byte/halfword lane-replicated data bus to memory.
| `write_en` | Output | 4 bits | Byte-wise write enable mask driven to memory controller.

---

### Program Counter (`program_counter`)

#### Description

The `program_counter` module maintains and calculates the 32-bit Instruction Pointer (PC) for the processor.

* **Dedicated Adders:** Continuously computes sequential PC (`pc_plus_4 = pc_out + 4`) and branch target PC (`pc_plus_imm = pc_out + imm`).


* **Next PC Selection (`pc_src`):** Selects `pc_next` from `pc_plus_4` (sequential), `pc_plus_imm` (`JAL` and taken branches), or `{alu_out[31:2], 2'b00}` (`JALR` with 2-bit alignment masking).


* **State Update:** Updates `pc_out` on `posedge clk` when enabled by `pc_write_en`, with asynchronous reset clearing `pc_out` to `0x0000_0000` on `negedge rst_n`.



#### Pinout Table

| Pin Name | Direction | Bit Width | Description |
| --- | --- | --- | --- |
| `clk` | Input | 1 bit | System clock input.
| `rst_n` | Input | 1 bit | Active-low asynchronous reset.
| `pc_write_en` | Input | 1 bit | Write update enable signal from `controller`.
| `pc_src` | Input | 2 bits | Next PC source select signal from `controller`.
| `imm` | Input | 32 bits | Sign-extended branch/jump target immediate from `Decoder`.
| `alu_out` | Input | 32 bits | Calculated jump address from ALU (used for `JALR`).
| `pc_out` | Output | 32 bits | Active Program Counter output address.
| `pc_plus_4` | Output | 32 bits | Incremented PC value (`PC + 4`) for sequential flow/link register.
| `pc_plus_imm` | Output | 32 bits | Target PC value (`PC + imm`) for branch/`JAL`.
