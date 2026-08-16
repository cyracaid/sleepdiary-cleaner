# Synthetic Benchmark — Results Registry

Every table under `results/`, with its source script, seed, sample sizes, and
CI type. Purpose: statistical transparency — each number must be traceable to
a command, a seed, and a stated estimator.

## Seed policy

| Seed | Used by | Purpose |
|---|---|---|
| `20260817` | ppv_cluster_ci.R (clean gen + injection), far_flag_mrr_magnitude.R, l2_tier_leave_one_out.R | 5.1/5.3/5.2/5.6 shared enrichment run |
| `20260817` | multiverse.R bootstrap | PPV band resampling |
| `20260812` | legacy results (detection_outcomes_v4.csv, enrichment_detection_outcomes_v3.csv) | pre-5.1 first-pass (superseded) |

Note: the pipeline itself (`run_pipeline`) is NOT seeded — run-to-run
variance in downstream quantities exists (see issue #6). The benchmark
evaluators are seeded.

## Ground truth — two layers (not circular)

1. **Synthetic layer (injected ground truth).** `generate_clean_data.R`
   constructs clean rows (monotonic, format-valid by construction);
   `inject_errors.R` corrupts a known subset and logs
   original/corrupted/true values. FAR=0 means: the pipeline never alters a
   **constructively-clean** row. This does NOT claim real data is clean.
2. **Real layer (logical audit).** Real n=13,990 has no injected truth. It is
   validated by the M1–M7 logical audit (`audit_review_queue_m1_m7.R`,
   `part_b_global_sweep.R`), which found 922 SOL-vs-window contradictions,
   49 uncorrected order violations, 1 silent worsening — and drove the
   closed-loop sol_window guard.

The two layers use different standards on purpose; the synthetic layer proves
mechanism-level behavior, the audit layer catches real-data blind spots.

## File-by-file

| File | Script | Seed | n | Quantities | CI type |
|---|---|---|---|---|---|
| `fcr_pure_n10000_result.csv` | evaluate_fcr.R | 20260812 | 10,000 | FAR_alter per field | rule-of-three 95% upper bound |
| `enrichment_detection_outcomes_v3.csv` | evaluate_detection.R (v3) | 20260812 | 7,000 | per-category recall (L1 flag) | none (superseded by v4) |
| `detection_outcomes_v4.csv` | evaluate_detection.R (v4) | 20260812 | 7,000 | per-category CORRECT/MISREPAIRED/FLAGGED/MISSED | none (first-pass, pre-5.1) |
| `cluster_bootstrap_per_row.csv` | ppv_cluster_ci.R | 20260817 | 7,000 (4,745 inj + 1,609 ctrl) | per-row detected/flag/value_correct | — |
| `recall_specificity_ci.csv` | ppv_cluster_ci.R | 20260817 | 4,745 inj / 1,609 ctrl | pooled + per-category recall, control specificity | participant-level cluster bootstrap, 2,000 resamples |
| `ppv_curve.csv` | ppv_cluster_ci.R | 20260817 | — | PPV over pi=0.5–10% | Bayes from recall/spec + 500 bootstrap draws |
| `far_flag_alter.csv` | far_flag_mrr_magnitude.R | 20260817 | 1,609 ctrl | FAR_flag, FAR_alter | point estimate |
| `mrr_magnitude.csv` | far_flag_mrr_magnitude.R | 20260817 | 4,745 inj | per-category MRR + magnitude | point estimate |
| `mrr_per_row.csv` | far_flag_mrr_magnitude.R | 20260817 | 4,745 | per-row kind + magnitude | — |
| `control_baselines.csv` | control_baselines.R | 20260817 | 4,745 | no-cleaning / naive-rule / pipeline recall + FAR | point estimate |
| `multiverse/oat_screening.csv` | multiverse.R | — | 13 specs | downstream qty per OAT level | none (screening) |
| `multiverse/spec_curve.csv` | multiverse.R | — | **9 specs (3^2)** | mean TST/SOL/SE, analyzable n | none (deterministic runs) |
| `multiverse/instability.csv` | multiverse.R | — | 5 specs | record classification by spec | none |
| `multiverse/variance_decomposition.csv` | multiverse.R | — | 9 specs | sum_sq + proportion per dim | ANOVA (descriptive) |
| `downstream_sensitivity.csv` | downstream_sensitivity.R | — | — | multiverse ranges + B1/B2 | none |
| `l2_tier.csv` | l2_tier_leave_one_out.R | 20260817 | 4,745 | per-category L1/L2/L3 | point estimate |
| `leave_one_out.csv` | l2_tier_leave_one_out.R | 20260817 | 4,745 | recall/workload per ablation | ⚠️ not reproducible (issue #6) |

## Multiverse — why 9 specs, not 243

The plan (08-14 meeting notes) expected "OAT → full factorial on surviving
4–6 dimensions (3^5 = 243)". After OAT screening (multiverse.R), only 2 of 6
candidate dimensions moved downstream quantities or classification on this
benchmark set:

- D1 flip_gap_hours (12h AM/PM flip threshold) — moves mean SOL strongly
- D2 swap_threshold_hours (minor-order swap) — moves mean TST/n

D3–D6 (flag thresholds: SOL excessive, SE poor, WASO excessive, TST/TIB ratio)
changed **no** downstream quantity or flag count on the healthy-adult
enrichment set → dropped by the ≥1% / ≥5-min survival rule. Full factorial on
the survivors = 3^2 = **9 specs**. Interaction found: D1=11 suppresses the D2
effect (12h-flip path dominates at that level).

243 is not claimed as a result; it was the pre-OAT worst-case budget.

## FAR=0 wording (scope limitation)

FAR_flag = 0/1,609 and FAR_alter = 0/1,609 mean: on **constructively-clean
generator rows**, zero flagged, zero altered. It does NOT mean real data has
zero silent issues — the real-data audit (M1–M7/Part B) found genuine ones.
Use the scoped wording in any manuscript sentence.

## Reproducibility commands (from repo root)

```bash
Rscript validation/synthetic/ppv_cluster_ci.R            # 5.1 tables
Rscript validation/synthetic/far_flag_mrr_magnitude.R    # 5.3 tables
Rscript validation/synthetic/control_baselines.R         # 5.7 table
Rscript validation/synthetic/multiverse.R                # 5.4 tables (reruns pipeline ~9x)
Rscript validation/synthetic/downstream_sensitivity.R    # 5.5 table
Rscript validation/synthetic/l2_tier_leave_one_out.R     # 5.2 + 5.6 (⚠️ 5.6 not reproducible)
Rscript audit_review_queue_m1_m7.R                       # M1–M7 audit (real data)
Rscript part_b_global_sweep.R                            # Part B sweep (real data)
```

All scripts reuse cached `validation/synthetic/run_ppv/` outputs when present
(ppv_cluster_ci.R) — delete that dir to force a full pipeline rerun.
