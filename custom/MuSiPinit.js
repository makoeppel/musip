// Must be loaded before Mudas.js

// This part to be changed depending on instrument
var instrName     = "MuSiP";
var instrColor    = "#FF0000";
var elogLink      = "https://lem03.psi.ch:8000/Si-Pixel/";
var autoRunPath   = "/home/mu3e/debug_online/online/userfiles/sequencer";

// Make a Map for instrument specific ODBs
var instrODB = {
    runStatus:     "/Runinfo/State",
    runTitle:      "/Info/Run Title",
    runNumber:     "/Runinfo/Run number",
    autorunStatus: "/Sequencer/State/Running",
    startTime:     "/Runinfo/Start time",
    stopTime:      "/Runinfo/Stop time",
    eventRate:     "/Equipment/SwitchingLabor/Variables/SCCN[41]",
    protonCurr:    "/Equipment/Scaler/Variables/RATE/Ip",
    totalStats:    "/Equipment/PixelsLabor/Statistics/Events sent",
    sampleName:    "/Info/Sample Name",
    // This depends on the used equipment
    sampleTemp:    "/Equipment/SampleCryo/Variables/Input[1]",
    //magField:      "/Equipment/Danfysik_PABA_Magnet/Variables/Input[",
    impEnergy:     "/Info/Implantation Energy (keV)",
    pID:           "/Info/File_Header_Info/Proposal Number",
    pPI:           "/Info/File_Header_Info/Main Proposer",
    pGRP:          "/Info/File_Header_Info/P-Group",
}
// This is the tab ordering
// Buttons go in tabBtns and html goes into tabFrames
var instrTabs = {
    runControl : {
	order   : 1,              // or according to order    
	label   : "Run Control",  // Label of the tab
	addFunc : "mhistory_init();",             // preferably always empty
	htmlFile: "RunControl_tab.html", // HTML file name for the tab
	style   : "Tab",          // Tab or Menu
    },
    autoRun : {
	order   : 2,              
	label   : "Sequencer",  
	addFunc : "",
	htmlFile: "Sequencer_tab.html", 
	style   : "Tab",          
    },
    Vacuum : {
	order   : 3,              
	label   : "Vacuum",  
	addFunc : "",
	htmlFile: "Vacuum_tab.html", 
	style   : "Tab",          
    },
}

// End of changeable part


