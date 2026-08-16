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
| `far_flag_alter.csv` | far_flag_mrr_magnitude.R | 20260817 | 1,609 ctrl | FAR_flag, FAR_alter + rule-of-three 95% upper bound (0.186% @ 0 hits) | point estimate + upper bound |
| `mrr_magnitude.csv` | far_flag_mrr_magnitude.R | 20260817 | 4,745 inj | per-category MRR + magnitude | point estimate |
| `mrr_per_row.csv` | far_flag_mrr_magnitude.R | 20260817 | 4,745 | per-row kind + magnitude | — |
| `control_baselines.csv` | control_baselines.R | 20260817 | 4,745 | no-cleaning / naive-rule / pipeline recall + FAR | point estimate |
| `multiverse/oat_screening.csv` | multiverse.R | — | 13 specs | downstream qty per OAT level | none (screening) |
| `multiverse/spec_curve.csv` | multiverse.R | — | **3 specs (D1-only)** | mean TST/SOL/SE, analyzable n | none (deterministic, robust survivors) |
| `multiverse/spec_curve_full.csv` | multiverse.R | — | **9 specs (3^2)** | mean TST/SOL/SE, analyzable n | none (deterministic, appendix incl. marginal D2) |
| `multiverse/instability.csv` | multiverse.R | — | 5 specs | record classification by spec | none |
| `multiverse/variance_decomposition.csv` | multiverse.R | — | 9 specs | sum_sq + proportion per dim | ANOVA (descriptive) |
| `downstream_sensitivity.csv` | downstream_sensitivity.R | — | — | multiverse ranges + B1/B2 | none |
| `l2_tier.csv` | l2_tier_leave_one_out.R | 20260817 | 4,745 | per-category L1/L2/L3 | point estimate |
| `leave_one_out.csv` | l2_tier_leave_one_out.R | 20260817 | 4,745 | recall/workload per ablation | deterministic via spec_cache (issue #6 closed) |
| `seed_sensitivity.csv` | seed_sensitivity.R | 20260812/17, 20260901/15 | 4×~5,400 | pooled recall, FAR, weak-cat recall, OAT survivors | point estimates, 4 seeds |
| `real_data_oat_screening.csv` | real_data_spec_curve.R | — | 13,990 | downstream qty per OAT level (real data) | none (screening) |
| `real_data_spec_curve.csv` | real_data_spec_curve.R | — | 13,990 | mean TST/SOL/SE, analyzable n per spec | none (deterministic, D2 fallback) |

## Multiverse — spec curve on robust survivors + full factorial appendix

The plan (08-14 meeting notes) expected "OAT → full factorial on surviving
4–6 dimensions (3^5 = 243)". OAT screening (multiverse.R) on the benchmark
seed keeps 2 of 6 dimensions:

- D1 flip_gap_hours (12h AM/PM flip threshold) — moves mean SOL strongly
- D2 swap_threshold_hours (minor-order swap) — moves mean TST/n (marginally)

D3–D6 (flag thresholds: SOL excessive, SE poor, WASO excessive, TST/TIB ratio)
change **no** downstream quantity or flag count on the healthy-adult
enrichment set → dropped by the ≥1% / ≥5-min survival rule.

**MAIN spec curve = robust survivors only (spec_curve.csv, 3 specs).**
The OAT survival decision is seed-sensitive (seed_sensitivity.csv): seed
20260817 → D1+D2; seed 20260915 → D1 only. D2 sits at the 5min/1% edge and
flips with the seed. The main curve therefore uses the across-seed
intersection — D1 alone → **3 specs** (D1=11/12/13). This is the
manuscript-facing specification curve.

**Appendix = full factorial on single-seed survivors (spec_curve_full.csv,
9 specs).** Includes the marginal D2 (D1×D2, 3^2). Kept for transparency;
the D1×D2 interaction is seed-marginal and should not be quoted as robust.

243 is not claimed as a result; it was the pre-OAT worst-case budget.

**Seed sensitivity of the survival decision (seed_sensitivity.csv):** the
D1+D2 → 9-spec selection is a property of the benchmark seed, not universal.
Across 4 seeds (20260812/17, 20260901/15):

- pooled recall stable 0.9935–0.9952, FAR_flag 0 across all seeds → the 5.1
  headline is robust.
- weak categories stable: cross_participant_spike 0.886–0.907 (always
  lowest); adjacent_swap_awake_getup + ampm_swap = 1.0 everywhere.
- OAT survival is seed-sensitive: seed 20260817 → D1+D2; seed 20260915 →
  D1 only (D2's swap effect sits at the 5min/1% edge). Report the full
  factorial as benchmark-seed-specific; D1 is the robust survivor, D2 is
  marginal. D3–D6 never survive on any seed.

## Real-data spec curve (real_data_spec_curve.csv) — thresholds insensitive

Multiverse on real n=13,990 (input + sber extra csv for StartDate):

- **No dimension passes the survival rule**: max |ΔTST| 0.93 min, max |Δn|
  0.70% across D1–D6. Downstream quantities are insensitive to cleaning
  thresholds on real data. (spec_curve is the D2 fallback, not a selection.)
- Only 1,719/13,990 rows (12.3%) have analyzable TST — the real-data
  cleaning surface is small, which is why thresholds barely matter there.
- D3–D6 move NOTHING on real data either → flag thresholds don't affect
  downstream values (synthetic and real agree).
- n_flagged = 0 on real data under every spec → the human-review workload
  on real data comes from checkforerrors flags only, never needs_review_flag.

## L3 value-correct rate — read it right (do not misquote 0.486)

Pooled L3 (value_correct) is 0.486, which LOOKS like "the pipeline only fixes
half of what it detects". That is a misreading. The per-row outcome split
(mrr_per_row.csv) is:

- **CORRECT** 2,619 (auto-fixed to ground truth)
- **FLAGGED** 2,746 (surfaced for human review, NOT auto-changed)
- **MISREPAIRED** 26 (auto-changed to the WRONG value — the true error rate)
- MISSED: the remainder (recall gap, see recall_specificity_ci.csv)

The design is conservative: when the pipeline cannot confirm a value it flags
and stops (needs_review_flag), it does not guess. So L3 is the "confident
auto-fix" rate, NOT the "correctness of cleaning" rate. The manuscript-facing
numbers are:

- Pooled detection (L1): 0.9952 — everything surfaced
- Corrected-or-flagged (safe outcome): (2619+2746)/5391 = 0.9952 — nothing
  silently lost except the recall gap
- Misrepair (MISREPAIRED): pooled MRR 0.0048 (26/5391) — the only harmful
  outcome
- Misrepair magnitude: median ~0 min (see mrr_magnitude.csv)

Quoting "L3 = 0.486" without this context misleads. Report L1 + MRR + the
corrected-or-flagged safe outcome.

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
Rscript validation/synthetic/multiverse.R                # 5.4 tables (cached via spec_cache)
Rscript validation/synthetic/downstream_sensitivity.R    # 5.5 table
Rscript validation/synthetic/l2_tier_leave_one_out.R     # 5.2 + 5.6 (cached via spec_cache)
Rscript audit_review_queue_m1_m7.R                       # M1–M7 audit (real data)
Rscript part_b_global_sweep.R                            # Part B sweep (real data)
```

Spec-cache determinism (issues #6/#7, fixed 4e94ef1):
- multiverse + ablation cache per-spec summaries in
  `validation/synthetic/spec_cache/`, keyed on sha256(input rds + config +
  overrides). Same input → cache hit → identical CSVs. Changed input →
  cache invalidated → real re-execution (drift surfaced, not hidden).
- Verified: full multiverse rerun = 27 cache hits, 0 pipeline executions,
  byte-identical CSV output; ablation 4/4 cache hits on rerun.
- The pre-fix "drift" was stale results — corrupted_enrichment.rds is
  .gitignore'd and was regenerated by 2face4d AFTER the CSVs were written.

All scripts reuse cached `validation/synthetic/run_ppv/` outputs when present
(ppv_cluster_ci.R) and `validation/synthetic/spec_cache/` (multiverse +
ablation) — delete those dirs to force full pipeline reruns.
