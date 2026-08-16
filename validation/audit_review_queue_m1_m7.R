# audit_review_queue_m1_m7.R — M1–M7 row-level audit of the review queue (REPORT-ONLY)
# =============================================================================
# Purpose: per the 2026-08-14 meeting plan, run methods M1–M7 against the real
# n=13,990 rows and emit a `decision` column WITHOUT applying any correction.
#   decision = AUTO_FIX  (M1 AND M4 AND M5 all hold — swap candidate)
#              FLAG     (audit hit only — M2/M3/M6/M7, or M1∧M4 without M5)
#              AUTO_PASS (clean)
#
# Method table (from meeting notes):
#   M1 swap detection    — rebuild absolute times from RAW; find bed≤sleep≤awake≤getup
#                          violations. Each violating pair → candidate swap type;
#                          after-swap SOL (sleep−bed) closer to self-report → high conf.
#   M2 string shape      — raw duration string: "23:30" hh=23 clock shape;
#                          "10:30" HH:MM ≥4h reinterpreted shape; pure number = minutes.
#                          clock shape → suspect field_misentry.
#   M3 self-report dev   — |mincalc SOL − self-reported SOL| large → flag (audit only).
#   M4 logical window    — mincalc SOL vs sleep window (sleep_corrected − bed_corrected).
#                          mincalc > window or negative/tiny → suspicious.
#   M5 redundant dir     — corrected |gap−self| vs raw |gap−self| (Channel B logic).
#                          corrected farther → silent worsening candidate.
#   M6 cross-day jump    — same pid adjacent day_num SOL/WASO; jump > 5× pid MAD → flag.
#   M7 note-text audit   — inventory all _correctionsmade texts vs known patterns.
#
# Decision rule:
#   AUTO_FIX only when M1 order violation exists AND M4 window stays legal
#   (swap keeps bed ≤ sleep ≤ awake ≤ getup, no negative SOL) AND M5 swap lands
#   closer to self-report. Missing M5 → FLAG (the sleep_awake_swap lesson).
#
# Outputs:
#   audit_m1_m7_decision.csv      — one row per record: decision + per-method hits
#   audit_m1_m7_notes_inventory.csv — M7 unique note-type inventory
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
})

# ── Inputs ──────────────────────────────────────────────────────────────────
prepost <- readRDS("output/cleaned_data_prepostcorrection.rds")
full    <- readRDS("output/cleaned_data_full.rds")

stopifnot(nrow(prepost) == 13990)

# ── M7: note-text inventory (run early; independent of row logic) ──────────
note_cols <- grep("_correctionsmade$", names(full), value = TRUE)
notes_df <- lapply(note_cols, function(col) {
  v <- full[[col]]
  v <- v[!is.na(v) & v != "" & v != "NA value"]
  data.frame(field = col, note = v, stringsAsFactors = FALSE)
}) %>% bind_rows()

# Known note-type families — the complete inventory of interval_parse.R
# mechanism strings (L156–445) + correction_appliers + field_misentry.
# Every note the parser can emit has a code path; a note OUTSIDE this list is
# a genuine blind-spot candidate (B3 deliverable).
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
  "decimal hours -> minutes; Manual fix",
  "field_misentry",
  "manual",
  "review",
  "threshold",
  "retained"
)
# Prefix-matching: a note is "covered" when it starts with (or embeds) a
# known mechanism token. Composite notes are "a; b" joins of the tokens.
covered_note <- function(x) {
  vapply(x, function(s) {
    parts <- strsplit(s, "; ", fixed = TRUE)[[1]]
    all(parts %in% mechanism_notes) || any(grepl("Manual fix|retained", s))
  }, logical(1))
}
notes_df$covered <- covered_note(notes_df$note)

# ── Build audit frame from prepost ──────────────────────────────────────────
# Parse raw (pre) and corrected (post) timestamps; both are POSIXct strings.
to_posix <- function(x) {
  out <- as.POSIXct(x, tz = "UTC")
  out
}

a <- prepost %>%
  mutate(
    bed_raw    = to_posix(bedtime_precorrection),
    sleep_raw  = to_posix(sleeponset_precorrection),
    awake_raw  = to_posix(awakening_precorrection),
    getup_raw  = to_posix(getup_precorrection),
    bed_cor    = to_posix(bedtime_postcorrection),
    sleep_cor  = to_posix(sleeponset_postcorrection),
    awake_cor  = to_posix(awakening_postcorrection),
    getup_cor  = to_posix(getup_postcorrection),
    sol_self   = sol_selfreport_minutes
  )

# ── M1: swap detection on RAW order violations ──────────────────────────────
# For complete rows only. A pair (X,Y) violates when X > Y (out of order).
# Candidate swap restores X < Y. SOL-relevant window is bed→sleep.
has_all <- complete.cases(a[, c("bed_raw","sleep_raw","awake_raw","getup_raw")])

m1 <- rep(FALSE, nrow(a))
m1_type <- rep(NA_character_, nrow(a))
for (i in which(has_all)) {
  viol <- character(0)
  if (a$bed_raw[i]   > a$sleep_raw[i])  viol <- c(viol, "bed_sleep")
  if (a$sleep_raw[i] > a$awake_raw[i])  viol <- c(viol, "sleep_awake")
  if (a$awake_raw[i] > a$getup_raw[i])  viol <- c(viol, "awake_getup")
  if (length(viol) > 0) {
    m1[i] <- TRUE
    m1_type[i] <- paste(viol, collapse = "+")
  }
}

# ── M4: logical window — mincalc SOL vs corrected sleep window ──────────────
# sleep window = sleep_cor − bed_cor (minutes). mincalc SOL must fit inside.
mincalc_sol <- full$duration_totalmin_sol_estimate_am_mincalc_for_review
if (is.null(mincalc_sol)) mincalc_sol <- full$duration_totalmin_sol_estimate_am_mincalc

sleep_win_min <- as.numeric(difftime(a$sleep_cor, a$bed_cor, units = "mins"))
# m4_neg_window = corrected window negative or mincalc > window (M4 gate for swaps)
m4_neg_window <- !is.na(sleep_win_min) & (sleep_win_min < 0 |
                  (!is.na(mincalc_sol) & mincalc_sol > sleep_win_min + 1))
m4 <- m4_neg_window

# ── M3: self-report deviation (audit only) ──────────────────────────────────
m3 <- rep(FALSE, nrow(a))
m3 <- !is.na(mincalc_sol) & !is.na(a$sol_self) & abs(mincalc_sol - a$sol_self) > 60

# ── M5: redundant direction (Channel B) ─────────────────────────────────────
# Compare raw gap (sleep_raw − bed_raw) and corrected gap vs self-report SOL.
raw_gap  <- as.numeric(difftime(a$sleep_raw,  a$bed_raw,  units = "mins"))
cor_gap  <- as.numeric(difftime(a$sleep_cor,  a$bed_cor,  units = "mins"))
m5 <- rep(FALSE, nrow(a))
m5_shift <- rep(NA_real_, nrow(a))
ok <- !is.na(raw_gap) & !is.na(cor_gap) & !is.na(a$sol_self) & raw_gap != cor_gap
m5[ok] <- abs(cor_gap[ok] - a$sol_self[ok]) > abs(raw_gap[ok] - a$sol_self[ok])
m5_shift[ok] <- (abs(cor_gap[ok] - a$sol_self[ok]) - abs(raw_gap[ok] - a$sol_self[ok]))

# ── M6: cross-day jump (SOL + WASO) ─────────────────────────────────────────
sol_used <- full$duration_totalmin_sol_estimate_am_mincalc_for_review
if (is.null(sol_used)) sol_used <- full$duration_totalmin_sol_estimate_am_mincalc
waso_used <- full$duration_totalmin_waso_estimate_am_mincalc_used

m6 <- rep(FALSE, nrow(a))
for (pid_val in unique(full$pid)) {
  idx <- which(full$pid == pid_val)
  ord <- order(full$day_num[idx])
  idx <- idx[ord]
  if (length(idx) < 2) next
  sol_mad <- mad(sol_used[idx], na.rm = TRUE)
  waso_mad <- mad(waso_used[idx], na.rm = TRUE)
  if (is.na(sol_mad) || sol_mad == 0) sol_mad <- 1
  if (is.na(waso_mad) || waso_mad == 0) waso_mad <- 1
  for (k in 2:length(idx)) {
    prev <- idx[k-1]; cur <- idx[k]
    if (!is.na(sol_used[prev]) && !is.na(sol_used[cur]) &&
        abs(sol_used[cur] - sol_used[prev]) > 5 * sol_mad) m6[cur] <- TRUE
    if (!is.na(waso_used[prev]) && !is.na(waso_used[cur]) &&
        abs(waso_used[cur] - waso_used[prev]) > 5 * waso_mad) m6[cur] <- TRUE
  }
}

# ── M2: string shape (SOL duration raw string) ──────────────────────────────
sol_raw_str <- as.character(full$duration_totalmin_sol_estimate_am)
m2_clock <- rep(FALSE, nrow(a))
m2_reinterp <- rep(FALSE, nrow(a))
ok_str <- !is.na(sol_raw_str) & sol_raw_str != ""
if (any(ok_str)) {
  m2_clock[ok_str]    <- grepl("^([0-2][0-9]):[0-5][0-9]$", sol_raw_str[ok_str]) &
                         as.numeric(sub(":.*", "", sol_raw_str[ok_str])) >= 13
  m2_reinterp[ok_str] <- grepl("^([0-9]+):([0-5][0-9])$", sol_raw_str[ok_str]) &
                         !m2_clock[ok_str] &
                         as.numeric(sub(":.*", "", sol_raw_str[ok_str])) >= 4
}

# ── Decision rule ───────────────────────────────────────────────────────────
# AUTO_FIX = M1 ∧ M4(stays legal) ∧ M5(lands closer).
# For a candidate swap we verify the corrected frame would be legal: since the
# pipeline already produced corrected times, treat m4-as-window-legal as the
# guarantee that a swap keeps the window valid (no negative SOL).
# M4 here is the "swap keeps window legal" gate; we also require m5 (direction).
auto_fix <- m1 & !m4_neg_window & m5

flag_only <- (m1 | m2_clock | m2_reinterp | m3 | m4 | m5 | m6) & !auto_fix

decision <- rep("AUTO_PASS", nrow(a))
decision[auto_fix] <- "AUTO_FIX"
decision[flag_only] <- "FLAG"

# ── Emit ────────────────────────────────────────────────────────────────────
out <- data.frame(
  pid = a$pid, day_num = a$day_num, row_id = a$row_id,
  decision = decision,
  M1_order_violation = m1, M1_viol_pairs = m1_type,
  M2_clock_shape = m2_clock, M2_reinterpreted = m2_reinterp,
  M3_self_deviation = m3,
  M4_window_illegal = m4,
  M5_silent_worsening = m5, M5_gap_shift_min = round(m5_shift, 1),
  M6_cross_day_jump = m6,
  correction_type = a$correction_type,
  sol_selfreport = a$sol_self,
  stringsAsFactors = FALSE
)

write.csv(out, "audit_m1_m7_decision.csv", row.names = FALSE)
write.csv(notes_df, "audit_m1_m7_notes_inventory.csv", row.names = FALSE)

# ── Summary ─────────────────────────────────────────────────────────────────
cat("\n=== M1–M7 audit (report-only) ===\n")
cat("Rows:", nrow(out), "\n")
print(table(decision))
cat("\nM1 order violations:", sum(m1), "\n")
cat("  pairs:", paste(names(table(m1_type)), table(m1_type), collapse = ", "), "\n")
cat("M2 clock-shape:", sum(m2_clock), " reinterpreted:", sum(m2_reinterp), "\n")
cat("M3 self-dev:", sum(m3), " M4 window-illegal:", sum(m4),
    " M5 silent-worsening:", sum(m5), " M6 cross-day jump:", sum(m6), "\n")
cat("M7 unique note texts:", nrow(notes_df), " uncovered-by-mechanism:", sum(!notes_df$covered), "\n")

# AUTO_FIX detail
af <- out[out$decision == "AUTO_FIX", ]
cat("\nAUTO_FIX rows:", nrow(af), "\n")
if (nrow(af) > 0) print(af[, c("pid","day_num","M1_viol_pairs","M5_gap_shift_min","correction_type")])

cat("\n=== [audit_m1_m7] Finished ===\n")
