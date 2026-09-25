/*
This module is ...
*/
`timescale 1ns/1ps

module SerializerMain (
    
    input  wire      [31:0]       DataIn_16n_A,
    input  wire      [3:0]        CommaIn_16n_A,
    input  wire			  dataoff_A,
	input wire			  datavalid_A,
    input  wire      [31:0]       DataIn_16n_B,
    input  wire      [3:0]        CommaIn_16n_B,
    input  wire			  dataoff_B,
	input wire			  datavalid_B,
    input  wire      [31:0]       DataIn_16n_C,
    input  wire      [3:0]        CommaIn_16n_C,
    input  wire			  dataoff_C,
	input wire			  datavalid_C,
    input  wire             clk_4n,
    input  wire             clk_3n2,
    output  reg	     [7:0]	    DataOut_A,
    output  reg	     [7:0]	    ToAurora_A,
    output  reg                KAurora_A,
    input  wire          [9:0]   FromAurora_A,
        output  reg	     [7:0]	    DataOut_B,
    output  reg	     [7:0]	    ToAurora_B,
    output  reg                KAurora_B,
    input  wire          [9:0]   FromAurora_B,
        output  reg	     [7:0]	    DataOut_C,
    output  reg	     [7:0]	    ToAurora_C,
    output  reg                KAurora_C,
    input  wire          [9:0]   FromAurora_C,
        output  reg	     [7:0]	    DataOut_D,
    output  reg	     [7:0]	    ToAurora_D,
    output  reg                KAurora_D,
    input  wire          [9:0]   FromAurora_D,
    output reg [1:0] Cnt4,
    output reg [2:0] Cnt5,
    input wire [1:0] linksel,
    input wire res_n,
    input wire syncres
);


/* 
This module has ...
*/

reg [31:0]       DataIn_A;
reg [3:0]        CommaIn_A;

reg [31:0]       DataIn_B;
reg [3:0]        CommaIn_B;

reg [31:0]       DataIn_C;
reg [3:0]        CommaIn_C;

reg [31:0]       DataIn_D;
reg [3:0]        CommaIn_D;

//2016 change

//added res
always @(posedge clk_4n or negedge res_n) begin //must reset verilog init problem

    if(~res_n)  Cnt4 <= 2'd0;   
    else begin
      if (syncres) Cnt4 <= 2'd1;
      else Cnt4 <= Cnt4 + 2'd1;
      	
	end
end



reg ResetEn;
reg PostResetEn;

always @(posedge clk_4n) begin

    ResetEn <= (Cnt4 == 2'd2);

end

always @(negedge clk_3n2) begin

    PostResetEn <= ResetEn;//to awoid two

end



always @(posedge clk_3n2) begin

    if(PostResetEn) Cnt5 <= 3'd0;
    else Cnt5 <= Cnt5 + 3'd1;

end

reg validdatapre;

reg [31:0] datareg_A;
reg [3:0] commareg_A;

reg [31:0] datareg_B;
reg [3:0] commareg_B;

reg [31:0] datareg_C;
reg [3:0] commareg_C;

reg [1:0] linkcycle;

reg [1:0] nodatacnt_A;
reg [1:0] nodatacnt_B;
reg [1:0] nodatacnt_C;

//the ser takes the data on edge after cnt 3
always @(posedge clk_4n) begin
    if(~res_n) begin 
		linkcycle <= 2'd0; 
		nodatacnt_A <= 2'd0; 
		nodatacnt_B <= 2'd0;
		nodatacnt_C <= 2'd0;
		// ADDED for MUPIX8 REVIEw: Send A/Commas during reset
		DataIn_D <= DataIn_16n_A;
	    CommaIn_D <= CommaIn_16n_A;
	end
	else begin 
	
	 // We use linksel to choose whether link D
      // will copy one of the links a to c or
      // merge them - merging being the most tricky case
      // the merging only works if we divide the RO clock by 3, i.e. timerend = 2
      
    if(Cnt4 == 2'd3) begin 
	
	    if(datavalid_A == 1'b1) begin
		datareg_A 	<= DataIn_16n_A;
		commareg_A	<= CommaIn_16n_A;
		nodatacnt_A <= 2'd0;
	  end
	  else begin
		nodatacnt_A <= nodatacnt_A + 1;
		if(nodatacnt_A == 2'b10) begin
			datareg_A 	<= DataIn_16n_A;
			commareg_A	<= CommaIn_16n_A;
			nodatacnt_A <= 2'd0;
		end
      end
      
      if(datavalid_B == 1'b1) begin
		datareg_B 	<= DataIn_16n_B;
		commareg_B	<= CommaIn_16n_B;
	 	nodatacnt_B <= 2'd0;
	  end
	  else begin
		nodatacnt_B <= nodatacnt_B + 1;
		if(nodatacnt_B == 2'b10) begin
			datareg_B 	<= DataIn_16n_B;
			commareg_B	<= CommaIn_16n_B;
			nodatacnt_B <= 2'd0;
		end
      end
      
      if(datavalid_C == 1'b1) begin
		datareg_C 	<= DataIn_16n_C;
		commareg_C	<= CommaIn_16n_C;
		nodatacnt_C <= 2'd0;
	  end
	  else begin
		nodatacnt_C <= nodatacnt_C + 1;
		if(nodatacnt_C == 2'b10) begin
			datareg_C 	<= DataIn_16n_C;
			commareg_C	<= CommaIn_16n_C;
			nodatacnt_C <= 2'd0;
		end
      end
	
	  linkcycle <= linkcycle + 2'd1;
	  if(linkcycle == 2'd2) linkcycle <= 2'd0;
	
      DataIn_A <= DataIn_16n_A;
      CommaIn_A <= CommaIn_16n_A;
      
      DataIn_B <= DataIn_16n_B;
      CommaIn_B <= CommaIn_16n_B;
      
      DataIn_C <= DataIn_16n_C;
      CommaIn_C <= CommaIn_16n_C;
       
      case(linksel)
	2'd0: begin
	    DataIn_D <= DataIn_16n_A;
	    CommaIn_D <= CommaIn_16n_A;
	  end
	2'd1: begin
	    DataIn_D <= DataIn_16n_B;
	    CommaIn_D <= CommaIn_16n_B;
	  end
	2'd2: begin
	    DataIn_D <= DataIn_16n_C;
	    CommaIn_D <= CommaIn_16n_C;
	  end
	2'd3: begin
	  case(linkcycle)
	    2'd0: begin
	      DataIn_D	<= datareg_A;
	      CommaIn_D	<= commareg_A;
	     end
	    2'd1: begin
	      DataIn_D	<= datareg_B;
	      CommaIn_D	<= commareg_B;
	     end
	   2'd2: begin
	      DataIn_D	<= datareg_C;
	      CommaIn_D	<= commareg_C;
	     end 
	   default: begin
	       DataIn_D	<= datareg_A;
	       CommaIn_D<= commareg_A;
	   end
	  endcase
	end
      endcase
    end
	end
end


always @(posedge clk_4n) begin

      case(Cnt4)    // 
        2'd0: begin  
                ToAurora_A <= DataIn_A[31:24];       // 0 if 2 clk del in aurora
                KAurora_A  <= CommaIn_A[3];
            end
        2'd1:  begin  	
                ToAurora_A <= DataIn_A[23:16];       //
                KAurora_A  <= CommaIn_A[2];
           end 
        2'd2:  begin      
                ToAurora_A <= DataIn_A[15:8];       // 
                KAurora_A <= CommaIn_A[1];
          end
        2'd3:  begin
           	ToAurora_A <= DataIn_A[7:0];       //
           	KAurora_A  <= CommaIn_A[0];
        end 
        default: begin    
           ToAurora_A <= DataIn_A[7:0];       // 
           KAurora_A  <= CommaIn_A[0];
      end
      endcase

end

always @(posedge clk_4n) begin

      case(Cnt4)    // 
        2'd0: begin  
                ToAurora_B <= DataIn_B[31:24];       // 0 if 2 clk del in aurora
                KAurora_B  <= CommaIn_B[3];
            end
        2'd1:  begin  	
                ToAurora_B <= DataIn_B[23:16];       //
                KAurora_B  <= CommaIn_B[2];
           end 
        2'd2:  begin      
                ToAurora_B <= DataIn_B[15:8];       // 
                KAurora_B <= CommaIn_B[1];
          end
        2'd3:  begin
           	ToAurora_B <= DataIn_B[7:0];       //
           	KAurora_B  <= CommaIn_B[0];
        end 
        default: begin    
           ToAurora_B <= DataIn_B[7:0];       // 
           KAurora_B  <= CommaIn_B[0];
      end
      endcase

end

always @(posedge clk_4n) begin

      case(Cnt4)    // 
        2'd0: begin  
                ToAurora_C <= DataIn_C[31:24];       // 0 if 2 clk del in aurora
                KAurora_C  <= CommaIn_C[3];
            end
        2'd1:  begin  	
                ToAurora_C <= DataIn_C[23:16];       //
                KAurora_C  <= CommaIn_C[2];
           end 
        2'd2:  begin      
                ToAurora_C <= DataIn_C[15:8];       // 
                KAurora_C <= CommaIn_C[1];
          end
        2'd3:  begin
           	ToAurora_C <= DataIn_C[7:0];       //
           	KAurora_C  <= CommaIn_C[0];
        end 
        default: begin    
           ToAurora_C <= DataIn_C[7:0];       // 
           KAurora_C  <= CommaIn_C[0];
      end
      endcase

end

always @(posedge clk_4n) begin

      case(Cnt4)    // 
        2'd0: begin  
                ToAurora_D <= DataIn_D[31:24];       // 0 if 2 clk del in aurora
                KAurora_D  <= CommaIn_D[3];
            end
        2'd1:  begin  	
                ToAurora_D <= DataIn_D[23:16];       //
                KAurora_D  <= CommaIn_D[2];
           end 
        2'd2:  begin      
                ToAurora_D <= DataIn_D[15:8];       // 
                KAurora_D <= CommaIn_D[1];
          end
        2'd3:  begin
           	ToAurora_D <= DataIn_D[7:0];       //
           	KAurora_D  <= CommaIn_D[0];
        end 
        default: begin    
           ToAurora_D <= DataIn_D[7:0];       // 
           KAurora_D  <= CommaIn_D[0];
      end
      endcase

end



reg [39:0] TenToEight_A; 

always @(posedge clk_4n) begin

      case(Cnt4)    // 
        2'd2:           TenToEight_A[39:30] <= FromAurora_A;       // 3
        2'd3:    	TenToEight_A[29:20] <= FromAurora_A;       // 0
        2'd0:           TenToEight_A[19:10] <= FromAurora_A;       // 1
        2'd1:     	TenToEight_A[9:0] <= FromAurora_A;       // 2
        default:        TenToEight_A[9:0] <= FromAurora_A;       // 
      endcase

end

reg [39:0] TenToEight_B; 

always @(posedge clk_4n) begin

      case(Cnt4)    // 
        2'd2:           TenToEight_B[39:30] <= FromAurora_B;       // 3
        2'd3:    	TenToEight_B[29:20] <= FromAurora_B;       // 0
        2'd0:           TenToEight_B[19:10] <= FromAurora_B;       // 1
        2'd1:     	TenToEight_B[9:0] <= FromAurora_B;       // 2
        default:        TenToEight_B[9:0] <= FromAurora_B;       // 
      endcase

end

reg [39:0] TenToEight_C; 

always @(posedge clk_4n) begin

      case(Cnt4)    // 
        2'd2:           TenToEight_C[39:30] <= FromAurora_C;       // 3
        2'd3:    	TenToEight_C[29:20] <= FromAurora_C;       // 0
        2'd0:           TenToEight_C[19:10] <= FromAurora_C;       // 1
        2'd1:     	TenToEight_C[9:0] <= FromAurora_C;       // 2
        default:        TenToEight_C[9:0] <= FromAurora_C;       // 
      endcase

end

reg [39:0] TenToEight_D; 

always @(posedge clk_4n) begin

      case(Cnt4)    // 
        2'd2:           TenToEight_D[39:30] <= FromAurora_D;       // 3
        2'd3:    	TenToEight_D[29:20] <= FromAurora_D;       // 0
        2'd0:           TenToEight_D[19:10] <= FromAurora_D;       // 1
        2'd1:     	TenToEight_D[9:0] <= FromAurora_D;       // 2
        default:        TenToEight_D[9:0] <= FromAurora_D;       // 
      endcase

end

//clk32n and clk4n are only after cnt4=3 and cnt5=4 in phase
//it is assured than in this moment different segments of tento8 reg are written and read - ring buffer pronciple
//relaxed sync between clocks by 4n + 800p
//changed counters 2 3 0 1 above to relax more


reg [7:0] Tree1L_A;
reg [7:0] Tree1R_A;

always @(posedge clk_3n2) begin

      case(Cnt5)    // 
        3'd0:           Tree1L_A <= TenToEight_A[39:32];       // 
        3'd1:    	Tree1R_A <= TenToEight_A[31:24];       // 
        3'd2:           Tree1L_A <= TenToEight_A[23:16];       // 
        3'd3:     	Tree1R_A <= TenToEight_A[15:8];       //
        3'd4:     	Tree1L_A <= TenToEight_A[7:0];       //  
        default:        Tree1L_A <= TenToEight_A[7:0];       // 
      endcase

end

always @(posedge clk_3n2) begin

      case(Cnt5)    // 
        3'd1:           DataOut_A <= Tree1L_A;       // 
        3'd2:    	DataOut_A <= Tree1R_A;       // 
        3'd3:           DataOut_A <= Tree1L_A;       // 
        3'd4:     	DataOut_A <= Tree1R_A;       //
        3'd0:     	DataOut_A <= Tree1L_A;       //  
        default:        DataOut_A <= Tree1L_A;       // 
      endcase

end

reg [7:0] Tree1L_B;
reg [7:0] Tree1R_B;

always @(posedge clk_3n2) begin

      case(Cnt5)    // 
        3'd0:           Tree1L_B <= TenToEight_B[39:32];       // 
        3'd1:    	Tree1R_B <= TenToEight_B[31:24];       // 
        3'd2:           Tree1L_B <= TenToEight_B[23:16];       // 
        3'd3:     	Tree1R_B <= TenToEight_B[15:8];       //
        3'd4:     	Tree1L_B <= TenToEight_B[7:0];       //  
        default:        Tree1L_B <= TenToEight_B[7:0];       // 
      endcase

end

always @(posedge clk_3n2) begin

      case(Cnt5)    // 
        3'd1:           DataOut_B <= Tree1L_B;       // 
        3'd2:    	DataOut_B <= Tree1R_B;       // 
        3'd3:           DataOut_B <= Tree1L_B;       // 
        3'd4:     	DataOut_B <= Tree1R_B;       //
        3'd0:     	DataOut_B <= Tree1L_B;       //  
        default:        DataOut_B <= Tree1L_B;       // 
      endcase

end

reg [7:0] Tree1L_C;
reg [7:0] Tree1R_C;

always @(posedge clk_3n2) begin

      case(Cnt5)    // 
        3'd0:           Tree1L_C <= TenToEight_C[39:32];       // 
        3'd1:    	Tree1R_C <= TenToEight_C[31:24];       // 
        3'd2:           Tree1L_C <= TenToEight_C[23:16];       // 
        3'd3:     	Tree1R_C <= TenToEight_C[15:8];       //
        3'd4:     	Tree1L_C <= TenToEight_C[7:0];       //  
        default:        Tree1L_C <= TenToEight_C[7:0];       // 
      endcase

end

always @(posedge clk_3n2) begin

      case(Cnt5)    // 
        3'd1:           DataOut_C <= Tree1L_C;       // 
        3'd2:    	DataOut_C <= Tree1R_C;       // 
        3'd3:           DataOut_C <= Tree1L_C;       // 
        3'd4:     	DataOut_C <= Tree1R_C;       //
        3'd0:     	DataOut_C <= Tree1L_C;       //  
        default:        DataOut_C <= Tree1L_C;       // 
      endcase

end

reg [7:0] Tree1L_D;
reg [7:0] Tree1R_D;

always @(posedge clk_3n2) begin

      case(Cnt5)    // 
        3'd0:           Tree1L_D <= TenToEight_D[39:32];       // 
        3'd1:    	Tree1R_D <= TenToEight_D[31:24];       // 
        3'd2:           Tree1L_D <= TenToEight_D[23:16];       // 
        3'd3:     	Tree1R_D <= TenToEight_D[15:8];       //
        3'd4:     	Tree1L_D <= TenToEight_D[7:0];       //  
        default:        Tree1L_D <= TenToEight_D[7:0];       // 
      endcase

end

always @(posedge clk_3n2) begin

      case(Cnt5)    // 
        3'd1:           DataOut_D <= Tree1L_D;       // 
        3'd2:    	DataOut_D <= Tree1R_D;       // 
        3'd3:           DataOut_D <= Tree1L_D;       // 
        3'd4:     	DataOut_D <= Tree1R_D;       //
        3'd0:     	DataOut_D <= Tree1L_D;       //  
        default:        DataOut_D <= Tree1L_D;       // 
      endcase

end

endmodule
