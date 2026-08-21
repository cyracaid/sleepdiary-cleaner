# Audit dispositions: silent-error audit ledger integration
#
# The 188-row silent-error audit produced per-row human decisions
# (keep / keep_flagged / corrected_manual / set_na / none). Those decisions
# live in a private ledger (`audit_dispositions.csv`, gitignored) keyed by
# pid, day_num, row_id, field (SOL / WASO) -- the same keying convention as
# `manual_sleep_metric_duration_corrections.csv`, so the "SOL and WASO decided
# differently, same night" case was already solved by existing plumbing.
#
# The delivered datasets stay principled:
#   - Dataset A: untouched (frozen contract).
#   - Dataset B: gains one categorical column, `audit_disposition`, a per-row
#     roll-up (levels: none/keep/keep_flagged/corrected_manual/set_na/mixed).
#     Field-level detail lives in the private ledger; `mixed` means the
#     ledger's fields for that row disagreed.
#
# Values themselves are never changed here. The 4 real value changes flow
# exclusively through `manual_sleep_metric_duration_corrections.csv` and
# surface as `has_correction = "manual"`.

.FIELD_TO_VARIABLE <- c(
  SOL  = "duration_totalmin_sol_estimate_am",
  WASO = "duration_totalmin_waso_estimate_am"
)

.ALLOWED_DISPOSITIONS <- c("none", "keep", "keep_flagged",
                           "corrected_manual", "set_na", "mixed")

.audit_ledger_path <- function() {
  getOption("sleepcleanr.audit_ledger",
            file.path(getwd(), "audit_dispositions.csv"))
}

.manual_corrections_path <- function() {
  getOption("sleepcleanr.audit_manual_corrections",
            file.path(getwd(), "manual_sleep_metric_duration_corrections.csv"))
}

audit_dispositions_read <- function(path = .audit_ledger_path()) {
  if (!file.exists(path)) return(NULL)
  led <- utils::read.csv(path, stringsAsFactors = FALSE,
                         colClasses = "character", na.strings = c("", "NA"))
  required <- c("pid", "day_num", "row_id", "field", "disposition",
                "decided_by", "annotators", "decision_date", "evidence_note")
  miss <- setdiff(required, names(led))
  if (length(miss)) {
    stop("audit_dispositions.csv is missing required column(s): ",
         paste(miss, collapse = ", "))
  }
  unknown <- setdiff(unique(led$disposition[!is.na(led$disposition)]),
                     .ALLOWED_DISPOSITIONS)
  if (length(unknown)) {
    stop("audit_dispositions.csv has unknown disposition level(s): ",
         paste(unknown, collapse = ", "))
  }
  led
}

manual_dispositions_read <- function(path = .manual_corrections_path()) {
  if (!file.exists(path)) return(NULL)
  utils::read.csv(path, stringsAsFactors = FALSE,
                  colClasses = "character", na.strings = c("", "NA"))
}

# Ledger values that moved data must be corroborated by the manual-corrections
# file. This is a hard consistency guard, not a soft "mixed" bucket: a
# disposition that says a value was changed or set to NA but has no matching
# manual-correction record (or a value-type mismatch) stops the build, like
# the existing export guard for negative minutes.
check_ledger_manual_consistency <- function(ledger, manual) {
  if (is.null(ledger)) return(invisible(TRUE))
  need <- ledger[ledger$disposition %in% c("corrected_manual", "set_na"), ]
  if (nrow(need) == 0) return(invisible(TRUE))
  if (is.null(manual)) {
    stop("Ledger declares corrected_manual/set_na row(s) but ",
         "manual_sleep_metric_duration_corrections.csv is missing; ",
         "cannot verify value movement. Investigate before shipping.")
  }
  manual$variable_fixed <- trimws(manual$variable)
  key_m <- paste(trimws(manual$pid), trimws(manual$day_num),
                 trimws(manual$row_id), manual$variable_fixed)
  for (i in seq_len(nrow(need))) {
    var <- unname(.FIELD_TO_VARIABLE[need$field[i]])
    if (is.na(var)) stop("Ledger field '", need$field[i], "' has no ",
                         "variable mapping (expected SOL or WASO).")
    k <- paste(trimws(need$pid[i]), trimws(need$day_num[i]),
               trimws(need$row_id[i]), var)
    hit <- manual[key_m %in% k, ]
    if (nrow(hit) == 0) {
      stop("Ledger ", need$pid[i], "/d", need$day_num[i], " (", need$field[i],
           ") disposition='", need$disposition[i], "' but no matching ",
           "manual-correction record exists.")
    }
    corr <- trimws(hit$corrected_mincalc[1])
    if (need$disposition[i] == "set_na" &&
        !(is.na(corr) || corr %in% c("", "NA"))) {
      stop("Ledger ", need$pid[i], "/d", need$day_num[i],
           " disposition='set_na' but manual-correction value is '", corr,
           "' (expected NA).")
    }
    if (need$disposition[i] == "corrected_manual" &&
        (is.na(corr) || corr %in% c("", "NA") || is.na(suppressWarnings(as.numeric(corr))))) {
      stop("Ledger ", need$pid[i], "/d", need$day_num[i],
           " disposition='corrected_manual' but manual-correction value is ",
           "'", corr, "' (expected numeric).")
    }
  }
  invisible(TRUE)
}

# Attach `audit_disposition` to corrected_ema_data before finalize_columns().
# No ledger -> column all "none". Ledger present -> per-row roll-up; a row
# whose ledger fields disagree (e.g. SOL=keep, WASO=set_na) becomes "mixed".
audit_dispositions_attach <- function(data,
                                     ledger_path = .audit_ledger_path(),
                                     manual_path = .manual_corrections_path()) {
  ledger <- audit_dispositions_read(ledger_path)

  # No ledger -> nothing to attach; fill "none" unconditionally so Dataset B
  # always carries the column. A data frame without a row_id (unit-test fakes)
  # is fine here: audit is simply inactive.
  if (is.null(ledger) || nrow(ledger) == 0) {
    data$audit_disposition <- "none"
    return(data)
  }

  if (!"row_id" %in% names(data)) {
    stop("audit_dispositions_attach needs a row_id column in the data.")
  }

  manual <- manual_dispositions_read(manual_path)
  check_ledger_manual_consistency(ledger, manual)

  drill <- paste(trimws(ledger$row_id), trimws(ledger$field))
  data_row_ids <- as.character(data$row_id)
  unknown <- setdiff(unique(paste(trimws(ledger$row_id))),
                     data_row_ids)
  if (length(unknown)) {
    stop("Ledger row_id(s) not present in pipeline data: ",
         paste(utils::head(unknown, 5), collapse = ", "),
         if (length(unknown) > 5) "... (total ", length(unknown), ")")
  }

  disp_by_row <- split(ledger$disposition, trimws(ledger$row_id))
  rollup <- vapply(disp_by_row, function(ds) {
    u <- unique(ds)
    if (length(u) == 1) u else "mixed"
  }, character(1))

  data$audit_disposition <- "none"
  hit <- match(data_row_ids, names(rollup))
  data$audit_disposition[!is.na(hit)] <- unname(rollup[hit[!is.na(hit)]])
  data
}