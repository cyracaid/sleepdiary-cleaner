# 下次会议 — 待讨论任务

**项目：** splsleep v1.3.1
**日期：** 待定
**目标：** 排定技术债务清理和 v1.4.0 功能候选的优先级

---

## 会议议程

1. 技术债务 #1–3 — 新功能之前先清掉？
2. 功能优先级投票：昼夜节律 vs brms vs targets vs Step 8 进链
3. CRAN 提交时间线 — 直接提交 v1.3.1？
4. 人工审核工作流 — SQLite 升级值得 1–2 周吗？

---

## 立即可做（各需 1 天 — 清理已知债务）

| # | 任务 | 来源 |
|---|------|------|
| 1 | **体内化 `process_timestamp()` / `process_interval()` 到 `R/steps.R`** | TECH_DEBT #2 |
| | 将函数体直接复制到步骤适配器中。消除步骤 2–3 的 `source()` → `sys.source()` 调用。约 600 行机械搬运。Snapshot 测试把关安全。 | |
| 2 | **解决根目录与 `inst/scripts/` 的重复脚本** | TECH_DEBT #1 |
| | 以 `inst/scripts/` 为唯一来源。所有调用方迁移到 `scripts_dir()` 后删除或将根目录副本改为薄包装。 | |
| 3 | **消除 `cfg_get()` deprecated fallback 警告** | TECH_DEBT #3 |
| | 将所有 `source()` 脚本改为接受显式 `cfg` 参数。移除全局环境警告路径。 | |

## 功能候选（v1.4.0）

| # | 任务 | 工作量 | 说明 |
|---|------|:--:|------|
| 4 | **昼夜节律分析模块** | 2–3 天 | `circadian_analysis()` — 独立函数：Cosinor 回归 + Lomb-Scargle 周期图。返回相位、振幅、中值。附带 vignette。 |
| 5 | **贝叶斯分层模型 vignette（brms）** | 2–3 天 | `.Rmd`：清洗数据 → `brms(SOL ~ caffeine + alcohol + (1\|pid))` → 后验检查 → 森林图。分析演示——不在管线内。 |
| 6 | **`{targets}` 增量管线** | 3–5 天 | 基于 DAG 的缓存。新增 3 天 EMA 数据 → 仅重跑受影响步骤。并行执行。崩溃自动续跑。 |
| 7 | **JSON Schema 配置校验** | 1 天 | VSCode 对 `config.yaml` 的自动补全。`{jsonvalidate}` + `inst/schema/`。 |
| 8 | **Step 8 自动检测进链** | 2–3 天 | 提取 `checkforerrors_processing.R` 的计算核心 → `step_auto_detect()` 适配器。文件 I/O 留在 `run_pipeline()` 中。 |
| 9 | **Ledger 持久化到 `sleep_diary`** | 0.5 天 | 将 flag 账本绑定到 S3 对象。`summary()` 跨 R 会话永远可用。链结束时自动写 CSV。 |

## 基础设施 / 润色

| # | 任务 | 工作量 | 说明 |
|---|------|:--:|------|
| 10 | **CRAN NOTE 清理** | 0.5 天 | 解决剩余 2 个 NOTE，准备 CRAN 提交。 |
| 11 | **pkgdown 文档站** | 0.5 天 | `https://cyracaid.github.io/splsleep/` — 函数参考 + vignettes。 |
| 12 | **列名单一来源** | 1–2 天 | 将 SCHEMA.md + validate_schema.R + config 列映射合并为一个 `R/schema.R`。 |
| 13 | **人工审核工作流 → SQLite** | 1–2 周 | `review_db$connect()`，含任务创建、决策追踪、回滚、查询。最大单项功能。 |

## 明确不做

| 项目 | 原因 |
|------|------|
| KZ 自适应滤波 | 工具类别错误——自报日记数据不需要传感器平滑 |
| Rcpp 时间解析 | 14K 行 = 0.5 秒——不存在瓶颈 |
| data.table 迁移 | dplyr 在此规模完全够用；风险 > 收益 |
| Isolation Forest / DBSCAN | 黑箱异常检测替代可审计的规则 |
| valgrind / sanitizer 检查 | 包内无编译代码 |
| DAG 抽象层 | S3 链 + 显式 cfg 注入 = 已足够 |

---

## 当前状态参考

```
版本:         1.3.1
R CMD check:  0 ERROR, 0 WARNING, 2 NOTE
CI:           GitHub Actions — 绿
测试:         76+ testthat 测试
Release:      v1.0.0 → v1.2.0 → v1.3.0
分支:         main（领先 v1.3.0 tag 9 个 commit）
```

另见：`TECH_DEBT.md`, `TECH_DEBT_CN.md`, `ROADMAP.md`, `NEWS.md`, `work_logs/2026-07-28_Phase_Summary.md`
