module Buffer (TSFromDet_PartA_int,TSFromDet_PartA,TSFromDet_PartB_int,TSFromDet_PartB,TSFromDet_PartC_int,TSFromDet_PartC,RowAddFromDet_PartA_int,RowAddFromDet_PartA,ColAddFromDet_PartA_int,ColAddFromDet_PartA,RowAddFromDet_PartB_int,RowAddFromDet_PartB,
ColAddFromDet_PartB_int,ColAddFromDet_PartB,RowAddFromDet_PartC_int,RowAddFromDet_PartC,ColAddFromDet_PartC_int,ColAddFromDet_PartC,RdCol_PartA,RdCol_PartB,RdCol_PartC);

//TSToDet,TSToDet_int,NegTSToDet,NegTSToDet_int,TSToDet2,TSToDet2_int,TSToDet3,TSToDet3_int,
//TSFromDet,TSFromDet_int,TS2FromDet,TS2FromDet_int,TS3FromDet_int,TS3FromDet,
//RdCol_int,RdCol,RdColB,LdCol_int,LdCol,LdPix_int,LdPix,PullDN_int,PullDN,
//ColAddFromDet_int,ColAddFromDet,RowAddFromDet_int,RowAddFromDet, SOut, SOut_int);




input RdCol_PartA;
input RdCol_PartB;
input RdCol_PartC;



//PartA
output [6:0] ColAddFromDet_PartA_int;
input [6:0] ColAddFromDet_PartA;

output [8:0] RowAddFromDet_PartA_int;
input [8:0] RowAddFromDet_PartA;

//PartB
output [6:0] ColAddFromDet_PartB_int;
input [6:0] ColAddFromDet_PartB;

output [8:0] RowAddFromDet_PartB_int;
input [8:0] RowAddFromDet_PartB;

//PartC
output [6:0] ColAddFromDet_PartC_int;
input [6:0] ColAddFromDet_PartC;

output [8:0] RowAddFromDet_PartC_int;
input [8:0] RowAddFromDet_PartC;


input [15:0]  TSFromDet_PartA; //20->16
output [15:0]  TSFromDet_PartA_int;

input [15:0]  TSFromDet_PartB; //20->16 //new
output [15:0]  TSFromDet_PartB_int;

input [15:0]  TSFromDet_PartC; //20->16 //new
output [15:0]  TSFromDet_PartC_int;



wire [15:0] net01;  //TSFromDet_PartA Q
wire [15:0] net02;  //TSFromDet_PartA QN
wire [15:0] net03;  //TSFromDet_PartB Q
wire [15:0] net04;  //TSFromDet_PartB QN
wire [15:0] net05;  //TSFromDet_PartC Q
wire [15:0] net06;  //TSFromDet_PartC QN

wire [6:0] ColAdd_PartA_mid;
wire [8:0] RowAdd_PartA_mid;
wire RdColB_PartA;

wire [6:0] ColAdd_PartB_mid;
wire [8:0] RowAdd_PartB_mid;
wire RdColB_PartB;

wire [6:0] ColAdd_PartC_mid;
wire [8:0] RowAdd_PartC_mid;
wire RdColB_PartC;





//PartA
LHX1_HV
I11_0 ( .D( ColAddFromDet_PartA[0] ), .E( RdCol_PartA ), .Q( ColAdd_PartA_mid[0] ) ),
I11_1 ( .D( ColAddFromDet_PartA[1] ), .E( RdCol_PartA ), .Q( ColAdd_PartA_mid[1] ) ),
I11_2 ( .D( ColAddFromDet_PartA[2] ), .E( RdCol_PartA ), .Q( ColAdd_PartA_mid[2] ) ),
I11_3 ( .D( ColAddFromDet_PartA[3] ), .E( RdCol_PartA ), .Q( ColAdd_PartA_mid[3] ) ),
I11_4 ( .D( ColAddFromDet_PartA[4] ), .E( RdCol_PartA ), .Q( ColAdd_PartA_mid[4] ) ),
I11_5 ( .D( ColAddFromDet_PartA[5] ), .E( RdCol_PartA ), .Q( ColAdd_PartA_mid[5] ) ),
I11_6 ( .D( ColAddFromDet_PartA[6] ), .E( RdCol_PartA ), .Q( ColAdd_PartA_mid[6] ) );

BUFX24_HV
I12_0 ( .A( ColAdd_PartA_mid[0] ), .Q( ColAddFromDet_PartA_int[0] ) ),
I12_1 ( .A( ColAdd_PartA_mid[1] ), .Q( ColAddFromDet_PartA_int[1] ) ),
I12_2 ( .A( ColAdd_PartA_mid[2] ), .Q( ColAddFromDet_PartA_int[2] ) ),
I12_3 ( .A( ColAdd_PartA_mid[3] ), .Q( ColAddFromDet_PartA_int[3] ) ),
I12_4 ( .A( ColAdd_PartA_mid[4] ), .Q( ColAddFromDet_PartA_int[4] ) ),
I12_5 ( .A( ColAdd_PartA_mid[5] ), .Q( ColAddFromDet_PartA_int[5] ) ),
I12_6 ( .A( ColAdd_PartA_mid[6] ), .Q( ColAddFromDet_PartA_int[6] ) );

LHX1_HV
I13_0 ( .D( RowAddFromDet_PartA[0] ), .E( RdCol_PartA ), .Q( RowAdd_PartA_mid[0] ) ),
I13_1 ( .D( RowAddFromDet_PartA[1] ), .E( RdCol_PartA ), .Q( RowAdd_PartA_mid[1] ) ),
I13_2 ( .D( RowAddFromDet_PartA[2] ), .E( RdCol_PartA ), .Q( RowAdd_PartA_mid[2] ) ),
I13_3 ( .D( RowAddFromDet_PartA[3] ), .E( RdCol_PartA ), .Q( RowAdd_PartA_mid[3] ) ),
I13_4 ( .D( RowAddFromDet_PartA[4] ), .E( RdCol_PartA ), .Q( RowAdd_PartA_mid[4] ) ),
I13_5 ( .D( RowAddFromDet_PartA[5] ), .E( RdCol_PartA ), .Q( RowAdd_PartA_mid[5] ) ),
I13_6 ( .D( RowAddFromDet_PartA[6] ), .E( RdCol_PartA ), .Q( RowAdd_PartA_mid[6] ) ),
I13_7 ( .D( RowAddFromDet_PartA[7] ), .E( RdCol_PartA ), .Q( RowAdd_PartA_mid[7] ) ),
I13_8 ( .D( RowAddFromDet_PartA[8] ), .E( RdCol_PartA ), .Q( RowAdd_PartA_mid[8] ) );

BUFX24_HV
I14_0 ( .A( RowAdd_PartA_mid[0] ), .Q( RowAddFromDet_PartA_int[0] ) ),
I14_1 ( .A( RowAdd_PartA_mid[1] ), .Q( RowAddFromDet_PartA_int[1] ) ),
I14_2 ( .A( RowAdd_PartA_mid[2] ), .Q( RowAddFromDet_PartA_int[2] ) ),
I14_3 ( .A( RowAdd_PartA_mid[3] ), .Q( RowAddFromDet_PartA_int[3] ) ),
I14_4 ( .A( RowAdd_PartA_mid[4] ), .Q( RowAddFromDet_PartA_int[4] ) ),
I14_5 ( .A( RowAdd_PartA_mid[5] ), .Q( RowAddFromDet_PartA_int[5] ) ),
I14_6 ( .A( RowAdd_PartA_mid[6] ), .Q( RowAddFromDet_PartA_int[6] ) ),
I14_7 ( .A( RowAdd_PartA_mid[7] ), .Q( RowAddFromDet_PartA_int[7] ) ),
I14_8 ( .A( RowAdd_PartA_mid[8] ), .Q( RowAddFromDet_PartA_int[8] ) );

//PartB
LHX1_HV
I31_0 ( .D( ColAddFromDet_PartB[0] ), .E( RdCol_PartB ), .Q( ColAdd_PartB_mid[0] ) ),
I31_1 ( .D( ColAddFromDet_PartB[1] ), .E( RdCol_PartB ), .Q( ColAdd_PartB_mid[1] ) ),
I31_2 ( .D( ColAddFromDet_PartB[2] ), .E( RdCol_PartB ), .Q( ColAdd_PartB_mid[2] ) ),
I31_3 ( .D( ColAddFromDet_PartB[3] ), .E( RdCol_PartB ), .Q( ColAdd_PartB_mid[3] ) ),
I31_4 ( .D( ColAddFromDet_PartB[4] ), .E( RdCol_PartB ), .Q( ColAdd_PartB_mid[4] ) ),
I31_5 ( .D( ColAddFromDet_PartB[5] ), .E( RdCol_PartB ), .Q( ColAdd_PartB_mid[5] ) ),
I31_6 ( .D( ColAddFromDet_PartB[6] ), .E( RdCol_PartB ), .Q( ColAdd_PartB_mid[6] ) );

BUFX24_HV
I32_0 ( .A( ColAdd_PartB_mid[0] ), .Q( ColAddFromDet_PartB_int[0] ) ),
I32_1 ( .A( ColAdd_PartB_mid[1] ), .Q( ColAddFromDet_PartB_int[1] ) ),
I32_2 ( .A( ColAdd_PartB_mid[2] ), .Q( ColAddFromDet_PartB_int[2] ) ),
I32_3 ( .A( ColAdd_PartB_mid[3] ), .Q( ColAddFromDet_PartB_int[3] ) ),
I32_4 ( .A( ColAdd_PartB_mid[4] ), .Q( ColAddFromDet_PartB_int[4] ) ),
I32_5 ( .A( ColAdd_PartB_mid[5] ), .Q( ColAddFromDet_PartB_int[5] ) ),
I32_6 ( .A( ColAdd_PartB_mid[6] ), .Q( ColAddFromDet_PartB_int[6] ) );

LHX1_HV
I33_0 ( .D( RowAddFromDet_PartB[0] ), .E( RdCol_PartB ), .Q( RowAdd_PartB_mid[0] ) ),
I33_1 ( .D( RowAddFromDet_PartB[1] ), .E( RdCol_PartB ), .Q( RowAdd_PartB_mid[1] ) ),
I33_2 ( .D( RowAddFromDet_PartB[2] ), .E( RdCol_PartB ), .Q( RowAdd_PartB_mid[2] ) ),
I33_3 ( .D( RowAddFromDet_PartB[3] ), .E( RdCol_PartB ), .Q( RowAdd_PartB_mid[3] ) ),
I33_4 ( .D( RowAddFromDet_PartB[4] ), .E( RdCol_PartB ), .Q( RowAdd_PartB_mid[4] ) ),
I33_5 ( .D( RowAddFromDet_PartB[5] ), .E( RdCol_PartB ), .Q( RowAdd_PartB_mid[5] ) ),
I33_6 ( .D( RowAddFromDet_PartB[6] ), .E( RdCol_PartB ), .Q( RowAdd_PartB_mid[6] ) ),
I33_7 ( .D( RowAddFromDet_PartB[7] ), .E( RdCol_PartB ), .Q( RowAdd_PartB_mid[7] ) ),
I33_8 ( .D( RowAddFromDet_PartB[8] ), .E( RdCol_PartB ), .Q( RowAdd_PartB_mid[8] ) );

BUFX24_HV
I34_0 ( .A( RowAdd_PartB_mid[0] ), .Q( RowAddFromDet_PartB_int[0] ) ),
I34_1 ( .A( RowAdd_PartB_mid[1] ), .Q( RowAddFromDet_PartB_int[1] ) ),
I34_2 ( .A( RowAdd_PartB_mid[2] ), .Q( RowAddFromDet_PartB_int[2] ) ),
I34_3 ( .A( RowAdd_PartB_mid[3] ), .Q( RowAddFromDet_PartB_int[3] ) ),
I34_4 ( .A( RowAdd_PartB_mid[4] ), .Q( RowAddFromDet_PartB_int[4] ) ),
I34_5 ( .A( RowAdd_PartB_mid[5] ), .Q( RowAddFromDet_PartB_int[5] ) ),
I34_6 ( .A( RowAdd_PartB_mid[6] ), .Q( RowAddFromDet_PartB_int[6] ) ),
I34_7 ( .A( RowAdd_PartB_mid[7] ), .Q( RowAddFromDet_PartB_int[7] ) ),
I34_8 ( .A( RowAdd_PartB_mid[8] ), .Q( RowAddFromDet_PartB_int[8] ) );

//PartC
LHX1_HV
I35_0 ( .D( ColAddFromDet_PartC[0] ), .E( RdCol_PartC ), .Q( ColAdd_PartC_mid[0] ) ),
I35_1 ( .D( ColAddFromDet_PartC[1] ), .E( RdCol_PartC ), .Q( ColAdd_PartC_mid[1] ) ),
I35_2 ( .D( ColAddFromDet_PartC[2] ), .E( RdCol_PartC ), .Q( ColAdd_PartC_mid[2] ) ),
I35_3 ( .D( ColAddFromDet_PartC[3] ), .E( RdCol_PartC ), .Q( ColAdd_PartC_mid[3] ) ),
I35_4 ( .D( ColAddFromDet_PartC[4] ), .E( RdCol_PartC ), .Q( ColAdd_PartC_mid[4] ) ),
I35_5 ( .D( ColAddFromDet_PartC[5] ), .E( RdCol_PartC ), .Q( ColAdd_PartC_mid[5] ) ),
I35_6 ( .D( ColAddFromDet_PartC[6] ), .E( RdCol_PartC ), .Q( ColAdd_PartC_mid[6] ) );

BUFX24_HV
I36_0 ( .A( ColAdd_PartC_mid[0] ), .Q( ColAddFromDet_PartC_int[0] ) ),
I36_1 ( .A( ColAdd_PartC_mid[1] ), .Q( ColAddFromDet_PartC_int[1] ) ),
I36_2 ( .A( ColAdd_PartC_mid[2] ), .Q( ColAddFromDet_PartC_int[2] ) ),
I36_3 ( .A( ColAdd_PartC_mid[3] ), .Q( ColAddFromDet_PartC_int[3] ) ),
I36_4 ( .A( ColAdd_PartC_mid[4] ), .Q( ColAddFromDet_PartC_int[4] ) ),
I36_5 ( .A( ColAdd_PartC_mid[5] ), .Q( ColAddFromDet_PartC_int[5] ) ),
I36_6 ( .A( ColAdd_PartC_mid[6] ), .Q( ColAddFromDet_PartC_int[6] ) );

LHX1_HV
I37_0 ( .D( RowAddFromDet_PartC[0] ), .E( RdCol_PartC ), .Q( RowAdd_PartC_mid[0] ) ),
I37_1 ( .D( RowAddFromDet_PartC[1] ), .E( RdCol_PartC ), .Q( RowAdd_PartC_mid[1] ) ),
I37_2 ( .D( RowAddFromDet_PartC[2] ), .E( RdCol_PartC ), .Q( RowAdd_PartC_mid[2] ) ),
I37_3 ( .D( RowAddFromDet_PartC[3] ), .E( RdCol_PartC ), .Q( RowAdd_PartC_mid[3] ) ),
I37_4 ( .D( RowAddFromDet_PartC[4] ), .E( RdCol_PartC ), .Q( RowAdd_PartC_mid[4] ) ),
I37_5 ( .D( RowAddFromDet_PartC[5] ), .E( RdCol_PartC ), .Q( RowAdd_PartC_mid[5] ) ),
I37_6 ( .D( RowAddFromDet_PartC[6] ), .E( RdCol_PartC ), .Q( RowAdd_PartC_mid[6] ) ),
I37_7 ( .D( RowAddFromDet_PartC[7] ), .E( RdCol_PartC ), .Q( RowAdd_PartC_mid[7] ) ),
I37_8 ( .D( RowAddFromDet_PartC[8] ), .E( RdCol_PartC ), .Q( RowAdd_PartC_mid[8] ) );

BUFX24_HV
I38_0 ( .A( RowAdd_PartC_mid[0] ), .Q( RowAddFromDet_PartC_int[0] ) ),
I38_1 ( .A( RowAdd_PartC_mid[1] ), .Q( RowAddFromDet_PartC_int[1] ) ),
I38_2 ( .A( RowAdd_PartC_mid[2] ), .Q( RowAddFromDet_PartC_int[2] ) ),
I38_3 ( .A( RowAdd_PartC_mid[3] ), .Q( RowAddFromDet_PartC_int[3] ) ),
I38_4 ( .A( RowAdd_PartC_mid[4] ), .Q( RowAddFromDet_PartC_int[4] ) ),
I38_5 ( .A( RowAdd_PartC_mid[5] ), .Q( RowAddFromDet_PartC_int[5] ) ),
I38_6 ( .A( RowAdd_PartC_mid[6] ), .Q( RowAddFromDet_PartC_int[6] ) ),
I38_7 ( .A( RowAdd_PartC_mid[7] ), .Q( RowAddFromDet_PartC_int[7] ) ),
I38_8 ( .A( RowAdd_PartC_mid[8] ), .Q( RowAddFromDet_PartC_int[8] ) );



// PartA
LHX1_HV
  I0_0 ( .QN( net02[0] ), .D( TSFromDet_PartA[0] ), .E( RdCol_PartA ), .Q( net01[0] ) ),
  I0_1 ( .QN( net02[1] ), .D( TSFromDet_PartA[1] ), .E( RdCol_PartA ), .Q( net01[1] ) ),
  I0_2 ( .QN( net02[2] ), .D( TSFromDet_PartA[2] ), .E( RdCol_PartA ), .Q( net01[2] ) ),
  I0_3 ( .QN( net02[3] ), .D( TSFromDet_PartA[3] ), .E( RdCol_PartA ), .Q( net01[3] ) ),
  I0_4 ( .QN( net02[4] ), .D( TSFromDet_PartA[4] ), .E( RdCol_PartA ), .Q( net01[4] ) ),
  I0_5 ( .QN( net02[5] ), .D( TSFromDet_PartA[5] ), .E( RdCol_PartA ), .Q( net01[5] ) ),
  I0_6 ( .QN( net02[6] ), .D( TSFromDet_PartA[6] ), .E( RdCol_PartA ), .Q( net01[6] ) ),
  I0_7 ( .QN( net02[7] ), .D( TSFromDet_PartA[7] ), .E( RdCol_PartA ), .Q( net01[7] ) ),
  I0_8 ( .QN( net02[8] ), .D( TSFromDet_PartA[8] ), .E( RdCol_PartA ), .Q( net01[8] ) ),
  I0_9 ( .QN( net02[9] ), .D( TSFromDet_PartA[9] ), .E( RdCol_PartA ), .Q( net01[9] ) ),
  I0_10 ( .QN( net02[10] ), .D( TSFromDet_PartA[10] ), .E( RdCol_PartA ), .Q( net01[10] ) ),
  I0_11 ( .QN( net02[11] ), .D( TSFromDet_PartA[11] ), .E( RdCol_PartA ), .Q( net01[11] ) ),
  I0_12 ( .QN( net02[12] ), .D( TSFromDet_PartA[12] ), .E( RdCol_PartA ), .Q( net01[12] ) ),
  I0_13 ( .QN( net02[13] ), .D( TSFromDet_PartA[13] ), .E( RdCol_PartA ), .Q( net01[13] ) ),
  I0_14 ( .QN( net02[14] ), .D( TSFromDet_PartA[14] ), .E( RdCol_PartA ), .Q( net01[14] ) ),
  I0_15 ( .QN( net02[15] ), .D( TSFromDet_PartA[15] ), .E( RdCol_PartA ), .Q( net01[15] ) );


  BUFX24_HV
  I1_0 ( .A( net01[0] ), .Q( TSFromDet_PartA_int[0] ) ),
  I1_1 ( .A( net01[1] ), .Q( TSFromDet_PartA_int[1] ) ),
  I1_2 ( .A( net01[2] ), .Q( TSFromDet_PartA_int[2] ) ),
  I1_3 ( .A( net01[3] ), .Q( TSFromDet_PartA_int[3] ) ),
  I1_4 ( .A( net01[4] ), .Q( TSFromDet_PartA_int[4] ) ),
  I1_5 ( .A( net01[5] ), .Q( TSFromDet_PartA_int[5] ) ),
  I1_6 ( .A( net01[6] ), .Q( TSFromDet_PartA_int[6] ) ),
  I1_7 ( .A( net01[7] ), .Q( TSFromDet_PartA_int[7] ) ),
  I1_8 ( .A( net01[8] ), .Q( TSFromDet_PartA_int[8] ) ),
  I1_9 ( .A( net01[9] ), .Q( TSFromDet_PartA_int[9] ) ),
  I1_10 ( .A( net01[10] ), .Q( TSFromDet_PartA_int[10] ) ),
  I1_11 ( .A( net01[11] ), .Q( TSFromDet_PartA_int[11] ) ),
  I1_12 ( .A( net01[12] ), .Q( TSFromDet_PartA_int[12] ) ),
  I1_13 ( .A( net01[13] ), .Q( TSFromDet_PartA_int[13] ) ),
  I1_14 ( .A( net01[14] ), .Q( TSFromDet_PartA_int[14] ) ),
  I1_15 ( .A( net01[15] ), .Q( TSFromDet_PartA_int[15] ) );

// PartB
LHX1_HV
  I39_0 ( .QN( net04[0] ), .D( TSFromDet_PartB[0] ), .E( RdCol_PartB ), .Q( net03[0] ) ),
  I39_1 ( .QN( net04[1] ), .D( TSFromDet_PartB[1] ), .E( RdCol_PartB ), .Q( net03[1] ) ),
  I39_2 ( .QN( net04[2] ), .D( TSFromDet_PartB[2] ), .E( RdCol_PartB ), .Q( net03[2] ) ),
  I39_3 ( .QN( net04[3] ), .D( TSFromDet_PartB[3] ), .E( RdCol_PartB ), .Q( net03[3] ) ),
  I39_4 ( .QN( net04[4] ), .D( TSFromDet_PartB[4] ), .E( RdCol_PartB ), .Q( net03[4] ) ),
  I39_5 ( .QN( net04[5] ), .D( TSFromDet_PartB[5] ), .E( RdCol_PartB ), .Q( net03[5] ) ),
  I39_6 ( .QN( net04[6] ), .D( TSFromDet_PartB[6] ), .E( RdCol_PartB ), .Q( net03[6] ) ),
  I39_7 ( .QN( net04[7] ), .D( TSFromDet_PartB[7] ), .E( RdCol_PartB ), .Q( net03[7] ) ),
  I39_8 ( .QN( net04[8] ), .D( TSFromDet_PartB[8] ), .E( RdCol_PartB ), .Q( net03[8] ) ),
  I39_9 ( .QN( net04[9] ), .D( TSFromDet_PartB[9] ), .E( RdCol_PartB ), .Q( net03[9] ) ),
  I39_10 ( .QN( net04[10] ), .D( TSFromDet_PartB[10] ), .E( RdCol_PartB ), .Q( net03[10] ) ),
  I39_11 ( .QN( net04[11] ), .D( TSFromDet_PartB[11] ), .E( RdCol_PartB ), .Q( net03[11] ) ),
  I39_12 ( .QN( net04[12] ), .D( TSFromDet_PartB[12] ), .E( RdCol_PartB ), .Q( net03[12] ) ),
  I39_13 ( .QN( net04[13] ), .D( TSFromDet_PartB[13] ), .E( RdCol_PartB ), .Q( net03[13] ) ),
  I39_14 ( .QN( net04[14] ), .D( TSFromDet_PartB[14] ), .E( RdCol_PartB ), .Q( net03[14] ) ),
  I39_15 ( .QN( net04[15] ), .D( TSFromDet_PartB[15] ), .E( RdCol_PartB ), .Q( net03[15] ) );


  BUFX24_HV
  I40_0 ( .A( net03[0] ), .Q( TSFromDet_PartB_int[0] ) ),
  I40_1 ( .A( net03[1] ), .Q( TSFromDet_PartB_int[1] ) ),
  I40_2 ( .A( net03[2] ), .Q( TSFromDet_PartB_int[2] ) ),
  I40_3 ( .A( net03[3] ), .Q( TSFromDet_PartB_int[3] ) ),
  I40_4 ( .A( net03[4] ), .Q( TSFromDet_PartB_int[4] ) ),
  I40_5 ( .A( net03[5] ), .Q( TSFromDet_PartB_int[5] ) ),
  I40_6 ( .A( net03[6] ), .Q( TSFromDet_PartB_int[6] ) ),
  I40_7 ( .A( net03[7] ), .Q( TSFromDet_PartB_int[7] ) ),
  I40_8 ( .A( net03[8] ), .Q( TSFromDet_PartB_int[8] ) ),
  I40_9 ( .A( net03[9] ), .Q( TSFromDet_PartB_int[9] ) ),
  I40_10 ( .A( net03[10] ), .Q( TSFromDet_PartB_int[10] ) ),
  I40_11 ( .A( net03[11] ), .Q( TSFromDet_PartB_int[11] ) ),
  I40_12 ( .A( net03[12] ), .Q( TSFromDet_PartB_int[12] ) ),
  I40_13 ( .A( net03[13] ), .Q( TSFromDet_PartB_int[13] ) ),
  I40_14 ( .A( net03[14] ), .Q( TSFromDet_PartB_int[14] ) ),
  I40_15 ( .A( net03[15] ), .Q( TSFromDet_PartB_int[15] ) );

// PartC
LHX1_HV
  I41_0 ( .QN( net06[0] ), .D( TSFromDet_PartC[0] ), .E( RdCol_PartC ), .Q( net05[0] ) ),
  I41_1 ( .QN( net06[1] ), .D( TSFromDet_PartC[1] ), .E( RdCol_PartC ), .Q( net05[1] ) ),
  I41_2 ( .QN( net06[2] ), .D( TSFromDet_PartC[2] ), .E( RdCol_PartC ), .Q( net05[2] ) ),
  I41_3 ( .QN( net06[3] ), .D( TSFromDet_PartC[3] ), .E( RdCol_PartC ), .Q( net05[3] ) ),
  I41_4 ( .QN( net06[4] ), .D( TSFromDet_PartC[4] ), .E( RdCol_PartC ), .Q( net05[4] ) ),
  I41_5 ( .QN( net06[5] ), .D( TSFromDet_PartC[5] ), .E( RdCol_PartC ), .Q( net05[5] ) ),
  I41_6 ( .QN( net06[6] ), .D( TSFromDet_PartC[6] ), .E( RdCol_PartC ), .Q( net05[6] ) ),
  I41_7 ( .QN( net06[7] ), .D( TSFromDet_PartC[7] ), .E( RdCol_PartC ), .Q( net05[7] ) ),
  I41_8 ( .QN( net06[8] ), .D( TSFromDet_PartC[8] ), .E( RdCol_PartC ), .Q( net05[8] ) ),
  I41_9 ( .QN( net06[9] ), .D( TSFromDet_PartC[9] ), .E( RdCol_PartC ), .Q( net05[9] ) ),
  I41_10 ( .QN( net06[10] ), .D( TSFromDet_PartC[10] ), .E( RdCol_PartC ), .Q( net05[10] ) ),
  I41_11 ( .QN( net06[11] ), .D( TSFromDet_PartC[11] ), .E( RdCol_PartC ), .Q( net05[11] ) ),
  I41_12 ( .QN( net06[12] ), .D( TSFromDet_PartC[12] ), .E( RdCol_PartC ), .Q( net05[12] ) ),
  I41_13 ( .QN( net06[13] ), .D( TSFromDet_PartC[13] ), .E( RdCol_PartC ), .Q( net05[13] ) ),
  I41_14 ( .QN( net06[14] ), .D( TSFromDet_PartC[14] ), .E( RdCol_PartC ), .Q( net05[14] ) ),
  I41_15 ( .QN( net06[15] ), .D( TSFromDet_PartC[15] ), .E( RdCol_PartC ), .Q( net05[15] ) );


  BUFX24_HV
  I42_0 ( .A( net05[0] ), .Q( TSFromDet_PartC_int[0] ) ),
  I42_1 ( .A( net05[1] ), .Q( TSFromDet_PartC_int[1] ) ),
  I42_2 ( .A( net05[2] ), .Q( TSFromDet_PartC_int[2] ) ),
  I42_3 ( .A( net05[3] ), .Q( TSFromDet_PartC_int[3] ) ),
  I42_4 ( .A( net05[4] ), .Q( TSFromDet_PartC_int[4] ) ),
  I42_5 ( .A( net05[5] ), .Q( TSFromDet_PartC_int[5] ) ),
  I42_6 ( .A( net05[6] ), .Q( TSFromDet_PartC_int[6] ) ),
  I42_7 ( .A( net05[7] ), .Q( TSFromDet_PartC_int[7] ) ),
  I42_8 ( .A( net05[8] ), .Q( TSFromDet_PartC_int[8] ) ),
  I42_9 ( .A( net05[9] ), .Q( TSFromDet_PartC_int[9] ) ),
  I42_10 ( .A( net05[10] ), .Q( TSFromDet_PartC_int[10] ) ),
  I42_11 ( .A( net05[11] ), .Q( TSFromDet_PartC_int[11] ) ),
  I42_12 ( .A( net05[12] ), .Q( TSFromDet_PartC_int[12] ) ),
  I42_13 ( .A( net05[13] ), .Q( TSFromDet_PartC_int[13] ) ),
  I42_14 ( .A( net05[14] ), .Q( TSFromDet_PartC_int[14] ) ),
  I42_15 ( .A( net05[15] ), .Q( TSFromDet_PartC_int[15] ) );





endmodule
