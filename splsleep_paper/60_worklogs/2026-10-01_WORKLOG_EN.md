# sleepcleanr worklog, week ending 2026-10-01 (English)

Author: Cai Dong. For: Maia ten Brink.

Every "done" item below has the command and output it rests on. Nothing in
this log contains participant-level data.

## 1. State at the end of the week

| Item | State |
|---|---|
| Released | v1.4.7 (2026-09-29) |
| In preparation | v1.4.8: committed and pushed (`705caec`, `28ed03e`); GitHub release waits for CI to finish |
| Tests | `devtools::test()` -> `[ FAIL 0 | WARN 42 | SKIP 1 | PASS 498 ]` (baseline before the last changes: 497 PASS, 1 FAIL, see 2.6) |
| Real-data run (n = 13,990, in a scratch copy outside the repo) | completes; audit PASS; Corrected = 85, same as before |
| JOSS submission | not yet; open items in section 4 |

## 2. What was done

### 2.1 Figures and the figure index
- Fixed clipped or overlapping text (Fig 13 top, Fig 2 and R25 subtitles, R27),
  a crash in Fig 24 (leftover continuous x scale), and missing legends or
  definitions. Fractional cups are shown as fractions again.
- Every figure missing from a run is listed on the index with a reason. Two
  reasons were wrong or empty and are now correct: Fig 13C (synthetic
  benchmark files not present in a scratch copy) and Fig 14 (in a run without
  manual corrections, the pending rows have no computable sleep duration; the
  console used to call this "UNEXPECTED").
- The index no longer shows an unexplained empty cell when a tier has an odd
  number of figures.

### 2.2 Step ledger (Fig 12 / A1)
- The checkforerrors column was NA at every step. The labels live in a
  different object than the ledger read; fixed by attaching them at Steps 8
  and 8.5. Re-run shows the counts.

### 2.3 Review loop for other researchers
- The `[NEW]` worksheets still list every row the rules flag, and now carry
  four columns taken from the existing manual files: `in_manual_file`,
  `review_resolution`, `resolved_at`, `resolved_by`.
- At the end of a run the console prints, per worksheet, how many rows are
  not in a manual file yet / pending / legacy / corrected / handled but still
  flagged after the re-check.
- Real-data result (run with manual corrections):
  - error worksheet, 63 rows: 0 not in a manual file, 0 pending, 52 legacy,
    11 corrected, 5 handled but still a problem after the re-check;
  - unusual worksheet, 37 rows: 0 not in a manual file, 0 pending, 33 legacy,
    4 corrected, 0 handled but still a problem.
- A bug I found in my own code through this run: a manual row written without
  a `row_id` was reported as "not in a manual file yet" (it was matched on
  pid, day and row_id). Now matched on pid and day when the manual row has no
  row_id; new test added.
- Manual files are now read the same way in every R session. In a non-UTF-8
  locale `read.csv(fileEncoding = "UTF-8")` silently dropped rows.

### 2.4 Documentation
- `interpreting-output` (English and Chinese) restructured: plain-language
  rules, terminology, run and inputs first, collapsible FAQ and exact rules.
- The pkgdown Articles menu now separates English and Chinese; each article
  links to its counterpart.
- README: removed the claim that the package is on CRAN (it is not; the CRAN
  URL returns 404), removed two directory badges, dated the statistics
  (1,048 flagged is the v1.4.5 snapshot), added a section on running the tests
  and reporting problems.

### 2.5 External datasets (feasibility checks, not accuracy evaluations)
- KAIST (Baigutanova et al. 2025): 1,372 diary rows, 49 adults; the pipeline
  ran end to end; mean TST 7.55 h, matching the source paper.
- Manchester (Didikoglu et al. 2023, PNAS): 478 rows, 59 adults; end to end;
  473 rows with metrics; mean TST 7.63 h against a self-reported mean
  duration of 7.26 h (the two are defined differently).
- Neither dataset has known diary errors or typed clock times, so neither
  tests error detection. Adaptation scripts and configs are in
  `validation/external/`; re-running the KAIST script reproduces the
  converted input byte for byte (`cmp`).
- Two things the runs taught: the pipeline needs a WASO value (an all-NA WASO
  makes every row `skipped_na`), and dd/mm/yyyy dates must be parsed
  explicitly.
- I searched for other public datasets with hand-typed clock times and found
  none usable.

### 2.6 Testing
- Full suite before the final changes: 497 PASS, 1 FAIL. The failure was
  `SKILL.md` still saying version 1.4.6 (it had not been regenerated for
  1.4.7; CI skips that test because `.opencode` is excluded from the built
  package). Regenerated with `Rscript tools/render_docs.R`.
- After: 498 PASS, 0 FAIL.

### 2.7 Release hygiene
- Built the release tarball from a clean `git archive` of the tagged commit
  (so untracked real data cannot enter). Contents checked: 195 files, no
  manual_*, sber_*, deidentified_*, `[NEW]*`, real_data_config*, fasttrack_*,
  provenance or spreadsheet files; the bundled `.rds` is the 280-row synthetic
  set (pid 1001 to 1020).
- Scanned all 342 pushed commits: no data file was ever pushed, and ten real
  participant ids searched for across every revision gave zero hits. Two
  config files with a real data file name (`real_data_config_fixed.yaml`,
  `_test.yaml`) are in history from 2026-09-07 and 2026-09-15; they contain
  names only, no data. I did not rewrite history.
- The local pre-commit hook now also refuses root-level csv/rds/xlsx and the
  manual_/sber_/real_data_config/fasttrack-style name shapes that leaked
  before. Tested in a throwaway repo. The hook must be installed once per
  clone: `bash inst/hooks/install-hooks.sh`.

## 3. JOSS readiness (my assessment)

Met: MIT licence; public repository; tests and CI; documentation site;
`paper.md` with Summary and Statement of need; validation on synthetic ground
truth and two external datasets.

Drafted in `paper.md` (local only, not pushed, because it has internal TODO
comments): Research impact statement, Development history, AI usage
disclosure.

## 4. Open items (need other people)

1. The 2023 lab scripts the package builds on: who wrote them, the lab's
   position on open release, and whether the writers agree to be credited and
   to the MIT licence.
2. Permission to name the lab and PI in the paper.
3. Public history is about 2.5 months (first public commit 2026-07-15) while
   development started in 2025-09; whether JOSS accepts that.
4. No publication yet uses the cleaned data.
5. AI disclosure wording (DeepSeek V4 Flash and V4 Pro via opencode; Claude
   Sonnet, Opus, Haiku via Claude Code): your review.
6. The 5 error-worksheet rows "handled but still a problem after the
   re-check": a human look.

## 5. Next week

- Publish v1.4.8 once CI is green (tag, tarball, release notes from NEWS).
- Fill the paper sections when the answers above are in.
- Method section completion.
