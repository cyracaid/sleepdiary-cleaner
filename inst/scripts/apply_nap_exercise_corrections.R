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

apply_nap_exercise_corrections <- function(data) {

  cat("\n=== Applying nap/exercise manual corrections ===\n")

  corr_file <- "manual_nap_exercise_corrections.csv"
  if (!file.exists(corr_file)) {
    cat(sprintf("  No corrections file found (%s) — skipping\n", corr_file))
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
      cat(sprintf("  ⚠ No match: pid=%s day=%s row_id=%s — skipped\n", pid_val, day_val, row_val))
      skipped_count <- skipped_count + 1
      next
    }
    if (length(idx) > 1) {
      cat(sprintf("  ⚠ Multiple matches: pid=%s day=%s — skipped\n", pid_val, day_val))
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

    cat(sprintf("  ✅ pid=%s day=%s row_id=%s %s: %.1f min (was %s)\n",
                pid_val, day_val, row_val, var_name, correct_min, raw_before))
    applied_count <- applied_count + 1
  }

  cat(sprintf("  Nap/exercise corrections applied: %d\n", applied_count))
  cat(sprintf("  Correction rows skipped: %d\n", skipped_count))
  return(data)
}
