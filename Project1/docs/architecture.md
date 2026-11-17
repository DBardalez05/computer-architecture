
# Project 1 - RV32I CPU Architecture

## Overview

For this project, we're building a 32-bit RISC-V CPU in SystemVerilog. It's going to be an unpipelined, multicycle CPU, meaning each instruction takes multiple clock cycles to finish.

We're splitting the CPU into two main parts: the control unit and the datapath.

Brad already gave us `memory.sv`, so we don't have to build the instruction or data memory ourselves.

Our CPU architecture and FSM diagrams are in `cpu_architecture_and_fsm.pdf`. The drawing is an early sketch. **If the drawing and this file disagree, this file is the one we follow.**

### Project Requirements (from `261027_proj1.pdf`)

Due **Tuesday, December 1, 2026, at the start of class**.

| Requirement | How we meet it | Status |
|---|---|---|
| Unpipelined, multicycle, 32-bit RV32I CPU | FSM below, one instruction at a time | done (`control_unit.sv`, `datapath.sv`, `top.sv`) |
| All RV32I instructions except `ecall`, `ebreak`, and CSR instructions (this includes `fence`) | Decoder Table below | done; all three test programs pass |
| Synthesizable SystemVerilog | yosys + nextpnr | synthesis + place & route pass (82% of logic cells, 18 MHz > 12 MHz); not tested on the board yet |
| Must use the provided `memory.sv` | Connections to Brad's Memory below | done |
| Icarus Verilog testbench + simulation results for every class of instruction | Testing section below | done (`tb_first.sv`, `proj1_tb.sv`, `tb_extra.sv`); screenshots for the report still needed |
| Runs a RISC-V assembly program that blinks the LEDs in an interesting way | LED Program section below | not started |
| PDF report: design explanation + simulation results + GitHub URL | Write after the CPU works | not started |
| Source files + testbench submitted, and all members joined the Canvas group | - | not started |

### Our Design Rules

We're keeping the design simple on purpose:

1. **Everything runs on `posedge clk`.** No `negedge` logic. (Brad's demo `top.sv` uses `negedge`, but we're not copying that.)
2. **Decoder outputs depend only on the instruction.** Signals like `alu_op`, `alu_a_sel`, `alu_b_sel`, `imm_sel`, `wb_sel`, and `pc_sel` stay the same for every cycle of one instruction.
3. **Write enables depend only on the FSM state.** Each state turns on at most one or two write enables. This makes the waveforms easy to read.
4. **The PC doesn't change until the last cycle of an instruction.** That way, `pc` and `pc + 4` always belong to the current instruction.

## Who's Doing What

### David - Control Unit
- Instruction decoder
- FSM (controls what happens during each clock cycle)
- Program counter (PC)
- Instruction register
- Branch/jump decisions and PC updates
- Driving `funct3` and `dmem_wren` to Brad's memory
- Helping integrate everything in `top.sv`

### Murray - Datapath
- Register file (x0 through x31)
- ALU
- Immediate generator
- Branch comparator (`rs1_eq_rs2`, `rs1_lt_signed`, `rs1_lt_unsigned`)
- ALU input MUXes
- Writeback MUX
- `alu_out` register (saved ALU result)
- Data-memory address and write-data connections

We'll both work on integration, testing, and debugging.

### Registers That Hold Values Between Cycles

We only need four of these:

| Register | Owner | Written when | Why we need it |
|---|---|---|---|
| `pc` | David | `NEXT_FETCH` | Address of the current instruction |
| `ir` (instruction register) | David | `FETCH_LATCH` | Holds the current instruction for the whole multicycle sequence |
| `alu_out` | Murray | `EXECUTE` | Saves the ALU result before the register file is written (see below) |
| `state` | David | every cycle | FSM state |

Plus the register file itself (Murray), which is written in `WRITEBACK`.

**Why `alu_out` is needed:** For `jalr x1, 0(x1)`, `WRITEBACK` overwrites x1 with PC+4. If `NEXT_FETCH` then used the live ALU output as the jump target, it would compute the target from the *new* x1 and jump to the wrong place. Saving the ALU result at the end of `EXECUTE` avoids this. Every state after `EXECUTE` uses `alu_out`, never the live ALU output.

We don't need A/B registers for rs1/rs2. The register file is read combinationally from `ir`, and nothing changes the registers until `WRITEBACK`, so the values stay stable.

## Control Unit -> Datapath

These are the signals my control unit sends to Murray's datapath to tell it what to do.

| Signal | Bits | Purpose |
|---|---|---|
| `instruction` | 32 | Current instruction (from `ir`); datapath takes rs1/rs2/rd and immediate bits from it |
| `pc` | 32 | Current PC (ALU input A option) |
| `pc_plus_4` | 32 | `pc + 4` (writeback option for `jal`/`jalr`) |
| `alu_op` | 4 | Tells the ALU which operation to perform |
| `alu_a_sel` | 2 | Selects the first ALU input |
| `alu_b_sel` | 1 | Selects the second ALU input |
| `imm_sel` | 3 | Selects the immediate format |
| `reg_write_enable` | 1 | Allows writing to a register |
| `wb_sel` | 2 | Selects which value gets written back |
| `alu_out_write_enable` | 1 | Saves the ALU result into `alu_out` |

### ALU Operations

These are our codes for `alu_op`.

| Code | Operation | Result |
|---|---|---|
| `0000` | ADD | `a + b` |
| `0001` | SUB | `a - b` |
| `0010` | AND | `a & b` |
| `0011` | OR | `a \| b` |
| `0100` | XOR | `a ^ b` |
| `0101` | SLL | `a << b[4:0]` |
| `0110` | SRL | `a >> b[4:0]` |
| `0111` | SRA | `$signed(a) >>> b[4:0]` |
| `1000` | SLT (signed) | `($signed(a) < $signed(b)) ? 1 : 0` |
| `1001` | SLTU (unsigned) | `(a < b) ? 1 : 0` |

These are internal codes we're choosing for our CPU, not actual RISC-V instruction encodings.

Shifts must only use the low 5 bits of `b`. For `srai`, the I-type immediate also contains `0x400` (bit 30 of the instruction), so using all of `b` would give the wrong result.

### ALU Input Selection

`alu_a_sel`:
- `00` = rs1 value
- `01` = PC
- `10` = zero (used by `lui`)
- `11` = unused

`alu_b_sel`:
- `0` = rs2 value
- `1` = immediate

### Writeback Selection

`wb_sel`:
- `00` = `alu_out` (the saved ALU result)
- `01` = `dmem_data_out` (data read from memory)
- `10` = `pc_plus_4`
- `11` = unused

Brad's memory already sign-extends or zero-extends `lb`/`lh`/`lbu`/`lhu` based on `funct3`, so `dmem_data_out` goes straight into the writeback MUX. We don't need our own load-extension logic.

### Immediate Formats

`imm_sel` (with `i` = instruction):

| Code | Format | Value |
|---|---|---|
| `000` | I-type | `{{20{i[31]}}, i[31:20]}` |
| `001` | S-type | `{{20{i[31]}}, i[31:25], i[11:7]}` |
| `010` | B-type | `{{19{i[31]}}, i[31], i[7], i[30:25], i[11:8], 1'b0}` |
| `011` | U-type | `{i[31:12], 12'b0}` |
| `100` | J-type | `{{11{i[31]}}, i[31], i[19:12], i[20], i[30:21], 1'b0}` |

We need to use the same codes on both sides. Otherwise, our modules might interpret the signals differently even if everything compiles.

### Register File

- 32 registers, 32 bits each.
- Two combinational read ports: `rs1 = instruction[19:15]`, `rs2 = instruction[24:20]`.
- One write port, written on `posedge clk` when `reg_write_enable` is 1. `rd = instruction[11:7]`.
- x0 always reads as zero, and writes to x0 are ignored.
- All registers start at 0 (initial values) so simulation waveforms don't show X.

## Datapath -> Control Unit

These are the values Murray's datapath sends back to my control unit.

| Signal | Bits | Purpose |
|---|---|---|
| `alu_out` | 32 | Saved ALU result; used as the jump/branch target |
| `rs1_eq_rs2` | 1 | Whether rs1 and rs2 have equal values |
| `rs1_lt_signed` | 1 | Whether rs1 is less than rs2 (signed) |
| `rs1_lt_unsigned` | 1 | Whether rs1 is less than rs2 (unsigned) |

The comparator is separate from the ALU, so during a branch the ALU can calculate the target (PC + imm) while the comparator checks the condition.

## Connections to Brad's Memory

| Memory port | Connected to | Owner |
|---|---|---|
| `imem_address[31:0]` | `pc` | David |
| `imem_data_out[31:0]` | input to `ir` | David |
| `dmem_address[31:0]` | `alu_out` | Murray |
| `dmem_data_in[31:0]` | rs2 value (unshifted; memory picks the byte lanes itself) | Murray |
| `dmem_data_out[31:0]` | writeback MUX input `01` | Murray |
| `dmem_wren` | 1 only in `MEM_WRITE` | David |
| `funct3[2:0]` | `instruction[14:12]` | David |
| `reset` | **not used** (Brad's memory always drives it to 1) | - |
| `led`, `red`, `green`, `blue` | top-level LED pins (inverted, like the demo) | both |

Memory map:
- Data RAM: `0x0000` to `0x0FFF`
- Instruction memory: `0x1000` to `0x1FFF` (read-only)
- LED PWM register: `0xFFFFFFFC` (R/W; byte 3 = user LED, byte 2 = red, byte 1 = green, byte 0 = blue)
- Millisecond timer: `0xFFFFFFF8` (read-only)
- Microsecond timer: `0xFFFFFFF4` (read-only)

We assume loads and stores are aligned (words on 4-byte boundaries, halfwords on 2-byte boundaries). We don't handle misaligned accesses.

### Memory Timing

Brad's memory reads are synchronous: memory captures the address on a rising clock edge, and the data shows up **after** that edge.

Since our CPU also updates on `posedge clk`, the rule is:

> Whatever address we output during cycle N, the data appears during cycle N+1.

Rules that follow from this:
- **Instruction fetch:** `pc` is the address during `FETCH`. The instruction is valid during `FETCH_LATCH`, and `ir` captures it at the end of `FETCH_LATCH`.
- **Loads:** `alu_out` (the address) is valid during `MEM_READ`. The data is valid during `WRITEBACK`.
- **Keep `dmem_address` stable until the load result is written.** Brad's memory uses the *live* address to choose between RAM and peripherals (`is_dmem`), so changing the address too early changes the data. Since `dmem_address = alu_out` and `alu_out` only changes in `EXECUTE`, this is automatically true.
- **Stores:** address, data, `funct3`, and `dmem_wren = 1` are all set during `MEM_WRITE`. The write happens at the end of `MEM_WRITE`.
- **`dmem_wren` must be 0 in every other state.** Otherwise, we could write garbage into RAM or the LED register.

## PC Updates

- The PC starts at `0x1000` (initial value).
- The PC changes **only** in `NEXT_FETCH`, which is the last cycle of every instruction.
- `pc_plus_4 = pc + 4` is computed by the control unit and shared with the datapath.

```
pc_sel  = is_jal | is_jalr | (is_branch & branch_taken)
next_pc = pc_sel ? {alu_out[31:1], 1'b0} : pc_plus_4
```

Clearing bit 0 is required for `jalr`. For branches and `jal`, bit 0 is already 0, so we can clear it every time and don't need a special case.

### Branch Decision

`branch_taken` uses `funct3 = instruction[14:12]`:

| funct3 | Instruction | `branch_taken` |
|---|---|---|
| `000` | `beq` | `rs1_eq_rs2` |
| `001` | `bne` | `!rs1_eq_rs2` |
| `100` | `blt` | `rs1_lt_signed` |
| `101` | `bge` | `!rs1_lt_signed` |
| `110` | `bltu` | `rs1_lt_unsigned` |
| `111` | `bgeu` | `!rs1_lt_unsigned` |
| other | invalid | `0` (not taken) |

## Decoder Table

The decoder looks at `opcode = instruction[6:0]`. These outputs are the same for every cycle of the instruction.

| Instruction | opcode | `alu_a_sel` | `alu_b_sel` | `imm_sel` | `alu_op` | `wb_sel` | `pc_sel` |
|---|---|---|---|---|---|---|---|
| R-type ALU (`add`, `sub`, ...) | `0110011` | rs1 | rs2 | - | from funct3/funct7 | `alu_out` | 0 |
| I-type ALU (`addi`, `srai`, ...) | `0010011` | rs1 | imm | I | from funct3 | `alu_out` | 0 |
| `lui` | `0110111` | zero | imm | U | ADD | `alu_out` | 0 |
| `auipc` | `0010111` | PC | imm | U | ADD | `alu_out` | 0 |
| `jal` | `1101111` | PC | imm | J | ADD | `pc_plus_4` | 1 |
| `jalr` | `1100111` | rs1 | imm | I | ADD | `pc_plus_4` | 1 |
| Branches | `1100011` | PC | imm | B | ADD | - | `branch_taken` |
| Loads | `0000011` | rs1 | imm | I | ADD | mem | 0 |
| Stores | `0100011` | rs1 | imm | S | ADD | - | 0 |
| `fence` | `0001111` | - | - | - | - | - | 0 (does nothing) |
| Anything else | - | goes to `HALT` | | | | | |

"Anything else" includes `0x00000000` (empty instruction memory) and `ecall`/`ebreak`/CSR instructions (opcode `1110011`), which we don't need to implement.

### `alu_op` for R-type and I-type ALU Instructions

| funct3 | R-type | I-type |
|---|---|---|
| `000` | ADD, or SUB if `instruction[30] = 1` | **always ADD** (`addi`) |
| `001` | SLL | SLL (`slli`) |
| `010` | SLT | SLT (`slti`) |
| `011` | SLTU | SLTU (`sltiu`) |
| `100` | XOR | XOR (`xori`) |
| `101` | SRL, or SRA if `instruction[30] = 1` | SRL (`srli`), or SRA (`srai`) if `instruction[30] = 1` |
| `110` | OR | OR (`ori`) |
| `111` | AND | AND (`andi`) |

**Watch out:** for `addi`, bit 30 belongs to the immediate (for example, `addi x1, x1, -1` has bit 30 = 1). Only check `instruction[30]` for R-type `000`/`101` and I-type `101`. Otherwise, `addi` with a negative immediate would turn into SUB.

`sltiu` compares against the sign-extended immediate as an unsigned number. That's what the RISC-V spec says, and our ALU already does this with SLTU.

## FSM

### States

| State | What happens | Write enables that are 1 |
|---|---|---|
| `FETCH` | `imem_address = pc`; memory reads at the end of this cycle | none |
| `FETCH_LATCH` | Instruction is valid on `imem_data_out`; save it | `ir_write_enable` |
| `DECODE` | Decoder and register file read settle. If the opcode is invalid, go to `HALT` | none |
| `EXECUTE` | ALU calculates; save the result | `alu_out_write_enable` |
| `MEM_READ` | `dmem_address = alu_out`; memory reads at the end of this cycle | none |
| `MEM_WRITE` | Store happens at the end of this cycle | `dmem_wren` |
| `WRITEBACK` | Write the `wb_sel` value into `rd` | `reg_write_enable` |
| `NEXT_FETCH` | Update the PC (`next_pc`) | `pc_write_enable` |
| `HALT` | Stop. Stay here forever | none |

Any write enable not listed for a state is 0 in that state.

### State Order

Every instruction starts with `FETCH -> FETCH_LATCH -> DECODE -> EXECUTE` and ends with `NEXT_FETCH -> FETCH`.

| Instruction type | After `EXECUTE` | Total cycles |
|---|---|---|
| ALU (R-type, I-type, `lui`, `auipc`) | `WRITEBACK -> NEXT_FETCH` | 6 |
| `jal`, `jalr` | `WRITEBACK -> NEXT_FETCH` | 6 |
| Loads | `MEM_READ -> WRITEBACK -> NEXT_FETCH` | 7 |
| Stores | `MEM_WRITE -> NEXT_FETCH` | 6 |
| Branches | `NEXT_FETCH` | 5 |
| `fence` | `NEXT_FETCH` | 5 |
| Invalid opcode | (`DECODE` goes straight to `HALT`) | - |

`jal`/`jalr` go through `WRITEBACK` to save PC+4, just like in the drawing. The drawing's "Next Fetch" box is our `NEXT_FETCH` state.

`DECODE` doesn't write anything except when it jumps to `HALT`. We keep it because a separate decode cycle makes the waveforms easier to follow and gives the combinational logic plenty of time.

### Startup

We don't use a reset signal. (Brad's memory always drives `reset` to 1, so it isn't useful.) Instead, we use initial values, like the demo `top.sv` does:

- `pc = 32'h1000`
- `state = FETCH`
- `ir = 0`, `alu_out = 0`, all registers = 0

The FPGA loads these values when it's programmed, and Icarus Verilog uses them in simulation.

### Why `HALT`?

After the last instruction of a test program, instruction memory is filled with `0x00000000`, which is not a valid instruction. Without `HALT`, the CPU would keep running random behavior. With `HALT`, the testbench can wait for `state == HALT` and then check the registers. The real LED program will end in an infinite loop, so it never reaches `HALT`.

## Source Files

| File | Owner | Contents |
|---|---|---|
| `control_unit.sv` | David | decoder, FSM, `pc`, `ir`, branch decision, `next_pc` |
| `datapath.sv` | Murray | register file, ALU, immediate generator, comparator, `alu_out`, MUXes |
| `top.sv` | both | connects the control unit, datapath, and `memory`; parameter `IMEM_FILE` picks the program |
| `tb_first.sv` | both | testbench for `test_first` (x3 = 12) |
| `proj1_tb.sv` | both | testbench for Brad's `rv32i_test` |
| `tb_extra.sv` | both | testbench for `test_extra` |
| `test_first*.txt`, `test_extra.s`, `test_extra*.txt` | both | our test programs (hex padded to 1024 lines, split with `split_memhfile.py`) |

Each testbench runs until the CPU reaches `HALT`, prints every instruction as it executes, then prints PASS/FAIL for each register and `ALL TESTS PASSED` at the end.

**Important:** the `Makefile` only gives yosys `top.sv`, and `proj1_tb.sv` only does `` `include "top.sv" ``. So `top.sv` must `` `include `` our new files, the same way it already includes `memory.sv`:

```systemverilog
`include "memory.sv"
`include "control_unit.sv"
`include "datapath.sv"
```

To run the simulation (from inside `Project1/`, because the memory init files use relative paths):

```sh
iverilog -g2012 -o proj1.vvp proj1_tb.sv
vvp proj1.vvp
gtkwave proj1.vcd
```

`-g2012` is needed because the code uses SystemVerilog (`logic`, `always_ff`, `unique case`). The OSS CAD Suite environment has to be loaded first, or `iverilog` won't be found.

## Testing

### First Test

```asm
addi x1, x0, 5      # 00500093
addi x2, x0, 7      # 00700113
add  x3, x1, x2     # 002081b3
```

Expected result: x1 = 5, x2 = 7, x3 = 12, then the CPU reaches `HALT` (the next word is `0x00000000`).

To run it: put the three hex words in a `.txt` file, one per line, **padded with `00000000` up to 1024 lines**, and split it with `split_memhfile.py`. Brad's memory doesn't fill missing lines with zeros, so without padding the rest of instruction memory is X in simulation.

### Full Test (`rv32i_test.txt`)

Use the provided hex files (`rv32i_test0.txt` to `rv32i_test3.txt`), not a re-assembled `rv32i_test.s` (see Starter File Notes). The program ends at `0x1088` and hits `0x00000000` at `0x108C`, so the CPU should end in `HALT` with:

| Reg | Expected | Reg | Expected |
|---|---|---|---|
| x1 | `FEDCBA98` | x13 | `00001038` |
| x2 | `0FEDCBA9` | x14 | `00001060` |
| x3 | `FFEDCBA9` | x15 | `00000000` |
| x4 | `00123456` | x16 | `00001048` |
| x5 | `00000002` | x17 | `000000C0` |
| x6 | `00123458` | x18 | `C0C0C0C0` |
| x7 | `00000002` | x19 | microsecond timer (changes) |
| x8 | `0048D158` | x20 | `FFFFC0C0` |
| x9 | `0048D15F` | x21 | `0000C0C0` |
| x10 | `12346028` | x22 | `FFFFFFC0` |
| x11 | `00000001` | x23 | `000000C0` |
| x12 | `00000000` | | |

The LED register (`0xFFFFFFFC`) should also be `C0C0C0C0`.

The testbench should wait for `HALT` and then print or check these registers through hierarchical names. Remember to give it enough simulation time.

### Instructions Not Covered by `rv32i_test`

The project requires representative examples of **every** class of RV32I instruction. Brad's test doesn't use: `sw`, `sh`, `bne`, `bge`, `bgeu`, `and`, `andi`, `or`, `xor`, `srl`, `sra`, `slli`, `slti`, `sltiu`, `fence`. `test_extra.s` covers all of these. It also checks RAM stores/loads (`0x100`-`0x107`), a write to x0 being ignored, and `jalr x19, 13(x19)`, where rd == rs1 and the target has bit 0 set. That last case makes sure we really use `alu_out` and really clear bit 0.

### Simulation Results for the Report

The report needs proof for every class of instruction: ALU register-register, ALU immediate, `lui`/`auipc`, loads, stores, branches, jumps, and `fence`. For each test program, we'll save:
- the testbench output that prints/checks the final registers (PASS/FAIL per register), and
- one GTKWave screenshot showing the FSM states for at least one instruction of each class.

## LED Program

This is a **required** part of the project, not an extra.

Plan: a short program that runs forever and fades or cycles the RGB LED.

- Write the LED register with `sw rX, -4(x0)`. The 12-bit immediate `-4` sign-extends to `0xFFFFFFFC`, so we don't need to build the address. Byte 3 is the user LED, byte 2 is red, byte 1 is green, and byte 0 is blue (0 = off, 255 = full brightness).
- For delays, read the millisecond timer with `lw rX, -8(x0)` (`0xFFFFFFF8`) and loop until enough time has passed. Don't use counting loops for timing, because their speed depends on how many cycles each instruction takes.
- The program must end in an infinite loop (`jal x0, loop`) so it never reaches `HALT`.
- Assemble it into one 32-bit hex word per line, pad it to 1024 lines with `00000000`, and split it with `split_memhfile.py`. Then change `IMEM_INIT_FILE_PREFIX` in `top.sv`. Only use PC-relative branches and jumps, so it doesn't matter what start address the assembler assumes.
- Test it in simulation first by reading the `leds` register inside `memory`, then run `make build` and `make prog` on the board.

## Starter File Notes

Problems we found in the provided files:

- **`Makefile`**: `pcf_file = ../common/iceBlinkPico.pcf`, but there's no `common/` folder in our repo, so `make build` fails. Before building for the FPGA, copy `iceBlinkPico.pcf` from `MP3/` into `Project1/` (and change the path), or create `common/`.
- **`rv32i_test.s` comments have wrong PCs:**
  - `addi x15, x0, 10` says `pc = 0x0138`; it's actually `0x1038`.
  - `lw x18` says `pc = 0x1070`, but that's the address of the last `sb`. The real addresses are `lw x18` = `0x1074`, `lw x19` = `0x1078`, `lh` = `0x107C`, `lhu` = `0x1080`, `lb` = `0x1084`, `lbu` = `0x1088`.
  - The register values in the comments are correct.
- **`rv32i_test.s` can't be re-assembled as-is.** The three empty comment lines at `0x1050`-`0x1058` are `0x00000000` words in the hex file, but an assembler wouldn't create them, so every address after them would shift and `jal x13, 0x28` would land in the wrong place. Also, `addi x1, x1, 0xA98` is out of range for a 12-bit signed immediate. Use the provided hex files.
- **`top.sv`** is only Brad's LED color demo. We'll replace its contents with our CPU, keeping the same ports and the `memory` instance.

## Design Decisions

### Decided

- [x] CPU split into control unit and datapath
- [x] Signal names and widths
- [x] ALU operation codes
- [x] MUX selection codes
- [x] Immediate format codes and bit layouts
- [x] PC starts at 0x1000
- [x] Register x0 always reads as zero; writes to x0 are ignored
- [x] All logic on `posedge clk`
- [x] Memory timing (address in cycle N, data in cycle N+1)
- [x] PC only updates in `NEXT_FETCH`
- [x] `alu_out` register saved in `EXECUTE`
- [x] Final FSM states, including `HALT`
- [x] Startup uses initial values (no reset signal)
- [x] `fence` does nothing; invalid opcodes go to `HALT`
- [x] First simulation goal: x3 = 12

Murray still needs to review the interface before we treat it as final.

### Still Open

- [x] How we're organizing the simulation tests (one testbench per program)
- [x] Extra test program for the instructions `rv32i_test` doesn't cover (`test_extra.s`)
- [ ] The LED program itself (required; see LED Program)
- [ ] How to assemble our own programs (a RISC-V assembler, or by hand for short programs)

## Schedule (Due December 1)

| Dates | Goal |
|---|---|
| Tue Nov 17 | Meeting: Murray reviews and approves the interface; both start writing modules |
| Nov 17 - 20 | Each module written and tested by itself; `top.sv` connects everything; first test passes (x3 = 12) |
| Nov 21 - 23 | `rv32i_test` passes with all expected register values; extra test for the instructions it doesn't cover |
| Nov 24 - 27 | LED program works in simulation, then `make build` / `make prog` on the board (Thanksgiving is Nov 26) |
| Nov 28 - 30 | Report PDF with simulation results and the GitHub URL; join the Canvas group |
| Tue Dec 1 | Submit before class |

## Next Meeting - Tuesday, November 17

### David Goal
- Implement the instruction decoder
- Implement PC logic and the instruction register
- Implement the FSM
- Run basic tests on my modules

### Murray's Goal
- Register file
- ALU
- Immediate generator
- Branch comparator and `alu_out` register
- Basic tests for his modules

On Tuesday, we'll review what each of us has finished, resolve any interface issues, and start connecting everything.

The goal isn't to have the entire CPU working by Tuesday. We just want both sections to be ready for integration.
