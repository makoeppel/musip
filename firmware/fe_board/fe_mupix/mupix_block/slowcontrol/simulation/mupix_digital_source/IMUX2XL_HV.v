module IMUX2XL_HV
( input A, 
  input B,
  input S,
  output Q);

 assign Q = S ? !B : !A;

endmodule
