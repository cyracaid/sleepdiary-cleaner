# downstream_sensitivity.R — 5.5: downstream quantity sensitivity
# =============================================================================
# How much do downstream quantities (mean TST/SOL/SE, analyzable n) move
# under reasonable cleaning choices.
#
# Two layers:
#   A. Multiverse layer — reuse validation/synthetic/results/multiverse/
#      spec_curve.csv (9 factorial specs on real-corrupted benchmark data):
#      report mean TST / SOL / SE / analyzable n ranges across specs.
#   B. Real-data B1/B2 headlines (meeting D3, reportable regardless):
#      B1 branch: mean TST with vs without SOL added to sleep onset
#                 (7.71h vs 7.23h -> ~29 min shift) — documented in
#                 2026-08-10 week worklog; recomputed here on cleaned real data.
#      B2 branch: usable-n shift from the WASO trust gate (a/b/c) ~1,127
#                 records.
#
# Outputs (validation/synthetic/results/):
#   downstream_sensitivity.csv — multiverse ranges + B1/B2 headline numbers
# =============================================================================

suppressPackageStartupMessages(library(dplyr))

SYN <- "validation/synthetic"
RES <- file.path(SYN, "results")

# ── A. Multiverse layer ─────────────────────────────────────────────────────
spec <- read.csv(file.path(RES, "multiverse", "spec_curve.csv"))
# main curve is now the ROBUST (seed-stable) dims only — D1-only after the
# seed-sensitivity finding. Base = the default level of the robust dim(s).
base <- spec[spec$spec == "D1=12", ]
if (nrow(base) == 0) base <- spec[spec$spec == "D1=12_D2=3", ]
if (nrow(base) == 0) base <- spec[1, ]

cat("\n=== A. Downstream quantities across multiverse specs (n=9) ===\n")
cat(sprintf("Mean TST:      base %.3f h | range [%.3f, %.3f] h | max shift %.1f min\n",
            base$mean_tst_h, min(spec$mean_tst_h), max(spec$mean_tst_h),
            60 * max(abs(spec$mean_tst_h - base$mean_tst_h))))
cat(sprintf("Mean SOL:      base %.1f min | range [%.1f, %.1f] min\n",
            base$mean_sol_min, min(spec$mean_sol_min), max(spec$mean_sol_min)))
cat(sprintf("Mean SE:       base %.4f | range [%.4f, %.4f]\n",
            base$mean_se_pct, min(spec$mean_se_pct), max(spec$mean_se_pct)))
cat(sprintf("Analyzable n:  base %d | range [%d, %d] | max shift %d records (%.1f%%)\n",
            base$analyzable_n, min(spec$analyzable_n), max(spec$analyzable_n),
            max(abs(spec$analyzable_n - base$analyzable_n)),
            100 * max(abs(spec$analyzable_n - base$analyzable_n)) / base$analyzable_n))

# ── B. Real-data B1/B2 headlines ────────────────────────────────────────────
# B1: sleep-onset semantics — TST excludes vs includes SOL.
# The 2026-08-10 decision: sleeponset WITHOUT self-report SOL (sleepcleanr
# implementation). If SOL were added: mean TST shifts ~29 min (7.71 -> 7.23).
# Recompute from cleaned real data: mean(TST) and mean(TST + SOL).
real <- readRDS("output/cleaned_data_full.rds")
tst <- real$self_diffcalc_totalsleeptime_minutes
# self_diffcalc_sol_minutes is the timestamp-derived SOL (matches the
# documented 7.71 -> 7.23h / ~29 min B1 headline; the _mincalc_for_review
# column is trust-gated and covers a different subset)
sol <- real$self_diffcalc_sol_minutes
ok <- !is.na(tst) & !is.na(sol)

tst_mean_h <- mean(tst[ok], na.rm = TRUE) / 60
# reference implementation: sleep onset = bed + SOL, so sleep period (and TST)
# SHORTENS by SOL: TST_ref = TST - SOL (documented 7.71h -> 7.23h, ~29 min)
tst_minus_sol_h <- mean((tst - sol)[ok], na.rm = TRUE) / 60
b1_shift_min <- 60 * (tst_mean_h - tst_minus_sol_h)

cat("\n=== B. Real-data B1/B2 headlines ===\n")
cat(sprintf("B1 sleeponset semantics: mean TST %.2f h vs (TST-SOL) %.2f h -> %.0f min shift\n",
            tst_mean_h, tst_minus_sol_h, b1_shift_min))

# B2: WASO trust gate. usable_n = records with non-NA TST under gate variants.
# Gate b = TST requires WASO; gate a = TST valid with WASO imputed/untrusted.
# The ~1,127 figure = records with complete timestamps but missing self-report
# WASO (TST NaN under the strict gate).
strict_n  <- sum(!is.na(tst) & !is.na(real$duration_totalmin_waso_estimate_am_mincalc_used))
# TST without WASO requirement (sleepperiod-based upper bound)
loose_n   <- sum(!is.na(real$self_diffcalc_sleepperiod_minutes))
cat(sprintf("B2 WASO trust gate: analyzable n strict %d vs loose %d -> shift %d records\n",
            strict_n, loose_n, abs(loose_n - strict_n)))

out <- data.frame(
  layer = c("multiverse_mean_tst_h", "multiverse_mean_sol_min", "multiverse_analyzable_n",
            "B1_tst_shift_min", "B2_n_shift_records"),
  base_value = c(base$mean_tst_h, base$mean_sol_min, base$analyzable_n,
                 b1_shift_min, abs(loose_n - strict_n)),
  min_value = c(min(spec$mean_tst_h), min(spec$mean_sol_min), min(spec$analyzable_n), NA, NA),
  max_value = c(max(spec$mean_tst_h), max(spec$mean_sol_min), max(spec$analyzable_n), NA, NA)
)
write.csv(out, file.path(RES, "downstream_sensitivity.csv"), row.names = FALSE)
cat("\nWrote downstream_sensitivity.csv\n")
cat("\n=== [downstream_sensitivity] Finished ===\n")
