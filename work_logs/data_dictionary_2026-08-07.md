# Data Dictionary — splsleep v1.4.0

> Every column produced by the pipeline, its destination, and its new name if renamed.
> Delivered by `finalize_columns(corrected_ema_data)` at end of `run_pipeline()`.

---

## Master Table

Columns are presented in the order they are created by the pipeline (Step 1 → Step 9).

| # | Source Column | Step | Type | Destination | New Name (if renamed) |
|---|--------------|------|------|-------------|----------------------|
| 1 | `pid` | 1 | numeric | A + B + Full | `pid` |
| 2 | `day_num` | 1 | numeric | A + B + Full | `day_num` |
| 3 | `time_bed_am_hhmm` | 1 | character | Full | — |
| 4 | `time_bed_am_ampm` | 1 | character | Full | — |
| 5 | `time_sleep_am_hhmm` | 1 | character | Full | — |
| 6 | `time_sleep_am_ampm` | 1 | character | Full | — |
| 7 | `time_awake_am_hhmm` | 1 | character | Full | — |
| 8 | `time_awake_am_ampm` | 1 | character | Full | — |
| 9 | `time_getup_am_hhmm` | 1 | character | Full | — |
| 10 | `time_getup_am_ampm` | 1 | character | Full | — |
| 11 | `caffeinetoday_PM_hhmm` | 1 | character | Full | — |
| 12 | `caffeinetoday_PM_ampm` | 1 | character | Full | — |
| 13 | `alcoholtoday_PM_hhmm` | 1 | character | Full | — |
| 14 | `alcoholtoday_PM_ampm` | 1 | character | Full | — |
| 15 | `nicotine_amount_pm_hhmm` | 1 | character | Full | — |
| 16 | `nicotine_amount_pm_ampm` | 1 | character | Full | — |
| 17 | `cannabis_amount_pm_hhmm` | 1 | character | Full | — |
| 18 | `cannabis_amount_pm_ampm` | 1 | character | Full | — |
| 19 | `caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1` | 1 | numeric | A | `caffeine_num` |
| 20 | `alcoholtoday_PM_NumAlcoholicDrinks_1` | 1 | numeric | A | `alcohol_num` |
| 37 | `nicotine_amount_pm_doses` | 1 | numeric | A | `nicotine_doses` |
| 37 | `cannabis_amount_pm_doses` | 1 | numeric | A | `cannabis_doses` |
| 37 | `duration_totalmin_sol_estimate_am` | 1 | character | Full | — |
| 37 | `duration_totalmin_waso_estimate_am` | 1 | character | Full | — |
| 37 | `duration_totalmin_napstoday_PM` | 1 | character | Full | — |
| 37 | `exercisetoday_PM_totalmin_Light` | 1 | character | Full | — |
| 37 | `exercisetoday_PM_totalmin_Moderate` | 1 | character | Full | — |
| 37 | `exercisetoday_PM_totalmin_Vigorous` | 1 | character | Full | — |
| 37 | `exercisetoday_PM_totalmin_Strength` | 1 | character | Full | — |
| 37 | `num_waso_am` | 1 | numeric | None | — |
| 37 | `num_waso_estimate_am` | 1 | numeric | A | `num_waso_bouts_selfreport` |
| 37 | `StartDate` | 1 | character | A | `StartDate` |
| 37 | `time_bed_am_hhmm_ampm` | 2 | POSIXct | B | `bedtime_precorrection` |
| 37 | `time_sleep_am_hhmm_ampm` | 2 | POSIXct | B | `sleeponset_precorrection` |
| 37 | `time_awake_am_hhmm_ampm` | 2 | POSIXct | B | `awakening_precorrection` |
| 37 | `time_getup_am_hhmm_ampm` | 2 | POSIXct | B | `getup_precorrection` |
| 37 | `caffeinetoday_PM_hhmm_ampm` | 2 | POSIXct | Full | — |
| 38 | `alcoholtoday_PM_hhmm_ampm` | 2 | POSIXct | Full | — |
| 39 | `nicotine_amount_pm_hhmm_ampm` | 2 | POSIXct | Full | — |
| 40 | `cannabis_amount_pm_hhmm_ampm` | 2 | POSIXct | Full | — |
| 41 | `time_bed_am_checkforerrors` | 2 | character | Full | — |
| 42 | `time_sleep_am_checkforerrors` | 2 | character | Full | — |
| 43 | `time_awake_am_checkforerrors` | 2 | character | Full | — |
| 44 | `time_getup_am_checkforerrors` | 2 | character | Full | — |
| 45 | `caffeinetoday_PM_checkforerrors` | 2 | character | Full | — |
| 46 | `alcoholtoday_PM_checkforerrors` | 2 | character | Full | — |
| 47 | `nicotine_amount_pm_checkforerrors` | 2 | character | Full | — |
| 48 | `cannabis_amount_pm_checkforerrors` | 2 | character | Full | — |
| 49 | `duration_totalmin_sol_estimate_am_mincalc` | 3 | numeric | A + B | `sol_selfreport_minutes` |
| 50 | `duration_totalmin_waso_estimate_am_mincalc` | 3 | numeric | A | `waso_selfreport_minutes` |
| 51 | `duration_totalmin_napstoday_PM_mincalc` | 3 | numeric | A | `nap_selfreport_totalminutes` |
| 52 | `exercisetoday_PM_totalmin_Light_mincalc` | 3 | numeric | A | `exercise_light_minutes` |
| 53 | `exercisetoday_PM_totalmin_Moderate_mincalc` | 3 | numeric | A | `exercise_moderate_minutes` |
| 54 | `exercisetoday_PM_totalmin_Vigorous_mincalc` | 3 | numeric | A | `exercise_vigorous_minutes` |
| 55 | `exercisetoday_PM_totalmin_Strength_mincalc` | 3 | numeric | A | `exercise_strength_minutes` |
| 56 | `duration_totalmin_sol_estimate_am_checkforerrors` | 3 | logical | Full | — |
| 57 | `duration_totalmin_waso_estimate_am_checkforerrors` | 3 | logical | Full | — |
| 58 | `duration_totalmin_napstoday_PM_checkforerrors` | 3 | logical | Full | — |
| 59 | `exercisetoday_PM_totalmin_Light_checkforerrors` | 3 | logical | Full | — |
| 60 | `exercisetoday_PM_totalmin_Moderate_checkforerrors` | 3 | logical | Full | — |
| 61 | `exercisetoday_PM_totalmin_Vigorous_checkforerrors` | 3 | logical | Full | — |
| 62 | `exercisetoday_PM_totalmin_Strength_checkforerrors` | 3 | logical | Full | — |
| 63 | `duration_totalmin_sol_estimate_am_correctionsmade` | 3 | character | Full | — |
| 64 | `duration_totalmin_waso_estimate_am_correctionsmade` | 3 | character | Full | — |
| 65 | `duration_totalmin_napstoday_PM_correctionsmade` | 3 | character | Full | — |
| 66 | `exercisetoday_PM_totalmin_Light_correctionsmade` | 3 | character | Full | — |
| 67 | `exercisetoday_PM_totalmin_Moderate_correctionsmade` | 3 | character | Full | — |
| 68 | `exercisetoday_PM_totalmin_Vigorous_correctionsmade` | 3 | character | Full | — |
| 69 | `exercisetoday_PM_totalmin_Strength_correctionsmade` | 3 | character | Full | — |
| 70 | `row_id` | 4 | numeric | A | `row_id` |
| 71 | `has_na` | 4 | logical | Full | — |
| 72 | `time_bed_corrected` | 4 | POSIXct | A + B + Full | A: `bedtime_selfreport_ts`, B: `bedtime_postcorrection` |
| 73 | `time_sleep_corrected` | 4 | POSIXct | Full | — |
| 74 | `time_awake_corrected` | 4 | POSIXct | A + B + Full | A: `awakening_selfreport_ts`, B: `awakening_postcorrection` |
| 75 | `time_getup_corrected` | 4 | POSIXct | A + B + Full | A: `getup_selfreport_ts`, B: `getup_postcorrection` |
| 76 | `corrected` | 4 | logical | Full | — |
| 77 | `correction_type` | 4 | character | Full | — |
| 78 | `data_category` | 4→6 | character | Full | — |
| 79 | `time_bed_manual` | 6 | POSIXct | None | — |
| 80 | `time_sleep_manual` | 6 | POSIXct | None | — |
| 81 | `time_awake_manual` | 6 | POSIXct | None | — |
| 82 | `time_getup_manual` | 6 | POSIXct | None | — |
| 83 | `manually_corrected` | 6 | logical | Full | — |
| 84 | `sleep_awake_diff_min` | 6 | numeric | None | — |
| 85 | `is_error` | 6 | logical | A | `is_error` |
| 86 | `error_type` | 6 | character | A | `error_type` |
| 87 | `is_unusual` | 6 | logical | A | `is_unusual` |
| 88 | `unusual_type` | 6 | character | A | `unusual_type` |
| 89 | `equal_time_type` | 6 | character | Full | — |
| 90 | `is_reasonable_unusual` | 6 | logical | A | `is_reasonable_unusual` |
| 91 | `bed_sleep_diff_h` | 6 | numeric | Full | — |
| 92 | `sleep_awake_diff_h` | 6 | numeric | Full | — |
| 93 | `awake_getup_diff_h` | 6 | numeric | A | `waso_computed_minutes` |
| 94 | `order_correct` | 6 | logical | Full | — |
| 95 | `reasonable_temporal_order` | 6 | logical | Full | — |
| 96 | `reasonable_sleep_latency` | 6 | logical | Full | — |
| 97 | `reasonable_time_in_bed_after_waking` | 6 | logical | Full | — |
| 98 | `reasonable_sleep_duration` | 6 | logical | Full | — |
| 99 | `bed_sleep_equal` | 6 | logical | Full | — |
| 100 | `awake_getup_equal` | 6 | logical | Full | — |
| 101 | `sleep_awake_suspicious` | 6 | logical | Full | — |
| 102 | `bed_sleep_suspicious` | 6 | logical | Full | — |
| 103 | `awake_getup_suspicious` | 6 | logical | Full | — |
| 104 | `self_diffcalc_sol_minutes` | 7 | numeric | A | `sol_computed_minutes` |
| 105 | `self_diffcalc_sleeponset` | 7 | POSIXct | A + B | A: `sleeponset_selfreport_ts`, B: `sleeponset_postcorrection` |
| 106 | `self_diffcalc_totaltrysleep_minutes` | 7 | numeric | A | `trysleep_minutes` |
| 107 | `sol_duration_for_review_status` | 7 | character | Full | — |
| 108 | `duration_totalmin_sol_estimate_am_mincalc_for_review` | 7 | numeric | Full | — |
| 109 | `self_diffcalc_timeinbed_minutes` | 7 | numeric | A | `tib_minutes` |
| 110 | `self_diffcalc_sleepperiod_minutes` | 7 | numeric | A | `sleepperiod_minutes` |
| 111 | `waso_duration_for_metrics_status` | 7 | character | Full | — |
| 112 | `duration_totalmin_waso_estimate_am_mincalc_used` | 7 | numeric | Full | — |
| 113 | `self_diffcalc_totalsleeptime_minutes` | 7 | numeric | A + B | `tst_minutes` |
| 114 | `self_diffcalc_sleepefficiency_percent` | 7 | numeric | Full | — |
| 115 | `avg_waso_estimate_am_minutes` | 7 | numeric | A | `waso_avg_bout_selfreport_minutes` |
| 116 | `sleep_duration_h` | 7 | numeric | Full | — |
| 117 | `sol_h` | 7 | numeric | Full | — |
| 118 | `waso_h` | 7 | numeric | Full | — |
| 119 | `sleep_efficiency_pct` | 7 | numeric | A | `se_percent` |
| 120 | `time_in_bed_h` | 7 | numeric | Full | — |
| 121 | `has_correction` | 7 | character | A + B | `has_correction` |
| 122 | `flag_severity` | 7 | character | A | `flag_severity` |
| 123 | `flag_duration_extreme` | 7 | character | Full | — |
| 124 | `needs_review_flag` | 8 | logical | A | `needs_review` |  ← from `review_output$data_with_flags`
| 125 | `auto_error_desc` | 8 | character | review_output only | — |
| 126 | `caffeine_value_checkforerrors` | 8 | logical | Full | — |
| 127 | `alcohol_value_checkforerrors` | 8 | logical | Full | — |
| 128 | `nicotine_value_checkforerrors` | 8 | logical | Full | — |
| 129 | `cannabis_value_checkforerrors` | 8 | logical | Full | — |
| 130 | `caffeine_input_anomaly` | 8 | character | Full | — |
| 131 | `alcohol_input_anomaly` | 8 | character | Full | — |
| 132 | `nicotine_input_anomaly` | 8 | character | Full | — |
| 133 | `cannabis_input_anomaly` | 8 | character | Full | — |
| 134 | `sol_category` | 8 | character | review_output only | — |
| 135 | `se_category` | 8 | character | review_output only | — |
| 136 | `se_is_insane_negative` | 8 | logical | review_output only | — |
| 137 | `tst_tib_ratio_category` | 8 | character | review_output only | — |
| 138 | `human_metric_review_status` | 8 | character | Full | — |
| 139 | `human_metric_review_note` | 8 | character | Full | — |
| 140 | `record_status` | **new** | character | A | `record_status` |

---

## Dataset A: `cleaned_data_final` (37 columns + passive EMA)

| # | Column Name | Source | Type | Description |
|---|------------|--------|------|-------------|
| 1 | `pid` | RDS | numeric | Participant ID |
| 2 | `day_num` | RDS | numeric | Study day number |
| 3 | `row_id` | Step 4 | numeric | Traceability key |
| 4 | `bedtime_selfreport_ts` | `time_bed_corrected` | POSIXct | Final bedtime |
| 5 | `sleeponset_selfreport_ts` | `self_diffcalc_sleeponset` | POSIXct | Final sleep onset |
| 6 | `awakening_selfreport_ts` | `time_awake_corrected` | POSIXct | Final awakening |
| 7 | `getup_selfreport_ts` | `time_getup_corrected` | POSIXct | Final get-up |
| 8 | `tst_minutes` | Step 7 | numeric | Total Sleep Time — primary outcome |
| 9 | `sol_computed_minutes` | Step 7 | numeric | Sleep Onset Latency |
| 10 | `se_percent` | Step 7 | numeric | Sleep efficiency, true 0–100 |
| 11 | `tib_minutes` | Step 7 | numeric | Time in Bed |
| 12 | `sleepperiod_minutes` | Step 7 | numeric | Sleep period duration — also serves as TST upper bound when WASO is untrusted (see B2) |
| 13 | `trysleep_minutes` | Step 7 | numeric | Try-sleep duration (SE denominator) |
| 14 | `waso_avg_bout_selfreport_minutes` | Step 7 | numeric | Average WASO bout duration |
| 15 | `sol_selfreport_minutes` | Step 3 | numeric | Participant-estimated SOL |
| 16 | `waso_selfreport_minutes` | Step 3 | numeric | Participant-estimated WASO |
| 17 | `num_waso_bouts_selfreport` | RDS | numeric | WASO bout count |
| 18 | `nap_selfreport_totalminutes` | Step 3 | numeric | Nap duration |
| 19 | `exercise_light_minutes` | Step 3 | numeric | Light exercise |
| 20 | `exercise_moderate_minutes` | Step 3 | numeric | Moderate exercise |
| 37 | `exercise_vigorous_minutes` | Step 3 | numeric | Vigorous exercise |
| 37 | `exercise_strength_minutes` | Step 3 | numeric | Strength training |
| 37 | `has_correction` | Step 7 | character | none / algorithmic / manual / both |
| 37 | `is_error` | Step 6 | logical | Error flag |
| 37 | `error_type` | Step 6 | character | Error category text |
| 37 | `is_unusual` | Step 6 | logical | Unusual pattern flag |
| 37 | `unusual_type` | Step 6 | character | Unusual pattern text |
| 37 | `is_reasonable_unusual` | Step 6 | logical | Human reviewer override |
| 37 | `record_status` | new | character | clean / error / unusual / equal_time / not_reported |
| 37 | `flag_severity` | Step 7 | character | Clean / Minor / Major |
| 37 | `needs_review` | Step 8 | logical | Combined review flag |
| 37 | `caffeine_num` | RDS | numeric | Caffeine count |
| 37 | `alcohol_num` | RDS | numeric | Alcohol count |
| 37 | `nicotine_doses` | RDS | numeric | Nicotine doses |
| 37 | `cannabis_doses` | RDS | numeric | Cannabis doses |
| 37 | `StartDate` | CSV | character | Survey date |

---

## Dataset B: `cleaned_data_prepostcorrection` (15 columns)

| # | Column Name | Source | Type | Description |
|---|------------|--------|------|-------------|
| 1 | `pid` | RDS | numeric | Participant ID |
| 2 | `day_num` | RDS | numeric | Study day |
| 3 | `row_id` | Step 4 | numeric | Traceability key |
| 4 | `bedtime_precorrection` | Step 2 | POSIXct | Before any correction |
| 5 | `bedtime_postcorrection` | Step 4 | POSIXct | After all corrections |
| 6 | `sleeponset_precorrection` | Step 2 | POSIXct | Before any correction |
| 7 | `sleeponset_postcorrection` | Step 7 | POSIXct | After all corrections |
| 8 | `awakening_precorrection` | Step 2 | POSIXct | Before any correction |
| 9 | `awakening_postcorrection` | Step 4 | POSIXct | After all corrections |
| 10 | `getup_precorrection` | Step 2 | POSIXct | Before any correction |
| 11 | `getup_postcorrection` | Step 4 | POSIXct | After all corrections |
| 12 | `has_correction` | Step 7 | character | none / algorithmic / manual / both |
| 13 | `tst_minutes` | Step 7 | numeric | Resulting sleep duration |
| 14 | `sol_selfreport_minutes` | Step 3 | numeric | Participant's SOL estimate |
| 15 | `correction_type` | Step 4 | character | Correction mechanism (e.g. sleep_reduce_12h_loop) |

---

## Full Only (100+ columns in `cleaned_data_full`)

All columns with destination "Full" or "None" in the master table. Includes all raw strings, parse flags, correction logs, diagnostic booleans, audit columns, redundant contract columns, debug text, substance anomaly flags, and all passive EMA columns from source RDS.

### `review_output only` — 5 columns not in any delivered file

`checkforerrors_processing.R` line 342 does `data <- corrected_ema_data` and all
Step 8 flags after that point are written to the copy, never back to
`corrected_ema_data`. Five columns therefore exist only inside
`review_output$data_with_flags` and are **not** in `cleaned_data_full`:

| Column | Where to find it instead |
|---|---|
| `auto_error_desc` | `output/flagged_records_self_reported.csv` |
| `sol_category` | `output/flagged_records_self_reported.csv` |
| `se_category` | `output/flagged_records_self_reported.csv` |
| `se_is_insane_negative` | `review_output$data_with_flags` (in-session only) |
| `tst_tib_ratio_category` | `output/flagged_records_self_reported.csv` |

`needs_review_flag` is in the same situation but IS delivered, as
`needs_review` in Dataset A: `finalize_columns()` takes `review_data =
review_output$data_with_flags` and pulls it from there. The machine-readable
dictionary records this in its `source_object` field.

Columns created BEFORE line 342 (the substance anomaly flags, rows 126-133,
and `human_metric_review_status` / `_note` from Step 6.5) are written directly
onto `corrected_ema_data` and are present in `cleaned_data_full` as stated.

## Excluded (not even Full)

| Column | Reason |
|--------|--------|
| `num_waso_am` | Duplicate of `num_waso_estimate_am` |
| `time_bed_manual` | Step 6 staging |
| `time_sleep_manual` | Step 6 staging |
| `time_awake_manual` | Step 6 staging |
| `time_getup_manual` | Step 6 staging |
| `sleep_awake_diff_min` | Intermediate calculation |

## Delivery

```r
finalize_columns <- function(data) {
  # Dataset A: select + rename → cleaned_data_final.rds + .csv
  # Dataset B: select + rename → cleaned_data_prepostcorrection.rds + .csv
  # Full: everything else → cleaned_data_full.rds
}
```

Written at end of `run_pipeline()`.
