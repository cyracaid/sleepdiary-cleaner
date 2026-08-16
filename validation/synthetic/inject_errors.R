# inject_errors.R
#
# Reads a clean pool (generate_clean_data.R output), injects labeled errors
# per error_catalog.yaml, writes:
#   - a corrupted dataset in the pipeline's expected raw-ingest shape
#   - ground_truth.csv: one row per injected error, with original/corrupted/
#     true values, so evaluate_detection.R / evaluate_correction.R never have
#     to guess what was done.
#
# Design decisions this file encodes (see validation/benchmark_design.md):
#
#   §3  Enrichment: each category is sampled to its OWN target count,
#       independent of the others' real-world rate. rate_anchor_pct in the
#       catalog is carried into ground_truth.csv for later PPV-curve
#       reweighting (§2) -- it is NOT used to decide how many to inject here.
#
#   §7① Participant clustering: a subset of participants is marked
#       "error-prone" and receives a disproportionate share of injected
#       errors, matching the real-data clustering pattern (33% of one
#       participant's SOL days were misentries) rather than IID-per-row
#       injection, which would make cross_participant_spike evaluation
#       meaningless.
#
#   §7② Compound errors: compound_ampm_and_swap composes two mechanisms on
#       one record, not sampled as a mix of two single-category injections.
#
#   Schema note: the clean generator stores SOL/WASO duration as NUMERIC
#   minutes (the intended, already-correct value). The real pipeline's raw
#   ingest expects these as CHARACTER strings (arbitrary as-typed formats --
#   see process_interval.R). This script is what performs that numeric ->
#   raw-string conversion, and it is also where format-corruption categories
#   (format_no_colon, format_malformed_colon, mmss_confusion) act, since they
#   are specifically about which string representation gets typed.

suppressPackageStartupMessages({
  library(dplyr)
  library(yaml)
})

parse_args <- function(defaults) {
  args <- commandArgs(trailingOnly = TRUE)
  out <- defaults
  for (a in args) {
    if (!grepl("^--[A-Za-z_]+=", a)) next
    kv <- sub("^--", "", a)
    k <- sub("=.*$", "", kv)
    v <- sub("^[^=]*=", "", kv)
    if (k %in% names(out)) {
      if (is.numeric(out[[k]])) v <- as.numeric(v)
      out[[k]] <- v
    }
  }
  out
}

opt <- parse_args(list(
  clean_rds        = "clean_pure_n7000.rds",
  catalog          = "error_catalog.yaml",
  seed             = 20260812,
  error_prone_frac = 0.12,     # fraction of participants marked error-prone
  error_prone_mult = 6,        # relative injection-probability multiplier for them
  out_data         = "corrupted_data.rds",
  out_truth        = "ground_truth.csv"
))

set.seed(opt$seed)
# NB: read the catalog as an explicit UTF-8 connection rather than
# yaml::read_yaml(path) directly. read_yaml()'s default file-read goes
# through readLines() under the PROCESS locale, and this container's locale
# is POSIX/C -- under that locale readLines() cannot decode the multi-byte
# UTF-8 characters this file legitimately contains (section signs "§",
# circled digits "①②③④" in the provenance comments) and silently truncates
# the read partway through with an "invalid input found" warning. The
# truncation drops the top-level `meta:` key entirely (it happened to fall
# after the first bad byte), which made catalog$meta$enrichment_target_per_category
# NULL and crashed inject_cross_participant_spikes() with "argument is of
# length zero" downstream -- catalog$meta wasn't merely wrong, it silently
# vanished. Forcing the connection's encoding to UTF-8 makes the read
# locale-independent.
catalog_con <- file(opt$catalog, encoding = "UTF-8")
catalog <- yaml::yaml.load(paste(readLines(catalog_con, warn = FALSE), collapse = "\n"))
close(catalog_con)
stopifnot(!is.null(catalog$meta$enrichment_target_per_category))
clean <- readRDS(opt$clean_rds)
stopifnot(all(c("pid", "day_num", "row_id",
                "time_bed_am_hhmm", "time_bed_am_ampm",
                "time_sleep_am_hhmm", "time_sleep_am_ampm",
                "time_awake_am_hhmm", "time_awake_am_ampm",
                "time_getup_am_hhmm", "time_getup_am_ampm",
                "duration_totalmin_sol_estimate_am",
                "duration_totalmin_waso_estimate_am") %in% names(clean)))

n <- nrow(clean)
corrupted <- clean   # will be mutated in place, row by row, as errors are assigned
used_row  <- rep(FALSE, n)   # a row gets at most ONE single-mechanism injection;
                              # compound category is exempt (it's its own category)
row_idx_by_id <- setNames(seq_len(n), clean$row_id)

# ---------------------------------------------------------------------------
# Participant clustering (§7①)
# ---------------------------------------------------------------------------
pids <- unique(clean$pid)
n_error_prone <- max(1, round(length(pids) * opt$error_prone_frac))
error_prone_pids <- sample(pids, n_error_prone)
participant_weight <- setNames(rep(1, length(pids)), pids)
participant_weight[as.character(error_prone_pids)] <- opt$error_prone_mult

row_weight <- participant_weight[as.character(clean$pid)]

sample_rows_weighted <- function(k, exclude_used = TRUE) {
  eligible <- which((!used_row) | !exclude_used)
  if (length(eligible) == 0) return(integer(0))
  w <- row_weight[eligible]
  k <- min(k, length(eligible))
  sample(eligible, k, prob = w)
}

ground_truth <- list()
gt_add <- function(row_i, error_type, field, original, corrupted_val, true_val, provenance) {
  ground_truth[[length(ground_truth) + 1]] <<- data.frame(
    row_id = clean$row_id[row_i],
    pid = clean$pid[row_i],
    day_num = clean$day_num[row_i],
    error_type = error_type,
    field = field,
    original_value = as.character(original),
    corrupted_value = as.character(corrupted_val),
    true_value = as.character(true_val),
    provenance = provenance,
    stringsAsFactors = FALSE
  )
}

# ---------------------------------------------------------------------------
# Helpers: HH:MM/AMPM <-> minutes-since-local-midnight-of-that-clock (0-719
# 12h-clock representation is enough for the swap/AM-PM mechanics we need)
# ---------------------------------------------------------------------------
hhmm_to_parts <- function(hhmm) {
  p <- strsplit(hhmm, ":")[[1]]
  list(h = as.integer(p[1]), m = as.integer(p[2]))
}

flip_ampm <- function(ampm) if (ampm == "AM") "PM" else "AM"

# ---------------------------------------------------------------------------
# Category injectors -- each takes a row index, mutates `corrupted` in
# global scope via <<-, and calls gt_add(). Return TRUE/FALSE (whether it
# actually applied -- some categories have row-level eligibility checks).
# ---------------------------------------------------------------------------

inject_ampm_swap <- function(i) {
  field <- sample(c("time_bed_am", "time_sleep_am"), 1)
  ampm_col <- paste0(field, "_ampm")
  orig_ampm <- corrupted[[ampm_col]][i]
  new_ampm <- flip_ampm(orig_ampm)
  corrupted[[ampm_col]][i] <<- new_ampm
  gt_add(i, "ampm_swap", ampm_col, orig_ampm, new_ampm, orig_ampm,
         "observed+literature")
  TRUE
}

# clock hh:mm + AM/PM -> minutes since midnight
to_minutes <- function(hhmm, ampm) {
  if (is.na(hhmm) || is.na(ampm) || !grepl("^[0-9]{1,2}:[0-9]{2}$", hhmm)) return(NA_real_)
  h <- as.integer(sub(":.*$", "", hhmm)); m <- as.integer(sub("^.*:", "", hhmm))
  if (ampm == "PM" && h != 12) h <- h + 12
  if (ampm == "AM" && h == 12) h <- 0
  h * 60 + m
}

inject_adjacent_swap <- function(i, pair) {
  # pair: c("time_bed_am", "time_sleep_am") etc.
  hhmm_a <- paste0(pair[1], "_hhmm"); ampm_a <- paste0(pair[1], "_ampm")
  hhmm_b <- paste0(pair[2], "_hhmm"); ampm_b <- paste0(pair[2], "_ampm")

  orig_a_hhmm <- corrupted[[hhmm_a]][i]; orig_a_ampm <- corrupted[[ampm_a]][i]
  orig_b_hhmm <- corrupted[[hhmm_b]][i]; orig_b_ampm <- corrupted[[ampm_b]][i]

  corrupted[[hhmm_a]][i] <<- orig_b_hhmm; corrupted[[ampm_a]][i] <<- orig_b_ampm
  corrupted[[hhmm_b]][i] <<- orig_a_hhmm; corrupted[[ampm_b]][i] <<- orig_a_ampm

  gt_add(i, paste0("adjacent_swap_", pair[1], "_", pair[2]),
         paste(hhmm_a, ampm_a, hhmm_b, ampm_b, sep = "|"),
         paste(orig_a_hhmm, orig_a_ampm, orig_b_hhmm, orig_b_ampm, sep = "|"),
         paste(orig_b_hhmm, orig_b_ampm, orig_a_hhmm, orig_a_ampm, sep = "|"),
         paste(orig_a_hhmm, orig_a_ampm, orig_b_hhmm, orig_b_ampm, sep = "|"),
         "observed+literature")
  TRUE
}

# raw-string renderers for duration fields (see schema note in header).
# `corrupted`'s duration columns start numeric but silently coerce to
# character the first time ANY element in that column is assigned a string
# (standard R vector-type-widening behaviour) -- so by the time later
# categories run, corrupted[[field]][i] may already be a character-typed
# numeral (e.g. "45") rather than a double. Every renderer therefore
# coerces its input through as.numeric() first, regardless of what type it
# arrives as.
render_plain <- function(mins) as.character(round(as.numeric(mins)))
render_no_colon_4digit <- function(mins) {
  # e.g. 90 minutes typed as "0090" (no separator, 4 digits) -- Branch 2 target
  sprintf("%04d", round(as.numeric(mins)))
}
render_malformed_colon <- function(mins) {
  # e.g. 34 minutes typed as ":0034" -- Branch 3 target
  paste0(":", sprintf("%04d", round(as.numeric(mins))))
}
render_mmss_ambiguous <- function(mins) {
  # a genuinely-short duration typed in a way that LOOKS like it could be
  # MM:SS and would be misparsed by the >=60-with-colon heuristic if the
  # heuristic's assumption is wrong for this particular value.
  # e.g. true value 65 minutes typed as "65:00" (parser reads as 00:65 -> WRONG,
  # true value was already just "65" minutes, not hours:minutes)
  sprintf("%d:00", round(as.numeric(mins)))
}
render_field_misentry <- function(hhmm, ampm) {
  # a clock time leaks into the duration field verbatim as if it were HH:MM
  # minutes:seconds -- e.g. sleep time "10:30 PM" typed into the SOL box as "10:30"
  hhmm
}

inject_format_error <- function(i, category, target_field) {
  true_val <- corrupted[[target_field]][i]
  raw_clean <- render_plain(true_val)
  raw_corrupt <- switch(category,
    format_no_colon = render_no_colon_4digit(true_val),
    format_malformed_colon = render_malformed_colon(true_val),
    mmss_confusion = render_mmss_ambiguous(true_val)
  )
  corrupted[[target_field]][i] <<- raw_corrupt
  gt_add(i, category, target_field, raw_clean, raw_corrupt, true_val, "observed")
  TRUE
}

inject_field_misentry <- function(i, category) {
  if (category == "field_misentry_sol") {
    target_field <- "duration_totalmin_sol_estimate_am"
    source_hhmm <- corrupted$time_sleep_am_hhmm[i]
    source_ampm <- corrupted$time_sleep_am_ampm[i]
  } else {
    target_field <- "duration_totalmin_waso_estimate_am"
    source_hhmm <- corrupted$time_awake_am_hhmm[i]
    source_ampm <- corrupted$time_awake_am_ampm[i]
  }
  true_val <- corrupted[[target_field]][i]
  raw_clean <- render_plain(true_val)
  raw_corrupt <- render_field_misentry(source_hhmm, source_ampm)
  corrupted[[target_field]][i] <<- raw_corrupt
  gt_add(i, category, target_field, raw_clean, raw_corrupt, true_val,
         "observed+blind_spot")
  TRUE
}

inject_implausible_duration <- function(i) {
  target_field <- sample(c("duration_totalmin_sol_estimate_am",
                            "duration_totalmin_waso_estimate_am"), 1)
  true_val <- corrupted[[target_field]][i]
  raw_clean <- render_plain(true_val)
  extreme_val <- if (grepl("sol", target_field)) sample(150:280, 1) else sample(150:280, 1)
  raw_corrupt <- render_plain(extreme_val)
  corrupted[[target_field]][i] <<- raw_corrupt
  gt_add(i, "implausible_duration", target_field, raw_clean, raw_corrupt, true_val,
         "literature")
  TRUE
}

inject_compound <- function(i) {
  # Deliberately does NOT call inject_ampm_swap()/inject_adjacent_swap()
  # directly -- those each call gt_add() under their OWN category label
  # (ampm_swap / adjacent_swap_*), which would make compound-injected rows
  # indistinguishable from single-mechanism ones in ground_truth.csv (this
  # is exactly the bug the first test run surfaced: table(gt$error_type)
  # showed ampm_swap inflated by the compound draws, and no
  # "compound_ampm_and_swap" label existed at all). Instead this function
  # re-applies the same two corruption mechanics inline and logs ONE
  # consolidated ground-truth row under its own category, so leave-one-out
  # ablation (benchmark_design.md §4) and per-category recall (§3) can
  # actually isolate compound-error performance from the two single-
  # mechanism categories.
  ampm_field <- sample(c("time_bed_am", "time_sleep_am"), 1)
  ampm_col <- paste0(ampm_field, "_ampm")
  orig_ampm <- corrupted[[ampm_col]][i]
  new_ampm <- flip_ampm(orig_ampm)
  corrupted[[ampm_col]][i] <<- new_ampm

  pair <- sample(list(c("time_bed_am", "time_sleep_am"),
                       c("time_awake_am", "time_getup_am")), 1)[[1]]
  hhmm_a <- paste0(pair[1], "_hhmm"); ampm_a <- paste0(pair[1], "_ampm")
  hhmm_b <- paste0(pair[2], "_hhmm"); ampm_b <- paste0(pair[2], "_ampm")
  orig_a_hhmm <- corrupted[[hhmm_a]][i]; orig_a_ampm_now <- corrupted[[ampm_a]][i]
  orig_b_hhmm <- corrupted[[hhmm_b]][i]; orig_b_ampm_now <- corrupted[[ampm_b]][i]
  corrupted[[hhmm_a]][i] <<- orig_b_hhmm; corrupted[[ampm_a]][i] <<- orig_b_ampm_now
  corrupted[[hhmm_b]][i] <<- orig_a_hhmm; corrupted[[ampm_b]][i] <<- orig_a_ampm_now

  gt_add(
    i, "compound_ampm_and_swap",
    paste(ampm_col, hhmm_a, ampm_a, hhmm_b, ampm_b, sep = "|"),
    paste(orig_ampm, orig_a_hhmm, orig_a_ampm_now, orig_b_hhmm, orig_b_ampm_now, sep = "|"),
    paste(new_ampm, orig_b_hhmm, orig_b_ampm_now, orig_a_hhmm, orig_a_ampm_now, sep = "|"),
    paste(orig_ampm, orig_a_hhmm, orig_a_ampm_now, orig_b_hhmm, orig_b_ampm_now, sep = "|"),
    "observed+blind_spot"
  )
  TRUE
}

# ---------------------------------------------------------------------------
# adjacent_swap_large_gap -- swap a pair whose gap EXCEEDS the minor-order
# swap threshold (>3h). The swap rule deliberately leaves >3h violations
# untouched, so the downstream temporal-order check is the only thing that
# can catch it. The 2026-08-17 M1-M7 audit found 49 real rows like this that
# the pipeline left uncorrected AND unflagged (25 clean + 23 equal_time_ok).
inject_adjacent_swap_large_gap <- function(i) {
  pair <- sample(list(c("time_bed_am", "time_sleep_am"),
                       c("time_sleep_am", "time_awake_am"),
                       c("time_awake_am", "time_getup_am")), 1)[[1]]
  hhmm_a <- paste0(pair[1], "_hhmm"); ampm_a <- paste0(pair[1], "_ampm")
  hhmm_b <- paste0(pair[2], "_hhmm"); ampm_b <- paste0(pair[2], "_ampm")
  orig_a_hhmm <- corrupted[[hhmm_a]][i]; orig_a_ampm <- corrupted[[ampm_a]][i]
  orig_b_hhmm <- corrupted[[hhmm_b]][i]; orig_b_ampm <- corrupted[[ampm_b]][i]
  corrupted[[hhmm_a]][i] <<- orig_b_hhmm; corrupted[[ampm_a]][i] <<- orig_b_ampm
  corrupted[[hhmm_b]][i] <<- orig_a_hhmm; corrupted[[ampm_b]][i] <<- orig_a_ampm
  gt_add(i, "adjacent_swap_large_gap_left_clean",
         paste(hhmm_a, ampm_a, hhmm_b, ampm_b, sep = "|"),
         paste(orig_a_hhmm, orig_a_ampm, orig_b_hhmm, orig_b_ampm, sep = "|"),
         paste(orig_b_hhmm, orig_b_ampm, orig_a_hhmm, orig_a_ampm, sep = "|"),
         paste(orig_a_hhmm, orig_a_ampm, orig_b_hhmm, orig_b_ampm, sep = "|"),
         "observed+blind_spot")
  TRUE
}

# ---------------------------------------------------------------------------
# sol_window_contradiction -- set the SOL duration to a value LARGER than
# the bed->sleep timestamp window, so the computed SOL cannot fit between
# bedtime and sleep onset. The 2026-08-17 M1-M7 audit flagged 922 real rows
# where mincalc SOL (up to 225 min) exceeded the sleep window, most with no
# pipeline flag. Tests whether that contradiction is surfaced.
inject_sol_window_contradiction <- function(i) {
  bed_hhmm <- corrupted$time_bed_am_hhmm[i]; bed_ampm <- corrupted$time_bed_am_ampm[i]
  slp_hhmm <- corrupted$time_sleep_am_hhmm[i]; slp_ampm <- corrupted$time_sleep_am_ampm[i]
  if (is.na(bed_hhmm) || is.na(slp_hhmm)) return(FALSE)
  bed_m <- to_minutes(bed_hhmm, bed_ampm)
  slp_m <- to_minutes(slp_hhmm, slp_ampm)
  if (is.na(bed_m) || is.na(slp_m)) return(FALSE)
  window <- (slp_m - bed_m + 1440) %% 1440
  if (window <= 5 || window > 300) return(FALSE)   # need a small but valid window
  # SOL larger than the window, well-formed numeric minutes
  new_sol <- window + sample(30:120, 1)
  true_val <- corrupted$duration_totalmin_sol_estimate_am[i]
  raw_clean <- render_plain(true_val)
  corrupted$duration_totalmin_sol_estimate_am[i] <<- render_plain(new_sol)
  gt_add(i, "sol_window_contradiction", "duration_totalmin_sol_estimate_am",
         raw_clean, render_plain(new_sol), true_val, "observed+blind_spot")
  TRUE
}


# ---------------------------------------------------------------------------
# cross_participant_spike -- needs multi-day baseline per participant,
# computed on the CLEAN pool (pre-corruption), so injection targets are
# picked using the exact same MAD/median-baseline logic Step 8.5 uses to
# detect them (spike_multiplier=4, min_baseline=5, spike_abs_threshold=120
# for SOL / 60 for WASO -- pulled directly from
# inst/scripts/cross_participant_global_check.R lines 74-89, not guessed).
# ---------------------------------------------------------------------------
inject_cross_participant_spikes <- function(target_n) {
  applied <- 0
  attempts <- 0
  metrics <- list(
    sol  = list(field = "duration_totalmin_sol_estimate_am",
                min_baseline = 5, multiplier = 4, abs_threshold = 120),
    waso = list(field = "duration_totalmin_waso_estimate_am",
                min_baseline = 3, multiplier = 4, abs_threshold = 60)
  )
  pid_days <- split(seq_len(n), clean$pid)
  candidates <- expand.grid(pid = names(pid_days), metric = names(metrics),
                             stringsAsFactors = FALSE)
  candidates <- candidates[sample(nrow(candidates)), ]

  for (r in seq_len(nrow(candidates))) {
    if (applied >= target_n) break
    pid <- candidates$pid[r]; metric <- candidates$metric[r]
    idxs <- pid_days[[pid]]
    if (length(idxs) < 4) next   # need >=3 OTHER days + 1 target, matching
                                  # Step 8.5's own n_days>=3 tier-3 fallback rule
    m <- metrics[[metric]]
    vals <- clean[[m$field]][idxs]
    target_i <- sample(idxs, 1)
    if (used_row[row_idx_by_id[as.character(clean$row_id[target_i])]]) next
    baseline_vals <- vals[idxs != target_i]
    baseline_median <- median(baseline_vals)
    if (baseline_median < m$min_baseline) next   # low-baseline-override territory,
                                                   # keep spikes and that category separate
    spike_val <- max(baseline_median * m$multiplier, m$abs_threshold) + sample(10:40, 1)

    row_i <- row_idx_by_id[as.character(clean$row_id[target_i])]
    true_val <- corrupted[[m$field]][row_i]
    raw_clean <- render_plain(true_val)
    corrupted[[m$field]][row_i] <<- render_plain(spike_val)
    gt_add(row_i, "cross_participant_spike", m$field, raw_clean,
           render_plain(spike_val), true_val, "observed")
    used_row[row_i] <<- TRUE
    applied <- applied + 1
  }
  applied
}

# ---------------------------------------------------------------------------
# Main enrichment loop
# ---------------------------------------------------------------------------
target_per_cat <- catalog$meta$enrichment_target_per_category

simple_categories <- list(
  list(name = "ampm_swap", fn = function(i) inject_ampm_swap(i)),
  list(name = "adjacent_swap_bed_sleep",
       fn = function(i) inject_adjacent_swap(i, c("time_bed_am", "time_sleep_am"))),
  list(name = "adjacent_swap_sleep_awake",
       fn = function(i) inject_adjacent_swap(i, c("time_sleep_am", "time_awake_am"))),
  list(name = "adjacent_swap_awake_getup",
       fn = function(i) inject_adjacent_swap(i, c("time_awake_am", "time_getup_am"))),
  list(name = "field_misentry_sol",
       fn = function(i) inject_field_misentry(i, "field_misentry_sol")),
  list(name = "field_misentry_waso",
       fn = function(i) inject_field_misentry(i, "field_misentry_waso")),
  list(name = "format_no_colon",
       fn = function(i) inject_format_error(i, "format_no_colon",
             sample(c("duration_totalmin_sol_estimate_am",
                      "duration_totalmin_waso_estimate_am"), 1))),
  list(name = "format_malformed_colon",
       fn = function(i) inject_format_error(i, "format_malformed_colon",
             sample(c("duration_totalmin_sol_estimate_am",
                      "duration_totalmin_waso_estimate_am"), 1))),
  list(name = "mmss_confusion",
       fn = function(i) inject_format_error(i, "mmss_confusion",
             sample(c("duration_totalmin_sol_estimate_am",
                      "duration_totalmin_waso_estimate_am"), 1))),
  list(name = "implausible_duration",
       fn = function(i) inject_implausible_duration(i)),
  list(name = "compound_ampm_and_swap",
       fn = function(i) inject_compound(i)),
  list(name = "adjacent_swap_large_gap_left_clean",
       fn = function(i) inject_adjacent_swap_large_gap(i)),
  list(name = "sol_window_contradiction",
       fn = function(i) inject_sol_window_contradiction(i))
)

log_lines <- character(0)
for (cat_spec in simple_categories) {
  target <- target_per_cat
  rows_i <- sample_rows_weighted(target)
  applied <- 0
  for (i in rows_i) {
    ok <- tryCatch(cat_spec$fn(i), error = function(e) FALSE)
    if (isTRUE(ok)) {
      # NB: plain `<-`, not `<<-` -- this statement runs directly at the
      # script's top level (inside a bare for-loop, not inside a function),
      # so the "current" evaluation frame already IS globalenv. `<<-`
      # deliberately skips the current frame when searching for the target,
      # which at true top level means it walks past globalenv into the
      # attached-package search path and fails with "object not found" for
      # this indexed (read-modify-write) form. `<<-` is only for reaching
      # OUT to an enclosing scope from inside a function; used_row is
      # already local here.
      used_row[i] <- TRUE
      applied <- applied + 1
    }
  }
  log_lines <- c(log_lines, sprintf("%-28s target=%-5d applied=%-5d",
                                     cat_spec$name, target, applied))
}

cp_applied <- inject_cross_participant_spikes(target_per_cat)
log_lines <- c(log_lines, sprintf("%-28s target=%-5d applied=%-5d",
                                   "cross_participant_spike", target_per_cat, cp_applied))

# no_error_control: everything never touched
untouched_idx <- which(!used_row)
for (i in untouched_idx) {
  gt_add(i, "no_error_control", NA_character_, NA_character_, NA_character_,
         NA_character_, "observed")
}
log_lines <- c(log_lines, sprintf("%-28s %-12s n=%d", "no_error_control", "", length(untouched_idx)))

# for rows that got a SINGLE-category duration injection, still need the
# duration column raw-stringified even if unused_row/untouched (the real
# pipeline expects character, not numeric, for these two fields) --
# stringify whatever's left as numeric.
for (fld in c("duration_totalmin_sol_estimate_am", "duration_totalmin_waso_estimate_am")) {
  is_num <- !is.na(suppressWarnings(as.numeric(corrupted[[fld]])))
  corrupted[[fld]][is_num] <- render_plain(as.numeric(corrupted[[fld]][is_num]))
}

ground_truth_df <- do.call(rbind, ground_truth)

saveRDS(corrupted, opt$out_data)
write.csv(ground_truth_df, opt$out_truth, row.names = FALSE)

cat("=== Injection summary ===\n")
cat(paste(log_lines, collapse = "\n"), "\n")
cat(sprintf("\nTotal rows: %d | injected: %d | untouched: %d\n",
            n, sum(used_row), sum(!used_row)))
cat(sprintf("Written: %s (corrupted data), %s (ground truth, %d rows)\n",
            opt$out_data, opt$out_truth, nrow(ground_truth_df)))
