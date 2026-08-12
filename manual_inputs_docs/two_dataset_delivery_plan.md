# Two-Dataset Delivery Plan

> **Separate from `column_review_2026-08-05_EN.md`.** This document defines what two datasets the pipeline will output, their column schemas, and the naming conventions. The column review (sections A-O) governs which pipeline columns are *available*. This plan governs how those columns are *packaged and named* for delivery.

---

## Why Two Datasets

| Dataset | Purpose | Content |
|---------|---------|---------|
| **`cleaned_data_final`** | Analysis-ready. A researcher opens this and starts modeling. | ~35 columns: final corrected values only, short clear names |
| **`cleaned_data_prepostcorrection`** | Traceability. A researcher asks "was this record changed? what was the original?" | ~15 columns: pre/post pairs of sleep timestamps only, plus correction flag |

The column review (`column_review_2026-08-05_EN.md`) lists all 100+ pipeline columns. Most (raw strings, intermediate flags, reasonability booleans, staging columns) stay in `cleaned_data_full` — not in either final dataset.



## Dataset A: `cleaned_data_final` (~35 columns)

\### Identifiers

 

| New Name | Source Column |
 |----------|--------------|
 | `pid` | `pid` |
 | `day_num` | `day_num` |
 | `row_id` | `row_id` |

 

\### Final Sleep Timestamps (post-correction only)

 

| New Name | Source Column | Unit |
 |----------|--------------|------|
 | `bedtime_selfreport_ts` | `time_bed_corrected` | POSIXct |
 | `sleeponset_selfreport_ts` | `self_diffcalc_sleeponset` | POSIXct |
 | `awakening_selfreport_ts` | `time_awake_corrected` | POSIXct |
 | `getup_selfreport_ts` | `time_getup_corrected` | POSIXct |

 

\### Sleep Metrics

 

| New Name | Source Column | Unit |
 |----------|--------------|------|
 | `tst_minutes` | `self_diffcalc_totalsleeptime_minutes` | minutes |
 | `sol_minutes` | `self_diffcalc_sol_minutes` | minutes |
 | `se_percent` | `sleep_efficiency_pct` | 0–100 |
 | `tib_minutes` | `self_diffcalc_timeinbed_minutes` | minutes |
 | `sleepperiod_minutes` | `self_diffcalc_sleepperiod_minutes` | minutes |
 | `trysleep_minutes` | `self_diffcalc_totaltrysleep_minutes` | minutes |
 | `waso_avg_minutes` | `avg_waso_estimate_am_minutes` | minutes |

 

\### Self-Reported Durations (participant estimates)

 

| New Name | Source Column | Unit |
 |----------|--------------|------|
 | `sol_selfreport_minutes` | `duration_totalmin_sol_estimate_am_mincalc` | minutes |
 | `waso_selfreport_minutes` | `duration_totalmin_waso_estimate_am_mincalc` | minutes |
 | `num_waso_bouts_selfreport` | `num_waso_estimate_am` | count |

 

\### Nap & Exercise

 

| New Name | Source Column | Unit |
 |----------|--------------|------|
 | `nap_selfreport_totalminutes` | `duration_totalmin_napstoday_PM_mincalc` | minutes |
 | `exercise_light_minutes` | `exercisetoday_PM_totalmin_Light_mincalc` | minutes |
 | `exercise_moderate_minutes` | `exercisetoday_PM_totalmin_Moderate_mincalc` | minutes |
 | `exercise_vigorous_minutes` | `exercisetoday_PM_totalmin_Vigorous_mincalc` | minutes |
 | `exercise_strength_minutes` | `exercisetoday_PM_totalmin_Strength_mincalc` | minutes |

 

\### Correction Traceability

 

| New Name | Source Column | Values |
 |----------|--------------|--------|
 | `has_correction` | `has_correction` | none / algorithmic / manual / both |
 | `is_error` | `is_error` | TRUE / FALSE |
 | `error_type` | `error_type` | order_error / bed_sleep_diff_error / ... |
 | `is_unusual` | `is_unusual` | TRUE / FALSE |
 | `unusual_type` | `unusual_type` | sleep_awake_suspicious / ... |

 

\### Quality Flags

 

| New Name | Source Column | Values |
 |----------|--------------|--------|
 | `flag_severity` | `flag_severity` | Clean / Minor / Major |
 | `needs_review` | `needs_review_flag` | TRUE / FALSE |
 | `auto_error_desc` | `auto_error_desc` | text |

 

\### Substance Use

 

| New Name | Source Column |
 |----------|--------------|
 | `caffeine_num` | `caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1` |
 | `alcohol_num` | `alcoholtoday_PM_NumAlcoholicDrinks_1` |
 | `nicotine_doses` | `nicotine_amount_pm_doses` |
 | `cannabis_doses` | `cannabis_amount_pm_doses` |



---

## Dataset B: `cleaned_data_prepostcorrection (~15 columns)

### Identifiers

| New Name | Source Column |
|----------|--------------|
| `pid` | `pid` |
| `day_num` | `day_num` |

### Pre/Post Sleep Timestamps

> Each sleep event appears twice: before correction and after correction. Side-by-side comparison.

| New Name | Source Column |
|----------|--------------|
| `bedtime_precorrection` | `time_bed_am_hhmm_ampm` |
| `bedtime_postcorrection` | `time_bed_corrected` |
| `sleeponset_precorrection` | `time_sleep_am_hhmm_ampm` |
| `sleeponset_postcorrection` | `self_diffcalc_sleeponset` |
| `awakening_precorrection` | `time_awake_am_hhmm_ampm` |
| `awakening_postcorrection` | `time_awake_corrected` |
| `getup_precorrection` | `time_getup_am_hhmm_ampm` |
| `getup_postcorrection` | `time_getup_corrected` |

### Context

| New Name | Source Column | Why |
|----------|--------------|-----|
| `has_correction` | `has_correction` | Was this record touched? |
| `tst_minutes` | `self_diffcalc_totalsleeptime_minutes` | Resulting sleep duration |
| `sol_selfreport_minutes` | `duration_totalmin_sol_estimate_am_mincalc` | What the participant thought |

`is_reasonable_unusual`  Step 6  Human reviewer marked as "reasonable unusual pattern"  ✅  

### D. Correction Traceability

Answers: "Was this record modified? By whom? What kind of fix?"

| Column                  | Source   | Description                                                  |  AI  | Approve |
| ----------------------- | -------- | ------------------------------------------------------------ | :--: | :-----: |
| `corrected`             | Step 4   | Algorithmic correction applied (TRUE/FALSE)                  |  ❌   |    ⬜    |
| `correction_type`       | Step 4   | Algorithmic correction type string (e.g. "sleep_reduce_12h_loop") |  ❌   |    ⬜    |
| `manually_corrected`    | Step 6/8 | Manual correction applied (TRUE/FALSE)                       |  ❌   |    ⬜    |
| `has_correction`        | Step 7   | enum: none / algorithmic / manual / both — replaces the three above in final |  ✅   |    ⬜    |
| `is_reasonable_unusual` | Step 6   | Human reviewer marked as "reasonable unusual pattern"        |  ✅   |    ⬜    |

### 

### E. Classification & Flags

| Column            | Source    | Description                                             |  AI  | Approve |
| ----------------- | --------- | ------------------------------------------------------- | :--: | :-----: |
| `data_category`   | Step 6    | ❌ **REMOVE** — internal process label, meeting decision |  ❌   |    —    |
| `is_error`        | Step 6    | Whether record has an error                             |  ✅   |    ⬜    |
| `error_type`      | Step 6    | Specific error type text                                |  ✅   |    ⬜    |
| `is_unusual`      | Step 6    | Whether record has unusual pattern                      |  ✅   |    ⬜    |
| `unusual_type`    | Step 6    | Unusual type text                                       |  ✅   |    ⬜    |
| `equal_time_type` | Step 6    | Which time pairs are equal                              |  ⚠️   |    ⬜    |
| `flag_severity`   | viz layer | Clean / Minor / Major (based on SOL/SE/WASO thresholds) |  ✅   |    ⬜    |

### 

### How to use Dataset B

```r
# Records where bedtime was algorithmically corrected:
compare %>% filter(has_correction == "algorithmic", bedtime_pre != bedtime_post)

# Records where the participant's SOL estimate differs from computed:
compare %>% mutate(sol_computed = as.numeric(sleeponset_post - bedtime_post, units = "mins"))
```

This is the dataset behind Figure 2 (Correction Impact). Every dot in the identity scatter plot is one row here.

---

## Column Naming Convention

| Rule | Example |
|------|---------|
| All lowercase | `tst_minutes` not `TST_Minutes` |
| Underscore separator | `sleeponset_pre` not `sleepOnsetPre` |
| Unit in name if not obvious | `tst_minutes`, `se_percent` |
| POSIXct columns: no unit tag | `bedtime`, `sleeponset` |
| `_pre` = before correction | `bedtime_pre` |
| `_post` = after correction | `bedtime_post` |

---

## What Is NOT in Either Dataset

These remain in `cleaned_data_full` only:

- All raw `*_hhmm` / `*_ampm` strings (16 columns — replaced by `*_pre` POSIXct)

- All `*_checkforerrors` flags (22 columns)

- All `*_correctionsmade` logs (7 columns)

- `correction_type` (Step 4 mechanism string — replaced by `has_correction` enum)

- `corrected`, `manually_corrected` booleans (replaced by `has_correction`)

- `data_category`, `has_na`, `order_correct`, all `reasonable_*`, all `*_suspicious` booleans

- `sol_category`, `se_category`, `tst_tib_ratio_category`, `se_is_insane_negative`

- `time_bed_manual`, `time_sleep_manual`, `time_awake_manual`, `time_getup_manual`

- `num_waso_am`, `exercisetoday_*` raw strings, `duration_totalmin_napstoday_PM` raw

- `sleep_awake_diff_min`, `bed_sleep_diff_h`, `sleep_awake_diff_h`, `awake_getup_diff_h`

- `StartDate`

- Substance timestamp raw strings (caffeine/alcohol/nicotine/cannabis `_hhmm` + `_ampm`)

   # we want to keep the substance timestamp, also the number of substances, why they not here. Put them back in here!!! we want the other stuff in ads the other things that has nothing to do with the pipeline and the cleaning, we want this purpose to be the part of the code

- `caffeine_input_anomaly` / `alcohol_input_anomaly` / `nicotine_input_anomaly` / `cannabis_input_anomaly`

- `bed_sleep_equal`, `awake_getup_equal`, `equal_time_type`

- All passive EMA columns from RDS (mood, stress, context)

---

## Implementation

One function called at end of `run_pipeline()`:

```r
finalize_columns(corrected_ema_data)
```

Returns a list:
```r
list(
  cleaned_data_final  = <dataframe>,   # Dataset A
  cleaned_data_compare = <dataframe>,  # Dataset B
  column_map = <dataframe>            # source → new name mapping
)
```

Writes three files:
- `cleaned_data_final.rds` / `.csv`
- `cleaned_data_prepostcorrection.rds` / `.csv`
- `column_map.csv`

Zero pipeline logic changes. Pure column select + rename at the end.
