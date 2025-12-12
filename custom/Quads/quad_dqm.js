
// DQM stuff
let runNumbers = [0];
let autoUpdater = new PlotAutoUpdater();
var clicked_x = 0;
var clicked_y = 0;
var clicked_chip = 0;
let hitmapPlot;
let hitToTPlot;
let timestampLocalPlot;
let timestampPrev;
let timeofarrival;

window.onClearAll = function() {
    clearHistograms("quad").then(
        (unusedResult) => {
            // Perform a refresh to plot the empty histogram (and any data created since the refresh returned).
            autoUpdater.refreshAll();
        }
    );
}

function get_selected_chip(id) {
    autoUpdater.changeSource(hitmapPlot, `quad/hitmap_000${String(id).padStart(2,'0')}`, true);
    autoUpdater.changeSource(hitToTPlot, `quad/hitToT_000${String(id).padStart(2,'0')}`, true);
    autoUpdater.changeSource(timestampLocalPlot, `quad/hitTime_000${String(id).padStart(2,'0')}`, true);
    autoUpdater.changeSource(timestampPrev, `quad/hitTimeInterval_perChip_000${String(id).padStart(2,'0')}`, true);
    autoUpdater.changeSource(timeofarrival, `quad/hitToA_000${String(id).padStart(2,'0')}`, true);
}

function click_on_histo(event, plot, layer) {
    clicked_x = Math.floor(plot.screenToX(event.offsetX));
    clicked_y = Math.floor(plot.screenToY(event.offsetY));

    if (clicked_x < 256 && clicked_y >= 250) {
        clicked_chip = 1 + 4 * layer;
    }

    if (clicked_x >= 256 && clicked_y >= 250) {
        clicked_chip = 0 + 4 * layer;
    }

    if (clicked_x < 256 && clicked_y < 250) {
        clicked_chip = 3 + 4 * layer;
    }

    if (clicked_x >= 256 && clicked_y < 250) {
        clicked_chip = 2 + 4 * layer;
    }

    get_selected_chip(clicked_chip);
}

window.tooltipText = function(plotGraph) {
    let xText, yText;
    if(typeof plotGraph.xAxisText === 'function') xText = plotGraph.xAxisText(plotGraph.marker.x);
    else xText = plotGraph.marker.x.toPrecision(6).stripZeros(); // What Midas does by default

    if(typeof plotGraph.yAxisText === 'function') yText = plotGraph.yAxisText(plotGraph.marker.y);
    else yText = plotGraph.marker.y.toPrecision(6).stripZeros(); // What Midas does by default

    let fullText = xText + " / " + yText;

    // If it's a 2D plot, add the bin content the same way Midas does.
    if (plotGraph.param.plot[0].type === "colormap")
        fullText += ": " + (plotGraph.marker.z === null ? "null" : plotGraph.marker.z.toPrecision(6).stripZeros());

    return fullText;
}

window.dqmInit = function() {
    let divElement = document.getElementById("globalPlotsOld");

    let globalPlotSources = [
        {source: "quad/combined_hitmap_00000_00001_00002_00003", title: "Layer 0 (Sensor 0 - 3)", xTitle: "Combined Column", yTitle: "Combined Row", logZ: true, layer: 0, minZ: "0.1"},
        {source: "quad/combined_hitmap_00004_00005_00006_00007", title: "Layer 1 (Sensor 4 - 7)", xTitle: "Combined Column", yTitle: "Combined Row", logZ: true, layer: 1, minZ: "0.1"},
        {source: "quad/combined_hitmap_00008_00009_00010_00011", title: "Layer 2 (Sensor 8 - 11)", xTitle: "Combined Column", yTitle: "Combined Row", logZ: true, layer: 2, minZ: "0.1"},
        {source: "quad/combined_hitmap_00012_00013_00014_00015", title: "Layer 3 (Sensor 12 - 15)", xTitle: "Combined Column", yTitle: "Combined Row", logZ: true, layer: 3, minZ: "0.1"},
    ];

    const createPlot = (parentDiv, source, title, xTitle, yTitle, logZ) => {
        let table = document.createElement("table");
        table.style.display = "inline-block";

        let titleRow = table.insertRow();

        let titleCell;
        if(title !== undefined) {
            titleCell = titleRow.insertCell();
            titleCell.appendChild(document.createTextNode(title));
        }

        let plotDiv = document.createElement("div");
        let plotCell = table.insertRow().insertCell();
        plotCell.colSpan = 2; // So that it covers the whole row, both the title and the log checkbox (if there is one)
        plotCell.appendChild(plotDiv);

        let mPlotGraph = new MPlotGraph(plotDiv);
        mPlotGraph.param.plot[0].bgcolor = "white";
        // Set custom tooltip text when the mouse is over the data area.
        // The function we're setting looks for a function xAxisText or yAxisText and
        // uses that if it's there. Otherwise it does the same as the Midas default.
        // This only works with Midas after about 2025-04-25 (commit 0x5e5473e)
        mPlotGraph.parentDiv.dataset.tooltip = "tooltipText";

        // Store reference to titleCell in case we need to change it later
        if(titleCell !== undefined) mPlotGraph.titleCell = titleCell;

        parentDiv.appendChild(table);

        if(xTitle !== undefined) {
            mPlotGraph.param.xAxis.title.text = xTitle;
            mPlotGraph.param.xAxis.title.textSize /= 2;
        }
        if(yTitle !== undefined) {
            mPlotGraph.param.yAxis.title.text = yTitle;
            mPlotGraph.param.yAxis.title.textSize /= 2;
        }
        if(logZ !== undefined) {
            // Midas sets the scale minimum really low for log plots, and this makes the scale
            // saturate for the ranges we're actually interested in. So we want to force the
            // minimum to a sensible value after each update. To do this we create a callback
            // function that PlotAutoUpdater will call when the plot has been updated.
            mPlotGraph.onUpdateComplete = () => {
                if(mPlotGraph.param.zAxis.log) mPlotGraph.zMin = 0.9;
                else mPlotGraph.zMin = 0.0;
            }

            if(logZ !== undefined) mPlotGraph.param.zAxis.log = logZ;
        }

        autoUpdater.addPlot(mPlotGraph, source);

        return mPlotGraph;
    };

    let counter = 0;
    for(let plotSource of globalPlotSources) {

        let mPlotGraph = createPlot(divElement, plotSource["source"], plotSource["title"], plotSource["xTitle"], plotSource["yTitle"], plotSource["logZ"])

        if (counter == 3) {
            // Add a line break after every 4 plots
            divElement.appendChild(document.createElement("br"));
            counter = 0;
        } else {
            counter++;
            // Add a space between plots
            divElement.appendChild(document.createTextNode(" "));
        }

        if (plotSource["source"] == "quad/combined_hitmap_00000_00001_00002_00003") {
            mPlotGraph.canvas.onclick = function(event) {
                click_on_histo(event, mPlotGraph, 0)
            }
        }

        if (plotSource["source"] == "quad/combined_hitmap_00004_00005_00006_00007") {
            mPlotGraph.canvas.onclick = function(event) {
                click_on_histo(event, mPlotGraph, 1)
            }
        }

        if (plotSource["source"] == "quad/combined_hitmap_00008_00009_00010_00011") {
            mPlotGraph.canvas.onclick = function(event) {
                click_on_histo(event, mPlotGraph, 2)
            }
        }

        if (plotSource["source"] == "quad/combined_hitmap_00012_00013_00014_00015") {
            mPlotGraph.canvas.onclick = function(event) {
                click_on_histo(event, mPlotGraph, 3)
            }
        }
    }

    hitmapPlot = createPlot(divElement, undefined, "Hitmap", "Column", "Row", true);
    timestampLocalPlot = createPlot(divElement, undefined, "Local timestamp (mod 2048)", "Timestamp");
    hitToTPlot = createPlot(divElement, undefined, "ToT", "ToT");
    timestampPrev = createPlot(divElement, undefined, "Hit time minus prev. hit time", "Timestamp");
    timeofarrival = createPlot(divElement, undefined, "Time of arrival (ToA)", "Timestamp");
    get_selected_chip(0);

    // This starts updating all histograms and sets a timer to repeat every 2000 milliseconds
    autoUpdater.start(2000);
}

window.onChangeRun = function() {
    let textBox = document.getElementById("runNumbers");
    let newValue = parseInt(textBox.value);
    if(isNaN(newValue)) {
        // Couldn't convert to an integer, so set the text back to what it was
        textBox.value = runNumbers[0];
    }
    else {
        runNumbers = [newValue];
        textBox.value = newValue;
        autoUpdater.setDefaultRunNumbers(runNumbers);
        autoUpdater.refreshAll();
    }
}
