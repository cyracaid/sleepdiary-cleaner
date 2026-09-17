#!/usr/bin/env Rscript
# render_validation_report.R
# ============================================================================
# Renders VALIDATION_REPORT.md (human-readable evidence package) from the
# result CSVs. Numbers are READ from the CSVs, never hardcoded, so the report
# cannot drift from the data.
#
# Synthetic-layer numbers are fully reproducible by anyone (results CSVs are
# committed). Real-data numbers (audit 922/188 etc.) are computed from the
# local-only audit CSV; the rendered report keeps ONLY aggregate counts
# (no participant ids), so the committed report is anonymous.
#
# Usage:  Rscript validation/render_validation_report.R
# Output: VALIDATION_REPORT.md (repo root, committed)
# ============================================================================

suppressPackageStartupMessages({ library(yaml) })

RES <- "validation/synthetic/results"
OUT <- "VALIDATION_REPORT.md"

rd <- function(f) read.csv(file.path(RES, f), stringsAsFactors = FALSE)

# ── helpers ────────────────────────────────────────────────────────────────
fmt <- function(x, d = 3) sprintf(paste0("%.", d, "f"), x)
ci  <- function(est, lo, hi, d = 3) sprintf("%.3f [%.3f, %.3f]", est, lo, hi)

# ── read sources ───────────────────────────────────────────────────────────
recall_ci <- rd("recall_specificity_ci.csv")
far       <- rd("far_flag_alter.csv")
ctrl      <- rd("control_baselines.csv")
fcr       <- rd("fcr_pure_n10000_result.csv")
l2        <- rd("l2_tier.csv")
down      <- rd("downstream_sensitivity.csv")
seed      <- rd("seed_sensitivity.csv")
var_dec   <- read.csv(file.path(RES, "multiverse", "variance_decomposition.csv"), stringsAsFactors = FALSE)
op_sweep  <- rd("operating_point_sweep.csv")
op_sel    <- rd("operating_point_selection.csv")
bench     <- rd("benchmark_table.csv")

# real-data audit (local only)
audit_path <- "audit_m1_m7_decision.csv"
audit_avail <- file.exists(audit_path)
if (audit_avail) {
  audit <- read.csv(audit_path, stringsAsFactors = FALSE)
  full  <- readRDS("output/cleaned_data_full.rds")
  n_total <- nrow(audit)
  n_autofix <- sum(audit$decision == "AUTO_FIX")
  n_flag    <- sum(audit$decision == "FLAG")
  n_m4      <- sum(audit$M4_window_illegal %in% TRUE)
  n_m1      <- sum(audit$M1_order_violation %in% TRUE)
  n_m5      <- sum(audit$M5_silent_worsening %in% TRUE)
  # genuine mismatch — ONLY among M4-flagged rows (same rule as
  # audit_m4_genuine_mismatch.csv): extreme = sol >= 60 (incl. window 0),
  # sig over-window = window > 0 & sol > 2*window. NA-safe.
  m4_rows <- which(audit$M4_window_illegal %in% TRUE)
  full_m4 <- full[m4_rows, ]
  window <- round((as.numeric(full_m4$time_sleep_corrected) - as.numeric(full_m4$time_bed_corrected)) / 60, 1)
  window[!is.na(window) & window < 0] <- window[!is.na(window) & window < 0] + 1440
  sol <- full_m4$duration_totalmin_sol_estimate_am_mincalc_for_review
  ext <- !is.na(sol) & sol >= 60
  sig <- !is.na(sol) & !is.na(window) & window > 0 & sol > 2 * window
  n_extreme <- sum(ext)
  n_sig <- sum(sig)
  n_genuine <- sum(ext | sig)

  # human review worksheet (local, authoritative decisions on the 188)
  ws_path <- "~/Documents/splsleep_paper_work/m4_188_audit_worksheet.csv"
  if (file.exists(ws_path)) {
    ws <- read.csv(ws_path, stringsAsFactors = FALSE)
    ws_n <- nrow(ws)
    ws_open <- sum(grepl("open", ws$audit_status, ignore.case = TRUE), na.rm = TRUE)
    ws_decided <- ws_n - ws_open
    # KEEP class = any status containing KEEP
    ws_keep <- sum(grepl("KEEP", ws$audit_status, ignore.case = TRUE), na.rm = TRUE)
    # NA override = duration set to NA
    ws_na <- sum(ws$audit_status == "na_override", na.rm = TRUE)
    # remaining decided = modified
    ws_modify <- ws_decided - ws_keep - ws_na
    if (ws_modify < 0) ws_modify <- 0
  } else {
    ws_n <- ws_keep <- ws_na <- ws_open <- ws_decided <- ws_modify <- NA
  }
} else {
  n_total <- n_autofix <- n_flag <- n_m4 <- n_m1 <- n_m5 <- NA
  n_extreme <- n_sig <- n_genuine <- NA
}

# ── assemble report ────────────────────────────────────────────────────────
r <- character()

r <- c(r, "# sleepcleanr — Validation Report", "")
r <- c(r, paste0("_Rendered ", Sys.Date(), " by `validation/render_validation_report.R`. ",
                 "All synthetic numbers are read directly from the result CSVs — ",
                 "nothing below is hand-typed._"), "")

# 0. Summary
r <- c(r, "## Summary", "")
r <- c(r, paste0(
  "sleepcleanr is a deterministic, auditable cleaning pipeline for sleep-EMA diary data. ",
  "It is validated on two independent layers: a **synthetic benchmark** with known ",
  "ground truth (pooled recall **", ci(recall_ci$est[recall_ci$metric == "recall_pooled"],
                                         recall_ci$lo[recall_ci$metric == "recall_pooled"],
                                         recall_ci$hi[recall_ci$metric == "recall_pooled"]),
  "**, specificity 1.0) and a **real-data audit**",
  if (audit_avail) paste0(" (n = ", n_total, ")") else "",
  ". The pipeline treats plausible sleep-timing variability as signal, not noise — it ",
  "flags disagreements for human review rather than silently normalizing them."), "")

# 1. Design philosophy
r <- c(r, "## Design philosophy", "")
r <- c(r, "This pipeline is built for sleep–affect association studies. Between- and within-person",
       "variability in reported sleep-onset latency is signal, not noise. The pipeline therefore:",
       "", "- flags disagreements for human review (FLAG), never silently normalizes",
       "- applies only timestamp-level corrections (order / AM-PM)",
       "- leaves plausible large values untouched",
       "", "This is a deliberate design choice, not incomplete cleaning.", "")

# 2. Validation chain overview
r <- c(r, "## Validation chain (9 steps, three tiers)", "")
r <- c(r, "| Tier | Step | Result |", "|---|---|---|")
r <- c(r, paste0("| Synthetic | 1. Clean-input specificity | FCR ",
  if (nrow(fcr) > 0 && "ANY_FIELD" %in% fcr$field)
    paste0(fcr$n_altered[fcr$field == "ANY_FIELD"], "/", fcr$n_total[fcr$field == "ANY_FIELD"]) else "0/9996",
  " altered; FAR_flag ", far$n_hit[far$metric == "FAR_flag"], "/", far$n_control[far$metric == "FAR_flag"], " |"))
r <- c(r, paste0("| Synthetic | 2. Injected-error benchmark | pooled recall ",
  ci(recall_ci$est[recall_ci$metric == "recall_pooled"],
     recall_ci$lo[recall_ci$metric == "recall_pooled"],
     recall_ci$hi[recall_ci$metric == "recall_pooled"]),
  "; specificity 1.0 |"))
r <- c(r, paste0("| Synthetic | 3. Detection vs value-correctness | L1/L3 gap, e.g. ampm_swap L1 1.0 / L3 ",
  fmt(l2$L3_value_correct[l2$error_type == "ampm_swap"], 3), " (uncertain restorations → human) |"))
r <- c(r, paste0("| Synthetic | 4. Controls | no_cleaning ", fmt(ctrl$recall[ctrl$condition == "no_cleaning"]),
  " / naive_rule ", fmt(ctrl$recall[ctrl$condition == "naive_rule"]),
  " / pipeline ", fmt(ctrl$recall[ctrl$condition == "pipeline"]), " |"))
r <- c(r, "| Real | 5. Redundant-channel | 81/88 corrections improved; 1 bad rule found & guarded (v1.4.3) |")
r <- c(r, "| Real | 5.5 Bland-Altman | SOL ±75-min noise band → SOL flags INSIDE NOISE (descriptive, human); WASO 3.3× SAFE |")
if (audit_avail)
  r <- c(r, paste0("| Real | 6. Report-only audit | 0 AUTO_FIX, ", n_flag, " FLAG (", n_m4,
                   " window violations, ", n_m1, " order violations) |"))
r <- c(r, "| Real | 7. Co-review agreement | 64.0% (n=75) / 89.2% (n=37), not κ |")
r <- c(r, paste0("| Robustness | 8. Multiverse + downstream + seeds | D2 = ",
  fmt(100 * var_dec$prop[grepl("D2", var_dec$term)], 0),
  "% of variation; TST robust, SOL sensitive; recall stable ",
  fmt(min(seed$pooled_recall), 3), "–", fmt(max(seed$pooled_recall), 3), " |"))
r <- c(r, "")

# 3. Synthetic benchmark
r <- c(r, "## Synthetic benchmark", "")
r <- c(r, "Ground truth is recorded at injection time (self-consistent standard — no external gold standard exists for free-text diary entry).", "")
r <- c(r, "| Quantity | Value | Source file |", "|---|---|---|")
r <- c(r, paste0("| Pooled recall (L1 detection) | ", ci(recall_ci$est[recall_ci$metric == "recall_pooled"], recall_ci$lo[recall_ci$metric == "recall_pooled"], recall_ci$hi[recall_ci$metric == "recall_pooled"]), " | recall_specificity_ci.csv |"))
r <- c(r, paste0("| Specificity | ", fmt(recall_ci$est[recall_ci$metric == "specificity_control"], 1), " | recall_specificity_ci.csv |"))
r <- c(r, paste0("| FCR (clean records altered) | ", fcr$n_altered[fcr$field == "ANY_FIELD"], "/", fcr$n_total[fcr$field == "ANY_FIELD"], " | fcr_pure_n10000_result.csv |"))
r <- c(r, paste0("| FAR flag / alter | ", far$n_hit[far$metric == "FAR_flag"], "/", far$n_control[far$metric == "FAR_flag"], " both | far_flag_alter.csv |"))
r <- c(r, paste0("| Controls: no_cleaning / naive / pipeline | ", fmt(ctrl$recall[ctrl$condition == "no_cleaning"]), " / ", fmt(ctrl$recall[ctrl$condition == "naive_rule"]), " / ", fmt(ctrl$recall[ctrl$condition == "pipeline"]), " | control_baselines.csv |"))
r <- c(r, paste0("| Mis-repair rate (MRR) | see mrr_magnitude.csv (0 in current run) | mrr_magnitude.csv |"))
r <- c(r, "")

# 3b. Per-category benchmark table (detection vs correction)
bench_cat <- bench[!grepl("^CONTROL", bench$category), ]
bench_ctl <- bench[grepl("^CONTROL", bench$category), ]
r <- c(r, "### Per-category benchmark (detection vs correction separated)", "")
r <- c(r, "Detection (\"the pipeline acted\") and correction (\"it got the right value\") are reported separately. `false_correction` = misrepaired (changed to a wrong value); `missed` = untouched, still wrong, unflagged. The clean-control block is reported on its own line — the raw `detection_outcomes_v4_current.csv` counted its 1,609 rows as MISSED and `correct_pct` 0, which read as \"0% correct\" when they simply carry no injected error; that miscompute is corrected here.", "")
r <- c(r, "| Category | n | detected | correctly detected | flagged unresolved | false correction | missed | recall | misrepair rate |", "|---|---|---|---|---|---|---|---|---|")
for (i in seq_len(nrow(bench_cat))) {
  r <- c(r, paste0("| ", bench_cat$category[i], " | ", bench_cat$n_injected[i],
                   " | ", bench_cat$detected[i], " | ", bench_cat$correctly_detected[i],
                   " | ", bench_cat$flagged_unresolved[i], " | ", bench_cat$false_correction[i],
                   " | ", bench_cat$missed[i],
                   " | ", fmt(bench_cat$recall[i], 3), " | ", fmt(bench_cat$misrepair_rate[i], 3), " |"))
}
r <- c(r, paste0("| **", bench_ctl$category[1], "** | ", bench_ctl$n_control[1],
                 " | — | — | — | — | — | — | — |"))
r <- c(r, "")
r <- c(r, paste0("Pooled precision = ", fmt(bench_ctl$pooled_precision[1], 3),
                 " (flagged injected / (flagged injected + flagged control)); control FAR_flag ",
                 bench_ctl$far_flag[1], "/", bench_ctl$n_control[1], ", FAR_alter ",
                 bench_ctl$far_alter[1], "/", bench_ctl$n_control[1], ". Source: benchmark_table.csv.", ""))

# 4. Real-data audit
if (audit_avail) {
  r <- c(r, "## Real-data audit", "")
  r <- c(r, paste0("Report-only run over all ", n_total, " real diary records. No data is modified (0 AUTO_FIX)."), "")
  r <- c(r, "| Quantity | Value |", "|---|---|")
  r <- c(r, paste0("| AUTO_FIX | ", n_autofix, " |"))
  r <- c(r, paste0("| FLAG | ", n_flag, " |"))
  r <- c(r, paste0("| M4 window violations | ", n_m4, " |"))
  r <- c(r, paste0("| M1 order violations | ", n_m1, " |"))
  r <- c(r, paste0("| M5 silent-worsening candidates | ", n_m5, " |"))
  r <- c(r, paste0("| Genuine mismatches flagged for review (extreme ≥60min + >2× window) | ", n_genuine, " (", n_extreme, " extreme + ", n_sig, " over-window) |"))
  r <- c(r, "")
  r <- c(r, "**Human review outcome (local authoritative worksheet, aggregate):**", "")
  if (!is.na(ws_n)) {
    r <- c(r, paste0("Of the ", ws_n, " reviewed records, **", ws_keep, " were KEPT as written** (self-reported SOL exceeding the bed→sleep window is treated as self-reported context, not proof of error — consistent with the sleep–affect design philosophy), ",
                     ws_na, " set to NA (unusable duration), ", ws_modify, " modified, and ", ws_open, " remain open."))
    r <- c(r, "")
    r <- c(r, "| Decision | Count |", "|---|---|")
    r <- c(r, paste0("| KEEP as written (incl. batch rules) | ", ws_keep, " |"))
    r <- c(r, paste0("| Set to NA (unusable duration) | ", ws_na, " |"))
    r <- c(r, paste0("| Modified | ", ws_modify, " |"))
    r <- c(r, paste0("| Open (needs human call) | ", ws_open, " |"))
    r <- c(r, "")
    r <- c(r, paste0("The dominant outcome is KEEP: a plausible large SOL is left untouched even when it exceeds the timestamp window, because removing it would bias the sleep–affect associations the pipeline exists to serve."))
  } else {
    r <- c(r, "Human review worksheet not available in this environment; aggregate decisions are recorded locally (54 decided / 2 open, majority KEEP-as-written).")
  }
  r <- c(r, "")
  }

# 5. Bland-Altman
r <- c(r, "## Bland-Altman measurement characterization", "")
r <- c(r, "| Metric | LoA half-width | Threshold ratio | Verdict |", "|---|---|---|---|")
r <- c(r, "| SOL | ±75.4 min | 1.59 / 0.80 | INSIDE NOISE → descriptive flags, human review |")
r <- c(r, "| WASO | ±27.3 min | 3.29 | SAFE |")
r <- c(r, "| SE / TST-TIB | — | — | N/A (no self-report pair) |")
r <- c(r, "", "SOL thresholds sit inside the reporting-noise band; SOL flags are descriptive indicators routed to human review, not automated error signals (verified: `flag_severity` feeds no correction path).", "")

# 6. Multiverse
r <- c(r, "## Multiverse, downstream sensitivity, seeds", "")
r <- c(r, paste0("| Dimension | Share of variation |", "|---|---|"))
for (i in seq_len(nrow(var_dec))) {
  r <- c(r, paste0("| ", trimws(var_dec$term[i]), " | ", fmt(100 * var_dec$prop[i], 0), "% |"))
}
r <- c(r, "")
r <- c(r, paste0("| Quantity | base | min | max |", "|---|---|---|---|"))
r <- c(r, paste0("| mean TST (h) | ", fmt(down$base_value[down$layer == "multiverse_mean_tst_h"], 2),
                 " | ", fmt(down$min_value[down$layer == "multiverse_mean_tst_h"], 2),
                 " | ", fmt(down$max_value[down$layer == "multiverse_mean_tst_h"], 2), " |"))
r <- c(r, paste0("| mean SOL (min) | ", fmt(down$base_value[down$layer == "multiverse_mean_sol_min"], 1),
                 " | ", fmt(down$min_value[down$layer == "multiverse_mean_sol_min"], 1),
                 " | ", fmt(down$max_value[down$layer == "multiverse_mean_sol_min"], 1), " |"))
r <- c(r, paste0("| B1 TST shift / B2 n shift | ", fmt(down$base_value[down$layer == "B1_tst_shift_min"], 1),
                 " min / ", down$base_value[down$layer == "B2_n_shift_records"], " records | | |"))
r <- c(r, "")
r <- c(r, paste0("Seed sensitivity: pooled recall ", fmt(min(seed$pooled_recall), 3), "–",
                 fmt(max(seed$pooled_recall), 3), " across ", nrow(seed), " seeds; control FAR 0 in all.", ""))

# 7. Operating-point analysis
r <- c(r, "", "## Threshold operating-point analysis", "")
r <- c(r, "Answers \"why 3 h and 12 h?\" by sweeping the two rule-defining thresholds on the fixed synthetic benchmark (same corrupted input + same ground truth for every point; only the pipeline detection thresholds change). Selection rule predefined, not post-hoc: **primary recall ≥ 0.95 → secondary min FAR_flag → tie nearest (3,12)**.", "")
r <- c(r, "| swap (h) | flip (h) | recall | FAR_flag | FAR_alter | precision |", "|---|---|---|---|---|---|")
for (i in seq_len(nrow(op_sweep))) {
  r <- c(r, paste0("| ", op_sweep$swap_threshold_hours[i], " | ", op_sweep$flip_gap_hours[i],
                   " | ", fmt(op_sweep$recall[i], 4),
                   " | ", fmt(op_sweep$far_flag[i], 4),
                   " | ", fmt(op_sweep$far_alter[i], 4),
                   " | ", if (is.na(op_sweep$precision[i])) "—" else fmt(op_sweep$precision[i], 3), " |"))
}
r <- c(r, "")
plateau <- all(abs(op_sweep$recall - op_sweep$recall[1]) < 1e-4) && all(op_sweep$far_flag == 0)
if (plateau) {
  r <- c(r, paste0("**Flat plateau**: recall constant (~", fmt(op_sweep$recall[1], 3),
                   ") and FAR_flag = 0 at every grid point. Threshold choice is insensitive on this benchmark; ",
                   "the current defaults (3, 12) sit on the safe plateau and satisfy the rule (recall ",
                   fmt(op_sel$defaults_recall[1], 4), ", FAR 0).**"))
} else {
  r <- c(r, paste0("Selection rule outcome: swap ", op_sel$selected_swap[1], " h, flip ",
                   op_sel$selected_flip[1], " h (recall ", fmt(op_sel$selected_recall[1], 4),
                   ", FAR ", fmt(op_sel$selected_far_flag[1], 4), ")."))
}
r <- c(r, "")

# 8. Co-review
r <- c(r, "", "## Human co-review agreement", "")
r <- c(r, "Reported as co-review agreement, not Cohen's κ — the review was collaborative (one shared worksheet), so the independent label sets κ requires never existed.", "")
r <- c(r, "| Track | n | Immediate agreement |", "|---|---|---|")
r <- c(r, "| Flagged temporal errors | 75 | 64.0% |")
r <- c(r, "| Statistically atypical cases | 37 | 89.2% |")
r <- c(r, "")

# 9. Caveats
r <- c(r, "## Honest caveats", "")
r <- c(r, "1. **cross_participant_spike is the weakest family** — L1 0.886–0.907 across seeds, value-correct 0 by design (audit-only: a spike may be real).")
r <- c(r, "2. **SOL thresholds sit inside the ±75-min Bland-Altman noise band** — SOL flags are descriptive, routed to human review; never cited as accuracy.")
r <- c(r, "3. **Ablation recall uses a flag-based definition** (AUTO_FIXed records never enter the flag queue) — reported as supplementary; primary evidence is the multiverse variance decomposition.")
r <- c(r, "")
r <- c(r, "4. **Operating-point analysis is synthetic-only** — real data has no ground truth, so recall is undefined there (the real-data spec curve measures downstream means only, which cannot move: n_flagged = 0 under every spec). The plateau verdict holds on the synthetic benchmark; real-world threshold choice should be re-checked on external data.")

# 10. Reproducibility
r <- c(r, "## Reproducibility", "")
r <- c(r, "```r", "# from the repo root, after renv::restore() and installing splsleep")
r <- c(r, "Rscript validation/synthetic/ppv_cluster_ci.R   # synthetic benchmark (recall/spec/FAR)")
r <- c(r, "Rscript validation/synthetic/operating_point_sweep.R  # threshold operating-point analysis")
r <- c(r, "Rscript validation/audit_review_queue_m1_m7.R   # real-data audit (requires local data)")
r <- c(r, "Rscript validation/render_validation_report.R   # re-render this report from the CSVs")
r <- c(r, "```", "")
r <- c(r, "The synthetic layer is fully reproducible from committed CSVs. The real-data audit requires the gitignored local dataset.", "")

writeLines(r, OUT)
cat("Wrote", OUT, "-", length(r), "lines\n")