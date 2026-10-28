# BRM paper: full outline with the numbers (2026-10-05)

Article type: Original Manuscript (Regular Article), about 8,000 to 9,000 words.
Every number below was checked against a file in the repository or against the
2026-10-01 to 05 runs; the source is in brackets. [CITE] = reference needed,
[CHECK] = needs a person. Prose for the Introduction is in
`BRM_INTRO_PROSE_DRAFT_2026-10-01.md`.

Working title: *sleepcleanr: an auditable pipeline for cleaning self-reported
sleep-diary data, validated on injected, real and public data*

## Abstract (about 230 words, draft)

Sleep diaries collected by ecological momentary assessment are a main source of
within-person sleep data, but participants type bedtimes, wake times and durations
as free text, and typing errors change the quantities studies analyze. Current
practice is manual checking or study-specific scripts that leave no record.
Automatic repair risks turning unusual but real nights into plausible wrong ones.
We present sleepcleanr, an R pipeline that corrects only entries a documented rule
shows to be wrong, sends the rest to a human reviewer, and records every change
against the original entry. We validated it in four ways. On a synthetic benchmark
(5,391 injected errors in 14 categories, 1,609 clean controls) the pipeline flagged
or correctly repaired 99.5% of errors and altered none of the clean rows; 48.6% of
errors were corrected to the true value, 50.9% were flagged for a human, and 0.5%
were repaired wrongly. Sleep metrics computed after cleaning were closer to the
truth than after no cleaning or a naive rule; the residual bias in onset latency
(+47.6 minutes) was confined to flagged rows. On 13,990 diary entries from one
study, corrections moved the computed onset latency toward participants' own reports
in 80 of 81 cases, and the review queue was 7.9% of the entries with all four times (226 of 2,848). Run unchanged on two
public datasets, the pipeline completed; neither contains known errors, so this
shows format generality, not detection accuracy. We release the package, tutorials
and the scripts that regenerate every benchmark table.

## 1. Introduction (about 900 words)
As drafted: field; typed-entry errors; current practice; fully automatic repair
risk (the clock-time-in-duration finding, 95.8% and 96.0% silently mis-repaired
before the patch, 0% after); our principle; the four-step plan; limits stated at
the outset. Add one paragraph of related work: general ESM preprocessing
frameworks [CITE esmtools paper, CHECK scope], sleep-diary standards (Consensus
Sleep Diary) [CITE], data-quality and careless-responding literature [CITE].

## 2. Methods (about 3,000 words)

2.1 **Design principle and overview.** One figure: raw entries to parsing, rule
classes (correct, flag, leave), human review, ledger, then metrics. State the
rule that nothing is changed without a recorded type.

2.2 **Error taxonomy.** Table with the 14 injected categories and the real-world
form each represents (AM/PM swap, adjacent-time transposition, missing or extra
colon, MM:SS read as HH:MM, a clock time typed into a duration field, an onset
latency longer than the bed-to-sleep window, an implausible duration, a
cross-participant spike). Say how each category was constructed, and that the
taxonomy comes from the study's own errors plus the literature [CHECK: sources].

2.3 **Rules and thresholds.** Table from `THRESHOLDS.md`: 12-hour flip trigger,
3-hour adjacent swap, midnight at 6 a.m., MM:SS at 60 minutes, onset latency over
120 minutes, efficiency over 100% or under 0%, TST/TIB ratio, with the rationale
and the statement that defaults were tuned on a healthy young-adult sample and are
references to be re-checked. Define the terms here once: detection recall,
correction-level recall, false-alarm rate, misrepair rate, flag-only share.

2.4 **Human review and the audit trail.** Worksheets, the four columns (in manual
file, resolution, date, reviewer), re-check after correction, the printed summary.
Reviewers: two members of the team on one shared worksheet.

2.5 **Validation 1: synthetic benchmark.** 500 simulated participants, 14 days;
errors injected with logged truth; fixed seeds; outcomes per row: corrected to the
true value, flagged, repaired wrongly, missed. Comparators: no cleaning, a naive
rule (resolve midnight, swap inverted adjacent pairs). Sensitivity: four seeds,
a 20-point threshold grid, a multiverse over thresholds. Metric distortion: mean
TST, SOL and SE under each arm compared with the clean data on the same rows.

2.5b **Realistic-prevalence arm.** The benchmark repeated with 25 injected errors per
category (about 5% of rows); report the share handled, precision of flags, clean rows
flagged or altered, and rows flagged per 1,000.

2.6 **Validation 2: real study data.** 13,990 entries, 237 participants (morning
diaries). Redundant-channel check (corrected bed-to-sleep gap against the
participant's own latency report, which the correction step never reads);
effect of the manual files (with and without); co-review agreement. **Blind audit [PLANNED, not run]:** two annotators who did not
write the rules label about 350 stratified raw entries without seeing the pipeline's
output; report their kappa, the precision of the flags, the miss rate in rows the
pipeline left alone with its interval, review time per row, and a population estimate
(`validation/blind_audit/`, tooling tested on synthetic data).

2.7 **Validation 3: public datasets.** KAIST and Manchester, converted by the
scripts in `validation/external/`, no threshold changed.

2.8 **Software and reproducibility.** R package, YAML column mapping, renv, tests,
CI, Zenodo DOI; `validation/run_all.R`.

## 3. Results (about 1,800 words)

3.1 **Benchmark.** [`recall_specificity_ci.csv`, `correction_level_recall*.csv`,
`far_flag_alter.csv`, `control_baselines.csv`]
- Flagged or corrected to the true value: 5,365 of 5,391, 0.9952 (95% interval
  0.9933 to 0.9970, participant-level bootstrap).
- Corrected to the true value 0.486 (2,619); flagged only 0.509 (2,746); repaired
  wrongly 0.0048 (26); false alarms and false alterations 0 of 1,609 (upper 95%
  bound 0.19%). No cleaning 0; naive rule 0.623.
- Per category (figure, stacked bars): fully corrected: missing or extra colon,
  bed/sleep and awake/get-up swaps (400 of 400 each); MM:SS confusion 0.945 (4
  wrong); AM/PM swap 0.565; compound AM/PM plus swap 0.38; field misentry in the
  latency and wake-after-sleep-onset fields 0.018 and 0.033 corrected, the rest
  flagged (393 and 387 of 400); sleep/awake swap, implausible duration and
  window contradictions 0 corrected, all flagged (400, 400 and 355). Weakest:
  cross-participant spike, 214 of 236 flagged and 22 wrong (0.907).
- Seeds: pooled 0.9935 to 0.9952 over four seeds, false alarms 0. Threshold grid
  (20 points): recall 0.9950 to 0.9957, false alarms 0, so the benchmark is
  insensitive to the swap and flip thresholds and cannot distinguish them.
  Multiverse: the 12-hour flip dimension and the swap dimension move downstream
  means; which survive depends on the seed (D2 explains 46% of variance in the
  full factorial) [CHECK wording with `README_results.md`].

3.1b **At a realistic error rate.** [`low_prevalence.csv`] With 25 errors per category
(348 of 7,000 rows, 5%): 99.4% flagged or corrected to the true value, 45.7%
corrected, 53.7% flagged only, 0.6% repaired wrongly; no clean row flagged or
altered; 29.7 rows per 1,000 flagged for review (the study's queue is about 16 per
1,000). State that the clean rows are built to pass, so precision 1.0 belongs to the
benchmark.

3.2 **Metric distortion.** [`metric_distortion.csv`] Against the clean data:
no cleaning TST -86.0 min, SOL +191.4 min, efficiency -22.0 points; naive rule
-55.2, +117.9, -18.5; pipeline +11.2, +47.6, +2.5. The pipeline's bias sits in
the flagged rows (2,787 of 6,668 compared rows; their latency is +114 min); with
those set aside, the remaining 3,881 rows show no shift (0.00 on all three).
Caution to state: the benchmark is error-enriched (77% of rows injected), so
setting flagged rows aside costs 42% of rows here and 7.9% of the diary entries in the study data.

3.3 **Real data.** [`redundant_channel_check.R`, the 2026-10-01 run]
- Redundant channel: 80 of 81 corrections moved the computed latency toward the
  self-report (98.8%, exact 95% interval 93.3 to 100%); by rule: 39 of 39, 39 of
  39, 2 of 3. An earlier analysis (81 of 88, 92%) predates a guard on one rule.
- Effect of the manual files: without them 1,719 entries have a total sleep time
  and 61 remain errors; with them 1,729 and 3. Rules corrected 93 rows (10 also
  by a reviewer); reviewers corrected 75 further rows. Review queue at the end
  of a run: 226 rows with the manual files, 307 without: 79 and 108 per 1,000 of the 2,848 entries with all four times (1.6% and 2.2% of all 13,990 submissions).
- Co-review agreement 64.0% (n = 75 flagged errors) and 89.2% (n = 37 atypical
  cases); reported as agreement, not as a chance-corrected statistic.
- Threshold insensitivity on real data: no threshold dimension changes the mean
  total sleep time by more than 0.93 minutes or the analysable n by more than
  0.70%.

3.4 **Public datasets.** KAIST: 1,372 entries, 49 adults, 1,094 (79.7%) with a
total sleep time, mean 7.55 h. Manchester: 478 entries, 59 adults, 473 with a
total sleep time, mean 7.63 h (self-reported mean duration 7.26 h; defined
differently). No errors flagged in either; stated as a format check.

3.5 **Worked example.** (synthetic data, so it can be shown in full) Two rows.
Row 1: sleep time typed "10:26 AM" instead of PM, 12 h 16 min after bed; the
12-hour rule moves it to 10:26 PM, type `sleep_reduce_12h_loop`, row marked
corrected, original kept. Row 2: sleep and awake times transposed (07:43 AM in the
sleep field, 11:59 PM in the awake field); no rule can prove which is right, so
the row is classed error, not changed, and appears on the review worksheet.

## 4. Discussion (about 1,700 words)
1. Recap in the order of the plan.
2. What to expect: share of rows needing review (7.9% to 10.8% of the entries with all four times in one study).
3. Why detect and route rather than repair: the clock-time finding; half of the
   injected errors cannot be fixed by a rule and must go to a person.
4. **Limitations, stated plainly.** Benchmark built by us and error-enriched;
   synthetic errors are not natural ones; one real study; the human agreement is
   64% on a shared worksheet, with no independent blinded coders; the public
   datasets contain no known errors; thresholds tuned on one population; the
   residual onset-latency bias (+47.6 min) remains in any analysis that keeps
   flagged rows; the package writes some objects to the global environment.
5. Generalization and what a new study must reconfigure and re-check.
6. Closing paragraph.

## 5. Declarations
Authors' contributions (CRediT); funding; data availability (study data not
public; synthetic fixture, benchmark scripts, Zenodo DOI 10.5281/zenodo.23077702);
code availability; ethics and data-use statement for the study data [CHECK with
Maia and the PI]; preregistration (none); conflict of interest; AI-use statement.

## Figures and tables (8 to 10)
Fig 1 pipeline and design; Fig 2 taxonomy with an example per category; Fig 3
benchmark outcomes per category (stacked: corrected, flagged, wrong, missed);
Fig 4 metric distortion by arm; Fig 5 redundant channel, before and after; Fig 6
review queue by study and by rule; Table 1 thresholds and rationale; Table 2
terms; Table 3 datasets and what each can and cannot show.

---

# An outside reader's view (what I would ask as a BRM reviewer)

Ordered by how likely each is to decide the review.

1. **"What errors did you not think of?"** The benchmark contains the errors you
   designed the rules for. Add one blind check on real data: draw about 300 raw
   entries from the study, stratified by flagged and not flagged, have two people
   label them without seeing the pipeline output, and report the pipeline's
   sensitivity and precision against those labels and the coders' kappa. The
   unflagged stratum is what estimates misses in real data. This is the single
   addition with the most effect.
2. **Downstream effect on an actual question.** Show how a cleaning choice changes
   an estimate the study cares about (for example the sleep to next-day affect
   association). This is what turns a package into a methods paper; it needs the
   study data and the PI's agreement.
3. **The residual bias must be in the abstract and in the Discussion, not a
   footnote.** The finding that all remaining bias sits in flagged rows is a
   strength (it says where to look), as long as the cost is shown (42% of rows in
   the enriched benchmark, 7.9% in the study).
4. **A realistic benchmark.** 77% injected is not a prevalence anyone sees. Keep
   it for per-category recall, but add an arm at a realistic error rate and report
   precision and the review burden per 1,000 entries (the PPV curve exists).
5. **A fairer comparator.** The naive rule is weak by design. Add a second,
   reasonable baseline (a careful hand-written rule set, or an existing tool if one
   applies) and state plainly that no published tool does the same task, only
   after the esmtools paper and the sleep-diary tools have been read.
6. **Say what the thresholds can and cannot claim.** The grid is flat, so the
   defaults are reference values, not optimized. State this in Methods, not only
   in the Discussion.
7. **Human review as a measured step.** Report time per reviewed row and the
   agreement definition (presence of error, error type, or corrected value). A
   64% agreement will be read as low unless the definition is clear.
8. **Software hygiene a reviewer from the R community will check.** Writing to
   the global environment is not allowed on CRAN; the package is not on CRAN;
   decide whether to fix that, install from R-universe, or say why it is not
   needed. The root-level `verify_*.R` scripts are used by CI and should be
   described as such.
9. **Presentation.** Define the terms once in a table; keep one headline number
   per claim with its definition; drop counts that are not evidence (tests,
   figures); no marketing language; describe the data source in neutral terms
   until the PI has agreed to be named.
10. **Affiliation and ethics.** The data come from a laboratory at one institution
   and the authors are at two others. The data-use arrangement and the ethics
   approval for the secondary use have to be written down.

---

# Status of the ten points above (2026-10-06)

| # | Point | Status |
|---|---|---|
| 1 | Blind audit for misses | Tooling and protocol done and tested on synthetic data (`validation/blind_audit/`); **needs two annotators and the study data** |
| 2 | Downstream effect | Plan written (`BRM_DOWNSTREAM_ANALYSIS_PLAN_2026-10-06.md`); **needs the outcome variables, the model and the PI's agreement** |
| 3 | Residual bias in abstract and Discussion | Done in the abstract draft and Discussion item 4; flagged-rows-set-aside result added |
| 4 | Realistic benchmark | Done: `low_prevalence.R`, table committed, part of `run_all.R` (10 of 10 tables regenerate identically) |
| 5 | Fairer comparator | Not done: the naive rule stays the only baseline. A second baseline written by us would not be independent, and no published tool for this task has been identified; esmtools and the sleep-diary tools must be read first |
| 6 | Threshold claims in Methods | Done: `THRESHOLDS.md` and outline 2.3 say the defaults are reference values and the benchmark is insensitive to them |
| 7 | Human review as a measured step | Annotation definition, `seconds_taken` and agreement reporting built into the audit; the existing 64.0% still lacks a stated definition and a kappa |
| 8 | R-community hygiene | `verify_*.R` described in `CONTRIBUTING.md`; global-environment writes assessed in `docs-dev/GLOBALENV_REFACTOR_ASSESSMENT.md`, **not refactored** (13 files, changes what a run leaves behind; recommended for a later, separate release) |
| 9 | Presentation | Terms table in outline 2.3; README no longer claims "30+" figures or test counts; one number per claim with its definition |
| 10 | Affiliation and ethics | Draft with blanks (`BRM_DECLARATIONS_DRAFT_2026-10-06.md`); **needs Maia and the PI** |

---

# Status of the gaps from the BRM comparison (2026-10-06)

| Gap | Status |
|---|---|
| Expand the simulation to a grid | Done: `prevalence_grid.R`, 16 cells, `prevalence_grid.csv` (see `BRM_SECTIONS_DRAFT_2026-10-06.md` B) |
| Recommendations section | Drafted (C) |
| Reporting template | Done as code: `cleaning_report()` with tests (development version, not released) |
| Literature scan | Protocol and coding sheet written, pilot inconclusive (H); **needs full-text access and two coders** |
| Positioning against esmtools and careless responding | Related-work paragraph drafted (A) with [CITE]/[CHECK] markers; the claim that no tool does this is **not yet verified** |
| Closing section names | Done: Recommendations, Limitations and future directions, Conclusion, open practices (C to F) |
| Worked example | Drafted from two real benchmark rows (G); also found that the manual-instruction grammar cannot shift to the previous day |
| Independent ground truth | Blind-audit tooling ready and tested on synthetic data; **real-data audit and a vignette typing task not run** (need people) |

The study data are real, but they carry no record of what each participant meant to
type. The only labels on them are the reviewers' own corrections (our judgment) and the
redundant self-report; neither is independent of the people who wrote the rules. That is
why independent labels (blind audit, typing task) are still on the list.
