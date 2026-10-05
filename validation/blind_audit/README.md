# Blind audit on real data: what does the pipeline miss?

The synthetic benchmark contains the errors we designed the rules for. A reader's
first question is "what errors did you not think of?" This audit answers it on the
study data: two people judge raw diary entries **without seeing what the pipeline
did**, and their judgments are compared with the pipeline's flags and changes.

Nothing in this folder contains study data. The scripts write the sheets and the key
to a directory **outside the repository** (`draw_sample.R` refuses a directory
inside a git work tree).

## Procedure

1. Run the pipeline on the study data and keep the review queue:
   ```r
   run_pipeline(config = "my_study.yaml")
   saveRDS(pipeline_results()$review_output, "review_output.rds")   # sleepcleanr >= 1.5.0
   # (older versions leave `review_output` in the global environment: saveRDS(review_output, ...))
   ```
2. Draw the sample (outside the repo):
   ```bash
   Rscript validation/blind_audit/draw_sample.R output/corrected_ema_data.rds ~/blind_audit review_output.rds
   ```
   It writes `annotation_sheet_A.csv`, `annotation_sheet_B.csv` (the same raw entries,
   in a mixed order, with no stratum or pipeline column) and
   `KEY_do_not_share_with_annotators.csv`.
3. Give sheet A to one annotator and sheet B to another. They work alone and do not
   see the pipeline output, the other sheet or the key. The person who holds the key
   is not an annotator.
4. Each annotator fills `error_present` (Y, N or U), `error_type` (optional, from the
   list below), `intended_value_or_note` (optional) and `seconds_taken`.
5. Score:
   ```bash
   Rscript validation/blind_audit/score_audit.R ~/blind_audit
   ```
   Where the annotators disagree, a third person can add an `adjudicated` column
   (Y or N) to sheet A; otherwise disagreements and unsure items are left out and
   counted.

## What counts as an error

*Y* = the entry as typed does not give the time or duration the participant most
likely meant (for example AM and PM swapped, two times transposed, a clock time typed
where a duration was asked, a latency longer than the time between getting into bed
and falling asleep). A typing slip that still reads as the intended value (a missing
colon in "1130") is *N*. *U* = cannot tell from the row. This is the definition the
pipeline's changes are measured against, so it is the same for both annotators.

Suggested `error_type`: `ampm`, `transposed`, `colon_or_format`, `duration_in_clock_format`,
`window_contradiction`, `implausible`, `other`.

## Strata and sample size

| Stratum | Rows | What it estimates | Default n |
|---|---|---|---|
| flagged | rows in the review queue | precision of the flags | 150 |
| changed | rows whose times the pipeline changed without a flag | share of changes made on real errors | 50 |
| left alone | rows neither flagged nor changed | **miss rate** | 150 |

With 150 left-alone rows the exact 95% interval is about 0.4 to 5.7% if the true miss
rate is 2%, and about 2 to 10% if it is 5%: enough to say whether the miss rate is
small, not enough to rank rules. About 350 items take roughly 2.5 hours per annotator
at 25 seconds per item; record `seconds_taken` so the paper can report review time.

## What it reports

Annotator agreement (raw and Cohen's kappa, also without the unsure items); precision
of the flags; the share of changes made on real errors; the miss rate in left-alone
rows with its interval; and a population-level estimate (errors present in left-alone
rows, sensitivity of flagging or changing) from the stratum sizes, with a bootstrap
interval.

## Limits

- It measures the pipeline against two annotators' judgment of the raw row, not
  against an independent record of what the participant meant. The annotators do not
  judge whether a change was correct, only whether the row contained an error.
- Annotators see one row. If context from other days is allowed, say so and give both
  annotators the same.
- If the annotators are the authors, state it: this is then still not independent
  of the pipeline's designers. Prefer two people who did not write the rules.

## Test of the tooling

`demo_synthetic.R` runs the whole chain on the synthetic benchmark, where the truth
is known, with two simulated annotators (5% label flips, 2% unsure). On the
2026-10-06 run the audit estimated a miss rate of 10.3% (95% interval 5.6 to 17.0%)
against 10.0% computed from the ground truth, and a sensitivity of 94.1%.
