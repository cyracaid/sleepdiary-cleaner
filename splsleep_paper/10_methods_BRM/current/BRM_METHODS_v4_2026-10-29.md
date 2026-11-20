# Method (Behavior Research Methods), v4 DRAFT 2026-10-29

## Method

The export contained 13,990 EMA submissions (rows) from 237 participants over up to 15 days. Of
these rows, 2,860 were morning sleep diaries, one per participant per study day, and 2,848 of them
had all four diary times. Each diary recorded, as free text, the times the participant went to bed,
fell asleep, woke up and got out of bed, plus self-reported sleep onset latency (SOL), wake after
sleep onset (WASO) and time in bed. To ensure data validity we built a structured, auditable
correction pipeline (R package sleepcleanr, version 1.7.2) that addresses timestamp formatting,
internal consistency and derived sleep metrics. Its rule is that a value is changed automatically
only when a documented rule can show that it is a data-entry error; anything that needs a judgment
about whether an unusual value is a mistake or a real night is written to a worksheet for a person
and is not altered. Every change is labeled with its type, and the entry as typed is kept beside the
corrected value. The pipeline runs in the following steps.

**Step 1: Data loading and schema validation.** The pipeline reads the raw export (`.rds` or `.csv`)
and, before any processing, checks that every column it needs exists under an expected name:
participant ID, the four timestamp fields and the duration fields. If one is missing or misnamed the
run stops with a message that names it, so it never continues on incomplete input. If human-review
files are configured but missing, the pipeline stops or asks whether to continue without them, so a
run cannot quietly proceed as if human corrections had been applied when they were not.

**Step 1.5: Field-misentry screen.** Participants sometimes type a clock time into a duration field,
for example the time they fell asleep into the SOL field. Because this must be seen before any
parsing changes the string, the screen runs on the raw text: a row is flagged when the raw SOL string
is identical to the raw bedtime or sleep-onset string, or when the raw WASO string is identical to
the raw awake-time or get-up string. Flagged rows are written to a file and nothing is changed.

**Step 2: Timestamp standardization.** Each time is rebuilt from its hour-minute and AM/PM fields.
Periods and semicolons are replaced by a colon, a single-digit hour is padded ("7:30" becomes
"07:30"), an hour with no minutes gets ":00", and an hour above 12 is read as a 24-hour entry with no
AM/PM conversion; an hour above 24 is invalid. For the two evening variables (bedtime and sleep
onset), a PM entry at 12 is taken as midnight, and any parsed time later than 15:00 is assigned to the
previous calendar day, so that a bedtime of 11:30 PM belongs to the night before the morning on which
the diary was written. Entries from 01:00 to 05:59 are correctly AM and are not flagged. Every
text-to-number conversion is checked, and an entry that cannot be read becomes missing and is flagged,
so it can never turn silently into a plausible number.

**Step 3: Interval processing (SOL, WASO, naps, exercise).** Duration strings pass through a
hierarchical decision tree that (1) excludes invalid strings (missing, empty or letters only; the
placeholder "p" is read as zero), (2) repairs the format, and (3) converts the result to total
minutes (hours × 60 + minutes). The repair depends on the shape of the string. A string already of
the form `dd:dd` is kept, except that minutes of 60 or more (up to three digits) are carried into
hours ("minute overflow") and a string whose minute field is longer than three digits goes to manual
check; when the hours are 10 or more and the minutes are 00, the two are exchanged, so "90:00" is read
as 90 minutes and not 90 hours. A string with no colon is read by digit count: four digits get a
colon after the second ("0130" becomes "01:30"), "000" becomes "00:00", two digits become "00:dd" and
one digit "00:0d"; five or more digits, and any three-digit string other than "000", go to manual
check. Strings with a misplaced colon (`d:d:dd`, `:0000`, `d:ddd`, `ddd:d`, `dddd:`, `0:dd:dd`) are
rewritten to `dd:dd`. In the SOL and WASO fields participants also type minutes and seconds, so
"10:30" can mean 10 minutes 30 seconds; a value is therefore reinterpreted as minutes and seconds
only when it would otherwise be 4 hours (240 minutes) or more, with the first part between 1 and 59
and the second below 60, and the row is marked ambiguous and flagged. An ordinary "01:30" is kept as
90 minutes. A result is also flagged for review when it is negative or above 10,000 minutes, when SOL
is above 360 minutes, WASO above 240, a nap above 720 or exercise above 360 minutes, or when a
non-empty string could not be converted. Each row keeps three records: the minute value, a review
flag and the list of corrections made.

**Step 4: Sequence correction.** Participants sometimes enter times in the wrong order, for example
bedtime and sleep onset swapped. The chronological sequence bed, sleep, awake, get-up is enforced with
a two-stage algorithm applied only to rows with all four times. Stage one resolves AM/PM and
cross-day errors: if get-up is 12 hours or more after awakening, 12 hours are subtracted from get-up,
repeatedly, until the gap is under 12 hours; if sleep onset is 12 hours or more after bedtime, the
same is done to sleep onset. Stage two corrects minor inversions: if two adjacent times (bed–sleep,
sleep–awake, awake–get-up) are in reverse order by less than 3 hours, which suggests they were typed
in the wrong fields, the two values are exchanged. Identical adjacent times (for example bedtime equal
to sleep onset) are not errors. Every automated correction is labeled with its type.

**Step 5: Record classification and review worksheets.** After Step 4, each row is classified. A row
is an *error*, and is written to the review worksheet, if at least one of the following holds: the
times are still out of order; sleep onset is more than 7 hours after bedtime (an average sleep onset
latency is not plausible at that length, so one of the two times is probably mistyped); get-up is more
than 7 hours after awakening; or the sleep period (awakening minus sleep onset) is longer than 24
hours. A row that is not an error is *atypical*, and is written to a second worksheet, if the sleep
period is shorter than 3 or longer than 15 hours, sleep onset is more than 3 hours after bedtime, or
get-up is more than 3 hours after awakening: such nights are possible but need a look. A row with
identical adjacent times is classed *equal time* and is not an error. Both worksheets carry the typed
and parsed times, the error type and blank columns for the reviewer's problem, solution, the column to
correct and the corrected value, plus four columns that record, for every row, whether it is in a
manual file, how it was resolved, when and by whom.

**Step 5.75: Second review.** Where records had already been reviewed once, a second-review checklist
is applied so that disagreements between reviewers are settled before corrections are applied. Rows
whose participant ID or day number is not a number are skipped and listed in a file (or the run
stops, as configured).

**Step 6: Human review and the manual correction system.** In the study, two members of the research
team reviewed the flagged entries together on one shared worksheet (75 flagged errors and 37
atypical records), comparing each value with all the other diary responses of the same participant to
judge the night in the context of the study. Because the review was collaborative, we report
immediate agreement (48 of 75, 64.0%, and 33 of 37, 89.2%), and not a chance-corrected statistic; the
rest were settled by discussion. The reviewers' decisions are applied only when the caller asks for
them. The system keeps four layers: the raw data at the base, which is never altered; the automated
corrections above it; separate working columns for the manual changes; and, on top, the confirmed
values. This makes every change reversible and gives a complete trail. Each instruction follows one of
four paths according to which fields are filled: an empty instruction is skipped; an instruction with
only a described solution is read as natural language; an explicit column and value is applied first;
an incomplete instruction is marked unprocessable and listed. Supported operations are AM/PM
conversion, subtracting 12 hours, setting a time, aligning the hour to a neighbouring time, swapping
two columns, and undoing an earlier correction. Records the reviewers judged "reasonable unusual" are
protected from the anomaly lists and kept in their own file. After the corrections are applied, the
corrected times are checked against the reported total sleep duration, and a difference of more than
6 minutes is flagged. Where a self-reported duration and the duration derived from the timestamps
disagree but both are individually plausible, the entry is flagged and not adjusted: in a study of
sleep and same-day affect, variability in reported sleep is the signal of interest, and normalizing
it toward consistency would remove it.

**Step 6.5: Duration corrections and metric acceptances.** Three further steps follow, in this order:
corrections to nap and exercise durations, corrections to the SOL and WASO durations, and a table of
human decisions to accept a computed value (SOL, WASO, efficiency, total sleep time) that had been
flagged. Every row that cannot be applied is listed with its reason.

**Step 7: Sleep metrics.** The metrics are computed only after all corrections. Derived sleep onset
latency is the time from bedtime to sleep onset; time in bed runs from bedtime to get-up; the sleep
period runs from sleep onset to final awakening; total sleep time (TST) is the sleep period minus
WASO; sleep efficiency is TST divided by the time between sleep onset and final awakening. A
self-reported SOL that is longer than the interval between sleep onset and final awakening, and a
self-reported WASO that is longer than the sleep period, cannot be right, so they are not used in the
calculation and the row is marked.

**Step 8: Auto-detection of remaining problems.** Four groups of flags are assigned and each row
may carry several: timestamp (sequence or range violations), duration (interval strings with a format
problem, including the two reinterpretations of Step 3, the MM:SS conversion and the swap of
"dd:00", which produce small plausible numbers and were once silent), amount (substance and amount
entries) and self-report (metric checks). The metric checks flag SOL above 120 minutes, sleep
efficiency below 0% or above 100%, and a TST to time-in-bed ratio below 0.5 or above 1.0. A severity
grade is then given: efficiency below 70%, SOL above 1 hour and WASO above 1.5 hours each count as
one flag; one flag is minor and two or more are major. These limits are lenient because they were set
on a healthy young-adult sample and are meant to catch entry errors and gross outliers, not to
diagnose insomnia.

**Step 8.5: Cross-participant check.** A participant's own history can show an error that no limit
on a single row would. For a participant with at least 3 days, the median and the median absolute
deviation (MAD; the spread is never taken as less than 1) of SOL, WASO, naps and each exercise type
are computed, and a day is flagged as a spike if all of the following hold: its value is at least 5
MADs from the participant's median; the participant's median is at least 5 minutes; the value reaches
an absolute floor (SOL 120, WASO 60, naps 360, light exercise 240, moderate 180, vigorous 120 and
strength 120 minutes); and the value is at least 4 times the median. A value above 180 minutes from a
participant whose median is under 15 minutes is also flagged, without the other conditions. A
participant who is above the floor on at least 3 days and on at least half of their days is treated
as consistently high, not as spiking, and is not flagged by either rule. The check reports and does not change records.

**Step 9 and 10: Figures and delivered data.** The pipeline draws diagnostic figures and writes two
datasets from a pre-specified column dictionary: one with all intermediate columns, so that every
change can be audited, and one with the columns needed for analysis. Each run saves the rules in
effect, a manifest with the inferred column mapping and the software version, and an integrity report
that checks the delivered table has the same rows as the input, that columns which must stay
untouched are untouched, and that no row is duplicated.

**Table 1. Thresholds in effect for the study run.** Every value can be set in the configuration
file; a run prints the list and saves it as `effective_rules.csv`.

| Step | Rule | Value | Config key or source |
|---|---|---|---|
| 2 | evening time (bed, sleep) parsed later than this is placed on the previous day | 15:00 | `timestamp_parse.R` |
| 3 | `dd:00` with dd at least this is read as `00:dd` | 10 | `interval_parse.R` |
| 3 | HH:MM read as MM:SS when it would be at least | 240 min | `interval_parse.R` |
| 3 | structural review: SOL / WASO / nap / exercise above | 360 / 240 / 720 / 360 min | `interval_parse.R` |
| 4 | gap that triggers a 12-hour flip | 12 h | `timestamp.sequence.max_gap_hours` |
| 4 | adjacent times inverted by less than this are swapped | 3 h | `normalize.swap_threshold_hours` |
| 5 | error: sleep onset after bedtime by more than | 7 h | `classification.step5.error.bed_to_sleep_max_hours` |
| 5 | error: get-up after awakening by more than | 7 h | `classification.step5.error.awake_to_getup_max_hours` |
| 5 | error: sleep period longer than | 24 h | `classification.step5.error.sleep_to_awake_max_hours` |
| 5 | atypical: sleep period shorter / longer than | 3 / 15 h | `classification.step5.unusual.sleep_to_awake_min_hours` / `_max_hours` |
| 5 | atypical: sleep onset after bedtime by more than | 3 h | `classification.step5.unusual.bed_to_sleep_max_hours` |
| 5 | atypical: get-up after awakening by more than | 3 h | `classification.step5.unusual.awake_to_getup_max_hours` |
| 6 | derived and reported durations count as a match only if they differ by less than | 6 min | `manual_corrections.R` (fixed in code; 6 min = 0.1 h; not a config key) |
| 8.5 | low-baseline override: participant median below / value above | 15 / 180 min | `cross_participant_global_check.R` |
| 8 | SOL flagged above | 120 min | `classification.metric_validation.sol.excessive_minutes` |
| 8 | efficiency flagged outside | 0 to 100% | `classification.metric_validation.se.min_valid_percent` / `.max_valid_percent` |
| 8 | TST / time-in-bed ratio flagged outside | 0.5 to 1.0 | `classification.metric_validation.tst_tib_ratio.min_ratio` / `.max_ratio` |
| 8 | severity: efficiency below / SOL above / WASO above | 70% / 1 h / 1.5 h | `classification.flag_severity.*` |
| 8.5 | participant days needed; MADs from median; multiple of median | 3; 5; 4 | `cross_participant_global_check.R` |
| 8.5 | absolute floor SOL / WASO / nap / light / moderate / vigorous / strength | 120 / 60 / 360 / 240 / 180 / 120 / 120 min | `cross_participant_global_check.R` |

### Validation 1: synthetic benchmark

*Data.* 500 simulated participants with 14 days each (7,000 rows) were generated with a fixed seed
from a model of a healthy adult. Errors were injected with logged truth: 400 per type, 5,391 rows in
14 types after eligibility, and 1,609 rows were left untouched as controls. A subset of participants
(12%) received six times the injection probability, to reproduce the clustering seen in real data.
*Outcomes.* Each injected row is scored as corrected to the true value, flagged (held for a person),
repaired wrongly or missed; "handled" means corrected to the true value or flagged. The false-alarm
rate is the share of clean rows flagged or altered, and a participant-level cluster bootstrap gives
the interval for recall. *Comparators.* No cleaning, and a naive rule that resolves midnight and swaps
any adjacent pair that is out of order. *Sensitivity.* Four seeds; a 20-point grid of the swap (1 to 5
hours) and flip (8 to 14 hours) thresholds; and a grid of four overall error rates (2, 5, 10 and 20%
of rows) by four error-type mixes (equal numbers per type; the real-world proportions in the catalog;
timestamp errors only; duration errors only), 16 cells. *Metric distortion.* Mean total sleep time,
latency and efficiency under each arm were compared with the clean data on the same rows, and again
with the flagged rows set aside.

### Validation 1b: error rates and mixes that do not come from our data

The error types and proportions in Validation 1 were chosen by us, partly from our own data, so
recall on them is not independent evidence. We added two checks. *Error rate.* The 16-cell grid of
overall error rate by mix (above) shows whether recall depends on how many errors there are: it
stayed between 98.6% and 100%, with no clean row flagged or altered in any cell. *External mix.* Two
published sources report error rates in sleep diaries: SHUTi (Shaffer et al., 2023), an online
diary in an insomnia trial, with 487 of 45,598 diaries (1.07%) corrected for date or AM/PM errors;
and RESTING (Tully et al., 2024; conference abstract only), with 3,382 diary-days, of which AM/PM
confusion accounted for 28 errors (about 0.8%) and confusing wake time with rise time for 150 (about
4.4%), the commonest error there. The abstract does not describe the confusion, but one of its post hoc flags was a rise time earlier than the wake time, so we modelled it as wake and rise times in reversed order, which the existing swap injector produces. We injected this and AM/PM errors, in the published proportions and no other type, into the synthetic data (the two studies supply only the rates; none of their data was used), at four overall rates (2, 5, 10 and 20% of rows). At 5% of rows, all 282 reversed pairs were corrected to the true value (95% CI 98.7 to 100%) and all 68 AM/PM errors were handled (40 corrected, 28 flagged); there were no wrong repairs and no clean row was altered.

*Scope of the reversed-pair result.* The 100% applies to the one reversal the benchmark injected, wake and rise times exchanged. In the study data, 140 of 2,848 nights with all four times (4.92%) have times out of order (134, or 4.71%, after setting aside 6 impossible get-up values); an exchanged wake and rise pair accounts for 9 of the 140 (6.4%). The rest are one time 12 hours away (57), bed and sleep-onset times exchanged (38), the whole night 12 hours away (14), and forms with no simple explanation. We re-ran the benchmark with the forms in these proportions (350 reversals in 7,000 rows). The pipeline corrected every exchange and every sleep-onset or rise-time shift, but only 17.5% of bed-time shifts and 5.0% of whole-night shifts, and none of the rows with wake time before bedtime or a wake time 12 hours away; overall 74.0% were flagged or corrected, with 91 wrong repairs, because this benchmark has no reviewer to catch them, and no clean row was altered (0 of 6,650). In the study data the forms the algorithm does not repair were fixed from the review worksheets.

*Stress test.* One kind of error cannot be seen by any check based on timestamps alone: the rise time typed in both fields, so that wake and rise agree. Equal times are valid, and 17.8% of awakening and get-up pairs in the study data are equal. We added this as a new opt-in error type (`awake_is_getup`; the committed benchmark is unchanged) and injected it in place of the reversed pairs: none of the 236 cases was flagged or corrected (upper 95% bound 1.6%). RESTING's flags could not have counted this form, so we do not know how often it occurs. To translate a miss into minutes, we took the observed gap between awakening and get-up in the study data after correction (median 15 minutes, mean 22.3 among pairs that differ, 18.4 over all pairs): if all confusions, as frequent as in RESTING, were of this kind and lengthened the sleep period, the missed ones would raise mean total sleep time by at most about 0.8 minutes. This is arithmetic under those three assumptions, not a measured bias. The other RESTING categories (bedtime versus lights-out, several parameters in the WASO field, typographical errors) have no counterpart in our error catalog and were not tested. Our study entered times as free text and SHUTi used a point-and-click picker, so its rate may not transfer.

### Validation 2: real study data

*Redundant channel.* For every row whose bed-to-sleep gap the pipeline changed and that has a
self-reported latency (81 rows), we compared the distance between the gap and the self-report before
and after the change. The correction step never reads the self-reported duration, so the comparison
is not circular. *Effect of the review files.* The pipeline was run with and without the reviewers'
files. *Agreement.* Immediate agreement of the two reviewers on 75 flagged errors and 37 atypical
cases, described above; because they worked on one worksheet this is agreement, not an independent
reliability estimate. *Threshold sensitivity.* The same pipeline was run over a grid of thresholds on
the real data.

### Validation 3: public datasets

Two public diary datasets not used in development were converted to the diary layout with scripts in
the repository and run with no threshold changed: 1,372 entries from 49 adults [CITE Baigutanova et
al., 2025] and 478 entries from 59 adults [CITE Didikoglu et al., 2023]. Conversion changed 24-hour or
numeric-hour times to 12-hour entries and set get-up equal to wake-up where there was no get-up field.

### Checks that need people (not yet run)

*Blind audit.* Two annotators who did not write the rules label about 350 raw entries, stratified into
flagged, changed-without-a-flag and left-alone rows, without seeing the pipeline's output; the miss
rate in left-alone rows, the precision of the flags and the annotators' agreement follow. *Typing
task.* 30 to 50 people read 40 short descriptions of a night and type them into a diary form; the true
times are known. Materials and scoring scripts are in `validation/blind_audit/` and
`validation/typing_task/`.

### Software and reproducibility

The package (R, version 1.7.2) is configured by a YAML column mapping and keeps its working objects in
a package-private environment; it does not write to the user's global environment. It is tested with
758 expectations in 290 test blocks across 48 files, including a snapshot test that compares the
delivered tables of a synthetic run with committed copies [CHECK: re-run the full suite and re-read
the counts before submission], and is checked on Linux, Windows and macOS in continuous integration
[CHECK: confirm on the release commit]. `validation/run_all.R` regenerates the benchmark tables from
fixed seeds in a temporary copy and compares each with the committed one; all 11 regenerate
identically [CHECK: re-run]. The repository is archived at Zenodo (DOI 10.5281/zenodo.23077702).

## Design principles (for the Discussion)

Four principles shaped the pipeline, and each can be checked in the code or the outputs. First, a value is
changed automatically only when a documented rule can show that it is an entry error; an unusual value that might be
a real night is held for a person and left as typed. This matters here because variability in reported sleep is
itself the signal in studies of sleep and daily affect, so a pipeline that smoothed it away would remove what the
study is about. Second, nothing is changed without a trace: the raw entry stays beside the corrected value, every
change carries its type, and the human decisions are stored with their resolution, date and reviewer. Third,
review is a loop with a stopping rule, not a one-off pass: flagged records are reviewed, the pipeline is rerun, and
a status table records which flagged records are still waiting, were reviewed but not incorporated, or are
incorporated, until none is left to review. Fourth, the limits are stated where they were found. Checks that
rely on timestamps alone cannot tell a true entry from a wrong one when the two agree, as when the rise time is
typed in both fields; in the benchmark none of 236 such cases was caught, against all 282 for the one reversed form injected (wake and rise exchanged),
and in the study data 17.8% of awakening and get-up pairs are equal. We do not claim that the pipeline finds these cases.
