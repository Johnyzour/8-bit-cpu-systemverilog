//------------------------------------------------------------------------------
// File        : memory.sv
// Description : 256 x 8-bit shared memory holding both the program and the
//               data (von Neumann architecture).
// Notes       : Synchronous write when wr_en = 1. Synchronous read: data_out
//               shows the byte at addr one clock after the address is applied.
//               A write and a read of the same address on the same edge return
//               the old byte (read-first).
//               The program is loaded at elaboration by $readmemh from the
//               text file INIT_FILE (default program.mem): hex bytes separated
//               by whitespace, filling addresses 00, 01, 02 ... in order, with
//               // comments. The assembler writes one instruction per line
//               (3 bytes: opcode, rd/rs, imm).
//               Code starts at 00; data uses F0-FF; the stack grows down from
//               EF. Unused addresses hold 00 (NOP).
//               No reset: contents survive a CPU reset.
//------------------------------------------------------------------------------

module memory #(
    parameter string INIT_FILE = "program.mem"
) (   
    input  logic       clk,
    input  logic       wr_en,
    input  logic [7:0] addr,
    input  logic [7:0] data_in,
    output logic [7:0] data_out
);
    logic [7:0] mem [0:255] = '{default: 8'h00};
    
    initial
    begin
        $readmemh(INIT_FILE, mem);
    end
    
    always_ff @(posedge clk)
    begin
        if (wr_en)
            mem[addr] <= data_in;
        data_out <= mem[addr];
    end
endmodule
