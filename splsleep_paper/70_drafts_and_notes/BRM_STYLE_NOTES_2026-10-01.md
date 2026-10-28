# What a Behavior Research Methods paper looks like (notes, 2026-10-01)

Based on one article read in full: Courtin et al., "Hierarchical Bayesian modeling
of interoceptive psychophysics", Behavior Research Methods 58:260 (2026), plus a
search of the journal's author guidance. One article is a thin sample; treat
these as patterns to check against two or three more BRM methods papers, not as
rules.

## Facts worth knowing

- Received 9 Sep 2025, accepted 8 Jul 2026, published 7 Aug 2026: about ten months
  from submission to acceptance.
- 15 pages, about 9,100 words including references and declarations.
- Abstract: unstructured, at most 250 words (this one is 195).
- BRM does not give open-materials badges because sharing is assumed: "the norm is
  that information described is freely available in an appendix or in a repository."
  A paper that describes a tool and does not share it is out of place there.
- A close comparator exists: the `esmtools` R package (preprocessing and quality
  reporting for experience-sampling / EMA data). Our draft claims we "know of no
  other R package" that does diary-aware, human-in-the-loop cleaning. That claim
  has to be checked against esmtools and stated narrowly, or a reviewer will do it.

## Structure and proportions (this article)

| Part | Words | What it does |
|---|---|---|
| Abstract | ~195 | field and why it matters, the practical problem, what we built, how we validated it, what we release, one-line implication |
| Introduction | ~900 | the field in two sentences; what is wrong with current methods; the idea; then a numbered plan |
| Methods | ~3,800 | descriptive subsections, one per component, in the order a reader would rebuild it |
| Results | ~1,150 | one subsection per validation, same order as the plan in the Introduction |
| Discussion | ~1,770 | recap in the same order; concrete practical numbers; limits; generalization; a closing paragraph |
| Declarations | ~220 | Authors' contributions, Funding, Data availability (repository link), Ethics, Open practices (preregistration statement) |

Results are short because Methods carries the detail; Discussion is longer than
Results.

## Voice and habits

- First person plural, plain verbs: "we present", "we fit", "we validate".
- The Introduction ends with an explicit plan: "First, ... Second, ... Third, ...
  Finally, we provide ..." and the Results and Discussion follow that same order.
- Each technical term is defined where it first appears, and the audience is named
  ("written with researchers without modeling expertise in mind").
- Open resources are part of the contribution, listed in the abstract and again in
  the Discussion: tutorial, app, ready-made models, scripts.
- Practical numbers are stated as a design rule ("30 trials across 20 participants
  suffice to detect ... with 80% power") rather than left as a statistic.
- Limits are stated plainly, then the paper moves on to what generalizes.
- Closing paragraph restates the result and the take-away in four or five sentences.
- Figure captions stand alone: they say what is plotted, what the line and shading
  mean, and the sample size.

## How our material maps onto it

Our current Methods text (`METHODS_SECTION_COMPLETE_WITH_ALL_STAGES_v2`) walks
through Stages 1 to 10 in pipeline order. That works as the Methods core, but a BRM
paper would wrap it like this:

1. **Introduction (~900 words).** Sleep-diary EMA is a main tool in intensive
   longitudinal research; free-text times and durations contain many kinds of entry
   error; current practice is manual or ad hoc scripts, which are not reproducible
   and leave no record; automated repair can silently change plausible values. Our
   approach: detect and correct only what is certain, route the rest to a human, log
   every change. Then the numbered plan: (1) define an error taxonomy and rules,
   (2) test them against injected errors with known truth, (3) check them on real
   study data, (4) run the pipeline on public datasets it was not built for,
   (5) release the package, tutorials and the validation scripts.
2. **Methods.** Pipeline overview; error taxonomy; detection and correction rules;
   human review and the audit trail; then the validation methods: synthetic
   benchmark, real-data checks (redundant channel, audit, co-review), external
   datasets. The ten-stage text can be condensed into the first three.
3. **Results.** In the order of the plan: benchmark, real data, external datasets.
4. **Discussion.** Recap in the same order; a practical rule (what share of rows a
   study should expect to review); limits (no independent blinded review; one study;
   external datasets contain no known errors); generalization (other diary designs).
5. **Declarations.** Data availability (study data not public; synthetic fixture and
   the seeded benchmark are), preregistration (none), authors' contributions,
   funding, and an AI-use statement.

## Before writing, check

- Two or three more BRM methods papers about data preparation or R tools, for the
  Introduction length and how they frame "existing tools". I could not retrieve
  further full texts in this session.
- The journal's current instructions for the article type, word limits and
  required statements.

## Three more BRM articles (read 2026-10-01; abstracts, section layout, declarations)

| Article | Type | Length | Submitted to accepted |
|---|---|---|---|
| Sayfoori and Cao, probabilistic framework linking signal integrity to rodent behavior (58:?, Aug 2026) | Original Manuscript | ~6,400 words, 12 pages | 7 Nov 2025 to 1 Jul 2026 (about 8 months) |
| How much habituation is enough? An R application for limits of acceptance (58:307) | Tutorial Special Collection | ~14,600 words, 26 pages | 8 Jan 2026 to 10 Aug 2026 (about 7 months) |
| Adding LLMs to the psycholinguistic norming toolbox: a practical guide (58:253) | Tutorial Special Collection | ~11,700 words, 13 pages | 17 Sep 2025 to 1 Jul 2026 (about 10 months) |

What they add to the first article:

- **Two article types appear.** "Original Manuscript" (6,000 to 9,000 words here) and
  "Tutorial Special Collection" (12,000 to 15,000 words). A methods paper about a
  tool with its validation sits between them; our material fits the Original
  Manuscript form, with the tutorial content living in the vignettes.
- **Abstracts carry numbers.** The rodent-tracking abstract states the key results
  (entropy 1.15 to 1.78 bits; sub-20 mm accuracy 63.2% to 27.7%). Ours should name
  the recall, the zero false alarms and the two external datasets rather than only
  saying the pipeline was validated.
- **An explicit link to earlier work** is stated in the Introduction ("This study
  builds directly upon our earlier work ... where we validated ..."). If the BRM
  paper builds on anything earlier of ours, say so there.
- **"To the best of our knowledge, this is the first ..."** appears, but attached to
  a specific, narrow claim. This is the safe form for our esmtools issue.
- **Declarations are consistent across all four:** Funding, Data availability, Code
  availability (or a combined "Open practices statement and code availability"),
  Ethics, Conflict of interest, and an explicit preregistration sentence ("The study
  was not preregistered"). Two of them point to an OSF project as well as a
  repository. Consider an OSF or Zenodo deposit of the benchmark and scripts.
- **Time to acceptance is 7 to 11 months in all four**, so BRM is a slow venue;
  plan the timeline around that.

## Decisions live elsewhere

Venue decision (Regular Article, not Tutorial), the fact-check corrections, and
the consolidated pre-submission priority list live in
`2026-10-05_BRM_REVIEWER_PREASSESSMENT.md` (section C). Keep this file as the
style/structure reference only.
