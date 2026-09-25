
`timescale 1ns/1ps



module MuPixDigitalTop (
//from matrix - part A
input wire PriFromDet_PartA,
input wire [8:0] RowAddFromDet_PartA,
input wire [6:0] ColAddFromDet_PartA,
input wire [15:0] TSFromDet_PartA,
//from matrix - part B
input wire PriFromDet_PartB,
input wire [8:0] RowAddFromDet_PartB,
input wire [6:0] ColAddFromDet_PartB,
input wire [15:0] TSFromDet_PartB,
//from matrix - part C
input wire PriFromDet_PartC,
input wire [8:0] RowAddFromDet_PartC,
input wire [6:0] ColAddFromDet_PartC,
input wire [15:0] TSFromDet_PartC,
//to matrix
output wire [10:0] TSToDet,
output wire [4:0] TSToDet2,
// to matrix - part A
output wire LdCol_PartA,
output wire RdCol_PartA,
output wire LdPix_PartA,
output wire PullDN_PartA,
// to matrix - part B
output wire LdCol_PartB,
output wire RdCol_PartB,
output wire LdPix_PartB,
output wire PullDN_PartB,
// to matrix - part C
output wire LdCol_PartC,
output wire RdCol_PartC,
output wire LdPix_PartC,
output wire PullDN_PartC,

//sm control
input wire   Aur_res_n,
input wire   Ser_res_n,
input wire   RO_res_n,

input wire sync_reset_Ext,//syncRes,
//ser out - four links
output wire  [1:0]  d_out_A,
output wire  [1:0]  d_out_B,
output wire  [1:0]  d_out_C,
output wire  [1:0]  d_out_D,
//clk in
input wire clk_800p,
//clk out
output wire clk_8n,
//debug
output wire [1:0] Cnt4,
output wire [2:0] Cnt5,
output wire clkOut_4n,
// clock
input wire clkIn_4n,

//SlowControl

//Enable Multiplexing
input wire EnSC,//

input wire ref_clock,//
input wire [3:0] slow_clock_div,//
input wire Serial_In,//
input wire [3:0] Chip_Address,//
input wire ResetSCB,//


input wire Bias_Back_In,
input wire VDAC_Back_In,
input wire Col_Back_In,
input wire Test_Back_In,
input wire TDAC_Back_In,
input wire ADC_CompIn,		//ADC Komparator

output wire sync_reset_SC,
output wire ResetBiasBlocksB,//ivan changed to B

input wire SIn_Ext,
input wire Ck1_Ext,
input wire Ck2_Ext,
input wire Readback_Ext,

input wire Load_BiasExt,
input wire Load_ConfExt,
input wire Load_VDACExt,
input wire Load_ColExt,
input wire Load_TestExt,
input wire Load_TDACExt,

output wire SIn_Bias,
output wire Load_Bias,
output wire Ck1_Bias,
output wire Ck2_Bias,

output wire SIn_VDAC,
output wire Load_VDAC,
output wire Ck1_VDAC,
output wire Ck2_VDAC,

output wire SIn_Col,
output wire Load_Col,
output wire Ck1_Col,
output wire Ck2_Col,

output wire SIn_Test,
output wire Load_Test,
output wire Ck1_Test,
output wire Ck2_Test,

output wire SIn_TDAC,
output wire Load_TDAC,
output wire Ck1_TDAC,
output wire Ck2_TDAC,

output wire Readback,

///
input wire PCH_Ext,
input wire WrEn_Ext,
input wire WR_Ext,
input wire Injection_Ext,

output wire PCH,
output wire WrEnable,
output wire WR,
output wire Injection,

output wire SOutSC, 	//output of the data reveiver register
output wire slow_clockSC,

//ADC
output wire [9:0] ADC_VDAC,
output wire [4:0] ADC_Mux,

input wire ResetConfigB,//reset of config reg
output wire [39:0] QConfigOut,
output wire [39:0] QBConfigOut,

//SPI
input wire MOSI,
output wire MISO,
input wire SCK,
input wire CSB,
input wire UseSPI,
input wire UseSPIRO,
	 
output wire clk_ts_out,
input wire clk_ts_in
);

wire SIn_Conf;
wire Load_Conf;
wire Ck1_Conf;
wire Ck2_Conf;


wire [31:0] DataOut_A;
wire [31:0] DataOut_B;
wire [31:0] DataOut_C;
wire [3:0]  CommaOut_A;
wire [3:0]  CommaOut_B;
wire [3:0]  CommaOut_C;
wire dataoff_A;
wire dataoff_B;
wire dataoff_C;
wire datavalid_A;
wire datavalid_B;
wire datavalid_C;
wire [23:0] BinCounter;
wire clk_3n2;
wire clk_1n6;
wire syncRes;

wire Data_ready;
wire [63:0] DataOut;


reg RegData_ready;
reg [63:0] RegDataOut;

//new
always @( posedge clkIn_4n ) begin
RegData_ready <= Data_ready;
RegDataOut <= DataOut;
end


wire SIn_BiasSC;
wire Load_BiasSC;
wire Ck1_BiasSC;
wire Ck2_BiasSC;

wire SIn_ConfSC;
wire Load_ConfSC;
wire Ck1_ConfSC;
wire Ck2_ConfSC;

wire SIn_VDACSC;
wire Load_VDACSC;
wire Ck1_VDACSC;
wire Ck2_VDACSC;

wire SIn_ColSC;
wire Load_ColSC;
wire Ck1_ColSC;
wire Ck2_ColSC;

wire SIn_TestSC;
wire Load_TestSC;
wire Ck1_TestSC;
wire Ck2_TestSC;

wire SIn_TDACSC;
wire Load_TDACSC;
wire Ck1_TDACSC;
wire Ck2_TDACSC;

wire Readback_SC;
wire PCH_SC;
wire WrEn_SC;
wire WR_SC;

wire Injection_SC;

 wire [5:0] Ickdivend;
 wire [5:0] Ickdivend2;
 wire [5:0] Itsphase;  
 wire [3:0] Itimerend;
 wire [3:0] Islowdownend;
 wire [5:0] Imaxcycend;
 wire [3:0] Iresetckdivend;
 wire Isendcounter;
 
wire [1:0] Ilinksel;

wire EnSync_SC;
wire [4:0] IslowdownLdColEnd;

wire [89:0] ResetLevelB;//57 -> 89
 
parameter INI_QConfigOut = 40'd0;//8 -> 40


parameter INI_slowdownLdColEnd = 5'd7;
parameter INI_EnSync_SC = 1'd1; 
parameter INI_RO_res_n = 1'd1;
parameter INI_Ser_res_n = 1'd1;
parameter INI_Aur_res_n = 1'd1;
parameter INI_linksel = 2'd3;//merging
parameter INI_tsphase = 6'd0;
parameter INI_sendcounter = 1'd0;
parameter INI_resetckdivend = 4'd0;
parameter INI_maxcycend = 6'd63;
parameter INI_slowdownend = 4'd0;
parameter INI_timerend = 4'd2;
parameter INI_ckdivend2 = 6'd3;
parameter INI_ckdivend = 6'd3;
parameter INI_space = 2'd3;
 
assign ResetLevelB = {INI_QConfigOut,INI_slowdownLdColEnd,INI_EnSync_SC,INI_RO_res_n,INI_Ser_res_n,INI_Aur_res_n,INI_linksel,INI_tsphase,INI_sendcounter,INI_resetckdivend,INI_space,INI_maxcycend,INI_slowdownend,INI_timerend,INI_ckdivend2,INI_ckdivend}; 
 
 
 wire [89:0] QConfig;//57 -> 89
 wire [89:0] QBConfig;//57 -> 89
 wire [90:0] SInConfig;//58 -> 90
 
 
 
 
 wire SOut_int;

 
 
assign SInConfig[0] = SIn_Conf;
assign SOut_int = SInConfig[90];
 
assign Ickdivend = QConfig[5:0];
assign Ickdivend2 = QConfig[11:6];
assign Itimerend = QConfig[15:12];
assign Islowdownend = QConfig[19:16];
assign Imaxcycend = QConfig[25:20];//26 27 not used 16 10
assign Iresetckdivend = QConfig[31:28];
assign Isendcounter = QConfig[32];
assign Itsphase = QConfig[38:33];//16 10
assign Ilinksel = QConfig[40:39];

assign EnSync_SC = QConfig[44];
assign IslowdownLdColEnd = QConfig[49:45];

//EnPLL,Invert,SelExt,SelSlow,AlwaysEn,ConnRes
assign QConfigOut = QConfig[89:50];//57 -> 89
assign QBConfigOut = QBConfig[89:50];//57 -> 89


wire countsheeps;
assign countsheeps = QConfig[88];
assign clk_ts_out = QConfig[89] ? clk_800p : ref_clock;

wire ResetConfigBfinal;
assign ResetConfigBfinal  =  EnSC ? ResetBiasBlocksB : ResetConfigB;


 
generate 

genvar j;




for (j=0; j<90; j=j+1) begin:GenConfigBit //57 -> 89
  
 ConfigBit ConfigBit_I(  
.Ck1(Ck1_Conf),
.Ck2(Ck2_Conf),
.Ld(Load_Conf),
.SIn(SInConfig[j]),
.RB(Readback),
.SOut(SInConfig[j+1]),
.Q(QConfig[j]),
.QB(QBConfig[j])
  
);
  
end
endgenerate


 wire [15:0] TSFromDet_PartA_int;//20->16
 wire [15:0] TSFromDet_PartB_int;//20->16 //new 
 wire [15:0] TSFromDet_PartC_int;//20->16 //new
 
 



wire [8:0] RowAddFromDet_PartA_int;
wire [6:0] ColAddFromDet_PartA_int;

wire [8:0] RowAddFromDet_PartB_int;
wire [6:0] ColAddFromDet_PartB_int;

wire [8:0] RowAddFromDet_PartC_int;
wire [6:0] ColAddFromDet_PartC_int;




Buffer Buffer_I(
	
	
	.TSFromDet_PartA_int(TSFromDet_PartA_int),//new
	.TSFromDet_PartA(TSFromDet_PartA),
	.TSFromDet_PartB_int(TSFromDet_PartB_int),//new
	.TSFromDet_PartB(TSFromDet_PartB),
	.TSFromDet_PartC_int(TSFromDet_PartC_int),//new
	.TSFromDet_PartC(TSFromDet_PartC),
	
	.RowAddFromDet_PartA_int(RowAddFromDet_PartA_int),
	.RowAddFromDet_PartA(RowAddFromDet_PartA),
	
	.ColAddFromDet_PartA_int(ColAddFromDet_PartA_int),
	.ColAddFromDet_PartA(ColAddFromDet_PartA),
	
	.RowAddFromDet_PartB_int(RowAddFromDet_PartB_int),
	.RowAddFromDet_PartB(RowAddFromDet_PartB),
	
	.ColAddFromDet_PartB_int(ColAddFromDet_PartB_int),
	.ColAddFromDet_PartB(ColAddFromDet_PartB),
	
	.RowAddFromDet_PartC_int(RowAddFromDet_PartC_int),
	.RowAddFromDet_PartC(RowAddFromDet_PartC),
	
	.ColAddFromDet_PartC_int(ColAddFromDet_PartC_int),
	.ColAddFromDet_PartC(ColAddFromDet_PartC),
	
	.RdCol_PartA(RdCol_PartA),
	
	.RdCol_PartB(RdCol_PartB),
	
	.RdCol_PartC(RdCol_PartC)

);


wire [31:0] SPIOut;

assign SIn_Bias  =  EnSC ? SIn_BiasSC : UseSPI ? SPIOut[0] : SIn_Ext;
assign Ck1_Bias  =  EnSC ? Ck1_BiasSC : UseSPI ? SPIOut[1] : Ck1_Ext;
assign Ck2_Bias  =  EnSC ? Ck2_BiasSC : UseSPI ? SPIOut[2] : Ck2_Ext;

assign SIn_Conf  =  EnSC ? SIn_ConfSC : UseSPI ? SPIOut[3] : SIn_Ext;
assign Ck1_Conf  =  EnSC ? Ck1_ConfSC : UseSPI ? SPIOut[4] : Ck1_Ext;
assign Ck2_Conf  =  EnSC ? Ck2_ConfSC : UseSPI ? SPIOut[5] : Ck2_Ext;

assign SIn_VDAC  =  EnSC ? SIn_VDACSC : UseSPI ? SPIOut[6] : SIn_Ext;
assign Ck1_VDAC  =  EnSC ? Ck1_VDACSC : UseSPI ? SPIOut[7] : Ck1_Ext;
assign Ck2_VDAC  =  EnSC ? Ck2_VDACSC : UseSPI ? SPIOut[8] : Ck2_Ext;

assign SIn_Col   =  EnSC ? SIn_ColSC : UseSPI ? SPIOut[9] : SIn_Ext;
assign Ck1_Col   =  EnSC ? Ck1_ColSC : UseSPI ? SPIOut[10] : Ck1_Ext;
assign Ck2_Col   =  EnSC ? Ck2_ColSC : UseSPI ? SPIOut[11] : Ck2_Ext;

assign SIn_Test  =  EnSC ? SIn_TestSC : UseSPI ? SPIOut[12] : SIn_Ext;
assign Ck1_Test  =  EnSC ? Ck1_TestSC : UseSPI ? SPIOut[13] : Ck1_Ext;
assign Ck2_Test  =  EnSC ? Ck2_TestSC : UseSPI ? SPIOut[14] : Ck2_Ext;

assign SIn_TDAC  =  EnSC ? SIn_TDACSC : UseSPI ? SPIOut[15] : SIn_Ext;
assign Ck1_TDAC  =  EnSC ? Ck1_TDACSC : UseSPI ? SPIOut[16] : Ck1_Ext;
assign Ck2_TDAC  =  EnSC ? Ck2_TDACSC : UseSPI ? SPIOut[17] : Ck2_Ext;


assign Load_Bias =  EnSC ? Load_BiasSC : UseSPI ? SPIOut[18] : Load_BiasExt;
assign Load_Conf =  EnSC ? Load_ConfSC : UseSPI ? SPIOut[19] : Load_ConfExt;
assign Load_VDAC =  EnSC ? Load_VDACSC : UseSPI ? SPIOut[20] : Load_VDACExt;
assign Load_Col  =  EnSC ? Load_ColSC  : UseSPI ? SPIOut[21] : Load_ColExt;
assign Load_Test =  EnSC ? Load_TestSC : UseSPI ? SPIOut[22] : Load_TestExt;
assign Load_TDAC =  EnSC ? Load_TDACSC : UseSPI ? SPIOut[23] : Load_TDACExt;

assign Readback  =  EnSC ? Readback_SC : UseSPI ? SPIOut[24] : Readback_Ext;
assign PCH 		 =  EnSC ? PCH_SC : UseSPI ? SPIOut[25] : PCH_Ext;
assign WR		 =  EnSC ? WR_SC : UseSPI ? SPIOut[26] : WR_Ext;
assign WrEnable		 =  EnSC ? WrEn_SC : UseSPI ? SPIOut[27] : WrEn_Ext;

assign Injection =  EnSC ? Injection_SC : UseSPI ? SPIOut[28] : Injection_Ext;

assign syncRes	 = EnSync_SC ? sync_reset_SC : sync_reset_Ext;		//dont use regsyncres when tsck is used

//sync reset

//Adding SlowControl state machine 

wire ResetBiasBlocks_SC;
assign ResetBiasBlocksB = ~ResetBiasBlocks_SC & ResetConfigB;//Ivan


SlowControlStatemachine SlowControlStatemachine_I(
	.ref_clock(ref_clock),		//I
	.slow_clock_div(slow_clock_div),
	.Serial_In(Serial_In),
	.Chip_Address(Chip_Address),
	.Bias_Back_In(Bias_Back_In),		//Looped back end of Bias register
	.Conf_Back_In(SOut_int),		//Looped back end of Bias register
	.VDAC_Back_In(VDAC_Back_In),		//Looped back end of Bias register
	.Col_Back_In(Col_Back_In),		//Looped back end of Bias register
	.Test_Back_In(Test_Back_In),		//Looped back end of Bias register
	.TDAC_Back_In(TDAC_Back_In),		//Looped back end of Bias register
	.CompIn(ADC_CompIn),
	.Reset(~ResetSCB),//Ivan
	.slow_clock(slow_clockSC),//O
	.SIn_Bias(SIn_BiasSC),
	.Ck1_Bias(Ck1_BiasSC),
	.Ck2_Bias(Ck2_BiasSC),
	.Load_Bias(Load_BiasSC),
	.SIn_Conf(SIn_ConfSC),
	.Ck1_Conf(Ck1_ConfSC),
	.Ck2_Conf(Ck2_ConfSC),
	.Load_Conf(Load_ConfSC),
	.SIn_VDAC(SIn_VDACSC),
	.Ck1_VDAC(Ck1_VDACSC),
	.Ck2_VDAC(Ck2_VDACSC),
	.Load_VDAC(Load_VDACSC),
	.SIn_Col(SIn_ColSC),
	.Ck1_Col(Ck1_ColSC),
	.Ck2_Col(Ck2_ColSC),
	.Load_Col(Load_ColSC),
	.SIn_Test(SIn_TestSC),
	.Ck1_Test(Ck1_TestSC),
	.Ck2_Test(Ck2_TestSC),
	.Load_Test(Load_TestSC),
	.SIn_TDAC(SIn_TDACSC),
	.Ck1_TDAC(Ck1_TDACSC),
	.Ck2_TDAC(Ck2_TDACSC),
	.Load_TDAC(Load_TDACSC),
	.Readback(Readback_SC),
	.Injection(Injection_SC),
	.ResetBiasBlocks(ResetBiasBlocks_SC),
	.PCH(PCH_SC),
	.WrEn(WrEn_SC),
	.WR(WR_SC),
	.ADC_VDAC(ADC_VDAC),
	.ADC_Mux(ADC_Mux),
	.DataOut(DataOut),			//Readback to Readout statemachine
	.Data_ready(Data_ready),
	.sync_reset(sync_reset_SC),
	.SOut(SOutSC)
);




MuPixTSGen MuPixTSGen_I(
	.fastclk(clk_ts_in),//Ivan changed from 800p clkOut_4n try clk_8n was clkIn_4n
	.res_n(RO_res_n),
    .syncRes(syncRes),
  	.ckdivend(Ickdivend),
  	.ckdivend2(Ickdivend2),
	.tsphase(Itsphase), 
	.TSToDet(TSToDet),
	.TSToDet2(TSToDet2),	
	.BinCounterOut(BinCounter)
	);
	
	
wire [31:0] DataOut2SPI_A;//SPI
wire [31:0] DataOut2SPI_B;//SPI
wire [31:0] DataOut2SPI_C;//SPI

wire takeme_A;//SPI
wire takeme_B;//SPI
wire takeme_C;//SPI

	

MuPixReadout MuPixReadout_A(
      .clk(clk_8n),
      .res_n(RO_res_n),	 
      .Fixedpattern(8'hAA),
	.RowAddFromDet(RowAddFromDet_PartA_int),
	.ColAddFromDet(ColAddFromDet_PartA_int),
	.TSFromDet(TSFromDet_PartA_int),
	.TSToDet(TSToDet),
	.BinCounter(BinCounter),
	.PriFromDet(PriFromDet_PartA),	 
	 .LdCol(LdCol_PartA),
	 .RdCol(RdCol_PartA),
	 .LdPix(LdPix_PartA),
	 .PullDN(PullDN_PartA),
	 .timerend(Itimerend),//divider for Readout
	 .slowdownend(Islowdownend),//wait in ldpix if empty
	 .maxcycend(Imaxcycend),//max read cyc
	 .resetckdivend(Iresetckdivend), //divider for reset (sync) clk
	  .sendcounter(Isendcounter), // send only the timestamp counter 
	 .DataOut(DataOut_A),//important data valid only 4 x 4ns
	 .CommaOut(CommaOut_A),
	 .SC_DataIn(RegDataOut),
	 .DataOut2SPI(DataOut2SPI_A),//SPI
	 .CSB(CSB),//SPI
	 .takeme(takeme_A),//SPI
	 .UseSPI(UseSPI & UseSPIRO),//SPI
	 .SC_Data_ready(RegData_ready),
	 .datavalid(datavalid_A),
	 .dataoff(dataoff_A),
	 .slowdownLdColEnd(IslowdownLdColEnd),
	 .countsheeps(countsheeps)
);

MuPixReadout MuPixReadout_B(
      .clk(clk_8n),
      .res_n(RO_res_n),
      .Fixedpattern(8'hBB),
	.RowAddFromDet(RowAddFromDet_PartB_int),
	.ColAddFromDet(ColAddFromDet_PartB_int),
	.TSFromDet(TSFromDet_PartB_int),
	.TSToDet(TSToDet),
	.BinCounter(BinCounter),
	.PriFromDet(PriFromDet_PartB),	 
	 .LdCol(LdCol_PartB),
	 .RdCol(RdCol_PartB),
	 .LdPix(LdPix_PartB),
	 .PullDN(PullDN_PartB),
	 .timerend(Itimerend),//divider for Readout
	 .slowdownend(Islowdownend),//wait in ldpix if empty
	 .maxcycend(Imaxcycend),//max read cyc
	 .resetckdivend(Iresetckdivend), //divider for reset (sync) clk
	  .sendcounter(Isendcounter), // send only the timestamp counter 
	 .DataOut(DataOut_B),//important data valid only 4 x 4ns
	 .CommaOut(CommaOut_B),
	 .SC_DataIn(RegDataOut),
	 .DataOut2SPI(DataOut2SPI_B),//SPI
	 .CSB(CSB),//SPI
	 .takeme(takeme_B),//SPI
	 .UseSPI(UseSPI & UseSPIRO),//SPI
	 .SC_Data_ready(RegData_ready),
	 .datavalid(datavalid_B),
	 .dataoff(dataoff_B),
	 .slowdownLdColEnd(IslowdownLdColEnd),
	 .countsheeps(countsheeps)
);

MuPixReadout MuPixReadout_C(
      .clk(clk_8n),
      .res_n(RO_res_n),
      .Fixedpattern(8'hCC),
	.RowAddFromDet(RowAddFromDet_PartC_int),
	.ColAddFromDet(ColAddFromDet_PartC_int),
	.TSFromDet(TSFromDet_PartC_int),
	.TSToDet(TSToDet),
	.BinCounter(BinCounter),
	.PriFromDet(PriFromDet_PartC),	 
	 .LdCol(LdCol_PartC),
	 .RdCol(RdCol_PartC),
	 .LdPix(LdPix_PartC),
	 .PullDN(PullDN_PartC),
	 .timerend(Itimerend),//divider for Readout
	 .slowdownend(Islowdownend),//wait in ldpix if empty
	 .maxcycend(Imaxcycend),//max read cyc
	 .resetckdivend(Iresetckdivend), //divider for reset (sync) clk
	  .sendcounter(Isendcounter), // send only the timestamp counter 
	 .DataOut(DataOut_C),//important data valid only 4 x 4ns
	 .CommaOut(CommaOut_C),
	 .SC_DataIn(RegDataOut),
	 .DataOut2SPI(DataOut2SPI_C),//SPI
	 .CSB(CSB),//SPI
	 .takeme(takeme_C),//SPI
	 .UseSPI(UseSPI & UseSPIRO),//SPI
	 .SC_Data_ready(RegData_ready),
	 .datavalid(datavalid_C),
	 .dataoff(dataoff_C),
	 .slowdownLdColEnd(IslowdownLdColEnd),
	 .countsheeps(countsheeps)
);


SerializerTop SerializerTop_A(
    .linksel(Ilinksel),
    .DataIn_A(DataOut_A),  
    .CommaIn_A(CommaOut_A),
    .dataoff_A(dataoff_A),
	.datavalid_A(datavalid_A),
    .DataIn_B(DataOut_B),  
    .CommaIn_B(CommaOut_B),
    .dataoff_B(dataoff_B),
	.datavalid_B(datavalid_B),	
    .DataIn_C(DataOut_C),  
    .CommaIn_C(CommaOut_C),    
    .dataoff_C(dataoff_C),
	.datavalid_C(datavalid_C),
    .clkIn_800p(clk_800p), 
    .Aur_res_n(Aur_res_n),
    .Ser_res_n(Ser_res_n),  
    .clkOut_8n(clk_8n), 
    .BitDataOut_A(d_out_A),
    .BitDataOut_B(d_out_B),
    .BitDataOut_C(d_out_C),
    .BitDataOut_D(d_out_D),   
    .Cnt4(Cnt4),
    .Cnt5(Cnt5),
    .clkOut_4n(clkOut_4n),
    .clkIn_4n(clkIn_4n)
);



reg firstbit;
reg [127:0] SPIReg;


always @( posedge SCK or posedge CSB) begin

if(CSB) begin


firstbit <=1;//first bit 

end
else begin


		firstbit <= 0;
		if (firstbit) begin//if takeme is hi, in the first clk spi register is parallely loeaded
 			
 			if(takeme_A) SPIReg[63:32] <= DataOut2SPI_A;
			else SPIReg[63:32] <= 32'hFFFF;
			
			if(takeme_B) SPIReg[95:64] <= DataOut2SPI_B;
			else SPIReg[95:64] <= 32'hFFFF;
			
			if(takeme_C) SPIReg[127:96] <= DataOut2SPI_C;
			else SPIReg[127:96] <= 32'hFFFF;
	
		end
		else begin

			SPIReg[127:0] <= {SPIReg[126:0], MOSI};

		end


end//res
end//always

assign SPIOut = CSB ? SPIReg[31:0] : SPIOut;//transparent when no shift
assign MISO = SPIReg[127];



endmodule
