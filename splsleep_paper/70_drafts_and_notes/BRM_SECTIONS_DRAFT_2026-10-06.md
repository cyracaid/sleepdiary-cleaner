# BRM paper: section drafts (2026-10-06)

Drafts of the parts the 2026-10-06 comparison with other BRM papers said were missing.
[CITE] = a reference a person must confirm or supply; [CHECK] = needs a person.
All numbers come from files in the repository (`validation/`) and are traceable.

---

## A. Related work (for the Introduction, about 220 words)

Several tools prepare ecological momentary assessment (EMA) and experience-sampling
data for analysis. The esmtools framework and package provide a step-by-step
preprocessing workflow with reporting templates, covering adherence to the sampling
design, response behaviour such as compliance and careless responding, and description
of the data [CITE Revol et al., 2024, AMPPS; CHECK exact scope against the paper].
Careless and insufficient-effort responding has its own literature, including
indicators validated by simulation and real data [CITE Meade & Craig, 2012; Curran,
2016; Goldammer et al., 2024, Behavior Research Methods] and studies of how it behaves
in EMA [CITE Ulitzsch et al., 2025, Psychological Assessment; Vogelsmeier et al., 2025,
Psychological Methods]. These address whether a respondent engaged with the survey. A
different problem arises inside a single, attentive entry: a participant who types the
wrong AM or PM, transposes two times, or writes a clock time where a duration was asked
produces a value that is wrong although the respondent was careful. We did not find a
published tool that detects and corrects such entry errors in typed diary times and
durations while recording every change [CHECK: a systematic search is needed before
this sentence is kept]. The closest precedents in this journal for the approach are
tools that detect errors automatically and are then validated against human judgment on
a sample [CITE Nuijten et al., 2016, statcheck], and preprocessing packages written to
make preprocessing transparent and reproducible [CITE Geller et al., 2020, gazeR].

---

## B. Results addition: error rate and mix (for 3.1c, about 150 words)

The share of errors handled did not depend on how common errors were or on which kinds
dominated (`prevalence_grid.csv`; four overall rates, 2, 5, 10 and 20% of 7,000 rows,
crossed with four mixes: equal numbers per type, the real-world proportions recorded in
the error catalog, timestamp errors only, duration errors only). In all 16 cells at
least 98.6% of injected errors were flagged or corrected to the true value (exact
interval lower bounds 94.9 to 99.7%), no clean row was flagged or altered, and every
flagged row carried an injected error. What changed with the mix was who does the work:
the share corrected without a person ranged from 14 to 19% when window contradictions
dominated (the real-world proportions) to 57 to 62% for timestamp errors only, and the
number of rows flagged for review rose from 8 to 151 per 1,000 entries. Review burden is
therefore a property of the error mix, not only of the error rate. Clean rows in the
benchmark are built to pass, so a precision of 1.0 is a property of the benchmark.

---

## C. Recommendations (BRM section, about 300 words)

1. **Plan for review.** Expect a fraction of entries to be flagged for a person, and
   expect it to depend on what kinds of errors your participants make. In the study
   data 7.9% of the entries with all four times (226 of 2,848) were in the review queue at the end of a run (10.8% before the
   reviewers' corrections were applied) of all submissions, which is 79 and 108 per 1,000 of the entries with all four times; in the benchmark the number ranged from 8 to
   151 per 1,000 entries depending on the mix.
2. **Treat the thresholds as reference values.** The benchmark and the study data are
   insensitive to the swap and flip thresholds over the range tested, so the defaults are
   not optimized. Re-check them on a sample of your own data; do not assume they transfer
   to clinical, shift-work or elderly samples.
3. **Audit what the pipeline leaves alone.** Detection is measured against errors we
   injected. Before relying on the result, have two people who did not write the rules
   label a stratified sample of your own raw entries and estimate the miss rate
   (`validation/blind_audit/`).
4. **Do not drop flagged rows silently.** After cleaning, the remaining bias in sleep
   metrics sat entirely in the rows left flagged; setting them aside removed it in the
   benchmark. Decide, and report, what you do with flagged rows.
5. **Keep the record.** Keep the correction files and the step ledger with the data,
   and describe the cleaning with `cleaning_report()` so a reader can see what changed.
6. **Do not use it for what it does not do.** It cannot recover information that was
   never entered, it assumes a morning diary with typed clock times, and it is not a
   substitute for study-specific quality control.

---

## D. Limitations and future directions

- The benchmark is built by us, and its errors are the ones the rules were designed
  for; the rates and mixes are varied but the error types are not new. The blind audit
  on real entries is the check that can find errors we did not anticipate; **it has not
  yet been run** on the study data.
- The real data come from one study, and the thresholds were tuned on a healthy-adult
  sample.
- The two reviewers worked on one worksheet, so their 64.0% agreement is not an
  independent reliability estimate.
- The two public datasets contain no known diary errors, so they show format
  generality only.
- The residual bias after cleaning (onset latency still 47.6 minutes above the clean
  data in the main benchmark) sits in the flagged rows and is removed only if they are
  set aside or resolved; setting aside cost 42% of the rows in the error-enriched
  benchmark and would cost far fewer in the study.
- The manual-correction instructions understand four forms ("Same day" with a time,
  "Minus 12 hours", "Plus 12 hours", a bare time); a correction that needs the previous
  calendar day cannot be expressed in them. We met this while preparing the worked
  example. Extending the instruction forms is a future change.
- Future work: a vignette typing task in which people type known schedules, giving real
  human typing errors with a known truth; other diary designs (evening diaries, the
  Consensus Sleep Diary); a downstream analysis of how cleaning choices change an
  association the study cares about.

## E. Conclusion (about 90 words)

We described a pipeline that corrects only what a documented rule can show to be an
error, sends the rest to a person and records every change. On injected errors it
flagged or corrected 98.6 to 100% across error rates and mixes without touching a clean
entry; on real study data its corrections moved the computed latency toward participants'
own reports in 80 of 81 cases; and it ran unchanged on two public datasets. Half of the
errors need a person, and what remains after cleaning is concentrated there, which tells
the user where to look. The package, tutorials and the scripts that regenerate every
benchmark table are openly available.

## F. Declarations (the BRM set)

Funding; Conflicts of interest; Ethics approval and consent (see
`BRM_DECLARATIONS_DRAFT_2026-10-06.md`); Data availability; Code availability; **Open
practices statement:** the benchmark and the validation scripts are available at
https://github.com/cyracaid/sleepdiary-cleaner (archived at Zenodo, DOI
10.5281/zenodo.23077702); the study data are not public; **neither the study nor the
analyses reported here were preregistered**; Authors' contributions (CRediT); use of AI
tools (as in the declarations draft).

---

## G. Worked example (a case walk-through, about 350 words; synthetic data, so it can
be shown in full)

Take two rows from the benchmark, which differ in how the pipeline treats them.

*An error a rule can prove.* A participant went to bed at 10:10 PM, and typed the time
they fell asleep as 10:26 AM, an AM that should be PM. Parsed as typed, the sleep time
falls 12 hours and 16 minutes after bedtime. A gap of 12 hours or more between adjacent
times is the signature of a swapped AM or PM, so the 12-hour rule moves the sleep time
back to 10:26 PM. The row is marked corrected, its correction type
(`sleep_reduce_12h_loop`) is recorded, and the entry as typed is kept beside the
corrected value. No person is involved.

*An error no rule can prove.* In another row the participant typed bedtime 11:45 PM,
sleep time 6:05 AM, awake time 11:58 PM and get-up time 6:05 AM. The sleep and awake
times appear to be in each other's fields (the person probably fell asleep at 11:58 PM
and woke at 6:05 AM), but a rule cannot be sure which entry is wrong. The row is classed
as an order error, **not changed**, and appears on the review worksheet with its typed
times, the parsed times, the error type and blank columns for the reviewer
(`problem_humanidentified`, `solution_humanidentified`, `column_to_correct`,
`correct_value`, `manually_corrected`). The reviewer fills those columns, saves the file
as the manual-correction file, and the next run applies the instruction. The worksheet
then shows, for that row, whether it is in a manual file, how it was resolved, when and
by whom.

*What this shows.* The first case is repaired without a person and the result is
verifiable; the second is held for a person because guessing would risk replacing a real
entry with a plausible wrong one. In the benchmark about half of the injected errors
were of the second kind. [CHECK: the rows come from the synthetic benchmark
(participants 50492 and 50270, rows 6887 and 3774); replace with a short fictional
record in the paper if a reader should not see benchmark ids.]

---

## H. Literature scan: protocol and pilot (supports the Introduction claim)

Claim to support: "current practice is manual or ad hoc and leaves no record of what
changed." It is not supported yet.

**Search (PubMed):** `("sleep diary" OR "daily diary" OR "ecological momentary
assessment") AND sleep AND (bedtime OR "wake time" OR "sleep onset latency")`,
2022-2026, open access, human participants, full text in English. Take the first 30
that analyze self-reported bedtime, wake time or latency collected at least daily for
at least 7 days.

**Code each paper** (CSV, one row each): reference; design and n; how the diary times
were collected (typed clock times, pickers, other); whether the paper reports any
cleaning of the times (none / exclusion only / correction); the rule stated; who
performed it; whether the number of entries changed or excluded is given; whether code
or a log is shared. Two coders; report agreement.

**Pilot, what I could do (read-only):** two open-access papers from a search were
checked (Methods section): a 2025 adolescent EMA feasibility study and a 2025
disordered-eating EMA study. Neither reports any cleaning of self-reported sleep times
(one schedules approximate times set by staff; the other uses a single 1-10 quality
item), and neither is a good fit for the claim, so this pilot says nothing yet. A first
attempt on a third paper returned no text. Reading 30 papers needs full-text access and
two coders; I did not do it. Do not write the claim as established until it is done.
