module ConfigBit (

input Ck1,
input Ck2,
input Ld,
input SIn,
input RB,
output wire SOut,
output wire Q,
output wire QB

);


IMUX2XL_HV MUX_0(
.A(SIn),//not inverted
.B(Q),//not inverted
.S(RB),
.Q(outmux)//inverted
);

LHX1_HV Latch_0(
.D(outmux),//inverted
.E(Ck1),
.Q(),
.QN(outlatch0)//not inverted
);

LHX1_HV Latch_1(
.D(outlatch0),//not inverted
.E(Ck2),
.Q(SOut),//not inverted
.QN()
);

LHX1_HV Latch_2(
.D(SOut),//not inverted
.E(Ld),
.Q(Q),
.QN(QB)
);

endmodule
