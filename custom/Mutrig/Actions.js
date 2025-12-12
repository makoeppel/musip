eq_path ="/Equipment/TilesLabor";

async function reset_mutrig_asics() {
    console.log("Resetting MuTrig ASICs");
    await setODBValue(eq_path+"/Settings/DAQ/reset_asics", 1);
}

async function reset_mutrig_dpath() {
    console.log("Resetting MuTrig Data Path");
    await setODBValue(eq_path+"/Settings/DAQ/reset_datapath", 1);
}

async function reset_mutrig_lvds() {
    console.log("Resetting MuTrig LVDS");
    await setODBValue(eq_path+"/Settings/DAQ/reset_lvds", 1);
}

async function reset_mutrig_counters() {
    console.log("Resetting MuTrig Counters");
    await setODBValue(eq_path+"/Settings/DAQ/reset_counters", 1);
}

async function mutrig_atestout_selected() {
    selectedChannel = window.selectedChannel || null;
    await set_mutrig_testout(selectedChannel);
}

async function mutrig_dtestout_selected() {
    selectedChannel = window.selectedChannel || null;
    await set_mutrig_dtestout(selectedChannel);
}


// Set the MuTrig TestOut MUX to the specified value and disable all other channel outputs.
// Also enable the output for the selected channel.
async function set_mutrig_testout(selectedChannel){
    var inputEl = document.getElementById("inputTestOut");
    var value = parseInt(inputEl.value);
    if (selectedChannel !== null && (isNaN(value) || value < 0 || value > 7)) {
        alert("Please enter a valid TestOut value (0-7).");
        return;
    }
    console.log("Setting MuTrig TestOut [",selectedChannel,"] to ", value);

    //TODO: combine calls
    path = eq_path+"/Settings/ASICs/Channels/amonctrl";
    amon = await getODBValue(path, true);
    amon.fill(0);
    if (selectedChannel !== null) {
        amon[selectedChannel] = value;
    }
    await setODBValue(path, amon, false);

    path = eq_path+"/Settings/ASICs/Channels/amon_en_n";
    amon_en_n = await getODBValue(path, true);
    amon_en_n.fill(true);
    if(value != 0){
        amon_en_n[selectedChannel] = false;
    }
    await setODBValue(path, amon_en_n, false);
    mutrig_configure_all();
}
// Set the MuTrig Digital TestOut MUX to the specified value, select channel
// Also enable the output for the selected channel.
async function set_mutrig_dtestout(selectedChannel){
    var inputEl = document.getElementById("inputTestOutDig");
    var select = parseInt(inputEl.value);
    var channel = selectedChannel % 32;
    var chip = selectedChannel - channel;
    if(selectedChannel == undefined || selectedChannel < 0){
        channel = -1;
    }
    const params = new Map([
        [ eq_path+"/Settings/ASICs/TDCs/dmon_select[*]",   channel ],
        [ eq_path+"/Settings/ASICs/TDCs/dmon_sw[*]",   select ],
        ]);
    setODBValue(Array.from(params.keys()),Array.from(params.values()),true).then(function(){
        mutrig_configure_all();
    });
}

async function mutrig_configure_all() {
    console.log("Configuring all MuTrig chips");
    setODBValue(eq_path+"/Commands/MutrigConfig", 1);
}

//Mask channels on mutrig.
//Value: if set, the channel is disabled.
//channel: -1: apply to full array. 0..n : apply to single channel
async function mutrig_sop_maskChannel(channel, value) {
    console.log("mutrig_sop_maskChannel "+channel+ " = "+ value);
    if (channel == -1){
        params = new Map([
        [ eq_path+"/Settings/ASICs/Channels/mask[*]",        value ],
        ]);
    }else{
        params = new Map([
        [ eq_path+"/Settings/ASICs/Channels/mask["+channel+"]", value ],
        ]);

    }

    setODBValue(Array.from(params.keys()),Array.from(params.values()),true).then(function(){
        mutrig_configure_all();
    });
}


async function mutrig_sop_inject(channel="*") {
    idx = "["+channel+"]"
    const params = new Map([
        [ eq_path+"/Settings/ASICs/Global/tx_mode",         0 ],
        [ eq_path+"/Settings/ASICs/Channels/cml"+idx,        0 ],
        [ eq_path+"/Settings/ASICs/Channels/cml_sc"+idx,     1 ],
        [ eq_path+"/Settings/ASICs/Channels/tdctest_n"+idx,  0 ],
        [ eq_path+"/Settings/ASICs/Channels/recv_all"+idx,   1 ],
        [ eq_path+"/Settings/ASICs/TDCs/dmon_select"+idx,   -1 ],
        [ eq_path+"/Settings/Commands/TestPulsesTDC",       1 ],
        ]);
    setODBValue(Array.from(params.keys()),Array.from(params.values()),true).then(function(){
        mutrig_configure_all();
    });
}

async function mutrig_sop_normal() {
    const params = new Map([
        [ eq_path+"/Settings/ASICs/Global/tx_mode",         0 ],
        [ eq_path+"/Settings/ASICs/Channels/cml[*]",        8 ],
        [ eq_path+"/Settings/ASICs/Channels/cml_sc[*]",     0 ],
        [ eq_path+"/Settings/ASICs/Channels/tdctest_n[*]",  1 ],
        [ eq_path+"/Settings/ASICs/Channels/recv_all[*]",   0 ],
        [ eq_path+"/Settings/ASICs/TDCs/dmon_select[*]",   -1 ],
        [ eq_path+"/Settings/Commands/TestPulsesTDC",       0 ],
        ]);
    setODBValue(Array.from(params.keys()),Array.from(params.values()),true).then(function(){
        mutrig_configure_all();
    });
}

async function mutrig_sop_noise() {
    const params = new Map([
        [ eq_path+"/Settings/ASICs/Global/tx_mode",         0 ],
        [ eq_path+"/Settings/ASICs/Channels/cml[*]",        8 ],
        [ eq_path+"/Settings/ASICs/Channels/cml_sc[*]",     0 ],
        [ eq_path+"/Settings/ASICs/Channels/tdctest_n[*]",  1 ],
        [ eq_path+"/Settings/ASICs/Channels/recv_all[*]",   1 ],
        [ eq_path+"/Settings/ASICs/TDCs/dmon_select[*]",   -1 ],
        [ eq_path+"/Settings/Commands/TestPulsesTDC",       0 ],
        ]);
    setODBValue(Array.from(params.keys()),Array.from(params.values()),true).then(function(){
        mutrig_configure_all();
    });
}

async function mutrig_sop_prbs() {
    const params = new Map([
        [ eq_path+"/Settings/ASICs/Global/tx_mode",         1 ],
        ]);
    setODBValue(Array.from(params.keys()),Array.from(params.values()),true).then(function(){
        mutrig_configure_all();
    });
}
