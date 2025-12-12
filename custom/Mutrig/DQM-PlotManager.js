let allPlots = [];
let updateInterval = 2000; // milliseconds
let timeoutID = undefined;
let runNumbers = [0]; // Default to the current run. Zero means the current run.

// Create autoUpdater as a global variable
window.autoUpdater = new PlotAutoUpdater();
autoUpdater.runNumbers = runNumbers; // Initialize with the default run numbers

// Start the update loop for the histograms. They will be updated sequentially every
// `updateInterval` milliseconds.
window.dqmInit = function (divElementID, globalPlotSources){
    let divElement = document.getElementById(divElementID);
    console.log("Initializing DQM plots in div:", divElement, "with sources:", globalPlotSources);
    //let globalPlotSources = [
    //    {source: "tile/Zphi_TileHitmap_DS", title: "hitmap DS", xTitle: "z" , yTitle: "phi", logZ: "true", minZ: "0.1"},
    //];

    for(let plotIndex = 0; plotIndex < globalPlotSources.length; plotIndex++) {
        let plotSource = globalPlotSources[plotIndex];
        let table = document.createElement("table");
        table.style.display = "inline-block";

        let titleCell = table.insertRow().insertCell();
        titleCell.appendChild(document.createTextNode(plotSource.title));
        // }

        let plotDiv = document.createElement("div");
        table.insertRow().insertCell().appendChild(plotDiv);

        let mPlotGraph = new MPlotGraph(plotDiv);

        // Add this line to register with autoUpdater
        autoUpdater.addPlot(mPlotGraph);

        // Add log controls for this specific plot
        let controlsRow = table.insertRow();
        let controlsCell = controlsRow.insertCell();
        controlsCell.style.textAlign = "center";

        // Create unique IDs for each checkbox using the plot index
        let logXId = `logXAxis_${plotIndex}`;
        let logYId = `logYAxis_${plotIndex}`;
        let logZId = `logZAxis_${plotIndex}`;

        // Create the checkboxes with event handlers
        let logXCheckbox = document.createElement("input");
        logXCheckbox.type = "checkbox";
        logXCheckbox.id = logXId;
        logXCheckbox.dataset.plotIndex = plotIndex; // Store the plot index as data attribute
        logXCheckbox.onchange = function() { onAxis(this.id, plotIndex); };

        let logYCheckbox = document.createElement("input");
        logYCheckbox.type = "checkbox";
        logYCheckbox.id = logYId;
        logYCheckbox.dataset.plotIndex = plotIndex;
        logYCheckbox.onchange = function() { onAxis(this.id, plotIndex); };

        let logZCheckbox = document.createElement("input");
        logZCheckbox.type = "checkbox";
        logZCheckbox.id = logZId;
        logZCheckbox.dataset.plotIndex = plotIndex;
        logZCheckbox.onchange = function() { onAxis(this.id, plotIndex); };

        // Set initial checkbox states based on plot configuration
        if(Object.hasOwn(plotSource, "logX")) {
            logXCheckbox.checked = true;
            mPlotGraph.param.xAxis.log = true;
        }
        if(Object.hasOwn(plotSource, "logY")) {
            logYCheckbox.checked = true;
            mPlotGraph.param.yAxis.log = true;
        }
        if(Object.hasOwn(plotSource, "logZ")) {
            logZCheckbox.checked = true;
            mPlotGraph.param.zAxis.log = true;
        }

        // Add checkboxes and labels to the controls cell
        controlsCell.appendChild(logXCheckbox);
        controlsCell.appendChild(document.createTextNode(" Log x "));

        controlsCell.appendChild(logYCheckbox);
        controlsCell.appendChild(document.createTextNode(" Log y "));

        controlsCell.appendChild(logZCheckbox);
        controlsCell.appendChild(document.createTextNode(" Log z "));

        divElement.appendChild(table);

        // record on the plot itself where the data comes from, so that we can update it again at
        // set time intervals.
        mPlotGraph.dqmSource = plotSource.source;

        if(Object.hasOwn(plotSource, "overlay")) mPlotGraph.param.overlay = plotSource.overlay;
        if(Object.hasOwn(plotSource, "xTitle")) {
            mPlotGraph.param.xAxis.title.text = plotSource.xTitle;
//                    mPlotGraph.param.xAxis.title.textSize /= 2;
        }
        if(Object.hasOwn(plotSource, "yTitle")) {
            mPlotGraph.param.yAxis.title.text = plotSource.yTitle;
//                    mPlotGraph.param.yAxis.title.textSize /= 2;
        }
        if(Object.hasOwn(plotSource, "logX")) {
            mPlotGraph.param.xAxis.log = true;
        }
        if(Object.hasOwn(plotSource, "logY")) {
            mPlotGraph.param.yAxis.log = true;
        }
        if(Object.hasOwn(plotSource, "logZ")) {
            mPlotGraph.param.zAxis.log = true;
        }
        if(Object.hasOwn(plotSource, "minY")) {
            mPlotGraph.param.yAxis.min = plotSource.minY;
        }
        if(Object.hasOwn(plotSource, "minZ")) {
            mPlotGraph.param.zAxis.min = plotSource.minZ;
        }

        allPlots[allPlots.length] = mPlotGraph;
    }

    // Comment out or remove this line
    // updateHistograms();
    autoUpdater.refreshAll();
}


// Replace the current setRunNumbers implementation with this one:
if (!autoUpdater.setRunNumbers) {
    autoUpdater.setRunNumbers = function(runs) {
        // Store the run numbers
        this.runNumbers = runs;

        // Use allPlots array instead of trying to access this.plots
        // since allPlots contains all the plots we've created
        for (let i = 0; i < allPlots.length; i++) {
            let plot = allPlots[i];
            if (plot.dqmSource) {
                // Get current DQM program
                let dqmProg = "ana";
                let dqmProgSelector = document.getElementById("dqmProg");
                if (dqmProgSelector) dqmProg = dqmProgSelector.value;

                // Use changeSource with loadFile:true to force loading the run file
                this.changeSource(plot, {
                    name: plot.dqmSource,
                    runs: runs,
                    dqmProg: dqmProg,
                    loadFile: true
                }, true);
            }
        }
    };
}


window.onChangeRun = function() {
    let textBox = document.getElementById("runNumbers");
    let newValue = parseInt(textBox.value);
    if(isNaN(newValue)) {
        textBox.value = runNumbers[0];
    }
    else {
        // Update global runNumbers
        runNumbers = [newValue];
        textBox.value = newValue;

        console.log("Changing to run:", newValue);

        // Call the setRunNumbers function which will update all plots
        autoUpdater.setRunNumbers(runNumbers);
    }
}

window.onDQMProgChanged = function() {
    let selector = document.getElementById("dqmProg");
    autoUpdater.setDefaultDQMProg(selector.value);

    // Refresh all plots with the new DQM program
    autoUpdater.refreshAll();
}

window.onClearAll = function() {
    console.log("Clearing all histograms");
    clearHistograms("mutrig").then(
        (unusedResult) => {
            // Perform a refresh to plot the empty histogram (and any data created since the refresh returned).
            autoUpdater.refreshAll();
        }
    );
}

window.onAxis = function(id, plotIndex) {
    let checkbox = document.getElementById(id);
    let mPlotGraph = allPlots[plotIndex];

    if(id.startsWith('logXAxis')) mPlotGraph.param.xAxis.log = checkbox.checked;
    else if(id.startsWith('logYAxis')) mPlotGraph.param.yAxis.log = checkbox.checked;
    else if(id.startsWith('logZAxis')) mPlotGraph.param.zAxis.log = checkbox.checked;

    mPlotGraph.draw();
}

window.onAutoRefreshClicked = function() {
    const isEnabled = document.getElementById('autoRefresh').checked;
    if(isEnabled) {
        // Disable the manual refresh button
        document.getElementById('refresh').disabled = true;
        // Update immediately, then every 2000 milliseconds
        autoUpdater.start(2000);
    }
    else {
        // Enable the manual refresh button
        document.getElementById('refresh').disabled = false;
        // Setting to zero disables auto updates
        autoUpdater.updateInterval = 0;
    }
}

window.onRefreshClicked = function() {
    // Manually refresh all plots
    autoUpdater.refreshAll();
}
