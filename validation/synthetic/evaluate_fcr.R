# evaluate_fcr.R
#
# False-alteration-rate (FCR test A / structurally-pure) evaluator.
# Compares raw input against the pipeline's OWN parsed-truth columns
# (_mincalc for durations, the reconstructed hour:minute for corrected
# timestamps) rather than raw display strings -- process_interval.R always
# rewrites the raw duration column into a canonical "HH:MM" string
# regardless of whether a correction fired (see its own docstring: "the
# original {varname} column is also replaced with the cleaned-up version of
# the interval strings"), so a raw-string diff conflates reformatting with
# correction. FAR_alter is about the latter only.
#
# Usage: Rscript evaluate_fcr.R <raw_rds> <corrected_rds> <out_csv>

args <- commandArgs(trailingOnly = TRUE)
raw       <- readRDS(args[1])
corrected <- readRDS(args[2])
out_csv   <- args[3]

m <- merge(
  raw[, c("pid", "day_num", "row_id",
          "time_bed_am_hhmm", "time_bed_am_ampm",
          "time_sleep_am_hhmm", "time_sleep_am_ampm",
          "time_awake_am_hhmm", "time_awake_am_ampm",
          "time_getup_am_hhmm", "time_getup_am_ampm",
          "duration_totalmin_sol_estimate_am",
          "duration_totalmin_waso_estimate_am")],
  corrected[, c("pid", "day_num", "row_id",
                "time_bed_corrected", "time_sleep_corrected",
                "time_awake_corrected", "time_getup_corrected",
                "duration_totalmin_sol_estimate_am_mincalc",
                "duration_totalmin_waso_estimate_am_mincalc")],
  by = c("pid", "day_num", "row_id")
)

to24 <- function(hhmm, ampm) {
  parts <- strsplit(hhmm, ":")
  h  <- as.integer(sapply(parts, `[`, 1))
  mn <- as.integer(sapply(parts, `[`, 2))
  h24 <- ifelse(ampm == "PM" & h != 12, h + 12, ifelse(ampm == "AM" & h == 12, 0, h))
  sprintf("%02d:%02d", h24, mn)
}

alt_bed   <- to24(m$time_bed_am_hhmm,   m$time_bed_am_ampm)   != format(as.POSIXct(m$time_bed_corrected),   "%H:%M")
alt_sleep <- to24(m$time_sleep_am_hhmm, m$time_sleep_am_ampm) != format(as.POSIXct(m$time_sleep_corrected), "%H:%M")
alt_awake <- to24(m$time_awake_am_hhmm, m$time_awake_am_ampm) != format(as.POSIXct(m$time_awake_corrected), "%H:%M")
alt_getup <- to24(m$time_getup_am_hhmm, m$time_getup_am_ampm) != format(as.POSIXct(m$time_getup_corrected), "%H:%M")
alt_sol   <- m$duration_totalmin_sol_estimate_am  != m$duration_totalmin_sol_estimate_am_mincalc
alt_waso  <- m$duration_totalmin_waso_estimate_am != m$duration_totalmin_waso_estimate_am_mincalc

alt_any <- alt_bed | alt_sleep | alt_awake | alt_getup | alt_sol | alt_waso
alt_any[is.na(alt_any)] <- TRUE  # any comparison that couldn't resolve counts as altered, fail-closed

n <- nrow(m)
k <- sum(alt_any, na.rm = TRUE)
upper95 <- if (k == 0) 3 / n else NA  # rule-of-three; only valid for k==0

summary_df <- data.frame(
  field = c("time_bed", "time_sleep", "time_awake", "time_getup",
            "duration_sol", "duration_waso", "ANY_FIELD"),
  n_altered = c(sum(alt_bed, na.rm=TRUE), sum(alt_sleep, na.rm=TRUE),
                sum(alt_awake, na.rm=TRUE), sum(alt_getup, na.rm=TRUE),
                sum(alt_sol, na.rm=TRUE), sum(alt_waso, na.rm=TRUE), k),
  n_total = n
)
write.csv(summary_df, out_csv, row.names = FALSE)

cat(sprintf("\n=== FCR (false-alteration-rate) result ===\nn=%d structurally-pure records\nrecords with >=1 field altered: %d\n", n, k))
if (k == 0) {
  cat(sprintf("FAR_alter = 0/%d. Rule-of-three 95%% upper bound = %.4f%% (%.5f)\n", n, upper95*100, upper95))
} else {
  cat(sprintf("FAR_alter = %d/%d = %.4f%%\n", k, n, 100*k/n))
}
print(summary_df)
