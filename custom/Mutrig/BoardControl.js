	const nFEBs = 1;


	function updateBoardStatus(valuex){
        //temperature color mapping
        function Tcolor(T, ind){
            if (ind === undefined || ind === null) return;
            Y = 35;
            R = 40;
            if(-30 < T && T <= Y)
                {ind.style.backgroundColor = "#8FED8F";}
                else if(Y < T && T <= R)
                    {ind.style.backgroundColor = "#FFFF00";}
                    else if(R < T)
                        {ind.style.backgroundColor = "#FF0000";}
                        else
                            {ind.style.backgroundColor = "#FFFFFF";}
        }
        function LampColor(obj, status){
            if (obj === undefined || obj === null) return;
            if(status)
                {obj.style.backgroundColor="#8FED8F";}
            else
                {obj.style.backgroundColor="#AAAAAA";};
        }

        //unpack
		var status = valuex;
		if(typeof valuex == 'object'){
		    status = JSON.parse(JSON.stringify(valuex));
        }else if(typeof valuex == 'string'){
		    status = JSON.parse(valuex);
        }
        //console.log("updateBoardStatus: "+status);

		var init_bit = new Array(nFEBs*2);
		var inject_bit = new Array(nFEBs*2);
        var vcca_bit = new Array(nFEBs*2);
        var vccd_bit = new Array(nFEBs*2);
        var pgood_bit = new Array(nFEBs*2);
		var temperature = new Array(nFEBs*2);
		for(var i=0; i < nFEBs; i++){
            for(var j=0; j < 2; j++){
        	    init_bit[i*2+j]   = status[i*4] & (0x01<<j*3);
                inject_bit[i*2+j] = status[i*4] & (0x02<<j*3);
                pgood_bit[i*2+j]  = status[i*4] & (0x04<<j*3);
                vcca_bit[i*2+j]   = status[i*4+1] & (1<<j);
                vccd_bit[i*2+j]   = status[i*4+1] & (1<<(j+13));
                temperature[i*2+j]= status[i*4+2+j]/100;    //TODO: check calibration
            }
		}

        for(var i=0; i < nFEBs*2; i++){
            //Temperatures
			document.getElementsByName("TMB_T")[i].innerHTML = temperature[i];
			Tcolor(temperature[i], document.getElementsByName("TMB_T")[i]);

			// Status Indicators
			initlamp = document.getElementsByName("Init")[i];
			injectlamp = document.getElementsByName("Inject")[i];
            vccalamp = document.getElementsByName("vcca")[i];
            vccdlamp = document.getElementsByName("vccd")[i];
			LampColor(initlamp,init_bit[i]);
            LampColor(injectlamp,inject_bit[i]);
            LampColor(vccalamp,vcca_bit[i]);
            LampColor(vccdlamp,vccd_bit[i]);
		}
		
        //store maximum temperature for overall TMB indicator
		Tmax = Math.max(...temperature);
        Tcolor(Tmax, document.getElementById("TMB_Tall"));

	}

    const COUNTER_TYPES  = ["TDCF", "TDCE", "TDCH"];
    counterBoxes = { tdcf: [], tdce: [], tdch: [] };

    function map_counter_tooltips() {
        COUNTER_TYPES.forEach((name) => {
            const boxes = Array.from(document.getElementsByName(`counter_box_${name.toLowerCase()}`));
            counterBoxes[name.toLowerCase()] = boxes;
            boxes.forEach((box, i) => {
                box.setAttribute("data-odb-path", "Runinfo/State");
                box.setAttribute("data-background-color", "#AAAAAA");
                box.setAttribute("data-color", "#FFFF00");         // default: gelb

                const tooltip = box.childNodes[0];
                const table   = document.createElement("table");

                for (let y = 0; y < 2; y++) {
                    const rowIdx = 2 * i + y;
                    table.insertRow().innerHTML =
                        `<td style="white-space:nowrap;"> ${name} ${rowIdx}: ` +
                        `<span id="counter_${name}_${rowIdx}" class="modbvalue" ` +
                        `data-odb-path="Equipment/TilesLabor/Variables/${name}[${rowIdx}]"></span></td>`;
                }
                //tooltip.appendChild(table);
            });
        });
    }

    //Color mapping function for global counter boxes
    function counter_colormap(x){
        /*
        tdcf_all = document.getElementById("tdcf_all");
        tdce_all = document.getElementById("tdce_all");
        tdch_all = document.getElementById("tdch_all");

        tdcf_all.setAttribute("data-color","#FFFF00");
        tdce_all.setAttribute("data-color","#FFFF00");
        tdch_all.setAttribute("data-color","#FFFF00");
        */

        if(x != 3){
            return false;
        }
        else{
            return true;
        }
    }

    function applyColors(values, type) {
		var value = values;
		if(typeof values == 'object')
		{valuez = JSON.stringify(values);
		value = JSON.parse(valuez);}
		else if(typeof values == 'string')
		{value = JSON.parse(values);}
        values = value;
        console.log("Applying colors for", type, "with values:", values);


        const boxes = counterBoxes[type];
        console.log("Found boxes for", type, ":", boxes);
        if (!boxes.length) return;
        for (let mod = 0; mod < boxes.length; mod++) {
            const slice = values.slice(mod * 2, (mod + 1) * 2);
            let color;

            switch (type) {
                case "tdcf": {
                    // 0 -> gray, 80865 -> green, else orange
                    const allZero     = slice.every((v) => v === 0);
                    const allGood    = slice.every((v) => Math.abs(v - 80645) <= 3);
                    if (allZero)       color = "#AAAAAA";
                    else if (allGood) color = "#8FED8F";
                    else               color = "#FFFF00";
                    break;
                }

                case "tdce": {
                    // 0 -> green, <=1e5 -> yellow, >1e5 -> red
                    const max = Math.max(...slice);
                    if (max === 0)          color = "#8FED8F";
                    else if (max <= 1e5)    color = "#FFFF00";
                    else                    color = "#FF0000";
                    break;
                }
                case "tdch": {
                    // 0 -> gray, >0 -> green
                    const allZero = slice.every((v) => v === 0);
                    color = allZero ? "#AAAAAA" : "#8FED8F";
                    break;
                }
            }
            console.log(`Module ${mod} (${type}): setting color to ${color}`);
            boxes[mod].setAttribute("data-color", color);
        }
    }



	function init_boardtable()
	{
        body = document.getElementById("ModuleControl-body");
        if (!body) return;
        body.innerHTML = '';

        mjsonrpc_db_get_values(["/Equipment/LinksLabor/Settings/LinkMask","/Equipment/LinksLabor/Settings/FEBType"]).then(function(rpc) {
            boardID = 0;
            for(let feb=0; feb<4; feb++) {
                // Only include boards that are enabled in LinkMask
                // only include Tile febs here
                if(rpc.result.data[0][feb] != "0x00000003") {
                    continue;
                }
                if(rpc.result.data[1][feb] != "0x00000004") {
                    continue;
                }
                febID = feb - 2;
                //TODO: implement mapping from feb (port number) to module number (febID)
                for (let board = 0; board < 2; board++) {
                    // Create a new row
                    var row = document.createElement('tr');    
                    row.innerHTML = `
                        <td>${febID}.${board}</td>
                        <td style="text-align: center"><input type="checkbox" name="Power" class="modbcheckbox" data-odb-path="/Equipment/TilesLabor/TMB_control/module_power_mask[${febID}]" style="width:20px; height: 20px;"></td>
                        <!-- CheckBox for ASIC mask, per asic -->
                        <!-- CheckBox for LVDS mask, per asic -->
                        <td style="text-align: center"><div class="modbbox" name="Init" style="width:25px; height: 20px;"></div></td>
                        <td style="text-align: center"><div class="modbbox" name="Inject" style="width:25px; height: 20px;"></div></td>
                        <td style="text-align: center"><div class="modbbox" name="vcca" style="width:25px; height: 20px;"></div></td>
                        <td style="text-align: center"><div class="modbbox" name="vccd" style="width:25px; height: 20px;"></div></td>
                        <td style="text-align: center">
                            <input type="checkbox" name="ASICMaskCB" onclick=updateASICmask(this,${feb},${board})></input>
                            <div class="modbvalue" name="ASICMask" data-odb-path="/Equipment/LinksLabor/Settings/ASICMask[${feb}]" data-odb-editable="0" style="width:60px; height: 20px;"  onchange="initASICMaskCB()"></div>
                        </td> 
                        <td style="text-align: center">
                            <input type="checkbox" name="LVDSMaskCB" onclick=updateLVDSmask(this,${feb},${board})>
                            <div class="modbvalue" name="LVDSMask" data-odb-path="/Equipment/LinksLabor/Settings/LVDSLinkMask[${feb}]" data-odb-editable="0" style="width:60px; height: 20px;" onchange="initLVDSMaskCB()"></div>
                            </input>
                        </td> 
                        <td style="text-align: center"><div class="modbbox" name="TMB_P" style="width:50px; height: 20px;"></div></td>
                        <td style="text-align: center"><div class="modbbox" name="TMB_P" style="width:50px; height: 20px;"></div></td>
                        <td style="text-align: center"><div class="modbbox" name="TMB_T" style="width:120px; height: 20px;"></div></td>
                        <td style="text-align: center"><div class="modbbox hoverable_counter" id="tdcf_${feb}" name="counter_box_tdcf" data-formula="counter_colormap(x);" style="width:20px; height: 20px; margin:auto;"><div class="tooltip_counter"></div></div></td>
                        <td style="text-align: center"><div class="modbbox hoverable_counter" id="tdce_${feb}" name="counter_box_tdce" data-formula="counter_colormap(x);" style="width:20px; height: 20px; margin:auto;"><div class="tooltip_counter"></div></div></td>
                        <td style="text-align: center"><div class="modbbox hoverable_counter" id="tdch_${feb}" name="counter_box_tdch" data-formula="counter_colormap(x);" style="width:20px; height: 20px; margin:auto;"><div class="tooltip_counter"></div></div></td>
                        `;
                    // Append the new row to the table
                    body.appendChild(row);
                    ++boardID;
                }
            }
            //map_dcdc();
            //map_hv();
            map_counter_tooltips();
        });
	}


function initASICMaskCB(){
    index = 0;
    for(object of document.getElementsByName("ASICMaskCB")){
        feb = Math.floor(index/2);
        board = index % 2;
        value = document.getElementsByName("ASICMask")[feb].value;
        mask = 1<<board;
        bvalue = (value & mask) >> board;
        //console.log("Index:", index, "FEB:", feb, " Board:", board, " Value:", value, " Mask:", mask, " Result:", bvalue);
        object.checked = bvalue;
        index += 1;
    }
}

function initLVDSMaskCB(){
    index = 0;
    for(object of document.getElementsByName("LVDSMaskCB")){
        feb = Math.floor(index/2);
        board = index % 2;
        value = document.getElementsByName("LVDSMask")[feb].value;
        mask = 1<<board;
        bvalue = (value & mask) >> board;
        //console.log("Index:", index, "FEB:", feb, " Board:", board, " Value:", value, " Mask:", mask, " Result:", bvalue);
        object.checked = bvalue;
        index += 1;
    }
}



function updateASICmask(checkbox, feb, board){
    const mask = 1<<board;
    obj = document.getElementsByName("ASICMask")[0];
    value = parseInt(obj.value);
    value &= ~mask;
    value |= checkbox.checked << board;
    console.log("ASIC Mask for FEB ", feb, " Board ", board, " set to ", value);
    modbset(obj.dataset.odbPath, value)
}

function updateLVDSmask(checkbox, feb, board){
    const mask = 1<<board;
    obj = document.getElementsByName("LVDSMask")[0];
    value = parseInt(obj.value);
    value &= ~mask;
    value |= checkbox.checked << board;
    console.log("LVDS Mask for FEB ", feb, " Board ", board, " set to ", value);
    obj.setValue(value);
}


function setGlobalASICpower( flag = false ){
    setODBValue("/Equipment/TilesLabor/TMB_control/module_power", flag, false);
}

function boardcontrol_init(){
        console.log("Initializing Board Control Module");
        path="/Equipment/TilesLabor";
        //Initializing all functions to display current ODB
        mjsonrpc_db_get_values(["/Equipment/LinksLabor/Settings/LinkMask"]).then(
		rpcL => {
			linkmask = rpcL.result.data[0];
        	maxtmb = linkmask.lastIndexOf("0x00000003")+1;
            init_boardtable();
        	mjsonrpc_db_get_values([path.concat("/Variables/","TDCF")]).then(function(rpc){applyColors(rpc.result.data[0], "tdcf")});
        	mjsonrpc_db_get_values([path.concat("/Variables/","TDCE")]).then(function(rpc){applyColors(rpc.result.data[0], "tdce")});
        	mjsonrpc_db_get_values([path.concat("/Variables/","TDCH")]).then(function(rpc){applyColors(rpc.result.data[0], "tdch")});
        	mjsonrpc_db_get_values([path.concat("/Variables/","TDSM")]).then(function(rpc){updateBoardStatus(rpc.result.data[0])});
        	mjsonrpc_db_get_values(["/Equipment/TilesLabor/Settings/Names TDTM"]).then(function(rpc){
        	    tmp_names = rpc.result.data[0];
	    	});
        	mjsonrpc_db_get_values(["/Equipment/TilesLabor/Settings/Names TDPM"]).then(function(rpc){
        	    power_names = rpc.result.data[0];
            });
            initASICMaskCB()
            initLVDSMaskCB()
        });
}

