#!/usr/bin/env Rscript
# =============================================================================
# checkforerrors_processing.R — Auto-detection of remaining data issues
# =============================================================================
# PURPOSE:
#   After all manual corrections are applied (step 6-7), this step checks
#   for any remaining issues in the corrected data. It operates in three
#   parallel passes (Parts A, B, C) and produces two outputs:
#
#   (1) checkforerrors_processed — a subset of records that still need review
#   (2) checkforerrors_summary — a classification summary (used by Figures 19-21)
#   (3) substance_decimal_anomalies — reference table of input-entry oddities
#
# WHAT IT DETECTS:
#   PART A: Parsing issues captured during timestamp/interval processing
#           (stored in *_checkforerrors columns from steps 2-4)
#   PART B: Temporal classification from step 6 (error_type / unusual_type)
#           that was not manually corrected
#   PART C: Computed sleep metric anomalies (SOL=0, negative SE, etc.)
#
# ADDITIONALLY:
#   Sections 1a-1c: Detect and report substance-value input anomalies
#   (text entries, decimal precision problems) using the RAW CSV data
#   to preserve information that R's type coercion may have lost.
#
# OUTPUT OBJECTS (in global environment):
#   review_output$data_with_flags    — full data with review flag columns
#   review_output$checkforerrors_df  — subset: only flagged records
#   checkforerrors_summary           — per-participant flag counts
#   substance_decimal_anomalies      — input oddities reference table
# =============================================================================

cat("\n=== [checkforerrors_processing] Starting ===\n")

# ----------------------------------------------------------------------------
# 0. Prerequisites — verify that the main data object exists
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
# 1a. Fix substance text entries from raw CSV
# ----------------------------------------------------------------------------
# WHY:  The main RDS data pre-processes substance columns as numeric, so any
#       text entry (like "Had three black coffees") becomes NA silently.
#       This function reads the RAW CSV to recover those text entries, extracts
#       number words (one→1, two→2, ..., ten→10), and patches the numeric column.
# NOTE: Only caffeine is checked here because it's the only substance column
#       with observed text entries in this dataset.
# ----------------------------------------------------------------------------
cat("\n--- 1a. Pre-processing raw substance values ---\n")

fix_substance_text <- function(df, raw_csv_path, val_col, label) {
  if (!file.exists(raw_csv_path)) {
    cat(sprintf("  Warning: %s not found, skipping raw pre-processing\n", raw_csv_path))
    return(df)
  }
  raw_all <- read.csv(raw_csv_path, stringsAsFactors = FALSE)
  if (!(val_col %in% names(raw_all))) {
    cat(sprintf("  Warning: %s not in CSV, skipping\n", val_col))
    return(df)
  }
  raw_vals <- raw_all[[val_col]]
  if (!is.character(raw_vals)) return(df)
  
  word_to_num <- c("zero" = 0, "one" = 1, "two" = 2, "three" = 3,
                   "four" = 4, "five" = 5, "six" = 6, "seven" = 7,
                   "eight" = 8, "nine" = 9, "ten" = 10)
  
  num_vals <- suppressWarnings(as.numeric(raw_vals))
  text_idx <- which(!is.na(raw_vals) & is.na(num_vals))
  
  if (length(text_idx) == 0) return(df)
  
  fixed <- 0
  for (i in text_idx) {
    txt <- tolower(trimws(gsub("[[:punct:]]", " ", raw_vals[i])))
    words <- strsplit(txt, "\\s+")[[1]]
    for (w in words) {
      if (w %in% names(word_to_num)) {
        num_vals[i] <- word_to_num[w]
        cat(sprintf("  Fixed \"%s\" → %g for %s (pid=%s, day=%s)\n",
                    raw_vals[i], word_to_num[w], label, raw_all$pid[i], raw_all$day_num[i]))
        fixed <- fixed + 1
        break
      }
    }
  }
  
  # Patch the processed df column (match by pid/day_num)
  for (i in text_idx) {
    match_idx <- which(df$pid == raw_all$pid[i] & df$day_num == raw_all$day_num[i])
    if (length(match_idx) == 1 && !is.na(num_vals[i])) {
      df[[val_col]][match_idx] <- num_vals[i]
    }
  }
  cat(sprintf("  %s: %d text entries, %d converted to numeric\n", label, length(text_idx), fixed))
  df
}

raw_csv <- "sber_ema_anon_20260227.csv"
corrected_ema_data <- fix_substance_text(corrected_ema_data, raw_csv,
                                         "caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1", "caffeine")

# ----------------------------------------------------------------------------
# 1b. Build substance input anomaly reference table
# ----------------------------------------------------------------------------
# WHAT:  Scans the RAW CSV for three types of input-entry anomalies:
#        1. Non-numeric text (e.g., "Had three black coffees")
#        2. Values with 2+ decimal places (1.25 — too precise for self-report)
#        3. Values between 0-1 (not 0.5) suggesting a misplaced decimal (0.3→3)
# WHY:   We read from the raw CSV (not the processed R data) because the RDS
#        may have already coerced text entries to NA or applied type conversions.
# OUTPUT: substance_decimal_anomalies (data.frame, stored in global environment
#         so it's accessible in R Studio after the pipeline finishes)
# ----------------------------------------------------------------------------
cat("\n--- 1b. Building substance input anomaly reference table ---\n")

build_input_anomalies <- function(val_col, label, raw_csv_path) {
  out <- data.frame()
  if (!file.exists(raw_csv_path)) return(out)
  raw_all <- read.csv(raw_csv_path, stringsAsFactors = FALSE)
  if (!(val_col %in% names(raw_all))) return(out)
  
  char_vals <- as.character(raw_all[[val_col]])
  
  for (i in seq_along(char_vals)) {
    if (is.na(char_vals[i]) || trimws(char_vals[i]) == "") next
    cv <- trimws(char_vals[i])
    orig_val <- suppressWarnings(as.numeric(cv))
    
    # Text that could not be converted to a number (e.g., "Had three black coffees")
    if (is.na(orig_val)) {
      out <- rbind(out, data.frame(
        substance = label, pid = raw_all$pid[i], day_num = raw_all$day_num[i],
        value = cv, anomaly_type = "non_numeric_entry",
        note = "Text input where number expected",
        stringsAsFactors = FALSE
      ))
      next
    }
    
    # 2+ decimal places (e.g., 1.25) — unusual precision for self-reported count
    if (grepl("^[0-9]+\\.[0-9]{2,}$", cv)) {
      out <- rbind(out, data.frame(
        substance = label, pid = raw_all$pid[i], day_num = raw_all$day_num[i],
        value = cv, anomaly_type = "suspicious_decimal",
        note = sprintf("Has %d decimal places (unusual for self-report)",
                       nchar(gsub("^[^.]*\\.", "", cv))),
        stringsAsFactors = FALSE
      ))
      next
    }
    
    # Decimal slip: value between 0 and 1 (but not .5), likely missing factor of 10
    # e.g., 0.3 → person probably meant 3
    if (orig_val > 0 && orig_val < 1 && orig_val != 0.5) {
      suggested <- round(orig_val * 10)
      if (suggested != orig_val) {
        out <- rbind(out, data.frame(
          substance = label, pid = raw_all$pid[i], day_num = raw_all$day_num[i],
          value = cv, anomaly_type = "possible_decimal_slip",
          note = sprintf("%s → maybe meant %g", cv, suggested),
          stringsAsFactors = FALSE
        ))
      }
    }
  }
  out
}

assign("substance_decimal_anomalies", rbind(
  build_input_anomalies("caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1", "caffeine", raw_csv),
  build_input_anomalies("alcoholtoday_PM_NumAlcoholicDrinks_1", "alcohol", raw_csv),
  build_input_anomalies("nicotine_amount_pm_doses", "nicotine", raw_csv),
  build_input_anomalies("cannabis_amount_pm_doses", "cannabis", raw_csv)
), envir = .GlobalEnv)

if (nrow(substance_decimal_anomalies) > 0) {
  cat(sprintf("  Found %d input anomalies:\n", nrow(substance_decimal_anomalies)))
  print(substance_decimal_anomalies, row.names = FALSE)
} else {
  cat("  No anomalies found\n")
}

# ----------------------------------------------------------------------------
# 1c. Detect input anomalies in substance value entries
# ----------------------------------------------------------------------------
# WHAT:  Adds two new columns per substance:
#        - *_value_checkforerrors (TRUE/FALSE — does this entry have an anomaly?)
#        - *_input_anomaly (text — what kind of anomaly)
# WHY:   These flags feed into Part D's unified classification as AMOUNT_FLAG.
#        The distinction from Section 1b: 1b is a human-readable reference table
#        in global env; 1c actually adds the flag columns to the data frame
#        used downstream by visualization (Figures 21-24).
# NOTE:  We pass raw CSV character values explicitly so that text entries that
#        were coerced to NA by R's type conversion are still detected.
# ----------------------------------------------------------------------------
cat("\n--- 1c. Detecting substance value input anomalies ---\n")

detect_input_anomaly <- function(df, val_col, label, raw_vals_char = NULL) {
  flag_col <- paste0(label, "_value_checkforerrors")
  note_col <- paste0(label, "_input_anomaly")
  
  if (!(val_col %in% names(df))) {
    df[[flag_col]] <- NA
    df[[note_col]] <- NA
    cat(sprintf("  Warning: %s not found, skipping %s\n", val_col, label))
    return(df)
  }
  
  proc_vals <- df[[val_col]]
  
  # Use raw CSV char values if available (they preserve text entries)
  if (!is.null(raw_vals_char)) {
    display_vals <- raw_vals_char
    vals <- suppressWarnings(as.numeric(raw_vals_char))
  } else {
    display_vals <- proc_vals
    if (is.character(proc_vals)) {
      vals <- suppressWarnings(as.numeric(proc_vals))
    } else {
      vals <- proc_vals
    }
  }
  
  n_total <- sum(!is.na(display_vals) & display_vals != "")
  anomaly_type <- rep(NA_character_, length(display_vals))
  
  # Check 0: Non-numeric entries.
  # Text entries that contain an interpretable number word (e.g.,
  # "Had three black coffees") are accepted after Section 1a converts them.
  non_num_idx <- which(!is.na(display_vals) & display_vals != "" & is.na(suppressWarnings(as.numeric(display_vals))))
  if (length(non_num_idx) > 0) {
    word_number_pattern <- "\\b(zero|one|two|three|four|five|six|seven|eight|nine|ten)\\b"
    unparsed_text_idx <- non_num_idx[!grepl(word_number_pattern, tolower(display_vals[non_num_idx]))]
    if (length(unparsed_text_idx) > 0) anomaly_type[unparsed_text_idx] <- "non_numeric_entry"
  }
  
  # Check 1: Negative values (clearly impossible)
  neg_idx <- which(!is.na(vals) & vals < 0)
  if (length(neg_idx) > 0) anomaly_type[neg_idx] <- "negative_value"
  
  # Check 2: Filler / non-genuine values
  filler_idx <- which(!is.na(vals) & vals %in% c(888, 999, 777))
  if (length(filler_idx) > 0) {
    new_idx <- setdiff(filler_idx, which(!is.na(anomaly_type)))
    if (length(new_idx) > 0) anomaly_type[new_idx] <- "filler_value"
  }
  
  # Check 3: Excessive digit length (3+ digits for consumption variables)
  digit_idx <- which(!is.na(vals) & abs(vals) >= 100)
  if (length(digit_idx) > 0) {
    new_idx <- setdiff(digit_idx, which(!is.na(anomaly_type)))
    if (length(new_idx) > 0) anomaly_type[new_idx] <- "excessive_digits"
  }
  
  # Check 4: Repeated digit pattern (e.g., 111, 222)
  char_vals <- as.character(display_vals)
  rep_idx <- which(!is.na(display_vals) & display_vals != "" & 
                     grepl("^(\\d)\\1{2,}$", gsub("[\\.\\-]", "", char_vals)))
  if (length(rep_idx) > 0) {
    new_idx <- setdiff(rep_idx, which(!is.na(anomaly_type)))
    if (length(new_idx) > 0) anomaly_type[new_idx] <- "repeated_digits"
  }
  
  # Decimal substance values can be valid fractional self-reports (e.g.,
  # 1.25 drinks), so decimal precision alone is retained only in the
  # reference table and does not trigger a checkforerrors flag.
  
  has_anomaly <- !is.na(anomaly_type)
  df[[flag_col]] <- has_anomaly
  df[[note_col]] <- anomaly_type
  
  n_flagged <- sum(has_anomaly, na.rm = TRUE)
  cat(sprintf("  %s (%s): %d non-NA entries, %d anomalies detected\n",
              label, val_col, n_total, n_flagged))
  if (n_flagged > 0) {
    anomaly_table <- table(anomaly_type[has_anomaly])
    cat(sprintf("    Breakdown: %s\n",
                paste(sprintf("%s=%d", names(anomaly_table), anomaly_table),
                      collapse = ", ")))
    flagged_idx <- which(has_anomaly)
    show_n <- min(5, length(flagged_idx))
    for (i in 1:show_n) {
      idx <- flagged_idx[i]
      cat(sprintf("    [%d] pid=%s day=%s value=\"%s\" → %s\n",
                  i, df$pid[idx], df$day_num[idx], display_vals[idx], anomaly_type[idx]))
    }
    if (length(flagged_idx) > show_n) {
      cat(sprintf("    ... and %d more\n", length(flagged_idx) - show_n))
    }
  }
  
  invisible(df)
}

# Load raw CSV values for text-preserving detection
raw_csv_fname <- "sber_ema_anon_20260227.csv"
raw_csv_data <- NULL
if (file.exists(raw_csv_fname)) {
  raw_csv_data <- read.csv(raw_csv_fname, stringsAsFactors = FALSE)
}

corrected_ema_data <- detect_input_anomaly(corrected_ema_data,
                                           "caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1", "caffeine",
                                           raw_csv_data[["caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1"]])
corrected_ema_data <- detect_input_anomaly(corrected_ema_data,
                                           "alcoholtoday_PM_NumAlcoholicDrinks_1", "alcohol",
                                           raw_csv_data[["alcoholtoday_PM_NumAlcoholicDrinks_1"]])
corrected_ema_data <- detect_input_anomaly(corrected_ema_data,
                                           "nicotine_amount_pm_doses", "nicotine",
                                           raw_csv_data[["nicotine_amount_pm_doses"]])
corrected_ema_data <- detect_input_anomaly(corrected_ema_data,
                                           "cannabis_amount_pm_doses", "cannabis",
                                           raw_csv_data[["cannabis_amount_pm_doses"]])

# ----------------------------------------------------------------------------
# 2. generate_review_flags logic (fully embedded)
# ----------------------------------------------------------------------------
# WHAT:  Three parallel detection passes that feed into a unified review flag.
#        Records flagged by any pass get added to checkforerrors_df.
# WHY:   Different types of issues are detected by different pipeline steps.
#        This section consolidates them into a single needs_review_flag.
# ----------------------------------------------------------------------------
cat("\n--- 2. Running generate_review_flags logic ---\n")

data <- corrected_ema_data  # work on a copy

# Initialize new columns
data$needs_review_flag <- FALSE
data$auto_error_desc <- NA_character_

# ==========================================================================
# PART A: Collect existing *_checkforerrors flags
# ==========================================================================
# WHAT:  Scans all columns ending in "_checkforerrors" that were created during
#        timestamp parsing (step 2) and interval processing (step 3).
#        These flags capture low-level parsing issues like:
#        - Interval format anomalies (SOL/WASO duration strings)
#        - Hour > 24 (impossible time values)
#
# NOTE:  AM/PM heuristic flags (e.g., "evening var h<6 marked AM (likely PM)")
#        were removed from process_timestamp_emadatarelease_cyra.R as they
#        were false positives. See 2026-05-28 work log for details.
#
# NOTE:  Exercise, nap, and substance timestamp *_checkforerrors columns are
#        excluded here — their format-based flags generate ~81% false positives.
#        Instead, structural anomaly detection on their _mincalc values is
#        applied in PART A3 below (same philosophy as substance value detection).
# ==========================================================================
all_check_cols <- names(data)[grepl("_checkforerrors$", names(data))]

exclude_irrelevant <- unique(grep(
  "exercisetoday|duration_totalmin_napstoday_PM|^caffeinetoday_PM_checkforerrors|^alcoholtoday_PM_checkforerrors|^nicotine_amount_pm_checkforerrors|^cannabis_amount_pm_checkforerrors",
  all_check_cols, ignore.case = TRUE, value = TRUE
))
if (length(exclude_irrelevant) > 0) {
  cat(sprintf("  Excluding %d non-sleep-relevant _checkforerrors columns (exercise, nap, substance timestamp); structural check applied in Part A3\n", length(exclude_irrelevant)))
  all_check_cols <- setdiff(all_check_cols, exclude_irrelevant)
}

# A1. Logical columns (interval, value checks) 
logical_check_cols <- all_check_cols[sapply(data[all_check_cols], is.logical)]
for (col in logical_check_cols) {
  true_idx <- which(data[[col]] == TRUE & !data$manually_corrected)
  if (length(true_idx) > 0) {
    data$needs_review_flag[true_idx] <- TRUE
    issue_prefix <- if (grepl("_value_checkforerrors$", col)) "[Amount] " else "[Interval] "
    for (i in true_idx) {
      if (is.na(data$auto_error_desc[i])) {
        data$auto_error_desc[i] <- paste0(issue_prefix, col)
      } else {
        data$auto_error_desc[i] <- paste(data$auto_error_desc[i], paste0(issue_prefix, col), sep = "; ")
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
# PART A3: Structural check for nap/exercise _mincalc values
# ==========================================================================
# WHAT:  Applies input-structure anomaly detection to nap and exercise duration
#        values (same philosophy as substance value detection in section 1c).
#        Checks _mincalc (numeric minutes) for extreme/implausible values,
#        rather than relying on the format-based _checkforerrors flags which
#        generate ~81% false positives (e.g., "d, min assumed").
#
# RULES:
#   negative_value:   _mincalc < 0 (impossible for duration)
#   excessive_nap:    nap > 720 min (12 hours — unrealistic single nap)
#   excessive_exercise: exercise type > 360 min (6 hours — unrealistic)
#   parse_error:      _mincalc > 10000 (failed parse, e.g. 0:00 → 208M)
# ==========================================================================
nap_exercise_vars <- list(
  nap  = "duration_totalmin_napstoday_PM_mincalc",
  light = "exercisetoday_PM_totalmin_Light_mincalc",
  moderate = "exercisetoday_PM_totalmin_Moderate_mincalc",
  vigorous = "exercisetoday_PM_totalmin_Vigorous_mincalc",
  strength = "exercisetoday_PM_totalmin_Strength_mincalc"
)

for (label in names(nap_exercise_vars)) {
  col_name <- nap_exercise_vars[[label]]
  if (col_name %in% names(data)) {
    vals <- data[[col_name]]
    anom_type <- ifelse(vals < 0, "negative_value",
                        ifelse(vals > 10000, "parse_error",
                               ifelse(label == "nap" & vals > 720, "excessive_nap",
                                      ifelse(label != "nap" & vals > 360, "excessive_exercise", NA))))
    for (i in which(!is.na(anom_type) & !data$manually_corrected)) {
      data$needs_review_flag[i] <- TRUE
      desc <- paste0("[NapEx] ", label, " ", anom_type[i], " (", col_name, "=", vals[i], ")")
      if (is.na(data$auto_error_desc[i])) {
        data$auto_error_desc[i] <- desc
      } else {
        data$auto_error_desc[i] <- paste(data$auto_error_desc[i], desc, sep = "; ")
      }
    }
    n_flagged <- sum(!is.na(anom_type) & !data$manually_corrected, na.rm = TRUE)
    if (n_flagged > 0) cat(sprintf("  Part A3: %s flagged %d structural anomalies\n", label, n_flagged))
  }
}

# ==========================================================================
# PART B: Import temporal error/unusual flags from existing columns
# ==========================================================================
# WHAT:  Reads the error_type and unusual_type columns that were already
#        computed in step 6 (error_unusual_sleep_time_corrections.R).
#        Instead of recomputing temporal diffs, we import the existing
#        classification. Records with non-NA error_type or unusual_type
#        that were NOT manually corrected still need review.
#
# FORMAT: auto_error_desc entries get [Temporal] Error: <type> or
#         [Temporal] Unusual: <type> prefixes so that Figure 16's
#         regex pattern matching correctly categorizes them.
# ==========================================================================
if (all(c("error_type", "unusual_type") %in% names(data))) {
  temporal_needs <- (!is.na(data$error_type) | !is.na(data$unusual_type)) & !data$manually_corrected
  temporal_idx <- which(temporal_needs)
  if (length(temporal_idx) > 0) {
    data$needs_review_flag[temporal_idx] <- TRUE
    for (i in temporal_idx) {
      label <- if (!is.na(data$error_type[i])) {
        paste0("[Temporal] Error: ", data$error_type[i])
      } else {
        paste0("[Temporal] Unusual: ", data$unusual_type[i])
      }
      if (is.na(data$auto_error_desc[i])) data$auto_error_desc[i] <- label
      else data$auto_error_desc[i] <- paste(data$auto_error_desc[i], label, sep = "; ")
    }
  }
  cat(sprintf("  Part B: %d temporal rows flagged (from existing error_type/unusual_type)\n", length(temporal_idx)))
} else {
  cat("  Part B: Skipped (error_type/unusual_type not found — run step 6 first)\n")
}

# ==========================================================================
# PART C: Sleep metrics validation
# ==========================================================================
# WHAT:  Checks four computed sleep metrics for implausible values:
#   C1 - SOL (Sleep Onset Latency):
#        negative → impossible (can't take negative minutes to fall asleep)
#        zero → may indicate bed==sleep (instant sleep — plausible but flag)
#        <5min → unusually fast sleep onset
#        >120min → unusually long to fall asleep
#   C2 - Sleep Efficiency (SE):
#        negative → calculation error (TST or TIB likely wrong)
#        >100% → impossible (more sleep than time in bed)
#        < -1000 → insane negative (severe data issue)
#   C3 - TST/TIB ratio:
#        zero → no sleep recorded
#        <0.5 → very low sleep proportion
#        >1.0 → more sleep than time in bed (impossible)
#
# NOTE:  "Normal" ranges (SOL 15-120min, SE 0-100%, ratio 0.5-1.0) are
#        NOT flagged — these are plausible physiological values.
#        Only extreme outliers trigger the review flag.
# ==========================================================================
required_metrics <- c("self_diffcalc_sol_minutes", "self_diffcalc_sleepefficiency_percent",
                      "self_diffcalc_totalsleeptime_minutes", "self_diffcalc_timeinbed_minutes")
if (all(required_metrics %in% names(data))) {

  # Config fallback
  if (!exists("pipeline_config")) { pipeline_config <- list() }

  # C1: SOL
  sol_min <- data$self_diffcalc_sol_minutes
  sol_excessive <- config_get(pipeline_config, "classification.metric_validation.sol.excessive_minutes", 120)
  sol_cat <- ifelse(is.na(sol_min), "missing",
                    ifelse(sol_min < 0, "negative",
                           ifelse(sol_min == 0, "zero",
                                  ifelse(sol_min > 0 & sol_min < 5, "less_than_5min",
                                         ifelse(sol_min >= 5 & sol_min < 15, "less_than_15min",
                                                ifelse(sol_min >= 15 & sol_min <= sol_excessive, "normal", "excessive"))))))
  sol_needs <- (sol_cat %in% c("negative", "excessive")) & !data$manually_corrected
  data$sol_category <- sol_cat

  # C2: Sleep Efficiency
  se_pct <- data$self_diffcalc_sleepefficiency_percent
  se_insane <- config_get(pipeline_config, "classification.metric_validation.se.insane_negative_percent", -1000)
  se_min <- config_get(pipeline_config, "classification.metric_validation.se.min_valid_percent", 0)
  se_max <- config_get(pipeline_config, "classification.metric_validation.se.max_valid_percent", 100)
  se_cat <- ifelse(is.na(se_pct), "missing",
                   ifelse(se_pct < se_insane, "insane_negative",
                          ifelse(se_pct < se_min, "negative",
                                 ifelse(se_pct >= se_min & se_pct <= se_max, "valid", "exceeds_100"))))
  se_needs <- (se_cat %in% c("insane_negative", "negative", "exceeds_100")) & !data$manually_corrected
  data$se_category <- se_cat
  data$se_is_insane_negative <- (se_cat == "insane_negative")

  # C3: TST/TIB ratio
  tst <- data$self_diffcalc_totalsleeptime_minutes
  tib <- data$self_diffcalc_timeinbed_minutes
  ratio <- ifelse(!is.na(tib) & tib > 0, tst / tib, NA_real_)
  ratio_min <- config_get(pipeline_config, "classification.metric_validation.tst_tib_ratio.min_ratio", 0.5)
  ratio_max <- config_get(pipeline_config, "classification.metric_validation.tst_tib_ratio.max_ratio", 1.0)
  ratio_cat <- ifelse(is.na(ratio), "missing",
                      ifelse(ratio <= 0, "zero",
                             ifelse(ratio > 0 & ratio < ratio_min, "very_low",
                                    ifelse(ratio >= ratio_min & ratio <= 0.9, "normal_low",
                                           ifelse(ratio > 0.9 & ratio <= ratio_max, "normal_high", "exceeds_1")))))
  ratio_needs <- (ratio_cat %in% c("zero", "very_low", "exceeds_1")) & !data$manually_corrected
  data$tst_tib_ratio_category <- ratio_cat

  # C4: Duration inputs used by the sleep metric formula
  # These checks point directly at the mincalc layer when subjective SOL/WASO
  # durations are too large for the observed sleep window. Without this, the
  # symptom only appears downstream as negative TST/SE.
  metric_duration_notes <- rep("", nrow(data))
  metric_duration_needs <- rep(FALSE, nrow(data))
  if (!"sol_duration_for_review_status" %in% names(data) &&
      all(c("duration_totalmin_sol_estimate_am_mincalc",
            "self_diffcalc_totaltrysleep_minutes") %in% names(data))) {
    sol_est <- data$duration_totalmin_sol_estimate_am_mincalc
    try_sleep <- data$self_diffcalc_totaltrysleep_minutes
    sol_est_bad <- !is.na(sol_est) & !is.na(try_sleep) & try_sleep >= 0 & sol_est > try_sleep
    metric_duration_needs <- metric_duration_needs | sol_est_bad
    metric_duration_notes <- ifelse(
      sol_est_bad,
      paste0(metric_duration_notes, "SOL_estimate:exceeds_sleep_to_awake_window; "),
      metric_duration_notes
    )
  }
  if ("sol_duration_for_review_status" %in% names(data)) {
    sol_status <- data$sol_duration_for_review_status
    sol_untrusted <- !is.na(sol_status) & grepl("^untrusted_", sol_status)
    metric_duration_needs <- metric_duration_needs | sol_untrusted
    metric_duration_notes <- ifelse(
      sol_untrusted,
      paste0(metric_duration_notes, "SOL_estimate:", sol_status, "; "),
      metric_duration_notes
    )
  }
  if (!"waso_duration_for_metrics_status" %in% names(data) &&
      all(c("duration_totalmin_waso_estimate_am_mincalc",
            "self_diffcalc_sleepperiod_minutes") %in% names(data))) {
    waso_est <- data$duration_totalmin_waso_estimate_am_mincalc
    sleep_period <- data$self_diffcalc_sleepperiod_minutes
    waso_est_bad <- !is.na(waso_est) & !is.na(sleep_period) & sleep_period >= 0 & waso_est > sleep_period
    metric_duration_needs <- metric_duration_needs | waso_est_bad
    metric_duration_notes <- ifelse(
      waso_est_bad,
      paste0(metric_duration_notes, "WASO_estimate:exceeds_sleep_period; "),
      metric_duration_notes
    )
  }
  if ("waso_duration_for_metrics_status" %in% names(data)) {
    waso_status <- data$waso_duration_for_metrics_status
    waso_untrusted <- !is.na(waso_status) & grepl("^untrusted_", waso_status)
    metric_duration_needs <- metric_duration_needs | waso_untrusted
    metric_duration_notes <- ifelse(
      waso_untrusted,
      paste0(metric_duration_notes, "WASO_estimate:", waso_status, "; "),
      metric_duration_notes
    )
  }
  metric_duration_needs <- metric_duration_needs & !data$manually_corrected
  data$metric_duration_input_category <- ifelse(
    metric_duration_notes == "",
    "valid_or_not_applicable",
    trimws(metric_duration_notes)
  )
  
  metrics_idx <- which((sol_needs | se_needs | ratio_needs | metric_duration_needs) &
                         !is.na(sol_needs | se_needs | ratio_needs | metric_duration_needs))
  if (length(metrics_idx) > 0) {
    data$needs_review_flag[metrics_idx] <- TRUE
    for (i in metrics_idx) {
      notes <- paste0(
        ifelse(metric_duration_needs[i], paste0(metric_duration_notes[i]), ""),
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
# PART C2: Apply human-reviewed metric acceptances
# ==========================================================================
# Rows marked human_metric_review_status == confirmed_not_error_do_not_correct
# have already been checked by a human and judged reasonable. This suppresses
# repeated metric warnings without changing the raw or corrected sleep data.
# ==========================================================================
accepted_count <- 0

# Path 1: suppress flagged rows that already have human_metric_review_status set
# (applied by apply_metric_review_acceptances() earlier in the pipeline)
if ("human_metric_review_status" %in% names(data)) {
  status_ok <- !is.na(data$human_metric_review_status) &
    data$human_metric_review_status == "confirmed_not_error_do_not_correct"
  idx <- which(status_ok)
  if (length(idx) > 0) {
    data$needs_review_flag[idx] <- FALSE
    data$auto_error_desc[idx] <- NA_character_
    accepted_count <- length(idx)
  }
}

# Path 2: also read manual_metric_review_acceptances.csv to catch any rows
# that haven't been matched by apply_metric_review_acceptances() yet
# (runs regardless of Path 1, to cover all accepted rows)
if (file.exists("manual_metric_review_acceptances.csv")) {
  metric_acceptances <- read.csv("manual_metric_review_acceptances.csv", stringsAsFactors = FALSE)
  required_accept_cols <- c("pid", "day_num", "row_id")
  if (all(required_accept_cols %in% names(metric_acceptances))) {
    if (!"human_metric_review_status" %in% names(data)) {
      data$human_metric_review_status <- NA_character_
    }
    if (!"human_metric_review_note" %in% names(data)) {
      data$human_metric_review_note <- NA_character_
    }

    already_suppressed <- which(data$needs_review_flag == FALSE &
      !is.na(data$human_metric_review_status) &
      data$human_metric_review_status == "confirmed_not_error_do_not_correct")
    suppressed_keys <- paste(data$pid[already_suppressed],
      data$day_num[already_suppressed], data$row_id[already_suppressed])

    for (j in seq_len(nrow(metric_acceptances))) {
      rec <- metric_acceptances[j, ]
      rec_key <- paste(rec$pid, rec$day_num, rec$row_id)
      if (rec_key %in% suppressed_keys) next

      idx <- which(data$pid == rec$pid & data$day_num == rec$day_num & data$row_id == rec$row_id)
      if (length(idx) != 1) next

      data$needs_review_flag[idx] <- FALSE
      data$auto_error_desc[idx] <- NA_character_
      data$human_metric_review_status[idx] <- if ("human_metric_review_status" %in% names(metric_acceptances)) {
        rec$human_metric_review_status
      } else if ("human_review_status" %in% names(metric_acceptances)) {
        rec$human_review_status
      } else {
        "confirmed_not_error_do_not_correct"
      }
      data$human_metric_review_note[idx] <- if ("human_metric_review_note" %in% names(metric_acceptances)) {
        rec$human_metric_review_note
      } else if ("accepted_reason" %in% names(metric_acceptances)) {
        rec$accepted_reason
      } else {
        "Human reviewed metric warning and accepted row as reasonable."
      }
      accepted_count <- accepted_count + 1
    }
  } else {
    cat("  Part C2: manual_metric_review_acceptances.csv missing required columns - skipped\n")
  }
} else {
  cat("  Part C2: no manual metric review acceptances file found\n")
}

if (accepted_count > 0) {
  cat(sprintf("  Part C2: suppressed %d human-accepted metric warnings\n", accepted_count))
}

# ==========================================================================
# PART D: Create checkforerrors_df
# ==========================================================================
# WHAT:  Subsets all flagged records into a dedicated data frame with
#        the most relevant columns (pid, day_num, timestamps, auto_error_desc,
#        and the underlying numeric sleep metrics that triggered review).
# WHY:   This is the working data for Figures 14-18 (auto-detection section).
#        Keeping it as a separate object means visualizations don't need to
#        re-scan the full 14K-row dataset every time.
# ==========================================================================
checkforerrors_df <- data[data$needs_review_flag == TRUE, ]
format_review_time <- function(x) {
  if (inherits(x, c("POSIXct", "POSIXt", "Date"))) {
    formatted <- format(x, "%Y-%m-%d %H:%M:%S %Z")
    formatted[is.na(x)] <- NA_character_
    return(formatted)
  }
  as.character(x)
}

time_cols_for_review <- intersect(c(
  "time_bed_am_hhmm_ampm",
  "time_sleep_am_hhmm_ampm",
  "time_awake_am_hhmm_ampm",
  "time_getup_am_hhmm_ampm",
  "time_bed_corrected",
  "time_sleep_corrected",
  "time_awake_corrected",
  "time_getup_corrected"
), names(checkforerrors_df))

for (col in time_cols_for_review) {
  checkforerrors_df[[paste0(col, "_display")]] <- format_review_time(checkforerrors_df[[col]])
}

raw_time_input_cols <- intersect(c(
  "time_bed_am_hhmm", "time_bed_am_ampm",
  "time_sleep_am_hhmm", "time_sleep_am_ampm",
  "time_awake_am_hhmm", "time_awake_am_ampm",
  "time_getup_am_hhmm", "time_getup_am_ampm"
), names(checkforerrors_df))

display_time_cols <- paste0(time_cols_for_review, "_display")

keep_cols <- c(
  "pid", "day_num", "row_id",
  raw_time_input_cols,
  display_time_cols,
  "time_bed_am_hhmm_ampm", "time_sleep_am_hhmm_ampm",
  "time_awake_am_hhmm_ampm", "time_getup_am_hhmm_ampm",
  "time_bed_corrected", "time_sleep_corrected",
  "time_awake_corrected", "time_getup_corrected",
  "manually_corrected", "needs_review_flag", "auto_error_desc"
)
extra_cols <- intersect(c(
  "self_diffcalc_sol_minutes",
  "self_diffcalc_sleepefficiency_percent",
  "self_diffcalc_totalsleeptime_minutes",
  "self_diffcalc_timeinbed_minutes",
  "sol_category",
  "se_category",
  "tst_tib_ratio_category",
  "metric_duration_input_category",
  "se_is_insane_negative"
), names(data))
keep_cols <- intersect(keep_cols, names(checkforerrors_df))
checkforerrors_df <- checkforerrors_df[, unique(c(keep_cols, extra_cols))]

review_output <- list(
  data_with_flags = data,
  checkforerrors_df = checkforerrors_df
)

cat(sprintf("  Part D: checkforerrors_df created with %d rows\n", nrow(checkforerrors_df)))

# ----------------------------------------------------------------------------
# 3. Unified classification summary (for Figures 19-21)
# ----------------------------------------------------------------------------
# WHAT:  Builds a per-record summary that assigns each flagged record to a
#        data-type category. These are ORGANIZATIONAL LABELS, not exclusion
#        criteria — no data is removed based on its category.
#
# CATEGORIES:
#   TIMESTAMP_ISSUE — clock-time format errors (bed/sleep/awake/getup)
#   DURATION_ISSUE  — interval/format errors (SOL, WASO)
#   AMOUNT_FLAG     — substance input anomalies (text, decimal, filler)
#   NEEDS_REVIEW    — metrics anomalies that need manual inspection
#   CLEAN           — no issues detected
#   CLEAN (Manually Fixed) — had issues but were corrected in step 6
#
# OUTPUT: review_summary data.frame with one row per original data row,
#         flag counts, and final category assignment.
# ----------------------------------------------------------------------------
cat("\n--- 3. Building unified classification summary (checkforerrors_summary) ---\n")

data_with_flags_local <- review_output$data_with_flags
all_check_columns <- names(data_with_flags_local)[grepl("_checkforerrors$", names(data_with_flags_local))]

n_rows <- nrow(data_with_flags_local)

timestamp_flags <- integer(n_rows)
duration_flags <- integer(n_rows)
amount_flags <- integer(n_rows)
review_flags <- integer(n_rows)
has_any <- logical(n_rows)
flag_details <- character(n_rows)

# Data-type mapping (organizational labels, NOT exclusion criteria)
column_type_mapping <- setNames(rep("EXCLUDED", length(all_check_columns)), all_check_columns)
column_description_mapping <- setNames(all_check_columns, all_check_columns)

# --- CLASSIFICATION BY DATA TYPE ---

# TIMESTAMP_ISSUE: Clock-time format errors (bed/sleep/awake/getup)
for (pat in c("time_bed_am", "time_sleep_am", "time_awake_am", "time_getup_am")) {
  col <- paste0(pat, "_checkforerrors")
  if (col %in% all_check_columns) { column_type_mapping[col] <- "TIMESTAMP_ISSUE"; column_description_mapping[col] <- paste(pat, "format error") }
}

# DURATION_ISSUE: Interval/duration format errors (SOL, WASO)
sol_cols <- grep("duration_totalmin_sol.*_checkforerrors", all_check_columns, value = TRUE)
for (col in sol_cols) { column_type_mapping[col] <- "DURATION_ISSUE"; column_description_mapping[col] <- "SOL interval error" }
waso_cols <- grep("duration_totalmin_waso.*_checkforerrors", all_check_columns, value = TRUE)
for (col in waso_cols) { column_type_mapping[col] <- "DURATION_ISSUE"; column_description_mapping[col] <- "WASO interval issue" }

# AMOUNT_FLAG: Input structural anomalies in substance values
#   Detected issues: negative values, excessive digits, filler codes, etc.
amount_cols <- grep("_value_checkforerrors", all_check_columns, value = TRUE)
for (col in amount_cols) {
  column_type_mapping[col] <- "AMOUNT_FLAG"
  label <- gsub("_value_checkforerrors", "", col)
  column_description_mapping[col] <- paste0(label, " input anomaly")
}
# Substance timestamp format issues → AMOUNT_FLAG (informational, contextual data)
subst_amount_cols <- grep("^(caffeinetoday|alcoholtoday|nicotine_amount|nicotine_amount_pm|cannabis_amount)_checkforerrors", all_check_columns, value = TRUE)
for (col in subst_amount_cols) {
  if (column_type_mapping[col] == "EXCLUDED") {
    column_type_mapping[col] <- "AMOUNT_FLAG"
    column_description_mapping[col] <- "substance timestamp note"
  }
}

# NEEDS_REVIEW: Metrics anomalies flagged in Part C (catch-all for manual review)
#   Applied dynamically below based on Part C detection

for (col in all_check_columns) {
  col_data <- data_with_flags_local[[col]]
  if (is.logical(col_data)) prob <- !is.na(col_data) & col_data == TRUE
  else if (is.character(col_data)) prob <- !is.na(col_data) & col_data != ""
  else prob <- rep(FALSE, n_rows)
  
  if (column_type_mapping[col] %in% c("TIMESTAMP_ISSUE", "DURATION_ISSUE", "AMOUNT_FLAG")) {
    has_any <- has_any | prob
  }
  if (column_type_mapping[col] == "TIMESTAMP_ISSUE") timestamp_flags <- timestamp_flags + as.numeric(prob)
  else if (column_type_mapping[col] == "DURATION_ISSUE") duration_flags <- duration_flags + as.numeric(prob)
  else if (column_type_mapping[col] == "AMOUNT_FLAG") amount_flags <- amount_flags + as.numeric(prob)
  
  idx <- which(prob & flag_details == "")
  if (length(idx) > 0) flag_details[idx] <- column_description_mapping[col]
}

# Part C metrics anomalies → NEEDS_REVIEW (catch-all, not a data type)
if (exists("metrics_idx") && length(metrics_idx) > 0) {
  has_any[metrics_idx] <- TRUE
  review_flags[metrics_idx] <- review_flags[metrics_idx] + 1
}

review_summary <- data.frame(
  pid = data_with_flags_local$pid,
  day_num = data_with_flags_local$day_num,
  row_id = data_with_flags_local$row_id,
  manually_corrected = data_with_flags_local$manually_corrected,
  has_any_issue = has_any,
  timestamp_flags = timestamp_flags,
  duration_flags = duration_flags,
  amount_flags = amount_flags,
  review_flags = review_flags,
  flag_details = flag_details,
  stringsAsFactors = FALSE
)

raw_category <- character(n_rows)
raw_category[timestamp_flags > 0] <- "TIMESTAMP_ISSUE"
raw_category[timestamp_flags == 0 & duration_flags > 0] <- "DURATION_ISSUE"
raw_category[timestamp_flags == 0 & duration_flags == 0 & amount_flags > 0] <- "AMOUNT_FLAG"
raw_category[timestamp_flags == 0 & duration_flags == 0 & amount_flags == 0 & review_flags > 0] <- "SELF_REPORTED_FLAG"
raw_category[timestamp_flags == 0 & duration_flags == 0 & amount_flags == 0 & review_flags == 0] <- "CLEAN"
final_status <- raw_category
final_status[review_summary$manually_corrected] <- "CLEAN (Manually Fixed)"

review_summary$raw_category <- raw_category
review_summary$final_status <- final_status

review_output$checkforerrors_summary <- list(
  review_summary = review_summary,
  classification_rules = list(type = column_type_mapping, description = column_description_mapping)
)

checkforerrors_summary <- list(
  review_summary = review_summary,
  classification_rules = list(type = column_type_mapping, description = column_description_mapping)
)

cat("Final status distribution (checkforerrors_summary):\n")
print(table(review_summary$final_status, useNA = "ifany"))

# ============================================================================
# ASSERTION: Flag Distribution Report
# ============================================================================
# WHAT:  Prints a final summary table showing how many records fall into
#        each category. This is the primary quality check output —
#        run after the pipeline to confirm no unexpected spike in any category.
# ============================================================================
timestamp_count <- sum(review_summary$raw_category == "TIMESTAMP_ISSUE", na.rm = TRUE)
duration_count <- sum(review_summary$raw_category == "DURATION_ISSUE", na.rm = TRUE)
amount_count <- sum(review_summary$raw_category == "AMOUNT_FLAG", na.rm = TRUE)
review_count <- sum(review_summary$raw_category == "SELF_REPORTED_FLAG", na.rm = TRUE)
clean_count <- sum(review_summary$raw_category == "CLEAN", na.rm = TRUE)
fixed_count <- sum(review_summary$final_status == "CLEAN (Manually Fixed)", na.rm = TRUE)

cat("\n")
cat(paste(rep("=", 60), collapse = ""))
cat("\nFLAG DISTRIBUTION REPORT\n")
cat(paste(rep("=", 60), collapse = ""))
cat(sprintf("\n  TIMESTAMP_ISSUE (clock-time errors): %d", timestamp_count))
cat(sprintf("\n  DURATION_ISSUE  (interval errors):   %d", duration_count))
cat(sprintf("\n  AMOUNT_FLAG     (substance/amount):  %d", amount_count))
cat(sprintf("\n  SELF-REPORTED FLAG (SOL/WASO diary anomalies): %d", review_count))
cat(sprintf("\n  CLEAN           (no issues):         %d", clean_count))
cat(sprintf("\n  CLEAN (Manually Fixed):              %d", fixed_count))
cat(sprintf("\n  ─────────────────────────────────────────"))
cat(sprintf("\n  TOTAL:                                %d", nrow(review_summary)))

if (timestamp_count > 0) {
  cat("\n\n⚠️  TIMESTAMP_ISSUE records detected:\n")
  ts_records <- review_summary %>%
    filter(raw_category == "TIMESTAMP_ISSUE") %>%
    select(pid, day_num, flag_details)
  print(ts_records)
}

if (duration_count > 0) {
  cat("\n⚠️  DURATION_ISSUE records detected:\n")
  dur_records <- review_summary %>%
    filter(raw_category == "DURATION_ISSUE") %>%
    select(pid, day_num, flag_details)
  print(dur_records)
}

if (review_count > 0) {
  cat("\n\n  SELF-REPORTED FLAG breakdown:\n")
  rs_sr <- review_summary[review_summary$raw_category == "SELF_REPORTED_FLAG", , drop = FALSE]
  d_flags <- data_with_flags_local[rownames(rs_sr), , drop = FALSE]
  sr_sol_excessive <- sum(d_flags$sol_category == "excessive", na.rm = TRUE)
  sr_ratio_low <- sum(d_flags$tst_tib_ratio_category == "very_low", na.rm = TRUE)
  sr_both <- sum(d_flags$sol_category == "excessive" & d_flags$tst_tib_ratio_category == "very_low", na.rm = TRUE)
  cat(sprintf("    SOL excessive (>&nbsp;%dmin):         %d\n", 
              config_get(pipeline_config, "classification.metric_validation.sol.excessive_minutes", 120), sr_sol_excessive))
  if (sr_both > 0) cat(sprintf("      └─ also with TST/TIB < 0.5:       %d\n", sr_both))
  cat(sprintf("    TST/TIB very_low (<0.5):         %d\n", sr_ratio_low - sr_both))
  cat(sprintf("    ────────────────────────────────\n"))
  cat(sprintf("    Total SELF-REPORTED FLAG:        %d\n", review_count))
  rm(rs_sr, d_flags, sr_sol_excessive, sr_ratio_low, sr_both)
}

if (timestamp_count == 0 && duration_count == 0) {
  cat("\n✅ No timestamp or duration issues. Data integrity checks passed.\n")
}

cat("\n")
cat(paste(rep("=", 60), collapse = ""))
cat("\n=== [checkforerrors_processing] Finished ===\n")
cat("Objects created: review_output, checkforerrors_summary\n")
