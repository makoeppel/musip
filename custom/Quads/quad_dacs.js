class DACManager {
    constructor() {
        this.id = undefined;
        this.conf_ids = undefined;
        this.remaining_ids = undefined;
        this.visible = false;
        this.currentDACSet = "Quads"; // Default DAC set, can be changed by radio buttons

        // HTML elements
        this.desc_active = document.getElementById("active_selection_dacs");
        this.desc_remaining = document.getElementById("remaining_selecion_dacs");
        this.tables = [];

        this.currentDACReference = Default_DAC_Sets[this.currentDACSet];

        // Generate DAC set radio buttons
        this._generateDACSetRadioButtons();

        for (let dac_class in this.currentDACReference) {
            
            this.tables.push(new DACTable(dac_class))
            this.set_visible(false);
        }

        this._init();
    }

    /**
     * Generate radio buttons for DAC set selection
     */
    _generateDACSetRadioButtons() {
        const radioGroupContainer = document.getElementById("dac-set-radio-group");
        if (!radioGroupContainer) {
            console.error("DAC set radio group container not found");
            return;
        }

        // Clear existing radio buttons
        radioGroupContainer.innerHTML = "";

        // Create radio buttons for each DAC set
        let isFirst = true;
        for (const dacSetName in Default_DAC_Sets) {
            const label = document.createElement("label");
            const radio = document.createElement("input");
            
            radio.type = "radio";
            radio.name = "dac-set";
            radio.value = dacSetName;
            radio.checked = isFirst; // Check the first one by default
            
            label.appendChild(radio);
            label.appendChild(document.createTextNode(" " + dacSetName));
            
            radioGroupContainer.appendChild(label);
            
            if (isFirst) {
                this.currentDACSet = dacSetName;
                isFirst = false;
            }
        }
    }

    _init() {

        const tab_dacs = document.querySelector("#tab-dacs");

        tab_dacs.addEventListener("change", (event) => {
            if (tab_dacs.checked == false || this.id == undefined || this.id == -1) {
                return;
            }
            this.set_visible(true);
            this.update();
        });

        // Add event listener for DAC set radio buttons
        const dacSetRadios = document.querySelectorAll('input[name="dac-set"]');
        dacSetRadios.forEach(radio => {
            radio.addEventListener('change', (event) => {
                if (event.target.checked) {
                    this.changeDACSet(event.target.value);
                }
            });
        });


        // add event Listener to sensor selection:
        window.addEventListener("quad_active_selection_event", (event) => {
            let active = getActiveSelection();
            if (this.id == active) {
                return;
            }
            this.id = active;
            this.update_id();
        })

        window.addEventListener("quad_selection_event", async (event) => {
            // console.log("remaining DAC Selection", getRemainingSelection())
            this.remaining_ids = getRemainingSelection();
            //this.remaining_ids = getConfigIds(remaining_ids);
            let selection_ids = getSelection();

            // console.log("selection", selconfigure = falseis.ids and selection are true, even if th e selection just changed.
            // if (this.ids == selection)  {
            //     return;
            // }

            let slow = false
            if (this.conf_ids == undefined) {
                slow = true;
            }

            this.conf_ids = getConfigIds(selection_ids);

            // console.log("initiate update function.")
            this.update();

            if (this.visible == false) {
                return;
            }

            this.update_remaining_ids(slow);
        })

    }
    
    get_id() {
        return this.id;
    }

    get_remaining_ids() {
        return this.remaining_ids;
    }

    getCurrentDACSet() {
        return this.currentDACSet;
    }

    changeDACSet(dacSetName) {
        if (dacSetName === this.currentDACSet) {
            return; // No change needed
        }

        console.log(`Changing DAC set from ${this.currentDACSet} to ${dacSetName}`);
        
        this.currentDACSet = dacSetName;
        this.currentDACReference = Default_DAC_Sets[dacSetName];

        // Update all tables with new DAC set - use a gentler update that preserves current values
        for (let table of this.tables) {
            table.updateDACSetPreservingValues(this.currentDACReference[table.class]);
        }

        // Trigger an update to refresh the display
        this.update();
    }


    set_visible(flag) {
        this.visible = flag;
        for (let table of this.tables) {
            table.set_visible(flag);
        }
    }


    clean() {
        // console.log("clean dac tables")
        for (let table of this.tables) {
            table.clean();
        }
    }
       

    update() {
        let tab_dacs = document.getElementById("tab-dacs");
        console.log("update:", tab_dacs.checked, this.id)
        this.update_description();

        if (tab_dacs.checked == false || this.id == undefined || this.id == -1) {
            //this.clean();
            this.set_visible(false);
            return;
        }

        // console.log("initate update description")

        if (this.visible == false) {
            return;
        }

        for (let table of this.tables) {
            table.update();
        }
    }

    async update_description() {
        // update description text for active selection
        let text = "";
        if (this.id == -1 || this.id == undefined) {
            text = "Please select a sensor.";
        }
        else {
            text = this.id;
        }
        this.desc_active.innerHTML = text;

        // update description text for remaining selection
        // console.log("remaining ids", this.remaining_ids)
        if (this.remaining_ids == -1 || this.remaining_ids == undefined) {
            text = "";
        }
        else {
            text = sort_array(this.remaining_ids).join(", ");
        }
        this.desc_remaining.innerHTML = text;
    }

    async update_id() {
        if (this.id == -1 || this.id == undefined) {
            if (this.visible == true) {
                // make all the other parts invisible
                this.set_visible(false);
            }
            return;
        }
        // if (this.visible == false) {
        //     return;
        // }

        for (let table of this.tables) {
            //console.log("Initiate id update:", this.id)
            table.update_id(this.id);
        } 

        this.set_visible(true);
    }

    async update_remaining_ids(slow) {       
        for (let table of this.tables) {
            table.update_remaining_ids(this.remaining_ids, slow);
        } 
    }

}

class DACTable {
    constructor(dac_class, id = undefined) {
        this.class = dac_class;
        this.table = document.getElementById(dac_class.toLowerCase() + "_table");
        this.expanded = false;
        this.visible = false
        this.id = id;

        this.button = undefined;
        this.button_tbody = undefined;

        this.dac_dict = Default_DAC_Sets["Quads"][dac_class];

        this.categories = []

        this._init();
    }

    /**
     * Create a button to expand/collapse the table
     */
    _createExpandButton() {
        this.button_tbody = document.createElement("tbody");
        this.button_tbody.classList.add("dac_tbody");
        let tr = document.createElement("tr");
        let td = document.createElement("td");
        td.classList.add("dac_button_container");
        td.setAttribute("colspan", "3");
        this.button = document.createElement("button");
        this.button.onclick = () => {
            this.toggle_expansion();
        }

        this.update_button();

        td.appendChild(this.button);
        tr.appendChild(td);
        this.button_tbody.appendChild(tr);
        this.table.appendChild(this.button_tbody);
    }

    /**
     * Create the table for the DACs
     */
    _init() {
        this._initCategories();
        this._createExpandButton();
    }

    /**
     * Initialize DAC categories
     */
    _initCategories() {
        for (let [category, dacs] of  Object.entries(this.dac_dict)) {
            //console.log("category", category);
            let dac_category = new DACCategory(category, dacs, this.class)
            this.categories.push(dac_category);
            
            // append tbody of categories to table
            this.table.appendChild(dac_category.get_container());
        }
    }

    /**
     * Update the DAC set being used by this table while preserving current values
     */
    updateDACSetPreservingValues(newDACDict) {
        this.dac_dict = newDACDict;
        
        // Update default values in existing categories/cells
        for (let category of this.categories) {
            category.updateDefaultValues(newDACDict);
        }
        
        // Trigger color updates since default values changed
        if (this.visible && this.id !== undefined && this.id !== -1) {
            // Small delay to ensure all updates propagate
            setTimeout(() => {
                for (let category of this.categories) {
                    for (let cell of category.dac_cells) {
                        cell.update_text_color(true);
                    }
                }
            }, 100);
        }
    }

    /**
     * Update the DAC set being used by this table
     */
    updateDACSet(newDACDict) {
        this.dac_dict = newDACDict;
        
        // Store current state
        const wasVisible = this.visible;
        const currentId = this.id;
        const currentRemainingIds = this.remaining_ids;
        const expandedState = this.expanded;
        
        // Clean existing categories
        this.clean();
        this.categories = [];
        
        // Recreate categories with new DAC set
        this._initCategories();
        
        // Recreate expand button
        this._createExpandButton();
        
        // Restore state
        this.expanded = expandedState;
        this.update_button();
        
        // Restore visibility and update with current sensor data
        if (wasVisible) {
            this.set_visible(true);
            if (currentId !== undefined && currentId !== -1) {
                this.update_id(currentId);
            }
            if (currentRemainingIds !== undefined && currentRemainingIds !== -1) {
                this.update_remaining_ids(currentRemainingIds, false);
            }
        }
    }

    set_visible(flag) {
        this.visible = flag;
        for (let category of this.categories) {
            category.set_visible(flag);
        }
        if (flag == false) {
            this.button_tbody.style.display = "none";
        }
        else {
            this.button_tbody.style.display = "table-row-group";
        }
    }

    toggle_expansion() {
        this.expanded = !this.expanded;

        this.update_button();

        for (let category of this.categories) {
            category.set_expansion(this.expanded);
        }
    }

    /**
     * Remove all DACs from the table
     */
    clean() {
        //let tbodies = Object.values(this.categories);
        let tbodies = this.table.querySelectorAll("tbody.dac_tbody");
        for (let tbody of tbodies) {
            tbody.remove();
        }
    }

    /**
     * Update the DACs in the table
     */
    update() {
        if (this.visible == false) {
            return;
        }
        // console.log("update", this.class);
    }

    update_button() {
        let text = "";
        if (this.expanded == true) {
            text = "Collapse";
        }
        else {
            text = "Expand";
        }
        this.button.innerHTML = text;
    }

    update_id(id) {
        for (let category of this.categories) {
            category.update_id(id);
        }
    }

    update_remaining_ids(ids, slow) {
        for (let category of this.categories) {
            category.update_remaining_ids(ids, slow);
        }
    }
}

class DACCategory {
    constructor(category, dacs, dac_class){
        this.tbody = document.createElement("tbody");

        this.category = category;
        this.dacs_ref = dacs;
        this.dac_class = dac_class;

        this.dac_cells = [];
        this.dac_cells_exp = [];

        this.expanded = false;

        this._init();
    }

    _init() {
        this.tbody.classList.add("dac_tbody");

        let tr = document.createElement("tr");
        let th = document.createElement("th");
        th.innerHTML = this.category;
        th.setAttribute("colspan", "3");
        tr.appendChild(th); 
        this.tbody.appendChild(tr);

        this._create_dac_cells()
    }

    _create_dac_cells() {
        for (let [dac, value] of Object.entries(this.dacs_ref)) {
            let visible = !value.exp;
            let desc = undefined;
            if (value.desc != undefined) {
                desc = value.desc;
            }
            let dac_cell = new DACCell(dac, value.std, this.dac_class, visible, desc);
            if (value.exp == true) {
                this.dac_cells_exp.push(dac_cell);
                this.tbody.appendChild(dac_cell.get_container());
            }
            else {
                this.dac_cells.push(dac_cell);
                this.tbody.appendChild(dac_cell.get_container());
            }            
        }
    }

    _remove_dac_cells() {
        for (let dac_cell of this.dac_cells) {
            dac_cell.get_container().remove();
        }
        for (let dac_cell of this.dac_cells_exp) {
            dac_cell.get_container().remove();
        }
    }

    get_container() {
        return this.tbody;
    }

    set_visible(flag) {
        // console.log("set_visible of DACCategory", this.category, "to", flag);
        if (flag == true) {
            this.tbody.style.display = "table-row-group";
        }
        else {
            this.tbody.style.display = "none";
        }
    }

    set_expansion(flag) {
        this.expanded = flag;
        if (flag == true) {
            for (let dac_cell of this.dac_cells_exp) {
                dac_cell.set_visible(true);
            }
            this.update_expanded();
        }
        else {
            for (let dac_cell of this.dac_cells_exp) {
                dac_cell.set_visible(false);
            }
        }
    }

    update_expanded() {
        for (let dac_cell of this.dac_cells_exp) {
            dac_cell.update();
        }
    }

    async update_id(id) {
        // Has to be added, as changing the odb-link of an existing cell does not work correctly.
        //await this._remove_dac_cells();
        //await this._create_dac_cells();

        for (let dac_cell of this.dac_cells) {
            this.update_cell_id(dac_cell, id);
        }

        for (let dac_cell of this.dac_cells_exp) {
            this.update_cell_id(dac_cell, id);
        }
    }

    async update_cell_id(cell, id) {
        //await cell.remove_odb_link();
        //cell.set_odb_link(id);
        cell.update_cell_id(id);
    }

    update_remaining_ids(ids, slow) {
        for (let dac_cell of this.dac_cells) {
            dac_cell.update_remaining_ids(ids, slow);
        }
        if (this.expanded == true) {
            for (let dac_cell of this.dac_cells_exp) {
                dac_cell.update_remaining_ids(ids, slow);
            }
        }

    }

    /**
     * Update default values for existing DAC cells with new DAC set data
     */
    updateDefaultValues(newDACDict) {
        // Update reference to new DAC dictionary
        if (newDACDict[this.category]) {
            this.dacs_ref = newDACDict[this.category];
            
            // Update each DAC cell's default value
            for (let dac_cell of this.dac_cells) {
                if (this.dacs_ref[dac_cell.dac_name]) {
                    dac_cell.updateDefaultValue(this.dacs_ref[dac_cell.dac_name].std);
                }
            }
            
            for (let dac_cell of this.dac_cells_exp) {
                if (this.dacs_ref[dac_cell.dac_name]) {
                    dac_cell.updateDefaultValue(this.dacs_ref[dac_cell.dac_name].std);
                }
            }
        }
    }
}

class DACCell {
    constructor(dac_name, std_value_sel, dac_class, expanded, description = undefined) {
        this.dac_name = dac_name;
        this.std_value_sel = std_value_sel
        this.dac_class = dac_class;
        this.expanded = expanded;
        this.description = description;

        if (Array.isArray(std_value_sel)) {
            this.std_value = std_value_sel[0];
        }
        else {
            this.std_value = std_value_sel;
        }

        this.value = undefined;

        this.id = undefined;
        this.conf_id = undefined;
        this.remaining_ids = undefined;
        this.visible = false;
        this.value_edited = false;

        this.cell_odb_value = undefined;

        this._init();
    }

    _init() {
        // console.log("create dac cell", this.dac_name, this.std_value, this.dac_class);
        // whole row
        this.row = document.createElement("tr");

        // name cell
        let cell_dac_name = document.createElement("td");
        cell_dac_name.innerHTML = this.dac_name;
        
        // modbvalue (don's set a link yet)
        this.cell_odb = document.createElement("td");

        if (Array.isArray(this.std_value_sel)) {
            this.odb_sel = document.createElement("select");
            this.odb_sel.classList.add("dac_select");
            // give this.std_value_sel as dropdown options
            for (let i = 0; i < this.std_value_sel.length; i++) {
                let option = document.createElement("option");
                option.classList.add("dac_select_option");
                option.value = this.std_value_sel[i];
                if (this.description != undefined) {
                    option.innerHTML = this.std_value_sel[i] + " - " + this.description[i];
                }
                else {
                    option.innerHTML = this.std_value_sel[i];
                }
                this.odb_sel.appendChild(option);
            }
            
            // on change apply this value to all selected sensors
            this.odb_sel.onchange = async () => {
                this.value = this.odb_sel.value;
                
                // Get all selected sensors including active one
                let all_selected_ids = getSelection();
                if (all_selected_ids == -1 || all_selected_ids == undefined || all_selected_ids.length == 0) {
                    // Just set for active sensor if no selection
                    await set_sensor_dac(this.dac_name, this.value, this.conf_id, this.dac_class);
                } else {
                    // Set for all selected sensors
                    let all_conf_ids = getConfigIds(all_selected_ids);
                    await set_sensors_dac(this.dac_name, this.value, all_conf_ids, this.dac_class);
                }
                
                // Wait a bit for ODB updates to propagate
                await sleep(50);
                
                // Update this cell and trigger color update for all related cells
                this.update();
                this.trigger_selection_color_update();
            }
        }
        if (this.odb_sel != undefined) {
            this.cell_odb.appendChild(this.odb_sel);
        }

        // standard value (textfield and reset button)
        this.cell_std = document.createElement("td");
        this.cell_std.classList.add("dac_std_value");

        let std_button = document.createElement("button");
        std_button.classList.add("dac_std_value_button");
        std_button.innerHTML = "<";
        std_button.onclick = () => {
            //console.log("button clicked, childNodes", this.cell_odb_value.childNodes);
            this.revert();
        }

        this.std_text = document.createElement("span");
        this.std_text.innerHTML = this.std_value;

        // if (Array.isArray(this.std_value_sel)) {
        //     this.std_sel = document.createElement("select");
        //     this.std_sel.classList.add("dac_select");
        //     // give this.std_value_sel as dropdown options
        //     for (let i = 0; i < this.std_value_sel.length; i++) {
        //         let option = document.createElement("option");
        //         option.classList.add("dac_select_option");
        //         option.value = this.std_value_sel[i];
        //         if (this.description != undefined) {
        //             option.innerHTML = this.std_value_sel[i] + " - " + this.description[i];
        //         }
        //         else {
        //             option.innerHTML = this.std_value_sel[i];
        //         }
        //         this.std_sel.appendChild(option);
        //     }
            
        //     // on change apply this value to this.std_value
        //     this.std_sel.onchange = () => {
        //         this.std_value = this.std_sel.value;
        //         this.std_text.innerHTML = this.std_value;
        //     }
        // }

        this.cell_std.appendChild(std_button);
        this.cell_std.appendChild(this.std_text);
        // if (this.std_sel != undefined) {
        //     this.cell_std.appendChild(this.std_sel);
        // }

        this.row.appendChild(cell_dac_name);
        this.row.appendChild(this.cell_odb);
        this.row.appendChild(this.cell_std);

        this.set_visible(this.expanded)
    }

    get_container() {
        return this.row;
    }


    _create_odb_cell() {
        this.cell_odb_value = document.createElement("span");
        this.cell_odb_value.classList.add("modbvalue");

        if (this.odb_sel != undefined) {
            this.cell_odb.insertBefore(this.cell_odb_value, this.odb_sel);
        }
        else {
            this.cell_odb.appendChild(this.cell_odb_value);
        }
    }

    _remove_odb_cell() {
        // remove cell this.cell_odb_value
        if (this.cell_odb_value == undefined) {
            return;
        }
        this.cell_odb_value.remove();
    }

    /**
     * Sets the ODB link for the DAC cell with the given ID.
     * @param {number} id - The ID of the DAC cell.
     */
    async set_odb_link(id) {
        //console.log("Set odb Link: ", id, this.dac_name)
        this.id = id;
        this.conf_id = getConfigIds(id);
        let link = `/Equipment/Quads/Settings/Config/${this.dac_class}/${this.dac_name}[${this.conf_id}]`;
        this.cell_odb_value.setAttribute("data-odb-path", link); // used to be await
        this.cell_odb_value.setAttribute("data-odb-editable", "1");

        //console.log("get newlink", this.cell_odb_value.getAttribute("data-odb-path"));

        // await sleep(1000);
        // this.update();

        // create on load event listener
        //console.log("create listeners", this.cell_odb_value)
        this.cell_odb_value.onload = () => {
            if (this.cell_odb_value.childNodes[0] == undefined) {
                console.log("onload: childNodes[0] is undefined");
                return;
            }

            this.value = parseInt(this.cell_odb_value.childNodes[0].firstChild.data);
            this.value_edited = false;
            //console.log("Set this.value to:", this.value)

            // create on change event listener
            this.create_listeners();
            this.update();
        }
        
    }

    async create_listeners() {

        this.cell_odb_value.oninput = async () => {
            console.log("oninput has been activated.")
            this.value_edited = true;
        }
        
        this.cell_odb_value.onchange = async () => {
            //if (this.value_edited == false) {
            //    return;
            //}
            this.value_edited = false;

            //console.log("child Objects:", this.cell_odb_value.childNodes);
            console.log("onblur, check nodeName, should be INPUT: ", this.cell_odb_value.childNodes[0])
            if (this.cell_odb_value.childNodes[0].nodeName != "INPUT") {
                //console.log("onchange: return because of color change.");
                return;
            }

            let new_value = parseInt(this.cell_odb_value.childNodes[0].value);
            if (new_value == undefined) {
                new_value = parseInt(this.cell_odb_value.childNodes[0].firstChild.data);
            }

            if (this.cell_odb_value.childNodes[0] == undefined) {
                //console.log("onchange: childNodes[0] is undefined");
                return;
            }
            if (this.value == undefined) {
                //console.log("onchange: value is undefined. Set", this.dac_name ,"to:", new_value);
                this.value = new_value;
                return;
            }
            else if (this.value == new_value) {
                //console.log("onchange: value did not change. Old vlaue:" , this.value, "new value:", new_value);  
                return;
            }
            else {
                this.value = new_value;
            }

            //console.log("value of:", this.dac_name, "changed.", "new value:", this.value, "old method:", this.cell_odb_value.childNodes[0].value);

            // Apply to all selected sensors, not just remaining ones
            let all_selected_ids = getSelection();
            if (all_selected_ids == -1 || all_selected_ids == undefined || all_selected_ids.length <= 1) {
                //console.log("onchange: single sensor or no selection");
                this.update();
                // Still trigger color update for consistency
                setTimeout(() => this.trigger_selection_color_update(), 50);
                return;
            }
            
            let all_conf_ids = getConfigIds(all_selected_ids);
            await set_sensors_dac(this.dac_name, this.cell_odb_value.childNodes[0].value, all_conf_ids, this.dac_class);
            
            // Wait for propagation and update colors
            await sleep(50);
            this.update(true);
            this.trigger_selection_color_update();
        }
    }

    async remove_odb_link() {
        //console.log("remove odb link", this.id, this.dac_name,)
        this.cell_odb_value.removeAttribute("data-odb-path");
        this.cell_odb_value.removeAttribute("data-odb-editable");

        // remove eventlisteners
        this.cell_odb_value.onload = undefined;
        this.cell_odb_value.onchange = undefined;
        this.cell_odb_value.oninput = undefined;
    }

    async revert() {
        let ids = getSelection();
        if (ids == -1 || ids == undefined) {
            return;
        }

        let conf_ids = getConfigIds(ids);
        await set_sensors_dac(this.dac_name, this.std_value, conf_ids, this.dac_class);
        
        // Wait for DAC values to propagate
        await sleep(50);
        
        this.update(true);
        
        // Trigger color update for all cells with the same DAC name
        this.trigger_selection_color_update();
    }

    set_visible(flag) {
        // console.log("set_visible of DACCell", this.dac_name, "to", flag)
        if (flag == true) {
            this.row.style.display = "table-row";
        }
        else {
            this.row.style.display = "none";
        }
    }

    update(configure = false) {
        //let ids = getRemainingSelection();
        let conf_on_change_bool = document.getElementById("checkboxConfOnChange").checked;
        if (conf_on_change_bool == true && configure == true) {
            configure_selected();
        }

        this.update_text_color(true);
    }

    async update_cell_id(id) {
        this._remove_odb_cell();
        this._create_odb_cell();

        this.set_odb_link(id);
    }

    update_remaining_ids(ids, slow) {
        this.remaining_ids = ids;
        this.update_text_color(slow);
    }

    //FIXME: the update_remaining_ids function is called before the odb link is set 
    async update_text_color(slow) {
        if (slow == true) {
            // console.log("slow update")
            await sleep(50); // Increased wait time for better stability
        }

        let a = this.cell_odb_value.querySelector("a");
        // console.log("a tag", a)

        let node = this.cell_odb_value.childNodes[0];
        if (node == undefined) {
            //console.log("node is undefined")
            return;
        }

        // console.log("Update text color:", this.dac_name, "from:", node.style.color)

        //console.log("cell", this.cell_odb_value, "text", this.cell_odb_value.childNodes.length);
        //this.cell_odb_value.childNodes[0].style.color = "blue"; 

        try {
            let value = await get_sensor_dac(this.dac_name, this.id, this.dac_class);
            
            // Get all currently selected sensors for proper color comparison
            let all_selected = getSelection();
            
            if (all_selected != -1 && all_selected != undefined && all_selected.length > 1) {
                //console.log("update colors for multiple selection")
                let all_conf_ids = getConfigIds(all_selected);
                let all_values = await get_sensors_dac(this.dac_name, all_conf_ids, this.dac_class);
        
                // Check if all values are identical
                let identical = true;
                let first_value = all_values[0];
                for (let i = 1; i < all_values.length; i++) {
                    if (first_value != all_values[i]) {
                        identical = false;
                        break;
                    }
                }
        
                if (identical == false) {
                    // Values differ among selection - RED
                    node.style.color = "red";
                }
                else if (first_value != this.std_value) {
                    // All values identical but differ from default - PURPLE (lila)
                    node.style.color = "purple";
                }
                else {
                    // All values identical and match default - BLUE
                    node.style.color = "blue";
                }
            }
            else {
                // Single sensor selected
                //console.log("single sensor selected", value, this.std_value)
                if (value != this.std_value) {
                    // Value differs from default - PURPLE (lila)
                    node.style.color = "purple";
                }
                else {
                    // Value matches default - BLUE
                    node.style.color = "blue";
                }
            }
        } catch (error) {
            console.error("Error updating text color for DAC", this.dac_name, ":", error);
            // Set to default color on error
            node.style.color = "black";
        }
        // console.log("to: ", node.style.color)
        // console.log(node)
    }

    /**
     * Trigger color update for all DAC cells with the same name across all categories
     * This ensures consistent coloring when a DAC value changes
     */
    trigger_selection_color_update() {
        // Find DAC manager and trigger update for all cells with same name
        if (typeof dacManager !== 'undefined' && dacManager.tables) {
            for (let table of dacManager.tables) {
                for (let category of table.categories) {
                    for (let cell of category.dac_cells) {
                        if (cell.dac_name === this.dac_name) {
                            setTimeout(() => cell.update_text_color(true), 100);
                        }
                    }
                    for (let cell of category.dac_cells_exp) {
                        if (cell.dac_name === this.dac_name) {
                            setTimeout(() => cell.update_text_color(true), 100);
                        }
                    }
                }
            }
        }
    }

    /**
     * Update the default value for this DAC cell
     */
    updateDefaultValue(newStdValue) {
        // Update the internal standard value
        this.std_value_sel = newStdValue;
        
        if (Array.isArray(newStdValue)) {
            this.std_value = newStdValue[0];
        } else {
            this.std_value = newStdValue;
        }
        
        // Update the displayed default value
        this.std_text.innerHTML = this.std_value;
        
        // Update dropdown options if this is a dropdown DAC
        if (Array.isArray(newStdValue) && this.odb_sel) {
            // Clear existing options
            this.odb_sel.innerHTML = "";
            
            // Add new options
            for (let i = 0; i < newStdValue.length; i++) {
                let option = document.createElement("option");
                option.classList.add("dac_select_option");
                option.value = newStdValue[i];
                if (this.description != undefined && this.description[i] != undefined) {
                    option.innerHTML = newStdValue[i] + " - " + this.description[i];
                } else {
                    option.innerHTML = newStdValue[i];
                }
                this.odb_sel.appendChild(option);
            }
        }
    }
}


// Create dacManager if it does not exist:
if (dacManager == undefined) {
    var dacManager = new DACManager();
} 