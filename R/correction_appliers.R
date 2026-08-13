# Internalised correction appliers (nap/exercise, metric durations, acceptances)
#
# Three applier functions copied verbatim from inst/scripts/ during
# TECH_DEBT item 4. Script copies retained (legacy entry + verifier source
# them); bodies locked identical by test-internalised-in-sync.R.
#
# @keywords internal
# @noRd
# @importFrom dplyr matches tail n
# @importFrom tidyr separate
# @importFrom lubridate minutes now interval duration
#' @importFrom utils read.csv

# ----------------------------------------------------------------------
# From apply_nap_exercise_corrections.R
# ----------------------------------------------------------------------

# ============================================================================
# NAP/EXERCISE MANUAL CORRECTION APPLICATOR
# ============================================================================
# Reads manual_nap_exercise_corrections.csv and applies each correction to
# corrected_ema_data: updates the _mincalc value, updates _correctionsmade,
# clears the _checkforerrors flag, and sets manually_corrected = TRUE.
#
# This complements error_unusual_sleep_time_corrections.R (step 6), which
# handles sleep-timestamp corrections. Nap/exercise duration corrections
# are structurally different (numeric values, not timestamps) so they get
# their own simpler pipeline step.
#
# INPUT:  corrected_ema_data (from step 6)
#         manual_nap_exercise_corrections.csv (the corrections table)
# OUTPUT: corrected_ema_data with nap/exercise values corrected
# ============================================================================

apply_nap_exercise_corrections <- function(data, cfg = NULL) {

  cat("\n=== Applying nap/exercise manual corrections ===\n")

  corr_file <- cfg_get("data.files.manual_nap_exercise", "manual_nap_exercise_corrections.csv", cfg = cfg)
  if (!file.exists(corr_file)) {
    cat(sprintf("  No corrections file found (%s) \u2014 skipping\n", corr_file))
    return(data)
  }

  corr <- read.csv(corr_file, stringsAsFactors = FALSE)
  cat(sprintf("  Read %d correction records from %s\n", nrow(corr), corr_file))

  applied_count <- 0
  skipped_count <- 0

  for (i in seq_len(nrow(corr))) {
    r <- corr[i, ]

    corr_status <- tolower(as.character(r$manually_corrected))
    if (!corr_status %in% c("true", "verified_recode")) {
      skipped_count <- skipped_count + 1
      next
    }

    pid_val <- r$pid
    day_val <- r$day_num
    row_val <- r$row_id
    var_name <- r$variable
    correct_min <- as.numeric(r$corrected_mincalc)

    min_col <- paste0(var_name, "_mincalc")
    err_col <- paste0(var_name, "_checkforerrors")
    corr_col <- paste0(var_name, "_correctionsmade")
    problem_col <- "problem_description"

    if (!(min_col %in% names(data))) {
      cat(sprintf("  Skipping non-nap/exercise correction row: pid=%s day=%s variable=%s (column not found)\n",
                  pid_val, day_val, var_name))
      skipped_count <- skipped_count + 1
      next
    }

    idx <- which(data$pid == pid_val & data$day_num == day_val & data$row_id == row_val)
    if (length(idx) == 0) {
      cat(sprintf("  \u26a0 No match: pid=%s day=%s row_id=%s \u2014 skipped\n", pid_val, day_val, row_val))
      skipped_count <- skipped_count + 1
      next
    }
    if (length(idx) > 1) {
      cat(sprintf("  \u26a0 Multiple matches: pid=%s day=%s \u2014 skipped\n", pid_val, day_val))
      skipped_count <- skipped_count + 1
      next
    }

    raw_before <- data[[var_name]][idx]
    corr_before <- if (corr_col %in% names(data)) data[[corr_col]][idx] else NA

    data[[min_col]][idx] <- correct_min
    if (err_col %in% names(data)) {
      data[[err_col]][idx] <- NA
    }
    if (corr_col %in% names(data)) {
      new_note <- sprintf("Manual fix: %s (was %s, corrected to %.1f min)",
                          r$problem_humanidentified, raw_before, correct_min)
      data[[corr_col]][idx] <- if (is.na(corr_before)) new_note else paste(corr_before, new_note, sep = "; ")
    }

    if ("manually_corrected" %in% names(data)) {
      data$manually_corrected[idx] <- TRUE
    }

    if (problem_col %in% names(data)) {
      existing <- data[[problem_col]][idx]
      data[[problem_col]][idx] <- if (is.na(existing)) {
        r$problem_humanidentified
      } else {
        paste(existing, r$problem_humanidentified, sep = "; ")
      }
    }

    cat(sprintf("  \u2705 pid=%s day=%s row_id=%s %s: %.1f min (was %s)\n",
                pid_val, day_val, row_val, var_name, correct_min, raw_before))
    applied_count <- applied_count + 1
  }

  cat(sprintf("  Nap/exercise corrections applied: %d\n", applied_count))
  cat(sprintf("  Correction rows skipped: %d\n", skipped_count))
  return(data)
}

# ----------------------------------------------------------------------
# From apply_sleep_metric_duration_corrections.R
# ----------------------------------------------------------------------

# ============================================================================
# SLEEP METRIC DURATION MANUAL CORRECTION APPLICATOR
# ============================================================================
# Reads manual_sleep_metric_duration_corrections.csv and applies targeted
# duration corrections used by Step 7 sleep metric calculations.
#
# This is separate from Step 6 timestamp corrections because these rows have
# valid bed/sleep/awake/getup timestamps. The problem is a duration input
# (usually SOL estimate, occasionally WASO estimate) that was parsed as an
# implausible number of minutes and then made TST/SE impossible.
# ============================================================================

apply_sleep_metric_duration_corrections <- function(data, cfg = NULL) {

  cat("\n=== Applying sleep metric duration corrections ===\n")

  corr_file <- cfg_get("data.files.manual_metric_duration", "manual_sleep_metric_duration_corrections.csv", cfg = cfg)
  if (!file.exists(corr_file)) {
    cat(sprintf("  No corrections file found (%s) - skipping\n", corr_file))
    return(data)
  }

  corr <- read.csv(corr_file, stringsAsFactors = FALSE)
  cat(sprintf("  Read %d correction records from %s\n", nrow(corr), corr_file))

  applied_count <- 0
  skipped_count <- 0

  for (i in seq_len(nrow(corr))) {
    r <- corr[i, ]

    if (!isTRUE(r$manually_corrected)) {
      skipped_count <- skipped_count + 1
      next
    }

    pid_val <- r$pid
    day_val <- r$day_num
    row_val <- r$row_id
    var_name <- r$variable
    correct_min <- as.numeric(r$corrected_mincalc)

    min_col <- paste0(var_name, "_mincalc")
    err_col <- paste0(var_name, "_checkforerrors")
    audit_col <- paste0(var_name, "_correctionsmade")

    if (!(min_col %in% names(data)) || is.na(correct_min)) {
      cat(sprintf("  Skipping correction row: pid=%s day=%s variable=%s\n",
                  pid_val, day_val, var_name))
      skipped_count <- skipped_count + 1
      next
    }

    idx <- which(data$pid == pid_val & data$day_num == day_val & data$row_id == row_val)
    if (length(idx) != 1) {
      cat(sprintf("  No unique match: pid=%s day=%s row_id=%s - skipped\n",
                  pid_val, day_val, row_val))
      skipped_count <- skipped_count + 1
      next
    }

    before_min <- data[[min_col]][idx]

    # The interval parser now handles the recurring SOL/WASO MM:SS tail case
    # directly (e.g., 10:30 -> 10.5 minutes). Do not let older manual rows that
    # used objective SOL as a workaround overwrite the parser-derived value.
    existing_audit <- if (audit_col %in% names(data)) data[[audit_col]][idx] else NA_character_
    if (!is.na(existing_audit) &&
        grepl("sleep metric duration MM:SS threshold conversion", existing_audit, fixed = TRUE)) {
      if (err_col %in% names(data)) {
        data[[err_col]][idx] <- FALSE
      }
      cat(sprintf("  Parser already converted pid=%s day=%s row_id=%s %s via MM:SS threshold - skipped manual override\n",
                  pid_val, day_val, row_val, var_name))
      skipped_count <- skipped_count + 1
      next
    }

    data[[min_col]][idx] <- correct_min

    if (err_col %in% names(data)) {
      data[[err_col]][idx] <- NA
    }

    if (audit_col %in% names(data)) {
      existing <- data[[audit_col]][idx]
      new_note <- sprintf(
        "Manual metric-duration fix: %s; %s; parsed %.1f min -> %.1f min",
        r$problem_humanidentified,
        r$solution_humanidentified,
        as.numeric(before_min),
        correct_min
      )
      data[[audit_col]][idx] <- if (is.na(existing) || existing == "") {
        new_note
      } else {
        paste(existing, new_note, sep = "; ")
      }
    }

    if ("manually_corrected" %in% names(data)) {
      data$manually_corrected[idx] <- TRUE
    }

    if ("problem_description" %in% names(data)) {
      existing_problem <- data$problem_description[idx]
      data$problem_description[idx] <- if (is.na(existing_problem) || existing_problem == "") {
        r$problem_humanidentified
      } else {
        paste(existing_problem, r$problem_humanidentified, sep = "; ")
      }
    }

    cat(sprintf("  Applied pid=%s day=%s row_id=%s %s: %.1f -> %.1f min\n",
                pid_val, day_val, row_val, var_name, as.numeric(before_min), correct_min))
    applied_count <- applied_count + 1
  }

  cat(sprintf("  Sleep metric duration corrections applied: %d\n", applied_count))
  cat(sprintf("  Correction rows skipped: %d\n", skipped_count))
  return(data)
}

# ----------------------------------------------------------------------
# From apply_metric_review_acceptances.R
# ----------------------------------------------------------------------

# ============================================================================
# HUMAN-ACCEPTED METRIC REVIEW APPLICATOR
# ============================================================================
# Reads manual_metric_review_acceptances.csv and records rows that a human has
# reviewed and accepted as not errors. This does not modify raw timestamps,
# corrected timestamps, or duration values. It only carries the review decision
# forward so Step 8 can suppress repeated checkforerrors warnings.
# ============================================================================

apply_metric_review_acceptances <- function(data, cfg = NULL) {

  cat("\n=== Applying human metric review acceptances ===\n")

  accept_file <- cfg_get("data.files.manual_metric_accept", "manual_metric_review_acceptances.csv", cfg = cfg)
  if (!file.exists(accept_file)) {
    cat(sprintf("  No acceptances file found (%s) - skipping\n", accept_file))
    return(data)
  }

  accept <- read.csv(accept_file, stringsAsFactors = FALSE)
  required_cols <- c("pid", "day_num", "row_id", "human_metric_review_status")
  if (!all(required_cols %in% names(accept))) {
    cat("  Acceptances file missing required columns - skipped\n")
    return(data)
  }

  if (!"human_metric_review_status" %in% names(data)) {
    data$human_metric_review_status <- NA_character_
  }
  if (!"human_metric_review_note" %in% names(data)) {
    data$human_metric_review_note <- NA_character_
  }

  applied_count <- 0
  skipped_count <- 0

  for (i in seq_len(nrow(accept))) {
    rec <- accept[i, ]
    idx <- which(data$pid == rec$pid & data$day_num == rec$day_num & data$row_id == rec$row_id)
    if (length(idx) != 1) {
      skipped_count <- skipped_count + 1
      next
    }

    data$human_metric_review_status[idx] <- rec$human_metric_review_status
    data$human_metric_review_note[idx] <- if ("human_metric_review_note" %in% names(accept)) {
      rec$human_metric_review_note
    } else {
      "Human reviewed metric warning and accepted row as reasonable."
    }
    applied_count <- applied_count + 1
  }

  cat(sprintf("  Human metric review acceptances applied: %d\n", applied_count))
  cat(sprintf("  Acceptance rows skipped: %d\n", skipped_count))
  return(data)
}
