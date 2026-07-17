# ── cross_participant_field_misentry_check.R ─────────────────────────────────
# Detects "filling in wrong field" — when a participant enters a clock-time
# (bedtime, sleep-time, awake-time, getup-time) into a duration field (SOL, WASO).
#
# Detection: raw SOL as HH:MM string == raw time_sleep or time_bed HH:MM
#             raw WASO as HH:MM string == raw time_awake or time_getup HH:MM
#
# Runs on RAW data (pre-correction) because post-MM:SS parsing the HH:MM
# strings are already converted to numeric minutes.
#
# Output: cross_participant_field_misentries.csv
# ──────────────────────────────────────────────────────────────────────────────

cat("=== Field-Misentry Check: SOL/WASO vs time columns ===\n")

rds_path <- cfg_get("data.files.main_rds", "deidentified_intervalvars_forCD_111325.rds")
if (!file.exists(rds_path)) {
  stop(sprintf("Raw data not found: %s. Run from splsleep/ directory.", rds_path))
}

raw <- readRDS(rds_path)

# ── Per-row check: does the HH:MM string of SOL/WASO exactly match a time column? ──
raw$mis_sol_sleep <- !is.na(raw$duration_totalmin_sol_estimate_am) &
  !is.na(raw$time_sleep_am_hhmm) &
  raw$duration_totalmin_sol_estimate_am == raw$time_sleep_am_hhmm

raw$mis_sol_bed <- !is.na(raw$duration_totalmin_sol_estimate_am) &
  !is.na(raw$time_bed_am_hhmm) &
  raw$duration_totalmin_sol_estimate_am == raw$time_bed_am_hhmm

raw$mis_waso_awake <- !is.na(raw$duration_totalmin_waso_estimate_am) &
  !is.na(raw$time_awake_am_hhmm) &
  raw$duration_totalmin_waso_estimate_am == raw$time_awake_am_hhmm

raw$mis_waso_getup <- !is.na(raw$duration_totalmin_waso_estimate_am) &
  !is.na(raw$time_getup_am_hhmm) &
  raw$duration_totalmin_waso_estimate_am == raw$time_getup_am_hhmm

raw$mis_sol_any <- raw$mis_sol_sleep | raw$mis_sol_bed
raw$mis_waso_any <- raw$mis_waso_awake | raw$mis_waso_getup

# ── Build flagged output ─────────────────────────────────────────────────────
flagged_idx <- which(raw$mis_sol_any | raw$mis_waso_any)
n_flag <- length(flagged_idx)

if (n_flag > 0) {
  keep_cols <- c("pid", "day_num", "row_id",
    "duration_totalmin_sol_estimate_am",
    "duration_totalmin_waso_estimate_am",
    "time_bed_am_hhmm", "time_bed_am_ampm",
    "time_sleep_am_hhmm", "time_sleep_am_ampm",
    "time_awake_am_hhmm", "time_awake_am_ampm",
    "time_getup_am_hhmm", "time_getup_am_ampm",
    "mis_sol_sleep", "mis_sol_bed",
    "mis_waso_awake", "mis_waso_getup")

  flagged_out <- flagged_idx
  mis_cols <- c("mis_sol_sleep", "mis_sol_bed", "mis_waso_awake", "mis_waso_getup")
  flagged <- cbind(raw[flagged_idx, intersect(keep_cols, names(raw))],
    raw[flagged_idx, mis_cols])
  flagged$misentry_type <- ifelse(
    flagged$mis_sol_sleep, "SOL=time_sleep",
    ifelse(flagged$mis_sol_bed, "SOL=time_bed",
    ifelse(flagged$mis_waso_awake, "WASO=time_awake",
    ifelse(flagged$mis_waso_getup, "WASO=time_getup", "unknown"))))
  flagged$value_in_min <- ifelse(
    grepl("^SOL", flagged$misentry_type),
    as.numeric(sub(":.*", "", flagged$duration_totalmin_sol_estimate_am)) * 60 +
      as.numeric(sub(".*:", "", flagged$duration_totalmin_sol_estimate_am)),
    as.numeric(sub(":.*", "", flagged$duration_totalmin_waso_estimate_am)) * 60 +
      as.numeric(sub(".*:", "", flagged$duration_totalmin_waso_estimate_am)))

  write.csv(flagged, "cross_participant_field_misentries.csv", row.names = FALSE)
  cat(sprintf("  Wrote cross_participant_field_misentries.csv (%d rows)\n", n_flag))

  # Summary
  sol_rows <- flagged$mis_sol_sleep | flagged$mis_sol_bed
  waso_rows <- flagged$mis_waso_awake | flagged$mis_waso_getup
  n_pid_sol <- length(unique(flagged$pid[sol_rows]))
  n_pid_waso <- length(unique(flagged$pid[waso_rows]))
  cat(sprintf("  SOL field-misentries: %d rows across %d PIDs\n",
    sum(sol_rows, na.rm=TRUE), n_pid_sol))
  cat(sprintf("  WASO field-misentries: %d rows across %d PIDs\n",
    sum(waso_rows, na.rm=TRUE), n_pid_waso))

  # PID-level summary
  sol_pids <- unique(flagged$pid[sol_rows])
  waso_pids <- unique(flagged$pid[waso_rows])
  if (length(sol_pids) > 0) {
    cat(sprintf("  SOL-misentry PIDs: %s\n",
      paste(sort(sol_pids), collapse=", ")))
  }
  if (length(waso_pids) > 0) {
    cat(sprintf("  WASO-misentry PIDs: %s\n",
      paste(sort(waso_pids), collapse=", ")))
  }

} else {
  cat("  No field-misentries found\n")
  write.csv(data.frame(), "cross_participant_field_misentries.csv", row.names = FALSE)
}

cat("=== [cross_participant_field_misentry_check] Finished ===\n")
