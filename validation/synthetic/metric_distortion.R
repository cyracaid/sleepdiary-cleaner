# metric_distortion.R
#
# B2 (2026-10-05): How much do downstream sleep metrics move under different
# cleaning strategies? Four arms on the same injection benchmark:
#   clean      — pre-injection data (reference / truth)
#   no_clean   — corrupted values passed through untouched
#   naive      — a crude adjacent-swap auto-fix on the corrupted values
#   pipeline   — sleepcleanr's actual corrected output (run_ppv/)
#
# All four arms are scored with ONE shared, transparent formula so the
# comparison is apples-to-apples:
#   SOL = sleeponset - bedtime
#   TST = awakening  - sleeponset
#   TIB = getup      - bedtime
#   SE  = 100 * TST / TIB
# with midnight resolved sequentially (add 24 h whenever the clock drops).
#
#   Rscript validation/synthetic/metric_distortion.R

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

SYN <- "validation/synthetic"
RES <- file.path(SYN, "results")

## ── parsing ----------------------------------------------------------------
parse_hhmm <- function(x) {
  x <- trimws(as.character(x))
  out <- rep(NA_real_, length(x))
  for (i in seq_along(x)) {
    s <- x[i]
    if (is.na(s) || s == "" || s == "NA") next
    if (grepl(":", s)) {
      p <- strsplit(s, ":")[[1]]
      if (length(p) != 2) next
      h <- suppressWarnings(as.integer(p[1])); m <- suppressWarnings(as.integer(p[2]))
    } else if (grepl("^[0-9]{3,4}$", s)) {
      h <- as.integer(substr(s, 1, nchar(s) - 2)); m <- as.integer(substr(s, nchar(s) - 1, nchar(s)))
    } else next
    if (is.na(h) || is.na(m) || h > 23 || m > 59) next
    out[i] <- h * 60 + m
  }
  out
}

to24 <- function(mins, ampm) {
  a <- toupper(trimws(as.character(ampm)))
  h <- mins %/% 60
  h <- ifelse(a == "PM" & h != 12, h + 12, ifelse(a == "AM" & h == 12, 0, h))
  ifelse(h > 23, NA_real_, h * 60 + (mins %% 60))
}

# sequential midnight resolution: add 1440 whenever a clock drops
night_seq <- function(bed, slp, awk, gup) {
  m <- cbind(bed, slp, awk, gup)
  for (k in 2:4) m[, k] <- ifelse(!is.na(m[, k]) & !is.na(m[, k - 1]) & m[, k] < m[, k - 1],
                                  m[, k] + 1440, m[, k])
  m
}

metrics_from <- function(bed, slp, awk, gup) {
  m <- night_seq(bed, slp, awk, gup)
  sol <- m[, 2] - m[, 1]
  tst <- m[, 3] - m[, 2]
  tib <- m[, 4] - m[, 1]
  se  <- ifelse(!is.na(tib) & tib > 0, 100 * tst / tib, NA_real_)
  data.frame(sol = sol, tst = tst, tib = tib, se = se)
}

raw_cols <- function(d) {
  bed <- to24(parse_hhmm(d$time_bed_am_hhmm),   d$time_bed_am_ampm)
  slp <- to24(parse_hhmm(d$time_sleep_am_hhmm), d$time_sleep_am_ampm)
  awk <- to24(parse_hhmm(d$time_awake_am_hhmm), d$time_awake_am_ampm)
  gup <- to24(parse_hhmm(d$time_getup_am_hhmm), d$time_getup_am_ampm)
  list(bed = bed, slp = slp, awk = awk, gup = gup)
}

## ── arms -------------------------------------------------------------------
raw   <- readRDS(file.path(SYN, "corrupted_enrichment.rds"))
clean <- readRDS(file.path(SYN, "clean_plausible_enrichment_n7000.rds"))
pipe  <- read_csv(file.path(SYN, "run_ppv/output/cleaned_data_final.csv"), show_col_types = FALSE)

rc <- raw_cols(clean)
rn <- raw_cols(raw)

# naive arm: resolve midnight, then bubble-swap any still-inverted adjacent
# pair (one pass). A crude "swap it back" auto-fix, no AM/PM reasoning, no
# field-misentry handling — deliberately weaker than the pipeline.
nm <- night_seq(rn$bed, rn$slp, rn$awk, rn$gup)
for (k in 2:4) {
  flip <- !is.na(nm[, k]) & !is.na(nm[, k - 1]) & nm[, k] < nm[, k - 1]
  if (any(flip)) { tmp <- nm[flip, k - 1]; nm[flip, k - 1] <- nm[flip, k]; nm[flip, k] <- tmp }
}
nb <- nm[, 1]; ns <- nm[, 2]; na <- nm[, 3]; ng <- nm[, 4]

# pipeline arm: use cleaned datetime columns directly (true dates, no guessing)
minus <- function(ts) {
  if (inherits(ts, "POSIXct")) return(as.numeric(ts) / 60)
  tt <- suppressWarnings(as.POSIXct(trimws(as.character(ts)), tz = "UTC"))
  as.numeric(tt) / 60
}

pb <- minus(pipe$bedtime_selfreport_ts); ps <- minus(pipe$sleeponset_selfreport_ts)
pa <- minus(pipe$awakening_selfreport_ts); pg <- minus(pipe$getup_selfreport_ts)
D <- data.frame(sol = ps - pb, tst = pa - ps, tib = pg - pb,
                se = ifelse(pg - pb > 0, 100 * (pa - ps) / (pg - pb), NA_real_))

A <- metrics_from(rc$bed, rc$slp, rc$awk, rc$gup)
B <- metrics_from(rn$bed, rn$slp, rn$awk, rn$gup)
C <- metrics_from(nb, ns, na, ng)

# compare on the SAME rows valid in every arm
keep <- complete.cases(A$tst, B$tst, C$tst, D$tst) & A$tib > 0 & D$tib > 0
arms <- list(clean = A, no_clean = B, naive = C, pipeline = D)

summ <- lapply(names(arms), function(nm) {
  a <- arms[[nm]][keep, ]
  data.frame(arm = nm, n = sum(keep),
             mean_tst_h = round(mean(a$tst) / 60, 3),
             mean_sol_min = round(mean(a$sol), 2),
             mean_tib_h = round(mean(a$tib) / 60, 3),
             mean_se_pct = round(mean(a$se, na.rm = TRUE), 2),
             tst_shift_min_vs_clean = round(mean(a$tst - A$tst[keep]) / 1, 2),
             sol_shift_min_vs_clean = round(mean(a$sol - A$sol[keep]), 2),
             se_shift_pct_vs_clean = round(mean(a$se - A$se[keep], na.rm = TRUE), 3))
}) %>% bind_rows()

# Extra arm (2026-10-05): the pipeline's output after the rows it flagged for review
# are set aside (excluded), compared with the clean data on those same rows. Shows
# whether the residual distortion above sits in the flagged rows. Needs the
# per-row flag from ppv_cluster_ci.R (cluster_bootstrap_per_row.csv).
pr_path <- file.path(RES, "cluster_bootstrap_per_row.csv")
if (file.exists(pr_path)) {
  pr <- read.csv(pr_path, stringsAsFactors = FALSE)
  fl <- pr$detected_flag[match(raw$row_id, pr$row_id)]
  fl[is.na(fl)] <- FALSE
  sel <- keep & !fl
  extra <- lapply(c("clean_same_rows", "pipeline_excl_flagged"), function(nm) {
    a <- if (nm == "clean_same_rows") A[sel, ] else D[sel, ]
    data.frame(arm = nm, n = sum(sel),
               mean_tst_h = round(mean(a$tst) / 60, 3),
               mean_sol_min = round(mean(a$sol), 2),
               mean_tib_h = round(mean(a$tib) / 60, 3),
               mean_se_pct = round(mean(a$se, na.rm = TRUE), 2),
               tst_shift_min_vs_clean = round(mean(a$tst - A$tst[sel]), 2),
               sol_shift_min_vs_clean = round(mean(a$sol - A$sol[sel]), 2),
               se_shift_pct_vs_clean = round(mean(a$se - A$se[sel], na.rm = TRUE), 3))
  }) %>% bind_rows()
  summ <- bind_rows(summ, extra)
}

write_csv(summ, file.path(RES, "metric_distortion.csv"))
print(as.data.frame(summ))
cat("\nWrote:", file.path(RES, "metric_distortion.csv"), "  (rows compared:", sum(keep), ")\n")
