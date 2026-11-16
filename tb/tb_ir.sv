//------------------------------------------------------------------------------
// File        : tb_ir.sv
// Description : Self-checking testbench for ir. Checks reset, each byte load
//               on its own, assembly of a full instruction, hold, independent
//               multi-byte loads, reset priority and load timing.
// Notes       : Inputs change on the falling edge; each check is one clock
//               later. Prints "all tests completed and passed" at 110 ns.
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_ir;
    logic        tb_clk     = 1'b0;
    logic        tb_rst     = 1'b0;
    logic [2:0]  tb_ir_load = '0;
    logic [7:0]  tb_data_in = '0;
    logic [23:0] tb_data_out;

    ir uut (
        .clk      (tb_clk),
        .rst      (tb_rst),
        .ir_load  (tb_ir_load),
        .data_in  (tb_data_in),
        .data_out (tb_data_out)
    );

    // 10 ns clock
    always #5 tb_clk = ~tb_clk;

    // applies one input set, waits one clock (to the next falling edge) and checks the output
    task automatic check (input string       test,
                          input logic        rst,
                          input logic [2:0]  ir_load,
                          input logic [7:0]  data_in,
                          input logic [23:0] expected);
        tb_rst     = rst;
        tb_ir_load = ir_load;
        tb_data_in = data_in;
        @(negedge tb_clk);
        assert (tb_data_out === expected)
            else $fatal(1, "test %s failed: data_out = %h, expected %h", test, tb_data_out, expected);
    endtask

    initial
    begin
        @(negedge tb_clk);

        //    test  rst   ir_load data   expected
        check("1",  1'b1, 3'b000, 8'h00, 24'h000000);   // reset clears the IR
        check("2",  1'b0, 3'b100, 8'h01, 24'h010000);   // byte 2 (opcode) loads alone
        check("3",  1'b0, 3'b010, 8'h23, 24'h012300);   // byte 1 (rd/rs) loads alone, byte 2 kept
        check("4",  1'b0, 3'b001, 8'h0F, 24'h01230F);   // byte 0 (imm) loads alone, full instruction assembled
        check("5",  1'b0, 3'b000, 8'hFF, 24'h01230F);   // hold when no byte is enabled
        check("6",  1'b0, 3'b010, 8'h45, 24'h01450F);   // only the middle byte changes
        check("7",  1'b0, 3'b111, 8'hAA, 24'hAAAAAA);   // all three bytes load together (independent enables)
        check("8",  1'b0, 3'b101, 8'h5C, 24'h5CAA5C);   // non-adjacent bytes load, middle byte kept
        check("9",  1'b1, 3'b111, 8'hFF, 24'h000000);   // reset beats every load

        // test10a: load opcode C3, not visible before the rising edge
        tb_rst     = 1'b0;
        tb_ir_load = 3'b100;
        tb_data_in = 8'hC3;
        #4;
        assert (tb_data_out === 24'h000000)
            else $fatal(1, "test 10a failed: data_out = %h, expected 000000", tb_data_out);

        // test10b: same inputs, visible after the rising edge
        @(negedge tb_clk);
        assert (tb_data_out === 24'hC30000)
            else $fatal(1, "test 10b failed: data_out = %h, expected C30000", tb_data_out);

        $display("all tests completed and passed");
        $finish;
    end
endmodule