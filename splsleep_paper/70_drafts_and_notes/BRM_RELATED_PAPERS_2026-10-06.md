# BRM papers close to ours: what they do, what we lack (2026-10-06)

How far this can be trusted: for Goldammer et al. I read the section headings and the
design from the open full text. For statcheck and gazeR I only have what search
results and abstracts state (the journal pages redirect to a login and the PMC copy
sits behind a captcha), so the structure notes for those two are partial. I found no
Behavior Research Methods paper on cleaning or correcting typed diary times; the
closest EMA data-quality papers are in other journals. That absence is itself worth
one sentence in the Introduction, once checked by a person.

## The papers

| # | Paper | Venue | Why it is close |
|---|---|---|---|
| 1 | Goldammer, Stöckli, Annen & Schmitz-Wilhelmy (2024). A comparison of conventional and resampled personal reliability in detecting careless responding. 56(8), 8831-8851 | BRM | A data-screening indicator validated by simulation and by a real-data reanalysis |
| 2 | Nuijten, Hartgerink, van Assen, Epskamp & Wicherts (2016). The prevalence of statistical reporting errors in psychology (1985-2013). 48(4), 1205-1226 [CHECK DOI] | BRM | An automatic error detector (statcheck) validated against manual coding, plus a large application that shows how common the errors are |
| 3 | Geller, Winn, Mahr & Mirman (2020). GazeR: a package for processing gaze position and pupil size data. 52(5) | BRM | A preprocessing package paper whose motivation is transparency and reproducibility of preprocessing |
| 4 | Courtin et al. (2026). Hierarchical Bayesian modeling of interoceptive psychophysics. 58:260 | BRM | Method plus open companion repository, tutorial and app (already read in full) |
| 5 | Revol, Carlier, Lafit, Verhees, Sels & Ceulemans (2024). Preprocessing ESM data: a step-by-step framework, tutorial website, R package and reporting templates | AMPPS, not BRM | The closest tool for the same kind of data; must be cited and distinguished |

Same topic, other journals, to cite for context: Ulitzsch et al. (2025), Psychological
Assessment 37(8): how questionnaire length and sampling frequency change careless
responding in experience sampling; Vogelsmeier et al. (2025), Psychological Methods:
13 data-driven methods for careless responding on 206,318 EMA observations that gave
very different results.

## Architecture each paper shows

**Goldammer et al. 2024** (about 16,000 words, with extensive tables). Introduction,
then one section per indicator, then "Purpose of current studies and research
questions", then two studies: a simulation (general design, manipulated parameters,
summary of hypotheses, fixed parameters, measures, outcome measures and analytic
procedure, results) and a real-data reanalysis (setting, measures, outcome measures,
results); Discussion, **Recommendations**, **Limitations and future research
directions**, Conclusion. The simulation is a full factorial (36 conditions, 100
replications each). Outcomes are the area under the ROC curve and sensitivity at a 5%
false-positive rate. The real-data study is an experiment with induced conditions
(careful, random careless, opposite careless; 359 participants), so the truth is known
from the design. Declarations: not preregistered; code and data in a repository.

**statcheck paper** (from the abstract and secondary reports): a tool, validated
against manual coding (reported inter-rater reliability .76 to .89, sensitivity 85 to
100%, specificity 96 to 100%, with the caveat that it reads only results reported in
full APA style), then applied to 258,105 p-values to show how often the problem occurs
(half of the papers had an inconsistency). Others contested its validity, and the
paper's strength is that the validation is separate from the application.

**gazeR**: a package paper organized around the preprocessing steps a user performs,
motivated by inconsistent and untransparent preprocessing; open source.

## What these suggest we are missing

1. **A ground truth that did not come from us.** Goldammer uses an experiment with
   induced conditions; statcheck uses manual coding. We have injected errors (ours) and
   no independent labels. The blind audit supplies labels on real entries. A cheaper,
   complementary design: a **vignette typing task**. Give 30 to 50 people a set of
   bed, sleep and wake schedules (as clocks or short stories) and have them type the
   times into the diary form. The intended times are known, and the errors are real
   human typing errors, not ours. This is the closest analogue to Goldammer's
   induced-condition study and answers "what errors did you not think of".
2. **How common the errors are, as a headline.** statcheck's finding is the
   prevalence. We never state an error prevalence for the study data. The blind audit
   (stratum sizes and miss rate) gives a defensible estimate with an interval.
3. **A factorial simulation with a threshold-free accuracy measure.** We report
   recall per category and a flat threshold sweep. Goldammer varies the setting
   (prevalence, severity, type) and reports sensitivity at a fixed false-positive rate.
   Our output is a flag, not a score, so report sensitivity and precision across
   several error prevalences and error-type mixes (the 5% arm is the first step), and
   state the false-alarm rate (0 of 1,609).
4. **A Recommendations section.** Goldammer and the other papers give the reader
   rules to follow: what share of rows to expect to review, when to re-check
   thresholds, when not to use the pipeline. We have the numbers and have not written
   the section.
5. **A reporting template.** The closest tool (esmtools) offers reporting templates so
   authors can describe their preprocessing. Our ledger and worksheets contain the
   content; a short generated "cleaning report" paragraph per run would let a user
   state in a Methods section what was changed and by whom. Optional, and only if it
   can be built from outputs that already exist.
6. **A statement of how sleep-EMA studies report cleaning today.** statcheck shows the
   problem by measuring it in the literature. A small scan (for example 30 recent
   sleep-diary EMA papers: do they report cleaning, which rules, any audit trail) would
   support the claim that practice is manual and unrecorded; that claim is currently
   unsupported in our Introduction.
7. **Positioning against esmtools and the careless-responding literature**, with
   references, in the Introduction and in a short related-work paragraph.
8. **The same section names the BRM papers use** for the closing material:
   Recommendations; Limitations and future research; Conclusion; and the declaration
   that nothing was preregistered.
9. **A worked example inside the paper** (gazeR is built around one): we drafted the
   two-row walk-through from the synthetic data; add one real-looking flagged record
   through the review worksheet.

## Order I would do them in

1 (vignette task or blind audit), 2 (comes from the audit), 3 (extend `low_prevalence.R`
to a small grid), 4 and 8 (writing), 7 and 6 (literature work), 9, 5.
