# paper.md: new sections, DRAFT (2026-10-01)

Not applied to paper.md. Items marked **[BLANK]** are deliberately left open
until the people concerned have agreed; they must be filled or removed before
submission. Nothing below names the PI or the lab in a way the repo does not
already (DESCRIPTION/README name the lab and study publicly).

---

# State of the field / Research impact statement

`sleepcleanr` was developed for, and has been used to clean the diary data of,
an ongoing intensive-longitudinal home sleep study at a university
psychophysiology laboratory: 13,990 diary submissions from 237 participants,
up to 15 diary days each. The data requirements of that study (free-text clock
times with separate AM/PM fields, separate bed, fall-asleep, awake and get-up
times, duration fields in minutes) shaped the package's input schema and its
rules, and the review queue the pipeline produced was worked through by two
human reviewers.

**[BLANK: lab/study name and PI, to be added only after the PI has agreed to
be named.]**

**[BLANK: outputs. No publication, preprint, conference abstract or data
report that uses the cleaned data exists yet. When one does, state its stage
here (in preparation / submitted / published).]**

Beyond that study, the evidence that the package works rests on:

- a synthetic benchmark with known ground truth (4,736 injected errors;
  recall and silent-misrepair rates in `validation/synthetic/`);
- two public diary datasets that were not used in development (KAIST, 1,372
  rows; Manchester, 478 rows), which show that the pipeline runs end to end on
  other schemas after a short conversion script. Neither contains known diary
  errors, so these runs are feasibility checks and say nothing about detection
  accuracy (`validation/external/README.md`).

At the time of submission the package has no users outside the group that
developed it.

---

# Development history

The package builds on earlier lab scripts from 2023, written by other members
of the group, which handled likely typing mistakes in user entries and set the
overall structure and several variable names; parts of the time-variable and
duration-calculation code may still derive from them. The scoring design and
the error rules were developed by the authors from September 2025.
**[BLANK, DO NOT SUBMIT UNTIL RESOLVED: who wrote the 2023 scripts, whether
they agree to be credited (acknowledgements or authorship) and to the MIT
licence, and whether the lab has a say over releasing them. Original dated
files are held elsewhere; obtain them.]** Systematic development of the
package began in September 2025 as a local collaboration between the authors
and was not placed under public version control until July 2026. The
public repository was created in April 2026; the first public commit (15 July
2026) already contained a working v1.0.0. The public history therefore
understates the time spent on the package. **[BLANK: dated evidence of the
earlier work, if any can be found (messages, file-history, earlier backups).]**

---

# AI usage disclosure

Generative AI coding assistants (Claude Code and opencode) were used during
development of the code, tests, documentation and this paper. They were used to
draft and revise R code and tests, to write and translate documentation
(vignettes, pkgdown site, NEWS), to run reviewer-style searches of the code for
defects, and to draft text that the authors then edited.

The authors made the design decisions: the scope of the pipeline, what counts
as an error versus an unusual entry, all classification thresholds, the
human-in-the-loop review design, and the choice of validation datasets. All
manual-review decisions on the study data (which diary entries are errors and
what the corrected values are) were made by the human reviewers, not by an AI.
AI-written code was reviewed and run by the authors. Since 29 September 2026
a written project rule requires the AI assistant to propose changes to package
code as a diff and apply them only after a human has approved it; before that
date this was done by practice, not by a written rule. The pipeline itself
does not call any AI model: its outputs are produced by fixed, documented rules.

The two human reviewers are the authors (Cai Dong and Maia ten Brink).
**[Confirmed by Cai 2026-10-01. Still to confirm: whether "before that date
this was done by practice" is true of the whole period; if not, cut that
clause. Show Maia the final text.]**
