# l2_tier_leave_one_out.R — 5.2 L2 tier + 5.6 leave-one-out ablation
# =============================================================================
# L2 (type-correct) tier: per injected error, did the pipeline identify the
# ERROR TYPE correctly, not just flag the record? Uses the 5.1 enrichment
# run (cluster_bootstrap_per_row.csv + ground_truth) and the pipeline's
# correction_type / flag details.
#
# Mapping injected catalog category -> expected pipeline signal:
#   ampm_swap                 -> getup_reduce_12h_loop / sleep_reduce_12h_loop
#   adjacent_swap_bed_sleep   -> bed_sleep_swap_3h
#   adjacent_swap_sleep_awake -> sleep_awake_swap_3h
#   adjacent_swap_awake_getup -> awake_getup_swap_3h
#   field_misentry_sol/waso   -> field_misentry (Step 1.5)
#   format_no_colon           -> interval_parse format normalization
#   format_malformed_colon    -> interval_parse malformed-colon
#   mmss_confusion            -> MM:SS threshold conversion
#   implausible_duration      -> DURATION_ISSUE structural flag
#   cross_participant_spike   -> [CrossParticipant]
#   compound_ampm_and_swap    -> both ampm + swap signals
#
# L2 = flagged AND the pipeline signal matches the expected type.
#
# Leave-one-out ablation (5.6): remove each rule group one at a time,
# measure recall + workload change. Implemented as a config-level ablation:
# the groups here are the config-driven dimensions from 5.4; turning a
# threshold to an extreme value approximates removing the rule.
#
# Outputs (validation/synthetic/results/):
#   l2_tier.csv        — per-category L1/L2/L3 rates
#   leave_one_out.csv  — recall/workload per ablated group
# =============================================================================

suppressPackageStartupMessages(library(dplyr))

SYN <- "validation/synthetic"
RES <- file.path(SYN, "results")

gt <- read.csv(file.path(SYN, "ground_truth_enrichment.csv"), stringsAsFactors = FALSE)
per <- read.csv(file.path(RES, "cluster_bootstrap_per_row.csv"), stringsAsFactors = FALSE)
corr <- readRDS(file.path(SYN, "run_ppv", "corrected_ema_data.rds"))
review <- readRDS(file.path(SYN, "run_ppv", "review_output.rds"))
d <- review$data_with_flags

# ── L2: expected signal mapping ─────────────────────────────────────────────
# Signal strings verified from review_output$data_with_flags auto_error_desc
# prefixes + corrected_ema_data correction_type on the actual 5.1 run:
#   correction_type bed_sleep_swap_3h / sleep_awake_swap_3h /
#     awake_getup_swap_3h / *_reduce_12h_loop   -> adjacent/ampm swaps
#   [Temporal] order_error       -> adjacent swaps, ampm flip violations
#   [DurationReinterp]           -> field_misentry + mmss_confusion
#   [Interval] *_checkforerrors  -> implausible_duration / format structural
#   [CrossParticipant]           -> cross_participant_spike
#   format rows leave NO correction_type and NO desc (silently reformatted by
#     interval_parse) -> their only trace is a *_correctionsmade note; match
#     the note text ("dd:00", "padded", "colon") as the type signal.
expected_signal <- c(
  adjacent_swap_time_bed_am_time_sleep_am = "bed_sleep_swap_3h|Temporal",
  adjacent_swap_time_sleep_am_time_awake_am = "sleep_awake_swap_3h|Temporal",
  adjacent_swap_time_awake_am_time_getup_am = "awake_getup_swap_3h|Temporal",
  ampm_swap = "reduce_12h_loop|Temporal",
  field_misentry_sol = "DurationReinterp",
  field_misentry_waso = "DurationReinterp",
  format_no_colon = "padded|00:00|dd:00|Interval|min assumed|digits",
  format_malformed_colon = "colon|dd:00|00:00|Interval|min assumed|valid minutes|00dd|all zeros",
  mmss_confusion = "DurationReinterp",
  implausible_duration = "Interval",
  cross_participant_spike = "CrossParticipant",
  compound_ampm_and_swap = "reduce_12h_loop|swap_3h|Temporal",
  adjacent_swap_large_gap_left_clean = "Temporal|swap|bed_to_sleep|order",
  sol_window_contradiction = "bed_to_sleep|exceeds_sleep|exceeds|Interval"
)

# Pipeline signal per row: correction_type (corrected) + auto_error_desc and
# checkforerrors flags (review data_with_flags) + correctionsmade notes
d <- review$data_with_flags
note_cols <- grep("_correctionsmade$", names(corr), value = TRUE)
signal_text <- function(rid) {
  i <- which(d$row_id == rid)
  j <- which(corr$row_id == rid)
  if (length(i) != 1) return("")
  parts <- c(
    if (length(j) == 1) corr$correction_type[j] else NA,
    d$auto_error_desc[i],
    if (length(j) == 1) unlist(lapply(note_cols, function(c) corr[[c]][j])) else NULL,
    unlist(lapply(grep("_checkforerrors$", names(d), value = TRUE),
                  function(c) if (isTRUE(d[[c]][i])) c else NULL))
  )
  parts <- parts[!is.na(parts) & parts != ""]
  paste(unique(parts), collapse = " | ")
}

l2 <- per[per$error_type != "no_error_control", ]
l2$signal <- vapply(l2$row_id, signal_text, character(1))
l2$expected <- expected_signal[l2$error_type]
l2$type_correct <- mapply(function(sig, exp) {
  if (is.na(exp) || exp == "") return(NA)
  grepl(exp, sig, ignore.case = TRUE)
}, l2$signal, l2$expected)
l2$type_correct[is.na(l2$type_correct)] <- FALSE

l2_df <- l2 %>%
  group_by(error_type) %>%
  summarise(
    n = n(),
    L1_detected = mean(detected),
    L2_type_correct = mean(type_correct),
    L3_value_correct = mean(value_correct),
    .groups = "drop"
  ) %>% as.data.frame()

cat("\n=== L1/L2/L3 tier rates (per category) ===\n")
print(l2_df, row.names = FALSE)
cat(sprintf("\nPooled: L1 %.3f, L2 %.3f, L3 %.3f\n",
            mean(l2$detected), mean(l2$type_correct), mean(l2$value_correct)))

write.csv(l2_df, file.path(RES, "l2_tier.csv"), row.names = FALSE)

# ── Leave-one-out ablation (5.6) ────────────────────────────────────────────
# Config-level: set one dimension to an extreme ("off") and measure pooled
# recall + workload (rows entering human review = flagged) on the benchmark.
# Baseline = 5.1 pipeline run outcomes.
#
# Determinism: each spec runs through spec_cache.R (run_spec_once), which
# keys on sha256(input rds + config + overrides). Re-running this script with
# unchanged input/config reuses cached summaries -> leave_one_out.csv is
# stable. Regenerating corrupted_enrichment.rds invalidates the cache and
# forces real re-execution (issue #6 root cause: the input rds is
# .gitignore'd and was regenerated after these CSVs were produced).
suppressPackageStartupMessages(library(yaml))
source(file.path(SYN, "spec_cache.R"))

run_ablation <- function(overrides, label) {
  s <- run_spec_once(label, overrides)
  if (is.null(s)) return(NULL)
  n_inj  <- sum(gt$error_type != "no_error_control")
  n_ctrl <- sum(gt$error_type == "no_error_control")
  data.frame(group = label,
             recall_flag = s$flagged_injected / n_inj,
             workload_flag = s$flagged_injected,
             control_flag_rate = s$flagged_control / n_ctrl,
             stringsAsFactors = FALSE)
}

abl <- rbind(
  run_ablation(list(), "baseline"),
  run_ablation(list("normalize.swap_threshold_hours" = 0.01), "D2_swap_off"),
  run_ablation(list("timestamp.sequence.max_gap_hours" = 99), "D1_flip_off"),
  run_ablation(list("classification.metric_validation.sol.excessive_minutes" = 100000), "D3_sol_excessive_off"),
  run_ablation(list("classification.flag_severity.poor_efficiency_threshold_pct" = -1), "D4_poor_se_off")
)
cat("\n=== Leave-one-out ablation (recall/workload) ===\n")
print(abl, row.names = FALSE)
write.csv(abl, file.path(RES, "leave_one_out.csv"), row.names = FALSE)
cat("\n=== [l2_tier_leave_one_out] Finished ===\n")
