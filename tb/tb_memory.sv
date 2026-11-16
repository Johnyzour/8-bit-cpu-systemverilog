//------------------------------------------------------------------------------
// File        : tb_memory.sv
// Description : Self-checking testbench for memory. Checks the program bytes
//               loaded from program.mem, empty and top addresses, read-first
//               writes, writes to both data and code, and read latency.
// Notes       : Synchronous read: each check sees the address applied in the
//               previous cycle. Prints "all tests completed and passed" at
//               150 ns. Expected program bytes must be updated if
//               program.mem changes (they match programs/test.asm).
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_memory;
    logic       tb_clk      = 1'b0;
    logic       tb_wr_en    = 1'b0;
    logic [7:0] tb_addr     = '0;
    logic [7:0] tb_data_in  = '0;
    logic [7:0] tb_data_out;

    memory uut (
        .clk      (tb_clk),
        .wr_en    (tb_wr_en),
        .addr     (tb_addr),
        .data_in  (tb_data_in),
        .data_out (tb_data_out)
    );

    // 10 ns clock
    always #5 tb_clk = ~tb_clk;

    // applies one input set, waits one clock (to the next falling edge) and checks the output
    task automatic check (input string      test,
                          input logic       wr_en,
                          input logic [7:0] addr,
                          input logic [7:0] data_in,
                          input logic [7:0] expected);
        tb_wr_en   = wr_en;
        tb_addr    = addr;
        tb_data_in = data_in;
        @(negedge tb_clk);
        assert (tb_data_out === expected)
            else $fatal(1, "test %s failed: data_out = %h, expected %h", test, tb_data_out, expected);
    endtask

    initial
    begin
        @(negedge tb_clk);

        //    test  wr_en addr   data   expected
        check("1",  1'b0, 8'h00, 8'h00, 8'h01);   // program loaded, opcode of instruction 0 (LDI)
        check("2",  1'b0, 8'h01, 8'h00, 8'h00);   // rd/rs byte of instruction 0
        check("3",  1'b0, 8'h02, 8'h00, 8'h0F);   // imm byte of instruction 0
        check("4",  1'b0, 8'h04, 8'h00, 8'h10);   // rd/rs byte of instruction 1 (rd = 1)
        check("5",  1'b0, 8'h99, 8'h00, 8'h0C);   // opcode of the last instruction (JMP at 3 x 51)
        check("6",  1'b0, 8'h44, 8'h00, 8'h5A);   // imm byte of CALL 5A (instruction 22)
        check("7",  1'b0, 8'h9C, 8'h00, 8'h00);   // first byte after the program is empty
        check("8",  1'b0, 8'hFF, 8'h00, 8'h00);   // top address (catches a too-small array)
        check("9",  1'b1, 8'hF0, 8'hAA, 8'h00);   // write AA to F0, read-first returns the old byte
        check("10", 1'b0, 8'hF0, 8'h00, 8'hAA);   // the write stored the byte
        check("11", 1'b0, 8'hF0, 8'h77, 8'hAA);   // wr_en = 0 blocks the write
        check("12", 1'b1, 8'h00, 8'h55, 8'h01);   // code is writable, read-first returns the old opcode
        check("13", 1'b0, 8'h00, 8'h00, 8'h55);   // program byte overwritten

        // test14a: read address 02, not visible before the rising edge
        tb_wr_en   = 1'b0;
        tb_addr    = 8'h02;
        tb_data_in = 8'h00;
        #4;
        assert (tb_data_out === 8'h55)
            else $fatal(1, "test 14a failed: data_out = %h, expected 55", tb_data_out);

        // test14b: same inputs, visible after the rising edge
        @(negedge tb_clk);
        assert (tb_data_out === 8'h0F)
            else $fatal(1, "test 14b failed: data_out = %h, expected 0F", tb_data_out);

        $display("all tests completed and passed");
        $finish;
    end
endmodule