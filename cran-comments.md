## Package summary

`sleepcleanr` is a reproducible R pipeline for cleaning intensive-longitudinal
sleep EMA diary data. It parses raw timestamp columns, detects and corrects
temporal and duration errors through a documented human-in-the-loop workflow
(with an audit ledger recording every disposition decision), computes standard
sleep metrics (TST, SOL, WASO, SE), and generates diagnostic and
research-ready figures. All study-specific mappings are configured via YAML,
so new studies can be added without code changes. Developed for the Stanford
Psychophysiology Laboratory's intensive-longitudinal sleep study
(github.com/stanford-sber). Formerly named `splsleep`; renamed to
`sleepcleanr` in this version. This is the package's first CRAN submission.

## Test environments

- Local: macOS (darwin), R 4.6.0 (2026-04-24), `R CMD check --as-cran`
  - Manual (PDF) build passes (TinyTeX/TeX available locally).
  - Test suite: 254 testthat expectations pass, 0 fail (21 test files,
    including the synthetic-fixture pipeline smoke test).
- GitHub Actions, `R CMD check` (`--as-cran`):
  - ubuntu-latest
  - windows-latest
  - macos-latest

## R CMD check results

0 errors | 0 warnings | 2 notes

> checking CRAN incoming feasibility ... NOTE
>   Maintainer: 'Cai Dong <cyracaid@gmail.com>'
>   New submission

This is a new submission, so the "New submission" note is expected.

> checking R code for possible problems ... NOTE
> Found the following assignments to the global environment:
> File 'sleepcleanr/R/manual_corrections.R': ...
> File 'sleepcleanr/R/pipeline.R': ...

See "Notes for the reviewer" below.

## Notes for the reviewer

- The package intentionally assigns a small number of objects into the global
  environment when running the legacy script-based entry point, which is
  retained for backward compatibility with the original analysis scripts and
  is exercised by the test suite. The supported S3 interface
  (`run_pipeline()` and the `step_*()` chain) does not do this.
- Real study data are not bundled. All examples, tests and vignettes run
  against the synthetic fixture in `inst/extdata/`; real-data outputs are
  excluded from the source tarball (`.Rbuildignore`).
- A previous submission failed `checking tests` on the Debian (R-devel)
  pre-test with `CCTZ: Unrecognized output timezone: "US/Pacific"`. The
  legacy `US/Pacific` alias is not recognized by lubridate's CCTZ on
  Debian; it has been replaced with the canonical `America/Los_Angeles`
  in `R/timestamp_parse.R` and the legacy `inst/scripts/process_timestamp_
  emadatarelease_cyra.R` copy. No other timezone aliases remain.

## Reverse dependencies

No reverse dependencies (new submission).
