# reversal_classify.R -- nights whose self-reported times are out of order
#
# A "reversal" is a night whose four self-reported times violate
# bed <= sleep onset <= final awakening <= get-up. Most of them are not
# "two columns swapped": in the study data the commonest form is a single
# field entered 12 hours away from where it belongs. This file classifies
# each reversed night by the smallest edit that restores the order while
# keeping the night physiologically plausible.
#
# The classification is descriptive. It does not change any value and is
# not used by the cleaning steps; the figures use it, and a Methods
# section can quote the counts.
#
# Thresholds (all can be changed by the caller):
#   near_tie_min      a reversal whose inverted gaps are all <= this many
#                     minutes is treated as rounding, not an error
#   broken get-up     a get-up clock time <= 00:30 while awakening is
#                     >= 05:00 is an impossible value for that night
#   plausible night   SOL 0-300 min, time in bed 120-960 min, TST 30-720,
#                     wake-to-rise 0-300 (the same order of magnitude as
#                     the Step 5 limits; deliberately lenient)

# ---- internal helpers ------------------------------------------------------

.reversal_pre_cols <- function(x) {
  cols <- c(bed = "time_bed_am_hhmm_ampm", sleep = "time_sleep_am_hhmm_ampm",
            awake = "time_awake_am_hhmm_ampm", getup = "time_getup_am_hhmm_ampm")
  miss <- setdiff(unname(cols), names(x))
  if (length(miss)) {
    stop("Missing the following pre-correction columns: ",
         paste(miss, collapse = ", "),
         ". Pass corrected_ema_data (or pipeline_results()), which carry them.",
         call. = FALSE)
  }
  cols
}

.reversal_clock_min <- function(t) {
  as.numeric(format(t, "%H")) * 60 + as.numeric(format(t, "%M"))
}

.reversal_h <- function(a, b) as.numeric(difftime(a, b, units = "hours"))

.reversal_plausible <- function(z) {
  sol <- z$sleep - z$bed
  tib <- z$getup - z$bed
  tst <- z$awake - z$sleep
  pw  <- z$getup - z$awake
  z$bed <= z$sleep & z$sleep <= z$awake & z$awake <= z$getup &
    sol >= 0 & sol <= 300 & tib >= 120 & tib <= 960 &
    tst >= 30 & tst <= 720 & pw >= 0 & pw <= 300
}

.reversal_candidates <- function(z) {
  out <- list()
  add <- function(zz, fam, desc, fields) {
    if (isTRUE(all.equal(zz, z))) return(invisible())
    out[[length(out) + 1L]] <<- list(z = zz, family = fam, desc = desc,
                                     fields = fields, nfields = length(fields))
    invisible()
  }
  nm <- names(z)
  for (p in utils::combn(nm, 2, simplify = FALSE)) {
    zz <- z; zz[[p[1]]] <- z[[p[2]]]; zz[[p[2]]] <- z[[p[1]]]
    add(zz, "swap", paste(p, collapse = "<->"), p)
  }
  for (k in nm) for (s in c(-12, 12)) {
    zz <- z; zz[[k]] <- z[[k]] + s * 60
    add(zz, "pm12h", sprintf("%s %+dh", k, s), k)
  }
  for (p in utils::combn(nm, 2, simplify = FALSE)) {
    for (s1 in c(-12, 12)) for (s2 in c(-12, 12)) {
      zz <- z
      zz[[p[1]]] <- z[[p[1]]] + s1 * 60
      zz[[p[2]]] <- z[[p[2]]] + s2 * 60
      add(zz, "pm12h_x2", sprintf("%s %+dh, %s %+dh", p[1], s1, p[2], s2), p)
    }
  }
  out
}

# ---- exported --------------------------------------------------------------

#' Classify nights whose self-reported times are out of order
#'
#' A reversal is a night whose four self-reported times violate
#' \code{bed <= sleep onset <= final awakening <= get-up}. For each reversed
#' night this function records the three adjacent gaps and picks the smallest
#' edit that restores the order while keeping the night plausible: exchange two
#' fields (\code{swap}), shift one field by 12 hours (\code{pm12h}), or shift
#' two fields by 12 hours (\code{pm12h_x2}). Nights no edit can explain are
#' classed by what is visibly wrong with them: an impossible get-up value
#' (\code{D1_value_broken}), an awakening earlier than bedtime
#' (\code{D2_awake_before_bed}), or a rounding-sized gap (\code{D3_near_tie});
#' everything else is \code{E_unexplained}. Nothing is changed.
#'
#' The \code{detail} column names the field or pair, e.g.
#' \code{"swap:bed-sleep"}, \code{"pm12h:sleep-12h"}, or
#' \code{"pm12h_x2:whole_night"}.
#'
#' @param x A \code{sleep_diary} object, the \code{corrected_ema_data} data
#'   frame, or the list returned by \code{\link{pipeline_results}()}. The
#'   pre-correction columns \code{time_*_am_hhmm_ampm} must be present.
#' @param near_tie_min Numeric. A reversal whose inverted gaps are all at most
#'   this many minutes is classed as rounding. Default 10; \code{Inf} turns the
#'   check off.
#' @return A data frame with one row per reversed night: \code{row_id},
#'   \code{pid}, \code{day_num}, \code{pattern} (which adjacent pairs are
#'   inverted), the three \code{gap_*_h} columns, \code{class}, \code{detail},
#'   and the flags \code{is_near_tie}, \code{value_broken},
#'   \code{awake_before_bed}. The attribute \code{summary} holds the counts and
#'   rates; see \code{\link{reversal_summary}()}.
#' @seealso \code{\link{reversal_summary}()}
#' @export
#' @examples
#' \dontrun{
#' run_pipeline(config = "my_study.yaml")
#' head(classify_reversals())
#' }
classify_reversals <- function(x, near_tie_min = 10) {
  if (is.list(x) && !is.data.frame(x) && "corrected_ema_data" %in% names(x)) {
    x <- x$corrected_ema_data
  }
  if (inherits(x, "sleep_diary")) x <- as.data.frame(x)
  if (!is.data.frame(x)) stop("`x` must be a data frame, a sleep_diary, or pipeline_results().", call. = FALSE)
  cols <- .reversal_pre_cols(x)

  bed   <- x[[cols[["bed"]]]]
  sleep <- x[[cols[["sleep"]]]]
  awake <- x[[cols[["awake"]]]]
  getup <- x[[cols[["getup"]]]]

  bs <- .reversal_h(sleep, bed)
  sa <- .reversal_h(awake, sleep)
  ag <- .reversal_h(getup, awake)
  complete <- !is.na(bs) & !is.na(sa) & !is.na(ag)

  pattern <- paste0(ifelse(!is.na(bs) & bs < 0, "bs", ""),
                    ifelse(!is.na(sa) & sa < 0, "sa", ""),
                    ifelse(!is.na(ag) & ag < 0, "ag", ""))
  pattern[!is.na(pattern) & pattern == ""] <- "none"
  pattern[!complete] <- NA_character_
  is_reversal <- complete & pattern != "none"

  neg_bs <- ifelse(bs < 0, -bs, 0) * 60
  neg_sa <- ifelse(sa < 0, -sa, 0) * 60
  neg_ag <- ifelse(ag < 0, -ag, 0) * 60
  max_neg <- pmax(neg_bs, neg_sa, neg_ag)
  min_neg <- pmin(ifelse(bs < 0, -bs, Inf), ifelse(sa < 0, -sa, Inf),
                  ifelse(ag < 0, -ag, Inf)) * 60
  is_near_tie <- is_reversal & is.finite(near_tie_min) & max_neg <= near_tie_min

  gup_clk <- .reversal_clock_min(getup)
  awk_clk <- .reversal_clock_min(awake)
  bed_clk <- .reversal_clock_min(bed)
  value_broken <- is_reversal & !is.na(gup_clk) & !is.na(awk_clk) &
    gup_clk <= 30 & awk_clk >= 300
  awake_before_bed <- !is.na(awake) & !is.na(bed) & awake < bed &
    !is.na(awk_clk) & !is.na(bed_clk) & awk_clk < 360

  idx <- which(is_reversal)
  klass <- rep(NA_character_, length(bs))
  detail <- rep(NA_character_, length(bs))
  vals <- list(bed = bed, sleep = sleep, awake = awake, getup = getup)
  for (i in idx) {
    z <- lapply(vals, function(v) as.numeric(v[i]) / 60)
    cs <- Filter(function(cand) .reversal_plausible(cand$z), .reversal_candidates(z))
    if (length(cs)) {
      nf <- min(vapply(cs, `[[`, 0L, "nfields"))
      best <- Filter(function(cand) cand$nfields == nf, cs)
      fams <- sort(unique(vapply(best, `[[`, "", "family")))
      klass[i] <- if (length(fams) == 1) fams else paste0("ambiguous:", paste(fams, collapse = "+"))
      flds <- unique(vapply(best, function(cand) paste(cand$fields, collapse = "-"), ""))
      dirs <- unique(vapply(best, function(cand) {
        m <- regmatches(cand$desc, regexpr("[+-][0-9]+h", cand$desc))
        if (length(m)) m else ""
      }, ""))
      where <- if (length(flds) == 1) flds else
        (if (identical(klass[i], "pm12h_x2")) "whole_night" else "ambiguous")
      dir <- if (length(dirs) == 1 && nzchar(dirs) && length(flds) == 1) dirs else ""
      detail[i] <- paste0(klass[i], ":", where, dir)
      next
    }
    klass[i] <- if (awake_before_bed[i]) "D2_awake_before_bed"
                  else if (value_broken[i]) "D1_value_broken"
                  else if (is_near_tie[i]) "D3_near_tie"
                  else "E_unexplained"
    detail[i] <- paste0(klass[i], ":", switch(klass[i],
      D1_value_broken = "getup", D2_awake_before_bed = "awake",
      D3_near_tie = "clock", "value"))
  }

  ids <- if ("row_id" %in% names(x)) x$row_id else seq_len(nrow(x))
  pids <- if ("pid" %in% names(x)) x$pid else rep(NA, nrow(x))
  days <- if ("day_num" %in% names(x)) x$day_num else rep(NA, nrow(x))
  out <- data.frame(
    row_id = ids[idx], pid = pids[idx], day_num = days[idx],
    pattern = pattern[idx],
    gap_bs_h = round(bs[idx], 2), gap_sa_h = round(sa[idx], 2), gap_ag_h = round(ag[idx], 2),
    class = klass[idx], detail = detail[idx],
    is_near_tie = is_near_tie[idx], value_broken = value_broken[idx],
    awake_before_bed = awake_before_bed[idx],
    stringsAsFactors = FALSE
  )
  attr(out, "summary") <- .reversal_summary_of(out, sum(complete), near_tie_min)
  out
}

.reversal_summary_of <- function(rev, n_complete, near_tie_min) {
  reported <- rev$class[rev$class != "D1_value_broken"]
  counts <- c(all = nrow(rev), reported = length(reported))
  list(n_complete = n_complete,
       counts = counts,
       rates = if (n_complete > 0) round(100 * counts / n_complete, 2) else c(all = NA, reported = NA),
       by_class = table(rev$class),
       by_detail = table(rev$detail),
       near_tie_min = near_tie_min)
}

#' Summarise the reversals of a run
#'
#' Counts the nights whose self-reported times are out of order, by mechanism,
#' and gives the two rates a Methods section quotes: all reversals, and
#' reversals excluding nights whose get-up field holds an impossible value
#' (those are a field-value problem rather than a sequence problem).
#'
#' @inheritParams classify_reversals
#' @return A list with \code{n_complete} (nights with all four times),
#'   \code{counts}, \code{rates} (percent), \code{by_class}, \code{by_detail},
#'   and \code{near_tie_min}.
#' @seealso \code{\link{classify_reversals}()}
#' @export
#' @examples
#' \dontrun{
#' run_pipeline(config = "my_study.yaml")
#' str(reversal_summary())
#' }
reversal_summary <- function(x, near_tie_min = 10) {
  rev <- classify_reversals(x, near_tie_min = near_tie_min)
  attr(rev, "summary")
}
