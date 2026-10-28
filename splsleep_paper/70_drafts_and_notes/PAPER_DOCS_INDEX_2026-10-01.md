# Paper documents: what is current, what is superseded (2026-10-01)

Nothing has been moved or deleted. This is a map, built from file dates and
contents. "Current" is my reading and needs your confirmation.

## The two papers

| Paper | Current working file | Where | Status |
|---|---|---|---|
| **Methods article (BRM)**, full pipeline and validation | `METHODS_SECTION_COMPLETE_WITH_ALL_STAGES_v2_2026-10-01.md` (v2 adds the Manchester paragraph to the 2026-09-29 version) | repo `work_logs/` | Main text drafted in Maia's prose style, 10 stages plus external validation. Stage 9 figure count to decide. |
| **JOSS software paper** | `paper.md` (modified locally, not pushed: internal TODO comments) | repo root | Summary and Statement of need exist; Research impact, Development history and AI disclosure drafted. JOSS now requires the repository to be public for more than six months (since 2026-07-15 it is about 2.5) and a demonstrated research impact, so this waits. |

## Proposed numbering

One folder outside the repo, `~/Documents/splsleep_paper/`, with a numbered
prefix so the order is obvious and each paper has one `current/` file:

```
splsleep_paper/
  00_INDEX.md                      (this file, kept up to date)
  10_methods_BRM/
    current/   METHODS_complete_v2_2026-10-01.md
    history/   2026-09-29 complete, 2026-08-28 BRM draft, 2026-08-20 skeleton
  20_software_JOSS/
    current/   paper.md  (copy; the repo file stays the source of truth)
  30_short_forms/
    current/   METHOD_SHORT (sleep-journal short form), after the BRM text settles
  40_maia_originals/               the .docx versions v0 to v5 (Aug 2026)
  50_audits/                       m4_188 and m4_922 audit files (contain participant ids: keep OUT of git)
  60_worklogs/                     dated worklogs, one per week
```

Rules: a file in `current/` is the only one to edit; when you replace it, move
the old one to `history/` with the date in the name; files with participant
ids never go inside the git repo.

## Classification of what exists

### Methods text (BRM direction)

| File | Date | Verdict |
|---|---|---|
| `work_logs/METHODS_SECTION_COMPLETE_WITH_ALL_STAGES_v2_2026-10-01.md` | 10-01 | **current** |
| `work_logs/METHODS_SECTION_COMPLETE_WITH_ALL_STAGES.md` | 09-29 | superseded by v2 (only the Manchester paragraph differs) |
| `splsleep_paper_work/BRM_METHODS_DRAFT.md` (Chinese, "to translate when submitting") | 08-28 | older; has the submission-positioning note (BRM yes, JAMIA no) worth keeping |
| `splsleep_paper_work/BRM_METHODS_SKELETON.md` | 08-20 | older skeleton |
| `work_logs/METHODS_SECTION_PAPER_2026-08-19.md`, `METHODS_SHORT.md`, `METHODS_SECTION_MAIA_ORIGINAL_WITH_UPDATED_NUMBERS.md`, `METHODS_MAIA_ORIGINAL_WITH_ADDITIONS_TRACKED.docx` | 08-25 | older (August); keep as history |
| `splsleep_paper_work/methods_sources/*.docx` (v0 to v5, plus 3 duplicates by file size) | 08-16 | Maia/Cyra originals; `v5_methodology_cyra_mtb-edits.docx` is the last; duplicates are identical copies (same byte size): `Methods english cyra.docx` = `v2_...`, `methodology 草稿.docx` = `v0_...`, `Methodology Cyra #2 _MtB edits 031926.docx` = `v5_...` |
| `validation/METHOD_SECTION_LONG_methodology_journal.md` | 09-07 | long form; the 81/88 table in it is the pre-guard analysis (see note below) |
| `validation/METHOD_SECTION_SHORT_sleep_journal.md` | 09-07 | short form; says reviewers worked "independently", which `VALIDATION_REPORT.md` contradicts; `work_logs/METHOD_SHORT_v2_DRAFT_2026-10-01.md` has the corrected wording |
| `validation/METHOD_SECTION_DRAFT_misrepaired_finding.md`, `PROMPT_method_section_misrepaired_finding.md` | 09-02 to 09-07 | single-finding write-up and its prompt |

### Worklogs

Dated worklogs sit in three places: repo `work_logs/` (2026-08-21 onward),
`opencode/proj_splclean/` (2026-08-17 to 09-07, one 91 KB file) and
`splsleep_paper_work/`. Suggested: one folder, one file per week, named
`YYYY-MM-DD_to_YYYY-MM-DD_WORKLOG.md`. The English worklog for this week is
`work_logs/2026-10-01_WORKLOG_EN.md`.

### Duplicates and things not to commit

- `opencode/proj_splclean/sensitive_local/` and `splsleep_paper_work/audit_*`,
  `m4_188_*`, `human_review_package*` hold participant ids: never inside git.
- `work_logs/` and `manuscript_notes/` are already git-ignored in the repo.

## The 81/88 number: reconciled (2026-10-01)

Appears in `VALIDATION_REPORT.md`, the validation vignette, the README and
`METHOD_SECTION_LONG`, from an August analysis whose script is not in the
repository. `validation/redundant_channel_check.R` (new, not yet committed)
recomputes it on the current pipeline output, by correction type:

| rule | August | now |
|---|---|---|
| bed_sleep_swap_3h | 39 of 39, median 31 to 5 | 39 of 39, median 31 to 5 (identical) |
| sleep_reduce_12h_loop | 38 of 38, median 720 to 9.5 | 39 of 39, median 720 to 9 |
| sleep_awake_swap_3h | 3 of 10 improved, 7 worsened | 2 of 3 improved, 1 worsened (rule guarded in v1.4.3) |
| all three | 81 of 88 (92.0%) | 80 of 81 (98.8%) |

The check itself is sound (it matches the August result where the rules did
not change, and its one worsened row matches the independent B2 list in
`part_b_global_sweep.R`). The published figure describes the pre-guard
pipeline. Before any paper quotes it, replace it with the current one and say
that the guard was added after the August analysis. None of the published files
was changed yet.
