# Weekly work log — 2026-08-14 → 2026-08-19

**Scope:** all work after the 08-14 meeting, consolidated from
`2026-08-17_work_log.md` (§1–§19).
**Repository:** `~/Documents/splsleep` (`cyracaid/sleepdiary-cleaner`), v1.4.3.
**Privacy:** this summary is **de-identified** — no real participant ids. For
id-level detail see `2026-08-17_work_log.md` §19 and the local files under
`~/Documents/splsleep_paper_work/`.
**Chinese version:** `2026-08-19_week_work_log_summary.md`.

---

## 0. The week in one sentence

Moved v1.4.x from "it runs" to "it can be submitted": completed all seven
benchmark evidence lines, ran the M1–M7 audit and the Part B silent-error sweep
on real data, fixed eight genuine CI defects, completed a second privacy purge,
finished CRAN-hygiene Phases 1–3, and in the last two days narrowed the 922 M4
window flags down to 87 records that actually need human judgment.

---

## 1. Benchmark completion (5.1–5.7 — every item the meeting left open)

| # | Item | Result |
|---|---|---|
| 5.1 | PPV curve + recall/specificity CIs | pooled recall **0.9871 [0.9847, 0.9896]** (recomputed to **0.9952 [0.9938, 0.9967]** after the closed-loop fix); control specificity 1.0; PPV = 1.0 across all π |
| 5.2 | L2 type-correct tier | swaps 0.81–1.0; field_sol 0.975; mmss 0.88; implausible 1.0; **format_no_colon 0.11 / malformed 0.07** (silent reformatting leaves no type trace); cross_participant_spike 0.27 |
| 5.3 | FAR_flag / MRR / mis-repair magnitude | FAR_flag = FAR_alter = 0/2255; pooled MRR 61/4745 = **1.29%**; magnitude median 61 min, 100% above the LoA half-width |
| 5.4 | Multiverse | OAT screened 6 dimensions → D1 (flip) + D2 (swap) survive → full factorial **3² = 9 specifications**; mean TST 7.756–7.922 h; analyzable n 6333–6692; D2 variance 44.4% > D1 10.2% |
| 5.5 | Downstream sensitivity | across the multiverse, max TST shift 8.3 min, n shift 4.2%; B1 (sleep-onset semantics) 30 min; B2 (WASO gate) 1131 records |
| 5.6 | Leave-one-out ablation | baseline recall_flag 0.565 / workload 2681 (later corrected to 3119); D2 swap off → 0.739 / 3508; D1 flip off → 0.621 / 2947; D3/D4 no effect |
| 5.7 | Control baselines | no-cleaning recall 0 (floor); naive-rule 0.6398 / FAR 0; pipeline 0.9871 / FAR 0 → **pipeline +34.7 pp** |
| 5.4a | Parameter extraction (unblocking task) | 3 h swap threshold + cross-participant constants → `config_default.yaml`; defaults = the previous literals, zero behavioural change; snapshot **13/13 bit-identical**, 254 tests pass |

**On "243 specifications":** 243 was the meeting-note upper bound assuming 4–6
dimensions would survive OAT (3⁵). It was never promised as a result. After OAT,
only D1 and D2 move downstream quantities → 3² = 9. The execution was correct;
this was a documentation-communication gap.

---

## 2. M1–M7 audit (real data, n = 13,990, report-only)

**Headline: AUTO_FIX = 0.** The golden combination (M1 ∧ M4 ∧ M5) never fires on
real data — M5 (the redundant-direction check) blocks every candidate. This
vindicates the meeting's judgment that report-only was the right first step.

| Method | Hits | Note |
|---|---|---|
| M1 order violation | 140 | bed_sleep 55 / sleep_awake 63 / awake_getup 21 / combined 1 |
| M2 clock shape | 0 | no "23:30"-style clock strings |
| M2 reinterpreted | 35 | "10:30"-style ≥4 h shapes |
| M3 self-report deviation | 0 | no deviation > 60 min |
| M4 illegal window | **922** | main finding: self-reported SOL exceeds the bed→sleep window (max 225 min) |
| M5 silent worsening | 1 | independently reproduces the boundary case disclosed in the 08-13 log ✅ |
| M6 cross-day jump | 1 | — |
| M7 uncovered note | 0 | all 14,338 notes map to known mechanisms |

Also found: **49 records** with a raw order violation that the pipeline did not
correct (falling into clean 25 / equal_time_ok 23 / error 1), whose
`needs_review_flag` is absent → B1/B4 candidates.

### Part B silent-error sweep (first systematic search for unknown-unknowns)

| Sweep | Result |
|---|---|
| B1 silent value alterations | **0** |
| B2 redundant-channel worsening | 1 (the same M5 case) |
| B3 uncovered note types | **0 / 14,338** |
| B4 blind-spot extrapolation | all 12 error-catalog categories **have guards** |

---

## 3. Closed loop: audit finding → catalog → injection → re-verification

| New category | Provenance | Recall after injection | Conclusion |
|---|---|---|---|
| `adjacent_swap_large_gap_left_clean` | observed + blind_spot | **1.0** | the injected form is detectable; the real-data instances are an equal_time_ok variant, so the audit finding still stands |
| `sol_window_contradiction` | observed + blind_spot | **0.431 → 1.0** | **blind spot closed**: added the C4 guard (SOL > bed→sleep window + 15 min tolerance) → 355/355 flagged, control FAR 0/1609 |

Pooled recall after the guard: **0.9952 [0.9938, 0.9967]**.

---

## 4. Reproducibility root cause corrected (#6, #7 closed)

An external report said ablation/multiverse were "not reproducible". The first
diagnosis — "random drift, no seed" — **was wrong and was overturned**:

- The pipeline **is deterministic**: same code, same input, three reruns produce
  bit-identical ablation workload.
- The real cause was **stale input**: the result CSVs predate the sol_window
  guard commit, and the input `.rds` (gitignored) was regenerated by a later
  commit. Stale, not random.
- Fix: new `spec_cache.R` keyed on sha256(input rds + config + normalized
  overrides), later extended with a **code fingerprint** (see §5). Any change to
  input, config or code invalidates the cache and forces a true rerun, so drift
  becomes visible rather than silent.

---

## 5. Robustness hardening (five items)

1. **spec_cache code fingerprint** (the most dangerous hole, and one I had opened
   myself): the original key omitted a pipeline-code hash, so editing code while
   config and input stayed constant would hit a stale cache entry. Now keyed
   additionally on `code_fingerprint()` = sha256(R/*.R + inst/scripts/*.R +
   installed version).
2. **Multi-seed sensitivity**: 5.1 rerun under four seeds → pooled recall
   **0.9935–0.9952** (a 0.17 pp range), FAR 0 throughout, and
   cross_participant_spike **0.886–0.907**, consistently the weakest class.
   **But the OAT verdict is seed-sensitive**: one seed leaves D1+D2 surviving,
   another leaves only D1.
3. **Real-data specification curve**: on the real n = 13,990, **no dimension
   survives** (max ΔTST 0.93 min, max Δn 0.70%) — the real data is insensitive to
   the cleaning thresholds. Important context: real-data analyzable_n is only
   1719/13990 (12.3%), so the cleaning surface is small.
4. **Upper bound on FAR**: FAR = 0 now carries a rule-of-three 95% upper bound of
   **0.186%** (0/1609), so "0" is not read as "proven zero".
5. **L3 phrasing, against misreading**: 0.486 does not mean "only half were
   repaired correctly". The actual split is CORRECT 2619 / FLAGGED 2746 (routed
   to human review) / MISREPAIRED 26. The submission figures are L1 0.9952 +
   MRR 0.0048 + corrected-or-flagged 0.9952.

### The D2 marginality decision (two-tier reporting)
- Fact: D2 (the swap threshold) sits right at the 5 min / 1% decision boundary
  and is unstable across seeds.
- Decision: the **main specification curve = robust survivors (D1-only, 3
  specifications)**, taken as the cross-seed intersection. The 9-specification
  full factorial is demoted to an appendix (`spec_curve_full.csv`), labelled
  seed-marginal and not to be cited on its own.
- Main-curve figures: D1 = 11/12/13 → mean TST 8.059 / 8.059 / 8.072 h,
  SOL 22.7 / 31.2 / 58.1 min, analyzable n 6660 / 6581 / 6327.

---

## 6. FDR (BH correction) — first item of the external critique

**Honest positioning:** the M1–M7 audit is descriptive (flag counts, no
hypothesis tests), so BH formally does not apply and the documentation says so
rather than faking it. The benchmark's 14 per-category rates *are* testable, so
BH is applied there.

Method: each category's L2 type-correct rate is tested one-sided against a fixed
0.90 target with an exact binomial, 14 tests BH-corrected, with Wilson CIs
alongside. **Three categories fall significantly below target (q < 0.05):**
cross_participant_spike 0.271 (q = 8.0e-116), adjacent_swap_awake_getup 0.81
(q = 2.9e-7), ampm_swap 0.845 (q = 1.8e-3). The remaining eleven have q ≥ 0.49.
Those three are exactly the previously known weak classes — mutually
corroborating.

---

## 7. Privacy — second purge (Phase 0b)

- **Finding:** three per-row artefacts including `cluster_bootstrap_per_row.csv`
  carried a `pid` header. Root cause: the **synthetic pid base of 1001 overlapped
  the real pid range at 8–9 values**, so an outside reader could not tell
  synthetic from real.
- **Response:** (1) a second filter-repo pass over history; (2) root-cause fix,
  `PID_BASE` 1001 → **50001** (zero overlap with the real range); (3) the three
  per-row files permanently gitignored; (4) full-chain rerun — pid is a pure
  label, so **every number is bit-identical**.
- **Hard gate:** the pre-commit hook rejects any staged path matching the
  sensitive patterns. `.gitignore` can be bypassed with `git add -f`; the hook is
  the real lock. Verified: staging an audit CSV → commit ABORTED ✓
- **Local isolation:** FileVault is on (full-disk encryption), so sensitive files
  were moved into `sensitive_local/` with chmod 700.

---

## 8. CRAN preparation Phases 1–3, and CI

### CI: eight consecutive failures → all green (eight real defects, not infrastructure)
1. `.Rprofile` unconditionally sources `renv/activate.R`, but `renv/` was
   gitignored → every R step crashed on checkout
2. `\u00d7` in an Rd file → checkRd unknown-macro ERROR
3. tests used `withr::` without declaring it in Suggests
4. 5.4a's new parameter was not synced to the Rd → codoc mismatch
5. hand-written aggregate Rd pages: duplicated aliases + `library()` calls in
   package code + non-ASCII symbols
6. smoke-legacy hung inside the `--as-cran` build-tree copy → CI downgraded to a
   plain check
7. a global `*.rds` gitignore swallowed the `inst/extdata` test fixture → added a
   `!` exception
8. removing in-function `library()` calls broke a verify script that relied on
   that attach

**Lessons:** an all-red CI is not automatically an infrastructure problem; a
global `*.rds` ignore will swallow package data; removing in-function `library()`
calls requires updating every caller.

### Phase 1 (structure)
- Deleted `run.sh` (zero references repo-wide); moved two root-only audit scripts
  into `validation/`.
- **Revised the original plan:** the 21 root/inst duplicate scripts are **kept** —
  the duplicates are the consistency mechanism that the pre-commit hook and
  `test-script-copies-in-sync.R` depend on, not redundancy.

### Phase 2 (CRAN hygiene, commit 7b10fb7)
- DESCRIPTION finalized: normalized `Authors@R`, both ORCIDs, single-paragraph
  Description, `Config/testthat/edition: 3`.
- Imports audited against actual calls: dropped tidyverse/scales/stringi/purrr/
  tibble, restored corrplot/magick/reshape2 → all 15 remaining packages are
  genuinely used.
- `--as-cran` cleanup chain: NAMESPACE importFrom completion, globalVariables,
  Rd escaping, and the C-locale crash root cause (Δ/→ in a banner).
- **Key line of defence:** `.Rbuildignore` excludes the real-data artefacts, and
  the tarball was verified not to contain them.
- Status: **zero non-environmental issues** — at the CRAN submission threshold
  (the remaining 1 ERROR + 1 WARNING are purely a missing pdflatex).

### Multi-platform CI (a CRAN gate)
matrix = [ubuntu, windows, macos]. The first Windows run exposed the only real
hazard: a subprocess embedded a `C:\Users\...` backslash path into a script and
Rscript failed to parse `\U`; fixed with `normalizePath(winslash="/")`.
**R-CMD-check now succeeds on all three platforms, and pkgdown is green.**

### Phase 3 (documentation)
README consistency (9-step → 10-step, the multiverse decision, real D1-only
figures, paths, test counts 200+/16 files, dead links); EN/ZH vignettes synced;
three docs-dev files rewritten; figure count unified at 30 (14 QC + 16 research)
with `steps.yaml` as the single source of truth. Final HEAD `9c1885a`, CI green on
all three platforms.

---

## 9. External audit follow-up (08-19)

An independent read-only audit found two genuine problems, both fixed (commit
`48a38fe`):
1. a comment in `generate_clean_data.R` carried the real pid range boundaries →
   boundaries removed, n=237 retained;
2. real export filenames hardcoded in seven places → placeholders;
   `real_data_spec_curve.R` now reads the filename from config; `.gitignore`
   exact name → wildcard.

The other three 🔴 items were false positives (the vignette's "9-step" claim is
correct — the diagram includes a Step 5.5 node, so there are nine nodes).

**Decision, recorded:** two de-identified export **filenames** remain in git
history and **will not** be filter-repo'd. Rationale: the filenames carry no
participant identifier, the files were never git-tracked, and no
individually-linkable data is exposed — it is a naming trace only, while a
rewrite would change every hash and disrupt three tags, the Releases, and
collaborators' clones. **The threshold for a rewrite is the reappearance of
individually-linkable data.** The README privacy section records this decision.

---

## 10. Programmatic triage of the M4 flags: 922 → 188 → 87 (08-19)

Of the 922 M4 flags, a stratified sample attributes roughly 65% to
timestamp-completeness artefacts and 29% to rounding-level disagreement, leaving
**188 genuine mismatches**. Six screens were run over those 188, all as
reproducible scripts:

| Screen | Result |
|---|---|
| A arithmetic coherence (TIB − SOL − WASO) | **186 coherent / 0 impossible / 2 without timestamps** |
| B baseline from the participant's own unflagged days | **100 within 2× their own median / 87 above** |
| C dual interpretation (HH:MM vs MM:SS) + evidence gate | **2 determined / 4 fit but unevidenced / 81 neither reading fits** |
| D digit-roundness signature | exact-hour values 28.2% of flagged vs 3.9% elsewhere → **7.2× enrichment** |
| E cross-family corroboration | **22 corroborated / 166 M4-only** |
| F within-row format contradiction | **0 hits** (a negative result; the heuristic does not generalize) |

**Screen A matters more than what it caught:** 186 of 188 produce a perfectly
ordinary night when the value is taken at face value. These are not arithmetic
nonsense — they are long latencies inside normal nights. That is the single
strongest piece of support for the keep-rather-than-correct position, and it
directly underwrites the scope statement for the sleep×affect parent study.

**Cross-validation from Screen E:** the four rows flagged `M2_reinterpreted` are
exactly the four identified by reading `process_interval.R` L480-496 by hand —
two independent routes to the same conclusion.

**Final disposition (91 participants hold the 188 days):** 9 already decided /
1 provenance anomaly / 2 with a determined correction / 15 priority review /
89 kept as genuine variability / 72 ambiguous.
→ **62 participants, 90 days need eyes** (87 open judgments + 3 confirmations);
**29 participants, 53 days need nothing**; within the ambiguous group 10
participants account for 27 days and can be judged as a pattern → realistically
60–70 decisions.

---

## 11. The MM:SS 240-minute threshold blind spot — finding and design decision

The reinterpretation rule in `process_interval.R` is **row-local**: it switches to
an MM:SS reading only when the HH:MM reading reaches 240 min. Row-local means
deterministic, order-independent and easily tested — which is exactly why the
pipeline is built this way — but it cannot see a participant whose MM:SS entries
happen to fall below 240.

**Motivating case:** one participant has three entries that exceed 240 min under
the HH:MM reading and were therefore **already reinterpreted by the pipeline** —
so their MM:SS habit is established by their own data. Two further entries sit
just under the threshold and are still carried as 180 and 225 minutes.

### The measured cost of each option

| Option | Measured | Verdict |
|---|---|---|
| 1. Lower the threshold | 240 is already near the plausible ceiling for a real SOL, and the flagged set contains genuine 120/180-minute latencies | **Rejected** — unbounded cost in the worst direction |
| 2. Row-local arithmetic impossibility | only **2** of 2,848 evaluable nights are currently impossible, and it **misses the motivating case** (180 min inside a 595-minute night is entirely possible) | **Ineffective** — and it proves that **no row-local rule can solve this** |
| 3. Naive participant-level (≥1 confirmed entry ⇒ convert all) | **blast radius 428 entries** (328 SOL / 100 WASO), of which **47 currently ≥60 min** would be crushed to 1–3 min | **Rejected** — destroys 47 plausible values to recover 6 |
| 4. Strict participant-level, AUDIT-only | ≥2 confirmed entries + non-zero hour digit + two-sided scale gate → **6 entries / 3 participants** dataset-wide | **Adopted** — a **71× reduction** versus the naive rule |

Sensitivity: requiring ≥1 confirmed entry yields 21; ≥2 yields 6; ≥3 yields 2.
**≥2 is the knee.**

### Why AUDIT-only (protecting the architecture)

A participant-level rule is **dataset-dependent**: the same row can be read
differently depending on which other rows are present. That breaks the
row-independence on which the test suite, the synthetic-injection benchmark and
the reproducibility argument all rest. As an audit-only detector the hazard is
contained: **no computed value changes → no validation number moves → no
benchmark rerun is needed → v1.4.x behaviour is preserved bit-for-bit.** The
mechanism already exists in the three-tier design (AUTO_FIX → FLAG → AUDIT-only),
and there is precedent — `cross_participant_spike` is audit-only for a
structurally similar reason.

**Audit-only does not mean the data goes unfixed.** Those six entries are
corrected through the existing human-review CSV channel, with provenance and
attribution to a human decision — which is precisely the paper's central claim,
that cleaning decisions are analysis decisions and should be explicit and
auditable. What stays out of the automatic path is the **code rule**, not the
**data correction**.

---

## 12. Self-corrections logged this week (so later work does not cite wrong figures)

| # | Error | Correction |
|---|---|---|
| 1 | "ablation/multiverse not reproducible = random drift" | the pipeline is deterministic; the real cause was **stale input** (§4) |
| 2 | multiverse "243 specifications" | actually **3² = 9**; 243 was a pre-OAT upper bound, never promised (§1) |
| 3 | the `time_bed`/`time_sleep` AM/PM fields read as literal 24-hour clock | they are coded `l`/`C`; empirically **l→PM, C→AM** (median TIB 8.67 h, 96.9% within 4–13 h). The two "arithmetically impossible" rows this produced are **retracted**; the corrected count is 0 |
| 4 | "7" of the 188 already humanly reviewed | the exact join gives **9** |
| 5 | human queue estimated at "20–30 rows" | that double-counted the overlap between screens; **87 is the honest figure** |
| 6 | the phrasing of FAR = 0 | narrowed to "zero mis-repairs on constructed-clean rows", with a rule-of-three upper bound of 0.186% |
| 7 | L3 0.486 read as "only half repaired correctly" | actually CORRECT 2619 / FLAGGED 2746 / MISREPAIRED 26 |

---

---

## 14. Late-week additions (2026-08-19, after the sections above were written)

### 14.1 Dataset structure: 13,990 is not the diary count

Counting the export directly settled a long-standing ambiguity — and turned up a
second error nobody had caught:

| quantity | value |
|---|---|
| rows in the export | 13,990 |
| rows carrying a morning sleep-diary timestamp | **2,860** |
| distinct participants | **237** |
| distinct participant x study-day combinations | 3,305 |
| participant-days with more than one diary row | **0** (exactly one per day) |
| diary days per participant | median 13, range 1-15 |
| diary coverage | 2,860 / 3,305 = **86.5%** |

The older methods drafts said "13,990 sleep diary records from approximately
10,000 participants". **Both halves are wrong.** There are 237 participants, not
~10,000; and 13,990 is the whole EMA export (evening and momentary prompts
included) — only 2,860 rows are sleep diaries, so calling all 13,990 "sleep
diaries" overstates the diary dataset roughly five-fold.

Independent corroboration: 2,860 / 13,990 = 20.4%, matching exactly the "20.4% of
n = 13,990 has non-missing self-reported SOL" figure recorded in the Channel B
analysis on 08-12 by a different route.

**No repository text needs changing.** Every "n = 13,990" in the README and
vignettes refers to the number of rows the pipeline processes, which is correct.
Only manuscript sentences calling those rows *sleep diaries* are wrong. The
nearest thing to "10,000" anywhere in the project is the synthetic
false-correction-rate benchmark, which runs at n = 10,000 — a plausible route for
a benchmark figure to have migrated into a dataset description.

### 14.2 Cluster bootstrap: implementation did not match its description

Writing up the bootstrap rationale surfaced a defect in the main evidence line.
`ppv_cluster_ci.R` documents "resample pids WITH replacement" but selected rows
with `df[df$pid %in% idx, ]`. `%in%` is set membership, so a participant drawn
twice still contributes its rows once. Each resample was therefore a random ~63%
subsample of participants counted once each — subsampling, not a bootstrap.

Verified against the real per-row data, both implementations at B = 2,000 x 5
seeds:

| implementation | pooled recall 95% CI |
|---|---|
| correct cluster bootstrap (multiplicity preserved) | [0.9932, 0.9970] |
| the shipped `%in%` code | **[0.9938, 0.9967]** |
| the published figure | **[0.9938, 0.9967]** — matches exactly |

The point estimate (0.9952) is unaffected; specificity is 1.0 with zero variance
and is unaffected; the PPV curve is unaffected. Only the interval is affected, and
only by being ~21% too narrow. Rounded to three decimals the published
[0.994, 0.997] becomes **[0.993, 0.997]** — the lower bound moves one place in the
third decimal, the upper bound does not move.

**Fixed** in all three affected places (pooled, per-category, PPV band) by
pre-aggregating to per-participant counts and indexing those by the drawn names,
which preserves multiplicity. Awaiting a local re-run in R to confirm; eight
citations in the README and vignettes will need the three-decimal update.

### 14.3 n_boot sensitivity (closes a pre-writing to-do)

B in {250, 500, 1,000, 2,000, 5,000, 10,000}, five independent seeds each.
Endpoints stabilize by B = 1,000; at the B = 2,000 in use they vary across seeds
by at most 2.4e-4, an order of magnitude below the interval half-width (1.9e-3).
The Monte-Carlo component is negligible relative to between-participant sampling
variability.

### 14.4 Submission order, revised again

**CRAN listing first, then Behavior Research Methods, then JOSS.** JOSS does not
require CRAN (verified against its submission documentation — archiving happens
after review passes), so CRAN is not an external constraint here; it is a
deliberate choice to have the package listed before the methods paper goes out.

CRAN status: the LICENSE holder, `VignetteBuilder`, the knitr/rmarkdown Suggests
and `cran-comments.md` are all now in place. One conflict was found and fixed —
`VignetteBuilder: knitr` was declared while `vignettes/` was excluded from the
build in `.Rbuildignore` (since the initial commit), which would leave the tarball
declaring a vignette builder with no vignettes. The vignettes are prose-only
(92 KB, one `include = FALSE` chunk and one `eval = FALSE` chunk each), so the
cheap fix is to ship them; `^vignettes$` was removed. `cran-comments.md` was
rewritten because it claimed 0 notes, which a new submission essentially never
achieves. Remaining: a local build/check pass, win-builder and rhub.

Also retracted: `Config/roxygen2/version` is *not* suspicious. roxygen2 8.0.0
(May 2026) introduced the `Config/roxygen2/` namespace to replace `RoxygenNote`,
so the field name and the 8.x version are both current and correct.

---

## 13. Open items and next steps

**Submission order (decided 08-19):** **Behavior Research Methods first, JOSS
after.** This supersedes the §13 decision ("JOSS first"), which is now void.

Checking the original dependency chain turned up a factual error: §13 stated that
"JOSS requires the software to be archived (CRAN + Zenodo DOI)". JOSS's own
submission documentation says archiving happens **after** review — "Upon
successful completion of the review, authors will make a tagged release of the
software, and deposit a copy of the repository with a data-archiving service such
as Zenodo or figshare, get a DOI for the archive" — and **CRAN is never mentioned
as a JOSS requirement**. The "CRAN → JOSS" dependency does not hold, so **CRAN is
now an independent track that blocks neither paper**.

JOSS policy is favourable here: it explicitly anticipates the pairing
("Sometimes authors prepare a JOSS publication alongside a contribution
describing … methods assessment"), so BRM (methods assessment) plus JOSS (the
software itself) is a recognized combination, not duplicate publication.
**One hard obligation:** a JOSS submission must declare the status of related
publications (published, in review, or nearing submission).

New chain: BRM (needs a frozen, citable version — a tag; **CRAN listing not
required**) → JOSS (declare the BRM status at submission; tagged release and
Zenodo DOI only after review passes); CRAN proceeds in parallel. The manuscript
of record is `BRM_METHODS_SKELETON.md`; the short JOSS draft under
`sensitive_local/paper/` drops to the later track.

**Remaining for CRAN:** `VignetteBuilder: knitr` plus knitr/rmarkdown are not in
Suggests (ten vignettes declare the `knitr::rmarkdown` engine); the LICENSE
COPYRIGHT HOLDER does not match the DESCRIPTION author (awaiting the real legal
name); there is no `cran-comments.md`; win-builder and rhub have not been run;
`Config/roxygen2/version` needs checking.

**Manuscript gap:** grepping README, the vignettes and the skeleton for
"mood / affect / emotion / purpose / individual variability / over-correct"
returns **zero hits** — the study-purpose framing for *why* the pipeline flags
conservatively rather than normalizing disagreements away has never been written
down anywhere. A Study-scope section has been added to
`BRM_METHODS_SKELETON.md` (a manuscript version and a short README version);
the README itself is unchanged pending a decision on placement. Still outstanding
for BRM: the bootstrap rationale (participant-level clustering + n_boot
sensitivity), the "snapshot 13/13" definition in the Reproducibility section, and
placement of the Study-scope statement.

**Review queue:** 15 priority-1 plus 72 priority-2 records to work through
(already ordered); one provenance anomaly to chase; the email to Maia has been
rewritten as an ordered instruction sequence and is ready to send.
