#!/usr/bin/env Rscript
# =============================================================================
# checkforerrors_processing.R (Fully self-contained)
# 
# This script:
#   1. Adds substance value validation flags (caffeine_value_checkforerrors etc.)
#   2. Implements the complete generate_review_flags() logic (Parts A, B, C)
#   3. Builds unified classification summary (checkforerrors_summary)
#
# Output (global):
#   - review_output (list with data_with_flags and checkforerrors_df)
#   - checkforerrors_summary (list with review_summary, classification_rules)
#
# This file replaces both add_substance_value_checks.R and generate_review_flags.R
# =============================================================================

cat("\n=== [checkforerrors_processing] Starting ===\n")

# ----------------------------------------------------------------------------
# 0. Prerequisites
# ----------------------------------------------------------------------------
if (!exists("corrected_ema_data")) {
  stop("Error: corrected_ema_data not found. Run main pipeline first.")
}

# Ensure manually_corrected column exists
if (!"manually_corrected" %in% names(corrected_ema_data)) {
  corrected_ema_data$manually_corrected <- FALSE
  cat("  Created manually_corrected column (all FALSE)\n")
}

# ----------------------------------------------------------------------------
# 1. Add substance value validation flags (numeric thresholds)
# ----------------------------------------------------------------------------
cat("\n--- 1. Adding substance value validation flags ---\n")

# 修改后的阈值（基于睡眠研究）
caffeine_max <- 4    # >4 cups/day may impair sleep
alcohol_max  <- 3    # >3 drinks/day significantly disrupts sleep
nicotine_max <- 1    # any nicotine use may affect sleep
cannabis_max <- 1    # any cannabis use may affect sleep

add_val_flag <- function(df, val_col, thr, new_col) {
  if (val_col %in% names(df)) {
    df[[new_col]] <- ifelse(is.na(df[[val_col]]), NA, df[[val_col]] > thr)
    cat(sprintf("  Added %s\n", new_col))
  } else {
    cat(sprintf("  Warning: %s not found, skipping %s\n", val_col, new_col))
    df[[new_col]] <- NA
  }
  return(df)
}

corrected_ema_data <- add_val_flag(corrected_ema_data,
                                   "caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1", caffeine_max, "caffeine_value_checkforerrors")
corrected_ema_data <- add_val_flag(corrected_ema_data,
                                   "alcoholtoday_PM_NumAlcoholicDrinks_1", alcohol_max, "alcohol_value_checkforerrors")
corrected_ema_data <- add_val_flag(corrected_ema_data,
                                   "nicotine_amount_pm_doses", nicotine_max, "nicotine_value_checkforerrors")
corrected_ema_data <- add_val_flag(corrected_ema_data,
                                   "cannabis_amount_pm_doses", cannabis_max, "cannabis_value_checkforerrors")

# ----------------------------------------------------------------------------
# 2. generate_review_flags logic (fully embedded)
# ----------------------------------------------------------------------------
cat("\n--- 2. Running generate_review_flags logic ---\n")

data <- corrected_ema_data  # work on a copy

# Initialize new columns
data$needs_review_flag <- FALSE
data$auto_error_desc <- NA_character_

# ==========================================================================
# PART A: Collect existing *_checkforerrors flags
# ==========================================================================
all_check_cols <- names(data)[grepl("_checkforerrors$", names(data))]

# NEW: Exclude columns that don't affect sleep quality metrics
# - Exercise format: doesn't impact SOL/TST/SE/WASO
# - Nap duration format: independent variable, not used in sleep calculation
# - Substance timestamp format: contextual variable, doesn't affect sleep metrics
exclude_irrelevant <- unique(grep(
  "exercisetoday|duration_totalmin_napstoday_PM|^caffeinetoday_PM_checkforerrors|^alcoholtoday_PM_checkforerrors|^nicotine_amount_pm_checkforerrors|^cannabis_amount_pm_checkforerrors",
  all_check_cols, ignore.case = TRUE, value = TRUE
))
if (length(exclude_irrelevant) > 0) {
  cat(sprintf("  Excluding %d non-sleep-relevant check columns (exercise, nap, substance timestamp)\n", length(exclude_irrelevant)))
  all_check_cols <- setdiff(all_check_cols, exclude_irrelevant)
}

# A1. Logical columns (interval, value checks)
logical_check_cols <- all_check_cols[sapply(data[all_check_cols], is.logical)]
for (col in logical_check_cols) {
  true_idx <- which(data[[col]] == TRUE & !data$manually_corrected)
  if (length(true_idx) > 0) {
    data$needs_review_flag[true_idx] <- TRUE
    for (i in true_idx) {
      if (is.na(data$auto_error_desc[i])) {
        data$auto_error_desc[i] <- paste0("[Interval] ", col)
      } else {
        data$auto_error_desc[i] <- paste(data$auto_error_desc[i], paste0("[Interval] ", col), sep = "; ")
      }
    }
  }
}

# A2. Character columns (timestamp errors)
char_check_cols <- all_check_cols[sapply(data[all_check_cols], is.character)]
for (col in char_check_cols) {
  non_na_idx <- which(!is.na(data[[col]]) & data[[col]] != "" & !data$manually_corrected)
  if (length(non_na_idx) > 0) {
    data$needs_review_flag[non_na_idx] <- TRUE
    for (i in non_na_idx) {
      if (is.na(data$auto_error_desc[i])) {
        data$auto_error_desc[i] <- paste0("[Timestamp] ", data[[col]][i])
      } else {
        data$auto_error_desc[i] <- paste(data$auto_error_desc[i], paste0("[Timestamp] ", data[[col]][i]), sep = "; ")
      }
    }
  }
}

cat(sprintf("  Part A: %d logical, %d character check columns processed\n", 
            length(logical_check_cols), length(char_check_cols)))

# ==========================================================================
# PART B: Temporal error/unusual detection
# ==========================================================================
required_temporal <- c("time_bed_corrected", "time_sleep_corrected", 
                       "time_awake_corrected", "time_getup_corrected")
if (all(required_temporal %in% names(data))) {
  
  n_rows <- nrow(data)
  temp_no_na <- !is.na(data$time_bed_corrected) & !is.na(data$time_sleep_corrected) & 
    !is.na(data$time_awake_corrected) & !is.na(data$time_getup_corrected) & 
    !data$manually_corrected
  
  bed_sleep_h <- ifelse(temp_no_na, 
                        as.numeric(difftime(data$time_sleep_corrected, data$time_bed_corrected, units = "hours")),
                        NA_real_)
  sleep_awake_h <- ifelse(temp_no_na,
                          as.numeric(difftime(data$time_awake_corrected, data$time_sleep_corrected, units = "hours")),
                          NA_real_)
  awake_getup_h <- ifelse(temp_no_na,
                          as.numeric(difftime(data$time_getup_corrected, data$time_awake_corrected, units = "hours")),
                          NA_real_)
  
  bed_sleep_equal <- temp_no_na & bed_sleep_h == 0
  awake_getup_equal <- temp_no_na & awake_getup_h == 0
  
  order_error <- temp_no_na & 
    !(data$time_bed_corrected < data$time_sleep_corrected & 
        data$time_sleep_corrected < data$time_awake_corrected & 
        data$time_awake_corrected < data$time_getup_corrected)
  
  bed_sleep_error <- temp_no_na & abs(bed_sleep_h) > 7 & !bed_sleep_equal
  awake_getup_error <- temp_no_na & abs(awake_getup_h) > 7 & !awake_getup_equal
  sleep_awake_24h_error <- temp_no_na & abs(sleep_awake_h) > 24
  
  sleep_awake_suspicious <- temp_no_na & !order_error & (sleep_awake_h < 3 | sleep_awake_h > 15)
  bed_sleep_suspicious <- temp_no_na & !order_error & bed_sleep_h > 3 & !bed_sleep_equal
  awake_getup_suspicious <- temp_no_na & !order_error & awake_getup_h > 3 & !awake_getup_equal
  
  is_error <- order_error | bed_sleep_error | awake_getup_error | sleep_awake_24h_error
  is_unusual <- (sleep_awake_suspicious | bed_sleep_suspicious | awake_getup_suspicious) & !is_error
  
  error_idx <- which(is_error & !is.na(is_error))
  unusual_idx <- which(is_unusual & !is.na(is_unusual))
  
  if (length(error_idx) > 0) {
    data$needs_review_flag[error_idx] <- TRUE
    for (i in error_idx) {
      if (is.na(data$auto_error_desc[i])) {
        data$auto_error_desc[i] <- "[Temporal] Error detected"
      } else {
        data$auto_error_desc[i] <- paste(data$auto_error_desc[i], "[Temporal] Error", sep = "; ")
      }
    }
  }
  if (length(unusual_idx) > 0) {
    data$needs_review_flag[unusual_idx] <- TRUE
    for (i in unusual_idx) {
      if (is.na(data$auto_error_desc[i])) {
        data$auto_error_desc[i] <- "[Temporal] Unusual pattern"
      } else {
        data$auto_error_desc[i] <- paste(data$auto_error_desc[i], "[Temporal] Unusual", sep = "; ")
      }
    }
  }
  cat(sprintf("  Part B: %d error rows, %d unusual rows flagged\n", length(error_idx), length(unusual_idx)))
} else {
  cat("  Part B: Skipped (missing time columns)\n")
}

# ==========================================================================
# PART C: Sleep metrics validation
# ==========================================================================
required_metrics <- c("self_diffcalc_sol_minutes", "self_diffcalc_sleepefficiency_percent",
                      "self_diffcalc_totalsleeptime_minutes", "self_diffcalc_timeinbed_minutes")
if (all(required_metrics %in% names(data))) {
  
  # C1: SOL
  sol_min <- data$self_diffcalc_sol_minutes
  sol_cat <- ifelse(is.na(sol_min), "missing",
                    ifelse(sol_min < 0, "negative",
                           ifelse(sol_min == 0, "zero",
                                  ifelse(sol_min > 0 & sol_min < 5, "less_than_5min",
                                         ifelse(sol_min >= 5 & sol_min < 15, "less_than_15min",
                                                ifelse(sol_min >= 15 & sol_min <= 120, "normal", "excessive"))))))
  sol_needs <- (sol_cat %in% c("negative", "zero", "less_than_5min", "excessive")) & !data$manually_corrected
  data$sol_category <- sol_cat
  
  # C2: Sleep Efficiency
  se_pct <- data$self_diffcalc_sleepefficiency_percent
  se_cat <- ifelse(is.na(se_pct), "missing",
                   ifelse(se_pct < -1000, "insane_negative",
                          ifelse(se_pct < 0, "negative",
                                 ifelse(se_pct >= 0 & se_pct <= 100, "valid", "exceeds_100"))))
  se_needs <- (se_cat %in% c("insane_negative", "negative", "exceeds_100")) & !data$manually_corrected
  data$se_category <- se_cat
  data$se_is_insane_negative <- (se_cat == "insane_negative")
  
  # C3: TST/TIB ratio
  tst <- data$self_diffcalc_totalsleeptime_minutes
  tib <- data$self_diffcalc_timeinbed_minutes
  ratio <- ifelse(!is.na(tib) & tib > 0, tst / tib, NA_real_)
  ratio_cat <- ifelse(is.na(ratio), "missing",
                      ifelse(ratio == 0, "zero",
                             ifelse(ratio > 0 & ratio < 0.5, "very_low",
                                    ifelse(ratio >= 0.5 & ratio <= 0.9, "normal_low",
                                           ifelse(ratio > 0.9 & ratio <= 1.0, "normal_high", "exceeds_1")))))
  ratio_needs <- (ratio_cat %in% c("zero", "very_low", "exceeds_1")) & !data$manually_corrected
  data$tst_tib_ratio_category <- ratio_cat
  
  metrics_idx <- which((sol_needs | se_needs | ratio_needs) & !is.na(sol_needs | se_needs | ratio_needs))
  if (length(metrics_idx) > 0) {
    data$needs_review_flag[metrics_idx] <- TRUE
    for (i in metrics_idx) {
      notes <- paste0(
        ifelse(sol_needs[i], paste0("SOL:", sol_cat[i], "; "), ""),
        ifelse(se_needs[i], paste0("SE:", se_cat[i], "; "), ""),
        ifelse(ratio_needs[i], paste0("TST/TIB:", ratio_cat[i], "; "), "")
      )
      if (is.na(data$auto_error_desc[i])) {
        data$auto_error_desc[i] <- paste0("[Metrics] ", notes)
      } else {
        data$auto_error_desc[i] <- paste(data$auto_error_desc[i], paste0("[Metrics] ", notes), sep = "; ")
      }
    }
  }
  cat(sprintf("  Part C: %d metrics rows flagged\n", length(metrics_idx)))
} else {
  cat("  Part C: Skipped (missing metrics columns)\n")
}

# ==========================================================================
# PART D: Create checkforerrors_df
# ==========================================================================
checkforerrors_df <- data[data$needs_review_flag == TRUE, ]
keep_cols <- c("pid", "day_num", "row_id", "time_bed_corrected", "time_sleep_corrected",
               "time_awake_corrected", "time_getup_corrected", "manually_corrected",
               "needs_review_flag", "auto_error_desc")
extra_cols <- intersect(c("sol_category", "se_category", "tst_tib_ratio_category", "se_is_insane_negative"), names(data))
checkforerrors_df <- checkforerrors_df[, c(keep_cols, extra_cols)]

review_output <- list(
  data_with_flags = data,
  checkforerrors_df = checkforerrors_df
)

cat(sprintf("  Part D: checkforerrors_df created with %d rows\n", nrow(checkforerrors_df)))

# ----------------------------------------------------------------------------
# 3. Unified classification summary (for Figures 19-21)
# ----------------------------------------------------------------------------
cat("\n--- 3. Building unified classification summary (checkforerrors_summary) ---\n")

data_wf <- review_output$data_with_flags
all_check <- names(data_wf)[grepl("_checkforerrors$", names(data_wf))]

# Also exclude non-actionable columns from severity classification (same as Part A)
exclude_check <- unique(grep(
  "exercisetoday|duration_totalmin_napstoday_PM|^caffeinetoday_PM_checkforerrors|^alcoholtoday_PM_checkforerrors|^nicotine_amount_pm_checkforerrors|^cannabis_amount_pm_checkforerrors",
  all_check, ignore.case = TRUE, value = TRUE
))
if (length(exclude_check) > 0) {
  all_check <- setdiff(all_check, exclude_check)
}

n2 <- nrow(data_wf)

red_flags <- integer(n2)
yellow_flags <- integer(n2)
behavioral_flags <- integer(n2)
has_any <- logical(n2)
flag_details <- character(n2)

# Severity mapping (base R vectors)
severity_vec <- setNames(rep("EXCLUDED", length(all_check)), all_check)
desc_vec <- setNames(all_check, all_check)

# --- INTELLIGENT CLASSIFICATION ---
# Tier 1 — RED: Data integrity issues affecting core sleep metrics
#   These truly need human review when they occur
#   (After normalize clearing, timestamp columns should be 0 non-NA)

# - Sleep timestamp format errors (safety net: kept as RED even though normalize clears them)
for (pat in c("time_bed_am", "time_sleep_am", "time_awake_am", "time_getup_am")) {
  col <- paste0(pat, "_checkforerrors")
  if (col %in% all_check) { severity_vec[col] <- "RED"; desc_vec[col] <- paste(pat, "format error") }
}
# - SOL interval format (core metric: sleep onset latency)
sol_cols <- grep("duration_totalmin_sol.*_checkforerrors", all_check, value = TRUE)
for (col in sol_cols) { severity_vec[col] <- "RED"; desc_vec[col] <- "SOL interval error" }

# Tier 2 — YELLOW: Minor data quality concerns
# - WASO interval format (important metric but format error is less critical than SOL)
waso_cols <- grep("duration_totalmin_waso.*_checkforerrors", all_check, value = TRUE)
for (col in waso_cols) { severity_vec[col] <- "YELLOW"; desc_vec[col] <- "WASO interval issue" }

# Tier 3 — BEHAVIORAL: Lifestyle/substance flags, not data quality
#   These are threshold warnings (e.g., caffeine >4 cups)
#   Informational for researchers, do NOT need manual correction
behavioral_cols <- grep("_value_checkforerrors", all_check, value = TRUE)
for (col in behavioral_cols) {
  severity_vec[col] <- "BEHAVIORAL"
  label <- gsub("_value_checkforerrors", "", col)
  desc_vec[col] <- paste0(label, " intake flag")
}
# Also include substance amount format issues in behavioral (contextual data)
subst_amount_cols <- grep("^(caffeinetoday|alcoholtoday|nicotine_amount|nicotine_amount_pm|cannabis_amount)_checkforerrors", all_check, value = TRUE)
for (col in subst_amount_cols) {
  if (severity_vec[col] == "EXCLUDED") {
    severity_vec[col] <- "BEHAVIORAL"
    desc_vec[col] <- "substance amount note"
  }
}

for (col in all_check) {
  col_data <- data_wf[[col]]
  if (is.logical(col_data)) prob <- !is.na(col_data) & col_data == TRUE
  else if (is.character(col_data)) prob <- !is.na(col_data) & col_data != ""
  else prob <- rep(FALSE, n2)
  
  if (severity_vec[col] == "RED" || severity_vec[col] == "YELLOW" || severity_vec[col] == "BEHAVIORAL") {
    has_any <- has_any | prob
  }
  if (severity_vec[col] == "RED") red_flags <- red_flags + as.numeric(prob)
  else if (severity_vec[col] == "YELLOW") yellow_flags <- yellow_flags + as.numeric(prob)
  else if (severity_vec[col] == "BEHAVIORAL") behavioral_flags <- behavioral_flags + as.numeric(prob)
  
  idx <- which(prob & flag_details == "")
  if (length(idx) > 0) flag_details[idx] <- desc_vec[col]
}

review_summary <- data.frame(
  pid = data_wf$pid,
  day_num = data_wf$day_num,
  row_id = data_wf$row_id,
  manually_corrected = data_wf$manually_corrected,
  has_any_issue = has_any,
  red_flags = red_flags,
  yellow_flags = yellow_flags,
  behavioral_flags = behavioral_flags,
  flag_details = flag_details,
  stringsAsFactors = FALSE
)

raw_severity <- character(n2)
raw_severity[red_flags > 0] <- "SERIOUS_RED_LINE"
raw_severity[red_flags == 0 & yellow_flags > 0] <- "UNUSUAL_VALUE"
raw_severity[red_flags == 0 & yellow_flags == 0 & behavioral_flags > 0] <- "BEHAVIORAL"
raw_severity[red_flags == 0 & yellow_flags == 0 & behavioral_flags == 0] <- "CLEAN"
final_status <- raw_severity
final_status[review_summary$manually_corrected] <- "CLEAN (Manually Fixed)"

review_summary$raw_severity <- raw_severity
review_summary$final_status <- final_status

# Add behavioral_flags to review_output for downstream use
review_output$checkforerrors_summary <- list(
  review_summary = review_summary,
  classification_rules = list(severity = severity_vec, description = desc_vec)
)

checkforerrors_summary <- list(
  review_summary = review_summary,
  classification_rules = list(severity = severity_vec, description = desc_vec)
)

cat("Final status distribution (checkforerrors_summary):\n")
print(table(review_summary$final_status, useNA = "ifany"))

cat("\n=== [checkforerrors_processing] Finished ===\n")
cat("Objects created: review_output, checkforerrors_summary\n")