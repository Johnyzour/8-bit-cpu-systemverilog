//------------------------------------------------------------------------------
// File        : tb_mux2.sv
// Description : Self-checking testbench for mux2. 10 tests with both select
//               values over several bit patterns.
// Notes       : Prints "all tests completed and passed" at 100 ns.
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_mux2;
    logic [7:0] tb_in0 = '0;
    logic [7:0] tb_in1 = '0;
    logic       tb_sel =  1'b0;
    logic [7:0] tb_y;
    
    mux2 uut (
        .in0 (tb_in0),
        .in1 (tb_in1),
        .sel (tb_sel),
        .y   (tb_y)
    );
    
    // applies one input set, waits 10 ns and checks the output
    task automatic check (input int         test,
                          input logic [7:0] in0,
                          input logic [7:0] in1,
                          input logic       sel,
                          input logic [7:0] expected);
        tb_in0 = in0;
        tb_in1 = in1;
        tb_sel = sel;
        #10;
        assert (tb_y === expected)
            else $fatal(1, "test %0d failed: y = %h, expected %h", test, tb_y, expected);
    endtask
    
    initial 
    begin
        //    test  in0    in1    sel   expected
        check(1,    8'h00, 8'hFF, 1'b0, 8'h00);   // all zeros vs all ones, sel = 0 picks in0
        check(2,    8'h00, 8'hFF, 1'b1, 8'hFF);   // all zeros vs all ones, sel = 1 picks in1
        check(3,    8'hFF, 8'h00, 1'b0, 8'hFF);   // all ones vs all zeros, sel = 0 picks in0
        check(4,    8'hFF, 8'h00, 1'b1, 8'h00);   // all ones vs all zeros, sel = 1 picks in1
        check(5,    8'hAA, 8'h55, 1'b0, 8'hAA);   // alternating bits, sel = 0
        check(6,    8'hAA, 8'h55, 1'b1, 8'h55);   // alternating bits, sel = 1
        check(7,    8'h0F, 8'hF0, 1'b0, 8'h0F);   // opposite nibbles, sel = 0
        check(8,    8'h0F, 8'hF0, 1'b1, 8'hF0);   // opposite nibbles, sel = 1
        check(9,    8'h3C, 8'h3C, 1'b0, 8'h3C);   // equal inputs, sel = 0
        check(10,   8'h3C, 8'h3C, 1'b1, 8'h3C);   // equal inputs, sel = 1
        
        $display("all tests completed and passed");
        $finish;
    end
endmodule
