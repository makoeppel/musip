//**************************************************************************//  
//    Copyright (C) 2020-2025 by Zaher Salman                               //
//    zaher.salman@psi.ch                                                   //
//    jonas.krieger@psi.ch                                                  //
//**************************************************************************//

/*
//moved into init:
let instrODB.logicDir='/Equipment/TDC/Logic/';
let instrODB.histogramDir='/Equipment/TDC/Histograms/';
let instrODB.tdcSettingsDir='/Equipment/TDC/Settings/'
*/


//global variables;
let gTDCbrowsed = false;
let gTDClastLoadfileName = "";

//custom style:
var readTDC_css = `
.tdcNewVal_General{
background-color: yellow;
float: right;
width:50%;
}

.tdcNewVal_Channel{
background-color: yellow;
/*overflow: hidden;
width:50%;*/
}
`;

const tdcstyle = document.createElement('style');
tdcstyle.textContent = readTDC_css;
document.head.appendChild(tdcstyle);

// Define the tdcStatus object to store the TDC status data
let tdcStatus = {
    HistoName: [],
    ScalerName: [],
    Ch: {
       Used: [],
       Type: [],
    }
 };
 
 
/*
  Function to read the TDC status data and update the tdcStatus object
  - modbRead is an modbvalue object
*/
function readTDCstatus() { //shortcut wihtout promise
	readTDCpromise().then(function (){}).catch(function (error) { console.error(error); });
}

function readTDCpromise() {
	return new Promise(function(resolve,reject){
         mjsonrpc_db_get_values([instrODB.histogramDir+'Name',
                            instrODB.logicDir+'Channel_Name', //instrODB.histScalerDir
                            instrODB.logicDir+'Channel_Used',
                            instrODB.logicDir+'Channel_Type']
                         ).then(function (rpc) {
                            tdcStatus['HistoName'] = rpc.result.data[0];
                            tdcStatus['ScalerName'] = rpc.result.data[1];
                            tdcStatus['Ch']['Used'] = rpc.result.data[2];
                            tdcStatus['Ch']['Type'] = rpc.result.data[3];
                            resolve();
                            return;

                         }).catch(function (error) { reject(error); return; });

		});
	}


//required for scaling in data-formula
let TDCresolution= 0.1e-3;//default


/*Save time resolution in a global variable, to use it in data-formula*/
function changedResolution(value) {
    if (value>0) {
       TDCresolution=value;
    }
}



/* 
   The class below defines the Locations, Keys and Data Types for objects
   that correspond to content in the ODB.

   It also contains information of what elements should be put into the 
   ODB if the read TDC-file has empty/undefined elements.
*/
class ODB_element_TDC {
    constructor(location, key, type = '', ifUndefined = '') {
       this.location = location;
       this.key = key;
       this.type = type;
       this.ifUndefined = ifUndefined;
    }
 }

/* 
   Each element of the array below is an object that correspond to 
   the Locations, Keys and Data Types for all the elements that are
   being read from the TDC-file.

   OBS: Everything in the list is in the same order as the content in the TDC-file.
*/
const ODBcontent_generalTDC = [
    // Here follows the properties for the first elements "general information" 
    // from the TDC-file.
    new ODB_element_TDC('/Experiment/', 'Name', 'str', ''),
    new ODB_element_TDC(instrODB.logicDir, 'Description', 'str', ''),
    new ODB_element_TDC(instrODB.logicDir, 'Data_Window', 'int', ''),
    new ODB_element_TDC(instrODB.tdcSettingsDir, 'Type', 'str', ''),
    new ODB_element_TDC(instrODB.tdcSettingsDir, 'Time_Per_Bin', 'str', '0'),
    new ODB_element_TDC(instrODB.logicDir, 'Muon_Delay', 'int', 0),
    new ODB_element_TDC(instrODB.logicDir, 'Positron_Delay', 'int', 0),
    new ODB_element_TDC(instrODB.logicDir, 'Muon_Coincidence_Window', 'int', 0),
    new ODB_element_TDC(instrODB.logicDir, 'Positron_Coincidence_Window', 'int', 0),
    new ODB_element_TDC(instrODB.logicDir, 'Veto_Coincidence_Window', 'int', 0),
    new ODB_element_TDC(instrODB.logicDir, 'T0_OffSet', 'int', 0),
    new ODB_element_TDC(instrODB.logicDir, 'Pre_Pileup_Window', 'int', 0),
    new ODB_element_TDC(instrODB.logicDir, 'Post_Pileup_Window', 'int', 0),
 ]
 
 const ODBcontent_channelTDC = [
    // Here follows the properties for the channels "channel lines" 
    // from the TDC-file.
    new ODB_element_TDC(instrODB.logicDir, 'Channel_Used', 'str', ''),
    new ODB_element_TDC(instrODB.logicDir, 'Channel_Name', 'str', ''),
    new ODB_element_TDC(instrODB.logicDir, 'Channel_Type', 'str', ''),
    new ODB_element_TDC(instrODB.tdcSettingsDir, 'Channel_OffSet', 'int', 0),
    new ODB_element_TDC(instrODB.logicDir, 'Channel_Logic', 'str', ';'),
 ]
 
 const ODBcontent_channelHisto = [
    // Here follows the properties for the channels "channel lines" 
    // from the TDC-file.
    new ODB_element_TDC(instrODB.histogramDir, 'Number', 'int', 0),
    new ODB_element_TDC(instrODB.histogramDir, 'Name', 'str', 'Ch'),
    new ODB_element_TDC(instrODB.histogramDir, 'TDCchannels', 'str', ''),
    new ODB_element_TDC(instrODB.histogramDir, 'T0', 'int', 0),
    new ODB_element_TDC(instrODB.histogramDir, 'FirstGood', 'int', 0),
    new ODB_element_TDC(instrODB.histogramDir, 'LastGood', 'int', 0),
    new ODB_element_TDC(instrODB.histogramDir, 'Length', 'int', 0),
    new ODB_element_TDC(instrODB.histogramDir, 'xUp', 'float', 0),
    new ODB_element_TDC(instrODB.histogramDir, 'xLow', 'float', 0),
    new ODB_element_TDC(instrODB.histogramDir, 'PP_correction_post_logic', 'bool', false),
 ]
 
 /*
   Form the skeleton of the HTML-tab, with hidden
   placeholders that appear when reading a TDC-file.
 
   Read and print the current TDC-settings from the ODB.
 */
 function onloadTDCtab() {
    let channelTable = `<thead>
                     <tr>
                     <th> Ch# </th>
                     <th> Used </th>
                     <th> Name </th>
                     <th> Type </th>
                     <th> OffSet </th>
                     <th> Logic </th>
                     </tr>
                 </thead>`;
    let histoTable = `<thead>
                    <tr>
                    <th> Number </th>
                    <th> Name </th>
                    <th> TDC channels </th>
                    <th> T0 </th>
                    <th> FirstGood </th>
                    <th> LastGood </th>
                    <th> Length </th>
                    <th> xUp </th>
                    <th> xLow </th>
                    <th> PP corr. </th>
                    </tr>
                </thead>`;
 
    // Build Logic configuration Table
    channelTable += '<tbody>';

    //check number of tdc channels
    numTDCch=0
    if (tdcStatus['Ch']['Type']!=null){
        numTDCch=tdcStatus['Ch']['Type'].length;
    }

    for (let i = 0; i < numTDCch; i++) {
       channelTable += '<tr>';
       channelTable += '<td>' + i + '</td>';
       // Print the current settings from the ODB using "modbvalue".
       for (let j = 0; j < ODBcontent_channelTDC.length; j++) {
          channelTable += '<td><span name="modbvalue" class="tdc_editable" data-odb-path=' + ODBcontent_channelTDC[j].location + ODBcontent_channelTDC[j].key + "[" + i + "]" + '></span>';
          channelTable += '<br><span class="tdcNewVal_Channel TDC_LOAD_'+ODBcontent_channelTDC[j].key+'" style="visibility: hidden;"></span></td>'
       }
       channelTable += '</tr>';
    }
    channelTable += '</tbody>';
    document.getElementById("channelTable").innerHTML = channelTable;


    // Build Histogram configuration Table
    histoTable += '<tbody>';

    //check number of tdc channels
    let numHistch=0
    if (tdcStatus['HistoName']!=null){
        numHistch=tdcStatus['HistoName'].length;
    }

    for (let i = 0; i < numHistch; i++) {
        histoTable += '<tr>';
        //histoTable += '<td>' + i + '</td>';
       // Print the current settings from the ODB using "modbvalue".
       for (let j = 0; j < ODBcontent_channelHisto.length; j++) {
        histoTable += '<td><span name="modbvalue" class="tdc_editable" data-odb-path=' + ODBcontent_channelHisto[j].location + ODBcontent_channelHisto[j].key + "[" + i + "]" + '></span>';
        histoTable += '<br><span class="tdcNewVal_Channel TDC_LOAD_'+ODBcontent_channelHisto[j].key+'" style="visibility: hidden;"></span></td>'
       }
       histoTable += '</tr>';
    }
    histoTable += '</tbody>';
    document.getElementById("histogramTable").innerHTML = histoTable;

    // Hide all the space holders.
    toggleVisibility("tdcNewVal_General","hidden");
 
    // Disable the 'Apply' and 'Reset'-button.
    //document.getElementById("loadTDC").disabled = true;
    //document.getElementById("resetTDC").disabled = true;
 }
 


/*Construct Settings table, reset buttons.*/
 function initTDCconfig() {
    onloadTDCtab();
    gTDCbrowsed = false;
    gTDClastLoadfileName="";
    editTDCconfig(false);//disable editing.
 }

/* Toggle button states depending on experiment status*/
function disableByRunStatus() {
    runStopped=document.getElementById("runStatusValue").value == 1
    //Enable only if Run stopped
    if (runStopped) {
      toggleButton("stoppedEditable",set="enable","");
    } else {
      toggleButton("stoppedEditable",set="disable","Stop run to edit.");
      //disable element editing
      editTDCconfig(false);
    }
    // Check if browsing a TDC file:
    if (gTDCbrowsed) {
      toggleButton("activeBrowsed",set="enable","");
    } else {
      toggleButton("activeBrowsed",set="enable","Load a file first.");
    }
    //special case: loading a new file needs stopped and browsed:
    if (gTDCbrowsed && runStopped){
      toggleButton("loadTDC",set="enable","");
    } else {
      toggleButton("loadTDC",set="disable","Stop run and load a file..");
    }
 }

 
/*
   Function to enable browser editing of the TDC configuration.
*/
 function editTDCconfig(enable=true){
   // Find all elements with the tdc_editable class
   const cl_elements = document.querySelectorAll(".tdc_editable");
   cl_elements.forEach((element) => {
      switch (enable) {
         case true:
            element.setAttribute("data-odb-editable","1");
            break;
         case false:
            element.setAttribute("data-odb-editable","0");
            break;
         default:
            console.log(`Error while enabling editing of TDC configuration.`);
            return; 
      }
   });

   // Use a default fileName when editing:
   if(enable==true){
      modbset(instrODB.tdcSettingsDir+'SettingsFile',"Manually edited. Please save!");
   }
   //set a red background color in editing mode:
   const odb_fileName=document.getElementById("TDC_ODB_FILENAME");//current fileName (should be fine without a promise.)
   document.querySelectorAll(".tdc_filename").forEach((element) => {
      // somebody could have forgotten saving the changes:
      if (enable==true || odb_fileName.value=="Manually edited. Please save!"){
            element.style.backgroundColor="red";
      } else{
         element.style.backgroundColor="";
      }
   });
}



/*
   Load a preview of a new configuration
   
   config is a json object with the following content:
   {
      "Instrument": string,
      "Settings": {
         "Channel_OffSet": [],
         "Time_Per_Bin": value,
         "Type": string,
         "SettingsFile": string,
      },
      "Logic": {
         "Description": string,
         "Data_Window": value,
         ... rest of odb fields of logicDir ...
         "Channel_Logic": [],
      },
      "Histograms": {
         "Number": [],
         ... rest of odb fields of histogramDir ...
         "TDCchannels":[],
      },
   }
*/
function browseNewTDCconfiguration(newConfig){   
   //function scope helper functions:
   function DisplayLoadDict(dict) {
      for (const key in dict) {
         if (Array.isArray(dict[key])) {
            DisplayLoadedArray(key, dict[key]);
         } else {
            DisplayLoadedValue(key, dict[key]);
         }
      }
   }
   //helper function
   function DisplayLoadedValue(key,value) {
      try {
         const geninfo = document.getElementById("TDC_LOAD_" + key);
         //parse hexadecimal, e.g. uint
         if (typeof value ==='string' && value.startsWith("0x")){
            value=Number(value);//parse to int.
         }
         geninfo.innerHTML = value;
      }
      catch { // If ID doesn't exist.
         console.error('ID does not exist: TDC_LOAD_', key);
      }
   }
   //helper function
   function DisplayLoadedArray(key,valarray) {
      try {
         const chaninfo = document.getElementsByClassName("TDC_LOAD_" + key);
         if (valarray.legnth>chaninfo.length){
            console.error("Not enough fields to store loaded TDC settings.")
         }
         for(let i=0;i<Math.min(valarray.length,chaninfo.length);i++){
            chaninfo[i].innerHTML=valarray[i];
         }
      }
      catch { // If ID doesn't exist.
         console.error('Classname does not exist: TDC_LOAD_', key);
      }
   }
   
   //TODO: workaround: retain fileneame
   let filename=gTDClastLoadfileName;
   //reset all visibilities 
   initTDCconfig();
   gTDCbrowsed = true;
   disableByRunStatus();
   gTDClastLoadfileName=filename;

   //Potentially, we need to add display only histogram channels:
  let numHistch=0
   if (tdcStatus['HistoName']!=null){
       numHistch=tdcStatus['HistoName'].length;
   }

   let addHistch=newConfig["Histograms"]["Number"].length - numHistch;
 
   addHistoDisplayChannels(addHistch);

   let fileInfo = document.getElementById('TDC_LOAD_FILENAME');
   fileInfo.innerHTML = gTDClastLoadfileName;
   //fileInfo.style = 'visibility: visible;';

   let fileInstr = document.getElementById('TDC_LOAD_INSTRUMENT');
   fileInstr.innerHTML = newConfig["Instrument"];
   //fileInstr.style = 'visibility: visible;';

   DisplayLoadDict(newConfig["Settings"]);
   DisplayLoadDict(newConfig["Logic"]);
   DisplayLoadDict(newConfig["Histograms"]);

   



   toggleVisibility("tdcNewVal_General","visible");
   toggleVisibility("tdcNewVal_Channel","visible");
}

/**
 * Write the content of the last loaded TDC config file into the ODB and reset GUI.
 * Ignore the Instrument field.
 * @param {TDCconfig} newConfig 
 */
function applyNewTDCconfiguration(newConfig){
   //ignoring instrument; but set filename:
   newConfig["Settings"]["SettingsFile"]=gTDClastLoadfileName;
   //paste into odb.

   //The following fails for string arrays. These need an additional {ParamName/key:{"item_size":64}} for every odb parameter
   // That is probably a bug. //TODO check in forum..
   /*
   mjsonrpc_db_paste(
      [       logicDir,          histogramDir,         tdcSettingsDir    ],
      [newConfig["Logic"], newConfig["Histograms"], newConfig["Settings"]]
   ).then(function(rpc) {*/

   //Manually creating paths and values:
   let paths=[];
   let values=[];
   for (key in newConfig["Logic"]){
      paths.push(instrODB.logicDir+key);
      values.push(newConfig["Logic"][key]);
   }
   for (key in newConfig["Histograms"]){
      paths.push(instrODB.histogramDir+key);
      values.push(newConfig["Histograms"][key]);
   }
   for (key in newConfig["Settings"]){
      paths.push(instrODB.tdcSettingsDir+key);
      values.push(newConfig["Settings"][key]);
   }
   
   mjsonrpc_db_paste(paths,values).then(function(rpc) {

      //resize tables:
      readTDCpromise().then(()=>{
         //reset gui
         initTDCconfig();
         disableByRunStatus();
      });

   }).catch(function(error) {
      console.error(error); });

}



/*Add more rows to the histogram table. Doesn't affect odb.*/
function addHistoDisplayChannels(addHistch) {
   const histTableref = document.getElementById('histogramTable').getElementsByTagName('tbody')[0];
   for (let i = 0; i < addHistch; i++) {
      const newRow = histTableref.insertRow();
      for (let j = 0; j < ODBcontent_channelHisto.length; j++) {
         const newCell = newRow.insertCell();
         newCell.appendChild(document.createElement('span'));
         newCell.appendChild(document.createElement('br'));
         let newval_span = document.createElement('span');
         newval_span.classList.add("tdcNewVal_Channel");
         newval_span.classList.add("TDC_LOAD_" + ODBcontent_channelHisto[j].key);
         newCell.appendChild(newval_span);
      }
   }
}


/*
   Write the last loaded configuration (gTDClastLoadfileName) into the odb.
*/
function applyLastTDCConfig(){

   let extension=gTDClastLoadfileName.split('.').pop();

   if (extension=="v1190") {
      loadTDCv1190(gTDClastLoadfileName,applyNewTDCconfiguration);
      return;
   }

   loadTDCconfig(gTDClastLoadfileName,applyNewTDCconfiguration);
}

/**
 * Load a tdc configuration .json file and display it without writing it into the odb.
 * @param {string} fileName : optional, , file name to load. using file_picker if undefined or empty "".
 */
function displayTDCconfig(fileName){
   loadTDCconfig(fileName,browseNewTDCconfiguration);
}

/**
 * 
 *  Load a saved TDC configuration .json file.
 *  and pass it to the callback.
 *
 * @param {string} fileName file name to load. using file_picker if undefined or empty "".
 * @param {function(TDCconfig)} callback   will be called with a configuration .json object.
 */
function loadTDCconfig(fileName, callback){
   // if the file name is not delivered, get it from file_picker
   if (typeof fileName !== "string" || fileName=="") {
      file_picker("/TDC_config", "*.json", loadTDCconfig, false,callback);
      return;
   }
  
   // Save the fileName to the global variable.
   gTDClastLoadfileName = fileName;

   // Fetch the TDC-file and load it as text.
   file_load_ascii(fileName, function(text) {
      callback(JSON.parse(text));
   });


}

/**
 * 
 *  Save the current TDC configuration to a .json file.
 *
 * @param {string} fileName file name to load. using file_picker if undefined or empty "".
 */
function saveTDCconfig(fileName){
   // if the file name is not delivered, get it from file_picker
   if (typeof fileName !== "string" || fileName=="") {
      file_picker("/TDC_config", "*.json", saveTDCconfig, true);
      return;
   }

   //Make a list of all the displayed variables. Don't save anything else!!
   let displayedODBkeys=[]
   for (elem of ODBcontent_generalTDC.concat(ODBcontent_channelTDC,ODBcontent_channelHisto)){
      displayedODBkeys.push(elem.key);
   }
   //function scope helper function to achieve that
   function rejectAdditionalKeys(obj){
      let reto={}
      for(key in obj){
         if (displayedODBkeys.includes(key)){
            reto[key]= obj[key];
         }
      }
      return reto;
   }

   //Get a "clean" extract, without metadata:
   let request=new Object();
   request.paths=["/Experiment/Name",instrODB.tdcSettingsDir,instrODB.logicDir,instrODB.histogramDir];
   request.omit_names=true;
   request.omit_last_written=true;
   request.omit_tid=true;
   request.omit_old_timestamp=true;
   request.omit_old_timestamp=true;
   request.preserve_case=true;//readability

   mjsonrpc_call("db_get_values", request).then(function(rpc) {
      let config={};
      config["Instrument"]=rpc.result.data[0];
      config["Settings"]=rejectAdditionalKeys(rpc.result.data[1]);
      config["Logic"]=rejectAdditionalKeys(rpc.result.data[2]);
      config["Histograms"]=rejectAdditionalKeys(rpc.result.data[3]);
      //convert to a string
      let configJson=JSON.stringify(config, null, '   ');
      //save
      file_save_ascii(fileName, configJson, "ODB TDC configuration saved to file \"" + fileName + "\".");
   }).catch (function (error) {
      console.error(error);
   });
}

/*
   Load a historic v1190 TDC configuration file.
   Highlight the chosen settings next to the current settings.

   fileName: optional, file name to load. using file_picker if undefined or empty "".


*/
function displayTDCv1190(fileName){
   loadTDCv1190(fileName,browseNewTDCconfiguration);
}

/*
   Load a historic v1190 TDC configuration file.
   and parse it into a configuration json object, which then gets passed to callback.

   fileName: file name to load. using file_picker if undefined or empty "".
   callback: function, will be called with a configuration .json object.


*/
 async function loadTDCv1190(fileName,callback){
   //TODO: this function cannot deal with the On/Off channel settings. (needed?)

   if (!callback) {//check if it was provided
      console.error("loadTDCv1190: missing callback.")
      return;}

   // function scope helper functions, to reduce repeated code.
   function HistObj_to_loadConfig(loadConfig, histNumber, main_histo_channels, ch) {
      loadConfig["Histograms"]["Number"][histNumber] = histNumber + 1;
      loadConfig["Histograms"]["Name"][histNumber] = main_histo_channels[ch].Name;
      loadConfig["Histograms"]["T0"][histNumber] = main_histo_channels[ch].T0;
      loadConfig["Histograms"]["FirstGood"][histNumber] = main_histo_channels[ch].FirstGood;
      loadConfig["Histograms"]["LastGood"][histNumber] = main_histo_channels[ch].LastGood;
      loadConfig["Histograms"]["TDCchannels"][histNumber] = String(ch);
      for (addch of main_histo_channels[ch].addHist) {
         loadConfig["Histograms"]["TDCchannels"][histNumber] += " " + String(addch);
      }
   }

   // Finds the first instance of a string in an array and returns its index
   function findIndexTDC(array, word) {
      var regex = new RegExp("\\b" + word + "\\b");
      for (var i = 0; i < array.length; i++) {
         if (regex.test(array[i])) {
            return i; // Return the index if the word is found
         }
      }
      return -1; // Return -1 if the word is not found in any string
   }

   function findFirstNumberedIndexTDC(string, first) {
      let indexNumbering = 0;
      for (let x = 0; x < string.length; x++) {
         if ((string[x].charAt(0) == '!' || !isNaN(string[x].charAt(0))) && first) {
            indexNumbering = x;
            first = false;
         }
      }
      return indexNumbering;
   }



   // if the file name is not delivered, get it from file_picker
   if (typeof fileName !== "string" || fileName=="") {
      file_picker("/TDC_config", "*.v1190", loadTDCv1190, false, callback);
      return;
   }


   // Save the fileName to the global variable.
   gTDClastLoadfileName = fileName;

   // Fetch the TDC-file and load it as text.
   file_load_ascii(fileName, async function(text) {

      // Split each row
      let newdataTest = text.split('\n');
   
      // Find the first crucial element of the TDC file which 
      // spererates the general information of the TDC and 
      // the individual channel lines.
      let index = findIndexTDC(newdataTest, 'INSTRUMENT');
   
      let newdata = text.split('\n').slice(index);
   
      // Remove all the comments and unneccesary information from the TDC-file
      const charsToCheck = ['\r', '$', '', '#'];
      for (let x = 0; x < newdata.length; x++) {
         if (charsToCheck.includes(newdata[x])) {
            newdata.splice(x, 1);
            x--;
         }
      }
   
      // Remove all unneccecary indents and empty spaces in each element
      newdata.forEach((element, index) => {
         newdata[index] = element.replace(/^\s+|\s+$/g, '').replace(/["/]+/g, '');
      });
   
      // Dividing the general information and channel lines into two arrays
      let indexNumbering = findFirstNumberedIndexTDC(newdata, true);
      let generalInformation = newdata.slice(0, indexNumbering);
      let channelLine = newdata.slice(indexNumbering);
   
      // Splitting each channel with ';'
      channelLine = channelLine.map(element => element.split(";").map(item => item.trim()));
      generalInformation = generalInformation.map(element => element.split("=").map(item => item.trim()));
      // Removing empty elements 
      channelLine.forEach(element => {
         if (element[element.length - 1] == '') {
            element.pop();
         }
      });
   
      // Removes space between '! #ch' so we get '!#ch'.
      channelLine.forEach((element, index) => {
         channelLine[index][0] = element[0].replace(/\s/g, '');
      });
   
      // Replace the '!#ch' to the Channel_Used type which 
      // is 'n' if '!' else 'y'.
      for (let i = 0; i < channelLine.length; i++) {
         try {
            // Here we remove the '!' from Histo_Name.
            if (channelLine[i][5].charAt(0) == '!') channelLine[i][5] = channelLine[i][5].slice(1);
            channelLine[i][0] = (channelLine[i][0].charAt(0) == '!' ? 'n' : 'y');
         }
         catch { channelLine[i][0] = (channelLine[i][0].charAt(0) == '!' ? 'n' : 'y'); }
      }
   
      
      //parse into a json object in the new format:
      //initialize containers.
      let loadConfig={
         "Settings": {
            "Channel_OffSet":[],
         },
         "Logic": {
            "Channel_Used":[],
            "Channel_Name":[],
            "Channel_Type":[],
            "Channel_Logic":[],
         },
         "Histograms": {
            "Number":[],
            "Name":[],
            "Length":[],
            "xLow":[],
            "xUp":[],
            "T0":[],
            "FirstGood":[],
            "LastGood":[],
            "PP_correction_post_logic":[],
            "TDCchannels":[],},
      };


      // parse general section:
      for (let i = 0; i < generalInformation.length; i++) {
         switch(generalInformation[i][0]){
            case("INSTRUMENT"):
               loadConfig["Instrument"]=generalInformation[i][1];
               break;
            case("DESCRIPTION"):
               loadConfig["Logic"]["Description"]=generalInformation[i][1];
               break;
            case("TYPE"):
               loadConfig["Settings"]["Type"]=generalInformation[i][1];
               break;
            case("RESOLUTION"):
               loadConfig["Settings"]["Time_Per_Bin"]=generalInformation[i][1];
               break;
            case("MDELAY"):
               loadConfig["Logic"]["Muon_Delay"]=generalInformation[i][1];
               break;
            case("PDELAY"):
               loadConfig["Logic"]["Positron_Delay"]=generalInformation[i][1];
               break;
            case("MCOINCIDENCEW"):
               loadConfig["Logic"]["Muon_Coincidence_Window"]=generalInformation[i][1];
               break;
            case("PCOINCIDENCEW"):
               loadConfig["Logic"]["Positron_Coincidence_Window"]=generalInformation[i][1];
               break;
            case("VCOINCIDENCEW"):
               loadConfig["Logic"]["Veto_Coincidence_Window"]=generalInformation[i][1];
               break;
            default:
               console.log("Unknown tdc configuration element: ", generalInformation[i][0]);
               break;
         }
      }


      let histlength = await mjsonrpc_db_get_value(instrODB.logicDir+"Data_Window").then((rpc)=>{
        return Number(rpc.result.data[0])+1;//Data_Window+1
        }).catch (function (error) { console.error(error);});
        console.log(histlength);


      //defaults for missing values in old files:
      let channelLineDefaults =[
         "n", // channel used
         "Ch", //channel name
         "N", // Detector type
         0, // t_offset
         ";", //coincidence channel+ anti coincidence channels
         "Ch", // histogram name
         0, //t0
         1,//first
         histlength-1,// last
         "", //add to histogram
         "", // name of combined histogram
      ];

      let loaded_value=0;


      //histograms are resulting directly from the channels
      //additional combined histograms can be created and pre-pendend.
      let main_histo_channels={};//TDCchannelnumber: histogram object.
      let additional_histo_channels={};//TDCchannelnumber: histogram object.

      // parse channel specific section:
      for (let i = 0; i <channelLine.length; i++){
         let ch_used=false;
         for(let j = 0; j <11; j++){//length may vary, order should be fixed....
            let loaded_value=channelLine[i][j];
            // if not present, take a default.
            if (typeof loaded_value === 'undefined') {
               loaded_value=channelLineDefaults[j];
               if (j==1||j==5){//channel or histogram name add channel number.
                  loaded_value+=i;
               }
            }
            switch(j){
               case 0://channel used
                  loadConfig["Logic"]["Channel_Used"][i]=loaded_value;
                  if (loaded_value.toLowerCase()=="y"){
                     ch_used=true;
                  }
                  break;
               case 1: // Detector name
                  loadConfig["Logic"]["Channel_Name"][i]=loaded_value;
                  break;
               case 2: // Detector type
                  loadConfig["Logic"]["Channel_Type"][i]=loaded_value;
                  //add a new histogram //assuming for now it is a main one.
                  if (loaded_value.toUpperCase()=="P"&&ch_used){
                     main_histo_channels[i]={addHist:[]};
                  }
                  break;
               case 3: // t_offset
                  loadConfig["Settings"]["Channel_OffSet"][i]=loaded_value;
                  break;
               case 4: //coincidence channel+ anti coincidence channels
                  loadConfig["Logic"]["Channel_Logic"][i]=loaded_value;
                  break;
               case 5: // histogram name
                  if(i in main_histo_channels){
                     main_histo_channels[i].Name=loaded_value;
                  }
                  break;
               case 6: //t0
                  if(i in main_histo_channels){
                     main_histo_channels[i].T0=loaded_value;
                  }
                  break;
               case 7://first
                  if(i in main_histo_channels){
                     main_histo_channels[i].FirstGood=loaded_value;
                  }
                  break;
               case 8:// last
                  if(i in main_histo_channels){
                    if (loaded_value>=histlength){//That would not be reasonable. Default to histogram lenght.
                        main_histo_channels[i].LastGood=histlength-1;
                    }else{
                        main_histo_channels[i].LastGood=loaded_value;
                    }
                  }
                  break;
               case 9: //add to histogram
                  if (loaded_value== ""||loaded_value== -1){
                     break;//primary histogram, nothing to do.
                  }
                  if (!(loaded_value in main_histo_channels )){
                     //something went wrong, there is no positron histogram we can add to:
                     console.error("Unknown history channel: ", loaded_value);
                     //skip to next channel
                     continue;
                  }
                  //check if we need to make a copy of the primary channel to a seperate additional histogram:
                  if (main_histo_channels[loaded_value].addHist.length==0){
                     additional_histo_channels[loaded_value]=structuredClone(main_histo_channels[loaded_value]);
                  }
                  main_histo_channels[loaded_value].addHist.push(i);
                  //copy current histogram to additional channels
                  additional_histo_channels[i]=structuredClone(main_histo_channels[i]);
                  //remove it from main channels
                  delete main_histo_channels[i];
                  break;
               case 10: // name of combined histogram 
                  //check if it is there:
                  if (loaded_value!= ""&&loaded_value.toUpperCase()!= "NONE"){
                     //find out where to add it to:
                     let addTo=channelLine[i][9];
                     if ((addTo!=='undefined') &&(addTo in main_histo_channels)){
                        main_histo_channels[addTo].Name=loaded_value;
                     }
                  }
                  break;
               default:
                  console.log("Unknown tdc configuration element: ", channelLine[i][j]);
                  break;
            }

         }
         
      }

      // parse history configuration:
      let histNumber=0;
      for (const ch in main_histo_channels){
         //function scope helper function
         HistObj_to_loadConfig(loadConfig, histNumber, main_histo_channels, ch);
         histNumber++;

      }
      for (const ch in additional_histo_channels){
         //function scope helper function
         HistObj_to_loadConfig(loadConfig, histNumber, additional_histo_channels, ch);
         histNumber++;
      }

      //add default configurations
      for (let i=0;i<loadConfig["Histograms"]["Number"].length;i++){
         loadConfig["Histograms"]["Length"][i]=histlength;
         loadConfig["Histograms"]["xLow"][i]=-0.5;
         loadConfig["Histograms"]["xUp"][i]=histlength-0.5;
         loadConfig["Histograms"]["PP_correction_post_logic"][i]="y";
      }

      //change unit on resolution:
      if (loadConfig["Settings"]['Time_Per_Bin']>1){//ps to mu s
         loadConfig["Settings"]['Time_Per_Bin']/=1000000;
      }
      //NOTE: the old value for the resolution was usually only approximately correct.
      //Do not load the value!!
      delete loadConfig["Settings"]['Time_Per_Bin'];

      callback(loadConfig);
   });
    
}

/** separate function to handle a data-window input change, in order to avoid races 
 * between the set button, and hitting enter on the input field.
 * Calls changeDataWindow() when necessary.
 */
function dataWindowInputChanged(){
    //try doing nothing:
    return;
    /*
    let changeButton = document.getElementById("tdc_DatWindow_button");
    //if button is already not on set anymore: nothing to do.
    console.log(changeButton.value);
    if (changeButton.value!="Set"){
        return;
    }
    //otherwise, do the equivalent of pressing the button.
    changeDataWindow();*/
}

/*Functionality to handle the GUI functionality of chaning the data window*/
function changeDataWindow() {

    let valueODB = document.getElementById("tdc_DatWindow_odb");
    let valueInput = document.getElementById("tdc_DatWindow_input");
    let changeButton = document.getElementById("tdc_DatWindow_button");

    //Determine the state of the page
    //Look at style.display, which in the default state shows valueODB
    let mode_changing=(valueODB.style.display!="none");

    //switch display and text to the other mode.
    if (mode_changing){ // Hide the link and display the input box
        valueODB.style.display = 'none';
        changeButton.value="Set";
        valueInput.style.display = 'inline';
        valueInput.value = parseFloat(valueODB.textContent); // Set the input value to the current value
        // Automatically select the input box when the "Change" button is clicked
        valueInput.focus();
    }
    else {
        valueODB.style.display = 'inline';
        changeButton.value="Change";
        valueInput.style.display = 'none';

        let newValue = parseFloat(valueInput.value);
        // get time per bin

       mjsonrpc_db_get_value(instrODB.tdcSettingsDir+"Time_Per_Bin").then((rpc)=>{
            let time_per_bin =  Number(rpc.result.data[0]);//Data_Window+1
            //Determine Data window
            newValue=Math.round(newValue/time_per_bin);        
            // If entered value is valid
            if (!isNaN(newValue)) {
                updateDataWindow(newValue);
            }
        }).catch (function (error) { console.error(error);});
    }
 }
 
/**
 * Update the data window and histogram lengths in the odb.
 * 
 * Data_Window=dataWindow
 * Histogram Legnth=dataWindow+1
 * xUp=dataWindow+0.5
 * LastGood=dataWindow
 * Pre_Pileup_Window = dataWindow
 * Post_Pileup_Window = dataWindow, unless 0.
 * 
 * @param {Number} dataWindow in number of tdc bins.
 * */
function updateDataWindow(dataWindow){
    //change values
    modbset(instrODB.logicDir+"Data_Window",dataWindow);
    modbset(instrODB.logicDir+"Pre_Pileup_Window",dataWindow);

    mjsonrpc_db_get_value(instrODB.logicDir+"Post_Pileup_Window").then((rpc)=>{
        let postPileupWindow=rpc.result.data[0];
        //only update it, if it is not zero.
        if (postPileupWindow!=0){
            modbset(instrODB.logicDir+"Post_Pileup_Window",dataWindow);}
    }).catch (function (error) { console.error(error);});

    //simultaneously change arrays
    //determine length first
    mjsonrpc_db_get_value(instrODB.histogramDir+"Length").then((rpc)=>{
        let histLenghts=rpc.result.data[0];
        if(Array.isArray(histLenghts)){
            let len=histLenghts.length-1;//last index to adress array with.
            //set all array elements to the same value
            modbset(instrODB.histogramDir+"Length[0-"+len+"]",dataWindow+1);
            modbset(instrODB.histogramDir+"xUp[0-"+len+"]",dataWindow+0.5);
            modbset(instrODB.histogramDir+"LastGood[0-"+len+"]",dataWindow);
        } else{
            console.error("Unable to change Histogram lengths. Not an array.")
        }
    }).catch (function (error) { console.error(error);});
};

 
/* ---------------------------------------------------------------------------------------
 * 
 * Functions for the TDC statistics page
 *
-----------------------------------------------------------------------------------------*/



/** 
* Function to read the TDC status data and update the tdcStatus object
*/
function loadTDCstatus() {
   // Histogram and Scaler table ID:s.
   tableIDs = ['Histo', 'Scaler'];
   for (j in tableIDs) {
      let tableID = tableIDs[j];
      if (document.getElementById(tableID) == undefined) return;
      let str = '';


      // Construct the skeleton for the Histo table
      if (tableID == 'Histo') {
         str = `<tr>
            <td style="position: sticky; top: 2px; text-align: center; background-color: gray; border-radius: 0px;">H#</td>
            <td style="position: sticky; top: 2px; text-align: center; background-color: gray;">Name</td>
            <td style="position: sticky; top: 2px; text-align: center; background-color: gray;">Rate</td>
            <td style="position: sticky; top: 2px; text-align: center; background-color: gray;">Total</td>
            <!--td style="position: sticky; top: 2px; text-align: center; background-color: gray; border-radius: 0px;">Saved</td-->
            </tr>`;
      }
      // Construct the skeleton for the Scalers table
      else {
         str = `<tr>
            <td style="position: sticky; top: 2px; text-align: center; background-color: gray; border-radius: 0px;">Name</td>
            <td style="position: sticky; top: 2px; text-align: center; background-color: gray;">Rate</td>
            <td style="position: sticky; top: 2px; text-align: center; background-color: gray;">Total</td>
            <td style="position: sticky; top: 2px; text-align: center; background-color: gray; border-radius: 0px;">Rejected Rate</td>
            </tr>`;
      }

      //Scaler

      // Retrieve the relevant data from tdcStatus based on the tableID
      const ScalerName = tdcStatus['ScalerName'];
      
      for (let i = 0; i < ScalerName.length; i++) {
         // Only fill if channel does not start with 'Ch' and channel_used is 'true'/'y'.
         if (ScalerName[i][0] !== 'C' && ScalerName[i][1] !== 'h' && tdcStatus['Ch']['Used'][i] === true) {
            let tempName = '';
            if (tableID === 'Scaler') {
               str += `<tr>
                            <td>${ScalerName[i]}</td>
                            <td><span name="modbvalue" data-odb-path="`+instrODB.histScalerDir+`channelRate[${i}]"
                                    data-format="%f1" ></span></td>
                            <td><span name="modbvalue" data-odb-path="`+instrODB.histScalerDir+`channelCounts[${i}]"
                                    data-format="%f2" data-formula="x/1000000"></span> M</td>
                            <td><span name="modbvalue" data-odb-path="`+instrODB.histScalerDir+`rejectedRate[${i}]"
                                    data-format="%f1" ></span></td>
                            </tr>`;
            }
         }
      }

      //Histograms

      // Retrieve the relevant data from tdcStatus based on the tableID
      const HistoName = tdcStatus['HistoName'];
      
      for (let i = 0; i < HistoName.length; i++) {
         /// If table is 'Histo', add a numbered index aside the 'Name'.
            if (tableID === 'Histo') {
               str += `<tr>
                            <td><span name="modbvalue" data-odb-path="`+instrODB.histogramDir+`Number[${i}]"></span></td>
                            <td>${HistoName[i]}</td>
                            <td><span name="modbvalue" data-odb-path="/Equipment/TDC/Histogram_Statistics/Histogram Rates[${i}]"
                                    data-format="%f1" ></span></td>
                            <td><span name="modbvalue" data-odb-path="/Equipment/TDC/Histogram_Statistics/Histogram Counts[${i}]"
                                    data-format="%f2" data-formula="x/1000000"></span> M</td>
                            <!--td><span name="modbvalue" data-odb-path="/Equipment/tdcv11900/Histo/Hsaved/0/histoSaved[${i}]"></span></td-->
                            </tr>`;
            }
            
      }
      // Set the HTML content of the table element to the generated string
      document.getElementById(tableID).innerHTML = str;
   }
}

/**
 * Functions placed in other files on pc12788, but needed for TDC tab:
 */


// Function to enable/disable a class 
// clname - class name to toggle
// set    - string "toggle", "enable" "disable" to specify behavior
// title  - optional, title to set.
// "enable" removes disabled , "disable" sets disabled  and 
// "toggle" changes depending on the current value.
function toggleButton(clname,set="toggle",title) {
   let selector = "." + clname; 
   // Find all elements with the correct class and hide/show
   const btnEls = document.querySelectorAll(selector);
   btnEls.forEach((element) => {
      switch (set) {
         case "enable":
            element.disabled=false;
            break;
         case "disable":
            element.disabled=true;
            break;
         case "toggle":
            element.disabled=!element.disabled;
            break;
         default:
            console.log(`Error in chaning disabled value of ${element}.`);
            return; 
      }
         if (typeof title !== undefined){
            element.title=title;
         }
   });
}




// This function will be called (once) after loading Mudas.html
function onloadTDC() {
   /* // TODO: might need re-enabling.
   readTDCstatus();
   loadTDCstatus();
   resetTDC();*/
   readTDCpromise().then(function (){
      //loadTDCstatus();
      initTDCconfig(); 
      }).catch(function (error) { console.error(error); });
}


// Function to change visibility of a class 
// clname - class name to toggle
// set    - string "toggle", "enable" "disable" to specify behavior
// "visible" sets visible , "hidden" sets hidden
// "toggle" changes depending on the current value.
function toggleVisibility(clname,set="toggle") {
   let selector = "." + clname; 
   // Find all elements with the correct class and hide/show
   const clEls = document.querySelectorAll(selector);
   clEls.forEach((element) => {
      switch (set) {
         case "visible":
            element.style.visibility='visible';
            break;
         case "hidden":
            element.style.visibility='hidden';
            break;
         case "toggle":
            if(element.style.visibility=='hidden'){
               element.style.visibility='visible';
            }else{
               element.style.visibility='hidden';
            }
            break;
         default:
            console.log(`Error in chaning visibility of ${element}.`);
            return; 
      }
   });
}