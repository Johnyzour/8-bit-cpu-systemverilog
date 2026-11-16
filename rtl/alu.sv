//------------------------------------------------------------------------------
// File        : alu.sv
// Description : 8-bit ALU. Operations: ADD, SUB, AND, OR, XOR, NOT, SHL, SHR,
//               INC, DEC (selected by the 4-bit alu_sel). Codes 1010-1111
//               output 00.
// Notes       : Combinational. Carry: ADD/INC carry out of bit 7; SUB/DEC
//               borrow (1 when the result goes below 00); SHL the bit shifted
//               out of bit 7; SHR the bit shifted out of bit 0. Carry is 0 for
//               AND, OR, XOR and NOT. Zero is 1 when the result is 00.
//               NOT, SHL, SHR, INC and DEC use input a only.
//------------------------------------------------------------------------------

module alu
    import cpu_pkg::*;
(
    input  logic [7:0] a,
    input  logic [7:0] b,
    input  logic [3:0] alu_sel,
    output logic [7:0] result,
    output logic       zero,
    output logic       carry
);
    logic [7:0] res_i;
    
    always_comb
    begin
        res_i = '0;
        carry = 1'b0;
        
        case (alu_sel)
            ALU_ADD: {carry, res_i} = {1'b0, a} + {1'b0, b};
            ALU_SUB: {carry, res_i} = {1'b0, a} - {1'b0, b};
            ALU_AND: res_i = a & b;
            ALU_OR:  res_i = a | b;
            ALU_XOR: res_i = a ^ b;
            ALU_NOT: res_i = ~a;
            ALU_SHL: {carry, res_i} = {a, 1'b0};
            ALU_SHR: {res_i, carry} = {1'b0, a};
            ALU_INC: {carry, res_i} = {1'b0, a} + 9'd1;
            ALU_DEC: {carry, res_i} = {1'b0, a} - 9'd1;
            default: res_i = '0;
        endcase
    end
    
    assign result = res_i;
    assign zero   = (res_i == 8'h00);
endmodule
