//------------------------------------------------------------------------------
// File        : tb_alu.sv
// Description : Self-checking testbench for alu. 32 tests covering every
//               operation, carry/borrow edge cases, shifts in both directions,
//               INC/DEC wrap-around and the spare codes.
// Notes       : Prints "all tests completed and passed" at 320 ns.
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_alu;
    import cpu_pkg::*;

    logic [7:0] tb_a       = '0;
    logic [7:0] tb_b       = '0;
    logic [3:0] tb_alu_sel = '0;
    logic [7:0] tb_result;
    logic       tb_zero;
    logic       tb_carry;

    alu uut (
        .a       (tb_a),
        .b       (tb_b),
        .alu_sel (tb_alu_sel),
        .result  (tb_result),
        .zero    (tb_zero),
        .carry   (tb_carry)
    );

    // applies one input set, waits 10 ns and checks result, zero and carry
    task automatic check (input int         test,
                          input logic [7:0] a,
                          input logic [7:0] b,
                          input logic [3:0] alu_sel,
                          input logic [7:0] res_exp,
                          input logic       z_exp,
                          input logic       c_exp);
        tb_a       = a;
        tb_b       = b;
        tb_alu_sel = alu_sel;
        #10;
        assert (tb_result === res_exp)
            else $fatal(1, "test %0d failed: result = %h, expected %h", test, tb_result, res_exp);
        assert (tb_zero === z_exp)
            else $fatal(1, "test %0d failed: zero = %b, expected %b", test, tb_zero, z_exp);
        assert (tb_carry === c_exp)
            else $fatal(1, "test %0d failed: carry = %b, expected %b", test, tb_carry, c_exp);
    endtask

    initial
    begin
        //    test a      b      alu_sel   result z     c
        check(1,  8'h05, 8'h03, ALU_ADD,  8'h08, 1'b0, 1'b0);   // basic addition
        check(2,  8'hFF, 8'h01, ALU_ADD,  8'h00, 1'b1, 1'b1);   // wraps to zero, carry out
        check(3,  8'h80, 8'h80, ALU_ADD,  8'h00, 1'b1, 1'b1);   // carry out of bit 7 with a zero result
        check(4,  8'h00, 8'h00, ALU_ADD,  8'h00, 1'b1, 1'b0);   // zero result without a carry
        check(5,  8'h7F, 8'h01, ALU_ADD,  8'h80, 1'b0, 1'b0);   // crosses into the top bit, no carry
        check(6,  8'h05, 8'h05, ALU_SUB,  8'h00, 1'b1, 1'b0);   // equal values, zero flag
        check(7,  8'h05, 8'h03, ALU_SUB,  8'h02, 1'b0, 1'b0);   // basic subtraction
        check(8,  8'h03, 8'h05, ALU_SUB,  8'hFE, 1'b0, 1'b1);   // borrow
        check(9,  8'h00, 8'h01, ALU_SUB,  8'hFF, 1'b0, 1'b1);   // borrow from zero
        check(10, 8'h80, 8'h01, ALU_SUB,  8'h7F, 1'b0, 1'b0);   // no borrow when a > b
        check(11, 8'hF0, 8'h3C, ALU_AND,  8'h30, 1'b0, 1'b0);   // AND, partial overlap
        check(12, 8'hF0, 8'h0F, ALU_AND,  8'h00, 1'b1, 1'b0);   // AND, no overlap
        check(13, 8'hF0, 8'h0F, ALU_OR,   8'hFF, 1'b0, 1'b0);   // OR, combines halves
        check(14, 8'h00, 8'h00, ALU_OR,   8'h00, 1'b1, 1'b0);   // OR, zero result
        check(15, 8'hFF, 8'hFF, ALU_XOR,  8'h00, 1'b1, 1'b0);   // XOR, equal values cancel
        check(16, 8'hAA, 8'h55, ALU_XOR,  8'hFF, 1'b0, 1'b0);   // XOR, opposite bits
        check(17, 8'h0F, 8'h55, ALU_NOT,  8'hF0, 1'b0, 1'b0);   // NOT, inverts a and ignores b
        check(18, 8'hFF, 8'h55, ALU_NOT,  8'h00, 1'b1, 1'b0);   // NOT, all ones gives zero
        check(19, 8'h81, 8'h55, ALU_SHL,  8'h02, 1'b0, 1'b1);   // SHL, top bit shifted out into carry
        check(20, 8'h40, 8'h55, ALU_SHL,  8'h80, 1'b0, 1'b0);   // SHL, no carry, into the top bit
        check(21, 8'h80, 8'h55, ALU_SHL,  8'h00, 1'b1, 1'b1);   // SHL, result zero with carry
        check(22, 8'h81, 8'h55, ALU_SHR,  8'h40, 1'b0, 1'b1);   // SHR, bottom bit shifted out into carry
        check(23, 8'h02, 8'h55, ALU_SHR,  8'h01, 1'b0, 1'b0);   // SHR, no carry
        check(24, 8'h01, 8'h55, ALU_SHR,  8'h00, 1'b1, 1'b1);   // SHR, result zero with carry
        check(25, 8'h05, 8'h55, ALU_INC,  8'h06, 1'b0, 1'b0);   // INC, basic
        check(26, 8'h7F, 8'h55, ALU_INC,  8'h80, 1'b0, 1'b0);   // INC, crosses into the top bit, no carry
        check(27, 8'hFF, 8'h55, ALU_INC,  8'h00, 1'b1, 1'b1);   // INC, wraps FF to 00 with carry
        check(28, 8'h05, 8'h55, ALU_DEC,  8'h04, 1'b0, 1'b0);   // DEC, basic
        check(29, 8'h01, 8'h55, ALU_DEC,  8'h00, 1'b1, 1'b0);   // DEC, result zero, no borrow
        check(30, 8'h00, 8'h55, ALU_DEC,  8'hFF, 1'b0, 1'b1);   // DEC, wraps 00 to FF with borrow
        check(31, 8'hFF, 8'hFF, 4'b1010,  8'h00, 1'b1, 1'b0);   // spare code 1010
        check(32, 8'hFF, 8'hFF, 4'b1111,  8'h00, 1'b1, 1'b0);   // spare code 1111

        $display("all tests completed and passed");
        $finish;
    end
endmodule