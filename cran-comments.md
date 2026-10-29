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

- Local: macOS (darwin), R 4.6.0 (2026-04-24), `R CMD check`
  - Manual (PDF) build passes (TinyTeX/TeX available locally).
  - Test suite under `R CMD check` (the same on the three CI platforms,
    2026-10-29): 858 testthat expectations pass, 0 fail, 9 skipped (48 test
    files, 290 `test_that()` blocks). The skips are by design: tests that need
    repository files that are not part of the installed package (`tools/`,
    `README.md`, the agent skill file) or real study deliverables, which are
    not in the tarball.
- GitHub Actions, `R CMD check` (`--as-cran`):
  - ubuntu-latest
  - windows-latest
  - macos-latest

## R CMD check results

0 errors | 0 warnings | 0 notes

`R CMD check` on the source tarball with vignettes built: R 4.6.0 (2026-04-24),
macOS (aarch64-apple-darwin23), `--no-manual`. `Status: OK`.

Under `--as-cran` the only additional output is the expected "New submission"
NOTE from `checking CRAN incoming feasibility`.

The check outputs present in earlier drafts are resolved in this version:

- `checking for portable file names ... WARNING` came from a paper workspace
  directory that was not listed in `.Rbuildignore`. It is excluded from the
  build now; the source tarball shrank from 2.0 MB to 0.83 MB.
- `checking for code/documentation mismatches ... WARNING` came from two
  `man/*.Rd` pages that had not been regenerated after their argument defaults
  changed (`figure12_step_flag_table(filename = )`, `resolve_data_tag(ask = )`).
  Both now match the code.
- The earlier "assignments to the global environment" NOTE is gone; see below.

## Notes for the reviewer

- The package does not write into the global environment. Run state lives in a
  package-private environment (`R/state.R`), and `test-no-globalenv.R` asserts
  that a run leaves `.GlobalEnv` identical. `run_pipeline(export_env = )` copies
  results outward only when that argument is supplied (default `NULL`). The two
  `get0(..., envir = globalenv())` calls in `R/state.R` are read-only fallbacks
  that let the legacy `source()`-based entry point see objects the user created
  by hand; nothing is assigned there. The supported S3 interface
  (`run_pipeline()` and the `step_*()` chain) does not read the global
  environment at all.
- Real study data are not bundled. All examples, tests and vignettes run
  against the synthetic fixture in `inst/extdata/`. Real-data files are excluded
  twice over: `.gitignore` keeps them out of version control and `.Rbuildignore`
  keeps them out of the tarball. Every tarball built for this submission was
  checked to contain only `DESCRIPTION`, `LICENSE`, `NAMESPACE`, `README.md`,
  and the `R/`, `man/`, `inst/`, `tests/`, `vignettes/` trees.
- A previous submission failed `checking tests` on the Debian (R-devel)
  pre-test with `CCTZ: Unrecognized output timezone: "US/Pacific"`. The
  legacy `US/Pacific` alias is not recognized by lubridate's CCTZ on
  Debian; it has been replaced with the canonical `America/Los_Angeles`
  in `R/timestamp_parse.R` and the legacy `inst/scripts/process_timestamp_
  emadatarelease_cyra.R` copy. No other timezone aliases remain.

## Reverse dependencies

No reverse dependencies (new submission).
