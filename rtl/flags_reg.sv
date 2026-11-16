//------------------------------------------------------------------------------
// File        : flags_reg.sv
// Description : Holds the Zero (Z) and Carry (C) flags between instructions.
// Notes       : Z and C have independent load enables, so logic operations can
//               update Z while keeping C. Synchronous reset clears both and
//               takes priority over the loads.
//------------------------------------------------------------------------------

module flags_reg (
    input  logic clk,
    input  logic rst,
    input  logic z_load,
    input  logic c_load,
    input  logic z_in,
    input  logic c_in,
    output logic z_out,
    output logic c_out
);
    always_ff @(posedge clk) 
    begin
        if (rst) 
            begin
                z_out <= 1'b0;
                c_out <= 1'b0;
            end
        else 
            begin
                if (z_load)
                    z_out <= z_in;
                if (c_load)
                    c_out <= c_in;
            end
    end
endmodule