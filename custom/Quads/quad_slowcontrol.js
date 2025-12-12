// Quad Slow Control Module
// Based on VTX_GenericSlowControl.js implementation

// Slow Control ADC name list with conversion functions and color mappings
const sc_adc_name_list = {
    "ref_vssa" : {
        "convert_function" : "x",
        "color_change" : function (div_selected) {
            var value = extract_value_from_div(div_selected);
            if (value === null)
                return;
            let new_color = set_color_from_fraction(value, 255, "therm");
            change_div_color(div_selected, new_color);
        },
        "data_format" : "%f0"
    },
    "Baseline" : {
        "convert_function" : "x",
        "color_change" : function (div_selected) {
            var value = extract_value_from_div(div_selected);
            if (value === null)
                return;
            let new_color = set_color_from_fraction(value, 255, "therm");
            change_div_color(div_selected, new_color);
        },
        "data_format" : "%f0"
    },
    "blpix" : {
        "convert_function" : "x",
        "color_change" : function (div_selected) {
            var value = extract_value_from_div(div_selected);
            if (value === null)
                return;
            let new_color = set_color_from_fraction(value, 255, "therm");
            change_div_color(div_selected, new_color);
        },
        "data_format" : "%f0"
    },
    "thpix" : {
        "convert_function" : "x",
        "color_change" : function (div_selected) {
            var value = extract_value_from_div(div_selected);
            if (value === null)
                return;
            let new_color = set_color_from_fraction(value, 255, "therm");
            change_div_color(div_selected, new_color);
        },
        "data_format" : "%f0"
    },
    "blpix_2" : {
        "convert_function" : "x",
        "color_change" : function (div_selected) {
            var value = extract_value_from_div(div_selected);
            if (value === null)
                return;
            let new_color = set_color_from_fraction(value, 255, "therm");
            change_div_color(div_selected, new_color);
        },
        "data_format" : "%f0"
    },
    "ThLow" : {
        "convert_function" : "x",
        "color_change" : function (div_selected) {
            var value = extract_value_from_div(div_selected);
            if (value === null)
                return;
            let new_color = set_color_from_fraction(value, 255, "therm");
            change_div_color(div_selected, new_color);
        },
        "data_format" : "%f0"
    },
    "ThHigh" : {
        "convert_function" : "x",
        "color_change" : function (div_selected) {
            var value = extract_value_from_div(div_selected);
            if (value === null)
                return;
            let new_color = set_color_from_fraction(value, 255, "therm");
            change_div_color(div_selected, new_color);
        },
        "data_format" : "%f0"
    },
    "TEST_OUT" : {
        "convert_function" : "x",
        "color_change" : function (div_selected) {
            var value = extract_value_from_div(div_selected);
            if (value === null)
                return;
            let new_color = set_color_from_fraction(value, 255, "therm");
            change_div_color(div_selected, new_color);
        },
        "data_format" : "%f0"
    },
    "vssa" : {
        "convert_function" : "x",
        "color_change" : function (div_selected) {
            var value = extract_value_from_div(div_selected);
            if (value === null)
                return;
            let new_color = set_color_from_fraction(value, 255, "therm");
            change_div_color(div_selected, new_color);
        },
        "data_format" : "%f0"
    },
    "thpix_2" : {
        "convert_function" : "x",
        "color_change" : function (div_selected) {
            var value = extract_value_from_div(div_selected);
            if (value === null)
                return;
            let new_color = set_color_from_fraction(value, 255, "therm");
            change_div_color(div_selected, new_color);
        },
        "data_format" : "%f0"
    },
    "VCAL" : {
        "convert_function" : "x",
        "color_change" : function (div_selected) {
            var value = extract_value_from_div(div_selected);
            if (value === null)
                return;
            let new_color = set_color_from_fraction(value, 255, "therm");
            change_div_color(div_selected, new_color);
        },
        "data_format" : "%f0"
    },
    "VTemp1" : {
        "convert_function" : "(x*7.4-990.9)/2.66",
        "color_change" : function (div_selected) {
            var value = extract_value_from_div(div_selected);
            if (value === null)
                return;
            let new_color = set_color_from_fraction(value, 140, "therm-custom-absolute", [0, 80, 100]);
            change_div_color(div_selected, new_color);
        },
        "data_format" : "%f0"
    },
    "VTemp2" : {
        "convert_function" : "(x*7.0588 - 964.3)/2.68",
        "color_change" : function (div_selected) {
            var value = extract_value_from_div(div_selected);
            if (value === null)
                return;
            let new_color = set_color_from_fraction(value, 140, "therm-custom-absolute", [0, 80, 100]);
            change_div_color(div_selected, new_color);
        },
        "data_format" : "%f0"
    }
};

// Slow Control Manager Class
class SlowControlManager {
    constructor() {
        this.selected_chips = [];
        this.current_variable = "VTemp1"; // Default variable
        this.table_initialized = false;
        
        // Set up event listeners
        this._initEventListeners();
    }

    /**
     * Initialize event listeners
     */
    _initEventListeners() {
        // Listen to sensor selection events (all selected sensors)
        window.addEventListener('quad_selection_event', (event) => {
            const selection = getSelectedSensors();
            if (selection && selection.length > 0) {
                this.selected_chips = selection;
                this.updateTable();
                
                // Update the displayed sensor numbers
                const sensorDisplay = document.getElementById("slow_control_selected_sensor");
                if (sensorDisplay) {
                    if (selection.length === 1) {
                        sensorDisplay.textContent = `${selection[0]}`;
                    } else {
                        sensorDisplay.textContent = `${selection.join(', ')}`;
                    }
                }
            } else {
                this.selected_chips = [];
                this.updateTable();
                const sensorDisplay = document.getElementById("slow_control_selected_sensor");
                if (sensorDisplay) {
                    sensorDisplay.textContent = "None";
                }
            }
        });

        // Listen to ADC selection changes
        const scSelect = document.getElementById("sc_read_options");
        if (scSelect) {
            scSelect.addEventListener('change', (event) => {
                this.current_variable = event.target.value;
                this.updateTable();
            });
        }
    }

    /**
     * Update the slow control table based on current selection
     */
    updateTable() {
        const sc_table = document.getElementById("slow_control_variables");
        if (!sc_table) {
            console.error("Slow control table not found");
            return;
        }

        // Clear existing table
        while (sc_table.rows.length > 0) {
            sc_table.deleteRow(0);
        }

        // Create header row with mtableheader class
        const headerRow = sc_table.insertRow(-1);
        const headerCell = headerRow.insertCell(0);
        headerCell.colSpan = 2;
        headerCell.className = "mtableheader";
        headerCell.innerHTML = `Slow Control Values - ${this.current_variable}`;

        // Create column header row
        const colHeaderRow = sc_table.insertRow(-1);
        const colHeader1 = colHeaderRow.insertCell(0);
        colHeader1.innerHTML = "<strong>Sensor</strong>";
        const colHeader2 = colHeaderRow.insertCell(1);
        colHeader2.innerHTML = "<strong>Value</strong>";

        // If no sensors selected, show message
        if (this.selected_chips.length === 0) {
            const row = sc_table.insertRow(-1);
            const cell0 = row.insertCell(0);
            cell0.textContent = "No sensor selected";
            cell0.colSpan = 2;
            cell0.style.textAlign = "center";
            cell0.style.fontStyle = "italic";
            return;
        }

        // Create row for each selected sensor
        for (const chip_number of this.selected_chips) {
            const row = sc_table.insertRow(-1);
            
            // Sensor number cell
            const cell0 = row.insertCell(0);
            cell0.textContent = `${chip_number}`;
            
            // Value cell (combined raw and converted)
            const cell1 = row.insertCell(1);
            
            // Raw value span
            const raw_span = document.createElement("span");
            raw_span.style.color = "#999";
            raw_span.textContent = "(";
            
            const raw_div = document.createElement("div");
            raw_div.id = `slow_control_${chip_number}_${this.current_variable}_raw`;
            raw_div.classList.add("modbvalue");
            raw_div.style.display = "inline";
            
            const raw_close = document.createElement("span");
            raw_close.style.color = "#999";
            raw_close.textContent = ") ";
            
            // Converted value div
            const converted_div = document.createElement("div");
            converted_div.id = `slow_control_${chip_number}_${this.current_variable}_converted`;
            converted_div.classList.add("modbvalue");
            converted_div.style.display = "inline";
            converted_div.style.fontWeight = "bold";
            
            // Append all elements
            cell1.appendChild(raw_span);
            cell1.appendChild(raw_div);
            cell1.appendChild(raw_close);
            cell1.appendChild(converted_div);
            
            // Set ODB paths and formulas
            this._updateCellPaths(chip_number, this.current_variable, raw_div, converted_div);
        }

        this.table_initialized = true;
    }

    /**
     * Update ODB paths for a cell
     */
    _updateCellPaths(chip_number, sc_variable, raw_div, converted_div) {
        const path = this._getSlowControlPath(chip_number, sc_variable);
        
        if (path === "none" || path === null) {
            raw_div.textContent = "N.A.";
            converted_div.textContent = "N.A.";
        } else {
            // Set ODB path for raw value
            raw_div.setAttribute("data-odb-path", path);
            raw_div.setAttribute("data-format", "%f0");
            
            // Set ODB path for converted value
            converted_div.setAttribute("data-odb-path", path);
            converted_div.setAttribute("data-format", sc_adc_name_list[sc_variable]["data_format"]);
            
            const formula = sc_adc_name_list[sc_variable]["convert_function"];
            converted_div.setAttribute("data-formula", formula);
        }
    }

    /**
     * Get the ODB path for a slow control variable
     * @param {number} chip_number - The chip number
     * @param {string} sc_variable - The slow control variable name
     * @returns {string} The ODB path or "none" if not available
     */
    _getSlowControlPath(chip_number, sc_variable) {
        // Use PixelsLabor equipment for quad modules
        return `/Equipment/Quads/Variables/${chip_number}/SC_${sc_variable}`;
    }
}

// Slow Control Command Functions

/**
 * Select ADC for slow control readout
 * @param {string} adc_name - The ADC name to select
 */
function SCSelectADC(adc_name) {
    const odb_keys = [];
    const odb_vals = [];
    
    for (const adcn in sc_adc_name_list) {
        odb_keys.push("Equipment/Quads/Settings/DAQ/Commands/MupixSlowControl/Mux_Address-" + adcn);
        if (adcn === adc_name) {
            odb_vals.push(true);
        } else {
            odb_vals.push(false);
        }
    }
    
    mjsonrpc_db_paste(odb_keys, odb_vals).then(function (rpc) {
        console.log("ADC selected: " + adc_name);
    }).catch(function (error) {
        mjsonrpc_error_alert(error);
    });
}

/**
 * Reset slow control ADC
 */
function resetSC() {
    mjsonrpc_db_paste(["Equipment/Quads/Settings/DAQ/Commands/MupixSlowControl/ADC reset"], [true]).then(function (rpc) {
        console.log("Slow control ADC reset");
    }).catch(function (error) {
        mjsonrpc_error_alert(error);
    });
}

/**
 * Configure slow control for readout
 */
function configureSC() {
    mjsonrpc_db_paste(["Equipment/Quads/Settings/DAQ/Commands/MupixSlowControl/Configure read"], [true]).then(function (rpc) {
        console.log("Slow control configured");
    }).catch(function (error) {
        mjsonrpc_error_alert(error);
    });
}

/**
 * Perform slow control read
 */
function readSC() {
    mjsonrpc_db_paste(["Equipment/Quads/Settings/DAQ/Commands/MupixSlowControl/Perform read"], [true]).then(function (rpc) {
        console.log("Slow control read initiated");
        // Perform a second read after 2 seconds
        setTimeout(function() {
            mjsonrpc_db_paste(["Equipment/Quads/Settings/DAQ/Commands/MupixSlowControl/Perform read"], [true]).then(function (rpc2) {
                console.log("Slow control second read completed");
            }).catch(function (error) {
                mjsonrpc_error_alert(error);
            });
        }, 2000);
    }).catch(function (error) {
        mjsonrpc_error_alert(error);
    });
}

/**
 * Configure continuous slow control readout
 */
function configureContinuousSC() {
    mjsonrpc_db_paste(["Equipment/Quads/Settings/DAQ/Commands/MupixSlowControl/ADC Continuous Readout"], [true]).then(function (rpc) {
        console.log("Continuous slow control readout configured");
    }).catch(function (error) {
        mjsonrpc_error_alert(error);
    });
}

// Helper functions for color management and value extraction

// Fallback for getSelection if not yet loaded
function getSelectedSensors() {
    if (typeof getSelection === 'function') {
        return getSelection();
    } else if (typeof selected !== 'undefined') {
        return selected;
    }
    return [];
}

function extract_value_from_div(div) {
    let value = null;
    if (div.value === undefined) {
        if (div.childarray && div.childarray.length > 0) {
            value = div.childarray[0].value;
        } else {
            // Try to get value from textContent
            if (div.textContent && div.textContent.trim() !== "") {
                value = parseFloat(div.textContent);
                if (isNaN(value)) {
                    value = null;
                }
            } else {
                value = null;
            }
        }
    } else {
        value = div.value;
    }
    return value;
}

function set_color_from_fraction(num, den, mode = "1-good", boundaries = []) {
    var fraction = 0;
    
    if (mode == "1-good") {
        if (den == 0) {
            return "var(--mgray)";
        } else {
            fraction = parseFloat(num) / parseFloat(den);
        }
        if (fraction > 0.999) {
            return "var(--mgreen)";
        } else if (fraction > 0.6) {
            return "var(--myellow)";
        } else if (fraction > 0.3) {
            return "var(--morange)";
        } else {
            return "var(--mred)";
        }
    } else if (mode == "therm") {
        if (den == 0) {
            return "var(--mgray)";
        } else {
            fraction = parseFloat(num) / parseFloat(den);
        }
        if (fraction > 0.999) {
            return "var(--mred)";
        } else if (fraction > 0.9) {
            return "var(--morange)";
        } else if (fraction > 0.3) {
            return "var(--mgreen)";
        } else {
            return "var(--mblue)";
        }
    } else if (mode == "therm-custom") {
        if (den == 0) {
            return "var(--mgray)";
        } else {
            fraction = parseFloat(num) / parseFloat(den);
        }
        if (fraction > boundaries[2]) {
            return "var(--mred)";
        } else if (fraction > boundaries[1]) {
            return "var(--morange)";
        } else if (fraction > boundaries[0]) {
            return "var(--mgreen)";
        } else {
            return "var(--mblue)";
        }
    } else if (mode == "therm-custom-absolute") {
        if (num > boundaries[2]) {
            return "var(--mred)";
        } else if (num > boundaries[1]) {
            return "var(--morange)";
        } else if (num > boundaries[0]) {
            return "var(--mgreen)";
        } else {
            return "var(--mblue)";
        }
    } else {
        console.log("quad_slowcontrol.js: mode ", mode, " not recognized. Returning gray");
        return "var(--mgray)";
    }
}

function change_div_color(div, color) {
    if (div.classList.contains("modbhbar")) {
        div.style["color"] = color;
    } else {
        div.style["background-color"] = color;
    }
}

// Initialize the Slow Control Manager when the page loads
let slowControlManager;

// Wait for DOM to be ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
        slowControlManager = new SlowControlManager();
    });
} else {
    slowControlManager = new SlowControlManager();
}
