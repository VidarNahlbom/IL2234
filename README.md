# Hello
this repo is use by Project **Group 16** in order to coordinate work amongst peers for the course **IL2234** "Digital Systems Design and Verification using Hardware Description Language".
There is also a Whattsapp group used for communication.

## Organization
**Admin:** Vidar Nahlbom, vidarch@kth.se

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
#### Module Descriptions

##### 1. `register_block` Module

The `register_block` module represents a single parameterizable $D$ flip-flop-based register designed to store data of width `BW`. It handles synchronous state storage with an asynchronous active-low reset (`rst_n`).

* **Sequential Behavior:** State updates occur on the rising edge of the clock (`posedge clk`).
* **Active-Low Write Enable (`write_en_n`):** New data (`data_in`) is sampled into the register only when `write_en_n` is driven LOW.
* **Asynchronous Reset (`rst_n`):** Overrides all operations to clear the output `out` to zero immediately upon falling edge detection.

---

##### 2. `register_file` Module

The `register_file` module acts as a multi-port register array simulating the register bank of a RISC-V core. It instantiates `DEPTH - 1` instances of `register_block` using a `generate` loop to form an addressable register set parameterized by data width (`BW`) and register depth (`DEPTH`).

* **Hardwired Zero Register:** Register index `0` (`outputs[0]`) is hardwired to zero (`'b0`) to comply with RISC-V architectural specifications for register `x0`.
* **Asynchronous Multi-Port Read:** Features two independent read ports (`read_addr_1`, `read_addr_2`) driving combinational outputs (`data_out_1`, `data_out_2`).
* **Synchronous Write Routing:** Decodes `write_addr` to select and route an active-low write signal (`write_enables[write_addr] = 1'b0`) to a specific register block when global write enable (`write_en_n`) is active.
* **Chip Enable & Standby (`chip_en`):** Disabling `chip_en` or asserting reset (`rst_n`) combinationally forces both output data ports to zero.

---

#### Interface Pinout Tables

##### `register_block` Pinout Table

| Pin Name | Direction | Bit Width | Description |
| --- | --- | --- | --- |
| `BW` | Parameter | — | Parameter defining the register data bit width. |
| `clk` | Input | 1 bit | Master clock input signal; triggers sequential state updates on rising edge. |
| `rst_n` | Input | 1 bit | Asynchronous active-low reset signal; forces `out` to zero when LOW. |
| `write_en_n` | Input | 1 bit | Active-low write enable signal; permits `data_in` sampling when LOW. |
| `data_in` | Input | `BW` | Parallel data input bus sampled on clock edge when enabled. |
| `out` | Output | `BW` | Stored register output data bus. |

---

##### `register_file` Pinout Table

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
#### Module Description

###### `memory_controller` Module

The `memory_controller` module acts as an interface wrapper around a single-port word-addressable block RAM (`SRAM`) macro on a Xilinx FPGA. It converts a byte-level 16-bit address space into word-aligned memory accesses and provides a handshaking signal (`mem_ready`) to synchronize memory requests with the processor core.

* **Byte-to-Word Address Translation:** Translates a 16-bit byte address (`addr[15:0]`) to a 14-bit word address (`sram_addr[13:0]`) by truncating the lower 2 bits (`addr[15:2]`), addressing a total memory depth of 16,384 32-bit words (64 KiB total byte capacity).
* **Byte-Enabling Writes:** Supports byte-granularity write operations via a 4-bit write mask (`write_en`). Each bit enables writing to its corresponding byte lane of the 32-bit word (`data_in`).
* **Finite State Machine (FSM):** Manages access latencies and generates the `mem_ready` handshake signal across three states:
* **`IDLE`:** Awaits read or write requests.
* **`WAIT`:** Accommodates the 1-clock cycle read latency of the synchronous SRAM macro.
* **`DONE`:** Asserts `mem_ready = 1'b1` when valid read data is available on `data_out` or immediately after a write cycle completes. Back-to-back operations transition directly within `DONE` to maintain high throughput.

---

#### Interface Pinout Table

##### `memory_controller` Pinout Table

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