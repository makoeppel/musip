

//////////////////////////////////////////////////////////////////////////////////
// Module Name:    aurora_trans Ivan
// Description:
//////////////////////////////////////////////////////////////////////////////////
module aurora_trans_simple(clk, res_n, comma_in, d_in, d_en_ser);

    input wire clk;
    input wire  res_n;
    input wire  comma_in;
    input wire  [7:0] d_in;
    output wire  [9:0] d_en_ser;

reg [7:0] data;






/*
full_8b_10b ENCODER_I(
	.clk(clk),
	.res_n(res_n),
	.d_in(d_fsm_en),
	.d_out(d_en_ser));
*/


reg comma;




always @ (posedge clk or negedge res_n) begin
  if(~res_n)begin
      comma <= 1'b1;
      data <= 8'hBC;
  end
  else begin
    data <= d_in;
    comma <= comma_in;
  end
end



//original code


the8b10bwrapper ENCODER_I
(
  //global signals
  .clk(clk),
  .resN(res_n),

  //8b10b interface
  .k_char(comma),//THIS IS IMPORTANT !!! Ivan
  .dataToEncoder(data),//
  .encodedData(d_en_ser)

);





//new code

/*
wire [8:0] dfordecoder;
assign dfordecoder = {comma, data[7:0]};

full_8b_10b full_8b_10b_I
(
  .clk(clk),
  .res_n(res_n),
  .d_in(dfordecoder),
  .d_out(d_en_ser)
);
*/


endmodule