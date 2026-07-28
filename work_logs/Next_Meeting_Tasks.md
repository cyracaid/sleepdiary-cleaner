# Next Meeting — Potential Tasks

**Project:** splsleep v1.3.1
**Date:** TBD
**Agenda goal:** Prioritize technical debt cleanup and v1.4.0 feature candidates.

---

## Agenda

1. TECH_DEBT items #1–3 — clear before new features?
2. Feature priority vote: circadian vs brms vs targets vs Step 8 chain
3. CRAN submission timeline — submit v1.3.1 as-is?
4. Human review workflow — is SQLite upgrade worth 1–2 weeks?

---

## Immediate (1 day each — clear documented debt)

| # | Task | Source |
|---|------|--------|
| 1 | **Internalize `process_timestamp()` / `process_interval()` into `R/steps.R`** | TECH_DEBT #2 |
| | Copy function bodies directly into step adapters. Eliminates `source()` → `sys.source()` for steps 2–3. ~600 lines mechanical move. Snapshot test gates safety. | |
| 2 | **Resolve root vs `inst/scripts/` duplicate scripts** | TECH_DEBT #1 |
| | Make `inst/scripts/` the single source of truth. Delete or thin-wrap root copies after all callers migrate to `scripts_dir()`. | |
| 3 | **Eliminate `cfg_get()` deprecated fallback warnings** | TECH_DEBT #3 |
| | Update all `source()`-d scripts to accept explicit `cfg` parameter. Remove the global-env warning path. | |

## Feature Candidates (v1.4.0)

| # | Task | Effort | Description |
|---|------|:--:|------|
| 4 | **Circadian rhythm analysis module** | 2–3 d | `circadian_analysis()` — standalone function: Cosinor regression + Lomb-Scargle periodogram. Returns phase, amplitude, mesor. With vignette. |
| 5 | **Bayesian hierarchical model vignette (brms)** | 2–3 d | `.Rmd`: cleaned data → `brms(SOL ~ caffeine + alcohol + (1\|pid))` → posterior checks → forest plot. Analysis demo — not in pipeline. |
| 6 | **`{targets}` incremental pipeline** | 3–5 d | DAG-aware caching. New 3 days of EMA → only rerun affected steps. Parallel execution. Auto-resume on crash. |
| 7 | **JSON Schema config validation** | 1 d | VSCode autocompletion for `config.yaml`. `{jsonvalidate}` + `inst/schema/`. |
| 8 | **Step 8 auto-detection into chain** | 2–3 d | Extract computational core of `checkforerrors_processing.R` → `step_auto_detect()` adapter. File I/O stays in `run_pipeline()`. |
| 9 | **Ledger persistence on `sleep_diary`** | 0.5 d | Attach flag ledger to S3 object. `summary()` works across R sessions. Auto-write CSV at chain end. |

## Infrastructure / Polish

| # | Task | Effort | Description |
|---|------|:--:|------|
| 10 | **CRAN NOTE cleanup** | 0.5 d | Resolve 2 remaining NOTEs for CRAN submission. |
| 11 | **pkgdown documentation site** | 0.5 d | `https://cyracaid.github.io/splsleep/` — function reference + vignettes. |
| 12 | **Column name single source of truth** | 1–2 d | Merge SCHEMA.md + validate_schema.R + config column mappings into one `R/schema.R`. |
| 13 | **Human review workflow → SQLite** | 1–2 w | `review_db$connect()` with task creation, decision tracking, rollback, query. Largest single feature. |

## Explicitly Not Doing

| Item | Reason |
|------|--------|
| KZ adaptive filter | Wrong tool for self-report diary data |
| Rcpp time parsing | 14K rows = 0.5s — no bottleneck exists |
| data.table migration | dplyr is fine at this scale; risk > reward |
| Isolation Forest / DBSCAN | Black-box anomaly detection replaces auditable rules |
| valgrind / sanitizer checks | Zero compiled code in the package |
| DAG abstraction layer | S3 chain + explicit cfg injection = sufficient data flow |

---

## Current State Reference

```
Version:     1.3.1
R CMD check: 0 ERROR, 0 WARNING, 2 NOTE
CI:          GitHub Actions — green
Tests:       76+ testthat tests
Releases:    v1.0.0 → v1.2.0 → v1.3.0
Branch:      main (9 commits ahead of v1.3.0 tag)
```

See also: `TECH_DEBT.md`, `ROADMAP.md`, `NEWS.md`, `work_logs/2026-07-28_Phase_Summary.md`
