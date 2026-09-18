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
# NOTE on semantics: process_timestamp() decodes the RECORDED AM/PM faithfully
# (a sleep row stored as "01:15 l/PM" decodes to 13:15). But these 23
# gap_sleep_awake candidates are exactly the rows where the morning-diary
# AM/PM label is WRONG -- manual_error_corrections.csv confirms the human
# fix is "Minus 12 hours" / "Same day 02:00 AM": the sleep clock-time belongs
# to the AM side of the night, so the corrected value must be the AM reading
# (01:15, anchored to the previous evening), NOT the PM decoding (13:15).
# Displaying the PM decode as "corrected" keeps the contradiction visible
# (13:15 sleep -> 08:30 awake = -3.3h). The AM reading is the actual fix.
extract_time <- function(posix_col) {
  format(posix_col, "%Y-%m-%d %H:%M")
}

# AM reading of a bed/sleep event: clock-time stays, period forced to AM,
# anchored to the PREVIOUS calendar day (bed/sleep happen the night before
# the morning awake/getup). Mirrors manual_error_corrections.csv's
# "Minus 12 hours" decision for these rows.
am_reading <- function(hhmm, date_str) {
  out <- rep(NA_character_, length(hhmm))
  for (k in seq_along(hhmm)) {
    if (is.na(hhmm[k]) || !nzchar(hhmm[k])) { out[k] <- NA_character_; next }
    hm <- strsplit(as.character(hhmm[k]), ":")[[1]]
    if (length(hm) != 2) { out[k] <- hhmm[k]; next }
    h <- as.integer(hm[1]); m <- as.integer(hm[2])
    out[k] <- sprintf("%s %02d:%02d", date_str[k], h, m)
  }
  out
}

# Choose the correct 12h side of a bed/sleep event so the night becomes
# plausible. Two error dialects exist in the 23 fasttrack rows:
#   (a) sleep stored as "01:15 l/PM" (morning clock-time, PM label) -> the
#       AM side is right: keep hh:mm, read as AM. (majority of rows)
#   (b) sleep stored as "11:00 C/AM" (midday clock-time, AM label) -> the
#       PM side is right: hh:mm + 12h (23:00 previous night).
# Rule: pick the side whose sleep->awake gap lands in [5,12]h; if both or
# neither do, prefer the AM reading (a) as the default interpretation.
bed_sleep_corrected <- function(bed_hhmm, sleep_hhmm, awake_posix, date_str) {
  hm_split <- function(x) {
    parts <- strsplit(x, ":")[[1]]
    if (length(parts) == 2) c(as.integer(parts[1]), as.integer(parts[2])) else c(NA_integer_, NA_integer_)
  }
  gap_h <- function(h, m, dstr) {
    t <- as.POSIXct(sprintf("%s %02d:%02d", dstr, h, m),
                    tz = attr(awake_posix[k], "tzone"))
    g <- as.numeric(difftime(awake_posix[k], t, units = "hours"))
    if (g < 0) g <- g + 24
    g
  }
  out_sleep <- out_bed <- rep(NA_character_, length(sleep_hhmm))
  for (k in seq_along(sleep_hhmm)) {
    if (is.na(sleep_hhmm[k]) || !nzchar(sleep_hhmm[k])) next
    s <- hm_split(sleep_hhmm[k])
    if (is.na(s[1])) { out_sleep[k] <- sleep_hhmm[k]; next }
    dstr <- date_str[k]
    g_am <- gap_h(s[1], s[2], dstr)
    # PM side = hh:mm + 12h, anchored the PREVIOUS day (23:00 the night
    # before the awake morning). Same-side-with-previous-date keeps the
    # night span correct: sleep 23:00 (prev day) -> awake 07:30 = 8.5h.
    prev_dstr <- as.character(as.Date(dstr) - 1)
    g_pm <- gap_h(if (s[1] == 12) s[1] else s[1] + 12, s[2], prev_dstr)
    use_pm <- is.finite(g_am) && is.finite(g_pm) &&
      !(g_am >= 5 && g_am <= 12) && (g_pm >= 5 && g_pm <= 12)
    if (use_pm) {
      hh <- if (s[1] == 12) "12" else sprintf("%02d", s[1] + 12)
      out_sleep[k] <- sprintf("%s %s:%02d", prev_dstr, hh, s[2])
    } else {
      out_sleep[k] <- sprintf("%s %02d:%02d", dstr, s[1], s[2])
    }
    # bed keeps its clock-time on the same side as sleep (same night)
    if (!is.na(bed_hhmm[k]) && nzchar(bed_hhmm[k])) {
      b <- hm_split(bed_hhmm[k])
      if (!is.na(b[1])) {
        if (use_pm && b[1] < 12) {
          # PM-side night: bed clock-time + 12h, previous day
          out_bed[k] <- sprintf("%s %02d:%02d", prev_dstr, b[1] + 12, b[2])
        } else if (use_pm) {
          out_bed[k] <- sprintf("%s %02d:%02d", prev_dstr, b[1], b[2])
        } else if (b[1] >= 12) {
          # AM-side night but bed clock-time stored on the PM side of the
          # dial (e.g. bed "12:59 l/PM" with sleep "01:15" AM): read the bed
          # clock-time as the SAME night's early AM (00:59), on the same
          # calendar date as sleep -- never shift the bed to a different day.
          out_bed[k] <- sprintf("%s %02d:%02d", dstr, b[1] - 12, b[2])
        } else if (b[1] >= 11) {
          # bed "11:30 l/PM" with an early-morning sleep (00:10): the PM
          # label makes this 23:30 the previous night. Clock 11-12 + AM-side
          # sleep -> previous-day 23:xx (bed + 12h).
          out_bed[k] <- sprintf("%s %02d:%02d", prev_dstr, b[1] + 12, b[2])
        } else {
          out_bed[k] <- sprintf("%s %02d:%02d", dstr, b[1], b[2])
        }
      }
    }
  }
  list(bed = out_bed, sleep = out_sleep)
}

ft_from_date <- substr(merged$from_time, 1, 10)
bs <- bed_sleep_corrected(merged$time_bed_am_hhmm_orig, merged$time_sleep_am_hhmm_orig,
                          merged$time_awake_am_hhmm_ampm, ft_from_date)
merged$Time_Bed_Corrected <- bs$bed
merged$Time_Sleep_Corrected <- bs$sleep
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

