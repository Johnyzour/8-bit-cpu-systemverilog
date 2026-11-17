//------------------------------------------------------------------------------
// File        : tb_run.sv
// Description : Program runner for the CPU (not a self-checking testbench).
//               Runs whatever program memory.sv loaded from program.mem
//               until it reaches its halt loop, then prints the result and
//               ends the simulation.
// Notes       : The halt loop is a JMP to its own address. In each FETCH1 the
//               IR holds the instruction fetched at the previous FETCH1, so
//               the halt is detected when the IR is a JMP whose target equals
//               that previous fetch address (one pass after the first fetch
//               of the halt instruction). A JMP to any other address is not a
//               halt, even though the next fetch is at its target.
//               Prints the cycle count, PC, SP, Z, C, R0-R3 and the memory
//               rows F0-FF (data) and E0-EF (stack), read through
//               hierarchical references into the design.
//               Stops with an error if no halt is reached within MAX_CYCLES.
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_run;
    import cpu_pkg::*;

    localparam int MAX_CYCLES = 20000;

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

    // one memory row of 16 bytes as hex text
    function automatic string mem_row (input int base);
        string s = "";
        for (int i = 0; i < 16; i++)
            s = {s, $sformatf(" %02h", uut.u_memory.mem[base + i])};
        return s.toupper();
    endfunction

    initial
    begin
        automatic int               cycle    = 0;
        automatic logic [7:0]       fetch_pc = 8'h00;   // address of the instruction in the IR

        // reset at the first rising edge, as in tb_cpu
        @(negedge tb_clk);
        tb_rst = 1'b0;

        forever
        begin
            if (tb_state_dbg == S_FETCH1)
                begin
                    // halt loop: the IR holds a JMP to its own address
                    if (cycle > 0 && tb_instr_dbg[23:16] == OP_JMP && tb_instr_dbg[7:0] == fetch_pc)
                        break;
                    fetch_pc = tb_pc_dbg;      // the instruction fetched now starts here
                end
            if (cycle >= MAX_CYCLES)
                $fatal(1, "no halt loop within %0d cycles (PC = %h)", MAX_CYCLES, tb_pc_dbg);
            @(negedge tb_clk);
            cycle++;
        end

        $display("halted at cycle %0d: PC = %h, SP = %h, Z = %b, C = %b",
                 cycle, tb_pc_dbg, tb_sp_dbg, tb_z_dbg, tb_c_dbg);
        $display("R0-R3 : %h %h %h %h",
                 uut.u_reg_file.regs[0], uut.u_reg_file.regs[1],
                 uut.u_reg_file.regs[2], uut.u_reg_file.regs[3]);
        $display("        +0 +1 +2 +3 +4 +5 +6 +7 +8 +9 +A +B +C +D +E +F");
        $display("MEM F0:%s", mem_row(8'hF0));
        $display("MEM E0:%s", mem_row(8'hE0));
        $finish;
    end
endmodule