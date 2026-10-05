# Validation: where each number comes from

This folder holds the evidence behind the claims in the paper and in
`VALIDATION_REPORT.md`. It is not part of the installed package.

**Two things to know first**

- The synthetic benchmark needs no real data. The scripts generate the clean
  rows, inject the errors, run the pipeline and score it, all from fixed seeds
  (the pipeline itself is not seeded; the scoring is). Anyone can re-run it.
- The real-study layer (the redundant-channel check, the M1-M7 audit, the
  co-review agreement) needs the study data, which are not public. Those
  numbers are recorded in `VALIDATION_REPORT.md`; the scripts that read the
  data are here, but they cannot run without local access.

## Re-run it

```bash
Rscript validation/run_all.R
```

This regenerates ten of the synthetic tables (recall and its intervals, the
PPV curve, false alarms and misrepair, the three control arms, the per-category
outcomes, the correction-level recall, the metric distortion and the benchmark at
a realistic error rate) in a temporary
copy, from fixed seeds, with the installed sleepcleanr, and compares each with the
committed table. Checked on 2026-10-06 with sleepcleanr 1.4.9: all ten
regenerate identically (largest difference 0). The longer scripts
(`multiverse.R`, `l2_tier_leave_one_out.R`, `seed_sensitivity.R`,
`operating_point_sweep.R`, `evaluate_fcr.R`) are not part of `run_all.R` and were
not re-run for this check.

## Headline numbers

| Claim | Table | Script (from the repo root) | Needs real data |
|---|---|---|---|
| Pooled recall 0.995 (participant-level cluster bootstrap CI) | `synthetic/results/recall_specificity_ci.csv` | `Rscript validation/synthetic/ppv_cluster_ci.R` | no |
| 0 of 1,609 constructively clean rows flagged or altered | `synthetic/results/far_flag_alter.csv` | `Rscript validation/synthetic/far_flag_mrr_magnitude.R` | no |
| Misrepair rate 0.0048 (26 of 5,391) and its magnitude | `synthetic/results/mrr_magnitude.csv` | `Rscript validation/synthetic/far_flag_mrr_magnitude.R` | no |
| 0 of 10,000 clean records altered | `synthetic/results/fcr_pure_n10000_result.csv` | `Rscript validation/synthetic/evaluate_fcr.R` | no |
| No-cleaning vs naive rule vs pipeline | `synthetic/results/control_baselines.csv` | `Rscript validation/synthetic/control_baselines.R` | no |
| Recall stable across four seeds | `synthetic/results/seed_sensitivity.csv` | `Rscript validation/synthetic/seed_sensitivity.R` | no |
| Operating point for the swap and flip thresholds | `synthetic/results/operating_point_sweep.csv` | `Rscript validation/synthetic/operating_point_sweep.R` | no |
| Threshold multiverse and its ablations | `synthetic/results/multiverse/`, `l2_tier.csv`, `leave_one_out.csv` | `multiverse.R`, `l2_tier_leave_one_out.R` | no |
| Clock-time-in-duration-field cases are no longer silently repaired | `synthetic/results/detection_outcomes_v4_current.csv` | `Rscript validation/synthetic/evaluate_detection.R` | no |
| Thresholds barely move real-data results | `synthetic/results/real_data_spec_curve.csv` | `Rscript validation/synthetic/real_data_spec_curve.R` | **yes** |
| Logical audit of the real review queue | (reported in `VALIDATION_REPORT.md`) | `validation/audit_review_queue_m1_m7.R`, `validation/part_b_global_sweep.R` | **yes** |
| Redundant-channel check: corrections move computed SOL toward self-reported SOL | printed by the script (by correction type: bed_sleep_swap_3h 39/39 improved, sleep_reduce_12h_loop 39/39, sleep_awake_swap_3h 2/3) | `Rscript validation/redundant_channel_check.R` (run in a project directory holding `output/corrected_ema_data.rds`) | **yes** |
| 64.0% co-review agreement (n = 75), 89.2% (n = 37) | `VALIDATION_REPORT.md` | not in this repo as a runnable script | **yes** |
| Pipeline runs on two public diary datasets | `external/README.md` | `external/adapt_kaist.R`, `external/adapt_manchester.R` | no (public data) |

Every table under `synthetic/results/` has its script, seed, sample size and
interval type in `synthetic/README_results.md`, which also lists the full
command sequence, the caching that makes reruns identical, and how to read the
numbers (for example why a pooled "value correct" rate of 0.486 is not the
cleaning accuracy).

## At a realistic error rate, and the audit on real data

- `synthetic/low_prevalence.R` repeats the benchmark with 25 injected errors per
  category (348 of 7,000 rows, 5%). Result (`results/low_prevalence.csv`): 99.4% of
  injected errors flagged or corrected to the true value, 45.7% corrected, 53.7%
  flagged only, 0.6% repaired wrongly; every flagged row carried an injected error and
  no clean row was flagged or altered; 29.7 rows per 1,000 are flagged for review (the
  study's own queue is about 16 per 1,000). Clean rows here are built to pass, so the
  precision of 1.0 is a property of the benchmark, not a promise for real data.
- `blind_audit/` is the procedure and the tooling for the check that the benchmark
  cannot give: two people judge raw study entries without seeing the pipeline's output,
  and the miss rate in rows the pipeline left alone is estimated. The tooling is
  tested on the synthetic data; **it has not been run on the study data**. See
  `blind_audit/README.md`.

## What these numbers do not show

- Zero false alarms is on constructively clean generator rows; it does not
  mean the real data are free of silent problems (the real audit found some).
- The two public-dataset runs are feasibility checks; neither dataset has
  known diary errors, so they say nothing about detection accuracy.
- The co-review agreement (64.0%) comes from one shared review worksheet; it
  is an agreement rate, not a chance-corrected reliability.
- The redundant-channel check was first run in August 2026, before a guard
  was added for the `sleep_awake_swap_3h` rule; its script is not in the
  repository. Recomputing with `redundant_channel_check.R` on the current
  pipeline reproduces the August result for the cleanest rule exactly
  (`bed_sleep_swap_3h`: 39 of 39 improved, median 31 to 5 minutes) and nearly
  for `sleep_reduce_12h_loop` (39 of 39 now, 38 of 38 then; median 720 to 9
  minutes). The rule that was guarded changed: `sleep_awake_swap_3h` now
  applies to 3 of these rows (2 improved, 1 worsened) instead of 10 (3
  improved, 7 worsened). All three types together: 80 of 81 improved now, 81
  of 88 then. The counts differ because the pipeline changed, not because the
  comparison did.
- **Two "recall" figures, one run.** Both come from the same benchmark run (5,391
  injected rows, 1,609 clean controls). The headline recall 0.995
  (`recall_specificity_ci.csv`, `ppv_cluster_ci.R`) counts a row as detected when
  the pipeline flagged it or corrected it to the true value: 5,365 of 5,391
  (0.9952); the 26 rows it repaired wrongly are the misses (the weakest
  category, `cross_participant_spike`, is 214 of 236, 0.907). The "detection
  recall (L1)" of 1.0 in `correction_level_recall.csv` counts every row the
  pipeline acted on, including those 26 wrong repairs. State which definition a
  sentence uses.
- The figure "4,736 injected errors" and the "4,745" in older notes describe an
  earlier benchmark composition (11 categories). The committed tables and the
  regenerated run use 5,391 injected rows in 14 categories.
- `correction_level_recall.csv` and `metric_distortion.csv` report that, among
  injected errors, 48.6% were corrected to the true value, 50.9% were flagged
  without correction, and 0.5% were misrepaired; and that after the pipeline the
  mean sleep-onset latency is still 47.6 minutes above the clean data (it is 191
  minutes above with no cleaning). The residual sits entirely in the rows the
  pipeline flagged and left for review: with the 2,787 flagged rows set aside the
  remaining 3,881 rows show no shift in total sleep time, onset latency or
  efficiency (the `pipeline_excl_flagged` arm), while the flagged rows alone are
  114 minutes too long on latency. Two cautions. The benchmark is enriched with
  errors (5,391 of 7,000 rows are injected), so setting aside the flagged rows
  costs 42% of the rows here, whereas the review queue is about 1.6% of rows in
  the study data. And no shift in the unflagged rows means the injected error
  types the pipeline handles; it says nothing about error types not injected.
