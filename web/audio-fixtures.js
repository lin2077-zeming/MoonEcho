export const DEFAULT_SAMPLE_RATE = 16000;

export function encodePcm16Wav(samples, sampleRate = DEFAULT_SAMPLE_RATE) {
  const bytesPerSample = 2;
  const dataSize = samples.length * bytesPerSample;
  const buffer = new ArrayBuffer(44 + dataSize);
  const view = new DataView(buffer);

  writeAscii(view, 0, "RIFF");
  view.setUint32(4, 36 + dataSize, true);
  writeAscii(view, 8, "WAVE");
  writeAscii(view, 12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, sampleRate * bytesPerSample, true);
  view.setUint16(32, bytesPerSample, true);
  view.setUint16(34, 16, true);
  writeAscii(view, 36, "data");
  view.setUint32(40, dataSize, true);

  for (let index = 0; index < samples.length; index += 1) {
    const clamped = Math.max(-1, Math.min(1, samples[index]));
    const quantized = Math.round(clamped * 32767);
    view.setInt16(44 + index * bytesPerSample, quantized, true);
  }

  return new Uint8Array(buffer);
}

export function parseWavInfo(bytes) {
  if (bytes.byteLength < 44) {
    return null;
  }
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  if (readAscii(view, 0, 4) !== "RIFF" || readAscii(view, 8, 4) !== "WAVE") {
    return null;
  }

  let offset = 12;
  let format = null;
  let dataOffset = 0;
  let dataSize = 0;
  while (offset + 8 <= view.byteLength) {
    const chunkId = readAscii(view, offset, 4);
    const chunkSize = view.getUint32(offset + 4, true);
    const chunkStart = offset + 8;
    if (chunkId === "fmt " && chunkStart + 16 <= view.byteLength) {
      format = {
        audioFormat: view.getUint16(chunkStart, true),
        channels: view.getUint16(chunkStart + 2, true),
        sampleRate: view.getUint32(chunkStart + 4, true),
        bitsPerSample: view.getUint16(chunkStart + 14, true),
      };
    } else if (chunkId === "data") {
      dataOffset = chunkStart;
      dataSize = chunkSize;
      break;
    }
    offset = chunkStart + chunkSize + (chunkSize % 2);
  }

  if (!format || format.channels <= 0 || dataOffset <= 0) {
    return null;
  }
  const bytesPerSample = Math.max(1, format.bitsPerSample / 8);
  const frameCount = Math.floor(dataSize / (bytesPerSample * format.channels));
  return {
    ...format,
    dataOffset,
    dataSize,
    frameCount,
    durationSeconds: frameCount / format.sampleRate,
  };
}

export function extractWaveform(bytes, buckets = 180) {
  const info = parseWavInfo(bytes);
  if (!info || info.audioFormat !== 1 || info.bitsPerSample !== 16) {
    return null;
  }
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const sampleCount = info.frameCount * info.channels;
  const bucketSize = Math.max(1, Math.floor(sampleCount / buckets));
  const output = new Float32Array(buckets);

  for (let bucket = 0; bucket < buckets; bucket += 1) {
    const start = bucket * bucketSize;
    const end = Math.min(sampleCount, start + bucketSize);
    let peak = 0;
    for (let sample = start; sample < end; sample += 1) {
      const value = view.getInt16(
        info.dataOffset + sample * 2,
        true,
      );
      peak = Math.max(peak, Math.abs(value) / 32768);
    }
    output[bucket] = peak;
  }
  return { info, peaks: output };
}

export function buildDemoCorpus() {
  const sampleRate = DEFAULT_SAMPLE_RATE;
  const duration = 3.6;
  const frameCount = Math.floor(sampleRate * duration);
  const trackA = new Float32Array(frameCount);
  const trackB = new Float32Array(frameCount);

  let phase = 0;
  for (let index = 0; index < frameCount; index += 1) {
    const t = index / frameCount;
    const frequency = 280 + 1320 * t;
    phase += (2 * Math.PI * frequency) / sampleRate;
    trackA[index] = 0.68 * Math.sin(phase) + 0.08 * Math.sin(phase * 2.01);
  }

  for (let index = 0; index < frameCount; index += 1) {
    const t = index / sampleRate;
    const burst = Math.floor(t / 0.45) % 2;
    const frequency = burst === 0 ? 615 : 1230;
    const local = (t % 0.45) / 0.45;
    const envelope = local < 0.16 ? local / 0.16 : (1 - local) / 0.84;
    trackB[index] = 0.58 * envelope * Math.sin(2 * Math.PI * frequency * t);
  }

  const clipStartSeconds = 1.15;
  const clipSeconds = 0.68;
  const clipStart = Math.floor(clipStartSeconds * sampleRate);
  const clipFrames = Math.floor(clipSeconds * sampleRate);
  const query = new Float32Array(clipFrames);
  const random = mulberry32(0x4d4f4f4e);
  for (let index = 0; index < clipFrames; index += 1) {
    const source = trackA[clipStart + index] ?? 0;
    query[index] = source * 0.74 + (random() * 2 - 1) * 0.012;
  }

  return {
    sampleRate,
    tracks: [
      {
        id: 1,
        name: "Chirp reference",
        bytes: encodePcm16Wav(trackA, sampleRate),
        sourceSamples: trackA,
      },
      {
        id: 2,
        name: "Tone-burst confuser",
        bytes: encodePcm16Wav(trackB, sampleRate),
        sourceSamples: trackB,
      },
    ],
    query: {
      name: "Chirp clip + noise",
      bytes: encodePcm16Wav(query, sampleRate),
      sourceSamples: query,
    },
    expectedTrackId: 1,
    expectedOffsetSeconds: clipStartSeconds,
  };
}

function mulberry32(seed) {
  let value = seed >>> 0;
  return () => {
    value += 0x6d2b79f5;
    let result = value;
    result = Math.imul(result ^ (result >>> 15), result | 1);
    result ^= result + Math.imul(result ^ (result >>> 7), result | 61);
    return ((result ^ (result >>> 14)) >>> 0) / 4294967296;
  };
}

function writeAscii(view, offset, value) {
  for (let index = 0; index < value.length; index += 1) {
    view.setUint8(offset + index, value.charCodeAt(index));
  }
}

function readAscii(view, offset, length) {
  let value = "";
  for (let index = 0; index < length; index += 1) {
    value += String.fromCharCode(view.getUint8(offset + index));
  }
  return value;
}
