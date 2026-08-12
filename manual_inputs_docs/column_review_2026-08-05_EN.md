# Output Column Inventory — Awaiting Approval (v2, AI Recommendations)

> **Principle: No pipeline changes. This document is for your line-by-line review before I implement anything.**

---

## Final Delivery Architecture

```
run_pipeline()
    │
    ├── cleaned_data_final.rds   ← 30-40 columns for analysis. Ready-to-use for collaborators.
    ├── cleaned_data_final.csv   ← Same, CSV format (non-R user friendly)
    │
    ├── cleaned_data_full.rds    ← 100+ columns, full pipeline output. For debugging / traceability.
    │
    └── column_map.csv           ← Column mapping table.
         Columns: column_name | category | source_file | step | description | in_final
         Tells you: where each column came from (RDS/CSV/Step N), what it means, whether it's in final.
```

### Data Source Quick Reference

| Source | Scope |
|--------|-------|
| **RDS** (`deidentified_intervalvars_forCD_111325.rds`) | pid, day_num, all sleep times, substance counts, all passive EMA columns |
| **CSV** (`sber_ema_anon_20260227.csv`) → `extra` | StartDate, num_waso, num_waso_estimate_am (3 columns merged into main) |
| **Step 2** (timestamp parse) | `*_hhmm_ampm` (POSIXct times), `*_checkforerrors` (parse warnings) |
| **Step 3** (interval parse) | `*_mincalc`, `*_checkforerrors`, `*_correctionsmade` |
| **Step 4** (normalize) | `*_corrected`, `corrected`, `correction_type`, `has_na`, `row_id` |
| **Step 6** (manual corrections) | `manually_corrected`, classification columns (`is_error`, `error_type`, etc.) |
| **Step 7** (metrics) | `self_diffcalc_*`, `avg_waso_*` |
| **Step 8** (auto-detect) | `needs_review_flag`, `auto_error_desc`, substance check flags |
| **viz layer** (Step 9) | `sleep_duration_h`, `sol_h`, `waso_h`, `sleep_efficiency_pct`, `flag_*` |

---

## Section 1: Final Output Candidate Columns

> AI legend: ✅ = include in final | ❌ = full only | ⚠️ = needs your decision

### A. Identifiers & Keys

| Column | Source | Description | AI | Approve |
|--------|--------|-------------|:--:|:--:|
| `pid` | RDS | Participant ID | ✅ | ⬜ |
| `day_num` | RDS | Study day number | ✅ | ⬜ |
| `row_id` | Step 4 | Row number (traceability key) | ✅ | ⬜ |

### B. Sleep Timestamps (full chain: raw → parsed → corrected → derived)

> Each sleep event (bed/sleep/awake/getup) exists in three layers. All must be listed individually for discussion.

| Column | Layer | Source | Description | AI | Approve |
|--------|-------|--------|-------------|:--:|:--:|
| `time_bed_am_hhmm` | Raw | RDS | Bedtime HH:MM string | ❌ | Yes |
| `time_bed_am_ampm` | Raw | RDS | Bedtime AM/PM indicator | ❌ | Yes |
| `time_sleep_am_hhmm` | Raw | RDS | Sleep onset HH:MM string | ❌ | Yes |
| `time_sleep_am_ampm` | Raw | RDS | Sleep onset AM/PM indicator | ❌ | Yes |
| `time_awake_am_hhmm` | Raw | RDS | Awakening HH:MM string | ❌ | Yes |
| `time_awake_am_ampm` | Raw | RDS | Awakening AM/PM indicator | ❌ | Yes |
| `time_getup_am_hhmm` | Raw | RDS | Get-up HH:MM string | ❌ | Yes |
| `time_getup_am_ampm` | Raw | RDS | Get-up AM/PM indicator | ❌ | Yes |
| `time_bed_am_hhmm_ampm` | Parsed | Step 2 | Parsed bedtime POSIXct | ⚠️ | ⬜ |
| `time_sleep_am_hhmm_ampm` | Parsed | Step 2 | Parsed sleep onset POSIXct | ⚠️ | ⬜ |
| `time_awake_am_hhmm_ampm` | Parsed | Step 2 | Parsed awakening POSIXct | ⚠️ | ⬜ |
| `time_getup_am_hhmm_ampm` | Parsed | Step 2 | Parsed get-up POSIXct | ⚠️ | ⬜ |
| `time_bed_corrected` | Corrected | Step 4→6 | Final bedtime POSIXct | ✅ | ⬜ |
| `time_sleep_corrected` | Corrected | Step 4→6 | Final sleep onset POSIXct | ✅ | ⬜ |
| `time_awake_corrected` | Corrected | Step 4→6 | Final awakening POSIXct | ✅ | ⬜ |
| `time_getup_corrected` | Corrected | Step 4→6 | Final get-up POSIXct | ✅ | ⬜ |
| `selff_diffcalc_sleeponset` | Deved | Step 7 | Sleep onset POSIXct (input to sleepperiod; equals time_sleep_corrected) | ✅ | ⬜ |

> **Parsed layer (`*_hhmm_ampm`) marked ⚠️:** These feed Dataset B (`*_pre` columns). If Dataset B is generated, decide whether these also belong in Dataset A. Marked ⚠️ = your call.

### C. Core Sleep Metrics (Step 7)

These are the primary analysis variables. TST (Total Sleep Time) is the main outcome variable for most sleep studies.

| Column | Source | Description | AI | Approve |
|--------|--------|-------------|:--:|:--:|
| `self_diffcalc_sol_minutes` | Step 7 | SOL (Sleep Onset Latency, minutes) | ✅ | ⬜ |
| `self_diffcalc_sleeponset` | Step 7 | Final sleep onset timestamp (POSIXct) — input to sleep period calculation | ✅ | ⬜ |
| `self_diffcalc_totalsleeptime_minutes` | Step 7 | TST (Total Sleep Time, minutes) — **primary outcome** | ✅ | ⬜ |
| `self_diffcalc_timeinbed_minutes` | Step 7 | TIB (Time in Bed, minutes) | ✅ | ⬜ |
| `self_diffcalc_sleepperiod_minutes` | Step 7 | Sleep period duration | ✅ | ⬜ |
| `self_diffcalc_totaltrysleep_minutes` | Step 7 | Total try-sleep duration (SE denominator) | ✅ | ⬜ |
| `self_diffcalc_sleepefficiency_percent` | Step 7 | Sleep efficiency (0-1 fraction) ⚠ misleading name — stored as fraction, not percent | ⚠️ | ⬜ |
| `avg_waso_estimate_am_minutes` | Step 7 | Average WASO bout duration | ✅ | ⬜ |

### D. Correction Traceability

Answers: "Was this record modified? By whom? What kind of fix?"

| Column | Source | Description | AI | Approve |
|--------|--------|-------------|:--:|:--:|
| `corrected` | Step 4 | Algorithmic correction applied (TRUE/FALSE) | ❌ | ⬜ |
| `correction_type` | Step 4 | Algorithmic correction type string (e.g. "sleep_reduce_12h_loop") | ❌ | ⬜ |
| `manually_corrected` | Step 6/8 | Manual correction applied (TRUE/FALSE) | ❌ | ⬜ |
| `has_correction` | Step 7 | enum: none / algorithmic / manual / both — replaces the three above in final | ✅ | ⬜ |
| `is_reasonable_unusual` | Step 6 | Human reviewer marked as "reasonable unusual pattern" | ✅ | ⬜ |

### E. Classification & Flags

| Column | Source | Description | AI | Approve |
|--------|--------|-------------|:--:|:--:|
| `data_category` | Step 6 | ❌ **REMOVE** — internal process label, meeting decision | ❌ | — |
| `is_error` | Step 6 | Whether record has an error | ✅ | ⬜ |
| `error_type` | Step 6 | Specific error type text | ✅ | ⬜ |
| `is_unusual` | Step 6 | Whether record has unusual pattern | ✅ | ⬜ |
| `unusual_type` | Step 6 | Unusual type text | ✅ | ⬜ |
| `equal_time_type` | Step 6 | Which time pairs are equal | ⚠️ | ⬜ |
| `flag_severity` | viz layer | Clean / Minor / Major (based on SOL/SE/WASO thresholds) | ✅ | ⬜ |

### F. Auto-Detection Flags (Step 8)

| Column | Source | Description | AI | Approve |
|--------|--------|-------------|:--:|:--:|
| `auto_error_desc` | Step 8 | Full text description of all detected issues — **debug only, not in Dataset A or B** | ❌ | ⬜ |
| `needs_review_flag` | Step 8 | Redundant with structured columns (is_error + is_unusual + flag_severity) | ❌ | ⬜ |
| `caffeine_value_checkforerrors` | Step 8 | Caffeine input anomaly | ❌ | ⬜ |
| `alcohol_value_checkforerrors` | Step 8 | Alcohol input anomaly | ❌ | ⬜ |
| `nicotine_value_checkforerrors` | Step 8 | Nicotine input anomaly | ❌ | ⬜ |
| `cannabis_value_checkforerrors` | Step 8 | Cannabis input anomaly | ❌ | ⬜ |

### G. Substance Use Counts (Raw RDS Columns)

These are the participant-reported substance consumption counts. Essential for any behavioral analysis.

| Column | Source | Description | AI | Approve |
|--------|--------|-------------|:--:|:--:|
| `caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1` | RDS | Caffeine intake | ✅ | ⬜ |
| `alcoholtoday_PM_NumAlcoholicDrinks_1` | RDS | Alcohol intake | ✅ | ⬜ |
| `nicotine_amount_pm_doses` | RDS | Nicotine intake | ✅ | ⬜ |
| `cannabis_amount_pm_doses` | RDS | Cannabis intake | ✅ | ⬜ |

### H. Duration Columns (mincalc — Step 3 processed values in minutes)

| Column | Source | Description | AI | Approve |
|--------|--------|-------------|:--:|:--:|
| `duration_totalmin_sol_estimate_am_mincalc` | RDS→Step 3 | Self-reported SOL (minutes) | ✅ | ⬜ |
| `duration_totalmin_waso_estimate_am_mincalc` | RDS→Step 3 | Self-reported WASO (minutes) | ✅ | ⬜ |
| `num_waso_estimate_am` | CSV→main | WASO bout count | ✅ | ⬜ |
| `duration_totalmin_napstoday_PM_mincalc` | RDS→Step 3 | Nap duration (minutes) — useful for comparing self-reported vs objective nap | ✅ | ⬜ |
| `exercisetoday_PM_totalmin_Light_mincalc` | RDS→Step 3 | Light exercise (minutes) | ✅ | ⬜ |
| `exercisetoday_PM_totalmin_Moderate_mincalc` | RDS→Step 3 | Moderate exercise (minutes) | ✅ | ⬜ |
| `exercisetoday_PM_totalmin_Vigorous_mincalc` | RDS→Step 3 | Vigorous exercise (minutes) | ✅ | ⬜ |
| `exercisetoday_PM_totalmin_Strength_mincalc` | RDS→Step 3 | Strength training (minutes) | ✅ | ⬜ |

### I. Contract Columns (Promoted from viz to Step 7)

These provide the same metrics as Section C but in hours (for readability) and as true percentages (for sleep efficiency).

| Column | Current Location | Value | AI | Approve |
|--------|----------|-------|:--:|:--:|
| `sleep_duration_h` | viz layer | TST / 60 | ✅ | ⬜ |
| `sol_h` | viz layer | SOL / 60 | ✅ | ⬜ |
| `waso_h` | viz layer | WASO / 60 | ✅ | ⬜ |
| `sleep_efficiency_pct` | viz layer | SE × 100 (true percentage 0-100) | ✅ | ⬜ |
| `time_in_bed_h` | viz layer | TIB / 60 | ✅ | ⬜ |

---

## Section 2: Full-Only Columns (for Traceability)

> Sleep timestamps (raw strings, parsed POSIXct) are listed in Section B. Only substance timestamps remain here.

### J. Raw Substance Timestamp Strings

| Column | Source | AI | Approve |
|--------|--------|:--:|:--:|
| `caffeinetoday_PM_hhmm` / `caffeinetoday_PM_ampm` | RDS | ❌ | ⬜ |
| `alcoholtoday_PM_hhmm` / `alcoholtoday_PM_ampm` | RDS | ❌ | ⬜ |
| `nicotine_amount_pm_hhmm` / `nicotine_amount_pm_ampm` | RDS | ❌ | ⬜ |
| `cannabis_amount_pm_hhmm` / `cannabis_amount_pm_ampm` | RDS | ❌ | ⬜ |
| `StartDate` | CSV→main | ❌ | ⬜ |

### K. Parse & Correction Audit Logs

| Column | Source | AI | Approve |
|--------|--------|:--:|:--:|
| `time_bed_am_checkforerrors` (8 cols) | Step 2 | ❌ | ⬜ |
| `duration_totalmin_sol_estimate_am_checkforerrors` (7 cols) | Step 3 | ❌ | ⬜ |
| `duration_totalmin_sol_estimate_am_correctionsmade` (7 cols) | Step 3 | ❌ | ⬜ |
| `has_na` | Step 4 | ❌ | ⬜ |
| `caffeine_input_anomaly` (4 cols) | Step 8 | ❌ | ⬜ |

### M. Reasonability Flags (Step 6)

Internal diagnostic booleans used by the correction engine to decide classification.

| Column | AI | Approve |
|--------|:--:|:--:|
| `order_correct` / `reasonable_temporal_order` | ❌ | ⬜ |
| `reasonable_sleep_latency` / `reasonable_time_in_bed_after_waking` / `reasonable_sleep_duration` | ❌ | ⬜ |
| `bed_sleep_diff_h` / `sleep_awake_diff_h` / `awake_getup_diff_h` | ❌ | ⬜ |
| `bed_sleep_equal` / `awake_getup_equal` | ❌ | ⬜ |
| `sleep_awake_suspicious` / `bed_sleep_suspicious` / `awake_getup_suspicious` | ❌ | ⬜ |

### N. Step 8 Review Detail Columns

Categorical breakdowns from the auto-detection system. Redundant with the combined `auto_error_desc` in final.

| Column | AI | Approve |
|--------|:--:|:--:|
| `sol_category` / `se_category` / `se_is_insane_negative` / `tst_tib_ratio_category` | ❌ | ⬜ |

### O. Excluded from All Outputs (Intermediate Staging)

These are temporary columns used during pipeline execution. They should not appear in either final or full.

| Column | Reason | AI | Approve |
|--------|--------|:--:|:--:|
| `time_bed_manual` (4 cols) | Step 6 staging columns for manual corrections | ❌ | ⬜ |
| `num_waso_am` | Duplicate of `num_waso_estimate_am` | ❌ | ⬜ |
| `exercisetoday_PM_totalmin_*` raw strings | Keep only `_mincalc` versions | ❌ | ⬜ |
| `duration_totalmin_napstoday_PM` raw | Keep only `_mincalc` version | ❌ | ⬜ |

---

## Section 3: Design Decisions (Pick One Per Question)

### Q1: Rename `self_diffcalc_sleepefficiency_percent`?

This column is named "percent" but stores a 0-1 fraction. The true percentage (`sleep_efficiency_pct`) lives in the viz layer.

| Option | AI |
|--------|:--:|
| A: Rename to `_fraction` | **✅ Recommended A** — name should match content |
| B: Keep as-is, document in SCHEMA.md | |
| **Decision** | ⬜ |

### Q2: What replaces `data_category` in final?

`data_category` has been removed per meeting decision. What should replace it for downstream users who need a quick status label?

| Option | AI |
|--------|:--:|
| A: Nothing — use `is_error` + `is_unusual` + `has_correction` together | |
| B: Keep but rename to `record_status` | |
| C: Create new `record_status` column with simplified values | **✅ Recommended C** — values: "clean" / "error" / "unusual" / "equal_time" / "not_reported" |
| **Decision** | ⬜ |

### Q3: Promote viz-layer flag columns to final?

These flag columns are currently computed only in the visualization layer. Should any be promoted to Step 7 for inclusion in final output?

Columns: `flag_duration_extreme`, `flag_poor_efficiency`, `flag_high_sol`, `flag_high_waso`, `flag_issue_count`, `flag_severity`

| Option | AI |
|--------|:--:|
| A: Only `flag_severity` | **✅ Recommended A** — minimal intrusion, maximum value |
| B: Promote all | |
| C: Keep all in full only | |
| **Decision** | ⬜ |

### Q4: Shorten long column names?

Current names are verbose (e.g. `self_diffcalc_totalsleeptime_minutes` → suggested `tst_minutes`). Shortening adds readability but introduces rename risk.

| Option | AI |
|--------|:--:|
| A: Keep original names | **✅ Recommended A** — avoid rename bugs, stability first |
| B: Short names in final, original in full | |
| C: Shorten all | |
| **Decision** | ⬜ |

### Q5: `has_correction` — new enum vs keep existing columns?

The current approach has three separate columns (`corrected`, `correction_type`, `manually_corrected`). The new `has_correction` enum consolidates them.

| Option | AI |
|--------|:--:|
| A: Add enum + keep original columns | **✅ Recommended A** — final uses enum, full preserves original booleans |
| B: New replaces old | |
| C: Don't add new column | |
| **Decision** | ⬜ |

### Q6: Passive EMA columns from source RDS?

The original RDS contains hundreds of passive EMA variables (mood, stress, context questions, etc.) beyond the sleep diary fields.

| Option | AI |
|--------|:--:|
| A: Keep all in full (no impact on final) | **✅ Recommended A** — preserve everything, let the researcher decide what to use |
| B: Keep only confirmed-useful columns | |
| **Decision** | ⬜ |

---

> **Status: Awaiting your line-by-line approval before implementation.**
