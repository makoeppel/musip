module LHX1_HV
(   input D,
    input E,
    output reg Q,
    output reg QN);

always@ (E or D)
    if(E) begin
        Q   <= D;
        QN  <= !D;
    end
endmodule