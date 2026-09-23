#!/usr/bin/env Rscript
# =============================================================================
# validation/query_pid.R — look up one participant's full raw history
#
# PURPOSE
#   For independent annotation of fasttrack_review.csv: before judging whether
#   a flagged row is a real AM/PM error or genuine behavior, the reviewer
#   needs to see that participant's OTHER days in the raw study dialect.
#   This script prints, for one pid, every observed day's raw bed/sleep/
#   awake/getup entries (hh:mm + C/l/AM/PM exactly as typed) plus the
#   self-reported SOL/WASO, so the flagged day can be compared against the
#   person's own baseline.
#
# USAGE
#   Rscript validation/query_pid.R 10989            # all days for pid 10989
#   Rscript validation/query_pid.R 10989 4          # only day 4
#   Rscript validation/query_pid.R --interactive    # prompt loop (type pid)
#
#   Inside an R session you can source() it and call:
#     show_pid(10989)
#     show_pid(10989, day = 4)
#
# DATA
#   sber_ema_anon_20260227.csv (raw, pre-correction, study dialect intact)
#   fasttrack_review.csv (optional; marks which days are flagged for review)
# =============================================================================

show_pid <- function(pid, day = NULL, raw_path = "sber_ema_anon_20260227.csv",
                     review_path = "fasttrack_review.csv") {
  raw <- read.csv(raw_path, stringsAsFactors = FALSE, check.names = FALSE)
  raw$raw_row_id <- seq_len(nrow(raw))

  pid <- as.character(pid)
  rows <- raw[as.character(raw$pid) == pid, ]
  if (nrow(rows) == 0) {
    cat("pid", pid, ": no rows in", basename(raw_path), "\n")
    return(invisible(NULL))
  }
  rows <- rows[order(rows$day_num), ]

  # Which days are flagged in the review sheet (if it exists)?
  flagged_days <- integer(0)
  if (file.exists(review_path)) {
    rv <- read.csv(review_path, stringsAsFactors = FALSE, check.names = FALSE)
    flagged_days <- rv$Day[as.character(rv$PID) == pid]
  }

  if (!is.null(day)) rows <- rows[rows$day_num == day, ]

  # sber has duplicate/blank rows per day (survey re-opens). Keep only rows
  # that actually carry a bed or sleep entry so the baseline table stays clean.
  has_data <- !is.na(rows$time_bed_am_hhmm) | !is.na(rows$time_sleep_am_hhmm)
  rows <- rows[has_data, ]
  cat(sprintf("\n=== pid %s : %d days with data ===\n", pid, nrow(rows)))
  cat(sprintf("%5s  %-11s %-9s %-9s %-9s %-9s | %-8s %-8s %s\n",
              "day", "date_of_obs", "bed", "sleep", "awake", "getup",
              "SOL", "WASO", "FLAG"))
  for (i in seq_len(nrow(rows))) {
    r <- rows[i, ]
    d <- substr(r$date_of_obs, 1, 10)
    cell <- function(hhmm, ampm) {
      if (is.na(hhmm) || !nzchar(as.character(hhmm))) return("NA")
      paste(hhmm, ampm)
    }
    bed   <- cell(r$time_bed_am_hhmm,    r$time_bed_am_ampm)
    sleep <- cell(r$time_sleep_am_hhmm,  r$time_sleep_am_ampm)
    awake <- cell(r$time_awake_am_hhmm,  r$time_awake_am_ampm)
    getup <- cell(r$time_getup_am_hhmm,  r$time_getup_am_ampm)
    sol   <- if (!"duration_sol_estimate_am_hhmm" %in% names(r) || is.na(r$duration_sol_estimate_am_hhmm)) "NA" else as.character(r$duration_sol_estimate_am_hhmm)
    waso  <- if (!"duration_totalmin_waso_estimate_am" %in% names(r) || is.na(r$duration_totalmin_waso_estimate_am)) "NA" else as.character(r$duration_totalmin_waso_estimate_am)
    fl <- if (r$day_num %in% flagged_days) "<-- FLAGGED" else ""
    cat(sprintf("%5d  %-11s %-9s %-9s %-9s %-9s | %-8s %-8s %s\n",
                r$day_num, d, bed, sleep, awake, getup, sol, waso, fl))
  }
  cat("=== dialect: C = AM, l = PM ===\n")
  invisible(rows)
}

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) >= 1 && args[1] == "--interactive") {
    cat("Interactive pid lookup. Type a pid (or 'q' to quit).\n")
    repeat {
      cat("pid> ")
      line <- readLines("stdin", n = 1)
      if (length(line) == 0 || tolower(trimws(line)) == "q") break
      suppressWarnings(p <- as.integer(trimws(line)))
      if (!is.na(p)) show_pid(p) else cat("not a number\n")
    }
  } else if (length(args) >= 1) {
    pid <- as.integer(args[1])
    day <- if (length(args) >= 2) as.integer(args[2]) else NULL
    show_pid(pid, day)
  } else {
    cat("Usage:\n  Rscript validation/query_pid.R <pid> [day]\n")
    cat("  Rscript validation/query_pid.R --interactive\n")
  }
}