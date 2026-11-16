# 8-bit CPU in SystemVerilog

A SystemVerilog remake of my [8-bit CPU in VHDL](https://github.com/Johnyzour/8-bit-cpu):
a simple 8-bit, multi-cycle, von Neumann CPU, verified with self-checking
testbenches in the Vivado simulator (XSIM).

**Status:** under development. Modules are being ported one at a time,
bottom-up, each with its testbench. Every module except the top level
(`cpu`) is done and passes its testbench.

---

## About

The VHDL project is complete. This repository rebuilds the same CPU in
SystemVerilog, starting from its latest version (the `von-neumann` branch,
tag `v1.2-multicycle-von-neumann`).

The design itself (instruction set, datapath, FSM and timing) is the same as
the VHDL version, so its README is the reference for how the CPU works.
What changes is the language: the goal is idiomatic SystemVerilog rather than
a line-by-line translation.

### The CPU in brief

- 8-bit data path, four registers (R0-R3), Z and C flags
- One shared 256 x 8 memory for code, data and the stack (von Neumann)
- 24-bit instructions, 26 of them, fetched one byte per clock
- 6-state FSM: FETCH1, FETCH2, FETCH3, DECODE, EXECUTE, WRITEBACK (5 or 6 clocks per instruction)
- Hardware stack (PUSH, POP, CALL, RET) and register-indirect addressing (LDR, STR)
- Program loaded from a text file (`program.mem`), written in assembly and assembled by `tools/asm.py`

---

## Progress

| Module | RTL | Testbench | Passes at |
|---|---|---|---|
| `mux2` | done | done | 100 ns |
| `wb_mux` | done | done | 60 ns |
| `pc` | done | done | 120 ns |
| `sp` | done | done | 100 ns |
| `flags_reg` | done | done | 90 ns |
| `reg_file` | done | done | 140 ns |
| `ir` | done | done | 110 ns |
| `alu` | done | done | 320 ns |
| `cpu_pkg` | done | - | (package, no testbench) |
| `memory` | done | done | 150 ns |
| `control_unit` | done | done | 1700 ns |
| `cpu` | in progress | - | |

Each testbench checks the same cases as its VHDL counterpart and prints
`all tests completed and passed`, then ends with `$finish`.

---

## Project structure

```
8-bit-cpu-systemverilog/
├── rtl/
│   ├── cpu_pkg.sv
│   ├── mux2.sv
│   ├── wb_mux.sv
│   ├── pc.sv
│   ├── sp.sv
│   ├── flags_reg.sv
│   ├── reg_file.sv
│   ├── ir.sv
│   ├── alu.sv
│   ├── memory.sv
│   ├── program.mem
│   └── control_unit.sv
├── tb/
│   ├── tb_mux2.sv
│   ├── tb_wb_mux.sv
│   ├── tb_pc.sv
│   ├── tb_sp.sv
│   ├── tb_flags_reg.sv
│   ├── tb_reg_file.sv
│   ├── tb_ir.sv
│   ├── tb_alu.sv
│   ├── tb_memory.sv
│   └── tb_control_unit.sv
└── README.md
```

The assembler (`tools/`), the example programs (`programs/`) and the program
runner will be carried over from the VHDL version as the CPU comes together.

### Program file

`memory.sv` loads the program with `$readmemh`, so `rtl/program.mem` holds hex
bytes separated by whitespace, filling addresses 00, 01, 02 ... in order, with
`//` comments. Each line is one instruction (opcode, rd/rs, imm):

```
01 00 0F   // 00: LDI R0, 0F
01 10 3C   // 03: LDI R1, 3C
```

This differs from the VHDL version (`01000F   -- ...`), whose loader was
hand-written with `textio`. The current file is the VHDL test program
(`test.asm`) converted to this format; the assembler will write it directly
once it is carried over.

### Coding conventions

- `logic` everywhere; `always_ff` for registers, `always_comb` for combinational logic
- Non-blocking `<=` in `always_ff`, blocking `=` in `always_comb` and testbenches
- Every `always_comb` assigns defaults first, and every `case` has a `default`, so no latches are inferred
- `begin`/`end` on their own lines: aligned with `always_ff`/`always_comb`/`initial`, indented one level under `if`/`else` and `case` items
- Shared constants and the FSM state type (`state_t`, an enum) in `cpu_pkg`, imported with `import cpu_pkg::*;` in the module header
- Testbenches use a `check` task per input set, `assert ... else $fatal`, and `===` so X values fail

---

## Tools

- Vivado 2026.1 (XSIM for simulation, Vivado synthesis), simulation only, no board
- Sources are added to the Vivado project straight from `rtl/` and `tb/` (not copied), including `program.mem`
- Python 3 for the assembler (standard library only)

---

## Related

- VHDL version, complete: [Johnyzour/8-bit-cpu](https://github.com/Johnyzour/8-bit-cpu)
  - `single-cycle`: single-cycle CPU (tag `v1.0-single-cycle`)
  - `multicycle`: multi-cycle Harvard CPU (tag `v1.1-multicycle-harvard`)
  - `von-neumann`: multi-cycle von Neumann CPU, the basis for this remake (tag `v1.2-multicycle-von-neumann`)
