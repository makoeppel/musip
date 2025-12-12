

var odb_path = "Equipment/TilesLabor/";
var config_container_class = "chip_settings_container";


// all dac settings             
var asicsettings_global_int         = ['tx_mode'];
var asicsettings_global_bool        = ['sync_ch_rst'];

var daqsettings_int                 = [];//'dummy_data_n']; //disable as long as it isnt fixed
var daqsettings_bool                = [];

var asicsettings_tdc_int            = ['vnhitlogic', 'vnhitlogic_offset', 'vnvcodelay', 'vnvcodelay_offset', 'dmon_select'];
var asicsettings_tdc_bool           = ['vnhitlogic_scale', 'vnvcodelay_scale', 'dmon_sw']

var asicsettings_channel_int        = ['tthresh', 'tthresh_sc', 'tthresh_offset', 'ethresh', 'ebias', 'inputbias', 'cml', 'cml_sc', 'sipm'];
var asicsettings_channel_bool       = ['mask', 'tdctest_n', 'recv_all'];


// optional validation for settings
const valid_entries = {
    "tx_mode": { min: 0, max: 3 },
    "vnhitlogic": { min: 0, max: 63 },
    "vnhitlogic_offset": { min: 0, max: 3 },
    "vnvcodelay": { min: 0, max: 63 },
    "vnvcodelay_offset": { min: 0, max: 3 },
    "dmon_select": { min: -1, max: 31 },
    "tthresh": { min: 0, max: 63 },
    "tthresh_sc": { min: 0, max: 7 },
    "tthresh_offset": { min: 0, max: 7 },
    "ethresh": { min: 0, max: 255 },
    "ebias": { min: 0, max: 7 },
    "inputbias": { min: 0, max: 63 },
    "cml": { min: 0, max: 15 },
    "cml_sc": { min: 0, max: 1 }
};


var msg = null;


function configure() {
    mutrig_configure_all();
}


function create_path(subpath, name, index){
    var dpath = "";
    if(index != undefined && index >= 0){
        dpath = odb_path.concat(subpath + name +"["+index+"]");
    }
    else{
        dpath = odb_path.concat(subpath + name);
    }
    //console.log("set path of " + name + " to: "+dpath);
    return dpath;
}

function map_indices(init = false, tdc = 0, ch = 0){
    //console.log("Mapping indices:"+ " TDC: " + tdc.toString() + " CH: " + ch.toString());

    var classNames = ["modbcheckbox", "modbvalue"];
    containerObjects = document.getElementsByClassName(config_container_class);
    Array.from(containerObjects).forEach(function(containerObject){
        //console.log("containerObject: ", containerObject);
        classNames.forEach(function(className) {
            var boxes = containerObject.getElementsByClassName(className);
            for (var i=0; i<boxes.length; i++){
                var box = boxes[i];
                var name = box.getAttribute("name");

//                if (box.cell_odb_value == undefined) {
//                    return;
//                }
//                box.cell_odb_value.remove();

                if(asicsettings_channel_int.includes(name) || asicsettings_channel_bool.includes(name)){
                    box.setAttribute("data-validate", "validate_odb");
                    box.setAttribute("data-odb-editable", "1");
                    box.setAttribute("data-odb-path", create_path("Settings/ASICs/Channels/",name,ch));
                    continue;
                }
                if(asicsettings_tdc_int.includes(name) || asicsettings_tdc_bool.includes(name)){
                    box.setAttribute("data-validate", "validate_odb");
                    box.setAttribute("data-odb-editable", "1");
                    box.setAttribute("data-odb-path", create_path("Settings/ASICs/TDCs/",name,tdc));
                    continue;
                }
                if(asicsettings_global_int.includes(name)){
                    box.setAttribute("data-validate", "validate_odb");
                    box.setAttribute("data-odb-editable", "1");
                    box.setAttribute("data-odb-path", create_path("Settings/ASICs/Global/",name));
                    continue;
                }
                if(daqsettings_int.includes(name) || daqsettings_bool.includes(name)){
                    box.setAttribute("data-validate", "validate_odb");
                    box.setAttribute("data-odb-editable", "1");
                    box.setAttribute("data-odb-path", create_path("Settings/Daq/",name));
                    box.classList.add("daq_int_setting");
                    continue;
                }

            }
        });
    });
}

//function checks if value is in valid range before writing to ODB
function validate_odb(value, element){
    var setting_name = element.attributes.name.value;
    if(valid_entries.hasOwnProperty(setting_name)){
        if(valid_entries[setting_name].min > value || valid_entries[setting_name].max < value ){
            msg = dlgMessage("Invalid value","Value was not transferred to ODB. Values for " + setting_name + " must be between " + valid_entries[setting_name].min + " and " + valid_entries[setting_name].max + ".", true); 
            return false;
        }
    }
    //else{
    //    msg = dlgMessage("No validation implemented", "Make sure to insert valid values. Value for "+setting_name + " saved to ODB: " + value, true);
    //}
    return true;
}

var mutrig_configureImmediate = false;
// New variant
function mutrig_configureImmediateUpdate(value){
   mutrig_configureImmediate = value;
}

