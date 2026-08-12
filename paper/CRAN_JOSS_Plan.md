# CRAN → JOSS Publication Plan

> Created: Aug 6, 2026 | Target: Submit splsleep to CRAN, then JOSS
> **Aug 6 update:** Skill indexed on [awesomeskills.dev](https://www.awesomeskills.dev/de/skill/cyracaid-sleepdiary-cleaner) — discoverable via `npx skills add cyracaid/sleepdiary-cleaner`. CRAN submission is the next infrastructure milestone.

---

## Why This Is the Highest-ROI Next Move

### You Already Have All Pass Conditions

JOSS reviews **code quality and documentation, not novelty.** Below is what they check — and your current status:

| JOSS Requirement | You Have |
|-----------------|----------|
| Open source license | MIT ✅ |
| README with install instructions | `renv::install("cyracaid/sleepdiary-cleaner")` + Quick Start + config template + vignette-length usage guide ✅ |
| Tests | 68 tests (correction engine, classification, auto-detection, config validation) ✅ |
| Versioned releases | v1.3.9, NEWS.md, 94 commits ✅ |
| Documentation of functionality | ARCHITECTURE.md, THRESHOLDS.md, SCHEMA.md, pipeline architecture docs (EN+CN), agent skill ✅ |
| Example / quick-start workflow | Synthetic data demo in README, 5-step output validation guide, Quick Reference Card ✅ |
| Community guidelines | Config template lets any lab adapt without code ✅ |

### ROI Is Extremely High

- **JOSS paper is ~250--1000 words**, not a full manuscript. You already wrote all the content — in README, ARCHITECTURE.md, THRESHOLDS.md, and work_logs. Translating these into JOSS format is ~2--3 hours.
- **The content already exists.** Every JOSS section maps directly to something you've already documented:

| JOSS Section | Source in Your Repo |
|-------------|-------------------|
| Summary (~250 words) | README first paragraph + Non-Destructive Model section |
| Statement of Need | THRESHOLDS.md rationale + work_logs entries about real data errors you encountered |
| State of the Field | "Existing tools require manual Excel cleaning or lab-specific scripts" — this argument is embedded in every PI conversation you've had |
| Features | README Features section |
| Implementation | DESCRIPTION, R CMD CHECK log, renv.lock |
| Figures | `figures/Figure_1_Pipeline_Workflow.png` + `figures/Figure_2_Cleaning_Effect.png` |
| Acknowledgements | James Gross + Maia ten Brink, Stanford SPL |
| References | 3--5 papers (EMA methodology, sleep diary, R reproducibility) |

- **2--3 hours writing. One session at your pace.**

### Unique Signal for PhD Applications

Your current publications:
- 2 × SSCI (social psychology, co-author)
- 1 × ACL-track (NLP, first author, in revision)

JOSS adds a new category:
- **1 × independent first-author peer-reviewed software publication**

This signal **does not exist** in clinical psych PhD applicant pools. It proves you can:
1. Independently design and deliver a reusable software tool
2. Document it to a standard that passes peer review
3. Get cited by other researchers as infrastructure

### DOI Chain = Adoption Infrastructure

Once JOSS publishes `splsleep` with a DOI:
- Another lab cites it in their Methods section → Google Scholar picks it up
- A new lab searches "EMA sleep diary R" → finds the JOSS paper → installs via CRAN
- Your h-index grows with each citation — independent of your advisor's co-authorship

**Without DOI**: your pipeline is a GitHub repo with 1 star.
**With DOI**: your pipeline is a citable academic publication that can accumulate independent citations.

---

## When: CRAN First, Then JOSS

JOSS submission expects the paper to say "Available on CRAN at https://CRAN.R-project.org/package=splsleep". You *can* submit with just a GitHub link — but JOSS reviewers strongly prefer CRAN-hosted packages because:

- CRAN = installable with one line (`install.packages("splsleep")`) for anyone
- CRAN = implicit quality gate (R CMD check must pass on multiple platforms)
- CRAN = permanent, archived, versioned

**Sequence:**
1. **Submit to CRAN first.** You already have 0 ERROR 0 WARNING. CRAN review typically 1--4 weeks.
2. **While waiting for CRAN**, prepare JOSS paper and paper.bib.
3. **When CRAN accepted**, update paper with CRAN link.
4. **Submit to JOSS.** Review typically 4--8 weeks.

**Target: JOSS published before December 2026.** In time for PhD application deadlines.

---

## Phase 1: CRAN Submission（1-3 天，取决于审核速度）

### Pre-submission checklist

- [ ] `R CMD check --as-cran` produces 0 ERROR, 0 WARNING
- [ ] All `@examples` wrapped in `\dontrun{}` to avoid timeout
- [ ] `DESCRIPTION` has `Authors@R` with correct `aut`/`cre` roles
- [ ] Any `\dontrun{}` examples that write to user's home directory? → Replace with `\donttest{}` or `tempdir()`
- [ ] No `.Rproj.user` or `.Rhistory` in the package tarball (check `.Rbuildignore`)
- [ ] Version bumped to `1.4.0` for first CRAN release
- [ ] `cran_comments.md` written — explain why this package is useful, note any NOTEs, confirm no internet access needed during build

### Submission

1. Run `devtools::release()` or manual `R CMD build` + upload to https://cran.r-project.org/submit.html
2. Wait for confirmation email (usually within hours)
3. Thread starts: CRAN team may ask for fixes. Reply within the thread — don't open a new submission.
4. Typical timeline: 1-4 weeks to acceptance

### If rejected

Common reasons and what to fix:
- "Package fails on Solaris / Windows oldrel" → add `SystemRequirements` or conditional code
- "Examples running time exceeds 5 sec" → `\dontrun{}` or trim data size
- "Non-standard file in top-level directory" → `.Rbuildignore` it

---

## Phase 2: JOSS Paper Preparation（发生在 CRAN submission 之后，可以并行准备）

### File: `paper/paper.md`

JOSS paper is a short Markdown file using their template. Sections:

#### Summary (~250 words)
```
splsleep is an R package for reproducible cleaning of sleep EMA 
(ecological momentary assessment) diary data. It parses raw bedtime/
sleep/awake/get-up timestamps, detects and corrects temporal and 
duration errors through a configurable YAML-based threshold system with 
a human-in-the-loop CSV audit trail, computes standard sleep metrics 
(TST, SOL, WASO, SE), validates self-reported durations, and generates 
publication-ready diagnostic figures. The pipeline is non-destructive:
no record is ever deleted — only labels and corrected columns are added.
```

#### Statement of Need
EMA sleep diary data is notoriously prone to entry errors: AM/PM confusion, timestamp order violations, non-standard time formats, missing entries. Most labs clean this data with ad-hoc Excel workflows or single-use R scripts that lack reproducibility, audit trails, and configurable thresholds. splsleep provides a standardized, installable alternative — with schema-validated YAML config that lets any lab map its dataset without code changes.

#### State of the Field
Existing tools for sleep data processing (e.g., GGIR for actigraphy, SleepPy for consumer wearables) target accelerometer or wearable data, not self-reported diary timestamps. Diary data remains a manual-cleaning bottleneck in many EMA studies. splsleep fills a specific gap with a focus on self-reported sleep event timestamps and human-in-the-loop correction traceability.

#### Implementation
R package. MIT license. 94 commits. 68 tests. Available on CRAN and GitHub. Depends on R ≥ 4.2. Uses tidyverse, ggplot2, yaml, and renv for dependency management.

#### Figures
- `figures/Figure_1_Pipeline_Workflow.png` — pipeline flow with record counts and classification
- `figures/Figure_2_Cleaning_Effect.png` — delta lollipop plots showing correction impact on TST/SOL

#### Acknowledgements
We thank James Gross and Maia ten Brink at Stanford Psychophysiology Lab.

#### References
- Shiffman, Stone, & Hufford (2008). Ecological momentary assessment. *Annual Review of Clinical Psychology*, 4, 1–32.
- Carney et al. (2012). The consensus sleep diary. *Sleep*, 35(2), 287–302.
- Wickham (2015). *R Packages*. O'Reilly.
- Wilson et al. (2017). Good enough practices in scientific computing. *PLOS Computational Biology*, 13(6), e1005510.

### File: `paper/bibliography.bib`

Standard BibTeX for the references above. JOSS supplies their own format.

### File: `codemeta.json`

Use `codemetar::write_codemeta()` to auto-generate.

---

## Phase 3: JOSS Submission（CRAN accepted 之后）

1. Go to https://joss.theoj.org/papers/new
2. Upload `paper.md` + `bibliography.bib` + `codemeta.json`
3. Select editor area: "Scientific Software" or "Life Sciences"
4. A reviewer will be assigned within 1-2 weeks
5. Review is on: code quality, documentation completeness, install success, example reproducibility — NOT novelty
6. Typical timeline: 4-8 weeks to publication

### JOSS Requirements You Already Meet
- [x] Open source license (MIT)
- [x] README with install instructions
- [x] Tests
- [x] Versioned releases
- [x] Documentation of functionality
- [x] Example/quick-start workflow
- [ ] CRAN availability (after Phase 1)

---

## Timeline

```
Week 1-4:   Submit CRAN → wait → revise if asked → CRAN accepted
Week 4-8:   Prepare JOSS paper (can start writing in Week 1 while waiting)
Week 8:     Submit JOSS
Week 8-16:  JOSS review → acceptance → DOI published
```

**Target: JOSS published before Dec 2026.** In time for PhD applications.

---

---

## Files Created for This Plan

- **`CRAN_JOSS_Plan.md`** — This file (checklist + timeline)
- **`JOSS_paper_draft.md`** — Full JOSS paper first draft (~1,100 words, all sections)
- **`paper.bib`** — BibTeX references (Shiffman 2008, Carney 2012, Wickham 2015, Wilson 2017, Wickham 2019)

### To Do Before JOSS Submission
- [ ] Fill in ORCID
- [ ] Run `codemetar::write_codemeta(".")` from package root → commit `codemeta.json`
- [ ] Bump version to `1.4.0` in DESCRIPTION
- [ ] Write `cran_comments.md`
- [ ] Submit to CRAN
- [ ] After CRAN accepted, update JOSS paper to say "Available on CRAN at ..."
- [ ] Submit to JOSS

---

## After Publication — Adoption Pipeline

1. **Cite `splsleep` in every relevant paper from Stanford SPL** — the first citation chain
2. **Poster at SLEEP / SRS / Flux** — "Any EMA sleep study can use this"
3. **One Bluesky/X thread** — Figure 1 + config template + CRAN link
4. **Add to CRAN Task View: Psychometrics** or **ClinicalTrials** — discoverability
5. **Let other labs find it through Google Scholar alerts for "EMA sleep diary"** — after DOI exists
