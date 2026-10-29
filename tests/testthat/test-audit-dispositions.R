# Audit dispositions integration tests
#
# Covers the new ledger layer only; the dictionary-driven finalize-column
# behaviour stays in test-finalize-columns.R (one integration assertion added
# there). This file tests:
#   1. Roll-up: same-night SOL/WASO disagreement collapses to "mixed".
#   2. Default fill: no ledger file -> column all "none".
#   3. Hard guard: corrected_manual/set_na disposition without a matching
#      manual-correction record -> stop(), never a silent "mixed".
#   4. Algorithmic-only run (blank manual path): the audit layer is inactive,
#      nothing is attached and the run is not stopped.

withr::local_options(
  sleepcleanr.audit_ledger = tempfile(fileext = ".csv"),
  sleepcleanr.audit_manual_corrections = tempfile(fileext = ".csv")
)

.ledger <- function(rows) {
  d <- data.frame(pid = "1", day_num = 1, row_id = c(10L, 11L, 12L),
                  field = c("SOL", "SOL", "SOL"),
                  disposition = c("keep", "keep_flagged", "set_na"),
                  decided_by = "audit_20260820", annotators = "",
                  decision_date = "2026-08-20", evidence_note = "",
                  stringsAsFactors = FALSE)
  if (!missing(rows)) d <- rbind(d, rows)
  write.csv(d, getOption("sleepcleanr.audit_ledger"), row.names = FALSE)
  invisible(d)
}

test_that("row with SOL and WASO decided differently rolls up to mixed", {
  ledger <- data.frame(
    pid = "1", day_num = 1, row_id = c(7L, 7L),
    field = c("SOL", "WASO"),
    disposition = c("keep", "set_na"),
    decided_by = rep("audit_20260820", 2), annotators = rep("", 2),
    decision_date = rep("2026-08-20", 2), evidence_note = rep("", 2),
    stringsAsFactors = FALSE)
  write.csv(rbind(.ledger()[FALSE, ], ledger),
            getOption("sleepcleanr.audit_ledger"), row.names = FALSE)
  # matching manual record for the set_na WASO row so the guard passes
  manual <- data.frame(pid = "1", day_num = 1, row_id = 7L,
    variable = "duration_totalmin_waso_estimate_am", corrected_mincalc = "NA",
    stringsAsFactors = FALSE)
  write.csv(manual, getOption("sleepcleanr.audit_manual_corrections"),
            row.names = FALSE)

  dat <- data.frame(row_id = as.character(7:9), stringsAsFactors = FALSE)
  out <- audit_dispositions_attach(dat)
  expect_identical(out$audit_disposition[1], "mixed")
  expect_identical(out$audit_disposition[2:3], rep("none", 2))
})

test_that("missing ledger fills audit_disposition with none for every row", {
  unlink(getOption("sleepcleanr.audit_ledger"))
  dat <- data.frame(row_id = as.character(1:5), stringsAsFactors = FALSE)
  out <- audit_dispositions_attach(dat)
  expect_identical(out$audit_disposition, rep("none", 5))
})

test_that("set_na without a matching manual-correction record stops", {
  ledger <- data.frame(pid = "1", day_num = 1, row_id = 7L, field = "SOL",
    disposition = "set_na", decided_by = "audit_20260820", annotators = "",
    decision_date = "2026-08-20", evidence_note = "", stringsAsFactors = FALSE)
  write.csv(ledger, getOption("sleepcleanr.audit_ledger"), row.names = FALSE)
  write.csv(data.frame(pid = character(), day_num = integer(), row_id = integer(),
                       variable = character(), corrected_mincalc = character()),
            getOption("sleepcleanr.audit_manual_corrections"), row.names = FALSE)

  dat <- data.frame(row_id = as.character(7L), stringsAsFactors = FALSE)
  expect_error(audit_dispositions_attach(dat), "no matching manual-correction")
})

test_that("ledger row_id must exist in the pipeline data", {
  ledger <- data.frame(pid = "1", day_num = 1, row_id = 999L, field = "SOL",
    disposition = "keep", decided_by = "audit_20260820", annotators = "",
    decision_date = "2026-08-20", evidence_note = "", stringsAsFactors = FALSE)
  write.csv(ledger, getOption("sleepcleanr.audit_ledger"), row.names = FALSE)
  unlink(getOption("sleepcleanr.audit_manual_corrections"))
  dat <- data.frame(row_id = as.character(1:3), stringsAsFactors = FALSE)
  expect_error(audit_dispositions_attach(dat), "not present in pipeline data")
})

test_that("a ledger path passed from the config is used over the option", {
  d <- withr::local_tempdir()
  cfg_ledger <- file.path(d, "my_ledger.csv")
  led <- data.frame(pid = "1", day_num = 1, row_id = 10L, field = "SOL",
    disposition = "keep_flagged", decided_by = "audit_20260820", annotators = "",
    decision_date = "2026-08-20", evidence_note = "", stringsAsFactors = FALSE)
  write.csv(led, cfg_ledger, row.names = FALSE)
  dat <- data.frame(row_id = as.character(10:11), stringsAsFactors = FALSE)
  out <- audit_dispositions_attach(dat, ledger_path = cfg_ledger)
  expect_identical(out$audit_disposition, c("keep_flagged", "none"))
})

test_that("a named ledger that does not exist stops instead of writing none", {
  dat <- data.frame(row_id = as.character(1:3), stringsAsFactors = FALSE)
  missing <- file.path(withr::local_tempdir(), "nope.csv")
  expect_error(audit_dispositions_attach(dat, ledger_path = missing),
               "data.files.audit_dispositions.*not found")
})

test_that("a blank configured ledger path falls back to the option (inactive here)", {
  unlink(getOption("sleepcleanr.audit_ledger"))
  dat <- data.frame(row_id = as.character(1:3), stringsAsFactors = FALSE)
  out <- audit_dispositions_attach(dat, ledger_path = "")
  expect_identical(out$audit_disposition, rep("none", 3))
})

test_that("consistency check reads the configured manual file, not the option", {
  d <- withr::local_tempdir()
  led <- data.frame(pid = "1", day_num = 1, row_id = 7L, field = "SOL",
    disposition = "set_na", decided_by = "audit_20260820", annotators = "",
    decision_date = "2026-08-20", evidence_note = "", stringsAsFactors = FALSE)
  write.csv(led, file.path(d, "ledger.csv"), row.names = FALSE)
  manual <- data.frame(pid = "1", day_num = 1, row_id = 7L,
    variable = "duration_totalmin_sol_estimate_am", corrected_mincalc = "NA",
    stringsAsFactors = FALSE)
  write.csv(manual, file.path(d, "renamed_manual.csv"), row.names = FALSE)
  dat <- data.frame(row_id = "7", stringsAsFactors = FALSE)

  # option points at a nonexistent file; the configured path must win
  out <- audit_dispositions_attach(dat, ledger_path = file.path(d, "ledger.csv"),
                                   manual_path = file.path(d, "renamed_manual.csv"))
  expect_identical(out$audit_disposition, "set_na")

  # blank manual path (algorithmic-only run) -> audit layer inactive: the
  # ledger belongs to the review channel this run deliberately closed, so
  # nothing is attached and the run is not stopped
  expect_message(
    out <- audit_dispositions_attach(dat, ledger_path = file.path(d, "ledger.csv"),
                                     manual_path = ""),
    "audit dispositions not attached")
  expect_identical(out$audit_disposition, "none")
})

test_that("keep-only ledger is also not attached in an algorithmic-only run", {
  d <- withr::local_tempdir()
  led <- data.frame(pid = "1", day_num = 1, row_id = 10L, field = "SOL",
    disposition = "keep", decided_by = "audit_20260820", annotators = "",
    decision_date = "2026-08-20", evidence_note = "", stringsAsFactors = FALSE)
  write.csv(led, file.path(d, "ledger.csv"), row.names = FALSE)
  dat <- data.frame(row_id = "10", stringsAsFactors = FALSE)
  expect_message(
    out <- audit_dispositions_attach(dat, ledger_path = file.path(d, "ledger.csv"),
                                     manual_path = ""),
    "audit dispositions not attached")
  expect_identical(out$audit_disposition, "none")
})

test_that("a named-but-missing manual file still stops the guard", {
  d <- withr::local_tempdir()
  led <- data.frame(pid = "1", day_num = 1, row_id = 7L, field = "SOL",
    disposition = "set_na", decided_by = "audit_20260820", annotators = "",
    decision_date = "2026-08-20", evidence_note = "", stringsAsFactors = FALSE)
  write.csv(led, file.path(d, "ledger.csv"), row.names = FALSE)
  # named path that does not exist: NOT the algorithmic-only blank path, so
  # the hard guard fires -- a vanished file is an accident, not a choice
  missing_manual <- file.path(d, "gone.csv")
  dat <- data.frame(row_id = "7", stringsAsFactors = FALSE)
  expect_error(
    audit_dispositions_attach(dat, ledger_path = file.path(d, "ledger.csv"),
                              manual_path = missing_manual),
    "manual_sleep_metric_duration_corrections.csv is missing")
})
