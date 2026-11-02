# sol_waso_candidate_scan.R -- READ-ONLY scan for self-reported SOL / WASO entries that are not ordinary durations
#
# Step 1 of the SOL/WASO cleaning plan (work_logs/2026-10-30_sol_waso_ambiguous_notes.md). It lists every entry whose
# text is not a plain "00:MM", works out what the pipeline did to it, and sorts it into a class with the rules
# agreed on 2026-10-30. It changes nothing: it reads files and writes a new table and a counts summary.
#
# Inputs (all read only):
#   --raw=PATH   the ORIGINAL input file (.rds or .csv; the file data.files.main points to). Strongly recommended: the
#                pipeline's own "raw" copy is saved after its format repairs, so it hides entries such as 11:00 -> 00:11.
#                Without --raw the scan falls back to that post-repair copy and says so.
#   --sol_col=, --waso_col=   raw column names (default duration_totalmin_sol_estimate_am / ..._waso_estimate_am)
#   --full=PATH  default output/cleaned_data_full.rds   (pipeline repair notes, ambiguity flag, delivered minutes)
#   --final=PATH default output/cleaned_data_final.csv  (the participant's own bedtime / sleep onset / awakening / get-up)
#   --out=DIR    default ~/Desktop/sol_waso_candidate_scan  (keep this OUTSIDE the repository: the table has participant ids)
#   --tol=5 --window=60 --near=15   rule parameters in minutes (agreed: 5 and 60; 15 is the "person confirms" band)
#
# Usage (from the repository root):
#   RENV_CONFIG_AUTOLOADER_ENABLED=FALSE Rscript validation/sol_waso_candidate_scan.R --raw=/path/to/original_input.rds
#
# The console shows counts only. The row-level table is written to --out.

args <- commandArgs(trailingOnly = TRUE)
getarg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[1]) else default
}
raw_path   <- getarg("raw")
sol_col    <- getarg("sol_col", "duration_totalmin_sol_estimate_am")
waso_col   <- getarg("waso_col", "duration_totalmin_waso_estimate_am")
full_path  <- getarg("full", "output/cleaned_data_full.rds")
final_path <- getarg("final", "output/cleaned_data_final.csv")
out_dir    <- getarg("out", file.path(path.expand("~"), "Desktop", "sol_waso_candidate_scan"))
tol    <- as.numeric(getarg("tol", 5))
window <- as.numeric(getarg("window", 60))
near   <- as.numeric(getarg("near", 15))
repo <- normalizePath(getwd(), mustWork = FALSE)
if (startsWith(normalizePath(out_dir, mustWork = FALSE), repo))
  stop("--out is inside the repository; choose a folder outside it (the table has participant ids).")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

read_any <- function(p) if (grepl("\\.csv$", p, ignore.case = TRUE)) utils::read.csv(p, stringsAsFactors = FALSE) else readRDS(p)
full  <- suppressWarnings(readRDS(full_path))
final <- utils::read.csv(final_path, stringsAsFactors = FALSE)

# ---- the raw text -------------------------------------------------------------------------------------------------
if (!is.null(raw_path)) {
  rawdf <- read_any(raw_path)
  for (cc in c(sol_col, waso_col))
    if (!cc %in% names(rawdf)) stop("Column '", cc, "' not found in the raw file. Columns that mention sol/waso: ",
                                    paste(grep("sol|waso", names(rawdf), value = TRUE, ignore.case = TRUE), collapse = ", "))
  if ("row_id" %in% names(rawdf)) {
    pos <- match(full$row_id, rawdf$row_id)
  } else {
    # the pipeline adds row_id (1..n in file order); match by position, but only if participant and day agree on every row
    if (nrow(rawdf) != nrow(full) || !identical(as.character(rawdf$pid), as.character(full$pid)) ||
        !identical(as.integer(rawdf$day_num), as.integer(full$day_num)))
      stop("The raw file has no row_id and its rows do not line up with the pipeline archive (pid / day_num differ); cannot match safely.")
    pos <- full$row_id
    cat("raw file has no row_id: matched by position (pid and day_num agree on all", nrow(full), "rows)\n")
  }
  src <- "original input"
  raw_sol  <- as.character(rawdf[[sol_col]])[pos]
  raw_waso <- as.character(rawdf[[waso_col]])[pos]
} else {
  warning("No --raw given: using the pipeline's post-repair copy. Entries like dd:00 are already rewritten there.", call. = FALSE)
  src <- "post-repair copy (NOT the original text)"
  raw_sol  <- as.character(full$duration_totalmin_sol_estimate_am_raw_orig)
  raw_waso <- as.character(full$duration_totalmin_waso_estimate_am_raw_orig)
}
cat("raw text source:", src, "\n")

# ---- own times of day (12-hour dial: no AM/PM was typed in these fields) --------------------------------------------
fix_ts <- function(x) { i <- !is.na(x) & x != "" & nchar(x) == 10; x[i] <- paste(x[i], "00:00:00")
                        as.POSIXct(strptime(x, "%Y-%m-%d %H:%M:%S", tz = "UTC")) }
tod <- function(t) as.numeric(format(t, "%H")) * 60 + as.numeric(format(t, "%M"))
hhmm <- function(m) ifelse(is.na(m), NA_character_, sprintf("%02d:%02d", as.integer(m %/% 60), as.integer(m %% 60)))
mi <- match(full$row_id, final$row_id)
bed <- tod(fix_ts(final$bedtime_selfreport_ts))[mi];  slp <- tod(fix_ts(final$sleeponset_selfreport_ts))[mi]
awk <- tod(fix_ts(final$awakening_selfreport_ts))[mi]; gup <- tod(fix_ts(final$getup_selfreport_ts))[mi]
d12 <- function(a, b) { d <- abs((a - b) %% 720); pmin(d, 720 - d) }

scan_field <- function(field, raw, notes, ambig, delivered) {
  raw <- trimws(raw); raw[raw %in% c("", "NA")] <- NA
  ok  <- !is.na(raw)
  colon <- ok & grepl("^[0-9]{1,3}:[0-9]{2}$", raw)
  digits <- ok & grepl("^[0-9]+$", raw)
  p <- strsplit(ifelse(colon, raw, NA), ":")
  h <- suppressWarnings(as.numeric(sapply(p, `[`, 1))); m <- suppressWarnings(as.numeric(sapply(p, `[`, 2)))
  typed <- h * 60 + m
  ordinary <- colon & h == 0 & m < 60
  cand <- ok & !ordinary
  pattern <- ifelse(!ok, "missing", ifelse(colon, "H:MM", ifelse(digits, "digits only", "other")))

  cls <- rep(NA_character_, length(raw)); proposed <- rep(NA_real_, length(raw))
  ds <- d12(typed, slp); db <- d12(typed, bed); diff <- (typed - bed) %% 720
  slp_ok <- !is.na(ds) & !is.na(db) & !is.na(diff)
  for (i in which(cand)) {
    if (pattern[i] != "H:MM") { cls[i] <- "other format (person)"; next }
    if (m[i] >= 60) { cls[i] <- "minute part 60 or more (person)"; next }
    if (h[i] %in% 1:3) {
      cls[i] <- "valid but unusual, 1 to 3 hours (keep; participant-level look)"
      if (field == "SOL" && slp_ok[i] && ds[i] <= tol && diff[i] <= window && db[i] > ds[i])
        cls[i] <- "1 to 3 hours AND fits the clock rule (person)"
      next
    }
    # first number 4 or more: cannot be a duration typed as H:MM
    if (m[i] == 0 && !(field == "SOL" && slp_ok[i] && min(ds[i], db[i]) <= near)) {
      cls[i] <- "minutes typed in the hours slot (keep as minutes)"; proposed[i] <- h[i]; next
    }
    if (field == "WASO") { cls[i] <- "WASO probable clock time -> missing"; next }
    # SOL
    if (!slp_ok[i]) { cls[i] <- "SOL clock-like, own times unavailable (person)"; next }
    if (ds[i] <= tol && diff[i] <= window && db[i] > ds[i]) { cls[i] <- "SOL recompute from clock time (auto)"; proposed[i] <- diff[i]; next }
    if (ds[i] <= tol && diff[i] <= window && db[i] == ds[i]) { cls[i] <- "SOL tie bedtime / sleep onset (person)"; proposed[i] <- diff[i]; next }
    if (db[i] < ds[i] && db[i] <= near) { cls[i] <- "SOL typed bedtime -> missing"; next }
    if (ds[i] <= near && diff[i] <= window) { cls[i] <- "SOL near sleep onset, beyond tolerance (person confirms)"; proposed[i] <- diff[i]; next }
    cls[i] <- "SOL unclear (person)"
  }
  touched <- !is.na(notes) & nzchar(notes)
  note_kind <- ifelse(!touched, "", ifelse(grepl("MM:SS", notes), "MM:SS rule", ifelse(grepl("dd:00", notes), "dd:00 rule", "format repair only")))
  data.frame(row_id = full$row_id, pid = full$pid, day_num = full$day_num, field = field,
             raw_text = raw, pattern = pattern, first_number = h, minute_part = m, class = cls,
             proposed_minutes_if_applied = proposed,
             pipeline_note_kind = note_kind, pipeline_ambiguous_flag = ambig %in% c(TRUE, "TRUE"),
             pipeline_delivered_minutes = delivered,
             own_bedtime = hhmm(bed), own_sleep_onset = hhmm(slp), own_awakening = hhmm(awk), own_getup = hhmm(gup),
             stringsAsFactors = FALSE)[cand, ]
}

tab <- rbind(
  scan_field("SOL",  raw_sol,  full$duration_totalmin_sol_estimate_am_correctionsmade,  full$duration_totalmin_sol_estimate_am_ambig,
             suppressWarnings(as.numeric(final$sol_selfreport_minutes[mi]))),
  scan_field("WASO", raw_waso, full$duration_totalmin_waso_estimate_am_correctionsmade, full$duration_totalmin_waso_estimate_am_ambig,
             suppressWarnings(as.numeric(final$waso_selfreport_minutes[mi]))))
tab$pipeline_touched <- tab$pipeline_note_kind %in% c("MM:SS rule", "dd:00 rule") | tab$pipeline_ambiguous_flag

# Suggested decision (what the agreed rules would do) and blank columns for the reviewer to fill in.
suggest <- function(cl) ifelse(grepl("^minutes typed", cl), "keep_as_minutes",
  ifelse(grepl("recompute from clock time", cl), "recompute",
  ifelse(grepl("-> missing", cl), "set_missing", ifelse(grepl("^valid but unusual", cl), "keep", "person_decides"))))
tab$suggested_decision <- suggest(tab$class)
tab$suggested_value_min <- ifelse(tab$suggested_decision == "keep_as_minutes", tab$first_number,
                           ifelse(tab$suggested_decision == "recompute", tab$proposed_minutes_if_applied, NA))
tab$decision <- ""            # keep_as_minutes / recompute / set_missing / keep / other  (reviewer fills in)
tab$decision_value_min <- ""  # the minutes to use if the decision is recompute or other
tab$decided_by <- ""
tab$decision_date <- ""
tab$reviewer_note <- ""

needs <- !grepl("^valid but unusual", tab$class)          # entries that need a decision (not the 1 to 3 hour group)
cnt <- table(tab$pid[needs])
tab$participant_entries_needing_a_decision <- as.integer(cnt[as.character(tab$pid)]); tab$participant_entries_needing_a_decision[is.na(tab$participant_entries_needing_a_decision)] <- 0L
tab$participant_repeats <- tab$participant_entries_needing_a_decision >= 2

# ---- what goes to the screen: counts only ---------------------------------------------------------------------------------
cat("\nParameters: tolerance", tol, "min | window", window, "min | 'person confirms' band up to", near, "min\n")
cat("\nCandidate entries by field and class\n"); print(table(tab$class, tab$field))
cat("\nWhat the pipeline did with the candidates (rows = how the pipeline touched them)\n")
print(table(pipeline_note = tab$pipeline_note_kind, field = tab$field))
cat("\nSilent candidates (first number 4 or more, but no MM:SS / dd:00 note and no ambiguity flag):",
    sum(!tab$pipeline_touched & !is.na(tab$first_number) & tab$first_number >= 4), "\n")
cat("Candidates that the pipeline flagged as ambiguous but this scan treats as an ordinary duration: ",
    sum(tab$pipeline_ambiguous_flag & grepl("^valid but unusual", tab$class)), "\n")
cat("\nEntries that need a decision (everything except the 1 to 3 hour group):", sum(needs),
    "| participants:", length(cnt), "| with 2 or more:", sum(cnt >= 2), "| entries that belong to those:", sum(cnt[cnt >= 2]), "\n")
cat("1 to 3 hour entries (kept, participant-level look):", sum(!needs), "\n\n")

# distinct strings (these are the strings, not people): useful to classify by string first
ds_tab <- aggregate(row_id ~ field + raw_text + class, tab, length); names(ds_tab)[4] <- "n"
ds_tab <- ds_tab[order(ds_tab$field, -ds_tab$n), ]
cat("distinct raw strings among the candidates:", nrow(ds_tab), "\n")

# Draft of the manual metric-duration corrections file (only the entries whose suggested decision changes a value),
# in the columns apply_sleep_metric_duration_corrections() reads. NOT applied: review it, set manually_corrected, and
# copy the rows you accept into your own manual_sleep_metric_duration_corrections.csv.
chg <- tab$suggested_decision %in% c("recompute", "set_missing")
draft <- data.frame(pid = tab$pid[chg], day_num = tab$day_num[chg], row_id = tab$row_id[chg],
                    variable = ifelse(tab$field[chg] == "SOL", "duration_totalmin_sol_estimate_am", "duration_totalmin_waso_estimate_am"),
                    corrected_mincalc = ifelse(tab$suggested_decision[chg] == "recompute", tab$suggested_value_min[chg], NA),
                    manually_corrected = FALSE,
                    problem_humanidentified = paste0("typed ", tab$raw_text[chg], " in a duration field: ", tab$class[chg]),
                    solution_humanidentified = ifelse(tab$suggested_decision[chg] == "recompute",
                                                      "recomputed as typed time minus bedtime (rule, tolerance/window in the scan)", "set to missing"),
                    stringsAsFactors = FALSE)
utils::write.csv(draft, file.path(out_dir, "metric_duration_corrections_DRAFT.csv"), row.names = FALSE)
cat("Wrote", file.path(out_dir, "metric_duration_corrections_DRAFT.csv"), "(", nrow(draft), "rows; not applied)\n")
utils::write.csv(tab, file.path(out_dir, "candidate_entries.csv"), row.names = FALSE)
utils::write.csv(ds_tab, file.path(out_dir, "candidate_strings.csv"), row.names = FALSE)
cat("\nWrote", file.path(out_dir, "candidate_entries.csv"), "(row level: keep it outside the repository)\n")
cat("Wrote", file.path(out_dir, "candidate_strings.csv"), "(one row per distinct text)\n")
