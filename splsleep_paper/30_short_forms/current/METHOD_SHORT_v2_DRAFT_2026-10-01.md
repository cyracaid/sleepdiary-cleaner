# Methods (short-form, sleep-research journal), revision DRAFT 2026-10-01

Not applied to `validation/METHOD_SECTION_SHORT_sleep_journal.md`. Changes from the 2026-09-07 draft:

1. **Reviewer wording corrected.** The old text said the two reviewers "independently reviewed"
   the records. `VALIDATION_REPORT.md` says the review was collaborative, one shared worksheet,
   and reports agreement, not kappa. The text now matches the report.
2. **1,048 (7.5%) is attributed to the v1.4.5 audit.** It is a stage-specific count; the
   current review queue printed at the end of a run is smaller (226 open rows in the study run
   with manual corrections, 307 without).
3. **Added** the audit-trail sentence (resolution, date, reviewer per manual decision).
4. **Added** the external-dataset paragraph (KAIST, Manchester) with its limits.
5. Everything else (benchmark numbers, the SOL/WASO patch, the redundant-channel check) is
   unchanged because `VALIDATION_REPORT.md` still carries the same numbers.

**Still to verify before use:** the 88 vs 85 figures refer to different stages (88 corrections
in the redundant-channel step; 85 in the final dataset). If the journal asks for one number,
say which stage. Word count is about 640; the sleep/awake-swap paragraph is the first to cut.

---

Sleep diary data (N = 13,990 diary-days) were cleaned using **sleepcleanr**, an R-based pipeline
that combines automated timestamp/duration parsing with human-in-the-loop review for ambiguous
records. Rather than auto-correcting every irregularity, the pipeline is deliberately
conservative: high-confidence, format- or order-level errors (e.g., AM/PM entry errors,
adjacent-field transpositions) are corrected automatically, while errors that require judging
whether an unusual value is a data-entry mistake or a genuine (if extreme) sleep pattern are
routed to human review rather than silently altered. Every correction is logged against the
original entry, so raw and corrected values remain independently inspectable.

Detection and correction accuracy were evaluated with a synthetic benchmark (11 error
categories, 400 injected cases per category, plus a 10,000-record clean-input control) and,
independently, on the real study data via a redundant-measurement check (below). On the clean
control, the pipeline altered 0/10,000 records (95% upper bound 0.03%), confirming it does not
introduce spurious corrections. Detection/correction performance on injected errors was
category-dependent: near-perfect for format and adjacent-timestamp errors (100% correctly
resolved), and for AM/PM entry errors (100% either auto-corrected or flagged, 0% resolved
incorrectly). One category is worth reporting in detail because it illustrates a general risk
in duration-field parsing: when a participant enters a clock time (e.g., "11:30") into a
minutes field intended for sleep-onset latency (SOL) or wake-after-sleep-onset (WASO), an
earlier version of the pipeline would silently reinterpret it as a plausible-looking duration
value with no warning (95.8% of SOL and 96.0% of WASO test cases). A targeted patch closed this:
in the current pipeline, 0% of these cases are silently mis-corrected; instead, 98.2% (SOL) and
96.8% (WASO) are routed to human review and 1.8%/3.2% are auto-corrected to the verified true
value. We flag this pattern for other diary-cleaning pipelines that parse free-text or
mixed-format duration fields: a plausibility check on the *raw* entry is not sufficient if the
*parsed* value is not separately checked for plausibility.

On the real study dataset, sleep-onset latency computed from raw timestamps
(`time_sleep − time_bed`) was compared against independently self-reported SOL, before and
after the pipeline's timestamp-correction step, for the 88 records that step corrected. Because
this correction step never reads the self-reported duration fields, the comparison is not
circular. Agreement between the two measures improved sharply after correction (median absolute
discrepancy: 120 → 8.5 minutes; 81/88 records improved, 92.0% [95% CI 84.3–96.7%], Wilcoxon
p = 1.3 × 10⁻¹²), which is within the typical self-report measurement noise band (~13 min
median on uncorrected records). One correction rule (resolving same-day sleep/awake-time
ambiguity, applied to only 10 of the 88 records) showed the opposite pattern (7/10 records
moved further from self-report) and is reported here as a limitation rather than omitted;
6 of the 7 affected records are independently caught by a downstream consistency check before
reaching the final dataset, leaving one record with an unflagged residual discrepancy.

Two research-team members co-reviewed all records flagged for manual review during pipeline
development (n = 75) on a shared worksheet; because the review was collaborative rather than
independent, we report immediate agreement (64.0%), not a chance-corrected statistic, with the
remainder resolved by discussion to full consensus. Each manual decision is stored with its
resolution status, date and reviewer, so the review trail can be re-read and re-applied. In the
v1.4.5 audit of the complete study dataset, 1,048/13,990 records (7.5%) were routed to human
review; 0 value-level corrections were applied without a corresponding audit-trail entry.

Beyond the study data, the pipeline was run end to end, with no threshold changed, on two public
diary datasets not used in development (KAIST: 49 adults, 1,372 diary entries; Manchester: 59
adults, 478 entries) after converting each to the expected layout. Both runs completed and gave
plausible mean total sleep times (7.55 h and 7.63 h). These are feasibility checks only: neither
dataset contains known diary errors or typed clock times, so neither tests error detection, and
the pipeline's detection accuracy rests on the synthetic benchmark and the study data above.
