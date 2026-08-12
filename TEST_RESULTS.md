# splsleep Package Test Results

**Date:** 2026-08-12
**R version:** 4.6.0
**Platform:** aarch64-apple-darwin23 (macOS Sequoia)

## Test Summary (testthat, 12 test files)

```
total: 90 tests
passed: 190
failed: 0
errors: 0
warnings: 39 (non-fatal: cfg_get() .GlobalEnv fallback deprecation notices, dplyr coercion)
skip: 1
```

## Coverage

| Test file | Focus |
|---|---|
| `test-normalize.R` | Sequence normalization: AM/PM errors, <3h swaps, all-NA, bed=getup, 12h gaps |
| `test-interval.R` | Malformed colon formats ("00:000" → "00:00") |
| `test-pipeline.R` | End-to-end smoke on synthetic data, config loading, column adaptation |
| `test-script-copies-in-sync.R` | Root vs `inst/scripts/` copies byte-identical (no new divergence) |
| others | Per-module unit tests (config, flags, figure steps, S3 chain) |

## Running Tests

```r
# From package root:
Rscript -e 'pkgload::load_all(quiet=TRUE); library(testthat); test_dir("tests/testthat", reporter="summary")'
```

Or via R CMD CHECK: `R CMD CHECK . --no-manual`

## Notes

- 39 warnings are non-fatal deprecation notices: `cfg_get()` read from `.GlobalEnv$pipeline_config` without explicit `cfg` (tracked in `TECH_DEBT.md` item 3) plus dplyr coercion notices.
- 1 skipped test is expected.
