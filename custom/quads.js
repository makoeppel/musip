const nFEBs = 2;
const nGirdPerFEB = 2;
const nASICPerGrid = 4;
const nASICsPerFEB = 8;
const nLinksPerASIC = 3;
const cells = [];
const selectedCells = new Set();


// Simulate 3 links per grid cell
function getColor(link) {
    const errors = link.disperr + link.err;
    if (link.ready) {
        if (errors === 0) return "green";
        if (errors > 5000) return "orange";
        return "yellow";
    }
    return "red";
}

function updateSelectedDisplay() {
    document.getElementById("selectedDisplay").textContent = 
        Array.from(selectedCells).sort((a, b) => a - b).join(", ");
}

function renderGrid(gridId, data, febID, gridID) {
    const grid = document.getElementById(gridId);
    grid.innerHTML = '';

    data[febID][gridID].forEach((cellLinks, index) => {
        const cell = document.createElement('div');
        cell.className = 'cell';
        if (selectedCells.has(index+gridID*nASICPerGrid+febID*nASICsPerFEB)) cell.classList.add('selected');

        // Build the 3 sections
        cellLinks.forEach(link => {
            const section = document.createElement('div');
            section.className = `section ${getColor(link)}`;
            cell.appendChild(section);
        });

        // Add click handler for selection
        cell.addEventListener('click', () => {
            if (selectedCells.has(index+gridID*nASICPerGrid+febID*nASICsPerFEB)) {
                selectedCells.delete(index+gridID*nASICPerGrid+febID*nASICsPerFEB);
                cell.classList.remove('selected');
            } else {
                selectedCells.add(index+gridID*nASICPerGrid+febID*nASICsPerFEB);
                cell.classList.add('selected');
            }
            updateSelectedDisplay();
        });

        grid.appendChild(cell);
    });
}

function update_pcls(input) {
    const data = (typeof input === 'string') ? JSON.parse(input) : input;
    let offset = 0;

    while (offset < data.length) {
        const febIndex = parseInt(data[offset]);
        const nLinks = parseInt(data[offset + 1]);

        if (febIndex >= nFEBs) break;

        for (let l = 0; l < nLinks; l++) {

            if (l >= nASICsPerFEB * nLinksPerASIC) break;

            const baseIndex = offset + 2 + 4 * l;
            const status = data[baseIndex];
            const disperr = data[baseIndex + 1];
            const err = data[baseIndex + 2];

            const asic = parseInt(l / 3);
            const grid_asic = parseInt(l / 3) % 4;
            const grid = parseInt(asic / 4);
            const link = parseInt(l % 3);

            cells[febIndex][grid][grid_asic][link].locked = (status & (1 << 31)) ? 1 : 0;
            cells[febIndex][grid][grid_asic][link].ready = (status & (1 << 30)) ? 1 : 0;
            cells[febIndex][grid][grid_asic][link].disperr = disperr;
            cells[febIndex][grid][grid_asic][link].err = err;
        }

        offset += 2 + nLinks * 4;
    }
    renderGrid("grid0", cells, 0, 0);
    renderGrid("grid1", cells, 0, 1);
    renderGrid("grid2", cells, 1, 0);
    renderGrid("grid3", cells, 1, 1);
}


function init() {
    for (let i = 0; i < nFEBs; i++) {
        let cur_feb = [];
        for (let j = 0; j < nGirdPerFEB; j++) {
            let cur_grid = [];
            for (let k = 0; k < nASICPerGrid; k++) {
                let cur_asic = [];
                for (let l = 0; l < nLinksPerASIC; l++) {
                    cur_asic.push({locked: 1, ready: 1, disperr: 0, err: 0});
                }
            cur_grid.push(cur_asic);
            }
        cur_feb.push(cur_grid);
        }
        cells.push(cur_feb);
    }

    mjsonrpc_db_get_values(["/Equipment/Quads Config/Variables/PCLS"]).then(function(rpc) {
        if(rpc.result.data[0]){
            update_pcls(rpc.result.data[0]);
        }
    }).catch(function(error) {
        mjsonrpc_error_alert(error);
    });

    // mjsonrpc_db_get_values(["/Equipment/PixelsCentral/Variables/PCMS"]).then(function(rpc) {
    //     if(rpc.result.data[0]){
    //         update_pcms(rpc.result.data[0]);
    //     }
    // }).catch(function(error) {
    //     mjsonrpc_error_alert(error);
    // });
}

init();
