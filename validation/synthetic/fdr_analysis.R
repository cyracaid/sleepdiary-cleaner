# fdr_analysis.R — Benjamini-Hochberg multiplicity control, honest version
# =============================================================================
# Critique response (🔴 "FDR 缺失").
#
# Where BH does NOT apply (documented, not faked):
#   - M1-M7 audit: descriptive. 1048 flags are COUNTS of logical-consistency
#     violations, not p-values from tests. There is no null hypothesis per
#     flag. Applying BH to counts would be fake multiplicity control.
#   - Benchmark recall: participant-level cluster bootstrap CIs (2,000
#     resamples). These are distribution estimates, not single-test p-values.
#
# Where BH DOES apply (this script):
#   - Comparing per-category rates to each other (14 categories) as a
#     reviewer would: a category whose rate is "low" vs the rest needs
#     multiplicity-corrected support. Two honest approaches used here:
#     (A) pairwise exact tests category-vs-rest are NOT independent of the
#         pooled value, so instead we report, per category, the 95% CI and
#         whether it EXCLUDES the pooled rate (CI-based, no p-value, no BH
#         needed for a binary statement).
#     (B) a BH-corrected table of per-category p-values from exact binomial
#         tests vs a FIXED reference (0.90 target rate) — each category is an
#         independent test of "rate >= 0.90", which is a legitimate H0 that
#         avoids the pooled-vs-part circularity. BH then controls FDR across
#         the 14 tests.
#
# Output: results/fdr_corrected.csv
#   category, tier, n, est, ci_lo, ci_hi, excludes_pooled, p_vs_0.90, q_vs_0.90, sig_q
# =============================================================================

suppressPackageStartupMessages(library(dplyr))

SYN <- "validation/synthetic"
RES <- file.path(SYN, "results")

l2 <- read.csv(file.path(RES, "l2_tier.csv"), stringsAsFactors = FALSE)
l2 <- l2[l2$error_type != "no_error_control", ]

pooled_l2 <- sum(l2$L2_type_correct * l2$n) / sum(l2$n)

# (A) CI for each category's L2 rate (Wilson) + exclusion of pooled
wilson_ci <- function(k, n, z = 1.96) {
  p <- k / n
  denom <- 1 + z^2 / n
  centre <- (p + z^2 / (2 * n)) / denom
  half <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / denom
  c(lo = max(0, centre - half), hi = min(1, centre + half))
}

out <- lapply(seq_len(nrow(l2)), function(i) {
  ct <- l2$error_type[i]; n <- l2$n[i]; k <- round(l2$L2_type_correct[i] * n)
  ci <- wilson_ci(k, n)
  # (B) independent test: H0 rate >= 0.90, one-sided lower (is it BELOW target?)
  p_lo <- if (k < n) binom.test(k, n, p = 0.90, alternative = "less")$p.value else 1
  data.frame(category = ct, tier = "L2_type_correct", n = n, est = l2$L2_type_correct[i],
             ci_lo = ci["lo"], ci_hi = ci["hi"], pooled = pooled_l2,
             excludes_pooled = (ci["lo"] > pooled_l2) | (ci["hi"] < pooled_l2),
             p_vs_0.90 = p_lo, stringsAsFactors = FALSE)
})
fdr <- do.call(rbind, out)

# BH on the 14 independent p_vs_0.90 tests (monotone q, largest-p first)
pv <- fdr$p_vs_0.90
m <- length(pv)
ord <- order(pv)                            # ascending p
qv_sorted <- pv[ord] * m / seq_along(pv)    # BH step-up: p_i * m / i
qv_sorted <- pmin(1, rev(cummin(rev(qv_sorted))))  # monotone from largest p
q_out <- numeric(m); q_out[ord] <- qv_sorted
fdr$q_vs_0.90 <- q_out
fdr$sig_q <- fdr$q_vs_0.90 < 0.05

cat("\n=== FDR analysis (honest: CI exclusion + BH vs fixed 0.90 target) ===\n")
print(fdr, row.names = FALSE)
cat(sprintf("\nPooled L2 type-correct: %.3f\n", pooled_l2))
cat("\nCategories whose 95% CI EXCLUDES pooled L2 rate (CI-based, no BH needed):\n")
print(fdr[fdr$excludes_pooled, c("category", "est", "ci_lo", "ci_hi", "pooled")], row.names = FALSE)
cat("\nCategories significantly BELOW 0.90 target after BH (q<0.05):\n")
print(fdr[fdr$sig_q, c("category", "est", "p_vs_0.90", "q_vs_0.90")], row.names = FALSE)

write.csv(fdr, file.path(RES, "fdr_corrected.csv"), row.names = FALSE)
cat("\nWrote fdr_corrected.csv\n")
cat("\n=== [fdr_analysis] Finished ===\n")