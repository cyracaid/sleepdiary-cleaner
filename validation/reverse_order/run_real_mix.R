# run_real_mix.R -- inject the reversal forms in the study's own proportions and
# score the pipeline on them.
#
# Written for the section "What the external mixes measure, and what they do not"
# in validation/synthetic/README_results.md. The external_inverted mix injects
# one form only (wake and rise exchanged); this script injects all the forms the
# study data shows, in the proportions the study data shows them, so the table
# it prints is the one that section quotes.
#
# Frozen parameters (change here, not downstream):
#   clean pool     500 participants x 14 days = 7,000 rows, plausible mode,
#                  healthy_adult population, seed 20260817
#   injection rate 5% of rows (350), split 36:38:14:14:9:6:6:1
#                  (sleep 36, bed<->sleep 38, whole night 14, bed 14,
#                   wake<->get-up 9, get-up 6, wake before bed 6, wake 1)
#   pipeline       the installed sleepcleanr (its version is written to
#                  results/real_mix_run_info.csv)
# Same seed, two runs, byte-identical output (checked; see the results file).
#
# What it does: generate a clean pool -> inject -> run the pipeline through
# validation/synthetic/run_one.R -> score every injected row against its
# pre-injection value.
#
# Outputs (all counts only, no participant identifiers):
#   validation/reverse_order/results/real_mix_outcome.csv
#   validation/reverse_order/results/real_mix_clean_rows.csv
#   validation/reverse_order/results/real_mix_run_info.csv
# The first is the same table as validation/synthetic/results/real_mix_outcome.csv.
#
# Usage (from the repository root):
#   Rscript validation/reverse_order/run_real_mix.R [--n_participants=500]
#           [--n_days=14] [--rate=0.05] [--work=<scratch dir>]

args <- commandArgs(trailingOnly = TRUE)
opt <- list(n_participants = 500L, n_days = 14L, rate = 0.05, seed = 20260817L, work = NULL)
for (a in args) {
  kv <- strsplit(sub("^--", "", a), "=")[[1]]
  if (kv[1] == "work") opt$work <- kv[2]
  else if (kv[1] %in% names(opt)) opt[[kv[1]]] <- as.numeric(kv[2])
}

repo <- "."
SYN <- file.path(repo, "validation", "synthetic")
out_dir <- file.path(repo, "validation", "reverse_order", "results")
work <- if (!is.null(opt$work)) opt$work else file.path(tempdir(), sprintf("real_mix_%d", opt$seed))
dir.create(work, recursive = TRUE, showWarnings = FALSE)
cat("工作目录:", work, "\n")

# ---- 1. 干净数据 -----------------------------------------------------------
clean_rds <- file.path(work, "clean.rds")
if (!file.exists(clean_rds)) {
  system2("Rscript", c(file.path(SYN, "generate_clean_data.R"),
    paste0("--n_participants=", opt$n_participants), paste0("--n_days=", opt$n_days),
    "--mode=plausible", "--population=healthy_adult",
    paste0("--seed=", opt$seed), paste0("--out=", clean_rds)))
}
d <- readRDS(clean_rds)
cat("干净数据:", nrow(d), "行\n")

# ---- 2. 注入 ---------------------------------------------------------------
to_min <- function(hhmm, ampm) {
  h <- suppressWarnings(as.integer(sub(":.*$", "", hhmm)))
  m <- suppressWarnings(as.integer(sub("^.*:", "", hhmm)))
  h24 <- ifelse(ampm == "PM" & h != 12, h + 12, ifelse(ampm == "AM" & h == 12, 0, h))
  h24 * 60 + m
}
from_min <- function(mm) {
  mm <- mm %% 1440
  h <- mm %/% 60; m <- round(mm %% 60)
  list(hhmm = sprintf("%d:%02d", ifelse(h %% 12 == 0, 12, h %% 12), m),
       ampm = ifelse(h < 12, "AM", "PM"))
}
fld <- function(f) c(hhmm = paste0("time_", f, "_am_hhmm"), ampm = paste0("time_", f, "_am_ampm"))
getf <- function(x, f, i) list(hhmm = x[[fld(f)[1]]][i], ampm = x[[fld(f)[2]]][i])
setf <- function(x, f, i, v) { x[[fld(f)[1]]][i] <- v$hhmm; x[[fld(f)[2]]][i] <- v$ampm; x }
shift12 <- function(v, dir) from_min(to_min(v$hhmm, v$ampm) + dir * 720)

F <- c("bed", "sleep", "awake", "getup")
types <- c("single_field_12h:入睡", "swap:上床-入睡", "night_block_12h",
           "single_field_12h:上床", "swap:醒来-起床", "single_field_12h:起床",
           "awake_before_bed", "single_field_12h:醒来")
w <- c(36, 38, 14, 14, 9, 6, 6, 1)           # 真实 124 条（2026-11-03 修正后）
n_inj <- round(opt$rate * nrow(d))
counts <- as.integer(round(n_inj * w / sum(w)))
while (sum(counts) < n_inj) counts[which.max(w)] <- counts[which.max(w)] + 1L
while (sum(counts) > n_inj) counts[which.max(w)] <- counts[which.max(w)] - 1L
names(counts) <- types
cat("注入:", sum(counts), "行（", paste(counts, collapse = " / "), "）\n")

ok <- complete.cases(d[, unlist(lapply(F, fld))])
pool <- which(ok)
set.seed(opt$seed)
truth <- list(); corrupted <- d
for (k in seq_along(types)) {
  if (counts[k] == 0) next
  pick <- sample(pool, counts[k]); pool <- setdiff(pool, pick)
  for (i in pick) {
    before <- lapply(F, function(f) getf(d, f, i))
    names(before) <- F
    x <- corrupted
    if (types[k] == "single_field_12h:入睡") {
      # 35/36 晚 12 小时，1/36 早 12 小时
      dir <- if (runif(1) < 35 / 36) 1 else -1
      x <- setf(x, "sleep", i, shift12(getf(x, "sleep", i), dir))
    } else if (types[k] == "single_field_12h:上床") {
      x <- setf(x, "bed", i, shift12(getf(x, "bed", i), 1))
    } else if (types[k] == "single_field_12h:起床") {
      x <- setf(x, "getup", i, shift12(getf(x, "getup", i), -1))
    } else if (types[k] == "single_field_12h:醒来") {
      x <- setf(x, "awake", i, shift12(getf(x, "awake", i), -1))
    } else if (types[k] == "swap:上床-入睡") {
      a <- getf(x, "bed", i); b <- getf(x, "sleep", i)
      x <- setf(setf(x, "bed", i, b), "sleep", i, a)
    } else if (types[k] == "swap:醒来-起床") {
      a <- getf(x, "awake", i); b <- getf(x, "getup", i)
      x <- setf(setf(x, "awake", i, b), "getup", i, a)
    } else if (types[k] == "night_block_12h") {
      x <- setf(x, "bed",   i, shift12(getf(x, "bed",   i), 1))
      x <- setf(x, "sleep", i, shift12(getf(x, "sleep", i), 1))
    } else if (types[k] == "awake_before_bed") {
      back <- sample(30:180, 1)
      bd <- getf(x, "bed", i)
      x <- setf(x, "awake", i, from_min(to_min(bd$hhmm, bd$ampm) - back))
    }
    corrupted <- x
    truth[[length(truth) + 1L]] <- data.frame(
      row_id = i, class = types[k], field = "",
      bed = before$bed$hhmm,   bed_ampm = before$bed$ampm,
      sleep = before$sleep$hhmm, sleep_ampm = before$sleep$ampm,
      awake = before$awake$hhmm, awake_ampm = before$awake$ampm,
      getup = before$getup$hhmm, getup_ampm = before$getup$ampm,
      stringsAsFactors = FALSE)
  }
}
truth <- do.call(rbind, truth)
corr_rds <- file.path(work, "corrupted.rds"); saveRDS(corrupted, corr_rds)
write.csv(truth, file.path(work, "truth.csv"), row.names = FALSE)

# ---- 3. 跑管线 -------------------------------------------------------------
run_dir <- file.path(work, "run")
unlink(run_dir, recursive = TRUE)
cat("跑管线...\n")
log <- system2("Rscript", c(file.path(SYN, "run_one.R"), corr_rds, run_dir, "real_mix"),
               stdout = TRUE, stderr = TRUE)
cat(tail(log, 3), sep = "\n")
corrected <- readRDS(file.path(run_dir, "corrected_ema_data.rds"))
review    <- readRDS(file.path(run_dir, "review_output.rds"))

# ---- 4. 评分 ---------------------------------------------------------------
# 注意：不能用 as.numeric()/60 取钟点——管线把时间解析成本地时区，
# epoch 分钟是 UTC 的，会整体偏 8/9 小时。必须用 format()（按对象自己的时区）。
clk <- function(x) as.integer(format(x, "%H")) * 60L + as.integer(format(x, "%M"))
cd <- corrected
cd$row_id <- as.integer(cd$row_id)
post <- list(bed = clk(cd$time_bed_corrected), sleep = clk(cd$time_sleep_corrected),
             awake = clk(cd$time_awake_corrected), getup = clk(cd$time_getup_corrected))
orig <- list(bed = to_min(truth$bed, truth$bed_ampm), sleep = to_min(truth$sleep, truth$sleep_ampm),
             awake = to_min(truth$awake, truth$awake_ampm), getup = to_min(truth$getup, truth$getup_ampm))

same_clock <- function(a, b) { d <- abs(a - b) %% 1440; pmin(d, 1440 - d) <= 1 }
tj <- match(truth$row_id, cd$row_id)
inv_d <- list(bed = to_min(d$time_bed_am_hhmm, d$time_bed_am_ampm),
              sleep = to_min(d$time_sleep_am_hhmm, d$time_sleep_am_ampm),
              awake = to_min(d$time_awake_am_hhmm, d$time_awake_am_ampm),
              getup = to_min(d$time_getup_am_hhmm, d$time_getup_am_ampm))

res <- data.frame(class = truth$class, stringsAsFactors = FALSE)
for (f in F) {
  res[[paste0("was_changed_", f)]] <- !same_clock(post[[f]][tj], inv_d[[f]][truth$row_id])
  res[[paste0("is_true_", f)]]     <- same_clock(post[[f]][tj], orig[[f]])
}
res$changed <- rowSums(res[, grep("^was_changed_", names(res))]) > 0
res$correct <- rowSums(res[, grep("^is_true_", names(res))]) == 4
flagged_ids <- review$data_with_flags$row_id[review$data_with_flags$needs_review_flag %in% TRUE]
res$flagged <- truth$row_id %in% flagged_ids
res$outcome <- with(res, ifelse(correct, "CORRECT",
                        ifelse(changed, "MISREPAIRED",
                        ifelse(flagged, "FLAGGED_UNRESOLVED", "MISSED"))))

wilson <- function(k, n, z = 1.96) {
  if (n == 0) return(c(NA, NA)); p <- k / n; den <- 1 + z^2 / n
  ctr <- (p + z^2 / (2 * n)) / den
  half <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / den
  c(max(0, ctr - half), min(1, ctr + half))
}
tab <- do.call(rbind, lapply(sort(unique(res$class)), function(g) {
  r <- res[res$class == g, ]
  k2 <- sum(r$outcome %in% c("CORRECT", "FLAGGED_UNRESOLVED"))
  ci <- wilson(k2, nrow(r))
  data.frame(class = g, n_injected = nrow(r),
             flagged_or_corrected_pct = round(100 * k2 / nrow(r), 1),
             ci_low = round(100 * ci[1], 1), ci_high = round(100 * ci[2], 1),
             corrected_pct = round(100 * mean(r$outcome == "CORRECT"), 1),
             flagged_only_pct = round(100 * mean(r$outcome == "FLAGGED_UNRESOLVED"), 1),
             missed_pct = round(100 * mean(r$outcome == "MISSED"), 1),
             wrong_repairs = sum(r$outcome == "MISREPAIRED"), stringsAsFactors = FALSE)
}))
tot <- data.frame(class = "ALL", n_injected = nrow(res),
                  flagged_or_corrected_pct = round(100 * mean(res$outcome %in% c("CORRECT", "FLAGGED_UNRESOLVED")), 1),
                  ci_low = NA, ci_high = NA,
                  corrected_pct = round(100 * mean(res$outcome == "CORRECT"), 1),
                  flagged_only_pct = round(100 * mean(res$outcome == "FLAGGED_UNRESOLVED"), 1),
                  missed_pct = round(100 * mean(res$outcome == "MISSED"), 1),
                  wrong_repairs = sum(res$outcome == "MISREPAIRED"))
tab <- rbind(tab, tot)
write.csv(tab, file.path(out_dir, "real_mix_outcome.csv"), row.names = FALSE)

# 干净行
clean_ok <- complete.cases(d[, unlist(lapply(F, fld))]) & !(seq_len(nrow(d)) %in% truth$row_id)
change_any <- rep(FALSE, nrow(d))
for (f in F) change_any <- change_any | !same_clock(post[[f]], inv_d[[f]])
clean_altered <- sum(clean_ok & change_any)
clean_flagged <- sum(clean_ok & seq_len(nrow(d)) %in% flagged_ids)
cat(sprintf("\n干净行 %d 条：被改 %d（%.2f%%），被标 %d（%.2f%%）\n",
            sum(clean_ok), clean_altered, 100 * clean_altered / sum(clean_ok),
            clean_flagged, 100 * clean_flagged / sum(clean_ok)))
write.csv(data.frame(n_clean = sum(clean_ok), altered = clean_altered, flagged = clean_flagged),
          file.path(out_dir, "real_mix_clean_rows.csv"), row.names = FALSE)

meta <- data.frame(
  r_version = R.version.string,
  sleepcleanr = tryCatch(as.character(utils::packageVersion("sleepcleanr")), error = function(e) NA),
  seed = opt$seed, n_participants = opt$n_participants, n_days = opt$n_days,
  rate = opt$rate, n_clean = nrow(d), n_injected = nrow(truth),
  n_flagged_clean = clean_flagged, n_altered_clean = clean_altered,
  run_time_local = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  stringsAsFactors = FALSE)
write.csv(meta, file.path(out_dir, "real_mix_run_info.csv"), row.names = FALSE)

cat("\n== 结果 ==\n"); print(tab, row.names = FALSE)
cat("\n写出:", file.path(out_dir, "real_mix_outcome.csv"), "\n")
