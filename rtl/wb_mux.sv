//------------------------------------------------------------------------------
// File        : wb_mux.sv
// Description : 4-to-1 writeback multiplexer choosing the value written to the
//               register file: ALU result, RAM data, immediate or rs register.
// Notes       : Built from three mux2 instances. sel[0] picks within each pair
//               (mux_a, mux_b); sel[1] picks the pair (mux_c).
//               sel: 00 ALU, 01 RAM, 10 imm, 11 reg_b (see WB_* in cpu_pkg).
//------------------------------------------------------------------------------

module wb_mux(
        input  logic [7:0] alu_result,
        input  logic [7:0] ram_data,
        input  logic [7:0] imm,
        input  logic [7:0] reg_b,
        input  logic [1:0] sel,
        output logic [7:0] wb_data
);
    logic [7:0] muxa_out;
    logic [7:0] muxb_out;
    
    mux2 mux_a (
        .in0 (alu_result),
        .in1 (ram_data),
        .sel (sel[0]),
        .y   (muxa_out)
    );
    
    mux2 mux_b (
        .in0 (imm),
        .in1 (reg_b),
        .sel (sel[0]),
        .y   (muxb_out)
    );    
    
    mux2 mux_c (
        .in0 (muxa_out),
        .in1 (muxb_out),
        .sel (sel[1]),
        .y   (wb_data)
    );    
endmodule
