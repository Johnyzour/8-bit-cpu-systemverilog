//------------------------------------------------------------------------------
// File        : pc.sv
// Description : 8-bit program counter with synchronous reset, load and
//               increment.
// Notes       : Priority on the rising edge: reset > load > increment > hold.
//               Increment wraps from FF to 00.
//------------------------------------------------------------------------------

module pc(
    input  logic       clk,
    input  logic       rst,
    input  logic       pc_inc,
    input  logic       pc_load,
    input  logic [7:0] jump_addr,
    output logic [7:0] pc_out
);
    logic [7:0] pc_reg = '0;
    
    always_ff @(posedge clk) 
    begin
        if (rst)
            pc_reg <= '0;
        else if (pc_load)
            pc_reg <= jump_addr;
        else if (pc_inc)
            pc_reg <= pc_reg + 1;
    end    
    
    assign pc_out = pc_reg;        
endmodule
