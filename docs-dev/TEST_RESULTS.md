# splsleep Package Test Results

**Date:** 2026-08-19
**R version:** 4.6.0
**Platform:** aarch64-apple-darwin23 (macOS Sequoia)
**CI:** ubuntu-latest + windows-latest + macos-latest, all green (R-CMD-check workflow)

## Test Summary (testthat, 16 test files)

```
test_that blocks: 100
expectations:    258
failed:          0
errors:          0
skips:           1 (local; 8 on CI where installed-package/docs-dev layout differs)
```

## Coverage

| Test file | Focus |
|---|---|
| `test-normalize.R` | Sequence normalization: AM/PM errors, <3h swaps, all-NA, bed=getup, 12h gaps |
| `test-interval.R` | Malformed colon formats ("00:000" → "00:00") |
| `test-pipeline.R` | End-to-end smoke on synthetic data, config loading, column adaptation |
| `test-script-copies-in-sync.R` | Root vs `inst/scripts/` copies byte-identical (dedup regression gate) |
| `test-generated-docs-in-sync.R` | AUTO-generated docs under `docs-dev/` stay byte-identical |
| `test-global-leakage.R` | Pipeline internals never leak into the global environment |
| `test-internalised-in-sync.R` | `R/` package wrappers vs `inst/scripts/` step scripts stay in sync |
| `test-smoke-legacy-entry.R` | Legacy `00_MAIN_entry.R` auto-run path (subprocess, sandboxed) |
| others | Per-module unit tests (config, flags, classification thresholds, finalize columns, nonfinite guards, sleep-diary S3, correction engine) |

## CI Status

- Three platforms (ubuntu / windows / macOS), `fail-fast: false`.
- Windows-specific fix 2026-08-19: tempfile() backslash paths injected into the
  smoke subprocess script broke Rscript parsing (`\U` escape); normalized to
  forward slashes. Commit 50c1592.

## Notes

- 8 skips are environmental (installed-package layout / missing docs-dev), not failures.
- Warnings in earlier runs were non-fatal deprecation notices; current test set runs clean.