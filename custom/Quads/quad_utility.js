// General UTILITIES //

/**
 * Function to pause execution for a specific amount of tme
 *
 * @param {int} ms time to pause execution
 */
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

function sort_array(array) {
    return array.slice().sort(function(a, b){return a-b});
}

function list_to_string(list) {
    let formattedString = sort_array(list).join(', ');
    return formattedString
}


// Retrieve Sensor information:

function getSensorId(module, sensor){
    return sensor_ids[module][sensor];
}

function getConfigIds(sensor_ids = undefined) {
    // let conf_ids = sensors.map(entry => entry.conf_id);
    // if (sensor_ids == undefined) {
    //     return conf_ids;
    // }

    // if (Array.isArray(sensor_ids)) {
    //     return sensor_ids.map(i => conf_ids[i]);
    // }

    // return conf_ids.sensor_ids;
    if (sensor_ids === -1 || sensor_ids === undefined) {
        return -1;
    }
    else if (Array.isArray(sensor_ids)) {
        return sensor_ids.map(i => conf_ids[i]);
    }
    else if (sensor_ids === 999){
        return conf_ids;
    }
    else {
        return conf_ids[sensor_ids];
    }
}

function getDataIds(sensor_ids = undefined) {
    // let data_ids = sensors.map(entry => entry.data_id);
    // if (sensor_ids == undefined) {
    //     return data_ids;
    // }

    // if (Array.isArray(sensor_ids)) {
    //     return sensor_ids.map(i => data_ids[i]);
    // }

    // return data_ids.sensor_ids;
    if (sensor_ids === -1 || sensor_ids === undefined) {
        return -1;
    }
    else if (Array.isArray(sensor_ids)) {
        return sensor_ids.map(i => data_ids[i]);
    }
    else if (sensor_ids === 999){
        return data_ids;
    }
    else {
        return data_ids[sensor_ids];
    }
}

function getFEBLink(module, sensor){
    // let id = getSensorId(module, sensor)
    // return [sensors[id].feb, sensors[id].link];
    return sensor_links[module][sensor];
}

function getAll() {
    return sensor_ids.flat();
}



// Midas UTILITIES //

/**
 * Writes any value to the ODB.
 * Needs to be called as a Promise with await keyword.
 * TODO: convert return to bolean
 *
 * @param {string} paths
 * @param {string} values
 * @param {string} errorMsg
 * @returns {Promise}
 */
async function setODBValue(paths, values, print = true, errorMessageText = undefined){ // Remember that you can call a JS script with any number of params that you'd like. If a param is not present, its undefined. Function will manage
    if (print) console.log("setODBValue: " + paths + " to: " + values);
    try{
        if (!Array.isArray(paths)){
            return await mjsonrpc_db_paste([paths], [values]);
        } else {
            return await mjsonrpc_db_paste(paths, values);
        }

    }
    catch (error) {
        let errorMessage = 'Couldn\'t change value at ' + paths + ': ' + error;
        if (errorMessageText != undefined){
            errorMessage = errorMessageText + ': ' + error;
        }
        mjsonrpc_error_alert(errorMessage)
        console.log(errorMessage);
        return null;
    }
}

/**
 * Function to read any value in the ODB.
 * Needs to be called as a Promise with await keyword.
 *
 * @param {string} paths
 * @param {string} errorMessageText
 * @returns {Promise} data
 */
async function getODBValue(paths, print = false, errorMessageText = undefined) {
    try {
        if (!Array.isArray(paths)) {
            let value = await mjsonrpc_db_get_value(paths);
            let data = value.result.data[0];
            if (print) console.log("getODBValue: " + paths + " = " + data);
            return data;
        }
        else {
            let values = await mjsonrpc_db_get_values(paths);
            let data = values.result.data;
            if (print) console.log("getODBValues: " + paths + " = " + data);
            return data;
        }
    }
    catch (error) {
        let errorMessage = 'Couldn\'t read value at ' + paths + ': ' + error;
        if (errorMessageText != undefined){
            errorMessage = errorMessageText + ': ' + error;
        }
        mjsonrpc_error_alert(errorMessage)
        console.log(errorMessage);
        return null;
    }
}

// Messages:

// write a function to change the text of the message box outputAction
async function setOutputText(text) {
    let outputAction = document.getElementById("outputAction");
    outputAction.innerHTML = "<p id='outputText'>" + text + "</p>";
}

async function clearOutputText(time = 2000) {
    if (time != undefined && time != 0 && time != false) await sleep(time);
    setOutputText("");
}

// Sequencer Scripts

/**
 * Executes a sequencer script
 * @param {string} script_name Sequencer script name
 * @param {string} script_path Sequencer script path
 */

async function execute_sequencer_script(scriptName, id ="", scriptPath = "/home/mu3e/mu3e/debug_online/online/pixels/operation/") {
    const paths = ["/Sequencer/State/Path", "/Sequencer/State/Filename"];
    const vals = [scriptPath, scriptName];

    try {
        await mjsonrpcDbPaste(paths, vals);

        const paths2 = ["/Sequencer/Command/Load filename"];
        const vals2 = [scriptName];
        await mjsonrpcDbPaste(paths2, vals2);

        const paths3 = ["/Sequencer/Command/Load new file"];
        const vals3 = [1];
        await mjsonrpcDbPaste(paths3, vals3);

        const paths4 = ["/Sequencer/Command/Start script"];
        const vals4 = [1];
        await mjsonrpcDbPaste(paths4, vals4);
    } catch (error) {
        console.log(error);
    }
}

async function mjsonrpcDbPaste(paths, vals) {
    return new Promise((resolve, reject) => {
        mjsonrpc_db_paste(paths, vals)
            .then(resolve)
            .catch(reject);
    });
}


async function jsLoadDACs(chipID = '*', dacSetName = "Quads") {

    let DAC = Default_DAC_Sets[dacSetName];
    if (!DAC) {
        console.error(`DAC set "${dacSetName}" not found. Using default "Quads" set.`);
        DAC = Default_DAC_Sets["Quads"];
    }

    console.log("Loading DACs for chip: ", chipID, "DAC Set: ", dacSetName);

    for (const group in DAC) {
    //dlgAlert(group);
    const groupObj = DAC[group];
        for (const category in groupObj) {
            //dlgAlert(category);
            const dacCategory = DAC[group][category];
            for (const dac in dacCategory) {
                const dacObj = dacCategory[dac];
                for (const property in dacObj) {
                    if (property == 'std') {
                        let value = dacObj[property];
                        if (Array.isArray(value)){
                        value = dacObj[property][0];
                    }
                    console.log(`${value}`);
                    //console.log(`${dac}`);
                    const path = `/Equipment/Quads/Settings/Config/${group}/${dac}[${chipID}]`;
                    setODBValue(path,value);
                }
                //console.log(`$path`);
            }
        }
    }
        //console.log(`Category: ${category}`);
    //const categoryObj = Mupix_DACs.BIASDACS[category];
        //console.log(`${category}`);
    }
    const foundChip = DAClist.find(chip => Number(chip.chipID) === Number(chipID));
    if (foundChip) {
        //dlgAlert(chipID);
        for (const dac of foundChip.VDACs) {
            //dlgAlert(dac.name);
            console.log(`DAC Name: ${dac.name}, Value: ${dac.value}`);
            const path = `/Equipment/Quads/Settings/Config/VDACS/${dac.name}[${chipID}]`;
            //dlgAlert(path);
            setODBValue(path,dac.value);
        }
        for (const dac of foundChip.CONFDACs) {
            //dlgAlert(dac.name);
            console.log(`DAC Name: ${dac.name}, Value: ${dac.value}`);
            const path = `/Equipment/Quads/Settings/Config/CONFDACS/${dac.name}[${chipID}]`;
            //dlgAlert(path);
            setODBValue(path,dac.value);
        }

    }
    return;
}

// CONFIGURATION //

function setup_odb() {
    // set Masking paths:
    // iterate over the flas sensor_id array and set:
    // /Equipment/Quads/Settings/Config/TDACS/${id}/TDACFILE

    let data_ids = getDataIds(999);

    //let runPath = "/home/musip/online/userfiles/";
    //let runPath = "/home/labor/online/online/userfiles/";
    let runPath = "/home/mu3e/mu3e/debug_online/online/userfiles/";
    for (let i = 0; i < data_ids.length; i++){
        let id = data_ids[i];
        let path = `/Equipment/Quads/Settings/Config/TDACS/TDACFILE[${id}]`;
        let value = `${runPath}mask_${id}.bin`;
        setODBValue(path, value);
    }
}

// Read files //

async function retrieveBinaryFile(filePath) {
    try {
        const index = filePath.indexOf("userfiles");
        if (index == -1) throw new Error("Invalid file path: " + filePath);

        const relPath = filePath.substring(index);
        console.log("relPath: ", relPath, "absPath: ", filePath);

        let xmlhttp = new XMLHttpRequest();
        return new Promise((resolve, reject) => {
            xmlhttp.onload = function() {
                if (xmlhttp.status == 200 && xmlhttp.readyState == 4) {
                    const data = new Uint8Array(xmlhttp.response);
                    resolve(data);
                }
            }
            xmlhttp.open("GET", relPath + "?cache=" + Date.now(), true);
            xmlhttp.responseType = "arraybuffer";
            xmlhttp.send();

            xmlhttp.onerror = function() {
                reject(new Error("File does not exist: " + xmlhttp.statusText));
            }
        });
    } catch (error) {
        console.log("Error retrieving file: ", error.message);
    }
}

// Note: intentionally no fileExists() HTTP probe here to avoid server log spam on missing files.


// color map

const rgbColors = hexArrayToRgbArray(hexColors);
console.log(rgbColors);

function hexToRgb(hex) {
    // Remove the hash at the start if it's there
    hex = hex.charAt(0) === '#' ? hex.slice(1) : hex;

    // Parse the r, g, b values
    let bigint = parseInt(hex, 16);
    let r = (bigint >> 16) & 255;
    let g = (bigint >> 8) & 255;
    let b = bigint & 255;

    return [ r, g, b ];
}

function hexArrayToRgbArray(hexArray) {
    return hexArray.map(hex => hexToRgb(hex));
}

function getBit(number, bitPosition) {
    return (number & (1 << bitPosition)) === 0 ? 0 : 1;
}

function interpolateColor(color1, color2, ratio) {
    let [r1, g1, b1] = color1
    let [r2, g2, b2] = color2

    // console.log("rgb1: ", r1, g1, b1);
    // console.log("rgb2: ", r2, g2, b2);

    let r = (r1 + (r2 - r1) * ratio) | 0;
    let g = (g1 + (g2 - g1) * ratio) | 0;
    let b = (b1 + (b2 - b1) * ratio) | 0;

    // console.log("rgb: ", r, g, b);

    return [r, g, b];

    // return as hex
    //return "#" + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1);
}

function generateGradient(ratio, colors = rgbColors, offset = 0) {
    if (ratio == 0) {
        return colors[0];
    }

    // Ensure ratio is between 0 and 1
    ratio = Math.min(Math.max(ratio, 0), 1);
    //console.log("ratio: ", ratio);
    let section = (1 / (colors.length - 2));
    //console.log("section: ", section);
    let index = Math.min((ratio / section) | 0, colors.length - 2 - offset);
    //console.log("index: ", index);
    let localRatio = (ratio - section * index) / section;
    //console.log("localRatio: ", localRatio)

    return interpolateColor(colors[index + offset], colors[index + 1 + offset], localRatio);
}


// LVDS Links (redifines functions from pixel_lvds.js)  //
// TODO: import febs from pixel_lvds.js and remove this section

function lvdslink(x,y,name){
    this.x = x;
    this.y = y;
    this.name = name;
    this.ready  = 0;

    this.disperr =0;
    this.disperr_last =0;
    this.err =0;
    this.err_last =0;

    this.A =0;
    this.B =0;
    this.C =0;
}

function feb(x,y,name){
    this.x = x;
    this.y = y;
    this.name = name;

    this.links = new Array(36);

    for(var i=0; i<36; i++){
        this.links[i] = new lvdslink(this.x,this.y+30+i*32, "Link "+ i);
    }
}

var febs = Array(10);

for(var i=0; i < 10; i++)
    febs[i] = new feb(160*i,0,"FEB "+ i);

function init(){
    mjsonrpc_db_get_values(["/Equipment/Quads/Variables/PCLS"]).then(function(rpc) {
        if(rpc.result.data[0]){
            update_pcls(rpc.result.data[0]);
        }
    }).catch(function(error) {
        mjsonrpc_error_alert(error);
    });
    mjsonrpc_db_get_values(["/Equipment/Quads/Variables/PCMS"]).then(function(rpc) {
        if(rpc.result.data[0]){
            update_pcms(rpc.result.data[0]);
        }
    }).catch(function(error) {
        mjsonrpc_error_alert(error);
    });
}

init();

function update_pcls(valuex){
    var value = valuex;
    if(typeof valuex === 'string')
        value = JSON.parse(valuex);

    var offset = 0;
    for(var f=0; f <10; f++){
        // get the FEB.GetLinkID() from the bank and only update this FEB
        var febindex = parseInt(value[offset], 16);
        var nlinks = parseInt(value[offset+1], 16);
        if(f != febindex)
            continue;
        for(var l=0; l < nlinks; l++){
            var status = parseInt(value[offset+2+4*l], 16);

            febs[f].links[l].locked = 0;
            febs[f].links[l].ready  = 0;
            if(status & (1<<31))
                febs[f].links[l].locked = 1;
            if(status & (1<<30))
                febs[f].links[l].ready  = 1;
            febs[f].links[l].disperr = parseInt(value[offset+2+4*l+1], 16);
            febs[f].links[l].err = parseInt(value[offset+2+4*l+2], 16);
        }
        offset += 2 + nlinks*4;
        if(offset >= value.length)
            break;
    }
}

function update_pcms(valuex){
    var value = valuex;
    if(typeof valuex === 'string')
        value = JSON.parse(valuex);

    // console.log("update_pcms", value);

    var offset = 0;
    for(var f=0; f < 10; f++){
        // get the FEB.GetLinkID() from the bank and only update this FEB
        var febindex = value[offset];
        var nlinks = value[offset+1];
        if(f != febindex)
            continue;

        for(var l=0; l < nlinks; l++){
            // TODO: remap here
            if(l >= febs[f].links.length)
                continue;
            // console.log("FEB:Link ", f, l, "A: ", value[offset+2], "B: ", value[offset+4], "C: ", value[offset+6], getBit(value[offset+2]), getBit(value[offset+4]), getBit(value[offset+6]))
            febs[f].links[l].A = getBit(value[offset+2], l);
            febs[f].links[l].B = getBit(value[offset+4], l);
            febs[f].links[l].C = getBit(value[offset+6], l);
        }
        offset += 8;
        if(offset >= value.length)
            break;
    }
}



