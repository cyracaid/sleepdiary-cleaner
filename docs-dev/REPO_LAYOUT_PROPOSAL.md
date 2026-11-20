# 主仓布局整理清单（只列不动，待批）

盘点基准：commit `c71fef1`，`git ls-files` 共 422 个文件。
"是否随包发布" = 该路径是否被 `.Rbuildignore` 的 149 条 pattern 排除。

---

## 第一类：会进 tarball、但不该进

| 路径 | 内容 | 体积 | 现状 | 建议 |
|---|---|---|---|---|
| `splsleep_paper/` | 50 个文件：`10_methods_BRM/`（methods 草稿、`METHODS_SECTION_MAIA_ORIGINAL_WITH_UPDATED_NUMBERS.md`）、`20_software_JOSS/`、`30_short_forms/`、`40_maia_originals/`（.docx 原稿）、`60_worklogs/`、`70_drafts_and_notes/` | 756 KB | 原未被 `.Rbuildignore` 排除 → 会随包发布 | **已加 `^splsleep_paper$`（2026-10-29）**。长期仍建议移出主仓（独立 `splsleep-paper` 仓） |
| `review_status.csv` | 52 KB，真实参与者行（pid、day_num、逐行时间戳） | 52 KB | 被 `.gitignore` 命中（`.gitignore:171`），但**不在 `.Rbuildignore` 里** → 已随 1.7.2 tarball 发布 | **已加 `^review_status\.csv$`** |
| `maia_m7_corrections_20260828.zip` | 内含 `audit_dispositions.csv`、`manual_sleep_metric_duration_corrections.csv`（真实修正文件） | 3.2 KB | 被 `.gitignore` 的 `*.zip` 命中，但**不在 `.Rbuildignore` 里** → 已随 1.7.2 tarball 发布 | **已加 `^.*\.zip$`** |

上面后两项是本轮盘点里最要紧的发现：`.gitignore` 和 `.Rbuildignore` 是两套独立的规则，只写一处等于没写。修复前 `R CMD build` 出来的 tarball 里有真实参与者的睡眠时间戳；修复后 tarball 从 2.0 MB 降到 0.83 MB，根目录只剩 `DESCRIPTION`、`LICENSE`、`NAMESPACE`、`README.md`。

`splsleep_paper/` 同时是 `checking for portable file names ... WARNING` 的唯一来源（`methodology 草稿.docx` 之类的非 ASCII 文件名 + 超过 100 字节的路径）。


---

## 第二类：不进 tarball，但占着主仓

| 路径 | 体积 / 规模 | 为什么该挪 |
|---|---|---|
| `validation/` | **95 个 tracked 文件**（全仓最大树）、780 KB | 混装了三样东西：审计脚本（`derive_*.R`、`build_typeA_review.R`）、method section 草稿（`METHOD_SECTION_DRAFT_*.md` ×3 + `PROMPT_*.md`）、外部文献扫描产物（`literature_scan_candidates.csv`、`external/`、`blind_audit/`）。跟包的运行无关 |
| `docs-dev/` | 原有 8 个 md（64 KB，加上本文件为 9 个） | 其中 `TECH_DEBT.md`、`ROADMAP.md`、`ARCHITECTURE.md` 有维护价值；`TEST_RESULTS.md`、`GLOBALENV_REFACTOR_ASSESSMENT.md`、`part_b_b4_no_guard_categories.md`、`README_figures_navigation.md`、`CLINICAL_WORKFLOW.md` 是一次性记录 |
| `verify_delivery_wiring.R`、`verify_finalize_columns.R`、`verify_reference_fidelity.R` | 840 行，39 KB | 根目录三个开发校验脚本：CI 不跑、`tests/` 不调、用户不看。要么变成 `tests/testthat/test-*.R`，要么进 `tools/verify/` |
| `inst/verification/` | 3 个脚本 | 位于 `inst/` 内部却被 `.Rbuildignore` 排除 → 既不在包里、又让人以为它在包里。是死文件 |
| `inst/hooks/` | `pre-commit`、`install-hooks.sh` | **会随包发布**。git hook 出现在 CRAN tarball 里没有意义。应在 `tools/hooks/` |
| `VISUALIZATION_TREE_PROPOSAL.md` | 35 KB，全仓第二大 md | 提案文档，F01–F32 已落地，提案本身是历史记录 |
| `.agents/`、`.claude/`、`.opencode/`、`opencode.jsonc`、`AGENTS.md`、`CLAUDE.md` | 6 个入口 | 都用 `.Rbuildignore` 排掉了，功能上没问题；只是根目录被占了 6 个位置。`CLAUDE.md` 只有一行 `@AGENTS.md`，是纯指针 |

---

## 第三类：引用悬空（这是 bug，不是整洁问题）

`vignettes/` 里有 **20 处**指向被 `.Rbuildignore` 排除的路径：

- `templates/template_manual_error_corrections.csv` 等 6 个（`column-mapping.Rmd` / `-zh.Rmd` 的表格里逐行列了文件名）
- `THRESHOLDS.md`（"阈值依据见 `THRESHOLDS.md`"）
- `SCHEMA.md`

装了包的人按 vignette 去找这些文件 → 找不到。同一份 vignette 里其他地方已经用了正确写法：

```r
system.file("extdata", "stub_error_corrections.csv", package = "sleepcleanr")
```

**修法**：把空模板放进 `inst/extdata/`（`stub_*.csv` 已经在那儿了），vignette 改成 `system.file()`；`THRESHOLDS.md` / `SCHEMA.md` 的内容要么进函数文档，要么随包发布。

---

## 第四类：影子副本

根目录 `00_MAIN_entry.R`（41 行）与 `inst/scripts/00_MAIN_entry.R` **md5 完全相同**（`1ac2b2c6cf4e21f3921341a9ef693528`），`00a_setup.R`（83 行）同理（`1c3b8ba692f82535132184101e5da69b`）。

`test-script-copies-in-sync.R` 第 49 行把这两个文件名放进了 `allowed_root`，**明确豁免**了它们的一致性检查。所以这两个文件可以悄悄漂移而测试照绿。

两个选项：删掉根目录副本（legacy 入口现在也走 `run_pipeline()`），或把根目录的缩成 3 行 `source(file.path("inst", "scripts", ...))`。

---

## 建议的目标布局

```
sleepcleanr/            # 只剩包 + 测试 + vignette + 文档
├── R/  man/  inst/  tests/  vignettes/  data-raw/
├── DESCRIPTION  NAMESPACE  README.md  NEWS.md
├── paper.md  paper.bib            # JOSS 惯例放根目录
├── .Rbuildignore  .github/  pkgdown/
├── tools/                         # render_docs.R + hooks/ + verify/
└── docs-dev/                      # 只留 TECH_DEBT.md、ROADMAP.md、ARCHITECTURE.md
splsleep-paper/         # 另一个仓：splsleep_paper/ + validation/ + methods 草稿
```

---

## 执行顺序（每步独立可回滚）

1. ~~`.Rbuildignore` 加 `^splsleep_paper$`、`^review_status\.csv$`、`^.*\.zip$`~~ —— **已完成 2026-10-29**（见第一类）。
2. `inst/hooks/` → `tools/hooks/`，同步改 `CONTRIBUTING.md` 里的安装说明。
3. `inst/verification/` → `tools/verify/`，删 `.Rbuildignore` 里的 `^inst/verification`。
4. `verify_*.R` → `tools/verify/`（或改写成 `test-*.R`）。
5. 修第三类的 20 处悬空引用（这一项最影响外部用户体验）。
6. 决定 `00_MAIN_entry.R` / `00a_setup.R` 根副本的处置，同时把 `allowed_root` 清空。
7. `splsleep_paper/` + `validation/` 迁到独立仓（最大动作，放最后；可与 JOSS 投稿同批）。

---

_盘点日期 2026-10-29。本文档本身是临时产物，决定做完即可删除。_
