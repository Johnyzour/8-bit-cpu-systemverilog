//------------------------------------------------------------------------------
// File        : sp.sv
// Description : 8-bit stack pointer. Points to the last byte pushed; the stack
//               grows down from F0, so the data area F0-FF is not used by it.
// Notes       : Synchronous. sp_dec decrements (PUSH, CALL), sp_inc increments
//               (POP, RET). Priority: reset > decrement > increment > hold.
//               Synchronous reset loads SP_INIT (F0, from cpu_pkg). No overflow
//               or underflow detection: the value wraps.
//------------------------------------------------------------------------------

module sp 
    import cpu_pkg::*;
(
    input  logic       clk,
    input  logic       rst,
    input  logic       sp_inc,
    input  logic       sp_dec,
    output logic [7:0] sp_out
);
    logic [7:0] i_sp = SP_INIT;

    always_ff @(posedge clk) 
    begin
        if (rst)
            i_sp <= SP_INIT;
        else if (sp_dec)
            i_sp <= i_sp - 1;
        else if (sp_inc)
            i_sp <= i_sp + 1;
    end

    assign sp_out = i_sp;
endmodule