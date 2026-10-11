import {
  buildDemoCorpus,
  extractWaveform,
  parseWavInfo,
} from "./audio-fixtures.js";

const ui = {
  runtimeStatus: document.querySelector("#runtime-status"),
  runtimeDot: document.querySelector("#runtime-dot"),
  wasmFileStatus: document.querySelector("#wasm-file-status"),
  loadDemo: document.querySelector("#load-demo"),
  buildIndex: document.querySelector("#build-index"),
  runMatch: document.querySelector("#run-match"),
  resetDemo: document.querySelector("#reset-demo"),
  actionStatus: document.querySelector("#action-status"),
  resultSummary: document.querySelector("#result-summary"),
  resultTitle: document.querySelector("#results-title"),
  resultBadge: document.querySelector("#result-badge"),
  resultCaption: document.querySelector("#result-caption"),
  metricTrack: document.querySelector("#metric-track"),
  metricOffset: document.querySelector("#metric-offset"),
  metricConfidence: document.querySelector("#metric-confidence"),
  metricCorrelation: document.querySelector("#metric-correlation"),
  metricTracks: document.querySelector("#metric-tracks"),
  metricPostings: document.querySelector("#metric-postings"),
  metricHashes: document.querySelector("#metric-hashes"),
  metricConsidered: document.querySelector("#metric-considered"),
  metricVotes: document.querySelector("#metric-votes"),
  metricCandidates: document.querySelector("#metric-candidates"),
  matchTime: document.querySelector("#match-time"),
  timelineOffset: document.querySelector("#timeline-offset"),
  timeline: document.querySelector("#timeline"),
  slots: {
    a: {
      panel: document.querySelector("#panel-a"),
      canvas: document.querySelector("#wave-a"),
      name: document.querySelector("#name-a"),
      rate: document.querySelector("#rate-a"),
      frames: document.querySelector("#frames-a"),
      duration: document.querySelector("#duration-a"),
      input: document.querySelector("#file-a"),
    },
    b: {
      panel: document.querySelector("#panel-b"),
      canvas: document.querySelector("#wave-b"),
      name: document.querySelector("#name-b"),
      rate: document.querySelector("#rate-b"),
      frames: document.querySelector("#frames-b"),
      duration: document.querySelector("#duration-b"),
      input: document.querySelector("#file-b"),
    },
    query: {
      panel: document.querySelector("#panel-query"),
      canvas: document.querySelector("#wave-query"),
      name: document.querySelector("#name-query"),
      rate: document.querySelector("#rate-query"),
      frames: document.querySelector("#frames-query"),
      duration: document.querySelector("#duration-query"),
      input: document.querySelector("#file-query"),
    },
  },
};

const state = {
  wasm: null,
  busy: false,
  indexBuilt: false,
  demoCorpus: null,
  slots: {
    a: null,
    b: null,
    query: null,
  },
  lastResult: null,
};

const demoButtonState = () => {
  const runtimeReady = state.wasm !== null;
  ui.buildIndex.disabled =
    !runtimeReady || state.busy || state.slots.a === null;
  ui.runMatch.disabled =
    !runtimeReady || state.busy || !state.indexBuilt ||
    state.slots.query === null;
  ui.resetDemo.disabled = state.busy;
};

function setRuntimeStatus(message, kind = "loading") {
  ui.runtimeStatus.textContent = message;
  const shell = ui.runtimeDot.parentElement;
  shell.classList.toggle("is-ready", kind === "ready");
  shell.classList.toggle("is-error", kind === "error");
}

function setActionStatus(message) {
  ui.actionStatus.textContent = message;
}

function setBusy(isBusy, message) {
  state.busy = isBusy;
  if (message) {
    setActionStatus(message);
  }
  demoButtonState();
}

function formatSeconds(value) {
  return `${value.toFixed(3)} s`;
}

function formatPercent(value) {
  return `${(value * 100).toFixed(1)}%`;
}

function trackLabel(trackId) {
  if (trackId === 1) {
    return "Library A";
  }
  if (trackId === 2) {
    return "Library B";
  }
  return "-";
}

function describeError(code) {
  switch (code) {
    case 1:
      return "The WAV could not be decoded or analyzed.";
    case 2:
      return "The track id is invalid.";
    case 3:
      return "That track id already exists in the index.";
    case 4:
      return "The index rejected the track.";
    case 5:
      return "Build the index before running a query.";
    case 6:
      return "The fingerprint query could not be evaluated.";
    default:
      return "The WASM pipeline returned an error.";
  }
}

function setSlot(slotName, source) {
  const info = parseWavInfo(source.bytes);
  const waveform = extractWaveform(source.bytes, 180);
  const slot = {
    ...source,
    info,
    peaks: waveform?.peaks ?? new Float32Array(180),
  };
  state.slots[slotName] = slot;
  state.indexBuilt = false;
  state.lastResult = null;
  const view = ui.slots[slotName];
  view.name.textContent = slot.name;
  view.rate.textContent = info ? `${info.sampleRate} Hz` : "-";
  view.frames.textContent = info ? info.frameCount.toLocaleString() : "-";
  view.duration.textContent = info ? formatSeconds(info.durationSeconds) : "-";
  renderSlotWaveform(slotName);
  renderEmptyResult();
  setActionStatus(`${slot.name} loaded.`);
  demoButtonState();
}

function setFileError(slotName, message) {
  setActionStatus(message);
  ui.slots[slotName].name.textContent = "Unreadable WAV";
}

async function readWaveFile(slotName, file) {
  try {
    const bytes = new Uint8Array(await file.arrayBuffer());
    if (!parseWavInfo(bytes)) {
      throw new Error("invalid WAV");
    }
    setSlot(slotName, { name: file.name, bytes });
  } catch {
    setFileError(slotName, `${file.name} is not a readable PCM WAV.`);
  }
}

function drawEmptyCanvas(canvas, message = "Waiting for audio") {
  const context = prepareCanvas(canvas);
  const { width, height } = canvas;
  context.clearRect(0, 0, width, height);
  context.fillStyle = "#f9fbf9";
  context.fillRect(0, 0, width, height);
  context.strokeStyle = "#d4dbd5";
  context.lineWidth = 1;
  context.beginPath();
  context.moveTo(0, height / 2);
  context.lineTo(width, height / 2);
  context.stroke();
  context.fillStyle = "#8a948f";
  context.font = '12px "Segoe UI", sans-serif';
  context.textAlign = "center";
  context.textBaseline = "middle";
  context.fillText(message, width / 2, height / 2);
}

function renderSlotWaveform(slotName) {
  const slot = state.slots[slotName];
  const canvas = ui.slots[slotName].canvas;
  if (!slot || !slot.info) {
    drawEmptyCanvas(canvas);
    return;
  }
  drawWaveform(canvas, slot.peaks, slotName === "query" ? "#c05621" : "#0f766e");
}

function drawWaveform(canvas, peaks, color) {
  const context = prepareCanvas(canvas);
  const { width, height } = canvas;
  context.clearRect(0, 0, width, height);
  context.fillStyle = "#f9fbf9";
  context.fillRect(0, 0, width, height);
  context.strokeStyle = "#d4dbd5";
  context.lineWidth = 1;
  context.beginPath();
  context.moveTo(0, height / 2);
  context.lineTo(width, height / 2);
  context.stroke();
  const barWidth = width / peaks.length;
  context.fillStyle = color;
  context.globalAlpha = 0.86;
  for (let index = 0; index < peaks.length; index += 1) {
    const amplitude = Math.max(1, peaks[index] * (height * 0.43));
    context.fillRect(
      index * barWidth,
      height / 2 - amplitude,
      Math.max(1, barWidth - 1),
      amplitude * 2,
    );
  }
  context.globalAlpha = 1;
}

function prepareCanvas(canvas) {
  const ratio = window.devicePixelRatio || 1;
  const width = Math.max(1, Math.floor(canvas.clientWidth * ratio));
  const height = Math.max(1, Math.floor(canvas.clientHeight * ratio));
  if (canvas.width !== width || canvas.height !== height) {
    canvas.width = width;
    canvas.height = height;
  }
  return canvas.getContext("2d");
}

function renderEmptyResult() {
  ui.resultSummary.className = "result-summary";
  ui.resultTitle.textContent = "No query yet";
  ui.resultBadge.textContent = "Idle";
  ui.resultBadge.className = "result-badge is-idle";
  ui.resultCaption.textContent = "Build an index to populate the search structure.";
  ui.metricTrack.textContent = "-";
  ui.metricOffset.textContent = "-";
  ui.metricConfidence.textContent = "-";
  ui.metricCorrelation.textContent = "-";
  ui.matchTime.textContent = "-";
  ui.timelineOffset.textContent = "-";
  renderTimeline();
}

function renderIndexStats() {
  if (!state.wasm) {
    return;
  }
  ui.metricTracks.textContent = state.wasm
    .moonecho_demo_track_count()
    .toLocaleString();
  ui.metricPostings.textContent = state.wasm
    .moonecho_demo_posting_count()
    .toLocaleString();
}

function renderResult(result) {
  const status = result.status;
  const variant = status >= 2 ? "strong" : status === 1 ? "weak" : "idle";
  ui.resultSummary.className = `result-summary is-${variant}`;
  ui.resultBadge.className = `result-badge is-${variant}`;
  ui.resultBadge.textContent =
    status >= 2 ? "Strong" : status === 1 ? "Weak" : "No match";
  ui.resultTitle.textContent =
    status === 0 ? "No confident candidate" : trackLabel(result.trackId);
  ui.resultCaption.textContent =
    status === 0
      ? "The query did not pass the current vote and confidence thresholds."
      : "The best fingerprint candidate was refined on the reference waveform.";
  ui.metricTrack.textContent = status === 0 ? "-" : trackLabel(result.trackId);
  ui.metricOffset.textContent = status === 0 ? "-" : formatSeconds(result.offsetSeconds);
  ui.metricConfidence.textContent =
    status === 0 ? "-" : formatPercent(result.confidence);
  ui.metricCorrelation.textContent =
    status === 0 ? "-" : result.correlation.toFixed(3);
  ui.metricHashes.textContent = result.queryHashes.toLocaleString();
  ui.metricConsidered.textContent = result.consideredPostings.toLocaleString();
  ui.metricVotes.textContent = result.votes.toLocaleString();
  ui.metricCandidates.textContent = result.candidates.toLocaleString();
  ui.matchTime.textContent = `${result.elapsedMs.toFixed(1)} ms`;
  ui.timelineOffset.textContent =
    status === 0 ? "-" : formatSeconds(result.offsetSeconds);
  renderTimeline();
}

function renderTimeline() {
  const canvas = ui.timeline;
  const context = prepareCanvas(canvas);
  const { width, height } = canvas;
  context.clearRect(0, 0, width, height);
  context.fillStyle = "#f9fbf9";
  context.fillRect(0, 0, width, height);

  const slot = state.slots.a;
  if (!slot?.info) {
    context.fillStyle = "#8a948f";
    context.font = '12px "Segoe UI", sans-serif';
    context.textAlign = "center";
    context.textBaseline = "middle";
    context.fillText("Library A is required", width / 2, height / 2);
    return;
  }

  const peaks = slot.peaks;
  const baseline = height * 0.68;
  context.strokeStyle = "#d4dbd5";
  context.lineWidth = 1;
  context.beginPath();
  context.moveTo(0, baseline);
  context.lineTo(width, baseline);
  context.stroke();

  context.fillStyle = "#0f766e";
  context.globalAlpha = 0.25;
  const barWidth = width / peaks.length;
  for (let index = 0; index < peaks.length; index += 1) {
    const amplitude = Math.max(1, peaks[index] * height * 0.42);
    context.fillRect(
      index * barWidth,
      baseline - amplitude,
      Math.max(1, barWidth - 1),
      amplitude,
    );
  }
  context.globalAlpha = 1;

  if (state.lastResult && state.lastResult.status > 0 && state.lastResult.trackId === 1) {
    const query = state.slots.query;
    const queryDuration = query?.info?.durationSeconds ?? 0;
    const trackDuration = slot.info.durationSeconds;
    const startX = Math.min(
      width,
      Math.max(0, (state.lastResult.offsetSeconds / trackDuration) * width),
    );
    const endX = Math.min(
      width,
      Math.max(startX, ((state.lastResult.offsetSeconds + queryDuration) / trackDuration) * width),
    );
    context.fillStyle = "#c05621";
    context.globalAlpha = 0.2;
    context.fillRect(startX, 0, Math.max(2, endX - startX), height);
    context.globalAlpha = 1;
    context.strokeStyle = "#c05621";
    context.lineWidth = 2;
    context.beginPath();
    context.moveTo(startX, 0);
    context.lineTo(startX, height);
    context.stroke();
    context.fillStyle = "#9a4218";
    context.font = '11px "Cascadia Mono", Consolas, monospace';
    context.textAlign = "left";
    context.fillText("query", Math.min(width - 36, startX + 6), 16);
  }
}

function renderAllWaveforms() {
  renderSlotWaveform("a");
  renderSlotWaveform("b");
  renderSlotWaveform("query");
  renderTimeline();
}

function loadBuiltInDemo() {
  state.demoCorpus = buildDemoCorpus();
  for (const slotName of ["a", "b", "query"]) {
    ui.slots[slotName].input.value = "";
  }
  setSlot("a", {
    name: state.demoCorpus.tracks[0].name,
    bytes: state.demoCorpus.tracks[0].bytes,
  });
  setSlot("b", {
    name: state.demoCorpus.tracks[1].name,
    bytes: state.demoCorpus.tracks[1].bytes,
  });
  setSlot("query", {
    name: state.demoCorpus.query.name,
    bytes: state.demoCorpus.query.bytes,
  });
  if (state.wasm) {
    state.wasm.moonecho_demo_reset();
  }
  state.indexBuilt = false;
  state.lastResult = null;
  renderEmptyResult();
  renderIndexStats();
  setActionStatus("Built-in chirp corpus loaded.");
  demoButtonState();
}

async function loadWasm() {
  setRuntimeStatus("Loading WASM runtime", "loading");
  try {
    const response = await fetch("./moonecho.wasm", { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    const bytes = await response.arrayBuffer();
    const imports = {
      moonecho_host: {
        bytes_length: (value) => value.length,
        bytes_get: (value, index) => value[index],
      },
    };
    const { instance } = await WebAssembly.instantiate(bytes, imports);
    state.wasm = instance.exports;
    window.moonecho = state.wasm;
    ui.wasmFileStatus.textContent = `${(bytes.byteLength / 1024).toFixed(1)} KB WASM loaded`;
    setRuntimeStatus("WASM GC ready", "ready");
    setActionStatus("Runtime ready. Build the index.");
  } catch (error) {
    console.error(error);
    setRuntimeStatus("WASM runtime unavailable", "error");
    ui.wasmFileStatus.textContent = "Run node scripts/build-demo.mjs";
    setActionStatus("WASM load failed. Build the demo runtime first.");
  }
  demoButtonState();
}

function buildIndex() {
  if (!state.wasm || state.busy) {
    return;
  }
  setBusy(true, "Indexing library tracks...");
  const started = performance.now();
  try {
    const exports = state.wasm;
    state.lastResult = null;
    renderEmptyResult();
    exports.moonecho_demo_reset();
    const entries = [
      ["a", 1],
      ["b", 2],
    ];
    let count = 0;
    for (const [slotName, trackId] of entries) {
      const slot = state.slots[slotName];
      if (!slot) {
        continue;
      }
      const result = exports.moonecho_demo_index_track(trackId, slot.bytes);
      if (result !== 0) {
        throw new Error(describeError(exports.moonecho_demo_last_error()));
      }
      count += 1;
    }
    if (count === 0) {
      throw new Error("Load at least one library WAV.");
    }
    state.indexBuilt = true;
    state.lastResult = null;
    renderEmptyResult();
    renderIndexStats();
    const elapsed = performance.now() - started;
    setActionStatus(
      `Indexed ${count} track${count === 1 ? "" : "s"} in ${elapsed.toFixed(0)} ms.`,
    );
  } catch (error) {
    state.lastResult = null;
    state.indexBuilt = false;
    setActionStatus(error.message);
    renderEmptyResult();
  } finally {
    setBusy(false);
  }
}

function runMatch() {
  if (!state.wasm || state.busy || !state.indexBuilt) {
    return;
  }
  setBusy(true, "Matching query and refining alignment...");
  const started = performance.now();
  try {
    const exports = state.wasm;
    const result = exports.moonecho_demo_match(state.slots.query.bytes);
    if (result !== 0) {
      throw new Error(describeError(exports.moonecho_demo_last_error()));
    }
    const elapsedMs = performance.now() - started;
    state.lastResult = {
      status: exports.moonecho_demo_last_status(),
      trackId: exports.moonecho_demo_last_track_id(),
      offsetFrames: exports.moonecho_demo_last_offset_frames(),
      offsetSeconds: exports.moonecho_demo_last_offset_seconds(),
      confidence: exports.moonecho_demo_last_confidence(),
      correlation: exports.moonecho_demo_last_correlation(),
      votes: exports.moonecho_demo_last_votes(),
      queryHashes: exports.moonecho_demo_last_query_hashes(),
      consideredPostings: exports.moonecho_demo_last_considered_postings(),
      candidates: exports.moonecho_demo_last_candidate_count(),
      elapsedMs,
    };
    renderResult(state.lastResult);
    setActionStatus(`Query completed in ${elapsedMs.toFixed(1)} ms.`);
  } catch (error) {
    state.lastResult = null;
    setActionStatus(error.message);
    renderEmptyResult();
  } finally {
    setBusy(false);
  }
}

function resetDemo() {
  if (state.wasm) {
    state.wasm.moonecho_demo_reset();
  }
  state.indexBuilt = false;
  state.lastResult = null;
  renderEmptyResult();
  renderIndexStats();
  setActionStatus("Index state cleared.");
  demoButtonState();
}

ui.loadDemo.addEventListener("click", loadBuiltInDemo);
ui.buildIndex.addEventListener("click", buildIndex);
ui.runMatch.addEventListener("click", runMatch);
ui.resetDemo.addEventListener("click", resetDemo);

ui.slots.a.input.addEventListener("change", (event) => {
  const file = event.target.files?.[0];
  if (file) {
    readWaveFile("a", file);
  }
});
ui.slots.b.input.addEventListener("change", (event) => {
  const file = event.target.files?.[0];
  if (file) {
    readWaveFile("b", file);
  }
});
ui.slots.query.input.addEventListener("change", (event) => {
  const file = event.target.files?.[0];
  if (file) {
    readWaveFile("query", file);
  }
});

window.addEventListener("resize", renderAllWaveforms);

loadBuiltInDemo();
loadWasm();
