//var masking_canvas = document.getElementById('MaskingCanvas');
//var masking_cc = masking_canvas.getContext('2d');

function SetupGeneral(name, drawFunction){
    console.log("SetupGeneral: " + name);
    this.name = name
    this.container = document.createElement(`div`);
    this.container.classList.add(`general_setup`);

    document.getElementById(this.name + 'Table').appendChild(this.container);

    this.Quads = new Array(4);

    for (var i = 0; i < 4; i++){
        this.Quads[i] = new QuadGeneral(i, name, drawFunction);

        this.container.appendChild(this.Quads[i].container)
    }

    this.draw = function(){
        for(var i = 0; i < 4; i++ ){   
            this.Quads[i].draw();
        }
    }
}

function QuadGeneral(num, name, drawFunction){
    console.log("QuadGeneral: " + name);
    this.num = num;
    this.name = name.toLowerCase();

    this.container = document.createElement(`div`);
    this.container.classList.add(`general_quad`);

    this.title = document.createElement(`div`);
    this.container.appendChild(this.title);
    this.title.classList.add(`general_quad_title`);
    this.title.innerHTML = `Quad ${this.num}`;
    

    this.Sensors = new Array(4);

    for (var i = 0; i < 4; i++){
        let id = getSensorId(this.num, i);
        this.Sensors[i] = new SensorGeneral(id, this.name, drawFunction);

        this.container.appendChild(this.Sensors[i].container);
    }

    this.draw = function(){

        for(var i = 0; i < 4; i++){
            this.Sensors[i].draw();
        }
    }
}

function SensorGeneral(id, name, drawFunction){
    //console.log("SensorGeneral: " + name);
    this.id = id;
    this.name = name.toLowerCase();

    this.histogram = new HistogramGeneral(0, 0, 256, 256, id, this.name, drawFunction);

    this.container = document.createElement(`div`);
    this.container.classList.add(`general_sensor`);

    this.title = document.createElement(`div`);
    this.container.appendChild(this.title);
    this.title.classList.add(`general_sensor_title`);
    this.title.innerHTML = `Sensor ${this.id}`;


    this.container.appendChild(this.histogram.canvas); 

    this.draw = function(){
        this.histogram.draw();
    }
}

function HistogramGeneral(x, y, dx, dy, id, name, drawFunction) {
    //console.log("HistogramGeneral: " + name);
    this.x = x;
    this.y = y;
    this.dx= dx;
    this.dy= dy;
    this.id = id;
    this.name = name.toLowerCase();

    this.canvas = document.createElement(`canvas`);
    this.canvas.id = this.name + `_histogram_${id}`;
    this.canvas.classList.add(`general_histogram`); 

    this.canvas.width = this.dx;
    this.canvas.height = this.dy;
    //this.canvas.style.position = 'absolute';
    this.canvas.style.left = this.x + 'px';
    this.canvas.style.top = this.y + 'px';

    this.cc = this.canvas.getContext('2d');

    /**
     * create histogram for masking file
     * 
     * @param {number} id Sensor ID
     */ 
    async function drawGeneralHistogram(){

        drawFunction.call(this);
        
    }

    this.draw = function() {
        this.cc.fillStyle = "lightgrey";
        this.cc.fillRect(this.x, this.y, this.dx, this.dy);

        drawGeneralHistogram.call(this);
        console.log("draw " + this.name + " histogram");
    }
}

