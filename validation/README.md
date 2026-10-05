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
- **Two detection-recall tables are not yet reconciled.** The headline recall
  (0.995, interval 0.993 to 0.997) comes from `recall_specificity_ci.csv`
  (`ppv_cluster_ci.R`, 4,745 injected rows; weakest category
  `cross_participant_spike`, about 0.89 to 0.91). `correction_level_recall.csv`
  and its per-category file (`correction_level_recall.R`) are built from
  `detection_outcomes_v4_current.csv` (5,391 injected rows) and report a
  detection recall of 1.0 in every category, because there "detected" counts every
  row the pipeline acted on, including 26 that it repaired wrongly. The two come
  from different benchmark runs and different definitions. Quote one table, name
  it, and state its definition; do not put the two side by side until they are
  re-derived from one run.
- `correction_level_recall.csv` and `metric_distortion.csv` report that, among
  injected errors, 48.6% were corrected to the true value, 50.9% were flagged
  without correction, and 0.5% were misrepaired; and that after the pipeline the
  mean sleep-onset latency is still 47.6 minutes above the clean data (it is 191
  minutes above with no cleaning). Report this residual in the paper.
