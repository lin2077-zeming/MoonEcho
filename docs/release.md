# Release and Acceptance Checklist

## Publication Status

`lin2077-zeming/moonecho@0.1.0` was published to Mooncakes.io on 2026-10-11:

https://mooncakes.io/docs/#/lin2077-zeming/moonecho/

## Mooncakes.io Preparation

The module metadata is in `moon.mod`:

- module name: `lin2077-zeming/moonecho`
- version: `0.1.0`
- license: `Apache-2.0`
- repository: `https://github.com/lin2077-zeming/MoonEcho`
- readme: `README.mbt.md`
- keywords: `audio`, `fingerprint`, `search`, `alignment`, `wasm`

Inspect the exact publish archive before uploading:

```bash
moon package --list
moon package
moon publish --dry-run
```

`moon publish` requires a Mooncakes.io account and credentials:

```bash
moon login
moon publish
```

Do not publish a version that has already been uploaded. Update `moon.mod` and
the release notes together when preparing the next version.

With the pinned `moonc` `0.10.14+7d59c7ec9`, `moon publish --dry-run` reports
`Server status: 202 Accepted` and a successful server-side dry run, but the
command currently exits non-zero afterward. Treat the server status text as the
validation result for that toolchain, and use the real authenticated publish
command only after the package and CI checks are green.

## Required Checks

Run from the repository root:

```bash
moon fmt --check
moon check --target all --deny-warn
moon test --target wasm --deny-warn
moon test --target native --deny-warn
npm run build:demo
npm run smoke:demo
```

The release candidate is ready when:

- CI is green
- the generated WASM demo loads in a browser
- the built-in query selects `Chirp reference`
- the README quickstart works on a clean checkout
- `LICENSE` and `THIRD_PARTY_NOTICES.md` are present
- `moon package --list` contains the package source and documentation

## Tagging

After the release checks pass:

```bash
git tag -a v0.1.0 -m "MoonEcho v0.1.0"
git push origin v0.1.0
```

The tag is a marker only. The Mooncakes.io version comes from `moon.mod`.
