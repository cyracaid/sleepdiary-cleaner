# 快速开始（中文）

[English
→](https://cyracaid.github.io/sleepdiary-cleaner/articles/getting-started.md)

sleepcleanr
检测并修正睡眠日记中时间和时长的录入错误，并记录每一处改动。它是研究软件，未上线
CRAN。本页带你从安装走到第一次运行。如果你的数据还不是预期的格式，先读[输入数据与配置](https://cyracaid.github.io/sleepdiary-cleaner/articles/column-mapping-zh.md)。

## 1. 安装

在**没有加载 sleepcleanr** 的普通 R
会话里安装，并且不要在本仓库的检出目录里操作（检出目录有自己的 `renv`
库，会看不到你系统里的包）。

``` r
install.packages("remotes")
remotes::install_github("cyracaid/sleepdiary-cleaner@v1.7.2", upgrade = "never", force = TRUE)
```

然后**重启 R**，再检查加载的是哪个版本：

``` r
library(sleepcleanr)
getNamespaceVersion("sleepcleanr")      # "1.7.2"
```

如果包在另一个 R
窗口里处于加载状态时被重装，安装可能损坏（`lazy-load database ... is corrupt`）。先关掉所有
R 会话，再安装，再重启。

## 2. 准备项目文件夹

每次运行用一个文件夹。里面放数据文件和配置 YAML（复制
`inst/config_template.yaml`，编辑 `data`
部分）。如果已有人工审核文件，也放进去。如果某个文件夹里有以前的结果，请从它的**副本**开始：一次运行会覆盖它写出的文件（见[输出文件一览](https://cyracaid.github.io/sleepdiary-cleaner/articles/output-files-zh.md)）。

## 3. 运行

``` r
library(sleepcleanr)
run_pipeline(config = "my_study.yaml", project_dir = "path/to/project",
             include_manual_corrections = TRUE)
```

| 参数                         | 作用                                                                                |
|------------------------------|-------------------------------------------------------------------------------------|
| `config`                     | 配置 YAML 的路径。相对路径先在 `project_dir` 里找，找不到再按你调用时所在的目录找。 |
| `project_dir`                | 项目文件夹。运行会进入它，所以 YAML 里的相对路径（数据、人工文件）都相对于它。      |
| `include_manual_corrections` | **默认 `FALSE`。** 是否应用人工审核文件。它是调用的参数，不是 YAML 设置。见下。     |
| `skip_visualization`         | `TRUE` 则跳过出图。                                                                 |

### 两种模式

|               | `include_manual_corrections = FALSE`（默认） | `= TRUE`                           |
|---------------|----------------------------------------------|------------------------------------|
| 人工审核文件  | 视为不存在；只跑算法，并用横幅说明           | 应用，前提是 YAML 里指向的文件存在 |
| Step 5 审核表 | 写出                                         | 写出                               |
| 适合          | 在新数据上第一次运行，看规则标记了什么       | 应用审核者已经记录的修正           |

默认值在 1.4.7
版改变。更早的版本不需要询问就应用人工文件，所以同一个调用在前后可能得到不同结果。

## 4. 在控制台里看什么

每一步会打印标题 `=== Step N: ... ===`。运行之后：

- 最后一个标题告诉你跑到了哪一步。如果运行中途停了，错误信息就在最后一个标题之后。
- 在 Step 1 之前，运行会打印
  `=== Rules in effect for this run ===`：它将使用的每个阈值，以及来自默认值还是你的配置。同一份清单保存在
  `output/effective_rules.csv`。
- Step 5 应该打印
  `14. Saving review CSV files with [NEW] prefix...`，以及两张审核表各一行
  `verified on disk`。
- 应用人工修正时应该看到 `Manual corrections INCLUDED`；不应用时是横幅
  `MANUAL CORRECTIONS NOT INCLUDED`。
- 接近结尾，`[review status]` 统计错误审核表的各个状态各有多少行。

## 5. 结果在哪里

审核用的工作文件写到**项目文件夹**（不在 `output/`）；结果写到
`output/`。[输出文件一览](https://cyracaid.github.io/sleepdiary-cleaner/articles/output-files-zh.md)开头有一份快速指引，说明哪个文件、哪一列回答哪个问题（是否被改过、是否还需要人看、是否有人接受），然后列出每个文件、何时写出、是什么。如果缺文件或出现错误，见[排错](https://cyracaid.github.io/sleepdiary-cleaner/articles/troubleshooting-zh.md)。

不打开文件，在 R 里读一次完成的运行：

``` r
res <- pipeline_results()
names(res)
```
