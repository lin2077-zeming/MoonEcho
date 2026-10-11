# Third-Party Notices

MoonEcho depends on the following third-party MoonBit packages. They remain
under their original licenses and copyright notices.

## Ridge-Lab/moonwavkit 0.1.3

- Repository: https://github.com/Ridge-Lab/MoonWavKit
- License: MIT
- Copyright: 2026 Ridge-Lab
- Use in MoonEcho: RIFF/WAVE parsing, PCM decoding, downmixing, gain,
  normalization, and linear resampling.

## chgttyyr/MoonSpectrum 0.2.2

- Repository: https://github.com/chgttyyr/MoonSpectrum
- License: Apache-2.0
- Copyright: 2026 chgttyyr
- Use in MoonEcho: FFT, STFT, windows, spectral analysis, and synthetic signal
  generation used by tests and benchmarks.

## moonbitlang/x 0.4.45

- Repository: https://github.com/moonbitlang/x
- License: Apache-2.0
- Copyright: 2025 International Digital Economy Academy and contributors
- Use in MoonEcho: filesystem and string utilities used by the CLI and tests.

## MoonBit Toolchain

- Project: https://www.moonbitlang.com
- Repository: https://github.com/moonbitlang
- License: Apache-2.0
- Use in MoonEcho: compiler, build system, and standard library.

The demo's browser code and generated WASM artifact are built from MoonEcho's
source and the dependencies above. No third-party audio samples are bundled;
the built-in demo corpus is generated deterministically in JavaScript.

The Apache-2.0 license text is available in this repository at `LICENSE`.

## MIT License Text

The following text applies to `Ridge-Lab/moonwavkit`:

```text
MIT License

Copyright (c) 2026 Ridge-Lab

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
