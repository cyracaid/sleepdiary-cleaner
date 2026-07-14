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

# ============================================================================
# FUNCTION: calculate_sleep_time_vars
# ============================================================================
# Purpose: Calculate derived sleep metrics from corrected timestamps
# Input: Dataframe with time_bed_corrected, time_sleep_corrected, etc.
# Output: Dataframe with added sleep metrics (sol, tst, se, etc.)
# ============================================================================
calculate_sleep_time_vars <- function(data) {
  
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
  
  cleaned_data <- data %>%
    mutate(self_diffcalc_sol_minutes = as.numeric(difftime(time_sleep_corrected, time_bed_corrected, units = "mins"))) %>%
    mutate(self_diffcalc_sleeponset = lubridate::minutes(duration_totalmin_sol_estimate_am_mincalc) + time_sleep_corrected) %>%
    mutate(self_diffcalc_totaltrysleep_minutes = as.numeric(difftime(time_awake_corrected, time_sleep_corrected, units = "mins"))) %>%
    mutate(self_diffcalc_timeinbed_minutes = as.numeric(difftime(time_getup_corrected, time_bed_corrected, units = "mins"))) %>%
    mutate(self_diffcalc_sleepperiod_minutes = as.numeric(difftime(time_awake_corrected, self_diffcalc_sleeponset, units = "mins"))) %>%
    mutate(self_diffcalc_totalsleeptime_minutes = self_diffcalc_sleepperiod_minutes - duration_totalmin_waso_estimate_am_mincalc) %>%
    mutate(self_diffcalc_sleepefficiency_percent = self_diffcalc_totalsleeptime_minutes / self_diffcalc_totaltrysleep_minutes) %>% 
    mutate(num_waso_estimate_am = as.numeric(num_waso_estimate_am)) %>%
    mutate(avg_waso_estimate_am_minutes = duration_totalmin_waso_estimate_am_mincalc / num_waso_estimate_am)
  
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
      
      flag_poor_efficiency = ifelse(!is.na(sleep_efficiency_pct), sleep_efficiency_pct < 70, FALSE),
      flag_high_sol = ifelse(!is.na(sol_h), sol_h > 1, FALSE),
      flag_high_waso = ifelse(!is.na(waso_h), waso_h > 1.5, FALSE),
      
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

# Define missing columns that need to be added
missing_cols_list <- c(
  "num_waso_estimate_am",
  "duration_totalmin_sol_estimate_am_mincalc",
  "duration_totalmin_waso_estimate_am_mincalc"
)

add_missing_columns <- function(df, df_name) {
  for(col in missing_cols_list) {
    if(!col %in% names(df)) {
      if(col == "num_waso_estimate_am") {
        df[[col]] <- 1
      } else if(col == "duration_totalmin_sol_estimate_am_mincalc") {
        df[[col]] <- 0
      } else if(col == "duration_totalmin_waso_estimate_am_mincalc") {
        df[[col]] <- 0
      }
      cat(sprintf("  ✓ Added column '%s' to %s (default values)\n", col, df_name))
    }
  }
  return(df)
}

cat("\nChecking clean_df for required columns:\n")
clean_df <- add_missing_columns(clean_df, "clean_df")

cat("\nCalculating sleep variables for clean_df:\n")
clean_df <- calculate_sleep_time_vars(clean_df)

# Process unusual_df if it exists (from error_unusual_sleep_time_corrections.R)
if(exists("unusual_df") && is.data.frame(unusual_df) && nrow(unusual_df) > 0) {
  cat("\nProcessing unusual_df:\n")
  unusual_df <- add_missing_columns(unusual_df, "unusual_df")
  unusual_df <- calculate_sleep_time_vars(unusual_df)
} else {
  cat("\n⚠ unusual_df not found or empty\n")
  unusual_df <- data.frame()
}

# Process error_df if it exists (from error_unusual_sleep_time_corrections.R)
if(exists("error_df") && is.data.frame(error_df) && nrow(error_df) > 0) {
  cat("\nProcessing error_df:\n")
  error_df <- add_missing_columns(error_df, "error_df")
  error_df <- calculate_sleep_time_vars(error_df)
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
    waso_h = duration_totalmin_waso_estimate_am_mincalc / 60,
    sleep_efficiency_pct = self_diffcalc_sleepefficiency_percent * 100
  )
cat("✓ clean_df converted\n")

if(nrow(unusual_df) > 0 && "self_diffcalc_totalsleeptime_minutes" %in% names(unusual_df)) {
  unusual_df <- unusual_df %>%
    mutate(
      sleep_duration_h = self_diffcalc_totalsleeptime_minutes / 60,
      time_in_bed_h = self_diffcalc_timeinbed_minutes / 60,
      sol_h = self_diffcalc_sol_minutes / 60,
      waso_h = duration_totalmin_waso_estimate_am_mincalc / 60,
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
      waso_h = duration_totalmin_waso_estimate_am_mincalc / 60,
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
    
    metrics_cols <- c("pid", "day_num", "sleep_duration_h", "time_in_bed_h", 
                      "sol_h", "waso_h", "sleep_efficiency_pct", "flag_severity")
    
    existing_metrics <- metrics_cols[metrics_cols %in% names(clean_df)]
    
    if(length(existing_metrics) > 1) {
      checkforerrors_processed <- checkforerrors_df %>%
        left_join(
          clean_df %>% select(all_of(existing_metrics)),
          by = c("pid", "day_num"),
          relationship = "many-to-many"
        )
      cat(sprintf("  ✓ Merged %d metrics columns\n", length(existing_metrics) - 2))
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
cat("Generating Figure 1...\n")

if(all(c("data_category", "manually_corrected") %in% names(corrected_ema_data))) {
  
  final_classification <- corrected_ema_data %>%
    mutate(
      final_category = case_when(
        manually_corrected == TRUE ~ "Manually Corrected",
        data_category == "clean" ~ "Clean",
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
      subtitle = sprintf("Based on final classification after manual corrections | Total flagged for review: %d (%.1f%%)", 
                         needs_review_count, needs_review_count/total_records*100),
      theme = theme(plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
                    plot.subtitle = element_text(hjust = 0.5, size = 10))
    )
  
  print(p1)
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
cat("Generating Figure 2...\n")

vars_to_plot <- c()
if("sleep_duration_h" %in% names(clean_df)) vars_to_plot <- c(vars_to_plot, sleep_duration = "sleep_duration_h")
if("time_in_bed_h" %in% names(clean_df)) vars_to_plot <- c(vars_to_plot, time_in_bed = "time_in_bed_h")
if("waso_h" %in% names(clean_df)) vars_to_plot <- c(vars_to_plot, WASO = "waso_h")
if("sol_h" %in% names(clean_df)) vars_to_plot <- c(vars_to_plot, SOL = "sol_h")
if("sleep_efficiency_pct" %in% names(clean_df)) vars_to_plot <- c(vars_to_plot, sleep_efficiency = "sleep_efficiency_pct")

if(length(vars_to_plot) > 0) {
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
  cat("✓ Figure 2 completed\n\n")
}

# ----------------------------------------------------------------------------
# Figure 3: Sleep Duration Distribution
# ----------------------------------------------------------------------------
# DATA SOURCE: clean_df
# WHAT IT SHOWS: Distribution of Total Sleep Time (TST) with mean/median lines
#                Mean and median annotated on the plot
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
cat("Generating Figure 5...\n")

available_vars <- c()
if("sleep_duration_h" %in% names(clean_df)) available_vars <- c(available_vars, `Sleep Duration` = "sleep_duration_h")
if("time_in_bed_h" %in% names(clean_df)) available_vars <- c(available_vars, `Time in Bed` = "time_in_bed_h")
if("waso_h" %in% names(clean_df)) available_vars <- c(available_vars, `WASO` = "waso_h")
if("sol_h" %in% names(clean_df)) available_vars <- c(available_vars, `SOL` = "sol_h")
if("sleep_efficiency_pct" %in% names(clean_df)) available_vars <- c(available_vars, `Sleep Efficiency` = "sleep_efficiency_pct")

if(length(available_vars) > 0) {
  long_df2 <- clean_df %>%
    select(all_of(available_vars)) %>%
    pivot_longer(cols = everything(), names_to = "variable", values_to = "value") %>%
    filter(!is.na(value))
  
  p5 <- ggplot(long_df2, aes(x = variable, y = value, fill = variable)) +
    geom_violin(trim = FALSE, alpha = 0.5) +
    geom_boxplot(width = 0.1, outlier.shape = NA, fill = "white") +
    scale_fill_brewer(palette = "Set2") +
    labs(title = "Figure 5: Variability of Sleep Variables",
         subtitle = "Violin plots showing distribution shape with internal box plots (based on final corrected data)",
         x = "", y = "Value") +
    theme(axis.text.x = element_text(angle = 45, hjust = 1),
          legend.position = "none")
  print(p5)
  cat("✓ Figure 5 completed\n\n")
}

# ----------------------------------------------------------------------------
# Figure 6: Sleep Duration - Clean vs Flagged (POST-MANUAL-CORRECTION)
# DATA SOURCE: clean_df (has sleep_duration_h) + corrected_ema_data (has final categories)
# ============================================================================
cat("Generating Figure 6 (Post-correction: Clean vs Flagged)...\n")

if (exists("clean_df") && exists("corrected_ema_data") && 
    "sleep_duration_h" %in% names(clean_df)) {
  
  # 合并 clean_df 的睡眠时长和 corrected_ema_data 的分类信息
  p6_data <- clean_df %>%
    select(pid, day_num, sleep_duration_h) %>%
    filter(!is.na(sleep_duration_h)) %>%
    left_join(
      corrected_ema_data %>% select(pid, day_num, data_category, manually_corrected),
      by = c("pid", "day_num"),
      relationship = "many-to-many"
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
           subtitle = paste0("Based on final classification after manual corrections | ",
                             "Clean: ", sum(p6_data$status == "Clean"),
                             ", Unusual: ", sum(p6_data$status == "Unusual"),
                             ", Manually Corrected: ", sum(p6_data$status == "Manually Corrected"),
                             ", Error: ", sum(p6_data$status == "Error")),
           x = "Sleep Duration (hours)", 
           y = "Density") +
      theme_minimal(base_size = 12) +
      theme(legend.position = "bottom")
    
    print(p6)
    cat("✓ Figure 6 completed\n\n")
  } else {
    cat("⚠ No valid data for Figure 6\n\n")
  }
} else {
  cat("⚠ clean_df or corrected_ema_data missing required columns\n")
  cat("  Make sure calculate_sleep_time_vars() was run on clean_df\n\n")
}


# ----------------------------------------------------------------------------
# Figure 7: Flag Composition (Stacked Histogram)
# ----------------------------------------------------------------------------
# DATA SOURCE: clean_df
# WHAT IT SHOWS: Stacked histogram showing data quality composition across sleep durations
#                Colors indicate Clean, Minor issues, Major issues
# ============================================================================
cat("Generating FIGURE 7 (Stacked by flag severity)...\n")

if(all(c("sleep_duration_h", "flag_severity") %in% names(clean_df))) {
  
  plot_df_7 <- clean_df %>% 
    filter(!is.na(sleep_duration_h), !is.na(flag_severity),
           sleep_duration_h > 0, sleep_duration_h < 20)
  
  if(nrow(plot_df_7) > 0) {
    p7 <- ggplot(plot_df_7, aes(x = sleep_duration_h, fill = flag_severity)) +
      geom_histogram(bins = 50, alpha = 0.7, position = "stack") +
      scale_fill_manual(values = c("Clean" = "#2E7D32", 
                                   "Minor issues (1 flag)" = "#FF8C00",
                                   "Major issues (2+ flags)" = "#D32F2F"),
                        name = "Data Quality") +
      labs(title = "Figure 7: Data Quality Composition Across Sleep Durations",
           subtitle = "Stacked histogram showing how data quality varies by sleep duration (based on final corrected data)",
           x = "Sleep Duration (hours)", y = "Count") +
      coord_cartesian(xlim = c(0, 16)) +
      theme(legend.position = "bottom")
    
    print(p7)
    cat("✓ Figure 7 completed\n\n")
  }
}

# ----------------------------------------------------------------------------
# Figure 8: Sleep Duration by Data Category
# ----------------------------------------------------------------------------
# DATA SOURCE: clean_df + unusual_df + error_df
# WHAT IT SHOWS: Violin plots comparing sleep duration across clean, unusual, and error categories
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
  cat("✓ Figure 8 completed\n\n")
}

# ----------------------------------------------------------------------------
# Figure 9: Bedtime vs Get-up Time Distribution
# ----------------------------------------------------------------------------
# DATA SOURCE: clean_df
# WHAT IT SHOWS: Density plots of bedtime and get-up time across the day
#                Reveals circadian patterns of sleep timing
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
  cat("✓ Figure 9 completed\n\n")
}

# ----------------------------------------------------------------------------
# Figure 10: Extreme Sleep Duration with Efficiency Context
# ----------------------------------------------------------------------------
# DATA SOURCE: clean_df
# WHAT IT SHOWS: Scatter plot of extreme sleep durations (<4h or >10h)
#                with sleep efficiency context, color-coded by data quality
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
      cat("✓ FIGURE 11 (Heatmap) completed\n\n")
    }
  }
}

# ----------------------------------------------------------------------------
# Figure 12: Overall Data Quality Distribution (Pie Chart)
# ----------------------------------------------------------------------------
# DATA SOURCE: clean_df$flag_severity
# WHAT IT SHOWS: Pie chart of overall data quality distribution
#                Clean vs Minor issues vs Major issues
# ============================================================================
cat("Generating FIGURE 12 (Flag severity distribution)...\n")

if("flag_severity" %in% names(clean_df)) {
  
  severity_summary <- clean_df %>%
    filter(!is.na(flag_severity)) %>%
    group_by(flag_severity) %>%
    summarise(count = n(), .groups = "drop") %>%
    mutate(percentage = count / sum(count) * 100)
  
  p12 <- ggplot(severity_summary, aes(x = "", y = count, fill = flag_severity)) +
    geom_bar(stat = "identity", width = 1, alpha = 0.8) +
    coord_polar("y", start = 0) +
    scale_fill_manual(values = c("Clean" = "#2E7D32", 
                                 "Minor issues (1 flag)" = "#FF8C00",
                                 "Major issues (2+ flags)" = "#D32F2F"),
                      name = "Data Quality") +
    labs(title = "Figure 12: Overall Data Quality Distribution",
         subtitle = sprintf("Based on final corrected data | Total records: %d | Flagged: %d (%.1f%%)", 
                            sum(severity_summary$count),
                            sum(severity_summary$count[severity_summary$flag_severity != "Clean"]),
                            sum(severity_summary$percentage[severity_summary$flag_severity != "Clean"]))) +
    theme_void(base_size = 12) +
    theme(legend.position = "bottom")
  
  print(p12)
  cat("✓ Figure 12 completed\n\n")
}

# ============================================================================
# FIGURES 13-18: CHECKFORERRORS VISUALIZATIONS (Auto-Detection)
# ============================================================================
# NOTE: These figures show algorithm-detected potential issues
#       Source: review_output from checkforerrors_processing.R (checkforerrors_df)
#       What they show: Issues that may need human review
#       These are PRE-correction flags, unlike Figures 1-12 which show POST-correction
# ============================================================================

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
  
  p13 <- (p13_bar / wrap_elements(full = severity_tab)) + 
    plot_layout(heights = c(2.5, 1)) +
    plot_annotation(
      title = "Figure 13: Distribution of Error/Review Categories (Auto-Detection)",
      subtitle = sprintf("Based on checkforerrors_processing.R auto-detection | Total records needing review: %s (%.1f%% of all data)", 
                         format(nrow(checkforerrors_processed), big.mark=","),
                         nrow(checkforerrors_processed)/nrow(clean_df) * 100),
      theme = theme(plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
                    plot.subtitle = element_text(hjust = 0.5, size = 10))
    )
  
  print(p13)
  cat("✓ Figure 13 completed\n\n")
  
  # --------------------------------------------------------------------------
  # Figure 14: Sleep Duration - Clean vs Flagged (PRE-CORRECTION / AUTO-DETECTION)
  # DATA SOURCE: checkforerrors_processed (from _checkforerrors flags)
  # WHAT IT SHOWS: Distribution of sleep duration for algorithm-detected issues
  #                - No Issues (Clean): Records with no _checkforerrors flags
  #                - Needs Review: Records flagged by algorithm (before manual review)
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
      cat("✓ Figure 15 completed\n\n")
    }
  }
  
  # --------------------------------------------------------------------------
  # Figure 16: Most Common Error Patterns (Auto-Detection)
  # --------------------------------------------------------------------------
  # DATA SOURCE: checkforerrors_processed$auto_error_desc
  # WHAT IT SHOWS: Horizontal bar chart of most common specific error patterns
  # ==========================================================================
  cat("Generating FIGURE 16 (Common error patterns - Auto-detection)...\n")
  
  if("auto_error_desc" %in% names(checkforerrors_processed)) {
    
    cat("  Analyzing error patterns...\n")
    
    pattern_data <- checkforerrors_processed %>%
      mutate(
        specific_pattern = case_when(
          grepl("exercisetoday_PM_totalmin_Light", auto_error_desc, ignore.case = TRUE) ~ "Exercise Light duration error",
          grepl("exercisetoday_PM_totalmin_Moderate", auto_error_desc, ignore.case = TRUE) ~ "Exercise Moderate duration error",
          grepl("exercisetoday_PM_totalmin_Vigorous", auto_error_desc, ignore.case = TRUE) ~ "Exercise Vigorous duration error",
          grepl("exercisetoday_PM_totalmin_Strength", auto_error_desc, ignore.case = TRUE) ~ "Exercise Strength duration error",
          grepl("duration_totalmin_sol_estimate_am", auto_error_desc, ignore.case = TRUE) ~ "SOL duration error",
          grepl("duration_totalmin_waso_estimate_am", auto_error_desc, ignore.case = TRUE) ~ "WASO duration error",
          grepl("duration_totalmin_napstoday_PM", auto_error_desc, ignore.case = TRUE) ~ "Nap duration error",
          grepl("sleep.*<3h|sleep duration <3h", auto_error_desc, ignore.case = TRUE) ~ "Sleep <3 hours",
          grepl("sleep.*>15h", auto_error_desc, ignore.case = TRUE) ~ "Sleep >15 hours",
          grepl("WASO >3h", auto_error_desc, ignore.case = TRUE) ~ "WASO >3 hours",
          grepl("latency.*>3h|SOL >3h", auto_error_desc, ignore.case = TRUE) ~ "SOL >3 hours",
          grepl("order error", auto_error_desc, ignore.case = TRUE) ~ "Incorrect time order",
          grepl("caffeinetoday_PM", auto_error_desc, ignore.case = TRUE) ~ "Caffeine record error",
          grepl("alcoholtoday_PM", auto_error_desc, ignore.case = TRUE) ~ "Alcohol record error",
          grepl("nicotine_amount_pm", auto_error_desc, ignore.case = TRUE) ~ "Nicotine record error",
          grepl("cannabis_amount_pm", auto_error_desc, ignore.case = TRUE) ~ "Cannabis record error",
          grepl("duration >24h", auto_error_desc, ignore.case = TRUE) ~ "Duration >24 hours",
          grepl("Interval format", auto_error_desc, ignore.case = TRUE) ~ "Other interval format error",
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
      mutate(specific_pattern = reorder(specific_pattern, count))
    
    if(nrow(pattern_summary) > 0) {
      p16 <- ggplot(pattern_summary, aes(x = specific_pattern, y = count, fill = count)) +
        geom_bar(stat = "identity", alpha = 0.8) +
        geom_text(aes(label = format(count, big.mark=",")), hjust = -0.1, size = 3.5) +
        scale_fill_gradient(low = "#FF8C00", high = "#D32F2F", name = "Count") +
        labs(title = "Figure 16: Most Common Error/Review Patterns (Auto-Detection)",
             subtitle = sprintf("Total flagged records: %s | Based on auto-detection from checkforerrors_processing.R", format(nrow(checkforerrors_processed), big.mark=",")),
             x = "", y = "Count") +
        coord_flip() +
        scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
        theme(legend.position = "bottom")
      
      print(p16)
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
                                            "Interval Format Errors", "Timestamp Format Errors",
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
        labs(title = "📊 Key Metrics", 
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
                     "Interval Format Errors" = "#1976D2",
                     "Timestamp Format Errors" = "#388E3C",
                     "Other Issues" = "#9E9E9E"),
          name = "Issue Type"
        ) +
        labs(title = "🔍 Auto-Detected Issues Breakdown",
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
      cat("✓ Figure 18 completed (using checkforerrors_processing.R output)\n\n")
      
      cat("\n--- Auto-Detected Issues Breakdown (Figure 18) ---\n")
      print(review_classification)
      
      cat("\n--- Interpretation Guide for Figure 18 ---\n")
      cat("  • Manually Corrected: Records fixed by human review (no longer need attention)\n")
      cat("  • Auto-Detected: Algorithm-flagged records requiring human review\n")
      cat("  • Temporal Issues: Chronological order errors (e.g., sleep before bed)\n")
      cat("  • Metrics Issues: Abnormal SOL, SE, or TST/TIB ratio\n")
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
                                     "UNUSUAL_VALUE" = "#FF8C00",
                                     "SERIOUS_RED_LINE" = "#D32F2F")) +
        labs(title = "Figure 19: Final Data Quality Status (Unified Classification)",
             x = "", y = "Count") +
        theme_minimal(base_size = 12) +
        theme(axis.text.x = element_text(angle = 45, hjust = 1),
              legend.position = "none")
      print(p19)
      cat("✓ Figure 19 completed\n\n")
    }
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
           subtitle = paste0("Based on ", length(valid_rows), " records | ",
                             "Objective = time_sleep_corrected - time_bed_corrected"),
           x = "Absolute difference (minutes)", y = "Count") +
      scale_x_continuous(limits = c(0, 200)) +
      theme_minimal(base_size = 12)
    
    print(p20)
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
               subtitle = paste0("Based on ", length(valid_waso_rows), " records | ",
                                 "Objective = time_getup_corrected - time_awake_corrected",
                                 " | Thresholds: Minor 15min, Red Line 60min"),
               x = "Absolute difference (minutes)", y = "Count") +
          scale_x_continuous(limits = c(0, 200)) +
          theme_minimal(base_size = 12)
        
        print(p20b)
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
  # Figure 21: Substance Use Flags (with thresholds and missing counts)
  # --------------------------------------------------------------------------
  cat("Generating Figure 21...\n")
  
  # Thresholds based on sleep research literature (per day)
  # - Caffeine: >4 cups/day may impair sleep
  # - Alcohol: >3 drinks/day significantly disrupts sleep  
  # - Nicotine: any use may affect sleep
  # - Cannabis: any use may affect sleep
  subst_info <- list(
    Caffeine = list(val_col = "caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1",
                    threshold = 4, unit = "cups"),
    Alcohol = list(val_col = "alcoholtoday_PM_NumAlcoholicDrinks_1",
                   threshold = 3, unit = "standard drinks"),
    Nicotine = list(val_col = "nicotine_amount_pm_doses",
                    threshold = 1, unit = "doses"),
    Cannabis = list(val_col = "cannabis_amount_pm_doses",
                    threshold = 1, unit = "doses")
  )
  
  subst_summary <- data.frame()
  total_n <- nrow(corrected_ema_data)
  
  for (nm in names(subst_info)) {
    info <- subst_info[[nm]]
    
    if (info$val_col %in% names(corrected_ema_data)) {
      val <- corrected_ema_data[[info$val_col]]
      n_non_na <- sum(!is.na(val))
      n_above <- if (n_non_na > 0 && any(val > info$threshold, na.rm = TRUE)) {
        sum(val > info$threshold, na.rm = TRUE)
      } else { 0 }
      n_below <- n_non_na - n_above
    } else {
      n_non_na <- 0
      n_above <- 0
      n_below <- 0
    }
    
    n_missing <- total_n - n_non_na
    flag_pct <- ifelse(n_non_na > 0, n_above / n_non_na * 100, 0)
    
    subst_summary <- rbind(subst_summary, data.frame(
      substance = nm,
      threshold = info$threshold,
      unit = info$unit,
      n_non_na = n_non_na,
      n_below = n_below,
      n_above = n_above,
      n_missing = n_missing,
      flag_pct = flag_pct,
      label = paste0(nm, " (threshold >", info$threshold, " ", info$unit, "/day)"),
      display_text = paste0(round(flag_pct, 1), "%  (", n_above, "/", n_non_na, 
                            " flagged abnormal, ", n_below, " normal, ", n_missing, " missing)"),
      stringsAsFactors = FALSE
    ))
  }
  
  p21 <- ggplot(subst_summary, aes(x = reorder(label, -flag_pct), y = flag_pct, fill = substance)) +
    geom_col(alpha = 0.8, width = 0.7) +
    geom_text(aes(label = display_text), vjust = -0.3, size = 3.5, 
              hjust = ifelse(subst_summary$flag_pct > 10, 0.5, -0.05)) +
    labs(title = "Figure 21: Substance Use Values Exceeding Sleep-Based Thresholds",
         subtitle = paste("Values above threshold are flagged as unusual (F_RED).",
                          "Thresholds based on sleep research: Caffeine >4 cups/day, Alcohol >3 drinks/day"),
         x = "", y = "% flagged as above threshold") +
    scale_fill_brewer(palette = "Set2") +
    scale_y_continuous(limits = c(0, max(5, subst_summary$flag_pct + 2))) +
    theme_minimal(base_size = 12) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1),
          legend.position = "none")
  
  print(p21)
  cat("✓ Figure 21 completed\n\n")
  
  # --------------------------------------------------------------------------
  # Figure 22: Substance Use Value Distribution (Detailed Statistics)
  # --------------------------------------------------------------------------
  cat("Generating Figure 22 (Substance Use Value Distribution)...\n")
  
  # Define substance columns and thresholds (same as Figure 21)
  subst_list <- list(
    Caffeine = list(
      col = "caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1",
      unit = "cups",
      threshold = 4
    ),
    Alcohol = list(
      col = "alcoholtoday_PM_NumAlcoholicDrinks_1", 
      unit = "standard drinks",
      threshold = 3
    ),
    Nicotine = list(
      col = "nicotine_amount_pm_doses",
      unit = "doses",
      threshold = 1
    ),
    Cannabis = list(
      col = "cannabis_amount_pm_doses",
      unit = "doses", 
      threshold = 1
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
          Above_Threshold = sum(non_na > info$threshold, na.rm = TRUE),
          Threshold = info$threshold,
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
          Above_Threshold = 0,
          Threshold = info$threshold,
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
      geom_hline(data = stats_table[stats_table$N > 0, ], 
                 aes(yintercept = Threshold), 
                 linetype = "dashed", color = "red", linewidth = 0.8) +
      labs(
        title = "Figure 22: Substance Use Value Distribution",
        subtitle = paste0(
          "Boxplots show distribution of reported values | ",
          "Red dashed line = threshold (Caffeine >4 cups, Alcohol >3 drinks)"
        ),
        y = "Reported Value", 
        x = ""
      ) +
      scale_fill_brewer(palette = "Set2") +
      theme_minimal(base_size = 12) +
      theme(legend.position = "none")
    
    print(p22)
    cat("✓ Figure 22 completed\n\n")
    
    # Print statistics table to console
    cat("--- Substance Use Statistics (Figure 22 data) ---\n")
    cat("Thresholds: Caffeine >4 cups/day, Alcohol >3 drinks/day are flagged as abnormal\n\n")
    print(stats_table)
    cat("\n")
    
  } else {
    cat("⚠ No substance use data available for Figure 22\n\n")
  }
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
cat("  Figure 12: Overall Data Quality Distribution (Pie Chart)\n\n")

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

cat("\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\n✅ ANALYSIS COMPLETE!\n")
cat(paste(rep("=", 80), collapse = ""))
cat("\n")