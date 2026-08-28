# Audit dispositions integration tests
#
# Covers the new ledger layer only; the dictionary-driven finalize-column
# behaviour stays in test-finalize-columns.R (one integration assertion added
# there). This file tests:
#   1. Roll-up: same-night SOL/WASO disagreement collapses to "mixed".
#   2. Default fill: no ledger file -> column all "none".
#   3. Hard guard: corrected_manual/set_na disposition without a matching
#      manual-correction record -> stop(), never a silent "mixed".

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