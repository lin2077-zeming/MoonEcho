## Summary

## Milestone

- [ ] M0 project foundation
- [ ] M1 audio and spectrum
- [ ] M2 fingerprint and index
- [ ] M3 matching loop
- [ ] M4 demo and quality
- [ ] M5 acceptance and release

## Verification

```text
moon check --target all --deny-warn
moon test --target wasm --deny-warn
moon test --target native --deny-warn
```

## Checklist

- [ ] Tests cover the changed behavior.
- [ ] README or docs are updated.
- [ ] Examples are runnable.
- [ ] No third-party code or media is added without license notes.
