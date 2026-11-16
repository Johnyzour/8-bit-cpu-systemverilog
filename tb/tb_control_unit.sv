//------------------------------------------------------------------------------
// File        : tb_control_unit.sv
// Description : Self-checking testbench for the multi-cycle control FSM.
//               Steps every opcode through its state sequence (FETCH1-3,
//               DECODE, EXECUTE, WRITEBACK as applicable), checking the state
//               and all control outputs in each state, including the IR byte
//               loads, the memory address and data selects, the stack pointer
//               enables and the PC source select. Covers each conditional jump
//               taken and not taken, PUSH, POP, CALL, RET, LDR and STR, an
//               unused opcode (treated as NOP), and reset in the middle of an
//               instruction.
// Notes       : The opcode changes only during FETCH1, as the IR would load it.
//               Prints "all tests completed and passed" at 1700 ns.
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_control_unit;
    import cpu_pkg::*;

    logic       tb_clk    = 1'b0;
    logic       tb_rst    = 1'b1;
    logic [7:0] tb_opcode = '0;
    logic       tb_z_flag = 1'b0;
    logic       tb_c_flag = 1'b0;
    logic       tb_reg_wr_en;
    logic [1:0] tb_wb_sel;
    logic [3:0] tb_alu_sel;
    logic       tb_mem_wr_en;
    logic       tb_z_load;
    logic       tb_c_load;
    logic       tb_pc_load;
    logic       tb_pc_inc;
    logic [2:0] tb_ir_load;
    logic [1:0] tb_mem_addr_sel;
    logic       tb_sp_inc;
    logic       tb_sp_dec;
    logic       tb_mem_data_sel;
    logic       tb_pc_src_sel;
    state_t     tb_state_out;

    control_unit uut (
        .clk          (tb_clk),
        .rst          (tb_rst),
        .opcode       (tb_opcode),
        .z_flag       (tb_z_flag),
        .c_flag       (tb_c_flag),
        .reg_wr_en    (tb_reg_wr_en),
        .wb_sel       (tb_wb_sel),
        .alu_sel      (tb_alu_sel),
        .mem_wr_en    (tb_mem_wr_en),
        .z_load       (tb_z_load),
        .c_load       (tb_c_load),
        .pc_load      (tb_pc_load),
        .pc_inc       (tb_pc_inc),
        .ir_load      (tb_ir_load),
        .mem_addr_sel (tb_mem_addr_sel),
        .sp_inc       (tb_sp_inc),
        .sp_dec       (tb_sp_dec),
        .mem_data_sel (tb_mem_data_sel),
        .pc_src_sel   (tb_pc_src_sel),
        .state_out    (tb_state_out)
    );

    // 10 ns clock
    always #5 tb_clk = ~tb_clk;

    // compares one output and stops with its name on a mismatch
    task automatic expect_bits (input string name, input string sig, input logic [3:0] actual, input logic [3:0] expected);
        assert (actual === expected)
            else $fatal(1, "%s failed: %s = %b, expected %b", name, sig, actual, expected);
    endtask

    // core check: compares the state and all 14 control outputs.
    // Enables, ir_load, mem_addr_sel and sp_inc/sp_dec are always checked;
    // the opcode selects (alu, wb, mds, pcs) only when chk_sel is 1.
    task automatic check (input string      name,
                          input state_t     st,
                          input logic [2:0] ir_ld,
                          input logic       pc_i,
                          input logic       pc_l,
                          input logic       reg_we,
                          input logic       mem_we,
                          input logic       z_ld,
                          input logic       c_ld,
                          input logic       s_i,
                          input logic       s_d,
                          input logic       mds,
                          input logic       pcs,
                          input logic [3:0] alu,
                          input logic [1:0] wb,
                          input logic [1:0] mem,
                          input logic       chk_sel);
        assert (tb_state_out === st)
            else $fatal(1, "%s failed: state is %s", name, tb_state_out.name());
        expect_bits(name, "ir_load",      tb_ir_load,      ir_ld);
        expect_bits(name, "pc_inc",       tb_pc_inc,       pc_i);
        expect_bits(name, "pc_load",      tb_pc_load,      pc_l);
        expect_bits(name, "reg_wr_en",    tb_reg_wr_en,    reg_we);
        expect_bits(name, "mem_wr_en",    tb_mem_wr_en,    mem_we);
        expect_bits(name, "z_load",       tb_z_load,       z_ld);
        expect_bits(name, "c_load",       tb_c_load,       c_ld);
        expect_bits(name, "mem_addr_sel", tb_mem_addr_sel, mem);
        expect_bits(name, "sp_inc",       tb_sp_inc,       s_i);
        expect_bits(name, "sp_dec",       tb_sp_dec,       s_d);
        if (chk_sel)
            begin
                expect_bits(name, "alu_sel",      tb_alu_sel,      alu);
                expect_bits(name, "wb_sel",       tb_wb_sel,       wb);
                expect_bits(name, "mem_data_sel", tb_mem_data_sel, mds);
                expect_bits(name, "pc_src_sel",   tb_pc_src_sel,   pcs);
            end
    endtask

    // one wrapper per state: fixed values are filled in, only the values
    // that vary per opcode are passed in.
    // FETCH1-3: pc_inc = 1, ir_load = 000/100/010, address = PC.
    // Selects are not checked: the IR still holds the previous opcode.
    task automatic fetch1 (input string name);
        check({name, " fetch1"}, S_FETCH1, 3'b000, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, MEMD_REG, PCSRC_IMM, ALU_ADD, WB_ALU, ADDR_PC, 1'b0);
    endtask

    task automatic fetch2 (input string name);
        check({name, " fetch2"}, S_FETCH2, 3'b100, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, MEMD_REG, PCSRC_IMM, ALU_ADD, WB_ALU, ADDR_PC, 1'b0);
    endtask

    task automatic fetch3 (input string name);
        check({name, " fetch3"}, S_FETCH3, 3'b010, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, MEMD_REG, PCSRC_IMM, ALU_ADD, WB_ALU, ADDR_PC, 1'b0);
    endtask

    // DECODE: ir_load = 001 (imm byte), address = PC.
    // Passed in: s_d (1 for PUSH and CALL), then the selects.
    task automatic decode (input string      name,
                           input logic       s_d,
                           input logic [3:0] alu,
                           input logic [1:0] wb,
                           input logic       mds,
                           input logic       pcs);
        check({name, " decode"}, S_DECODE, 3'b001, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, s_d, mds, pcs, alu, wb, ADDR_PC, 1'b1);
    endtask

    // EXECUTE: no ir_load, pc_inc, reg_wr_en or sp_dec.
    // Passed in: pc_l, mem_we, z_ld, c_ld, s_i (1 for POP and RET),
    // then alu, wb, the memory address select and mds, pcs.
    task automatic execute (input string      name,
                            input logic       pc_l,
                            input logic       mem_we,
                            input logic       z_ld,
                            input logic       c_ld,
                            input logic       s_i,
                            input logic [3:0] alu,
                            input logic [1:0] wb,
                            input logic [1:0] mem,
                            input logic       mds,
                            input logic       pcs);
        check({name, " execute"}, S_EXECUTE, 3'b000, 1'b0, pc_l, 1'b0, mem_we, z_ld, c_ld, s_i, 1'b0, mds, pcs, alu, wb, mem, 1'b1);
    endtask

    // WRITEBACK: address = PC, no memory, flag or SP activity.
    // Passed in: pc_l and reg_we (RET = 1, 0; all others = 0, 1),
    // then the selects.
    task automatic writeback (input string      name,
                              input logic       pc_l,
                              input logic       reg_we,
                              input logic [3:0] alu,
                              input logic [1:0] wb,
                              input logic       mds,
                              input logic       pcs);
        check({name, " writeback"}, S_WRITEBACK, 3'b000, 1'b0, pc_l, reg_we, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, mds, pcs, alu, wb, ADDR_PC, 1'b1);
    endtask

    initial
    begin
        // reset was applied at the first rising edge
        @(negedge tb_clk);
        tb_rst = 1'b0;
        fetch1("reset");

        // test1: NOP (F1 F2 F3 D E)
        tb_opcode = OP_NOP; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 1 NOP");
        @(negedge tb_clk); fetch3("test 1 NOP");
        @(negedge tb_clk); decode("test 1 NOP", 1'b0, ALU_ADD, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 1 NOP", 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, ALU_ADD, WB_ALU, ADDR_PC, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 1 NOP");

        // test2: LDI (F1 F2 F3 D W, skips EXECUTE)
        tb_opcode = OP_LDI; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 2 LDI");
        @(negedge tb_clk); fetch3("test 2 LDI");
        @(negedge tb_clk); decode("test 2 LDI", 1'b0, ALU_ADD, WB_IMM, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); writeback("test 2 LDI", 1'b0, 1'b1, ALU_ADD, WB_IMM, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 2 LDI");

        // test3: MOV (F1 F2 F3 D W, skips EXECUTE)
        tb_opcode = OP_MOV; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 3 MOV");
        @(negedge tb_clk); fetch3("test 3 MOV");
        @(negedge tb_clk); decode("test 3 MOV", 1'b0, ALU_ADD, WB_REG, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); writeback("test 3 MOV", 1'b0, 1'b1, ALU_ADD, WB_REG, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 3 MOV");

        // test4: LD (F1 F2 F3 D E W, memory address = imm in EXECUTE)
        tb_opcode = OP_LD; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 4 LD");
        @(negedge tb_clk); fetch3("test 4 LD");
        @(negedge tb_clk); decode("test 4 LD", 1'b0, ALU_ADD, WB_RAM, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 4 LD", 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, ALU_ADD, WB_RAM, ADDR_IMM, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); writeback("test 4 LD", 1'b0, 1'b1, ALU_ADD, WB_RAM, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 4 LD");

        // test5: ST (F1 F2 F3 D E, write at address imm)
        tb_opcode = OP_ST; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 5 ST");
        @(negedge tb_clk); fetch3("test 5 ST");
        @(negedge tb_clk); decode("test 5 ST", 1'b0, ALU_ADD, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 5 ST", 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, ALU_ADD, WB_ALU, ADDR_IMM, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 5 ST");

        // test6: ADD (F1 F2 F3 D E W)
        tb_opcode = OP_ADD; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 6 ADD");
        @(negedge tb_clk); fetch3("test 6 ADD");
        @(negedge tb_clk); decode("test 6 ADD", 1'b0, ALU_ADD, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 6 ADD", 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, ALU_ADD, WB_ALU, ADDR_PC, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); writeback("test 6 ADD", 1'b0, 1'b1, ALU_ADD, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 6 ADD");

        // test7: SUB (F1 F2 F3 D E W)
        tb_opcode = OP_SUB; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 7 SUB");
        @(negedge tb_clk); fetch3("test 7 SUB");
        @(negedge tb_clk); decode("test 7 SUB", 1'b0, ALU_SUB, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 7 SUB", 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, ALU_SUB, WB_ALU, ADDR_PC, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); writeback("test 7 SUB", 1'b0, 1'b1, ALU_SUB, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 7 SUB");

        // test8: AND (F1 F2 F3 D E W, Z only)
        tb_opcode = OP_AND; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 8 AND");
        @(negedge tb_clk); fetch3("test 8 AND");
        @(negedge tb_clk); decode("test 8 AND", 1'b0, ALU_AND, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 8 AND", 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, ALU_AND, WB_ALU, ADDR_PC, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); writeback("test 8 AND", 1'b0, 1'b1, ALU_AND, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 8 AND");

        // test9: OR (F1 F2 F3 D E W, Z only)
        tb_opcode = OP_OR; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 9 OR");
        @(negedge tb_clk); fetch3("test 9 OR");
        @(negedge tb_clk); decode("test 9 OR", 1'b0, ALU_OR, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 9 OR", 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, ALU_OR, WB_ALU, ADDR_PC, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); writeback("test 9 OR", 1'b0, 1'b1, ALU_OR, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 9 OR");

        // test10: XOR (F1 F2 F3 D E W, Z only)
        tb_opcode = OP_XOR; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 10 XOR");
        @(negedge tb_clk); fetch3("test 10 XOR");
        @(negedge tb_clk); decode("test 10 XOR", 1'b0, ALU_XOR, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 10 XOR", 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, ALU_XOR, WB_ALU, ADDR_PC, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); writeback("test 10 XOR", 1'b0, 1'b1, ALU_XOR, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 10 XOR");

        // test11: NOT (F1 F2 F3 D E W, Z only)
        tb_opcode = OP_NOT; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 11 NOT");
        @(negedge tb_clk); fetch3("test 11 NOT");
        @(negedge tb_clk); decode("test 11 NOT", 1'b0, ALU_NOT, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 11 NOT", 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, ALU_NOT, WB_ALU, ADDR_PC, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); writeback("test 11 NOT", 1'b0, 1'b1, ALU_NOT, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 11 NOT");

        // test12: CMP (F1 F2 F3 D E, flags but no writeback)
        tb_opcode = OP_CMP; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 12 CMP");
        @(negedge tb_clk); fetch3("test 12 CMP");
        @(negedge tb_clk); decode("test 12 CMP", 1'b0, ALU_SUB, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 12 CMP", 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, ALU_SUB, WB_ALU, ADDR_PC, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 12 CMP");

        // test13: JMP (F1 F2 F3 D E, always taken)
        tb_opcode = OP_JMP; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 13 JMP");
        @(negedge tb_clk); fetch3("test 13 JMP");
        @(negedge tb_clk); decode("test 13 JMP", 1'b0, ALU_ADD, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 13 JMP", 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, ALU_ADD, WB_ALU, ADDR_PC, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 13 JMP");

        // test14: JZ taken (z = 1)
        tb_opcode = OP_JZ; tb_z_flag = 1'b1; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 14 JZ");
        @(negedge tb_clk); fetch3("test 14 JZ");
        @(negedge tb_clk); decode("test 14 JZ", 1'b0, ALU_ADD, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 14 JZ", 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, ALU_ADD, WB_ALU, ADDR_PC, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 14 JZ");

        // test15: JZ not taken (z = 0)
        tb_opcode = OP_JZ; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 15 JZ");
        @(negedge tb_clk); fetch3("test 15 JZ");
        @(negedge tb_clk); decode("test 15 JZ", 1'b0, ALU_ADD, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 15 JZ", 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, ALU_ADD, WB_ALU, ADDR_PC, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 15 JZ");

        // test16: JNZ taken (z = 0)
        tb_opcode = OP_JNZ; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 16 JNZ");
        @(negedge tb_clk); fetch3("test 16 JNZ");
        @(negedge tb_clk); decode("test 16 JNZ", 1'b0, ALU_ADD, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 16 JNZ", 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, ALU_ADD, WB_ALU, ADDR_PC, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 16 JNZ");

        // test17: JNZ not taken (z = 1)
        tb_opcode = OP_JNZ; tb_z_flag = 1'b1; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 17 JNZ");
        @(negedge tb_clk); fetch3("test 17 JNZ");
        @(negedge tb_clk); decode("test 17 JNZ", 1'b0, ALU_ADD, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 17 JNZ", 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, ALU_ADD, WB_ALU, ADDR_PC, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 17 JNZ");

        // test18: JC taken (c = 1)
        tb_opcode = OP_JC; tb_z_flag = 1'b0; tb_c_flag = 1'b1;
        @(negedge tb_clk); fetch2("test 18 JC");
        @(negedge tb_clk); fetch3("test 18 JC");
        @(negedge tb_clk); decode("test 18 JC", 1'b0, ALU_ADD, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 18 JC", 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, ALU_ADD, WB_ALU, ADDR_PC, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 18 JC");

        // test19: JC ignores z (z = 1, c = 0)
        tb_opcode = OP_JC; tb_z_flag = 1'b1; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 19 JC");
        @(negedge tb_clk); fetch3("test 19 JC");
        @(negedge tb_clk); decode("test 19 JC", 1'b0, ALU_ADD, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 19 JC", 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, ALU_ADD, WB_ALU, ADDR_PC, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 19 JC");

        // test20: SHL (F1 F2 F3 D E W, Z and C)
        tb_opcode = OP_SHL; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 20 SHL");
        @(negedge tb_clk); fetch3("test 20 SHL");
        @(negedge tb_clk); decode("test 20 SHL", 1'b0, ALU_SHL, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 20 SHL", 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, ALU_SHL, WB_ALU, ADDR_PC, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); writeback("test 20 SHL", 1'b0, 1'b1, ALU_SHL, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 20 SHL");

        // test21: SHR (F1 F2 F3 D E W, Z and C)
        tb_opcode = OP_SHR; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 21 SHR");
        @(negedge tb_clk); fetch3("test 21 SHR");
        @(negedge tb_clk); decode("test 21 SHR", 1'b0, ALU_SHR, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 21 SHR", 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, ALU_SHR, WB_ALU, ADDR_PC, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); writeback("test 21 SHR", 1'b0, 1'b1, ALU_SHR, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 21 SHR");

        // test22: INC (F1 F2 F3 D E W, Z and C)
        tb_opcode = OP_INC; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 22 INC");
        @(negedge tb_clk); fetch3("test 22 INC");
        @(negedge tb_clk); decode("test 22 INC", 1'b0, ALU_INC, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 22 INC", 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, ALU_INC, WB_ALU, ADDR_PC, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); writeback("test 22 INC", 1'b0, 1'b1, ALU_INC, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 22 INC");

        // test23: DEC (F1 F2 F3 D E W, Z and C)
        tb_opcode = OP_DEC; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 23 DEC");
        @(negedge tb_clk); fetch3("test 23 DEC");
        @(negedge tb_clk); decode("test 23 DEC", 1'b0, ALU_DEC, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 23 DEC", 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, ALU_DEC, WB_ALU, ADDR_PC, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); writeback("test 23 DEC", 1'b0, 1'b1, ALU_DEC, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 23 DEC");

        // test24: unused opcode FF behaves as NOP (F1 F2 F3 D E, no enables)
        tb_opcode = 8'hFF; tb_z_flag = 1'b1; tb_c_flag = 1'b1;
        @(negedge tb_clk); fetch2("test 24 unused");
        @(negedge tb_clk); fetch3("test 24 unused");
        @(negedge tb_clk); decode("test 24 unused", 1'b0, ALU_ADD, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 24 unused", 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, ALU_ADD, WB_ALU, ADDR_PC, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 24 unused");

        // test25: PUSH (F1 F2 F3 D E, SP-1 in DECODE, write at SP)
        tb_opcode = OP_PUSH; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 25 PUSH");
        @(negedge tb_clk); fetch3("test 25 PUSH");
        @(negedge tb_clk); decode("test 25 PUSH", 1'b1, ALU_ADD, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 25 PUSH", 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, ALU_ADD, WB_ALU, ADDR_SP, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 25 PUSH");

        // test26: POP (F1 F2 F3 D E W, read at SP and SP+1, write rd)
        tb_opcode = OP_POP; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 26 POP");
        @(negedge tb_clk); fetch3("test 26 POP");
        @(negedge tb_clk); decode("test 26 POP", 1'b0, ALU_ADD, WB_RAM, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 26 POP", 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, ALU_ADD, WB_RAM, ADDR_SP, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); writeback("test 26 POP", 1'b0, 1'b1, ALU_ADD, WB_RAM, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 26 POP");

        // test27: CALL (F1 F2 F3 D E, SP-1 in DECODE, write PC at SP and jump)
        tb_opcode = OP_CALL; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 27 CALL");
        @(negedge tb_clk); fetch3("test 27 CALL");
        @(negedge tb_clk); decode("test 27 CALL", 1'b1, ALU_ADD, WB_ALU, MEMD_PC, PCSRC_IMM);
        @(negedge tb_clk); execute("test 27 CALL", 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, ALU_ADD, WB_ALU, ADDR_SP, MEMD_PC, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 27 CALL");

        // test28: RET (F1 F2 F3 D E W, read at SP and SP+1, PC from memory)
        tb_opcode = OP_RET; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 28 RET");
        @(negedge tb_clk); fetch3("test 28 RET");
        @(negedge tb_clk); decode("test 28 RET", 1'b0, ALU_ADD, WB_ALU, MEMD_REG, PCSRC_MEM);
        @(negedge tb_clk); execute("test 28 RET", 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, ALU_ADD, WB_ALU, ADDR_SP, MEMD_REG, PCSRC_MEM);
        @(negedge tb_clk); writeback("test 28 RET", 1'b1, 1'b0, ALU_ADD, WB_ALU, MEMD_REG, PCSRC_MEM);
        @(negedge tb_clk); fetch1("test 28 RET");

        // test29: LDR (F1 F2 F3 D E W, memory address = rs register in EXECUTE)
        tb_opcode = OP_LDR; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 29 LDR");
        @(negedge tb_clk); fetch3("test 29 LDR");
        @(negedge tb_clk); decode("test 29 LDR", 1'b0, ALU_ADD, WB_RAM, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 29 LDR", 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, ALU_ADD, WB_RAM, ADDR_REG, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); writeback("test 29 LDR", 1'b0, 1'b1, ALU_ADD, WB_RAM, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 29 LDR");

        // test30: STR (F1 F2 F3 D E, write at address in rs register)
        tb_opcode = OP_STR; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 30 STR");
        @(negedge tb_clk); fetch3("test 30 STR");
        @(negedge tb_clk); decode("test 30 STR", 1'b0, ALU_ADD, WB_ALU, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); execute("test 30 STR", 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, ALU_ADD, WB_ALU, ADDR_REG, MEMD_REG, PCSRC_IMM);
        @(negedge tb_clk); fetch1("test 30 STR");

        // test31: reset during DECODE returns to FETCH1, then resumes
        tb_opcode = OP_ADD; tb_z_flag = 1'b0; tb_c_flag = 1'b0;
        @(negedge tb_clk); fetch2("test 31 ADD");
        @(negedge tb_clk); fetch3("test 31 ADD");
        @(negedge tb_clk); decode("test 31 ADD", 1'b0, ALU_ADD, WB_ALU, MEMD_REG, PCSRC_IMM);
        tb_rst = 1'b1;
        @(negedge tb_clk); fetch1("test 31 reset");
        tb_rst = 1'b0;
        @(negedge tb_clk); fetch2("test 31 resume");

        $display("all tests completed and passed");
        $finish;
    end
endmodule