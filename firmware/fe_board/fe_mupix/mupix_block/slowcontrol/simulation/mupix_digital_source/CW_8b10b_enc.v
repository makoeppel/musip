`timescale 1ns/1ps

//-------------------------------------------------------------------------
// Copyright (c) 1997-2009 Cadence Design Systems, Inc.  All rights reserved.
// This work may not be copied, modified, re-published, uploaded, executed,
// or distributed in any way, in any medium, whether in whole or in part,
// without prior written permission from Cadence Design Systems, Inc.
//------------------------------------------------------------------------

//------------------------------------------------------------------------
//  Abstract   : Simulation Architecture for CW_8b10b_enc
//  RC Release : v10.10-s322_1
//------------------------------------------------------------------------

//-----------------------------------------------------------------------
// Module         : CW_8b10b_enc
// Abstract       : CW_8b10b_enc encodes 1 to 16 bytes of data using the 
//                  8b10b Direct Current (DC) balanced encoding scheme.
//
//    Pin Name     Width             Direction       Function
//-----------------------------------------------------------------------
//    clk          1 bit             Input           Clock 
//
//    rst_n        1 bit             Input           Asynchronous reset 
//                                                   active low 
//
//    init_rd_n    1 bit             Input           Synchronous 
//                                                   initialization, 
//                                                   active low 
//
//    init_rd_val  1 bit             Input           Value of initial 
//                                                   Running Disparity 
//
//    k_char       bytes bit(s)      Input           Special Character 
//                                                   controls (one control 
//                                                   per byte to encode) 
//
//    data_in      bytes × 8 bit(s)  Input           Input data for   
//                                                   encoding 
//
//    rd           1 bit             Output          Current Running 
//                                                   Disparity (before 
//                                                   encoding data presented 
//                                                   at data_in) 
//
//    data_out     bytes × 10 bit(s) Output          8b10b Encoded data
//-----------------------------------------------------------------------
//
//    Parameter    Values             Description
//-----------------------------------------------------------------------
//    bytes        1 to 16            Number of bytes to encode 
//                 Default: 2 
//
//    k28_5_only   0 or 1             Special Character subset control 
//                 Default: 0         parameter 0 for all special characters 
//                                    available, 1 for only K28.5 available 
//                                    [when k_char = HIGH, regardless of 
//                                    the value on data_in]
//----------------------------------------------------------------------- 
module CW_8b10b_enc ( 
		      clk, 
		      rst_n, 
		      init_rd_n, 
		      init_rd_val, 
		      k_char,
		      data_in, 
		      rd, 
		      data_out );
   //----------------------------------------------------------------------
   // parameters declaration
   //----------------------------------------------------------------------
   parameter		bytes = 1;
   parameter		k28_5_only = 0;
   //----------------------------------------------------------------------
   // input declaration
   //----------------------------------------------------------------------
   input 		clk;
   input 		rst_n;
   input 		init_rd_n;
   input 		init_rd_val;
   input [bytes-1:0] 	k_char;
   input [bytes*8-1:0] 	data_in;
   //----------------------------------------------------------------------
   // output declaration
   //----------------------------------------------------------------------
   output 		rd;
   output [bytes*10-1:0] data_out;
   //----------------------------------------------------------------------
   // wire declaration
   //---------------------------------------------------------------------- 
   wire 		 clk;
   wire 		 rst_n;
   wire 		 init_rd_n;
   wire 		 init_rd_val;
   wire [bytes-1:0] 	 k_char;
   wire [bytes*8-1:0] 	 data_in;
   //----------------------------------------------------------------------
   // reg declaration
   //----------------------------------------------------------------------
   reg 			 rd;
   reg [bytes*10-1:0] 	 data_out;
   //----------------------------------------------------------------------
   // function  encode_lower_5bits
   // This function encodes the lower five bits of the byte to be encoded.
   // The LSB of the returned output contains the running disparity.
   //----------------------------------------------------------------------
   function [6:0]	encode_lower_5bits;
      input[4:0]	EDCBA;
      input		rd_in;
      reg [5:0]         lookup;
      integer           count;
      begin
	 encode_lower_5bits = 7'b0;
	 case(EDCBA)
	   5'h00: lookup = 6'b100111;
	   5'h01: lookup = 6'b011101;
	   5'h02: lookup = 6'b101101;
	   5'h03: lookup = 6'b110001;
	   5'h04: lookup = 6'b110101;
	   5'h05: lookup = 6'b101001;
	   5'h06: lookup = 6'b011001;
	   5'h07: lookup = 6'b111000;
	   5'h08: lookup = 6'b111001;
	   5'h09: lookup = 6'b100101;
	   5'h0a: lookup = 6'b010101;
	   5'h0b: lookup = 6'b110100;
	   5'h0c: lookup = 6'b001101;
	   5'h0d: lookup = 6'b101100;
	   5'h0e: lookup = 6'b011100;
	   5'h0f: lookup = 6'b010111;
	   5'h10: lookup = 6'b011011;
	   5'h11: lookup = 6'b100011;
	   5'h12: lookup = 6'b010011;
	   5'h13: lookup = 6'b110010;
	   5'h14: lookup = 6'b001011;
	   5'h15: lookup = 6'b101010;
	   5'h16: lookup = 6'b011010;
	   5'h17: lookup = 6'b111010;
	   5'h18: lookup = 6'b110011;
	   5'h19: lookup = 6'b100110;
	   5'h1a: lookup = 6'b010110;
	   5'h1b: lookup = 6'b110110;
	   5'h1c: lookup = 6'b001110;
	   5'h1d: lookup = 6'b101110;
	   5'h1e: lookup = 6'b011110;
	   5'h1f: lookup = 6'b101011;
	 endcase // case({EDCBA,rd_in})
	 count = one_count(lookup);
	 if(count > 3 )
	   if(rd_in == 1'b1)
	     lookup = ~lookup;
	 count = one_count(lookup);
	 if(count > 3)
	   encode_lower_5bits = {lookup,1'b1};
	 else
	   if(count < 3)
	     encode_lower_5bits = {lookup,1'b0};
	   else
	     if(lookup == 6'b111000)
	       if(rd_in == 1'b1)
		 encode_lower_5bits = {~lookup,1'b1};
	       else
		 encode_lower_5bits = {lookup,1'b0};
	     else
	       encode_lower_5bits = {lookup,rd_in};
      end
   endfunction // encode_lower_5bits
   //----------------------------------------------------------------------
   // function one_count
   // This function counts the number of ones in the input vector.
   //----------------------------------------------------------------------
   function [31:0] one_count;      
      input  [5:0]  value;
      integer       i    ;
      begin
	 one_count = 0;
	 for(i=0;i<6;i=i+1)
	   one_count=one_count+value[i];
      end
   endfunction // one_count
   //----------------------------------------------------------------------
   // function encode_upper_3bits
   // This function encodes the upper three bits of the byte to be encoded.
   // The LSB of the returned output contains the running disparity.
   //----------------------------------------------------------------------
   function [4:0]	encode_upper_3bits;
      input[2:0]	HGF;
      input		rd_in;
      reg  [3:0]        lookup;
      integer           count;
      begin
	 encode_upper_3bits = 0;
	 case(HGF)
	   3'h0: lookup = 4'b1011;
	   3'h1: lookup = 4'b1001;
	   3'h2: lookup = 4'b0101;
	   3'h3: lookup = 4'b1100; 
	   3'h4: lookup = 4'b1101;
	   3'h5: lookup = 4'b1010;
	   3'h6: lookup = 4'b0110;
	   3'h7: lookup = 4'b1110;
	 endcase // case(HGF)
	 count = one_count(lookup);
	 if(count > 2 )
	   if(rd_in == 1'b1)
	     lookup = ~lookup;
	 count = one_count(lookup);
	 if(count > 2)
	   encode_upper_3bits = {lookup,1'b1};
	 else
	   if(count < 2)
	     encode_upper_3bits = {lookup,1'b0};
	   else
	     if(lookup == 4'b1100)
	       if(rd_in == 1'b1)
		 encode_upper_3bits = {~lookup,1'b1};
	       else
		 encode_upper_3bits = {lookup,1'b0};
	     else
	       encode_upper_3bits = {lookup,rd_in};
      end
   endfunction
   //----------------------------------------------------------------------
   // function ctrl_char_encode
   // This function encodes the one_byte as control character.
   //----------------------------------------------------------------------
   function [10:0] ctrl_char_encode;
      input [7:0]	one_byte;
      input		rd_in;
      reg   [10:0]      lookup;
      begin
	 if (k28_5_only == 1)
	   lookup = 11'b00111110101 ;
	 else
	   case (one_byte)
	     8'b00011100: lookup = 11'b00111101000 ;
	     8'b00111100: lookup = 11'b00111110011 ;
	     8'b01011100: lookup = 11'b00111101011 ;
	     8'b01111100: lookup = 11'b00111100111 ;
	     8'b10011100: lookup = 11'b00111100100 ;
	     8'b10111100: lookup = 11'b00111110101 ;
	     8'b11011100: lookup = 11'b00111101101 ;
	     8'b11111100: lookup = 11'b00111110000 ;
	     8'b11110111: lookup = 11'b11101010000 ;
	     8'b11111011: lookup = 11'b11011010000 ;
	     8'b11111101: lookup = 11'b10111010000 ;
	     8'b11111110: lookup = 11'b01111010000 ;
	     default: 
	       begin
          //cadence translate_off
		  $display("%m ERROR - Invalid Control Character, data_in = %0b ",one_byte);
          //cadence translate_on
		  lookup = 11'bxxxxxxxxxxx ;
	       end
	   endcase
	 if(rd_in == 1'b1)
	   lookup = ~lookup;
	 ctrl_char_encode = lookup;
      end
   endfunction // ctrl_char_encod
   //----------------------------------------------------------------------
   // function sp_char_encode
   // This function deals with the special case of a specific bit pattern.
   //----------------------------------------------------------------------
   function [4:0]	sp_char_encode;
      input [7:0]	one_byte;
      input		rd_in;
      begin
	 if (one_byte[7:5]==3'b111)
	   if ((one_byte[4:0]==5'b01011 ||
		one_byte[4:0]==5'b01101 ||
		one_byte[4:0]==5'b01110) &&
	       rd_in == 1'b1)
	     sp_char_encode = 5'b10000;
	   else 
	     if ((one_byte[4:0]==5'b10001 ||
		  one_byte[4:0]==5'b10010 ||
		  one_byte[4:0]==5'b10100) &&
		 rd_in == 1'b0)
	       sp_char_encode = 5'b01111;
	     else 
	       sp_char_encode = encode_upper_3bits(one_byte[7:5], rd_in);
	 else
	   sp_char_encode = encode_upper_3bits(one_byte[7:5], rd_in);
      end
   endfunction // sp_char_encode
   //----------------------------------------------------------------------
   // function encode_8b_to_10b
   // This function encodes one full one_byte by calling above mentioned 
   // functions.
   //----------------------------------------------------------------------
   function [10:0]	encode_8b_to_10b;
      input [7:0]	one_byte;
      input		rd_in;
      input		k_char;
      
      reg [6:0] 	abcdei_rd;
      reg [4:0] 	fghj_rd;
      begin
	 // Control Character be encoded
	 if (k_char == 1'b1)
	   encode_8b_to_10b = ctrl_char_encode(one_byte,rd_in);
	 else 
	   if(k28_5_only == 1'b1)
	     begin
        //cadence translate_off
		$display("%m ERROR - Invalid Input, k_char = %0b for the parameter k28_5_only = %0b",k_char,k28_5_only);
        //cadence translate_on
		encode_8b_to_10b = 11'bxxxxxxxxxxx;
	     end
	   else
	     begin
		abcdei_rd = encode_lower_5bits(one_byte[4:0],rd_in);
		fghj_rd = sp_char_encode(one_byte,abcdei_rd[0]);
		encode_8b_to_10b = {abcdei_rd[6:1], fghj_rd[4:0]};
	     end // else: !if(^{byte,rd_in} === 1'bx )
      end
   endfunction // encode_8b_to_10b
   //----------------------------------------------------------------------
   // function encode_data
   // This function encodes the complete data presented on the port by
   // calling the above function repeatitively.
   //----------------------------------------------------------------------
   function [bytes*10:0] encode_data;
      input [bytes*8-1:0] data;
      input [bytes-1:0]   k_char;
      input               rd;
      input 		  init_rd_n;
      input 		  init_rd_val;

      reg [4:0] 	  i;      
      reg [3:0] 	  j;
      reg [bytes*10-1:0]  data_out_temp;
      reg                 rd_temp;
      reg [7:0] 	  data_in_temp;
      begin
	 data_out_temp = 0;
	 rd_temp       = rd;
	 for(i=0;i<bytes;i=i+1)
	   begin
	      data_out_temp = data_out_temp << 10;
	      for(j=0;j<8;j=j+1)
		data_in_temp[j]=data[(bytes-i-1)*8+j];
	      {data_out_temp[9:0],rd_temp} 
			= encode_8b_to_10b(data_in_temp,rd_temp,k_char[bytes-i-1]);
	   end
	 if(init_rd_n == 1'b0)
	   rd_temp = init_rd_val;
	 encode_data = {data_out_temp,rd_temp};
      end
   endfunction // encode_data
   //----------------------------------------------------------------------
   always @(posedge clk or negedge rst_n )
     begin
	if(!rst_n)
	  begin
	     rd  <= 1'b0;
	     data_out  <= {bytes*10{1'b0}};
	  end
	else
	  begin
	     {data_out,rd}<=encode_data(data_in,k_char,rd,init_rd_n,init_rd_val);
	  end
     end // always @ (posedge clk or negedge rst_n )
   //----------------------------------------------------------------------
   //cadence translate_off
   //synopsys translate_off
   //----------------------------------------------------------------------
   initial
   begin : parameter_check
      reg err_flag;
      err_flag = 0;
      
      if(bytes < 1 || bytes > 16) begin
	 $display("%m ERROR - Incorrect parameter, bytes = %0d (Valid range : 1-16)",bytes);
	 err_flag = 1;
      end
      
      if(k28_5_only < 0 || k28_5_only > 1) begin
	 $display("%m ERROR - Incorrect parameter, k28_5_only = %0d (Valid range : 0-1)",k28_5_only);
	 err_flag = 1;
      end

      if (err_flag === 1) begin
	 $display ("%m ERROR - Simulation stopped due to incorrect parameter values");
	 #1 $finish;
      end
   end

   //----------------------------------------------------------------------
   //synopsys translate_on
   //cadence translate_on
   //----------------------------------------------------------------------
endmodule
//------------------------------End of file-----------------------------
