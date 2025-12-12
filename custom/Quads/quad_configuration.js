// Constants:

const alignment = [[0,0], [1,0], [0,1], [1,1]];

// Normal
const sensor_ids = [[0,1, 2,3], [4,5, 6,7], [8,9, 10,11], [12,13, 14,15]];

// Normal
const conf_ids = [0,1,2,3, 4,5,6,7, 8,9,10,11, 12,13,14,15];
const data_ids = [0,1,2,3, 4,5,6,7, 8,9,10,11, 12,13,14,15];

const sensor_links = [[[0, 0],[0, 1],[0, 2],[0, 3]],
                      [[0, 4],[0, 5],[0, 6],[0, 7]],
                      [[1, 8],[1, 9],[1,10],[1,11]],
                      [[1,12],[1,13],[0,14],[0,15]]]

const hexColors = [
    "#00008f", // Dark Blue
    "#00eeff", // turquis
    "#8fff6f", // Green
    "#ffff00", // Yellow
    "#ff9900", // Orange
    "#FF0000", // Red
    "#890000"  // Dark Red Magenta
]

const Mupix_DACs = {
    "BIASDACS" : {
        "PLL" : {
            "VNVCO" :       {"std" : [23, 17, 13],    "exp" : false},
            "VPVCO" :       {"std" : [22, 16, 12],    "exp" : false},

            "VNTimerDel" :  {"std" : 20,    "exp" : true},
            "VPTimerDel":   {"std" : [4,5,6],"exp" : false},
            "VPPump" :      {"std" : 30,    "exp" : true},
            "VNLVDSDel" :   {"std" : 0,     "exp" : true},
            "VNLVDS" :      {"std" : 16,    "exp" : true},
            "VPDcl" :       {"std" : 30,    "exp" : true},
            "VNDelPreEmp" : {"std" : 32,    "exp" : true},
            "VPDelPreEmp" : {"std" : 32,    "exp" : true},
            "VNDcl" :       {"std" : 10,    "exp" : true},
            "VNDelDcl" :    {"std" : 32,    "exp" : true},
            "VPDelDcl" :    {"std" : 32,    "exp" : true},
            "VNDelDclMux" : {"std" : 32,    "exp" : true},
            "VPDelDclMux" : {"std" : 32,    "exp" : true},
            "VNDel" :       {"std" : 10,    "exp" : true},
            "VNRegC" :      {"std" : 0,     "exp" : true}
        },
        "Pixel" : {
            "VNPix" :       {"std" : 10,    "exp" : false},
            "VPLoadPix" :   {"std" : 5,     "exp" : false},
            "VNFBPix" :     {"std" : [3,4,5,6], "exp" : false},
            "VNFollPix" :   {"std" : 5,     "exp" : false},
            "VNOutPix" :    {"std" : 5,     "exp" : false},
            "VPComp1" :     {"std" : 5,     "exp" : false},
            "VPComp2" :     {"std" : 5,     "exp" : false},
            "VNBiasPix" :   {"std" : 0,     "exp" : false},
            "BLResDig" :    {"std" : 6,     "exp" : false},
            "BLResPix" :    {"std" : 6,     "exp" : false},

            "VNPix2" :      {"std" : 0,     "exp" : true},
            "VNComp" :      {"std" : 0,     "exp" : true},
            "VNDAC" :       {"std" : 0,     "exp" : true},
            "VPDAC" :       {"std" : 0,     "exp" : true}
        },
        "General" : {
            "BiasBlock_on" :{"std" : [5, 0],     "exp" : false, "desc" : ["on", "off"]},
            "Bandgap_on" :  {"std" : [0, 1],     "exp" : false, "desc" : ["off", "on"]},

            "VPFoll" :      {"std" : 0,     "exp" : true},
            "VNHB" :        {"std" : 0,     "exp" : true},
        }
    },

    "CONFDACS" : {
        "General" : {
            "TestOut" :     {"std" : [0, 1, 3, 4, 5, 6, 7, 8, 9, 10], "exp" : false, "desc" : ["NC", "VSSA1", "VDDA1", "GNDA1", "VSSA2", "VDDA2", "GNDA2", "GND1", "VDD1", "GND2", "VDD2"]},
            "AlwaysEnable" :{"std" : [0, 1],     "exp" : false, "desc" : ["off", "on"]},
            "En2thre" :     {"std" : [1, 0],     "exp" : false, "desc" : ["on", "off"]},
            "EnPLL" :       {"std" : [0, 1],     "exp" : false, "desc" : ["on", "off"]},

            "SelFast" :     {"std" : 0,     "exp" : true},
            "count_sheep" : {"std" : 0,     "exp" : true},
            "NC1" :         {"std" : 0,     "exp" : true},
            "disable_HB" :  {"std" : 1,     "exp" : true},
            "conf_res_n" :  {"std" : 1,     "exp" : true},
            "RO_res_n" :    {"std" : 1,     "exp" : true},
            "Ser_res_n" :   {"std" : 1,     "exp" : true},
            "Aur_res_n" :   {"std" : 1,     "exp" : true},
            "NC2" :         {"std" : 0,     "exp" : true},
            "Tune_Reg_L" :  {"std" : 0,     "exp" : true},
            "NC3" :         {"std" : 0,     "exp" : true},
            "Tune_Reg_R" :  {"std" : 0,     "exp" : true},
            "NC4" :         {"std" : 0,     "exp" : true},
            "SelSlow" :     {"std" : 0,     "exp" : true},
            "SelEx" :       {"std" : 0,     "exp" : true},
            "invert" :      {"std" : 1,     "exp" : true},
            "slowdownlDColEnd":{"std" : 7,  "exp" : true},
            "EnSync_SC" :   {"std" : 1,     "exp" : true},
            "NC5" :         {"std" : 0,     "exp" : true},
            "linksel" :     {"std" : 0,     "exp" : true},
            "tsphase" :     {"std" : 0,     "exp" : true},
            "sendcounter" : {"std" : 0,     "exp" : true},
            "resetckdivend":{"std" : 0,     "exp" : true},
            "NC6" :         {"std" : 0,     "exp" : true},
            "maxcycend" :   {"std" : 63,    "exp" : true},
            "slowdownend" : {"std" : 0,     "exp" : true},
            "timerend" :    {"std" : 0,     "exp" : true},
            "ckdivend2" :   {"std" : [31, 15], "exp" : false},
            "ckdivend" :    {"std" : 0,     "exp" : true},
        }
    },

    "VDACS" : {
        "General" : {
            "BLPix" :       {"std" : 60,    "exp" : false},
            "ThHigh" :      {"std" : [125, 140, 129, 135, 200], "exp" : false},
            "ThLow" :       {"std" : [124, 139, 128, 134, 199], "exp" : false},
            "Baseline" :    {"std" : 112,   "exp" : false},
            "ref_Vss" :     {"std" : 169,   "exp" : false},

            "VCAL" :        {"std" : 0,     "exp" : true},
            "ThPix" :       {"std" : 0,     "exp" : true},
            "ThHigh2" :     {"std" : 0,     "exp" : true},
            "ThLow2" :      {"std" : 0,     "exp" : true},
            "VDAC1" :       {"std" : 0,     "exp" : true}
        }
    }
}

const Mupix_DACs_Vertex = {
    "BIASDACS" : {
        "PLL" : {
            "VNVCO" :       {"std" : [23, 17, 13],    "exp" : false},
            "VPVCO" :       {"std" : [22, 16, 12],    "exp" : false},

            "VNTimerDel" :  {"std" : 10,    "exp" : true},
            "VPTimerDel":   {"std" : 4,     "exp" : true},
            "VPPump" :      {"std" : 63,    "exp" : true},
            "VNLVDSDel" :   {"std" : 10,     "exp" : true},
            "VNLVDS" :      {"std" : 25,    "exp" : true},
            "VPDcl" :       {"std" : 32,    "exp" : true},
            "VNDcl" :       {"std" : 60,    "exp" : true},
            "VNDelPreEmp" : {"std" : 10,    "exp" : true},
            "VPDelPreEmp" : {"std" : 10,    "exp" : true},
            "VNDelDcl" :    {"std" : 10,    "exp" : true},
            "VPDelDcl" :    {"std" : 10,    "exp" : true},
            "VNDelDclMux" : {"std" : 10,    "exp" : true},
            "VPDelDclMux" : {"std" : 10,    "exp" : true},
            "VNDel" :       {"std" : 10,    "exp" : true},
            "VNRegC" :      {"std" : 0,     "exp" : true}
        },
        "Pixel" : {
            "VNPix" :       {"std" : 10,    "exp" : false},
            "VPLoadPix" :   {"std" : 5,     "exp" : false},
            "VNFBPix" :     {"std" : 3,     "exp" : false},
            "VNFollPix" :   {"std" : 5,     "exp" : false},
            "VNOutPix" :    {"std" : 5,     "exp" : false},
            "VPComp1" :     {"std" : 5,     "exp" : false},
            "VPComp2" :     {"std" : 5,     "exp" : false},
            "VNBiasPix" :   {"std" : 0,     "exp" : false},
            "BLResDig" :    {"std" : 5,     "exp" : false},
            "BLResPix" :    {"std" : 6,     "exp" : false},

            "VNPix2" :      {"std" : 0,     "exp" : true},
            "VNComp" :      {"std" : 0,     "exp" : true},
            "VNDAC" :       {"std" : 0,     "exp" : true},
            "VPDAC" :       {"std" : 10,     "exp" : true}
        },
        "General" : {
            "BiasBlock_on" :{"std" : [5, 0],     "exp" : false, "desc" : ["on", "off"]},
            "Bandgap_on" :  {"std" : [0, 1],     "exp" : false, "desc" : ["off", "on"]},

            "VPFoll" :      {"std" : 0,     "exp" : true},
            "VNHB" :        {"std" : 0,     "exp" : true},
        }
    },

    "CONFDACS" : {
        "General" : {
            "TestOut" :     {"std" : [0, 1, 3, 4, 5, 6, 7, 8, 9, 10], "exp" : false, "desc" : ["NC", "VSSA1", "VDDA1", "GNDA1", "VSSA2", "VDDA2", "GNDA2", "GND1", "VDD1", "GND2", "VDD2"]},
            "AlwaysEnable" :{"std" : [0, 1],     "exp" : false, "desc" : ["off", "on"]},
            "En2thre" :     {"std" : [1, 0],     "exp" : false, "desc" : ["on", "off"]},
            "EnPLL" :       {"std" : [0, 1],     "exp" : false, "desc" : ["on", "off"]},

            "SelFast" :     {"std" : 0,     "exp" : true},
            "count_sheep" : {"std" : 0,     "exp" : true},
            "NC1" :         {"std" : 0,     "exp" : true},
            "disable_HB" :  {"std" : 1,     "exp" : true},
            "conf_res_n" :  {"std" : 1,     "exp" : true},
            "RO_res_n" :    {"std" : 1,     "exp" : true},
            "Ser_res_n" :   {"std" : 1,     "exp" : true},
            "Aur_res_n" :   {"std" : 1,     "exp" : true},
            "NC2" :         {"std" : 0,     "exp" : true},
            "Tune_Reg_L" :  {"std" : 0,     "exp" : true},
            "NC3" :         {"std" : 0,     "exp" : true},
            "Tune_Reg_R" :  {"std" : 0,     "exp" : true},
            "NC4" :         {"std" : 0,     "exp" : true},
            "SelSlow" :     {"std" : 0,     "exp" : true},
            "SelEx" :       {"std" : 0,     "exp" : true},
            "invert" :      {"std" : 1,     "exp" : true},
            "slowdownlDColEnd":{"std" : 7,  "exp" : true},
            "EnSync_SC" :   {"std" : 1,     "exp" : true},
            "NC5" :         {"std" : 0,     "exp" : true},
            "linksel" :     {"std" : 0,     "exp" : true},
            "tsphase" :     {"std" : 0,     "exp" : true},
            "sendcounter" : {"std" : 0,     "exp" : true},
            "resetckdivend":{"std" : 0,     "exp" : true},
            "NC6" :         {"std" : 0,     "exp" : true},
            "maxcycend" :   {"std" : 63,    "exp" : true},
            "slowdownend" : {"std" : 0,     "exp" : true},
            "timerend" :    {"std" : 0,     "exp" : true},
            "ckdivend2" :   {"std" : 31,    "exp" : true},
            "ckdivend" :    {"std" : 0,     "exp" : true},
        }
    },

    "VDACS" : {
        "General" : {
            "BLPix" :       {"std" : 75,    "exp" : false},
            "ThHigh" :      {"std" : [140, 129, 135, 200], "exp" : false},
            "ThLow" :       {"std" : [139, 128, 134, 199], "exp" : false},
            "Baseline" :    {"std" : 112,   "exp" : false},
            "ref_Vss" :     {"std" : 169,   "exp" : false},

            "VCAL" :        {"std" : 0,     "exp" : true},
            "ThPix" :       {"std" : 0,     "exp" : true},
            "ThHigh2" :     {"std" : 0,     "exp" : true},
            "ThLow2" :      {"std" : 0,     "exp" : true},
            "VDAC1" :       {"std" : 0,     "exp" : true}
        }
    }
}

const Default_DAC_Sets = {
    "Quads" : Mupix_DACs, 
    "Vertex" : Mupix_DACs_Vertex
}


//setting specific DACs for chips
const DAClist = [
    {
        chipID: "0",
        VDACs: [
            // { name: "ThHigh", value: 134 },
            // { name: "ThLow", value: 133 }
        ],
        BIASDACS: [
            
        ],
        CONFDACs: [
        ]
    },
    {
        chipID: "9",
        BIASDACS: [
            {name: "VPTimerDel", value: 4},
        ]
    },
    {
        chipID: "10",
        BIASDACS: [
            {name: "VPTimerDel", value: 4},
        ]
    },
    {
        chipID: "13",
        BIASDACS: [
            {name: "VPTimerDel", value: 4},
        ]
    }
];

