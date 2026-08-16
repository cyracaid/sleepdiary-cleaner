# Testing Coverage

The pipeline includes 190+ testthat expectations across 12 test files,
all exercising software correctness — does the code do what it was
designed to do — as distinct from methodological validity, which is
covered in the validation-methodology vignette.

``` r
library(splsleep)
```

## Test files and coverage

| Test File                          | Coverage                                                                                                                                                          |
|------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `test-normalize.R`                 | AM/PM correction, minor order errors, midnight crossing, edge cases                                                                                               |
| `test-interval.R`                  | Colon-format edge cases in duration parsing                                                                                                                       |
| `test-pipeline.R`                  | End-to-end run on synthetic data, config loading, column adaptation                                                                                               |
| `test-sleep-diary.R`               | S3 construction, validation, coercion, generics, step-contract assertion, provenance                                                                              |
| `test-flag-standards.R`            | Flag evaluators for field misentry, data category, duration extreme, flag severity, checkforerrors; step-ledger logging                                           |
| `test-correction-engine.R`         | Every classification outcome (order/bed-sleep/awake-getup/24h errors, equal-time, unusual, skipped-NA, multiple errors, suspicious-latency flags)                 |
| `test-classification-thresholds.R` | Boundary behavior at every classification threshold (7h error, 3h/15h unusual, suspicious-latency)                                                                |
| `test-auto-detection-thresholds.R` | SOL/SE/TST-TIB boundary behavior for the Step 8 auto-detection flags                                                                                              |
| `test-finalize-columns.R`          | Dictionary ↔︎ delivered-column consistency, A/B join key uniqueness, unit transforms, reserved-column pass-through, export guard, missing/optional-column handling |
| `test-nonfinite-guards.R`          | NA/Inf handling in duration and flag-severity evaluators (regression tests for two real bugs)                                                                     |
| `test-config-data.R`               | Config file loading (RDS/CSV, legacy keys, column mapping, friendly error messages)                                                                               |
| `test-script-copies-in-sync.R`     | Root and `inst/scripts/` copies of every dual-maintained script stay byte-identical                                                                               |

## How to run the tests

``` r
# Installed-package mode (fast, tests the built package):
testthat::test_package("splsleep")

# Source-development mode (tests the working tree; use this when editing
# code — test_dir() alone does NOT load the package, so load it first):
pkgload::load_all(".")
testthat::test_dir("tests/testthat")

# Preferred dev workflow (loads source + runs tests in one call, needs
# devtools installed):
devtools::test()
```

Full package check (documentation, examples, tests, and the
`verify_reference_fidelity` / dual-copy checks):

``` r
devtools::check()   # needs devtools; equivalently: R CMD check splsleep_*.tar.gz
```

`devtools` is a development-only tool — it is intentionally **not** a
dependency of the package (not in `DESCRIPTION`), so it is never
required to install or run splsleep itself.

## Snapshot verification

Snapshot verification (`inst/verification/`, `verify_v1_3_snapshot.R`)
confirms the current S3 pipeline chain produces byte-identical output to
the legacy pipeline path on real data. `verify_reference_fidelity.R`
separately pins each of the 8 core metric formulas against a documented
baseline (`--strict` mode is CI-wired).
