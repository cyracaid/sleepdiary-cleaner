# prevalence_grid.R -- the benchmark over a small grid of error rates and error-type
# mixes, with the flags' precision and the review burden at each point.
#
# Grid: 4 overall error rates (2, 5, 10, 20% of the 7,000 rows) x 4 mixes:
#   equal       the same number of each of the 14 error types
#   anchored    each type in proportion to its real-world rate in the catalog
#               (rate_anchor_pct); window contradictions dominate, as they do in the
#               study data
#   timestamp   only errors in the bed/sleep/awake/get-up times
#   duration    only errors in the latency and wake-after-sleep-onset fields
# Each cell: generate the clean pool (seed 20260817), inject with a temporary catalog,
# run the installed sleepcleanr once, score with evaluate_detection.R. Reports, per cell,
# the share of injected errors flagged or corrected to the true value (exact 95%
# interval), the share corrected, flagged only and repaired wrongly, the precision of
# the flags, clean rows flagged or altered, and rows flagged per 1,000.
# Writes validation/synthetic/results/prevalence_grid.csv.
# Usage (from the repository root): Rscript validation/synthetic/prevalence_grid.R

suppressPackageStartupMessages({ library(yaml) })
SYN <- "validation/synthetic"; RES <- file.path(SYN, "results")
seed <- 20260817
rates <- c(0.02, 0.05, 0.10, 0.20)

tmp <- file.path(tempdir(), "grid"); dir.create(tmp, recursive = TRUE)
clean_rds <- file.path(tmp, "clean.rds")
system2("Rscript", c(file.path(SYN, "generate_clean_data.R"),
  "--n_participants=500", "--n_days=14", "--mode=plausible",
  "--population=healthy_adult", paste0("--seed=", seed), paste0("--out=", clean_rds)),
  stdout = TRUE, stderr = TRUE)
stopifnot(file.exists(clean_rds))
n_rows <- nrow(readRDS(clean_rds))

cat_txt <- readLines(file.path(SYN, "error_catalog.yaml"), encoding = "UTF-8")
catalog <- yaml::yaml.load(paste(cat_txt, collapse = "\n"))
types <- c("ampm_swap", "adjacent_swap_bed_sleep", "adjacent_swap_sleep_awake",
           "adjacent_swap_awake_getup", "field_misentry_sol", "field_misentry_waso",
           "format_no_colon", "format_malformed_colon", "mmss_confusion",
           "implausible_duration", "compound_ampm_and_swap",
           "adjacent_swap_large_gap_left_clean", "sol_window_contradiction",
           "cross_participant_spike")
timestamp_types <- c("ampm_swap", "adjacent_swap_bed_sleep", "adjacent_swap_sleep_awake",
                     "adjacent_swap_awake_getup", "compound_ampm_and_swap",
                     "adjacent_swap_large_gap_left_clean")
duration_types <- c("field_misentry_sol", "field_misentry_waso", "format_no_colon",
                    "format_malformed_colon", "mmss_confusion", "implausible_duration",
                    "sol_window_contradiction")
anchor <- vapply(types, function(t) {
  v <- catalog$categories[[t]]$rate_anchor_pct; if (is.null(v)) 0 else as.numeric(v)
}, numeric(1))
weights <- list(
  equal     = setNames(rep(1, length(types)), types),
  anchored  = anchor,
  timestamp = setNames(as.numeric(types %in% timestamp_types), types),
  duration  = setNames(as.numeric(types %in% duration_types), types)
)

# catalog copy with per-category targets inserted (a line after each category header)
with_targets <- function(targets) {
  out <- cat_txt
  for (t in names(targets)) {
    i <- grep(paste0("^  ", t, ":\\s*$"), out)
    stopifnot(length(i) == 1)
    out <- append(out, sprintf("    enrichment_target: %d", targets[[t]]), after = i)
  }
  out
}

rows <- list()
for (mix in names(weights)) for (rate in rates) {
  w <- weights[[mix]] / sum(weights[[mix]])
  targets <- as.list(round(rate * n_rows * w))
  names(targets) <- types
  cell <- file.path(tmp, sprintf("%s_%g", mix, rate)); dir.create(cell)
  cat_path <- file.path(cell, "catalog.yaml"); writeLines(with_targets(targets), cat_path, useBytes = TRUE)
  corr_rds <- file.path(cell, "corrupted.rds"); truth_csv <- file.path(cell, "truth.csv")
  system2("Rscript", c(file.path(SYN, "inject_errors.R"), paste0("--clean_rds=", clean_rds),
    paste0("--catalog=", cat_path), paste0("--out_data=", corr_rds),
    paste0("--out_truth=", truth_csv), paste0("--seed=", seed)), stdout = TRUE, stderr = TRUE)
  run_dir <- file.path(cell, "run")
  system2("Rscript", c(file.path(SYN, "run_one.R"), corr_rds, run_dir, "grid"), stdout = TRUE, stderr = TRUE)
  review <- readRDS(file.path(run_dir, "review_output.rds"))
  corrected <- readRDS(file.path(run_dir, "corrected_ema_data.rds"))
  gt <- read.csv(truth_csv, stringsAsFactors = FALSE)
  det_csv <- file.path(cell, "outcomes.csv")
  system2("Rscript", c(file.path(SYN, "evaluate_detection.R"), truth_csv, corr_rds,
    file.path(run_dir, "review_output.rds"), file.path(run_dir, "corrected_ema_data.rds"), det_csv),
    stdout = TRUE, stderr = TRUE)
  oc <- read.csv(det_csv, stringsAsFactors = FALSE); oc <- oc[oc$category != "no_error_control", ]
  d <- review$data_with_flags
  q <- d$needs_review_flag %in% TRUE
  for (cc in grep("_checkforerrors$", names(d), value = TRUE)) q <- q | (d[[cc]] %in% TRUE)
  flagged <- q[match(corrected$row_id, d$row_id)]; flagged[is.na(flagged)] <- FALSE
  altered <- corrected$corrected %in% TRUE
  inj <- corrected$row_id %in% unique(gt$row_id[gt$error_type != "no_error_control"])
  n_inj <- sum(oc$n); ok <- sum(oc$CORRECT) + sum(oc$FLAGGED_UNRESOLVED)
  ci <- if (n_inj > 0) binom.test(ok, n_inj)$conf.int else c(NA, NA)
  rows[[length(rows) + 1]] <- data.frame(
    mix = mix, target_rate = rate, injected_rows = n_inj, injected_share = round(n_inj / n_rows, 4),
    flagged_or_corrected = round(ok / n_inj, 4), ci_low = round(ci[1], 4), ci_high = round(ci[2], 4),
    corrected_to_true_value = round(sum(oc$CORRECT) / n_inj, 4),
    flagged_only = round(sum(oc$FLAGGED_UNRESOLVED) / n_inj, 4),
    repaired_wrongly = round(sum(oc$MISREPAIRED) / n_inj, 4),
    precision_of_flags = if (sum(flagged) > 0) round(sum(flagged & inj) / sum(flagged), 4) else NA,
    clean_rows_flagged = sum(flagged & !inj), clean_rows_altered = sum(altered & !inj),
    rows_flagged_per_1000 = round(1000 * mean(flagged), 1))
  cat(sprintf("done: %s %g%%\n", mix, 100 * rate))
}
out <- do.call(rbind, rows)
write.csv(out, file.path(RES, "prevalence_grid.csv"), row.names = FALSE)
print(out)
