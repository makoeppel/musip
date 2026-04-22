(function () {
  "use strict";

  const root = document.getElementById("app");
  if (!root) {
    return;
  }

  const inlineDataEl = document.getElementById("packet-analyzer-data");
  const debugMode = new URLSearchParams(window.location.search).get("debug") === "1";

  const tooltipEl = document.createElement("div");
  tooltipEl.className = "tooltip";
  tooltipEl.hidden = true;
  document.body.appendChild(tooltipEl);

  const menuEl = document.createElement("div");
  menuEl.className = "context-menu";
  menuEl.hidden = true;
  document.body.appendChild(menuEl);

  const rawInline = parseInlineData();
  const manifest = normalizeManifest(window.__PACKET_ANALYZER_MANIFEST__ || rawInline || {});
  const laneInfoMap = new Map((manifest.lanes || []).map((lane) => [Number(lane.lane), lane]));
  const laneDataMap = new Map();
  const laneLoadPromises = new Map();
  const loadedScripts = new Set();
  const packetMap = new Map();

  const debugState = {
    enabled: debugMode,
    bootState: "init",
    renderCount: 0,
    actions: [],
    errors: [],
    laneLoads: [],
    startedAt: Date.now(),
  };

  let menuState = null;
  let holdTimer = null;
  let holdTriggered = false;
  let scrollRaf = 0;

  const FAMILY_ORDER = (manifest.families || []).map((family) => family.id);
  const FAMILY_LABELS = Object.fromEntries((manifest.families || []).map((family) => [family.id, family.label]));
  const PREF_KEY = "packet-analyzer-field-prefs:v2";

  const state = {
    lane: typeof manifest.meta.defaultLane === "number" ? manifest.meta.defaultLane : (manifest.lanes[0] && Number(manifest.lanes[0].lane)) || 0,
    decodeMode: manifest.meta.defaultDecodeMode || "musip-demo",
    viewTab: "spec",
    specMode: "hex",
    detailsRadix: "hex",
    updateMode: "click",
    trackerFormat: "fields",
    trackerDensity: "1x",
    trackerSync: true,
    wrap: false,
    familyFilters: Object.fromEntries(FAMILY_ORDER.map((family) => [family, true])),
    expandedRows: new Set(),
    selectedRowId: "",
    selectedFieldId: "",
    zeroTimePsByLane: {},
    fieldPrefs: loadFieldPrefs(),
    lastScrollTopByLane: {},
    loadingLane: null,
    fatalError: "",
    waveEmbedOpen: true,
  };

  bindEvents();
  bindGlobalErrorCapture();
  seedInlineLaneData(rawInline);
  exposeDebug();
  void bootstrap();

  async function bootstrap() {
    debugState.bootState = "loading";
    render();
    try {
      await ensureLaneData(state.lane);
      debugState.bootState = "ready";
      ensureSelection();
      ensureSelectedField(selectedPacket());
      render();
      void preloadOtherLanes();
    } catch (error) {
      noteError(error);
      state.fatalError = error instanceof Error ? error.message : String(error);
      debugState.bootState = "error";
      render();
    }
  }

  function parseInlineData() {
    if (!inlineDataEl || !inlineDataEl.textContent) {
      return null;
    }
    try {
      return JSON.parse(inlineDataEl.textContent);
    } catch (error) {
      noteError(error);
      return null;
    }
  }

  function normalizeManifest(raw) {
    if (raw && raw.manifest) {
      return raw.manifest;
    }
    if (raw && Array.isArray(raw.lanes) && raw.lanes.length && Array.isArray(raw.lanes[0].packets)) {
      return {
        meta: raw.meta || {},
        families: raw.families || [],
        decodeModes: raw.decodeModes || [],
        lanes: raw.lanes.map((lane) => ({
          lane: Number(lane.lane),
          frameIds: lane.frameIds || [],
          packetCount: lane.packetCount || ((lane.packets || []).length),
          hitCount: lane.hitCount || (lane.packets || []).filter((packet) => packet.kind === "hit").length,
          laneScript: "",
        })),
      };
    }
    return {
      meta: raw.meta || {},
      families: raw.families || [],
      decodeModes: raw.decodeModes || [],
      lanes: Array.isArray(raw.lanes) ? raw.lanes : [],
    };
  }

  function seedInlineLaneData(raw) {
    if (!raw || !Array.isArray(raw.lanes)) {
      return;
    }
    raw.lanes.forEach((lane) => {
      if (Array.isArray(lane.packets)) {
        seedLaneData(lane);
      }
    });
  }

  function bindGlobalErrorCapture() {
    window.addEventListener("error", (event) => {
      noteError(event.error || event.message || "Unknown window error");
    });
    window.addEventListener("unhandledrejection", (event) => {
      noteError(event.reason || "Unhandled promise rejection");
    });
  }

  function noteError(error) {
    const message = error instanceof Error ? error.stack || error.message : String(error);
    debugState.errors.push({
      time: new Date().toISOString(),
      message: message,
    });
  }

  function recordAction(action, detail) {
    const entry = {
      time: new Date().toISOString(),
      action: action,
      detail: detail || "",
    };
    debugState.actions.unshift(entry);
    debugState.actions = debugState.actions.slice(0, 18);
  }

  function exposeDebug() {
    window.__packetAnalyzerDebug = {
      getState: function () {
        const lane = currentLane();
        return {
          ready: debugState.bootState === "ready" && !state.loadingLane && !state.fatalError,
          bootState: debugState.bootState,
          lane: state.lane,
          loadingLane: state.loadingLane,
          loadedLanes: Array.from(laneDataMap.keys()).sort((a, b) => a - b),
          renderCount: debugState.renderCount,
          selectedRowId: state.selectedRowId,
          selectedFieldId: state.selectedFieldId,
          viewTab: state.viewTab,
          specMode: state.specMode,
          detailsRadix: state.detailsRadix,
          trackerFormat: state.trackerFormat,
          trackerDensity: state.trackerDensity,
          trackerSync: state.trackerSync,
          updateMode: state.updateMode,
          visiblePacketCount: visiblePackets().length,
          lanePacketCount: Array.isArray(lane.packets) ? lane.packets.length : 0,
          errors: debugState.errors.slice(),
          actions: debugState.actions.slice(),
          laneLoads: debugState.laneLoads.slice(),
        };
      },
      getErrors: function () {
        return debugState.errors.slice();
      },
    };
  }

  async function preloadOtherLanes() {
    for (const laneInfo of manifest.lanes || []) {
      const lane = Number(laneInfo.lane);
      if (lane === state.lane) {
        continue;
      }
      try {
        await ensureLaneData(lane);
      } catch (error) {
        noteError(error);
      }
    }
  }

  async function ensureLaneData(lane) {
    if (laneDataMap.has(lane)) {
      return laneDataMap.get(lane);
    }
    if (laneLoadPromises.has(lane)) {
      return laneLoadPromises.get(lane);
    }

    const laneInfo = laneInfoMap.get(lane);
    if (!laneInfo || !laneInfo.laneScript) {
      return null;
    }

    const promise = loadScriptOnce(laneInfo.laneScript)
      .then(() => {
        const payloads = window.__PACKET_ANALYZER_LANES__ || {};
        const laneData = payloads[lane] || payloads[String(lane)];
        if (!laneData) {
          throw new Error("Lane payload did not register after script load: lane " + lane);
        }
        seedLaneData(laneData);
        debugState.laneLoads.push({
          lane: lane,
          script: laneInfo.laneScript,
          time: new Date().toISOString(),
          packetCount: laneData.packetCount || (laneData.packets || []).length,
        });
        debugState.laneLoads = debugState.laneLoads.slice(-8);
        return laneData;
      })
      .finally(() => {
        laneLoadPromises.delete(lane);
      });

    laneLoadPromises.set(lane, promise);
    return promise;
  }

  function seedLaneData(laneData) {
    const lane = Number(laneData.lane);
    if (laneDataMap.has(lane)) {
      return;
    }
    laneDataMap.set(lane, laneData);
    (laneData.packets || []).forEach((packet) => {
      packetMap.set(packet.rowId, packet);
    });
    state.fieldPrefs = loadFieldPrefs();
  }

  function loadScriptOnce(src) {
    if (loadedScripts.has(src)) {
      return Promise.resolve();
    }
    return new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = src;
      script.async = true;
      script.onload = function () {
        loadedScripts.add(src);
        resolve();
      };
      script.onerror = function () {
        reject(new Error("Failed to load script: " + src));
      };
      document.head.appendChild(script);
    });
  }

  function loadFieldPrefs() {
    const base = buildDefaultFieldPrefs();
    try {
      const saved = JSON.parse(localStorage.getItem(PREF_KEY) || "{}");
      Object.keys(saved).forEach((key) => {
        if (!base[key]) {
          return;
        }
        const order = Array.isArray(saved[key].order) ? saved[key].order.filter((id) => base[key].order.includes(id)) : base[key].order.slice();
        const missing = base[key].order.filter((id) => !order.includes(id));
        base[key] = {
          order: order.concat(missing),
          hidden: Array.isArray(saved[key].hidden) ? saved[key].hidden.filter((id) => base[key].order.includes(id)) : base[key].hidden.slice(),
        };
      });
    } catch (error) {
      noteError(error);
    }
    return base;
  }

  function saveFieldPrefs() {
    try {
      localStorage.setItem(PREF_KEY, JSON.stringify(state.fieldPrefs));
    } catch (error) {
      noteError(error);
    }
  }

  function buildDefaultFieldPrefs() {
    const prefs = {};
    packetMap.forEach((packet) => {
      Object.keys(packet.fieldsByMode || {}).forEach((mode) => {
        const key = prefKey(mode, packet.kind);
        if (prefs[key]) {
          return;
        }
        const fields = packet.fieldsByMode[mode] || [];
        prefs[key] = {
          order: fields.map((field) => field.id),
          hidden: fields.filter((field) => !field.defaultVisible).map((field) => field.id),
        };
      });
    });
    return prefs;
  }

  function prefKey(mode, kind) {
    return mode + ":" + kind;
  }

  function ensurePref(packet) {
    if (!packet) {
      return { order: [], hidden: [] };
    }
    const key = prefKey(state.decodeMode, packet.kind);
    if (!state.fieldPrefs[key]) {
      const fields = getFields(packet);
      state.fieldPrefs[key] = {
        order: fields.map((field) => field.id),
        hidden: fields.filter((field) => !field.defaultVisible).map((field) => field.id),
      };
    }
    return state.fieldPrefs[key];
  }

  function currentLaneInfo() {
    return laneInfoMap.get(state.lane) || manifest.lanes[0] || { lane: 0, frameIds: [], packetCount: 0, hitCount: 0, laneScript: "" };
  }

  function currentLane() {
    const loaded = laneDataMap.get(state.lane);
    if (loaded) {
      return loaded;
    }
    const laneInfo = currentLaneInfo();
    return {
      lane: laneInfo.lane,
      frameIds: laneInfo.frameIds || [],
      packetCount: laneInfo.packetCount || 0,
      hitCount: laneInfo.hitCount || 0,
      packets: [],
    };
  }

  function visiblePackets() {
    return (currentLane().packets || []).filter((packet) => !!state.familyFilters[packet.kindFamily]);
  }

  function ensureSelection() {
    const visible = visiblePackets();
    if (!visible.length) {
      state.selectedRowId = "";
      return;
    }
    if (!visible.some((packet) => packet.rowId === state.selectedRowId)) {
      state.selectedRowId = visible[0].rowId;
    }
  }

  function selectedPacket() {
    return packetMap.get(state.selectedRowId) || visiblePackets()[0] || null;
  }

  function ensureSelectedField(packet) {
    const fields = getOrderedFields(packet);
    if (!fields.length) {
      state.selectedFieldId = "";
      return null;
    }
    if (!fields.some((field) => field.id === state.selectedFieldId)) {
      state.selectedFieldId = fields[0].id;
    }
    return fields.find((field) => field.id === state.selectedFieldId) || fields[0];
  }

  function getFields(packet) {
    return packet && packet.fieldsByMode ? (packet.fieldsByMode[state.decodeMode] || []) : [];
  }

  function getOrderedFields(packet) {
    const fields = getFields(packet);
    if (!packet) {
      return [];
    }
    const pref = ensurePref(packet);
    const ordered = pref.order
      .map((fieldId) => fields.find((field) => field.id === fieldId))
      .filter(Boolean);
    fields.forEach((field) => {
      if (!ordered.some((candidate) => candidate.id === field.id)) {
        ordered.push(field);
      }
    });
    return ordered;
  }

  function isHiddenDefault(packet, fieldId) {
    const pref = ensurePref(packet);
    return pref.hidden.includes(fieldId);
  }

  function relativeTimeLabel(packet) {
    const zero = state.zeroTimePsByLane[packet.lane] || 0;
    const delta = packet.timePs - zero;
    const sign = delta >= 0 ? "+" : "-";
    return sign + formatNs(Math.abs(delta));
  }

  function formatNs(timePs) {
    return (timePs / 1000).toFixed(3) + " ns";
  }

  function escapeHtml(text) {
    return String(text == null ? "" : text)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;");
  }

  function render() {
    debugState.renderCount += 1;

    if (state.fatalError) {
      root.className = "";
      root.innerHTML = `
        <div class="window">
          <div class="shell">
            <div class="window-title">
              <span>${escapeHtml(manifest.meta.title || "Packet Analyzer")}</span>
              <small>Fatal load error</small>
            </div>
            <div class="content">
              <section class="trace-panel">
                <div class="panel-title"><span>Load Failure</span></div>
                <div class="trace-scroll">
                  <div class="empty-state">${escapeHtml(state.fatalError)}</div>
                </div>
              </section>
            </div>
          </div>
        </div>
      `;
      return;
    }

    ensureSelection();
    const lane = currentLane();
    const visible = visiblePackets();
    const selected = selectedPacket();
    const selectedField = ensureSelectedField(selected);
    const prevScrollTop = state.lastScrollTopByLane[state.lane] || 0;
    const loadingCurrentLane = state.loadingLane === state.lane || (!laneDataMap.has(state.lane) && !!currentLaneInfo().laneScript);
    const visibleCountLabel = loadingCurrentLane && !visible.length ? "loading..." : String(visible.length);
    const title = manifest.meta.title || "Packet Analyzer";
    const subtitle = manifest.meta.subtitle || "";

    root.className = "";
    root.innerHTML = `
      <div class="window">
        <div class="shell ${state.wrap ? "wrap-enabled" : ""}">
          <div class="window-title">
            <span>${escapeHtml(title)}</span>
            <small>${escapeHtml(subtitle)}</small>
          </div>
          <div class="summary-bar">
            ${summaryCard("Source", manifest.meta.sourceVcd || "n/a")}
            ${summaryCard("Frames", "F" + ((lane.frameIds || []).join(", F") || "n/a"))}
            ${summaryCard("Visible Packets", visibleCountLabel)}
            ${summaryCard("Decode", decodeModeLabel(state.decodeMode))}
          </div>
          <div class="toolbar">
            ${renderPrimaryToolbar()}
          </div>
          ${renderReferenceBar()}
          ${renderWaveEmbed()}
          <div class="content">
            <section class="trace-panel">
              <div class="panel-title">
                <span>Packet Trace</span>
                <span class="hint">Lane ${escapeHtml(String(state.lane))} | click row to synchronize Spec View, Details View, and Link Tracker</span>
              </div>
              <div class="trace-scroll" data-role="trace-scroll">
                ${renderTracePanelBody(visible, loadingCurrentLane)}
              </div>
            </section>
            <section class="side-panel">
              <div>
                <div class="side-tabs">
                  ${renderTab("spec", "Spec View")}
                  ${renderTab("details", "Details View")}
                  ${renderTab("tracker", "Link Tracker")}
                </div>
              </div>
              <div class="side-body">
                ${selected ? renderSidePanel(selected, visible, selectedField) : '<div class="empty-state">Select a packet row to inspect the 32-bit word.</div>'}
              </div>
            </section>
          </div>
          <div class="status-bar">
            <span class="status-pill">lane=${escapeHtml(String(state.lane))}</span>
            <span class="status-pill">loaded=${escapeHtml(Array.from(laneDataMap.keys()).sort((a, b) => a - b).join(",") || "none")}</span>
            <span class="status-pill">selected=${escapeHtml(selected ? "#" + selected.packetNo + " " + selected.kind : "none")}</span>
            <span class="status-pill">update=${escapeHtml(state.updateMode)}</span>
            <span class="status-pill">tracker=${escapeHtml(state.trackerFormat + "/" + state.trackerDensity)}</span>
            <span class="status-pill">generated=${escapeHtml(manifest.meta.generatedAt || "n/a")}</span>
          </div>
          ${debugMode ? renderDebugOverlay(selected, visible) : ""}
        </div>
      </div>
    `;

    const scroller = root.querySelector('[data-role="trace-scroll"]');
    if (scroller) {
      scroller.scrollTop = prevScrollTop;
    }
  }

  function renderTracePanelBody(visible, loadingCurrentLane) {
    if (loadingCurrentLane && !visible.length) {
      return `<div class="empty-state">Loading lane ${escapeHtml(String(state.lane))} payload script...</div>`;
    }
    if (!visible.length) {
      return '<div class="empty-state">Current filter buttons hide every packet in this lane.</div>';
    }
    return `<div class="trace-list">${visible.map((packet) => renderTraceRow(packet)).join("")}</div>`;
  }

  function summaryCard(label, value) {
    const text = value || "n/a";
    return `<div class="summary-card"><strong>${escapeHtml(label)}</strong><span class="summary-value" title="${escapeHtml(text)}">${escapeHtml(text)}</span></div>`;
  }

  function renderPrimaryToolbar() {
    const laneOptions = (manifest.lanes || [])
      .map((lane) => `<option value="${lane.lane}" ${Number(lane.lane) === state.lane ? "selected" : ""}>Lane ${escapeHtml(String(lane.lane))}</option>`)
      .join("");
    const decodeOptions = (manifest.decodeModes || [])
      .map((mode) => `<option value="${escapeHtml(mode.id)}" ${mode.id === state.decodeMode ? "selected" : ""}>${escapeHtml(mode.label)}</option>`)
      .join("");
    return `
      <div class="toolbar-group">
        <span class="toolbar-label">Lane</span>
        <select class="tool-select" data-action="lane-change">${laneOptions}</select>
      </div>
      <div class="toolbar-group">
        <span class="toolbar-label">Decode</span>
        <select class="tool-select" data-action="decode-change">${decodeOptions}</select>
      </div>
      <div class="toolbar-group">
        <span class="toolbar-label">Filter</span>
        ${FAMILY_ORDER.map((family) => renderToolbarToggle("family-toggle", family, FAMILY_LABELS[family], state.familyFilters[family])).join("")}
      </div>
      <div class="toolbar-group">
        <span class="toolbar-label">Behavior</span>
        ${renderToolbarToggle("wrap-toggle", "wrap", "Wrap", state.wrap)}
        ${renderToolbarToggle("update-mode", "click", "Update On Click", state.updateMode === "click")}
        ${renderToolbarToggle("update-mode", "scroll", "Update On Scroll", state.updateMode === "scroll")}
      </div>
    `;
  }

  function renderReferenceBar() {
    const waveUrl = manifest.meta.referenceWaveUrl || "";
    return `
      <div class="reference-bar">
        <div>
          <strong>Waveform Correlation</strong>
          <span>Use the current 3-panel WaveDrom surface as the shared-axis reference: 4 ingress lanes with 2 frames each feeding the merged 2-frame OPQ egress path.</span>
        </div>
        <div class="reference-actions">
          <button class="tool-button" type="button" data-action="wave-embed-toggle" data-value="${state.waveEmbedOpen ? "hide" : "show"}">${state.waveEmbedOpen ? "Hide Waveform" : "Show Waveform"}</button>
          ${waveUrl ? `<a href="${escapeHtml(waveUrl)}" target="_blank" rel="noreferrer">Open Port 8877 Wave Report</a>` : ""}
        </div>
      </div>
    `;
  }

  function renderWaveEmbed() {
    const waveUrl = manifest.meta.referenceWaveUrl || "";
    if (!waveUrl || !state.waveEmbedOpen) {
      return "";
    }
    return `
      <section class="wave-embed-panel">
        <div class="panel-title">
          <span>Shared-Axis Waveform Reference</span>
          <span class="hint">Ingress window, merged OPQ egress, and downstream payload view from the existing port 8877 report.</span>
        </div>
        <div class="wave-embed-body">
          <iframe
            class="wave-embed-frame"
            src="${escapeHtml(waveUrl)}"
            title="MuSiP shared-axis waveform reference"
            loading="lazy"
            referrerpolicy="no-referrer"
          ></iframe>
        </div>
      </section>
    `;
  }

  function renderToolbarToggle(action, value, label, active) {
    return `<button class="tool-button ${active ? "active" : ""}" type="button" data-action="${escapeHtml(action)}" data-value="${escapeHtml(value)}">${escapeHtml(label)}</button>`;
  }

  function renderTab(tabId, label) {
    return `<button class="side-tab ${state.viewTab === tabId ? "active" : ""}" type="button" data-action="tab" data-value="${escapeHtml(tabId)}">${escapeHtml(label)}</button>`;
  }

  function renderTraceRow(packet) {
    const selected = packet.rowId === state.selectedRowId;
    const expanded = state.expandedRows.has(packet.rowId);
    const fields = getOrderedFields(packet);
    const visibleFields = expanded ? fields : fields.filter((field) => !isHiddenDefault(packet, field.id));
    const hiddenCount = fields.length - visibleFields.length;
    return `
      <div class="trace-row ${selected ? "selected" : ""}" data-role="trace-row" data-row-id="${escapeHtml(packet.rowId)}">
        <div class="row-controls">
          <button
            class="tool-button subtle row-expander"
            type="button"
            title="${escapeHtml(expanded ? "Collapse row" : "Expand row")} | hold to toggle all ${packet.kindLabel} rows"
            data-action="toggle-row"
            data-row-id="${escapeHtml(packet.rowId)}"
            data-kind="${escapeHtml(packet.kind)}"
          >${expanded ? "▾" : "▸"}</button>
          ${renderFixedCard("Packet", "#" + packet.packetNo, packet.kindFamily)}
          ${renderFixedCard("Kind", packet.kindLabel, packet.kindFamily)}
          ${renderFixedCard("Frame", "F" + packet.frameId, packet.kindFamily)}
          ${renderFixedCard("Time", relativeTimeLabel(packet), packet.kindFamily)}
        </div>
        <div class="trace-fields">
          ${visibleFields.map((field) => renderFieldCard(packet, field, isHiddenDefault(packet, field.id))).join("")}
        </div>
        <div class="decode-note">
          ${escapeHtml(packet.decodeSummaryByMode[state.decodeMode])}
          ${hiddenCount > 0 && !expanded ? ` | ${hiddenCount} hidden field${hiddenCount === 1 ? "" : "s"} behind triangle` : ""}
        </div>
      </div>
    `;
  }

  function renderFixedCard(label, value, family) {
    const tone = fixedTone(family);
    return `
      <div class="fixed-card" style="border-color:${tone.border}; background:${tone.value};">
        <div class="fixed-label" style="background:${tone.label}; color:${tone.text}; border-bottom-color:${tone.border};">${escapeHtml(label)}</div>
        <div class="fixed-value" style="background:${tone.value}; color:${tone.text};">${escapeHtml(value)}</div>
      </div>
    `;
  }

  function fixedTone(family) {
    const map = {
      header: { label: "#b8cffb", value: "#f0f5ff", text: "#172d5c", border: "#8ca5d1" },
      timestamp: { label: "#b7e4df", value: "#effbf9", text: "#1a4a46", border: "#85b7b1" },
      debug: { label: "#f1c6cc", value: "#fff4f6", text: "#5d2232", border: "#c9969c" },
      subheader: { label: "#d7c8f1", value: "#faf6ff", text: "#44305c", border: "#a89ac1" },
      hit: { label: "#f2d7a8", value: "#fff9ea", text: "#5f4516", border: "#d0b078" },
      trailer: { label: "#bee1bb", value: "#f0faef", text: "#244622", border: "#91b48e" },
    };
    return map[family] || map.hit;
  }

  function renderFieldCard(packet, field, hiddenDefault) {
    const tooltip = [
      field.label + " " + field.bits,
      field.valueHex,
      field.valueDec,
      field.description,
    ].join(" | ");
    return `
      <div
        class="field-card ${hiddenDefault ? "hidden-default" : ""} ${state.selectedFieldId === field.id && packet.rowId === state.selectedRowId ? "field-selected" : ""}"
        data-field-card="1"
        data-row-id="${escapeHtml(packet.rowId)}"
        data-field-id="${escapeHtml(field.id)}"
        data-tooltip="${escapeHtml(tooltip)}"
      >
        <div class="field-label" style="background:${field.tone.label}; color:${field.tone.text}; border-bottom-color:${field.tone.border};">
          ${escapeHtml(field.label)} ${escapeHtml(field.bits)}
        </div>
        <div class="field-value" style="background:${field.tone.value}; color:${field.tone.text};">
          ${escapeHtml(field.valueHex)}
        </div>
      </div>
    `;
  }

  function renderSidePanel(packet, visible, selectedField) {
    if (state.viewTab === "details") {
      return renderDetailsPanel(packet, selectedField);
    }
    if (state.viewTab === "tracker") {
      return renderTrackerPanel(packet, visible);
    }
    return renderSpecPanel(packet, selectedField);
  }

  function renderSpecPanel(packet, selectedField) {
    const fields = getOrderedFields(packet);
    const activeField = selectedField || fields[0] || null;
    const primaryRow = state.specMode === "hex" ? renderSpecHexCells(packet, activeField) : renderSpecBitCells(packet, activeField);
    const secondaryRow = state.specMode === "hex" ? renderSpecBitCells(packet, activeField) : renderSpecHexCells(packet, activeField);
    return `
      <div class="side-toolbar">
        <button class="tool-button" type="button" data-action="packet-nav" data-value="-1">Prev</button>
        <button class="tool-button" type="button" data-action="packet-nav" data-value="1">Next</button>
        ${renderToolbarToggle("spec-mode", "hex", "Hex", state.specMode === "hex")}
        ${renderToolbarToggle("spec-mode", "bin", "Bin", state.specMode === "bin")}
      </div>
      <p class="pane-title">Spec View: packet #${escapeHtml(String(packet.packetNo))}</p>
      <p class="pane-subtitle">${escapeHtml(packet.kindLabel)} | ${escapeHtml(packet.rawHex)} | datak=${escapeHtml(packet.datakHex)} | cycle=${escapeHtml(String(packet.cycle))}</p>
      <div class="spec-window">
        <table class="spec-grid">
          <thead>
            <tr>
              <th>View</th>
              <th class="byte-band" colspan="8">Byte 3</th>
              <th class="byte-band" colspan="8">Byte 2</th>
              <th class="byte-band" colspan="8">Byte 1</th>
              <th class="byte-band" colspan="8">Byte 0</th>
            </tr>
            <tr>
              <th>Bits</th>
              ${Array.from({ length: 32 }, (_, index) => `<th class="bits">${31 - index}</th>`).join("")}
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>${state.specMode === "hex" ? "Primary Hex" : "Primary Bin"}</td>
              ${primaryRow}
            </tr>
            <tr>
              <td>${state.specMode === "hex" ? "Reference Bin" : "Reference Hex"}</td>
              ${secondaryRow}
            </tr>
            <tr class="field-name-row">
              <td>Field Names</td>
              ${fields.map((field) => renderSpecFieldNameCell(field, activeField)).join("")}
            </tr>
            <tr class="field-value-row">
              <td>Field Values</td>
              ${fields.map((field) => renderSpecFieldValueCell(field, activeField)).join("")}
            </tr>
          </tbody>
        </table>
        <div class="spec-ribbon">
          ${fields.map((field) => renderSpecRibbonField(field, activeField)).join("")}
        </div>
        ${activeField ? renderSpecSelectedField(activeField) : ""}
      </div>
      <p class="pane-subtitle">Update mode: ${escapeHtml(state.updateMode)}. When set to scroll, the side pane follows the first visible packet row.</p>
    `;
  }

  function renderSpecHexCells(packet, activeField) {
    const hex = packet.rawHex.replace(/^0x/, "");
    return hex.split("").map((nibble, index) => {
      const nibbleMsb = 31 - index * 4;
      const nibbleLsb = nibbleMsb - 3;
      const active = activeField && nibbleMsb >= activeField.lsb && nibbleLsb <= activeField.msb;
      return `<td class="bits ${active ? "spec-active-bit" : ""}" colspan="4">${escapeHtml(nibble)}</td>`;
    }).join("");
  }

  function renderSpecBitCells(packet, activeField) {
    const cells = [];
    for (let bit = 31; bit >= 0; bit -= 1) {
      const active = activeField && bit <= activeField.msb && bit >= activeField.lsb;
      cells.push(`<td class="bits ${active ? "spec-active-bit" : ""}">${(packet.data >> bit) & 1}</td>`);
    }
    return cells.join("");
  }

  function renderSpecFieldNameCell(field, activeField) {
    const active = activeField && activeField.id === field.id;
    return `
      <td colspan="${field.width}" class="${active ? "spec-field-selected" : ""}" style="background:${field.tone.label}; color:${field.tone.text}; text-align:center;">
        <button class="spec-band-button" type="button" data-action="select-field" data-value="${escapeHtml(field.id)}">${escapeHtml(field.label)}</button>
      </td>
    `;
  }

  function renderSpecFieldValueCell(field, activeField) {
    const active = activeField && activeField.id === field.id;
    const value = state.specMode === "hex" ? field.valueHex : field.valueBin;
    return `
      <td colspan="${field.width}" class="${active ? "spec-field-selected" : ""}" style="background:${field.tone.value}; color:${field.tone.text}; text-align:center;">
        <button class="spec-band-button spec-value-button" type="button" data-action="select-field" data-value="${escapeHtml(field.id)}">${escapeHtml(value)}</button>
      </td>
    `;
  }

  function renderSpecRibbonField(field, activeField) {
    const active = activeField && activeField.id === field.id;
    return `
      <button
        class="spec-ribbon-field ${active ? "active" : ""}"
        type="button"
        data-action="select-field"
        data-value="${escapeHtml(field.id)}"
        style="flex:${field.width} 1 0%; background:${field.tone.label}; color:${field.tone.text}; border-color:${field.tone.border};"
      >
        <span>${escapeHtml(field.label)}</span>
        <small>${escapeHtml(field.bits)}</small>
      </button>
    `;
  }

  function renderSpecSelectedField(field) {
    return `
      <div class="spec-selected" style="border-color:${field.tone.border}; background:${field.tone.value}; color:${field.tone.text};">
        <strong>${escapeHtml(field.label)} ${escapeHtml(field.bits)}</strong>
        <span>${escapeHtml(field.valueHex)} | ${escapeHtml(field.valueDec)} | ${escapeHtml(field.valueBin)}</span>
        <span>${escapeHtml(field.description)}</span>
      </div>
    `;
  }

  function renderDetailsPanel(packet, selectedField) {
    const fields = getOrderedFields(packet);
    return `
      <div class="side-toolbar">
        ${renderToolbarToggle("details-radix", "hex", "Hex", state.detailsRadix === "hex")}
        ${renderToolbarToggle("details-radix", "dec", "Dec", state.detailsRadix === "dec")}
      </div>
      <p class="pane-title">Details View</p>
      <p class="pane-subtitle">${escapeHtml(packet.kindLabel)} | absolute ${escapeHtml(packet.timeLabel)} | relative ${escapeHtml(relativeTimeLabel(packet))}</p>
      <table class="detail-table">
        <thead>
          <tr>
            <th>Field</th>
            <th>Bits</th>
            <th>Value</th>
            <th>Other Base</th>
            <th>Description</th>
          </tr>
        </thead>
        <tbody>
          ${detailMetaRows(packet)}
          ${fields.map((field) => renderDetailFieldRow(field, selectedField)).join("")}
        </tbody>
      </table>
    `;
  }

  function detailMetaRows(packet) {
    const rows = [
      ["Packet", "#" + packet.packetNo, packet.kindLabel, "Selected packet row"],
      ["Lane", String(packet.lane), "F" + packet.frameId, "Current ingress lane and frame"],
      ["Cycle", String(packet.cycle), packet.datakHex, "Trace cycle and datak nibble"],
      ["Raw Word", packet.rawHex, packet.rawBin, "Original 32-bit word as captured from the VCD"],
    ];
    return rows.map((row) => `<tr><td>${escapeHtml(row[0])}</td><td class="mono">meta</td><td class="mono">${escapeHtml(row[1])}</td><td class="mono">${escapeHtml(row[2])}</td><td>${escapeHtml(row[3])}</td></tr>`).join("");
  }

  function renderDetailFieldRow(field, selectedField) {
    const active = selectedField && selectedField.id === field.id;
    const primary = state.detailsRadix === "hex" ? field.valueHex : field.valueDec;
    const secondary = state.detailsRadix === "hex" ? field.valueDec : field.valueHex;
    return `
      <tr class="${active ? "selected-field" : ""}">
        <td><button class="detail-field-button" type="button" data-action="select-field" data-value="${escapeHtml(field.id)}">${escapeHtml(field.label)}</button></td>
        <td class="mono">${escapeHtml(field.bits)}</td>
        <td class="mono">${escapeHtml(primary)}</td>
        <td class="mono">${escapeHtml(secondary)}</td>
        <td>${escapeHtml(field.description)}</td>
      </tr>
    `;
  }

  function renderTrackerPanel(packet, visible) {
    const rows = trackerRows(visible, packet);
    return `
      <div class="side-toolbar">
        ${renderToolbarToggle("tracker-format", "fields", "Fields", state.trackerFormat === "fields")}
        ${renderToolbarToggle("tracker-format", "hex", "0x", state.trackerFormat === "hex")}
        ${renderToolbarToggle("tracker-format", "bin", "Bin", state.trackerFormat === "bin")}
        ${renderToolbarToggle("tracker-format", "desc", "Desc", state.trackerFormat === "desc")}
        ${renderToolbarToggle("tracker-density", "1x", "1x", state.trackerDensity === "1x")}
        ${renderToolbarToggle("tracker-density", "2x", "2x", state.trackerDensity === "2x")}
        ${renderToolbarToggle("tracker-density", "4x", "4x", state.trackerDensity === "4x")}
        ${renderToolbarToggle("tracker-sync", state.trackerSync ? "on" : "off", state.trackerSync ? "Sync" : "Freeze", state.trackerSync)}
      </div>
      <p class="pane-title">Link Tracker</p>
      <p class="pane-subtitle">Synchronized to the selected packet row with format/compression controls matching the analyzer workflow more closely.</p>
      <table class="tracker-table">
        <thead>
          <tr>
            <th>Pkt</th>
            <th>Kind</th>
            <th>Frame</th>
            <th>Tracker Content</th>
          </tr>
        </thead>
        <tbody>
          ${rows.map((row) => renderTrackerRow(row, packet)).join("")}
        </tbody>
      </table>
    `;
  }

  function trackerRows(visible, packet) {
    if (!visible.length) {
      return [];
    }
    if (!state.trackerSync) {
      return visible.slice(0, 14);
    }
    const idx = visible.findIndex((item) => item.rowId === packet.rowId);
    const start = Math.max(0, idx - 6);
    return visible.slice(start, start + 13);
  }

  function renderTrackerRow(row, selected) {
    const selectedClass = row.rowId === selected.rowId ? "selected-packet" : "";
    return `
      <tr class="${selectedClass}" data-row-id="${escapeHtml(row.rowId)}">
        <td class="mono">#${escapeHtml(String(row.packetNo))}</td>
        <td>${escapeHtml(row.kindLabel)}</td>
        <td class="mono">F${escapeHtml(String(row.frameId))}</td>
        <td>
          <div class="tracker-stream">
            ${trackerTokens(row).map((token) => renderTrackerToken(token)).join("")}
          </div>
        </td>
      </tr>
    `;
  }

  function trackerTokens(packet) {
    if (state.trackerFormat === "hex") {
      return rawHexTokens(packet);
    }
    if (state.trackerFormat === "bin") {
      return rawBinaryTokens(packet);
    }
    if (state.trackerFormat === "desc") {
      return descriptionTokens(packet);
    }
    return fieldTokens(packet);
  }

  function rawHexTokens(packet) {
    const word = packet.rawHex.replace(/^0x/, "");
    if (state.trackerDensity === "4x") {
      return [neutralToken(packet.rawHex)];
    }
    if (state.trackerDensity === "2x") {
      return [neutralToken("0x" + word.slice(0, 4)), neutralToken("0x" + word.slice(4))];
    }
    return word.match(/.{1,2}/g).map((chunk) => neutralToken("0x" + chunk));
  }

  function rawBinaryTokens(packet) {
    const groups = packet.rawBin.split(" ");
    if (state.trackerDensity === "4x") {
      return [neutralToken(packet.rawBin.replaceAll(" ", ""))];
    }
    if (state.trackerDensity === "2x") {
      return [
        neutralToken(groups.slice(0, 4).join("")),
        neutralToken(groups.slice(4).join("")),
      ];
    }
    return groups.map((group) => neutralToken(group));
  }

  function descriptionTokens(packet) {
    if (state.trackerDensity === "4x") {
      return [neutralToken(packet.kindLabel)];
    }
    if (state.trackerDensity === "2x") {
      return [neutralToken(packet.decodeSummaryByMode[state.decodeMode])];
    }
    return [
      neutralToken(packet.kindLabel),
      neutralToken(packet.decodeSummaryByMode[state.decodeMode]),
      neutralToken("cycle " + packet.cycle),
      neutralToken(relativeTimeLabel(packet)),
    ];
  }

  function fieldTokens(packet) {
    const fields = getOrderedFields(packet);
    if (state.trackerDensity === "4x") {
      return [neutralToken(packet.decodeSummaryByMode[state.decodeMode])];
    }
    const visibleFields = state.trackerDensity === "2x" ? fields.filter((field) => field.defaultVisible !== false).slice(0, 4) : fields;
    return visibleFields.map((field) => ({
      text: state.trackerDensity === "2x" ? shortFieldLabel(field) + " " + field.valueHex : shortFieldLabel(field) + "=" + field.valueHex,
      label: field.label,
      style: `background:${field.tone.value}; color:${field.tone.text}; border-color:${field.tone.border};`,
    }));
  }

  function neutralToken(text) {
    return {
      text: text,
      label: "raw",
      style: "",
    };
  }

  function shortFieldLabel(field) {
    return field.label
      .replace(/\s+/g, "")
      .replace(/PackageCnt/g, "Pkg")
      .replace(/Subheaders/g, "Shd")
      .replace(/SendTSCnt/g, "Send")
      .replace(/Reserved/g, "Rsvd");
  }

  function renderTrackerToken(token) {
    return `<span class="tracker-token" title="${escapeHtml(token.label)}" style="${token.style}">${escapeHtml(token.text)}</span>`;
  }

  function decodeModeLabel(modeId) {
    const mode = (manifest.decodeModes || []).find((item) => item.id === modeId);
    return mode ? mode.label : modeId;
  }

  function renderDebugOverlay(selected, visible) {
    return `
      <aside class="debug-panel" data-role="debug-overlay">
        <strong>Visual Debug</strong>
        <div>boot=${escapeHtml(debugState.bootState)} render=${escapeHtml(String(debugState.renderCount))} errors=${escapeHtml(String(debugState.errors.length))}</div>
        <div>lane=${escapeHtml(String(state.lane))} loaded=[${escapeHtml(Array.from(laneDataMap.keys()).sort((a, b) => a - b).join(","))}] visible=${escapeHtml(String(visible.length))}</div>
        <div>selected=${escapeHtml(selected ? selected.rowId : "none")} field=${escapeHtml(state.selectedFieldId || "none")}</div>
        <div>tab=${escapeHtml(state.viewTab)} tracker=${escapeHtml(state.trackerFormat + "/" + state.trackerDensity)}</div>
        <div class="debug-log">
          ${debugState.actions.slice(0, 8).map((entry) => `<div>${escapeHtml(entry.action)} ${escapeHtml(entry.detail)}</div>`).join("")}
        </div>
      </aside>
    `;
  }

  function bindEvents() {
    root.addEventListener("click", onClick);
    root.addEventListener("change", onChange);
    root.addEventListener("mousemove", onMouseMove);
    root.addEventListener("mouseover", onMouseOver);
    root.addEventListener("mouseout", onMouseOut);
    root.addEventListener("contextmenu", onContextMenu);
    root.addEventListener("pointerdown", onPointerDown);
    root.addEventListener("pointerup", clearHoldTimer);
    root.addEventListener("pointerleave", clearHoldTimer);
    root.addEventListener("scroll", onTraceScroll, true);
    document.addEventListener("click", onDocumentClick);
    window.addEventListener("resize", hideTooltip);
    window.addEventListener("scroll", hideTooltip, true);
  }

  function onClick(event) {
    const fieldEl = event.target.closest("[data-field-card]");
    if (fieldEl) {
      const rowId = fieldEl.getAttribute("data-row-id");
      const fieldId = fieldEl.getAttribute("data-field-id");
      if (rowId) {
        state.selectedRowId = rowId;
      }
      state.selectedFieldId = fieldId || "";
      recordAction("field-click", rowId + ":" + (fieldId || ""));
      render();
      return;
    }

    const actionEl = event.target.closest("[data-action]");
    if (actionEl) {
      if (actionEl.getAttribute("data-action") === "toggle-row" && holdTriggered) {
        holdTriggered = false;
        return;
      }
      handleAction(actionEl);
      return;
    }

    const rowEl = event.target.closest("[data-row-id]");
    if (rowEl) {
      const rowId = rowEl.getAttribute("data-row-id");
      if (rowId) {
        state.selectedRowId = rowId;
        ensureSelectedField(selectedPacket());
        recordAction("row-select", rowId);
        render();
      }
    }
  }

  function handleAction(actionEl) {
    const action = actionEl.getAttribute("data-action");
    const value = actionEl.getAttribute("data-value") || "";
    recordAction(action, value);

    if (action === "tab") {
      state.viewTab = value;
      render();
      return;
    }
    if (action === "family-toggle") {
      state.familyFilters[value] = !state.familyFilters[value];
      ensureSelection();
      ensureSelectedField(selectedPacket());
      render();
      return;
    }
    if (action === "wrap-toggle") {
      state.wrap = !state.wrap;
      render();
      return;
    }
    if (action === "wave-embed-toggle") {
      state.waveEmbedOpen = !state.waveEmbedOpen;
      render();
      return;
    }
    if (action === "update-mode") {
      state.updateMode = value;
      render();
      return;
    }
    if (action === "spec-mode") {
      state.specMode = value;
      render();
      return;
    }
    if (action === "details-radix") {
      state.detailsRadix = value;
      render();
      return;
    }
    if (action === "tracker-format") {
      state.trackerFormat = value;
      render();
      return;
    }
    if (action === "tracker-density") {
      state.trackerDensity = value;
      render();
      return;
    }
    if (action === "tracker-sync") {
      state.trackerSync = !state.trackerSync;
      render();
      return;
    }
    if (action === "packet-nav") {
      navigatePackets(Number(value));
      return;
    }
    if (action === "toggle-row") {
      toggleRow(actionEl.getAttribute("data-row-id"));
      return;
    }
    if (action === "select-field") {
      state.selectedFieldId = value;
      render();
    }
  }

  function onChange(event) {
    const selectEl = event.target.closest("select[data-action]");
    if (!selectEl) {
      return;
    }
    const action = selectEl.getAttribute("data-action");
    if (action === "lane-change") {
      void setLane(Number(selectEl.value));
      return;
    }
    if (action === "decode-change") {
      state.decodeMode = selectEl.value;
      ensureSelectedField(selectedPacket());
      recordAction("decode-change", state.decodeMode);
      render();
    }
  }

  async function setLane(lane) {
    state.lastScrollTopByLane[state.lane] = getCurrentScrollTop();
    state.lane = lane;
    state.loadingLane = lane;
    ensureSelection();
    recordAction("lane-change", String(lane));
    render();
    try {
      await ensureLaneData(lane);
    } catch (error) {
      noteError(error);
    } finally {
      state.loadingLane = null;
      ensureSelection();
      ensureSelectedField(selectedPacket());
      render();
    }
  }

  function getCurrentScrollTop() {
    const scroller = root.querySelector('[data-role="trace-scroll"]');
    return scroller ? scroller.scrollTop : 0;
  }

  function navigatePackets(delta) {
    const visible = visiblePackets();
    const idx = visible.findIndex((packet) => packet.rowId === state.selectedRowId);
    if (idx === -1) {
      return;
    }
    const nextIdx = Math.max(0, Math.min(visible.length - 1, idx + delta));
    state.selectedRowId = visible[nextIdx].rowId;
    ensureSelectedField(selectedPacket());
    render();
    scrollRowIntoView(state.selectedRowId);
  }

  function toggleRow(rowId) {
    if (!rowId) {
      return;
    }
    if (state.expandedRows.has(rowId)) {
      state.expandedRows.delete(rowId);
    } else {
      state.expandedRows.add(rowId);
    }
    render();
  }

  function onPointerDown(event) {
    const expander = event.target.closest('[data-action="toggle-row"]');
    if (!expander) {
      return;
    }
    clearHoldTimer();
    holdTriggered = false;
    const kind = expander.getAttribute("data-kind");
    holdTimer = window.setTimeout(() => {
      holdTriggered = true;
      const visible = visiblePackets().filter((packet) => packet.kind === kind);
      const shouldExpand = visible.some((packet) => !state.expandedRows.has(packet.rowId));
      visible.forEach((packet) => {
        if (shouldExpand) {
          state.expandedRows.add(packet.rowId);
        } else {
          state.expandedRows.delete(packet.rowId);
        }
      });
      recordAction("toggle-row-kind", kind || "");
      render();
    }, 450);
  }

  function clearHoldTimer() {
    if (holdTimer) {
      window.clearTimeout(holdTimer);
      holdTimer = null;
    }
  }

  function onMouseOver(event) {
    const fieldEl = event.target.closest("[data-field-card]");
    if (!fieldEl) {
      return;
    }
    showTooltip(fieldEl.getAttribute("data-tooltip") || "", event.clientX, event.clientY);
  }

  function onMouseMove(event) {
    if (!tooltipEl.hidden) {
      moveTooltip(event.clientX, event.clientY);
    }
  }

  function onMouseOut(event) {
    const fieldEl = event.target.closest("[data-field-card]");
    if (fieldEl && event.relatedTarget && fieldEl.contains(event.relatedTarget)) {
      return;
    }
    if (fieldEl) {
      hideTooltip();
    }
  }

  function onContextMenu(event) {
    const fieldEl = event.target.closest("[data-field-card]");
    if (!fieldEl) {
      return;
    }
    event.preventDefault();
    const rowId = fieldEl.getAttribute("data-row-id");
    const fieldId = fieldEl.getAttribute("data-field-id");
    const packet = rowId ? packetMap.get(rowId) : null;
    if (!packet || !fieldId) {
      return;
    }
    state.selectedRowId = rowId;
    state.selectedFieldId = fieldId;
    ensureSelectedField(packet);
    openContextMenu(event.clientX, event.clientY, packet, fieldId);
    recordAction("context-open", rowId + ":" + fieldId);
    render();
  }

  function onDocumentClick(event) {
    if (!menuEl.hidden && !event.target.closest(".context-menu")) {
      closeContextMenu();
    }
  }

  function onTraceScroll(event) {
    const scroller = event.target.closest('[data-role="trace-scroll"]');
    if (!scroller) {
      return;
    }
    state.lastScrollTopByLane[state.lane] = scroller.scrollTop;
    if (state.updateMode !== "scroll") {
      return;
    }
    if (scrollRaf) {
      return;
    }
    scrollRaf = window.requestAnimationFrame(() => {
      scrollRaf = 0;
      const firstVisible = firstVisibleRow(scroller);
      if (firstVisible && firstVisible !== state.selectedRowId) {
        state.selectedRowId = firstVisible;
        ensureSelectedField(selectedPacket());
        recordAction("scroll-sync", firstVisible);
        render();
      }
    });
  }

  function firstVisibleRow(scroller) {
    const rows = Array.from(scroller.querySelectorAll(".trace-row[data-row-id]"));
    const top = scroller.scrollTop;
    const found = rows.find((row) => row.offsetTop + row.offsetHeight > top + 2);
    return found ? found.getAttribute("data-row-id") : "";
  }

  function scrollRowIntoView(rowId) {
    const rowEl = root.querySelector(`.trace-row[data-row-id="${CSS.escape(rowId)}"]`);
    if (rowEl) {
      rowEl.scrollIntoView({ block: "nearest" });
    }
  }

  function showTooltip(text, x, y) {
    const parts = text.split(" | ");
    tooltipEl.innerHTML = `<strong>${escapeHtml(parts[0] || "")}</strong>${parts.slice(1).map((part) => `<div>${escapeHtml(part)}</div>`).join("")}`;
    tooltipEl.hidden = false;
    moveTooltip(x, y);
  }

  function moveTooltip(x, y) {
    const left = Math.min(window.innerWidth - 380, x + 14);
    const top = Math.min(window.innerHeight - 180, y + 16);
    tooltipEl.style.left = Math.max(8, left) + "px";
    tooltipEl.style.top = Math.max(8, top) + "px";
  }

  function hideTooltip() {
    tooltipEl.hidden = true;
  }

  function openContextMenu(x, y, packet, fieldId) {
    const pref = ensurePref(packet);
    const idx = pref.order.indexOf(fieldId);
    const hidden = pref.hidden.includes(fieldId);
    menuState = { packetKind: packet.kind, fieldId: fieldId };
    menuEl.innerHTML = [
      menuItem("toggle-default", hidden ? "Show Field By Default" : "Hide Field By Default"),
      menuItem("move-left", "Move Field Left", idx <= 0),
      menuItem("move-right", "Move Field Right", idx === -1 || idx >= pref.order.length - 1),
      menuItem("zero-time", "Zero Timestamp At This Packet"),
      menuItem("reset-layout", "Reset Field Layout"),
    ].join("");
    menuEl.hidden = false;
    menuEl.style.left = x + "px";
    menuEl.style.top = y + "px";
    menuEl.querySelectorAll(".context-item").forEach((item) => {
      item.addEventListener("click", onMenuItemClick);
    });
  }

  function menuItem(action, label, disabled) {
    return `<div class="context-item${disabled ? " muted" : ""}" data-menu-action="${escapeHtml(action)}" data-disabled="${disabled ? "1" : "0"}">${escapeHtml(label)}</div>`;
  }

  function onMenuItemClick(event) {
    const item = event.currentTarget;
    if (item.getAttribute("data-disabled") === "1" || !menuState) {
      closeContextMenu();
      return;
    }
    const packet = selectedPacket();
    if (!packet) {
      closeContextMenu();
      return;
    }
    const pref = ensurePref(packet);
    const action = item.getAttribute("data-menu-action");
    const fieldId = menuState.fieldId;
    recordAction("context-" + action, fieldId);

    if (action === "toggle-default") {
      if (pref.hidden.includes(fieldId)) {
        pref.hidden = pref.hidden.filter((id) => id !== fieldId);
      } else {
        pref.hidden = pref.hidden.concat(fieldId);
      }
    } else if (action === "move-left") {
      moveField(pref.order, fieldId, -1);
    } else if (action === "move-right") {
      moveField(pref.order, fieldId, 1);
    } else if (action === "zero-time") {
      state.zeroTimePsByLane[packet.lane] = packet.timePs;
    } else if (action === "reset-layout") {
      const key = prefKey(state.decodeMode, packet.kind);
      const defaults = buildDefaultFieldPrefs()[key];
      if (defaults) {
        state.fieldPrefs[key] = {
          order: defaults.order.slice(),
          hidden: defaults.hidden.slice(),
        };
      }
    }
    saveFieldPrefs();
    closeContextMenu();
    render();
  }

  function moveField(order, fieldId, delta) {
    const idx = order.indexOf(fieldId);
    if (idx === -1) {
      return;
    }
    const next = idx + delta;
    if (next < 0 || next >= order.length) {
      return;
    }
    const tmp = order[idx];
    order[idx] = order[next];
    order[next] = tmp;
  }

  function closeContextMenu() {
    menuEl.hidden = true;
    menuState = null;
  }
})();
