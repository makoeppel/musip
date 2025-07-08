//**************************************************************************//  
//    Copyright (C) 2020-2025 by Zaher Salman                               //
//    zaher.salman@psi.ch                                                   //
//**************************************************************************//

//**************************************************************************//  
// Mudas CSS                                                                //
//**************************************************************************//  
var mudas_css = `
html { font-size: 100%;}

* {
    box-sizing: border-box;
}

td {
    white-space: nowrap;
/*    font-size: 10vw;*/
}

.guitable {
    background-color: #DDDDDD;
    border: 0px;
    width: 100%;
    height: 100%;
    /*  border-collapse: collapse; */
    border-radius: 10px;
    border: none;
    border-spacing: 0px;
    /*padding: 2px;*/
    padding-left: 5px;
    padding-right: 5px;
    padding-top: 0px;
    padding-bottom: 0px
    margin-left: auto;
    margin-right: auto;
    margin-top: 0px;
    margin-bottom: 0px;
}
.guitable tr:last-child td:first-child {
/*    font-size: 10vw;*/
    border-bottom-left-radius: 12px;
}
.guitable tr:last-child td:last-child {
    border-bottom-right-radius: 12px;
}
.guitable tr:first-child td:first-child {
    border-top-left-radius: 12px;
}
.guitable tr:first-child td:last-child {
    border-top-right-radius: 12px;
}
.guitable tr:nth-child(odd) {
    background-color: #DDDDDD;
}
.guitable tr:nth-child(even) {
    background-color: #DDDDDD;
}

.oddeven tr:nth-child(odd) {
    background-color: #DDDDDD;
}
.oddeven tr:nth-child(even) {
    background-color: #F2F2F2;
}

/* For mobile phones: */
[class*="col-"] {
    width: 100%;
    float: left;
    padding: 2px;
    overflow:hidden; 
    border: none;
}

    
@media only screen and (min-width: 990px) {
    /* For desktop: */
    .col-1 {width: 50%;background-color: #F2F2F2;}
    .col-2 {width: 50%;background-color: #F2F2F2;}
    .col-full {width: 100%;background-color: #F2F2F2;}
    .col-1a {width: 33.333%;background-color: #F2F2F2;padding-right:0px;}
    .col-2a {width: 33.333%;background-color: #F2F2F2;}
    .col-3a {width: 33.333%;background-color: #F2F2F2;}
} 

.row::after {
    content: "";
    clear: both;
    display: table;
}
.left_td{
    padding-left: 1em;
    vertical-align:top;
    text-align:left;
}
.right_td{
    padding-right: 1em;
    vertical-align:top;
    text-align:right;
}
.group_name {
    padding-left:1em;
    padding-right:1em;
    font-size:1.05rem;
    font-weight:bold;
    width: 1%;
    white-space: nowrap;
    text-align: left; 
}
.yellow_td {
    padding-left:1em;
    padding-right:1em;
    background-color: yellow;
    width: 1%;
    white-space: nowrap;
    font-size: 1rem;
}
.gray_td {
    padding-left:1em;
    padding-right:1em;
    background-color: gray;
    width: 1%;
    white-space: nowrap;
}
.nocol_td {
    padding-left:1em;
    padding-right:1em;
    width: 1%;
    min-width: 9rem;
    white-space: nowrap;
}

/* Style the tab */
.tab {
    overflow: hidden;
    border: 1px solid #ccc;
    background-color: #f1f1f1;
}

tab.active {
    background-color: #11f1f1;
}

/* Style the buttons that are used to open the tab content */
.tab button {
    background-color: inherit;
    float: left;
    border: none;
    outline: none;
    cursor: pointer;
    padding: 14px 16px;
    transition: 10.3s;
    font-size:1.1rem;
    font-weight:bold;
}

/* Style the tab content */
.tabcontent {
    display: none;
    height: 100%;
    flex: 1; /* Add this to ensure full height */
    overflow: auto; /* Add scroll if content overflows */
    box-sizing: border-box; /* Include padding in height */
}

/* Active tab state */
.tabcontent.active {
    display: flex; /* Changed to flex for better layout */
    flex-direction: column;
}

/* Ensure content fills the tab */
.tabcontent > * {
    flex: 1;
    min-height: 0; /* Important for proper flex sizing */
}

/* Go from zero to full opacity */
@keyframes fadeEffect {
    from {opacity: 0;}
    to {opacity: 1;}
}

.scaler_head_left {
    text-align:left; 
    padding-left:1em;
    padding-right:1em;
}
.scaler_head_right {
    text-align:right; 
    padding-left:1em;
    padding-right:1em;
}
.scaler_name {
    padding-left:1em;
    padding-right:1em;
}
.scaler_val {
    text-align:right; 
    padding-right:1em;
}


/* For the AutoRun tab */
.lar_label {
    text-align:left; 
    padding-left:1em;
    padding-right:1em;
}
.lar_label_right {
    text-align:right; 
    padding-left:1em;
    padding-right:1em;
}
.lar_value {
    text-align:left;
    padding-left:1em;
    padding-right:1em;
}
.lar_script {
    text-align:left;
    font-family:Fixed;
    font-size: 1rem;
    line-height:1.25;
}
.lar_fatal {
    background-color: #FF0000;
    font-weight: bold;
}
.lar_err {
    background-color: #FF8800;
    font-weight: bold;
}
.lar_msg {
    background-color: #11FF11;
    font-weight: bold;
}
.lar_current_cmd {
    background-color: #FFFF00;
    font-weight: bold;
}
.lar_comment {
    color: grey;
    font-style: italic;
}

/*LOOP_ WAIT TITLE START TOF FIELD TEMP */
.lar_command {
    color: #C81A1C;
    font-weight: bold;
}

/*ODB_TAG ALIAS */
.lar_tag {
    color: #0A6E2B;
    font-weight: bold;
}

/*ODB_TAG ALIAS */
.lar_ntag {
    color: #8E0F7E;
}

/*ODB_TAG ALIAS */
.lar_otag {
    color: #9F4511;
}

/*ODB_PARAM ALIAS */
.lar_par {
    color: #1817A2;
    font-style: italic;
}

.lar_odb {
    color: #D3AF37;
}

.lar_loop {
    color: #8E0F7E;
    font-weight: bold;
}

.lar_area {
    max-width:90vw;
    width:100%; 
    height:40vh; 
    overflow:auto; 
    resize:both;
    background-color:white;
    overflow-wrap: break-word;
    caret-color: red;
    padding: 5px 10px 5px 10px;
    white-space: pre;
    font-family: monospace;
    display: block;
}

/* Red/Green Mode */
#PulsOn {
    width: 15px;
    height: 15px;
    background-color: red;
    position: relative;
    -webkit-animation-name: example; /* Chrome, Safari, Opera */
    -webkit-animation-duration: 2s; /* Chrome, Safari, Opera */
    -webkit-animation-iteration-count: infinite; /* Chrome, Safari, Opera */
    animation-name: example;
    animation-duration: 3s;
    animation-iteration-count: infinite;
}

/* Chrome, Safari, Opera */
@-webkit-keyframes example {
    0%   {background-color:red; left:20px; top:0px;}
    25%  {background-color:orange; left:25px; top:0px;}
    50%  {background-color:green; left:30px; top:0px;}
    75%  {background-color:orange; left:25px; top:0px;}
    100% {background-color:red; left:20px; top:0px;}
}

/* Standard syntax */
@keyframes example {
    0%   {background-color:red; left:20px; top:0px;}
    25%  {background-color:orange; left:25px; top:0px;}
    50%  {background-color:green; left:30px; top:0px;}
    75%  {background-color:orange; left:25px; top:0px;}
    100% {background-color:red; left:20px; top:0px;}
}

/* HV table highlight */
.tdSelectable:hover {
    background-color: yellow;
}

.tdSelected {
    background: yellow;
}

.tdIgnorable:hover {
    background-color: red;
}

.tdIgnored {
    background: red;
}

/* Proposal ID checks */
.propIDcorrect {
    background: red;
}


/* Vacuum related */
.chamber {
    stroke: #000000;
    stroke-width: 2px;  
    fill: #E0E0E0;
}
.pump_line {
    stroke: #505050;
    stroke-width: 5px;  
    fill: none;
}

/* The switch - the box around the slider */
.switch {
  position: relative;
  display: inline-block;
  width: 30px;
  height: 17px;
}

/* Hide default HTML checkbox */
.switch input {
  opacity: 0;
  width: 0;
  height: 0;
}

/* The slider */
.slider {
  position: absolute;
  cursor: pointer;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: #ccc;
  -webkit-transition: .4s;
  transition: .4s;
}

.slider:before {
  position: absolute;
  content: "";
  height: 13px;
  width: 13px;
  left: 2px;
  bottom: 2px;
  background-color: white;
  -webkit-transition: .4s;
  transition: .4s;
}

input:checked + .slider {
  background-color: green;
}

input:focus + .slider {
  box-shadow: 0 0 1px #2196F3;
}

input:checked + .slider:before {
  -webkit-transform: translateX(13px);
  -ms-transform: translateX(13px);
  transform: translateX(13px);
}

/* Rounded sliders */
.slider.round {
  border-radius: 17px;
}

.slider.round:before {
  border-radius: 50%;
}
`;

const mudas_style = document.createElement('style');
mudas_style.textContent = mudas_css;
document.head.appendChild(mudas_style);

//**************************************************************************//  
// Generic functions for midas                                              //
//**************************************************************************//
function mjsonrpc_error_alert(error) {
   console.error(error);
}

// Function to stop an ongoing run
function stopRun() {
   let flag = confirm('Are you sure you want to stop the run?');
   if (flag == true) {
      mjsonrpc_call("cm_transition", {"transition": "TR_STOP"}).then(function (rpc) {
         if (rpc.result.status !== 1) {
            throw new Error("Cannot stop run, cm_transition() status " + rpc.result.status + ", see MIDAS messages");
	 }
      }).catch(function (error) {
	 console.error(error);
      });
   }
}

// Function to pause an ongoing run
function pauseRun() {
   let flag = confirm('Are you sure you want to pause the run?');
   if (flag == true) {
      mjsonrpc_call("cm_transition", {"transition": "TR_PAUSE"}).then(function (rpc) {
         if (rpc.result.status !== 1) {
            throw new Error("Cannot pause run, cm_transition() status " + rpc.result.status + ", see MIDAS messages");
	 }
      }).catch(function (error) {
	 console.error(error);
      });
   }
}

// Function to resume a paused run
function resumeRun() {
   let flag = confirm('Are you sure you want to resume the run?');
   if (flag == true) {
      mjsonrpc_call("cm_transition", {"transition": "TR_RESUME"}).then(function (rpc) {
         if (rpc.result.status !== 1) {
            throw new Error("Cannot resume run, cm_transition() status " + rpc.result.status + ", see MIDAS messages");
	 }
      }).catch(function (error) {
	 console.error(error);
      });
   }
}

// Function to start a run
function startRun() {
   let flag = confirm('Are you sure you want to start the run?');
   if (flag == true) {
      mjsonrpc_call("cm_transition", {"transition": "TR_START"}).then(function (rpc) {
         if (rpc.result.status !== 1) {
            throw new Error("Cannot start run, cm_transition() status " + rpc.result.status + ", see MIDAS messages");
	 }
      }).catch(function (error) {
	 console.error(error);
      });
   }
}


//**************************************************************************//
// Generic functions JS                                                      //
//**************************************************************************//

// Function to remove element by id
function removeElement(elementId) {
   var element = document.getElementById(elementId);
   if (element) element.parentNode.removeChild(element);
}

// Function to check whether an element exists or not
function existElement(elementId) {
   var element = document.getElementById(elementId);
   if (element)
      return true;
   else
      return false;
}

// Function to add element in parent
function addElement(parentId, elementTag, elementId, html) {
   var p = document.getElementById(parentId);
   var newElement = document.createElement(elementTag);
   newElement.setAttribute('id', elementId);
   newElement.innerHTML = html;
   p.appendChild(newElement);
}

// Function to change content of element id
function setIfChanged(id, text)
{
   var e = document.getElementById(id);
   if (e) {
      if (e.innerHTML != text) {
         e.innerHTML = text;
      }
   }
}

//**************************************************************************//	
// Functions for general Mudas use                                          //
//**************************************************************************//	

// Global variables
var updateTimerId = 0;
var updatePeriod = 1000; // in msec
var startupCount = 0;

// Function to run onload to setup needed options and update period of GUI
// Called only once, onload.
function Mudas_init_once() {
   // update run state
   runStatus();
   // Configure setup 
   setupInit();
   // hide side menu
   // mhttpd_show_menu(0);
   // Check proposal ID against DUO
   propODB(0);
   // Setup APD page
   showSegment();
   // Update link to musrfit
   updateFitLink();
   // Update cryostat page
   updateSamcryo();
   // Transport options
   selColl("none");
   // HV settings
   mkEquipmentTable("HV",0,15,"HVTable");
   mkEquipmentTable("Beamline",0,39,"blTable");
   //prepEditor();
   // add event listiners to lar editor area
   checkSyntaxEvent();
}

// Function to run onload to setup needed options and update period of GUI
// Called periodically
function Mudas_init() {
   // HIPA status update
   document.getElementById("HIPAimg").src = "https://gfa-status.web.psi.ch/hipa-info-1024x768.png" + "?" + Date();

   // AutoRun update
   load_lar();
   
   // Check alarms
   triggerAlarms();

   // Vacuum update
   update_vacuum();

   // Running time update
   // This is a workaround, needed only for running time
   runStatus();

   // timing update
   clearTimeout(updateTimerId);
   if (updatePeriod > 0) {
      if (updatePeriod == 500) {
         startupCount++;
         if (startupCount > 2)
	    updatePeriod = 3000;
      }
      updateTimerId = setTimeout('Mudas_init()', updatePeriod);
   }
}

// This function fills the modbvalue tags with the appropriate data_odb_path
// The ODBs should be defined in instrODB ([INSTR]init.js)
function fillODBs() {
   for (let key in instrODB) {
      var element = document.getElementById(key);
      if (element) {
	 // if the element exists then fill the correct path
	 element.setAttribute("data-odb-path",instrODB[key]);
      }
   }

   // Elog link
   let elogElem = document.getElementById("elogLink");
   if (elogLink == "") {
      // hide Elog field
      elogElem.style.visibility = "hidden";
   } else {
      // set the correct link
      elogElem.setAttribute("href",elogLink);
   }

   // Title of page and instumenat name/color
   document.title = instrName + " Mudas";
   let instrBanner = document.getElementById("instrName");
   instrBanner.innerHTML = "<span style='color: white;width:300px;padding: 0.3em 0.5em 0.3em 0.5em;border-radius:10px;font-style: oblique;font-weight: bold;background-color:"+instrColor+";'>Mudas "+instrName+"</span>";
   let mTables = document.getElementsByClassName("mtable");
   for (const mTable of mTables) {
      mTable.style.border = '1px solid ' + instrColor;
   }
}

// This function fills the tabs according to the init file 
// The tabs should be defined in instrTabs ([INSTR]init.js)
function fillTabs() {
    // create two containers
    let tabBtns = document.getElementById("tabBtns");
    let tabMenu = document.getElementById("tabMenu");
    let tabFrames = document.getElementById("tabFrames");
    let beforeMenu = document.getElementById("beforeMenu");
    let HIPA = document.getElementById("100");
    // tab counter
    let iTab=0;
    for (let key in instrTabs) {
	iTab++;
        let d = document.createElement("div");
        d.id = "Tab" + iTab;
        d.className = "tabcontent";
        let f = "<iframe src='/tabs/" + instrTabs[key].htmlFile + "'style='height:500px;width:100%;' onload='this.before((this.contentDocument.body||this.contentDocument).children[0]);this.remove();'></iframe>";
        d.innerHTML= f;
        let b = document.createElement("button");
        if (instrTabs[key].style == "Menu") {
            b = document.createElement("a");
	}
	b.id = iTab;
	b.className = "w3-bar-item w3-button w3-round";
	b.setAttribute("onclick","openTab(event,this.id);" + instrTabs[key].addFunc);
	b.innerHTML = "<b>" + instrTabs[key].label + "</b>";
	//b.onload = "openTab(event,this.id);" + instrTabs[key].addFunc;
	
	// Append elements
	if (instrTabs[key].style == "Tab") {
	    tabBtns.insertBefore(b,beforeMenu);
	} else {
	    tabMenu.insertBefore(b,HIPA);
	}
	tabFrames.appendChild(d);
    }
}

// This function checks for triggered alarms and add them to Mudas
function triggerAlarms() {
   mjsonrpc_db_get_values(["/Alarms"]).then(function(rpc) {
      alarm = rpc.result.data[0];
      //console.log(alarm);
      //console.log(alarm['alarm system active']);
      if (alarm["alarm system active"]) {
         var allAlarms = alarm["alarms"]
         for (var element in allAlarms) {
	    if (allAlarms[element]["triggered"] && allAlarms[element]["active"]) {
               if (document.getElementById(element + "Alarm") === null) {
		  var newAlarm = document.getElementById("alarmsTable").insertRow(0);
		  var bgcol = "var(--mred)";
		  if (allAlarms[element]["alarm class"] == "Warning") {
		     bgcol = "var(--myellow)";
		  } else if (allAlarms[element]["alarm class"] == "Message") {
		     bgcol = "var(--mgreen)";
		  }
		  newAlarm.id = element + "Alarm";
		  newAlarm.className = "alarmRow";
		  newAlarm.style.backgroundColor = bgcol;
		  let alarmHTML = "<td align=center style='font-weight: bold;'>\n"+allAlarms[element]["alarm class"]+":"+allAlarms[element]["alarm message"];
		  alarmHTML += "<button class='mbutton' type='button' style='float:right;' onclick=\"mhttpd_reset_alarm('" + element + "');\">Reset</button>\n</td>\n";
		  newAlarm.innerHTML = alarmHTML;
               }
	    } else {
	       if (document.getElementById(element + "Alarm") != null) {
		  document.getElementById(element + "Alarm").remove();
               }
	    }
         }
      }
   }).catch(function(error){console.error(error);});
}

//**************************************************************************//	
// Functions for Run Control tab                                            //
//**************************************************************************//	

// Function to check run state and adjust controls accordingly
// run_state = -2     check ODB and adjust accordingly
//              1     run is stopped
//              2     run is paused
//              3     run is ongoing
function runStatus(run_state) {
   mjsonrpc_db_get_values([instrODB["runStatus"]]).then(function(rpc) {
      run_state = rpc.result.data[0];
      // Change accordingly in GUI
      // due to strange behaviour of mjsonrpc I have to send action to different function
      if (run_state == 1) {
	 // Stopped
	 runStatus_action(1);
      } else if (run_state == 2) {
	 // Paused
	 runStatus_action(2);
      } else if (run_state == 3) {
	 // Running
	 runStatus_action(3);
      }
   }).catch(function(error){console.error(error);}); 
}    

// Function to set the buttons visibility according to run status
// run_state =  1     run is stopped
//              2     run is pauseden
//              3     run is ongoing
function runStatus_action(run_state) {
   // No buttons to adjust
   if (!document.getElementById("startButton")) return;

   //   let common_style = 'padding: 0.3em 0.5em 0.3em 0.5em;border-radius:10px;box-shadow: 5px 5px 5px grey;'
   let common_style = 'padding: 0.0em 1.0em 0.0em 1.0em;border-radius:5px;box-shadow: 5px 5px 5px grey;width:150px;'
   if (document.getElementById("runStatusBanner")) {
      document.getElementById("runStatusBanner").innerHTML = '<span id="statusText" style="'+common_style+'"></span>';
   }
   let statText = "";
   let statCol = "";
   // Change accordingly in GUI
   if (run_state == 1) {
      // Stopped - red, make only Start visible
      document.getElementById("startButton").disabled = false;
      document.getElementById("stopButton").disabled = true;
      document.getElementById("pauseButton").disabled = true;
      document.getElementById("resumeButton").disabled = true;
      document.getElementById("writeButton").disabled = true;
      statCol = 'var(--mred)';
      statText = 'Stopped';
      // Insert stop time
      document.getElementById("stopTimetd").innerHTML = 'Stop time: ';
   } else if (run_state == 2) {
      // Paused - orange, make Stop and Resume visible 
      document.getElementById("startButton").disabled = true;
      document.getElementById("stopButton").disabled = false;
      document.getElementById("pauseButton").disabled = true;
      document.getElementById("resumeButton").disabled = false;
      document.getElementById("writeButton").disabled = false;
      statCol = 'var(--myellow)';
      statText = 'Paused';
      // Insert running time
      document.getElementById("stopTimetd").innerHTML = 'Run time: ';
      runningTime(run_state);
   } else if (run_state == 3) {
      // Running - green, make Stop and Pause visible
      document.getElementById("startButton").disabled = true;
      document.getElementById("stopButton").disabled = false;
      document.getElementById("pauseButton").disabled = false;
      document.getElementById("resumeButton").disabled = true;
      document.getElementById("writeButton").disabled = false;
      statCol = 'var(--mgreen)';
      statText = 'Running';
      // Insert running time time
      document.getElementById("stopTimetd").innerHTML = 'Run time: ';
      runningTime(run_state);
   }   
   let statusText = document.getElementById("statusText");
   statusText.style.backgroundColor = statCol;
   statusText.innerHTML = statText;
}

// Function to set the running time field
// run_state =  1     run is stopped
//              2     run is pauseden
//              3     run is ongoing
function runningTime(run_state) {
   let stopTime = document.getElementById("stopTime");
   // If running or paused
   if (run_state != 1) {
      // hide stopped time
      stopTime.style.visibility = "hidden";   
      // show running time
      mjsonrpc_db_get_values(["/Runinfo"]).then(function(rpc) {
         runinfo = rpc.result.data[0];
         time = runinfo['start time binary/last_written'];
         difftime = Math.round(new Date().getTime() / 1000) - time;
         h = Math.floor(difftime / 3600);
	 m = Math.floor(difftime % 3600 / 60);
	 s = Math.floor(difftime % 60);
	 runTime = h + "h" + ((m<10)?"0"+m:m) + "m" + ((s<10)?"0"+s:s) + "s";
	 document.getElementById("vstopTimetd").innerHTML = runTime;
      }).catch(function(error){console.error(error);});
   } else {
      // show stopped time
      stopTime.style.visibility = "visible";  
   }
}

// Function to make link to musrfit
function updateFitLink() {
   // ToDo: check measurement geometry and guess function/histos
   let aelement = document.getElementById("musrfitRun");
   let fitlink = "http://musruser.psi.ch/cgi-bin/musrfit.cgi?";
   let belement = document.getElementById("SearchDBlink");
   let dblink = "http://musruser.psi.ch/cgi-bin/SearchDB.cgi?";
   let year = new Date().getFullYear();
   fitlink += "YEAR="+year;
   fitlink += "&BeamLine="+instrName.split("-")[0];
   dblink += "YEAR="+year;
   dblink += "&AREA="+instrName.split("-")[0];
   mjsonrpc_db_get_values([instrODB["runNumber"],instrODB["sampleName"]]).then(function(rpc) {
      let runNumber = rpc.result.data[0];
      let sampleName = rpc.result.data[1];
      if (window.location.href.includes("/CS/Mudas"))
         sampleName = sampleName.substring(0,9);
      sampleName= sampleName.replaceAll("(","\\(").replaceAll(")","\\)");
      sampleName= sampleName.replaceAll("[","\\[").replaceAll("]","\\]");
      fitlink += "&RunNumbers="+runNumber;
      dblink += "&Phrases="+ sampleName +"&go=Search";
      aelement.setAttribute("href",fitlink);
      belement.setAttribute("href",dblink);
   }).catch(function(error){console.error(error);});
}



//**************************************************************************//	
// End of Run Control tab                                                   //
//**************************************************************************//	


//**************************************************************************//	
// Function for general use                                                 //
//**************************************************************************//	


// Function to toggele div visible/hidden
function showHide(iddiv,sender) {
   let totoggle = document.getElementById(iddiv);
   if (totoggle === null) return;
   let state = totoggle.style.display;

   if (state == 'none') {
      totoggle.style.display = "block";
   } else {
      totoggle.style.display = "none";
   }

   let symbol = sender.innerHTML;
   if (symbol == "-") {
      sender.innerHTML = "+";
      sender.title = "Show information row";
   } else if (symbol == "+") {
      sender.innerHTML = "-";
      sender.title = "Hide information row";
   } else if (iddiv ==  "infoRow" && symbol == "🗖") {
      sender.innerHTML = "&#128471;";
      sender.title = "Restore";
   } else if (iddiv ==  "infoRow" && symbol == "🗗") {
      sender.innerHTML = "&#128470;";
      sender.title = "Maximize";
   }
}

// Function to swap iddiv1 and iddiv2 positions
function swapDiv(iddiv1,iddiv2,arrow) {
   let element1 = document.getElementById(iddiv1);
   let element2 = document.getElementById(iddiv2);
   
   if (arrow.innerHTML == "\u2191") { 
      element1.parentNode.insertBefore(element1,element2);
      arrow.innerHTML = "&darr;";
      arrow.title = "Move down";
   } else {
      element2.parentNode.insertBefore(element2,element1);
      arrow.innerHTML = "&uarr;";
      arrow.title = "Move up";
   }
}

// Function to compare proposal ID with DUO schedule
// TODO: if not matching highlight in red with option to change 
function compProp(prop_odb,proposer_odb,pgrp_odb,flag) {
   // flag = 0 - check values and highlight only
   //      = 1 - check, highlight and change on request
   let fullname;
   let d= new Date();
   d.setHours(d.getHours() - 6);
   let curr_date = d.toISOString().slice(0,-5);
   let instrument = instrName.toLowerCase();
   if (instrument === "musip") instrument="lmu development";
   //let web_duo = 'https://duo.psi.ch/duo/rest.php/cal/smus/'+instrument+'/'+curr_date+'/?SECRET=change-bib-eva-grille';
   let web_duo = 'https://duo.psi.ch/duo/api.php/v1/CalendarInfos/scheduled/smus?beamline='+instrument+'&SECRET=change-bib-eva-grille';
   // let web_duo = 'https://duo.psi.ch/duo/rest.php/cal/smus/lem/'+curr_date+'/?SECRET=change-bib-eva-grille';
   console.log(web_duo);
   fetch(web_duo,{method:'POST'})
      .then( data => data.json(), console.error)
      .then( data => {
         let proposer_duo = "Thomas Prokscha";
         let prop_duo = "20210284";
         let pgrp_duo = "p18973";
         let extratxt = "\ndoes not match the empty schedule!\nShould I use the default values?";
         if (data[0] !== undefined) {
            proposer_duo = data[0].firstname+" "+data[0].lastname;
            prop_duo = data[0].proposal;
            pgrp_duo = data[0].pgroup;
            extratxt = "\ndoes NOT match schedule!\n"+prop_duo+"/"+proposer_duo+"/"+pgrp_duo+"\nShould I take the details from DUO?";
         }
         if ((prop_odb != prop_duo) || (proposer_odb != proposer_duo) || (pgrp_odb != pgrp_duo)) {
	    document.getElementById("propID").className = "propIDcorrect";
	    document.getElementById("propGRP").className = "propIDcorrect";
	    document.getElementById("propPI").className = "propIDcorrect";
            document.getElementById("propBtn").className = "propIDcorrect";
	    document.getElementById("propFromDuo").style.visibility = "visible";
	    if (flag) {
	       if (confirm("Proposal ID\n"+prop_odb+"/"+proposer_odb+"/"+pgrp_odb+extratxt)) {
		  modbset(instrODB["pID"],prop_duo);
		  modbset(instrODB["pPI"],proposer_duo);
		  modbset(instrODB["pGRP"],pgrp_duo);
		  // Then reset highlights/button
		  document.getElementById("propID").className = "";
		  document.getElementById("propGRP").className = "";
		  document.getElementById("propPI").className = "";
                  document.getElementById("propBtn").className = "";
		  document.getElementById("propFromDuo").style.visibility = "hidden";
	       }
	    }
	 } else {
	    document.getElementById("propID").className = "";
	    document.getElementById("propGRP").className = "";
	    document.getElementById("propPI").className = "";
            document.getElementById("propFromDuo").style.visibility = "hidden";
         }
         // console.log('proper_duo:', data.firstname+" "+data.lastname);
      });
}

// Function to check proposal ID against DUO schedule.
// If not matching highlight in red and show button 
function propODB(flag) {
   // flag = 0 - check values and highlight only
   //      = 1 - check, highlight and change on request
   mjsonrpc_db_get_values([instrODB["pID"],instrODB["pPI"],instrODB["pGRP"]])
      .then(function(rpc) {
	 let prop_odb = rpc.result.data[0];
	 let proposer_odb = rpc.result.data[1];
	 let pgrp_odb = rpc.result.data[2];
	 compProp(prop_odb,proposer_odb,pgrp_odb,flag);
      });
}

function midasCustom(tab) {
   if (tab === undefined || tab === null) tab = 1;  
   let url = window.location.href;
   if (url.search("tab=") === -1 || url.search("Mudas") === -1) {
      // if url is not Mudas then load it first
      window.history.replaceState({}, "", `?cmd=custom&page=Mudas&tab=${tab}`);
      window.location.reload();
   }

   openTab("",tab);
}


// Function to change to selected tab
function openTab(evt, tab) {
    // Check arguments and set default values if undefined
    if (tab === undefined) tab = 1;
    let tabName = "Tab"+tab;
    let activeTab = document.getElementById(tabName);
    let activeBtn = (evt) ? evt.currentTarget : document.getElementById(tab);
    if (!activeTab) return;

    // Get all elements with class="tabcontent" and hide them
    let tabcontent = document.getElementsByClassName("tabcontent");
    for (let i = 0; i < tabcontent.length; i++) {
        tabcontent[i].classList.remove("active");
    }
    
    // Get all elements with class="tablinks" and remove the class "active"
    let tablinks = document.getElementsByClassName("w3-bar-item");
    for (let i = 0; i < tablinks.length; i++) {
        tablinks[i].className = tablinks[i].className.replace(" active", "");
        tablinks[i].className = tablinks[i].className.replace(" w3-gray", "");
    }

    // Show the selected tab and add an "active" class to the button that opens it
    activeTab.classList.add("active");
    activeBtn.className += " active";
    activeBtn.className += " w3-gray";
    
    let reg = /tab=\d+/;
    let url = window.location.href;
    if (url.search("tab=") == -1) {
        // if tab is not in url add it but check which version of midas we are dealing with
        if (url.includes("/CS/Mudas")) {
            url += "?tab="+tab;
        } else {
            url += "&tab="+tab;
        }
    } else {
        // otherwise replace with new tab value
        url = url.replace(reg,"tab="+tab)
    }
    if (url !== window.location.href) {
        window.history.replaceState({}, "", url);
    }
    getVars["tab"] = tab;
}

//**************************************************************************//	
// End general use                                                          //
//**************************************************************************//	


//**************************************************************************//	
// Function for AutoRun tab                                                 //
//**************************************************************************//	
const LAR_TT_IDLE     = 0;
const LAR_TT_FINISHED = 1;
const LAR_TT_ABORTED  = 2;
const LAR_TT_WARMUP   = 3;

var larObj = {};
var liveData = {};
var larState;
var prevRunState = -1;
var transitionTag = LAR_TT_IDLE;
var firstValidRunState = true;
var larStateCol = 'var(--mred)';
var larStateText = 'Stopped';


// Function to update AutoRun tab
function load_lar() {
   // get autorun data from ODB
   mjsonrpc_db_get_values(["/AutoRun"]).then(function(rpc) {
      larObj = rpc.result.data[0];
   }).catch (function (error) {
      console.error(error);
   });
   
   larState = larObj['run state'];
   liveData = larObj['livedata'];
   
   if ((larState !== undefined) && firstValidRunState) {
      firstValidRunState = false;
      prevRunState = larState;
      load_buttons();
   }
   // check if the run state has changed
   if (prevRunState != larState) {
      prevRunState = larState;
      load_buttons();
      // speed up update period at larState change
      updatePeriod = 500;
      startupCount = 0;
   }

   if (liveData) {
      transitionTag = liveData['transitiontag'];
      update_lar_script(liveData, larObj['show comments']);
   }
}

// Function to parse AutoRun script into html
function update_lar_script(liveData, showComment) {
   var errIdx=-1;
   var num = "";
   let edtArea = document.getElementById('lar');
   if (edtArea === null) return;
   var content="", str="", msg="";
   // This holds the autorun text
   var lar = liveData['autorun'];
   var errorNo = liveData['errorinline'];
   var errorMsg = liveData['errormsg'];
   var foundError = false;
   var isComment = false;
   
   // check for fatal-errors without lar-script (e.g. missing, ...)
   if (errorNo[0] === 0) {
      content = "<span class=\"lar_fatal\">" + errorMsg[0] + "</span>";
      edtArea.innerHTML = content;
      return;
   }
   if (errorNo[0] != -1)
      foundError = true;
   
   // add sequence only loaded info
   if ((liveData['currentlineno'] == -1) && (errorNo[0] == -1)) {
      content = "<span class=\"lar_msg\">&gt;&gt; SEQUENCE LOADED ONLY, PRESS START AUTORUN BOTTOM IF YOU WANT TO START IT &lt;&lt;</span>\n";
   }
   // in case there are errors display a prominent message at the begining
   if (errorNo[0] != -1) {
      content = "<span class=\"lar_fatal\">&gt;&gt; ERRORS ENTCOUNTERED, PLEASE FIX IT! &lt;&lt;</span>\n";
   }
   
   // Send lar to syntax highlighting
   lar = syntax_lar(lar);

   // normal lar-script handling
   for (var i=0; i<lar.length; i++) {
      // check if comments shall be suppressed
      var str = lar[i].trim();
      if (!showComment) {
         if (str.length == 0)
	    continue;
         if (str.charAt(0) == "%")
	    continue;
      }
      isComment = false;
      if ((str.charAt(0) == "%") || (str.length == 0)) {
         isComment = true;
      } 
      
      // generate numbering
      num="<span style='user-select: none;'>"+(i+1).toString().padStart(3)+": </span>";
      
      // check if it is the current line -> highlight  
      if ((liveData['currentlineno'] == (i+1)) && !foundError && (liveData['currentlineno'] <= lar.length)) {
         if (transitionTag == LAR_TT_ABORTED) {
	    content += num + lar[i] + "\n";         
	    content += "<span class=\"lar_err\">             ^--- AutoRun aborted here.</span>\n";
         } else {
	    if (liveData['loopval'] == "empty")
	       content += "<span class=\"lar_current_cmd\">" + num + lar[i] + "</span>\n";
	    else
	       content += "<span class=\"lar_current_cmd\">" + num + lar[i] + " (LOOP_ELEMENT=" + liveData['loopval'] + ")</span>\n";
         }
      } else {
         if (isComment) {
	    content += "<span class=\"lar_comment\">" + num + lar[i] + "</span>\n";
         } else {
	    if (liveData['loopval'] == "empty")
	       content += num + lar[i] + "\n";
	    else
	       content += num + lar[i] + "\n";
         }
      }
      
      // check for errors
      errIdx = check_for_error(i, errorNo);
      if (errIdx != -1) {
         content += "<span class=\"lar_err\">             ^---" + errorMsg[errIdx] + "</span>\n";
      }
   }
   // Add autorun status
   switch (transitionTag) {
   case LAR_TT_FINISHED:
      msg = "<span class=\"lar_msg\">&gt;&gt; Autorun finished ...</span>\n";
      str = content;
      content = msg.concat(str);
      content += msg;
      break;
   case LAR_TT_ABORTED:
      msg = "<span class=\"lar_err\">&gt;&gt; Autorun aborted ...</span>\n";
      str = content;
      content = msg.concat(str);
      content += msg;
      break;
   case LAR_TT_WARMUP:
      msg = "<span class=\"lar_msg\">&gt;&gt; Autorun finished ...</span>\n";
      str = content;
      content = msg.concat(str);
      content += msg;
      break;
   default:
      break;
   }
   // Fill html of script in appropriate div
   edtArea.innerHTML = content;
   // Now you need to scrill to current line
   // scrollToCurr();
}

function check_for_error(idx, errorNo) {
   for (var i=0; i<errorNo.length; i++)
      if (errorNo[i]-1 == idx)
         return i;
   return -1;
}



// Function to produce syntax highlighted lar
function syntax_lar(lar) {
   // lar is an array of lines
   let cmds = ["FIELD","TEMP","SAMPLE_HV","SPIN_ROT","TRANSPORT_HV","START","STOP","LOOP_SAMPLE_HV","RA_HV","DEGAUSS_MAGNET","WARMUP"];
   let cmdssec = ["TITLE","TFL","TOF","WAIT","ODB_SET_DATA","BPVX","BPVY"];
   let tags = ["ODB_TAG","ALIAS"];
   let pars = ["ODB_FIELD","ODB_TEMP","ODB_TRANSP","ODB_ENERGY","ODB_RA_DIFF_LR","DB_HV_SAMP","ODB_RA_DIFF_LR","ODB_SAMPLE","LOOP_ELEMENT","LOOP_LIST","ODB_SPIN_ROT","ODB_HV_SAMP"];
   let loops = ["LOOP_START","LOOP_ITER","LOOP_ITERATOR","LOOP_TEMP","LOOP_FIELD_WEWL","LOOP_FIELD_WEWH","LOOP_FIELD_DANFYSIK","LOOP_FIELD","LOOP_END"];
   let i,j;

   // Keep original 
   let lar_org = lar;
   if (Array.isArray(lar)) {
      // Join all lines in one string
      var lar_text = lar.join("\n");
   } else {
      var lar_text = lar;
   }
   
   // These can be done on the text in one go
   // Parameters group
   for (i=0;i<pars.length;i++){
      let reg = new RegExp("\\b"+pars[i]+"\\b","g");
      lar_text = lar_text.replaceAll(reg,"<span class='lar_par'>"+pars[i]+"</span>");
   }

   // Loops group
   for (i=0;i<loops.length;i++){
      let reg = new RegExp("\\b"+loops[i]+"\\b","g");
      lar_text = lar_text.replaceAll(reg,"<span class='lar_loop'>"+loops[i]+"</span>");
   }


   // Commands group
   for (i=0;i<cmds.length;i++){
      let reg = new RegExp("\\b"+cmds[i]+"\\b","g");
      lar_text = lar_text.replaceAll(reg,"<span class='lar_command'>"+cmds[i]+"</span>");
   }

   // Secondary Commands group
   for (i=0;i<cmdssec.length;i++){
      let reg = new RegExp("\\b"+cmdssec[i]+"\\b","g");
      lar_text = lar_text.replaceAll(reg,"<span class='lar_tag'>"+cmdssec[i]+"</span>");
   }

   // These needs line by line treatment
   for (j=0;j<lar.length;j++) {
      let line = lar[j].trim();
      
      // Tags group
      if (line.startsWith(tags[0]) || line.startsWith(tags[1])) {
	 // should give 3 words
	 let words = line.split(/(\s+)/).filter( function(e) { return e.trim().length > 0; } ); 
	 // the first lar_tag
	 lar_text = lar_text.replaceAll(words[0],"<span class='lar_tag'>"+words[0]+"</span>");
	 lar_text = lar_text.replaceAll(words[1],"<span class='lar_ntag'>"+words[1]+"</span>");
	 lar_text = lar_text.replaceAll(words[2],"<span class='lar_otag'>"+words[2]+"</span>");
      }
   }

   // Break lines and handle one by one
   lar = lar_text.split("\n");
   // Loop backwards, remove empty lines at end keeping only one 
   // then restore comment lines with no highlighting
   let isEmpty = 1;
   for (j=lar.length-3;j>=0;j--) {
      let line = lar[j].trim();
      // Empty line skip it 
      if (line == "" & isEmpty == 1) {
	 // Remove empty lines (optional)
	 //lar.splice(j,1);
	 // Replace empty lines with <br>
	 //lar[j] = "<br>";
      } else {
	 isEmpty = 0;
	 // Restore comment lines with no highlighting
	 if (line.startsWith("%")) {
	    lar[j]=lar_org[j];
	 }
      }
   }
   return lar;
}

// Function to change the status of AutoRun
function setLARstate(val) {
/* STOPPED  = 0;
   PAUSED   = 1;
   STARTING = 2;
   RUNNING  = 3;
   LOAD     = 4;
   LOADING  = 5;
   NEXT     = 6; */

   let message = '';
   // Need confirmation for start and stop
   if (val == 2) {
      message = 'Are you sure you want to start the autorun?';
   } else if (val == 0) {
      message = 'Are you sure you want to stop the autorun?';
   } else if (val == 4) {
      modbset('/AutoRun/LiveData/CurrentLineNo', -1);
   }

   if (message === '') {
      modbset('/AutoRun/Run State', val);
   } else {
      dlgConfirm(message, function(resp) {
         if (resp) {
            modbset('/AutoRun/Run State', val);
         }
      });
   }
   load_buttons();
}

// Function to create the right button depending on AutoRun state
function setLARState(larState) {
   const state = [
      "Stopped",  // 0
      "Paused",   // 1
      "Starting", // 2
      "Running",  // 3
      "Load",     // 4
      "Loading",  // 5
      "Next"      // 6
   ];
   const color = [
      "var(--mred)",  // 0
      "var(--myellow)",   // 1
      "var(--myellow)", // 2
      "var(--mgreen)",  // 3
      "var(--mred)",     // 4
      "var(--mred)",  // 5
      "var(--myellow)"      // 6
   ];

   let larStatusSpan = document.getElementById("AutorRunState");
   larStatusSpan.style.backgroundColor = color[larState.value];
   larStatusSpan.innerHTML = state[larState.value];
}


//**************************************************************************//	
// End AutoRun tab                                                          //
//**************************************************************************//	


//**************************************************************************//	
// Functions for the moderator tab                                          //
//**************************************************************************//	
// Start autorun depending on selection 
function autorunCommand(command)
{
   if (command != 'Idle') {
      // Get confirmation from user before proceeding
      let result=confirm('Are you sure you want to run '+command);
      if (result == false) {
         // Set back to Idle and return without doing anything
         document.getElementById('Command').value = "Idle";
         return;
      } else {
         // Get another confitrmation
         result=confirm('Are you sure you want to run '+command);
         if (result == false) {
            // Set back to Idle and return without doing anything
            document.getElementById('Command').value = "Idle";
            return;
         }
      }
      
      // Set autorun name in ODB
      modbset('/AutoRun/Auto Run Sequence',command);
      // Check whether the name was changed, maybe also load
      // Trigger autorun start
      modbset('/AutoRun/Run State', 2);
      // Check if things went as planned or give an alert.
   }
}
//**************************************************************************//	
// End Moderator tab                                                        //
//**************************************************************************//	

//**************************************************************************//	
// Functions for Setup tab                                                  //
//**************************************************************************//	

// Function to initialize the Setup Configuration page following the current state of the ODB
function setupInit()
{
   // Check state of FE and change accordingly
   // Make sure you send the right FE name and optional ID for checkbox
   feIsRunning("QL564P_SC");
   feIsRunning("QL564P_Ta_SC");
   feIsRunning("K2400_SC");
   feIsRunning("Bluepoint_SC");
   feIsRunning("K3390_SC");

   // Now check cryostat and adjust accordingly
   mjsonrpc_db_get_values(["/Info/Sample Cryo"]).then(function(rpc) {
      if (rpc.result.data[0] == "Omega") {
	 // Also hide needle valve row from Run Control
	 if (document.getElementById('NVRow')) {
	    document.getElementById('NVRow').style.display = 'none';
	 }
	 if (document.getElementById('RateRow')) {
	    document.getElementById('RateRow').style.display = 'none';
	 }
	 if (document.getElementById('FlowRow1')) {
	    document.getElementById('FlowRow1').style.display = 'none';
	    document.getElementById('FlowRow2').style.display = 'none';
	 }
	 if (document.getElementById('histTLink')) {
	    document.getElementById('histTLink').setAttribute("onclick","mhistory_dialog('Omega','Temp');");
	 }
	 if (document.getElementById('sampleTemp')) {
	    document.getElementById('sampleTemp').setAttribute("data-odb-path","/Equipment/Omega/Variables/Input[0]");
	    document.getElementById('sampleTempD').setAttribute("data-odb-path","/Equipment/Omega/Variables/Output[0]");
	    document.getElementById('sampleTempR').setAttribute("data-odb-path","/Equipment/Omega/Variables/Input[0]");
	    document.getElementById('sampleTemp').setAttribute("data-formula","x+273");
	    document.getElementById('unitTD').innerHTML = "C";
	    document.getElementById('unitTR').innerHTML = "C";
	 }
      } else if (rpc.result.data[0] == "LowTemp-2") {
	 // Also hide needle valve row from Run Control
	 if (document.getElementById('NVRow')) {
	    document.getElementById('NVRow').style.display = 'none';
	 }
	 if (document.getElementById('RateRow')) {
	    document.getElementById('RateRow').style.display = '';
	 }
	 if (document.getElementById('FlowRow1')) {
	    document.getElementById('FlowRow1').style.display = '';
	    document.getElementById('FlowRow2').style.display = '';
	 }
	 if (document.getElementById('histTLink')) {
	    document.getElementById('histTLink').setAttribute("onclick","mhistory_dialog('LowTemp','SampleTemp');");
	 }
	 if (document.getElementById('sampleTemp')) {
	    document.getElementById('sampleTemp').setAttribute("data-odb-path","/Equipment/SampleCryo/Variables/Input[0]");
	    document.getElementById('sampleTempD').setAttribute("data-odb-path","/Equipment/SampleCryo/Variables/Output[0]");
	    document.getElementById('sampleTempR').setAttribute("data-odb-path","/Equipment/SampleCryo/Variables/Input[0]");
	    document.getElementById('unitTD').innerHTML = "K";
	    document.getElementById('unitTR').innerHTML = "K";
	 }
      } else {
	 if (document.getElementById('NVRow')) {
	    document.getElementById('NVRow').style.display = '';
	 }
	 if (document.getElementById('RateRow')) {
	    document.getElementById('RateRow').style.display = '';
	 }
	 if (document.getElementById('FlowRow1')) {
	    document.getElementById('FlowRow1').style.display = '';
	    document.getElementById('FlowRow2').style.display = '';
	 }
	 if (document.getElementById('histTLink')) {
	    document.getElementById('histTLink').setAttribute("onclick","mhistory_dialog('SampleCryo','SampleTemp');");
	 }
	 if (document.getElementById('sampleTemp')) {
	    document.getElementById('sampleTemp').setAttribute("data-odb-path","/Equipment/SampleCryo/Variables/Input[0]");
	    document.getElementById('sampleTempD').setAttribute("data-odb-path","/Equipment/SampleCryo/Variables/Output[0]");
	    document.getElementById('sampleTempR').setAttribute("data-odb-path","/Equipment/SampleCryo/Variables/Input[0]");
	    document.getElementById('unitTD').innerHTML = "K";
	    document.getElementById('unitTR').innerHTML = "K";
	 }
      }
   }).catch(function(error){console.error(error);});
}

function updateSetupPars(setup) {
   let [sample,magnet]=setup.split(", ");
   // initialize all as "n"
   let parMCP2 = "n";
   let parSample = "n";
   let parWEW = "n";
   let parBpar = "n";
   // first compare to ODB, if it is the same return
   mjsonrpc_db_get_values(["Info/LEM_Setup"]).then(function(rpc) {
      if (sample == "MCP2") {
	 parMCP2 = "y";
      } else if (sample == "Sample") {
	 parSample = "y";
      }
      
      if (magnet == "WEW") {
	 parWEW = "y";
      } else if (magnet == "Bpar") {
	 parBpar = "y";
      }

      modbset("/Info/LEM_Setup_Parameter/MCP2",parMCP2);
      modbset("/Info/LEM_Setup_Parameter/Sample",parSample);
      modbset("/Info/LEM_Setup_Parameter/WEW",parWEW);
      modbset("/Info/LEM_Setup_Parameter/Bpar",parBpar);
   }).catch (function (error) {console.error(error);}); 
}


// Function to check if a frontend is running.
// e - is a checkbox element, e.id is the name of the FE program
function feIsRunning(e) {
   console.log(e);
   if (!e) {
      return false;
   } else if (typeof e === "string") {
      e = document.getElementById(e);
   }
   mjsonrpc_call("cm_exist", { "name": e.id, "unique":false}).then(function(rpc) {
      let state = (rpc.result.status === 1);
      if (e) e.checked = state;
      return state;
   }).catch (function(error) {
      console.error(error);
   });
}

// This function starts/stops front end
// name - fronend name, e.g. "K2400_SC"
// action - Can be "start"/1 or "stop"/0 action
function eqStart (name,action) {
   if (action.toLowerCase() === "start" || action === 1) {
      console.log(Starting,name);
      mjsonrpc_start_program(name);
   } else if (action.toLowerCase() === "stop" || action === 0) {
      console.log(Stopping,name);
      mjsonrpc_stop_program(name);
   }
}

function cryoSetup(cryo) {       
   // Get new value from argument
   // first compare to ODB, if it is the same return
   mjsonrpc_db_get_values(["/Info/Sample Cryo"]).then(function(rpc) {
      if (rpc.result.data[0] == cryo) {
	 return 0;
      } else {
	 // variables for hide/show FE
	 let hide_sc,hide_ov,hide_om;
	 // variables for start/stop FE
	 let fe_sc,fe_ov,fe_om;

	 // all equipment are hidden by default
	 hide_sc = "y";
	 hide_ov = "y";
	 hide_om = "y";
	 hide_tfl = "y";
	 // all FEs are off by default
	 fe_sc = "Stop";
	 fe_ov = "Stop";
	 fe_om = "Stop";
	 fe_tfl = "Stop";
	 if (cryo.startsWith("Konti")) {
	    hide_sc = "n";
            hide_tfl = "n";
            fe_sc = "Start";
            fe_tfl = "Start";
         } else if (cryo.startsWitt("LowTemp")) {
            hide_sc = "n";
            fe_sc = "Start";
         } else if (cryo.startsWitt("Omega")) {
            hide_om = "n";
            fe_om = "Start";    
         }
	 
	 // Hide/Show SampleCryo/Oven/Omega
	 modbset("/Equipment/SampleCryo/Common/Hidden", hide_sc);
         modbset("/Equipment/TFL/Common/Hidden", hide_tfl);
         modbset("/Equipment/Omega/Common/Hidden", hide_om);
         // The corresponding FE should be started/stopped
         if (fe_sc == "Stop") { 
             mjsonrpc_stop_program("Sample_SC");
         } else if (fe_sc == "Start") {
            mjsonrpc_start_program("Sample_SC");
         }

         if (fe_om == "Stop" && feIsRunning("Omega SC") != 0) { // only stop frontend if already running
	    eqStart("Omega SC",fe_om);
	 } else if (fe_om == "Start" && feIsRunning("Omega SC") == 0) { // only start frontend if not already running
	    eqStart("Omega SC",fe_om);
	 }

	 if (fe_tfl == "Stop" && feIsRunning("TFL_SC") != 0) { // only stop frontend if already running
	    eqStart("TFL_SC",fe_tfl);
	 } else if (fe_tfl == "Start" && feIsRunning("TFL_SC") == 0) { // only start frontend if not already running
	    eqStart("TFL_SC",fe_tfl);
	 }
	 
	 // change the cryo setup string
	 modbset("/Info/Sample Cryo", cryo);
	 console.log("Setting cryostat to: " + cryo);       
      }
   }).catch (function (error) {console.error(error);}); 
}


function cs_ra_pulsing(val)
{
   // write RA pulsing state to the ODB
   if (val) {
      document.getElementById("PulsOn").style.visibility = "visible";
   } else {
      document.getElementById("PulsOn").style.visibility = "hidden";
   }
}

// This function disables/enables equipment
function eqEnable(element)
{
   let val = element.id;
   // We expect the that val is the name of the Equipment in ODB
   // /Equipment/val/...
   //console.log("eqEnable: " + val);

   // The assumption is that the FronEnd Program is in "/Equipment/val/Common/Frontend name"
   let feProgramODB = "/Equipment/"+val+"/Common/Frontend name";
   mjsonrpc_db_get_values([feProgramODB]).then(function(rpc) {
      let feProgram = rpc.result.data[0];
      // toggle selection
      onoff = document.getElementById(val).checked; 
      if ( onoff ) {
         document.getElementById(val).checked = true;
	 // Make it visible on the Status page
         modbset("/Equipment/"+val+"/Common/Hidden", "n");
	 // If FronEnd is not running, then start it
         if (feIsRunning(feProgram) == 0) {
	    eqStart(feProgram,"Start");
         }
      } else { 
	 document.getElementById(val).checked = false;
	 // Hide it on the Status page
         modbset("/Equipment/"+val+"/Common/Hidden", "y");
         eqStart (feProgram,"Stop");
      }
   }).catch (function (error) {mjsonrpc_error_alert(error);});
}



// For setting magnetic field
function setFieldCurrent(val,element)
{
   // Which magnet are we using?
   // Get all calibration parameters to convert from Gauss to A
   let sel_mag = "";
   console.log("Set Field ",val,"G");
   // First confirm the change
   if (confirm('Are you sure you want to change the field?\nSet Field '+val+' G')) {
      mjsonrpc_db_get_values(["/Info/LEM_Setup_Parameter/WEW",
			      "/Info/LEM_Setup_Parameter/Bpar",
			      "/Info/Magnet_Parameter/WEW",
			      "/Info/Magnet_Parameter/Bpar"]).then(function(rpc) {
				 let wew = rpc.result.data[0];
				 let bpar = rpc.result.data[1];
				 let pWEW = rpc.result.data[2];
				 let pBpar = rpc.result.data[3];
				 let Bcurrent = 0;
				 if (wew && !bpar) {
				    sel_mag = "WEW";
				    console.log("Selected magnet is "+sel_mag);
				    Bcurrent = (val-pWEW[0])/pWEW[1];
				    console.log("Set current: "+Bcurrent);
				    // Field higher than 100G, ba careful and check RA
				    if (val > 100) {
				       if (!confirm("The applied field is > 100G, is the RA off?")) {
					  // Bail out
					  return true;
				       }
				    }
				    if (Bcurrent > 40) {
				       // Uses WEWH
				       // WEWL 0 Cmd/1 Current
				       // WEWH 2 Cmd/3 Current
				       modbset("/Equipment/WEW/Variables/Output[1]",0);
                                       modbset("/Equipment/WEW/Variables/Output[0]",0);
                                       modbset("/Equipment/WEW/Variables/Output[2]",1);
                                       modbset("/Equipment/WEW/Variables/Output[3]",Bcurrent);
                                       console.log("Set WEWH ",Bcurrent);
                                    } else {
                                       // Uses WEWL
                                       modbset("/Equipment/WEW/Variables/Output[3]",0);
				       modbset("/Equipment/WEW/Variables/Output[2]",0);
				       modbset("/Equipment/WEW/Variables/Output[0]",1);
				       modbset("/Equipment/WEW/Variables/Output[1]",Bcurrent);
				       consile.log("Set WEWL ",Bcurrent);
				    }
				 } else if (!wew && bpar) {
				    sel_mag = "Bpar";
				    console.log("Selected magnet is "+sel_mag);
				    Bcurrent = (val-pBpar[0])/pBpar[1];
				    console.log("Set Bpar "+Bcurrent);
				    modbset("/Equipment/Danfysik/Variables/Output[2]",Bcurrent);
				 } else if (!wew && !bpar) {
				    sel_mag = "none";
				    console.log("Selected magnet is "+sel_mag);
				    console.log("Set current: "+Bcurrent);
				 } 
			      }).catch (function (error) { console.error(error);});
   }
   return true;
}

function get_field_current()
{
   // Which magnet are we using?
   // Get all calibration parameters to convert from A to Gauss
   let sel_mag = "";
   mjsonrpc_db_get_values(["/Info/LEM_Setup_Parameter/WEW", 
                           "/Info/LEM_Setup_Parameter/Bpar",
			   "/Info/Magnet_Parameter/WEW",
			   "/Info/Magnet_Parameter/Bpar",
			   "/Equipment/WEW/Variables/Output[1]",
			   "/Equipment/WEW/Variables/Output[3]",
			   "/Equipment/Danfysik/Variables/Output[2]"]).then(function(rpc) {
			      let wew = rpc.result.data[0];
			      let bpar = rpc.result.data[1];
			      let pWEW = rpc.result.data[2];
			      let pBpar = rpc.result.data[3];
			      let Bgauss = 0;
			      let Ival = 0;
			      let message = "";
			      if (wew && !bpar) {
				 Ival = rpc.result.data[4];
				 Bgauss = pWEW[1]*Ival+pWEW[0];
				 message += "WEW=";
				 return Bgauss;
			      } else if (!wew && bpar) {
				 Ival = rpc.result.data[6];
				 Bgauss = pBpar[1]*Ival+pBpar[0];
				 return Bgauss;
			      } 
			   }).catch (function (error) { console.error(error);});
}

function histRefresh() {
   let allHists = document.getElementsByClassName("mjshistory");
   for (let i =0; i < allHists.length; i++) {
      allHists[i].innerHTML= "";
      mhistory_init(allHists[i]);
   }
}

function Konti_Params()
{
   let Parameters = [
      '<a href="../Info" target"_blank"><text transform="translate(15000,3700) rotate(-90)" font-size="30rem"><tspan class="modbvalue" data-odb-path="/Info/Sample Cryo"></tspan></text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'SampleCryo\',\'TFL\');"><text x="5800" y="2300" font-size="30rem">NV=<tspan class="modbvalue" data-odb-path="/Equipment/TFL/Variables/Input[0]" data-format="f2"></tspan>%</text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'SampleCryo\',\'CryoPressure\');"><text x="10500" y="8500" font-size="30rem"><tspan class="modbvalue" data-odb-path="/Equipment/SampleCryo/Variables/Input[4]" data-format="f2"></tspan> bar</text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'SampleCryo\',\'HeFlow\');"><text x="14000" y="5800" font-size="30rem">BH=<tspan class="modbvalue" data-odb-path="/Equipment/SampleCryo/Variables/Input[24]" data-format="f2"></tspan></text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'SampleCryo\',\'HeFlow\');"><text x="20000" y="8000" font-size="30rem"><tspan class="modbvalue" data-odb-path="/Equipment/SampleCryo/Variables/Input[29]" data-format="f2"></tspan> l/min</text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'SampleCryo\',\'LHe_Level\');"><text x="6000" y="6500" font-size="30rem"><tspan class="modbvalue" data-odb-path="/Equipment/LM510 LHe/Variables/Input" data-format="f2"></tspan>%</text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'SampleCryo\',\'SampleTemp\');"><text x="21500" y="2500" font-size="30rem">T=<tspan class="modbvalue" data-odb-path="/Equipment/SampleCryo/Variables/Input[0]" data-format="f2"></tspan> K</text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'SampleCryo\',\'Heater\');"><text x="21500" y="3000" font-size="30rem">Heater=<tspan class="modbvalue" data-odb-path="/Equipment/SampleCryo/Variables/Input[8]" data-format="f1"></tspan>%</text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'SampleCryo\',\'HV_Sample\');"><text x="21500" y="3500" font-size="30rem">HV=<tspan class="modbvalue" data-odb-path="/Equipment/HV/Variables/Measured[15]" data-format="f1"></tspan> kV</text></a>',
      '<a href="../Info" target"_blank"><text x="21500" y="4000" font-size="30rem">E=<tspan class="modbvalue" data-odb-path="/Info/Implantation Energy (keV)" data-format="f1"></tspan> keV</text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'WEW\',\'ZeroFlux\');"><text x="21500" y="4500" font-size="30rem">B=<tspan class="modbvalue" data-odb-path="/Info/Magnetic Field (G)" data-format="f2"></tspan> G</text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'Lemvac\',\'pressure UHV\');"><text x="21500" y="5000" font-size="30rem">p=<tspan class="modbvalue" data-odb-path="/Equipment/LEMVAC/Variables/Input[11]" data-format="e2"></tspan> mbar</text></a>'].join('\n');
   document.getElementById('Parameters').innerHTML = Parameters;
}

function LowTemp_Params()
{
   let Parameters = [
      '<a href="../Info" target"_blank"><text transform="translate(15500,4750) rotate(-90)" font-size="30rem"><tspan class="modbvalue" data-odb-path="/Info/Sample Cryo"></tspan></text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'LowTemp\',\'FlowAfterPumps\');"><text x="450" y="2000" font-size="30rem"><tspan class="modbvalue" data-odb-path="/Equipment/SampleCryo/Variables/Input[28]" data-format="f2"></tspan> l/min</text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'LowTemp\',\'CryoPressure\');"><text x="9000" y="8000" font-size="30rem"><tspan class="modbvalue" data-odb-path="/Equipment/SampleCryo/Variables/Input[4]" data-format="f2"></tspan> bar</text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'SampleCryo\',\'LHe_Level\');"><text x="6000" y="7500" font-size="30rem"><tspan class="modbvalue" data-odb-path="/Equipment/LM510 LHe/Variables/Input" data-format="f2"></tspan>%</text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'LowTemp\',\'HeFlow\');"><text x="13000" y="8500" font-size="30rem">BH1=<tspan class="modbvalue" data-odb-path="/Equipment/SampleCryo/Variables/Input[24]" data-format="f0"></tspan></text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'LowTemp\',\'HeFlow\');"><text x="13000" y="5500" font-size="30rem">BH2=<tspan class="modbvalue" data-odb-path="/Equipment/SampleCryo/Variables/Input[26]" data-format="f0"></tspan></text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'LowTemp\',\'FlowAfterPumps\');"><text x="21000" y="8500" font-size="30rem"><tspan class="modbvalue" data-odb-path="/Equipment/SampleCryo/Variables/Input[29]" data-format="f2"></tspan> l/min</text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'LowTemp\',\'TPG262\');"><text x="16000" y="8800" font-size="30rem"><tspan class="modbvalue" data-odb-path="/Equipment/TPG262/Variables/Measured[1]" data-format="f2"></tspan> mbar</text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'LowTemp\',\'TPG262\');"><text x="5500" y="2000" font-size="30rem"><tspan class="modbvalue" data-odb-path="/Equipment/TPG262/Variables/Measured[0]" data-format="f2"></tspan> mbar</text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'LowTemp\',\'SampleTemp\');"><text x="21800" y="2500" font-size="30rem">T=<tspan class="modbvalue" data-odb-path="/Equipment/SampleCryo/Variables/Input[0]" data-format="f2"></tspan> K</text></a>',
      //'<a style="cursor: pointer" onclick="mhistory_dialog(\'LowTemp\',\'SampleTemp\');"><text x="21800" y="2500" font-size="30rem">T=<tspan class="modbvalue" data-odb-path="/Equipment/LS340/Variables/Input[0]" data-format="f2"></tspan> K</text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'SampleCryo\',\'Heater\');"><text x="21800" y="3000" font-size="30rem">Heater=<tspan class="modbvalue" data-odb-path="/Equipment/SampleCryo/Variables/Input[8]" data-format="f1"></tspan>%</text></a>',
      //'<a style="cursor: pointer" onclick="mhistory_dialog(\'LowTemp\',\'Heater\');"><text x="21800" y="3000" font-size="30rem">Heater=<tspan class="modbvalue" data-odb-path="/Equipment/LS340/Variables/Input[7]" data-format="f1"></tspan>%</text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'SampleCryo\',\'HV_Sample\');"><text x="21800" y="3500" font-size="30rem">HV=<tspan class="modbvalue" data-odb-path="/Equipment/HV/Variables/Measured[15]" data-format="f1"></tspan> kV</text></a>',
      '<a href="../Info" target"_blank"><text x="21800" y="4000" font-size="30rem">E=<tspan class="modbvalue" data-odb-path="/Info/Implantation Energy (keV)" data-format="f1"></tspan> keV</text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'WEW\',\'ZeroFlux\');"><text x="21800" y="4500" font-size="30rem">B=<tspan class="modbvalue" data-odb-path="/Info/Magnetic Field (G)" data-format="f1"></tspan> G</text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'Lemvac\',\'pressure UHV\');"><text x="21800" y="5000" font-size="30rem">p=<tspan class="modbvalue" data-odb-path="/Equipment/LEMVAC/Variables/Input[11]" data-format="e2"></tspan> mbar</text></a>'].join('\n');
   document.getElementById('Parameters').innerHTML = Parameters;
}

function Omega_Params()
{
   let Parameters = [
      '<a href="../Info" target"_blank"><text transform="translate(15000,3900) rotate(-90)" font-size="30rem"><tspan class="modbvalue" data-odb-path="/Info/Sample Cryo"></tspan></text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'Omega\',\'Temp\');"><text x="18800" y="2500" font-size="30rem">T=<tspan class="modbvalue" data-odb-path="/Equipment/Omega/Variables/Input[0]" data-format="f1" data-formula="x+273.16"></tspan> K</text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'SampleCryo\',\'HV_Sample\');"><text x="18800" y="3000" font-size="30rem">HV=<tspan class="modbvalue" data-odb-path="/Equipment/HV/Variables/Measured[15]" data-format="f1"></tspan> kV</text></a>',
      '<a href="../Info" target"_blank"><text x="18800" y="3500" font-size="30rem">E=<tspan class="modbvalue" data-odb-path="/Info/Implantation Energy (keV)" data-format="f1"></tspan> keV</text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'WEW\',\'ZeroFlux\');"><text x="18800" y="4000" font-size="30rem">B=<tspan class="modbvalue" data-odb-path="/Info/Magnetic Field (G)" data-format="f1"></tspan> G</text></a>',
      '<a style="cursor: pointer" onclick="mhistory_dialog(\'Lemvac\',\'pressure UHV\');"><text x="18800" y="5000" font-size="30rem">p=<tspan class="modbvalue" data-odb-path="/Equipment/LEMVAC/Variables/Input[11]" data-format="e2"></tspan> mbar</text></a>'].join('\n');
   document.getElementById('Parameters').innerHTML = Parameters;
}

function Konti_Ctrl()
{
   let Konti_CTRL = [
      'Sample Temperature: <span name="modbvalue" data-odb-path="/Equipment/SampleCryo/Variables/Output[0]" data-format="f2.1" data-odb-editable="1"></span> (K) |',
      'Ramp Rate: <span name="modbvalue" data-odb-path="/Equipment/SampleCryo/Variables/Output[6]"  data-format="f2.1" data-odb-editable="1"></span> (K/min) |',
      'He Flow (BH): <span name="modbvalue" data-odb-path="/Equipment/SampleCryo/Variables/Output[14]" data-format="f0" data-odb-editable="1"></span> |',
      'Needle Valve: <span name="modbvalue" data-odb-path="/Equipment/TFL/Variables/Output[0]" data-format="f2" data-odb-editable="1"></span>'].join(' ');
   document.getElementById('Controls').innerHTML = Konti_CTRL;
   document.getElementById('Controls').setAttribute("name","Konti");
   document.getElementById('Controls').style.textAlign = "center";
   document.getElementById('samplecryosvg').setAttribute("viewBox","2500 1200 23000 9000");

   // Also show needle valve row from Run Control
   if (document.getElementById('NVRow')) {
      document.getElementById('NVRow').style.display = '';
   }
}

function Konti_Histos()
{
   //    let size= 'width: 360px; height: 200px;border: 1px solid black;';
   let size= 'width: 100%; height: 23vh;min-height: 200px;';
   let Hist3='<div class="mjshistory" data-group="SampleCryo" data-panel="SampleTemp" data-scale="30m" style="'+ size +'"></div>';
   let Hist2='<div class="mjshistory" data-group="SampleCryo" data-panel="CryoPressure" data-scale="30m" style="'+ size +'"></div>';
   let Hist1='<div class="mjshistory" data-group="SampleCryo" data-panel="HeFlow" data-scale="30m" style="'+ size +'"></div>';
   document.getElementById('Hist1').innerHTML = Hist1;
   document.getElementById('Hist2').innerHTML = Hist2;
   document.getElementById('Hist3').innerHTML = Hist3;
   //document.getElementById('Hist1').classList.add("w3-border");
   //document.getElementById('Hist2').classList.add("w3-border");
   //document.getElementById('Hist3').classList.add("w3-border");
}


function LowTemp_Histos()
{
   //    let size= 'width: 360px; height: 200px;border: 1px solid black;';
   let size= 'width: 100%; height: 23vh;min-height: 200px;';
   let Hist3 = '<div class="mjshistory" data-group="LowTemp" data-panel="SampleTemp" data-scale="30m" style="'+size+'"></div>';
   let Hist2 = '<div class="mjshistory" data-group="LowTemp" data-panel="CryoPressure" data-scale="30m" style="'+size+'"></div>';
   let Hist1 = '<div class="mjshistory" data-group="LowTemp" data-panel="HeFlow" data-scale="30m" style="'+size+'"></div>';
   document.getElementById('Hist1').innerHTML = Hist1;
   document.getElementById('Hist2').innerHTML = Hist2;
   document.getElementById('Hist3').innerHTML = Hist3;
   //document.getElementById('Hist1').classList.add("w3-border");
   //document.getElementById('Hist2').classList.add("w3-border");
   //document.getElementById('Hist3').classList.add("w3-border");
}

function LowTemp_Ctrl()
{
   let LowTemp_CTRL = [
      'Sample Temperature: <span name="modbvalue" data-odb-path="/Equipment/SampleCryo/Variables/Output[0]" data-format="f2.1" data-odb-editable="1"></span> (K) |',
      //'Sample Temperature: <span name="modbvalue" data-odb-path="/Equipment/LS340/Variables/Output[1]" data-format="f2.1" data-odb-editable="1"></span> (K) |',
      'Ramp Rate: <span name="modbvalue" data-odb-path="/Equipment/SampleCryo/Variables/Output[6]"  data-format="f2.1" data-odb-editable="1"></span> (K/min) |',
      //'Ramp Rate: <span name="modbvalue" data-odb-path="/Equipment/LS340/Variables/Output[7]"  data-format="f2.1" data-odb-editable="1"></span> (K/min) |',
      'He Flow (BH1): <span name="modbvalue" data-odb-path="/Equipment/SampleCryo/Variables/Output[14]" data-format="f0" data-odb-editable="1"></span> |',
      ' / (BH2): <span name="modbvalue" data-odb-path="/Equipment/SampleCryo/Variables/Output[16]" data-format="f0" data-odb-editable="1"></span>'].join('\n');
   document.getElementById('Controls').innerHTML = LowTemp_CTRL;
   document.getElementById('Controls').setAttribute("name","LowTemp");
   document.getElementById('Controls').style.textAlign = "center";
   document.getElementById('samplecryosvg').setAttribute("viewBox","500 1200 25500 10000");
}

function Omega_Histos()
{
   //    let size= 'width: 360px; height: 200px;border: 1px solid black;';
   let size= 'width: 100%; height: 23vh;min-height: 200px;';
   let Hist2 = '<div class="mjshistory" data-group="Omega" data-panel="Temp" style="'+size+'"></div>';
   document.getElementById('Hist1').innerHTML = "";
   document.getElementById('Hist3').innerHTML = "";
   document.getElementById('Hist2').innerHTML = Hist2;
   //document.getElementById('Hist1').classList.remove("w3-border");
   //document.getElementById('Hist3').classList.remove("w3-border");
   //document.getElementById('Hist2').classList.add("w3-border");
}

function Omega_Ctrl()
{
   let Omega_CTRL = [
      'Sample Temperature: <span name="modbvalue" data-odb-path="/Equipment/Omega/Variables/Output[0]" data-format="f2.1" data-odb-editable="1"></span> (C)/<span name="modbvalue" data-odb-path="/Equipment/Omega/Variables/Output[0]" data-format="f2.1" data-formula="x+273.16"></span> (K)'].join('\n');
   document.getElementById('Controls').innerHTML = Omega_CTRL;
   document.getElementById('Controls').setAttribute("name","Omega");
   document.getElementById('Controls').style.textAlign = "center";
   document.getElementById('samplecryosvg').setAttribute("viewBox","4000 1200 19500 6000");
   //document.getElementById('samplecryosvg').style.maxWidth = "60vw";
   //document.getElementById('samplecryosvg').style.maxHeight = "30vh";
}

function NoCryo()
{
   mjsonrpc_db_get_values(["/Info/LEM_Setup","/Info/Sample Cryo"]).then(function(rpc) {
      let lem_setup = rpc.result.data[0];
      let lem_sample_cryo = rpc.result.data[1];
      let NoCryo = 'Not a Cryo Setup: lem_setup='+lem_setup+', lem_sample_cryo='+lem_sample_cryo;
      document.getElementById('SVGholder').innerHTML = NoCryo;
   }).catch (function (error) {mjsonrpc_error_alert(error);});
}


function Konti_SVG()
{
   let KontiSVG = [
      '<g id="TFL-Konti" transform="translate(6600,3100) rotate(0)">',
      '  <path fill="none" stroke="rgb(153,204,255)" stroke-width="159" stroke-linejoin="round" d="M 0,3000 L 0,0 7400,0"/>',
      '  <g id="NeedleValve" transform="translate(0,0) rotate(0)">',
      '    <path fill="rgb(255,255,255)" stroke="rgb(0,0,0)" stroke-width="50" stroke-linejoin="round" d="M 500,-350 L 500,350 -500,-350 -500,350 500,-350 Z"/>',
      '    <path fill="none" stroke="rgb(0,0,0)" stroke-width="50" stroke-linejoin="round" d="M 100,-350 L -100,350"/>',
      '    <polygon style="fill:black;stroke:black;stroke-width:10" transform="translate(-100,0) rotate(15)" points="200,-350 0,-350 100,-550"/>',
      '  </g>',
      '</g>',
      '<g id="PumpLine" transform="translate(0,0) rotate(0)">',
      '  <path fill="none" stroke="rgb(153,204,255)" stroke-width="159" stroke-linejoin="round" d="M 14000,4006 L 11937,4008 11944,7972 18100,7972"/>',
      '  <g id="BH">',
      '    <image x="14000" y="6100" width="2500" height="2100" xlink:href="sample/BH.png"/>',
      '  </g>',
      '  <g id="Gauge" transform="translate(12700,8770) rotate(0)">',
      '    <circle cx="0" cy="0" r="300" stroke="rgb(1,0,0)" stroke-width="50" fill="none" />',
      '    <path fill="none" stroke="rgb(0,0,0)" stroke-width="50" stroke-linejoin="round" d="M 0,-275 L -150,275"/>',
      '    <path fill="none" stroke="rgb(0,0,0)" stroke-width="50" stroke-linejoin="round" d="M 150,275 L 0,-275"/>',
      '    <path fill="none" stroke="rgb(0,0,0)" stroke-width="50" stroke-linejoin="round" d="M 250,130 L -250,130"/>',
      '    <path fill="none" stroke="rgb(0,0,0)" stroke-width="50" stroke-linejoin="round" d="M 0,-275 L 0,-790"/>',
      '  </g>',
      '  <g id="Pump" transform="translate(19000,8000) rotate(0)">',
      '    <circle cx="0" cy="0" r="900" stroke="rgb(0,0,0)" stroke-width="50" fill="none" />',
      '    <path fill="none" stroke="rgb(0,0,0)" stroke-width="50" stroke-linejoin="round" d="M -570,-700 L 830,-300"/>',
      '    <path fill="none" stroke="rgb(0,0,0)" stroke-width="50" stroke-linejoin="round" d="M -570,700 L 830,300"/>',
      '    <text x="-800" y="100" font-size="30rem">ACP28</text>',
      '  </g>',
      '</g>',
      '<g id="Konti"  transform="translate(-4000,0) rotate(0)">',
      '  <g id="longline">',
      '    <path fill="none" stroke="rgb(0,0,0)" d="M 19565,4286 L 19565,1905"/>',
      '  </g>',
      '  <g id="shortline">',
      '    <path fill="none" stroke="rgb(0,0,0)" d="M 20993,3571 L 20993,2619"/>',
      '  </g>',
      '  <g id="flange">',
      '    <rect x="21232" y="1905" width="238" height="2381" stroke-width="25" stroke="rgb(0,0,0)" style="fill:url(#silver)"/>',
      '  </g>',
      '  <g id="LowerSheild">',
      '    <rect x="21270" y="2381" width="1905" height="1428" stroke-width="0" stroke="rgb(0,0,0)" style="fill:url(#silver)"/>',
      '  </g>',
      '  <g id="AuSheild">',
      '    <rect x="23150" y="2381" width="1676" height="1428" stroke-width="0" stroke="rgb(0,0,0)" style="fill:url(#gold)"/>',
      '  </g>',
      '  <g id="KontiCenter">',
      '    <rect x="21289" y="2857" width="2346" height="476" stroke-width="25" stroke-dasharray="50,50" fill="none" stroke="rgb(0,0,0)"/>',
      '  </g>',
      '  <g id="BasePlate">',
      '    <rect x="23635" y="2618" width="152" height="953" stroke-width="25" stroke-dasharray="50,50" fill="none" stroke="rgb(0,0,0)"/>',
      '  </g>',
      '  <g id="SamplePlate">',
      '    <rect x="23951" y="2618" width="152" height="953" stroke-width="25" stroke-dasharray="50,50" fill="none" stroke="rgb(0,0,0)"/>',
      '  </g>',
      '  <g id="Sapphire">',
      '    <rect x="23802" y="2718" width="152" height="773" stroke-width="25" stroke-dasharray="50,50" fill="none" stroke="rgb(0,0,0)"/>',
      '  </g>',
      '  <g id="He-inout">',
      '    <rect x="17660" y="2857" width="476" height="476" stroke-width="25" stroke="rgb(0,0,0)" style="fill:url(#silver)"/>',
      '    <rect x="17660" y="3757" width="476" height="476" stroke-width="25" stroke="rgb(0,0,0)" style="fill:url(#silver)"/>',
      '  </g>',
      '  <g id="KontiBody">',
      '    <path style="fill:url(#silver)" stroke="rgb(0,0,0)" stroke-width="25" stroke-linejoin="round" d="M 20517,4048 C 20207,4192 19835,4433 19587,4481 19338,4530 19254,4510 19088,4524 L 18612,4524 C 18136,4524 18136,4524 18136,4048 L 18136,2143 C 18136,1667 18136,1667 18612,1667 L 19088,1667 C 19255,1681 19338,1662 19588,1710 19837,1758 20207,1999 20517,2144 L 20517,2143 C 20618,2203 20648,2229 20821,2323 20994,2418 21052,2453 21247,2453 L 21240,2471 21240,3746 21246,3739 C 21051,3738 20994,3775 20820,3868 20647,3962 20618,3988 20517,4048 Z"/>',
      '  </g>',
      '</g>',

      '<g id="Dewar"  transform="translate(5000,5000) rotate(0)">',
      '  <g id="Wheels">',
      '    <circle cx="772" cy="4904" r="300" stroke="rgb(0,0,0)" stroke-width="25" fill="gray" />',
      '    <circle cx="2512" cy="4904" r="300" stroke="rgb(0,0,0)" stroke-width="25" fill="gray" />',
      '  </g>',
      '  <g id="Recovery">',
      '    <path fill="none" stroke="rgb(153,153,153)" stroke-width="81" stroke-linejoin="round" d="M 1000,-1300 L -1300,-1300 -1300,2500 -2000,2500"/>',
      '    <text x="0" y="0" font-size="30rem" transform="translate(-1700,1500) rotate(-90)">He recovery</text>',
      '  </g>',
      '  <g id="DewarBody">',
      '    <path style="fill:url(#DewarBlue)" d="M -53,73 L -51,16 -44,-40 -34,-95 -19,-294 -2,-202 19,-252 43,-299 69,-343 97,-384 128,-420 160,-453 194,-480 229,-502 264,-518 282,-524 300,-529 319,-531 337,-532 2880,-532 2898,-531 2917,-529 2935,-524 2953,-518 2988,-502 3023,-480 3057,-453 3089,-420 3120,-384 3149,-343 3175,-299 3199,-252 3220,-202 3237,-149 3252,-95 3262,-40 3269,16 3271,73 3271,4010 3269,4067 3262,4123 3252,4178 3237,4233 3220,4285 3199,4335 3175,4382 3149,4427 3120,4467 3089,4504 3057,4536 3023,4564 2988,4586 2953,4602 2935,4608 2917,4613 2898,4615 2880,4616 337,4616 319,4615 300,4613 282,4608 264,4602 229,4586 194,4564 160,4536 128,4504 97,4467 69,4427 43,4382 19,4335 -2,4285 -19,4233 -34,4178 -44,4123 -51,4067 -53,4010 -53,73 Z"/>',
      '    <path style="fill:url(#DewarBlue)" d="M 384,-989 L 386,-1011 391,-1032 400,-1054 411,-1075 426,-1096 445,-1118 489,-1159 545,-1199 610,-1237 684,-1273 767,-1307 952,-1366 1159,-1412 1380,-1442 1609,-1442 1837,-1442 2059,-1412 2266,-1366 2451,-1307 2533,-1273 2608,-1236 2673,-1199 2729,-1159 2773,-1118 2791,-1096 2806,-1075 2818,-1054 2827,-1032 2832,-1011 2834,-989 2834,-537 384,-527 384,-989 Z"/>',
      '  </g>',
      '</g>'].join('');
   document.getElementById('SVGholder').innerHTML = KontiSVG;
}

function LowTemp_SVG()
{
   let LowTempSVG = [
      '<g id="TFL-LowTemp" transform="translate(0,-5700) rotate(0)">',
      '  <path fill="none" stroke="rgb(153,204,255)" stroke-width="159" stroke-linejoin="round" d="M 6619,12038 L 6619,9092 19000,9096"/>',
      '</g>',
      '<g id="PumpLine28" transform="translate(-3500,-5700) rotate(0)">',
      '  <path fill="none" stroke="red" stroke-width="159" stroke-linejoin="round" d="M 18500,9350 L 18000,10006 14022,10006 14022,11972 16000,11972"/>',
      '  <path fill="none" stroke="rgb(153,204,255)" stroke-width="159" stroke-linejoin="round" d="M 16500,11972 L 19364,11972 19364,13909 22364,13972"/>',
      '  <g id="BH1"><image x="15000" y="10500" width="2000" height="1680" xlink:href="sample/BH.png"/></g>',
      '  <path fill="none" stroke="rgb(32,74,135)" stroke-width="159" stroke-linejoin="round" d="M 21750,8700 L 13022,8700 13022,14972 16000,14972"/>',
      '  <path fill="none" stroke="rgb(153,204,255)" stroke-width="159" stroke-linejoin="round" d="M 16500,14972 L 19364,14972 19364,13909"/>',
      '  <g id="BH2"><image x="15000" y="13500" width="2000" height="1680" xlink:href="sample/BH.png"/></g>',
      '  <g id="Gauge" transform="translate(1400,-2000) rotate(0)">',
      '    <path fill="none" stroke="rgb(0,0,0)" stroke-width="25" stroke-linejoin="round" d="M 12664,14496 C 12717,14496 12762,14508 12808,14535 12854,14561 12887,14594 12913,14640 12940,14686 12952,14731 12952,14784 12952,14837 12940,14882 12913,14928 12887,14974 12854,15007 12808,15033 12762,15060 12717,15072 12664,15072 12611,15072 12566,15060 12520,15033 12474,15007 12441,14974 12415,14928 12388,14882 12376,14837 12376,14784 12376,14731 12388,14686 12415,14640 12441,14594 12474,14561 12520,14535 12566,14508 12611,14496 12664,14496 L 12664,14496 Z"/>',
      '    <path fill="none" stroke="rgb(0,0,0)" stroke-width="25" stroke-linejoin="round" d="M 12669,14494 L 12521,15034"/>',
      '    <path fill="none" stroke="rgb(0,0,0)" stroke-width="25" stroke-linejoin="round" d="M 12816,15038 L 12668,14498"/>',
      '    <path fill="none" stroke="rgb(0,0,0)" stroke-width="25" stroke-linejoin="round" d="M 12924,14901 L 12406,14901"/>',
      '    <path fill="none" stroke="rgb(0,0,0)" stroke-width="25" stroke-linejoin="round" d="M 12672,14492 L 12672,13977"/>',
      '  </g>',
      '  <path fill="none" stroke="rgb(153,204,255)" stroke-width="159" stroke-linejoin="round" d="M 19364,14000 19364,13909"/>',
      '  <g id="Pump">',
      '    <circle cx="23270" cy="13900" r="900" stroke="rgb(0,0,0)" stroke-width="25" fill="none" />',
      '    <path fill="none" stroke="rgb(0,0,0)" stroke-width="25" stroke-linejoin="round" d="M 22635,13287 L 24117,13693"/>',
      '    <path fill="none" stroke="rgb(0,0,0)" stroke-width="25" stroke-linejoin="round" d="M 24134,14104 L 22652,14510"/>',
      '    <text x="22500" y="14100" font-size="30rem">ACP28</text>',
      '  </g>',
      '</g>',
      '<g id="PumpLine120" transform="translate(-500,-5000) rotate(0)">',
      '  <path fill="none" stroke="yellow" stroke-width="300" stroke-linejoin="round" d="M 18500,7500 L 18500,7000 5500,7500"/>',
      '  <text x="3700" y="7700" font-size="30rem">ACP120</text>',
      '  <g id="Pump120" transform="translate(-14200,-5300) rotate(180,23270,14800) scale(1.2,1.2)">',
      '    <circle cx="23270" cy="13900" r="900" stroke="rgb(0,0,0)" stroke-width="25" fill="none" />',
      '    <path fill="none" stroke="rgb(0,0,0)" stroke-width="25" stroke-linejoin="round" d="M 22635,13287 L 24117,13693"/>',
      '    <path fill="none" stroke="rgb(0,0,0)" stroke-width="25" stroke-linejoin="round" d="M 24134,14104 L 22652,14510"/>',
      '  </g>',
      '</g>',
      '<g id="LowTemp"  transform="translate(-4500,-5700) rotate(0)">',
      '  <g id="Extension">',
      '    <rect x="18100" y="7995" width="1300" height="2200" stroke-width="0" stroke="rgb(0,0,0)" style="fill:url(#silver)"/>',
      '  </g>',
      '  <g id="ReturnGas">',
      '    <rect x="21500" y="8295" width="3500" height="1600" stroke-width="0" stroke="rgb(0,0,0)" fill="yellow"/>',
      '  </g>',
      '  <g id="PhasSep">',
      '    <rect x="21500" y="8495" width="3300" height="1200" stroke-width="25" stroke="rgb(0,0,0)" fill="white"/>',
      '    <rect x="21750" y="8645" width="2200" height="900" stroke-width="25" stroke="rgb(0,0,0)" style="fill:url(#LiquidHe)"/>',
      '    <path fill="none" stroke="rgb(32,74,135)" stroke-width="100" stroke-linejoin="round" d="M 23550,9445 L 24350,9445 24550,9095 24800,9095"/>',
      '  </g>',
      '  <g id="flange">',
      '    <rect x="21232" y="7805" width="238" height="2580" stroke-width="25" stroke="rgb(0,0,0)" style="fill:url(#silver)"/>',
      '  </g>',
      '  <g id="LowTempBody"  transform="translate(8500,0) scale(0.6,1)">',
      '    <path style="fill:url(#silver)" stroke="rgb(0,0,0)" stroke-width="25" stroke-linejoin="round" d="M 20517,10048 C 20207,10192 19835,10433 19587,10481 19338,10530 19254,10510 19088,10524 L 18612,10524 C 18136,10524 18136,10524 18136,10048 L 18136,8143 C 18136,7667 18136,7667 18612,7667 L 19088,7667 C 19255,7681 19338,7662 19588,7710 19837,7758 20207,7999 20517,8144 L 20517,8143 C 20618,8203 20648,8229 20821,8323 20994,8418 21052,8453 21247,8453 L 21240,8471 21240,9746 21246,9739 C 21051,9738 20994,9775 20820,9868 20647,9962 20618,9988 20517,10048 Z"/>',
      '  </g>',
      '  <g id="BasePlate">',
      '    <rect x="25000" y="8195" width="150" height="1800" stroke-width="25" fill="none" stroke="rgb(0,0,0)"/>',
      '  </g>',
      '  <g id="SamplePlate">',
      '    <rect x="25300" y="8195" width="150" height="1800" stroke-width="25" fill="none" stroke="rgb(0,0,0)"/>',
      '  </g>',
      '  <g id="Sapphire">',
      '    <rect x="25150" y="8295" width="150" height="1600" stroke-width="25" fill="none" stroke="rgb(0,0,0)"/>',
      '  </g>',
      '  <g id="NV1" transform="translate(24200,8800) rotate(0) scale(0.5,0.5)" >',
      '    <path fill="red" stroke="rgb(0,0,0)" stroke-width="25" stroke-linejoin="round" d="M 950,793 L 950,1428 0,793 0,1428 950,793 Z"/>',
      '    <path fill="red" stroke="red" stroke-width="50" stroke-linejoin="round" d="M 340,1519 L 520,915"/>',
      '    <path fill="red" stroke="red" d="M 600,941 L 620,967 599,591 376,895 406,884 440,878 475,878 510,884 544,897 574,917 600,941 Z"/>',
      '  </g>',
      '<path fill="red" stroke="red" stroke-width="80" stroke-linejoin="round" d="M 17500,9350 L 24200,9350"/>',
      '<rect x="17500" y="9280" width="300" height="140" stroke-width="25" stroke="red" fill="red"/>',
      '</g>',
      '<g id="Dewar"  transform="translate(5000,5500) rotate(0)">',
      '  <g id="Wheels">',
      '    <circle cx="772" cy="4904" r="300" stroke="rgb(0,0,0)" stroke-width="25" fill="gray" />',
      '    <circle cx="2512" cy="4904" r="300" stroke="rgb(0,0,0)" stroke-width="25" fill="gray" />',
      '  </g>',
      '  <g id="Recovery">',
      '    <path fill="none" stroke="rgb(153,153,153)" stroke-width="81" stroke-linejoin="round" d="M 1000,-1300 L -1300,-1300 -1300,2500 -2000,2500"/>',
      '    <text x="0" y="0" font-size="30rem" transform="translate(-1700,1500) rotate(-90)">He recovery</text>',
      '  </g>',
      '  <g id="DewarBody">',
      '    <path style="fill:url(#DewarBlue)" d="M -53,73 L -51,16 -44,-40 -34,-95 -19,-294 -2,-202 19,-252 43,-299 69,-343 97,-384 128,-420 160,-453 194,-480 229,-502 264,-518 282,-524 300,-529 319,-531 337,-532 2880,-532 2898,-531 2917,-529 2935,-524 2953,-518 2988,-502 3023,-480 3057,-453 3089,-420 3120,-384 3149,-343 3175,-299 3199,-252 3220,-202 3237,-149 3252,-95 3262,-40 3269,16 3271,73 3271,4010 3269,4067 3262,4123 3252,4178 3237,4233 3220,4285 3199,4335 3175,4382 3149,4427 3120,4467 3089,4504 3057,4536 3023,4564 2988,4586 2953,4602 2935,4608 2917,4613 2898,4615 2880,4616 337,4616 319,4615 300,4613 282,4608 264,4602 229,4586 194,4564 160,4536 128,4504 97,4467 69,4427 43,4382 19,4335 -2,4285 -19,4233 -34,4178 -44,4123 -51,4067 -53,4010 -53,73 Z"/>',
      '    <path style="fill:url(#DewarBlue)" d="M 384,-989 L 386,-1011 391,-1032 400,-1054 411,-1075 426,-1096 445,-1118 489,-1159 545,-1199 610,-1237 684,-1273 767,-1307 952,-1366 1159,-1412 1380,-1442 1609,-1442 1837,-1442 2059,-1412 2266,-1366 2451,-1307 2533,-1273 2608,-1236 2673,-1199 2729,-1159 2773,-1118 2791,-1096 2806,-1075 2818,-1054 2827,-1032 2832,-1011 2834,-989 2834,-537 384,-527 384,-989 Z"/>',
      '  </g>',
      '</g>'].join('');
   document.getElementById('SVGholder').innerHTML = LowTempSVG;
}

function Omega_SVG()
{
   let OmegaSVG = [
      '<g id="TFL-Oven" transform="translate(-4000,-6000) rotate(0)">',
      '  <path fill="none" stroke="rgb(153,204,255)" stroke-width="159" stroke-linejoin="round" d="M 8800,9092 L 18000,9096"/>',
      '  <text x="8800" y="9092" font-size="30rem">N2 Line In</text>',
      '</g>',
      '<g id="N2Line" transform="translate(-7000,-6000) rotate(0)">',
      '  <path fill="none" stroke="rgb(153,204,255)" stroke-width="159" stroke-linejoin="round" d="M 21500,9500 L 19000,9500 19000,11972"/>',
      '  <text transform="translate(19000,11972) rotate(-90)" font-size="30rem">N2 Line Out</text>',
      '</g>',
      '<g id="Oven"  transform="translate(-7000,-6000) rotate(0)">',
      '  <g id="longline">',
      '    <path fill="none" stroke="rgb(0,0,0)" d="M 19565,10286 L 19565,7905"/>',
      '  </g>',
      '  <g id="shortline">',
      '    <path fill="none" stroke="rgb(0,0,0)" d="M 20993,9571 L 20993,8619"/>',
      '  </g>',
      '  <g id="flange">',
      '    <rect x="21232" y="7905" width="238" height="2381" stroke-width="25" stroke="rgb(0,0,0)" style="fill:url(#silver)"/>',
      '  </g>',
      '  <g id="LowerSheild">',
      '    <rect x="21270" y="8381" width="1905" height="1428" stroke-width="0" stroke="rgb(0,0,0)" style="fill:url(#silver)"/>',
      '  </g>',
      '  <g id="Sheild">',
      '    <rect x="23150" y="8381" width="1676" height="1428" stroke-width="0" stroke="rgb(0,0,0)" style="fill:url(#lightal)"/>',
      '  </g>',
      '  <g id="Center">',
      '    <rect x="21289" y="8857" width="2346" height="476" stroke-width="25" stroke-dasharray="50,50" fill="none" stroke="rgb(0,0,0)"/>',
      '  </g>',
      '  <g id="BasePlate">',
      '    <rect x="23635" y="8618" width="152" height="953" stroke-width="25" stroke-dasharray="50,50" fill="none" stroke="rgb(0,0,0)"/>',
      '  </g>',
      '  <g id="SamplePlate">',
      '    <rect x="23951" y="8618" width="152" height="953" stroke-width="25" stroke-dasharray="50,50" fill="none" stroke="rgb(0,0,0)"/>',
      '  </g>',
      '  <g id="Sapphire">',
      '    <rect x="23802" y="8718" width="152" height="773" stroke-width="25" stroke-dasharray="50,50" fill="none" stroke="rgb(0,0,0)"/>',
      '  </g>',
      '  <g id="N2-in">',
      '    <rect x="20760" y="8857" width="476" height="476" stroke-width="25" stroke="rgb(0,0,0)" style="fill:url(#silver)"/>',
      '  </g>',
      '</g>'].join('');
   document.getElementById('SVGholder').innerHTML = OmegaSVG;
}

function Bpar_SVG(cryo)
{
   let coordinates = "26200,5300";  //26200,2300
   if (cryo == "Omega") {
      coordinates = "16500,5000";
   }
   let FieldSVG = [
      '<g id="Bin" transform="translate('+coordinates+') rotate(0,350,350)">',
      '  <text class="TextShape"><tspan fill="rgb(0,255,150)" font-family="DejaVu Sans, sans-serif" font-size="1270px" font-weight="400" x="0" y="0" fill="rgb(0,0,0)" stroke="none">⊗</tspan></text>',
      '</g>'].join('');
   let FieldSVGin = [
      '<g id="Bout" transform="translate('+coordinates+') rotate(0,350,350)">',
      '  <text class="TextShape"><tspan fill="rgb(0,255,150)" font-family="DejaVu Sans, sans-serif" font-size="1270px" font-weight="400" x="0" y="0" fill="rgb(0,0,0)" stroke="none">⊙</tspan></text>',
      '</g>'].join('');
   document.getElementById('FieldHolder').innerHTML = FieldSVG;
}


function Bperp_SVG(cryo)
{
   // translate(15500,4500) for Oven
   // translate(18500,4500) for Konti/LT2
   let coordinates = "18500,4500";
   if (cryo == "Omega") {
      coordinates = "15500,4500";
   }
   let FieldSVG = [
      '<g id="B-RL" transform="translate('+coordinates+') rotate(0,1025,363)">',
      '  <path fill="rgb(0,255,150)" stroke="none" d="M 0,0 L 1537,0 1537,-181 2050,182 1537,545 1537,363 0,363 0,0 Z M 0,-181 L 0,-181 Z M 2050,545 L 2050,545 Z"/>',
      '</g>'].join('');
   document.getElementById('FieldHolder').innerHTML = FieldSVG;
}

function Muon_SVG()
{
   mjsonrpc_db_get_values(["/Info/SpinRot_Parameter/RotationAngle","/Info/Sample Cryo"]).then(function(rpc) {
      let spinangle = rpc.result.data[0];
      let lem_sample_cryo = rpc.result.data[1];
      if (lem_sample_cryo.startsWith("Konti")) {
         var coord = '(20000,2721)';
      } else if (lem_sample_cryo == "LowTemp-2") {
         var coord = '(20800,3000)';
      } else if (lem_sample_cryo == "Omega") {
         var coord = '(17000,2800)';
      } else {
         var coord = '(20000,3000)';
      }
      transform = 'translate'+coord+' rotate('+spinangle+',350,350)';
      let MuonSVG = [
         '<g id="Muon" transform="'+transform+'">',
	 '  <g id="Spin">',
	 '    <path fill="rgb(153,204,255)" stroke="none" d="M 280,1076 L 280,-143 199,-143 362,-549 525,-143 443,-143 443,1076 280,1076 Z M 199,-549 L 199,-549 Z M 525,1076 L 525,1076 Z"/>',
	 '  </g>',
	 '  <g id="Ball">',
	 '    <image x="0" y="0" width="700" height="700" xlink:href="sample/Ball.png"/>',
	 '  </g>',
	 '</g>'].join('\n');
      if (document.getElementById('MuonHolder')) {
	 document.getElementById('MuonHolder').innerHTML = MuonSVG;
      }
   }).catch(function(error){console.error(error);});
}

function updateSamcryo() {
   mjsonrpc_db_get_values(["/Info/Sample Cryo","/Info/LEM_Setup"]).then(function(rpc) {
      let lem_sample_cryo = rpc.result.data[0];
      let lem_setup = rpc.result.data[1];
      // Check if Controls exists if not return
      if (!document.getElementById("Controls")) return;
      if (lem_sample_cryo.includes("Konti-")) {
         if (document.getElementById("Controls").attributes["name"].value != "Konti") {
            Konti_Ctrl();
            Konti_SVG();
         }
         Konti_Histos();
         Konti_Params();
      } else if (lem_sample_cryo == "LowTemp-2") {
         if (document.getElementById("Controls").attributes["name"].value != "LowTemp") {
            LowTemp_Ctrl();
            LowTemp_SVG();
         }
         LowTemp_Histos();
         LowTemp_Params();
      } else if (lem_sample_cryo == "Omega" || lem_sample_cryo == "Oven") {
         if (document.getElementById("Controls").attributes["name"].value != "Omega") {
            Omega_Ctrl();
            Omega_SVG();
         }
         Omega_Histos();
         Omega_Params();
      } else {
         NoCryo();
      }

      if (lem_setup == "Sample, Bpar") {
         Bpar_SVG(lem_sample_cryo);
      } else if (lem_setup == "Sample, WEW") {
	 Bperp_SVG(lem_sample_cryo);
      }
      histRefresh();
   }).catch(function(error){console.error(error);});

   Muon_SVG();
}

// Begin: Functions for the APD calibration page
function turnoffon(Ch1,Ch2,Ch3) {
   // store values in slots
   storeODBvalue(Ch1);
   storeODBvalue(Ch2);
   storeODBvalue(Ch3);
   
   // set values to zero
   modbset('/Equipment/HV Detectors/Variables/Demand['+Ch1+']', 0);
   modbset('/Equipment/HV Detectors/Variables/Demand['+Ch2+']', 0);
   modbset('/Equipment/HV Detectors/Variables/Demand['+Ch3+']', 0);
}

function restoreVset(Ch1,Ch2,Ch3,Ch4) {
   // get old values
   let Vset1= document.getElementById("slot"+Ch1).innerHTML;
   let Vset2= document.getElementById("slot"+Ch2).innerHTML;
   let Vset3= document.getElementById("slot"+Ch3).innerHTML;
   let Vset4= document.getElementById("slot"+Ch4).innerHTML;
   
   // set values to zero
   if (Vset1 != 0) modbset('/Equipment/HV Detectors/Variables/Demand['+Ch1+']', Vset1);
   if (Vset2 != 0) modbset('/Equipment/HV Detectors/Variables/Demand['+Ch2+']', Vset2);
   if (Vset3 != 0) modbset('/Equipment/HV Detectors/Variables/Demand['+Ch3+']', Vset3);
   if (Vset4 != 0) modbset('/Equipment/HV Detectors/Variables/Demand['+Ch4+']', Vset4);

   // clear old values
   document.getElementById("slot"+Ch1).innerHTML = "";
   document.getElementById("slot"+Ch2).innerHTML = "";
   document.getElementById("slot"+Ch3).innerHTML = "";
   document.getElementById("slot"+Ch4).innerHTML = "";
}

function showSegment() {
   // get segment name
   let segName = document.getElementById("segments").value;
   let tmp = document.getElementById("storage").value;
   document.getElementById("storage").value = segName;
   var chSeg = {};
   // These are the channel numbers in each segment
   // Left
   chSeg["LDI"]=[9,13,17,21];
   chSeg["LDO"]=[10,14,18,22];
   chSeg["LUI"]=[11,15,19,23];
   chSeg["LUO"]=[12,16,20,24];
   // Right
   chSeg["RDI"]=[41,45,49,53];
   chSeg["RDO"]=[42,46,50,54];
   chSeg["RUI"]=[43,47,51,55];
   chSeg["RUO"]=[44,48,52,56];
   // Bottom
   chSeg["BDI"]=[25,29,33,37];
   chSeg["BDO"]=[26,30,34,38];
   chSeg["BUI"]=[27,31,35,39];
   chSeg["BUO"]=[28,32,36,40];
   // Top
   chSeg["TDI"]=[57,61,1,5];
   chSeg["TDO"]=[58,62,2,6];
   chSeg["TUI"]=[59,63,3,7];
   chSeg["TUO"]=[60,64,4,8];

   // Now generate html code for the selected segment
   let ch1=chSeg[segName][0];
   let ch2=chSeg[segName][1];
   let ch3=chSeg[segName][2];
   let ch4=chSeg[segName][3];
   let ch1odb=chSeg[segName][0]+29;
   let ch2odb=chSeg[segName][1]+29;
   let ch3odb=chSeg[segName][2]+29;
   let ch4odb=chSeg[segName][3]+29;
   // turn these off
   let off1= ch2odb+','+ch3odb+','+ch4odb;
   let off2= ch1odb+','+ch3odb+','+ch4odb;
   let off3= ch1odb+','+ch2odb+','+ch4odb;
   let off4= ch1odb+','+ch2odb+','+ch3odb;
   let allCh= ch1odb+','+ch2odb+','+ch3odb+','+ch4odb;
   let segHtml= '<td></td><td><label for="Ch'+ch1+'"><input type="radio" name="'+segName+'" id="Ch'+ch1+'" onclick="turnoffon('+off1+');">Ch '+ch1+'</label></label></td><td><label for="Ch'+ch2+'"><input type="radio" name="'+segName+'" id="Ch'+ch2+'" onclick="turnoffon('+off2+');">Ch '+ch2+'</label></label></td><td><label for="Ch'+ch3+'"><input type="radio" name="'+segName+'" id="Ch'+ch3+'" onclick="turnoffon('+off3+');">Ch '+ch3+'</label></label></td><td><label for="Ch'+ch4+'"><input type="radio" name="'+segName+'" id="Ch'+ch4+'" onclick="turnoffon('+off4+');">Ch '+ch4+'</label></label></td>';
   document.getElementById("chSegment").innerHTML = segHtml;
   let voltages = '<td>V (V)</td><td><span name="modbvalue" data-format="f2" data-odb-path="/Equipment/HV Detectors/Variables/Demand['+ch1odb+']" data-odb-editable="1"></span></td><td><span name="modbvalue" data-format="f2" data-odb-path="/Equipment/HV Detectors/Variables/Demand['+ch2odb+']" data-odb-editable="1"></span></td><td><span name="modbvalue" data-format="f2" data-odb-path="/Equipment/HV Detectors/Variables/Demand['+ch3odb+']" data-odb-editable="1"></span></td><td><span name="modbvalue" data-format="f2" data-odb-path="/Equipment/HV Detectors/Variables/Demand['+ch4odb+']" data-odb-editable="1"></span></td>';
   document.getElementById("chVoltages").innerHTML = voltages;
   let currents = '<td>I (uA)</td><td><span name="modbvalue" data-format="f2" data-odb-path="/Equipment/HV Detectors/Variables/Current['+ch1odb+']" ></span></td><td><span name="modbvalue" data-format="f2" data-odb-path="/Equipment/HV Detectors/Variables/Current['+ch2odb+']" ></span></td><td><span name="modbvalue" data-format="f2" data-odb-path="/Equipment/HV Detectors/Variables/Current['+ch3odb+']" ></span></td><td><span name="modbvalue" data-format="f2" data-odb-path="/Equipment/HV Detectors/Variables/Current['+ch4odb+']" ></span></td>';
   document.getElementById("chCurrents").innerHTML = currents;
   let vset = '<td align="center"><a style="cursor: pointer" onclick="restoreVset('+allCh+');">Restore &uarr;</a></td><td id="slot'+ch1odb+'"></td><td id="slot'+ch2odb+'"></td><td id="slot'+ch3odb+'"></td><td id="slot'+ch4odb+'"></td>'
   document.getElementById("Vsetstorage").innerHTML = vset;
}

function chDemand(i) {
   var xmlDoc;
   var xmlFile = 'tabs/APD_ZF.xml';
   xmlhttp=new XMLHttpRequest();
   xmlhttp.open("GET",xmlFile,false);
   if (xmlhttp.overrideMimeType){
      xmlhttp.overrideMimeType('text/xml');
   }
   xmlhttp.send();
   xmlDoc=xmlhttp.responseXML;
   var nNodes=xmlDoc.getElementsByTagName("hvCh")[i-30].childNodes;
   var nCh=xmlDoc.getElementsByTagName("hvCh")[i-30].firstChild;
   while (nCh.nodeName != "hvDemand") {
      nCh = nCh.nextSibling;
   }    
   var chDemand = nCh.firstChild.nodeValue * 1.0;
   console.log('Demand value should be: '+chDemand);
   showSegment("LDI");
   return(chDemand);
}


function readXml(xmlFile){
   var xmlDoc;
   xmlhttp=new XMLHttpRequest();
   xmlhttp.open("GET",xmlFile,false);
   if (xmlhttp.overrideMimeType){
      xmlhttp.overrideMimeType('text/xml');
   }
   xmlhttp.send();
   xmlDoc=xmlhttp.responseXML;
   var nNodes=xmlDoc.getElementsByTagName("hvCh")[0].childNodes;
   var nCh=xmlDoc.getElementsByTagName("hvCh");
   
   for (k = 0; k < nCh.length; k++) {          
      y = xmlDoc.getElementsByTagName("hvCh")[k].firstChild;
      for (i = 0; i < nNodes.length; i++) //looping xml childnodes
      {            
	 if (y.nodeType == 1) {
            console.log(y.nodeName + ":" + y.firstChild.nodeValue);
	 }
	 y = y.nextSibling;
      }
      console.log("-------------------");
   }
}

function storeODBvalue (nCh) {
   let ODBpath = "/Equipment/HV Detectors/Variables/Demand["+nCh+"]";
   let slot = "slot"+nCh;
   mjsonrpc_db_get_values([ODBpath]).then(function(rpc) {
      value = rpc.result.data[0];
      document.getElementById(slot).innerHTML = value.toFixed(2);
      return value;
   })
}

// End: Functions for the APD calibration page

function mkEquipmentTable(equipment,starti = -1,endi = -1, tableID) {
   // Create a html table of voltages
   const names = "/Equipment/"+equipment+"/Settings/Names";
   const vardemand = "/Equipment/"+equipment+"/Variables/Demand";
   const varmeas = "/Equipment/"+equipment+"/Variables/Measured";
   const curr = "/Equipment/"+equipment+"/Variables/Current";
   const currlimit = "/Equipment/"+equipment+"/Settings/Current Limit";
   let eqFlag = 1;
   // Place holders for demand and readback
   const modb_edit = "<span class='modbvalue' data-format='f3' data-odb-editable='1' data-odb-path='dataODBPath'></span>";
   const modb_read = "<span class='modbvalue' data-format='f3' data-odb-path='dataODBPath'></span>";
   let table = "<table class='mtable oddeven' style='width: 100%;border: 0px;max-height:500px;'>\n";

   // Check which ODB keys are available
   mjsonrpc_db_key([names,vardemand,varmeas,curr,currlimit]).then(function (rpc) {
      // The usual number of columns of the table
      let ncols = 3;
      if (rpc.result.status[3] == 1 && rpc.result.status[4] == 1) {
         // need extra columns
         ncols = 5;
         table += "<tr><th>Name</th><th>Demand</th><th>Measured</th><th>Current</th><th>Current limit</th></tr>\n";
      } else {
         table += "<tr><th>Name</th><th>Demand</th><th>Measured</th></tr>\n";
      }
      if (starti == -1) {
         starti = 0;
         //console.log(rpc.result.keys);
         if (rpc.result.keys[0] !== null) {
            endi = rpc.result.keys[0].num_values - 1;
         } else {
            eqFlag = 0;
         }
      }

      if (eqFlag) {
         for (var i=starti;i<endi+1;i++){
            let odbName = modb_read.replace("dataODBPath",names + "[" + i + "]");
            let odbDemand = modb_edit.replace("dataODBPath",vardemand + "[" + i + "]");
            let odbMeasured = modb_read.replace("dataODBPath",varmeas + "[" + i + "]");
            let row = "<td id='Ch"+i+"n'>"+odbName+"</td>\n";
            row += "<td class='tdSelectable' onclick='toggleColor(this);' id='Ch"+i+"'>"+odbDemand+"</td>\n";
            row += "<td id='Ch"+i+"m'>"+odbMeasured+"</td>\n";
            if (ncols == 5) {
               let odbCurr = modb_read.replace("dataODBPath",curr + "[" + i + "]");
               row += "<td id='Ch"+i+"c'>"+odbCurr+"</td>\n";
               let odbCurrLim = modb_edit.replace("dataODBPath",currlimit + "[" + i + "]");
               row += "<td class='tdCurrent' id='Ch"+i+"l'>"+odbCurrLim+"</td>\n";
            }
            table += "<tr>\n" + row + "</tr>\n";
         }
         table += "</table>\n";
      } else {
         let statusTable = loadAscii("/?cmd=eqtable&eq=" + equipment,1);
         const parser = new DOMParser();
         const doc = parser.parseFromString(statusTable, "text/html");

         const trElements = doc.querySelectorAll("tr");
         table = "<table>";
         for (let i = 2; i< trElements.length; i++) {
            table += trElements[i].outerHTML;
         };
         table += "</table>";
      }
      document.getElementById(tableID).innerHTML=table;
      // return as promise ...
      //return table;
   }).catch(function (error) {
      console.log(error);
   });
}

// Begin: Functions for the HV Edit page

// ToDo this function should check that the set value is within the limits
function checkEqLimit(value, element) {
   return true;
   console.log("value=",value);
   console.log("element=",element);
   let dataODBPath = element.getAttribute("data-odb-path");
   console.log("data-odb-path=",dataODBPath);
}

function showHVtable() {
   // get HV table name
   let tableName = document.getElementById("HVSettings").value;
   // Default is FUG
   let equipment = "HV";
   let starti = 0;
   let endi = 15;
   if (tableName == "NHR") {
      equipment = "HV Detectors";
      starti = 0;
      endi = 7;
   } else if (tableName == "PHVR400") {
      equipment = "HV Detectors";
      starti = 8;
      endi = 10;
   } else if (tableName == "NHR400") {
      equipment = "HV Detectors";
      starti = 20;
      endi = 27;
   } else if (tableName == "HPP30_107") {
      equipment = "HV Detectors";
      starti = 28;
      endi = 28;
   } else if (tableName == "HPN30_107") {
      equipment = "HV Detectors";
      starti = 29;
      endi = 29;
   } else if (tableName == "APD") {
      equipment = "HV Detectors";
      starti = 30;
      endi = 93;
   } else if (tableName == "hvr80flame") {
      equipment = "hvr80flame0";
      starti = 0;
      endi = 31;
   }
   mkEquipmentTable(equipment,starti,endi,"HVTable");
}

function openFile(event) {
   let input = event.target;
   let reader = new FileReader();
   reader.onload = function(){
      let text = reader.result;
      let table = xmlToTable(text);
      popModal("popPrompt");
      document.getElementById("popHTML").innerHTML = table;
      document.getElementById("popButton").textContent = "Load";
      document.getElementById("popButton").addEventListener("click",loadHV);
      document.getElementById("popButton").addEventListener("click",closeModal);
   };
   reader.readAsText(input.files[0]);
}

function xmlToTable(text) {
   var parser = new DOMParser();
   var xmlDoc = parser.parseFromString(text,"text/xml");
   // Get device name and switch to it, otherwise loading will be a problem
   let device = xmlDoc.getElementsByTagName("hvDeviceName")[0].innerHTML.trim();
   let description = xmlDoc.getElementsByTagName("description")[0].innerHTML.trim();
   // Take possible options and selected index
   let HVoptions = document.getElementById("HVSettings").options;
   let selDevice = document.getElementById("HVSettings").selectedIndex;
   
   // if the loaded field does not match selected device adjust
   if (HVoptions[selDevice].value != device) {
      console.log("changing from",HVoptions[selDevice].value," to ",device);
      document.getElementById("HVSettings").value=device;
      showHVtable();
   }

   // Parse XML file for settings
   let names = xmlDoc.getElementsByTagName("name");
   let demands = xmlDoc.getElementsByTagName("hvDemand");
   let limits = xmlDoc.getElementsByTagName("currentLimit");
   
   // Create preload table
   var table = "<table><tr><td>";
   table += "<table style='border: 3px;'>\n";
   table += "<tr><th>Name</th><th>Demand</th><th>Current limit</th></tr>\n"
   for (let i=0; i<names.length; i++) {
      let name = names[i].innerHTML;
      let demand = demands[i].innerHTML;
      let limit = limits[i].innerHTML;
      
      table += "<tr>\n";
      table += "<td id='" + name + "'>"+name+"</td>\n";
      table += "<td class='tdIgnorable' onclick='toggleColor(this);'><input class='demandVal' type='number'  style='width:5em' id='" + name + "d' value='"+demand+"'>&nbsp;&nbsp;&#9747;&nbsp;&nbsp;</td>\n";
      table += "<td class='tdIgnorable' onclick='toggleColor(this);'><input class='currentLim' type='number' style='width:5em' id='" + name + "l' value='"+limit+"'>&nbsp;&nbsp;&#9747;&nbsp;&nbsp;</td>\n";
      table += "</tr>\n";	    
   }	
   table += "</table></td>\n";

   table += "<td style='width:50%;vertical-align:top;'><div class='tdIgnored'>Highlight (&nbsp;&nbsp;&#9747;&nbsp;&nbsp;) cell to ignore.</div><br><br><b>Comment</b><div><textarea style='width:100%;height:5em;' id='description'>"+description+"</textarea></div></td></tr></table>";
   return table;
}

// This function is used to toggle the highlight of selected cells
// in the HV and Beamline tables
function toggleColor(element) {
   if (element.className == "tdSelectable") {
      element.className = "tdSelected";
   } else if (element.className == "tdSelected") {
      element.className = "tdSelectable";
   } else if (element.className == "tdIgnorable") {
      element.className = "tdIgnored";
   } else if (element.className == "tdIgnored") {
      element.className = "tdIgnorable";
   }
}

// This function is used to toggle the highlight of all cells
// in the HV tables
// newState - all/none toggled to state
function toggleAll(tableID,newState) {
   let selCells = [];
   if (tableID) {
      selCells = [...document.getElementById(tableID).getElementsByClassName("tdSelectable"), ...document.getElementById(tableID).getElementsByClassName("tdSelected")];
   } else {
      selCells = [...document.getElementsByClassName("tdSelectable"), ...document.getElementsByClassName("tdSelected")];
   }
   let curState = selCells[0].className;
   
   if (newState == "" || newState == undefined || newState == null) {
      if (curState == "tdSelectable") {
	 var newState = "tdSelected";
      } else {
	 var newState = "tdSelectable";
      }
   }
   
   // Loop over cells and set to new state
   for (let i=0; i<selCells.length; i++) {
      selCells[i].className = newState;
   }
}

// This function is used to turn off all elements in the HV tables
function turnVOff() {
   if (!confirm('Are you sure you want to turn off all voltages?'))
      return;

   let HVTable = document.getElementById("HVTable");
   let selCells = [];
   selCells = [...HVTable.getElementsByClassName("tdSelectable"), ...HVTable.getElementsByClassName("tdSelected")];
   
   // Loop over cells and set to new state
   for (let i=0; i<selCells.length; i++) {
      let odbPath =  selCells[i].getElementsByClassName("modbvalue")[0].dataset.odbPath;
      mjsonrpc_db_get_values([odbPath]).then(function(rpc) {
	 let curvalue = rpc.result.data[0];
	 let setvalue = 0;
	 // store current value
	 selCells[i].value = curvalue;
	 // Turn all off 
	 modbset(odbPath,setvalue);
      }).catch(function(error){console.error(error);});
   }
}


// This function is used to ramp up/down the selected
// HV cells, zero or restore.
// dV = 0 - zero selected
// dV = 2 - restore selected
// dV = ? - increment selected by dV
function rampV(dV,tableID) {
   let selCells = document.getElementsByClassName("tdSelected");
   if (tableID)
      selCells = document.getElementById(tableID).getElementsByClassName("tdSelected");
   for (let i=0; i<selCells.length; i++) {
      // Get the odb path of each selected cell
      let odbPath =  selCells[i].getElementsByClassName("modbvalue")[0].dataset.odbPath;
      console.log(odbPath,dV);
      if (dV==0) {
	 mjsonrpc_db_get_values([odbPath]).then(function(rpc) {
	    let curvalue = rpc.result.data[0];
	    let setvalue = 0;
	    // store current value
	    selCells[i].value = curvalue;
	    // Turn off selected values
	    modbset(odbPath,setvalue);
	 }).catch(function(error){console.error(error);});
      } else if (dV == "r") {
	 // Restore saved values from Zero button
	 let setvalue = selCells[i].value;
	 // set new value
	 modbset(odbPath,setvalue);
      } else {
	 // Read the value and then increment/decrement
	 mjsonrpc_db_get_values([odbPath]).then(function(rpc) {
	    let curvalue = rpc.result.data[0];
	    let setvalue = curvalue+dV;
	    // set new value
	    // ToDo check limits before setting
	    modbset(odbPath,setvalue);
	 }).catch(function(error){console.error(error);});
      }
   }
}

function loadBL() {
   let demands = document.getElementsByClassName("demandVal");
   let blTable = document.getElementById("blTable"); 
   // Assume same order as HV table
   let demCells = [];
   // This is a problem if some of the cells are selected, the order will be wrong
   // To star with unselect all cells
   toggleAll("blTable","tdSelectable");
   demCells = [...blTable.getElementsByClassName("tdSelectable")];
   for (let i=0;i<demands.length;i++) {
      let demandi = demands[i].value;
      let odbPathDem =  demCells[i].getElementsByClassName("modbvalue")[0].dataset.odbPath;
      // set values in ODB skipping ignored cells
      if (demands[i].parentElement.className !== "tdIgnored" && demandi !== "") {
	 modbset(odbPathDem,demandi);
	 //console.log("Set ",odbPathDem," to ",demandi);
      } else {
	 console.log("Ignored ",demandi)
      }	    
   }
}

function loadHV() {
   let demands = document.getElementsByClassName("demandVal");
   let currents = document.getElementsByClassName("currentLim");
   let HVTable = document.getElementById("HVTable");
   // Assume same order as HV table
   let demCells = [];
   // This is a problem if some of the cells are selected, the order will be wrong
   // To star with unselect all cells
   toggleAll("HVTable","tdSelectable");
   demCells = [...HVTable.getElementsByClassName("tdSelectable")];
   let curCells = [];
   curCells = [...HVTable.getElementsByClassName("tdCurrent")];
   for (let i=0;i<demands.length;i++) {
      let demandi = demands[i].value;
      let currenti= currents[i].value;
      let odbPathVol =  demCells[i].getElementsByClassName("modbvalue")[0].dataset.odbPath;
      let odbPathCur =  curCells[i].getElementsByClassName("modbvalue")[0].dataset.odbPath;
      // set values in ODB skipping ignored cells
      if (demands[i].parentElement.className !== "tdIgnored") {
	 modbset(odbPathVol,demandi);
	 //console.log("Set ",odbPathVol," to ",demandi);
      } else {
	 console.log("Ignored ",demands[i].id)
      }	    

      if (currents[i].parentElement.className !== "tdIgnored") {
	 modbset(odbPathCur,currenti);
	 //console.log("Set ",odbPathCur," to ",currenti);
      } else {
	 console.log("Ignored ",currents[i].id)
      }
   }
}

function saveFile() {
   // get HV device name
   let device = document.getElementById("HVSettings").value;

   // Read HV details from ODB
   // Default is FUG
   let equipment = "HV";
   let units = "chHV/chCurrentLimit in (kV/mA)";
   let starti = 0;
   let endi = 15;
   if (device == "NHR") {
      equipment = "HV Detectors";
      starti = 0;
      endi = 7;
   } else if (device == "PHVR400") {
      equipment = "HV Detectors";
      starti = 8;
      endi = 10;
   } else if (device == "NHR400") {
      equipment = "HV Detectors";
      starti = 20;
      endi = 27;
   } else if (device == "HPP30_107") {
      equipment = "HV Detectors";
      starti = 28;
      endi = 28;
   } else if (device == "HPN30_107") {
      equipment = "HV Detectors";
      starti = 29;
      endi = 29;
   } else if (device == "APD") {
      equipment = "HV Detectors";
      starti = 30;
      endi = 93;
      units = "chHV/chCurrentLimit in (V/uA)";
   }else if (device == "hvr80flame") {
      equipment = "hvr80flame0";
      starti = 0;
      endi = 31;
      units = "V";
   }

   // Set correct odb paths
   var names = "/Equipment/"+equipment+"/Settings/Names";
   var currlimit = "/Equipment/"+equipment+"/Settings/Current Limit";
   var vardemand = "/Equipment/"+equipment+"/Variables/Demand";
   var range = "["+starti+"-"+endi+"]";

   var odbPaths = [names+range,vardemand+range,currlimit+range];
   var N=endi-starti;
   var comment = prompt("Please enter an optional description","This is a description");
   if (comment != null) { 
      mjsonrpc_db_get_values(odbPaths).then(function(rpc) {
	 var doc = '<HV xmlns="http://nemu.web.psi.ch/HV">\n';
	 doc += '<comment>\n';
	 doc += new Date();
	 doc += '\n'+units+'\n';
	 doc += '</comment>\n<description>\n';
	 doc += comment;
	 doc += '\n</description>\n';
	 doc += '<hvDeviceName>\n';
         doc += device;
         doc += '\n</hvDeviceName>\n';
         for (let i=0;i<=N;i++) {
            if (instrName == "LEM") {
               odbname=rpc.result.data[0][i].split("%")[1];
            } else {
               odbname=rpc.result.data[0][i];
            }
            odbdemand=Math.round(rpc.result.data[1][i] * 1000)/1000;
            odblimit=rpc.result.data[2][i];
            doc += '<hvCh name="' + odbname + '">\n';
	    doc += '  <chNo>' + (i+1) + '</chNo>\n';
	    doc += '  <name>' + odbname + '</name>\n';
	    doc += '  <hvDemand>' + odbdemand + '</hvDemand>\n';
	    doc += '  <currentLimit>' + odblimit + '</currentLimit>\n';
	    doc += '</hvCh>\n';
	 }
	 doc += '</HV>\n';
	 table = xmlToTable(doc);
	 download(doc,"HV.xml","text/plain");
      }).catch(function(error){console.error(error);});    
   }
}

// Function to download data to a file
function download(data, filename, type) {
   var file = new Blob([data], {type: type});
   if (window.navigator.msSaveOrOpenBlob) // IE10+
      window.navigator.msSaveOrOpenBlob(file, filename);
   else { // Others
      var a = document.createElement("a");
      url = URL.createObjectURL(file);
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      setTimeout(function() {
         document.body.removeChild(a);
         window.URL.revokeObjectURL(url);  
      }, 0); 
   }
}

// Function to load ODB json file from server
function serverBLSet(filename){
   file_load_ascii(filename,function(content) {
      // `data` contains the parsed JSON object
      const data = JSON.parse(content);
      const path = data["/ODB path"];
      const names = data.Settings.Names;
      const demands = data.Variables.Demand;
      
      // Create preload table
      var table = "<table><tr><td>";
      table += "<table style='border: 3px;'>\n";
      for (let i=0; i<names.length; i++) {
	 let name = names[i];
	 let demand = demands[i];
	 
	 table += "<tr>\n";
	 table += "<td id='" + name + "'>"+name+"</td>\n";
	 table += "<td class='tdIgnorable' onclick='toggleColor(this);'><input class='demandVal' type='number' style='width:5em' id='" + name + "d' value='"+demand+"'>&nbsp;&nbsp;&#9747;&nbsp;&nbsp;</td>\n";
	 table += "</tr>\n";	    
      }	
      table += "</table></td>\n";
      table += "<td style='width:50%;vertical-align:top;'><div class='tdIgnored'>Highlight (&nbsp;&nbsp;&#9747;&nbsp;&nbsp;) cell to ignore.</div></td></tr></table>";

      // Show table in dialog
      popModal("popPrompt");
      document.getElementById("popHTML").innerHTML = table;
      document.getElementById("popButton").textContent = "Load";
      document.getElementById("popButton").addEventListener("click",loadBL);
      document.getElementById("popButton").addEventListener("click",closeModal);
   });
}


// Function to load standard HV setting from server
function serverHVSet(filename){
   if (!filename) { 
      filename = document.getElementById("serverHVSet").value;
   }
   document.getElementById("curTransport").innerHTML = filename;
   file_load_ascii(filename,function(content) {
      //console.log(content);
      let table = xmlToTable(content);
      popModal("popPrompt");
      document.getElementById("popHTML").innerHTML = table;
      document.getElementById("popButton").textContent = "Load";
      document.getElementById("popButton").addEventListener("click",loadHV);
      document.getElementById("popButton").addEventListener("click",closeModal);
   });
   // Change value back to none
   document.getElementById("serverHVSet").value = "none";
}

function selColl(coll) {
   let fillTrOpts = `
        <option value="none">none</option>
        <option value="hv_settings/fug_07-5kV_1-7ug.xml">7.5 keV</option>
        <option value="hv_settings/fug_08-5kV_1-7ug.xml">8.5 keV</option>
        <option value="hv_settings/fug_09-0kV_1-7ug.xml">9.0 keV</option>
        <option value="hv_settings/fug_10-0kV_1-7ug.xml">10.0 keV</option>
        <option value="hv_settings/fug_11-0kV_1-7ug.xml">11.0 keV</option>
        <option value="hv_settings/fug_12-0kV_1-7ug.xml">12.0 keV</option>
        <option value="hv_settings/fug_13-5kV_1-7ug.xml">13.5 keV</option>
        <option value="hv_settings/fug_14-3kV_1-7ug.xml">14.3 keV</option>
        <option value="hv_settings/fug_15-0kV_1-7ug.xml">15.0 keV</option>
        <option value="hv_settings/fug_16-5kV_1-7ug.xml">16.5 keV</option>
        `;
   if (coll == "1.5cm") {
      fillTrOpts = `
            <option value="none">none</option>
            <option value="hv_settings/1.5cmCollimator/fug_07-5kV_1-7ug_SRon_1.5cmCollimator.xml">7.5 keV</option>
            <option value="hv_settings/1.5cmCollimator/fug_10-0kV_1-7ug_SRon_1.5cmCollimator.xml">10.0 keV</option>
            <option value="hv_settings/1.5cmCollimator/fug_12-0kV_1-7ug_SRon_1.5cmCollimator.xml">12.0 keV</option>
            <option value="hv_settings/1.5cmCollimator/fug_15-0kV_1-7ug_SRon_1.5cmCollimator.xml">15.0 keV</option>
            `;
   } else if (coll == "1.0cm") {
      fillTrOpts = `
            <option value="none">none</option>
            <option value="hv_settings/1.0cmCollimator/fug_07-5kV_1-7ug_SRoff_1.0cmCollimator.xml">7.5 keV</option>
            <option value="hv_settings/1.0cmCollimator/fug_10-0kV_1-7ug_SRoff_1.0cmCollimator.xml">10.0 keV</option>
            <option value="hv_settings/1.0cmCollimator/fug_12-0kV_1-7ug_SRoff_1.0cmCollimator.xml">12.0 keV</option>
            <option value="hv_settings/1.0cmCollimator/fug_15-0kV_1-7ug_SRoff_1.0cmCollimator.xml">15.0 keV</option>
            `;
   }
   document.getElementById("serverHVSet").innerHTML = fillTrOpts;
}


// End: Functions for the HV Edit page

function highlight(e) {
   let text= e.currentTarget.textContent;
   let text_array = text.split("\n");
   let new_text = syntax_lar(text_array);
   //    var tex=element.innerHTML;
   console.log(new_text);
   e.currentTarget.innerHTML=new_text;

}

var mjsonvalue;
function modbget(path) {
   mjsonrpc_db_get_value(path).then(function(rpc){
      mjsonvalue = rpc.result.data[0];
      //	console.log("inside=",mjsonvalue);
   }).catch (function (error) { console.error(error);});
}

// Function for RunLog
// ToDo: get the runlog file name from the ODB
// Path: /Logger/Data dir
// File name:  ??

function LoadFile() {
   var oFrame = document.getElementById("frmFile");
   var strRawContents = oFrame.contentWindow.document.body.childNodes[0].innerHTML;
   // Get tne number of requested lines to show
   var nlines = document.getElementById("numlines").value;
   var dispLines = "";
   var tabLines = "<tr style='font-family:\"Fixed\"; font-size:120%'><td><b>Run</b></td><td><b>Start Date::Time --- Duration</b></td><td><b>Statistics</b></td><td><b>Run Title --- Propsal Number</b></td></tr>";
   // Clean up file if needed
   while (strRawContents.indexOf("\r") >= 0) strRawContents = strRawContents.replace("\r", "");
   // Split file into lines
   var arrLines = strRawContents.split("\n");
   console.log("number of lines in file ="+arrLines.length);
   // The number of requested lines should not be larger than the actual number of lines
   if (nlines > arrLines.length) {
      nlines=arrLines.length-2;
      document.getElementById("numlines").value = nlines;
   }
   for (var i = arrLines.length-2; i > arrLines.length-2-nlines; i--) {
      var curLine = arrLines[i];
      var words = curLine.split('\t');
      var tabLine = "<tr><td>" + words[0] + "</td><td>" + words[1] + "</td><td>" + words[2] + "</td><td>" + words[3] + "</td></tr>";
      dispLines = [dispLines,curLine].join('<br>\n');
      tabLines = [tabLines,tabLine].join('\n');
   }
   document.getElementById('runlogtable').innerHTML = tabLines;
}

function goSearchDB() {
   var fromRun = document.getElementById("fromrun").value;
   var toRun = document.getElementById("torun").value;
   var year = new Date().getFullYear();
   if (fromRun > 0 && toRun > 0) {
      // send to SearchDB.cgi
      // http://musruser.psi.ch/cgi-bin/SearchDB.cgi?AREA=LEM&YEAR=2020&AFTER=&BEFORE=&RUN=&Rmin=100&Rmax=200&Phrases=&go=Search
      var url = "http://musruser.psi.ch/cgi-bin/SearchDB.cgi?AREA=LEM&YEAR=" + year + "&AFTER=&BEFORE=&RUN=&Rmin=" + fromRun + "&Rmax=" + toRun + "&Phrases=&go=Search";
      window.open(url);
   }
}



// Function for Vacuum 
// decoding bits for pump and valve states
const LV_BIT0=0x0100;
const LV_BIT1=0x0200;
const LV_BIT2=0x0400;
const LV_BIT3=0x0800;
const LV_BIT4=0x1000;
const LV_BIT5=0x2000;
const LV_BIT6=0x4000;
const LV_BIT7=0x8000;
const LV_BIT8=0x0001;
const LV_BIT9=0x0002;
const LV_BIT10=0x0004;
const LV_BIT11=0x0008;
const LV_BIT12=0x0010;
const LV_BIT13=0x0020;
const LV_BIT14=0x0040;
const LV_BIT15=0x0080;   

var lemvac_data_in = [];
var lemvac_data_out = [];
var lemvac_fe_state = -1;


function update_vacuum() {
   
   // get input/output data from ODB
   mjsonrpc_db_get_values(["Equipment/LEMVAC/Variables/Input","Equipment/LEMVAC/Variables/Output"]).then(function(rpc) {
      lemvac_data_in = rpc.result.data[0];
      lemvac_data_out = rpc.result.data[1];
   }).catch (function (error) {
      mjsonrpc_error_alert(error);
   });         
   
   // get state of the frontend 
   mjsonrpc_call("cm_exist", "{ \"name\": \"LEMVAC_SC\" }").then(function(rpc) {
      lemvac_fe_state = rpc.result.status;
   }).catch (function(error) {
      mjsonrpc_error_alert(error);
   });

   lemvac();       
   update_pressure_values();
   update_pressure_gauge_states();
   update_valve_states();
   update_pump_states();
}

function update_pressure_values() {
   // piranni underneath the MC turbo
   if (lemvac_data_in.length === 0) {
      document.getElementById('MC_buffer_gauge_pressure').innerHTML = "undef";
   } else if (lemvac_data_in[1] <= 1.0e-4) {
      document.getElementById('MC_buffer_gauge_pressure').innerHTML = "underrange";
   } else {
      var val = lemvac_data_in[1].toExponential(2);
      document.getElementById('MC_buffer_gauge_pressure').innerHTML = val + "mbar";
   }
   // piranni MC
   if (lemvac_data_in.length === 0) {
      document.getElementById('MC_G1_high_pressure').innerHTML = "undef";         
   } else if (lemvac_data_in[2] <= 1.0e-4) {
      document.getElementById('MC_G1_high_pressure').innerHTML = "underrange";         
   } else {
      var val = lemvac_data_in[2].toExponential(2);
      document.getElementById('MC_G1_high_pressure').innerHTML = val + "mbar";         
   }
   // 1st penning MC
   if (lemvac_data_in.length === 0) {
      document.getElementById('MC_G1_low_pressure').innerHTML = "undef";
   } else if (lemvac_data_in[3] <= 1.0e-11) {
      if (lemvac_data_in[2] >= 1.0e-4) { // piranni above 1e-4 mbar
         document.getElementById('MC_G1_low_pressure').innerHTML = "off";
      } else {
         document.getElementById('MC_G1_low_pressure').innerHTML = "underrange";
      }         
   } else if (lemvac_data_in[3] > 1.0e-1) {
      document.getElementById('MC_G1_low_pressure').innerHTML = "off";
   } else {
      var val = lemvac_data_in[3].toExponential(2);
      document.getElementById('MC_G1_low_pressure').innerHTML = val + "mbar";
   }
   // 2nd penning MC 
   if (lemvac_data_in.length === 0) {
      document.getElementById('MC_G2_low_pressure').innerHTML = "undef";
   } else if (lemvac_data_in[4] <= 1.0e-11) {
      if (lemvac_data_in[2] >= 1.0e-4) { // piranni above 1e-4 mbar
         document.getElementById('MC_G2_low_pressure').innerHTML = "off";
      } else {
         document.getElementById('MC_G2_low_pressure').innerHTML = "underrange";
      }         
   } else if (lemvac_data_in[4] > 1.0e-1) {
      document.getElementById('MC_G2_low_pressure').innerHTML = "off";
   } else {
      var val = lemvac_data_in[4].toExponential(2);
      document.getElementById('MC_G2_low_pressure').innerHTML = val + "mbar";
   }
   
   // piranni underneath the TC turbo
   if (lemvac_data_in.length === 0) {
      document.getElementById('TC_buffer_gauge_pressure').innerHTML = "undef";
   } else if (lemvac_data_in[5] <= 1.0e-4) {
      document.getElementById('TC_buffer_gauge_pressure').innerHTML = "underrange";
   } else {
      var val = lemvac_data_in[5].toExponential(2);
      document.getElementById('TC_buffer_gauge_pressure').innerHTML = val + "mbar";
   }
   // piranni TC 
   if (lemvac_data_in.length === 0) {
      document.getElementById('TC_G1_high_pressure').innerHTML = "undef";         
   } else if (lemvac_data_in[6] <= 1.0e-4) {
      document.getElementById('TC_G1_high_pressure').innerHTML = "underrange";         
   } else {
      var val = lemvac_data_in[6].toExponential(2);
      document.getElementById('TC_G1_high_pressure').innerHTML = val + "mbar";         
   }
   // 1st penning TC
   if (lemvac_data_in.length === 0) {
      document.getElementById('TC_G1_low_pressure').innerHTML = "undef";
   } else if (lemvac_data_in[7] <= 1.0e-11) {
      if (lemvac_data_in[6] >= 1.0e-4) { // piranni above 1e-4 mbar
         document.getElementById('TC_G1_low_pressure').innerHTML = "off";
      } else {
         document.getElementById('TC_G1_low_pressure').innerHTML = "underrange";
      }         
   } else if (lemvac_data_in[7] > 1.0e-1) {
      document.getElementById('TC_G1_low_pressure').innerHTML = "off";
   } else {
      var val = lemvac_data_in[7].toExponential(2);
      document.getElementById('TC_G1_low_pressure').innerHTML = val + "mbar";
   }
   // 2nd penning TC 
   if (lemvac_data_in.length === 0) {
      document.getElementById('TC_G2_low_pressure').innerHTML = "undef";
   } else if (lemvac_data_in[8] <= 1.0e-11) {
      if (lemvac_data_in[6] >= 1.0e-4) { // piranni above 1e-4 mbar
         document.getElementById('TC_G2_low_pressure').innerHTML = "off";
      } else {
         document.getElementById('TC_G2_low_pressure').innerHTML = "underrange";
      }         
   } else if (lemvac_data_in[8] > 1.0e-1) {
      document.getElementById('TC_G2_low_pressure').innerHTML = "off";
   } else {
      var val = lemvac_data_in[8].toExponential(2);
      document.getElementById('TC_G2_low_pressure').innerHTML = val + "mbar";
   }

   // piranni underneath the SC turbo
   if (lemvac_data_in.length === 0) {
      document.getElementById('SC_buffer_gauge_pressure').innerHTML = "undef";
   } else if (lemvac_data_in[9] <= 1.0e-4) {
      document.getElementById('SC_buffer_gauge_pressure').innerHTML = "underrange";
   } else {
      var val = lemvac_data_in[9].toExponential(2);
      document.getElementById('SC_buffer_gauge_pressure').innerHTML = val + "mbar";
   }
   // piranni SC 
   if (lemvac_data_in.length === 0) {
      document.getElementById('SC_G1_high_pressure').innerHTML = "undef";         
   } else if (lemvac_data_in[10] <= 1.0e-4) {
      document.getElementById('SC_G1_high_pressure').innerHTML = "underrange";         
   } else {
      var val = lemvac_data_in[10].toExponential(2);
      document.getElementById('SC_G1_high_pressure').innerHTML = val + "mbar";         
   }
   // 1st penning SC
   if (lemvac_data_in.length === 0) {
      document.getElementById('SC_G1_low_pressure').innerHTML = "undef";
   } else if (lemvac_data_in[11] <= 1.0e-11) {
      if (lemvac_data_in[10] >= 1.0e-4) { // piranni above 1e-4 mbar
         document.getElementById('SC_G1_low_pressure').innerHTML = "off";
      } else {
         document.getElementById('SC_G1_low_pressure').innerHTML = "underrange";
      }         
   } else if (lemvac_data_in[11] > 1.0e-1) {
      document.getElementById('SC_G1_low_pressure').innerHTML = "off";
   } else {
      var val = lemvac_data_in[11].toExponential(2);
      document.getElementById('SC_G1_low_pressure').innerHTML = val + "mbar";
   }
   // 2nd penning TC 
   if (lemvac_data_in.length === 0) {
      document.getElementById('SC_G2_low_pressure').innerHTML = "undef";
   } else if (lemvac_data_in[12] <= 1.0e-11) {
      if (lemvac_data_in[10] >= 1.0e-4) { // piranni above 1e-4 mbar
         document.getElementById('SC_G2_low_pressure').innerHTML = "off";
      } else {
         document.getElementById('SC_G2_low_pressure').innerHTML = "underrange";
      }         
   } else if (lemvac_data_in[12] > 1.0e-1) {
      document.getElementById('SC_G2_low_pressure').innerHTML = "off";
   } else {
      var val = lemvac_data_in[12].toExponential(2);
      document.getElementById('SC_G2_low_pressure').innerHTML = val + "mbar";
   }
   
   // piranni party line
   if (lemvac_data_in.length === 0) {
      document.getElementById('C_buffer_gauge_pressure').innerHTML = "undef";         
   } else if (lemvac_data_in[13] <= 1.0e-4) {
      document.getElementById('C_buffer_gauge_pressure').innerHTML = "underrange";         
   } else {
      var val = lemvac_data_in[13].toExponential(2);
      document.getElementById('C_buffer_gauge_pressure').innerHTML = val + "mbar";         
   }
}     

function update_pressure_gauge_states() {
   if (lemvac_data_in.length === 0) { // no data yet
      return;
   }     
   
   // piranni underneath the MC turbo
   let val = lemvac_data_in[1];
   if (val <= 1.0e-4) {
      lemvac_gauge('MC_buffer_gauge', 3);
   } else if (val < 1.0e-2) {
      lemvac_gauge('MC_buffer_gauge', 2);
   } else if (val < 1.0) {
      lemvac_gauge('MC_buffer_gauge', 1);
   } else {
      lemvac_gauge('MC_buffer_gauge', 0);
   }
   
   // piranni/penning gauge state MC 
   val = lemvac_data_in[2];       
   if (val <= 1.0e-4) {
      lemvac_gauge('MC_G1', 3);
      lemvac_gauge('MC_G2', 3);
   } else {
      var gj  = lemvac_data_in[3];
      var gj2 = lemvac_data_in[4];
      if ((gj > 1.0e-11) && (gj < 1.0e-4) && (gj2 > 1.0e-11) && (gj2 < 1.0e-4)) {
         lemvac_gauge('MC_G1', 3);
         lemvac_gauge('MC_G2', 3);
      } else if (val < 1.0e-2) {
         lemvac_gauge('MC_G1', 2);
         lemvac_gauge('MC_G2', 2);
      } else if (val < 1.0) {
         lemvac_gauge('MC_G1', 1);
         lemvac_gauge('MC_G2', 1);
      } else {
         lemvac_gauge('MC_G1', 0);
         lemvac_gauge('MC_G2', 0);
      }
   }
   
   // piranni underneath the TC turbo
   val = lemvac_data_in[5];
   if (val <= 1.0e-4) {
      lemvac_gauge('TC_buffer_gauge', 3);
   } else if (val < 1.0e-2) {
      lemvac_gauge('TC_buffer_gauge', 2);
   } else if (val < 1.0) {
      lemvac_gauge('TC_buffer_gauge', 1);
   } else {
      lemvac_gauge('TC_buffer_gauge', 0);
   }

   // piranni/penning gauge state TC 
   val = lemvac_data_in[6];       
   if (val <= 1.0e-4) {
      lemvac_gauge('TC_G1', 3);
      lemvac_gauge('TC_G2', 3);
   } else {
      var gj  = lemvac_data_in[7];
      var gj2 = lemvac_data_in[8];
      if ((gj > 1.0e-11) && (gj < 1.0e-4) && (gj2 > 1.0e-11) && (gj2 < 1.0e-4)) {
         lemvac_gauge('TC_G1', 3);
         lemvac_gauge('TC_G2', 3);
      } else if (val < 1.0e-2) {
         lemvac_gauge('TC_G1', 2);
         lemvac_gauge('TC_G2', 2);
      } else if (val < 1.0) {
         lemvac_gauge('TC_G1', 1);
         lemvac_gauge('TC_G2', 1);
      } else {
         lemvac_gauge('TC_G1', 0);
         lemvac_gauge('TC_G2', 0);
      }
   }

   // piranni underneath the SC turbo
   val = lemvac_data_in[9];
   if (val <= 1.0e-4) {
      lemvac_gauge('SC_buffer_gauge', 3);
   } else if (val < 1.0e-2) {
      lemvac_gauge('SC_buffer_gauge', 2);
   } else if (val < 1.0) {
      lemvac_gauge('SC_buffer_gauge', 1);
   } else {
      lemvac_gauge('SC_buffer_gauge', 0);
   }

   // piranni/penning gauge state SC 
   val = lemvac_data_in[9];       
   if (val <= 1.0e-4) {
      lemvac_gauge('SC_G1', 3);
      lemvac_gauge('SC_G2', 3);
   } else {
      var gj  = lemvac_data_in[10];
      var gj2 = lemvac_data_in[11];
      if ((gj > 1.0e-11) && (gj < 1.0e-4) && (gj2 > 1.0e-11) && (gj2 < 1.0e-4)) {
         lemvac_gauge('SC_G1', 3);
         lemvac_gauge('SC_G2', 3);
      } else if (val < 1.0e-2) {
         lemvac_gauge('SC_G1', 2);
         lemvac_gauge('SC_G2', 2);
      } else if (val < 1.0) {
         lemvac_gauge('SC_G1', 1);
         lemvac_gauge('SC_G2', 1);
      } else {
         lemvac_gauge('SC_G1', 0);
         lemvac_gauge('SC_G2', 0);
      }
   }
   
   // piranni of the party line
   val = lemvac_data_in[13];
   if (val <= 1.0e-4) {
      lemvac_gauge('C_buffer_gauge', 3);
   } else if (val < 1.0e-2) {
      lemvac_gauge('C_buffer_gauge', 2);
   } else if (val < 1.0) {
      lemvac_gauge('C_buffer_gauge', 1);
   } else {
      lemvac_gauge('C_buffer_gauge', 0);
   }
   
}     

function update_valve_states() {
   if (lemvac_data_in.length === 0) { // no data yet
      return;
   }
   
   // BPVX
   let val = lemvac_data_in[25];
   if (val & LV_BIT3) { // valve closed
      lemvac_valve('BPVX', 1);
   } else if ((val & LV_BIT4) && (val & LV_BIT2)) { // open AND enabled
      lemvac_valve('BPVX', 0);
   } else if ((val & LV_BIT4) && !(val & LV_BIT2)) { // open AND NOT enabled
      lemvac_valve('BPVX', 3);
   } else {
      lemvac_valve('BPVX', 4);
   }
   
   // BPVY
   val = lemvac_data_in[26];
   if (val & LV_BIT3) { // valve closed
      lemvac_valve('BPVY', 1);
   } else if ((val & LV_BIT4) && (val & LV_BIT2)) { // open AND enabled
      lemvac_valve('BPVY', 0);
   } else if ((val & LV_BIT4) && !(val & LV_BIT2)) { // open AND NOT enabled
      lemvac_valve('BPVY', 3);
   } else {
      lemvac_valve('BPVY', 4);
   }
   
   // MC main valve
   val = lemvac_data_in[14];
   if ((!(val & LV_BIT5) && !(val & LV_BIT6)) ||
       ((val & LV_BIT5) && (val & LV_BIT6))) { // valve state uncertain
      lemvac_valve('MC_GV', 4);
   } else if (val & LV_BIT5) { // valve closed
      lemvac_valve('MC_GV', 1);
   } else if (val & LV_BIT6) { // valve open
      lemvac_valve('MC_GV', 0);
   } else if (val & LV_BIT4) { // valve locked
      lemvac_valve('MC_GV', 3);
   }

   // MC fore valve
   if ((!(val & LV_BIT7) && !(val & LV_BIT8)) || 
       ((val & LV_BIT7) && (val & LV_BIT8))) { // valve state uncertain
      lemvac_valve('MC_BFV', 4);
   } else if (val & LV_BIT7) { // valve closed
      lemvac_valve('MC_BFV', 1);
   } else if (val & LV_BIT8) { // valve open
      lemvac_valve('MC_BFV', 0);
   }

   // MC bypass valve
   if ((!(val & LV_BIT9) && !(val & LV_BIT10)) ||
       ((val & LV_BIT9) && (val & LV_BIT10))) { // valve state uncertain
      lemvac_valve('MC_BV', 4);
   } else if (val & LV_BIT9) { // valve closed
      lemvac_valve('MC_BV', 1);
   } else if (val & LV_BIT10) { // valve open
      lemvac_valve('MC_BV', 0);
   }
   
   // MC venting valve
   val = lemvac_data_in[15];
   if ((!(val & LV_BIT13) && !(val & LV_BIT14)) ||
       ((val & LV_BIT13) && (val & LV_BIT14))){ // valve state uncertain
      lemvac_valve('MC_VV', 4);
   } else if (val & LV_BIT13) { // valve closed
      lemvac_valve('MC_VV', 1);
   } else if (val & LV_BIT14) { // valve open
      lemvac_valve('MC_VV', 0);
   }

   // TC main valve
   val = lemvac_data_in[17];
   if ((!(val & LV_BIT5) && !(val & LV_BIT6)) ||
       ((val & LV_BIT5) && (val & LV_BIT6))) { // valve state uncertain
      lemvac_valve('TC_GV', 4);
   } else if (val & LV_BIT5) { // valve closed
      lemvac_valve('TC_GV', 1);
   } else if (val & LV_BIT6) { // valve open
      lemvac_valve('TC_GV', 0);
   } else if (val & LV_BIT4) { // valve locked
      lemvac_valve('TC_GV', 3);
   }

   // TC fore valve
   if ((!(val & LV_BIT7) && !(val & LV_BIT8)) ||
       ((val & LV_BIT7) && (val & LV_BIT8))) { // valve state uncertain
      lemvac_valve('TC_BFV', 4);
   } else if (val & LV_BIT7) { // valve closed
      lemvac_valve('TC_BFV', 1);
   } else if (val & LV_BIT8) { // valve open
      lemvac_valve('TC_BFV', 0);
   }

   // TC bypass valve
   if ((!(val & LV_BIT9) && !(val & LV_BIT10)) ||
       ((val & LV_BIT9) && (val & LV_BIT10))) { // valve state uncertain
      lemvac_valve('TC_BV', 4);
   } else if (val & LV_BIT9) { // valve closed
      lemvac_valve('TC_BV', 1);
   } else if (val & LV_BIT10) { // valve open
      lemvac_valve('TC_BV', 0);
   }

   // TC venting valve
   val = lemvac_data_in[18];
   if ((!(val & LV_BIT13) && !(val & LV_BIT14)) ||
       ((val & LV_BIT13) && (val & LV_BIT14))) { // valve state uncertain
      lemvac_valve('TC_VV', 4);
   } else if (val & LV_BIT13) { // valve closed
      lemvac_valve('TC_VV', 1);
   } else if (val & LV_BIT14) { // valve open
      lemvac_valve('TC_VV', 0);
   }

   // SC main valve
   val = lemvac_data_in[20];
   if ((!(val & LV_BIT5) && !(val & LV_BIT6)) ||
       ((val & LV_BIT5) && (val & LV_BIT6))) { // valve state uncertain
      lemvac_valve('SC_GV', 4);
   } else if (val & LV_BIT5) { // valve closed
      lemvac_valve('SC_GV', 1);
   } else if (val & LV_BIT6) { // valve open
      lemvac_valve('SC_GV', 0);
   } else if (val & LV_BIT4) { // valve locked
      lemvac_valve('SC_GV', 3);
   }
   
   // SC fore valve
   if ((!(val & LV_BIT7) && !(val & LV_BIT8)) ||
       ((val & LV_BIT7) && (val & LV_BIT8))) { // valve state uncertain
      lemvac_valve('SC_BFV', 4);
   } else if (val & LV_BIT7) { // valve closed
      lemvac_valve('SC_BFV', 1);
   } else if (val & LV_BIT8) { // valve open
      lemvac_valve('SC_BFV', 0);
   }

   // SC bypass valve
   if ((!(val & LV_BIT9) && !(val & LV_BIT10)) ||
       ((val & LV_BIT9) && (val & LV_BIT10))) { // valve state uncertain
      lemvac_valve('SC_BV', 4);
   } else if (val & LV_BIT9) { // valve closed
      lemvac_valve('SC_BV', 1);
   } else if (val & LV_BIT10) { // valve open
      lemvac_valve('SC_BV', 0);
   }
   
   // SC venting valve
   val = lemvac_data_in[21];
   if ((!(val & LV_BIT13) && !(val & LV_BIT14)) ||
       ((val & LV_BIT13) && (val & LV_BIT14))){ // valve state uncertain
      lemvac_valve('SC_VV', 4);
   } else if (val & LV_BIT13) { // valve closed
      lemvac_valve('SC_VV', 1);
   } else if (val & LV_BIT14) { // valve open
      lemvac_valve('SC_VV', 0);
   }

   // valve PZR1
   val = lemvac_data_in[23];
   if ((!(val & LV_BIT2) && !(val & LV_BIT3)) ||
       ((val & LV_BIT2) && (val & LV_BIT3))) { // valve state uncertain
      lemvac_valve('RP1V', 4);
   } else if (val & LV_BIT2) { // valve open
      lemvac_valve('RP1V', 0);
   } else if (val & LV_BIT3) { // valve closed
      lemvac_valve('RP1V', 1);
   }

   // valve PZR2
   if ((!(val & LV_BIT11) && !(val & LV_BIT12)) || 
       ((val & LV_BIT11) && (val & LV_BIT12))) { // valve state uncertain
      lemvac_valve('RP2V', 4);
   } else if (val & LV_BIT11) { // valve open
      lemvac_valve('RP2V', 0);
   } else if (val & LV_BIT12) { // valve closed
      lemvac_valve('RP2V', 1);
   }
}     

function update_pump_states() {
   if (lemvac_data_in.length === 0) { // no data yet
      return;
   }
   
   // MC turbo pump
   let val = lemvac_data_in[14];
   if ((val & LV_BIT0) && (val & LV_BIT3)) { // pump on and running > 80%        
      lemvac_turbo('mod_turbo', 0);
   } else if (val & LV_BIT1) { // pump off
      lemvac_turbo('mod_turbo', 1);
   } else if (val & LV_BIT2) { // pumping running high < 80%
      lemvac_turbo('mod_turbo', 3);
   } else if (!(val & LV_BIT2) && (val & LV_BIT0) && !(val & LV_BIT3)) {
      lemvac_turbo('mod_turbo', 4); // i.e. on, <80%, not running high      
   }
   if (val & LV_BIT0) { // MC pump station manually off
      // string to be placed, AS35 STILL MISSING
   } else if (val & LV_BIT3) { // MC TCP turbo controller error
      // string to be placed, AS35 STILL MISSING
   } else if (val & LV_BIT4) { // MC turbo pump error
      lemvac_turbo('mod_turbo', 2); // turbo pump error
   }

   // TC turbo pump
   val = lemvac_data_in[17];
   if ((val & LV_BIT0) && (val & LV_BIT3)) { // pump on and running > 80%        
      lemvac_turbo('trigger_turbo', 0);
   } else if (val & LV_BIT1) { // pump off
      lemvac_turbo('trigger_turbo', 1);
   } else if (val & LV_BIT2) { // pumping running high < 80%
      lemvac_turbo('trigger_turbo', 3);
   } else if (!(val & LV_BIT2) && (val & LV_BIT0) && !(val & LV_BIT3)) {
      lemvac_turbo('trigger_turbo', 4); // i.e. on, <80%, not running high      
   }
   if (val & LV_BIT0) { // TC pump station manually off
      // string to be placed, AS35 STILL MISSING
   } else if (val & LV_BIT3) { // TC TCP turbo controller error
      // string to be placed, AS35 STILL MISSING
   } else if (val & LV_BIT4) { // TC turbo pump error
      lemvac_turbo('trigger_turbo', 2); // turbo pump error
   }

   // SC turbo pump
   val = lemvac_data_in[20];
   if ((val & LV_BIT0) && (val & LV_BIT3)) { // pump on and running > 80%        
      lemvac_turbo('sample_turbo', 0);
   } else if (val & LV_BIT1) { // pump off
      lemvac_turbo('sample_turbo', 1);
   } else if (val & LV_BIT2) { // pumping running high < 80%
      lemvac_turbo('sample_turbo', 3);
   } else if (!(val & LV_BIT2) && (val & LV_BIT0) && !(val & LV_BIT3)) {
      lemvac_turbo('sample_turbo', 4); // i.e. on, <80%, not running high      
   }
   if (val & LV_BIT0) { // SC pump station manually off
      // string to be placed, AS35 STILL MISSING
   } else if (val & LV_BIT3) { // SC TCP turbo controller error
      // string to be placed, AS35 STILL MISSING
   } else if (val & LV_BIT4) { // SC turbo pump error
      lemvac_turbo('sample_turbo', 2); // turbo pump error
   }
   
   // rough pump 1
   val = lemvac_data_in[23];
   if (val & LV_BIT0) { // pump on
      lemvac_rough('rough_pump_1', 0);
   } else {
      lemvac_rough('rough_pump_1', 1);
   }
   // rough pump 2
   if (val & LV_BIT9) { // pump on
      lemvac_rough('rough_pump_2', 0);
   } else {
      lemvac_rough('rough_pump_2', 1);
   }       
}     

function lemvac_turbo(name, state) {
   let st = '#dfdf00';
   let fi = '#000000';
   let st_w = 2;
   // select the proper colors depending on the state
   switch (state) {
   case 0: // > 80%
      st = '#000000';
      fi = '#00af00';
      break;
   case 1: // off
      st = '#dfdf00';
      fi = '#000000';
      break;
   case 2: // error
      st = '#000000';
      fi = '#cf0000';
      break;  
   case 3: // < 80%
      st = '#000000';
      fi = '#f0d000';
      break;  
   case 4: // < running out
      st = '#000000';
      fi = '#00c8f0';
      break;  
   default:
      break;  
   }       
   let el = document.getElementsByClassName(name);
   for (let i=0; i<el.length; i++) {
      el[i].style.fill = fi;
      el[i].style.stroke = st;
      el[i].style.strokeWidth = st_w; // in px
   }
}

function lemvac_rough(name, state) {
   let st = '#dfdf00';
   let fi = '#000000';
   let st_w = 2;
   // select the proper colors depending on the state
   switch (state) {
   case 0: // on 
      st = '#000000';
      fi = '#00af00';
      break;  
   case 1: // off
      st = '#dfdf00';
      fi = '#000000';
      break;
   default:
      break;  
   }       
   let el = document.getElementsByClassName(name);
   for (let i=0; i<el.length; i++) {
      el[i].style.fill = fi;
      el[i].style.stroke = st;
      el[i].style.strokeWidth = st_w; // in px
   }
}

function lemvac_valve(name, state) {
   let st = '#000000';
   let fi = '#ef0000';
   let st_w = 2;
   // select the proper colors depending on the state
   switch (state) {
   case 0: // open 
      st = '#000000';
      fi = '#00af00';
      break;  
   case 1: // closed
      st = '#000000';
      fi = '#ef0000';
      break;
   case 2: // moving
      st = '#000000';
      fi = '#f0d000';
      break;
   case 3: // valve locked
      // AS35 object needs to be redrawn
      break;
   case 4: // valve state uncertain
      st = '#000000';
      fi = '#a000a0';
      break;
   case 5: // valve throttle position
      // AS35 object needs to be redrawn
      break;          
   default:
      break;  
   }       
   document.getElementById(name).style.fill = fi;
   document.getElementById(name).style.stroke = st;
   document.getElementById(name).style.strokeWidth = st_w;
}

function lemvac_gauge(name, state) {
   let st = '#000000';
   let fi = '#ef0000';
   let st_w = 2;
   // select the proper colors depending on the state
   switch (state) {
   case 0: // p > 1 mbar 
      st = '#000000';
      fi = '#ef0000';
      break;
   case 1: // p < 1 mbar
      st = '#000000';
      fi = '#f0d000';
      break;  
   case 2: // p < 1e-2 mbar
      st = '#000000';
      fi = '#00af00';
      break;  
   case 3: // p < 1e-4 mbar
      st = '#000000';
      fi = '#3030ff';
      break;  
   default:
      break;  
   }       
   document.getElementById(name).style.fill = fi;
   document.getElementById(name).style.stroke = st;
   document.getElementById(name).style.strokeWidth = st_w;
}

function bpv_toggle(valve) {
   if (valve == 0) { // BPVX
      if (lemvac_data_out[0] == 1) {
         if (confirm("Do you really want to toggle the BPVX state?")) { // yes
	    modbset("Equipment/LEMVAC/Variables/Output[1]", 1);
         }
      } 
   } else if (valve == 1) { // BPVY
      if (lemvac_data_out[2] == 1) {
         if (confirm("Do you really want to toggle the BPVY state?")) { // yes
	    modbset("Equipment/LEMVAC/Variables/Output[3]", 1);
         }
      } 
   }
}

function lemvac() {
   lemvac_turbo('mod_turbo', 0);
   lemvac_turbo('trigger_turbo', 0);
   lemvac_turbo('sample_turbo', 1);
   lemvac_rough('rough_pump_1', 1); 
   lemvac_rough('rough_pump_2', 0);
   lemvac_valve('BPVX', 1);
   lemvac_valve('BPVY', 0);
   lemvac_valve('MC_GV', 1); 
   lemvac_valve('MC_BV', 1); 
   lemvac_valve('MC_BFV', 1); 
   lemvac_valve('MC_VV', 1);
   lemvac_gauge('MC_G1', 3); 
   lemvac_gauge('MC_G2', 3); 
   lemvac_gauge('MC_buffer_gauge', 1); 
   lemvac_valve('TC_GV', 1); 
   lemvac_valve('TC_BV', 1); 
   lemvac_valve('TC_BFV', 1); 
   lemvac_valve('TC_VV', 1); 
   lemvac_gauge('TC_G1', 3); 
   lemvac_gauge('TC_G2', 3); 
   lemvac_gauge('TC_buffer_gauge', 1); 
   lemvac_valve('SC_GV', 1); 
   lemvac_valve('SC_BV', 1);
   lemvac_valve('SC_BFV', 1);
   lemvac_valve('SC_VV', 1); 
   lemvac_gauge('SC_G1', 3); 
   lemvac_gauge('SC_G2', 3); 
   lemvac_gauge('SC_buffer_gauge', 1); 
   lemvac_valve('RP1V', 1); 
   lemvac_valve('RP2V', 0); 
   lemvac_gauge('C_buffer_gauge', 1); 
}

// Functions for autorun editor

// Insert block into autorun
function insertLARBlock(element,editor) {
   let elId = element.id;
   let larEditor = (editor) ? editor : document.getElementById("larEditor");
   let enablePop = document.getElementById("enablePop").checked;
   let text;
   let html = "<br><br><table class='guitable' style='width:90%;'>";
   if (elId == "tempLoop") {
      // Sample temperature loop
      text = "LOOP_START\n";
      text += "  LOOP_LIST [tempValues]\n";
      text += "  LOOP_TEMP LOOP_ELEMENT, tempTol, tempTimeout, tempRate\n";
      text += "  TITLE titleVal\n";
      text += "  START stats\n";
      text += "LOOP_END\n";
      // Prompt for values
      html += "<tr><td colspan='2'>Temperature list (comma separated or from:step:to)</td></tr>";
      html += "<tr><td colspan='2'><input class='prompPar' value='300:50:10' style='width:90%;' id='tempValues'> K</td></tr>";
      html += "<tr><td>Tolerance: </td>";
      html += "<td><input class='prompPar' type='number' value='0.5' style='width:7em;' id='tempTol'> K</td></tr>";
      html += "<tr><td>Time Out: </td>";
      html += "<td><input class='prompPar' type='number' value='1200' style='width:7em;' id='tempTimeout'> sec</td></tr>";
      html += "<tr><td>Rate: </td>";
      html += "<td><input class='prompPar' type='number' style='width:7em;' id='tempRate'> K/min</td></tr>";
      html += "<tr><td>Title:</td></tr>";
      html += "<tr><td colspan='2'><input  size='70' class='prompPar' style='width:90%;' id='titleVal' rows='2' value='ODB_SAMPLE, T=ODB_TEMP K, E=ODB_ENERGY keV, B=ODB_FIELD, Tr/Sa=ODB_TRANSP/ODB_HV_SAMP kV, SR=ODB_SPIN_ROT' ></td></tr>";
      html += "<tr><td>Stats: </td>";
      html += "<td><input class='prompPar' type='number' value='3e6' step='1e6' style='width:7em;' id='stats'> Events</td></tr>";
   } else if (elId == "hvLoop") {
      // Sample HV loop
      text = "LOOP_START\n";
      text += "  LOOP_LIST [hvValues]\n";
      text += "  LOOP_SAMPLE_HV LOOP_ELEMENT\n";
      text += "  TITLE titleVal\n";
      text += "  START stats\n";
      text += "LOOP_END\n";
      // Prompt for values
      html += "<tr><td>Sample HV list (comma separated or from:step:to)</td></tr>";
      html += "<tr><td colspan='2'><input class='prompPar' value='10.8:-2:1.2' style='width:90%;' id='hvValues'> kV</td></tr>";
      html += "<tr><td>Title:</td></tr>";
      html += "<tr><td colspan='2'><input  size='70' class='prompPar' style='width:90%;' id='titleVal' rows='2' value='ODB_SAMPLE, T=ODB_TEMP K, E=ODB_ENERGY keV, B=ODB_FIELD, Tr/Sa=ODB_TRANSP/ODB_HV_SAMP kV, SR=ODB_SPIN_ROT' ></td></tr>";
      html += "<tr><td>Stats: </td>";
      html += "<td><input class='prompPar' type='number' value='3e6' style='width:7em;' id='stats'> Events</td></tr>";
   } else if (elId == "setTemp") {
      // Set temperature command
      text = "TEMP tempVal, tempTol, tempTimeout, tempRate\n";
      // Prompt for values
      html += "<tr><td>Temperature:</td>";
      html += "<td><input class='prompPar' type='number' value='100' style='width:7em;' id='tempVal'> K</td></tr>";
      html += "<tr><td>Tolerance: </td>";
      html += "<td><input class='prompPar' type='number' value='0.5' style='width:7em;' id='tempTol'> K</td></tr>";
      html += "<tr><td>Time Out: </td>";
      html += "<td><input class='prompPar' type='number' value='1200' style='width:7em;' id='tempTimeout'> sec</td></tr>";
      html += "<tr><td>Rate: </td>";
      html += "<td><input class='prompPar' type='number' style='width:7em;' id='tempRate'> K/min</td></tr>";
   } else if (elId == "setField") {
      // Set temperature command
      text = "FIELD fieldVal G\n";
      // Prompt for values
      html += "<tr><td>Field:</td>";
      html += "<td><input class='prompPar' type='number' value='100' style='width:7em;' id='fieldVal'> G</td></tr>";
   } else if (elId == "degMagnet") {
      // Set temperature command
      text = "DEGAUSS_MAGNET\n";
      // No need for pop
      enablePop = false;
   } else if (elId == "setSR") {
      // Set temperature command
      text = "SPIN_ROT srVal\n";
      // Prompt for values
      html += "<tr><td>SR Angle:</td>";
      html += "<td><input class='prompPar' type='number' value='-10' style='width:7em;' id='srVal'>&deg;</td></tr>";
   } else if (elId == "setSamHV") {
      // Set temperature command
      text = "SAMPLE_HV hvVal\n";
      // Prompt for values
      html += "<tr><td>Sample HV:</td>";
      html += "<td><input class='prompPar' type='number' value='1.0' style='width:7em;' id='hvVal'> kV</td></tr>";
   } else if (elId == "setRA") {
      // Set temperature command
      text = "RA_HV raLVal,raRVal,raTVal,raBVal\n";
      // Prompt for values
      html += "<tr><td>Left:</td>";
      html += "<td><input class='prompPar' type='number' value='11.3' style='width:7em;' id='raLVal'> kV</td></tr>";
      html += "<tr><td>Right:</td>";
      html += "<td><input class='prompPar' type='number' value='11.3' style='width:7em;' id='raRVal'> kV</td></tr>";
      html += "<tr><td>Top:</td>";
      html += "<td><input class='prompPar' type='number' value='11.3' style='width:7em;' id='raTVal'> kV</td></tr>";
      html += "<tr><td>Bottom:</td>";
      html += "<td><input class='prompPar' type='number' value='11.3' style='width:7em;' id='raBVal'> kV</td></tr>";
   } else if (elId == "setODB") {
      // Set temperature command
      text = "ODB_SET_DATA odbPath, odbVal\n";
      // Prompt for values
      html += "<tr><td>ODB Path:</td>";
      html += "<td><input class='prompPar' value='/Equipment/' id='odbPath'><input class='mbutton' type='button' value='Browse' onclick='odb_picker(\"/Equipment\",(flag,path) => {if (flag) {document.getElementById(\"odbPath\").value = path; console.log(path);}})' style='width:100px;'></td></tr>";
      html += "<tr><td>Set Value:</td>";
      html += "<td><input class='prompPar' style='width:7em;' id='odbVal'></td></tr>";
      html += "<tr><td colspan='2' id='odbBrowse'></td></tr>";
   } else if (elId == "warmupDate") {
      // Set temperature command
      text = "WARMUP dateVal, timeVal, vent\n";
      // Prompt for values
      html += "<tr><td>Date:</td>";
      html += "<td><input class='prompPar' type='date' style='width:90%;' id='dateVal' value='2021-06-20' required></td></tr>";
      html += "<tr><td>Time:</td>";
      html += "<td><input class='prompPar' type='time' step='1' value='07:30:00' style='width:90%;' id='timeVal' required></td></tr>";
      html += "<tr><td>Vent:</td>";
      html += "<td><input class='prompPar' type='checkbox' style='width:7em;' id='ventCheck' checked></td></tr>";
   } else if (elId == "trHV") {
      // Set temperature command
      text = "TRANSPORT_HV xml_filename\n";
      // Prompt for values
      html += "<tr><td>Transport filename:</td>";
      html += "<td><input class='prompPar' value='' id='xml_filename'><input class='mbutton' type='button' value='Browse' onclick='file_picker(\"hv_settings\",\"*.xml\",function(fn) {document.getElementById(\"xml_filename\").value=fn.replace(\"hv_settings/\",\"\");});' style='width:100px;'></td></tr>";
      html += "<tr><td colspan='2' id='xmlHVSel'></td></tr>";
   } else if (elId == "setTitle") {
      // Set temperature command
      text = "TITLE titleVal\n";
      text += "START stats\n";
      // Prompt for values
      html += "<tr><td>Title:</td></tr>";
      html += "<tr><td colspan='2'><input size='70' class='prompPar' value='ODB_SAMPLE, T=ODB_TEMP K, E=ODB_ENERGY keV, B=ODB_FIELD, Tr/Sa=ODB_TRANSP/ODB_HV_SAMP kV, SR=ODB_SPIN_ROT' style='width:90%;' id='titleVal'></td></tr>";
      html += "<tr><td>Stats: </td>";
      html += "<td><input class='prompPar' type='number' value='3e6' style='width:7em;' id='stats'> Events</td></tr>";
   }


   // Finish html block
   html += "</table><br><b>Block:</b><br><pre id='textBlock'>"+text+"</pre>";

   let sel, range, newNode;
   newNode = document.createElement("pre");
   newNode.id = "tmpID";
   // Cursor in editing
   larEditor.focus();
   if (document.getSelection) {
      sel = document.getSelection();
      // If anything is selected 
      if (sel.getRangeAt && sel.rangeCount) {
	 // Only if cursor is in larEditor
	 if (larEditor.contains(sel.getRangeAt(0).startContainer)) {
	    range = sel.getRangeAt(0);
	    range.deleteContents();
	    range.insertNode(newNode);
	 } else {
	    alert("Cursor must be in the editing area!");
	    return(0); 
	 }
      } else {
	 alert("Cursor must be in the editing area!");
	 return(0);
      }
   }
   
   if (enablePop) {
      let d = popModal("popPrompt");
      newNode.innerHTML = "<div id='preparing'>preparing ....</div>";
      document.getElementById("popHTML").innerHTML = html;
      document.getElementById("popButton").textContent = "Submit";
      document.getElementById("popButton").addEventListener("click",promptParams);
      document.getElementById("popButton").addEventListener("click",closeModal);
      document.getElementById("popButton").addEventListener("click",checkSyntax);

      const observer = new MutationObserver(() => {
	 let preparing = document.getElementById("preparing");
	 if (preparing) preparing.remove();
      });
      observer.observe(d, {attributes: true});
   } else {
      // Use defaults
      text = subLARDefaults(text);
      newNode.innerHTML = text;
      checkSyntax();
   }
} 

// Close pop modal cleanly
function closeModal()
{
   let caller =  document.getElementById("popPrompt");
   if (caller) caller.remove();
}

// This function populates a modal with a general html
function popModal(iddiv,x,y) {
   // First make sure you removed exisitng iddiv
   if (document.getElementById(iddiv)) document.getElementById(iddiv).remove();
   let d = document.createElement("div");
   d.className = "dlgFrame";
   d.id = iddiv;
   d.style.zIndex = "30";
   d.shouldDestroy = true;

   d.innerHTML = `
            <div class="dlgTitlebar">Mudas dialog</div>
            <div class="dlgPanel" style="padding: 3px;">
               <div style="width:fit-content;height:35em;overflow:scroll;text-align: left;" id="popHTML"></div>
               <button class="mbutton w3-display-bottomright" type="button" id="popButton"></button>
            </div>
         `;
   document.body.appendChild(d);
   dlgShow(d);

   if (x !== undefined && y !== undefined)
      dlgMove(d, x, y);

   return d;
}

// Thist function extracts values from popPrompt
function promptParams() {
   let parEls = document.getElementsByClassName("prompPar");
   let textBlock = document.getElementById("textBlock").innerText;
   let key,value;
   for (let i=0;i<parEls.length;i++) {
      key = parEls[i].id;
      value = parEls[i].value;
      // Special case from:step:to
      if ((key == "tempValues" || key == "hvValues") && value.includes(":")) {
	 let loopT = value.split(":");
	 let fromT =parseFloat(loopT[0]);
	 let stepT =parseFloat(loopT[1]);
	 let toT =parseFloat(loopT[2]);
	 if ((fromT > toT && stepT>0) || (fromT < toT && stepT<0)) {stepT = -1*stepT;}
	 value = fromT;
	 let currT = fromT;
	 while ((1+(currT-toT)/stepT) < 0) {
	    //console.log((currT-toT)/stepT);
	    currT = Math.round((currT + stepT)*100)/100;
	    value += ", "+currT;
	 }
      }
      // Special case tempRate is empty or zero
      //console.log(key,value);
      if (key == "tempRate" && (isNaN(value) || value == 0 )) {
	 key = ", tempRate";
	 value = "";
      } else if (key == "ventCheck" && !parEls[i].checked) {
	 key = ", vent";
	 value ="";
      }

      textBlock = textBlock.replace(key,value);
   }
   let tmpID = document.getElementById("tmpID");
   tmpID.innerHTML = textBlock;
   tmpID.removeAttribute('id');
}

// This function substitutes defaults in lar blocks
function subLARDefaults(text) {
   let defaults = {tempValues : "290,200,100,50,20,10,5" ,
                   tempVal : "100" , 
		   tempTol : "0.5" , 
		   tempTimeout : "1200", 
		   ", tempRate" : "", 
		   stats : "3e6", 
		   hvValues : "10, 9, 8",
		   fieldVal : "100", 
		   srVal : "-10" , 
		   hvVal : "5",
		   raLVal : "0" ,
		   raRVal : "0" ,
		   raTVal : "0" ,
		   raBVal : "0" ,
		   titleVal : "ODB_SAMPLE, T=ODB_TEMP K, E=ODB_ENERGY keV, B=ODB_FIELD, Tr/Sa=ODB_TRANSP/ODB_HV_SAMP kV, SR=ODB_SPIN_ROT",
		   dateVal : "2019-09-11:",
		   timeVal : "07:30:00",
		   odbPath : "/Equipment/", 
		   odbVal : "??"};

   for (let key in defaults) {
      let reg = new RegExp(key);
      text = text.replace(key,defaults[key]);
   }
   return text;
}


// Function to detect key press in editor area
function keyPressEditor(event,element) {
   let keyCode = ('which' in event) ? event.which : event.keyCode;
   // console.log(keyCode);
   // Space = 32, Enter = 13, Esc = 27, Tab=9
   if (keyCode === 9 ) {
      return 1;
   } else {
      return 0;
   }
}

function getCaretIndex(element) {
   let position = 0;
   const isSupported = typeof window.getSelection !== "undefined";
   if (isSupported) {
      const selection = window.getSelection();
      if (selection.rangeCount !== 0) {
         const range = window.getSelection().getRangeAt(0);
         const preCaretRange = range.cloneRange();
         preCaretRange.selectNodeContents(element);
         preCaretRange.setEnd(range.endContainer, range.endOffset);
         position = preCaretRange.toString().length;
      }
   }
   return position;
}

// Move caret to a specific point in a DOM element
function setCaretPosition(element, pos) {
   // Loop through all children nodes
   for (var node of element.childNodes) {
      if (node.nodeType == 3) { // we have a text node
         if (node.length >= pos) {
            // finally add our range
            var range = document.createRange();
            var sel = window.getSelection();
            range.setStart(node,pos);
            range.collapse(true);
            sel.removeAllRanges();
            sel.addRange(range);
            return -1; // we are done
         } else {
            pos -= node.length;
         }
      } else {
         pos = setCaretPosition(node,pos);
         if (pos == -1) {
            return -1; // no need to finish the for loop
         }
      }
   }
   return pos; // needed because of recursion stuff
}

function checkSyntaxEvent() {
   let larEditor = document.getElementById("larEditor");
   if (larEditor === null) return;
   // Add even listener to editor area
   document.getElementById('larEditor').addEventListener('keydown', (event) => {
      if (event.key === ' ' || event.key === 'Enter' || event.key === ',') {
	 checkSyntax();
      }
   });
}


function checkSyntax() {
   let larEditor = document.getElementById("larEditor");
   larEditor.focus();
   let line = larEditor.innerText.substr(larEditor.selectionStart).split("\n");
   let sel = document.getSelection();
   let range = sel.getRangeAt(0);
   let pos = range.startOffset;
   let posNode = range.startContainer;
   let caretPos = getCaretIndex(larEditor);

   let text = larEditor.innerText;
   if (instrName == "LEM") {
      text = syntax_lar(text.split("\n"));
      text = text.join("<br>");
   } else if (instrName == "LEYLA") {
      text = syntax_msl(text.split("\n"));
      text = text.join("<br>");
   } else {
      text = syntaxSeq(text).replaceAll(/\d+:\s+/g,"");
      text = text.replaceAll(/\n/g,"<br>")
   }
   larEditor.innerHTML = text;
   range=document.createRange();  
   sel.removeAllRanges(); 
   range.selectNodeContents(larEditor);
   range.collapse(false);  
   sel.addRange(range);
   larEditor.focus();
   setCaretPosition(larEditor,caretPos);
}

function clearScript() {
   // get LAR text
   let larEditor = document.getElementById("larEditor");
   if (confirm("Do you want to clear the sequence?")) {
      larEditor.innerHTML = "";
   }
}

// Function to load and ascii file 
// async read, be careful with use
function loadAscii(file,flag){
   var xhttp,content;
   if (file == "" || file == undefined || file == null) {
      return 0;
   } else {
      // Make an HTTP request using the attribute value as the file name:
      xhttp = new XMLHttpRequest();
      xhttp.onreadystatechange = function() {
         if (this.readyState == 4) {
            if (this.status == 404) {
               console.log("File "+file+" not found.");
            }
         }
      }
      file += flag ? "" : "?" + Date();
      xhttp.open("GET", file, false);
      xhttp.send();
      return(xhttp.responseText);
   }
}


// Function to load file from client - Not used in Mudas
function loadScriptLocal(event) {
   let input = event.target;
   let reader = new FileReader();
   let larEditor = document.getElementById("larEditor");

   reader.onload = function(){
      var text = reader.result;
      larEditor.innerHTML = text;
      checkSyntax();
   };
   reader.readAsText(input.files[0]);
}


// Save autorun for modern midas
function saveAutoRun(filename) {
   // Flag for "Load as autorun" and "Set as next autorun"
   let fn2autorun = false;
   let fn2next = false;
   if (document.getElementById("fn2autorun")) {fn2autorun = document.getElementById("fn2autorun").checked;}
   if (document.getElementById("fn2next")) {fn2next = document.getElementById("fn2next").checked;}
   let larEditor = document.getElementById("larEditor");
   let script = larEditor.innerText;
   let fileext = filename.slice(-4);
   // Check if filename is empty or does not have .lar extension 
   if (filename == "") {
      alert("Illegal empty file name! Please provide a file name.");
      return;
   } else if  (!(fileext == ".lar" || fileext == ".seq")) {
      alert("Illegal file name extension '"+fileext+"'! Please try again.");
      return;
   }
   
   file_save_ascii(filename, script, function() {
      if (fn2autorun & larState == 0) {
         // Load sequence
         setCurrentLAR(filename);
      } else if (fn2next) {
         setNextLAR(filename);
      }
      document.getElementById("editFileName").innerText = filename.replace("autoRun/","");
   });
   return filename;
}

// Save file to server, possible only in sequencer odbpath
function saveScript() {
   file_picker("autoRun","*.lar",saveAutoRun,true);
   let fContainer = document.getElementById("fContainer");
   fContainer.style.textAlign = "left";

   // Append radio what to do next to fContainer
   const fn2autorun = document.createElement('input');
   fn2autorun.type = 'radio';
   fn2autorun.name = "fn2wha";
   fn2autorun.id = 'fn2autorun';
   const lblfn2autorun = document.createElement('label');
   lblfn2autorun.htmlFor = 'fn2autorun';
   lblfn2autorun.appendChild(document.createTextNode(' Load as autorun'));

   const fn2next = document.createElement('input');
   fn2next.type = 'radio';
   fn2next.name = "fn2wha";
   fn2next.id = 'fn2next';
   const lblfn2next = document.createElement('label');
   lblfn2next.htmlFor = 'fn2next';
   lblfn2next.appendChild(document.createTextNode(' Set as next autorun'));

   const fn2not = document.createElement('input');
   fn2not.type = 'radio';
   fn2not.name = "fn2wha";
   fn2not.id = 'fn2not';
   const lblfn2not = document.createElement('label');
   lblfn2not.htmlFor = 'fn2bot';
   lblfn2not.appendChild(document.createTextNode(' Do nothing'));

   fContainer.appendChild(document.createElement('br'));
   fContainer.appendChild(fn2autorun);
   fContainer.appendChild(lblfn2autorun);
   fContainer.appendChild(document.createElement('br'));
   fContainer.appendChild(fn2next);
   fContainer.appendChild(lblfn2next);
   fContainer.appendChild(document.createElement('br'));
   fContainer.appendChild(fn2not);
   fContainer.appendChild(lblfn2not);
}


// Callback function to load a selected script from LAR Editor
function loadScript(filename) {
   file_load_ascii(filename,function(content) {
      let larEditor = document.getElementById("larEditor");
      larEditor.innerHTML = content;
      checkSyntax();
      document.getElementById("editFileName").innerText = filename.replace("autoRun/","");
   });
}

// Callback function to set selected sequence and load it
function setCurrentLAR(fileName) {
   if (!fileName) {
      fileName = document.getElementById("fileSelect").value;
   } else {
      fileName = fileName.replace("autoRun/","");
   }
   if (document.getElementById("popPrompt")) document.getElementById("popPrompt").remove();
   if (instrName == "LEM") { 
      modbset("/AutoRun/Auto Run Sequence",fileName);
      // Load sequence
      setLARstate(4)
   } else if (instrName == "LEYLA") {
      modbset("/Sequencer/Command/Load filename",fileName);
      modbset("/Sequencer/Command/Load new file",true);
   } else {
      // Bulk macines
      modbset('/Autorun/Cmd/Atransition',1);
      modbset("/AutoRun/File/File",fileName);
      updateSeq(fileName);
   }
}

// Callback function to set selected next sequence
function setNextLAR(fileName) {
   if (!fileName) {
      fileName = document.getElementById("fileSelect").value;
   } else {
      fileName = fileName.replace("autoRun/","");
   }
   if (instrName == "LEM") {
      modbset("/AutoRun/Next",fileName);
   } else {
      // Bulk macines
      modbset('/Autorun/Cmd/Atransition',1);
      modbset("/Autorun/Cmd/Next",fileName);
   }
   if (document.getElementById("popPrompt")) document.getElementById("popPrompt").remove();
}

var mjsonvalue;
function test() {
   //    console.log("I am in test");
   //mjsonvalue = modbget("/Info/Sample Cryo");
   //console.log("value=",mjsonvalue);
   //eqList();
   //console.log(eqListArray);
   mjsonrpc_db_get_values(["/Equipment"]).then(function(rpc){
      //let eqListArray = Object.keys(rpc.result.data[0])
      //console.log(eqListArray);
      let result = rpc.result.data[0];
      console.log(result)
      /*for (let key in result) {
        console.log(key);
        }*/
   });
}

var eqListArray = [];
function eqList() {
   let eqTable = "";
   // Get equipment list in array
   
   mjsonrpc_db_ls(["/Equipment"]).then(function (rpc) {
      eqListArray = Object.keys(rpc.result.data[0]);
      //console.log("Eq = ",eqListArray);
      for (let i=0; i < eqListArray.length; i++) {
         //console.log("Eq = ",eqListArray[i]);
         eqTable += "<tr><td onclick='eqTable_dialog(\"" + eqListArray[i] + "\")'>" + eqListArray[i] + "</td>";
         eqTable += "<td><input type='checkbox' id='test' onclick='eqEnable(this)'></td>";
         eqTable += "<td>test</td></tr>";
      }
      document.getElementById("eqTable").innerHTML = eqTable;
      return eqListArray;
   }).catch(function (error) {console.error(error);});
}

function eqTable_dialog(equipment, width = 600, height = 350, x, y) {
   if (equipment === undefined)
      return;

   const d = document.createElement("div");
   d.className = "dlgFrame";
   d.id = "dlg" + equipment;
   d.style.zIndex = "30";
   // allow resizing modal
   d.style.overflow = "hidden";
   d.style.resize = "both";
   d.style.minWidth = width + "px";
   d.style.minHeight = height + "px";
   d.style.width = width + "px";
   d.style.height = height + "px";
   d.shouldDestroy = true;

   const dlgTitle = document.createElement("div");
   dlgTitle.className = "dlgTitlebar";
   dlgTitle.id = "dlgMessageTitle";
   dlgTitle.innerText = "Equipment dialog";
   d.appendChild(dlgTitle);

   const dlgPanel = document.createElement("div");
   dlgPanel.className = "dlgPanel";
   dlgPanel.id = "dlgPanel";
   d.appendChild(dlgPanel);

   const divTable = document.createElement("div");
   divTable.style.overflow = "auto";
   const eqTable = document.createElement("table");
   eqTable.className = "mtable dialogTable";
   eqTable.id = "eqTable_" + equipment;
   eqTable.style.border = "none";
   eqTable.style.width = "100%";
   eqTable.style.overflow = "auto";
   
   const colTitles = eqTable.createTHead();
   colTitles.innerHTML = `
     <tr>
       <th id='nameSort' onclick='//check_sorting(this);'>Name
         <img id='nameArrow' style='float:right;visibility:hidden;' src='/icons/chevron-up.svg'>
       </th>
       <th id='valSort' onclick='//check_sorting(this);'>Modified
         <img id='timeArrow' style='float:right;' src='/icons/chevron-down.svg'>
       </th>
       <th id='rbSort' onclick='//check_sorting(this);'>Size
         <img id='sizeArrow' style='float:right;visibility:hidden;' src='/icons/chevron-down.svg'>
       </th>
     </tr>`;
   eqTable.appendChild(document.createElement("tbody"));
   divTable.appendChild(eqTable);
   dlgPanel.appendChild(divTable);
   mkEquipmentTable(equipment,-1,-1,eqTable.id);
   const fContainer = document.createElement("div");
   fContainer.id = "fContainer";
   fContainer.style.width = "100%";
   fContainer.style.paddingTop = "5px";
   fContainer.style.paddingBottom = "3px";
   dlgPanel.appendChild(fContainer);
   const btnContainer = document.createElement("div");
   btnContainer.id = "btnContainer";
   btnContainer.style.paddingBottom = "3px";
   dlgPanel.appendChild(btnContainer);

   /*
     const dlgButton = document.createElement("button");
     dlgButton.className = "dlgButtonDefault";
     dlgButton.id = "dlgButton";
     dlgButton.type = "button";
     btnContainer.appendChild(dlgButton);
   */
   const dlgCancelBtn = document.createElement("button");
   dlgCancelBtn.className = "dlgButtonDefault";
   dlgCancelBtn.id = "dlgCancelBtn";
   dlgCancelBtn.type = "button";
   dlgCancelBtn.textContent = "Cancel";
   dlgCancelBtn.addEventListener("click", function () {
      document.removeEventListener("keydown", tableClickHandler);
      d.remove();
   });
   btnContainer.appendChild(dlgCancelBtn);

   document.body.appendChild(d);
   dlgShow(d);

   if (x !== undefined && y !== undefined)
      dlgMove(d, x, y);

   // adjust select size when resizing modal
   const resizeObs = new ResizeObserver(() => {
      divTable.style.height = (d.offsetHeight - dlgTitle.offsetHeight - fContainer.offsetHeight - btnContainer.offsetHeight - 5 ) + "px";
   });
   resizeObs.observe(d);

   // Add key navigation
   document.addEventListener("keydown", tableClickHandler);

   return d;

}

/* The following functions are modifications of midas functions that will 
   most probably never make it to the main development branch */

function drawCloseButton(c, mark) {
   if (!c.getContext)
      return;
   let ctx = c.getContext("2d");
   ctx.clearRect(0, 0, c.width, c.height);
   ctx.lineWidth = 0.5;
   ctx.beginPath();
   ctx.arc(c.width/2, c.height/2, c.width/2-1, 0, 2*Math.PI);
   ctx.fillStyle = 'white';
   ctx.fill();
   ctx.strokeStyle = 'gray';
   ctx.stroke();
   if (mark) {
      ctx.beginPath();	
      ctx.arc(c.width/2, c.height/2, c.width/2, 0, 2*Math.PI);
      ctx.fillStyle = '#FD5E59';
      ctx.fill();
   }
   ctx.strokeStyle = '#000000';
   ctx.beginPath();
   ctx.lineWidth = 1;
   ctx.moveTo(c.width/2-3, c.height/2-3);
   ctx.lineTo(c.width/2+3, c.height/2+3);
   ctx.moveTo(c.width/2+3, c.height/2-3);
   ctx.lineTo(c.width/2-3, c.height/2+3);
   ctx.stroke();
}
