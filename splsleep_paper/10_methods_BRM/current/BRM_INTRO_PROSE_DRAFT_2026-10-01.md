# BRM paper: Introduction (prose draft, 2026-10-01)

Working title: *sleepcleanr: a reproducible, auditable pipeline for cleaning
self-reported sleep-diary data from ecological momentary assessment*

[CITE] marks a reference a person must supply. [CHECK] marks a statement that
needs a source or a decision. Nothing here has been shown to the co-author.

---

Sleep diaries collected through ecological momentary assessment (EMA) allow
researchers to follow a person's sleep from night to night and to link it to
mood, behavior and health measured in the same days [CITE]. In intensive
longitudinal designs a participant may complete a diary entry every morning for
weeks, so a study of a few hundred people can produce tens of thousands of
entries. The quantities of interest are usually simple: how long the person was
in bed, how long they took to fall asleep, how long they were awake in the night,
and how much they slept. Each of these is computed from times and durations that
the participant types.

That typing is the source of the problem. When bedtime, sleep time, wake time and
get-up time are entered as free text, entries go wrong in recognizable ways: AM and
PM are swapped; two adjacent times are transposed; a clock time such as "11:30" is
typed into a field that expects a duration in minutes; a reported time to fall
asleep is longer than the whole interval between getting into bed and falling
asleep. These errors are not rare in the study that motivated this work, and they
change the very quantities the study analyzes: a swapped AM/PM turns a night of
seven hours into one of nineteen.

Current practice for dealing with such entries is mostly manual inspection or
one-off scripts written for a single study [CHECK: cite how published sleep-EMA
studies report cleaning]. Both have the same weakness: it is rarely possible to say
afterwards which entries were changed, by which rule, and what they looked like
before. Two studies that clean their diaries differently cannot be compared, and a
reader cannot tell whether an unusual result comes from the participants or from
the cleaning. General-purpose frameworks for preprocessing experience-sampling data
exist and address compliance, missing data and reporting [CITE: Revol et al., 2023
(esmtools); CHECK scope against the paper]; the entry-level errors in typed clock
times and durations, and a record of every correction, are a narrower problem that
we address here.

Fully automatic repair carries its own risk. A rule that "fixes" every entry that
looks odd will sooner or later change a night that was unusual but real into a
plausible and wrong one, and the change will leave no trace. The risk is sharpest
for duration fields: an earlier version of our pipeline silently turned a clock
time typed into a latency field into a plausible number of minutes in about 96% of
injected cases, because the raw entry passed a plausibility check and the parsed
value was never checked again. For a study whose question is how sleep varies
within a person, quietly pulling unusual entries toward the typical would remove the
signal.

We therefore built a pipeline on a conservative principle. It corrects only what a
documented rule can show to be an error; it sends everything else to a human
reviewer instead of guessing; and it records every change against the original
entry, so that raw and corrected values stay inspectable and a correction can be
reversed. The standard sleep metrics (total sleep time, sleep-onset latency, wake
after sleep onset and sleep efficiency) are computed only after this step. The
pipeline is configured by a column mapping, so a new study can use it without
changing code.

We evaluate the pipeline in four steps. First, we define a taxonomy of entry errors
and the rules that detect and correct each one. Second, we test the rules on a
synthetic benchmark in which errors are injected into constructed diary data, so
that the truth is known, and we report detection, correction, misrepair and the
rate at which clean entries are altered. Third, we examine the pipeline on the real
study data that motivated it, using a redundant measure (the participant's own
report of how long they took to fall asleep) that the correction step never reads,
and the agreement between two human reviewers. Fourth, we run the pipeline,
without changing any threshold, on two public diary datasets it was not built for.
Finally, we release the package, the tutorials and the validation scripts, written
so that researchers who do not program can run the pipeline on their own data and
see what it changed.

We state the limits of this evaluation at the outset. The benchmark has known truth
but is built by us; the real data come from one study; the two reviewers worked on
one shared worksheet, so their agreement is not an independent reliability
estimate; and the two public datasets contain no known diary errors, so they show
that the pipeline accepts other formats, not how well it finds errors.

---

Notes for the next pass

- Length: about 780 words of text (the BRM article read had ~900), room for one more paragraph.
- The 96% figure is the pre-patch silent-misrepair rate for clock times typed in
  the latency field (95.8% for latency, 96.0% for wake after sleep onset;
  `validation/synthetic/results/detection_outcomes_v4_current.csv` and
  `VALIDATION_REPORT.md`); after the patch it is 0%. The sentence says "about 96%".
- "These errors are not rare in the study that motivated this work" needs a number
  from the study data; the v1.4.5 audit (1,048 of 13,990 entries routed to review)
  is a count of routed entries, not of errors, so I did not use it. [CHECK]
- "A swapped AM/PM turns a night of seven hours into one of nineteen" is an
  illustration of the 12-hour offset the rule targets (the median discrepancy for
  that rule is about 720 minutes), not a measured case.
- Do not name the laboratory or the study until the PI has agreed.
