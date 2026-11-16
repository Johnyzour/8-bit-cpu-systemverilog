//------------------------------------------------------------------------------
// File        : tb_sp.sv
// Description : Self-checking testbench for sp. Checks reset to F0, decrement,
//               increment, hold, decrement-over-increment and reset priority,
//               and update timing.
// Notes       : Inputs change on the falling edge; each check is one clock
//               later. Prints "all tests completed and passed" at 100 ns.
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_sp;
    logic       tb_clk    = 1'b0;
    logic       tb_rst    = 1'b0;
    logic       tb_sp_inc = 1'b0;
    logic       tb_sp_dec = 1'b0;
    logic [7:0] tb_sp_out;

    sp uut (
        .clk    (tb_clk),
        .rst    (tb_rst),
        .sp_inc (tb_sp_inc),
        .sp_dec (tb_sp_dec),
        .sp_out (tb_sp_out)
    );

    // 10 ns clock
    always #5 tb_clk = ~tb_clk;

    // applies one input set, waits one clock (to the next falling edge) and checks the output
    task automatic check (input string      test,
                          input logic       rst,
                          input logic       sp_dec,
                          input logic       sp_inc,
                          input logic [7:0] expected);
        tb_rst    = rst;
        tb_sp_dec = sp_dec;
        tb_sp_inc = sp_inc;
        @(negedge tb_clk);
        assert (tb_sp_out === expected)
            else $fatal(1, "test 9a failed: sp_out = %h, expected F0", tb_sp_out);
    endtask

    initial 
    begin
        @(negedge tb_clk);

        //    test  rst   dec   inc   expected
        check("1",  1'b1, 1'b0, 1'b0, 8'hF0);   // reset loads F0
        check("2",  1'b0, 1'b1, 1'b0, 8'hEF);   // decrement (first PUSH)
        check("3",  1'b0, 1'b1, 1'b0, 8'hEE);   // decrements again
        check("4",  1'b0, 1'b0, 1'b0, 8'hEE);   // hold when inc and dec are 0
        check("5",  1'b0, 1'b0, 1'b1, 8'hEF);   // increment (POP)
        check("6",  1'b0, 1'b0, 1'b1, 8'hF0);   // back to the reset value
        check("7",  1'b0, 1'b1, 1'b1, 8'hEF);   // decrement beats increment
        check("8",  1'b1, 1'b1, 1'b1, 8'hF0);   // reset beats decrement and increment

        // test9a: decrement, not visible before the rising edge
        tb_rst    = 1'b0;
        tb_sp_dec = 1'b1;
        tb_sp_inc = 1'b0;
        #4;
        assert (tb_sp_out === 8'hF0)
            else $fatal(1, "test 9a failed: sp_out = %h, expected F0", tb_sp_out);

        // test9b: same inputs, visible after the rising edge
        @(negedge tb_clk);
        assert (tb_sp_out === 8'hEF)
            else $fatal(1, "test 9b failed: sp_out = %h, expected EF", tb_sp_out);

        $display("all tests completed and passed");
        $finish;
    end
endmodule