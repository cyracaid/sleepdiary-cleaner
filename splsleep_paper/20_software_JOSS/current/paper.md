---
title: 'sleepcleanr: a reproducible, auditable cleaning pipeline for self-reported sleep-diary EMA data'
tags:
  - R
  - sleep research
  - ecological momentary assessment
  - data cleaning
  - reproducibility
  - human-in-the-loop
authors:
  # NOTE (2026-09-29): additional authors may be added pending agreement.
  # The list below reflects confirmed contributions only; update before
  # final submission.
  - given-names: Cai
    family-names: Dong
    affiliation: "Yonsei University"
    orcid: "https://orcid.org/0009-0001-0706-0335"
  - given-names: Maia
    family-names: ten Brink
    affiliation: "Center for Behavioral Cardiovascular Health, Department of Medicine, Columbia University Irving Medical Center"
    orcid: "https://orcid.org/0000-0001-6987-1339"
date: 29 September 2026
repository: https://github.com/cyracaid/sleepdiary-cleaner
version: 1.4.7
license: MIT
---

<!-- ===== OPEN ITEMS BEFORE SUBMISSION (internal; delete this block) =====
Do NOT push this file while these comments are here.

BLOCKERS
1. 2023 lab scripts: who wrote them, how many people touched them, are they the
   lab's or individuals' work, lab/university rule on code ownership and open
   release, agreement of the writers to be credited (acknowledgements or
   authorship) and to the MIT licence, and the original dated files (held
   elsewhere). Then: credit sentence here + Acknowledgements, revisit LICENSE
   and the author list (currently only Dong and ten Brink).
2. PI (James Gross): agreement to name the lab/study in the paper. DESCRIPTION
   and README already name the lab publicly; decide whether to keep that.
0. Venue (2026-10-01): main line is a methods article (BRM); JOSS is optional and later.
   JOSS says the repository must have been public MORE than six months with
   active development, and requires demonstrated research impact; neither holds
   yet (public since 2026-07-15, earliest about mid-Jan 2027). A related BRM
   article must be declared at JOSS submission, and the JOSS paper may not carry
   new research results. The numbers in this paper are those of the BRM text.
3. Public history: only ~2.5 months (first public commit 2026-07-15). Ask JOSS
   in a presubmission whether the earlier local development (since 2025-09,
   framework from 2023) is acceptable. Gather dated evidence of it.

STILL TO FILL
4. Outputs: none yet. Add stage (in preparation / submitted / published) when
   one exists.
5. (done) DeepSeek R1 not used; AI disclosure models are final.
6. Show Maia the AI-disclosure and research-impact text before submitting.
7. Author list comment at the top of the front matter ("additional authors may
   be added") must be resolved and removed.

DOES NOT BLOCK, BUT CHECK
8. Re-check the current JOSS author guide for required sections and word range.
9. After review: Zenodo archive and DOI.
====================================================================== -->

# Summary

Self-reported sleep diaries collected through ecological momentary assessment
(EMA) are noisy at exactly the points that matter most. Clock times are
entered as free text, and that text carries AM/PM reversals, 12-hour dial
habits, order swaps between adjacent events, and duration values typed into
timestamp fields (and vice versa). Existing cleaning options sit at two
unhelpful extremes. Fully automated scripts silently "repair"
plausible-looking entries. Fully manual review of every record is
intractable at diary scale: a two-week study with ~250 participants already
produces thousands of entries.

`sleepcleanr` is an R package implementing a hybrid cleaning pipeline for
morning sleep diaries. Deterministic rules with validated operating points
(a 3-hour adjacent-swap threshold and a 12-hour AM/PM flip) correct only
unambiguous ordering and format errors. Every applied correction is recorded
with its type in the output data. Everything else — value-level
disagreements between self-reported durations and timestamp-derived
intervals, atypical-but-possible patterns, ambiguous formats — is routed to
structured human-review worksheets. The pipeline generates these worksheets
itself (`[NEW]manual_error_correction_review.csv` and
`manual_unusual_review.csv`); reviewers fill them in, and the next run
applies them. The loop converges: corrected records stop reappearing, and
the run ends when the review worksheets come back empty.

Three design commitments distinguish the pipeline. First, **no silent
repair**: a value is either left as reported or changed with a recorded
correction type — never reinterpreted without a trace. (A field-misentry bug
that silently misrepaired 96% of injected clock-in-duration-field errors was
found by the synthetic benchmark and closed; the current benchmark reports
0% silent misrepair.) Second, **auditability**: every run writes a per-step
flag ledger covering five independent evaluation systems across the
ten-stage pipeline. Human-review files are applied only when the caller
opts in (`include_manual_corrections = TRUE`), so a dataset can never be
modified by leftover review files without the analyst's knowledge. Third,
**threshold transparency**: shipped thresholds are YAML-configurable
references validated on our data — not gospel. The package ships an
operating-point sweep and a Bland–Altman measurement-noise analysis showing
how detection thresholds relate to measurement noise.

# Statement of need

Sleep-diary cleaning sits between two communities with different tools.
Sleep researchers typically clean diaries by hand in spreadsheets —
unreproducible, unscalable, and unauditable — or with bespoke scripts that
are not shared and silently alter data. General-purpose data-cleaning
frameworks know nothing of diary semantics: that bedtime precedes sleep
onset, which precedes final awakening, which precedes get-up; that a
12-hour flip can rescue a mis-entered AM/PM; and that a zero-length sleep
period is an error while a zero-latency report is a benign diary habit. We
know of no other R package that implements diary-aware, human-in-the-loop
cleaning with per-record correction provenance and a convergence-guaranteed
review cycle, and that ships validation of its detection thresholds against
both synthetic ground truth and independent real data.

The package was developed for a real EMA sleep study: 13,990 submissions
from 237 participants, up to 15 diary days each. It was validated on three
tiers. On synthetic ground truth (4,736 injected errors) it reaches recall
0.995 with 0% silent misrepair. On the real study data, controlled re-runs
quantify exactly what human corrections contribute to the final dataset. On
an independent, externally published real-world dataset
[@baigutanova2025hrv] — 49 healthy adults' four-week sleep diaries (1,372
entries, 24-hour clock format, a different schema with no separate get-up
field) — the pipeline ran end-to-end without intervention and recovered the
source study's sleep metrics (mean total sleep time 7.55 h). This is a
feasibility check on data without ground truth: it shows that the pipeline runs
unmodified and reproduces a published metric, not how accurately it detects
errors. That external run also exposed two input-handling defects, which are fixed in the current
version. Researchers collecting longitudinal diary data with free-text time
entries — in sleep, affect, or any protocol where participants type clock
times — should find the pipeline directly usable. Column mapping is
configurable via YAML, or inferred by a recorded, fail-loud guessing
function. A data-first entry point accepts an in-memory data frame without
any config file.

# Research impact statement

`sleepcleanr` was developed for, and has been used to clean the diary data of,
an ongoing intensive-longitudinal home sleep study at a university
psychophysiology laboratory (13,990 diary submissions, 237 participants). That
study's data requirements shaped the input schema and the rules, and the review
queue the pipeline produced was worked through by two human reviewers, the
authors.

<!-- TODO (PI James Gross has NOT agreed to be named; lab/study name stays out
of this paper until he does. Note DESCRIPTION and README already name the lab
publicly.) -->
<!-- TODO (outputs): no publication, preprint, abstract or data report uses the
cleaned data yet. When one exists, add its stage here: in preparation /
submitted / published. -->

Beyond that study, the evidence that the package works is a synthetic benchmark
with known ground truth (4,736 injected errors) and two public diary datasets
not used in development (KAIST, 1,372 entries; Manchester, 478 entries), each
run end to end after a short conversion script. Neither public dataset contains
known diary errors, so these runs show that the pipeline runs on other schemas,
not how accurately it detects errors (`validation/external/README.md`). At the
time of submission the package has no users outside the group that developed
it.

# Development history

Systematic development of the package began in September 2025 as a local
collaboration between the authors. The repository was created in April 2026 and
public commits began on 15 July 2026 with a working v1.0.0, so the public
history understates the time spent on the package.

<!-- TODO (BLOCKER, do not submit until resolved): the package builds on 2023
lab scripts written by other people (user-entry typo handling, overall
structure, several variable names; possibly parts of the time-variable and
duration code). Need: who wrote them, their agreement to be credited and to the
MIT licence, the lab's position on public release, and the original dated
files. Then add a credit sentence here and in Acknowledgements, and revisit
LICENSE and the author list. -->

# AI usage disclosure

Generative AI coding assistants were used during development of the code,
tests, documentation and this paper: DeepSeek V4 Flash and V4 Pro (used through the opencode agent) and Claude
Code with Anthropic Claude Sonnet, Opus and Haiku models, in several versions
over the period. Haiku was used mainly for documentation. No other generative AI tool was used
in any substantial way.
They were used to draft and revise R
code and tests, to write and translate documentation, to search the code for
defects, and to draft text that the authors edited.

The authors made the design decisions: the scope of the pipeline, what counts
as an error versus an unusual entry, all classification thresholds, the
human-in-the-loop review design and the choice of validation datasets. Every
AI-produced change was reviewed by the authors before it was adopted, and all
manual-review decisions on the study data (which entries are errors and what
the corrected values are) were made by the authors, not by an AI.
The
pipeline itself calls no AI model: its outputs come from fixed, documented
rules.

# References