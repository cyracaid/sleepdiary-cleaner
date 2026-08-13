# Internalised error_unusual correction engine (was error_unusual_sleep_time_corrections.R)
#
# 20 mutually-recursive functions copied verbatim during TECH_DEBT item 4.
# list2env(results, .GlobalEnv) / assign / exists / write_csv are PRESERVED:
# sleep_visualization.R and the legacy entry consume those globals.
#
#' @keywords internal
#' @noRd
#' @importFrom dplyr mutate filter select summarise case_when left_join pull distinct between n "%>%"
#' @importFrom tidyr separate complete
#' @importFrom lubridate hours minutes days parse_date_time ymd_hms date hour minute second duration
#' @importFrom stringr str_detect str_replace str_replace_all str_extract_all str_split str_trim str_match
#' @importFrom readr write_csv cols
#' @importFrom rlang sym ":="
#' @importFrom stats update

utils::globalVariables(c(
  "reasonable_unusual_df", "data_with_flags",
  "awake_getup_diff_h", "awake_getup_equal", "awake_getup_suspicious",
  "bed_sleep_diff_h", "bed_sleep_equal", "bed_sleep_suspicious",
  "correction_type", "data_category", "day_num", "duration_calc",
  "duration_calculated_min", "duration_difference_min",
  "duration_from_data_min", "equal_time_type", "error_type", "exclude",
  "has_na", "is_reasonable_unusual", "manually_corrected",
  "mean_duration_diff_min", "order_correct", "pid", "problem_humanidentified",
  "reasonable_sleep_duration", "reasonable_sleep_latency",
  "reasonable_temporal_order", "reasonable_time_in_bed_after_waking", "row_id",
  "sleep_awake_diff_h", "sleep_awake_diff_min", "sleep_awake_suspicious",
  "solution_humanidentified", "time_awake_manual", "time_bed_manual",
  "time_getup_manual", "time_sleep_manual", "unusual_type"
))

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

# Process swap operations (single function, two pattern sets)
process_swap_operations <- function(data, row_idx, solution_text, pattern_set = "case3") {
  
  operations_applied <- FALSE
  solution_lower <- tolower(solution_text)
  
  swap_patterns <- if (pattern_set == "case2") {
    list(
      "bed_sleep" = c("bed-sleep switch", "perform bed-sleep switch", "bed/sleep switch", 
                      "bed-sleep swap", "perform bed-sleep swap"),
      "awake_getup" = c("awake-getup switch", "perform awake-getup switch", "awake/getup switch",
                        "awake-getup swap", "perform awake-getup swap"),
      "sleep_awake" = c("sleep-awake switch", "perform sleep-awake switch", "sleep/awake switch",
                        "sleep-awake swap", "perform sleep-awake swap")
    )
  } else {
    list(
      "bed_sleep" = c("bed-sleep switch", "perform bed-sleep switch", "bed/sleep switch"),
      "awake_getup" = c("awake-getup switch", "perform awake-getup switch", "awake/getup switch"),
      "sleep_awake" = c("sleep-awake switch", "perform sleep-awake switch", "sleep/awake switch")
    )
  }
  
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
# Column mapping helper
# ============================================

# Map "time_*_corrected" column names to their manual counterparts
corrected_to_manual_col <- function(col) {
  switch(col,
    "time_bed_corrected" = "time_bed_manual",
    "time_sleep_corrected" = "time_sleep_manual",
    "time_awake_corrected" = "time_awake_manual",
    "time_getup_corrected" = "time_getup_manual",
    NA_character_
  )
}

# ============================================
# Utility Functions
# ============================================

# Check and mark swap corrections
check_swap_corrections <- function(data, corrections_df) {
  
  cat("  Checking swap operation handling...\n")
  
  if (nrow(corrections_df) == 0 || !("correction_type" %in% names(corrections_df))) {
    cat("    No swap correction records to process\n")
    return(data)
  }
  
  swap_corrections <- corrections_df %>%
    filter(str_detect(tolower(correction_type), "swap"))
  
  for (i in seq_len(nrow(swap_corrections))) {
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
      data[[col]] <- if (col == "data_category") NA_character_ else NA
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
      target_col <- corrected_to_manual_col(col)
      
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
      target_col <- corrected_to_manual_col(col)
      
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
    swap_ops <- process_swap_operations(data, row_idx, solution_text, pattern_set = "case3")
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
      target_col <- corrected_to_manual_col(col)
      
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
      target_col <- corrected_to_manual_col(col)
      
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
    swap_ops <- process_swap_operations(data, row_idx, solution_text, pattern_set = "case3")
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
  swap_ops <- process_swap_operations(data, row_idx, solution_text, pattern_set = "case2")
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
                             (!!sym(bed_corr_col) <= !!sym(sleep_corr_col)) & 
                               (!!sym(sleep_corr_col) <= !!sym(awake_corr_col)) & 
                               (!!sym(awake_corr_col) <= !!sym(getup_corr_col)),
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
                      reasonable_time_in_bed_after_waking & reasonable_sleep_duration) ~ TRUE,
        TRUE ~ FALSE
      ),
      
      sleep_awake_suspicious = ifelse(!has_na, sleep_awake_diff_h < 3 | sleep_awake_diff_h > 15, NA),
      bed_sleep_suspicious = ifelse(!has_na, bed_sleep_diff_h > 3, NA),
      awake_getup_suspicious = ifelse(!has_na, awake_getup_diff_h > 3, NA),
      
      is_unusual = case_when(
        has_na ~ FALSE,
        !has_na & (sleep_awake_suspicious | bed_sleep_suspicious | awake_getup_suspicious) & 
          !is_error & !(bed_sleep_equal | awake_getup_equal) ~ TRUE,
        TRUE ~ FALSE
      ),
      
      data_category = case_when(
        has_na ~ "skipped_na",
        !has_na & is_error ~ "error",
        !has_na & order_correct & (bed_sleep_equal | awake_getup_equal) ~ "equal_time_ok",
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
      
      for (i in seq_len(nrow(reasonable_unusual_records))) {
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
    n_already_handled <- sum(unusual_df_base$row_id %in% reasonable_unusual_records$row_id)
    
    if (n_already_handled > 0) {
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
      cat(sprintf("  Removed %d from unusual_df (left join), %d already excluded by data_category override\n", 
                  before_count - after_count, nrow(reasonable_unusual_records) - n_already_handled))
    } else {
      cat(sprintf("  All %d reasonable unusual records already excluded by data_category override\n", 
                  nrow(reasonable_unusual_records)))
    }
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
      
      for (i in seq_len(nrow(manual_unusual_corrections))) {
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
  
  for (i in seq_len(nrow(corrections_df))) {
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
