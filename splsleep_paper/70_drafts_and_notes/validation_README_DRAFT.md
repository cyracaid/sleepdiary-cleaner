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
| 81 of 88 corrections improved; 64.0% co-review agreement | `VALIDATION_REPORT.md` | not in this repo as a runnable script | **yes** |
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
- The 81-of-88 and 64.0% figures come from the study data and one shared
  review worksheet; the second is an agreement rate, not a chance-corrected
  reliability.
