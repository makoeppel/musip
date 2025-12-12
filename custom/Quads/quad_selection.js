var selection_canvas = document.getElementById('SensorSelectionCanvas');
var selection_cc = selection_canvas.getContext('2d');

var quad_active_selection_event = new CustomEvent('quad_active_selection_event');
var quad_selection_event = new CustomEvent('quad_selection_event');

// Drag and drop variables
var isDragging = false;
var dragSource = null;
var dragTarget = null;

if (typeof selected === 'undefined') {
    selected = new Array();
}

function getSensorStatus(feb, link){
    //console.log(feb + " " + link + ": " +  febs[feb].links[link].ready)
    let ready = febs[feb].links[link].ready;
    let disper1 = febs[feb].links[link].disperr;
    let disper2 = febs[feb].links[link+1].disperr;
    let disper3 = febs[feb].links[link+2].disperr;

    let A0 = febs[feb].links[link].A;
    let B0 = febs[feb].links[link].B;
    let C0 = febs[feb].links[link].C;
    let A1 = febs[feb].links[link+1].A;
    let B1 = febs[feb].links[link+1].B;
    let C1 = febs[feb].links[link+1].C;
    let A2 = febs[feb].links[link+2].A;
    let B2 = febs[feb].links[link+2].B;
    let C2 = febs[feb].links[link+2].C;

    return [ready, disper1, disper2, disper3, A0, B0, C0, A1, B1, C1, A2, B2, C2];
}

function areAllSelected(){
    if (selected.length == sensor_ids.flat().length){
        return true;
    }
    else {
        return false;
    }
}

function getSelection(){
    return selected;
}

function getActiveSelection(){
    if (selected.length == 0){
        return -1;
    }
    else {
        return selected[selected.length-1];
    }
}

function getRemainingSelection(){
    if (selected.length <= 1){
        return -1;
    }
    else {
        return selected.slice(0, -1);
    }
}


// DAC transfer functions moved to quad_actions.js

function getSensorFromCoordinates(x, y) {
    for (let i = 0; i < 4; i++) {
        for (let j = 0; j < 4; j++) {
            const sensor = selection_setup.Quads[i].Sensors[j];
            if (x >= sensor.x && x <= sensor.x + sensor.dx && 
                y >= sensor.y && y <= sensor.y + sensor.dy) {
                return sensor;
            }
        }
    }
    return null;
}

function SetupSel(){
    this.Quads = new Array(4);

    for(let i = 0; i < 4; i++) {
        this.Quads[i] = new QuadSel(5+i*180,5,155,175, i); 
    }

    this.draw = function(){
        //cc.fillStyle = "rgb(230,230,230)";
        //cc.fillRect(0, 0, canvas.width, canvas.height);

        for(let i = 0; i < 4; i++ ){   
            this.Quads[i].draw();
        }
    }
}

function QuadSel(x,y,dx,dy, num){
    this.x = x;
    this.y = y;
    this.dx= dx;
    this.dy= dy;
    this.num = num;

    this.xoffset = 10;
    this.yoffset = 30;

    this.Sensors = new Array(4);
    // create sensors for each quad module
    for (let i = 0; i < 4; i++){
        let id = getSensorId(this.num, i);
        let x = this.x + this.xoffset + alignment[i][0] * 70;
        let y = this.y + this.yoffset + alignment[i][1] * 70;
        this.Sensors[i] = new SensorSel(x, y, 65, 65, id);
    }

    this.draw = function(){
        selection_cc.fillStyle = "rgb(60,60,60)";
        selection_cc.fillRect(this.x, this.y,this.dx, this.dy);

        selection_cc.fillStyle = "white";
        selection_cc.font = "20px Arial";
        selection_cc.textAlign = "left";
        selection_cc.textBaseline = "top";
        selection_cc.fillText("Quad " + this.num, this.x + this.xoffset, this.y + 5);
        
        for(let i = 0; i < 4; i++){
            this.Sensors[i].update(this.num, i);
            this.Sensors[i].draw();
        }
    }
}

function SensorSel(x,y,dx,dy, id){
    this.x = x;
    this.y = y;
    this.dx= dx;
    this.dy= dy;
    this.id = id;
    this.conf_id = getConfigIds(id);
    this.data_id = getDataIds(id);
    this.active = false;

    this.ready = 0;

    this.a0 = 0;
    this.b0 = 0;
    this.c0 = 0;
    this.a1 = 0;
    this.b1 = 0;
    this.c1 = 0;
    this.a2 = 0;
    this.b2 = 0;
    this.c2 = 0;

    this.disper1 = 0;
    this.disper1_last = 0;
    this.disper2 = 0;
    this.disper2_last = 0;
    this.disper3 = 0;
    this.disper3_last = 0;

    this.errors = 0;
    this.lastTransferTime = null;

    this.draw = function(){
        //console.log("draw sensor" + this.id, febs)
        if (this.active){
            selection_cc.fillStyle = "grey";
        } else {
            selection_cc.fillStyle = "rgb(190,190,190)";
        }
        
        // Highlight drag source and target during drag operation
        if (isDragging && dragSource && dragSource.id === this.id) {
            selection_cc.fillStyle = "rgb(100, 150, 255)"; // Blue for source
        } else if (isDragging && dragTarget) {
            // If dragTarget is in the selected array, highlight all selected sensors as targets
            if (selected.includes(dragTarget.id) && selected.includes(this.id)) {
                selection_cc.fillStyle = "rgb(255, 150, 100)"; // Orange for all selected targets
            } else if (dragTarget.id === this.id) {
                selection_cc.fillStyle = "rgb(255, 150, 100)"; // Orange for single target
            }
        }
        
        // create sensor rectangle
        selection_cc.fillRect(this.x, this.y,this.dx, this.dy);

        // create ID text
        selection_cc.fillStyle = "white";
        selection_cc.font = "15px Arial";
        selection_cc.textAlign = "center";
        selection_cc.textBaseline = "middle";
        let centerX = this.x + this.dx/2 - 10;window.dispatchEvent(quad_active_selection_event);
        let centerY = this.y + this.dy/2 + 20;

        //TODO: add text for config id
        let text = "ID: " + this.id;
        let link0 = "A: " + this.a0 + " B: " + this.b0 + " C: " + this.c0;
        let link1 = "A: " + this.a1 + " B: " + this.b1 + " C: " + this.c1;
        let link2 = "A: " + this.a2 + " B: " + this.b2 + " C: " + this.c2;

        selection_cc.fillText(text, centerX, centerY);
        selection_cc.fillText(link0, centerX, centerY - 45, 40);
        selection_cc.fillText(link1, centerX, centerY - 30, 40);
        selection_cc.fillText(link2, centerX, centerY - 15, 40);

        // create ready and error indicators
        let color = "red"
        if (this.ready){
            color = "yellow";
            if (this.errors == 0){
                color = "green";
            }
            else if ( this.errors > 5000 ){
                color = "orange";
            }
        }

        selection_cc.fillStyle = color;
        selection_cc.beginPath();
        selection_cc.arc(this.x + this.dx - 10, this.y + 10, 5, 0, 2 * Math.PI);
        selection_cc.fill();

        // console.log("errors in drawing: " + this.errors)
        // quad_cc.fillStyle = this.errors ? "red" : "green";
        // quad_cc.beginPath();
        // quad_cc.arc(this.x + this.dx - 10, this.y + 25, 5, 0, 2 * Math.PI);
        // quad_cc.fill();

        // ad a border to the active sensor:
        if (this.id == getActiveSelection()){
            selection_cc.strokeStyle = "white";
            selection_cc.lineWidth = 3;
            selection_cc.strokeRect(this.x, this.y,this.dx, this.dy);
        }
        
        // Show recent DAC transfer indicator
        if (this.lastTransferTime && (Date.now() - this.lastTransferTime) < 3000) {
            selection_cc.fillStyle = "rgba(0, 255, 0, 0.3)"; // Green overlay
            selection_cc.fillRect(this.x, this.y, this.dx, this.dy);
            
            // Add transfer arrow or text
            selection_cc.fillStyle = "green";
            selection_cc.font = "12px Arial";
            selection_cc.textAlign = "center";
            selection_cc.fillText("✓ DACs", this.x + this.dx/2, this.y + this.dy - 5);
        }
    }

    this.update = function(module, sensor){
        let [feb, link] = getFEBLink(module, sensor);
        [this.ready, this.disper1, this.disper2, this.disper3, this.a0, this.b0, this.c0, this.a1, this.b1, this.c1, this.a2, this.b2, this.c2] = getSensorStatus(feb, link);

        this.errors = Math.abs(this.disper1_last - this.disper1 + this.disper2_last - this.disper2 + this.disper3_last - this.disper3);
        this.disper1_last = this.disper1;
        this.disper2_last = this.disper2;
        this.disper3_last = this.disper3;
    }
}



//only create SetupSel if it does not exist yet
if (typeof selection_setup === 'undefined') {
    var selection_setup = new SetupSel();
}

function selection_draw() {
    // Clear the entire canvas before redrawing
    if (selection_canvas && selection_cc) {
        selection_cc.clearRect(0, 0, selection_canvas.width, selection_canvas.height);
    }
    
    // TODO: do I need this?
    //selection_canvas = document.getElementById('SensorSelectionCanvas');
    //selection_cc = selection_canvas.getContext('2d');
    selection_setup.draw();
    
    // Draw drag line if dragging
    if (isDragging && dragSource && selection_cc) {
        selection_cc.strokeStyle = "white";
        selection_cc.lineWidth = 2;
        selection_cc.setLineDash([5, 5]); // Dashed line
        selection_cc.beginPath();
        selection_cc.moveTo(dragSource.x + dragSource.dx/2, dragSource.y + dragSource.dy/2);
        selection_cc.lineTo(mouse.x, mouse.y);
        selection_cc.stroke();
        selection_cc.setLineDash([]); // Reset to solid line
    }
    
    // add an event to activate functions in ofher scripts
}

selection_draw();


var mouse = {
    x: undefined,
    y: undefined
}

// Mouse event handlers for drag and drop
let isDragMode = false;

function updateCursor(event) {
    const sensor = getSensorFromCoordinates(mouse.x, mouse.y);
    selection_canvas.style.cursor = isDragging ? 'grabbing' : 
                                   event.altKey && sensor ? 'grab' : 'default';
}

window.addEventListener('mousedown', function(event) {
    if (event.button !== 0 || !event.altKey) return;
    
    const rect = selection_canvas.getBoundingClientRect();
    mouse.x = event.clientX - rect.left;
    mouse.y = event.clientY - rect.top;
    
    const sensor = getSensorFromCoordinates(mouse.x, mouse.y);
    if (sensor) {
        isDragging = true;
        dragSource = sensor;
        updateCursor(event);
        event.preventDefault();
        selection_draw();
    }
});

window.addEventListener('mousemove', function(event) {
    const rect = selection_canvas.getBoundingClientRect();
    mouse.x = event.clientX - rect.left;
    mouse.y = event.clientY - rect.top;
    
    if (isDragging) {
        const newTarget = getSensorFromCoordinates(mouse.x, mouse.y);
        if (newTarget !== dragTarget) {
            dragTarget = newTarget;
            selection_draw();
        }
    } else {
        updateCursor(event);
    }
});

['keydown', 'keyup'].forEach(event => {
    window.addEventListener(event, updateCursor);
});

window.addEventListener('click', function(event) {
    // Skip click handling if we just finished a drag operation
    if (event.altKey) return;
    
    let rect = selection_canvas.getBoundingClientRect();

    mouse.x = event.clientX -rect.left;
    mouse.y = event.clientY -rect.top;

    let found = false;
    let old_active = undefined;

    // toggle sensors between active and unactive if clicked:
    for(let i = 0; i < 4; i++){
        for(let j = 0; j < 4; j++){
            if (mouse.x > selection_setup.Quads[i].Sensors[j].x && mouse.x < selection_setup.Quads[i].Sensors[j].x + selection_setup.Quads[i].Sensors[j].dx && mouse.y > selection_setup.Quads[i].Sensors[j].y && mouse.y < selection_setup.Quads[i].Sensors[j].y + selection_setup.Quads[i].Sensors[j].dy){
                selection_setup.Quads[i].Sensors[j].active = !selection_setup.Quads[i].Sensors[j].active;
                found = true;

                old_active = getActiveSelection();
                
                if (selection_setup.Quads[i].Sensors[j].active){
                    if (event.ctrlKey) {
                        selected.splice(0, 0, selection_setup.Quads[i].Sensors[j].id);
                    }
                    else {
                        selected.push(selection_setup.Quads[i].Sensors[j].id);
                    }
                }
                else{
                    selected.splice(selected.indexOf(selection_setup.Quads[i].Sensors[j].id), 1);
                }

                if (getActiveSelection() != old_active){
                    // activate event quad_selection_changed
                    window.dispatchEvent(quad_active_selection_event);
                }
                
                window.dispatchEvent(quad_selection_event);

                displaySelected()

                selection_draw();
            }
        }
        
        if (found == false && (mouse.x > selection_setup.Quads[i].x && mouse.x < selection_setup.Quads[i].x + selection_setup.Quads[i].dx && mouse.y > selection_setup.Quads[i].y && mouse.y < selection_setup.Quads[i].y + selection_setup.Quads[i].dy)){
            // check if not all of the Sensors in this Quad are activated. In this case activate all. In the other case decativate all.
            let noneActive = true;
            old_active = getActiveSelection();

            for(let k = 0; k < 4; k++){
                if (selection_setup.Quads[i].Sensors[k].active){
                    noneActive = false;
                    break;
                }
            }
            for(let k = 3; k >= 0; k--){
                if (noneActive == true){
                    if (event.ctrlKey) {
                        selected.splice(3-k, 0, selection_setup.Quads[i].Sensors[k].id);
                    }
                    else {
                        selected.push(selection_setup.Quads[i].Sensors[k].id);
                    }
                    // NOTE: this sould get the last seletion mixed up.
                    //selected.sort(function(a, b){return a-b});
                }
                else if (selection_setup.Quads[i].Sensors[k].active){
                    selected.splice(selected.indexOf(selection_setup.Quads[i].Sensors[k].id), 1);
                }
                selection_setup.Quads[i].Sensors[k].active = noneActive;
            }
            
            if (getActiveSelection() != old_active){
                // activate event quad_selection_changed
                window.dispatchEvent(quad_active_selection_event);
            }

            window.dispatchEvent(quad_selection_event);

            displaySelected()
    
            selection_draw();
        }
    }
});

function displaySelected(){
    if (typeof selected === 'undefined') {
        selected = new Array();
    }

    if (selected.length == 0){
        document.getElementById("sensor_selection").innerHTML = "None";
        document.getElementById("active_selection").innerHTML = "None";
    }
    else {        
        let sorted = sort_array(selected)
        document.getElementById("sensor_selection").innerHTML = sorted.join(", ");
        document.getElementById("active_selection").innerHTML = getActiveSelection();
    }   
}

function selectAll() {
    selected = new Array();
    for(let i = 0; i < 4; i++){
        for(let j = 0; j < 4; j++){
            selection_setup.Quads[i].Sensors[j].active = true;
            selected.splice(0, 0, selection_setup.Quads[i].Sensors[j].id);
        }
    }
    displaySelected();
    selection_draw();
    window.dispatchEvent(quad_selection_event);
}

function deselectAll() {
    selected = new Array();
    for(let i = 0; i < 4; i++){
        for(let j = 0; j < 4; j++){
            selection_setup.Quads[i].Sensors[j].active = false;
        }
    }
    displaySelected();
    selection_draw();
    window.dispatchEvent(quad_selection_event);
}

// Periodic refresh to clear transfer indicators
setInterval(() => {
    const now = Date.now();
    let needsRedraw = false;
    
    selection_setup.Quads.forEach(quad => {
        quad.Sensors.forEach(sensor => {
            if (sensor.lastTransferTime && (now - sensor.lastTransferTime) >= 3000) {
                sensor.lastTransferTime = null;
                needsRedraw = true;
            }
        });
    });
    
    if (needsRedraw) selection_draw();
}, 500);