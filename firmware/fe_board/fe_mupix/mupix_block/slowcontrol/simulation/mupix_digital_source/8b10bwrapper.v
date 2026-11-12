`timescale 1ns/1ps
`default_nettype none

/*
  wrapper: K.28.5 only
*/

module the8b10bwrapper
(
  //global signals
  input wire clk,
  input wire resN,

  //8b10b interface
  input wire k_char,
  input wire [7:0] dataToEncoder, 
  output wire [9:0] encodedData

);

//wire [7:0] dataToEncoder_int;
//assign dataToEncoder_int = (k_char == 1'b1) ? 8'b1011_1100 : dataToEncoder; //K.28.5 OR data

CW_8b10b_enc 
#(
  .bytes(1),
  .k28_5_only(0)  //1 not possible :-(
) 
CW_8b10b_enc_I
( 
  .clk(clk), 
  .rst_n(resN), 
  .init_rd_n(1'b1), 
  .init_rd_val(1'b0), 
  .k_char(k_char),
  .data_in(dataToEncoder), 
  .rd(),       
  .data_out(encodedData) 
);

endmodule

`default_nettype wire
