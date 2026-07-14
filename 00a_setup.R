# ============================================================================
# 00a_setup.R — Environment and dependency check
# ============================================================================
# Run this before 00_MAIN_entry.R to:
#   1. Auto-detect required R packages by scanning all .R files for
#      library() / require() calls
#   2. Install any missing packages
#   3. Verify all required input files exist before pipeline starts
#
# When sourced from run_pipeline(), uses file paths from pipeline_config.
# When run standalone, uses hardcoded file list for backward compatibility.
# ============================================================================

check_environment <- function() {
  cat("=== Environment Check ===\n")

  # ── Packages ──
  r_files <- list.files(pattern = "\\.R$", ignore.case = TRUE)
  pkg_calls <- unlist(sapply(r_files, function(f) {
    lines <- tryCatch(readLines(f, warn = FALSE), error = function(e) character())
    regmatches(lines, gregexpr("(?<=(library|require)\\().*?(?=\\))", lines, perl = TRUE))
  }))
  needed <- unique(trimws(pkg_calls))
  needed <- sort(setdiff(needed, c("", "tidyverse")))

  missing <- needed[!sapply(needed, requireNamespace, quietly = TRUE)]
  if (length(missing)) {
    cat(sprintf("  Installing %d missing package(s): %s\n", length(missing), paste(missing, collapse = ", ")))
    install.packages(missing)
  } else {
    cat("  All required packages already installed.\n")
  }

  # if tidyverse is needed, install it explicitly
  tidy_missing <- !requireNamespace("tidyverse", quietly = TRUE)
  if (tidy_missing && any(grepl("tidyverse", pkg_calls))) {
    install.packages("tidyverse")
  }

  # ── Required files ──
  # Use pipeline_config if available (via run_pipeline()), else hardcoded defaults
  cfg <- get0("pipeline_config", envir = .GlobalEnv, ifnotfound = NULL)
  if (!is.null(cfg) && !is.null(cfg$data$files)) {
    file_list <- cfg$data$files
    # Filter out empty paths (e.g. manual corrections not used in demo)
    required_files <- unlist(file_list[nchar(file_list) > 0])
    names(required_files) <- NULL
  } else {
    required_files <- c(
      "deidentified_intervalvars_forCD_111325.rds",
      "sber_ema_anon_20260227.csv",
      "second_review_checklist.csv",
      "manual_error_corrections.csv",
      "manual_unusual_corrections.csv",
      "manual_nap_exercise_corrections.csv",
      "manual_sleep_metric_duration_corrections.csv",
      "manual_metric_review_acceptances.csv"
    )
  }

  cat("  Checking input files...\n")
  all_ok <- TRUE
  for (f in required_files) {
    if (file.exists(f)) {
      cat(sprintf("    ✓ %s\n", f))
    } else {
      cat(sprintf("    ✗ %s  (MISSING)\n", f))
      all_ok <- FALSE
    }
  }

  if (!all_ok) {
    stop("Required input file(s) missing. Pipeline cannot proceed.")
  }

  cat("=== Environment OK ===\n")
  invisible(TRUE)
}

# Auto-run only when NOT sourced from run_pipeline()
if (!exists("splsleep_loaded")) {
  check_environment()
}
