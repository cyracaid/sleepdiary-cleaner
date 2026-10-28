# Data-cleaning Methods subsection — sleep paper (update of the May/MtB version)

**What this is.** A refreshed version of the condensed Methods text Maia edited in
May (`methods_sources/v5_methodology_cyra_mtb-edits.docx`, first section). Same
length, same five-stage prose structure, same level of detail — that was the
agreed level and it has not been raised. **The May file is untouched**; this is a
separate document.

**Why a refresh.** Four things changed since May: the participant/record counts
were wrong, the human-review counts grew, the agreement rate placeholder can now
be filled, and the pipeline has been formally validated. Changes are listed at the
bottom so you can see exactly what moved.

---

## Draft text (≈640 words)

Morning sleep diaries were collected as one component of a larger ecological
momentary assessment (EMA) protocol. Of the 13,990 EMA submissions in the export,
2,860 were morning sleep diaries: one per participant per study day, from 237
participants over up to 15 days (median 13 diary days per participant; 86.5% of
all possible participant-days). Each diary recorded self-reported sleep onset
latency (SOL), wake after sleep onset (WASO), time in bed, sleep time, final
awakening time, and time out of bed, all entered as free-text responses. To ensure data validity, we implemented a
structured, auditable correction pipeline addressing timestamp formatting,
internal consistency, and derived sleep metrics. The pipeline involved four
stages, and every automated action was recorded so that any correction can be
traced back to the rule or the person that produced it.

**Timestamp standardization and interval processing.** All text-entered timestamps
and duration responses (SOL, WASO) were reformatted into a uniform time
representation with checks to prevent silent coercion errors. AM/PM mis-entries
were corrected with conditional logic and 12-hour adjustments, with special
handling of near-midnight entries (bedtime, sleep time), where mistakes were
frequent. Duration variables were processed using a hierarchical decision-tree
function that (1) excluded invalid strings, (2) standardized malformed timestamp
formats (e.g., insertion or relocation of a colon relative to hours and minutes),
and (3) converted corrected timestamps into total minutes. At each step we
recorded the numeric output, the correction history, and manual-review flags.

**Processing and correction of timestamp sequence.** Because participants
occasionally entered timestamps out of order (e.g., swapping time in bed and sleep
time), chronological sequence across time in bed, sleep time, final awakening
time, and time out of bed was enforced using a two-step algorithm operating on
complete cases only. Step 1 resolved cross-day and AM/PM misclassifications by
iteratively subtracting 12 hours when adjacent intervals exceeded 12 hours. Step 2
corrected minor inversions (<3 hours), suggestive of accidentally entering
timestamps in the wrong order, by swapping adjacent timestamps. Identical
timestamps (e.g., time in bed = sleep time) were not treated as errors. Records
were flagged for manual review if, after correction, any of the following
remained: (a) timestamp sequence errors; (b) a calculated difference between time
in bed and time asleep of >7 hours; (c) a calculated difference between final
awakening and time out of bed of >7 hours; or (d) a timestamp-derived sleep
duration of >24 hours. Clinically plausible but statistically atypical records
were separately marked for review if timestamp-derived sleep duration was <3 or
>15 hours, calculated SOL was >3 hours, or time in bed after final awakening
exceeded 3 hours.

**Human review.** Two members of the research team independently reviewed all
flagged errors (n = 75) and all statistically atypical cases (n = 37), comparing
each value against that participant's other diary entries so that a given sleep
period could be judged in the context of the rest of their study period. For
flagged errors, the two reviewers reached the same judgment immediately on 48 of
75 records (64.0%) and resolved the remaining 27 (36.0%) by discussion to
consensus; for atypical cases the corresponding figures were 33 of 37 (89.2%) and
4 (10.8%). Because both reviewers were members of the research team with access to
the pipeline output, these figures describe co-review agreement during development
and are not an independent blinded reliability estimate.

**Reincorporation and post-correction verification.** Human corrections were
merged back into the final dataset by a partially automated script that applied
structured labels and parsed free-text correction notes, with checks to ensure
reversibility and post-correction validation flagging discrepancies greater than 6
minutes between derived intervals and reported durations. Duration-based sleep
metrics were derived only after correction was complete.

Where a self-reported duration and the timestamp-derived interval disagreed but
both values were individually plausible, the record was flagged rather than
adjusted. Because this study concerns the association between sleep and same-day
affect, between- and within-person variability in reported sleep timing is the
signal of interest, and normalizing such disagreements toward internal consistency
would risk removing it. Only records confirmed to contain a data-entry error were
corrected.

---

## What changed from the last version, and why

| # | May text | Now | Reason |
|---|---|---|---|
| 1 | "13,990 sleep diary records from approximately 10,000 participants" | **2,860 morning sleep diaries from 237 participants**, drawn from a 13,990-row EMA export | Two separate errors. (a) **237, not ~10,000** — counted directly, the export contains 237 distinct participant ids. (b) **2,860, not 13,990** — 13,990 is the whole EMA export including evening and momentary prompts; only 2,860 rows carry sleep-diary content. Calling all 13,990 "sleep diary records" overstates the diary dataset roughly five-fold. See the note below for how this was established. |
| 2 | "flagged errors (n = 47)" | **n = 75** | The flagged-error review set grew between March and August. The atypical set is unchanged at n = 37. |
| 3 | "resolved all disagreements (X%)" | **48/75 (64.0%) immediate agreement, 27/75 (36.0%) by discussion; atypical 33/37 (89.2%) and 4/37 (10.8%)** | Counted from the two review files (`agreement_cd_mtb`, `cd_mtb_Consenssus`). The placeholder can now be filled. |
| 4 | "Two independent human coders" | **"Two members of the research team independently reviewed…"** plus one sentence stating this is development-time co-review, not blinded reliability | Both reviewers could see pipeline output, so "independent coders" overstates it. Saying so plainly is safer than having a reviewer infer it. The two tracks are also not additive — please do not report 75 + 37 = 112 as one pooled figure. |
| 5 | "three stages" | **four stages** | The May text described four (standardization, sequence, human review, reincorporation) but said three. |
| 6 | — | **New closing paragraph on flag-rather-than-adjust** | States why plausible disagreements are preserved. This rationale had never been written down anywhere, and it is the reason several thresholds are set conservatively. |
| 7 | "In total, there were n = XXX human and algorithmic corrections made." | **removed** | The single pooled number is ambiguous (algorithmic corrections and human corrections are different objects, and rows can carry both). If a total is wanted, give the two separately. |

## How the 2,860 / 13,990 split was established

Counted directly from the export, and the structure is unambiguous:

| quantity | value |
|---|---|
| rows in the export | 13,990 |
| rows carrying any morning sleep-diary timestamp | **2,860** |
| rows carrying none | 11,130 |
| distinct participants | 237 |
| distinct participant × study-day combinations | 3,305 |
| participant-days with **more than one** diary row | **0** (max 1) |
| diary days per participant | median 13, range 1–15 |
| diary coverage | 2,860 / 3,305 = 86.5% of possible participant-days |

The morning diary is exactly one record per participant per day — there is no
duplication to disentangle. All four timestamps, the SOL field and sleep quality
are populated on precisely the same 2,860 rows; WASO on 1,730 of them (60.5%).
The other 11,130 rows are evening and momentary EMA prompts (≈2,850 evening
surveys carrying the same-day affect items, the remainder momentary affect
prompts; the momentary affect item is present on all 13,990 rows).

**Independent corroboration:** 2,860 / 13,990 = 20.4%, which matches exactly the
"20.4% of the full n = 13,990 has non-missing self-reported SOL" figure recorded
in the Channel B validation analysis on 2026-08-12, derived at a different time by
a different route.

**Note for the methods paper, not this one:** "n = 13,990" as used throughout the
pipeline documentation is correct — it is the number of rows the pipeline
processes, and the pipeline does run over the whole export. Only a sentence that
calls those 13,990 rows *sleep diaries* is wrong. No repository text needs
changing on this account; this is a manuscript-wording issue.

## Where "approximately 10,000" probably came from

There is no quantity near 10,000 in the real data. The two nearest things are the
11,130 non-diary rows, and — more likely — the synthetic benchmark's
false-correction-rate test, which is run at **n = 10,000** synthetic records
(`fcr_pure_n10000_result.csv`). A benchmark figure migrating into a dataset
description is an easy slip and worth watching for elsewhere in the older drafts.
Either way the number has no basis in the study data and should not survive.

## Not included, deliberately

The validation work (synthetic error-injection benchmark, recall/specificity
confidence intervals, the M1–M7 audit of the real data, the specification-curve
analysis) belongs to the methods paper, not here. This subsection stays at the
level Maia set in May: what was done to the data, in enough detail to be
reproducible in principle, without turning the sleep paper into a software paper.

