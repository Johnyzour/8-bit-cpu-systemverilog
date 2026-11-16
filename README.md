# 8-bit CPU in SystemVerilog

A SystemVerilog remake of my [8-bit CPU in VHDL](https://github.com/Johnyzour/8-bit-cpu):
a simple 8-bit, multi-cycle, von Neumann CPU, verified with self-checking
testbenches in the Vivado simulator (XSIM).

**Status:** under development. Modules are being ported one at a time,
bottom-up, each with its testbench. The design is not complete yet.

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

| Module | RTL | Testbench |
|---|---|---|
| `mux2` | in progress | - |
| `wb_mux` | - | - |
| `pc` | - | - |
| `sp` | - | - |
| `flags_reg` | - | - |
| `reg_file` | - | - |
| `ir` | - | - |
| `alu` | - | - |
| `cpu_pkg` | - | - |
| `memory` | - | - |
| `control_unit` | - | - |
| `cpu` | - | - |

---

## Project structure

```
8-bit-cpu-sv/
├── rtl/          SystemVerilog design files (.sv)
├── tb/           SystemVerilog testbenches (.sv)
└── README.md
```

The assembler (`tools/`), the example programs (`programs/`) and the program
runner will be carried over from the VHDL version as the CPU comes together;
the instruction set is unchanged, so the assembler works as is.

---

## Tools

- Vivado (XSIM for simulation, Vivado synthesis), simulation only, no board
- Python 3 for the assembler (standard library only)

---

## Related

- VHDL version, complete: [Johnyzour/8-bit-cpu](https://github.com/Johnyzour/8-bit-cpu)
  - `single-cycle`: single-cycle CPU (tag `v1.0-single-cycle`)
  - `multicycle`: multi-cycle Harvard CPU (tag `v1.1-multicycle-harvard`)
  - `von-neumann`: multi-cycle von Neumann CPU, the basis for this remake (tag `v1.2-multicycle-von-neumann`)
