#!/usr/bin/env Rscript
# =============================================================================
# validation/scan_fasttrack_blindspot.R
#
# PURPOSE
#   Second-pass scan for "same-quirk" days the fasttrack filter MISSED.
#
#   fasttrack (derive_timegap_candidates.R) only catches negative
#   sleep->awake gaps in the 3-6h window. But the annotation pass on
#   fasttrack_review_cyra.csv repeatedly found the SAME single-field quirk
#   on UNFLAGGED days (e.g. PID 2095 day8 twin of flagged day7; PID 6805
#   days 1/9/12; PID 11554). This script systematically finds those.
#
#   Blindspot definition (the fasttrack-relevant quirk, relaxed window):
#     - sleep clock-time is 00:00-05:59 (a post-midnight AM sleep time)
#     - sleep ampm label is "l" (PM) -> decodes to 12:00-17:59
#     - awake is AM (06:00-11:59)
#     - raw decoded sleep -> awake gap is NEGATIVE (sleep decodes after awake)
#     - gap magnitude in [0.5, 12]h -- WIDER than fasttrack's [3,6] so we
#       surface near-miss rows too (fasttrack used 3-6h, so 0.5-3h and 6-12h
#       negative gaps were never reviewed)
#
#   Also reports the "twin" signal: same pid + same raw pattern on an
#   unflagged day as on a flagged day.
#
# OUTPUT
#   - console table grouped by pid
#   - scans the same sber export fasttrack reads
#
# USAGE
#   Rscript validation/scan_fasttrack_blindspot.R
# =============================================================================

raw_path     <- "sber_ema_anon_20260227.csv"
review_path  <- "fasttrack_review.csv"     # template (unannotated) for flagged-day set

raw <- read.csv(raw_path, stringsAsFactors = FALSE, check.names = FALSE)
raw$raw_row_id <- seq_len(nrow(raw))

review <- read.csv(review_path, stringsAsFactors = FALSE, check.names = FALSE)
flagged_keys <- paste(review$PID, review$Day)

dec_hour <- function(hhmm, ampm) {
  # returns decoded 24h hour, NA if unparseable
  if (is.na(hhmm) || !nzchar(as.character(hhmm))) return(NA_real_)
  hm <- strsplit(as.character(hhmm), ":")[[1]]
  if (length(hm) != 2) return(NA_real_)
  h <- suppressWarnings(as.numeric(hm[1]))
  if (is.na(h)) return(NA_real_)
  ap <- tolower(trimws(as.character(ampm)))
  if (ap %in% c("l", "pm")) h <- if (h != 12) h + 12 else 12
  if (ap %in% c("c", "am") && h == 12) h <- 0
  h
}

gap_hours <- function(sleep_h, awake_h) {
  # negative gap = sleep decodes AFTER awake (same-calendar-day reading)
  awake_h - sleep_h
}

cat("=== Blindspot scan: post-midnight sleep with PM label, negative gap ===\n")
cat("Window: negative sleep->awake gap in [0.5, 12]h (fasttrack used [3,6])\n\n")

# per row: classify
raw$sleep_h <- mapply(dec_hour, raw$time_sleep_am_hhmm, raw$time_sleep_am_ampm)
raw$awake_h <- mapply(dec_hour, raw$time_awake_am_hhmm, raw$time_awake_am_ampm)
raw$bed_h   <- mapply(dec_hour, raw$time_bed_am_hhmm,   raw$time_bed_am_ampm)

# quirk: sleep clock 00-05 + PM label + awake AM + negative gap in window
sleep_clock_pm <- !is.na(raw$time_sleep_am_hhmm) &
  !is.na(raw$time_sleep_am_ampm) &
  tolower(trimws(raw$time_sleep_am_ampm)) %in% c("l", "pm") &
  !is.na(raw$sleep_h) & raw$sleep_h >= 12 & raw$sleep_h <= 17.99 &
  !is.na(raw$bed_h) & raw$bed_h <= 5.99 &   # post-midnight bed context
  !is.na(raw$awake_h) & raw$awake_h >= 6 & raw$awake_h <= 11.99  # awake genuinely AM (excludes whole-row-timezone-shifted rows)

raw$gap <- mapply(gap_hours, raw$sleep_h, raw$awake_h)

blind <- raw[sleep_clock_pm & !is.na(raw$gap) & raw$gap < 0 & abs(raw$gap) >= 0.5 & abs(raw$gap) <= 12, ]
blind$key <- paste(blind$pid, blind$day_num)
blind$flagged <- blind$key %in% flagged_keys

cat(sprintf("Blindspot rows: %d total (%d flagged already, %d NEW unannotated)\n\n",
            nrow(blind), sum(blind$flagged), sum(!blind$flagged)))

# group by pid, show only non-flagged (the new finds) with their flagged twins
if (sum(!blind$flagged) > 0) {
  new_finds <- blind[!blind$flagged, ]
  new_finds <- new_finds[order(new_finds$pid, new_finds$day_num), ]
  cat("=== NEW unannotated blindspot days ===\n")
  cat(sprintf("%6s %4s %-11s %-10s %-10s %-10s | %6s  %s\n",
              "pid", "day", "date_of_obs", "bed", "sleep", "awake", "gap_h", "same-pid flagged?"))
  for (i in seq_len(nrow(new_finds))) {
    r <- new_finds[i, ]
    bed_s <- ifelse(is.na(r$time_bed_am_hhmm), "NA", paste(r$time_bed_am_hhmm, r$time_bed_am_ampm))
    sl_s  <- ifelse(is.na(r$time_sleep_am_hhmm), "NA", paste(r$time_sleep_am_hhmm, r$time_sleep_am_ampm))
    aw_s  <- ifelse(is.na(r$time_awake_am_hhmm), "NA", paste(r$time_awake_am_hhmm, r$time_awake_am_ampm))
    twin <- any(blind$flagged & blind$pid == r$pid)
    cat(sprintf("%6s %4s %-11s %-10s %-10s %-10s | %6.1f  %s\n",
                r$pid, r$day_num, substr(r$date_of_obs,1,10),
                bed_s, sl_s, aw_s, r$gap, ifelse(twin, "YES", "no")))
  }
  cat("\n=== Summary ===\n")
  cat(sprintf("New blindspot days: %d across %d pids\n", nrow(new_finds), length(unique(new_finds$pid))))
  cat(sprintf("Same-quirk unflagged twins per pid:\n"))
  print(table(new_finds$pid))
} else {
  cat("No NEW blindspot rows found.\n")
}
# =============================================================================
# MISFIRE-RISK TIERING (added 2026-09-24)
#   Two distinct sub-populations hide inside the 32 blindspot rows:
#   A) TRUE quirk (10 rows): sleep clock 00:00-04:59 + "l" label. Same error
#      as the 23 fasttrack rows (post-midnight sleep mislabeled PM). AM
#      correction gives a 5-10h night matching the person's median. LOW
#      false-positive risk -- these should be annotated like fasttrack.
#   B) 12h-dial habit (22 rows): sleep clock 11:00-12:59 + ANY label. The
#      participant writes their post-midnight 00:xx as 11:xx/12:xx by habit
#      (verified: PID 6805 uses 12:05 l, 12:40 C, 11:51 l interchangeably).
#      These are NOT AM/PM label errors -- the clock VALUE is a habit.
#      HIGHER false-positive risk; check per-pid whether the 11/12-xx form
#      recurs before flagging.
