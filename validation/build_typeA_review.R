# =============================================================================
# validation/build_typeA_review.R — build the Type-A blindspot review sheet
#
# PURPOSE
#   The fasttrack blindspot scan (scan_fasttrack_blindspot.R) found 10 days
#   with the SAME post-midnight-sleep + PM-label quirk as the 23 fasttrack
#   rows, but outside the [3,6]h gap window that derive_timegap_candidates.R
#   locks to. These are type-A: sleep clock 00:00-04:59 + "l" label, AM
#   correction yielding a 5-10h night matching the participant's median.
#
#   This script builds fasttrack_review_typeA.csv — a twin of the main review
#   sheet (same columns) for the 10 blindspot days, so they can be annotated
#   in the same independent-review flow.
#
# NOTE: PID 10710 day5 is flagged in the sheet as ambiguous — that
#   participant normally sleeps 22:00-23:00 (10-11 PM l) and day5 is their
#   ONLY post-midnight entry; may be genuine behavior, not a label error.
#
# OUTPUT
#   fasttrack_review_typeA.csv
# =============================================================================

raw <- read.csv("sber_ema_anon_20260227.csv", stringsAsFactors = FALSE, check.names = FALSE)
raw$raw_row_id <- seq_len(nrow(raw))

typeA <- data.frame(
  pid = c(1035, 2095, 3200, 5239, 6855, 6855, 10323, 10710, 10989, 11554),
  day = c(13, 8, 2, 6, 9, 10, 11, 5, 15, 4),
  stringsAsFactors = FALSE
)

dec_hour <- function(hhmm, ampm) {
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

raw$sleep_h <- mapply(dec_hour, raw$time_sleep_am_hhmm, raw$time_sleep_am_ampm)
raw$awake_h <- mapply(dec_hour, raw$time_awake_am_hhmm, raw$time_awake_am_ampm)

# rows must be extracted AFTER sleep_h/awake_h are attached (line 84 uses rows$awake_h)
rows <- raw[paste(raw$pid, raw$day_num) %in% paste(typeA$pid, typeA$day), ]
rows <- rows[!is.na(rows$time_sleep_am_hhmm), ]

med_duration <- function(pid, day) {
  others <- raw[raw$pid == pid & raw$day_num != day & !is.na(raw$time_sleep_am_hhmm), ]
  durs <- numeric()
  if (nrow(others) > 0) {
    for (i in seq_len(nrow(others))) {
      s <- others$sleep_h[i]; a <- others$awake_h[i]
      if (!is.na(s) && !is.na(a) && length(s) == 1 && length(a) == 1) {
        d <- a - s
        if (!is.na(d) && d < 0) d <- d + 24
        if (!is.na(d) && d > 3 && d < 14) durs <- c(durs, d)
      }
    }
  }
  if (length(durs)) median(durs) else NA_real_
}

out <- data.frame(
  "#" = seq_len(nrow(rows)),
  PID = rows$pid,
  Day = rows$day_num,
  Row_ID = rows$raw_row_id,
  Gap_Type = "gap_sleep_awake (blindspot, <3h or >6h)",
  Raw_Bed   = paste0(rows$time_bed_am_hhmm, " ", rows$time_bed_am_ampm),
  Raw_Sleep = paste0(rows$time_sleep_am_hhmm, " ", rows$time_sleep_am_ampm),
  Raw_Awake = paste0(rows$time_awake_am_hhmm, " ", rows$time_awake_am_ampm),
  Raw_Getup = paste0(rows$time_getup_am_hhmm, " ", rows$time_getup_am_ampm),
  SOL_SelfReport_min = rows$duration_sol_estimate_am_hhmm,
  SOL_Calculated_min = NA,
  SOL_Diff_min = NA,
  SOL_Match = NA,
  Confidence_Pct = NA,
  median_night_h = vapply(seq_len(nrow(rows)), function(i) med_duration(rows$pid[i], rows$day_num[i]), numeric(1)),
  AM_corrected_h = vapply(seq_len(nrow(rows)), function(i) {
    sh <- as.numeric(sub(":.*", "", rows$time_sleep_am_hhmm[i]))
    a <- rows$awake_h[i]
    d <- a - sh; if (d < 0) d <- d + 24
    d
  }, numeric(1)),
  Ambiguous = ifelse(rows$pid == 10710 & rows$day_num == 5, "YES - night owl (normally 22-23h)", ""),
  Accept = "",
  Notes = "",
  check.names = FALSE, stringsAsFactors = FALSE
)

out$AM_corrected_h <- round(out$AM_corrected_h, 1)
out$median_night_h <- round(out$median_night_h, 1)

write.csv(out, "fasttrack_review_typeA.csv", row.names = FALSE, quote = TRUE)
cat("Wrote fasttrack_review_typeA.csv:", nrow(out), "rows\n")