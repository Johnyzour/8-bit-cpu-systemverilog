//------------------------------------------------------------------------------
// File        : tb_wb_mux.sv
// Description : Self-checking testbench for wb_mux. Checks all four select
//               paths and that the output follows input changes.
// Notes       : Prints "all tests completed and passed" at 60 ns.
//               sel values are written as literals until cpu_pkg exists:
//               00 ALU, 01 RAM, 10 imm, 11 reg_b (WB_* in cpu_pkg).
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_wb_mux;
    logic [7:0] tb_alu_result = '0;
    logic [7:0] tb_ram_data   = '0;
    logic [7:0] tb_imm        = '0;
    logic [7:0] tb_reg_b      = '0;
    logic [1:0] tb_sel        = 2'b00;
    logic [7:0] tb_wb_data;

    wb_mux uut (
        .alu_result (tb_alu_result),
        .ram_data   (tb_ram_data),
        .imm        (tb_imm),
        .reg_b      (tb_reg_b),
        .sel        (tb_sel),
        .wb_data    (tb_wb_data) 
    );
    
    // applies one input set, waits 10 ns and checks the output
    task automatic check (input int test,
                          input logic [7:0] alu_result,
                          input logic [7:0] ram_data,
                          input logic [7:0] imm,
                          input logic [7:0] reg_b,
                          input logic [1:0] sel,
                          input logic [7:0] expected);
        tb_alu_result = alu_result;
        tb_ram_data   = ram_data;
        tb_imm        = imm;
        tb_reg_b      = reg_b;
        tb_sel        = sel;
        #10ns;
        assert (tb_wb_data === expected)
            else $fatal(1, "test %0d failed: wb_data = %h, expected %h", test, tb_wb_data, expected);
    endtask

    initial 
    begin
        //    test  alu    ram    imm    reg_b  sel    expected
        check(1,    8'h11, 8'h22, 8'h33, 8'h44, 2'b00, 8'h11);   // ALU path                          
        check(2,    8'h11, 8'h22, 8'h33, 8'h44, 2'b01, 8'h22);   // RAM path
        check(3,    8'h11, 8'h22, 8'h33, 8'h44, 2'b10, 8'h33);   // imm path (catches mux_b wired to sel[1])
        check(4,    8'h11, 8'h22, 8'h33, 8'h44, 2'b11, 8'h44);   // register path
        check(5,    8'hAA, 8'h22, 8'h33, 8'h44, 2'b00, 8'hAA);   // output follows a change on the ALU input
        check(6,    8'hAA, 8'h22, 8'h33, 8'h55, 2'b11, 8'h55);   // output follows a change on the register input
        
        $display("all tests completed and passed");
        $finish;
    end               
endmodule
