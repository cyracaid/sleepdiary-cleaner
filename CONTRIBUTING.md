# Contributing to sleepcleanr

Thank you for considering contributing! This package cleans and validates
self-reported sleep-diary data (ECMA morning diaries: bed / sleep / awake /
get-up timestamps, SOL/WASO durations, and derived metrics TST, SOL, WASO, SE).

## Getting started

1. Fork the repository and clone your fork.
2. This project uses [renv](https://rstudio.github.io/renv/) for dependency
   management. Run `renv::restore()` after cloning to install the locked
   package versions.
3. Build and check the package before you start editing, so you have a green
   baseline:

   ```r
   devtools::install()
   devtools::test()
   ```

## Development workflow

- **Golden-baseline rule.** Run the test suite *before* your changes and
  record the counts. After your changes, the suite may only gain tests —
  removing or weakening an existing test requires a written justification in
  the PR description.
- **Tests.** New behaviour needs tests. Bug fixes need a test that fails
  before the fix and passes after it. Place tests in `tests/testthat/`
  following the existing file-per-function naming (`test-<function>.R`).
- **Documentation.** Every exported function needs a roxygen2 docblock;
  run `devtools::document()` so `man/` stays in sync with the code. A Codoc
  mismatch (documented arguments differing from code) fails `R CMD check`.
- **NEWS.md.** User-visible changes get an entry under the relevant version
  heading.
- **No threshold changes without validation.** Detection thresholds (3 h gap,
  12 h flip, metric flag boundaries) are validated against the synthetic
  benchmark and the Bland–Altman measurement-noise analysis. Changing a
  default requires re-running the operating-point sweep and including the
  updated results in your PR.
- **Figures.** If you change what a figure shows, update the corresponding
  figure card in `vignettes/interpreting-output.Rmd` (Sections 6–7 document
  every figure's parts, rules, and paper-ready captions).

## What the pipeline will never accept

- Cleaning logic that silently repairs data: every automated correction must
  set a `corrected`/`correction_type` marker, and unverifiable entries must
  be flagged for human review, never silently reinterpreted.
- Paths that "guess": configured input files are used as-is or the run stops
  with an error. The pipeline never searches for similarly-named files.
- Real participant data: never commit data files containing participant
  identifiers (`manual_*`, `fasttrack_*`, `disambiguation_*`, `sber_*`,
  `deidentified_*`, `audit_*`, `cleaned_*`, `real_data_config*`). Templates
  and synthetic stubs in `inst/extdata/` and `templates/` are the only data
  files in the repository.

## Pull requests

- One logical change per PR; include the rationale, not just the diff.
- CI runs `R CMD check` (macOS/Windows/Ubuntu), coverage, and pkgdown builds.
  All three must be green before merge.
- A maintainer review focuses on: silent-repair risk, threshold rationale,
  documentation/test sync, and data-leakage surface.

## Reporting bugs

Open an issue with: your R version, package version (`packageVersion("sleepcleanr")`),
the smallest input that reproduces the problem, and the full pipeline console
output. If the issue involves data that cannot be shared publicly, describe
the *shape* of the data (columns, formats) rather than the data itself.

## Code of conduct

By participating you agree to abide by the [Contributor Covenant Code of
Conduct](CODE_OF_CONDUCT.md).