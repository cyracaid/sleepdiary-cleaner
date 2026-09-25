#!/usr/bin/env Rscript
# =============================================================================
# validation/rebuild_fasttrack_complete.R
#
# PURPOSE
#   Turn disambiguate_timegap_candidates.R's fast-track worksheet into the two
#   review deliverables:
#     - manual_disambiguation_fasttrack.csv (internal, complete time columns)
#     - fasttrack_review.csv               (user-facing review sheet)
#
# ZERO-JOIN DESIGN (2026-09-18)
#   This script performs NO join and reads NO raw data. Every time value it
#   needs is already decoded in the disambiguate worksheet:
#     from_time                    = sleep  decoded POSIX (Y-m-d H:M:S)
#     to_time                      = awake  decoded POSIX
#     time_bed_am_hhmm_ampm        = bed    decoded POSIX
#     time_getup_am_hhmm_ampm      = getup  decoded POSIX
#   The previous version joined sber_ema_anon_20260227.csv by raw_row_id to
#   "fill in" sleep/awake, on the mistaken assumption that the worksheet only
#   carried bed+getup. That assumption was false -- sleep/awake were already
#   present as from_time/to_time -- and the join introduced an entire bug
#   class: base merge() reorders rows (cross-participant time mismatch), adds
#   .x/.y column suffixes (Time_Sleep_Original.1/.2/... pollution), and pins
#   correctness to the sber file's row order staying byte-identical (it did
#   not; raw_row_id 7189 etc. drifted). Removing the join removes all of it.
#
# INPUT
#   - disambiguation_worksheet_tiered_fasttrack.csv (or any fasttrack frame
#     carrying from_time / to_time / time_bed_am_hhmm_ampm /
#     time_getup_am_hhmm_ampm)
#
# OUTPUT
#   - manual_disambiguation_fasttrack.csv (overwrite with complete time cols)
#   - fasttrack_review.csv (user-facing review sheet)
#
# PROCESS
#   1. Read the worksheet (input path configurable)
#   2. Extract the 4 decoded times straight from its columns (no join)
#   3. Build internal output (all worksheet columns + clean Time_* columns)
#   4. Build user-facing sheet with review columns
#   5. Write both CSVs with provenance sidecars
# =============================================================================

suppressPackageStartupMessages({
  library(stringr)
})

source("validation/provenance_helpers.R")

# ===== INPUT =====
args          <- commandArgs(trailingOnly = TRUE)
input_path    <- if (length(args) >= 1) args[[1]] else "disambiguation_worksheet_tiered_fasttrack.csv"
raw_path      <- if (length(args) >= 2) args[[2]] else "sber_ema_anon_20260227.csv"
output_internal <- "manual_disambiguation_fasttrack.csv"
output_user   <- "fasttrack_review.csv"

stopifnot(file.exists(input_path))
stopifnot(file.exists(raw_path))

fasttrack <- read.csv(input_path, stringsAsFactors = FALSE, check.names = FALSE)
raw       <- read.csv(raw_path, stringsAsFactors = FALSE, check.names = FALSE)
raw$raw_row_id <- seq_len(nrow(raw))
cat("Loaded:", nrow(fasttrack), "rows from", input_path, "\n")

# ===== PULL THE RAW ORIGINAL ENTRIES (match-index, not join) ================
# The reviewer wants to SEE what the participant actually typed, in the raw
# study dialect (hh:mm + C/l/AM/PM), not just the decoded POSIX. Index the
# sber rows by position with match() -- this never reorders (unlike merge)
# and never adds .x/.y suffixes. Rows without a raw match stay NA.
idx <- match(fasttrack$raw_row_id, raw$raw_row_id)

raw_orig <- function(hhmm_col, ampm_col) {
  h <- raw[[hhmm_col]][idx]
  a <- raw[[ampm_col]][idx]
  d <- substr(raw$date_of_obs[idx], 1, 10)   # observation date = the day the participant recorded this
  out <- rep(NA_character_, length(h))
  ok <- !is.na(h) & nzchar(as.character(h))
  out[ok] <- paste0(d[ok], " ", h[ok], " ", a[ok])
  out
}

fasttrack$Raw_Bed    <- raw_orig("time_bed_am_hhmm",    "time_bed_am_ampm")
fasttrack$Raw_Sleep  <- raw_orig("time_sleep_am_hhmm",  "time_sleep_am_ampm")
fasttrack$Raw_Awake  <- raw_orig("time_awake_am_hhmm",  "time_awake_am_ampm")
fasttrack$Raw_Getup  <- raw_orig("time_getup_am_hhmm",  "time_getup_am_ampm")
cat("Pulled raw original entries (e.g. '2022-01-13 01:15 l') for all rows.\n")

# ===== EXTRACT THE 4 DECODED TIMES (zero join) ==============================
# All four are already decoded POSIX-ish strings in the worksheet. Normalise
# to "YYYY-MM-DD HH:MM" (drop seconds). from_time/to_time are the flagged
# pair (gap_sleep_awake => sleep/awake); bed/getup are their own columns.
need <- c("from_time", "to_time", "time_bed_am_hhmm_ampm", "time_getup_am_hhmm_ampm")
missing <- setdiff(need, names(fasttrack))
if (length(missing) > 0) {
  stop("Worksheet is missing decoded-time columns: ", paste(missing, collapse = ", "))
}

extract_time <- function(x) {
  out <- rep(NA_character_, length(x))
  ok  <- !is.na(x) & nzchar(as.character(x))
  out[ok] <- substr(format(as.POSIXct(as.character(x[ok]), tz = "America/Los_Angeles"), "%Y-%m-%d %H:%M"), 1, 16)
  out
}

# Original = the RAW entry the participant typed (dialect preserved).
# Corrected = the PIPELINE's actual corrected value from the final data
#             (cleaned_data_full.rds), matched by raw_row_id. This is what
#             normalize_sleep_time_sequence actually produced (AM/PM flip),
#             NOT the literal PM decode of from_time. (Previous versions
#             showed the literal decode here, which contradicted the actual
#             fix and confused review: e.g. sleep "01:20 l" showed as 13:20
#             "corrected" while the pipeline had already fixed it to 01:20.)
fasttrack$Time_Bed_Original   <- fasttrack$Raw_Bed
fasttrack$Time_Sleep_Original <- fasttrack$Raw_Sleep
fasttrack$Time_Awake_Original <- fasttrack$Raw_Awake
fasttrack$Time_Getup_Original <- fasttrack$Raw_Getup

# Pull pipeline-corrected times from the final dataset when available.
# TRACKABILITY (2026-09-25): cleaned_data_full.rds is a PIPELINE RUN ARTIFACT,
# not source data. Its corrected values are produced by
# R/normalize_sequence.R's normalize_sleep_time_sequence() (12h AM/PM flip,
# flip_gap_hours=12, swap_threshold=3h). If the pipeline is re-run, this file
# is regenerated; if the normalize RULES change, the corrected values change
# with them. We record the artifact's md5 + mtime + the R-code fingerprint in
# the provenance sidecar so a reviewer can see EXACTLY which pipeline run (and
# which normalize code version) produced the Corrected columns -- otherwise a
# stale file would silently feed wrong corrections into the review sheet.
pipeline_corr_path <- "output/cleaned_data_full.rds"
pipeline_corr_meta <- list(used = FALSE, path = NA_character_, md5 = NA_character_,
                           mtime = NA_character_, normalize_code_md5 = NA_character_)
if (file.exists(pipeline_corr_path)) {
  full <- readRDS(pipeline_corr_path)
  full$key <- paste(full$pid, full$day_num)
  ft_key <- paste(fasttrack$pid, fasttrack$day_num)
  match_idx <- match(ft_key, full$key)
  get_corr <- function(col) {
    vals <- full[[col]][match_idx]
    out <- rep(NA_character_, length(vals))
    ok <- !is.na(vals)
    out[ok] <- format(as.POSIXct(vals[ok], tz = "America/Los_Angeles"), "%Y-%m-%d %H:%M")
    out
  }
  fasttrack$Time_Bed_Corrected   <- get_corr("time_bed_corrected")
  fasttrack$Time_Sleep_Corrected <- get_corr("time_sleep_corrected")
  fasttrack$Time_Awake_Corrected <- get_corr("time_awake_corrected")
  fasttrack$Time_Getup_Corrected <- get_corr("time_getup_corrected")
  pipeline_corr_meta$used <- TRUE
  pipeline_corr_meta$path <- pipeline_corr_path
  pipeline_corr_meta$md5 <- unname(tools::md5sum(pipeline_corr_path))
  pipeline_corr_meta$mtime <- as.character(file.mtime(pipeline_corr_path))
  # fingerprint of the normalize rule code (the thing that PRODUCES these values)
  norm_code <- if (file.exists("R/normalize_sequence.R")) paste(readLines("R/normalize_sequence.R"), collapse = "\n") else ""
  pipeline_corr_meta$normalize_code_md5 <- unname(tools::md5sum("R/normalize_sequence.R"))
  cat("Corrected times pulled from pipeline final data (cleaned_data_full.rds).\n")
  cat(sprintf("  [track] %s md5=%s mtime=%s\n", pipeline_corr_path,
              substr(pipeline_corr_meta$md5, 1, 8), pipeline_corr_meta$mtime))
} else {
  # Fallback: literal decode (best available without pipeline output)
  fasttrack$Time_Bed_Corrected   <- extract_time(fasttrack$time_bed_am_hhmm_ampm)
  fasttrack$Time_Sleep_Corrected <- extract_time(fasttrack$from_time)
  fasttrack$Time_Awake_Corrected <- extract_time(fasttrack$to_time)
  fasttrack$Time_Getup_Corrected <- extract_time(fasttrack$time_getup_am_hhmm_ampm)
  cat("WARNING: cleaned_data_full.rds not found; Corrected = literal decode.\n")
}

# ===== BUILD OUTPUT (INTERNAL) =====
# Drop any stale Time_*_Original / Time_*_Corrected columns the input may have
# accumulated from older rebuild runs (would otherwise duplicate/rename).
internal_output <- fasttrack[, !grepl("^Time_(Bed|Sleep|Awake|Getup)_(Original|Corrected)", names(fasttrack)), drop = FALSE]
internal_output <- cbind(
  internal_output,
  Time_Bed_Original   = fasttrack$Time_Bed_Original,
  Time_Sleep_Original = fasttrack$Time_Sleep_Original,
  Time_Awake_Original = fasttrack$Time_Awake_Original,
  Time_Getup_Original = fasttrack$Time_Getup_Original,
  Time_Bed_Corrected  = fasttrack$Time_Bed_Corrected,
  Time_Sleep_Corrected = fasttrack$Time_Sleep_Corrected,
  Time_Awake_Corrected = fasttrack$Time_Awake_Corrected,
  Time_Getup_Corrected = fasttrack$Time_Getup_Corrected
)
cat("Internal output:", nrow(internal_output), "rows\n")

# ===== BUILD OUTPUT (USER-FACING) =====
user_output <- data.frame(
  "#"            = seq_len(nrow(fasttrack)),
  PID            = fasttrack$pid,
  Day            = fasttrack$day_num,
  Gap_Type       = fasttrack$field_pair,
  Row_ID         = fasttrack$raw_row_id,
  Raw_Bed        = fasttrack$Raw_Bed,
  Raw_Sleep      = fasttrack$Raw_Sleep,
  Raw_Awake      = fasttrack$Raw_Awake,
  Raw_Getup      = fasttrack$Raw_Getup,
  Time_Bed_Original   = fasttrack$Time_Bed_Original,
  Time_Sleep_Original = fasttrack$Time_Sleep_Original,
  Time_Awake_Original = fasttrack$Time_Awake_Original,
  Time_Getup_Original = fasttrack$Time_Getup_Original,
  Time_Bed_Corrected  = fasttrack$Time_Bed_Corrected,
  Time_Sleep_Corrected = fasttrack$Time_Sleep_Corrected,
  Time_Awake_Corrected = fasttrack$Time_Awake_Corrected,
  Time_Getup_Corrected = fasttrack$Time_Getup_Corrected,
  SOL_SelfReport_min = fasttrack$sol_selfreport_min,
  SOL_Calculated_min = fasttrack$sol_crosscheck_calc_min,
  SOL_Diff_min      = fasttrack$sol_crosscheck_diff_min,
  SOL_Match         = ifelse(fasttrack$sol_crosscheck_fit == "good", "\u2713 Yes", "\u2717 No"),
  Confidence_Pct    = fasttrack$posterior_p_error_combined,
  Accept            = "",
  Notes             = "",
  check.names       = FALSE,
  stringsAsFactors  = FALSE
)

# Format numeric columns
user_output$SOL_SelfReport_min <- round(as.numeric(user_output$SOL_SelfReport_min), 0)
user_output$SOL_Calculated_min <- round(as.numeric(user_output$SOL_Calculated_min), 0)
user_output$SOL_Diff_min       <- round(as.numeric(user_output$SOL_Diff_min), 0)
user_output$Confidence_Pct     <- round(as.numeric(user_output$Confidence_Pct), 1)

# Replace NAs with empty strings for cleaner output
user_output[is.na(user_output)] <- ""

# ===== WRITE OUTPUTS =====
# output_internal may already exist with reviewer judgments/notes. Snapshot
# the pre-overwrite version first so a bad run is recoverable.
if (file.exists(output_internal)) {
  dir.create("validation/_snapshots", showWarnings = FALSE, recursive = TRUE)
  snapshot_path <- sprintf(
    "validation/_snapshots/%s_%s.csv",
    tools::file_path_sans_ext(basename(output_internal)),
    format(Sys.time(), "%Y%m%d_%H%M%S")
  )
  file.copy(output_internal, snapshot_path, overwrite = TRUE)
  cat("Snapshotted pre-overwrite version to:", snapshot_path, "\n")
}

track_note <- if (isTRUE(pipeline_corr_meta$used)) {
  sprintf("Corrected columns sourced from PIPELINE RUN ARTIFACT %s (md5=%s, mtime=%s); normalize rule code md5=%s. Re-run pipeline if normalize rules change -- stale artifact would feed wrong corrections.",
          pipeline_corr_meta$path, pipeline_corr_meta$md5,
          pipeline_corr_meta$mtime, pipeline_corr_meta$normalize_code_md5)
} else {
  "WARNING: cleaned_data_full.rds not found; Corrected = literal decode (not pipeline output)."
}

write_csv_with_provenance(
  internal_output, output_internal,
  script_path = "validation/rebuild_fasttrack_complete.R",
  inputs = input_path,
  notes = paste0(
    "Zero-join rebuild: Original = raw entries, Corrected = ",
    if (isTRUE(pipeline_corr_meta$used)) "pipeline actual values." else "literal decode (pipeline missing). ",
    track_note
  ),
  quote = TRUE
)
cat("\u2713 Wrote:", output_internal, "\n")

write_csv_with_provenance(
  user_output, output_user,
  script_path = "validation/rebuild_fasttrack_complete.R",
  inputs = input_path,
  notes = paste0(
    "User-facing review sheet derived from the same run as manual_disambiguation_fasttrack.csv. ",
    track_note
  ),
  quote = TRUE
)
cat("\u2713 Wrote:", output_user, "\n")

# ===== SUMMARY =====
cat("\n=== SUMMARY ===\n")
cat("Fasttrack records: ", nrow(user_output), "\n")
cat("Times shown: ALL 4 (bed, sleep, awake, getup) x (original + corrected)\n")
cat("Format: YYYY-MM-DD HH:MM (each cell, no blanks)\n")
cat("User columns: #, PID, Day, Gap_Type, Row_ID, 8 time cols, 5 SOL cols, 2 review cols\n")