// Single consolidated script: mapping load, message display, SVG handler attachment,
// halo injection, and Mask/Unmask UI functions.

var channelMapping = {}; // name -> numeric id mapping (loaded from JSON)

var selectedChannel = null ; // currently selected channel
var selectedASIC = 0 ; // currently selected asic

// Load mapping JSON (same-directory relative path)
function init_channelSelection(url){
  fetch(url, {cache: 'no-cache'}).then(function(resp){
    if (!resp.ok) throw new Error('Failed to load mapping');
    return resp.json();
  }).then(function(json){
    channelMapping= json["channelmap"] || {};
    console.log('Channel map table loaded:', channelMapping);
  }).catch(function(err){
    console.warn('Could not load configuration:', err.message);
  });
};

// Show message using numeric mapping when available (accepts name string or event)
function showMessage(nameOrEvent) {
  var name = '';
  if (typeof nameOrEvent === 'string') name = nameOrEvent;
  else if (nameOrEvent && nameOrEvent.target) name = nameOrEvent.target.id || '';
  var mapped = (name && channelMapping[name]) || (name && channelMapping[name.trim()]);
  var display = (mapped !== undefined && mapped !== null) ? mapped : (name || nameOrEvent);
  

  selectedASIC = 0;
  selectedChannel = mapped || null;
  // Update selected channel display
  var selSpan = document.getElementById('channel_selection');
  if (selSpan) selSpan.textContent = (selectedChannel !== null) ? String(selectedChannel) : 'None';
  map_indices(true, selectedASIC, selectedChannel);
}

// Attach handlers into the embedded SVG, enabling hover halos
function attachHandlersToEmbeddedSvg(obj) {
  try {
    var svgDoc = obj.contentDocument || (obj.getSVGDocument && obj.getSVGDocument());
    if (!svgDoc) return false;

    // Inject halo CSS into the SVG document so drop-shadow renders inside the object
    try {
      var styleEl = svgDoc.createElementNS('http://www.w3.org/2000/svg','style');
      styleEl.textContent = '\n.halo { filter: drop-shadow(0 0 8px rgba(96,165,250,0.9)) drop-shadow(0 0 18px rgba(96,165,250,0.5)); }\n.shape { transition: transform .15s; }\n';
      var root = svgDoc.documentElement || svgDoc.querySelector('svg');
      if (root) root.appendChild(styleEl);
    } catch (e) { /* ignore injection errors */ }

    // Find interactive elements: those with onclick, class .shape, or data-name
    var elems = svgDoc.querySelectorAll('[onclick], .shape, [data-name]');
    elems.forEach(function(el){
      if (el.__bound__) return; // avoid double binding
      el.__bound__ = true;
      // hover/focus halo toggle
      var add = function(){ try{ el.classList.add('halo'); } catch(e){} };
      var rem = function(){ try{ el.classList.remove('halo'); } catch(e){} };
      el.addEventListener('mouseenter', add);
      el.addEventListener('mouseleave', rem);
    });
    return true;
  } catch (err) {
    return false;
  }
}

// Helper to find elements for a mapping key inside the embedded SVG
function findElementsForKey(key) {
  var obj = document.getElementById('svg-object');
  if (!obj) return [];
  try {
    var svgDoc = obj.contentDocument || (obj.getSVGDocument && obj.getSVGDocument());
    if (!svgDoc) return [];
    var byId = svgDoc.getElementById(key);
    if (byId) return [byId];
    var results = [];
    var all = svgDoc.querySelectorAll('[data-name], title');
    all.forEach(function(n){
      if (n.getAttribute && n.getAttribute('data-name') === key) results.push(n);
      else if (n.tagName && n.tagName.toLowerCase() === 'title' && n.textContent.trim() === key) { if (n.parentNode) results.push(n.parentNode); }
    });
    return results;
  } catch (e) { return []; }
}

// Set or clear masked appearance on an element
function setElementMasked(el, masked) {
  try {
    if (masked) {
      el.setAttribute('data-old-fill', el.getAttribute('fill') || '');
//      el.setAttribute('data-old-stroke', el.getAttribute('stroke') || '');
      el.setAttribute('fill', '#ff0000');
//      if (el.hasAttribute('stroke')) el.setAttribute('stroke', '#888888');
      el.setAttribute('opacity', '0.5');
    } else {
      el.setAttribute('opacity', '1');
      var oldFill = el.getAttribute('data-old-fill');
//      var oldStroke = el.getAttribute('data-old-stroke');
      if (oldFill !== null) el.setAttribute('fill', oldFill);
//      if (oldStroke !== null) el.setAttribute('stroke', oldStroke); else el.removeAttribute('stroke');
//      el.removeAttribute('data-old-fill'); el.removeAttribute('data-old-stroke'); el.removeAttribute('opacity');
    }
  } catch (e) {}
}

//Mask all channels in map
// - update colour in svg
// - update odb and configure
function maskUnmaskChannelAll(value) {
  mutrig_sop_maskChannel(-1,value);
  Object.keys(channelMapping).forEach(function(key){ var els = findElementsForKey(key); els.forEach(function(el){ setElementMasked(el, value); }); });
}

//Mask selected channel in map
// - update colour in svg
// - update odb and configure
function maskUnmaskChannel(value) {
  var ch = selectedChannel;
  if (ch === undefined || ch === null) ch = document.getElementById('channel-input') && document.getElementById('channel-input').value;
  if (!ch) return;
  mutrig_sop_maskChannel(ch,value);
  Object.keys(channelMapping).forEach(function(key){ if (String(channelMapping[key]) === String(ch)) { var els = findElementsForKey(key); els.forEach(function(el){ setElementMasked(el, value); }); }});
}

// Wire up UI and object load
document.addEventListener('DOMContentLoaded', function(){
  var obj = document.getElementById('svg-object');
  if (obj) {
    obj.addEventListener('load', function(){ attachHandlersToEmbeddedSvg(obj); });
    // delayed attach for browsers that populate contentDocument slowly
    setTimeout(function(){ attachHandlersToEmbeddedSvg(obj); }, 700);
  }
});
