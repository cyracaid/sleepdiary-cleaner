# Methods (short form, sleep-research journal), v4 DRAFT 2026-10-29

**Data.** The study collected morning sleep diaries as part of an ecological momentary assessment
protocol: 13,990 submissions (rows) from 237 participants over up to 15 days, of which 2,848 rows
had all four diary times (bedtime, sleep onset, final awakening, getting up). Times and durations were
typed as free text.

**Cleaning pipeline.** Data were cleaned with sleepcleanr (R package, version 1.7.2), a structured,
auditable pipeline. A value is changed automatically only when a documented rule can show that it is
a data-entry error; anything that needs a judgment about whether an unusual value is a mistake or a
real night goes to a worksheet for a person and is not altered, so that unusual signals relevant to affect research are not cleaned away as noise.
The entry as typed is kept beside every corrected value, and every change, automatic or manual, carries
its type. Our principle is that data still needing a person's judgment after the automated cleaning go
through rounds of human review until the queue is empty, while figures and the validation system guard
against silent repair, wrong repair and missed errors. The pipeline runs in the order below. *Timestamps and durations.* Text times were
rebuilt from their hour-minute and AM/PM fields; an evening time (bedtime, sleep onset) later than
15:00 was assigned to the previous calendar day. Duration strings (sleep onset latency, SOL; wake
after sleep onset, WASO) passed through a decision tree that excluded invalid strings, repaired the
format (a missing or misplaced colon, "90:00" read as 90 minutes) and converted the result to
minutes. A value such as "10:30" in these fields can mean 10 minutes 30 seconds, so it was
reinterpreted as minutes and seconds, and flagged, only when it would otherwise be 4 hours or more;
"01:30" stayed 90 minutes. Every text-to-number conversion was checked, and an unreadable entry was
flagged and not turned into a number. *Sequence.* Times were put in the order bed, sleep, awake,
get-up for rows with all four: when two adjacent times were 12 hours or more apart, 12 hours were
subtracted from the later one (an AM/PM error), and when two adjacent times were inverted by less than
3 hours they were exchanged. Identical adjacent times were not errors. *Classification.* A row was an
error, and went to review, if the order was still wrong, sleep onset was more than 7 hours after
bedtime, get-up was more than 7 hours after awakening, or the sleep period exceeded 24 hours. It was
atypical, and also went to review, if the sleep period was under 3 or over 15 hours, or sleep onset or
get-up came more than 3 hours after bedtime or awakening respectively. *Metrics.* Total sleep time
(sleep period minus WASO), efficiency and the other measures were computed only after all corrections,
and later checks flagged SOL above 120 minutes, efficiency outside 0 to 100%, a sleep-to-time-in-bed
ratio outside 0.5 to 1.0, and, for participants with at least 3 days, a day at least 5 median absolute
deviations and at least 4 times above the participant's own median.

**Human review.** Two members of the research team reviewed the flagged entries together on one shared
worksheet (75 flagged errors, 37 atypical records), comparing each value with all other diary entries
of the same participant. Because the review was collaborative, we report immediate agreement (48 of 75,
64.0%; 33 of 37, 89.2%), not a chance-corrected statistic; the rest were settled by discussion. Each
decision is stored with its resolution, date and reviewer. Review files are applied only when
requested, and corrected times were checked against reported total sleep duration, flagging
differences over 6 minutes. A self-reported duration that disagreed with the timestamp-derived interval
but was plausible was flagged, not adjusted, because variability in reported sleep is the signal of
interest in studies of sleep and daily affect.

**After review.** Once corrections are applied and metrics computed, the final data are checked again
(step 8): four groups of flags (timestamp, duration, amount, self-report) are assigned, with a severity
grade (efficiency below 70%, SOL above 1 hour and WASO above 1.5 hours each count as one flag; one is
minor, two or more major). A cross-participant check follows (step 8.5), because a participant's own
history can show an error that no single-row limit would. For participants with at least 3 days, a day
is flagged as a spike if its value is at least 5 median absolute deviations (MAD, never taken as less
than 1) from the participant's median, the median is at least 5 minutes, the value reaches an absolute
floor (SOL 120, WASO 60, naps 360 minutes, exercise 120 to 240 minutes by type) and it is at least 4
times the median; a value above 180 minutes from a participant whose median is under 15 minutes is also
flagged. A participant above the floor on at least 3 days and on at least half of their days is treated
as consistently high and is not flagged. This check reports and never changes data. Each run also writes
a review-status table that places every flagged record as needs review, reviewed but not incorporated,
or incorporated, with the reason, so what remains to be looked at can be read directly. Review, rerun
and reading the table repeat until nothing needs review; the study run ended with 100 of 100 incorporated
and none needing review. To keep silent errors from slipping through, a separate 188-row audit had a
person judge each plausible-looking SOL and WASO value (keep, keep and flag, corrected by hand, set
missing). The audit ledger only records these decisions and does not change values; it is summarized in
one column, `audit_disposition`, in the dataset with before and after values, and the analysis dataset
is left unchanged. Two datasets are delivered: one for analysis and one for checking every change (the
four times before and after, the change type and the audit disposition).

**Validation.** *Synthetic benchmark.* 500 simulated participants with 14 days each (7,000 rows) were
generated with a fixed seed; 5,391 errors in 14 types were injected with logged truth and 1,609 rows
were left clean. Of the injected errors, 99.5% were flagged or corrected to the true value (48.6%
corrected, 50.9% flagged, 0.5% repaired wrongly), and none of the clean rows was flagged or altered
(upper 95% bound 0.19%); clean rows are built to pass, so this is a property of the benchmark. One
type matters for any diary pipeline: a clock time typed into a duration field (for example "11:30" in
the SOL field) was silently turned into a plausible duration in about 96% of cases before a targeted
fix and in none afterwards; those cases now go to review. *Independent error rates.* The error types above were chosen by us, partly from our own data, so recall on them is not independent evidence. Across overall error rates of 2% to 20% of rows, recall stayed between 98.6% and 100% and no clean row was flagged or changed. Only two error types have a published rate in sleep diaries: an AM/PM or date error in 1.07% of 45,598 diaries in an online insomnia trial (SHUTi), and in about 0.8% of 3,382 diary-days in a second trial (RESTING, conference abstract). The second also reports confusing wake time with rise time as its commonest error (about 4.4% of diary-days). Its flagging rules included a rise time earlier than the wake time, so we modelled it as a reversed pair. At 5% of rows, with only these two types injected into the synthetic data in the proportions the two studies report, all 282 reversed pairs were corrected to the true value (95% CI 98.7 to 100%) and all AM/PM errors were handled (68 of 68; 40 corrected, 28 flagged); nothing was repaired wrongly and no clean row was altered. The 100% applies only to that form (wake and rise exchanged), 9 of the 140 out-of-order nights (4.92% of 2,848) in the study data. With all forms in the study proportions, the pipeline flagged or corrected 74.0% of 350 injected reversals (all exchanges and sleep-onset or rise-time shifts; 17.5% of bed-time and 5.0% of whole-night shifts; none of wake-before-bed), with 91 wrong repairs and no clean row altered (0 of 6,650); in the study data the rest were fixed from the review worksheets. As a stress test we also typed the rise time into both fields, which no timestamp check can see because equal times are valid (17.8% of pairs in the study data): none of 236 such cases was flagged or corrected (upper 95% bound 1.6%). RESTING's rules could not have counted this form, so its frequency is unknown; were every confusion of this kind and lengthening the sleep period, the missed ones would raise mean total sleep time by at most about 0.8 minutes. Entries typed by real participants with known truth (a typing task) have not yet been run. *Real study data.* For the 81 rows where the
correction changed the bed-to-sleep gap and the participant also reported a latency, the corrected gap
was closer to the self-report in 80 (98.8%); the correction never reads the self-reported duration, so
the comparison is not circular. The review queue at the end of the study run was 226 of 2,848 rows
(7.9%) with the review files applied and 307 without. *Public data.* The pipeline ran with no
threshold changed on two public diary datasets (49 adults, 1,372 entries; 59 adults, 478 entries),
which contain no known errors, so this shows that other formats are accepted, not how well errors are
found. The thresholds are reference values set on a healthy young-adult sample: over a 20-point grid of
the swap (1 to 5 hours) and flip (8 to 14 hours) limits, recall stayed between 99.50% and 99.57% with
no false alarms, and on the study data no threshold changed mean total sleep time by more than 0.93
minutes.

**Availability.** The package, vignettes and the scripts that regenerate every benchmark table from
fixed seeds are open source (Zenodo DOI 10.5281/zenodo.23077702). The participant data are not public;
a synthetic fixture that runs the full pipeline is bundled.
