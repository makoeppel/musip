/*
This module is generating the Gray timestamps and a binary counter
*/
`timescale 1ns/1ps

module MuPixTSGen (

      input wire fastclk,
      input wire res_n,
      input wire syncRes,
      input wire [5:0] ckdivend,
      input wire [5:0] ckdivend2,
      input wire [5:0] tsphase,
      output reg [10:0] TSToDet,
      output reg [4:0] TSToDet2,
      output [23:0] BinCounterOut
);



reg [5:0] ckdiv;
reg [5:0] ckdiv2;


wire [10:0] TSToReg;


wire [4:0] TSToReg2;

reg [4:0] BinCounter2;

reg [23:0] BinCounter;

assign  BinCounterOut = BinCounter[23:0];

always @( posedge fastclk or negedge res_n) begin

if(~res_n)begin
	    ckdiv <= 0;
	    ckdiv2 <= 0;
	    BinCounter <= 0;
	    BinCounter2 <= 0;
end
else begin
	if(syncRes) begin
	    ckdiv <= 0;
	    ckdiv2 <= 0;
	    BinCounter <= 0;
	    BinCounter2 <= 0;
	    TSToDet <= 0;
	end//syres
	else begin
	    TSToDet <= TSToReg;
	    TSToDet2 <= TSToReg2;
	    if(ckdiv < ckdivend) ckdiv <= ckdiv+1;
	    else ckdiv <= 0;

	    if(ckdiv2 < ckdivend2) ckdiv2 <= ckdiv2+1;
	    else ckdiv2 <= 0;

	    if (ckdiv2 == tsphase) BinCounter2 <= BinCounter2+1;
	    if (ckdiv == tsphase) BinCounter <= BinCounter+1;

	end//nosyres
end
end

assign TSToReg[10] = BinCounter[10];

generate
genvar j;
for (j=0; j<10; j=j+1) begin:myknurzelwurzel
  assign TSToReg[j] = BinCounter[j+1] ^ BinCounter[j];
end
endgenerate


assign TSToReg2[4] = BinCounter2[4];


assign TSToReg2[3] = BinCounter2[4] ^ BinCounter2[3];
assign TSToReg2[2] = BinCounter2[3] ^ BinCounter2[2];
assign TSToReg2[1] = BinCounter2[2] ^ BinCounter2[1];
assign TSToReg2[0] = BinCounter2[1] ^ BinCounter2[0];



endmodule
