let allPlots = [];
let plotGroups = {};
let updateInterval = 2000; // milliseconds
let timeoutID = undefined;
let runNumbers = [0]; // Default to the current run. Zero means the current run.

// Create autoUpdater as a global variable
window.autoUpdater = new PlotAutoUpdater();
autoUpdater.runNumbers = runNumbers; // Initialize with the default run numbers

// Start the update loop for the histograms. They will be updated sequentially every
// `updateInterval` milliseconds.
function isPlotOptionEnabled(value) {
    return value === true || (typeof value === "string" && value.toLowerCase() === "true");
}

function applyPlotOptions(record, plotSource) {
    record.titleCell.textContent = plotSource.title || "";
    record.logXCheckbox.checked = isPlotOptionEnabled(plotSource.logX);
    record.logYCheckbox.checked = isPlotOptionEnabled(plotSource.logY);
    record.logZCheckbox.checked = isPlotOptionEnabled(plotSource.logZ);

    record.graph.param.xAxis.log = record.logXCheckbox.checked;
    record.graph.param.yAxis.log = record.logYCheckbox.checked;
    record.graph.param.zAxis.log = record.logZCheckbox.checked;
    record.graph.param.xAxis.title.text = plotSource.xTitle || "";
    record.graph.param.yAxis.title.text = plotSource.yTitle || "";
    record.graph.param.yAxis.min = plotSource.minY;
    record.graph.param.zAxis.min = plotSource.minZ;
    record.graph.param.overlay = plotSource.overlay;
}

function createPlotRecord(container, plotSource) {
    let table = document.createElement("table");
    table.style.display = "inline-block";

    let titleCell = table.insertRow().insertCell();
    titleCell.appendChild(document.createTextNode(plotSource.title || ""));

    let plotDiv = document.createElement("div");
    table.insertRow().insertCell().appendChild(plotDiv);

    let graph = new MPlotGraph(plotDiv);
    autoUpdater.addPlot(graph);

    let plotIndex = allPlots.length;
    let controlsCell = table.insertRow().insertCell();
    controlsCell.style.textAlign = "center";
    let controls = [];
    [["x", "Log x"], ["y", "Log y"], ["z", "Log z"]].forEach(function(axis) {
        let checkbox = document.createElement("input");
        checkbox.type = "checkbox";
        checkbox.id = `log${axis[0].toUpperCase()}Axis_${plotIndex}`;
        checkbox.dataset.plotIndex = plotIndex;
        checkbox.onchange = function() { onAxis(this.id, plotIndex); };
        controls.push(checkbox);
        controlsCell.appendChild(checkbox);
        controlsCell.appendChild(document.createTextNode(" " + axis[1] + " "));
    });

    container.appendChild(table);
    allPlots.push(graph);
    return {
        table: table,
        titleCell: titleCell,
        graph: graph,
        logXCheckbox: controls[0],
        logYCheckbox: controls[1],
        logZCheckbox: controls[2]
    };
}

window.dqmInit = function (divElementID, plotSources) {
    let container = document.getElementById(divElementID);
    if (!container) return;

    let records = plotGroups[divElementID] || [];
    let createdPlot = false;
    let sourceChanged = false;
    plotSources.forEach(function(plotSource, index) {
        let record = records[index];
        if (!record) {
            record = createPlotRecord(container, plotSource);
            records[index] = record;
            createdPlot = true;
        } else {
            record.table.hidden = false;
        }

        applyPlotOptions(record, plotSource);
        if (record.graph.dqmSource !== plotSource.source) {
            record.graph.dqmSource = plotSource.source;
            sourceChanged = true;
        }
    });

    records.slice(plotSources.length).forEach(function(record) {
        record.table.hidden = true;
        record.graph.dqmSource = undefined;
        autoUpdater.changeSource(record.graph, undefined);
    });
    plotGroups[divElementID] = records;

    if (createdPlot || sourceChanged) autoUpdater.refreshAll();
}

window.updateChannelPlots = function(objectId, channelName) {
    let container = document.getElementById("anaPlotsChannel");
    let placeholder = document.getElementById("anaPlotsChannelPlaceholder");
    let templates = window.channelPairPlotTemplates || [];
    let match = /^SIG_([XY])_(\d+)_([AB])$/.exec(channelName || "");

    if (!container || !match) {
        if (placeholder) {
            placeholder.hidden = false;
            placeholder.textContent = "Select a channel ending in _A or _B to display its pair plots.";
        }
        if (container) window.dqmInit("anaPlotsChannel", []);
        return;
    }

    let partnerSuffix = match[3] === "A" ? "B" : "A";
    let partnerName = "SIG_" + match[1] + "_" + match[2] + "_" + partnerSuffix;
    let channelA = match[3] === "A" ? channelMapping[objectId + ":" + channelName] :
        channelMapping[objectId + ":" + partnerName];
    let channelB = match[3] === "B" ? channelMapping[objectId + ":" + channelName] :
        channelMapping[objectId + ":" + partnerName];

    if (channelA === undefined || channelB === undefined) {
        if (placeholder) {
            placeholder.hidden = false;
            placeholder.textContent = "The selected channel has no matching _A/_B partner.";
        }
        window.dqmInit("anaPlotsChannel", []);
        return;
    }

    let channelPair = [
        {name: "SIG_" + match[1] + "_" + match[2] + "_A", number: channelA},
        {name: "SIG_" + match[1] + "_" + match[2] + "_B", number: channelB}
    ];
    let pairName = "SIG_" + match[1] + "_" + (parseInt(match[2], 10) - 1);
    let plotSources = [];

    function makePlot(template, source, title) {
        let plot = {source: source, title: title};
        ["xTitle", "yTitle", "logX", "logY", "logZ", "minY", "minZ", "overlay"].forEach(function(key) {
            if (Object.hasOwn(template, key)) plot[key] = template[key];
        });
        return plot;
    }

    templates.forEach(function(template) {
        if (template.perChannel) {
            channelPair.forEach(function(channel) {
                plotSources.push(makePlot(
                    template,
                    template.source.replace("{}", channel.number),
                    template.title.replace("{}", objectId).replace("{}", channel.name)
                ));
            });
        } else {
            plotSources.push(makePlot(
                template,
                template.source.replace("{}", pairName),
                template.title.replace("{}", pairName)
            ));
        }
    });

    if (placeholder) placeholder.hidden = true;
    window.dqmInit("anaPlotsChannel", plotSources);
};

window.initConfiguredPlots = function(config) {
    window.channelPairPlotTemplates = Array.isArray(config.channelPairPlots) ?
        config.channelPairPlots : [];
    let fixedPlots = Array.isArray(config.fixedPlots) ? config.fixedPlots : [];
    window.dqmInit("anaPlotsFixed", fixedPlots);
};


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
