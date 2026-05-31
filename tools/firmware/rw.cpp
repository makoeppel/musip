/**
 * open a mudaq device and measure DMA speed
 * use data generator from counter with 250 MHz clock
 *
 * @author      Dorothea vom Bruch <vombruch@physi.uni-heidelberg.de>
 *              adapted from code by Fabian Foerster and Qinhua Huang
 * @date        2015-01-22
 */

#include <iostream>
#include <unistd.h>
#include <chrono>
#include <stdio.h>
#include <sstream>
#include <limits>
#include <fstream>
#include <sys/mman.h>

#include <cassert>




#include "mudaq_device.h"

using namespace std;

void print_usage(){
    cout << "Usage: " << endl;
    cout << "       rw rr <addr> for reading read register at addr" << endl;
    cout << "       rw rm <addr> for reading read memory at addr" << endl;
    cout << "       rw wr <addr> for reading write register at addr" << endl;
    cout << "       rw wm <addr> for reading write memory at addr" << endl;
    cout << "       rw wwr <addr> <value> for writing write register at addr" << endl;
    cout << "       rw wwm <addr> <value> for writing write memory at addr" << endl;
    cout << "       rw t <None> for test sc on addr 0xA" << endl;

}

constexpr unsigned int str2int(const char* str, int h = 0)
{
    return !str[h] ? 5381 : (str2int(str, h+1) * 33) ^ str[h];
}

int main(int argc, char * argv[])
{
    if(argc < 3){
        print_usage();
        return -1;
    }

    char * command = argv[1];

    char * addrs = argv[2];

    unsigned int addr  = strtol( addrs, 0,0);

    /* Open mudaq device */
    mudaq::DmaMudaqDevice mu("/dev/mudaq0");
    if ( !mu.open() ) {
        cout << "Could not open device " << endl;
        return -1;
    }
    if ( !mu.is_ok() ) return -1;

    unsigned int value;

    switch (str2int(command))
    {
        case str2int("rr"):
            //        if(addr > 63){
            //            cout << "Invalid register address " << addr << endl;
            //            break;
            //        }
            cout << hex << "0x" << mu.read_register_ro(addr) << endl;
            break;
        case str2int("rm"):
            //        if(addr > 64*1024){
            //            cout << "Invalid memory address " << addr << endl;
            //            break;
            //        }
            cout << hex << "0x" << mu.read_memory_ro(addr) << endl;
            break;
        case str2int("wr"):
            //        if(addr > 63){
            //            cout << "Invalid register address " << addr << endl;
            //            break;
            //        }
            cout << hex << "0x" << mu.read_register_rw(addr) << endl;
            break;
        case str2int("wm"):
            //        if(addr > 64*1024-1){
            //            cout << "Invalid memory address " << addr << endl;
            //            break;
            //        }
            cout << hex << "0x" << mu.read_memory_rw(addr) << endl;
            break;
        case str2int("wwr"):
            if(argc < 4){
                cout << "Too few arguments" << endl;
                break;
            }
            //        if(addr > 63){
            //            cout << "Invalid register address " << addr << endl;
            //            break;
            //        }
            value  = strtol(argv[3], 0,0);
            mu.write_register(addr, value);
            cout << hex << "0x" << mu.read_register_rw(addr) << endl;
            break;
        case str2int("wwm"):
            if(argc < 4){
                cout << "Too few arguments" << endl;
                break;
            }
            if(addr > 64*1024-1){
                cout << "Invalid memory address " << addr << endl;
                break;
            }
            value  = strtol(argv[3], 0,0);
            mu.write_memory_rw(addr, value);
            cout << hex << "0x" << mu.read_memory_rw(addr) << endl;
            break;
        case str2int("t"):

            // reset FPGA
            mu.write_register_wait(RESET_REGISTER_W, 0x0, 100);
            mu.write_register_wait(RESET_REGISTER_W, 0x1, 100);
            mu.write_register_wait(RESET_REGISTER_W, 0x0, 100);

            // wait for stateout 2 of SC secondary
            while ( (mu.read_register_ro(SC_STATE_REGISTER_R) & 0x20000000) != 0x20000000 ) {
//                cout << hex << mu.read_register_ro(SC_STATE_REGISTER_R) << " 0x20000000" << endl;
                continue;
            }
            cout << "State: " << hex << mu.read_register_ro(SC_STATE_REGISTER_R) << endl;
            cout << "Last addr reg: " << hex << mu.read_register_ro(MEM_WRITEADDR_LOW_REGISTER_R) << endl;

            mu.write_register_wait(FEB_ENABLE_REGISTER_W, 0x400, 100);

            cout << "Write 0x1CFEB" << addr << "BC to wmem" << endl;
            cout << "Write addr 0xA to wmem" << endl;
            cout << "Write length 0x1 to wmem" << endl;
            cout << "Write 0x0000009C to wmem" << endl;

            for ( int i = 0; i < 5; i++ ) {
                cout << "Last addr reg: " << hex << mu.read_register_ro(MEM_WRITEADDR_LOW_REGISTER_R) << endl;
                usleep(1);
                cout << "State: " << hex << mu.read_register_ro(SC_STATE_REGISTER_R) << endl;
                cout << "State: " << hex << mu.read_register_ro(SC_STATE_REGISTER_R) << endl;
                usleep(1);

                mu.write_memory_rw(0, 0x1DFEBABC);
                mu.write_memory_rw(1, i);
                //mu.write_memory_rw(2, 0x2);
                mu.write_memory_rw(2, 0x1);
                //mu.write_memory_rw(3, 0x1);
                mu.write_memory_rw(3, 0x9C);

                // SC_MAIN_LENGTH_REGISTER_W starts from 1
                // length for SC Main does not include preamble and trailer, thats why it is 2
                mu.write_register(SC_MAIN_LENGTH_REGISTER_W, 2);
                // toggle enable register
                mu.write_register_wait(SC_MAIN_ENABLE_REGISTER_W, 0x0, 100);
                mu.write_register_wait(SC_MAIN_ENABLE_REGISTER_W, 0x1, 100);
                mu.write_register_wait(SC_MAIN_ENABLE_REGISTER_W, 0x0, 100);
                sleep(2);
                cout << "///////////////////" << endl;
                for ( int k = 0; k < 5; k++ ) {
                    for ( int j = 0; j < 5; j++ ) {
                        cout << "Addr: 0x" << hex << j+k*5 << " 0x" << mu.read_memory_ro(j+k*5) << " | ";
                    }
                    cout << endl;
                }
                cout << "///////////////////" << endl;
            }
            break;
        default:
                cout << "Unknown command" << endl;
                print_usage();
                break;
    }

    mu.close();

  return 0;
}
