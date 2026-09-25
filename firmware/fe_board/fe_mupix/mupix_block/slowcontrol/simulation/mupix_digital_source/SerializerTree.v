/*
This module is ...
*/
`timescale 1ns/1ps

module SerializerTree (
    input   wire            clkIn_800p,
    input   wire            clkIn_1n6,
    input   wire            clkIn_3n2,
    input   wire      [7:0]       DataIn,
    output  wire      [1:0]    DataOut

);

/* 
This module has ...
*/


wire [7:0] Stage0;

//delay 2 clk 800 - 76543210
/*
always @ (posedge clkIn_3n2) begin

  Stage0[7] <= DataIn[7];
  Stage0[3] <= DataIn[6];
  Stage0[5] <= DataIn[5];
  Stage0[1] <= DataIn[4];
  Stage0[6] <= DataIn[3];
  Stage0[2] <= DataIn[2];
  Stage0[4] <= DataIn[1];
  Stage0[0] <= DataIn[0];

end
*/
assign Stage0[7] = DataIn[7];
assign Stage0[3] = DataIn[6];
assign Stage0[5] = DataIn[5];
assign Stage0[1] = DataIn[4];
assign Stage0[6] = DataIn[3];
assign Stage0[2] = DataIn[2];
assign Stage0[4] = DataIn[1];
assign Stage0[0] = DataIn[0];



reg [3:0] Stage1;

//1n6clk rising edge is never in phase with 3n2clk rising edge assured by exor relaxed clc sync by 800p

always @ (posedge clkIn_1n6) begin

  Stage1[3] <= clkIn_3n2  ?  Stage0[7] : Stage0[6];
  Stage1[2] <= clkIn_3n2  ?  Stage0[5] : Stage0[4];
  Stage1[1] <= clkIn_3n2  ?  Stage0[3] : Stage0[2];
  Stage1[0] <= clkIn_3n2  ?  Stage0[1] : Stage0[0];

end

// MM: this is not original source code, default value needed for simulation
reg [1:0] Stage2 = 2'b00;
// original: 
// reg [1:0] Stage2;

//sync between clk800 and clk 1n6 must be assured - however if 1n6edge occurs a bit later is ok

always @ (posedge clkIn_800p) begin

  Stage2[1] <= clkIn_1n6  ?  Stage1[3] : Stage1[2];
  Stage2[0] <= clkIn_1n6  ?  Stage1[1] : Stage1[0];

end

assign DataOut = Stage2;
//assign DataOut = clkIn_800p  ?  Stage2[1] : Stage2[0];


 

endmodule