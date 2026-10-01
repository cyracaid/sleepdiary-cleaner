# redundant_channel_check.R -- does a bed/sleep timestamp correction move the
# computed sleep-onset latency toward the participant's own self-reported SOL?
#
# The correction step never reads the self-reported duration, so the
# comparison is not circular: for each row whose bed->sleep gap was changed,
#   before = |raw gap - self-reported SOL|,  after = |corrected gap - self-reported SOL|
# and a row "improved" when after < before, "worsened" when after > before.
#
# Needs the study data (not public): run it in a project directory that holds
# output/corrected_ema_data.rds from a run_pipeline() run.
# Usage (from that directory):
#   Rscript /path/to/validation/redundant_channel_check.R [path/to/corrected_ema_data.rds]
#
# Same comparison as M5 in audit_review_queue_m1_m7.R and B2 in
# part_b_global_sweep.R, which list only the worsened rows; this script adds the
# counts, the medians, the interval and the paired test reported in the paper.

args <- commandArgs(trailingOnly = TRUE)
path <- if (length(args) >= 1) args[1] else file.path("output", "corrected_ema_data.rds")
x <- readRDS(path)

need <- c("time_bed_am_hhmm_ampm", "time_sleep_am_hhmm_ampm",
          "time_bed_corrected", "time_sleep_corrected",
          "duration_totalmin_sol_estimate_am_mincalc")
stopifnot(all(need %in% names(x)))

gap <- function(sleep, bed) as.numeric(difftime(sleep, bed, units = "mins"))
raw_gap <- gap(x$time_sleep_am_hhmm_ampm, x$time_bed_am_hhmm_ampm)
cor_gap <- gap(x$time_sleep_corrected,    x$time_bed_corrected)
self    <- as.numeric(x$duration_totalmin_sol_estimate_am_mincalc)

ok <- !is.na(raw_gap) & !is.na(cor_gap) & !is.na(self) & raw_gap != cor_gap
before <- abs(raw_gap[ok] - self[ok])
after  <- abs(cor_gap[ok] - self[ok])

report <- function(label, keep) {
  b <- before[keep]; a <- after[keep]; n <- length(b)
  if (n == 0) { cat(sprintf("%s: no rows\n", label)); return(invisible()) }
  improved <- sum(a < b); worsened <- sum(a > b); tied <- sum(a == b)
  ci <- binom.test(improved, n)$conf.int
  w <- suppressWarnings(wilcox.test(b, a, paired = TRUE))
  p <- if (is.na(w$p.value)) "NA" else if (w$p.value < 2.2e-16) "< 2.2e-16" else sprintf("%.2g", w$p.value)
  cat(sprintf("\n[%s] n = %d\n", label, n))
  cat(sprintf("  improved %d | worsened %d | unchanged distance %d\n", improved, worsened, tied))
  cat(sprintf("  median |gap - self| (min): before %.1f -> after %.1f\n", median(b), median(a)))
  cat(sprintf("  P(improved) = %.1f%%  [exact 95%% CI %.1f-%.1f%%]\n",
              100 * improved / n, 100 * ci[1], 100 * ci[2]))
  cat(sprintf("  Wilcoxon signed-rank (paired) p %s\n", p))
}

manual <- if ("manually_corrected" %in% names(x)) x$manually_corrected[ok] %in% TRUE else rep(NA, sum(ok))
cat("rows with a changed bed->sleep gap and a self-reported SOL\n")
report("all", rep(TRUE, sum(ok)))
if (!all(is.na(manual))) {
  report("algorithmic corrections only (not manually corrected)", !manual)
  report("manually corrected", manual)
}

# Same split as the August 2026 analysis: by the three correction types that
# touch the bed/sleep pair (rows of any origin, manual or not).
type_ <- x$correction_type[ok]
cat("\nBy correction type (the three types that touch the bed/sleep pair)\n")
for (ty in c("bed_sleep_swap_3h", "sleep_reduce_12h_loop", "sleep_awake_swap_3h")) {
  report(ty, type_ %in% ty)
}
report("all three types together", type_ %in% c("bed_sleep_swap_3h", "sleep_reduce_12h_loop", "sleep_awake_swap_3h"))
