// constants //

TESTOUT_VALUES = [0, 3,2,1, 6,5,4, 7,8, 9,10, 0]

// general functions //

async function executeSensorCommand(odbPath, id = -1, time = 1, errorMessageText="Failed",  messageText=undefined, qcHisto = false) {
    let status1 = true;
    if (id == -1) {
        return false;
    }
    status1 = await setODBValue(`/Equipment/Quads/Settings/DAQ/Commands/MupixChipToConfigure`, id, false);
    status1 = await setODBValue(`/Equipment/Quads/Settings/DAQ/Commands/QcHisto chip number`, id, false);
    console.log("path:", odbPath, "id:", id);
    if (qcHisto == true){
        chip_id = id;
        feb_id = Math.floor(id / 8);
        status1 &= await setODBValue(`/Equipment/Quads/Settings/DAQ/Commands/QcHisto FEB link number`, feb_id, false);
        console.log("qcHisto:", odbPath, "chip id:", chip_id, "feb id:", feb_id);
    }
    let status2 = await setODBValue(odbPath, true, false);
    let status3 = true;


    time = time * 1000;
    waitTime = Math.round(time / 50);
    for (let i = 0; i < 50; i++) {
        // wait for half a second
        await sleep(waitTime);
        // check if configuration is finished
        status3 = await getODBValue(odbPath, false)
        //console.log("process status", status3)
        if (!status3){
            console.log("process sucessfully finished");
            break;
        }
    }

    if (status3){
        console.log(errorMessageText);
    }

    if (messageText != undefined){
        console.log(messageText, status1, status2, !status3);
    }
    return (status1 && status2 && !status3);

}


// Load DACs //

async function load_dacs(id = "*", dacSetName = null){
    // Get the current DAC set from the DACManager if not explicitly provided
    let currentDACSet = dacSetName;
    if (!currentDACSet && typeof dacManager !== 'undefined') {
        currentDACSet = dacManager.getCurrentDACSet();
    }
    if (!currentDACSet) {
        currentDACSet = "Quads"; // Default fallback
    }
    
    //execute_sequencer_script("load_dacs_quad_mp11.msl", id);
    jsLoadDACs(id, currentDACSet);
}

async function reset_all_asics() {
    await setODBValue("/Equipment/Quads/Settings/DAQ/Commands/ResetASICs", 1);
    await setODBValue("/Equipment/Quads/Settings/DAQ/Commands/MupixConfig", 1);
    await setODBValue("/Equipment/Quads/Settings/DAQ/Commands/ResetASICs", 0);
}


async function load_all_dacs(dacSetName = null){
    // Get the current DAC set from the DACManager if not explicitly provided
    let currentDACSet = dacSetName;
    if (!currentDACSet && typeof dacManager !== 'undefined') {
        currentDACSet = dacManager.getCurrentDACSet();
    }
    if (!currentDACSet) {
        currentDACSet = "Quads"; // Default fallback
    }
    
    setOutputText("Loading DACs for all sensors...");
    for (const conf_id of conf_ids) {
        await load_dacs(conf_id, currentDACSet);
    }
    clearOutputText();
}

async function load_dacs_selected(){
    let ids = getSelection();
    console.log("ids", ids);
    setOutputText("Loading DACs selected sensors:" + list_to_string(ids));
    let config_ids_loc = getConfigIds(ids);
    
    // Get the current DAC set from the DACManager if it exists
    let currentDACSet = "Quads"; // Default fallback
    if (typeof dacManager !== 'undefined') {
        currentDACSet = dacManager.getCurrentDACSet();
    }
    
    for (let i = 0; i < config_ids_loc.length; i++) {
        let id = config_ids_loc[i];
        await load_dacs(id, currentDACSet);
    }
    clearOutputText();
}


// Get DACs //

async function get_sensor_dac(dac, id, type = "BIASDACS") {
    if (type != "BIASDACS" && type != "CONFDACS" && type != "VDACS") {
        return console.error("Type must be BIASDACS, CONFDACS or VDACS");
    }

    let path = `/Equipment/Quads/Settings/Config/${type}/${dac}[${id}]`;

    return await getODBValue(path, false);
}

async function get_sensors_dac(dac, ids, type = "BIASDACS") {
    if (type != "BIASDACS" && type != "CONFDACS" && type != "VDACS") {
        return console.error("Type must be BIASDACS, CONFDACS or VDACS");
    }

    let paths = [];
    for (let i = 0; i < ids.length; i++) {
        id = ids[i];
        paths.push(`/Equipment/Quads/Settings/Config/${type}/${dac}[${id}]`);
    }

    return await getODBValue(paths, false);
}

async function get_sensor_dacs(dacs, id, type="BIASDACS") {
    if (type != "BIASDACS" && type != "CONFDACS" && type != "VDACS") {
        return console.error("Type must be BIASDACS, CONFDACS or VDACS");
    }

    let paths = [];
    for (let i = 0; i < dacs.length; i++) {
        dac = dacs[i];
        paths.push(`/Equipment/Quads/Settings/Config/${type}/${dac}[${id}]`);
    }
    return await getODBValue(paths, false);

}

// TODO: Write a function, that can handle everything at once

// Set DACs //

/**
 * Set a specific DAC of a certain type to a sensor with id
 *
 * @author Lukas
 * @param {string} dac DAC name
 * @param {number} value DAC value (dec)
 * @param {number} config_id SensorID (default: "*" for all sensors)
 * @param {string} type DAC type (BIAS, CONF, V) (default: BIAS)
 * @returns {Promise} status
 */
async function set_sensor_dac(dac, value, config_id = "*", type = "BIASDACS") {
    if (type != "BIASDACS" && type != "CONFDACS" && type != "VDACS") {
        return console.error("Type must be BIASDACS, CONFDACS or VDACS");
    }

    let path = `/Equipment/Quads/Settings/Config/${type}/${dac}[${config_id}]`;

    return await setODBValue(path, value);
}

async function set_sensors_dac(dac, value, config_ids, type){
    setOutputText("Setting DAC " + dac + " to " + value + " for sensors " + list_to_string(config_ids));
    
    // Use Promise.all to wait for all DAC operations to complete
    const promises = [];
    for (let i = 0; i < config_ids.length; i++) {
        const id = config_ids[i];
        console.log("Set dac", dac, "to", value, "for sensor", id, "of type", type);
        promises.push(set_sensor_dac(dac, value, id, type));
    }
    
    // Wait for all operations to complete
    await Promise.all(promises);
    clearOutputText();
}


/**
 * Set the DACs from a list of DACs to the sensors with ids
 * TODO: implement
 *
 * @param {*} dacs
 * @param {*} config_ids
 * @returns
 */
function set_sensors_dacs(dacs, config_ids) {
    // if id is a list:
    if (Array.isArray(config_ids)){
        // loop over all ids
        for (let i = 0; i < config_ids.length; i++) {
            // set the dacs
            set_sensors_dacs(dacs, config_ids[i]);
        }
        return;
    }
    else {
        // TODO: Implement (set multiple dacs for one sensor)
    }
}

// Configuration //

/**
 * configure sensor with id and wait until configuration is finished.
 * Needs to be called as a Promise with await keyword.
 *
 * @author Lukas
 * @param {number} id SensorID
 * @returns
 */
async function configure(id = 999){
    //if AllAlwaysEnable On: the DAC AlwaysEnable of all chips
    const allAlwaysEnable_bool = document.getElementById("checkboxAllAlwaysEnable");
    if (allAlwaysEnable_bool.checked) {
        let config_ids_loc = conf_ids;
        if (id != 999) {
            config_ids_loc = [id];
        }
        for (const conf_id of config_ids_loc) {
            const path = `/Equipment/Quads/Settings/Config/CONFDACS/AlwaysEnable[${conf_id}]`;
            await setODBValue(path,1);
        }
    }
    //if ResetPLL checked, all chips are configured twice
    const resetPLL_bool = document.getElementById("checkboxResetPLL");
    if (resetPLL_bool.checked) {
        let config_ids_loc = conf_ids;
        if (id != 999) {
            config_ids_loc = [id];
        }
        for (const conf_id of config_ids_loc) {
            const path = `/Equipment/Quads/Settings/Config/CONFDACS/EnPLL[${conf_id}]`;
            await setODBValue(path,1);
        }

        await executeSensorCommand(`/Equipment/Quads/Settings/DAQ/Commands/MupixConfig`, id, 1, "Configuration not sucessfull...", undefined, false);

        await sleep(1000); //wait for chips to stabilize
        for (const conf_id of conf_ids) {
            const path = `/Equipment/Quads/Settings/Config/CONFDACS/EnPLL[${conf_id}]`;
            await setODBValue(path,0);
        }
    }
    return await executeSensorCommand(`/Equipment/Quads/Settings/DAQ/Commands/MupixConfig`, id, 1, "Configuration not sucessfull...", undefined, false)
}

/**
 * Use boradcast to configure all sensors at once
 *
 * @author Lukas
 * @returns {Promise} status
 */
async function configure_all(){
    setOutputText("Configuring all sensors...");
    let status = await configure(999);

    clearOutputText();
    return status;
}

/**
 * Configure all selected sensors
 *
 * @returns {Promise} status
 */
async function configure_selected(){
    let selected = getSelection();
    let config_ids = getConfigIds(selected);
    setOutputText("Configuring selected sensors: " + list_to_string(selected) + "-" + list_to_string(config_ids));
    let status = false;

    if (selected.length == 16){
        status = await configure_all();
    }
    else {
        let config_ids = getConfigIds(selected);
        console.log("!!!!!!! - config_ids: ", config_ids)
        for (let i = 0; i < config_ids.length; i++) {
            // set the chip id
            let id = config_ids[i];
            status = await configure(id);
        }
    }

    clearOutputText();
    return status;
}



// Masking //

/**
 * applies mask files to sensor with id
 * FIXME: id does not matter
 *
 * @author Lukas
 * @returns {Promise} status
 */
async function mask(id = 999) {
    return await executeSensorCommand(`/Equipment/Quads/Settings/DAQ/Commands/MupixTDACConfig`, id, 3, "Masking not sucessfull...", undefined, false)
}

/**
 * Apply masks to all sensors at once
 * FIXME: ID does not matter - this always maks all
 */
async function mask_all() {
    setOutputText("Masking all sensors...");
    await mask(999);
    clearOutputText();
}

/**
 * Apply masks to all selected sensors
 * FIXME: ID does not matter - this always masks all
 */
async function mask_selected() {
    let selected = getSelection();
    setOutputText("Masking selected sensors: " + list_to_string(selected));

    if (selected.length == 16){
        await mask_all();
    }
    else {
        for (let i = 0; i < selected.length; i++) {
            let conf_id = selected[i];
            await mask(conf_id);
        }
    }
    clearOutputText();
}

// Create Masks

async function create_masks_all() {
    setOutputText("Creating Masks for all sensors...");


    clearOutputText();
}

async function create_masks_selected() {
    let selected = getSelection();

}

// Testout

async function testout_selected() {
    const inputTestOut = parseInt(document.getElementById("inputTestOut").value, 10);

    let selected = getSelection();
    setOutputText("Setting TestOut to " + inputTestOut + " for sensor: " + selected);
    let selected_conf = getConfigIds(selected);

    for (let i = 0; i < selected_conf.length; i++) {
        conf_id = selected_conf[i];
        await set_sensor_dac("TestOut", inputTestOut, conf_id, "CONFDACS");
        await configure(conf_id);
    }
    clearOutputText();
}

async function testout_scan() {
    let id = getActiveSelection();
    setOutputText("Scanning TestOut for sensor: " + id);
    let conf_id = getConfigIds(id);

    if (conf_id < 0){
        return console.error("No sensor selected");
    }

    // for loop over all testout values
    for (let i = 0; i < TESTOUT_VALUES.length; i++) {
        let value = TESTOUT_VALUES[i];
        setOutputText("Current TestOut value: " + value + " for sensor: " + id);

        await set_sensor_dac("TestOut", value, conf_id, "CONFDACS");
        await configure(conf_id);
        await sleep(5000);
    }
    clearOutputText();
}

/**
 * Execute full chip injection
 *
 * @author Assistant
 * @returns {Promise<boolean>} Success status
 */
async function full_chip_injection() {
    try {
        // Phase 1: Set FEBs to idle
        setOutputText("Start injection");

        // Use executeSensorCommand with id=-1 but modified to not check for id
        let status1 = await executeCommand(`/Equipment/Quads/Settings/DAQ/Commands/Full chip Injection`, -1, "FEB Full chip Injection command failed");

        if (!status1) {
            setOutputText("Injection takes a lot of time, check ODB & histograms");
            return false;
        }

        // Success
        setOutputText("Injection successfully");
        setTimeout(() => clearOutputText(), 2000); // Clear after 2 seconds
        return true;
    } catch (error) {
        console.error("Error during Start injection:", error);
        setOutputText("Error during Start injection: " + error.message);
        return false;
    }
}

// FEB Run Cycle //
/**
 * Execute a FEB run cycle: set FEBs to idle, wait for completion, then set back to running
 *
 * @author Assistant
 * @returns {Promise<boolean>} Success status
 */
async function feb_run_cycle() {
    try {
        // Phase 1: Set FEBs to idle
        setOutputText("Setting FEBs to idle...");
        console.log("Starting FEB run cycle - setting FEBs to idle");
        
        // Use executeSensorCommand with id=-1 but modified to not check for id
        let status1 = await executeCommand(`/Equipment/Quads/Settings/DAQ/Commands/Set FEBs into idle`, 1, "FEB idle command failed");
        
        if (!status1) {
            setOutputText("Failed to set FEBs to idle");
            return false;
        }
        
        // Phase 2: Set FEBs back to running
        setOutputText("Setting FEBs to running...");
        console.log("Setting FEBs back to running");
        
        let status2 = await executeCommand(`/Equipment/Quads/Settings/DAQ/Commands/Set FEBs into running`, 1, "FEB running command failed");
        
        if (!status2) {
            setOutputText("Failed to set FEBs to running");
            return false;
        }
        
        // Success
        setOutputText("FEB run cycle completed successfully");
        setTimeout(() => clearOutputText(), 2000); // Clear after 2 seconds
        return true;
        
    } catch (error) {
        console.error("Error during FEB run cycle:", error);
        setOutputText("Error during FEB run cycle: " + error.message);
        return false;
    }
}

/**
 * Execute a FEB command (similar to executeSensorCommand but for FEB operations)
 * 
 * @param {string} odbPath ODB command path
 * @param {number} time Timeout in seconds
 * @param {string} errorMessageText Error message to display
 * @returns {Promise<boolean>} Success status
 */
async function executeCommand(odbPath, time = 1, errorMessageText = "FEB command failed") {
    console.log("Executing FEB command:", odbPath);
    
    // Set the command to true
    let status1 = await setODBValue(odbPath, true, false);
    if (!status1) {
        console.error("Failed to initiate FEB command:", odbPath);
        return false;
    }
    
    // Wait for command to complete (similar logic to executeSensorCommand)
    let status2 = true;
    let n_loop = 50;
    if (time == -1) n_loop = 10000000;
    time = time * 1000;
    let waitTime = Math.round(time / 50);

    for (let i = 0; i < n_loop; i++) {
        await sleep(waitTime);
        status2 = await getODBValue(odbPath, false);
        if (!status2) {
            console.log("FEB command completed successfully:", odbPath);
            break;
        }
    }

    if (status2) {
        console.log(errorMessageText);
        return false;
    }
    
    return true;
}
