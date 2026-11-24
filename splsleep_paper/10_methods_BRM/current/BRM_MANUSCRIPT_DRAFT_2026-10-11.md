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

The same logical checks can be run without writing anything: order violations, duration-string
shape, deviation from the self-reported value, latency against the timestamp window, a correction that
moves a value further from the self-report, day-to-day jumps beyond five times the participant's own
median absolute deviation, and an inventory of the notes the parser can emit. A row is flagged when a
check hits and the automatic-fix conditions do not hold. On the study data no row met those
conditions, so the audit changed nothing. Its counts are reported apart from the queue a delivered
run leaves, because the two answer different questions.

Every rule is assigned one of three states rather than a single clean-or-keep switch: automatic fix,
which writes a value and is reversible because the entry as typed is kept beside it; flag, which
writes the row to the worksheet and changes nothing; and report only, which records a count or a note
and never touches the data. The families divide accordingly. Standardization flags, and so does
free-text parsing: a full clock time typed into a duration field is flagged at the misentry screen
and never converted, while an `h:mm` above the threshold is read as minutes and seconds and marked
ambiguous. Order validation fixes only when a swap
repairs the chain, keeps the window legal and lands closer to the self-report. The consistency check
either supplies a component of that fix or reports. Cross-day screening and correction provenance
report only, and post-correction verification either flags or passes. One check holds a veto over
every automatic fix: the gap after a fix is compared with the gap before it, and the fix is dropped if
the value moved further from the self-reported duration.

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

### Validation 2b: measurement noise (Bland–Altman)

A diary measures latency and time awake twice: as a duration the participant typed and as
the difference between the times they typed. Before asking whether a correction moved one
report toward the other, we need the size of the disagreement that exists when nothing has
gone wrong. For every night with both a reported and a computed value we
summarized the difference (computed minus reported) as bias, 95% limits of agreement and
the half-width of those limits, then divided each flag threshold by that half-width. A
threshold inside the limits of agreement cannot separate a genuinely long night from
ordinary disagreement between two reports of the same night.

### Validation 3: public datasets

Two public diary datasets not used in development were converted to the diary layout
with scripts in the repository and run with no threshold changed: 1,372 entries from 49
adults [CITE Baigutanova et al., 2025], and 478 entries from 59 adults [CITE Didikoglu et
al., 2023]. Conversion converted 24-hour or numeric-hour times to 12-hour entries and set
get-up equal to wake-up where there was no get-up field.

### Validation 4: whether the answers depend on our own choices

Every threshold here is a judgement: the 12-hour flip trigger, the 3-hour adjacent-swap window,
the 4× MAD spike cutoff, the latency and time-awake flags, the 6-minute verification tolerance.
If the delivered quantities move with any reasonable value of these, the cleaning is manufacturing
the findings rather than measuring them. Three analyses follow. A specification curve over the
genuinely open choices — continuous thresholds plus discrete branches (which rows are trusted,
whether the cross-participant layer runs, whether the review layer is applied), with hard
constraints excluded as logic rather than choice — screened one at a time against the base
specification and then run as a full factorial grid. The delivered quantities (mean total sleep
time, mean latency, analysable nights) recorded over the same grid, plus two branch deltas. And the
whole benchmark regenerated under four seeds. A dimension enters the main curve only if it survives
one-at-a-time screening under more than one seed; that rule was applied after the grid had been
read, so the main curve reported is the conservative one and the full grid is reported as well.

### Pre-registration and exploratory status

The pipeline and its validation plan were built on this project's own data from the outset, and no
analysis plan was registered in advance. The analysis is exploratory rather than confirmatory and is
not described otherwise anywhere in this paper. Three mitigations are in place and each is checkable.
Every number comes from a script at a recorded version: eleven benchmark tables are regenerated from
fixed seeds by one entry point and compared with the committed copies, and the Bland–Altman band, the
multiverse grid, the seed runs and the downstream sensitivities have their own scripts, listed under
Sources of the numbers. The benchmark's ground truth is a self-consistent standard, not an external
gold standard: clean inputs are generated to pass, errors are injected with logged truth, a redundant
channel confirms the repair, and the specificity of the clean layer is reported. And where a result
could have been chosen after the fact, the choice is disclosed: the rule for admitting a dimension to
the specification curve is stated together with the fact that it was applied after the whole grid had
been read.

Steps designed after the benchmark results were known are named as such rather than folded into a
protocol that never existed. The Bland–Altman band, the specification curve and the check of which
error types the pipeline names were all designed once the benchmark results were in hand; each is
reported with the question it answers, so a reader can judge the question independently of when it
was asked.

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

The package (R) is configured by a YAML column mapping and keeps its working objects in a
package-private environment; it does not write to the user's global environment. It is tested with
332 `test_that` blocks across 56 files, including a snapshot test that compares the delivered tables
of a synthetic run with committed copies, and is checked on Linux, Windows and macOS in continuous
integration. The study data were cleaned with version 1.7.1; the released version 1.9.0 differs from
it in one Step 4 rule (the 00:00 guard), and on the pre-correction times of the 2,848 complete nights
the two versions differ on one night. `validation/run_all.R` regenerates eleven of the benchmark
tables from fixed seeds in a temporary copy and compares each with the committed one, all eleven
identically; the remaining tables — the Bland–Altman band, the multiverse grid, the seed runs and the
downstream sensitivities — are produced by their own scripts, listed under Sources of the numbers,
and the first of these needs the study data. The repository is archived at
Zenodo (DOI 10.5281/zenodo.23077702).

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

*Detection is not correction.* The pipeline caught every injected error, 5,391 of 5,391,
but restored the true value in 2,619 (48.6%). The other 2,746 (50.9%) were flagged and
left to a person and 26 (0.5%) were repaired wrongly. The span between caught and fixed is
where the human review sits, and it is reported as its own quantity because the two levels
answer different questions: whether the rule noticed, and whether the field now holds what
happened. For most types the gap is small — a missing colon, and each of the two types that
exchange one adjacent pair, were corrected in all 400 cases — while for two it is nearly the
whole type, because several readings of the same string are plausible and a guess would be
indistinguishable from an entry, so the pipeline declines to guess and flags. Loosening the rules would move rows from flagged to
repaired wrongly, not to correct. The benchmark's own history shows why the two levels are
kept apart. Before the targeted fix, clock times in a duration field were caught in 4.2%
and 3.0% of cases, and 95.8% and 96.0% were silently rewritten to a plausible wrong value;
after the fix the same type is caught in every case and ends in a flag for 98.2% and 96.8%,
in the true value for the rest, and in a wrong value for none. A report that gives only the
caught share cannot tell those two states apart.

### Which types identify themselves

The type score is the account the pipeline gives a reviewer, not the value it writes: for each
injected error it asks whether the pipeline's own record names the injected type. Fourteen types were
each tested against a fixed reference of 0.90 with Benjamini–Hochberg control at 5%, and three fall
below it (Table 4). Because a repair reached by another route can end with the right value under the
wrong name, the two levels are shown together.

| Type | n | names the type (95% CI) | q | value correct | flagged | repaired wrongly |
|---|---|---|---|---|---|---|
| Cross-participant spike | 236 | 27.1% (21.8–33.1) | 8.0e-116 | 0 | 214 | 22 |
| Awake and get-up transposed | 400 | 81.0% (76.9–84.5) | 2.9e-07 | 400 | 0 | 0 |
| AM/PM swapped | 400 | 84.5% (80.6–87.7) | 1.8e-03 | 226 | 174 | 0 |

The other eleven lie between 88% and 100% and none is significant after correction. The nearest, a
clock time read as minutes and seconds at 88.3% (q = 0.49), is one the benchmark cannot separate from
the target with 400 cases, which is stated rather than resolved by leaving it off the list.

The three are different problems. The cross-participant spike is audit-only by design: a single night
far from a participant's other days may be an illness or a shift, and the rule never writes to the
data; the 22 rows repaired wrongly were changed by another rule, and that is the number that matters
for this type. For awake and get-up the value is restored in all 400 cases and the name is wrong in one
row in five, because the same arrangement is reachable by a different swap; the row ends right and the
reviewer is told the wrong mechanism. AM/PM is the one genuine weakness: 43.5% stop at a flag rather
than a repair, and one row in six does not name the injected mechanism. Naming the type is not
cosmetic, because on a flagged row the reviewer's decision starts from that label.

### Error rate and error mix

In all 16 cells at least 98.6% of injected errors were handled (lower bounds of the exact
intervals 94.9 to 99.7%), no clean entry was flagged or altered, and every flagged entry
carried an injected error. What changed was the work left for a person. The share
corrected without one ranged from 14 to 19% when window contradictions dominated (the
real-world proportions) to 57 to 62% for timestamp errors only, and the number of rows
flagged rose from 8 to 151 per 1,000 entries (Table 5). The review burden is a property of
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
39 of 39 (720 to 9 minutes) and 2 of 3.

The same step also rejected a rule. The one that reverses a sleep-and-awake transposition
moved 7 of its 10 applicable rows away from the self-report in the first analysis, while
the set as a whole read 81 of 88 (92%). It was diagnosed and guarded in version 1.4.3 with
a `bed ≤ awake` condition rather than removed, and on the current pipeline it applies to 3
rows with a self-report, 2 of which improve and 1 worsens; the other two families are
unchanged and the three together read 80 of 81. The counts differ because the pipeline
changed, not because the comparison did — which is the point: the yardstick caught one of
our own rules and the guard is what shows in the current numbers.

*Review files.* Without the reviewers' files, 1,719 entries had a total sleep time and 61
remained errors; with them, 1,729 and 3. The rules corrected 93 rows (10 of them also by a
reviewer) and the reviewers corrected 75 further rows. The review queue at the end of a
run was 226 rows with the files applied and 307 without: 79 and 108 per 1,000 of the
2,848 entries with all four times, or 16 and 22 per 1,000 of all 13,990 submissions. The
per-entry rate is the one quoted, because every analysis of sleep uses only those entries.

*Agreement.* The reviewers agreed immediately on 48 of 75 flagged errors (64.0%) and 33 of
37 atypical cases (89.2%). They worked on one shared worksheet, so this is agreement, not
an independent reliability estimate. Of 112 reviewed records, 85 were corrected and 27
needed no change.

*What the flag counts count.* Three numbers in this paper are all described as flags, and
none of them is the number of errors in the study data; each is quoted with the population
and the run that produced it (Table 6).

| Count | What it is | Population |
|---|---|---|
| 1,048 | rows flagged by the report-only audit, which changed nothing: 922 window violations, 140 order violations, 35 latency strings that support a second reading, 1 silent-worsening candidate and 1 cross-day jump; 50 rows carry more than one | 13,990 submissions, v1.4.5 audit run |
| 226 (307) | rows left in the review queue at the end of a run, with (without) the reviewers' files applied | 13,990 submissions; 79 (108) per 1,000 of the 2,848 complete entries, delivered run |
| 112 | records a person worked through on the shared worksheet: 75 flagged errors and 37 atypical cases; 85 corrected, 27 left as written | worksheet |

The three are not nested. The 37 atypical cases came from a different route than the
flagged errors, so the 112 is not a subset of the 1,048, and the audit is a separate
report-only run on an earlier version. The audit and the queue also count different things:
the audit asks whether a rule could fire on the raw data, while the queue is what a
delivered run leaves for a person after the confident rules have acted.

*Measurement noise.* 2,848 nights carry both a reported and a computed latency, and 1,730
both a reported and a computed time awake. For latency the computed value exceeds the
reported one by 13.2 minutes on average, 95% limits of agreement −61.1 to +87.6, half-width
74.4 minutes. The two latency thresholds, 120 and 60 minutes, are 1.61 and 0.81 times that
half-width: both lie inside the band, so a latency flag is descriptive and is not read as
evidence of an entry error. The severity column feeds no correction path, verified in the
code. For time awake the bias is −6.6 minutes, the limits −33.9 to +20.7, the half-width
27.3 minutes, and the 90-minute severity threshold is 3.29 times the half-width, outside
the band. Efficiency and the total-sleep-time to time-in-bed ratio have no self-reported
counterpart, so no such comparison exists for them. Limits of agreement bound consistency
between two reports, not accuracy against sleep itself, which would need actigraphy or
polysomnography; and the half-width is a property of these participants on these
instruments, so the band is reported rather than 60, 90 and 120 minutes presented as
universal.

### Do the choices matter?

*Which choice dominates.* In the full factorial grid of the two dimensions that entered it, the
adjacent-swap window accounts for 46.4% of the variation in the delivered quantities, the AM/PM flip
trigger for 6.6%, and 47.1% is residual. That share does not survive a change of seed: one-at-a-time
screening keeps both dimensions under seed 20260817 but only the flip trigger under 20260915, so the
intersection is the flip trigger alone. The main specification curve therefore has three
specifications (flip at 11, 12 and 13 hours) and the nine-cell factorial grid is reported alongside it.
Under all five specifications tested for record-level stability, no entry changed class: the share of
clean entries that stayed clean, of valid equal-time entries that stayed valid and of injected errors
that stayed classified as errors was 1.0 in every specification.

| Quantity | Base | Main curve (3 specs) | Full grid (9 specs) |
|---|---|---|---|
| mean total sleep time | 8.06 h | 8.06 to 8.07 h | 7.92 to 8.09 h |
| mean latency | 31.2 min | **22.7 to 58.1 min** | 22.5 to 58.9 min |
| analysable nights | 6,581 | 6,327 to 6,660 | 6,303 to 6,663 |

*What a study would receive.* The two conclusions have different status. Total sleep time is
essentially fixed on the main curve, moving by 0.8 minutes; on the full grid it moves by 10 minutes,
and every cell that moves it is one where the adjacent-swap window is changed (1 and 6 hours), while
the three flip settings at the base window span 0.8 minutes. Latency is not fixed: it ranges over 35
minutes, and the Bland–Altman
band above says why — with a half-width of 74 minutes, a latency that shifts by 35 is movement inside
the measurement noise of the instrument that produced it, not a different answer about sleep. Two
branch decisions move the deliverable by more than any threshold does: which rows to trust shifts mean
total sleep time by 29.6 minutes, and a wider time-awake trust gate changes the number of analysable
nights by 1,131. On the study data the one-at-a-time grid gives total sleep time 7.686 to 7.702 h,
latency 25.3 to 25.9 min and 1,707 to 1,720 analysable nights, with the 13-hour flip trigger the one
specification that moves latency (to 34.1 min) and drops 12 nights.

*Seeds.* Pooled recall was 0.9935 to 0.9952 across four seeds with no clean entry flagged in any run.
The one family that moves is the cross-participant spike, 0.886 to 0.907, which is the family the
pipeline already treats as audit-only: a single high night may be an illness or a shift, so it is
flagged for a person and never corrected.

*What it means.* The choice that dominates the grid is a sensitivity warning rather than a knob to
tune: changing the adjacent-swap window moves rows between flagged, missed and wrongly repaired, not
between flagged and correct. A narrower window leaves 1,246 rows classified as errors against 979 at
the base value, and a wider one repairs more pairs, some of them wrongly. The reported status of each
quantity — robust, sensitive, or audit-only — is decided by these three analyses together with the
noise band, not by the base specification alone.

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
[BLANK: route for qualified researchers, if any]. The synthetic benchmark can be
regenerated from fixed seeds: `validation/run_all.R` reproduces eleven of the committed
tables and compares each with the committed copy, and the multiverse, seed and downstream
tables have their own scripts, listed under Sources of the numbers. Two public datasets
used for the format check are cited with their DOIs.

**Code availability and open practices.** https://github.com/cyracaid/sleepdiary-cleaner,
archived at Zenodo (concept DOI 10.5281/zenodo.23077702; the study data were cleaned with
version 1.7.1, 10.5281/zenodo.23735330; the current release is 1.9.0,
10.5281/zenodo.24408732). Neither the study nor the analyses reported here were
preregistered.

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
2026-10-01 and 10-11 on the study data (counts only); Bland–Altman:
`output/verification/real_n13990/threshold_validation.csv` (run 2026-10-29, package 1.7.1;
generated by `validate_thresholds()` in `R/bland_altman.R`, rendered by
`validation/render_validation_report.R`); multiverse, downstream and seeds:
`validation/synthetic/results/multiverse/` (`spec_curve.csv`, `spec_curve_full.csv`,
`variance_decomposition.csv`, `oat_screening.csv`, `instability.csv`),
`validation/synthetic/results/downstream_sensitivity.csv`,
`validation/synthetic/results/seed_sensitivity.csv`,
`validation/synthetic/results/real_data_{spec_curve,oat_screening}.csv`; type identification and
multiplicity: `validation/synthetic/l2_tier_leave_one_out.R`, `l2_tier.csv`,
`validation/synthetic/fdr_analysis.R`, `fdr_corrected.csv`; audit layer:
`validation/audit_review_queue_m1_m7.R`, `audit_m1_m7_decision.csv`; co-review:
`VALIDATION_REPORT.md`; public datasets: `validation/external/README.md`.

## Items to settle before this is shown

1. The review queue is quoted per entry with all four times (79 and 108 per 1,000) and per
   submission (16 and 22); the entry rate is used in the text and both are given. Decide
   whether to keep both.
2. The statement that no tool does this is not verified (Introduction).
3. The literature scan, the blind audit and the typing task have not been done; the
   Introduction and Discussion are written so that they do not depend on them, but the
   Discussion should be revised once any of them exists.
4. The laboratory and PI are unnamed; ethics, funding and authorship are blanks.
5. Figures: pipeline diagram; error types with an example each; stacked outcomes per type;
   metric distortion by arm; redundant channel before and after; review queue by mix.
