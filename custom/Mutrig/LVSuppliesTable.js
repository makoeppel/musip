// Dynamically build LV supply table rows from LV_devices provided by TimingScint_config.js
function init_LVTable(config_url){
    function makeRow(device, index) {
        function makeCell(html) { var td = document.createElement('td'); td.innerHTML = html; return td; }

        var tr = document.createElement('tr');
        // Device name & Channel number
        tr.appendChild(makeCell('' + device + ''));
        tr.appendChild(makeCell('' + index + ''));

        var statePath = '/Equipment/' + device + '/Variables/State[' + index + ']';
        var setStatePath = '/Equipment/' + device + '/Variables/Set State[' + index + ']';
        var demandVPath = '/Equipment/' + device + '/Variables/Demand Voltage[' + index + ']';
        var voltagePath = '/Equipment/' + device + '/Variables/Voltage[' + index + ']';
        var currentLimitPath = '/Equipment/' + device + '/Variables/Current Limit[' + index + ']';
        var currentPath = '/Equipment/' + device + '/Variables/Current[' + index + ']';
        var descPath = '/Equipment/' + device + '/Settings/Channel Names[' + index + ']';

        // State color box
        tr.appendChild(makeCell('<div class="modbbox" style="width: 20px; height: 20px;" data-odb-path="' + statePath + '" data-color="lightgreen" data-background-color="red"></div>'));

        // Set state checkbox
        tr.appendChild(makeCell('<input type="checkbox" class="modbcheckbox" data-odb-path="' + setStatePath + '">'));

        // Demand Voltage
        tr.appendChild(makeCell('<div class="modbvalue" data-format="f2" data-odb-path="' + demandVPath + '" data-odb-editable="1"></div>'));

        // Voltage
        tr.appendChild(makeCell('<div class="modbvalue" data-format="f2" data-odb-path="' + voltagePath + '"></div>'));

        // Current Limit
        tr.appendChild(makeCell('<div class="modbvalue" data-format="f3" data-odb-path="' + currentLimitPath + '" data-odb-editable="1"></div>'));

        // Current
        tr.appendChild(makeCell('<div class="modbvalue" data-format="f3" data-odb-path="' + currentPath + '"></div>'));

        // Description
        tr.appendChild(makeCell('<div class="modbvalue" data-format="f3" data-odb-path="' + descPath + '" data-odb-editable="1"></div>'));

        return tr;
    }

    var LV_devices = []; // device list (loaded from JSON)

    function buildTable() {
        console.log('Building LV supply table from LV_devices');
        var body = document.getElementById('LVsupplies-body');
        if (!body) return;
        // Clear existing
        body.innerHTML = '';
        if (!window.LV_devices || !Array.isArray(window.LV_devices)) return;

        window.LV_devices.forEach(function(dev){
            //console.log('Processing device:', dev);
            body.appendChild(makeRow(dev.device, dev.channel));
        });
    }

    // Load mapping JSON (same-directory relative path)
    function loadConfig(url){
      fetch(url, {cache: 'no-cache'}).then(function(resp){
        if (!resp.ok) throw new Error('Failed to load mapping');
        return resp.json();
      }).then(function(json){
        // Populate LV_devices from JSON LV field
        try {
          var LV = json && json.LV ? json.LV : [];
          window.LV_devices = [];
          LV.forEach(function(entry){
            // Expect entry: { device: <name>, channel: <value> }
            if (!entry || typeof entry !== 'object') return;
            var device = entry.device !== undefined ? entry.device : null;
            var indices = entry.indices !== undefined ? entry.indices : null;

            indices.forEach(function(c){
              window.LV_devices.push({ device: device, channel: c }); 
            });
          });
          console.log('LV devices:', window.LV_devices);
        } catch (e) {
          console.warn('Failed to parse LV entries from mapping JSON', e.message);
        }
        buildTable();
      }).catch(function(err){
        console.warn('Could not load configuration:', err.message);
      });
    };

    loadConfig(config_url);
    buildTable();
};

// Dynamically build HV supply table rows from HV_devices provided by TimingScint_config.js
function init_HVTable(config_url){
    function makeRow(device, index) {
        function makeCell(html) { var td = document.createElement('td'); td.innerHTML = html; return td; }

        var tr = document.createElement('tr');
        // Device name & Channel number
        tr.appendChild(makeCell('' + device + ''));
        tr.appendChild(makeCell('' + index + ''));

        //this is for the SCSHV boxes at PSI
        var statePath = '/Equipment/' + device + '/Variables/ChStatus[' + index + ']';
        var setStatePath = null; //'/Equipment/' + device + '/Variables/ChStatus[' + index + ']';
        var demandVPath = '/Equipment/' + device + '/Variables/Demand[' + index + ']';
        var voltagePath = '/Equipment/' + device + '/Variables/Measured[' + index + ']';
        var currentLimitPath = '/Equipment/' + device + '/Settings/Current Limit[' + index + ']';
        var currentPath = '/Equipment/' + device + '/Variables/Current[' + index + ']';
        var descPath = '/Equipment/' + device + '/Settings/Names[' + index + ']';

        // State color box
        tr.appendChild(makeCell('<div class="modbbox" style="width: 20px; height: 20px;" data-odb-path="' + statePath + '" data-color="lightgreen" data-background-color="red"></div>'));

        // Set state checkbox
	if(setStatePath != null)
            tr.appendChild(makeCell('<input type="checkbox" class="modbcheckbox" data-odb-path="' + setStatePath + '">'));
	else
            tr.appendChild(makeCell(''));

        // Demand Voltage
        tr.appendChild(makeCell('<div class="modbvalue" data-format="f2" data-odb-path="' + demandVPath + '" data-odb-editable="1"></div>'));

        // Voltage
        tr.appendChild(makeCell('<div class="modbvalue" data-format="f2" data-odb-path="' + voltagePath + '"></div>'));

        // Current Limit
        tr.appendChild(makeCell('<div class="modbvalue" data-format="f3" data-odb-path="' + currentLimitPath + '" data-odb-editable="1"></div>'));

        // Current
        tr.appendChild(makeCell('<div class="modbvalue" data-format="f3" data-odb-path="' + currentPath + '"></div>'));

        // Description
        tr.appendChild(makeCell('<div class="modbvalue" data-format="f3" data-odb-path="' + descPath + '" data-odb-editable="1"></div>'));

        return tr;
    }

    var HV_devices = []; // device list (loaded from JSON)

    function buildTable() {
        console.log('Building HV supply table from HV_devices');
        var body = document.getElementById('HVsupplies-body');
        if (!body) return;
        // Clear existing
        body.innerHTML = '';
        if (!window.HV_devices || !Array.isArray(window.HV_devices)) return;

        window.HV_devices.forEach(function(dev){
            //console.log('Processing device:', dev);
            body.appendChild(makeRow(dev.device, dev.channel));
        });
    }

    // Load mapping JSON (same-directory relative path)
    function loadConfig(url){
      fetch(url, {cache: 'no-cache'}).then(function(resp){
        if (!resp.ok) throw new Error('Failed to load mapping');
        return resp.json();
      }).then(function(json){
        // Populate HV_devices from JSON HV field
        try {
          var HV = json && json.HV ? json.HV : [];
          window.HV_devices = [];
          HV.forEach(function(entry){
            // Expect entry: { device: <name>, channel: <value> }
            if (!entry || typeof entry !== 'object') return;
            var device = entry.device !== undefined ? entry.device : null;
            var indices = entry.indices !== undefined ? entry.indices : null;

            indices.forEach(function(c){
              window.HV_devices.push({ device: device, channel: c }); 
            });
          });
          console.log('HV devices:', window.HV_devices);
        } catch (e) {
          console.warn('Failed to parse HV entries from mapping JSON', e.message);
        }
        buildTable();
      }).catch(function(err){
        console.warn('Could not load configuration:', err.message);
      });
    };

    loadConfig(config_url);
    buildTable();
};
