# part_b_global_sweep.R — Part B: all-data silent-error sweep (B1–B4)
# =============================================================================
# Purpose: first systematic search for unknown-unknowns on the full real
# dataset (n=13,990), per 2026-08-14 meeting plan Part B.
#
#   B1 silent alteration  — raw ≠ corrected AND no correction_type AND no flag
#                           AND no correction note → silent change (a bug).
#   B2 redundant worsening — corrected |gap−self| > raw |gap−self| → the fix
#                           moved values away from self-report.
#   B3 note-type inventory — every unique _correctionsmade text vs the
#                           mechanism inventory (already produced by M7; this
#                           recomputes + lists uncovered per field).
#   B4 blind-spot extrapolation — error_catalog.yaml categories that are
#                           "theoretically possible" but have no pipeline guard.
#
# Outputs:
#   part_b_b1_silent_alteration.csv
#   part_b_b2_redundant_worsening.csv
#   part_b_b3_note_inventory.csv
#   part_b_b4_no_guard_categories.md
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
  library(yaml)
})

prepost <- readRDS("output/cleaned_data_prepostcorrection.rds")
full    <- readRDS("output/cleaned_data_full.rds")
stopifnot(nrow(prepost) == 13990, nrow(full) == 13990)

# ── B1: silent alteration ────────────────────────────────────────────────────
# Any row where raw timestamps differ from corrected AND no correction_type,
# no flag, no note was recorded → silent change.
t_cols <- c("bedtime","sleeponset","awakening","getup")
raw <- prepost[, paste0(t_cols, "_precorrection")]
cor <- prepost[, paste0(t_cols, "_postcorrection")]

# Compare as POSIXct (raw strings have tz suffix; both parse)
parse_ok <- function(x) {
  out <- as.POSIXct(x, tz = "UTC")
  out
}
raw_p <- as.data.frame(lapply(raw, parse_ok))
cor_p <- as.data.frame(lapply(cor, parse_ok))

# Elementwise diff in seconds (data.frames of POSIXct); NA rows -> 0 so they
# never count as "changed".
sec_diff <- Map(function(r, c) {
  d <- as.numeric(c - r, units = "secs")
  d[is.na(d)] <- 0
  d
}, raw_p, cor_p)
sec_diff <- as.data.frame(sec_diff)
both_known <- !is.na(raw_p) & !is.na(cor_p)
changed <- rowSums(both_known & abs(sec_diff) > 1) > 0
has_correction_marker <- !is.na(prepost$correction_type) &
  prepost$correction_type != "" & prepost$correction_type != "none"

# note marker: any correctionsmade non-NA/non-empty in full
note_cols <- grep("_correctionsmade$", names(full), value = TRUE)
note_marker <- rep(FALSE, nrow(full))
for (c in note_cols) note_marker <- note_marker | (!is.na(full[[c]]) & full[[c]] != "" & full[[c]] != "NA value")

# flag marker: any checkforerrors
flag_cols <- grep("_checkforerrors$", names(full), value = TRUE)
flag_marker <- rep(FALSE, nrow(full))
for (c in flag_cols) flag_marker <- flag_marker | (full[[c]] %in% TRUE)

# manual marker: human-review corrections leave manually_corrected == TRUE
manual_marker <- full$manually_corrected %in% TRUE

b1 <- changed & !has_correction_marker & !note_marker & !flag_marker & !manual_marker

b1_out <- data.frame(
  pid = prepost$pid, day_num = prepost$day_num, row_id = prepost$row_id,
  bedtime_pre = prepost$bedtime_precorrection,
  sleeponset_pre = prepost$sleeponset_precorrection,
  awakening_pre = prepost$awakening_precorrection,
  getup_pre = prepost$getup_precorrection,
  bedtime_post = prepost$bedtime_postcorrection,
  sleeponset_post = prepost$sleeponset_postcorrection,
  awakening_post = prepost$awakening_postcorrection,
  getup_post = prepost$getup_postcorrection
)[b1, ]
write.csv(b1_out, "part_b_b1_silent_alteration.csv", row.names = FALSE)

# ── B2: redundant worsening (Channel B logic, all data) ─────────────────────
# corrected |gap−self| > raw |gap−self| for the SOL-relevant bed→sleep gap.
sol_self <- prepost$sol_selfreport_minutes
raw_gap  <- as.numeric(difftime(raw_p$sleeponset, raw_p$bedtime, units = "mins"))
cor_gap  <- as.numeric(difftime(cor_p$sleeponset, cor_p$bedtime, units = "mins"))

ok <- !is.na(raw_gap) & !is.na(cor_gap) & !is.na(sol_self) & raw_gap != cor_gap
b2 <- rep(FALSE, nrow(prepost))
b2_shift <- rep(NA_real_, nrow(prepost))
b2[ok] <- abs(cor_gap[ok] - sol_self[ok]) > abs(raw_gap[ok] - sol_self[ok])
b2_shift[ok] <- abs(cor_gap[ok] - sol_self[ok]) - abs(raw_gap[ok] - sol_self[ok])

b2_out <- data.frame(
  pid = prepost$pid, day_num = prepost$day_num, row_id = prepost$row_id,
  sol_selfreport = sol_self,
  raw_gap_min = round(raw_gap, 1), cor_gap_min = round(cor_gap, 1),
  shift_min = round(b2_shift, 1),
  correction_type = prepost$correction_type
)[b2, ]
write.csv(b2_out, "part_b_b2_redundant_worsening.csv", row.names = FALSE)

# ── B3: note-type inventory (per field, uncovered) ──────────────────────────
mechanism_notes <- c(
  "decimal hours -> minutes",
  "minute field too long, manual check",
  "minute overflow normalized",
  "h/m padded",
  "dd:00 \u2192 00:dd",
  "5+ digits, manual check",
  "dddd",
  "000",
  "3 digits, manual check",
  "00",
  "dd, min assumed",
  "converted 0 to 00:00",
  "d, min assumed",
  "other unhandled case",
  "d:d:dd",
  ":d/:dd -> 00:dd",
  "00:000 -> 00:00",
  "000:dd -> 00:dd",
  "colon but wrong format",
  "sleep metric duration MM:SS threshold conversion",
  "field_misentry"
)

note_rows <- lapply(note_cols, function(col) {
  v <- full[[col]]
  v <- v[!is.na(v) & v != "" & v != "NA value"]
  data.frame(field = col, note = v, stringsAsFactors = FALSE)
}) %>% bind_rows()

covered_note <- function(x) {
  vapply(x, function(s) {
    parts <- strsplit(s, "; ", fixed = TRUE)[[1]]
    all(parts %in% mechanism_notes) | any(grepl("Manual fix|retained", s))
  }, logical(1))
}
note_rows$covered <- covered_note(note_rows$note)
b3_out <- note_rows
write.csv(b3_out, "part_b_b3_note_inventory.csv", row.names = FALSE)

# ── B4: blind-spot extrapolation from error_catalog.yaml ────────────────────
# read_yaml chokes on a UTF-8 byte in this file; readLines + yaml.load works.
cat_txt <- readLines("validation/synthetic/error_catalog.yaml", warn = FALSE, encoding = "UTF-8")
cat_yml <- yaml::yaml.load(paste(cat_txt, collapse = "\n"))
cat_names <- setdiff(names(cat_yml$categories), "no_error_control")

# Map each catalog category to the pipeline guard that should catch it.
# "guard" = the mechanism name in code; NA = no dedicated guard found.
catalog_guards <- list(
  ampm_swap                = "step 4 flip_gap_hours (12h AM/PM flip)",
  adjacent_swap_bed_sleep  = "step 4 bed_sleep_swap_3h (swap_threshold_hours)",
  adjacent_swap_sleep_awake = "step 4 sleep_awake_swap_3h + bed<=awake guard",
  adjacent_swap_awake_getup = "step 4 awake_getup_swap_3h (swap_threshold_hours)",
  field_misentry_sol       = "step 1.5 field_misentry_check (A4)",
  field_misentry_waso      = "step 1.5 field_misentry_check (A4)",
  format_no_colon          = "interval_parse format normalization",
  format_malformed_colon   = "interval_parse malformed-colon handling",
  mmss_confusion           = "interval_parse MM:SS threshold conversion",
  cross_participant_spike  = "step 8.5 cross_participant_global_check",
  implausible_duration     = "interval_parse structural_flag + classification thresholds",
  compound_ampm_and_swap   = "step 4 flip + swap chain"
)

b4_lines <- c("# B4: blind-spot extrapolation — catalog categories vs pipeline guards",
              "",
              "| catalog category | provenance | pipeline guard | guarded? |",
              "|---|---|---|---|")
for (nm in cat_names) {
  prov <- paste(cat_yml$categories[[nm]]$provenance, collapse = ",")
  g <- catalog_guards[[nm]]
  if (is.null(g) || g == "") g <- "**NO DEDICATED GUARD**"
  guarded <- ifelse(grepl("NO DEDICATED", g), "❌", "✅")
  b4_lines <- c(b4_lines,
    sprintf("| %s | %s | %s | %s |", nm, prov, g, guarded))
}
b4_lines <- c(b4_lines, "",
  "Note: adjacent_swap_sleep_awake guard = 2026-08-13 `bed <= awake` (commit 606a0e0).",
  "field_misentry guard = 2026-06-18 Step 1.5 (A4), residual 3.5% '01:XX' known.",
  "Categories are ENRICHED in the benchmark (400/category) — detection coverage",
  "is measured in validation/synthetic/results/, not re-derived here.")
writeLines(b4_lines, "part_b_b4_no_guard_categories.md")

# ── Summary ─────────────────────────────────────────────────────────────────
cat("\n=== Part B: global silent-error sweep ===\n")
cat("B1 silent alteration rows:", sum(b1), "\n")
cat("B2 redundant worsening rows:", sum(b2), "\n")
cat("B3 note rows:", nrow(b3_out), " uncovered:", sum(!b3_out$covered),
    " unique uncovered:", length(unique(b3_out$note[!b3_out$covered])), "\n")
cat("B4 catalog categories:", length(cat_names), " (see part_b_b4_no_guard_categories.md)\n")
if (sum(b1) > 0) {
  cat("\nB1 rows (first 10):\n")
  print(head(b1_out[, c("pid","day_num")]))
}
cat("\n=== [part_b_global_sweep] Finished ===\n")
