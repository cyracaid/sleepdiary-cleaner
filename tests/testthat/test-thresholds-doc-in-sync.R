# test-thresholds-doc-in-sync.R -- the threshold defaults are written in four
# places: inst/config_default.yaml (what the code uses), THRESHOLDS.md,
# THRESHOLDS-zh.md and the commented examples in inst/config_template.yaml.
# The yaml is the source of truth; the three documents must not drift from it,
# and the two threshold pages must list the same keys with the same defaults.

.th_root <- function() {
  if (basename(getwd()) == "testthat") dirname(dirname(getwd())) else getwd()
}

.th_default <- function(cfg, path) {
  x <- cfg
  for (k in strsplit(path, ".", fixed = TRUE)[[1]]) {
    if (!is.list(x) || is.null(x[[k]])) return(NULL)
    x <- x[[k]]
  }
  x
}

# Rows of the "Threshold table": key cell, default cell.
.th_rows <- function(path) {
  tx <- readLines(path, encoding = "UTF-8", warn = FALSE)
  rows <- grep("^\\| `", tx, value = TRUE)
  lapply(rows, function(r) {
    cells <- trimws(strsplit(r, "|", fixed = TRUE)[[1]])[-1]
    ticks <- function(x) gsub("`", "", regmatches(x, gregexpr("`[^`]+`", x))[[1]])
    list(keys = ticks(cells[1]), defaults = ticks(cells[2]))
  })
}

# Compare as numbers or logicals where possible, so 1.0 == 1 and true == TRUE.
.th_norm <- function(x) {
  x <- tolower(as.character(unlist(x)))
  num <- suppressWarnings(as.numeric(x))
  ifelse(is.na(num), x, format(num, scientific = FALSE, trim = TRUE))
}

test_that("THRESHOLDS.md defaults match inst/config_default.yaml", {
  root <- .th_root()
  skip_if_not(file.exists(file.path(root, "THRESHOLDS.md")), "THRESHOLDS.md not found")
  cfg <- yaml::read_yaml(file.path(root, "inst", "config_default.yaml"))
  rows <- .th_rows(file.path(root, "THRESHOLDS.md"))
  expect_gt(length(rows), 15)
  for (r in rows) {
    key <- r$keys[1]
    # "a.min_hours / _max_hours" documents a pair of keys in one row
    paths <- key
    if (length(r$keys) > 1 && startsWith(r$keys[2], "_")) {
      paths <- c(key, sub("_[a-z]+_hours$", r$keys[2], key))
    }
    got <- lapply(paths, function(p) .th_default(cfg, p))
    expect_false(any(vapply(got, is.null, logical(1))),
                 info = paste("not in config_default.yaml:", paste(paths, collapse = ", ")))
    expect_identical(.th_norm(got), .th_norm(r$defaults),
                     info = paste("THRESHOLDS.md default drifted for", key))
  }
})

test_that("THRESHOLDS-zh.md lists the same keys and defaults as THRESHOLDS.md", {
  root <- .th_root()
  en <- file.path(root, "THRESHOLDS.md")
  zh <- file.path(root, "THRESHOLDS-zh.md")
  skip_if_not(file.exists(en) && file.exists(zh), "threshold pages not found")
  a <- .th_rows(en)
  b <- .th_rows(zh)
  expect_identical(lapply(b, `[[`, "keys"), lapply(a, `[[`, "keys"))
  expect_identical(lapply(b, `[[`, "defaults"), lapply(a, `[[`, "defaults"))
  # Same number of sections, so a section added to one page is noticed
  n_sec <- function(p) sum(grepl("^## ", readLines(p, encoding = "UTF-8", warn = FALSE)))
  expect_identical(n_sec(zh), n_sec(en))
})

test_that("commented examples in config_template.yaml match the defaults", {
  root <- .th_root()
  tpl <- file.path(root, "inst", "config_template.yaml")
  skip_if_not(file.exists(tpl), "config_template.yaml not found")
  cfg <- yaml::read_yaml(file.path(root, "inst", "config_default.yaml"))
  lines <- readLines(tpl, encoding = "UTF-8", warn = FALSE)
  start <- grep("^# classification:", lines)[1]
  skip_if(is.na(start), "no commented threshold block")
  # The THRESHOLDS section runs to the next "# ====" banner; later sections
  # reuse top-level keys such as review:, which would be duplicate yaml keys.
  banner <- grep("^# =====", lines)
  stop_at <- banner[banner > start + 1][1]
  block <- lines[start:(if (is.na(stop_at)) length(lines) else stop_at - 1)]
  # Keep only the commented yaml (drop prose comments and blank comment lines)
  block <- block[grepl("^#  ?[A-Za-z0-9_]+:|^#   +[A-Za-z0-9_]+:", block)]
  block <- sub("^# ?", "", block)
  # The section holds two separate "review:" examples, so parse it one
  # top-level block at a time rather than as a single (duplicate-key) document.
  top <- grepl("^[A-Za-z0-9_]+:", block)
  chunks <- unname(split(block, cumsum(top)))
  ex <- do.call(c, lapply(chunks, function(ch) {
    parsed <- yaml::yaml.load(paste(ch, collapse = "\n"))
    # keep each block distinct even if a top-level key repeats
    stats::setNames(list(parsed[[1]]), names(parsed))
  }))
  leaves <- function(x, p = character()) {
    if (is.list(x) && !is.null(names(x))) {
      return(unlist(lapply(seq_along(x), function(i) leaves(x[[i]], c(p, names(x)[i]))), recursive = FALSE))
    }
    list(list(path = paste(p, collapse = "."), value = x))
  }
  checked <- 0
  for (l in leaves(ex)) {
    d <- .th_default(cfg, l$path)
    if (is.null(d)) next          # an example for a key the default file leaves out
    checked <- checked + 1
    expect_identical(.th_norm(l$value), .th_norm(d),
                     info = paste("config_template.yaml example drifted for", l$path))
  }
  expect_gt(checked, 8)
})
