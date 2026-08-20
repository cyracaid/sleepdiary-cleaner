#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# verify_reference_fidelity.R  --  S5
#
# The validation that v1.3 left out.
#
# WHY THIS EXISTS
# ---------------
# verify_v1_3_snapshot.R compares "sleepcleanr old path" against "sleepcleanr S3
# chain". It proves the refactor did not change results. It CANNOT prove that# sleepcleanr is faithful to the reference implementation
# (R01_online_sleepdiary_manualclean / calculate_sleep_time_vars.R), because a
# deviation that predates the snapshot is carried by both sides and compares
# equal. B1 (sleeponset) sat undetected for exactly that reason.
#
# Internal-consistency testing and external-fidelity testing are two different
# things. This script is the second one.
#
# WHAT IT DOES
# ------------
#   PART 1  FORMULA CONTRACT   -- fails the run if an implemented formula no
#                                 longer matches its declared definition.
#                                 This is the regression guard: silently
#                                 editing a mutate() in
#                                 calculate_sleep_time_end.R breaks the build.
#
#   PART 2  FIDELITY REGISTER  -- reports, per metric, whether it has been
#                                 compared against the reference implementation
#                                 and what the verdict was. Metrics never
#                                 compared are listed as UNREVIEWED.
#
# Part 2 is the point. Before this script, "how many of our formulas has anyone
# actually checked against the reference?" had no answer anywhere in the repo.
# An unchecked assumption that nobody can see is how B1 survived.
#
#   Rscript verify_reference_fidelity.R           # contract only
#   Rscript verify_reference_fidelity.R --strict  # also fail on UNREVIEWED
#
# NOTE ON DEPENDENCIES: unlike verify_finalize_columns.R this is not
# zero-dependency -- calculate_sleep_time_vars_end() calls library(dplyr) and
# library(lubridate) itself. Those are pipeline dependencies anyway.
# From 2026-08-17 the function no longer attaches them (R CMD check flags
# library() in package code), so this script loads them explicitly.
# ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
})

strict <- "--strict" %in% commandArgs(trailingOnly = TRUE)

.pass <- 0L
.fail <- 0L

check <- function(label, expr) {
  ok <- tryCatch(isTRUE(expr), error = function(e) {
    structure(FALSE, msg = conditionMessage(e))
  })
  msg <- attr(ok, "msg")
  if (isTRUE(ok)) {
    .pass <<- .pass + 1L
    cat(sprintf("PASS  %s\n", label))
  } else {
    .fail <<- .fail + 1L
    cat(sprintf("FAIL  %s%s\n", label,
                if (!is.null(msg)) paste0("  [", msg, "]") else ""))
  }
  invisible(isTRUE(ok))
}

same <- function(a, b, tol = 1e-8) {
  if (length(a) != length(b)) return(FALSE)
  na <- is.na(a); nb <- is.na(b)
  if (!identical(na, nb)) return(FALSE)
  if (all(na)) return(TRUE)
  if (inherits(a, "POSIXct") || inherits(b, "POSIXct")) {
    return(isTRUE(all(as.numeric(a[!na]) == as.numeric(b[!nb]))))
  }
  isTRUE(all(abs(as.numeric(a[!na]) - as.numeric(b[!nb])) < tol))
}

cat("\n=== S5: reference-fidelity verification ===\n")
cat(if (strict) "mode: STRICT (UNREVIEWED metrics fail the run)\n\n"
    else        "mode: default (UNREVIEWED metrics are reported, not failed)\n\n")

# ---------------------------------------------------------------------------
# Locate the implementation
# ---------------------------------------------------------------------------
fn_path <- file.path("inst", "scripts", "calculate_sleep_time_end.R")
if (!file.exists(fn_path)) fn_path <- "calculate_sleep_time_end.R"
if (!file.exists(fn_path)) {
  cat("FAIL  calculate_sleep_time_end.R not found\n"); quit(status = 1)
}
fn_path <- normalizePath(fn_path)          # absolute: we chdir below
suppressMessages(suppressWarnings(source(fn_path)))

# DANGER, and the reason for the sandbox below.
#
# calculate_sleep_time_vars_end() is named as though it only computes metrics,
# but its last act before return() is:
#
#     dir.create("output", showWarnings = FALSE)
#     saveRDS(cleaned_data, "output/corrected_ema_data.rds")
#
# Calling it from the repo root therefore OVERWRITES the real-data pipeline
# output with whatever was passed in -- here, a 3-row fixture. Every call is
# run inside a throwaway directory so the fixture can never touch output/.
# See open_issues (hidden write side effect in a compute function).
run_sandboxed <- function(expr) {
  old <- getwd()
  tmp <- file.path(tempdir(), paste0("s5_", as.integer(Sys.time())))
  dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
  on.exit(setwd(old), add = TRUE)
  setwd(tmp)
  force(expr)
}

# Baseline for the fidelity comparison.
#
# On 2026-08-09 this was recorded as "the reference implementation is not in
# the repo". That was wrong -- it was a search failure. The pre-deviation
# formulas live in the archived 2026-05-19 package, under the name
# calculate_sleep_time_end.R, not calculate_sleep_time_vars.R. Searching by
# filename missed it; searching by content (self_diffcalc_sleeponset) found it
# immediately.
#
# Caveat on provenance: this is sleepcleanr's OWN 2026-05-19 ancestor, not the
# upstream R01_online_sleepdiary_manualclean file. The screenshot of R01 that
# prompted the B1 audit reads "+ time_sleep_am_hhmm_ampm" where this reads
# "+ time_sleep_corrected" -- same lineage, not the same file. So this baseline
# answers "have our formulas drifted from where they started", which is what
# the register below claims, and nothing stronger.
# The original lives under archive/, which is gitignored -- it holds real-data
# visualisation CSVs and can never be committed. Pointing the baseline there
# would make this check pass locally and silently find nothing in CI. So the
# file (source code only, no participant data) is vendored into
# inst/verification/ and that copy is canonical.
BASELINE_DEFAULT <- file.path("inst", "verification",
                              "baseline_formulas_2026-05-19.R")
BASELINE_ORIGIN  <- file.path("archive", "2026-07-25",
                              "spl_pipeline_package_2026-05-19", "sleepcleanr",
                              "calculate_sleep_time_end.R")
ref_path <- Sys.getenv("SPLSLEEP_REFERENCE_IMPL", BASELINE_DEFAULT)
ref_available <- nzchar(ref_path) && file.exists(ref_path)

# ---------------------------------------------------------------------------
# Fixture -- hand-built, values chosen so every expected number is checkable
# by hand from the timestamps alone.
# ---------------------------------------------------------------------------
ts <- function(x) as.POSIXct(x, tz = "UTC")

fx <- data.frame(
  pid     = c(1L, 2L, 3L),
  day_num = c(1L, 1L, 1L),
  row_id  = 1:3,
  # R1 ordinary night | R2 zero try-sleep window | R3 WASO exceeds sleep period
  time_bed_corrected   = ts(c("2021-01-01 23:00", "2021-01-01 23:00", "2021-01-01 23:00")),
  time_sleep_corrected = ts(c("2021-01-01 23:30", "2021-01-02 07:00", "2021-01-01 23:30")),
  time_awake_corrected = ts(c("2021-01-02 07:00", "2021-01-02 07:00", "2021-01-02 01:30")),
  time_getup_corrected = ts(c("2021-01-02 07:30", "2021-01-02 07:30", "2021-01-02 02:00")),
  duration_totalmin_sol_estimate_am_mincalc  = c(25,  10,  25),
  duration_totalmin_waso_estimate_am_mincalc = c(20,   0, 200),
  num_waso_estimate_am                       = c( 2,   0,   3),
  # Not used by any formula, but Block 1b builds has_correction from these and
  # dplyr::case_when() errors on a NULL condition rather than treating the
  # column as absent.
  corrected          = c(FALSE, TRUE,  TRUE),
  manually_corrected = c(FALSE, FALSE, TRUE),
  stringsAsFactors = FALSE
)

out <- run_sandboxed(
  suppressMessages(suppressWarnings(calculate_sleep_time_vars_end(fx))))

# ---------------------------------------------------------------------------
# PART 1  --  FORMULA CONTRACT
#
# Each entry states the formula in words and recomputes it independently from
# the fixture. If calculate_sleep_time_end.R is edited so a metric no longer
# matches its stated definition, the corresponding check fails.
# ---------------------------------------------------------------------------
cat("-- Part 1: formula contract --\n")

mins <- function(a, b) as.numeric(difftime(a, b, units = "mins"))

sol         <- mins(fx$time_sleep_corrected, fx$time_bed_corrected)
sleeponset  <- fx$time_sleep_corrected
trysleep    <- mins(fx$time_awake_corrected, fx$time_sleep_corrected)
timeinbed   <- mins(fx$time_getup_corrected, fx$time_bed_corrected)
sleepperiod <- mins(fx$time_awake_corrected, sleeponset)

waso_raw    <- fx$duration_totalmin_waso_estimate_am_mincalc
waso_used   <- ifelse(is.na(waso_raw) | waso_raw < 0 |
                        (!is.na(sleepperiod) & waso_raw > sleepperiod),
                      NA_real_, waso_raw)
tst         <- sleepperiod - waso_used
se          <- ifelse(!is.na(trysleep) & trysleep > 0, tst / trysleep, NA_real_)
avg_bout    <- ifelse(!is.na(waso_used) & !is.na(fx$num_waso_estimate_am) &
                        fx$num_waso_estimate_am > 0,
                      waso_used / fx$num_waso_estimate_am, NA_real_)

check("SOL = sleep - bed",
      same(out$self_diffcalc_sol_minutes, sol))
check("sleeponset = time_sleep_corrected (NO self-reported SOL added)",
      same(out$self_diffcalc_sleeponset, sleeponset))
check("try-sleep = awake - sleep",
      same(out$self_diffcalc_totaltrysleep_minutes, trysleep))
check("time-in-bed = getup - bed",
      same(out$self_diffcalc_timeinbed_minutes, timeinbed))
check("sleep period = awake - sleeponset",
      same(out$self_diffcalc_sleepperiod_minutes, sleepperiod))
check("TST = sleep period - trusted WASO",
      same(out$self_diffcalc_totalsleeptime_minutes, tst))
check("SE = TST / try-sleep (0-1 fraction, NA when try-sleep <= 0)",
      same(out$self_diffcalc_sleepefficiency_percent, se))
check("avg WASO bout = trusted WASO / bout count",
      same(out$avg_waso_estimate_am_minutes, avg_bout))

cat("\n-- Part 1b: guard rails these formulas depend on --\n")

# R2: try-sleep is exactly 0. A bare division would give Inf, and is.na(Inf) is
# FALSE, so na.rm = TRUE would NOT remove it from any downstream mean().
check("zero try-sleep yields NA efficiency, never Inf",
      is.na(out$self_diffcalc_sleepefficiency_percent[2]) &&
        !any(is.infinite(out$self_diffcalc_sleepefficiency_percent), na.rm = TRUE))

# R3: self-reported WASO larger than the whole sleep period cannot be true.
check("WASO exceeding the sleep period is refused, TST becomes NA",
      identical(out$waso_duration_for_metrics_status[3],
                "untrusted_exceeds_sleep_period") &&
        is.na(out$self_diffcalc_totalsleeptime_minutes[3]))

check("refused WASO also suppresses the derived bout average",
      is.na(out$avg_waso_estimate_am_minutes[3]))

# Contract columns are pure unit conversions of the above.
check("sleep_efficiency_pct = efficiency * 100",
      same(out$sleep_efficiency_pct, out$self_diffcalc_sleepefficiency_percent * 100))
check("sol_h = SOL / 60",
      same(out$sol_h, out$self_diffcalc_sol_minutes / 60))
check("sleep_duration_h = TST / 60",
      same(out$sleep_duration_h, out$self_diffcalc_totalsleeptime_minutes / 60))

# The fixture must never reach the real delivery artefacts. If this fails the
# sandbox leaked and output/corrected_ema_data.rds has just been destroyed.
check("fixture did not overwrite output/corrected_ema_data.rds",
      !file.exists(file.path("output", "corrected_ema_data.rds")) ||
        nrow(readRDS(file.path("output", "corrected_ema_data.rds"))) != nrow(fx))

# ---------------------------------------------------------------------------
# PART 2  --  FIDELITY REGISTER
#
# status:
#   MATCHES    formula compared against the reference and found identical
#   DEVIATION  differs from the reference, deviation reviewed and approved
#   UNREVIEWED never compared -- an assumption, not a finding
# ---------------------------------------------------------------------------
reg <- data.frame(
  metric = c("sol_minutes", "sleeponset", "totaltrysleep_minutes",
             "timeinbed_minutes", "sleepperiod_minutes",
             "totalsleeptime_minutes", "sleepefficiency_percent",
             "avg_waso_bout_minutes"),
  status = c("MATCHES", "DEVIATION", "MATCHES", "MATCHES",
             "MATCHES", "DEVIATION", "DEVIATION", "DEVIATION"),
  evidence = c(
    "baseline L119 difftime(sleep_corrected, bed_corrected) -- identical",
    "baseline L126 adds minutes(sol_mincalc); sleepcleanr does not. B1, approved 2026-08-09, work log section 1",
    "baseline L131 difftime(awake, sleep) -- identical",
    "baseline L138 difftime(getup, bed) -- identical",
    "baseline L144 difftime(awake, sleeponset) -- identical formula (values differ only via sleeponset)",
    "baseline L150 subtracts raw waso_mincalc; sleepcleanr subtracts waso_mincalc_used. B2 trust gate, approved 2026-08-09",
    "baseline L158 bare TST/trysleep; sleepcleanr guards trysleep <= 0 to NA. Without it a zero window yields Inf, and is.na(Inf) is FALSE",
    "baseline L167 bare waso/num_waso; sleepcleanr requires trusted WASO and num_waso > 0"
  ),
  stringsAsFactors = FALSE
)

# All four deviations are deliberate and documented. Three are guards added
# after the baseline (B2 trust gate, the SE zero-divide guard, the bout guard);
# only B1 changes what a metric means. Nothing here is an unreviewed accident.

cat("\n-- Part 2: fidelity against the reference implementation --\n\n")
w <- max(nchar(reg$metric))
for (i in seq_len(nrow(reg))) {
  cat(sprintf("  %-*s  %-10s  %s\n", w, reg$metric[i], reg$status[i], reg$evidence[i]))
}

n_unrev <- sum(reg$status == "UNREVIEWED")

n_dev <- sum(reg$status == "DEVIATION")

cat("\n  baseline: ")
if (ref_available) {
  cat(ref_path, "\n")
  cat("  (sleepcleanr's own 2026-05-19 ancestor -- same lineage as the upstream\n")
  cat("   R01 file, not byte-identical to it. Answers 'have our formulas\n")
  cat("   drifted from where they started', nothing stronger.)\n")
} else {
  cat("NOT FOUND at ", ref_path, "\n", sep = "")
  cat("  The register above was written against that file. Without it the\n")
  cat("  statuses cannot be re-derived, so they are unverifiable claims.\n")
  cat("  Origin (gitignored, local only): ", BASELINE_ORIGIN, "\n", sep = "")
}

# A missing baseline must not pass quietly in strict mode. The whole point of
# vendoring the file was that a CI run with no baseline would otherwise print
# the register verbatim and exit 0, asserting comparisons nobody could check.
check("baseline file is present (register is re-derivable)", ref_available)

cat(sprintf("\n  %d identical, %d deviating, %d unreviewed.\n",
            sum(reg$status == "MATCHES"), n_dev, n_unrev))
if (n_dev > 0) {
  cat("  Every deviation is deliberate and documented: three are guards added\n")
  cat("  after the baseline (B2 trust gate, SE zero-divide, bout guard); only\n")
  cat("  B1 changes what a metric means.\n")
}
if (n_unrev > 0) {
  cat(sprintf("\n  %d metric(s) NEVER compared. These are assumptions, not\n", n_unrev))
  cat("  findings. B1 was one of these until 2026-08-09, and it shifted mean\n")
  cat("  TST by roughly 29 minutes.\n")
}

# ---------------------------------------------------------------------------
cat(sprintf("\n%d passed, %d failed\n", .pass, .fail))

if (.fail > 0L) {
  cat("\nFORMULA CONTRACT BROKEN. A metric no longer matches its declared\n")
  cat("definition -- either the change was intentional and this script must be\n")
  cat("updated in the same commit, or it was accidental.\n")
  quit(status = 1)
}

if (strict && n_unrev > 0) {
  cat(sprintf("\nSTRICT: %d metric(s) UNREVIEWED against the reference.\n", n_unrev))
  quit(status = 1)
}

cat("Formula contract holds.")
cat(if (n_unrev > 0) sprintf(" %d metric(s) still UNREVIEWED.\n", n_unrev) else "\n")
