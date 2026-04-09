/**
 * open a mudaq device and measure DMA speed
 * use data generator from counter with 250 MHz clock
 *
 * @author      Dorothea vom Bruch <vombruch@physi.uni-heidelberg.de>
 *              adapted from code by Fabian Foerster and Qinhua Huang
 * @date        2015-01-22
 */

#include "mudaq_device.h"

#include <bitset>

#include <fcntl.h>
#include <sys/mman.h>
#include <chrono>
#include <list>

using namespace std::chrono;
using namespace std;

uint32_t read_counters(mudaq::DmaMudaqDevice & mu, uint32_t write_value, uint8_t link, uint8_t detector, uint8_t type, uint8_t treeLayer)
{
    // write_value: counter one wants to read
    // link:        addrs for link specific counters
    // detector:    for readout, 0=PIXEL US, 1=PIXEL DS, 2=SCIFI
    // type:        0=link, 1=datapath, 2=tree
    // layer:       layer of the tree 0, 1 or 2

    // debug readout counters
    //      bank_builder_idle_not_header
    //      bank_builder_skip_event_dma
    //      bank_builder_event_dma
    //      bank_builder_tag_fifo_full

    // counter range for each sub detector
    // 0 to 7:
    //      e_stream_fifo full
    //      e_debug_stream_fifo almost full
    //      0
    //      0
    //      0
    //      0
    //      events send to the farm
    //      e_debug_time_merger_fifo almost full
    // 8 to 3 * (1 + 2 + 4):
    //      tree layer0: 8 to 3 * 4
    //      tree layer1: 8 + 3 * 4 to 3 * 4 + 3 * 2
    //      tree layer2: 8 + 3 * 4 + 3 * 2 to 3 * 4 + 3 * 2 + 3 * 1
    //          layerN link output: # HEADER, SHEADER, HIT
    // 8 + 3 * (1 + 2 + 4) to 8 + 3 * (1 + 2 + 4) + NLINKS * 5:
    //      fifo almost_full
    //      fifo wrfull
    //      # of skip event
    //      # of events
    //      # of sub header

    // link counters
    if ( type == 0 ) {
        write_value += SWB_DATAPATH_CNT + SWB_TREE_CNT * (SWB_LAYER0_OUT_CNT + SWB_LAYER1_OUT_CNT + SWB_LAYER2_OUT_CNT) + link * SWB_LINK_CNT;
    // tree counters
    } else if ( type == 2 ) {
        uint32_t treeLinkOffset[3] = { 0, 4, 6 };
        write_value += SWB_DATAPATH_CNT + SWB_TREE_CNT * (treeLinkOffset[treeLayer] + link);
        //printf("write_value %d, link %d, treeLinkOffset[treeLayer] %d\n", write_value, link, treeLinkOffset[treeLayer]);
    }

    // readout detector
    if (type != 3) {
        uint32_t nLinks[2] = {0, 0};
        write_value += SWB_DEBUG_RO_CNT;
        for ( int i = 0; i < detector; i++ ) {
            //      offset: 8 for general counters   tree offset       link offset
            write_value += (8                      + 3 * (1 + 2 + 4) + nLinks[i] * 5);
        }
    }

    mu.write_register(SWB_COUNTER_REGISTER_W, write_value);
    return mu.read_register_ro(SWB_COUNTER_REGISTER_R);
}

void print_counters(mudaq::DmaMudaqDevice & mu, uint32_t bits, uint32_t detector)
{
    cout << "Detector " << detector << endl;
    cout << "bits " << bits << endl;
    cout << "Global Time 0x" << hex << mu.read_register_ro(GLOBAL_TS_LOW_REGISTER_R) << endl;
    cout << "DataPath counters" << endl;
    cout << "SWB_STREAM_FIFO_FULL_CNT: 0x" << hex << read_counters(mu, SWB_STREAM_FIFO_FULL_CNT, 0, detector, 1, 0) << endl;
    cout << "SWB_STREAM_DEBUG_FIFO_ALFULL_CNT: 0x" << hex << read_counters(mu, SWB_STREAM_DEBUG_FIFO_ALFULL_CNT, 0, detector, 1, 0) << endl;
    cout << "DUMMY: 0x" << hex << read_counters(mu, DUMMY_0_CNT, 0, detector, 1, 0) << endl;
    cout << "DUMMY: 0x" << hex << read_counters(mu, DUMMY_1_CNT, 0, detector, 1, 0) << endl;
    cout << "DUMMY: 0x" << hex << read_counters(mu, DUMMY_2_CNT, 0, detector, 1, 0) << endl;
    cout << "DUMMY: 0x" << hex << read_counters(mu, DUMMY_3_CNT, 0, detector, 1, 0) << endl;
    cout << "SWB_EVENTS_TO_FARM_CNT: 0x" << hex << read_counters(mu, SWB_EVENTS_TO_FARM_CNT, 0, detector, 1, 0) << endl;
    cout << "SWB_MERGER_DEBUG_FIFO_ALFULL_CNT: 0x" << hex << read_counters(mu, SWB_MERGER_DEBUG_FIFO_ALFULL_CNT, 0, detector, 1, 0) << endl;

    cout << "Link counters" << endl;
    cout << "------------------" << endl;
    for ( uint32_t i = 0; i < bits; i++ ) {
        cout << "SWB_LINK_FIFO_ALMOST_FULL_CNT: 0x" << hex << read_counters(mu, SWB_LINK_FIFO_ALMOST_FULL_CNT, i, detector, 0, 0) << endl;
        cout << "SWB_LINK_FIFO_FULL_CNT: 0x" << hex << read_counters(mu, SWB_LINK_FIFO_FULL_CNT, i, detector, 0, 0) << endl;
        cout << "SWB_SKIP_SORTER_PACKAGE_CNT: 0x" << hex << read_counters(mu, SWB_SKIP_SORTER_PACKAGE_CNT, i, detector, 0, 0) << endl;
        cout << "SWB_EVENT_CNT: 0x" << hex << read_counters(mu, SWB_EVENT_CNT, i, detector, 0, 0) << endl;
        cout << "SWB_SUB_HEADER_CNT: 0x" << hex << read_counters(mu, SWB_SUB_HEADER_CNT, i, detector, 0, 0) << endl;
        cout << "------------------" << endl;
    }

    cout << "Tree counters" << endl;
    uint32_t treeLayers[3] = { 4, 2, 1 };
    for ( uint32_t layer = 0; layer < 3; layer++ ) {
        cout << "Layer " << layer;
        for ( uint32_t link = 0; link < treeLayers[layer]; link++ ) {
            cout << " L" << link << ":";
            cout << " SOP 0x" << hex << read_counters(mu, SWB_MERGER_HEADER_CNT, link, detector, 2, layer) << "\t";
            cout << " SH 0x" << hex << read_counters(mu, SWB_MERGER_SHEADER_CNT, link, detector, 2, layer) << "\t";
            cout << " HIT 0x" << hex << read_counters(mu, SWB_MERGER_HIT_CNT, link, 0, 2, layer) << " |";
        }
        cout << endl;
    }

    cout << "Debug Readout Counters" << endl;
    cout << "SWB_BANK_BUILDER_IDLE_NOT_HEADER_CNT: 0x" << hex << read_counters(mu, SWB_BANK_BUILDER_IDLE_NOT_HEADER_CNT, 0, 0, 3, 0) << endl;
    cout << "SWB_BANK_BUILDER_SKIP_EVENT_CNT: 0x" << hex << read_counters(mu, SWB_BANK_BUILDER_SKIP_EVENT_CNT, 0, 0, 3, 0) << endl;
    cout << "SWB_BANK_BUILDER_EVENT_CNT: 0x" << hex << read_counters(mu, SWB_BANK_BUILDER_EVENT_CNT, 0, 0, 3, 0) << endl;
    cout << "SWB_BANK_BUILDER_TAG_FIFO_FULL_CNT: 0x" << hex << read_counters(mu, SWB_BANK_BUILDER_TAG_FIFO_FULL_CNT, 0, 0, 3, 0) << endl;

    cout << "Link/PLL Counters" << endl;
    cout << "TS:" << mu.read_register_ro(GLOBAL_TS_LOW_REGISTER_R) << endl;
    cout << "156 L:" << (mu.read_register_ro(CNT_PLL_156_REGISTER_R) >> 31) << endl;
    cout << "250 L:" << (mu.read_register_ro(CNT_PLL_250_REGISTER_R) >> 31) << endl;
    cout << "156 C:" << (mu.read_register_ro(CNT_PLL_156_REGISTER_R) & 0x7FFFFFFF) << endl;
    cout << "250 C:" << (mu.read_register_ro(CNT_PLL_250_REGISTER_R) & 0x7FFFFFFF) << endl;
    cout << "Links:" << std::bitset<32>(mu.read_register_ro(LINK_LOCKED_LOW_REGISTER_R)) << endl;
    cout << "Links:" << std::bitset<32>(mu.read_register_ro(LINK_LOCKED_HIGH_REGISTER_R)) << endl;
    cout << "MASKP:" << std::bitset<32>(mu .read_register_rw(SWB_LINK_MASK_PIXEL_REGISTER_W)) << endl;
    cout << "MASKS:" << std::bitset<32>(mu .read_register_rw(SWB_LINK_MASK_SCIFI_REGISTER_W)) << endl;
    cout << "MASKG:" << std::bitset<32>(mu .read_register_rw(SWB_GENERIC_MASK_REGISTER_W)) << endl;

}

#define PRINTREG(reg) {auto val = mu.read_register_rw(reg); cout << #reg ": " << std::hex << val << "  " << std::bitset<32>(val) << endl;};

uint32_t cntBits(uint32_t n) {
    uint32_t count = 0;
    while (n) {
        count += n & 1;
        n >>= 1;
    }
    return count;
}

void print_usage() {
    cout << "Usage: " << endl;
    cout << "       dmatest <readout mode> <stop dma> <readout words> <link mask> <use pixel> <get counters>" << endl;
    cout << " readout mode: 0 = use stream merger to readout links" << endl;
    cout << " readout mode: 2 = use stream merger to readout datagen" << endl;
    cout << " readout mode: 3 = use time merger to readout datagen" << endl;
    cout << " readout mode: 4 = use time merger to readout links" << endl;
    cout << " stop DMA: 0 = no effect" << endl;
    cout << " stop DMA: 1 = reset FPGA and stop DMA" << endl;
    cout << " readout words: 0 = readout half of DMA buffer" << endl;
    cout << " readout words: 1 = dump DMA readout with time stop" << endl;
    cout << " link mask: 0xFFFF mask links (one is use this link)" << endl;
    cout << " 0: pixel ds, 1: pixel us, 2: scifi, 3: farm, 4: SWB readout Scifi/Pixel, 5: generic" << endl;
    cout << " 0: normal mode, 1: counter only mode / read back registers only mode" << endl;
}

int main(int argc, char *argv[]) {
    if(argc < 7) {
        print_usage();
        return -1;
    }
    
    if(atoi(argv[2]) == 1) {
        /* Open mudaq device */
        mudaq::DmaMudaqDevice mu("/dev/mudaq0");
        if ( !mu.open() ) {
            cout << "Could not open device " << endl;
            return -1;
        }

        mu.disable();
        mu.write_register(DATAGENERATOR_DIVIDER_REGISTER_W, 0x0);
        mu.write_register(SWB_READOUT_STATE_REGISTER_W, 0x0);
        mu.write_register(FARM_READOUT_STATE_REGISTER_W, 0x0);
        mu.write_register(DATAGENERATOR_DIVIDER_REGISTER_W, 0x0);
        mu.write_register(SWB_LINK_MASK_PIXEL_REGISTER_W, 0x0);
        mu.write_register(SWB_READOUT_LINK_REGISTER_W, 0x0);
        mu.write_register(GET_N_DMA_WORDS_REGISTER_W, 0x0);
        mu.close();
        return 0;
    }

    uint32_t detector = 0;
    if (atoi(argv[5]) == 0) detector = 0;
    if (atoi(argv[5]) == 1) detector = 1;
    if (atoi(argv[5]) == 2) detector = 2;
    if (atoi(argv[5]) == 4) detector = 3;
    if (atoi(argv[5]) == 5) detector = 0;

    char cmd;
    size_t dma_buf_size = MUDAQ_DMABUF_DATA_LEN;
    volatile uint32_t *dma_buf;
    size_t size = MUDAQ_DMABUF_DATA_LEN;
    uint32_t dma_buf_nwords = dma_buf_size/sizeof(uint32_t);

/*    cudaError_t cuda_error = cudaMallocHost( (void**)&dma_buf, size );
    if(cuda_error != cudaSuccess){
        cout << "Error: " << cudaGetErrorString(cuda_error) << endl;
        cout << "Allocation failed!" << endl;
        return -1;
    }*/

    int fd = open("/dev/mudaq0_dmabuf", O_RDWR);
    if(fd < 0) {
        printf("fd = %d\n", fd);
        return EXIT_FAILURE;
    }
    dma_buf = (uint32_t*)mmap(nullptr, MUDAQ_DMABUF_DATA_LEN, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if(dma_buf == MAP_FAILED) {
        printf("mmap failed: dmabuf = MAP_FAILED\n");
        return EXIT_FAILURE;
    }

    // initialize to zero
    for(size_t i = 0; i < size/sizeof(uint32_t); i++) {
        dma_buf[i] = 0;
    }

    /* Open mudaq device */
    mudaq::DmaMudaqDevice mu("/dev/mudaq0");
    if ( !mu.open() ) {
        cout << "Could not open device " << endl;
        return -1;
    }

    if ( !mu.is_ok() ) return -1;
    cout << "MuDaq is ok" << endl;

    /* map memory to bus addresses for FPGA */
    int ret_val = 0;
    if ( ret_val < 0 ) {
        cout << "Mapping failed " << endl;
        mu.disable();
        mu.close();
        free( (void *)dma_buf );
        return ret_val;
    }

    // get counter
    if (atoi(argv[6]) == 1) {
        while (1) {
            printf("  [1] => readout counters \n");
            printf("  [2] => print regs \n");
            printf("  [3] => print links regs \n");
            printf("  [q] => return \n");
            cout << "Select entry ...";
            cin >> cmd;
            switch(cmd) {
            case '1':
                if ( detector != 3) print_counters(mu, 5, detector);
                if ( detector == 3) for ( int i = 0; i < 2; i++ ) print_counters(mu, 5, i);
                break;
            case '2':
                PRINTREG(RESET_REGISTER_W)
                PRINTREG(DATAGENERATOR_DIVIDER_REGISTER_W);
                PRINTREG(GET_N_DMA_WORDS_REGISTER_W);

                PRINTREG(SWB_READOUT_LINK_REGISTER_W);
                PRINTREG(SWB_LINK_MASK_PIXEL_REGISTER_W);
                PRINTREG(SWB_LINK_MASK_SCIFI_REGISTER_W)
                PRINTREG(SWB_GENERIC_MASK_REGISTER_W)
                PRINTREG(FARM_LINK_MASK_REGISTER_W)

                PRINTREG(SWB_READOUT_STATE_REGISTER_W);
                PRINTREG(FARM_READOUT_STATE_REGISTER_W);

                break;
            case '3': {
                // get link values
                int allmost_full = 0;
                int full = 0;
                int skip = 0;
                int evnt = 0;
                int subh = 0;
                int fullsubhoverflow = 0;
                int skiphits = 0;
                int skipsubheader = 0;
                int tsoverflow = 0;
                for ( uint32_t i = 0; i < 8; i++ ) {
                    mu.write_register(SWB_COUNTER_REGISTER_W, i*13+0);
                    allmost_full += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                    mu.write_register(SWB_COUNTER_REGISTER_W, i*13+1);
                    full += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                    mu.write_register(SWB_COUNTER_REGISTER_W, i*13+2);
                    skip += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                    mu.write_register(SWB_COUNTER_REGISTER_W, i*13+3);
                    evnt += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                    mu.write_register(SWB_COUNTER_REGISTER_W, i*13+4);
                    subh += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                    mu.write_register(SWB_COUNTER_REGISTER_W, i*13+5);
                    fullsubhoverflow += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                    mu.write_register(SWB_COUNTER_REGISTER_W, i*13+6);
                    skiphits += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                    mu.write_register(SWB_COUNTER_REGISTER_W, i*13+7);
                    skipsubheader += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                    mu.write_register(SWB_COUNTER_REGISTER_W, i*13+8);
                    tsoverflow += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);
                }
                cout << "allmost_full 0x" << hex << allmost_full << endl;
                cout << "full 0x" << hex << full << endl;
                cout << "skip 0x" << hex << skip << endl;
                cout << "evnt 0x" << hex << evnt << endl;
                cout << "subh 0x" << hex << subh << endl;
                cout << "fullsubhoverflow 0x" << hex << fullsubhoverflow << endl;
                cout << "skiphits 0x" << hex << skiphits << endl;
                cout << "skipsubheader 0x" << hex << skipsubheader << endl;
                cout << "tsoverflow 0x" << hex << tsoverflow << endl;
                break;
            }
            default:
                printf("invalid command: '%c'\n", cmd);
            }
        }
    }

    // reset all
    uint32_t reset_regs = 0;
    reset_regs = SET_RESET_BIT_DATA_PATH(reset_regs);
    reset_regs = SET_RESET_BIT_FARM_BLOCK(reset_regs);
    reset_regs = SET_RESET_BIT_DATAGEN(reset_regs);
    reset_regs = SET_RESET_BIT_SWB_STREAM_MERGER(reset_regs);
    reset_regs = SET_RESET_BIT_FARM_STREAM_MERGER(reset_regs);
    reset_regs = SET_RESET_BIT_SWB_TIME_MERGER(reset_regs);
    reset_regs = SET_RESET_BIT_FARM_TIME_MERGER(reset_regs);
    reset_regs = SET_RESET_BIT_LINK_LOCKED(reset_regs);
    cout << "Reset Regs: " << hex << reset_regs << endl;
    mu.write_register(RESET_REGISTER_W, reset_regs);

    // request data to read dma_buffer_size/2 (count in blocks of 256 bits)
    uint32_t max_requested_words = 0x80000;
    cout << "request " << max_requested_words << endl;
    mu.write_register(GET_N_DMA_WORDS_REGISTER_W, max_requested_words);

    // setup datagen
    mu.write_register(DATAGENERATOR_DIVIDER_REGISTER_W, 0x10);

    uint32_t mask_n_add;
    if (atoi(argv[5]) == 0) mask_n_add = SWB_LINK_MASK_PIXEL_REGISTER_W;
    if (atoi(argv[5]) == 1) mask_n_add = SWB_LINK_MASK_PIXEL_REGISTER_W;
    if (atoi(argv[5]) == 2) mask_n_add = SWB_LINK_MASK_SCIFI_REGISTER_W;
    if (atoi(argv[5]) == 3) mask_n_add = FARM_LINK_MASK_REGISTER_W;
    if (atoi(argv[5]) == 5) mask_n_add = SWB_GENERIC_MASK_REGISTER_W;
    /*uint32_t set_pixel;
    if (atoi(argv[5]) == 1) set_pixel = 0;
    if (atoi(argv[5]) == 0) set_pixel = 1;*/

    uint32_t readout_state_regs = 0;
    if (atoi(argv[5]) == 0) readout_state_regs = SET_USE_BIT_PIXEL_DS(readout_state_regs);
    if (atoi(argv[5]) == 1) readout_state_regs = SET_USE_BIT_PIXEL_US(readout_state_regs);
    if (atoi(argv[5]) == 2) readout_state_regs = SET_USE_BIT_SCIFI(readout_state_regs);
    if (atoi(argv[5]) == 4) readout_state_regs = SET_USE_BIT_ALL(readout_state_regs);
    if (atoi(argv[5]) == 5) readout_state_regs = SET_USE_BIT_GENERIC(readout_state_regs);
    if (atoi(argv[5]) == 5) readout_state_regs = SET_USE_BIT_ALL(readout_state_regs);

    // set mask bits
    if (atoi(argv[5]) == 4) mu.write_register(SWB_LINK_MASK_PIXEL_REGISTER_W, strtol(argv[4], NULL, 16));
    if (atoi(argv[5]) == 4) mu.write_register(SWB_LINK_MASK_SCIFI_REGISTER_W, strtol(argv[4], NULL, 16));
    if (atoi(argv[5]) != 4) mu.write_register(mask_n_add, strtol(argv[4], NULL, 16));
    // use stream merger
    if ( atoi(argv[1]) == 0 or atoi(argv[1]) == 2 ) readout_state_regs = SET_USE_BIT_STREAM(readout_state_regs);
    // use datagen
    if ( atoi(argv[1]) == 2 or atoi(argv[1]) == 3 ) readout_state_regs = SET_USE_BIT_GEN_LINK(readout_state_regs);
    // use time merger
    if ( atoi(argv[1]) == 4 or atoi(argv[1]) == 3 ) readout_state_regs = SET_USE_BIT_MERGER(readout_state_regs);
    // write regs
    mu.write_register(SWB_READOUT_STATE_REGISTER_W, readout_state_regs);
    mu.write_register(FARM_READOUT_STATE_REGISTER_W, readout_state_regs);

    PRINTREG(RESET_REGISTER_W)
    PRINTREG(DATAGENERATOR_DIVIDER_REGISTER_W);
    PRINTREG(GET_N_DMA_WORDS_REGISTER_W);

    PRINTREG(SWB_READOUT_LINK_REGISTER_W);
    PRINTREG(SWB_LINK_MASK_PIXEL_REGISTER_W);
    PRINTREG(SWB_LINK_MASK_SCIFI_REGISTER_W)
    PRINTREG(SWB_GENERIC_MASK_REGISTER_W)
    PRINTREG(FARM_LINK_MASK_REGISTER_W)

    PRINTREG(SWB_READOUT_STATE_REGISTER_W);
    PRINTREG(FARM_READOUT_STATE_REGISTER_W);


    while (1) {
        cout << hex << readout_state_regs << endl;
        printf("  [1] => trigger a readout \n");
        printf("  [2] => readout counters \n");
        printf("  [3] => reset stuff \n");
        printf("  [4] => test speed \n");
        printf("  [5] => reset counters \n");
        printf("  [q] => return \n");
        cout << "Select entry ...";
        cin >> cmd;
        switch(cmd) {
        case '1': {

            usleep(10);
            mu.write_register(RESET_REGISTER_W, 0x0);

            // start dma
            mu.enable_continous_readout(0);
            if (atoi(argv[3]) == 1) {
                // wait for requested data
                while ( (mu.read_register_ro(EVENT_BUILD_STATUS_REGISTER_R) & 1) == 0 ) { }
            }

            if ( atoi(argv[3]) != 1) {
                for ( int i = 0; i < 3; i++ ) {
                    cout << "sleep " << i << "/3 s" << endl;
                    sleep(i);
                }
            }
            // stop dma
            mu.disable();

            for(int i=0; i < 20; i++)
                cout << hex << "0x" <<  dma_buf[i] << " ";
            cout << endl;

            uint32_t size_dma_buf = mu.last_endofevent_addr() * 256 / 8;
            uint32_t maxidx = (mu.last_endofevent_addr()+1)*8;
            uint32_t last_written = mu.last_written_addr();
            uint32_t maxwords = max_requested_words;
            printf("last_written_addr: 0x%08x\nlast_endofevent_addr: 0x%08x\nmaxidx: 0x%08x\n0x%08x 0x%08x 0x%08x\n", mu.last_written_addr(), mu.last_endofevent_addr(), maxidx, size_dma_buf, maxwords, maxwords*8);

            std::cout << std::endl;
            for(int i=-20; i < 20; i++)
                std::cout << std::hex << maxwords*8+i << std::hex << maxidx+i << " 0x" <<  dma_buf[maxidx+i] << std::endl;

            break;
        }
        case '2': {

            usleep(10);
            mu.write_register(RESET_REGISTER_W, 0x0);

            //cout << "Last Word in buffer: 0x" << hex << dma_buf[mu.last_endofevent_addr() * 8 - 1] << endl;
            if ( detector == 4) print_counters(mu, 8, detector);
            if ( detector != 3 and detector != 4) print_counters(mu, 2, detector);
            if ( detector == 3) for ( int i = 0; i < 2; i++ ) print_counters(mu, 5, i);

            // get link values
            int allmost_full = 0;
            int full = 0;
            int skip = 0;
            int evnt = 0;
            int subh = 0;
            int fullsubhoverflow = 0;
            int skiphits = 0;
            int skipsubheader = 0;
            int tsoverflow = 0;
            for ( uint32_t i = 0; i < 8; i++ ) {
                mu.write_register(SWB_COUNTER_REGISTER_W, i*13+0);
                allmost_full += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                mu.write_register(SWB_COUNTER_REGISTER_W, i*13+1);
                full += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                mu.write_register(SWB_COUNTER_REGISTER_W, i*13+2);
                skip += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                mu.write_register(SWB_COUNTER_REGISTER_W, i*13+3);
                evnt += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                mu.write_register(SWB_COUNTER_REGISTER_W, i*13+4);
                subh += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                mu.write_register(SWB_COUNTER_REGISTER_W, i*13+5);
                fullsubhoverflow += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                mu.write_register(SWB_COUNTER_REGISTER_W, i*13+6);
                skiphits += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                mu.write_register(SWB_COUNTER_REGISTER_W, i*13+7);
                skipsubheader += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                mu.write_register(SWB_COUNTER_REGISTER_W, i*13+8);
                tsoverflow += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);
            }
            cout << "allmost_full 0x" << hex << allmost_full << endl;
            cout << "full 0x" << hex << full << endl;
            cout << "skip 0x" << hex << skip << endl;
            cout << "evnt 0x" << hex << evnt << endl;
            cout << "subh 0x" << hex << subh << endl;
            cout << "fullsubhoverflow 0x" << hex << fullsubhoverflow << endl;
            cout << "skiphits 0x" << hex << skiphits << endl;
            cout << "skipsubheader 0x" << hex << skipsubheader << endl;
            cout << "tsoverflow 0x" << hex << tsoverflow << endl;
            break;
        }
        case '3': {
            mu.write_register(RESET_REGISTER_W, reset_regs);
            usleep(10);
            if ( detector != 3) print_counters(mu, 2, detector);
            if ( detector == 3) for ( int i = 0; i < 2; i++ ) print_counters(mu, 5, i);
            mu.write_register(RESET_REGISTER_W, 0x0);
            break;
        }
        case '4': {

            // output data
            auto fout = fopen("speed_test.csv", "w");

            reset_regs = SET_RESET_BIT_DATA_PATH(reset_regs);

            fprintf(fout, "time,#max_hits;num_hits_per_package;maskLinkValue;#hits0;#hits1;#hits2;#hits3;#MUX;MUX-rate;#DMA-hit;#DMA-hit-rate;#DMA-skip;#DMA-full\n");

            for ( int max_words = max_requested_words; max_words < 2*max_requested_words;) {
                mu.write_register(GET_N_DMA_WORDS_REGISTER_W, max_words);
                list<int> link_list;
                link_list.push_back(1);
                link_list.push_back(3);
                link_list.push_back(7);
                link_list.push_back(15);
                for ( int link : link_list ) {
                    // write number of links
                    mu.write_register(mask_n_add, link);
                    //mu.write_register(SWB_READOUT_STATE_REGISTER_W, readout_state_regs);
                    for ( int i = 1; i < 2*(2000-128-1-5); ) {
                        // setup datagen
                        mu.write_register(DATAGENERATOR_DIVIDER_REGISTER_W, i);

                        // reset the statemachines
                        mu.write_register(RESET_REGISTER_W, reset_regs);
                        usleep(10);
                        mu.write_register(RESET_REGISTER_W, 0x0);

                        // loop 10 times to get some stats
                        auto start = high_resolution_clock::now();
                        for ( int k = 0; k < 10; k++ ) {
                            // start dma
                            mu.enable_continous_readout(0);

                            while ( (mu.read_register_ro(EVENT_BUILD_STATUS_REGISTER_R) & 1) == 0 ) { }
                            // stop dma
                            mu.disable();
                        }
                        //mu.write_register(SWB_READOUT_STATE_REGISTER_W, 0x0);
                        uint32_t time = duration_cast<microseconds>(high_resolution_clock::now() - start).count() / 10;

                        // get DMA values
                        uint32_t dma_skip = mu.read_register_ro(EVENT_BUILD_SKIP_EVENT_DMA_R) * 4 / 10;
                        uint32_t dma_full = mu.read_register_ro(BUFFER_STATUS_REGISTER_R) / 10;
                        // sleep 1s to the the rate
                        // sleep(1);
                        uint32_t dma_rate = mu.read_register_ro(EVENT_BUILD_TAG_FIFO_FULL_R) * 4;
                        uint32_t dma_cnt = mu.read_register_ro(EVENT_BUILD_IDLE_NOT_HEADER_R) * 4 / 10;

                        // get link hits
                        mu.write_register(SWB_COUNTER_REGISTER_W, 4);
                        uint32_t hits0_cnt = mu.read_register_ro(SWB_COUNTER_REGISTER_R) / 10;
                        mu.write_register(SWB_COUNTER_REGISTER_W, 5);
                        uint32_t hits1_cnt = mu.read_register_ro(SWB_COUNTER_REGISTER_R) / 10;
                        mu.write_register(SWB_COUNTER_REGISTER_W, 6);
                        uint32_t hits2_cnt = mu.read_register_ro(SWB_COUNTER_REGISTER_R) / 10;
                        mu.write_register(SWB_COUNTER_REGISTER_W, 7);
                        uint32_t hits3_cnt = mu.read_register_ro(SWB_COUNTER_REGISTER_R) / 10;

                        mu.write_register(SWB_COUNTER_REGISTER_W, 8);
                        uint32_t pkg_cnt = mu.read_register_ro(SWB_COUNTER_REGISTER_R) / 10;
                        printf("%i\n", pkg_cnt);

                        mu.write_register(SWB_COUNTER_REGISTER_W, 12);
                        uint32_t mux_cnt = mu.read_register_ro(SWB_COUNTER_REGISTER_R) * 4 / 10;
                        uint32_t mux_rate = mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R) * 4;

                        fprintf(fout, "%u;%u;%u;%u;%u;%u;%u;%u;%u;%u;%u;%u;%u;%u\n", time, max_words*4, i, link, hits0_cnt, hits1_cnt, hits2_cnt, hits3_cnt, mux_cnt, mux_rate, dma_cnt, dma_rate, dma_skip, dma_full);
                        printf("TS:%u[us] max_hits:%u drop-ratio:%f #Hits:%u LinkMask:%u\nhits0:%u hits1:%u hits2:%u hits3:%u\nMUX:%u MUX-rate:%u[kHz]\nDMA:%u DMA-rate:%ukHz DMA-skip:%u DMA-full:%u\n\n", time, max_words*4, (float) dma_skip/(dma_cnt+dma_skip), i, link, hits0_cnt, hits1_cnt, hits2_cnt, hits3_cnt, mux_cnt, mux_rate/1000, dma_cnt, dma_rate/1000, dma_skip, dma_full);

                        if ((float) dma_skip/(dma_cnt+dma_skip) > 0.1) break;

                        i += 10;
                    }
                }
                max_words += 0x10000;
            }
            fclose(fout);
            break;
        }
        case '5': {
            uint32_t reset_regs = 0;
            reset_regs = SET_RESET_BIT_SWB_COUNTERS(reset_regs);
            mu.write_register(RESET_REGISTER_W, reset_regs);
            usleep(10);
            mu.write_register(RESET_REGISTER_W, 0x0);
            // get link values
            int allmost_full = 0;
            int full = 0;
            int skip = 0;
            int evnt = 0;
            int subh = 0;
            int fullsubhoverflow = 0;
            int skiphits = 0;
            int skipsubheader = 0;
            int tsoverflow = 0;
            for ( uint32_t i = 0; i < 8; i++ ) {
                mu.write_register(SWB_COUNTER_REGISTER_W, i*13+0);
                allmost_full += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                mu.write_register(SWB_COUNTER_REGISTER_W, i*13+1);
                full += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                mu.write_register(SWB_COUNTER_REGISTER_W, i*13+2);
                skip += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                mu.write_register(SWB_COUNTER_REGISTER_W, i*13+3);
                evnt += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                mu.write_register(SWB_COUNTER_REGISTER_W, i*13+4);
                subh += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                mu.write_register(SWB_COUNTER_REGISTER_W, i*13+5);
                fullsubhoverflow += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                mu.write_register(SWB_COUNTER_REGISTER_W, i*13+6);
                skiphits += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                mu.write_register(SWB_COUNTER_REGISTER_W, i*13+7);
                skipsubheader += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);

                mu.write_register(SWB_COUNTER_REGISTER_W, i*13+8);
                tsoverflow += mu.read_register_ro(SWB_LINK_COUNTER_REGISTER_R);
            }
            cout << "allmost_full 0x" << hex << allmost_full << endl;
            cout << "full 0x" << hex << full << endl;
            cout << "skip 0x" << hex << skip << endl;
            cout << "evnt 0x" << hex << evnt << endl;
            cout << "subh 0x" << hex << subh << endl;
            cout << "fullsubhoverflow 0x" << hex << fullsubhoverflow << endl;
            cout << "skiphits 0x" << hex << skiphits << endl;
            cout << "skipsubheader 0x" << hex << skipsubheader << endl;
            cout << "tsoverflow 0x" << hex << tsoverflow << endl;
            break;
        }
        case 'q': {
            goto exit_loop;
        }
        default: {
            printf("invalid command: '%c'\n", cmd);
        }
        }
    }
    exit_loop: ;

    cout << "start to write file" << endl;

    // stop dma
    mu.disable();
    // stop readout
    mu.write_register(RESET_REGISTER_W, reset_regs);
    mu.write_register(DATAGENERATOR_DIVIDER_REGISTER_W, 0x0);
    mu.write_register(SWB_READOUT_STATE_REGISTER_W, 0x0);
    mu.write_register(FARM_READOUT_STATE_REGISTER_W, 0x0);
    mu.write_register(SWB_LINK_MASK_PIXEL_REGISTER_W, 0x0);
    mu.write_register(SWB_READOUT_LINK_REGISTER_W, 0x0);
    mu.write_register(GET_N_DMA_WORDS_REGISTER_W, 0x0);

    // output data
    auto fout = fopen("memory_content.txt", "w");
    for(size_t j = 0; j < size/sizeof(uint32_t); j++) {
        fprintf(fout, "%ld\t%08X\n", j, dma_buf[j]);
    }
    fclose(fout);

    mu.close();

    return 0;
}
