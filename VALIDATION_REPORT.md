# sleepcleanr — Validation Report

_Rendered 2026-09-17 by `validation/render_validation_report.R`. All synthetic numbers are read directly from the result CSVs — nothing below is hand-typed._

## Summary

sleepcleanr is a deterministic, auditable cleaning pipeline for sleep-EMA diary data. It is validated on two independent layers: a **synthetic benchmark** with known ground truth (pooled recall **0.995 [0.993, 0.997]**, specificity 1.0) and a **real-data audit** (n = 13990). The pipeline treats plausible sleep-timing variability as signal, not noise — it flags disagreements for human review rather than silently normalizing them.

## Design philosophy

This pipeline is built for sleep–affect association studies. Between- and within-person
variability in reported sleep-onset latency is signal, not noise. The pipeline therefore:

- flags disagreements for human review (FLAG), never silently normalizes
- applies only timestamp-level corrections (order / AM-PM)
- leaves plausible large values untouched

This is a deliberate design choice, not incomplete cleaning.

## Validation chain (9 steps, three tiers)

| Tier | Step | Result |
|---|---|---|
| Synthetic | 1. Clean-input specificity | FCR 0/9996 altered; FAR_flag 0/1609 |
| Synthetic | 2. Injected-error benchmark | pooled recall 0.995 [0.993, 0.997]; specificity 1.0 |
| Synthetic | 3. Detection vs value-correctness | L1/L3 gap, e.g. ampm_swap L1 1.0 / L3 0.565 (uncertain restorations → human) |
| Synthetic | 4. Controls | no_cleaning 0.000 / naive_rule 0.623 / pipeline 0.995 |
| Real | 5. Redundant-channel | 81/88 corrections improved; 1 bad rule found & guarded (v1.4.3) |
| Real | 5.5 Bland-Altman | SOL ±75-min noise band → SOL flags INSIDE NOISE (descriptive, human); WASO 3.3× SAFE |
| Real | 6. Report-only audit | 0 AUTO_FIX, 1048 FLAG (922 window violations, 140 order violations) |
| Real | 7. Co-review agreement | 64.0% (n=75) / 89.2% (n=37), not κ |
| Robustness | 8. Multiverse + downstream + seeds | D2 = 46% of variation; TST robust, SOL sensitive; recall stable 0.994–0.995 |

## Synthetic benchmark

Ground truth is recorded at injection time (self-consistent standard — no external gold standard exists for free-text diary entry).

| Quantity | Value | Source file |
|---|---|---|
| Pooled recall (L1 detection) | 0.995 [0.993, 0.997] | recall_specificity_ci.csv |
| Specificity | 1.0 | recall_specificity_ci.csv |
| FCR (clean records altered) | 0/9996 | fcr_pure_n10000_result.csv |
| FAR flag / alter | 0/1609 both | far_flag_alter.csv |
| Controls: no_cleaning / naive / pipeline | 0.000 / 0.623 / 0.995 | control_baselines.csv |
| Mis-repair rate (MRR) | see mrr_magnitude.csv (0 in current run) | mrr_magnitude.csv |

### Per-category benchmark (detection vs correction separated)

Detection ("the pipeline acted") and correction ("it got the right value") are reported separately. `false_correction` = misrepaired (changed to a wrong value); `missed` = untouched, still wrong, unflagged. The clean-control block is reported on its own line — the raw `detection_outcomes_v4_current.csv` counted its 1,609 rows as MISSED and `correct_pct` 0, which read as "0% correct" when they simply carry no injected error; that miscompute is corrected here.

| Category | n | detected | correctly detected | flagged unresolved | false correction | missed | recall | misrepair rate |
|---|---|---|---|---|---|---|---|---|
| adjacent_swap_large_gap_left_clean | 400 | 400 | 243 | 157 | 0 | 0 | 1.000 | 0.000 |
| adjacent_swap_time_awake_am_time_getup_am | 400 | 400 | 400 | 0 | 0 | 0 | 1.000 | 0.000 |
| adjacent_swap_time_bed_am_time_sleep_am | 400 | 400 | 400 | 0 | 0 | 0 | 1.000 | 0.000 |
| adjacent_swap_time_sleep_am_time_awake_am | 400 | 400 | 0 | 400 | 0 | 0 | 1.000 | 0.000 |
| ampm_swap | 400 | 400 | 226 | 174 | 0 | 0 | 1.000 | 0.000 |
| compound_ampm_and_swap | 400 | 400 | 152 | 248 | 0 | 0 | 1.000 | 0.000 |
| cross_participant_spike | 236 | 236 | 0 | 214 | 22 | 0 | 1.000 | 0.093 |
| field_misentry_sol | 400 | 400 | 7 | 393 | 0 | 0 | 1.000 | 0.000 |
| field_misentry_waso | 400 | 400 | 13 | 387 | 0 | 0 | 1.000 | 0.000 |
| format_malformed_colon | 400 | 400 | 400 | 0 | 0 | 0 | 1.000 | 0.000 |
| format_no_colon | 400 | 400 | 400 | 0 | 0 | 0 | 1.000 | 0.000 |
| implausible_duration | 400 | 400 | 0 | 400 | 0 | 0 | 1.000 | 0.000 |
| mmss_confusion | 400 | 400 | 378 | 18 | 4 | 0 | 1.000 | 0.010 |
| sol_window_contradiction | 355 | 355 | 0 | 355 | 0 | 0 | 1.000 | 0.000 |
| **CONTROL (no_error_control)** | 1609 | — | — | — | — | — | — | — |

Pooled precision = 1.000 (flagged injected / (flagged injected + flagged control)); control FAR_flag 0/1609, FAR_alter 0/1609. Source: benchmark_table.csv.
## Real-data audit

Report-only run over all 13990 real diary records. No data is modified (0 AUTO_FIX).

| Quantity | Value |
|---|---|
| AUTO_FIX | 0 |
| FLAG | 1048 |
| M4 window violations | 922 |
| M1 order violations | 140 |
| M5 silent-worsening candidates | 1 |
| Genuine mismatches flagged for review (extreme ≥60min + >2× window) | 185 (76 extreme + 138 over-window) |

**Human review outcome (local authoritative worksheet, aggregate):**

Of the 56 reviewed records, **50 were KEPT as written** (self-reported SOL exceeding the bed→sleep window is treated as self-reported context, not proof of error — consistent with the sleep–affect design philosophy), 2 set to NA (unusable duration), 2 modified, and 2 remain open.

| Decision | Count |
|---|---|
| KEEP as written (incl. batch rules) | 50 |
| Set to NA (unusable duration) | 2 |
| Modified | 2 |
| Open (needs human call) | 2 |

The dominant outcome is KEEP: a plausible large SOL is left untouched even when it exceeds the timestamp window, because removing it would bias the sleep–affect associations the pipeline exists to serve.

## Bland-Altman measurement characterization

| Metric | LoA half-width | Threshold ratio | Verdict |
|---|---|---|---|
| SOL | ±75.4 min | 1.59 / 0.80 | INSIDE NOISE → descriptive flags, human review |
| WASO | ±27.3 min | 3.29 | SAFE |
| SE / TST-TIB | — | — | N/A (no self-report pair) |

SOL thresholds sit inside the reporting-noise band; SOL flags are descriptive indicators routed to human review, not automated error signals (verified: `flag_severity` feeds no correction path).

## Multiverse, downstream sensitivity, seeds

| Dimension | Share of variation ||---|---|
| D1 | 7% |
| D2 | 46% |
| Residuals | 47% |

| Quantity | base | min | max ||---|---|---|---|
| mean TST (h) | 8.06 | 8.06 | 8.07 |
| mean SOL (min) | 31.2 | 22.7 | 58.1 |
| B1 TST shift / B2 n shift | 29.6 min / 1131 records | | |

Seed sensitivity: pooled recall 0.994–0.995 across 4 seeds; control FAR 0 in all.

## Threshold operating-point analysis

Answers "why 3 h and 12 h?" by sweeping the two rule-defining thresholds on the fixed synthetic benchmark (same corrupted input + same ground truth for every point; only the pipeline detection thresholds change). Selection rule predefined, not post-hoc: **primary recall ≥ 0.95 → secondary min FAR_flag → tie nearest (3,12)**.

| swap (h) | flip (h) | recall | FAR_flag | FAR_alter | precision |
|---|---|---|---|---|---|
| 1 | 8 | 0.9954 | 0.0000 | 0.0000 | 1.000 |
| 1 | 10 | 0.9954 | 0.0000 | 0.0000 | 1.000 |
| 1 | 12 | 0.9950 | 0.0000 | 0.0000 | 1.000 |
| 1 | 14 | 0.9952 | 0.0000 | 0.0000 | 1.000 |
| 2 | 8 | 0.9954 | 0.0000 | 0.0000 | 1.000 |
| 2 | 10 | 0.9954 | 0.0000 | 0.0000 | 1.000 |
| 2 | 12 | 0.9950 | 0.0000 | 0.0000 | 1.000 |
| 2 | 14 | 0.9952 | 0.0000 | 0.0000 | 1.000 |
| 3 | 8 | 0.9954 | 0.0000 | 0.0000 | 1.000 |
| 3 | 10 | 0.9954 | 0.0000 | 0.0000 | 1.000 |
| 3 | 12 | 0.9952 | 0.0000 | 0.0000 | 1.000 |
| 3 | 14 | 0.9954 | 0.0000 | 0.0000 | 1.000 |
| 4 | 8 | 0.9954 | 0.0000 | 0.0000 | 1.000 |
| 4 | 10 | 0.9954 | 0.0000 | 0.0000 | 1.000 |
| 4 | 12 | 0.9952 | 0.0000 | 0.0000 | 1.000 |
| 4 | 14 | 0.9957 | 0.0000 | 0.0000 | 1.000 |
| 5 | 8 | 0.9954 | 0.0000 | 0.0000 | 1.000 |
| 5 | 10 | 0.9954 | 0.0000 | 0.0000 | 1.000 |
| 5 | 12 | 0.9954 | 0.0000 | 0.0000 | 1.000 |
| 5 | 14 | 0.9955 | 0.0000 | 0.0000 | 1.000 |

Selection rule outcome: swap 3 h, flip 12 h (recall 0.9952, FAR 0.0000).


## Human co-review agreement

Reported as co-review agreement, not Cohen's κ — the review was collaborative (one shared worksheet), so the independent label sets κ requires never existed.

| Track | n | Immediate agreement |
|---|---|---|
| Flagged temporal errors | 75 | 64.0% |
| Statistically atypical cases | 37 | 89.2% |

## Honest caveats

1. **cross_participant_spike is the weakest family** — L1 0.886–0.907 across seeds, value-correct 0 by design (audit-only: a spike may be real).
2. **SOL thresholds sit inside the ±75-min Bland-Altman noise band** — SOL flags are descriptive, routed to human review; never cited as accuracy.
3. **Ablation recall uses a flag-based definition** (AUTO_FIXed records never enter the flag queue) — reported as supplementary; primary evidence is the multiverse variance decomposition.

4. **Operating-point analysis is synthetic-only** — real data has no ground truth, so recall is undefined there (the real-data spec curve measures downstream means only, which cannot move: n_flagged = 0 under every spec). The plateau verdict holds on the synthetic benchmark; real-world threshold choice should be re-checked on external data.
## Reproducibility

```r
# from the repo root, after renv::restore() and installing splsleep
Rscript validation/synthetic/ppv_cluster_ci.R   # synthetic benchmark (recall/spec/FAR)
Rscript validation/synthetic/operating_point_sweep.R  # threshold operating-point analysis
Rscript validation/audit_review_queue_m1_m7.R   # real-data audit (requires local data)
Rscript validation/render_validation_report.R   # re-render this report from the CSVs
```

The synthetic layer is fully reproducible from committed CSVs. The real-data audit requires the gitignored local dataset.

