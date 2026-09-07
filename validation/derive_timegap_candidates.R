#!/usr/bin/env Rscript
# =============================================================================
# derive_timegap_candidates.R
#
# PURPOSE
#   Produce ONE canonical, reproducible candidate list of diary rows whose
#   raw (pre-correction) bed/sleep/awake/getup timestamps are internally
#   inconsistent in a specific, bounded way: a same-day negative gap between
#   two adjacent sleep-diary events, with magnitude 3-6 hours. This pattern
#   is the signature of an AM/PM-dialect misread or a field-swap, not of a
#   normal overnight sleep period (which the pipeline's own date-rollover
#   logic in process_timestamp() already resolves to a positive, multi-hour
#   duration -- see the ">15:00 -> subtract one day" step below).
#
#   This script exists because a "590-row" figure circulated across several
#   sessions/agents without a traceable derivation, and no independent
#   re-run has ever reproduced it. A separate naive re-derivation (raw
#   hour-of-day subtraction, no date anchoring) gave 126/2036 depending on
#   assumed AM/PM mapping -- also not trustworthy, because it skips the
#   date-rollover step process_timestamp() already does for bed/sleep.
#
#   VERIFIED 2026-09-02: running THIS script (real process_timestamp(),
#   executed in R, not simulated) against sber_ema_anon_20260227.csv
#   reproduces gap_sleep_awake=39, gap_awake_getup=6, gap_bed_sleep=1,
#   total=46 -- matching a "46-row" figure that had independently appeared
#   in another session's output without its own derivation being available
#   to check. That match is now backed by a reproducible script, so 46 is
#   the locked count. 590 is confirmed fabricated. Do not cite 126, 134,
#   2036, or 590 anywhere downstream -- cite this script's output only.
#
# LOCKED DECISIONS (do not silently change; if you need a different
# definition, add a new script / new version, don't edit these silently)
#   1. AM/PM mapping for the bed/sleep dialect codes ("l"/"C"): reused
#      verbatim from R/timestamp_parse.R's already-shipped, already-verified
#      decode ("C" -> AM, "l" -> PM; verified against the archived
#      pre-processed export, exact count match). NOT re-derived here.
#   2. Gap definition: POSIXct difference in hours between the two events'
#      already date-anchored timestamps (process_timestamp() shifts
#      bed/sleep clock-times after 15:00 back one calendar day). This is
#      NOT a naive "hour of day" subtraction with an ad hoc "+24 if
#      negative" patch -- that patch is mathematically incapable of ever
#      producing a negative result and was the source of one earlier
#      wrong "0 rows" run.
#   3. Data: raw PRE-correction values only (sber_ema_anon_20260227.csv
#      as exported, before any manual_sleep_metric_duration_corrections.csv
#      rows are applied).
#   4. Threshold: negative gap, 3 <= |gap_hours| <= 6.
#   5. Field pairs, each tested independently, unioned (a row can appear
#      once per pair it triggers on, never collapsed into one flag):
#        gap_bed_sleep   = time_sleep_am - time_bed_am
#        gap_sleep_awake = time_awake_am - time_sleep_am
#        gap_awake_getup = time_getup_am - time_awake_am
#
# OUTPUT
#   - candidates: one row per (pid, day_num, raw_row_id, field_pair) that
#     triggers the rule, with both raw inputs and computed gap for audit.
#   - summary: per-field-pair and total counts, printed and saved.
#
# PRIVACY: the candidate CSV carries real pid/day_num and timestamps. Keep
# it out of git, same as the 188-row audit ledger. Only this script (the
# logic) is meant to be committed.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(rlang)
})

args <- commandArgs(trailingOnly = TRUE)
raw_path <- if (length(args) >= 1) args[[1]] else "sber_ema_anon_20260227.csv"
out_dir  <- if (length(args) >= 2) args[[2]] else "."

script_dir <- if (length(args) >= 3) args[[3]] else "R"
source(file.path(script_dir, "timestamp_parse.R"))  # brings in process_timestamp()

stopifnot(file.exists(raw_path))
raw <- read.csv(raw_path, stringsAsFactors = FALSE, check.names = FALSE)
raw$raw_row_id <- seq_len(nrow(raw))

vars <- c("time_bed_am", "time_sleep_am", "time_awake_am", "time_getup_am")
for (v in vars) {
  stopifnot(paste0(v, "_hhmm") %in% names(raw), paste0(v, "_ampm") %in% names(raw))
}

d <- raw
for (v in vars) {
  d <- process_timestamp(d, v, "timestamp")
}

gap_hours <- function(df, from_var, to_var) {
  t1 <- df[[paste0(from_var, "_hhmm_ampm")]]
  t2 <- df[[paste0(to_var, "_hhmm_ampm")]]
  as.numeric(difftime(t2, t1, units = "hours"))
}

d$gap_bed_sleep   <- gap_hours(d, "time_bed_am",   "time_sleep_am")
d$gap_sleep_awake <- gap_hours(d, "time_sleep_am", "time_awake_am")
d$gap_awake_getup <- gap_hours(d, "time_awake_am", "time_getup_am")

pairs <- list(
  gap_bed_sleep   = c("time_bed_am_hhmm_ampm",   "time_sleep_am_hhmm_ampm"),
  gap_sleep_awake = c("time_sleep_am_hhmm_ampm", "time_awake_am_hhmm_ampm"),
  gap_awake_getup = c("time_awake_am_hhmm_ampm", "time_getup_am_hhmm_ampm")
)

flag_one <- function(df, gap_col, from_col, to_col, pair_name) {
  gap <- df[[gap_col]]
  hit <- !is.na(gap) & gap < 0 & abs(gap) >= 3 & abs(gap) <= 6
  if (!any(hit)) {
    return(df[0, c("pid", "day_num", "raw_row_id"), drop = FALSE] %>%
             mutate(field_pair = character(0), from_time = character(0),
                    to_time = character(0), gap_hours = numeric(0)))
  }
  data.frame(
    pid        = df$pid[hit],
    day_num    = df$day_num[hit],
    raw_row_id = df$raw_row_id[hit],
    field_pair = pair_name,
    from_time  = as.character(df[[from_col]][hit]),
    to_time    = as.character(df[[to_col]][hit]),
    gap_hours  = round(gap[hit], 3),
    stringsAsFactors = FALSE
  )
}

candidates <- do.call(rbind, list(
  flag_one(d, "gap_bed_sleep",   pairs$gap_bed_sleep[1],   pairs$gap_bed_sleep[2],   "gap_bed_sleep"),
  flag_one(d, "gap_sleep_awake", pairs$gap_sleep_awake[1], pairs$gap_sleep_awake[2], "gap_sleep_awake"),
  flag_one(d, "gap_awake_getup", pairs$gap_awake_getup[1], pairs$gap_awake_getup[2], "gap_awake_getup")
))

summary_counts <- candidates %>%
  count(field_pair, name = "n_rows") %>%
  arrange(desc(n_rows))

cat("=== derive_timegap_candidates.R: field-pair candidate counts (3-6h negative, PRE-correction) ===\n")
print(summary_counts)
cat("TOTAL candidate rows (union across pairs, a row can appear more than once if it triggers >1 pair):",
    nrow(candidates), "\n")
cat("DISTINCT pid+day_num affected:", nrow(unique(candidates[, c("pid","day_num")])), "\n")

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
write.csv(candidates, file.path(out_dir, "timegap_candidates_3to6h.csv"), row.names = FALSE)
write.csv(summary_counts, file.path(out_dir, "timegap_candidates_summary.csv"), row.names = FALSE)
cat("Written to:", out_dir, "\n")
