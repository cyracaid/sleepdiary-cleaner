# Methods: Data Cleaning — Sleep Paper (Maia's text, updated with 2026-08 numbers)

## Original structure (Maia's May version, lines 1-6)

The dataset comprised 2,860 morning sleep diary records from 237 participants, including self-reported sleep onset latency (SOL), wake after sleep onset (WASO), time in bed, sleep time, final awakening time, and time they got out of bed entered as free text responses. To ensure data validity, we implemented a structured, auditable correction pipeline addressing timestamp formatting, internal consistency, and derived sleep metrics. This pipeline involved four stages:

**Timestamp Standardization and Interval Processing.** All text-entered timestamps and time duration (SOL, WASO) were reformatted into a uniform time format with checking to prevent silent coercion errors. AM/PM mis-entries inconsistencies were corrected with conditional logic and 12-hour adjustments, with special handling of near-midnight entries (bedtime, sleep time), where mistakes were frequent. Duration variables (SOL, WASO) were processed using a custom hierarchical decision-tree function that (1) excluded invalid strings, (2) standardized incorrect timestamp formats (e.g., insertion or relocation of colon relative to hours minutes), and (3) converted corrected timestamps into total minutes for duration responses (SOL, WASO). At each step, we documented numeric output, correction history, and manual-review flags for human auditing of corrections.

**Processing and Correction of Timestamp Sequence.** Since participants occasionally entered timestamps in the incorrect order (e.g., swapping time in bed and sleep time), chronological sequence across time in bed, sleep time, final awakening time, and time out of bed was enforced using a two-step algorithm operating on complete cases only. Step 1 resolved cross-day and AM/PM misclassifications by iteratively subtracting 12 hours when adjacent intervals exceeded 12 hours. Step 2 corrected minor inversions (<3 hours), suggestive of accidentally entering timestamps in the wrong order, by swapping adjacent timestamps. Identical timestamps (e.g., time in bed = sleep time) were not considered errors. All automated corrections were again labeled with indicators of correction type to ensure traceability for human auditing. If, after those correction steps were complete, at least one of the following errors existed, the entry was flagged for manual review: a) timestamp sequence errors; b) calculated difference between time in bed and time asleep was >7 hours (i.e., an average sleep duration is unlikely for SOL); c) calculated difference between time of final awakening and time out of bed was >7 hours; and d) duration of sleep calculated based on timestamps was >24 hours. Clinically plausible but statistically atypical records were also marked for human review if at least one of the following conditions were met: a) duration of sleep calculated based on timestamps was <3 or >15 hours; b) calculated SOL was >3 hours; c) calculated duration in bed after final awakening >3 hours.

**Human Manual Correction.** Two members of the research team independently reviewed all flagged errors (n = 75) as well as statistically atypical cases (n = 37) by comparing values against all original sleep diary responses by that participant in order to understand a given sleep period in context of the rest of the study. For flagged errors, the two reviewers reached the same judgment immediately on 48 of 75 records (64.0%) and resolved the remaining 27 (36.0%) by discussion to consensus; for atypical cases the corresponding figures were 33 of 37 (89.2%) and 4 (10.8%). Because both reviewers were members of the research team with access to the pipeline output, these figures describe co-review agreement during development and are not an independent blinded reliability estimate.

**Manual Correction Processing System.** The human manual corrections were reincorporated into a final dataset using a partially automated script to correct values using labels and natural-language processing, with checks to ensure reversibility and post-correction validation to flag discrepancies (>6 minutes) between derived intervals and reported durations.

Where a self-reported duration and the timestamp-derived interval disagreed but both values were individually plausible, the record was flagged rather than adjusted. Because this study concerns the association between sleep and same-day affect, between- and within-person variability in reported sleep timing is the signal of interest, and normalizing such disagreements toward internal consistency would risk removing it. Only records confirmed to contain a data-entry error were corrected.

Final calculations of duration-based sleep metrics were derived only after full correction.

---

## Changes from May version (for tracking)

| Item | May | Now | Reason |
|------|-----|-----|--------|
| Participants | ~10,000 | 237 | Exact count from export |
| Records | XXX | 2,860 | Morning diaries only (not full 13,990 export) |
| Flagged errors | n = 47 | n = 75 | Actual count from review files |
| Atypical cases | n = 37 | n = 37 | Unchanged |
| Human agreement | (X%) | 64.0% flagged / 89.2% atypical | Counted from review files |
| Stages | three | four | Standardization, Sequence, Human, Processing |
| Reviewer role | "independent human coders" | "members of the research team" | More accurate language |

