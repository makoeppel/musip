var channelRateValues = [];
var channelRateRefreshTimer = null;
var channelRateRefreshPending = false;
var channelRateSvgObserver = null;

function initChannelRateOverlay() {
  var maxInput = document.getElementById('channel-rate-max');
  if (maxInput) {
    maxInput.addEventListener('input', drawChannelRateOverlays);
  }

  var container = document.getElementById('svg-container');
  if (container && window.MutationObserver) {
    channelRateSvgObserver = new MutationObserver(function(records) {
      records.forEach(function(record) {
        record.addedNodes.forEach(function(node) {
          if (node.nodeType !== 1) return;
          if (node.tagName && node.tagName.toLowerCase() === 'object') {
            bindChannelRateSvg(node);
          }
          node.querySelectorAll &&
            node.querySelectorAll('object').forEach(bindChannelRateSvg);
        });
      });
    });
    channelRateSvgObserver.observe(container, {childList: true, subtree: true});
  }

  if (container) {
    container.querySelectorAll('object').forEach(bindChannelRateSvg);
  }

  refreshChannelRates();
  if (channelRateRefreshTimer !== null) {
    window.clearInterval(channelRateRefreshTimer);
  }
  channelRateRefreshTimer = window.setInterval(refreshChannelRates, 1000);
}

function bindChannelRateSvg(obj) {
  if (obj.__channelRateLoadBound) return;
  obj.__channelRateLoadBound = true;
  obj.addEventListener('load', drawChannelRateOverlays);
}

function refreshChannelRates() {
  if (channelRateRefreshPending) return;
  channelRateRefreshPending = true;
  mjsonrpc_db_get_values(['/Equipment/Quads/Variables/MTCR'])
    .then(function(rpc) {
      var data = rpc && rpc.result && rpc.result.data;
      if (!Array.isArray(data) || !Array.isArray(data[0])) {
        throw new Error('MTCR did not return a rate array');
      }
      channelRateValues = data[0].map(Number);
      var status = document.getElementById('channel-rate-status');
      if (status) status.textContent = '';
      channelRateRefreshPending = false;
      drawChannelRateOverlays();
    })
    .catch(function(error) {
      channelRateRefreshPending = false;
      var status = document.getElementById('channel-rate-status');
      if (status) status.textContent = ' Rate data unavailable: ' + error.message;
      console.error('Could not load MTCR rates:', error);
    });
}

function drawChannelRateOverlays() {
  var maxInput = document.getElementById('channel-rate-max');
  var maximum = maxInput ? Number(maxInput.value) : NaN;
  if (!Number.isFinite(maximum) || maximum <= 0) {
    if (maxInput) maxInput.setAttribute('aria-invalid', 'true');
    var status = document.getElementById('channel-rate-status');
    if (status) status.textContent = ' Rate bar maximum must be greater than zero.';
    return;
  }
  if (maxInput) maxInput.removeAttribute('aria-invalid');
  if (!channelMapping || typeof channelMapping !== 'object') return;

  Object.keys(channelMapping).forEach(function(key) {
    var mappingElement = getMappingElement(key);
    if (!mappingElement) return;

    var object = document.getElementById(mappingElement.objectId);
    var svgDoc = object &&
      (object.contentDocument || (object.getSVGDocument && object.getSVGDocument()));
    if (!svgDoc) return;

    var rateIndex = Number(channelMapping[key]);
    var rate = channelRateValues[rateIndex];
    if (!Number.isFinite(rate) || rate < 0) return;

    var shapes = Array.from(svgDoc.querySelectorAll('[data-name], [id]'))
      .filter(function(element) {
        return element.id === mappingElement.channelName ||
          element.getAttribute('data-name') === mappingElement.channelName;
      });

    shapes.forEach(function(shape) {
      updateChannelRateOverlay(shape, mappingElement.channelName, rate, maximum);
    });
  });
}

function updateChannelRateOverlay(shape, channelName, rate, maximum) {
  var svgDoc = shape.ownerDocument;
  var bounds;
  try {
    bounds = shape.getBBox();
  } catch (error) {
    console.warn('Could not measure SVG channel for rate overlay:', shape.id, error);
    return;
  }
  if (!bounds.width || !bounds.height || !shape.parentNode) return;

  var overlay = shape.__channelRateOverlay;
  if (!overlay) {
    overlay = svgDoc.createElementNS('http://www.w3.org/2000/svg', 'g');
    overlay.setAttribute('class', 'channel-rate-overlay');

    var bar = svgDoc.createElementNS('http://www.w3.org/2000/svg', 'rect');
    bar.setAttribute('fill', '#f59e0b');
    bar.setAttribute('fill-opacity', '0.8');
    bar.setAttribute('pointer-events', 'none');
    overlay.appendChild(bar);

    var label = svgDoc.createElementNS('http://www.w3.org/2000/svg', 'text');
    label.setAttribute('text-anchor', 'middle');
    label.setAttribute('dominant-baseline', 'central');
    label.setAttribute('font-family', 'sans-serif');
    label.setAttribute('font-size', String(Math.min(bounds.height * 0.7, 5)));
    label.setAttribute('font-weight', 'bold');
    label.setAttribute('fill', '#111827');
    label.setAttribute('stroke', '#ffffff');
    label.setAttribute('stroke-width', '1.2');
    label.setAttribute('paint-order', 'stroke');
    label.setAttribute('pointer-events', 'none');
    overlay.appendChild(label);

    shape.parentNode.insertBefore(overlay, shape.nextSibling);
    shape.__channelRateOverlay = overlay;
  }

  var bar = overlay.firstElementChild;
  var label = overlay.lastElementChild;
  var padding = Math.min(bounds.height * 0.08, bounds.width * 0.04);
  var chartWidth = Math.max(0, bounds.width - 2 * padding);
  var fraction = Math.max(0, Math.min(1, rate / maximum));
  var width = chartWidth * fraction;
  // A and B channels are opposite sides of the strip and grow toward its center.
  var fromRight = channelName.endsWith('_B') || channelName === 'M:2';
  if (fromRight) {
    bar.setAttribute('x', String(bounds.x + bounds.width - padding - width));
  } else {
    bar.setAttribute('x', String(bounds.x + padding));
  }
  bar.setAttribute('y', String(bounds.y + bounds.height * 0.2));
  bar.setAttribute('width', String(width));
  bar.setAttribute('height', String(bounds.height * 0.6));

  label.setAttribute('x', String(bounds.x + bounds.width / 2));
  label.setAttribute('y', String(bounds.y + bounds.height / 2));
  var labelText = Math.round(rate).toLocaleString() + ' Hz';
  var fontSize = Math.min(bounds.height * 0.7, 5, bounds.width / (labelText.length * 0.65));
  label.textContent = labelText;
  label.setAttribute('font-size', String(fontSize));
  label.setAttribute('stroke-width', String(Math.min(1.2, fontSize * 0.25)));
}
