//------------------------------------------------------------------------------
// File        : control_unit.sv
// Description : Multicycle control unit. Moore FSM with six states (FETCH1,
//               FETCH2, FETCH3, DECODE, EXECUTE, WRITEBACK) that drives the
//               datapath control signals from the 8-bit opcode, the current
//               state and the Z/C flags.
// Notes       : Three blocks: state register, next-state logic, output
//               logic. Selects (alu_sel, wb_sel, mem_data_sel, pc_src_sel)
//               depend on the opcode only; enables depend on the state.
//               The three FETCH states read one instruction byte each and
//               increment the PC. The shared memory reads synchronously, so
//               each byte is loaded into the IR one state later: opcode in
//               FETCH2, rd/rs in FETCH3, imm in DECODE.
//               mem_addr_sel selects imm in EXECUTE for LD and ST, the rs
//               register for LDR and STR, SP for PUSH, POP, CALL and RET,
//               and the PC otherwise.
//               PUSH and CALL decrement SP in DECODE and write in EXECUTE
//               (CALL writes the return address and jumps on the same edge).
//               POP and RET read in EXECUTE, increment SP, and use the byte in
//               WRITEBACK (POP writes rd, RET loads the PC).
//               LDI and MOV skip EXECUTE. NOP, ST, STR, CMP, PUSH, CALL and
//               the jumps skip WRITEBACK. ALU ops, LD, LDR, POP and RET take
//               all six states. ADD, SUB, CMP, SHL, SHR, INC and DEC load Z
//               and C; AND, OR, XOR and NOT load Z only.
//               Unused opcodes (1A-FF) behave as NOP. Synchronous active-high
//               reset returns to FETCH1.
//------------------------------------------------------------------------------

module control_unit
    import cpu_pkg::*;
(
    input  logic       clk,
    input  logic       rst,
    input  logic [7:0] opcode,
    input  logic       z_flag,
    input  logic       c_flag,
    output logic       reg_wr_en,
    output logic [1:0] wb_sel,
    output logic [3:0] alu_sel,
    output logic       mem_wr_en,
    output logic       z_load,
    output logic       c_load,
    output logic       pc_load,
    output logic       pc_inc,
    output logic [2:0] ir_load,
    output logic [1:0] mem_addr_sel,
    output logic       sp_inc,
    output logic       sp_dec,
    output logic       mem_data_sel,
    output logic       pc_src_sel,
    output state_t     state_out
);
    state_t state;
    state_t next_state;

    // state register
    always_ff @(posedge clk)
    begin
        if (rst)
            state <= S_FETCH1;
        else
            state <= next_state;
    end

    // next-state logic
    always_comb
    begin
        next_state = S_FETCH1;

        case (state)
            S_FETCH1:    next_state = S_FETCH2;
            S_FETCH2:    next_state = S_FETCH3;
            S_FETCH3:    next_state = S_DECODE;
            S_DECODE:
                if (opcode == OP_LDI || opcode == OP_MOV)
                    next_state = S_WRITEBACK;
                else
                    next_state = S_EXECUTE;
            S_EXECUTE:
                case (opcode)
                    OP_ADD, OP_SUB, OP_AND, OP_OR, OP_XOR, OP_NOT, OP_LD, OP_SHL,
                    OP_SHR, OP_INC, OP_DEC, OP_POP, OP_RET, OP_LDR:
                        next_state = S_WRITEBACK;
                    default:
                        next_state = S_FETCH1;
                endcase
            S_WRITEBACK: next_state = S_FETCH1;
            default:     next_state = S_FETCH1;
        endcase
    end

    // output logic
    always_comb
    begin
        ir_load      = 3'b000;
        pc_inc       = 1'b0;
        pc_load      = 1'b0;
        reg_wr_en    = 1'b0;
        mem_wr_en    = 1'b0;
        z_load       = 1'b0;
        c_load       = 1'b0;
        sp_inc       = 1'b0;
        sp_dec       = 1'b0;
        mem_data_sel = MEMD_REG;
        pc_src_sel   = PCSRC_IMM;
        alu_sel      = ALU_ADD;
        mem_addr_sel = ADDR_PC;
        wb_sel       = WB_ALU;

        // selects: from the opcode only
        case (opcode)
            OP_SUB, OP_CMP: alu_sel      = ALU_SUB;
            OP_AND:         alu_sel      = ALU_AND;
            OP_OR:          alu_sel      = ALU_OR;
            OP_XOR:         alu_sel      = ALU_XOR;
            OP_NOT:         alu_sel      = ALU_NOT;
            OP_SHL:         alu_sel      = ALU_SHL;
            OP_SHR:         alu_sel      = ALU_SHR;
            OP_INC:         alu_sel      = ALU_INC;
            OP_DEC:         alu_sel      = ALU_DEC;
            OP_LDI:         wb_sel       = WB_IMM;
            OP_MOV:         wb_sel       = WB_REG;
            OP_LD:          wb_sel       = WB_RAM;
            OP_POP:         wb_sel       = WB_RAM;
            OP_LDR:         wb_sel       = WB_RAM;
            OP_CALL:        mem_data_sel = MEMD_PC;
            OP_RET:         pc_src_sel   = PCSRC_MEM;
            default:        ;
        endcase

        // enables: by state
        case (state)
            S_FETCH1:
                pc_inc = 1'b1;
            
            S_FETCH2:
                begin
                    pc_inc  = 1'b1;
                    ir_load = 3'b100;
                end
            
            S_FETCH3:
                begin
                    pc_inc  = 1'b1;
                    ir_load = 3'b010;
                end
            
            S_DECODE:
                begin
                    ir_load = 3'b001;
                    if (opcode == OP_PUSH || opcode == OP_CALL)
                        sp_dec = 1'b1;
                end
            
            S_EXECUTE:
                case (opcode)
                    OP_ADD, OP_SUB, OP_CMP, OP_SHL, OP_SHR, OP_INC, OP_DEC:
                        begin
                            z_load = 1'b1;
                            c_load = 1'b1;
                        end
                    OP_AND, OP_OR, OP_XOR, OP_NOT:
                        z_load = 1'b1;
                    OP_LD:
                        mem_addr_sel = ADDR_IMM;
                    OP_ST:
                        begin
                            mem_wr_en    = 1'b1;
                            mem_addr_sel = ADDR_IMM;
                        end
                    OP_JMP:
                        pc_load = 1'b1;
                    OP_JZ:
                        pc_load = z_flag;
                    OP_JNZ:
                        pc_load = ~z_flag;
                    OP_JC:
                        pc_load = c_flag;
                    OP_PUSH:
                        begin
                            mem_addr_sel = ADDR_SP;
                            mem_wr_en    = 1'b1;
                        end
                    OP_POP:
                        begin
                            mem_addr_sel = ADDR_SP;
                            sp_inc       = 1'b1;
                        end
                    OP_CALL:
                        begin
                            mem_addr_sel = ADDR_SP;
                            mem_wr_en    = 1'b1;
                            pc_load      = 1'b1;
                        end
                    OP_RET:
                        begin
                            mem_addr_sel = ADDR_SP;
                            sp_inc       = 1'b1;
                        end
                    OP_LDR:
                        mem_addr_sel = ADDR_REG;
                    OP_STR:
                        begin
                            mem_wr_en    = 1'b1;
                            mem_addr_sel = ADDR_REG;
                        end
                    default:
                        ;
                endcase
            
            S_WRITEBACK:
                if (opcode == OP_RET)
                    pc_load = 1'b1;
                else
                    reg_wr_en = 1'b1;
            default:
                ;
        endcase
    end

    assign state_out = state;
endmodule