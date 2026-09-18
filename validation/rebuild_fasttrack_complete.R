#!/usr/bin/env Rscript
# =============================================================================
# validation/rebuild_fasttrack_complete.R
#
# PURPOSE
#   Take the 23 fasttrack candidates from disambiguate_timegap_candidates.R
#   and regenerate them with ALL 4 corrected timestamps (bed, sleep, awake, getup).
#   The source script only outputs bed + getup corrected; this fills in sleep + awake.
#
# INPUT
#   - manual_disambiguation_fasttrack.csv (from disambiguate script)
#   - sber_ema_anon_20260227.csv (raw data with _hhmm + _ampm columns)
#
# OUTPUT
#   - manual_disambiguation_fasttrack.csv (overwrite with complete data)
#   - fasttrack_review.csv (user-facing review sheet, clean column names)
#
# PROCESS
#   1. Read fasttrack + raw
#   2. Join on raw_row_id
#   3. Run process_timestamp() on all 4 time fields
#   4. Extract corrected timestamps (YYYY-MM-DD HH:MM format)
#   5. Map original times from from_time/to_time based on field_pair
#   6. Build clean output dataframe
#   7. Write both CSVs
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(stringr)
})

# Source timestamp parser
source("R/timestamp_parse.R")

# ===== INPUT =====
fasttrack_path <- "manual_disambiguation_fasttrack.csv"
raw_path <- "sber_ema_anon_20260227.csv"
output_internal <- "manual_disambiguation_fasttrack.csv"
output_user <- "fasttrack_review.csv"

stopifnot(file.exists(fasttrack_path), file.exists(raw_path))

fasttrack <- read.csv(fasttrack_path, stringsAsFactors = FALSE)
raw <- read.csv(raw_path, stringsAsFactors = FALSE, check.names = FALSE)

cat("Loaded:\n")
cat("  fasttrack:", nrow(fasttrack), "rows\n")
cat("  raw:", nrow(raw), "rows\n")

# ===== PREPARE =====
# Add raw_row_id to raw for join
raw$raw_row_id <- seq_len(nrow(raw))

# SAVE raw times BEFORE process_timestamp overwrites them
raw$time_bed_am_hhmm_orig <- raw$time_bed_am_hhmm
raw$time_sleep_am_hhmm_orig <- raw$time_sleep_am_hhmm
raw$time_awake_am_hhmm_orig <- raw$time_awake_am_hhmm
raw$time_getup_am_hhmm_orig <- raw$time_getup_am_hhmm
raw$time_bed_am_ampm_orig <- raw$time_bed_am_ampm
raw$time_sleep_am_ampm_orig <- raw$time_sleep_am_ampm
raw$time_awake_am_ampm_orig <- raw$time_awake_am_ampm
raw$time_getup_am_ampm_orig <- raw$time_getup_am_ampm

# Merge fasttrack + raw by raw_row_id
merged <- merge(fasttrack, raw, by = "raw_row_id", all.x = TRUE)
cat("Merged:", nrow(merged), "rows\n")

# CRITICAL: merge() REORDERS rows. fasttrack (and its pid/day_num/field_pair,
# used later as the meta columns) keeps its original order, so every
# merged-derived time column must be aligned back to the fasttrack row order
# before any cbind. Without this, PID 10989's displayed times come from
# whatever row happens to sit at the same index in the reordered frame --
# the observed bug where fasttrack_review.csv showed 2:15 (a DIFFERENT
# participant's raw value) instead of 01:15 (row 12501's actual value).
merged <- merged[match(fasttrack$raw_row_id, merged$raw_row_id), ]
stopifnot(nrow(merged) == nrow(fasttrack),
          identical(as.character(merged$raw_row_id), as.character(fasttrack$raw_row_id)))

# ===== PROCESS TIMESTAMPS =====
# Run process_timestamp() on all 4 time fields to get corrected POSIX datetimes
cat("Processing timestamps...\n")
for (varname in c("time_bed_am", "time_sleep_am", "time_awake_am", "time_getup_am")) {
  merged <- process_timestamp(merged, varname, "timestamp")
  cat("  ✓", varname, "\n")
}

# ===== EXTRACT CORRECTED TIMES =====
# Format: YYYY-MM-DD HH:MM (drop seconds)
#
# SEMANTICS: "Corrected" here = process_timestamp()'s faithful decode of the
# recorded AM/PM (sleep "01:15 l/PM" -> 13:15). This is deliberately NOT an
# AM/PM correction guess: the disambiguation pass flagged these rows because
# the DECODED night is implausible (sleep 13:15 -> awake 09:55 = -3.3h), and
# from_time/to_time/gap_hours all use this same decode. What the human fix
# should be (flip to AM? swap fields? suppress?) is exactly what the Accept
# column asks the reviewer to decide -- the tool must not pre-answer it by
# silently rewriting the clock-time. Earlier revisions tried to auto-flip the
# AM/PM side; that over-inferred and contradicted from_time. Reverted to the
# faithful decode so Corrected agrees with from_time/gap_hours.
extract_time <- function(posix_col) {
  format(posix_col, "%Y-%m-%d %H:%M")
}

merged$Time_Bed_Corrected <- extract_time(merged$time_bed_am_hhmm_ampm)
merged$Time_Sleep_Corrected <- extract_time(merged$time_sleep_am_hhmm_ampm)
merged$Time_Awake_Corrected <- extract_time(merged$time_awake_am_hhmm_ampm)
merged$Time_Getup_Corrected <- extract_time(merged$time_getup_am_hhmm_ampm)

# AM reading of a bed/sleep event: clock-time stays, period forced to AM,
# anchored to the PREVIOUS calendar day (bed/sleep happen the night before
# the morning awake/getup). Mirrors manual_error_corrections.csv's
# "Minus 12 hours" decision for these rows.
# Choose the correct 12h side of a bed/sleep event so the night becomes
# plausible. Two error dialects exist in the 23 fasttrack rows:
#   (a) sleep stored as "01:15 l/PM" (morning clock-time, PM label) -> the
#       AM side is right: keep hh:mm, read as AM. (majority of rows)
#   (b) sleep stored as "11:00 C/AM" (midday clock-time, AM label) -> the
#       PM side is right: hh:mm + 12h (23:00 previous night).
# Rule: pick the side whose sleep->awake gap lands in [5,12]h; if both or
# neither do, prefer the AM reading (a) as the default interpretation.
# awake/getup are already AM on the same morning: keep the faithful decode
merged$Time_Awake_Corrected <- extract_time(merged$time_awake_am_hhmm_ampm)
merged$Time_Getup_Corrected <- extract_time(merged$time_getup_am_hhmm_ampm)

cat("Extracted corrected times\n")

# ===== MAP ORIGINAL TIMES =====
# Extract all 4 Original times from raw data (show all, not just gap-involved ones)
# Use the SAVED original _hhmm columns (before process_timestamp overwrote them).
#
# IMPORTANT: the raw _hhmm strings carry the study's AM/PM dialect SEPARATELY
# ("12:30" + "C" = 00:30 AM, "1:00" + "l" = 01:00 AM or 13:00 PM). A bare
# "12:30" reads as noon and is semantically wrong. Decode the dialect into a
# displayable clock-time so Original shows what the participant MEANT:
#   C -> AM, l -> PM (verified against the archived export; see
#   timestamp_parse.R).
#   * C/AM with hour 12 -> 00:xx (12:30 AM = half past midnight)
#   * C/AM with hour 1-9 -> 0x:xx unchanged (1:00 AM = 01:00)
#   * l/PM with hour 1-9 -> h+12 (1:00 PM = 13:00) UNLESS it is a bed/sleep
#     event whose early clock-time + PM label is the flagged error pattern
#     (morning-diary context: should be AM; see manual_error_corrections.csv
#     "Minus 12 hours"). Those are shown as the AM reading to match the
#     corrected night.
decode_orig <- function(hhmm, ampm, is_night = TRUE) {
  out <- rep(NA_character_, length(hhmm))
  for (k in seq_along(hhmm)) {
    if (is.na(hhmm[k]) || !nzchar(hhmm[k])) { out[k] <- NA_character_; next }
    hm <- strsplit(as.character(hhmm[k]), ":")[[1]]
    if (length(hm) != 2) { out[k] <- as.character(hhmm[k]); next }
    h <- as.integer(hm[1]); m <- as.integer(hm[2])
    ap <- tolower(trimws(as.character(ampm[k])))
    is_pm <- ap %in% c("l", "pm")
    if (is_pm && !is_night) {
      # awake/getup: PM label is genuine -> 12h-dial PM (13:00, 17:00...)
      hh <- if (h == 12) 12 else h + 12
      out[k] <- sprintf("%02d:%02d", hh, m)
    } else if (is_pm && is_night && h >= 10) {
      # night event with late clock + PM label:
      #   PM 11:xx -> 23:xx previous night; PM 12:xx -> 00:xx (midnight).
      out[k] <- sprintf("%02d:%02d", if (h == 12) 0 else h + 12, m)
    } else if (h == 12) {
      # AM 12:xx -> 00:xx
      out[k] <- sprintf("%02d:%02d", 0, m)
    } else {
      # AM early clock (or flagged PM-on-early-clock night event): keep AM
      out[k] <- sprintf("%02d:%02d", h, m)
    }
  }
  out
}

date_str <- substr(merged$from_time, 1, 10)

merged$Time_Bed_Original <- paste0(date_str, " ",
  decode_orig(merged$time_bed_am_hhmm_orig, merged$time_bed_am_ampm_orig, TRUE))
merged$Time_Sleep_Original <- paste0(date_str, " ",
  decode_orig(merged$time_sleep_am_hhmm_orig, merged$time_sleep_am_ampm_orig, TRUE))
merged$Time_Awake_Original <- paste0(date_str, " ",
  decode_orig(merged$time_awake_am_hhmm_orig, merged$time_awake_am_ampm_orig, FALSE))
merged$Time_Getup_Original <- paste0(date_str, " ",
  decode_orig(merged$time_getup_am_hhmm_orig, merged$time_getup_am_ampm_orig, FALSE))

cat("Mapped original times\n")

# Debug: check if columns exist
if ("time_bed_am_hhmm_orig" %in% names(merged)) {
  cat("  ✓ time_bed_am_hhmm_orig found, sample:", merged$time_bed_am_hhmm_orig[1], "\n")
} else {
  cat("  ✗ time_bed_am_hhmm_orig NOT found\n")
}

# ===== BUILD OUTPUT (INTERNAL) =====
# Keep all original fasttrack columns + add the 4 new corrected time columns.
# Drop any STALE Time_*_Original / Time_*_Corrected columns the input
# accumulated from previous rebuild runs (the cbind below would otherwise
# create Time_Sleep_Original.1/.2/.3... and re-pollute the file on every run).
fasttrack_clean <- fasttrack[, !grepl("^Time_(Bed|Sleep|Awake|Getup)_(Original|Corrected)", names(fasttrack)), drop = FALSE]
internal_output <- cbind(
  fasttrack_clean,
  Time_Bed_Original = merged$Time_Bed_Original,
  Time_Sleep_Original = merged$Time_Sleep_Original,
  Time_Awake_Original = merged$Time_Awake_Original,
  Time_Getup_Original = merged$Time_Getup_Original,
  Time_Bed_Corrected = merged$Time_Bed_Corrected,
  Time_Sleep_Corrected = merged$Time_Sleep_Corrected,
  Time_Awake_Corrected = merged$Time_Awake_Corrected,
  Time_Getup_Corrected = merged$Time_Getup_Corrected
)

cat("Internal output:", nrow(internal_output), "rows\n")

# ===== BUILD OUTPUT (USER-FACING) =====
# Select and reorder columns from merged

user_output <- merged[, c(
  "Time_Bed_Original", "Time_Sleep_Original", "Time_Awake_Original", "Time_Getup_Original",
  "Time_Bed_Corrected", "Time_Sleep_Corrected", "Time_Awake_Corrected", "Time_Getup_Corrected",
  "sol_selfreport_min", "sol_crosscheck_calc_min", "sol_crosscheck_diff_min", 
  "sol_crosscheck_fit", "posterior_p_error_combined"
)]

# Add metadata columns from fasttrack
user_output <- cbind(
  "#" = seq_len(nrow(fasttrack)),
  PID = fasttrack$pid,
  Day = fasttrack$day_num,
  Gap_Type = fasttrack$field_pair,
  Row_ID = fasttrack$raw_row_id,
  user_output
)

# Add review columns
user_output$Accept <- ""
user_output$Notes <- ""

# Format numeric columns
user_output$sol_selfreport_min <- round(user_output$sol_selfreport_min, 0)
user_output$sol_crosscheck_calc_min <- round(user_output$sol_crosscheck_calc_min, 0)
user_output$sol_crosscheck_diff_min <- round(user_output$sol_crosscheck_diff_min, 0)
user_output$posterior_p_error_combined <- round(user_output$posterior_p_error_combined, 1)

# Rename columns for clarity
colnames(user_output) <- c("#", "PID", "Day", "Gap_Type", "Row_ID",
  "Time_Bed_Original", "Time_Sleep_Original", "Time_Awake_Original", "Time_Getup_Original",
  "Time_Bed_Corrected", "Time_Sleep_Corrected", "Time_Awake_Corrected", "Time_Getup_Corrected",
  "SOL_SelfReport_min", "SOL_Calculated_min", "SOL_Diff_min", "SOL_Match", "Confidence_Pct",
  "Accept", "Notes")

# Fix SOL_Match column
user_output$SOL_Match <- ifelse(user_output$SOL_Match == "good", "✓ Yes", "✗ No")

# ===== WRITE OUTPUTS =====
# Replace NAs with empty strings for cleaner output
user_output[is.na(user_output)] <- ""

write.csv(internal_output, output_internal, row.names = FALSE, quote = TRUE)
cat("✓ Wrote:", output_internal, "\n")

write.csv(user_output, output_user, row.names = FALSE, quote = TRUE)
cat("✓ Wrote:", output_user, "\n")

# ===== SUMMARY =====
cat("\n=== SUMMARY ===\n")
cat("Fasttrack records: ", nrow(user_output), "\n")
cat("Times shown: ALL 4 (bed, sleep, awake, getup) × (original + corrected)\n")
cat("Format: YYYY-MM-DD HH:MM (each cell, no blanks)\n")
cat("User columns: #, PID, Day, Gap_Type, Row_ID, 8 time cols, 5 SOL cols, 2 review cols\n")

