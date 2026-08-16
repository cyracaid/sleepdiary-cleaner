# multiverse.R — 5.4: multiverse analysis (OAT screening -> full factorial)
# =============================================================================
# Design (validation/benchmark_design.md §9, meeting D6):
#   Phase 1 OAT screening: baseline spec, then vary each dimension one at a
#     time to its min/max level. Keep dimensions whose downstream quantities
#     move materially (|Δmean TST| >= 5 min or |Δanalyzable n| >= 1%).
#   Phase 2 full factorial: 3^K on the surviving dimensions (K<=5 -> 243).
#   Output contract: specification curve + downstream distributions + record
#     classification instability + variance decomposition.
#
# Dimensions (all config-driven; default level = current config_default):
#   D1 flip_gap_hours          (timestamp.sequence.max_gap_hours)    12
#   D2 swap_threshold_hours    (normalize.swap_threshold_hours)       3
#   D3 sol_excessive_minutes   (classification.metric_validation.sol
#                                .excessive_minutes)                120
#   D4 poor_efficiency_pct     (classification.flag_severity
#                                .poor_efficiency_threshold_pct)     70
#   D5 waso_excessive_hours    (classification.metric_validation.waso
#                                .excessive_hours)                   1.5
#   D6 tst_tib_ratio_min       (classification.metric_validation.tst_tib_ratio
#                                .min_ratio)                         0.5
#
# Levels (literature/physiology anchored where possible, see THRESHOLDS.md):
#   D1: 11 / 12 / 13
#   D2:  1 /  3 /  6
#   D3: 90 / 120 / 180
#   D4: 60 /  70 /  80
#   D5: 1.0 / 1.5 / 2.0
#   D6: 0.4 / 0.5 / 0.6
#
# Outputs (validation/synthetic/results/multiverse/):
#   oat_screening.csv          — OAT phase: downstream qty per spec
#   spec_curve.csv             — full factorial: downstream qty per spec
#   instability.csv            — record-level status flips across specs
#   variance_decomposition.csv — contribution of each dimension
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(yaml)
})

SYN <- "validation/synthetic"
RES <- file.path(SYN, "results", "multiverse")
dir.create(RES, showWarnings = FALSE, recursive = TRUE)

source(file.path(SYN, "spec_cache.R"))
corr_rds <- file.path(SYN, "corrupted_enrichment.rds")
stopifnot(file.exists(corr_rds))

# ── Dimension definitions ───────────────────────────────────────────────────
dims <- list(
  D1 = list(key = "timestamp.sequence.max_gap_hours",            levels = c(11, 12, 13), default = 12),
  D2 = list(key = "normalize.swap_threshold_hours",              levels = c(1, 3, 6),    default = 3),
  D3 = list(key = "classification.metric_validation.sol.excessive_minutes", levels = c(90, 120, 180), default = 120),
  D4 = list(key = "classification.flag_severity.poor_efficiency_threshold_pct", levels = c(60, 70, 80), default = 70),
  D5 = list(key = "classification.metric_validation.waso.excessive_hours",   levels = c(1.0, 1.5, 2.0), default = 1.5),
  D6 = list(key = "classification.metric_validation.tst_tib_ratio.min_ratio", levels = c(0.4, 0.5, 0.6), default = 0.5)
)

# ── Downstream quantities per spec (cached via spec_cache.R) ────────────────
# run_spec maps a summary (from run_spec_once) to the spec_curve data.frame
# row. Instability stage needs the per-spec category table, carried in the
# summary's cat_table.
# overrides uses DIM names (D1..D6); translate to config keys for spec_cache.
dim_overrides <- function(ov) {
  out <- list()
  for (nm in names(ov)) out[[dims[[nm]]$key]] <- ov[[nm]]
  out
}
run_spec <- function(overrides, label) {
  s <- run_spec_once(label, dim_overrides(overrides))
  if (is.null(s)) return(NULL)
  data.frame(
    spec = label,
    mean_tst_h = s$mean_tst_h,
    mean_sol_min = s$mean_sol_min,
    mean_se_pct = s$mean_se_pct,
    analyzable_n = s$analyzable_n,
    n_total = s$n_total,
    n_error = s$n_error,
    n_unusual = s$n_unusual,
    n_flagged = s$n_flagged,
    status_flip_from_base = NA_character_,
    stringsAsFactors = FALSE
  )
}

# ── Phase 1: OAT screening ──────────────────────────────────────────────────
cat("\n=== Multiverse Phase 1: OAT screening ===\n")
base_overrides <- list()
for (nm in names(dims)) base_overrides[[nm]] <- dims[[nm]]$default
base_row <- run_spec(base_overrides, "BASE")
stopifnot(!is.null(base_row))

oat <- base_row
for (nm in names(dims)) {
  for (lv in setdiff(dims[[nm]]$levels, dims[[nm]]$default)) {
    ov <- base_overrides; ov[[nm]] <- lv
    r <- run_spec(ov, paste0(nm, "=", lv))
    if (!is.null(r)) oat <- rbind(oat, r)
    cat("  done", nm, "=", lv, "\n")
  }
}
write.csv(oat, file.path(RES, "oat_screening.csv"), row.names = FALSE)

# surviving dims: |Δmean TST| >= 5 min OR |Δanalyzable n| >= 1% OR
# |Δn_flagged| >= 1% (flag thresholds D3-D6 act on classification, not values)
keep <- names(dims)
for (nm in names(dims)) {
  rows <- oat[grepl(paste0("^", nm, "="), oat$spec), ]
  if (nrow(rows) == 0) next
  d_tst <- max(abs(rows$mean_tst_h - base_row$mean_tst_h), na.rm = TRUE) * 60
  d_n   <- max(abs(rows$analyzable_n - base_row$analyzable_n), na.rm = TRUE) / base_row$analyzable_n * 100
  d_fl  <- max(abs(rows$n_flagged - base_row$n_flagged), na.rm = TRUE) / max(base_row$n_flagged, 1) * 100
  if (d_tst < 5 && d_n < 1 && d_fl < 1) keep <- setdiff(keep, nm)
}
cat("Surviving dimensions:", paste(keep, collapse = ", "), "\n")
if (length(keep) == 0) keep <- "D2"  # never collapse to nothing

# ── Phase 2: full factorial on survivors ────────────────────────────────────
cat("\n=== Multiverse Phase 2: full factorial ===\n")
levs <- lapply(keep, function(nm) dims[[nm]]$levels)
names(levs) <- keep
grid <- expand.grid(levs, stringsAsFactors = FALSE)
cat("Factorial specs:", nrow(grid), "\n")

results <- list()
for (i in seq_len(nrow(grid))) {
  ov <- base_overrides
  for (nm in keep) ov[[nm]] <- grid[i, nm]
  lab <- paste(paste0(keep, "=", unlist(grid[i, keep])), collapse = "_")
  r <- run_spec(ov, lab)
  if (!is.null(r)) results[[lab]] <- r
  if (i %% 25 == 0) cat("  ", i, "/", nrow(grid), "\n")
}
spec_curve <- do.call(rbind, results)
write.csv(spec_curve, file.path(RES, "spec_curve.csv"), row.names = FALSE)

cat("\n=== Specification curve (mean TST h) ===\n")
print(summary(spec_curve$mean_tst_h))
cat("Analyzable n range:", range(spec_curve$analyzable_n, na.rm = TRUE), "\n")

# ── Record-level classification instability ─────────────────────────────────
# Rerun BASE + extremes on the full set, compare data_category per record.
# (Lightweight version: BASE vs D2-min vs D2-max + D4-min.)
inst <- data.frame()
for (ov_lab in c("BASE", "D2=1", "D2=6", "D4=60", "D4=80")) {
  ov <- base_overrides
  if (grepl("D2", ov_lab)) ov[["D2"]] <- as.numeric(sub("D2=", "", ov_lab))
  if (grepl("D4", ov_lab)) ov[["D4"]] <- as.numeric(sub("D4=", "", ov_lab))
  s <- run_spec_once(ov_lab, dim_overrides(ov))
  if (is.null(s)) next
  ct <- s$cat_table
  inst <- rbind(inst, data.frame(spec = ov_lab, cat = as.character(ct$cat),
                                 n = ct$Freq, stringsAsFactors = FALSE))
}
if (nrow(inst) > 0) {
  tab <- table(inst$spec, inst$cat)
  inst_df <- as.data.frame.matrix(tab)
  inst_df$spec <- rownames(inst_df)
  write.csv(inst_df, file.path(RES, "instability.csv"), row.names = FALSE)
  cat("\n=== Record classification by spec ===\n")
  print(inst_df)
}

# ── Variance decomposition (ANOVA-like on mean TST) ─────────────────────────
vd <- spec_curve %>%
  tidyr::separate(spec, into = paste0("D", seq_along(keep)), sep = "_", remove = FALSE) %>%
  mutate(across(starts_with("D"), ~ suppressWarnings(as.numeric(sub(".*=", "", .)))))
if (length(keep) >= 1 && nrow(vd) > 1) {
  fml <- as.formula(paste("mean_tst_h ~", paste(keep, collapse = " + ")))
  fit <- tryCatch(aov(fml, data = vd), error = function(e) NULL)
  if (!is.null(fit)) {
    s <- summary(fit)[[1]]
    vd_out <- data.frame(
      term = rownames(s), df = s$Df, sum_sq = s$`Sum Sq`,
      prop = s$`Sum Sq` / sum(s$`Sum Sq`)
    )
    write.csv(vd_out, file.path(RES, "variance_decomposition.csv"), row.names = FALSE)
    cat("\n=== Variance decomposition (mean TST) ===\n")
    print(vd_out)
  }
}

cat("\n=== [multiverse] Finished ===\n")
