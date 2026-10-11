import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { buildDemoCorpus } from "../web/audio-fixtures.js";

const root = resolve(import.meta.dirname, "..");
const wasmPath = resolve(root, "web/moonecho.wasm");
const bytes = readFileSync(wasmPath);
const imports = {
  moonecho_host: {
    bytes_length: (value) => value.length,
    bytes_get: (value, index) => value[index],
  },
};

const { instance } = await WebAssembly.instantiate(bytes, imports);
const demo = instance.exports;
const corpus = buildDemoCorpus();

const resetCode = demo.moonecho_demo_reset();
if (resetCode !== 0) {
  throw new Error(`demo reset failed: ${resetCode}`);
}
for (const track of corpus.tracks) {
  const result = demo.moonecho_demo_index_track(track.id, track.bytes);
  if (result !== 0) {
    throw new Error(
      `index failed for track ${track.id}: ${demo.moonecho_demo_last_error()}`,
    );
  }
}
const trackCount = demo.moonecho_demo_track_count();
if (trackCount !== corpus.tracks.length) {
  throw new Error(`expected ${corpus.tracks.length} tracks, got ${trackCount}`);
}

const matchCode = demo.moonecho_demo_match(corpus.query.bytes);
if (matchCode !== 0) {
  throw new Error(`match failed: ${demo.moonecho_demo_last_error()}`);
}
const status = demo.moonecho_demo_last_status();
const trackId = demo.moonecho_demo_last_track_id();
const confidence = demo.moonecho_demo_last_confidence();
const correlation = demo.moonecho_demo_last_correlation();
const offsetSeconds = demo.moonecho_demo_last_offset_seconds();

if (status < 1 || trackId !== corpus.expectedTrackId) {
  throw new Error(`unexpected match: status=${status}, track=${trackId}`);
}
if (confidence <= 0.05 || correlation < 0.8) {
  throw new Error(
    `weak verification: confidence=${confidence}, correlation=${correlation}`,
  );
}
if (Math.abs(offsetSeconds - corpus.expectedOffsetSeconds) > 0.08) {
  throw new Error(
    `offset mismatch: expected ${corpus.expectedOffsetSeconds}, got ${offsetSeconds}`,
  );
}

console.log(
  `WASM demo smoke passed: track=${trackId}, status=${status}, ` +
    `offset=${offsetSeconds.toFixed(3)}s, confidence=${confidence.toFixed(3)}, ` +
    `correlation=${correlation.toFixed(3)}`,
);
