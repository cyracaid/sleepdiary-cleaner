# Clock-time rule for SOL / WASO text the interval parser had to reinterpret.
#
# The study asked for a duration ("How long ... ? Format: HH:MM"). Some participants typed a clock time instead
# (for example the time they fell asleep, or the time they woke in the night). The parser reads such text under
# the MM:SS rule or the dd:00 rule and returns a small, plausible number, which is wrong when the text was a
# clock time. This step looks only at rows the parser already reinterpreted and applies the rule agreed on
# 2026-10-30:
#   - minutes typed in the hours slot (the text ends in :00, e.g. "5:00"): keep the parser's minutes;
#   - SOL, typed time within `tolerance_min` of the recorded sleep onset and 0 to `window_min` minutes after the
#     recorded bedtime (12-hour dial, because no AM/PM was typed): SOL = typed time - bedtime;
#   - SOL, typed time closer to the recorded bedtime than to the sleep onset: SOL set to missing;
#   - WASO, text not ending in :00: set to missing (a clock time cannot be turned back into a duration);
#   - everything else (ties, near but outside the tolerance, unclear): value left as parsed, still flagged by Step 8.
# Rows a person has already corrected (`manually_corrected`) are never touched. Every row seen gets a line in
# output/duration_clock_rule_log.csv, and every changed value gets a note in the *_correctionsmade column.
#' @noRd
apply_duration_clock_rule <- function(data, cfg = NULL) {
  cat("\n=== Clock-time rule for reinterpreted SOL / WASO text ===\n")
  if (!isTRUE(cfg_get("duration_clock_rule.enabled", TRUE, cfg = cfg))) {
    cat("  disabled in the config - skipping\n")
    return(data)
  }
  tol  <- as.numeric(cfg_get("duration_clock_rule.tolerance_min", 5,  cfg = cfg))
  win  <- as.numeric(cfg_get("duration_clock_rule.window_min",    60, cfg = cfg))
  near <- as.numeric(cfg_get("duration_clock_rule.near_min",      15, cfg = cfg))

  tod <- function(t) as.numeric(format(t, "%H")) * 60 + as.numeric(format(t, "%M"))
  d12 <- function(a, b) { d <- abs((a - b) %% 720); pmin(d, 720 - d) }
  have_times <- all(c("time_bed_corrected", "time_sleep_corrected") %in% names(data))
  bed <- if (have_times) tod(data$time_bed_corrected)   else rep(NA_real_, nrow(data))
  slp <- if (have_times) tod(data$time_sleep_corrected) else rep(NA_real_, nrow(data))
  manual <- if ("manually_corrected" %in% names(data)) data$manually_corrected %in% TRUE else rep(FALSE, nrow(data))

  log_rows <- list()
  for (field in c("sol", "waso")) {
    var <- paste0("duration_totalmin_", field, "_estimate_am")
    mc <- paste0(var, "_mincalc"); nt <- paste0(var, "_correctionsmade")
    io <- paste0(var, "_input_orig"); ro <- paste0(var, "_raw_orig"); ab <- paste0(var, "_ambig")
    if (!all(c(mc, nt) %in% names(data))) next
    txt <- if (io %in% names(data)) data[[io]] else if (ro %in% names(data)) data[[ro]] else next
    note <- data[[nt]]
    touched <- (if (ab %in% names(data)) data[[ab]] %in% TRUE else rep(FALSE, nrow(data))) |
               (!is.na(note) & grepl("MM:SS|dd:00", note))
    for (i in which(touched & !manual)) {
      m <- regmatches(trimws(txt[i]), regexec("^([0-9]{1,3}):([0-9]{2})$", trimws(txt[i])))[[1]]
      if (length(m) != 3) next
      h <- as.numeric(m[2]); mi <- as.numeric(m[3]); typed <- h * 60 + mi
      before <- data[[mc]][i]; after <- before; action <- "kept"; cls <- NULL
      if (mi == 0 && !(field == "sol" && !is.na(slp[i]) && min(d12(typed, slp[i]), d12(typed, bed[i])) <= near)) {
        cls <- "minutes typed in the hours slot"
      } else if (field == "waso") {
        cls <- "WASO probable clock time"; after <- NA_real_; action <- "set to missing"
      } else if (is.na(bed[i]) || is.na(slp[i])) {
        cls <- "SOL clock-like, own times unavailable"
      } else {
        ds <- d12(typed, slp[i]); db <- d12(typed, bed[i]); dd <- (typed - bed[i]) %% 720
        if (ds <= tol && dd <= win && db > ds) {
          cls <- "SOL typed sleep onset"; after <- dd; action <- "recomputed"
        } else if (db < ds && db <= near) {
          cls <- "SOL typed bedtime"; after <- NA_real_; action <- "set to missing"
        } else {
          cls <- "SOL clock-like, left for review"
        }
      }
      if (action != "kept") {
        data[[mc]][i] <- after
        add <- sprintf("clock-time rule: %s; typed %s; %s (%s -> %s min)", cls, trimws(txt[i]), action,
                       format(round(before, 2)), format(round(after, 2)))
        data[[nt]][i] <- if (is.na(note[i]) || note[i] == "") add else paste(note[i], add, sep = "; ")
      }
      log_rows[[length(log_rows) + 1L]] <- data.frame(
        pid = data$pid[i], day_num = data$day_num[i], row_id = data$row_id[i], field = toupper(field),
        raw_text = trimws(txt[i]), class = cls, action = action,
        minutes_before = before, minutes_after = after, stringsAsFactors = FALSE)
    }
  }
  lg <- if (length(log_rows)) do.call(rbind, log_rows) else
    data.frame(pid = character(0), day_num = character(0), row_id = character(0), field = character(0),
               raw_text = character(0), class = character(0), action = character(0),
               minutes_before = numeric(0), minutes_after = numeric(0))
  out_dir <- cfg_get("output.report.dir", "output", cfg = cfg)
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  utils::write.csv(lg, file.path(out_dir, "duration_clock_rule_log.csv"), row.names = FALSE)
  cat(sprintf("  Reinterpreted entries seen: %d; recomputed: %d; set to missing: %d; kept: %d\n",
              nrow(lg), sum(lg$action == "recomputed"), sum(lg$action == "set to missing"), sum(lg$action == "kept")))
  cat(sprintf("  Each entry and what was done: %s\n", file.path(out_dir, "duration_clock_rule_log.csv")))
  data
}
