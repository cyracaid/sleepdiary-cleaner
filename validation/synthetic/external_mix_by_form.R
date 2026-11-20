# external_mix_by_form.R -- the per-form counts behind the two external-mix rows of
# prevalence_grid.csv (external_inverted and external_same, at 5% of rows).
#
# prevalence_grid.csv scores each mix as a whole. Each cell's per-category scoring is
# written to a temporary folder that R deletes on exit, so the split by form (for
# example 282 of 282 exchanged pairs corrected) was not kept. This script runs the
# whole grid through prevalence_grid.R, keeps those two cells' tables, and writes
# validation/synthetic/results/external_mix_by_form.csv. It takes about 8 minutes.
# prevalence_grid.csv is rewritten with identical content (checked 2026-11-20: same md5).
#
# Intervals are exact (Clopper-Pearson), 95%, on "flagged or corrected to the true value".
# Usage (from the repository root): Rscript validation/synthetic/external_mix_by_form.R

source("validation/synthetic/prevalence_grid.R")

cells <- c(external_inverted = "external_inverted_0.05", external_same = "external_same_0.05")
exact_ci <- function(k, n) {
  lo <- if (k == 0) 0 else qbeta(0.025, k, n - k + 1)
  hi <- if (k == n) 1 else qbeta(0.975, k + 1, n - k)
  round(100 * c(lo, hi), 1)
}
out <- do.call(rbind, lapply(names(cells), function(mix) {
  o <- read.csv(file.path(tempdir(), "grid", cells[[mix]], "outcomes.csv"), stringsAsFactors = FALSE)
  o <- o[o$category != "no_error_control", ]
  handled <- o$CORRECT + o$FLAGGED_UNRESOLVED
  ci <- t(mapply(exact_ci, handled, o$n))
  data.frame(mix = mix, form = o$category, n_injected = o$n,
             corrected_to_true_value = o$CORRECT, flagged_only = o$FLAGGED_UNRESOLVED,
             repaired_wrongly = o$MISREPAIRED, missed = o$MISSED + o$NO_MATCH,
             handled_pct = round(100 * handled / o$n, 1), ci_low = ci[, 1], ci_high = ci[, 2],
             stringsAsFactors = FALSE)
}))
write.csv(out, file.path(RES, "external_mix_by_form.csv"), row.names = FALSE)
cat("wrote", file.path(RES, "external_mix_by_form.csv"), "\n")
