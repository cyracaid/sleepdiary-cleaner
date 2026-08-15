# B4: blind-spot extrapolation — catalog categories vs pipeline guards

| catalog category | provenance | pipeline guard | guarded? |
|---|---|---|---|
| ampm_swap | observed,literature | step 4 flip_gap_hours (12h AM/PM flip) | ✅ |
| adjacent_swap_bed_sleep | observed,literature | step 4 bed_sleep_swap_3h (swap_threshold_hours) | ✅ |
| adjacent_swap_sleep_awake | observed,literature | step 4 sleep_awake_swap_3h + bed<=awake guard | ✅ |
| adjacent_swap_awake_getup | observed,literature | step 4 awake_getup_swap_3h (swap_threshold_hours) | ✅ |
| field_misentry_sol | observed,blind_spot | step 1.5 field_misentry_check (A4) | ✅ |
| field_misentry_waso | blind_spot | step 1.5 field_misentry_check (A4) | ✅ |
| format_no_colon | observed | interval_parse format normalization | ✅ |
| format_malformed_colon | observed | interval_parse malformed-colon handling | ✅ |
| mmss_confusion | observed | interval_parse MM:SS threshold conversion | ✅ |
| cross_participant_spike | observed | step 8.5 cross_participant_global_check | ✅ |
| implausible_duration | literature | interval_parse structural_flag + classification thresholds | ✅ |
| compound_ampm_and_swap | observed,blind_spot | step 4 flip + swap chain | ✅ |

Note: adjacent_swap_sleep_awake guard = 2026-08-13 `bed <= awake` (commit 606a0e0).
field_misentry guard = 2026-06-18 Step 1.5 (A4), residual 3.5% '01:XX' known.
Categories are ENRICHED in the benchmark (400/category) — detection coverage
is measured in validation/synthetic/results/, not re-derived here.

## Cross-reference: M1–M7 audit findings (2026-08-17)

| catalog category | guarded? | audit finding |
|---|---|---|
| adjacent_swap_bed_sleep / sleep_awake / awake_getup | ✅ | **49 real rows** have RAW order violations the pipeline left uncorrected AND unflagged (25 `clean` + 23 `equal_time_ok` + 1 `error`). The guards exist but the >3h-violation rows fall through to "clean" — candidate for closed-loop re-injection. |
| mmss_confusion | ✅ | 35 rows flagged reinterpreted-shaped (M2), all FLAG not AUTO_FIX. |
| field_misentry_sol | ✅ | 922 rows (M4) have mincalc SOL > bed→sleep window (max 225 min) — SOL value contradicts timestamp window; FLAG-only. |
| (all) | — | AUTO_FIX = 0 under golden combo M1∧M4∧M5 on real data. M5 (direction validator) blocks every swap candidate. |

**Closed-loop candidate:** add "adjacent swap with >3h gap, left clean" as a new
injector category (observed provenance) and re-run the synthetic benchmark to
measure whether the pipeline flags or silently passes it.
