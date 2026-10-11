# score_typing_task.R -- score the typing task: what people typed against the known
# truth, and what the pipeline did with it.
#
# Usage (from the repository root, with sleepcleanr installed):
#   Rscript validation/typing_task/score_typing_task.R <responses_dir_or_file> [out_dir]
# <responses_dir_or_file>: one CSV per participant as saved by typing_task_form.html, or a
# directory holding them. Participant answers are study data: keep them outside the
# repository. [out_dir] gets per_entry.csv and summary.csv (aggregate).
#
# For every entry: is any typed value wrong (against scenarios.csv)? and did the
# pipeline flag it, change it to the truth, change it to something else, or leave it?
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) >= 1)
src <- args[1]; out_dir <- if (length(args) >= 2) args[2] else NULL
here <- if (dir.exists("validation/typing_task")) "validation/typing_task" else "."
files <- if (dir.exists(src)) list.files(src, "[.]csv$", full.names = TRUE) else src
stopifnot(length(files) > 0)
resp <- do.call(rbind, lapply(files, function(f) read.csv(f, stringsAsFactors = FALSE, colClasses = "character")))
sc <- read.csv(file.path(here, "scenarios.csv"), stringsAsFactors = FALSE)
resp <- merge(resp, sc, by = "scenario_id", suffixes = c("", ".truth"), sort = FALSE)
n <- nrow(resp)

# ---- parsing what was typed (only to decide whether it equals the truth) ------
clock_min <- function(txt, ap) {
  t <- gsub("[[:space:]]", "", as.character(txt)); a <- toupper(trimws(as.character(ap)))
  m <- rep(NA_real_, length(t))
  p <- regmatches(t, regexec("^([0-9]{1,2})[:.]([0-9]{2})$", t))
  p4 <- regmatches(t, regexec("^([0-9]{1,2})([0-9]{2})$", t))
  for (i in seq_along(t)) {
    g <- if (length(p[[i]]) == 3) p[[i]] else if (length(p4[[i]]) == 3) p4[[i]] else NULL
    if (is.null(g) || !(a[i] %in% c("AM", "PM"))) next
    h <- as.numeric(g[2]); mi <- as.numeric(g[3])
    if (h < 1 || h > 12 || mi > 59) next
    m[i] <- (h %% 12) * 60 + mi + if (a[i] == "PM") 720 else 0
  }
  m
}
dur_min <- function(txt) {
  t <- tolower(gsub("[[:space:]]", "", as.character(txt)))
  v <- suppressWarnings(as.numeric(sub("min(utes?)?$", "", t)))
  hm <- regmatches(t, regexec("^([0-9]+):([0-9]{2})$", t))
  for (i in seq_along(t)) if (is.na(v[i]) && length(hm[[i]]) == 3) v[i] <- as.numeric(hm[[i]][2]) * 60 + as.numeric(hm[[i]][3])
  v
}
keys <- c("bed", "sleep", "awake", "getup")
typed <- sapply(keys, function(k) clock_min(resp[[paste0(k, "_time")]], resp[[paste0(k, "_ampm")]]))
truth <- sapply(keys, function(k) resp[[paste0(k, "_min")]])
typed_sol <- dur_min(resp$sol_typed); typed_waso <- dur_min(resp$waso_typed)
ok_t <- typed == truth; ok_t[is.na(ok_t)] <- FALSE
ok_sol <- !is.na(typed_sol) & typed_sol == resp$sol_min
ok_waso <- !is.na(typed_waso) & typed_waso == resp$waso_min
typed_ok <- rowSums(ok_t) == 4 & ok_sol & ok_waso

# ---- build the pipeline input in the diary layout and run the pipeline --------
pid <- as.integer(factor(resp$participant_id))
day <- as.integer(sub("^S", "", resp$scenario_id))
na <- rep(NA_real_, n)
inp <- data.frame(
  pid = pid, day_num = day, row_id = seq_len(n), StartDate = as.Date("2026-01-01") + day,
  time_bed_am_hhmm = resp$bed_time, time_bed_am_ampm = resp$bed_ampm,
  time_sleep_am_hhmm = resp$sleep_time, time_sleep_am_ampm = resp$sleep_ampm,
  time_awake_am_hhmm = resp$awake_time, time_awake_am_ampm = resp$awake_ampm,
  time_getup_am_hhmm = resp$getup_time, time_getup_am_ampm = resp$getup_ampm,
  duration_totalmin_sol_estimate_am = resp$sol_typed,
  duration_totalmin_waso_estimate_am = resp$waso_typed,
  duration_totalmin_napstoday_PM = na, exercisetoday_PM_totalmin_Light = na,
  exercisetoday_PM_totalmin_Moderate = na, exercisetoday_PM_totalmin_Vigorous = na,
  exercisetoday_PM_totalmin_Strength = na, num_waso_estimate_am = NA_integer_, num_waso_am = NA_integer_,
  caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1 = na, alcoholtoday_PM_NumAlcoholicDrinks_1 = na,
  nicotine_amount_pm_doses = na, cannabis_amount_pm_doses = na, has_na = FALSE,
  stringsAsFactors = FALSE)
proj <- file.path(tempdir(), "typing_task_run"); dir.create(proj, recursive = TRUE)
ext <- system.file("extdata", package = "sleepcleanr")
if (!nzchar(ext)) stop("sleepcleanr is not installed")
file.copy(file.path(ext, c("synthetic_config.yaml", list.files(ext, "^stub_.*[.]csv$"))), proj)
saveRDS(inp, file.path(proj, "main.rds"))
write.csv(data.frame(StartDate = inp$StartDate, num_waso_estimate_am = NA,
                     caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1 = NA,
                     alcoholtoday_PM_NumAlcoholicDrinks_1 = NA,
                     nicotine_amount_pm_doses = NA, cannabis_amount_pm_doses = NA),
          file.path(proj, "extra.csv"), row.names = FALSE)
cfg <- yaml::read_yaml(file.path(proj, "synthetic_config.yaml"))
cfg$data$files$main <- "main.rds"; cfg$data$files$extra <- "extra.csv"
yaml::write_yaml(cfg, file.path(proj, "cfg.yaml"))
suppressMessages(suppressWarnings(sleepcleanr::run_pipeline(config = file.path(proj, "cfg.yaml"),
                                  project_dir = proj, verbose = FALSE, skip_visualization = TRUE)))
res <- sleepcleanr::pipeline_results()
cd <- res$corrected_ema_data; rv <- res$review_output$data_with_flags

# ---- what the pipeline did -----------------------------------------------------
idx <- match(seq_len(n), cd$row_id)
mod <- function(x) { v <- as.POSIXct(x); as.numeric(format(v, "%H")) * 60 + as.numeric(format(v, "%M")) }
final <- sapply(keys, function(k) mod(cd[[paste0("time_", k, "_corrected")]])[idx])
final_sol <- as.numeric(cd$duration_totalmin_sol_estimate_am_mincalc)[idx]
final_waso <- as.numeric(cd$duration_totalmin_waso_estimate_am_mincalc)[idx]
f_ok <- final == truth; f_ok[is.na(f_ok)] <- FALSE
final_ok <- rowSums(f_ok) == 4 & !is.na(final_sol) & final_sol == resp$sol_min &
            !is.na(final_waso) & final_waso == resp$waso_min
q <- rv$needs_review_flag %in% TRUE
for (cc in grep("_checkforerrors$", names(rv), value = TRUE)) q <- q | (rv[[cc]] %in% TRUE)
flagged <- q[match(seq_len(n), rv$row_id)]; flagged[is.na(flagged)] <- FALSE
changed <- rowSums(!is.na(typed) & !is.na(final) & typed != final) > 0

outcome <- ifelse(typed_ok,
  ifelse(flagged, "no error, flagged", ifelse(changed, "no error, changed", "no error, untouched")),
  ifelse(final_ok & changed, "corrected to the truth",
  ifelse(changed, "changed to something else", ifelse(flagged, "flagged only", "left alone, still wrong"))))

kind <- ifelse(typed_ok, "none", vapply(seq_len(n), function(i) {
  w <- which(!ok_t[i, ])
  if (length(w) == 0) return("duration field")
  if (identical(keys[w], c("sleep", "awake")) && !is.na(typed[i, 2]) &&
      typed[i, 2] == truth[i, 3] && typed[i, 3] == truth[i, 2]) return("transposed times")
  if (all(!is.na(typed[i, w]) & (typed[i, w] - truth[i, w]) %% 720 == 0)) return("AM/PM")
  if (all(is.na(typed[i, w]))) return("unreadable or missing")
  "other time error"
}, character(1)))

per <- data.frame(participant = resp$participant_id, scenario_id = resp$scenario_id,
                  typed_ok, error_kind = kind, flagged, changed, final_ok, outcome)
cat(sprintf("\n%d entries from %d participants\n", n, length(unique(resp$participant_id))))
n_err <- sum(!typed_ok)
ci <- if (n_err > 0) binom.test(n_err, n)$conf.int else c(NA, NA)
cat(sprintf("entries with at least one wrong typed value: %d (%.1f%%, exact 95%% CI %.1f-%.1f%%)\n",
            n_err, 100 * n_err / n, 100 * ci[1], 100 * ci[2]))
cat("\nWhat the pipeline did, entries with a typed error:\n"); print(table(outcome[!typed_ok]))
cat("\nEntries typed correctly:\n"); print(table(outcome[typed_ok]))
cat("\nError kind by outcome:\n"); print(table(kind[!typed_ok], outcome[!typed_ok]))
handled <- sum(outcome %in% c("corrected to the truth", "flagged only"))
if (n_err > 0) cat(sprintf("\nflagged or corrected to the truth: %d of %d typed errors (%.1f%%)\n",
                            handled, n_err, 100 * handled / n_err))
if (!is.null(out_dir)) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  write.csv(per, file.path(out_dir, "per_entry.csv"), row.names = FALSE)
  s <- as.data.frame(table(error_kind = kind, outcome = outcome)); names(s)[3] <- "entries"
  write.csv(s, file.path(out_dir, "summary.csv"), row.names = FALSE)
  cat("\nwritten to", out_dir, "\n")
}
