const nFEBs = 2;
const nGirdPerFEB = 2;
const nASICPerGrid = 4;
const nASICsPerFEB = 8;
const nLinksPerASIC = 3;
const cells = [];
const selectedCells = new Set();
const maskedLinks = [];
const invertedLinks = [];


async function setODBValue(paths, values, print = false, errorMessageText = undefined){
   if (print) console.log("setODBValue: " + paths + " to: " + values);
   try{
      if (!Array.isArray(paths)){
         return await mjsonrpc_db_paste([paths], [values]);
      } else {
         return await mjsonrpc_db_paste(paths, values);
      }

   }
   catch (error) {
      let errorMessage = 'Couldn\'t change value at ' + paths + ': ' + error;
      if (errorMessageText != undefined){
         errorMessage = errorMessageText + ': ' + error;
      }
      mjsonrpc_error_alert(errorMessage)
      console.log(errorMessage);
      return null;
   }
}

async function getODBValue(paths, print = false, errorMessageText = undefined) {
   try {
      if (!Array.isArray(paths)) {
         let value = await mjsonrpc_db_get_value(paths);
         let data = value.result.data[0];
         if (print) console.log("getODBValue: " + paths + " = " + data);
         return data;
      }
      else {
         let values = await mjsonrpc_db_get_values(paths);
         let data = values.result.data;
         if (print) console.log("getODBValues: " + paths + " = " + data);
         return data;
      }
   }
   catch (error) {
      let errorMessage = 'Couldn\'t read value at ' + paths + ': ' + error;
      if (errorMessageText != undefined){
         errorMessage = errorMessageText + ': ' + error;
      }
      mjsonrpc_error_alert(errorMessage)
      console.log(errorMessage);
      return null;
   }
}

function computeCellIndex(index, gridID, febID) {
    return index + gridID * nASICPerGrid + febID * nASICsPerFEB;
}

function getBit(number, bitPosition) {
    return (number & (1 << bitPosition)) === 0 ? 0 : 1;
}

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

async function sendStateToBackend() {
    const ASICMask = [0, 0, 0, 0];
    const LVDSLinkMask = [0, 0, 0, 0];
    const LVDSLinkInvert = [0, 0, 0, 0];

    for(let asic of selectedCells)
        ASICMask[parseInt(asic / nASICsPerFEB)] |= (1 << asic % nASICsPerFEB);

    for (let feb = 0; feb < nFEBs; feb++) {
        for (let l = 0; l < nASICsPerFEB * nLinksPerASIC; l++) {
            if (maskedLinks[feb][l]) LVDSLinkMask[feb] |= (1 << l);
            if (invertedLinks[feb][l]) LVDSLinkInvert[feb] |= (1 << l);
        }
    }

    await setODBValue("/Equipment/Quads Config/Settings/DAQ/Links/ASICMask", ASICMask);
    await setODBValue("/Equipment/Quads Config/Settings/DAQ/Links/LVDSLinkMask", LVDSLinkMask);
    await setODBValue("/Equipment/Quads Config/Settings/DAQ/Links/LVDSLinkInvert", LVDSLinkInvert);
}

async function configure() {
    await sendStateToBackend();
    await setODBValue("/Equipment/Quads Config/Settings/Readout/MupixConfig", 1);
}

function renderGrid(gridId, data, febID, gridID) {
    const grid = document.getElementById(gridId);
    grid.innerHTML = '';

    data[febID][gridID].forEach((cellLinks, index) => {
        const cell = document.createElement('div');
        cell.className = 'cell';

        const globalIndex = computeCellIndex(index, gridID, febID);
        if (selectedCells.has(globalIndex)) {
            cell.classList.add('selected');
        }

        cellLinks.forEach(link => {
            const section = document.createElement('div');
            section.className = `section ${getColor(link)}`;
            section.style.display = 'flex';
            section.style.flexDirection = 'column';
            section.style.alignItems = 'center';
            section.style.justifyContent = 'center';
            section.style.fontSize = '10px';
            section.style.padding = '2px';

            // Top label (ND / A / B / C)
            const label = document.createElement('div');
            label.className = 'section-label';
            if ((link.A == link.B) && (link.B == link.C)) {
                label.textContent = "ND";
            } else if (link.A) {
                label.textContent = "A";
            } else if (link.B) {
                label.textContent = "B";
            } else if (link.C) {
                label.textContent = "C";
            }
            section.appendChild(label);

            // Checkbox group container
            const checkboxGroup = document.createElement('div');
            checkboxGroup.style.display = 'flex';
            checkboxGroup.style.flexDirection = 'column';
            checkboxGroup.style.alignItems = 'center';

            // Mask checkbox
            const mask = document.createElement('input');
            mask.type = 'checkbox';
            mask.title = 'Mask link';
            mask.style.margin = '1px';
            mask.checked = maskedLinks[link.feb][link.idx];
            section.classList.toggle('masked', mask.checked);
            mask.addEventListener('click', e => {
                e.stopPropagation(); // prevent cell selection toggle
                section.classList.toggle('masked', mask.checked); // toggle gray style
                maskedLinks[link.feb][link.idx] = mask.checked;
            });
            checkboxGroup.appendChild(mask);

            // Invert checkbox
            const invert = document.createElement('input');
            invert.type = 'checkbox';
            invert.title = 'Invert link';
            invert.style.margin = '1px';
            invert.checked = invertedLinks[link.feb][link.idx];
            invert.addEventListener('click', e => {
                e.stopPropagation(); // prevent cell toggle
                invertedLinks[link.feb][link.idx] = invert.checked;
            });
            checkboxGroup.appendChild(invert);

            section.appendChild(checkboxGroup);
            cell.appendChild(section);
        });


        // Prevent propagation to wrapper
        cell.addEventListener('click', e => {
            e.stopPropagation();
            if (selectedCells.has(globalIndex)) {
                selectedCells.delete(globalIndex);
                cell.classList.remove('selected');
            } else {
                selectedCells.add(globalIndex);
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
            if (l >= nASICsPerFEB * nLinksPerASIC) continue;

            const baseIndex = offset + 2 + 4 * l;
            const status = data[baseIndex];
            const disperr = data[baseIndex + 1];
            const err = data[baseIndex + 2];

            const asic = Math.floor(l / 3);
            const grid_asic = asic % 4;
            const grid = Math.floor(asic / 4);
            const link = l % 3;

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

    // Add grid-wrapper click handler for group select
    document.querySelectorAll('.grid-wrapper').forEach(wrapper => {
        wrapper.addEventListener('click', e => {
            const gridId = parseInt(wrapper.dataset.gridId);
            const febID = Math.floor(gridId / 2);
            const localGridID = gridId % 2;

            const baseIndex = localGridID * nASICPerGrid + febID * nASICsPerFEB;
            let allSelected = true;

            for (let i = 0; i < nASICPerGrid; i++) {
                if (!selectedCells.has(baseIndex + i)) {
                    allSelected = false;
                    break;
                }
            }

            for (let i = 0; i < nASICPerGrid; i++) {
                const index = baseIndex + i;
                const cell = wrapper.querySelector(`.cell:nth-child(${i + 1})`);
                if (allSelected) {
                    selectedCells.delete(index);
                    cell.classList.remove('selected');
                } else {
                    selectedCells.add(index);
                    cell.classList.add('selected');
                }
            }

            updateSelectedDisplay();
        });
    });
}

function update_pcms(input){
    const data = (typeof input === 'string') ? JSON.parse(input) : input;
    let offset = 0;

    while (offset < data.length) {

        var febIndex = parseInt(data[offset]);
        const nLinks = parseInt(data[offset + 1]);

        if (febIndex >= nFEBs) break;

        for (let l = 0; l < nLinks; l++) {
            if (l >= nASICsPerFEB * nLinksPerASIC) continue;

            const asic = Math.floor(l / 3);
            const grid_asic = asic % 4;
            const grid = Math.floor(asic / 4);
            const link = l % 3;

            var mask = 1 << l;
            cells[febIndex][grid][grid_asic][link].A = parseInt(data[offset+2] & mask);
            cells[febIndex][grid][grid_asic][link].B = parseInt(data[offset+4] & mask);
            cells[febIndex][grid][grid_asic][link].C = parseInt(data[offset+6] & mask);
        }
        offset += 8;
    }
}

async function init() {
    for (let i = 0; i < nFEBs; i++) {
        const cur_feb = [];
        idx = 0;
        for (let j = 0; j < nGirdPerFEB; j++) {
            const cur_grid = [];
            for (let k = 0; k < nASICPerGrid; k++) {
                const cur_asic = [];
                for (let l = 0; l < nLinksPerASIC; l++) {
                    cur_asic.push({ locked: 0, ready: 0, disperr: 0, err: 0, A: 0, B: 0, C: 0, idx: idx, feb: i });
                    idx++;
                }
                cur_grid.push(cur_asic);
            }
            cur_feb.push(cur_grid);
        }
        cells.push(cur_feb);
    }

    let ASICMask = await getODBValue(["/Equipment/Quads Config/Settings/DAQ/Links/ASICMask"]);
    let LVDSLinkMask = await getODBValue(["/Equipment/Quads Config/Settings/DAQ/Links/LVDSLinkMask"]);
    let LVDSLinkInvert = await getODBValue(["/Equipment/Quads Config/Settings/DAQ/Links/LVDSLinkInvert"]);

    for (let feb = 0; feb < nFEBs; feb++) {
        const mask = parseInt(ASICMask[0][feb]);
        const linkMask = parseInt(LVDSLinkMask[0][feb]);
        const linkInvert = parseInt(LVDSLinkInvert[0][feb]);

        // Loop over ASICs
        for (let asic = 0; asic < nASICsPerFEB; asic++) {
            const selected = ((mask >> asic) & 1) === 1;
            const grid = Math.floor(asic / nASICPerGrid);
            const grid_asic = asic % nASICPerGrid;
            const baseIndex = computeCellIndex(grid_asic, grid, feb);
            if (selected) selectedCells.add(baseIndex);
        }

        // Loop over links (24 per FEB)
        let cur_mask_link = []
        let cur_invert_link = []
        for (let l = 0; l < nASICsPerFEB * nLinksPerASIC; l++) {
            cur_mask_link.push(((linkMask >> l) & 1) === 1);
            cur_invert_link.push(((linkInvert >> l) & 1) === 1);
        }
        maskedLinks.push(cur_mask_link);
        invertedLinks.push(cur_invert_link);
    }
    updateSelectedDisplay();

    mjsonrpc_db_get_values(["/Equipment/Quads Config/Variables/PCLS"]).then(function(rpc) {
        if (rpc.result.data[0]) {
            update_pcls(rpc.result.data[0]);
        }
    }).catch(function(error) {
        mjsonrpc_error_alert(error);
    });

    mjsonrpc_db_get_values(["/Equipment/Quads Config/Variables/PCMS"]).then(function(rpc) {
        if(rpc.result.data[0]){
            update_pcms(rpc.result.data[0]);
        }
    }).catch(function(error) {
        mjsonrpc_error_alert(error);
    });

}

init();
