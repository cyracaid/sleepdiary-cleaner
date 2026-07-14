# ============================================================================
# SLEEP DATA ANALYSIS - COMPLETE COMBINED VERSION
# ============================================================================
# 
# DATA SOURCE HIERARCHY:
# ============================================================================
# Figures 1-12:  Based on `corrected_ema_data` (post-correction final data)
#                Uses: data_category, manually_corrected, sleep metrics
#                Shows: Final classification after all corrections applied
#
# Figures 13-18: Based on `review_output` from checkforerrors_processing.R (auto-detection)
#                Uses: checkforerrors_df from algorithm detection
#                Shows: Potential issues needing human review
#
# Figure 1:      Final data quality dashboard (corrected data)
# Figure 18:     Auto-detected issues dashboard (raw algorithm output)
# ============================================================================
# OVERVIEW
# ============================================================================
# Data sources:
#   - Figures 1-12: corrected_ema_data (post-correction final data)
#   - Figures 13-18: checkforerrors_processed (pre-correction auto-detection flags)
#   - Figures 19-24: checkforerrors_summary + corrected_ema_data
# 
# File output: All figures saved as PNG files in the working directory
# 
# Color scheme:
#   - Orange-red (#D32F2F, #FF8C00): flagged/problematic data
#   - Blue-gray (#2E7D32, #1976D2): clean/acceptable data
# ============================================================================

# Load required libraries
library(ggplot2)
library(dplyr)
library(tidyr)
library(patchwork)
library(lubridate)
library(scales)
library(RColorBrewer)
library(gridExtra)

# Set global theme
theme_set(theme_minimal(base_size = 14))

# Config: use defaults if not running inside run_pipeline()
if (!exists("pipeline_config")) { pipeline_config <- list() }

# ============================================================================
# AUTO-SAVE SETUP
# ============================================================================
output_dir <- paste0("sleep_visualization_", format(Sys.time(), "%Y%m%d_%H%M"))
dir.create(output_dir, showWarnings = FALSE)
cat(sprintf("\nFigures auto-saving to: %s/\n", output_dir))
save_png <- function(plot, name, w = 14, h = 9, subdir = NULL) {
  ggsave(file.path(output_dir, paste0(name, ".png")), plot, width = w, height = h, dpi = 150, limitsize = FALSE)
  if (!is.null(subdir)) {
    sub_path <- file.path(output_dir, subdir, paste0(name, ".png"))
    dir.create(dirname(sub_path), showWarnings = FALSE, recursive = TRUE)
    ggsave(sub_path, plot, width = w, height = h, dpi = 150, limitsize = FALSE)
  }
}

# ============================================================================
# FUNCTION: apply_sleep_metrics (local helper for classified subsets)
# ============================================================================
# Purpose: Calculate derived sleep metrics from corrected timestamps
# Input: Dataframe with time_bed_corrected, time_sleep_corrected, etc.
# Output: Dataframe with added sleep metrics (sol, tst, se, etc.)
# ============================================================================
apply_sleep_metrics <- function(data) {
  
  data_name <- deparse(substitute(data))
  cat(sprintf("\n=== Calculating sleep time variables for: %s ===\n", data_name))
  
  required_cols <- c(
    "time_bed_corrected",
    "time_sleep_corrected", 
    "time_awake_corrected",
    "time_getup_corrected",
    "num_waso_estimate_am",
    "duration_totalmin_sol_estimate_am_mincalc",
    "duration_totalmin_waso_estimate_am_mincalc"
  )
  
  missing_cols <- setdiff(required_cols, names(data))
  
  if (length(missing_cols) > 0) {
    stop(sprintf("\n❌ Missing required columns in %s: %s", data_name, paste(missing_cols, collapse = ", ")))
  }
  
  cat(sprintf("\n✓ All required columns found in %s\n", data_name))

  if (!"duration_totalmin_waso_estimate_am_checkforerrors" %in% names(data)) {
    data$duration_totalmin_waso_estimate_am_checkforerrors <- FALSE
  }
  if (!"duration_totalmin_sol_estimate_am_checkforerrors" %in% names(data)) {
    data$duration_totalmin_sol_estimate_am_checkforerrors <- FALSE
  }
  
  cleaned_data <- data %>%
    mutate(self_diffcalc_sol_minutes = as.numeric(difftime(time_sleep_corrected, time_bed_corrected, units = "mins"))) %>%
    mutate(self_diffcalc_sleeponset = time_sleep_corrected) %>%
    mutate(self_diffcalc_totaltrysleep_minutes = as.numeric(difftime(time_awake_corrected, time_sleep_corrected, units = "mins"))) %>%
    mutate(
      sol_duration_for_review_status = case_when(
        is.na(duration_totalmin_sol_estimate_am_mincalc) ~ "missing",
        duration_totalmin_sol_estimate_am_checkforerrors %in% TRUE ~ "untrusted_interval_flag",
        !is.na(self_diffcalc_totaltrysleep_minutes) & self_diffcalc_totaltrysleep_minutes >= 0 &
          duration_totalmin_sol_estimate_am_mincalc > self_diffcalc_totaltrysleep_minutes ~ "untrusted_exceeds_sleep_to_awake_window",
        duration_totalmin_sol_estimate_am_mincalc < 0 ~ "untrusted_negative",
        TRUE ~ "available_for_review"
      ),
      duration_totalmin_sol_estimate_am_mincalc_for_review = if_else(
        sol_duration_for_review_status == "available_for_review",
        as.numeric(duration_totalmin_sol_estimate_am_mincalc),
        NA_real_
      )
    ) %>%
    mutate(self_diffcalc_timeinbed_minutes = as.numeric(difftime(time_getup_corrected, time_bed_corrected, units = "mins"))) %>%
    mutate(self_diffcalc_sleepperiod_minutes = as.numeric(difftime(time_awake_corrected, self_diffcalc_sleeponset, units = "mins"))) %>%
    mutate(
      waso_duration_for_metrics_status = case_when(
        is.na(duration_totalmin_waso_estimate_am_mincalc) ~ "missing",
        duration_totalmin_waso_estimate_am_checkforerrors %in% TRUE ~ "untrusted_interval_flag",
        !is.na(self_diffcalc_sleepperiod_minutes) &
          duration_totalmin_waso_estimate_am_mincalc > self_diffcalc_sleepperiod_minutes ~ "untrusted_exceeds_sleep_period",
        duration_totalmin_waso_estimate_am_mincalc < 0 ~ "untrusted_negative",
        TRUE ~ "used"
      ),
      duration_totalmin_waso_estimate_am_mincalc_used = if_else(
        waso_duration_for_metrics_status == "used",
        as.numeric(duration_totalmin_waso_estimate_am_mincalc),
        NA_real_
      )
    ) %>%
    mutate(self_diffcalc_totalsleeptime_minutes = self_diffcalc_sleepperiod_minutes - duration_totalmin_waso_estimate_am_mincalc_used) %>%
    mutate(self_diffcalc_sleepefficiency_percent = self_diffcalc_totalsleeptime_minutes / self_diffcalc_totaltrysleep_minutes) %>%
    mutate(num_waso_estimate_am = as.numeric(num_waso_estimate_am)) %>%
    mutate(avg_waso_estimate_am_minutes = if_else(
      !is.na(duration_totalmin_waso_estimate_am_mincalc_used) &
        !is.na(num_waso_estimate_am) & num_waso_estimate_am > 0,
      duration_totalmin_waso_estimate_am_mincalc_used / num_waso_estimate_am,
      NA_real_
    ))
  
  return(cleaned_data)
}

# ============================================================================
# FUNCTION: Add Data Quality Flags (for additional quality assessment)
# ============================================================================
# Purpose: Add flag columns for data quality assessment
# Input: Dataframe with sleep_duration_h, sol_h, waso_h, sleep_efficiency_pct
# Output: Dataframe with added flag columns
# ============================================================================
add_quality_flags <- function(data) {
  
  if(!"sleep_duration_h" %in% names(data)) {
    warning("sleep_duration_h not found, skipping flags")
    return(data)
  }
  
  data <- data %>%
    mutate(
      flag_duration_extreme = case_when(
        sleep_duration_h < 3 ~ "Too short (<3h)",
        sleep_duration_h > 12 ~ "Too long (>12h)",
        TRUE ~ "Normal range"
      ),
      
      flag_poor_efficiency = ifelse(!is.na(sleep_efficiency_pct),
        sleep_efficiency_pct < cfg_get("classification.flag_severity.poor_efficiency_threshold_pct", 70), FALSE),
      flag_high_sol = ifelse(!is.na(sol_h),
        sol_h > cfg_get("classification.flag_severity.high_sol_threshold_hours", 1), FALSE),
      flag_high_waso = ifelse(!is.na(waso_h),
        waso_h > cfg_get("classification.flag_severity.high_waso_threshold_hours", 1.5), FALSE),
      
      flag_issue_count = (flag_poor_efficiency + flag_high_sol + flag_high_waso),
      flag_severity = case_when(
        flag_issue_count == 0 ~ "Clean",
        flag_issue_count == 1 ~ "Minor issues (1 flag)",
        flag_issue_count >= 2 ~ "Major issues (2+ flags)",
        TRUE ~ "Unknown"
      ),
      
      flag_sleep_calculation_issue = ifelse(
        !is.na(self_diffcalc_sol_minutes) & !is.na(duration_totalmin_sol_estimate_am_mincalc),
        abs(self_diffcalc_sol_minutes - duration_totalmin_sol_estimate_am_mincalc) > 30,
        FALSE
      )
    )
  
  return(data)
}

# ============================================================================
# STEP 1: DATA PREPARATION
# ============================================================================
# NOTE: Figures 1-12 use `corrected_ema_data` (final corrected data, post-correction)
#       Figures 13-18 use `checkforerrors_df` from checkforerrors_processing.R (auto-detection, pre-correction)
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\nSTEP 1: DATA PREPARATION\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\n")

# Check if ema_data_release_timecalc exists
if(!exists("ema_data_release_timecalc")) {
  stop("❌ ema_data_release_timecalc not found! Please load your data first.")
}

# Create clean_df from ema_data_release_timecalc
clean_df <- ema_data_release_timecalc
cat(sprintf("\n✓ clean_df created with %d rows\n", nrow(clean_df)))

# Required duration columns for sleep metrics. Do not synthesize missing
# durations as zero; that would turn unknown input into false sleep facts.
missing_cols_list <- c(
  "num_waso_estimate_am",
  "duration_totalmin_sol_estimate_am_mincalc",
  "duration_totalmin_waso_estimate_am_mincalc"
)

has_sleep_duration_inputs <- function(df, df_name, required = FALSE) {
  missing <- setdiff(missing_cols_list, names(df))
  if(length(missing) > 0) {
    msg <- sprintf(
      "Missing required sleep duration columns in %s: %s. Refusing to fill unknown durations with zero.",
      df_name,
      paste(missing, collapse = ", ")
    )
    if(required) {
      stop(msg)
    }
    cat(sprintf("  ⚠ %s Skipping sleep metric recalculation for %s.\n", msg, df_name))
    return(FALSE)
  }
  TRUE
}

cat("\nChecking clean_df for required columns:\n")
has_sleep_duration_inputs(clean_df, "clean_df", required = TRUE)

cat("\nCalculating sleep variables for clean_df:\n")
clean_df <- apply_sleep_metrics(clean_df)

# Process unusual_df if it exists (from error_unusual_sleep_time_corrections.R)
if(exists("unusual_df") && is.data.frame(unusual_df) && nrow(unusual_df) > 0) {
  cat("\nProcessing unusual_df:\n")
  if(has_sleep_duration_inputs(unusual_df, "unusual_df")) {
    unusual_df <- apply_sleep_metrics(unusual_df)
  }
} else {
  cat("\n⚠ unusual_df not found or empty\n")
  unusual_df <- data.frame()
}

# Process error_df if it exists (from error_unusual_sleep_time_corrections.R)
if(exists("error_df") && is.data.frame(error_df) && nrow(error_df) > 0) {
  cat("\nProcessing error_df:\n")
  if(has_sleep_duration_inputs(error_df, "error_df")) {
    error_df <- apply_sleep_metrics(error_df)
  }
} else {
  cat("\n⚠ error_df not found or empty\n")
  error_df <- data.frame()
}

# ============================================================================
# STEP 2: CONVERT MINUTES TO HOURS
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\nSTEP 2: CONVERTING MINUTES TO HOURS\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\n")

clean_df <- clean_df %>%
  mutate(
    sleep_duration_h = self_diffcalc_totalsleeptime_minutes / 60,
    time_in_bed_h = self_diffcalc_timeinbed_minutes / 60,
    sol_h = self_diffcalc_sol_minutes / 60,
    waso_h = duration_totalmin_waso_estimate_am_mincalc_used / 60,
    sleep_efficiency_pct = self_diffcalc_sleepefficiency_percent * 100
  )
cat("✓ clean_df converted\n")

if(nrow(unusual_df) > 0 && "self_diffcalc_totalsleeptime_minutes" %in% names(unusual_df)) {
  unusual_df <- unusual_df %>%
    mutate(
      sleep_duration_h = self_diffcalc_totalsleeptime_minutes / 60,
      time_in_bed_h = self_diffcalc_timeinbed_minutes / 60,
      sol_h = self_diffcalc_sol_minutes / 60,
      waso_h = duration_totalmin_waso_estimate_am_mincalc_used / 60,
      sleep_efficiency_pct = self_diffcalc_sleepefficiency_percent * 100
    )
  cat("✓ unusual_df converted\n")
}

if(nrow(error_df) > 0 && "self_diffcalc_totalsleeptime_minutes" %in% names(error_df)) {
  error_df <- error_df %>%
    mutate(
      sleep_duration_h = self_diffcalc_totalsleeptime_minutes / 60,
      time_in_bed_h = self_diffcalc_timeinbed_minutes / 60,
      sol_h = self_diffcalc_sol_minutes / 60,
      waso_h = duration_totalmin_waso_estimate_am_mincalc_used / 60,
      sleep_efficiency_pct = self_diffcalc_sleepefficiency_percent * 100
    )
  cat("✓ error_df converted\n")
}

# ============================================================================
# STEP 3: APPLY QUALITY FLAGS
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\nSTEP 3: APPLYING DATA QUALITY FLAGS\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\n")

if(exists("clean_df") && nrow(clean_df) > 0) {
  clean_df <- add_quality_flags(clean_df)
  cat("\n✓ Quality flags added to clean_df\n")
}

# ============================================================================
# STEP 4: GET CHECKFORERRORS OUTPUT (Auto-detection)
# ============================================================================
cat("\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\nSTEP 4: PREPARING CHECKFORERRORS DATA (Auto-detection)\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\n")

# Initialize checkforerrors_df as NULL
checkforerrors_df <- NULL

# Check if review_output already exists (from checkforerrors_processing.R)
if (exists("review_output") && is.list(review_output) && 
    "checkforerrors_df" %in% names(review_output)) {
  cat("\n✓ Using existing review_output from checkforerrors_processing.R\n")
  checkforerrors_df <- review_output$checkforerrors_df
  data_with_flags <- review_output$data_with_flags  # optional, not used later
} else if (exists("generate_review_flags")) {
  # Fallback: run generate_review_flags if function exists
  cat("\n⚠ review_output not found, but generate_review_flags exists. Running it...\n")
  review_output <- generate_review_flags(ema_data_release_timecalc)
  if (!is.null(review_output) && is.list(review_output) && 
      "checkforerrors_df" %in% names(review_output)) {
    checkforerrors_df <- review_output$checkforerrors_df
  }
} else {
  cat("\n⚠ Neither review_output nor generate_review_flags found.\n")
  cat("  Please run checkforerrors_processing.R first.\n")
  checkforerrors_df <- data.frame()
}

# Now check if checkforerrors_df is valid
checkforerrors_exists <- FALSE
if (is.data.frame(checkforerrors_df) && nrow(checkforerrors_df) > 0) {
  checkforerrors_exists <- TRUE
  cat(sprintf("\n✓ checkforerrors_df has %d rows\n", nrow(checkforerrors_df)))
} else {
  cat("\n⚠ checkforerrors_df is empty or not available.\n")
}

# ============================================================================
# STEP 5: PROCESS CHECKFORERRORS DATA FOR VISUALIZATION
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\nSTEP 5: PROCESSING CHECKFORERRORS DATA\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\n")

# Properly check if checkforerrors_df exists AND is a valid data frame
checkforerrors_exists <- FALSE

if (exists("checkforerrors_df")) {
  if (is.data.frame(checkforerrors_df)) {
    if (nrow(checkforerrors_df) > 0) {
      checkforerrors_exists <- TRUE
      cat(sprintf("\n✓ checkforerrors_df found with %d rows\n", nrow(checkforerrors_df)))
    } else {
      cat("\n⚠ checkforerrors_df exists but has 0 rows\n")
    }
  } else {
    cat("\n⚠ checkforerrors_df exists but is not a data frame\n")
  }
} else {
  cat("\n⚠ checkforerrors_df not found in environment\n")
}

# Initialize data frames as empty
checkforerrors_processed <- data.frame()

if (checkforerrors_exists) {
  
  # Merge with clean_df to get sleep metrics (only calculated metrics, not time columns)
  if(all(c("pid", "day_num") %in% names(clean_df)) && 
     all(c("pid", "day_num") %in% names(checkforerrors_df))) {
    
    cat("\n✓ Merging checkforerrors_df with clean_df to get sleep metrics...\n")
    cat("  (Only selecting calculated metrics, preserving original time columns)\n")
    
    metrics_cols <- c("pid", "day_num", "row_id", "sleep_duration_h", "time_in_bed_h", 
                      "sol_h", "waso_h", "sleep_efficiency_pct", "flag_severity")
    
    existing_metrics <- metrics_cols[metrics_cols %in% names(clean_df)]
    
    if(length(existing_metrics) > 1) {
      join_cols <- intersect(c("pid", "day_num", "row_id"), names(checkforerrors_df))
      checkforerrors_processed <- checkforerrors_df %>%
        left_join(
          clean_df %>% select(all_of(existing_metrics)),
          by = join_cols
        )
      cat(sprintf("  ✓ Merged %d metrics columns (join by: %s)\n", 
                  length(existing_metrics) - 2, paste(join_cols, collapse=", ")))
    } else {
      cat("  ⚠ No metrics columns found in clean_df, using checkforerrors_df as is\n")
      checkforerrors_processed <- checkforerrors_df
    }
    
  } else {
    cat("\n⚠ Cannot merge - missing pid/day_num columns. Using checkforerrors_df as is.\n")
    checkforerrors_processed <- checkforerrors_df
  }
  
  # Parse error descriptions into categories
  if("auto_error_desc" %in% names(checkforerrors_processed)) {
    
    checkforerrors_processed <- checkforerrors_processed %>%
      mutate(
        error_category = case_when(
          grepl("Interval format error", auto_error_desc, ignore.case = TRUE) ~ "Interval Format Error",
          grepl("order error", auto_error_desc, ignore.case = TRUE) ~ "Time Order Error",
          grepl("sleep latency.*[0-9]+h", auto_error_desc, ignore.case = TRUE) ~ "Sleep Latency Issue",
          grepl("WASO", auto_error_desc, ignore.case = TRUE) ~ "WASO Issue",
          grepl("duration >24h", auto_error_desc, ignore.case = TRUE) ~ "Duration >24 Hours",
          grepl("Unusual pattern", auto_error_desc, ignore.case = TRUE) ~ "Unusual Sleep Pattern",
          grepl("Error detected", auto_error_desc, ignore.case = TRUE) ~ "General Error",
          TRUE ~ "Other Issue"
        )
      )
    
    cat("\n✓ Processed checkforerrors data with", nrow(checkforerrors_processed), "rows\n")
    cat("  Error categories found:\n")
    error_table <- table(checkforerrors_processed$error_category)
    print(error_table)
    
    if("sleep_duration_h" %in% names(checkforerrors_processed)) {
      cat("\n  Sleep duration data available in", 
          sum(!is.na(checkforerrors_processed$sleep_duration_h)), 
          "out of", nrow(checkforerrors_processed), "rows\n")
    }
    
  } else {
    cat("\n⚠ 'auto_error_desc' column not found in checkforerrors_df\n")
    if(!"error_category" %in% names(checkforerrors_processed)) {
      checkforerrors_processed$error_category <- "Other Issue"
    }
  }
  
} else {
  cat("\n⚠ No checkforerrors data available - skipping checkforerrors visualizations\n")
}

# ============================================================================
# STEP 6: GENERATE FIGURES 1-12 (Based on corrected_ema_data)
# ============================================================================
# NOTE: These figures show the FINAL corrected data after all manual corrections
#       Source: corrected_ema_data from apply_manual_corrections_and_recalculate()
#       What they show: Sleep metrics and classifications in the final dataset
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\nSTEP 6: GENERATING FIGURES 1-12 (Final Corrected Data)\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\n\n")

# ----------------------------------------------------------------------------
# Figure 1: Final Data Quality Dashboard (Post-Correction)
# ----------------------------------------------------------------------------
# DATA SOURCE: corrected_ema_data (final dataset after all corrections)
# KEY COLUMNS: data_category, manually_corrected
# WHAT IT SHOWS: Final distribution of records after applying manual corrections
#                - Manually Corrected: Records fixed by human review
#                - Error (Needs Review): Records with errors not yet corrected
#                - Unusual (Acceptable): Unusual but valid patterns
#                - Clean: Records passing all quality checks
#                - Equal Time: Auto-accepted zero-difference records
#                - Missing Data: Records with NA values
# ============================================================================
# WHAT THIS FIGURE SHOWS:
# A two-panel dashboard of final data classification. Left panel: key metrics
# (total records, corrections made, errors still pending). Right panel: pie
# chart of all records broken into Clean, Manually Corrected, Error, Unusual,
# and other categories.
#
# INTERPRETATION:
# Most records should be Clean. A high percentage of Manually Corrected or
# Error records suggests systematic issues in data collection or entry. The
# "Needs Review" count should decrease as corrections are applied over time.
# ============================================================================
cat("Generating Figure 1...\n")

if(all(c("data_category", "manually_corrected") %in% names(corrected_ema_data))) {
  
  final_classification <- corrected_ema_data %>%
    mutate(
      final_category = case_when(
        manually_corrected == TRUE ~ "Manually Corrected",
        data_category == "clean" ~ "Cleaned by Algorithm",
        data_category == "unusual" ~ "Unusual (Acceptable)",
        data_category == "error" ~ "Error (Needs Review)",
        data_category == "equal_time_ok" ~ "Equal Time (Auto-accepted)",
        data_category == "reasonable_unusual" ~ "Reasonable Unusual",
        data_category == "skipped_na" ~ "Missing Data",
        TRUE ~ "Other"
      )
    ) %>%
    group_by(final_category) %>%
    summarise(count = n(), .groups = "drop") %>%
    mutate(
      percentage = count / sum(count) * 100,
      final_category = factor(final_category, 
                              levels = c("Manually Corrected", "Error (Needs Review)", 
                                         "Unusual (Acceptable)", "Clean", 
                                         "Equal Time (Auto-accepted)", 
                                         "Reasonable Unusual", "Missing Data", "Other"))
    )
  
  total_records <- nrow(corrected_ema_data)
  corrected_count <- sum(corrected_ema_data$manually_corrected, na.rm = TRUE)
  needs_review_count <- sum(corrected_ema_data$data_category == "error" & 
                              !corrected_ema_data$manually_corrected, na.rm = TRUE)
  
  summary_stats <- data.frame(
    metric = c("Total Records", "Manually Corrected", "Needs Review (Error)"),
    value = c(format(total_records, big.mark=","),
              sprintf("%d (%.1f%%)", corrected_count, corrected_count/total_records*100),
              sprintf("%d (%.1f%%)", needs_review_count, needs_review_count/total_records*100))
  )
  
  p1_left <- ggplot(summary_stats, aes(x = metric, y = 1, label = value)) +
    geom_text(size = 6, fontface = "bold") +
    labs(title = "Key Metrics") +
    theme_void() +
    theme(plot.title = element_text(hjust = 0.5, size = 11, face = "bold"))
  
  p1_right <- ggplot(final_classification, aes(x = "", y = percentage, fill = final_category)) +
    geom_bar(stat = "identity", width = 1, alpha = 0.85) +
    coord_polar("y", start = 0) +
    geom_text(aes(label = sprintf("%s\n%.1f%%", count, percentage)), 
              position = position_stack(vjust = 0.5), size = 3) +
    scale_fill_manual(
      values = c("Manually Corrected" = "#4CAF50",
                 "Error (Needs Review)" = "#D32F2F",
                 "Unusual (Acceptable)" = "#FF8C00", 
                 "Clean" = "#2E7D32",
                 "Equal Time (Auto-accepted)" = "#64B5F6",
                 "Reasonable Unusual" = "#AB47BC",
                 "Missing Data" = "#9E9E9E",
                 "Other" = "#757575"),
      name = "Category"
    ) +
    labs(title = "Final Data Classification") +
    theme_void() +
    theme(plot.title = element_text(hjust = 0.5, size = 11, face = "bold"),
          legend.position = "right",
          legend.text = element_text(size = 8))
  
  p1 <- (p1_left | p1_right) + 
    plot_layout(widths = c(0.4, 0.6)) +
    plot_annotation(
      title = "Figure 1: Final Data Quality Dashboard (Post-Correction)",
      subtitle = sprintf("Pipeline Step 9 output: records classified by data_category after timestamp/duration corrections | Flagged for review: %d (%.1f%%)", 
                         needs_review_count, needs_review_count/total_records*100),
      theme = theme(plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
                    plot.subtitle = element_text(hjust = 0.5, size = 10))
    )
  
  print(p1)
  save_png(p1, "01_Final_Data_Quality_Dashboard", subdir = "pipeline_cleaning")
  cat("✓ Figure 1 completed (using corrected_ema_data$data_category and manually_corrected)\n\n")
  
  cat("\n--- Final Classification Details (Figure 1) ---\n")
  print(final_classification)
  
} else {
  cat("⚠ Missing required columns: data_category or manually_corrected\n")
}

# ----------------------------------------------------------------------------
# Figure 2: Distribution of Sleep Variables
# ----------------------------------------------------------------------------
# DATA SOURCE: clean_df (subset of corrected_ema_data without NAs)
# WHAT IT SHOWS: Histograms and density curves for key sleep metrics
#                - Sleep Duration (hours)
#                - Time in Bed (hours)
#                - WASO (hours)
#                - SOL (hours)
#                - Sleep Efficiency (%)
# ============================================================================
# WHAT THIS FIGURE SHOWS:
# Histograms with overlaid density curves for five key sleep metrics: sleep
# duration, time in bed, WASO, sleep onset latency, and sleep efficiency.
#
# INTERPRETATION:
# Each metric should follow a roughly bell-shaped distribution within clinically
# expected ranges. Bimodal or extremely skewed distributions may indicate
# subpopulations with different sleep patterns or data quality issues. Long
# tails in WASO or SOL suggest problematic records worth investigating.
# ============================================================================
cat("Generating Figure 2...\n")

vars_to_plot <- c()
if("sleep_duration_h" %in% names(clean_df)) vars_to_plot <- c(vars_to_plot, sleep_duration = "sleep_duration_h")
if("time_in_bed_h" %in% names(clean_df)) vars_to_plot <- c(vars_to_plot, time_in_bed = "time_in_bed_h")
if("waso_h" %in% names(clean_df)) vars_to_plot <- c(vars_to_plot, WASO = "waso_h")
if("sol_h" %in% names(clean_df)) vars_to_plot <- c(vars_to_plot, SOL = "sol_h")
if("sleep_efficiency_pct" %in% names(clean_df)) vars_to_plot <- c(vars_to_plot, sleep_efficiency = "sleep_efficiency_pct")

if(length(vars_to_plot) > 0) {
  # Wide → long: reshape 5 sleep metrics into key-value pairs for faceted plotting
  long_df <- clean_df %>%
    select(all_of(vars_to_plot)) %>%
    pivot_longer(cols = everything(), names_to = "variable", values_to = "value") %>%
    filter(!is.na(value))
  
  p2 <- ggplot(long_df, aes(x = value)) +
    geom_histogram(aes(y = after_stat(density)), bins = 40, fill = "#2E7D32", alpha = 0.5) +
    geom_density(color = "#D32F2F", size = 1) +
    facet_wrap(~variable, scales = "free") +
    labs(title = "Figure 2: Distribution of Sleep Variables",
         subtitle = "Histograms with density curves for key sleep metrics (based on final corrected data)",
         x = "Value", y = "Density")
  print(p2)
  save_png(p2, "02_Distribution_Sleep_Variables", subdir = "research_ready")
  cat("✓ Figure 2 completed\n\n")
}

# ----------------------------------------------------------------------------
# Figure 3: Sleep Duration Distribution
# ----------------------------------------------------------------------------
# DATA SOURCE: clean_df
# WHAT IT SHOWS: Distribution of Total Sleep Time (TST) with mean/median lines
#                Mean and median annotated on the plot
# ============================================================================
# WHAT THIS FIGURE SHOWS:
# Distribution of Total Sleep Time (TST) with the mean (blue solid line) and
# median (orange dashed line) annotated.
#
# INTERPRETATION:
# Typical adult sleep duration should center around 7-9 hours. If the mean
# deviates substantially from this range, check for systematic calculation
# errors or an unusual study population. A large gap between mean and median
# indicates skew from extreme values that may need correction.
# ============================================================================
cat("Generating Figure 3...\n")

if("sleep_duration_h" %in% names(clean_df)) {
  p3 <- ggplot(clean_df, aes(x = sleep_duration_h)) +
    geom_histogram(aes(y = after_stat(density)), bins = 40, fill = "#2E7D32", alpha = 0.5) +
    geom_density(color = "#D32F2F", size = 1) +
    geom_vline(aes(xintercept = mean(sleep_duration_h, na.rm = TRUE)), color = "#1976D2", size = 1) +
    geom_vline(aes(xintercept = median(sleep_duration_h, na.rm = TRUE)), color = "#FF8C00", linetype = "dashed", size = 1) +
    labs(title = "Figure 3: Distribution of Total Sleep Time (TST)",
         subtitle = "Enhanced calculation: Sleep period minus WASO (based on final corrected data)",
         x = "Sleep Duration (hours)", y = "Density") +
    annotate("text", x = Inf, y = Inf, 
             label = paste("Mean:", round(mean(clean_df$sleep_duration_h, na.rm = TRUE), 2),
                           "hours\nMedian:", round(median(clean_df$sleep_duration_h, na.rm = TRUE), 2),
                           "hours\nn =", sum(!is.na(clean_df$sleep_duration_h))),
             hjust = 1.1, vjust = 1.5, size = 3.5)
  print(p3)
  save_png(p3, "03_Sleep_Duration_Distribution", subdir = "research_ready")
  cat("✓ Figure 3 completed\n\n")
}

# ----------------------------------------------------------------------------
# Figure 4: Sleep Duration vs Time in Bed (COLOR-CODED BY SEVERITY)
# ----------------------------------------------------------------------------
# DATA SOURCE: clean_df
# WHAT IT SHOWS: Scatter plot of TST vs Time in Bed
#                Color-coded by data quality severity
#                Includes correlation coefficients
# ============================================================================
# WHAT THIS FIGURE SHOWS:
# Scatter plot of Total Sleep Time vs. Time in Bed, color-coded by data quality
# severity. The dashed diagonal line represents perfect agreement
# (TST = TIB); points below it indicate wake time during the sleep period.
#
# INTERPRETATION:
# Healthy records should cluster near the diagonal (TST close to TIB). Points
# far below the line have high WASO or poor sleep efficiency. If most flagged
# records (orange/red) are in a specific region of the plot, this reveals
# systematic bias in how flags are assigned.
# ============================================================================
cat("Generating FIGURE 4 (Sleep Duration vs Time in Bed)...\n")

if(all(c("time_in_bed_h", "sleep_duration_h", "flag_severity") %in% names(clean_df))) {
  
  plot_df_4 <- clean_df %>% 
    filter(!is.na(time_in_bed_h), !is.na(sleep_duration_h), !is.na(flag_severity),
           time_in_bed_h > 0, time_in_bed_h < 24,
           sleep_duration_h > 0, sleep_duration_h < 20)
  
  if(nrow(plot_df_4) > 0) {
    overall_cor <- cor(plot_df_4$time_in_bed_h, plot_df_4$sleep_duration_h, use = "complete.obs")
    clean_cor <- cor(plot_df_4$time_in_bed_h[plot_df_4$flag_severity == "Clean"],
                     plot_df_4$sleep_duration_h[plot_df_4$flag_severity == "Clean"],
                     use = "complete.obs")
    
    p4 <- ggplot(plot_df_4, aes(x = time_in_bed_h, y = sleep_duration_h, 
                                color = flag_severity)) +
      geom_point(alpha = 0.6, size = 2) +
      geom_smooth(aes(group = 1), method = "lm", se = TRUE, color = "black", size = 0.8) +
      geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "gray50", alpha = 0.5) +
      scale_color_manual(values = c("Clean" = "#2E7D32", 
                                    "Minor issues (1 flag)" = "#FF8C00",
                                    "Major issues (2+ flags)" = "#D32F2F"),
                         name = "Data Quality") +
      labs(title = "Figure 4: Sleep Duration vs Time in Bed",
           subtitle = sprintf("COLOR-CODED by data quality | Overall r = %.3f | Clean records r = %.3f (based on final corrected data)", overall_cor, clean_cor),
           x = "Time in Bed (hours)", 
           y = "Total Sleep Time (hours)") +
      theme(legend.position = "bottom") +
      coord_cartesian(xlim = c(0, 16), ylim = c(0, 16))
    
    print(p4)
  save_png(p4, "04_Sleep_Duration_vs_Time_in_Bed", subdir = "research_ready")
    cat("✓ FIGURE 4 completed\n\n")
  }
}

# ----------------------------------------------------------------------------
# Figure 4B: SOL vs Sleep Duration (COLOR-CODED)
# ----------------------------------------------------------------------------
# DATA SOURCE: clean_df
# WHAT IT SHOWS: Scatter plot of Sleep Onset Latency vs TST
#                Color-coded by data quality severity
#                SOL > 3h filtered for clarity
# ============================================================================
# WHAT THIS FIGURE SHOWS:
# Scatter plot of Sleep Onset Latency (SOL) vs. Sleep Duration, color-coded
# by data quality. SOL values over 3 hours are filtered out for clarity. The
# dotted vertical red line marks SOL = 1 hour (clinically significant).
#
# INTERPRETATION:
# Most records should have SOL under 1 hour (left of the dotted line). High
# SOL with short sleep duration may indicate genuine insomnia, but SOL > 2
# hours often reflects data entry errors (e.g., mis-typed bedtimes). If
# flagged points cluster at high SOL, focus correction efforts on those records.
# ============================================================================
cat("Generating FIGURE 4B (SOL vs Sleep Duration)...\n")

if(all(c("sol_h", "sleep_duration_h", "flag_severity") %in% names(clean_df))) {
  
  plot_df_4b <- clean_df %>% 
    filter(!is.na(sol_h), !is.na(sleep_duration_h), !is.na(flag_severity),
           sol_h <= 3, sol_h >= 0,
           sleep_duration_h > 0, sleep_duration_h < 20)
  
  if(nrow(plot_df_4b) > 0) {
    p4b <- ggplot(plot_df_4b, aes(x = sol_h, y = sleep_duration_h, 
                                  color = flag_severity)) +
      geom_point(alpha = 0.6, size = 2) +
      geom_smooth(aes(group = 1), method = "lm", se = TRUE, color = "black", size = 0.8) +
      scale_color_manual(values = c("Clean" = "#2E7D32", 
                                    "Minor issues (1 flag)" = "#FF8C00",
                                    "Major issues (2+ flags)" = "#D32F2F"),
                         name = "Data Quality") +
      labs(title = "Figure 4B: Sleep Onset Latency vs Sleep Duration",
           subtitle = "COLOR-CODED by data quality | SOL > 3h filtered for clarity (based on final corrected data)",
           x = "Sleep Onset Latency (hours)", 
           y = "Total Sleep Time (hours)") +
      theme(legend.position = "bottom") +
      geom_vline(xintercept = 1, linetype = "dotted", color = "red", alpha = 0.5)
    
    print(p4b)
  save_png(p4b, "04B_SOL_vs_Sleep_Duration", subdir = "research_ready")
    cat("✓ FIGURE 4B completed\n\n")
  }
}

# ----------------------------------------------------------------------------
# Figure 5: Variability of Sleep Variables (Violin Plot)
# ----------------------------------------------------------------------------
# DATA SOURCE: clean_df
# WHAT IT SHOWS: Violin plots with internal box plots showing distribution shape
#                for each sleep variable
# ============================================================================
# WHAT THIS FIGURE SHOWS:
# Violin plots with embedded box plots for all sleep variables, showing the
# full shape of each distribution including density, median, and outliers.
#
# INTERPRETATION:
# Each variable should have a reasonable spread: sleep duration ~4-12 h,
# SOL 0-2 h, WASO 0-3 h, efficiency 70-100%. Very wide distributions or
# extreme outliers suggest data quality problems. Variables with unusually
# shaped distributions (e.g., bimodal, flat) may need further investigation.
# ============================================================================
cat("Generating Figure 5...\n")

available_vars <- c()
if("sleep_duration_h" %in% names(clean_df)) available_vars <- c(available_vars, `Sleep Duration` = "sleep_duration_h")
if("time_in_bed_h" %in% names(clean_df)) available_vars <- c(available_vars, `Time in Bed` = "time_in_bed_h")
if("waso_h" %in% names(clean_df)) available_vars <- c(available_vars, `WASO` = "waso_h")
if("sol_h" %in% names(clean_df)) available_vars <- c(available_vars, `SOL` = "sol_h")
if("sleep_efficiency_pct" %in% names(clean_df)) available_vars <- c(available_vars, `Sleep Efficiency` = "sleep_efficiency_pct")

if(length(available_vars) > 0) {
  # Wide → long: reshape sleep metrics into a single column for faceted violin plots
  long_df2 <- clean_df %>%
    select(all_of(available_vars)) %>%
    pivot_longer(cols = everything(), names_to = "variable", values_to = "value") %>%
    filter(!is.na(value))
  
  p5 <- ggplot(long_df2, aes(x = "  ", y = value, fill = variable)) +
    geom_violin(trim = FALSE, alpha = 0.5) +
    geom_boxplot(width = 0.1, outlier.shape = NA, fill = "white") +
    facet_wrap(vars(variable), scales = "free_y", ncol = 3) +
    scale_fill_brewer(palette = "Set2") +
    labs(title = "Figure 5: Variability of Sleep Variables",
         subtitle = "Violin plots with free Y-axis per variable (based on final corrected data)",
         x = "", y = "") +
    theme(axis.text.x = element_blank(),
          axis.ticks.x = element_blank(),
          legend.position = "none")
  print(p5)
  save_png(p5, "05_Variability_Sleep_Variables", subdir = "research_ready")
  cat("✓ Figure 5 completed\n\n")
}

# ----------------------------------------------------------------------------
# Figure 6: Sleep Duration - Clean vs Flagged (POST-MANUAL-CORRECTION)
# DATA SOURCE: clean_df (has sleep_duration_h) + corrected_ema_data (has final categories)
# ============================================================================
# WHAT THIS FIGURE SHOWS:
# Density curves comparing sleep duration distributions across four final
# classification groups: Clean, Unusual, Manually Corrected, and Error.
#
# INTERPRETATION:
# Clean and Manually Corrected distributions should overlap substantially,
# indicating corrections successfully restored plausible values. If Error
# records have a very different distribution from Clean, the flagging
# algorithm is detecting genuine anomalies. If all groups look similar,
# the classification criteria may need tightening.
# ============================================================================
cat("Generating Figure 6 (Post-correction: Clean vs Flagged)...\n")

if (exists("clean_df") && exists("corrected_ema_data") && 
    "sleep_duration_h" %in% names(clean_df)) {
  
  # 合并 clean_df 的睡眠时长和 corrected_ema_data 的分类信息
  p6_data <- clean_df %>%
    select(pid, day_num, row_id, sleep_duration_h) %>%
    filter(!is.na(sleep_duration_h)) %>%
    left_join(
      corrected_ema_data %>% select(pid, day_num, row_id, data_category, manually_corrected),
      by = c("pid", "day_num", "row_id")
    ) %>%
    mutate(
      status = case_when(
        manually_corrected == TRUE ~ "Manually Corrected",
        data_category == "clean" ~ "Clean",
        data_category == "unusual" ~ "Unusual",
        data_category == "error" ~ "Error",
        data_category == "equal_time_ok" ~ "Equal Time",
        data_category == "skipped_na" ~ "Missing Data",
        TRUE ~ "Other"
      )
    ) %>%
    filter(status %in% c("Clean", "Unusual", "Manually Corrected", "Error"))
  
  cat("  Records after filtering:", nrow(p6_data), "\n")
  cat("  Status counts:\n")
  print(table(p6_data$status, useNA = "ifany"))
  
  if (nrow(p6_data) > 0) {
    
    color_map <- c(
      "Clean" = "#2E7D32",
      "Unusual" = "#FF8C00",
      "Manually Corrected" = "#4CAF50",
      "Error" = "#D32F2F"
    )
    
    p6 <- ggplot(p6_data, aes(x = sleep_duration_h, fill = status, color = status)) +
      geom_density(alpha = 0.3, size = 0.8) +
      scale_fill_manual(values = color_map, name = "Final Classification") +
      scale_color_manual(values = color_map, name = "Final Classification") +
      labs(title = "Figure 6: Sleep Duration Distribution (Post-Manual-Correction)",
      subtitle = paste0("Before-vs-after: sleep duration distributions by data_category after Steps 5-6.5 corrections. ",
                        "Clean: ", sum(p6_data$status == "Clean"),
                        " | Unusual: ", sum(p6_data$status == "Unusual"),
                        " | Manually Corrected: ", sum(p6_data$status == "Manually Corrected"),
                        " | Error: ", sum(p6_data$status == "Error")),
           x = "Sleep Duration (hours)", 
           y = "Density") +
      theme_minimal(base_size = 12) +
      theme(legend.position = "bottom")
    
    print(p6)
  save_png(p6, "06_Sleep_Duration_Post_Correction", subdir = "pipeline_cleaning")
    cat("✓ Figure 6 completed\n\n")
  } else {
    cat("⚠ No valid data for Figure 6\n\n")
  }
} else {
  cat("⚠ clean_df or corrected_ema_data missing required columns\n")
  cat("  Make sure apply_sleep_metrics() was run on clean_df\n\n")
}


# ----------------------------------------------------------------------------
# Figure 7: Flag Composition (Stacked Histogram)
# ----------------------------------------------------------------------------
# DATA SOURCE: clean_df
# WHAT IT SHOWS: Stacked histogram showing data quality composition across sleep durations
#                Colors indicate Clean, Minor issues, Major issues
# ============================================================================
# WHAT THIS FIGURE SHOWS:
# A stacked histogram showing how data quality (Clean, Minor Issues, Major
# Issues) distributes across the range of sleep durations.
#
# INTERPRETATION:
# Flags should be more frequent at the extremes (<4 h or >10 h), which is
# clinically expected. If many flags appear in the normal range (6-9 h),
# this suggests overly aggressive flagging thresholds. Conversely, if extreme
# values show no flags, thresholds may be too lenient.
# ============================================================================
cat("Generating FIGURE 7 (Stacked by flag severity)...\n")

if(all(c("sleep_duration_h", "flag_severity") %in% names(clean_df))) {
  
  plot_df_7 <- clean_df %>% 
    filter(!is.na(sleep_duration_h), !is.na(flag_severity),
           sleep_duration_h > 0, sleep_duration_h < 20)
  
  if(nrow(plot_df_7) > 0) {
    n_minor <- sum(plot_df_7$flag_severity == "Minor issues (1 flag)", na.rm = TRUE)
    n_major <- sum(plot_df_7$flag_severity == "Major issues (2+ flags)", na.rm = TRUE)
    flag_text <- paste0(
      "Flag thresholds (corrected metrics):\n",
      "  SE < 70%     (poor sleep efficiency)\n",
      "  SOL > 1h     (long sleep onset latency)\n",
      "  WASO > 1.5h  (excessive wake after sleep onset)\n\n",
      sprintf("  Minor (1 flag): n = %d\n", n_minor),
      sprintf("  Major (2+ flags): n = %d", n_major)
    )

    p7 <- ggplot(plot_df_7, aes(x = sleep_duration_h, fill = flag_severity)) +
      geom_histogram(bins = 50, alpha = 0.7, position = "stack") +
      scale_fill_manual(values = c("Clean" = "#2E7D32", 
                                   "Minor issues (1 flag)" = "#FF8C00",
                                   "Major issues (2+ flags)" = "#D32F2F"),
                        name = "Data Quality") +
      labs(title = "Figure 7: Data Quality Composition Across Sleep Durations",
           subtitle = "Stacked histogram showing how data quality varies by sleep duration (based on final corrected data)",
           x = "Sleep Duration (hours)", y = "Count") +
      scale_x_continuous(limits = c(0, 16), expand = c(0.02, 0)) +
      scale_y_continuous(expand = expansion(mult = c(0, 0.35))) +
      annotate("label", x = 15, y = Inf, label = flag_text,
               hjust = 1, vjust = 1, size = 3, fill = "white", alpha = 0.9,
               label.r = unit(0.15, "lines"), label.size = 0.3) +
      theme(legend.position = "bottom")
    
    print(p7)
  save_png(p7, "07_Flag_Composition_Stacked", subdir = "pipeline_cleaning")
    cat("✓ Figure 7 completed\n\n")
  }
}

# ----------------------------------------------------------------------------
# Figure 8: Sleep Duration by Data Category
# ----------------------------------------------------------------------------
# DATA SOURCE: clean_df + unusual_df + error_df
# WHAT IT SHOWS: Violin plots comparing sleep duration across clean, unusual, and error categories
# ============================================================================
# WHAT THIS FIGURE SHOWS:
# Violin plots comparing sleep duration distributions across the three
# original data categories: clean, unusual, and error.
#
# INTERPRETATION:
# Clean records should show the tightest, most clinically normal distribution.
# Unusual records should be wider but still plausible. Error records should
# show the widest spread and most extreme values. If all three categories
# have similar distributions, the original classification criteria may not
# be effectively separating problematic from healthy data.
# ============================================================================
cat("Generating Figure 8...\n")

combined_all <- bind_rows(
  clean_df %>% mutate(category = "clean"),
  if(exists("unusual_df") && nrow(unusual_df) > 0) unusual_df %>% mutate(category = "unusual") else NULL,
  if(exists("error_df") && nrow(error_df) > 0) error_df %>% mutate(category = "error") else NULL
) %>% filter(!is.na(sleep_duration_h))

if(nrow(combined_all) > 0) {
  p8 <- ggplot(combined_all, aes(x = category, y = sleep_duration_h, fill = category)) +
    geom_violin(trim = FALSE, alpha = 0.4) +
    geom_boxplot(width = 0.15, outlier.shape = NA) +
    scale_fill_manual(values = c("clean" = "#2E7D32", "unusual" = "#FF8C00", "error" = "#D32F2F")) +
    labs(title = "Figure 8: Sleep Duration by Data Category",
         subtitle = "Comparison across clean, unusual, and error categories (based on final corrected data)",
         x = "", y = "Sleep Duration (hours)") +
    theme(legend.position = "none")
  print(p8)
  save_png(p8, "08_Sleep_Duration_by_Category", subdir = "pipeline_cleaning")
  cat("✓ Figure 8 completed\n\n")
}

# ----------------------------------------------------------------------------
# Figure 9: Bedtime vs Get-up Time Distribution
# ----------------------------------------------------------------------------
# DATA SOURCE: clean_df
# WHAT IT SHOWS: Density plots of bedtime and get-up time across the day
#                Reveals circadian patterns of sleep timing
# ============================================================================
# WHAT THIS FIGURE SHOWS:
# Density plots of bedtime (green) and get-up time (orange) across the 24-hour
# clock, revealing the circadian sleep-wake patterns in the data.
#
# INTERPRETATION:
# Bedtimes should peak in late evening (10 PM-midnight) and get-up times in
# early morning (6-8 AM). Multiple peaks or very flat distributions suggest
# heterogeneous sleep schedules or potential data quality issues. Bedtimes
# clustered near midnight with get-up times near noon could indicate a
# night-owl population or shift workers.
# ============================================================================
cat("Generating Figure 9...\n")

if(all(c("time_bed_corrected", "time_getup_corrected") %in% names(clean_df))) {
  clean_df_timing <- clean_df %>%
    filter(!is.na(time_bed_corrected), !is.na(time_getup_corrected)) %>%
    mutate(
      bedtime_hour = hour(time_bed_corrected) + minute(time_bed_corrected)/60,
      getup_hour = hour(time_getup_corrected) + minute(time_getup_corrected)/60
    )
  
  p9 <- ggplot(clean_df_timing) +
    geom_density(aes(x = bedtime_hour, fill = "Bedtime"), alpha = 0.4) +
    geom_density(aes(x = getup_hour, fill = "Get-up Time"), alpha = 0.4) +
    labs(title = "Figure 9: Bedtime vs Get-up Time Distribution",
         subtitle = "Circadian pattern of sleep timing (based on final corrected data)",
         x = "Hour of Day", y = "Density", fill = "Time") +
    scale_fill_manual(values = c("Bedtime" = "#2E7D32", "Get-up Time" = "#FF8C00")) +
    scale_x_continuous(breaks = seq(0, 24, 2))
  print(p9)
  save_png(p9, "09_Bedtime_vs_Getup_Distribution", subdir = "research_ready")
  cat("✓ Figure 9 completed\n\n")
}

# ----------------------------------------------------------------------------
# Figure 10: Extreme Sleep Duration with Efficiency Context
# ----------------------------------------------------------------------------
# DATA SOURCE: clean_df
# WHAT IT SHOWS: Scatter plot of extreme sleep durations (<4h or >10h)
#                with sleep efficiency context, color-coded by data quality
# ============================================================================
# WHAT THIS FIGURE SHOWS:
# A focused scatter plot of extreme sleep durations (<4 h or >10 h), plotting
# each record's sleep efficiency against its duration, color-coded by data
# quality. The horizontal dashed line marks 85% efficiency.
#
# INTERPRETATION:
# Very short sleep (<4 h) with low efficiency may reflect genuine insomnia,
# but extremely long sleep (>10 h) with low efficiency often points to
# calculation errors (e.g., time in bed was used instead of TST). If most
# extreme records are flagged as Major Issues, the flagging is working as
# intended. Unflagged extreme values warrant a closer look.
# ============================================================================
cat("Generating FIGURE 10...\n")

if(all(c("sleep_duration_h", "sleep_efficiency_pct", "flag_severity") %in% names(clean_df))) {
  
  plot_df_10 <- clean_df %>%
    filter(!is.na(sleep_duration_h), !is.na(sleep_efficiency_pct), !is.na(flag_severity)) %>%
    mutate(
      extreme_type = case_when(
        sleep_duration_h < 4 ~ "Short sleep (<4h)",
        sleep_duration_h > 10 ~ "Long sleep (>10h)",
        TRUE ~ "Normal range"
      )
    )
  
  extreme_df <- plot_df_10 %>% filter(extreme_type != "Normal range")
  
  if(nrow(extreme_df) > 0) {
    p10 <- ggplot(extreme_df, aes(x = sleep_duration_h, y = sleep_efficiency_pct,
                                  color = flag_severity, shape = extreme_type)) +
      geom_point(size = 3, alpha = 0.7) +
      scale_color_manual(values = c("Clean" = "#2E7D32", 
                                    "Minor issues (1 flag)" = "#FF8C00",
                                    "Major issues (2+ flags)" = "#D32F2F"),
                         name = "Data Quality") +
      labs(title = "Figure 10: Extreme Sleep Durations with Efficiency Context",
           subtitle = "COLOR-CODED by data quality | SHAPE indicates short vs long sleep (based on final corrected data)",
           x = "Sleep Duration (hours)", 
           y = "Sleep Efficiency (%)",
           shape = "Duration Type") +
      geom_hline(yintercept = 85, linetype = "dashed", color = "gray50", alpha = 0.7) +
      theme(legend.position = "bottom")
    
    print(p10)
  save_png(p10, "10_Extreme_Sleep_Duration", subdir = "pipeline_cleaning")
    cat("✓ Figure 10 completed\n\n")
  } else {
    cat("⚠ No extreme values for Figure 10\n\n")
  }
}

# ----------------------------------------------------------------------------
# Figure 11: Flag Co-occurrence Heatmap
# ----------------------------------------------------------------------------
# DATA SOURCE: clean_df
# WHAT IT SHOWS: Heatmap showing how often different quality flags occur together
#                Helps identify clusters of related issues
# ============================================================================
# WHAT THIS FIGURE SHOWS:
# A heatmap showing how often pairs of data quality flags (Poor Efficiency,
# High SOL, High WASO, Extreme Duration) occur together in the same record.
# Darker cells indicate more frequent co-occurrence.
#
# INTERPRETATION:
# Some co-occurrence is clinically expected (e.g., high SOL with low
# efficiency). Isolated flags (light cells) suggest specific, isolated issues.
# If most flag pairs show high co-occurrence, it may indicate a general data
# quality problem affecting many records simultaneously, or that the flagging
# thresholds are correlated by design.
# ============================================================================
cat("Generating FIGURE 11 (Flag co-occurrence heatmap)...\n")

if(!"flag_poor_efficiency" %in% names(clean_df)) {
  clean_df <- clean_df %>%
    mutate(
      flag_poor_efficiency = ifelse(!is.na(sleep_efficiency_pct), sleep_efficiency_pct < 70, FALSE),
      flag_high_sol = ifelse(!is.na(sol_h), sol_h > 1, FALSE),
      flag_high_waso = ifelse(!is.na(waso_h), waso_h > 1.5, FALSE),
      flag_duration_extreme_num = ifelse(!is.na(sleep_duration_h), sleep_duration_h < 3 | sleep_duration_h > 12, FALSE)
    )
}

flag_columns <- c()
if("flag_poor_efficiency" %in% names(clean_df)) flag_columns <- c(flag_columns, "Poor Efficiency" = "flag_poor_efficiency")
if("flag_high_sol" %in% names(clean_df)) flag_columns <- c(flag_columns, "High SOL" = "flag_high_sol")
if("flag_high_waso" %in% names(clean_df)) flag_columns <- c(flag_columns, "High WASO" = "flag_high_waso")
if("flag_duration_extreme_num" %in% names(clean_df)) flag_columns <- c(flag_columns, "Extreme Duration" = "flag_duration_extreme_num")

if(length(flag_columns) >= 2) {
  
  flag_matrix <- clean_df %>%
    select(all_of(flag_columns)) %>%
    mutate(across(everything(), ~as.numeric(.)))
  
  flag_matrix <- flag_matrix[complete.cases(flag_matrix), ]
  
  if(nrow(flag_matrix) > 0 && ncol(flag_matrix) > 1) {
    n_flags <- ncol(flag_matrix)
    cooccurrence_matrix <- matrix(0, nrow = n_flags, ncol = n_flags)
    colnames(cooccurrence_matrix) <- names(flag_columns)
    rownames(cooccurrence_matrix) <- names(flag_columns)
    
    for(i in 1:n_flags) {
      for(j in 1:n_flags) {
        if(i != j) {
          cooccurrence_matrix[i, j] <- sum(flag_matrix[, i] == 1 & flag_matrix[, j] == 1, na.rm = TRUE)
        }
      }
    }
    
    heatmap_df <- as.data.frame(as.table(cooccurrence_matrix)) %>%
      rename(Flag1 = Var1, Flag2 = Var2, Count = Freq) %>%
      filter(Flag1 != Flag2, Count > 0)
    
    if(nrow(heatmap_df) > 0) {
      p11_heatmap <- ggplot(heatmap_df, aes(x = Flag1, y = Flag2, fill = Count)) +
        geom_tile(color = "white", size = 1) +
        geom_text(aes(label = Count), size = 4, fontface = "bold") +
        scale_fill_gradient(low = "#FEE5D9", high = "#D32F2F", 
                            name = "Co-occurrence\nCount",
                            trans = "sqrt") +
        labs(title = "Figure 11: Data Quality Flag Co-occurrence Heatmap",
             subtitle = "Shows which quality issues tend to occur together (based on final corrected data)",
             x = "", y = "") +
        theme_minimal(base_size = 12) +
        theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 10),
              axis.text.y = element_text(size = 10),
              panel.grid = element_blank(),
              legend.position = "right")
      
      print(p11_heatmap)
  save_png(p11_heatmap, "11_Flag_Cooccurrence_Heatmap", subdir = "pipeline_cleaning")
      cat("✓ FIGURE 11 (Heatmap) completed\n\n")
    }
  }
}

# ============================================================================
# Figure 12: Pipeline Correction Progress (Three-Panel Table)
# ============================================================================
# WHAT IT SHOWS: Three-panel summary table of pipeline correction progress.
#   Panel 1 — Core metrics per step (Total, Clean, Error, Unusual, etc.)
#   Panel 2 — Step-to-step changes (Δ Clean, Δ Error, Δ Unusual, Δ Corrected)
#   Panel 3 — Sleep metrics for steps where available (Valid N, TST, SOL)
# DATA SOURCE: correction_status.csv from report_correction_status.R
# ============================================================================
cat("Generating FIGURE 12 (Pipeline Correction Progress Table)...\n")

cp_file <- "output/correction_status.csv"
if (file.exists(cp_file)) {
  cp <- read.csv(cp_file, stringsAsFactors = FALSE)
  latest_run <- max(cp$run_id)
  cp <- cp[cp$run_id == latest_run, ] %>%
    filter(checkpoint %in% c("A", "B", "C", "D", "E")) %>%
    mutate(
      step_label = case_when(
        checkpoint == "A" ~ "Step 4",
        checkpoint == "B" ~ "Step 6",
        checkpoint == "C" ~ "Step 6.5",
        checkpoint == "D" ~ "Step 7",
        checkpoint == "E" ~ "Step 8"
      ),
      step_desc = case_when(
        checkpoint == "A" ~ "Auto-normalize",
        checkpoint == "B" ~ "Timestamp corrections",
        checkpoint == "C" ~ "Duration corrections",
        checkpoint == "D" ~ "Metrics computed",
        checkpoint == "E" ~ "Auto-detection"
      )
    )

  # Panel 1 — Core metrics
  tbl1 <- cp %>%
    mutate(n_corrected = ifelse(is.na(n_corrected), 0, n_corrected)) %>%
    select(Step = step_label, Description = step_desc,
           Total = n_total, Clean = n_clean, Error = n_error,
           Unusual = n_unusual, `Eq.Time` = n_equal_time,
           Skipped = n_skipped, Corrected = n_corrected)

  # Panel 2 — Step-to-step deltas
  delta_df <- data.frame(
    Step = cp$step_label,
    `Δ Clean`    = c(NA, diff(cp$n_clean)),
    `Δ Error`    = c(NA, diff(cp$n_error)),
    `Δ Unusual`  = c(NA, diff(cp$n_unusual)),
    `Δ Corrected` = c(NA, diff(ifelse(is.na(cp$n_corrected), 0, cp$n_corrected))),
    check.names = FALSE
  )

  # Panel 3 — Sleep metrics (step D/E only)
  metrics_data <- cp %>% filter(checkpoint %in% c("D", "E"))
  if (nrow(metrics_data) > 0 && any(!is.na(metrics_data$n_valid) & metrics_data$n_valid > 0)) {
    tbl3 <- metrics_data %>%
      mutate(`TST (h)` = sprintf("%.2f", tst_mean_h),
             `SOL (min)` = sprintf("%.1f", sol_mean_min)) %>%
      select(Step = step_label, `N Valid` = n_valid, `TST (h)`, `SOL (min)`)
  } else {
    tbl3 <- data.frame(Step = "—", `N Valid` = "—", `TST (h)` = "—",
                       `SOL (min)` = "—", check.names = FALSE)
  }

  # Render helpers
  make_tab <- function(df, fontsize = 9) {
    tableGrob(df, rows = NULL,
              theme = ttheme_minimal(
                base_size = fontsize,
                core = list(fg_params = list(hjust = 0, x = 0.03)),
                colhead = list(fg_params = list(hjust = 0, x = 0.03, fontface = "bold"))
              ))
  }

  t1 <- make_tab(tbl1)
  t2 <- make_tab(delta_df)
  t3 <- make_tab(tbl3)

  # Layout
  p12 <- grid.arrange(
    textGrob("Figure 12: Pipeline Correction Progress",
             gp = gpar(fontsize = 14, fontface = "bold"), just = "left", x = 0.03),
    textGrob(sprintf("Run %s  |  Checkpoints A→E → Steps 4→8  |  Δ = change from previous step",
                     latest_run),
             gp = gpar(fontsize = 9, col = "gray40"), just = "left", x = 0.03),
    t1, t2, t3, ncol = 1,
    heights = c(unit(0.35, "in"), unit(0.2, "in"),
                unit(nrow(tbl1) * 0.28 + 0.4, "in"),
                unit(nrow(delta_df) * 0.28 + 0.4, "in"),
                unit(nrow(tbl3) * 0.28 + 0.4, "in"))
  )

  save_png(p12, "12_Pipeline_Correction_Progress", subdir = "pipeline_cleaning")
  print(p12)
  cat("✓ Figure 12 (Three-Panel Progress Table) completed\n\n")
} else {
  cat("⚠ correction_status.csv not found — skipping Figure 12\n\n")
}

cat("\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\nSTEP 7: GENERATING FIGURES 13-20 (Auto-Detection Flags)\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\n\n")

if(checkforerrors_exists && nrow(checkforerrors_processed) > 0) {
  
  # --------------------------------------------------------------------------
  # Figure 13: Error Category Distribution (Auto-Detection)
  # --------------------------------------------------------------------------
  # DATA SOURCE: checkforerrors_processed
  # WHAT IT SHOWS: Bar chart of error categories from algorithm detection
  #                Shows what types of issues are most common
  # ==========================================================================
  # WHAT THIS FIGURE SHOWS:
  # Bar chart of algorithm-detected error categories (Interval Format, Time
  # Order, Sleep Latency, WASO, Duration >24h, etc.), plus reference tables
  # for severity and current flag distribution.
  #
  # INTERPRETATION:
  # The most common error categories reveal systematic issues in data collection.
  # If one category dominates (e.g., Interval Format Errors), investigate the
  # root cause (e.g., inconsistent time entry format). High-severity categories
  # (Sleep Latency, Duration >24h) should be prioritized for manual correction.
  # ==========================================================================
  cat("Generating FIGURE 13 (Error category distribution - Auto-detection)...\n")
  
  error_summary <- checkforerrors_processed %>%
    group_by(error_category) %>%
    summarise(count = n(), .groups = "drop") %>%
    mutate(percentage = count / sum(count) * 100,
           error_category = reorder(error_category, -count))
  
  # Bar chart (without title — will use patchwork annotation)
  p13_bar <- ggplot(error_summary, aes(x = error_category, y = count, fill = error_category)) +
    geom_bar(stat = "identity", alpha = 0.8) +
    geom_text(aes(label = paste0(format(count, big.mark=","), "\n(", round(percentage, 1), "%)")), 
              vjust = -0.3, size = 3) +
    scale_fill_brewer(palette = "Set2") +
    labs(x = "", y = "Count") +
    theme(axis.text.x = element_text(angle = 45, hjust = 1),
          legend.position = "none")
  
  # Severity reference table for error categories
  severity_df <- data.frame(
    Category = c("Interval Format Error", "Time Order Error", 
                 "Sleep Latency Issue", "WASO Issue",
                 "Duration >24 Hours", "Unusual Sleep Pattern", "General Error"),
    Severity = c("Low", "Medium", "High", "Medium", "High", "Low", "High"),
    Description = c("Format issues, likely entry habit differences",
                    "Chronological order reversed",
                    "SOL reaches hour-level, possible entry error",
                    "Abnormal wake-after-sleep-onset",
                    "Calculation error or abnormal entry",
                    "Unusual but possibly real pattern",
                    "Uncategorized error")
  )
  
  severity_tab <- tableGrob(severity_df, rows = NULL,
                             theme = ttheme_minimal(
                               base_size = 9,
                               core = list(fg_params = list(hjust = 0, x = 0.03)),
                               colhead = list(fg_params = list(hjust = 0, x = 0.03, fontface = "bold"))
                             ))
  
  # Current flag distribution from checkforerrors_summary
  flag_dist_df <- NULL
  if (exists("checkforerrors_summary") && is.list(checkforerrors_summary) &&
      "review_summary" %in% names(checkforerrors_summary)) {
    rs <- checkforerrors_summary$review_summary
    flag_dist_df <- data.frame(
      Category = c("TIMESTAMP_ISSUE", "DURATION_ISSUE", "AMOUNT_FLAG", "SELF-REPORTED FLAG", "CLEAN", "CLEAN (Manually Fixed)"),
      Count = c(
        sum(rs$raw_category == "TIMESTAMP_ISSUE", na.rm = TRUE),
        sum(rs$raw_category == "DURATION_ISSUE", na.rm = TRUE),
        sum(rs$raw_category == "AMOUNT_FLAG", na.rm = TRUE),
        sum(rs$raw_category == "SELF_REPORTED_FLAG", na.rm = TRUE),
        sum(rs$raw_category == "CLEAN", na.rm = TRUE),
        sum(rs$final_status == "CLEAN (Manually Fixed)", na.rm = TRUE)
      )
    )
  }
  
  if (!is.null(flag_dist_df)) {
    flag_tab <- tableGrob(flag_dist_df, rows = NULL,
                          theme = ttheme_minimal(
                            base_size = 9,
                            core = list(fg_params = list(hjust = 0, x = 0.03)),
                            colhead = list(fg_params = list(hjust = 0, x = 0.03, fontface = "bold"))
                          ))
    p13_content <- (p13_bar / severity_tab / flag_tab)
  } else {
    p13_content <- (p13_bar / severity_tab)
  }
  
  p13 <- p13_content +
    plot_layout(heights = c(3, unit(1.5, "in"), unit(1.2, "in"))) +
    plot_annotation(
      title = "Figure 13: Distribution of Error/Review Categories (Auto-Detection)",
      subtitle = sprintf("Auto-detection (pre-correction): flags from timestamp parsing (Part A), temporal error_type (Part B), and sleep metrics validation (Part C: SOL>120min, SE<0 or >100%%, TST/TIB<0.5) | Total: %s (%.1f%% of all data)", 
                         format(nrow(checkforerrors_processed), big.mark=","),
                         nrow(checkforerrors_processed)/nrow(clean_df) * 100),
      theme = theme(plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
                    plot.subtitle = element_text(hjust = 0.5, size = 10))
    )
  
  print(p13)
  save_png(p13, "13_Error_Category_Distribution", subdir = "pipeline_cleaning")
  cat("✓ Figure 13 completed\n\n")
  
  # --------------------------------------------------------------------------
  # Figure 14: Sleep Duration - Clean vs Flagged (PRE-CORRECTION / AUTO-DETECTION)
  # DATA SOURCE: checkforerrors_processed (from _checkforerrors flags)
  # WHAT IT SHOWS: Distribution of sleep duration for algorithm-detected issues
  #                - No Issues (Clean): Records with no _checkforerrors flags
  #                - Needs Review: Records flagged by algorithm (before manual review)
  # ==========================================================================
  # WHAT THIS FIGURE SHOWS:
  # Density curves comparing sleep duration for algorithm-flagged records vs.
  # a random sample of clean (unflagged) records. This reveals whether flagged
  # records have systematically different sleep durations.
  #
  # INTERPRETATION:
  # If flagged records cluster at extreme durations (<4 h or >10 h), the
  # algorithm is correctly identifying outliers. If flagged records overlap
  # heavily with clean ones, the algorithm may be too sensitive (high false
  # positive rate). A clean separation suggests the flagging criteria are
  # working well.
  # ==========================================================================
  cat("Generating FIGURE 14 (Pre-correction: Auto-detection flags)...\n")
  
  if("sleep_duration_h" %in% names(checkforerrors_processed) && sum(!is.na(checkforerrors_processed$sleep_duration_h)) > 0) {
    
    clean_sample_size <- min(5000, sum(!is.na(clean_df$sleep_duration_h)))
    
    clean_sample <- clean_df %>% 
      filter(!is.na(sleep_duration_h)) %>%
      mutate(status = "No Issues (Clean) - No _checkforerrors flags") %>%
      slice_sample(n = clean_sample_size)
    
    flagged_data <- checkforerrors_processed %>%
      filter(!is.na(sleep_duration_h)) %>%
      mutate(status = "Needs Review (Auto-detected) - Has _checkforerrors flags")
    
    if(nrow(flagged_data) > 0) {
      comparison_df <- bind_rows(clean_sample, flagged_data)
      
      # Get counts for subtitle
      clean_count <- nrow(clean_sample)
      flagged_count <- nrow(flagged_data)
      
      p14 <- ggplot(comparison_df, aes(x = sleep_duration_h, fill = status, color = status)) +
        geom_density(alpha = 0.4, size = 0.8) +
        scale_fill_manual(values = c("No Issues (Clean) - No _checkforerrors flags" = "#2E7D32", 
                                     "Needs Review (Auto-detected) - Has _checkforerrors flags" = "#D32F2F")) +
        scale_color_manual(values = c("No Issues (Clean) - No _checkforerrors flags" = "#2E7D32", 
                                      "Needs Review (Auto-detected) - Has _checkforerrors flags" = "#D32F2F")) +
        labs(title = "Figure 14: Sleep Duration Distribution (Pre-Correction / Auto-Detection)",
             subtitle = paste0("Based on _checkforerrors flags (algorithm only, no manual corrections) | ",
                               "Clean sample: ", clean_count, " records | ",
                               "Flagged: ", flagged_count, " records"),
             x = "Sleep Duration (hours)", 
             y = "Density",
             fill = "Status", color = "Status") +
        theme_minimal(base_size = 12) +
        theme(legend.position = "bottom")
      
      print(p14)
  save_png(p14, "14_Sleep_Duration_Pre_Correction", subdir = "pipeline_cleaning")
      cat("✓ Figure 14 completed (using _checkforerrors auto-detection)\n\n")
    } else {
      cat("⚠ No flagged data for Figure 14\n\n")
    }
  } else {
    cat("⚠ No valid sleep duration data for Figure 14\n\n")
  }
  
  # --------------------------------------------------------------------------
  # Figure 15: Error Timeline Over Study Period (Auto-Detection)
  # --------------------------------------------------------------------------
  # DATA SOURCE: checkforerrors_processed
  # WHAT IT SHOWS: Stacked area chart showing when errors/reviews occur over time
  # ==========================================================================
  # WHAT THIS FIGURE SHOWS:
  # Stacked area chart of error frequency over the study timeline, with each
  # error category shown in a different color.
  #
  # INTERPRETATION:
  # Errors concentrated at the study start suggest a learning curve or
  # instruction issues. Spikes on specific dates may indicate protocol changes,
  # technical problems, or data collection disruptions. A steady rate of errors
  # throughout suggests ongoing, systemic issues. The absence of errors after
  # a certain date could mean the problem was fixed—or that data entry stopped.
  # ==========================================================================
  cat("Generating FIGURE 15 (Error timeline - Auto-detection)...\n")
  
  if("time_bed_corrected" %in% names(checkforerrors_processed)) {
    
    timeline_data <- checkforerrors_processed %>%
      filter(!is.na(time_bed_corrected), !is.na(error_category)) %>%
      mutate(date = as.Date(time_bed_corrected)) %>%
      group_by(date, error_category) %>%
      summarise(count = n(), .groups = "drop")
    
    if(nrow(timeline_data) > 0) {
      p15 <- ggplot(timeline_data, aes(x = date, y = count, fill = error_category)) +
        geom_area(position = "stack", alpha = 0.7) +
        scale_fill_brewer(palette = "Set2", name = "Error Category") +
        labs(title = "Figure 15: Error Timeline Over Study Period (Auto-Detection)",
             subtitle = "Stacked area chart showing when algorithm-detected errors occur",
             x = "Date", 
             y = "Number of Records Needing Review") +
        theme(legend.position = "bottom",
              legend.text = element_text(size = 8))
      
      print(p15)
  save_png(p15, "15_Error_Timeline", subdir = "pipeline_cleaning")
      cat("✓ Figure 15 completed\n\n")
    }
  }
  
  # --------------------------------------------------------------------------
  # Figure 16: Most Common Error Patterns (Auto-Detection)
  # --------------------------------------------------------------------------
  # DATA SOURCE: checkforerrors_processed$auto_error_desc
  # WHAT IT SHOWS: Horizontal bar chart of most common specific error patterns
  # ==========================================================================
  # WHAT THIS FIGURE SHOWS:
  # A horizontal bar chart ranking the most frequent specific error patterns
  # (e.g., temporal order errors, SOL metric issues, interval format errors).
  #
  # INTERPRETATION:
  # The dominant error patterns reveal where to focus correction efforts.
  # Temporal errors suggest participants misunderstood the time entry interface.
  # SOL/WASO metric issues may indicate a problem with how these values were
  # calculated or reported. Patterns appearing in only a few records are likely
  # individual mistakes rather than systemic problems.
  # ==========================================================================
  cat("Generating FIGURE 16 (Common error patterns - Auto-detection)...\n")
  
  if("auto_error_desc" %in% names(checkforerrors_processed)) {
    
    cat("  Analyzing error patterns...\n")
    
    pattern_data <- checkforerrors_processed %>%
      mutate(
        specific_pattern = case_when(
          grepl("\\[Temporal\\].*Error", auto_error_desc) ~ "Temporal order error",
          grepl("\\[Temporal\\].*Unusual", auto_error_desc) ~ "Unusual sleep pattern",
          grepl("\\[Metrics\\].*SOL:", auto_error_desc) ~ "SOL metric abnormal",
          grepl("\\[Metrics\\].*SE:", auto_error_desc) ~ "Sleep efficiency abnormal",
          grepl("\\[Metrics\\].*TST/TIB:", auto_error_desc) ~ "TST/TIB ratio abnormal",
          grepl("duration_totalmin_sol_estimate_am", auto_error_desc) ~ "SOL interval format",
          grepl("duration_totalmin_waso_estimate_am", auto_error_desc) ~ "WASO interval format",
          grepl("\\[Amount\\]", auto_error_desc) ~ "Amount input anomaly",
          grepl("\\[Interval\\]", auto_error_desc) ~ "Other interval format error",
          grepl("\\[Timestamp\\]", auto_error_desc) ~ "Timestamp parse warning",
          TRUE ~ "Other"
        )
      )
    
    cat("  Pattern distribution:\n")
    pattern_dist <- table(pattern_data$specific_pattern)
    print(pattern_dist)
    
    pattern_summary <- pattern_data %>%
      filter(specific_pattern != "Other") %>%
      group_by(specific_pattern) %>%
      summarise(count = n(), .groups = "drop") %>%
      arrange(desc(count)) %>%
      mutate(specific_pattern = factor(specific_pattern, levels = rev(unique(specific_pattern))))
    
    if(nrow(pattern_summary) > 0) {
      p16 <- ggplot(pattern_summary, aes(x = specific_pattern, y = count, fill = count)) +
        geom_bar(stat = "identity", alpha = 0.8) +
        geom_text(aes(label = format(count, big.mark=",")), hjust = -0.1, size = 3.5) +
        scale_x_discrete(labels = function(x) {
          sapply(x, function(s) paste(strwrap(s, width = 35), collapse = "\n"))
        }) +
        scale_fill_gradient(low = "#FF8C00", high = "#D32F2F", name = "Count") +
        labs(title = "Figure 16: Most Common Error/Review Patterns (Auto-Detection)",
             x = "", y = "Count") +
        coord_flip() +
        scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
        theme_minimal(base_size = 11) +
        theme(legend.position = "bottom")
      
      print(p16)
  save_png(p16, "16_Common_Error_Patterns", subdir = "pipeline_cleaning")
      cat("✓ Figure 16 completed\n\n")
    } else {
      cat("⚠ No specific patterns identified (all 'Other')\n")
    }
  }
  
  # --------------------------------------------------------------------------
  # Figure 17: Flagged Records by Participant (Auto-Detection)
  # --------------------------------------------------------------------------
  # DATA SOURCE: checkforerrors_processed
  # WHAT IT SHOWS: Top 15 participants with most algorithm-detected flags
  # ==========================================================================
  # WHAT THIS FIGURE SHOWS:
  # Bar chart of the 15 participants with the highest number of algorithm-
  # detected flags, ranked from most to least.
  #
  # INTERPRETATION:
  # A few participants with many flags suggests individual-level issues
  # (non-compliance, misunderstanding of instructions, consistently poor data
  # quality). If many participants have a similar (low) number of flags, the
  # issues are likely systemic. Participants at the very top may need their
  # data excluded or specially handled in analysis.
  # ==========================================================================
  cat("Generating FIGURE 17 (Flagged records by participant - Auto-detection)...\n")
  
  if("pid" %in% names(checkforerrors_processed)) {
    
    participant_errors <- checkforerrors_processed %>%
      group_by(pid) %>%
      summarise(error_count = n(), .groups = "drop") %>%
      arrange(desc(error_count)) %>%
      mutate(rank = row_number(),
             pid_label = ifelse(rank <= 15, as.character(pid), "Other")) %>%
      filter(pid_label != "Other")
    
    if(nrow(participant_errors) > 0) {
      p17 <- ggplot(participant_errors, 
                    aes(x = reorder(pid_label, -error_count), y = error_count, fill = error_count)) +
        geom_bar(stat = "identity", alpha = 0.7) +
        geom_text(aes(label = error_count), vjust = -0.3, size = 3) +
        scale_fill_gradient(low = "#FF8C00", high = "#D32F2F", name = "Flag Count") +
        labs(title = "Figure 17: Top 15 Participants with Most Review Flags (Auto-Detection)",
             subtitle = sprintf("Total participants with algorithm-detected issues: %d", length(unique(checkforerrors_processed$pid))),
             x = "Participant ID", 
             y = "Number of Records Needing Review") +
        theme(axis.text.x = element_text(angle = 45, hjust = 1),
              legend.position = "bottom")
      
      print(p17)
  save_png(p17, "17_Top_Participants_Flags", subdir = "pipeline_cleaning")
      cat("✓ Figure 17 completed\n\n")
    }
  }
  
  # --------------------------------------------------------------------------
  # Figure 18: Auto-Detected Review Flags Dashboard
  # --------------------------------------------------------------------------
  # DATA SOURCE: review_output from checkforerrors_processing.R
  # WHAT IT SHOWS: Dashboard of algorithm-detected issues
  #                - Left: Key metrics (Total records, Manually Corrected, Auto-detected)
  #                - Right: Pie chart of issue types (Temporal, Metrics, Interval, etc.)
  # NOTE: This is PRE-correction detection, different from Figure 1 (POST-correction)
  # ==========================================================================
  cat("Generating FIGURE 18 (Auto-detected review flags dashboard)...\n")
  
  if(exists("review_output") && is.list(review_output) && 
     "checkforerrors_df" %in% names(review_output) && 
     nrow(review_output$checkforerrors_df) > 0) {
    
    checkforerrors_df <- review_output$checkforerrors_df
    total_records <- nrow(corrected_ema_data)
    flagged_records <- nrow(checkforerrors_df)
    manually_corrected_count <- sum(corrected_ema_data$manually_corrected, na.rm = TRUE)
    
    if("auto_error_desc" %in% names(checkforerrors_df)) {
      
      review_classification <- checkforerrors_df %>%
        mutate(
          review_source = case_when(
            grepl("\\[Temporal\\]", auto_error_desc, ignore.case = TRUE) ~ "Temporal Issues",
            grepl("\\[Metrics\\]", auto_error_desc, ignore.case = TRUE) ~ "Metrics Issues",
            grepl("\\[Amount\\]", auto_error_desc, ignore.case = TRUE) ~ "Amount/Input Flags",
            grepl("\\[Interval\\]", auto_error_desc, ignore.case = TRUE) ~ "Interval Format Errors",
            grepl("\\[Timestamp\\]", auto_error_desc, ignore.case = TRUE) ~ "Timestamp Format Errors",
            TRUE ~ "Other Issues"
          )
        ) %>%
        group_by(review_source) %>%
        summarise(count = n(), .groups = "drop") %>%
        mutate(
          percentage = count / flagged_records * 100,
          review_source = factor(review_source,
                                 levels = c("Temporal Issues", "Metrics Issues",
                                            "Amount/Input Flags", "Interval Format Errors",
                                            "Timestamp Format Errors",
                                            "Other Issues"))
        )
      
      summary_stats <- data.frame(
        metric = c("Total Records", 
                   "Manually Corrected\n(Human-reviewed & fixed)", 
                   "Auto-Detected\n(Needs human review)"),
        value = c(format(total_records, big.mark=","),
                  sprintf("%d (%.1f%%)", manually_corrected_count, manually_corrected_count/total_records*100),
                  sprintf("%d (%.1f%%)", flagged_records, flagged_records/total_records*100))
      )
      
      p18_left <- ggplot(summary_stats, aes(x = metric, y = 1, label = value)) +
        geom_text(size = 5, fontface = "bold") +
        labs(title = "Key Metrics", 
             subtitle = "Manually corrected = fixed by human review\nAuto-detected = algorithm-identified potential issues") +
        theme_void() +
        theme(plot.title = element_text(hjust = 0.5, size = 12, face = "bold"),
              plot.subtitle = element_text(hjust = 0.5, size = 8, color = "gray50"))
      
      p18_right <- ggplot(review_classification, aes(x = "", y = percentage, fill = review_source)) +
        geom_bar(stat = "identity", width = 1, alpha = 0.85) +
        coord_polar("y", start = 0) +
        geom_text(aes(label = sprintf("%s\n%.1f%%", count, percentage)), 
                  position = position_stack(vjust = 0.5), size = 3) +
        scale_fill_manual(
          values = c("Temporal Issues" = "#D32F2F",
                     "Metrics Issues" = "#FF8C00",
                     "Amount/Input Flags" = "#7B1FA2",
                     "Interval Format Errors" = "#1976D2",
                     "Timestamp Format Errors" = "#388E3C",
                     "Other Issues" = "#9E9E9E"),
          name = "Issue Type"
        ) +
        labs(title = "Auto-Detected Issues Breakdown",
             subtitle = sprintf("Total: %s records flagged by algorithm", format(flagged_records, big.mark=","))) +
        theme_void() +
        theme(plot.title = element_text(hjust = 0.5, size = 11, face = "bold"),
              plot.subtitle = element_text(hjust = 0.5, size = 8, color = "gray50"),
              legend.position = "right",
              legend.text = element_text(size = 8))
      
      p18 <- (p18_left | p18_right) + 
        plot_layout(widths = c(0.45, 0.55)) +
        plot_annotation(
          title = "Figure 18: Auto-Detected Review Flags Dashboard",
          subtitle = sprintf("Based on auto-detection from checkforerrors_processing.R | %d records (%.1f%%) need review, %d (%.1f%%) already corrected",
                             flagged_records, flagged_records/total_records*100,
                             manually_corrected_count, manually_corrected_count/total_records*100),
          theme = theme(plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
                        plot.subtitle = element_text(hjust = 0.5, size = 9))
        )
      
      print(p18)
  save_png(p18, "18_Auto_Detected_Dashboard", subdir = "pipeline_cleaning")
      cat("✓ Figure 18 completed (using checkforerrors_processing.R output)\n\n")
      
      cat("\n--- Auto-Detected Issues Breakdown (Figure 18) ---\n")
      print(review_classification)
      
      cat("\n--- Interpretation Guide for Figure 18 ---\n")
      cat("  • Manually Corrected: Records fixed by human review (no longer need attention)\n")
      cat("  • Auto-Detected: Algorithm-flagged records requiring human review\n")
      cat("  • Temporal Issues: Chronological order errors (e.g., sleep before bed)\n")
      cat("  • Metrics Issues: Abnormal SOL, SE, or TST/TIB ratio\n")
      cat("  • Amount/Input Flags: Substance amount input anomalies\n")
      cat("  • Interval Format: Duration values with formatting issues\n")
      cat("  • Timestamp Format: Time values with formatting issues\n")
      
      overlap <- sum(corrected_ema_data$manually_corrected & 
                       corrected_ema_data$row_id %in% checkforerrors_df$row_id, na.rm = TRUE)
      
      cat(sprintf("\n--- Quality Check ---\n"))
      cat(sprintf("  Overlap (corrected but still flagged by algorithm): %d\n", overlap))
      if(overlap == 0) {
        cat("  ✓ Good: No corrected records appear in auto-detected list\n")
      } else {
        cat("  ⚠ Warning: Some corrected records still flagged - may need re-review\n")
      }
      
    } else {
      cat("⚠ 'auto_error_desc' column not found in checkforerrors_df\n")
    }
    
  } else {
    cat("⚠ review_output or checkforerrors_df not available\n")
    cat("  Please run: source('checkforerrors_processing.R') to generate review_output\n")
  }
}

# ============================================================================
# FIGURES 19-21: UNIFIED CLASSIFICATION SUMMARY (Based on checkforerrors_summary)
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\nSTEP 8: GENERATING FIGURES 19-21 (Unified Classification)\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\n\n")

if (exists("checkforerrors_summary") && is.list(checkforerrors_summary) && 
    "review_summary" %in% names(checkforerrors_summary)) {
  
  review_summary <- checkforerrors_summary$review_summary
  
  # --------------------------------------------------------------------------
  # Figure 19: Final Data Quality Status
  # --------------------------------------------------------------------------
  # WHAT THIS FIGURE SHOWS:
  #   Unified classification of all 13990 records after corrections.
  #
  # CATEGORIES:
  #   CLEAN                         — no issues detected across all checks
  #   CLEAN (Manually Fixed)        — had issues, corrected in Step 6
  #   TIMESTAMP_ISSUE               — clock-time format errors (bed/sleep/awake/getup)
  #   DURATION_ISSUE                — interval/format errors (SOL, WASO)
  #   AMOUNT_FLAG                   — substance input anomalies
  #   NEEDS_REVIEW                  — metric anomalies with no other flag type
  #
  # NEEDS_REVIEW DETAIL (72 records):
  #   Source: checkforerrors_processing.R Part C — auto-detected sleep metric
  #   anomalies that survive all corrections but are NOT timestamp/duration/
  #   substance-amount errors (those have zero flags in Parts A/B).
  #
  #   Breakdown (current data):
  #     SOL excessive ( > 120 min )          61   ← e.g. pid=1518 day=14 SOL=195min
  #     SOL zero      ( == 0 min )            2   ← bedtime == sleeptime
  #     SOL lt15      ( < 15 min )            3   ← unusually fast onset
  #     SE anomalies  ( efficiency < 0% )     6   ← calculation error or extreme
  #                          Total:          72
  #
  #   These records have valid timestamps and valid duration formats — the
  #   derived metric itself falls outside normal physiological range. Each
  #   requires case-by-case human judgment (genuine insomnia vs data error).
  # --------------------------------------------------------------------------
  cat("Generating Figure 19...\n")
  
  if (nrow(review_summary) > 0 && "final_status" %in% names(review_summary)) {
    p19_data <- review_summary %>%
      filter(!is.na(final_status)) %>%
      group_by(final_status) %>%
      summarise(n = n(), .groups = "drop") %>%
      mutate(pct = n / sum(n) * 100)
    
    if (nrow(p19_data) > 0) {
      p19 <- ggplot(p19_data, aes(x = reorder(final_status, -n), y = n, fill = final_status)) +
        geom_col(alpha = 0.8) +
        geom_text(aes(label = paste0(n, "\n(", round(pct, 1), "%)")), vjust = -0.3, size = 3) +
        scale_fill_manual(values = c("CLEAN" = "#2E7D32",
                                     "CLEAN (Manually Fixed)" = "#4CAF50",
                                     "TIMESTAMP_ISSUE" = "#D32F2F",
                                     "DURATION_ISSUE" = "#FF8C00",
                                     "AMOUNT_FLAG" = "#1976D2",
                                     "SELF_REPORTED_FLAG" = "#9E9E9E")) +
        labs(title = "Figure 19: Final Data Quality Status (Unified Classification)",
             subtitle = "Unified classification from checkforerrors_summary. SELF-REPORTED FLAG = diary-based SOL/WASO metrics anomalies (not data errors). Run after pipeline Steps 1-8.",
             x = "", y = "Count") +
        theme_minimal(base_size = 12) +
        theme(axis.text.x = element_text(angle = 45, hjust = 1),
              legend.position = "none")
      print(p19)
  save_png(p19, "19_Unified_Quality_Status", subdir = "pipeline_cleaning")
      cat("✓ Figure 19 completed\n\n")
    }
  }
  
  # --------------------------------------------------------------------------
  # Figure P26: Per-Participant Final Flag Rate
  # --------------------------------------------------------------------------
  cat("Generating FIGURE P26 (Per-Participant Flag Rate)...\n")
  
  if ("flag_severity" %in% names(clean_df) && "pid" %in% names(clean_df)) {
    pid_flags <- clean_df %>%
      filter(!is.na(flag_severity)) %>%
      group_by(pid, flag_severity) %>%
      summarise(n = n(), .groups = "drop") %>%
      group_by(pid) %>%
      mutate(total = sum(n), pct = n / total * 100) %>%
      ungroup()
    
    pid_order <- pid_flags %>%
      filter(flag_severity == "Clean") %>%
      arrange(desc(pct)) %>%
      pull(pid)
    
    pid_flags$pid <- factor(pid_flags$pid, levels = rev(pid_order))
    
    p_p26 <- ggplot(pid_flags, aes(x = pid, y = pct, fill = flag_severity)) +
      geom_col(alpha = 0.8, width = 0.9) +
      scale_fill_manual(values = c("Clean" = "#2E7D32",
                                   "Minor issues (1 flag)" = "#FF8C00",
                                   "Major issues (2+ flags)" = "#D32F2F"),
                        name = "Data Quality") +
      labs(title = "Figure P26: Per-Participant Data Quality (Final Corrected Data)",
           subtitle = paste0("Each bar = one participant (N=", length(unique(clean_df$pid)),
                             "). Sorted by Clean% descending. Minor = 1 flag, Major = 2+ flags from {SE<",
                             cfg_get("classification.flag_severity.poor_efficiency_threshold_pct", 70),
                             "%, SOL>", cfg_get("classification.flag_severity.high_sol_threshold_hours", 1),
                             "h, WASO>", cfg_get("classification.flag_severity.high_waso_threshold_hours", 1.5), "h}."),
           x = "Participant ID", y = "% of Participant's Records") +
      theme_minimal(base_size = 9) +
      theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5, size = 5),
            legend.position = "bottom")
    print(p_p26)
    save_png(p_p26, "P26_PerParticipant_Flag_Rate", subdir = "pipeline_cleaning")
    cat("✓ Figure P26 completed\n\n")
  } else {
    cat("⚠ Missing flag_severity or pid — skipping Figure P26\n\n")
  }
  
  # --------------------------------------------------------------------------
  # Figure 20: SOL Perception Bias (主观 vs 客观)
  # 客观 SOL = time_sleep_corrected - time_bed_corrected
  # 主观 SOL = duration_totalmin_sol_estimate_am
  # --------------------------------------------------------------------------
  cat("Generating Figure 20 (SOL bias: subjective vs objective)...\n")
  
  # 客观 SOL（基于校正后的时间戳）
  obj_sol <- as.numeric(difftime(corrected_ema_data$time_sleep_corrected, 
                                 corrected_ema_data$time_bed_corrected, 
                                 units = "mins"))
  
  # 主观 SOL（用户填写的 HH:MM）
  subj_sol <- rep(NA_real_, nrow(corrected_ema_data))
  self_raw <- corrected_ema_data$duration_totalmin_sol_estimate_am
  valid_idx <- which(grepl("^\\d{1,2}:\\d{2}$", self_raw))
  if (length(valid_idx) > 0) {
    parts <- strsplit(self_raw[valid_idx], ":")
    hours <- as.numeric(sapply(parts, `[`, 1))
    minutes <- as.numeric(sapply(parts, `[`, 2))
    subj_sol[valid_idx] <- hours * 60 + minutes
  }
  
  valid_rows <- which(!is.na(obj_sol) & !is.na(subj_sol))
  
  if (length(valid_rows) > 0) {
    bias_sol <- abs(obj_sol[valid_rows] - subj_sol[valid_rows])
    bias_counts <- data.frame(bias = bias_sol) %>% group_by(bias) %>% summarise(count = n(), .groups = "drop")
    
    cat("  客观 SOL (time_sleep_corrected - time_bed_corrected) 非 NA 数:", sum(!is.na(obj_sol)), "\n")
    cat("  主观 SOL 有效解析数:", sum(!is.na(subj_sol)), "\n")
    cat("  两者都非 NA 的行数:", length(valid_rows), "\n")
    cat("  偏差统计: min =", min(bias_sol), "max =", max(bias_sol), 
        "mean =", round(mean(bias_sol), 2), "\n")
    
    p20 <- ggplot(bias_counts, aes(x = bias, y = count)) +
      geom_col(fill = "#1976D2", alpha = 0.8, width = 1) +
      geom_vline(xintercept = c(15, 60), linetype = "dashed", color = c("orange", "red"), linewidth = 1) +
      annotate("text", x = 15, y = Inf, label = "Minor (15min)", vjust = 2, color = "orange") +
      annotate("text", x = 60, y = Inf, label = "Red Line (60min)", vjust = 2, color = "red") +
      labs(title = "Figure 20: SOL Perception Bias (Subjective vs Objective)",
      subtitle = paste0("Absolute difference: subjective SOL (self-reported duration_totalmin_sol_estimate_am) vs objective SOL (time_sleep - time_bed). ",
                        "N=", length(valid_rows), " | Clinical: <15min typical, >60min significant discrepancy."),
           x = "Absolute difference (minutes)", y = "Count") +
      scale_x_continuous(limits = c(0, 200)) +
      theme_minimal(base_size = 12)
    
    print(p20)
  save_png(p20, "20_SOL_Perception_Bias", subdir = "research_ready")
    cat("✓ Figure 20 completed\n\n")
  } else {
    cat("⚠ No valid SOL bias data.\n\n")
  }
  
  # --------------------------------------------------------------------------
  # Figure 20B: WASO Perception Bias (with same thresholds as SOL)
  # 客观 WASO = time_getup_corrected - time_awake_corrected
  # 主观 WASO = duration_totalmin_waso_estimate_am
  # Thresholds: Minor = 15min, Red Line = 60min (same as SOL)
  # --------------------------------------------------------------------------
  cat("Generating Figure 20B (WASO bias: subjective vs objective)...\n")
  
  if (exists("corrected_ema_data")) {
    
    waso_cols_ok <- all(c("time_getup_corrected", "time_awake_corrected",
                          "duration_totalmin_waso_estimate_am") %in% names(corrected_ema_data))
    
    if (waso_cols_ok) {
      obj_waso <- as.numeric(difftime(corrected_ema_data$time_getup_corrected, 
                                      corrected_ema_data$time_awake_corrected, 
                                      units = "mins"))
      
      subj_waso <- rep(NA_real_, nrow(corrected_ema_data))
      waso_raw <- corrected_ema_data$duration_totalmin_waso_estimate_am
      valid_waso_idx <- which(grepl("^\\d{1,2}:\\d{2}$", waso_raw))
      if (length(valid_waso_idx) > 0) {
        parts <- strsplit(waso_raw[valid_waso_idx], ":")
        hours <- as.numeric(sapply(parts, `[`, 1))
        minutes <- as.numeric(sapply(parts, `[`, 2))
        subj_waso[valid_waso_idx] <- hours * 60 + minutes
      }
      
      valid_waso_rows <- which(!is.na(obj_waso) & !is.na(subj_waso))
      
      if (length(valid_waso_rows) > 0) {
        bias_waso <- abs(obj_waso[valid_waso_rows] - subj_waso[valid_waso_rows])
        waso_df <- data.frame(bias = bias_waso)
        
        p20b <- ggplot(waso_df, aes(x = bias)) +
          geom_histogram(binwidth = 5, fill = "#FF8C00", alpha = 0.7, boundary = 0) +
          geom_vline(xintercept = c(15, 60), linetype = "dashed", color = c("orange", "red"), linewidth = 1) +
          annotate("text", x = 15, y = Inf, label = "Minor (15min)", vjust = 2, color = "orange") +
          annotate("text", x = 60, y = Inf, label = "Red Line (60min)", vjust = 2, color = "red") +
          labs(title = "Figure 20B: WASO Perception Bias (Subjective vs Objective)",
           subtitle = paste0("Absolute difference: subjective WASO (self-reported duration_totalmin_waso_estimate_am) vs objective WASO (time_getup - time_awake). ",
                             "N=", length(valid_waso_rows), " | Clinical: <15min typical, >60min significant discrepancy."),
               x = "Absolute difference (minutes)", y = "Count") +
          scale_x_continuous(limits = c(0, 200)) +
          theme_minimal(base_size = 12)
        
        print(p20b)
  save_png(p20b, "20B_WASO_Perception_Bias", subdir = "research_ready")
        cat("✓ Figure 20B completed\n\n")
        
        cat("  Objective WASO non-NA:", sum(!is.na(obj_waso)), "\n")
        cat("  Subjective WASO parsed:", sum(!is.na(subj_waso)), "\n")
        cat("  Valid pairs:", length(valid_waso_rows), "\n\n")
        
      } else {
        cat("⚠ No valid WASO bias data.\n\n")
      }
    } else {
      cat("⚠ Missing WASO columns. Skipping Figure 20B.\n\n")
    }
  } else {
    cat("⚠ corrected_ema_data not found. Skipping Figure 20B.\n\n")
  }
  
  
  # --------------------------------------------------------------------------
  # Figure 21: Substance Use Data Availability
  # --------------------------------------------------------------------------
  cat("Generating Figure 21...\n")
  
  subst_cols <- list(
    Caffeine = "caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1",
    Alcohol = "alcoholtoday_PM_NumAlcoholicDrinks_1",
    Nicotine = "nicotine_amount_pm_doses",
    Cannabis = "cannabis_amount_pm_doses"
  )
  
  subst_summary <- data.frame()
  total_n <- nrow(corrected_ema_data)
  
  for (nm in names(subst_cols)) {
    col <- subst_cols[[nm]]
    if (col %in% names(corrected_ema_data)) {
      val <- corrected_ema_data[[col]]
      n_non_na <- sum(!is.na(val))
      vals <- val[!is.na(val)]
      rng <- if (length(vals) > 0) paste0(min(vals), " - ", max(vals)) else "NA"
      med <- if (length(vals) > 0) round(median(vals), 1) else NA
    } else {
      n_non_na <- 0
      rng <- "NA"
      med <- NA
    }
    n_missing <- total_n - n_non_na
    subst_summary <- rbind(subst_summary, data.frame(
      substance = nm,
      n_non_na = n_non_na,
      n_missing = n_missing,
      pct = round(n_non_na / total_n * 100, 1),
      range = rng,
      median = med,
      stringsAsFactors = FALSE
    ))
  }
  
  p21 <- ggplot(subst_summary, aes(x = reorder(substance, -n_non_na), y = pct, fill = substance)) +
    geom_col(alpha = 0.8, width = 0.7) +
    geom_text(aes(label = paste0(n_non_na, "/", total_n, " (", pct, "%)  range: ", range)),
              vjust = -0.3, size = 3.5) +
    labs(title = "Figure 21: Substance Use Data Availability",
         subtitle = paste("Non-NA entries and value range for each substance variable (total N =", total_n, ")"),
         x = "", y = "% of records with data") +
    scale_fill_brewer(palette = "Set2") +
    scale_y_continuous(limits = c(0, max(10, subst_summary$pct + 5))) +
    theme_minimal(base_size = 12) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1),
          legend.position = "none")
  
  print(p21)
  save_png(p21, "21_Substance_Use_Availability", subdir = "research_ready")
  cat("✓ Figure 21 completed\n\n")
  
  # --------------------------------------------------------------------------
  # Figure 22: Substance Use Value Distribution (Detailed Statistics)
  # --------------------------------------------------------------------------
  cat("Generating Figure 22 (Substance Use Value Distribution)...\n")
  
  # Define substance columns and units
  subst_list <- list(
    Caffeine = list(
      col = "caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1",
      unit = "cups"
    ),
    Alcohol = list(
      col = "alcoholtoday_PM_NumAlcoholicDrinks_1", 
      unit = "standard drinks"
    ),
    Nicotine = list(
      col = "nicotine_amount_pm_doses",
      unit = "doses"
    ),
    Cannabis = list(
      col = "cannabis_amount_pm_doses",
      unit = "doses"
    )
  )
  
  # Prepare data for plotting
  plot_data <- data.frame()
  stats_table <- data.frame()
  
  for (subst in names(subst_list)) {
    info <- subst_list[[subst]]
    col_name <- info$col
    
    if (col_name %in% names(corrected_ema_data)) {
      values <- corrected_ema_data[[col_name]]
      non_na <- values[!is.na(values)]
      
      if (length(non_na) > 0) {
        # Add to plot data
        plot_data <- rbind(plot_data, data.frame(
          Substance = subst,
          Value = non_na,
          Unit = info$unit,
          stringsAsFactors = FALSE
        ))
        
        # Calculate statistics
        stats_table <- rbind(stats_table, data.frame(
          Substance = subst,
          N = length(non_na),
          Missing = sum(is.na(values)),
          Min = min(non_na),
          Max = max(non_na),
          Mean = round(mean(non_na), 2),
          Median = median(non_na),
          SD = round(sd(non_na), 2),
          Unit = info$unit,
          stringsAsFactors = FALSE
        ))
      } else {
        # No valid data
        stats_table <- rbind(stats_table, data.frame(
          Substance = subst,
          N = 0,
          Missing = nrow(corrected_ema_data),
          Min = NA,
          Max = NA,
          Mean = NA,
          Median = NA,
          SD = NA,
          Unit = info$unit,
          stringsAsFactors = FALSE
        ))
      }
    }
  }
  
  if (nrow(plot_data) > 0) {
    # Create boxplot with jitter
    p22 <- ggplot(plot_data, aes(x = Substance, y = Value, fill = Substance)) +
      geom_boxplot(alpha = 0.7, outlier.shape = NA) +
      geom_jitter(width = 0.2, alpha = 0.3, size = 0.8, color = "gray30") +
      labs(
        title = "Figure 22: Substance Use Value Distribution",
        subtitle = "Boxplots show distribution of reported self-report values",
        y = "Reported Value", 
        x = ""
      ) +
      scale_fill_brewer(palette = "Set2") +
      theme_minimal(base_size = 12) +
      theme(legend.position = "none")
    
    print(p22)
  save_png(p22, "22_Substance_Use_Distribution", subdir = "research_ready")
    cat("✓ Figure 22 completed\n\n")
    
    # Print statistics table to console
    cat("--- Substance Use Statistics (Figure 22 data) ---\n")
    print(stats_table)
    cat("\n")
    
  } else {
    cat("⚠ No substance use data available for Figure 22\n\n")
  }
}

# ============================================================================
# FIGURES 23-24: SUBSTANCE CONSUMPTION DISTRIBUTIONS
# ============================================================================
# DATA SOURCE: corrected_ema_data
# WHAT THEY SHOW: Distribution of caffeine and alcohol self-report values
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\nSTEP 9: GENERATING FIGURES 23-24 (Substance Consumption Distributions)\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\n\n")

# --------------------------------------------------------------------------
# Figure 23: Caffeine Consumption Distribution
# --------------------------------------------------------------------------
cat("Generating Figure 23 (Caffeine consumption)...\n")

caf_col <- "caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1"
if (exists("corrected_ema_data") && caf_col %in% names(corrected_ema_data)) {
  caf_vals <- corrected_ema_data[[caf_col]]
  caf_non_na <- caf_vals[!is.na(caf_vals)]

  if (length(caf_non_na) > 0) {
    caf_df <- data.frame(caffeine_cups = caf_non_na)

    caf_summary <- caf_df %>%
      group_by(caffeine_cups) %>%
      summarise(n = n(), .groups = "drop") %>%
      mutate(pct = n / sum(n) * 100)

    p23 <- ggplot(caf_summary, aes(x = caffeine_cups, y = n)) +
      geom_col(alpha = 0.85, width = 0.7, fill = "#1976D2") +
      geom_text(aes(label = paste0(n, " (", round(pct, 1), "%)")),
                vjust = -0.3, size = 3) +
      scale_x_continuous(breaks = seq(0, max(caf_summary$caffeine_cups), by = 1)) +
      labs(title = "Figure 23: Caffeine Consumption Distribution",
           subtitle = sprintf("Based on %d non-NA records | Median: %d cups | Range: %d - %d",
                              length(caf_non_na), median(caf_non_na), min(caf_non_na), max(caf_non_na)),
           x = "Caffeine (cups/day)", y = "Count") +
      theme_minimal(base_size = 12)

    print(p23)
  save_png(p23, "23_Caffeine_Consumption", subdir = "research_ready")
    cat(sprintf("✓ Figure 23 completed (%d non-NA records)\n\n", length(caf_non_na)))
  }
}

# --------------------------------------------------------------------------
# Figure 24: Alcohol Consumption Distribution
# --------------------------------------------------------------------------
cat("Generating Figure 24 (Alcohol consumption)...\n")

alc_col <- "alcoholtoday_PM_NumAlcoholicDrinks_1"
if (exists("corrected_ema_data") && alc_col %in% names(corrected_ema_data)) {
  alc_vals <- corrected_ema_data[[alc_col]]
  alc_non_na <- alc_vals[!is.na(alc_vals)]

  if (length(alc_non_na) > 0) {
    alc_df <- data.frame(alcohol_drinks = alc_non_na)

    alc_summary <- alc_df %>%
      group_by(alcohol_drinks) %>%
      summarise(n = n(), .groups = "drop") %>%
      mutate(pct = n / sum(n) * 100)

    p24 <- ggplot(alc_summary, aes(x = alcohol_drinks, y = n)) +
      geom_col(alpha = 0.85, width = 0.7, fill = "#FF8C00") +
      geom_text(aes(label = paste0(n, " (", round(pct, 1), "%)")),
                vjust = -0.3, size = 3) +
      scale_x_continuous(breaks = seq(0, max(alc_summary$alcohol_drinks), by = 1)) +
      labs(title = "Figure 24: Alcohol Consumption Distribution",
           subtitle = sprintf("Based on %d non-NA records | Median: %d drinks | Range: %d - %d",
                              length(alc_non_na), median(alc_non_na), min(alc_non_na), max(alc_non_na)),
           x = "Alcohol (drinks/day)", y = "Count") +
      theme_minimal(base_size = 12)

    print(p24)
  save_png(p24, "24_Alcohol_Consumption", subdir = "research_ready")
    cat(sprintf("✓ Figure 24 completed (%d non-NA records)\n\n", length(alc_non_na)))
  }
}

# --------------------------------------------------------------------------
# Figure R25: Sleep Regularity — Weekday vs Weekend
# --------------------------------------------------------------------------
cat("Generating FIGURE R25 (Sleep Regularity: Weekday vs Weekend)...\n")

if (all(c("time_bed_corrected", "time_getup_corrected") %in% names(corrected_ema_data))) {
  cat("  R25: columns found, processing...\n")
  cat("  R25: time_bed_corrected class:", class(corrected_ema_data$time_bed_corrected)[1], "\n")
  
  n_bed <- sum(!is.na(corrected_ema_data$time_bed_corrected))
  n_getup <- sum(!is.na(corrected_ema_data$time_getup_corrected))
  cat("  R25: non-NA time_bed:", n_bed, " time_getup:", n_getup, "\n")
  
  if (n_bed > 0 && n_getup > 0) {
    is_posix <- inherits(corrected_ema_data$time_bed_corrected, "POSIXct")
    cat("  R25: is POSIXct:", is_posix, "\n")
    
    if (is_posix) {
      sr <- corrected_ema_data %>%
        filter(!is.na(time_bed_corrected), !is.na(time_getup_corrected)) %>%
        mutate(
          wd = lubridate::wday(time_bed_corrected, week_start = 1),
          day_type = ifelse(wd >= 6, "Weekend", "Weekday"),
          bed_hour = as.numeric(format(time_bed_corrected, "%H")) + 
            as.numeric(format(time_bed_corrected, "%M")) / 60,
          getup_hour = as.numeric(format(time_getup_corrected, "%H")) + 
            as.numeric(format(time_getup_corrected, "%M")) / 60
        )
    } else {
      sr <- corrected_ema_data %>%
        filter(!is.na(time_bed_corrected), !is.na(time_getup_corrected)) %>%
        mutate(
          wd = lubridate::wday(time_bed_corrected, week_start = 1),
          day_type = ifelse(wd >= 6, "Weekend", "Weekday"),
          bed_hour = lubridate::hour(time_bed_corrected) + lubridate::minute(time_bed_corrected) / 60,
          getup_hour = lubridate::hour(time_getup_corrected) + lubridate::minute(time_getup_corrected) / 60
        )
    }
    sr$bed_hour <- ifelse(sr$bed_hour < 12, sr$bed_hour + 24, sr$bed_hour)

    sr_long <- sr %>%
      select(pid, day_type, bed_hour, getup_hour) %>%
      reshape2::melt(id.vars = c("pid", "day_type"), variable.name = "event", value.name = "hour") %>%
      mutate(event = ifelse(event == "bed_hour", "Bedtime", "Get-up Time"))

    p_r25 <- ggplot(sr_long, aes(x = day_type, y = hour, fill = day_type)) +
      geom_violin(alpha = 0.4, trim = FALSE) +
      geom_boxplot(width = 0.2, outlier.alpha = 0.3, outlier.size = 0.5) +
      stat_summary(fun = median, geom = "point", size = 2, color = "black") +
      facet_wrap(~event, scales = "free_y") +
      scale_fill_manual(values = c("Weekday" = "#1976D2", "Weekend" = "#FF8C00")) +
      labs(title = "Figure R25: Sleep Regularity — Weekday vs Weekend",
           subtitle = paste0("Violin + boxplot of bedtime and get-up time by day type (Weekend = Sat/Sun). ",
                             "Bedtime hours >12 indicate AM. N=", nrow(sr), " records."),
           x = "", y = "Clock Hour") +
      theme_minimal(base_size = 11) +
      theme(legend.position = "bottom")
    print(p_r25)
    save_png(p_r25, "R25_Sleep_Regularity_Weekday_Weekend", subdir = "research_ready")
    cat("✓ Figure R25 completed\n\n")
  } else {
    cat("  R25: no non-NA records found — skipping\n\n")
  }
} else {
  cat("⚠ Missing required columns (time_bed_corrected, time_getup_corrected) — skipping Figure R25\n\n")
}

# --------------------------------------------------------------------------
# Figure R26: Sleep Composition — TIB = TST + SOL + WASO
# --------------------------------------------------------------------------
cat("Generating FIGURE R26 (Sleep Composition)...\n")

if (all(c("self_diffcalc_totalsleeptime_minutes", "self_diffcalc_sol_minutes",
          "duration_totalmin_waso_estimate_am_mincalc_used") %in% names(corrected_ema_data))) {
  sc <- corrected_ema_data %>%
    filter(
      !is.na(self_diffcalc_totalsleeptime_minutes),
      !is.na(self_diffcalc_sol_minutes),
      !is.na(duration_totalmin_waso_estimate_am_mincalc_used),
      self_diffcalc_totalsleeptime_minutes > 0
    ) %>%
    mutate(
      total = self_diffcalc_totalsleeptime_minutes + self_diffcalc_sol_minutes + duration_totalmin_waso_estimate_am_mincalc_used,
      sol_pct = self_diffcalc_sol_minutes / total * 100,
      waso_pct = duration_totalmin_waso_estimate_am_mincalc_used / total * 100,
      tst_pct = self_diffcalc_totalsleeptime_minutes / total * 100
    )

  avg_comp <- data.frame(
    component = c("Total Sleep Time (TST)", "Sleep Onset Latency (SOL)", "Wake After Sleep Onset (WASO)"),
    pct = c(mean(sc$tst_pct, na.rm = TRUE), mean(sc$sol_pct, na.rm = TRUE), mean(sc$waso_pct, na.rm = TRUE)),
    stringsAsFactors = FALSE
  )

  p_r26 <- ggplot(avg_comp, aes(x = "", y = pct, fill = component)) +
    geom_bar(stat = "identity", width = 1, alpha = 0.85) +
    coord_polar("y", start = 0) +
    geom_text(aes(label = sprintf("%.1f%%", pct)), position = position_stack(vjust = 0.5), size = 4) +
    scale_fill_manual(values = c("Total Sleep Time (TST)" = "#2E7D32",
                                 "Sleep Onset Latency (SOL)" = "#FF8C00",
                                 "Wake After Sleep Onset (WASO)" = "#D32F2F")) +
    labs(title = "Figure R26: Sleep Composition — TIB Breakdown",
         subtitle = paste0("Average proportion of Time in Bed spent in each stage (N=", nrow(sc),
                           " valid records after pipeline correction). TIB = TST + SOL + WASO."),
         x = "", y = "") +
    theme_void(base_size = 12) +
    theme(legend.position = "bottom")
  print(p_r26)
  save_png(p_r26, "R26_Sleep_Composition_TIB_Breakdown", subdir = "research_ready")
  cat("✓ Figure R26 completed\n\n")
} else {
  cat("⚠ Missing required columns — skipping Figure R26\n\n")
}

# --------------------------------------------------------------------------
# Figure R27: Sleep Metrics Correlation Matrix
# --------------------------------------------------------------------------
cat("Generating FIGURE R27 (Sleep Metrics Correlation Matrix)...\n")

if (requireNamespace("corrplot", quietly = TRUE) &&
    all(c("self_diffcalc_totalsleeptime_minutes", "self_diffcalc_sol_minutes",
          "duration_totalmin_waso_estimate_am_mincalc_used", "self_diffcalc_sleepefficiency_percent",
          "self_diffcalc_timeinbed_minutes") %in% names(corrected_ema_data))) {

  cor_data <- corrected_ema_data %>%
    select(
      TST = self_diffcalc_totalsleeptime_minutes,
      SOL = self_diffcalc_sol_minutes,
      WASO = duration_totalmin_waso_estimate_am_mincalc_used,
      SE = self_diffcalc_sleepefficiency_percent,
      TIB = self_diffcalc_timeinbed_minutes
    ) %>%
    na.omit()

  if (nrow(cor_data) > 50) {
    M <- cor(cor_data, use = "pairwise.complete.obs")

    png(file.path(output_dir, "research_ready", "R27_Sleep_Metrics_Correlation_Matrix.png"),
        width = 8, height = 7, units = "in", res = 150)
    corrplot::corrplot(M, method = "color", type = "upper",
                       tl.col = "black", tl.cex = 0.8,
                       addCoef.col = "black", number.cex = 0.7,
                       col = colorRampPalette(c("#D32F2F", "white", "#2E7D32"))(200),
                       title = "Figure R27: Sleep Metrics Correlation Matrix",
                       mar = c(2, 2, 3, 2))
    mtext(side = 3, line = 0.5, cex = 0.8,
          sprintf("Pairwise Pearson correlations (N=%d valid records after pipeline correction). Red = negative, Green = positive.", nrow(cor_data)))
    dev.off()
    # Also save to master directory
    file.copy(file.path(output_dir, "research_ready", "R27_Sleep_Metrics_Correlation_Matrix.png"),
              file.path(output_dir, "R27_Sleep_Metrics_Correlation_Matrix.png"))
    cat("✓ Figure R27 completed\n\n")
  } else {
    cat("⚠ Too few records for correlation matrix — skipping Figure R27\n\n")
  }
} else {
  cat("⚠ corrplot package or required columns missing — skipping Figure R27\n\n")
}


# ============================================================================
# COMPLETE FIGURE SUMMARY
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\nCOMPLETE FIGURE SUMMARY\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\n\n")

cat("FIGURES 1-12 (Based on FINAL CORRECTED DATA - Post-Correction):\n")
cat("  Source: corrected_ema_data from apply_manual_corrections_and_recalculate()\n")
cat("  What they show: Final dataset after all manual corrections applied\n")
cat("  Figure 1: Final Data Quality Dashboard (Post-Correction)\n")
cat("  Figure 2: Distribution of Sleep Variables\n")
cat("  Figure 3: Sleep Duration Distribution\n")
cat("  Figure 4: Sleep Duration vs Time in Bed (COLOR-CODED)\n")
cat("  Figure 4B: SOL vs Sleep Duration (COLOR-CODED)\n")
cat("  Figure 5: Variability of Sleep Variables (Violin Plot)\n")
cat("  Figure 6: Clean vs Unusual Comparison\n")
cat("  Figure 7: Flag Composition (Stacked Histogram)\n")
cat("  Figure 8: Sleep Duration by Data Category\n")
cat("  Figure 9: Bedtime vs Get-up Time Distribution\n")
cat("  Figure 10: Extreme Durations with Efficiency (COLOR-CODED)\n")
cat("  Figure 11: Flag Co-occurrence Heatmap\n")
cat("  Figure 12: Pipeline Correction Progress (Three-Panel Table)\n\n")

if(checkforerrors_exists && nrow(checkforerrors_processed) > 0) {
  cat("FIGURES 13-18 (Based on AUTO-DETECTION - Pre-Correction):\n")
  cat("  Source: review_output from checkforerrors_processing.R (checkforerrors_df)\n")
  cat("  What they show: Algorithm-detected potential issues needing human review\n")
  cat("  Figure 13: Error Category Distribution (Auto-Detection)\n")
  cat("  Figure 14: Flagged vs Clean Sleep Duration (Auto-Detection)\n")
  cat("  Figure 15: Error Timeline Over Study Period (Auto-Detection)\n")
  cat("  Figure 16: Most Common Error Patterns (Auto-Detection)\n")
  cat("  Figure 17: Top 15 Participants with Most Review Flags (Auto-Detection)\n")
  cat("  Figure 18: Auto-Detected Review Flags Dashboard\n\n")
} else {
  cat("FIGURES 13-18: SKIPPED (no checkforerrors data available)\n\n")
}

cat("ADDITIONAL PIPELINE CLEANING FIGURES:\n")
cat("  Figure 19: Unified Classification (checkforerrors_summary)\n")
cat("  Figure P26: Per-Participant Final Flag Rate\n\n")

cat("FIGURES 20-24 (Research: Sleep Perception + Substance Use):\n")
cat("  Figure 20: SOL Perception Bias\n")
cat("  Figure 20B: WASO Perception Bias\n")
cat("  Figure 21: Substance Use Availability\n")
cat("  Figure 22: Substance Use Distribution\n")
cat("  Figure 23: Caffeine Consumption\n")
cat("  Figure 24: Alcohol Consumption\n\n")

cat("ADDITIONAL RESEARCH FIGURES:\n")
cat("  Figure R25: Sleep Regularity — Weekday vs Weekend\n")
cat("  Figure R26: Sleep Composition — TIB = TST + SOL + WASO\n")
cat("  Figure R27: Sleep Metrics Correlation Matrix\n\n")

cat("FOLDER STRUCTURE:\n")
cat("  latest_visualization/pipeline_cleaning/  — Data cleaning pipeline progress & quality control\n")
cat("  latest_visualization/research_ready/     — Sleep metrics, substance use & perception for analysis\n\n")

cat("NOTE: Figures 1-12 show the FINAL corrected data (after manual fixes)\n")
cat("      Figures 13-18 show AUTO-DETECTED issues (before manual review)\n")
cat("      These two sets serve different purposes and are not directly comparable.\n")

# ============================================================================
# STATISTICAL SUMMARY
# ============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\nSTATISTICAL SUMMARY\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\n")

if("sleep_duration_h" %in% names(clean_df)) {
  cat("\n--- Total Sleep Time (TST) - Based on Final Corrected Data ---\n")
  cat(sprintf("  Mean: %.2f hours\n", mean(clean_df$sleep_duration_h, na.rm = TRUE)))
  cat(sprintf("  Median: %.2f hours\n", median(clean_df$sleep_duration_h, na.rm = TRUE)))
  cat(sprintf("  SD: %.2f hours\n", sd(clean_df$sleep_duration_h, na.rm = TRUE)))
}

if(checkforerrors_exists && nrow(checkforerrors_processed) > 0) {
  cat("\n--- AUTO-DETECTION SUMMARY (From checkforerrors_processing.R) ---\n")
  cat(sprintf("  Total records needing review: %d\n", nrow(checkforerrors_processed)))
  cat(sprintf("  Percentage of all data: %.2f%%\n", nrow(checkforerrors_processed)/nrow(clean_df) * 100))
}

if("flag_severity" %in% names(clean_df)) {
  cat("\n--- Data Quality Summary (From Flag System - Final Data) ---\n")
  cat(sprintf("  Clean records: %d (%.1f%%)\n", 
              sum(clean_df$flag_severity == "Clean", na.rm = TRUE),
              mean(clean_df$flag_severity == "Clean", na.rm = TRUE) * 100))
  cat(sprintf("  Minor issues: %d (%.1f%%)\n", 
              sum(clean_df$flag_severity == "Minor issues (1 flag)", na.rm = TRUE),
              mean(clean_df$flag_severity == "Minor issues (1 flag)", na.rm = TRUE) * 100))
  cat(sprintf("  Major issues: %d (%.1f%%)\n", 
              sum(clean_df$flag_severity == "Major issues (2+ flags)", na.rm = TRUE),
              mean(clean_df$flag_severity == "Major issues (2+ flags)", na.rm = TRUE) * 100))
}

# ── Export summary tables to output folder ──
if (exists("final_classification")) {
  write.csv(final_classification, file.path(output_dir, "classification_summary.csv"), row.names = FALSE)
}
if (exists("checkforerrors_summary") && is.list(checkforerrors_summary) && "review_summary" %in% names(checkforerrors_summary)) {
  write.csv(checkforerrors_summary$review_summary, file.path(output_dir, "flag_distribution.csv"), row.names = FALSE)
}
if ("flag_severity" %in% names(clean_df)) {
  sev_summary <- clean_df %>% count(flag_severity) %>% mutate(pct = n / sum(n) * 100)
  write.csv(sev_summary, file.path(output_dir, "flag_severity_summary.csv"), row.names = FALSE)
}

# ── Update latest_visualization (replace old with current run) ──
latest_dir <- "latest_visualization"
if (dir.exists(latest_dir)) unlink(latest_dir, recursive = TRUE)
dir.create(latest_dir, showWarnings = FALSE)
viz_files <- list.files(output_dir, full.names = TRUE)
file.copy(viz_files, latest_dir, recursive = TRUE)
# Also re-create subfolder structure under latest_visualization
for (sub in c("pipeline_cleaning", "research_ready")) {
  src_sub <- file.path(output_dir, sub)
  if (dir.exists(src_sub)) {
    dst_sub <- file.path(latest_dir, sub)
    dir.create(dst_sub, showWarnings = FALSE, recursive = TRUE)
    file.copy(list.files(src_sub, full.names = TRUE), dst_sub)
  }
}
cat(sprintf("\n✓ latest_visualization/ updated → %s/\n", output_dir))
cat(sprintf("  ├── latest_visualization/pipeline_cleaning/  (%d cleaning figures)\n",
            length(list.files(file.path(output_dir, "pipeline_cleaning")))))
cat(sprintf("  └── latest_visualization/research_ready/    (%d research figures)\n",
            length(list.files(file.path(output_dir, "research_ready")))))

cat("\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\n✅ ANALYSIS COMPLETE!\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\n")
