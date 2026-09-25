const setup = "pioneer"; // Options available: "musip" and "pioneer"

const setups = {
    musip: {
	mask_path: ["/home/mu3e/musip/online/userfiles/maskfiles"],
        features: ["keithley", "cooling"],
	//Titles:
	lv_supply_0_title: "LV SUPPLY 0: FEB & MuTrig",
	lv_supply_1_title: "LV SUPPLY 1: Quads & HV Box",
	hv_supply_title: "HV Box & Keithely HV supplies",
	//Channels:
	node_hv0_def: 2,
	node_hv1_def: 2,
	node_hv_max: 2,
	channel_hv0_def: 2,
	channel_hv1_def: 3,
	channel_hv0_name: "MSCB382 - Layer 5",
        channel_hv1_name: "MSCB382 - Layer 1",
        hvBox_supplyChannel: "/Equipment/LVSUPPLY1/Variables/State[3]",
        hvBox_supplyChannelSet: "/Equipment/LVSUPPLY1/Variables/Set State[3]"
    },

    pioneer: {
	mask_path: ["/home"],     
        features: ["keins"],
	lv_supply_0_title: "LV SUPPLY 0: FEBs",
	lv_supply_1_title: "LV SUPPLY 1 Quads and HV Box",
	hv_supply_title: "HV Box",
        //Channels:
        node_hv0_def: 1,
        node_hv1_def: 1,
	node_hv_max: 1,
        channel_hv0_def: 0,
        channel_hv1_def: 1,
        channel_hv0_name: "",
        channel_hv1_name: "",
	hvBox_supplyChannel: "/Equipment/LVSUPPLY1/Variables/State[2]",   
	hvBox_supplyChannelSet: "/Equipment/LVSUPPLY1/Variables/Set State[2]"
    }
};

const cfg = setups[setup];

