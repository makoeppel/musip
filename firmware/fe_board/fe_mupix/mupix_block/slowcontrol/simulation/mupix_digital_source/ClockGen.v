/*
This module is ...
*/
`timescale 1ns/1ps

module ClockGen (
    input   wire            clkIn_800p,
    output  wire             clkOut_4n,
    output  wire             clkOut_3n2,
    output  reg             clkOut_1n6,
    output reg syncres
);

/*
This module has ...
*/


reg [3:0] FastCnt5 = 4'b1111;

reg [2:0] FastCnt4 = 3'b111;


wire ResetCnt;
assign ResetCnt = ~FastCnt5[0];

always @ (posedge clkIn_800p) begin

FastCnt5[3] <= ResetCnt;//res 1 cnt 1
FastCnt5[2] <= ~(~ResetCnt & ~FastCnt5[3]);//res 1 cnt 0 res 0 cnt cnt
FastCnt5[1] <= ~(~ResetCnt & ~FastCnt5[2]);//res 1 cnt 0 res 0 cnt cnt
FastCnt5[0] <= ~(~ResetCnt & ~FastCnt5[1]);//res 1 cnt 0 res 0 cnt cnt

end

wire ResetCnt4B;//16 oct

assign ResetCnt4B = FastCnt4[0];//16 oct

reg [3:0] resreg;

reg resregor1;
reg resregor2;



always @ (posedge clkIn_800p) begin

 resreg[3:0] <= {~(FastCnt5[3] & FastCnt4[2]), resreg[3:1]};

 resregor1 <= ~(resreg[3] & resreg[2]);
 resregor2 <= ~(resreg[1] & resreg[0]);

 syncres <= ~(~resregor1 & ~resregor2);

end


always @ (posedge clkIn_800p) begin

FastCnt4[2] <= ~ResetCnt4B;//res 1 cnt 1
FastCnt4[1] <= ~(ResetCnt4B & ~FastCnt4[2]);//res 1 cnt 0 res 0 cnt cnt
FastCnt4[0] <= ~(ResetCnt4B & ~FastCnt4[1]);//res 1 cnt 0 res 0 cnt cnt

end

assign clkOut_4n = FastCnt5[2];
assign clkOut_3n2 = FastCnt4[1];

reg clkOut_3n2_del;
reg clkOut_1n6AND1, clkOut_1n6AND2, clkOut_1n6del;

always @ (posedge clkIn_800p) begin


  clkOut_3n2_del <= clkOut_3n2;
  clkOut_1n6AND1 <= ~(clkOut_3n2_del & ~clkOut_3n2);
  clkOut_1n6AND2 <= ~(~clkOut_3n2_del & clkOut_3n2);
  clkOut_1n6del <= ~(clkOut_1n6AND1 & clkOut_1n6AND2);//was del
  clkOut_1n6 <= clkOut_1n6del;

end

endmodule
