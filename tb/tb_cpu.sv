//------------------------------------------------------------------------------
// File        : tb_cpu.sv
// Description : System testbench for the multi-cycle von Neumann cpu. Runs the
//               program in memory (all 26 instructions, including a nested
//               subroutine call, a call inside a loop and a pointer loop using
//               LDR/STR) and checks the FSM state and debug outputs, including
//               the stack pointer, on every clock cycle against the expected
//               trace.
// Notes       : Reset is held for the first cycle. The PC increments in each
//               FETCH state, so pc_dbg runs ahead of the instruction. The IR
//               fills one byte per state (FETCH2, FETCH3, DECODE), so it mixes
//               new and old bytes until EXECUTE. Results appear in the state
//               after the one that writes them. Prints "all tests completed
//               and passed" at 4140 ns. The expected trace must be updated if
//               the program changes (rtl/program.mem must hold test.asm).
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_cpu;
    import cpu_pkg::*;

    logic        tb_clk = 1'b0;
    logic        tb_rst = 1'b1;
    logic [7:0]  tb_pc_dbg;
    logic [7:0]  tb_sp_dbg;
    logic [23:0] tb_instr_dbg;
    logic [7:0]  tb_reg_a_dbg;
    logic        tb_z_dbg;
    logic        tb_c_dbg;
    state_t      tb_state_dbg;

    cpu uut (
        .clk       (tb_clk),
        .rst       (tb_rst),
        .pc_dbg    (tb_pc_dbg),
        .sp_dbg    (tb_sp_dbg),
        .instr_dbg (tb_instr_dbg),
        .reg_a_dbg (tb_reg_a_dbg),
        .z_dbg     (tb_z_dbg),
        .c_dbg     (tb_c_dbg),
        .state_dbg (tb_state_dbg)
    );

    // 10 ns clock
    always #5 tb_clk = ~tb_clk;

    // compares the state and all six debug outputs
    task automatic check (input string       name,
                          input state_t      st,
                          input logic [7:0]  pc,
                          input logic [7:0]  sp,
                          input logic [23:0] ir,
                          input logic [7:0]  reg_a,
                          input logic        z,
                          input logic        c);
        assert (tb_state_dbg === st)
            else $fatal(1, "%s failed: state is %s, expected %s", name, tb_state_dbg.name(), st.name());
        assert (tb_pc_dbg === pc)
            else $fatal(1, "%s failed: pc_dbg = %h, expected %h", name, tb_pc_dbg, pc);
        assert (tb_sp_dbg === sp)
            else $fatal(1, "%s failed: sp_dbg = %h, expected %h", name, tb_sp_dbg, sp);
        assert (tb_instr_dbg === ir)
            else $fatal(1, "%s failed: instr_dbg = %h, expected %h", name, tb_instr_dbg, ir);
        assert (tb_reg_a_dbg === reg_a)
            else $fatal(1, "%s failed: reg_a_dbg = %h, expected %h", name, tb_reg_a_dbg, reg_a);
        assert (tb_z_dbg === z)
            else $fatal(1, "%s failed: z_dbg = %b, expected %b", name, tb_z_dbg, z);
        assert (tb_c_dbg === c)
            else $fatal(1, "%s failed: c_dbg = %b, expected %b", name, tb_c_dbg, c);
    endtask

    initial
    begin
        // reset was applied at the first rising edge; IR holds 000000, SP = F0
        // during FETCH3 and DECODE the IR mixes new and old bytes (one byte per state)
        // check order: state, pc, sp, ir, reg_a, z, c
        @(negedge tb_clk);
        tb_rst = 1'b0;
        // LDI R0, 0F
        check("cycle 0",  S_FETCH1,    8'h00, 8'hF0, 24'h000000, 8'h00, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 1",  S_FETCH2,    8'h01, 8'hF0, 24'h000000, 8'h00, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 2",  S_FETCH3,    8'h02, 8'hF0, 24'h010000, 8'h00, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 3",  S_DECODE,    8'h03, 8'hF0, 24'h010000, 8'h00, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 4",  S_WRITEBACK, 8'h03, 8'hF0, 24'h01000F, 8'h00, 1'b0, 1'b0);

        // LDI R1, 3C
        @(negedge tb_clk); check("cycle 5",  S_FETCH1,    8'h03, 8'hF0, 24'h01000F, 8'h0F, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 6",  S_FETCH2,    8'h04, 8'hF0, 24'h01000F, 8'h0F, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 7",  S_FETCH3,    8'h05, 8'hF0, 24'h01000F, 8'h0F, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 8",  S_DECODE,    8'h06, 8'hF0, 24'h01100F, 8'h00, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 9",  S_WRITEBACK, 8'h06, 8'hF0, 24'h01103C, 8'h00, 1'b0, 1'b0);

        // MOV R2, R1
        @(negedge tb_clk); check("cycle 10", S_FETCH1,    8'h06, 8'hF0, 24'h01103C, 8'h3C, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 11", S_FETCH2,    8'h07, 8'hF0, 24'h01103C, 8'h3C, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 12", S_FETCH3,    8'h08, 8'hF0, 24'h02103C, 8'h3C, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 13", S_DECODE,    8'h09, 8'hF0, 24'h02213C, 8'h00, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 14", S_WRITEBACK, 8'h09, 8'hF0, 24'h022100, 8'h00, 1'b0, 1'b0);

        // ADD R2, R0
        @(negedge tb_clk); check("cycle 15", S_FETCH1,    8'h09, 8'hF0, 24'h022100, 8'h3C, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 16", S_FETCH2,    8'h0A, 8'hF0, 24'h022100, 8'h3C, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 17", S_FETCH3,    8'h0B, 8'hF0, 24'h052100, 8'h3C, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 18", S_DECODE,    8'h0C, 8'hF0, 24'h052000, 8'h3C, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 19", S_EXECUTE,   8'h0C, 8'hF0, 24'h052000, 8'h3C, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 20", S_WRITEBACK, 8'h0C, 8'hF0, 24'h052000, 8'h3C, 1'b0, 1'b0);

        // AND R2, R1
        @(negedge tb_clk); check("cycle 21", S_FETCH1,    8'h0C, 8'hF0, 24'h052000, 8'h4B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 22", S_FETCH2,    8'h0D, 8'hF0, 24'h052000, 8'h4B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 23", S_FETCH3,    8'h0E, 8'hF0, 24'h072000, 8'h4B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 24", S_DECODE,    8'h0F, 8'hF0, 24'h072100, 8'h4B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 25", S_EXECUTE,   8'h0F, 8'hF0, 24'h072100, 8'h4B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 26", S_WRITEBACK, 8'h0F, 8'hF0, 24'h072100, 8'h4B, 1'b0, 1'b0);

        // OR R2, R0
        @(negedge tb_clk); check("cycle 27", S_FETCH1,    8'h0F, 8'hF0, 24'h072100, 8'h08, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 28", S_FETCH2,    8'h10, 8'hF0, 24'h072100, 8'h08, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 29", S_FETCH3,    8'h11, 8'hF0, 24'h082100, 8'h08, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 30", S_DECODE,    8'h12, 8'hF0, 24'h082000, 8'h08, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 31", S_EXECUTE,   8'h12, 8'hF0, 24'h082000, 8'h08, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 32", S_WRITEBACK, 8'h12, 8'hF0, 24'h082000, 8'h08, 1'b0, 1'b0);

        // XOR R2, R0 (result 00, Z set in EXECUTE)
        @(negedge tb_clk); check("cycle 33", S_FETCH1,    8'h12, 8'hF0, 24'h082000, 8'h0F, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 34", S_FETCH2,    8'h13, 8'hF0, 24'h082000, 8'h0F, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 35", S_FETCH3,    8'h14, 8'hF0, 24'h092000, 8'h0F, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 36", S_DECODE,    8'h15, 8'hF0, 24'h092000, 8'h0F, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 37", S_EXECUTE,   8'h15, 8'hF0, 24'h092000, 8'h0F, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 38", S_WRITEBACK, 8'h15, 8'hF0, 24'h092000, 8'h0F, 1'b1, 1'b0);

        // JZ 1B (taken: PC jumps over address 18)
        @(negedge tb_clk); check("cycle 39", S_FETCH1,    8'h15, 8'hF0, 24'h092000, 8'h00, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 40", S_FETCH2,    8'h16, 8'hF0, 24'h092000, 8'h00, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 41", S_FETCH3,    8'h17, 8'hF0, 24'h0D2000, 8'h00, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 42", S_DECODE,    8'h18, 8'hF0, 24'h0D0000, 8'h0F, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 43", S_EXECUTE,   8'h18, 8'hF0, 24'h0D001B, 8'h0F, 1'b1, 1'b0);

        // NOT R2
        @(negedge tb_clk); check("cycle 44", S_FETCH1,    8'h1B, 8'hF0, 24'h0D001B, 8'h0F, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 45", S_FETCH2,    8'h1C, 8'hF0, 24'h0D001B, 8'h0F, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 46", S_FETCH3,    8'h1D, 8'hF0, 24'h0A001B, 8'h0F, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 47", S_DECODE,    8'h1E, 8'hF0, 24'h0A201B, 8'h00, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 48", S_EXECUTE,   8'h1E, 8'hF0, 24'h0A2000, 8'h00, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 49", S_WRITEBACK, 8'h1E, 8'hF0, 24'h0A2000, 8'h00, 1'b0, 1'b0);

        // ST R2, F0 (write to the data area)
        @(negedge tb_clk); check("cycle 50", S_FETCH1,    8'h1E, 8'hF0, 24'h0A2000, 8'hFF, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 51", S_FETCH2,    8'h1F, 8'hF0, 24'h0A2000, 8'hFF, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 52", S_FETCH3,    8'h20, 8'hF0, 24'h042000, 8'hFF, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 53", S_DECODE,    8'h21, 8'hF0, 24'h042000, 8'hFF, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 54", S_EXECUTE,   8'h21, 8'hF0, 24'h0420F0, 8'hFF, 1'b0, 1'b0);

        // LD R3, F0 (R3 = 00 proves address 18 never ran)
        @(negedge tb_clk); check("cycle 55", S_FETCH1,    8'h21, 8'hF0, 24'h0420F0, 8'hFF, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 56", S_FETCH2,    8'h22, 8'hF0, 24'h0420F0, 8'hFF, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 57", S_FETCH3,    8'h23, 8'hF0, 24'h0320F0, 8'hFF, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 58", S_DECODE,    8'h24, 8'hF0, 24'h0330F0, 8'h00, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 59", S_EXECUTE,   8'h24, 8'hF0, 24'h0330F0, 8'h00, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 60", S_WRITEBACK, 8'h24, 8'hF0, 24'h0330F0, 8'h00, 1'b0, 1'b0);

        // SUB R0, R1 (borrow, C set in EXECUTE)
        @(negedge tb_clk); check("cycle 61", S_FETCH1,    8'h24, 8'hF0, 24'h0330F0, 8'hFF, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 62", S_FETCH2,    8'h25, 8'hF0, 24'h0330F0, 8'hFF, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 63", S_FETCH3,    8'h26, 8'hF0, 24'h0630F0, 8'hFF, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 64", S_DECODE,    8'h27, 8'hF0, 24'h0601F0, 8'h0F, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 65", S_EXECUTE,   8'h27, 8'hF0, 24'h060100, 8'h0F, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 66", S_WRITEBACK, 8'h27, 8'hF0, 24'h060100, 8'h0F, 1'b0, 1'b1);

        // JC 2D (taken: PC jumps over address 2A)
        @(negedge tb_clk); check("cycle 67", S_FETCH1,    8'h27, 8'hF0, 24'h060100, 8'hD3, 1'b0, 1'b1);
        @(negedge tb_clk); check("cycle 68", S_FETCH2,    8'h28, 8'hF0, 24'h060100, 8'hD3, 1'b0, 1'b1);
        @(negedge tb_clk); check("cycle 69", S_FETCH3,    8'h29, 8'hF0, 24'h0F0100, 8'hD3, 1'b0, 1'b1);
        @(negedge tb_clk); check("cycle 70", S_DECODE,    8'h2A, 8'hF0, 24'h0F0000, 8'hD3, 1'b0, 1'b1);
        @(negedge tb_clk); check("cycle 71", S_EXECUTE,   8'h2A, 8'hF0, 24'h0F002D, 8'hD3, 1'b0, 1'b1);

        // CMP R3, R2 (R3 = FF proves LD worked; Z set, C cleared)
        @(negedge tb_clk); check("cycle 72", S_FETCH1,    8'h2D, 8'hF0, 24'h0F002D, 8'hD3, 1'b0, 1'b1);
        @(negedge tb_clk); check("cycle 73", S_FETCH2,    8'h2E, 8'hF0, 24'h0F002D, 8'hD3, 1'b0, 1'b1);
        @(negedge tb_clk); check("cycle 74", S_FETCH3,    8'h2F, 8'hF0, 24'h0B002D, 8'hD3, 1'b0, 1'b1);
        @(negedge tb_clk); check("cycle 75", S_DECODE,    8'h30, 8'hF0, 24'h0B322D, 8'hFF, 1'b0, 1'b1);
        @(negedge tb_clk); check("cycle 76", S_EXECUTE,   8'h30, 8'hF0, 24'h0B3200, 8'hFF, 1'b0, 1'b1);

        // JNZ 99 (not taken: falls through to 33)
        @(negedge tb_clk); check("cycle 77", S_FETCH1,    8'h30, 8'hF0, 24'h0B3200, 8'hFF, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 78", S_FETCH2,    8'h31, 8'hF0, 24'h0B3200, 8'hFF, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 79", S_FETCH3,    8'h32, 8'hF0, 24'h0E3200, 8'hFF, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 80", S_DECODE,    8'h33, 8'hF0, 24'h0E0000, 8'hD3, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 81", S_EXECUTE,   8'h33, 8'hF0, 24'h0E0099, 8'hD3, 1'b1, 1'b0);

        // NOP
        @(negedge tb_clk); check("cycle 82", S_FETCH1,    8'h33, 8'hF0, 24'h0E0099, 8'hD3, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 83", S_FETCH2,    8'h34, 8'hF0, 24'h0E0099, 8'hD3, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 84", S_FETCH3,    8'h35, 8'hF0, 24'h000099, 8'hD3, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 85", S_DECODE,    8'h36, 8'hF0, 24'h000099, 8'hD3, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 86", S_EXECUTE,   8'h36, 8'hF0, 24'h000000, 8'hD3, 1'b1, 1'b0);

        // INC R2 (FF wraps to 00: Z and C set in EXECUTE)
        @(negedge tb_clk); check("cycle 87", S_FETCH1,    8'h36, 8'hF0, 24'h000000, 8'hD3, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 88", S_FETCH2,    8'h37, 8'hF0, 24'h000000, 8'hD3, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 89", S_FETCH3,    8'h38, 8'hF0, 24'h120000, 8'hD3, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 90", S_DECODE,    8'h39, 8'hF0, 24'h122000, 8'hFF, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 91", S_EXECUTE,   8'h39, 8'hF0, 24'h122000, 8'hFF, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 92", S_WRITEBACK, 8'h39, 8'hF0, 24'h122000, 8'hFF, 1'b1, 1'b1);

        // DEC R1 (3C to 3B: Z and C cleared)
        @(negedge tb_clk); check("cycle 93", S_FETCH1,    8'h39, 8'hF0, 24'h122000, 8'h00, 1'b1, 1'b1);
        @(negedge tb_clk); check("cycle 94", S_FETCH2,    8'h3A, 8'hF0, 24'h122000, 8'h00, 1'b1, 1'b1);
        @(negedge tb_clk); check("cycle 95", S_FETCH3,    8'h3B, 8'hF0, 24'h132000, 8'h00, 1'b1, 1'b1);
        @(negedge tb_clk); check("cycle 96", S_DECODE,    8'h3C, 8'hF0, 24'h131000, 8'h3C, 1'b1, 1'b1);
        @(negedge tb_clk); check("cycle 97", S_EXECUTE,   8'h3C, 8'hF0, 24'h131000, 8'h3C, 1'b1, 1'b1);
        @(negedge tb_clk); check("cycle 98", S_WRITEBACK, 8'h3C, 8'hF0, 24'h131000, 8'h3C, 1'b0, 1'b0);

        // SHL R0 (D3 to A6: bit 7 into C)
        @(negedge tb_clk); check("cycle 99", S_FETCH1,    8'h3C, 8'hF0, 24'h131000, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 100", S_FETCH2,    8'h3D, 8'hF0, 24'h131000, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 101", S_FETCH3,    8'h3E, 8'hF0, 24'h101000, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 102", S_DECODE,    8'h3F, 8'hF0, 24'h100000, 8'hD3, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 103", S_EXECUTE,   8'h3F, 8'hF0, 24'h100000, 8'hD3, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 104", S_WRITEBACK, 8'h3F, 8'hF0, 24'h100000, 8'hD3, 1'b0, 1'b1);

        // SHR R0 (A6 to 53: bit 0 into C, C cleared)
        @(negedge tb_clk); check("cycle 105", S_FETCH1,    8'h3F, 8'hF0, 24'h100000, 8'hA6, 1'b0, 1'b1);
        @(negedge tb_clk); check("cycle 106", S_FETCH2,    8'h40, 8'hF0, 24'h100000, 8'hA6, 1'b0, 1'b1);
        @(negedge tb_clk); check("cycle 107", S_FETCH3,    8'h41, 8'hF0, 24'h110000, 8'hA6, 1'b0, 1'b1);
        @(negedge tb_clk); check("cycle 108", S_DECODE,    8'h42, 8'hF0, 24'h110000, 8'hA6, 1'b0, 1'b1);
        @(negedge tb_clk); check("cycle 109", S_EXECUTE,   8'h42, 8'hF0, 24'h110000, 8'hA6, 1'b0, 1'b1);
        @(negedge tb_clk); check("cycle 110", S_WRITEBACK, 8'h42, 8'hF0, 24'h110000, 8'hA6, 1'b0, 1'b0);

        // CALL 5A (SP-1 in DECODE, return address 45 written to EF, PC = 5A)
        @(negedge tb_clk); check("cycle 111", S_FETCH1,    8'h42, 8'hF0, 24'h110000, 8'h53, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 112", S_FETCH2,    8'h43, 8'hF0, 24'h110000, 8'h53, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 113", S_FETCH3,    8'h44, 8'hF0, 24'h160000, 8'h53, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 114", S_DECODE,    8'h45, 8'hF0, 24'h160000, 8'h53, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 115", S_EXECUTE,   8'h45, 8'hEF, 24'h16005A, 8'h53, 1'b0, 1'b0);

        // sub1: PUSH R1 (SP = EE, MEM[EE] = 3B)
        @(negedge tb_clk); check("cycle 116", S_FETCH1,    8'h5A, 8'hEF, 24'h16005A, 8'h53, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 117", S_FETCH2,    8'h5B, 8'hEF, 24'h16005A, 8'h53, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 118", S_FETCH3,    8'h5C, 8'hEF, 24'h14005A, 8'h53, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 119", S_DECODE,    8'h5D, 8'hEF, 24'h14105A, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 120", S_EXECUTE,   8'h5D, 8'hEE, 24'h141000, 8'h3B, 1'b0, 1'b0);

        // sub1: LDI R1, 77 (clobber the saved register)
        @(negedge tb_clk); check("cycle 121", S_FETCH1,    8'h5D, 8'hEE, 24'h141000, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 122", S_FETCH2,    8'h5E, 8'hEE, 24'h141000, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 123", S_FETCH3,    8'h5F, 8'hEE, 24'h011000, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 124", S_DECODE,    8'h60, 8'hEE, 24'h011000, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 125", S_WRITEBACK, 8'h60, 8'hEE, 24'h011077, 8'h3B, 1'b0, 1'b0);

        // sub1: CALL 69 (nested: return address 63 written to ED, SP = ED)
        @(negedge tb_clk); check("cycle 126", S_FETCH1,    8'h60, 8'hEE, 24'h011077, 8'h77, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 127", S_FETCH2,    8'h61, 8'hEE, 24'h011077, 8'h77, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 128", S_FETCH3,    8'h62, 8'hEE, 24'h161077, 8'h77, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 129", S_DECODE,    8'h63, 8'hEE, 24'h160077, 8'h53, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 130", S_EXECUTE,   8'h63, 8'hED, 24'h160069, 8'h53, 1'b0, 1'b0);

        // sub2: INC R0
        @(negedge tb_clk); check("cycle 131", S_FETCH1,    8'h69, 8'hED, 24'h160069, 8'h53, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 132", S_FETCH2,    8'h6A, 8'hED, 24'h160069, 8'h53, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 133", S_FETCH3,    8'h6B, 8'hED, 24'h120069, 8'h53, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 134", S_DECODE,    8'h6C, 8'hED, 24'h120069, 8'h53, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 135", S_EXECUTE,   8'h6C, 8'hED, 24'h120000, 8'h53, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 136", S_WRITEBACK, 8'h6C, 8'hED, 24'h120000, 8'h53, 1'b0, 1'b0);

        // sub2: RET (PC from memory, SP + 1)
        @(negedge tb_clk); check("cycle 137", S_FETCH1,    8'h6C, 8'hED, 24'h120000, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 138", S_FETCH2,    8'h6D, 8'hED, 24'h120000, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 139", S_FETCH3,    8'h6E, 8'hED, 24'h170000, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 140", S_DECODE,    8'h6F, 8'hED, 24'h170000, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 141", S_EXECUTE,   8'h6F, 8'hED, 24'h170000, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 142", S_WRITEBACK, 8'h6F, 8'hEE, 24'h170000, 8'h54, 1'b0, 1'b0);

        // sub1: POP R1 (R1 = 3B restored, SP = EF)
        @(negedge tb_clk); check("cycle 143", S_FETCH1,    8'h63, 8'hEE, 24'h170000, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 144", S_FETCH2,    8'h64, 8'hEE, 24'h170000, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 145", S_FETCH3,    8'h65, 8'hEE, 24'h150000, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 146", S_DECODE,    8'h66, 8'hEE, 24'h151000, 8'h77, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 147", S_EXECUTE,   8'h66, 8'hEE, 24'h151000, 8'h77, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 148", S_WRITEBACK, 8'h66, 8'hEF, 24'h151000, 8'h77, 1'b0, 1'b0);

        // sub1: RET (back to 45, SP = F0)
        @(negedge tb_clk); check("cycle 149", S_FETCH1,    8'h66, 8'hEF, 24'h151000, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 150", S_FETCH2,    8'h67, 8'hEF, 24'h151000, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 151", S_FETCH3,    8'h68, 8'hEF, 24'h171000, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 152", S_DECODE,    8'h69, 8'hEF, 24'h170000, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 153", S_EXECUTE,   8'h69, 8'hEF, 24'h170000, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 154", S_WRITEBACK, 8'h69, 8'hF0, 24'h170000, 8'h54, 1'b0, 1'b0);

        // PUSH R0 (SP = EF, MEM[EF] = 54)
        @(negedge tb_clk); check("cycle 155", S_FETCH1,    8'h45, 8'hF0, 24'h170000, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 156", S_FETCH2,    8'h46, 8'hF0, 24'h170000, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 157", S_FETCH3,    8'h47, 8'hF0, 24'h140000, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 158", S_DECODE,    8'h48, 8'hF0, 24'h140000, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 159", S_EXECUTE,   8'h48, 8'hEF, 24'h140000, 8'h54, 1'b0, 1'b0);

        // POP R2 (R2 = 54, SP = F0)
        @(negedge tb_clk); check("cycle 160", S_FETCH1,    8'h48, 8'hEF, 24'h140000, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 161", S_FETCH2,    8'h49, 8'hEF, 24'h140000, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 162", S_FETCH3,    8'h4A, 8'hEF, 24'h150000, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 163", S_DECODE,    8'h4B, 8'hEF, 24'h152000, 8'h00, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 164", S_EXECUTE,   8'h4B, 8'hEF, 24'h152000, 8'h00, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 165", S_WRITEBACK, 8'h4B, 8'hF0, 24'h152000, 8'h00, 1'b0, 1'b0);

        // LDI R3, 03 (loop counter)
        @(negedge tb_clk); check("cycle 166", S_FETCH1,    8'h4B, 8'hF0, 24'h152000, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 167", S_FETCH2,    8'h4C, 8'hF0, 24'h152000, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 168", S_FETCH3,    8'h4D, 8'hF0, 24'h012000, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 169", S_DECODE,    8'h4E, 8'hF0, 24'h013000, 8'hFF, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 170", S_WRITEBACK, 8'h4E, 8'hF0, 24'h013003, 8'hFF, 1'b0, 1'b0);

        // CALL 69 (loop: return address 51 written to EF)
        @(negedge tb_clk); check("cycle 171", S_FETCH1,    8'h4E, 8'hF0, 24'h013003, 8'h03, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 172", S_FETCH2,    8'h4F, 8'hF0, 24'h013003, 8'h03, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 173", S_FETCH3,    8'h50, 8'hF0, 24'h163003, 8'h03, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 174", S_DECODE,    8'h51, 8'hF0, 24'h160003, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 175", S_EXECUTE,   8'h51, 8'hEF, 24'h160069, 8'h54, 1'b0, 1'b0);

        // sub2: INC R0
        @(negedge tb_clk); check("cycle 176", S_FETCH1,    8'h69, 8'hEF, 24'h160069, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 177", S_FETCH2,    8'h6A, 8'hEF, 24'h160069, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 178", S_FETCH3,    8'h6B, 8'hEF, 24'h120069, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 179", S_DECODE,    8'h6C, 8'hEF, 24'h120069, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 180", S_EXECUTE,   8'h6C, 8'hEF, 24'h120000, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 181", S_WRITEBACK, 8'h6C, 8'hEF, 24'h120000, 8'h54, 1'b0, 1'b0);

        // sub2: RET (PC from memory, SP + 1)
        @(negedge tb_clk); check("cycle 182", S_FETCH1,    8'h6C, 8'hEF, 24'h120000, 8'h55, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 183", S_FETCH2,    8'h6D, 8'hEF, 24'h120000, 8'h55, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 184", S_FETCH3,    8'h6E, 8'hEF, 24'h170000, 8'h55, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 185", S_DECODE,    8'h6F, 8'hEF, 24'h170000, 8'h55, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 186", S_EXECUTE,   8'h6F, 8'hEF, 24'h170000, 8'h55, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 187", S_WRITEBACK, 8'h6F, 8'hF0, 24'h170000, 8'h55, 1'b0, 1'b0);

        // DEC R3
        @(negedge tb_clk); check("cycle 188", S_FETCH1,    8'h51, 8'hF0, 24'h170000, 8'h55, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 189", S_FETCH2,    8'h52, 8'hF0, 24'h170000, 8'h55, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 190", S_FETCH3,    8'h53, 8'hF0, 24'h130000, 8'h55, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 191", S_DECODE,    8'h54, 8'hF0, 24'h133000, 8'h03, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 192", S_EXECUTE,   8'h54, 8'hF0, 24'h133000, 8'h03, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 193", S_WRITEBACK, 8'h54, 8'hF0, 24'h133000, 8'h03, 1'b0, 1'b0);

        // JNZ 4E
        @(negedge tb_clk); check("cycle 194", S_FETCH1,    8'h54, 8'hF0, 24'h133000, 8'h02, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 195", S_FETCH2,    8'h55, 8'hF0, 24'h133000, 8'h02, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 196", S_FETCH3,    8'h56, 8'hF0, 24'h0E3000, 8'h02, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 197", S_DECODE,    8'h57, 8'hF0, 24'h0E0000, 8'h55, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 198", S_EXECUTE,   8'h57, 8'hF0, 24'h0E004E, 8'h55, 1'b0, 1'b0);

        // CALL 69 (loop: return address 51 written to EF)
        @(negedge tb_clk); check("cycle 199", S_FETCH1,    8'h4E, 8'hF0, 24'h0E004E, 8'h55, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 200", S_FETCH2,    8'h4F, 8'hF0, 24'h0E004E, 8'h55, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 201", S_FETCH3,    8'h50, 8'hF0, 24'h16004E, 8'h55, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 202", S_DECODE,    8'h51, 8'hF0, 24'h16004E, 8'h55, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 203", S_EXECUTE,   8'h51, 8'hEF, 24'h160069, 8'h55, 1'b0, 1'b0);

        // sub2: INC R0
        @(negedge tb_clk); check("cycle 204", S_FETCH1,    8'h69, 8'hEF, 24'h160069, 8'h55, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 205", S_FETCH2,    8'h6A, 8'hEF, 24'h160069, 8'h55, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 206", S_FETCH3,    8'h6B, 8'hEF, 24'h120069, 8'h55, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 207", S_DECODE,    8'h6C, 8'hEF, 24'h120069, 8'h55, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 208", S_EXECUTE,   8'h6C, 8'hEF, 24'h120000, 8'h55, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 209", S_WRITEBACK, 8'h6C, 8'hEF, 24'h120000, 8'h55, 1'b0, 1'b0);

        // sub2: RET (PC from memory, SP + 1)
        @(negedge tb_clk); check("cycle 210", S_FETCH1,    8'h6C, 8'hEF, 24'h120000, 8'h56, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 211", S_FETCH2,    8'h6D, 8'hEF, 24'h120000, 8'h56, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 212", S_FETCH3,    8'h6E, 8'hEF, 24'h170000, 8'h56, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 213", S_DECODE,    8'h6F, 8'hEF, 24'h170000, 8'h56, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 214", S_EXECUTE,   8'h6F, 8'hEF, 24'h170000, 8'h56, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 215", S_WRITEBACK, 8'h6F, 8'hF0, 24'h170000, 8'h56, 1'b0, 1'b0);

        // DEC R3
        @(negedge tb_clk); check("cycle 216", S_FETCH1,    8'h51, 8'hF0, 24'h170000, 8'h56, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 217", S_FETCH2,    8'h52, 8'hF0, 24'h170000, 8'h56, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 218", S_FETCH3,    8'h53, 8'hF0, 24'h130000, 8'h56, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 219", S_DECODE,    8'h54, 8'hF0, 24'h133000, 8'h02, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 220", S_EXECUTE,   8'h54, 8'hF0, 24'h133000, 8'h02, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 221", S_WRITEBACK, 8'h54, 8'hF0, 24'h133000, 8'h02, 1'b0, 1'b0);

        // JNZ 4E
        @(negedge tb_clk); check("cycle 222", S_FETCH1,    8'h54, 8'hF0, 24'h133000, 8'h01, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 223", S_FETCH2,    8'h55, 8'hF0, 24'h133000, 8'h01, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 224", S_FETCH3,    8'h56, 8'hF0, 24'h0E3000, 8'h01, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 225", S_DECODE,    8'h57, 8'hF0, 24'h0E0000, 8'h56, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 226", S_EXECUTE,   8'h57, 8'hF0, 24'h0E004E, 8'h56, 1'b0, 1'b0);

        // CALL 69 (loop: return address 51 written to EF)
        @(negedge tb_clk); check("cycle 227", S_FETCH1,    8'h4E, 8'hF0, 24'h0E004E, 8'h56, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 228", S_FETCH2,    8'h4F, 8'hF0, 24'h0E004E, 8'h56, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 229", S_FETCH3,    8'h50, 8'hF0, 24'h16004E, 8'h56, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 230", S_DECODE,    8'h51, 8'hF0, 24'h16004E, 8'h56, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 231", S_EXECUTE,   8'h51, 8'hEF, 24'h160069, 8'h56, 1'b0, 1'b0);

        // sub2: INC R0
        @(negedge tb_clk); check("cycle 232", S_FETCH1,    8'h69, 8'hEF, 24'h160069, 8'h56, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 233", S_FETCH2,    8'h6A, 8'hEF, 24'h160069, 8'h56, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 234", S_FETCH3,    8'h6B, 8'hEF, 24'h120069, 8'h56, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 235", S_DECODE,    8'h6C, 8'hEF, 24'h120069, 8'h56, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 236", S_EXECUTE,   8'h6C, 8'hEF, 24'h120000, 8'h56, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 237", S_WRITEBACK, 8'h6C, 8'hEF, 24'h120000, 8'h56, 1'b0, 1'b0);

        // sub2: RET (PC from memory, SP + 1)
        @(negedge tb_clk); check("cycle 238", S_FETCH1,    8'h6C, 8'hEF, 24'h120000, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 239", S_FETCH2,    8'h6D, 8'hEF, 24'h120000, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 240", S_FETCH3,    8'h6E, 8'hEF, 24'h170000, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 241", S_DECODE,    8'h6F, 8'hEF, 24'h170000, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 242", S_EXECUTE,   8'h6F, 8'hEF, 24'h170000, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 243", S_WRITEBACK, 8'h6F, 8'hF0, 24'h170000, 8'h57, 1'b0, 1'b0);

        // DEC R3
        @(negedge tb_clk); check("cycle 244", S_FETCH1,    8'h51, 8'hF0, 24'h170000, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 245", S_FETCH2,    8'h52, 8'hF0, 24'h170000, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 246", S_FETCH3,    8'h53, 8'hF0, 24'h130000, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 247", S_DECODE,    8'h54, 8'hF0, 24'h133000, 8'h01, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 248", S_EXECUTE,   8'h54, 8'hF0, 24'h133000, 8'h01, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 249", S_WRITEBACK, 8'h54, 8'hF0, 24'h133000, 8'h01, 1'b1, 1'b0);

        // JNZ 4E
        @(negedge tb_clk); check("cycle 250", S_FETCH1,    8'h54, 8'hF0, 24'h133000, 8'h00, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 251", S_FETCH2,    8'h55, 8'hF0, 24'h133000, 8'h00, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 252", S_FETCH3,    8'h56, 8'hF0, 24'h0E3000, 8'h00, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 253", S_DECODE,    8'h57, 8'hF0, 24'h0E0000, 8'h57, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 254", S_EXECUTE,   8'h57, 8'hF0, 24'h0E004E, 8'h57, 1'b1, 1'b0);

        // JMP 6F (on to the register-indirect section)
        @(negedge tb_clk); check("cycle 255", S_FETCH1,    8'h57, 8'hF0, 24'h0E004E, 8'h57, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 256", S_FETCH2,    8'h58, 8'hF0, 24'h0E004E, 8'h57, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 257", S_FETCH3,    8'h59, 8'hF0, 24'h0C004E, 8'h57, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 258", S_DECODE,    8'h5A, 8'hF0, 24'h0C004E, 8'h57, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 259", S_EXECUTE,   8'h5A, 8'hF0, 24'h0C006F, 8'h57, 1'b1, 1'b0);

        // LDI R3, F1 (pointer)
        @(negedge tb_clk); check("cycle 260", S_FETCH1,    8'h6F, 8'hF0, 24'h0C006F, 8'h57, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 261", S_FETCH2,    8'h70, 8'hF0, 24'h0C006F, 8'h57, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 262", S_FETCH3,    8'h71, 8'hF0, 24'h01006F, 8'h57, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 263", S_DECODE,    8'h72, 8'hF0, 24'h01306F, 8'h00, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 264", S_WRITEBACK, 8'h72, 8'hF0, 24'h0130F1, 8'h00, 1'b1, 1'b0);

        // STR R0, [R3] (MEM[F1] = 57)
        @(negedge tb_clk); check("cycle 265", S_FETCH1,    8'h72, 8'hF0, 24'h0130F1, 8'hF1, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 266", S_FETCH2,    8'h73, 8'hF0, 24'h0130F1, 8'hF1, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 267", S_FETCH3,    8'h74, 8'hF0, 24'h1930F1, 8'hF1, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 268", S_DECODE,    8'h75, 8'hF0, 24'h1903F1, 8'h57, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 269", S_EXECUTE,   8'h75, 8'hF0, 24'h190300, 8'h57, 1'b1, 1'b0);

        // INC R3 (pointer = F2)
        @(negedge tb_clk); check("cycle 270", S_FETCH1,    8'h75, 8'hF0, 24'h190300, 8'h57, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 271", S_FETCH2,    8'h76, 8'hF0, 24'h190300, 8'h57, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 272", S_FETCH3,    8'h77, 8'hF0, 24'h120300, 8'h57, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 273", S_DECODE,    8'h78, 8'hF0, 24'h123000, 8'hF1, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 274", S_EXECUTE,   8'h78, 8'hF0, 24'h123000, 8'hF1, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 275", S_WRITEBACK, 8'h78, 8'hF0, 24'h123000, 8'hF1, 1'b0, 1'b0);

        // STR R1, [R3] (MEM[F2] = 3B)
        @(negedge tb_clk); check("cycle 276", S_FETCH1,    8'h78, 8'hF0, 24'h123000, 8'hF2, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 277", S_FETCH2,    8'h79, 8'hF0, 24'h123000, 8'hF2, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 278", S_FETCH3,    8'h7A, 8'hF0, 24'h193000, 8'hF2, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 279", S_DECODE,    8'h7B, 8'hF0, 24'h191300, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 280", S_EXECUTE,   8'h7B, 8'hF0, 24'h191300, 8'h3B, 1'b0, 1'b0);

        // INC R3 (pointer = F3)
        @(negedge tb_clk); check("cycle 281", S_FETCH1,    8'h7B, 8'hF0, 24'h191300, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 282", S_FETCH2,    8'h7C, 8'hF0, 24'h191300, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 283", S_FETCH3,    8'h7D, 8'hF0, 24'h121300, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 284", S_DECODE,    8'h7E, 8'hF0, 24'h123000, 8'hF2, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 285", S_EXECUTE,   8'h7E, 8'hF0, 24'h123000, 8'hF2, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 286", S_WRITEBACK, 8'h7E, 8'hF0, 24'h123000, 8'hF2, 1'b0, 1'b0);

        // STR R2, [R3] (MEM[F3] = 54)
        @(negedge tb_clk); check("cycle 287", S_FETCH1,    8'h7E, 8'hF0, 24'h123000, 8'hF3, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 288", S_FETCH2,    8'h7F, 8'hF0, 24'h123000, 8'hF3, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 289", S_FETCH3,    8'h80, 8'hF0, 24'h193000, 8'hF3, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 290", S_DECODE,    8'h81, 8'hF0, 24'h192300, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 291", S_EXECUTE,   8'h81, 8'hF0, 24'h192300, 8'h54, 1'b0, 1'b0);

        // LDI R0, 00 (sum)
        @(negedge tb_clk); check("cycle 292", S_FETCH1,    8'h81, 8'hF0, 24'h192300, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 293", S_FETCH2,    8'h82, 8'hF0, 24'h192300, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 294", S_FETCH3,    8'h83, 8'hF0, 24'h012300, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 295", S_DECODE,    8'h84, 8'hF0, 24'h010000, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 296", S_WRITEBACK, 8'h84, 8'hF0, 24'h010000, 8'h57, 1'b0, 1'b0);

        // LDI R3, F1 (pointer back to F1)
        @(negedge tb_clk); check("cycle 297", S_FETCH1,    8'h84, 8'hF0, 24'h010000, 8'h00, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 298", S_FETCH2,    8'h85, 8'hF0, 24'h010000, 8'h00, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 299", S_FETCH3,    8'h86, 8'hF0, 24'h010000, 8'h00, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 300", S_DECODE,    8'h87, 8'hF0, 24'h013000, 8'hF3, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 301", S_WRITEBACK, 8'h87, 8'hF0, 24'h0130F1, 8'hF3, 1'b0, 1'b0);

        // LDI R2, 03 (counter)
        @(negedge tb_clk); check("cycle 302", S_FETCH1,    8'h87, 8'hF0, 24'h0130F1, 8'hF1, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 303", S_FETCH2,    8'h88, 8'hF0, 24'h0130F1, 8'hF1, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 304", S_FETCH3,    8'h89, 8'hF0, 24'h0130F1, 8'hF1, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 305", S_DECODE,    8'h8A, 8'hF0, 24'h0120F1, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 306", S_WRITEBACK, 8'h8A, 8'hF0, 24'h012003, 8'h54, 1'b0, 1'b0);

        // loop: LDR R1, [R3] (R1 = MEM[pointer])
        @(negedge tb_clk); check("cycle 307", S_FETCH1,    8'h8A, 8'hF0, 24'h012003, 8'h03, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 308", S_FETCH2,    8'h8B, 8'hF0, 24'h012003, 8'h03, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 309", S_FETCH3,    8'h8C, 8'hF0, 24'h182003, 8'h03, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 310", S_DECODE,    8'h8D, 8'hF0, 24'h181303, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 311", S_EXECUTE,   8'h8D, 8'hF0, 24'h181300, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 312", S_WRITEBACK, 8'h8D, 8'hF0, 24'h181300, 8'h3B, 1'b0, 1'b0);

        // ADD R0, R1 (sum)
        @(negedge tb_clk); check("cycle 313", S_FETCH1,    8'h8D, 8'hF0, 24'h181300, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 314", S_FETCH2,    8'h8E, 8'hF0, 24'h181300, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 315", S_FETCH3,    8'h8F, 8'hF0, 24'h051300, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 316", S_DECODE,    8'h90, 8'hF0, 24'h050100, 8'h00, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 317", S_EXECUTE,   8'h90, 8'hF0, 24'h050100, 8'h00, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 318", S_WRITEBACK, 8'h90, 8'hF0, 24'h050100, 8'h00, 1'b0, 1'b0);

        // INC R3 (next byte)
        @(negedge tb_clk); check("cycle 319", S_FETCH1,    8'h90, 8'hF0, 24'h050100, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 320", S_FETCH2,    8'h91, 8'hF0, 24'h050100, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 321", S_FETCH3,    8'h92, 8'hF0, 24'h120100, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 322", S_DECODE,    8'h93, 8'hF0, 24'h123000, 8'hF1, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 323", S_EXECUTE,   8'h93, 8'hF0, 24'h123000, 8'hF1, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 324", S_WRITEBACK, 8'h93, 8'hF0, 24'h123000, 8'hF1, 1'b0, 1'b0);

        // DEC R2
        @(negedge tb_clk); check("cycle 325", S_FETCH1,    8'h93, 8'hF0, 24'h123000, 8'hF2, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 326", S_FETCH2,    8'h94, 8'hF0, 24'h123000, 8'hF2, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 327", S_FETCH3,    8'h95, 8'hF0, 24'h133000, 8'hF2, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 328", S_DECODE,    8'h96, 8'hF0, 24'h132000, 8'h03, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 329", S_EXECUTE,   8'h96, 8'hF0, 24'h132000, 8'h03, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 330", S_WRITEBACK, 8'h96, 8'hF0, 24'h132000, 8'h03, 1'b0, 1'b0);

        // JNZ 8A
        @(negedge tb_clk); check("cycle 331", S_FETCH1,    8'h96, 8'hF0, 24'h132000, 8'h02, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 332", S_FETCH2,    8'h97, 8'hF0, 24'h132000, 8'h02, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 333", S_FETCH3,    8'h98, 8'hF0, 24'h0E2000, 8'h02, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 334", S_DECODE,    8'h99, 8'hF0, 24'h0E0000, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 335", S_EXECUTE,   8'h99, 8'hF0, 24'h0E008A, 8'h57, 1'b0, 1'b0);

        // loop: LDR R1, [R3] (R1 = MEM[pointer])
        @(negedge tb_clk); check("cycle 336", S_FETCH1,    8'h8A, 8'hF0, 24'h0E008A, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 337", S_FETCH2,    8'h8B, 8'hF0, 24'h0E008A, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 338", S_FETCH3,    8'h8C, 8'hF0, 24'h18008A, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 339", S_DECODE,    8'h8D, 8'hF0, 24'h18138A, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 340", S_EXECUTE,   8'h8D, 8'hF0, 24'h181300, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 341", S_WRITEBACK, 8'h8D, 8'hF0, 24'h181300, 8'h57, 1'b0, 1'b0);

        // ADD R0, R1 (sum)
        @(negedge tb_clk); check("cycle 342", S_FETCH1,    8'h8D, 8'hF0, 24'h181300, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 343", S_FETCH2,    8'h8E, 8'hF0, 24'h181300, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 344", S_FETCH3,    8'h8F, 8'hF0, 24'h051300, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 345", S_DECODE,    8'h90, 8'hF0, 24'h050100, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 346", S_EXECUTE,   8'h90, 8'hF0, 24'h050100, 8'h57, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 347", S_WRITEBACK, 8'h90, 8'hF0, 24'h050100, 8'h57, 1'b0, 1'b0);

        // INC R3 (next byte)
        @(negedge tb_clk); check("cycle 348", S_FETCH1,    8'h90, 8'hF0, 24'h050100, 8'h92, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 349", S_FETCH2,    8'h91, 8'hF0, 24'h050100, 8'h92, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 350", S_FETCH3,    8'h92, 8'hF0, 24'h120100, 8'h92, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 351", S_DECODE,    8'h93, 8'hF0, 24'h123000, 8'hF2, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 352", S_EXECUTE,   8'h93, 8'hF0, 24'h123000, 8'hF2, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 353", S_WRITEBACK, 8'h93, 8'hF0, 24'h123000, 8'hF2, 1'b0, 1'b0);

        // DEC R2
        @(negedge tb_clk); check("cycle 354", S_FETCH1,    8'h93, 8'hF0, 24'h123000, 8'hF3, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 355", S_FETCH2,    8'h94, 8'hF0, 24'h123000, 8'hF3, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 356", S_FETCH3,    8'h95, 8'hF0, 24'h133000, 8'hF3, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 357", S_DECODE,    8'h96, 8'hF0, 24'h132000, 8'h02, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 358", S_EXECUTE,   8'h96, 8'hF0, 24'h132000, 8'h02, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 359", S_WRITEBACK, 8'h96, 8'hF0, 24'h132000, 8'h02, 1'b0, 1'b0);

        // JNZ 8A
        @(negedge tb_clk); check("cycle 360", S_FETCH1,    8'h96, 8'hF0, 24'h132000, 8'h01, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 361", S_FETCH2,    8'h97, 8'hF0, 24'h132000, 8'h01, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 362", S_FETCH3,    8'h98, 8'hF0, 24'h0E2000, 8'h01, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 363", S_DECODE,    8'h99, 8'hF0, 24'h0E0000, 8'h92, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 364", S_EXECUTE,   8'h99, 8'hF0, 24'h0E008A, 8'h92, 1'b0, 1'b0);

        // loop: LDR R1, [R3] (R1 = MEM[pointer])
        @(negedge tb_clk); check("cycle 365", S_FETCH1,    8'h8A, 8'hF0, 24'h0E008A, 8'h92, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 366", S_FETCH2,    8'h8B, 8'hF0, 24'h0E008A, 8'h92, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 367", S_FETCH3,    8'h8C, 8'hF0, 24'h18008A, 8'h92, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 368", S_DECODE,    8'h8D, 8'hF0, 24'h18138A, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 369", S_EXECUTE,   8'h8D, 8'hF0, 24'h181300, 8'h3B, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 370", S_WRITEBACK, 8'h8D, 8'hF0, 24'h181300, 8'h3B, 1'b0, 1'b0);

        // ADD R0, R1 (sum)
        @(negedge tb_clk); check("cycle 371", S_FETCH1,    8'h8D, 8'hF0, 24'h181300, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 372", S_FETCH2,    8'h8E, 8'hF0, 24'h181300, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 373", S_FETCH3,    8'h8F, 8'hF0, 24'h051300, 8'h54, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 374", S_DECODE,    8'h90, 8'hF0, 24'h050100, 8'h92, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 375", S_EXECUTE,   8'h90, 8'hF0, 24'h050100, 8'h92, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 376", S_WRITEBACK, 8'h90, 8'hF0, 24'h050100, 8'h92, 1'b0, 1'b0);

        // INC R3 (next byte)
        @(negedge tb_clk); check("cycle 377", S_FETCH1,    8'h90, 8'hF0, 24'h050100, 8'hE6, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 378", S_FETCH2,    8'h91, 8'hF0, 24'h050100, 8'hE6, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 379", S_FETCH3,    8'h92, 8'hF0, 24'h120100, 8'hE6, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 380", S_DECODE,    8'h93, 8'hF0, 24'h123000, 8'hF3, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 381", S_EXECUTE,   8'h93, 8'hF0, 24'h123000, 8'hF3, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 382", S_WRITEBACK, 8'h93, 8'hF0, 24'h123000, 8'hF3, 1'b0, 1'b0);

        // DEC R2
        @(negedge tb_clk); check("cycle 383", S_FETCH1,    8'h93, 8'hF0, 24'h123000, 8'hF4, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 384", S_FETCH2,    8'h94, 8'hF0, 24'h123000, 8'hF4, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 385", S_FETCH3,    8'h95, 8'hF0, 24'h133000, 8'hF4, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 386", S_DECODE,    8'h96, 8'hF0, 24'h132000, 8'h01, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 387", S_EXECUTE,   8'h96, 8'hF0, 24'h132000, 8'h01, 1'b0, 1'b0);
        @(negedge tb_clk); check("cycle 388", S_WRITEBACK, 8'h96, 8'hF0, 24'h132000, 8'h01, 1'b1, 1'b0);

        // JNZ 8A
        @(negedge tb_clk); check("cycle 389", S_FETCH1,    8'h96, 8'hF0, 24'h132000, 8'h00, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 390", S_FETCH2,    8'h97, 8'hF0, 24'h132000, 8'h00, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 391", S_FETCH3,    8'h98, 8'hF0, 24'h0E2000, 8'h00, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 392", S_DECODE,    8'h99, 8'hF0, 24'h0E0000, 8'hE6, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 393", S_EXECUTE,   8'h99, 8'hF0, 24'h0E008A, 8'hE6, 1'b1, 1'b0);

        // JMP 99 (halt loop: R0 = E6 = 57 + 3B + 54)
        @(negedge tb_clk); check("cycle 394", S_FETCH1,    8'h99, 8'hF0, 24'h0E008A, 8'hE6, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 395", S_FETCH2,    8'h9A, 8'hF0, 24'h0E008A, 8'hE6, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 396", S_FETCH3,    8'h9B, 8'hF0, 24'h0C008A, 8'hE6, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 397", S_DECODE,    8'h9C, 8'hF0, 24'h0C008A, 8'hE6, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 398", S_EXECUTE,   8'h9C, 8'hF0, 24'h0C0099, 8'hE6, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 399", S_FETCH1,    8'h99, 8'hF0, 24'h0C0099, 8'hE6, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 400", S_FETCH2,    8'h9A, 8'hF0, 24'h0C0099, 8'hE6, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 401", S_FETCH3,    8'h9B, 8'hF0, 24'h0C0099, 8'hE6, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 402", S_DECODE,    8'h9C, 8'hF0, 24'h0C0099, 8'hE6, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 403", S_EXECUTE,   8'h9C, 8'hF0, 24'h0C0099, 8'hE6, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 404", S_FETCH1,    8'h99, 8'hF0, 24'h0C0099, 8'hE6, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 405", S_FETCH2,    8'h9A, 8'hF0, 24'h0C0099, 8'hE6, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 406", S_FETCH3,    8'h9B, 8'hF0, 24'h0C0099, 8'hE6, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 407", S_DECODE,    8'h9C, 8'hF0, 24'h0C0099, 8'hE6, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 408", S_EXECUTE,   8'h9C, 8'hF0, 24'h0C0099, 8'hE6, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 409", S_FETCH1,    8'h99, 8'hF0, 24'h0C0099, 8'hE6, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 410", S_FETCH2,    8'h9A, 8'hF0, 24'h0C0099, 8'hE6, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 411", S_FETCH3,    8'h9B, 8'hF0, 24'h0C0099, 8'hE6, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 412", S_DECODE,    8'h9C, 8'hF0, 24'h0C0099, 8'hE6, 1'b1, 1'b0);
        @(negedge tb_clk); check("cycle 413", S_EXECUTE,   8'h9C, 8'hF0, 24'h0C0099, 8'hE6, 1'b1, 1'b0);

        $display("all tests completed and passed");
        $finish;
    end
endmodule