# draw_sample.R -- draw the sample for a blind audit of the pipeline on real data.
#
# Question it answers: what errors does the pipeline MISS in real diaries, and how
# many of its flags are real errors? Two people label raw entries without seeing
# the pipeline's output; the labels are then compared with the pipeline's flags
# (score_audit.R).
#
# Three strata: rows the pipeline flagged for review; rows whose time values it
# changed without a flag; and rows it left alone. The left-alone stratum is what
# estimates misses (a wrong time or duration in a row the pipeline neither flagged
# nor changed). A row whose typed format was merely normalised (for example "1130"
# read as 11:30) counts as left alone: its value is unchanged.
#
# "Error" for the annotators means: the entry as typed does not give the time or
# duration the participant most likely meant. The sheets and the key hold study data: write
# them OUTSIDE the repository (the script refuses a directory inside it).
#
# Usage:
#   Rscript validation/blind_audit/draw_sample.R <corrected_ema_data.rds> <out_dir> \
#       [<review_output.rds>] [--n_flagged=150] [--n_changed=50] [--n_left_alone=150] [--seed=20261006]
# review_output.rds holds the review queue. run_pipeline() leaves it in the global
# environment as `review_output`; save it after the run with
#   saveRDS(review_output, "review_output.rds")
# Without it the script falls back to rows classed error or unusual, which is a
# subset of the queue and understates it.
args <- commandArgs(trailingOnly = TRUE)
pos <- args[!grepl("^--", args)]
opt <- function(name, default) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) as.numeric(sub(paste0("^--", name, "="), "", hit[1])) else default
}
stopifnot(length(pos) %in% 2:3)
in_rds <- pos[1]; out_dir <- normalizePath(pos[2], mustWork = FALSE)
n_flag <- opt("n_flagged", 150); n_alt <- opt("n_changed", 50); n_unt <- opt("n_left_alone", 150)
seed <- opt("seed", 20261006)

# refuse to write inside a git work tree
git_top <- suppressWarnings(system2("git", c("-C", dirname(out_dir), "rev-parse", "--show-toplevel"),
                                    stdout = TRUE, stderr = FALSE))
if (length(git_top) == 1 && nzchar(git_top) && startsWith(out_dir, normalizePath(git_top))) {
  stop("out_dir is inside a git repository (", git_top, "); choose a directory outside it")
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

x <- readRDS(in_rds)
raw_cols <- c("time_bed_am_hhmm", "time_bed_am_ampm", "time_sleep_am_hhmm", "time_sleep_am_ampm",
              "time_awake_am_hhmm", "time_awake_am_ampm", "time_getup_am_hhmm", "time_getup_am_ampm",
              "duration_totalmin_sol_estimate_am", "duration_totalmin_waso_estimate_am")
stopifnot(all(c("pid", "day_num", "row_id", raw_cols) %in% names(x)))

# pipeline flag: needs_review (cleaned_data_final) or any *_checkforerrors flag
fl <- rep(FALSE, nrow(x))
if (length(pos) == 3) {
  d <- readRDS(pos[3])$data_with_flags
  q <- d$needs_review_flag %in% TRUE
  for (c in grep("_checkforerrors$", names(d), value = TRUE)) q <- q | (d[[c]] %in% TRUE)
  fl <- x$row_id %in% d$row_id[q]
} else {
  message("No review_output.rds given: flags taken from the error/unusual classes only.")
  fl <- x$data_category %in% c("error", "unusual")
}
# changed = any of the four parsed times differs from its corrected value
tm <- c("bed", "sleep", "awake", "getup")
changed <- rep(FALSE, nrow(x))
for (k in tm) {
  r <- x[[sprintf("time_%s_am_hhmm_ampm", k)]]; c <- x[[sprintf("time_%s_corrected", k)]]
  changed <- changed | (!is.na(r) & !is.na(c) & as.numeric(r) != as.numeric(c))
}
altered <- changed

has_raw <- rowSums(!is.na(x[, raw_cols])) >= 4      # a row with something to read
set.seed(seed)
pick <- function(idx, n) idx[sample.int(length(idx), min(n, length(idx)))]
s_f <- pick(which(fl & has_raw), n_flag)
s_a <- pick(which(!fl & altered & has_raw), n_alt)
s_u <- pick(which(!fl & !altered & has_raw), n_unt)
sel <- sample(c(s_f, s_a, s_u))                     # mixed order, no stratum visible
stratum <- ifelse(fl, "flagged", ifelse(altered, "changed", "left_alone"))
size <- c(flagged = sum(fl & has_raw), changed = sum(!fl & altered & has_raw),
          left_alone = sum(!fl & !altered & has_raw))

key <- data.frame(item = sprintf("item%04d", seq_along(sel)),
                  pid = x$pid[sel], day_num = x$day_num[sel], row_id = x$row_id[sel],
                  stratum = stratum[sel], pipeline_altered = altered[sel],
                  stratum_size = size[stratum[sel]],
                  stringsAsFactors = FALSE)
write.csv(key, file.path(out_dir, "KEY_do_not_share_with_annotators.csv"), row.names = FALSE)

sheet <- cbind(item = key$item, x[sel, raw_cols, drop = FALSE],
               error_present = "", error_type = "", intended_value_or_note = "", seconds_taken = "")
names(sheet)[2:11] <- c("bed_time", "bed_ampm", "sleep_time", "sleep_ampm", "awake_time", "awake_ampm",
                        "getup_time", "getup_ampm", "SOL_typed", "WASO_typed")
for (who in c("A", "B")) {
  write.csv(sheet, file.path(out_dir, sprintf("annotation_sheet_%s.csv", who)), row.names = FALSE, na = "")
}
cat(sprintf("%d items (%d flagged, %d changed, %d left alone) written to %s\n",
            length(sel), length(s_f), length(s_a), length(s_u), out_dir))
cat(sprintf("Population: %d flagged, %d changed without a flag, %d left-alone rows with raw entries.\n",
            size["flagged"], size["changed"], size["left_alone"]))
