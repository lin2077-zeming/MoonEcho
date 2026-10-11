# WASM Browser Demo

## Purpose

The browser demo runs the MoonEcho fingerprint and alignment pipeline as a
`wasm-gc` library. JavaScript handles file selection and presentation; WAV
decoding, STFT, peak extraction, fingerprinting, inverted-index lookup, offset
voting, and sample alignment execute in the MoonBit WASM module.

The built-in corpus is generated locally in JavaScript:

- a rising chirp reference track
- a tone-burst confuser track
- a noisy chirp query clip cut from the reference

No audio files or network requests are used by the demo itself.

## Build

```bash
npm run build:demo
```

This runs:

```bash
moon build src/web --target wasm-gc --release --deny-warn
```

and copies the generated artifact to `web/moonecho.wasm`. The `.wasm` file is
generated output and is ignored by Git.

## Run

```bash
npm run serve:demo
```

Open `http://127.0.0.1:4173`. The server is a dependency-free Node static
server for the `web/` directory.

The page also works with any static HTTP server:

```bash
python -m http.server 4173 --directory web
```

Opening `index.html` directly from `file://` is not supported because browser
security rules prevent `fetch("./moonecho.wasm")`.

## Verification

```bash
npm run smoke:demo
```

The smoke test instantiates the generated module in Node, indexes the two
built-in tracks, matches the query, and asserts:

- the expected track is selected
- confidence clears the configured floor
- sample correlation is at least `0.8`
- the refined offset is within 80 ms of the generated clip position

The same check runs in CI after the MoonBit tests.

## WASM ABI

The demo module imports two host functions:

```javascript
{
  moonecho_host: {
    bytes_length: (value) => value.length,
    bytes_get: (value, index) => value[index],
  },
}
```

The host function receives a browser `Uint8Array` as an `externref`,
`bytes_length` returns its byte length, and `bytes_get` returns one byte.
MoonBit converts those bytes into its own array representation and runs the
normal library pipeline.

Exported functions use the prefix `moonecho_demo_`:

- `moonecho_demo_reset`
- `moonecho_demo_index_track`
- `moonecho_demo_match`
- metadata getters for track count, posting count, match status, offset,
  confidence, correlation, votes, and query diagnostics

The exported API uses only scalar return values and `externref` inputs. This
keeps the browser boundary small and avoids serializing MoonBit strings or
internal objects.

## Browser Support

The demo requires:

- WebAssembly GC support
- `externref` support
- JavaScript modules

Current Chromium, Firefox, and Safari releases support these features. If the
module cannot be instantiated, the page reports that the runtime is unavailable
and leaves the generated-runtime path visible in the UI.
