# BRM paper: Introduction and Discussion outline (draft, 2026-10-01)

An outline, not prose. Numbers come from `VALIDATION_REPORT.md`, the 2026-10-01
real-data run and `validation/README.md`. Items marked [CHECK] need a person.

## Positioning against esmtools [CHECK before use]

`esmtools` (Revol, Carlier, Lafit, Verhees, Sels & Ceulemans; paper: "Preprocessing
ESM data: a step-by-step framework, tutorial website, R package, and reporting
templates", 2023) is the closest published work. From its CRAN README I could
establish only this: it supports preprocessing and quality assessment of EMA/ESM
data, provides calendar plots and RMarkdown reporting templates, and points to a
"5 steps framework" website. The README does not say whether it detects or
corrects mistyped clock times or duration fields, and I did not read the paper.
So the sentence we may write is limited to: general ESM preprocessing frameworks
exist (esmtools); we address a narrower, different problem, the diary-specific
errors in typed clock times and durations, with a correction log and human review.
Do not write "no other tool does X" until someone has read the esmtools paper and
the sleep-diary tools (for example the Sleep Diary Project, `slumbR`) and confirmed it.

## Introduction (~900 words)

1. **The field.** Sleep diaries collected as ecological momentary assessment give
   repeated, within-person sleep timing; they are used in intensive longitudinal
   designs. (Cite two or three from the sleep-EMA literature. [CHECK references])
2. **The problem.** Participants type bed, sleep, wake and get-up times and
   durations (sleep-onset latency, wake after sleep onset) as free text. Errors
   are frequent and take several forms: AM/PM swapped, adjacent times transposed,
   a clock time typed into a duration field, an onset latency longer than the
   window between bed and sleep. They shift the very quantities the studies
   analyze. (State the study's own rate once, from the v1.4.5 audit, labelled as a
   snapshot: 13,990 entries, 237 participants.)
3. **Current practice.** Manual checking or one-off scripts: not reproducible, no
   record of what changed, not comparable across studies. Fully automatic repair
   has a different risk: it can quietly turn an unusual but real night into a
   plausible wrong value.
4. **Our approach in one paragraph.** Correct only what a rule can show to be an
   error; flag everything else for a human; log every change against the original
   entry so raw and corrected values stay inspectable; compute the standard
   metrics (TST, SOL, WASO, SE) only afterwards.
5. **Plan.** First, a taxonomy of entry errors and the rules that detect and
   correct them. Second, a test on a synthetic benchmark with known truth. Third,
   a check on real study data using a redundant measure and a human-review audit.
   Fourth, a run on two public datasets the pipeline was not built for. Finally,
   release of the package, tutorials and the validation scripts, written for
   researchers who do not program.

## Methods (condense the ten stages into this order)

Pipeline overview (one figure); error taxonomy; detection and correction rules
and thresholds (state the reference values and that they are references, not
fixed); human review and the audit trail; validation methods in the order of the
plan above.

## Results (same order as the plan)

- Synthetic benchmark: pooled recall 0.995, no clean row flagged or altered,
  misrepair 0.0048; weakest category (cross-participant spike) 0.89 to 0.91;
  stable across four seeds. [numbers: `validation/README.md` table]
- The clock-time-in-duration finding: before the patch most such entries were
  silently turned into plausible durations (95.8% SOL, 96.0% WASO); after it, 0%.
- Real data, redundant measure: corrections move the computed latency toward the
  participant's own report. Use the current count (80 of 81 across the three
  correction types, one rule guarded after the first analysis) [CHECK: Maia to
  confirm which count the paper quotes].
- Real data, human review: co-review agreement 64.0% (n = 75) and 89.2% (n = 37),
  reported as agreement, not as a chance-corrected statistic, because the two
  reviewers worked on one shared worksheet.
- Effect of the manual files: without them 1,719 rows have a total sleep time
  and 61 remain errors; with them 1,729 and 3. (Reproduced 2026-10-01.)
- Public datasets: KAIST (49 adults, 1,372 entries) and Manchester (59 adults,
  478 entries) run end to end; mean total sleep time 7.55 h and 7.63 h. Said once,
  plainly: neither dataset has known diary errors, so this shows the pipeline
  accepts other formats, not that it detects errors.

## Discussion (~1,700 words)

1. Recap in the order of the plan, in four or five sentences.
2. **A practical rule.** What share of rows a study should expect to review. From
   the study data: the review queue at the end of a run is 226 of 13,990 rows
   (1.6%) with the manual files applied and 307 (2.2%) without. [CHECK: label as
   one study]
3. **Why detect-and-route rather than auto-fix.** The clock-time-in-duration
   result is the example; the plausibility check has to be applied to the parsed
   value, not only the raw entry.
4. **Limits, stated plainly.** No independent blinded review; one study supplied
   the real data; the thresholds were set on healthy-adult data; the public
   datasets contain no known errors; the pipeline itself is not seeded; the
   package writes to the user's global environment, a design limit [CHECK:
   remove if fixed before submission].
5. **Generalization.** Other diary designs, other typed-time fields; what a new
   study must configure (the column mapping) and what it must re-check (the
   thresholds).
6. **Closing paragraph.** Four or five sentences: what was built, how it was
   validated, what is released, what it is for.

## Declarations to prepare

Authors' contributions (CRediT), funding, data availability (study data are not
public; synthetic fixture and seeded benchmark are; link the repository),
ethics statement for the study data [CHECK with Maia], preregistration (none),
AI-use statement (DeepSeek V4 Flash and V4 Pro via opencode; Claude Sonnet, Opus
and Haiku via Claude Code; the authors made the design decisions and reviewed
every change), conflict of interest.
