<div id="main" class="col-md-9" role="main">

# Summary

<div id="summary" class="section level1">

Self-reported sleep diaries collected through ecological momentary
assessment (EMA) are noisy at exactly the points that matter most. Clock
times are entered as free text, and that text carries AM/PM reversals,
12-hour dial habits, order swaps between adjacent events, and duration
values typed into timestamp fields (and vice versa). Existing cleaning
options sit at two unhelpful extremes. Fully automated scripts silently
“repair” plausible-looking entries. Fully manual review of every record
is intractable at diary scale: a two-week study with \~250 participants
already produces thousands of entries.

`sleepcleanr` is an R package implementing a hybrid cleaning pipeline
for morning sleep diaries. Deterministic rules with validated operating
points (a 3-hour adjacent-swap threshold and a 12-hour AM/PM flip)
correct only unambiguous ordering and format errors. Every applied
correction is recorded with its type in the output data. Everything else
— value-level disagreements between self-reported durations and
timestamp-derived intervals, atypical-but-possible patterns, ambiguous
formats — is routed to structured human-review worksheets. The pipeline
generates these worksheets itself
(`[NEW]manual_error_correction_review.csv` and
`manual_unusual_review.csv`); reviewers fill them in, and the next run
applies them. The loop converges: corrected records stop reappearing,
and the run ends when the review worksheets come back empty.

Three design commitments distinguish the pipeline. First, **no silent
repair**: a value is either left as reported or changed with a recorded
correction type — never reinterpreted without a trace. (A field-misentry
bug that silently misrepaired 96% of injected clock-in-duration-field
errors was found by the synthetic benchmark and closed; the current
benchmark reports 0% silent misrepair.) Second, **auditability**: every
run writes a per-step flag ledger covering five independent evaluation
systems across the ten-stage pipeline. Human-review files are applied
only when the caller opts in (`include_manual_corrections = TRUE`), so a
dataset can never be modified by leftover review files without the
analyst’s knowledge. Third, **threshold transparency**: shipped
thresholds are YAML-configurable references validated on our data — not
gospel. The package ships an operating-point sweep and a Bland–Altman
measurement-noise analysis showing how detection thresholds relate to
measurement noise.

</div>

<div class="section level1">

# Statement of need

Sleep-diary cleaning sits between two communities with different tools.
Sleep researchers typically clean diaries by hand in spreadsheets —
unreproducible, unscalable, and unauditable — or with bespoke scripts
that are not shared and silently alter data. General-purpose
data-cleaning frameworks know nothing of diary semantics: that bedtime
precedes sleep onset, which precedes final awakening, which precedes
get-up; that a 12-hour flip can rescue a mis-entered AM/PM; and that a
zero-length sleep period is an error while a zero-latency report is a
benign diary habit. We know of no other R package that implements
diary-aware, human-in-the-loop cleaning with per-record correction
provenance and a convergence-guaranteed review cycle, and that ships
validation of its detection thresholds against both synthetic ground
truth and independent real data.

The package was developed for a real EMA sleep study: 13,990 submissions
from 237 participants, up to 15 diary days each. It was validated on
three tiers. On synthetic ground truth (4,736 injected errors) it
reaches recall 0.995 with 0% silent misrepair. On the real study data,
controlled re-runs quantify exactly what human corrections contribute to
the final dataset. On an independent, externally published real-world
dataset \[@baigutanova2025hrv\] — 49 healthy adults’ four-week sleep
diaries (1,372 entries, 24-hour clock format, a different schema with no
separate get-up field) — the pipeline ran end-to-end without
intervention and recovered the source study’s sleep metrics (mean total
sleep time 7.55 h). This is a feasibility check on data without ground
truth: it shows that the pipeline runs unmodified and reproduces a
published metric, not how accurately it detects errors. That external
run also exposed two input-handling defects, which are fixed in the
current version. Researchers collecting longitudinal diary data with
free-text time entries — in sleep, affect, or any protocol where
participants type clock times — should find the pipeline directly
usable. Column mapping is configurable via YAML, or inferred by a
recorded, fail-loud guessing function. A data-first entry point accepts
an in-memory data frame without any config file.

</div>

<div class="section level1">

# Research impact statement

`sleepcleanr` was developed for, and has been used to clean the diary
data of, an ongoing intensive-longitudinal home sleep study at a
university psychophysiology laboratory (13,990 diary submissions, 237
participants). That study’s data requirements shaped the input schema
and the rules, and the review queue the pipeline produced was worked
through by two human reviewers, the authors.

Beyond that study, the evidence that the package works is a synthetic
benchmark with known ground truth (4,736 injected errors) and two public
diary datasets not used in development (KAIST, 1,372 entries;
Manchester, 478 entries), each run end to end after a short conversion
script. Neither public dataset contains known diary errors, so these
runs show that the pipeline runs on other schemas, not how accurately it
detects errors (`validation/external/README.md`). At the time of
submission the package has no users outside the group that developed it.

</div>

<div class="section level1">

# Development history

Systematic development of the package began in September 2025 as a local
collaboration between the authors. The repository was created in April
2026 and public commits began on 15 July 2026 with a working v1.0.0, so
the public history understates the time spent on the package.

</div>

<div class="section level1">

# AI usage disclosure

Generative AI coding assistants were used during development of the
code, tests, documentation and this paper: DeepSeek V4 Flash and V4 Pro
(used through the opencode agent) and Claude Code with Anthropic Claude
Sonnet, Opus and Haiku models, in several versions over the period.
Haiku was used mainly for documentation. No other generative AI tool was
used in any substantial way. They were used to draft and revise R code
and tests, to write and translate documentation, to search the code for
defects, and to draft text that the authors edited.

The authors made the design decisions: the scope of the pipeline, what
counts as an error versus an unusual entry, all classification
thresholds, the human-in-the-loop review design and the choice of
validation datasets. Every AI-produced change was reviewed by the
authors before it was adopted, and all manual-review decisions on the
study data (which entries are errors and what the corrected values are)
were made by the authors, not by an AI. The pipeline itself calls no AI
model: its outputs come from fixed, documented rules.

</div>

<div class="section level1">

# References

</div>

</div>
