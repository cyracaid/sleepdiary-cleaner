# ============================================================================
# TIME CORRECTION MAIN PROGRAM - COMPLETE TECHNICAL DOCUMENTATION
# ============================================================================
# Author: Cyra Cai Dong
# Date: 02/2026
# Description: Master function for applying manual time corrections to EMA 
#              sleep diary data, processing correction instructions, 
#              recalculating metrics, and generating classified datasets
#
# Dependencies: dplyr, lubridate, stringr, readr, tidyverse
# Note! The script should only be run after running the"calculate_sleep_time_vars"
# from file "calculate_sleep_time_R"
# ============================================================================
# ============================================================================
# TIME CORRECTION PROCESSING SYSTEM - COMPLETE DOCUMENTATION
# ============================================================================
#
# This system processes manual corrections for EMA sleep timing data with a
# focus on data integrity, auditability, and transparent decision-making.
#
# ============================================================================
# 1. COLUMN HIERARCHY & DATA FLOW
# ============================================================================
#
# ┌───────────────────────────────────────────────────────────────────────┐
# │ LAYER 1: RAW AM/PM DATA (NEVER MODIFIED)                            │
# ├───────────────────────────────────────────────────────────────────────┤
# │ time_bed_am_hhmm_ampm      <- Original bed time reported in AM/PM    │
# │ time_sleep_am_hhmm_ampm    <- Original sleep time reported in AM/PM  │
# │ time_awake_am_hhmm_ampm    <- Original awake time reported in AM/PM  │
# │ time_getup_am_hhmm_ampm    <- Original getup time reported in AM/PM  │
# │───────────────────────────────────────────────────────────────────────│
# │ PURPOSE: Immutable source of truth. NEVER modified.                  │
# │          Preserves complete audit trail from raw data.               │
# └───────────────────────────────────────────────────────────────────────┘
#                                       ↓
# ┌───────────────────────────────────────────────────────────────────────┐
# │ LAYER 2: BASELINE CORRECTED (FROM PREVIOUS PROCESSING)              │
# ├───────────────────────────────────────────────────────────────────────┤
# │ time_bed_corrected         <- Previously corrected bed time          │
# │ time_sleep_corrected       <- Previously corrected sleep time        │
# │ time_awake_corrected       <- Previously corrected awake time        │
# │ time_getup_corrected       <- Previously corrected getup time        │
# │───────────────────────────────────────────────────────────────────────│
# │ PURPOSE: Starting point for current correction pass.                 │
# │          Represents state before manual review.                      │
# └───────────────────────────────────────────────────────────────────────┘
#                                       ↓
# ┌───────────────────────────────────────────────────────────────────────┐
# │ LAYER 3: WORKING MANUAL COLUMNS (MODIFIED DURING CORRECTION)        │
# ├───────────────────────────────────────────────────────────────────────┤
# │ time_bed_manual     <- Active working column - RECEIVES CORRECTIONS │
# │ time_sleep_manual   <- Active working column - RECEIVES CORRECTIONS │
# │ time_awake_manual   <- Active working column - RECEIVES CORRECTIONS │
# │ time_getup_manual   <- Active working column - RECEIVES CORRECTIONS │
# │───────────────────────────────────────────────────────────────────────│
# │ PURPOSE: All corrections applied here. Prevents corrupting baseline. │
# │          Enables undo operations by resetting from Layer 2.          │
# └───────────────────────────────────────────────────────────────────────┘
#                                       ↓
# ┌───────────────────────────────────────────────────────────────────────┐
# │ LAYER 4: FINAL CORRECTED OUTPUT                                     │
# ├───────────────────────────────────────────────────────────────────────┤
# │ time_bed_corrected     <- UPDATED from time_bed_manual             │
# │ time_sleep_corrected   <- UPDATED from time_sleep_manual           │
# │ time_awake_corrected   <- UPDATED from time_awake_manual           │
# │ time_getup_corrected   <- UPDATED from time_getup_manual           │
# │───────────────────────────────────────────────────────────────────────│
# │ PURPOSE: Final corrected values for analysis.                        │
# │          Overwrites previous corrections with manual overrides.      │
# └───────────────────────────────────────────────────────────────────────┘
#
# ============================================================================
# 2. COLUMN NAME CONSTANTS (FIXED)
# ============================================================================
#
# These constants are used throughout the system to ensure consistency.
# DO NOT MODIFY - These match the exact column names in the data files.
#
# ----------------------------------------------------------------------------
# 2.1 Raw Data Columns (NEVER Modified)
# ----------------------------------------------------------------------------
TIME_BED_AM_COL     <- "time_bed_am_hhmm_ampm"     # Original bed time
TIME_SLEEP_AM_COL   <- "time_sleep_am_hhmm_ampm"   # Original sleep time
TIME_AWAKE_AM_COL   <- "time_awake_am_hhmm_ampm"   # Original awake time
TIME_GETUP_AM_COL   <- "time_getup_am_hhmm_ampm"   # Original getup time
#
# ----------------------------------------------------------------------------
# 2.2 Baseline Corrected Columns (From Previous Processing)
# ----------------------------------------------------------------------------
TIME_BED_CORRECTED_COL     <- "time_bed_corrected"     # Pre-correction state
TIME_SLEEP_CORRECTED_COL   <- "time_sleep_corrected"   # Pre-correction state
TIME_AWAKE_CORRECTED_COL   <- "time_awake_corrected"   # Pre-correction state
TIME_GETUP_CORRECTED_COL   <- "time_getup_corrected"   # Pre-correction state
#
# ----------------------------------------------------------------------------
# 2.3 Working Manual Columns (Modified During Correction)
# ----------------------------------------------------------------------------
TIME_BED_MANUAL_COL     <- "time_bed_manual"     # Active correction target
TIME_SLEEP_MANUAL_COL   <- "time_sleep_manual"   # Active correction target
TIME_AWAKE_MANUAL_COL   <- "time_awake_manual"   # Active correction target
TIME_GETUP_MANUAL_COL   <- "time_getup_manual"   # Active correction target
#
# ============================================================================
# 3. CORRECTION PROCESSING CASES - COMPLETE CLASSIFICATION
# ============================================================================
#
# Each correction row is classified into exactly one case based on which
# fields are populated. Classification determines processing pathway.
#
# ----------------------------------------------------------------------------
# 3.1 CASE 1: SKIP - All fields empty
# ----------------------------------------------------------------------------
# Condition:  is.na(solution) & is.na(column) & is.na(value)
# Count:      case1_count++
# Action:     Skip record, no processing
# Location:   Main correction loop
# Rationale:  Empty correction row = no action required
#
# ----------------------------------------------------------------------------
# 3.2 CASE 2: SOLUTION-BASED - solution non-empty, column OR value empty
# ----------------------------------------------------------------------------
# Condition:  !is.na(solution) & (is.na(column) | is.na(value))
# Count:      case2_count++
# Action:     Parse solution text for natural language instructions
# Location:   process_case2_correction()
# Rationale:  Only human-readable description available
#             Must interpret free-form text instructions
#
# PROCESSING SEQUENCE (Strict Priority Order):
#   1. UNDO CORRECTION (Highest)
#      Pattern: "undo correction"
#      Action: Reset ALL manual columns to original AM values
#              Return immediately - no further processing
#   
#   2. AM/PM CONVERSION
#      Pattern: "[time] time am/pm conversion"
#      Action: Awake/Getup: +12 hours (PM → AM)
#              Bed/Sleep:   -12 hours (AM → PM)
#   
#   3. TIME ALIGNMENT
#      Pattern: "align [source] time's hour to [target] time's hour"
#      Action: Copy hour component from target to source
#              Preserve date, minute, second
#   
#   4. TIME CHANGE
#      Pattern: "change [time] time into HH:MM(:SS)"
#      Action: Set specific time components
#              Preserve date
#   
#   5. HOURS OPERATIONS
#      Pattern: "minus 12 hours" / "plus 12 hours"
#      Action: Add/subtract exactly 12 hours from full timestamp
#   
#   6. SWAP OPERATIONS
#      Patterns: "switch" OR "swap" variants
#      Action: Exchange values between two time columns
#
# ----------------------------------------------------------------------------
# 3.3 CASE 3: COLUMN/VALUE-BASED [PRIORITY PATH] - column & value non-empty
# ----------------------------------------------------------------------------
# Condition:  !is.na(column) & !is.na(value)
# Count:      case3_count++
# Action:     Apply explicit column/value correction
# Location:   process_case3_correction()
# Rationale:  PRIORITY OVER CASE 2 - Explicit instructions are unambiguous
#             Column+value provides direct mapping
#             Solution text may contain additional context
#
# PROCESSING SEQUENCE (Strict Priority Order):
#   1. UNDO CORRECTION (Highest)
#      Check solution_humanidentified for "undo correction"
#      If found: Reset to AM values, RETURN IMMEDIATELY
#   
#   2. APPLY CORRECT_VALUE TO COLUMN_TO_CORRECT
#      Parse column_to_correct (supports comma/semicolon separated list)
#      For each column: apply_time_instruction_case3()
#      
#      Instruction Types:
#      ┌─────────────────────────────────────────────────────────────┐
#      │ Type 1: "Same day HH:MM:SS" or "Same day HH:MM:SS AM/PM"   │
#      │   Action: Preserve date, update hour/minute/second         │
#      │   Why:    Date defines which day, only time is wrong       │
#      │   Example: "Same day 11:30:00 PM" → 23:30:00 on same date  │
#      ├─────────────────────────────────────────────────────────────┤
#      │ Type 2: "Minus 12 hours"                                   │
#      │   Action: Subtract exactly 12 hours from full timestamp    │
#      │   Why:    Corrects AM/PM errors (PM→AM)                    │
#      │   Example: "2024-01-01 14:00:00" → "2024-01-01 02:00:00"   │
#      ├─────────────────────────────────────────────────────────────┤
#      │ Type 3: "Plus 12 hours"                                    │
#      │   Action: Add exactly 12 hours to full timestamp           │
#      │   Why:    Corrects AM/PM errors (AM→PM)                    │
#      │   Example: "2024-01-01 02:00:00" → "2024-01-01 14:00:00"   │
#      ├─────────────────────────────────────────────────────────────┤
#      │ Type 4: "HH:MM:SS" or "HH:MM"                              │
#      │   Action: Same as Type 1 - update time components only     │
#      │   Why:    Concise format, same semantic meaning            │
#      │   Example: "23:30:00" → 23:30:00 on same date              │
#      └─────────────────────────────────────────────────────────────┘
#   
#   3. CHECK SWAP OPERATIONS IN SOLUTION
#      Patterns: "switch" ONLY (not "swap")
#      Action: Exchange values between two time columns
#      Why:    Historical consistency with CASE3 swap patterns
#
# ----------------------------------------------------------------------------
# 3.4 CASE 4: UNPROCESSABLE - Other combinations
# ----------------------------------------------------------------------------
# Condition:  Any other combination (e.g., only column, only value)
# Count:      case4_count++
# Action:     Log warning, skip processing
# Rationale:  Incomplete correction instructions cannot be safely applied
#
# ============================================================================
# 4. SWAP OPERATION PATTERNS - COMPLETE REFERENCE
# ============================================================================
#
# ----------------------------------------------------------------------------
# 4.1 CASE3 SWAP PATTERNS (process_swap_operations_case3)
# ----------------------------------------------------------------------------
# Exact match only: "switch" ✓ | "swap" ✗
#
# Bed-Sleep Switch:
#   ┌─────────────────────────────────────────────────────────────┐
#   │ Patterns: "bed-sleep switch"                               │
#   │          "perform bed-sleep switch"                        │
#   │          "bed/sleep switch"                                │
#   │ Action:   time_bed_manual <-> time_sleep_manual           │
#   │ Purpose:  Correct mislabeled bed vs sleep time            │
#   └─────────────────────────────────────────────────────────────┘
#
# Awake-Getup Switch:
#   ┌─────────────────────────────────────────────────────────────┐
#   │ Patterns: "awake-getup switch"                             │
#   │          "perform awake-getup switch"                      │
#   │          "awake/getup switch"                              │
#   │ Action:   time_awake_manual <-> time_getup_manual         │
#   │ Purpose:  Correct mislabeled awake vs getup time          │
#   └─────────────────────────────────────────────────────────────┘
#
# Sleep-Awake Switch:
#   ┌─────────────────────────────────────────────────────────────┐
#   │ Patterns: "sleep-awake switch"                             │
#   │          "perform sleep-awake switch"                      │
#   │          "sleep/awake switch"                              │
#   │ Action:   time_sleep_manual <-> time_awake_manual         │
#   │ Purpose:  Correct mislabeled sleep vs awake time          │
#   └─────────────────────────────────────────────────────────────┘
#
# ----------------------------------------------------------------------------
# 4.2 CASE2 SWAP PATTERNS (process_swap_operations)
# ----------------------------------------------------------------------------
# Pattern Matching: "switch" OR "swap" (BROADER pattern set)
#
# Extended Patterns Include:
#   ┌─────────────────────────────────────────────────────────────┐
#   │ "bed-sleep swap"           "perform bed-sleep swap"        │
#   │ "awake-getup swap"         "perform awake-getup swap"      │
#   │ "sleep-awake swap"         "perform sleep-awake swap"      │
#   │ "bed/sleep swap"           "bed-sleep switch"              │
#   │ "awake/getup swap"         "awake-getup switch"            │
#   │ "sleep/awake swap"         "sleep-awake switch"            │
#   └─────────────────────────────────────────────────────────────┘
#
# Why CASE2 has more patterns:
#   - Solution text is free-form human input
#   - Must accommodate various phrasings
#   - Conservative matching (cast wider net)
#
# ============================================================================
# 5. CLASSIFICATION CRITERIA - COMPLETE DECISION TREE
# ============================================================================
#
# ----------------------------------------------------------------------------
# 5.1 ERROR_TYPE Conditions (Priority Order)
# ----------------------------------------------------------------------------
#
# Error Flag: is_error = TRUE
#
# Priority 1 - order_error:
#   Condition:  !(bed_corrected < sleep_corrected < 
#                 awake_corrected < getup_corrected)
#   Rationale:  Chronological order is fundamental
#               Cannot have sleep before bed, awake before sleep, etc.
#
# Priority 2 - bed_sleep_diff_error:
#   Condition:  abs(bed_sleep_diff_h) > 7 hours
#   Rationale:  Sleep onset latency >7 hours is impossible
#               7 hours = almost full normal sleep cycle
#
# Priority 3 - awake_getup_diff_error:
#   Condition:  abs(awake_getup_diff_h) > 7 hours
#   Rationale:  Time between waking and getting up >7 hours impossible
#
# Priority 4 - sleep_awake_24h_error:
#   Condition:  abs(sleep_awake_diff_h) > 24 hours
#   Rationale:  Sleep duration >24 hours impossible in one day
#
# Priority 5 - multiple_errors:
#   Condition:  Any combination of above errors
##里面需要加一条如果sleep和awake 时间是equal就是error
# ----------------------------------------------------------------------------
# 5.2 UNUSUAL_TYPE Conditions
# ----------------------------------------------------------------------------
#
# Unusual Flag: is_unusual = TRUE
#
# Condition 1 - sleep_awake_suspicious:
#   Condition:  sleep_awake_diff_h < 3 OR sleep_awake_diff_h > 15
#   Rationale:  <3h: Inadequate for restorative sleep
#               >15h: Unusual for daily sleep (possible but rare)
#
# Condition 2 - bed_sleep_suspicious:
#   Condition:  bed_sleep_diff_h > 3 hours
#   Rationale:  Taking >3 hours to fall asleep is clinically significant
#
# Condition 3 - awake_getup_suspicious:
#   Condition:  awake_getup_diff_h > 3 hours
#   Rationale:  Staying in bed >3 hours after waking is unusual
#
# Condition 4 - multiple_suspicious:
#   Condition:  Multiple suspicious conditions
#
# Why separate from errors?
#   - Not impossible, just statistically unusual
#   - May be clinically significant but valid
#   - Requires human review to confirm accuracy
#
# ----------------------------------------------------------------------------
# 5.3 EQUAL_TIME_TYPE Conditions
# ----------------------------------------------------------------------------
#
# Type 1 - bed_sleep_equal:
#   Condition:  bed_sleep_diff_h == 0
#   Rationale:  Fell asleep immediately upon getting in bed
#               May be accurate or reporting error
#
# Type 2 - awake_getup_equal:
#   Condition:  awake_getup_diff_h == 0
#   Rationale:  Got up immediately upon waking
#               May be accurate or reporting error
#
# Type 3 - both_equal:
#   Condition:  bed_sleep_equal AND awake_getup_equal
#
# Why treat as separate category?
#   - Mathematically perfect zero differences
#   - Not errors, but also not typical
#   - Automatically acceptable without review
#
# ============================================================================
# 6. REASONABLE UNUSUAL RECORD HANDLING - CRITICAL WORKFLOW
# ============================================================================
#
# This is the most important override mechanism in the system.
# Human reviewers identify certain statistically unusual records as actually
# valid and clinically meaningful. These records must be:
#   1. Identified from manual_unusual_review.csv
#   2. Marked in the main dataset
#   3. EXCLUDED from unusual_df
#   4. Saved to separate output for documentation
#
# ----------------------------------------------------------------------------
# 6.1 Step 1: Identification 
# ----------------------------------------------------------------------------
# Location:  create_classified_dataframes(), lines ~1520
#
# Filter Logic:
#   reasonable_unusual_records <- manual_unusual_df %>%
#     filter(!is.na(problem_humanidentified)) %>%
#     filter(str_detect(tolower(problem_humanidentified), 
#                       "reasonable unusual record"))
#
# Why case-insensitive matching?
#   - Human reviewers may use various capitalizations
#   - "Reasonable Unusual Record", "reasonable unusual", "REASONABLE"
#
# ----------------------------------------------------------------------------
# 6.2 Step 2: Marking in ema_data
# ----------------------------------------------------------------------------
# Location:  create_classified_dataframes(), lines ~1538
#
# Marking Actions (ALL applied):
#   1. is_reasonable_unusual <- TRUE
#      Purpose: Flag for identification in outputs
#   
#   2. data_category <- "reasonable_unusual"
#      Purpose: Override statistical classification
#   
#   3. is_unusual <- FALSE
#      Purpose: CRITICAL - Prevents filtering as unusual
#
# Why override is_unusual?
#   - Without this, record would be filtered out with unusual_df
#   - Human review determined these records are valid
#   - Must be included in main analysis
#
# ----------------------------------------------------------------------------
# 6.3 Step 3: Unusual_df EXCLUSION Logic
# ----------------------------------------------------------------------------
# Location:  create_classified_dataframes(), lines ~1610
#
# Exclusion Process:
#
#   BEFORE:
#   unusual_df_base <- data %>% filter(data_category == "unusual")
#   # Contains ALL records flagged as unusual by algorithm
#
#   EXCLUSION JOIN:
#   exclude_records <- reasonable_unusual_records %>%
#     select(pid, row_id) %>%
#     distinct() %>%
#     mutate(exclude = TRUE)
#   
#   unusual_df_base %>%
#     left_join(exclude_records, by = c("pid", "row_id")) %>%
#     filter(is.na(exclude)) %>%
#     select(-exclude)
#
#   AFTER:
#   unusual_df <- [records NOT in reasonable_unusual_records]
#
# Why join on pid + row_id (NOT day_num)?
#   - row_id is the unique identifier for each record
#   - pid alone insufficient (multiple days per person)
#   - Prevents accidentally removing wrong day's data
#
# Count Tracking:
#   before_count <- nrow(unusual_df_base)
#   after_count  <- nrow(unusual_df)
#   removed_count <- before_count - after_count
#   
#   cat(sprintf("Removed %d Reasonable unusual records\n", removed_count))
#
# Why log removal count?
#   - Transparency in processing
#   - Verify correct number excluded
#   - Audit trail for data quality
#
# ----------------------------------------------------------------------------
# 6.4 Step 4: Output Generation
# ----------------------------------------------------------------------------
# Location:  create_classified_dataframes(), lines ~1680
#
# Output Columns (Complete Audit Trail):
#
#   ┌────────────────────┬────────────────────────────────────────────┐
#   │ Column             │ Purpose                                    │
#   ├────────────────────┼────────────────────────────────────────────┤
#   │ pid                │ Participant identifier                     │
#   │ day_num            │ Study day number                          │
#   │ row_id             │ Unique record identifier                  │
#   ├────────────────────┼────────────────────────────────────────────┤
#   │ time_bed_am_hhmm_ampm    │ ORIGINAL reported time (audit)      │
#   │ time_sleep_am_hhmm_ampm  │ ORIGINAL reported time (audit)      │
#   │ time_awake_am_hhmm_ampm  │ ORIGINAL reported time (audit)      │
#   │ time_getup_am_hhmm_ampm  │ ORIGINAL reported time (audit)      │
#   ├────────────────────┼────────────────────────────────────────────┤
#   │ time_bed_corrected │ FINAL corrected time                      │
#   │ time_sleep_corrected│ FINAL corrected time                     │
#   │ time_awake_corrected│ FINAL corrected time                     │
#   │ time_getup_corrected│ FINAL corrected time                     │
#   ├────────────────────┼────────────────────────────────────────────┤
#   │ bed_sleep_diff_h   │ Calculated sleep latency                 │
#   │ sleep_awake_diff_h │ Calculated sleep duration                │
#   │ awake_getup_diff_h │ Calculated time-in-bed-after-waking      │
#   ├────────────────────┼────────────────────────────────────────────┤
#   │ manually_corrected │ Whether any corrections were applied      │
#   ├────────────────────┼────────────────────────────────────────────┤
#   │ problem_humanidentified│ Original reviewer flag text           │
#   │ solution_humanidentified│ Original reviewer solution text      │
#   └────────────────────┴────────────────────────────────────────────┘
#
# File Output:
#   write_csv(reasonable_unusual_df, "reasonable_unusual_records.csv")
#
# ============================================================================
# 7. COMPLETE PROCESSING PIPELINE - apply_manual_corrections_and_recalculate() SEQUENTIAL STEPS
# ============================================================================
#
# ----------------------------------------------------------------------------
# STEP 1: INITIALIZATION
# ----------------------------------------------------------------------------
#
# Actions:
#   1. Verify required columns exist (pid, day_num, row_id)
#   2. Create manual columns if not exist
#      time_x_manual <- time_x_corrected
#   3. Initialize manually_corrected flag = FALSE
#   4. Create sleep_awake_diff_min column for duration comparison
#
# Rationale:
#   - Ensure all required columns present before processing
#   - Manual columns are the ONLY columns modified
#   - Track which records received corrections
#
# ----------------------------------------------------------------------------
# STEP 2: PROCESS MANUAL UNUSUAL RECORDS
# ----------------------------------------------------------------------------
#
# Actions:
#   1. Filter manual_unusual_df for "manual unusual" records
#   2. For each record: process_manual_unusual_correction()
#      a. Apply column/value corrections
#      b. Apply swap operations from solution text
#      c. Mark manually_corrected = TRUE
#
# Why process manual unusual first?
#   - These are pre-identified special cases
#   - May override regular corrections
#   - Highest priority after undo operations
#
# ----------------------------------------------------------------------------
# STEP 3: PROCESS REGULAR CORRECTIONS
# ----------------------------------------------------------------------------
#
# For each row in corrections_df:
#
#   ┌─────────────────────────────────────────────────────────────┐
#   │ Classify → Process → Count → Next                          │
#   └─────────────────────────────────────────────────────────────┘
#
#   CASE1: if all fields empty → skip, case1_count++
#   CASE3: if !is.na(column) & !is.na(value) → process_case3, case3_count++
#   CASE2: if !is.na(solution) & (column|value empty) → process_case2, case2_count++
#   CASE4: else → log warning, case4_count++
#
# ----------------------------------------------------------------------------
# STEP 4: UPDATE CORRECTED COLUMNS
# ----------------------------------------------------------------------------
#
# Action:
#   time_x_corrected <- time_x_manual
#
# Rationale:
#   - Propagate working manual changes to official corrected columns
#   - Overwrites previous corrections with manual overrides
#
# ----------------------------------------------------------------------------
# STEP 5: CHECK SWAP OPERATIONS
# ----------------------------------------------------------------------------
# Function: apply_manual_corrections_and_recalculate()
#           check_swap_corrections()
#
# Action:
#   1. Identify all corrections with "swap" in correction_type
#   2. For each swap: mark manually_corrected = TRUE
#
# Why separate check?
#   - Swap operations may not have column/value pairs
#   - Ensures swap-corrected records are properly flagged
#
# ----------------------------------------------------------------------------
# STEP 6: RECALCULATE TIME DIFFERENCES AND MARK
# ----------------------------------------------------------------------------
# Function: recalculate_and_mark_errors() 
#
# Recalculate:
#   bed_sleep_diff_h
#   sleep_awake_diff_h
#   awake_getup_diff_h
#   sleep_awake_diff_min
#
# Mark:
#   has_na
#   bed_sleep_equal, awake_getup_equal
#   is_error, error_type
#   is_unusual, unusual_type
#   data_category
#   equal_time_type
#
# ----------------------------------------------------------------------------
# STEP 7: UPDATE CORRECTION STATUS
# ----------------------------------------------------------------------------
#
# Actions:
#   1. Find all records with manually_corrected = TRUE
#   2. Update corrections_df with manually_corrected flag
#   3. Save to manual_error_correction_updated.csv
#
# Rationale:
#   - Maintain bidirectional link between data and corrections
#   - Provide audit trail of which corrections were applied
#
# ----------------------------------------------------------------------------
# STEP 8: GENERATE STATISTICS
# ----------------------------------------------------------------------------
#
# Output:
#   Case counts (1-4)
#   Total records
#   Manually corrected count and percentage
#
# ----------------------------------------------------------------------------
# STEP 9: CREATE CLASSIFIED DATAFRAMES
# ----------------------------------------------------------------------------
# Function: create_classified_dataframes()
#
# Output Dataframes:
#   1. equal_time_df     - Equal time records (automatically accepted)
#   2. error_df          - Error records (with duration comparison)
#   3. unusual_df        - Unusual records (reasonable unusual EXCLUDED)
#   4. clean_df          - Clean records (passes all checks)
#   5. reasonable_unusual_df - Reasonable unusual records (if any)
#   6. correction_summary    - Complete statistics
#
# ============================================================================
# 8. DURATION COMPARISON SYSTEM
# ============================================================================
#
# Purpose: Validate corrected sleep times against reported total sleep duration
#
# ----------------------------------------------------------------------------
# 8.1 Duration Column Detection
# ----------------------------------------------------------------------------
# Function: find_duration_columns()
#
# Search Order:
#   1. Predefined common column names:
#      - "duration", "Duration", "DURATION"
#      - "sleep_duration", "sleep_duration_corrected"
#      - "time_in_bed", "time_in_bed_corrected"
#      - "duration_totalmin_sol_estimate_am"
#      - "total_sleep_duration_minutes"
#      - "sleep_duration_minutes"
#   2. Any column name containing "duration" (case-insensitive)
#   3. Return NULL if none found
#
# ----------------------------------------------------------------------------
# 8.2 Duration Metrics Added
# ----------------------------------------------------------------------------
#
# duration_from_data_min     <- Reported duration from data (minutes)
# duration_calculated_min    <- sleep_awake_diff_min (minutes)
# duration_difference_min    <- calculated - reported (minutes)
# duration_difference_h      <- difference / 60 (hours)
# duration_match             <- abs(difference) < 6 minutes
#
# Why 6 minute threshold?
#   - Typical sleep diary reporting precision
#   - Allows for rounding differences
#   - 0.1 hour = 6 minutes
#
# ============================================================================
# 9. ERROR HANDLING AND SAFETY CHECKS
# ============================================================================
#
# ----------------------------------------------------------------------------
# 9.1 Safe Numeric Conversion
# ----------------------------------------------------------------------------
# Function: safe_numeric() 
# Purpose: Prevent warnings from invalid numeric conversion
# Action:  suppressWarnings(as.numeric(x))
# Returns: NA for non-numeric input, numeric value otherwise
#
# ----------------------------------------------------------------------------
# 9.2 Column Existence Verification
# ----------------------------------------------------------------------------
# Location: Throughout system
#
# Pattern:
#   if (col %in% names(data)) { ... }
#
# Why check before access?
#   - Data structures may vary between environments
#   - Prevents cryptic "column not found" errors
#   - Graceful degradation
#
# ----------------------------------------------------------------------------
# 9.3 Missing Column Creation
# ----------------------------------------------------------------------------
# Function: ensure_marking_columns
#
# Purpose: Ensure all classification columns exist before assignment
# Action:  Create column with NA if not present
#
# Columns checked:
#   has_na, bed_sleep_equal, awake_getup_equal
#   is_error, is_unusual, data_category
#   error_type, unusual_type, equal_time_type
#
# ============================================================================
# 10. KEY DESIGN PRINCIPLES - SUMMARY
# ============================================================================
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │ PRINCIPLE 1: IMMUTABLE SOURCE DATA                                     │
# │ Implementation: Never modify *_am_hhmm_ampm columns                    │
# │ Rationale: Audit trail, reproducibility, ability to "undo"            │
# └─────────────────────────────────────────────────────────────────────────┘
#                                      ↓
# ┌─────────────────────────────────────────────────────────────────────────┐
# │ PRINCIPLE 2: EXPLICIT > IMPLICIT                                       │
# │ Implementation: CASE3 prioritized over CASE2                           │
# │ Rationale: Column+value instructions are unambiguous                  │
# └─────────────────────────────────────────────────────────────────────────┘
#                                      ↓
# ┌─────────────────────────────────────────────────────────────────────────┐
# │ PRINCIPLE 3: OPERATION ORDER MATTERS                                   │
# │ Implementation: Undo → Apply → Swap                                    │
# │ Rationale: Undo resets state, apply modifies, swap rearranges         │
# └─────────────────────────────────────────────────────────────────────────┘
#                                      ↓
# ┌─────────────────────────────────────────────────────────────────────────┐
# │ PRINCIPLE 4: HUMAN REVIEW OVERRIDES ALGORITHM                          │
# │ Implementation: Reasonable unusual marking overrides is_unusual        │
# │ Rationale: Domain knowledge beats pure statistical rules              │
# └─────────────────────────────────────────────────────────────────────────┘
#                                      ↓
# ┌─────────────────────────────────────────────────────────────────────────┐
# │ PRINCIPLE 5: TRANSPARENT EXCLUSION                                     │
# │ Implementation: Log counts before/after, save excluded records         │
# │ Rationale: No hidden data removal, fully documented                   │
# └─────────────────────────────────────────────────────────────────────────┘
#                                      ↓
# ┌─────────────────────────────────────────────────────────────────────────┐
# │ PRINCIPLE 6: PRESERVE CONTEXT                                          │
# │ Implementation: Keep original AM times and correction notes in outputs │
# │ Rationale: Full traceability from raw to final                        │
# └─────────────────────────────────────────────────────────────────────────┘
#
# ============================================================================
# END OF DOCUMENTATION
# ============================================================================

# time_correction_main_program.R
library(dplyr)
library(lubridate)
library(stringr)
library(readr)
library(tidyverse)

# ============================================
# CASE3 Helper Functions - Time Instruction Processing
# ============================================

# Apply time correction instructions for CASE3
apply_time_instruction_case3 <- function(current_time, instruction) {
  
  if (is.na(current_time) || is.na(instruction) || instruction == "") {
    return(current_time)
  }
  
  if (is.character(current_time)) {
    current_time <- ymd_hms(current_time, quiet = TRUE)
  }
  
  instruction_lower <- tolower(instruction)
  
  # Type 1: "Same day HH:MM:SS" or "Same day HH:MM:SS AM/PM"
  if (str_detect(instruction_lower, "^same day")) {
    return(handle_same_day_instruction(current_time, instruction))
  }
  
  # Type 2: "Minus 12 hours"
  if (str_detect(instruction_lower, "minus 12 hours")) {
    return(current_time - hours(12))
  }
  
  # Type 3: "Plus 12 hours"
  if (str_detect(instruction_lower, "plus 12 hours")) {
    return(current_time + hours(12))
  }
  
  # Type 4: "HH:MM:SS" or "HH:MM"
  if (str_detect(instruction, "^\\d{1,2}:\\d{2}(:\\d{2})?$")) {
    return(handle_time_only_instruction(current_time, instruction))
  }
  
  return(current_time)
}

# Handle 'Same day' instruction
handle_same_day_instruction <- function(current_time, instruction) {
  
  time_str <- str_replace(tolower(instruction), "^same day\\s*", "")
  time_str <- str_trim(time_str)
  
  parsed_time <- parse_date_time(time_str, 
                                 orders = c("H:M:S p", "H:M p", "H p", "H:M:S", "H:M"),
                                 quiet = TRUE)
  
  if (!is.na(parsed_time)) {
    return(update(current_time,
                  hour = hour(parsed_time),
                  minute = minute(parsed_time),
                  second = second(parsed_time)))
  }
  
  time_parts <- str_extract_all(time_str, "\\d+")[[1]]
  if (length(time_parts) >= 2) {
    hour_val <- as.numeric(time_parts[1])
    minute_val <- as.numeric(time_parts[2])
    second_val <- ifelse(length(time_parts) >= 3, as.numeric(time_parts[3]), 0)
    
    return(update(current_time,
                  hour = hour_val,
                  minute = minute_val,
                  second = second_val))
  }
  
  return(current_time)
}

# Handle time-only instruction
handle_time_only_instruction <- function(current_time, instruction) {
  
  time_parts <- str_split(instruction, ":")[[1]]
  hour_val <- as.numeric(time_parts[1])
  minute_val <- as.numeric(time_parts[2])
  second_val <- ifelse(length(time_parts) >= 3, as.numeric(time_parts[3]), 0)
  
  return(update(current_time,
                hour = hour_val,
                minute = minute_val,
                second = second_val))
}

# ============================================
# CASE2 Helper Functions - Operation Processors
# ============================================

# Process AM/PM conversion operations
process_ampm_conversion <- function(data, row_idx, solution_text) {
  
  operations_applied <- FALSE
  solution_lower <- tolower(solution_text)
  
  if (str_detect(solution_lower, "am/pm conversion")) {
    
    conversions <- str_extract_all(solution_lower, 
                                   "(awake|bed|getup|sleep)\\s+time\\s+am/pm\\s+conversion")[[1]]
    
    for (conv in conversions) {
      time_type <- case_when(
        str_detect(conv, "awake") ~ "awake",
        str_detect(conv, "bed") ~ "bed",
        str_detect(conv, "getup") ~ "getup",
        str_detect(conv, "sleep") ~ "sleep",
        TRUE ~ NA_character_
      )
      
      if (is.na(time_type)) next
      
      col_name <- paste0("time_", time_type, "_manual")
      
      if (col_name %in% names(data)) {
        current_time <- data[[col_name]][row_idx]
        if (!is.na(current_time)) {
          corrected_time <- if (time_type %in% c("getup", "awake")) {
            current_time + hours(12)
          } else {
            current_time - hours(12)
          }
          
          data[[col_name]][row_idx] <- corrected_time
          operations_applied <- TRUE
          cat(sprintf("    AM/PM conversion: %s\n", time_type))
        }
      }
    }
  }
  
  return(list(data = data, applied = operations_applied))
}

# Process time alignment operations
process_align_operations <- function(data, row_idx, solution_text) {
  
  solution_lower <- tolower(solution_text)
  operations_applied <- FALSE
  
  align_pattern <- "align\\s+(\\w+)\\s+time['\\s]s hour to\\s+(\\w+)\\s+time['\\s]s hour"
  align_match <- str_match(solution_lower, align_pattern)
  
  if (!is.na(align_match[1,1])) {
    source_time <- align_match[1,2]
    target_time <- align_match[1,3]
    
    source_col <- switch(source_time,
                         "awake" = "time_awake_manual",
                         "bed" = "time_bed_manual",
                         "getup" = "time_getup_manual",
                         "sleep" = "time_sleep_manual",
                         NA)
    
    target_col <- switch(target_time,
                         "awake" = "time_awake_manual",
                         "bed" = "time_bed_manual",
                         "getup" = "time_getup_manual",
                         "sleep" = "time_sleep_manual",
                         NA)
    
    if (!is.na(source_col) && !is.na(target_col) &&
        source_col %in% names(data) && target_col %in% names(data)) {
      
      source_time_val <- data[[source_col]][row_idx]
      target_time_val <- data[[target_col]][row_idx]
      
      if (!is.na(source_time_val) && !is.na(target_time_val)) {
        data[[source_col]][row_idx] <- update(source_time_val, hour = hour(target_time_val))
        operations_applied <- TRUE
        cat(sprintf("    Time alignment: %s hour aligned to %s\n", source_time, target_time))
      }
    }
  }
  
  return(list(data = data, applied = operations_applied))
}

# Process time change operations
process_change_operations <- function(data, row_idx, solution_text) {
  
  solution_lower <- tolower(solution_text)
  operations_applied <- FALSE
  
  change_pattern <- "change\\s+(\\w+)\\s+time into\\s+(\\d{1,2}:\\d{2}(:\\d{2})?)"
  change_match <- str_match(solution_lower, change_pattern)
  
  if (!is.na(change_match[1,1])) {
    time_type <- change_match[1,2]
    new_time_str <- change_match[1,3]
    
    target_col <- switch(time_type,
                         "awake" = "time_awake_manual",
                         "bed" = "time_bed_manual",
                         "getup" = "time_getup_manual",
                         "sleep" = "time_sleep_manual",
                         NA)
    
    if (!is.na(target_col) && target_col %in% names(data)) {
      current_time <- data[[target_col]][row_idx]
      if (!is.na(current_time)) {
        time_parts <- str_split(new_time_str, ":")[[1]]
        hour_val <- as.numeric(time_parts[1])
        minute_val <- as.numeric(time_parts[2])
        second_val <- ifelse(length(time_parts) >= 3, as.numeric(time_parts[3]), 0)
        
        data[[target_col]][row_idx] <- update(current_time,
                                              hour = hour_val,
                                              minute = minute_val,
                                              second = second_val)
        operations_applied <- TRUE
        cat(sprintf("    Time change: %s set to %s\n", time_type, new_time_str))
      }
    }
  }
  
  return(list(data = data, applied = operations_applied))
}

# Process add/subtract hours operations
process_hours_operations <- function(data, row_idx, solution_text) {
  
  solution_lower <- tolower(solution_text)
  operations_applied <- FALSE
  
  time_cols <- c("time_bed_manual", "time_sleep_manual", 
                 "time_awake_manual", "time_getup_manual")
  
  if (str_detect(solution_lower, "minus 12 hours")) {
    for (col in time_cols) {
      if (col %in% names(data)) {
        current_time <- data[[col]][row_idx]
        if (!is.na(current_time)) {
          data[[col]][row_idx] <- current_time - hours(12)
        }
      }
    }
    operations_applied <- TRUE
    cat("    Minus 12 hours operation\n")
  }
  
  if (str_detect(solution_lower, "plus 12 hours")) {
    for (col in time_cols) {
      if (col %in% names(data)) {
        current_time <- data[[col]][row_idx]
        if (!is.na(current_time)) {
          data[[col]][row_idx] <- current_time + hours(12)
        }
      }
    }
    operations_applied <- TRUE
    cat("    Plus 12 hours operation\n")
  }
  
  return(list(data = data, applied = operations_applied))
}

# Process swap operations for CASE3
process_swap_operations_case3 <- function(data, row_idx, solution_text) {
  
  operations_applied <- FALSE
  solution_lower <- tolower(solution_text)
  
  swap_patterns <- list(
    "bed_sleep" = c("bed-sleep switch", "perform bed-sleep switch", "bed/sleep switch"),
    "awake_getup" = c("awake-getup switch", "perform awake-getup switch", "awake/getup switch"),
    "sleep_awake" = c("sleep-awake switch", "perform sleep-awake switch", "sleep/awake switch")
  )
  
  for (swap_type in names(swap_patterns)) {
    patterns <- swap_patterns[[swap_type]]
    pattern_found <- any(sapply(patterns, function(p) str_detect(solution_lower, p)))
    
    if (pattern_found) {
      cols <- switch(swap_type,
                     "bed_sleep" = c("time_bed_manual", "time_sleep_manual"),
                     "awake_getup" = c("time_awake_manual", "time_getup_manual"),
                     "sleep_awake" = c("time_sleep_manual", "time_awake_manual"))
      
      col1 <- cols[1]; col2 <- cols[2]
      
      if (col1 %in% names(data) && col2 %in% names(data)) {
        temp <- data[[col1]][row_idx]
        data[[col1]][row_idx] <- data[[col2]][row_idx]
        data[[col2]][row_idx] <- temp
        operations_applied <- TRUE
        cat(sprintf("    Swap operation: %s <-> %s\n", col1, col2))
      }
    }
  }
  
  return(list(data = data, applied = operations_applied))
}

# Process swap operations for CASE2
process_swap_operations <- function(data, row_idx, solution_text) {
  
  operations_applied <- FALSE
  solution_lower <- tolower(solution_text)
  
  swap_patterns <- list(
    "bed_sleep" = c("bed-sleep switch", "perform bed-sleep switch", "bed/sleep switch", 
                    "bed-sleep swap", "perform bed-sleep swap"),
    "awake_getup" = c("awake-getup switch", "perform awake-getup switch", "awake/getup switch",
                      "awake-getup swap", "perform awake-getup swap"),
    "sleep_awake" = c("sleep-awake switch", "perform sleep-awake switch", "sleep/awake switch",
                      "sleep-awake swap", "perform sleep-awake swap")
  )
  
  for (swap_type in names(swap_patterns)) {
    patterns <- swap_patterns[[swap_type]]
    pattern_found <- any(sapply(patterns, function(p) str_detect(solution_lower, p)))
    
    if (pattern_found) {
      cols <- switch(swap_type,
                     "bed_sleep" = c("time_bed_manual", "time_sleep_manual"),
                     "awake_getup" = c("time_awake_manual", "time_getup_manual"),
                     "sleep_awake" = c("time_sleep_manual", "time_awake_manual"))
      
      col1 <- cols[1]; col2 <- cols[2]
      
      if (col1 %in% names(data) && col2 %in% names(data)) {
        temp <- data[[col1]][row_idx]
        data[[col1]][row_idx] <- data[[col2]][row_idx]
        data[[col2]][row_idx] <- temp
        operations_applied <- TRUE
        cat(sprintf("    Swap operation: %s <-> %s\n", col1, col2))
      }
    }
  }
  
  return(list(data = data, applied = operations_applied))
}

# ============================================
# Utility Functions
# ============================================

# Check and mark swap corrections
check_swap_corrections <- function(data, corrections_df) {
  
  cat("  Checking swap operation handling...\n")
  
  swap_corrections <- corrections_df %>%
    filter(str_detect(tolower(correction_type), "swap"))
  
  for (i in 1:nrow(swap_corrections)) {
    corr <- swap_corrections[i, ]
    target_idx <- which(data$pid == corr$pid & data$day_num == corr$day_num)
    
    if (length(target_idx) > 0) {
      row_idx <- target_idx[1]
      if (!is.na(data$manually_corrected[row_idx]) && !data$manually_corrected[row_idx]) {
        data$manually_corrected[row_idx] <- TRUE
        cat(sprintf("    Marked swap as corrected: pid=%s, day=%d\n", corr$pid, corr$day_num))
      }
    }
  }
  
  return(data)
}

# Ensure all marking columns exist
ensure_marking_columns <- function(data) {
  
  required_mark_cols <- c("has_na", "bed_sleep_equal", "awake_getup_equal",
                          "is_error", "is_unusual", "data_category", 
                          "error_type", "unusual_type", "equal_time_type")
  
  for (col in required_mark_cols) {
    if (!col %in% names(data)) {
      data[[col]] <- NA
    }
  }
  
  return(data)
}

# Find duration column
find_duration_columns <- function(data) {
  
  duration_cols <- names(data)[grepl("duration", names(data), ignore.case = TRUE)]
  
  possible_duration_cols <- c(
    "duration", "Duration", "DURATION",
    "sleep_duration", "sleep_duration_corrected",
    "time_in_bed", "time_in_bed_corrected",
    "duration_totalmin_sol_estimate_am",
    "total_sleep_duration_minutes",
    "sleep_duration_minutes"
  )
  
  for (col in possible_duration_cols) {
    if (col %in% names(data)) return(col)
  }
  
  if (length(duration_cols) > 0) return(duration_cols[1])
  
  return(NULL)
}

# Safe numeric conversion
safe_numeric <- function(x) {
  suppressWarnings(as.numeric(x))
}

# Parse column string
parse_columns <- function(column_string) {
  if (is.na(column_string) || column_string == "") {
    return(character(0))
  }
  
  cleaned <- str_replace_all(column_string, "\\s+", " ")
  columns <- str_split(cleaned, "[,+\\s]")[[1]]
  columns <- columns[columns != ""] %>% str_trim()
  
  return(columns)
}

# ============================================
# Correction Processing Functions
# ============================================

# Process manual unusual corrections
process_manual_unusual_correction <- function(data, correction,
                                              bed_am_col, sleep_am_col,
                                              awake_am_col, getup_am_col) {
  
  pid <- correction$pid
  day_num <- correction$day_num
  column_to_adjust <- correction$column_to_adjust
  correction_value <- correction$correction_value
  column_to_adjust_2 <- correction$column_to_adjust_2   
  correction_value_2 <- correction$correction_value_2  
  solution_text <- correction$solution_humanidentified
  
  target_idx <- which(data$pid == pid & data$day_num == day_num)
  if (length(target_idx) == 0) {
    cat(sprintf("  Warning: Cannot find EMA record pid=%s, day=%d\n", pid, day_num))
    return(data)
  }
  
  row_idx <- target_idx[1]
  operations_applied <- FALSE
  
  # Step 1: Handle Undo correction (highest priority)
  if (!is.na(solution_text) && str_detect(tolower(solution_text), "undo correction")) {
    data$time_bed_manual[row_idx] <- data[[bed_am_col]][row_idx]
    data$time_sleep_manual[row_idx] <- data[[sleep_am_col]][row_idx]
    data$time_awake_manual[row_idx] <- data[[awake_am_col]][row_idx]
    data$time_getup_manual[row_idx] <- data[[getup_am_col]][row_idx]
    
    operations_applied <- TRUE
    cat(sprintf("  ✓ Undo correction: pid=%s, day=%d\n", pid, day_num))
    
    if (operations_applied) data$manually_corrected[row_idx] <- TRUE
    return(data)
  }
  
  # Step 2: Process column_to_adjust and correction_value
  if (!is.na(column_to_adjust) && column_to_adjust != "" &&
      !is.na(correction_value) && correction_value != "") {
    
    columns <- parse_columns(column_to_adjust)
    
    for (col in columns) {
      target_col <- switch(col,
                           "time_bed_corrected" = "time_bed_manual",
                           "time_sleep_corrected" = "time_sleep_manual",
                           "time_awake_corrected" = "time_awake_manual",
                           "time_getup_corrected" = "time_getup_manual",
                           NA)
      
      if (is.na(target_col) || !target_col %in% names(data)) next
      
      current_time <- data[[target_col]][row_idx]
      if (is.na(current_time)) next
      
      corrected_time <- apply_time_instruction_case3(current_time, correction_value)
      
      if (!identical(current_time, corrected_time)) {
        data[[target_col]][row_idx] <- corrected_time
        operations_applied <- TRUE
      }
      
    }
  }
  
  # Step 2b: Process second adjustment (column_to_adjust_2 + correction_value_2)
  if (!is.na(column_to_adjust_2) && column_to_adjust_2 != "" &&
      !is.na(correction_value_2) && correction_value_2 != "") {
    
    columns2 <- parse_columns(column_to_adjust_2)
    
    for (col in columns2) {
      target_col <- switch(col,
                           "time_bed_corrected" = "time_bed_manual",
                           "time_sleep_corrected" = "time_sleep_manual",
                           "time_awake_corrected" = "time_awake_manual",
                           "time_getup_corrected" = "time_getup_manual",
                           NA)
      
      if (is.na(target_col) || !target_col %in% names(data)) next
      
      current_time <- data[[target_col]][row_idx]
      if (is.na(current_time)) next
      
      corrected_time <- apply_time_instruction_case3(current_time, correction_value_2)
      
      if (!identical(current_time, corrected_time)) {
        data[[target_col]][row_idx] <- corrected_time
        operations_applied <- TRUE
        cat(sprintf("    Second adjustment applied: %s -> %s\n", 
                    column_to_adjust_2, correction_value_2))
      }
    }
  }
      
  # Step 3: Check for other operations in solution_humanidentified
  if (!is.na(solution_text) && solution_text != "") {
    swap_ops <- process_swap_operations_case3(data, row_idx, solution_text)
    if (swap_ops$applied) {
      data <- swap_ops$data
      operations_applied <- TRUE
    }
    
    ampm_ops <- process_ampm_conversion(data, row_idx, solution_text)
    if (!is.null(ampm_ops) && ampm_ops$applied) {
      data <- ampm_ops$data
      operations_applied <- TRUE
    }
  }
  
  if (operations_applied) {
    data$manually_corrected[row_idx] <- TRUE
    cat(sprintf("  ✓ Marked as manually corrected: pid=%s, day=%d\n", pid, day_num))
  }
  
  return(data)
}

# Process CASE3 corrections
process_case3_correction <- function(data, correction,
                                     bed_am_col, sleep_am_col,
                                     awake_am_col, getup_am_col) {
  
  pid <- correction$pid
  day_num <- correction$day_num
  column_to_correct <- correction$column_to_correct
  correct_value <- correction$correct_value
  column_to_correct_2 <- correction$column_to_correct_2   
  correct_value_2 <- correction$correct_value_2  
  solution_text <- correction$solution_humanidentified
  
  target_idx <- which(data$pid == pid & data$day_num == day_num)
  if (length(target_idx) == 0) {
    cat(sprintf("  Warning: Cannot find EMA record pid=%s, day=%d\n", pid, day_num))
    return(data)
  }
  
  row_idx <- target_idx[1]
  operations_applied <- FALSE
  
  # Step 1: Handle Undo correction
  if (!is.na(solution_text) && str_detect(tolower(solution_text), "undo correction")) {
    data$time_bed_manual[row_idx] <- data[[bed_am_col]][row_idx]
    data$time_sleep_manual[row_idx] <- data[[sleep_am_col]][row_idx]
    data$time_awake_manual[row_idx] <- data[[awake_am_col]][row_idx]
    data$time_getup_manual[row_idx] <- data[[getup_am_col]][row_idx]
    
    operations_applied <- TRUE
    cat(sprintf("  ✓ Undo correction: pid=%s, day=%d\n", pid, day_num))
    
    if (operations_applied) data$manually_corrected[row_idx] <- TRUE
    return(data)
  }
  
  # Step 2: Process column_to_correct and correct_value
  if (!is.na(column_to_correct) && column_to_correct != "" &&
      !is.na(correct_value) && correct_value != "") {
    
    columns <- parse_columns(column_to_correct)
    
    for (col in columns) {
      target_col <- switch(col,
                           "time_bed_corrected" = "time_bed_manual",
                           "time_sleep_corrected" = "time_sleep_manual",
                           "time_awake_corrected" = "time_awake_manual",
                           "time_getup_corrected" = "time_getup_manual",
                           NA)
      
      if (is.na(target_col) || !target_col %in% names(data)) next
      
      current_time <- data[[target_col]][row_idx]
      if (is.na(current_time)) next
      
      corrected_time <- apply_time_instruction_case3(current_time, correct_value)
      
      if (!identical(current_time, corrected_time)) {
        data[[target_col]][row_idx] <- corrected_time
        operations_applied <- TRUE
      }
      
    }
  }
  
  # Step 2b: Process second correction (column_to_correct_2 + correct_value_2)
  if (!is.na(column_to_correct_2) && column_to_correct_2 != "" &&
      !is.na(correct_value_2) && correct_value_2 != "") {
    
    columns2 <- parse_columns(column_to_correct_2)
    
    for (col in columns2) {
      target_col <- switch(col,
                           "time_bed_corrected" = "time_bed_manual",
                           "time_sleep_corrected" = "time_sleep_manual",
                           "time_awake_corrected" = "time_awake_manual",
                           "time_getup_corrected" = "time_getup_manual",
                           NA)
      
      if (is.na(target_col) || !target_col %in% names(data)) next
      
      current_time <- data[[target_col]][row_idx]
      if (is.na(current_time)) next
      
      corrected_time <- apply_time_instruction_case3(current_time, correct_value_2)
      
      if (!identical(current_time, corrected_time)) {
        data[[target_col]][row_idx] <- corrected_time
        operations_applied <- TRUE
        cat(sprintf("    Second correction applied: %s -> %s\n", 
                    column_to_correct_2, correct_value_2))
      }
    }
  }
  # Step 3: Check for swap operations
  if (!is.na(solution_text) && solution_text != "") {
    swap_ops <- process_swap_operations_case3(data, row_idx, solution_text)
    if (swap_ops$applied) {
      data <- swap_ops$data
      operations_applied <- TRUE
    }
  }
  
  if (operations_applied) {
    data$manually_corrected[row_idx] <- TRUE
    cat(sprintf("  ✓ Marked as manually corrected: pid=%s, day=%d\n", pid, day_num))
  }
  
  return(data)
}

# Process CASE2 corrections
process_case2_correction <- function(data, correction,
                                     bed_am_col, sleep_am_col,
                                     awake_am_col, getup_am_col) {
  
  pid <- correction$pid
  day_num <- correction$day_num
  solution_text <- correction$solution_humanidentified
  
  target_idx <- which(data$pid == pid & data$day_num == day_num)
  if (length(target_idx) == 0) return(data)
  
  row_idx <- target_idx[1]
  operations_applied <- FALSE
  
  # Step 1: Handle Undo correction
  if (str_detect(tolower(solution_text), "undo correction")) {
    data$time_bed_manual[row_idx] <- data[[bed_am_col]][row_idx]
    data$time_sleep_manual[row_idx] <- data[[sleep_am_col]][row_idx]
    data$time_awake_manual[row_idx] <- data[[awake_am_col]][row_idx]
    data$time_getup_manual[row_idx] <- data[[getup_am_col]][row_idx]
    operations_applied <- TRUE
    cat(sprintf("  ✓ Undo correction: pid=%s, day=%d\n", pid, day_num))
  }
  
  # Step 2: Process AM/PM conversion
  ampm_ops <- process_ampm_conversion(data, row_idx, solution_text)
  if (!is.null(ampm_ops)) {
    data <- ampm_ops$data
    operations_applied <- operations_applied || ampm_ops$applied
  }
  
  # Step 3: Process time alignment
  align_ops <- process_align_operations(data, row_idx, solution_text)
  if (!is.null(align_ops)) {
    data <- align_ops$data
    operations_applied <- operations_applied || align_ops$applied
  }
  
  # Step 4: Process time change
  change_ops <- process_change_operations(data, row_idx, solution_text)
  if (!is.null(change_ops)) {
    data <- change_ops$data
    operations_applied <- operations_applied || change_ops$applied
  }
  
  # Step 5: Process hours operations
  hours_ops <- process_hours_operations(data, row_idx, solution_text)
  if (!is.null(hours_ops)) {
    data <- hours_ops$data
    operations_applied <- operations_applied || hours_ops$applied
  }
  
  # Step 6: Process swap operations
  swap_ops <- process_swap_operations(data, row_idx, solution_text)
  if (!is.null(swap_ops)) {
    data <- swap_ops$data
    operations_applied <- operations_applied || swap_ops$applied
  }
  
  if (operations_applied) {
    data$manually_corrected[row_idx] <- TRUE
  }
  
  return(data)
}

# ============================================
# Recalculation and Marking Functions
# ============================================

# Recalculate time differences and mark errors/unusual records
recalculate_and_mark_errors <- function(data, 
                                        bed_corr_col, sleep_corr_col,
                                        awake_corr_col, getup_corr_col) {
  
  cat("  Recalculating time differences and marking...\n")
  
  data <- data %>%
    mutate(
      has_na = is.na(!!sym(bed_corr_col)) | is.na(!!sym(sleep_corr_col)) | 
        is.na(!!sym(awake_corr_col)) | is.na(!!sym(getup_corr_col)),
      
      bed_sleep_diff_h = ifelse(!has_na, 
                                as.numeric(difftime(!!sym(sleep_corr_col), !!sym(bed_corr_col), units = "hours")),
                                NA_real_),
      
      sleep_awake_diff_h = ifelse(!has_na,
                                  as.numeric(difftime(!!sym(awake_corr_col), !!sym(sleep_corr_col), units = "hours")),
                                  NA_real_),
      
      awake_getup_diff_h = ifelse(!has_na,
                                  as.numeric(difftime(!!sym(getup_corr_col), !!sym(awake_corr_col), units = "hours")),
                                  NA_real_),
      
      sleep_awake_diff_min = ifelse(!has_na,
                                    as.numeric(difftime(!!sym(awake_corr_col), !!sym(sleep_corr_col), units = "mins")),
                                    NA_real_),
      
      order_correct = ifelse(!has_na,
                             (!!sym(bed_corr_col) < !!sym(sleep_corr_col)) & 
                               (!!sym(sleep_corr_col) < !!sym(awake_corr_col)) & 
                               (!!sym(awake_corr_col) < !!sym(getup_corr_col)),
                             NA),
      
      reasonable_temporal_order = order_correct,
      reasonable_sleep_latency = ifelse(!has_na, abs(bed_sleep_diff_h) <= 7, NA),
      reasonable_time_in_bed_after_waking = ifelse(!has_na, abs(awake_getup_diff_h) <= 7, NA),
      reasonable_sleep_duration = ifelse(!has_na, abs(sleep_awake_diff_h) <= 24, NA),
      
      bed_sleep_equal = ifelse(!has_na, bed_sleep_diff_h == 0, NA),
      awake_getup_equal = ifelse(!has_na, awake_getup_diff_h == 0, NA),
      
      is_error = case_when(
        has_na ~ FALSE,
        !has_na & !(order_correct & reasonable_sleep_latency & 
                      reasonable_time_in_bed_after_waking & reasonable_sleep_duration) & 
          !(bed_sleep_equal | awake_getup_equal) ~ TRUE,
        TRUE ~ FALSE
      ),
      
      sleep_awake_suspicious = ifelse(!has_na, sleep_awake_diff_h < 3 | sleep_awake_diff_h > 15, NA),
      bed_sleep_suspicious = ifelse(!has_na, bed_sleep_diff_h > 3, NA),
      awake_getup_suspicious = ifelse(!has_na, awake_getup_diff_h > 3, NA),
      
      is_unusual = case_when(
        has_na ~ FALSE,
        !has_na & (sleep_awake_suspicious | bed_sleep_suspicious | awake_getup_suspicious) & 
          !(bed_sleep_equal | awake_getup_equal) ~ TRUE,
        TRUE ~ FALSE
      ),
      
      data_category = case_when(
        has_na ~ "skipped_na",
        !has_na & (bed_sleep_equal | awake_getup_equal) ~ "equal_time_ok",
        !has_na & is_error ~ "error",
        !has_na & is_unusual ~ "unusual",
        !has_na ~ "clean",
        TRUE ~ "unknown"
      ),
      
      error_type = case_when(
        !is_error ~ NA_character_,
        !reasonable_temporal_order ~ "order_error",
        !reasonable_sleep_latency ~ "bed_sleep_diff_error",
        !reasonable_time_in_bed_after_waking ~ "awake_getup_diff_error",
        !reasonable_sleep_duration ~ "sleep_awake_24h_error",
        TRUE ~ "multiple_errors"
      ),
      
      unusual_type = case_when(
        !is_unusual ~ NA_character_,
        sleep_awake_suspicious ~ "sleep_awake_suspicious",
        bed_sleep_suspicious ~ "bed_sleep_suspicious",
        awake_getup_suspicious ~ "awake_getup_suspicious",
        TRUE ~ "multiple_suspicious"
      ),
      
      equal_time_type = case_when(
        bed_sleep_equal & awake_getup_equal ~ "both_equal",
        bed_sleep_equal ~ "bed_sleep_equal",
        awake_getup_equal ~ "awake_getup_equal",
        TRUE ~ NA_character_
      )
    )
  
  return(data)
}

# ============================================
# Classification Function
# ============================================

# Create classified dataframes and exclude Reasonable unusual records
create_classified_dataframes <- function(data, 
                                         bed_am_col, sleep_am_col,
                                         awake_am_col, getup_am_col,
                                         bed_corr_col, sleep_corr_col,
                                         awake_corr_col, getup_corr_col,
                                         duration_col = NULL,
                                         manual_unusual_df = NULL) {
  
  if (is.null(duration_col)) {
    duration_col <- find_duration_columns(data)
  }
  
  cat(sprintf("  Using duration column: %s\n", 
              ifelse(is.null(duration_col), "Not found", duration_col)))
  
  # ============================================
  # Identify Reasonable unusual records from manual_unusual_df
  # ============================================
  reasonable_unusual_records <- NULL
  
  if (!is.null(manual_unusual_df) && nrow(manual_unusual_df) > 0) {
    reasonable_unusual_records <- manual_unusual_df %>%
      filter(!is.na(problem_humanidentified) & 
               str_detect(tolower(problem_humanidentified), "reasonable unusual record")) %>%
      select(pid, row_id, problem_humanidentified, solution_humanidentified) %>%
      distinct()
    
    if (nrow(reasonable_unusual_records) > 0) {
      cat(sprintf("\n  Found %d Reasonable unusual records from manual_unusual_review.csv\n", 
                  nrow(reasonable_unusual_records)))
      
      if (!"is_reasonable_unusual" %in% names(data)) {
        data$is_reasonable_unusual <- FALSE
      }
      
      for (i in 1:nrow(reasonable_unusual_records)) {
        rec <- reasonable_unusual_records[i, ]
        target_idx <- which(data$pid == rec$pid & data$row_id == rec$row_id)
        
        if (length(target_idx) > 0) {
          data$is_reasonable_unusual[target_idx] <- TRUE
          data$data_category[target_idx] <- "reasonable_unusual"
          data$is_unusual[target_idx] <- FALSE
        }
      }
    }
  }
  
  # ============================================
  # Equal time data
  # ============================================
  equal_time_df <- data %>%
    filter(data_category == "equal_time_ok") %>%
    select(pid, day_num, row_id,
           !!sym(bed_am_col), !!sym(sleep_am_col), 
           !!sym(awake_am_col), !!sym(getup_am_col),
           !!sym(bed_corr_col), !!sym(sleep_corr_col), 
           !!sym(awake_corr_col), !!sym(getup_corr_col),
           bed_sleep_diff_h, sleep_awake_diff_h, awake_getup_diff_h,
           bed_sleep_equal, awake_getup_equal, equal_time_type,
           manually_corrected)
  
  # ============================================
  # Error data with duration comparison
  # ============================================
  error_df_base <- data %>%
    filter(data_category == "error") %>%
    select(pid, day_num, row_id,
           !!sym(bed_am_col), !!sym(sleep_am_col), 
           !!sym(awake_am_col), !!sym(getup_am_col),
           !!sym(bed_corr_col), !!sym(sleep_corr_col), 
           !!sym(awake_corr_col), !!sym(getup_corr_col),
           bed_sleep_diff_h, sleep_awake_diff_h, awake_getup_diff_h,
           reasonable_temporal_order, reasonable_sleep_latency, 
           reasonable_time_in_bed_after_waking, reasonable_sleep_duration,
           error_type, manually_corrected)
  
  error_df <- error_df_base
  if (!is.null(duration_col) && duration_col %in% names(data)) {
    duration_data <- data %>%
      filter(data_category == "error") %>%
      select(pid, day_num, row_id, !!sym(duration_col), sleep_awake_diff_min)
    
    error_df <- error_df_base %>%
      left_join(duration_data, by = c("pid", "day_num", "row_id")) %>%
      mutate(
        duration_from_data_min = safe_numeric(!!sym(duration_col)),
        duration_calculated_min = sleep_awake_diff_min,
        duration_difference_min = ifelse(!is.na(duration_calculated_min) & !is.na(duration_from_data_min),
                                         duration_calculated_min - duration_from_data_min, NA_real_),
        duration_difference_h = duration_difference_min / 60,
        duration_match = ifelse(!is.na(duration_difference_min), 
                                abs(duration_difference_min) < 6, NA)
      )
  }
  
  # ============================================
  # Unusual data - Exclude Reasonable unusual records by pid and row_id
  # ============================================
  unusual_df_base <- data %>%
    filter(data_category == "unusual")
  
  if (!is.null(reasonable_unusual_records) && nrow(reasonable_unusual_records) > 0) {
    cat(sprintf("\n  Removing %d Reasonable unusual records from unusual_df (based on pid and row_id)\n", 
                nrow(reasonable_unusual_records)))
    
    exclude_records <- reasonable_unusual_records %>%
      select(pid, row_id) %>%
      distinct() %>%
      mutate(exclude = TRUE)
    
    before_count <- nrow(unusual_df_base)
    
    unusual_df_base <- unusual_df_base %>%
      left_join(exclude_records, by = c("pid", "row_id")) %>%
      filter(is.na(exclude)) %>%
      select(-exclude)
    
    after_count <- nrow(unusual_df_base)
    cat(sprintf("    - Before: %d, After: %d, Removed: %d\n", 
                before_count, after_count, before_count - after_count))
  }
  
  unusual_df <- unusual_df_base %>%
    select(pid, day_num, row_id,
           !!sym(bed_corr_col), !!sym(sleep_corr_col), 
           !!sym(awake_corr_col), !!sym(getup_corr_col),
           bed_sleep_diff_h, sleep_awake_diff_h, awake_getup_diff_h,
           sleep_awake_suspicious, bed_sleep_suspicious, awake_getup_suspicious,
           unusual_type, manually_corrected)
  
  if (!is.null(duration_col) && duration_col %in% names(data)) {
    duration_data <- unusual_df_base %>%
      select(pid, day_num, row_id, !!sym(duration_col), sleep_awake_diff_min)
    
    unusual_df <- unusual_df %>%
      left_join(duration_data, by = c("pid", "day_num", "row_id")) %>%
      mutate(
        duration_from_data_min = safe_numeric(!!sym(duration_col)),
        duration_calculated_min = sleep_awake_diff_min,
        duration_difference_min = ifelse(!is.na(duration_calculated_min) & !is.na(duration_from_data_min),
                                         duration_calculated_min - duration_from_data_min, NA_real_),
        duration_difference_h = duration_difference_min / 60,
        duration_match = ifelse(!is.na(duration_difference_min), 
                                abs(duration_difference_min) < 6, NA)
      )
  }
  
  # ============================================
  # Clean data
  # ============================================
  clean_df_base <- data %>%
    filter(data_category == "clean") %>%
    select(pid, day_num, row_id,
           !!sym(bed_corr_col), !!sym(sleep_corr_col), 
           !!sym(awake_corr_col), !!sym(getup_corr_col),
           bed_sleep_diff_h, sleep_awake_diff_h, awake_getup_diff_h,
           manually_corrected)
  
  clean_df <- clean_df_base
  if (!is.null(duration_col) && duration_col %in% names(data)) {
    duration_data <- data %>%
      filter(data_category == "clean") %>%
      select(pid, day_num, row_id, !!sym(duration_col), sleep_awake_diff_min)
    
    clean_df <- clean_df_base %>%
      left_join(duration_data, by = c("pid", "day_num", "row_id")) %>%
      mutate(
        duration_from_data_min = safe_numeric(!!sym(duration_col)),
        duration_calculated_min = sleep_awake_diff_min,
        duration_difference_min = ifelse(!is.na(duration_calculated_min) & !is.na(duration_from_data_min),
                                         duration_calculated_min - duration_from_data_min, NA_real_),
        duration_difference_h = duration_difference_min / 60,
        duration_match = ifelse(!is.na(duration_difference_min), 
                                abs(duration_difference_min) < 6, NA)
      )
  }
  
  # ============================================
  # Prepare Reasonable unusual records for output
  # ============================================
  reasonable_unusual_output_df <- NULL
  if (!is.null(reasonable_unusual_records) && nrow(reasonable_unusual_records) > 0) {
    reasonable_unusual_output_df <- data %>%
      filter(is_reasonable_unusual == TRUE) %>%
      select(pid, day_num, row_id,
             !!sym(bed_am_col), !!sym(sleep_am_col), 
             !!sym(awake_am_col), !!sym(getup_am_col),
             !!sym(bed_corr_col), !!sym(sleep_corr_col), 
             !!sym(awake_corr_col), !!sym(getup_corr_col),
             bed_sleep_diff_h, sleep_awake_diff_h, awake_getup_diff_h,
             manually_corrected) %>%
      left_join(reasonable_unusual_records %>% 
                  select(pid, row_id, problem_humanidentified, solution_humanidentified),
                by = c("pid", "row_id"))
    
    cat(sprintf("\n  Prepared %d Reasonable unusual records for output\n", 
                nrow(reasonable_unusual_output_df)))
  }
  
  # ============================================
  # Summary statistics
  # ============================================
  total_records <- nrow(data)
  na_count <- sum(data$has_na, na.rm = TRUE)
  valid_records <- total_records - na_count
  
  if (valid_records > 0) {
    equal_time_count <- sum(data$data_category == "equal_time_ok", na.rm = TRUE)
    error_count <- sum(data$data_category == "error", na.rm = TRUE)
    unusual_count <- nrow(unusual_df)
    reasonable_count <- ifelse(!is.null(reasonable_unusual_records), 
                               nrow(reasonable_unusual_records), 0)
    clean_count <- sum(data$data_category == "clean", na.rm = TRUE)
    corrected_count <- sum(data$manually_corrected, na.rm = TRUE)
  } else {
    equal_time_count <- error_count <- unusual_count <- 
      clean_count <- corrected_count <- reasonable_count <- 0
  }
  
  # Duration statistics
  duration_stats <- NULL
  if (!is.null(duration_col) && duration_col %in% names(data)) {
    valid_with_duration <- data %>%
      filter(!has_na & !is.na(!!sym(duration_col)))
    
    if (nrow(valid_with_duration) > 0) {
      valid_with_duration <- valid_with_duration %>%
        mutate(
          duration_data = safe_numeric(!!sym(duration_col)),
          duration_calc = sleep_awake_diff_min
        )
      
      duration_stats <- valid_with_duration %>%
        summarise(
          records_with_duration = n(),
          mean_duration_data_min = mean(duration_data, na.rm = TRUE),
          mean_duration_calc_min = mean(duration_calc, na.rm = TRUE),
          mean_duration_diff_min = mean(duration_calc - duration_data, na.rm = TRUE),
          mean_duration_diff_h = mean_duration_diff_min / 60,
          duration_match_rate = mean(abs(duration_calc - duration_data) < 6, na.rm = TRUE) * 100
        )
    }
  }
  
  correction_summary <- data.frame(
    total_records = total_records,
    skipped_na_records = na_count,
    valid_records = valid_records,
    equal_time_records = equal_time_count,
    error_records = error_count,
    unusual_records = unusual_count,
    reasonable_unusual_records = reasonable_count,
    clean_records = clean_count,
    manually_corrected_records = corrected_count,
    error_rate = ifelse(valid_records > 0, round(error_count/valid_records*100, 1), 0),
    unusual_rate = ifelse(valid_records > 0, round(unusual_count/valid_records*100, 1), 0),
    reasonable_unusual_rate = ifelse(valid_records > 0, round(reasonable_count/valid_records*100, 1), 0),
    correction_rate = ifelse(valid_records > 0, round(corrected_count/valid_records*100, 1), 0)
  )
  
  if (!is.null(duration_stats)) {
    correction_summary <- cbind(correction_summary, duration_stats)
  }
  
  # ============================================
  # Return results
  # ============================================
  result_list <- list(
    equal_time_df = equal_time_df,
    error_df = error_df,
    unusual_df = unusual_df,
    clean_df = clean_df,
    correction_summary = correction_summary
  )
  
  if (!is.null(reasonable_unusual_output_df) && nrow(reasonable_unusual_output_df) > 0) {
    result_list$reasonable_unusual_df <- reasonable_unusual_output_df
  }
  
  return(result_list)
}

# ============================================
# Main Function
# ============================================

# Apply manual corrections and recalculate EMA data
apply_manual_corrections_and_recalculate <- function(ema_data, corrections_df, manual_unusual_df = NULL) {
  
  cat("=== Starting manual corrections application to EMA data ===\n")
  
  # Check required columns
  required_cols <- c("pid", "day_num", "row_id")
  missing_in_ema <- setdiff(required_cols, names(ema_data))
  
  if (length(missing_in_ema) > 0) {
    stop(sprintf("EMA data missing required columns: %s", 
                 paste(missing_in_ema, collapse=", ")))
  }
  
  # Fixed column names - using exact patterns
  time_bed_am_col <- "time_bed_am_hhmm_ampm"
  time_sleep_am_col <- "time_sleep_am_hhmm_ampm"
  time_awake_am_col <- "time_awake_am_hhmm_ampm"
  time_getup_am_col <- "time_getup_am_hhmm_ampm"
  
  time_bed_corrected_col <- "time_bed_corrected"
  time_sleep_corrected_col <- "time_sleep_corrected"
  time_awake_corrected_col <- "time_awake_corrected"
  time_getup_corrected_col <- "time_getup_corrected"
  
  duration_col <- find_duration_columns(ema_data)
  
  cat("\nUsing time columns:\n")
  cat(sprintf("  Original bed column: %s\n", time_bed_am_col))
  cat(sprintf("  Original sleep column: %s\n", time_sleep_am_col))
  cat(sprintf("  Original awake column: %s\n", time_awake_am_col))
  cat(sprintf("  Original getup column: %s\n", time_getup_am_col))
  cat(sprintf("  Corrected bed column: %s\n", time_bed_corrected_col))
  cat(sprintf("  Corrected sleep column: %s\n", time_sleep_corrected_col))
  cat(sprintf("  Corrected awake column: %s\n", time_awake_corrected_col))
  cat(sprintf("  Corrected getup column: %s\n", time_getup_corrected_col))
  cat(sprintf("  Duration column: %s\n", 
              ifelse(is.null(duration_col), "Not found", duration_col)))
  
  # ============================================
  # Step 1: Initialize and create manual columns
  # ============================================
  cat("\n1. Initializing modifications...\n")
  
  if (!"time_bed_manual" %in% names(ema_data)) {
    ema_data <- ema_data %>%
      mutate(
        time_bed_manual = !!sym(time_bed_corrected_col),
        time_sleep_manual = !!sym(time_sleep_corrected_col),
        time_awake_manual = !!sym(time_awake_corrected_col),
        time_getup_manual = !!sym(time_getup_corrected_col)
      )
    cat("  ✓ Created manual columns\n")
  }
  
  if (!"manually_corrected" %in% names(ema_data)) {
    ema_data$manually_corrected <- FALSE
  }
  
  if (!"sleep_awake_diff_min" %in% names(ema_data)) {
    ema_data <- ema_data %>%
      mutate(
        sleep_awake_diff_min = ifelse(!is.na(!!sym(time_awake_corrected_col)) & !is.na(!!sym(time_sleep_corrected_col)),
                                      as.numeric(difftime(!!sym(time_awake_corrected_col), !!sym(time_sleep_corrected_col), units = "mins")),
                                      NA_real_)
      )
    cat("  ✓ Created sleep_awake_diff_min column\n")
  }

  
  # ============================================
  # Step 2: Process Manual unusual records
  # ============================================
  cat("\n2. Processing Manual unusual records...\n")
  
  if (!is.null(manual_unusual_df) && nrow(manual_unusual_df) > 0) {
    manual_unusual_corrections <- manual_unusual_df %>%
      filter(!is.na(problem_humanidentified) & 
               str_detect(tolower(problem_humanidentified), "manual unusual"))
    
    if (nrow(manual_unusual_corrections) > 0) {
      cat(sprintf("  Found %d Manual unusual records\n", nrow(manual_unusual_corrections)))
      
      for (i in 1:nrow(manual_unusual_corrections)) {
        corr <- manual_unusual_corrections[i, ]
        cat(sprintf("\n  Processing Manual unusual: pid=%s, row_id=%s\n", corr$pid, corr$row_id))
        
        ema_data <- process_manual_unusual_correction(ema_data, corr,
                                                      time_bed_am_col, time_sleep_am_col,
                                                      time_awake_am_col, time_getup_am_col)
      }
    }
  }
  
  # ============================================
  # Step 3: Process regular corrections
  # ============================================
  cat("\n3. Processing regular correction instructions...\n")
  
  case1_count <- 0
  case2_count <- 0
  case3_count <- 0
  case4_count <- 0
  
  for (i in 1:nrow(corrections_df)) {
    corr <- corrections_df[i, ]
    
    solution_na <- is.na(corr$solution_humanidentified) || corr$solution_humanidentified == ""
    column_na <- is.na(corr$column_to_correct) || corr$column_to_correct == ""
    value_na <- is.na(corr$correct_value) || corr$correct_value == ""
    
    # Case 1: All empty
    if (solution_na && column_na && value_na) {
      case1_count <- case1_count + 1
      next
    }
    
    # Case 3: column_to_correct and correct_value both non-empty
    if (!column_na && !value_na) {
      ema_data <- process_case3_correction(ema_data, corr,
                                           time_bed_am_col, time_sleep_am_col,
                                           time_awake_am_col, time_getup_am_col)
      case3_count <- case3_count + 1
      next
    }
    
    # Case 2: solution_humanidentified non-empty, column or value empty
    if (!solution_na && (column_na || value_na)) {
      ema_data <- process_case2_correction(ema_data, corr,
                                           time_bed_am_col, time_sleep_am_col,
                                           time_awake_am_col, time_getup_am_col)
      case2_count <- case2_count + 1
      next
    }
    
    # Case 4: Other cases
    case4_count <- case4_count + 1
    cat(sprintf("  Warning: Cannot process row %d (pid=%s, day=%d)\n", 
                i, corr$pid, corr$day_num))
  }
  
  # ============================================
  # Step 4: Update corrected columns
  # ============================================
  cat("\n4. Updating EMA corrected columns...\n")
  
  ema_data <- ema_data %>%
    mutate(
      !!sym(time_bed_corrected_col) := time_bed_manual,
      !!sym(time_sleep_corrected_col) := time_sleep_manual,
      !!sym(time_awake_corrected_col) := time_awake_manual,
      !!sym(time_getup_corrected_col) := time_getup_manual
    )
  
  cat("  ✓ Corrected columns updated\n")
  
  # ============================================
  # Step 5: Check swap operations
  # ============================================
  cat("\n5. Checking swap operations...\n")
  ema_data <- check_swap_corrections(ema_data, corrections_df)
  
  # ============================================
  # Step 6: Recalculate time differences and mark
  # ============================================
  cat("\n6. Recalculating time differences and marking...\n")
  ema_data <- recalculate_and_mark_errors(ema_data, 
                                          time_bed_corrected_col,
                                          time_sleep_corrected_col,
                                          time_awake_corrected_col,
                                          time_getup_corrected_col)
  
  # ============================================
  # Step 7: Update correction status
  # ============================================
  cat("\n7. Updating correction status...\n")
  
  corrected_pids <- ema_data %>% 
    filter(manually_corrected == TRUE) %>% 
    pull(pid) %>% unique()
  
  corrected_days <- ema_data %>% 
    filter(manually_corrected == TRUE) %>% 
    pull(day_num) %>% unique()
  
  for (pid_val in corrected_pids) {
    for (day_val in corrected_days) {
      idx <- which(corrections_df$pid == pid_val & corrections_df$day_num == day_val)
      if (length(idx) > 0) {
        corrections_df$manually_corrected[idx] <- TRUE
      }
    }
  }
  
  write_csv(corrections_df, "manual_error_correction_updated.csv", na = "")
  cat(sprintf("  ✓ Saved updated corrections to manual_error_correction_updated.csv\n"))
  
  # ============================================
  # Step 8: Generate statistics
  # ============================================
  cat("\n=== Correction Complete Statistics ===\n")
  cat(sprintf("Case1 (Skipped): %d\n", case1_count))
  cat(sprintf("Case2 (Solution-based): %d\n", case2_count))
  cat(sprintf("Case3 (Column/Value-based): %d\n", case3_count))
  cat(sprintf("Case4 (Unprocessable): %d\n", case4_count))
  
  total_corrected <- sum(ema_data$manually_corrected, na.rm = TRUE)
  total_records <- nrow(ema_data)
  cat(sprintf("\nEMA Data Correction Statistics:\n"))
  cat(sprintf("  Total records: %d\n", total_records))
  cat(sprintf("  Manually corrected: %d (%.1f%%)\n", 
              total_corrected, total_corrected/total_records*100))
  
  # ============================================
  # Step 9: Create classified dataframes
  # ============================================
  cat("\n9. Creating classified dataframes...\n")
  
  ema_data <- ensure_marking_columns(ema_data)
  
  results <- create_classified_dataframes(ema_data,
                                          time_bed_am_col, time_sleep_am_col,
                                          time_awake_am_col, time_getup_am_col,
                                          time_bed_corrected_col, time_sleep_corrected_col,
                                          time_awake_corrected_col, time_getup_corrected_col,
                                          duration_col = duration_col,
                                          manual_unusual_df = manual_unusual_df)
  
  list2env(results, envir = .GlobalEnv)
  
  cat("\n✓ All dataframes saved to global environment:\n")
  cat("  equal_time_df: Equal time records\n")
  cat("  error_df: Error records (with duration comparison)\n")
  cat("  unusual_df: Unusual records (Reasonable unusual records removed by pid and row_id)\n")
  cat("  clean_df: Clean records\n")
  
  if ("reasonable_unusual_df" %in% names(results)) {
    assign("reasonable_unusual_df", results$reasonable_unusual_df, envir = .GlobalEnv)
    cat("  reasonable_unusual_df: Reasonable unusual records\n")
  }
  
  cat("  correction_summary: Correction statistics\n")
  
  if (!is.null(duration_col)) {
    cat("\n✓ Duration comparison added to error_df and unusual_df:\n")
    cat("  - duration_from_data_min: Duration from original data (minutes)\n")
    cat("  - duration_calculated_min: Duration calculated from sleep times (minutes)\n")
    cat("  - duration_difference_min: Difference (minutes)\n")
    cat("  - duration_difference_h: Difference (hours)\n")
    cat("  - duration_match: Difference < 6 minutes\n")
  }
  
  if (exists("reasonable_unusual_df") && nrow(reasonable_unusual_df) > 0) {
    write_csv(reasonable_unusual_df, "reasonable_unusual_records.csv", na = "")
    cat(sprintf("\n✓ Saved %d Reasonable unusual records to reasonable_unusual_records.csv\n", 
                nrow(reasonable_unusual_df)))
  }
  
  return(list(
    corrected_ema_data = ema_data,
    updated_corrections = corrections_df,
    classification_results = results,
    manual_unusual_records = if (!is.null(manual_unusual_df)) manual_unusual_df else NULL
  ))
}