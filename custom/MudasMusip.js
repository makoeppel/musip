
var pump_data_in = new Array();
var pump_data_out = new Array();
var pump_fe_state = -1;

// Function to run onload to setup needed options and update period of GUI
// Called periodically
function Mudas_init() {
   // Check alarms
   triggerAlarms();

   // Vacuum update
   update_vacuum('Pump');
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

function Mudas_init_once() {
    // Sequence state
    seqState();
    load_msl();
    seqState(updateBtns);

    // update run state
    runStatus(-2);
    mhistory_init();
//    console.log("calling it...");
//    mhistory_init_one('KentaxHist');
}

function update_vacuum(pumpStation,num) {
    // pumpStation is the name of the FE in equipment
   if (pumpStation == null) {pumpStation = "Pump";}
   if (num === undefined || num === null || num === 0) num = '';
   
   clearTimeout(updateTimerId);
   load_vacuum(pumpStation,num);
   if (updatePeriod > 0) {
      if (updatePeriod == 500) {
         startupCount++;
         if (startupCount > 2)
	    updatePeriod = 3000;
      }
      updateTimerId = setTimeout('update_vacuum("'+pumpStation+'","'+num+'")', updatePeriod);
   }
}

function load_vacuum(pumpStation,num) {
   if (num === undefined || num === null || num === 0) num = '';
   // get input/output data from ODB
   mjsonrpc_db_get_values(["/Equipment/"+pumpStation+"/Variables/Input","/Equipment/"+pumpStation+"/Variables/Output"]).then(function(rpc) {
      pump_data_in = rpc.result.data[0];
      pump_data_out = rpc.result.data[1];
   }).catch (function (error) {
      mjsonrpc_error_alert(error);
   });                   
   
   // get state of the frontend 
   mjsonrpc_call("cm_exist", "{ \"name\": \"PUMP_SC\" }").then(function(rpc) {
      pump_fe_state = rpc.result.status;
   }).catch (function(error) {
      mjsonrpc_error_alert(error);
   });
   
   pump(num);       
   update_pressure_gauge_states(num);
   update_valve_states(num);
   update_pump_states(num);
}

function update_pressure_gauge_states(num) {
   if (pump_data_in.length === 0) { // no data yet
      return;
   }
   if (num === undefined || num === null || num === 0) num = '';
    // Gti
       var val = pump_data_in[2];
    if (val <= 1.0e-4) {
        pump_gauge('gti_gauge' + num, 3);
    } else if (val < 1.0e-2) {
        pump_gauge('gti_gauge' + num, 2);
    } else if (val < 1.0) {
        pump_gauge('gti_gauge' + num, 1);
    } else {
        pump_gauge('gti_gauge' + num, 0);
    }
    
    // GP
    val = pump_data_in[1];
    if (val <= 1.0e-4) {
        pump_gauge('gp_gauge' + num, 3);
    } else if (val < 1.0e-2) {
        pump_gauge('gp_gauge' + num, 2);
    } else if (val < 1.0) {
        pump_gauge('gp_gauge' + num, 1);
    } else {
        pump_gauge('gp_gauge' + num, 0);
    }
    
}     

function update_valve_states(num) {
    if (pump_data_in.length === 0) { // no data yet
        return;
    }       
   if (num === undefined || num === null || num === 0) num = '';
    // gate valve
    val = pump_data_in[4];
    if (!(val & 0x40) && (val & 0x80)) { // valve open
        pump_valve('gate_valve' + num, 0);
    } else if ((val & 0x40) && !(val & 0x80)) { // valve closed
        pump_valve('gate_valve' + num, 1);
    } else if (val & 0x20) { // valve locked
        pump_valve('gate_valve' + num, 3);
    } else { // valve uncertain
        pump_valve('gate_valve' + num, 4);
    }
    
    // buffer valve
    val = pump_data_in[5];
    if (!(val & 0x01) && (val & 0x02)) { // valve open
        pump_valve('buffer_valve' + num, 0);
    } else if ((val & 0x01) && !(val & 0x02)) { // valve closed
        pump_valve('buffer_valve' + num, 1);
    } else { // valve uncertain
        pump_valve('buffer_valve' + num, 4);
    }
    
    // bypass valve
    if (!(val & 0x04) && (val & 0x08)) { // valve open
        pump_valve('bypass_valve' + num, 0);
    } else if ((val & 0x04) && !(val & 0x08)) { // valve closed
        pump_valve('bypass_valve' + num, 1);
    } else { // valve uncertain
        pump_valve('bypass_valve' + num, 4);
    }       
}     

function update_pump_states(num) {
    if (pump_data_in.length === 0) { // no data yet
        return;
    }
   if (num === undefined || num === null || num === 0) num = '';
   // turbo pump

   var val = pump_data_in[4];
   if ((val & 0x02) && (val & 0x10)) { // pump on and running > 80%        
      turbo_pump('turbo_pump' + num, 0);
   } else if (val & 0x04) { // pump off
      turbo_pump('turbo_pump' + num, 1);
   } else if (val & 0x08) { // pumping running high < 80%
      turbo_pump('turbo_pump' + num, 3);
   } else if (!(val & 0x08) && (val & 0x02) && !(val & 0x10)) {
      turbo_pump('turbo_pump' + num, 4); // i.e. on, <80%, not running high      
   } else if (!(val & 0x01)) { // pump station manually off
      // string to be placed, AS35 STILL MISSING
   }
   
   val = pump_data_in[7];
   if ((val & 0x08) || (val & 0x10)) { // TCP turbo controller error or timeout
      // string to be placed, AS35 STILL MISSING
      turbo_pump('turbo_pump' + num, 2); // turbo pump error
   }
   
   // rough pump 
   val = pump_data_in[5];
   if ((val & 0x40) && !(val & 0x80))  { // pump on
      rough_pump('rough_pump' + num, 0);
   } else if (!(val & 0x40) && (val & 0x80))  { // pump off
      rough_pump('rough_pump' + num, 1);
   } else {
      // AS35 pump error - STILL MISSING
   }
}     

function turbo_pump(name, state) {
    var st = '#dfdf00';
    var fi = '#000000';
    var st_w = 2;
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
    var el = document.getElementsByClassName(name);
    for (var i=0; i<el.length; i++) {
        el[i].style.fill = fi;
        el[i].style.stroke = st;
        el[i].style.strokeWidth = st_w; // in px
    }
}

function rough_pump(name, state) {
    var st = '#dfdf00';
    var fi = '#000000';
    var st_w = 2;
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
    var el = document.getElementsByClassName(name);
    for (var i=0; i<el.length; i++) {
        el[i].style.fill = fi;
        el[i].style.stroke = st;
        el[i].style.strokeWidth = st_w; // in px
    }
}

function pump_valve(name, state) {
    var st = '#000000';
    var fi = '#ef0000';
    var st_w = 2;
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
        // AS35 object needs to be redrawn
        break;
    case 5: // valve throttle position
        // AS35 object needs to be redrawn
        break;          
    default:
        break;  
    }
   if (document.getElementById(name)) {
      document.getElementById(name).style.fill = fi;
      document.getElementById(name).style.stroke = st;
      document.getElementById(name).style.strokeWidth = st_w;
   }
}

function pump_gauge(name, state) {
    var st = '#000000';
    var fi = '#ef0000';
    var st_w = 2;
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
   if (document.getElementById(name)) {
      document.getElementById(name).style.fill = fi;
      document.getElementById(name).style.stroke = st;
      document.getElementById(name).style.strokeWidth = st_w;
   }
}

function pump(num) {
    //document.getElementById('pump_counter').innerHTML = pump_data_in[0];
    
   if (num === undefined || num === null || num === 0) num = '';
    turbo_pump('turbo_pump' + num, 0);
    rough_pump('rough_pump' + num, 1); 
    
    pump_valve('gate_valve' + num, 1); 
    pump_valve('bypass_valve' + num, 1);
    pump_valve('buffer_valve' + num, 1); 
    
    pump_gauge('gti_gauge' + num, 3); 
    pump_gauge('gp_gauge' + num, 3); 
}


