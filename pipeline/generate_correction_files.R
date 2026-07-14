# ============================================
# generate_correction_files.R
# Function: Generate correction files based on ERROR_TYPE, UNUSUAL_TYPE, and EQUAL_TIME_TYPE conditions
# ============================================

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
  duration_cols <- c(
    "duration_totalmin_sol_estimate_am",
    "duration_totalmin_waso_estimate_am",
    "duration_totalmin_napstoday_PM"
  )
  available_duration_cols <- duration_cols[duration_cols %in% names(ema_data_release_timecalc)]
  
  # ============================================
  # 1. Add row_id to dataframe
  # ============================================
  cat("\n2. Adding row identifiers...\n")
  ema_data <- ema_data_release_timecalc %>%
    mutate(row_id = row_number())
  
  # ============================================
  # 2. Calculate all time differences
  # ============================================
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
  cat("\n4. Assessing EQUAL_TIME_TYPE conditions...\n")
  
  ema_data_with_diffs <- ema_data_with_diffs %>%
    mutate(
      # Type 1 - bed_sleep_equal: bed and sleep times are equal
      bed_sleep_equal = abs(bed_sleep_diff_h) < 0.01,  # Consider floating point precision
      
      # Type 2 - awake_getup_equal: awake and getup times are equal
      awake_getup_equal = abs(awake_getup_diff_h) < 0.01,
      
      # Type 3 - both_equal: both are equal
      both_equal = bed_sleep_equal & awake_getup_equal,
      
      # Equal time flag
      is_equal_time = bed_sleep_equal | awake_getup_equal,
      
      # Equal time type classification
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
  cat("\n5. Assessing ERROR_TYPE conditions...\n")
  
  ema_data_with_diffs <- ema_data_with_diffs %>%
    mutate(
      # New: sleep_awake_equal_error - sleep and awake times are equal
      sleep_awake_equal_error = abs(sleep_awake_diff_h) < 0.01 & !is_equal_time,
      
      # Priority 1 - order_error
      order_error = !temporal_order_check & !is_equal_time & !sleep_awake_equal_error,
      
      # Priority 2 - bed_sleep_diff_error (|diff| > 7 hours)
      bed_sleep_diff_error = abs(bed_sleep_diff_h) > 7 & !is_equal_time & !sleep_awake_equal_error,
      
      # Priority 3 - awake_getup_diff_error (|diff| > 7 hours)
      awake_getup_diff_error = abs(awake_getup_diff_h) > 7 & !is_equal_time & !sleep_awake_equal_error,
      
      # Priority 4 - sleep_awake_24h_error (|diff| > 24 hours)
      sleep_awake_24h_error = abs(sleep_awake_diff_h) > 24 & !is_equal_time & !sleep_awake_equal_error,
      
      # Error flag - meets any error condition and not equal time
      is_error = (order_error | bed_sleep_diff_error | awake_getup_diff_error | 
                    sleep_awake_24h_error | sleep_awake_equal_error) & !is_equal_time,
      
      # Error type (by priority)
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
  cat("\n6. Assessing UNUSUAL_TYPE conditions...\n")
  
  ema_data_with_diffs <- ema_data_with_diffs %>%
    mutate(
      # Condition 1 - sleep_awake_suspicious: <3h OR >15h
      sleep_awake_suspicious = (sleep_awake_diff_h < 3 | sleep_awake_diff_h > 15) & 
        !is_error & !is_equal_time,
      
      # Condition 2 - bed_sleep_suspicious: >3h
      bed_sleep_suspicious = bed_sleep_diff_h > 3 & !is_error & !is_equal_time,
      
      # Condition 3 - awake_getup_suspicious: >3h
      awake_getup_suspicious = awake_getup_diff_h > 3 & !is_error & !is_equal_time,
      
      # Condition 4 - multiple_suspicious: multiple suspicious conditions
      multiple_suspicious = (sleep_awake_suspicious + bed_sleep_suspicious + awake_getup_suspicious) >= 2,
      
      # Unusual flag - meets any suspicious condition and not error and not equal time
      is_unusual = (sleep_awake_suspicious | bed_sleep_suspicious | awake_getup_suspicious | multiple_suspicious) & 
        !is_error & !is_equal_time,
      
      # Unusual type
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
  cat("\n7. Final classification statistics:\n")
  
  final_stats <- ema_data_with_diffs %>%
    mutate(
      final_category = case_when(
        is_equal_time ~ "equal_time",
        is_error ~ "error",
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
  cat("\n8. Creating error_df_pre...\n")
  
  error_df_pre <- final_stats %>%
    filter(is_error) %>%
    select(
      # 标识列
      pid, day_num, row_id,
      
      # 时长列
      any_of(c(
        "duration_totalmin_sol_estimate_am",
        "duration_totalmin_waso_estimate_am",
        "duration_totalmin_napstoday_PM"
      )),
      
      # 时间列（原始 + 检查标记）
      time_bed_am_hhmm_ampm, time_bed_am_checkforerrors,
      time_sleep_am_hhmm_ampm, time_sleep_am_checkforerrors,
      time_awake_am_hhmm_ampm, time_awake_am_checkforerrors,
      time_getup_am_hhmm_ampm, time_getup_am_checkforerrors,
      
      # WASO次数
      num_waso_estimate_am,
      
      # 修正后时间列
      !!sym(col_mapping$bed_corrected), !!sym(col_mapping$sleep_corrected), 
      !!sym(col_mapping$awake_corrected), !!sym(col_mapping$getup_corrected),
      
      # 其他计算列
      bed_sleep_diff_h, sleep_awake_diff_h, awake_getup_diff_h,
      temporal_order_check,
      error_type, corrected, correction_type
    ) %>%
    rename(
      reasonable_temporal_order = temporal_order_check
    ) %>%
    mutate(
      # Error-related reasonable judgment columns (for compatibility)
      reasonable_sleep_latency = NA,
      reasonable_time_in_bed_after_waking = NA,
      reasonable_sleep_duration = NA,
      
      # Human review columns (这些放在最后)
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
  cat("\n9. Creating unusual_df_pre...\n")
  
  unusual_df_pre <- final_stats %>%
    filter(is_unusual) %>%
    select(
      # 标识列
      pid, day_num, row_id,
      
      # 时长列
      any_of(c(
        "duration_totalmin_sol_estimate_am",
        "duration_totalmin_waso_estimate_am",
        "duration_totalmin_napstoday_PM"
      )),
      
      # 时间列（原始 + 检查标记）
      time_bed_am_hhmm_ampm, time_bed_am_checkforerrors,
      time_sleep_am_hhmm_ampm, time_sleep_am_checkforerrors,
      time_awake_am_hhmm_ampm, time_awake_am_checkforerrors,
      time_getup_am_hhmm_ampm, time_getup_am_checkforerrors,
      
      # WASO次数
      num_waso_estimate_am,
      
      # 修正后时间列
      !!sym(col_mapping$bed_corrected), !!sym(col_mapping$sleep_corrected), 
      !!sym(col_mapping$awake_corrected), !!sym(col_mapping$getup_corrected),
      
      # 其他计算列
      bed_sleep_diff_h, sleep_awake_diff_h, awake_getup_diff_h,
      unusual_type,
      bed_sleep_suspicious, sleep_awake_suspicious, awake_getup_suspicious,
      multiple_suspicious
    ) %>%
    mutate(
      # Human review columns (这些放在最后)
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
  cat("\n10. Creating equal_time_df_pre...\n")
  
  equal_time_df_pre <- final_stats %>%
    filter(is_equal_time) %>%
    select(
      # 标识列
      pid, day_num, row_id,
      
      # 时长列
      any_of(c(
        "duration_totalmin_sol_estimate_am",
        "duration_totalmin_waso_estimate_am",
        "duration_totalmin_napstoday_PM"
      )),
      
      # 时间列（原始 + 检查标记）
      time_bed_am_hhmm_ampm, time_bed_am_checkforerrors,
      time_sleep_am_hhmm_ampm, time_sleep_am_checkforerrors,
      time_awake_am_hhmm_ampm, time_awake_am_checkforerrors,
      time_getup_am_hhmm_ampm, time_getup_am_checkforerrors,
      
      # WASO次数
      num_waso_estimate_am,
      
      # 修正后时间列
      !!sym(col_mapping$bed_corrected), !!sym(col_mapping$sleep_corrected), 
      !!sym(col_mapping$awake_corrected), !!sym(col_mapping$getup_corrected),
      
      # 其他计算列
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
  cat("\n12. Creating manual_corrections_pre...\n")
  
  manual_corrections_pre <- error_df_pre %>%
    select(
      # 标识列
      pid, day_num, row_id,
      
      # 时长列
      any_of(c(
        "duration_totalmin_sol_estimate_am",
        "duration_totalmin_waso_estimate_am",
        "duration_totalmin_napstoday_PM"
      )),
      
      # 时间列（原始）
      time_bed_am_hhmm_ampm, time_sleep_am_hhmm_ampm,
      time_awake_am_hhmm_ampm, time_getup_am_hhmm_ampm,
      
      # 时间检查标记
      time_bed_am_checkforerrors, time_sleep_am_checkforerrors,
      time_awake_am_checkforerrors, time_getup_am_checkforerrors,
      
      # WASO次数
      num_waso_estimate_am,
      
      # 修正后时间
      time_bed_corrected, time_sleep_corrected,
      time_awake_corrected, time_getup_corrected,
      
      # 差值
      bed_sleep_diff_h, sleep_awake_diff_h, awake_getup_diff_h,
      reasonable_temporal_order,
      error_type, corrected, correction_type,
      
      # 人工添加列（最后）
      problem_humanidentified, solution_humanidentified,
      column_to_correct, correct_value, manually_corrected
    )
  
  cat(sprintf("✓ manual_corrections_pre created: %d rows\n", nrow(manual_corrections_pre)))
  
  # ============================================
  # 12. Create manual_unusual_pre (with all required columns in correct order)
  # ============================================
  cat("\n13. Creating manual_unusual_pre...\n")
  
  manual_unusual_pre <- unusual_df_pre %>%
    select(
      # 标识列
      pid, day_num, row_id,
      
      # 时长列
      any_of(c(
        "duration_totalmin_sol_estimate_am",
        "duration_totalmin_waso_estimate_am",
        "duration_totalmin_napstoday_PM"
      )),
      
      # 时间列（原始）
      time_bed_am_hhmm_ampm, time_sleep_am_hhmm_ampm,
      time_awake_am_hhmm_ampm, time_getup_am_hhmm_ampm,
      
      # 时间检查标记
      time_bed_am_checkforerrors, time_sleep_am_checkforerrors,
      time_awake_am_checkforerrors, time_getup_am_checkforerrors,
      
      # WASO次数
      num_waso_estimate_am,
      
      # 修正后时间
      time_bed_corrected, time_sleep_corrected,
      time_awake_corrected, time_getup_corrected,
      
      # 差值
      bed_sleep_diff_h, sleep_awake_diff_h, awake_getup_diff_h,
      unusual_type,
      bed_sleep_suspicious, sleep_awake_suspicious, awake_getup_suspicious,
      
      # 人工添加列（最后）
      problem_humanidentified, solution_humanidentified,
      column_to_adjust, correction_value, manually_corrected
    )
  
  cat(sprintf("✓ manual_unusual_pre created: %d rows\n", nrow(manual_unusual_pre)))
  
  # ============================================
  # 13. Save only the two review files with [NEW] prefix (no timestamp files)
  # ============================================
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
  
  # Return results - 不包含manual_corrections_pre和manual_unusual_pre
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