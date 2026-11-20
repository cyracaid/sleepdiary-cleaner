# sleepcleanr — Reproducible cleaning pipeline for sleep EMA diary data

[![GitHub
stars](https://img.shields.io/github/stars/cyracaid/sleepdiary-cleaner?style=flat-square)](https://github.com/cyracaid/sleepdiary-cleaner)
[![License:
MIT](https://img.shields.io/badge/license-MIT-green?style=flat-square)](https://opensource.org/licenses/MIT)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23077702.svg)](https://doi.org/10.5281/zenodo.23077702)
[![R-CMD-check](https://img.shields.io/github/actions/workflow/status/cyracaid/sleepdiary-cleaner/R-CMD-check.yaml?style=flat-square&label=R--CMD--check)](https://github.com/cyracaid/sleepdiary-cleaner/actions/workflows/R-CMD-check.yaml)
[![Codecov](https://img.shields.io/codecov/c/github/cyracaid/sleepdiary-cleaner?style=flat-square&color=orange)](https://app.codecov.io/gh/cyracaid/sleepdiary-cleaner)
[![Docs](https://img.shields.io/badge/docs-pkgdown-blue?style=flat-square)](https://cyracaid.github.io/sleepdiary-cleaner/)

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
       Diagnostic and research figures
             ↓
       Dataset A (final clean) + Dataset B (audit ledger)

## What makes it different

1.  **Human-in-the-loop, not automatic repair.** Deterministic rules
    correct only unambiguous ordering and format errors; value-level
    disagreements are routed to human review. A plausible large SOL is
    left exactly as reported — it is signal, not an error.
2.  **No silent corrections.** Every change carries a recorded
    correction type, and flags persist until a human resolves them
    explicitly. The correction ledger is part of the output
    (`correction_status_final.csv`, `step_flag_ledger.csv`), and every
    run regenerates the human-review worksheets
    (`[NEW]manual_error_correction_review.csv`,
    `[NEW]manual_unusual_review.csv`) in the project root — not in
    `output/`.
3.  **Configurable, documented thresholds.** Rule thresholds ship as
    YAML defaults with rationale (see
    [THRESHOLDS.md](https://cyracaid.github.io/sleepdiary-cleaner/THRESHOLDS.md))
    and are meant to be re-checked against your own data.
4.  **Reproducible.** YAML config, `renv.lock`, and a CI-run test suite
    (R-CMD-check, Codecov).

## Install

``` r
# From GitHub (not yet on CRAN)
renv::install("cyracaid/sleepdiary-cleaner")
# or: pak::pak("cyracaid/sleepdiary-cleaner")
```

## Quick start

Shortest path: point
[`clean_sleep_diary()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/clean_sleep_diary.md)
at your file; no config needed.

``` r
library(sleepcleanr)

res <- clean_sleep_diary("my_diary.csv")          # .csv / .rds / .xlsx / data.frame
res$cleaned                                       # cleaned Dataset A
res$guesses                                       # how each column was mapped
res$manifest                                      # provenance: input hash, config, step ledger
# Preview the inferred mapping without running anything:
clean_sleep_diary("my_diary.csv", dry_run = TRUE) # writes dry_run_manifest.json, no data written
```

Other entries:

``` r
# Demo run on the bundled synthetic fixture
run_pipeline()

# Config-file route: copy the template, map your columns, run again
file.copy(system.file("config_template.yaml", package = "sleepcleanr"),
          "my_study.yaml")
# edit my_study.yaml → run_pipeline(config = "my_study.yaml")
```

> **Shell note:** the review worksheets are named `[NEW]manual_*.csv`.
> The square brackets are glob characters, so quote the name in a shell:
> `open "[NEW]manual_error_correction_review.csv"`.

## Evidence at a glance

Full package in
[VALIDATION_REPORT.md](https://cyracaid.github.io/sleepdiary-cleaner/VALIDATION_REPORT.md).
Summary:

- **Synthetic ground truth** (5,391 injected errors in 14 categories,
  plus 1,609 clean control rows): detection recall **0.995** \[0.993,
  0.997\], specificity 1.0. “Detection” means the record was flagged,
  not that the corrected value was recovered — correction-level recall
  is lower and is reported per error category in the validation report.
- **Real study data** (13,990 rows from 237 participants): in the
  study’s run, the rules applied an automatic order or format correction
  to 93 rows (10 of them were also corrected by a reviewer) and
  reviewers corrected 75 further rows. The review queue at the end of a
  run is 226 rows with the manual files applied and 307 without. Of the
  13,990 submissions, 2,848 have all four times, so that is 79 and 108
  rows per 1,000 diary entries (1.6% and 2.2% of all submissions). The
  1,048 rows flagged in the v1.4.5 audit came from a report-only pass
  that modified no data.
- **External public datasets**: the pipeline runs on other schemas after
  a short conversion script. These datasets contain no known errors, so
  they are a feasibility check, not accuracy validation.

![Flag dashboard from the bundled synthetic fixture: 23 of 280 records
flagged for review, split by issue
type](https://raw.githubusercontent.com/cyracaid/sleepdiary-cleaner/main/man/img/flag-dashboard-synthetic.png)

Flag dashboard from the bundled synthetic fixture: 23 of 280 records
flagged for review, split by issue type

*Figure 14 from a run on the bundled synthetic fixture (280 rows): what
the pipeline flags for review at the end of a run.*

Earlier automated variants silently misrepaired entries; the synthetic
benchmark found and closed those defects, and the current benchmark
reports 0% silent misrepair for SOL/WASO.

### Why the hybrid (automated + human) design?

sleepcleanr is deliberately **not** fully automated and **not**
all-manual-flag:

- **Not fully auto:** high-confidence, order/AM-PM-only rules correct
  harmlessly; but value-level errors (e.g. SOL vs the bed→sleep window)
  must not be overwritten — a plausible large SOL is real psychological
  signal, and silently “fixing” it would bias the sleep–affect
  associations the pipeline exists to serve.
- **Not all-flag:** flagging every disagreement is unmanageable by hand
  (the v1.4.5 report-only audit flagged 1,048 rows; a current run leaves
  226 rows to review, or 307 without the manual files). High-confidence
  rules take the deterministic cases; FLAG keeps only the ambiguous ones
  for human review.

The outcome is not “the pipeline makes a mess clean” — it makes the mess
**explicit**: every candidate error is surfaced or logged, never
silently hidden.

> **Thresholds are references, not gospel.** The swap/flip thresholds
> shipped here (e.g. 3-hour adjacent swap, 12-hour AM/PM flip) were
> validated on our dataset(s) — see VALIDATION_REPORT. Your study’s
> diaries may fall inside or outside these cut-offs; they are
> YAML-configurable and should be re-checked against your own data, not
> copied blindly.

### Flags, terminology and thresholds

The flag columns, the flag lifecycle, the terms used in the validation
tables (L1/L3 recall, FCR, FAR, M1/M4/M5) and
[`sync_human_review_status()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/sync_human_review_status.md)
are in the article
[`vignette("review-flags")`](https://cyracaid.github.io/sleepdiary-cleaner/articles/review-flags.md)
(Flags, terminology and the review workflow). The detection thresholds,
with defaults and rationale, are on the
[Thresholds](https://cyracaid.github.io/sleepdiary-cleaner/THRESHOLDS.md)
page.

The validation map (synthetic, real-data and robustness tiers) and where
each number comes from are in
[`vignette("validation-methodology")`](https://cyracaid.github.io/sleepdiary-cleaner/articles/validation-methodology.md).

> **Naming note:** The R package is called **sleepcleanr** (CRAN
> convention: no hyphens). The GitHub repository is
> **sleepdiary-cleaner**. They are the same project — install via
> `renv::install("cyracaid/sleepdiary-cleaner")` and then
> [`library(sleepcleanr)`](https://github.com/cyracaid/sleepdiary-cleaner).

## Status and data availability

**Status.** sleepcleanr (the development version after 1.8.0) is
research software under active development. It was built for one
longitudinal sleep study, has not yet been peer reviewed, and is not on
CRAN. Treat the shipped thresholds as references to check against your
own data.

**Data availability.** The study data are not public (participant
privacy). What you can use without them:

- a bundled synthetic fixture (`inst/extdata/`, 280 rows, 20
  participants) that
  [`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md)
  runs on by default;
- the synthetic benchmark, which regenerates its own data from fixed
  seeds, so every benchmark number can be re-run (see
  [`validation/README.md`](https://github.com/cyracaid/sleepdiary-cleaner/blob/main/validation/README.md));
- two public diary datasets with adaptation scripts
  (`validation/external/`).

The few numbers that come from the study data (for example the
redundant-channel check) are reported in `VALIDATION_REPORT.md` and
cannot be re-run without access to those data.

## Limitations

- **Thresholds are study-specific defaults.** The 3-hour adjacent-swap
  and 12-hour AM/PM-flip rules, and the plausibility cut-offs, were
  tuned on one healthy-adult EMA sample. Clinical, shift-work, and
  elderly samples should revisit every rule. Rationale and defaults are
  in
  [THRESHOLDS.md](https://cyracaid.github.io/sleepdiary-cleaner/THRESHOLDS.md).
- **Detect, do not infer intent.** The pipeline surfaces candidate
  errors; it cannot recover information that was never entered, and
  value-level disagreements are routed to a human, not resolved
  automatically.
- **Validation is partly self-referential.** Detection was validated
  against injected synthetic errors and the pipeline’s own real-data
  audit. No independent human gold standard for free-text diary entry
  exists, and some reported statistics come from the development data.
- **No native CSD or `.sav` support.** The Consensus Sleep Diary format
  is not a native input; map your columns via YAML (or let the inference
  guess). Output is `.csv` / `.rds`; there is no SPSS `.sav` export.
- **One protocol.** Developed for an intensive-longitudinal morning
  sleep diary. Evening diaries, nap-only logs, and actigraphy are out of
  scope.
- **Not a substitute for study-specific quality control.**

## Citation

Cite the software with its Zenodo DOI (the concept DOI always resolves
to the latest version; each release also has its own version DOI):

> Dong, C., & ten Brink, M. (2026). *sleepcleanr: Reproducible Sleep EMA
> Diary Data Cleaning Pipeline* \[R package\].
> <https://doi.org/10.5281/zenodo.23077702>

In R: `citation("sleepcleanr")`. Machine-readable metadata:
`CITATION.cff`.

## Run the tests, report a problem, contribute

``` r
devtools::test()   # from a clone of the repository; the same suite runs in CI
```

Bugs, questions and feature requests: open an
[issue](https://github.com/cyracaid/sleepdiary-cleaner/issues).
Contribution guidelines are in
[`CONTRIBUTING.md`](https://cyracaid.github.io/sleepdiary-cleaner/CONTRIBUTING.md).

## Learn more

- Full docs site (searchable reference + vignettes, bilingual):
  <https://cyracaid.github.io/sleepdiary-cleaner/>
- **Validation Report** (evidence package, machine-read from result
  CSVs):
  [`VALIDATION_REPORT.md`](https://cyracaid.github.io/sleepdiary-cleaner/VALIDATION_REPORT.md)
- vignette(“getting-started”) — install, first run, the two modes
  (`include_manual_corrections`)
- vignette(“column-mapping”) — input data and configuration: mapping
  your dataset via YAML
- vignette(“data-first”) —
  [`clean_sleep_diary()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/clean_sleep_diary.md):
  no-config entry, column auto-guess, run manifest
- vignette(“interpreting-output”) — reading the output and the review
  loop (`correction_status_final.csv`, the review status table, figures)
- vignette(“review-flags”) — flag columns and lifecycle, the terms in
  the validation tables,
  [`sync_human_review_status()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/sync_human_review_status.md)
- vignette(“output-files”) — every file a run writes: where it goes,
  which step writes it, what it is
- vignette(“troubleshooting”) — symptom, cause and fix for the problems
  seen most often
- [`THRESHOLDS.md`](https://cyracaid.github.io/sleepdiary-cleaner/THRESHOLDS.md)
  — every detection threshold with its default and rationale, and how to
  set your own (also on the docs site under “Thresholds”)
- vignette(“pipeline-architecture”) — structure, rule families,
  classification
- vignette(“validation-methodology”) — how the rules were validated
  (synthetic + real data)
- vignette(“testing-coverage”) — test suite coverage
- Changelog: <https://github.com/cyracaid/sleepdiary-cleaner/releases>

## For developers / AI assistants

The repository ships an agent skill at
`.claude/skills/sleepcleanr-pipeline/SKILL.md` (also linked from
`.agents/skills/`, so Claude Code, Codex and opencode all find it) that
documents how to run the pipeline, interpret checkpoint reports, add
manual corrections, and diagnose issues.

### Pipeline steps

**10 steps** (source: `inst/steps.yaml`):

| Step | Label | Description |
|----|----|----|
| 1 | Load data | .rds/.csv auto-detected; schema validated; optional supplementary file merged |
| 1.5 | Field-misentry check | SOL/WASO clock-time vs duration-field misentry detection on raw data |
| 2-4 | Parse & normalize (S3 chain) | Parse timestamps → parse intervals → normalize sequence |
| 5 | Classify records | Generate manual review CSVs for human approval |
| 5.75 | Second-review consensus | Apply second-review checklist consensus |
| 6-7 | Correct & compute metrics (S3 chain) | Manual + duration corrections; TST/SOL/WASO/SE metrics; has_correction enum |
| 8 | Auto-detect remaining issues | TIMESTAMP/DURATION/AMOUNT/SELF-REPORTED flag classification |
| 8.5 | Cross-participant consistency check | Global consistency audit across participants |
| 9 | Generate diagnostic figures | 35 figures (19 QC + 16 research) + figure_index.png contact sheet + RUN_INFO.txt |
| 10 | Build delivered datasets | finalize_columns() selects/renames to Dataset A/B per column dictionary |

------------------------------------------------------------------------

# 中文

**sleepcleanr** 是一个可复现、可审计的睡眠 EMA 日记数据清洗 R
管线：解析原始
就寝/入睡/醒来/起床时间戳，通过透明的人工审核工作流（每次修正都存为可重读的
CSV）检测并修正时序与时长错误，计算标准睡眠指标（TST、SOL、WASO、SE），并生成
诊断与科研图表。经 schema 校验的 YAML
配置可将管线映射到你的数据集，无需改代码。
为斯坦福心理生理学实验室的高强度纵向睡眠研究开发。

### 管线一览

    杂乱的睡眠日记数据 (CSV / RDS)
             ↓
       时间戳解析与规范化
             ↓
       错误检测（顺序、时长、时区）
             ↓
       人工审核（只看被标记的记录）
             ↓
       修正台账（完整审计轨迹）
             ↓
       睡眠指标 (TST, SOL, WASO, SE)
             ↓
       诊断图与科研图
             ↓
       数据集 A（最终清洗版）+ 数据集 B（审计台账）

### 有何不同

1.  **人工参与，而非自动修复。**
    确定性规则只修正无歧义的顺序和格式错误；值级分歧交人工审核。一个看似偏大的
    SOL 原样保留——它是信号，不是错误。
2.  **没有静默修正。**
    每次改动都带有记录在案的修正类型，标记会一直保留，直到人工明确解决。修正台账是输出的一部分（`correction_status_final.csv`、`step_flag_ledger.csv`），每轮运行都会在**项目根目录**（不是
    `output/`）重新生成人工评审工作表（`[NEW]manual_error_correction_review.csv`、`[NEW]manual_unusual_review.csv`）。
3.  **阈值可配置、有文档。** 规则阈值以 YAML 默认值给出并附依据（见
    [THRESHOLDS.md](https://cyracaid.github.io/sleepdiary-cleaner/THRESHOLDS.md)），应按你自己的数据重新核对。
4.  **可复现。** YAML 配置、`renv.lock`，以及在 CI
    中运行的测试套件（R-CMD-check、Codecov）。

## 安装

``` r
# 从 GitHub 安装（尚未上线 CRAN，包名 sleepcleanr）
renv::install("cyracaid/sleepdiary-cleaner")
# 或：pak::pak("cyracaid/sleepdiary-cleaner")
```

## 快速开始

最短路径：把
[`clean_sleep_diary()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/clean_sleep_diary.md)
指向你的文件，无需配置。

``` r
library(sleepcleanr)

res <- clean_sleep_diary("my_diary.csv")          # .csv / .rds / .xlsx / data.frame
res$cleaned                                       # 清洗后的数据集 A
res$guesses                                       # 每一列是怎么映射的
res$manifest                                      # 来源记录：输入哈希、配置、步骤台账
# 只预览推断出的映射，不运行任何东西：
clean_sleep_diary("my_diary.csv", dry_run = TRUE) # 写出 dry_run_manifest.json，不写数据
```

其他入口：

``` r
# 用内置合成数据跑演示
run_pipeline()

# 配置文件路线：复制模板、映射列名、再跑
file.copy(system.file("config_template.yaml", package = "sleepcleanr"),
          "my_study.yaml")
# 编辑 my_study.yaml → run_pipeline(config = "my_study.yaml")
```

> **Shell 提示：** 评审工作表的文件名是
> `[NEW]manual_*.csv`。方括号是通配符， 在 shell
> 里要给文件名加引号：`open "[NEW]manual_error_correction_review.csv"`。

### 证据一览

完整证据包见
[VALIDATION_REPORT.md](https://cyracaid.github.io/sleepdiary-cleaner/VALIDATION_REPORT.md)。摘要：

- **合成真值**（14 类共 5,391 条注入错误，另有 1,609
  行干净对照）：检出率 **0.995** \[0.993, 0.997\]，特异度
  1.0。“检出”指记录被标记，不代表恢复了正确值——修正层面的召回率更低，验证报告里按错误类别分别给出。
- **真实研究数据**（237 名参与者的 13,990 行）：在该研究的运行中，规则对
  93 行做了自动的顺序或格式修正（其中 10
  行也被审核者修正过），审核者另外修正了 75
  行。一轮运行结束时的审核队列：应用人工文件后为 226 行，不应用则为 307
  行。13,990 条提交中有 2,848 条四个时间都填了，因此每 1,000 条日记对应
  79 和 108 行（占全部提交的 1.6% 和 2.2%）。v1.4.5 审计标记的 1,048
  行来自只报告、不改数据的一次运行。
- **外部公开数据集**：经一段简短的转换脚本，管线可在其他 schema
  上运行。这些数据集没有已知错误，所以只是可行性检查，不是准确性验证。

![内置合成数据的 flag 仪表盘：280 条记录中有 23
条被标记待审，按问题类型划分](https://raw.githubusercontent.com/cyracaid/sleepdiary-cleaner/main/man/img/flag-dashboard-synthetic.png)

内置合成数据的 flag 仪表盘：280 条记录中有 23
条被标记待审，按问题类型划分

*图 14，来自在内置合成数据（280
行）上的一次运行：一轮运行结束时管线标记待审的内容。*

早期的自动化版本曾静默地误修条目；合成基准发现并堵住了这些缺陷，目前的基准显示
SOL/WASO 的静默误修率为 0%。

### 为什么是”自动 + 人工”混合设计？

sleepcleanr 刻意**既非全自动、也非全部人工 flag**：

- **不全自动：** 高置信、仅涉时序/AM-PM
  的规则才安全自动修正；但值级错误（如 SOL
  与就寝→入睡窗口的矛盾）绝不覆盖 — 一个看似偏大的 SOL
  是真实的心理信号，静默”修正”会破坏管线所服务的睡眠–情绪关联。
- **不全 flag**：把每个分歧都标出来，手动看不过来（v1.4.5
  只报告审计标记了 1,048 行；当前一轮运行留下 226
  行待审，不应用人工文件则为 307 行）。高置信规则处理确定性个案；FLAG
  只把歧义个案留给人审。

结果不是”管线把 mess 洗干净”，而是把 mess
**显式化**：每个候选错误要么被呈现，要么被记录，永不被静默隐藏。每轮 run
会在**项目根目录**（不是
`output/`）重新生成两张人工评审工作表：`[NEW]manual_error_correction_review.csv`
与 `[NEW]manual_unusual_review.csv`——填好后以
`include_manual_corrections = TRUE` 重跑即应用。

> **阈值只是参考，不是教条。** 这里的 swap/flip 阈值（如 3
> 小时相邻对调、12 小时 AM/PM 翻转）在我们的数据集上验证过 — 见
> VALIDATION_REPORT。你的研究日记可能落在这区间内或外；它们都是 YAML
> 可配置的，应按你自己的数据重新审视，而非盲抄。

### Flag、术语与阈值

flag 各列、flag 生命周期、验证表里用到的术语（L1/L3
召回、FCR、FAR、M1/M4/M5）以及
[`sync_human_review_status()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/sync_human_review_status.md)，见文章
[`vignette("review-flags-zh")`](https://cyracaid.github.io/sleepdiary-cleaner/articles/review-flags-zh.md)（Flag、术语与审核流程）。
检测阈值及其默认值与依据，见[阈值](https://cyracaid.github.io/sleepdiary-cleaner/THRESHOLDS-zh.md)页。

验证地图（合成层、真实数据层、稳健性层）以及每个数字的来源，见
[`vignette("validation-methodology-zh")`](https://cyracaid.github.io/sleepdiary-cleaner/articles/validation-methodology-zh.md)。

> **命名说明：** R 包名为 **sleepcleanr**（CRAN 规范不允许连字符），
> GitHub 仓库名为 **sleepdiary-cleaner**。两者是同一项目 — 安装用
> `renv::install("cyracaid/sleepdiary-cleaner")`，加载用
> [`library(sleepcleanr)`](https://github.com/cyracaid/sleepdiary-cleaner)。

## 状态与数据可用性

**状态。** sleepcleanr（1.8.0
之后的开发版）是仍在开发中的研究软件，为一项纵向睡眠研究而写，尚未经同行评审，也未上线
CRAN。随包给出的阈值只是参考，请用你自己的数据核对。

**数据可用性。**
研究数据不公开（参与者隐私）。不需要这些数据也能用到的东西：

- 内置合成数据（`inst/extdata/`，280 行、20
  名参与者），[`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md)
  默认就跑它；
- 合成基准会按固定随机种子自己生成数据，所以基准里的每个数字都可以重跑（见
  [`validation/README.md`](https://github.com/cyracaid/sleepdiary-cleaner/blob/main/validation/README.md)）；
- 两个公开日记数据集及其转换脚本（`validation/external/`）。

少数来自研究数据的数字（例如冗余通道检查）记录在 `VALIDATION_REPORT.md`
里，没有数据访问权限就无法重跑。

## 局限

- **阈值是研究专属默认值。** 3 小时相邻对调、12 小时 AM/PM
  翻转及合理性切点，都在单一健康成人 EMA
  样本上调过。临床、倒班、老年样本应重新审视每条规则。见
  [THRESHOLDS.md](https://cyracaid.github.io/sleepdiary-cleaner/THRESHOLDS.md)。
- **只检测，不推断意图。**
  管线只呈现候选错误，无法恢复从未录入的信息；值级分歧交人工，不自动裁决。
- **验证部分是自证的。**
  检出率基于注入的合成错误与本管线自己的真实数据审计。自由文本日记没有独立人工金标准，部分统计来自开发数据。
- **无原生 CSD / `.sav` 支持。** Consensus Sleep Diary
  不是原生输入格式，需用 YAML 映射列（或让推断函数猜）。输出为 `.csv` /
  `.rds`，无 SPSS `.sav` 导出。
- **单一协议。**
  为高强度纵向晨间睡眠日记开发；晚间日记、仅小睡日志、actigraphy
  不在范围。
- **不能替代研究专属的质量控制。**

## 引用

请用 Zenodo DOI 引用本软件（总 DOI 永远指向最新版本，每个 release
另有自己的版本 DOI）：

> Dong, C., & ten Brink, M. (2026). *sleepcleanr: Reproducible Sleep EMA
> Diary Data Cleaning Pipeline* \[R package\].
> <https://doi.org/10.5281/zenodo.23077702>

在 R 里：`citation("sleepcleanr")`。机器可读元数据：`CITATION.cff`。

## 运行测试、反馈问题、参与贡献

``` r
devtools::test()   # 在仓库克隆目录中运行；CI 里跑的是同一套测试
```

Bug、问题和功能建议：请开
[issue](https://github.com/cyracaid/sleepdiary-cleaner/issues)。
贡献指南见
[`CONTRIBUTING.md`](https://cyracaid.github.io/sleepdiary-cleaner/CONTRIBUTING.md)。

## 了解更多

- 完整文档站（可检索函数参考 + 双语 vignette）：
  <https://cyracaid.github.io/sleepdiary-cleaner/>
- **验证报告**（证据包，数字从结果 CSV 机器读取）：
  [`VALIDATION_REPORT.md`](https://cyracaid.github.io/sleepdiary-cleaner/VALIDATION_REPORT.md)
- vignette(“getting-started-zh”) —
  安装、第一次运行、两种模式（`include_manual_corrections`）
- vignette(“column-mapping-zh”) — 输入数据与配置：用 YAML 映射你的数据集
- vignette(“data-first-zh”) —
  [`clean_sleep_diary()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/clean_sleep_diary.md)：免配置入口、列名自动推断、运行清单
- vignette(“review-flags-zh”) — flag
  各列与生命周期、验证表里的术语、[`sync_human_review_status()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/sync_human_review_status.md)
- vignette(“interpreting-output-zh”) —
  读懂输出与审核循环（`correction_status_final.csv`、审核状态表、图）
- vignette(“output-files-zh”) —
  一次运行写出的每个文件：放哪里、哪一步写出、是什么
- vignette(“troubleshooting-zh”) — 最常见问题的现象、原因和处理办法
- [`THRESHOLDS-zh.md`](https://cyracaid.github.io/sleepdiary-cleaner/THRESHOLDS-zh.md)
  —
  每个检测阈值的默认值与依据，以及如何设置你自己的（文档站点”Thresholds”页也有）
- vignette(“pipeline-architecture-zh”) — 结构、规则族、分类体系
- vignette(“validation-methodology-zh”) — 规则如何验证（合成 +
  真实数据）
- vignette(“testing-coverage-zh”) — 测试覆盖
- 更新日志：<https://github.com/cyracaid/sleepdiary-cleaner/releases>

## 开发/AI 助手

仓库自带 agent
skill：`.claude/skills/sleepcleanr-pipeline/SKILL.md`（`.agents/skills/`
下有指向它的链接，Claude Code、Codex 和 opencode 都能读到），说明如何
运行管线、解读检查点报告、添加人工修正与诊断问题。

### 管线步骤

**10 个步骤**（来源：`inst/steps.yaml`）：

| 步骤 | 名称 | 说明 |
|----|----|----|
| 1 | 加载数据 | 自动识别 .rds/.csv；校验 schema；可合并补充文件 |
| 1.5 | 字段误填检查 | 在原始数据上检测 SOL/WASO 的时刻与时长字段误填 |
| 2-4 | 解析与规范化（S3 链） | 解析时间戳 → 解析时长 → 规范化顺序 |
| 5 | 记录分类 | 生成供人工批准的审核 CSV |
| 5.75 | 二次审核共识 | 应用二次审核清单的共识 |
| 6-7 | 修正并计算指标（S3 链） | 人工与时长修正；TST/SOL/WASO/SE 指标；has_correction 枚举 |
| 8 | 自动检测剩余问题 | TIMESTAMP/DURATION/AMOUNT/SELF-REPORTED 标记分类 |
| 8.5 | 跨参与者一致性检查 | 对全体参与者做全局一致性审计 |
| 9 | 生成诊断图 | 35 张图（19 张质控 + 16 张科研）+ figure_index.png 总览图 + RUN_INFO.txt |
| 10 | 构建交付数据集 | finalize_columns() 按列字典选列并重命名，得到数据集 A/B |
