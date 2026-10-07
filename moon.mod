// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "lin2077-zeming/moonecho"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/lin2077-zeming/MoonEcho"

license = "Apache-2.0"

keywords = [ "audio", "fingerprint", "search", "alignment", "wasm" ]

preferred_target = "wasm"

description = "Local-first acoustic fingerprint search and audio alignment toolkit for MoonBit."

import {
  "Ridge-Lab/moonwavkit@0.1.3",
  "chgttyyr/MoonSpectrum@0.2.2",
}
