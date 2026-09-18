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
extract_time <- function(posix_col) {
  format(posix_col, "%Y-%m-%d %H:%M")
}

merged$Time_Bed_Corrected <- extract_time(merged$time_bed_am_hhmm_ampm)
merged$Time_Sleep_Corrected <- extract_time(merged$time_sleep_am_hhmm_ampm)
merged$Time_Awake_Corrected <- extract_time(merged$time_awake_am_hhmm_ampm)
merged$Time_Getup_Corrected <- extract_time(merged$time_getup_am_hhmm_ampm)

cat("Extracted corrected times\n")

# ===== MAP ORIGINAL TIMES =====
# Extract all 4 Original times from raw data (show all, not just gap-involved ones)
# Use the SAVED original _hhmm columns (before process_timestamp overwrote them)

date_str <- substr(merged$from_time, 1, 10)

merged$Time_Bed_Original <- paste0(date_str, " ", merged$time_bed_am_hhmm_orig)
merged$Time_Sleep_Original <- paste0(date_str, " ", merged$time_sleep_am_hhmm_orig)
merged$Time_Awake_Original <- paste0(date_str, " ", merged$time_awake_am_hhmm_orig)
merged$Time_Getup_Original <- paste0(date_str, " ", merged$time_getup_am_hhmm_orig)

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
colnames(user_output) <- c("#", "PID", "Day", "Gap_Type",
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
cat("User columns: #, PID, Day, Gap_Type, 8 time cols, 5 SOL cols, 2 review cols\n")

