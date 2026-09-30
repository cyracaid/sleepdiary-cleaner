# Read a manual correction CSV the same way in every R session.
#
# utils::read.csv(path, fileEncoding = "UTF-8-BOM") re-encodes the file to the
# session's native encoding. In a non-UTF-8 session (for example LC_CTYPE = "C",
# or a Windows code page) a non-ASCII character makes the connection stop
# reading at that point: only a warning is raised and the rows after it are
# silently dropped, so human corrections would be left out of the run without
# any error.
#
# Here the file's bytes are read directly, the UTF-8 byte-order mark (if any) is
# removed, and the text is parsed as UTF-8, so the result does not depend on the
# session locale. If R still reports that it could not read everything, the run
# stops instead of continuing with fewer rows.

#' @noRd
.read_manual_csv <- function(path) {
  raw <- readBin(path, "raw", file.info(path)$size)
  if (length(raw) >= 3 && identical(raw[1:3], as.raw(c(0xef, 0xbb, 0xbf)))) {
    raw <- raw[-(1:3)]
  }
  problems <- character(0)
  out <- withCallingHandlers(
    utils::read.csv(text = rawToChar(raw), encoding = "UTF-8"),
    warning = function(w) {
      msg <- conditionMessage(w)
      if (grepl("invalid input found|EOF within quoted string", msg)) {
        problems <<- c(problems, msg)
        invokeRestart("muffleWarning")
      }
    }
  )
  if (length(problems) > 0) {
    stop(sprintf(
      paste0("%s could not be read completely (%s). The file may not be valid ",
             "UTF-8; re-save it as UTF-8 (CSV UTF-8) and run again, otherwise ",
             "rows after the problem would be left out of this run."),
      path, problems[[1]]), call. = FALSE)
  }
  out
}
