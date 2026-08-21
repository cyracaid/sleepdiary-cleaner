# Derive audit_dispositions.csv from the 188-row audit worksheet
#
# Source of truth for the disposition of every audited pid+day+field row:
#   ../splsleep_paper_work/m4_188_audit_worksheet.csv   (56 rows, private)
# Row_ids come from the delivered Dataset B
#   output/cleaned_data_prepostcorrection.csv
# by taking the first pipeline row_id of each (pid, day_num) -- the same rows
# referenced by manual_sleep_metric_duration_corrections.csv for the four
# value-moving decisions (9696 d3/d5 -> set_na, d7/d11 -> corrected_manual).
#
# Disposition mapping (decision text -> level):
#   "KEEP as written (batch ...)"                        -> keep
#   "KEEP as written (inter...)"                         -> keep
#   "AGREE -- no change ..."                             -> keep
#   "KEEP 120 ..." / "KEEP 15 as written" / "KEEP 30 ..." -> keep
#   "KEEP_ORIGINAL_CLEANING ..." (3200/6374 WASO)        -> keep
#   "NA (duration_sol -> NA)"                            -> set_na
#   "AGREE 3.00 ..." / "AGREE 3.75 ..."                  -> corrected_manual
#
# The ledger is private (gitignored). Values are never changed here; only the
# four 9696 rows move data, exclusively via the manual-corrections file.
#
# Writes: audit_dispositions.csv at repo root (gitignored template lives in
# inst/extdata/template_audit_dispositions.csv).

ws <- read.csv("../splsleep_paper_work/m4_188_audit_worksheet.csv",
               stringsAsFactors = FALSE, check.names = FALSE)

b <- read.csv("output/cleaned_data_prepostcorrection.csv",
              stringsAsFactors = FALSE, check.names = FALSE)
b$pid <- trimws(as.character(b$pid)); b$day_num <- as.integer(b$day_num)

first_row_id <- function(pid, day) {
  hit <- which(b$pid == trimws(as.character(pid)) & b$day_num == as.integer(day))
  if (length(hit) == 0) stop("no Dataset B rows for pid=", pid, " day=", day)
  as.character(b$row_id[hit[1]])
}

# Authoritative pid+day -> row_id mapping: the manual-corrections file (the
# same keying the pipeline applier and the attach guard use). Fall back to the
# first Dataset-B row only when a (pid, day, variable) has no manual record.
sol_var <- "duration_totalmin_sol_estimate_am"
waso_var <- "duration_totalmin_waso_estimate_am"
manual_file <- "manual_sleep_metric_duration_corrections.csv"
manual_tbl <- if (file.exists(manual_file)) {
  read.csv(manual_file, stringsAsFactors = FALSE, check.names = FALSE)
} else NULL
row_id_from_manual <- function(i) {
  if (is.null(manual_tbl)) return(NA_character_)
  v <- if (trimws(ws$field[i]) == "WASO") waso_var else sol_var
  hit <- which(trimws(as.character(manual_tbl$pid)) == trimws(as.character(ws$pid[i])) &
                 as.integer(manual_tbl$day_num) == as.integer(ws$day[i]) &
                 trimws(manual_tbl$variable) == v)
  if (length(hit) == 0) NA_character_ else as.character(manual_tbl$row_id[hit[1]])
}

map_disp <- function(h) {
  h <- gsub("[\n\r]+", " ", h)
  ifelse(grepl("^NA \\(duration_sol", h), "set_na",
  ifelse(grepl("^AGREE 3\\.(00|75)", h), "corrected_manual",
  "keep"))
}

out <- data.frame(
  pid          = trimws(as.character(ws$pid)),
  day_num      = as.integer(ws$day),
  row_id       = vapply(seq_len(nrow(ws)), function(i) {
    m <- row_id_from_manual(i)
    if (is.na(m)) first_row_id(ws$pid[i], ws$day[i]) else m
  }, character(1)),
  field        = trimws(ws$field),
  disposition  = map_disp(ws$human_decision),
  decided_by   = "audit_20260820",
  annotators   = ifelse(grepl("^AGREE 3\\.(00|75)", ws$human_decision), "cyra;maia", ""),
  decision_date = "2026-08-20",
  evidence_note = gsub("[\n\r]+", " ", trimws(ws$human_decision)),
  stringsAsFactors = FALSE)

stopifnot(all(out$disposition %in%
  c("none", "keep", "keep_flagged", "corrected_manual", "set_na", "mixed")))
write.csv(out, "audit_dispositions.csv", row.names = FALSE)
cat(sprintf("Wrote audit_dispositions.csv: %d rows\n  keep=%d set_na=%d corrected_manual=%d\n",
            nrow(out), sum(out$disposition == "keep"),
            sum(out$disposition == "set_na"),
            sum(out$disposition == "corrected_manual")))