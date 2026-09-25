/*
This module is ...
*/
`timescale 1ns/1ps

module SerializerTop (
    input wire [1:0] linksel,
    input  wire      [31:0]       DataIn_A,
    input wire       [3:0]        CommaIn_A,
    input wire		          dataoff_A,
	input wire				  datavalid_A,
    input  wire      [31:0]       DataIn_B,
    input wire       [3:0]        CommaIn_B,
    input wire                    dataoff_B,
	input wire				  datavalid_B,
    input  wire      [31:0]       DataIn_C,
    input wire       [3:0]        CommaIn_C,
    input wire			  dataoff_C,
	input wire				  datavalid_C,
    input  wire            clkIn_800p,
    output  wire    [1:0]       BitDataOut_A,
    output  wire    [1:0]       BitDataOut_B,
    output  wire    [1:0]       BitDataOut_C,
    output  wire    [1:0]       BitDataOut_D,
    output  wire clkOut_8n,
    input wire Aur_res_n,
    input wire Ser_res_n,
    output wire [1:0] Cnt4,
    output wire [2:0] Cnt5,
output wire clkOut_4n,
input wire clkIn_4n
//output wire clk_3n2,
//output wire clk_1n6
//input wire clkIn_3n2//change Friday
 
);


/* 
This module has ...
*/


wire clk_4n;
wire clk_3n2;
wire clk_1n6;
wire syncres;

ClockGen ClockGen_I(
    .clkIn_800p(clkIn_800p),
    .clkOut_4n(clkOut_4n),
    .clkOut_3n2(clk_3n2),
    .clkOut_1n6(clk_1n6),
    .syncres(syncres)//Ivan
);


wire	     [7:0]	    DataOut_A;
wire	     [7:0]	    ToAurora_A;
wire                KAurora_A;
wire          [9:0]   FromAurora_A;

wire	     [7:0]	    DataOut_B;
wire	     [7:0]	    ToAurora_B;
wire                KAurora_B;
wire          [9:0]   FromAurora_B;

wire	     [7:0]	    DataOut_C;
wire	     [7:0]	    ToAurora_C;
wire                KAurora_C;
wire          [9:0]   FromAurora_C;

wire	     [7:0]	    DataOut_D;
wire	     [7:0]	    ToAurora_D;
wire                KAurora_D;
wire          [9:0]   FromAurora_D;

//this is the mu pix sm clock it never has active edge when the data are latched at 4nclk after cnt4=3
//relaxed sync cond between clk8 and clk4 by pm4ns  
 
assign clkOut_8n = Cnt4[0];
//the ser takes the data on edge after cnt 3



SerializerMain SerializerMain_I(
    .DataIn_16n_A(DataIn_A),
    .CommaIn_16n_A(CommaIn_A),
    .dataoff_A(dataoff_A),
	.datavalid_A(datavalid_A),
    .DataIn_16n_B(DataIn_B),
    .CommaIn_16n_B(CommaIn_B),
    .dataoff_B(dataoff_B),
	.datavalid_B(datavalid_B),
    .DataIn_16n_C(DataIn_C),
    .CommaIn_16n_C(CommaIn_C),
    .dataoff_C(dataoff_C),
	.datavalid_C(datavalid_C),
    .clk_4n(clkIn_4n),
    .clk_3n2(clk_3n2),//change Friday clkIn_3n2
         .DataOut_A(DataOut_A),
    .ToAurora_A(ToAurora_A),
    .KAurora_A(KAurora_A),
    .FromAurora_A(FromAurora_A),
        .DataOut_B(DataOut_B),
    .ToAurora_B(ToAurora_B),
    .KAurora_B(KAurora_B),
    .FromAurora_B(FromAurora_B),
        .DataOut_C(DataOut_C),
    .ToAurora_C(ToAurora_C),
    .KAurora_C(KAurora_C),
    .FromAurora_C(FromAurora_C),
    .DataOut_D(DataOut_D),
    .ToAurora_D(ToAurora_D),
    .KAurora_D(KAurora_D),
    .FromAurora_D(FromAurora_D),
    .Cnt4(Cnt4),
    .Cnt5(Cnt5),
    .linksel(linksel),
    .res_n(Ser_res_n),
    .syncres(syncres)//Ivan
);


SerializerTree SerializerTree_A(
    .clkIn_800p(clkIn_800p),
    .clkIn_1n6(clk_1n6),
    .clkIn_3n2(clk_3n2),
    .DataIn(DataOut_A),
    .DataOut(BitDataOut_A)
);

SerializerTree SerializerTree_B(
    .clkIn_800p(clkIn_800p),
    .clkIn_1n6(clk_1n6),
    .clkIn_3n2(clk_3n2),
    .DataIn(DataOut_B),
    .DataOut(BitDataOut_B)
);
SerializerTree SerializerTree_C(
    .clkIn_800p(clkIn_800p),
    .clkIn_1n6(clk_1n6),
    .clkIn_3n2(clk_3n2),
    .DataIn(DataOut_C),
    .DataOut(BitDataOut_C)
);

SerializerTree SerializerTree_D(
    .clkIn_800p(clkIn_800p),
    .clkIn_1n6(clk_1n6),
    .clkIn_3n2(clk_3n2),
    .DataIn(DataOut_D),
    .DataOut(BitDataOut_D)
);

aurora_trans_simple aurora_trans_A(
    .clk(clkIn_4n), 
    .res_n(Aur_res_n),
    .comma_in(KAurora_A), 
    .d_in(ToAurora_A), 
    .d_en_ser(FromAurora_A)
);

aurora_trans_simple aurora_trans_B(
    .clk(clkIn_4n), 
    .res_n(Aur_res_n),
    .comma_in(KAurora_B), 
    .d_in(ToAurora_B), 
    .d_en_ser(FromAurora_B)
);

aurora_trans_simple aurora_trans_C(
    .clk(clkIn_4n), 
    .res_n(Aur_res_n),
    .comma_in(KAurora_C), 
    .d_in(ToAurora_C), 
    .d_en_ser(FromAurora_C)
);

aurora_trans_simple aurora_trans_D(
    .clk(clkIn_4n), 
    .res_n(Aur_res_n),
    .comma_in(KAurora_D), 
    .d_in(ToAurora_D), 
    .d_en_ser(FromAurora_D)
);	

endmodule
