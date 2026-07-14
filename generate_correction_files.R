# ============================================
# generate_correction_files.R
# Function: Generate correction files based on ERROR_TYPE, UNUSUAL_TYPE, and EQUAL_TIME_TYPE conditions
# ============================================
#
# OVERVIEW:
# This function takes processed sleep diary data and classifies every sleep record
# into one of four categories based on temporal reasonability thresholds:
#   1. CLEAN (normal) — no issues detected, no review needed
#   2. EQUAL_TIME — adjacent timestamps are identical (e.g., bed==sleep), which is
#      common and can be auto-resolved; no human review needed
#   3. ERROR — severe temporal violations that make the record unusable without
#      correction (e.g., times out of order, differences >7h/24h)
#   4. UNUSUAL — suspicious but not clearly wrong; human review decides
#
# It produces two CSV files for human annotators:
#   - [NEW]manual_error_correction_review.csv — records flagged as ERROR
#   - [NEW]manual_unusual_review.csv — records flagged as UNUSUAL
#
# Classification priority chain (first match wins):
#   EQUAL_TIME > ERROR > UNUSUAL > CLEAN (normal)

generate_correction_files <- function(ema_data_release_timecalc) {
  
  # Load required libraries
  require(dplyr)
  require(lubridate)
  require(stringr)
  require(tidyr)
  require(readr)
  
  cat("\n========================================\n")
  cat("Starting correction file generation\n")
  cat("========================================\n")
  cat("Input dataframe: ema_data_release_timecalc\n")
  cat("Dataframe rows:", nrow(ema_data_release_timecalc), "\n")
  
  # Define column name mapping
  col_mapping <- list(
    bed_am = "time_bed_am_hhmm_ampm",
    sleep_am = "time_sleep_am_hhmm_ampm",
    awake_am = "time_awake_am_hhmm_ampm", 
    getup_am = "time_getup_am_hhmm_ampm",
    bed_corrected = "time_bed_corrected",
    sleep_corrected = "time_sleep_corrected",
    awake_corrected = "time_awake_corrected",
    getup_corrected = "time_getup_corrected"
  )
  
  # Check required columns
  cat("\n1. Checking required columns...\n")
  required_cols <- unlist(col_mapping)
  missing_cols <- required_cols[!required_cols %in% names(ema_data_release_timecalc)]
  if (length(missing_cols) > 0) {
    stop("Error: Missing required columns: ", paste(missing_cols, collapse = ", "))
  }
  cat("✓ All required columns exist\n")
  
  # Check and get available duration columns
  # These are optional: the data may or may not have SOL/ WASO/ nap estimates.
  # We store which ones exist so we can include them in output CSVs if available.
  duration_cols <- c(
    "duration_totalmin_sol_estimate_am",
    "duration_totalmin_waso_estimate_am",
    "duration_totalmin_napstoday_PM"
  )
  available_duration_cols <- duration_cols[duration_cols %in% names(ema_data_release_timecalc)]
  
  # ============================================
  # 1. Add row_id to dataframe
  # ============================================
  # WHAT: Creates a unique integer identifier (1..N) for every row in the dataframe.
  # WHY: Every record needs a stable, unique key so that downstream review files
  #   can reference specific records unambiguously. The original data may not have
  #   a natural primary key, so we add one here.
  # WHAT HAPPENS NEXT: All subsequent filtering/joining refers back to this row_id
  #   to track which records fall into which category.
  
  cat("\n2. Adding row identifiers...\n")
  ema_data <- ema_data_release_timecalc %>%
    mutate(row_id = row_number())
  
  # ============================================
  # 2. Calculate all time differences
  # ============================================
  # WHAT: Computes three pairwise time differences in hours from the four corrected
  #   timestamps (bed→sleep→awake→getup), plus a boolean check that these timestamps
  #   are in chronological order.
  # WHY: All subsequent classification decisions (ERROR, UNUSUAL, EQUAL_TIME) are
  #   based on these diff values. Without them, we cannot automatically detect
  #   problems like out-of-order events or implausibly long/short intervals.
  # CALCULATIONS:
  #   bed_sleep_diff_h     = sleep time minus bed time (sleep latency)
  #   sleep_awake_diff_h   = awake time minus sleep time (total sleep period)
  #   awake_getup_diff_h   = getup time minus awake time (time in bed after waking)
  #   temporal_order_check = TRUE if bed ≤ sleep ≤ awake ≤ getup
  # WHAT HAPPENS NEXT: These diff columns are used by EQUAL_TIME (Section 3),
  #   ERROR (Section 4), and UNUSUAL (Section 5) classification blocks.
  
  cat("\n3. Calculating time differences...\n")
  
  ema_data_with_diffs <- ema_data %>%
    mutate(
      # Calculate time differences (hours)
      bed_sleep_diff_h = as.numeric(difftime(!!sym(col_mapping$sleep_corrected), 
                                             !!sym(col_mapping$bed_corrected), 
                                             units = "hours")),
      sleep_awake_diff_h = as.numeric(difftime(!!sym(col_mapping$awake_corrected), 
                                               !!sym(col_mapping$sleep_corrected), 
                                               units = "hours")),
      awake_getup_diff_h = as.numeric(difftime(!!sym(col_mapping$getup_corrected), 
                                               !!sym(col_mapping$awake_corrected), 
                                               units = "hours")),
      
      # Temporal order check
      temporal_order_check = 
        !!sym(col_mapping$bed_corrected) <= !!sym(col_mapping$sleep_corrected) &
        !!sym(col_mapping$sleep_corrected) <= !!sym(col_mapping$awake_corrected) &
        !!sym(col_mapping$awake_corrected) <= !!sym(col_mapping$getup_corrected)
    )
  
  # ============================================
  # 3. EQUAL_TIME_TYPE condition assessment
  # ============================================
  # WHAT: Detects records where adjacent timestamps are identical (within floating-
  #   point tolerance). Four equal-time patterns exist:
  #     Type 1 — bed_sleep_equal:       bed time == sleep time (sleep latency = 0)
  #     Type 2 — awake_getup_equal:     awake time == getup time (no time in bed after waking)
  #     Type 3 — both_equal:            both pairs equal (bed==sleep AND awake==getup)
  # WHY: Equal timestamps are common in real-world sleep diaries (participants often
  #   report bed and sleep as the same time). These records can be auto-accepted
  #   only when the full temporal order is otherwise valid. Equal timestamps must
  #   not mask order errors such as bed > sleep or awake > getup.
  # WHAT HAPPENS NEXT: Valid equal-time records are grouped into equal_time_df_pre.
  
  cat("\n4. Assessing EQUAL_TIME_TYPE conditions...\n")
  
  ema_data_with_diffs <- ema_data_with_diffs %>%
    mutate(
      # Type 1 — bed_sleep_equal: bed and sleep times are equal
      # Participant reported going to bed and falling asleep at the same moment.
      # Diff < 0.01 hours (~36 seconds) accounts for floating-point imprecision.
      bed_sleep_equal = abs(bed_sleep_diff_h) < 0.01,
      
      # Type 2 — awake_getup_equal: awake and getup times are equal
      # Participant reported waking up and getting out of bed at the same moment.
      awake_getup_equal = abs(awake_getup_diff_h) < 0.01,
      
      # Type 3 — both_equal: both are equal
      # Both bed==sleep AND awake==getup — the entire record has no "gaps."
      both_equal = bed_sleep_equal & awake_getup_equal,
      
      # Equal time flag — TRUE only if an adjacent pair is equal AND the overall
      # temporal order is valid. Otherwise the row must flow into error review.
      is_equal_time = (bed_sleep_equal | awake_getup_equal) & temporal_order_check,
      
      # Equal time type classification — records which pattern occurred
      equal_time_type = case_when(
        both_equal ~ "both_equal",
        bed_sleep_equal ~ "bed_sleep_equal",
        awake_getup_equal ~ "awake_getup_equal",
        TRUE ~ NA_character_
      )
    )
  
  # Equal type statistics
  cat("\nEqual time type statistics:\n")
  equal_stats <- ema_data_with_diffs %>%
    filter(is_equal_time) %>%
    count(equal_time_type) %>%
    arrange(desc(n))
  print(equal_stats)
  
  # ============================================
  # 4. ERROR_TYPE condition assessment (Priority Order)
  # ============================================
  # WHAT: Detects records with severe temporal violations. Errors are assessed in
  #   priority order, and each record gets classified as the FIRST error it matches:
  #
  #   Priority 0 — sleep_awake_equal_error:  sleep==awake (only when NOT already
  #       equal_time). This is separated because sleep==awake is always a data
  #       error rather than a benign equal-time pattern.
  #   Priority 1 — order_error:              timestamps violate bed≤sleep≤awake≤getup.
  #       This means the participant's reported sequence is physically impossible
  #       (e.g., getup before bed).
  #   Priority 2 — bed_sleep_diff_error:     |bed - sleep| > 7 hours.
  #       Sleep latency longer than 7 hours is implausible (likely a data entry error
  #       where bed/sleep times were swapped or mis-entered).
  #   Priority 3 — awake_getup_diff_error:   |awake - getup| > 7 hours.
  #       Staying in bed for >7 hours after final waking is implausible.
  #   Priority 4 — sleep_awake_24h_error:    |sleep - awake| > 24 hours.
  #       A single sleep period longer than 24 hours is impossible (spans multiple
  #       days, indicating a date/timestamp entry error).
  #
  # WHY: These records are NOT trustable as-is. They need human intervention to
  #   identify the correct value. The priority ordering ensures that the MOST
  #   severe problem is surfaced first, so human reviewers fix the root cause
  #   rather than downstream symptoms.
  # WHAT HAPPENS NEXT: Error records are sent to manual_corrections_pre for
  #   human review. They are excluded from UNUSUAL and EQUAL_TIME via exclusion
  #   conditions. The `error_type` column records which priority condition fired.
  
  cat("\n5. Assessing ERROR_TYPE conditions...\n")
  
  ema_data_with_diffs <- ema_data_with_diffs %>%
    mutate(
      # Priority 0 — sleep_awake_equal_error: sleep and awake times are equal
      # This is treated as an error (not an equal-time pattern) because a sleep
      # period of zero hours means the data is fundamentally broken.
      sleep_awake_equal_error = abs(sleep_awake_diff_h) < 0.01,
      
      # Priority 1 — order_error: temporal sequence is violated
      # Something like getup before bed, or awake before sleep. The physical
      # timeline of a single night is impossible. This is the most severe error.
      order_error = !temporal_order_check & !sleep_awake_equal_error,
      
      # Priority 2 — bed_sleep_diff_error: |diff| > 7 hours
      # The gap between going to bed and falling asleep exceeds 7 hours.
      # Reasonable sleep latency is minutes, not hours. >7h likely means the
      # participant entered one of the two times incorrectly.
      bed_sleep_diff_error = abs(bed_sleep_diff_h) > 7 &
        !order_error & !is_equal_time & !sleep_awake_equal_error,
      
      # Priority 3 — awake_getup_diff_error: |diff| > 7 hours
      # The gap between final waking and getting out of bed exceeds 7 hours.
      # Lying in bed >7h after waking is implausible; likely an entry error.
      awake_getup_diff_error = abs(awake_getup_diff_h) > 7 &
        !order_error & !bed_sleep_diff_error & !is_equal_time & !sleep_awake_equal_error,
      
      # Priority 4 — sleep_awake_24h_error: |diff| > 24 hours
      # The total sleep period exceeds 24 hours. This is impossible for a single
      # night and suggests the timestamps span multiple days incorrectly.
      sleep_awake_24h_error = abs(sleep_awake_diff_h) > 24 &
        !order_error & !bed_sleep_diff_error & !awake_getup_diff_error &
        !is_equal_time & !sleep_awake_equal_error,
      
      # Error flag — TRUE if the record matches any error condition
      is_error = (order_error | bed_sleep_diff_error | awake_getup_diff_error | 
                    sleep_awake_24h_error | sleep_awake_equal_error),
      
      # Error type — records which error condition fired (first match by priority)
      error_type = case_when(
        sleep_awake_equal_error ~ "sleep_awake_equal_error",
        order_error ~ "order_error",
        bed_sleep_diff_error ~ "bed_sleep_diff_error",
        awake_getup_diff_error ~ "awake_getup_diff_error",
        sleep_awake_24h_error ~ "sleep_awake_24h_error",
        TRUE ~ NA_character_
      )
    )
  
  # Error type statistics
  cat("\nError type statistics:\n")
  error_stats <- ema_data_with_diffs %>%
    filter(is_error) %>%
    count(error_type) %>%
    arrange(desc(n))
  print(error_stats)
  
  # ============================================
  # 5. UNUSUAL_TYPE condition assessment
  # ============================================
  # WHAT: Detects records with suspicious — but not necessarily impossible — values.
  #   Four suspicious patterns (NOT mutually exclusive; a record can match multiple):
  #
  #   Condition 1 — sleep_awake_suspicious:  total sleep <3h OR >15h
  #       <3h:   Very short sleep is possible but warrants review — could be
  #              accurate (insomnia) or a data error.
  #       >15h:  Very long sleep is unusual; could be accurate (recovery) or a
  #              misreported time.
  #
  #   Condition 2 — bed_sleep_suspicious:    sleep latency >3h
  #       More than 3 hours to fall asleep is unusual enough to flag for review.
  #
  #   Condition 3 — awake_getup_suspicious:  >3h in bed after waking
  #       Staying in bed >3 hours after waking is flagged for review.
  #
  #   Condition 4 — multiple_suspicious:     2+ suspicious conditions at once
  #       A record with multiple individually plausible flags is collectively
  #       more suspicious and gets its own category.
  #
  # WHY: These thresholds catch plausible-but-unusual data that an automated
  #   system should not override but a human should look at. The thresholds are
  #   intentionally generous (3h) to catch edge cases without over-flagging.
  # WHAT HAPPENS NEXT: Unusual records go to manual_unusual_pre for human review.
  #   They are guaranteed NOT to be ERROR or EQUAL_TIME records (excluded via
  #   !is_error & !is_equal_time guards).
  
  cat("\n6. Assessing UNUSUAL_TYPE conditions...\n")
  
  ema_data_with_diffs <- ema_data_with_diffs %>%
    mutate(
      # Condition 1 — sleep_awake_suspicious: <3h OR >15h
      # Very short or very long total sleep duration. Both ends of the spectrum
      # can be legitimate but warrant a human look.
      sleep_awake_suspicious = (sleep_awake_diff_h < 3 | sleep_awake_diff_h > 15) & 
        !is_error & !is_equal_time,
      
      # Condition 2 — bed_sleep_suspicious: >3h
      # Unusually long sleep latency. Most people fall asleep in <1h; >3h is
      # unusual enough to flag.
      bed_sleep_suspicious = bed_sleep_diff_h > 3 & !is_error & !is_equal_time,
      
      # Condition 3 — awake_getup_suspicious: >3h
      # Unusually long time in bed after waking.
      awake_getup_suspicious = awake_getup_diff_h > 3 & !is_error & !is_equal_time,
      
      # Condition 4 — multiple_suspicious: multiple suspicious conditions
      # When >=2 individual conditions fire simultaneously, the record is
      # collectively more suspicious than any single flag would suggest.
      multiple_suspicious = (sleep_awake_suspicious + bed_sleep_suspicious + awake_getup_suspicious) >= 2,
      
      # Unusual flag — TRUE if any suspicious condition fires AND not error/equal_time
      is_unusual = (sleep_awake_suspicious | bed_sleep_suspicious | awake_getup_suspicious | multiple_suspicious) & 
        !is_error & !is_equal_time,
      
      # Unusual type — records WHICH suspicious pattern was the primary reason
      # multiple_suspicious is checked first because it takes priority over
      # individual conditions.
      unusual_type = case_when(
        multiple_suspicious ~ "multiple_suspicious",
        sleep_awake_suspicious ~ "sleep_awake_suspicious",
        bed_sleep_suspicious ~ "bed_sleep_suspicious",
        awake_getup_suspicious ~ "awake_getup_suspicious",
        TRUE ~ NA_character_
      )
    )
  
  # Unusual type statistics
  cat("\nUnusual type statistics:\n")
  unusual_stats <- ema_data_with_diffs %>%
    filter(is_unusual) %>%
    count(unusual_type) %>%
    arrange(desc(n))
  print(unusual_stats)
  
  # ============================================
  # 6. Final classification statistics
  # ============================================
  # WHAT: Assembles a final category label for every record using this priority:
  #   is_error → "error" > is_equal_time → "equal_time" > is_unusual → "unusual"
  #   > otherwise → "normal" (clean).
  #   Also prints category counts and percentages to the console.
  # WHY: This gives an at-a-glance summary of data quality. The percentages tell
  #   the analyst how much of the dataset needs human review vs. how much is
  #   automatically clean.
  # WHAT HAPPENS NEXT: The `final_stats` dataframe is the source for the three
  #   review subset dataframes created in Sections 7-9.
  
  cat("\n7. Final classification statistics:\n")
  
  final_stats <- ema_data_with_diffs %>%
    mutate(
      final_category = case_when(
        is_error ~ "error",
        is_equal_time ~ "equal_time",
        is_unusual ~ "unusual",
        TRUE ~ "normal"
      )
    )
  
  category_counts <- table(final_stats$final_category)
  print(category_counts)
  
  # Display percentages
  cat("\nClassification percentages:\n")
  category_pct <- prop.table(category_counts) * 100
  print(round(category_pct, 2))
  
  # ============================================
  # 7. Create error_df_pre (with all required columns)
  # ============================================
  # WHAT: Extracts all records flagged is_error into a separate dataframe with
  #   columns organized for human review. Includes original timestamps, check-
  #   for-errors flags, corrected timestamps, difference calculations, and
  #   blank human-review columns that annotators will fill in.
  # WHY: This is the working dataframe for error records in the R environment.
  #   It pre-populates NA placeholder columns (problem_humanidentified,
  #   solution_humanidentified, etc.) that human reviewers will complete.
  #   It also adds three new reasonable_* columns (set to NA) for compatibility
  #   with downstream comparison workflows.
  # WHAT HAPPENS NEXT: A subset of columns from error_df_pre is selected for
  #   the human-facing CSV (manual_corrections_pre) in Section 11.
  
  cat("\n8. Creating error_df_pre...\n")
  
  error_df_pre <- final_stats %>%
    filter(is_error) %>%
    select(
      # Identifier columns — uniquely identify this record
      pid, day_num, row_id,
      
      # Duration columns (if available in source data)
      any_of(c(
        "duration_totalmin_sol_estimate_am",
        "duration_totalmin_waso_estimate_am",
        "duration_totalmin_napstoday_PM"
      )),
      
      # Original reported timestamps + their check-for-errors flags
      time_bed_am_hhmm_ampm, time_bed_am_checkforerrors,
      time_sleep_am_hhmm_ampm, time_sleep_am_checkforerrors,
      time_awake_am_hhmm_ampm, time_awake_am_checkforerrors,
      time_getup_am_hhmm_ampm, time_getup_am_checkforerrors,
      
      # Number of WASO (Wake After Sleep Onset) episodes
      num_waso_estimate_am,
      
      # Algorithm-corrected timestamps (the values used in diff calculations)
      !!sym(col_mapping$bed_corrected), !!sym(col_mapping$sleep_corrected), 
      !!sym(col_mapping$awake_corrected), !!sym(col_mapping$getup_corrected),
      
      # Computed difference values and error classification
      bed_sleep_diff_h, sleep_awake_diff_h, awake_getup_diff_h,
      temporal_order_check,
      error_type, corrected, correction_type
    ) %>%
    rename(
      reasonable_temporal_order = temporal_order_check
    ) %>%
    mutate(
      # Error-related reasonable judgment columns (for compatibility)
      # These exist in the equivalent human-reviewed output but haven't been
      # filled yet; they remain NA until a human annotator reviews them.
      reasonable_sleep_latency = NA,
      reasonable_time_in_bed_after_waking = NA,
      reasonable_sleep_duration = NA,
      
      # Human review columns — blank placeholders for annotators to complete
      problem_humanidentified = NA_character_,
      solution_humanidentified = NA_character_,
      column_to_correct = NA_character_,
      correct_value = NA_character_,
      manually_corrected = FALSE
    )
  
  cat(sprintf("✓ error_df_pre created: %d rows\n", nrow(error_df_pre)))
  
  # Display detailed error type distribution
  cat("\nDetailed error type distribution:\n")
  error_detail <- error_df_pre %>%
    count(error_type) %>%
    mutate(percentage = n / nrow(error_df_pre) * 100) %>%
    arrange(desc(n))
  print(error_detail)
  
  # ============================================
  # 8. Create unusual_df_pre (with all required columns)
  # ============================================
  # WHAT: Extracts all records flagged is_unusual into a separate dataframe,
  #   organized for R environment access. Similar structure to error_df_pre
  #   but with columns relevant to unusual classification (the suspicious flags
  #   instead of error_type/correction fields).
  # WHY: Provides an in-R working copy of unusual records for programmatic
  #   inspection before the human-facing CSV is created.
  # WHAT HAPPENS NEXT: A subset of columns is selected for the human-facing
  #   CSV (manual_unusual_pre) in Section 12.
  
  cat("\n9. Creating unusual_df_pre...\n")
  
  unusual_df_pre <- final_stats %>%
    filter(is_unusual) %>%
    select(
      # Identifier columns
      pid, day_num, row_id,
      
      # Duration columns (if available)
      any_of(c(
        "duration_totalmin_sol_estimate_am",
        "duration_totalmin_waso_estimate_am",
        "duration_totalmin_napstoday_PM"
      )),
      
      # Original reported timestamps + check-for-errors flags
      time_bed_am_hhmm_ampm, time_bed_am_checkforerrors,
      time_sleep_am_hhmm_ampm, time_sleep_am_checkforerrors,
      time_awake_am_hhmm_ampm, time_awake_am_checkforerrors,
      time_getup_am_hhmm_ampm, time_getup_am_checkforerrors,
      
      # Number of WASO episodes
      num_waso_estimate_am,
      
      # Algorithm-corrected timestamps
      !!sym(col_mapping$bed_corrected), !!sym(col_mapping$sleep_corrected), 
      !!sym(col_mapping$awake_corrected), !!sym(col_mapping$getup_corrected),
      
      # Computed differences and unusual classification details
      bed_sleep_diff_h, sleep_awake_diff_h, awake_getup_diff_h,
      unusual_type,
      bed_sleep_suspicious, sleep_awake_suspicious, awake_getup_suspicious,
      multiple_suspicious
    ) %>%
    mutate(
      # Human review columns — blank placeholders for annotators
      problem_humanidentified = NA_character_,
      solution_humanidentified = NA_character_,
      column_to_adjust = NA_character_,
      correction_value = NA_character_,
      manually_corrected = FALSE
    )
  
  cat(sprintf("✓ unusual_df_pre created: %d rows\n", nrow(unusual_df_pre)))
  
  # ============================================
  # 9. Create equal_time_df_pre
  # ============================================
  # WHAT: Extracts all records with is_equal_time = TRUE. These are records
  #   where adjacent timestamps are identical (bed==sleep and/or awake==getup).
  # WHY: Equal-time records are NOT sent for human review — the pattern is
  #   self-evident and can be auto-resolved. However, we still create this
  #   dataframe for completeness, reporting, and potential downstream use.
  #   The human-review columns are included with NA values purely for format
  #   consistency, since these records never need manual correction.
  # WHAT HAPPENS NEXT: These records do not appear in the review CSVs
  #   (manual_corrections_pre or manual_unusual_pre). They are returned in
  #   the result list for informational purposes.
  
  cat("\n10. Creating equal_time_df_pre...\n")
  
  equal_time_df_pre <- final_stats %>%
    filter(is_equal_time) %>%
    select(
      # Identifier columns
      pid, day_num, row_id,
      
      # Duration columns (if available)
      any_of(c(
        "duration_totalmin_sol_estimate_am",
        "duration_totalmin_waso_estimate_am",
        "duration_totalmin_napstoday_PM"
      )),
      
      # Original reported timestamps + check-for-errors flags
      time_bed_am_hhmm_ampm, time_bed_am_checkforerrors,
      time_sleep_am_hhmm_ampm, time_sleep_am_checkforerrors,
      time_awake_am_hhmm_ampm, time_awake_am_checkforerrors,
      time_getup_am_hhmm_ampm, time_getup_am_checkforerrors,
      
      # Number of WASO episodes
      num_waso_estimate_am,
      
      # Algorithm-corrected timestamps
      !!sym(col_mapping$bed_corrected), !!sym(col_mapping$sleep_corrected), 
      !!sym(col_mapping$awake_corrected), !!sym(col_mapping$getup_corrected),
      
      # Computed differences and equal-time classification details
      bed_sleep_diff_h, sleep_awake_diff_h, awake_getup_diff_h,
      equal_time_type,
      bed_sleep_equal, awake_getup_equal, both_equal
    ) %>%
    mutate(
      # Human review columns (equal time doesn't need human review, but kept for format consistency)
      problem_humanidentified = NA_character_,
      solution_humanidentified = NA_character_,
      column_to_correct = NA_character_,
      correct_value = NA_character_,
      manually_corrected = FALSE
    )
  
  cat(sprintf("✓ equal_time_df_pre created: %d rows\n", nrow(equal_time_df_pre)))
  
  # ============================================
  # 10. Verify classification mutual exclusivity
  # ============================================
  # WHAT: Checks that the sum of all category row counts (error + unusual +
  #   equal_time + normal) equals the total number of input records.
  # WHY: This is a critical data integrity check. If the sum doesn't match,
  #   it means the classification logic has a bug — some records were counted
  #   in multiple categories or fell through all categories. Every input row
  #   must be assigned to exactly one final category.
  # WHAT HAPPENS NEXT: If the counts match, processing continues. If not,
  #   the discrepancy is visible in the console output for debugging.
  
  cat("\n11. Verifying classification mutual exclusivity:\n")
  error_rows <- nrow(error_df_pre)
  unusual_rows <- nrow(unusual_df_pre)
  equal_rows <- nrow(equal_time_df_pre)
  normal_rows <- nrow(final_stats) - error_rows - unusual_rows - equal_rows
  
  cat(sprintf("  error_df_pre: %d rows\n", error_rows))
  cat(sprintf("  unusual_df_pre: %d rows\n", unusual_rows))
  cat(sprintf("  equal_time_df_pre: %d rows\n", equal_rows))
  cat(sprintf("  normal: %d rows\n", normal_rows))
  cat(sprintf("  Total: %d rows (should match original data: %d)\n", 
              error_rows + unusual_rows + equal_rows + normal_rows, nrow(final_stats)))
  
  # ============================================
  # 11. Create manual_corrections_pre (with all required columns in correct order)
  # ============================================
  # WHAT: The primary deliverable for human ERROR reviewers. Takes error_df_pre
  #   and selects/orders columns into a clean CSV-friendly layout. Includes
  #   all original data plus blank annotation columns that reviewers fill in.
  # WHY: This CSV is given to human annotators. The column order is designed
  #   for easy reading: identifiers first, then data, then differences, then
  #   classification, then blank annotation columns at the end (where reviewers
  #   type their decisions). The original (pre-correction) timestamps appear
  #   alongside the algorithm-corrected timestamps so reviewers can compare.
  # WHAT HAPPENS NEXT: This dataframe is currently NOT written to CSV (the
  #   write.csv calls in Section 13 are commented out). It is returned in the
  #   result list.
  
  cat("\n12. Creating manual_corrections_pre...\n")
  
  manual_corrections_pre <- error_df_pre %>%
    select(
      # Identifier columns
      pid, day_num, row_id,
      
      # Duration columns (if available)
      any_of(c(
        "duration_totalmin_sol_estimate_am",
        "duration_totalmin_waso_estimate_am",
        "duration_totalmin_napstoday_PM"
      )),
      
      # Original reported timestamps (raw text from participant)
      time_bed_am_hhmm_ampm, time_sleep_am_hhmm_ampm,
      time_awake_am_hhmm_ampm, time_getup_am_hhmm_ampm,
      
      # Check-for-errors flags for each timestamp
      time_bed_am_checkforerrors, time_sleep_am_checkforerrors,
      time_awake_am_checkforerrors, time_getup_am_checkforerrors,
      
      # Number of WASO episodes
      num_waso_estimate_am,
      
      # Algorithm-corrected timestamps (used in automated checks)
      time_bed_corrected, time_sleep_corrected,
      time_awake_corrected, time_getup_corrected,
      
      # Computed difference values and classification
      bed_sleep_diff_h, sleep_awake_diff_h, awake_getup_diff_h,
      reasonable_temporal_order,
      error_type, corrected, correction_type,
      
      # Human review annotation columns (blank, placed last for easy access)
      problem_humanidentified, solution_humanidentified,
      column_to_correct, correct_value, manually_corrected
    )
  
  cat(sprintf("✓ manual_corrections_pre created: %d rows\n", nrow(manual_corrections_pre)))
  
  # ============================================
  # 12. Create manual_unusual_pre (with all required columns in correct order)
  # ============================================
  # WHAT: The primary deliverable for human UNUSUAL reviewers. Takes
  #   unusual_df_pre and selects/orders columns for the CSV. Similar structure
  #   to manual_corrections_pre but includes suspicious flag columns instead of
  #   error_type/correction fields.
  # WHY: Unusual records require a different review workflow than errors.
  #   Reviewers need to see WHICH condition(s) triggered the flag (e.g.,
  #   sleep_awake_suspicious) so they can focus their attention on the
  #   specific unusual value. The blank annotation columns let them record
  #   whether the value is accurate or needs adjustment.
  # WHAT HAPPENS NEXT: This dataframe is currently NOT written to CSV (the
  #   write.csv calls in Section 13 are commented out). It is returned in the
  #   result list.
  
  cat("\n13. Creating manual_unusual_pre...\n")
  
  manual_unusual_pre <- unusual_df_pre %>%
    select(
      # Identifier columns
      pid, day_num, row_id,
      
      # Duration columns (if available)
      any_of(c(
        "duration_totalmin_sol_estimate_am",
        "duration_totalmin_waso_estimate_am",
        "duration_totalmin_napstoday_PM"
      )),
      
      # Original reported timestamps (raw text from participant)
      time_bed_am_hhmm_ampm, time_sleep_am_hhmm_ampm,
      time_awake_am_hhmm_ampm, time_getup_am_hhmm_ampm,
      
      # Check-for-errors flags for each timestamp
      time_bed_am_checkforerrors, time_sleep_am_checkforerrors,
      time_awake_am_checkforerrors, time_getup_am_checkforerrors,
      
      # Number of WASO episodes
      num_waso_estimate_am,
      
      # Algorithm-corrected timestamps
      time_bed_corrected, time_sleep_corrected,
      time_awake_corrected, time_getup_corrected,
      
      # Computed differences and unusual classification details
      bed_sleep_diff_h, sleep_awake_diff_h, awake_getup_diff_h,
      unusual_type,
      bed_sleep_suspicious, sleep_awake_suspicious, awake_getup_suspicious,
      
      # Human review annotation columns (blank, placed last for easy access)
      problem_humanidentified, solution_humanidentified,
      column_to_adjust, correction_value, manually_corrected
    )
  
  cat(sprintf("✓ manual_unusual_pre created: %d rows\n", nrow(manual_unusual_pre)))
  
  # ============================================
  # 13. Save only the two review files with [NEW] prefix (no timestamp files)
  # ============================================
  # WHAT: Writes the human-review CSV files to disk. Currently the write.csv
  #   calls are commented out — the dataframes are created but not saved.
  #   Only a console note reports what would be saved.
  # WHY: The write.csv calls are disabled, likely because the caller manages
  #   file saving externally or because the user prefers manual control over
  #   when / where files are written. The dataframes are returned via the
  #   function return value for programmatic use.
  
  #cat("\n14. Saving review CSV files with [NEW] prefix...\n")
  
  # Save manual error correction review file with [NEW] prefix
  #write.csv(manual_corrections_pre, "[NEW]manual_error_correction_review.csv", row.names = FALSE)
  #cat(sprintf("  ✓ [NEW]manual_error_correction_review.csv (%d rows)\n", nrow(manual_corrections_pre)))
  
  # Save manual unusual review file with [NEW] prefix
  #write.csv(manual_unusual_pre, "[NEW]manual_unusual_review.csv", row.names = FALSE)
  #cat(sprintf("  ✓ [NEW]manual_unusual_review.csv (%d rows)\n", nrow(manual_unusual_pre)))
  
  # Note about other dataframes (not saved)
  cat("\n  Note: The following dataframes are available in environment but NOT saved to CSV:\n")
  cat(sprintf("    - error_df_pre (%d rows)\n", nrow(error_df_pre)))
  cat(sprintf("    - unusual_df_pre (%d rows)\n", nrow(unusual_df_pre)))
  cat(sprintf("    - equal_time_df_pre (%d rows)\n", nrow(equal_time_df_pre)))
  
  # ============================================
  # 14. Generate summary report
  # ============================================
  # WHAT: Prints a final summary to the console showing the count and percentage
  #   of records in each category (error / unusual / equal_time / normal), plus
  #   the detailed subtype distributions within each category.
  # WHY: This is the "readout" of data quality. The analyst sees at a glance:
  #   - What percentage of data needs human review (error + unusual)
  #   - Which error types are most common (e.g., mostly order errors?)
  #   - Which unusual patterns dominate (e.g., mostly short sleep?)
  #   - How many records are auto-resolved via equal_time
  # WHAT HAPPENS NEXT: The function returns these statistics in an invisible
  #   list so the caller can store/use them programmatically.
  
  cat("\n========================================\n")
  cat("Generation Summary\n")
  cat("========================================\n")
  cat(sprintf("\nError records (error_df_pre): %d rows (%.1f%%)\n", 
              nrow(error_df_pre), nrow(error_df_pre)/nrow(final_stats)*100))
  cat(sprintf("Unusual records (unusual_df_pre): %d rows (%.1f%%)\n", 
              nrow(unusual_df_pre), nrow(unusual_df_pre)/nrow(final_stats)*100))
  cat(sprintf("Equal time records (equal_time_df_pre): %d rows (%.1f%%)\n", 
              nrow(equal_time_df_pre), nrow(equal_time_df_pre)/nrow(final_stats)*100))
  cat(sprintf("Normal records: %d rows (%.1f%%)\n", 
              normal_rows, normal_rows/nrow(final_stats)*100))
  
  cat("\nError type distribution:\n")
  error_type_dist <- error_df_pre %>%
    count(error_type) %>%
    mutate(percentage = n / nrow(error_df_pre) * 100) %>%
    arrange(desc(n))
  print(error_type_dist)
  
  cat("\nUnusual type distribution:\n")
  unusual_type_dist <- unusual_df_pre %>%
    count(unusual_type) %>%
    mutate(percentage = n / nrow(unusual_df_pre) * 100) %>%
    arrange(desc(n))
  print(unusual_type_dist)
  
  cat("\nEqual time type distribution:\n")
  equal_type_dist <- equal_time_df_pre %>%
    count(equal_time_type) %>%
    mutate(percentage = n / nrow(equal_time_df_pre) * 100) %>%
    arrange(desc(n))
  print(equal_type_dist)
  
  cat("\n========================================\n")
  cat("Correction file generation complete!\n")
  cat("========================================\n")
  cat("\nFiles saved:\n")
  cat("  - [NEW]manual_error_correction_review.csv\n")
  cat("  - [NEW]manual_unusual_review.csv\n")
  cat("\nAll other dataframes are available in the R environment.\n")
  
  # Return results — returns the review dataframes and statistics invisibly.
  # manual_corrections_pre and manual_unusual_pre are intentionally excluded
  # from the return value because they are subsets of error_df_pre and
  # unusual_df_pre with reordered columns. The caller can access them via
  # the environment if needed.
  return(invisible(list(
    error_df_pre = error_df_pre,
    unusual_df_pre = unusual_df_pre,
    equal_time_df_pre = equal_time_df_pre,
    error_stats = error_type_dist,
    unusual_stats = unusual_type_dist,
    equal_stats = equal_type_dist,
    final_stats = final_stats
  )))
}

# If script is run directly, display help information
if (interactive()) {
  cat("\n=== generate_correction_files.R ===\n")
  cat("This file defines the generate_correction_files() function\n")
  cat("\nUsage:\n")
  cat("  result <- generate_correction_files(ema_data_release_timecalc)\n")
  cat("\nOutput:\n")
  cat("  - Saves: [NEW]manual_error_correction_review.csv, [NEW]manual_unusual_review.csv\n")
  cat("  - Returns: List with error_df_pre, unusual_df_pre, equal_time_df_pre and statistics\n")
}
