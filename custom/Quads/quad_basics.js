//Load sequencer files

function load_sequencer_script(script_name, script_path="/home/labor/online/online/pixels/operation/") {
    paths = ["/Sequencer/State/Path", "/Sequencer/State/Filename"]
    vals = [script_path, script_name]
    mjsonrpc_db_paste(paths, vals).then(rpc => {
        paths2 = ["/Sequencer/Command/Load filename"]
        vals2 = [script_name]
        mjsonrpc_db_paste(paths2, vals2).then(rpc2 => {
            paths3 = ["/Sequencer/Command/Load new file"]
            vals3 = [1]
            mjsonrpc_db_paste(paths3, vals3).then(rpc3 => {
                                qcParamUpdate(script_name);
                return;
            }).catch(function(error) {
                console.log(error);
            });
        })
    })
}


function confirmSequencerLoadDACs() {
    dlgConfirm("Are you sure to load the default DACs for all chips?", sequencerLoadDACs);
}

function confirmSequencerConfigAll() {
    dlgConfirm("Are you sure to configure all chip?", sequencerConfigAll);
}

function confirmSequencerLoadThresholds() {
    dlgConfirm("Load sequencer file to change thesholds?", sequencerLoadThresholds);
}

function confirmSequencerUploadThresholds() {
    dlgConfirm("Upload selected thresholds in sequencer?", sequencerUploadThresholds);
}

function confirmSequencerSetThresholds() {
    dlgConfirm("Configure chip with new thresholds?", sequencerSetThresholds);
}



function sequencerLoadDACs(flag) {
    if (flag) {
        execute_sequencer_script("load_dacs_quad_mp11.msl");
    }
}

function sequencerConfigAll(flag) {
    const resetPLL_bool = document.getElementById("checkboxResetPLLOld");

    if (!resetPLL_bool.checked && flag) {
        execute_sequencer_script("configure_all.msl");
    }
    if (resetPLL_bool.checked && flag) {
        execute_sequencer_script("Reset_PLL_all.msl");
        dlgAlert("You are resetting the PLLs of all chips!");
    }
}

function sequencerLoadThresholds(flag) {
    if (flag) {
        load_sequencer_script("Set_Thresholds_all.msl");
    }
}

function sequencerUploadThresholds(flag) {
    if (flag) {
        const inputThHigh = parseInt(document.getElementById("inputThHigh").value, 10);
        const inputThLow = parseInt(document.getElementById("inputThLow").value, 10);
        const formattedThHigh = `${Math.abs(inputThHigh)}`;
        const formattedThLow = `${Math.abs(inputThLow)}`;
        modbset(['/Sequencer/Variables/ThHigh','/Sequencer/Variables/ThLow'], [formattedThHigh,formattedThLow]);
    }
}

function sequencerSetThresholds(flag) {
    if (flag) {
        modbset(['/Sequencer/Command/Start script'],[1]);
    }
}

function draw() {
    selection_draw();
}
