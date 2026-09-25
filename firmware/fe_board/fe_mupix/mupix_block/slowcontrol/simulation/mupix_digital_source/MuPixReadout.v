/*
This module is ...
*/
`timescale 1ns/1ps

module MuPixReadout (
    
      input wire clk,
      input wire res_n,
	input wire [7:0] Fixedpattern,	 
	 input wire [8:0] RowAddFromDet,
	 input wire [6:0] ColAddFromDet,
	 input wire [15:0] TSFromDet,

	 input wire [10:0] TSToDet,
	 input wire [23:0] BinCounter,
	 
	 input wire PriFromDet,
	 
	 output wire LdCol,
	 output wire RdCol,
	 output wire LdPix,
	 output wire PullDN,
	 
	 input wire [3:0] timerend,
	 input wire [3:0] slowdownend,
	 input wire [4:0] slowdownLdColEnd,
	 input wire [5:0] maxcycend,
	 input wire [3:0] resetckdivend,
	 input wire sendcounter,
	 output reg [31:0] DataOut,
	 output reg [31:0] DataOut2SPI,//SPI
	 input CSB,//SPI
	 output reg takeme,//SPI
	 input UseSPI,//SPI
	 output reg [3:0] CommaOut,
	 output reg datavalid,
	 output reg dataoff,
	 input wire [63:0] SC_DataIn,
	 input wire SC_Data_ready,
	 input wire countsheeps
);


/* 
This module has ...
*/





//State Machine

/*

parameter StateSync = 0;

parameter StatePD1 = 1;
parameter StatePD2 = 2;

parameter StateLdCol1 = 3;
parameter StateLdCol2 = 4;

parameter StateLdPix1 = 5;
parameter StateLdPix2 = 6;

parameter StateRdCol1 = 7;
parameter StateRdCol2 = 8;

parameter StateSendCounter1 = 9;
parameter StateSendCounter2 = 10;

*/


parameter StateSync = 11'b100_0000_0000;

parameter StatePD1 = 11'b010_0000_0000;
parameter StatePD2 = 11'b001_0000_0000;

parameter StateLdCol1 = 11'b000_1000_0000;
parameter StateLdCol2 = 11'b000_0100_0000;

parameter StateLdPix1 = 11'b000_0010_0000;
parameter StateLdPix2 = 11'b000_0001_0000;

parameter StateRdCol1 = 11'b000_0000_1000;
parameter StateRdCol2 = 11'b000_0000_0100;

parameter StateSendCounter1 = 11'b000_0000_0010;
parameter StateSendCounter2 = 11'b000_0000_0001;


//reg [3:0] State;


reg[10:0] State;




reg[3:0] timer;
reg[3:0] slowdown;

reg[4:0] slowdownLdCol;//new

reg[5:0] maxcyc;

reg[7:0] resetcounter;
reg[3:0] resetckdiv;



wire SuspendSM;//SPI
reg SPIFull;//SPI

assign SuspendSM = UseSPI ? SPIFull : 1'b0;//SPI



always @( posedge clk or negedge res_n) begin
 if(~res_n) begin
				State <= StateSync;
				timer <= 0;
				slowdown <= 0;
				slowdownLdCol <= 0;//new
				maxcyc <= 0;
				resetcounter <= 0;

 end//res
 else begin   
   
  if(timer < timerend) timer <= timer + 1;
  else timer <= 0;
	if(timer == 0) begin
  
  if(SuspendSM == 0) begin//suspending when SPI reg is full
  
	case ( State )

		StateSync: begin
		   if(resetckdiv < resetckdivend) resetckdiv <= resetckdiv + 1;
       else resetckdiv <= 0;
         
       if(resetckdiv==0)
          resetcounter <= resetcounter + 1;   
		  
		  if(resetcounter == 8'd255)
		    if(sendcounter)
		        State <= StateSendCounter1;
		    else
		        State <= StatePD1;
		
		end
		StatePD1: begin
		
			State <= StatePD2;

		
		end		
		StatePD2: begin
		
			State <= StateLdCol1;
		
		end

		StateLdCol1: begin
		
			if(slowdownLdCol < slowdownLdColEnd) slowdownLdCol <= slowdownLdCol + 1;//new
			else begin
					slowdownLdCol <= 0;
					State <= StateLdCol2;
			end
				
		end
		
		StateLdCol2: begin		

			if(countsheeps == 1) begin
				if(PriFromDet)begin
					State <= StateRdCol1;
				end
				else begin
					State <= StateLdPix1;
				end
			end
			else begin
				State <= StateLdPix1;
			end

		end  

		StateLdPix1: begin

			if(PriFromDet)begin
				State <= StateLdPix2;//if there are hits in last frame go fast
			end
			else begin//if no hits in last frame wait longer in LdPix state
			        if(slowdown < slowdownend) slowdown <= slowdown + 1;
				else begin
					slowdown <= 0;
					State <= StateLdPix2;
				end
			end
			
		
		end		
		StateLdPix2: begin

			if(PriFromDet)begin//if there are hits read col
				State <= StateRdCol1;
			end//otherwise start state
		
			else State <= StatePD1;
		
		end		

		
		StateRdCol1: begin
		
			State <= StateRdCol2;


		
		end
		
		StateRdCol2: begin
		
			if(PriFromDet)begin//if there are hits read col
			    if(maxcyc < maxcycend) begin//if not too many cycles
					maxcyc <= maxcyc + 1;
					State <= StateRdCol1;
				end
				else begin//if too many cycles start state
					maxcyc <= 0;
					State <= StatePD1;
				end
			end//if no hits start state	
			else begin 
			  State <= StatePD1;
			  maxcyc <= 0;  // Change from MuPix7: Reset maxcyc here
			end  
		end
		
		StateSendCounter1: begin
		  
		  State <= StateSendCounter2;
	
	   end
	   
	 	StateSendCounter2: begin
		  
		  if(sendcounter) begin
		    State <= StateSendCounter1;
		  end
		   else begin
		     State <= StatePD1;
	     end
	   end
		
		default: State <= StatePD1;//to avoid hanging

	endcase
  end//suspend SPI
  end//timer	
 end//not res
end//alw

assign LdPix = (State == StateLdPix1);
assign LdCol = (State == StateLdCol1);
assign RdCol = (State == StateRdCol1);
assign PullDN = (State == StatePD1);



			//very important valid hit must stay two clock intervals
			//otherwise will be not taken by serializer

always @( posedge clk or negedge res_n) begin
 if(~res_n) begin
	  //DataOut <= {8'hFF, 8'hFF, 8'hFF, TSToDet[7:0]};//Ivan no preset
	  DataOut <= {8'hBC, 8'hBC, 8'hBC, 8'hBC}; // Nik: yes please use preset
	  CommaOut <= {1'b1,1'b1,1'b1,1'b1};
	  dataoff <= 0;
	  datavalid <= 0;
	  
 end//res
 else begin
    if(State == StateSync) begin
      DataOut <= {8'hBC, 8'hBC, 8'hBC, 8'hBC};
      CommaOut <= {1'b1,1'b1,1'b1,1'b1};  
	  datavalid <= 1;
  end
   else if((timer == 0)&&(State == StateLdCol2)) begin//changed from 1
	// Change from MuPix7: Swapped order of words
	DataOut <= {8'h1C, Fixedpattern, 8'h1C, Fixedpattern};
	CommaOut <= {1'b1,1'b0,1'b1,1'b0};
	dataoff <= 0;
	datavalid <= 1;
    end
 else if((timer == 0)&&(State == StateRdCol2)) begin//changed from 1
	// Change from MuPix7: Swapped order of words
	DataOut <= {TSFromDet[15:0], ColAddFromDet[6:0],  RowAddFromDet[8:0]};
	CommaOut <= {1'b0,1'b0,1'b0,1'b0};
	dataoff <= 0;
	datavalid <= 1;
    end
	// CHANGE FOR MUPIX8 REVIEW: check for slowdown==slowdownend or pri from det! 
    else if((timer == 0)&&(State == StateLdPix2) ) begin // change from MuPix7: capture counter on StateLdPix1 insteda of StatePD1 //changed from 1 removed || cnt = max
	// Change from MuPix7: Swapped order of words
	DataOut <= {BinCounter[23:16], BinCounter[15:8], BinCounter[7:0], TSToDet[7:0]};
	CommaOut <= {1'b0,1'b0,1'b0,1'b0};
	dataoff <= 0;
	datavalid <= 1;
    end
 else if((timer == 0)&&(State == StateSendCounter1)) begin
	// Change from MuPix7: Swapped order of words
	DataOut <= {BinCounter[23:16], BinCounter[15:8], BinCounter[7:0], TSToDet[7:0]};
	CommaOut <= {1'b0,1'b0,1'b0,1'b0};
	dataoff <= 0;
	datavalid <= 1;
    end
    else if((timer == 0)&&(State == StatePD2)) begin		//new SC
		DataOut <= {8'h5C, 8'hBC, 8'h5C, 8'hBC};			//K28.2 K28.5 K28.2 K28.5
	   CommaOut <= {1'b1,1'b1,1'b1,1'b1};
		dataoff <= 0;
		datavalid <= 1;
		//SC_DataIn_reg[63:0] <= SC_DataIn[63:0]; //OPTION
	 end
	 else if((timer == 0)&&(slowdownLdCol == 1)) begin		//new SC	// State LDCol1
		DataOut <= {SC_DataIn[31:24],SC_DataIn[23:16],SC_DataIn[15:8],SC_DataIn[7:0]};					//Word 1
		//DataOut <= {SC_DataIn_reg[31:24],SC_DataIn_reg[23:16],SC_DataIn_reg[15:8],SC_DataIn_reg[7:0]};					//Word 1 OPTION
		CommaOut <= {1'b0,1'b0,1'b0,1'b0};
		dataoff <= 0;
		datavalid <= 1;
	 end
	 else if((timer == 0)&&(slowdownLdCol == 3)) begin		//new SC	// State LDCol1
		DataOut <= {SC_DataIn[63:56],SC_DataIn[55:48],SC_DataIn[47:40],SC_DataIn[39:32]};				//Word 2
		//DataOut <= {SC_DataIn_reg[63:56],SC_DataIn_reg[55:48],SC_DataIn_reg[47:40],SC_DataIn_reg[39:32]};				//Word 2 OPTION
		CommaOut <= {1'b0,1'b0,1'b0,1'b0};
		dataoff <= 0;
		datavalid <= 1;
	 end
	 else begin
	dataoff <= 1;
	if(dataoff) begin 
	   DataOut <= {8'hBC, 8'hBC, 8'hBC, 8'hBC};
	   CommaOut <= {1'b1,1'b1,1'b1,1'b1};
	   datavalid <= 0;
   end
  end
 end
end





//SPI

reg CSBSync;
reg CSBSyncDel;
//reg takeme;



always @( posedge clk or negedge res_n ) begin

 if (~res_n) begin
 
 	CSBSync <= 1;
	CSBSyncDel <= 1;
	SPIFull <= 0;
	takeme <= 0;
	
 end

 else begin

	CSBSync <= CSB;
	CSBSyncDel <= CSBSync;

 	if(~UseSPI) SPIFull <= 0;
 	else begin
		if ((SPIFull==0) && (timer == 0)&&(State == StateRdCol2)) begin//if data are valid spi full goes 1 and data are stored in data2spi
			SPIFull <= 1;
			DataOut2SPI <= {TSFromDet[15:0], ColAddFromDet[6:0],  RowAddFromDet[8:0]};
		end
	end
	
	if(~UseSPI) takeme<=0;//takeme signals goes hi when data are there (full) and if csb signal is 1, if no spi ro is used takeme is always 0
	else begin 
	
		if (SPIFull & CSBSync & ~takeme) takeme<=1; 
		


		if (takeme & SPIFull & CSBSync & ~CSBSyncDel) begin//takeme signal and full signal will go low at the rising edge of csb
			SPIFull <= 0;
			takeme <= 0;

		end
	
	end




 end//not reset
end//always



	

endmodule
