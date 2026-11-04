# figure_reverse_order.R -- the two-panel figure for the reversed-order section
#
# Panel (a)  the study data: every night whose four self-reported times are out
#            of order, by mechanism, split by who repaired it (algorithm, human
#            review, or neither).
# Panel (b)  the same rows, repaired by the algorithm alone: the study data next
#            to the injection.
#
# Both panels are horizontal so the rows line up one-to-one.
#
# Reads counts only:
#   results/outcome_by_class.csv   (study data)
#   results/real_mix_outcome.csv   (injection)
# Writes:
#   results/figure_reverse_order.pdf  and  .png (300 dpi)
#
# Usage (from the repository root): Rscript validation/reverse_order/figure_reverse_order.R

res <- file.path("validation", "reverse_order", "results")
real <- read.csv(file.path(res, "outcome_by_class.csv"), stringsAsFactors = FALSE)
syn  <- read.csv(file.path(res, "real_mix_outcome.csv"), stringsAsFactors = FALSE)

real_map <- data.frame(
  real  = c("swap:bed-sleep", "swap:awake-getup", "pm12h:sleep-12h", "pm12h:sleep+12h",
            "pm12h:bed-12h", "pm12h:getup+12h", "pm12h:awake+12h", "pm12h_x2:whole_night",
            "D2_awake_before_bed:awake", "D1_value_broken:getup", "D3_near_tie:clock",
            "E_unexplained:value"),
  label = c("bed <-> sleep exchanged", "wake <-> get-up exchanged", "sleep onset 12 h off",
            "sleep onset 12 h off", "bed time 12 h off", "get-up 12 h off",
            "wake time 12 h off", "whole night 12 h off", "wake before bed time",
            "value broken (get-up 00:0x)", "rounding-sized gap", "unexplained"),
  stringsAsFactors = FALSE)

syn_map <- data.frame(
  syn   = c("swap:上床-入睡", "swap:醒来-起床", "single_field_12h:入睡",
            "single_field_12h:上床", "single_field_12h:起床", "single_field_12h:醒来",
            "night_block_12h", "awake_before_bed"),
  label = c("bed <-> sleep exchanged", "wake <-> get-up exchanged", "sleep onset 12 h off",
            "bed time 12 h off", "get-up 12 h off", "wake time 12 h off",
            "whole night 12 h off", "wake before bed time"),
  stringsAsFactors = FALSE)

ord <- c("bed <-> sleep exchanged", "sleep onset 12 h off", "bed time 12 h off",
         "whole night 12 h off", "wake <-> get-up exchanged", "get-up 12 h off",
         "wake time 12 h off", "wake before bed time",
         "value broken (get-up 00:0x)", "rounding-sized gap", "unexplained")

# ---- panel (a): study data -------------------------------------------------
a <- merge(real[, c("class", "n", "fixed_by_algorithm", "fixed_by_human")],
           real_map, by.x = "class", by.y = "real")
a <- aggregate(cbind(n, fixed_by_algorithm, fixed_by_human) ~ label, data = a, FUN = sum)
a <- a[match(ord, a$label), ]
a$neither <- a$n - a$fixed_by_algorithm - a$fixed_by_human

# ---- panel (b): algorithm alone, study vs injection ------------------------
b <- merge(syn[syn$class != "ALL", c("class", "n_injected", "corrected_pct")],
           syn_map, by.x = "class", by.y = "syn")
study_rate <- a$fixed_by_algorithm / a$n * 100                 # all 11 rows
inj_rate   <- b$corrected_pct[match(ord, b$label)]             # NA where not injected
inj_rate[is.na(inj_rate)] <- 0
injectable <- ord %in% b$label

draw <- function(file, dev_open) {
  dev_open(file)
  par(mfrow = c(1, 2), oma = c(0, 0, 2.8, 0))

  # panel (a)
  par(mar = c(4.2, 16.8, 4.6, 1.2), cex.axis = 0.8)
  m <- rbind(a$fixed_by_algorithm, a$fixed_by_human, a$neither)
  colnames(m) <- a$label
  barplot(m, horiz = TRUE, las = 1, border = NA,
          col = c("#1E88E5", "#90A4AE", "#E0E0E0"), xlab = "Nights",
          cex.names = 0.8, main = "a  Study data: who repaired each form", cex.main = 1)
  mtext(sprintf("N = %d reversed nights of 2,848 with all four times (%.1f%%)",
                sum(a$n), 100 * sum(a$n) / 2848), side = 3, line = 0.6, cex = 0.72)
  legend("topright", c("algorithm", "human review", "neither"),
         fill = c("#1E88E5", "#90A4AE", "#E0E0E0"), border = NA, bty = "n", cex = 0.72)

  # panel (b)
  par(mar = c(4.2, 0.8, 4.6, 1.2), cex.axis = 0.8)
  mb <- rbind(study = study_rate, injected = inj_rate)
  colnames(mb) <- a$label
  bp <- barplot(mb, horiz = TRUE, beside = TRUE, las = 1, border = NA,
                col = c("#1565C0", "#90CAF9"), xlim = c(0, 105), axes = FALSE,
                names.arg = rep("", ncol(mb)),      # labels live in panel (a) only
                xlab = "Repaired by the algorithm (%)",
                main = "b  Algorithm alone: study vs injection", cex.main = 1)
  row_mid <- as.numeric(bp[1, ])
  axis(1, at = seq(0, 100, 25), labels = paste0(seq(0, 100, 25), "%"))
  abline(v = seq(0, 100, 25), col = "#EEEEEE")
  # mark the rows the benchmark cannot inject
  for (k in which(!injectable)) {
    text(2, row_mid[k], "not injected", adj = 0, cex = 0.62, col = "#9E9E9E")
  }
  legend("topright", c("study data", "injected"), fill = c("#1565C0", "#90CAF9"),
         border = NA, bty = "n", cex = 0.72)

  mtext("Reversed nights in self-reported sleep diaries: what the pipeline repairs, and where it does not",
        side = 3, outer = TRUE, line = 0.6, cex = 1.05, font = 2)
  dev.off()
  invisible(file)
}

draw(file.path(res, "figure_reverse_order.pdf"), function(f) pdf(f, width = 13, height = 6.4))
draw(file.path(res, "figure_reverse_order.png"),
     function(f) png(f, width = 13, height = 6.4, units = "in", res = 300))

cat(sprintf("panel (a): %d nights; algorithm %d, human %d, neither %d\n",
            sum(a$n), sum(a$fixed_by_algorithm), sum(a$fixed_by_human), sum(a$neither)))
cat(sprintf("panel (b): study %.0f%% vs injected %.0f%% (injectable forms only)\n",
            100 * sum(a$fixed_by_algorithm[injectable]) / sum(a$n[injectable]),
            mean(inj_rate[injectable])))
cat("wrote", file.path(res, "figure_reverse_order.pdf"), "and .png\n")
