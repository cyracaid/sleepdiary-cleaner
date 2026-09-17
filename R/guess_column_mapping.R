#' Guess column mapping from raw column names
#'
#' Data-first schema inference for \code{clean_sleep_diary()}. Every inference
#' decision is recorded (the package never silently infers schema): each input
#' column gets a row with the matched internal field, the rule that matched,
#' a confidence, a status, and the candidate set when ambiguous.
#'
#' Matching is deterministic: exact alias match (confidence 1.0) wins over
#' semantic substring match (0.6). A column that ties between two internal
#' fields is marked \code{ambiguous} with its candidate set and is NOT mapped.
#' Required schema fields with no matching column are marked \code{absent} so
#' \code{validate_schema()} can fail loudly instead of guessing.
#'
#' @param cols Character vector of raw column names.
#' @return A list with two elements:
#'   \item{decisions}{data.frame, one row per input column: user_col,
#'     internal_col, match_rule, confidence, status, candidate_set.}
#'   \item{mapping}{list in the config \code{column_mapping} shape, ready to
#'     merge into a config for \code{adapt_columns()}.}
#' @export
guess_column_mapping <- function(cols) {
  norm <- function(x) tolower(gsub("[^a-zA-Z0-9]", "", x))
  nc <- vapply(cols, norm, character(1))

  # internal field -> (exact aliases, semantic substring tokens)
  ALIAS <- list(
    pid             = c("pid","id","ids","subject","subjectid","subject_id","participant","participant_id","ptid","subid"),
    day_num         = c("day","daynum","day_num","daynumber","day_number","dayno","studyday","study_day","dayindex","day_index"),
    time_bed_hhmm   = c("bedtime","bedtimehhmm","bed_time","time_bed","timebed","timeinbed","in_bed","bed","bedhhmm","bed_hhmm","tb"),
    time_bed_ampm   = c("bedampm","bed_ampm","bedtimeampm","bedtime_ampm","bed_am_pm"),
    time_sleep_hhmm = c("sleeptime","sleeptimehhmm","sleep_time","time_sleep","timesleep","sleeponset","sleep_onset","sleepstart","sleep_start","lightsout","lights_out","fallasleep","fellasleep","sleep","sleephhmm","sleep_hhmm"),
    time_sleep_ampm = c("sleepampm","sleep_ampm","sleeptimeampm","sleeptime_ampm","sleep_am_pm"),
    time_awake_hhmm = c("awake","awaketime","awake_time","time_awake","timeawake","waketime","wake_time","timewake","wake","woke","wakeup","wake_up","midwake","midsleep","awakehhmm","awake_hhmm"),
    time_awake_ampm = c("awakeampm","awake_ampm","wakeampm","wake_ampm","wake_am_pm","wakeupampm","wakeup_ampm","wake_up_ampm"),
    time_getup_hhmm = c("getup","getuptime","getup_time","time_getup","timegetup","risetime","rise_time","rise","outofbed","out_of_bed","getoutofbed","get_up","gethhmm","getup_hhmm"),
    time_getup_ampm = c("getupampm","getup_ampm","getup_am_pm","riseampm","rise_ampm"),
    sol             = c("sol","solminutes","sol_minutes","solmin","sol_min","sleeponsetlatency","sleep_onset_latency","duration_sol","sol_estimate","sol_duration","sollatency"),
    waso            = c("waso","wasominutes","waso_minutes","wasomin","waso_min","wakeafteronset","wake_after_onset","duration_waso","waso_estimate","waso_duration"),
    date_bed        = c("startdate","start_date","date","beddate","bed_date","sleepdate","sleep_date","diarydate","diary_date"),
    waso_count      = c("wasocount","waso_count","numwaso","num_waso","nwaso","wasobouts","waso_bouts","nwasobouts"),
    nap             = c("nap","napminutes","nap_minutes","napduration","nap_duration","naptime","nap_time","totalnap","total_nap"),
    caffeine        = c("caffeine","caffeinated","caffeinedrinks","caffeine_drinks","caffeine_count","numcaffeine","num_caffeine","caff"),
    alcohol         = c("alcohol","alcoholic","alcoholdrinks","alcohol_drinks","alcohol_count","numalcohol","num_alcohol")
  )
  TOKENS <- list(
    pid             = c("pid","participant","subject","id"),
    day_num         = c("daynum","daynumber","day"),
    time_bed_hhmm   = c("bed","bedtime"),
    time_bed_ampm   = c("bedampm","bedtimeampm"),
    time_sleep_hhmm = c("sleep","sleeptime","sleeponset"),
    time_sleep_ampm = c("sleepampm"),
    time_awake_hhmm = c("wake","awake","wakeup"),
    time_awake_ampm = c("wakeampm","awakeampm"),
    time_getup_hhmm = c("getup","rise","getup"),
    time_getup_ampm = c("getupampm","riseampm"),
    sol             = c("sol","sleeponsetlatency"),
    waso            = c("waso","wakeafteronset"),
    date_bed        = c("startdate","date"),
    waso_count      = c("wasocount","numwaso"),
    nap             = c("nap"),
    caffeine        = c("caffeine","caff"),
    alcohol         = c("alcohol","alcoh")
  )

  fields <- names(ALIAS)

  score_matrix <- matrix(0, nrow = length(nc), ncol = length(fields),
                         dimnames = list(names(nc), fields))
  rule_matrix <- matrix("", nrow = length(nc), ncol = length(fields),
                        dimnames = list(names(nc), fields))
  for (ci in seq_along(nc)) {
    for (fi in seq_along(fields)) {
      if (nc[ci] %in% ALIAS[[fields[fi]]]) {
        score_matrix[ci, fi] <- 1.0
        rule_matrix[ci, fi] <- "exact_name"
      } else if (any(vapply(TOKENS[[fields[fi]]], function(t) grepl(t, nc[ci], fixed = TRUE), logical(1)))) {
        score_matrix[ci, fi] <- 0.6
        rule_matrix[ci, fi] <- "semantic_substring"
      }
    }
  }

  # per input column: best field, tie -> ambiguous
  decisions <- vector("list", length(nc))
  for (ci in seq_along(nc)) {
    scores <- score_matrix[ci, ]
    best <- which(scores == max(scores))
    if (max(scores) == 0) {
      decisions[[ci]] <- data.frame(
        user_col = names(nc)[ci], internal_col = NA_character_,
        match_rule = "no_match", confidence = 0, status = "no_match",
        candidate_set = "", stringsAsFactors = FALSE)
    } else if (length(best) > 1 && length(unique(scores[best])) == 1) {
      # two fields tied at the top -> ambiguous (do NOT silently pick)
      ties <- fields[best]
      decisions[[ci]] <- data.frame(
        user_col = names(nc)[ci], internal_col = NA_character_,
        match_rule = "ambiguous_tie", confidence = max(scores),
        status = "ambiguous", candidate_set = paste(ties, collapse = " | "),
        stringsAsFactors = FALSE)
    } else {
      fi <- fields[best[1]]
      decisions[[ci]] <- data.frame(
        user_col = names(nc)[ci], internal_col = fi,
        match_rule = rule_matrix[ci, fi], confidence = scores[fi],
        status = "matched", candidate_set = "",
        stringsAsFactors = FALSE)
    }
  }
  dec <- do.call(rbind, decisions)

  # per field: reject any field whose best-scoring user column was ambiguous
  # or that has no match at all -> absent (fail-loud upstream)
  matched <- dec[dec$status == "matched", ]
  field_rows <- split(matched, matched$internal_col)
  for (f in fields) {
    rows <- field_rows[[f]]
    if (is.null(rows) || nrow(rows) == 0) {
      dec <- rbind(dec, data.frame(
        user_col = NA_character_, internal_col = f,
        match_rule = "no_input", confidence = 0, status = "absent",
        candidate_set = "", stringsAsFactors = FALSE))
    }
  }
  dec <- dec[order(dec$internal_col, -dec$confidence, na.last = TRUE), ]
  rownames(dec) <- NULL

  # build config-shaped mapping: section -> internal field -> user col
  SECTION <- list(
    identifiers = c("pid", "day_num", "date_bed"),
    timestamp   = c("time_bed_hhmm", "time_bed_ampm", "time_sleep_hhmm", "time_sleep_ampm",
                    "time_awake_hhmm", "time_awake_ampm", "time_getup_hhmm", "time_getup_ampm"),
    duration    = c("sol", "waso", "nap"),
    waso_count  = "waso_count",
    substance   = c("caffeine", "alcohol")
  )
  mapping <- list()
  for (sec in names(SECTION)) {
    sec_out <- list()
    for (f in SECTION[[sec]]) {
      hit <- dec[dec$status == "matched" & dec$internal_col == f, ]
      if (nrow(hit) > 1) {
        # two different user columns both matched the same field -> record as
        # ambiguous instead of silently picking the first
        cand <- unique(hit$user_col)
        idx <- which(dec$internal_col == f & dec$status == "matched")
        dec$status[idx] <- "ambiguous"
        dec$candidate_set[idx] <- paste(cand, collapse = " | ")
        dec$internal_col[idx] <- NA_character_
        sec_out[[f]] <- NULL
      } else {
        sec_out[[f]] <- if (nrow(hit) == 1) hit$user_col[1] else NULL
      }
    }
    mapping[[sec]] <- sec_out
  }

  list(decisions = dec, mapping = mapping)
}