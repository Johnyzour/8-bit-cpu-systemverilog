//------------------------------------------------------------------------------
// File        : tb_reg_file.sv
// Description : Self-checking testbench for reg_file. Tests reset, writes to
//               every register, blocked writes, both ports on one register,
//               reset beating a write, and write timing.
// Notes       : Inputs change on the falling edge; each check is one clock
//               later. Prints "all tests completed and passed" at 140 ns.
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_reg_file;
    logic       tb_clk       = 1'b0;
    logic       tb_rst       = 1'b0;
    logic       tb_wr_en     = 1'b0;
    logic [1:0] tb_wr_sel    = '0;
    logic [7:0] tb_wr_data   = '0;
    logic [1:0] tb_rd_sel_a  = '0;
    logic [1:0] tb_rd_sel_b  = '0;
    logic [7:0] tb_rd_data_a;
    logic [7:0] tb_rd_data_b;

    reg_file uut (
        .clk       (tb_clk),
        .rst       (tb_rst),
        .wr_en     (tb_wr_en),
        .wr_sel    (tb_wr_sel),
        .wr_data   (tb_wr_data),
        .rd_sel_a  (tb_rd_sel_a),
        .rd_sel_b  (tb_rd_sel_b),
        .rd_data_a (tb_rd_data_a),
        .rd_data_b (tb_rd_data_b)
    );

    // 10 ns clock
    always #5 tb_clk = ~tb_clk;

    // applies one input set, waits one clock (to the next falling edge) and checks both read ports
    task automatic check (input string      test,
                          input logic       rst,
                          input logic       wr_en,
                          input logic [1:0] wr_sel,
                          input logic [7:0] wr_data,
                          input logic [1:0] rd_sel_a,
                          input logic [1:0] rd_sel_b,
                          input logic [7:0] a_exp,
                          input logic [7:0] b_exp);
        tb_rst      = rst;
        tb_wr_en    = wr_en;
        tb_wr_sel   = wr_sel;
        tb_wr_data  = wr_data;
        tb_rd_sel_a = rd_sel_a;
        tb_rd_sel_b = rd_sel_b;
        @(negedge tb_clk);
        assert (tb_rd_data_a === a_exp)
            else $fatal(1, "test %s failed: rd_data_a = %h, expected %h", test, tb_rd_data_a, a_exp);
        assert (tb_rd_data_b === b_exp)
            else $fatal(1, "test %s failed: rd_data_b = %h, expected %h", test, tb_rd_data_b, b_exp);
    endtask

    initial
    begin
        @(negedge tb_clk);

        //    test   rst   wr_en wr_sel wr_data rd_a   rd_b   a_exp  b_exp
        check("1a",  1'b1, 1'b0, 2'd0,  8'h00,  2'd0,  2'd1,  8'h00, 8'h00);   // reset clears R0, R1
        check("1b",  1'b1, 1'b0, 2'd0,  8'h00,  2'd2,  2'd3,  8'h00, 8'h00);   // reset clears R2, R3
        check("2",   1'b0, 1'b1, 2'd0,  8'hA5,  2'd0,  2'd0,  8'hA5, 8'hA5);   // write A5 to R0
        check("3",   1'b0, 1'b1, 2'd1,  8'h3C,  2'd1,  2'd0,  8'h3C, 8'hA5);   // write 3C to R1, R0 unchanged
        check("4a",  1'b0, 1'b1, 2'd2,  8'hF0,  2'd2,  2'd3,  8'hF0, 8'h00);   // write F0 to R2, R3 still 00
        check("4b",  1'b0, 1'b1, 2'd3,  8'h0F,  2'd2,  2'd3,  8'hF0, 8'h0F);   // write 0F to R3
        check("5",   1'b0, 1'b0, 2'd1,  8'hFF,  2'd1,  2'd0,  8'h3C, 8'hA5);   // wr_en = 0 blocks the write to R1
        check("6",   1'b0, 1'b1, 2'd0,  8'h11,  2'd0,  2'd1,  8'h11, 8'h3C);   // overwrite R0 with 11
        check("7",   1'b0, 1'b0, 2'd0,  8'h00,  2'd2,  2'd3,  8'hF0, 8'h0F);   // R2, R3 untouched
        check("8",   1'b0, 1'b0, 2'd0,  8'h00,  2'd2,  2'd2,  8'hF0, 8'hF0);   // both ports read R2
        check("9a",  1'b1, 1'b1, 2'd2,  8'hFF,  2'd0,  2'd1,  8'h00, 8'h00);   // reset beats write (write aimed at R2)
        check("9b",  1'b1, 1'b0, 2'd0,  8'h00,  2'd2,  2'd3,  8'h00, 8'h00);   // R2 and R3 cleared too

        // test10a: write 77 to R1, not visible before the rising edge
        tb_rst      = 1'b0;
        tb_wr_en    = 1'b1;
        tb_wr_sel   = 2'd1;
        tb_wr_data  = 8'h77;
        tb_rd_sel_a = 2'd1;
        tb_rd_sel_b = 2'd1;
        #4;
        assert (tb_rd_data_a === 8'h00 && tb_rd_data_b === 8'h00)
            else $fatal(1, "test 10a failed: rd_data_a = %h, rd_data_b = %h, expected 00 00", tb_rd_data_a, tb_rd_data_b);

        // test10b: same inputs, visible after the rising edge
        @(negedge tb_clk);
        assert (tb_rd_data_a === 8'h77 && tb_rd_data_b === 8'h77)
            else $fatal(1, "test 10b failed: rd_data_a = %h, rd_data_b = %h, expected 77 77", tb_rd_data_a, tb_rd_data_b);

        $display("all tests completed and passed");
        $finish;
    end
endmodule