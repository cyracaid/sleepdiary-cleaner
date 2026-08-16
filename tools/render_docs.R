#!/usr/bin/env Rscript
# render_docs.R — derive SKILL.md facts + README architecture from sources.
#
# Single generator for the "facts" sections of the docs that drift when the
# code changes: package version, pipeline step list, delivered columns, and
# runtime dependency count. Manual prose (operating rules, classification
# rationale, ASCII diagrams) stays hand-written between markers.
#
# Sources:
#   DESCRIPTION$Version, DESCRIPTION$Imports
#   inst/steps.yaml
#   inst/extdata/column_dictionary.csv (status == "implemented")
#
# Output targets (between AUTO markers):
#   .opencode/skills/splsleep-pipeline/SKILL.md
#   README.md
#
# Usage: Rscript tools/render_docs.R   (from repo root)
# CI keeps it honest: tests/testthat/test-generated-docs-in-sync.R re-renders
# in memory and fails if the committed files drifted.

# Force UTF-8: renv/R CMD check often run with LC_CTYPE="C", under which
# sprintf() mangles Chinese literals into native bytes before writeLines
# (useBytes=TRUE then writes the corruption). Must precede any string work.
suppressWarnings(tryCatch(
  Sys.setlocale("LC_CTYPE", "en_US.UTF-8"),
  error = function(e) NULL
))

suppressMessages({
  library(yaml)
})

repo_root <- function() {
  # Walk up from cwd until a DESCRIPTION (source tree) is found.
  d <- normalizePath(getwd(), mustWork = FALSE)
  repeat {
    if (file.exists(file.path(d, "DESCRIPTION"))) return(d)
    up <- dirname(d)
    if (identical(up, d)) break
    d <- up
  }
  # Installed-package fallback (no DESCRIPTION upstream).
  p <- tryCatch(system.file(package = "splsleep"), error = function(e) "")
  if (nzchar(p)) return(p)
  getwd()
}

read_steps <- function(yaml_path) {
  # readLines(encoding="UTF-8") then yaml.load: yaml::read_yaml chokes on
  # non-ASCII (em dash) under non-UTF-8 locales.
  txt <- readLines(yaml_path, warn = FALSE, encoding = "UTF-8")
  d <- yaml::yaml.load(paste(txt, collapse = "\n"))
  d$steps
}

read_dictionary_columns <- function(csv_path) {
  if (!file.exists(csv_path)) return(character(0))
  df <- read.csv(csv_path, stringsAsFactors = FALSE, check.names = FALSE,
                 fileEncoding = "UTF-8")
  cols <- df$name_a[df$status == "implemented"]
  cols[!is.na(cols) & nzchar(cols)]
}

pkg_version <- function() {
  d <- read.dcf(file.path(repo_root(), "DESCRIPTION"))
  unname(d[1, "Version"])
}

pkg_imports <- function() {
  d <- read.dcf(file.path(repo_root(), "DESCRIPTION"))
  imp <- unname(d[1, "Imports"])
  if (is.na(imp) || !nzchar(imp)) return(character(0))
  parts <- strsplit(imp, ",\\s*")[[1]]
  sub("\\s*\\(.*$", "", parts)
}

render_skill_facts <- function(steps, columns, version, n_imports) {
  step_lines <- vapply(steps, function(s) {
    sprintf("Step %-5s %s — %s", s$id, s$label, s$description)
  }, character(1))
  col_lines <- vapply(columns, function(c) sprintf("- `%s`", c), character(1))
  unname(c(
    sprintf("**Version:** %s", version),
    sprintf("**Pipeline steps:** %d", length(steps)),
    "",
    "| Step | Label | Description |",
    "|------|-------|-------------|",
    vapply(steps, function(s) {
      sprintf("| %s | %s | %s |", s$id, s$label, s$description)
    }, character(1)),
    "",
    sprintf("**Delivered columns (%d, from column dictionary):**", length(columns)),
    col_lines,
    "",
    sprintf("**Runtime dependencies:** %d packages in Imports (`renv::install()` covers all)", n_imports)
  ))
}

render_readme_steps_zh <- function(steps) {
  enc2utf8(unname(c(
    sprintf("**%d 个步骤**（来源：`inst/steps.yaml`）：", length(steps)),
    "",
    "| 步骤 | 名称 | 说明 |",
    "|------|------|------|",
    vapply(steps, function(s) {
      sprintf("| %s | %s | %s |", s$id, s$label, s$description)
    }, character(1))
  )))
}

render_readme_steps <- function(steps) {
  unname(c(
    sprintf("**%d steps** (source: `inst/steps.yaml`):", length(steps)),
    "",
    "| Step | Label | Description |",
    "|------|-------|-------------|",
    vapply(steps, function(s) {
      sprintf("| %s | %s | %s |", s$id, s$label, s$description)
    }, character(1))
  ))
}

# ── Wrapper: regenerate one region between markers ──────────────────────────
regenerate_region <- function(path, start_marker, end_marker, lines) {
  txt <- readLines(path, warn = FALSE, encoding = "UTF-8")
  i_start <- which(trimws(txt) == start_marker)
  i_end <- which(trimws(txt) == end_marker)
  if (length(i_start) != 1 || length(i_end) != 1 || i_start > i_end) {
    stop(sprintf("markers %s/%s not found once and in order in %s",
                 start_marker, end_marker, path))
  }
  block <- c(start_marker, "", lines, "", end_marker)
  out <- c(txt[seq_len(i_start - 1)], block, txt[seq((i_end + 1), length(txt))])
  writeLines(out, path, useBytes = TRUE)
  invisible(length(out))
}

main <- function() {
  root <- repo_root()
  steps <- read_steps(file.path(root, "inst", "steps.yaml"))
  cols <- read_dictionary_columns(file.path(root, "inst", "extdata", "column_dictionary.csv"))
  ver <- pkg_version()
  n_imp <- length(pkg_imports())

  skill_path <- file.path(root, ".opencode", "skills", "splsleep-pipeline", "SKILL.md")
  readme_path <- file.path(root, "README.md")

  if (!file.exists(skill_path)) stop("SKILL.md not found at ", skill_path)

  regenerate_region(skill_path,
                    "<!-- AUTO:SKILL_FACTS_START -->",
                    "<!-- AUTO:SKILL_FACTS_END -->",
                    render_skill_facts(steps, cols, ver, n_imp))
  regenerate_region(readme_path,
                    "<!-- AUTO:ARCH_START -->",
                    "<!-- AUTO:ARCH_END -->",
                    render_readme_steps(steps))
  regenerate_region(readme_path,
                    "<!-- AUTO:ARCH_ZH_START -->",
                    "<!-- AUTO:ARCH_ZH_END -->",
                    render_readme_steps_zh(steps))

  cat("Rendered docs from", ver, "-", length(steps), "steps,", length(cols), "columns.\n")
}

if (sys.nframe() == 0 && !interactive()) {
  main()
}
