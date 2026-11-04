# sol_waso_candidate_figures.R -- two figures from the candidate table written by
# sol_waso_candidate_scan.R. Read only. The table has participant ids, so it and the
# figures stay outside the repository.
#
# Figure X: each SOL entry typed like a clock time, as a distance (minutes, 12-hour dial)
#   from the participant's own recorded bedtime and sleep onset.
# Figure Y: the entries that need a decision, by field and by what the rule does with them.
#
# Usage (from the repository root):
#   Rscript validation/sol_waso_candidate_figures.R [candidate_entries.csv] [out_dir]
# Defaults: ~/Desktop/sol_waso_candidate_scan/candidate_entries.csv, same folder.

args <- commandArgs(trailingOnly = TRUE)
inf <- if (length(args) >= 1) args[1] else file.path(path.expand("~"), "Desktop", "sol_waso_candidate_scan", "candidate_entries.csv")
out_dir <- if (length(args) >= 2) args[2] else dirname(inf)
d <- read.csv(inf, stringsAsFactors = FALSE)
d <- d[!grepl("^valid but unusual", d$class), ]   # the 72 that need a decision

to_min <- function(x) { p <- strsplit(x, ":"); sapply(p, function(v) if (length(v) < 2) NA_real_ else as.numeric(v[1]) * 60 + as.numeric(v[2])) }
fold <- function(m) ((m + 360) %% 720) - 360       # signed difference on a 12-hour dial

# ---- Figure X --------------------------------------------------------------
# SOL entries that are not read as "minutes typed in the hours slot"
s <- d[d$field == "SOL" & d$suggested_decision != "keep_as_minutes", ]
typed <- (s$first_number %% 12) * 60 + s$minute_part
s$from_bed <- fold(typed - to_min(s$own_bedtime))
s$from_onset <- fold(typed - to_min(s$own_sleep_onset))
cols <- c("SOL recompute from clock time (auto)" = "darkgreen", "SOL typed bedtime -> missing" = "firebrick")
col <- ifelse(s$class %in% names(cols), cols[s$class], "grey50")
png(file.path(out_dir, "figure_X_sol_clock_vs_own_times.png"), width = 1300, height = 1000, res = 130)
plot(s$from_bed, s$from_onset, pch = 16, col = adjustcolor(col, 0.7), cex = 1.4, xlim = c(-120, 240), ylim = c(-120, 120),
     xlab = "typed time minus own bedtime (min, 12-hour dial)", ylab = "typed time minus own sleep onset (min, 12-hour dial)",
     main = paste0("SOL entries typed like a clock time (n = ", nrow(s), ")"))
rect(0, -5, 60, 5, border = "darkgreen", lty = 2)
text(30, 9, "auto-recompute zone", cex = 0.75, col = "darkgreen")
abline(h = 0, v = 0, col = "grey80")
legend("topright", bty = "n", cex = 0.85, pch = 16, col = c("darkgreen", "firebrick", "grey50"),
       legend = c("recomputed from the clock time", "typed the bedtime -> missing", "left for a person"))
dev.off()

# ---- Figure Y --------------------------------------------------------------
# One bar per outcome, in plain words; the colour is the field. The last bar is the only one
# that needs a human decision.
lab <- c(keep_as_minutes = "Kept as minutes\n(e.g. typed 5:00, meant 5 minutes)",
         recompute = "SOL recomputed from the clock time\n(typed time close to own sleep onset)",
         set_missing = "Set to missing\n(looks like a clock time, cannot be recovered)",
         person_decides = "NEEDS YOUR DECISION\n(unclear: rule does not decide)")
d$action <- factor(lab[d$suggested_decision], levels = rev(unname(lab)))
tab <- table(d$action, d$field)
png(file.path(out_dir, "figure_Y_candidates_by_action.png"), width = 1500, height = 900, res = 130)
op <- par(mar = c(4.5, 17, 4, 2))
b <- barplot(t(tab), horiz = TRUE, las = 1, col = c(SOL = "steelblue", WASO = "darkorange")[colnames(tab)], border = "white",
             xlim = c(0, max(rowSums(tab)) * 1.15), cex.names = 0.85,
             xlab = "number of entries",
             main = paste0("What happens to the ", nrow(d), " SOL / WASO entries that look like a clock time or a mistyped duration"),
             cex.main = 0.95, legend.text = colnames(tab), args.legend = list(x = "bottomright", bty = "n", title = "Field"))
text(rowSums(tab), b, labels = rowSums(tab), pos = 4, cex = 1.1, font = 2)
par(op); dev.off()
cat("Written to", out_dir, "\n"); print(tab)
