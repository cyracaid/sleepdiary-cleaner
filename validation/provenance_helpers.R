# =============================================================================
# validation/provenance_helpers.R
#
# PURPOSE
#   Every CSV this validation pipeline writes should be able to answer, on
#   its own, "which script, run against which inputs, produced this file?"
#   without anyone having to remember or dig through work_logs/*.md.
#
#   This was NOT true for manual_disambiguation_fasttrack.csv: it exists
#   only because of a one-off manual copy/rename of
#   disambiguation_worksheet_tiered_fasttrack.csv (see
#   work_logs/2026-09-09_EMAIL_TO_MAIA_validation_update.md), a step no
#   script recorded. write_csv_with_provenance() + promote_fasttrack_
#   for_review.R close that gap going forward.
#
#   No new package dependencies: file hashing uses tools::md5sum() (part of
#   base R), and the sidecar is written with a small hand-rolled JSON
#   serializer (not jsonlite) so this file has zero install requirements.
#
# USAGE
#   source("validation/provenance_helpers.R")
#   write_csv_with_provenance(
#     df, "some_output.csv",
#     script_path = "validation/some_script.R",     # usually the caller itself
#     inputs = c("input_a.csv", "input_b.csv"),      # files this output was derived from
#     notes = "optional free-text context"
#   )
#   # -> writes some_output.csv AND some_output.csv.provenance.json
# =============================================================================

.provenance_hash_file <- function(path) {
  if (is.na(path) || !nzchar(path) || !file.exists(path)) return(NA_character_)
  unname(tools::md5sum(path))
}

# Minimal JSON writer. Handles the shapes provenance objects actually use:
# named lists (objects), unnamed lists (arrays), character/numeric scalars,
# and NA -> null. Not a general-purpose serializer -- deliberately kept small
# so it can be read/trusted at a glance instead of adding a jsonlite dependency.
.provenance_to_json <- function(x, indent = 0) {
  pad  <- strrep("  ", indent)
  pad1 <- strrep("  ", indent + 1)

  is_named_list <- is.list(x) && !is.null(names(x)) && all(names(x) != "")

  if (is_named_list) {
    items <- vapply(names(x), function(nm) {
      paste0(pad1, '"', nm, '": ', .provenance_to_json(x[[nm]], indent + 1))
    }, character(1))
    paste0("{\n", paste(items, collapse = ",\n"), "\n", pad, "}")
  } else if (is.list(x)) {
    if (length(x) == 0) return("[]")
    items <- vapply(x, function(el) paste0(pad1, .provenance_to_json(el, indent + 1)), character(1))
    paste0("[\n", paste(items, collapse = ",\n"), "\n", pad, "]")
  } else if (is.character(x)) {
    if (length(x) == 0 || is.na(x)) return("null")
    escaped <- gsub("\\\\", "\\\\\\\\", x[1])
    escaped <- gsub('"', '\\\\"', escaped)
    escaped <- gsub("\n", "\\\\n", escaped)
    paste0('"', escaped, '"')
  } else if (is.numeric(x)) {
    if (length(x) == 0 || is.na(x[1])) return("null")
    as.character(x[1])
  } else if (is.logical(x)) {
    if (length(x) == 0 || is.na(x[1])) return("null")
    if (x[1]) "true" else "false"
  } else {
    "null"
  }
}

#' Write a data frame to CSV together with a .provenance.json sidecar.
#'
#' @param df data.frame to write.
#' @param path output CSV path.
#' @param script_path path (repo-relative, e.g. "validation/derive_timegap_candidates.R")
#'   of the script producing this file -- normally the script calling this
#'   function.
#' @param inputs character vector of input file paths this output was
#'   derived from. Each gets hashed too, so a later run can tell whether an
#'   input changed since this output was generated.
#' @param notes optional free-text note, e.g. "pure promotion, content unchanged".
#' @param ... passed through to write.csv() (row.names defaults to FALSE).
#' @return path, invisibly.
write_csv_with_provenance <- function(df, path, script_path, inputs = character(0),
                                       notes = "", ...) {
  extra_args <- list(...)
  if (is.null(extra_args$row.names)) extra_args$row.names <- FALSE
  do.call(write.csv, c(list(df, path), extra_args))

  input_records <- lapply(inputs, function(p) {
    list(path = p, md5 = .provenance_hash_file(p))
  })

  prov <- list(
    output_file  = path,
    output_rows  = nrow(df),
    output_md5   = .provenance_hash_file(path),
    generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %z"),
    script       = script_path,
    script_md5   = .provenance_hash_file(script_path),
    inputs       = input_records,
    notes        = notes,
    r_version    = R.version.string
  )

  sidecar_path <- paste0(path, ".provenance.json")
  writeLines(.provenance_to_json(prov), sidecar_path)

  invisible(path)
}
