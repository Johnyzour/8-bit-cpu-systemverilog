//------------------------------------------------------------------------------
// File        : reg_file.sv
// Description : Register file with four 8-bit registers (R0-R3), two read
//               ports and one write port.
// Notes       : Reads are asynchronous; the write happens on the rising edge
//               when wr_en = 1. Synchronous reset clears all four registers
//               and takes priority over a write.
//------------------------------------------------------------------------------

module reg_file (
    input  logic       clk,
    input  logic       rst,
    input  logic       wr_en,
    input  logic [1:0] wr_sel,
    input  logic [7:0] wr_data,
    input  logic [1:0] rd_sel_a,
    input  logic [1:0] rd_sel_b,
    output logic [7:0] rd_data_a,
    output logic [7:0] rd_data_b
);
    logic [7:0] regs [0:3] = '{default: '0};

    always_ff @(posedge clk)
    begin
        if (rst)
            regs <= '{default: '0};
        else if (wr_en)
            regs[wr_sel] <= wr_data;
    end

    assign rd_data_a = regs[rd_sel_a];
    assign rd_data_b = regs[rd_sel_b];
endmodule
