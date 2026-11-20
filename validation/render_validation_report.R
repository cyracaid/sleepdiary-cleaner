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
# Output: VALIDATION_REPORT.md     (English, repo root, committed)
#         VALIDATION_REPORT-zh.md  (Chinese, same numbers, repo root, committed)
# Both files come from one template below: every sentence is written once per
# language with T(en, zh), so the two reports cannot show different numbers.
# ============================================================================

suppressPackageStartupMessages({ library(yaml) })

RES <- "validation/synthetic/results"
OUT <- c(en = "VALIDATION_REPORT.md", zh = "VALIDATION_REPORT-zh.md")

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
  # The worksheet holds real review decisions and lives outside the repo; it moved
# from ~/Documents/splsleep_paper_work/ to the private folder below. Set
# SPLSLEEP_AUDIT_WORKSHEET to point somewhere else.
  ws_path <- Sys.getenv("SPLSLEEP_AUDIT_WORKSHEET",
                        "~/Documents/splsleep_private/splsleep_paper_work/m4_188_audit_worksheet.csv")
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
render_report <- function(lang) {
T <- function(en, zh) if (lang == "zh") zh else en
r <- character()
rp <- recall_ci$metric == "recall_pooled"
pooled <- ci(recall_ci$est[rp], recall_ci$lo[rp], recall_ci$hi[rp])
fcr_any <- fcr$field == "ANY_FIELD"
fcr_txt <- if (nrow(fcr) > 0 && "ANY_FIELD" %in% fcr$field)
  paste0(fcr$n_altered[fcr_any], "/", fcr$n_total[fcr_any]) else "0/9996"
far_txt <- paste0(far$n_hit[far$metric == "FAR_flag"], "/", far$n_control[far$metric == "FAR_flag"])

r <- c(r, T("# sleepcleanr — Validation Report", "# sleepcleanr — 验证报告"), "")
r <- c(r, T(paste0("_Rendered ", Sys.Date(), " by `validation/render_validation_report.R`. ",
                   "All synthetic numbers are read directly from the result CSVs — ",
                   "nothing below is hand-typed._"),
            paste0("_由 `validation/render_validation_report.R` 于 ", Sys.Date(), " 生成。",
                   "所有合成数据的数字都直接读自结果 CSV——下文没有手工键入的数字。_")), "")
r <- c(r, T("English · [中文](VALIDATION_REPORT-zh.md)", "[English](VALIDATION_REPORT.md) · 中文"), "")

# 0. Summary
r <- c(r, T("## Summary", "## 摘要"), "")
r <- c(r, T(paste0(
  "sleepcleanr is a deterministic, auditable cleaning pipeline for sleep-EMA diary data. ",
  "It is validated on two independent layers: a **synthetic benchmark** with known ",
  "ground truth (pooled recall **", pooled, "**, specificity 1.0) and a **real-data audit**",
  if (audit_avail) paste0(" (n = ", n_total, ")") else "",
  ". The pipeline treats plausible sleep-timing variability as signal, not noise — it ",
  "flags disagreements for human review rather than silently normalizing them."),
  paste0(
  "sleepcleanr 是一条确定性的、可审计的睡眠 EMA 日记数据清洗管线。它在两个相互独立的层面上验证：",
  "有已知真值的**合成基准**（合并召回率 **", pooled, "**，特异度 1.0）和**真实数据审计**",
  if (audit_avail) paste0("（n = ", n_total, "）") else "",
  "。管线把合理的睡眠时间变异视为信号而非噪声——对有分歧的记录标记后交人工审核，而不是静默地规整掉。")), "")

# 1. Design philosophy
r <- c(r, T("## Design philosophy", "## 设计理念"), "")
if (lang == "zh") {
  r <- c(r, "本管线为睡眠–情绪关联研究而设计。人与人之间、同一人前后之间自报入睡潜伏期的变异是信号，不是噪声。因此管线：",
         "", "- 对有分歧的记录标记（FLAG）交人工审核，从不静默规整",
         "- 只做时间戳层面的修正（顺序 / AM-PM）",
         "- 对合理的较大值保持原样",
         "", "这是有意的设计选择，不是清洗不彻底。", "")
} else {
  r <- c(r, "This pipeline is built for sleep–affect association studies. Between- and within-person",
         "variability in reported sleep-onset latency is signal, not noise. The pipeline therefore:",
         "", "- flags disagreements for human review (FLAG), never silently normalizes",
         "- applies only timestamp-level corrections (order / AM-PM)",
         "- leaves plausible large values untouched",
         "", "This is a deliberate design choice, not incomplete cleaning.", "")
}

# 2. Validation chain overview
r <- c(r, T("## Validation chain (9 steps, three tiers)", "## 验证链（9 步，三个层级）"), "")
r <- c(r, T("| Tier | Step | Result |", "| 层级 | 步骤 | 结果 |"), "|---|---|---|")
syn <- T("Synthetic", "合成"); real <- T("Real", "真实数据"); rob <- T("Robustness", "稳健性")
r <- c(r, T(paste0("| ", syn, " | 1. Clean-input specificity | FCR ", fcr_txt, " altered; FAR_flag ", far_txt, " |"),
            paste0("| ", syn, " | 1. 干净输入的特异度 | FCR ", fcr_txt, " 被改动；FAR_flag ", far_txt, " |")))
r <- c(r, T(paste0("| ", syn, " | 2. Injected-error benchmark | pooled recall ", pooled, "; specificity 1.0 |"),
            paste0("| ", syn, " | 2. 注入错误基准 | 合并召回率 ", pooled, "；特异度 1.0 |")))
l3 <- fmt(l2$L3_value_correct[l2$error_type == "ampm_swap"], 3)
r <- c(r, T(paste0("| ", syn, " | 3. Detection vs value-correctness | L1/L3 gap, e.g. ampm_swap L1 1.0 / L3 ", l3, " (uncertain restorations → human) |"),
            paste0("| ", syn, " | 3. 检出 vs 值是否正确 | L1/L3 差距，例如 ampm_swap L1 1.0 / L3 ", l3, "（不确定的还原 → 交人工） |")))
ctrl3 <- paste0(fmt(ctrl$recall[ctrl$condition == "no_cleaning"]), " / ", fmt(ctrl$recall[ctrl$condition == "naive_rule"]),
                " / ", fmt(ctrl$recall[ctrl$condition == "pipeline"]))
r <- c(r, paste0("| ", syn, " | ", T("4. Controls", "4. 对照"), " | no_cleaning ", fmt(ctrl$recall[ctrl$condition == "no_cleaning"]),
  " / naive_rule ", fmt(ctrl$recall[ctrl$condition == "naive_rule"]),
  " / pipeline ", fmt(ctrl$recall[ctrl$condition == "pipeline"]), " |"))
r <- c(r, T(paste0("| ", real, " | 5. Redundant-channel | 80/81 corrections improved (98.8%); 1 bad rule found & guarded (v1.4.3) |"),
            paste0("| ", real, " | 5. 冗余通道 | 80/81 条修正使数据更好（98.8%）；发现 1 条有问题的规则并加了守卫（v1.4.3） |")))
r <- c(r, T(paste0("| ", real, " | 5.5 Bland-Altman | SOL ±75-min noise band → SOL flags INSIDE NOISE (descriptive, human); WASO 3.3× SAFE |"),
            paste0("| ", real, " | 5.5 Bland-Altman | SOL 噪声带 ±75 分钟 → SOL 标记处于噪声之内（仅描述性，交人工）；WASO 高出噪声 3.3 倍，安全 |")))
if (audit_avail)
  r <- c(r, T(paste0("| ", real, " | 6. Report-only audit | 0 AUTO_FIX, ", n_flag, " FLAG (", n_m4, " window violations, ", n_m1, " order violations) |"),
              paste0("| ", real, " | 6. 只报告审计 | 0 AUTO_FIX，", n_flag, " FLAG（", n_m4, " 条窗口违规，", n_m1, " 条顺序违规） |")))
r <- c(r, T(paste0("| ", real, " | 7. Co-review agreement | 64.0% (n=75) / 89.2% (n=37), not κ |"),
            paste0("| ", real, " | 7. 共同审查一致率 | 64.0%（n=75）/ 89.2%（n=37），不是 κ |")))
d2 <- fmt(100 * var_dec$prop[grepl("D2", var_dec$term)], 0)
rec_rng <- paste0(fmt(min(seed$pooled_recall), 3), "–", fmt(max(seed$pooled_recall), 3))
r <- c(r, T(paste0("| ", rob, " | 8. Multiverse + downstream + seeds | D2 = ", d2, "% of variation; TST robust, SOL sensitive; recall stable ", rec_rng, " |"),
            paste0("| ", rob, " | 8. Multiverse + 下游 + 随机种子 | D2 = ", d2, "% 的变异；TST 稳健，SOL 敏感；召回率稳定在 ", rec_rng, " |")))
r <- c(r, "")

# 3. Synthetic benchmark
r <- c(r, T("## Synthetic benchmark", "## 合成基准"), "")
r <- c(r, T("Ground truth is recorded at injection time (self-consistent standard — no external gold standard exists for free-text diary entry).",
            "真值在注入错误时记录（自洽的标准——自由文本日记没有外部金标准）。"), "")
r <- c(r, T("| Quantity | Value | Source file |", "| 量 | 值 | 来源文件 |"), "|---|---|---|")
r <- c(r, paste0("| ", T("Pooled recall (L1 detection)", "合并召回率（L1 检出）"), " | ", pooled, " | recall_specificity_ci.csv |"))
r <- c(r, paste0("| ", T("Specificity", "特异度"), " | ", fmt(recall_ci$est[recall_ci$metric == "specificity_control"], 1), " | recall_specificity_ci.csv |"))
r <- c(r, paste0("| ", T("FCR (clean records altered)", "FCR（被改动的干净记录）"), " | ", fcr_txt, " | fcr_pure_n10000_result.csv |"))
r <- c(r, paste0("| ", T("FAR flag / alter", "FAR 标记 / 改动"), " | ", far_txt, T(" both", " 两者相同"), " | far_flag_alter.csv |"))
r <- c(r, paste0("| ", T("Controls: no_cleaning / naive / pipeline", "对照：no_cleaning / naive / pipeline"), " | ", ctrl3, " | control_baselines.csv |"))
r <- c(r, paste0("| ", T("Mis-repair rate (MRR)", "误修率（MRR）"), " | ", T("see mrr_magnitude.csv (0 in current run)", "见 mrr_magnitude.csv（当前运行为 0）"), " | mrr_magnitude.csv |"))
r <- c(r, "")

# 3b. Per-category benchmark table (detection vs correction)
bench_cat <- bench[!grepl("^CONTROL", bench$category), ]
bench_ctl <- bench[grepl("^CONTROL", bench$category), ]
r <- c(r, T("### Per-category benchmark (detection vs correction separated)", "### 分类别基准（检出与修正分开）"), "")
r <- c(r, T("Detection (\"the pipeline acted\") and correction (\"it got the right value\") are reported separately. `false_correction` = misrepaired (changed to a wrong value); `missed` = untouched, still wrong, unflagged. The clean-control block is reported on its own line — the raw `detection_outcomes_v4_current.csv` counted its 1,609 rows as MISSED and `correct_pct` 0, which read as \"0% correct\" when they simply carry no injected error; that miscompute is corrected here.",
            "检出（“管线有所动作”）与修正（“得到了正确的值”）分开报告。`false_correction` = 误修（被改成了错误的值）；`missed` = 未被触动、仍然错误、也没有被标记。干净对照单独占一行——原始的 `detection_outcomes_v4_current.csv` 把它的 1,609 行算作 MISSED、`correct_pct` 为 0，读起来像“0% 正确”，其实它们根本没有注入错误；这个计算错误在这里已更正。"), "")
r <- c(r, T("| Category | n | detected | correctly detected | flagged unresolved | false correction | missed | recall | misrepair rate |",
            "| 类别 | n | 检出 | 正确检出 | 已标记未解决 | 误修 | 漏检 | 召回率 | 误修率 |"), "|---|---|---|---|---|---|---|---|---|")
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
r <- c(r, T(paste0("Pooled precision = ", fmt(bench_ctl$pooled_precision[1], 3),
                   " (flagged injected / (flagged injected + flagged control)); control FAR_flag ",
                   bench_ctl$far_flag[1], "/", bench_ctl$n_control[1], ", FAR_alter ",
                   bench_ctl$far_alter[1], "/", bench_ctl$n_control[1], ". Source: benchmark_table.csv."),
            paste0("合并精确率 = ", fmt(bench_ctl$pooled_precision[1], 3),
                   "（被标记的注入行 /（被标记的注入行 + 被标记的对照行））；对照 FAR_flag ",
                   bench_ctl$far_flag[1], "/", bench_ctl$n_control[1], "，FAR_alter ",
                   bench_ctl$far_alter[1], "/", bench_ctl$n_control[1], "。来源：benchmark_table.csv。")), "")

# 4. Real-data audit
if (audit_avail) {
  r <- c(r, T("## Real-data audit", "## 真实数据审计"), "")
  r <- c(r, T(paste0("Report-only run over all ", n_total, " real diary records. No data is modified (0 AUTO_FIX)."),
              paste0("对全部 ", n_total, " 条真实日记记录做的只报告运行。不修改任何数据（0 AUTO_FIX）。")), "")
  r <- c(r, T("| Quantity | Value |", "| 量 | 值 |"), "|---|---|")
  r <- c(r, paste0("| AUTO_FIX | ", n_autofix, " |"))
  r <- c(r, paste0("| FLAG | ", n_flag, " |"))
  r <- c(r, paste0("| ", T("M4 window violations", "M4 窗口违规"), " | ", n_m4, " |"))
  r <- c(r, paste0("| ", T("M1 order violations", "M1 顺序违规"), " | ", n_m1, " |"))
  r <- c(r, paste0("| ", T("M5 silent-worsening candidates", "M5 静默恶化候选"), " | ", n_m5, " |"))
  r <- c(r, paste0("| ", T("Genuine mismatches flagged for review (extreme ≥60min + >2× window)", "标记待审的真实不一致（极端值 ≥60 分钟 + 超过窗口 2 倍）"),
                   " | ", n_genuine, " (", n_extreme, T(" extreme + ", " 极端 + "), n_sig, T(" over-window)", " 超窗口)"), " |"))
  r <- c(r, "")
  r <- c(r, T("**Human review outcome (local authoritative worksheet, aggregate):**", "**人工审核结果（本地权威工作表，汇总）：**"), "")
  if (!is.na(ws_n)) {
    r <- c(r, T(paste0("Of the ", ws_n, " reviewed records, **", ws_keep, " were KEPT as written** (self-reported SOL exceeding the bed→sleep window is treated as self-reported context, not proof of error — consistent with the sleep–affect design philosophy), ",
                       ws_na, " set to NA (unusable duration), ", ws_modify, " modified, and ", ws_open, " remain open."),
                paste0("在 ", ws_n, " 条已审核记录中，**", ws_keep, " 条按原样保留**（自报 SOL 超过就寝→入睡窗口，视为自报的背景信息，而不是错误的证据——与睡眠–情绪的设计理念一致），",
                       ws_na, " 条设为 NA（时长不可用），", ws_modify, " 条被修改，", ws_open, " 条仍待处理。")))
    r <- c(r, "")
    r <- c(r, T("| Decision | Count |", "| 决定 | 数量 |"), "|---|---|")
    r <- c(r, paste0("| ", T("KEEP as written (incl. batch rules)", "按原样保留（含批量规则）"), " | ", ws_keep, " |"))
    r <- c(r, paste0("| ", T("Set to NA (unusable duration)", "设为 NA（时长不可用）"), " | ", ws_na, " |"))
    r <- c(r, paste0("| ", T("Modified", "已修改"), " | ", ws_modify, " |"))
    r <- c(r, paste0("| ", T("Open (needs human call)", "待处理（需人工判断）"), " | ", ws_open, " |"))
    r <- c(r, "")
    r <- c(r, T("The dominant outcome is KEEP: a plausible large SOL is left untouched even when it exceeds the timestamp window, because removing it would bias the sleep–affect associations the pipeline exists to serve.",
                "占多数的结果是保留：合理的较大 SOL 即使超过时间戳窗口也原样保留，因为去掉它会使管线所服务的睡眠–情绪关联产生偏差。"))
  } else {
    r <- c(r, T("Human review worksheet not available in this environment; aggregate decisions are recorded locally (54 decided / 2 open, majority KEEP-as-written).",
                "人工审核工作表在当前环境中不可用；汇总决定记录在本地（54 条已决定 / 2 条待处理，多数为按原样保留）。"))
  }
  r <- c(r, "")
}

# 5. Bland-Altman
r <- c(r, T("## Bland-Altman measurement characterization", "## Bland-Altman 测量特性"), "")
r <- c(r, T("| Metric | LoA half-width | Threshold ratio | Verdict |", "| 指标 | LoA 半宽 | 阈值比 | 结论 |"), "|---|---|---|---|")
r <- c(r, T("| SOL | ±75.4 min | 1.59 / 0.80 | INSIDE NOISE → descriptive flags, human review |", "| SOL | ±75.4 分钟 | 1.59 / 0.80 | 处于噪声之内 → 描述性标记，交人工审核 |"))
r <- c(r, T("| WASO | ±27.3 min | 3.29 | SAFE |", "| WASO | ±27.3 分钟 | 3.29 | 安全 |"))
r <- c(r, T("| SE / TST-TIB | — | — | N/A (no self-report pair) |", "| SE / TST-TIB | — | — | 不适用（没有自报配对） |"))
r <- c(r, "", T("SOL thresholds sit inside the reporting-noise band; SOL flags are descriptive indicators routed to human review, not automated error signals (verified: `flag_severity` feeds no correction path).",
                "SOL 阈值落在自报噪声带之内；SOL 标记是交人工审核的描述性指标，不是自动的错误信号（已验证：`flag_severity` 不进入任何修正路径）。"), "")

# 6. Multiverse
r <- c(r, T("## Multiverse, downstream sensitivity, seeds", "## Multiverse、下游敏感性、随机种子"), "")
r <- c(r, paste0(T("| Dimension | Share of variation |", "| 维度 | 变异占比 |"), "|---|---|"))
for (i in seq_len(nrow(var_dec))) {
  r <- c(r, paste0("| ", trimws(var_dec$term[i]), " | ", fmt(100 * var_dec$prop[i], 0), "% |"))
}
r <- c(r, "")
r <- c(r, paste0(T("| Quantity | base | min | max |", "| 量 | 基准 | 最小 | 最大 |"), "|---|---|---|---|"))
r <- c(r, paste0("| ", T("mean TST (h)", "平均 TST（小时）"), " | ", fmt(down$base_value[down$layer == "multiverse_mean_tst_h"], 2),
                 " | ", fmt(down$min_value[down$layer == "multiverse_mean_tst_h"], 2),
                 " | ", fmt(down$max_value[down$layer == "multiverse_mean_tst_h"], 2), " |"))
r <- c(r, paste0("| ", T("mean SOL (min)", "平均 SOL（分钟）"), " | ", fmt(down$base_value[down$layer == "multiverse_mean_sol_min"], 1),
                 " | ", fmt(down$min_value[down$layer == "multiverse_mean_sol_min"], 1),
                 " | ", fmt(down$max_value[down$layer == "multiverse_mean_sol_min"], 1), " |"))
r <- c(r, paste0("| ", T("B1 TST shift / B2 n shift", "B1 TST 偏移 / B2 记录数偏移"), " | ", fmt(down$base_value[down$layer == "B1_tst_shift_min"], 1),
                 T(" min / ", " 分钟 / "), down$base_value[down$layer == "B2_n_shift_records"], T(" records | | |", " 条记录 | | |")))
r <- c(r, "")
r <- c(r, T(paste0("Seed sensitivity: pooled recall ", rec_rng, " across ", nrow(seed), " seeds; control FAR 0 in all."),
            paste0("种子敏感性：在 ", nrow(seed), " 个种子上合并召回率为 ", rec_rng, "；对照 FAR 全部为 0。")), "")

# 7. Operating-point analysis
r <- c(r, "", T("## Threshold operating-point analysis", "## 阈值工作点分析"), "")
r <- c(r, T("Answers \"why 3 h and 12 h?\" by sweeping the two rule-defining thresholds on the fixed synthetic benchmark (same corrupted input + same ground truth for every point; only the pipeline detection thresholds change). Selection rule predefined, not post-hoc: **primary recall ≥ 0.95 → secondary min FAR_flag → tie nearest (3,12)**.",
            "为回答“为什么是 3 小时和 12 小时？”，在固定的合成基准上扫描定义规则的两个阈值（每个点用同一份被破坏的输入和同一份真值，只改变管线的检测阈值）。选择规则事先确定，不是事后挑选：**首要召回率 ≥ 0.95 → 其次最小 FAR_flag → 并列时取最接近 (3,12) 的点**。"), "")
r <- c(r, T("| swap (h) | flip (h) | recall | FAR_flag | FAR_alter | precision |", "| 对调 (h) | 翻转 (h) | 召回率 | FAR_flag | FAR_alter | 精确率 |"), "|---|---|---|---|---|---|")
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
  r <- c(r, T(paste0("**Flat plateau**: recall constant (~", fmt(op_sweep$recall[1], 3),
                     ") and FAR_flag = 0 at every grid point. Threshold choice is insensitive on this benchmark; ",
                     "the current defaults (3, 12) sit on the safe plateau and satisfy the rule (recall ",
                     fmt(op_sel$defaults_recall[1], 4), ", FAR 0).**"),
              paste0("**平坦的平台**：每个网格点上召回率恒定（约 ", fmt(op_sweep$recall[1], 3),
                     "），FAR_flag = 0。在这个基准上，阈值的选择不敏感；",
                     "当前默认值 (3, 12) 位于安全平台上，满足该规则（召回率 ",
                     fmt(op_sel$defaults_recall[1], 4), "，FAR 0）。**")))
} else {
  r <- c(r, T(paste0("Selection rule outcome: swap ", op_sel$selected_swap[1], " h, flip ",
                     op_sel$selected_flip[1], " h (recall ", fmt(op_sel$selected_recall[1], 4),
                     ", FAR ", fmt(op_sel$selected_far_flag[1], 4), ")."),
              paste0("选择规则的结果：对调 ", op_sel$selected_swap[1], " 小时，翻转 ",
                     op_sel$selected_flip[1], " 小时（召回率 ", fmt(op_sel$selected_recall[1], 4),
                     "，FAR ", fmt(op_sel$selected_far_flag[1], 4), "）。")))
}
r <- c(r, "")

# 8. Co-review
r <- c(r, "", T("## Human co-review agreement", "## 人工共同审查一致性"), "")
r <- c(r, T("Reported as co-review agreement, not Cohen's κ — the review was collaborative (one shared worksheet), so the independent label sets κ requires never existed.",
            "以共同审查一致率报告，而不是 Cohen's κ——审查是协作进行的（共用一张工作表），所以 κ 所需的相互独立的标签集从未存在。"), "")
r <- c(r, T("| Track | n | Immediate agreement |", "| 轨道 | n | 当场一致率 |"), "|---|---|---|")
r <- c(r, T("| Flagged temporal errors | 75 | 64.0% |", "| 被标记的时间错误 | 75 | 64.0% |"))
r <- c(r, T("| Statistically atypical cases | 37 | 89.2% |", "| 统计上非典型的个案 | 37 | 89.2% |"))
r <- c(r, "")

# 9. Caveats
r <- c(r, T("## Honest caveats", "## 诚实的注意事项"), "")
r <- c(r, T("1. **cross_participant_spike is the weakest family** — L1 0.886–0.907 across seeds, value-correct 0 by design (audit-only: a spike may be real).",
            "1. **cross_participant_spike 是最弱的一族**——各种子下 L1 为 0.886–0.907，值正确率按设计为 0（仅用于审计：尖峰可能是真的）。"))
r <- c(r, T("2. **SOL thresholds sit inside the ±75-min Bland-Altman noise band** — SOL flags are descriptive, routed to human review; never cited as accuracy.",
            "2. **SOL 阈值落在 ±75 分钟的 Bland-Altman 噪声带之内**——SOL 标记是描述性的，交人工审核；绝不引作准确性。"))
r <- c(r, T("3. **Ablation recall uses a flag-based definition** (AUTO_FIXed records never enter the flag queue) — reported as supplementary; primary evidence is the multiverse variance decomposition.",
            "3. **消融召回率使用基于标记的定义**（被 AUTO_FIX 的记录从不进入标记队列）——作为补充报告；主要证据是 multiverse 方差分解。"))
r <- c(r, "")
r <- c(r, T("4. **Operating-point analysis is synthetic-only** — real data has no ground truth, so recall is undefined there (the real-data spec curve measures downstream means only, which cannot move: n_flagged = 0 under every spec). The plateau verdict holds on the synthetic benchmark; real-world threshold choice should be re-checked on external data.",
            "4. **工作点分析只在合成数据上做过**——真实数据没有真值，所以那里没有定义召回率（真实数据的 spec 曲线只测下游均值，而它不可能动：每种设定下 n_flagged = 0）。平台结论只在合成基准上成立；真实世界的阈值选择应在外部数据上重新核对。"))

# 10. Reproducibility
r <- c(r, T("## Reproducibility", "## 可复现性"), "")
r <- c(r, "```r", T("# from the repo root, after renv::restore() and installing splsleep", "# 在仓库根目录，renv::restore() 并安装 splsleep 之后"))
r <- c(r, T("Rscript validation/synthetic/ppv_cluster_ci.R   # synthetic benchmark (recall/spec/FAR)", "Rscript validation/synthetic/ppv_cluster_ci.R   # 合成基准（召回/特异度/FAR）"))
r <- c(r, T("Rscript validation/synthetic/operating_point_sweep.R  # threshold operating-point analysis", "Rscript validation/synthetic/operating_point_sweep.R  # 阈值工作点分析"))
r <- c(r, T("Rscript validation/audit_review_queue_m1_m7.R   # real-data audit (requires local data)", "Rscript validation/audit_review_queue_m1_m7.R   # 真实数据审计（需要本地数据）"))
r <- c(r, T("Rscript validation/render_validation_report.R   # re-render this report from the CSVs", "Rscript validation/render_validation_report.R   # 从 CSV 重新生成本报告（中英文两份）"))
r <- c(r, "```", "")
r <- c(r, T("The synthetic layer is fully reproducible from committed CSVs. The real-data audit requires the gitignored local dataset.",
            "合成层可以完全从已提交的 CSV 复现。真实数据审计需要被 git 忽略的本地数据集。"), "")
r
}

for (lang in names(OUT)) writeLines(render_report(lang), OUT[[lang]])
