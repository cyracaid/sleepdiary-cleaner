# sweep_thresholds.R -- how a threshold behaves on a given distribution of nights
#
# Purpose: the study's threshold defaults were set on healthy young adults
# (THRESHOLDS.md). Before this pipeline is used on another population, someone
# has to know how far those defaults travel. This script answers one question
# at a time: **at threshold T, what share of these nights would be flagged?**
#
# It does NOT re-run the pipeline and it does NOT claim a clinical result. It
# takes a vector of nightly values and reports flag rates across thresholds, so
# that a distribution (the study's own, or one built from published parameters)
# can be compared against the rule the pipeline uses.
#
# Usage (from the repository root):
#   Rscript validation/cross_protocol/sweep_thresholds.R \
#       [--data=output/cleaned_data_full.rds] [--metric=sol] [--out=validation/cross_protocol/results]
#
# Metric choices: sol (minutes), tst (minutes), se (percent, flagged below).
# With no --data it stops: there is no built-in sample, because a made-up
# distribution would make the output look like a finding.

args <- commandArgs(trailingOnly = TRUE)
opt <- list(data = "output/cleaned_data_full.rds", metric = "sol", direction = "",
            out = file.path("validation", "cross_protocol", "results"))
for (a in args) {
  kv <- strsplit(sub("^--", "", a), "=")[[1]]
  if (kv[1] %in% names(opt)) opt[[kv[1]]] <- kv[2]
}

metric_col <- c(sol = "self_diffcalc_sol_minutes",
                tst = "self_diffcalc_totalsleeptime_minutes",
                se  = "self_diffcalc_sleepefficiency_percent")
if (!opt$metric %in% names(metric_col)) {
  stop("--metric must be one of: ", paste(names(metric_col), collapse = ", "), call. = FALSE)
}
if (!file.exists(opt$data)) {
  stop("No ", opt$data, ". Pass --data=<rds with the delivered columns>. ", call. = FALSE)
}

d <- readRDS(opt$data)
col <- metric_col[[opt$metric]]
if (!col %in% names(d)) stop("Column ", col, " not in the data.", call. = FALSE)
v <- d[[col]]; v <- v[!is.na(v)]
if (!length(v)) stop("No non-missing values for ", col, call. = FALSE)
# the package stores efficiency as a fraction in some builds and as a percent in
# others; normalise to percent so the thresholds below mean what they say
if (opt$metric == "se" && max(v, na.rm = TRUE) <= 1) v <- v * 100

# The grid is the range the pipeline's own thresholds live in (THRESHOLDS.md):
# SOL excessive = 120, SOL high = 60, SE poor = 70. TST has no flag threshold
# but 300/600 min are the usual "short/long sleep" reference points.
grid <- switch(opt$metric,
  sol = c(30, 45, 60, 90, 120, 180),
  tst = c(240, 300, 360, 420, 480, 540, 600),
  se  = c(95, 90, 85, 80, 75, 70, 60, 50))

# which side is the flag: low efficiency is bad; SOL is bad when long; TST is bad
# when short (--direction=below) or long (--direction=above, the default)
direction <- if (nzchar(opt$direction)) opt$direction else if (opt$metric == "se") "below" else "above"
if (!direction %in% c("above", "below")) stop("--direction must be above or below", call. = FALSE)
flag_rate <- if (direction == "below") {
  vapply(grid, function(t) mean(v < t), numeric(1))
} else {
  vapply(grid, function(t) mean(v > t), numeric(1))
}

out <- data.frame(
  metric = opt$metric,
  direction = direction,
  threshold = grid,
  share_flagged = round(flag_rate, 4),
  n = length(v),
  data = opt$data,
  stringsAsFactors = FALSE)

dir.create(opt$out, showWarnings = FALSE, recursive = TRUE)
path <- file.path(opt$out, sprintf("sweep_%s.csv", opt$metric))
write.csv(out, path, row.names = FALSE)

cat(sprintf("%s, n = %d, median = %.1f, 10th-90th pct = %.1f-%.1f\n",
            col, length(v), median(v), quantile(v, .1), quantile(v, .9)))
cat(sprintf("%-10s %10s\n", "threshold", "flagged"))
for (i in seq_len(nrow(out))) cat(sprintf("%-10s %9.1f%%\n", out$threshold[i], 100 * out$share_flagged[i]))
cat("\nwrote", path, "\n")
cat("\nThis table describes the distribution you passed in. It is not a finding\n",
    "about another population until that population's values are supplied.\n", sep = "")
