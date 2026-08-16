# real_data_spec_curve.R — multiverse spec curve on REAL data (robustness #5)
# =============================================================================
# The 5.4 multiverse runs entirely on synthetic enrichment data. Real data
# (n=13,990) has no ground truth so recall is undefined, but the DOWNSTREAM
# sensitivity question is exactly the one a reviewer cares about: how much do
# mean TST/SOL/SE and analyzable n move when cleaning thresholds (D1 flip
# gap, D2 swap threshold, D3-D6 flag thresholds) change on the real dataset?
#
# Reuses spec_cache.R with input_rds = the real deidentified rds. The cache
# key includes the input sha, so these runs are distinct from the synthetic
# ones and deterministic.
#
# Output: results/real_data_spec_curve.csv
#   spec, mean_tst_h, mean_sol_min, mean_se_pct, analyzable_n, n_total,
#   n_flagged
# =============================================================================

suppressPackageStartupMessages({ library(dplyr); library(yaml) })

SYN <- "validation/synthetic"
RES <- file.path(SYN, "results")
source(file.path(SYN, "spec_cache.R"))

REAL_RD    <- "deidentified_intervalvars_forCD_111325.rds"
REAL_EXTRA <- "sber_ema_anon_20260227.csv"  # StartDate/num_waso live here
stopifnot(file.exists(REAL_RD), file.exists(REAL_EXTRA))

dims <- list(
  D1 = list(key = "timestamp.sequence.max_gap_hours",            levels = c(11, 12, 13), default = 12),
  D2 = list(key = "normalize.swap_threshold_hours",              levels = c(1, 3, 6),    default = 3),
  D3 = list(key = "classification.metric_validation.sol.excessive_minutes", levels = c(90, 120, 180), default = 120),
  D4 = list(key = "classification.flag_severity.poor_efficiency_threshold_pct", levels = c(60, 70, 80), default = 70),
  D5 = list(key = "classification.metric_validation.waso.excessive_hours",   levels = c(1.0, 1.5, 2.0), default = 1.5),
  D6 = list(key = "classification.metric_validation.tst_tib_ratio.min_ratio", levels = c(0.4, 0.5, 0.6), default = 0.5)
)
base_ov <- lapply(dims, function(x) x$default)
dim2key <- function(ov) { out <- list(); for (nm in names(ov)) out[[dims[[nm]]$key]] <- ov[[nm]]; out }

cat("=== Real-data multiverse: OAT screening ===\n")
base <- run_spec_once("real_BASE", dim2key(base_ov), input_rds = REAL_RD, extra_file = REAL_EXTRA)
stopifnot(!is.null(base))

oat <- data.frame(spec = "BASE", mean_tst_h = base$mean_tst_h, mean_sol_min = base$mean_sol_min,
                  mean_se_pct = base$mean_se_pct, analyzable_n = base$analyzable_n,
                  n_total = base$n_total, n_flagged = base$n_flagged)
for (nm in names(dims)) {
  for (lv in setdiff(dims[[nm]]$levels, dims[[nm]]$default)) {
    ov <- base_ov; ov[[nm]] <- lv
    s <- run_spec_once(sprintf("real_%s=%g", nm, lv), dim2key(ov), input_rds = REAL_RD, extra_file = REAL_EXTRA)
    if (is.null(s)) next
    oat <- rbind(oat, data.frame(spec = sprintf("%s=%g", nm, lv), mean_tst_h = s$mean_tst_h,
                 mean_sol_min = s$mean_sol_min, mean_se_pct = s$mean_se_pct,
                 analyzable_n = s$analyzable_n, n_total = s$n_total, n_flagged = s$n_flagged))
  }
}
write.csv(oat, file.path(RES, "real_data_oat_screening.csv"), row.names = FALSE)
cat("\n=== Real-data OAT screening ===\n")
print(oat, row.names = FALSE)

# Survival rule (same thresholds as multiverse.R)
keep <- names(dims)
for (nm in names(dims)) {
  rows <- oat[grepl(sprintf("^%s=", nm), oat$spec), ]
  if (nrow(rows) == 0) next
  d_tst <- max(abs(rows$mean_tst_h - base$mean_tst_h), na.rm = TRUE) * 60
  d_n   <- max(abs(rows$analyzable_n - base$analyzable_n), na.rm = TRUE) / base$analyzable_n * 100
  d_fl  <- max(abs(rows$n_flagged - base$n_flagged), na.rm = TRUE) / max(base$n_flagged, 1) * 100
  if (d_tst < 5 && d_n < 1 && d_fl < 1) keep <- setdiff(keep, nm)
}
if (length(keep) == 0) keep <- "D2"
# HONEST READING: on the real dataset all six dimensions fall below the
# survival rule (max |ΔTST| 0.93 min, max |Δn| 0.70% — see oat_screening).
# The fallback keeps the script runnable; the correct conclusion is that
# downstream quantities are INSENSITIVE to cleaning thresholds on real data.
# Spec curve below is therefore the D2-only fallback, not a selection result.
cat(sprintf("\nReal-data OAT survivors: %s %s\n", paste(keep, collapse = ", "),
    if (length(keep) == 1 && keep == "D2") "(fallback — NO dimension passed the survival rule on real data)" else ""))

# Full factorial on survivors (cached)
levs <- lapply(keep, function(nm) dims[[nm]]$levels); names(levs) <- keep
grid <- expand.grid(levs, stringsAsFactors = FALSE)
cat(sprintf("Factorial specs: %d\n", nrow(grid)))
res <- list()
for (i in seq_len(nrow(grid))) {
  ov <- base_ov
  for (nm in keep) ov[[nm]] <- grid[i, nm]
  lab <- paste(paste0(keep, "=", unlist(grid[i, keep])), collapse = "_")
  s <- run_spec_once(sprintf("real_%s", lab), dim2key(ov), input_rds = REAL_RD, extra_file = REAL_EXTRA)
  if (!is.null(s)) res[[lab]] <- data.frame(spec = lab, mean_tst_h = s$mean_tst_h,
      mean_sol_min = s$mean_sol_min, mean_se_pct = s$mean_se_pct,
      analyzable_n = s$analyzable_n, n_total = s$n_total, n_flagged = s$n_flagged)
}
curve <- do.call(rbind, res)
write.csv(curve, file.path(RES, "real_data_spec_curve.csv"), row.names = FALSE)
cat("\n=== Real-data specification curve ===\n")
print(curve, row.names = FALSE)
cat(sprintf("\nMean TST range [%.3f, %.3f] h | analyzable n range [%d, %d]\n",
            min(curve$mean_tst_h), max(curve$mean_tst_h),
            min(curve$analyzable_n), max(curve$analyzable_n)))
cat("\nWrote real_data_oat_screening.csv + real_data_spec_curve.csv\n")
cat("\n=== [real_data_spec_curve] Finished ===\n")