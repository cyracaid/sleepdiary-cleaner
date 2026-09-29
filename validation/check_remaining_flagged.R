## Check all remaining fasttrack-flagged rows against output/corrected_ema_data.rds
## Run from ~/Documents/splsleep :
##   Rscript check_remaining_flagged.R
## or paste the body into an interactive R session after cd-ing there.

d <- readRDS("output/corrected_ema_data.rds")

targets <- read.table(text = "
pid,day_num
2720,12
2720,1
2720,2
2720,3
10989,4
10989,3
10516,8
1265,4
1265,13
10323,8
3868,4
6143,1
7288,4
6032,11
3268,13
10041,3
2854,3
4141,6
10599,9
4296,10
6805,2
1035,11
1035,14
2095,7
2095,12
6855,3
11554,5
", header = TRUE, sep = ",")

cols <- c("pid","day_num","row_id",
          "time_bed_am_hhmm_ampm","time_sleep_am_hhmm_ampm",
          "time_bed_corrected","time_sleep_corrected",
          "correction_type","corrected","manually_corrected")
cols <- cols[cols %in% names(d)]

out <- do.call(rbind, lapply(seq_len(nrow(targets)), function(i) {
  p <- targets$pid[i]; dn <- targets$day_num[i]
  rows <- d[d$pid == p & d$day_num == dn & !is.na(d$time_bed_am_hhmm_ampm), cols]
  if (nrow(rows) == 0) {
    data.frame(pid = p, day_num = dn, row_id = NA, note = "NO MATCHING ROW FOUND")
  } else {
    rows$note <- ifelse(
      as.character(rows$time_bed_am_hhmm_ampm) == as.character(rows$time_bed_corrected) &
      as.character(rows$time_sleep_am_hhmm_ampm) == as.character(rows$time_sleep_corrected),
      "UNCHANGED (raw == corrected, not touched by any auto/manual step)",
      "CHANGED (auto and/or manual correction applied)"
    )
    rows
  }
}))

print(out, row.names = FALSE)
write.csv(out, "validation/flagged_rows_vs_corrected_ema_data.csv", row.names = FALSE)
cat("\nWrote validation/flagged_rows_vs_corrected_ema_data.csv\n")
