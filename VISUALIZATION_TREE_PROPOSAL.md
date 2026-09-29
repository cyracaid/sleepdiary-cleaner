<div id="main" class="col-md-9" role="main">

# Visualization Section Redesign — Proposal v2 (revised per your critique, still not implemented)

<div
id="visualization-section-redesign--proposal-v2-revised-per-your-critique-still-not-implemented"
class="section level1">

\*Drafted 2026-09-11, revised same day after your critique. Grounded in:
`inst/scripts/sleep_visualization.R`’s actual figure-generation code
(including a code-level, line-by-line read of the Fig 13 and Fig 12
blocks specifically to verify the two layout bugs before proposing fixes
— see §0), `inst/scripts/make_figure_index.R`’s current tier registry,
direct visual inspection of `figure_index.png` and 10+ individual figure
PNGs (synthetic n=280 demo run), and a direct count of unique
participants in the real dataset (`output/cleaned_data_final.csv`: **237
unique pid, 3–75 diary-days each, median 61 — &gt;20x spread**). Nothing
in this document has been implemented yet — still the “text sketch to
react to” scope.

**What changed from v1, answering your three priority questions plus the
two smaller ones — firm single answers, not open options:** 1. **Level
0’s identity**: neither “new figure” nor “Figure 1 enhancement” — it’s a
new *contact-sheet header*, not a `save_png()` output at all. See §2. 2.
**Fig 19**: committed to fold into Fig 13. No longer “drop or fold.” 3.
**Misrepair-vs-flagged number**: moved to Level 0, kept visually and
conceptually distinct from the always-0 “silently altered” tile (a
footer citation, not a tile swap). See §2 and §5. 4. **Fig 17**:
concrete criterion is now a normalized %-flagged-days metric, justified
by the 3–75 day real per-participant range — not just a legibility
re-check. See §2 1.4. 5. **§1.3 branch name**: renamed to “Correction
Impact & Error Structure.” See §2.

Plus the two code-verified bug diagnoses you asked for before any fix
approach gets asserted (§0), and the numbering-scheme coexistence answer
(§2, cross-cutting fixes).\*

<div class="section level2">

## 0. What’s actually causing the “scattered, unintuitive” feeling — found two things worse than a missing hierarchy

Before designing a new tree, it’s worth naming two concrete bugs that
would undermine *any* hierarchy until fixed, because they break the one
organizing signal a reader currently has — the figure number:

1.  **“Figure 2” is used for two different figures. FIXED (implemented,
    pushed to your Mac — not git-committed).** `sleep_visualization.R`
    printed `✓ Figure 2 completed (before/after delta)` for
    `02_Correction_Impact.png` and `✓ Figure 2 completed` again for
    `02_Distribution_Sleep_Variables.png`. Resolution, decided via
    git-blame recency (both vignette mentions of “Figure 2 — Correction
    Impact” postdate the script’s internal `COMPLETE FIGURE SUMMARY`
    hardcoded list by \~1 month, and were authored by you): **Correction
    Impact keeps “Figure 2”** (untouched — it already matched the
    vignettes/docs, which turned out to be the only place this figure is
    documented at all), **Distribution is renamed to “Figure 2B”** —
    filename `02B_Distribution_Sleep_Variables.png`, ggplot title,
    `cat()` log line, the `COMPLETE FIGURE SUMMARY` block (which was
    also missing a Correction Impact entry entirely — now added), and
    `make_figure_index.R`’s registry path, all updated together. Also
    updated: `docs-dev/README_figures_navigation.md`’s filename
    reference. Left untouched, deliberately: two dated `work_logs/*.md`
    entries — editing a historical dated report to retroactively use a
    name that didn’t exist at the time would misrepresent it, not fix
    it. `proj_splclean` had no reference to this filename to begin with.
    **Not yet render-tested — see status note below.**
2.  **“Figure 12” is used for two different figures — NOT independent,
    folds into Step 3.** Two different titles baked into the images
    themselves: `A1_Step_Flag_Ledger.png`’s own title reads *“Figure 12:
    Per-Step Flag Ledger”* (this title lives in
    `R/figure12_step_flag_table.R`, a package function — “Figure 12” is
    baked into that function’s own name, not just a display string, a
    separate smell worth knowing about but out of scope to rename here);
    `12_Pipeline_Correction_Progress.png`’s title reads *“Figure 12:
    Pipeline Correction Progress”*. Unlike the Figure 2 collision,
    **this one isn’t a standalone fix** — §2 1.1 already merges
    `12_Pipeline_Correction_Progress.png` into the Step Flag Ledger,
    which deletes the losing title outright. Fixing it standalone now
    would mean rewriting A1’s embedded title once today and likely again
    when the 1.1 merge lands (since A1’s title should probably become
    something caption-scheme-consistent like “1.1 — Step Flag Ledger”
    rather than “Figure 12” either way). Deferred to Step 3 on purpose,
    not an oversight.

Separately, **the contact sheet (`figure_index.png`) is generated from a
hand-maintained registry in `make_figure_index.R` that has drifted from
the actual figure set.** Its current registry (the `reg <- rbind(...)`
block) omits at least 8 real generated figures entirely: `11` (Flag
Co-occurrence Heatmap), `13B/13C/13D` (the gap-analysis /
detection-outcomes / threshold-noise figures added 2026-09-07), `14`
(Sleep Duration Pre-Correction), `16` (Common Error Patterns), `A1`
(Step Flag Ledger), and `P26` (Per-Participant Flag Rate — present in an
older contact sheet render but not in the registry as it stands now).
Any new tree should be generated *from* the actual figure list the
script produces, not maintained a second time by hand — see §4.

Two more rendering-level problems, found while inspecting individual
PNGs. You asked me to verify both against the actual code before
asserting a fix approach — not infer from the rendered PNG alone — so I
read the exact `sleep_visualization.R` blocks (lines \~1600–1715 for Fig
13, \~1496–1590 for Fig 12) rather than guessing. **They turn out to be
two different bugs with two different mechanisms, not the same
“patchwork heights” issue twice:**

-   **`13_Error_Category_Distribution.png` — confirmed `patchwork`
    mixed-unit layout bug, needs restructuring, not just a ratio
    tweak.** The figure is `p13_bar / severity_tab / flag_tab` composed
    with `plot_layout(heights = c(3, unit(1.5, "in"), unit(1.2, "in")))`
    — one *relative* unit (`3`) for the bar chart, two *absolute* inch
    units for the two tables. `p13_bar`‘s x-axis labels are rotated 45°
    (`element_text(angle = 45, hjust = 1)`). Patchwork allocates each
    panel’s cell height from its nominal panel geometry, not the
    rendered extent of rotated tick text — so the rotated labels’ visual
    descent overflows past the bar chart’s allocated cell straight into
    `severity_tab`’s fixed cell directly below it. Because this is
    content overflowing its cell (not a wrong ratio), retuning the
    `heights` numbers won’t reliably fix it. Real fix: give `p13_bar`
    explicit bottom margin (e.g. `plot.margin = margin(b = 20)`) and/or
    add a small explicit spacer row between panels — a genuine
    restructuring of the composition, confirmed needed, not assumed.
-   **`12_Pipeline_Correction_Progress.png` — confirmed `grid.arrange()`
    fixed-canvas mismatch, a different mechanism from Fig 13.** This
    figure does NOT use patchwork at all — it’s
    `gridExtra::grid.arrange()` with three tables sized via
    `unit(nrow(df) * 0.28 + 0.4, "in")`. `save_png()`‘s signature
    (`h = cfg_get("output.figure.height_inches", 9, cfg = pipeline_config)`)
    confirms the default 9-inch canvas height, and Fig 12’s `save_png()`
    call passes no explicit `h=` override, so it renders into that
    default 9in canvas. The three tables’ specified heights sum to
    roughly \~5.1in of actual content; `grid.arrange`’s gtable sizes
    rows to exactly their specified absolute units and does not stretch
    to fill the surrounding device viewport, so the remaining \~3.9in of
    the 9in canvas renders as blank space below the content. Confirmed
    root cause: `ggsave`’s fixed height parameter vs. `grid.arrange`’s
    fixed absolute row heights, exactly as you suspected — not a
    heights-ratio problem like Fig 13. **Practically moot either way**:
    §2 1.1 already folds this table into the Step Flag Ledger, which
    removes the standalone figure entirely; noting the confirmed
    mechanism here only in case that merge doesn’t happen this cycle.

</div>

<div class="section level2">

## 1. Your four example dimensions, checked against what’s actually in the figure catalog

You said the dimension list wasn’t exhaustive, and confirmed you’re
describing the *organizing principle* for the whole section, not a spec
for one figure. Mapping what exists today onto (and past) your four
examples:

| Your dimension                    | What currently exists                                                                                                                                                                                                            | Gaps                                                                                                                                                                                   |
|-----------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Error counts                      | `A1` ledger, `12` progress, `13` category distribution, `18` dashboard, `19` unified status, `15` timeline, `16` patterns, `11` co-occurrence — **6+ figures answering overlapping versions of “how many errors, of what kind”** | Not a gap — an oversupply, see §2                                                                                                                                                      |
| Sleep duration                    | `03`, `02B` (distribution), `05` (variability), `R26` (composition), `R27` (correlation), `08` (by category, broken)                                                                                                             | —                                                                                                                                                                                      |
| “Bed” (timing/circadian)          | `04`, `04B`, `09` (bedtime vs getup), `R25` (weekday/weekend regularity)                                                                                                                                                         | These four are currently scattered across two different top-level folders (`pipeline_cleaning` has none of them; they’re split across `research_ready` with no shared visual grouping) |
| Substance                         | `21`, `22`, `23`, `24`                                                                                                                                                                                                           | Reasonably self-contained already, easiest branch                                                                                                                                      |
| *(not in your list, but present)* | `20`/`20B` self-report-vs-measured perception bias; `10` extreme-duration outliers; `07` quality-vs-duration                                                                                                                     | These need a home in the tree too — proposed below                                                                                                                                     |

</div>

<div class="section level2">

## 2. Proposed tree

    Sleep EMA Cleaning Pipeline — Visualization Suite
    │
    ├── LEVEL 0 — Pipeline Health (NOT a new figure file — a new CONTACT-SHEET
    │   HEADER, prepended to figure_index.png itself. This is the resolved
    │   identity question: it's neither a new save_png() output nor an edit to
    │   Figure 1. Figure 1 stays exactly as-is and keeps its own place in 1.1;
    │   Level 0 just reuses Figure 1's already-rendered thumbnail inline,
    │   alongside a new stat-tile row, as the front page of the contact sheet.
    │   Because it needs no new figure-generation code — only a header block in
    │   make_figure_index.R, drawn before the Tier 1 section, populated from
    │   data the pipeline already computes (correction_status.csv etc.) — it's
    │   cheap enough to bundle into the same implementation pass as the Fig
    │   12/13/19 fixes below, which also touch make_figure_index.R.
    │     Data-source check, confirmed: `make_figure_index.R` currently does zero
    │     data reading (grepped for `read.csv`/`read_csv`/`correction_status` —
    │     no hits) — it's purely a static image-composition script today, reading
    │     nothing. So Level 0's stat tiles DO need a new summary write-out, and
    │     the right place for it is the same write as the §4 registry rebuild:
    │     after `generate_appendix_ledger()`, before `generate_figure_index()`,
    │     write one run-summary file (N records, % clean/flagged/corrected — read
    │     from `correction_status.csv`'s latest `run_id` row, which already has
    │     these columns) that both the new registry AND the Level 0 header read.
    │     One write-out, not two separate mechanisms.
    │     Content: a stat-tile row (N records · % clean · % flagged ·
    │     % auto-corrected · % silently altered [live, always reads 0 — a
    │     per-run QC canary]) + Figure 1's existing flow diagram thumbnail.
    │     PLUS one footer line beneath the stat tiles, small and citation-styled
    │     (not another tile): "Validated against synthetic error injection:
    │     0% misrepair, ~97% detection (see validation/ report)." This is the
    │     misrepair-vs-flagged number you flagged as under-placed in v1 — it's
    │     now at Level 0, immediately visible, but deliberately NOT merged into
    │     the "% silently altered" tile: that tile is LIVE (recomputed every
    │     run, expected to read 0 as a safety canary), while the misrepair
    │     number is a STATIC validated benchmark (from the synthetic-injection
    │     study; real data has no ground truth to recompute it against). A
    │     footer citation keeps both visible without implying the benchmark
    │     number is being freshly checked on every run — it isn't.
    │
    ├── LEVEL 1 — Pipeline Integrity  (branch answers: "is the cleaning trustworthy")
    │   │
    │   ├── 1.1 Process & step counts
    │   │     • Fig 1 Pipeline Flow Diagram — keep as-is
    │   │     • Step Flag Ledger (today mislabeled "Fig 12a") — keep, becomes
    │   │       the ONE per-step table (see 1.1 merge note below)
    │   │     • Pipeline Correction Progress (today mislabeled "Fig 12b") —
    │   │       MERGE into Step Flag Ledger: same question (counts per step),
    │   │       redundant as two separate tables; also fixes the dead-space
    │   │       layout bug in the Progress table by removing the duplicate
    │   │
    │   ├── 1.2 Error taxonomy — "how many errors, what kind"
    │   │     • Fig 13 Error Category Distribution — KEEP as the canonical
    │   │       answer to this question, but fix the table/chart overlap bug
    │   │     • Fig 11 Flag Co-occurrence Heatmap — keep (genuinely distinct:
    │   │       which error types happen together, not shown anywhere else)
    │   │     • DROP Fig 18 Auto-Detected Dashboard — its entire content (10
    │   │       records, 100% one category) is a strict subset of Fig 13's own
    │   │       category table, rendered far less legibly (a single-slice pie
    │   │       filling 90% of the canvas)
    │   │     • FOLD Fig 19 Unified Quality Status into Fig 13 — decided, not
    │   │       left open: same CLEAN vs DURATION_ISSUE split as Fig 13's own
    │   │       category table, just coarser. Fig 13 is already getting its
    │   │       layout restructured to fix the overlap bug (§0), so absorbing
    │   │       Fig 19's 2-bar split as a small inset/annotation in that same
    │   │       edit is low marginal cost, per your own read of it — Fig 19 as
    │   │       a standalone file is dropped once that's in place
    │   │
    │   ├── 1.3 Correction Impact & Error Structure (renamed from "Correction
    │   │   magnitude & when" — the old name didn't cover Fig 10's outlier
    │   │   detection or the merged Fig 14+06 before/after pair; this does)
    │   │     • Fig 2a Correction Impact (before/after delta) — keep
    │   │     • Fig 15 Error Timeline — keep
    │   │     • Fig 16 Common Error Patterns — keep
    │   │     • Fig 10 Extreme Sleep Duration — keep
    │   │     • MERGE Fig 14 (Pre-Correction) + Fig 06 (Post-Correction) into
    │   │       one paired before/after panel — these are already a natural
    │   │       pair, currently split into two separate figures a reader has
    │   │       to flip between
    │   │     • DROP Fig 08 Sleep Duration by Category — degenerates to a
    │   │       single violin whenever the error/unusual categories are sparse
    │   │       relative to clean data (exactly what happened in the synthetic
    │   │       run you're looking at — it rendered ONE violin, not a
    │   │       comparison). Fig 07 already answers the same question (quality
    │   │       category overlaid on the duration histogram) without breaking
    │   │       when one category is small, since it keeps N visible as bar
    │   │       height rather than needing 3 distinct box/violin shapes to look
    │   │       meaningful
    │   │
    │   └── 1.4 Who — participant-level quality (implementation note: P26's new
    │   │     %-clean-days and Fig 17's new %-flagged-days are highly likely
    │   │     correlated (%-clean ≈ 1 − %-flagged, depending on how "clean" is
    │   │     defined) — before building both as separate charts, compute the
    │   │     actual correlation on the real N=237 data during 1.4 implementation;
    │   │     if |r| is high, merge into one figure (distribution histogram +
    │   │     tail annotation of the worst participants) instead of two
    │   │     near-duplicate views. Not resolved now — no real data to check this
    │   │     against from proposal-writing time — but flagged so it's decided
    │   │     with data in hand, not by assumption either way.
    │         • REPLACE Fig P26 (one bar per participant) — confirmed this
    │           breaks past a few dozen participants: real data has 237
    │           participants, so 237 x-axis labels would need to fit where the
    │           demo currently fits 20. Replace with a distribution view: a
    │           histogram of each participant's %-clean-days (or a beeswarm/
    │           strip plot) — same question ("how uneven is quality across
    │           people"), scales to any N, and a long tail of problem
    │           participants is still visible as outlier points/bars rather
    │           than illegible text
    │         • Fig 17 Top Participants by Flag — KEEP, but the metric changes,
    │           not just a legibility re-check: switch from raw flag COUNT to
    │           %-flagged-days (flagged_days / total_days per participant).
    │           Concrete reason, not just "verify it looks ok": real
    │           participants have 3–75 diary-days each (>20x spread), so a raw
    │           flag count conflates "flagged a lot" with "observed a long
    │           time" — a participant with 75 days and a normal flag RATE could
    │           out-count one with 5 days and a terrible rate. This confound
    │           exists regardless of whether raw counts happen to differentiate
    │           nicely at N=237, so switch to the normalized metric on its own
    │           merits rather than only if the tie observed at n=20 persists.
    │           Concrete check before implementing: compute %-flagged-days per
    │           participant on the real N=237 data and confirm the distribution
    │           has real spread (not near-degenerate) — if it does, it's Fig
    │           17's new x-axis; if it's still oddly flat, that's itself a
    │           pipeline-health finding worth surfacing, not a chart problem
    │
    ├── LEVEL 2 — Research-Ready  (branch answers: "what does the cleaned data look like")
    │   │
    │   ├── 2.1 Sleep duration & composition
    │   │     • Fig 03 Sleep Duration Distribution
    │   │     • Fig 02B Distribution of Sleep Variables
    │   │     • Fig 05 Variability of Sleep Variables
    │   │     • Fig R26 Sleep Composition — TIB Breakdown
    │   │     • Fig R27 Sleep Metrics Correlation Matrix
    │   │
    │   ├── 2.2 Timing / circadian ("bed")
    │   │     • Fig 04 Sleep Duration vs Time in Bed
    │   │     • Fig 04B SOL vs Sleep Duration
    │   │     • Fig 09 Bedtime vs Getup Distribution
    │   │     • Fig R25 Sleep Regularity — Weekday vs Weekend
    │   │     (currently these four have no shared visual grouping at all —
    │   │     they're just four items among sixteen in one flat folder)
    │   │
    │   ├── 2.3 Self-report vs. measured (perception bias)
    │   │     • Fig 20 SOL Perception Bias
    │   │     • Fig 20B WASO Perception Bias
    │   │
    │   └── 2.4 Substance use
    │         • Fig 21 Substance Use Availability (coverage)
    │         • Fig 22 Substance Use Distribution
    │         • Fig 23 Caffeine Consumption
    │         • Fig 24 Alcohol Consumption
    │
    └── Fixes needed regardless of which tree you pick
          • De-collide "Figure 2" and "Figure 12" (see §0) — do this first,
            independent of everything else, since it's actively misleading
          • Fix the Fig 13 table/chart overlap and Fig 12/progress dead-space
            layout bugs — both now code-confirmed, see §0
          • Bring make_figure_index.R's registry back in sync with the actual
            figure set (§4) so this doesn't drift again
          • Numbering-scheme coexistence, decided: existing filename prefixes
            (A1, R25/R26/R27, P26) stay unchanged — renaming files means
            touching code and any downstream references, not worth it for a
            display-layer concern. The hierarchical numbers (e.g. "1.2-13",
            "1.4-P26") apply ONLY as a caption/contact-sheet prefix layer, so
            there's one numbering system a reader sees (the hierarchical one,
            in captions/headers) and the legacy prefixes persist purely as
            internal filenames — documented as "legacy identifiers, kept for
            code stability" in a comment in make_figure_index.R's registry so
            a future contributor isn't confused by why A1/R25-27/P26 don't
            follow the numeric sequence

</div>

<div class="section level2">

## 3. What to do about the three figures you flagged, concretely

| Figure                             | Your read                     | What I found                                                                                                                                                       | Recommendation                                                                                                                                                                                           |
|------------------------------------|-------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Fig 8 (Sleep Duration by Category) | not helpful                   | Confirmed structurally fragile — renders as a single violin (no comparison at all) whenever category counts are uneven, which is the common case, not an edge case | **Drop.** Fig 07 already covers this question more robustly                                                                                                                                              |
| Fig 18 (Auto-Detected Dashboard)   | maybe not helpful             | Confirmed — single-category pie filling 90% of the canvas for what’s a 2-number summary; content is a subset of Fig 13                                             | **Drop.** Nothing here Fig 13 doesn’t already show better                                                                                                                                                |
| Fig P26 (Per-Participant)          | not helpful, labels illegible | Confirmed and quantified — real data has 237 participants; the one-bar-per-participant design cannot produce legible labels at that N, this isn’t a tuning issue   | **Replace the chart type**, don’t just drop — the underlying question (“how uneven is data quality across participants”) is worth keeping, a distribution/beeswarm view scales where the bar chart can’t |

</div>

<div class="section level2">

## 4. Layout & mechanics suggestions

-   **Keep the existing tier-based contact sheet mechanism**
    (`make_figure_index.R`’s `image_append`/`magick` approach already
    works and already has a tier concept) rather than introducing a new
    rendering system — extend it to 2 levels of header (tier header,
    existing dark bar; sub-branch header, e.g. a lighter gray bar for
    “1.2 Error taxonomy”) so the nesting is visible directly in the
    contact sheet, not just in this document.
-   **Don’t try to force the whole 30-figure catalog into one
    Sankey/flowchart.** A literal flow/graph layout is the right tool
    for Figure 1 specifically (it already is a flow diagram of the
    pipeline’s actual steps) — using it as the *meta-organizer* for 30
    unrelated figures would just be a differently-shaped version of the
    same “too much in one picture” problem Fig 18 has now. Hierarchical
    grouping + a numbering scheme that reflects the hierarchy
    (e.g. `1.2-13` instead of a bare `13`) gets you the “tree” feeling
    without cramming everything into one diagram.
-   **Generate the contact-sheet registry from the actual figure
    catalog, not by hand a second time.** Concretely: have each
    `save_png()` call in `sleep_visualization.R` also append
    `(path, tier, subtier, caption)` to a running list in-memory, and
    write that list out as the registry at the end of the script,
    instead of `make_figure_index.R` hard-coding a parallel list that
    can silently drift (as it already has, twice, per §0).
-   **P26 replacement**: a histogram of per-participant %-clean-days
    (one bar per *bin*, not per *participant*) is the most direct fix
    and reuses the exact same underlying per-participant summary table
    P26 already computes — no new data pipeline needed, just a different
    geom.

</div>

<div class="section level2">

## 5. Redundancy and gaps, summarized

**Redundant (candidates to drop or merge), in order of confidence:** 1.
Fig 18 — drop (subset of Fig 13, worse presentation) 2. “Figure 12”
collision — merge into one table (§0, §2 1.1) 3. Fig 19 — **fold into
Fig 13** (decided; coarser version of the same split — no longer “likely
drop or fold,” see §2 1.2) 4. Fig 8 — drop (structurally fragile,
superseded by Fig 07) 5. Fig 14 + Fig 06 — merge into one paired
before/after figure

**Gaps** (things implied by your dimension list or by the pipeline’s own
validation work that don’t have a home in the current 30 figures): -
~~No figure currently shows the misrepair vs. flagged distinction…~~
**Resolved, moved to Level 0** — this was buried too far down in v1, as
you flagged. It’s now the footer citation on the Level 0 stat-tile row
(§2), kept deliberately distinct from the live “% silently altered” tile
rather than swapped with it, since one is a live per-run canary and the
other a static validated benchmark. This was, per your read, arguably
the single most important “is this pipeline safe” number in the whole
figure set — it shouldn’t have shipped this deep in a redundancy list,
and it doesn’t anymore. - The four “bed”/timing figures (§2.2) have no
shared visual identity today — confirming/fixing that is really a
labeling-and-grouping fix, not a new figure.

</div>

<div class="section level2">

## Status — what’s decided vs. still open

**Decided this round** (no longer open): Level 0’s identity
(contact-sheet header, not a new figure or a Fig 1 edit) and that it’s
cheap enough to bundle into the same implementation pass as the Fig
12/13/19 fixes; Fig 19 folds into Fig 13; the misrepair-vs-flagged
number’s placement and its relationship to the always-0 tile; Fig 17’s
metric (switches to %-flagged-days, not just a legibility check); the
§1.3 branch name; the numbering-scheme coexistence approach; and the
exact, code-confirmed mechanism behind both the Fig 13 and Fig 12 layout
bugs.

**Implemented this round (pushed to your Mac, no git commit made — see
§0 item 1):** the Figure 2 de-collision. Correction Impact keeps “Figure
2” unchanged; Distribution renamed to “Figure 2B” across its filename,
title, log line, the internal summary block, and the two registries
(`make_figure_index.R`, `docs-dev/README_figures_navigation.md`) that
reference it.

**Important constraint discovered this round: no R is reachable from
here** — not in this cloud sandbox, and not through the device bridge
into your Mac either (`which R Rscript` found nothing in either place; I
also checked common install locations and found no R framework, Homebrew
R, or RStudio). The Figure 2 fix above is text-only
(filenames/titles/labels), low risk, but genuinely untested by
rendering. Before I touch Fig 13’s `patchwork` layout or Fig 12’s
`grid.arrange` layout — real structural changes, not text swaps — I’d
like you to run the pipeline once on your end and confirm the Figure 2
rename didn’t break anything, so we’re not stacking untested changes.
This also matches the per-step-commit cadence you proposed: each step
verified before the next.

**Still open, your call**: whether to also do the Level 2 grouping
(§2.1–2.4, purely a contact-sheet reorganization, no bug fixes needed
there) in the same pass as Level 0/1, or defer it — it’s lower risk than
the Level 1 work since nothing in Level 2 has a known bug, just no
shared visual grouping yet. Once you confirm scope (and confirm Figure 2
still renders correctly), the next step is implementation:
`make_figure_index.R` changes (Level 0 header, 2-level tier headers,
registry regeneration, Fig 19 fold, and A1’s title rewrite — see §0 item
2) plus the two `sleep_visualization.R` fixes (Fig 13 spacer-row
restructuring — see execution-order note below, Fig 12/progress merge
into the Step Flag Ledger) and the P26/Fig 17 replacement charts.

**On your proposed execution order**: agreed, with one adjustment — Step
1 is now just the Figure 2 fix (done); the Figure 12 fix isn’t
independent, it folds into Step 3’s 1.1 merge (§0 item 2), so there’s no
separate “de-collide Figure 12” step anymore. Also: Fig 13’s fix goes
straight to a spacer row, not margin-first — a fixed
`plot.margin = margin(b = 20)` won’t reliably hold up across different
`error_category` label lengths, and Fig 13 is already being restructured
to absorb Fig 19 in the same edit, so there’s no cost saved by trying
margin first.

**Update 2026-09-17**: most of what was “still open” above is now either
done or superseded — see §6 below. In particular: Fig 8 is fully dropped
(was only a recommendation above), Fig 12/19 and the Fig 13 layout bug
were fixed by Cyra herself, P26 and Fig 17 were redesigned but were
**not** merged (the §2 1.4 “check the correlation, maybe merge” plan
turned out to rest on a wrong premise — see §6), and Figure 1 was
investigated and deliberately *not* turned into a new dashboard figure.
Fig 18’s drop (§3/§5) was never executed and is still open.

</div>

<div class="section level2">

## 6. Addendum — 2026-09-17 session: non-destructive framing goal, and what actually shipped

<div class="section level3">

### 6.0 New governing goal, applies to all design decisions from here on (from Cyra)

Three things stated directly, restated here so future edits to this
document stay consistent with them:

1.  **The point of these figures is not to show self-report and measured
    data converging.** It’s to show that the pipeline is
    *non-destructive*: it only corrects clear input errors (format
    issues, obvious mis-entries), and deliberately does **not** alter a
    record just because self-report and measured/calculated values
    disagree. That disagreement is preserved on purpose — it’s signal
    for emotion/interoception research, not noise to fix toward an
    assumed ground truth. Any figure or caption that reads as “this data
    point is wrong because it doesn’t match” is off-goal; the correct
    framing is “this pair doesn’t match, and that gap is retained, not
    corrected.”
2.  **Keep the research-ready figures already judged useful; trust prior
    “not useful” calls.** Fig 8’s drop (§3) is not up for relitigating.
3.  **Every figure must be outsider-legible** — labels, axis names, and
    captions have to make sense to someone outside the lab, not just to
    someone who already knows the pipeline’s internal vocabulary
    (e.g. “Checkpoint A–E”, raw column names).

</div>

<div class="section level3">

### 6.1 What actually shipped this session (code, pushed via device bridge, not git-committed)

-   **Fig 8 dropped — fully executed**, not just recommended. The
    violin/boxplot block in `sleep_visualization.R` was replaced with a
    removal notice (same rationale as §3/§5: degenerates to one violin
    under unbalanced clean/unusual/error group sizes, which is the
    common case, not an edge case). `make_figure_index.R`’s registry and
    `docs-dev/README_figures_navigation.md` both updated to drop it; the
    figure count corrected to 29 (13 QC + 16 research).
-   **Fig 12 + Fig 19 fold, and the Fig 13 layout bug — fixed, but by
    Cyra, not by me.** I only diagnosed the two mechanisms in §0; her
    commit (`3ecf952`) implemented the actual fix: Fig 12 merged into
    the Step Flag Ledger (now titled “1.1 — Step Flag Ledger”), Fig 19
    folded into Fig 13, and a `plot_spacer()` row added to Fig 13 to
    stop the rotated x-axis labels overflowing into the table below.
-   **Non-destructive captions added** to Figures 2, 20, and 20B, per
    goal 6.0.1 — each now states explicitly that the
    self-report/measured gap is preserved, not corrected, and that a
    flag is not a verdict that the record is wrong.
-   **Fig 17 — redesigned, per §2 1.4’s original plan, confirmed
    correct.** Switched from raw flag count to a rate: flags ÷ that
    participant’s own total observed days, still capped at the top 15.
    The denominator source (unresolved in v2) is `clean_df`’s per-pid
    row count — `clean_df` is the full corrected dataset (one row per
    diary-day per participant), confirmed by an existing line elsewhere
    in the script that already uses `nrow(clean_df)` as the “all
    records” denominator.
-   **P26 — redesigned, but *not* as §3/§4 described
    (histogram/beeswarm), and *not* merged with Fig 17** (see §6.2 for
    why). Implemented as a ranked **table**: top 20 participants by
    flagged-record rate, reusing the exact per-participant
    `pid_flags`/`pid_order` calculation that was already correct in the
    old bar-chart version — only the render form changed. Wording
    follows goal 6.0.1: “Participants Worth a Second Look,” not “bad
    data”; rows are lightly tinted using the existing green/orange/red
    severity colors, not a new palette.
-   **Figure 1 — investigated, deliberately left as the flow diagram it
    already is.** Found a real internal inconsistency: the data-source
    header (L15), Figure 1’s own section comment (L661), and the
    `COMPLETE FIGURE SUMMARY` log line (L2885) all called it “Final Data
    Quality Dashboard,” while the code that actually runs there has
    always produced the “Pipeline Record Flow Diagram” — a two-panel
    dashboard (metrics tile + pie chart) was apparently planned at some
    point but never built, and the comments/log were never updated to
    match what shipped. Given a choice between building that dashboard
    for real (a bigger change touching \~9 other files that reference
    `01_Pipeline_Flow_Diagram.png` or “Figure 1,” none of it
    render-testable from here) or just fixing the stale text, Cyra chose
    the latter. The three mismatched comments/log lines are now
    corrected to describe the flow diagram; the figure itself is
    unchanged. `docs-dev/README_figures_navigation.md`’s row 1 was
    updated to reference the real filename and describe what the flow
    diagram actually shows.

</div>

<div class="section level3">

### 6.2 §2 1.4’s merge plan — premise was wrong, corrected

§2 1.4 flagged that P26’s %-clean and Fig 17’s %-flagged-days were
“highly likely correlated” and said to check the real-data correlation
before building both, merging into one figure if `|r|` is high. That
check never happened, because reading the actual code surfaced something
more basic than a correlation question: **P26 and Fig 17 aren’t computed
over the same population.** P26 uses `clean_df` — the full corrected
dataset, every participant and every record. Fig 17 uses
`checkforerrors_processed`, which is built by joining onto
`checkforerrors_df` — i.e. only records that were flagged by
pre-correction auto-detection in the first place. They answer genuinely
different questions: P26 is “of this participant’s final records, what
fraction ended up Clean/Minor/Major” (research-readiness,
post-correction); Fig 17 is “of this participant’s algorithm-flagged
records, how does the flag rate compare to peers” (pre-correction QC
diagnostic). A merge would have papered over that difference, not
simplified anything — so both stayed as two figures, each fixed on its
own terms (§6.1).

</div>

<div class="section level3">

### 6.3 Still open after this session

-   **Fig 18 drop (§3/§5)** — recommended, never executed. Still present
    in `make_figure_index.R`’s registry and the nav doc’s Tier 2 list.
    Needs a decision, not assumed.
-   **Level 0 contact-sheet header** (§2: stat-tile row + Fig 1
    thumbnail + misrepair-vs-flagged footer citation) — not implemented.
-   **Level 2 grouping** (§2.1–2.4 visual regrouping of the 16
    research-ready figures in the contact sheet) — not implemented.
-   **Fig 14 + Fig 06 merge** into one paired before/after panel — not
    implemented.
-   **Outsider-friendly labeling audit (goal 6.0.3)** — applied so far
    only to the figures touched this session (1, 2, 8, 17, 20, 20B,
    P26). Not yet a systematic pass over the other \~22 figures —
    e.g. whether “Checkpoint A–E” and similar internal vocabulary in the
    Step Flag Ledger has adequate plain-language translation hasn’t been
    checked.
-   **`make_figure_index.R`’s tier scheme vs. the nav doc’s tier
    scheme** — the registry still defines 3 tiers (1/2/3) with tier 2
    unused (everything is 1 = pipeline\_cleaning or 3 =
    research\_ready), while the nav doc uses “60-second check” + “Tier
    2” + “Tier 3” as three genuinely distinct levels. Not reconciled;
    flagged here so it isn’t lost again.

</div>

</div>

</div>

</div>
