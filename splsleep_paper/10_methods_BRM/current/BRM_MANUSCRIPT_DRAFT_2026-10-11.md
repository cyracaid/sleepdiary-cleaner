# sleepcleanr: an auditable pipeline for cleaning self-reported sleep-diary data, validated on injected, real and public data

**Draft 2026-10-11, assembled from the section drafts of 2026-10-01 to 10-06.** Not
shown to the co-author. `[CITE]` = a reference to confirm or supply. `[CHECK]` = a
statement that needs a person. The laboratory and the principal investigator are not
named until the PI has agreed. Every number is taken from a file in the repository
(`validation/`, `VALIDATION_REPORT.md`) or from a run of 2026-10-01 to 10-11; sources are
listed at the end.

Authors: Cai Dong, Maia ten Brink [CHECK: author list, affiliations, order]

---

## Abstract

Sleep diaries collected by ecological momentary assessment give repeated, within-person
measures of sleep, but participants type bedtimes, wake times and durations as free text,
and typing errors change the quantities studies analyze. Current practice is manual
checking or study-specific scripts that leave no record of what changed, while fully
automatic repair risks turning an unusual but real night into a plausible wrong one. We
present sleepcleanr, an R pipeline that corrects only what a documented rule can show to
be an error, sends everything else to a human reviewer and records every change against
the original entry. On a synthetic benchmark of 5,391 injected errors in 14 categories
and 1,609 clean entries, 99.5% of errors were flagged or corrected to the true value
and no clean entry was flagged or altered; 48.6% were corrected to the true value, 50.9%
were flagged for a person and 0.5% were repaired wrongly. Across 16 combinations of error
rate (2 to 20%) and error-type mix the handled share never fell below 98.6%, while the
work left for a person ranged from 8 to 151 flagged entries per 1,000. Residual bias in
sleep metrics after cleaning sat entirely in the flagged entries. In 13,990 submissions
from one study, corrections moved the computed onset latency toward participants' own
reports in 80 of 81 cases. The pipeline ran unchanged on two public datasets, which
contain no known errors and so show format generality, not accuracy. We release the
package, tutorials and the scripts that regenerate every benchmark table.

**Keywords:** sleep diary; ecological momentary assessment; data cleaning; data
quality; reproducibility; R package

---

## Introduction

Sleep diaries collected through ecological momentary assessment (EMA) allow researchers
to follow a person's sleep from night to night and to link it to mood, behavior and
health measured in the same days [CITE]. In intensive longitudinal designs a participant
may complete a diary entry every morning for weeks, so a study of a few hundred people
can produce tens of thousands of entries. The quantities of interest are usually simple:
how long the person was in bed, how long they took to fall asleep, how long they were
awake in the night, and how much they slept. Each is computed from times and durations
that the participant types.

That typing is the source of the problem. When bedtime, sleep time, wake time and get-up
time are entered as free text, entries go wrong in recognizable ways: AM and PM are
swapped; two adjacent times are transposed; a clock time such as "11:30" is typed into a
field that expects a duration in minutes; a reported time to fall asleep is longer than
the whole interval between getting into bed and falling asleep. These errors change the
quantities a study analyzes: a swapped AM or PM turns a night of seven hours into one of
nineteen.

Current practice for such entries is mostly manual inspection or scripts written for a
single study [CHECK: cite how published sleep-diary studies report cleaning; the scan
protocol is in `validation/literature_scan_README.md`]. Both share one weakness: it is
rarely possible to say afterwards which entries were changed, by which rule, and what
they looked like before. Two studies that clean their diaries differently cannot be
compared, and a reader cannot tell whether an unusual result comes from the participants
or from the cleaning.

Several tools prepare EMA and experience-sampling data for analysis. The esmtools
framework and package provide a step-by-step preprocessing workflow with reporting
templates, covering adherence to the sampling design, response behaviour such as
compliance and careless responding, and description of the data [CITE Revol et al.,
2024; CHECK scope against the paper]. Careless and insufficient-effort responding has its
own literature, including indicators validated by simulation and real data [CITE Meade &
Craig, 2012; Curran, 2016; Goldammer et al., 2024] and studies of how it behaves in EMA
[CITE Ulitzsch et al., 2025; Vogelsmeier et al., 2025]. These address whether a
respondent engaged with the survey. A different problem arises inside a single, attentive
entry: a participant who types the wrong AM or PM, transposes two times, or writes a clock
time where a duration was asked produces a value that is wrong although the respondent
was careful. We did not find a published tool that detects and corrects such entry errors
in typed diary times and durations while recording every change [CHECK: a systematic
search is needed before this sentence is kept].

Fully automatic repair carries its own risk. A rule that "fixes" every entry that looks
odd will sooner or later change a night that was unusual but real into a plausible and
wrong one, and the change will leave no trace. The risk is sharpest for duration fields:
an earlier version of our pipeline silently turned a clock time typed into a latency
field into a plausible number of minutes in about 96% of injected cases, because the raw
entry passed a plausibility check and the parsed value was never checked again. For a
study whose question is how sleep varies within a person, quietly pulling unusual
entries toward the typical would remove the signal.

We therefore built a pipeline on a conservative principle. It corrects only what a
documented rule can show to be an error; it sends everything else to a human reviewer
instead of guessing; and it records every change against the original entry, so that raw
and corrected values stay inspectable and a correction can be reversed. The standard
sleep metrics (total sleep time, sleep-onset latency, wake after sleep onset and sleep
efficiency) are computed only afterwards. A column mapping configures it for a new study
without changing code.

We evaluate the pipeline in three steps and say plainly what each can and cannot show.
First, a synthetic benchmark with known truth, in which errors are injected into
constructed diary data, reports detection, correction, wrong repair and the rate at which
clean entries are altered, over a grid of error rates and error-type mixes. Second, real
study data are examined with a redundant measure that the correction step never reads
(the participant's own report of how long they took to fall asleep) and with the
agreement between two human reviewers. Third, the pipeline is run unchanged on two public
diary datasets. We also describe, and provide the tooling for, two checks that need
people and have not yet been run: a blind audit of real entries by annotators who did not
write the rules, and a typing task in which people type known schedules so that real
typing errors have a known truth. Finally, we release the package, the tutorials and the
scripts that regenerate every benchmark table.

---

## Method

### Design principle and overview

The pipeline reads raw entries, parses times and durations, applies rules in three
classes (correct, flag, leave alone), writes a worksheet of everything flagged, applies a
reviewer's decisions when a correction file is supplied, and only then computes the
standard sleep metrics. Nothing is changed without a recorded correction type; the
entry as typed is kept beside the corrected value; and a step ledger counts, at each step,
how many entries are clean, in error, unusual or skipped. Manual corrections are applied
only when the caller asks for them, so a data set cannot be modified by review files left
in a working directory.

### Error types and rules

Table 1 lists the 14 error types used in the benchmark, the form each takes in a real
diary, and what the pipeline does. The types come from errors seen in the study data and
from the literature on diary entry [CHECK: sources; the catalog records for each type
whether it was observed in the study, taken from the literature, or both].

| Type | What it looks like | What the pipeline does |
|---|---|---|
| AM/PM swapped | the evening time typed as AM, so two adjacent times are 12 hours apart | corrects when the gap is 12 h or more and the flip restores a plausible night; otherwise flags |
| Adjacent times transposed (bed and sleep; awake and get-up) | the later time typed first | swaps when the gap is under 3 h |
| Sleep and awake times transposed | the late-evening and early-morning times in each other's fields | classes as an order error; flags |
| Large-gap transposition left clean | transposed times more than 3 h apart | flags |
| AM/PM swap combined with a transposition | both at once | corrects what a rule can prove; flags the rest |
| Missing or misplaced colon | "1130", "11.30" | reads the intended time |
| MM:SS read as HH:MM | "10:30" meaning 10 minutes 30 seconds | reads as minutes and seconds when the value exceeds 60 |
| Clock time typed into a duration field (latency or time awake) | "11:30" in the latency field | flags; never converts silently |
| Implausible duration | a latency or time awake that no night supports | flags |
| Latency longer than bed-to-sleep window | 200 minutes to fall asleep, 20 minutes between bed and sleep | flags |
| Cross-participant spike | one participant's value far from their other days | flags |

Table 2 gives the reference thresholds. They were set on a healthy young-adult sample and
are reference values, not optimized ones (see Results).

| Rule | Default |
|---|---|
| gap that triggers an AM/PM flip | 12 h |
| gap below which adjacent times are swapped | 3 h |
| times before this hour are assigned to the next day | 6 AM |
| value above which "h:mm" is read as minutes and seconds | 60 |
| latency flagged as excessive | 120 min |
| efficiency flagged as impossible | below 0% or above 100% |
| ratio of sleep time to time in bed | 0.5 to 1.0 |

### Human review and audit trail

Flagged entries go to a worksheet with the typed and parsed times, the error type and
blank columns for the reviewer's problem, solution, the column to correct and the
corrected value. The reviewer's file is applied on the next run. Four columns on the
worksheet show, for every flagged row, whether it is in a manual file, how it was
resolved, when and by whom, and the end of a run prints how many rows are handled,
pending or still a problem after the re-check. In the study, two members of the team
reviewed the flagged entries on one shared worksheet.

### Validation 1: synthetic benchmark

*Data.* 500 simulated participants with 14 days each (7,000 rows) were generated with a
fixed seed from a model of a healthy adult. Errors were injected with logged truth; 400
per type (5,391 rows in the 14 types after eligibility) and 1,609 rows left untouched as
controls. A subset of participants (12%) received six times the injection probability, to
reproduce the clustering seen in real data.

*Outcomes.* Each injected row is scored as corrected to the true value, flagged (held for
a person), repaired wrongly or missed. "Handled" means corrected to the true value or
flagged. The false-alarm rate is the share of clean rows flagged or altered; participant-
level cluster bootstrap gives the interval for recall.

*Comparators.* No cleaning, and a naive rule that resolves midnight and swaps any adjacent
pair that is out of order.

*Sensitivity.* Four seeds; a 20-point grid of the swap (1 to 5 h) and flip (8 to 14 h)
thresholds; and a grid of four overall error rates (2, 5, 10 and 20% of rows) by four
error-type mixes (equal numbers per type; the real-world proportions in the catalog;
timestamp errors only; duration errors only), 16 cells.

*Metric distortion.* Mean total sleep time, latency and efficiency under each arm (clean,
no cleaning, naive rule, pipeline) were compared with the clean data on the same rows,
and again with the flagged rows set aside.

### Validation 2: real study data

The study data are 13,990 EMA submissions from 237 participants, of which 2,848 have all
four times (the others are not morning diaries or lack times). *Redundant channel.* For
every row whose bed-to-sleep gap the pipeline changed and that has a self-reported
latency, we compared the distance between the gap and the self-report before and after the
change. The correction step never reads the self-reported duration, so the comparison is
not circular. *Effect of the review files.* The pipeline was run with and without the
reviewers' files. *Agreement.* Immediate agreement of the two reviewers on 75 flagged
errors and 37 atypical cases. *Threshold sensitivity.* The same pipeline was run over a
grid of thresholds on the real data.

### Validation 3: public datasets

Two public diary datasets not used in development were converted to the diary layout
with scripts in the repository and run with no threshold changed: 1,372 entries from 49
adults [CITE Baigutanova et al., 2025], and 478 entries from 59 adults [CITE Didikoglu et
al., 2023]. Conversion converted 24-hour or numeric-hour times to 12-hour entries and set
get-up equal to wake-up where there was no get-up field.

### Checks that need people (not yet run)

*Blind audit.* Two annotators who did not write the rules label about 350 raw entries,
stratified into flagged, changed-without-a-flag and left-alone rows, without seeing the
pipeline's output; the miss rate in left-alone rows, the precision of the flags and the
annotators' agreement follow, with a population-level estimate. *Typing task.* 30 to 50
people read 40 short descriptions of a night and type them into a diary form; the true
times are known, so typing errors have a truth no one on the project chose. Materials,
scoring scripts and tests on simulated data are in `validation/blind_audit/` and
`validation/typing_task/`.

### Software and reproducibility

The package (R, version 1.5.0) is configured by a YAML column mapping, tested (518 tests)
and checked on three platforms in continuous integration. The package keeps its working
objects in a package-private environment and does not write to the user's global
environment. `validation/run_all.R` regenerates the benchmark tables from fixed seeds in
a temporary copy and compares each with the committed one; all 11 regenerate identically.
The repository is archived at Zenodo (DOI 10.5281/zenodo.23077702).

---

## Results

### Benchmark: detection and correction

Of 5,391 injected errors, 5,365 (99.5%; 95% interval 99.3 to 99.7) were flagged or
corrected to the true value (Table 3). 2,619 (48.6%) were corrected to the true value,
2,746 (50.9%) were flagged and held for a person, and 26 (0.5%) were repaired wrongly. Of
the 1,609 clean entries none was flagged or altered (upper 95% bound 0.19%). No cleaning
handled none; the naive rule handled 62.3%. Across four seeds the share handled was 99.35
to 99.52%, and over the 20-point threshold grid 99.50 to 99.57% with no false alarms.

Table 3 shows the types. Colon and format errors and the two adjacent-pair
transpositions were corrected in all 400 cases; a clock time read as minutes and seconds
in 94.5% (4 wrong). An AM/PM swap was corrected in 56.5% (the others flagged) and the
combined swap in 38%. Clock times typed into the latency and time-awake fields were
corrected in 1.8% and 3.3% and flagged in the rest. Sleep and awake times transposed,
implausible durations and latencies longer than the bed-to-sleep window were never
corrected, all were flagged (400, 400 and 355). The weakest type is the cross-participant
spike: 214 of 236 flagged and 22 repaired wrongly. The pipeline never converted a clock
time typed in a duration field silently: before a targeted fix this happened in 95.8%
(latency) and 96.0% (time awake) of cases; afterwards in none.

| Type | n | corrected to the true value | flagged only | repaired wrongly |
|---|---|---|---|---|
| Missing or misplaced colon (two types) | 400 each | 400, 400 | 0 | 0 |
| Bed and sleep transposed | 400 | 400 | 0 | 0 |
| Awake and get-up transposed | 400 | 400 | 0 | 0 |
| MM:SS read as HH:MM | 400 | 378 | 18 | 4 |
| AM/PM swapped | 400 | 226 | 174 | 0 |
| Transposition left clean (large gap) | 400 | 243 | 157 | 0 |
| AM/PM swap with transposition | 400 | 152 | 248 | 0 |
| Clock time in latency field | 400 | 7 | 393 | 0 |
| Clock time in time-awake field | 400 | 13 | 387 | 0 |
| Sleep and awake transposed | 400 | 0 | 400 | 0 |
| Implausible duration | 400 | 0 | 400 | 0 |
| Latency longer than the window | 355 | 0 | 355 | 0 |
| Cross-participant spike | 236 | 0 | 214 | 22 |

### Error rate and error mix

In all 16 cells at least 98.6% of injected errors were handled (lower bounds of the exact
intervals 94.9 to 99.7%), no clean entry was flagged or altered, and every flagged entry
carried an injected error. What changed was the work left for a person. The share
corrected without one ranged from 14 to 19% when window contradictions dominated (the
real-world proportions) to 57 to 62% for timestamp errors only, and the number of rows
flagged rose from 8 to 151 per 1,000 entries (Table 4). The review burden is a property of
the mix, not only of the rate. Clean entries in the benchmark are built to pass, so a
precision of 1.0 is a property of the benchmark.

| Mix | 2% | 5% | 10% | 20% |
|---|---|---|---|---|
| equal: handled / corrected / flagged per 1,000 | 98.6 / 46 / 11 | 99.4 / 46 / 30 | 99.4 / 47 / 59 | 99.1 / 47 / 116 |
| real-world: handled / corrected / flagged per 1,000 | 100 / 14 / 16 | 99.4 / 19 / 38 | 99.5 / 19 / 75 | 99.8 / 19 / 151 |
| timestamp only | 100 / 57 / 8 | 100 / 58 / 21 | 100 / 62 / 38 | 100 / 57 / 85 |
| duration only | 100 / 43 / 14 | 99.7 / 43 / 34 | 99.6 / 43 / 69 | 99.6 / 43 / 136 |

### Metric distortion

Against the clean data on the same 6,668 rows, not cleaning left total sleep time 86.0
minutes short, onset latency 191.4 minutes long and efficiency 22.0 points low; the naive
rule left them at -55.2 minutes, +117.9 minutes and -18.5 points; the pipeline left them
at +11.2 minutes, +47.6 minutes and +2.5 points. The remaining bias sat entirely in the
flagged entries: with the 2,787 flagged rows set aside, the other 3,881 showed no shift in
any of the three (0.00), while the flagged rows alone were 114 minutes too long on
latency. This is not free: the benchmark is enriched with errors (77% of rows), so setting
the flagged rows aside cost 42% of rows; in the study data the review queue is 7.9% of the
entries with all four times (226 of 2,848).

### Real study data

*Redundant channel.* In 81 rows whose bed-to-sleep gap was changed and that had a
self-reported latency, the change moved the computed latency toward the self-report in 80
(98.8%; exact interval 93.3 to 100%). By rule, 39 of 39 (median distance 31 to 5 minutes),
39 of 39 (720 to 9 minutes) and 2 of 3. An earlier analysis (81 of 88, 92%) predates a
guard added to one rule.

*Review files.* Without the reviewers' files, 1,719 entries had a total sleep time and 61
remained errors; with them, 1,729 and 3. The rules corrected 93 rows (10 of them also by a
reviewer) and the reviewers corrected 75 further rows. The review queue at the end of a
run was 226 rows with the files applied and 307 without, which is 79 and 108 per 1,000 of
the 2,848 entries with all four times. [CHECK: whether the queue's 226 and 307 should be
quoted per diary entry or per submission; both are given in the repository.]

*Agreement.* The reviewers agreed immediately on 48 of 75 flagged errors (64.0%) and 33 of
37 atypical cases (89.2%). They worked on one shared worksheet, so this is agreement, not
an independent reliability estimate. Of 112 reviewed records, 85 were corrected and 27
needed no change.

*Thresholds.* No threshold dimension changed the mean total sleep time by more than 0.93
minutes or the number of analysable rows by more than 0.70%.

### Public datasets

The pipeline completed all steps on both. In the first, 1,094 of 1,372 entries (79.7%)
had a total sleep time, mean 7.55 hours, as in the source study; no entry was classed an
error or unusual and none was corrected. In the second, 473 of 478 entries had a total
sleep time (mean 7.63 hours, against a self-reported mean duration of 7.26 hours in the
source file, a difference we do not interpret because the quantities are defined
differently). Neither dataset contains known diary errors, so these runs show that the
pipeline accepts other formats, not how well it finds errors.

### A worked example

Two rows from the benchmark illustrate the two paths. A participant went to bed at 10:10
PM and typed the time they fell asleep as 10:26 AM. Parsed as typed, sleep begins 12
hours and 16 minutes after bedtime; a gap of 12 hours or more is the signature of a
swapped AM or PM, so the rule moves the sleep time to 10:26 PM, records the correction
type and keeps the entry as typed. In another row the participant typed bedtime 11:45 PM,
sleep time 6:05 AM, awake time 11:58 PM and get-up time 6:05 AM. The sleep and awake
times appear to be in each other's fields, but no rule can be sure which entry is wrong;
the row is classed an order error, not changed, and appears on the worksheet for a person.
The first row needs no person and the result is verifiable; the second is held because
guessing would risk replacing a real entry with a plausible wrong one. About half of the
injected errors were of the second kind.

---

## Discussion

We described a pipeline that corrects only what a documented rule can show to be an error,
sends the rest to a person and records every change. On injected errors it flagged or
corrected between 98.6 and 100% across error rates and mixes without touching a clean
entry; on real study data its corrections moved the computed latency toward participants'
own reports in 80 of 81 cases; and it ran unchanged on two public datasets.

### Recommendations

1. *Plan for review.* Expect a share of entries to be flagged, and expect it to depend on
   the kinds of errors your participants make. In the study data the review queue was 79
   per 1,000 entries with all four times with the reviewers' files applied (108 before);
   in the benchmark it ranged from 8 to 151 per 1,000 depending on the mix.
2. *Treat the thresholds as reference values.* The benchmark and the study data are
   insensitive to the swap and flip thresholds over the range tested, so the defaults are
   not optimized. Re-check them on a sample of your own data, especially for clinical,
   shift-work or elderly samples.
3. *Audit what the pipeline leaves alone.* Detection is measured against errors we
   injected. Have two people who did not write the rules label a stratified sample of your
   own raw entries and estimate the miss rate.
4. *Do not drop flagged rows silently.* After cleaning, the remaining bias sat entirely in
   the flagged rows; decide, and report, what you do with them.
5. *Keep the record.* Keep the correction files and the step ledger with the data, and
   describe the cleaning with `cleaning_report()`.
6. *Know its scope.* It cannot recover information that was never entered, it assumes a
   morning diary with typed clock times, and it does not replace study-specific quality
   control.

### Limitations and future directions

The benchmark is built by us, and its errors are the ones the rules were designed for; the
rates and mixes are varied but the types are not new. The check that can find errors we
did not anticipate, a blind audit of real entries, has not yet been run. The real data come
from one study and the thresholds were tuned on a healthy-adult sample. The two reviewers
worked on one worksheet, so their agreement is not an independent reliability estimate,
and a 64% immediate agreement on flagged errors is modest. The public datasets contain no
known diary errors. The bias that remains after cleaning (onset latency still 47.6 minutes
above the clean data in the main benchmark) sits in the flagged rows and is removed only if
they are set aside or resolved. The manual-correction instructions understand four forms
(a time on the same day, minus 12 hours, plus 12 hours, a bare time), so a correction that
needs the previous calendar day cannot be expressed; we met this preparing the worked
example. Future work: the blind audit; the typing task, which gives real human typing
errors with a known truth; other diary designs (evening diaries, the Consensus Sleep
Diary [CITE Carney et al., 2012]); and a downstream analysis of how cleaning choices change
an association the study cares about.

### Conclusion

Half of the errors in a typed sleep diary need a person, and what remains after cleaning
is concentrated there, which tells the user where to look. A pipeline that separates what
a rule can prove from what it cannot, and records both, makes that division visible and
reproducible. The package, tutorials and the scripts that regenerate every benchmark
table are openly available.

---

## Declarations

**Funding.** [BLANK]  **Conflicts of interest.** [BLANK]

**Data source, ethics and consent.** The diary data come from an ongoing longitudinal home
sleep study at [BLANK: institution and laboratory, only with the PI's agreement]. The
study was approved by [BLANK: committee and protocol] and participants gave [BLANK:
consent]. The secondary analysis was covered by [BLANK: approval or agreement; who holds
it]. The de-identified export was used; no participant identifiers are in the repository,
the archive or this paper.

**Data availability.** The study data are not public because of participant privacy
[BLANK: route for qualified researchers, if any]. The synthetic benchmark and every table
derived from it can be regenerated with `validation/run_all.R`. Two public datasets used
for the format check are cited with their DOIs.

**Code availability and open practices.** https://github.com/cyracaid/sleepdiary-cleaner,
archived at Zenodo (DOI 10.5281/zenodo.23077702; version 1.5.0, 10.5281/zenodo.23175667).
Neither the study nor the analyses reported here were preregistered.

**Authors' contributions.** [BLANK: CRediT]

**Use of AI tools.** Generative AI assistants (DeepSeek V4 Flash and V4 Pro through
opencode; Claude Sonnet, Opus and Haiku through Claude Code) were used to draft and revise
code, tests, documentation and text. The authors made the design decisions, reviewed every
change and made all manual-review decisions on the study data. The pipeline itself calls no
AI model.

---

## References (to confirm)

Baigutanova et al. (2025), *Scientific Data* 12, 1474. Carney et al. (2012), Consensus
Sleep Diary, *Sleep* [CHECK]. Courtin et al. (2026), *Behavior Research Methods* 58:260.
Curran (2016), *Journal of Experimental Social Psychology* [CHECK]. Didikoglu et al.
(2023), *PNAS* [CHECK]. Geller, Winn, Mahr & Mirman (2020), gazeR, *Behavior Research
Methods* 52. Goldammer et al. (2024), *Behavior Research Methods* 56(8), 8831-8851. Meade &
Craig (2012), *Psychological Methods* [CHECK]. Nuijten et al. (2016), *Behavior Research
Methods* 48, 1205-1226 [CHECK]. Revol et al. (2024), *Advances in Methods and Practices in
Psychological Science* [CHECK]. Ulitzsch et al. (2025), *Psychological Assessment* 37(8).
Vogelsmeier et al. (2025), *Psychological Methods*.

## Sources of the numbers

Benchmark: `validation/synthetic/results/` (`recall_specificity_ci.csv`,
`correction_level_recall.csv`, `correction_level_recall_per_category.csv`,
`far_flag_alter.csv`, `control_baselines.csv`, `seed_sensitivity.csv`,
`operating_point_sweep.csv`, `prevalence_grid.csv`, `low_prevalence.csv`,
`metric_distortion.csv`); real data: `validation/redundant_channel_check.R` and the runs of
2026-10-01 and 10-11 on the study data (counts only); co-review: `VALIDATION_REPORT.md`;
public datasets: `validation/external/README.md`.

## Items to settle before this is shown

1. The review queue is quoted per entry with all four times (79 and 108 per 1,000) and per
   submission (16 and 22); choose one and say which.
2. The statement that no tool does this is not verified (Introduction).
3. The literature scan, the blind audit and the typing task have not been done; the
   Introduction and Discussion are written so that they do not depend on them, but the
   Discussion should be revised once any of them exists.
4. The laboratory and PI are unnamed; ethics, funding and authorship are blanks.
5. Figures: pipeline diagram; error types with an example each; stacked outcomes per type;
   metric distortion by arm; redundant channel before and after; review queue by mix.
