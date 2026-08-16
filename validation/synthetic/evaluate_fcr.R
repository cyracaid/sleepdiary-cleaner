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
# Self-contained mode (default): generates a pure n=10,000 set via
# generate_clean_data.R (--mode=pure, seed 20260812), runs the real pipeline
# via run_one.R, then evaluates. Output CSV records input sha256 + seed so the
# result is traceable and re-runnable. Previously the pure input rds was
# generated ad hoc and lost (results CSV existed with no input) -- issue: FCR
# not reproducible. This script now owns the whole chain.
#
# Usage:
#   Rscript evaluate_fcr.R                          # self-contained (default)
#   Rscript evaluate_fcr.R <raw_rds> <corrected_rds> <out_csv>  # legacy
# Args: --n=10000 --seed=20260812 --out=results/fcr_pure_n10000_result.csv

suppressPackageStartupMessages(library(digest))
SYN <- "validation/synthetic"
RES <- file.path(SYN, "results")

args <- commandArgs(trailingOnly = TRUE)
n_help <- grep("^--n=", args, value = TRUE)
seed_help <- grep("^--seed=", args, value = TRUE)
out_help <- grep("^--out=", args, value = TRUE)
n_sel   <- if (length(n_help))   as.integer(sub("--n=", "", n_help[1]))   else 10000
seed    <- if (length(seed_help)) as.integer(sub("--seed=", "", seed_help[1])) else 20260812
out_csv <- if (length(out_help)) sub("--out=", "", out_help[1]) else
             file.path(RES, "fcr_pure_n10000_result.csv")

# -- Self-contained chain: generate pure set -> run pipeline -> evaluate ------
pure_rds <- file.path(tempdir(), sprintf("fcr_clean_pure_n%d.rds", n_sel))
run_dir  <- file.path(tempdir(), "fcr_run")
cat(sprintf("Generating pure set n=%d seed=%d...\n", n_sel, seed))
system2("Rscript", c(file.path(SYN, "generate_clean_data.R"),
  sprintf("--n_participants=%d", n_sel %/% 14),
  "--n_days=14", "--mode=pure", "--population=healthy_adult",
  sprintf("--seed=%d", seed), sprintf("--out=%s", pure_rds)),
  stdout = TRUE, stderr = TRUE, wait = TRUE)
stopifnot(file.exists(pure_rds))

cat("Running pipeline on pure set...\n")
system2("Rscript", c(file.path(SYN, "run_one.R"), pure_rds, run_dir, "fcr_pure"),
  stdout = TRUE, stderr = TRUE, wait = TRUE)
corrected_rds <- file.path(run_dir, "corrected_ema_data.rds")
stopifnot(file.exists(corrected_rds))

raw       <- readRDS(pure_rds)
corrected <- readRDS(corrected_rds)

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
attr(summary_df, "input_sha256") <- digest::digest(file = pure_rds, algo = "sha256")
attr(summary_df, "seed") <- seed
out_df <- summary_df
out_df$input_sha256 <- attr(summary_df, "input_sha256")
out_df$seed <- seed
write.csv(out_df, out_csv, row.names = FALSE)
cat(sprintf("  input_sha256: %s\n", out_df$input_sha256[1]))
cat(sprintf("  seed: %d\n", seed))

cat(sprintf("\n=== FCR (false-alteration-rate) result ===\nn=%d structurally-pure records\nrecords with >=1 field altered: %d\n", n, k))
if (k == 0) {
  cat(sprintf("FAR_alter = 0/%d. Rule-of-three 95%% upper bound = %.4f%% (%.5f)\n", n, upper95*100, upper95))
} else {
  cat(sprintf("FAR_alter = %d/%d = %.4f%%\n", k, n, 100*k/n))
}
print(summary_df)
