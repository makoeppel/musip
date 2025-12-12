

async function adjust_text_color(node, dac, dac_class, id, std_value) {
    node.style.color = "blue";
    let ids = getRemainingSelection();
    if (ids != -1 && ids != undefined) {
        let config_ids = id;
        let remaining_values = await get_sensors_dac(dac, config_ids, dac_class);
        let value = await get_sensor_dac(dac, id, dac_class);

        // console.log("remaining_values", remaining_values);
        // console.log("value", value);

        let identical = true;
        for (let i = 0; i < remaining_values.length; i++) {
            if (value != remaining_values[i]) {
                identical = false;
                break;
            }
        }

        if (identical == false) {
            //console.log("change color", node);
            node.style.color = "red";
        }
        else if (value != std_value) {
            node.style.color = "lila";
        }
        else {
            node.style.color = "blue";
        }
    }
}

// TODO: add indicator, if dacs are diffent for selected sensors. 
function add_dac_to_table(dac, std_value, dac_class, id, tbody) {
    let tr = document.createElement("tr");
    let td_dac = document.createElement("td");
    td_dac.innerHTML = dac;

    // Create modbvalue textfield for dac of active sensor
    let td_value = document.createElement("td");
    td_value.classList.add("modbvalue");
    let link = `/Equipment/PixelsCentral/Settings/${dac_class}/${id}/${dac}`;
    td_value.setAttribute("data-odb-path", link)
    td_value.setAttribute("data-odb-editable", "1")

    // if the td_value is fully initialized, add the onchange eventlistener to change all remaining sensor dacs if changed 
    td_value.onload = function() {
        // change color of td_value if dac is different for selected sensors
        adjust_text_color(td_value.childNodes[0], dac, dac_class, id, std_value);

        td_value.onchange = function() {
            if (td_value.childNodes[0] == undefined) {
                return;
            }

            adjust_text_color(td_value.childNodes[0], dac, dac_class, id, std_value);

            let ids = getRemainingSelection(); 
            // console.log("onchange - Nodes", td_value.childNodes);
            // console.log("onchange", dac, td_value.childNodes[0].value, ids, dac_class);
            if (ids == -1 || ids == undefined) {
                return;
            }

            let config_ids = id;

            set_sensors_dac(dac, td_value.childNodes[0].value, config_ids, dac_class);
        }
    }

    // Create textfield and button for standard dac value
    let td_std = document.createElement("td");
    td_std.classList.add("dac_std_value");
    let text = document.createElement("span");
    text.innerHTML = std_value;
    let button = document.createElement("button");
    button.classList.add("dac_std_value_button");
    button.innerHTML = "<";
    button.onclick = function() {
        // console.log("button clicked, childNodes", td_value.childNodes);
        let ids = getSelection();
        if (id == -1 || id == undefined) {
            return;
        }
        adjust_text_color(td_value.childNodes[0], dac, dac_class, id, std_value);
        // console.log("button clicked", dac, value, ids, dac_class);
        let config_ids = id;
        set_sensors_dac(dac, std_value, config_ids, dac_class);
    };

    td_std.appendChild(button);
    td_std.appendChild(text);

    //td_std.innerHTML = value;

    tr.appendChild(td_dac);
    tr.appendChild(td_value);
    tr.appendChild(td_std);
    tbody.appendChild(tr);
}

function clean_dac_table(table) {
    let tbodies = table.querySelectorAll("tbody.dac_tbody");
    for (let tbody of tbodies) {
        tbody.remove();
    }
}

async function fill_dac_table(dac_dict, dac_class, table, id, extended = undefined) {
    clean_dac_table(table);

    // if extended is specified, update table.dataset.expanded
    if (extended != undefined) {
        table.dataset.expanded = extended;
    }

    for (let dac_category in dac_dict) {
        let tbody = document.createElement("tbody");
        tbody.classList.add("dac_tbody");        
        
        let tr = document.createElement("tr");
        let th = document.createElement("th");
        th.innerHTML = dac_category;
        th.colSpan = 3;
        tr.appendChild(th);
        tbody.appendChild(tr);

        table.appendChild(tbody);

        for (let [dac, value] of Object.entries(dac_dict[dac_category])) {
            if (dac == "extended"){
                if (table.dataset.expanded == true) {
                    for (let [ext_dac, ext_value] of Object.entries(value)) {
                        add_dac_to_table(ext_dac, ext_value, dac_class, id, tbody);
                    }
                }
            }
            else {
                add_dac_to_table(dac, value, dac_class, id, tbody);
            }
        }
    }

    if (table.dataset.expanded == 0) {
        // Make an button at the bottom of the table to extend, when clicked
        let tbody = document.createElement("tbody");
        tbody.classList.add("dac_tbody");
        let tr = document.createElement("tr");
        let td = document.createElement("td");
        let button = document.createElement("button");
        button.innerHTML = "Show extended DACs";
        button.onclick = function() {fill_dac_table(dac_dict, dac_class, table, id, 1)};
        td.appendChild(button);
        td.colSpan = 3;
        tr.appendChild(td);
        tbody.appendChild(tr);
        table.appendChild(tbody);
    }
    else {
        // Make a button at the bottom of the table to remove extension, when clocked
        let tbody = document.createElement("tbody");
        tbody.classList.add("dac_tbody");
        let tr = document.createElement("tr");
        let td = document.createElement("td");
        let button = document.createElement("button");
        button.innerHTML = "Hide extended DACs";
        button.onclick = function() {fill_dac_table(dac_dict, dac_class, table, id, 0)};
        td.appendChild(button);
        td.colSpan = 3;
        tr.appendChild(td);
        tbody.appendChild(tr);
        table.appendChild(tbody);
    }
}


function fill_dac_tables(id = undefined) {
    // check if radiobutton with id tab-dacs is checked
    let tab_dacs = document.getElementById("tab-dacs");
    if (tab_dacs.checked == false) {
        return;
    }

    // update description text for active selection
    let text = "";
    if (id == -1 || id == undefined) {
        text = "Please select a sensor.";
    }
    else {
        text = id;
    }
    document.getElementById("active_selection_dacs").innerHTML = text;

    // update description text for remaining selection
    let remaining_ids = getRemainingSelection();
    text = "";
    if (remaining_ids == -1 || remaining_ids == undefined) {
        text = "";
    }
    else {
        text = sort_array(remaining_ids).join(", ");
    }
    document.getElementById("remaining_selecion_dacs").innerHTML = text;

    // fill dac tables
    for (let dac_class in Mupix_DACs) {
        let table = document.getElementById(dac_class.toLowerCase() + "_table");
        
        if (table.dataset.expanded == undefined) {
            table.dataset.expanded = 0;
        }

        // clean if no id is selected
        if (id == -1 || id == undefined) {
            clean_dac_table(table);
        }
        else {
            fill_dac_table(Mupix_DACs[dac_class], dac_class, table, id);
        }
    }
} 

// Missing initialization of dac tables