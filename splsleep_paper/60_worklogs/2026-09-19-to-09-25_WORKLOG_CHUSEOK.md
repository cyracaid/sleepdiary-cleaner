# 2026-09-19 to 2026-09-25 Work Log (Chuseok week)

## Summary
四条线：fasttrack 审计闭环、数据隐私/仓库安全、pipeline 工程修复、文档体系
重构。22 commits；仓库公开但历史重写后零真实数据残留；coverage
67.6%→80%（458 tests，0 fail）；CI 全绿（R-CMD-check / test-coverage /
pkgdown 首次同周全绿）。

## 1. Fasttrack 审计闭环（23 条的完整旅程）
- raw 行溯源：`derive_timegap_candidates.R:80`（raw_row_id = sber 行号）
- date_of_obs 注入 raw 列（5496414）
- `query_pid.R`（1596114）：单人全史查询，供独立标注
- 独立标注说明（11123f2）→ cyra 23/23 Accept=Yes + Notes
- blindspot 扫描（1dee3b6）：typeA 10（真 quirk）/ typeB 22（12h-dial 习惯）
  → typeA review sheet（c20b7ab）
- Corrected 列三连修：
  1. literal decode（错误）→ pipeline actual（612e8f5）
  2. provenance：rds md5 + mtime + normalize 代码指纹进 sidecar（8508a05）
  3. 真实日期：sber-extra 重跑 pipeline → 2020-09-19 02:15 非 2000-01-01
- 终验：23 fasttrack + 10 typeA + 3 fullreview 全部已 auto-corrected
  （corrected=TRUE, sleep_reduce_12h_loop），manual csv 75 行不变

## 2. 数据隐私 / 仓库安全
- git-filter-repo 全历史重写：4 泄漏文件清除（tiered_fasttrack、
  tiered_fullreview_cyra/maia、fasttrack_review_maia），force-push
- `--sensitive-data-removal` 复核：First Changed Commit(s) 空、0 PR、无 LFS
- Pages 被安全机制自动禁用（has_pages False）→ API 重新启用 → 200 恢复
- GitHub Support ticket 起草（Log request, 2026-09-07 14:23 → 09-24 15:05,
  PUBLIC, 3 旧 SHA）
- release tarball 复核：真实 csv 全排除；tarball 只有
  stub/template/synthetic（stub_error_corrections.csv = 1 行 header）
- 决策：仓库保持 PUBLIC（Maia 免登录下载 release）

## 3. Pipeline 工程修复
- R 4.6.0 `format(<difftime>, "%H:%M")` → "invalid trim" bug 修复
  （timestamp_parse.R:69，手动秒→HH:MM，pipeline 恢复可跑）
- sber-extra config（main=deidentified rds + extra=sber csv 注入 StartDate）
  重跑全 pipeline → cleaned_data_full.rds 2860 行 corrected 全带真实日期，
  0 占位残留
- Pages 404 → 恢复 → 最新文档两轮部署

## 4. 文档体系
- 图表逐图 guide → 28 卡片重构（4ed4ebc，+503/−289）：
  - §6.1 Figure Index（28 行：论文用途/代码来源 file:line/核对日期）
  - §6.2 卡片（File/Paper use/含义/精确规则/正常异常/FAQ/caption 单源）
  - §6.3 关键定义（equal_time_ok 0.01h 容差三子型、sleep==awake 恒 error）
  - §7 论文 captions、§8 manual CSV（7 文件：步骤/原因/生成源）+ run code
- 07 图纠正：fill=flag_severity 非 data_category
- Method Stage 7.5 fasttrack 审计段（本地 work_logs）
- coverage 67.6→80%（6 commits, 458 tests）
- A1 替代 12、19 并入 13、11/14/15/16 真实数据跳过（设计使然）

## Next week
见 `2026-09-29_WORKLOG.md`（include_manual_corrections 参数、运行时问询、
严格路径、manual csv 循环文档化、1,720 vs 1,729 查证、synthetic 验证、
Method 完整稿、选图建议）