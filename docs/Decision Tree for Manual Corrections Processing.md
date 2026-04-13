# Decision Tree for Manual Corrections Processing

## 🌳 **OVERVIEW DECISION TREE**

```
START: Process Corrections
│
├───► Input Data Sources:
│     ├── ema_data (Original: *_am_hhmm_ampm, Corrected: *_corrected)
│     ├── corrections_df (manual_error_correction.csv)
│     └── manual_unusual_df (manual_unusual_review.csv) [NEW!]
│
└───► Branch A: Process manual_unusual_df FIRST (Priority 1)
      │
      └───► Branch B: Process corrections_df SECOND (Priority 2)
```

---

## 🌿 **BRANCH A: MANUAL_UNUSUAL_DF PROCESSING**
**Why here first?** These are pre-identified records requiring special handling before regular corrections.

```
START: Process manual_unusual_df
│
├───► Check problem_humanidentified column
│     │
│     ├───► Contains "manual unusual"?
│     │     │
│     │     ├───► YES → Call process_manual_unusual_correction()
│     │     │     │
│     │     │     ├───► Step A1: Check for "Undo correction" (Highest Priority)
│     │     │     │     │
│     │     │     │     ├───► IF found: 
│     │     │     │     │     ├─── Restore original values from *_am_hhmm_ampm to *_manual
│     │     │     │     │     ├─── Mark manually_corrected = TRUE
│     │     │     │     │     └─── RETURN (skip further processing)
│     │     │     │     │
│     │     │     │     └───► IF NOT found: Continue to next step
│     │     │     │
│     │     │     ├───► Step A2: Process column_to_adjust and correction_value
│     │     │     │     │
│     │     │     │     ├───► Parse column_to_adjust (split by "," or "+")
│     │     │     │     │     └─── WHY? Multiple columns can be corrected at once
│     │     │     │     │
│     │     │     │     └───► For each column:
│     │     │     │           ├─── Map to manual column (corrected → manual)
│     │     │     │           ├─── Apply time instruction (Same day/Minus/Plus/HH:MM)
│     │     │     │           └─── Update if time changed
│     │     │     │
│     │     │     └───► Step A3: Check solution_humanidentified for operations
│     │     │           │
│     │     │           ├───► Contains swap operations?
│     │     │           │     └─── Apply swap (bed-sleep/awake-getup/sleep-awake)
│     │     │           │
│     │     │           └───► Contains AM/PM conversion?
│     │     │                 └─── Apply ±12 hours based on time type
│     │     │
│     │     └───► NO → Skip to next record
│     │
│     └───► Contains "reasonable unusual record"? [KEY FEATURE]
│           │
│           ├───► YES → Mark for later exclusion
│           │     ├─── Extract pid, row_id
│           │     ├─── Store in reasonable_unusual_records list
│           │     └─── WHY? These records are VALID but look suspicious,
│           │          so they should be REMOVED from unusual_df later
│           │
│           └───► NO → Skip
│
└───► END Branch A
```

---

## 🌿 **BRANCH B: CORRECTIONS_DF PROCESSING**
**Why here second?** Regular corrections applied after manual_unusual fixes.

```
START: Process corrections_df
│
├───► For EACH row in corrections_df:
│     │
│     ├───► Step B1: Check three critical columns
│     │     ├── solution_humanidentified
│     │     ├── column_to_correct
│     │     └── correct_value
│     │     │
│     │     └───► DECISION NODE 1: All columns NA/empty?
│     │           │
│     │           ├───► YES → CASE 1: SKIP
│     │           │     └─── WHY? No correction information available
│     │           │
│     │           └───► NO → Continue to next decision
│     │
│     ├───► DECISION NODE 2: column_to_correct NOT empty AND correct_value NOT empty?
│     │     │
│     │     ├───► YES → CASE 3: PREFERRED PATH
│     │     │     │    WHY? Most specific, direct column-value mapping
│     │     │     │
│     │     │     ├───► Step C3.1: Check "Undo correction" (Highest Priority)
│     │     │     │     │
│     │     │     │     ├───► IF found in solution_humanidentified:
│     │     │     │     │     ├─── Restore: time_bed_manual ← time_bed_am_hhmm_ampm
│     │     │     │     │     ├─── Restore: time_sleep_manual ← time_sleep_am_hhmm_ampm
│     │     │     │     │     ├─── Restore: time_awake_manual ← time_awake_am_hhmm_ampm
│     │     │     │     │     ├─── Restore: time_getup_manual ← time_getup_am_hhmm_ampm
│     │     │     │     │     ├─── Mark manually_corrected = TRUE
│     │     │     │     │     └─── RETURN (skip further processing)
│     │     │     │     │
│     │     │     │     └───► IF NOT found: Continue
│     │     │     │
│     │     │     ├───► Step C3.2: Parse column_to_correct
│     │     │     │     │
│     │     │     │     ├───► Contains "," or "+"?
│     │     │     │     │     ├───► YES: Split into multiple column names
│     │     │     │     │     │     └─── WHY? Batch corrections save time
│     │     │     │     │     │
│     │     │     │     │     └───► NO: Single column
│     │     │     │     │
│     │     │     │     └───► Map to manual columns:
│     │     │     │           ├─── "time_bed_corrected" → time_bed_manual
│     │     │     │           ├─── "time_sleep_corrected" → time_sleep_manual
│     │     │     │           ├─── "time_awake_corrected" → time_awake_manual
│     │     │     │           └─── "time_getup_corrected" → time_getup_manual
│     │     │     │
│     │     │     ├───► Step C3.3: For each column, process correct_value
│     │     │     │     │
│     │     │     │     ├───► Get current time from manual column
│     │     │     │     │
│     │     │     │     ├───► DECISION NODE 3: Instruction Type Detection
│     │     │     │     │     │
│     │     │     │     │     ├───► Pattern: "^same day"
│     │     │     │     │     │     ├─── Action: Keep date, update time only
│     │     │     │     │     │     └─── WHY? Date is correct, time is wrong
│     │     │     │     │     │
│     │     │     │     │     ├───► Pattern: "minus 12 hours"
│     │     │     │     │     │     ├─── Action: Subtract 12 hours from full timestamp
│     │     │     │     │     │     └─── WHY? AM/PM error, date may cross
│     │     │     │     │     │
│     │     │     │     │     ├───► Pattern: "plus 12 hours"
│     │     │     │     │     │     ├─── Action: Add 12 hours to full timestamp
│     │     │     │     │     │     └─── WHY? AM/PM error, date may cross
│     │     │     │     │     │
│     │     │     │     │     └───► Pattern: "HH:MM:SS" or "HH:MM"
│     │     │     │     │           ├─── Action: Update time only, keep date
│     │     │     │     │           └─── WHY: Exact time correction needed
│     │     │     │     │
│     │     │     │     └───► Apply correction if time changed
│     │     │     │
│     │     │     └───► Step C3.4: Check solution_humanidentified for swaps
│     │     │           │
│     │     │           ├───► Contains "bed-sleep switch" or similar?
│     │     │           │     └─── Swap time_bed_manual ↔ time_sleep_manual
│     │     │           │
│     │     │           ├───► Contains "awake-getup switch" or similar?
│     │     │           │     └─── Swap time_awake_manual ↔ time_getup_manual
│     │     │           │
│     │     │           └───► Contains "sleep-awake switch" or similar?
│     │     │                 └─── Swap time_sleep_manual ↔ time_awake_manual
│     │     │                 └─── WHY? Values entered in wrong columns
│     │     │
│     │     └───► Mark manually_corrected = TRUE
│     │
│     ├───► DECISION NODE 4: solution_humanidentified NOT empty AND 
│     │     (column_to_correct OR correct_value is empty)?
│     │     │
│     │     ├───► YES → CASE 2: SOLUTION-BASED PATH
│     │     │     │    WHY? Natural language description of correction
│     │     │     │
│     │     │     ├───► Step C2.0: Check "Undo correction" (Highest Priority)
│     │     │     │     └─── Same restore logic as CASE 3
│     │     │     │
│     │     │     ├───► Step C2.1: AM/PM Conversion Detection
│     │     │     │     │
│     │     │     │     ├───► Scan for "am/pm conversion"
│     │     │     │     │
│     │     │     │     ├───► Extract time types (can be multiple)
│     │     │     │     │     ├─── "awake" / "getup" → ADD 12 hours
│     │     │     │     │     └─── "bed" / "sleep" → SUBTRACT 12 hours
│     │     │     │     │
│     │     │     │     └─── Apply to corresponding manual columns
│     │     │     │           └─── WHY? AM/PM misclassification is common
│     │     │     │
│     │     │     ├───► Step C2.2: Time Alignment Detection
│     │     │     │     │
│     │     │     │     ├───► Pattern: "Align X time's hour to Y time's hour"
│     │     │     │     │     └─── Example: "Align awake time's hour to getup time's hour"
│     │     │     │     │
│     │     │     │     └─── Action: Set source hour = target hour
│     │     │     │           └─── WHY? Hours should match, minutes may differ
│     │     │     │
│     │     │     ├───► Step C2.3: Time Change Detection
│     │     │     │     │
│     │     │     │     ├───► Pattern: "Change X time into HH:MM"
│     │     │     │     │     └─── Example: "Change sleep time into 02:11:00"
│     │     │     │     │
│     │     │     │     └─── Action: Set specific time, keep date
│     │     │     │           └─── WHY? Exact correction known
│     │     │     │
│     │     │     ├───► Step C2.4: Hours Operation Detection
│     │     │     │     │
│     │     │     │     ├───► "Minus 12 hours" → Subtract from ALL manual columns
│     │     │     │     ├───► "Plus 12 hours" → Add to ALL manual columns
│     │     │     │     └─── WHY? Systematic AM/PM offset for entire day
│     │     │     │
│     │     │     └───► Step C2.5: Swap Operation Detection (comprehensive)
│     │     │           │
│     │     │           ├───► Patterns include "switch" AND "swap" variants
│     │     │           └─── Execute corresponding column swaps
│     │     │
│     │     └───► Mark manually_corrected = TRUE if any operation applied
│     │
│     └───► DECISION NODE 5: All other cases
│           │
│           └───► CASE 4: UNPROCESSABLE
│                 ├─── Log warning with pid, day_num
│                 └─── WHY? Insufficient or unrecognizable instructions
│
└───► END Branch B
```

---

## 🌿 **BRANCH C: POST-PROCESSING & RECALCULATION**

```
START: Post-Processing
│
├───► Step 4: Update Corrected Columns
│     ├── time_bed_corrected ← time_bed_manual
│     ├── time_sleep_corrected ← time_sleep_manual
│     ├── time_awake_corrected ← time_awake_manual
│     └── time_getup_corrected ← time_getup_manual
│     └─── WHY? Manual columns are working copies, corrected columns are final
│
├───► Step 5: Check Swap Corrections
│     ├─── Scan corrections_df for correction_type containing "swap"
│     ├─── Verify if swap was actually executed
│     └─── Mark manually_corrected = TRUE if executed but not marked
│     └─── WHY? Ensure swap operations are properly recorded
│
├───► Step 6: Recalculate Time Differences
│     ├── bed_sleep_diff_h = sleep - bed (hours)
│     ├── sleep_awake_diff_h = awake - sleep (hours)
│     ├── awake_getup_diff_h = getup - awake (hours)
│     └── sleep_awake_diff_min = awake - sleep (minutes)
│     └─── WHY? All corrections need validation against rules
│
├───► Step 7: Mark Errors and Unusual Records
│     │
│     ├───► DECISION NODE 6: Order Correct?
│     │     ├── bed < sleep < awake < getup?
│     │     └─── NO → Mark is_error = TRUE, error_type = "order_error"
│     │
│     ├───► DECISION NODE 7: Sleep Latency Reasonable?
│     │     ├── bed_sleep_diff_h ≤ 7?
│     │     └─── NO → Mark is_error = TRUE, error_type = "bed_sleep_diff_error"
│     │
│     ├───► DECISION NODE 8: Time in Bed After Waking Reasonable?
│     │     ├── awake_getup_diff_h ≤ 7?
│     │     └─── NO → Mark is_error = TRUE, error_type = "awake_getup_diff_error"
│     │
│     ├───► DECISION NODE 9: Sleep Duration Reasonable?
│     │     ├── sleep_awake_diff_h ≤ 24?
│     │     └─── NO → Mark is_error = TRUE, error_type = "sleep_awake_24h_error"
│     │
│     ├───► DECISION NODE 10: Unusual Sleep Duration?
│     │     ├── sleep_awake_diff_h < 3 OR > 15?
│     │     └─── YES → Mark is_unusual = TRUE, unusual_type = "sleep_awake_suspicious"
│     │
│     ├───► DECISION NODE 11: Unusual Sleep Latency?
│     │     ├── bed_sleep_diff_h > 3?
│     │     └─── YES → Mark is_unusual = TRUE, unusual_type = "bed_sleep_suspicious"
│     │
│     └───► DECISION NODE 12: Unusual Wake-up Time?
│           ├── awake_getup_diff_h > 3?
│           └─── YES → Mark is_unusual = TRUE, unusual_type = "awake_getup_suspicious"
│
└───► Step 8: Update Correction Status & Save
      ├── Sync manually_corrected flag to corrections_df
      └── Save manual_error_correction_updated.csv
```

---

## 🌿 **BRANCH D: CLASSIFICATION & REASONABLE UNUSUAL EXCLUSION [KEY FEATURE]**

```
START: Create Classified DataFrames
│
├───► Step 9.1: Identify Reasonable Unusual Records from manual_unusual_df
│     │
│     ├───► DECISION NODE 13: problem_humanidentified contains "reasonable unusual record"?
│     │     │
│     │     ├───► YES:
│     │     │     ├── Extract pid, row_id
│     │     │     ├── Store in reasonable_unusual_records list
│     │     │     ├── Mark ema_data$is_reasonable_unusual = TRUE
│     │     │     ├── Set data_category = "reasonable_unusual"
│     │     │     └── Set is_unusual = FALSE
│     │     │     └─── WHY? These are VALID patterns that look like errors,
│     │     │          so they should be EXCLUDED from unusual detection
│     │     │
│     │     └───► NO: Continue
│     │
│     └───► Why here? Must identify BEFORE creating unusual_df
│
├───► Step 9.2: Create equal_time_df
│     └── Filter data_category == "equal_time_ok"
│
├───► Step 9.3: Create error_df with duration comparison
│     └── Filter data_category == "error", add duration metrics
│
├───► Step 9.4: Create unusual_df - EXCLUSION DECISION TREE
│     │
│     ├───► Base filter: data_category == "unusual"
│     │
│     ├───► DECISION NODE 14: Are there any Reasonable Unusual Records?
│     │     │
│     │     ├───► YES:
│     │     │     ├───► Create exclude_list = unique(pid, row_id)
│     │     │     │     └─── WHY? Need exact matching for deletion
│     │     │     │
│     │     │     ├───► Record BEFORE count
│     │     │     │
│     │     │     ├───► PERFORM EXCLUSION:
│     │     │     │     ├── left_join by c("pid", "row_id")
│     │     │     │     ├── filter(is.na(exclude))
│     │     │     │     └── select(-exclude)
│     │     │     │     └─── WHY? Remove rows that match BOTH pid AND row_id
│     │     │     │
│     │     │     └───► Record AFTER count, log removal statistics
│     │     │
│     │     └───► NO: Use base unusual_df without modification
│     │
│     └───► Add duration comparison fields
│
├───► Step 9.5: Create clean_df
│     └── Filter data_category == "clean"
│
├───► Step 9.6: Prepare Reasonable Unusual Records for Export
│     │
│     ├───► Filter ema_data where is_reasonable_unusual == TRUE
│     │
│     ├───► Merge with original problem/solution text
│     │   └─── WHY? Preserve human review comments
│     │
│     └───► Create reasonable_unusual_output_df with full time information
│
├───► Step 9.7: Generate Summary Statistics
│     ├── total_records, na_count, valid_records
│     ├── equal_time_count, error_count
│     ├── unusual_count (AFTER exclusion)
│     ├── reasonable_unusual_count
│     ├── clean_count, corrected_count
│     └── calculate percentages
│     └─── WHY? Monitor data quality and correction effectiveness
│
└───► Step 9.8: Save Results
      ├── Assign all dataframes to global environment
      ├── unusual_df: Clean unusual records (reasonable ones removed)
      ├── reasonable_unusual_df: Excluded records with metadata
      └── Write reasonable_unusual_records.csv
      └─── WHY? Separate storage for audit and review
```

---

## 📊 **DECISION NODE SUMMARY TABLE**

| Node   | Decision Point                                  | Why Important                                | Action if YES                 | Action if NO         |
| ------ | ----------------------------------------------- | -------------------------------------------- | ----------------------------- | -------------------- |
| **1**  | All correction columns empty?                   | No info to act on                            | SKIP (Case 1)                 | Continue             |
| **2**  | column_to_correct AND correct_value non-empty?  | Most precise correction path                 | CASE 3 processing             | Check next condition |
| **3**  | Instruction type detection                      | Different operations need different handling | Apply specific time operation | Default: no change   |
| **4**  | solution non-empty AND (column OR value empty)? | Natural language description                 | CASE 2 processing             | CASE 4               |
| **5**  | All other cases                                 | Unrecognizable format                        | Log warning                   | N/A                  |
| **6**  | Time order correct?                             | Basic logical validity                       | No error                      | Mark order_error     |
| **7**  | Sleep latency ≤ 7h?                             | Clinically reasonable                        | No error                      | Mark latency error   |
| **8**  | Wake-up time ≤ 7h?                              | Clinically reasonable                        | No error                      | Mark wake error      |
| **9**  | Sleep duration ≤ 24h?                           | Impossible to sleep >24h                     | No error                      | Mark duration error  |
| **10** | Sleep duration 3-15h?                           | Typical range                                | Mark unusual                  | Normal               |
| **11** | Sleep latency ≤ 3h?                             | Typical range                                | Mark unusual                  | Normal               |
| **12** | Wake-up time ≤ 3h?                              | Typical range                                | Mark unusual                  | Normal               |
| **13** | Contains "reasonable unusual record"?           | Valid pattern that looks like error          | Mark for exclusion            | Skip                 |
| **14** | Reasonable unusual records exist?               | Need to clean unusual_df                     | Remove matching rows          | Keep all unusual     |

---

## 🎯 **KEY DESIGN DECISIONS EXPLAINED**

### 1. **Manual Columns as Working Copy**
```
Decision: Create time_*_manual columns, modify them, then copy to corrected
Why: Prevents data loss, allows undo operations, maintains original corrected values
```

### 2. **Case 3 Preferred Over Case 2**
```
Decision: If column_to_correct AND correct_value exist, IGNORE solution_humanidentified
Why: Column/value pairs are explicit, machine-readable instructions.
     Natural language in solution_humanidentified is ambiguous and may contain errors.
```

### 3. **Undo Correction: Highest Priority**
```
Decision: Check for "Undo correction" FIRST in both Case 2 and Case 3
Why: This is a rollback operation - must happen before ANY other modifications,
     otherwise we'd be undoing after applying new changes (wrong order)
```

### 4. **Reasonable Unusual: Exclusion, Not Correction**
```
Decision: Mark as is_reasonable_unusual, remove from unusual_df, save separately
Why: These are NOT errors - they're valid patterns that happen to trigger our detection.
     Don't "fix" them, just don't report them as problems.
     Save them for review and algorithm improvement.
```

### 5. **Exact Matching on pid AND row_id**
```
Decision: Remove from unusual_df using BOTH pid AND row_id
Why: pid alone is not unique (multiple days per person)
     row_id alone might not be unique across datasets
     Both together provide absolute unique identification
```

### 6. **Full Timestamp Operations**
```
Decision: Never split date and time; always operate on complete POSIXct objects
Why: Adding/subtracting 12 hours can cross date boundaries.
     Splitting would lose date information and cause incorrect results.
```

### 7. **Batch Column Processing**
```
Decision: Support comma/plus-separated column lists in column_to_correct
Why: One correction often needs to fix multiple time points.
     Reduces manual work and ensures consistency.
```

### 8. **Duration Comparison**
```
Decision: Calculate duration_from_data_min AND duration_calculated_min, show difference
Why: Validates that our time corrections produce durations consistent with
     independently recorded sleep duration values.
```