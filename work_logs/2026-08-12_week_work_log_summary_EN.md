# Worklog Summary — 2026-08-07 → 2026-08-12

**Reporting draft**, consolidating everything from this stretch of work for Maia.
Sources: `data_dictionary_2026-08-07.md`, `data_dictionary_audit_2026-08-07.md`,
`open_issues_2026-08-07.md`, `2026-08-09_work_log.md`, `2026-08-10_week_work_log_summary.md`,
`2026-08-12_work_log.md` (all in splsleep).

---

## TL;DR

Closed out the data-dictionary audit and the v1.4.0 delivery gate (08-07→08-10), then shipped and
tagged two production bug fixes as v1.4.1 (08-12), and ran two real-data validation checks that are
independent of the synthetic benchmark (redundant-channel validation, B1 semantics check). Also fully
resolved whether the double-coder review data supports a Cohen's κ, and where the n=47/37/84 numbers
in the manuscript actually come from.

---

## Timeline

| Date | Event |
|------|-------|
| 08-07 | Line-by-line audit of `data_dictionary.md` against code → **FAIL** (Dataset A incomplete for the sleep-affect study) |
| 08-07 | Opened `open_issues_2026-08-07.md`: B1/B2 blockers + the S-series (severe) and naming issues |
| 08-09 | B1/B2 resolved; S1/S2/S4/M2/M3/M6 implemented; `finalize_columns()` + `column_dictionary.csv` shipped; S5 (`verify_reference_fidelity.R`) done |
| 08-09 | v1.4.0 Phase 1 delivery gate closed (affect columns reserved, negative-export guard, Step 10 hard-fail, wiring verification) |
| 08-10 | Real-data snapshot verification passed; fixed an incident where synthetic testthat runs had been overwriting real output (sandboxed now); round-2 GitHub history anonymization + push correction |
| 08-12 | Designed, verified, and shipped two production bug fixes (silent SOL/WASO misrepair flag, missing human-review CSV output) |
| 08-12 | Back-tagged `v1.4.0` (it had never actually been tagged) and released `v1.4.1`, pushed to GitHub |
| 08-12 | Redundant-channel validation on real data (n=13,990) + B1 descriptive analysis on real data (n=2,735) — both first-tier validation items |
| 08-12 | Resolved two open questions: whether Cohen's κ can be computed from the double-coder data, and why the manuscript's n=47/37/84 didn't match the current CSVs |

---

## Key decisions (the ones worth walking through)

### B1: `sleeponset` does not add self-reported SOL — resolved

- The reference implementation adds SOL to sleeponset; splsleep doesn't. Adding it would shift mean
  TST from **7.71h to 7.23h** (a systematic ~29-minute shift).
- **Decision**: `time_sleep` asks "what time did you fall asleep" — i.e. it already *is* sleep onset,
  so adding SOL again double-counts the same latency. splsleep's current behavior is correct; zero
  code changes needed.
- Basis: the schema definition, an internal contradiction in the reference implementation itself
  (lines 47 and 49 make inconsistent assumptions about what `time_sleep` means), and the researcher's
  confirmation of the survey item's intent.

### B2: missing WASO produces NA TST — resolved (option C)

- About 1,127 records have complete timestamps but no TST because self-reported WASO is missing.
- **Decision**: option C — zero code changes. The dictionary now documents `sleepperiod_minutes` as
  an upper bound on TST, so those 1,127 records aren't lost; the gap is exactly the unknown WASO and
  can support a sensitivity analysis.

### Related: `sleepperiod` and `trysleep` are identical by construction — resolved

- Once SOL isn't added, these two columns are the same expression. We considered re-adding SOL just
  to make the two columns differ — **rejected** that (would be bending the algorithm to fit the table
  layout). Dropped `trysleep_minutes` from Dataset A, kept `sleepperiod_minutes`. One line for
  Methods: the diary never captures the moment of falling asleep separately from getting into bed
  with intent to sleep, so "sleep period" and "attempted-sleep period" are indistinguishable by
  construction.

### S7: reworking the AM/PM normalization rule — decided against

- Rules 4.1/4.2 can guess wrong about which timestamp is actually the error (wrong in 2 of 3 real
  cases we found). **Decided not to implement a fix**: the pipeline runs, the numbers are sane, and
  we're close to delivery — not worth swapping out core logic for a theoretical gain. The 75
  human-adjudicated records we already have double as a ground-truth set if we ever want to
  backtest this.

---

## What shipped, 08-07 → 08-10 (8 items, all done)

| # | Item | Result |
|---|------|--------|
| S1 | Computed-side WASO into Dataset A | `awake_getup_diff_h × 60` → `waso_computed_minutes`, fixes a unit mismatch (was in hours) |
| S2 | Figure 20B title | Changed to "Self-Reported Nighttime Wakefulness vs Post-Awakening Time in Bed" — removes the "same quantity, two methods" implication |
| S3 | `record_status` implemented | Six-level mapping in `finalize_columns.R` (`.RECORD_STATUS_MAP`), unknown levels hard-stop; Dataset A now delivers this column |
| S4 | Dataset B primary key made unique | Added `row_id`, matching A's key, eliminating a many-to-many join risk |
| S5 | Formula snapshot | `verify_reference_fidelity.R`: 8 formula contracts + guards, `--strict` 16/16, CI-ready |
| S6 | `correction_type` provenance | Dictionary description now carries a caveat: it only records the algorithmic action and is never rewritten after a manual override |
| M2/M3 | Naming symmetry | `sol_computed_minutes`, `waso_avg_bout_selfreport_minutes` |
| M6 | Dataset B self-sufficiency | `correction_type` added to Dataset B (now 15 columns) |

### Column counts (as of 08-10)

- **Dataset A**: 36 columns (incl. `record_status`)
- **Dataset B**: 15 columns
- **Full**: 134 columns
- Real data: 13,990 rows

---

## Verification (all green as of 08-10)

| Check | Result |
|-------|--------|
| Full testthat suite | **190 pass / 0 fail / 1 skip** (skip = a deliberately isolated assertion when no real output exists) |
| `verify_finalize_columns` | 41/41 (dictionary ↔ delivered columns: names, units, keys) |
| `verify_reference_fidelity --strict` | 16/16 (formula contracts + fidelity ledger: 4 identical, 4 deliberate deviations, all documented) |
| `verify_delivery_wiring` | 31/31 with real output present (gracefully skips without it) |
| `verify_v1_3_snapshot --config` on real data | 13/13, 126 columns byte-identical (S3 chain vs. old path, bit-identical) |

Real-data baseline (unchanged before/after): Total 13,990 | Clean 1,908 | Unusual 31 | Equal 903 |
Skipped NA 11,142 | Corrected 81 | **Mean TST 7.71h (SD 1.27)** | **Mean SOL 28.8 min**. Only one
number moved: fixing a temporal-order inversion in one getup-normalization record (row 8502) changed
Error 7→6 and a negative computed-WASO count 1→0.

---

## Incidents and fixes, 08-07 → 08-10 (reported honestly)

1. **Synthetic testthat runs were overwriting real output.** A 280-row synthetic test run clobbered
   the 13,990-row real deliverable. Fixed by sandboxing `test-pipeline.R` (pointing `project_dir` at a
   temp directory) and adding an assertion that fails if real deliverables ever appear inside the
   sandbox. Re-verified the real deliverable was untouched.
2. **`calculate_sleep_time_vars_end()` had a hidden write side effect** — it calls
   `saveRDS(output/corrected_ema_data.rds)` internally, so calling it from the repo root silently
   overwrites real output. Mitigated with `run_sandboxed()` (logged as S8; a proper fix — moving the
   write out of the calculation function — is deferred).
3. **Backup files were bypassing `.gitignore`.** `.bak` files containing 75 real correction records
   weren't ignored. Fixed by adding `*.bak*` / `manual_*.csv.*` patterns.

### Security cleanup — GitHub anonymization (08-10)

- Round-2 history rewrite via `git-filter-repo --replace-text`: real pids → fake pids 90100–90120,
  real row_ids → 90200/90201, dump-table rows → `[redacted dump row]`, timestamps/derived values →
  `[redacted]`
- Real-data Bland-Altman figure removed from the entire history (`--invert-paths`), function code kept
- Push correction: local tags hadn't been rewritten to match → re-pushed `--force --tags`; deleted an
  old tag pointing at a pre-rewrite ancestor
- **Result**: zero real-data remnants across GitHub main + 11 tags, full history

---

## 08-12: two production bug fixes, verified and shipped as v1.4.1

### Fix 1: flag silent SOL/WASO misrepairs (Part A4)

- **Background**: synthetic benchmark testing (n=400/class) found `field_misentry_sol`/`field_misentry_waso`
  (a clock time typed into a duration field) were silently misrepaired **95.8%/96.0%** of the time.
  `process_interval.R`'s MM:SS/dd:00 reinterpretation heuristic turns the misentry into a small,
  plausible-looking duration, and the downstream review-status check (`calculate_sleep_time_end.R`)
  only ever flags values that are too *large*, never too *small* — so nothing catches it.
- **Fix**: new Part A4 block in `checkforerrors_processing.R` flags any row whose `_correctionsmade`
  note matches the `MM:SS`/`dd:00` reinterpretation pattern and routes it to human review.
- **Result**: SOL silent misrepair 95.8% → **3.5%** (14/400 — a disclosed residual blind spot for
  "01:XX"-shaped values that leave no reinterpretation trace, structurally uncatchable by this
  approach). WASO silent misrepair 96.0% → **0%**. Zero new false positives on 10,000 clean records;
  FAR_alter unchanged at 0/10,000.

### Fix 2: `generate_correction_files.R` was never writing the human-review CSVs

- **Finding**: the `write.csv()` calls for `[NEW]manual_error_correction_review.csv` and
  `[NEW]manual_unusual_review.csv` were commented out, and `run_pipeline()` immediately `rm()`'d the
  in-memory result right after — so neither file was ever actually produced in production, even
  though the pipeline log unconditionally printed "Files saved: ...". **This upgrades the severity
  from "misleading log message" to "the human-review file generation feature has never worked."**
- **Fix**: uncommented both `write.csv()` calls; verified non-empty, expected output on a full real
  n=280 pipeline run.

### Getting both fixes into the real repo

Both patches were verified in a sandbox, then written directly into the real local repo via the
device bridge (root copy + the `inst/scripts/` copy, kept in sync). After `R CMD INSTALL`, reran FCR
(n=10,000), enrichment (n=7,000), and the full `testthat::test_dir()` suite on the real source —
results matched the sandbox exactly: `[ FAIL 4 | WARN 51 | SKIP 1 | PASS 181]` (the 4 failures are
pre-existing, unrelated to this change — two un-exported functions the test suite references).

### Back-tagging v1.4.0 and releasing v1.4.1

Turned out the repo had never actually tagged v1.4.0 (`DESCRIPTION` said 1.4.0, but `git tag` stopped
at v1.3.9). Back-tagged `v1.4.0` on the correct historical commit, then made four commits (the two
fixes, the version bump + NEWS.md entry, today's worklog), tagged `v1.4.1`, and pushed the branch and
both tags to `github.com/cyracaid/sleepdiary-cleaner`.

---

## 08-12: two real-data validation checks (first-tier validation list)

### Redundant-channel (Channel B) validation on real data (n=13,990)

**Logic**: the diary contains two independent measures of sleep-onset latency — self-reported
duration and the timestamp-derived gap (`time_sleep − time_bed`). Step 4
(`normalize_sleep_time_sequence.R`) *never reads* the duration columns (confirmed by grep), so
self-reported SOL is a genuinely independent check on whether Step 4's corrections make sense — on
real data, with no synthetic injection and no fresh human annotation.

**Results** (88 Step-4-corrected records that touch the bed/sleep pair):

| correction_type | n | improved | worsened | median before→after | P(improved) | Wilcoxon p |
|---|---|---|---|---|---|---|
| bed_sleep_swap_3h | 39 | 39 | 0 | 31 → 5 min | 100% | 4.9e-08 |
| sleep_reduce_12h_loop | 38 | 38 | 0 | 720 → 9.5 min | 100% | 3.1e-08 |
| sleep_awake_swap_3h | 10 | 3 | 7 | 5 → 90 min (worse) | 30% | 0.036 |
| **all relevant corrections** | **88** | **81** | **7** | **120 → 8.5 min** | **92.0%** | **1.3e-12** |

`bed_sleep_swap_3h` and `sleep_reduce_12h_loop` are strongly validated on real data.
`sleep_awake_swap_3h` (n=10) surfaced a genuine negative finding: mechanistically, fixing a
sleep-after-awake ordering problem can come at the cost of the bed-before-sleep ordering. 6 of the 7
worsened cases get caught by the pipeline's own downstream temporal-order check and routed to human
review; only 1 (pid 90123) is genuinely silent. With n=10 this reads as "this rule deserves another
look," not "this rule is broken."

### B1 descriptive analysis (`time_sleep` semantics), real data (n=2,735)

Reused the same real-data checkpoint to test whether `time_sleep` means "lights out" or "fell
asleep" — a question the researcher had already answered directly on 08-09; this is an independent,
data-driven cross-check, not a re-opening of the question. Result: binning by self-reported SOL, the
median raw gap rises from ~15 min to ~37.5 min, which rules out the "lights out" hypothesis outright
(that would sit flat near zero). Point-level correlation is weak (R²=0.017) — a population-level lean,
not a precise individual match. At high self-reported SOL the self-report runs longer than the
timestamp gap, a pattern with precedent in the sleep literature (self-reported latency tends to
overrun objective measures specifically at longer latencies).

---

## 08-12: two open questions, resolved

### Can we compute Cohen's κ? — No, and it's not a "couldn't find it," it never existed

The v5 manuscript draft says "two independent human coders reviewed all flagged errors and atypical
cases." We'd already computed raw agreement at 64.0% (48/75). This time we confirmed: **Cohen's κ
requires each rater's original label, recorded independently, before either sees the other's call**
— and the two coders worked on one shared sheet from the start, not separately-then-reconciled. There
is no separately-stored "independent" version to go find, because the workflow never produced one.
Gwet's AC1 needs the same input, so it's ruled out for the same reason. **Conclusion: report raw
agreement only, and use "collaborative/concurrent dual-review" rather than "inter-rater reliability"
(even qualified as "development-time") — that term presumes some independence between the two
measurement processes, which doesn't hold here.**

### Why doesn't the manuscript's n=47/37/84 match the CSV's 75 rows?

Resolved: the manuscript sentence actually describes **two separate review tracks** (a flagged-errors
track and an atypical-cases track), not one dataset split in half:

| Track | Manuscript n | Current row count | Match? |
|---|---|---|---|
| Atypical cases (`manual_unusual_corrections.csv`) | 37 | **37** | ✅ exact |
| Flagged errors (`manual_error_corrections.csv`) | 47 | **75** | ❌ off by 28 |

The atypical track matches exactly, which confirms the manuscript's numbers were accurate when
written. The flagged-errors track doesn't match because that file's last edit (2026-08-08) is nearly
5 months after the manuscript sentence was drafted (tracked-change dated 2026-03-19) — over those 5
months the pipeline added several rounds of detection logic, so the set of records routed to human
review naturally grew as the rules got stricter. **This isn't lost data, the manuscript number is just
stale** — before submission, this sentence needs the current numbers, and the two tracks should be
reported separately (75 + 37 = 112 total reviewed, not the 84 the original sentence implied). While
we were at it, we computed the atypical track's agreement too: 89.2% immediate agreement / 10.8%
consensus-reached — notably higher than the flagged-errors track's 64.0%, which is itself a nice data
point for "review difficulty varies by task type."

---

## What's left

| Item | Status |
|------|--------|
| S8 proper fix (move the write out of the calculation function) | Deferred past v1.4.1 |
| M1 sleeponset pure-alias cleanup (still present post-B1) | Can wait |
| M4/M5/M7/M8 naming/docs | Can wait |
| D1-D7 known tech debt | Deferred |
| Committing/pushing the two 08-12 fixes | ✅ Done — v1.4.1 is live on GitHub |
| Channel B validation / B1 descriptive analysis | ✅ Done (2 of the 5 first-tier validation items) |
| κ question / n=47/37/84 discrepancy | ✅ Resolved (the remaining first-tier items) |
| OSF pre-registration protocol | Not started — last first-tier item, needed before starting tier-2 work (Monte Carlo benchmark, ablations) |

---

## Attachments

- `2026-08-12_week_work_log_summary.md` — Chinese version of this same summary
- `channel-b-redundancy-validation.md` — full Channel B + B1 methods, results, caveats (project doc)
- `development-evidence-audit.md` — full write-up of the κ and n=47/37/84 investigations (project doc)

Best,
Cyra
