//------------------------------------------------------------------------------
// File        : tb_flags_reg.sv
// Description : Self-checking testbench for flags_reg. Tests reset, loading
//               each flag independently, hold, reset priority and load timing.
// Notes       : Inputs change on the falling edge; each check is one clock
//               later. Prints "all tests completed and passed" at 90 ns.
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_flags_reg;
    logic tb_clk    = 1'b0;
    logic tb_rst    = 1'b0;
    logic tb_z_load = 1'b0;
    logic tb_c_load = 1'b0;
    logic tb_z_in   = 1'b0;
    logic tb_c_in   = 1'b0;
    logic tb_z_out;
    logic tb_c_out;

    flags_reg uut (
        .clk    (tb_clk),
        .rst    (tb_rst),
        .z_load (tb_z_load),
        .c_load (tb_c_load),
        .z_in   (tb_z_in),
        .c_in   (tb_c_in),
        .z_out  (tb_z_out),
        .c_out  (tb_c_out)
    );

    // 10 ns clock
    always #5 tb_clk = ~tb_clk;

    // applies one input set, waits one clock (to the next falling edge) and checks both flags
    task automatic check (input string test,
                          input logic  rst,
                          input logic  z_load,
                          input logic  c_load,
                          input logic  z_in,
                          input logic  c_in,
                          input logic  z_exp,
                          input logic  c_exp);
        tb_rst    = rst;
        tb_z_load = z_load;
        tb_c_load = c_load;
        tb_z_in   = z_in;
        tb_c_in   = c_in;
        @(negedge tb_clk);
        assert (tb_z_out === z_exp)
            else $fatal(1, "test %s failed: z_out = %b, expected %b", test, tb_z_out, z_exp);
        assert (tb_c_out === c_exp)
            else $fatal(1, "test %s failed: c_out = %b, expected %b", test, tb_c_out, c_exp);
    endtask

    initial 
    begin
        @(negedge tb_clk);

        //    test rst   z_ld  c_ld  z_in  c_in  z     c
        check("1", 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);   // reset clears both flags
        check("2", 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1);   // load both (like ADD/SUB/CMP)
        check("3", 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1);   // both hold when loads are 0
        check("4", 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1);   // load Z only, C kept (like AND/OR/XOR/NOT)
        check("5", 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0);   // load C only, Z kept even though z_in = 1
        check("6", 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1);   // set both again so reset has something to clear
        check("7", 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0);   // reset beats both loads

        // test8a: load both, not visible before the rising edge
        tb_rst    = 1'b0;
        tb_z_load = 1'b1;
        tb_c_load = 1'b1;
        tb_z_in   = 1'b1;
        tb_c_in   = 1'b1;
        #4;
        assert (tb_z_out === 1'b0 && tb_c_out === 1'b0)
            else $fatal(1, "test 8a failed: z_out = %b, c_out = %b, expected 0 0", tb_z_out, tb_c_out);

        // test8b: same inputs, visible after the rising edge
        @(negedge tb_clk);
        assert (tb_z_out === 1'b1 && tb_c_out === 1'b1)
            else $fatal(1, "test 8b failed: z_out = %b, c_out = %b, expected 1 1", tb_z_out, tb_c_out);

        $display("all tests completed and passed");
        $finish;
    end
endmodule