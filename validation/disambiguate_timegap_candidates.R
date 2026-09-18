#!/usr/bin/env Rscript
# =============================================================================
# disambiguate_timegap_candidates.R
#
# PURPOSE
#   Turn the locked candidate list from derive_timegap_candidates.R (default
#   46 rows -- re-derive, don't assume the number; see that script's header)
#   into two independent annotation worksheets, one for each human reviewer,
#   plus computed decision-support context per row -- for whichever
#   candidates don't already have a real answer on file (see v3 -> v4 below;
#   as of this version, most of the reduction comes from there, not from
#   scoring).
#
#   Disambiguation target (locked 2026-09-02, per direct confirmation): for
#   each candidate row, is this a genuine DATA ERROR (AM/PM decode slip or a
#   field swap -- something that should be corrected) or genuine PARTICIPANT
#   BEHAVIOR (an unusual but real schedule -- something that should be left
#   alone)? This script does NOT decide that for the rows that still need a
#   human. It computes context to help a human decide faster, and structures
#   two SEPARATE worksheets so the two reviewers' judgments are captured
#   independently before being compared -- deliberately avoiding the failure
#   mode documented in development-evidence-audit.md: manual_error_
#   corrections.csv's "agreement_cd_mtb" column turned out to record a
#   single shared, collaborative pass, not two independent codings, which
#   made Cohen's kappa impossible to compute after the fact. This time, if
#   both worksheets are filled out independently (see USAGE below), kappa
#   is a real, computable statistic -- compute_disambiguation_agreement.R
#   does that once both are back.
#
# v3 -> v4 (2026-09-02, same day): asked to actually mine the project's
#   existing manual annotation files for a smarter rule instead of inventing
#   another one. Joined all 46 candidates against manual_error_corrections.
#   csv and manual_unusual_corrections.csv by (pid, day_num). Result:
#   **20 of the 46 candidates (43%) already have a real, specific, already-
#   applied verdict on file** in manual_error_corrections.csv -- every one
#   of them error_type == "order_error", manually_corrected == TRUE, with an
#   exact correction (e.g. "Minus 12 hours", or a specific replacement
#   time). Zero of the 46 matched manual_unusual_corrections.csv (the
#   "reasonable, leave it alone" file). These 20 don't need a fresh
#   judgment at all -- they already have one, from the project's real
#   collaborative co-review process (not independently double-coded, so
#   still not a kappa-eligible source per development-evidence-audit.md,
#   but a real, considered, already-applied decision, not a guess). v4 pulls
#   them out into disambiguation_already_resolved.csv (see OUTPUT) instead
#   of sending them through fresh review at all -- a validated 43%
#   reduction, bigger than v3's invented 30% and not speculative.
#
#   v3's SINGLE_REVIEW_TIER (recurrence_signal == "recurring_leans_behavior"
#   routed to single-reviewer confirm-or-override) is REMOVED in v4, because
#   checking it against the 20 newly-found real verdicts falsified it: PID
#   6805 (candidate days 7, 11) and PID 11554 (candidate days 11, 12, 13,
#   15) were ALL in the v3 single-review "leans behavior" tier on the
#   strength of n_recurring_similar >= 2 -- and ALL SIX are confirmed
#   order_error in manual_error_corrections.csv, not behavior. Reading the
#   correction notes explains why the recurrence heuristic pointed the
#   wrong way for exactly these participants: "If they get up in the
#   morning, it is very likely they fall asleep at ni[ght before]..." -- a
#   systematic AM/PM decode issue recurs on MULTIPLE days for a participant
#   precisely because it's systematic (their entry habit or the form
#   produces the same ambiguity repeatedly), which looks identical to
#   "recurring real behavior" under a pure count-of-similar-days rule. 6/14
#   (43%) of v3's single-review tier was wrong on the only 14 rows where
#   this was actually checkable against ground truth -- not a marginal
#   miscalibration, a directionally broken assumption. Recurrence count
#   alone cannot distinguish "recurs because it's real" from "recurs
#   because the same decode mistake keeps happening" -- see METHOD below
#   for what n_recurring_similar / recurrence_signal are now used for
#   instead (informational context, not a routing decision).
#
#   Promising direction NOT shipped here, flagged for a careful follow-up
#   rather than rushed in: several of the 20 confirmed order_error
#   corrections are literally "Minus 12 hours" / "Plus 12 hours" -- a clean
#   AM/PM decode signature that could in principle be checked mechanically
#   (does shifting one endpoint by 12h resolve the implausible gap?) for
#   the remaining candidates too. Roughly 12/20 confirmed cases have a
#   clean ±12h correction; the other 8 are "same day HH:MM" or a specific
#   replacement time, which may or may not reduce to the same mechanism --
#   not confirmed either way. Given that v3's last mechanical-looking shortcut
#   didn't survive contact with real data, this needs to be built and
#   validated against these same 20 known-answer rows before it's trusted
#   for the remaining 26 -- not assumed to work and shipped straight to a
#   worksheet.
#
# v4 -> v5 (2026-09-02, same day, asked to push further): "还是少啊" -- 43%
#   wasn't enough, asked to mine the audited corpus at the PER-PARTICIPANT
#   level for more reduction. Two things were actually tried and tested
#   against the full 112-row corpus (75 error + 37 unusual) before touching
#   the remaining 26 needs-review rows -- one worked partially, one was
#   tested and found NOT to apply here (recorded so it isn't re-tried later):
#
#   (a) The ±12h mechanical check flagged above WAS built and validated on
#   the full 112-row corpus: does shifting the implausible field by ±12h
#   land the resulting duration in a plausible range? Recall on the 75
#   confirmed errors: 36/75 (48%). False-positive rate on the 37 confirmed
#   "reasonable, leave alone" rows: 1/37 (2.7%) -- a genuinely good,
#   well-validated rule *in general*. But it is USELESS for the specific 26
#   needs-review rows here: all 26 are gap_sleep_awake candidates with
#   gap_hours in [-6,-3] by construction (that's the locked 3-6h filter),
#   and -6..-3 + 12h always lands in [6,9]h -- a plausible sleep duration by
#   definition, every single time. The check fires on all 26/26 with zero
#   discriminating power, precisely because the candidate list was already
#   pre-filtered into the exact zone where ±12h always "resolves." Not
#   implemented as a filter -- would provide no information. Recorded here
#   so this doesn't get re-proposed without re-deriving this same result.
#
#   (b) Participant history: for each needs-review candidate, does that
#   participant have OTHER already-audited days (real error or behavior
#   verdicts, any day, in either manual file) that could serve as a prior?
#   Leave-one-out test on the full 112-row corpus (does a participant's
#   OTHER audited verdicts predict a given day's verdict when they're
#   unanimous?): predictable for 56/112 rows (the other 56 have no history
#   or mixed/contradictory history), 89.3% accurate (50/56) when a
#   prediction was possible. Real counter-examples exist and matter: PID
#   6805, 3330, and 10638 each have BOTH a confirmed error day and a
#   confirmed behavior day, so a same-participant history rule is wrong for
#   some of their days by construction -- the same lesson as v3's
#   recurrence_signal (a participant can genuinely have both a systematic
#   decode issue AND real unusual-but-genuine days). 12.5% (7/56) prior
#   wrong-when-predictable is too high to auto-resolve on, per the v3
#   lesson -- so this is added as an ADDITIONAL CONTEXT COLUMN
#   (participant_prior_n_error / participant_prior_n_behavior /
#   participant_prior_signal) on the needs-review worksheets, same status as
#   recurrence_signal: informational, not a routing decision. Of the 26
#   needs-review rows, 12 have an error-only participant history (no
#   contradicting behavior verdict for that participant anywhere), 1 has a
#   behavior-only history, 1 has mixed history, 12 have no history at all --
#   see participant_prior_signal per row.
#
#   Net effect: the validated reduction stays at 43% (20/46, from v3->v4).
#   Nothing further was found that clears the bar this project has been
#   holding rules to (checked against real ground truth before being
#   trusted) -- the remaining 26 genuinely look like the residue that needs
#   a human, which is presumably why they're still unresolved in the
#   project's own records.
#
# v5 -> v6 (2026-09-02, same day, pushed further): asked to (a) actually find
#   the AM/PM code mapping instead of leaving it as a blocked idea, and (b)
#   be careful of a real, separate error mechanism this project's notes also
#   document: some rows aren't a bed/sleep AM/PM decode issue at all, but a
#   participant misreading the "awake" question as "when I woke up briefly
#   during the night" (a WASO event) rather than final wake time -- fixed by
#   setting time_awake = time_getup, not by any 12h shift.
#
#   (a) AM/PM code mapping -- SOLVED, and it turns out the project's own
#   pipeline already had it right. timestamp_parse.R (R/timestamp_parse.R,
#   ~line 101) already documents and normalizes the anonymization dialect:
#   "C" -> "AM", "l" -> "PM", verified there against the exact same
#   value counts independently re-derived here (1013 "C", 1847 "l" on
#   time_bed_am_ampm). Independently re-confirmed from scratch in this pass
#   by cross-referencing 210 real (pid, day_num) rows that exist in BOTH
#   sber_ema_anon_20260227.csv (coded) and manual_error_corrections.csv /
#   manual_unusual_corrections.csv (real decoded datetimes, no code) --
#   210/210 (100%) agreed with C=AM, l=PM, zero contradictions. This
#   script now reuses process_timestamp()'s own decoding (the same function
#   already used for gap_hours() above) rather than hand-rolling a second
#   decoder, so it can never disagree with the rest of the pipeline on this.
#
#   (b) WASO-misinterpretation risk -- checked, confirmed real, but shown to
#   be a MINORITY mechanism for this specific field_pair, not something that
#   applies broadly to the 26 needs-review rows. Across all 75 confirmed
#   error rows, corrections split almost evenly: 38 touch the bed/sleep side
#   (AM/PM decode), 37 touch the awake/getup side (of which several are
#   exactly the WASO-misread pattern flagged -- e.g. PID 6985 x7 rows, PID
#   10516 day 12, PID 10599 day 4, PID 8876 x3 -- "problem" notes literally
#   say things like "this person probably put 0:00 because they did not
#   wake up at night" or "awake time is likely WASO time, not final awake").
#   But cross-tabulated against field_pair specifically: of the 13
#   already-resolved candidates whose OWN field_pair is gap_sleep_awake (the
#   same type as all 26 needs-review rows), 12/13 (92%) were actually fixed
#   on the bed/sleep side and only 1/13 on the awake/getup side -- the
#   WASO-misread mechanism is heavily concentrated in gap_awake_getup
#   candidates (6/6 of those, all already resolved), not gap_sleep_awake
#   ones. So the risk is real and worth a per-row caution, but the base rate
#   for THIS specific candidate type favors the AM/PM-decode hypothesis.
#
#   Given the codes are decoded (a), a genuinely NEW check became possible
#   that earlier magnitude/hour-only checks could not do (see v4->v5 (a) --
#   any signal built purely from the SAME 4 flagged clock times is
#   tautologically constant across this whole pre-filtered candidate set,
#   structurally incapable of discriminating). Self-reported SOL
#   (duration_sol_estimate_am_hhmm) is an INDEPENDENT survey item -- not
#   derived from the flagged times -- so it doesn't have that problem.
#   sol_selfreport_min / sol_crosscheck_calc_min / sol_crosscheck_diff_min /
#   sol_crosscheck_fit (added here): try all 4 combinations of shifting bed
#   and/or sleep by +/-12h, compute the resulting bed->sleep SOL for each,
#   and keep whichever combination lands closest to the participant's own
#   self-reported SOL. fit = "good" if that best difference is <=30 minutes,
#   "poor" otherwise, "no_selfreport" if the field is blank that day.
#   VALIDATED on the 13 known gap_sleep_awake already-resolved rows before
#   being trusted on the 26: 11/13 (85%) come back "good" -- the 2
#   exceptions (PID 6805 day 7, PID 11554 day 15) were checked by hand and
#   are genuinely messier real cases (a likely additional day-boundary
#   issue and an outlier self-report respectively), not a sign the check is
#   broken. Applied to the 26 needs-review rows: 22/26 (85%) come back
#   "good" (self-report corroborates a clean +/-12h bed/sleep
#   interpretation), 4/26 "poor" (PID 3539 day 13, PID 6143 day 1, PID 5239
#   day 6, PID 6855 day 9) -- worth EXTRA scrutiny during review, not fewer
#   eyes on them; still context, not a routing decision, same status as
#   recurrence_signal and participant_prior_signal, and NOT auto-resolved
#   on, per the same discipline as everything else in this file. A "poor"
#   fit does not mean "behavior" -- it means the dominant AM/PM-decode
#   hypothesis doesn't cleanly explain this row, which could be behavior,
#   could be the awake/getup-side WASO mechanism from (b) instead, or could
#   just be an unreliable self-report that day.
#
# v6 -> v7 (2026-09-02, same day): asked how the v6 findings could deepen
#   the ORIGINAL Bayesian idea from v1 (dropped there because
#   posterior_p_error collapsed to 3 discrete values with no real
#   discriminating power over n_recurring_similar alone). v6 produced two
#   things v1 never had: an honest BASE RATE, and a validated LIKELIHOOD
#   RATIO -- so this redoes it properly instead of reusing the discredited
#   v1 numbers.
#
#   Base rate: of the 13 already-resolved candidates whose field_pair is
#   gap_sleep_awake (same type as all 26 needs-review rows), 13/13 are
#   confirmed error, 0 confirmed behavior. A Jeffreys Beta(0.5,0.5) posterior
#   on the true behavior-rate of this exact candidate signature gives
#   mean=3.6%, 95% credible interval (0%, 17.3%) -- i.e., BEFORE looking at
#   any row-specific signal, an unlabeled gap_sleep_awake candidate in this
#   3-6h bucket is already ~96% likely to be an error, purely from what this
#   candidate-selection filter has turned out to mean every time it's been
#   checked. Small-n caveat: n=13, so the credible interval is genuinely
#   wide at the low end -- treat 96% as "very likely," not certainty.
#
#   Likelihood ratio for sol_crosscheck_fit: P(fit=good | error) = 11/13
#   (0.846, from the same known cases). P(fit=good | behavior) has NO
#   same-class reference (0 known gap_sleep_awake behavior cases exist) --
#   approximated instead from the 21 manual_unusual_corrections.csv rows
#   with unusual_type in (bed_sleep_suspicious, multiple_suspicious), the
#   closest available real "confirmed behavior, suspicious bed/sleep
#   relationship" class: 4/21 (0.190) come back fit=good. This gives
#   LR(good)=0.846/0.190=4.45, LR(poor)=0.154/0.810=0.19 -- real
#   discriminating power, unlike v1's collapsed signal, though this LR is a
#   cross-class approximation (proxy behavior rows, not the exact same
#   candidate filter) and should be read as directional, not exact.
#
#   Likelihood ratio for participant_prior_signal: computed directly from
#   the full 112-row corpus (not a proxy) via leave-one-out: P(error_only_
#   history | error) = 26/75 (0.347), P(error_only_history | behavior) =
#   3/37 (0.081) -> LR=4.28. Same order of magnitude as the SOL LR.
#
#   posterior_p_error_solonly / posterior_p_error_combined (added here):
#   base-rate prior odds (27.0) updated by the sol_crosscheck LR alone
#   (_solonly), and additionally by the participant_prior LR when
#   participant_prior_signal == "error_only_history" (_combined). On the 26
#   needs-review rows: _solonly ranges 83.7% (poor fit) to 99.2% (good fit);
#   _combined reaches as high as 99.8% for rows with both signals agreeing.
#
#   IMPORTANT CAVEAT, not swept under the rug: _combined multiplies two
#   likelihood ratios assuming they're independent evidence (naive Bayes).
#   They may not be -- a participant with a genuine systematic AM/PM habit
#   could mechanically produce BOTH an error_only_history AND a good
#   sol_crosscheck fit from the same underlying cause, which would make
#   _combined overconfident. _solonly rests on one directly-relevant
#   (if proxy-approximated) LR and is the more defensible number of the two.
#   Both numbers are INFORMATIONAL ONLY here -- same status as every other
#   context column in this file, NOT used to skip or shortcut review for
#   any row. Given the magnitude of these posteriors (mostly >95%), there is
#   a real, honest case for using this to define a lighter-weight review
#   tier (e.g. single-confirm instead of full double-blind) for the
#   highest-confidence rows -- but that is a policy call with the same
#   stakes v3's shortcut had, now with real statistical grounding instead of
#   an unvalidated heuristic. Deliberately left as a decision for the
#   project, not made unilaterally here -- see the discussion delivered
#   alongside this version.
#
# METHOD (decision-support context for the NEEDS_REVIEW tier only --
#   informational, not a verdict; see v3->v4 above for why recurrence stopped
#   being used to route rows)
#   Reuses cross_participant_global_check.R's own approach (median + MAD of
#   a participant's OTHER days) rather than inventing a new one -- see that
#   script's header for the "personal baseline" rationale. For each
#   candidate row still needing review:
#     0. (added v8) time_bed_am_hhmm_ampm / time_getup_am_hhmm_ampm /
#        bed_sleep_diff_h / awake_getup_diff_h / waso_selfreport_min -- the
#        rest of the night, not just the flagged pair. Every candidate's
#        from_time/to_time/gap_hours already show the ONE flagged pair
#        (currently always time_sleep_am -> time_awake_am); these five fill
#        in the other two raw clock times, the other two adjacent-gap diffs,
#        and the self-reported WASO minutes -- the same fields manual_error_
#        corrections.csv and manual_unusual_corrections.csv both carry, so a
#        reviewer sees the whole night the way the original human reviewers
#        did, not just the slice that tripped the candidate filter. Purely
#        descriptive (same `d` lookups sol_crosscheck_for already uses) --
#        no new scoring.
#     1. Pull this participant's gap values for the SAME field_pair on their
#        OTHER valid days (excluding the flagged day itself).
#     2. personal_median_hr / personal_mad_hr from those other days (if >=3
#        are available; NA otherwise -- same floor cross_participant_
#        global_check.R uses before falling back to a personal baseline at
#        all).
#     3. n_recurring_similar: how many of those other days ALSO show a
#        negative gap of similar magnitude (>=2h) for the same pair. NA
#        (not 0) when n_other_valid_days < 3. Present as context ONLY --
#        do NOT read a high count as "leans behavior" (see v3->v4 above).
#     4. personal_deviation_mad: how many personal MADs this candidate's own
#        gap sits from the participant's personal median (their own,
#        excluding this day). NA if no personal baseline; Inf if
#        personal_mad_hr is exactly 0. CAVEAT: WITHIN-PARTICIPANT ranking
#        signal only, not comparable in magnitude across participants (seen
#        on real output: personal_mad_hr as low as 0.03-0.04h for some
#        gap_awake_getup participants, which inflates the ratio without the
#        underlying gap being proportionally more dramatic). Use it to rank
#        a participant's OWN candidate rows against each other, not to
#        compare severity across different participants.
#     5. recurrence_signal: n_recurring_similar restated as a plain label
#        (insufficient_personal_baseline / single_prior_uninformative /
#        isolated_leans_error / recurring_leans_behavior) for legibility.
#        The label names are kept from v3 for continuity but should be read
#        as "how much history exists," not "which way this leans" -- v3->v4
#        above is the reason why.
#     6. participant_prior_n_error / participant_prior_n_behavior /
#        participant_prior_signal (added v4->v5): this participant's OTHER
#        already-audited verdicts (any day, either manual file, excluding
#        this candidate day). signal is one of error_only_history /
#        behavior_only_history / mixed_history / no_history. Validated at
#        89.3% accuracy (50/56) when unanimous, on the full 112-row corpus,
#        via leave-one-out -- see v4->v5 above for the real counter-examples
#        (PID 6805, 3330, 10638) that keep this at context-only, not a
#        routing signal.
#     7. sol_selfreport_min / sol_crosscheck_calc_min /
#        sol_crosscheck_diff_min / sol_crosscheck_fit (added v5->v6): does
#        the participant's own self-reported sleep-onset-latency corroborate
#        a +/-12h AM/PM reinterpretation of bed/sleep? See v5->v6 above for
#        the mechanism, the validation (11/13 known cases, 85%), and why a
#        "poor" fit is a flag for extra scrutiny, not a verdict.
#     8. posterior_p_error_solonly / posterior_p_error_combined (added
#        v6->v7): a real Bayesian posterior -- base-rate prior (from the
#        13/13 known gap_sleep_awake error rate) updated by validated
#        likelihood ratios (sol_crosscheck_fit alone / sol_crosscheck_fit +
#        participant_prior_signal together). See v6->v7 above for the
#        derivation, the LR values, and the naive-independence caveat on
#        _combined. Informational only -- not used to route or skip review.
#
# v7 -> v8 (2026-09-03): asked to build the (still open, still undecided)
#   lighter-review-tier idea flagged in v6->v7 as a real, usable option
#   alongside the existing full double-blind process -- "两版都做出来" (build
#   both versions) -- rather than pick one. Both are now generated on every
#   run; nothing is forced. See TIERED OUTPUT below for what's added and
#   USAGE for how to use either.
#
#   Important caveat to weigh before using the tiered files, found the same
#   day as this addition (recorded in the project worklog in full): the only
#   sample of confirmed BEHAVIOR whose field_pair exactly matches these
#   candidates (gap_sleep_awake) is manual_unusual_corrections.csv's
#   `sleep_awake_suspicious` unusual_type, n=5 -- too small to re-derive
#   LR_SOL_POOR from, but a quick check found 2/5 (40%) of these genuine
#   behavior cases come back sol_crosscheck_fit == "good", well above the
#   19% implied by the proxy class v7's LR_SOL_GOOD/LR_SOL_POOR were derived
#   from. That means "good fit" is weaker evidence for error than v7's
#   numbers suggest -- a real behavior case can plausibly land in the
#   fast-track tier below. The tiered files are provided as a real,
#   available choice, not a validated-safe recommendation; adopting them
#   trades some of this specific risk for less review time, and that
#   trade-off is Cyra/Maia's to make, not this script's.
#
#   Same day, separate ask: the worksheet's column selection was flagged as
#   a real problem, not a nice-to-have -- it only showed from_time/to_time/
#   gap_hours for the ONE flagged field_pair, unlike manual_error_
#   corrections.csv and manual_unusual_corrections.csv, which both show all
#   FOUR raw clock times and all THREE adjacent-gap diffs (plus self-
#   reported SOL/WASO), so the humans who built those two files could see
#   the whole night at a glance. Fixed by adding time_bed_am_hhmm_ampm /
#   time_getup_am_hhmm_ampm / bed_sleep_diff_h / awake_getup_diff_h /
#   waso_selfreport_min (see METHOD item 0 below) -- purely descriptive,
#   reusing `d`'s already-decoded fields, no new scoring. Directly useful
#   for the awake_misread_as_waso mechanism documented the same day in
#   error_catalog.yaml too: a reviewer can now see awake_getup_diff_h and
#   waso_selfreport_min side by side and spot that pattern by eye, which the
#   worksheet gave no way to do before.
#
# v8 fix, same day: while wiring in the raw-context columns above, asked
#   directly whether the WASO string-format bug meant the REAL PRODUCTION
#   pipeline (inst/scripts/process_interval.R) also needed fixing --
#   "是不是管线本身忽略了". Read process_interval.R's duration_totalmin_
#   sol_estimate_am / duration_totalmin_waso_estimate_am handling (~line
#   440-539) end to end: no, the pipeline itself is correct, it parses
#   "H:MM" strings the same way for both fields. But that same reading
#   surfaced a SEPARATE gap: the pipeline applies one more correction this
#   script's parse_hhmm_minutes() did not replicate -- an "H:MM" reading
#   with h in 1..59, m in 0..59, and a naive h*60+m >= 240 minutes is
#   clinically implausible as a duration self-report, so the pipeline
#   reinterprets it as MM:SS (h + m/60) instead of HH:MM (h*60+m). Fixed by
#   adding the same correction to parse_hhmm_minutes() (see its own comment
#   above for the exact rule), which feeds BOTH call sites --
#   sol_crosscheck_for()'s sol_selfreport_min and raw_context_for()'s
#   waso_selfreport_min -- so both get the fix, not just the one that
#   prompted it.
#   Concrete, verified impact: exactly one row across all 26 needs-review
#   candidates was affected -- PID 6143 day 1, whose raw self-reported SOL
#   is literally "11:20". Before the fix: sol_selfreport_min=680,
#   sol_crosscheck_diff_min=70, sol_crosscheck_fit="poor". After: 11.33,
#   18.67, "good" -- posterior_p_error_solonly/_combined moved from 83.7%
#   to 99.2% for this row. This moved the sol_crosscheck_fit split from
#   22 good / 4 poor to 23 good / 3 poor, and the tiered split from
#   22 fast-track / 4 full-review to 23 / 3. Checked all 26 rows for both
#   SOL and WASO self-report values >= 240 min (the threshold that can
#   trigger this correction) -- only this one row qualified; the other
#   three "poor" rows (PID 3539 day 13, PID 5239 day 6, PID 6855 day 9)
#   have small self-reported SOL values (5, 45, 30 min) well under the
#   threshold and are confirmed unaffected (diffed byte-for-byte against
#   the pre-fix output -- only PID 6143 day 1's row changed anywhere in
#   any output file). disambiguation_already_resolved.csv is a direct
#   lookup against real human verdicts, not a computed field, and is
#   correctly unaffected.
#
# SORT ORDER (needs-review worksheets only)
#   Groups surface in order of how little the tool can tell you, on the
#   theory that a human's attention is worth spending where the tool
#   provides the least guidance: insufficient_personal_baseline, then
#   single_prior_uninformative, then isolated_leans_error, then
#   recurring_leans_behavior. Within each group, rows with the largest
#   personal_deviation_mad (the most surprising day, by the participant's
#   own norm) surface first. This is unchanged from v3 and is still fine as
#   an ordering heuristic -- what changed is that recurring_leans_behavior
#   no longer means "skip double review," only "review this last."
#
# OUTPUT
#   disambiguation_already_resolved.csv -- the 20 (as of this run) rows that
#   already have a real verdict in manual_error_corrections.csv. Columns
#   include the original candidate fields plus existing_error_type,
#   existing_column_to_correct, existing_correct_value,
#   existing_problem_humanidentified, existing_agreement_cd_mtb. No fresh
#   judgment needed -- the real next step for these is confirming the
#   correction is actually applied in the current pipeline output, not
#   re-litigating whether it should be, though a spot check is still
#   reasonable given the co-review process wasn't independently coded.
#
#   disambiguation_worksheet_cyra.csv, disambiguation_worksheet_maia.csv --
#   the NEEDS_REVIEW tier (candidates with no existing verdict). Identical
#   content, separate files, each with a blank `judgment` column (fill in
#   exactly one of: error / behavior / unsure) and a blank `notes` column.
#   DO NOT COMPARE these two files with each other until both are filled in
#   independently -- that independence is the entire point. This is the
#   DEFAULT process -- always generated, always safe to use as-is.
#
# TIERED OUTPUT (v7->v8, an ALTERNATIVE process, also always generated --
#   see the caveat in v7->v8 above before choosing this over the default)
#   disambiguation_worksheet_tiered_fasttrack.csv -- the needs-review rows
#   with sol_crosscheck_fit == "good" (validated 85% (11/13) accurate on
#   known cases, but see the v7->v8 caveat: a real behavior case landing
#   here is a real possibility, not a remote one). ONE `judgment` column,
#   ONE `notes` column -- meant for a single reviewer to confirm or
#   override, not full double-blind. Still never auto-resolved -- every row
#   still needs a human judgment entered, just by one reviewer instead of
#   two independently.
#   disambiguation_worksheet_tiered_fullreview_cyra.csv,
#   disambiguation_worksheet_tiered_fullreview_maia.csv -- the remaining
#   needs-review rows (sol_crosscheck_fit != "good": poor / no_selfreport /
#   no_data -- i.e. every row where the tool has the least to offer).
#   Structured exactly like the default worksheets (independent judgment +
#   notes columns each) so compute_disambiguation_agreement.R works
#   unchanged against this pair too.
#   Choosing the tiered process means using disambiguation_worksheet_
#   tiered_fasttrack.csv (single review) plus the two tiered_fullreview
#   files (double-blind) INSTEAD OF disambiguation_worksheet_{cyra,maia}.csv
#   -- not in addition to them, that would just be reviewing everything
#   twice under two different schemes.
#
# USAGE
#   Rscript validation/disambiguate_timegap_candidates.R \
#     [raw_csv] [candidates_csv] [out_dir] [script_dir] [manual_error_csv] [manual_unusual_csv]
#   Defaults: sber_ema_anon_20260227.csv, timegap_candidates_3to6h.csv, ".",
#   "R", manual_error_corrections.csv, manual_unusual_corrections.csv
#   The last two are optional -- if either file is missing, this script
#   warns and proceeds as if there were no matches for it (so it still runs
#   in an environment that doesn't have the real correction files staged),
#   but check the console warning before trusting the resulting split.
#
# PRIVACY: outputs carry real pid/day_num/timestamps, and the already-
# resolved file additionally carries real correction notes. Never commit
# any of these -- same rule as timegap_candidates_3to6h.csv. Only this
# script is meant to be committed.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(rlang)
})

args <- commandArgs(trailingOnly = TRUE)
raw_path      <- if (length(args) >= 1) args[[1]] else "sber_ema_anon_20260227.csv"
cand_path     <- if (length(args) >= 2) args[[2]] else "timegap_candidates_3to6h.csv"
out_dir       <- if (length(args) >= 3) args[[3]] else "."
script_dir    <- if (length(args) >= 4) args[[4]] else "R"
manual_error_path   <- if (length(args) >= 5) args[[5]] else "manual_error_corrections.csv"
manual_unusual_path <- if (length(args) >= 6) args[[6]] else "manual_unusual_corrections.csv"

stopifnot(file.exists(raw_path))
stopifnot(file.exists(cand_path))
source(file.path(script_dir, "timestamp_parse.R"))  # process_timestamp()
source("validation/provenance_helpers.R")

candidates <- read.csv(cand_path, stringsAsFactors = FALSE)
candidates$pid <- as.character(candidates$pid)
candidates$day_num <- as.character(candidates$day_num)
cat(sprintf("Loaded %d candidate rows from %s (%d distinct pid+day_num)\n",
            nrow(candidates), cand_path,
            nrow(unique(candidates[, c("pid", "day_num")]))))

# ── Join against existing real annotation files (v4) ────────────────────────
join_key <- function(df) paste(as.character(df$pid), as.character(df$day_num), sep = "||")
cand_key <- join_key(candidates)

# Some of these files carry a UTF-8 BOM (seen on manual_unusual_corrections.csv;
# manual_error_corrections.csv does not) and some don't -- forcing fileEncoding=
# "UTF-8-BOM" unconditionally silently mis-parsed the non-BOM file (0 matches
# where 20 were expected, caught by actually running this end to end against
# real data, not just a parse check). Strip a BOM by hand if present instead,
# so this works for either case.
read_csv_strip_bom <- function(path) {
  raw_bytes <- readBin(path, "raw", n = 3)
  has_bom <- length(raw_bytes) == 3 && identical(raw_bytes, as.raw(c(0xEF, 0xBB, 0xBF)))
  con <- file(path, encoding = "UTF-8")
  on.exit(close(con))
  if (has_bom) {
    txt <- readLines(con, warn = FALSE)
    txt[1] <- sub("^\xEF\xBB\xBF", "", txt[1], useBytes = TRUE)
    read.csv(text = txt, stringsAsFactors = FALSE)
  } else {
    read.csv(path, stringsAsFactors = FALSE)
  }
}

if (file.exists(manual_error_path)) {
  manual_error <- read_csv_strip_bom(manual_error_path)
  manual_error$pid <- as.character(manual_error$pid)
  manual_error$day_num <- as.character(manual_error$day_num)
  err_key <- join_key(manual_error)
  err_match_idx <- match(cand_key, err_key)
} else {
  cat(sprintf("WARNING: %s not found -- proceeding as if no candidates have an existing error-file verdict. Do not trust the already-resolved split until this is fixed.\n", manual_error_path))
  err_match_idx <- rep(NA_integer_, length(cand_key))
}

if (file.exists(manual_unusual_path)) {
  manual_unusual <- read_csv_strip_bom(manual_unusual_path)
  manual_unusual$pid <- as.character(manual_unusual$pid)
  manual_unusual$day_num <- as.character(manual_unusual$day_num)
  unusual_key <- join_key(manual_unusual)
  unusual_match_idx <- match(cand_key, unusual_key)
} else {
  cat(sprintf("WARNING: %s not found -- proceeding as if no candidates have an existing unusual-file verdict.\n", manual_unusual_path))
  unusual_match_idx <- rep(NA_integer_, length(cand_key))
}

has_error_match   <- !is.na(err_match_idx)
has_unusual_match <- !is.na(unusual_match_idx)
if (any(has_error_match & has_unusual_match)) {
  overlap_n <- sum(has_error_match & has_unusual_match)
  cat(sprintf("WARNING: %d candidate(s) matched BOTH manual_error_corrections.csv and manual_unusual_corrections.csv -- conflicting existing verdicts, treating as error-file match but this needs a human look.\n", overlap_n))
}

candidates$existing_verdict <- ifelse(has_error_match, "error",
                                ifelse(has_unusual_match, "behavior", NA_character_))
candidates$existing_error_type              <- NA_character_
candidates$existing_column_to_correct       <- NA_character_
candidates$existing_correct_value           <- NA_character_
candidates$existing_problem_humanidentified <- NA_character_
candidates$existing_agreement               <- NA_character_
if (any(has_error_match)) {
  m <- err_match_idx[has_error_match]
  candidates$existing_error_type[has_error_match]              <- manual_error$error_type[m]
  candidates$existing_column_to_correct[has_error_match]       <- manual_error$column_to_correct[m]
  candidates$existing_correct_value[has_error_match]           <- manual_error$correct_value[m]
  candidates$existing_problem_humanidentified[has_error_match] <- manual_error$problem_humanidentified[m]
  candidates$existing_agreement[has_error_match]                <- manual_error$agreement_cd_mtb[m]
}
if (any(has_unusual_match)) {
  m <- unusual_match_idx[has_unusual_match]
  candidates$existing_problem_humanidentified[has_unusual_match] <- manual_unusual$problem_humanidentified[m]
  candidates$existing_agreement[has_unusual_match]                <- manual_unusual$cd_mtb_Consenssus[m]
}

# ── Per-participant audited history (v4 -> v5), for context only -- see
#    v4->v5 in the header for the leave-one-out validation and its limits.
participant_history <- data.frame(pid = character(), day_num = character(),
                                   verdict = character(), stringsAsFactors = FALSE)
if (exists("manual_error")) {
  participant_history <- rbind(participant_history, data.frame(
    pid = manual_error$pid, day_num = manual_error$day_num,
    verdict = "error", stringsAsFactors = FALSE))
}
if (exists("manual_unusual")) {
  participant_history <- rbind(participant_history, data.frame(
    pid = manual_unusual$pid, day_num = manual_unusual$day_num,
    verdict = "behavior", stringsAsFactors = FALSE))
}

participant_prior_for <- function(own_pid, own_day) {
  if (nrow(participant_history) == 0) {
    return(data.frame(participant_prior_n_error = 0L, participant_prior_n_behavior = 0L,
                       participant_prior_signal = "no_history", stringsAsFactors = FALSE))
  }
  other <- participant_history[participant_history$pid == own_pid &
                                  participant_history$day_num != own_day, ]
  n_err <- sum(other$verdict == "error")
  n_beh <- sum(other$verdict == "behavior")
  signal <- if (n_err == 0 && n_beh == 0) {
    "no_history"
  } else if (n_err > 0 && n_beh == 0) {
    "error_only_history"
  } else if (n_beh > 0 && n_err == 0) {
    "behavior_only_history"
  } else {
    "mixed_history"
  }
  data.frame(participant_prior_n_error = n_err, participant_prior_n_behavior = n_beh,
             participant_prior_signal = signal, stringsAsFactors = FALSE)
}

already_resolved <- candidates[!is.na(candidates$existing_verdict), ]
needs_review      <- candidates[is.na(candidates$existing_verdict), ]
needs_review <- needs_review[, setdiff(names(needs_review),
  c("existing_verdict", "existing_error_type", "existing_column_to_correct",
    "existing_correct_value", "existing_problem_humanidentified", "existing_agreement"))]

# ── Decode ALL rows (not just candidates) so each participant's full history
#    is available for the personal-baseline computation ─────────────────────
raw <- read.csv(raw_path, stringsAsFactors = FALSE, check.names = FALSE)
raw$raw_row_id <- seq_len(nrow(raw))
raw$pid <- as.character(raw$pid)
raw$day_num <- as.character(raw$day_num)

vars <- c("time_bed_am", "time_sleep_am", "time_awake_am", "time_getup_am")
d <- raw
for (v in vars) d <- process_timestamp(d, v, "timestamp")

gap_hours <- function(df, from_var, to_var) {
  t1 <- df[[paste0(from_var, "_hhmm_ampm")]]
  t2 <- df[[paste0(to_var, "_hhmm_ampm")]]
  as.numeric(difftime(t2, t1, units = "hours"))
}
d$gap_bed_sleep   <- gap_hours(d, "time_bed_am",   "time_sleep_am")
d$gap_sleep_awake <- gap_hours(d, "time_sleep_am", "time_awake_am")
d$gap_awake_getup <- gap_hours(d, "time_awake_am", "time_getup_am")

recurrence_label <- function(n_other, n_recurring) {
  if (n_other < 3 || is.na(n_recurring)) return("insufficient_personal_baseline")
  if (n_recurring == 0) return("isolated_leans_error")
  if (n_recurring == 1) return("single_prior_uninformative")
  return("recurring_leans_behavior")
}

# ── Self-reported-SOL cross-check (v5 -> v6) ─────────────────────────────────
# Reuses process_timestamp()'s own AM/PM decode (d$time_bed_am_hhmm_ampm /
# d$time_sleep_am_hhmm_ampm, already computed above for gap_hours()) rather
# than a second hand-rolled decoder -- see v5->v6 in the header for why, and
# for the validation numbers. duration_sol_estimate_am_hhmm is a self-reported
# DURATION field (not a clock time), so it needs no AM/PM handling, just
# hh:mm -> minutes, with the same "00:xx means literal 00:xx" rule as the
# clock fields (a 12h reading of "00" would otherwise misparse as noon).
parse_hhmm_minutes <- function(hhmm_str) {
  if (is.na(hhmm_str) || hhmm_str == "" || hhmm_str == "NA") return(NA_real_)
  parts <- strsplit(as.character(hhmm_str), ":")[[1]]
  if (length(parts) != 2) return(NA_real_)
  h <- suppressWarnings(as.numeric(parts[1]))
  m <- suppressWarnings(as.numeric(parts[2]))
  if (is.na(h) || is.na(m)) return(NA_real_)
  raw <- h * 60 + m
  # MM:SS-confusion correction (v8, 2026-09-03), replicated from the REAL
  # production pipeline (inst/scripts/process_interval.R, ~line 492, the
  # duration_totalmin_sol_estimate_am / duration_totalmin_waso_estimate_am
  # branch). Asked directly whether the pipeline itself ignores this: it does
  # not -- confirmed by reading process_interval.R, which parses H:MM
  # correctly for both fields. But it goes further: an "H:MM" reading with
  # h in 1..59, m in 0..59, and a naive h*60+m >= 240 minutes is clinically
  # implausible as a duration self-report (e.g. "11:20" read as 11h20m of
  # sleep-onset latency), so the pipeline reinterprets it as MM:SS instead --
  # h + m/60, not h*60+m. This script's own parser did not replicate that
  # correction, so it could silently disagree with what the real pipeline
  # computes from the same raw value. Confirmed real-world impact: PID 6143
  # day 1's raw self-reported SOL is literally "11:20" -- naive parse gives
  # 680 min (this script, before this fix), pipeline logic gives ~11.33 min.
  if (h > 0 && h <= 59 && m >= 0 && m < 60 && raw >= 240) {
    return(h + m / 60)
  }
  raw
}

sol_crosscheck_for <- function(own_pid, own_day) {
  er <- d[d$pid == own_pid & d$day_num == own_day &
            !is.na(d$time_bed_am_hhmm_ampm) & !is.na(d$time_sleep_am_hhmm_ampm), ]
  if (nrow(er) == 0) {
    return(data.frame(sol_selfreport_min = NA_real_, sol_crosscheck_calc_min = NA_real_,
                       sol_crosscheck_diff_min = NA_real_, sol_crosscheck_fit = "no_data",
                       stringsAsFactors = FALSE))
  }
  er <- er[1, ]
  bed_min   <- lubridate::hour(er$time_bed_am_hhmm_ampm)   * 60 + lubridate::minute(er$time_bed_am_hhmm_ampm)
  sleep_min <- lubridate::hour(er$time_sleep_am_hhmm_ampm) * 60 + lubridate::minute(er$time_sleep_am_hhmm_ampm)
  sol_rep <- parse_hhmm_minutes(er$duration_sol_estimate_am_hhmm)

  # Try all 4 combinations of a +/-12h reinterpretation on bed and/or sleep;
  # keep whichever lands the resulting SOL closest to the self-report. With
  # no self-report to check against, fall back to the as-recorded (no-shift)
  # reading so the column is never silently empty.
  shifts <- c(0, -720)
  best_diff <- NA_real_; best_calc <- NA_real_
  for (db in shifts) for (ds in shifts) {
    b <- (bed_min + db) %% 1440
    s <- (sleep_min + ds) %% 1440
    calc <- (s - b) %% 1440
    if (!is.na(sol_rep)) {
      diff <- abs(calc - sol_rep)
      if (is.na(best_diff) || diff < best_diff) { best_diff <- diff; best_calc <- calc }
    } else if (db == 0 && ds == 0) {
      best_calc <- calc
    }
  }
  fit <- if (is.na(sol_rep)) "no_selfreport" else if (best_diff <= 30) "good" else "poor"
  data.frame(sol_selfreport_min = sol_rep, sol_crosscheck_calc_min = best_calc,
             sol_crosscheck_diff_min = best_diff, sol_crosscheck_fit = fit,
             stringsAsFactors = FALSE)
}

# ── Bayesian posterior (v6 -> v7) ────────────────────────────────────────────
# Constants derived and validated against the real corpus -- see v6->v7 in
# the header for the full derivation. Not re-derived at runtime (the manual
# correction files may be absent in some environments per the file.exists()
# guards above); hard-coded from the analysis performed alongside this
# version, dated 2026-09-02.
BASE_RATE_PRIOR_ODDS   <- 27.0   # gap_sleep_awake candidates: 13/13 known = error (Jeffreys)
LR_SOL_GOOD            <- 4.45   # P(fit=good|error)=11/13 vs P(fit=good|behavior proxy)=4/21
LR_SOL_POOR            <- 0.19   # complement of the above
LR_PARTICIPANT_PRIOR_ERROR_ONLY <- 4.28  # P(error_only_history|error)=26/75 vs |behavior)=3/37

posterior_p_error <- function(sol_fit, participant_signal) {
  sol_lr <- if (identical(sol_fit, "good")) LR_SOL_GOOD
            else if (identical(sol_fit, "poor")) LR_SOL_POOR
            else 1.0  # no_selfreport / no_data -- no update
  odds_solonly <- BASE_RATE_PRIOR_ODDS * sol_lr
  prior_lr <- if (identical(participant_signal, "error_only_history")) LR_PARTICIPANT_PRIOR_ERROR_ONLY else 1.0
  odds_combined <- odds_solonly * prior_lr
  data.frame(
    posterior_p_error_solonly  = round(100 * odds_solonly  / (1 + odds_solonly),  1),
    posterior_p_error_combined = round(100 * odds_combined / (1 + odds_combined), 1),
    stringsAsFactors = FALSE
  )
}

# ── Full-night raw context (v8, 2026-09-03) ──────────────────────────────────
# Asked directly: the worksheet only showed from_time/to_time/gap_hours for
# the ONE flagged field_pair, unlike manual_error_corrections.csv and
# manual_unusual_corrections.csv, which both show all FOUR raw timestamps and
# all THREE adjacent-gap diffs plus self-reported SOL/WASO, so the original
# human reviewers could see the whole night at a glance -- not just the one
# pair that got flagged. This closes that gap: adds the same raw fields those
# two sheets carry, so a reviewer can eyeball-compare the same way. Purely
# descriptive lookups against `d` (already decoded above) -- no new scoring,
# no new judgment logic.
raw_context_for <- function(own_pid, own_day) {
  er <- d[d$pid == own_pid & d$day_num == own_day, ]
  if (nrow(er) == 0) {
    return(data.frame(
      time_bed_am_hhmm_ampm = NA_character_, time_getup_am_hhmm_ampm = NA_character_,
      bed_sleep_diff_h = NA_real_, awake_getup_diff_h = NA_real_,
      waso_selfreport_min = NA_real_, stringsAsFactors = FALSE))
  }
  er <- er[1, ]
  # duration_totalmin_waso_estimate_am's NAME says "totalmin" but the raw
  # values are actually "H:MM" strings (e.g. "1:00", "0:05"), same shape as
  # duration_sol_estimate_am_hhmm -- confirmed by inspection (1,730/13,990
  # non-missing raw values, all colon-formatted, never a bare number). Reuses
  # the same parse_hhmm_minutes() already defined above for SOL, not a
  # second hand-rolled parser.
  data.frame(
    time_bed_am_hhmm_ampm   = format(er$time_bed_am_hhmm_ampm,   "%Y-%m-%d %H:%M"),
    time_getup_am_hhmm_ampm = format(er$time_getup_am_hhmm_ampm, "%Y-%m-%d %H:%M"),
    bed_sleep_diff_h    = round(er$gap_bed_sleep, 3),
    awake_getup_diff_h  = round(er$gap_awake_getup, 3),
    waso_selfreport_min = parse_hhmm_minutes(er$duration_totalmin_waso_estimate_am),
    stringsAsFactors = FALSE
  )
}

# ── Per-candidate context (needs_review only) ────────────────────────────────
score_one <- function(row) {
  gap_col <- row$field_pair
  own_pid <- row$pid
  own_day <- row$day_num
  own_gap <- row$gap_hours

  other_days <- d %>%
    filter(pid == own_pid, day_num != own_day, !is.na(.data[[gap_col]]))

  n_other <- nrow(other_days)
  personal_median <- if (n_other >= 3) median(other_days[[gap_col]]) else NA_real_
  personal_mad    <- if (n_other >= 3) mad(other_days[[gap_col]])    else NA_real_

  n_recurring_raw <- sum(other_days[[gap_col]] < 0 & abs(other_days[[gap_col]]) >= 2, na.rm = TRUE)
  n_recurring <- if (n_other >= 3) n_recurring_raw else NA_integer_

  deviation_mad <- if (is.na(personal_mad)) {
    NA_real_
  } else if (personal_mad == 0) {
    Inf
  } else {
    round(abs(own_gap - personal_median) / personal_mad, 2)
  }

  prior <- participant_prior_for(own_pid, own_day)
  sol_check <- sol_crosscheck_for(own_pid, own_day)
  raw_ctx <- raw_context_for(own_pid, own_day)
  posterior <- posterior_p_error(sol_check$sol_crosscheck_fit, prior$participant_prior_signal)

  data.frame(
    # Full-night raw context (v8) -- matches manual_error_corrections.csv /
    # manual_unusual_corrections.csv's layout so this is eyeball-comparable
    # the same way. from_time/to_time/gap_hours (already in needs_review,
    # to the left of these columns) are the ONE flagged pair
    # (time_sleep_am/time_awake_am for every current candidate); these fill
    # in the other two clock times and the other two diffs.
    time_bed_am_hhmm_ampm   = raw_ctx$time_bed_am_hhmm_ampm,
    time_getup_am_hhmm_ampm = raw_ctx$time_getup_am_hhmm_ampm,
    bed_sleep_diff_h    = raw_ctx$bed_sleep_diff_h,
    awake_getup_diff_h  = raw_ctx$awake_getup_diff_h,
    waso_selfreport_min = raw_ctx$waso_selfreport_min,
    n_other_valid_days     = n_other,
    personal_median_hr     = round(personal_median, 2),
    personal_mad_hr        = round(personal_mad, 2),
    n_recurring_similar    = n_recurring,
    personal_deviation_mad = deviation_mad,
    recurrence_signal      = recurrence_label(n_other, n_recurring),
    participant_prior_n_error    = prior$participant_prior_n_error,
    participant_prior_n_behavior = prior$participant_prior_n_behavior,
    participant_prior_signal     = prior$participant_prior_signal,
    sol_selfreport_min       = sol_check$sol_selfreport_min,
    sol_crosscheck_calc_min  = sol_check$sol_crosscheck_calc_min,
    sol_crosscheck_diff_min  = sol_check$sol_crosscheck_diff_min,
    sol_crosscheck_fit       = sol_check$sol_crosscheck_fit,
    posterior_p_error_solonly  = posterior$posterior_p_error_solonly,
    posterior_p_error_combined = posterior$posterior_p_error_combined,
    stringsAsFactors = FALSE
  )
}

if (nrow(needs_review) > 0) {
  context <- do.call(rbind, lapply(seq_len(nrow(needs_review)), function(i) score_one(needs_review[i, ])))
  worksheet <- cbind(needs_review, context)

  # See SORT ORDER in the header comment above.
  signal_priority <- c(
    insufficient_personal_baseline = 1L,
    single_prior_uninformative     = 2L,
    isolated_leans_error           = 3L,
    recurring_leans_behavior       = 4L
  )
  worksheet$.sig_rank <- signal_priority[worksheet$recurrence_signal]
  worksheet <- worksheet %>%
    arrange(.sig_rank, desc(personal_deviation_mad)) %>%
    select(-.sig_rank)
} else {
  worksheet <- needs_review
}

worksheet$judgment <- ""   # fill in: error / behavior / unsure
worksheet$notes <- ""

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
write.csv(already_resolved, file.path(out_dir, "disambiguation_already_resolved.csv"), row.names = FALSE)
write.csv(worksheet, file.path(out_dir, "disambiguation_worksheet_cyra.csv"), row.names = FALSE)
write.csv(worksheet, file.path(out_dir, "disambiguation_worksheet_maia.csv"), row.names = FALSE)

# ── Tiered alternative process (v7 -> v8) -- generated alongside the default
#    above, not instead of it. See v7->v8 in the header for why this exists
#    and the caveat to weigh before using it, and TIERED OUTPUT for the file
#    layout. Purely a re-split of `worksheet` by sol_crosscheck_fit -- no new
#    scoring, no row is dropped or auto-resolved.
if (nrow(worksheet) > 0) {
  fasttrack_rows  <- worksheet[worksheet$sol_crosscheck_fit == "good", , drop = FALSE]
  fullreview_rows <- worksheet[worksheet$sol_crosscheck_fit != "good", , drop = FALSE]
} else {
  fasttrack_rows  <- worksheet
  fullreview_rows <- worksheet
}
write_csv_with_provenance(
  fasttrack_rows, file.path(out_dir, "disambiguation_worksheet_tiered_fasttrack.csv"),
  script_path = "validation/disambiguate_timegap_candidates.R",
  inputs = c(cand_path, raw_path, manual_error_path, manual_unusual_path),
  notes = "needs-review rows with sol_crosscheck_fit == 'good' (single-reviewer fast-track tier, v7->v8)."
)
write.csv(fullreview_rows, file.path(out_dir, "disambiguation_worksheet_tiered_fullreview_cyra.csv"), row.names = FALSE)
write.csv(fullreview_rows, file.path(out_dir, "disambiguation_worksheet_tiered_fullreview_maia.csv"), row.names = FALSE)

cat(sprintf("\nAlready resolved (existing verdict on file, no fresh review needed): %d/%d (%.0f%%) -- see disambiguation_already_resolved.csv\n",
            nrow(already_resolved), nrow(candidates), 100 * nrow(already_resolved) / nrow(candidates)))
if (nrow(already_resolved) > 0) print(table(already_resolved$existing_verdict))
cat(sprintf("\nNeeds fresh review: %d/%d (%.0f%%) -- written to %s/ (disambiguation_worksheet_{cyra,maia}.csv)\n",
            nrow(worksheet), nrow(candidates), 100 * nrow(worksheet) / nrow(candidates), out_dir))
cat("Fill in `judgment` (error / behavior / unsure) and optional `notes` in EACH file\n")
cat("independently -- do not compare until both are done. Then run\n")
cat("compute_disambiguation_agreement.R on the two completed files.\n\n")
if (nrow(worksheet) > 0) {
  cat("recurrence_signal breakdown (needs-review rows -- context only, NOT a routing signal; see v3->v4):\n")
  print(table(worksheet$recurrence_signal))
  cat("\nparticipant_prior_signal breakdown (needs-review rows -- context only, NOT a routing\n")
  cat("signal; 89.3% accurate when unanimous on the full corpus but with real exceptions -- see v4->v5):\n")
  print(table(worksheet$participant_prior_signal))
  cat("\nsol_crosscheck_fit breakdown (needs-review rows -- context only, NOT a routing signal;\n")
  cat("validated 85% (11/13) on known gap_sleep_awake cases -- see v5->v6. 'poor' means EXTRA\n")
  cat("scrutiny, not 'behavior' -- could be the awake/getup-side WASO mechanism instead):\n")
  print(table(worksheet$sol_crosscheck_fit))
  cat("\nposterior_p_error_solonly / _combined summary (informational Bayesian posterior, NOT\n")
  cat("used to route or skip review -- see v6->v7 for derivation and the naive-independence\n")
  cat("caveat on _combined):\n")
  cat(sprintf("  solonly:  min=%.1f%%  median=%.1f%%  max=%.1f%%\n",
              min(worksheet$posterior_p_error_solonly), median(worksheet$posterior_p_error_solonly),
              max(worksheet$posterior_p_error_solonly)))
  cat(sprintf("  combined: min=%.1f%%  median=%.1f%%  max=%.1f%%\n",
              min(worksheet$posterior_p_error_combined), median(worksheet$posterior_p_error_combined),
              max(worksheet$posterior_p_error_combined)))
  cat(sprintf("\nTIERED ALTERNATIVE (v7->v8, optional -- see caveat in header before using):\n"))
  cat(sprintf("  fast-track (sol_crosscheck_fit == good, single-reviewer): %d rows -- disambiguation_worksheet_tiered_fasttrack.csv\n",
              nrow(fasttrack_rows)))
  cat(sprintf("  full review (everything else, double-blind):              %d rows -- disambiguation_worksheet_tiered_fullreview_{cyra,maia}.csv\n",
              nrow(fullreview_rows)))
  cat("  Use EITHER the default {cyra,maia} pair OR this tiered set -- not both.\n")
}
