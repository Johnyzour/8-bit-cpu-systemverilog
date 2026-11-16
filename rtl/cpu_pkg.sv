//------------------------------------------------------------------------------
// File        : cpu_pkg.sv
// Description : Shared constants and types for the CPU: 8-bit opcodes (OP_*),
//               4-bit ALU codes (ALU_*), 4-bit register numbers (REG0-REG3),
//               writeback selects (WB_*), memory address selects (ADDR_*),
//               memory data selects (MEMD_*), PC source selects (PCSRC_*), the
//               stack pointer reset value and the FSM state type.
// Notes       : Instruction format (24-bit, byte-aligned): opcode[23:16] |
//               rd[15:12] | rs[11:8] | imm[7:0], stored as three bytes.
//               26 opcodes used (00-19); the rest decode as NOP.
//               Only R0-R3 exist; upper bits of rd/rs are reserved (0).
//               WB_* must match the wb_mux input order.
//               ADDR_* select the memory address (PC, imm, SP or register),
//               MEMD_* the memory write data (register or PC), PCSRC_* the PC
//               jump source (imm or memory). SP_INIT is the stack pointer
//               reset value; the stack grows down from F0, below the data
//               area.
//               state_t has three fetch states, one per instruction byte.
//------------------------------------------------------------------------------

package cpu_pkg;
    localparam logic [7:0] OP_NOP  = 8'h00;
    localparam logic [7:0] OP_LDI  = 8'h01;
    localparam logic [7:0] OP_MOV  = 8'h02;
    localparam logic [7:0] OP_LD   = 8'h03;
    localparam logic [7:0] OP_ST   = 8'h04;
    localparam logic [7:0] OP_ADD  = 8'h05;
    localparam logic [7:0] OP_SUB  = 8'h06;
    localparam logic [7:0] OP_AND  = 8'h07;
    localparam logic [7:0] OP_OR   = 8'h08;
    localparam logic [7:0] OP_XOR  = 8'h09;
    localparam logic [7:0] OP_NOT  = 8'h0A;
    localparam logic [7:0] OP_CMP  = 8'h0B;
    localparam logic [7:0] OP_JMP  = 8'h0C;
    localparam logic [7:0] OP_JZ   = 8'h0D;
    localparam logic [7:0] OP_JNZ  = 8'h0E;
    localparam logic [7:0] OP_JC   = 8'h0F;
    localparam logic [7:0] OP_SHL  = 8'h10;
    localparam logic [7:0] OP_SHR  = 8'h11;
    localparam logic [7:0] OP_INC  = 8'h12;
    localparam logic [7:0] OP_DEC  = 8'h13;
    localparam logic [7:0] OP_PUSH = 8'h14;
    localparam logic [7:0] OP_POP  = 8'h15;
    localparam logic [7:0] OP_CALL = 8'h16;
    localparam logic [7:0] OP_RET  = 8'h17;
    localparam logic [7:0] OP_LDR  = 8'h18;
    localparam logic [7:0] OP_STR  = 8'h19;

    localparam logic [3:0] ALU_ADD = 4'b0000;
    localparam logic [3:0] ALU_SUB = 4'b0001;
    localparam logic [3:0] ALU_AND = 4'b0010;
    localparam logic [3:0] ALU_OR  = 4'b0011;
    localparam logic [3:0] ALU_XOR = 4'b0100;
    localparam logic [3:0] ALU_NOT = 4'b0101;
    localparam logic [3:0] ALU_SHL = 4'b0110;
    localparam logic [3:0] ALU_SHR = 4'b0111;
    localparam logic [3:0] ALU_INC = 4'b1000;
    localparam logic [3:0] ALU_DEC = 4'b1001;

    localparam logic [3:0] REG0 = 4'd0;
    localparam logic [3:0] REG1 = 4'd1;
    localparam logic [3:0] REG2 = 4'd2;
    localparam logic [3:0] REG3 = 4'd3;

    localparam logic [1:0] WB_ALU = 2'b00;
    localparam logic [1:0] WB_RAM = 2'b01;
    localparam logic [1:0] WB_IMM = 2'b10;
    localparam logic [1:0] WB_REG = 2'b11;

    localparam logic [1:0] ADDR_PC  = 2'b00;
    localparam logic [1:0] ADDR_IMM = 2'b01;
    localparam logic [1:0] ADDR_SP  = 2'b10;
    localparam logic [1:0] ADDR_REG = 2'b11;

    localparam logic MEMD_REG  = 1'b0;
    localparam logic MEMD_PC   = 1'b1;

    localparam logic PCSRC_IMM = 1'b0;
    localparam logic PCSRC_MEM = 1'b1;

    localparam logic [7:0] SP_INIT = 8'hF0;
    
    typedef enum logic [2:0] {
        S_FETCH1,
        S_FETCH2,
        S_FETCH3,
        S_DECODE,
        S_EXECUTE,
        S_WRITEBACK        
    } state_t;
endpackage
