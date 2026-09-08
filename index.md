# sleepcleanr — Reproducible cleaning pipeline for sleep EMA diary data

[![CRAN](https://img.shields.io/cran/v/sleepcleanr?style=flat-square&color=blue)](https://cran.r-project.org/package=sleepcleanr)
[![GitHub
stars](https://img.shields.io/github/stars/cyracaid/sleepdiary-cleaner?style=flat-square)](https://github.com/cyracaid/sleepdiary-cleaner)
[![License:
MIT](https://img.shields.io/badge/license-MIT-green?style=flat-square)](https://opensource.org/licenses/MIT)
[![R-CMD-check](https://img.shields.io/github/actions/workflow/status/cyracaid/sleepdiary-cleaner/R-CMD-check.yaml?style=flat-square&label=R--CMD--check)](https://github.com/cyracaid/sleepdiary-cleaner/actions/workflows/R-CMD-check.yaml)
[![Codecov](https://img.shields.io/codecov/c/github/cyracaid/sleepdiary-cleaner?style=flat-square&color=orange)](https://app.codecov.io/gh/cyracaid/sleepdiary-cleaner)
[![Docs](https://img.shields.io/badge/docs-pkgdown-blue?style=flat-square)](https://cyracaid.github.io/sleepdiary-cleaner/)
[![awesomeskills](https://img.shields.io/badge/awesomeskills.dev-listed-brightgreen?style=flat-square)](https://www.awesomeskills.dev/zh-CN/skill/cyracaid-sleepdiary-cleaner)
[![awesome-R
PR](https://img.shields.io/badge/awesome--R-PR_276-open?style=flat-square)](https://github.com/qinwf/awesome-R/pull/276)

> **[English](#english) · [中文](#%E4%B8%AD%E6%96%87)**

------------------------------------------------------------------------

# English

**sleepcleanr** is a reproducible, auditable R pipeline for cleaning
sleep EMA (ecological momentary assessment) diary data: it parses raw
bedtime/sleep/awake/get-up timestamps, detects and corrects temporal and
duration errors through a transparent human-in-the-loop workflow (every
correction stored in re-readable CSVs), computes standard sleep metrics
(TST, SOL, WASO, SE), and generates diagnostic and research-ready
figures. A schema-validated YAML config maps the pipeline to your
dataset without touching code. Developed for the Stanford
Psychophysiology Laboratory’s intensive-longitudinal sleep study.

## The Pipeline at a Glance

    Messy sleep diary data (CSV / RDS)
             ↓
       Timestamp parsing & normalization
             ↓
       Error detection (order, duration, timezone)
             ↓
       Human-in-the-loop review (flagged records only)
             ↓
       Correction ledger (full audit trail)
             ↓
       Sleep metrics (TST, SOL, WASO, SE)
             ↓
       30+ diagnostic & research-ready figures
             ↓
       Dataset A (final clean) + Dataset B (audit ledger)

**Why sleepcleanr?**

- 🔍 **Detects** not auto-fixes — 1,048 records flagged for manual
  review, 0 silent corrections (field-misentry silent-misrepair bug, 96%
  in v1.4.0, fixed in v1.4.4+; current benchmark: 0% silent misrepair
  for SOL/WASO)
- 📊 **Auditable** — every change logged and reversible; non-destructive
  architecture
- ✅ **Validated** — 9-step validation chain: synthetic (0.995 recall) +
  real data (92% improved) + robustness proof
- 🚀 **Reproducible** — YAML config, full pipeline documentation, 308
  unit tests passing
- 🎯 **Research-ready** — generates publication-quality figures +
  correlation matrices

### Why the hybrid (automated + human) design?

sleepcleanr is deliberately **not** fully automated and **not**
all-manual-flag:

- **Not fully auto:** high-confidence, order/AM-PM-only rules correct
  harmlessly; but value-level errors (e.g. SOL vs the bed→sleep window)
  must not be overwritten — a plausible large SOL is real psychological
  signal, and silently “fixing” it would bias the sleep–affect
  associations the pipeline exists to serve.
- **Not all-flag:** a 1,048-row FLAG queue is unmanageable by hand.
  High-confidence rules chew the deterministic cases; FLAG keeps only
  the ambiguous ones for human review.

The outcome is not “the pipeline makes a mess clean” — it makes the mess
**explicit**: every candidate error is surfaced or logged, never
silently hidden.

> **Thresholds are references, not gospel.** The swap/flip thresholds
> shipped here (e.g. 3-hour adjacent swap, 12-hour AM/PM flip) were
> validated on our dataset(s) — see VALIDATION_REPORT. Your study’s
> diaries may fall inside or outside these cut-offs; they are
> YAML-configurable and should be re-checked against your own data, not
> copied blindly.

### Flag System & Human Review Workflow

sleepcleanr uses a structured flag system to route records through the
human-in-the-loop review process. Every record can carry multiple flags;
flags are **additive** (a record may carry several simultaneously) and
**never silently cleared** — they persist until explicitly resolved by
human action.

| Flag / Column                 | Trigger                                                   | Meaning                                                             | Resolution                                                                                                        |
|-------------------------------|-----------------------------------------------------------|---------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| `needs_review_flag`           | Any detection rule fires                                  | Record needs human attention                                        | Human reviews → sets `manually_corrected=TRUE` OR `human_metric_review_status=confirmed_not_error_do_not_correct` |
| `auto_error_desc`             | Auto-detection logic                                      | Machine-readable description of why flagged                         | Reference for human reviewer                                                                                      |
| `error_type` / `unusual_type` | Step 5 classification                                     | Categorized error type (TIMESTAMP, DURATION, SELF_REPORTED, etc.)   | Informs reviewer; drives Figure 13 classification                                                                 |
| `manually_corrected`          | Human applied correction via `apply_manual_corrections.R` | Record was explicitly fixed by human                                | Set to `TRUE` by `apply_manual_corrections.R`                                                                     |
| `human_metric_review_status`  | Human metric review decision                              | `confirmed_not_error_do_not_correct` = reviewed & confirmed correct | Set by `apply_metric_review_acceptances.R` / `apply_metric_review_acceptances()`                                  |
| `human_metric_review_note`    | Reviewer’s free-text note                                 | Context for future auditors                                         | Free text                                                                                                         |
| `correction_type`             | Applied correction type                                   | e.g., `bed_sleep_swap_3h`, `sleep_reduce_12h_loop`                  | Populated by correction engine                                                                                    |

**Flag lifecycle:**

    Record flagged (needs_review_flag=TRUE)
        ↓ Human reviews
        ├── Confirmed error → apply_manual_corrections.R → manually_corrected=TRUE
        ├── Confirmed OK → human_metric_review_status="confirmed_not_error_do_not_correct"
        └── Deferred / unsure → needs_review_flag remains TRUE

**Key design principles:**

1.  **Flags are never silently cleared** — a flag persists until
    explicit human action (`manually_corrected=TRUE` or
    `human_metric_review_status=confirmed_not_error_do_not_correct`).
2.  **Flags are additive** — a record can carry multiple flags
    simultaneously (e.g., TIMESTAMP + DURATION + SELF_REPORTED).
3.  **Resolution is explicit** — a flag is “resolved” only by setting
    `manually_corrected=TRUE` or
    `human_metric_review_status=confirmed_not_error_do_not_correct`;
    there is no implicit “auto-resolve”.
4.  **Flags persist in outputs** — Dataset A (full) retains all flags
    for audit; Dataset B (minimal) includes only `needs_review_flag` and
    `correction_type` for downstream analysis.

**Current flag categories** (from `checkforerrors_processing.R`):

| Category          | Sub-types                                        | Meaning                                            |
|-------------------|--------------------------------------------------|----------------------------------------------------|
| **TIMESTAMP**     | Clock-time format errors (bed/sleep/awake/getup) | e.g., hour\>23, malformed colon                    |
| **DURATION**      | Interval/format errors (SOL, WASO)               | e.g., MM:SS vs HH:MM confusion                     |
| **AMOUNT**        | Substance input anomalies                        | negative, excessive digits, filler codes (888/999) |
| **SELF_REPORTED** | SOL/WASO vs timestamp-window mismatch            | SOL \> bed→sleep window, SE\>100%, etc.            |

**Flag statistics (v1.4.5, n=13,990):** 1,048 records flagged (7.5%); 0
AUTO_FIX; 0 silent corrections. Breakdown: 922 TIMESTAMP (window
violations), 140 DURATION (order violations), 1 SELF_REPORTED (extreme),
1 redundancy-confirmed worsening. See `VALIDATION_REPORT.md` for full
breakdown.

### Validation Map

    SYNTHETIC TIER (ground truth)
    ──────────────────────────────
    Step 1  Clean-input specificity ── 10k clean records → 0 changes/flags
    Step 2  Injected-error benchmark ── recall 0.995 [0.993, 0.997]
    Step 3  Detection vs correctness ── L1 vs L3 gap → routes to human
    Step 4  Controls ── no_cleaning 0 / naive_rule 0.623 / pipeline 0.995

    REAL-DATA TIER (n = 13,990)
    ──────────────────────────────
    Step 5  Redundant-channel ── 81/88 corrections improve (92%)
    Step 5.5  Bland-Altman ── SOL ±75-min noise band; WASO 3.3× above noise
    Step 6  Report-only audit ── 0 AUTO_FIX, 1,048 FLAG
    Step 7  Human co-review ── 64–89% agreement

    ROBUSTNESS TIER
    ──────────────────────────────
    Step 8  Multiverse + seeds ── recall stable 0.993–0.995

> **Naming note:** The R package is called **sleepcleanr** (CRAN
> convention: no hyphens). The GitHub repository is
> **sleepdiary-cleaner**. They are the same project — install via
> `renv::install("cyracaid/sleepdiary-cleaner")` and then
> [`library(sleepcleanr)`](https://github.com/cyracaid/sleepdiary-cleaner).

> **Validation statistics source:** All validation statistics above
> (recall 0.995, 92% improvement, 0% silent misrepair for SOL/WASO,
> etc.) are derived from benchmarks run against the current
> `sleepcleanr` v1.4.5+ codebase (commit fd6bbd0). The synthetic
> benchmark
> (`validation/synthetic/results/detection_outcomes_v4_current.csv`,
> 4,736 injected rows) and real-data audit (n=13,990) were executed
> against the current codebase (commit fd6bbd0). These statistics
> reflect the current pipeline behavior and supersede any earlier
> pre-patch numbers cited in earlier documentation. See
> `VALIDATION_REPORT.md` and
> `validation/synthetic/SYNTHETIC_BENCHMARK_RESULTS.md` for the full
> evidence package.

## Install

``` r
# From GitHub (CRAN release pending)
renv::install("cyracaid/sleepdiary-cleaner")
```

## Quick start

``` r
library(sleepcleanr)

# Demo run on the bundled synthetic fixture
run_pipeline()

# Your own study: copy the config template, map your columns, run again
file.copy(system.file("config_template.yaml", package = "sleepcleanr"),
          "my_study.yaml")
# edit my_study.yaml → run_pipeline(config = "my_study.yaml")
```

## Learn more

- Full docs site (searchable reference + vignettes, bilingual):
  <https://cyracaid.github.io/sleepdiary-cleaner/>
- **Validation Report** (evidence package, machine-read from result
  CSVs):
  [`VALIDATION_REPORT.md`](https://cyracaid.github.io/sleepdiary-cleaner/VALIDATION_REPORT.md)
- vignette(“pipeline-architecture”) — structure, rule families,
  classification
- vignette(“column-mapping”) — mapping your dataset via YAML
- vignette(“interpreting-output”) — reading
  `correction_status_final.csv` and `step_flag_ledger.csv`
- vignette(“validation-methodology”) — how the rules were validated
  (synthetic + real data)
- vignette(“testing-coverage”) — test suite coverage
- Changelog: <https://github.com/cyracaid/sleepdiary-cleaner/releases>

## For developers / AI assistants

The repository ships an agent skill at
`.opencode/skills/sleepcleanr-pipeline/SKILL.md` that documents how to
run the pipeline, interpret checkpoint reports, add manual corrections,
and diagnose issues.

### Pipeline steps

**10 steps** (source: `inst/steps.yaml`):

| Step | Label                                | Description                                                                      |
|------|--------------------------------------|----------------------------------------------------------------------------------|
| 1    | Load data                            | .rds/.csv auto-detected; schema validated; optional supplementary file merged    |
| 1.5  | Field-misentry check                 | SOL/WASO clock-time vs duration-field misentry detection on raw data             |
| 2-4  | Parse & normalize (S3 chain)         | Parse timestamps → parse intervals → normalize sequence                          |
| 5    | Classify records                     | Generate manual review CSVs for human approval                                   |
| 5.75 | Second-review consensus              | Apply second-review checklist consensus                                          |
| 6-7  | Correct & compute metrics (S3 chain) | Manual + duration corrections; TST/SOL/WASO/SE metrics; has_correction enum      |
| 8    | Auto-detect remaining issues         | TIMESTAMP/DURATION/AMOUNT/SELF-REPORTED flag classification                      |
| 8.5  | Cross-participant consistency check  | Global consistency audit across participants                                     |
| 9    | Generate diagnostic figures          | 30 figures (14 QC + 16 research) + figure_index.png contact sheet + RUN_INFO.txt |
| 10   | Build delivered datasets             | finalize_columns() selects/renames to Dataset A/B per column dictionary          |

## Sync Human Review Status

sleepcleanr provides a utility to synchronize human review status fields
in the metric review acceptance CSV file.

> **Known issue (flagged 2026-09-07, not yet fixed):** the current
> implementation crashes on a genuine first/bootstrap run (missing
> `resolved_at`/`resolved_by` columns raise
> `object 'resolved_at' not found`), and the `review_resolution` split
> it produces on already-populated data does not reproduce from a clean
> run of the logic below — the numbers shown in this section’s example
> output should not yet be treated as verified. Treat this utility as
> unreviewed until the crash and the provenance question are resolved.

### `sync_human_review_status()`

Automatically synchronizes review status fields in
`manual_metric_review_acceptances.csv` based on human review traces.

``` r
library(sleepcleanr)
sync_human_review_status("manual_metric_review_acceptances.csv")
```

**What it does:**

1.  **Detects human review traces** by checking:
    - `human_metric_review_note` (non-empty reviewer notes)
    - `resolved_at` (resolution timestamp)
    - `resolved_by` (resolution actor)
2.  **Updates three columns** based on detected traces:
    - `review_resolution`: `"corrected"` / `"flagged_unresolved"` /
      `"legacy"`
    - `resolved_at`: Resolution date (only for `corrected`)
    - `resolved_by`: `"system"` / `"pending"` / `"legacy"`

**Resolution Logic:** \| Condition \| `review_resolution` \|
`resolved_at` \| `resolved_by` \| \|———–\|———————\|—————\|—————\| \|
Explicit `corrected` flag \| `"corrected"` \| Today \| `"system"` \| \|
Human traces + legacy/NA \| `"flagged_unresolved"` \| NA \| `"pending"`
\| \| Human traces + legacy/NA \| `"flagged_unresolved"` \| NA \|
`"pending"` \| \| No traces + legacy \| `"legacy"` \| NA \| `"legacy"`
\|

**Usage:**

``` r
library(sleepcleanr)
sync_human_review_status("manual_metric_review_acceptances.csv")
```

**Output:**

    ✓ Synced 161 rows: 1 corrected, 43 flagged, 117 legacy

**Integration in Pipeline:** Automatically runs at pipeline Step 11
(after all corrections, before visualization):

``` r
run_pipeline(config = "my_study.yaml")  # Automatically runs sync_human_review_status() at Step 11
```

**Manual invocation:**

``` r
library(sleepcleanr)
sync_human_review_status("manual_metric_review_acceptances.csv")
```

------------------------------------------------------------------------

# 中文

**sleepcleanr** 是一个可复现、可审计的睡眠 EMA 日记数据清洗 R
管线：解析原始
就寝/入睡/醒来/起床时间戳，通过透明的人工审核工作流（每次修正都存为可重读的
CSV）检测并修正时序与时长错误，计算标准睡眠指标（TST、SOL、WASO、SE），并生成
诊断与科研图表。经 schema 校验的 YAML
配置可将管线映射到你的数据集，无需改代码。
为斯坦福心理生理学实验室的高强度纵向睡眠研究开发。

### 为什么是”自动 + 人工”混合设计？

sleepcleanr 刻意**既非全自动、也非全部人工 flag**：

- **不全自动：** 高置信、仅涉时序/AM-PM
  的规则才安全自动修正；但值级错误（如 SOL
  与就寝→入睡窗口的矛盾）绝不覆盖 — 一个看似偏大的 SOL
  是真实的心理信号，静默”修正”会破坏管线所服务的睡眠–情绪关联。
- **不全 flag**：1048 行 FLAG
  队列手动看不过来。高置信规则吃掉确定性个案；FLAG
  只把歧义个案留给人审。

结果不是”管线把 mess 洗干净”，而是把 mess
**显式化**：每个候选错误要么被呈现，要么被记录，永不被静默隐藏。

> **阈值只是参考，不是教条。** 这里的 swap/flip 阈值（如 3
> 小时相邻对调、12 小时 AM/PM 翻转）在我们的数据集上验证过 — 见
> VALIDATION_REPORT。你的研究日记可能落在这区间内或外；它们都是 YAML
> 可配置的，应按你自己的数据重新审视，而非盲抄。

> **命名说明：** R 包名为 **sleepcleanr**（CRAN 规范不允许连字符），
> GitHub 仓库名为 **sleepdiary-cleaner**。两者是同一项目 — 安装用
> `renv::install("cyracaid/sleepdiary-cleaner")`，加载用
> [`library(sleepcleanr)`](https://github.com/cyracaid/sleepdiary-cleaner)。

## 安装

``` r
# 从 GitHub 安装（CRAN 发布待定）
renv::install("cyracaid/sleepdiary-cleaner")
```

## 快速开始

``` r
library(sleepcleanr)

# 用内置合成数据跑演示
run_pipeline()

# 自己的研究数据：复制配置模板、映射列名、再跑
file.copy(system.file("config_template.yaml", package = "sleepcleanr"),
          "my_study.yaml")
# 编辑 my_study.yaml → run_pipeline(config = "my_study.yaml")
```

## 了解更多

- 完整文档站（可检索函数参考 + 双语 vignette）：
  <https://cyracaid.github.io/sleepdiary-cleaner/>
- **验证报告**（证据包，数字从结果 CSV 机器读取）：
  [`VALIDATION_REPORT.md`](https://cyracaid.github.io/sleepdiary-cleaner/VALIDATION_REPORT.md)
- vignette(“pipeline-architecture-zh”) — 结构、规则族、分类体系
- vignette(“column-mapping-zh”) — 用 YAML 映射你的数据集
- vignette(“interpreting-output-zh”) — 读 `correction_status_final.csv`
  和 `step_flag_ledger.csv`
- vignette(“validation-methodology-zh”) — 规则如何验证（合成 +
  真实数据）
- vignette(“testing-coverage-zh”) — 测试覆盖
- 更新日志：<https://github.com/cyracaid/sleepdiary-cleaner/releases>

## 开发/AI 助手

仓库自带 agent
skill：`.opencode/skills/sleepcleanr-pipeline/SKILL.md`，说明如何
运行管线、解读检查点报告、添加人工修正与诊断问题。

### 管线步骤

**10 个步骤**（来源：`inst/steps.yaml`）：

| 步骤 | 名称                                 | 说明                                                                             |
|------|--------------------------------------|----------------------------------------------------------------------------------|
| 1    | Load data                            | .rds/.csv auto-detected; schema validated; optional supplementary file merged    |
| 1.5  | Field-misentry check                 | SOL/WASO clock-time vs duration-field misentry detection on raw data             |
| 2-4  | Parse & normalize (S3 chain)         | Parse timestamps → parse intervals → normalize sequence                          |
| 5    | Classify records                     | Generate manual review CSVs for human approval                                   |
| 5.75 | Second-review consensus              | Apply second-review checklist consensus                                          |
| 6-7  | Correct & compute metrics (S3 chain) | Manual + duration corrections; TST/SOL/WASO/SE metrics; has_correction enum      |
| 8    | Auto-detect remaining issues         | TIMESTAMP/DURATION/AMOUNT/SELF-REPORTED flag classification                      |
| 8.5  | Cross-participant consistency check  | Global consistency audit across participants                                     |
| 9    | Generate diagnostic figures          | 30 figures (14 QC + 16 research) + figure_index.png contact sheet + RUN_INFO.txt |
| 10   | Build delivered datasets             | finalize_columns() selects/renames to Dataset A/B per column dictionary          |
