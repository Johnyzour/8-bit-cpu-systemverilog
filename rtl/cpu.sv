//------------------------------------------------------------------------------
// File        : cpu.sv
// Description : Top level of the 8-bit multi-cycle von Neumann CPU.
//               Instantiates and wires the PC, stack pointer, shared memory,
//               memory address and data muxes, PC source mux, instruction
//               register, control FSM, register file, ALU, flags register and
//               writeback mux.
// Notes       : One 256 x 8 memory holds the program, the data and the stack.
//               The address comes from the PC (fetch), imm (LD/ST), SP
//               (PUSH/POP/CALL/RET) or the rs register (LDR/STR), selected
//               by three mux2 arranged as a 4-to-1 mux. Memory write data is
//               a register, or the PC for CALL; the PC jump address is imm,
//               or the memory output for RET.
//               Instruction format (24-bit): opcode[23:16] | rd[15:12] |
//               rs[11:8] | imm[7:0], stored as three bytes and fetched one
//               byte per clock in FETCH1-3; only bits 13:12 and 9:8 select
//               R0-R3. Each instruction takes 5 or 6 clocks.
//               The *_dbg ports expose internal state for the testbench.
//------------------------------------------------------------------------------

module cpu
    import cpu_pkg::*;
(
    input  logic        clk,
    input  logic        rst,
    output logic [7:0]  pc_dbg,
    output logic [23:0] instr_dbg,
    output logic [7:0]  reg_a_dbg,
    output logic        z_dbg,
    output logic        c_dbg,
    output logic [7:0]  sp_dbg,
    output state_t      state_dbg
);
    logic [7:0]  pc_val;
    logic [23:0] instr;
    logic [7:0]  reg_a;
    logic [7:0]  reg_b;
    logic [7:0]  alu_result;
    logic        alu_zero;
    logic        alu_carry;
    logic        z_flag;
    logic        c_flag;
    logic [7:0]  mem_out;
    logic [7:0]  wb_data;
    logic        reg_wr_en;
    logic        mem_wr_en;
    logic        z_load;
    logic        c_load;
    logic        pc_load;
    logic        pc_inc;
    logic        sp_inc;
    logic        sp_dec;
    logic        mem_data_sel;
    logic        pc_src_sel;
    logic [1:0]  wb_sel;
    logic [3:0]  alu_sel;
    logic [7:0]  mem_addr;
    logic [1:0]  mem_addr_sel;
    logic [2:0]  ir_load;
    logic [7:0]  sp_val;
    logic [7:0]  addr_a;
    logic [7:0]  addr_b;
    logic [7:0]  mem_data_in;
    logic [7:0]  jump_addr;
    state_t      state;

    pc u_pc (
        .clk       (clk),
        .rst       (rst),
        .pc_inc    (pc_inc),
        .pc_load   (pc_load),
        .jump_addr (jump_addr),
        .pc_out    (pc_val)
    );

    memory u_memory (
        .clk      (clk),
        .wr_en    (mem_wr_en),
        .addr     (mem_addr),
        .data_in  (mem_data_in),
        .data_out (mem_out)
    );

    ir u_ir (
        .clk      (clk),
        .rst      (rst),
        .ir_load  (ir_load),
        .data_in  (mem_out),
        .data_out (instr)
    );

    control_unit u_control_unit (
        .clk          (clk),
        .rst          (rst),
        .opcode       (instr[23:16]),
        .z_flag       (z_flag),
        .c_flag       (c_flag),
        .reg_wr_en    (reg_wr_en),
        .wb_sel       (wb_sel),
        .alu_sel      (alu_sel),
        .mem_wr_en    (mem_wr_en),
        .z_load       (z_load),
        .c_load       (c_load),
        .pc_load      (pc_load),
        .pc_inc       (pc_inc),
        .ir_load      (ir_load),
        .mem_addr_sel (mem_addr_sel),
        .sp_inc       (sp_inc),
        .sp_dec       (sp_dec),
        .mem_data_sel (mem_data_sel),
        .pc_src_sel   (pc_src_sel),
        .state_out    (state)
    );

    reg_file u_reg_file (
        .clk       (clk),
        .rst       (rst),
        .wr_en     (reg_wr_en),
        .wr_sel    (instr[13:12]),
        .wr_data   (wb_data),
        .rd_sel_a  (instr[13:12]),
        .rd_sel_b  (instr[9:8]),
        .rd_data_a (reg_a),
        .rd_data_b (reg_b)
    );

    alu u_alu (
        .a       (reg_a),
        .b       (reg_b),
        .alu_sel (alu_sel),
        .result  (alu_result),
        .zero    (alu_zero),
        .carry   (alu_carry)
    );

    flags_reg u_flags_reg (
        .clk    (clk),
        .rst    (rst),
        .z_load (z_load),
        .c_load (c_load),
        .z_in   (alu_zero),
        .c_in   (alu_carry),
        .z_out  (z_flag),
        .c_out  (c_flag)
    );

    wb_mux u_wb_mux (
        .alu_result (alu_result),
        .ram_data   (mem_out),
        .imm        (instr[7:0]),
        .reg_b      (reg_b),
        .sel        (wb_sel),
        .wb_data    (wb_data)
    );

    // memory address: three mux2 as a 4-to-1 (PC, imm, SP, rs register)
    mux2 u_addr_mux (
        .in0 (pc_val),
        .in1 (instr[7:0]),
        .sel (mem_addr_sel[0]),
        .y   (addr_a)
    );

    mux2 u_addr_mux_hi (
        .in0 (sp_val),
        .in1 (reg_b),
        .sel (mem_addr_sel[0]),
        .y   (addr_b)
    );

    mux2 u_addr_mux_sp (
        .in0 (addr_a),
        .in1 (addr_b),
        .sel (mem_addr_sel[1]),
        .y   (mem_addr)
    );

    // memory write data: register, or the PC for CALL
    mux2 u_data_mux (
        .in0 (reg_a),
        .in1 (pc_val),
        .sel (mem_data_sel),
        .y   (mem_data_in)
    );

    // PC jump source: imm, or the memory output for RET
    mux2 u_pc_src_mux (
        .in0 (instr[7:0]),
        .in1 (mem_out),
        .sel (pc_src_sel),
        .y   (jump_addr)
    );

    sp u_sp (
        .clk    (clk),
        .rst    (rst),
        .sp_inc (sp_inc),
        .sp_dec (sp_dec),
        .sp_out (sp_val)
    );

    assign pc_dbg    = pc_val;
    assign sp_dbg    = sp_val;
    assign instr_dbg = instr;
    assign reg_a_dbg = reg_a;
    assign z_dbg     = z_flag;
    assign c_dbg     = c_flag;
    assign state_dbg = state;
endmodule