# Round 2 _checkforerrors Manual Screening Work Log — 2026-05-28

## Objective
Second-round manual screening of all records flagged in `_checkforerrors` columns that have not yet been corrected. Output a CSV (similar to step 6 format) for row-by-row human review — decide whether each flag is a real problem requiring correction, or can be dismissed as a formatting artifact.

---

## Background

### Completed Last Session
- **Substance detection**: Switched from behavioral thresholds to input-structure anomaly detection (`detect_input_anomaly`); false positives reduced from 10 to 0.
- **Part B replacement**: Temporal detection now imports existing `error_type`/`unusual_type` columns instead of recomputing `difftime()`.
- **Classification rename**: `SERIOUS_RED_LINE→TIMESTAMP_ISSUE`, `UNUSUAL_VALUE→DURATION_ISSUE`, `BEHAVIORAL→AMOUNT_FLAG`, new `NEEDS_REVIEW`.
- **Part A3 nap/exercise structural check**: Replaces blanket 10000+ exclusion with parse-error, negative-value, and excessive-value anomaly detection.
- **2 Moderate parse_errors found**: `"0:208333333"` ≈ 12.5 min (12.5÷60), `"0:041666667"` ≈ 2.5 min (2.5÷60) — decimal hours corrupted by colon parser.

### Meeting Notes (2026-05-28)
- nap/exercise also needs input-error detection (similar to timestamp cleaning)
- Show AI the underlying `_checkforerrors` data for error-type suggestions
- `all_check <- names(data_wf)[grepl("_checkforerrors$", names(data_wf))]` to get all check columns
- Extract records from `checkforerrors_summary` underlying data that are **not yet fixed**
- Build manual-checking CSV (similar to step 6 format)

---

## `_checkforerrors` Column Overview

| Column | non-NA Count | Description |
|--------|:-----------:|-------------|
| `time_bed_am_checkforerrors` | 506 | Bedtime format/value issues |
| `time_sleep_am_checkforerrors` | 724 | Sleep-onset time format/value issues |
| `time_awake_am_checkforerrors` | 15 | Wake time format/value issues |
| `time_getup_am_checkforerrors` | 20 | Get-up time format/value issues |
| `duration_totalmin_napstoday_PM_checkforerrors` | 497 | Nap duration format issues |
| `exercisetoday_PM_totalmin_Light_checkforerrors` | 2,242 | Light exercise duration format issues |
| `exercisetoday_PM_totalmin_Moderate_checkforerrors` | 1,199 | Moderate exercise duration format issues |
| `exercisetoday_PM_totalmin_Vigorous_checkforerrors` | 611 | Vigorous exercise duration format issues |
| `exercisetoday_PM_totalmin_Strength_checkforerrors` | 642 | Strength exercise duration format issues |

**Totals**: Out of 13,990 rows, **3,392 rows** still have a `_checkforerrors` flag and `manually_corrected=FALSE`.

### Outstanding Anomaly Summary
- **parse_error (2 records)**: Moderate `"0:208333333"` / `"0:041666667"` ≈ decimal hours mis-parsed by colon parser
- **Light > 360min (7 records)**: 480min, 390min×4, 750min×2 — real long-duration exercise or data-entry errors?
- **Timestamp format issues**: ~1,265 across all time columns
- **Nap/exercise format issues**: ~5,191 (many are legitimate values flagged only by format heuristics)

---

## This Week's Task Checklist

- [ ] **Step 1**: Extract all records with any `_checkforerrors` flag + `manually_corrected=FALSE` → wide-format CSV
- [ ] **Step 2**: For each record, annotate:
  - Raw value (original input)
  - `_mincalc` value (parsed numeric)
  - `_checkforerrors` error description
  - `_correctionsmade` correction log
- [ ] **Step 3**: Human row-by-row judgment — real input problem vs format artifact?
- [ ] **Step 4**: Keep only records needing intervention, fill in correction plan
- [ ] **Step 5**: Resolve 2 Moderate parse_errors:
  - `"0:208333333"` → 12.5 min or 13 min?
  - `"0:041666667"` → 2.5 min or 3 min?
- [ ] **Step 6**: Resolve 7 Light >360min records

---

## Open Questions
1. Correction mechanism: add to `manual_error_corrections.csv` or pipeline preprocessing?
2. Should nap/exercise `_checkforerrors` be replaced with `detect_input_anomaly` like substance?
3. Round 2 CSV format: columns and structure?

---

---

## Key Clarification: Format-Level vs Content-Level — Two Completely Different Screening Tiers

**Source of confusion**: The Round 2 CSV's 6,445 records and Figure 18's ~120/731 flagged records are different things entirely.

| Tier | Source | Count | Meaning |
|------|--------|:-----:|---------|
| **Format-level `_checkforerrors`** | `process_interval.R` | **6,445** | Raw format was non-standard, parser had to guess — `"6:30"` no leading zero, `"30"` no colon |
| **Content-level classification flags** | `checkforerrors_processing.R` Part C | **~731** | Parsed value itself is unreasonable — TST>24h, SE<0%, temporal order errors |

### Core Distinction
- **`_checkforerrors=TRUE`** ≠ "data error." It only means "the raw format was non-standard, the parser made a guess" (e.g., `"6:30"` no leading zero → guessed 06:30, `"30"` no colon → guessed plain minutes).
- The 5,191 nap/exercise format issues + 1,254 AM/PM timestamp guesses = **6,445 "parser uncertainty" flags** — a first-pass screen for data-entry review.
- In contrast, Figure 18's **~731 classification flags** are the second-pass screen after parsing → content validation (TST anomalies, SE anomalies, temporal order errors).

### Workflow Implications
- Most of the 6,445 Round 2 records are false positives (non-standard format but correct value). The truly concerning subset is where both format AND value look suspicious.
- Subsequent human review should triage into: ① format OK, no change needed ② format weird but value correct (optional fix) ③ format AND value both problematic (must fix).

---

---

## Figure 18 Results (2026-05-28 Pipeline Run)

### Auto-detected flags (checkforerrors_processing.R)
**Total flagged: 815 records**

### Figure 18 Four Categories
| Category | Count |
|----------|:-----:|
| Timestamp Format Errors | 731 |
| Temporal Issues | 73 |
| Interval Format Errors | 2 |
| Other (NapEx) | 9 |

### Temporal Error Type Glossary
| Type | Meaning | Trigger |
|------|---------|---------|
| `order_error` | Temporal order violation | bed→sleep→awake→getup violates logical sequence (e.g., bed after sleep) |
| `awake_getup_diff_error` | Awake-getup diff anomaly | Negative or unreasonable awake→getup interval |
| `sleep_awake_suspicious` | Sleep duration suspicious | Unusually short or long sleep period |
| `awake_getup_suspicious` | Post-wake lounging suspicious | Unusually long time in bed after waking |
| `bed_sleep_suspicious` | SOL suspicious | Unusually long or short sleep onset latency |

### Detailed auto_error_desc Breakdown (Formatted)

```
═══════════════════════════════════════════════════════════════
                AUTO-DETECTED ERROR BREAKDOWN (815 total)
═══════════════════════════════════════════════════════════════

┌─ [Interval] — Substance input anomalies                 2
│  caffeine_value_checkforerrors                          1
│  alcohol_value_checkforerrors                           1

┌─ [NapEx] — Nap/Exercise structural anomalies             9
│  light excessive_exercise (390 min)                     4
│  light excessive_exercise (480 min)                     1
│  light excessive_exercise (750 min)                     2
│  moderate parse_error (208,333,333)                     1
│  moderate parse_error (41,666,667)                      1

┌─ [Temporal] — Pure temporal anomalies                  40
│  Error: order_error                                    24
│  Unusual: sleep_awake_suspicious                        7
│  Unusual: awake_getup_suspicious                        6
│  Unusual: bed_sleep_suspicious                          2
│  Error: awake_getup_diff_error                          1

┌─ [Timestamp] + [Temporal] mixed                        33
│  evening h<6 + order_error                              6
│  evening h<6 + awake_getup_suspicious                   1
│  evening h<6 + bed_sleep_suspicious                    11
│  evening h<6 ×2 + order_error                           3
│  evening h<6 ×2 + awake_getup_suspicious                3
│  evening h<6 ×2 + bed_sleep_suspicious                  1
│  evening h<6 ×2 + sleep_awake_suspicious                2
│  evening h<6 ×2 + morning h>3 + order_error             1
│  evening h<6 ×2 + morning h>3 + awake_getup_suspicious  1
│  evening h=12 + sleep_awake_suspicious                  1
│  morning h>3 + order_error                              1
│  evening h<6 + morning h>3 ×2 + bed_sleep_suspicious    1

┌─ [Timestamp] — Pure AM/PM guesses                     731
│  evening var h<6 marked AM (likely PM)            ×1  200
│  evening var h<6 marked AM (likely PM)            ×2  405
│  evening var h<6 + morning h>3                    ×1    3
│  evening var h<6 + morning h>3                    ×2    6
│  evening var h<6 + evening h=12                          1
│  evening var h=12 marked PM (likely AM)           ×1   77
│  evening var h=12 marked PM (likely AM)           ×2   27
│  evening h<6 + h=12 + morning h>3                 ×1    6
│  evening h<6 ×2 + h=12 ×2 + morning h>3 ×2             1
│  morning var h>3 marked PM (likely AM)            ×2    3
│  evening h<6 ×2 + morning h>3 + h=12                    1
│  evening h<6 + morning h>3 + sleep_awake_suspicious     1
───────────────────────────────────────────────────────────
```

### Raw table output

| Pattern | Count |
|---------|:-----:|
| `[Timestamp] evening var h<6 marked AM` | 200 |
| `[Timestamp] evening var h<6 marked AM` × 2 | 405 |
| `[Timestamp] evening var h=12 marked PM` | 77 |
| `[Timestamp] evening var h=12 marked PM` × 2 | 27 |
| `[Timestamp] morning var h>3 marked PM` | — 🔹 |
| `[Temporal] Error: order_error` | 24 |
| `[Temporal] Error: awake_getup_diff_error` | 1 |
| `[Temporal] Unusual: sleep_awake_suspicious` | 7 |
| `[Temporal] Unusual: awake_getup_suspicious` | 6 |
| `[Temporal] Unusual: bed_sleep_suspicious` | 2 |
| `[Temporal]` + `[Timestamp]` combos | 36 |
| `[Interval]` substance anomalies | 2 |
| `[NapEx]` structural anomalies | 9 |

🔹 Some `[Timestamp] morning` records are combined with `[Timestamp] evening` in the same row.

### [NapEx] Details (still showing OLD values — Step 6.5 not run)
| pid | day | Type | _mincalc Value |
|-----|:---:|------|:-----------:|
| 1527 | 2 | moderate parse_error | 208,333,333 ⚠️ (should be 12.5 after Step 6.5) |
| 9616 | 3 | moderate parse_error | 41,666,667 ⚠️ (should be 2.5 after Step 6.5) |
| 3299 | 8 | light excessive_exercise | 480 min |
| 6153 | 1,2,12 | light excessive_exercise | 390 min × 3 |
| 7315 | 10 | light excessive_exercise | 390 min |
| 9267 | 10,12 | light excessive_exercise | 750 min × 2 |

**Note**: The pipeline was sourced directly (skipping Steps 6.5 and 7), so the 2 Moderate records show uncorrected values. Full `run_pipeline()` will apply Step 6.5 and change them to 12.5/2.5 min.

---

## False Positive Fix: AM/PM Heuristic Flags Removed

**Problem**: `process_timestamp_emadatarelease_cyra.R` generated `_h_othererrors` messages for:
- Early-morning times (h<6) marked AM → parser warned "likely should be PM"
- Morning wake times (h>3) marked PM → parser warned "likely should be AM"

But 01:00-05:59 bed/sleep times ARE correctly AM, and 04:00-11:59 awake/getup times are also correctly AM. These heuristic rules produced massive format-level false positives.

**Changes** (2 files):

### `process_timestamp_emadatarelease_cyra.R`
- Removed L131-139: `"morning var h>3 marked PM (likely AM)"` generation
- Removed L141-149: `"evening var h<6 marked AM (likely PM)"` generation
- Updated comments: only h=12 PM→AM conversion is retained (actual correction, not false positive)
- Preserved h=24 error check (genuine data error)

### `checkforerrors_processing.R`
- Removed `uncertainty_patterns` variable (L382-386) — no longer needed
- Removed AM/PM uncertainty filtering logic (L389-391) — no messages to filter
- Updated Part A comments

### Impact
- AM/PM heuristic messages no longer written to `_checkforerrors` columns
- Round 2 CSV's 1,254 AM/PM guess entries will drop significantly
- Actual data corrections unaffected (h=12 PM→AM conversion still executes, just without the error flag)

---

## Light Exercise MM:SS Misinterpretation — 7 Records Resolved

**Key insight**: All 7 flagged Light records share the same bug — the survey's **MM:SS (minutes:seconds)** format was parsed as **HH:MM (hours:minutes)**.

| pid | day | Raw value | Misparsed as | Actual meaning | Action |
|-----|:---:|:---------:|:------------:|:---------------|:------:|
| 3299 | 8 | `08:00` | 8h = 480min | **8min** (08:00 in MM:SS) | ✅ Corrected to 8 min |
| 6153 | 1,2,12 | `6:30` | 6.5h = 390min | **6.5min** (6:30 in MM:SS) | ✅ Corrected to 6.5 min |
| 7315 | 10 | `6:30` | 6.5h = 390min | Could be 6.5min or real exercise | ❓ Pending |
| 9267 | 10,12 | `12:30` | 12.5h = 750min | **12.5min** (12:30 in MM:SS) | ✅ Corrected to 12.5 min |

**Evidence**: For each participant, the flagged day's Light value is an extreme outlier compared to their normal pattern (1-30 min on all other days). The MM:SS→minutes conversion exactly explains the discrepancy.

### `apply_nap_exercise_corrections.R` Bug Fix
- **Problem**: L72 `data$manually_corrected[idx] <- TRUE` unconditionally marked ALL CSV records as corrected, causing the 7 "pending" records to be skipped by Part A3's `[NapEx]` flagging.
- **Fix**: Changed to `data$manually_corrected[idx] <- isTRUE(r$manually_corrected)`, respecting the CSV's `manually_corrected` column.

### Final `manual_nap_exercise_corrections.csv` (9 rows)
| # | pid | day | Variable | Raw | Corrected | Status |
|:-:|:---:|:---:|----------|:----:|:---------:|:------:|
| 1 | 1527 | 2 | Moderate | `0:208333333` | 12.5 | ✅ |
| 2 | 9616 | 3 | Moderate | `0:041666667` | 2.5 | ✅ |
| 3 | 3299 | 8 | Light | `08:00` | 8.0 | ✅ |
| 4 | 6153 | 1 | Light | `6:30` | 6.5 | ✅ |
| 5 | 6153 | 2 | Light | `6:30` | 6.5 | ✅ |
| 6 | 6153 | 12 | Light | `6:30` | 6.5 | ✅ |
| 7 | 7315 | 10 | Light | `6:30` | 390 | ❓ |
| 8 | 9267 | 10 | Light | `12:30` | 12.5 | ✅ |
| 9 | 9267 | 12 | Light | `12:30` | 12.5 | ✅ |

---

### checkforerrors_summary (FLAG DISTRIBUTION REPORT)
| Category | Count |
|----------|:-----:|
| TIMESTAMP_ISSUE | 771 |
| AMOUNT_FLAG | 2 |
| CLEAN | 13,217 |
| CLEAN (Manually Fixed) | 11 |
| **TOTAL** | **13,990** |

---

## Changes Made This Session

### New files
- `manual_nap_exercise_corrections.csv` — 9 nap/exercise corrections
- `apply_nap_exercise_corrections.R` — processing function for nap/exercise manual corrections

### Modified files
- `00_MAIN_entry.R` — Added Step 6.5 between Step 6 and Step 7
- `process_timestamp_emadatarelease_cyra.R` — Removed AM/PM heuristic false positive flags
- `checkforerrors_processing.R` — Removed uncertainty_patterns filtering logic
- `apply_nap_exercise_corrections.R` — Bug fix: `manually_corrected` no longer forced to TRUE

---

## Architecture Decision: Don't modify `process_interval.R`, keep Step 6.5

**Problem**: `"08:00"`, `"6:30"`, `"12:30"` in exercise duration columns should be interpreted as MM:SS (minutes:seconds), but the parser treats all time-like values as HH:MM (hours:minutes), producing 480/390/750 min errors.

**Options considered**:
1. **Modify parser**: Add `format="interval_mmss"` branch in `process_interval()` for exercise columns
2. **Keep as-is**: Unchanged parser + Part A3 threshold detection + Step 6.5 manual corrections

**Decision: Keep as-is (don't modify parser). Rationale:**

> The core issue is semantic ambiguity, not a parsing error — whether `"6:30"` means 6.5h or 6.5min can only be decided by a human. pid=7315's `"6:30"` is still pending. If the parser forcibly interpreted all colon values as MM:SS, then `"1:30"` would become 1.5 min, wrongly converting legitimate 90-min exercise sessions. The existing 3-tier pipeline is already sound:
> 
> 1. **`process_interval.R`** — Parse uniformly as HH:MM; flag format issues in `_checkforerrors`
> 2. **Part A3** (`checkforerrors_processing.R`) — Threshold >360min flags `[NapEx]`
> 3. **Step 6.5** (`apply_nap_exercise_corrections.R`) — Human review decides and records corrections

---

### Work logs created
- `2026-05-28_work_log.md` (Chinese)
- `2026-05-28_work_log_EN.md` (English)

---

## References
- Previous work log: `2026-05-18_work_log.md`
- Pipeline architecture: `../ARCHITECTURE.md`
- Data directory: `<project-root>/`
- Round 2 screening CSV: `<project-root>/round2_checkforerrors_review.csv`
