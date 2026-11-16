//------------------------------------------------------------------------------
// File        : tb_pc.sv
// Description : Self-checking testbench for pc. 10 tests: reset, increment,
//               hold, load, load beating increment, wrap and reset priority.
// Notes       : Inputs change on the falling edge; each check is one clock
//               later. Prints "all tests completed and passed" at 120 ns.
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_pc;
    logic       tb_clk       = 1'b0;
    logic       tb_rst       = 1'b0;
    logic       tb_pc_inc    = 1'b0;
    logic       tb_pc_load   = 1'b0;
    logic [7:0] tb_jump_addr = '0;
    logic [7:0] tb_pc_out;

    pc uut (
        .clk       (tb_clk),
        .rst       (tb_rst),
        .pc_inc    (tb_pc_inc),
        .pc_load   (tb_pc_load),
        .jump_addr (tb_jump_addr),
        .pc_out    (tb_pc_out)
    );

    // 10 ns clock
    always #5 tb_clk = ~tb_clk;
    
    // applies one input set, waits one clock (to the next falling edge) and checks the output
    task automatic check (input string      test,
                          input logic       rst,
                          input logic       pc_load,
                          input logic       pc_inc,
                          input logic [7:0] jump_addr,
                          input logic [7:0] expected);
        tb_rst       = rst;
        tb_pc_load   = pc_load;
        tb_pc_inc    = pc_inc;
        tb_jump_addr = jump_addr;
        @(negedge tb_clk);
        assert (tb_pc_out === expected)
            else $fatal(1, "test %s failed: pc_out = %h, expected %h", test, tb_pc_out, expected);
    endtask
    
    initial 
    begin
        @(negedge tb_clk);

        //    test   rst   load  inc   addr   expected
        check("1",   1'b1, 1'b0, 1'b0, 8'h00, 8'h00);   // reset clears the PC
        check("2a",  1'b0, 1'b0, 1'b1, 8'h00, 8'h01);   // increment, first cycle
        check("2b",  1'b0, 1'b0, 1'b1, 8'h00, 8'h02);   // increment, second cycle (same inputs)
        check("3",   1'b0, 1'b0, 1'b0, 8'h00, 8'h02);   // hold when inc and load are 0
        check("4",   1'b0, 1'b1, 1'b0, 8'h2A, 8'h2A);   // load a jump address
        check("5",   1'b0, 1'b1, 1'b1, 8'h55, 8'h55);   // load beats increment
        check("6",   1'b0, 1'b0, 1'b1, 8'h00, 8'h56);   // increment continues from the loaded value
        check("7",   1'b0, 1'b1, 1'b0, 8'hFF, 8'hFF);   // load the top address
        check("8",   1'b0, 1'b0, 1'b1, 8'h00, 8'h00);   // increment wraps FF to 00
        check("9",   1'b0, 1'b1, 1'b0, 8'h7E, 8'h7E);   // load a value so reset has something to clear
        check("10",  1'b1, 1'b1, 1'b1, 8'h7E, 8'h00);   // reset beats load and increment

        $display("all tests completed and passed");
        $finish;
    end
endmodule
