# evaluate_detection.R
#
# Per-injected-error outcome evaluator, v4.
#
# v1 used needs_review_flag alone -> conflated "never touched" with "silently
# auto-fixed correctly" (bed/sleep swap, awake/getup swap, format_no_colon,
# format_malformed_colon all looked like 0% detection when several were
# actually near-100% silently correct).
#
# v2 added a "was_corrected" signal via as.numeric(raw_corrupted_string) !=
# mincalc. That signal is BROKEN for any category whose corrupted string
# contains a colon that as.numeric() can't parse (field_misentry_sol/waso's
# corrupted_value is a clock time like "10:51"; mmss_confusion's is "18:00")
# -- as.numeric() on those returns NA, which v2 silently defaulted to FALSE
# ("not corrected"), so v2's MISSED counts for exactly those two categories
# were partly an artifact of the parser, not a real finding.
#
# v3 fixed that by using ground_truth.csv's own original_value/true_value
# columns directly instead of re-deriving them from the corrupted string, but
# only handled SINGLE-field ground truth rows. adjacent_swap_* and
# compound_ampm_and_swap log a PIPE-JOINED multi-field "field" /"true_value"
# (inject_adjacent_swap/inject_compound touch 4-5 columns per injected error
# at once), which fell through to a flag-only fallback in v3 -- those three
# categories' CORRECT/MISREPAIRED breakdown was reported as "not yet
# measured".
#
# v4 adds a general multi-field parser (see resolve_multifield_prefixes()
# below) that handles both the single-field case (delegates to the same
# logic as v3) and the pipe-joined multi-field case, INCLUDING the case
# where inject_compound()'s ampm-flip and swap steps touch the SAME column
# (e.g. ampm_field happens to equal one member of the swap pair) -- when
# that happens the field list contains the same column name twice with two
# DIFFERENT true_values (one from each corruption step), and only the FIRST
# occurrence is the fully-reverted (pre-any-corruption) target; the second
# is an intermediate state from undoing only the later step. Verified this
# by hand-tracing one real compound row (row_id 10, ampm_field=time_sleep_am
# overlapping pair=(time_bed_am,time_sleep_am)) against the injector source
# before trusting match()'s first-occurrence-wins behavior for the general
# case.
#
# Outcome per injected error:
#   CORRECT        -- final derived value matches ground-truth true_value,
#                      for EVERY timestamp/field touched by this injection
#   MISREPAIRED    -- final value changed from the corrupted input, but does
#                     NOT match true_value (this is the real MRR signal)
#   FLAGGED_UNRESOLVED -- flagged for human review, value not yet corrected
#   MISSED         -- neither flagged nor corrected, value still wrong
#
# Usage: Rscript evaluate_detection.R <ground_truth_csv> <raw_rds> <review_output_rds> <corrected_rds> <out_csv>

args <- commandArgs(trailingOnly = TRUE)
gt        <- read.csv(args[1], stringsAsFactors = FALSE)
raw       <- readRDS(args[2])   # the CORRUPTED input actually fed to the pipeline
review    <- readRDS(args[3])
corrected <- readRDS(args[4])
out_csv   <- args[5]

d <- review$data_with_flags

to24 <- function(hhmm, ampm) {
  parts <- strsplit(hhmm, ":"); h <- as.integer(sapply(parts, `[`, 1)); mn <- as.integer(sapply(parts, `[`, 2))
  h24 <- ifelse(ampm == "PM" & h != 12, h + 12, ifelse(ampm == "AM" & h == 12, 0, h))
  sprintf("%02d:%02d", h24, mn)
}

DURATION_FIELDS <- c("duration_totalmin_sol_estimate_am", "duration_totalmin_waso_estimate_am")
TS_HHMM_TO_CORRECTED <- c(
  time_bed_am_hhmm   = "time_bed_corrected",   time_bed_am_ampm   = "time_bed_corrected",
  time_sleep_am_hhmm = "time_sleep_corrected", time_sleep_am_ampm = "time_sleep_corrected",
  time_awake_am_hhmm = "time_awake_corrected", time_awake_am_ampm = "time_awake_corrected",
  time_getup_am_hhmm = "time_getup_corrected", time_getup_am_ampm = "time_getup_corrected"
)
FIELD_TO_RAW_HHMM <- c(time_bed_am_ampm="time_bed_am_hhmm", time_sleep_am_ampm="time_sleep_am_hhmm",
                        time_awake_am_ampm="time_awake_am_hhmm", time_getup_am_ampm="time_getup_am_hhmm",
                        time_bed_am_hhmm="time_bed_am_ampm", time_sleep_am_hhmm="time_sleep_am_ampm",
                        time_awake_am_hhmm="time_awake_am_ampm", time_getup_am_hhmm="time_getup_am_ampm")

# Resolve a (possibly pipe-joined, possibly duplicated) field/true_value pair
# into one entry per distinct TIMESTAMP PREFIX touched (e.g. "time_bed_am"),
# each carrying the fully-reverted target hhmm+ampm and which *_corrected
# column in `corrected` to check it against. Non-timestamp (duration) field
# strings are returned as-is via the `duration` element for the caller to
# handle separately -- a ground-truth row is either all-duration or
# all-timestamp fields in this catalog, never mixed.
resolve_multifield <- function(field_str, true_str, rraw) {
  fields <- strsplit(field_str, "\\|")[[1]]
  trues  <- strsplit(true_str,  "\\|")[[1]]

  if (length(fields) == 1 && fields[1] %in% DURATION_FIELDS) {
    return(list(duration_field = fields[1], duration_true = trues[1], timestamps = list()))
  }

  ts_fields <- fields[fields %in% names(TS_HHMM_TO_CORRECTED)]
  prefixes <- unique(sub("_(hhmm|ampm)$", "", ts_fields))
  out <- list()
  for (p in prefixes) {
    hf <- paste0(p, "_hhmm"); af <- paste0(p, "_ampm")
    # match() returns the FIRST occurrence -- for compound rows where the
    # ampm-flip and swap steps touch the same column, the first-listed entry
    # (always the ampm-flip's pre-corruption capture, per inject_compound's
    # gt_add() argument order) is the fully-reverted target; a later
    # duplicate is only an intermediate undo-the-swap-alone state. See header
    # comment for the hand-traced example this was verified against.
    hi <- match(hf, fields); ai <- match(af, fields)
    true_hhmm <- if (!is.na(hi)) trues[hi] else rraw[[hf]]   # untouched component: already correct in raw
    true_ampm <- if (!is.na(ai)) trues[ai] else rraw[[af]]
    out[[p]] <- list(true_hhmm = true_hhmm, true_ampm = true_ampm,
                      corrected_col = TS_HHMM_TO_CORRECTED[[hf]],
                      raw_hhmm_col = hf, raw_ampm_col = af)
  }
  list(duration_field = NA_character_, duration_true = NA_character_, timestamps = out)
}

gt$outcome <- NA_character_
gt$needs_review_flag <- d$needs_review_flag[match(gt$row_id, d$row_id)]
gt$needs_review_flag[is.na(gt$needs_review_flag)] <- FALSE

for (i in seq_len(nrow(gt))) {
  rid <- gt$row_id[i]; field <- gt$field[i]
  if (is.na(field) || !nzchar(field)) { gt$outcome[i] <- if (gt$needs_review_flag[i]) "FLAGGED_UNRESOLVED" else "MISSED"; next }

  rraw <- raw[raw$row_id == rid, , drop = FALSE]
  rcor <- corrected[corrected$row_id == rid, , drop = FALSE]
  if (nrow(rraw) != 1 || nrow(rcor) != 1) { gt$outcome[i] <- "NO_MATCH"; next }

  parsed <- resolve_multifield(field, gt$true_value[i], rraw)

  if (!is.na(parsed$duration_field)) {
    mincalc_col <- paste0(parsed$duration_field, "_mincalc")
    got <- round(suppressWarnings(as.numeric(rcor[[mincalc_col]])))
    want <- round(suppressWarnings(as.numeric(parsed$duration_true)))
    was_orig <- round(suppressWarnings(as.numeric(gt$original_value[i])))
    correct <- !is.na(got) && !is.na(want) && got == want
    changed_from_corrupted <- !is.na(got) && got != was_orig
  } else if (length(parsed$timestamps) > 0) {
    correct <- TRUE
    changed_from_corrupted <- FALSE
    for (p in parsed$timestamps) {
      got_hm  <- format(as.POSIXct(rcor[[p$corrected_col]]), "%H:%M")
      want_hm <- to24(p$true_hhmm, p$true_ampm)
      corrupted_hm <- to24(rraw[[p$raw_hhmm_col]], rraw[[p$raw_ampm_col]])
      if (is.na(got_hm) || is.na(want_hm) || got_hm != want_hm) correct <- FALSE
      if (!is.na(got_hm) && !is.na(corrupted_hm) && got_hm != corrupted_hm) changed_from_corrupted <- TRUE
    }
  } else {
    gt$outcome[i] <- if (gt$needs_review_flag[i]) "FLAGGED_UNRESOLVED" else "MISSED"; next
  }

  if (isTRUE(correct)) {
    gt$outcome[i] <- "CORRECT"
  } else if (gt$needs_review_flag[i]) {
    gt$outcome[i] <- "FLAGGED_UNRESOLVED"
  } else if (isTRUE(changed_from_corrupted)) {
    gt$outcome[i] <- "MISREPAIRED"
  } else {
    gt$outcome[i] <- "MISSED"
  }
}

outcome_tbl <- table(gt$error_type, gt$outcome)
outcome_df <- as.data.frame.matrix(outcome_tbl)
for (col in c("CORRECT","FLAGGED_UNRESOLVED","MISREPAIRED","MISSED","NO_MATCH")) {
  if (!col %in% names(outcome_df)) outcome_df[[col]] <- 0L
}
outcome_df$category <- rownames(outcome_df)
outcome_df$n <- rowSums(outcome_df[, c("CORRECT","FLAGGED_UNRESOLVED","MISREPAIRED","MISSED","NO_MATCH")])
outcome_df$correct_pct <- round(100 * outcome_df$CORRECT / outcome_df$n, 1)
outcome_df <- outcome_df[, c("category","n","CORRECT","FLAGGED_UNRESOLVED","MISREPAIRED","MISSED","NO_MATCH","correct_pct")]
rownames(outcome_df) <- NULL

write.csv(outcome_df, out_csv, row.names = FALSE)

cat("\n=== Per-category outcome, v4 (ground-truth true_value comparison, multi-field aware) ===\n")
print(outcome_df[order(outcome_df$category), ], row.names = FALSE)

cat("\nCORRECT = final derived value verified equal to ground-truth true_value.\n")
cat("FLAGGED_UNRESOLVED = surfaced for human review, not yet auto-corrected to truth.\n")
cat("MISREPAIRED = pipeline changed it, but to something other than the true value (real MRR).\n")
cat("MISSED = untouched, still wrong, no flag.\n")

# --- FAR_alter / FAR_flag on no_error_control subset, in-context ----------
ctrl <- gt[gt$error_type == "no_error_control", ]
cat(sprintf("\n=== In-context no_error_control check (n=%d) ===\n", nrow(ctrl)))
cat(sprintf("FAR_flag = %d/%d = %.2f%%\n", sum(ctrl$needs_review_flag), nrow(ctrl), 100*mean(ctrl$needs_review_flag)))
