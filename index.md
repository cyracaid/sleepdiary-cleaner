# sleepcleanr — Reproducible cleaning pipeline for sleep EMA diary data

[![CRAN](https://img.shields.io/cran/v/sleepcleanr?style=flat-square&color=blue)](https://cran.r-project.org/package=sleepcleanr)
[![GitHub
stars](https://img.shields.io/github/stars/cyracaid/sleepdiary-cleaner?style=flat-square)](https://github.com/cyracaid/sleepdiary-cleaner/stargazers)
[![License:
MIT](https://img.shields.io/badge/license-MIT-green?style=flat-square)](https://opensource.org/licenses/MIT)
[![R-CMD-check](https://img.shields.io/github/actions/workflow/status/cyracaid/sleepdiary-cleaner/R-CMD-check.yaml?style=flat-square&label=R--CMD--check)](https://github.com/cyracaid/sleepdiary-cleaner/actions/workflows/R-CMD-check.yaml)
[![Codecov](https://img.shields.io/codecov/c/github/cyracaid/sleepdiary-cleaner?style=flat-square&color=orange)](https://codecov.io/gh/cyracaid/sleepdiary-cleaner)
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
  review, 0 silent corrections
- 📊 **Auditable** — every change logged and reversible; non-destructive
  architecture
- ✅ **Validated** — 9-step validation chain: synthetic (0.995 recall) +
  real data (92% improved) + robustness proof
- 🚀 **Reproducible** — YAML config, full pipeline documentation, 308
  unit tests passing
- 🎯 **Research-ready** — generates publication-quality figures +
  correlation matrices

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

------------------------------------------------------------------------

# 中文

**sleepcleanr** 是一个可复现、可审计的睡眠 EMA 日记数据清洗 R
管线：解析原始
就寝/入睡/醒来/起床时间戳，通过透明的人工审核工作流（每次修正都存为可重读的
CSV）检测并修正时序与时长错误，计算标准睡眠指标（TST、SOL、WASO、SE），并生成
诊断与科研图表。经 schema 校验的 YAML
配置可将管线映射到你的数据集，无需改代码。
为斯坦福心理生理学实验室的高强度纵向睡眠研究开发。

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
