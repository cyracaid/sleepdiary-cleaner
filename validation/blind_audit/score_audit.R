# score_audit.R -- score the blind audit: annotator agreement, then the pipeline
# against the annotators' consensus, by stratum, with the population-level estimate.
#
# Usage:
#   Rscript validation/blind_audit/score_audit.R <dir with the key and the two completed sheets>
# Reads KEY_do_not_share_with_annotators.csv, annotation_sheet_A.csv, annotation_sheet_B.csv.
# error_present must be Y, N or U (unsure). Where A and B disagree, add an
# `adjudicated` column (Y or N) to annotation_sheet_A.csv; otherwise disagreements
# and unsure items are excluded from the pipeline comparison and counted.
args <- commandArgs(trailingOnly = TRUE)
d <- args[1]
key <- read.csv(file.path(d, "KEY_do_not_share_with_annotators.csv"), stringsAsFactors = FALSE)
A <- read.csv(file.path(d, "annotation_sheet_A.csv"), stringsAsFactors = FALSE, na.strings = "")
B <- read.csv(file.path(d, "annotation_sheet_B.csv"), stringsAsFactors = FALSE, na.strings = "")
stopifnot(identical(A$item, key$item), identical(B$item, key$item))
norm <- function(v) { v <- toupper(trimws(as.character(v))); ifelse(v %in% c("Y", "N", "U"), v, NA_character_) }
a <- norm(A$error_present); b <- norm(B$error_present)
stopifnot(!anyNA(a), !anyNA(b))

# ---- 1. annotator agreement ------------------------------------------------
lev <- c("Y", "N", "U")
tab <- table(factor(a, lev), factor(b, lev))
po <- sum(diag(tab)) / sum(tab)
pe <- sum(rowSums(tab) * colSums(tab)) / sum(tab)^2
kappa <- (po - pe) / (1 - pe)
cat(sprintf("Annotator agreement on error_present (%d items): raw %.1f%%, Cohen's kappa %.2f\n",
            sum(tab), 100 * po, kappa))
yn <- a %in% c("Y", "N") & b %in% c("Y", "N")
po2 <- mean(a[yn] == b[yn]); tab2 <- table(factor(a[yn], c("Y","N")), factor(b[yn], c("Y","N")))
pe2 <- sum(rowSums(tab2) * colSums(tab2)) / sum(tab2)^2
cat(sprintf("  excluding unsure: raw %.1f%%, kappa %.2f (n = %d)\n", 100 * po2, (po2 - pe2) / (1 - pe2), sum(yn)))
for (w in c("A", "B")) {
  s <- suppressWarnings(as.numeric(get(w)$seconds_taken))
  if (any(!is.na(s))) cat(sprintf("  annotator %s: median %.0f s per item\n", w, median(s, na.rm = TRUE)))
}

# ---- 2. consensus -----------------------------------------------------------
cons <- ifelse(a == b & a %in% c("Y", "N"), a, NA_character_)
if ("adjudicated" %in% names(A)) {
  adj <- norm(A$adjudicated); cons <- ifelse(is.na(cons) & adj %in% c("Y", "N"), adj, cons)
}
cat(sprintf("Consensus on %d of %d items; %d left out (disagreement or unsure).\n",
            sum(!is.na(cons)), length(cons), sum(is.na(cons))))
key$err <- cons == "Y"
use <- !is.na(cons)

# ---- 3. pipeline against consensus, by stratum ----------------------------------
ci <- function(x, n) if (n > 0) binom.test(x, n)$conf.int else c(NA, NA)
cnt <- function(st) { z <- key[use & key$stratum == st, ]; c(x = sum(z$err), n = nrow(z)) }
f <- cnt("flagged"); al <- cnt("changed"); u <- cnt("left_alone")
show <- function(lab, v, what) {
  c_ <- ci(v["x"], v["n"])
  cat(sprintf("%-10s %d of %d judged to carry an error (%s %.1f%%, exact 95%% CI %.1f-%.1f%%)\n",
              lab, v["x"], v["n"], what, 100 * v["x"] / v["n"], 100 * c_[1], 100 * c_[2]))
}
cat("\n")
show("Flagged:", f, "precision of flags")
show("Changed:", al, "share with an error")
show("Left alone:", u, "miss rate")

# ---- 4. population estimate (stratified) -------------------------------------
N <- sapply(c("flagged", "changed", "left_alone"), function(s) key$stratum_size[key$stratum == s][1])
est <- function(pf, pa, pu) {
  tp <- pf * N["flagged"] + pa * N["changed"]; fn <- pu * N["left_alone"]
  c(sens = unname(tp / (tp + fn)), missed = unname(fn))
}
p <- c(f["x"] / f["n"], al["x"] / al["n"], u["x"] / u["n"])
e <- est(p[1], p[2], p[3])
set.seed(1)
bs <- replicate(5000, est(rbinom(1, f["n"], p[1]) / f["n"],
                          if (al["n"] > 0) rbinom(1, al["n"], p[2]) / al["n"] else 0,
                          rbinom(1, u["n"], p[3]) / u["n"]))
q <- apply(bs, 1, quantile, c(.025, .975), na.rm = TRUE)
cat(sprintf("\nPopulation (%d flagged, %d changed, %d left-alone rows):\n", N[1], N[2], N[3]))
cat(sprintf("  errors present in left-alone rows (missed): %.0f (95%% %.0f-%.0f)\n", e["missed"], q[1, "missed"], q[2, "missed"]))
cat(sprintf("  sensitivity of flagging or changing: %.1f%% (95%% %.1f-%.1f%%)\n",
            100 * e["sens"], 100 * q[1, "sens"], 100 * q[2, "sens"]))
cat("Sensitivity is against what two annotators judged to be an error; it is not a\n",
    "measure against an independent gold standard of the intended values, and the\n",
    "annotators do not judge whether an alteration was correct.\n", sep = "")
