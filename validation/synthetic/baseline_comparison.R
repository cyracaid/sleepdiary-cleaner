# baseline_comparison.R -- what the pipeline buys relative to what teams do instead
#
# Three ways of handling diary data are already in the repository:
#   no_cleaning  -- nothing is flagged or dropped (the floor)
#   naive_rule   -- flag a row if a value is structurally impossible (control_baselines.R)
#   pipeline     -- the package (control_baselines.csv)
#
# This script adds the fourth, which is the one most teams actually use:
#   exclusion_only -- drop the whole night whenever anything looks wrong.
# It also puts the two things reviewers ask for side by side: how much of the
# truth is handled, and how much clean data is lost doing it.
#
# Output: validation/synthetic/results/baseline_comparison.csv
# Usage (from the repository root): Rscript validation/synthetic/baseline_comparison.R

SYN <- "validation/synthetic"
RES <- file.path(SYN, "results")

gt  <- read.csv(file.path(SYN, "ground_truth_enrichment.csv"), stringsAsFactors = FALSE)
raw <- readRDS(file.path(SYN, "corrupted_enrichment.rds"))
base <- read.csv(file.path(RES, "control_baselines.csv"), stringsAsFactors = FALSE)
far  <- read.csv(file.path(RES, "far_flag_alter.csv"), stringsAsFactors = FALSE)
corr <- read.csv(file.path(RES, "correction_level_recall.csv"), stringsAsFactors = FALSE)

get1 <- function(df, key, col = "value") df[[col]][df[["metric"]] == key][1]
pipeline_correct_share <- get1(corr, "correction_recall_L3")
n_control <- far$n_control[far$metric == "FAR_flag"]

# ---- the exclusion-only rule ----------------------------------------------
# What a careful team with no cleaning software does: if any of these holds,
# throw the night away rather than repair it.
#   (a) any of the four times is missing;
#   (b) a time value is not a usable clock time (hour > 23, minute > 59);
#   (c) the four times cannot be read as one night in order;
#   (d) after reading them, the night is implausible: SOL > 120 min,
#       TST < 180 or > 720 min, time in bed > 960 min.
to24 <- function(hhmm, ampm) {
  h <- suppressWarnings(as.integer(sub(":.*$", "", hhmm)))
  m <- suppressWarnings(as.integer(sub("^.*:", "", hhmm)))
  ifelse(ampm == "PM" & h != 12, h + 12, ifelse(ampm == "AM" & h == 12, 0, h)) * 60 + m
}

ts <- c("time_bed_am", "time_sleep_am", "time_awake_am", "time_getup_am")
drop <- rep(FALSE, nrow(raw))
for (i in seq_len(nrow(raw))) {
  mins <- numeric(4); ok <- logical(4)
  for (k in seq_along(ts)) {
    hh <- raw[[paste0(ts[k], "_hhmm")]][i]; ap <- raw[[paste0(ts[k], "_ampm")]][i]
    if (is.na(hh) || is.na(ap) || !nzchar(hh) || !nzchar(ap) ||
        !grepl("^[0-9]{1,2}:[0-9]{2}$", hh)) { ok[k] <- FALSE; next }
    v <- to24(hh, ap)
    if (is.na(v)) { ok[k] <- FALSE; next }
    mins[k] <- v; ok[k] <- TRUE
  }
  if (!all(ok)) { drop[i] <- TRUE; next }                     # (a)/(b)
  h <- mins
  for (k in 2:4) if (h[k] < h[k - 1]) h[k] <- h[k] + 24        # midnight-aware
  if (any(diff(h) < 0)) { drop[i] <- TRUE; next }              # (c)
  sol <- h[2] - h[1]; tst <- h[3] - h[2]; tib <- h[4] - h[1]
  if (sol > 120 || tst < 180 || tst > 720 || tib > 960) drop[i] <- TRUE  # (d)
}

err_ids  <- gt$row_id[gt$error_type != "no_error_control"]
ctrl_ids <- gt$row_id[gt$error_type == "no_error_control"]
drop_err  <- drop[match(err_ids, raw$row_id)]
drop_ctrl <- drop[match(ctrl_ids, raw$row_id)]

cat("\n=== Exclusion-only (drop the whole night) ===\n")
cat(sprintf("  errors handled by dropping: %d/%d = %.4f\n",
            sum(drop_err), length(drop_err), mean(drop_err)))
cat(sprintf("  clean control nights dropped: %d/%d = %.4f\n",
            sum(drop_ctrl), length(drop_ctrl), mean(drop_ctrl)))

# ---- assemble the comparison ----------------------------------------------
pull <- function(cond, col) base[[col]][base$condition == cond][1]

out <- data.frame(
  condition           = c("no_cleaning", "naive_rule", "exclusion_only", "pipeline"),
  handled             = c(pull("no_cleaning", "recall"), pull("naive_rule", "recall"),
                          mean(drop_err), pull("pipeline", "recall")),
  corrected_to_truth  = c(0, 0, 0, pipeline_correct_share),
  clean_rows_lost     = c(0, 0, mean(drop_ctrl), pull("pipeline", "far_alter")),
  stringsAsFactors    = FALSE
)
out <- rbind(out, data.frame(
  condition = "note: denominators",
  handled = NA, corrected_to_truth = NA, clean_rows_lost = NA,
  stringsAsFactors = FALSE
))

write.csv(out[out$condition != "note: denominators", ],
          file.path(RES, "baseline_comparison.csv"), row.names = FALSE)

cat("\n=== Baseline comparison (same enrichment benchmark) ===\n")
cat(sprintf("%-14s %10s %18s %16s\n", "condition", "handled", "corrected_to_truth", "clean_rows_lost"))
for (k in seq_len(nrow(out) - 1)) {
  cat(sprintf("%-14s %10.4f %18.4f %16.4f\n", out$condition[k],
              out$handled[k], out$corrected_to_truth[k], out$clean_rows_lost[k]))
}
cat("\n  handled            = share of the injected errors that the condition deals with\n")
cat("  corrected_to_truth = share corrected to the pre-injection value (pipeline only;\n")
cat("                       the other conditions cannot correct, they flag or drop)\n")
cat("  clean_rows_lost    = share of the", n_control, "clean control rows flagged or dropped\n")
cat("\nWrote", file.path(RES, "baseline_comparison.csv"), "\n")
