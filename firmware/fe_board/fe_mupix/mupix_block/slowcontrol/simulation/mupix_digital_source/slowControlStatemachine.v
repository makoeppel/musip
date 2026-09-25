
	`timescale 1ns/1ps

	module SlowControlStatemachine (
	//input
	input wire ref_clock,
	input wire [3:0] slow_clock_div,
	input wire Serial_In,
	input wire [3:0] Chip_Address,
	input wire Bias_Back_In,
	input wire Conf_Back_In,
	input wire VDAC_Back_In,
	input wire Col_Back_In,
	input wire Test_Back_In,
	input wire TDAC_Back_In,
	input wire Reset,
	input wire CompIn,		//ADC Komparator
	//output
	output wire slow_clock,
	output reg SIn_Bias,
	output wire Ck1_Bias,
	output wire Ck2_Bias,
	output wire Load_Bias,
	output reg SIn_Conf,
	output wire Ck1_Conf,
	output wire Ck2_Conf,
	output wire Load_Conf,
	output reg SIn_VDAC,
	output wire Ck1_VDAC,
	output wire Ck2_VDAC,
	output wire Load_VDAC,
	output reg SIn_Col,
	output wire Ck1_Col,
	output wire Ck2_Col,
	output wire Load_Col,
	output reg SIn_Test,
	output wire Ck1_Test,
	output wire Ck2_Test,
	output wire Load_Test,
	output reg SIn_TDAC,
	output wire Ck1_TDAC,
	output wire Ck2_TDAC,
	output wire Load_TDAC,
	output wire Readback,

	output wire Injection,
	output wire ResetBiasBlocks,

	output wire PCH,				//pre charge for TDAC readback
	output wire WrEn,				// driver vor pixel ram enabled
	output wire WR,				//Write RAM

	//to RO SM
	output reg [63:0] DataOut,
	output wire Data_ready,
	output wire sync_reset,					//Make switchabel EnSC_sync
	//to ADC
	output reg [9:0] ADC_VDAC,
	output reg [4:0] ADC_Mux,				//32 addresses enough?
	output wire SOut
	);


	//SC SM states
	parameter StateReset 					= 	25'b1_0000_0000_0000_0000_0000_0000;
	parameter StateSyncReset 				= 	25'b0_1000_0000_0000_0000_0000_0000;

	parameter StateWait 						=	25'b0_0100_0000_0000_0000_0000_0000;

	parameter StateReadInput 				= 	25'b0_0010_0000_0000_0000_0000_0000;
	parameter StateInterpretData 			= 	25'b0_0001_0000_0000_0000_0000_0000;

	parameter StateWriteDacRegister 		= 	25'b0_0000_1000_0000_0000_0000_0000;
	parameter StateLoadDacRegister 		= 	25'b0_0000_0100_0000_0000_0000_0000;

	parameter StateWriteConfRegister 	= 	25'b0_0000_0010_0000_0000_0000_0000;
	parameter StateLoadConfRegister 		= 	25'b0_0000_0001_0000_0000_0000_0000;

	parameter StateWriteVDACRegister 	= 	25'b0_0000_0000_1000_0000_0000_0000;
	parameter StateLoadVDACRegister 		= 	25'b0_0000_0000_0100_0000_0000_0000;

	parameter StateWriteColRegister 		= 	25'b0_0000_0000_0010_0000_0000_0000;
	parameter StateShiftColRegisterbyOne= 	25'b0_0000_0000_0001_0000_0000_0000;
	parameter StateLoadColRegister 		= 	25'b0_0000_0000_0000_1000_0000_0000;
	parameter StateRWPixelRAM	 			= 	25'b0_0000_0000_0000_0100_0000_0000;


	parameter StateWriteTestRegister 	= 	25'b0_0000_0000_0000_0010_0000_0000;
	parameter StateLoadTestRegister		= 	25'b0_0000_0000_0000_0001_0000_0000;

	parameter StateWriteTDACRegister 	= 	25'b0_0000_0000_0000_0000_1000_0000;
	parameter StateLoadTDACRegister 		= 	25'b0_0000_0000_0000_0000_0100_0000;

	parameter StateReadTDACRegister 		= 	25'b0_0000_0000_0000_0000_0010_0000;
	parameter StateHoldPCH			 		= 	25'b0_0000_0000_0000_0000_0001_0000;
	parameter StateReadDacRegister 		= 	25'b0_0000_0000_0000_0000_0000_1000;


	parameter StateSteerADC 				= 	25'b0_0000_0000_0000_0000_0000_0100;

	parameter StateInject		 			= 	25'b0_0000_0000_0000_0000_0000_0010;
	parameter StateResetBiasBlocks 		= 	25'b0_0000_0000_0000_0000_0000_0001;			//


	//Action flags for the SC SM
	parameter ActionWriteDacRegister 	= 	6'b111000;
	parameter ActionLoadDacRegister 	= 	6'b000111;

	parameter ActionWriteConfRegister 	= 	6'b110100;
	parameter ActionLoadConfRegister 	= 	6'b001011;

	parameter ActionWriteVDACRegister 	= 	6'b110010;
	parameter ActionLoadVDACRegister 	= 	6'b010011;

	parameter ActionWriteColRegister 	= 	6'b110001;			//new
	parameter ActionLoadColRegister 		= 	6'b100011;				//new

	parameter ActionWriteTestRegister 	= 	6'b101100;			//new
	parameter ActionLoadTestRegister 	= 	6'b001101;			//new

	parameter ActionWriteTDACRegister 	= 	6'b101010;			//new
	parameter ActionLoadTDACRegister 	= 	6'b010101;			//new

	parameter ActionReadbackDacs 		=	6'b100110;				//copies Ram to Shift register
	parameter ActionReadbackTDACs		=   6'b100101;				//new

	parameter ActionSteerADC			=	6'b100000;				//go to certain voltage, update ADC, round robin,
	parameter ActionInject 				=	6'b001000;

	parameter ActionResetBiasBlocks		=	6'b000010;				//17  1bit-->6, 3 bit , 5 bit -> 6

	parameter ActionShiftColRegisterbyOne= 6'b111101;


	//Broadcast signals
	parameter ActionSyncReset 		=	64'hFFFF_FFFF_FFFF_FFFF;

	parameter BroadcastAddress		=	4'hF;


	//shiftregister states
	parameter RegStateSetBit 				= 		6'b010000;
	parameter RegStateCk1_on 				= 		6'b001000;
	parameter RegStateCk1_off 				= 		6'b000100;
	parameter RegStateCk2_on 				= 		6'b000010;
	parameter RegStateCk2_off 				= 		6'b000001;

	parameter RegStateReadbackData_ready    =       6'b100000;

	//ADC actions
	parameter AdcActionReset       		= 4'b1000;	//Stop
	parameter AdcActionConfigure       	= 4'b0100;
	parameter AdcActionMeasure       	= 4'b0010;

	//ADC states
	parameter AdcStateReset       		= 4'b1000;
	parameter AdcStateWait       		= 4'b0100;
	parameter AdcStateMeasure       	= 4'b0010;
	parameter AdcStateFinished       	= 4'b0001;

	// ADC cycling mode
	parameter AdcModeSingle			= 4'b0100;
	parameter AdcModeSequence		= 4'b0010;
	parameter AdcModeAll			= 4'b0001;
	//last bit could be used to decide whether the measuremnt is done once or repaeted

	//ADC regs
	reg		CompIn_reg;					//sample of the coparator input
	reg		AdcDataReady;				//Data_ready of ADC
	reg[9:0] AdcVDAC;
	reg[3:0] AdcState;					//State
	reg[9:0] AdcDiv;					//Additional division of slow clock to make slow measurement, depends on speed of VDAC and Mux, also it reduces the mux switching activity
	reg[3:0] AdcMode;					//Measurement mode: roundrobin, single, sequence,
	reg[19:0] MuxAddr;					//sequencer addresses 4 addresses with 5 bit --> 32 voltages enough?
	reg[9:0] Adc_wait_time_reg;
	reg[5:0] AdcMeasurementCnt;


	//bit flags
	parameter ADC_FLAG 		= 4'b1100;
	parameter RB_FLAG		 	= 4'b0110;
	parameter ERROR_FLAG_COMMAND 	= 4'b0011 ;
	parameter ERROR_FLAG_STATE 	= 4'b0101 ;
	parameter ERROR_FLAG_ADC 	= 4'b1001 ;

	//unused
	parameter data_length 	= 6'h40;		// 32 --> 64
	parameter word_length 	= 5'h18;		// 24 --> 54

	//////////
	//INTERNAL

	//CLOCKING
	// 125 MHz base -- pos edge --> 62.5 MHz
	// Aim for bit speed of up to 10 Mbit/s
	// Bit steps needed: apply bit value, ck1-on, ck1-off, ck2-on, ck2-off ==>> at fullspeed 10.5 MBits/s !! check experimentally; w/o extension --> load is 16ns long ==> extend
	// current speed 125 MHz /6(div ref clock) /32(div slow clock)

	reg[7:0] slow_clock_div_internal;

	reg[7:0] slow_clock_timer;//
	reg		slow_clock_reg;

	reg[9:0] wait_timer;

	//States
	reg[24:0] State;
	reg[5:0] RegState;
	reg[63:0] Dataword;			//input format: [63:12] Data/config, [9:4] ActionFlag, [3:0] ChipAdress
	reg[53:0] Readback_word;

	reg[6:0] data_counter;
	//reg[6:0] data_out_counter;
	reg[5:0] word_counter;


	assign fast_clock = ref_clock;
	assign slow_clock = slow_clock_reg;


	assign sync_reset = (State == StateSyncReset);

	assign Load_Bias = (State == StateLoadDacRegister) ;
	assign Load_Conf = (State == StateLoadConfRegister) ;
	assign Load_VDAC = (State == StateLoadVDACRegister) ;
	assign Load_Col = (State == StateLoadColRegister) ;
	assign Load_Test = (State == StateLoadTestRegister) ;
	assign Load_TDAC = (State == StateLoadTDACRegister) ;

	assign Ck1_Bias = ( (State == StateWriteDacRegister || State == StateReadDacRegister) && RegState == RegStateCk1_on ) ;
	assign Ck2_Bias = ( (State == StateWriteDacRegister || State == StateReadDacRegister) && RegState == RegStateCk2_on ) ;

	assign Ck1_Conf = ( (State == StateWriteConfRegister || State == StateReadDacRegister) && RegState == RegStateCk1_on ) ;			//RB for new register parts
	assign Ck2_Conf = ( (State == StateWriteConfRegister || State == StateReadDacRegister) && RegState == RegStateCk2_on ) ;

	assign Ck1_VDAC = ( (State == StateWriteVDACRegister || State == StateReadDacRegister) && RegState == RegStateCk1_on ) ;
	assign Ck2_VDAC = ( (State == StateWriteVDACRegister || State == StateReadDacRegister) && RegState == RegStateCk2_on ) ;

	assign Ck1_Col = ( (State == StateWriteColRegister || State == StateShiftColRegisterbyOne || State == StateReadDacRegister) && RegState == RegStateCk1_on ) ;
	assign Ck2_Col = ( (State == StateWriteColRegister || State == StateShiftColRegisterbyOne || State == StateReadDacRegister) && RegState == RegStateCk2_on ) ;

	assign Ck1_Test = ( (State == StateWriteTestRegister || State == StateReadDacRegister) && RegState == RegStateCk1_on ) ;
	assign Ck2_Test = ( (State == StateWriteTestRegister || State == StateReadDacRegister) && RegState == RegStateCk2_on ) ;

	assign Ck1_TDAC = ( (State == StateWriteTDACRegister || State == StateReadDacRegister) && RegState == RegStateCk1_on ) ;					//RB for TDACs?
	assign Ck2_TDAC = ( (State == StateWriteTDACRegister || State == StateReadDacRegister) && RegState == RegStateCk2_on ) ;

	assign Readback = (State == StateReadDacRegister) ;

	assign Injection = (State == StateInject);									//check polarity
	assign ResetBiasBlocks = (State == StateResetBiasBlocks);			//check polarity

	assign WrEn = (State == StateRWPixelRAM);//!(State == StateReadTDACRegister || State == StateReadDacRegister || State == StateHoldPCH);
	assign PCH = (State == StateHoldPCH);
	assign WR  = (State == StateRWPixelRAM || State == StateReadDacRegister);

	assign Data_ready = ( RegState == RegStateReadbackData_ready || AdcDataReady == 1'b1);

	assign SOut = Dataword[0];				//( Dataword[0] == 1'b1 ) ;


	//fast sampling

	always @( posedge ref_clock or posedge Reset) begin


	 if(Reset) begin
					//reset everything/default state
		State <= StateReset ;
		RegState <= RegStateSetBit ;
		data_counter <= 7'b0 ;
		word_counter <= 6'b0 ;
		//Dataword[63:0] <= 64'h0000_0000_0000_0000 ;
		//Readback_word[53:0] <= 54'h00_0000_0000_0000 ;
		slow_clock_div_internal[5:3] <= 3'b000 ;
		slow_clock_div_internal[0] <= 1'b1 ;		//fixed division, 10 MBit is mostlikely to fast, also you want to have a clean data transmission through the RO data. THis asssumes SC slower than RO, the slower the better.
		slow_clock_div_internal[7:6] <= slow_clock_div[3:2];		//4bits from external, 2 LSB and 2 MSB // maybe 2MsB not required (only safety pre-caution)
		slow_clock_div_internal[2:1] <= slow_clock_div[1:0];
		slow_clock_timer <= 0 ;
		slow_clock_reg <= 1'b0 ;

		wait_timer 			<= 10'b0 ;

		//ADC
		AdcState 			<= AdcStateReset;
		CompIn_reg 			<= 0;
		AdcDataReady 		<= 0;
		AdcDiv 				<= 0;
		AdcMode 			<= 0;
		MuxAddr 			<= 0;
		Adc_wait_time_reg 	<= 0;


	 end//Reset
	 //slow sampling
	 else begin

	    //slow clock generation
	   	if(slow_clock_timer != slow_clock_div_internal[7:0]) begin
				slow_clock_timer <= slow_clock_timer + 1 ;
		end
		else begin
			slow_clock_timer <= 0 ;
		end

		if(slow_clock_timer == 0 ) begin
			slow_clock_reg <= ~slow_clock_reg;
		end

		/////////////////
		//STATEMACHINE
		case ( State )

			//Waiting for Start Spike
			StateWait: begin
				if(slow_clock_timer == 0) begin
					if(Serial_In) begin
						//State <= StateReadInput;
						//State[23:0]<=State[24:1]; State[24]<=0;
						State[21]<=State[22]; State[22]<=0;			//all equivalent
					end

					data_counter <= 7'b0 ;
					RegState <= RegStateSetBit ;
				end

			end//Wait

			//Syncronous Reset, reset all registers and hold the the slow clock
			StateSyncReset: begin
				slow_clock_div_internal[5:3] <= 3'b000 ;
				slow_clock_div_internal[0] <= 1'b1 ;
				slow_clock_div_internal[7:6] <= slow_clock_div[3:2];
				slow_clock_div_internal[2:1] <= slow_clock_div[1:0];
				slow_clock_timer <= 0 ;
				slow_clock_reg <= 0 ;
				if(!Serial_In) begin	//Release SyncReset
					State <= StateWait;
				end
				else begin
					RegState <= RegStateSetBit ;
					data_counter <= 7'b0 ;
					word_counter <= 6'b0 ;
					//Dataword[63:0] <= 64'h0000_0000_0000_0000 ;
					//Readback_word[53:0] <= 54'h00_0000_0000_0000 ;

				end
			end//SyncReset

			StateReset: begin
				if(slow_clock_timer == 0) begin
				State <= StateWait;
				end
			end//Reset

			//Read data syncronous to the slow clock
			StateReadInput: begin
				if(slow_clock_timer == 0) begin
					if(data_counter[6] == 1'b0 ) begin
						Dataword[62:0] <= Dataword[63:1] ;
						Dataword[63] <= Serial_In ;
						data_counter <= data_counter + 1 ;
					end
					else begin
						data_counter <= 7'b0 ;
						State <= StateInterpretData;
					end
				end
			end//ReadInput

			//Interpret the read data
			StateInterpretData: begin
				if(slow_clock_timer == 0) begin
					if(Dataword[63:0] == ActionSyncReset)	//is SyncReset?
						State <= StateSyncReset;
					else
					if(Dataword[3:0] != Chip_Address && Dataword[3:0] != BroadcastAddress)		//Correct Chip Address?
						State <= StateWait;
					else begin
						AdcState <= AdcStateWait;			//When the SC is about to do something, stop the ADC (no data flow)
						case (Dataword[9:4])				//Decode Action Flag
							ActionWriteDacRegister: begin
								State <= StateWriteDacRegister;
								data_counter <= 7'h0A;
								//data_counter[3] <= 1'b1 ;	//10bit header
								//data_counter[1] <= 1'b1 ;
								end
							ActionLoadDacRegister: 		State <= StateLoadDacRegister;

							ActionWriteConfRegister: begin
								State <= StateWriteConfRegister;
								data_counter <= 7'h0A;
								//data_counter[3] <= 1'b1 ;	//10bit header
								//data_counter[1] <= 1'b1 ;
								end
							ActionLoadConfRegister: 		State <= StateLoadConfRegister;

							ActionWriteVDACRegister: begin
								State <= StateWriteVDACRegister;
								data_counter <= 7'h0A;
								//data_counter[3] <= 1'b1 ;	//10bit header
								//data_counter[1] <= 1'b1 ;
								end
							ActionLoadVDACRegister: 		State <= StateLoadVDACRegister;

							ActionWriteColRegister: begin
								State <= StateWriteColRegister;
								data_counter <= 7'h0A;
								//data_counter[3] <= 1'b1 ;	//10bit header
								//data_counter[1] <= 1'b1 ;
								end
							ActionLoadColRegister: 		State <= StateLoadColRegister;

							ActionShiftColRegisterbyOne: State <= StateShiftColRegisterbyOne;

							ActionWriteTestRegister: begin
								State <= StateWriteTestRegister;
								data_counter <= 7'h0A;
								//data_counter[3] <= 1'b1 ;	//10bit header
								//data_counter[1] <= 1'b1 ;
								end
							ActionLoadTestRegister: 		State <= StateLoadTestRegister;

							ActionWriteTDACRegister: begin
								State <= StateWriteTDACRegister;
								data_counter <= 7'h0A;
								//data_counter[3] <= 1'b1 ;	//10bit header
								//data_counter[1] <= 1'b1 ;
								end
							ActionLoadTDACRegister: 		State <= StateLoadTDACRegister;

							ActionReadbackDacs: 		State <= StateReadDacRegister;
							ActionReadbackTDACs: 		State <= StateReadTDACRegister;

							ActionInject:				State <= StateInject;
							ActionResetBiasBlocks: State <= StateResetBiasBlocks;
							ActionSteerADC:	 			State <= StateSteerADC;
							default: begin

								if(slow_clock_timer == 0) begin

									DataOut[3:0] <= ERROR_FLAG_COMMAND ;				//report error
									DataOut[63:4] <= Dataword[63:4] ;		//to much fanout?

									if(RegState == RegStateReadbackData_ready) begin

										data_counter <= 7'b0 ;
										State <= StateWait;
										RegState <= RegStateSetBit ;
									end
									else begin
										RegState <= RegStateReadbackData_ready;
									end
								end

							end//default

						endcase
					end
				end
			end//Interpret Data

			//Write Bias DAC register
			StateWriteDacRegister: begin
				if(slow_clock_timer == 0) begin
					if(data_counter[6] == 1'b0) begin

						case (RegState)
							RegStateSetBit: begin
								SIn_Bias <= Dataword[10];
								Dataword[62:10] <= Dataword[63:11];
								Readback_word[53:1] <= Readback_word[52:0] ;
								Readback_word[0] <= Bias_Back_In ;
								RegState <= RegStateCk1_on ;
							end
							RegStateCk1_on: begin
								RegState <= RegStateCk1_off ;
							end
							RegStateCk1_off: begin
								RegState <= RegStateCk2_on ;
							end
							RegStateCk2_on: begin
								RegState <= RegStateCk2_off ;
							end
							RegStateCk2_off: begin
								RegState <= RegStateSetBit ;
								data_counter <= data_counter + 1 ;
							end
						endcase

						DataOut[53:0] <= Readback_word[53:0] ;		//readback data format
						DataOut[59:54] <= word_counter ;			//sampled her for ready signal
						DataOut[63:60] <= RB_FLAG ;

					end//Write register
					else begin

						if(RegState == RegStateReadbackData_ready) begin

							data_counter <= 7'b0 ;
							word_counter <= word_counter + 1 ;
							State <= StateWait;
							RegState <= RegStateSetBit ;
						end
						else begin
							RegState <= RegStateReadbackData_ready;
						end

					end	//Data ready for readback

				end
			end

			//Load Bias DAC register
			StateLoadDacRegister: begin					// wait
				if(slow_clock_timer == 0) begin
					if(wait_timer <= Dataword[19:10]) begin
						wait_timer <= wait_timer + 1 ;
					end
					else begin
						wait_timer <= 0 ;
						State <= StateWait ;
					end
				end
			end//Load

			//Write Conf register
			StateWriteConfRegister: begin
				if(slow_clock_timer == 0) begin
					if(data_counter[6] == 1'b0) begin

						case (RegState)
							RegStateSetBit: begin
								SIn_Conf <= Dataword[10];
								Dataword[62:10] <= Dataword[63:11];
								Readback_word[53:1] <= Readback_word[52:0] ;		//extend
								Readback_word[0] <= Conf_Back_In ;
								RegState <= RegStateCk1_on ;
							end
							RegStateCk1_on: begin
								RegState <= RegStateCk1_off ;
							end
							RegStateCk1_off: begin
								RegState <= RegStateCk2_on ;
							end
							RegStateCk2_on: begin
								RegState <= RegStateCk2_off ;
							end
							RegStateCk2_off: begin
								RegState <= RegStateSetBit ;
								data_counter <= data_counter + 1 ;
							end
						endcase

						DataOut[53:0] <= Readback_word[53:0] ;			//readback data format
						DataOut[59:54] <= word_counter ;			//sampled her for ready signal
						DataOut[63:60] <= RB_FLAG ;

					end//Write register
					else begin


						if(RegState == RegStateReadbackData_ready) begin

							data_counter <= 7'b0 ;
							word_counter <= word_counter + 1 ;
							State <= StateWait;
							RegState <= RegStateSetBit ;
						end
						else begin
							RegState <= RegStateReadbackData_ready;
						end

					end	//Data ready for readback

				end
			end

			//Load Bias DAC register
			StateLoadConfRegister: begin					// wait
				if(slow_clock_timer == 0) begin
					if(wait_timer <= Dataword[19:10]) begin
						wait_timer <= wait_timer + 1 ;
					end
					else begin
						wait_timer <= 0 ;
						State <= StateWait ;
					end
				end
			end//Load

			//Write VDAC register
			StateWriteVDACRegister: begin
				if(slow_clock_timer == 0) begin
					if(data_counter[6] == 1'b0) begin

						case (RegState)
							RegStateSetBit: begin
								SIn_VDAC <= Dataword[10];
								Dataword[62:10] <= Dataword[63:11];
								Readback_word[53:1] <= Readback_word[52:0] ;		//extend
								Readback_word[0] <= VDAC_Back_In ;
								RegState <= RegStateCk1_on ;
							end
							RegStateCk1_on: begin
								RegState <= RegStateCk1_off ;
							end
							RegStateCk1_off: begin
								RegState <= RegStateCk2_on ;
							end
							RegStateCk2_on: begin
								RegState <= RegStateCk2_off ;
							end
							RegStateCk2_off: begin
								RegState <= RegStateSetBit ;
								data_counter <= data_counter + 1 ;
							end
						endcase

						DataOut[53:0] <= Readback_word[53:0] ;			//readback data format
						DataOut[59:54] <= word_counter ;			//sampled her for ready signal
						DataOut[63:60] <= RB_FLAG ;

					end//Write register
					else begin

						if(RegState == RegStateReadbackData_ready) begin

							data_counter <= 7'b0 ;
							word_counter <= word_counter + 1 ;
							State <= StateWait;
							RegState <= RegStateSetBit ;
						end
						else begin
							RegState <= RegStateReadbackData_ready;
						end

					end	//Data ready for readback

				end
			end

			//Load VDAC register
			StateLoadVDACRegister: begin					// wait
				if(slow_clock_timer == 0) begin
					if(wait_timer <= Dataword[19:10]) begin
						wait_timer <= wait_timer + 1 ;
					end
					else begin
						wait_timer <= 0 ;
						State <= StateWait ;
					end
				end
			end//Load

			//Write Pixel Register
			StateWriteColRegister: begin
				if(slow_clock_timer == 0) begin
					if(data_counter[6] == 1'b0) begin

						case (RegState)
							RegStateSetBit: begin
								SIn_Col <= Dataword[10];
								Dataword[62:10] <= Dataword[63:11];
								Readback_word[53:1] <= Readback_word[52:0] ;		//extend
								Readback_word[0] <= Col_Back_In ;
								RegState <= RegStateCk1_on ;
							end
							RegStateCk1_on: begin
								RegState <= RegStateCk1_off ;
							end
							RegStateCk1_off: begin
								RegState <= RegStateCk2_on ;
							end
							RegStateCk2_on: begin
								RegState <= RegStateCk2_off ;
							end
							RegStateCk2_off: begin
								RegState <= RegStateSetBit ;
								data_counter <= data_counter + 1 ;
							end
						endcase

						DataOut[53:0] <= Readback_word[53:0] ;			//readback data format
						DataOut[59:54] <= word_counter ;			//sampled her for ready signal
						DataOut[63:60] <= RB_FLAG ;

					end//Write register
					else begin

						if(RegState == RegStateReadbackData_ready) begin

							data_counter <= 7'b0 ;
							word_counter <= word_counter + 1 ;
							State <= StateWait;
							RegState <= RegStateSetBit ;
						end
						else begin
							RegState <= RegStateReadbackData_ready;
						end

					end	//Data ready for readback

				end
			end//Write Pix Register

			//Load Pix Register
			StateLoadColRegister: begin
				if(slow_clock_timer == 0) begin
					if(wait_timer <= Dataword[19:10]) begin
						wait_timer <= wait_timer + 1 ;
					end
					else begin
						wait_timer <= 0 ;
						State <= StateRWPixelRAM ;
					end
				end
			end//Load Pix

			//Write Pixel RAM or read pixel ram
			StateRWPixelRAM: begin
				if(slow_clock_timer == 0) begin
					if(wait_timer <= Dataword[19:10]) begin
						wait_timer <= wait_timer + 1 ;
					end
					else begin
						wait_timer <= 0 ;
						State <= StateWait ;
					end
				end
			end//Load Pix

			StateShiftColRegisterbyOne: begin
				if(slow_clock_timer == 0) begin

						case (RegState)
							RegStateSetBit: begin
								SIn_Col <= Dataword[20];
								RegState <= RegStateCk1_on ;
							end
							RegStateCk1_on: begin
								RegState <= RegStateCk1_off ;
							end
							RegStateCk1_off: begin
								RegState <= RegStateCk2_on ;
							end
							RegStateCk2_on: begin
								RegState <= RegStateCk2_off ;
							end
							RegStateCk2_off: begin
								RegState <= RegStateSetBit ;
								State <= StateLoadColRegister;
							end
						endcase

				end
			end//Write Pix Register


			//Write Test Register Inj/HB/Amp etc
			StateWriteTestRegister: begin
				if(slow_clock_timer == 0) begin
					if(data_counter[6] == 1'b0) begin

						case (RegState)
							RegStateSetBit: begin
								SIn_Test <= Dataword[10];
								Dataword[62:10] <= Dataword[63:11];
								Readback_word[53:1] <= Readback_word[52:0] ;		//extend
								Readback_word[0] <= Test_Back_In ;
								RegState <= RegStateCk1_on ;
							end
							RegStateCk1_on: begin
								RegState <= RegStateCk1_off ;
							end
							RegStateCk1_off: begin
								RegState <= RegStateCk2_on ;
							end
							RegStateCk2_on: begin
								RegState <= RegStateCk2_off ;
							end
							RegStateCk2_off: begin
								RegState <= RegStateSetBit ;
								data_counter <= data_counter + 1 ;
							end
						endcase

						DataOut[53:0] <= Readback_word[53:0] ;			//readback data format
						DataOut[59:54] <= word_counter ;			//sampled her for ready signal
						DataOut[63:60] <= RB_FLAG ;

					end//Write register
					else begin

						if(RegState == RegStateReadbackData_ready) begin

							data_counter <= 7'b0 ;
							word_counter <= word_counter + 1 ;
							State <= StateWait;
							RegState <= RegStateSetBit ;
						end
						else begin
							RegState <= RegStateReadbackData_ready;
						end

					end	//Data ready for readback

				end
			end//Write Pix Register

			//Load Test Register
			StateLoadTestRegister: begin
				if(slow_clock_timer == 0) begin
					if(wait_timer <= Dataword[19:10]) begin
						wait_timer <= wait_timer + 1 ;
					end
					else begin
						wait_timer <= 0 ;
						State <= StateWait ;
					end
				end
			end//Load Pix

			//Write Pixel Register
			StateWriteTDACRegister: begin
				if(slow_clock_timer == 0) begin
					if(data_counter[6] == 1'b0) begin

						case (RegState)
							RegStateSetBit: begin
								SIn_TDAC <= Dataword[10];
								Dataword[62:10] <= Dataword[63:11];
								Readback_word[53:1] <= Readback_word[52:0] ;		//extend
								Readback_word[0] <= TDAC_Back_In ;
								RegState <= RegStateCk1_on ;
							end
							RegStateCk1_on: begin
								RegState <= RegStateCk1_off ;
							end
							RegStateCk1_off: begin
								RegState <= RegStateCk2_on ;
							end
							RegStateCk2_on: begin
								RegState <= RegStateCk2_off ;
							end
							RegStateCk2_off: begin
								RegState <= RegStateSetBit ;
								data_counter <= data_counter + 1 ;
							end
						endcase

						DataOut[53:0] <= Readback_word[53:0] ;			//readback data format
						DataOut[59:54] <= word_counter ;			//sampled her for ready signal
						DataOut[63:60] <= RB_FLAG ;

					end//Write register
					else begin

						if(RegState == RegStateReadbackData_ready) begin

							data_counter <= 7'b0 ;
							word_counter <= word_counter + 1 ;
							State <= StateWait;
							RegState <= RegStateSetBit ;
						end
						else begin
							RegState <= RegStateReadbackData_ready;
						end

					end	//Data ready for readback

				end
			end//Write Pix Register

			//Load Pix Register
			StateLoadTDACRegister: begin
				if(slow_clock_timer == 0) begin
					if(wait_timer <= Dataword[19:10]) begin
						wait_timer <= wait_timer + 1 ;
					end
					else begin
						wait_timer <= 0 ;
						State <= StateWait ;
					end
				end
			end//Load Pix


			//Readback RAMs
			StateReadTDACRegister: begin
				if(slow_clock_timer == 0) begin
					if(wait_timer <= Dataword[19:10]) begin
						wait_timer <= wait_timer + 1 ;
					end
					else begin
						wait_timer <= 0 ;
						State <= StateHoldPCH ;
					end
				end
			end

			//Hold the PCH signal
			StateHoldPCH: begin
				if(slow_clock_timer == 0) begin
					if(wait_timer <= Dataword[19:10]) begin
						wait_timer <= wait_timer + 1 ;
					end
					else begin
						wait_timer <= 0 ;
						State <= StateWait ;
					end
				end
			end

			//Readback RAMs
			StateReadDacRegister: begin
				if(slow_clock_timer == 0) begin

					if(wait_timer <= Dataword[19:10]) begin
						wait_timer <= wait_timer + 1 ;
					end
					else begin
						if(RegState == RegStateSetBit) begin
							RegState <= RegStateCk1_on;
						end
					end

					case (RegState)		//make this external?
						RegStateCk1_on: begin
							RegState <= RegStateCk1_off ;
						end
						RegStateCk1_off: begin
							RegState <= RegStateCk2_on ;
						end
						RegStateCk2_on: begin
							RegState <= RegStateCk2_off ;
						end
						RegStateCk2_off: begin
							RegState <= RegStateSetBit ;
							wait_timer <= 0 ;
							State <= StateWait ;
							word_counter <= 0 ;
						end
					endcase

				end
			end

			StateInject: begin
				//Inject <= 1;
				if(slow_clock_timer == 0) begin
					if(wait_timer <= Dataword[19:10]) begin
						wait_timer <= wait_timer + 1 ;
					end
					else begin
						//Inject <= 0;
						wait_timer <= 0 ;
						State <= StateWait ;
					end
				end
			end

			StateResetBiasBlocks: begin
				//ResetBiasBlocks <= 1 ;
				if(slow_clock_timer == 0) begin
					if(wait_timer <= Dataword[19:10]) begin
						wait_timer <= wait_timer + 1 ;
					end
					else begin
						//ResetBiasBlocks <= 0 ;
						wait_timer <= 0 ;
						State <= StateWait ;
					end
				end
			end

			StateSteerADC: begin
				if(slow_clock_timer == 0) begin
					case (Dataword[13:10])

					AdcActionReset:	AdcState <= AdcStateReset;

					AdcActionConfigure:	begin	// ADC VDAC Value?
						AdcState 	<= AdcStateWait;			//set value
						AdcDiv 		<= Dataword[23:14];
						AdcMode  	<= Dataword[27:24];				//single DAC, sequencer, all, repeated
						MuxAddr  	<= Dataword[47:28];
						AdcVDAC 	<= Dataword[57:48];
					end

					AdcActionMeasure: AdcState <= AdcStateMeasure;

					default:	AdcState <= AdcStateWait;

					endcase

					State <= StateWait ;

				end
			end// Read ADC

			default: begin										//tell!! report error
				if(slow_clock_timer == 0) begin

					DataOut[3:0] <= ERROR_FLAG_STATE ;				//report error
					DataOut[63:4] <= Dataword[63:4] ;		//what else to tell? STATE?

					if(RegState == RegStateReadbackData_ready) begin

						State <= StateWait;
						RegState <= RegStateSetBit ;
					end
					else begin
						RegState <= RegStateReadbackData_ready;
					end
				end
			end

		endcase //case

		////////////////////////////////////////////////////////////////////
		////////////////////////////////////////////////////////////////////
		// ADC Statemachine
		////////////////////////////////////////////////////////////////////
		////////////////////////////////////////////////////////////////////

		ADC_VDAC <= AdcVDAC;		//VDAC_value to output //fast clock //is this ok?

		case (AdcState)

		//Reset ADC Config
		AdcStateReset: begin

			AdcDiv <= 0;	//10bit
			AdcMode <= 0;	//3bit
			MuxAddr <= 0;
			Adc_wait_time_reg <= 0 ;
			AdcMeasurementCnt <= 0;
			AdcVDAC <= 0 ;
			CompIn_reg <= 0;
			AdcDataReady <= 0;


			if(slow_clock_timer == 0) begin
					AdcState <= AdcStateWait;
			end
		end

		//IDLE, reset counters
		AdcStateWait: begin
			//reset counters, values to 0
			CompIn_reg	 		<= 0;
			AdcDataReady 		<= 0;
			AdcVDAC 				<= 0;
			ADC_Mux				<= 0;
			Adc_wait_time_reg 	<= 0;
			AdcMeasurementCnt 	<= 0;
		end

		//MEASUREMENT simple count up VDAC, interval nesting can implemented if wished, but count up might be superior due to minimal voltage changes in each step. More than a factor 1000 possible to slow down the sampling. div_SC*div_ADC (max 60000)
		AdcStateMeasure: begin
			if(slow_clock_timer == 0) begin
				CompIn_reg <= CompIn;						//sample the comparator
				if(Adc_wait_time_reg != AdcDiv) begin
						Adc_wait_time_reg <= Adc_wait_time_reg + 1 ;
				end
				else begin
					Adc_wait_time_reg <= 0 ;
					if(CompIn_reg == 1 || AdcVDAC == 10'h3FF) begin		//Finish measurement if either Comp is high or VDAC at max.
						AdcState <= AdcStateFinished;
					end
					else begin
						AdcVDAC <= AdcVDAC + 1 ;
					end
				end
			end
		end

		AdcStateFinished: begin
			if(slow_clock_timer == 0) begin
				//if(RegState != RegStateReadbackData_ready) begin		//not required due to strict separation

					if(AdcDataReady != 1) begin

						case (AdcMode)
						AdcModeAll: begin
							MuxAddr[4:0] <= MuxAddr[4:0] +1 ;		//will spill over, but does not matter here
							end

						AdcModeSequence: begin
							MuxAddr[14:0] <= MuxAddr[19:5];
							MuxAddr[19:15] <= MuxAddr[4:0];
							end

						//default and single: nothing to do here
						endcase

						AdcDataReady <= 1;
						AdcMeasurementCnt <= AdcMeasurementCnt + 1 ;
						DataOut[9:0] <= AdcVDAC;
						DataOut[14:10] <= MuxAddr[4:0];
						DataOut[24:15] <= AdcDiv;
						DataOut[28:25] <= AdcMode;
						DataOut[59:54] <= AdcMeasurementCnt;
						DataOut[63:60] <= ADC_FLAG;
					end
					else begin
						AdcDataReady <= 0 ;
						ADC_Mux <= MuxAddr[4:0];
						AdcState <= AdcStateMeasure;
						AdcVDAC <= 0 ;
					end
				//end
			end
		end//ADC finished

		default: begin
			if(slow_clock_timer == 0) begin

				DataOut[9:0] <= AdcVDAC;
				DataOut[14:10] <= MuxAddr[4:0];
				DataOut[24:15] <= AdcDiv;
				DataOut[28:25] <= AdcMode;
				DataOut[59:54] <= AdcMeasurementCnt;
				DataOut[63:60] <= ERROR_FLAG_ADC ;

				if(AdcDataReady == 1) begin

					AdcState <= AdcStateWait;
					AdcDataReady <= 0;
				end
				else begin
					AdcDataReady <= 1;
				end
			end
		end
		endcase



	end//no Reset

end //always

endmodule