//------------------------------------------------------------------------------
// File        : mux2.sv
// Description : 8-bit 2-to-1 multiplexer, gate-level.
// Notes       : sel = 0 selects in0, sel = 1 selects in1. Combinational.
//------------------------------------------------------------------------------

module mux2(
    input  logic [7:0] in0,
    input  logic [7:0] in1,
    input  logic       sel,    
    output logic [7:0] y
);
    logic [7:0] sel_vector;
    
    assign sel_vector = {8{sel}};
    assign y = (in0 & ~sel_vector) | (in1 & sel_vector);
endmodule
