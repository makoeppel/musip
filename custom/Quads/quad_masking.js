// Load masking files:

// Default path for UI display only - does NOT modify ODB values on page load
let currentMaskFolderPath = "/home/mu3e/mu3e/debug_online/online/userfiles/maskfiles/"; // Default: maskfiles directory

// Track display state vs actual ODB state
// This represents what the user has selected in the UI, not what's actually in ODB
let displayState = {
    selectedPath: currentMaskFolderPath,
    selectedIteration: null,
    requiresIteration: false
};

/**
 * Get available mask file folders (manually defined)
 */
function getMaskFolders() {
    const basePath = currentMaskFolderPath;
    return [
        { name: "Current", path: basePath },
        { name: "Edges", path: basePath + "edges/" },
        { name: "Identify", path: basePath + "identify/" },
        { name: "Tuning", path: basePath + "tuning/", requiresIteration: true },
    ];
}

/**
 * Check if the display state matches the actual ODB state for a sensor
 */
async function checkPathMatches(sensorId) {
    try {
        const dataId = getDataIds(sensorId);
        const actualId = Array.isArray(dataId) ? dataId[0] : dataId;

        // Get current ODB path
        const odbPath = await getODBValue(`/Equipment/Quads/Settings/Config/TDACS//TDACFILE[${actualId}]`);

        // Only compare if this sensor would use display state (selected or active)
        const selectedSensors = getSelectedSensorsForMasking();
        const isSelected = selectedSensors.includes(sensorId);

        let isActiveForDisplay = false;
        if (typeof getActiveSelection === 'function') {
            const activeSensor = getActiveSelection();
            isActiveForDisplay = (activeSensor === sensorId);
        }

        // If this sensor wouldn't use display state, always return true (no mismatch)
        if (!isSelected && !isActiveForDisplay) {
            return true;
        }

        // Generate expected path from display state, using remapping if enabled
        let expectedId = enableSensorRemap ? remapSensorId(actualId) : actualId;
        let expectedPath;
        if (displayState.requiresIteration && displayState.selectedIteration !== null) {
            expectedPath = `${displayState.selectedPath}mask_${expectedId}_iteration_${displayState.selectedIteration}.bin`;
        } else {
            expectedPath = `${displayState.selectedPath}mask_${expectedId}.bin`;
        }

        return odbPath === expectedPath;
    } catch (error) {
        console.error(`Error checking path match for sensor ${sensorId}:`, error);
        return true; // Assume match on error to avoid false highlighting
    }
}

/**
 * Update display state when selection changes (without writing to ODB)
 */
function updateDisplayState(basePath, iteration = null, requiresIteration = false) {
    displayState.selectedPath = basePath;
    displayState.selectedIteration = iteration;
    displayState.requiresIteration = requiresIteration;
    
    console.log("Display state updated:", displayState);
    
    // Update visual indicators
    createSensorSelectionForMasking();
    
    // Refresh masking display if needed
    if (typeof masking_draw === 'function') {
        masking_draw();
    }
}

/**
 * Revert display to match current ODB state for deselected sensors
 */
async function revertDisplayToODB() {
    // This will be called when sensors are deselected
    // The color coding will automatically show the ODB state
    createSensorSelectionForMasking();
}

/**
 * Get list of active sensors from sensor selection
 */
function getActiveSensors() {
    // Return all sensor IDs (0-15) if no specific selection is available
    let allSensors = [];
    for (let i = 0; i < 16; i++) {
        allSensors.push(i);
    }
    return allSensors;
}

/**
 * Get sensors that are currently selected in the sensor selection interface
 */
function getSelectedSensorsForMasking() {
    // Check if sensor selection exists
    if (typeof getSelection === 'function') {
        const selection = getSelection();
        if (selection && selection.length > 0) {
            return selection;
        }
    }
    
    // Fallback to all active sensors
    return getActiveSensors();
}

/**
 * Highlight sensor titles for selected sensors in the masking view
 * Targets ONLY sensor titles within the Masking tab (not HitMap tab)
 */
async function createSensorSelectionForMasking() {
    // Get selected sensors from the main sensor selection interface
    const selectedSensors = getSelectedSensorsForMasking();
    
    // Find sensor title elements ONLY within the MaskingTable (not HitMapTable)
    const maskingTable = document.getElementById('MaskingTable');
    if (!maskingTable) return;
    const sensorTitles = maskingTable.querySelectorAll('.general_sensor_title');
    
    for (const titleElement of sensorTitles) {
        // Extract sensor ID from the title text "Sensor X"
        const titleText = titleElement.textContent || titleElement.innerText;
        const sensorIdMatch = titleText.match(/Sensor\s*(\d+)/i);
        
        if (sensorIdMatch) {
            const sensorId = parseInt(sensorIdMatch[1]);
            
            // Set consistent base styling for all titles
            titleElement.style.padding = '4px 10px';
            titleElement.style.margin = '3px auto';
            titleElement.style.borderRadius = '4px';
            titleElement.style.fontSize = '14px';
            titleElement.style.textAlign = 'center';
            titleElement.style.width = 'fit-content';
            titleElement.style.maxWidth = '256px'; // Same width as masking canvas
            titleElement.style.display = 'block';
            
            if (selectedSensors.includes(sensorId)) {
                // Check if display state matches ODB state for color coding
                const pathMatches = await checkPathMatches(sensorId);
                
                // Highlight selected sensors with color coding
                if (pathMatches) {
                    titleElement.style.backgroundColor = '#4CAF50'; // Green: matches ODB
                    titleElement.style.color = 'white';
                } else {
                    titleElement.style.backgroundColor = '#FF9800'; // Orange: differs from ODB
                    titleElement.style.color = 'white';
                }
                titleElement.style.fontWeight = 'bold';
                
                // Special highlighting for active sensor
                if (typeof getActiveSelection === 'function') {
                    const activeSensor = getActiveSelection();
                    if (activeSensor === sensorId) {
                        titleElement.style.border = '2px solid #2196F3'; // Blue border for active
                        titleElement.title = pathMatches ? 
                            'Active sensor - display matches ODB' : 
                            'Active sensor - display differs from ODB (press Apply to update)';
                    } else {
                        titleElement.style.border = 'none';
                        titleElement.title = pathMatches ?
                            'Selected sensor - display matches ODB' :
                            'Selected sensor - display differs from ODB (press Apply to update)';
                    }
                }
            } else {
                // Non-selected sensors - keep consistent styling but different colors
                titleElement.style.backgroundColor = '#f5f5f5';
                titleElement.style.color = '#666';
                titleElement.style.fontWeight = 'normal';
                titleElement.style.border = 'none';
                titleElement.title = '';
            }
        }
    }
}

/**
 * Initialize mask folder radio buttons
 */
function initializeMaskFolderSelection() {
    const folders = getMaskFolders();
    const radioGroup = document.getElementById('maskFolderRadioGroup');
    
    if (!radioGroup) return;
    
    radioGroup.innerHTML = '';
    
    // Highlight selected sensor titles in the existing masking view
    createSensorSelectionForMasking();
    
    // Create horizontal container for predefined folders
    const horizontalContainer = document.createElement('div');
    horizontalContainer.style.display = 'flex';
    horizontalContainer.style.flexWrap = 'wrap';
    horizontalContainer.style.gap = '15px';
    horizontalContainer.style.marginBottom = '10px';
    
    folders.forEach((folder, index) => {
        const radioDiv = document.createElement('div');
        radioDiv.style.display = 'flex';
        radioDiv.style.alignItems = 'center';
        radioDiv.style.flexWrap = 'wrap';
        
        const radioInput = document.createElement('input');
        radioInput.type = 'radio';
        radioInput.name = 'maskFolder';
        radioInput.id = `maskFolder_${index}`;
        radioInput.value = folder.path;
        radioInput.checked = index === 0; // Default to first option (Main Directory)
        
        const radioLabel = document.createElement('label');
        radioLabel.htmlFor = `maskFolder_${index}`;
        radioLabel.textContent = folder.name;
        radioLabel.style.marginLeft = '5px';
        radioLabel.style.cursor = 'pointer';
        
        radioInput.addEventListener('change', function() {
            if (this.checked) {
                // Handle tuning folder with iteration
                if (folder.requiresIteration) {
                    const iterationInput = document.getElementById('tuningIteration');
                    const applyTuningButton = document.getElementById('applyTuningIteration');
                    if (iterationInput) {
                        iterationInput.disabled = false;
                        iterationInput.focus();
                    }
                    
                    // Update display state only (don't write to ODB yet)
                    const currentIteration = iterationInput ? iterationInput.value : null;
                    if (currentIteration) {
                        updateDisplayState(this.value, parseInt(currentIteration), true);
                    } else {
                        updateDisplayState(this.value, null, true);
                    }
                    
                    disableOtherInputs(['tuningIteration']);
                } else {
                    // Update display state only (don't write to ODB yet)
                    updateDisplayState(this.value, null, false);
                    disableOtherInputs([]);
                }
            }
        });
        
        radioDiv.appendChild(radioInput);
        radioDiv.appendChild(radioLabel);
        
        // Add iteration input for tuning folder
        if (folder.requiresIteration) {
            const iterationLabel = document.createElement('label');
            iterationLabel.textContent = 'Iteration:';
            iterationLabel.style.marginLeft = '10px';
            iterationLabel.style.fontSize = '12px';
            
            const iterationInput = document.createElement('input');
            iterationInput.type = 'number';
            iterationInput.id = 'tuningIteration';
            iterationInput.placeholder = '97';
            iterationInput.min = '0';
            iterationInput.max = '999';
            iterationInput.style.width = '60px';
            iterationInput.style.marginLeft = '5px';
            iterationInput.disabled = true;
            
            // Update display state when iteration changes
            iterationInput.addEventListener('input', function(e) {
                const iteration = this.value.trim();
                if (iteration && !isNaN(iteration)) {
                    const tuningPath = "/home/mu3e/mu3e/debug_online/online/userfiles/maskfiles/tuning/";
                    updateDisplayState(tuningPath, parseInt(iteration), true);
                }
            });
            
            radioDiv.appendChild(iterationLabel);
            radioDiv.appendChild(iterationInput);
        }
        
        horizontalContainer.appendChild(radioDiv);
    });
    
    radioGroup.appendChild(horizontalContainer);
    
    // Add a general Apply button that fits with the existing style
    const generalApplyContainer = document.createElement('div');
    generalApplyContainer.style.marginTop = '10px';
    generalApplyContainer.style.display = 'flex';
    generalApplyContainer.style.alignItems = 'center';
    generalApplyContainer.style.gap = '10px';
    
    const generalApplyButton = document.createElement('button');
    generalApplyButton.id = 'applyAllMaskPaths';
    generalApplyButton.textContent = 'Apply';
    generalApplyButton.style.padding = '4px 12px';
    generalApplyButton.style.fontSize = '12px';
    generalApplyButton.style.cursor = 'pointer';
    generalApplyButton.onclick = applyAllMaskPaths;
    
    const applyLabel = document.createElement('span');
    applyLabel.textContent = 'Write selected maskes to ODB';
    applyLabel.style.fontSize = '12px';
    applyLabel.style.color = '#666';
    
    generalApplyContainer.appendChild(generalApplyButton);
    generalApplyContainer.appendChild(applyLabel);
    radioGroup.appendChild(generalApplyContainer);
    
    // Handle existing custom path radio button from HTML
    const customRadio = document.getElementById('maskFolder_custom');
    if (customRadio) {
        customRadio.addEventListener('change', function() {
            if (this.checked) {
                const customPathInput = document.getElementById('customMaskPath');
                const applyButton = document.getElementById('applyCustomPath');
                if (customPathInput) {
                    customPathInput.disabled = false;
                    // Pre-populate with current display path for editing
                    customPathInput.value = displayState.selectedPath;
                    customPathInput.focus();
                    customPathInput.select(); // Select all text for easy editing
                }
                if (applyButton) applyButton.disabled = false;
                
                // Disable other inputs when custom is selected
                disableOtherInputs(['customMaskPath', 'applyCustomPath']);
            }
        });
    }
    
    // Set initial display state WITHOUT writing to ODB
    // This just sets the UI default, doesn't modify actual sensor configurations
    if (folders.length > 0) {
        // Initialize display state to default path but don't trigger ODB writes
        displayState.selectedPath = folders[0].path;
        displayState.selectedIteration = null;
        displayState.requiresIteration = false;
        
        console.log("Initial display state set (no ODB write):", displayState);
        console.log("currentMaskFolderPath:", currentMaskFolderPath);
        console.log("folders[0].path:", folders[0].path);
        
        // Sanity check - ensure path includes 'maskfiles'
        if (!displayState.selectedPath.includes('maskfiles')) {
            console.error("WARNING: Display path does not include 'maskfiles':", displayState.selectedPath);
            displayState.selectedPath = "/home/mu3e/mu3e/debug_online/online/userfiles/maskfiles/";
            console.log("Corrected display path to:", displayState.selectedPath);
        }
        
        // Initialize custom path input with current display state
        const customPathInput = document.getElementById('customMaskPath');
        if (customPathInput) {
            customPathInput.value = displayState.selectedPath;
            
            // Update display state when custom path changes
            customPathInput.addEventListener('input', function() {
                const normalizedPath = this.value.endsWith('/') ? this.value : this.value + '/';
                updateDisplayState(normalizedPath, null, false);
            });
        }
        
        // Initial visual update (shows current ODB state vs display state)
        createSensorSelectionForMasking();
    }
}

/**
 * Apply custom mask path - only updates display state, does not write to ODB
 */
function applyCustomMaskPath() {
    const customPath = document.getElementById('customMaskPath').value.trim();
    if (customPath) {
        // Ensure path ends with /
        const normalizedPath = customPath.endsWith('/') ? customPath : customPath + '/';
        // Only update display state, don't write to ODB
        updateDisplayState(normalizedPath, null, false);
        console.log("Custom path applied to display state only:", normalizedPath);
    } else {
        alert('Please enter a valid path');
    }
}

// Optional: Enable chipID remapping for ODB file paths
let enableSensorRemap = false; // Set to true to enable remapping

// Remapping function: input sensorId -> output sensorId
function remapSensorId(sensorId) {
    // const remap = [10, 11, 2, 3, 0, 1, 8, 9, 14, 15, 6, 7, 4, 5, 12, 13];
    const remap = [4, 5, 2, 3, 12, 13, 10, 11, 6, 7, 0, 1, 14, 15, 8, 9];
    if (enableSensorRemap && sensorId >= 0 && sensorId < remap.length) {
        console.log('using remapping for sensor', sensorId, " changing it to", remap[sensorId]);
        return remap[sensorId];
    }
    return sensorId;
}

/**
 * Apply all mask paths - general function for all apply buttons
 */
async function applyAllMaskPaths() {
    try {
        currentMaskFolderPath = displayState.selectedPath;
        console.log("Applying mask paths:", displayState);
        
        // Get the currently selected sensors from the main sensor selection interface
        const sensorsToUpdate = getSelectedSensorsForMasking();
        
        console.log("Updating sensors:", sensorsToUpdate, "with display state:", displayState);
        
        // Convert sensor IDs to data IDs
        let data_ids = [];
        for (let sensorId of sensorsToUpdate) {
            let dataId = getDataIds(sensorId);
            if (Array.isArray(dataId)) {
                data_ids.push(dataId[0]); // Take first element if array
            } else {
                data_ids.push(dataId);
            }
        }
        for (let i = 0; i < data_ids.length; i++) {
            let originalSensorId = data_ids[i];
            // Remap sensorId if remapping is enabled
            let remappedSensorId = remapSensorId(originalSensorId);
            
            // Update TDACFILE path for selected sensors
            let tdacPath = `/Equipment/Quads/Settings/Config/TDACS/${originalSensorId}/TDACFILE`;
            let tdacValue;
            
            if (displayState.requiresIteration && displayState.selectedIteration !== null) {
                tdacValue = `${displayState.selectedPath}mask_${remappedSensorId}_iteration_${displayState.selectedIteration}.bin`;
            } else {
                tdacValue = `${displayState.selectedPath}mask_${remappedSensorId}.bin`;
            }
            
            await setODBValue(tdacPath, tdacValue);
            console.log(`Updated sensor ${originalSensorId} -> ${remappedSensorId}: ${tdacValue}`);
        }
        
        console.log(`Successfully applied mask file paths for ${sensorsToUpdate.length} sensor(s)`);
        
        // Refresh the sensor selection display to show updated colors
        createSensorSelectionForMasking();
        
        // Refresh masking display if needed
        if (typeof masking_draw === 'function') {
            masking_draw();
        }
    } catch (error) {
        console.error("Error applying mask paths:", error);
        alert("Error applying mask paths: " + error.message);
    }
}

/**
 * Apply tuning iteration mask path (legacy function - now calls general apply)
 */
/**
 * Disable other input controls when a specific option is selected
 */
function disableOtherInputs(enabledIds = []) {
    // Disable custom path input
    const customPathInput = document.getElementById('customMaskPath');
    const customApplyButton = document.getElementById('applyCustomPath');
    if (customPathInput) {
        customPathInput.disabled = !enabledIds.includes('customMaskPath');
    }
    if (customApplyButton) {
        customApplyButton.disabled = !enabledIds.includes('applyCustomPath');
    }
    
    // Disable tuning iteration input
    const tuningIterationInput = document.getElementById('tuningIteration');
    if (tuningIterationInput) {
        tuningIterationInput.disabled = !enabledIds.includes('tuningIteration');
    }
}

/**
 * get Masking file for sensor of id
 * Uses display state if available, otherwise falls back to ODB value
 * 
 * @param {number} id Sensor ID
 */
async function getMaskingFile(id){
    try {
        // Check if we should use display state or ODB state
        const selectedSensors = getSelectedSensorsForMasking();
        const isSelected = selectedSensors.includes(id);
        
        // Also check if this is the currently active sensor being displayed
        let isActiveForDisplay = false;
        if (typeof getActiveSelection === 'function') {
            const activeSensor = getActiveSelection();
            isActiveForDisplay = (activeSensor === id);
        }
        
        let filePath;
        if ((isSelected || isActiveForDisplay) && displayState.selectedPath) {
            // Use display state for selected sensors or the active sensor being displayed
            const dataId = getDataIds(id);
            const actualId = Array.isArray(dataId) ? dataId[0] : dataId;
            
            if (displayState.requiresIteration && displayState.selectedIteration !== null) {
                filePath = `${displayState.selectedPath}mask_${actualId}_iteration_${displayState.selectedIteration}.bin`;
            } else {
                filePath = `${displayState.selectedPath}mask_${actualId}.bin`;
            }
        } else {
            // Use ODB state for non-selected sensors
            filePath = await getODBValue(`/Equipment/Quads/Settings/Config/TDACS/${id}/TDACFILE`);
        }
        
        console.log(`Getting mask file for ID ${id}: ${filePath} (${(isSelected || isActiveForDisplay) ? 'display state' : 'ODB state'})`);
        const data = await retrieveBinaryFile(filePath);
        if (data == undefined) {
            throw new Error("File does not exist.");
        }
        return data;

    } catch (error) {
        console.log(`Error getting mask file for ID ${id}:`, error.message);
        return undefined;
    }
}


async function drawMaskingHistogram(){
    console.log("drawMaskingHistogram this:", this, "this.id:", this?.id);

    let data_id = getDataIds(this.id);
    let data = await getMaskingFile(data_id);

    if (data == undefined) {  
        return;
    }
    console.log("id: ", data_id, "length: ", data.length, "data: ", data)

    // The mask file is 256x256 but only 256x250 contains actual sensor data
    // Rows 250-255 are padding/metadata that should not be displayed
    const sensorCols = 256;
    const sensorRows = 250;
    
    let imageData = this.cc.createImageData(sensorCols, sensorRows);
    
    // Color mapping function for TDAC values
    function getTDACColor(value) {
        if (value === 0) {
            // Unmasked -> white
            return [255, 255, 255];
        } else if (value >= 1 && value <= 7) {
            // TDAC values 1-7 -> color scale from light blue to red
            const ratio = (value - 1) / 6; // Normalize to 0-1
            const r = Math.round(255 * ratio);           // 0 -> 255 (red increases)
            const g = Math.round(255 * (1 - ratio));     // 255 -> 0 (green decreases)
            const b = Math.round(255 * (1 - ratio));     // 255 -> 0 (blue decreases)
            return [r, g, b];
        } else {
            // Fully masked (value > 7) -> black
            return [0, 0, 0];
        }
    }
    
    // C++ writes: masking[col + 256*row] for a 256x256 file
    // But let's verify if we're interpreting col/row correctly
    // The C++ loop structure is: for(col) { for(row) { masking[col + 256*row] } }
    // This suggests the data might be stored column-major, not row-major!
    
    for ( let sensorRow = 0; sensorRow < sensorRows; sensorRow++ ) {
        for ( let sensorCol = 0; sensorCol < sensorCols; sensorCol++ ) {
            // Try swapped interpretation: maybe C++ col/row are swapped vs our expectation
            let fileIndex = sensorRow + 256 * sensorCol;  // C++ uses col + 256*row storage pattern
            let value = data[fileIndex];
            let [r, g, b] = getTDACColor(value);
            
            // Transform to canvas coordinates:
            // Sensor (0,0) should appear at canvas bottom-left
            // Canvas (0,0) is top-left, so flip Y-axis
            let canvasRow = (sensorRows - 1) - sensorRow;  // Flip: 0->249, 249->0
            let canvasCol = sensorCol;                     // No flip: 0->0, 255->255
            
            // ImageData index: (canvasRow * width + canvasCol) * 4
            let imageIndex = (canvasRow * sensorCols + canvasCol) * 4;

            imageData.data[imageIndex    ] = r;
            imageData.data[imageIndex + 1] = g;
            imageData.data[imageIndex + 2] = b;
            imageData.data[imageIndex + 3] = 255; // Alpha
        }
    }
    this.cc.putImageData(imageData, 0, 0);
}



//only create SetupSel if it does not exist yet
if (typeof mask_setup === 'undefined') {
    var mask_setup = new SetupGeneral("Masking", drawMaskingHistogram);
}

function masking_draw(){
    mask_setup.draw();   
}

masking_draw();

// Initialize mask folder selection when page loads
document.addEventListener('DOMContentLoaded', function() {
    initializeMaskFolderSelection();
});

// Also initialize when the masking tab is clicked
document.addEventListener('change', function(event) {
    if (event.target && event.target.id === 'tab-masking' && event.target.checked) {
        initializeMaskFolderSelection();
    }
});

// Sync UI controls to current active sensor's ODB settings
async function syncUIToActiveSensor() {
    // Determine active sensor (default to 0 if none)
    let activeSensor = 0;
    if (typeof getActiveSelection === 'function') {
        const sel = getActiveSelection();
        if (typeof sel === 'number' && sel >= 0 && sel < 16) activeSensor = sel;
    }
    // Get ODB value for this sensor
    const odbPath = `/Equipment/Quads/Settings/Config/TDACS/${activeSensor}/TDACFILE`;
    let odbValue = await getODBValue(odbPath);
    // Try to parse remapping and mask folder from ODB value
    let remapDetected = false;
    let folderDetected = '';
    if (odbValue) {
        // Try to extract mask_N.bin or mask_N_iteration_M.bin
        const match = odbValue.match(/mask_(\d+)(?:_iteration_(\d+))?\.bin/);
        if (match) {
            const fileId = parseInt(match[1]);
            remapDetected = (fileId !== activeSensor); // If fileId differs, remapping is active
        }
        // Extract folder
        const folderMatch = odbValue.match(/^(.*\/)(mask_\d+.*\.bin)$/);
        if (folderMatch) {
            folderDetected = folderMatch[1];
        }
    }
    // Update remapping checkbox
    const remapCheckbox = document.getElementById('enableRemapCheckbox');
    if (remapCheckbox) remapCheckbox.checked = remapDetected;
    enableSensorRemap = remapDetected;
    // Update mask folder radio selection
    const folders = getMaskFolders();
    let found = false;
    for (let i = 0; i < folders.length; i++) {
        if (folders[i].path === folderDetected) {
            const radio = document.getElementById(`maskFolder_${i}`);
            if (radio) radio.checked = true;
            displayState.selectedPath = folders[i].path;
            displayState.requiresIteration = !!folders[i].requiresIteration;
            found = true;
            break;
        }
    }
    if (!found && folderDetected) {
        // Custom path
        const customRadio = document.getElementById('maskFolder_custom');
        const customInput = document.getElementById('customMaskPath');
        if (customRadio && customInput) {
            customRadio.checked = true;
            customInput.value = folderDetected;
            displayState.selectedPath = folderDetected;
        }
    }
    // Optionally update iteration if detected
    if (displayState.requiresIteration) {
        const match = odbValue.match(/_iteration_(\d+)\.bin/);
        if (match) {
            displayState.selectedIteration = parseInt(match[1]);
            const iterInput = document.getElementById('tuningIteration');
            if (iterInput) iterInput.value = displayState.selectedIteration;
        }
    }
    // Refresh UI
    createSensorSelectionForMasking();
    if (typeof masking_draw === 'function') masking_draw();
}

// Call syncUIToActiveSensor on selection change
if (typeof window !== 'undefined') {
    window.addEventListener('quad_selection_event', function() {
        createSensorSelectionForMasking(); // Only update colors
    });
    window.addEventListener('quad_active_selection_event', function() {
        createSensorSelectionForMasking(); // Only update colors
    });
}

// --- Update remapping and mask folder UI only on user interaction ---
// Add these listeners in initializeMaskFolderSelection after creating the controls
// (This code should be placed after remapCheckbox and radioGroup are created)
if (typeof document !== 'undefined') {
    document.addEventListener('change', function(event) {
        if (event.target && event.target.id === 'enableRemapCheckbox') {
            // User toggled remapping checkbox
            enableSensorRemap = event.target.checked;
            createSensorSelectionForMasking(); // Update color coding
        }
        if (event.target && event.target.name === 'maskFolder') {
            // User changed mask folder radio
            const selectedRadio = document.querySelector('input[name="maskFolder"]:checked');
            if (selectedRadio) {
                displayState.selectedPath = selectedRadio.value;
                // Update requiresIteration if needed
                const folders = getMaskFolders();
                for (let i = 0; i < folders.length; i++) {
                    if (folders[i].path === selectedRadio.value) {
                        displayState.requiresIteration = !!folders[i].requiresIteration;
                        break;
                    }
                }
                createSensorSelectionForMasking(); // Update color coding
            }
        }
    });
}

syncUIToActiveSensor()