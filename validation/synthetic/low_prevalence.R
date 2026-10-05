# low_prevalence.R -- the benchmark at a realistic error rate.
#
# The main benchmark injects 400 errors per category (5,391 of 7,000 rows, 77%),
# which is right for per-category recall and wrong for judging how a reviewer's
# workload looks. This script injects 25 per category (about 5% of rows), runs the
# pipeline once, and reports, for the whole table:
#   - the share of injected errors flagged or corrected to the true value, the share
#     corrected, flagged only, and repaired wrongly (same scorer as the main run),
#   - the precision of the flags (flagged rows that really carry an injected error),
#   - clean rows flagged or altered,
#   - the number of rows a reviewer would see per 1,000 entries.
#
# Self-contained: generates its own clean pool (seed 20260817, as the main run),
# injects with a temporary copy of the catalog, runs the installed sleepcleanr in
# a temporary project directory. Writes validation/synthetic/results/low_prevalence.csv.
# Usage (from the repository root): Rscript validation/synthetic/low_prevalence.R

suppressPackageStartupMessages({ library(yaml) })
SYN <- "validation/synthetic"
RES <- file.path(SYN, "results")
per_cat <- 25L
seed    <- 20260817

tmp <- file.path(tempdir(), "lowprev"); dir.create(tmp, recursive = TRUE)
clean_rds <- file.path(tmp, "clean.rds")
cat_path  <- file.path(tmp, "catalog.yaml")
corr_rds  <- file.path(tmp, "corrupted.rds")
truth_csv <- file.path(tmp, "truth.csv")

# 1. same clean pool as the main benchmark
system2("Rscript", c(file.path(SYN, "generate_clean_data.R"),
  "--n_participants=500", "--n_days=14", "--mode=plausible",
  "--population=healthy_adult", paste0("--seed=", seed), paste0("--out=", clean_rds)),
  stdout = TRUE, stderr = TRUE)
stopifnot(file.exists(clean_rds))

# 2. catalog copy with a smaller per-category target
cat_txt <- readLines(file.path(SYN, "error_catalog.yaml"), encoding = "UTF-8")
hit <- grep("^\\s*enrichment_target_per_category:", cat_txt)
stopifnot(length(hit) == 1)
cat_txt[hit] <- sub("enrichment_target_per_category:\\s*[0-9]+",
                    paste0("enrichment_target_per_category: ", per_cat), cat_txt[hit])
writeLines(cat_txt, cat_path, useBytes = TRUE)

system2("Rscript", c(file.path(SYN, "inject_errors.R"),
  paste0("--clean_rds=", clean_rds), paste0("--catalog=", cat_path),
  paste0("--out_data=", corr_rds), paste0("--out_truth=", truth_csv),
  paste0("--seed=", seed)), stdout = TRUE, stderr = TRUE)
stopifnot(file.exists(corr_rds), file.exists(truth_csv))

# 3. run the pipeline in an isolated project directory
run_dir <- file.path(tmp, "run")
system2("Rscript", c(file.path(SYN, "run_one.R"), corr_rds, run_dir, "low_prevalence"),
        stdout = TRUE, stderr = TRUE)
corrected <- readRDS(file.path(run_dir, "corrected_ema_data.rds"))
review    <- readRDS(file.path(run_dir, "review_output.rds"))
gt        <- read.csv(truth_csv, stringsAsFactors = FALSE)

d <- review$data_with_flags
flag_cols <- grep("_checkforerrors$", names(d), value = TRUE)
flag_marker <- rep(FALSE, nrow(d))
for (c in flag_cols) flag_marker <- flag_marker | (d[[c]] %in% TRUE)
flagged <- d$needs_review_flag %in% TRUE | flag_marker
flagged <- flagged[match(corrected$row_id, d$row_id)]
flagged[is.na(flagged)] <- FALSE
altered <- corrected$corrected %in% TRUE

injected_ids <- unique(gt$row_id[gt$error_type != "no_error_control"])
inj <- corrected$row_id %in% injected_ids
n <- nrow(corrected)

# per-category outcomes (same scorer as the main benchmark): corrected to the true
# value, flagged, repaired wrongly, missed
det_csv <- file.path(tmp, "outcomes.csv")
system2("Rscript", c(file.path(SYN, "evaluate_detection.R"), truth_csv, corr_rds,
  file.path(run_dir, "review_output.rds"), file.path(run_dir, "corrected_ema_data.rds"),
  det_csv), stdout = TRUE, stderr = TRUE)
oc <- read.csv(det_csv, stringsAsFactors = FALSE)
oc <- oc[oc$category != "no_error_control", ]
n_inj <- sum(oc$n)

out <- data.frame(
  metric = c("rows", "injected_rows", "injected_share",
             "flagged_or_corrected_to_true_value", "corrected_to_true_value",
             "flagged_only", "repaired_wrongly",
             "precision_of_flags", "clean_rows_flagged", "clean_rows_altered",
             "rows_flagged_per_1000"),
  value = c(n, n_inj, round(n_inj / n, 4),
            round((sum(oc$CORRECT) + sum(oc$FLAGGED_UNRESOLVED)) / n_inj, 4),
            round(sum(oc$CORRECT) / n_inj, 4),
            round(sum(oc$FLAGGED_UNRESOLVED) / n_inj, 4),
            round(sum(oc$MISREPAIRED) / n_inj, 4),
            round(sum(flagged & inj) / sum(flagged), 4),
            sum(flagged & !inj), sum(altered & !inj),
            round(1000 * mean(flagged), 1))
)
write.csv(out, file.path(RES, "low_prevalence.csv"), row.names = FALSE)
print(out)
