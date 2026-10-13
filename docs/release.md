# Release and Acceptance Checklist

## Publication Status

The current module version is `0.1.1`. Verify the live publication state with:

https://mooncakes.io/docs/#/lin2077-zeming/moonecho/

The machine-readable status endpoint is:

`https://mooncakes.io/api-new/v0/modules/lin2077-zeming/moonecho`

## Mooncakes.io Preparation

The module metadata is in `moon.mod`:

- module name: `lin2077-zeming/moonecho`
- version: `0.1.1`
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

With the pinned `moonc` `0.10.15+943464bfa`, `moon publish --dry-run` reports
`Server status: 202 Accepted` and a successful server-side dry run, but the
command currently exits non-zero afterward. Treat the server status text as the
validation result for that toolchain, and use the real authenticated publish
command only after the package and CI checks are green.

The same `moonc` release has a reproducible upstream `moon bundle --all`
planner panic for even a newly generated empty module:

```text
declared execution output has multiple producers: .../<module>.core
```

MoonEcho therefore uses `moon build --target all --release --deny-warn` as the
CI build gate. The bundle command remains documented here for evaluation, but
the panic is a toolchain issue rather than a project source failure.

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
git tag -a v0.1.1 -m "MoonEcho v0.1.1"
git push origin v0.1.1
```

The tag is a marker only. The Mooncakes.io version comes from `moon.mod`.
