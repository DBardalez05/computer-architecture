
# Project 1 - RV32I CPU Architecture

## Overview

For this project, we're building a 32-bit RISC-V CPU in SystemVerilog. It's going to be an unpipelined, multicycle CPU, meaning each instruction takes multiple clock cycles to finish.

We're splitting the CPU into two main parts: the control unit and the datapath.

Brad already gave us `memory.sv`, so we don't have to build the instruction or data memory ourselves.

Our CPU architecture and FSM diagrams are in `cpu_architecture_and_fsm.pdf`.

## Who's Doing What

### David - Control Unit
- Instruction decoder
- FSM (controls what happens during each clock cycle)
- Program counter (PC)
- Instruction register
- Branch/jump decisions and PC updates
- Helping integrate everything in `top.sv`

### Murray - Datapath
- Register file (x0 through x31)
- ALU
- Immediate generator
- ALU input MUXes
- Writeback MUX
- Data-memory address and write-data connections
- Intermediate datapath registers, if needed

We'll both work on integration, testing, and debugging.

### Intermediate Registers

Since this is a multicycle CPU, we might need to save some intermediate values between clock cycles.

For now, we're splitting these responsibilities as follows:

- David handles the PC register and instruction register.
- Murray handles registers for intermediate datapath values, such as a saved ALU result.
- We'll determine exactly which additional registers are needed as we work through the FSM timing.
- We should avoid having both sections create separate registers to store the same value.

## Control Unit -> Datapath

These are the signals my control unit sends to Murray's datapath to tell it what to do.

| Signal | Bits | Purpose |
|---|---|---|
| `alu_op` | 4 | Tells the ALU which operation to perform |
| `alu_a_sel` | 2 | Selects the first ALU input |
| `alu_b_sel` | 1 | Selects the second ALU input |
| `imm_sel` | 3 | Selects the immediate format |
| `reg_write_enable` | 1 | Allows writing to a register |
| `wb_sel` | 2 | Selects which value gets written back |
| `alu_out_write_enable` | 1 | Saves the ALU result if we use an intermediate result register |

### ALU Operations

These are our proposed codes for `alu_op`.

| Code | Operation |
|---|---|
| `0000` | ADD |
| `0001` | SUB |
| `0010` | AND |
| `0011` | OR |
| `0100` | XOR |
| `0101` | SLL |
| `0110` | SRL |
| `0111` | SRA |
| `1000` | SLT (signed) |
| `1001` | SLTU (unsigned) |

These are internal codes we're choosing for our CPU, not actual RISC-V instruction encodings.

### ALU Input Selection

`alu_a_sel`:
- `00` = rs1
- `01` = PC
- `10` = zero
- `11` = unused for now

`alu_b_sel`:
- `0` = rs2
- `1` = immediate

### Writeback Selection

`wb_sel`:
- `00` = ALU result (saved result if we're using an ALU output register)
- `01` = data read from RAM
- `10` = PC + 4
- `11` = unused for now

### Immediate Formats

`imm_sel`:
- `000` = I-type
- `001` = S-type
- `010` = B-type
- `011` = U-type
- `100` = J-type

We need to use the same codes on both sides. Otherwise, our modules might interpret the signals differently even if everything compiles.

## Datapath -> Control Unit

These are the values Murray's datapath sends back to my control unit.

| Signal | Bits | Purpose |
|---|---|---|
| `alu_result` | 32 | Result of the ALU calculation or a calculated address |
| `rs1_eq_rs2` | 1 | Whether rs1 and rs2 have equal values |
| `rs1_lt_signed` | 1 | Whether rs1 is less than rs2 (signed) |
| `rs1_lt_unsigned` | 1 | Whether rs1 is less than rs2 (unsigned) |

I need the comparison signals for branch instructions like `beq`, `bne`, `blt`, and `bge`.

For example, if we're executing `beq` and `rs1_eq_rs2` is 1, the control unit will select the branch target for the PC.

The ALU result can also provide addresses for loads, stores, branches, and jumps.

## PC and Instruction Register

The PC starts at `0x1000`, since that's where Brad's instruction memory begins.

Normally, the PC advances by 4 bytes per instruction. For taken branches and jumps, we need to use the calculated target address instead.

Signals I'll be using internally:

| Signal | Purpose |
|---|---|
| `pc_write_enable` | Allows the PC to update |
| `pc_sel` | Selects PC+4 or a branch/jump target |
| `ir_write_enable` | Saves the fetched instruction |
| `branch_taken` | Whether a branch condition was met |

The instruction register holds the current 32-bit instruction while the CPU processes it.

Murray's datapath also needs:
- `pc[31:0]`
- `instruction[31:0]`

For `jalr`, we have to clear bit 0 of the jump target.

For `jal` and `jalr`, we also have to save the original PC+4 into the destination register as the return address.

We still need to finalize exactly when the PC updates so that it remains correct throughout multicycle execution.

## Brad's Memory

We're using the provided `memory.sv` for both instruction and data memory.

| Signal | Purpose |
|---|---|
| `imem_address[31:0]` | Address of the instruction we want |
| `imem_data_out[31:0]` | Instruction returned by memory |
| `dmem_address[31:0]` | Address used for loads/stores |
| `dmem_data_in[31:0]` | Value we're storing |
| `dmem_data_out[31:0]` | Value loaded from memory |
| `dmem_wren` | Enables a memory write |
| `funct3[2:0]` | Determines the load/store type |

Memory ranges:
- Instruction memory: `0x1000` to `0x1FFF`
- Data RAM: `0x0000` to `0x0FFF`

Brad's memory also includes memory-mapped LED outputs and timers, which we'll use later.

### Memory Timing

One important detail is that Brad's memory reads are synchronous, meaning they happen on clock edges.

Because of this:
- The FSM needs to allow time for an instruction to be read before capturing it.
- Loads need to wait until the memory output is valid before writing the value into a register.
- Stores must have the correct address, data, and write enable ready for the memory clock edge.

We'll work out the exact timing when implementing the FSM.

## FSM Plan

Our initial instruction sequence is:

FETCH -> FETCH_LATCH -> DECODE -> EXECUTE

After EXECUTE, the path depends on the instruction:

| Instruction type | Next steps |
|---|---|
| ALU instructions | WRITEBACK -> FETCH |
| Loads | MEMORY READ -> WRITEBACK -> FETCH |
| Stores | MEMORY WRITE -> FETCH |
| Branches | Update PC -> FETCH |
| JAL/JALR | Update PC and save PC+4 -> FETCH |

This is our conceptual FSM, not the final clock-by-clock implementation.

We might need additional states for memory timing, and we'll decide exactly where the PC updates.

## First Test Goal

Our first goal is to get the CPU to execute something simple:

```asm
addi x1, x0, 5
addi x2, x0, 7
add  x3, x1, x2
```

Expected result: x3 = 12.

After this works, we'll continue with the remaining RV32I instructions, including loads, stores, branches, and jumps.

## Design Decisions

### Already Proposed

- [x] CPU split into control unit and datapath
- [x] Signal names and widths
- [x] ALU operation codes
- [x] MUX selection codes
- [x] Immediate format codes
- [x] PC starts at 0x1000
- [x] Register x0 always reads as zero
- [x] Initial FSM diagram
- [x] Intermediate register responsibilities
- [x] First simulation goal: x3 = 12

These are our proposed design choices. Murray still needs to review the interface before we treat it as finalized.


### Finalize During Implementation

- [ ] Exact memory read/write timing
- [ ] Exact PC update timing
- [ ] Initialization/reset behavior
- [ ] Final FSM states
- [ ] How we're organizing the simulation tests

## Next Meeting - Tuesday, November 17

### David Goal
- Implement the instruction decoder
- Implement initial PC logic
- Implement the first FSM states
- Run basic tests on my modules

### Murray's Goal
- Register file
- ALU
- Immediate generator
- Basic tests for his modules

On Tuesday, we'll review what each of us has finished, resolve any interface issues, and start connecting everything.

The goal isn't to have the entire CPU working by Tuesday. We just want both sections to be ready for integration.
