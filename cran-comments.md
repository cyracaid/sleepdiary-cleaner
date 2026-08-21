## Test environments

- Local: macOS (darwin), R 4.6.0 (2026-04-24), `R CMD check --as-cran --no-manual`
  - Manual (PDF) build skipped locally because `pdflatex` is not installed
    on this machine; LaTeX is available on CRAN servers, and the manual
    already passes the Rd-to-LaTeX conversion stage, so this is an
    environment limitation only.
  - Test suite: 307 testthat expectations pass, 0 fail (21 test files,
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
- A local check without `--no-manual` reports one ERROR solely because
  `pdflatex` is missing from this machine; the error message is
  `pdflatex is not available` (from `texi2dvi`) and is unrelated to the
  package contents. CRAN servers ship TeX and will build the manual normally.

## Reverse dependencies

No reverse dependencies (new submission).