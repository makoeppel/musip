// Mapping load, message display, SVG handler attachment, and Mask/Unmask UI functions.

var channelMapping = {};
var svgObjects = [];
var selectedChannel = null;
var selectedASIC = 0;

function init_channelSelection(url) {
  return fetch(url, {cache: 'no-cache'}).then(function(resp) {
    if (!resp.ok) throw new Error('Failed to load mapping: ' + resp.status);
    return resp.json();
  }).then(function(json) {
    channelMapping = json.channelmap || {};
    svgObjects = Array.isArray(json.svgs) ? json.svgs : [];
    renderConfiguredSvgs();
    console.log('Channel map table loaded:', channelMapping);
  }).catch(function(err) {
    console.warn('Could not load configuration:', err.message);
  });
}

function renderConfiguredSvgs() {
  var container = document.getElementById('svg-container');
  if (!container) return;
  container.replaceChildren();

  svgObjects.forEach(function(svgConfig) {
    if (!svgConfig || typeof svgConfig.name !== 'string' ||
        typeof svgConfig.path !== 'string') {
      console.warn('Ignoring invalid SVG configuration:', svgConfig);
      return;
    }

    var wrapper = document.createElement('div');
    wrapper.style.display = 'flex';
    wrapper.style.flexDirection = 'column';
    wrapper.style.gap = '6px';

    var titleEl = document.createElement('div');
    titleEl.textContent = svgConfig.name;
    titleEl.style.fontWeight = 'bold';
    titleEl.style.textTransform = 'capitalize';

    var obj = document.createElement('object');
    obj.type = 'image/svg+xml';
    obj.data = svgConfig.path;
    obj.id = svgConfig.name;
    obj.height = '300px';
    obj.setAttribute('aria-label', svgConfig.name);
    obj.setAttribute('title', svgConfig.name);
    obj.innerHTML = '<p>Your browser does not support inline SVG.</p>';
    obj.addEventListener('load', function() {
      attachHandlersToEmbeddedSvg(obj);
    });

    wrapper.appendChild(titleEl);
    wrapper.appendChild(obj);
    container.appendChild(wrapper);
    setTimeout(function() {
      attachHandlersToEmbeddedSvg(obj);
    }, 700);
  });
}

function getSvgObjectId(event) {
  var element = event && (event.currentTarget || event.target);
  var svgDoc = element && element.ownerDocument;
  var frameElement = svgDoc && svgDoc.defaultView && svgDoc.defaultView.frameElement;
  return frameElement ? frameElement.id : '';
}

function showMessage(nameOrEvent) {
  var name = '';
  var objectId = '';
  if (typeof nameOrEvent === 'string') {
    name = nameOrEvent;
  } else if (nameOrEvent && nameOrEvent.target) {
    var element = nameOrEvent.currentTarget || nameOrEvent.target;
    name = element.id ||
      (element.getAttribute && element.getAttribute('data-name')) ||
      nameOrEvent.target.id || '';
    objectId = getSvgObjectId(nameOrEvent);
  }

  var key = objectId && name ? objectId + ':' + name : '';
  var mapped = key ? channelMapping[key] : undefined;
  if (mapped === undefined && key) mapped = channelMapping[key.trim()];

  selectedASIC = 0;
  selectedChannel = mapped !== undefined && mapped !== null ? mapped : null;
  var selSpan = document.getElementById('channel_selection');
  if (selSpan) {
    selSpan.textContent = selectedChannel !== null ? String(selectedChannel) : 'None';
  }
  map_indices(true, selectedASIC, selectedChannel);
}

function attachHandlersToEmbeddedSvg(obj) {
  try {
    var svgDoc = obj.contentDocument || (obj.getSVGDocument && obj.getSVGDocument());
    if (!svgDoc) return false;

    var styleEl = svgDoc.createElementNS('http://www.w3.org/2000/svg', 'style');
    styleEl.textContent = '\n.halo { filter: drop-shadow(0 0 8px rgba(96,165,250,0.9)) drop-shadow(0 0 18px rgba(96,165,250,0.5)); }\n.shape { transition: transform .15s; }\n';
    var root = svgDoc.documentElement || svgDoc.querySelector('svg');
    if (root) root.appendChild(styleEl);

    var elems = svgDoc.querySelectorAll('[onclick], .shape, [data-name]');
    elems.forEach(function(el) {
      if (el.__bound__) return;
      el.__bound__ = true;
      el.addEventListener('mouseenter', function() {
        el.classList.add('halo');
      });
      el.addEventListener('mouseleave', function() {
        el.classList.remove('halo');
      });
    });
    return true;
  } catch (err) {
    return false;
  }
}

function getMappingElement(key) {
  for (var i = 0; i < svgObjects.length; i++) {
    var objectId = svgObjects[i].name + ':';
    if (key.indexOf(objectId) === 0) {
      return {
        objectId: svgObjects[i].name,
        channelName: key.substring(objectId.length)
      };
    }
  }
  return null;
}

function findElementsForKey(key) {
  var mappingElement = getMappingElement(key);
  var obj = mappingElement && document.getElementById(mappingElement.objectId);
  if (!obj) return [];
  try {
    var svgDoc = obj.contentDocument || (obj.getSVGDocument && obj.getSVGDocument());
    if (!svgDoc) return [];
    var channelName = mappingElement.channelName;
    var byId = svgDoc.getElementById(channelName);
    if (byId) return [byId];

    var results = [];
    svgDoc.querySelectorAll('[data-name], title').forEach(function(element) {
      if (element.getAttribute &&
          element.getAttribute('data-name') === channelName) {
        results.push(element);
      } else if (element.tagName &&
          element.tagName.toLowerCase() === 'title' &&
          element.textContent.trim() === channelName &&
          element.parentNode) {
        results.push(element.parentNode);
      }
    });
    return results;
  } catch (err) {
    return [];
  }
}

function setElementMasked(el, masked) {
  try {
    if (masked) {
      if (!el.hasAttribute('data-old-fill')) {
        var oldFill = el.getAttribute('fill');
        el.setAttribute('data-old-fill', oldFill === null ? '' : oldFill);
        el.setAttribute('data-had-fill', oldFill === null ? 'false' : 'true');
      }
      el.setAttribute('fill', '#ff0000');
      el.setAttribute('opacity', '0.5');
    } else {
      el.setAttribute('opacity', '1');
      var oldFill = el.getAttribute('data-old-fill');
      if (oldFill !== null) {
        if (el.getAttribute('data-had-fill') === 'true') {
          el.setAttribute('fill', oldFill);
        } else {
          el.removeAttribute('fill');
        }
        el.removeAttribute('data-old-fill');
        el.removeAttribute('data-had-fill');
      }
    }
  } catch (err) {}
}

function maskUnmaskChannelAll(value) {
  mutrig_sop_maskChannel(-1, value);
  Object.keys(channelMapping).forEach(function(key) {
    findElementsForKey(key).forEach(function(el) {
      setElementMasked(el, value);
    });
  });
}

function maskUnmaskChannel(value) {
  var ch = selectedChannel;
  if (ch === undefined || ch === null) {
    ch = document.getElementById('channel-input') &&
      document.getElementById('channel-input').value;
  }
  if (ch === undefined || ch === null || ch === '') return;

  mutrig_sop_maskChannel(ch, value);
  Object.keys(channelMapping).forEach(function(key) {
    if (String(channelMapping[key]) === String(ch)) {
      findElementsForKey(key).forEach(function(el) {
        setElementMasked(el, value);
      });
    }
  });
}
