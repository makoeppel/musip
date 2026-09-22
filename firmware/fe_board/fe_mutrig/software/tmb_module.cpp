//
#include <sys/alt_cache.h>
#include "tmb_module.h"
#include "builtin_config/mutrig3_config.h"

//from base.h
//
//#include <stdio.h>
char wait_key(useconds_t us = 100000);//{return getchar();}

#include "system.h"
#include "../../fe/software/sc.h"
#include "../../../../midas_fe/constants.h"

#include "../../../registers/mutrig_registers.h"
#include "../../../registers/sorter_registers.h"
#include <altera_avalon_spi.h>
TB_t::TB_t(sc_t& _sc):sc(_sc){
    software_Status = 0; //Set 1 if initialized
	boards_present = 0;
    asicStatus = 0;
    matrix_tmp_Status = 0;
    for(auto board=0; board < nBoards ; board++)
        boardIDs[board]=0xffff;
};

bool TB_t::is_board_present(int asic){
	if( (boards_present&(1<<asic)) == 0){
		return false;
	}
	return true;
}

alt_u16 TB_t::init_TB(){
	boards_present = 0;
	software_Status = 1;
	asicStatus = 0;
	matrix_tmp_Status = 0;
    for(auto board=0; board < nBoards ; board++){
		ping(board,boardIDs[board]);
		if(ping(board,boardIDs[board]))
			boards_present+=(1<<board);
		printf("Board %d Present: %x --> ID=%x\n",board,(boards_present>>board)&1,boardIDs[board]);
    }
	printf("Boards Present mask: %x\n",boards_present);
	printf("SiPM Temperature sensor mask: %x\n", matrix_tmp_Status);
	return boards_present;	
}

/**
 * Power up/down ASIC
 * UP:
 * - powerup digital 1.8V
 * - configure ALL_OFF pattern twice
 * - if not ok, then powerdown digital and exit
 * - powerup analog 1.8V
 * DOWN:
 * - power down analog 1.8V
 * - power down digital 1.8V
 */
alt_u16 TB_t::power_ASIC(int asic, bool enable){
    alt_u16 status = FEB_REPLY_SUCCESS;
    if(!is_board_present(asic))
        return status;
    if(enable) {
        //already powered, do not overwrite configuration
        if((asicStatus & (0x01 << asic)) != 0)
            return status;
        //preconfigure - allows for softer start
        configure_asic(asic, config_ALL_OFF);
        //power up
        power_ASIC_AD(asic,true,false);   //analog first
        //power_ASIC_AD(asic,false,true); //digital first
        usleep(10000); //wait for settling
        if(configure_asic(asic, config_ALL_OFF) != FEB_REPLY_SUCCESS){
            //printf("Configuration error, powering off again\n");
            status = FEB_REPLY_ERROR;
            power_ASIC_AD(asic,false,false);
            return status;
        }
        power_ASIC_AD(asic,true,true);
        usleep(10000); //wait for settling
        asicStatus |= (0x01 << asic);
    }else{
        //power down
        power_ASIC_AD(asic,false,false);
        asicStatus &= ~(0x01 << asic);
    }
    return status;
}

alt_u16 TB_t::power_ASIC_AD(int asic, bool enable_vcca, bool enable_vccd, bool configure){
    printf("Powering ASIC %d : vcca=%d vccd=%d\n",asic,enable_vcca,enable_vccd);
	struct mcu_packet packet;
	char buffer[32];
	packet.data=buffer;

    char val=0;
    if(enable_vccd)
		val+=2;
    if(enable_vcca)
		val+=1;
    if(configure)
		val+=4;
	//printf("v=%u ",val);

	uart485_select(UART485_0_BASE,SPI_BASE,asic);
	uart485_write_packet(UART485_0_BASE,mcu_packet(MCUCMD_PCTRL,1,&val),0);
	auto status=uart485_rcv_packet(UART485_0_BASE,packet,1,true);
	//printf("Status: RCV status=%d",status);
	//packet.print();
	if(status < 0) packet.data[0]=0xff;
	return packet.data[0];
}

void TB_t::power_ASIC_all(bool enable){
    for(int i = 0; i <= 2; i++){
        power_ASIC(i, enable);
    }
}

alt_u16 TB_t::setInject(int enable){
	printf("inj ->%d\n",enable);
    auto& regs = sc.ram->data;

    alt_u32 regval=regs[MUTRIG_CNT_CTRL_REGISTER_W];
    regval &= ~(1<<0);
    asicStatus &= ~(0x01 << 13);
    if(enable!=0){
        regval |= (1<<0);
        asicStatus |= (0x01 << 13);
    }
    regs[MUTRIG_CNT_CTRL_REGISTER_W]=regval;

    //Verify write
    if( checkInject() != enable)
        return FEB_REPLY_ERROR;
    return FEB_REPLY_SUCCESS;
}

bool TB_t::checkInject(){
    auto& regs = sc.ram->data;
    bool status = (regs[MUTRIG_CNT_CTRL_REGISTER_W]) & 0x01;
    return status;
}




void TB_t::read_matrix_t(volatile alt_u32 * data){
    for(int n = 0; n < 2*nBoards ; n++){
    	data[n+1]=0xffff;
    }
    data[0]=0x0;

    struct mcu_packet packet;
    char buffer[32];
    packet.data=buffer;
    for(auto board=0; board < nBoards ; board++){
        if(!is_board_present(board)){
                continue;
            }
        uart485_select(UART485_0_BASE,SPI_BASE,board);
        uart485_write_packet(UART485_0_BASE,mcu_packet(MCUCMD_TRD,0),0);
        auto status=uart485_rcv_packet(UART485_0_BASE,packet,32,true);
        if(status < 0){
        	data[board*2 + 1]=0xffff;
        	data[board*2 + 2]=0xffff;
        } else {
            data[0] |= 3<<(board*2);
            data[1+board*2]  = (packet.data[0]<<8) & 0xff00;
            data[1+board*2] |= (packet.data[1]<<0) & 0x00ff;
            data[2+board*2]  = (packet.data[2]<<8) & 0xff00;
            data[2+board*2] |= (packet.data[3]<<0) & 0x00ff;
        }
    }
}

void TB_t::read_power(volatile alt_u32 * data){
	for(int n = 0; n < 2*3 ; n++){
	    	data[n]=0xffff;
}

	struct mcu_packet packet;
	char buffer[32];
    packet.data=buffer;

    for(auto board=0; board < nBoards ; board++){
		if(!is_board_present(board)){
			continue;
		}
	    uart485_select(UART485_0_BASE,SPI_BASE,board);
	    uart485_write_packet(UART485_0_BASE,mcu_packet(MCUCMD_VRD,0),0);
	    auto status=uart485_rcv_packet(UART485_0_BASE,packet,32,true);
	    //packet.print();
	    if(status >= 0){
	        data[board*3+0] = (alt_u32) packet.data[1]<<8 | packet.data[0];
	        data[board*3+1] = (alt_u32) packet.data[3]<<8 | packet.data[2];
	        data[board*3+2] = (alt_u32) packet.data[5]<<8 | packet.data[4];
        }
    }
}

//read testboard status and fill into structure.
//in TMB: data[0]: status bits
//                  0: init
//                  1: inject
//                  2: pgood
//            18...31: asic status
//        data[1]: vcc a/d status bits
//        data[2]: tmb temperature 0
//        data[3]: tmb temperature 1

//extensions: asic status in data 0,1 are mapping both boards. i.e asic 0-> board0 asic0, asic 1-> board1 asic0
//tmb temperature in data 2,3 are from both boards, one field each.
// data[0]: status bits
//                  0: init board0
//                  1: inject board0
//                  2: pgood board0
///                 3: init board1
//                  4: inject board1
//                  5: pgood board1 
//        data[1]: vcc a/d status bits
//                  0: vcca board 0
//                  1: vcca board 1
//                 13: vcca board 0
//                 14: vcca board 1
//        data[2]: temperature board 0
//        data[3]: temperature board 1
//
//data from board:
//					packet.data[0]=get_status();
//						0: digital
//						1: analog
//						2: pgood
//                  packet.data[1]=t>>8;
//                  packet.data[2]=t&0xff;

void TB_t::read_tb_status(volatile alt_u32 * data){
	for(int n = 0; n < 2+nBoards ; n++){
	    data[n]=0x0000;
	}
	struct mcu_packet packet;
	char buffer[32];
    packet.data=buffer;

	for(int board = 0; board < nBoards; board++){
		if(!is_board_present(board)){
			continue;
		}
		uart485_select(UART485_0_BASE,SPI_BASE,board);
		uart485_write_packet(UART485_0_BASE,mcu_packet(MCUCMD_STAT,0),0);
		auto status=uart485_rcv_packet(UART485_0_BASE,packet,3,true);
		//printf("Board %d Status RX, ret=%d, ",board,status); packet.print();
		if(status >= 0){
			if(software_Status != 0)
				data[0]	      |= 1<<(board*3); //board present is already checked in the loop above, so only software status
			if(checkInject())
				data[0]	      |= 1<<(board*3 + 1); //inject
			if((packet.data[0]&4) != 0)
				data[0]	      |= 1<<(board*3 + 2); //pgood
			if((asicStatus & (1<<board))!=0)
				data[0]	  |= 1<<(board+18); //asic status

			data[1]       |= (alt_u32) (packet.data[0]&1)<<(board);
			data[1]       |= (alt_u32) (packet.data[0]&2)<<(board+13-1);
			data[2+board]  = (packet.data[1]<<8) & 0xff00;
			data[2+board] |= (packet.data[2]<<0) & 0x00ff;
            data[2+board] *= 32; //bring into units of 8.7mK
            data[2+board] -= 0x8880; //Bring into units of C
		}
		//printf("Status %x %x %d %d\n",data[0],data[1],data[2],data[3]);
	}
}

void TB_t::print_matrix_t(volatile alt_u32 * data, const bool two_columns){
    printf("MSK:\t 0x%04X\n",data[0]);
    for(int id = 0; id<4; id++){
		printf("TMP[%d]:\t 0x%04X\n",id,data[id+1]);
    }
}

void TB_t::print_power(volatile alt_u32 * data){
	printf("[%d]:\t 0x%04X\n",0,data[0]);
	printf("[%d]:\t 0x%04X\n",1,data[1]);
	printf("[%d]:\t 0x%04X\n",2,data[2]);
}
void TB_t::print_tb_status(volatile alt_u32 * data){
	for(int board = 0; board < nBoards; board++){
		printf("[%d] Status:\n",board);
		printf("Temperature :\t 0x%04X\n",data[2+board]);
		printf("INI:\t 0x%04X\n",data[0]&(1<<(0+3*board)));
		printf("INJ:\t 0x%04X\n",data[0]&(1<<(1+3*board)));
		printf("PGn:\t 0x%04X\n",data[0]&(1<<(2+3*board)));

		printf("PWR:\t 0x%04X\n",data[0]&(1<<(18+board)));

		printf("18D:\t 0x%04X\n",data[1]&(1<<( 0+board)));
		printf("18A:\t 0x%04X\n",data[1]&(1<<(13+board)));
	}
}


void pcharb(uint8_t c){
  for(int i=0;i<8;i++) printf("%u",(c>>i)&1);
}


bool TB_t::ping(int board, uint16_t& boardID){
	struct mcu_packet packet;
	char buffer[2];
    packet.data=buffer;

	packet.len=0;
	uart485_select(UART485_0_BASE,SPI_BASE,board);

	uart485_write_packet(UART485_0_BASE,mcu_packet(MCUCMD_PING,0),0);
	int status=uart485_rcv_packet(UART485_0_BASE,packet,2,true);
	if((status>=0) && (packet.cmd==MCUCMD_ACK)){
	    boardID=*((uint16_t*)packet.data);
        return true;
    }
	boardID=0xffff;
	return false;
}

//write slow control pattern over SPI, returns 0 if readback value matches written, otherwise -1. Does not include CSn line switching.
int TB_t::spi_write_pattern(alt_u32 asic, const alt_u8* bitpattern) {
	char buffer[MUTRIG_CONFIG_LEN_BYTES];
	for(int i=0; i< MUTRIG_CONFIG_LEN_BYTES; i++) buffer[i]=bitpattern[MUTRIG_CONFIG_LEN_BYTES-1-i];

	uart485_select(UART485_0_BASE,SPI_BASE,asic);
	uart485_write_packet(UART485_0_BASE,mcu_packet(MCUCMD_CFG,MUTRIG_CONFIG_LEN_BYTES,(char*)buffer),0);
	uart485_rxclear(UART485_0_BASE);

	for(int i=0; i< MUTRIG_CONFIG_LEN_BYTES; i++) buffer[i]=0;
	struct mcu_packet packet;
	packet.data=buffer;
	auto status=uart485_rcv_packet(UART485_0_BASE,packet,100,true);
	printf("Config RCV status=%d\n",status);
	if (status < 0) return status;
	//printf("TX: "); mcu_packet(MCUCMD_CFG,MUTRIG_CONFIG_LEN_BYTES,(char*)bitpattern).print(MUTRIG_CONFIG_LEN_BYTES);
	//printf("RX: "); packet.print(100);
	return packet.data[0];
}



void TB_t::print_config(const alt_u8* bitpattern) {
    uint16_t nb=MUTRIG_CONFIG_LEN_BYTES;
    int i=0;
    printf("alt_u8 config[] = {\n");
    do {
        nb--;
        printf("%02X,",bitpattern[nb]);
	if(i==9){
          printf("\n");
	  i=-1;
	}
	i++;
    } while(nb>0);
    printf("}\n");
}



void TB_t::print_config_reverse(const alt_u8* bitpattern) {
    uint16_t nb=0;//MUTRIG_CONFIG_LEN_BYTES;
    int i=0;
    printf("alt_u8 config[] = {\n");
    do {
        printf("0x%02X,",bitpattern[nb]);
	if(i==9){
          printf("\n");
	  i=-1;
	}
	i++;
        nb++;
    } while(nb<=MUTRIG_CONFIG_LEN_BYTES);
    printf("}\n");
}


//configure ASIC
alt_u16 TB_t::configure_asic(alt_u32 asic, const alt_u8* bitpattern) {
    printf("[TB] chip_configure(%u) ", asic);
	if(!is_board_present(asic)){
        printf("--> SKIPPED\n");
		return FEB_REPLY_SUCCESS;
	}else{
        printf("--> CFG\n");
	}
    int ret;
    ret = spi_write_pattern(asic, bitpattern);
    ret = spi_write_pattern(asic, bitpattern);

	if(ret != 0) {
        printf("Configuration error\n");
        return FEB_REPLY_ERROR;
    }
	//print_config(bitpattern);
    return FEB_REPLY_SUCCESS;
}


//TODO: add list&document in specbook
//TODO: update functions
//Callback function called after receiving a command from the FEB slow control interface
alt_u16 TB_t::sc_callback(alt_u16 cmd, volatile alt_u32* data, alt_u16 n [[maybe_unused]]) {
	alt_u16 status=FEB_REPLY_SUCCESS;
	int asic = cmd & 0x000f;
	//printf("callback: %3.3x asic %1.1x\n",cmd & 0xfff0, asic);
	switch(cmd & 0xFFF0) {
    	case CMD_TILE_TMB_INIT:
			printf("initialize TB\n");
            if (!init_TB())
                status = FEB_REPLY_ERROR;
            printf("[cb] init --> %u\n",status);
            for(size_t i=0; i < sizeof(boardIDs) / sizeof(boardIDs[0]) ; i++)
                data[i] = boardIDs[i];
            break;
		case CMD_TILE_INJECTION_SETTING:
            status = setInject(asic);
			break;
    	case CMD_TILE_ASIC_PWR:
            printf("[cb] CMD_TILE_ASIC_PWR %x\n",data[0]);
            for(int asic=0 ; asic<nBoards; asic++){
	            auto value = (data[0]>>asic) & 0x01;
                if(power_ASIC(asic, value) != FEB_REPLY_SUCCESS){
                    status = FEB_REPLY_ERROR;
                }
	            usleep(1000);
	        }
            break;
        case CMD_TILE_ASIC_PWROR:
            //printf("[cb] CMD_TILE_ASIC_PWROR %x %x\n",data[0],data[1]);
	        for(int asic=0 ; asic<1; asic++){
                if(power_ASIC_AD(asic,  (data[0]>>asic) & 0x01, (data[1]>>asic) & 0x01) != FEB_REPLY_SUCCESS){
                    status = FEB_REPLY_ERROR;
                    printf("[cb] --> PWR-OR Error %d\n",asic);
                }
	        }
            break;
		case CMD_TILE_TEMPERATURES_READ:
			//printf("[cb] RD MatT\n");
			read_matrix_t(data);
        	break;

        case CMD_TILE_TEMPERATURES_READ_IDS:
			//printf("[cb] RD MatT_ID\n");
            read_matrix_ids(matrix_tmp_data);
	        for(size_t i=0; i < sizeof(matrix_tmp_data) / sizeof(matrix_tmp_data[0]) ; i++)
                data[i] = matrix_tmp_data[i];
            break;

        case CMD_TILE_POWERMONITORS_READ:
			//printf("[cb] RD Pwr\n");
			read_power(power_data);
	        for(size_t i=0; i < sizeof(power_data) / sizeof(power_data[0]) ; i++)
                data[i] = power_data[i];
            break;
		    break;

        case CMD_TILE_TMB_STATUS:
		//printf("[cb] RD Stat\n");
		read_tb_status(tb_status_data);
	        for(size_t i=0; i < sizeof(tb_status_data) / sizeof(tb_status_data[0]) ; i++)
                data[i] = tb_status_data[i];
		    break;

		case CMD_MUTRIG_ASIC_CFG:
			status=configure_asic(asic, (alt_u8*)data);
			break;
		default:
			printf("[sc_callback] unknown command\n");
			break;
	}
    return status;
}

void TB_t::periodic(){
/*
    static char ch = 0;
    switch(ch){
        case 0:
            printf("[bg] reading temperature sensors\n");
            read_matrix_t(matrix_tmp_data);
            break;
        case 1:
            printf("[bg] reading powermonitors\n");
            read_power(power_data);
            break;
        case 2:
            //printf("[bg] reading status of TMB\n");
            read_tmb_status(tmb_status_data);
            break;
    }
//    ch = (ch+1) % 3;
*/
}


void TB_t::menu_TB_main(){
//FEB    auto& regs = sc.ram->regs.TB;

    while(1) {

        printf("  [1] => init TBs\n");
        printf("  [2] => ASIC configuration\n");
        printf("  [6] => TB power menu\n");
        printf("  [4] => datapath status\n");
        printf("  [5] => TB status menu\n");
        printf("  [6] => monitor menu\n");
        printf("  [q] => exit\n");

        printf("Select entry ...\n");
        char cmd = wait_key();
        switch(cmd) {
        case '1':
            init_TB();
            break;
        case '2':
			menu_ASIC_config();
            break;
        case '3':
            menu_TB_pwr();
            break;
        case '4':
            printf("// not implemented\n");
//FEB            printf("buffer_full / frame_desync / rx_pll_lock : 0x%03X\n", regs.mon.status);
//FEB            printf("rx_dpa_lock / rx_ready : 0x%04X / 0x%04X\n", regs.mon.rx_dpa_lock, regs.mon.rx_ready);
            break;
        case '5':
            menu_TB_debug();
            break;
        case '6':
            menu_TB_monitors();
            break;

        case 'q':
            return;
        default:
            printf("invalid command: '%c'\n", cmd);
        }
    }
}
void TB_t::menu_TB_debug() {
    alt_u8 i =0;
    alt_u32 data[4];
    while(1) {
        printf("  [0] => ping\n");
        printf("  [1] => get status\n");
        printf("  [2] => get temperatures\n");
        printf("  [3] => get voltages\n",i);
        printf("  [i] => disable pulse injection\n");
        printf("  [I] => enable pulse injection\n");
        printf("  +-  => set board #\n");

        printf("  [q] => exit\n");

        printf("Select entry ...\n");
		uint16_t boardID;
        char cmd = wait_key();
        switch(cmd) {
        case '0':
			if(ping(i,boardID))
				printf("Ping (%u) ACK with BoardID=%x\n",i,boardID);
            else
				printf("Ping (%u) NACK with BoardID=%x\n",i);
            break;
        case '1':
			read_tb_status(data);
			print_tb_status(data);
            break;
        case '2':
			read_matrix_t(data);
			print_matrix_t(data);
            break;
        case '3':
			read_power(data);
			print_power(data);
            break;
        case 'I':
			setInject(true);
			break;
        case 'i':
			setInject(false);
	    break;

        case 'q':
            return;
		case '+':
			i = (i + 1) % nBoards;
			break;
		case '-':
			i = (i - 1) % nBoards;
			break;

        default:
            printf("invalid command: '%c'\n", cmd);
        }
    }
}

void TB_t::menu_TB_monitors() {
    while(1) {
        printf("  [0] => read power\n");
        printf("  [1] => read temperature\n");
        printf("  [2] => read status\n");
        printf("  [1] => read temperature IDs\n");
        printf("  [q] => exit\n");

        printf("Select entry ...\n");
        char cmd = wait_key();
        switch(cmd) {
        case '0':
            //read_power(power_data);
            //print_power(power_data);
            break;
        case '1':
            read_matrix_t(matrix_tmp_data);
            print_matrix_t(matrix_tmp_data);
            break;
        case '2':
            read_tb_status(tb_status_data);
            print_tb_status(tb_status_data);
            break;
        case '3':
            read_matrix_ids(matrix_tmp_data);
            print_matrix_t(matrix_tmp_data, true);
            break;
        case 'q':
            return;
        default:
            printf("invalid command: '%c'\n", cmd);
        }
    }
}

void TB_t::menu_TB_pwr(){

	static unsigned int i=0;
	static bool D=false;
	static bool A=false;
    alt_u32 status;
	while(1){
		printf("** TB ASIC POWER CONTROL **\n");
		printf("SELECTED POWER DOMAIN: %d:%c\n", i);
		printf("  [0] => turn off ASIC\n");
		printf("  [1] => turn on ASIC\n");
		printf("  [+] => increase ASIC id\n");
	       	printf("  [-] => decrease ASIC id\n");
		printf("  [D | d] => Digital on /off\n");
		printf("  [A | a] => Analog on /off\n");
		printf("  [c]     => Configure all off\n");
		printf("  [q] => exit\n");
		printf("Select entry ...\n");
		char cmd = wait_key();
		switch(cmd){
			case '0':
				power_ASIC(i,false);
				break;
			case '1':
				power_ASIC(i,true);
				break;
			case '+':
				i = (i + 1) % nBoards;
				break;
			case '-':
				i = (i - 1) % nBoards;
				break;
			case 'd':
				D=false;
				status=power_ASIC_AD(i,A,D);
				break;
			case 'D':
				D=true;
				status=power_ASIC_AD(i,A,D);
				break;
			case 'a':
				A=false;
				status=power_ASIC_AD(i,A,D);
				break;
			case 'A':
				A=true;
				status=power_ASIC_AD(i,A,D);
				break;
			case 'c':
				configure_asic(i,config_ALL_OFF);
				break;
			case 'q':
				return;
		}
//        if(status&0xff != 0xff)
//
            read_tb_status(tb_status_data);
            print_tb_status(tb_status_data);
	}
}


void TB_t::menu_ASIC_config(){
    static unsigned int i=0;
    while(1) {
        printf("** TB ASIC CONFIGURATION **\n");
        printf("CURRENTLY SELECTED ASIC: %d\n", i);
        printf("  [+] => increase ASIC id\n");
        printf("  [-] => decrease ASIC id\n");
        printf("  [1] => configure ALL_OFF\n");
        printf("  [2] => configure PRBS / Single\n");

        printf("  [q] => exit\n");

        printf("Select entry ...\n");
        char cmd = wait_key();
        switch(cmd) {
        case '1':
            //print_config_reverse(config_ALL_OFF);
            configure_asic(i,config_ALL_OFF);
            break;
        case '2':
            configure_asic(i,config_PRBS_single);
            break;
        case '+':
            i = (i + 1) % nBoards;
            break;
        case '-':
            i = (i - 1) % nBoards;
            break;
        case 'q':
            return;
        }
    }
}
