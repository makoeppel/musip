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
async function getODBValue(paths, print = true, errorMessageText = undefined) {
    try {
        if (!Array.isArray(paths)) {
            let value = await mjsonrpc_db_get_value(paths);
            let data = value.result.data[0];
            if (value.result.data.length > 1){
                data = value.result.data;
            }
            if (print) console.log("getODBValue: " + paths + " = " + data);
            console.log(data);
            return data;
        }
        else {
            let values = await mjsonrpc_db_get_values(paths);
            let data = values.result.data;
            if (print) console.log("getODBValues: " + paths + " = " + data);
            console.log(data);
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

async function execute_sequencer_script(scriptName, id ="", scriptPath = "/home/labor/online/online/pixels/operation/") {
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

// color map

//const rgbColors = hexArrayToRgbArray(hexColors);
//console.log(rgbColors);

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
