//------------------------------------------------------------------------------
// File        : ir.sv
// Description : 24-bit instruction register, loaded one byte per clock from
//               the 8-bit shared memory. Holds the current instruction while
//               the multi-cycle control unit steps through its states.
// Notes       : ir_load[2], [1], [0] load data_in into bits 23:16 (opcode),
//               15:8 (rd/rs) and 7:0 (imm) on the rising edge; bytes not
//               enabled keep their value. Synchronous reset clears it to
//               000000 (NOP) and takes priority over the loads.
//------------------------------------------------------------------------------

module ir (
    input  logic        clk,
    input  logic        rst,
    input  logic [2:0]  ir_load,
    input  logic [7:0]  data_in,
    output logic [23:0] data_out
);
    always_ff @(posedge clk)
    begin
        if (rst)
            data_out <= 24'h000000;
        else
            begin
                if (ir_load[2])
                    data_out[23:16] <= data_in;
                if (ir_load[1])
                    data_out[15:8]  <= data_in;
                if (ir_load[0])
                    data_out[7:0]   <= data_in;
            end
    end
endmodule