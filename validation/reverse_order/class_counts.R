# class_counts.R -- recount the nights whose self-reported times are out of order,
# by mechanism, from a delivered dataset.
#
# This is the script behind the numbers in the section "What the external mixes
# measure, and what they do not" of validation/synthetic/README_results.md:
# 2,848 complete nights, 140 reversed (4.92%), 134 after setting aside the 6
# impossible get-up values (4.71%), and the per-mechanism split.
#
# It reads output/cleaned_data_full.rds, which a pipeline run writes and which
# carries the parsed pre-correction columns (time_*_am_hhmm_ampm). Those columns
# are what classify_reversals() needs; the delivered Dataset A/B do not carry
# them.
#
# The study data are not in this repository, so this script can only run where a
# run has produced output/cleaned_data_full.rds. The counts it printed for the
# study are recorded in the results file next to it.
#
# Usage (from the repository root, with the package loaded):
#   devtools::load_all(".")   # or library(sleepcleanr), if the installed build
#                             # already has classify_reversals()
#   source("validation/reverse_order/class_counts.R")
#
# Output: validation/reverse_order/results/reversal_class_counts.csv (counts only)

data_path <- file.path("output", "cleaned_data_full.rds")
out_path  <- file.path("validation", "reverse_order", "results", "reversal_class_counts.csv")

if (!file.exists(data_path)) {
  stop("No ", data_path, ". Run the pipeline first; this script reads the full ",
       "archive, not the delivered datasets.", call. = FALSE)
}
if (!exists("classify_reversals")) {
  stop("classify_reversals() is not available. Run devtools::load_all(\".\") ",
       "(or install a build that has it) before sourcing this script.", call. = FALSE)
}

d <- readRDS(data_path)
rev <- classify_reversals(d)
s <- attr(rev, "summary")

cat(sprintf("rows: %d | complete nights: %d | reversed: %d (%.2f%%) | reported: %d (%.2f%%)\n",
            nrow(d), s$n_complete, s$counts[["all"]], s$rates[["all"]],
            s$counts[["reported"]], s$rates[["reported"]]))

detail <- sort(table(rev$detail), decreasing = TRUE)
cat("\nby mechanism:\n")
print(detail)

dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)
out <- data.frame(detail = names(detail), n = as.integer(detail),
                  stringsAsFactors = FALSE)
out <- rbind(out, data.frame(detail = "ALL_REVERSALS", n = s$counts[["all"]]))
out <- rbind(out, data.frame(detail = "REPORTED_EXCL_VALUE_BROKEN",
                             n = s$counts[["reported"]]))
write.csv(out, out_path, row.names = FALSE)
cat("\nwrote ", out_path, "\n", sep = "")
